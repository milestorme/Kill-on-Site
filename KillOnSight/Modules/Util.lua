-- Util.lua
-- Shared helpers (loaded early)
local ADDON_NAME = ...
local L = KillOnSight_L
if type(L) ~= "table" then
  local _lf = { KOS = "KoS", GUILD_KOS = "Guild KoS", HIDDEN = "Hidden" }
  L = setmetatable({}, { __index = function(_, k) return _lf[k] or tostring(k) end })
end

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

_G.KillOnSight_Util = Util
