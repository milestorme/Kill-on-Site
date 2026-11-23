-- PlayerIdentity.lua
-- Single source of truth for unit names and persistent player keys.
local Identity = {}

function Identity:IsForeverNames()
  if type(_G.RegionalUniqueNamesEnabled) ~= "function" then return false end
  local ok, enabled = pcall(_G.RegionalUniqueNamesEnabled)
  return ok and enabled == true
end

function Identity:NormalizePlayerName(name)
  if type(name) ~= "string" then return nil end
  local ok, clean = pcall(function() return name:match("^%s*(.-)%s*$") end)
  if not ok or clean == "" then return nil end
  return clean:gsub("%s+", " ")
end

function Identity:UnitPlayerName(unit)
  if not unit then return nil end
  local function safe(fn, ...)
    if type(fn) ~= "function" then return nil, nil end
    local ok, a, b = pcall(fn, ...)
    if ok and type(a) == "string" and a ~= "" then return a, b end
  end
  local first, second = safe(_G.UnitFullName, unit)
  if self:IsForeverNames() then
    -- Prefer Forever's explicit full name; fall back to its two name fields.
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

function Identity:PlayerKey(name)
  name = self:NormalizePlayerName(name)
  if not name then return nil end
  -- Only Forever uses spaces for surnames. Never truncate a Forever identity.
  if self:IsForeverNames() then name = name:gsub("%s*%-%s*", " ") end
  return name:lower()
end

function Identity:SamePlayer(a, b)
  local ka, kb = self:PlayerKey(a), self:PlayerKey(b)
  return ka ~= nil and kb ~= nil and ka == kb
end

function Identity:NameForUnitOr(unit, fallback)
  return self:UnitPlayerName(unit) or self:NormalizePlayerName(fallback)
end

function Identity:StatsKey(name)
  if type(name) ~= "string" or name == "" then return nil end
  if self:IsForeverNames() then
    -- Legacy Forever realm separators represented the surname.
    return (name:gsub("%-", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")):lower()
  end
  return (name:match("^[^-]+") or name):lower()
end

function Identity:MigrationIdentity(name)
  name = self:NormalizePlayerName(name)
  if type(name) ~= "string" then return nil end
  name = name:gsub("%s*%-%s*", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
  if name == "" then return nil end
  return name:lower(), name
end

_G.KillOnSight_Identity = Identity
