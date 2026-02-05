-- Locale/nlNL.lua
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

if not (GetLocale() == "nlNL") then return end

L.ACTIVITY = "%s in de buurt: %s (%s)%s"
L.ADDED_GUILD = "Gilde toegevoegd aan %s: %s"
L.ADDED_PLAYER = "Speler toegevoegd aan %s: %s"
L.ADDON_PREFIX = "KILLONSIGHT"
L.CMD_HELP = "Commando's: /kos help | show | add [naam] | remove <naam> | addguild <gilde> | removeguild <gilde> | list | sync | statsprune"
L.GUILD_KOS = "Gilde-KoS"
L.HIDDEN = "Verborgen"
L.KOS = "KoS"
L.NOT_FOUND = "Niet gevonden: %s"
L.REMOVED_GUILD = "Gilde verwijderd: %s"
L.REMOVED_PLAYER = "Speler verwijderd: %s"
L.SEEN = "%s gespot in de buurt: %s%s"
L.SEEN_GUILD = "Gilde van %s in de buurt: %s (%s)%s"
L.SEEN_HIDDEN = "Verborgen gedetecteerd: %s"
L.SYNC_COOLDOWN = "Sync heeft cooldown: nog %ds."
L.SYNC_DISABLED = "Sync vereist dat je in een gilde zit."
L.SYNC_DONE = "Sync voltooid."
L.SYNC_RECEIVED = "Sync-gegevens ontvangen van %s."
L.SYNC_SENT = "Sync-verzoek verzonden."
L.UI_ADD = "Add"
L.UI_ADD_GUILD = "Gilde toevoegen"
L.UI_ADD_KOS = "KoS toevoegen"
L.UI_ALERT_NEW = "Alert on new nearby enemy"
L.UI_ATTACKED_AT = "Aangevallen"
L.UI_CLEAR = "Wissen"
L.UI_CLOSE = "Sluiten"
L.UI_FLASH = "Flitsen"
L.UI_GUILD = "Gilde"
L.UI_INSTANCES = "Melden in instances"
L.UI_LAST_SEEN = "Laatst gezien"
L.UI_CLASS = "Klasse"
L.UI_NAME = "Naam"
L.UI_NEARBY_ALPHA = "Nabij-transparantie"
L.UI_NEARBY_AUTOHIDE = "Automatisch verbergen als leeg"
L.UI_DISABLE_GOBLIN_TOWNS = "Schakel waarschuwingen uit in Booty Bay / Gadgetzan"
L.SUBZONE_BOOTY_BAY = "Booty Bay"
L.SUBZONE_GADGETZAN = "Gadgetzan"
L.UI_NEARBY_FADE = "In-/uitfaden"
L.UI_NEARBY_FRAME = "Nabij-venster"
L.UI_NEARBY_LOCK = "Nabij-venster vergrendelen"
L.UI_NEARBY_MINIMAL = "Ultra-minimaal nabij-venster"
L.UI_NEARBY_ROWFADE = "Vervagtimers per rij"
L.UI_NEARBY_ROWICONS = "Rijpictogrammen (klasse/schedel)"
L.UI_NEARBY_SCALE = "Schaal van nabij-venster"
L.UI_NEARBY_NAME_FONT = "Lettertype van namen in de buurt"
L.UI_NEARBY_NAME_SIZE = "Lettergrootte van namen in de buurt"

L.UI_OPTIONS = "Options"

L.UI_OPTIONS_TITLE = "Opties"
L.UI_REMOVE = "Remove"
L.UI_SOUND = "Geluid"
L.UI_STEALTH = "Stealth-detectie"
L.UI_STEALTH_ADD_NEARBY = "Verborgen in Nabij-lijst zetten"
L.UI_STEALTH_BANNER = "Middenbanner tonen"
L.UI_STEALTH_ENABLE = "Stealth-detectie inschakelen"
L.UI_STEALTH_FADE = "Banner vervagen (sec)"
L.UI_STEALTH_HOLD = "Banner vasthouden (sec)"
L.UI_STEALTH_SOUND = "Stealth-geluid afspelen"
L.UI_SYNC = "Nu syncen"
L.UI_TAB_ATTACKERS = "Aanvallers"
L.UI_TAB_GUILDS = "Gildes"
L.UI_TAB_PLAYERS = "Spelers"
L.UI_TAB_STATS = "Statistieken"
L.UI_THROTTLE = "Beperking (s)"
L.UI_TITLE = "Kill on Sight"
L.UI_TYPE = "Type"
L.UI_ZONE = "Zone"
L.UI_REMOVE_KOS = "KoS verwijderen"
L.UI_CLEAR_NEARBY = "Dichtbij-lijst wissen"
L.UI_NEARBY_COUNT = "Dichtbij: %d"
L.UI_ADD_KOS_TARGET = "KoS toevoegen (doel)"
L.ERR_NO_PLAYER_TARGET = "Geen speler als doelwit."
L.UI_BANNER_TIMING = "Banner-timing"
L.UI_BANNER_HOLD_HELP = "Hoe lang de waarschuwing volledig zichtbaar blijft voordat hij vervaagt."
L.UI_BANNER_FADE_HELP = "Hoe lang de waarschuwing soepel vervaagt."
L.UI_LIST_PLAYERS = "Spelers: %s"
L.UI_LIST_GUILDS = "Guilds: %s"


L.MSG_LOADED = "Geladen. Typ /kos show"
L.UI_NEARBY_HEADER = "Naam / Level / Tijd"



L.STEALTH_DETECTED_TITLE = "Sluipende speler gedetecteerd!"

L.UI_STATS_TITLE = "Vijandstatistieken"
L.UI_STATS_KOS_TAG = "KoS"
L.UI_TAG_KOS = "KoS"
L.UI_TAG_GUILD = "Gilde"
L.UI_STATS_KOS_ONLY = "Alleen KoS"
L.UI_STATS_PVP_ONLY = "Alleen PvP"
L.UI_STATS_RESET = "Resetten"
L.UI_STATS_SEEN = "Gezien"
L.UI_STATS_WINS = "Overwinning"
L.UI_STATS_LOSES = "Nederlaag"
L.UI_STATS_RESET_CONFIRM = "Vijandstatistieken resetten?"
L.UI_STATS_FIRSTSEEN = "Eerst gezien"
L.UI_STATS_SORT_LASTSEEN = "Laatst gezien"
L.UI_STATS_SORT_NAME = "Naam"
L.UI_STATS_SORT_SEEN = "Gezien"
L.UI_STATS_SORT_WINS = "Overwinningen"
L.UI_STATS_SORT_LOSES = "Nederlagen"

L.TT_MINIMAP_TITLE = 'Kill on Sight'

L.TT_MINIMAP_LEFTCLICK = 'Linkerklik: Openen/Sluiten'

L.TT_MINIMAP_RIGHTCLICK = 'Rechterklik: Menu'

L.TT_ON_KOS = 'Op KoS-lijst'

L.TT_GUILD_KOS = 'Guild-KoS'

L.TT_LEVEL_FMT = 'Level %s'

L.UI_STEALTH_CHAT = "Chat notification"

L.UI_NEARBY_SOUND = "Nearby list sound"


-- Added/updated for new 3.0.x UI & features
L.UI_ADD = "Toevoegen"
L.UI_REMOVE = "Verwijderen"
L.UI_OPTIONS = "Opties"
L.UI_TYPE = "Type"
L.UI_ZONE = "Zone"
L.UI_LIST_GUILDS = "Gilden: %s"
L.UI_ALERT_NEW = "Waarschuw bij nieuwe vijand in de buurt"
L.UI_STEALTH_CHAT = "Chatmelding"
L.UI_NEARBY_SOUND = "Geluid voor nabijheidslijst"
L.UI_ALERTS = "KoS / Gilde"
L.UI_NEARBY_HEADING = "In de buurt"
L.TT_MINIMAP_TITLE = "Kill on Sight"
L.TT_MINIMAP_LEFTCLICK = "Linksklik: Openen/Sluiten"
L.TT_MINIMAP_RIGHTCLICK = "Rechtsklik: Menu"
L.TT_ON_KOS = "Op KoS-lijst"
L.TT_GUILD_KOS = "Gilde-KoS"
L.TT_LEVEL_FMT = "Niveau %s"
L.UI_ATTACKERS_TITLE = "Aanvallers"

-- Notes / Spy import
L.UI_NOTE = L.UI_NOTE or "Note"
L.UI_NOTE_EDIT = L.UI_NOTE_EDIT or "Edit Note"
L.UI_NOTE_SAVE = L.UI_NOTE_SAVE or "Save"
L.UI_NOTE_CLEAR = L.UI_NOTE_CLEAR or "Clear"
L.UI_NOTE_CANCEL = L.UI_NOTE_CANCEL or "Cancel"
L.UI_NOTE_EMPTY = L.UI_NOTE_EMPTY or "(No note)"
L.UI_IMPORTSPY_NONE = L.UI_IMPORTSPY_NONE or "Spy import complete - no new KoS entries found."
L.UI_IMPORTSPY_RESULT = L.UI_IMPORTSPY_RESULT or "Spy import complete: %d added, %d already existed."
L.UI_NOTES = "Notities"

L.RETAIL_NEARBY_LIMITED_NAMEPLATES_OFF = "Dichtbij is beperkt omdat vijandelijke naamplaten UIT staan. Schakel vijandelijke naamplaten in (Interface > Namen) voor volledige detectie. Je kunt ze toggelen met de V-toets."

L["TT_NOT_TARGETABLE"] = "Nu niet te targeten"
