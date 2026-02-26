-- Locale/ptBR.lua
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

if not (GetLocale() == "ptBR") then return end

L.ACTIVITY = "%s por perto: %s (%s)%s"
L.ADDED_GUILD = "Guilda adicionada a %s: %s"
L.ADDED_PLAYER = "Jogador adicionado a %s: %s"
L.ADDON_PREFIX = "KILLONSIGHT"
L.CMD_HELP = "Comandos: /kos help | show | add [nome] | remove <nome> | addguild <guilda> | removeguild <guilda> | list | sync | statsprune"
L.GUILD_KOS = "KoS-Guilda"
L.HIDDEN = "Oculto"
L.KOS = "KoS"
L.NOT_FOUND = "Não encontrado: %s"
L.REMOVED_GUILD = "Guilda removida: %s"
L.REMOVED_PLAYER = "Jogador removido: %s"
L.SEEN = "%s avistado por perto: %s%s"
L.SEEN_GUILD = "Guilda de %s avistada por perto: %s (%s)%s"
L.SEEN_HIDDEN = "Oculto detectado: %s"
L.SYNC_COOLDOWN = "Sincronização em recarga: %ds restantes."
L.SYNC_DISABLED = "A sincronização requer estar em uma guilda."
L.SYNC_SENT = "Pedido de sincronização enviado."
L.SYNC_TOO_OLD = "Sincronização falhou: o par está muito defasado (oldest=%s, current=%s)."
L.UI_ADD = "Adicionar"
L.UI_ADD_GUILD = "Adicionar guilda"
L.UI_ADD_KOS = "Adicionar KoS"
L.UI_CLEAR = "Limpar"
L.UI_CLOSE = "Fechar"
L.UI_FLASH = "Piscar"
L.UI_GUILD = "Guilda"
L.UI_ALERTS = "KoS / Guilda"
L.UI_NEARBY_HEADING = "Próximos"
L.UI_LAST_SEEN = "Visto por último"
L.UI_CLASS = "Classe"
L.UI_NAME = "Nome"
L.UI_NEARBY_AUTOHIDE = "Ocultar automaticamente quando vazia"
L.UI_DISABLE_GOBLIN_TOWNS = "Desativar alertas em Angra do Butim / Gadgetzan"
L.SUBZONE_BOOTY_BAY = "Angra do Butim"
L.SUBZONE_GADGETZAN = "Gadgetzan"
L.UI_NEARBY_FRAME = "Janela de próximos"
L.UI_NEARBY_LOCK = "Bloquear janela de próximos"
L.UI_NEARBY_SCALE = "Escala da janela de próximos"
L.UI_NEARBY_NAME_FONT = "Fonte dos nomes próximos"
L.UI_NEARBY_NAME_SIZE = "Tamanho da fonte dos nomes próximos"
L.UI_NEARBY_RANGE_CLAMP = "Alcance de detecção (estilo Classic)"

L.UI_OPTIONS = "Opções"

L.UI_OPTIONS_TITLE = "Opções"
L.UI_REMOVE = "Remover"
L.UI_SOUND = "Som"
L.UI_STEALTH = "Detecção de furtividade"
L.UI_STEALTH_ADD_NEARBY = "Adicionar ocultos à lista Próximos"
L.UI_STEALTH_BANNER = "Mostrar aviso central"
L.UI_STEALTH_CHAT = "Notificação no chat"
L.UI_STEALTH_ENABLE = "Ativar detecção de furtividade"
L.UI_STEALTH_FADE = "Desvanecer aviso (segundos)"
L.UI_STEALTH_HOLD = "Duração do aviso (segundos)"
L.UI_STEALTH_SOUND = "Tocar som de furtividade"
L.UI_STEALTH_FLASH = "Piscar a tela ao furtivo"
L.UI_SYNC = "Sincronizar agora"
L.UI_TAB_ATTACKERS = "Atacantes"
L.UI_TAB_GUILDS = "Guildas"
L.UI_TAB_PLAYERS = "Jogadores"
L.UI_TAB_STATS = "Estatísticas"
L.UI_TITLE = "Kill on Sight"
L.UI_TYPE = "Tipo"
L.UI_ZONE = "Zona"
L.UI_REMOVE_KOS = "Remover KoS"
L.UI_CLEAR_NEARBY = "Limpar lista de proximidade"
L.UI_NEARBY_COUNT = "Perto: %d"
L.UI_ADD_KOS_TARGET = "Adicionar KoS (alvo)"
L.ERR_NO_PLAYER_TARGET = "Nenhum jogador selecionado."
L.UI_BANNER_TIMING = "Tempo do aviso"
L.UI_BANNER_HOLD_HELP = "Quanto tempo o aviso fica totalmente visível antes de desaparecer."
L.UI_BANNER_FADE_HELP = "Quanto tempo o aviso leva para desaparecer suavemente."
L.UI_LIST_PLAYERS = "Jogadores: %s"
L.UI_LIST_GUILDS = "Guildas: %s"

L.MSG_LOADED = "Carregado. Digite /kos show"
L.UI_NEARBY_HEADER = "Nome / Nível / Hora"

L.STEALTH_DETECTED_TITLE = "Jogador furtivo detectado!"

L.UI_STATS_TITLE = "Estatísticas de inimigos"
L.UI_STATS_KOS_TAG = "KoS"
L.UI_TAG_KOS = "KoS"
L.UI_TAG_GUILD = "Guild"
L.UI_STATS_KOS_ONLY = "Apenas KoS"
L.UI_STATS_PVP_ONLY = "Apenas JxJ"
L.UI_STATS_RESET = "Redefinir"
L.UI_STATS_SEEN = "Visto"
L.UI_STATS_WINS = "Vitória"
L.UI_STATS_LOSES = "Derrota"
L.UI_STATS_RESET_CONFIRM = "Redefinir estatísticas de inimigos?"
L.UI_STATS_FIRSTSEEN = "Visto pela primeira vez"
L.UI_STATS_SORT_LASTSEEN = "Visto por último"
L.UI_STATS_SORT_NAME = "Nome"
L.UI_STATS_SORT_SEEN = "Visto"
L.UI_STATS_SORT_WINS = "Vitórias"
L.UI_STATS_SORT_LOSES = "Derrotas"

L.TT_MINIMAP_TITLE = "Matar à Vista"
L.TT_MINIMAP_LEFTCLICK = "Clique esquerdo: Abrir/Fechar"
L.TT_MINIMAP_RIGHTCLICK = "Clique direito: Menu"
L.TT_GUILD = "Guilda"
L.TT_KOS = "Matar ao ver"
L.TT_NOT_TARGETABLE = "Não é possível selecionar agora"
L.TT_GUILD_KOS = "KoS da guilda"
L.TT_LEVEL_FMT = "Nível %s"

L.UI_NEARBY_SOUND = "Som da lista de próximos"

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

L.UI_NEARBY_BG_DARKNESS = "Escuridão do fundo da janela de próximos"

-- Battleground options
L.UI_BATTLEGROUNDS = "Campos de batalha"
L.UI_BG_MUTE_SOUNDS = "Silenciar todos os sons de notificação em campos de batalha"
