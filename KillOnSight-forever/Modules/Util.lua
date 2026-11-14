-- Util.lua
-- Shared helpers (loaded early)
local ADDON_NAME = ...
local L = KillOnSight_L

local Util = {}

-- Append unified tags to a pre-colored name.
-- Used by Nearby / Attackers / Stats so tag logic isn't duplicated.
function Util:AppendTags(nameText, isKoS, isGuild)
  local out = nameText or ""

  if isKoS then
    local tag = (L and (L.UI_TAG_KOS or L.UI_STATS_KOS_TAG)) or "KoS"
    out = out .. " |cffff0000[" .. tag .. "]|r"
  end

  if isGuild then
    local tag = (L and (L.UI_TAG_GUILD)) or "Guild"
    out = out .. " |cffffd000[" .. tag .. "]|r"
  end

  return out
end


-- Canonical unit identity shared across the addon. Forever uses First Surname;
-- normal clients retain their existing Name-Realm identity.
function Util:IsForeverNames()
  if type(_G.RegionalUniqueNamesEnabled) ~= "function" then return false end
  local ok, enabled = pcall(_G.RegionalUniqueNamesEnabled)
  return ok and enabled == true
end

function Util:NormalizePlayerName(name)
  if type(name) ~= "string" then return nil end
  local ok, clean = pcall(function() return name:match("^%s*(.-)%s*$") end)
  if not ok or clean == "" then return nil end
  return clean:gsub("%s+", " ")
end

function Util:UnitPlayerName(unit)
  if not unit then return nil end
  local function safe(fn, ...)
    if type(fn) ~= "function" then return nil, nil end
    local ok, a, b = pcall(fn, ...)
    if ok and type(a) == "string" and a ~= "" then return a, b end
  end
  local first, second = safe(_G.UnitFullName, unit)
  if self:IsForeverNames() then
    -- GetUnitName(unit, true) is preferred on Forever; use the two return values
    -- only when it does not provide a full name.
    local full = safe(_G.GetUnitName, unit, true)
    if full and full:find(" ", 1, true) then return self:NormalizePlayerName(full) end
    if first and type(second) == "string" and second ~= "" then
      return self:NormalizePlayerName(first .. " " .. second)
    end
    local a,b = safe(_G.UnitName, unit)
    if a and type(b) == "string" and b ~= "" then return self:NormalizePlayerName(a .. " " .. b) end
    return self:NormalizePlayerName(full or first or a)
  end
  if first then
    if type(second) == "string" and second ~= "" then return first .. "-" .. second end
    return first
  end
  return self:NormalizePlayerName(safe(_G.UnitName, unit))
end

function Util:PlayerKey(name)
  name = self:NormalizePlayerName(name)
  if not name then return nil end
  -- Only Forever uses spaces for surnames. Never truncate a Forever identity.
  if self:IsForeverNames() then
    name = name:gsub("%s*%-%s*", " ")
  end
  return name:lower()
end

function Util:SamePlayer(a, b)
  local ka, kb = self:PlayerKey(a), self:PlayerKey(b)
  return ka ~= nil and kb ~= nil and ka == kb
end

function Util:NameForUnitOr(unit, fallback)
  return self:UnitPlayerName(unit) or self:NormalizePlayerName(fallback)
end

_G.KillOnSight_Util = Util
