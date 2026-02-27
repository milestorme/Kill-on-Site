-- SpyImport.lua
-- Optional helper to import Spy's KoS list into KillOnSight.
--
-- Notes:
-- * Spy's SavedVariables (SpyPerCharDB / SpyDB) are only loaded by WoW if Spy is enabled at least once.
-- * We intentionally do NOT change any KillOnSight logic. This only adds entries to the KoS list.

local L = KillOnSight_L

local Import = {}

local function Print(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00d0ff"..(L and L.ADDON_PREFIX or "KILLONSIGHT")..":|r "..tostring(msg))
  end
end

local function BuildReasonText(playerData)
  local r = playerData and playerData.reason
  if type(r) ~= "table" then return nil end
  local parts = {}
  for k, v in pairs(r) do
    if v == true then
      parts[#parts+1] = tostring(k)
    elseif type(v) == "string" and v ~= "" then
      parts[#parts+1] = v
    end
  end
  if #parts == 0 then return nil end
  table.sort(parts)
  return table.concat(parts, ", ")
end

-- Import SpyPerCharDB.KOSData into KillOnSight's player list.
-- Returns: importedCount, skippedCount
function Import:ImportPerCharacter()
  local DB = _G.KillOnSight_DB
  if not DB or not DB.AddPlayer then
    Print("Import failed: KillOnSight DB not ready.")
    return 0, 0
  end

  local spy = _G.SpyPerCharDB
  local kos = spy and spy.KOSData
  if type(kos) ~= "table" then
    Print("Spy KoS data not found. Enable Spy once (so its SavedVariables load), then /reload and try again.")
    return 0, 0
  end

  local playerData = (spy and spy.PlayerData) or {}
  local imported, skipped = 0, 0

  for name in pairs(kos) do
    if type(name) == "string" and name ~= "" then
      if DB.LookupPlayer and DB:LookupPlayer(name) then
        skipped = skipped + 1
      else
        local pd = playerData[name]
        local class = pd and pd.class
        local reason = BuildReasonText(pd)
        DB:AddPlayer(name, nil, reason, "Spy Import", class)
        imported = imported + 1
      end
    end
  end

  return imported, skipped
end

-- Public helper called by /kos importspy
function Import:Run()
  local imported, skipped = self:ImportPerCharacter()
  if imported == 0 and skipped == 0 then
    Print(L.UI_IMPORTSPY_NONE or "Spy import complete - no new KoS entries found.")
  else
    Print(string.format((L.UI_IMPORTSPY_RESULT or "Spy import complete: %d added, %d already existed."), imported, skipped))
    Print("Tip: You can disable Spy after importing if you only need KillOnSight.")
  end

  -- Refresh the KoS list UI instantly, if it's loaded.
  local gui = _G.KillOnSight_GUI
  if gui and gui.RefreshAll then
    gui:RefreshAll()
  end
end

_G.KillOnSight_SpyImport = Import
