-- ============================================================
-- Warbrand-Fast-Mail / Core.lua
-- SavedVariables, public API, slash commands.
-- ============================================================
local ADDON, ns = ...
local L, Util, Scanner, Rules, Mailer = ns.L, ns.Util, ns.Scanner, ns.Rules, ns.Mailer

-- --- Version -----------------------------------------------
-- Version scheme: <wowMajor>.<wowMinor>.<wowPatch>.<build>
-- The first three components are the WoW version this copy was written
-- for, the fourth is the addon's own counter. 12.1.0.5 = fifth build
-- for WoW 12.1.0. A stale copy is therefore detectable at runtime.

ns.VERSION = Util.Meta(ADDON, "Version") or "0.0.0.0"

---@return number|nil major, number|nil minor, number|nil patch, number|nil build
local function ParseVersion()
    local a, b, c, d = ns.VERSION:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    return tonumber(a), tonumber(b), tonumber(c), tonumber(d)
end

---Compares the targeted WoW version against the running client.
---A differing major or minor is a real problem; a differing patch level
---only means the TOC should be refreshed, so the two are reported apart.
---@return boolean exact, boolean severe, string builtText, string clientText, number iface
function ns.VersionCheck()
    local bMaj, bMin, bPat = ParseVersion()
    local iface = Util.ClientInterface()
    local cMaj, cMin, cPat = Util.SplitInterface(iface)

    local clientText = string.format("%d.%d.%d", cMaj, cMin, cPat)
    if not bMaj then return true, false, "?", clientText, iface end

    local builtText = string.format("%d.%d.%d", bMaj, bMin, bPat)
    local exact  = (bMaj == cMaj and bMin == cMin and bPat == cPat)
    local severe = (bMaj ~= cMaj or bMin ~= cMin)
    return exact, severe, builtText, clientText, iface
end

-- --- Defaults ----------------------------------------------

local DEFAULTS = {
    rules          = {},     -- ordered list, see Lib/Rules.lua
    hold           = {},     -- [itemID] = true (never send) | n (keep n)
    target         = "",     -- account-wide default recipient for items
    includeUnbound = false,  -- implicit default rule also takes BoE
    confirm        = true,
    debug          = false,
    subject        = Util.DEFAULT_SUBJECT,
    body           = "",
    gold           = {
        recipient = "",                       -- fixed character, account-wide
        reserve   = 100 * Util.COPPER_PER_GOLD, -- keep 100 gold back
        confirm   = true,
    },
    ui             = { show = true, point = nil, configPoint = nil,
                       holdPoint = nil, settingsPoint = nil },
}

local CHAR_DEFAULTS = {
    target        = "",      -- default recipient for items, overrides db.target
    goldRecipient = "",      -- gold recipient, overrides db.gold.recipient
    goldReserve   = "",      -- copper, overrides db.gold.reserve ("" = inherit)
    hold          = {},      -- [itemID] = true | n, overrides the global entry
}

local function ApplyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ApplyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

-- --- Confirmation popup ------------------------------------

StaticPopupDialogs["WARBRANDFASTMAIL_CONFIRM"] = {
    text           = "%s",
    button1        = SEND or "Send",
    button2        = CANCEL or "Cancel",
    timeout        = 30,
    whileDead      = false,
    hideOnEscape   = true,
    preferredIndex = 3,
    OnAccept = function(_, data)
        if data and data.plan then Mailer:Start(data.plan, data.override, data.withGold) end
    end,
}

local function Launch(plan, override, total, lines, withGold)
    if ns.db.confirm then
        local dlg = StaticPopup_Show("WARBRANDFASTMAIL_CONFIRM",
            string.format(L.CONFIRM, total, lines))
        if dlg then dlg.data = { plan = plan, override = override, withGold = withGold } end
        return
    end
    Util.Print(L.START, total, #plan)
    Mailer:Start(plan, override, withGold)
end

-- --- Public API --------------------------------------------

---Runs every rule plus the implicit default rule.
---@param withGold boolean|nil  also transfer gold, riding on the last
---                             mail to its recipient to save postage
function ns.SendPlan(withGold)
    if Mailer:IsActive() or ns.Gold.IsPending() then return Util.Print(L.BUSY) end
    if not (MailFrame and MailFrame:IsShown()) then return Util.Print(L.NO_MAILBOX) end

    local plan = Rules.BuildPlan()
    local goldTo, goldAmount
    if withGold then
        goldTo = ns.Gold.Recipient()
        goldAmount = goldTo and ns.Gold.Sendable() or 0
    end

    if plan.total == 0 and (goldAmount or 0) <= 0 then return Util.Print(L.NOTHING) end

    local lines = {}
    for _, r in ipairs(plan.order) do
        lines[#lines + 1] = string.format(L.UI_PLANLINE, plan.count[r], r)
    end
    if goldTo and goldAmount > 0 then
        lines[#lines + 1] = string.format(L.UI_GOLD_LINE, Util.Money(goldAmount), goldTo)
    end

    -- Nothing to mail but gold to move: skip the item machinery entirely.
    if plan.total == 0 then return ns.Gold.Send() end

    Launch(plan.order, nil, plan.total, table.concat(lines, "\n"), withGold)
end

---Ignores all rules and sends everything mailable to one recipient.
function ns.SendForce(input)
    if Mailer:IsActive() or ns.Gold.IsPending() then return Util.Print(L.BUSY) end

    local raw = Util.Trim(input or "")
    if raw == "" then raw = Rules.Target() end
    if not raw or raw == "" then return Util.Print(L.TARGET_NONE) end

    local recipient, err = Util.NormalizeRecipient(raw)
    if not recipient then return Util.Print(L.BAD_NAME, tostring(raw) .. " (" .. tostring(err) .. ")") end
    if Util.IsSelf(recipient) then return Util.Print(L.NO_SELF) end
    if not (MailFrame and MailFrame:IsShown()) then return Util.Print(L.NO_MAILBOX) end

    local filter = function(e)
        if Rules.IsIgnored(e.itemID) then return false end
        if e.bind == Scanner.UNBOUND and not ns.db.includeUnbound then return false end
        return true
    end

    local items = Scanner.Collect(nil, filter)
    if #items == 0 then return Util.Print(L.NOTHING) end

    local total = 0
    for _, e in ipairs(items) do total = total + (e.sendQty or e.count or 1) end

    Launch({ recipient }, filter, total, string.format(L.UI_PLANLINE, total, recipient))
end

---Validates a recipient for storage.
---Self is rejected on the character level (pointless and confusing) but
---allowed account-wide, where it is simply inert on that one character.
---@return string|nil value ("" clears the level), string|nil errorReason
function ns.CheckRecipient(input, allowSelf)
    local raw = Util.Trim(input or "")
    if raw == "" then return "" end
    local recipient, err = Util.NormalizeRecipient(raw)
    if not recipient then return nil, err end
    if not allowSelf and Util.IsSelf(recipient) then return nil, "self" end
    return recipient
end

---@param scope string|nil "char" (default) or "global"
function ns.SetTarget(input, scope)
    local global = (scope == "global")
    local value, err = ns.CheckRecipient(input, global)
    if not value then
        return Util.Print(err == "self" and L.NO_SELF or L.BAD_NAME,
                          Util.Trim(input or "") .. " (" .. tostring(err) .. ")")
    end
    if global then ns.db.target = value else ns.charDB.target = value end

    local eff = ns.Rules.Target()
    Util.Print(eff and string.format(L.TARGET_EFF, eff) or L.TARGET_NONE)
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    if ns.Config then ns.Config:RefreshSettings() end
end

---@param scope string|nil "char" (default) or "global"
function ns.SetGoldTarget(input, scope)
    local global = (scope == "global")
    local value, err = ns.CheckRecipient(input, global)
    if not value then
        return Util.Print(err == "self" and L.NO_SELF or L.BAD_NAME,
                          Util.Trim(input or "") .. " (" .. tostring(err) .. ")")
    end
    if global then ns.db.gold.recipient = value else ns.charDB.goldRecipient = value end

    local eff = ns.Gold.Recipient()
    Util.Print(eff and string.format(L.TARGET_EFF, eff) or L.GOLD_NONE)
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    if ns.Config then ns.Config:RefreshSettings() end
end

-- --- Slash commands ----------------------------------------

local function OnOff(v) return v and L.TOGGLE_ON or L.TOGGLE_OFF end

local handlers = {}

handlers["send"] = function() ns.SendPlan(false) end
handlers["s"]    = handlers["send"]

handlers["sendall"] = function() ns.SendPlan(true) end
handlers["alles"]   = handlers["sendall"]

handlers["force"] = function(rest) ns.SendForce(rest) end

---Splits an optional leading "global" / "char" keyword off the argument.
local function SplitScope(rest)
    local head = Util.Trim(rest):match("^(%S*)")
    if head == "global" or head == "char" then
        return head, Util.Trim(rest:sub(#head + 1))
    end
    return "char", Util.Trim(rest)
end

handlers["target"] = function(rest)
    local scope, value = SplitScope(rest)
    if value == "" and Util.Trim(rest) == "" then
        local c, g = ns.charDB.target, ns.db.target
        Util.Print(L.TARGET_CHAR,   (c and c ~= "" and c) or L.SET_NOTSET)
        Util.Print(L.TARGET_GLOBAL, (g and g ~= "" and g) or L.SET_NOTSET)
        local eff = ns.Rules.Target()
        return Util.Print(eff and string.format(L.TARGET_EFF, eff) or L.TARGET_NONE)
    end
    ns.SetTarget(value, scope)
end
handlers["ziel"] = handlers["target"]

handlers["rules"] = function() if ns.Config then ns.Config:ToggleRules() end end
handlers["regeln"] = handlers["rules"]

handlers["hold"] = function(rest)
    rest = Util.Trim(rest)
    local scope = "global"
    local head = rest:match("^(%S*)")
    if head == "char" or head == "global" then
        scope = head
        rest = Util.Trim(rest:sub(#head + 1))
    end

    local idPart, amountPart = rest:match("^(%S*)%s*(%S*)$")
    if not idPart or idPart == "" then
        if ns.Config then ns.Config:ToggleHold() end
        return
    end

    local itemID = Util.ToItemID(idPart)
    if not itemID then return Util.Print(L.BAD_NAME, idPart) end

    if amountPart == "" then
        local v = ns.Hold.Get(itemID)
        if v == nil then return Util.Print(L.HOLD_CLEARED, Util.ItemLink(itemID)) end
        return Util.Print(L.HOLD_SET,
            (v == true) and L.HOLD_ALL or tostring(v), Util.ItemLink(itemID))
    end

    if amountPart == "-" or amountPart == "off" then
        ns.Hold.Clear(itemID)
        Util.Print(L.HOLD_CLEARED, Util.ItemLink(itemID))
    elseif not ns.Hold.Set(itemID, amountPart, scope) then
        return Util.Print(L.HOLD_BADNUM, amountPart)
    else
        local v = ns.Hold.Get(itemID)
        Util.Print(L.HOLD_SET, (v == true) and L.HOLD_ALL or tostring(v), Util.ItemLink(itemID))
    end
    if ns.UI then ns.UI:Refresh() end
end
handlers["ignore"] = handlers["hold"]
handlers["ignorieren"] = handlers["hold"]
handlers["keep"] = handlers["hold"]
handlers["behalten"] = handlers["hold"]

---Prints every number that feeds a hold decision, so a wrong transfer
---can be traced to the exact source instead of guessed at.
handlers["check"] = function(rest)
    local itemID = Util.ToItemID(Util.Trim(rest))
    if not itemID then return Util.Print(L.BAD_NAME, tostring(rest)) end

    local link = Util.ItemLink(itemID)
    local value, scope = ns.Hold.Get(itemID)
    if value == nil then return Util.Print(L.CHECK_NONE, link) end

    local scanTotal = ns.Scanner.BagTotals()[itemID] or 0
    local apiTotal  = ns.Hold.InBags(itemID)
    local budget    = ns.Hold.Budget(itemID, scanTotal)

    Util.Print(L.CHECK_LINE, link,
        (value == true) and L.HOLD_ALL or tostring(value),
        scope or "?", scanTotal, apiTotal,
        (budget == math.huge) and L.CHECK_UNLIMITED or tostring(budget))
end
handlers["pruefen"] = handlers["check"]

handlers["settings"] = function() if ns.Config then ns.Config:ToggleSettings() end end
handlers["einstellungen"] = handlers["settings"]

handlers["gold"] = function() ns.Gold.Send() end

handlers["goldtarget"] = function(rest)
    local scope, value = SplitScope(rest)
    if value == "" and Util.Trim(rest) == "" then
        local c, g = ns.charDB.goldRecipient, ns.db.gold.recipient
        Util.Print(L.GOLD_TARGET_C, (c and c ~= "" and c) or L.SET_NOTSET)
        Util.Print(L.GOLD_TARGET_G, (g and g ~= "" and g) or L.SET_NOTSET)
        local eff = ns.Gold.Recipient()
        return Util.Print(eff and string.format(L.TARGET_EFF, eff) or L.GOLD_NONE)
    end
    ns.SetGoldTarget(value, scope)
end

handlers["reserve"] = function(rest)
    local scope, value = SplitScope(rest)
    if value == "" and Util.Trim(rest) == "" then
        local c = ns.charDB.goldReserve
        Util.Print(L.TARGET_CHAR,
            (type(c) == "number") and Util.Money(c) or L.SET_NOTSET)
        Util.Print(L.TARGET_GLOBAL, Util.Money(ns.db.gold.reserve))
        return Util.Print(L.SET_SENDABLE, Util.Money(ns.Gold.Sendable()))
    end

    if scope == "char" and (value == "-" or value == "off") then
        ns.charDB.goldReserve = ""
    else
        local copper = Util.GoldToCopper(value)
        if not copper then return Util.Print(L.SET_BADRESERVE, tostring(value)) end
        if scope == "char" then ns.charDB.goldReserve = copper
        else ns.db.gold.reserve = copper end
    end
    Util.Print(L.SET_SENDABLE, Util.Money(ns.Gold.Sendable()))
    if ns.UI then ns.UI:Refresh() end
    if ns.Config then ns.Config:RefreshSettings() end
end
handlers["ruecklage"] = handlers["reserve"]

handlers["list"] = function()
    local plan = Rules.BuildPlan()
    if plan.total == 0 and plan.unrouted == 0 and plan.ignored == 0 and plan.staying == 0 then
        return Util.Print(L.NOTHING)
    end
    for _, r in ipairs(plan.order) do
        Util.Print("  " .. L.UI_PLANLINE, plan.count[r], r)
    end
    if plan.staying  > 0 then Util.Print("  " .. L.UI_STAYING,  plan.staying) end
    if plan.unrouted > 0 then Util.Print("  " .. L.UI_UNROUTED, plan.unrouted) end
    if plan.ignored  > 0 then Util.Print("  " .. L.UI_IGNORED,  plan.ignored) end
end

handlers["unbound"] = function()
    ns.db.includeUnbound = not ns.db.includeUnbound
    Util.Print(L.UNBOUND_STATE, OnOff(ns.db.includeUnbound))
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

handlers["confirm"] = function()
    ns.db.confirm = not ns.db.confirm
    Util.Print(L.CONFIRM_STATE, OnOff(ns.db.confirm))
end

handlers["debug"] = function()
    ns.db.debug = not ns.db.debug
    Util.Print(L.DEBUG_STATE, OnOff(ns.db.debug))
end

handlers["version"] = function()
    local exact, severe, built, client, iface = ns.VersionCheck()
    Util.Print(L.VERSION_LINE, ns.VERSION, built)
    Util.Print(L.VERSION_CLIENT, client, iface)
    if severe then
        Util.Print(L.VERSION_MISMATCH, built, client)
    elseif not exact then
        Util.Print(L.VERSION_PATCH, built, client)
    end
end
handlers["v"] = handlers["version"]

handlers["ui"] = function()
    ns.db.ui.show = not ns.db.ui.show
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

local function Help()
    Util.Print(L.HELP_HEADER)
    for _, line in ipairs({
        L.HELP_SEND, L.HELP_FORCE, L.HELP_TARGET, L.HELP_GOLD, L.HELP_GOLDTGT, L.HELP_RULES,
        L.HELP_HOLD, L.HELP_CHECK, L.HELP_SETTINGS, L.HELP_LIST, L.HELP_UNBOUND,
        L.HELP_CONFIRM, L.HELP_UI, L.HELP_DEBUG, L.HELP_VERSION,
    }) do
        Util.Print("  " .. line)
    end
end

-- No short generic alias on purpose: "/warbrand" is the kind of name
-- another addon claims, and the last registration wins.
SLASH_WARBRANDFASTMAIL1 = "/warbrand-fast-mail"
SLASH_WARBRANDFASTMAIL2 = "/wfm"
SlashCmdList["WARBRANDFASTMAIL"] = function(msg)
    msg = Util.Trim(tostring(msg or ""))
    local cmd, rest = msg:match("^(%S*)%s*(.*)$")
    local fn = handlers[(cmd or ""):lower()]
    if fn then fn(rest or "") else Help() end
end

function WarbrandFastMail_OnCompartmentClick()
    if ns.Config then ns.Config:ToggleRules() end
end

-- --- Init --------------------------------------------------

local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")

    WarbrandFastMailDB     = ApplyDefaults(WarbrandFastMailDB or {}, DEFAULTS)
    WarbrandFastMailCharDB = ApplyDefaults(WarbrandFastMailCharDB or {}, CHAR_DEFAULTS)
    ns.db     = WarbrandFastMailDB
    ns.charDB = WarbrandFastMailCharDB

    -- migrate older profiles: separate ignore/keep tables become one
    -- hold list, and the temporary locale registrar is retired.
    if ns.db.minQuality ~= nil then ns.db.minQuality = nil end
    ns.Hold.Migrate(ns.db)
    ns.Hold.Migrate(ns.charDB)
    -- Earlier builds defaulted the subject to "Kriegsmeute", then to
    -- "Warband". ApplyDefaults only fills nil, so a stored default would
    -- outlive the rename; a subject the user typed themselves is kept.
    if ns.db.subject == "Warband" or ns.db.subject == "Kriegsmeute" then
        ns.db.subject = Util.DEFAULT_SUBJECT
    end
    _G.WarbrandFastMail_RegisterLocale = nil
    if type(ns.db.target) ~= "string" then ns.db.target = "" end
    if type(ns.charDB.target) ~= "string" then ns.charDB.target = "" end
    if type(ns.charDB.goldRecipient) ~= "string" then ns.charDB.goldRecipient = "" end
    for _, rule in ipairs(ns.db.rules) do
        if rule.scope ~= "char" then rule.scope, rule.owner = "global", nil end
    end
    if type(ns.db.gold.reserve) ~= "number" or ns.db.gold.reserve < 0 then
        ns.db.gold.reserve = 100 * Util.COPPER_PER_GOLD
    end
    if type(ns.charDB.goldReserve) == "number" and ns.charDB.goldReserve < 0 then
        ns.charDB.goldReserve = ""
    end

    if ns.UI and ns.UI.Init then ns.UI:Init() end
    Util.Print(L.LOADED, ns.VERSION)

    -- Only shout when the client changed branch. A pure patch-level
    -- difference stays quiet and is visible via /wfm version.
    local _, severe, built, client = ns.VersionCheck()
    if severe then Util.Print(L.VERSION_MISMATCH, built, client) end
end)
