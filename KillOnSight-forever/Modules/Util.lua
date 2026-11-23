-- Util.lua
-- Shared helpers (loaded early)
local ADDON_NAME = ...
local L = KillOnSight_L

local Util = {}

-- Shared fail-closed instance gate: all instanced content, including PvP.
function Util:IsDisabledInstance()
  if type(IsInInstance) ~= "function" then return false end
  local ok, disabled = pcall(function()
    local inside = IsInInstance()
    return inside == true
  end)
  return not ok or disabled == true
end

-- Compatibility alias for existing callers.
function Util:IsPvEInstance()
  return self:IsDisabledInstance()
end

-- A string may still be secret; pcall alone does not make it non-secret.
function Util:SafePublicGUID(value)
  local ok, public = pcall(function()
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) ~= "string" or value == "" then return nil end
    -- Exercise the value before using it as a table key.
    if not value:match("^[%w%-]+$") then return nil end
    return value
  end)
  return ok and public or nil
end


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


-- Compatibility surface: keep existing callers stable while routing all
-- player-name and key behavior through the canonical identity module.
local Identity = _G.KillOnSight_Identity
function Util:IsForeverNames() return Identity:IsForeverNames() end
function Util:NormalizePlayerName(name) return Identity:NormalizePlayerName(name) end
function Util:UnitPlayerName(unit) return Identity:UnitPlayerName(unit) end
function Util:PlayerKey(name) return Identity:PlayerKey(name) end
function Util:SamePlayer(a, b) return Identity:SamePlayer(a, b) end
function Util:NameForUnitOr(unit, fallback) return Identity:NameForUnitOr(unit, fallback) end

_G.KillOnSight_Util = Util
