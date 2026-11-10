-- Activity.lua
-- Activity notifications disabled (nearby-only mode).
-- Provide a stub module so core can safely reference it.

KillOnSight_Activity = KillOnSight_Activity or {}

function KillOnSight_Activity:OnCombatLog()
  -- intentionally noop
end
