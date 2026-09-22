-- ============================================================
-- Warbrand-Fast-Mail / Lib/Hold.lua
-- One list for "never send" and "keep n, send the rest".
--
-- Value semantics per itemID:
--   true    keep everything, never mail it  (the old ignore list)
--   number  keep that many, mail the surplus
--
-- Two scopes: ns.db.hold applies to every character, ns.charDB.hold
-- only to the current one and wins for the same itemID.
--
-- The amount is a floor on the bag contents, not a running counter:
--
--     available(itemID) = GetItemCount(itemID) - keep(itemID)
--
-- Attached items have already left the bags, so the value shrinks by
-- itself during a run and lands exactly on the keep amount. Nothing
-- has to be tracked across steps, and an aborted or resumed run can
-- never overshoot.
-- ============================================================
local ADDON, ns = ...
local L, Util = ns.L, ns.Util

local Hold = {}
ns.Hold = Hold

local GetItemCount = (C_Item and C_Item.GetItemCount) or _G.GetItemCount

Hold.MAX  = 99999
Hold.ALL  = true      -- sentinel: keep everything

-- --- Query -------------------------------------------------

---Raw entry for an item, character scope first.
---@return boolean|number|nil value, string|nil scope
function Hold.Get(itemID)
    if not itemID or not ns.db then return nil end
    local c = ns.charDB and ns.charDB.hold and ns.charDB.hold[itemID]
    if c ~= nil then return c, "char" end
    local g = ns.db.hold and ns.db.hold[itemID]
    if g ~= nil then return g, "global" end
    return nil
end

---True when the item must never leave the bags.
function Hold.IsBlocked(itemID)
    return Hold.Get(itemID) == true
end

---Configured keep amount, 0 when none (or when fully blocked, which
---IsBlocked handles separately).
function Hold.Amount(itemID)
    local v = Hold.Get(itemID)
    if type(v) ~= "number" then return 0 end
    if v <= 0 then return 0 end
    return math.min(math.floor(v), Hold.MAX)
end

---Current quantity in the bags only (bank and mail excluded).
function Hold.InBags(itemID)
    if not itemID or not GetItemCount then return 0 end
    return Util.Try(GetItemCount, itemID) or 0
end

---How many pieces may still leave the bags, measured against an
---explicit bag total.
---
---The total is passed in on purpose. GetItemCount is a cached counter
---with its own idea of which containers count, and it only refreshes on
---BAG_UPDATE -- during a transfer it still reports the pre-attach total.
---Scanner.BagTotals walks the same slots the scanner itself walks, so
---display and transfer can never disagree.
---@param total number|nil  pieces in the bags; falls back to GetItemCount
function Hold.Budget(itemID, total)
    local v = Hold.Get(itemID)
    if v == nil then return math.huge end
    if v == true then return 0 end
    local keep = Hold.Amount(itemID)
    if keep <= 0 then return math.huge end
    total = tonumber(total) or Hold.InBags(itemID)
    return math.max(0, total - keep)
end

---Convenience wrapper for callers without a scan at hand.
function Hold.Available(itemID)
    return Hold.Budget(itemID, nil)
end

---Pieces of this particular stack that may be attached.
function Hold.StackSendQty(itemID, stackCount)
    stackCount = math.max(0, math.floor(tonumber(stackCount) or 0))
    local avail = Hold.Available(itemID)
    if avail == math.huge then return stackCount end
    return math.min(stackCount, math.floor(avail))
end

---Display text for the amount column.
function Hold.AmountText(value)
    if type(value) == "number" and value > 0 then return tostring(math.floor(value)) end
    return ""
end

-- --- Mutation ----------------------------------------------

---@param value boolean|number  true = never send, n > 0 = keep n
---@param scope string|nil      "global" (default) or "char"
function Hold.Set(itemID, value, scope)
    itemID = Util.ToItemID(itemID)
    if not itemID or not ns.db then return false end

    if type(value) == "string" then
        local trimmed = Util.Trim(value)
        if trimmed == "" then
            value = true
        else
            local n = tonumber(trimmed)
            if not n then return false end
            value = n
        end
    end

    if type(value) == "number" then
        value = math.floor(value)
        if value < 0 or value > Hold.MAX then return false end
        if value == 0 then value = true end   -- "keep 0" is meaningless, read as "keep all"
    elseif value ~= true then
        return false
    end

    local toChar = (scope == "char")
    local target = toChar and ns.charDB.hold or ns.db.hold
    local other  = toChar and ns.db.hold or ns.charDB.hold
    -- The and/or idiom silently falls through to the global table when the
    -- character one is missing, which would write the entry to the wrong
    -- scope instead of failing. Migrate guarantees both today; say so.
    if type(target) ~= "table" or type(other) ~= "table" then return false end
    target[itemID] = value
    other[itemID]  = nil
    return true
end

---@param scope string|nil  "char" or "global" clears only that level,
---                         nil clears the entry wherever it lives
function Hold.Clear(itemID, scope)
    itemID = Util.ToItemID(itemID)
    if not itemID then return false end
    if scope == "char" then
        if type(ns.charDB.hold) == "table" then ns.charDB.hold[itemID] = nil end
    elseif scope == "global" then
        if type(ns.db.hold) == "table" then ns.db.hold[itemID] = nil end
    else
        if type(ns.db.hold) == "table" then ns.db.hold[itemID] = nil end
        if type(ns.charDB.hold) == "table" then ns.charDB.hold[itemID] = nil end
    end
    return true
end

function Hold.Count()
    local seen, n = {}, 0
    for id in pairs(ns.charDB.hold or {}) do seen[id] = true; n = n + 1 end
    for id in pairs(ns.db.hold or {}) do if not seen[id] then n = n + 1 end end
    return n
end

-- --- Migration ---------------------------------------------

---Folds the separate ignore and keep tables of earlier builds into
---the unified list. Idempotent: the old tables are removed as they go.
function Hold.Migrate(store)
    if type(store) ~= "table" then return 0 end
    if type(store.hold) ~= "table" then store.hold = {} end
    local moved = 0

    if type(store.ignore) == "table" then
        for id in pairs(store.ignore) do
            if store.hold[id] == nil then store.hold[id] = true; moved = moved + 1 end
        end
        store.ignore = nil
    end
    if type(store.keep) == "table" then
        for id, n in pairs(store.keep) do
            local amount = tonumber(n)
            if amount and amount > 0 and store.hold[id] == nil then
                store.hold[id] = math.floor(amount)
                moved = moved + 1
            end
        end
        store.keep = nil
    end
    return moved
end
