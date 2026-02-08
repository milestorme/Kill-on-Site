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
local ADDON_VER = "3.1.7"

-- Safety limits: if a peer is too far behind (or diff is huge), send a compact snapshot instead.
local MAX_DIFF_CHANGES = 600
local MAX_DIFF_BYTES = 28000 -- approx, across serialized lines before chunking


local peers = {} -- [sender] = { theirRev=0, theirSeq=0, lastHelloAt=0 }

local function CanSync() return IsInGuild() end

local syncDisabledWarned = false
local function WarnSyncDisabledOnce()
  -- Only print this once per session to avoid chat spam when zoning/entering instances.
  -- Reset automatically when the player becomes eligible to sync again.
  if CanSync() then syncDisabledWarned = false; return false end
  if syncDisabledWarned then return true end
  syncDisabledWarned = true
  Notifier:Chat(L.SYNC_DISABLED)
  return true
end

local function BestChannel()
  if IsInGuild() then return "GUILD" end
  return nil
end

local function Send(channel, msg)
  C_ChatInfo.SendAddonMessage(PREFIX, msg, channel)
end

local function Escape(s)
  s = tostring(s or "")
  s = s:gsub("%%", "%%25")
  s = s:gsub("\n", "%%0A")
  s = s:gsub("|", "%%7C")
  s = s:gsub("&", "%%26")
  s = s:gsub("=", "%%3D")
  return s
end
local function Unescape(s)
  s = tostring(s or "")
  s = s:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
  return s
end

local function SerializeChange(ch)
  -- CH|seq|rev|op|kind|key|payload
  local payload = ""
  if ch.op == "upsert" and ch.entry then
    if ch.kind == "P" then
      payload = table.concat({
        "name="..Escape(ch.entry.name or ""),
        "fullName="..Escape(ch.entry.fullName or ""),
        "realm="..Escape(ch.entry.realm or ""),
        "guild="..Escape(ch.entry.guild or ""),
        "class="..Escape(ch.entry.class or ""),
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
        fullName = (kv.fullName ~= "" and kv.fullName or nil),
        realm = (kv.realm ~= "" and kv.realm or nil),
        guild = (kv.guild ~= "" and kv.guild or nil),
        class = (kv.class ~= "" and kv.class or nil),

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
    WarnSyncDisabledOnce(); return
  end
  local ch = BestChannel()
  if not ch then WarnSyncDisabledOnce(); return end
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
    WarnSyncDisabledOnce(); return
  end
  local ch = BestChannel()
  if not ch then WarnSyncDisabledOnce(); return end
  local d = DB:GetData()
  Send(ch, ("REQ|%s|%s"):format(tostring(d.revision or 0), tostring(d.changeSeq or 0)))
  nextSyncAllowedAt = (GetTime and GetTime() or 0) + (SYNC_COOLDOWN or 60)
  Notifier:Chat(L.SYNC_SENT)
end

local rx = {} -- [sender] = { lines={} }

local function ApplyLines(sender, lines)
  local d = DB:GetData()
  local stats = {
    p_added = 0, p_updated = 0,
    g_added = 0, g_updated = 0,
    deletes_ignored = 0,
    ignored = 0,
    applied = 0,
  }

  for _,line in ipairs(lines) do
    if line:match("^CH|") then
      local ch = DeserializeChange(line)
      if ch then
        -- Option A + safety: NEVER apply deletes via sync. Ignore them.
        if ch.op == "delete" then
          stats.deletes_ignored = stats.deletes_ignored + 1
        elseif ch.op == "upsert" and ch.entry then
          if ch.kind == "P" then
            local existed = (d.players and d.players[ch.key] ~= nil)
            DB:ApplyRemoteChange(sender, ch)
            stats.applied = stats.applied + 1
            if existed then stats.p_updated = stats.p_updated + 1 else stats.p_added = stats.p_added + 1 end
          elseif ch.kind == "G" then
            local existed = (d.guilds and d.guilds[ch.key] ~= nil)
            DB:ApplyRemoteChange(sender, ch)
            stats.applied = stats.applied + 1
            if existed then stats.g_updated = stats.g_updated + 1 else stats.g_added = stats.g_added + 1 end
          else
            -- unknown kind
            stats.ignored = stats.ignored + 1
          end
        else
          stats.ignored = stats.ignored + 1
        end
      end
    end
  end

  -- One-line summary (local chat only)
  Notifier:Chat((
    "|cffd20ff7KillOnSight|r: Sync from %s complete — KoS +%d / ~%d, Guild +%d / ~%d, deletes ignored %d, ignored %d"
  ):format(tostring(sender), stats.p_added, stats.p_updated, stats.g_added, stats.g_updated, stats.deletes_ignored, stats.ignored))

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
  if channel ~= "GUILD" then return end
  if not IsInGuild() then return end


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

  if cmd == "ERR" then
    local code, a, b = strsplit("|", rest or "", 3)
    if code == "TOO_OLD" then
      Notifier:Chat((L.SYNC_TOO_OLD or "Sync failed: peer is too far behind (oldest=%s, current=%s)." ):format(tostring(a or "?"), tostring(b or "?")))
    end
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
    -- If peer is too far behind, we refuse a full resync (resync removed for safety).
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
      -- Peer is too far behind our local change journal; cannot safely resync without a destructive reset.
      -- They should ask again after both sides have a longer journal, or clear their local lists manually if desired.
      Send(ch, ("ERR|TOO_OLD|%s|%s"):format(tostring(oldest or 0), tostring(d.changeSeq or 0)))
      return
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