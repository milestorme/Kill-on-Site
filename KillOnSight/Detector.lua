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

-- Classic expansions (TBC 2.5.5+ through MoP 5.5.3): nameplate discovery range is noticeably
-- longer than Classic Era, so we optionally clamp "Nearby" population to a more
-- Classic-feel distance.
local _toc = select(4, GetBuildInfo())
local IS_CLASSIC_CLAMP_CLIENT = (type(_toc) == "number") and (_toc >= 20505) and (_toc <= 50503)
local CLASSIC_CLAMP_MAX_YARDS = 28 -- roughly CheckInteractDistance(unit, 4)

local function IsWithinClassicClampRange(unit)
  if not unit then return true end

  -- Prefer a true yard distance if available.
  if UnitDistanceSquared then
    local d2 = UnitDistanceSquared(unit)
    if d2 then
      return d2 <= (CLASSIC_CLAMP_MAX_YARDS * CLASSIC_CLAMP_MAX_YARDS)
    end
  end

  -- Fallback: interaction distance (index 4 ~ 28 yards). Returns true/false/nil.
  if CheckInteractDistance then
    local ok = CheckInteractDistance(unit, 4)
    if ok ~= nil then return ok end
  end

  -- If the client can't answer, don't block detection.
  return true
end


function Detector:CheckUnit(unit)
  local DB = GetDB()
  local Notifier = GetNotifier()
  if not DB or not Notifier then return end
  if not unit or not UnitExists(unit) then return end
  if not InAllowedContext() then return end
  if UnitIsUnit(unit, "player") then return end

  local prof = DB:GetProfile()

  -- Gate Nearby list updates by distance (Classic expansion clamp, optional).
  local withinNearbyRange = true
  if IS_CLASSIC_CLAMP_CLIENT and (prof.nearbyRangeClampEnabled ~= false) then
    withinNearbyRange = IsWithinClassicClampRange(unit)
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

  -- Reset retry counter once we have data.
  if self._deferUnitChecks and self._deferUnitChecks[unit] then
    self._deferUnitChecks[unit] = nil
  end

  local isPlayer = UnitIsPlayer(unit)
  local classFile = isPlayer and select(2, UnitClass(unit)) or nil
  local guild = isPlayer and GetUnitGuild(unit) or nil

  -- Nearby list (hostile players)
  if isPlayer and UnitCanAttack("player", unit) then
    if withinNearbyRange then
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
    -- If this player is in the Attackers list, enrich it with guild.
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
