-- Locale/esMX.lua
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


if not (GetLocale() == "esMX") then return end

L.ENEMY_NAMEPLATES_REQUIRED = "La detección pasiva cercana requiere tener activadas las placas de nombre enemigas."

L.ACTIVITY = "%s cerca: %s (%s)%s"
L.ADDED_GUILD = "Gremio añadida a %s: %s"
L.ADDED_PLAYER = "Jugador añadido a %s: %s"
L.ADDON_PREFIX = "KILLONSIGHT"
L.CMD_HELP = "Comandos: /kos help | show | add [nombre] | remove <nombre> | addguild <gremio> | removeguild <gremio> | list | sync | statsprune"
L.GUILD_KOS = "KoS-Gremio"
L.HIDDEN = "Oculto"
L.KOS = "KoS"
L.NOT_FOUND = "No encontrado: %s"
L.REMOVED_GUILD = "Gremio eliminada: %s"
L.REMOVED_PLAYER = "Jugador eliminado: %s"
L.SEEN = "%s visto cerca: %s%s"
L.SEEN_GUILD = "Gremio de %s cerca: %s (%s)%s"
L.SEEN_HIDDEN = "Sigilo detectado: %s"
L.SYNC_COOLDOWN = "Sincronización en enfriamiento: quedan %ds."
L.SYNC_DISABLED = "La sincronización requiere estar en un gremio."
L.SYNC_SENT = "Solicitud de sincronización enviada."
L.SYNC_TOO_OLD = "Sincronización fallida: el par está demasiado atrasado (oldest=%s, current=%s)."
L.UI_ADD = "Añadir"
L.UI_ADD_GUILD = "Añadir gremio"
L.UI_ADD_KOS = "Añadir KoS"
L.UI_CLEAR = "Limpiar"
L.UI_CLOSE = "Cerrar"
L.UI_FLASH = "Destello"
L.UI_GUILD = "Gremio"
L.UI_ALERTS = "KoS / Gremio"
L.UI_NEARBY_HEADING = "Cercanos"
L.UI_LAST_SEEN = "Visto por última vez"
L.UI_CLASS = "Clase"
L.UI_NAME = "Nombre"
L.UI_NEARBY_AUTOHIDE = "Ocultar automáticamente si está vacía"
L.UI_DISABLE_GOBLIN_TOWNS = "Desactivar alertas en Bahía del Botín / Gadgetzan"
L.SUBZONE_BOOTY_BAY = "Bahía del Botín"
L.SUBZONE_GADGETZAN = "Gadgetzan"
L.UI_NEARBY_FRAME = "Ventana de cercanos"
L.UI_NEARBY_LOCK = "Bloquear ventana de cercanos"
L.UI_NEARBY_SCALE = "Escala de la ventana de cercanos"
L.UI_NEARBY_NAME_FONT = "Fuente de nombres cercanos"
L.UI_NEARBY_NAME_SIZE = "Tamaño de fuente de nombres cercanos"
L.UI_NEARBY_RANGE_CLAMP = "Alcance de detección (sensación Classic)"

L.UI_OPTIONS = "Opciones"

L.UI_OPTIONS_TITLE = "Opciones"
L.UI_REMOVE = "Eliminar"
L.UI_SOUND = "Sonido"
L.UI_STEALTH = "Detección de sigilo"
L.UI_STEALTH_ADD_NEARBY = "Añadir ocultos a la lista Cercanos"
L.UI_STEALTH_BANNER = "Mostrar aviso central"
L.UI_STEALTH_CHAT = "Notificación en el chat"
L.UI_STEALTH_ENABLE = "Activar detección de sigilo"
L.UI_STEALTH_FADE = "Desvanecer aviso (seg.)"
L.UI_STEALTH_HOLD = "Duración del aviso (seg.)"
L.UI_STEALTH_SOUND = "Reproducir sonido de sigilo"
L.UI_STEALTH_FLASH = "Destello de pantalla al sigilo"
L.UI_SYNC = "Sincronizar ahora"
L.UI_TAB_ATTACKERS = "Atacantes"
L.UI_TAB_GUILDS = "Gremios"
L.UI_TAB_PLAYERS = "Jugadores"
L.UI_TAB_STATS = "Estadísticas"
L.UI_TITLE = "Kill on Sight"
L.UI_TYPE = "Tipo"
L.UI_ZONE = "Zona"
L.UI_REMOVE_KOS = "Quitar de KoS"
L.UI_CLEAR_NEARBY = "Limpiar lista cercana"
L.UI_NEARBY_COUNT = "Cerca: %d"
L.UI_ADD_KOS_TARGET = "Añadir KoS (objetivo)"
L.ERR_NO_PLAYER_TARGET = "No hay jugador seleccionado."
L.UI_BANNER_TIMING = "Temporización del aviso"
L.UI_BANNER_HOLD_HELP = "Cuánto tiempo permanece el aviso totalmente visible antes de desvanecerse."
L.UI_BANNER_FADE_HELP = "Cuánto tarda el aviso en desvanecerse suavemente."
L.UI_LIST_PLAYERS = "Jugadores: %s"
L.UI_LIST_GUILDS = "Gremios: %s"

L.MSG_LOADED = "Cargado. Escribe /kos show"
L.UI_NEARBY_HEADER = "Nombre / Nivel / Hora"

L.STEALTH_DETECTED_TITLE = "¡Jugador en sigilo detectado!"

L.UI_STATS_TITLE = "Estadísticas de enemigos"
L.UI_STATS_KOS_TAG = "KoS"
L.UI_TAG_KOS = "KoS"
L.UI_TAG_GUILD = "Gremio"
L.UI_STATS_KOS_ONLY = "Solo KoS"
L.UI_STATS_PVP_ONLY = "Solo JcJ"
L.UI_STATS_RESET = "Restablecer"
L.UI_STATS_SEEN = "Visto"
L.UI_STATS_WINS = "Victoria"
L.UI_STATS_LOSES = "Derrota"
L.UI_STATS_RESET_CONFIRM = "¿Restablecer estadísticas de enemigos?"
L.UI_STATS_FIRSTSEEN = "Visto por primera vez"
L.UI_STATS_SORT_LASTSEEN = "Visto por última vez"
L.UI_STATS_SORT_NAME = "Nombre"
L.UI_STATS_SORT_SEEN = "Visto"
L.UI_STATS_SORT_WINS = "Victorias"
L.UI_STATS_SORT_LOSES = "Derrotas"

L.TT_MINIMAP_TITLE = "Matar a la vista"
L.TT_MINIMAP_LEFTCLICK = "Clic izquierdo: Abrir/Cerrar"
L.TT_MINIMAP_RIGHTCLICK = "Clic derecho: Menú"
L.TT_KOS = "Matar al ver"
L.TT_GUILD = "Hermandad"
L.TT_NOT_TARGETABLE = "No se puede seleccionar ahora"
L.TT_GUILD_KOS = "KoS de gremio"
L.TT_LEVEL_FMT = "Nivel %s"

L.UI_NEARBY_SOUND = "Sonido de la lista de cercanos"

L.UI_ATTACKERS_TITLE = "Atacantes"

-- Notes / Spy import
L.UI_NOTE = L.UI_NOTE or "Note"
L.UI_NOTE_EDIT = L.UI_NOTE_EDIT or "Edit Note"
L.UI_NOTE_SAVE = L.UI_NOTE_SAVE or "Save"
L.UI_NOTE_CLEAR = L.UI_NOTE_CLEAR or "Clear"
L.UI_NOTE_CANCEL = L.UI_NOTE_CANCEL or "Cancel"
L.UI_NOTE_EMPTY = L.UI_NOTE_EMPTY or "(No note)"
L.UI_IMPORTSPY_NONE = L.UI_IMPORTSPY_NONE or "Spy import complete - no new KoS entries found."
L.UI_IMPORTSPY_RESULT = L.UI_IMPORTSPY_RESULT or "Spy import complete: %d added, %d already existed."
L.UI_NOTES = "Notas"

L.UI_NEARBY_BG_DARKNESS = "Oscuridad del fondo de la ventana de cercanos"

-- Battleground options
L.UI_BATTLEGROUNDS = "Campos de batalla"
L.UI_BG_MUTE_SOUNDS = "Silenciar todos los sonidos de notificación en campos de batalla"
