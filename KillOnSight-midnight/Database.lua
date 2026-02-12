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



-- Change log retention (for diff-based sync).
-- Keeping this bounded prevents SavedVariables bloat and slows downs over long play sessions.
local CHANGELOG_KEEP = 800      -- how many recent changes to retain
local CHANGELOG_PRUNE_EVERY = 25 -- prune every N local changes


local function Now() return time() end

local function RealmKey()
  -- Account-wide shared DB across all realms/factions/characters.
  return "GLOBAL"
end

local function CharKey()
  local name = UnitName("player") or "Unknown"
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
    changeSeq = 0,         -- monotonically increasing change id
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

  -- prune very old change log if it grew huge
  local data = realmDB.data
  local changes = data.changes or {}
  local count = 0
  for _ in pairs(changes) do count = count + 1 end
  if count > (CHANGELOG_KEEP + 200) then
    -- keep last ~CHANGELOG_KEEP
    local keys = {}
    for k in pairs(changes) do keys[#keys+1] = k end
    table.sort(keys)
    for i=1, (#keys-CHANGELOG_KEEP) do
      changes[keys[i]] = nil
    end
    data.oldestSeq = keys[#keys-CHANGELOG_KEEP+1] or 0
  end

  -- Optional stats pruning (prevents long-term SV bloat)
  if self.PruneStatsPlayers then
    self:PruneStatsPlayers()
  end
end

function DB:GetProfile()
  -- Returns the *active* options profile for the current character.
  -- (Per realm+faction DB; per-character assignment within that DB.)
  return self.activeProfile or (self.realmDB and self.realmDB.profile) or {}
end

function DB:GetData() return self.realmDB.data end

-- ------------------------------------------------------------
-- Profiles (Options presets)
-- ------------------------------------------------------------

function DB:ListProfiles()
  local t = {}
  local profiles = (self.realmDB and self.realmDB.profiles) or {}
  for name, pobj in pairs(profiles) do
    if type(name) == "string" and type(pobj) == "table" then
      t[#t+1] = name
    end
  end
  table.sort(t)
  return t
end

function DB:GetActiveProfileName()
  return self.activeProfileName or "Default"
end

function DB:SetActiveProfileName(name)
  if not self.realmDB then return false end
  if type(name) ~= "string" or name == "" then return false end
  if not self.realmDB.profiles or not self.realmDB.profiles[name] then return false end

  local ck = CharKey()
  self.realmDB.profileNameByChar = self.realmDB.profileNameByChar or {}
  self.realmDB.profileNameByChar[ck] = name

  self.activeProfileName = name
  self.activeProfile = self.realmDB.profiles[name]
  return true
end

local function _NextProfileName(profiles, base)
  base = base or "Profile"
  if not profiles[base] then return base end
  local i = 2
  while profiles[(base .. " " .. i)] do i = i + 1 end
  return (base .. " " .. i)
end

function DB:CreateProfile(name, copyFrom)
  if not self.realmDB then return nil end
  self.realmDB.profiles = self.realmDB.profiles or {}

  if type(name) ~= "string" or name == "" then
    name = _NextProfileName(self.realmDB.profiles, "Profile")
  end
  if self.realmDB.profiles[name] then
    name = _NextProfileName(self.realmDB.profiles, name)
  end

  local src = nil
  if type(copyFrom) == "string" then
    src = self.realmDB.profiles[copyFrom]
  elseif type(copyFrom) == "table" then
    src = copyFrom
  end

  local dst = {}
  if type(src) == "table" then
    -- full copy (including user choices)
    for k,v in pairs(src) do
      if type(v) == "table" then
        local sub = {}
        -- shallow copy tables (nested config tables are simple)
        for kk,vv in pairs(v) do sub[kk] = vv end
        dst[k] = sub
      else
        dst[k] = v
      end
    end
  end
  -- ensure any new defaults exist
  DeepCopy(dst, DEFAULTS.profile)
  dst.nearbyMinimal = true

  self.realmDB.profiles[name] = dst
  return name
end

function DB:ResetProfile(name)
  if not self.realmDB or not self.realmDB.profiles then return false end
  if type(name) ~= "string" or not self.realmDB.profiles[name] then return false end
  local dst = self.realmDB.profiles[name]
  for k in pairs(dst) do dst[k] = nil end
  DeepCopy(dst, DEFAULTS.profile)
  dst.nearbyMinimal = true
  return true
end

function DB:DeleteProfile(name)
  if not self.realmDB or not self.realmDB.profiles then return false end
  if type(name) ~= "string" or name == "" then return false end
  if name == "Default" then return false end
  if not self.realmDB.profiles[name] then return false end

  self.realmDB.profiles[name] = nil

  -- Reassign any chars that used this profile back to Default
  self.realmDB.profileNameByChar = self.realmDB.profileNameByChar or {}
  for ck, pn in pairs(self.realmDB.profileNameByChar) do
    if pn == name then
      self.realmDB.profileNameByChar[ck] = "Default"
    end
  end

  -- If current char was using it, fall back now
  if self.activeProfileName == name then
    self:SetActiveProfileName("Default")
  end

  return true
end


function DB:GetOldestChangeSeq()
  local d = self:GetData()
  if d.oldestSeq then return d.oldestSeq end
  local minSeq = nil
  local changes = d.changes or {}
  for s in pairs(changes) do
    s = tonumber(s)
    if s and (not minSeq or s < minSeq) then minSeq = s end
  end
  d.oldestSeq = minSeq or 0
  return d.oldestSeq
end

function DB:PruneChangeLog()
  local d = self:GetData()
  d.changes = d.changes or {}
  local seq = d.changeSeq or 0
  if seq <= CHANGELOG_KEEP then
    d.oldestSeq = d.oldestSeq or 0
    return
  end

  local cutoff = seq - CHANGELOG_KEEP
  for s in pairs(d.changes) do
    local n = tonumber(s)
    if n and n <= cutoff then
      d.changes[s] = nil
    end
  end
  -- Record an approximate oldest seq so Sync can detect "too far behind".
  d.oldestSeq = cutoff + 1
end

function DB:_IncRevision()
  local d = self:GetData()
  d.revision = (d.revision or 0) + 1
  return d.revision
end

function DB:_PushChange(op, kind, key, entry)
  local d = self:GetData()
  d.changeSeq = (d.changeSeq or 0) + 1
  local seq = d.changeSeq
  d.changes[seq] = { op=op, kind=kind, key=key, entry=entry, rev=d.revision }

  -- Keep the change log bounded so diff-sync stays fast and SavedVariables don't balloon.
  if (seq % CHANGELOG_PRUNE_EVERY) == 0 then
    self:PruneChangeLog()
  end
end

local function MakePlayerEntry(name, listType, reason, addedBy, existing, class)
  return {
    name = name,
    class = class or (existing and existing.class) or nil,
    type = listType or L.KOS,
    reason = norm(reason),
    addedBy = addedBy or UnitName("player") or "Unknown",
    addedAt = existing and existing.addedAt or Now(),
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
    addedBy = addedBy or UnitName("player") or "Unknown",
    addedAt = existing and existing.addedAt or Now(),
    modifiedAt = Now(),
    lastSeenAt = existing and existing.lastSeenAt or nil,
    lastSeenZone = existing and existing.lastSeenZone or nil,
  }
end

function DB:AddPlayer(name, listType, reason, addedBy, class)
  name = norm(name); if not name then return false end
  local key = name:lower()
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
  d.players[key] = entry
  self:_IncRevision()
  self:_PushChange("upsert","P",key,entry)
  local N = _G.KillOnSight_Nearby
  if N and N.OnListChanged then
    pcall(function() N:OnListChanged("P", key) end)
    if shortKey and shortKey ~= key then pcall(function() N:OnListChanged("P", shortKey) end) end
  end
  return true
end

function DB:RemovePlayer(name)
  name = norm(name); if not name then return false end
  local key = name:lower()
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
    self:_IncRevision()
    self:_PushChange("delete","P",removedKey,nil)
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
  d.guilds[key] = entry
  self:_IncRevision()
  self:_PushChange("upsert","G",key,entry)
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
    self:_IncRevision()
    self:_PushChange("delete","G",key,nil)
    local N = _G.KillOnSight_Nearby
    if N and N.OnListChanged then pcall(function() N:OnListChanged("G", key) end) end
    return true
  end
  return false
end

function DB:LookupPlayer(name)
  if not name then return nil end
  return self:GetData().players[name:lower()]
end

function DB:LookupGuild(guild)
  if not guild or guild == "" then return nil end
  return self:GetData().guilds[guild:lower()]
end

function DB:SetPlayerClass(name, class)
  if not name or not class then return false end
  local key = name:lower()
  local d = self:GetData()
  local e = d.players[key]
  if not e then return false end
  if e.class == class then return false end
  e.class = class
  e.modifiedAt = Now()
  self:_IncRevision()
  self:_PushChange("upsert","P",key,e)
  return true
end

-- Update the optional note/reason attached to a KoS player.
-- This is metadata only and does not affect detection.
function DB:SetPlayerReason(name, reason)
  name = norm(name); if not name then return false end
  local key = name:lower()
  local d = self:GetData()
  local e = d.players[key]
  if not e then return false end

  local r = norm(reason)
  if r == "" then r = nil end
  if e.reason == r then return false end

  e.reason = r
  e.modifiedAt = Now()
  self:_IncRevision()
  self:_PushChange("upsert","P",key,e)
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

-- Enemy encounter stats (separate from KoS/Guild lists; not synced)
local function _StatsKey(name)
  if not name or name == "" then return nil end
  return name:match("^[^-]+") and (name:match("^[^-]+") or name):lower() or name:lower()
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

  local now = Now()
  local e = d.statsPlayers[key]
  if not e then
    e = {
      name = name:match("^[^-]+") or name,
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

-- Apply changes received from sync
function DB:ApplyRemoteChange(sender, change)
  local d = self:GetData()
  if not change or not change.kind or not change.key then return end

  if change.kind == "P" then
    if change.op == "delete" then
      d.players[change.key] = nil
    elseif change.op == "upsert" and change.entry then
      d.players[change.key] = change.entry
    end
  elseif change.kind == "G" then
    if change.op == "delete" then
      d.guilds[change.key] = nil
    elseif change.op == "upsert" and change.entry then
      d.guilds[change.key] = change.entry
    end
  end

  -- keep our revision monotonic
  d.revision = math.max(tonumber(d.revision or 0), tonumber(change.rev or 0))

  -- record remote changes locally so we can forward them to peers
  d.changes = d.changes or {}
  d.changeSeq = (d.changeSeq or 0) + 1
  local seq = d.changeSeq
  d.changes[seq] = { op = change.op, kind = change.kind, key = change.key, entry = change.entry, rev = change.rev }
  if (seq % CHANGELOG_PRUNE_EVERY) == 0 then
    self:PruneChangeLog()
  end
end


function DB:AddLastAttacker(name, guid, zone, guild, classFile)
  if not name or name == "" then return end
  local d = self:GetData()
  d.lastAttackers = d.lastAttackers or {}
  local keyName = name:lower()
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
      elseif (not keyGUID) and e.name and e.name:lower() == keyName then
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

  local keyName = (name and name ~= "") and name:lower() or nil
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
      elseif (not keyGUID) and keyName and e.name and e.name:lower() == keyName then
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
  local p = (self.realmDB and self.realmDB.profile) or {}
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
