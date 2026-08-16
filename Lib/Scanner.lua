-- ============================================================
-- Warbrand-Fast-Mail / Lib/Scanner.lua
-- Classifies every bag slot as "warbound" / "unbound" / "soulbound"
-- and returns the metadata the rule engine needs.
--
-- Detection order (first conclusive result wins):
--   1. C_Bank.IsItemAllowedInBankType(Account) + C_Item.IsBound
--      -> locale independent and authoritative. Soulbound items are
--         never allowed in the warband bank, warbound ones always.
--   2. bindType (field 14 of GetItemInfo) against Enum.ItemBind
--   3. Tooltip scan against Blizzard's own localized GlobalStrings
--
-- Entries also carry sendQty: how many pieces of that stack may
-- leave the bags after Lib/Hold.lua has taken its reserve.
--
-- The reserve is a budget per ITEM, not per stack, so it is spent
-- down across one scan pass: with 810 bandages and "keep 5" spread
-- over five stacks, the pass hands out 805 in total instead of
-- clearing every stack against the same 805.
--
-- Callers may inject their own quota function. The mailer does, so a
-- running transfer is not measured against GetItemCount, which is
-- cached and only refreshes on BAG_UPDATE.
-- ============================================================
local ADDON, ns = ...
local Util, Hold = ns.Util, ns.Hold

local Scanner = {}
ns.Scanner = Scanner

-- --- Constants ---------------------------------------------

local BAG_FIRST = (Enum.BagIndex and Enum.BagIndex.Backpack)   or 0
local BAG_LAST  = (Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5

-- No numeric fallback on purpose: if the enum is missing we skip
-- detection level 1 rather than guessing a bank type.
local BANK_ACCOUNT = Enum.BankType and Enum.BankType.Account

local WARBOUND_BIND = {}
do
    if Enum and Enum.ItemBind then
        for _, k in ipairs({ "ToWoWAccount", "ToBnetAccount",
                             "ToWoWAccountUntilEquipped", "ToBnetAccountUntilEquipped" }) do
            local v = Enum.ItemBind[k]
            if type(v) == "number" then WARBOUND_BIND[v] = true end
        end
    end
    WARBOUND_BIND[7] = true; WARBOUND_BIND[8] = true; WARBOUND_BIND[9] = true
end

local BIND_TEXT, SOULBOUND_TEXT = {}, nil
do
    for _, g in ipairs({ "ITEM_ACCOUNTBOUND", "ITEM_BIND_TO_ACCOUNT",
                         "ITEM_BNETACCOUNTBOUND", "ITEM_BIND_TO_BNETACCOUNT",
                         "ITEM_ACCOUNTBOUND_UNTIL_EQUIP", "ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP" }) do
        local s = _G[g]
        if type(s) == "string" and s ~= "" then BIND_TEXT[s] = true end
    end
    SOULBOUND_TEXT = _G.ITEM_SOULBOUND
end

Scanner.WARBOUND  = "warbound"
Scanner.UNBOUND   = "unbound"
Scanner.SOULBOUND = "soulbound"

-- --- Level 3: tooltip fallback -----------------------------

---@return boolean|nil  nil = inconclusive
local function TooltipWarbound(bag, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return nil end
    local data = Util.Try(C_TooltipInfo.GetBagItem, bag, slot)
    if not (data and data.lines) then return nil end

    local warbound = false
    for i = 1, #data.lines do
        local text = data.lines[i] and data.lines[i].leftText
        if type(text) == "string" then
            if SOULBOUND_TEXT and text == SOULBOUND_TEXT then return false end
            if BIND_TEXT[text] then warbound = true end
        end
    end
    return warbound
end

-- --- Bind state --------------------------------------------

---@return string "warbound" | "unbound" | "soulbound"
function Scanner.BindState(bag, slot, link)
    local loc = ItemLocation and ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not loc then return Scanner.SOULBOUND end
    if C_Item.DoesItemExist and not C_Item.DoesItemExist(loc) then return Scanner.SOULBOUND end

    -- 1) warband bank eligibility
    local allowed
    if BANK_ACCOUNT and C_Bank and C_Bank.IsItemAllowedInBankType then
        allowed = Util.Try(C_Bank.IsItemAllowedInBankType, BANK_ACCOUNT, loc)
    end
    local bound = C_Item.IsBound and Util.Try(C_Item.IsBound, loc)

    if allowed ~= nil then
        if allowed == false then return Scanner.SOULBOUND end
        if bound == true  then return Scanner.WARBOUND end
        if bound == false then return Scanner.UNBOUND end
    end

    -- 2) bindType
    if link and Util.API.GetItemInfo then
        local bindType = select(14, Util.API.GetItemInfo(link))
        if bindType and WARBOUND_BIND[bindType] then
            if C_Item.IsBoundToAccountUntilEquip
               and Util.Try(C_Item.IsBoundToAccountUntilEquip, loc) then
                return Scanner.WARBOUND
            end
            if TooltipWarbound(bag, slot) == false then return Scanner.SOULBOUND end
            return Scanner.WARBOUND
        end
        if bindType == 0 and bound == false then return Scanner.UNBOUND end
    end

    -- 3) tooltip
    local t = TooltipWarbound(bag, slot)
    if t == true then return Scanner.WARBOUND end
    if t == false and bound ~= false then return Scanner.SOULBOUND end
    if bound == false then return Scanner.UNBOUND end
    return Scanner.SOULBOUND
end

-- --- Entry construction ------------------------------------

local function BuildEntry(bag, slot, info, remaining)
    local link = info.hyperlink
    local classID, subclassID

    if Util.API.GetItemInfoInstant then
        local _, _, _, _, _, cID, scID = Util.API.GetItemInfoInstant(link)
        classID, subclassID = cID, scID
    end

    local ilvl
    if Util.API.GetDetailedItemLevelInfo then
        ilvl = Util.API.GetDetailedItemLevelInfo(link)
    end

    local count = info.stackCount or 1
    local allowance = remaining(info.itemID)
    local sendQty = (allowance == math.huge) and count or math.min(count, math.floor(allowance))

    return {
        bag        = bag,
        slot       = slot,
        link       = link,
        itemID     = info.itemID,
        count      = count,
        sendQty    = sendQty,
        quality    = info.quality or 0,
        classID    = classID,
        subclassID = subclassID,
        ilvl       = ilvl,
        bind       = Scanner.BindState(bag, slot, link),
    }
end

-- --- Bag totals --------------------------------------------

---Pieces per itemID across exactly the slots this module scans.
---Single source of truth for hold budgets: GetItemCount uses its own
---container set and a cache that lags behind attachments.
---@return table totals  [itemID] = pieces
function Scanner.BagTotals()
    local totals = {}
    for bag = BAG_FIRST, BAG_LAST do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                totals[info.itemID] = (totals[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    return totals
end

---First empty slot in a general purpose bag, or nil.
---Reagent and other specialised bags are skipped: they refuse most
---items, and a refused drop would leave the cursor loaded.
---@return number|nil bag, number|nil slot
function Scanner.FindEmptyBagSlot()
    for bag = BAG_FIRST, BAG_LAST do
        local _, family = C_Container.GetContainerNumFreeSlots(bag)
        if (family or 0) == 0 then
            local n = C_Container.GetContainerNumSlots(bag) or 0
            for slot = 1, n do
                if not C_Container.GetContainerItemInfo(bag, slot) then
                    return bag, slot
                end
            end
        end
    end
end

---Slot holding exactly this many pieces of an item, or nil.
---Used after parking a remainder: the container cache may still be
---stale, and the game may have restacked, so the stack is looked up by
---content instead of by remembered coordinates.
---@return number|nil bag, number|nil slot
function Scanner.FindSlotWithCount(itemID, count)
    if not itemID or not count then return nil end
    for bag = BAG_FIRST, BAG_LAST do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID and (info.stackCount or 0) == count
               and not info.isLocked then
                return bag, slot
            end
        end
    end
end

-- --- Iteration ---------------------------------------------

---@param skip table|nil   [itemID] = failCount. Keyed by item, not by
---                         slot: a failed attach can move a stack to a
---                         different slot, and a slot-keyed counter
---                         would reset and retry forever.
---@param filter function|nil  entry -> boolean
local function Iterate(skip, filter, callback, quota)
    -- budget[itemID] is what is still allowed to leave the bags in this
    -- pass; it shrinks as stacks are handed out.
    local budget, totals = {}, nil
    local function remaining(itemID)
        if itemID == nil then return math.huge end
        if budget[itemID] == nil then
            if quota then
                budget[itemID] = quota(itemID)
            else
                totals = totals or Scanner.BagTotals()
                budget[itemID] = Hold.Budget(itemID, totals[itemID])
            end
        end
        return budget[itemID]
    end
    local function spend(itemID, qty)
        if itemID == nil or budget[itemID] == math.huge then return end
        budget[itemID] = math.max(0, (budget[itemID] or 0) - qty)
    end

    for bag = BAG_FIRST, BAG_LAST do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink and not info.isLocked and not info.hasLoot then
                local ok = true
                if skip and info.itemID and (skip[info.itemID] or 0) >= 3 then
                    ok = false
                end
                if ok then
                    local entry = BuildEntry(bag, slot, info, remaining)
                    if entry.bind ~= Scanner.SOULBOUND and entry.sendQty > 0 then
                        if (not filter) or filter(entry) then
                            spend(entry.itemID, entry.sendQty)
                            if callback(entry) == false then return end
                        end
                    end
                end
            end
        end
    end
end

---All mailable (non-soulbound) items in the bags.
function Scanner.Collect(skip, filter, quota)
    local out = {}
    Iterate(skip, filter, function(e) out[#out + 1] = e end, quota)
    return out
end

---First mailable item matching the filter, or nil.
function Scanner.FindFirst(skip, filter, quota)
    local found
    Iterate(skip, filter, function(e) found = e; return false end, quota)
    return found
end
