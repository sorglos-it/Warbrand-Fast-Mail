-- ============================================================
-- Warbrand-Fast-Mail / UI.lua
-- Panel next to the mailbox.
--
-- Visibility is driven by MailFrame:HookScript("OnShow"/"OnHide"),
-- NOT by the MAIL_SHOW event. MAIL_SHOW fires before Blizzard
-- calls ShowUIPanel(MailFrame), so MailFrame:IsShown() is still
-- false at that moment -- that race is what kept the panel hidden
-- in 1.0.0.
-- ============================================================
local ADDON, ns = ...
local L, Util, Rules, Mailer, Gold, W = ns.L, ns.Util, ns.Rules, ns.Mailer, ns.Gold, ns.Widgets

local UI = {}
ns.UI = UI

local panel
local PLAN_LINES = 5
local hooked = false

-- --- Construction ------------------------------------------

local function BuildPanel()
    local f = W.Window(ADDON .. "Panel", 250, 306, L.UI_TITLE, nil, nil, true)
    f:SetFrameStrata("HIGH")

    -- close button only hides for this session
    f.closeButton:SetScript("OnClick", function()
        ns.db.ui.show = false
        f:Hide()
    end)

    -- Rules, hold list and settings are children of this panel. Hooking
    -- OnHide covers every way it can disappear at once: the X button,
    -- closing the mailbox, MAIL_CLOSED and /wfm ui.
    f:SetScript("OnHide", function()
        if ns.Config then ns.Config:CloseAll() end
    end)

    -- persist position on this frame's own key
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.db.ui.point = { p, rp, x, y }
    end)

    -- default recipient
    local lbl = W.Label(f, L.UI_FALLBACK)
    lbl:SetPoint("TOPLEFT", 14, -34)

    local eb = W.EditBox(f, 214, 48, function(_, text) ns.SetTarget(text, "char") end)
    eb:SetPoint("TOPLEFT", 18, -48)
    eb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.UI_FALLBACK, 1, 1, 1)
        GameTooltip:AddLine(L.SET_INHERIT, nil, nil, nil, true)
        GameTooltip:AddDoubleLine(L.TARGET_EFF:gsub("|cffffff00%%s|r", ""),
                                  Rules.Target() or L.SET_NOTSET, 1, 1, 1)
        GameTooltip:Show()
    end)
    eb:SetScript("OnLeave", GameTooltip_Hide)
    f.name = eb

    -- unbound toggle
    local cb = W.CheckBox(f, L.UI_UNBOUND, function(self)
        ns.db.includeUnbound = self:GetChecked() and true or false
        UI:Refresh()
    end)
    cb:SetPoint("TOPLEFT", 12, -70)
    cb.Text:SetWidth(200)
    f.unbound = cb

    -- plan preview
    f.lines = {}
    for i = 1, PLAN_LINES do
        local fs = W.Label(f, "")
        fs:SetPoint("TOPLEFT", 18, -98 - (i - 1) * 14)
        fs:SetWidth(212)
        f.lines[i] = fs
    end

    -- gold summary
    f.goldLine = W.Label(f, "")
    f.goldLine:SetPoint("TOPLEFT", 18, -172)
    f.goldLine:SetWidth(212)

    -- buttons: 4 rows, 2 columns
    local sendAll = W.Button(f, 220, L.UI_SENDALL, function() ns.SendPlan(true) end)
    sendAll:SetPoint("BOTTOMLEFT", 14, 98)
    sendAll:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.UI_SENDALL, 1, 1, 1)
        GameTooltip:AddLine(L.UI_SENDALL_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    sendAll:SetScript("OnLeave", GameTooltip_Hide)
    f.sendAll = sendAll

    local send = W.Button(f, 108, L.UI_SEND, function() ns.SendPlan(false) end)
    send:SetPoint("BOTTOMLEFT", 14, 74)
    send:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.UI_TITLE, 1, 1, 1)
        GameTooltip:AddLine(L.UI_TOOLTIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    send:SetScript("OnLeave", GameTooltip_Hide)
    f.send = send

    local gold = W.Button(f, 108, L.UI_GOLD, function() Gold.Send() end)
    gold:SetPoint("BOTTOMRIGHT", -14, 74)
    gold:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.UI_GOLD, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.SET_RESERVE, Util.Money(Gold.Reserve()), 1, 1, 1)
        GameTooltip:AddDoubleLine(L.UI_GOLD, Util.Money(Gold.Sendable()), 1, 1, 1)
        GameTooltip:Show()
    end)
    gold:SetScript("OnLeave", GameTooltip_Hide)
    f.gold = gold

    local rules = W.Button(f, 108, L.UI_RULES, function() ns.Config:ToggleRules() end)
    rules:SetPoint("BOTTOMLEFT", 14, 50)

    local hold = W.Button(f, 108, L.UI_HOLD, function() ns.Config:ToggleHold() end)
    hold:SetPoint("BOTTOMRIGHT", -14, 50)
    hold:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.HOLD_TITLE, 1, 1, 1)
        GameTooltip:AddLine(L.HOLD_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    hold:SetScript("OnLeave", GameTooltip_Hide)

    local settings = W.Button(f, 108, L.UI_SETTINGS, function() ns.Config:ToggleSettings() end)
    settings:SetPoint("BOTTOMLEFT", 14, 26)

    local scan = W.Button(f, 108, L.UI_SCAN, function() UI:Refresh() end)
    scan:SetPoint("BOTTOMRIGHT", -14, 26)

    -- version stamp, bottom right
    f.version = W.Label(f, "v" .. (ns.VERSION or "?"), "GameFontDisableSmall")
    f.version:SetPoint("BOTTOMRIGHT", -16, 8)
    f.version:SetJustifyH("RIGHT")

    local vHit = CreateFrame("Frame", nil, f)
    vHit:SetPoint("TOPLEFT", f.version, "TOPLEFT", -2, 2)
    vHit:SetPoint("BOTTOMRIGHT", f.version, "BOTTOMRIGHT", 2, -2)
    vHit:EnableMouse(true)
    vHit:SetScript("OnEnter", function(self)
        local exact, severe, built, client, iface = ns.VersionCheck()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(string.format(L.VERSION_LINE, ns.VERSION, built), 1, 1, 1)
        GameTooltip:AddLine(string.format(L.VERSION_CLIENT, client, iface), nil, nil, nil, true)
        if severe then
            GameTooltip:AddLine(string.format(L.VERSION_MISMATCH, built, client), 1, 0.2, 0.2, true)
        elseif not exact then
            GameTooltip:AddLine(string.format(L.VERSION_PATCH, built, client), 0.9, 0.8, 0.2, true)
        end
        if ns.localeLoaded then
            GameTooltip:AddLine(string.format(L.LOCALE_INFO, ns.localeLoaded), nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    vHit:SetScript("OnLeave", GameTooltip_Hide)

    return f
end

local function Reposition()
    panel:ClearAllPoints()
    local p = ns.db.ui.point
    if p and p[1] then
        panel:SetPoint(p[1], UIParent, p[2] or "CENTER", p[3] or 0, p[4] or 0)
    elseif MailFrame then
        panel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 4, -8)
    else
        panel:SetPoint("CENTER")
    end
end

-- --- Refresh -----------------------------------------------

function UI:Refresh(skipPlan)
    if not panel then return end

    if not (ns.db.ui.show and MailFrame and MailFrame:IsShown()) then
        return panel:Hide()
    end

    Reposition()
    panel:Show()

    panel.unbound:SetChecked(ns.db.includeUnbound and true or false)
    if not panel.name:HasFocus() then
        panel.name:SetText(ns.charDB.target or "")
    end

    if skipPlan then return end

    local plan = Rules.BuildPlan()
    local shown = 0

    for i = 1, PLAN_LINES do
        local fs = panel.lines[i]
        local recipient = plan.order[i]
        if recipient and i < PLAN_LINES then
            fs:SetText(string.format(L.UI_PLANLINE, plan.count[recipient], recipient))
            shown = i
        else
            fs:SetText("")
        end
    end

    -- last line carries the overflow / summary
    local extra = {}
    if #plan.order > PLAN_LINES - 1 then
        local rest = 0
        for i = PLAN_LINES, #plan.order do rest = rest + plan.count[plan.order[i]] end
        extra[#extra + 1] = "|cff888888+ " .. rest .. " ...|r"
    end
    if plan.staying  > 0 then extra[#extra + 1] = string.format(L.UI_STAYING, plan.staying) end
    if plan.unrouted > 0 then extra[#extra + 1] = string.format(L.UI_UNROUTED, plan.unrouted) end
    if plan.ignored  > 0 then extra[#extra + 1] = string.format(L.UI_IGNORED, plan.ignored) end
    panel.lines[PLAN_LINES]:SetText(table.concat(extra, "  "))

    if plan.total == 0 and shown == 0 then
        panel.lines[1]:SetText("|cff888888" .. L.UI_NOTHING .. "|r")
    end

    local busy = Mailer:IsActive() or Gold.IsPending()
    panel.send:SetEnabled(plan.total > 0 and not busy)

    -- gold
    local recipient = Gold.Recipient()
    local sendable  = Gold.Sendable()
    if recipient then
        panel.goldLine:SetText(string.format(L.UI_GOLD_LINE, Util.Money(sendable), recipient))
    else
        panel.goldLine:SetText(L.UI_GOLD_NONE)
    end
    panel.gold:SetEnabled(recipient ~= nil and sendable > 0 and not busy)
    panel.sendAll:SetEnabled(not busy
        and (plan.total > 0 or (recipient ~= nil and sendable > 0)))
end

-- --- Mailbox hooks -----------------------------------------

local function HookMailFrame()
    if hooked or not MailFrame then return end
    hooked = true
    MailFrame:HookScript("OnShow", function()
        ns.db.ui.show = true
        UI:Refresh()
    end)
    MailFrame:HookScript("OnHide", function()
        if panel then panel:Hide() end
    end)
    -- mailbox may already be open when the addon initialises
    if MailFrame:IsShown() then UI:Refresh() end
    Util.Debug("MailFrame hooked")
end

-- --- Init --------------------------------------------------

function UI:Init()
    if panel then return end
    panel = BuildPanel()
    panel:Hide()

    HookMailFrame()

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:RegisterEvent("ADDON_LOADED")     -- Blizzard_MailFrame may load on demand
    ev:RegisterEvent("MAIL_SHOW")
    ev:RegisterEvent("MAIL_CLOSED")
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:RegisterEvent("PLAYER_MONEY")
    ev:SetScript("OnEvent", function(self, event)
        if event == "MAIL_CLOSED" then
            panel:Hide()
            return
        end
        HookMailFrame()
        if hooked and event == "ADDON_LOADED" then
            self:UnregisterEvent("ADDON_LOADED")
        end
        -- next frame: by then Blizzard has actually shown MailFrame
        C_Timer.After(0, function() UI:Refresh() end)
    end)
end

function UI:IsShown()
    return panel and panel:IsShown()
end

function UI:GetFrame()
    return panel
end
