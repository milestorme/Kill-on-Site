-- KillOnSight: readable chat shares with local import links for addon users.
local ADDON_NAME, KOS = ...
local L = KillOnSight_L
local DB = KillOnSight_DB

local Share = {}
local SHARE_KINDS = {
  KOS = "KoS",
  GUILD = "Guild KoS",
  HONOR = "Honor",
  STATS = "Stats",
}
local SHARE_LABELS = {
  KOS = "KoS Target",
  GUILD = "KoS Guild",
  HONOR = "Honor",
  STATS = "KoS Target",
}
local SHARE_LABEL_KINDS = {
  ["KoS Target Share"] = "KOS",
  ["KoS Guild Share"] = "GUILD",
  ["Honor Share"] = "HONOR",
}

local function Trim(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function NormalizeNames(names)
  local out, seen = {}, {}
  for _, value in ipairs(names or {}) do
    local name = Trim(value)
    if name ~= "" and not name:find("[|;:]", 1) then
      local key = name:lower()
      if not seen[key] then
        seen[key] = true
        out[#out + 1] = name
      end
    end
  end
  table.sort(out, function(a, b) return a:lower() < b:lower() end)
  return out
end

local function ParseShare(message)
  if type(message) ~= "string" then return end
  local label, payload
  for shareLabel in pairs(SHARE_LABEL_KINDS) do
    local marker = "[" .. shareLabel .. "]"
    if message:sub(1, #marker) == marker then
      label = shareLabel
      payload = message:sub(#marker + 1):gsub("^%s+", "")
      break
    end
  end
  local kind = label and SHARE_LABEL_KINDS[label]
  if not kind then return end
  local names = {}
  for name in payload:gmatch("([^;]+)") do
    name = Trim(name)
    if name ~= "" then names[#names + 1] = name end
  end
  names = NormalizeNames(names)
  if #names ~= 1 then return end
  return kind, names
end

local function MakeShareLink(kind, names)
  local title
  if kind == "GUILD" then
    title = L.UI_SHARE_GUILD_LABEL or "KoS Guild Share"
  elseif kind == "HONOR" then
    title = L.UI_SHARE_HONOR_LABEL or "Honor Share"
  else
    title = L.UI_SHARE_TARGET_LABEL or "KoS Target Share"
  end
  local link = "addon:KillOnSight:share:" .. kind .. ":" .. table.concat(names, ";")
  local text = "|cffffcc00[" .. title .. ": " .. (names[1] or "") .. "]|r"
  return "|H" .. link .. "|h" .. text .. "|h"
end

local function FormatMessage(kind, names)
  return "[" .. (SHARE_LABELS[kind] or "Name") .. " Share] " .. table.concat(names, "; ")
end

local function EnsureImportDialog()
  if Share.importDialog then return Share.importDialog end
  local f = CreateFrame("Frame", "KillOnSight_ShareImportDialog", UIParent, "BackdropTemplate")
  f:SetSize(390, 270)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  if f.SetBackdrop then
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=8,right=8,top=8,bottom=8}})
  end
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 14, -14)
  f.title = title

  local message = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  message:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
  message:SetWidth(350)
  message:SetJustifyH("LEFT")
  message:SetJustifyV("TOP")
  f.message = message

  local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 14, -66)
  sf:SetPoint("BOTTOMRIGHT", -32, 54)
  local eb = CreateFrame("EditBox", nil, sf)
  eb:SetMultiLine(true)
  eb:SetAutoFocus(false)
  eb:SetFontObject("ChatFontNormal")
  eb:SetWidth(330)
  eb:EnableMouse(true)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
  sf:SetScrollChild(eb)
  f.preview = eb

  local function Button(label, x, onClick)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(104, 22)
    b:SetPoint("BOTTOMLEFT", 14 + x, 14)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
  end
  f.accept = Button(L.UI_SHARE_IMPORT or "Import", 0, function()
    local names, kind = f.names or {}, f.kind
    if not DB then return end
    local imported = 0
    if kind == "GUILD" then
      for _, name in ipairs(names) do
        if not (DB.HasGuild and DB:HasGuild(name)) then
          DB:AddGuild(name, L.GUILD_KOS, nil, "Shared")
          imported = imported + 1
        end
      end
    elseif kind == "HONOR" then
      for _, name in ipairs(names) do
        if not (DB.LookupHonor and DB:LookupHonor(name)) then DB:AddHonor(name); imported = imported + 1 end
      end
    else
      for _, name in ipairs(names) do
        if not (DB.HasPlayer and DB:HasPlayer(name)) then DB:AddPlayer(name, L.KOS, nil, "Shared"); imported = imported + 1 end
      end
    end
    f:Hide()
    if _G.KillOnSight_GUI and _G.KillOnSight_GUI.RefreshAll then _G.KillOnSight_GUI:RefreshAll() end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00d0ff" .. L.ADDON_PREFIX .. ":|r " .. string.format(L.UI_SHARE_IMPORTED or "%d new entries imported.", imported))
  end)
  Button(L.UI_SHARE_CANCEL or "Cancel", 112, function() f:Hide() end)
  Share.importDialog = f
  return f
end

local function OpenImport(kind, names)
  local f = EnsureImportDialog()
  f.kind, f.names = kind, names
  if kind == "GUILD" then
    f.title:SetText(L.UI_SHARE_IMPORT_GUILD_TITLE or "Import Guild KoS?")
  elseif kind == "HONOR" then
    f.title:SetText(L.UI_SHARE_IMPORT_HONOR_TITLE or "Import Honor entry?")
  else
    f.title:SetText(L.UI_SHARE_IMPORT_KOS_TITLE or "Import KoS target?")
  end
  if kind == "GUILD" then
    f.message:SetText(L.UI_SHARE_REVIEW_GUILD or "Review this guild. Import adds it to your Guild KoS list.")
  elseif kind == "HONOR" then
    f.message:SetText(L.UI_SHARE_REVIEW_HONOR or "Review this name. Import adds it to your Honor list.")
  else
    f.message:SetText(L.UI_SHARE_REVIEW_KOS or "Review this name. Import adds it to your KoS list.")
  end
  f.preview:SetText(table.concat(names, "\n"))
  f.preview:SetCursorPosition(0)
  f:Show()
end

local function HyperlinkClick(_, link)
  local kind, payload = link:match("^addon:KillOnSight:share:([A-Z]+):(.*)$")
  if not kind or not SHARE_KINDS[kind] then return end
  local names = {}
  for name in payload:gmatch("([^;]+)") do names[#names + 1] = name end
  names = NormalizeNames(names)
  if #names == 1 then OpenImport(kind, names) end
end

local function SecureHyperlinkClick(link)
  HyperlinkClick(nil, link)
end

local function ChatShareFilter(_, _, message, author, ...)
  local kind, names = ParseShare(message)
  if not kind then return false end
  return false, MakeShareLink(kind, names), author, ...
end

function Share:Open(kind, names)
  names = NormalizeNames(names)
  if #names ~= 1 then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00d0ff" .. L.ADDON_PREFIX .. ":|r " .. (L.UI_SHARE_SELECT_ONE or "Select one entry to share."))
    return
  end
  local message = FormatMessage(kind, names)

  if not self.exportDialog then
    local f = CreateFrame("Frame", "KillOnSight_ShareExportDialog", UIParent, "BackdropTemplate")
    f:SetSize(430, 200)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    if f.SetBackdrop then f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=8,right=8,top=8,bottom=8}}) end
    f:Hide()
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -14)
    title:SetText(L.UI_SHARE_DIALOG_TITLE or "Share selected entry")
    local help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    help:SetWidth(390)
    help:SetJustifyH("LEFT")
    help:SetText(L.UI_SHARE_COPY_HINT or "Press Ctrl+C to copy this message, then paste it into chat and press Enter.")
    local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    box:SetPoint("TOPLEFT", 18, -72)
    box:SetSize(390, 24)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
    f.box = box
    local function Btn(label, x, width, cb)
      local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
      b:SetSize(width, 22)
      b:SetPoint("BOTTOMLEFT", 14 + x, 14)
      b:SetText(label)
      b:SetScript("OnClick", cb)
      return b
    end
    f.close = Btn(L.UI_CLOSE or "Close", 172, 70, function() f:Hide() end)
    self.exportDialog = f
  end
  local f = self.exportDialog
  f.box:SetText(message)
  f:Show()
  f.box:SetFocus()
  f.box:HighlightText()
end

function Share:Init()
  local addMessageEventFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
  if addMessageEventFilter then
    local events = {
      "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
      "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
      "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
      "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
      "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
      "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_COMMUNITIES_CHANNEL",
      "CHAT_MSG_CHANNEL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
      "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER",
    }
    for _, event in ipairs(events) do addMessageEventFilter(event, ChatShareFilter) end
  end
  if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("SetItemRef", HyperlinkClick, self)
  elseif hooksecurefunc then
    hooksecurefunc("SetItemRef", SecureHyperlinkClick)
  end
end

_G.KillOnSight_Share = Share
Share:Init()
return Share
