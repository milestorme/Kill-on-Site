-- Locale/zhCN.lua
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

if not (GetLocale() == "zhCN") then return end

L.ACTIVITY = "%s 附近：%s（%s）%s"
L.ADDED_GUILD = "已将公会加入 %s：%s"
L.ADDED_PLAYER = "已将玩家加入 %s：%s"
L.ADDON_PREFIX = "KILLONSIGHT"
L.CMD_HELP = "命令：/kos help | show | add [名字] | remove <名字> | addguild <公会> | removeguild <公会> | list | sync | statsprune"
L.GUILD_KOS = "公会-KoS"
L.HIDDEN = "潜行"
L.KOS = "KoS"
L.NOT_FOUND = "未找到：%s"
L.REMOVED_GUILD = "已移除公会：%s"
L.REMOVED_PLAYER = "已移除玩家：%s"
L.SEEN = "附近发现%s：%s%s"
L.SEEN_GUILD = "附近发现%s的公会：%s（%s）%s"
L.SEEN_HIDDEN = "发现潜行：%s"
L.SYNC_COOLDOWN = "同步冷却中：剩余 %d 秒。"
L.SYNC_DISABLED = "同步需要在队伍/团队或公会中。"
L.SYNC_DONE = "同步完成。"
L.SYNC_RECEIVED = "已从 %s 接收同步数据。"
L.SYNC_SENT = "已发送同步请求。"
L.UI_ADD = "Add"
L.UI_ADD_GUILD = "添加公会"
L.UI_ADD_KOS = "添加 KoS"
L.UI_ALERT_NEW = "Alert on new nearby enemy"
L.UI_ATTACKED_AT = "被攻击"
L.UI_CLEAR = "清除"
L.UI_CLOSE = "关闭"
L.UI_FLASH = "闪烁"
L.UI_GUILD = "公会"
L.UI_INSTANCES = "副本内提示"
L.UI_LAST_SEEN = "上次出现"
L.UI_CLASS = "职业"
L.UI_NAME = "名字"
L.UI_NEARBY_ALPHA = "附近透明度"
L.UI_NEARBY_AUTOHIDE = "为空时自动隐藏"
L.UI_DISABLE_GOBLIN_TOWNS = "在藏宝海湾 / 加基森禁用警报"
L.SUBZONE_BOOTY_BAY = "藏宝海湾"
L.SUBZONE_GADGETZAN = "加基森"
L.UI_NEARBY_FADE = "淡入/淡出"
L.UI_NEARBY_FRAME = "附近窗口"
L.UI_NEARBY_LOCK = "锁定附近窗口"
L.UI_NEARBY_MINIMAL = "超简附近窗口"
L.UI_NEARBY_ROWFADE = "每行淡出计时"
L.UI_NEARBY_ROWICONS = "行图标（职业/骷髅）"
L.UI_NEARBY_SCALE = "附近窗口缩放"
L.UI_NEARBY_NAME_FONT = "附近名字字体"
L.UI_NEARBY_NAME_SIZE = "附近名字字号"
L.UI_OPTIONS = "Options"

L.UI_OPTIONS_TITLE = "选项"
L.UI_REMOVE = "Remove"
L.UI_SOUND = "声音"
L.UI_STEALTH = "潜行侦测"
L.UI_STEALTH_ADD_NEARBY = "将潜行者加入附近列表"
L.UI_STEALTH_BANNER = "显示中央警告条"
L.UI_STEALTH_ENABLE = "启用潜行侦测"
L.UI_STEALTH_FADE = "警告淡出（秒）"
L.UI_STEALTH_HOLD = "警告停留（秒）"
L.UI_STEALTH_SOUND = "播放潜行提示音"
L.UI_SYNC = "立即同步"
L.UI_TAB_ATTACKERS = "攻击者"
L.UI_TAB_GUILDS = "公会"
L.UI_TAB_PLAYERS = "玩家"
L.UI_TAB_STATS = "统计"
L.UI_THROTTLE = "节流（秒）"
L.UI_TITLE = "Kill on Sight"
L.UI_TYPE = "类型"
L.UI_ZONE = "区域"
L.UI_REMOVE_KOS = "移除仇杀名单"
L.UI_CLEAR_NEARBY = "清空附近列表"
L.UI_NEARBY_COUNT = "附近：%d"
L.UI_ADD_KOS_TARGET = "添加仇杀（目标）"
L.ERR_NO_PLAYER_TARGET = "未选中玩家目标。"
L.UI_BANNER_TIMING = "提示条计时"
L.UI_BANNER_HOLD_HELP = "提示在开始淡出前保持完全可见的时间。"
L.UI_BANNER_FADE_HELP = "提示条平滑淡出的时间。"
L.UI_LIST_PLAYERS = "玩家：%s"
L.UI_LIST_GUILDS = "公会：%s"


L.MSG_LOADED = "已加载。输入 /kos show"
L.UI_NEARBY_HEADER = "名字 / 等级 / 时间"



L.STEALTH_DETECTED_TITLE = "侦测到潜行玩家！"

L.UI_STATS_TITLE = "敌人统计"
L.UI_STATS_KOS_TAG = "KoS"
L.UI_TAG_KOS = "KoS"
L.UI_TAG_GUILD = "公会"
L.UI_STATS_KOS_ONLY = "仅KoS"
L.UI_STATS_PVP_ONLY = "仅PvP"
L.UI_STATS_RESET = "重置"
L.UI_STATS_SEEN = "出现"
L.UI_STATS_WINS = "胜利"
L.UI_STATS_LOSES = "失败"
L.UI_STATS_RESET_CONFIRM = "重置敌人统计？"
L.UI_STATS_FIRSTSEEN = "首次出现"
L.UI_STATS_SORT_LASTSEEN = "最后出现"
L.UI_STATS_SORT_NAME = "名称"
L.UI_STATS_SORT_SEEN = "出现"
L.UI_STATS_SORT_WINS = "胜利"
L.UI_STATS_SORT_LOSES = "失败"

L.TT_MINIMAP_TITLE = 'Kill on Sight'

L.TT_MINIMAP_LEFTCLICK = '左键：打开/关闭'

L.TT_MINIMAP_RIGHTCLICK = '右键：菜单'

L.TT_ON_KOS = '在KoS列表'

L.TT_GUILD_KOS = '公会KoS'

L.TT_LEVEL_FMT = '等级 %s'

L.UI_STEALTH_CHAT = "Chat notification"

L.UI_NEARBY_SOUND = "Nearby list sound"


-- Added/updated for new 3.0.x UI & features
L.UI_ADD = "添加"
L.UI_REMOVE = "移除"
L.UI_OPTIONS = "选项"
L.UI_ALERT_NEW = "附近出现新敌人时提醒"
L.UI_STEALTH_CHAT = "聊天提示"
L.UI_NEARBY_SOUND = "附近列表音效"
L.UI_ALERTS = "KoS / 公会"
L.UI_NEARBY_HEADING = "附近"
L.TT_MINIMAP_TITLE = "Kill on Sight"
L.TT_MINIMAP_LEFTCLICK = "左键：打开/关闭"
L.TT_MINIMAP_RIGHTCLICK = "右键：菜单"
L.TT_ON_KOS = "在KoS列表中"
L.TT_GUILD_KOS = "公会KoS"
L.TT_LEVEL_FMT = "等级 %s"
L.UI_ATTACKERS_TITLE = "攻击者"

-- Notes / Spy import
L.UI_NOTE = L.UI_NOTE or "Note"
L.UI_NOTE_EDIT = L.UI_NOTE_EDIT or "Edit Note"
L.UI_NOTE_SAVE = L.UI_NOTE_SAVE or "Save"
L.UI_NOTE_CLEAR = L.UI_NOTE_CLEAR or "Clear"
L.UI_NOTE_CANCEL = L.UI_NOTE_CANCEL or "Cancel"
L.UI_NOTE_EMPTY = L.UI_NOTE_EMPTY or "(No note)"
L.UI_IMPORTSPY_NONE = L.UI_IMPORTSPY_NONE or "Spy import complete - no new KoS entries found."
L.UI_IMPORTSPY_RESULT = L.UI_IMPORTSPY_RESULT or "Spy import complete: %d added, %d already existed."
L.UI_NOTES = "备注"

L.RETAIL_NEARBY_LIMITED_NAMEPLATES_OFF = "附近检测受限，因为敌方姓名版已关闭。请在“界面 > 名称”中启用敌方姓名版以获得完整检测。可按 V 键切换。"
