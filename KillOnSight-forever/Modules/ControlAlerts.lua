-- Say a short callout when a recognized hostile crowd-control aura is applied.
-- Combat-log access is unavailable in Forever; use the player's aura API instead.
local frame = CreateFrame("Frame")
local util = _G.KillOnSight_Util

local CONTROL_AURAS = {
  { 6770, "sap", "Sapped!" }, { 2070, "sap", "Sapped!" }, { 11297, "sap", "Sapped!" },
  { 118, "polymorph", "Sheeped!" }, { 12824, "polymorph", "Sheeped!" },
  { 12825, "polymorph", "Sheeped!" }, { 12826, "polymorph", "Sheeped!" },
  { 28271, "polymorph", "Sheeped!" }, { 28272, "polymorph", "Sheeped!" },
  { 710, "banish", "Banished!" }, { 18647, "banish", "Banished!" },
}

local instanceDisabled = false
local activeControls = {}
local scanPending = false

local function IsSecret(value)
  if type(issecretvalue) == "function" and issecretvalue(value) then return true end
  if type(issecrettable) == "function" and issecrettable(value) then return true end
  return false
end

local function IsDisabledInstance()
  if util and util.IsDisabledInstance then
    local ok, disabled = pcall(function() return util:IsDisabledInstance() end)
    return not ok or disabled == true
  end
  if type(IsInInstance) ~= "function" then return false end
  local ok, inside = pcall(function() return IsInInstance() == true end)
  return not ok or inside == true
end

local function ReadAuraState(spellID)
  local secrets = C_Secrets
  if secrets and type(secrets.ShouldSpellAuraBeSecret) == "function" then
    local ok, hidden = pcall(secrets.ShouldSpellAuraBeSecret, spellID)
    if not ok or hidden == true then return nil end
  end

  local auraAPI = C_UnitAuras
  if not auraAPI or type(auraAPI.GetUnitAuraBySpellID) ~= "function" then return nil end
  local ok, aura = pcall(auraAPI.GetUnitAuraBySpellID, "player", spellID)
  if not ok or IsSecret(aura) then return nil end
  return aura ~= nil
end

local function ScanControlAuras()
  scanPending = false
  if instanceDisabled then return end

  local nextControls, uncertainGroups, announcements = {}, {}, {}
  for _, entry in ipairs(CONTROL_AURAS) do
    local spellID, group, message = entry[1], entry[2], entry[3]
    local state = ReadAuraState(spellID)
    if state == true then
      nextControls[group] = true
      if not activeControls[group] then announcements[group] = message end
    elseif state == nil then
      uncertainGroups[group] = true
    end
  end

  -- Keep prior state while Forever hides an aura, so an unreadable aura
  -- cannot cause duplicate callouts on every later UNIT_AURA event.
  for group in pairs(activeControls) do
    if uncertainGroups[group] then nextControls[group] = true end
  end

  for group, message in pairs(announcements) do
    if not activeControls[group] and type(SendChatMessage) == "function" then
      SendChatMessage(message, "SAY")
    end
  end
  activeControls = nextControls
end

local function ScheduleScan()
  if scanPending then return end
  scanPending = true
  if C_Timer and C_Timer.After then
    C_Timer.After(0.05, ScanControlAuras)
  else
    ScanControlAuras()
  end
end

frame:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_ENTERING_WORLD" then
    instanceDisabled = IsDisabledInstance()
    activeControls = {}
    scanPending = false
    return
  end

  if event == "UNIT_AURA" and unit == "player" and not instanceDisabled then
    ScheduleScan()
  end
end)

instanceDisabled = IsDisabledInstance()
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_AURA")
