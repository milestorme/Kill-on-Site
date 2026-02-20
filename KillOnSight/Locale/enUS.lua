-- Locale/enUS.lua
local ADDON_NAME = ...
KillOnSight_L_data = KillOnSight_L_data or {}
KillOnSight_L_used = KillOnSight_L_used or {}
KillOnSight_L = KillOnSight_L or {}

if not KillOnSight_L.__kos_proxy then
  KillOnSight_L.__kos_proxy = true
  setmetatable(KillOnSight_L, {
    __index = function(_, k)
      KillOnSight_L_used[k] = true
      local v = KillOnSight_L_data[k]
      if v == nil then
        return k -- fallback so missing keys are obvious
      end
      return v
    end,
  })
end

local L = KillOnSight_L_data

-- Default (enUS) strings. Other locale files override these keys.

L.ACTIVITY = "%s nearby: %s (%s)%s"
L.ADDED_GUILD = "Added guild to %s: %s"
L.ADDED_PLAYER = "Added player to %s: %s"
L.ADDON_PREFIX = "KILLONSIGHT"
L.CMD_HELP = "Commands: /kos help | show | add [name] | remove <name> | addguild <guild> | removeguild <guild> | list | sync | statsprune"
L.GUILD_KOS = "Guild-KoS"
L.HIDDEN = "Hidden"
L.KOS = "KoS"
L.NOT_FOUND = "Not found: %s"
L.REMOVED_GUILD = "Removed guild: %s"
L.REMOVED_PLAYER = "Removed player: %s"
L.SEEN = "%s spotted nearby: %s%s"
L.SEEN_GUILD = "%s guild spotted nearby: %s (%s)%s"
L.SEEN_HIDDEN = "Hidden detected: %s"
L.SYNC_COOLDOWN = "Sync is on cooldown: %ds remaining."
L.SYNC_DISABLED = "Sync requires being in a guild."
L.SYNC_DONE = "Sync complete."
L.SYNC_RECEIVED = "Received sync data from %s."
L.SYNC_SENT = "Sync request sent."
L.UI_ADD = "Add"
L.UI_ADD_GUILD = "Add Guild"
L.UI_ADD_KOS = "Add KoS"
L.UI_ALERT_NEW = "Alert on new nearby enemy"
L.UI_ATTACKED_AT = "Attacked"
L.UI_CLEAR = "Clear"
L.UI_CLOSE = "Close"
L.UI_FLASH = "Flash"
L.UI_GUILD = "Guild"
L.UI_INSTANCES = "Notify in instances"
L.UI_ALERTS = "KoS / Guild"
L.UI_NEARBY_HEADING = "Nearby"
L.UI_LAST_SEEN = "Last seen"
L.UI_CLASS = "Class"
L.UI_NAME = "Name"
L.UI_NEARBY_ALPHA = "Nearby transparency"
L.UI_NEARBY_AUTOHIDE = "Auto-hide when empty"
L.UI_DISABLE_GOBLIN_TOWNS = "Disable alerts in Booty Bay / Gadgetzan"
L.SUBZONE_BOOTY_BAY = "Booty Bay"
L.SUBZONE_GADGETZAN = "Gadgetzan"
L.UI_NEARBY_FADE = "Fade in/out"
L.UI_NEARBY_FRAME = "Nearby window"
L.UI_NEARBY_LOCK = "Lock nearby window"
L.UI_NEARBY_MINIMAL = "Ultra-minimal nearby window"
L.UI_NEARBY_ROWFADE = "Per-row fade timers"
L.UI_NEARBY_ROWICONS = "Row icons (class/skull)"
L.UI_NEARBY_SCALE = "Nearby window scale"
L.UI_NEARBY_NAME_FONT = "Nearby name font"
L.UI_NEARBY_NAME_SIZE = "Nearby name size"
L.UI_NEARBY_RANGE_CLAMP = "Detection range (Classic feel)"

L.UI_OPTIONS = "Options"

L.UI_OPTIONS_TITLE = "Options"
L.UI_REMOVE = "Remove"
L.UI_SOUND = "Sound"
L.UI_STEALTH = "Stealth Detection"
L.UI_STEALTH_ADD_NEARBY = "Add hidden to Nearby list"
L.UI_STEALTH_BANNER = "Show center warning banner"
L.UI_STEALTH_CHAT = "Chat notification"
L.UI_STEALTH_ENABLE = "Enable stealth detection"
L.UI_STEALTH_FADE = "Banner fade (seconds)"
L.UI_STEALTH_HOLD = "Banner hold (seconds)"
L.UI_STEALTH_SOUND = "Play stealth sound"
L.UI_STEALTH_FLASH = "Flash screen on stealth"
L.UI_SYNC = "Sync Now"
L.UI_TAB_ATTACKERS = "Attackers"
L.UI_TAB_GUILDS = "Guilds"
L.UI_TAB_PLAYERS = "Players"
L.UI_TAB_STATS = "Stats"
L.UI_THROTTLE = "Throttle (sec)"
L.UI_TITLE = "Kill on Sight"
L.UI_TYPE = "Type"
L.UI_ZONE = "Zone"
L.UI_REMOVE_KOS = "Remove KoS"
L.UI_CLEAR_NEARBY = "Clear Nearby List"
L.UI_NEARBY_COUNT = "Nearby: %d"
L.UI_ADD_KOS_TARGET = "Add KoS (target)"
L.ERR_NO_PLAYER_TARGET = "No player targeted."
L.UI_BANNER_TIMING = "Banner Timing"
L.UI_BANNER_HOLD_HELP = "How long the warning stays fully visible before fading."
L.UI_BANNER_FADE_HELP = "How long the warning takes to fade out smoothly."
L.UI_LIST_PLAYERS = "Players: %s"
L.UI_LIST_GUILDS = "Guilds: %s"

L.MSG_LOADED = "Loaded. Type /kos show"

L.UI_NEARBY_HEADER = "Name / Level / Time"



L.STEALTH_DETECTED_TITLE = "Stealth player detected!"

L.UI_STATS_TITLE = "Enemy Statistics"
L.UI_STATS_KOS_TAG = "KoS"
L.UI_TAG_KOS = "KoS"
L.UI_TAG_GUILD = "Guild"
L.UI_STATS_KOS_ONLY = "KoS only"
L.UI_STATS_PVP_ONLY = "PvP only"
L.UI_STATS_RESET = "Reset"
L.UI_STATS_RESET_CONFIRM = "Reset enemy statistics? This cannot be undone."
L.UI_STATS_FIRSTSEEN = "First seen"

L.UI_STATS_SORT_LASTSEEN = "Last Seen"
L.UI_STATS_SORT_NAME = "Name"
L.UI_STATS_SORT_SEEN = "Seen"
L.UI_STATS_SORT_WINS = "Wins"
L.UI_STATS_SORT_LOSES = "Losses"

L.UI_STATS_SEEN = "Seen"
L.UI_STATS_WINS = "Win"
L.UI_STATS_LOSES = "Loss"

L.TT_MINIMAP_TITLE = "Kill on Sight"

L.TT_MINIMAP_LEFTCLICK = "Left-click: Open/Close"

L.TT_MINIMAP_RIGHTCLICK = "Right-click: Menu"

L.TT_ON_KOS = "On KoS list"

L.TT_KOS = "Kill on Sight"
L.TT_GUILD = "Guild"
L.TT_NOT_TARGETABLE = "Not targetable"

L.TT_GUILD_KOS = "Guild-KoS"

L.TT_LEVEL_FMT = "Level %s"

L.UI_NEARBY_SOUND = "Nearby list sound"


-- Added in 3.0.x
L.UI_ATTACKERS_TITLE = "Attackers"

-- Notes / Spy import
L.UI_NOTE = L.UI_NOTE or "Note"
L.UI_NOTE_EDIT = L.UI_NOTE_EDIT or "Edit Note"
L.UI_NOTE_SAVE = L.UI_NOTE_SAVE or "Save"
L.UI_NOTE_CLEAR = L.UI_NOTE_CLEAR or "Clear"
L.UI_NOTE_CANCEL = L.UI_NOTE_CANCEL or "Cancel"
L.UI_NOTE_EMPTY = L.UI_NOTE_EMPTY or "(No note)"
L.UI_IMPORTSPY_NONE = L.UI_IMPORTSPY_NONE or "Spy import complete - no new KoS entries found."
L.UI_IMPORTSPY_RESULT = L.UI_IMPORTSPY_RESULT or "Spy import complete: %d added, %d already existed."
L.UI_NOTES = "Notes"


L["TT_NOT_TARGETABLE"] = "Not targetable right now"

L.UI_NEARBY_BG_DARKNESS = "Nearby background darkness"
