-- Portrait.lua
-- TargetFrame portrait ring for Classic-era clients.
--   Player KoS  -> Rare (silver) dragon frame
--   Guild KoS   -> Elite (gold) dragon frame

local f = CreateFrame("Frame")

local ORIGINAL_TEXTURE
local ORIGINAL_VC

local function NormalizeName(name)
  if not name then return nil end
  return name:match("^([^%-]+)") or name
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
  local n = UnitName and UnitName("target")
  local r
  if UnitFullName then
    local _n, _r = UnitFullName("target")
    if _r and _r ~= "" then r = _r end
  end
  local short = NormalizeName(n)
  if not short then return false end

  local DB = _G.KillOnSight_DB
  if not DB or not DB.GetData then return false end
  local data = DB:GetData()
  if not data or not data.players then return false end

  local keyShort = short:lower()
  if data.players[keyShort] then return true end

  if r and r ~= "" then
    local keyFull = (n .. "-" .. r):lower()
    if data.players[keyFull] then return true end
  end

  return false
end

local function IsGuildKoSTarget()
  if not UnitExists("target") or not UnitIsPlayer("target") then return false end
  local guildName = GetGuildInfo("target")
  if not guildName or guildName == "" then return false end

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
    -- Restore only the texture we changed. Don't call Blizzard's
    -- TargetFrame_CheckClassification here - it reflows/reveals other parts
    -- of the default Target frame, which conflicts with frame-skinning addons
    -- (e.g. Easy Frames) that have hidden or replaced those default pieces.
    ApplyBorder("none")
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
    -- Non-KoS player: restore our own texture only (see note above about
    -- avoiding TargetFrame_CheckClassification for frame-skin compatibility).
    ApplyBorder("none")
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

  -- Normal NPC: restore our own texture only.
  ApplyBorder("none")
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
