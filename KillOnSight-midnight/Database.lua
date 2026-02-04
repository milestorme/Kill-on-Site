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
  local realm = GetRealmName() or "UnknownRealm"
  local faction = UnitFactionGroup("player") or "Neutral"
  return realm .. "-" .. faction
end

local DEFAULTS = {
  profile = {
    enableSound = true,
    enableScreenFlash = true,
    throttleSeconds = 12,
    notifyInInstances = true,
    printToChat = true,
    minimap = { hide=false, minimapPos=220 },
    showNearbyFrame = true,
    nearbyFrameLocked = false,
    nearbyFrame = { point="CENTER", relPoint="CENTER", x=280, y=80, scale=0.80 },
    nearbyAlpha = 0.80,
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
-- Stealth detection
stealthDetectEnabled = true,
stealthDetectChat = true,
stealthDetectSound = true,
stealthDetectCenterWarning = true,
stealthDetectAddToNearby = true,
stealthWarningHoldSeconds = 6.0,
stealthWarningFadeSeconds = 1.2,

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
  KillOnSightDB.realms = KillOnSightDB.realms or {}
  local key = RealmKey()
  KillOnSightDB.realms[key] = KillOnSightDB.realms[key] or {}
  local realmDB = KillOnSightDB.realms[key]
  DeepCopy(realmDB, DEFAULTS)
  self.realmKey = key
  self.realmDB = realmDB

  -- Force ultra-minimal Nearby window (no option to change)
  realmDB.profile.nearbyMinimal = true

  -- Clean up legacy/dead config keys (kept for backward compatibility in old SVs)
  realmDB.profile.guildAlertCooldownSeconds = nil
  realmDB.profile.kosAlertCooldownSeconds = nil
  realmDB.profile.activityThrottleSeconds = nil
  realmDB.profile.nearbyRowFade = nil

  -- New option defaults (older SavedVariables won't have these)
  if realmDB.profile.nearbySound == nil then realmDB.profile.nearbySound = true end
  if realmDB.profile.nearbyNameFont == nil then realmDB.profile.nearbyNameFont = "Default" end
  if realmDB.profile.nearbyNameFontSize == nil then realmDB.profile.nearbyNameFontSize = 12 end
  if realmDB.profile.disableInGoblinTowns == nil then realmDB.profile.disableInGoblinTowns = false end

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

function DB:GetProfile() return self.realmDB.profile end
function DB:GetData() return self.realmDB.data end

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
function DB:NoteEnemySeen(name, classFile, guild, guid)
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


KillOnSight_DB = DB
