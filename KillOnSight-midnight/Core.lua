-- Core.lua
local ADDON_NAME = ...
local L = KillOnSight_L

local Core = CreateFrame("Frame")

-- Project detection (Retail vs Classic variants)
local IS_RETAIL = (WOW_PROJECT_ID and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) or false

-- Retail 12.x (Midnight): instances can return protected 'secret values' for unit data.
-- Rather than fighting the API in restricted contexts, we hard-disable Nearby/Detector processing
-- inside PvP instances and also inside PvE instances (party/raid/scenario) on Retail/Midnight.

local function IsInPvPInstance()
  if not IS_RETAIL then return false end
  if not IsInInstance then return false end
  local ok, inInstance, instType = pcall(IsInInstance)
  if not ok then return false end
  return (inInstance and (instType == "pvp" or instType == "arena")) and true or false
end

local function IsInPvEInstance()
  if not IS_RETAIL then return false end
  if not IsInInstance then return false end
  local ok, inInstance, instType = pcall(IsInInstance)
  if not ok or not inInstance then return false end

  -- Retail: Blizzard can return new/unknown instance types (e.g. Delves).
  -- We only want to keep KoS active in PvP/Arena; treat everything else as PvE suppression.
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
  -- isPvP: boolean (pvp/arena instances on Retail)
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
      -- Respect user's setting (showNearbyFrame). If enabled, show and refresh.
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
      DEFAULT_CHAT_FRAME:AddMessage('|cff00d0ff'..prefix..':|r Nearby is disabled in battlegrounds/arenas on Retail 12.x (Midnight).')
    end
  end
end


local band = (bit and bit.band) or (bit32 and bit32.band)

local function GetDB() return _G.KillOnSight_DB end
local function GetDetector() return _G.KillOnSight_Detector end
local function GetActivity() return _G.KillOnSight_Activity end
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

-- Compatibility wrappers: Encounter tracking lives in Midnight_Stats.lua
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
  if not IS_RETAIL then return true end
  if not GetCVarBool then return true end

  -- CVars vary slightly by client; check the common ones.
  if GetCVarBool("nameplateShowEnemies") == false then return false end
  if GetCVarBool("nameplateShowEnemyPlayers") == false then return false end

  return true
end

local function WarnIfEnemyNameplatesDisabled()
  if not IS_RETAIL then return end
  local enabled = EnemyNameplatesEnabled()

  -- Export a simple flag other modules can check.
  _G.KillOnSight_RetailNearbyLimited = (not enabled) or nil

  if enabled then return end

  -- Warn once per session. (Deliberately not saved to DB; users may toggle nameplates mid-session.)
  if _G.KillOnSight_NameplatesWarned then return end
  _G.KillOnSight_NameplatesWarned = true

  local prefix = (L and L.ADDON_PREFIX) or "KILLONSIGHT"
  local msg = (L and L.RETAIL_NEARBY_LIMITED_NAMEPLATES_OFF) or "Retail: Nearby is limited because enemy nameplates are disabled. Enable Enemy Nameplates in Interface > Names (press V)."
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
      -- Hello is useful, but keep it silent so we don't double-print SYNC_DISABLED.
      Sync:Hello(true)
      return Sync:RequestDiff()
    end
    return
  end

  Help()
end

local clSeenAt = {}      -- [nameLower] = GetTime()
local clNotifyAt = {}    -- [key] = GetTime()
local clCleanupAt = 0
local CL_CLEANUP_INTERVAL = 600  -- seconds
local CL_CACHE_TTL = 900         -- seconds (must be >= max notify cooldown)

-- PvP outcome tracking (Spy-style):
-- - If YOU damage an enemy and they die within 60s => +1 win for that enemy
-- - If an enemy damages YOU and you die within 60s => +1 loss for that enemy
-- These timers are kept in-memory only; the resulting counters are stored in SavedVariables (DB.statsPlayers).
local pvpOutgoing = {} -- [enemyGUID] = { t=GetTime(), nameLower="foo" }
local pvpIncoming = {} -- [enemyGUID] = { t=GetTime(), nameLower="foo" }
local PVP_WINDOW = 60

local function CleanupCLCaches(now)
  if (now - (clCleanupAt or 0)) < CL_CLEANUP_INTERVAL then return end
  clCleanupAt = now
  for k,t in pairs(clNotifyAt) do
    if (not t) or (now - t) > CL_CACHE_TTL then clNotifyAt[k] = nil end
  end
  for k,t in pairs(clSeenAt) do
    if (not t) or (now - t) > 10.0 then clSeenAt[k] = nil end
  end

  -- PvP timer cleanup (prevents unbounded growth in long sessions)
  for guid, e in pairs(pvpOutgoing) do
    if not e or not e.t or (now - e.t) > PVP_WINDOW then pvpOutgoing[guid] = nil end
  end
  for guid, e in pairs(pvpIncoming) do
    if not e or not e.t or (now - e.t) > PVP_WINDOW then pvpIncoming[guid] = nil end
  end
end


-- Guild resolve cache (prevents expensive ResolveGuildForGuid scans on every combat log tick)
local guildCache = {} -- [guid] = { guild = "name", t = GetTime(), lastTry = GetTime() }
local GUILD_CACHE_TTL = 60          -- seconds to keep a resolved guild
local GUILD_RESOLVE_TRY_COOLDOWN = 10 -- seconds between expensive resolve attempts per GUID

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

-- Debounced GUI refresh (used by deferred guild resolution)
local function _ScheduleGUIRefreshDeferred()
  _ScheduleGUIRefresh(0.2, "deferred")
end


local function IsFlagPlayer(flags)
  if not band then return false end
  return band(flags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0
end

local function IsFlagHostileSpy(flags)
  -- Spy-style: only treat units as hostile if the HOSTILE reaction bit is set.
  -- This avoids same-faction/friendly entries showing up from certain combat log flag combinations.
  if not band then return false end
  local f = flags or 0
  return COMBATLOG_OBJECT_REACTION_HOSTILE
     and band(f, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE
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
  -- Quick checks
  local g = GuildFromUnit('target') or GuildFromUnit('mouseover') or GuildFromUnit('focus')
  if g then return g end
  -- Nameplates (most reliable for enemies)
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
  -- Party/Raid (for same-faction situations)
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

-- Deferred guild resolution (Spy-style): guild data is often unavailable from combat log alone.
-- We retry periodically and enrich existing entries (Attackers/Stats) when guild becomes available.
local guildResolveTicker
local function ResolvePendingGuilds()
  local DB = _G.KillOnSight_DB
  if not DB or not DB.GetLastAttackers then return end
  local list = DB:GetLastAttackers()
  if not list or #list == 0 then return end
  local now = time()
  local changed = false

  -- Cap work per tick (prevents spikes in large BG fights)
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
          -- Keep stats metadata enriched too.
          -- IMPORTANT: only enrich existing stats records so "Reset Stats" stays a true wipe
          -- (deferred guild resolution should not resurrect old enemies back into stats).
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

local function IsFlagHostileOrNeutral(flags)
  if not band then return false end
  local f = flags or 0
  -- Prefer outsider affiliation when available (avoids listing party/raid/friendly units from combat log).
  if COMBATLOG_OBJECT_AFFILIATION_OUTSIDER then
    if band(f, COMBATLOG_OBJECT_AFFILIATION_OUTSIDER) == 0 then return false end
  end
  -- Exclude friendly reaction explicitly (some subevents can carry mixed flags).
  if COMBATLOG_OBJECT_REACTION_FRIENDLY and band(f, COMBATLOG_OBJECT_REACTION_FRIENDLY) ~= 0 then
    return false
  end
  return (COMBATLOG_OBJECT_REACTION_HOSTILE and band(f, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0)
      or (COMBATLOG_OBJECT_REACTION_NEUTRAL and band(f, COMBATLOG_OBJECT_REACTION_NEUTRAL) ~= 0)
end


local function IsGroupOrSelfByName(name)
  if not name or name == "" then return true end
  local clean = name:match("^[^-]+") or name
  local playerName = UnitName and UnitName("player")
  if playerName and clean == (playerName:match("^[^-]+") or playerName) then
    return true
  end
  -- Party (includes player at index 0 via "party1..4")
  if IsInGroup and IsInGroup() then
    if IsInRaid and IsInRaid() then
      local n = GetNumGroupMembers and GetNumGroupMembers() or 0
      for i=1,n do
        local rn = UnitName("raid"..i)
        if rn and (rn:match("^[^-]+") or rn) == clean then return true end
      end
    else
      for i=1,4 do
        local pn = UnitName("party"..i)
        if pn and (pn:match("^[^-]+") or pn) == clean then return true end
      end
    end
  end
  return false
end

local function ShouldCLSeen(nameLower, now)
  local last = clSeenAt[nameLower]
  if last and (now - last) < 1.0 then return false end
  clSeenAt[nameLower] = now
  return true
end

local function ShouldCLNotify(key, now, cooldown)
  local last = clNotifyAt[key]
  if last and (now - last) < cooldown then return false end
  clNotifyAt[key] = now
  return true
end

local STEALTH_SPELL_IDS = {
  [1784] = true,  -- Rogue: Stealth
  [5215] = true,  -- Druid: Prowl
  [1856] = true,  -- Rogue: Vanish (often logged as aura)
  [102547] = true, -- Druid: Prowl (some modern combat log variants)
  [11327] = true,  -- Rogue: Vanish (legacy/rank variant)
  [20580] = true, -- Night Elf: Shadowmeld
}

local STEALTH_SPELL_NAMES = {
  ["Stealth"] = true,
  ["Prowl"] = true,
  ["Vanish"] = true,
  ["Shadowmeld"] = true,
}

local function IsStealthAura(spellId, spellName)
  if spellId and STEALTH_SPELL_IDS[spellId] then return true end
  if spellName and STEALTH_SPELL_NAMES[spellName] then return true end
  return false
end

local function HandleCombatLog()
  local DB = _G.KillOnSight_DB
  local Notifier = GetNotifier and GetNotifier() or _G.KillOnSight_Notifier
  local Nearby = GetNearby()
  if not DB then return end
  if not CombatLogGetCurrentEventInfo then return end
  local function CleanName(n)
    if not n or n == "" then return nil end
    return (n:match("^[^-]+") or n)
  end

  local timestamp, subevent, hideCaster,
    srcGUID, srcName, srcFlags, srcRaidFlags,
    dstGUID, dstName, dstFlags, dstRaidFlags,
    spellId, spellName = CombatLogGetCurrentEventInfo()

  local now = (GetTime and GetTime()) or 0
  CleanupCLCaches(now)

	-- PvP outcome tracking (wins/losses + encounter resolution)
	local playerGUID = UnitGUID and UnitGUID("player")
	local isDamage = (subevent and subevent:find("_DAMAGE")) or subevent == "SWING_DAMAGE" or subevent == "RANGE_DAMAGE"
	if playerGUID and isDamage then
	  -- YOU -> enemy (outgoing)
	  if srcGUID == playerGUID and dstGUID and IsFlagPlayer(dstFlags) and IsFlagHostileSpy(dstFlags) then
	    local cn = CleanName(dstName)
	    if cn and not IsGroupOrSelfByName(cn) then
	      pvpOutgoing[dstGUID] = { t = now, nameLower = cn:lower(), name = cn }
	      Core:TouchEncounter(dstGUID, dstName or cn, nil, nil)
	    end
	  end
	  -- enemy -> YOU (incoming)
	  if dstGUID == playerGUID and srcGUID and IsFlagPlayer(srcFlags) and IsFlagHostileSpy(srcFlags) then
	    local cn = CleanName(srcName)
	    if cn and not IsGroupOrSelfByName(cn) then
	      pvpIncoming[srcGUID] = { t = now, nameLower = cn:lower(), name = cn }
	      Core:TouchEncounter(srcGUID, srcName or cn, nil, nil)
	    end
	  end
	end

	-- Death events credit wins/losses to recently involved enemies
	if playerGUID and subevent == "UNIT_DIED" then
	  -- You died -> every recent attacker gets a "loss" credit
	  if dstGUID == playerGUID then
	    for guid, e in pairs(pvpIncoming) do
	      if e and e.t and (now - e.t) <= PVP_WINDOW then
	        if DB and DB.StatsAddLoss then DB:StatsAddLoss(e.nameLower or (e.name and e.name:lower()) or "") end
	        Core:ResolveEncounter(guid)
	        pvpIncoming[guid] = nil
	        pvpOutgoing[guid] = nil
	      end
	    end
	  else
	    -- Enemy died -> if you hit them recently, you get a "win" credit
	    if dstGUID and IsFlagPlayer(dstFlags) and IsFlagHostileSpy(dstFlags) then
	      local e = pvpOutgoing[dstGUID]
	      if e and e.t and (now - e.t) <= PVP_WINDOW then
	        if DB and DB.StatsAddWin then DB:StatsAddWin(e.nameLower or (e.name and e.name:lower()) or "") end
	        Core:ResolveEncounter(dstGUID)
	      end
	      pvpOutgoing[dstGUID] = nil
	      pvpIncoming[dstGUID] = nil
	    end
	  end
	end

  -- Stealth detection (Spy-style): alert on ANY hostile player entering stealth/prowl/shadowmeld.
  -- Some clients log these as SPELL_CAST_SUCCESS (especially Vanish/Prowl), so include that too.
  if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" or subevent == "SPELL_CAST_SUCCESS" then
    -- spellId/spellName were captured from the initial CombatLogGetCurrentEventInfo() call
    if IsFlagPlayer(srcFlags) and IsFlagHostileSpy(srcFlags) and IsStealthAura(spellId, spellName) then
      local cleanName = srcName and (srcName:match("^[^-]+") or srcName)
      if cleanName and not IsGroupOrSelfByName(cleanName) then
        if srcGUID then
          Core:TouchEncounter(srcGUID, srcName or cleanName, nil, nil)
        end
        local key = cleanName:lower()
        if ShouldCLNotify("cl:stealth:" .. key, now, 8) then
          -- Add to Nearby as "Hidden"
          if Nearby and Nearby.Seen then
            local classFile
            if srcGUID and GetPlayerInfoByGUID then
              local _, cls = GetPlayerInfoByGUID(srcGUID)
              classFile = cls
            end
            Nearby:Seen(cleanName, classFile, nil, L.HIDDEN, nil)
          end

          if Notifier and Notifier.NotifyHidden then
            local prof = DB and DB:GetProfile()
      if prof and prof.stealthDetectEnabled ~= false then
        Notifier:NotifyHidden(cleanName, spellName, srcGUID)
      end
          end
        end
      end
    end
  end


  local function HandleName(name, flags, guid)
    if not name or name == "" then return end
    if not IsFlagPlayer(flags) then return end
    if not IsFlagHostileSpy(flags) then return end

    local cleanName = name:match("^[^-]+") or name
    local key = cleanName:lower()

    -- Never add yourself or party/raid members from combat log.
    if IsGroupOrSelfByName(cleanName) then return end

    -- Try to resolve class from GUID (Spy-style). This may be nil if unavailable.
    local classFile
    if guid and GetPlayerInfoByGUID then
      local _, cls = GetPlayerInfoByGUID(guid)
      classFile = cls
    end

    -- Feed Nearby list (even when we only know the name from combat log)
    if Nearby and Nearby.Seen and ShouldCLSeen(key, now) then
      local kosType = nil
      if DB.LookupPlayer then
        local pe = DB:LookupPlayer(cleanName)
        if pe then kosType = pe.type or L.KOS end
      end
      Nearby:Seen(cleanName, classFile, nil, kosType, nil)
    end

    -- If this hostile player is on KoS, alert (Spy-like behaviour)
    if Notifier and DB.LookupPlayer then
      local pe = DB:LookupPlayer(cleanName)
      if pe then
        local nk = "cl:p:" .. key
        if ShouldCLNotify(nk, now, 15) then
          DB:MarkSeenPlayer(cleanName)
          Notifier:NotifyPlayer(pe.type or L.KOS, cleanName, pe.reason)
        end
      end
    end
  end

  HandleName(srcName, srcFlags, srcGUID)
  HandleName(dstName, dstFlags, dstGUID)

  -- Keep the old "Last attackers" tracking, but ONLY when an enemy actually attacked YOU.
  -- (Not just seen/nearby; must be a hostile action targeted at the player.)
  -- playerGUID is already declared above; reuse it here (nil-guarded).
  if not playerGUID or dstGUID ~= playerGUID then return end
  if not srcName or srcName == "" then return end
  if not IsFlagPlayer(srcFlags) then return end
  if not IsFlagHostileSpy(srcFlags) then return end

  local isAttack = false
  if subevent == "SWING_DAMAGE" or subevent == "RANGE_DAMAGE" or (subevent and subevent:find("_DAMAGE")) then
    isAttack = true
  elseif subevent == "SWING_MISSED" or subevent == "RANGE_MISSED" or (subevent and subevent:find("_MISSED")) then
    -- Attacks that miss/dodge/parry/immune/etc still count as an attack on you.
    isAttack = true
  elseif subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" or subevent == "SPELL_AURA_APPLIED_DOSE" then
    -- Count hostile debuffs/CC on the player as an attack (e.g., Sap/Cheap Shot), even if no damage event fires.
    isAttack = true
  end

  if not isAttack then return end

  local guildName = ""
  if srcGUID then
    guildName = GetCachedGuild(srcGUID, now) or ""
    if guildName == "" and CanTryResolveGuild(srcGUID, now) then
      NoteResolveTry(srcGUID, now)
      local resolved = ResolveGuildForGuid(srcName, srcGUID)
      if resolved and resolved ~= "" then
        guildName = resolved
        SetCachedGuild(srcGUID, resolved, now)
      end
    end
  end
  DB:AddLastAttacker(srcName, srcGUID, (GetRealZoneText and GetRealZoneText()) or "", guildName)
end

Core:SetScript("OnEvent", function(self, event, ...)
  local Detector = GetDetector()
  local Sync = GetSync()
  local GUI = GetGUI()
  local Minimap = GetMinimap()
  local Activity = GetActivity()

  if event == "ADDON_LOADED" then
    local addon = ...
    if addon ~= ADDON_NAME then return end
    local DB = _G.KillOnSight_DB
    if DB then DB:Init() end
    -- Periodic stats pruning (optional; off by default)
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
    -- Encounter ticker is initialized by Midnight_Stats
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
	    if Detector and not Core._bgDisabled and not Core._instDisabled then Detector:CheckUnit("target") end
	    if GUI then GUI:RefreshAll() end
	    -- Print sync warning first (if any), then the Retail nameplate limitation warning.
	    if Sync then Sync:Hello(true) end
	    WarnIfEnemyNameplatesDisabled()
	    return
	  end

  if event == "PLAYER_TARGET_CHANGED" then
    -- Keep PvE suppression accurate even if instance type changes (e.g. Delves).
    if IsInPvEInstance() then
      if not Core._instDisabled then ApplyPvEInstanceDisableState(true) end
      return
    elseif Core._instDisabled then
      ApplyPvEInstanceDisableState(false)
    end
    if Core._bgDisabled then return end
    if Detector and not Core._bgDisabled and not Core._instDisabled then Detector:CheckUnit("target") end
    if GUI then GUI:RefreshAll() end
    return
  end

  if event == "UPDATE_MOUSEOVER_UNIT" then
    -- Keep PvE suppression accurate even if instance type changes (e.g. Delves).
    if IsInPvEInstance() then
      if not Core._instDisabled then ApplyPvEInstanceDisableState(true) end
      return
    elseif Core._instDisabled then
      ApplyPvEInstanceDisableState(false)
    end
    if Core._bgDisabled then return end
    if Detector and not Core._bgDisabled and not Core._instDisabled then Detector:CheckUnit("mouseover") end
    return
  end

  -- Retail-only: best-effort PvP outcome tracking without CLEU.
  -- Delegated to Midnight_Stats.lua so Core stays focused on event routing.
  if IS_RETAIL and (event == "PLAYER_PVP_KILLS_CHANGED" or event == "PLAYER_DEAD") then
    local Stats = GetMidnightStats()
    if Stats and Stats.OnEvent then
      Stats:OnEvent(event, ...)
    end
    return
  end

  if event == "NAME_PLATE_UNIT_ADDED" then
    -- Keep PvE suppression accurate even if instance type changes (e.g. Delves).
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
    -- Keep PvE suppression accurate even if instance type changes (e.g. Delves).
    if IsInPvEInstance() then
      if not Core._instDisabled then ApplyPvEInstanceDisableState(true) end
      return
    elseif Core._instDisabled then
      ApplyPvEInstanceDisableState(false)
    end
    if Core._bgDisabled then return end
    local unit = ...
    -- Nearby list is pruned by ticker; no hard remove needed here.
    -- Retail: use removal as an additional signal for stealth/vanish inference (no CLEU).
    if IS_RETAIL and Detector and Detector.OnNameplateRemoved and unit then
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

  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if IS_RETAIL then return end
    HandleCombatLog()
    if Activity and Activity.OnCombatLog then Activity:OnCombatLog() end
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
if IS_RETAIL then SafeRegisterEvent("PLAYER_PVP_KILLS_CHANGED") end
if IS_RETAIL then SafeRegisterEvent("PLAYER_DEAD") end
SafeRegisterEvent("NAME_PLATE_UNIT_ADDED")

SafeRegisterEvent("NAME_PLATE_UNIT_REMOVED")

-- Retail 12.x: avoid CLEU (can cause repeated forbidden/blocked actions).
-- Classic-era clients: keep CLEU for full attacker/combat attribution.
if not IS_RETAIL then
  SafeRegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

-- Unit-scoped alternatives (Retail-friendly)
SafeRegisterEvent("UNIT_AURA")
SafeRegisterEvent("UNIT_SPELLCAST_START")
SafeRegisterEvent("UNIT_SPELLCAST_STOP")
SafeRegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
SafeRegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
SafeRegisterEvent("UNIT_SPELLCAST_FAILED")
-- Retail: helps reduce laggy Nearby additions when a hostile player nameplate briefly resolves as not-attackable.
-- These unit events often fire shortly after NAME_PLATE_UNIT_ADDED.
SafeRegisterEvent("UNIT_FLAGS")
SafeRegisterEvent("UNIT_FACTION")

-- Export for other modules.
_G.KillOnSight_Core = Core

-- Locale sanity checker: warns about keys defined in locales but never read by the UI/code.
LocaleSanityCheck = function()
  if not KillOnSight_L_data or not KillOnSight_L_used then return end

  -- User can disable by setting KillOnSightDB.localeSanity = false
  if KillOnSightDB and KillOnSightDB.localeSanity == false then return end

  local unused = {}
  for k in pairs(KillOnSight_L_data) do
    -- ignore internal/proxy marker
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

-- Expose for other modules
_G.KillOnSight_Core = _G.KillOnSight_Core or Core
_G.KillOnSight_Core._ScheduleGUIRefresh = _ScheduleGUIRefresh