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

-- Retail can return protected/"secret" GUID values in certain PvP/instance contexts.
-- Never use non-string GUIDs as table keys or in comparisons.
local function _ValidPlayerGUID(guid)
  -- In BGs/instances Blizzard may hand addons a protected "secret" value that breaks even simple comparisons.
  -- Never compare or pattern-match the raw value; coerce via tostring inside pcall and validate the result.
  if type(guid) ~= "string" then return nil end
  local ok, s = pcall(tostring, guid)
  if not ok or type(s) ~= "string" then return nil end
  if s == "" then return nil end
  if not s:match("^Player%-") then return nil end
  return s
end

local function _InspectEnabled()
  if not IS_RETAIL then return false end
  if IsInInstance then
    local inInst, instType = IsInInstance()
    if inInst and instType and instType ~= "none" then
      return false
    end
  end
  return true
end


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
  name = nil,

  -- Retail-only: spec detection via Inspect
  _inspectMgr = nil,         -- initialized lazily by _EnsureInspect()
  _inspectEventFrame = nil,


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

-- Font choices for Nearby list player names.
-- 'Default' uses the current GameFontHighlight font.
local NEARBY_NAME_FONTS = {
  ["Morpheus"]      = "Fonts\\MORPHEUS.TTF",
  ["Skurri"]        = "Fonts\\SKURRI.TTF",
  ["Avantgarde"]    = "Interface\\AddOns\\KillOnSight\\Media\\Fonts\\Avantgarde.ttf",
}



-- Custom font support:
-- We do NOT ship proprietary fonts. If you place a font file at:
--   Interface\AddOns\KillOnSight\Media\Fonts\Avantgarde.ttf
-- it will appear as "Avantgarde" in the Nearby name font dropdown.
-- If LibSharedMedia-3.0 is present, we also register it there.
do
  local fontPath = "Interface\\AddOns\\KillOnSight\\Media\\Fonts\\Avantgarde.ttf"
  if _G.LibStub then
    local lsm = _G.LibStub("LibSharedMedia-3.0", true)
    if lsm and lsm.Register then
      pcall(function() lsm:Register("font", "Avantgarde", fontPath) end)
    end
  end
end

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
  if self._nearbyNameFontMap and self._nearbyNameFontChoices then
    -- Font packs can register fonts after login. If LibSharedMedia is present, we
    -- keep the cache but also listen for new registrations and invalidate.
    return
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
  local lsm
  if _G.LibStub then
    lsm = _G.LibStub("LibSharedMedia-3.0", true)
  end
  if lsm and lsm.List and lsm.Fetch then
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
end

function Nearby:GetNameFontChoices()
  BuildNearbyNameFontMap(self)
  return self._nearbyNameFontChoices or { "Default" }
end

function Nearby:ApplyNameFont()
  BuildNearbyNameFontMap(self)
  local DB = GetDB()
  local prof = DB and DB:GetProfile()
  local choice = (prof and prof.nearbyNameFont) or "Default"
  local path = (self._nearbyNameFontMap and self._nearbyNameFontMap[choice]) or NEARBY_NAME_FONTS[choice]
  -- nil means Default

  self._badFontsWarned = self._badFontsWarned or {}

  local sizeChoice = (prof and prof.nearbyNameFontSize)
  if type(sizeChoice) ~= "number" then sizeChoice = nil end

  local defPath, defSize, defFlags
  if GameFontHighlight and GameFontHighlight.GetFont then
    defPath, defSize, defFlags = GameFontHighlight:GetFont()
  end

  if not self.rows then return end
  for _,row in ipairs(self.rows) do
    if row and row.text and row.text.SetFont then
      local curPath, size, flags = row.text:GetFont()
      size = sizeChoice or size or defSize or 12
      flags = flags or defFlags
      local usePath = path or defPath or curPath
      if usePath then
        local ok
        pcall(function()
          ok = row.text:SetFont(usePath, size, flags)
        end)

        -- Some clients can return "true" but keep the previous font if the file is invalid.
        if ok and choice ~= "Default" and path and path ~= "" then
          local appliedPath = select(1, row.text:GetFont())
          if appliedPath == curPath and curPath ~= usePath then
            ok = false
          end
        end

        -- If the chosen font fails to apply (bad path / missing file), fall back to default.
        if not ok and defPath and defPath ~= usePath then
          pcall(function() row.text:SetFont(defPath, size, flags) end)
          if choice ~= "Default" and not self._badFontsWarned[choice] then
            self._badFontsWarned[choice] = true
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
              DEFAULT_CHAT_FRAME:AddMessage("KillOnSight: Font '" .. choice .. "' could not be loaded. Falling back to Default.")
            end
          end
        end
      end
    end
  end

  -- Keep the auto-width measurer in sync with the row font.
  if self._awMeasureFS and self._awMeasureFS.SetFont then
    local usePath = path or defPath
    local size = sizeChoice or defSize or 12
    local flags = defFlags
    pcall(function() self._awMeasureFS:SetFont(usePath or defPath, size, flags) end)
  end

  if self.UpdateDynamicWidth then pcall(function() self:UpdateDynamicWidth() end) end
end


-- Spy-like retention: keep players ACTIVE for this long, then INACTIVE (dimmed) before removal.
local ACTIVE_TTL = 30   -- seconds: considered 'nearby'
local INACTIVE_TTL = 30 -- seconds: keep dimmed before removing


local SafeSetShown

function Nearby:_ShowEntryTooltip(selfBtn, e)
  if not GameTooltip then return end
  GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")

  -- Name
  GameTooltip:AddLine(e.name)

  -- Level
  if e.level then
    GameTooltip:AddLine((L.TT_LEVEL_FMT):format(e.level > 0 and e.level or "??"), 1, 1, 1)
  end

  -- Class (colored)
  if e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class] then
    local c = RAID_CLASS_COLORS[e.class]
    local className =
      (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[e.class]) or
      (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[e.class]) or
      e.class
    GameTooltip:AddLine(className, c.r, c.g, c.b)
  end

  -- Spec (Retail inspect; present when known)
  if e.spec and e.spec ~= "" then
    GameTooltip:AddLine(e.spec, 0.7, 0.9, 1)
  elseif IS_RETAIL and e.guid then
  elseif IS_RETAIL and e.guid then
    -- Only show "Inspecting..." if we actually have an active request queued/pending for this GUID.
    local mgr = self._inspectMgr
    local isPending = mgr and mgr.pending and mgr.pending.guid == e.guid
    local isQueued = mgr and mgr.queued and mgr.queued[e.guid]
    if isPending or isQueued then
      GameTooltip:AddLine(L.TT_SPEC_LOADING or "Inspecting...", 0.7, 0.7, 0.7)
    end
  end

  -- Guild
  if e.guild and e.guild ~= "" then
    GameTooltip:AddLine(e.guild, 0.8, 0.8, 0.8)
  end

  -- Realm
  if e.realm and e.realm ~= "" then
    GameTooltip:AddLine("Realm: " .. e.realm, 0.8, 0.8, 0.8)
  end

  -- Zone
  if e.zone and e.zone ~= "" then
    GameTooltip:AddLine(e.zone, 0.8, 0.8, 0.8)
  end

  if e.kosType == L.KOS then
    GameTooltip:AddLine(L.TT_ON_KOS, 1,0.2,0.2)
  elseif e.kosType == L.GUILD_KOS then
    GameTooltip:AddLine(L.TT_GUILD_KOS, 1,0.8,0.2)
  elseif (e.isHidden == true) or (e.kosType == L.HIDDEN) then
    GameTooltip:AddLine("[" .. (L.HIDDEN or "Hidden") .. "]", 0.7,0.7,0.7)
  end

  GameTooltip:Show()
end

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
  if InCombatLockdown and InCombatLockdown() then return end
  -- Never gate on InCombatLockdown for Nearby; attempt immediately with a pcall guard.
  local ok = pcall(function() obj:EnableMouse(enabled and true or false) end)
  if ok then return end
  -- If it errors (taint/protection), fail silently; Nearby will still function visually.
end

SafeSetShown = function(frame, shown)
  if not frame then return end

  -- Retail BG/instances: SetShown/Show/Hide can be protected in combat.
  if InCombatLockdown and InCombatLockdown() then
    -- Defer until combat ends
    if not _G.__KOS_SAFESET_PEND then _G.__KOS_SAFESET_PEND = {} end
    _G.__KOS_SAFESET_PEND[frame] = shown and true or false

    if not _G.__KOS_SAFESET_FRAME and CreateFrame then
      local f = CreateFrame("Frame")
      f:RegisterEvent("PLAYER_REGEN_ENABLED")
      f:SetScript("OnEvent", function()
        if InCombatLockdown and InCombatLockdown() then return end
        local pend = _G.__KOS_SAFESET_PEND
        if not pend then return end
        _G.__KOS_SAFESET_PEND = {}
        for fr, want in pairs(pend) do
          pcall(function()
            if fr and fr.SetShown then
              fr:SetShown(want)
            elseif fr then
              if want then fr:Show() else fr:Hide() end
            end
          end)
        end
      end)
      _G.__KOS_SAFESET_FRAME = f
    end
    return
  end

  pcall(function()
    if frame.SetShown then
      frame:SetShown(shown and true or false)
    else
      if shown then frame:Show() else frame:Hide() end
    end
  end)
end



-- Safe width setter (Retail/BG combat-safe): defer SetWidth in combat to avoid taint/protected errors.
local function SafeSetWidth(nearbyObj, width)
  if not nearbyObj or not nearbyObj.frame or not nearbyObj.frame.SetWidth then return end

  if InCombatLockdown and InCombatLockdown() then
    -- Defer until combat ends
    if not _G.__KOS_SAFEWIDTH_PEND then _G.__KOS_SAFEWIDTH_PEND = {} end
    _G.__KOS_SAFEWIDTH_PEND[nearbyObj] = width

    if not _G.__KOS_SAFEWIDTH_FRAME and CreateFrame then
      local f = CreateFrame("Frame")
      f:RegisterEvent("PLAYER_REGEN_ENABLED")
      f:SetScript("OnEvent", function()
        if InCombatLockdown and InCombatLockdown() then return end
        local pend = _G.__KOS_SAFEWIDTH_PEND
        if not pend then return end
        _G.__KOS_SAFEWIDTH_PEND = {}
        for obj, w in pairs(pend) do
          pcall(function()
            if obj and obj.frame and obj.frame.SetWidth then
              obj.frame:SetWidth(w)
              if obj._ApplyRowWidths then obj:_ApplyRowWidths(w) end
            end
          end)
          if obj then
            obj._widthAnimating = false
            if obj.frame and obj.frame.SetScript then
              obj.frame:SetScript("OnUpdate", nil)
            end
          end
        end
      end)
      _G.__KOS_SAFEWIDTH_FRAME = f
    end
    return
  end

  pcall(function()
    nearbyObj.frame:SetWidth(width)
    if nearbyObj._ApplyRowWidths then nearbyObj:_ApplyRowWidths(width) end
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

local function ExtractRealm(name)
  if not name or name == "" then return nil end
  name = tostring(name)
  local realm = name:match("%-(.+)$")
  if realm and realm ~= "" then
    return realm
  end
  return nil
end

local function BuildTargetName(entry)
  if not entry then return "" end
  local name = entry.fullName or entry.name or ""
  name = tostring(name)
  name = name:gsub("|c%x%x%x%x%x%x%x%x", "")
             :gsub("|r", "")
             :gsub("|T.-|t", "")
             :gsub("^%s+", "")
             :gsub("%s+$", "")
  if entry.realm and entry.realm ~= "" and not name:find("%-") then
    name = name .. "-" .. entry.realm
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
  if shown then self:_SafeSetShown(self.frame, true) else self:_SafeSetShown(self.frame, false) end
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

  -- Track which entries are already present in the cached list so we can
  -- safely append newly-seen players while sort is frozen (e.g. in combat)
  -- without re-sorting and changing click targets.
  if not self._sortedMap then
    self._sortedMap = {}
  end

  local frozen = self:IsSortFrozen()

  -- If we have no cached list yet, build once even if frozen.
  if self._sortedDirty and (not frozen or #self._sortedList == 0) then
    wipe(self._sortedList)
    wipe(self._sortedMap)
    for _, e in pairs(self.entries) do
      self._sortedList[#self._sortedList + 1] = e
      self._sortedMap[e] = true
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
  elseif frozen and self._sortedDirty then
    -- Sorting is frozen (combat / hover): keep existing order stable, but
    -- ensure newly added entries appear immediately by appending any missing
    -- ones to the end. We'll rebuild+sort properly once unfrozen.
    for _, e in pairs(self.entries) do
      if not self._sortedMap[e] then
        self._sortedList[#self._sortedList + 1] = e
        self._sortedMap[e] = true
      end
    end
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


-- ===== Nearby dynamic width (auto-fit longest visible row) =====
local function Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function Nearby:_ApplyRowWidths(frameWidth)
  if not self.rows then return end
  local inner = math.max(50, (frameWidth or 200) - 24) -- left/right frame padding
  for _, row in ipairs(self.rows) do
    if row and row.SetWidth then
      row:SetWidth(inner)
      if row.text and row.text.SetWidth then
        -- Set a width for clipping, but keep wordwrap off so it never becomes multi-line.
        row.text:SetWidth(math.max(10, inner - 28))
      end
    end
  end
end

function Nearby:_SetWidthTarget(target)
  if not (self.frame and self.frame.SetWidth) then return end

  local DB = GetDB()
  local prof = DB and DB:GetProfile() or {}
  local minW = prof.nearbyMinWidth or 216
  local maxW = prof.nearbyMaxWidth or 450

  target = Clamp(target or minW, minW, maxW)
  self._widthTarget = target


  -- In combat on Retail/BGs, SetWidth can be protected/taint; defer to PLAYER_REGEN_ENABLED.
  if InCombatLockdown and InCombatLockdown() then
    self._widthTarget = target
    SafeSetWidth(self, target)
    return
  end
  -- Immediate mode if disabled
  if prof.nearbyAutoWidth == false then
    SafeSetWidth(self, target)
    return
  end

  if self._widthAnimating then return end
  self._widthAnimating = true

  self.frame:SetScript("OnUpdate", function(_, elapsed)
    if not self._widthTarget then
      self._widthAnimating = false
      self.frame:SetScript("OnUpdate", nil)
      return
    end

    local cur = self.frame:GetWidth() or 0
    local goal = self._widthTarget
    local diff = goal - cur
    if InCombatLockdown and InCombatLockdown() then
      -- Stop animating in combat; width will be applied once combat ends.
      self._widthAnimating = false
      self.frame:SetScript("OnUpdate", nil)
      return
    end
    if math.abs(diff) < 1.0 then
      SafeSetWidth(self, goal)
      self._widthAnimating = false
      self.frame:SetScript("OnUpdate", nil)
      return
    end

    -- Smooth approach: pixels per second
    local speed = Clamp(math.abs(diff) * 12, 1400, 7000) -- faster dynamic speed
    local step = Clamp(diff, -speed * elapsed, speed * elapsed)
    local nextW = cur + step
    SafeSetWidth(self, nextW)
  end)
end

function Nearby:UpdateDynamicWidth()
  if not (self.frame and self.frame.IsShown and self.frame:IsShown()) then return end

  local DB = GetDB()
  local prof = DB and DB:GetProfile() or {}
  if prof.nearbyAutoWidth == false then return end

  local measure = self._awMeasureFS
  local maxText = 0

  if self.rows then
    for _, row in ipairs(self.rows) do
      if row and row:IsShown() and row.text and row.text.GetText then
        local s = row.text:GetText() or ""
        local w = 0
        if measure and measure.SetText and measure.GetStringWidth then
          measure:SetText(s)
          w = measure:GetStringWidth() or 0
        elseif row.text.GetStringWidth then
          w = row.text:GetStringWidth() or 0
        end
        if w > maxText then maxText = w end
      end
    end
  end

  -- Text padding: left inset (18) + right inset (10) + frame padding (24)
  local desired = math.floor(maxText + 18 + 10 + 24 + 0.5)
  self:_SetWidthTarget(desired)
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
        self:ClearAll({ keepShown = true, rescan = true, immediate = true })
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
          local tname = BuildTargetName(e)
          pcall(function()
            row:SetAttribute("type1", "macro")
            if tname ~= "" then
              local macro = "/targetexact " .. tname
              row:SetAttribute("macrotext1", macro)
              row:SetAttribute("macrotext",  macro)
            else
              row:SetAttribute("macrotext1", "/targetexact nil")
              row:SetAttribute("macrotext",  "/targetexact nil")
            end
          end)
        end
      end

      row.text:SetText(RowLabel(e, tNow))

      -- Cache width for dynamic frame sizing
      if row.text and row.text.GetStringWidth then
        row._desiredTextWidth = row.text:GetStringWidth() or 0
      end


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
      if row.SetAttribute and not (InCombatLockdown and InCombatLockdown()) then
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
      if row.SetAttribute and not (InCombatLockdown and InCombatLockdown()) then
        row:SetAttribute("type1", nil)
        row:SetAttribute("macrotext1", nil)
        row:SetAttribute("macrotext", nil)
      end
    end
  end

  if self.UpdateDynamicWidth then pcall(function() self:UpdateDynamicWidth() end) end

  FauxScrollFrame_Update(self.scroll, total, visible, 22)
end

function Nearby:Create()
  if self.frame then return end

  local f = CreateFrame("Frame", "KillOnSight_NearbyFrame", UIParent, "BackdropTemplate")
  f:SetSize(216, 220)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  MakeBackdrop(f)

  -- Auto-width measurer: an unconstrained FontString used to measure full text width.
  -- On some clients, GetStringWidth() on a constrained FontString can return a clamped value.
  local measureFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  measureFS:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -10000, -10000) -- keep it off-screen
  measureFS:SetAlpha(0)
  measureFS:SetText("")
  measureFS:SetWordWrap(false)
  measureFS:SetMaxLines(1)
  self._awMeasureFS = measureFS

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

      local tname = BuildTargetName(e)
      if tname == "" then return end

      -- Set both for broad compatibility.
      pcall(function()
        selfBtn:SetAttribute("type1", "macro")
        local macro = "/targetexact " .. tname
        selfBtn:SetAttribute("macrotext1", macro)
        selfBtn:SetAttribute("macrotext",  macro)
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
    b.text:SetPoint("RIGHT", -10, 0)
    b.text:SetWordWrap(false)
    b.text:SetMaxLines(1)
    b.text:SetText("")

    -- (Hidden/stealth indicator is rendered inline in the row text via a texture tag.)

    b:SetScript("OnEnter", function(selfBtn)
      self:SetHoverFreeze(true)
      selfBtn.bg:Show()
      local e = selfBtn.entry
      if not e then return end

      -- Track which entry is currently shown so we can live-refresh when inspect data arrives.
      self._tooltipOwner = selfBtn
      self._tooltipGuid = e.guid

      -- If spec is not known yet, try to request inspect for the unit currently under mouse/target/focus.
      if IS_RETAIL and (not e.spec or e.spec == "") and e.guid and not InCombatLockdown() then
        local unit = nil
        if UnitGUID then
          if UnitExists and UnitExists("mouseover") and UnitGUID("mouseover") == e.guid then unit = "mouseover"
          elseif UnitExists and UnitExists("target") and UnitGUID("target") == e.guid then unit = "target"
          elseif UnitExists and UnitExists("focus") and UnitGUID("focus") == e.guid then unit = "focus"
          end
        end

        -- If not directly mouseover/target/focus, try nameplate units so spec can be fetched even when the player
        -- isn't currently targeted. (Retail only; harmless elsewhere.)
        if not unit and UnitExists and UnitGUID then
          for i = 1, 40 do
            local u = "nameplate" .. i
            if UnitExists(u) and UnitGUID(u) == e.guid then
              unit = u
              break
            end
          end
        end
        if unit then
          self:_RequestSpecForGuid(e.guid, unit)
        end
      end

      self:_ShowEntryTooltip(selfBtn, e)
    end)
    b:SetScript("OnLeave", function(selfBtn)
      selfBtn.bg:Hide()
      GameTooltip:Hide()
      if self._tooltipOwner == selfBtn then
        self._tooltipOwner = nil
        self._tooltipGuid = nil
      end
      if self.frame and MouseIsOver and not MouseIsOver(self.frame) then
        self:SetHoverFreeze(false)
      end
    end)
    -- Targeting + menu are handled in PreClick (Spy-style secure buttons).

    self.rows[i] = b
  end

  -- Apply user-selected font for the name column.
  if self.ApplyNameFont then self:ApplyNameFont() end

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


  -- Retail-only: Inspect + unit-token signals for spec detection.
  -- Important: On Retail you can only inspect via a live unit token (target/mouseover/nameplate),
  -- so we listen for nameplate/target/mouseover changes and immediately queue an inspect when a
  -- nameplate appears for a Nearby GUID.
  if IS_RETAIL and not self._inspectEventFrame then
    local inf = CreateFrame("Frame")
    inf:RegisterEvent("INSPECT_READY")
    inf:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    inf:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    inf:RegisterEvent("PLAYER_TARGET_CHANGED")
    inf:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    inf:SetScript("OnEvent", function(_, event, arg1)
      -- Disable Retail inspect/nameplate helpers inside instances/BGs (Nearby is suppressed there).
      if IsInInstance then
        local inInst, instType = IsInInstance()
        if inInst and instType and instType ~= "none" then
          return
        end
      end
      if event == "INSPECT_READY" then
        Nearby:_OnInspectReady(arg1)
        return
      end

      -- Helper: if this guid is tracked in Nearby and spec is unknown, request it now.
      local function TryQueueForGuid(guid, unit)
        if not guid or not Nearby.guidToKey then return end
        local key = Nearby.guidToKey[guid]
        if not key then return end
        local entry = Nearby.entries and Nearby.entries[key]
        if not entry then return end
        if entry.spec and entry.spec ~= "" then return end
        Nearby:_RequestSpecForGuid(guid, unit)
      end

      if event == "NAME_PLATE_UNIT_ADDED" then
        local unit = arg1
        if unit and UnitGUID then
          local guid = UnitGUID(unit)
          -- Remember the freshest unit token for this guid.
          Nearby:_EnsureInspect()
        if type(guid) ~= "string" or guid == "" then
          return
        end
        Nearby._inspectMgr.lastUnit[guid] = unit
          TryQueueForGuid(guid, unit)
        end
      elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = arg1
        -- UnitGUID(unit) may already be nil here; clear any lastUnit entries that pointed at this nameplate token.
        Nearby:_EnsureInspect()
        local mgr = Nearby._inspectMgr
        if mgr and mgr.lastUnit and unit and unit ~= "" then
          for g, u in pairs(mgr.lastUnit) do
            if u == unit then
              mgr.lastUnit[g] = nil
            end
          end
        end
      elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitGUID and UnitExists and UnitExists("target") then
          local guid = UnitGUID("target")
          TryQueueForGuid(guid, "target")
        end
      elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if UnitGUID and UnitExists and UnitExists("mouseover") then
          local guid = UnitGUID("mouseover")
          TryQueueForGuid(guid, "mouseover")
        end
      end
    end)
    self._inspectEventFrame = inf
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


function Nearby:RescanVisibleUnits()
  local Detector = _G.KillOnSight_Detector
  if not (Detector and Detector.CheckUnit) then return end

  -- Prefer explicit unit tokens first.
  local tokens = { "target", "mouseover", "focus" }
  for i = 1, #tokens do
    local u = tokens[i]
    if UnitExists and UnitExists(u) then
      pcall(function() Detector:CheckUnit(u, true) end)
    end
  end

  -- Nameplates: modern API (works on many Classic clients too).
  if C_NamePlate and C_NamePlate.GetNamePlates then
    local plates = C_NamePlate.GetNamePlates()
    if plates then
      for i = 1, #plates do
        local plate = plates[i]
        local unit = plate and (plate.namePlateUnitToken or (plate.unitFrame and plate.unitFrame.unit))
        if unit and UnitExists and UnitExists(unit) then
          pcall(function() Detector:CheckUnit(unit, true) end)
        end
      end
    end
  end

  -- Fallback scan: nameplate1..nameplate40 (safe no-op on clients that don't expose these).
  if UnitExists then
    for i = 1, 40 do
      local u = "nameplate" .. i
      if UnitExists(u) then
        pcall(function() Detector:CheckUnit(u, true) end)
      end
    end
  end
end

function Nearby:ClearAll(opts)
  opts = opts or {}

  -- Cancel any queued refresh; otherwise ScheduleRefresh may be blocked until the timer fires.
  if self._refreshTimer and self._refreshTimer.Cancel then
    pcall(function() self._refreshTimer:Cancel() end)
  end
  self._refreshTimer = nil
  self._nextAllowedRefresh = 0

  self.entries = {}
  self.guidToKey = {}
  self.nameToKey = {}
  self.alerted = {}
  self.strongAlerted = {}
  self.announceAlerted = {}
  self.orderCounter = 0
  if self._sortedList then
    wipe(self._sortedList)
  end
  self._sortedDirty = true
  -- Hide immediately in sanctuary mode unless caller requests otherwise.
  if self.frame and not opts.keepShown then
    SafeSetShown(self.frame, false)
  end

  if opts.rescan then
    pcall(function() self:RescanVisibleUnits() end)
  end

  if opts.immediate then
    if self.Refresh then pcall(function() self:Refresh() end) end
  else
    self:ScheduleRefresh(true)
  end
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


-- ===== Retail Inspect-based spec detection =====

-- A single-flight, throttled inspect manager to learn enemy specs on Retail.
-- Goals:
--   * Prefer cached spec immediately (Blizzard-tooltip-like)
--   * Pre-warm cache when a Nearby entry first appears (lightweight throttle)
--   * Avoid repeated inspect requests for the same GUID (cache + backoff)
--   * Refresh open tooltips immediately when INSPECT_READY fires

local SPEC_CACHE_TTL = 60 * 60         -- 1 hour "fresh" cache window (spec rarely matters beyond this)
local INSPECT_RETRY_BACKOFF = 15        -- seconds after a failed attempt before retrying the same GUID
local INSPECT_THROTTLE = 0.30           -- minimum seconds between NotifyInspect calls (Retail rate limits)
local INSPECT_RETRY_SOFT_BACKOFF = 1.5    -- seconds after a transient failure / stale unit token (Retail nameplate churn)

function Nearby:_EnsureInspect()
  if self._inspectMgr then return end
  self._inspectMgr = {
    queue = {},
    queued = {},
    pending = nil,     -- { guid = ..., unit = ..., startedAt = ... }
    lastAt = 0,
    lastUnit = {},     -- guid -> last known unit token
    specCache = {},    -- guid -> { spec = "Fury", ts = GetTime() }
    backoff = {},      -- guid -> retryAt (GetTime)
  }
  -- Retail: drive the inspect queue even when INSPECT_READY never fires.
  -- Without a heartbeat, a single stuck inspect can leave entries showing "Inspecting..." forever.
  if not self._inspectMgr.heartbeat and CreateFrame then
    local hb = CreateFrame("Frame")
    local acc = 0
    hb:SetScript("OnUpdate", function(_, elapsed)
      acc = acc + (elapsed or 0)
      if acc < 0.15 then return end
      acc = 0
      if not self._inspectMgr then return end
      local mgr = self._inspectMgr
      if _InspectEnabled() and (mgr.pending or (mgr.queue and #mgr.queue > 0)) then
        self:_ProcessInspectQueue()
      end
    end)
    self._inspectMgr.heartbeat = hb
  end
end

local function _Now()
  return (GetTime and GetTime()) or time()
end

function Nearby:_SpecCacheGet(guid)
  guid = _ValidPlayerGUID(guid)
  if not guid then return nil end
  self:_EnsureInspect()
  local c = self._inspectMgr.specCache[guid]
  if not c then return nil end
  local now = _Now()
  if (now - (c.ts or 0)) > SPEC_CACHE_TTL then
    self._inspectMgr.specCache[guid] = nil
    return nil
  end
  return c.spec
end

function Nearby:_SpecCacheSet(guid, specName)
  guid = _ValidPlayerGUID(guid)
  if not guid then return end
  if not guid or not specName or specName == "" then return end
  self:_EnsureInspect()
  self._inspectMgr.specCache[guid] = { spec = specName, ts = _Now() }
  -- Clear any backoff on success
  self._inspectMgr.backoff[guid] = nil
end

function Nearby:_InspectBackoffActive(guid)
  guid = _ValidPlayerGUID(guid)
  if not guid then return nil end
  self:_EnsureInspect()
  local t = self._inspectMgr.backoff[guid]
  return t and (_Now() < t)
end

function Nearby:_SetInspectBackoff(guid, seconds)
  guid = _ValidPlayerGUID(guid)
  if not guid then return end
  self:_EnsureInspect()
  local s = seconds or INSPECT_RETRY_BACKOFF
  self._inspectMgr.backoff[guid] = _Now() + s
end

function Nearby:_FindUnitByGuid(guid)
  guid = _ValidPlayerGUID(guid)
  if not guid then return nil end
  if not guid or not UnitExists or not UnitGUID then return nil end
  self:_EnsureInspect()

  -- Fast path: last unit we successfully matched for this guid
  local lu = self._inspectMgr.lastUnit[guid]
  if lu and UnitExists(lu) and UnitGUID(lu) == guid then
    return lu
  end

  -- Common tokens first
  if UnitExists("target") and UnitGUID("target") == guid then return "target" end
  if UnitExists("mouseover") and UnitGUID("mouseover") == guid then return "mouseover" end
  if UnitExists("focus") and UnitGUID("focus") == guid then return "focus" end

  -- Nameplates
  for i = 1, 40 do
    local u = "nameplate" .. i
    if UnitExists(u) and UnitGUID(u) == guid then return u end
  end

  return nil
end


-- Build a lookup of all specialization names (localized) so we can recognize them in tooltips.
local _SPEC_NAME_SET
local function _BuildSpecNameSet()
  if _SPEC_NAME_SET then return _SPEC_NAME_SET end
  local set = {}
  if not IS_RETAIL then _SPEC_NAME_SET = set; return set end

  -- Retail APIs (guarded)
  if GetNumClasses and GetClassInfo and GetNumSpecializationsForClassID and GetSpecializationInfoForClassID then
    local n = GetNumClasses()
    for i = 1, n do
      local className, classFile, classID = GetClassInfo(i)
      if classID then
        local sn = GetNumSpecializationsForClassID(classID)
        for s = 1, sn do
          local _, specName = GetSpecializationInfoForClassID(classID, s)
          if specName and specName ~= "" then
            set[string.lower(specName)] = specName
          end
        end
      end
    end
  end

  _SPEC_NAME_SET = set
  return set
end

local function _StripTooltipText(s)
  if not s then return nil end
  -- remove color codes and textures
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("|T.-|t", "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

-- Retail: If Blizzard tooltip already shows specialization, pick it up immediately (works in War Mode where NotifyInspect is blocked).
function Nearby:_TryResolveSpecFromTooltip(unit)
  if not IS_RETAIL then return nil end
  if not unit or unit == "" or not UnitExists or not UnitExists(unit) then return nil end
  if not C_TooltipInfo or not C_TooltipInfo.GetUnit then return nil end

  local _, _, classID = UnitClass(unit)
  if not classID then return nil end

  local info = C_TooltipInfo.GetUnit(unit)
  if not info or not info.lines then return nil end

  -- Build a class-restricted spec map to prevent cross-class false positives
  local classSpecs = {}
  if GetNumSpecializationsForClassID and GetSpecializationInfoForClassID then
    local n = GetNumSpecializationsForClassID(classID) or 0
    for i = 1, n do
      local _, specName = GetSpecializationInfoForClassID(classID, i)
      if specName and specName ~= "" then
        classSpecs[string.lower(specName)] = specName
      end
    end
  end

  local function checkText(s)
    s = _StripTooltipText(s)
    if not s or s == "" then return nil end
    local lower = string.lower(s)
    local exact = classSpecs[lower]
    if exact then return exact end
    -- Substring match, but only among specs of this class (handles "Fury Warrior" etc.)
    for key, specName in pairs(classSpecs) do
      if string.find(lower, key, 1, true) then
        return specName
      end
    end
    return nil
  end

  for i = 1, #info.lines do
    local line = info.lines[i]
    local spec = checkText(line and line.leftText) or checkText(line and line.rightText)
    if spec then return spec end
  end

  return nil
end


function Nearby:_TryResolveSpecFromUnit(unit)
  if not IS_RETAIL then return nil end
  if not unit or unit == "" then return nil end
  if not UnitExists or not UnitExists(unit) then return nil end
  if not GetInspectSpecialization or not GetSpecializationInfoByID then return nil end

  local specID = GetInspectSpecialization(unit)
  if specID and specID > 0 then
    local _, name = GetSpecializationInfoByID(specID)
    if name and name ~= "" then
      return name
    end
  end
  return nil
end

-- Public-ish entrypoint: try to learn spec for this guid using the best known unit token.
-- This is safe to call frequently; it is cache-aware and throttled.
function Nearby:_RequestSpecForGuid(guid, unit)
  if not _InspectEnabled() then return end
  guid = _ValidPlayerGUID(guid)
  if not guid then return end
  if not IS_RETAIL then return end
  if not guid then return end
  self:_EnsureInspect()

  -- If already cached, apply to entry immediately.
  local cached = self:_SpecCacheGet(guid)
  if cached and cached ~= "" then
    local key = self.guidToKey and self.guidToKey[guid]
    local entry = key and self.entries and self.entries[key]
    if entry and (not entry.spec or entry.spec == "") then
      entry.spec = cached
      self:ScheduleRefresh(true)
      if self._tooltipGuid == guid and self._tooltipOwner and GameTooltip and GameTooltip:IsOwned(self._tooltipOwner) then
        self:_ShowEntryTooltip(self._tooltipOwner, entry)
      end
    end
    return
  end

  if self:_InspectBackoffActive(guid) then return end
  if InCombatLockdown and InCombatLockdown() then return end

  -- Resolve/refresh unit token if not provided.
  if (not unit or unit == "") then
    unit = self:_FindUnitByGuid(guid)
  end
  if not unit or unit == "" then return end

  -- Remember last unit for this guid.
  self._inspectMgr.lastUnit[guid] = unit

  -- If client already has inspect cached for this unit, pick it up immediately.
  local immediate = self:_TryResolveSpecFromUnit(unit)
  if immediate and immediate ~= "" then
    self:_SpecCacheSet(guid, immediate)
    local key = self.guidToKey and self.guidToKey[guid]
    local entry = key and self.entries and self.entries[key]
    if entry then
      entry.spec = immediate
      self:ScheduleRefresh(true)
      if self._tooltipGuid == guid and self._tooltipOwner and GameTooltip and GameTooltip:IsOwned(self._tooltipOwner) then
        self:_ShowEntryTooltip(self._tooltipOwner, entry)
      end
    end
    return
  end

  -- War Mode friendly: Blizzard tooltips often include spec even when NotifyInspect is blocked.
  local tipSpec = self:_TryResolveSpecFromTooltip(unit)
  if tipSpec and tipSpec ~= "" then
    self:_SpecCacheSet(guid, tipSpec)
    local key = self.guidToKey and self.guidToKey[guid]
    local entry = key and self.entries and self.entries[key]
    if entry then
      entry.spec = tipSpec
      self:ScheduleRefresh(true)
      if self._tooltipGuid == guid and self._tooltipOwner and GameTooltip and GameTooltip:IsOwned(self._tooltipOwner) then
        self:_ShowEntryTooltip(self._tooltipOwner, entry)
      end
    end
    return
  end

  -- Queue inspect request (single-flight + throttle)
  local mgr = self._inspectMgr
  if mgr.queued[guid] or (mgr.pending and mgr.pending.guid == guid) then return end
  table.insert(mgr.queue, { guid = guid, unit = unit })
  mgr.queued[guid] = true
  self:_ProcessInspectQueue()
end

-- Called when a new Nearby entry is created (pre-warm).
function Nearby:_PrewarmSpecForEntry(entry, unit)
  if not _InspectEnabled() then return end
  if not IS_RETAIL then return end
  if not entry or not entry.guid then return end
  if entry.spec and entry.spec ~= "" then
    -- keep cache consistent
    self:_SpecCacheSet(entry.guid, entry.spec)
    return
  end
  self:_RequestSpecForGuid(entry.guid, unit)
end

function Nearby:_ProcessInspectQueue()
  if not _InspectEnabled() then return end
  if not IS_RETAIL then return end
  self:_EnsureInspect()
  local mgr = self._inspectMgr
  -- Fail-safe: sometimes INSPECT_READY never returns (out of range, phased, other addons/Blizzard inspect races).
  -- Don't let a single stuck request block the whole queue.
  if mgr.pending then
    local now = _Now()
    local pend = mgr.pending
    local pguid = pend.guid
    local startedAt = pend.startedAt or 0
    -- If the unit token we inspected has gone stale (nameplate churn), don't wait the full timeout.
    local pu = pend.unit
    if pu and type(pguid) == "string" and UnitExists and UnitExists(pu) and UnitGUID and UnitGUID(pu) ~= pguid then
      self:_SetInspectBackoff(pguid, INSPECT_RETRY_SOFT_BACKOFF)
      mgr.pending = nil
    else
      if (now - startedAt) < 5.0 then
        return
      end
      -- Timed out: release and try again later.
      if pguid then
        self:_SetInspectBackoff(pguid, INSPECT_RETRY_SOFT_BACKOFF)
      end
      mgr.pending = nil
    end
  end
  if InCombatLockdown and InCombatLockdown() then return end

  local now = _Now()
  if (now - (mgr.lastAt or 0)) < INSPECT_THROTTLE then return end

  while #mgr.queue > 0 do
    local item = table.remove(mgr.queue, 1)
    local guid, unit = item.guid, item.unit
    mgr.queued[guid] = nil

    if self:_InspectBackoffActive(guid) then
      -- skip for now
    else
      -- Retail: unit tokens (especially nameplates) are volatile. Re-resolve by GUID at inspect-time
      -- to avoid long delays caused by stale unit tokens.
      local resolved = self:_FindUnitByGuid(guid)
      if resolved and resolved ~= "" then
        unit = resolved
      end

      if UnitExists and UnitExists(unit) and UnitGUID and UnitGUID(unit) == guid and UnitIsPlayer and UnitIsPlayer(unit) and (not UnitIsUnit or not UnitIsUnit(unit, "player")) then
        -- Try tooltip spec first (War Mode / hostile inspect restrictions)
        local tipSpec = self:_TryResolveSpecFromTooltip(unit)
        if tipSpec and tipSpec ~= "" then
          self:_SpecCacheSet(guid, tipSpec)
          local key = self.guidToKey and self.guidToKey[guid]
          local entry = key and self.entries and self.entries[key]
          if entry then
            entry.spec = tipSpec
            self:ScheduleRefresh(true)
            if self._tooltipGuid == guid and self._tooltipOwner and GameTooltip and GameTooltip:IsOwned(self._tooltipOwner) then
              self:_ShowEntryTooltip(self._tooltipOwner, entry)
            end
          end
          return
        end

        -- If CanInspect exists and says no, don't enter a stuck "Inspecting..." state.
        if CanInspect and (not CanInspect(unit)) then
          self:_SetInspectBackoff(guid, INSPECT_RETRY_SOFT_BACKOFF)
          return
        end

        mgr.lastUnit[guid] = unit
        NotifyInspect(unit)
        mgr.pending = { guid = guid, unit = unit, startedAt = _Now() }
        mgr.lastAt = now
        return
      else
        -- Couldn't inspect. If the unit token went stale / we couldn't resolve it, apply only a soft backoff
        -- so the spec doesn't sit "loading" for 15s.
        if not unit or unit == "" or (UnitExists and not UnitExists(unit)) or (UnitGUID and UnitExists and UnitExists(unit) and UnitGUID(unit) ~= guid) then
          self:_SetInspectBackoff(guid, INSPECT_RETRY_SOFT_BACKOFF)
        else
          -- out of range/phased/etc.
          self:_SetInspectBackoff(guid)
        end
      end
    end
  end
end

function Nearby:_OnInspectReady(eventGuid)
  if not IS_RETAIL then return end
  if not eventGuid then return end
  self:_EnsureInspect()
  local mgr = self._inspectMgr

  -- Only treat this as "ours" if we actually have a pending request for this GUID.
  -- Blizzard tooltips and other addons can also trigger INSPECT_READY; we should not interfere.
  local isOurs = (mgr.pending and mgr.pending.guid == eventGuid)

  -- Prefer the exact unit token we inspected (most reliable, especially for target/mouseover).
  local unit
  if isOurs and mgr.pending and mgr.pending.unit and mgr.pending.unit ~= "" then
    unit = mgr.pending.unit
  else
    unit = self:_FindUnitByGuid(eventGuid)
  end

  -- Try resolve spec from that unit.
  local specName = unit and self:_TryResolveSpecFromUnit(unit) or nil

  -- If that failed but this was our request, try one more time using any last known unit for this guid.
  if (not specName or specName == "") and isOurs then
    local fallback = self._inspectMgr and self._inspectMgr.lastUnit and self._inspectMgr.lastUnit[eventGuid]
    if fallback and fallback ~= unit then
      specName = self:_TryResolveSpecFromUnit(fallback)
      if specName and specName ~= "" then unit = fallback end
    end
  end

  -- Store on entry/cache (if still present)
  if specName and specName ~= "" then
    self:_SpecCacheSet(eventGuid, specName)
    local key = self.guidToKey and self.guidToKey[eventGuid]
    local entry = key and self.entries and self.entries[key]
    if entry then
      entry.spec = specName
      entry.lastSeen = entry.lastSeen or time()
      self:ScheduleRefresh(true)

      -- If the tooltip for this entry is currently open, rebuild it immediately.
      if self._tooltipGuid == eventGuid and self._tooltipOwner and GameTooltip and GameTooltip:IsOwned(self._tooltipOwner) then
        self:_ShowEntryTooltip(self._tooltipOwner, entry)
      end
    end
  else
    -- Only backoff if this completion was for our own request; otherwise leave it alone.
    if isOurs then
      self:_SetInspectBackoff(eventGuid, INSPECT_RETRY_SOFT_BACKOFF)
    end
  end

  if isOurs then
    -- Let Blizzard/tooltip consumers read the data before we clear it.
    if C_Timer and C_Timer.After and ClearInspectPlayer then
      C_Timer.After(0.05, function()
        pcall(ClearInspectPlayer)
      end)
    elseif ClearInspectPlayer then
      pcall(ClearInspectPlayer)
    end
    mgr.pending = nil
  end

  -- Continue queue
  self:_ProcessInspectQueue()
end

-- =============================================

function Nearby:Seen(name, classFile, guild, kosType, level, guid, unit)
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
  e.realm = ExtractRealm(rawName) or e.realm
  e.class = NormalizeClass(classFile) or e.class
  e.guild = guild or e.guild
    -- Retail-only: pre-warm / learn specialization (cached + throttled).
  if IS_RETAIL and playerGuid then
    if e.spec and e.spec ~= "" then
      self:_SpecCacheSet(playerGuid, e.spec)
    elseif unit and (not e.spec or e.spec == "") then
      self:_RequestSpecForGuid(playerGuid, unit)
    end
  end

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

-- Safe visibility toggles: avoid ADDON_ACTION_BLOCKED during combat lockdown.
function Nearby:_SafeSetShown(frame, shown)
  if not frame or not frame.SetShown then return end

  -- If Nearby is suppressed in instances/BGs, we still must not touch protected UI in combat.
  if InCombatLockdown and InCombatLockdown() then
    self._deferredNearbyShown = shown and true or false
    if not self._nearbyCombatFixFrame and CreateFrame then
      local f = CreateFrame("Frame")
      f:RegisterEvent("PLAYER_REGEN_ENABLED")
      f:SetScript("OnEvent", function()
        if InCombatLockdown and InCombatLockdown() then return end
        local want = self._deferredNearbyShown
        self._deferredNearbyShown = nil
        if want ~= nil and self.frame and self.frame.SetShown then
          pcall(self.frame.SetShown, self.frame, want)
        end
      end)
      self._nearbyCombatFixFrame = f
    end
    return
  end

  pcall(frame.SetShown, frame, shown and true or false)
end




-- =========================================================
-- Midnight Retail Nameplate Auto-Inspect
-- Queues inspect as soon as a nameplate for a GUID appears
-- =========================================================
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

  local function ResolveGUID(unit)
    if unit and UnitIsPlayer and UnitIsPlayer(unit) and UnitGUID then
      return UnitGUID(unit)
    end
  end

  f:SetScript("OnEvent", function(_, event, unit)
    if not _InspectEnabled() then return end

    local guid = _ValidPlayerGUID(ResolveGUID(unit))
    if not guid then return end

    -- Nearby is exposed as a global for cross-file access.
    local NearbyMod = _G.KillOnSight_Nearby
    if not NearbyMod or not NearbyMod._RequestSpecForGuid then return end

    if event == "NAME_PLATE_UNIT_ADDED" then
      -- Nameplate units are the most reliable non-target token for enemy inspection on Retail.
      NearbyMod:_RequestSpecForGuid(guid, unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
      -- If we cached this exact unit token as the last known match, clear it.
      if NearbyMod._inspectMgr and NearbyMod._inspectMgr.lastUnit and NearbyMod._inspectMgr.lastUnit[guid] == unit then
        NearbyMod._inspectMgr.lastUnit[guid] = nil
      end
    end
  end)
end