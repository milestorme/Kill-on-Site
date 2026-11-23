-- Profile-scoped alert volume using pre-rendered sound levels.
-- WoW PlaySoundFile does not expose per-play gain.
KillOnSight_AlertAudio = {}
function KillOnSight_AlertAudio:Play(kind)
  local db = KillOnSight_DB
  local prof = db and db.GetProfile and db:GetProfile()
  local volume = prof and tonumber(prof.alertVolume) or 100
  volume = math.max(0, math.min(100, volume))
  if volume == 0 then return end
  local level = math.max(1, math.min(10, math.floor(volume / 10 + 0.5)))
  if kind ~= "kos" and kind ~= "nearby" and kind ~= "stealth" and kind ~= "targeted" then return end
  local soundKind = kind
  if kind == "targeted" then
    local choice = prof and prof.targetedSoundChoice or "high-threat"
    if choice == "nearby" then
      soundKind = "nearby"
    elseif choice == "radar" or choice == "siren" or choice == "pulse" or choice == "chime" then
      soundKind = "target-" .. choice
    else
      soundKind = "target-high-threat"
    end
  end
  local path = ("Interface\\AddOns\\KillOnSight\\Sounds\\Volumes\\%s-%02d.mp3"):format(soundKind, level)
  local played = PlaySoundFile(path, "Master")
  -- If the game rejects a bundled file, use the original addon sound rather
  -- than silently dropping the alert. Do not fall back at 0% volume.
  if played == false then
    if kind == "kos" then
      PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    else
      local fallback = (kind == "stealth") and "detected-stealth.mp3" or "detected-nearby.mp3"
      PlaySoundFile("Interface\\AddOns\\KillOnSight\\Sounds\\" .. fallback, "Master")
    end
  end
end
