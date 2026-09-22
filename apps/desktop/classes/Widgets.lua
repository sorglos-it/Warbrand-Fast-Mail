-- ============================================================
-- Warbrand-Fast-Mail / Lib/Widgets.lua
-- Small, self-contained widget toolkit.
-- Deliberately avoids UIDropDownMenu / FauxScrollFrame and the
-- newer MenuUtil API, so nothing breaks when Blizzard reworks
-- either of them. Only long-stable templates are used.
-- ============================================================
local ADDON, ns = ...
local L, Util = ns.L, ns.Util

local W = {}
ns.Widgets = W

local BACKDROP = {
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local INSET = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- --- Window ------------------------------------------------

---Movable, closable dialog. Position is persisted through store[key].
---@param noEscape boolean|nil  true = do not register in UISpecialFrames
function W.Window(name, width, height, title, store, key, noEscape)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(width, height)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetBackdrop(BACKDROP)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if store and key then
            local p, _, rp, x, y = self:GetPoint()
            store[key] = { p, rp, x, y }
        end
    end)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetText(title or "")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() f:Hide() end)
    f.closeButton = close

    f.RestorePosition = function(self, anchorTo)
        self:ClearAllPoints()
        local p = store and key and store[key]
        if p and p[1] then
            self:SetPoint(p[1], UIParent, p[2] or "CENTER", p[3] or 0, p[4] or 0)
        elseif anchorTo then
            self:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 4, 0)
        else
            self:SetPoint("CENTER")
        end
    end

    if not noEscape then
        tinsert(UISpecialFrames, name)   -- Escape closes the window
    end

    -- CreateFrame hands back a *visible* frame. Without this the first
    -- Toggle() would read IsShown() == true and hide an unpositioned
    -- window instead of opening it, which looked like the first click
    -- on every button being swallowed.
    f:Hide()
    return f
end

function W.Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

function W.Button(parent, width, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text or "")
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

function W.EditBox(parent, width, maxLetters, onEnter)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(width, 20)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(maxLetters or 64)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if onEnter then onEnter(self, self:GetText()) end
    end)
    return eb
end

function W.CheckBox(parent, text, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    local t = cb.Text or _G[(cb:GetName() or "") .. "Text"]
    if not t then
        t = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        cb.Text = t
    end
    t:SetFontObject("GameFontHighlightSmall")
    t:SetText(text or "")
    if onClick then cb:SetScript("OnClick", onClick) end
    return cb
end

-- --- Dropdown ----------------------------------------------
-- items provider returns { {value=, text=}, ... }
-- value == nil is allowed and used for the "Any/All" entry.

local openMenu

local function CloseMenu()
    if openMenu then openMenu:Hide(); openMenu = nil end
end

function W.Dropdown(parent, width, itemsProvider, onSelect, emptyText)
    local dd = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    dd:SetSize(width, 22)
    dd.value = nil
    dd.emptyText = emptyText or L.CFG_ANY

    local arrow = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetText("v")

    function dd:GetValue() return self.value end

    function dd:SetValue(v, silent)
        self.value = v
        local text = self.emptyText
        for _, it in ipairs(itemsProvider() or {}) do
            if it.value == v then text = it.text break end
        end
        self:SetText(text)
        if not silent and onSelect then onSelect(v) end
    end

    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetBackdrop(INSET)
    menu:SetBackdropColor(0, 0, 0, 0.95)
    menu:EnableMouse(true)
    menu:Hide()
    menu.rows = {}

    menu:SetScript("OnHide", function() if openMenu == menu then openMenu = nil end end)

    local MAX_ROWS = 18

    local function Build()
        local list = itemsProvider() or {}
        local n = math.min(#list, MAX_ROWS)
        menu:SetSize(math.max(width, 140), n * 18 + 12)

        for i = 1, math.max(n, #menu.rows) do
            local row = menu.rows[i]
            if not row and i <= n then
                row = CreateFrame("Button", nil, menu)
                row:SetSize(math.max(width, 140) - 12, 18)
                row:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 18)
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", 4, 0)
                row.text:SetJustifyH("LEFT")
                row.hl = row:CreateTexture(nil, "HIGHLIGHT")
                row.hl:SetAllPoints()
                row.hl:SetColorTexture(1, 1, 1, 0.15)
                menu.rows[i] = row
            end
            if row then
                if i <= n then
                    row:SetWidth(math.max(width, 140) - 12)
                    row.text:SetText(list[i].text)
                    row.entry = list[i]
                    row:SetScript("OnClick", function(self)
                        CloseMenu()
                        dd:SetValue(self.entry.value)
                    end)
                    row:Show()
                else
                    row:Hide()
                end
            end
        end
    end

    dd:SetScript("OnClick", function(self)
        if openMenu == menu then return CloseMenu() end
        CloseMenu()
        Build()
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:Show()
        openMenu = menu
    end)

    dd.menu = menu
    dd:SetValue(nil, true)
    return dd
end

-- Any click outside closes an open menu.
do
    local catcher = CreateFrame("Frame")
    catcher:RegisterEvent("GLOBAL_MOUSE_DOWN")
    catcher:SetScript("OnEvent", function()
        if not openMenu then return end
        if openMenu:IsMouseOver() then return end
        CloseMenu()
    end)
end

-- --- Scoped item list -------------------------------------
-- Edits two tables at once: a global one and a per-character one.
-- Character entries win over global entries for the same itemID and
-- are listed first. Each row carries a scope toggle.
--
-- opts.getGlobal  function -> table   { [itemID] = value }
-- opts.getChar    function -> table
-- opts.counted    boolean            show an editable amount column
-- opts.getNewScope function -> "global" | "char"
-- opts.getSearch  function -> string  live filter, optional
-- opts.onChange   function
--
-- In counted mode a value of true means "keep everything" and renders
-- as an empty box; a number means "keep that many".

-- Emptying a list is destructive and cannot be undone, so it asks first
-- and says how many entries are at stake.
StaticPopupDialogs["WARBRANDFASTMAIL_CLEARLIST"] = {
    text           = "%s",
    button1        = YES or "Yes",
    button2        = NO or "No",
    timeout        = 30,
    whileDead      = false,
    hideOnEscape   = true,
    showAlert      = true,
    preferredIndex = 3,
    OnAccept = function(_, data)
        if data and type(data.run) == "function" then data.run() end
    end,
}

function W.ItemScopeList(parent, width, height, opts)
    local counted = opts.counted and true or false
    -- Unscoped mode: no per-character table, no scope column. Used for
    -- the per-rule item list, which belongs to its rule, not to a scope.
    local scoped  = opts.getChar ~= nil

    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(width, height)
    box:SetBackdrop(INSET)
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:EnableMouse(true)
    box:EnableMouseWheel(true)

    local ROW_H = counted and 20 or 17
    local rows, offset = {}, 0
    local visible = math.max(1, math.floor((height - 10) / ROW_H))

    local function Tables()
        return opts.getGlobal() or {}, (scoped and opts.getChar()) or {}
    end
    -- New entries start as "keep everything", which is the safe
    -- reading of dropping an item onto a hold list.
    local function DefaultValue() return true end

    ---Merged and filtered view, character entries first.
    local function Entries()
        local g, c = Tables()
        local needle = opts.getSearch and Util.Trim(opts.getSearch() or "") or ""
        local out, seen = {}, {}

        local function Accept(id)
            if needle == "" then return true end
            if tostring(id):find(needle, 1, true) then return true end
            return Util.Matches(Util.ItemName(id), needle)
        end

        for id, v in pairs(c) do
            seen[id] = true
            if Accept(id) then out[#out + 1] = { id = id, value = v, char = true } end
        end
        for id, v in pairs(g) do
            if not seen[id] and Accept(id) then
                out[#out + 1] = { id = id, value = v, char = false }
            end
        end
        table.sort(out, function(a, b)
            if a.char ~= b.char then return a.char end
            return a.id < b.id
        end)
        return out
    end

    function box:ResetScroll() offset = 0 end

    local function Store(id, value, toChar)
        local g, c = Tables()
        if scoped and toChar then c[id] = value; g[id] = nil
        else g[id] = value; if scoped then c[id] = nil end end
    end

    local function Remove(id)
        local g, c = Tables()
        g[id] = nil; c[id] = nil
    end

    function box:Refresh()
        local list = Entries()
        offset = math.max(0, math.min(math.max(0, #list - visible), offset))

        for i = 1, visible do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, box)
                row:SetSize(width - 12, ROW_H)
                row:SetPoint("TOPLEFT", 6, -5 - (i - 1) * ROW_H)

                row.scope = CreateFrame("Button", nil, row)
                row.scope:SetSize(18, 15)
                row.scope:SetPoint("LEFT", 0, 0)
                row.scope.fs = row.scope:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.scope.fs:SetPoint("CENTER")
                row.scope:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(L.SCOPE_TIP, 1, 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                row.scope:SetScript("OnLeave", GameTooltip_Hide)
                row.scope:SetShown(scoped)

                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", scoped and 22 or 4, 0)
                row.text:SetPoint("RIGHT", row, "RIGHT", counted and -86 or -20, 0)
                row.text:SetJustifyH("LEFT")

                if counted then
                    row.amount = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
                    row.amount:SetSize(48, 18)
                    row.amount:SetPoint("RIGHT", -24, 0)
                    row.amount:SetAutoFocus(false)
                    row.amount:SetNumeric(true)
                    row.amount:SetMaxLetters(5)
                    row.amount:SetJustifyH("RIGHT")
                    row.amount:SetScript("OnEscapePressed", row.amount.ClearFocus)
                    row.amount:SetScript("OnEnterPressed", row.amount.ClearFocus)
                    row.amount:SetScript("OnTextChanged", function(self)
                        if row.updating or not row.itemID then return end
                        local text = Util.Trim(self:GetText())
                        local value = true                    -- empty = keep everything
                        if text ~= "" then
                            local n = tonumber(text)
                            if not n then return end
                            if n > 0 then value = math.min(math.floor(n), 99999) end
                        end
                        Store(row.itemID, value, row.isChar)
                        if opts.onChange then opts.onChange() end
                    end)
                    row.amount:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(L.HOLD_COL, 1, 1, 1)
                        GameTooltip:AddLine(L.HOLD_TIP, nil, nil, nil, true)
                        GameTooltip:Show()
                    end)
                    row.amount:SetScript("OnLeave", GameTooltip_Hide)
                end

                row.del = CreateFrame("Button", nil, row)
                row.del:SetSize(14, 14)
                row.del:SetPoint("RIGHT", -2, 0)
                row.del.fs = row.del:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.del.fs:SetPoint("CENTER")
                row.del.fs:SetText("|cffff4040x|r")

                rows[i] = row
            end

            local e = list[i + offset]
            if e then
                row.itemID, row.isChar = e.id, e.char
                if scoped then
                    row.scope.fs:SetText(e.char and ("|cff66bbff" .. L.SCOPE_MARK_C .. "|r")
                                                 or ("|cffaaaaaa" .. L.SCOPE_MARK_G .. "|r"))
                    row.scope:SetScript("OnClick", function()
                        Store(e.id, e.value, not e.char)
                        box:Refresh()
                        if opts.onChange then opts.onChange() end
                    end)
                end
                row.text:SetText(Util.ItemLink(e.id))
                if counted then
                    row.updating = true
                    row.amount:SetText(ns.Hold.AmountText(e.value))
                    row.updating = false
                end
                row.del:SetScript("OnClick", function()
                    Remove(e.id)
                    box:Refresh()
                    if opts.onChange then opts.onChange() end
                end)
                row:Show()
            else
                row.itemID = nil
                row:Hide()
            end
        end

        if box.emptyText then
            local filtering = opts.getSearch and Util.Trim(opts.getSearch() or "") ~= ""
            box.emptyText:SetShown(#list == 0 and filtering)
        end
    end

    box:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta)
        box:Refresh()
    end)

    box.emptyText = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    box.emptyText:SetPoint("TOPLEFT", 10, -10)
    box.emptyText:SetText(L.SEARCH_NONE)
    box.emptyText:Hide()

    local function Add(id)
        if not id then return false end
        local g, c = Tables()
        if g[id] == nil and c[id] == nil then
            Store(id, DefaultValue(), scoped and opts.getNewScope() == "char")
        end
        box:Refresh()
        if opts.onChange then opts.onChange() end
        return true
    end

    local function AddFromCursor()
        local kind, id = GetCursorInfo()
        if kind ~= "item" or not id then return false end
        ClearCursor()
        return Add(id)
    end

    box:SetScript("OnReceiveDrag", AddFromCursor)
    box:SetScript("OnMouseDown", AddFromCursor)

    box.clearButton = W.Button(parent, 60, L.CFG_CLEAR, function()
        local g, c = Tables()
        local t = (scoped and opts.getNewScope() == "char") and c or g
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        if n == 0 then return end

        local dlg = StaticPopup_Show("WARBRANDFASTMAIL_CLEARLIST",
            string.format(L.CFG_CLEARCONFIRM, n))
        if not dlg then return end
        dlg.data = { run = function()
            for k in pairs(t) do t[k] = nil end
            box:Refresh()
            if opts.onChange then opts.onChange() end
        end }
    end)
    box.clearButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.CFG_CLEAR, 1, 1, 1)
        GameTooltip:AddLine(L.CFG_CLEARTIP, nil, nil, nil, true)
        -- Only the hold list has a scope selector; the per-rule list does
        -- not, and claiming otherwise there was simply wrong.
        if scoped then
            GameTooltip:AddLine(L.SCOPE_CLEARTIP, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    box.clearButton:SetScript("OnLeave", GameTooltip_Hide)
    -- Anchored here rather than by each caller: the button belongs in the
    -- same corner of every window that hosts one of these lists.
    box.clearButton:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -14, 12)

    box.hint = W.Label(parent, L.CFG_DROPHERE, "GameFontDisableSmall")
    return box
end
