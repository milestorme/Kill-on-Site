-- Detector.lua
local ADDON_NAME = ...
local L = KillOnSight_L

local function GetDB() return _G.KillOnSight_DB end
local function GetNotifier() return _G.KillOnSight_Notifier end
local function GetCore() return _G.KillOnSight_Core end
local function GetUnitGuild(unit)
  if not unit then return end
  local g = GetGuildInfo and GetGuildInfo(unit)
  if g and g ~= "" then return g end
end
local Detector = {}

-- Debounced GUI refresh (provided by Core)
local function _ScheduleGUIRefresh()
  local core = _G.KillOnSight_Core
  if core and core._ScheduleGUIRefresh then
    core._ScheduleGUIRefresh()
  end
end
local lastNotifyAt = {} -- [key] = time()
local lastCleanupAt = 0
local CLEANUP_INTERVAL = 600      -- seconds
local NOTIFY_TTL = 3600           -- seconds to keep keys

local function CleanupNotifyCache(now)
  if (now - (lastCleanupAt or 0)) < CLEANUP_INTERVAL then return end
  lastCleanupAt = now
  for k,t in pairs(lastNotifyAt) do
    if (not t) or (now - t) > NOTIFY_TTL then
      lastNotifyAt[k] = nil
    end
  end
end

local function Now() return time() end

local function InAllowedContext()
  local DB = GetDB()
  if not DB then return false end
  local prof = DB:GetProfile()
  if prof.notifyInInstances then return true end
  local inInstance = IsInInstance()
  return not inInstance
end

local function ShouldNotify(key)
  local DB = GetDB()
  if not DB then return false end
  local t = DB:GetProfile().throttleSeconds or 12
  local now = Now()
  CleanupNotifyCache(now)
  if lastNotifyAt[key] and (now - lastNotifyAt[key]) < t then
    return false
  end
  lastNotifyAt[key] = now
  return true
end

local function GetUnitNameSafe(unit)
  local name = UnitName(unit)
  if not name or name == "" then return nil end
  return name
end

-- Retail/Midnight: nameplates can appear at very long distances.
-- Distance-filter only the *Nearby list population* to keep it relevant.
local IS_RETAIL = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local DEFAULT_RETAIL_NEARBY_MAX_YARDS = 60


function Detector:CheckUnit(unit)
  local DB = GetDB()
  local Notifier = GetNotifier()
  if not DB or not Notifier then return end
  if not unit or not UnitExists(unit) then return end
  if not InAllowedContext() then return end
  if UnitIsUnit(unit, "player") then return end

  -- Retail-only: gate Nearby list updates by distance (nameplates can be very long-range in 12.x).
  local withinNearbyRange = true
  if IS_RETAIL and UnitDistanceSquared then
    local distSq = UnitDistanceSquared(unit)
    if distSq then
      local maxSq = DEFAULT_RETAIL_NEARBY_MAX_YARDS * DEFAULT_RETAIL_NEARBY_MAX_YARDS
      if distSq > maxSq then
        withinNearbyRange = false
      end
    end
  end



  
local guid = UnitGUID(unit)
local name = GetUnitNameSafe(unit)

-- Sometimes (especially right on PLAYER_TARGET_CHANGED) the client hasn't populated unit name yet.
-- Defer a few short retries so targeted enemy players land in Nearby immediately once data arrives.
if not guid or not name then
  if (unit == "target" or unit == "mouseover") and C_Timer and C_Timer.After then
    self._deferUnitChecks = self._deferUnitChecks or {}
    local now = (GetTime and GetTime()) or 0
    local d = self._deferUnitChecks[unit]
    if not d or (now - (d.t or 0)) > 1 then
      d = { n = 0, t = now }
    end
    if d.n < 10 then
      d.n = d.n + 1
      d.t = now
      self._deferUnitChecks[unit] = d
      C_Timer.After(0.05, function()
        if Detector and Detector.CheckUnit and UnitExists(unit) then
          Detector:CheckUnit(unit)
        end
      end)
    end
  end
  return
end

-- reset retry counter once we have data
if self._deferUnitChecks and self._deferUnitChecks[unit] then
  self._deferUnitChecks[unit] = nil
end


  local isPlayer = UnitIsPlayer(unit)
  local classFile = isPlayer and select(2, UnitClass(unit)) or nil
  local guild = isPlayer and GetUnitGuild(unit) or nil
-- Nearby list (hostile players)
if isPlayer and UnitCanAttack("player", unit) then
  if withinNearbyRange then
  -- classFile computed once above
	  -- Track enemy encounters (Spy-style): touch an active encounter, don't increment count here.
	  local Core = GetCore()
	  if Core and Core.TouchEncounter then
	    Core:TouchEncounter(guid, name, classFile, guild)
	  elseif DB.NoteEnemySeen then
	    -- Fallback: keep metadata fresh (still doesn't increment encounters)
	    DB:NoteEnemySeen(name, classFile, guild, guid)
	  end
  if guild and guild ~= "" and DB.UpdateLastAttackerGuild then
    DB:UpdateLastAttackerGuild(name, guild)
    local Core = GetCore()
    if Core and Core._ScheduleGUIRefresh then
      Core:_ScheduleGUIRefresh()
    end
  end
  local kosType = nil
  local pe = DB.LookupPlayer and DB:LookupPlayer(name)
  if pe then kosType = pe.type or L.KOS end
  if not kosType and guild and DB.LookupGuild then
    local ge = DB:LookupGuild(guild)
    if ge then kosType = ge.type or L.GUILD_KOS end
  end
  if KillOnSight_Nearby then
    KillOnSight_Nearby:Seen(name, classFile, guild, kosType, UnitLevel(unit))
  end
  end
end


  local playerEntry = DB:LookupPlayer(name)
  if playerEntry then
    if classFile and DB.SetPlayerClass then DB:SetPlayerClass(name, classFile) end
    local key = ("p:"..name:lower())
    if ShouldNotify(key) then
      DB:MarkSeenPlayer(name)
      Notifier:NotifyPlayer(playerEntry.type or L.KOS, name, playerEntry.reason)
    end
    return
  end
  if guid and guild and DB.UpdateLastAttackerGuildByGUID then
    -- If this player is in the Attackers list, enrich it with guild
    local updated = DB:UpdateLastAttackerGuildByGUID(guid, guild)
    if updated then
      local Core = GetCore()
      if Core and Core._ScheduleGUIRefresh then
        Core:_ScheduleGUIRefresh()
      end
    end
  end
  if guild then
    local guildEntry = DB:LookupGuild(guild)
    if guildEntry then
      local key = ("g:"..guild:lower()..":"..name:lower())
      if ShouldNotify(key) then
        DB:MarkSeenGuild(guild)
        Notifier:NotifyGuild(guildEntry.type or L.GUILD_KOS, name, guild, guildEntry.reason)
      end
      return
    end
  end
end

KillOnSight_Detector = Detector
