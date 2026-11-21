-- Enemy-targeting-you warning. Spy-style one-second visible-unit scan plus events.
local f = CreateFrame("Frame")
local utilGate = _G.KillOnSight_Util
local function Disabled() return utilGate and utilGate:IsDisabledInstance() end
local active = {} -- GUID -> last time confirmed targeting player
local alerted = {} -- GUID -> last alert time
local STALE = 2.5
local ALERT_COOLDOWN = 30
local SCAN_INTERVAL = 0.5
local PET_SCAN_INTERVAL = 1
local function safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, ...)
  if ok then return result end
end
local function profile()
  local db = _G.KillOnSight_DB
  return db and db.GetProfile and db:GetProfile()
end
local function check(unit)
  if Disabled() or type(unit) ~= "string" then return end
  local guid = safe(UnitGUID, unit)
  if type(guid) ~= "string" or guid == "" then return end
  local enemy = safe(UnitIsEnemy, "player", unit)
  local playerUnit = safe(UnitIsPlayer, unit)
  local targeting = safe(UnitIsUnit, unit .. "target", "player")
  -- A protected/unknown result must not be treated as a target change.
  if enemy ~= true or playerUnit ~= true then return end
  if targeting == false then
    active[guid] = nil
    return
  end
  if targeting ~= true then return end
  local now = GetTime()
  local wasActive = active[guid] ~= nil
  active[guid] = now
  if wasActive then return end
  if alerted[guid] and now - alerted[guid] < ALERT_COOLDOWN then return end
  local p = profile()
  if not p or p.targetedAlert == false then return end
  alerted[guid] = now
  local util = _G.KillOnSight_Util
  local name = (util and util.UnitPlayerName and safe(util.UnitPlayerName, util, unit)) or safe(UnitName, unit) or "Enemy"
  -- Feed confirmed enemy sightings through the existing Nearby pipeline so
  -- identity merging, KoS/Guild classification and row ordering stay consistent.
  local nearby = _G.KillOnSight_Nearby
  local db = _G.KillOnSight_DB
  if nearby and nearby.Seen then
    local _, classFile = safe(UnitClass, unit)
    local guild = safe(GetGuildInfo, unit)
    local level = safe(UnitLevel, unit)
    local kind
    if db then
      local entry = db.LookupPlayer and safe(db.LookupPlayer, db, name)
      if entry then
        kind = entry.type or "KoS"
      elseif guild and db.LookupGuild then
        local honor = db.LookupHonor and safe(db.LookupHonor, db, name)
        local guildEntry = not honor and safe(db.LookupGuild, db, guild)
        if guildEntry then kind = guildEntry.type or "Guild" end
      end
    end
    pcall(nearby.Seen, nearby, name, classFile, guild, kind, level, guid, unit)
  end
  -- Use the same styled banner as the stealth alert, in a separate frame.
  local notifier = _G.KillOnSight_Notifier
  if notifier and notifier.ShowTargetingAlert then
    local classFile
    if type(UnitClass) == "function" then
      local ok, _, token = pcall(UnitClass, unit)
      if ok then classFile = token end
    end
    local ok = pcall(notifier.ShowTargetingAlert, notifier, name, classFile)
    if not ok and RaidNotice_AddMessage and RaidWarningFrame then
      pcall(RaidNotice_AddMessage, RaidWarningFrame, string.format((_G.KillOnSight_L and _G.KillOnSight_L.UI_TARGETED_WARNING) or "ENEMY TARGETING YOU: %s", name), ChatTypeInfo and ChatTypeInfo.RAID_WARNING)
    end
  end
  if p.targetedAlertSound ~= false and _G.KillOnSight_AlertAudio then
    _G.KillOnSight_AlertAudio:Play("nearby")
  end
end
local function scan()
  if Disabled() then return end
  check("target")
  check("mouseover")
  if C_NamePlate and C_NamePlate.GetNamePlates then
    local plates = safe(C_NamePlate.GetNamePlates)
    if type(plates) == "table" then
      for _, plate in ipairs(plates) do
        local unit = plate and plate.namePlateUnitToken
        if unit then check(unit) end
      end
    end
  end
end
f:SetScript("OnEvent", function(_, event, unit)
  if Disabled() then
    wipe(active)
    wipe(alerted)
    return
  end
  if event == "PLAYER_ENTERING_WORLD" then
    wipe(active)
    wipe(alerted)
    return
  end
  if event == "NAME_PLATE_UNIT_REMOVED" then
    -- A disappearing nameplate is not proof the player stopped targeting us.
    -- Keep state until observed again; clear on zone transition.
    return
  end
  if event == "UNIT_TARGET" then
    if type(unit) == "string" and (unit == "target" or unit == "mouseover" or unit:match("^nameplate%d+$")) then check(unit) end
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    check(unit)
  elseif event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
    scan()
  end
end)
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "UNIT_TARGET", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT"}) do
  pcall(f.RegisterEvent, f, event)
end

-- Scan twice per second so changes to an enemy's target are detected even when
-- WoW does not deliver UNIT_TARGET for nameplate units. No continuous OnUpdate.
local elapsed = 0
local petElapsed = 0
f:SetScript("OnUpdate", function(_, dt)
  if Disabled() then
    elapsed = 0
    petElapsed = 0
    wipe(active)
    wipe(alerted)
    return
  end
  elapsed = elapsed + dt
  petElapsed = petElapsed + dt
  -- Preserve the existing one-second pet-target tracking cadence.
  if petElapsed >= PET_SCAN_INTERVAL then
    petElapsed = petElapsed % PET_SCAN_INTERVAL
    local stats = _G.KillOnSight_MidnightStats
    if stats and stats.TrackPetTarget then stats:TrackPetTarget() end
  end
  if elapsed < SCAN_INTERVAL then return end
  elapsed = elapsed % SCAN_INTERVAL
  local p = profile()
  if not p or p.targetedAlert == false then
    wipe(active)
    return
  end
  scan()
  local now = GetTime()
  for guid, lastSeen in pairs(active) do
    if now - lastSeen > STALE then active[guid] = nil end
  end
  for guid, lastAlert in pairs(alerted) do
    if now - lastAlert > ALERT_COOLDOWN + 60 then alerted[guid] = nil end
  end
end)
