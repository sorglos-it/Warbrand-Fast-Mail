-- ============================================================
-- Warbrand-Fast-Mail / Lib/Util.lua
-- Central helper library. No game state, no side effects.
-- Every public function validates its own input.
-- ============================================================
local ADDON, ns = ...

local Util = {}
ns.Util = Util

local PREFIX = "|cff33ff99Warbrand-Fast-Mail|r: "

-- Subject line used when the user has not set one. Defined once here
-- because four call sites need the same fallback: the defaults table,
-- the settings window, the mailer and the gold transfer.
Util.DEFAULT_SUBJECT = "Warbrand-Fast-Mail"

-- --- Output ------------------------------------------------

function Util.Print(fmt, ...)
    if type(fmt) ~= "string" then return end
    local msg = fmt
    if select("#", ...) > 0 then
        local ok, res = pcall(string.format, fmt, ...)
        msg = ok and res or fmt
    end
    (DEFAULT_CHAT_FRAME or ChatFrame1):AddMessage(PREFIX .. msg)
end

function Util.Debug(fmt, ...)
    if not (ns.db and ns.db.debug) then return end
    if type(fmt) ~= "string" then fmt = tostring(fmt) end
    local msg = fmt
    if select("#", ...) > 0 then
        local ok, res = pcall(string.format, fmt, ...)
        msg = ok and res or fmt
    end
    (DEFAULT_CHAT_FRAME or ChatFrame1):AddMessage(PREFIX .. "|cff888888[dbg]|r " .. msg)
end

-- --- Guards ------------------------------------------------

---pcall wrapper for optional / renamed API functions.
function Util.Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

function Util.Clamp(v, lo, hi)
    v = tonumber(v)
    if not v then return lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return math.floor(v)
end

function Util.Trim(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- --- API compat shims --------------------------------------
-- Several item functions were namespaced into C_Item in 10.2.6.
-- Resolve once, use everywhere.

local function pick(a, b) return (type(a) == "function" and a) or (type(b) == "function" and b) or nil end

Util.API = {
    GetItemInfo         = pick(C_Item and C_Item.GetItemInfo,         _G.GetItemInfo),
    GetItemInfoInstant  = pick(C_Item and C_Item.GetItemInfoInstant,  _G.GetItemInfoInstant),
    GetItemClassInfo    = pick(C_Item and C_Item.GetItemClassInfo,    _G.GetItemClassInfo),
    GetItemSubClassInfo = pick(C_Item and C_Item.GetItemSubClassInfo, _G.GetItemSubClassInfo),
    GetDetailedItemLevelInfo = pick(C_Item and C_Item.GetDetailedItemLevelInfo, _G.GetDetailedItemLevelInfo),
    GetCoinTextureString = pick(C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString, _G.GetCoinTextureString),
}

-- --- Version / interface -----------------------------------
-- Interface numbers are packed as xxyyzz: 120100 == WoW 12.1.0.

Util.API.GetAddOnMetadata = pick(C_AddOns and C_AddOns.GetAddOnMetadata, _G.GetAddOnMetadata)

---@return number interface, e.g. 120100
function Util.ClientInterface()
    local n = select(4, GetBuildInfo())
    return tonumber(n) or 0
end

---Splits a packed interface number into major, minor, patch.
function Util.SplitInterface(n)
    n = tonumber(n) or 0
    return math.floor(n / 10000), math.floor(n / 100) % 100, n % 100
end

---"12.1.0" for 120100.
function Util.InterfaceString(n)
    local a, b, c = Util.SplitInterface(n)
    return string.format("%d.%d.%d", a, b, c)
end

---Reads a "## " field from the TOC.
function Util.Meta(addon, field)
    if not Util.API.GetAddOnMetadata then return nil end
    return Util.Try(Util.API.GetAddOnMetadata, addon, field)
end

-- --- Money -------------------------------------------------

Util.COPPER_PER_GOLD = (_G.COPPER_PER_SILVER or 100) * (_G.SILVER_PER_GOLD or 100)

---Formatted money string with coin icons.
function Util.Money(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    if Util.API.GetCoinTextureString then
        local s = Util.Try(Util.API.GetCoinTextureString, copper)
        if s then return s end
    end
    return string.format("%d g", math.floor(copper / Util.COPPER_PER_GOLD))
end

---Parses a whole-gold amount into copper. Tolerates 1.000 / 1,000 / 1 000.
---@return number|nil copper
function Util.GoldToCopper(text)
    if type(text) == "number" then text = tostring(math.floor(text)) end
    if type(text) ~= "string" then return nil end
    local clean = text:gsub("[%s%.,']", "")
    if clean == "" then return 0 end
    if not clean:match("^%d+$") then return nil end
    local g = tonumber(clean)
    if not g or g < 0 or g > 9999999 then return nil end
    return math.floor(g) * Util.COPPER_PER_GOLD
end

function Util.CopperToGold(copper)
    return math.floor((tonumber(copper) or 0) / Util.COPPER_PER_GOLD)
end

-- --- Mail frame helper -------------------------------------
-- The only function in this file that touches game state; kept
-- here because both Mailer and Gold need exactly this.

Util.MAIL_SEND_TAB = 2

function Util.EnsureMailSendTab()
    if MailFrame and MailFrame.selectedTab ~= Util.MAIL_SEND_TAB then
        Util.Try(MailFrameTab_OnClick, _G["MailFrameTab" .. Util.MAIL_SEND_TAB], Util.MAIL_SEND_TAB)
    end
end

function Util.MailboxOpen()
    return (MailFrame and MailFrame:IsShown()) and true or false
end

---Number of filled attachment slots in the send-mail frame.
function Util.MailAttachments()
    local max, n = _G.ATTACHMENTS_MAX_SEND or 12, 0
    for i = 1, max do
        if GetSendMailItem(i) then n = n + 1 end
    end
    return n
end

---Index of the first empty attachment slot, or nil.
function Util.FirstFreeMailSlot()
    for i = 1, _G.ATTACHMENTS_MAX_SEND or 12 do
        if not GetSendMailItem(i) then return i end
    end
end

-- --- Recipient validation ----------------------------------
-- Strict whitelist. Blocks UI escape sequences, control chars,
-- quotes and backslashes before anything reaches SendMail.

local CHAR_PATTERN  = "^[%a\128-\255][%a\128-\255]*$"
local REALM_PATTERN = "^[%a\128-\255][%a\128-\255'%-]*$"

---@return string|nil normalised, string|nil errorReason
function Util.NormalizeRecipient(input)
    if type(input) ~= "string" then return nil, "type" end

    local name = Util.Trim(input)
    if name == "" then return nil, "empty" end
    if #name > 48 then return nil, "length" end
    if name:find("|", 1, true) then return nil, "escape" end
    if name:find("%c") then return nil, "control" end
    if name:find('"', 1, true) or name:find("\\", 1, true) then return nil, "quote" end

    local charPart, realmPart = name:match("^([^%-]+)%-(.+)$")
    if not charPart then charPart, realmPart = name, nil end

    if not charPart:match(CHAR_PATTERN) then return nil, "charname" end
    if #charPart < 2 or #charPart > 24 then return nil, "charlen" end

    if realmPart then
        realmPart = realmPart:gsub("%s+", "")
        if not realmPart:match(REALM_PATTERN) then return nil, "realm" end
        return charPart .. "-" .. realmPart
    end
    return charPart
end

---"Name-Realm" of the logged-in character, realm without spaces.
function Util.MyFullName()
    local me = UnitName("player") or "?"
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
    if realm ~= "" then return me .. "-" .. realm end
    return me
end

function Util.IsSelf(recipient)
    if type(recipient) ~= "string" then return false end
    local me = UnitName("player") or ""
    local myRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
    local t = recipient:lower()
    return t == me:lower() or t == (me .. "-" .. myRealm):lower()
end

-- --- Item helpers ------------------------------------------

function Util.ToItemID(input)
    if type(input) == "number" then return math.floor(input) end
    if type(input) ~= "string" then return nil end
    local id = input:match("item:(%d+)")
    return tonumber(id) or tonumber(input:match("^%s*(%d+)%s*$"))
end

---Coloured item link if cached, otherwise a stable placeholder.
function Util.ItemLink(itemID)
    if not itemID then return "?" end
    if Util.API.GetItemInfo then
        local _, link = Util.API.GetItemInfo(itemID)
        if link then return link end
    end
    return "|cff888888item:" .. tostring(itemID) .. "|r"
end

---Plain item name for searching. Returns nil while the item is not
---cached yet and asks the client to load it; GET_ITEM_INFO_RECEIVED
---then triggers a refresh of the open list.
function Util.ItemName(itemID)
    if not itemID then return nil end
    if Util.API.GetItemInfo then
        local name = Util.API.GetItemInfo(itemID)
        if name and name ~= "" then return name end
    end
    if C_Item and C_Item.RequestLoadItemDataByID then
        Util.Try(C_Item.RequestLoadItemDataByID, itemID)
    end
    return nil
end

---Case-insensitive, accent-tolerant substring test used by the
---search boxes. Needles are matched literally, never as patterns.
function Util.Matches(haystack, needle)
    if needle == nil or needle == "" then return true end
    if type(haystack) ~= "string" then return false end
    return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

---Localized category name for an Enum.ItemClass value.
function Util.ClassName(classID)
    if classID == nil or not Util.API.GetItemClassInfo then return nil end
    return Util.API.GetItemClassInfo(classID)
end

function Util.SubClassName(classID, subclassID)
    if classID == nil or subclassID == nil or not Util.API.GetItemSubClassInfo then return nil end
    return Util.API.GetItemSubClassInfo(classID, subclassID)
end

---Localized, coloured quality name.
function Util.QualityName(q)
    q = Util.Clamp(q or 0, 0, 7)
    local text = _G["ITEM_QUALITY" .. q .. "_DESC"] or tostring(q)
    local c = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[q]
    if c and c.hex then return c.hex .. text .. "|r" end
    return text
end
