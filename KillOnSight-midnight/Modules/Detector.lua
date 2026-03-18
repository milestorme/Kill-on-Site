-- Detector.lua
-- Unit-based detection and notification routing (Retail / Midnight only).
-- No CLEU dependency; relies on nameplates/target/mouseover/unit-scoped events.

local ADDON_NAME = ...
local L = KillOnSight_L

local DEFAULT_NEARBY_MAX_YARDS = 60
local FORCE_NEARBY_MAX_MULT = 1.5 -- allow a bit more distance for "high confidence" promotions

local function Now() return time() end

local function GetDB() return _G.KillOnSight_DB end
local function GetNotifier() return _G.KillOnSight_Notifier end
local function GetCore() return _G.KillOnSight_Core end

-- Hard gate: bail out if we're in any non-PvP instance (Delves, dungeons, raids, scenarios).
-- This is defense-in-depth; Core.lua also gates, but tainted return values can slip past.
local function _IsDisabledInstance()
  if not IsInInstance then return false end
  local ok, inInstance, instType = pcall(IsInInstance)
  if not ok then return true end  -- assume instanced on error
  -- inInstance may itself be tainted; use pcall for the truthiness check.
  local okBool, isIn = pcall(function() return inInstance == true end)
  if not okBool then return true end
  if not isIn then return false end
  local okCmp, isPvP = pcall(function()
    return instType == "pvp" or instType == "arena"
  end)
  if not okCmp then return true end
  return not isPvP
end
local function GetNearby() return _G.KillOnSight_Nearby end

-- Stealth/vanish detection via UNIT_AURA on target/mouseover/nameplates.
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
local stealthLastSeenByGUID = {} -- guid -> last seen timestamp

local STEALTH_STATE_TTL = 120
local STEALTH_NOTIFY_TTL = 120
local STEALTH_CLEANUP_INTERVAL = 30
local lastStealthCleanupAt = 0

local function CleanupStealthState(now)
  if (now - lastStealthCleanupAt) < STEALTH_CLEANUP_INTERVAL then return end
  lastStealthCleanupAt = now

  for guid, lastSeen in pairs(stealthLastSeenByGUID) do
    if (now - (lastSeen or 0)) > STEALTH_STATE_TTL then
      stealthLastSeenByGUID[guid] = nil
      stealthStateByGUID[guid] = nil
      visibleStateByGUID[guid] = nil
    end
  end

  for nameLower, lastAt in pairs(lastStealthNotifyAt) do
    if (now - (lastAt or 0)) > STEALTH_NOTIFY_TTL then
      lastStealthNotifyAt[nameLower] = nil
    end
  end
end

local function GetStealthNotifyCooldown()
  local DB = GetDB()
  local prof = DB and DB.GetProfile and DB:GetProfile()
  local cooldown = prof and tonumber(prof.stealthNotifyCooldownSeconds)
  if not cooldown or cooldown < 0 then cooldown = 8 end
  return cooldown
end

local function ShouldNotifyStealth(nameLower)
  local now = Now()
  local last = lastStealthNotifyAt[nameLower]
  local cooldown = GetStealthNotifyCooldown()
  if last and (now - last) < cooldown then return false end
  lastStealthNotifyAt[nameLower] = now
  return true
end

local function UnitHasStealthAura(unit)
  if not unit or unit == "" then return false end

  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID then
    for i = 1, #STEALTH_AURA_SPELLIDS do
      local id = STEALTH_AURA_SPELLIDS[i]
      local aura = C_UnitAuras.GetAuraDataBySpellID(unit, id)
      if aura then
        return true, (aura.name or (GetSpellInfo and GetSpellInfo(id))) or "Stealth"
      end
    end
  end

  return false
end

-- Enemy stealth auras are not always queryable via UnitAuras for hostile units.
-- As a fallback, infer "hidden" transitions via UnitIsVisible()/nameplate removal while recently engaged.
local function UnitIsActuallyVisible(unit)
  if UnitIsVisible then
    local ok = UnitIsVisible(unit)
    if ok ~= nil then return ok end
  end
  return true
end

local function CheckStealthTransition(unit, name, classFile, guild, guid, highConfidence)
  if not guid or not name or name == "" then return end

  local now = Now()
  stealthLastSeenByGUID[guid] = now
  CleanupStealthState(now)

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
      if (not prof) or prof.stealthDetectAddToNearby ~= false then
        local Nearby = GetNearby()
        if Nearby and Nearby.Seen then
          Nearby:Seen(name, classFile, guild, (L and L.HIDDEN) or "Hidden", nil, guid, unit)
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
  if not GetGuildInfo then return end
  local ok, g = pcall(GetGuildInfo, unit)
  if not ok then return nil end
  local okCmp, result = pcall(function()
    if type(g) ~= "string" then return nil end
    if g == "" then return nil end
    return g
  end)
  if not okCmp or not result then return nil end
  return result
end

local function GetUnitNameSafe(unit)
  if not unit or unit == "" then return nil end
  if not UnitName then return nil end
  local ok, raw = pcall(UnitName, unit)
  if not ok then return nil end
  -- raw may be a tainted "secret" string; tostring does NOT untaint it.
  -- Wrap ALL comparisons and operations in pcall.
  local okCheck, result = pcall(function()
    if type(raw) ~= "string" then return nil end
    if raw == "" then return nil end
    return raw
  end)
  if not okCheck or not result then return nil end
  return result
end

local function GetUnitFullNameSafe(unit)
  if not unit or unit == "" then return nil, nil end
  if not UnitFullName then return nil, nil end
  local ok, n, r = pcall(UnitFullName, unit)
  if not ok then return nil, nil end
  local okN, name = pcall(function()
    if type(n) ~= "string" then return nil end
    if n == "" then return nil end
    return n
  end)
  if not okN or not name then return nil, nil end
  local realm = nil
  if r ~= nil then
    local okR, realmStr = pcall(function()
      if type(r) ~= "string" then return nil end
      if r == "" then return nil end
      return r
    end)
    if okR and realmStr then
      realm = realmStr
    end
  end
  return name, realm
end

local function UnitTargetsPlayer(unit)
  if not unit or unit == "" then return false end
  if not UnitExists or not UnitIsUnit then return false end
  local u = unit .. "target"
  local ok, result = pcall(function()
    if not UnitExists(u) then return false end
    return UnitIsUnit(u, "player") and true or false
  end)
  return (ok and result) or false
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

-- Combat-entry correlation window (short-lived confidence boost).
local combatWindowUntil = 0
local function InCombatWindow()
  if not GetTime then return false end
  local ok, t = pcall(GetTime)
  if not ok or type(t) ~= "number" then return false end
  return (t < combatWindowUntil) and true or false
end

-- Track recent hostile engagements for win attribution (best-effort, no CLEU).
local recentEngagements = {}
local ENGAGE_WINDOW = 20 -- seconds
local function TrackEngagement(name, classFile, guild, guid)
  if not GetTime then return end
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
  if not unit or unit == "" then return end
  if _IsDisabledInstance() then return end
  if _G.KillOnSight_Core and (_G.KillOnSight_Core._bgDisabled or _G.KillOnSight_Core._instDisabled) then return end
  if not UnitGUID or not UnitName then return end

  local okG, guid = pcall(UnitGUID, unit)
  if not okG or not guid then return end

  -- Midnight: guid can be a protected "secret" value that passes nil checks
  -- but throws "table index is secret" when used as a table key or in string ops.
  local okType, isStr = pcall(function() return type(guid) == "string" end)
  if not okType or not isStr then return end

  local now = Now()
  local okSet, _ = pcall(function() stealthLastSeenByGUID[guid] = now end)
  if not okSet then return end
  CleanupStealthState(now)

  local okN, name = pcall(UnitName, unit)
  if not okN or name == nil then return end

  -- Some Midnight builds return protected "secret values" that can throw on compare or string ops.
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

  pcall(function()
    CheckStealthTransition(unit, name, nil, nil, guid, true)
  end)
end

function Detector:PopMostRecentEngagement(maxAge)
  if not GetTime then return nil end
  local now = GetTime()
  local window = maxAge or ENGAGE_WINDOW
  local bestKey, bestT, bestEntry = nil, 0, nil
  for k, e in pairs(recentEngagements) do
    local t = (type(e) == "table") and e.t or e
    if t and (now - t) <= window and t > bestT then
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
  if not name or name == "" then return nil end
  local clean = name:match("^[^-]+") or name
  local okLower, key = pcall(string.lower, clean)
  if not okLower or not key then return nil end

  local e = recentEngagements[key]
  if not e or type(e) ~= "table" then return nil end

  recentEngagements[key] = nil
  return (e.name or clean), e.classFile, e.guild, e.guid
end

-- Clear the engagement queue (used for best-effort win/loss attribution).
-- Called by Midnight_Stats on Reset Stats so old engagements can't repopulate.
function Detector:ResetEngagementQueue()
  for k in pairs(recentEngagements) do
    recentEngagements[k] = nil
  end
end

-- Combat window timing.
do
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

-- Debounced GUI refresh (provided by Core)
local function ScheduleGUIRefresh()
  local Core = GetCore()
  if Core and Core._ScheduleGUIRefresh then
    Core:_ScheduleGUIRefresh()
  elseif Core and Core.ScheduleGUIRefresh then
    Core:ScheduleGUIRefresh()
  end
end

-- Determine whether a unit is within Nearby range.
local function IsWithinNearbyRange(unit, forceNearby)
  if not UnitDistanceSquared then
    return true -- no API, can't filter
  end
  local distSq = UnitDistanceSquared(unit)
  if not distSq then return true end

  local maxYards = DEFAULT_NEARBY_MAX_YARDS
  if forceNearby then
    maxYards = maxYards * FORCE_NEARBY_MAX_MULT
  end

  return distSq <= (maxYards * maxYards)
end

-- Main entry point used by Core.lua (target/mouseover/nameplates/unit-scoped events).
function Detector:CheckUnit(unit, forceNearby)
  if not unit or unit == "" then return end
  -- Hard gate: never run detection inside Delves/dungeons/raids/scenarios.
  if _IsDisabledInstance() then return end
  if UnitExists and not UnitExists(unit) then return end

  local DB = GetDB()
  local Notifier = GetNotifier()
  if not DB or not Notifier then return end

  local guid = nil
  if UnitGUID then
    local okG, rawGuid = pcall(UnitGUID, unit)
    if okG then
      local okV, validGuid = pcall(function()
        if type(rawGuid) ~= "string" then return nil end
        if rawGuid == "" then return nil end
        return rawGuid
      end)
      if okV then guid = validGuid end
    end
  end
  local name = GetUnitNameSafe(unit)
  if not name then return end

  -- Nameplates include NPCs, pets and totems. We must only track *enemy players*.
  local isPlayerUnit = false
  if UnitIsPlayer then
    local okP, p = pcall(UnitIsPlayer, unit)
    isPlayerUnit = (okP and p and true) or false
  end
  local isPlayerGUID = false
  if guid then
    local okM, m = pcall(string.match, guid, '^Player%-')
    isPlayerGUID = (okM and m ~= nil)
  end

  -- Retail can briefly report hostile nameplate units as not-attackable (UnitCanAttack false)
  -- right as the nameplate appears. Prefer friend/enemy APIs and fall back to GUID-based assumptions.
  -- All WoW API boolean returns can be tainted in instances; wrap in pcall.
  local isHostile = nil
  pcall(function()
    if UnitIsEnemy then
      local e = UnitIsEnemy('player', unit)
      if e ~= nil then isHostile = e and true or false; return end
    end
    if UnitIsFriend then
      local f = UnitIsFriend('player', unit)
      if f ~= nil then isHostile = not f; return end
    end
    if UnitCanAttack then
      local ca = UnitCanAttack('player', unit)
      if ca ~= nil then isHostile = ca and true or false; return end
    end
  end)
  if isHostile == nil and isPlayerGUID and tostring(unit):match('^nameplate') then
    isHostile = true
  end

  local isEnemyPlayer = (isPlayerUnit or isPlayerGUID) and (isHostile == true)

  -- Confidence promotions
  if forceNearby or UnitTargetsPlayer(unit) or InCombatWindow() then
    forceNearby = true
  end

  local classFile = isPlayerUnit and (select(2, UnitClass(unit))) or nil
  local guild = GetUnitGuild(unit)

  -- Stealth detection via UNIT_AURA on target/mouseover/nameplates.
  if isEnemyPlayer then
    local highConfidence = forceNearby or UnitTargetsPlayer(unit) or InCombatWindow() or (unit == "target")
    CheckStealthTransition(unit, name, classFile, guild, guid, highConfidence)
  end

  -- Stats note (does not increment encounters; just updates last seen/class/guild).
  if isEnemyPlayer and DB.NoteEnemySeen then
    local statsName = name
    local fullName, realm = GetUnitFullNameSafe(unit)
    if fullName and realm and realm ~= "" then
      statsName = fullName .. "-" .. realm
    end
    DB:NoteEnemySeen(statsName, classFile, guild, guid, (UnitFactionGroup and UnitFactionGroup(unit)) )

    -- Encounter tracking: increment "Seen" only once per encounter (timeout-based).
    local Core = GetCore()
    if Core and Core.TouchEncounter then
      Core:TouchEncounter(guid, statsName, classFile, guild)
    end
  end

  -- Class/guild metadata can arrive late; ensure the Stats UI updates.
  if isEnemyPlayer then
    ScheduleGUIRefresh()
  end

  -- Maintain guild->guid mapping for attacker UI.
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
        Nearby:Seen(nearbyName, classFile, guild, kosType, (UnitLevel and UnitLevel(unit)) or nil, guid, unit)
      end
    end

    -- Engagement tracking for win attribution (best-effort).
    local isDirectUnit = (unit == "target" or unit == "mouseover")
    if (forceNearby or UnitTargetsPlayer(unit) or InCombatWindow() or isDirectUnit) then
      TrackEngagement(name, classFile, guild, guid)
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
