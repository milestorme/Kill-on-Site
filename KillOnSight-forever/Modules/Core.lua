-- Core.lua (Retail / Midnight only)
local ADDON_NAME = ...
local L = KillOnSight_L

local Core = CreateFrame("Frame")

local function ShowWhatsNewOnce()
  local db = _G.KillOnSight_DB
  if not db or not db.realmDB or not CreateFrame or not UIParent then return end

  local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local version = getMetadata and getMetadata(ADDON_NAME, "Version")
  if not version or version == "" then return end

  local saved = db.realmDB
  if saved.whatsNewSeenVersion == version then return end

  local title = string.format(L.UI_WHATS_NEW_TITLE, version)
  local changelog = _G.KillOnSight_WhatsNew
  if not changelog or changelog.version ~= version or not changelog.body then return end
  local body = changelog.body

  local dialog = _G.KillOnSight_WhatsNewFrame
  if not dialog then
    dialog = CreateFrame("Frame", "KillOnSight_WhatsNewFrame", UIParent, "BackdropTemplate")
    dialog:SetSize(570, 420)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetClampedToScreen(true)
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    if dialog.SetBackdrop then
      dialog:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
      })
    end

    local titleBar = CreateFrame("Frame", nil, dialog)
    titleBar:SetPoint("TOPLEFT", 12, -8)
    titleBar:SetPoint("TOPRIGHT", -12, -8)
    titleBar:SetHeight(38)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() dialog:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() dialog:StopMovingOrSizing() end)

    dialog.title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dialog.title:SetPoint("CENTER")

    dialog.scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    dialog.scroll:SetPoint("TOPLEFT", 22, -54)
    dialog.scroll:SetPoint("BOTTOMRIGHT", -38, 52)
    dialog.content = CreateFrame("Frame", nil, dialog.scroll)
    dialog.content:SetWidth(486)
    dialog.scroll:SetScrollChild(dialog.content)
    dialog.body = dialog.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dialog.body:SetPoint("TOPLEFT", 8, -6)
    dialog.body:SetWidth(462)
    dialog.body:SetJustifyH("LEFT")
    dialog.body:SetJustifyV("TOP")

    dialog.close = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.close:SetSize(120, 24)
    dialog.close:SetPoint("BOTTOM", 0, 16)
    dialog.close:SetText(L.UI_CLOSE)
    dialog.close:SetScript("OnClick", function() dialog:Hide() end)
  end

  dialog.title:SetText(title)
  dialog.body:SetText(body)
  dialog.content:SetHeight(math.max(dialog.body:GetStringHeight() + 14, dialog.scroll:GetHeight()))
  dialog:Show()
  -- Save at display time: relogs and /reload won't repeat this version's notice.
  saved.whatsNewSeenVersion = version
end

-- Midnight: instances can return protected 'secret values' for unit data.
-- We hard-disable Nearby/Detector processing inside PvP and PvE instances.

local function IsInPvPInstance()
  if not IsInInstance then return false end
  local ok, inInstance, instType = pcall(IsInInstance)
  if not ok then return false end
  if not inInstance then return false end
  local okCmp, isPvP = pcall(function()
    return instType == "pvp" or instType == "arena"
  end)
  return (okCmp and isPvP) or false
end

local function IsInPvEInstance()
  if not IsInInstance then return false end
  -- Wrap everything in pcall: both inInstance and instType can be tainted values
  -- that error on any comparison, even boolean truthiness checks.
  local ok, result = pcall(function()
    local inInstance, instType = IsInInstance()
    if not inInstance then return false end
    if instType == "pvp" or instType == "arena" then return false end
    return true
  end)
  if not ok then return true end  -- pcall failed → assume instanced, disable
  return result
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
      local msg = (KillOnSight_L and KillOnSight_L.NEARBY_DISABLED_INSTANCE) or "Nearby is disabled in battlegrounds and arenas."

      DEFAULT_CHAT_FRAME:AddMessage('|cff00d0ff'..prefix..':|r '..msg)
    end
  end
end


local function GetDB() return _G.KillOnSight_DB end
local function GetDetector() return _G.KillOnSight_Detector end
local function GetGUI() return _G.KillOnSight_GUI end
local function GetMinimap() return _G.KillOnSight_Minimap end
local function GetNotifier() return _G.KillOnSight_Notifier end
local function GetNearby() return _G.KillOnSight_Nearby end
local function GetMidnightStats() return _G.KillOnSight_MidnightStats end

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
function Core:TouchEncounter(guid, name, classFile, guild, metadataHandled)
  local S = GetMidnightStats()
  if S and S.TouchEncounter then
    S:TouchEncounter(guid, name, classFile, guild, metadataHandled)
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

local VERSION_PREFIX = "KOS_VERSION"
local getAddonMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local ADDON_VERSION = tostring((getAddonMetadata and getAddonMetadata(ADDON_NAME, "Version")) or "0")
local sentVersionThisGroup = false
local sentVersionToGuild = nil

local function VersionParts(version)
  if type(version) ~= "string" or not version:match("^%d+%.%d+%.?%d*$") then return nil end
  local parts = {}
  for part in version:gmatch("%d+") do
    parts[#parts + 1] = tonumber(part) or 0
  end
  return parts
end

local function IsNewerVersion(remoteVersion)
  local remoteParts = VersionParts(tostring(remoteVersion or ""))
  local localParts = VersionParts(ADDON_VERSION)
  if not remoteParts or not localParts then return false end
  for i = 1, math.max(#remoteParts, #localParts) do
    local remotePart, localPart = remoteParts[i] or 0, localParts[i] or 0
    if remotePart ~= localPart then return remotePart > localPart end
  end
  return false
end

local registerAddonMessagePrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
local sendAddonMessage = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
if type(registerAddonMessagePrefix) == "function" then
  pcall(registerAddonMessagePrefix, VERSION_PREFIX)
end

local function AnnounceVersionToGuild()
  local guildName = GetGuildInfo and GetGuildInfo("player")
  if not guildName then
    sentVersionToGuild = nil
    return
  end
  if sentVersionToGuild == guildName or type(sendAddonMessage) ~= "function" then return end
  sendAddonMessage(VERSION_PREFIX, ADDON_VERSION, "GUILD")
  sentVersionToGuild = guildName
end

local function AnnounceVersionToGroup()
  local grouped = (IsInRaid and IsInRaid()) or (IsInGroup and IsInGroup())
  if not grouped then
    sentVersionThisGroup = false
    return
  end
  if sentVersionThisGroup or type(sendAddonMessage) ~= "function" then return end
  sendAddonMessage(VERSION_PREFIX, ADDON_VERSION, (IsInRaid and IsInRaid()) and "RAID" or "PARTY")
  sentVersionThisGroup = true
end

local function AnnounceVersion()
  AnnounceVersionToGuild()
  AnnounceVersionToGroup()
end

local function CheckPeerVersion(remoteVersion)
  remoteVersion = tostring(remoteVersion or "")
  if not IsNewerVersion(remoteVersion) then return end
  local db = _G.KillOnSight_DB
  local saved = db and db.realmDB
  if not saved then return end
  saved.newerVersionsSeen = saved.newerVersionsSeen or {}
  if saved.newerVersionsSeen[remoteVersion] then return end
  saved.newerVersionsSeen[remoteVersion] = true
  Print(string.format(L.MSG_NEWER_VERSION, remoteVersion))
  Print(string.format(L.MSG_CURRENT_VERSION, ADDON_VERSION))
  Print(L.MSG_UPDATE_HINT)
end

local function ShowAddonVersion()
  Print(string.format(L.MSG_VERSION, ADDON_VERSION))
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
    if Nearby and Nearby.frame and Nearby.frame.IsShown and (not Nearby.frame:IsShown()) then return end
    local plates = C_NamePlate.GetNamePlates(false)
    if not plates then return end
    for _, plate in ipairs(plates) do
      local unit = plate and plate.namePlateUnitToken
      if unit then
        if not Core._bgDisabled and not Core._instDisabled then Detector:ObserveUnit(unit, nil, "nameplate_poll") end
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
  Print(L.CMD_VERSION)
  Print("Pruning policy (Stats): /kos statsprune on|off|maxdays N|maxentries N|now")
  Print("Tip: /kos statsprune   (with no args) prints current status")
  Print("Import from Spy: /kos importspy")
end

local function EnsureName(rest)
  local name = _G.KillOnSight_Util:NormalizePlayerName(rest or "")
  if not name or name == "" then
    local unit = "target"
    if UnitExists(unit) and UnitIsPlayer(unit) then
      name = _G.KillOnSight_Util:UnitPlayerName(unit)
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
  DB:AddPlayer(name, L.KOS, nil, ((_G.KillOnSight_Util and _G.KillOnSight_Util:UnitPlayerName("player")) or UnitName("player")))
  Notifier:Chat(string.format(L.ADDED_PLAYER, L.KOS, name))
  local GUI = GetGUI()
  if GUI then GUI:RefreshAll() end
end

local function RemovePlayer(rest)
  local DB = _G.KillOnSight_DB
  local Notifier = GetNotifier()
  if not DB or not Notifier then return end

  local name = _G.KillOnSight_Util:NormalizePlayerName(rest or "")
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

  local guild = (rest or ""):match("^%s*(.-)%s*$")
  if guild == "" then return Help() end
  if DB:HasGuild(guild) then return end
  DB:AddGuild(guild, L.GUILD_KOS, nil, ((_G.KillOnSight_Util and _G.KillOnSight_Util:UnitPlayerName("player")) or UnitName("player")))
  Notifier:Chat(string.format(L.ADDED_GUILD, L.GUILD_KOS, guild))
  local GUI = GetGUI()
  if GUI then GUI:RefreshAll() end
end

local function RemoveGuild(rest)
  local DB = _G.KillOnSight_DB
  local Notifier = GetNotifier()
  if not DB or not Notifier then return end

  local guild = (rest or ""):match("^%s*(.-)%s*$")
  if guild == "" then return Help() end
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
  if cmd == "version" or cmd == "ver" then return ShowAddonVersion() end
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
    return (_G.KillOnSight_Util and _G.KillOnSight_Util:PlayerKey(n)) or n
  end
  local cleanName = Clean(name)
  local function GuildFromUnit(unit)
    if not unit or not UnitExists or not UnitExists(unit) then return nil end
    if guid and UnitGUID and UnitGUID(unit) ~= guid then return nil end
    if (not guid) and cleanName and UnitName then
      local un = _G.KillOnSight_Util:UnitPlayerName(unit)
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
    if Minimap and Minimap.Create then Minimap:Create() end
    local Nearby = GetNearby()
    if Nearby and Nearby.Init then Nearby:Init() end
    StartNearbyNameplateScan()
    if GetMidnightStats() and GetMidnightStats().Init then GetMidnightStats():Init() end
    StartDeferredGuildResolveTicker()
    Print(L.MSG_LOADED)
    return
  end

  if event == "PLAYER_LOGIN" then
    ShowWhatsNewOnce()
    AnnounceVersion()
    return
  end

  if event == "GROUP_ROSTER_UPDATE" then
    AnnounceVersionToGroup()
    return
  end

  if event == "GUILD_ROSTER_UPDATE" then
    AnnounceVersionToGuild()
    return
  end

  if event == "CHAT_MSG_ADDON" then
    local prefix, message = ...
    if prefix == VERSION_PREFIX then CheckPeerVersion(message) end
    return
  end


  if event == "PLAYER_ENTERING_WORLD" then
    ApplyPvPInstanceDisableState(IsInPvPInstance())
    ApplyPvEInstanceDisableState(IsInPvEInstance())
    if Core._bgDisabled then return end
    if Detector and not Core._instDisabled then Detector:ObserveUnit("target", nil, "world_enter") end
    if GUI then GUI:RefreshAll() end
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
    if Detector and not Core._instDisabled then Detector:ObserveUnit("target", nil, "target_changed") end
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
    -- World mouseover can fire repeatedly for the same unit in crowded areas.
    -- Coalesce only unchanged mouseover GUIDs; new targets run immediately.
    -- UNIT_AURA / spellcast / flags events still use the unthrottled detection path.
    local mouseGUID
    if UnitGUID then
      local ok, value = pcall(UnitGUID, "mouseover")
      if ok and type(value) == "string" and value ~= "" then mouseGUID = value end
    end
    if mouseGUID and GetTime then
      local ok, now = pcall(GetTime)
      if ok and type(now) == "number" then
        if Core._lastWorldMouseoverGUID == mouseGUID
          and now - (Core._lastWorldMouseoverAt or 0) < 0.30 then
          return
        end
        Core._lastWorldMouseoverGUID = mouseGUID
        Core._lastWorldMouseoverAt = now
      end
    else
      Core._lastWorldMouseoverGUID = nil
    end
    if Detector and not Core._instDisabled then Detector:ObserveUnit("mouseover", nil, "mouseover_changed") end
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
    if Detector and not Core._instDisabled then Detector:ObserveUnit(unit, nil, "nameplate_added") end
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
    if IsInPvEInstance() then
      if not Core._instDisabled then ApplyPvEInstanceDisableState(true) end
      return
    elseif Core._instDisabled then
      ApplyPvEInstanceDisableState(false)
    end
    if Core._bgDisabled then return end
    local unit, castGUID, spellID = ...
    if event == "UNIT_SPELLCAST_SUCCEEDED" and Detector and Detector.OnStealthSpellCast then
      Detector:OnStealthSpellCast(unit, spellID)
    end
    if unit and (unit == "target" or unit == "mouseover" or unit:match('^nameplate')) then
      if Detector and not Core._instDisabled then Detector:ObserveUnit(unit, nil, "unit_state") end
    end
    return
  end
end)

local function SafeRegisterEvent(event)
  if not Core or not Core.RegisterEvent then return end
  pcall(Core.RegisterEvent, Core, event)
end

SafeRegisterEvent("ADDON_LOADED")
SafeRegisterEvent("PLAYER_LOGIN")
SafeRegisterEvent("CHAT_MSG_ADDON")
SafeRegisterEvent("GROUP_ROSTER_UPDATE")
SafeRegisterEvent("GUILD_ROSTER_UPDATE")
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

_G.KillOnSight_Core._ScheduleGUIRefresh = _ScheduleGUIRefresh
