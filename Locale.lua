-- ============================================================
-- Warbrand-Fast-Mail / Locale.lua
-- Localization registry.
--
-- The actual strings live in lang\*.xml. The TOC loads
--   lang\enUS.xml          (always, as the base)
--   lang\[TextLocale].xml  (the client's locale, when shipped)
-- using the [TextLocale] path variable, so exactly one
-- translation is ever in memory next to the English base.
--
-- Language files call the temporary global registrar below.
-- Core.lua removes it once loading is done, so nothing of this
-- scaffolding survives into the running session.
-- ============================================================
local ADDON, ns = ...

local strings = {}

-- Missing keys resolve to their own name instead of nil, so a gap in
-- a translation degrades to a readable identifier, never to an error.
ns.L = setmetatable(strings, {
    __index = function(_, key) return tostring(key) end,
})

ns.localeLoaded = nil

---Merges a language table. Later calls overwrite earlier ones, which is
---exactly the enUS-then-locale order the TOC produces.
---@param code string  locale code, for diagnostics
---@param tbl table    [KEY] = "text"
function _G.Warbrand-Fast-Mail_RegisterLocale(code, tbl)
    if type(tbl) ~= "table" then return end
    local n = 0
    for key, value in pairs(tbl) do
        if type(key) == "string" and type(value) == "string" then
            strings[key] = value
            n = n + 1
        end
    end
    if n > 0 and code ~= "enUS" then ns.localeLoaded = code end
    return n
end
