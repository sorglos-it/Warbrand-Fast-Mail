-- ============================================================
-- Warbrand-Fast-Mail / Lib/Categories.lua
-- Category and subcategory lists for the rule editor.
--
-- Enum.ItemClass still carries long-dead entries (Projectile,
-- Quiver, the two *Obsolete classes) and GetItemClassInfo happily
-- returns localized names for them, so enumerating the Enum puts
-- categories in the dropdown that no current item can ever match.
--
-- The auction house already solves this: Blizzard maintains
-- AuctionCategories as the browse tree of everything actually
-- tradeable, localized and current. This module loads
-- Blizzard_AuctionHouseUI on demand and derives the lists from it.
--
-- Fallback, when that addon cannot be loaded: an explicit list of
-- live item classes. Kept as data at the top of the file so it is
-- one edit to adjust after a patch.
-- ============================================================
local ADDON, ns = ...
local L, Util = ns.L, ns.Util

local Categories = {}
ns.Categories = Categories

-- --- Fallback data -----------------------------------------
-- Item classes that still exist in modern retail. Deliberately
-- omitted: Projectile (6), CurrencyTokenObsolete (10), Quiver (11),
-- PermanentObsolete (14) -- all removed from the game.

local LIVE_CLASSES = {
    "Consumable", "Container", "Weapon", "Gem", "Armor", "Reagent",
    "Tradegoods", "ItemEnhancement", "Recipe", "Questitem",
    "Miscellaneous", "Battlepet", "WoWToken", "Profession",
}

-- Subclasses of live classes that no longer receive items.
local DEAD_SUBCLASSES = {
    [2]  = { [10] = true, [14] = true, [16] = true, [17] = true }, -- Weapon: legacy slots, Thrown
    [4]  = { [7] = true, [8] = true, [9] = true, [10] = true, [11] = true }, -- Armor: Libram/Idol/Totem/Sigil/Relic
}

-- --- State -------------------------------------------------

local cache = { classes = nil, sub = {}, source = nil }

function Categories.Source()
    return cache.source == "ah" and L.CAT_SOURCE_AH or L.CAT_SOURCE_FB
end

function Categories.Invalidate()
    cache.classes, cache.sub, cache.source = nil, {}, nil
end

-- --- Auction house tree ------------------------------------

---Collects every filter of a category, including nested ones.
local function CollectFilters(cat, out)
    if type(cat) ~= "table" then return out end
    if type(cat.filters) == "table" then
        for _, f in ipairs(cat.filters) do out[#out + 1] = f end
    end
    if type(cat.subCategories) == "table" then
        for _, sub in ipairs(cat.subCategories) do CollectFilters(sub, out) end
    end
    return out
end

---A category is usable only when every one of its filters names the
---same class (resp. subclass). Mixed categories are dropped rather
---than guessed at.
local function UniformField(cat, field)
    local value
    for _, f in ipairs(CollectFilters(cat, {})) do
        local v = f[field]
        if v == nil then return nil end
        if value == nil then value = v elseif value ~= v then return nil end
    end
    return value
end

local function LoadAuctionUI()
    if _G.AuctionCategories then return true end
    local load = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
    if not load then return false end
    Util.Try(load, "Blizzard_AuctionHouseUI")
    return _G.AuctionCategories ~= nil
end

-- --- Public lists ------------------------------------------

---@return table list  { { value = classID, text = name }, ... }
function Categories.Classes()
    if cache.classes then return cache.classes end

    local out, seen = {}, {}

    if LoadAuctionUI() then
        for _, cat in ipairs(_G.AuctionCategories) do
            local classID = UniformField(cat, "classID")
            if classID and not seen[classID] and cat.name and cat.name ~= "" then
                seen[classID] = true
                out[#out + 1] = { value = classID, text = cat.name, ahCategory = cat }
            end
        end
        if #out > 0 then cache.source = "ah" end
    end

    if #out == 0 then
        cache.source = "fallback"
        for _, key in ipairs(LIVE_CLASSES) do
            local id = Enum.ItemClass and Enum.ItemClass[key]
            if type(id) == "number" and not seen[id] then
                local name = Util.ClassName(id)
                if name and name ~= "" then
                    seen[id] = true
                    out[#out + 1] = { value = id, text = name }
                end
            end
        end
    end

    table.sort(out, function(a, b) return a.text < b.text end)
    cache.classes = out
    return out
end

---@return table list  { { value = subClassID, text = name }, ... }
function Categories.SubClasses(classID)
    if classID == nil then return {} end
    if cache.sub[classID] then return cache.sub[classID] end

    local out, seen = {}, {}

    -- prefer the auction house subtree of the matching category
    for _, entry in ipairs(Categories.Classes()) do
        if entry.value == classID and entry.ahCategory
           and type(entry.ahCategory.subCategories) == "table" then
            for _, sub in ipairs(entry.ahCategory.subCategories) do
                local subID = UniformField(sub, "subClassID")
                if subID and not seen[subID] and sub.name and sub.name ~= "" then
                    seen[subID] = true
                    out[#out + 1] = { value = subID, text = sub.name }
                end
            end
            break
        end
    end

    if #out == 0 then
        local dead = DEAD_SUBCLASSES[classID] or {}
        for i = 0, 24 do
            if not dead[i] then
                local name = Util.SubClassName(classID, i)
                if name and name ~= "" then out[#out + 1] = { value = i, text = name } end
            end
        end
    end

    table.sort(out, function(a, b) return a.text < b.text end)
    cache.sub[classID] = out
    return out
end
