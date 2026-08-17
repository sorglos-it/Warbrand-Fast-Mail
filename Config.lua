-- ============================================================
-- Warbrand-Fast-Mail / Config.lua
-- Rule manager and ignore list.
-- ============================================================
local ADDON, ns = ...
local L, Util, Rules, W = ns.L, ns.Util, ns.Rules, ns.Widgets

local Config = {}
ns.Config = Config

local rulesWin, holdWin, settingsWin
local ruleSearch = ""

-- Every sub window belongs to one exclusive group: opening one closes
-- the others and raises the new one inside its strata. Without this a
-- second window opens *behind* the first, which looks like a dead click.
local group = {}

local function Register(f)
    f:SetFrameStrata("DIALOG")
    group[#group + 1] = f
    return f
end

---Closes every sub window. The panel calls this when it hides, so the
---children can never outlive their parent.
function Config:CloseAll()
    for _, win in ipairs(group) do
        if win:IsShown() then win:Hide() end
    end
end

local function Toggle(win)
    if win:IsShown() then
        win:Hide()
        return false
    end
    for _, other in ipairs(group) do
        if other ~= win and other:IsShown() then other:Hide() end
    end
    win:RestorePosition(ns.UI and ns.UI:GetFrame())
    win:Show()
    win:Raise()
    return true
end
local ROW_H, ROWS = 24, 6
local offset, selected, draft = 0, nil, nil

-- --- Scope selector ----------------------------------------
-- Small dropdown deciding where NEW entries of a list go.

local function ScopeSelector(parent, width, get, set)
    return W.Dropdown(parent, width, function()
        return {
            { value = "global", text = L.SCOPE_GLOBAL },
            { value = "char",   text = string.format(L.SCOPE_CHAR, Util.MyFullName()) },
        }
    end, function(v) set(v == "char" and "char" or "global") end, L.SCOPE_GLOBAL)
end

-- --- Draft handling ----------------------------------------

local function CopyRule(src)
    local r = Rules.New()
    if not src then return r end
    r.enabled    = src.enabled ~= false
    r.label      = src.label or ""
    r.recipient  = src.recipient or ""
    r.classID    = src.classID
    r.subclassID = src.subclassID
    r.bind       = src.bind or "any"
    r.minQuality = src.minQuality or 0
    r.scope      = src.scope or "global"
    r.owner      = src.owner
    r.items      = {}
    if type(src.items) == "table" then
        for id in pairs(src.items) do r.items[id] = true end
    end
    return r
end

-- --- Editor ------------------------------------------------

local function LoadDraftIntoEditor()
    local e = rulesWin.editor
    e.name:SetText(draft.label or "")
    e.recipient:SetText(draft.recipient or "")
    e.scope:SetValue(draft.scope or "global", true)
    e.category:SetValue(draft.classID, true)
    e.subcategory:SetValue(draft.subclassID, true)
    e.bind:SetValue(draft.bind or "any", true)
    e.quality:SetValue(draft.minQuality or 0, true)
    e.items:Refresh()
    e.delete:SetEnabled(selected ~= nil)
end

local function BuildEditor(f)
    local e = {}
    f.editor = e

    local header = W.Label(f, L.CFG_EDIT, "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", 14, -262)

    local nameLbl = W.Label(f, L.CFG_NAME)
    nameLbl:SetPoint("TOPLEFT", 18, -280)
    e.name = W.EditBox(f, 280, 48, function(self) draft.label = Util.Trim(self:GetText()) end)
    e.name:SetPoint("TOPLEFT", 22, -294)
    e.name:SetScript("OnTextChanged", function(self) draft.label = Util.Trim(self:GetText()) end)

    local scopeLbl = W.Label(f, L.SCOPE_LABEL)
    scopeLbl:SetPoint("TOPLEFT", 320, -280)
    e.scope = W.Dropdown(f, 180, function()
        return {
            { value = "global", text = L.SCOPE_GLOBAL },
            { value = "char",   text = string.format(L.SCOPE_CHAR,
                                          (draft and draft.owner) or Util.MyFullName()) },
        }
    end, function(v) draft.scope = (v == "char") and "char" or "global" end, L.SCOPE_GLOBAL)
    e.scope:SetPoint("TOPLEFT", 320, -295)

    local rcptLbl = W.Label(f, L.CFG_RECIPIENT)
    rcptLbl:SetPoint("TOPLEFT", 18, -320)
    e.recipient = W.EditBox(f, 480, 48)
    e.recipient:SetPoint("TOPLEFT", 22, -334)
    e.recipient:SetScript("OnTextChanged", function(self) draft.recipient = Util.Trim(self:GetText()) end)

    -- category / subcategory
    local catLbl = W.Label(f, L.CFG_CATEGORY)
    catLbl:SetPoint("TOPLEFT", 18, -362)
    e.category = W.Dropdown(f, 225, function()
        local list = { { value = nil, text = L.CFG_ALL } }
        for _, it in ipairs(ns.Categories.Classes()) do
            list[#list + 1] = { value = it.value, text = it.text }
        end
        return list
    end, function(v)
        draft.classID = v
        draft.subclassID = nil
        e.subcategory:SetValue(nil, true)
    end, L.CFG_ALL)
    e.category:SetPoint("TOPLEFT", 18, -376)

    local subLbl = W.Label(f, L.CFG_SUBCAT)
    subLbl:SetPoint("TOPLEFT", 262, -362)
    e.subcategory = W.Dropdown(f, 225, function()
        local list = { { value = nil, text = L.CFG_ALL } }
        for _, it in ipairs(ns.Categories.SubClasses(draft and draft.classID)) do
            list[#list + 1] = it
        end
        return list
    end, function(v) draft.subclassID = v end, L.CFG_ALL)
    e.subcategory:SetPoint("TOPLEFT", 262, -376)

    -- bind / quality
    local bindLbl = W.Label(f, L.CFG_BIND)
    bindLbl:SetPoint("TOPLEFT", 18, -406)
    e.bind = W.Dropdown(f, 225, function()
        local list = {}
        for _, v in ipairs(Rules.BIND_VALUES) do
            list[#list + 1] = { value = v, text = Rules.BindText(v) }
        end
        return list
    end, function(v) draft.bind = v end, L.BIND_ANY)
    e.bind:SetPoint("TOPLEFT", 18, -420)

    local qLbl = W.Label(f, L.CFG_QUALITY)
    qLbl:SetPoint("TOPLEFT", 262, -406)
    e.quality = W.Dropdown(f, 225, function()
        local list = {}
        for q = 0, 7 do list[#list + 1] = { value = q, text = Util.QualityName(q) } end
        return list
    end, function(v) draft.minQuality = v or 0 end, Util.QualityName(0))
    e.quality:SetPoint("TOPLEFT", 262, -420)

    -- explicit item list
    local itemLbl = W.Label(f, L.CFG_ONLYITEMS, "GameFontNormalSmall")
    itemLbl:SetPoint("TOPLEFT", 18, -450)

    e.items = W.ItemScopeList(f, 330, 68, {
        getGlobal = function() return draft and draft.items end,
    })
    e.items:SetPoint("TOPLEFT", 18, -464)
    e.items.hint:SetPoint("TOPLEFT", 356, -468)
    e.items.hint:SetWidth(146)

    e.apply = W.Button(f, 140, L.CFG_APPLY, function()
        draft.label     = Util.Trim(e.name:GetText())
        draft.recipient = Util.Trim(e.recipient:GetText())
        local idx, err = Rules.Save(selected, CopyRule(draft))
        if not idx then
            return Util.Print(L.BAD_NAME, draft.recipient .. " (" .. tostring(err) .. ")")
        end
        selected = idx
        Util.Print(L.CFG_RULE_SAVED, Rules.Describe(ns.db.rules[idx], idx))
        Config:Refresh()
        if ns.UI then ns.UI:Refresh() end
    end)
    e.apply:SetPoint("BOTTOMLEFT", 14, 12)

    e.delete = W.Button(f, 140, L.CFG_DELETE, function()
        if not selected then return end
        local removed = Rules.Delete(selected)
        if removed then Util.Print(L.CFG_RULE_DEL, Rules.Describe(removed, selected)) end
        selected, draft = nil, CopyRule(nil)
        Config:Refresh()
        if ns.UI then ns.UI:Refresh() end
    end)
    e.delete:SetPoint("BOTTOMLEFT", 162, 12)
end

-- --- Rule list ---------------------------------------------

local function BuildList(f)
    local list = CreateFrame("Frame", nil, f, "BackdropTemplate")
    list:SetSize(492, 152)
    list:SetPoint("TOPLEFT", 14, -74)
    list:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    list:SetBackdropColor(0, 0, 0, 0.6)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta)
        Config:Refresh()
    end)

    list.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, list)
        row:SetSize(480, ROW_H)
        row:SetPoint("TOPLEFT", 6, -5 - (i - 1) * ROW_H)

        row.sel = row:CreateTexture(nil, "BACKGROUND")
        row.sel:SetAllPoints()
        row.sel:SetColorTexture(0.2, 0.6, 0.2, 0.35)
        row.sel:Hide()

        row.hl = row:CreateTexture(nil, "HIGHLIGHT")
        row.hl:SetAllPoints()
        row.hl:SetColorTexture(1, 1, 1, 0.10)

        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetSize(20, 20)
        row.check:SetPoint("LEFT", 2, 0)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 26, 0)
        row.text:SetPoint("RIGHT", -74, 0)
        row.text:SetJustifyH("LEFT")

        local function MiniButton(label, xOff, tip)
            local b = CreateFrame("Button", nil, row)
            b:SetSize(20, 20)
            b:SetPoint("RIGHT", xOff, 0)
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            b.fs:SetPoint("CENTER")
            b.fs:SetText(label)
            b.tip = tip
            return b
        end

        row.up   = MiniButton("|cffaaaaaa^|r", -50)
        row.down = MiniButton("|cffaaaaaav|r", -28)
        row.del  = MiniButton("|cffff4040x|r", -6)

        list.rows[i] = row
    end

    f.list = list
end

-- --- Refresh -----------------------------------------------

---Indices of the rules passing the current search box, in order.
local function FilteredIndices()
    local out = {}
    for i, rule in ipairs(ns.db.rules) do
        if ruleSearch == "" then
            out[#out + 1] = i
        else
            local hay = table.concat({
                rule.label or "", rule.recipient or "",
                Rules.Describe(rule, i), rule.owner or "",
            }, " ")
            local hit = Util.Matches(hay, ruleSearch)
            if not hit and type(rule.items) == "table" then
                for id in pairs(rule.items) do
                    if tostring(id):find(ruleSearch, 1, true)
                       or Util.Matches(Util.ItemName(id), ruleSearch) then
                        hit = true
                        break
                    end
                end
            end
            if hit then out[#out + 1] = i end
        end
    end
    return out
end

function Config:Refresh()
    if not rulesWin then return end

    local rules = ns.db.rules
    local view = FilteredIndices()
    local maxOffset = math.max(0, #view - ROWS)
    if offset > maxOffset then offset = maxOffset end

    for i = 1, ROWS do
        local row = rulesWin.list.rows[i]
        local index = view[i + offset]
        local rule = index and rules[index]

        if rule then
            row.index = index
            local mark = ""
            if rule.scope == "char" then
                mark = Rules.AppliesHere(rule)
                    and ("|cff66bbff[" .. L.SCOPE_MARK_C .. "]|r ")
                    or  ("|cff555555[" .. (rule.owner or "?") .. "]|r ")
            end
            -- A rule aimed at the current character can never fire here;
            -- say so instead of letting it look broken.
            local tail = ""
            if Rules.IsInert(rule) then
                tail = "  |cff888888(" .. L.CFG_INERT .. ")|r"
            end
            row.text:SetText(mark .. Rules.Describe(rule, index)
                .. "  |cff888888->|r |cffffff00" .. (rule.recipient or "?") .. "|r" .. tail)
            row:SetScript("OnEnter", function(self)
                if not Rules.IsInert(rule) then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L.CFG_INERT, 1, 1, 1)
                GameTooltip:AddLine(L.CFG_INERT_TIP, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", GameTooltip_Hide)
            row.check:SetChecked(rule.enabled ~= false)
            row.check:SetScript("OnClick", function(self)
                rule.enabled = self:GetChecked() and true or false
                if ns.UI then ns.UI:Refresh() end
            end)
            row:SetScript("OnClick", function()
                selected = index
                draft = CopyRule(rules[index])
                Config:Refresh()
                LoadDraftIntoEditor()
            end)
            row.up:SetScript("OnClick", function()
                if Rules.Move(index, -1) then
                    if selected == index then selected = index - 1 end
                    Config:Refresh(); if ns.UI then ns.UI:Refresh() end
                end
            end)
            row.down:SetScript("OnClick", function()
                if Rules.Move(index, 1) then
                    if selected == index then selected = index + 1 end
                    Config:Refresh(); if ns.UI then ns.UI:Refresh() end
                end
            end)
            row.del:SetScript("OnClick", function()
                local removed = Rules.Delete(index)
                if removed then Util.Print(L.CFG_RULE_DEL, Rules.Describe(removed, index)) end
                if selected == index then selected, draft = nil, CopyRule(nil) end
                Config:Refresh(); LoadDraftIntoEditor()
                if ns.UI then ns.UI:Refresh() end
            end)
            row.sel:SetShown(selected == index)
            row:Show()
        else
            row:Hide()
        end
    end

    rulesWin.empty:SetShown(#view == 0)
    rulesWin.empty:SetText(#rules == 0 and L.CFG_NORULES or L.SEARCH_NONE)
    rulesWin.editor.delete:SetEnabled(selected ~= nil)
    rulesWin.editor.items:Refresh()
end

-- --- Windows -----------------------------------------------

local function BuildRulesWindow()
    local f = W.Window(ADDON .. "Rules", 520, 612, L.CFG_TITLE, ns.db.ui, "configPoint")

    local hint = W.Label(f, L.CFG_HINT, "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 14, -34)

    local searchLbl = W.Label(f, L.SEARCH)
    searchLbl:SetPoint("TOPLEFT", 14, -50)
    local search = W.EditBox(f, 396, 48)
    search:SetPoint("TOPLEFT", 74, -48)
    search:SetScript("OnTextChanged", function(self)
        ruleSearch = Util.Trim(self:GetText())
        Config:Refresh()
    end)
    search:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.SEARCH_RULES, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    search:SetScript("OnLeave", GameTooltip_Hide)
    f.search = search

    local clearSearch = W.Button(f, 24, "x", function()
        search:SetText("")
        search:ClearFocus()
    end)
    clearSearch:SetPoint("TOPLEFT", 476, -49)

    BuildList(f)

    f.empty = W.Label(f.list, L.CFG_NORULES, "GameFontDisableSmall")
    f.empty:SetPoint("TOPLEFT", 10, -10)

    local newBtn = W.Button(f, 140, L.CFG_NEW, function()
        selected = nil
        draft = CopyRule(nil)
        Config:Refresh()
        LoadDraftIntoEditor()
        f.editor.recipient:SetFocus()
    end)
    newBtn:SetPoint("TOPLEFT", 14, -232)

    BuildEditor(f)
    return f
end

local function BuildHoldWindow()
    local f = W.Window(ADDON .. "Hold", 460, 400, L.HOLD_TITLE, ns.db.ui, "holdPoint")
    f.newScope = "global"

    local hint = W.Label(f, L.HOLD_HINT, "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 14, -34)

    local searchLbl = W.Label(f, L.SEARCH)
    searchLbl:SetPoint("TOPLEFT", 18, -56)
    local search = W.EditBox(f, 330, 48)
    search:SetPoint("TOPLEFT", 76, -54)
    search:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.SEARCH_HINT, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    search:SetScript("OnLeave", GameTooltip_Hide)
    f.search = search

    local box = W.ItemScopeList(f, 424, 200, {
        counted     = true,
        getGlobal   = function() return ns.db.hold end,
        getChar     = function() return ns.charDB.hold end,
        getNewScope = function() return f.newScope end,
        getSearch   = function() return f.search:GetText() end,
        onChange    = function() if ns.UI then ns.UI:Refresh() end end,
    })
    -- 16px lower than the list would otherwise sit: the "Keep" column
    -- header hangs off this frame's top edge and needs a band of its own,
    -- or it lands on top of the search row.
    box:SetPoint("TOPLEFT", 18, -96)

    search:SetScript("OnTextChanged", function()
        box:ResetScroll()
        box:Refresh()
    end)

    local clearSearch = W.Button(f, 24, "x", function()
        search:SetText("")
        search:ClearFocus()
    end)
    clearSearch:SetPoint("TOPLEFT", 412, -55)

    local col = W.Label(f, L.HOLD_COL, "GameFontNormalSmall")
    col:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -26, 2)

    box.hint:SetPoint("TOPLEFT", 18, -304)

    local scopeLbl = W.Label(f, L.SCOPE_NEW)
    scopeLbl:SetPoint("TOPLEFT", 18, -330)
    local sel = ScopeSelector(f, 200, nil, function(v) f.newScope = v end)
    sel:SetPoint("TOPLEFT", 128, -326)
    sel:SetValue("global", true)

    f.box = box
    return f
end

local function BuildSettingsWindow()
    local f = W.Window(ADDON .. "Settings", 440, 556, L.SET_TITLE, ns.db.ui, "settingsPoint")
    local s = {}
    f.s = s

    local hint = W.Label(f, L.SET_INHERIT, "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 14, -34)

    -- ---------- section: this character ----------
    s.secChar = W.Label(f, "", "GameFontNormalSmall")
    s.secChar:SetPoint("TOPLEFT", 14, -58)

    local cItemLbl = W.Label(f, L.SET_ITEMRCPT)
    cItemLbl:SetPoint("TOPLEFT", 22, -76)
    s.charTarget = W.EditBox(f, 392, 48)
    s.charTarget:SetPoint("TOPLEFT", 26, -90)

    local cGoldLbl = W.Label(f, L.SET_GOLDRCPT)
    cGoldLbl:SetPoint("TOPLEFT", 22, -116)
    s.charGold = W.EditBox(f, 392, 48)
    s.charGold:SetPoint("TOPLEFT", 26, -130)

    local cResLbl = W.Label(f, L.SET_RESERVE)
    cResLbl:SetPoint("TOPLEFT", 22, -156)
    s.charReserve = W.EditBox(f, 110, 12)
    s.charReserve:SetPoint("TOPLEFT", 26, -170)
    s.charReserve:SetNumeric(true)

    local cResHint = W.Label(f, L.SET_INHERIT, "GameFontDisableSmall")
    cResHint:SetPoint("LEFT", s.charReserve, "RIGHT", 10, 0)

    -- ---------- section: all characters ----------
    local secGlobal = W.Label(f, L.SET_SEC_GLOBAL, "GameFontNormalSmall")
    secGlobal:SetPoint("TOPLEFT", 14, -200)

    local gItemLbl = W.Label(f, L.SET_ITEMRCPT)
    gItemLbl:SetPoint("TOPLEFT", 22, -218)
    s.globalTarget = W.EditBox(f, 392, 48)
    s.globalTarget:SetPoint("TOPLEFT", 26, -232)

    local gGoldLbl = W.Label(f, L.SET_GOLDRCPT)
    gGoldLbl:SetPoint("TOPLEFT", 22, -258)
    s.globalGold = W.EditBox(f, 392, 48)
    s.globalGold:SetPoint("TOPLEFT", 26, -272)

    local gResLbl = W.Label(f, L.SET_RESERVE)
    gResLbl:SetPoint("TOPLEFT", 22, -298)
    s.reserve = W.EditBox(f, 110, 12)
    s.reserve:SetPoint("TOPLEFT", 26, -312)
    s.reserve:SetNumeric(true)

    local resHint = W.Label(f, L.SET_RESERVEHINT, "GameFontDisableSmall")
    resHint:SetPoint("LEFT", s.reserve, "RIGHT", 10, 0)

    s.sendable = W.Label(f, "")
    s.sendable:SetPoint("TOPLEFT", 26, -336)

    s.goldConfirm = W.CheckBox(f, L.SET_GOLDCONFIRM)
    s.goldConfirm:SetPoint("TOPLEFT", 20, -356)

    s.confirm = W.CheckBox(f, L.SET_CONFIRM)
    s.confirm:SetPoint("TOPLEFT", 20, -380)

    s.unbound = W.CheckBox(f, L.UI_UNBOUND)
    s.unbound:SetPoint("TOPLEFT", 20, -404)
    s.unbound.Text:SetWidth(390)

    local subLbl = W.Label(f, L.SET_SUBJECT)
    subLbl:SetPoint("TOPLEFT", 22, -434)
    s.subject = W.EditBox(f, 392, 64)
    s.subject:SetPoint("TOPLEFT", 26, -448)

    -- ---------- effective values ----------
    s.effective = W.Label(f, "", "GameFontDisableSmall")
    s.effective:SetPoint("TOPLEFT", 16, -476)
    s.effective:SetWidth(408)

    s.apply = W.Button(f, 140, L.CFG_APPLY, function()
        -- Everything is validated before anything is written, so a typo
        -- in one box cannot leave the rest half-applied.
        local pending = {}
        local fields = {
            { box = s.charTarget,   allowSelf = false, key = "charTarget"   },
            { box = s.charGold,     allowSelf = false, key = "charGold"     },
            { box = s.globalTarget, allowSelf = true,  key = "globalTarget" },
            { box = s.globalGold,   allowSelf = true,  key = "globalGold"   },
        }
        for _, fld in ipairs(fields) do
            local value, err = ns.CheckRecipient(fld.box:GetText(), fld.allowSelf)
            if not value then
                return Util.Print(err == "self" and L.NO_SELF or L.BAD_NAME,
                                  Util.Trim(fld.box:GetText()) .. " (" .. tostring(err) .. ")")
            end
            pending[fld.key] = value
        end

        local globalReserve = Util.GoldToCopper(s.reserve:GetText())
        if not globalReserve then return Util.Print(L.SET_BADRESERVE, s.reserve:GetText()) end

        -- An empty character box means "inherit", not "keep nothing".
        local charReserveText = Util.Trim(s.charReserve:GetText())
        local charReserve = ""
        if charReserveText ~= "" then
            charReserve = Util.GoldToCopper(charReserveText)
            if not charReserve then return Util.Print(L.SET_BADRESERVE, charReserveText) end
        end

        ns.charDB.target        = pending.charTarget
        ns.charDB.goldRecipient = pending.charGold
        ns.charDB.goldReserve   = charReserve
        ns.db.target            = pending.globalTarget
        ns.db.gold.recipient    = pending.globalGold
        ns.db.gold.reserve      = globalReserve

        ns.db.gold.confirm   = s.goldConfirm:GetChecked() and true or false
        ns.db.confirm        = s.confirm:GetChecked() and true or false
        ns.db.includeUnbound = s.unbound:GetChecked() and true or false

        local subject = Util.Trim(s.subject:GetText())
        ns.db.subject = (subject ~= "" and subject) or Util.DEFAULT_SUBJECT

        Util.Print(L.SET_SAVED)
        Config:RefreshSettings()
        if ns.UI then ns.UI:Refresh() end
    end)
    s.apply:SetPoint("BOTTOMLEFT", 14, 12)

    return f
end

---Reloads the settings window from the database. Safe to call any time.
function Config:RefreshSettings()
    if not settingsWin or not settingsWin:IsShown() then return end
    local s = settingsWin.s

    s.secChar:SetText(string.format(L.SET_SEC_CHAR, Util.MyFullName()))

    local function Fill(box, value)
        if not box:HasFocus() then box:SetText(value or "") end
    end
    Fill(s.charTarget,   ns.charDB.target)
    Fill(s.charGold,     ns.charDB.goldRecipient)
    Fill(s.globalTarget, ns.db.target)
    Fill(s.globalGold,   ns.db.gold.recipient)
    Fill(s.subject,      ns.db.subject)
    if not s.reserve:HasFocus() then
        s.reserve:SetText(tostring(Util.CopperToGold(ns.db.gold.reserve)))
    end
    if not s.charReserve:HasFocus() then
        local c = ns.charDB.goldReserve
        s.charReserve:SetText(type(c) == "number" and tostring(Util.CopperToGold(c)) or "")
    end

    s.goldConfirm:SetChecked(ns.db.gold.confirm and true or false)
    s.confirm:SetChecked(ns.db.confirm and true or false)
    s.unbound:SetChecked(ns.db.includeUnbound and true or false)
    s.sendable:SetText(string.format(L.SET_SENDABLE, Util.Money(ns.Gold.Sendable())))

    s.effective:SetText(string.format(L.SET_EFFECTIVE,
        ns.Rules.Target()   or L.SET_NOTSET,
        ns.Gold.Recipient() or L.SET_NOTSET))
end

function Config:ToggleSettings()
    if not settingsWin then settingsWin = Register(BuildSettingsWindow()) end
    if Toggle(settingsWin) then Config:RefreshSettings() end
end

function Config:ToggleRules()
    if not rulesWin then
        rulesWin = Register(BuildRulesWindow())
        draft = CopyRule(nil)
        LoadDraftIntoEditor()
    end
    if Toggle(rulesWin) then Config:Refresh() end
end

function Config:ToggleHold()
    if not holdWin then holdWin = Register(BuildHoldWindow()) end
    if Toggle(holdWin) then holdWin.box:Refresh() end
end

-- kept so older bindings and macros keep working
function Config:ToggleIgnore() return Config:ToggleHold() end

-- Item names arrive asynchronously; refresh whatever list is open so
-- search by name works for items that were not cached at first paint.
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    ev:SetScript("OnEvent", function()
        if holdWin and holdWin:IsShown() then holdWin.box:Refresh() end
        if rulesWin and rulesWin:IsShown() and ruleSearch ~= "" then Config:Refresh() end
    end)
end
