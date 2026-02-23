-- Locale/ptPT.lua
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

if not (GetLocale() == "ptPT") then return end

L.ACTIVITY = "%s por perto: %s (%s)%s"
L.ADDED_GUILD = "Guild adicionada a %s: %s"
L.ADDED_PLAYER = "Jogador adicionado a %s: %s"
L.ADDON_PREFIX = "KILLONSIGHT"
L.CMD_HELP = "Comandos: /kos help | show | add [nome] | remove <nome> | addguild <guild> | removeguild <guild> | list | sync | statsprune"
L.GUILD_KOS = "Guilda-KoS"
L.HIDDEN = "Oculto"
L.KOS = "KoS"
L.NOT_FOUND = "Não encontrado: %s"
L.REMOVED_GUILD = "Guild removida: %s"
L.REMOVED_PLAYER = "Jogador removido: %s"
L.SEEN = "%s avistado por perto: %s%s"
L.SEEN_GUILD = "Guild de %s avistada por perto: %s (%s)%s"
L.SEEN_HIDDEN = "Oculto detetado: %s"
L.SYNC_COOLDOWN = "Sincronização em recarga: faltam %ds."
L.SYNC_DISABLED = "A sincronização requer estar numa guild."
L.SYNC_DONE = "Sincronização concluída."
L.SYNC_RECEIVED = "Dados de sincronização recebidos de %s."
L.SYNC_SENT = "Pedido de sincronização enviado."
L.UI_ADD = "Adicionar"
L.UI_ADD_GUILD = "Adicionar guild"
L.UI_ADD_KOS = "Adicionar KoS"
L.UI_ALERT_NEW = "Avisar ao surgir novo inimigo por perto"
L.UI_ATTACKED_AT = "Atacado"
L.UI_CLEAR = "Limpar"
L.UI_CLOSE = "Fechar"
L.UI_FLASH = "Piscar"
L.UI_GUILD = "Guilda"
L.UI_INSTANCES = "Notificar em instâncias"
L.UI_ALERTS = "KoS / Guilda"
L.UI_NEARBY_HEADING = "Por perto"
L.UI_LAST_SEEN = "Visto pela última vez"
L.UI_CLASS = "Classe"
L.UI_NAME = "Nome"
L.UI_NEARBY_ALPHA = "Transparência (por perto)"
L.UI_NEARBY_AUTOHIDE = "Ocultar automaticamente quando vazio"
L.UI_DISABLE_GOBLIN_TOWNS = "Desativar alertas em Angra do Butim / Gadgetzan"
L.SUBZONE_BOOTY_BAY = "Angra do Butim"
L.SUBZONE_GADGETZAN = "Gadgetzan"
L.UI_NEARBY_FADE = "Esbater entrada/saída"
L.UI_NEARBY_FRAME = "Janela 'por perto'"
L.UI_NEARBY_LOCK = "Bloquear janela 'por perto'"
L.UI_NEARBY_MINIMAL = "Janela 'por perto' ultra-minimal"
L.UI_NEARBY_ROWFADE = "Temporizadores de esbatimento por linha"
L.UI_NEARBY_ROWICONS = "Ícones por linha (classe/caveira)"
L.UI_NEARBY_SCALE = "Escala da janela 'por perto'"
L.UI_NEARBY_NAME_FONT = "Tipo de letra dos nomes próximos"
L.UI_NEARBY_NAME_SIZE = "Tamanho do tipo de letra dos nomes próximos"
L.UI_NEARBY_RANGE_CLAMP = "Alcance de deteção (estilo Classic)"

L.UI_OPTIONS = "Opções"

L.UI_OPTIONS_TITLE = "Opções"
L.UI_REMOVE = "Remover"
L.UI_SOUND = "Som"
L.UI_STEALTH = "Deteção de furtividade"
L.UI_STEALTH_ADD_NEARBY = "Adicionar ocultos à lista 'por perto'"
L.UI_STEALTH_BANNER = "Mostrar aviso central"
L.UI_STEALTH_CHAT = "Notificação no chat"
L.UI_STEALTH_ENABLE = "Ativar deteção de furtividade"
L.UI_STEALTH_FADE = "Esbater aviso (seg)"
L.UI_STEALTH_HOLD = "Manter aviso (seg)"
L.UI_STEALTH_SOUND = "Reproduzir som de furtividade"
L.UI_STEALTH_FLASH = "Flash screen on stealth"
L.UI_SYNC = "Sincronizar agora"
L.UI_TAB_ATTACKERS = "Agressores"
L.UI_TAB_GUILDS = "Guildas"
L.UI_TAB_PLAYERS = "Jogadores"
L.UI_TAB_STATS = "Estatísticas"
L.UI_THROTTLE = "Intervalo (seg)"
L.UI_TITLE = "Matar à Vista"
L.UI_TYPE = "Tipo"
L.UI_ZONE = "Zona"
L.UI_REMOVE_KOS = "Remover KoS"
L.UI_CLEAR_NEARBY = "Limpar lista 'por perto'"
L.UI_NEARBY_COUNT = "Por perto: %d"
L.UI_ADD_KOS_TARGET = "Adicionar KoS (alvo)"
L.ERR_NO_PLAYER_TARGET = "Nenhum jogador selecionado."
L.UI_BANNER_TIMING = "Tempos do aviso"
L.UI_BANNER_HOLD_HELP = "Quanto tempo o aviso fica totalmente visível antes de esbater."
L.UI_BANNER_FADE_HELP = "Quanto tempo o aviso leva a esbater suavemente."
L.UI_LIST_PLAYERS = "Jogadores: %s"
L.UI_LIST_GUILDS = "Guildas: %s"
L.MSG_LOADED = "Carregado. Escreva /kos show"
L.UI_NEARBY_HEADER = "Nome / Nível / Tempo"
L.STEALTH_DETECTED_TITLE = "Jogador em furtividade detetado!"
L.UI_STATS_TITLE = "Estatísticas de inimigos"
L.UI_STATS_KOS_TAG = "KoS"
L.UI_TAG_KOS = "KoS"
L.UI_TAG_GUILD = "Guilda"
L.UI_STATS_KOS_ONLY = "Apenas KoS"
L.UI_STATS_PVP_ONLY = "Apenas PvP"
L.UI_STATS_RESET = "Repor"
L.UI_STATS_RESET_CONFIRM = "Repor estatísticas de inimigos? Não pode ser desfeito."
L.UI_STATS_FIRSTSEEN = "Visto pela primeira vez"
L.UI_STATS_SORT_LASTSEEN = "Última vez"
L.UI_STATS_SORT_NAME = "Nome"
L.UI_STATS_SORT_SEEN = "Visto"
L.UI_STATS_SORT_WINS = "Vitórias"
L.UI_STATS_SORT_LOSES = "Derrotas"
L.UI_STATS_SEEN = "Visto"
L.UI_STATS_WINS = "Vitória"
L.UI_STATS_LOSES = "Derrota"
L.TT_MINIMAP_TITLE = "Matar à Vista"
L.TT_MINIMAP_LEFTCLICK = "Clique esq.: Abrir/Fechar"
L.TT_MINIMAP_RIGHTCLICK = "Clique dir.: Menu"
L.TT_ON_KOS = "Na lista KoS"
L.TT_GUILD = "Guilda"
L.TT_KOS = "Matar ao ver"
L.TT_NOT_TARGETABLE = "Não pode ser alvo"
L.TT_GUILD_KOS = "Guilda-KoS"
L.TT_LEVEL_FMT = "Nível %s"
L.UI_NEARBY_SOUND = "Som da lista 'por perto'"
L.UI_ATTACKERS_TITLE = "Agressores"

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


L["TT_NOT_TARGETABLE"] = "Não é possível selecionar agora"

L.UI_NEARBY_BG_DARKNESS = "Escuridão do fundo da janela de próximos"

L.ENEMY_NAMEPLATES_REQUIRED = "A deteção passiva nas proximidades requer que as Placas de Nome dos Inimigos estejam ativadas."
