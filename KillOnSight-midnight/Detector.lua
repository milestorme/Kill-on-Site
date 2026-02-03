-- Detector.lua
-- Unit-based detection and notification routing.
-- Retail (Midnight+): no CLEU dependency; relies on nameplates/target/mouseover/unit-scoped events.
-- Classic-era clients: remains compatible; this file does not remove CLEU functionality elsewhere.

local ADDON_NAME = ...
local L = KillOnSight_L

local IS_RETAIL = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local DEFAULT_RETAIL_NEARBY_MAX_YARDS = 60
local RETAIL_FORCE_NEARBY_MAX_MULT = 1.5 -- allow a bit more distance for "high confidence" promotions

local function Now() return time() end

local function GetDB() return _G.KillOnSight_DB end
local function GetNotifier() return _G.KillOnSight_Notifier end
local function GetCore() return _G.KillOnSight_Core end
local function GetNearby() return _G.KillOnSight_Nearby end

-- Retail stealth/vanish detection (no CLEU): driven by UNIT_AURA on target/mouseover/nameplates.
-- We use spellIDs to avoid localization issues.
local STEALTH_AURA_SPELLIDS = {
  1784,   -- Rogue: Stealth
  1856,   -- Rogue: Vanish (often grants/refreshes Stealth)
  11327,  -- Rogue: Vanish (older/alternate aura id seen on some clients)
  5215,   -- Druid: Prowl
  58984,  -- Night Elf: Shadowmeld
}

local stealthStateByGUID = {} -- guid -> true (stealthed)
local lastStealthNotifyAt = {} -- nameLower -> time
local visibleStateByGUID = {} -- guid -> true (visible)

local function ShouldNotifyStealth(nameLower)
  local now = Now()
  local last = lastStealthNotifyAt[nameLower]
  if last and (now - last) < 8 then return false end
  lastStealthNotifyAt[nameLower] = now
  return true
end

local function UnitHasStealthAura(unit)
  if not IS_RETAIL then return false end
  if not unit or unit == "" then return false end

  -- Fast path: Dragonflight+ C_UnitAuras helper.
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID then
    for i = 1, #STEALTH_AURA_SPELLIDS do
      local id = STEALTH_AURA_SPELLIDS[i]
      local aura = C_UnitAuras.GetAuraDataBySpellID(unit, id)
      if aura then
        return true, (aura.name or (GetSpellInfo and GetSpellInfo(id))) or "Stealth"
      end
    end
    return false
  end

  -- Fallback: scan buffs (Classic-era only). Retail UnitAura can surface protected values.
  if not IS_RETAIL and UnitAura then
    for i = 1, 40 do
      local name, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, "HELPFUL")
      if not name then break end
      if spellId then
        for j = 1, #STEALTH_AURA_SPELLIDS do
          if spellId == STEALTH_AURA_SPELLIDS[j] then
            return true, name
          end
        end
      end
    end
  end
  return false
end

-- Retail reality: enemy stealth auras are not always queryable via UnitAuras for hostile units.
-- As a fallback, infer "hidden" transitions via UnitIsVisible()/nameplate removal while recently engaged.
local function UnitIsActuallyVisible(unit)
  if not IS_RETAIL then return true end
  if UnitIsVisible then
    local ok = UnitIsVisible(unit)
    if ok ~= nil then return ok end
  end
  return true
end

local function CheckStealthTransition(unit, name, classFile, guild, guid, highConfidence)
  if not IS_RETAIL then return end
  if not guid or not name or name == "" then return end

  local DB = GetDB()
  local Notifier = GetNotifier()
  if not DB or not Notifier then return end

  local prof = DB.GetProfile and DB:GetProfile() or nil
  if prof and prof.stealthDetectEnabled == false then
    stealthStateByGUID[guid] = nil
    return
  end

  local nowStealthed, auraName = UnitHasStealthAura(unit)
  local prev = stealthStateByGUID[guid] == true

  -- Fallback inference: when an enemy player goes from visible -> not visible while we have
  -- high confidence they were engaged/near (targeted, targeting us, or in combat window),
  -- treat this as a "hidden" transition (Vanish/Prowl/Shadowmeld). This covers cases where
  -- hostile buff auras are not queryable.
  local visibleNow = UnitIsActuallyVisible(unit)
  local visiblePrev = visibleStateByGUID[guid]
  if visiblePrev == nil then visiblePrev = true end
  visibleStateByGUID[guid] = visibleNow

  if (not nowStealthed) and highConfidence and (visiblePrev == true) and (visibleNow == false) then
    nowStealthed = true
    auraName = auraName or "Hidden"
  end

  if nowStealthed and not prev then
    stealthStateByGUID[guid] = true

    local keyLower = name:lower()
    if ShouldNotifyStealth(keyLower) then
      -- Optionally add/update Nearby as Hidden.
      if (not prof) or prof.stealthDetectAddToNearby ~= false then
        local Nearby = GetNearby()
        if Nearby and Nearby.Seen then
          Nearby:Seen(name, classFile, guild, (L and L.HIDDEN) or "Hidden", nil, guid)
        end
      end

      if Notifier and Notifier.NotifyHidden then
        Notifier:NotifyHidden(name, auraName or "Stealth", guid)
      end
    end
  elseif (not nowStealthed) and prev then
    stealthStateByGUID[guid] = nil
  end
end

local function GetUnitGuild(unit)
  if not unit then return end
  local g = GetGuildInfo and GetGuildInfo(unit)
  if g and g ~= "" then return g end
end

local function GetUnitNameSafe(unit)
  if not unit or unit == "" then return nil end
  if not UnitName then return nil end
  local ok, raw = pcall(UnitName, unit)
  if not ok then return nil end
  local ok2, name = pcall(tostring, raw)
  if not ok2 or type(name) ~= "string" or name == "" then return nil end
  return name
end

local function GetUnitFullNameSafe(unit)
  if not unit or unit == "" then return nil, nil end
  if not UnitFullName then return nil, nil end
  local ok, n, r = pcall(UnitFullName, unit)
  if not ok then return nil, nil end
  local okN, name = pcall(tostring, n)
  if not okN or type(name) ~= "string" or name == "" then return nil, nil end
  local realm = nil
  if r ~= nil then
    local okR, realmStr = pcall(tostring, r)
    if okR and type(realmStr) == "string" and realmStr ~= "" then
      realm = realmStr
    end
  end
  return name, realm
end

-- Retail-safe: avoid UnitTarget() (can be nil/tainted in some clients); use unit token instead.
local function UnitTargetsPlayer(unit)
  if not unit or unit == "" then return false end
  if not UnitExists or not UnitIsUnit then return false end
  local u = unit .. "target"
  local ok1, exists = pcall(UnitExists, u)
  if not ok1 or exists ~= true then return false end
  local ok2, isunit = pcall(UnitIsUnit, u, "player")
  return (ok2 and isunit == true) or false
end

-- Throttle notifications per key (player/guild) using profile throttleSeconds.
local lastNotifyAt = {}
local function ShouldNotify(key)
  local DB = GetDB()
  if not DB then return false end
  local prof = DB.GetProfile and DB:GetProfile() or nil
  local t = (prof and tonumber(prof.throttleSeconds)) or 12
  local now = Now()
  if lastNotifyAt[key] and (now - lastNotifyAt[key]) < t then
    return false
  end
  lastNotifyAt[key] = now
  return true
end

-- Retail: combat-entry correlation window (short-lived confidence boost).
local combatWindowUntil = 0
local function InCombatWindow()
  if not IS_RETAIL or not GetTime then return false end
  local ok, t = pcall(GetTime)
  if not ok or type(t) ~= "number" then return false end
  return (t < combatWindowUntil) and true or false
end

-- Retail: track recent hostile engagements for BG win attribution (best-effort, no CLEU).
local recentEngagements = {}
local ENGAGE_WINDOW = 20 -- seconds
local function TrackEngagement(name, classFile, guild, guid)
  if not IS_RETAIL or not GetTime then return end
  if not name or name == "" then return end

  local okLower, key = pcall(string.lower, name)
  if not okLower or not key then return end

  recentEngagements[key] = {
    t = GetTime(),
    name = name,
    classFile = classFile,
    guild = guild,
    guid = guid,
  }
end

local Detector = {}

-- NAME_PLATE_UNIT_REMOVED does not reliably fire UNIT_AURA/UNIT_FLAGS transitions in all cases.
-- When a recently engaged enemy player's nameplate disappears abruptly (common for Vanish/Prowl),
-- infer a hidden transition to keep stealth/prowl announcements working without CLEU.
function Detector:OnNameplateRemoved(unit)
  if not IS_RETAIL then return end
  if not unit or unit == "" then return end
  -- If Core has disabled detection (BG/Arena or PvE instances), ignore nameplate events entirely.
  if _G.KillOnSight_Core and (_G.KillOnSight_Core._bgDisabled or _G.KillOnSight_Core._instDisabled) then return end
  if not UnitGUID or not UnitName then return end

  local okG, guid = pcall(UnitGUID, unit)
  if not okG or not guid then return end

  local okN, name = pcall(UnitName, unit)
  if not okN or name == nil then return end

  -- Some Retail/Midnight builds return protected "secret values" that can throw on compare or string ops.
  local okEmpty, isEmpty = pcall(function() return name == "" end)
  if not okEmpty or isEmpty then return end

  local okMatch, isPlayer = pcall(function() return type(guid) == "string" and guid:match("^Player%-") ~= nil end)
  if not okMatch or not isPlayer then return end

  local okLower, k = pcall(string.lower, name)
  if not okLower or not k then return end

  local e = recentEngagements[k]
  if not e or type(e) ~= "table" or not e.t or not GetTime then return end

  local age = GetTime() - e.t
  if age > 5 then return end

  -- Only notify if we haven't already marked them as stealthed.
  pcall(function()
    CheckStealthTransition(unit, name, nil, nil, guid, true)
  end)
end
function Detector:PopMostRecentEngagement()
  if not IS_RETAIL or not GetTime then return nil end
  local now = GetTime()
  local bestKey, bestT, bestEntry = nil, 0, nil
  for k, e in pairs(recentEngagements) do
    local t = (type(e) == "table") and e.t or e
    if t and (now - t) <= ENGAGE_WINDOW and t > bestT then
      bestKey, bestT, bestEntry = k, t, e
    end
  end
  if bestKey then
    recentEngagements[bestKey] = nil
    if type(bestEntry) == "table" then
      return (bestEntry.name or bestKey), bestEntry.classFile, bestEntry.guild, bestEntry.guid
    end
    return bestKey
  end
end

function Detector:PopEngagementForName(name)
  if not IS_RETAIL then return nil end
  if not name or name == "" then return nil end
  local clean = name:match("^[^-]+") or name
  local okLower, key = pcall(string.lower, clean)
  if not okLower or not key then return nil end

  local e = recentEngagements[key]
  if not e or type(e) ~= "table" then return nil end

  recentEngagements[key] = nil
  return (e.name or clean), e.classFile, e.guild, e.guid
end

-- Clear the Retail engagement queue (used for best-effort win/loss attribution).
-- Called by Midnight_Stats on Reset Stats so old engagements can't repopulate.
function Detector:ResetEngagementQueue()
  if not IS_RETAIL then return end
  for k in pairs(recentEngagements) do
    recentEngagements[k] = nil
  end
end

-- Lightweight internal event hook (Retail only) for combat window timing.
do
  if IS_RETAIL and CreateFrame then
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_REGEN_DISABLED" then
        combatWindowUntil = (GetTime and GetTime() or 0) + 2
      elseif event == "PLAYER_REGEN_ENABLED" then
        combatWindowUntil = 0
      end
    end)
  end
end

-- Debounced GUI refresh (provided by Core)
local function ScheduleGUIRefresh()
  local Core = GetCore()
  if Core and Core._ScheduleGUIRefresh then
    Core:_ScheduleGUIRefresh()
  elseif Core and Core.ScheduleGUIRefresh then
    Core:ScheduleGUIRefresh()
  end
end

-- Determine whether a unit is within Nearby range (Retail only). On non-Retail, returns true.
local function IsWithinNearbyRange(unit, forceNearby)
  if not IS_RETAIL then return true end
  if not UnitDistanceSquared then
    return true -- no API, can't filter
  end
  local distSq = UnitDistanceSquared(unit)
  if not distSq then return true end

  local maxYards = DEFAULT_RETAIL_NEARBY_MAX_YARDS
  if forceNearby then
    maxYards = maxYards * RETAIL_FORCE_NEARBY_MAX_MULT
  end

  return distSq <= (maxYards * maxYards)
end

-- Main entry point used by Core.lua (target/mouseover/nameplates/unit-scoped events).
function Detector:CheckUnit(unit, forceNearby)
  if not unit or unit == "" then return end
  if UnitExists and not UnitExists(unit) then return end

  local DB = GetDB()
  local Notifier = GetNotifier()
  if not DB or not Notifier then return end

  local guid = UnitGUID and UnitGUID(unit)
  local name = GetUnitNameSafe(unit)
  if not name then return end

  -- Retail nameplates include NPCs, pets and totems (Fire Elemental, Earthgrab Totem, etc).
  -- We must only track *enemy players* for Stats and Nearby tagging.
  local isPlayerUnit = (UnitIsPlayer and UnitIsPlayer(unit)) or false
  local isPlayerGUID = (guid and guid:match('^Player%-')) ~= nil

  -- Retail can briefly report hostile nameplate units as not-attackable (UnitCanAttack false)
  -- right as the nameplate appears. That causes Nearby to lag by several seconds until another
  -- event retriggers detection. Prefer friend/enemy APIs and fall back to GUID-based assumptions.
  local isHostile = nil
  if UnitIsEnemy then
    isHostile = UnitIsEnemy('player', unit)
  end
  if isHostile == nil and UnitIsFriend then
    local f = UnitIsFriend('player', unit)
    if f ~= nil then isHostile = not f end
  end
  if isHostile == nil and UnitCanAttack then
    local ca = UnitCanAttack('player', unit)
    if ca ~= nil then isHostile = ca end
  end
  -- As a last resort: if it's a Player GUID and a nameplate unit token, treat as hostile.
  if isHostile == nil and isPlayerGUID and tostring(unit):match('^nameplate') then
    isHostile = true
  end

  local isEnemyPlayer = (isPlayerUnit or isPlayerGUID) and (isHostile == true)

  -- Confidence promotions (Retail only)
  if IS_RETAIL then
    if forceNearby or UnitTargetsPlayer(unit) or InCombatWindow() then
      forceNearby = true
    end
  end

  local classFile = isPlayerUnit and (select(2, UnitClass(unit))) or nil
  local guild = GetUnitGuild(unit)

  -- Retail: class info may not be available immediately on NAME_PLATE_UNIT_ADDED.
  if IS_RETAIL and (isPlayerUnit or isPlayerGUID) and (not classFile or classFile == "") and guid then
    ScheduleClassRetry(unit, guid, 0, forceNearby)
  end

  -- Retail stealth detection without CLEU: detect transitions via UNIT_AURA on target/mouseover/nameplates.
  -- This catches Vanish/Stealth/Prowl/Shadowmeld even when the player is already on-screen.
  if IS_RETAIL and isEnemyPlayer then
    local highConfidence = forceNearby or UnitTargetsPlayer(unit) or InCombatWindow() or (unit == "target")
    CheckStealthTransition(unit, name, classFile, guild, guid, highConfidence)
  end

  -- Stats note (does not increment encounters; just updates last seen/class/guild).
  if isEnemyPlayer and DB.NoteEnemySeen then
    DB:NoteEnemySeen(name, classFile, guild, guid)
  end

  -- Retail: class/guild metadata can arrive late; ensure the Stats UI updates even when
  -- this enemy isn't KoS/Guild. Core refresh is debounced.
  if IS_RETAIL and isEnemyPlayer then
    ScheduleGUIRefresh()
  end

  -- Maintain guild->guid mapping for attacker UI (Classic/TBC still use this in some paths).
  if guid and guild and DB.UpdateLastAttackerGuildByGUID then
    DB:UpdateLastAttackerGuildByGUID(guid, guild)
  elseif name and guild and DB.UpdateLastAttackerGuild then
    DB:UpdateLastAttackerGuild(name, guild)
  end

  -- Nearby list population (hostile players)
  local withinNearbyRange = IsWithinNearbyRange(unit, forceNearby)

  if isEnemyPlayer then
    if withinNearbyRange then
      local kosType = nil
      local pe = DB.LookupPlayer and DB:LookupPlayer(name)
      if pe then
        kosType = pe.type or (L and L.KOS) or "KoS"
      elseif guild and DB.LookupGuild then
        local ge = DB:LookupGuild(guild)
        if ge then
          kosType = ge.type or (L and L.GUILD_KOS) or "Guild"
        end
      end

      local Nearby = GetNearby()
      if Nearby and Nearby.Seen then
        local nearbyName = name
        local fullName, realm = GetUnitFullNameSafe(unit)
        if fullName and realm and realm ~= "" then
          nearbyName = fullName .. "-" .. realm
        end
        Nearby:Seen(nearbyName, classFile, guild, kosType, (UnitLevel and UnitLevel(unit)) or nil, guid)
      end
    end

    -- Engagement tracking for Retail win attribution (best-effort).
    -- Include target/mouseover so open-world wins/losses credit even when the enemy
    -- never targets you (common for ranged kills or quick skirmishes).
    if IS_RETAIL then
      local isDirectUnit = (unit == "target" or unit == "mouseover")
      if (forceNearby or UnitTargetsPlayer(unit) or InCombatWindow() or isDirectUnit) then
        TrackEngagement(name, classFile, guild, guid)
      end
    end
  end

  -- KoS player notification
  local playerEntry = DB.LookupPlayer and DB:LookupPlayer(name)
  if playerEntry then
    if classFile and DB.SetPlayerClass then DB:SetPlayerClass(name, classFile) end
    DB:MarkSeenPlayer(name)
    ScheduleGUIRefresh()

    local key = "p:" .. name:lower()
    if ShouldNotify(key) then
      Notifier:NotifyPlayer(playerEntry.type or (L and L.KOS) or "KoS", name, playerEntry.reason)
    end
    return
  end

  -- Guild notification (when guild is known and tracked)
  if guild and guild ~= "" and DB.LookupGuild then
    local guildEntry = DB:LookupGuild(guild)
    if guildEntry then
      DB:MarkSeenGuild(guild)
      ScheduleGUIRefresh()

      local key = "g:" .. guild:lower()
      if ShouldNotify(key) then
        Notifier:NotifyGuild(guildEntry.type or (L and L.GUILD_KOS) or "Guild", name, guild, guildEntry.reason)
      end
      return
    end
  end
end

_G.KillOnSight_Detector = Detector
return Detector
