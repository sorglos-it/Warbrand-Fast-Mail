-- ============================================================
-- Warbrand-Fast-Mail / Lib/Keep.lua
-- Per-item reserve: "keep 20 healing potions, mail the rest".
--
-- The rule is expressed as a floor on the bag contents, not as a
-- running counter. At any moment during a run:
--
--     available(itemID) = GetItemCount(itemID) - keep(itemID)
--
-- Attached items have already left the bags, so the value shrinks
-- by itself as the run progresses and lands exactly on the keep
-- amount. Nothing has to be tracked across steps, and an aborted
-- or resumed run can never overshoot.
--
-- Two scopes: ns.db.keep applies to every character, ns.charDB.keep
-- only to the current one and wins for the same itemID. Either way
-- the amount is evaluated against the bags of the character that is
-- running -- "every character keeps 20" is the global reading.
-- ============================================================
local ADDON, ns = ...
local L, Util = ns.L, ns.Util

local Keep = {}
ns.Keep = Keep

local GetItemCount = (C_Item and C_Item.GetItemCount) or _G.GetItemCount

Keep.MAX = 99999

-- --- Query -------------------------------------------------

---Configured keep amount for an item (0 = no limit).
function Keep.Amount(itemID)
    if not itemID or not ns.db then return 0 end
    local n = tonumber(ns.charDB and ns.charDB.keep and ns.charDB.keep[itemID])
    if n == nil then n = tonumber(ns.db.keep and ns.db.keep[itemID]) end
    if not n or n <= 0 then return 0 end
    return math.min(math.floor(n), Keep.MAX)
end

---"char" if the current character overrides the global amount.
function Keep.Scope(itemID)
    if itemID and ns.charDB and ns.charDB.keep and ns.charDB.keep[itemID] then return "char" end
    return "global"
end

---Current quantity in the bags only (bank and mail excluded).
function Keep.InBags(itemID)
    if not itemID or not GetItemCount then return 0 end
    return Util.Try(GetItemCount, itemID) or 0
end

---How many pieces of this item may still leave the bags.
---Returns math.huge when no keep amount is configured, so the
---common case costs no bag lookup at all.
function Keep.Available(itemID)
    local keep = Keep.Amount(itemID)
    if keep <= 0 then return math.huge end
    return math.max(0, Keep.InBags(itemID) - keep)
end

---Pieces of this particular stack that may be attached.
function Keep.StackSendQty(itemID, stackCount)
    stackCount = math.max(0, math.floor(tonumber(stackCount) or 0))
    local avail = Keep.Available(itemID)
    if avail == math.huge then return stackCount end
    return math.min(stackCount, math.floor(avail))
end

-- --- Mutation ----------------------------------------------

---@return boolean ok
---@param scope string|nil  "global" (default) or "char"
function Keep.Set(itemID, amount, scope)
    itemID = Util.ToItemID(itemID)
    if not itemID then return false end
    local n = tonumber(amount)
    if not n then return false end
    n = math.floor(n)
    if n < 0 or n > Keep.MAX then return false end

    local target = (scope == "char") and ns.charDB.keep or ns.db.keep
    local other  = (scope == "char") and ns.db.keep or ns.charDB.keep

    if n == 0 then
        target[itemID] = nil
    else
        target[itemID] = n
        other[itemID]  = nil
    end
    return true
end

function Keep.Clear(itemID)
    itemID = Util.ToItemID(itemID)
    if not itemID then return false end
    ns.db.keep[itemID] = nil
    ns.charDB.keep[itemID] = nil
    return true
end

function Keep.Count()
    local seen, n = {}, 0
    for id in pairs(ns.charDB.keep or {}) do seen[id] = true; n = n + 1 end
    for id in pairs(ns.db.keep or {}) do if not seen[id] then n = n + 1 end end
    return n
end
