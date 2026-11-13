-- KillOnSight: Midnight init (Retail / Mainline only)
-- Loads before other files.

local addonName = ...

-- Ensure main SavedVariables table exists.
_G.KillOnSightDB = _G.KillOnSightDB or {}

-- Fork flags
_G.KOS_MIDNIGHT = true

-- Correct addon folder for assets (logo.tga, sounds, etc.)
_G.KOS_ADDON_FOLDER = "KillOnSight"

do
  local _, _, _, build = GetBuildInfo()
  _G.KOS_CLIENT_BUILD = tonumber(build) or 0
end
