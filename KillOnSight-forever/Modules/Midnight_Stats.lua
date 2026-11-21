-- KillOnSight: Midnight - Stats module (Retail BG/WPvP focused)
--
-- Owns all Stats-related state:
--  * PvP outcomes (wins/losses) without relying on CLEU
--  * Spy-style "encounter" counting (seen encounters) with timeouts
--  * Reset safety (no resurrection)

local Stats = {}
local guard = _G.KillOnSight_Util
local function Disabled() return guard and guard:IsDisabledInstance() end
local function PublicGUID(value) return guard and guard:SafePublicGUID(value) end

local ENCOUNTER_TIMEOUT = 60 -- seconds since last touch to count as one encounter

local encounterTicker
local activeEncounters = {} -- [guid] = { name = "Name", nameLower = "name", lastTouchAt = epoch }
-- Best-effort pet kill attribution. No combat-log access is required.
local petTargets, confirmedKills, recentPlayerWins = {}, {}, {}
local PET_TARGET_WINDOW, KILL_DEDUP_WINDOW = 4, 5
local function SafeGUID(unit)
  if not UnitGUID then return nil end
  local ok, value = pcall(UnitGUID, unit)
  return ok and PublicGUID(value) or nil
end
local function Clock() return GetTime and GetTime() or 0 end
local function TrackPetTarget()
  if Disabled() then return end
  if not SafeGUID("pet") then return end
  local guid = SafeGUID("pettarget")
  if guid and guid:match("^Player%-") then petTargets[guid] = Clock() end
end


-- Called from the existing one-second visible-enemy scan.
function Stats:TrackPetTarget()
  TrackPetTarget()
end


local function IsPlayerGUID(guid)
  guid = PublicGUID(guid)
  return guid and guid:match('^Player%-') ~= nil
end

local function GetDB()
  return _G.KillOnSight_DB
end

local function ScheduleGUIRefresh()
  local Core = _G.KillOnSight_Core
  if Core and Core._ScheduleGUIRefresh then
    Core:_ScheduleGUIRefresh()
  elseif Core and Core.ScheduleGUIRefresh then
    Core:ScheduleGUIRefresh()
  end
end

local function CleanName(n)
  local util = _G.KillOnSight_Util
  return util and util:NormalizePlayerName(n) or n
end

local function IsGroupOrSelfByName(name)
  if not name or name == "" then return true end
  local util = _G.KillOnSight_Util
  local key = util and util:PlayerKey(name)
  if not key then return false end
  local function same(unit)
    return util:PlayerKey(util:UnitPlayerName(unit)) == key
  end
  if same("player") then return true end
  if IsInGroup and IsInGroup() then
    if IsInRaid and IsInRaid() then
      for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
        if same("raid"..i) then return true end
      end
    else
      for i = 1, 4 do if same("party"..i) then return true end end
    end
  end
  return false
end

-- --------------------------------------------------
-- Encounter tracking
-- --------------------------------------------------

function Stats:TouchEncounter(guid, name, classFile, guild)
  if Disabled() then return end
  guid = PublicGUID(guid)
  if not guid or guid == "" then return end
  if not IsPlayerGUID(guid) then return end

  local cn = CleanName(name)
  if not cn then return end
  if IsGroupOrSelfByName(cn) then return end

  local DB = GetDB()
  if not DB then return end

  -- Keep metadata fresh (do not increment seenCount here)
  if DB.NoteEnemySeen then
    local full = name or cn
    DB:NoteEnemySeen(full, classFile, guild, guid)
  end

  local now = time()
  local e = activeEncounters[guid]
  if not e then
    activeEncounters[guid] = { name = name, nameLower = cn:lower(), lastTouchAt = now }
  else
    if name and (not e.name or #name > #e.name) then e.name = name end
    e.nameLower = e.nameLower or cn:lower()
    e.lastTouchAt = now
  end
end

function Stats:ResolveEncounter(guid)
  if Disabled() then return end
  guid = PublicGUID(guid)
  if not guid or guid == "" then return end
  local e = activeEncounters[guid]
  if not e then return end

  local DB = GetDB()
  if DB and DB.StatsAddSeenEncounter then
    DB:StatsAddSeenEncounter(e.name or e.nameLower or "")
  end

  activeEncounters[guid] = nil
end

local function StartEncounterTicker()
  if encounterTicker then return end
  if not C_Timer or not C_Timer.NewTicker then return end

  encounterTicker = C_Timer.NewTicker(5, function()
    if Disabled() then return end
    local DB = GetDB()
    if not DB then return end

    local now = time()
    for guid, e in pairs(activeEncounters) do
      if e and e.lastTouchAt and (now - e.lastTouchAt) >= ENCOUNTER_TIMEOUT then
        if DB.StatsAddSeenEncounter then
          DB:StatsAddSeenEncounter(e.name or e.nameLower or "")
        end
        activeEncounters[guid] = nil
      end
    end
  end)
end

function Stats:Init()
  StartEncounterTicker()
end

-- --------------------------------------------------
-- PvP outcomes (Retail best-effort)
-- --------------------------------------------------

-- Pull the most recent engaged enemy from the Detector queue.
-- (Detector maintains this on Retail because we avoid CLEU.)
local function PopMostRecentEngagement(maxAge)
  local Detector = _G.KillOnSight_Detector
  if Detector and Detector.PopMostRecentEngagement then
    return Detector:PopMostRecentEngagement(maxAge)
  end
  return nil
end

local function PopEngagementForName(name)
  local Detector = _G.KillOnSight_Detector
  if Detector and Detector.PopEngagementForName then
    return Detector:PopEngagementForName(name)
  end
  return nil
end

local function TouchOutcome(kind, nameHint, maxAge)
  if Disabled() then return end
  local DB = GetDB()
  if not DB then return end

  local name, classFile, guild, guid
  if nameHint and nameHint ~= "" then
    name, classFile, guild, guid = PopEngagementForName(nameHint)
  else
    name, classFile, guild, guid = PopMostRecentEngagement(maxAge)
  end
  if not name or name == "" then return end
  guid = PublicGUID(guid)

  -- Hard safety: never create stats records for non-player GUIDs.
  if guid and guid ~= "" and not IsPlayerGUID(guid) then
    return
  end

  -- Count this as an encounter session (one per outcome).
  if guid and guid ~= "" then
    Stats:TouchEncounter(guid, name, classFile, guild)
  else
    -- No GUID: still keep metadata fresh
    if DB.NoteEnemySeen then
      DB:NoteEnemySeen(name, classFile, guild, guid)
    end
  end

  if kind == "win" then
    if DB.StatsAddWin then DB:StatsAddWin(name) end
  else
    if DB.StatsAddLoss then DB:StatsAddLoss(name) end
  end

  -- Resolve (adds exactly one SeenEncounter) if we have a GUID, otherwise just add one.
  if guid and guid ~= "" then
    Stats:ResolveEncounter(guid)
  else
    if DB.StatsAddSeenEncounter then DB:StatsAddSeenEncounter(name) end
  end

  if DB._BumpStatsRevision then DB:_BumpStatsRevision() end
  ScheduleGUIRefresh()
end

function Stats:OnEvent(event, ...)
  if Disabled() then return end
  if event == "PLAYER_PVP_KILLS_CHANGED" then
    recentPlayerWins[#recentPlayerWins + 1] = Clock()
    TouchOutcome("win")
    return
  end

  if event == "PLAYER_DEAD" then
    TouchOutcome("loss", nil, 60)
    return
  end
end

-- Called by GUI Reset Stats accept handler.
function Stats:OnResetStats()
  -- Clear any detector queues so no stale engagement can repopulate stats.
  local Detector = _G.KillOnSight_Detector
  if Detector and Detector.ResetEngagementQueue then
    Detector:ResetEngagementQueue()
  end
  for k in pairs(petTargets) do petTargets[k] = nil end
  for k in pairs(confirmedKills) do confirmedKills[k] = nil end
  for k in pairs(recentPlayerWins) do recentPlayerWins[k] = nil end
  -- Also clear encounter sessions.
  for k in pairs(activeEncounters) do
    activeEncounters[k] = nil
  end
end

-- UNIT_DIED is only useful when the client exposes a non-secret player GUID.
-- Pet-target proximity is a heuristic, so never credit a death when a kill
-- event already accounted for it or when the victim is unidentified.
local petFrame = CreateFrame("Frame")
for _, event in ipairs({"UNIT_DIED", "PARTY_KILL", "UNIT_TARGET", "UNIT_PET"}) do
  pcall(petFrame.RegisterEvent, petFrame, event)
end
petFrame:SetScript("OnEvent", function(_, event, ...)
  if Disabled() then return end
  if event == "UNIT_TARGET" or event == "UNIT_PET" then
    TrackPetTarget()
    return
  end
  local a, b = ...
  if event == "PARTY_KILL" then
    local victim = PublicGUID(b)
    if victim then confirmedKills[victim] = Clock() end
    return
  end
  if event ~= "UNIT_DIED" then return end
  local guid = PublicGUID(a)
  if not guid or not guid:match("^Player%-") then return end
  local last = petTargets[guid]
  if not last or Clock() - last > PET_TARGET_WINDOW then return end
  local encounter = activeEncounters[guid]
  if not encounter or not encounter.name or encounter.name == "" then return end
  local deathAt = Clock()
  local name = encounter.name
  if C_Timer and C_Timer.After then
    C_Timer.After(1, function()
      if Disabled() then return end
      if confirmedKills[guid] and math.abs(confirmedKills[guid] - deathAt) <= KILL_DEDUP_WINDOW then return end
      for _, at in ipairs(recentPlayerWins) do
        if math.abs(at - deathAt) <= KILL_DEDUP_WINDOW then return end
      end
      local DB = GetDB()
      if not DB or not DB.StatsAddWin then return end
      if not petTargets[guid] or petTargets[guid] ~= last then return end
      petTargets[guid] = nil
      DB:StatsAddWin(name)
      Stats:ResolveEncounter(guid)
      if DB._BumpStatsRevision then DB:_BumpStatsRevision() end
      ScheduleGUIRefresh()
    end)
  end
end)
if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(10, function()
    local now = Clock()
    for guid, at in pairs(petTargets) do if now - at > 60 then petTargets[guid] = nil end end
    for guid, at in pairs(confirmedKills) do if now - at > 60 then confirmedKills[guid] = nil end end
    for i = #recentPlayerWins, 1, -1 do
      if now - recentPlayerWins[i] > 10 then table.remove(recentPlayerWins, i) end
    end
  end)
end

_G.KillOnSight_MidnightStats = Stats
return Stats
