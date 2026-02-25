-- Notice for enemy nameplates (shown every login/reload if disabled)
local function CheckEnemyNameplatesNotice()
  -- Some clients split enemy nameplate CVars; treat enemy nameplates as enabled if ANY relevant toggle is on.
  local function cvarOn(name)
    local v = GetCVar and GetCVar(name)
    return v == "1"
  end

  local enemyOn = cvarOn("nameplateShowEnemies") or cvarOn("nameplateShowEnemyNPCs") or cvarOn("nameplateShowEnemyMinions")
  if enemyOn then return end

  local Loc = KillOnSight_L
  local msg = (Loc and Loc.ENEMY_NAMEPLATES_REQUIRED) or "Nearby passive detection requires Enemy Nameplates enabled."

  local function _print()
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000KillOnSight:|r " .. msg)
    end
  end

  -- Delay so it shows after other startup messages
  if C_Timer and C_Timer.After then
    C_Timer.After(5, _print)
  else
    _print()
  end
end


-- Core.lua
local ADDON_NAME = ...
local L = KillOnSight_L

local Core = CreateFrame("Frame")



-- Fallback: fire the notice once on first PLAYER_ENTERING_WORLD in case the ADDON_LOADED path changes.
local KOS_NameplateNoticePEW
local band = (bit and bit.band) or (bit32 and bit32.band)

local function GetDB()       return _G.KillOnSight_DB       end
local function GetDetector() return _G.KillOnSight_Detector end
local function GetActivity() return _G.KillOnSight_Activity end
local function GetSync()     return _G.KillOnSight_Sync     end
local function GetGUI()      return _G.KillOnSight_GUI      end
local function GetMinimap()  return _G.KillOnSight_Minimap  end
local function GetNotifier() return _G.KillOnSight_Notifier end
local function GetNearby()   return _G.KillOnSight_Nearby   end

local LocaleSanityCheck   -- forward (assigned at bottom)
local IsGroupOrSelfByName -- forward (used in TouchEncounter before its definition)

-- -------------------------------------------------------
-- Encounter tracking (Spy-style)
--
-- We treat Stats "seenCount" as *encounters*, not raw detection spam.
-- An encounter starts when we detect a hostile player (nameplate/target/mouseover/combatlog)
-- and resolves on win/loss or a timeout (flee/disengage).
-- -------------------------------------------------------

local ENCOUNTER_TIMEOUT = 60 -- seconds since last touch to count as one encounter
local encounterTicker
local activeEncounters = {} -- [guid] = { nameLower, name, lastTouchAt }

local function CleanName(n)
  if not n or n == "" then return nil end
  return (n:match("^[^-]+") or n)
end

local function TouchEncounter(guid, name, classFile, guild)
  if not guid or guid == "" then return end
  local DB = GetDB()
  if not DB then return end
  local cn = CleanName(name)
  if not cn then return end
  if IsGroupOrSelfByName(cn) then return end

  local now = time()
  local key = cn:lower()

  -- Ensure stats record exists and keep metadata fresh, but do NOT increment seenCount here.
  if DB.NoteEnemySeen then
    DB:NoteEnemySeen(cn, classFile, guild, guid)
  end

  local e = activeEncounters[guid]
  if not e then
    activeEncounters[guid] = { nameLower = key, name = cn, lastTouchAt = now }
  else
    e.lastTouchAt = now
    e.nameLower = e.nameLower or key
    e.name = e.name or cn
  end
end

-- Debounced GUI refresh (safe to call from anywhere).
-- Single implementation: 0.2s delay, guards against concurrent calls.
local _pendingGUIRefresh = false
local function _ScheduleGUIRefresh()
  if _pendingGUIRefresh then return end
  _pendingGUIRefresh = true
  C_Timer.After(0.2, function()
    _pendingGUIRefresh = false
    local GUI = GetGUI()
    if GUI and GUI.RefreshAll then
      GUI:RefreshAll()
    end
  end)
end

local function ResolveEncounter(guid)
  local DB = GetDB()
  if not DB then return end
  local e = guid and activeEncounters[guid]
  if not e then return end

  -- Count exactly one encounter.
  if DB.StatsAddSeenEncounter then
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

-- Expose a safe method for other modules (Detector) to touch encounters.
function Core:TouchEncounter(guid, name, classFile, guild)
  TouchEncounter(guid, name, classFile, guild)
end

-- Expose a safe, debounced GUI refresh hook for other modules.
function Core:_ScheduleGUIRefresh()
  _ScheduleGUIRefresh()
end

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff00d0ff"..L.ADDON_PREFIX..":|r "..msg)
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
        Detector:CheckUnit(unit)
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
  local DB = GetDB()
  local Notifier = GetNotifier()
  if not DB or not Notifier then return end

  local name = EnsureName(rest)
  if not name then return Help() end
  if DB:HasPlayer(name) then return end
  DB:AddPlayer(name, L.KOS, nil, UnitName("player"))
  Notifier:Chat(string.format(L.ADDED_PLAYER, L.KOS, name))
  local GUI = GetGUI()
  if GUI then GUI:RefreshAll() end
  local Nearby = GetNearby()
  if Nearby and Nearby.Refresh then Nearby:Refresh() end
end

local function RemovePlayer(rest)
  local DB = GetDB()
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
  local Nearby = GetNearby()
  if Nearby and Nearby.Refresh then Nearby:Refresh() end
end

local function AddGuild(rest)
  local DB = GetDB()
  local Notifier = GetNotifier()
  if not DB or not Notifier then return end

  local guild = (rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if guild == "" then return Help() end
  if DB:HasGuild(guild) then return end
  DB:AddGuild(guild, L.GUILD_KOS, nil, UnitName("player"))
  Notifier:Chat(string.format(L.ADDED_GUILD, L.GUILD_KOS, guild))
  local GUI = GetGUI()
  if GUI then GUI:RefreshAll() end
  local Nearby = GetNearby()
  if Nearby and Nearby.Refresh then Nearby:Refresh() end
end

local function RemoveGuild(rest)
  local DB = GetDB()
  local Notifier = GetNotifier()
  if not DB or not Notifier then return end

  local guild = (rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if guild == "" then return Help() end
  if DB:RemoveGuild(guild) then
    Notifier:Chat(string.format(L.REMOVED_GUILD, guild))
  else
    Notifier:Chat(string.format(L.NOT_FOUND, guild))
  end
  local GUI = GetGUI()
  if GUI then GUI:RefreshAll() end
  local Nearby = GetNearby()
  if Nearby and Nearby.Refresh then Nearby:Refresh() end
end

local function List()
  local DB = GetDB()
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
  local cmd, rest = SplitFirst(msg or "")
  cmd = (cmd or ""):lower()

  if cmd == "" or cmd == "show" then
    local GUI = GetGUI()
    if GUI then GUI:Toggle() end
    return
  end

  if cmd == "help"                    then return Help()            end
  if cmd == "add"                     then return AddPlayer(rest)   end
  if cmd == "remove" or cmd == "del"  then return RemovePlayer(rest) end
  if cmd == "addguild"                then return AddGuild(rest)    end
  if cmd == "removeguild"             then return RemoveGuild(rest) end
  if cmd == "list" or cmd == "stats"  then return List()            end

  if cmd == "importspy" then
    local imp = _G.KillOnSight_SpyImport
    if imp and imp.Run then
      imp:Run()
    else
      Print("Spy import is unavailable (module not loaded).")
    end
    return
  end

  if cmd == "localesanity" then
    LocaleSanityCheck()
    return
  end

  if cmd == "statsprune" then
    local DB = GetDB()
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
    if sub == "on"         then prof.statsPruneEnabled  = true;              Print("Stats prune enabled.");                         return end
    if sub == "off"        then prof.statsPruneEnabled  = false;             Print("Stats prune disabled.");                        return end
    if sub == "maxdays"    and tonumber(arg) then prof.statsPruneMaxDays    = tonumber(arg); Print("Stats prune maxDays set to "    ..arg); return end
    if sub == "maxentries" and tonumber(arg) then prof.statsPruneMaxEntries = tonumber(arg); Print("Stats prune maxEntries set to " ..arg); return end
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
      Sync:Hello()
      return Sync:RequestDiff()
    end
    return
  end

  Help()
end

local clSeenAt    = {}  -- [nameLower] = GetTime()
local clNotifyAt  = {}  -- [key] = GetTime()
local clCleanupAt = 0
local CL_CLEANUP_INTERVAL = 600  -- seconds
local CL_CACHE_TTL         = 900  -- seconds (must be >= max notify cooldown)

-- PvP outcome tracking (Spy-style):
-- - If YOU damage an enemy and they die within 60s => +1 win for that enemy
-- - If an enemy damages YOU and you die within 60s => +1 loss for that enemy
-- These timers are in-memory only; resulting counters are stored in SavedVariables.
local pvpOutgoing = {} -- [enemyGUID] = { t=GetTime(), nameLower="foo", name="Foo" }
local pvpIncoming = {} -- [enemyGUID] = { t=GetTime(), nameLower="foo", name="Foo" }
local PVP_WINDOW  = 60

local function CleanupCLCaches(now)
  if (now - (clCleanupAt or 0)) < CL_CLEANUP_INTERVAL then return end
  clCleanupAt = now
  for k, t in pairs(clNotifyAt) do
    if (not t) or (now - t) > CL_CACHE_TTL then clNotifyAt[k] = nil end
  end
  for k, t in pairs(clSeenAt) do
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

-- Guild resolve cache (prevents expensive ResolveGuildForGuid scans on every CLEU tick)
local guildCache = {}  -- [guid] = { guild="name", t=time(), lastTry=time() }
local GUILD_CACHE_TTL            = 60  -- seconds to keep a resolved guild
local GUILD_RESOLVE_TRY_COOLDOWN = 10  -- seconds between expensive resolve attempts per GUID

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

local function IsFlagPlayer(flags)
  if not band then return false end
  return band(flags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0
end

local function IsFlagHostileSpy(flags)
  -- Only treat units as hostile if the HOSTILE reaction bit is set.
  -- Avoids same-faction/friendly entries from certain combat log flag combinations.
  if not band or not COMBATLOG_OBJECT_REACTION_HOSTILE then return false end
  local f = flags or 0
  return band(f, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE
end

-- Reuses module-level CleanName; avoids a duplicate inner Clean() function.
local function ResolveGuildForGuid(name, guid)
  local cleanName = CleanName(name)
  local function GuildFromUnit(unit)
    if not unit or not UnitExists or not UnitExists(unit) then return nil end
    if guid and UnitGUID and UnitGUID(unit) ~= guid then return nil end
    if (not guid) and cleanName and UnitName then
      local un = UnitName(unit)
      if not un or CleanName(un) ~= cleanName then return nil end
    end
    local g = GetGuildInfo and GetGuildInfo(unit)
    if g and g ~= "" then return g end
    return nil
  end
  -- Quick checks
  local g = GuildFromUnit("target") or GuildFromUnit("mouseover") or GuildFromUnit("focus")
  if g then return g end
  -- Nameplates (most reliable for enemies)
  if C_NamePlate and C_NamePlate.GetNamePlates then
    local plates = C_NamePlate.GetNamePlates()
    if plates then
      for i = 1, #plates do
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
      for i = 1, n do
        g = GuildFromUnit("raid"..i)
        if g then return g end
      end
    else
      for i = 1, 4 do
        g = GuildFromUnit("party"..i)
        if g then return g end
      end
    end
  end
  return nil
end

-- Deferred guild resolution: guild data is often unavailable from combat log alone.
-- Retries periodically and enriches Attackers/Stats entries when guild becomes available.
local guildResolveTicker
local function ResolvePendingGuilds()
  local DB = GetDB()
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
          if DB.NoteEnemySeen then
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
    _ScheduleGUIRefresh()
  end
end

local function StartDeferredGuildResolveTicker()
  if guildResolveTicker then return end
  if not C_Timer or not C_Timer.NewTicker then return end
  guildResolveTicker = C_Timer.NewTicker(1.0, ResolvePendingGuilds)
end

-- Forward declaration resolved here.
IsGroupOrSelfByName = function(name)
  if not name or name == "" then return true end
  local clean = name:match("^[^-]+") or name
  local playerName = UnitName and UnitName("player")
  if playerName and clean == (playerName:match("^[^-]+") or playerName) then
    return true
  end
  -- Party/Raid members
  if IsInGroup and IsInGroup() then
    if IsInRaid and IsInRaid() then
      local n = GetNumGroupMembers and GetNumGroupMembers() or 0
      for i = 1, n do
        local rn = UnitName("raid"..i)
        if rn and (rn:match("^[^-]+") or rn) == clean then return true end
      end
    else
      for i = 1, 4 do
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
  [1784]   = true, -- Rogue: Stealth
  [5215]   = true, -- Druid: Prowl
  [1856]   = true, -- Rogue: Vanish (often logged as aura)
  [102547] = true, -- Druid: Prowl (some combat log variants)
  [11327]  = true, -- Rogue: Vanish (legacy/rank variant)
  [20580]  = true, -- Night Elf: Shadowmeld
}

local STEALTH_SPELL_NAMES = {
  ["Stealth"]    = true,
  ["Prowl"]      = true,
  ["Vanish"]     = true,
  ["Shadowmeld"] = true,
}

local function IsStealthAura(spellId, spellName)
  if spellId   and STEALTH_SPELL_IDS[spellId]     then return true end
  if spellName and STEALTH_SPELL_NAMES[spellName] then return true end
  return false
end

-- HandleCLName: processes a single source/dest entry from a CLEU event.
-- Defined at module level (not inside HandleCombatLog) to avoid a new closure allocation
-- on every COMBAT_LOG_EVENT_UNFILTERED fire.
local function HandleCLName(name, flags, guid, now, DB, Notifier, Nearby)
  if not name or name == "" then return end
  if not IsFlagPlayer(flags) then return end
  if not IsFlagHostileSpy(flags) then return end

  local cleanName = CleanName(name)
  if not cleanName then return end
  local key = cleanName:lower()

  -- Never add yourself or party/raid members from combat log.
  if IsGroupOrSelfByName(cleanName) then return end

  -- Try to resolve class from GUID. May be nil on some clients.
  local classFile
  if guid and GetPlayerInfoByGUID then
    local _, cls = GetPlayerInfoByGUID(guid)
    classFile = cls
  end

  -- Feed Nearby list (even when we only know the name from combat log)
  if Nearby and Nearby.Seen and ShouldCLSeen(key, now) then
    local cachedGuild = guid and GetCachedGuild(guid, now) or nil
    local kosType = nil
    if DB.LookupPlayer then
      local pe = DB:LookupPlayer(cleanName)
      if pe then kosType = pe.type or L.KOS end
    end
    Nearby:Seen(cleanName, classFile, cachedGuild, kosType, nil)
  end

  -- If this hostile player is on KoS, alert
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

local function HandleCombatLog()
  local DB       = GetDB()
  local Notifier = GetNotifier()
  local Nearby   = GetNearby()
  if not DB then return end
  if not CombatLogGetCurrentEventInfo then return end

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
        TouchEncounter(dstGUID, cn, nil, nil)
      end
    end
    -- enemy -> YOU (incoming)
    if dstGUID == playerGUID and srcGUID and IsFlagPlayer(srcFlags) and IsFlagHostileSpy(srcFlags) then
      local cn = CleanName(srcName)
      if cn and not IsGroupOrSelfByName(cn) then
        pvpIncoming[srcGUID] = { t = now, nameLower = cn:lower(), name = cn }
        TouchEncounter(srcGUID, cn, nil, nil)
      end
    end
  end

  -- Death events credit wins/losses to recently involved enemies
  if playerGUID and subevent == "UNIT_DIED" then
    if dstGUID == playerGUID then
      -- You died -> every recent attacker gets a "loss" credit
      for guid, e in pairs(pvpIncoming) do
        if e and e.t and (now - e.t) <= PVP_WINDOW then
          if DB.StatsAddLoss then DB:StatsAddLoss(e.nameLower or (e.name and e.name:lower()) or "") end
          ResolveEncounter(guid)
          pvpIncoming[guid] = nil
          pvpOutgoing[guid] = nil
        end
      end
    else
      -- Enemy died -> if you hit them recently, you get a "win" credit
      if dstGUID and IsFlagPlayer(dstFlags) and IsFlagHostileSpy(dstFlags) then
        local e = pvpOutgoing[dstGUID]
        if e and e.t and (now - e.t) <= PVP_WINDOW then
          if DB.StatsAddWin then DB:StatsAddWin(e.nameLower or (e.name and e.name:lower()) or "") end
          ResolveEncounter(dstGUID)
        end
        pvpOutgoing[dstGUID] = nil
        pvpIncoming[dstGUID] = nil
      end
    end
  end

  -- Stealth detection: alert on ANY hostile player entering stealth/prowl/shadowmeld.
  -- Some clients log these as SPELL_CAST_SUCCESS (especially Vanish/Prowl), so include that too.
  if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" or subevent == "SPELL_CAST_SUCCESS" then
    if IsFlagPlayer(srcFlags) and IsFlagHostileSpy(srcFlags) and IsStealthAura(spellId, spellName) then
      local cleanName = CleanName(srcName)
      if cleanName and not IsGroupOrSelfByName(cleanName) then
        if srcGUID then
          TouchEncounter(srcGUID, cleanName, nil, nil)
        end
        local key = cleanName:lower()
        if ShouldCLNotify("cl:stealth:" .. key, now, 8) then
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

  HandleCLName(srcName, srcFlags, srcGUID, now, DB, Notifier, Nearby)
  HandleCLName(dstName, dstFlags, dstGUID, now, DB, Notifier, Nearby)

  -- Last attackers tracking: ONLY when an enemy actually attacked YOU
  -- (not just seen/nearby; must be a hostile action targeted at the player).
  -- Some clients/log variants can be inconsistent, so fall back to dstFlags when available.
  local attackedMe = false
  if playerGUID and dstGUID == playerGUID then
    attackedMe = true
  elseif dstFlags and CombatLog_Object_IsA and COMBATLOG_OBJECT_AFFILIATION_MINE and COMBATLOG_OBJECT_TYPE_PLAYER then
    attackedMe = CombatLog_Object_IsA(dstFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) and CombatLog_Object_IsA(dstFlags, COMBATLOG_OBJECT_TYPE_PLAYER)
  end

  if attackedMe then
    if srcName and srcName ~= "" and IsFlagPlayer(srcFlags) and IsFlagHostileSpy(srcFlags) then
      local isAttack = false
      if subevent == "SWING_DAMAGE" or subevent == "RANGE_DAMAGE" or (subevent and subevent:find("_DAMAGE")) then
        isAttack = true
      elseif subevent == "SWING_MISSED" or subevent == "RANGE_MISSED" or (subevent and subevent:find("_MISSED")) then
        -- Attacks that miss/dodge/parry/immune/etc still count as an attack on you.
        isAttack = true
      elseif subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" or subevent == "SPELL_AURA_APPLIED_DOSE" then
        -- Hostile debuffs/CC on the player count as an attack (e.g. Sap/Cheap Shot).
        isAttack = true
      end

      if isAttack then
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
    end
  end
end

Core:SetScript("OnEvent", function(self, event, ...)
  local Detector = GetDetector()
  local Sync     = GetSync()
  local GUI      = GetGUI()
  local Minimap  = GetMinimap()
  local Activity = GetActivity()

  if event == "ADDON_LOADED" then
    local addon = ...
    if addon ~= ADDON_NAME then return end
    local DB = GetDB()
    if DB then DB:Init() end
    -- Periodic stats pruning (optional; controlled by profile.statsPruneEnabled)
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
    StartEncounterTicker()
    StartDeferredGuildResolveTicker()
    Print(L.MSG_LOADED)
    CheckEnemyNameplatesNotice()
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
    if Detector then Detector:CheckUnit("target") end
    if GUI then GUI:RefreshAll() end
    if Sync then Sync:Hello() end
    return
  end

  if event == "PLAYER_TARGET_CHANGED" then
    if Detector then Detector:CheckUnit("target") end
    if GUI then GUI:RefreshAll() end
    return
  end

  if event == "UPDATE_MOUSEOVER_UNIT" then
    if Detector then Detector:CheckUnit("mouseover") end
    return
  end

  if event == "NAME_PLATE_UNIT_ADDED" then
    local unit = ...
    if Detector then Detector:CheckUnit(unit) end
    return
  end

  if event == "NAME_PLATE_UNIT_REMOVED" then
    local unit = ...
    if KillOnSight_Nearby and KillOnSight_Nearby.OnNameplateRemoved then
      KillOnSight_Nearby:OnNameplateRemoved(unit)
    end
    return
  end

  if event == "UNIT_AURA" or event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_STOP"
  or event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
    local unit = ...
    if unit and (unit == "target" or unit == "mouseover" or unit:match("^nameplate")) then
      if Detector then Detector:CheckUnit(unit) end
    end
    return
  end

  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    HandleCombatLog()
    if Activity and Activity.OnCombatLog then Activity:OnCombatLog() end
    return
  end
end)

Core:RegisterEvent("ADDON_LOADED")
Core:RegisterEvent("CHAT_MSG_ADDON")
Core:RegisterEvent("PLAYER_ENTERING_WORLD")
Core:RegisterEvent("PLAYER_TARGET_CHANGED")
Core:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
Core:RegisterEvent("NAME_PLATE_UNIT_ADDED")
Core:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
Core:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
Core:RegisterEvent("UNIT_AURA")
Core:RegisterEvent("UNIT_SPELLCAST_START")
Core:RegisterEvent("UNIT_SPELLCAST_STOP")
Core:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
Core:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
Core:RegisterEvent("UNIT_SPELLCAST_FAILED")

-- Export for other modules.
_G.KillOnSight_Core = Core
_G.KillOnSight_Core._ScheduleGUIRefresh = _ScheduleGUIRefresh

-- Locale sanity checker: warns about keys defined in locales but never read by the UI/code.
LocaleSanityCheck = function()
  if not KillOnSight_L_data or not KillOnSight_L_used then return end

  -- Disable by setting KillOnSightDB.localeSanity = false
  if KillOnSightDB and KillOnSightDB.localeSanity == false then return end

  local unused = {}
  for k in pairs(KillOnSight_L_data) do
    if k ~= "__kos_proxy" and not KillOnSight_L_used[k] then
      unused[#unused+1] = k
    end
  end

  if #unused > 0 then
    table.sort(unused)
    local prefix = (KillOnSight_L and KillOnSight_L.ADDON_PREFIX) or "KILLONSIGHT"
    DEFAULT_CHAT_FRAME:AddMessage("|cff00d0ff"..prefix..":|r Locale sanity: "..#unused.." key(s) defined but unused. Set KillOnSightDB.localeSanity=false to silence.")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00d0ff"..prefix..":|r "..table.concat(unused, ", "))
  end
end
