-- Locale/plPL.lua
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

if not (GetLocale() == "plPL") then return end

L.ACTIVITY = "%s w pobliżu: %s (%s)%s"
L.ADDED_GUILD = "Dodano gildię do %s: %s"
L.ADDED_PLAYER = "Dodano gracza do %s: %s"
L.ADDON_PREFIX = "KILLONSIGHT"
L.CMD_HELP = "Komendy: /kos help | show | add [nazwa] | remove <nazwa> | addguild <gildia> | removeguild <gildia> | list | sync | statsprune"
L.GUILD_KOS = "Gildia-KoS"
L.HIDDEN = "Ukryty"
L.KOS = "KoS"
L.NOT_FOUND = "Nie znaleziono: %s"
L.REMOVED_GUILD = "Usunięto gildię: %s"
L.REMOVED_PLAYER = "Usunięto gracza: %s"
L.SEEN = "%s zauważony w pobliżu: %s%s"
L.SEEN_GUILD = "Gildia %s zauważona w pobliżu: %s (%s)%s"
L.SEEN_HIDDEN = "Wykryto ukrycie: %s"
L.SYNC_COOLDOWN = "Synchronizacja w trakcie odnowienia: pozostało %ds."
L.SYNC_DISABLED = "Synchronizacja wymaga bycia w gildii."
L.SYNC_DONE = "Synchronizacja zakończona."
L.SYNC_RECEIVED = "Otrzymano dane synchronizacji od %s."
L.SYNC_SENT = "Wysłano prośbę o synchronizację."
L.UI_ADD = "Dodaj"
L.UI_ADD_GUILD = "Dodaj gildię"
L.UI_ADD_KOS = "Dodaj KoS"
L.UI_ALERT_NEW = "Powiadom o nowym wrogu w pobliżu"
L.UI_ATTACKED_AT = "Atak"
L.UI_CLEAR = "Wyczyść"
L.UI_CLOSE = "Zamknij"
L.UI_FLASH = "Migaj"
L.UI_GUILD = "Gildia"
L.UI_INSTANCES = "Powiadamiaj w instancjach"
L.UI_ALERTS = "KoS / Gildia"
L.UI_NEARBY_HEADING = "W pobliżu"
L.UI_LAST_SEEN = "Ostatnio widziany"
L.UI_CLASS = "Klasa"
L.UI_NAME = "Nazwa"
L.UI_NEARBY_ALPHA = "Przezroczystość listy"
L.UI_NEARBY_AUTOHIDE = "Automatycznie ukrywaj gdy puste"
L.UI_DISABLE_GOBLIN_TOWNS = "Wyłącz alerty w Zatoce Łupieżców / Gadgetzan"
L.SUBZONE_BOOTY_BAY = "Zatoka Łupieżców"
L.SUBZONE_GADGETZAN = "Gadgetzan"
L.UI_NEARBY_FADE = "Zanikanie"
L.UI_NEARBY_FRAME = "Okno 'W pobliżu'"
L.UI_NEARBY_LOCK = "Zablokuj okno"
L.UI_NEARBY_MINIMAL = "Ultra-minimalne okno"
L.UI_NEARBY_ROWFADE = "Zanikanie wierszy"
L.UI_NEARBY_ROWICONS = "Ikony wierszy (klasa/czaszka)"
L.UI_NEARBY_SCALE = "Skala okna"
L.UI_NEARBY_NAME_FONT = "Czcionka nazw w pobliżu"
L.UI_NEARBY_NAME_SIZE = "Rozmiar czcionki nazw w pobliżu"
L.UI_NEARBY_RANGE_CLAMP = "Zasięg wykrywania (jak w Classic)"

L.UI_OPTIONS = "Opcje"

L.UI_OPTIONS_TITLE = "Opcje"
L.UI_REMOVE = "Usuń"
L.UI_SOUND = "Dźwięk"
L.UI_STEALTH = "Wykrywanie skradania"
L.UI_STEALTH_ADD_NEARBY = "Dodaj ukrytych do listy"
L.UI_STEALTH_BANNER = "Pokaż centralny baner"
L.UI_STEALTH_CHAT = "Powiadomienie na czacie"
L.UI_STEALTH_ENABLE = "Włącz wykrywanie skradania"
L.UI_STEALTH_FADE = "Zanikanie baneru (sek)"
L.UI_STEALTH_HOLD = "Czas trwania baneru (sek)"
L.UI_STEALTH_SOUND = "Odtwórz dźwięk skradania"
L.UI_STEALTH_FLASH = "Błysk ekranu przy skradaniu"
L.UI_SYNC = "Synchronizuj teraz"
L.UI_TAB_ATTACKERS = "Napastnicy"
L.UI_TAB_GUILDS = "Gildie"
L.UI_TAB_PLAYERS = "Gracze"
L.UI_TAB_STATS = "Statystyki"
L.UI_THROTTLE = "Ograniczenie (sek)"
L.UI_TITLE = "Zabij na miejscu"
L.UI_TYPE = "Typ"
L.UI_ZONE = "Strefa"
L.UI_REMOVE_KOS = "Usuń KoS"
L.UI_CLEAR_NEARBY = "Wyczyść listę"
L.UI_NEARBY_COUNT = "W pobliżu: %d"
L.UI_ADD_KOS_TARGET = "Dodaj KoS (cel)"
L.ERR_NO_PLAYER_TARGET = "Brak wybranego gracza."
L.UI_BANNER_TIMING = "Czasy baneru"
L.UI_BANNER_HOLD_HELP = "Jak długo ostrzeżenie pozostaje w pełni widoczne przed zaniknięciem."
L.UI_BANNER_FADE_HELP = "Jak długo ostrzeżenie płynnie zanika."
L.UI_LIST_PLAYERS = "Gracze: %s"
L.UI_LIST_GUILDS = "Gildie: %s"
L.MSG_LOADED = "Wczytano. Wpisz /kos show"
L.UI_NEARBY_HEADER = "Nazwa / Poziom / Czas"
L.STEALTH_DETECTED_TITLE = "Wykryto ukrytego gracza!"
L.UI_STATS_TITLE = "Statystyki wrogów"
L.UI_STATS_KOS_TAG = "KoS"
L.UI_TAG_KOS = "KoS"
L.UI_TAG_GUILD = "Gildia"
L.UI_STATS_KOS_ONLY = "Tylko KoS"
L.UI_STATS_PVP_ONLY = "Tylko PvP"
L.UI_STATS_RESET = "Resetuj"
L.UI_STATS_RESET_CONFIRM = "Zresetować statystyki wrogów? Nie można cofnąć."
L.UI_STATS_FIRSTSEEN = "Pierwsze spotkanie"
L.UI_STATS_SORT_LASTSEEN = "Ostatnio"
L.UI_STATS_SORT_NAME = "Nazwa"
L.UI_STATS_SORT_SEEN = "Widziano"
L.UI_STATS_SORT_WINS = "Wygrane"
L.UI_STATS_SORT_LOSES = "Przegrane"
L.UI_STATS_SEEN = "Widziano"
L.UI_STATS_WINS = "Wygrana"
L.UI_STATS_LOSES = "Porażka"
L.TT_MINIMAP_TITLE = "Zabij na miejscu"
L.TT_MINIMAP_LEFTCLICK = "LPM: Otwórz/Zamknij"
L.TT_MINIMAP_RIGHTCLICK = "PPM: Menu"
L.TT_ON_KOS = "Na liście KoS"
L.TT_GUILD = "Guild"
L.TT_KOS = "Kill on Sight"
L.TT_NOT_TARGETABLE = "Not targetable"
L.TT_GUILD_KOS = "Gildia-KoS"
L.TT_LEVEL_FMT = "Poziom %s"
L.UI_NEARBY_SOUND = "Dźwięk listy"
L.UI_ATTACKERS_TITLE = "Napastnicy"

-- Notes / Spy import
L.UI_NOTE = L.UI_NOTE or "Note"
L.UI_NOTE_EDIT = L.UI_NOTE_EDIT or "Edit Note"
L.UI_NOTE_SAVE = L.UI_NOTE_SAVE or "Save"
L.UI_NOTE_CLEAR = L.UI_NOTE_CLEAR or "Clear"
L.UI_NOTE_CANCEL = L.UI_NOTE_CANCEL or "Cancel"
L.UI_NOTE_EMPTY = L.UI_NOTE_EMPTY or "(No note)"
L.UI_IMPORTSPY_NONE = L.UI_IMPORTSPY_NONE or "Spy import complete - no new KoS entries found."
L.UI_IMPORTSPY_RESULT = L.UI_IMPORTSPY_RESULT or "Spy import complete: %d added, %d already existed."
L.UI_NOTES = "Notatki"

L.RETAIL_NEARBY_LIMITED_NAMEPLATES_OFF = "Lista w pobliżu jest ograniczona, ponieważ wrogie tabliczki imion są WYŁĄCZONE. Włącz wrogie tabliczki imion (Interfejs > Nazwy), aby uzyskać pełne wykrywanie. Możesz przełączać klawiszem V."

L["TT_NOT_TARGETABLE"] = "Nie można teraz namierzyć"

L.UI_NEARBY_BG_DARKNESS = "Przyciemnienie tła okna pobliżu"
