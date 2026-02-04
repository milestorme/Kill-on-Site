-- Locale/koKR.lua
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

if not (GetLocale() == "koKR") then return end

L.ACTIVITY = "%s 근처: %s (%s)%s"
L.ADDED_GUILD = "%s에 길드 추가: %s"
L.ADDED_PLAYER = "%s에 플레이어 추가: %s"
L.ADDON_PREFIX = "KILLONSIGHT"
L.CMD_HELP = "명령어: /kos help | show | add [이름] | remove <이름> | addguild <길드> | removeguild <길드> | list | sync | statsprune"
L.GUILD_KOS = "길드-KoS"
L.HIDDEN = "은신"
L.KOS = "KoS"
L.NOT_FOUND = "찾을 수 없음: %s"
L.REMOVED_GUILD = "길드 제거: %s"
L.REMOVED_PLAYER = "플레이어 제거: %s"
L.SEEN = "근처에서 %s 발견: %s%s"
L.SEEN_GUILD = "근처에서 %s의 길드 발견: %s (%s)%s"
L.SEEN_HIDDEN = "은신 감지: %s"
L.SYNC_COOLDOWN = "동기화 대기시간: %ds 남음."
L.SYNC_DISABLED = "동기화는 파티/공격대 또는 길드에서만 가능합니다."
L.SYNC_DONE = "동기화 완료."
L.SYNC_RECEIVED = "%s로부터 동기화 데이터를 받았습니다."
L.SYNC_SENT = "동기화 요청을 보냈습니다."
L.UI_ADD = "Add"
L.UI_ADD_GUILD = "길드 추가"
L.UI_ADD_KOS = "KoS 추가"
L.UI_ALERT_NEW = "Alert on new nearby enemy"
L.UI_ATTACKED_AT = "공격 받음"
L.UI_CLEAR = "지우기"
L.UI_CLOSE = "닫기"
L.UI_FLASH = "점멸"
L.UI_GUILD = "길드"
L.UI_INSTANCES = "인스턴스에서 알림"
L.UI_LAST_SEEN = "마지막 목격"
L.UI_CLASS = "직업"
L.UI_NAME = "이름"
L.UI_NEARBY_ALPHA = "근처 투명도"
L.UI_NEARBY_AUTOHIDE = "비어 있으면 자동 숨김"
L.UI_DISABLE_GOBLIN_TOWNS = "무법항 / 가젯잔에서 알림 끄기"
L.SUBZONE_BOOTY_BAY = "무법항"
L.SUBZONE_GADGETZAN = "가젯잔"
L.UI_NEARBY_FADE = "페이드 인/아웃"
L.UI_NEARBY_FRAME = "근처 창"
L.UI_NEARBY_LOCK = "근처 창 잠금"
L.UI_NEARBY_MINIMAL = "초미니 근처 창"
L.UI_NEARBY_ROWFADE = "행별 페이드 타이머"
L.UI_NEARBY_ROWICONS = "행 아이콘 (직업/해골)"
L.UI_NEARBY_SCALE = "근처 창 크기"
L.UI_NEARBY_NAME_FONT = "근처 이름 글꼴"
L.UI_NEARBY_NAME_SIZE = "근처 이름 크기"
L.UI_OPTIONS = "Options"

L.UI_OPTIONS_TITLE = "옵션"
L.UI_REMOVE = "Remove"
L.UI_SOUND = "소리"
L.UI_STEALTH = "은신 감지"
L.UI_STEALTH_ADD_NEARBY = "은신자를 근처 목록에 추가"
L.UI_STEALTH_BANNER = "중앙 경고 배너 표시"
L.UI_STEALTH_ENABLE = "은신 감지 사용"
L.UI_STEALTH_FADE = "배너 페이드 (초)"
L.UI_STEALTH_HOLD = "배너 유지 (초)"
L.UI_STEALTH_SOUND = "은신 소리 재생"
L.UI_SYNC = "지금 동기화"
L.UI_TAB_ATTACKERS = "공격자"
L.UI_TAB_GUILDS = "길드"
L.UI_TAB_PLAYERS = "플레이어"
L.UI_TAB_STATS = "통계"
L.UI_THROTTLE = "제한 (초)"
L.UI_TITLE = "Kill on Sight"
L.UI_TYPE = "유형"
L.UI_ZONE = "지역"
L.UI_REMOVE_KOS = "KoS 제거"
L.UI_CLEAR_NEARBY = "근처 목록 비우기"
L.UI_NEARBY_COUNT = "근처: %d"
L.UI_ADD_KOS_TARGET = "KoS 추가(대상)"
L.ERR_NO_PLAYER_TARGET = "대상 플레이어가 없습니다."
L.UI_BANNER_TIMING = "배너 시간"
L.UI_BANNER_HOLD_HELP = "사라지기 전에 경고가 완전히 보이는 시간입니다."
L.UI_BANNER_FADE_HELP = "경고가 부드럽게 사라지는 데 걸리는 시간입니다."
L.UI_LIST_PLAYERS = "플레이어: %s"
L.UI_LIST_GUILDS = "길드: %s"


L.MSG_LOADED = "로드됨. /kos show 입력"
L.UI_NEARBY_HEADER = "이름 / 레벨 / 시간"



L.STEALTH_DETECTED_TITLE = "은신 플레이어 감지!"

L.UI_STATS_TITLE = "적 통계"
L.UI_STATS_KOS_TAG = "KoS"
L.UI_TAG_KOS = "KoS"
L.UI_TAG_GUILD = "길드"
L.UI_STATS_KOS_ONLY = "KoS만"
L.UI_STATS_PVP_ONLY = "PvP만"
L.UI_STATS_RESET = "초기화"
L.UI_STATS_SEEN = "목격"
L.UI_STATS_WINS = "승리"
L.UI_STATS_LOSES = "패배"
L.UI_STATS_RESET_CONFIRM = "적 통계를 초기화할까요?"
L.UI_STATS_FIRSTSEEN = "최초 목격"
L.UI_STATS_SORT_LASTSEEN = "마지막 목격"
L.UI_STATS_SORT_NAME = "이름"
L.UI_STATS_SORT_SEEN = "목격"
L.UI_STATS_SORT_WINS = "승리"
L.UI_STATS_SORT_LOSES = "패배"

L.TT_MINIMAP_TITLE = 'Kill on Sight'

L.TT_MINIMAP_LEFTCLICK = '왼쪽 클릭: 열기/닫기'

L.TT_MINIMAP_RIGHTCLICK = '오른쪽 클릭: 메뉴'

L.TT_ON_KOS = 'KoS 목록에 있음'

L.TT_GUILD_KOS = '길드 KoS'

L.TT_LEVEL_FMT = '레벨 %s'

L.UI_STEALTH_CHAT = "Chat notification"

L.UI_NEARBY_SOUND = "Nearby list sound"


-- Added/updated for new 3.0.x UI & features
L.UI_ADD = "추가"
L.UI_REMOVE = "제거"
L.UI_OPTIONS = "옵션"
L.UI_ALERT_NEW = "근처에 새로운 적이 나타나면 알림"
L.UI_STEALTH_CHAT = "채팅 알림"
L.UI_NEARBY_SOUND = "근처 목록 소리"
L.UI_ALERTS = "KoS / 길드"
L.UI_NEARBY_HEADING = "근처"
L.TT_MINIMAP_TITLE = "Kill on Sight"
L.TT_MINIMAP_LEFTCLICK = "왼쪽 클릭: 열기/닫기"
L.TT_MINIMAP_RIGHTCLICK = "오른쪽 클릭: 메뉴"
L.TT_ON_KOS = "KoS 목록에 있음"
L.TT_GUILD_KOS = "길드 KoS"
L.TT_LEVEL_FMT = "레벨 %s"
L.UI_ATTACKERS_TITLE = "공격자"

-- Notes / Spy import
L.UI_NOTE = L.UI_NOTE or "Note"
L.UI_NOTE_EDIT = L.UI_NOTE_EDIT or "Edit Note"
L.UI_NOTE_SAVE = L.UI_NOTE_SAVE or "Save"
L.UI_NOTE_CLEAR = L.UI_NOTE_CLEAR or "Clear"
L.UI_NOTE_CANCEL = L.UI_NOTE_CANCEL or "Cancel"
L.UI_NOTE_EMPTY = L.UI_NOTE_EMPTY or "(No note)"
L.UI_IMPORTSPY_NONE = L.UI_IMPORTSPY_NONE or "Spy import complete - no new KoS entries found."
L.UI_IMPORTSPY_RESULT = L.UI_IMPORTSPY_RESULT or "Spy import complete: %d added, %d already existed."
L.UI_NOTES = "메모"

L.RETAIL_NEARBY_LIMITED_NAMEPLATES_OFF = "근처 감지는 적 이름표가 꺼져 있어 제한됩니다. 전체 감지를 위해 적 이름표(인터페이스 > 이름)를 켜세요. V 키로 토글할 수 있습니다."
L.TT_SPEC_LOADING = "살펴보는 중…"
