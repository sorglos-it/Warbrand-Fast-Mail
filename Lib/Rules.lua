-- ============================================================
-- Warbrand-Fast-Mail / Lib/Rules.lua
-- Routing engine. Pure logic, no UI, no game state beyond ns.db.
--
-- Rule schema (all fields optional except recipient):
--   enabled    boolean
--   label      string
--   recipient  string   (already normalised)
--   items      table    { [itemID] = true }  -- if non-empty this
--                       rule matches ONLY these items and every
--                       other criterion is ignored
--   classID    number   Enum.ItemClass
--   subclassID number
--   bind       "any" | "warbound" | "unbound"
--   minQuality number   0..7
--   scope      "global" (every character) | "char" (owner only)
--   owner      string   "Name-Realm", set when scope == "char"
--
-- Evaluation: top-down, first match wins. If no rule matches, the
-- implicit default rule (charDB.target) applies.
--
-- Self guard: when the winning rule points at the character that is
-- currently running, the item stays put and evaluation stops. That
-- is what makes a collector setup work without any per-character
-- ignore entry -- one global rule "pet charms -> Collector" sends on
-- every character and is inert on Collector itself.
-- ============================================================
local ADDON, ns = ...
local L, Util, Scanner = ns.L, ns.Util, ns.Scanner

local Rules = {}
ns.Rules = Rules

Rules.BIND_VALUES = { "any", "warbound", "unbound" }

function Rules.BindText(v)
    if v == "warbound" then return L.BIND_WARBOUND end
    if v == "unbound"  then return L.BIND_UNBOUND end
    return L.BIND_ANY
end

-- --- Construction ------------------------------------------

function Rules.New()
    return {
        enabled    = true,
        label      = "",
        recipient  = "",
        items      = {},
        classID    = nil,
        subclassID = nil,
        bind       = "any",
        minQuality = 0,
        scope      = "global",
        owner      = nil,
    }
end

---True when the rule is in force on the logged-in character.
function Rules.AppliesHere(rule)
    if not rule then return false end
    if rule.scope ~= "char" then return true end
    if not rule.owner then return true end
    return rule.owner == Util.MyFullName()
end

function Rules.ScopeText(rule)
    if not rule or rule.scope ~= "char" then return L.SCOPE_GLOBAL end
    return string.format(L.SCOPE_CHAR, rule.owner or Util.MyFullName())
end

function Rules.HasItems(rule)
    return rule and rule.items and next(rule.items) ~= nil
end

---Human readable one-liner for the rule list.
function Rules.Describe(rule, index)
    if not rule then return "?" end
    if rule.label and rule.label ~= "" then return rule.label end

    if Rules.HasItems(rule) then
        local n = 0
        for _ in pairs(rule.items) do n = n + 1 end
        return n .. " x Item"
    end

    local parts = {}
    local cls = Util.ClassName(rule.classID)
    if cls then
        local sub = Util.SubClassName(rule.classID, rule.subclassID)
        parts[#parts + 1] = sub and (cls .. " / " .. sub) or cls
    else
        parts[#parts + 1] = L.CFG_ALL
    end
    if rule.bind and rule.bind ~= "any" then
        parts[#parts + 1] = Rules.BindText(rule.bind)
    end
    if (rule.minQuality or 0) > 0 then
        parts[#parts + 1] = ">= " .. Util.QualityName(rule.minQuality)
    end
    if #parts == 0 then return string.format(L.CFG_UNNAMED, index or 0) end
    return table.concat(parts, ", ")
end

-- --- Matching ----------------------------------------------

---Criteria only: does this rule describe this item? Deliberately says
---nothing about whether the rule is in force on the logged-in character.
---The two are separate because a rule naming this character still means
---"the item belongs here" on characters where the rule itself never fires.
---@param rule table
---@param e table  entry from Scanner
---@return boolean
function Rules.Describes(rule, e)
    if not rule or rule.enabled == false then return false end
    if type(rule.recipient) ~= "string" or rule.recipient == "" then return false end

    -- explicit item list short-circuits every other criterion
    if Rules.HasItems(rule) then
        return e.itemID ~= nil and rule.items[e.itemID] == true
    end

    if rule.classID    ~= nil and e.classID    ~= rule.classID    then return false end
    if rule.subclassID ~= nil and e.subclassID ~= rule.subclassID then return false end
    if rule.bind and rule.bind ~= "any" and e.bind ~= rule.bind   then return false end
    if (e.quality or 0) < (rule.minQuality or 0)                  then return false end
    return true
end

-- --- Resolution --------------------------------------------

---Effective default recipient for items: the character override wins,
---otherwise the account-wide value. Returns nil when it resolves to the
---logged-in character, so an account-wide "everything to Bankchar" is
---simply inert while playing Bankchar.
---@return string|nil recipient, string|nil scope ("char"|"global")
function Rules.Target()
    local c = ns.charDB and ns.charDB.target
    if type(c) == "string" and c ~= "" then
        if Util.IsSelf(c) then return nil end
        return c, "char"
    end
    local g = ns.db and ns.db.target
    if type(g) == "string" and g ~= "" then
        if Util.IsSelf(g) then return nil end
        return g, "global"
    end
    return nil
end

---True if the item must never be mailed (hold list, "keep all").
function Rules.IsIgnored(itemID)
    return ns.Hold.IsBlocked(itemID)
end

---True when the rule can never fire on the logged-in character
---because it points right back at them. Purely informational; the
---enforcement lives in Rules.Resolve.
function Rules.IsInert(rule)
    if not rule or type(rule.recipient) ~= "string" then return false end
    return Util.IsSelf(rule.recipient)
end

---Evaluated per item, top down: the first matching rule wins and the
---rest are never asked. An item covered by rule 1 therefore ignores a
---broader rule 2 further down.
---@return string|nil recipient, string|nil source, number|nil ruleIndex
function Rules.Resolve(e)
    if not e then return nil end

    if Rules.IsIgnored(e.itemID) then return nil, "ignore" end

    for i = 1, #ns.db.rules do
        local rule = ns.db.rules[i]
        if Rules.Describes(rule, e) then
            -- A rule naming this character means the item has arrived, and
            -- that is true whether or not the rule fires here. Asking only
            -- rules in force was the bug: a rule owned by another character
            -- did not match at all, so the delivery it had just made fell
            -- through to the default recipient and was mailed right back.
            if Util.IsSelf(rule.recipient) then return nil, "self", i end
            if Rules.AppliesHere(rule) then return rule.recipient, "rule", i end
        end
    end

    -- implicit default rule
    local target = Rules.Target()
    if target then
        if e.bind == Scanner.WARBOUND then return target, "default", math.huge end
        if e.bind == Scanner.UNBOUND and ns.db.includeUnbound then
            return target, "default", math.huge
        end
    end

    return nil
end

-- --- Plan --------------------------------------------------

---Builds the full routing plan from the current bag contents.
---@return table plan { order = {recipient,...}, count = {[recipient]=pieces},
---                     stacks = {[recipient]=attachments}, total = pieces,
---                     ignored = pieces, unrouted = pieces }
function Rules.BuildPlan()
    local order, count, stacks, rank = {}, {}, {}, {}
    local total, ignored, unrouted, staying = 0, 0, 0, 0

    for _, e in ipairs(Scanner.Collect()) do
        local recipient, source, ruleIndex = Rules.Resolve(e)
        if recipient then
            if not count[recipient] then
                count[recipient] = 0
                order[#order + 1] = recipient
            end
            -- rank by the earliest rule that feeds this recipient, so the
            -- send order follows the rule list instead of bag order
            local r = ruleIndex or math.huge
            if r < (rank[recipient] or math.huge) then rank[recipient] = r end
            local qty = e.sendQty or e.count or 1
            count[recipient] = count[recipient] + qty
            stacks[recipient] = (stacks[recipient] or 0) + 1
            total = total + qty
        elseif source == "ignore" then
            ignored = ignored + (e.sendQty or e.count or 1)
        elseif source == "self" then
            staying = staying + (e.sendQty or e.count or 1)
        else
            unrouted = unrouted + (e.sendQty or e.count or 1)
        end
    end

    table.sort(order, function(a, b)
        local ra, rb = rank[a] or math.huge, rank[b] or math.huge
        if ra ~= rb then return ra < rb end
        return a < b
    end)

    return { order = order, count = count, stacks = stacks, total = total,
             ignored = ignored, unrouted = unrouted, staying = staying }
end

-- --- Persistence helpers -----------------------------------

function Rules.Move(index, delta)
    local r = ns.db.rules
    local target = index + delta
    if not r[index] or not r[target] then return false end
    r[index], r[target] = r[target], r[index]
    return true
end

function Rules.Delete(index)
    if not ns.db.rules[index] then return nil end
    return table.remove(ns.db.rules, index)
end

---Validates and stores a rule. Returns nil + reason on failure.
---
---A rule may name the logged-in character. It has to: a rule that
---applies to every character has to point at *some* character, and on
---that one it is simply inert. Rules.Resolve drops those items before
---any mail is composed, so no postage is ever paid. Rejecting it here
---would also break the legitimate case of editing another character's
---rule that happens to send to this one.
function Rules.Save(index, rule)
    local recipient, err = Util.NormalizeRecipient(rule.recipient or "")
    if not recipient then return nil, err end

    rule.recipient = recipient
    rule.bind = (rule.bind == "warbound" or rule.bind == "unbound") and rule.bind or "any"
    rule.minQuality = Util.Clamp(rule.minQuality or 0, 0, 7)
    if type(rule.items) ~= "table" then rule.items = {} end
    if rule.enabled == nil then rule.enabled = true end

    if rule.scope == "char" then
        -- keep an existing owner so editing someone else's rule does
        -- not silently reassign it
        rule.owner = rule.owner or Util.MyFullName()
    else
        rule.scope, rule.owner = "global", nil
    end

    if index and ns.db.rules[index] then
        ns.db.rules[index] = rule
    else
        ns.db.rules[#ns.db.rules + 1] = rule
        index = #ns.db.rules
    end
    return index
end
