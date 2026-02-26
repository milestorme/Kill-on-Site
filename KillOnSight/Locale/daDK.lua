-- Locale/daDK.lua
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


if not (GetLocale() == "daDK") then return end

L.ENEMY_NAMEPLATES_REQUIRED = "Passiv registrering i nærheden kræver, at fjendtlige navneskilte er aktiveret."

L.ACTIVITY = "%s i nærheden: %s (%s)%s"
L.ADDED_GUILD = "Guild tilføjet til %s: %s"
L.ADDED_PLAYER = "Spiller tilføjet til %s: %s"
L.ADDON_PREFIX = "KILLONSIGHT"
L.CMD_HELP = "Kommandoer: /kos help | show | add [navn] | remove <navn> | addguild <guild> | removeguild <guild> | list | sync | statsprune"
L.GUILD_KOS = "Gilde-KoS"
L.HIDDEN = "Skjult"
L.KOS = "KoS"
L.NOT_FOUND = "Ikke fundet: %s"
L.REMOVED_GUILD = "Guild fjernet: %s"
L.REMOVED_PLAYER = "Spiller fjernet: %s"
L.SEEN = "%s set i nærheden: %s%s"
L.SEEN_GUILD = "%s's guild set i nærheden: %s (%s)%s"
L.SEEN_HIDDEN = "Skjult registreret: %s"
L.SYNC_COOLDOWN = "Synkronisering på cooldown: %ds tilbage."
L.SYNC_DISABLED = "Synkronisering kræver, at du er i en gilde."
L.SYNC_SENT = "Synkroniseringsanmodning sendt."
L.SYNC_TOO_OLD = "Synkronisering mislykkedes: modpart er for langt bagud (oldest=%s, current=%s)."
L.UI_ADD = "Tilføj"
L.UI_ADD_GUILD = "Tilføj guild"
L.UI_ADD_KOS = "Tilføj KoS"
L.UI_CLEAR = "Ryd"
L.UI_CLOSE = "Luk"
L.UI_FLASH = "Blink"
L.UI_GUILD = "Gilde"
L.UI_ALERTS = "KoS / Gilde"
L.UI_NEARBY_HEADING = "I nærheden"
L.UI_LAST_SEEN = "Sidst set"
L.UI_CLASS = "Klasse"
L.UI_NAME = "Navn"
L.UI_NEARBY_AUTOHIDE = "Skjul automatisk når tom"
L.UI_DISABLE_GOBLIN_TOWNS = "Deaktiver advarsler i Booty Bay / Gadgetzan"
L.SUBZONE_BOOTY_BAY = "Booty Bay"
L.SUBZONE_GADGETZAN = "Gadgetzan"
L.UI_NEARBY_FRAME = "Nær-vindue"
L.UI_NEARBY_LOCK = "Lås nær-vindue"
L.UI_NEARBY_SCALE = "Skala for nær-vindue"
L.UI_NEARBY_NAME_FONT = "Skrifttype for navne i nærheden"
L.UI_NEARBY_NAME_SIZE = "Skriftstørrelse for navne i nærheden"
L.UI_NEARBY_RANGE_CLAMP = "Registreringsrækkevidde (Classic-følelse)"

L.UI_OPTIONS = "Indstillinger"

L.UI_OPTIONS_TITLE = "Indstillinger"
L.UI_REMOVE = "Fjern"
L.UI_SOUND = "Lyd"
L.UI_STEALTH = "Stealth-detektion"
L.UI_STEALTH_ADD_NEARBY = "Tilføj skjulte til Nær-liste"
L.UI_STEALTH_BANNER = "Vis central advarsel"
L.UI_STEALTH_CHAT = "Chat-besked"
L.UI_STEALTH_ENABLE = "Aktivér stealth-detektion"
L.UI_STEALTH_FADE = "Advarsel fade (sek)"
L.UI_STEALTH_HOLD = "Advarsel varighed (sek)"
L.UI_STEALTH_SOUND = "Afspil stealth-lyd"
L.UI_STEALTH_FLASH = "Skærmblink ved stealth"
L.UI_SYNC = "Synk nu"
L.UI_TAB_ATTACKERS = "Angribere"
L.UI_TAB_GUILDS = "Gilder"
L.UI_TAB_PLAYERS = "Spillere"
L.UI_TAB_STATS = "Statistik"
L.UI_TITLE = "Kill on Sight"
L.UI_TYPE = "Type"
L.UI_ZONE = "Zone"
L.UI_REMOVE_KOS = "Fjern KoS"
L.UI_CLEAR_NEARBY = "Ryd nærliste"
L.UI_NEARBY_COUNT = "I nærheden: %d"
L.UI_ADD_KOS_TARGET = "Tilføj KoS (mål)"
L.ERR_NO_PLAYER_TARGET = "Ingen spiller er målrettet."
L.UI_BANNER_TIMING = "Banner-timing"
L.UI_BANNER_HOLD_HELP = "Hvor længe advarslen forbliver fuldt synlig før den toner ud."
L.UI_BANNER_FADE_HELP = "Hvor længe advarslen toner blødt ud."
L.UI_LIST_PLAYERS = "Spillere: %s"
L.UI_LIST_GUILDS = "Gilder: %s"

L.MSG_LOADED = "Indlæst. Skriv /kos show"
L.UI_NEARBY_HEADER = "Navn / Level / Tid"

L.STEALTH_DETECTED_TITLE = "Skjult spiller opdaget!"

L.UI_STATS_TITLE = "Fjendestatistik"
L.UI_STATS_KOS_TAG = "KoS"
L.UI_TAG_KOS = "KoS"
L.UI_TAG_GUILD = "Gilde"
L.UI_STATS_KOS_ONLY = "Kun KoS"
L.UI_STATS_PVP_ONLY = "Kun PvP"
L.UI_STATS_RESET = "Nulstil"
L.UI_STATS_SEEN = "Set"
L.UI_STATS_WINS = "Sejr"
L.UI_STATS_LOSES = "Nederlag"
L.UI_STATS_RESET_CONFIRM = "Nulstil fjendestatistik?"
L.UI_STATS_FIRSTSEEN = "Først set"
L.UI_STATS_SORT_LASTSEEN = "Sidst set"
L.UI_STATS_SORT_NAME = "Navn"
L.UI_STATS_SORT_SEEN = "Set"
L.UI_STATS_SORT_WINS = "Sejre"
L.UI_STATS_SORT_LOSES = "Nederlag"

L.TT_MINIMAP_TITLE = "Kill on Sight"
L.TT_MINIMAP_LEFTCLICK = "Venstreklik: Åbn/Luk"
L.TT_MINIMAP_RIGHTCLICK = "Højreklik: Menu"
L.TT_KOS = "Kill on Sight"
L.TT_GUILD = "Guild"
L.TT_NOT_TARGETABLE = "Kan ikke målrettes nu"
L.TT_GUILD_KOS = "Gilde-KoS"
L.TT_LEVEL_FMT = "Niveau %s"

L.UI_NEARBY_SOUND = "Lyd for nærhedsliste"

L.UI_ATTACKERS_TITLE = "Angribere"

-- Notes / Spy import
L.UI_NOTE = L.UI_NOTE or "Note"
L.UI_NOTE_EDIT = L.UI_NOTE_EDIT or "Edit Note"
L.UI_NOTE_SAVE = L.UI_NOTE_SAVE or "Save"
L.UI_NOTE_CLEAR = L.UI_NOTE_CLEAR or "Clear"
L.UI_NOTE_CANCEL = L.UI_NOTE_CANCEL or "Cancel"
L.UI_NOTE_EMPTY = L.UI_NOTE_EMPTY or "(No note)"
L.UI_IMPORTSPY_NONE = L.UI_IMPORTSPY_NONE or "Spy import complete - no new KoS entries found."
L.UI_IMPORTSPY_RESULT = L.UI_IMPORTSPY_RESULT or "Spy import complete: %d added, %d already existed."
L.UI_NOTES = "Noter"

L.UI_NEARBY_BG_DARKNESS = "Mørkhed på baggrund i nær-vinduet"

-- Battleground options
L.UI_BATTLEGROUNDS = "Slagmarker"
L.UI_BG_MUTE_SOUNDS = "Slå alle notifikationslyde fra i slagmarker"
