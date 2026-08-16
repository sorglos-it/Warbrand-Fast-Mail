-- ============================================================
-- Warbrand-Fast-Mail / Lib/Gold.lua
-- Sends everything above a configurable reserve to one fixed
-- character.
--
-- Safety:
--   * reserve is a hard floor, postage is deducted on top of it
--   * amount is recomputed immediately before SendMail, never
--     trusted from the confirmation dialog
--   * refuses to run while items are attached in the mail frame
--     (SendMail would ship them along with the money)
--   * refuses to run while an item run is in progress
--   * COD forced to zero, attached money reset after every attempt
--   * recipient goes through the same whitelist as item mails
-- ============================================================
local ADDON, ns = ...
local L, Util = ns.L, ns.Util

local Gold = CreateFrame("Frame", ADDON .. "GoldFrame")
ns.Gold = Gold

local MIN_FEE = 30    -- copper, standard postage
local pending = nil

-- --- Calculation -------------------------------------------

function Gold.Fee()
    local price = Util.Try(GetSendMailPrice) or 0
    return math.max(price, MIN_FEE)
end

---Effective reserve in copper: the character override wins, otherwise
---the account-wide value. An unset override is stored as "" rather than
---0, so "keep nothing back" stays expressible per character.
---@return number copper, string scope ("char"|"global")
function Gold.Reserve()
    local c = ns.charDB and ns.charDB.goldReserve
    if type(c) == "number" and c >= 0 then return math.floor(c), "char" end
    local g = tonumber(ns.db.gold and ns.db.gold.reserve) or 0
    return math.max(0, math.floor(g)), "global"
end

---@return number copper that may be sent right now (0 if none)
function Gold.Sendable()
    local amount = (GetMoney() or 0) - Gold.Reserve() - Gold.Fee()
    if amount < 0 then return 0 end
    return math.floor(amount)
end

---Effective gold recipient: character override wins over the
---account-wide value. Resolving to the logged-in character yields nil,
---so one account-wide setting can be left in place everywhere.
---@return string|nil recipient, string|nil scopeOrError
function Gold.Recipient()
    local levels = {
        { raw = ns.charDB and ns.charDB.goldRecipient, scope = "char" },
        { raw = ns.db.gold and ns.db.gold.recipient,   scope = "global" },
    }
    for _, lvl in ipairs(levels) do
        if type(lvl.raw) == "string" and Util.Trim(lvl.raw) ~= "" then
            local recipient = Util.NormalizeRecipient(lvl.raw)
            if not recipient then return nil, "invalid" end
            if Util.IsSelf(recipient) then return nil, "self" end
            return recipient, lvl.scope
        end
    end
    return nil, "empty"
end

function Gold.IsPending() return pending ~= nil end

-- --- Confirmation ------------------------------------------

StaticPopupDialogs["Warbrand-Fast-Mail_GOLD"] = {
    text           = "%s",
    button1        = SEND or "Send",
    button2        = CANCEL or "Cancel",
    timeout        = 30,
    whileDead      = false,
    hideOnEscape   = true,
    preferredIndex = 3,
    OnAccept = function(_, data)
        if data and data.recipient then Gold.Execute(data.recipient) end
    end,
}

-- --- Send --------------------------------------------------

function Gold.Send()
    if pending then return Util.Print(L.BUSY) end
    if ns.Mailer:IsActive() then return Util.Print(L.BUSY) end
    if not Util.MailboxOpen() then return Util.Print(L.NO_MAILBOX) end

    local recipient = Gold.Recipient()
    if not recipient then return Util.Print(L.GOLD_NONE) end

    if Util.MailAttachments() > 0 then return Util.Print(L.GOLD_ATTACH) end

    local amount = Gold.Sendable()
    if amount <= 0 then return Util.Print(L.GOLD_NOTHING) end

    if ns.db.gold.confirm then
        local dlg = StaticPopup_Show("Warbrand-Fast-Mail_GOLD",
            string.format(L.GOLD_CONFIRM, Util.Money(amount), recipient, Util.Money(Gold.Reserve())))
        if dlg then dlg.data = { recipient = recipient } end
        return
    end

    Gold.Execute(recipient)
end

---Performs the transfer. The amount is recalculated here on purpose:
---money may have changed between the dialog and the click.
function Gold.Execute(recipient)
    if pending then return end
    if not Util.MailboxOpen() then return Util.Print(L.NO_MAILBOX) end
    if Util.MailAttachments() > 0 then return Util.Print(L.GOLD_ATTACH) end

    -- re-validate the stored name, never trust the dialog payload alone
    local verified = Gold.Recipient()
    if not verified or verified ~= recipient then return Util.Print(L.GOLD_NONE) end

    local amount = Gold.Sendable()
    if amount <= 0 then return Util.Print(L.GOLD_NOTHING) end

    Util.EnsureMailSendTab()
    Util.Try(SetSendMailCOD, 0)
    Util.Try(SetSendMailMoney, amount)

    local subject = ns.db.subject
    if type(subject) ~= "string" or subject == "" then subject = "Kriegsmeute" end

    if SendMailNameEditBox    then SendMailNameEditBox:SetText(verified) end
    if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText(subject) end

    pending = { recipient = verified, amount = amount }
    Gold:RegisterEvent("MAIL_SEND_SUCCESS")
    Gold:RegisterEvent("MAIL_FAILED")
    Gold:RegisterEvent("MAIL_CLOSED")

    Util.Debug("gold %d copper -> %s", amount, verified)
    SendMail(verified, subject, "")
end

-- --- Cleanup / events --------------------------------------

local function Cleanup()
    Gold:UnregisterAllEvents()
    Util.Try(SetSendMailMoney, 0)
    pending = nil
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    if ns.Config and ns.Config.RefreshSettings then ns.Config:RefreshSettings() end
end

Gold:SetScript("OnEvent", function(_, event)
    if not pending then return end

    if event == "MAIL_SEND_SUCCESS" then
        Util.Print(L.GOLD_SENT, Util.Money(pending.amount), pending.recipient)
        Cleanup()
    elseif event == "MAIL_FAILED" then
        Util.Print(L.GOLD_FAILED)
        Cleanup()
    elseif event == "MAIL_CLOSED" then
        Cleanup()
    end
end)
