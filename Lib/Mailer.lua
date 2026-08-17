-- ============================================================
-- Warbrand-Fast-Mail / Lib/Mailer.lua
-- Event-driven state machine, one recipient at a time:
--   attach (max 12) -> dispatch -> repeat -> next recipient
--
-- Safety:
--   * never runs without an open mailbox
--   * hard cap on mails per run
--   * postage checked before every SendMail
--   * COD and attached money forced to zero
--   * items that refuse to attach are skipped after 3 tries
--   * partial stacks are handled by parking the remainder in a free
--     bag slot and then attaching the rest as a whole stack; a failed
--     partial attach retires the item for the run instead of retrying,
--     because a retry works on a changed bag layout and would ship the
--     item away a few pieces at a time
--   * the skip counter is keyed by itemID, so moving a stack between
--     slots cannot reset it
--   * bags are re-scanned and re-routed before every single attach,
--     so slot indices can never go stale
--   * hold amounts are tracked in a ledger seeded once per run, not
--     re-read from GetItemCount: that counter is cached and refreshes
--     only on BAG_UPDATE, so mid-run it still reports the pre-attach
--     total and every stack would clear the same budget
--   * gold can ride along on the last mail to its recipient, which
--     saves one postage fee
-- ============================================================
local ADDON, ns = ...
local L, Util, Scanner = ns.L, ns.Util, ns.Scanner

local Mailer = CreateFrame("Frame", ADDON .. "MailerFrame")
ns.Mailer = Mailer

-- --- Tunables ----------------------------------------------
local MAX_ATTACH = _G.ATTACHMENTS_MAX_SEND or 12
local THROTTLE   = 0.20
local MAX_RETRY  = 3
local SPLIT_DELAY = 0.25   -- item lock settle time around cursor moves
local POLL_STEP   = 0.10   -- re-read interval while waiting for BAG_UPDATE
local SPLIT_POLLS = 20     -- give the container cache up to two seconds
local MAX_MAILS  = 25

-- --- State -------------------------------------------------
local S = { active = false }

local function ResetState()
    S = {
        active    = false,
        plan      = nil,   -- ordered list of recipients
        index     = 0,
        recipient = nil,
        override  = nil,   -- function(entry) -> boolean, forces one recipient
        sent      = 0,
        mails     = 0,
        pending   = 0,
        skip      = {},
        ledger    = {},    -- itemID -> pieces still allowed to leave
        totals    = nil,   -- bag snapshot taken at Start
        withGold  = false,
        goldSent  = false,
        goldAmount = 0,
        goldOnThisMail = 0,  -- set per dispatch; belongs to the run state
    }
end
ResetState()

function Mailer:IsActive() return S.active end

-- --- Helpers -----------------------------------------------

local MailboxOpen  = Util.MailboxOpen
local FilledSlots  = Util.MailAttachments
local EnsureSendTab = Util.EnsureMailSendTab

---Predicate for the current recipient, re-evaluated on every scan.
local function CurrentFilter(e)
    if S.override then return S.override(e) end
    return ns.Rules.Resolve(e) == S.recipient
end

---Remaining allowance for an item. Seeded once per run from the bag
---totals taken at Start, then decremented by hand -- never re-read from
---a counter that lags behind the attachments.
local function Quota(itemID)
    if itemID == nil then return math.huge end
    if S.ledger[itemID] == nil then
        S.ledger[itemID] = ns.Hold.Budget(itemID, S.totals and S.totals[itemID])
    end
    return S.ledger[itemID]
end

local function SpendQuota(itemID, qty)
    if itemID == nil then return end
    local left = S.ledger[itemID]
    if left == nil or left == math.huge then return end
    S.ledger[itemID] = math.max(0, left - qty)
end

-- --- Lifecycle ---------------------------------------------

function Mailer:Stop(msg, isError)
    if not S.active then return end
    self:UnregisterAllEvents()
    Util.Try(SetSendMailMoney, 0)
    local sent, mails = S.sent, S.mails
    -- gold was requested but never found a mail to ride on
    local goldLeftOver = S.withGold and not S.goldSent and not isError
    ResetState()
    if msg then Util.Print(msg) end
    if isError then
        Util.Print(L.ABORTED, sent)
    else
        Util.Print(L.DONE, sent, mails)
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end

    -- No item mail went to the gold recipient, so send it on its own.
    if goldLeftOver then
        C_Timer.After(THROTTLE, function()
            if ns.Gold.Recipient() and ns.Gold.Sendable() > 0 then ns.Gold.Send() end
        end)
    end
end

function Mailer:Abort(msg) self:Stop(msg, true) end
function Mailer:Finish()   self:Stop(nil, false) end

---@param plan table      ordered list of recipient names
---@param override function|nil  entry -> boolean (forces a single recipient)
---@param withGold boolean|nil   attach the gold transfer to the last
---                              mail going to the gold recipient
function Mailer:Start(plan, override, withGold)
    if S.active then return Util.Print(L.BUSY) end
    if not MailboxOpen() then return Util.Print(L.NO_MAILBOX) end
    if type(plan) ~= "table" or #plan == 0 then return Util.Print(L.NOTHING) end

    ResetState()
    S.active   = true
    S.plan     = plan
    S.override = override
    S.withGold = withGold and true or false
    S.totals   = Scanner.BagTotals()
    S.index    = 0

    EnsureSendTab()
    self:RegisterEvent("MAIL_SEND_SUCCESS")
    self:RegisterEvent("MAIL_FAILED")
    self:RegisterEvent("MAIL_CLOSED")
    self:NextRecipient()
end

function Mailer:NextRecipient()
    if not S.active then return end
    S.index = S.index + 1
    S.recipient = S.plan[S.index]
    if not S.recipient then return self:Finish() end
    Util.Debug("recipient %d/%d: %s", S.index, #S.plan, S.recipient)
    self:Step()
end

-- --- Attach loop -------------------------------------------

function Mailer:Step()
    if not S.active then return end
    if not MailboxOpen() then return self:Abort(L.MAILBOX_CLOSED) end

    local filled = FilledSlots()
    if filled >= MAX_ATTACH then return self:Dispatch() end

    local item = Scanner.FindFirst(S.skip, CurrentFilter, Quota)
    if not item then
        if filled > 0 then return self:Dispatch() end
        return self:NextRecipient()
    end

    local link = item.link

    ---A partial attach that goes wrong must not be retried: the pieces
    ---land back in the bags in a new layout, the smaller stack then fits
    ---the budget whole, and the item gets nibbled away entirely. One
    ---strike, then the item is out for this run.
    local function FailItem(reason)
        S.skip[item.itemID] = MAX_RETRY
        Util.Debug("partial attach failed (%s)", reason or "?")
        Util.Print(L.SKIP, link or "?")
        ClearCursor()
        Mailer:Step()
    end

    local function Verify()
        if not S.active then return ClearCursor() end
        if FilledSlots() > filled then
            SpendQuota(item.itemID, item.sendQty)
            Util.Debug("attached %d x %s, rest erlaubt %s",
                item.sendQty, link or "?", tostring(S.ledger[item.itemID]))
        else
            S.skip[item.itemID] = (S.skip[item.itemID] or 0) + 1
            if S.skip[item.itemID] >= MAX_RETRY then Util.Print(L.SKIP, link or "?") end
        end
        Mailer:Step()
    end

    ClearCursor()

    if item.sendQty >= item.count then
        Util.Try(C_Container.UseContainerItem, item.bag, item.slot)
        C_Timer.After(THROTTLE, Verify)
        return
    end

    -- Partial stack. Rather than splitting the sendable part onto the
    -- cursor and dropping it into a mail slot, move the *remainder* into
    -- a free bag slot. What stays behind is then exactly the sendable
    -- amount and goes out as an ordinary whole stack, which is the path
    -- that is known to work.
    local keepHere = item.count - item.sendQty
    local freeBag, freeSlot = Scanner.FindEmptyBagSlot()
    if not freeBag then return FailItem("no free bag slot") end

    Util.Debug("split %d off %s, sending %d", keepHere, link or "?", item.sendQty)
    Util.Try(C_Container.SplitContainerItem, item.bag, item.slot, keepHere)

    C_Timer.After(SPLIT_DELAY, function()
        if not S.active then return ClearCursor() end
        if GetCursorInfo() ~= "item" then return FailItem("split produced no cursor item") end

        Util.Try(C_Container.PickupContainerItem, freeBag, freeSlot)

        -- The container cache only refreshes on BAG_UPDATE, so the split
        -- result is not readable immediately. Poll for a stack holding
        -- exactly the sendable amount rather than reading the old slot
        -- once; that also survives the game restacking things.
        local function AttachWhenReady(tries)
            if not S.active then return ClearCursor() end
            if GetCursorInfo() then return FailItem("could not park the remainder") end

            local bag, slot = Scanner.FindSlotWithCount(item.itemID, item.sendQty)
            if bag then
                Util.Try(C_Container.UseContainerItem, bag, slot)
                return C_Timer.After(THROTTLE, Verify)
            end

            if tries < SPLIT_POLLS then
                return C_Timer.After(POLL_STEP, function() AttachWhenReady(tries + 1) end)
            end

            local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
            FailItem(string.format("no stack of %d found after %.1fs, source slot holds %s",
                item.sendQty, SPLIT_POLLS * POLL_STEP,
                info and tostring(info.stackCount) or "nothing"))
        end

        C_Timer.After(POLL_STEP, function() AttachWhenReady(0) end)
    end)
end

-- --- Dispatch ----------------------------------------------

function Mailer:Dispatch()
    if not S.active then return end
    if not MailboxOpen() then return self:Abort(L.MAILBOX_CLOSED) end

    local n = FilledSlots()
    if n == 0 then return self:NextRecipient() end
    if S.mails >= MAX_MAILS then return self:Abort(string.format(L.CAP, MAX_MAILS)) end

    Util.Try(SetSendMailCOD, 0)
    Util.Try(SetSendMailMoney, 0)

    local price = Util.Try(GetSendMailPrice) or 0
    if GetMoney() < price then return self:Abort(L.NO_MONEY) end

    local subject = ns.db.subject
    if type(subject) ~= "string" or subject == "" then subject = Util.DEFAULT_SUBJECT end
    local body = type(ns.db.body) == "string" and ns.db.body or ""

    if SendMailNameEditBox    then SendMailNameEditBox:SetText(S.recipient) end
    if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText(subject) end

    -- Piggyback the gold transfer onto the last mail that goes to the
    -- gold recipient: same postage, one less mail.
    S.goldOnThisMail = 0
    if S.withGold and not S.goldSent then
        local goldTo = ns.Gold.Recipient()
        local lastForRecipient = (Scanner.FindFirst(S.skip, CurrentFilter, Quota) == nil)
        if goldTo and goldTo == S.recipient and lastForRecipient then
            local amount = ns.Gold.Sendable()
            if amount > 0 then
                Util.Try(SetSendMailMoney, amount)
                S.goldOnThisMail = amount
            end
        end
    end

    S.mails   = S.mails + 1
    S.pending = n
    Util.Debug("mail #%d, %d attachment(s), %d copper -> %s",
        S.mails, n, S.goldOnThisMail, S.recipient)
    SendMail(S.recipient, subject, body)
end

-- --- Events ------------------------------------------------

Mailer:SetScript("OnEvent", function(self, event)
    if not S.active then return end

    if event == "MAIL_SEND_SUCCESS" then
        S.sent    = S.sent + (S.pending or 0)
        S.pending = 0
        if (S.goldOnThisMail or 0) > 0 then
            S.goldSent   = true
            S.goldAmount = S.goldOnThisMail
            Util.Print(L.GOLD_SENT, Util.Money(S.goldOnThisMail), S.recipient)
            S.goldOnThisMail = 0
        end
        if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
        C_Timer.After(THROTTLE, function() Mailer:Step() end)

    elseif event == "MAIL_FAILED" then
        self:Abort(L.SEND_FAILED)

    elseif event == "MAIL_CLOSED" then
        self:Abort(L.MAILBOX_CLOSED)
    end
end)
