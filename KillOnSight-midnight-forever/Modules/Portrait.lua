-- Portrait.lua (Retail / Midnight only)
-- Overlay ring anchored to modern TargetFrame portrait.
--
-- Player KoS  -> Rare (silver) ring
-- Guild KoS   -> Elite (gold) ring
--
-- We do NOT re-skin Blizzard's own TargetFrame textures.
-- We render our own overlay texture so we don't stretch/mis-size the default UI assets.

local f = CreateFrame("Frame")

local function InRestrictedInstance()
  if not IsInInstance then return false end
  local ok, inInst, instType = pcall(IsInInstance)
  if not ok then return true end  -- assume restricted on error
  if not inInst then return false end
  local okCmp, isOpenWorld = pcall(function() return instType == "none" end)
  if not okCmp or not isOpenWorld then return true end
  return false
end

local function SafeToString(v)
  local ok, result = pcall(function()
    if type(v) ~= "string" then return nil end
    if v == "" then return nil end
    return v
  end)
  if not ok then return nil end
  return result
end

local function NormalizeName(name)
  local s = SafeToString(name)
  if not s then return nil end
  local ok, short = pcall(string.match, s, "^([^%-]+)")
  if not ok then return nil end
  return short or s
end

local function GetDataTables()
  local DB = _G.KillOnSight_DB
  if DB and DB.GetData then
    local data = DB:GetData()
    if data then
      return data.players, data.guilds
    end
  end
  return nil, nil
end

local function IsKoSTarget()
  if InRestrictedInstance() then return false end
  if not UnitExists("target") or not UnitIsPlayer("target") then return false end
  local rawN, rawR = UnitName("target")
  local n = SafeToString(rawN)
  local realm = SafeToString(rawR)
  local short = NormalizeName(n)
  if not short then return false end

  local players = select(1, GetDataTables())
  if not players then return false end

  local keyShort = short:lower()
  if players[keyShort] then return true end

  if realm then
    local keyFull = (n .. "-" .. realm):lower()
    if players[keyFull] then return true end
  end

  return false
end

local function IsGuildKoSTarget()
  if InRestrictedInstance() then return false end
  if not UnitExists("target") or not UnitIsPlayer("target") then return false end
  local rawGuildName = GetGuildInfo("target")
  local guildName = SafeToString(rawGuildName)
  if not guildName then return false end

  local _, guilds = GetDataTables()
  if not guilds then return false end

  return guilds[guildName:lower()] ~= nil
end

-- Overlay texture management
local OVERLAY_TEX
local OVERLAY_PARENT
local OVERLAY_ANCHOR

local function GetTargetPortraitFrame()
  if _G.TargetFrame and _G.TargetFrame.TargetFrameContainer then
    local c = _G.TargetFrame.TargetFrameContainer
    if c.Portrait then
      return c.Portrait
    end
  end

  if _G.TargetFrame and _G.TargetFrame.portrait then
    return _G.TargetFrame.portrait
  end

  return nil
end

local function GetOverlayBaseSize(anchor)
  local w = (anchor and anchor.GetWidth and anchor:GetWidth()) or 0
  local h = (anchor and anchor.GetHeight and anchor:GetHeight()) or 0
  local size = math.max(w, h)
  if not size or size <= 0 then
    size = 64
  end

  local ringScale = 1.55
  size = math.floor(size * ringScale + 0.5)
  return size, size
end

local function EnsureOverlay()
  local anchor = GetTargetPortraitFrame()
  if not anchor then return nil end

  -- The "portrait" is often a Texture object, not a Frame.
  -- Textures do not have :CreateTexture(), so we create our overlay on the parent frame,
  -- but keep it anchored to the portrait region for perfect alignment.
  local parent = (anchor.CreateTexture and anchor) or (anchor.GetParent and anchor:GetParent()) or _G.TargetFrame
  if not parent or not parent.CreateTexture then return nil end

  if OVERLAY_TEX and OVERLAY_PARENT == parent and OVERLAY_ANCHOR == anchor then
    return OVERLAY_TEX
  end

  OVERLAY_PARENT = parent
  OVERLAY_ANCHOR = anchor

  OVERLAY_TEX = parent:CreateTexture(nil, "OVERLAY", nil, 7)
  OVERLAY_TEX:ClearAllPoints()
  OVERLAY_TEX:SetPoint("CENTER", anchor, "CENTER", 0, 0)

  local w, h = GetOverlayBaseSize(anchor)
  if OVERLAY_TEX.SetSize then
    OVERLAY_TEX:SetSize(w, h)
  end

  OVERLAY_TEX:Hide()
  return OVERLAY_TEX
end

local function ApplyOverlay(mode)
  local tex = EnsureOverlay()
  if not tex then return end

  if mode == "none" then
    tex:Hide()
    return
  end

  local anchor = OVERLAY_ANCHOR or GetTargetPortraitFrame() or tex

  local w, h = GetOverlayBaseSize(anchor)
  local offsetX = 0

  if mode == "rare" then
    w = math.floor(w * 0.88 + 0.5)
    h = w
    offsetX = 4
  end

  if mode == "elite" then
    w = math.floor(w * 0.94 + 0.5)
    h = w
    offsetX = 12
  end

  tex:ClearAllPoints()
  tex:SetPoint("CENTER", anchor, "CENTER", offsetX, 0)
  if tex.SetSize then tex:SetSize(w, h) end

  local function TryAtlas(list)
    if not tex.SetAtlas then return false end
    for _, a in ipairs(list) do
      local ok = pcall(function()
        tex:SetAtlas(a, false)
      end)
      if ok then
        return true
      end
    end
    return false
  end

  local applied = false

  if mode == "rare" then
    applied = TryAtlas({
      "ui-hud-unitframe-target-portraiton-boss-rare-silver",
      "ui-hud-unitframe-target-portraiton-boss-rare-silver-2x",
      "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare",
    })

    if not applied then
      tex:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Rare")
      tex:SetTexCoord(0, 1, 0, 1)
    end
  else
    applied = TryAtlas({
      "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged",
      "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold",
      "ui-hud-unitframe-target-portraiton-boss-gold-winged",
      "ui-hud-unitframe-target-portraiton-boss-gold",
    })

    if not applied then
      tex:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Elite")
      tex:SetTexCoord(0, 1, 0, 1)
    end
  end

  if tex.SetVertexColor then tex:SetVertexColor(1, 1, 1, 1) end
  tex:Show()
end

-- Do NOT touch Blizzard's TargetFrame frame textures.
-- On modern Retail unitframes, these textures are atlas-driven; calling :SetTexture()
-- on them can break the entire TargetFrame (missing art / displaced regions).
local function RestoreTargetFrameArt()
  if _G.TargetFrame_Update then
    pcall(_G.TargetFrame_Update, _G.TargetFrame)
  end
  if _G.TargetFrame_CheckClassification then
    pcall(_G.TargetFrame_CheckClassification, _G.TargetFrame)
  end
end

local function IsArenaInstance()
  if not IsInInstance then return false end
  local ok, inInstance, instType = pcall(IsInInstance)
  if not ok then return false end
  if not inInstance then return false end
  local okCmp, isArena = pcall(function() return instType == "arena" end)
  return (okCmp and isArena) or false
end

local function Update()
  local Core = _G.KillOnSight_Core
  if Core and Core._bgDisabled and IsArenaInstance() then
    ApplyOverlay("none")
    RestoreTargetFrameArt()
    return
  end

  if not UnitExists("target") then
    ApplyOverlay("none")
    RestoreTargetFrameArt()
    return
  end

  if UnitIsPlayer("target") then
    if IsKoSTarget() then
      ApplyOverlay("rare")
    elseif IsGuildKoSTarget() then
      ApplyOverlay("elite")
    else
      ApplyOverlay("none")
      RestoreTargetFrameArt()
    end
    return
  end

  -- NPCs: never apply rings.
  ApplyOverlay("none")
  RestoreTargetFrameArt()
end

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
f:RegisterEvent("UNIT_NAME_UPDATE")
f:RegisterEvent("ADDON_LOADED")

f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == "Blizzard_TargetingUI" or arg1 == "KillOnSight" then
      C_Timer.After(0.1, Update)
    end
    return
  end

  if event == "UNIT_CLASSIFICATION_CHANGED" or event == "UNIT_NAME_UPDATE" then
    if arg1 ~= "target" then return end
  end

  Update()
  if event == "PLAYER_TARGET_CHANGED" and UnitExists("target") and (not UnitIsPlayer("target")) then
    C_Timer.After(0.15, Update)
    C_Timer.After(0.45, Update)
  end
end)

C_Timer.After(0.2, RestoreTargetFrameArt)
