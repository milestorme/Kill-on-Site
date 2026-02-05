-- Locale/ruRU.lua
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

if not (GetLocale() == "ruRU") then return end

L.ACTIVITY = "%s рядом: %s (%s)%s"
L.ADDED_GUILD = "Гильдия добавлена в %s: %s"
L.ADDED_PLAYER = "Игрок добавлен в %s: %s"
L.ADDON_PREFIX = "KILLONSIGHT"
L.CMD_HELP = "Команды: /kos help | show | add [имя] | remove <имя> | addguild <гильдия> | removeguild <гильдия> | list | sync | statsprune"
L.GUILD_KOS = "Гильд-КоS"
L.HIDDEN = "Скрыт"
L.KOS = "KoS"
L.NOT_FOUND = "Не найдено: %s"
L.REMOVED_GUILD = "Гильдия удалена: %s"
L.REMOVED_PLAYER = "Игрок удалён: %s"
L.SEEN = "%s рядом: %s%s"
L.SEEN_GUILD = "Гильдия %s рядом: %s (%s)%s"
L.SEEN_HIDDEN = "Обнаружен скрытник: %s"
L.SYNC_COOLDOWN = "Синхронизация на перезарядке: осталось %ds."
L.SYNC_DISABLED = "Синхронизация требует быть в гильдии."
L.SYNC_DONE = "Синхронизация завершена."
L.SYNC_RECEIVED = "Данные синхронизации получены от %s."
L.SYNC_SENT = "Запрос синхронизации отправлен."
L.UI_ADD = "Add"
L.UI_ADD_GUILD = "Добавить гильдию"
L.UI_ADD_KOS = "Добавить KoS"
L.UI_ALERT_NEW = "Alert on new nearby enemy"
L.UI_ATTACKED_AT = "Атакован"
L.UI_CLEAR = "Очистить"
L.UI_CLOSE = "Закрыть"
L.UI_FLASH = "Мигание"
L.UI_GUILD = "Гильдия"
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
L.UI_NEARBY_NAME_FONT = "Шрифт имён рядом"
L.UI_NEARBY_NAME_SIZE = "Размер шрифта имён рядом"
L.UI_OPTIONS = "Options"

L.UI_OPTIONS_TITLE = "Настройки"
L.UI_REMOVE = "Remove"
L.UI_SOUND = "Звук"
L.UI_STEALTH = "Обнаружение скрытности"
L.UI_STEALTH_ADD_NEARBY = "Добавлять скрытников в список рядом"
L.UI_STEALTH_BANNER = "Показывать центральный баннер"
L.UI_STEALTH_ENABLE = "Включить обнаружение скрытности"
L.UI_STEALTH_FADE = "Затухание баннера (сек.)"
L.UI_STEALTH_HOLD = "Показ баннера (сек.)"
L.UI_STEALTH_SOUND = "Звук скрытности"
L.UI_SYNC = "Синхр. сейчас"
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
L.TT_SPEC_LOADING = "Осмотр…"
