-- Locale/ruRU.lua
local ADDON_NAME = ...
KillOnSight_L_data = KillOnSight_L_data or {}
KillOnSight_L = KillOnSight_L or {}

if not KillOnSight_L.__kos_proxy then
  KillOnSight_L.__kos_proxy = true
  setmetatable(KillOnSight_L, {
    __index = function(_, k)
      local v = KillOnSight_L_data[k]
      if v == nil then
        return k -- fallback so missing keys are obvious
      end
      return v
    end,
  })
end

local L = KillOnSight_L_data

if not (GetLocale() == "ruRU") then return end

L.ACTIVITY = "%s рядом: %s (%s)%s"
L.ADDED_GUILD = "Гильдия добавлена в %s: %s"
L.ADDED_PLAYER = "Игрок добавлен в %s: %s"
L.ADDON_PREFIX = "KILLONSIGHT"
L.CMD_HELP = "Команды: /kos help | show | add [имя] | remove <имя> | addguild <гильдия> | removeguild <гильдия> | list | statsprune"
L.GUILD_KOS = "Гильд-КоS"
L.HIDDEN = "Скрыт"
L.KOS = "KoS"
L.NOT_FOUND = "Не найдено: %s"
L.REMOVED_GUILD = "Гильдия удалена: %s"
L.REMOVED_PLAYER = "Игрок удалён: %s"
L.SEEN = "%s рядом: %s%s"
L.SEEN_GUILD = "Гильдия %s рядом: %s (%s)%s"
L.SEEN_HIDDEN = "Обнаружен скрытник: %s"
L.UI_ADD = "Add"
L.UI_ADD_GUILD = "Добавить гильдию"
L.UI_ADD_KOS = "Добавить KoS"
L.UI_ALERT_NEW = "Alert on new nearby enemy"
L.UI_ATTACKED_AT = "Атакован"
L.UI_CLEAR = "Очистить"
L.UI_CLOSE = "Закрыть"
L.UI_SHARE = "Поделиться"
L.UI_SHARE_DIALOG_TITLE = "Поделиться выбранной записью"
L.UI_SHARE_COPY_HINT = "Нажмите Ctrl+C, чтобы скопировать сообщение, вставьте его в чат и нажмите Enter."
L.UI_SHARE_IMPORT = "Импортировать"
L.UI_SHARE_CANCEL = "Отмена"
L.UI_SHARE_IMPORT_KOS_TITLE = "Импортировать цель KoS?"
L.UI_SHARE_IMPORT_GUILD_TITLE = "Импортировать Guild KoS?"
L.UI_SHARE_IMPORT_HONOR_TITLE = "Импортировать запись Honor?"
L.UI_SHARE_REVIEW_KOS = "Проверьте имя. После импорта оно появится в вашем списке KoS."
L.UI_SHARE_REVIEW_GUILD = "Проверьте гильдию. После импорта она появится в вашем списке Guild KoS."
L.UI_SHARE_REVIEW_HONOR = "Проверьте имя. После импорта оно появится в вашем списке Honor."
L.UI_SHARE_SELECT_ONE = "Выберите одну запись для отправки."
L.UI_SHARE_IMPORTED = "Импортировано новых записей: %d."
L.UI_SHARE_TARGET_LABEL = "Поделиться целью KoS"
L.UI_SHARE_GUILD_LABEL = "Поделиться Guild KoS"
L.UI_SHARE_HONOR_LABEL = "Поделиться Honor"
L.UI_FLASH = "Мигание"
L.UI_GUILD = "Гильдия"
L.UI_FACTION = "Фракция"
L.UI_INSTANCES = "Уведомлять в инстансах"
L.UI_LAST_SEEN = "Последний раз"
L.UI_CLASS = "Класс"
L.UI_NAME = "Имя"
L.UI_NEARBY_ALPHA = "Прозрачность окна"
L.UI_NEARBY_AUTOHIDE = "Автоскрытие, если пусто"
L.UI_DISABLE_GOBLIN_TOWNS = "Отключить оповещения в Пиратской Бухте / Прибамбасске"
L.SUBZONE_BOOTY_BAY = "Пиратская Бухта"
L.SUBZONE_GADGETZAN = "Прибамбасск"
L.UI_NEARBY_FADE = "Плавное появл./исчезн."
L.UI_NEARBY_FRAME = "Окно рядом"
L.UI_NEARBY_LOCK = "Закрепить окно рядом"
L.UI_NEARBY_MINIMAL = "Ультра-минималистичное окно рядом"
L.UI_NEARBY_ROWFADE = "Таймеры затухания по строкам"
L.UI_NEARBY_ROWICONS = "Иконки строки (класс/череп)"
L.UI_NEARBY_SCALE = "Масштаб окна рядом"
L.UI_NEARBY_BACKGROUND = "Фон (рядом)"
L.UI_NEARBY_NAME_FONT = "Шрифт имён рядом"
L.UI_NEARBY_NAME_SIZE = "Размер шрифта имён рядом"
L.UI_NEARBY_MAX_ROWS = "Макс. строк в \"Рядом\""
L.UI_OPTIONS = "Options"

L.UI_OPTIONS_TITLE = "Настройки"
L.UI_REMOVE = "Remove"
L.UI_SOUND = "Звук"
L.UI_ALERT_VOLUME = "Громкость оповещений"
L.UI_STEALTH = "Обнаружение скрытности"
L.UI_STEALTH_ADD_NEARBY = "Добавлять скрытников в список рядом"
L.UI_STEALTH_BANNER = "Показывать центральный баннер"
L.UI_STEALTH_ENABLE = "Включить обнаружение скрытности"
L.UI_STEALTH_FADE = "Затухание баннера (сек.)"
L.UI_STEALTH_HOLD = "Показ баннера (сек.)"
L.UI_STEALTH_SOUND = "Звук скрытности"
L.UI_TAB_ATTACKERS = "Нападавшие"
L.UI_TAB_GUILDS = "Гильдии"
L.UI_TAB_PLAYERS = "Игроки"
L.UI_TAB_STATS = "Статистика"
L.UI_THROTTLE = "Ограничение (с)"
L.UI_TITLE = "Kill on Sight"
L.UI_TYPE = "Тип"
L.UI_ZONE = "Зона"
L.UI_REMOVE_KOS = "Удалить из KoS"
L.UI_CLEAR_NEARBY = "Очистить список рядом"
L.UI_NEARBY_COUNT = "Рядом: %d"
L.UI_ADD_KOS_TARGET = "Добавить KoS (цель)"
L.ERR_NO_PLAYER_TARGET = "Игрок не выбран."
L.UI_BANNER_TIMING = "Время баннера"
L.UI_BANNER_HOLD_HELP = "Сколько времени предупреждение полностью видно перед затуханием."
L.UI_BANNER_FADE_HELP = "Как долго предупреждение плавно исчезает."
L.UI_LIST_PLAYERS = "Игроки: %s"
L.UI_LIST_GUILDS = "Гильдии: %s"


L.MSG_LOADED = "Загружено. Введите /kos show"
L.UI_NEARBY_HEADER = "Имя / Уровень / Время"



L.STEALTH_DETECTED_TITLE = "Обнаружен игрок в скрытности!"

L.UI_STATS_TITLE = "Статистика врагов"
L.UI_STATS_KOS_TAG = "KoS"
L.UI_TAG_KOS = "KoS"
L.UI_TAG_GUILD = "Гильдия"
L.UI_STATS_KOS_ONLY = "Только KoS"
L.UI_STATS_PVP_ONLY = "Только PvP"
L.UI_STATS_RESET = "Сбросить"
L.UI_STATS_SEEN = "Видели"
L.UI_STATS_WINS = "Победа"
L.UI_STATS_LOSES = "Поражение"
L.UI_STATS_RESET_CONFIRM = "Сбросить статистику врагов?"
L.UI_STATS_FIRSTSEEN = "Впервые видели"
L.UI_STATS_SORT_LASTSEEN = "Последний раз видели"
L.UI_STATS_SORT_NAME = "Имя"
L.UI_STATS_SORT_SEEN = "Видели"
L.UI_STATS_SORT_WINS = "Победы"
L.UI_STATS_SORT_LOSES = "Поражения"

L.TT_MINIMAP_TITLE = 'Kill on Sight'

L.TT_MINIMAP_LEFTCLICK = 'ЛКМ: Открыть/Закрыть'

L.TT_MINIMAP_RIGHTCLICK = 'ПКМ: Меню'

L.TT_ON_KOS = 'В списке KoS'

L.TT_GUILD_KOS = 'KoS гильдии'

L.TT_LEVEL_FMT = 'Уровень %s'

L.UI_STEALTH_CHAT = "Chat notification"

L.UI_NEARBY_SOUND = "Nearby list sound"


-- Added/updated for new 3.0.x UI & features
L.UI_ADD = "Добавить"
L.UI_REMOVE = "Удалить"
L.UI_OPTIONS = "Настройки"
L.UI_ALERT_NEW = "Оповещать о новом враге рядом"
L.UI_STEALTH_CHAT = "Уведомление в чат"
L.UI_NEARBY_SOUND = "Звук списка рядом"
L.UI_ALERTS = "KoS / Гильдия"
L.UI_TARGETED_ALERTS_HEADING = "Оповещения о наведении"
L.UI_NEARBY_HEADING = "Рядом"
L.TT_MINIMAP_TITLE = "Убить при встрече"
L.TT_MINIMAP_LEFTCLICK = "ЛКМ: Открыть/Закрыть"
L.TT_MINIMAP_RIGHTCLICK = "ПКМ: Меню"
L.TT_ON_KOS = "В списке KoS"
L.TT_GUILD_KOS = "Гильдейский KoS"
L.TT_LEVEL_FMT = "Уровень %s"
L.UI_ATTACKERS_TITLE = "Нападавшие"

-- Notes / Spy import
L.UI_NOTE = L.UI_NOTE or "Note"
L.UI_NOTE_EDIT = L.UI_NOTE_EDIT or "Edit Note"
L.UI_NOTE_SAVE = L.UI_NOTE_SAVE or "Save"
L.UI_NOTE_CLEAR = L.UI_NOTE_CLEAR or "Clear"
L.UI_NOTE_CANCEL = L.UI_NOTE_CANCEL or "Cancel"
L.UI_NOTE_EMPTY = L.UI_NOTE_EMPTY or "(No note)"
L.UI_IMPORTSPY_NONE = L.UI_IMPORTSPY_NONE or "Spy import complete - no new KoS entries found."
L.UI_IMPORTSPY_RESULT = L.UI_IMPORTSPY_RESULT or "Spy import complete: %d added, %d already existed."
L.UI_NOTES = "Заметки"

L.RETAIL_NEARBY_LIMITED_NAMEPLATES_OFF = "Список рядом ограничен, потому что вражеские индикаторы имен ВЫКЛЮЧЕНЫ. Включите вражеские индикаторы имен (Интерфейс > Имена) для полного обнаружения. Переключается клавишей V."
L.NEARBY_DISABLED_INSTANCE = "Nearby отключён на полях боя и аренах."
L.TT_SPEC_LOADING = "Осмотр…"

-- Profiles (options presets)
L.UI_PROFILES = L.UI_PROFILES or "Profiles"
L.UI_PROFILE_NEW = L.UI_PROFILE_NEW or "New"
L.UI_PROFILE_COPY = L.UI_PROFILE_COPY or "Copy"
L.UI_PROFILE_RESET = L.UI_PROFILE_RESET or "Reset"
L.UI_PROFILE_DELETE = L.UI_PROFILE_DELETE or "Delete"

-- Profiles UI
L.UI_PROFILE_NEW_NAME = "Введите имя для нового профиля:"

-- Nearby right-click announcements (v3.4.9)
L.UI_ANNOUNCE = "Объявить"
L.UI_ANNOUNCE_SAY = "Сказать"
L.UI_ANNOUNCE_PARTY = "Группа"
L.UI_ANNOUNCE_RAID = "Рейд"
L.UI_ANNOUNCE_GUILD = "Гильдия"
L.UI_ANNOUNCE_LOCAL = "Местная оборона"


-- Honor list and Stats actions (v3.5.1)
L.UI_TAB_HONOR = "Уважение"
L.UI_ADD_HONOR = "Добавить в список уважаемых"
L.UI_REMOVE_HONOR = "Удалить из списка уважаемых"
L.UI_ADD_GUILD_KOS = "Добавить гильдию в KoS"
L.UI_HONOURED = "Уважаемый"
L.UI_HON_TAG = "Hon"

L.UI_TARGETED_ALERT = "Противник выбирает вас целью"
L.UI_TARGETED_WARNING = "ПРОТИВНИК ВЫБРАЛ ВАС ЦЕЛЬЮ: %s"

-- Enemy-targeting sound selector (English fallback where translation is pending).
L.UI_TARGET_SOUND_SELECT = L.UI_TARGET_SOUND_SELECT or 'Targeting sound'
L.UI_TARGET_SOUND_PREVIEW = L.UI_TARGET_SOUND_PREVIEW or 'Preview'
L.UI_TARGET_SOUND_HIGH_THREAT = L.UI_TARGET_SOUND_HIGH_THREAT or 'High Threat (Default)'
L.UI_TARGET_SOUND_NEARBY = L.UI_TARGET_SOUND_NEARBY or 'Nearby Detection'
L.UI_TARGET_SOUND_RADAR = L.UI_TARGET_SOUND_RADAR or 'Radar Sweep'
L.UI_TARGET_SOUND_SIREN = L.UI_TARGET_SOUND_SIREN or 'Warning Siren'
L.UI_TARGET_SOUND_PULSE = L.UI_TARGET_SOUND_PULSE or 'Double Pulse'
L.UI_TARGET_SOUND_CHIME = L.UI_TARGET_SOUND_CHIME or 'Alert Chime'

-- Profile actions and Guild-KoS removal labels.
L.UI_PROFILE_EDIT = 'Изменить'
L.UI_PROFILE_RENAME = 'Переименовать профиль:'
L.UI_PROFILE_ERR_EMPTY = 'Имя не может быть пустым.'
L.UI_PROFILE_ERR_EXISTS = 'Профиль с таким именем уже существует.'
L.UI_PROFILE_ERR_INVALID = 'Это имя нельзя использовать.'
L.UI_REMOVE_GUILD_KOS = 'Удалить гильдию из списка KoS'
L.UI_NEARBY_LAST_NAMES = "Показывать фамилии в Nearby"
