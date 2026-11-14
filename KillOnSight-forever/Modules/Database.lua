-- Database.lua
local ADDON_NAME = ...
local L = KillOnSight_L

KillOnSightDB = KillOnSightDB or {}


-- NOTE: SavedVariables are handled via KillOnSightDB.
-- Any legacy migration code was removed during cleanup because it was either a no-op or dead code.

local DB = {}

-- Normalize class input to classFile token (e.g. "ROGUE")
local _locToClassFile
local function _NormalizeClassForDB(classIn)
  if not classIn or classIn == "" then return nil end
  if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classIn] then
    return classIn
  end
  if not _locToClassFile then
    _locToClassFile = {}
    if LOCALIZED_CLASS_NAMES_MALE then
      for file, loc in pairs(LOCALIZED_CLASS_NAMES_MALE) do
        _locToClassFile[loc] = file
      end
    end
    if LOCALIZED_CLASS_NAMES_FEMALE then
      for file, loc in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
        _locToClassFile[loc] = file
      end
    end
  end
  return _locToClassFile[classIn]
end





local function Now() return time() end

local function RealmKey()
  -- Account-wide shared DB across all realms/factions/characters.
  return "GLOBAL"
end

local function CharKey()
  local util = _G.KillOnSight_Util
  local name = (util and util:UnitPlayerName("player")) or ((_G.KillOnSight_Util and _G.KillOnSight_Util:UnitPlayerName("player")) or UnitName("player")) or "Unknown"
  if util and util:IsForeverNames() then return name end
  if name:find("-", 1, true) then return name end
  local realm = GetRealmName() or "UnknownRealm"
  return name .. "-" .. realm
end

local DEFAULTS = {
  profile = {
    enableSound = true,
    enableScreenFlash = true,
    throttleSeconds = 12,
    printToChat = true,
    minimap = { hide=false, minimapPos=220 },
    showNearbyFrame = true,
    nearbyFrameLocked = false,
	    -- nearbyFrame.bgAlpha controls the backdrop/border opacity. For simplicity (and
	    -- backward compatibility), we also keep nearbyAlpha in sync with bgAlpha so the
	    -- overall window opacity matches the background slider unless fading is enabled.
	    nearbyFrame = { point="CENTER", relPoint="CENTER", x=280, y=80, scale=0.80, bgAlpha=0.60 },
	    -- Legacy key (older versions used this for overall frame alpha). Kept for back-compat.
	    nearbyAlpha = 0.60,
    nearbyAutoHide = false,
    nearbyFade = false,

    -- Spy-style sound when a non-KoS enemy is first added to the nearby list.
    -- (Separate from KoS alerts and separate from stealth-detection sounds.)
    nearbySound = true,
    -- Nearby window is always ultra-minimal (no toggle)
    nearbyMinimal = true,
    nearbyRowIcons = true,
    -- Font used for player names in the Nearby list (dropdown in Options)
    nearbyNameFont = "Default",
    nearbyNameFontSize = 12,
    -- Max number of rows to show in Nearby before scrolling (Nearby pre-creates 20 rows)
    nearbyMaxVisibleRows = 20,
-- Stealth detection
stealthDetectEnabled = true,
stealthDetectChat = true,
stealthDetectSound = true,
stealthDetectCenterWarning = true,
stealthDetectAddToNearby = true,
    stealthWarningHoldSeconds = 6.0,
    stealthWarningFadeSeconds = 1.2,
    stealthNotifyCooldownSeconds = 8,

    -- Enemy stats pruning policy (enabled by default)
    statsPruneEnabled = true,
    statsPruneMaxDays = 180,
    statsPruneMaxEntries = 25000,
  },
  data = {
    revision = 0,          -- global revision
    statsRevision = 0,     -- enemy stats revision (for UI caching)
    honorPlayers = {},     -- [lowerFullName] = honoured enemy
    players = {},          -- [lowerName] = entry
    guilds  = {},          -- [lowerGuild] = entry
    changes = {},          -- [seq] = { op="upsert"/"delete", kind="P"/"G", key, entry, rev }
    lastAttackers = {},    -- array of {name, guid, zone, at}

		-- Enemy encounter statistics (unbounded by default)
		-- statsPlayers[lowerName] = {
		--   name, classFile, guild,
		--   firstSeenAt, lastSeenAt,
		--   seenCount,
		--   wins, loses,
		-- }
		statsPlayers = {},
  }
}

-- Optional pruning policy for enemy stats (prevents long-term SavedVariables bloat)
-- Enabled by default to keep SavedVariables lean; can be disabled if you prefer Spy-like "remember everything" behavior.
--
-- Settings live in profile:
--   statsPruneEnabled   (bool)
--   statsPruneMaxDays   (number)  -- drop entries not seen in N days
--   statsPruneMaxEntries(number)  -- hard cap by dropping oldest lastSeenAt

local function DeepCopy(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = dst[k] or {}
      DeepCopy(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end


local function _MergeInto(dst, src)
  -- Merge src table into dst table (dst wins on conflicts)
  if type(dst) ~= "table" or type(src) ~= "table" then return end
  for k,v in pairs(src) do
    if dst[k] == nil then
      if type(v) == "table" then
        local t = {}
        _MergeInto(t, v)
        dst[k] = t
      else
        dst[k] = v
      end
    elseif type(dst[k]) == "table" and type(v) == "table" then
      _MergeInto(dst[k], v)
    end
  end
end

local function _MergeData(dstData, srcData)
  if type(dstData) ~= "table" or type(srcData) ~= "table" then return end

  dstData.honorPlayers = dstData.honorPlayers or {}
  for k, entry in pairs(srcData.honorPlayers or {}) do
    if dstData.honorPlayers[k] == nil then dstData.honorPlayers[k] = entry end
  end
  dstData.players = dstData.players or {}
  if type(srcData.players) == "table" then
    for k, entry in pairs(srcData.players) do
      if dstData.players[k] == nil then
        dstData.players[k] = entry
      else
        local a = dstData.players[k]
        local b = entry
        local aSeen = tonumber(a.lastSeenAt or 0) or 0
        local bSeen = tonumber(b.lastSeenAt or 0) or 0
        if bSeen > aSeen then
          dstData.players[k] = b
        end
      end
    end
  end

  dstData.guilds = dstData.guilds or {}
  if type(srcData.guilds) == "table" then
    for k, entry in pairs(srcData.guilds) do
      if dstData.guilds[k] == nil then
        dstData.guilds[k] = entry
      end
    end
  end

  -- Merge statsPlayers if present
  dstData.statsPlayers = dstData.statsPlayers or {}
  if type(srcData.statsPlayers) == "table" then
    for k, entry in pairs(srcData.statsPlayers) do
      if dstData.statsPlayers[k] == nil then
        dstData.statsPlayers[k] = entry
      else
        local a = dstData.statsPlayers[k]
        local b = entry
        local aSeen = tonumber(a.lastSeenAt or 0) or 0
        local bSeen = tonumber(b.lastSeenAt or 0) or 0
        if bSeen > aSeen then
          dstData.statsPlayers[k] = b
        end
      end
    end
  end

  -- Keep highest revisions
  dstData.revision = math.max(tonumber(dstData.revision or 0) or 0, tonumber(srcData.revision or 0) or 0)
  dstData.statsRevision = math.max(tonumber(dstData.statsRevision or 0) or 0, tonumber(srcData.statsRevision or 0) or 0)
end

local function norm(s)
  if not s or s == "" then return nil end
  s = s:gsub("^%s+",""):gsub("%s+$","")
  if s == "" then return nil end
  return s
end

function DB:_BumpStatsRevision()
  local d = self:GetData()
  d.statsRevision = (tonumber(d.statsRevision or 0) or 0) + 1
end

function DB:GetStatsRevision()
  local d = self:GetData()
  return tonumber(d.statsRevision or 0) or 0
end

-- One-time, non-destructive migration for WoW Forever two-part identities.
-- Keep an in-SavedVariables snapshot for recovery; never guess missing surnames.
local NAME_SCHEMA_VERSION = 2
local function _NameIdentity(name)
  if type(name) ~= "string" then return nil end
  local util = _G.KillOnSight_Util
  if util and util.NormalizePlayerName then name = util:NormalizePlayerName(name) end
  if type(name) ~= "string" then return nil end
  name = name:gsub("%s*%-%s*", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
  if name == "" then return nil end
  return name:lower(), name
end
local function _LegacyFullName(oldKey, entry)
  -- Forever originally used the legacy realm field for the SURNAME.
  -- Only append it if the stored name is a single token. Never double-append.
  local full = type(entry.fullName) == "string" and entry.fullName or nil
  local name = type(entry.name) == "string" and entry.name or nil
  local surname = type(entry.realm) == "string" and entry.realm:match("^%s*(.-)%s*$") or nil
  if full and full ~= "" then return full end
  if name and name ~= "" then
    if name:find("[ %-]") then return name end
    if surname and surname ~= "" then return name .. " " .. surname end
  end
  -- Keys with two components are unambiguous even if entry.name is first-only.
  if type(oldKey) == "string" and oldKey:find("[ %-]") then return oldKey end
  return name or oldKey
end
local function _MergeMigratedEntry(dst, src, kind)
  if kind == "statsPlayers" then
    -- Historical duplicate counters can overlap; max avoids inventing events.
    for _, field in ipairs({"seenCount", "wins", "loses"}) do
      dst[field] = math.max(tonumber(dst[field]) or 0, tonumber(src[field]) or 0)
    end
    local first, oldFirst = tonumber(dst.firstSeenAt) or 0, tonumber(src.firstSeenAt) or 0
    if oldFirst > 0 and (first == 0 or oldFirst < first) then dst.firstSeenAt = oldFirst end
    if (tonumber(src.lastSeenAt) or 0) > (tonumber(dst.lastSeenAt) or 0) then dst.lastSeenAt = src.lastSeenAt end
  end
  -- Never discard notes or other distinct metadata when entries collide.
  for k, v in pairs(src) do
    if dst[k] == nil or dst[k] == "" then dst[k] = v end
  end
end
local function _MigrateNameData(realmDB)
  local util = _G.KillOnSight_Util
  if not (util and util.IsForeverNames and util:IsForeverNames()) then return end
  local data = realmDB.data
  if type(data) ~= "table" or (tonumber(data.nameSchemaVersion) or 0) >= NAME_SCHEMA_VERSION then return end
  -- Preserve the original backup from v1 and take a fresh v2 snapshot.
  if not realmDB.nameMigrationBackupV2 then
    local snapshot = {schema=NAME_SCHEMA_VERSION, createdAt=Now()}
    for _, kind in ipairs({"players", "honorPlayers", "statsPlayers"}) do
      snapshot[kind] = {}
      for key, entry in pairs(data[kind] or {}) do
        if type(entry) == "table" then
          local copy = {}; _MergeInto(copy, entry); snapshot[kind][key] = copy
        end
      end
    end
    realmDB.nameMigrationBackupV2 = snapshot
  end
  local changed = false
  for _, kind in ipairs({"players", "honorPlayers", "statsPlayers"}) do
    local entries = data[kind]
    if type(entries) == "table" then
      local keys = {}
      for key in pairs(entries) do keys[#keys+1] = key end
      table.sort(keys, function(x,y) return tostring(x) < tostring(y) end)
      for _, oldKey in ipairs(keys) do
        local entry = entries[oldKey]
        if type(entry) == "table" then
          local identity = _LegacyFullName(oldKey, entry)
          local key, full = _NameIdentity(identity)
          -- Never merge an unqualified first name with a full identity.
          if key and full:find(" ", 1, true) then
            if oldKey ~= key then
              local dst = entries[key]
              if dst and dst ~= entry then
                -- Only merge when both records independently resolve to the same full name.
                local otherKey = _NameIdentity(_LegacyFullName(key, dst))
                if otherKey == key then
                  _MergeMigratedEntry(dst, entry, kind)
                  entries[oldKey] = nil
                  entry = dst
                  changed = true
                end
              elseif not dst then
                entries[key] = entry
                entries[oldKey] = nil
                changed = true
              end
            end
            if entries[key] == entry then
              -- Stats uses name/realm as legacy components. Do not overwrite
              -- name with the complete identity while realm is still populated:
              -- older display paths would append the surname a second time.
              if kind == "statsPlayers" then
                local first, surname = full:match("^(%S+)%s+(.+)$")
                entry.name = first or full
                entry.realm = surname or entry.realm
              else
                entry.name = full
              end
              entry.fullName = full
            end
          end
        end
      end
    end
  end
  data.nameSchemaVersion = NAME_SCHEMA_VERSION
  if changed then
    data.revision = (tonumber(data.revision) or 0) + 1
    data.statsRevision = (tonumber(data.statsRevision) or 0) + 1
  end
end

function DB:Init()
  -- Use a single account-wide database shared across all realms/factions/characters.
  KillOnSightDB.global = KillOnSightDB.global or {}
  local realmDB = KillOnSightDB.global

  -- One-time migration: if older builds stored per-realm DBs, merge them into the global DB.
  if KillOnSightDB.realms and type(KillOnSightDB.realms) == "table" then
    for _, old in pairs(KillOnSightDB.realms) do
      if type(old) == "table" then
        -- Merge profiles + assignments first
        if type(old.profiles) == "table" then
          realmDB.profiles = realmDB.profiles or {}
          _MergeInto(realmDB.profiles, old.profiles)
        end
        if type(old.profileNameByChar) == "table" then
          realmDB.profileNameByChar = realmDB.profileNameByChar or {}
          _MergeInto(realmDB.profileNameByChar, old.profileNameByChar)
        end
        -- Merge main data tables (players/guilds/stats)
        if type(old.data) == "table" then
          realmDB.data = realmDB.data or {}
          _MergeInto(realmDB.data, DEFAULTS.data) -- ensure structure
          _MergeData(realmDB.data, old.data)
        end
      end
    end
  end

  -- Ensure defaults exist on the global DB
  DeepCopy(realmDB, DEFAULTS)

  self.realmKey = "GLOBAL"
  self.realmDB = realmDB

  -- Profiles (options only): allow multiple option sets and per-character assignment.
  -- Backward compatible: older SVs store options directly in realmDB.profile.
  realmDB.profiles = realmDB.profiles or {}
  realmDB.profileNameByChar = realmDB.profileNameByChar or {}

  -- Migrate legacy single profile into a named profile.
  if realmDB.profile and not realmDB.profiles["Default"] then
    realmDB.profiles["Default"] = realmDB.profile
  elseif not realmDB.profiles["Default"] then
    realmDB.profiles["Default"] = {}
    DeepCopy(realmDB.profiles["Default"], DEFAULTS.profile)
  end

  local ck = CharKey()
  local assigned = realmDB.profileNameByChar[ck] or "Default"
  if not realmDB.profiles[assigned] then
    assigned = "Default"
    realmDB.profileNameByChar[ck] = assigned
  end

  -- Ensure new defaults exist on all profiles (e.g. after updates)
  for _,pobj in pairs(realmDB.profiles) do
    if type(pobj) == "table" then
      DeepCopy(pobj, DEFAULTS.profile)
      -- Force ultra-minimal Nearby window (no toggle)
      pobj.nearbyMinimal = true
    end
  end

  self.activeProfileName = assigned
  self.activeProfile = realmDB.profiles[assigned]


  -- Back-compat: keep realmDB.profile pointing at Default (some older forks may still read it).
  realmDB.profile = realmDB.profiles["Default"]

  -- Apply cleanup / defaulting to ALL profiles (keeps profiles consistent across updates)
  for _, pobj in pairs(realmDB.profiles) do
    if type(pobj) == "table" then
      -- Clean up legacy/dead config keys (kept for backward compatibility in old SVs)
      pobj.guildAlertCooldownSeconds = nil
      pobj.kosAlertCooldownSeconds = nil
      pobj.activityThrottleSeconds = nil
      pobj.nearbyRowFade = nil

      -- New option defaults (older SavedVariables won't have these)
      if pobj.nearbySound == nil then pobj.nearbySound = true end
      if pobj.nearbyNameFont == nil then pobj.nearbyNameFont = "Default" end
      if pobj.nearbyNameFontSize == nil then pobj.nearbyNameFontSize = 12 end
      if pobj.nearbyMaxVisibleRows == nil then pobj.nearbyMaxVisibleRows = 20 end
      -- Clamp to the available pre-created row pool (20)
      if type(pobj.nearbyMaxVisibleRows) ~= "number" then pobj.nearbyMaxVisibleRows = 20 end
      pobj.nearbyMaxVisibleRows = math.floor(pobj.nearbyMaxVisibleRows + 0.5)
      if pobj.nearbyMaxVisibleRows < 1 then pobj.nearbyMaxVisibleRows = 1 end
      if pobj.nearbyMaxVisibleRows > 20 then pobj.nearbyMaxVisibleRows = 20 end
      if pobj.disableInGoblinTowns == nil then pobj.disableInGoblinTowns = false end
      if pobj.stealthNotifyCooldownSeconds == nil then pobj.stealthNotifyCooldownSeconds = 8 end
    end
  end

  _MigrateNameData(realmDB)

  -- Optional stats pruning (prevents long-term SV bloat)
  if self.PruneStatsPlayers then
    self:PruneStatsPlayers()
  end
end

function DB:_EnsureRealmDB()
  -- Defensive init: some modules may query DB before ADDON_LOADED finishes,
  -- or in rare edge-cases where realmDB wasn't set (e.g. savedvars not ready).
  if not self.realmDB then
    if type(self.Init) == "function" then
      -- Never throw here; if Init fails we still return a safe table.
      pcall(function() self:Init() end)
    end
  end

  -- Absolute fallback: keep the addon functional even if saved vars are missing.
  if not self.realmDB then
    KillOnSightDB = KillOnSightDB or {}
    KillOnSightDB.global = KillOnSightDB.global or {}
    self.realmDB = KillOnSightDB.global
    self.realmKey = self.realmKey or "GLOBAL"
  end

  self.realmDB.data = self.realmDB.data or {}
  return self.realmDB
end

function DB:GetProfile()
  -- Returns the *active* options profile for the current character.
  -- (Per realm+faction DB; per-character assignment within that DB.)
  if self.activeProfile then return self.activeProfile end
  local realmDB = self:_EnsureRealmDB()
  return realmDB.profile or {}
end

function DB:GetData()
  local realmDB = self:_EnsureRealmDB()
  return realmDB.data
end

-- Persist insertion order to distinguish entries added within the same second.
local function NextListOrder(data)
  local maximum = tonumber(data.listAddOrder) or 0
  for _, list in ipairs({data.players, data.guilds, data.honorPlayers}) do
    for _, entry in pairs(list or {}) do
      if type(entry) == "table" then
        maximum = math.max(maximum, tonumber(entry.addedOrder) or 0)
      end
    end
  end
  data.listAddOrder = maximum + 1
  return data.listAddOrder
end

local function MakePlayerEntry(name, listType, reason, addedBy, existing, class)
  return {
    name = name,
    class = class or (existing and existing.class) or nil,
    type = listType or L.KOS,
    reason = norm(reason),
    addedBy = addedBy or ((_G.KillOnSight_Util and _G.KillOnSight_Util:UnitPlayerName("player")) or UnitName("player")) or "Unknown",
    addedAt = existing and existing.addedAt or Now(),
    addedOrder = existing and existing.addedOrder or nil,
    modifiedAt = Now(),
    lastSeenAt = existing and existing.lastSeenAt or nil,
    lastSeenZone = existing and existing.lastSeenZone or nil,
  }
end

local function MakeGuildEntry(guild, listType, reason, addedBy, existing)
  return {
    guild = guild,
    type = listType or L.GUILD_KOS,
    reason = norm(reason),
    addedBy = addedBy or ((_G.KillOnSight_Util and _G.KillOnSight_Util:UnitPlayerName("player")) or UnitName("player")) or "Unknown",
    addedAt = existing and existing.addedAt or Now(),
    addedOrder = existing and existing.addedOrder or nil,
    modifiedAt = Now(),
    lastSeenAt = existing and existing.lastSeenAt or nil,
    lastSeenZone = existing and existing.lastSeenZone or nil,
  }
end

-- Honor is a private, independent list (not part of KoS sync or alerts).
local function CanonicalPlayerKey(name)
  local util = _G.KillOnSight_Util
  return util and util:PlayerKey(name) or (type(name) == "string" and name:lower() or nil)
end

function DB:LookupHonor(name)
  name = norm(name)
  if not name then return nil end
  return (self:GetData().honorPlayers or {})[CanonicalPlayerKey(name)]
end
function DB:AddHonor(name, class)
  name = norm(name)
  if not name then return false end
  local d = self:GetData()
  d.honorPlayers = d.honorPlayers or {}
  local key = CanonicalPlayerKey(name)
  if d.honorPlayers[key] then return false end
  d.honorPlayers[key] = {name=name, class=class, addedAt=Now(), addedOrder=NextListOrder(d)}
  local N = _G.KillOnSight_Nearby
  if N and N.OnListChanged then N:OnListChanged("H", key) end
  return true
end
function DB:RemoveHonor(name)
  name = norm(name)
  if not name then return false end
  local d = self:GetData()
  d.honorPlayers = d.honorPlayers or {}
  local key = CanonicalPlayerKey(name)
  if not d.honorPlayers[key] then return false end
  d.honorPlayers[key] = nil
  local N = _G.KillOnSight_Nearby
  if N and N.OnListChanged then N:OnListChanged("H", key) end
  return true
end

function DB:AddPlayer(name, listType, reason, addedBy, class)
  name = norm(name); if not name then return false end
  local key = CanonicalPlayerKey(name)
  -- Retail/Midnight: some UI surfaces provide full names (Name-Realm) while Nearby normalizes
  -- to short names. Notify Nearby for both keys so tags update immediately either way.
  local shortKey
  if _G.Ambiguate then
    local s = Ambiguate(name, "short")
    if s and s ~= "" then
      shortKey = s:lower()
    end
  end
  local d = self:GetData()
  local existing = d.players[key]
  local entry = MakePlayerEntry(name, listType, reason, addedBy, existing, class)
  if not existing then entry.addedOrder = NextListOrder(d) end
  d.players[key] = entry
  local N = _G.KillOnSight_Nearby
  if N and N.OnListChanged then
    pcall(function() N:OnListChanged("P", key) end)
    if shortKey and shortKey ~= key then pcall(function() N:OnListChanged("P", shortKey) end) end
  end
  return true
end

function DB:RemovePlayer(name)
  name = norm(name); if not name then return false end
  local key = CanonicalPlayerKey(name)
  local shortKey
  if _G.Ambiguate then
    local s = Ambiguate(name, "short")
    if s and s ~= "" then
      shortKey = s:lower()
    end
  end
  local d = self:GetData()
  local removedKey
  if d.players[key] then
    removedKey = key
  elseif shortKey and d.players[shortKey] then
    -- Allow removing a player even if this client stored/entered Name-Realm earlier.
    removedKey = shortKey
  end

  if removedKey then
    d.players[removedKey] = nil
    local N = _G.KillOnSight_Nearby
    if N and N.OnListChanged then
      -- Notify both full and short keys so Nearby retags immediately regardless of how the entry was stored.
      pcall(function() N:OnListChanged("P", key) end)
      if shortKey and shortKey ~= key then pcall(function() N:OnListChanged("P", shortKey) end) end
    end
    return true
  end
  return false
end

function DB:AddGuild(guild, listType, reason, addedBy)
  guild = norm(guild); if not guild then return false end
  local key = guild:lower()
  local d = self:GetData()
  local existing = d.guilds[key]
  local entry = MakeGuildEntry(guild, listType, reason, addedBy, existing)
  if not existing then entry.addedOrder = NextListOrder(d) end
  d.guilds[key] = entry
  local N = _G.KillOnSight_Nearby
  if N and N.OnListChanged then pcall(function() N:OnListChanged("G", key) end) end
  return true
end

function DB:RemoveGuild(guild)
  guild = norm(guild); if not guild then return false end
  local key = guild:lower()
  local d = self:GetData()
  if d.guilds[key] then
    d.guilds[key] = nil
    local N = _G.KillOnSight_Nearby
    if N and N.OnListChanged then pcall(function() N:OnListChanged("G", key) end) end
    return true
  end
  return false
end

function DB:LookupPlayer(name)
  if not name then return nil end
  return self:GetData().players[CanonicalPlayerKey(name)]
end

function DB:LookupGuild(guild)
  if not guild or guild == "" then return nil end
  return self:GetData().guilds[guild:lower()]
end

function DB:SetPlayerClass(name, class)
  if not name or not class then return false end
  local key = CanonicalPlayerKey(name)
  local d = self:GetData()
  local e = d.players[key]
  if not e then return false end
  if e.class == class then return false end
  e.class = class
  e.modifiedAt = Now()
  return true
end

-- Update the optional note/reason attached to a KoS player.
-- This is metadata only and does not affect detection.
function DB:SetPlayerReason(name, reason)
  name = norm(name); if not name then return false end
  local key = CanonicalPlayerKey(name)
  local d = self:GetData()
  local e = d.players[key]
  if not e then return false end

  local r = norm(reason)
  if r == "" then r = nil end
  if e.reason == r then return false end

  e.reason = r
  e.modifiedAt = Now()
  return true
end
function DB:HasPlayer(name)
  return self:LookupPlayer(name) ~= nil
end

function DB:HasGuild(guild)
  return self:LookupGuild(guild) ~= nil
end
function DB:MarkSeenPlayer(name)
  local e = self:LookupPlayer(name)
  if e then
    e.lastSeenAt = Now()
    e.lastSeenZone = GetRealZoneText() or GetZoneText() or ""
  end
end

function DB:MarkSeenGuild(guild)
  local e = self:LookupGuild(guild)
  if e then
    e.lastSeenAt = Now()
    e.lastSeenZone = GetRealZoneText() or GetZoneText() or ""
  end
end

-- Enemy encounter stats (separate from KoS/Guild lists)
local function _ForeverStatsMode()
  if type(_G.RegionalUniqueNamesEnabled) ~= "function" then return false end
  local ok, enabled = pcall(_G.RegionalUniqueNamesEnabled)
  return ok and enabled == true
end

local function _StatsKey(name)
  if type(name) ~= "string" or name == "" then return nil end
  if _ForeverStatsMode() then
    -- In Forever the legacy realm separator represents a surname.
    return (name:gsub("%-", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")):lower()
  end
  return (name:match("^[^-]+") or name):lower()
end

local function _MergeStatsRecord(dst, src)
  if not dst or not src then return end
  for _, field in ipairs({"seenCount", "wins", "loses"}) do
    -- Legacy duplicates often count the same encounter twice: avoid inflation.
    dst[field] = math.max(tonumber(dst[field]) or 0, tonumber(src[field]) or 0)
  end
  local first = tonumber(src.firstSeenAt) or 0
  if first > 0 and (not dst.firstSeenAt or dst.firstSeenAt == 0 or first < dst.firstSeenAt) then dst.firstSeenAt = first end
  if (tonumber(src.lastSeenAt) or 0) > (tonumber(dst.lastSeenAt) or 0) then dst.lastSeenAt = src.lastSeenAt end
  for _, field in ipairs({"classFile", "guild", "faction", "realm", "fullName"}) do
    if (not dst[field] or dst[field] == "") and src[field] and src[field] ~= "" then dst[field] = src[field] end
  end
end

local function _ConsolidateForeverStats(data, fullKey)
  if not _ForeverStatsMode() then return end
  local stats = data.statsPlayers or {}
  -- Consolidate alternative separators and old first-name-only records.
  -- Never merge two distinct full names merely because they share a first name.
  local target = stats[fullKey]
  for oldKey, entry in pairs(stats) do
    if oldKey ~= fullKey and type(entry) == "table" then
      local canonical = _StatsKey(entry.fullName or ((entry.name or "") .. ((entry.realm and entry.realm ~= "") and (" " .. entry.realm) or "")))
      local keyCanonical = _StatsKey(oldKey)
      local exact = canonical == fullKey or keyCanonical == fullKey
      -- A first-name-only record is never proof of the same player.
      -- Merge only when both records explicitly resolve to the same full identity.
      if exact then
        if not target then target = entry; stats[fullKey] = target
        else _MergeStatsRecord(target, entry) end
        stats[oldKey] = nil
        data.statsRevision = (tonumber(data.statsRevision) or 0) + 1
      end
    end
  end
end

-- Repair historical Stats keys on demand, including records already saved before
-- a player is sighted again. Never combine two different surnames.
function DB:ConsolidateStatsDuplicates()
  if not _ForeverStatsMode() then return 0 end
  local data = self:GetData()
  local stats = data.statsPlayers or {}
  local function canonical(k, e)
    local name = type(e.fullName) == "string" and e.fullName or ""
    if name == "" then
      name = type(e.name) == "string" and e.name or ""
      if type(e.realm) == "string" and e.realm ~= "" then
        local base = name:match("^([^%s%-]+)") or name
        name = base .. " " .. e.realm
      end
    end
    local key = _StatsKey(name)
    if key and key:find(" ", 1, true) then return key end
    key = _StatsKey(k)
    if key and key:find(" ", 1, true) then return key end
    return nil
  end
  local changes = 0
  local keys = {}
  for k in pairs(stats) do keys[#keys+1] = k end
  for _, k in ipairs(keys) do
    local e = stats[k]
    if type(e) == "table" then
      local c = canonical(k, e)
      if c and c ~= k then
        if type(stats[c]) == "table" then _MergeStatsRecord(stats[c], e)
        else stats[c] = e end
        stats[k] = nil
        changes = changes + 1
      end
    end
  end
  if changes > 0 then
    data.statsRevision = (tonumber(data.statsRevision) or 0) + 1
  end
  return changes
end

-- Update / create an enemy stats record WITHOUT incrementing encounter count.
--
-- We treat "seenCount" as *encounters*, not raw detection events.
-- The encounter counter is incremented only when an encounter resolves
-- (win/loss/timeout) via StatsAddSeenEncounter().
-- Optional guid lets us backfill class for enemies where we don't yet have a unit.
function DB:NoteEnemySeen(name, classFile, guild, guid, factionGroup)
  local d = self:GetData()
  d.statsPlayers = d.statsPlayers or {}

  local key = _StatsKey(name)
  if not key then return end

  -- Safety: do not allow pets/totems/NPCs to create stats records.
  -- If we have a GUID, only accept real player GUIDs ("Player-####-########").
  if guid and guid ~= "" and not guid:match('^Player%-') then
    return
  end

  if _ForeverStatsMode() and key:find(" ", 1, true) then _ConsolidateForeverStats(d, key) end
  local now = Now()
  local e = d.statsPlayers[key]
  if not e then
    e = {
      name = _ForeverStatsMode() and key or (name:match("^[^-]+") or name),
      firstSeenAt = now,
      lastSeenAt = now,
      seenCount = 0, -- incremented by StatsAddSeenEncounter()
    }
    d.statsPlayers[key] = e
    self:_BumpStatsRevision()
  else
    if e.lastSeenAt ~= now then
      e.lastSeenAt = now
      self:_BumpStatsRevision()
    end
  end

  -- If we weren't given class, try GUID lookup (works on many clients when GUID is resolvable).
  if (not classFile or classFile == "") and guid and guid ~= "" and GetPlayerInfoByGUID then
    local _, cls = GetPlayerInfoByGUID(guid)
    classFile = cls
  end

  if classFile and classFile ~= "" then
    local cf = _NormalizeClassForDB(classFile) or classFile
    if e.classFile ~= cf then
      e.classFile = cf
      self:_BumpStatsRevision()
    end
  end
  if guild and guild ~= "" then
    if e.guild ~= guild then
      e.guild = guild
      self:_BumpStatsRevision()
    end
  end

  -- Track realm/fullName for cross-realm identification (do not depend on guild being known)
  if name and name ~= "" then
    local base = name:match("^[^-]+") or name
    local realm = name:match("^[^-]+%-(.+)$") or ""
    if _ForeverStatsMode() then
      base = key:match("^(%S+)") or key
      realm = key:match("^%S+ (.+)$") or ""
    end
    if e.name ~= base then e.name = base; self:_BumpStatsRevision() end
    if e.realm ~= realm then e.realm = realm; self:_BumpStatsRevision() end
    if e.fullName ~= name then e.fullName = name; self:_BumpStatsRevision() end
  end


if factionGroup and factionGroup ~= "" then
  if e.faction ~= factionGroup then
    e.faction = factionGroup
    self:_BumpStatsRevision()
  end
end
end

-- Increment "seenCount" once per encounter resolution (win/loss/timeout).
function DB:StatsAddSeenEncounter(name)
  local d = self:GetData(); d.statsPlayers = d.statsPlayers or {}
  local key = _StatsKey(name)
  if not key then return end
  if _ForeverStatsMode() and key:find(" ", 1, true) then _ConsolidateForeverStats(d, key) end
  local now = Now()
  local e = d.statsPlayers[key]
  if not e then
    e = { name = name:match("^[^-]+") or name, firstSeenAt = now, lastSeenAt = now, seenCount = 0 }
    d.statsPlayers[key] = e
    self:_BumpStatsRevision()
  end
  e.lastSeenAt = now
  e.seenCount = (tonumber(e.seenCount or 0) or 0) + 1
  self:_BumpStatsRevision()
end

function DB:StatsAddWin(name)
  local d = self:GetData(); d.statsPlayers = d.statsPlayers or {}
  local key = _StatsKey(name)
  if not key then return end
  local e = d.statsPlayers[key]
  if not e then
    e = { name = name:match("^[^-]+") or name, firstSeenAt = Now(), lastSeenAt = Now(), seenCount = 0 }
    d.statsPlayers[key] = e
    self:_BumpStatsRevision()
  end
  e.wins = (tonumber(e.wins or 0) or 0) + 1
  self:_BumpStatsRevision()
end

function DB:StatsAddLoss(name)
  local d = self:GetData(); d.statsPlayers = d.statsPlayers or {}
  local key = _StatsKey(name)
  if not key then return end
  local e = d.statsPlayers[key]
  if not e then
    e = { name = name:match("^[^-]+") or name, firstSeenAt = Now(), lastSeenAt = Now(), seenCount = 0 }
    d.statsPlayers[key] = e
    self:_BumpStatsRevision()
  end
  e.loses = (tonumber(e.loses or 0) or 0) + 1
  self:_BumpStatsRevision()
end
-- Return stats record for a player (or nil). Useful for pulling cached faction/class/guild.
function DB:StatsGetPlayer(name)
  local d = self:GetData(); d.statsPlayers = d.statsPlayers or {}
  local key = _StatsKey(name)
  if not key then return nil end
  return d.statsPlayers[key]
end

-- Returns true if an enemy stats record already exists for this name.
-- Useful when callers want to *enrich* existing records without creating new ones
-- (e.g. deferred guild resolution), so "Reset Stats" stays a true wipe.
function DB:HasStatsPlayer(name)
  local d = self:GetData(); d.statsPlayers = d.statsPlayers or {}
  local key = _StatsKey(name)
  if not key then return false end
  return d.statsPlayers[key] ~= nil
end

function DB:AddLastAttacker(name, guid, zone, guild, classFile)
  if not name or name == "" then return end
  local d = self:GetData()
  d.lastAttackers = d.lastAttackers or {}
  local keyName = CanonicalPlayerKey(name)
  local keyGUID = (guid and guid ~= "") and guid or nil


  -- Resolve/persist class immediately when possible (prevents "late recolor" after login)
  local class = _NormalizeClassForDB(classFile)
  if not class and keyGUID and GetPlayerInfoByGUID then
    local _, cls = GetPlayerInfoByGUID(keyGUID)
    class = _NormalizeClassForDB(cls)
  end
  -- remove existing entry (prefer GUID match when available)
  for j = #d.lastAttackers, 1, -1 do
    local e = d.lastAttackers[j]
    if e then
      if keyGUID and e.guid == keyGUID then
        table.remove(d.lastAttackers, j)
      elseif (not keyGUID) and e.name and CanonicalPlayerKey(e.name) == keyName then
        table.remove(d.lastAttackers, j)
      end
    end
  end

  table.insert(d.lastAttackers, 1, { name = name,
        class = class, guid = guid or "", zone = zone or "", guild = guild or "" })

  -- Keep enemy stats metadata in sync with what we already know for attackers.
  -- (Encounter counting is handled in Core.lua; this only refreshes metadata.)
  if self.NoteEnemySeen then
    self:NoteEnemySeen(name, class, guild, guid)
  end

  -- cap
	while #d.lastAttackers > 200 do
    table.remove(d.lastAttackers)
  end
end

function DB:UpdateLastAttackerGuild(name, guild)
  if (not guild) or guild == "" then return end
  local d = self:GetData()
  d.lastAttackers = d.lastAttackers or {}

  local keyName = (name and name ~= "") and CanonicalPlayerKey(name) or nil
  local keyGUID = (name and name:find("^Player%-")) and name or nil
  -- If caller passed a GUID in the first arg, match by GUID; otherwise match by name.
  for j = 1, #d.lastAttackers do
    local e = d.lastAttackers[j]
    if e then
      if keyGUID and e.guid == keyGUID then
        e.guild = guild
        if self.NoteEnemySeen then
          self:NoteEnemySeen(e.name or name, e.class, guild, e.guid)
        end
        return
      elseif (not keyGUID) and keyName and e.name and CanonicalPlayerKey(e.name) == keyName then
        e.guild = guild
        if self.NoteEnemySeen then
          self:NoteEnemySeen(e.name or name, e.class, guild, e.guid)
        end
        return
      end
    end
  end
end

function DB:UpdateLastAttackerGuildByGUID(guid, guild)
  if not guid or guid == "" then return end
  if not guild or guild == "" then return end
  local d = self:GetData()
  d.lastAttackers = d.lastAttackers or {}
  for i=1,#d.lastAttackers do
    local e = d.lastAttackers[i]
    if e and e.guid == guid then
      e.guild = guild
      if self.NoteEnemySeen then
        self:NoteEnemySeen(e.name, e.class, guild, e.guid)
      end
      return true
    end
  end
end

function DB:GetLastAttackers()
  local d = self:GetData()
  d.lastAttackers = d.lastAttackers or {}
  return d.lastAttackers
end

function DB:ClearLastAttackers()
  local d = self:GetData()
  d.lastAttackers = {}
end


function DB:ClearStatsPlayers()
  local d = self:GetData()
  d.statsPlayers = {}
  d.lastAttackers = {}
  self:_BumpStatsRevision()
end

function DB:PruneStatsPlayers()
  local p = self:GetProfile()
  if not p.statsPruneEnabled then return 0 end

  local maxDays = tonumber(p.statsPruneMaxDays or 0) or 0
  local maxEntries = tonumber(p.statsPruneMaxEntries or 0) or 0

  local d = self:GetData()
  d.statsPlayers = d.statsPlayers or {}
  local stats = d.statsPlayers
  local now = Now()
  local removed = 0

  -- 1) Drop entries older than maxDays (based on lastSeenAt)
  if maxDays and maxDays > 0 then
    local cutoff = now - (maxDays * 86400)
    for k,e in pairs(stats) do
      local last = tonumber(e and e.lastSeenAt or 0) or 0
      if last > 0 and last < cutoff then
        stats[k] = nil
        removed = removed + 1
      end
    end
  end

  -- 2) Hard cap by removing oldest lastSeenAt
  if maxEntries and maxEntries > 0 then
    local count = 0
    for _ in pairs(stats) do count = count + 1 end
    if count > maxEntries then
      local keys = {}
      for k,e in pairs(stats) do
        keys[#keys+1] = { k=k, last=tonumber(e and e.lastSeenAt or 0) or 0 }
      end
      table.sort(keys, function(a,b) return (a.last or 0) < (b.last or 0) end)
      local toDrop = count - maxEntries
      for i=1, toDrop do
        if keys[i] and keys[i].k then
          stats[keys[i].k] = nil
          removed = removed + 1
        end
      end
    end
  end

  if removed > 0 then
    self:_BumpStatsRevision()
  end
  return removed
end


-- ===== Profiles API (options only) =====

function DB:GetActiveProfileName()
  return self.activeProfileName or "Default"
end

function DB:ListProfiles()
  local r = (self.realmDB or {})
  local p = r.profiles or {}
  local names = {}
  for k,v in pairs(p) do
    if type(v) == "table" then names[#names+1] = k end
  end
  table.sort(names)
  return names
end

local function _UniqueProfileName(realmDB, base)
  base = base or "Profile"
  local n = 1
  local name = base
  while realmDB.profiles[name] do
    n = n + 1
    name = string.format("%s %d", base, n)
  end
  return name
end

function DB:CreateProfile(name, copyFrom)
  local r = self.realmDB
  if not r then return nil end
  r.profiles = r.profiles or {}
  if not name or name == "" then
    name = _UniqueProfileName(r, "Profile")
  end
  if r.profiles[name] then
    name = _UniqueProfileName(r, name)
  end

  local src = (copyFrom and r.profiles[copyFrom]) or self:GetProfile() or {}
  local dst = {}
  DeepCopy(dst, DEFAULTS.profile)
  DeepCopy(dst, src)
  dst.nearbyMinimal = true
  r.profiles[name] = dst
  return name
end

function DB:ResetProfile(name)
  local r = self.realmDB
  if not r or not r.profiles then return end
  name = name or self:GetActiveProfileName()
  if not r.profiles[name] then return end
  r.profiles[name] = {}
  DeepCopy(r.profiles[name], DEFAULTS.profile)
  r.profiles[name].nearbyMinimal = true
  if self.activeProfileName == name then
    self.activeProfile = r.profiles[name]
  end
end

function DB:DeleteProfile(name)
  local r = self.realmDB
  if not r or not r.profiles then return false end
  name = name or self:GetActiveProfileName()
  if name == "Default" then return false end
  if not r.profiles[name] then return false end

  r.profiles[name] = nil

  -- Reassign any characters using this profile back to Default
  r.profileNameByChar = r.profileNameByChar or {}
  for ck,pn in pairs(r.profileNameByChar) do
    if pn == name then r.profileNameByChar[ck] = "Default" end
  end

  if self.activeProfileName == name then
    self:SetActiveProfileName("Default")
  end
  return true
end
function DB:RenameProfile(oldName, newName)
  local r = self.realmDB
  if not r or not r.profiles then return nil, "notready" end
  oldName = oldName or self:GetActiveProfileName()
  if oldName == "Default" then return nil, "default" end
  if not r.profiles[oldName] then return nil, "notfound" end

  newName = (newName or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if newName == "" then return nil, "empty" end
  if newName == oldName then return oldName end
  if r.profiles[newName] then return nil, "exists" end

  r.profiles[newName] = r.profiles[oldName]
  r.profiles[oldName] = nil

  -- Update any characters using this profile
  r.profileNameByChar = r.profileNameByChar or {}
  for ck,pn in pairs(r.profileNameByChar) do
    if pn == oldName then r.profileNameByChar[ck] = newName end
  end

  if self.activeProfileName == oldName then
    self.activeProfileName = newName
    self.activeProfile = r.profiles[newName]
  end

  return newName
end


function DB:SetActiveProfileName(name)
  local r = self.realmDB
  if not r or not r.profiles then return false end
  if not name or not r.profiles[name] then name = "Default" end
  local ck = CharKey()
  r.profileNameByChar = r.profileNameByChar or {}
  r.profileNameByChar[ck] = name
  self.activeProfileName = name
  self.activeProfile = r.profiles[name]

  -- Ensure new defaults exist (covers profile created on older version)
  if type(self.activeProfile) == "table" then
    DeepCopy(self.activeProfile, DEFAULTS.profile)
    self.activeProfile.nearbyMinimal = true
  end
  return true
end


KillOnSight_DB = DB
