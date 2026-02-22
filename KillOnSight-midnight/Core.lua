-- Core.lua (Retail / Midnight only)
local ADDON_NAME = ...
local L = KillOnSight_L

local Core = CreateFrame("Frame")

-- Midnight: instances can return protected 'secret values' for unit data.
-- We hard-disable Nearby/Detector processing inside PvP and PvE instances.

local function IsInPvPInstance()
  if not IsInInstance then return false end
  local ok, inInstance, instType = pcall(IsInInstance)
  if not ok then return false end
  return (inInstance and (instType == "pvp" or instType == "arena")) and true or false
end

local function IsInPvEInstance()
  if not IsInInstance then return false end
  local ok, inInstance, instType = pcall(IsInInstance)
  if not ok or not inInstance then return false end

  -- Blizzard can return new/unknown instance types (e.g. Delves).
  -- We only want to keep KoS active in open world; treat everything else as PvE suppression.
  if instType == "pvp" or instType == "arena" then
    return false
  end
  return true
end

local function ApplyPvEInstanceDisableState(isPvE)
  Core._instDisabled = isPvE and true or false

  local Nearby = _G.KillOnSight_Nearby
  if Nearby then
    if Core._instDisabled then
      if Nearby.ClearAll then pcall(function() Nearby:ClearAll() end) end
      if Nearby.StopTicker then pcall(function() Nearby:StopTicker() end) end
    else
      if Nearby.StartTicker then pcall(function() Nearby:StartTicker() end) end
      if Nearby.Refresh then pcall(function() Nearby:Refresh() end) end
    end
  end

  local f = _G.KillOnSight_NearbyFrame
  if f and Core._instDisabled and f.Hide then
    pcall(function() f:Hide() end)
  end

  if _G.KillOnSight and KillOnSight.GUI and KillOnSight.GUI.RefreshAll then
    pcall(function() KillOnSight.GUI:RefreshAll() end)
  end
end

local function ApplyPvPInstanceDisableState(isPvP)
  Core._bgDisabled = isPvP and true or false

  local Nearby = _G.KillOnSight_Nearby
  if Nearby then
    if Core._bgDisabled then
      if Nearby.ClearAll then pcall(function() Nearby:ClearAll({ noRefresh = true }) end) end
      if Nearby.StopTicker then pcall(function() Nearby:StopTicker() end) end
    else
      if Nearby.StartTicker then pcall(function() Nearby:StartTicker() end) end
      if Nearby.Refresh then pcall(function() Nearby:Refresh() end) end
    end
  end

  local f = _G.KillOnSight_NearbyFrame
  if f then
    if Core._bgDisabled then
      pcall(function() f:Hide() end)
    else
      local DB = _G.KillOnSight_DB
      local prof = DB and DB.GetProfile and DB:GetProfile()
      local wantShown = not (prof and prof.showNearbyFrame == false)
      pcall(function()
        if wantShown then f:Show() else f:Hide() end
      end)
      if Nearby and Nearby.Refresh then pcall(function() Nearby:Refresh() end) end
    end
  end

  if Core._bgDisabled and not Core._bgDisableWarned then
    Core._bgDisableWarned = true
    local prefix = (KillOnSight_L and KillOnSight_L.ADDON_PREFIX) or 'KILLONSIGHT'
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage('|cff00d0ff'..prefix..':|r Nearby is disabled in battlegrounds/arenas.')
    end
  end
end


local function GetDB() return _G.KillOnSight_DB end
local function GetDetector() return _G.KillOnSight_Detector end
local function GetSync() return _G.KillOnSight_Sync end
local function GetGUI() return _G.KillOnSight_GUI end
local function GetMinimap() return _G.KillOnSight_Minimap end
local function GetNotifier() return _G.KillOnSight_Notifier end
local function GetNearby() return _G.KillOnSight_Nearby end
local function GetMidnightStats() return _G.KillOnSight_MidnightStats end

local LocaleSanityCheck -- forward

-- Debounced GUI refresh (safe to call from anywhere)
local _guiRefreshQueued = {}
local function _DoGUIRefresh()
  local gui = (KillOnSight and KillOnSight.GUI) or GetGUI()
  if gui and gui.RefreshAll then
    pcall(function() gui:RefreshAll() end)
  elseif KillOnSight and KillOnSight.RefreshGUI then
    pcall(KillOnSight.RefreshGUI)
  end
end

local function _ScheduleGUIRefresh(delay, key)
  local bucket = key or "default"
  if _guiRefreshQueued[bucket] then return end
  _guiRefreshQueued[bucket] = true
  local wait = tonumber(delay) or 0
  if C_Timer and C_Timer.After then
    C_Timer.After(wait, function()
      _guiRefreshQueued[bucket] = nil
      _DoGUIRefresh()
    end)
  else
    _guiRefreshQueued[bucket] = nil
    _DoGUIRefresh()
  end
end

-- Encounter tracking lives in Midnight_Stats.lua
function Core:TouchEncounter(guid, name, classFile, guild)
  local S = GetMidnightStats()
  if S and S.TouchEncounter then
    S:TouchEncounter(guid, name, classFile, guild)
  end
end

function Core:ResolveEncounter(guid)
  local S = GetMidnightStats()
  if S and S.ResolveEncounter then
    S:ResolveEncounter(guid)
  end
end

function Core:_ScheduleGUIRefresh()
  _ScheduleGUIRefresh(0, "immediate")
end



local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff00d0ff"..L.ADDON_PREFIX..":|r "..msg)
end

-- Nearby list population relies heavily on enemy nameplates (NAME_PLATE_* events / C_NamePlate).
-- If enemy nameplates are disabled, we can only see players when you target/mouseover them.
local function EnemyNameplatesEnabled()
  if not GetCVarBool then return true end
  if GetCVarBool("nameplateShowEnemies") == false then return false end
  if GetCVarBool("nameplateShowEnemyPlayers") == false then return false end
  return true
end

local function WarnIfEnemyNameplatesDisabled()
  local enabled = EnemyNameplatesEnabled()

  _G.KillOnSight_RetailNearbyLimited = (not enabled) or nil

  if enabled then return end

  -- Warn once per session.
  if _G.KillOnSight_NameplatesWarned then return end
  _G.KillOnSight_NameplatesWarned = true

  local prefix = (L and L.ADDON_PREFIX) or "KILLONSIGHT"
  local msg = (L and L.RETAIL_NEARBY_LIMITED_NAMEPLATES_OFF) or "Nearby is limited because enemy nameplates are disabled. Enable Enemy Nameplates in Interface > Names (press V)."
  DEFAULT_CHAT_FRAME:AddMessage("|cff00d0ff"..prefix..":|r "..msg)
end

local nearbyTicker

local function StartNearbyNameplateScan()
  if nearbyTicker then return end
  if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
  nearbyTicker = C_Timer.NewTicker(2.5, function()
    local Detector = GetDetector()
    if not Detector then return end
    local Nearby = GetNearby()
    if Nearby and Nearby.IsShown and (not Nearby:IsShown()) then return end
    local plates = C_NamePlate.GetNamePlates(false)
    if not plates then return end
    for _, plate in ipairs(plates) do
      local unit = plate and plate.namePlateUnitToken
      if unit then
        if not Core._bgDisabled and not Core._instDisabled then Detector:CheckUnit(unit) end
      end
    end
  end)
end

local function SplitFirst(s)
  if not s or s == "" then return nil, nil end
  local a, b = s:match("^(%S+)%s*(.-)%s*$")
  return a, b
end

local function Help()
  Print(L.CMD_HELP)
  Print("Pruning policy (Stats): /kos statsprune on|off|maxdays N|maxentries N|now")
  Print("Tip: /kos statsprune   (with no args) prints current status")
  Print("Import from Spy: /kos importspy")
end

local function EnsureName(rest)
  local name = SplitFirst(rest or "")
  if not name or name == "" then
    local unit = "target"
    if UnitExists(unit) and UnitIsPlayer(unit) then
      name = UnitName(unit)
    end
  end
  return name
end

local function AddPlayer(rest)
  local DB = _G.KillOnSight_DB
  local Notifier = GetNotifier()
  if not DB or not Notifier then return end

  local name = EnsureName(rest)
  if not name then return Help() end
  if DB:HasPlayer(name) then return end
  DB:AddPlayer(name, L.KOS, nil, UnitName("player"))
  Notifier:Chat(string.format(L.ADDED_PLAYER, L.KOS, name))
  local GUI = GetGUI()
  if GUI then GUI:RefreshAll() end
end

local function RemovePlayer(rest)
  local DB = _G.KillOnSight_DB
  local Notifier = GetNotifier()
  if not DB or not Notifier then return end

  local name = SplitFirst(rest or "")
  if not name then return Help() end
  if DB:RemovePlayer(name) then
    Notifier:Chat(string.format(L.REMOVED_PLAYER, name))
  else
    Notifier:Chat(string.format(L.NOT_FOUND, name))
  end
  local GUI = GetGUI()
  if GUI then GUI:RefreshAll() end
end

local function AddGuild(rest)
  local DB = _G.KillOnSight_DB
  local Notifier = GetNotifier()
  if not DB or not Notifier then return end

  local guild = SplitFirst(rest or "")
  if not guild then return Help() end
  if DB:HasGuild(guild) then return end
  DB:AddGuild(guild, L.GUILD_KOS, nil, UnitName("player"))
  Notifier:Chat(string.format(L.ADDED_GUILD, L.GUILD_KOS, guild))
  local GUI = GetGUI()
  if GUI then GUI:RefreshAll() end
end

local function RemoveGuild(rest)
  local DB = _G.KillOnSight_DB
  local Notifier = GetNotifier()
  if not DB or not Notifier then return end

  local guild = SplitFirst(rest or "")
  if not guild then return Help() end
  if DB:RemoveGuild(guild) then
    Notifier:Chat(string.format(L.REMOVED_GUILD, guild))
  else
    Notifier:Chat(string.format(L.NOT_FOUND, guild))
  end
  local GUI = GetGUI()
  if GUI then GUI:RefreshAll() end
end

local function List()
  local DB = _G.KillOnSight_DB
  if not DB then return end
  local d = DB:GetData()
  local function count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
  end
  Print(string.format(L.UI_LIST_PLAYERS, tostring(count(d.players))))
  Print(string.format(L.UI_LIST_GUILDS, tostring(count(d.guilds))))
  Print("Enemy stats: " .. tostring(count(d.statsPlayers)))
end

SLASH_KILLONSIGHT1 = "/kos"
SlashCmdList["KILLONSIGHT"] = function(msg)
  local cmd, rest = SplitFirst((msg or ""):lower())
  cmd = cmd or ""

  if cmd == "" or cmd == "show" then
    local GUI = GetGUI()
    if GUI then GUI:Toggle() end
    return
  end

  if cmd == "help" then return Help() end
  if cmd == "add" then return AddPlayer(rest) end
  if cmd == "remove" or cmd == "del" then return RemovePlayer(rest) end
  if cmd == "addguild" then return AddGuild(rest) end
  if cmd == "removeguild" then return RemoveGuild(rest) end
  if cmd == "list" then return List() end
  if cmd == "stats" then return List() end
  if cmd == "importspy" then
    local imp = _G.KillOnSight_SpyImport
    if imp and imp.Run then
      imp:Run()
    else
      Print("Spy import is unavailable (module not loaded).")
    end
    return
  end
  if cmd == 'localesanity' then
    LocaleSanityCheck()
    return
  end
  if cmd == 'statsprune' then
    local DB = _G.KillOnSight_DB
    if not DB then return end
    local prof = DB.GetProfile and DB:GetProfile() or {}
    local sub, arg = SplitFirst((rest or ""):lower())
    sub = sub or ""

    if sub == "" then
      Print((prof.statsPruneEnabled and "Stats prune: ON" or "Stats prune: OFF") ..
        " |cffbbbbbb(maxDays=" .. tostring(prof.statsPruneMaxDays or "-") ..
        ", maxEntries=" .. tostring(prof.statsPruneMaxEntries or "-") .. ")|r")
      return
    end
    if sub == "on" then prof.statsPruneEnabled = true; Print("Stats prune enabled."); return end
    if sub == "off" then prof.statsPruneEnabled = false; Print("Stats prune disabled."); return end
    if sub == "maxdays" and tonumber(arg) then prof.statsPruneMaxDays = tonumber(arg); Print("Stats prune maxDays set to "..arg); return end
    if (sub == "max" or sub == "maxentries") and tonumber(arg) then prof.statsPruneMaxEntries = tonumber(arg); Print("Stats prune maxEntries set to "..arg); return end
    if sub == "now" then
      local removed = DB.PruneStatsPlayers and DB:PruneStatsPlayers() or 0
      Print("Stats prune removed " .. tostring(removed) .. " entries.")
      return
    end
    Print("Usage: /kos statsprune on|off|maxdays N|maxentries N|now")
    return
  end
  if cmd == "sync" then
    local Sync = GetSync()
    if Sync then
      Sync:Hello(true)
      return Sync:RequestDiff()
    end
    return
  end

  Help()
end


-- Guild resolve cache (prevents expensive ResolveGuildForGuid scans on every tick)
local guildCache = {} -- [guid] = { guild = "name", t = GetTime(), lastTry = GetTime() }
local GUILD_CACHE_TTL = 60
local GUILD_RESOLVE_TRY_COOLDOWN = 10

local function GetCachedGuild(guid, now)
  local e = guid and guildCache[guid]
  if not e then return nil end
  if (now - (e.t or 0)) > GUILD_CACHE_TTL then
    guildCache[guid] = nil
    return nil
  end
  return e.guild
end

local function NoteResolveTry(guid, now)
  if not guid then return end
  local e = guildCache[guid] or {}
  e.lastTry = now
  guildCache[guid] = e
end

local function CanTryResolveGuild(guid, now)
  if not guid then return false end
  local e = guildCache[guid]
  if not e or not e.lastTry then return true end
  return (now - e.lastTry) >= GUILD_RESOLVE_TRY_COOLDOWN
end

local function SetCachedGuild(guid, guild, now)
  if not guid or not guild or guild == "" then return end
  guildCache[guid] = { guild = guild, t = now }
end

local function _ScheduleGUIRefreshDeferred()
  _ScheduleGUIRefresh(0.2, "deferred")
end


local function ResolveGuildForGuid(name, guid)
  local function Clean(n)
    if not n then return nil end
    return (n:match('^[^-]+') or n)
  end
  local cleanName = Clean(name)
  local function GuildFromUnit(unit)
    if not unit or not UnitExists or not UnitExists(unit) then return nil end
    if guid and UnitGUID and UnitGUID(unit) ~= guid then return nil end
    if (not guid) and cleanName and UnitName then
      local un = UnitName(unit)
      if not un or Clean(un) ~= cleanName then return nil end
    end
    local g = GetGuildInfo and GetGuildInfo(unit)
    if g and g ~= '' then return g end
    return nil
  end
  local g = GuildFromUnit('target') or GuildFromUnit('mouseover') or GuildFromUnit('focus')
  if g then return g end
  if C_NamePlate and C_NamePlate.GetNamePlates then
    local plates = C_NamePlate.GetNamePlates()
    if plates then
      for i=1,#plates do
        local unit = plates[i] and plates[i].namePlateUnitToken
        g = GuildFromUnit(unit)
        if g then return g end
      end
    end
  end
  if IsInGroup and IsInGroup() then
    if IsInRaid and IsInRaid() then
      local n = GetNumGroupMembers and GetNumGroupMembers() or 0
      for i=1,n do
        g = GuildFromUnit('raid'..i)
        if g then return g end
      end
    else
      for i=1,4 do
        g = GuildFromUnit('party'..i)
        if g then return g end
      end
    end
  end
  return nil
end

-- Deferred guild resolution: guild data is often unavailable immediately.
-- We retry periodically and enrich existing entries when guild becomes available.
local guildResolveTicker
local function ResolvePendingGuilds()
  local DB = _G.KillOnSight_DB
  if not DB or not DB.GetLastAttackers then return end
  local list = DB:GetLastAttackers()
  if not list or #list == 0 then return end
  local now = time()
  local changed = false

  local checked = 0
  for i = 1, #list do
    local e = list[i]
    if e and (not e.guild or e.guild == "") and e.guid and e.guid ~= "" then
      if CanTryResolveGuild(e.guid, now) then
        NoteResolveTry(e.guid, now)
        local resolved = ResolveGuildForGuid(e.name, e.guid)
        if resolved and resolved ~= "" then
          e.guild = resolved
          SetCachedGuild(e.guid, resolved, now)
          -- Only enrich existing stats records so "Reset Stats" stays a true wipe.
          if DB.NoteEnemySeen and DB.HasStatsPlayer and DB:HasStatsPlayer(e.name) then
            DB:NoteEnemySeen(e.name, e.class, resolved, e.guid)
          end
          changed = true
        end
      end
      checked = checked + 1
      if checked >= 20 then break end
    end
  end

  if changed then
    _ScheduleGUIRefreshDeferred()
  end
end

local function StartDeferredGuildResolveTicker()
  if guildResolveTicker then return end
  if not C_Timer or not C_Timer.NewTicker then return end
  guildResolveTicker = C_Timer.NewTicker(1.0, ResolvePendingGuilds)
end


Core:SetScript("OnEvent", function(self, event, ...)
  local Detector = GetDetector()
  local Sync = GetSync()
  local GUI = GetGUI()
  local Minimap = GetMinimap()

  if event == "ADDON_LOADED" then
    local addon = ...
    if addon ~= ADDON_NAME then return end
    local DB = _G.KillOnSight_DB
    if DB then DB:Init() end
    -- Periodic stats pruning
    if DB and DB.PruneStatsPlayers and C_Timer and C_Timer.NewTicker then
      if not Core._statsPruneTicker then
        Core._statsPruneTicker = C_Timer.NewTicker(1800, function()
          local db = GetDB()
          if db and db.PruneStatsPlayers then db:PruneStatsPlayers() end
        end)
      end
    end
    if Sync then Sync:Init() end
    if Minimap and Minimap.Create then Minimap:Create() end
    local Nearby = GetNearby()
    if Nearby and Nearby.Init then Nearby:Init() end
    StartNearbyNameplateScan()
    if GetMidnightStats() and GetMidnightStats().Init then GetMidnightStats():Init() end
    StartDeferredGuildResolveTicker()
    Print(L.MSG_LOADED)
    if C_Timer and C_Timer.After and KillOnSightDB and KillOnSightDB.localeSanity == true then
      C_Timer.After(10, LocaleSanityCheck)
    end
    return
  end

  if event == "CHAT_MSG_ADDON" then
    if Sync then Sync:OnMessage(...) end
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    ApplyPvPInstanceDisableState(IsInPvPInstance())
    ApplyPvEInstanceDisableState(IsInPvEInstance())
    if Core._bgDisabled then return end
    if Detector and not Core._instDisabled then Detector:CheckUnit("target") end
    if GUI then GUI:RefreshAll() end
    if Sync then Sync:Hello(true) end
    WarnIfEnemyNameplatesDisabled()
    return
  end

  if event == "PLAYER_TARGET_CHANGED" then
    if IsInPvEInstance() then
      if not Core._instDisabled then ApplyPvEInstanceDisableState(true) end
      return
    elseif Core._instDisabled then
      ApplyPvEInstanceDisableState(false)
    end
    if Core._bgDisabled then return end
    if Detector and not Core._instDisabled then Detector:CheckUnit("target") end
    if GUI then GUI:RefreshAll() end
    return
  end

  if event == "UPDATE_MOUSEOVER_UNIT" then
    if IsInPvEInstance() then
      if not Core._instDisabled then ApplyPvEInstanceDisableState(true) end
      return
    elseif Core._instDisabled then
      ApplyPvEInstanceDisableState(false)
    end
    if Core._bgDisabled then return end
    if Detector and not Core._instDisabled then Detector:CheckUnit("mouseover") end
    return
  end

  -- Best-effort PvP outcome tracking. Delegated to Midnight_Stats.lua.
  if event == "PLAYER_PVP_KILLS_CHANGED" or event == "PLAYER_DEAD" then
    local Stats = GetMidnightStats()
    if Stats and Stats.OnEvent then
      Stats:OnEvent(event, ...)
    end
    return
  end

  if event == "NAME_PLATE_UNIT_ADDED" then
    if IsInPvEInstance() then
      if not Core._instDisabled then ApplyPvEInstanceDisableState(true) end
      return
    elseif Core._instDisabled then
      ApplyPvEInstanceDisableState(false)
    end
    if Core._bgDisabled then return end
    local unit = ...
    if Detector and not Core._instDisabled then Detector:CheckUnit(unit) end
    return
  end

  if event == "NAME_PLATE_UNIT_REMOVED" then
    if IsInPvEInstance() then
      if not Core._instDisabled then ApplyPvEInstanceDisableState(true) end
      return
    elseif Core._instDisabled then
      ApplyPvEInstanceDisableState(false)
    end
    if Core._bgDisabled then return end
    local unit = ...
    if Detector and Detector.OnNameplateRemoved and unit then
      Detector:OnNameplateRemoved(unit)
    end
    return
  end

  if event == "UNIT_AURA" or event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_FLAGS" or event == "UNIT_FACTION" then
    if Core._bgDisabled then return end
    local unit = ...
    if unit and (unit == "target" or unit == "mouseover" or unit:match('^nameplate')) then
      if Detector and not Core._instDisabled then Detector:CheckUnit(unit) end
    end
    return
  end
end)

local function SafeRegisterEvent(event)
  if not Core or not Core.RegisterEvent then return end
  pcall(Core.RegisterEvent, Core, event)
end

SafeRegisterEvent("ADDON_LOADED")
SafeRegisterEvent("CHAT_MSG_ADDON")
SafeRegisterEvent("PLAYER_ENTERING_WORLD")
SafeRegisterEvent("PLAYER_TARGET_CHANGED")
SafeRegisterEvent("UPDATE_MOUSEOVER_UNIT")
SafeRegisterEvent("PLAYER_PVP_KILLS_CHANGED")
SafeRegisterEvent("PLAYER_DEAD")
SafeRegisterEvent("NAME_PLATE_UNIT_ADDED")
SafeRegisterEvent("NAME_PLATE_UNIT_REMOVED")

-- Unit-scoped events
SafeRegisterEvent("UNIT_AURA")
SafeRegisterEvent("UNIT_SPELLCAST_START")
SafeRegisterEvent("UNIT_SPELLCAST_STOP")
SafeRegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
SafeRegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
SafeRegisterEvent("UNIT_SPELLCAST_FAILED")
SafeRegisterEvent("UNIT_FLAGS")
SafeRegisterEvent("UNIT_FACTION")

-- Export for other modules.
_G.KillOnSight_Core = Core

-- Locale sanity checker
LocaleSanityCheck = function()
  if not KillOnSight_L_data or not KillOnSight_L_used then return end
  if KillOnSightDB and KillOnSightDB.localeSanity == false then return end

  local unused = {}
  for k in pairs(KillOnSight_L_data) do
    if k ~= '__kos_proxy' and not KillOnSight_L_used[k] then
      unused[#unused+1] = k
    end
  end

  if #unused > 0 then
    table.sort(unused)
    local prefix = (KillOnSight_L and KillOnSight_L.ADDON_PREFIX) or 'KILLONSIGHT'
    DEFAULT_CHAT_FRAME:AddMessage('|cff00d0ff'..prefix..':|r Locale sanity: '..#unused..' key(s) defined but unused. Set KillOnSightDB.localeSanity=false to silence.')
    DEFAULT_CHAT_FRAME:AddMessage('|cff00d0ff'..prefix..':|r '..table.concat(unused, ', '))
  end
end

_G.KillOnSight_Core = _G.KillOnSight_Core or Core
_G.KillOnSight_Core._ScheduleGUIRefresh = _ScheduleGUIRefresh
