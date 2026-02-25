-- NearbyFrame.lua
-- Spy-like nearby enemies window (small, scrollable, clickable)
local ADDON_NAME = ...
local L = KillOnSight_L
if type(L) ~= "table" then
  local _lf = { KOS = "KoS", GUILD_KOS = "Guild KoS", HIDDEN = "Hidden" }
  L = setmetatable({}, { __index = function(_, k) return _lf[k] or tostring(k) end })
end

local KOS_TYPE = (L.KOS or "KoS")
local GUILD_KOS_TYPE = (L.GUILD_KOS or "Guild KoS")
local HIDDEN_TYPE = (L.HIDDEN or "Hidden")

local function NormalizeKosTypeValue(t)
  if not t or t == "" then return t end
  if t == "KoS" or t == KOS_TYPE then return KOS_TYPE end
  if t == "Guild-KoS" or t == "Guild KoS" or t == GUILD_KOS_TYPE then return GUILD_KOS_TYPE end
  if t == "Hidden" or t == HIDDEN_TYPE then return HIDDEN_TYPE end
  return t
end

local function IsKosLike(t)
  t = NormalizeKosTypeValue(t)
  return t == KOS_TYPE or t == GUILD_KOS_TYPE
end

-- Classic-safe shim: some clients/builds don't ship SafeSetShown helper.
if type(SafeSetShown) ~= "function" then
  function SafeSetShown(f, shown)
    if not f then return end
    -- Avoid protected show/hide attempts during combat lockdown.
    if InCombatLockdown and InCombatLockdown() then return end
    if shown then
      if f.Show then f:Show() end
    else
      if f.Hide then f:Hide() end
    end
  end
end


local function GetDB() return _G.KillOnSight_DB end
local function GetNotifier() return _G.KillOnSight_Notifier end

-- Sanctuary detection: prevent Nearby population and clear the list in safe "sanctuary" areas.
-- Prefer GetZonePVPInfo() which can return "sanctuary"; fall back to IsResting() in versions/zones
-- where that is the only reliable signal.
local function IsInSanctuary()
  local pvpType = (GetZonePVPInfo and GetZonePVPInfo())
  if pvpType == "sanctuary" then return true end
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


-- Project detection (Lua 5.1 compatible): use WOW_PROJECT_ID when available.
local function IsClassicOrTBCProject()
  if not WOW_PROJECT_ID then return false end
  if WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then return true end
  if WOW_PROJECT_BURNING_CRUSADE_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then return true end
  return false
end

local function StripRealmSuffix(name)
  if not name or name == "" then return name end
  -- Player names cannot contain '-' normally; this safely removes cross-realm suffixes.
  return (tostring(name):gsub("%-.*$", ""))
end

local function NormalizeNameForCompare(name)
  if not name then return "" end
  name = tostring(name)
  name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  if IsClassicOrTBCProject() then
    name = StripRealmSuffix(name)
  end
  return name
end

local function MacroTargetNameForEntry(e)
  local tname = (e and (e.fullName or e.name)) or ""
  tname = NormalizeNameForCompare(tname)
  return tname
end

local Nearby = {
  frame = nil,
  scroll = nil,
  rows = {},
  entries = {},   -- [lowerName] = {name,class,guild,level,zone,lastSeen,kosType}
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
  -- Dynamic width (auto-fit to longest visible entry)
  autoWidthEnabled = true, -- can be overridden by profile: prof.nearbyAutoWidth
  autoWidthMin = 216,
  autoWidthMax = 450,
  _awTarget = nil,
  _awActive = false,
  _awRowPad = 45, -- frame padding beyond text width (default layout: 216 - 171)
}

-- Unified suppression logic: when suppressed, Nearby must NEVER try to show (prevents flicker).
function Nearby:IsSuppressed(prof)
  if IsInSanctuary() then return true, "sanctuary" end
  if prof and prof.disableInGoblinTowns and IsInGoblinTown() then return true, "goblin" end
  return false, nil
end

function Nearby:IsShown()
  return self.frame and self.frame.IsShown and self.frame:IsShown() or false
end

function Nearby:HandleSuppressionChange()
  if not self.frame then return end
  local DB = GetDB()
  local prof = DB and DB:GetProfile()

  local suppressed, reason = self:IsSuppressed(prof)

  if suppressed then
    self._suppressed = reason or true

    -- Hard lock: stop periodic refresh work and force-hide without letting fades re-show.
    self:StopTicker()

    if self._fadeGroup and self._fadeGroup:IsPlaying() then
      self._fadeGroup._hideOnDone = false
      self._fadeGroup:Stop()
    end

    -- Clear + hide immediately while suppressed.
    if next(self.entries) ~= nil then
      self:ClearAll({ keepShown = false })
    else
      SafeSetShown(self.frame, false)
    end
    return true
  end

  -- Leaving suppressed area: re-enable periodic refresh.
  if self._suppressed then
    self._suppressed = nil
    self:StartTicker()
    self:ScheduleRefresh()
  end
  return false
end


local NEARBY_NAME_FONTS = {
  ["Morpheus"]      = "Fonts\\MORPHEUS.TTF",
  ["Skurri"]        = "Fonts\\SKURRI.TTF",
}

-- Fonts that should not appear in the dropdown (either unreliable or not desired).
-- Note: this is about *dropdown entries* (labels), not files on disk.
local function IsBlockedNearbyFont(name)
  if not name or name == "" then return true end
  -- Explicit removals requested.
  local lower = string.lower(tostring(name))
  if lower == "system" then return true end
  if lower == "tooltip" then return true end
  if lower == "highlight" then return true end
  if lower == "friz quadrata" then return true end
  if lower == "arial narrow" then return true end
  if lower == "2002" then return true end
  if lower == "2002 bold" then return true end

  -- Remove the AR* fonts (e.g. "AR ...")
  -- Keep this tight so we don't accidentally hide unrelated fonts.
  if string.match(name, "^AR%s") then return true end

  return false
end

-- Build a richer font list when possible:
-- 1) Include a handful of common UI font objects (when present).
-- 2) If LibSharedMedia-3.0 is installed, include its registered fonts.
local function BuildNearbyNameFontMap(self)
  local lsm
  if _G.LibStub then
    lsm = _G.LibStub("LibSharedMedia-3.0", true)
  end
  local hasLSM = lsm and lsm.List and lsm.Fetch

  -- Keep cached map, but allow one rebuild when LSM becomes available later.
  if self._nearbyNameFontMap and self._nearbyNameFontChoices then
    if self._nearbyNameFontMapIncludesLSM or (not hasLSM) then
      return
    end
  end

  local map = {}
  local choices = { "Default" }

  -- Built-in file fonts (always available on supported clients).
  for label, path in pairs(NEARBY_NAME_FONTS) do
    if not IsBlockedNearbyFont(label) then
      map[label] = path
      choices[#choices+1] = label
    end
  end

  -- Common UI font objects (may vary by client).
  local fontObjects = {
    { "Chat",            _G.ChatFontNormal },
    { "Quest Title",     _G.QuestTitleFont },
    { "Number",          _G.NumberFontNormal },
    { "Huge Number",     _G.NumberFontNormalHuge },
  }
  for _, item in ipairs(fontObjects) do
    local label, fo = item[1], item[2]
    if fo and fo.GetFont then
      local p = select(1, fo:GetFont())
      if p and p ~= "" and not map[label] and not IsBlockedNearbyFont(label) then
        map[label] = p
        choices[#choices+1] = label
      end
    end
  end

  -- LibSharedMedia fonts (if present). This is the easiest way for users to get lots of fonts
  -- without us shipping any assets.
  if hasLSM then
    -- Re-apply currently selected font when LSM registers media later in the session.
    -- This fixes "custom font selected but rows stay default until reopening/reload".
    if lsm.RegisterCallback and not self._lsmCallbackRegistered then
      self._lsmCallbackRegistered = true
      pcall(function()
        lsm:RegisterCallback(self, "LibSharedMedia_Registered", function(_, mediaType)
          if mediaType == "font" and Nearby and Nearby.ApplyNameFont then
            Nearby:ApplyNameFont(true)
          end
        end)
      end)
    end

    -- Invalidate cached lists when new fonts are registered (font packs often load later).
    if lsm.RegisterCallback and not self._lsmFontCallbackRegistered then
      self._lsmFontCallbackRegistered = true
      pcall(function()
        lsm:RegisterCallback(self, "LibSharedMedia_Registered", function(_, mediaType)
          if mediaType == "font" then
            self._nearbyNameFontMap = nil
            self._nearbyNameFontChoices = nil
          end
        end)
      end)
    end

    local ok, list = pcall(function() return lsm:List("font") end)
    if ok and type(list) == "table" then
      table.sort(list)
      for _, name in ipairs(list) do
        if name and name ~= "" and name ~= "Default" and not map[name] and not IsBlockedNearbyFont(name) then
          local p
          pcall(function() p = lsm:Fetch("font", name) end)
          if p and p ~= "" then
            map[name] = p
            choices[#choices+1] = name
          end
        end
      end
    end
  end

  -- Keep dropdown deterministic.
  -- Sort everything after "Default" alphabetically.
  local rest = {}
  for i = 2, #choices do rest[#rest+1] = choices[i] end
  table.sort(rest)
  choices = { "Default" }
  for _, v in ipairs(rest) do choices[#choices+1] = v end

  self._nearbyNameFontMap = map
  self._nearbyNameFontChoices = choices
  self._nearbyNameFontMapIncludesLSM = not not hasLSM
end

function Nearby:GetNameFontChoices()
  BuildNearbyNameFontMap(self)
  return self._nearbyNameFontChoices or { "Default" }
end

function Nearby:ApplyNameFont(silent)
  BuildNearbyNameFontMap(self)
  local DB = GetDB()
  local prof = DB and DB:GetProfile()
  local choice = (prof and prof.nearbyNameFont) or "Default"
  local sizeChoice = (prof and prof.nearbyNameFontSize)
  if type(sizeChoice) ~= "number" then sizeChoice = nil end

  -- Resolve desired font path
  local path = (self._nearbyNameFontMap and self._nearbyNameFontMap[choice]) or NEARBY_NAME_FONTS[choice]
  local defPath, defSize, defFlags
  if GameFontHighlight and GameFontHighlight.GetFont then
    defPath, defSize, defFlags = GameFontHighlight:GetFont()
  end

  if not self.rows then return end

  -- Use the first row to pick reasonable defaults for size/flags
  local anyRow = self.rows[1]
  local curPath, curSize, curFlags
  if anyRow and anyRow.text and anyRow.text.GetFont then
    curPath, curSize, curFlags = anyRow.text:GetFont()
  end

  local size = sizeChoice or curSize or defSize or 12
  local flags = curFlags or defFlags

  local wantedPath
  if choice ~= "Default" and path and path ~= "" then
    wantedPath = path
  else
    wantedPath = defPath or curPath
  end
  if not wantedPath or wantedPath == "" then return end

  -- Track failures/retries per font choice
  self._badFontsWarned = self._badFontsWarned or {}
  self._fontApplyRetry = self._fontApplyRetry or {}

  local anyApplied = false
  local anyFailed = false

  -- Apply safely: if SetFont fails for a row, immediately restore its previous font.
  for _, row in ipairs(self.rows) do
    if row and row.text and row.text.SetFont and row.text.GetFont then
      local prevPath, prevSize, prevFlags = row.text:GetFont()
      local ok = false
      pcall(function() ok = row.text:SetFont(wantedPath, size, flags) end)

      if ok then
        anyApplied = true
        -- Force an immediate redraw (avoids "blank until next SetText" quirks)
        if row.text.GetText and row.text.SetText then
          local t = row.text:GetText()
          if t ~= nil then row.text:SetText(t) end
        end
      else
        anyFailed = true
        pcall(function()
          if prevPath and prevPath ~= "" then
            row.text:SetFont(prevPath, prevSize or size, prevFlags)
          end
        end)
      end
    end
  end

  -- If nothing applied, we likely hit an LSM timing race. Retry a few times quickly.
  if (not anyApplied or anyFailed) and choice ~= "Default" and C_Timer and C_Timer.After then
    local retries = self._fontApplyRetry[choice] or 0
    if retries < 5 then
      self._fontApplyRetry[choice] = retries + 1
      local delay = 0.10 * (retries + 1) -- 0.10s, 0.20s, ... up to 0.60s
      C_Timer.After(delay, function()
        if Nearby and Nearby.ApplyNameFont then
          Nearby:ApplyNameFont(true)
        end
      end)
      return
    end
  end

  -- Final failure warning (once per font), then fall back silently to Default on next open
  if not anyApplied and choice ~= "Default" then
    if not silent and not self._badFontsWarned[choice] then
      self._badFontsWarned[choice] = true
      if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("KillOnSight: Font '" .. choice .. "' could not be loaded. Falling back to Default.")
      end
    end
  end


-- Keep the hidden auto-width measurer in sync with the row font (unbounded width measurement).
if self._awMeasureFS and self._awMeasureFS.SetFont then
  pcall(function() self._awMeasureFS:SetFont(wantedPath, size, flags) end)
  if self._awMeasureFS.SetWordWrap then self._awMeasureFS:SetWordWrap(false) end
  if self._awMeasureFS.SetMaxLines then self._awMeasureFS:SetMaxLines(1) end
end

-- Font change affects string widths; trigger an auto-width recompute.
self._awDirty = true

  -- Success: clear retry counter
  if choice ~= "Default" then
    self._fontApplyRetry[choice] = 0
  end
end






-- Spy-like retention: keep players ACTIVE for this long, then INACTIVE (dimmed) before removal.
local ACTIVE_TTL = 30   -- seconds: considered 'nearby'
local INACTIVE_TTL = 30 -- seconds: keep dimmed before removing


local SafeSetShown

-- Combat lockdown safe layout updates (avoid taint/protected calls like SetHeight in combat)
function Nearby:QueueLayout()
  self._pendingLayout = true
  if self._combatEventFrame then return end
  local ef = CreateFrame("Frame")
  ef:RegisterEvent("PLAYER_REGEN_ENABLED")
  ef:RegisterEvent("PLAYER_REGEN_DISABLED")
  ef:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
      Nearby._inCombat = true
      if Nearby.SnapshotCombatRows then pcall(function() Nearby:SnapshotCombatRows() end) end
      return
    end
    Nearby._inCombat = nil
    if not Nearby._pendingLayout then return end
    Nearby._pendingLayout = nil
    if Nearby._pendingShown ~= nil and Nearby.frame then
      pcall(function() SafeSetShown(Nearby.frame, Nearby._pendingShown) end)
      Nearby._pendingShown = nil
    end
    -- Apply layout and refresh once combat ends
    if Nearby.ApplyMinimalMode then
      pcall(function() Nearby:ApplyMinimalMode() end)
    end
    if Nearby.Refresh then
      pcall(function() Nearby:Refresh() end)
    end
  end)
  self._combatEventFrame = ef
end



function Nearby:SnapshotCombatRows()
  self._combatStableKeys = self._combatStableKeys or {}
  -- Mark currently displayed row keys as stable (targetable) for duration of combat
  wipe(self._combatStableKeys)
  if not self.rows then return end
  for _, row in ipairs(self.rows) do
    if row and row._entryKey then
      self._combatStableKeys[row._entryKey] = true
      row._notTargetable = nil
    end
  end
end

function Nearby:StartTicker()
  if self.ticker then return end
  if not C_Timer or not C_Timer.NewTicker then return end
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
  if InCombatLockdown and InCombatLockdown() then
    -- EnableMouse/DisableMouse can be protected on secure frames during combat.
    -- Defer to out-of-combat via the existing PLAYER_REGEN_ENABLED hook.
    Nearby._pendingRefresh = true
    Nearby:QueueLayout() -- ensures regen handler exists
    return
  end
  obj:EnableMouse(enabled and true or false)
end

SafeSetShown = function(frame, shown)
  if not frame then return end
  -- Show/Hide can become protected (taint) during combat if the frame is considered "secure" or has been tainted.
  -- Avoid calling it in combat; defer until PLAYER_REGEN_ENABLED via QueueLayout().
  if InCombatLockdown and InCombatLockdown() then
    Nearby._pendingShown = shown and true or false
    Nearby:QueueLayout()
    return
  end
  if frame.SetShown then
    frame:SetShown(shown and true or false)
  else
    if shown then frame:Show() else frame:Hide() end
  end
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
    if not self._regenHooked then
      self._regenHooked = true
      local f = CreateFrame("Frame")
      f:RegisterEvent("PLAYER_REGEN_ENABLED")
      f:SetScript("OnEvent", function()
        f:UnregisterAllEvents()
        if KillOnSight_Nearby and KillOnSight_Nearby._pendingHeight and KillOnSight_Nearby.frame then
          KillOnSight_Nearby.frame:SetHeight(KillOnSight_Nearby._pendingHeight)
          KillOnSight_Nearby._pendingHeight = nil
        end
        -- Apply any pending width changes blocked during combat (secure rows).
        if KillOnSight_Nearby and KillOnSight_Nearby._pendingWidthApply and KillOnSight_Nearby.frame then
          KillOnSight_Nearby._pendingWidthApply = nil
          local w = KillOnSight_Nearby._awTarget or (KillOnSight_Nearby.frame:GetWidth())
          if w then
            KillOnSight_Nearby.frame:SetWidth(w)
            if KillOnSight_Nearby._ApplyRowWidths then
              KillOnSight_Nearby:_ApplyRowWidths(w)
            end
          end
          KillOnSight_Nearby._awActive = false
          KillOnSight_Nearby._awTarget = nil
        end
        KillOnSight_Nearby._regenHooked = false
      end)
    end
    return
  end
  self.frame:SetHeight(h)
end


function Nearby:AutoFitHeight(visibleCount)
  if self.minimized then return end
  if not self.frame then return end
  local DB = GetDB()
  if not DB then return end
  local prof = DB:GetProfile()
  local bodyA = prof.nearbyBackdropAlpha
  if bodyA == nil then bodyA = 0.5 end

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

  if InCombatLockdown and InCombatLockdown() then self:QueueLayout(); return end
  if not self.frame then return end
  local DB = GetDB()
  if not DB then return end
  local prof = DB:GetProfile()
  local bodyA = prof.nearbyBackdropAlpha
  if bodyA == nil then bodyA = 0.5 end

  local minimal = prof.nearbyMinimal == true
  -- backdrop
  if self.frame.SetBackdrop then
    if minimal then
      self.frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
      self.frame:SetBackdropColor(0,0,0,bodyA)
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



-- =========================
-- Dynamic width (auto-fit)
-- =========================
function Nearby:_GetAutoWidthSettings()
  local DB = GetDB()
  local prof = DB and DB:GetProfile()
  local enabled = self.autoWidthEnabled
  if prof and prof.nearbyAutoWidth ~= nil then
    enabled = (prof.nearbyAutoWidth == true)
  end
  local minW = (prof and prof.nearbyMinWidth) or self.autoWidthMin
  local maxW = (prof and prof.nearbyMaxWidth) or self.autoWidthMax
  return enabled, minW, maxW
end

function Nearby:_ApplyRowWidths(frameW)
  if not self.frame or not self.rows then return end
  if InCombatLockdown and InCombatLockdown() then
    self._pendingWidthApply = true
    return
  end

  -- Default layout: frame 216, rows 180, text 171
  local rowW = math.max(80, frameW - 36)
  local textW = math.max(40, rowW - 9)

  for _, row in ipairs(self.rows) do
    if row and row.SetWidth then
      row:SetWidth(rowW)
    end
    if row and row.text and row.text.SetWidth then
      row.text:SetWidth(textW)
    end
  end
end

function Nearby:_SetAutoWidthTarget(targetW)
  if not self.frame then return end
  local enabled, minW, maxW = self:_GetAutoWidthSettings()
  if not enabled then return end
  if not targetW then return end

  if targetW < minW then targetW = minW end
  if targetW > maxW then targetW = maxW end

  self._awTarget = targetW
  self._awActive = true
end

function Nearby:_ComputeAutoWidthTarget()
  if not self.frame or not self.rows then return end
  local enabled, minW, maxW = self:_GetAutoWidthSettings()
  if not enabled then return end

  
local maxText = 0
local meas = self._awMeasureFS
for _, row in ipairs(self.rows) do
  if row and row:IsShown() and row.text then
    local t = row.text:GetText()
    if t and t ~= "" then
      local w = 0
      if meas and meas.SetText and meas.GetStringWidth then
        meas:SetText(t)
        w = meas:GetStringWidth() or 0
      else
        -- Fallback: may be clamped if the FontString has a width.
        w = row.text:GetStringWidth() or 0
      end
      -- Texture tags inside the string (|T...|t) don't always contribute to width; add a tiny bump.
      if t:find("|T", 1, true) then w = w + 14 end
      if w > maxText then maxText = w end
    end
  end
end

  local targetW = math.ceil(maxText + (self._awRowPad or 45))
  if targetW < minW then targetW = minW end
  if targetW > maxW then targetW = maxW end

  self:_SetAutoWidthTarget(targetW)
end

function Nearby:_AutoWidthOnUpdate(elapsed)
  if not self._awActive or not self._awTarget or not self.frame then return end
  if InCombatLockdown and InCombatLockdown() then return end

  local cur = self.frame:GetWidth() or 0
  local tgt = self._awTarget
  local diff = tgt - cur
  local ad = math.abs(diff)

  if ad <= 1.0 then
    self.frame:SetWidth(tgt)
    self:_ApplyRowWidths(tgt)
    self._awActive = false
    self._awTarget = nil
    return
  end

  -- Very fast, distance-scaled speed (snappy expand, still smooth).
  local speed = 1400 + (ad * 20)
  if speed > 7000 then speed = 7000 end

  local step = speed * (elapsed or 0)
  if diff > 0 then
    cur = math.min(tgt, cur + step)
  else
    cur = math.max(tgt, cur - step)
  end

  self.frame:SetWidth(cur)
  self:_ApplyRowWidths(cur)
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

  local t = e.kosType

  -- KoS / Guild-KoS: keep the strong alert behavior (sound + flash) exactly as before.
  local isKoS = IsKosLike(t)

  if isKoS then
    -- Mark strong alert as consumed for this presence so Notifier does not
    -- re-fire sound/flash while the player remains in the Nearby list.
    local key = (e.name and e.name:lower()) or nil
    if key then self.strongAlerted[key] = true end
    if prof.enableSound ~= false and type(N.Sound) == "function" then N:Sound() end
    if prof.enableScreenFlash ~= false and type(N.Flash) == "function" then N:Flash() end
  else
    -- Spy-style "nearby detected" sound when ANY enemy is first added to the nearby list.
    -- This is intentionally separate from KoS alerts to avoid double-playing.
    -- NOTE: Nearby sound is intentionally independent from the main KoS/Guild sound toggle.
    if prof.nearbySound ~= false and type(PlaySoundFile) == "function" then
      PlaySoundFile("Interface/AddOns/KillOnSight/Sounds/detected-nearby.mp3", "Master")
    end
  end
end

-- KoS/Guild alerts should only fire once while the player remains in the Nearby list.
-- Returns two booleans: doChat, doStrong (sound/flash).
function Nearby:ConsumeKoSGuildAnnouncement(name, listType)
  if not name or name == "" then return false, false end
  local isKoS = IsKosLike(listType)
  if not isKoS then return false, false end

  local norm = NormalizeName(name) or name
  local key = tostring(norm):lower()

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


local function SortedEntries(self)
  local activeKoS, inactiveKoS, active, inactive = {}, {}, {}, {}
  local now = (GetTime and GetTime()) or 0
  local DB = GetDB()
  for lower, e in pairs(self.entries) do
    if e and e._key ~= lower then e._key = lower end
    if e then e.kosType = NormalizeKosTypeValue(e.kosType) end
    local skip = false
    if e._kosLayerFilteredUntil and now < e._kosLayerFilteredUntil then
      skip = true
    elseif e._kosLayerFilteredUntil then
      e._kosLayerFilteredUntil = nil
    end
    if not skip then
      -- Re-evaluate kosType from live DB so add/remove from any UI path is
      -- reflected immediately without needing the player to be re-detected.
      if DB then
        local playerKoS = DB.HasPlayer and DB:HasPlayer(e.name)
        local guildKoS  = (not playerKoS) and e.guild and e.guild ~= ""
                          and DB.HasGuild and DB:HasGuild(e.guild)
        if playerKoS then
          e.kosType = KOS_TYPE
        elseif guildKoS then
          e.kosType = GUILD_KOS_TYPE
        elseif IsKosLike(e.kosType) then
          e.kosType = nil
        end
      end
      if IsKosLike(e.kosType) then
        if e.state == "inactive" then
          inactiveKoS[#inactiveKoS+1] = e
        else
          activeKoS[#activeKoS+1] = e
        end
      else
        if e.state == "inactive" then
          inactive[#inactive+1] = e
        else
          active[#active+1] = e
        end
      end
    end
  end

  local function byOrderDesc(a,b)
    return (a.order or 0) > (b.order or 0)
  end
  table.sort(activeKoS, byOrderDesc)
  table.sort(inactiveKoS, byOrderDesc)
  table.sort(active, byOrderDesc)
  table.sort(inactive, byOrderDesc)

  local list = {}
  for i=1,#activeKoS do list[#list+1] = activeKoS[i] end
  for i=1,#inactiveKoS do list[#list+1] = inactiveKoS[i] end
  for i=1,#active do list[#list+1] = active[i] end
  for i=1,#inactive do list[#list+1] = inactive[i] end
  return list
end

local function RowLabel(e, tNow)
  local c = ClassColorHex(e.class)
  local lvl = (e.level and e.level > 0) and tostring(e.level) or "??"

  -- Hidden (stealth/prowl/vanish) is a state separate from KoS/Guild tagging.
  -- We render it as a small icon inline with the text to avoid overlapping
  -- the KoS/Guild tags and to save horizontal space.
  local isHidden = (e.isHidden == true) or (e.kosType == HIDDEN_TYPE)

  local util = _G.KillOnSight_Util
  local normalizedType = NormalizeKosTypeValue(e.kosType)
  local isKoS = (normalizedType == KOS_TYPE)
  local isGuild = (normalizedType == GUILD_KOS_TYPE)
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
        DB:AddPlayer(e.name, KOS_TYPE, nil, UnitName("player"), nil, e.realm, e.fullName, e.guild)
        e.kosType = KOS_TYPE
        self:ScheduleRefresh()
      end
    },
    { text = L.UI_REMOVE_KOS, notCheckable = true, disabled = not has, func = function()
        DB:RemovePlayer(e.name)
        self:ScheduleRefresh()
      end
    },
    { text = L.UI_CLEAR_NEARBY, notCheckable = true, func = function()
        wipe(self.entries)
        wipe(self.alerted)
        self:ScheduleRefresh()
      end
    },
    { text = CLOSE, notCheckable = true },
  }

  UIDropDownMenu_Initialize(self.menu, function(_, level)
    for _, item in ipairs(menu) do
      local info = UIDropDownMenu_CreateInfo()
      for k, v in pairs(item) do info[k] = v end
      UIDropDownMenu_AddButton(info, level)
    end
  end, "MENU")
  ToggleDropDownMenu(1, nil, self.menu, "cursor", 0, 0)
end


local function UpdateScroll(self)
  local list = SortedEntries(self)
  local total = #list
  local offset = FauxScrollFrame_GetOffset(self.scroll)
  local visible = self.visibleRows or #self.rows
  local tNow = Now()

  if self.countFS then
    self.countFS:SetText(string.format((L.UI_NEARBY_COUNT or "Nearby: %d"), total))
  end

  -- IMPORTANT (combat / battleground reliability):
  -- SecureActionButtonTemplate attributes (type/macrotext) are protected during combat.
  -- If we keep trying to reassign row.entry + labels in combat (common in battlegrounds),
  -- the displayed name can diverge from the secure macro target, causing "sometimes" targeting.
  --
  -- Strategy: during combat, do a *visual-only* refresh that never changes secure targeting
  -- bindings for existing rows. Rows that were already displayed remain targetable.
  -- New rows can be shown, but are not targetable until combat ends.
  if InCombatLockdown and InCombatLockdown() then
    self._pendingRefresh = true
    self:QueueLayout()

    local stable = self._combatStableKeys
    if not stable then
      self:SnapshotCombatRows()
      stable = self._combatStableKeys
    end

    -- Build a list of new keys (not already displayed) in current sort order.
    local newKeys = {}
    for _, e in ipairs(list) do
      local k = e and e._key
      if k and not stable[k] then
        newKeys[#newKeys+1] = k
      end
    end

    -- No scrolling in combat (changing visible rows would require re-binding secure attributes).
    offset = 0
    FauxScrollFrame_Update(self.scroll, total, visible, 22)

    local j = 1
    for i = 1, visible do
      local row = self.rows[i]
      local e

      if row and row._entryKey and stable[row._entryKey] then
        e = self.entries[row._entryKey]
        row._notTargetable = nil
      elseif row then
        local k = newKeys[j]
        j = j + 1
        if k then
          row._entryKey = k
          e = self.entries[k]
          row._notTargetable = true
        else
          row._entryKey = nil
          row._notTargetable = nil
        end
      end

      row.entry = e

      if e then
        local DB = GetDB()
        local prof = DB and DB:GetProfile()

        row.text:SetText(RowLabel(e, tNow))
        self._awDirty = true

        if prof and prof.nearbyRowIcons ~= false and row.icon then
          if e.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[e.class] then
            row.icon:SetTexture("Interface\GLUES\CHARACTERCREATE\UI-CHARACTERCREATE-CLASSES")
            local c = CLASS_ICON_TCOORDS[e.class]
            row.icon:SetTexCoord(c[1], c[2], c[3], c[4])
            row.icon:Show()
          else
            row.icon:Hide()
          end
          if row.skull then
            row.skull:SetShown(IsKosLike(e.kosType))
          end
        else
          if row.icon then row.icon:Hide() end
          if row.skull then row.skull:Hide() end
        end

        if e.state == "inactive" then
          row:SetAlpha(0.60)
        else
          row:SetAlpha(1)
        end
        -- Do not call SafeEnableMouse / SetAttribute changes in combat; leave as-is.
      else
        if row then
          row.text:SetText("")
          row:SetAlpha(0)
          if row.icon then row.icon:Hide() end
          if row.skull then row.skull:Hide() end
        end
      end
    end

    return
  end

  for i = 1, visible do
    local idx = offset + i
    local row = self.rows[i]
    local e = list[idx]
    row.entry = e
    row._entryKey = e and e._key or nil
    row._notTargetable = nil

    if e then
      -- Secure targeting: only set while out of combat (protected in combat).
      if row.SetAttribute then
        row:SetAttribute("type1", "macro")
        -- Use macrotext1 (paired with type1). Also set macrotext for maximum compatibility
        -- across client variants that may read the un-suffixed attribute.
        local tname = MacroTargetNameForEntry(e)
        row:SetAttribute("macrotext1", "/targetexact " .. tname)
        row:SetAttribute("macrotext",  "/targetexact " .. tname)
      end

      local DB = GetDB()
      local prof = DB and DB:GetProfile()

      row.text:SetText(RowLabel(e, tNow))
      -- Dynamic width: recompute after rows are populated (fast, single pass).
      self._awDirty = true

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
          row.skull:SetShown(IsKosLike(e.kosType))
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
      row._entryKey = nil
      row._notTargetable = nil
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
      row._entryKey = nil
      row._notTargetable = nil
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

  -- Apply dynamic width after row texts are set/cleared (only out of combat).
  if self._awDirty then
    self._awDirty = nil
    if self._ComputeAutoWidthTarget then
      self:_ComputeAutoWidthTarget()
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
  -- Width animation (auto-fit)
  f:SetScript("OnUpdate", function(_, elapsed)
    if KillOnSight_Nearby and KillOnSight_Nearby._AutoWidthOnUpdate then
      KillOnSight_Nearby:_AutoWidthOnUpdate(elapsed)
    end
  end)


  
-- Hidden measurer FontString for unbounded width calculations (GetStringWidth is clamped when the FS has a width).
local meas = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
meas:Hide()
if meas.SetWordWrap then meas:SetWordWrap(false) end
if meas.SetMaxLines then meas:SetMaxLines(1) end
self._awMeasureFS = meas

-- Title + count like Spy
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetText(L.UI_TITLE)
  self.titleFS = title

  local count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  count:SetText(string.format((L.UI_NEARBY_COUNT or "Nearby: %d"), 0))
  self.countFS = count

  -- Close

  -- Header bar
  local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
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
    local list = SortedEntries(self)
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
  -- Rows
  for i=1,20 do
    local b = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyDown", "AnyUp")

    -- Secure targeting setup.
    -- Use macrotext1 (paired with type1). Also set macrotext for compatibility.
    b:SetAttribute("type1", "macro")
    b:SetAttribute("macrotext1", "/targetexact nil")
    b:SetAttribute("macrotext",  "/targetexact nil")

    b:SetScript("PreClick", function(selfBtn, button)
      if button ~= "LeftButton" then return end
      local e = selfBtn.entry
      if not e then return end
      -- Cannot change secure attributes during combat.
      if InCombatLockdown and InCombatLockdown() then return end
      -- Use full cross-realm name when available; fall back to short name.
      -- Use normalized name for secure /targetexact (strip colors; Classic/TBC remove -Realm suffix).
      local tname = MacroTargetNameForEntry(e)
      if tname == "" then return end
      selfBtn:SetAttribute("macrotext1", "/targetexact " .. tname)
      selfBtn:SetAttribute("macrotext",  "/targetexact " .. tname)
    end)
    b:SetPoint("TOPLEFT", 12, -56 - (i-1)*22)
    b:SetSize((f:GetWidth() or 216) - 36, 22)

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
    b.text:SetWordWrap(false)
    if b.text.SetMaxLines then b.text:SetMaxLines(1) end
    b.text:SetWidth((f:GetWidth() or 216) - 45)
    b.text:SetText("")

    -- (Hidden/stealth indicator is rendered inline in the row text via a texture tag.)

    local function BuildNearbyTooltip(btn)
      local e = btn.entry
      if not e then return end
      GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
      GameTooltip:ClearLines()
      GameTooltip:AddLine(e.name)
      if e.level then GameTooltip:AddLine((L.TT_LEVEL_FMT):format(e.level > 0 and e.level or "??"), 1,1,1) end
      if e.guild and e.guild ~= "" then GameTooltip:AddLine(e.guild, 0.8,0.8,0.8) end
      if e.zone and e.zone ~= "" then GameTooltip:AddLine(e.zone, 0.8,0.8,0.8) end
      local tipType = NormalizeKosTypeValue(e.kosType)
      if tipType == KOS_TYPE then
        GameTooltip:AddLine(L.TT_KOS, 1,0.2,0.2)
      elseif tipType == GUILD_KOS_TYPE then
        GameTooltip:AddLine(L.TT_GUILD_KOS, 1,0.8,0.2)
      elseif (e.isHidden == true) or (tipType == HIDDEN_TYPE) then
        GameTooltip:AddLine("[" .. (HIDDEN_TYPE or "Hidden") .. "]", 0.7,0.7,0.7)
      end
      local now = (GetTime and GetTime()) or 0
      if e._kosNotTargetableUntil and now < e._kosNotTargetableUntil then
        GameTooltip:AddLine(L.TT_NOT_TARGETABLE or "Not targetable right now", 1,0.2,0.2)
      elseif e._kosNotTargetableUntil then
        e._kosNotTargetableUntil = nil
      end
            if btn._notTargetable and InCombatLockdown and InCombatLockdown() then
        GameTooltip:AddLine(L.TT_NOT_TARGETABLE or "Not targetable right now", 1,0.2,0.2)
      end
      GameTooltip:Show()
    end

    local function RefreshNearbyTooltip(btn)
  if not btn then return end
  if GameTooltip and GameTooltip:IsShown() then
    if (GameTooltip.IsOwned and GameTooltip:IsOwned(btn)) or (btn.IsMouseOver and btn:IsMouseOver()) then
      BuildNearbyTooltip(btn)
    end
  elseif btn.IsMouseOver and btn:IsMouseOver() then
    BuildNearbyTooltip(btn)
  end
end

-- If an entry was previously flagged as "not targetable" but later becomes targetable (layer swap / cache),
-- clear the flag immediately while hovering so the tooltip updates without waiting for the timer to expire.
local function MaybeClearTargetableFlags(btn)
  if not btn or not btn.entry then return false end
  local e = btn.entry
  if not (e._kosNotTargetableUntil or e._kosLayerFilteredUntil) then return false end

  local function namesMatch(fullA, fullB)
    if not NormalizeNameForCompare then return (fullA or "") == (fullB or "") end
    return NormalizeNameForCompare(fullA or "") == NormalizeNameForCompare(fullB or "")
  end

  -- Case 1: they are our current target and are now attackable OR friendly (i.e. real unit, not a ghost)
  if UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") then
    local tn, tr = UnitName("target")
    local tfull = tn or ""
    if tr and tr ~= "" then tfull = tfull .. "-" .. tr end
    local entryName = e.fullName or e.name or ""
    if namesMatch(tfull, entryName) then
      local canAttack = UnitCanAttack and UnitCanAttack("player", "target")
      local isFriend = UnitIsFriend and UnitIsFriend("player", "target")
      if canAttack == true or isFriend == true then
        e._kosNotTargetableUntil = nil
        e._kosLayerFilteredUntil = nil
        return true
      end
    end
  end

  -- Case 2 (Classic/TBC/Wrath): nameplate scan for a now-valid unit
  if UnitExists and UnitIsPlayer and UnitCanAttack and UnitIsFriend then
    local entryName = e.fullName or e.name or ""
    for i = 1, 40 do
      local unit = "nameplate" .. i
      if UnitExists(unit) and UnitIsPlayer(unit) then
        local n, r = UnitName(unit)
        local full = n or ""
        if r and r ~= "" then full = full .. "-" .. r end
        if namesMatch(full, entryName) then
          local canAttack = UnitCanAttack("player", unit)
          local isFriend = UnitIsFriend("player", unit)
          if canAttack == true or isFriend == true then
            e._kosNotTargetableUntil = nil
            e._kosLayerFilteredUntil = nil
            return true
          end
        end
      end
    end
  end

  return false
end

-- Tooltip live-refresh while hovering:
-- Updates the tooltip while the cursor stays on the row, so expiring/cleared flags are reflected immediately.
function StopNearbyTooltipTicker(btn)
  if not btn then return end
  if btn._kosTooltipTicker then
    if btn._kosTooltipTicker.Cancel then
      btn._kosTooltipTicker:Cancel()
    end
    btn._kosTooltipTicker = nil
  end
  btn._kosTooltipTicking = nil
end

function StartNearbyTooltipTicker(btn)
  if not btn or btn._kosTooltipTicker or btn._kosTooltipTicking then return end

  local function tick()
    if not btn or not GameTooltip then
      StopNearbyTooltipTicker(btn)
      return
    end
    local hovering = (btn.IsMouseOver and btn:IsMouseOver()) or (GameTooltip.IsOwned and GameTooltip:IsOwned(btn))
    if not hovering then
      StopNearbyTooltipTicker(btn)
      return
    end
    MaybeClearTargetableFlags(btn)
    BuildNearbyTooltip(btn)
  end

  if C_Timer and C_Timer.NewTicker then
    btn._kosTooltipTicker = C_Timer.NewTicker(0.20, tick)
  elseif C_Timer and C_Timer.After then
    btn._kosTooltipTicking = true
    local function loop()
      if not btn or not btn._kosTooltipTicking then return end
      tick()
      if btn and btn._kosTooltipTicking then
        C_Timer.After(0.20, loop)
      end
    end
    C_Timer.After(0.20, loop)
  end
end

b:SetScript("OnEnter", function(selfBtn)
      selfBtn.bg:Show()
      BuildNearbyTooltip(selfBtn)
      StartNearbyTooltipTicker(selfBtn)
    end)
    b:SetScript("OnLeave", function(selfBtn)
      selfBtn.bg:Hide()
      StopNearbyTooltipTicker(selfBtn)
      GameTooltip:Hide()
    end)

    b:SetScript("OnMouseUp", function(selfBtn, btn)
      local e = selfBtn.entry
      if not e then return end
      if btn == "LeftButton" then
        -- Left click targeting is handled by SecureActionButtonTemplate (macrotext1).
        -- After a short delay, verify whether we actually acquired the target.
        local entry = e
        if C_Timer and C_Timer.After then
          C_Timer.After(0.18, function()
  if not entry then return end
  local function checkTarget()
    if not entry then return false end
    if not UnitExists or not UnitExists("target") then return false end
    local tn, tr = UnitName("target")
    if not tn or tn == "" then return false end
    local tfull = tn
    if tr and tr ~= "" then tfull = tn .. "-" .. tr end
    local targetNorm = NormalizeNameForCompare and NormalizeNameForCompare(tfull) or tfull
    local entryNorm  = NormalizeNameForCompare and NormalizeNameForCompare(entry.fullName or entry.name or "") or (entry.fullName or entry.name or "")
    return (targetNorm ~= "" and entryNorm ~= "" and targetNorm == entryNorm)
  end

  local function failNotTargetable()
    local now = (GetTime and GetTime()) or 0
    entry._kosNotTargetableUntil = now + 30
    RefreshNearbyTooltip(selfBtn)
  end

  -- First check shortly after the secure macro runs.
  if checkTarget() then
    entry._kosNotTargetableUntil = nil
    entry._kosLayerFilteredUntil = nil
    RefreshNearbyTooltip(selfBtn)
    return
  end

  -- Retry once more to avoid false "Not targetable" when the client targets slightly late.
  C_Timer.After(0.22, function()
    if checkTarget() then
      entry._kosNotTargetableUntil = nil
      entry._kosLayerFilteredUntil = nil
      RefreshNearbyTooltip(selfBtn)
      return
    end
    failNotTargetable()
  end)
end)
        end
        return
      elseif btn == "RightButton" then
        ShowMenuFor(self, e)
      end
    end)

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
      Nearby:HandleSuppressionChange()
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
  self:HandleSuppressionChange()

  -- Apply saved Nearby font (and keep the auto-width measurer in sync) on startup.
  if self.ApplyNameFont then
    pcall(function() self:ApplyNameFont(true) end)
  end

  UpdateScroll(self)
  self:ApplyAlpha()
  self:ApplyLocked()
  self:ApplyMinimalMode()
  self:StartTicker()
  self:HandleSuppressionChange()
  self:Refresh() -- apply auto-hide immediately
end

function Nearby:ScheduleRefresh()
  if self.refreshScheduled then return end
  self.refreshScheduled = true

  local function doRefresh()
    self.refreshScheduled = false
    self:Refresh()
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(0.10, doRefresh)
  else
    doRefresh()
  end
end

function Nearby:ClearAll(opts)
  opts = opts or {}
  self.entries = {}
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


function Nearby:Seen(name, classFile, guild, kosType, level)
  if not name or name == "" then return end
  if not self.frame then self:Create() end

  local DB = GetDB()
  if not DB then return end
  local prof = DB:GetProfile()
  if prof.showNearbyFrame == false then return end

  -- Hard suppression (sanctuary + optional goblin towns): while suppressed, Nearby is fully disabled and hidden.
  local suppressed = self:IsSuppressed(prof)
  if suppressed then
    self:HandleSuppressionChange()
    return
  end

  local now = Now()
  local ttl = ACTIVE_TTL -- seconds to keep a player in the list since last sighting
  local rawName = name
  name = NormalizeName(name) or name
  local key = name:lower()

  local e = self.entries[key]
  local isNew = false
  if not e then
    self.orderCounter = (self.orderCounter or 0) + 1
    e = { name = name, firstSeen = now, order = self.orderCounter, state = "active" }
    self.entries[key] = e
    isNew = true
  end

  e.fullName = rawName or e.fullName
  e.class = NormalizeClass(classFile) or e.class
  e.guild = guild or e.guild
  -- Hidden is a *state* (stealth/prowl/shadowmeld detection). Do not store it as kosType,
  -- otherwise later list-type updates (KoS/Guild) can erase it and the UI can't show both.
  kosType = NormalizeKosTypeValue(kosType)
  if kosType == HIDDEN_TYPE then
    e.isHidden = true
    kosType = nil
  end
  -- If we have a concrete unit level, this was a visible sighting (nameplate/target), so clear Hidden.
  if level ~= nil then
    e.isHidden = nil
  end
  if kosType ~= nil then
    e.kosType = kosType
  end
  e.level = level or e.level
  e.zone = GetRealZoneText() or e.zone
  e.lastSeen = now
  e.state = "active"
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

  self:Refresh()
end

-- Remove a single entry immediately (used to prevent "ghost" nearby entries on clients where
-- nameplates can appear briefly for players on other layers/phases).
function Nearby:ForgetByName(name)
    if not name or name == "" then return end
    local raw = name
    name = NormalizeName(name) or name
    local key = name:lower()
    if not self.entries or not self.entries[key] then return end
    self.entries[key] = nil
    if self.alerted then self.alerted[key] = nil end
    if self.strongAlerted then self.strongAlerted[key] = nil end
    if self.announceAlerted then self.announceAlerted[key] = nil end
    self:ScheduleRefresh()
end

-- Hooked from NAME_PLATE_UNIT_REMOVED so we don't keep players in the Nearby list
-- for up to ACTIVE_TTL seconds after their nameplate is gone (common in TBC due to layering).
function Nearby:OnNameplateRemoved(unit)
    if not unit then return end
    -- If they're still your target/mouseover, let the normal unit events keep them alive.
    if UnitIsUnit and (UnitIsUnit(unit, "target") or UnitIsUnit(unit, "mouseover")) then
        return
    end

    local name = GetUnitNameSafe and GetUnitNameSafe(unit) or nil
    if not name and GetUnitName then
        name = GetUnitName(unit)
    end
    if name then
        self:ForgetByName(name)
    end
end


function Nearby:Refresh()

  -- HARD SUPPRESSION GUARD
  if self._suppressed then
    return
  end

  if not self.frame then self:Create() end
  if InCombatLockdown and InCombatLockdown() then
    -- Defer refresh & any frame Show/Hide calls until combat ends
    self:QueueLayout()
    return
  end

  local DB = GetDB()
  if not DB then return end
  local prof = DB:GetProfile()

  self:ApplyMinimalMode()

  if prof.showNearbyFrame == false then
    SafeSetShown(self.frame, false)
    return
  end

  -- Hard suppression (sanctuary + optional goblin towns): never attempt to show while suppressed.
  local suppressed = self:IsSuppressed(prof)
  if suppressed then
    self:HandleSuppressionChange()
    return
  end

  local now = Now()
  local count = 0

  -- manage expirations (Spy-like): active -> inactive -> remove
  for k, e in pairs(self.entries) do
    local activeExp = e.activeExpiresAt or ((e.lastSeen or now) + ACTIVE_TTL)
    local inactiveExp = e.inactiveExpiresAt or (activeExp + INACTIVE_TTL)

    if now > inactiveExp then
      self.entries[k] = nil
      self.alerted[k] = nil
      self.strongAlerted[k] = nil
      self.announceAlerted[k] = nil
    elseif now > activeExp then
      e.state = "inactive"
      count = count + 1
    else
      e.state = "active"
      count = count + 1
    end
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
