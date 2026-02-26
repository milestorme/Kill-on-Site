-- Locale/deDE.lua
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


if not (GetLocale() == "deDE") then return end

L.ENEMY_NAMEPLATES_REQUIRED = "Passive Erkennung in der Nähe erfordert aktivierte feindliche Namensplaketten."

L.ACTIVITY = "%s in der Nähe: %s (%s)%s"
L.ADDED_GUILD = "Gilde zu %s hinzugefügt: %s"
L.ADDED_PLAYER = "Spieler zu %s hinzugefügt: %s"
L.ADDON_PREFIX = "KILLONSIGHT"
L.CMD_HELP = "Befehle: /kos help | show | add [name] | remove <name> | addguild <gilde> | removeguild <gilde> | list | sync | statsprune"
L.GUILD_KOS = "Gilden-KoS"
L.HIDDEN = "Versteckt"
L.KOS = "KoS"
L.NOT_FOUND = "Nicht gefunden: %s"
L.REMOVED_GUILD = "Gilde entfernt: %s"
L.REMOVED_PLAYER = "Spieler entfernt: %s"
L.SEEN = "%s in der Nähe gesichtet: %s%s"
L.SEEN_GUILD = "Gilde von %s in der Nähe: %s (%s)%s"
L.SEEN_HIDDEN = "Versteckt entdeckt: %s"
L.SYNC_COOLDOWN = "Sync auf Abklingzeit: noch %ds."
L.SYNC_DISABLED = "Sync erfordert, dass du in einer Gilde bist."
L.SYNC_SENT = "Sync-Anfrage gesendet."
L.SYNC_TOO_OLD = "Synchronisierung fehlgeschlagen: Peer ist zu weit zurück (oldest=%s, current=%s)."
L.UI_ADD = "Hinzufügen"
L.UI_ADD_GUILD = "Gilde hinzufügen"
L.UI_ADD_KOS = "KoS hinzufügen"
L.UI_CLEAR = "Leeren"
L.UI_CLOSE = "Schließen"
L.UI_FLASH = "Blitzen"
L.UI_GUILD = "Gilde"
L.UI_ALERTS = "KoS / Gilde"
L.UI_NEARBY_HEADING = "In der Nähe"
L.UI_LAST_SEEN = "Zuletzt gesehen"
L.UI_CLASS = "Klasse"
L.UI_NAME = "Name"
L.UI_NEARBY_AUTOHIDE = "Automatisch ausblenden, wenn leer"
L.UI_DISABLE_GOBLIN_TOWNS = "Warnungen in Beutebucht / Gadgetzan deaktivieren"
L.SUBZONE_BOOTY_BAY = "Beutebucht"
L.SUBZONE_GADGETZAN = "Gadgetzan"
L.UI_NEARBY_FRAME = "Nah-Fenster"
L.UI_NEARBY_LOCK = "Nah-Fenster sperren"
L.UI_NEARBY_SCALE = "Skalierung des Nah-Fensters"
L.UI_NEARBY_NAME_FONT = "Schriftart der Namen in der Nähe"
L.UI_NEARBY_NAME_SIZE = "Schriftgröße der Namen in der Nähe"
L.UI_NEARBY_RANGE_CLAMP = "Erkennungsreichweite (Classic-Gefühl)"

L.UI_OPTIONS = "Optionen"

L.UI_OPTIONS_TITLE = "Optionen"
L.UI_REMOVE = "Entfernen"
L.UI_SOUND = "Sound"
L.UI_STEALTH = "Schleich-Erkennung"
L.UI_STEALTH_ADD_NEARBY = "Versteckte zur Nah-Liste hinzufügen"
L.UI_STEALTH_BANNER = "Zentrale Warnleiste anzeigen"
L.UI_STEALTH_CHAT = "Chat-Benachrichtigung"
L.UI_STEALTH_ENABLE = "Schleich-Erkennung aktivieren"
L.UI_STEALTH_FADE = "Warnanzeige ausblenden (Sek.)"
L.UI_STEALTH_HOLD = "Warnanzeige halten (Sek.)"
L.UI_STEALTH_SOUND = "Schleich-Sound abspielen"
L.UI_STEALTH_FLASH = "Bildschirm bei Stealth aufblitzen"
L.UI_SYNC = "Jetzt syncen"
L.UI_TAB_ATTACKERS = "Angreifer"
L.UI_TAB_GUILDS = "Gilden"
L.UI_TAB_PLAYERS = "Spieler"
L.UI_TAB_STATS = "Statistik"
L.UI_TITLE = "Kill on Sight"
L.UI_TYPE = "Typ"
L.UI_ZONE = "Zone"
L.UI_REMOVE_KOS = "KoS entfernen"
L.UI_CLEAR_NEARBY = "Nah-Liste leeren"
L.UI_NEARBY_COUNT = "In der Nähe: %d"
L.UI_ADD_KOS_TARGET = "KoS hinzufügen (Ziel)"
L.ERR_NO_PLAYER_TARGET = "Kein Spieler anvisiert."
L.UI_BANNER_TIMING = "Banner-Zeit"
L.UI_BANNER_HOLD_HELP = "Wie lange die Warnung vollständig sichtbar bleibt, bevor sie ausblendet."
L.UI_BANNER_FADE_HELP = "Wie lange die Warnung sanft ausblendet."
L.UI_LIST_PLAYERS = "Spieler: %s"
L.UI_LIST_GUILDS = "Gilden: %s"

L.MSG_LOADED = "Geladen. Tippe /kos show"
L.UI_NEARBY_HEADER = "Name / Stufe / Zeit"

L.STEALTH_DETECTED_TITLE = "Schleichender Spieler entdeckt!"

L.UI_STATS_TITLE = "Feindstatistik"
L.UI_STATS_KOS_TAG = "KoS"
L.UI_TAG_KOS = "KoS"
L.UI_TAG_GUILD = "Gilde"
L.UI_STATS_KOS_ONLY = "Nur KoS"
L.UI_STATS_PVP_ONLY = "Nur PvP"
L.UI_STATS_RESET = "Zurücksetzen"
L.UI_STATS_SEEN = "Gesehen"
L.UI_STATS_WINS = "Sieg"
L.UI_STATS_LOSES = "Niederlage"
L.UI_STATS_RESET_CONFIRM = "Feindstatistik zurücksetzen?"
L.UI_STATS_FIRSTSEEN = "Zuerst gesehen"
L.UI_STATS_SORT_LASTSEEN = "Zuletzt gesehen"
L.UI_STATS_SORT_NAME = "Name"
L.UI_STATS_SORT_SEEN = "Gesehen"
L.UI_STATS_SORT_WINS = "Siege"
L.UI_STATS_SORT_LOSES = "Niederlagen"

L.TT_MINIMAP_TITLE = "Kill on Sight"

L.TT_MINIMAP_LEFTCLICK = "Linksklick: Öffnen/Schließen"

L.TT_MINIMAP_RIGHTCLICK = "Rechtsklick: Menü"

L.TT_KOS = "Sofort angreifen"
L.TT_GUILD = "Gilde"
L.TT_NOT_TARGETABLE = "Derzeit nicht anvisierbar"

L.TT_GUILD_KOS = "Gilden-KoS"

L.TT_LEVEL_FMT = "Stufe %s"

L.UI_NEARBY_SOUND = "Sound für Nah-Liste"

L.UI_ATTACKERS_TITLE = "Angreifer"

-- Notes / Spy import
L.UI_NOTE = L.UI_NOTE or "Note"
L.UI_NOTE_EDIT = L.UI_NOTE_EDIT or "Edit Note"
L.UI_NOTE_SAVE = L.UI_NOTE_SAVE or "Save"
L.UI_NOTE_CLEAR = L.UI_NOTE_CLEAR or "Clear"
L.UI_NOTE_CANCEL = L.UI_NOTE_CANCEL or "Cancel"
L.UI_NOTE_EMPTY = L.UI_NOTE_EMPTY or "(No note)"
L.UI_IMPORTSPY_NONE = L.UI_IMPORTSPY_NONE or "Spy import complete - no new KoS entries found."
L.UI_IMPORTSPY_RESULT = L.UI_IMPORTSPY_RESULT or "Spy import complete: %d added, %d already existed."
L.UI_NOTES = "Notizen"

L.UI_NEARBY_BG_DARKNESS = "Dunkelheit des Nahfenster-Hintergrunds"

-- Battleground options
L.UI_BATTLEGROUNDS = "Schlachtfelder"
L.UI_BG_MUTE_SOUNDS = "Alle Benachrichtigungstöne in Schlachtfeldern stummschalten"
