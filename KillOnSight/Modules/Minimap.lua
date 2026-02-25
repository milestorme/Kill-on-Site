-- Minimap.lua (LibDataBroker + LibDBIcon)
-- This is the "Auto Junk Destroyer" proven pattern for perfect minimap alignment + saved position.
local ADDON_NAME = ...
local L = KillOnSight_L
if type(L) ~= "table" then
  local _lf = { KOS = "KoS", GUILD_KOS = "Guild KoS", HIDDEN = "Hidden" }
  L = setmetatable({}, { __index = function(_, k) return _lf[k] or tostring(k) end })
end
local function GetDB() return _G.KillOnSight_DB end

local function Loc(key, fallback)
  return (L and L[key]) or fallback
end

local Minimap = {}
local icon, LDB, dataobj

local function EnsureBrokerLibs()
  if icon and LDB and dataobj then return true end
  if type(LibStub) ~= "function" then return false end

  local okIcon, libIcon = pcall(LibStub, "LibDBIcon-1.0", true)
  local okLDB, libLDB = pcall(LibStub, "LibDataBroker-1.1", true)
  if not okIcon or not okLDB or not libIcon or not libLDB then return false end

  icon, LDB = libIcon, libLDB
  dataobj = LDB:NewDataObject("Kill on Sight", {
    type = "data source",
    text = Loc("UI_TITLE", "Kill on Sight"),
    icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8", -- skull raid marker
  })

  function dataobj:OnTooltipShow()
    self:AddLine(Loc("TT_MINIMAP_TITLE", "Kill on Sight"))
    self:AddLine(Loc("TT_MINIMAP_LEFTCLICK", "Left-click: Toggle window"), 1,1,1)
    self:AddLine(Loc("TT_MINIMAP_RIGHTCLICK", "Right-click: Open menu"), 1,1,1)
  end

  function dataobj:OnClick(btn)
    if btn == "LeftButton" then
      if KillOnSight_GUI and KillOnSight_GUI.Toggle then
        KillOnSight_GUI:Toggle()
      end
    elseif btn == "RightButton" then
      local DB = GetDB()
      if not DB then return end
      local prof = DB:GetProfile()
      prof.minimap = prof.minimap or { hide=false, minimapPos=220 }

      local isPlayerTarget = UnitExists("target") and UnitIsPlayer("target")
      local tName = isPlayerTarget and UnitName("target") or nil
      local already = false
      if tName and tName ~= "" then
        if DB.HasPlayer then
          already = DB:HasPlayer(tName)
        elseif DB.LookupPlayer then
          already = DB:LookupPlayer(tName) ~= nil
        end
      end

      local menu = {
        { text = Loc("UI_TITLE", "Kill on Sight"), isTitle = true, notCheckable = true },
        { text = Loc("UI_ADD_KOS_TARGET", "Add target to KoS"), notCheckable = true, disabled = (not isPlayerTarget) or already, func = function()
            if not (UnitExists("target") and UnitIsPlayer("target")) then
              if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00d0ff"..Loc("ADDON_PREFIX", "KillOnSight")..":|r "..Loc("ERR_NO_PLAYER_TARGET", "No player target selected."))
              end
              return
            end
            local name = UnitName("target")
            if (DB.HasPlayer and DB:HasPlayer(name)) or (DB.LookupPlayer and DB:LookupPlayer(name)) then
              return
            end
            local kosType = Loc("KOS", "KoS")
            DB:AddPlayer(name, kosType, nil, UnitName("player"))
            if KillOnSight_Notifier and type(KillOnSight_Notifier.Chat) == "function" then
              KillOnSight_Notifier:Chat(string.format(Loc("ADDED_PLAYER", "Added %s: %s"), kosType, name))
            end
            if KillOnSight_Nearby and KillOnSight_Nearby.Refresh then
              KillOnSight_Nearby:Refresh()
            end
            if KillOnSight_GUI and KillOnSight_GUI.RefreshAll then
              KillOnSight_GUI:RefreshAll()
            end
          end
        },
        { text = Loc("UI_SYNC", "Sync"), notCheckable = true, func = function()
            if KillOnSight_Sync and KillOnSight_Sync.RequestDiff then
              KillOnSight_Sync:RequestDiff()
            end
          end
        },
        { text = Loc("UI_CLOSE", "Close"), notCheckable = true, func = function() if KillOnSight_GUI then KillOnSight_GUI:Hide() end end },
      }
      ShowDropdown(menu)
    end
  end

  return true
end

local function ShowDropdown(menuTable)
  if not Minimap._menuFrame then
    Minimap._menuFrame = CreateFrame("Frame", "KillOnSight_MinimapMenu", UIParent, "UIDropDownMenuTemplate")
  end
  local f = Minimap._menuFrame
  UIDropDownMenu_Initialize(f, function(self, level)
    for _,item in ipairs(menuTable) do
      local info = UIDropDownMenu_CreateInfo()
      for k,v in pairs(item) do info[k] = v end
      UIDropDownMenu_AddButton(info, level)
    end
  end, "MENU")
  ToggleDropDownMenu(1, nil, f, "cursor", 0, 0)
end

function Minimap:Create()
  local DB = GetDB()
  if not DB then return end
  if not EnsureBrokerLibs() then return end
  local prof = DB:GetProfile()
  prof.minimap = prof.minimap or { hide=false, minimapPos=220 }
  if not icon:IsRegistered("KillOnSight") then
    icon:Register("KillOnSight", dataobj, prof.minimap)
  end
  icon:Refresh("KillOnSight", prof.minimap)
end

KillOnSight_Minimap = Minimap
