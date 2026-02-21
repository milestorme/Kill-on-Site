-- Notifier.lua
local ADDON_NAME = ...
local L = KillOnSight_L

-- Lazy getter: DB is initialised after file load so we must not capture it at parse time.
local function GetDB() return _G.KillOnSight_DB end

local Notifier = {}

-- Local print helper (avoid relying on a global Print function)
local function _Print(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00d0ff"..(KillOnSight_L and KillOnSight_L.ADDON_PREFIX or "KILLONSIGHT")..":|r "..tostring(msg))
  end
end

-- Optional town-level suppression (Classic/TBC-friendly): Booty Bay / Gadgetzan.

-- Optional town-level suppression (Classic/TBC-friendly): Booty Bay / Gadgetzan.
local function IsInGoblinTown()
  local sub = (GetSubZoneText and GetSubZoneText()) or ""
  local mini = (GetMinimapZoneText and GetMinimapZoneText()) or ""
  if sub == "" then sub = mini end
  if mini == "" then mini = sub end

  local bb = (L.SUBZONE_BOOTY_BAY or "Booty Bay")
  local gz = (L.SUBZONE_GADGETZAN or "Gadgetzan")

  return sub == bb or mini == bb or sub == gz or mini == gz
end

local function SuppressInGoblinTown()
  local DB = GetDB()
  if not DB or not DB.GetProfile then return false end
  local prof = DB:GetProfile()
  return prof and prof.disableInGoblinTowns and IsInGoblinTown() or false
end


local function IsInSanctuary()
  -- Note: right after loading/teleporting, GetZonePVPInfo() can briefly return nil.
  -- If we alert during that window, you can get a single "beep" before sanctuary suppression kicks in.
  if GetZonePVPInfo then
    local pvpType = GetZonePVPInfo()

    -- Zone info not ready yet: suppress briefly to avoid one-shot alerts on spawn/teleport.
    if pvpType == nil then
      local now = (GetTime and GetTime()) or 0
      Notifier._pvpNilSince = Notifier._pvpNilSince or now
      if (now - Notifier._pvpNilSince) < 2.0 then
        return true
      end
      return false
    end

    -- Zone info is ready again; clear the timer.
    Notifier._pvpNilSince = nil

    if pvpType == "sanctuary" then
      return true
    end
  end
  return false
end


local function ClassHex(classFile)
  if not classFile or not RAID_CLASS_COLORS or not RAID_CLASS_COLORS[classFile] then
    return nil
  end
  local c = RAID_CLASS_COLORS[classFile]
  local r = math.floor((c.r or 1) * 255 + 0.5)
  local g = math.floor((c.g or 1) * 255 + 0.5)
  local b = math.floor((c.b or 1) * 255 + 0.5)
  return string.format("|cff%02x%02x%02x", r, g, b)
end

local function ColorizeName(name, classFile)
  local hex = ClassHex(classFile)
  if not hex then return name end
  return hex .. name .. "|r"
end

function Notifier:GetStealthTiming()
  local DB = GetDB()
  local prof = DB and DB:GetProfile() or {}
  local hold = tonumber(prof.stealthWarningHoldSeconds) or 6.0
  local fade = tonumber(prof.stealthWarningFadeSeconds) or 1.2
  if hold < 0 then hold = 0 end
  if fade < 0.1 then fade = 0.1 end
  return hold, fade
end

function Notifier:ApplyStealthSettings()
  local DB = GetDB()
  local prof = DB and DB:GetProfile() or {}
  if prof.stealthDetectCenterWarning == false then
    if self.warningFrame then
      self.warningFrame:Hide()
    end
    if self._stealthHoldTimer and self._stealthHoldTimer.Cancel then
      self._stealthHoldTimer:Cancel()
    end
    if self._stealthFadeTicker and self._stealthFadeTicker.Cancel then
      self._stealthFadeTicker:Cancel()
    end
    self._stealthHoldTimer = nil
    self._stealthFadeTicker = nil
  end
end

local CENTER_WARNING_YOFF = 180   -- vertical offset from center
-- Spy-style center warning frame (custom, reliable across client branches)
local function EnsureSpyWarningFrame()
  if Notifier._spyFrame then return Notifier._spyFrame end

  local parent = _G.UIParent or nil
  local f = CreateFrame("Frame", "KillOnSight_SpyWarningFrame", parent)
  f:SetFrameStrata("HIGH")
  f:SetSize(720, 84)
  if parent then
    f:SetPoint("CENTER", parent, "CENTER", 0, CENTER_WARNING_YOFF)
  else
    f:SetPoint("CENTER", 0, CENTER_WARNING_YOFF)
  end
  f:Hide()
  f:SetAlpha(1)

  -- Banner background
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.55)
  f.bg = bg

  -- Thin red top/bottom lines (Spy-ish)
  local top = f:CreateTexture(nil, "BORDER")
  top:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  top:SetHeight(2)
  top:SetColorTexture(1, 0.15, 0.15, 0.9)

  local bottom = f:CreateTexture(nil, "BORDER")
  bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(2)
  bottom:SetColorTexture(1, 0.15, 0.15, 0.9)

  -- Text
  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  fs:SetPoint("CENTER")
  fs:SetJustifyH("CENTER")
  fs:SetJustifyV("MIDDLE")
  fs:SetTextColor(1, 0.12, 0.12)
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(2, -2)
  f.text = fs

  -- Internal fade state
  f._phase = "idle"
  f._t = 0
  f._timer = nil

  Notifier._spyFrame = f
  return f
end

local flashFrame

local function EnsureFlashFrame()
  if flashFrame then return end
  flashFrame = CreateFrame("Frame", nil, UIParent)
  flashFrame:SetAllPoints(UIParent)
  flashFrame:Hide()
  flashFrame.tex = flashFrame:CreateTexture(nil, "BACKGROUND")
  flashFrame.tex:SetAllPoints()
  flashFrame.tex:SetColorTexture(1, 0, 0, 0.18)
end


local function EnsureSpyAlertWindow()
  if Notifier._spyAlertWindow then return Notifier._spyAlertWindow end

  local f = CreateFrame("Frame", "KillOnSight_SpyAlertWindow", UIParent, "BackdropTemplate")
  f:ClearAllPoints()
  f:SetPoint("TOP", UIParent, "TOP", 0, -215)
  f:SetClampedToScreen(true)
  f:SetHeight(42)
  f:Hide()

  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  f:SetBackdropColor(0, 0, 0, 0.90)

  f.Icon = CreateFrame("Frame", nil, f, "BackdropTemplate")
  f.Icon:ClearAllPoints()
  f.Icon:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -5)
  f.Icon:SetSize(32, 32)
  f.Icon:SetBackdrop({ bgFile = "Interface\\Icons\\Ability_Stealth" })
  f.Icon:SetBackdropColor(1, 1, 1, 0.5)

  f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.Title:SetPoint("TOPLEFT", f, "TOPLEFT", 42, -3)
  f.Title:SetHeight(12)
  f.Title:SetText(L.STEALTH_DETECTED_TITLE)


  f.Name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.Name:SetPoint("TOPLEFT", f, "TOPLEFT", 42, -15)
  f.Name:SetHeight(12)

  f.Location = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.Location:SetPoint("TOPLEFT", f, "TOPLEFT", 42, -26)
  f.Location:SetHeight(12)
  f.Location:SetText("")

  -- Visual styling (match Spy defaults)
  local br, bg, bb, ba = 0.6, 0.2, 1.0, 0.4 -- Stealth Border
  f:SetBackdropBorderColor(br, bg, bb, ba)
  f.Title:SetTextColor(0.6, 0.2, 1.0, 1)     -- Stealth Text
  f.Name:SetTextColor(1, 1, 1, 1)           -- Name Text
  f.Location:SetTextColor(1, 0.82, 0, 1)    -- Location Text (unused for stealth)

  Notifier._spyAlertWindow = f
  return f
end


local function _FlashStopWindow(f)
  if not f then return end
  if f._flashTicker then
    f._flashTicker:SetScript("OnUpdate", nil)
    f._flashTicker:Hide()
    f._flashTicker = nil
  end
end

local function _FlashWindow(f)
  if not f then return end
  _FlashStopWindow(f)

  -- Reuse a cached overlay child to avoid leaking a new frame on every alert.
  if not f._kosFlashChild then
    local flash = CreateFrame("Frame", nil, f)
    flash:SetAllPoints(f)
    flash:Hide()
    f._kosFlashChild = flash
  end
  local flash = f._kosFlashChild
  flash:SetAlpha(0.65)
  flash.elapsed = 0
  flash:SetScript("OnUpdate", function(self, dt)
    self.elapsed = self.elapsed + dt
    local a = 0.65 * (1 - (self.elapsed / 0.55))
    if a <= 0 then
      self:SetScript("OnUpdate", nil)
      self:Hide()
    else
      self:SetAlpha(a)
    end
  end)
  f._flashTicker = flash
  flash:Show()
end

function Notifier:ShowSpyStealthAlert(name, classFile)
  local f = EnsureSpyAlertWindow()

  -- Title (localized)
  if f.Title and f.Title.SetText then
    f.Title:SetText(L.STEALTH_DETECTED_TITLE)
  end

  -- Apply class-colored name (Spy-style)
  local coloredName = ColorizeName(name, classFile)
  if f.Name and f.Name.SetText then
    f.Name:SetText(coloredName or (name or ""))
    -- Name position (no class icon)
    f.Name:SetPoint("TOPLEFT", f, "TOPLEFT", 42, -15)
  end

  -- Hide the optional location line for stealth (Spy behavior)
  if f.Location and f.Location.SetText then
    f.Location:SetText("")
  end

  -- Width = max(title, name) + 52 (Spy formula)
  local titleW = (f.Title and f.Title.GetStringWidth and f.Title:GetStringWidth()) or 0
  local nameW  = (f.Name and f.Name.GetStringWidth and f.Name:GetStringWidth()) or 0
  local w = math.max(titleW, nameW) + 52
  if w < 180 then w = 180 end -- keep readable minimum
  f:SetWidth(w)
  if f.Name and f.Name.SetWidth then f.Name:SetWidth(f:GetWidth() - 52) end
  if f.Location and f.Location.SetWidth then f.Location:SetWidth(f:GetWidth() - 52) end

  -- Show + animate (hold then fade)
  f:Show()
  f:SetAlpha(1)

  local hold, fade = 6.0, 1.2
  if self.GetStealthTiming then
    local h, fd = self:GetStealthTiming()
    if h then hold = h end
    if fd then fade = fd end
  end

  -- cancel any existing animation
  if f._kosStealthAnim and f._kosStealthAnim.Cancel then
    f._kosStealthAnim:Cancel()
  end

  -- Start flash pulse (small overlay)
  _FlashWindow(f)

  -- Hold, then fade out smoothly
  if C_Timer and C_Timer.After then
    f._kosStealthAnim = C_Timer.NewTimer(hold, function()
      if not f or not f.IsShown or not f:IsShown() then return end
      local t = 0
      f:SetScript("OnUpdate", function(self, elapsed)
        t = t + elapsed
        local p = t / fade
        if p >= 1 then
          self:SetScript("OnUpdate", nil)
          self:Hide()
          self:SetAlpha(1)
          return
        end
        self:SetAlpha(1 - p)
      end)
    end)
  else
    -- fallback: no timer API, just show
  end
end



-------------------------------------------------
-- Spy-style Stealth Alert Frame (Classic-safe)
-------------------------------------------------
function Notifier:Chat(msg)
  local DB = GetDB()
  if DB and DB.GetProfile and DB:GetProfile().printToChat then
    _Print(msg)
  end
end

function Notifier:Sound()
  local DB = GetDB()
  if not DB or not DB.GetProfile or not DB:GetProfile().enableSound then return end
  PlaySound(SOUNDKIT.RAID_WARNING, "Master")
end

function Notifier:Flash()
  local DB = GetDB()
  if not DB or not DB.GetProfile or not DB:GetProfile().enableScreenFlash then return end
  EnsureFlashFrame()
  flashFrame:Show()
  flashFrame:SetAlpha(0.65)
  flashFrame.elapsed = 0
  flashFrame:SetScript("OnUpdate", function(self, dt)
    self.elapsed = self.elapsed + dt
    local a = 0.65 * (1 - (self.elapsed / 0.55))
    if a <= 0 then
      self:SetScript("OnUpdate", nil)
      self:Hide()
    else
      self:SetAlpha(a)
    end
  end)
end

function Notifier:NotifyPlayer(listType, name, reason)
  if SuppressInGoblinTown() or IsInSanctuary() then return end
  -- Always update the Nearby list first.
  local nearby = _G.KillOnSight_Nearby
  if nearby and nearby.Seen then
    nearby:Seen(name, nil, nil, listType, nil)
  end

  -- Rollback-style behavior requested: KoS/Guild alerts fire ONLY once while the
  -- player remains in the Nearby list (no time-based throttling).
  local doChat, doStrong = true, true
  if nearby and nearby.ConsumeKoSGuildAnnouncement then
    doChat, doStrong = nearby:ConsumeKoSGuildAnnouncement(name, listType)
  end

  if not doChat and not doStrong then return end

  local suffix = reason and (" - "..reason) or ""
  if doChat then
    self:Chat(string.format(L.SEEN, listType, name, suffix))
  end
  if doStrong then
    self:Sound()
    self:Flash()
  end
end

function Notifier:NotifyGuild(listType, name, guild, reason)
  if SuppressInGoblinTown() or IsInSanctuary() then return end
  -- Always update the Nearby list first.
  local nearby = _G.KillOnSight_Nearby
  if nearby and nearby.Seen then
    nearby:Seen(name, nil, guild, listType, nil)
  end

  -- Rollback-style behavior requested: KoS/Guild alerts fire ONLY once while the
  -- player remains in the Nearby list (no time-based throttling).
  local doChat, doStrong = true, true
  if nearby and nearby.ConsumeKoSGuildAnnouncement then
    doChat, doStrong = nearby:ConsumeKoSGuildAnnouncement(name, listType)
  end

  if not doChat and not doStrong then return end

  local suffix = reason and (" - "..reason) or ""
  if doChat then
    self:Chat(string.format(L.SEEN_GUILD, listType, name, guild, suffix))
  end
  if doStrong then
    self:Sound()
    self:Flash()
  end
end


function Notifier:CenterWarning(msg)
  local hold, fade = self:GetStealthTiming()
  if self._stealthHoldTimer and self._stealthHoldTimer.Cancel then self._stealthHoldTimer:Cancel() end
  if self._stealthFadeTicker and self._stealthFadeTicker.Cancel then self._stealthFadeTicker:Cancel() end
  self._stealthHoldTimer = nil
  self._stealthFadeTicker = nil
  if not msg or msg == "" then return end

  local f = EnsureSpyWarningFrame()
  if f and f.text then
    f.text:SetText(msg)
    f:SetAlpha(1)
    f:Show()

    -- Cancel any existing timer
    if f._timer and f._timer.Cancel then
      f._timer:Cancel()
      f._timer = nil
    end

    -- Reset any running OnUpdate fade
    f:SetScript("OnUpdate", nil)
    f._phase = "hold"
    f._t = 0

    -- After hold time, begin fade-out smoothly
    if _G.C_Timer and _G.C_Timer.NewTimer then
      f._timer = _G.C_Timer.NewTimer(hold, function()
        if not f then return end
        f._phase = "fade"
        f._t = 0
        f:SetScript("OnUpdate", function(self, elapsed)
          self._t = (self._t or 0) + elapsed
          local p = self._t / fade
          if p >= 1 then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            self:SetAlpha(1)
            self._phase = "idle"
            return
          end
          self:SetAlpha(1 - p)
        end)
      end)
    else
      -- Very old fallback: do both hold+fade inside OnUpdate
      f._phase = "hold"
      f._t = 0
      f:SetScript("OnUpdate", function(self, elapsed)
        self._t = (self._t or 0) + elapsed
        if self._phase == "hold" then
          if self._t >= hold then
            self._phase = "fade"
            self._t = 0
          end
          return
        end

        local p = self._t / fade
        if p >= 1 then
          self:SetScript("OnUpdate", nil)
          self:Hide()
          self:SetAlpha(1)
          self._phase = "idle"
          return
        end
        self:SetAlpha(1 - p)
      end)
    end

    return
  end

  -- Fallback: UIErrorsFrame (some UIs filter it)
  if _G.UIErrorsFrame and _G.UIErrorsFrame.AddMessage then
    pcall(function() _G.UIErrorsFrame:AddMessage(msg, 1, 0.1, 0.1) end)
    return
  end

  -- Fallback: Raid warning (top-middle).
  if _G.RaidNotice_AddMessage and _G.RaidWarningFrame and _G.ChatTypeInfo then
    _G.RaidNotice_AddMessage(_G.RaidWarningFrame, msg, _G.ChatTypeInfo["RAID_WARNING"])
    return
  end
end
function Notifier:NotifyHidden(name, spellName, guid)
  if SuppressInGoblinTown() or IsInSanctuary() then return end
  local DB = GetDB()
  local prof = DB and DB.GetProfile and DB:GetProfile() or {}

  -- Master stealth toggle (live)
  if prof.stealthDetectEnabled == false then
    return
  end

  local classFile
  if guid and GetPlayerInfoByGUID then
    local _, cls = GetPlayerInfoByGUID(guid)
    classFile = cls
  end

  local coloredName = ColorizeName(name, classFile)
  local label = spellName and (spellName .. ": ") or ""

  -- Chat output (Chat() respects printToChat)
  if prof.stealthDetectChat ~= false then
    self:Chat(string.format(L.SEEN_HIDDEN, label .. coloredName))
  end
  -- Spy-style stealth alert window
  if prof.stealthDetectCenterWarning ~= false then
    self:ShowSpyStealthAlert(name, classFile)
  end
  -- Stealth sound (independent of the main KoS/Guild sound toggle)
  if prof.stealthDetectSound ~= false then
    local ok = pcall(PlaySoundFile, "Interface\\AddOns\\KillOnSight\\Sounds\\detected-stealth.mp3", "Master")
    if not ok then
      PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    end
  end

  if prof.stealthDetectScreenFlash then
    self:Flash()
  end

  -- Add to Nearby list (pass class so row can be colored/iconed)
  if prof.stealthDetectAddToNearby ~= false then
    if _G.KillOnSight_Nearby and _G.KillOnSight_Nearby.Seen then
      _G.KillOnSight_Nearby:Seen(name, classFile, nil, L.HIDDEN, nil)
    end
  end
end

function Notifier:NotifyActivity(listType, name, activity, reason)
  if SuppressInGoblinTown() or IsInSanctuary() then return end
  local suffix = reason and (" - "..reason) or ""
  self:Chat(string.format(L.ACTIVITY, listType, name, activity, suffix))
  self:Sound()
end

KillOnSight_Notifier = Notifier