-- Portrait.lua
-- Client-aware TargetFrame portrait ring.
--
-- Retail (Mainline): overlay ring anchored to modern TargetFrame portrait.
-- Classic-era clients: texture-swap TargetFrame border for perfect alignment.

local function IsRetailMainline()
  if type(WOW_PROJECT_ID) == "number" and type(WOW_PROJECT_MAINLINE) == "number" then
    return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
  end
  -- Fallback for clients that don't expose WOW_PROJECT_* globals:
  -- Use TOC version from GetBuildInfo(). Retail (Mainline) uses 1xx,xxx+.
  local _, _, _, toc = GetBuildInfo()
  if type(toc) == "number" then
    return toc >= 100000
  end
  return false
end

local function RunRetail()
  -- Portrait.lua
  -- Adds an overlay "dragon" ring on the Retail/Classic TargetFrame portrait for KoS targets.
  --
  -- Player KoS  -> Rare (silver) ring
  -- Guild KoS   -> Elite (gold) ring
  --
  -- IMPORTANT: We do NOT re-skin Blizzard's own TargetFrame textures.
  -- We render our own overlay texture so we don't stretch/mis-size the default UI assets.

  local f = CreateFrame("Frame")

  local function InRestrictedInstance()
    if not IsInInstance then return false end
    local inInst, instType = IsInInstance()
    return inInst and instType and instType ~= "none"
  end

  local function SafeToString(v)
    -- In BGs/instances Blizzard may expose protected "secret" values that break even equality checks.
    -- Convert using tostring inside pcall, then coerce to a *plain* Lua string via format inside pcall.
    local ok, s = pcall(tostring, v)
    if not ok then return nil end
    local ok2, plain = pcall(string.format, "%s", s)
    if not ok2 or type(plain) ~= "string" or plain == "" then return nil end
    return plain
  end

  local function NormalizeName(name)
    local s = SafeToString(name)
    if not s then return nil end
    -- Strip realm suffix if present (Name-Realm)
    local short = s:match("^([^%-]+)")
    return short or s
  end

  -- Works with both the current refactor DB object and older direct-table layouts.
  local function GetDataTables()
    local DB = _G.KillOnSight_DB
    if DB and DB.GetData then
      local data = DB:GetData()
      if data then
        return data.players, data.guilds
      end
    end

    -- Legacy/fallback
    if type(DB) == "table" then
      if DB.players or DB.guilds then
        return DB.players, DB.guilds
      end
      if DB.data and (DB.data.players or DB.data.guilds) then
        return DB.data.players, DB.data.guilds
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

  -- ------------------------------------------------------------
  -- Overlay texture management
  -- ------------------------------------------------------------

  local OVERLAY_TEX
  local OVERLAY_PARENT
  local OVERLAY_ANCHOR

  local function GetTargetPortraitFrame()
    -- Retail (Dragonflight / TWW style)
    if _G.TargetFrame and _G.TargetFrame.TargetFrameContainer then
      local c = _G.TargetFrame.TargetFrameContainer
      if c.Portrait then
        return c.Portrait
      end
    end

    -- Classic / legacy
    if _G.TargetFramePortrait then
      return _G.TargetFramePortrait
    end

    -- Fallback: try the portrait region on TargetFrame
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

    -- Tuned for Retail 11.2.7. Classic uses a bit smaller ring.
    local ringScale = 1.55
    if WOW_PROJECT_ID and WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
      ringScale = 1.65
    end

    size = math.floor(size * ringScale + 0.5)
    return size, size
  end

  local function EnsureOverlay()
    local anchor = GetTargetPortraitFrame()
    if not anchor then return nil end

    -- In Retail, the "portrait" we find is often a Texture object, not a Frame.
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
    -- mode: "none" | "rare" | "elite"
    local tex = EnsureOverlay()
    if not tex then return end

    if mode == "none" then
      tex:Hide()
      return
    end

    local anchor = OVERLAY_ANCHOR or GetTargetPortraitFrame() or tex

    -- Base size
    local w, h = GetOverlayBaseSize(anchor)
    local offsetX = 0

    -- Per-mode fit adjustments:
    -- Rare is just slightly too big on Retail target frame, so scale down a touch.
    if mode == "rare" then
      w = math.floor(w * 0.88 + 0.5)
      h = w
  	offsetX = 4
    end

    -- Elite (gold winged) atlas is visually left-heavy, so:
    -- - smaller than rare
    -- - nudged right a bit
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
          -- Use our explicit sizing (no native atlas sizing) to match TargetFrame.
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

  -- ------------------------------------------------------------
  -- IMPORTANT (Retail Midnight): do NOT touch Blizzard's TargetFrame frame textures.
  -- On modern Retail unitframes, these textures are atlas-driven; calling :SetTexture()
  -- on them can break the entire TargetFrame (missing art / displaced regions).
  -- We only render our own overlay ring for KoS/Guild KoS PLAYER targets.
  -- ------------------------------------------------------------

  local function RestoreTargetFrameArt()
    -- Best-effort restore if a previous version swapped textures.
    if _G.TargetFrame_Update then
      pcall(_G.TargetFrame_Update, _G.TargetFrame)
    end
    if _G.TargetFrame_CheckClassification then
      pcall(_G.TargetFrame_CheckClassification, _G.TargetFrame)
    end
  end

  -- ------------------------------------------------------------
  -- Update loop
  -- ------------------------------------------------------------

  local function IsArenaInstance()
    if not IsInInstance then return false end
    local ok, inInstance, instType = pcall(IsInInstance)
    if not ok then return false end
    return (inInstance and instType == "arena") and true or false
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

    -- Players: keep existing KoS/Guild behavior (do not change).
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

    -- NPCs: never apply rings on Retail Midnight.
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
    -- Ensure we only kick on after our addon & the target UI are ready.
    if event == "ADDON_LOADED" then
      if arg1 == "Blizzard_TargetingUI" or arg1 == "KillOnSight" then
        if C_Timer and C_Timer.After then
          C_Timer.After(0.1, Update)
        else
          Update()
        end
      end
      return
    end

    -- Unit events: only refresh when the affected unit is the current target.
    if event == "UNIT_CLASSIFICATION_CHANGED" or event == "UNIT_NAME_UPDATE" then
      if arg1 ~= "target" then return end
    end

    -- Classification data can arrive a split-second after PLAYER_TARGET_CHANGED for some NPCs.
    -- Do an immediate update and a short delayed update to catch late classification.
    Update()
    if event == "PLAYER_TARGET_CHANGED" and C_Timer and C_Timer.After and UnitExists("target") and (not UnitIsPlayer("target")) then
      C_Timer.After(0.15, Update)
      C_Timer.After(0.45, Update)
    end
  end)

  -- Restore any legacy texture swaps once at load.
  if C_Timer and C_Timer.After then
    C_Timer.After(0.2, RestoreTargetFrameArt)
  else
    RestoreTargetFrameArt()
  end
end

local function RunClassic()
  -- Portrait.lua
  -- TargetFrame dragon border (Classic 1.15.8):
  --   Player KoS  -> Rare (silver) dragon frame
  --   Guild KoS   -> Elite (gold) dragon frame
  -- Uses Blizzard's target-frame texture swap for perfect alignment.

  local f = CreateFrame("Frame")

  local ORIGINAL_TEXTURE
  local ORIGINAL_VC

  local function SafeToString(v)
    local ok, s = pcall(tostring, v)
    if not ok or type(s) ~= "string" or s == "" then return nil end
    return s
  end

  local function NormalizeName(name)
    local s = SafeToString(name)
    if not s then return nil end
    -- Strip realm suffix if present (Name-Realm)
    local short = s:match("^([^%-]+)")
    return short or s
  end

  local function GetTargetFrameTexture()
    local tex = _G.TargetFrameTextureFrameTexture
            or (_G.TargetFrameTextureFrame and _G.TargetFrameTextureFrame.Texture)
    if tex and tex.SetTexture then
      return tex
    end

    local holder = _G.TargetFrameTextureFrame
    if holder and holder.GetRegions then
      local regions = { holder:GetRegions() }
      for _, r in ipairs(regions) do
        if r and r.GetObjectType and r:GetObjectType() == "Texture" and r.SetTexture then
          return r
        end
      end
    end

    if _G.TargetFrame and TargetFrame.GetRegions then
      local regions = { TargetFrame:GetRegions() }
      for _, r in ipairs(regions) do
        if r and r.GetObjectType and r:GetObjectType() == "Texture" and r.SetTexture then
          local t = r.GetTexture and r:GetTexture() or nil
          if type(t) == "string" and t:find("UI%-TargetingFrame") then
            return r
          end
        end
      end
    end

    return nil
  end

  local function EnsureOriginal(tex)
    if ORIGINAL_TEXTURE then return end
    if tex and tex.GetTexture then
      ORIGINAL_TEXTURE = tex:GetTexture()
    end
    if tex and tex.GetVertexColor then
      local r,g,b,a = tex:GetVertexColor()
      ORIGINAL_VC = {r,g,b,a}
    end
  end

  local function IsKoSTarget()
    if not UnitExists("target") or not UnitIsPlayer("target") then return false end
    local rawN, rawR = UnitName("target")
    local n = SafeToString(rawN)
    local realm = SafeToString(rawR)
    local short = NormalizeName(n)
    if not short then return false end
    if not n then return false end

    local DB = _G.KillOnSight_DB
    if not DB or not DB.GetData then return false end
    local data = DB:GetData()
    if not data or not data.players then return false end

    local keyShort = short:lower()
    if data.players[keyShort] then return true end

    if realm then
      local keyFull = (n .. "-" .. realm):lower()
      if data.players[keyFull] then return true end
    end

    return false
  end

  local function IsGuildKoSTarget()
    if not UnitExists("target") or not UnitIsPlayer("target") then return false end
    local rawGuildName = GetGuildInfo("target")
    local guildName = SafeToString(rawGuildName)
    if not guildName then return false end

    local DB = _G.KillOnSight_DB
    if not DB or not DB.GetData then return false end
    local data = DB:GetData()
    if not data or not data.guilds then return false end

    return data.guilds[guildName:lower()] ~= nil
  end

  local function ApplyBorder(mode)
    -- mode: "none" | "rare" | "elite"
    local tex = GetTargetFrameTexture()
    if not tex or not tex.SetTexture then return end
    EnsureOriginal(tex)

    if mode == "none" then
      tex:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame")
      if tex.SetVertexColor then
        if ORIGINAL_VC then
          tex:SetVertexColor(ORIGINAL_VC[1], ORIGINAL_VC[2], ORIGINAL_VC[3], ORIGINAL_VC[4] or 1)
        else
          tex:SetVertexColor(1,1,1,1)
        end
      end
      return
    end

    if mode == "rare" then
      tex:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Rare")
      if tex.SetVertexColor then tex:SetVertexColor(1,1,1,1) end
      return
    end

    tex:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Elite")
    if tex.SetVertexColor then tex:SetVertexColor(1,1,1,1) end
  end

  local function Update()
    local Core = _G.KillOnSight_Core
    if Core and Core._bgDisabled then return end
    if not GetTargetFrameTexture() then
      if C_Timer and C_Timer.After then
        C_Timer.After(0.2, Update)
      end
      return
    end

    -- IMPORTANT:
    -- Keep ALL KoS/Guild behavior for PLAYER targets exactly as-is.
    -- Additionally, show Blizzard-style rare/elite dragons for NPC targets.
    if not UnitExists("target") then
      -- Restore whatever Blizzard wants when there's no target.
      if TargetFrame_CheckClassification then
        TargetFrame_CheckClassification(TargetFrame)
      else
        ApplyBorder("none")
      end
      return
    end

    if UnitIsPlayer("target") then
      if IsKoSTarget() then
        ApplyBorder("rare")
        return
      elseif IsGuildKoSTarget() then
        ApplyBorder("elite")
        return
      end
      -- Non-KoS player: restore Blizzard default (no dragon)
      if TargetFrame_CheckClassification then
        TargetFrame_CheckClassification(TargetFrame)
      else
        ApplyBorder("none")
      end
      return
    end

    -- NPC target: ALWAYS show rare/elite dragons based on classification.
    local class = UnitClassification and UnitClassification("target")
    if class == "rare" or class == "rareelite" then
      ApplyBorder("rare")
      return
    elseif class == "elite" or class == "worldboss" then
      ApplyBorder("elite")
      return
    end

    -- Normal NPC: restore Blizzard's normal texture.
    if TargetFrame_CheckClassification then
      TargetFrame_CheckClassification(TargetFrame)
    else
      ApplyBorder("none")
    end
  end


  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("PLAYER_TARGET_CHANGED")
  f:RegisterEvent("GROUP_ROSTER_UPDATE")
  f:RegisterEvent("GUILD_ROSTER_UPDATE")
  f:RegisterEvent("ADDON_LOADED")

  f:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName and addonName ~= "Blizzard_TargetingUI" then return end
    Update()
  end)
end

if IsRetailMainline() then
  RunRetail()
else
  RunClassic()
end
