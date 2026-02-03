-- KillOnSight: Midnight - Stats module (Retail BG/WPvP focused)
--
-- Owns all Stats-related state:
--  * PvP outcomes (wins/losses) without relying on CLEU
--  * Spy-style "encounter" counting (seen encounters) with timeouts
--  * Reset safety (no resurrection)

local Stats = {}

local ENCOUNTER_TIMEOUT = 60 -- seconds since last touch to count as one encounter

local encounterTicker
local activeEncounters = {} -- [guid] = { name = "Name", nameLower = "name", lastTouchAt = epoch }

local function IsPlayerGUID(guid)
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
  if not n or n == "" then return nil end
  return (n:match("^[^-]+") or n)
end

-- --------------------------------------------------
-- Encounter tracking
-- --------------------------------------------------

function Stats:TouchEncounter(guid, name, classFile, guild)
  if not guid or guid == "" then return end
  if not IsPlayerGUID(guid) then return end

  local cn = CleanName(name)
  if not cn then return end
  if IsGroupOrSelfByName and IsGroupOrSelfByName(cn) then return end

  local DB = GetDB()
  if not DB then return end

  -- Keep metadata fresh (do not increment seenCount here)
  if DB.NoteEnemySeen then
    DB:NoteEnemySeen(cn, classFile, guild, guid)
  end

  local now = time()
  local e = activeEncounters[guid]
  if not e then
    activeEncounters[guid] = { name = cn, nameLower = cn:lower(), lastTouchAt = now }
  else
    e.name = e.name or cn
    e.nameLower = e.nameLower or cn:lower()
    e.lastTouchAt = now
  end
end

function Stats:ResolveEncounter(guid)
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
  local DB = GetDB()
  if not DB then return end

  local name, classFile, guild, guid
  if nameHint and nameHint ~= "" then
    name, classFile, guild, guid = PopEngagementForName(nameHint)
  else
    name, classFile, guild, guid = PopMostRecentEngagement(maxAge)
  end
  if not name or name == "" then return end

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

function Stats:OnEvent(event)
  if event == "PLAYER_PVP_KILLS_CHANGED" then
    TouchOutcome("win")
    return
  end

  if event == "PLAYER_KILLING_BLOW" then
    local name = ...
    TouchOutcome("win", name)
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
  -- Also clear encounter sessions.
  for k in pairs(activeEncounters) do
    activeEncounters[k] = nil
  end
end

_G.KillOnSight_MidnightStats = Stats
return Stats
