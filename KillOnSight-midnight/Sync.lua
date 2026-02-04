-- Sync.lua
-- Diff-based sync using changeSeq/revision.
local ADDON_NAME = ...
local L = KillOnSight_L
local DB = KillOnSight_DB
local Notifier = KillOnSight_Notifier

local Sync = {}

local SYNC_COOLDOWN = 60
local nextSyncAllowedAt = 0
local PREFIX = "KOS2"
local ADDON_VER = "3.2.2"

-- Safety limits: if a peer is too far behind (or diff is huge), send a compact snapshot instead.
local MAX_DIFF_CHANGES = 600
local MAX_DIFF_BYTES = 28000 -- approx, across serialized lines before chunking


local peers = {} -- [sender] = { theirRev=0, theirSeq=0, lastHelloAt=0 }

local function CanSync() return IsInGuild() or IsInGroup() end
local function BestChannel()
  if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
  if IsInRaid() then return "RAID" end
  if IsInGroup() then return "PARTY" end
  if IsInGuild() then return "GUILD" end
  return nil
end

local function Send(channel, msg)
  C_ChatInfo.SendAddonMessage(PREFIX, msg, channel)
end

local function Escape(s)
  s = s or ""
  s = s:gsub("|", "/")
  s = s:gsub("\n"," ")
  return s
end
local function Unescape(s)
  s = s or ""
  s = s:gsub("/", "|")
  return s
end

local function SerializeChange(ch)
  -- CH|seq|rev|op|kind|key|payload
  local payload = ""
  if ch.op == "upsert" and ch.entry then
    if ch.kind == "P" then
      payload = table.concat({
        "name="..Escape(ch.entry.name or ""),
        "type="..Escape(ch.entry.type or ""),
        "reason="..Escape(ch.entry.reason or ""),
        "addedBy="..Escape(ch.entry.addedBy or ""),
        "addedAt="..tostring(ch.entry.addedAt or 0),
        "modifiedAt="..tostring(ch.entry.modifiedAt or 0),
        "lastSeenAt="..tostring(ch.entry.lastSeenAt or 0),
        "lastSeenZone="..Escape(ch.entry.lastSeenZone or ""),
      }, "&")
    elseif ch.kind == "G" then
      payload = table.concat({
        "guild="..Escape(ch.entry.guild or ""),
        "type="..Escape(ch.entry.type or ""),
        "reason="..Escape(ch.entry.reason or ""),
        "addedBy="..Escape(ch.entry.addedBy or ""),
        "addedAt="..tostring(ch.entry.addedAt or 0),
        "modifiedAt="..tostring(ch.entry.modifiedAt or 0),
        "lastSeenAt="..tostring(ch.entry.lastSeenAt or 0),
        "lastSeenZone="..Escape(ch.entry.lastSeenZone or ""),
      }, "&")
    end
  end
  return table.concat({
    "CH",
    tostring(ch.seq or 0),
    tostring(ch.rev or 0),
    Escape(ch.op or ""),
    Escape(ch.kind or ""),
    Escape(ch.key or ""),
    payload
  }, "|")
end

local function ParseKV(payload)
  local t = {}
  for pair in (payload or ""):gmatch("([^&]+)") do
    local k,v = pair:match("([^=]+)=(.*)")
    if k then
      t[k] = Unescape(v)
    end
  end
  return t
end

local function DeserializeChange(msg)
  local _, seq, rev, op, kind, key, payload = strsplit("|", msg, 7)
  if not seq or not kind or not key then return nil end
  local ch = {
    seq = tonumber(seq) or 0,
    rev = tonumber(rev) or 0,
    op = Unescape(op),
    kind = Unescape(kind),
    key = Unescape(key),
  }
  if ch.op == "upsert" and payload and payload ~= "" then
    local kv = ParseKV(payload)
    if ch.kind == "P" then
      ch.entry = {
        name = kv.name,
        type = kv.type,
        reason = kv.reason ~= "" and kv.reason or nil,
        addedBy = kv.addedBy,
        addedAt = tonumber(kv.addedAt) or 0,
        modifiedAt = tonumber(kv.modifiedAt) or 0,
        lastSeenAt = (tonumber(kv.lastSeenAt) or 0),
        lastSeenZone = kv.lastSeenZone,
      }
      if ch.entry.lastSeenAt == 0 then ch.entry.lastSeenAt = nil end
      if ch.entry.lastSeenZone == "" then ch.entry.lastSeenZone = nil end
    elseif ch.kind == "G" then
      ch.entry = {
        guild = kv.guild,
        type = kv.type,
        reason = kv.reason ~= "" and kv.reason or nil,
        addedBy = kv.addedBy,
        addedAt = tonumber(kv.addedAt) or 0,
        modifiedAt = tonumber(kv.modifiedAt) or 0,
        lastSeenAt = (tonumber(kv.lastSeenAt) or 0),
        lastSeenZone = kv.lastSeenZone,
      }
      if ch.entry.lastSeenAt == 0 then ch.entry.lastSeenAt = nil end
      if ch.entry.lastSeenZone == "" then ch.entry.lastSeenZone = nil end
    end
  end
  return ch
end

local function SendChunks(channel, lines)
  local buf = ""
  for _,line in ipairs(lines) do
    if #buf + #line + 1 > 220 then
      Send(channel, "D|"..buf)
      buf = ""
    end
    buf = buf .. line .. "\n"
  end
  if buf ~= "" then
    Send(channel, "D|"..buf)
  end
end

function Sync:Init()
  C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
end

function Sync:Hello()
  if not CanSync() then
    Notifier:Chat(L.SYNC_DISABLED); return
  end
  local ch = BestChannel()
  if not ch then Notifier:Chat(L.SYNC_DISABLED); return end
  local d = DB:GetData()
  Send(ch, ("HELLO|%s|%s|%s"):format(tostring(d.revision or 0), tostring(d.changeSeq or 0), ADDON_VER))
end

function Sync:RequestDiff()
  local now = GetTime and GetTime() or 0
  if now < (nextSyncAllowedAt or 0) then
    local remain = math.ceil((nextSyncAllowedAt or 0) - now)
    Notifier:Chat((L.SYNC_COOLDOWN or "Sync is on cooldown: %ds remaining."):format(remain))
    return
  end
  if not CanSync() then
    Notifier:Chat(L.SYNC_DISABLED); return
  end
  local ch = BestChannel()
  if not ch then Notifier:Chat(L.SYNC_DISABLED); return end
  local d = DB:GetData()
  Send(ch, ("REQ|%s|%s"):format(tostring(d.revision or 0), tostring(d.changeSeq or 0)))
  nextSyncAllowedAt = (GetTime and GetTime() or 0) + (SYNC_COOLDOWN or 60)
  Notifier:Chat(L.SYNC_SENT)
end

local rx = {} -- [sender] = { lines={} }

local function ApplyLines(sender, lines)
  local applied = 0
  for _,line in ipairs(lines) do
    if line:match("^CH|") then
      local ch = DeserializeChange(line)
      if ch then
        DB:ApplyRemoteChange(sender, ch)
        applied = applied + 1
      end
    end
  end
  Notifier:Chat(string.format(L.SYNC_RECEIVED, sender))
  Notifier:Chat(("Applied %d changes."):format(applied))
  Notifier:Chat(L.SYNC_DONE)
  if KillOnSight_GUI and KillOnSight_GUI.RefreshAll then
    KillOnSight_GUI:RefreshAll()
  end
end

local function BuildDiffSince(seq)
  local d = DB:GetData()
  local out = {}
  local changes = d.changes or {}
  for s, ch in pairs(changes) do
    if tonumber(s) and tonumber(s) > seq then
      out[#out+1] = { seq=tonumber(s), rev=ch.rev, op=ch.op, kind=ch.kind, key=ch.key, entry=ch.entry }
    end
  end
  table.sort(out, function(a,b) return a.seq < b.seq end)
  return out
end

local function GetOldestSeq()
  if DB and DB.GetOldestChangeSeq then
    return DB:GetOldestChangeSeq() or 0
  end
  -- fallback: compute from table
  local d = DB:GetData()
  local minSeq = nil
  local changes = d.changes or {}
  for s in pairs(changes) do
    s = tonumber(s)
    if s and (not minSeq or s < minSeq) then minSeq = s end
  end
  return minSeq or 0
end

local function BuildSnapshotLines()
  local d = DB:GetData()
  local lines = {}

  for key, entry in pairs(d.players or {}) do
    lines[#lines+1] = SerializeChange({ op="upsert", kind="P", key=key, entry=entry, rev=d.revision })
  end
  for key, entry in pairs(d.guilds or {}) do
    lines[#lines+1] = SerializeChange({ op="upsert", kind="G", key=key, entry=entry, rev=d.revision })
  end

  return lines
end

function Sync:OnMessage(prefix, msg, channel, sender)
  if prefix ~= PREFIX then return end
  if sender == UnitName("player") then return end

  local cmd, rest = strsplit("|", msg, 2)
  cmd = cmd or ""

  if cmd == "HELLO" then
    local theirRev, theirSeq, ver = strsplit("|", rest or "", 3)
    peers[sender] = peers[sender] or {}
    peers[sender].theirRev = tonumber(theirRev) or 0
    peers[sender].theirSeq = tonumber(theirSeq) or 0
    peers[sender].ver = ver
    return
  end

  if cmd == "RESET" then
    -- Sender is providing a full snapshot; wipe local tables so state matches exactly.
    local d = DB:GetData()
    d.players = {}
    d.guilds  = {}
    rx[sender] = nil
    return
  end

  if cmd == "REQ" then
    if not CanSync() then return end
    local theirRev, theirSeq = strsplit("|", rest or "", 2)
    theirSeq = tonumber(theirSeq) or 0
    local ch = BestChannel()
    if not ch then return end

    local d = DB:GetData()
    local oldest = GetOldestSeq() or 0

    -- If they've requested a seq older than what we still retain, we cannot build a correct diff.
    -- Send a snapshot with a RESET so their DB matches ours exactly.
    local useSnapshot = (theirSeq < (oldest - 1))

    local diff = nil
    local lines = nil

    if not useSnapshot then
      diff = BuildDiffSince(theirSeq)
      lines = {}
      local totalBytes = 0
      for _,c in ipairs(diff) do
        local s = SerializeChange(c)
        totalBytes = totalBytes + #s
        lines[#lines+1] = s
        if #lines > MAX_DIFF_CHANGES or totalBytes > MAX_DIFF_BYTES then
          useSnapshot = true
          break
        end
      end
    end

    if useSnapshot then
      -- Reset and send a snapshot (upserts for all current entries).
      Send(ch, ("RESET|%s|%s"):format(tostring(d.revision or 0), tostring(d.changeSeq or 0)))
      lines = BuildSnapshotLines()
    end

    if (not lines) or #lines == 0 then
      -- nothing to send
      Send(ch, "END|0")
      return
    end

    SendChunks(ch, lines)
    Send(ch, ("END|%s"):format(tostring(d.changeSeq or 0)))
    return
  end

  if cmd == "D" then
    rx[sender] = rx[sender] or { lines = {} }
    local payload = rest or ""
    for line in payload:gmatch("([^\n]+)") do
      if line and line ~= "" then
        table.insert(rx[sender].lines, line)
      end
    end
    return
  end

  if cmd == "END" then
    local bucket = rx[sender]
    if bucket and bucket.lines then
      ApplyLines(sender, bucket.lines)
    end
    rx[sender] = nil
    return
  end
end

KillOnSight_Sync = Sync
