-- NearbyFrame.lua
-- Spy-like nearby enemies window (small, scrollable, clickable)
local ADDON_NAME = ...
local L = KillOnSight_L

local function GetDB() return _G.KillOnSight_DB end
local function GetNotifier() return _G.KillOnSight_Notifier end

-- Project detection (Retail vs Classic-era). On Retail, players can PvP in "resting" areas (War Mode,
-- city skirmishes, etc.). Treating IsResting() as a sanctuary signal on Retail would incorrectly
-- disable Nearby population.
local IS_RETAIL = (WOW_PROJECT_ID and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) or false

-- Sanctuary detection: prevent Nearby population and clear the list in safe "sanctuary" areas.
-- Prefer GetZonePVPInfo() which can return "sanctuary"; fall back to IsResting() in versions/zones
-- where that is the only reliable signal.
local function IsInSanctuary()
  local pvpType = (GetZonePVPInfo and GetZonePVPInfo())
  if pvpType == "sanctuary" then return true end
  -- Classic-era fallback only.
  if (not IS_RETAIL) and IsResting and IsResting() then return true end
  return false
end

-- Optional town-level suppression (Classic/TBC-friendly): Booty Bay / Gadgetzan.
-- These are *not* sanctuary zones, so we rely on subzone/minimap zone text.
local function IsInGoblinTown()
  local sub = (GetSubZoneText and GetSubZoneText()) or ""
  local mini = (GetMinimapZoneText and GetMinimapZoneText()) or ""
  if sub == "" then sub = mini end
  if mini == "" then mini = sub end

  local bb = (L.SUBZONE_BOOTY_BAY or "Booty Bay")
  local gz = (L.SUBZONE_GADGETZAN or "Gadgetzan")

  return sub == bb or mini == bb or sub == gz or mini == gz
end

-- Recompute KoS/Guild tagging for a Nearby entry based on current lists.
-- Hidden is handled separately and should not be persisted as kosType.
local function ComputeKoSTypeForEntry(e, DB)
  if not e or not DB then return nil end
  local name = e.name
  if name and DB.LookupPlayer and DB:LookupPlayer(name) then
    return L.KOS
  end
  local g = e.guild
  if g and g ~= "" and DB.LookupGuild and DB:LookupGuild(g) then
    return L.GUILD_KOS
  end
  return nil
end

local Nearby = {
  frame = nil,
  scroll = nil,
  rows = {},
  entries = {},   -- [key]=entry where key is Player GUID when known, else lowerName
  guidToKey = {}, -- [guid]=key
  nameToKey = {}, -- [lowerName]=key
  alerted = {},   -- [lowerName] = true if alerted this presence
  -- KoS/Guild announcement gates: only once per presence while the player remains in Nearby.
  strongAlerted = {},  -- [lowerName] = true if sound/flash already played this presence
  announceAlerted = {},-- [lowerName] = true if chat announce already sent this presence
  refreshScheduled = false,
  minimized = false,
  menu = nil,
  titleFS = nil,
  countFS = nil,
  headerFrame = nil,
  bottomButtons = nil,
  ticker = nil,
  tickerInterval = 0.5,
  orderCounter = 0,

  -- Midnight perf: keep a stable sorted list and refresh at a capped rate.
  _sortedList = nil,
  _sortedDirty = true,
  _refreshTimer = nil,
  _nextAllowedRefresh = 0,
  refreshInterval = 0.10, -- seconds (10 fps max)
}

-- Spy-like retention: keep players ACTIVE for this long, then INACTIVE (dimmed) before removal.
local ACTIVE_TTL = 30   -- seconds: considered 'nearby'
local INACTIVE_TTL = 30 -- seconds: keep dimmed before removing


local SafeSetShown

-- Layout refresh helper (Retail/BG safe): attempt immediately; never wait for PLAYER_REGEN_ENABLED.
function Nearby:QueueLayout()
  self._pendingLayout = nil
  if self.ApplyMinimalMode then pcall(function() self:ApplyMinimalMode() end) end
  if self.Refresh then pcall(function() self:Refresh() end) end
end


function Nearby:StartTicker()
  if self.ticker then return end
  self.ticker = C_Timer.NewTicker(self.tickerInterval or 0.5, function()
    -- periodic refresh so TTL prune + autohide works even when no new events happen
    if self.frame and (self.frame:IsShown() or (GetDB() and GetDB():GetProfile().showNearbyFrame ~= false)) then
      self:Refresh()
    end
  end)
end


function Nearby:StopTicker()
  if self.ticker then
    self.ticker:Cancel()
    self.ticker = nil
  end
end

local function Now() return GetTime() end

local function SafeEnableMouse(obj, enabled)
  if not obj or not obj.EnableMouse then return end
  -- Never gate on InCombatLockdown for Nearby; attempt immediately with a pcall guard.
  local ok = pcall(function() obj:EnableMouse(enabled and true or false) end)
  if ok then return end
  -- If it errors (taint/protection), fail silently; Nearby will still function visually.
end

SafeSetShown = function(frame, shown)
  if not frame then return end
  -- Never gate on InCombatLockdown for Nearby; attempt immediately with a pcall guard.
  pcall(function()
    if frame.SetShown then
      frame:SetShown(shown and true or false)
    else
      if shown then frame:Show() else frame:Hide() end
    end
  end)
end

local function NormalizeName(name)
  if not name or name == "" then return nil end
  -- Defensive: never allow formatted strings (color codes / texture tags) to become part of the stored name.
  -- If a formatted name leaks into storage, it can cause duplicated inline icons (e.g. stealth) and bad lookups.
  name = tostring(name)
  -- Strip WoW color codes and texture tags.
  name = name:gsub("|c%x%x%x%x%x%x%x%x", "")
             :gsub("|r", "")
             :gsub("|T.-|t", "")
             :gsub("^%s+", "")
             :gsub("%s+$", "")
  -- Make names consistent with Spy: strip realm suffix and normalize capitalization input.
  if _G.Ambiguate then
    name = Ambiguate(name, "short")
  else
    name = name:gsub("%-.+$", "")
  end
  return name
end

local function ClassColorHex(classFile)
  if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
    local c = RAID_CLASS_COLORS[classFile]
    return ("|cff%02x%02x%02x"):format(c.r*255, c.g*255, c.b*255)
  end
  return "|cffffffff"
end

-- Accept either class file token ("WARRIOR") or localized class name ("Warrior").
-- Returns class file token or nil.
local _localizedToClassFile
local function NormalizeClass(classIn)
  if not classIn or classIn == "" then return nil end
  if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classIn] then
    return classIn
  end
  if not _localizedToClassFile then
    _localizedToClassFile = {}
    if LOCALIZED_CLASS_NAMES_MALE then
      for file, loc in pairs(LOCALIZED_CLASS_NAMES_MALE) do
        _localizedToClassFile[loc] = file
      end
    end
    if LOCALIZED_CLASS_NAMES_FEMALE then
      for file, loc in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
        _localizedToClassFile[loc] = file
      end
    end
  end
  return _localizedToClassFile[classIn]
end

local function MakeBackdrop(frame)
  if not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  frame:SetBackdropColor(0,0,0,0.80)
end

function Nearby:ApplyPosition()
  local DB = GetDB()
  if not DB or not self.frame then return end
  local prof = DB:GetProfile()
  local p = prof.nearbyFrame or {}
  self.frame:ClearAllPoints()
  self.frame:SetPoint(p.point or "CENTER", UIParent, p.relPoint or "CENTER", p.x or 280, p.y or 80)
  self.frame:SetScale(p.scale or 1.0)
end

function Nearby:SavePosition()
  local DB = GetDB()
  if not DB or not self.frame then return end
  local prof = DB:GetProfile()
  prof.nearbyFrame = prof.nearbyFrame or {}
  local point, _, relPoint, x, y = self.frame:GetPoint(1)
  prof.nearbyFrame.point = point
  prof.nearbyFrame.relPoint = relPoint
  prof.nearbyFrame.x = x
  prof.nearbyFrame.y = y
end

function Nearby:SetLocked(locked)
  local DB = GetDB()
  if not DB then return end
  local prof = DB:GetProfile()
  prof.nearbyFrameLocked = not not locked
  if self.frame then
    self.frame:SetMovable(not locked)
  end
end

function Nearby:SetShown(shown)
  local DB = GetDB()
  if not DB then return end
  local prof = DB:GetProfile()
  prof.showNearbyFrame = not not shown
  if not self.frame then
    if shown then self:Create() end
    return
  end
  if shown then self.frame:Show() else self.frame:Hide() end
  if shown then self:StartTicker() else self:StopTicker() end
end


function Nearby:_SetFrameHeightSafe(h)
  if not self.frame then return end
  if InCombatLockdown and InCombatLockdown() then
    self._pendingHeight = h
    if not self._heightRetryTicker and C_Timer and C_Timer.NewTicker then
      self._heightRetryTicker = C_Timer.NewTicker(1, function()
        if InCombatLockdown and InCombatLockdown() then return end
        if self._heightRetryTicker then
          self._heightRetryTicker:Cancel()
          self._heightRetryTicker = nil
        end
        if self._pendingHeight and self.frame then
          local height = self._pendingHeight
          self._pendingHeight = nil
          pcall(function() self.frame:SetHeight(height) end)
        end
      end)
    end
    return
  end
  pcall(function() self.frame:SetHeight(h) end)
end

function Nearby:AutoFitHeight(visibleCount)
  if self.minimized then return end
  if not self.frame then return end
  local DB = GetDB()
  if not DB then return end
  local prof = DB:GetProfile()

  local minimal = prof.nearbyMinimal == true
  local maxRows = (self.rows and #self.rows) or 0
  if maxRows <= 0 then return end

  local desired = tonumber(visibleCount) or 0
  if desired < 1 then desired = 1 end
  if desired > maxRows then desired = maxRows end

  self.visibleRows = desired

  -- Keep existing layout feel:
  -- non-minimal default: 220 for 8 rows @22px => base 44
  -- minimal default:     190 for 8 rows @22px => base 14
  local base = minimal and 14 or 44
  local h = base + (desired * 22)
  if h < 60 then h = 60 end

  self:_SetFrameHeightSafe(h)
end

function Nearby:SetMinimized(mini)
  self.minimized = not not mini
  if not self.frame then return end

  if self.minimized then
    self.scroll:Hide()
    for _,r in ipairs(self.rows) do r:Hide() end
    self:_SetFrameHeightSafe(62)
  else
    self.scroll:Show()
    for _,r in ipairs(self.rows) do r:Show() end
  end
  self:Refresh()
end


function Nearby:ApplyMinimalMode()
  if not self.frame then return end
  local DB = GetDB()
  if not DB then return end
  local prof = DB:GetProfile()

  if InCombatLockdown and InCombatLockdown() then
    self._pendingMinimal = true
    if not self._combatRetryTicker and C_Timer and C_Timer.NewTicker then
      self._combatRetryTicker = C_Timer.NewTicker(1, function()
        if InCombatLockdown and InCombatLockdown() then return end
        if self._combatRetryTicker then
          self._combatRetryTicker:Cancel()
          self._combatRetryTicker = nil
        end
        if self._pendingMinimal then
          self._pendingMinimal = nil
          if self.ApplyMinimalMode then pcall(function() self:ApplyMinimalMode() end) end
        end
      end)
    end
    return
  end

  local minimal = prof.nearbyMinimal == true
  -- backdrop
  if self.frame.SetBackdrop then
    if minimal then
      self.frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
      self.frame:SetBackdropColor(0,0,0,0.35)
    else
      self.frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
      })
      self.frame:SetBackdropColor(0,0,0,0.80)
    end
  end

  -- header + bottom buttons
  if self.headerFrame then
    self.headerFrame:SetShown(not minimal)
  end
  if self.titleFS then
    self.titleFS:SetShown(not minimal)
  end
  if self.countFS then
    self.countFS:SetShown(not minimal)
  end

  -- adjust scroll area anchors for minimal mode
  if self.scroll then
    self.scroll:ClearAllPoints()
    if minimal then
      self.scroll:SetPoint("TOPLEFT", 10, -10)
      self.scroll:SetPoint("BOTTOMRIGHT", -28, 10)
    else
      self.scroll:SetPoint("TOPLEFT", 10, -56)
      self.scroll:SetPoint("BOTTOMRIGHT", -28, 10)
    self:AutoFitHeight(self._lastCount or 1)
    end
  end

  -- row positions update
  if self.rows and #self.rows > 0 then
    for i,row in ipairs(self.rows) do
      row:ClearAllPoints()
      if minimal then
        row:SetPoint("TOPLEFT", 12, -10 - (i-1)*22)
      else
        row:SetPoint("TOPLEFT", 12, -56 - (i-1)*22)
      end
    end
  end
end


function Nearby:ApplyLocked()
  if not self.frame then return end
  local DB = GetDB()
  if not DB then return end
  local prof = DB:GetProfile()
  local locked = prof.nearbyLocked == true
  self.frame:SetMovable(true)
  SafeEnableMouse(self.frame, true)
  if locked then
    self.frame:RegisterForDrag()
    self.frame:SetScript("OnDragStart", nil)
    self.frame:SetScript("OnDragStop", nil)
  else
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    self.frame:SetScript("OnDragStop", function(f)
      f:StopMovingOrSizing()
      self:SavePosition()
    end)
  end
end

function Nearby:ApplyAlpha()
  if not self.frame then return end
  local DB = GetDB()
  if not DB then return end
  local prof = DB:GetProfile()
  self.baseAlpha = prof.nearbyAlpha or 0.80
  if prof.nearbyFade == false then
    self.frame:SetAlpha(self.baseAlpha)
  end
end

function Nearby:FadeTo(targetAlpha, duration, hideOnDone)
  if not self.frame then return end
  self.frame:SetAlpha(targetAlpha or 1)
  if hideOnDone then SafeSetShown(self.frame, false) end
end

function Nearby:AlertNewEnemy(e)
  local N = GetNotifier()
  if not N or not e then return end

  local DB = GetDB()
  local prof = DB and DB:GetProfile()
  if not prof then return end

  local L = GetLocale()
  local t = e.kosType

  -- KoS / Guild-KoS: keep the strong alert behavior (sound + flash) exactly as before.
  -- NOTE: We *must not* rely on (t == L.KOS) if locale keys are missing (nil), so we guard with t.
  local isKoS = false
  if t then
    if (L and L.KOS and t == L.KOS) or (L and L.GUILD_KOS and t == L.GUILD_KOS) or t == "KoS" or t == "Guild-KoS" then
      isKoS = true
    end
  end

  if isKoS then
    -- Mark strong alert as consumed for this presence so Notifier does not
    -- re-fire sound/flash while the player remains in the Nearby list.
    local key = (e.name and e.name:lower()) or nil
    if key then self.strongAlerted[key] = true end
    if prof.enableSound ~= false then N:Sound() end
    if prof.enableScreenFlash ~= false then N:Flash() end
  else
    -- Spy-style "nearby detected" sound when ANY enemy is first added to the nearby list.
    -- This is intentionally separate from KoS alerts to avoid double-playing.
    -- NOTE: Nearby sound is intentionally independent from the main KoS/Guild sound toggle.
    if prof.nearbySound ~= false then
      -- Play the bundled Nearby sound (addon folder name is KillOnSight).
      PlaySoundFile("Interface\\AddOns\\KillOnSight\\Sounds\\detected-nearby.mp3", "Master")
    end
  end
end

-- KoS/Guild alerts should only fire once while the player remains in the Nearby list.
-- Returns two booleans: doChat, doStrong (sound/flash).
function Nearby:ConsumeKoSGuildAnnouncement(name, listType)
  if not name or name == "" then return false, false end
  local Lc = GetLocale()
  local isKoS = false
  if listType then
    if (Lc and Lc.KOS and listType == Lc.KOS) or (Lc and Lc.GUILD_KOS and listType == Lc.GUILD_KOS) or listType == "KoS" or listType == "Guild-KoS" then
      isKoS = true
    end
  end
  if not isKoS then return false, false end

  local norm = NormalizeName(name) or name
  local lower = tostring(norm):lower()
  local key = (self.nameToKey and self.nameToKey[lower]) or lower

  local doChat = false
  local doStrong = false

  if not self.announceAlerted[key] then
    self.announceAlerted[key] = true
    doChat = true
  end
  if not self.strongAlerted[key] then
    self.strongAlerted[key] = true
    doStrong = true
  end

  return doChat, doStrong
end



-- Midnight perf: mark sort cache dirty
function Nearby:MarkSortedDirty()
  self._sortedDirty = true
end

-- Freeze ordering while hovered or in combat (Spy-stable clickability).
function Nearby:IsSortFrozen()
  if self._sortFreezeHover then return true end
  if InCombatLockdown and InCombatLockdown() then return true end
  return false
end

-- Toggle hover-based sort freeze. When unfreezing, apply any pending reorder once.
function Nearby:SetHoverFreeze(on)
  local v = on and true or false
  if self._sortFreezeHover == v then return end
  self._sortFreezeHover = v
  if not v then
    -- Apply any pending reorder after hover ends.
    if self._sortedDirty then
      self:ScheduleRefresh(true)
    end
  end
end


-- Midnight perf: rebuild sorted list only when needed
function Nearby:GetSortedList()
  if not self._sortedList then
    self._sortedList = {}
    self._sortedDirty = true
  end

  local frozen = self:IsSortFrozen()

  -- If we have no cached list yet, build once even if frozen.
  if self._sortedDirty and (not frozen or #self._sortedList == 0) then
    wipe(self._sortedList)
    for _, e in pairs(self.entries) do
      self._sortedList[#self._sortedList + 1] = e
    end
    table.sort(self._sortedList, function(a, b)
      local aKoS = (a.kosType == L.KOS or a.kosType == L.GUILD_KOS)
      local bKoS = (b.kosType == L.KOS or b.kosType == L.GUILD_KOS)
      local aPri = (aKoS and 0 or 2) + ((a.state == "inactive") and 1 or 0)
      local bPri = (bKoS and 0 or 2) + ((b.state == "inactive") and 1 or 0)
      if aPri ~= bPri then return aPri < bPri end
      -- Spy-stable: newest first by firstSeen only (do NOT sort by lastSeen/order).
      local af = a.firstSeen or 0
      local bf = b.firstSeen or 0
      if af ~= bf then return af > bf end
      return (a.order or 0) > (b.order or 0)
    end)
    self._sortedDirty = false
  end

  return self._sortedList
end

-- Midnight perf: capped refresh scheduler
function Nearby:ScheduleRefresh(immediate)
  if not self.frame then return end
  local now = Now()
  local interval = self.refreshInterval or 0.10
  local earliest = self._nextAllowedRefresh or 0

  if self._refreshTimer then
    -- A refresh is already queued; no need to add more.
    return
  end

  local delay
  if immediate then
    delay = 0
  else
    delay = math.max(0, earliest - now)
  end

  -- Set next allowed refresh time.
  self._nextAllowedRefresh = now + interval

  self._refreshTimer = C_Timer.NewTimer(delay, function()
    self._refreshTimer = nil
    if self.Refresh then pcall(function() self:Refresh() end) end
  end)
end

local function RowLabel(e, tNow)
  local c = ClassColorHex(e.class)
  local lvl = (e.level and e.level > 0) and tostring(e.level) or "??"

  -- Hidden (stealth/prowl/vanish) is a state separate from KoS/Guild tagging.
  -- We render it as a small icon inline with the text to avoid overlapping
  -- the KoS/Guild tags and to save horizontal space.
  local isHidden = (e.isHidden == true) or (e.kosType == L.HIDDEN)

  local util = _G.KillOnSight_Util
  local isKoS = (e.kosType == L.KOS)
  local isGuild = (e.kosType == L.GUILD_KOS)
  local tag = ""
  if util and util.AppendTags then
    tag = util:AppendTags("", isKoS, isGuild)
  else
    if isKoS then tag = " |cffff0000[KoS]|r" end
    if isGuild then tag = " |cffffd000[Guild]|r" end
  end

  -- Zone text intentionally suppressed
  local zone = ""

  local line = ("%s%s|r |cffbbbbbbLv%s|r%s%s"):format(
    c,
    e.name,
    lvl,
    tag,
    zone
  )

  if isHidden then
    -- Inline texture tag keeps layout stable and prevents overlap with other right-aligned indicators.
    -- Texture tag format: |TtexturePath:width:height:xOffset:yOffset|t
    line = line .. " |TInterface\\Icons\\Ability_Stealth:12:12:0:0|t"
  end

  if e.state == "inactive" then
    return "|cff9a9a9a" .. line .. "|r"
  end

  return line
end

local function EnsureMenu(self)
  if self.menu then return end
  self.menu = CreateFrame("Frame", "KillOnSight_NearbyMenu", UIParent, "UIDropDownMenuTemplate")
end

local function ShowMenuFor(self, e)
  if not e then return end
  local DB = GetDB()
  if not DB then return end
  EnsureMenu(self)

  local has = (DB.LookupPlayer and DB:LookupPlayer(e.name)) and true or false
  local menu = {
    { text = e.name, isTitle = true, notCheckable = true },
    { text = L.UI_ADD_KOS, notCheckable = true, disabled = has, func = function()
        DB:AddPlayer(e.name)
        e.kosType = L.KOS
        self:MarkSortedDirty()
        self:ScheduleRefresh(true)
      end
    },
    { text = L.UI_REMOVE_KOS, notCheckable = true, disabled = not has, func = function()
        DB:RemovePlayer(e.name)
        if e.kosType == L.KOS then e.kosType = nil end
        self:MarkSortedDirty()
        self:ScheduleRefresh(true)
      end
    },
    { text = L.UI_CLEAR_NEARBY, notCheckable = true, func = function()
        wipe(self.entries)
        wipe(self.alerted)
        self:MarkSortedDirty()
        self:ScheduleRefresh(true)
      end
    },
    { text = CLOSE, notCheckable = true },
  }

  if EasyMenu then
    EasyMenu(menu, self.menu, "cursor", 0, 0, "MENU")
    return
  end

  if not (UIDropDownMenu_Initialize and UIDropDownMenu_AddButton and UIDropDownMenu_CreateInfo and ToggleDropDownMenu) then
    return
  end

  UIDropDownMenu_Initialize(self.menu, function(_, level)
    if level ~= 1 then return end
    for _, item in ipairs(menu) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = item.text
      info.isTitle = item.isTitle
      info.notCheckable = item.notCheckable
      info.disabled = item.disabled
      info.func = item.func
      UIDropDownMenu_AddButton(info, level)
    end
  end, "MENU")
  ToggleDropDownMenu(1, nil, self.menu, "cursor", 0, 0)
end


local function UpdateScroll(self)
  local list = self:GetSortedList()
  local total = #list
  local offset = FauxScrollFrame_GetOffset(self.scroll)
  local visible = self.visibleRows or #self.rows
  local tNow = Now()

  if self.countFS then
    self.countFS:SetText(string.format(L.UI_NEARBY_COUNT, total))
  end

  for i = 1, visible do
    local idx = offset + i
    local row = self.rows[i]
    local e = list[idx]
    row.entry = e

    if e then      -- Secure targeting (Classic): cannot update macro attributes in combat.
      if row.SetAttribute then
        if not (InCombatLockdown and InCombatLockdown()) then
          local tname = e.fullName or e.name or ""
          pcall(function()
            row:SetAttribute("type1", "macro")
            row:SetAttribute("macrotext1", "/targetexact " .. tname)
            row:SetAttribute("macrotext",  "/targetexact " .. tname)
          end)
        end
      end

      row.text:SetText(RowLabel(e, tNow))


      local DB = GetDB()
      local prof = DB and DB:GetProfile()

      -- Row icons (class + skull for KoS/Guild)
      if prof and prof.nearbyRowIcons ~= false and row.icon then
        if e.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[e.class] then
          row.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
          local c = CLASS_ICON_TCOORDS[e.class]
          row.icon:SetTexCoord(c[1], c[2], c[3], c[4])
          row.icon:Show()
        else
          row.icon:Hide()
        end
        if row.skull then
          row.skull:SetShown(e.kosType == L.KOS or e.kosType == L.GUILD_KOS)
        end
      else
        if row.icon then row.icon:Hide() end
        if row.skull then row.skull:Hide() end
      end

      -- Row alpha: dim inactive entries
      if e.state == "inactive" then
        row:SetAlpha(0.60)
      else
        row:SetAlpha(1)
      end

      SafeEnableMouse(row, true)
      -- rows are created shown; do not call :Show() (protected)
    else
      -- Clear unused row
      row.text:SetText("")
      row.entry = nil
      row:SetAlpha(0)
      SafeEnableMouse(row, false)
      if row.icon then row.icon:Hide() end
      if row.skull then row.skull:Hide() end
      if row.SetAttribute then
        row:SetAttribute("macrotext1", nil)
        row:SetAttribute("macrotext", nil)
        row:SetAttribute("type1", nil)
      end
      -- do not call :Hide() (protected)
    end
  end

  -- Clear rows beyond the visible count so old names don't linger when the list shrinks
  for i = visible + 1, #self.rows do
    local row = self.rows[i]
    if row then
      row.entry = nil
      row.text:SetText("")
      row:SetAlpha(0)
      SafeEnableMouse(row, false)
      if row.icon then row.icon:Hide() end
      if row.skull then row.skull:Hide() end
      if row.SetAttribute then
        row:SetAttribute("type1", nil)
        row:SetAttribute("macrotext1", nil)
        row:SetAttribute("macrotext", nil)
      end
    end
  end

  FauxScrollFrame_Update(self.scroll, total, visible, 22)
end

function Nearby:Create()
  if self.frame then return end

  local f = CreateFrame("Frame", "KillOnSight_NearbyFrame", UIParent, "BackdropTemplate")
  f:SetSize(216, 220)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  MakeBackdrop(f)

  -- Freeze ordering while the user interacts with the window (Spy-stable clicking).
  f:SetScript("OnEnter", function()
    if Nearby and Nearby.SetHoverFreeze then Nearby:SetHoverFreeze(true) end
  end)
  f:SetScript("OnLeave", function()
    if Nearby and Nearby.SetHoverFreeze then Nearby:SetHoverFreeze(false) end
  end)

  -- Title + count like Spy
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetText(L.UI_TITLE)
  self.titleFS = title

  local count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  count:SetText(string.format(L.UI_NEARBY_COUNT, 0))
  self.countFS = count

  -- Close

  -- Header bar
  local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
  self.headerFrame = header
  self.headerFrame = header
  header:SetHeight(18)
  header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  header:SetBackdropColor(1,1,1,0.06)

  local hName = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hName:SetText(L.UI_NEARBY_HEADER)

  -- Scroll
  local scroll = CreateFrame("ScrollFrame", "KillOnSight_NearbyScroll", f, "FauxScrollFrameTemplate")
  scroll:SetScript("OnVerticalScroll", function(_, offset)
    FauxScrollFrame_OnVerticalScroll(scroll, offset, 22, function() UpdateScroll(self) end)
  end)
  self.scroll = scroll


  -- Mousewheel scroll to view more than the visible rows (we keep the window ultra-minimal but allow browsing the full list)
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(_, delta)
    if not self.scroll then return end
    local list = self:GetSortedList()
    local total = #list
    local visible = #self.rows
    if total <= visible then return end

    local current = FauxScrollFrame_GetOffset(self.scroll) or 0
    local newOffset = current - delta  -- delta is +1 wheel up, -1 wheel down
    if newOffset < 0 then newOffset = 0 end
    local maxOffset = total - visible
    if newOffset > maxOffset then newOffset = maxOffset end

    FauxScrollFrame_SetOffset(self.scroll, newOffset)
    UpdateScroll(self)
  end)

  -- Freeze ordering while hovered so rows don't shift under the mouse (Spy-stable).
  f:SetScript("OnEnter", function()
    self._sortFreezeHover = true
  end)
  f:SetScript("OnLeave", function()
    self._sortFreezeHover = false
    if self._sortedDirty then
      self:ScheduleRefresh(true)
    end
  end)

  -- Rows
  for i=1,20 do
    local b    -- Retail 12.x + Classic/TBC: Spy-style secure button targeting (out of combat) via macro attributes.
    -- Left-click targets using /targetexact (hardware event). Right-click opens the context menu.
    b = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetAttribute("type1", "macro")
    b:SetAttribute("macrotext1", "/targetexact nil")
    b:SetAttribute("macrotext",  "/targetexact nil")
    b:SetScript("PreClick", function(selfBtn, btn)
      local e = selfBtn.entry
      if not e then return end

      if btn == "RightButton" then
        ShowMenuFor(self, e)
        return
      end

      if btn ~= "LeftButton" then return end

      -- Spy behavior: only set secure macro attributes out of combat.
      if InCombatLockdown and InCombatLockdown() then return end

      -- Modifiers are handled elsewhere in KoS; keep targeting on plain left-click.
      if IsShiftKeyDown and (IsShiftKeyDown() or (IsControlKeyDown and IsControlKeyDown()) or (IsAltKeyDown and IsAltKeyDown())) then
        return
      end

      local tname = e.fullName or e.name or ""
      if tname == "" then return end
      tname = tostring(tname):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

      -- Set both for broad compatibility.
      pcall(function()
        selfBtn:SetAttribute("type1", "macro")
        selfBtn:SetAttribute("macrotext1", "/targetexact " .. tname)
        selfBtn:SetAttribute("macrotext",  "/targetexact " .. tname)
      end)
    end)

    b:SetPoint("TOPLEFT", 12, -56 - (i-1)*22)
    b:SetSize(180, 22)

    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(true)
    b.bg:SetColorTexture(1,1,1,0.10)
    b.bg:Hide()

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(14,16)
    b.icon:SetPoint("LEFT", 0, 0)
    b.icon:Hide()

    b.skull = b:CreateTexture(nil, "ARTWORK")
    b.skull:SetSize(13,14)
    b.skull:SetPoint("LEFT", 1, 0)
    b.skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    -- skull icon (8) texcoords
    b.skull:SetTexCoord(0.75,1.0,0.25,0.5)
    b.skull:Hide()

    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("LEFT", 18, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWidth(171)
    b.text:SetText("")

    -- (Hidden/stealth indicator is rendered inline in the row text via a texture tag.)

    b:SetScript("OnEnter", function(selfBtn)
      self:SetHoverFreeze(true)
      selfBtn.bg:Show()
      local e = selfBtn.entry
      if not e then return end
      GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
      GameTooltip:AddLine(e.name)
      if e.level then GameTooltip:AddLine((L.TT_LEVEL_FMT):format(e.level > 0 and e.level or "??"), 1,1,1) end
      if e.guild and e.guild ~= "" then GameTooltip:AddLine(e.guild, 0.8,0.8,0.8) end
      if e.zone and e.zone ~= "" then GameTooltip:AddLine(e.zone, 0.8,0.8,0.8) end
      if e.kosType == L.KOS then
        GameTooltip:AddLine(L.TT_ON_KOS, 1,0.2,0.2)
      elseif e.kosType == L.GUILD_KOS then
        GameTooltip:AddLine(L.TT_GUILD_KOS, 1,0.8,0.2)
      elseif (e.isHidden == true) or (e.kosType == L.HIDDEN) then
        GameTooltip:AddLine("[" .. (L.HIDDEN or "Hidden") .. "]", 0.7,0.7,0.7)
      end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(selfBtn)
      selfBtn.bg:Hide()
      GameTooltip:Hide()
      if self.frame and MouseIsOver and not MouseIsOver(self.frame) then
        self:SetHoverFreeze(false)
      end
    end)
    -- Targeting + menu are handled in PreClick (Spy-style secure buttons).

    self.rows[i] = b
  end

  -- Drag to move
  SafeEnableMouse(f, true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function()
    local DB = GetDB()
    if not DB then return end
    if DB:GetProfile().nearbyFrameLocked then return end
    f:StartMoving()
  end)
  f:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    self:SavePosition()
  end)

  self.frame = f
  self:ApplyPosition()

  -- Watch for sanctuary/resting transitions so we can clear/disable Nearby in safe zones.
  if not self._zoneEventFrame then
    local zf = CreateFrame("Frame")
    zf:RegisterEvent("ZONE_CHANGED")
    zf:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    zf:RegisterEvent("PLAYER_UPDATE_RESTING")
    zf:SetScript("OnEvent", function()
      Nearby:HandleSanctuaryChange()
    end)
    self._zoneEventFrame = zf
  end

  local DB = GetDB()
  local prof = DB and DB:GetProfile()
  self:SetLocked(prof and prof.nearbyFrameLocked)

  if prof and prof.showNearbyFrame == false then
    f:Hide()
  else
    f:Show()
  end

  -- Apply sanctuary rule immediately on creation.
  self:HandleSanctuaryChange()

  UpdateScroll(self)
  self:ApplyAlpha()
  self:ApplyLocked()
  self:ApplyMinimalMode()
  self:StartTicker()
  self:HandleSanctuaryChange()
  self:Refresh() -- apply auto-hide immediately
end

function Nearby:ClearAll(opts)
  opts = opts or {}
  self.entries = {}
  self.guidToKey = {}
  self.nameToKey = {}
  self.alerted = {}
  self.strongAlerted = {}
  self.announceAlerted = {}
  self.orderCounter = 0
  -- Hide immediately in sanctuary mode unless caller requests otherwise.
  if self.frame and not opts.keepShown then
    SafeSetShown(self.frame, false)
  end
  self:ScheduleRefresh()
end

function Nearby:HandleSanctuaryChange()
  if not self.frame then return end
  local inSanct = IsInSanctuary()
  if inSanct then
    -- Disable + clear list while in sanctuary.
    if next(self.entries) ~= nil then
      self:ClearAll({ keepShown = false })
    else
      SafeSetShown(self.frame, false)
    end
  end
end

function Nearby:OnListChanged(kind, keyLower)
  if not self.entries or not keyLower then return end
  local DB = GetDB()
  if not DB then return end

  local dirty = false
  for _, e in pairs(self.entries) do
    if kind == "P" then
      if (e._lowerName and e._lowerName == keyLower) or (e.name and e.name:lower() == keyLower) then
        local newType = ComputeKoSTypeForEntry(e, DB)
        if e.kosType ~= newType then
          e.kosType = newType
          dirty = true
        end
      end
    elseif kind == "G" then
      if e.guild and e.guild:lower() == keyLower then
        local newType = ComputeKoSTypeForEntry(e, DB)
        if e.kosType ~= newType then
          e.kosType = newType
          dirty = true
        end
      end
    end
  end

  if dirty then
    self:MarkSortedDirty()
    self:ScheduleRefresh(true)
  end
end

function Nearby:Seen(name, classFile, guild, kosType, level, guid)
  if not name or name == "" then return end
  if not self.frame then self:Create() end

  local DB = GetDB()
  if not DB then return end
  local prof = DB:GetProfile()
  if prof.showNearbyFrame == false then return end

  -- Optional suppression for neutral goblin towns (Booty Bay / Gadgetzan).
  if prof.disableInGoblinTowns and IsInGoblinTown() then
    if next(self.entries) ~= nil then
      self:ClearAll({ keepShown = false })
    elseif self.frame and self.frame:IsShown() then
      SafeSetShown(self.frame, false)
    end
    return
  end

  -- Do not populate Nearby while in a sanctuary area; also clear/hide if needed.
  if IsInSanctuary() then
    if next(self.entries) ~= nil then
      self:ClearAll({ keepShown = false })
    elseif self.frame and self.frame:IsShown() then
      SafeSetShown(self.frame, false)
    end
    return
  end

  local now = Now()
  local ttl = ACTIVE_TTL -- seconds to keep a player in the list since last sighting
  local rawName = name
  local normName = NormalizeName(name) or name
  local lowerName = tostring(normName):lower()

  local playerGuid = guid and tostring(guid) or nil
  if playerGuid and not playerGuid:match("^Player%-") then
    playerGuid = nil
  end

  local key
  if playerGuid and self.guidToKey[playerGuid] then
    key = self.guidToKey[playerGuid]
  elseif playerGuid then
    local existingKey = self.nameToKey[lowerName]
    if existingKey and existingKey ~= playerGuid then
      local old = self.entries[existingKey]
      if old then
        -- Migrate a name-keyed entry to GUID-keyed once we learn the GUID.
        self.entries[playerGuid] = old
        self.entries[existingKey] = nil

        self.alerted[playerGuid] = self.alerted[existingKey]
        self.strongAlerted[playerGuid] = self.strongAlerted[existingKey]
        self.announceAlerted[playerGuid] = self.announceAlerted[existingKey]
        self.alerted[existingKey] = nil
        self.strongAlerted[existingKey] = nil
        self.announceAlerted[existingKey] = nil

        if old._lowerName then
          self.nameToKey[old._lowerName] = playerGuid
        end
      end
    end
    key = playerGuid
    self.guidToKey[playerGuid] = key
    self.nameToKey[lowerName] = key
  else
    key = self.nameToKey[lowerName] or lowerName
    self.nameToKey[lowerName] = key
  end

  local name = normName

  local e = self.entries[key]
  local wasState = e and e.state or nil
  local wasKoS = e and (e.kosType == L.KOS or e.kosType == L.GUILD_KOS) or false
  local isNew = false
  if not e then
    self.orderCounter = (self.orderCounter or 0) + 1
    e = { name = name, firstSeen = now, order = self.orderCounter, state = "active" } -- order is insertion order (set once)
    self.entries[key] = e
    isNew = true
  end

  -- Spy-stable ordering: only mark sort dirty on structural/bucket changes (not every sighting).
  local wasInactive = (not isNew) and (e.state == "inactive")
  local oldKoS = (e.kosType == L.KOS or e.kosType == L.GUILD_KOS)

  -- Update identity fields and maps (GUID-first).
  e.guid = playerGuid or e.guid
  e._lowerName = lowerName
  if playerGuid then
    self.guidToKey[playerGuid] = key
  end
  self.nameToKey[lowerName] = key

  e.fullName = rawName or e.fullName
  e.class = NormalizeClass(classFile) or e.class
  e.guild = guild or e.guild
  -- Hidden is a *state* (stealth/prowl/shadowmeld detection). Do not store it as kosType,
  -- otherwise later list-type updates (KoS/Guild) can erase it and the UI can't show both.
  if kosType == L.HIDDEN then
    e.isHidden = true
    kosType = nil
  end
  -- If we have a concrete unit level, this was a visible sighting (nameplate/target), so clear Hidden.
  if level ~= nil then
    e.isHidden = nil
  end
  if kosType ~= nil then
    local newKoS = (kosType == L.KOS or kosType == L.GUILD_KOS)
    if (not isNew) and (newKoS ~= wasKoS) then
      self:MarkSortedDirty()
    end
    e.kosType = kosType
  end
  local newKoS = (e.kosType == L.KOS or e.kosType == L.GUILD_KOS)
  e.level = level or e.level
  e.zone = GetRealZoneText() or e.zone
  e.lastSeen = now
  e.state = "active"

  if isNew or wasInactive or (oldKoS ~= newKoS) then
    self:MarkSortedDirty()
  end
  e.activeExpiresAt = now + ACTIVE_TTL
  e.inactiveExpiresAt = now + ACTIVE_TTL + INACTIVE_TTL

  if isNew and not self.alerted[key] then
    self.alerted[key] = true
    self:AlertNewEnemy(e)
  end

  -- ensure visible if we have at least one entry
  self._autoHidden = false
  if self._fadeGroup and self._fadeGroup:IsPlaying() then
    self._fadeGroup._hideOnDone = false
    self._fadeGroup:Stop()
  end
  if not self.frame:IsShown() then
    SafeSetShown(self.frame, true)
  end

  -- cancel any pending fade-out hide
  if self._fadeGroup and self._fadeGroup:IsPlaying() then
    self._fadeGroup._hideOnDone = false
    self._fadeGroup:Stop()
  end

  -- Do not refresh immediately every time (BG-safe perf). Coalesce updates and cap refresh rate.
  self:ScheduleRefresh(true)
end

function Nearby:Refresh()
  if not self.frame then self:Create() end

  local DB = GetDB()
  if not DB then return end
  local prof = DB:GetProfile()

  self:ApplyMinimalMode()

  if prof.showNearbyFrame == false then
    SafeSetShown(self.frame, false)
    return
  end

  -- Sanctuary overrides all nearby-frame visibility settings on 12.x.
  if IsInSanctuary() then
    if next(self.entries) ~= nil then
      self:ClearAll({ keepShown = false })
    else
      SafeSetShown(self.frame, false)
    end
    self._autoHidden = true
    return
  end

  -- Optional suppression for neutral goblin towns (Booty Bay / Gadgetzan).
  if prof.disableInGoblinTowns and IsInGoblinTown() then
    if next(self.entries) ~= nil then
      self:ClearAll({ keepShown = false })
    else
      SafeSetShown(self.frame, false)
    end
    self._autoHidden = true
    return
  end

  local now = Now()
  local count = 0

  -- manage expirations (Spy-like): active -> inactive -> remove
  local dirty = false
  for k, e in pairs(self.entries) do
    local activeExp = e.activeExpiresAt or ((e.lastSeen or now) + ACTIVE_TTL)
    local inactiveExp = e.inactiveExpiresAt or (activeExp + INACTIVE_TTL)

    if now > inactiveExp then
      -- Remove expired entry and its identity mappings.
      if e.guid and self.guidToKey[e.guid] == k then
        self.guidToKey[e.guid] = nil
      end
      if e._lowerName and self.nameToKey[e._lowerName] == k then
        self.nameToKey[e._lowerName] = nil
      end

      self.entries[k] = nil
      self.alerted[k] = nil
      self.strongAlerted[k] = nil
      self.announceAlerted[k] = nil
      dirty = true
    elseif now > activeExp then
      if e.state ~= "inactive" then dirty = true end
      e.state = "inactive"
      count = count + 1
    else
      if e.state ~= "active" then dirty = true end
      e.state = "active"
      count = count + 1
    end
  end

  if dirty then
    self:MarkSortedDirty()
  end

  self._lastCount = count
  self:AutoFitHeight(count)

  if prof.nearbyAutoHide ~= false and count == 0 then
    self._autoHidden = true
    SafeSetShown(self.frame, false)
    return
  end

  -- show + set alpha target
  self._autoHidden = false
  if not self.frame:IsShown() then
    SafeSetShown(self.frame, true)
  end

  self:ApplyAlpha()
  local target = self.baseAlpha or (prof.nearbyAlpha or 0.80)
  self.frame:SetAlpha(target)

  if self.minimized then return end
  UpdateScroll(self)
end

function Nearby:Init()
  self:Create()
  self:StartTicker()
  self:Refresh()
end

KillOnSight_Nearby = Nearby
