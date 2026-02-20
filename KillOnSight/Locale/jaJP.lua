-- Locale/jaJP.lua
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

if not (GetLocale() == "jaJP") then return end

L.ACTIVITY = "%s 付近: %s (%s)%s"
L.ADDED_GUILD = "ギルドを %s に追加: %s"
L.ADDED_PLAYER = "プレイヤーを %s に追加: %s"
L.ADDON_PREFIX = "KILLONSIGHT"
L.CMD_HELP = "コマンド: /kos help | show | add [名前] | remove <名前> | addguild <ギルド> | removeguild <ギルド> | list | sync | statsprune"
L.GUILD_KOS = "ギルド-KoS"
L.HIDDEN = "隠密"
L.KOS = "KoS"
L.NOT_FOUND = "見つかりません: %s"
L.REMOVED_GUILD = "ギルドを削除: %s"
L.REMOVED_PLAYER = "プレイヤーを削除: %s"
L.SEEN = "%s 付近で発見: %s%s"
L.SEEN_GUILD = "%s のギルド付近で発見: %s (%s)%s"
L.SEEN_HIDDEN = "隠密を検知: %s"
L.SYNC_COOLDOWN = "同期クールダウン中: 残り %ds。"
L.SYNC_DISABLED = "同期にはギルドに所属している必要があります。"
L.SYNC_DONE = "同期完了。"
L.SYNC_RECEIVED = "%s から同期データを受信。"
L.SYNC_SENT = "同期リクエストを送信。"
L.UI_ADD = "追加"
L.UI_ADD_GUILD = "ギルド追加"
L.UI_ADD_KOS = "KoS 追加"
L.UI_ALERT_NEW = "新しい付近の敵を通知"
L.UI_ATTACKED_AT = "攻撃"
L.UI_CLEAR = "クリア"
L.UI_CLOSE = "閉じる"
L.UI_FLASH = "点滅"
L.UI_GUILD = "ギルド"
L.UI_INSTANCES = "インスタンスで通知"
L.UI_ALERTS = "KoS / ギルド"
L.UI_NEARBY_HEADING = "付近"
L.UI_LAST_SEEN = "最終確認"
L.UI_CLASS = "クラス"
L.UI_NAME = "名前"
L.UI_NEARBY_ALPHA = "付近の透明度"
L.UI_NEARBY_AUTOHIDE = "空なら自動非表示"
L.UI_DISABLE_GOBLIN_TOWNS = "ブーティベイ / ガジェッツァンでは通知を無効化"
L.SUBZONE_BOOTY_BAY = "ブーティベイ"
L.SUBZONE_GADGETZAN = "ガジェッツァン"
L.UI_NEARBY_FADE = "フェードイン/アウト"
L.UI_NEARBY_FRAME = "付近ウィンドウ"
L.UI_NEARBY_LOCK = "付近ウィンドウを固定"
L.UI_NEARBY_MINIMAL = "超ミニマル付近ウィンドウ"
L.UI_NEARBY_ROWFADE = "行ごとのフェードタイマー"
L.UI_NEARBY_ROWICONS = "行アイコン (クラス/髑髏)"
L.UI_NEARBY_SCALE = "付近ウィンドウの倍率"
L.UI_NEARBY_NAME_FONT = "近くの名前のフォント"
L.UI_NEARBY_NAME_SIZE = "近くの名前のサイズ"
L.UI_NEARBY_RANGE_CLAMP = "検知距離（クラシック風）"

L.UI_OPTIONS = "オプション"

L.UI_OPTIONS_TITLE = "オプション"
L.UI_REMOVE = "削除"
L.UI_SOUND = "サウンド"
L.UI_STEALTH = "ステルス検知"
L.UI_STEALTH_ADD_NEARBY = "隠密を付近リストに追加"
L.UI_STEALTH_BANNER = "中央警告バナーを表示"
L.UI_STEALTH_CHAT = "チャット通知"
L.UI_STEALTH_ENABLE = "ステルス検知を有効化"
L.UI_STEALTH_FADE = "バナーのフェード(秒)"
L.UI_STEALTH_HOLD = "バナー表示時間(秒)"
L.UI_STEALTH_SOUND = "ステルス音を再生"
L.UI_STEALTH_FLASH = "ステルス検知で画面点滅"
L.UI_SYNC = "今すぐ同期"
L.UI_TAB_ATTACKERS = "攻撃者"
L.UI_TAB_GUILDS = "ギルド"
L.UI_TAB_PLAYERS = "プレイヤー"
L.UI_TAB_STATS = "統計"
L.UI_THROTTLE = "間隔 (秒)"
L.UI_TITLE = "即排除"
L.UI_TYPE = "種類"
L.UI_ZONE = "ゾーン"
L.UI_REMOVE_KOS = "KoS を削除"
L.UI_CLEAR_NEARBY = "付近リストをクリア"
L.UI_NEARBY_COUNT = "付近: %d"
L.UI_ADD_KOS_TARGET = "KoS 追加 (ターゲット)"
L.ERR_NO_PLAYER_TARGET = "プレイヤーをターゲットしていません。"
L.UI_BANNER_TIMING = "バナー時間設定"
L.UI_BANNER_HOLD_HELP = "警告が完全に表示されたまま維持される時間。"
L.UI_BANNER_FADE_HELP = "警告が滑らかにフェードアウトする時間。"
L.UI_LIST_PLAYERS = "プレイヤー: %s"
L.UI_LIST_GUILDS = "ギルド: %s"
L.MSG_LOADED = "読み込み完了。/kos show"
L.UI_NEARBY_HEADER = "名前 / レベル / 時間"
L.STEALTH_DETECTED_TITLE = "ステルスプレイヤーを検知!"
L.UI_STATS_TITLE = "敵統計"
L.UI_STATS_KOS_TAG = "KoS"
L.UI_TAG_KOS = "KoS"
L.UI_TAG_GUILD = "ギルド"
L.UI_STATS_KOS_ONLY = "KoSのみ"
L.UI_STATS_PVP_ONLY = "PvPのみ"
L.UI_STATS_RESET = "リセット"
L.UI_STATS_RESET_CONFIRM = "敵統計をリセットしますか？元に戻せません。"
L.UI_STATS_FIRSTSEEN = "初確認"
L.UI_STATS_SORT_LASTSEEN = "最終確認"
L.UI_STATS_SORT_NAME = "名前"
L.UI_STATS_SORT_SEEN = "確認回数"
L.UI_STATS_SORT_WINS = "勝利"
L.UI_STATS_SORT_LOSES = "敗北"
L.UI_STATS_SEEN = "確認回数"
L.UI_STATS_WINS = "勝"
L.UI_STATS_LOSES = "敗"
L.TT_MINIMAP_TITLE = "即排除"
L.TT_MINIMAP_LEFTCLICK = "左クリック: 開閉"
L.TT_MINIMAP_RIGHTCLICK = "右クリック: メニュー"
L.TT_ON_KOS = "KoSリストに登録"
L.TT_GUILD = "ギルド"
L.TT_KOS = "即時攻撃"
L.TT_NOT_TARGETABLE = "対象不可"
L.TT_GUILD_KOS = "ギルド-KoS"
L.TT_LEVEL_FMT = "レベル %s"
L.UI_NEARBY_SOUND = "付近リスト音"
L.UI_ATTACKERS_TITLE = "攻撃者"

-- Notes / Spy import
L.UI_NOTE = L.UI_NOTE or "Note"
L.UI_NOTE_EDIT = L.UI_NOTE_EDIT or "Edit Note"
L.UI_NOTE_SAVE = L.UI_NOTE_SAVE or "Save"
L.UI_NOTE_CLEAR = L.UI_NOTE_CLEAR or "Clear"
L.UI_NOTE_CANCEL = L.UI_NOTE_CANCEL or "Cancel"
L.UI_NOTE_EMPTY = L.UI_NOTE_EMPTY or "(No note)"
L.UI_IMPORTSPY_NONE = L.UI_IMPORTSPY_NONE or "Spy import complete - no new KoS entries found."
L.UI_IMPORTSPY_RESULT = L.UI_IMPORTSPY_RESULT or "Spy import complete: %d added, %d already existed."
L.UI_NOTES = "メモ"


L["TT_NOT_TARGETABLE"] = "現在ターゲット不可"

L.UI_NEARBY_BG_DARKNESS = "付近ウィンドウ背景の暗さ"
