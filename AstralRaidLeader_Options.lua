-- AstralRaidLeader_Options.lua
-- Lightweight in-game settings window for AstralRaidLeader.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

local function Print(msg)
    print("|cff00ccff[AstralRaidLeader]|r " .. tostring(msg))
end

local function Normalize(name)
    if not name then return "" end
    return name:match("^%s*(.-)%s*$")
end

local function ShortName(name)
    return (name and (name:match("^([^%-]+)") or name) or "")
end

local function NamesMatch(a, b)
    local al = (a or ""):lower()
    local bl = (b or ""):lower()
    if al == bl then return true end
    return ShortName(al) == ShortName(bl)
end

local frame = CreateFrame(
    "Frame",
    "AstralRaidLeaderOptionsFrame",
    UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
frame:SetSize(760, 500)
frame:SetPoint("CENTER")
frame:SetClampedToScreen(true)
frame:SetFrameStrata("DIALOG")
frame:SetFrameLevel(100)
frame:SetToplevel(true)
frame:SetMovable(true)
frame:EnableMouse(false)
frame:SetAlpha(0)
frame:Hide()

frame:HookScript("OnShow", function(self)
    self:SetAlpha(1)
    self:EnableMouse(true)
end)

frame:HookScript("OnHide", function(self)
    self:SetAlpha(0)
    self:EnableMouse(false)
end)

if frame.SetBackdrop then
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.03, 0.05, 0.08, 0.985)
    frame:SetBackdropBorderColor(0.34, 0.42, 0.54, 0.96)
end

local header = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
header:SetPoint("TOPLEFT", 7, -7)
header:SetPoint("TOPRIGHT", -30, -7)
header:SetHeight(28)
header:SetFrameLevel(frame:GetFrameLevel() + 8)
if header.SetBackdrop then
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    header:SetBackdropColor(0.05, 0.09, 0.15, 0.88)
end

local headerDivider = header:CreateTexture(nil, "BORDER")
headerDivider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
headerDivider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
headerDivider:SetHeight(1)
headerDivider:SetColorTexture(0.44, 0.54, 0.68, 0.70)

local titleText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("CENTER", header, "CENTER", 0, 0)
titleText:SetText("AstralRaidLeader Settings")
titleText:SetTextColor(1.0, 0.96, 0.78)
titleText:SetShadowColor(0.0, 0.0, 0.0, 0.95)
titleText:SetShadowOffset(1, -1)
titleText:SetAlpha(1)

local topCloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
topCloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
topCloseButton:SetScript("OnClick", function() frame:Hide() end)

local dragRegion = CreateFrame("Frame", nil, frame)
dragRegion:SetPoint("TOPLEFT", 8, -6)
dragRegion:SetPoint("TOPRIGHT", -28, -6)
dragRegion:SetHeight(22)
dragRegion:EnableMouse(true)
dragRegion:RegisterForDrag("LeftButton")
dragRegion:SetScript("OnDragStart", function() frame:StartMoving() end)
dragRegion:SetScript("OnDragStop",  function() frame:StopMovingOrSizing() end)

table.insert(UISpecialFrames, frame:GetName())

local updating = false

local THEME = {
    goldActiveText = { 0.95, 0.81, 0.24 },
    mutedText = { 0.80, 0.82, 0.86 },
    tabIdleBG = { 0.11, 0.13, 0.17, 0.24 },
    tabActiveBG = { 0.16, 0.19, 0.25, 0.34 },
    hover = { 1.0, 1.0, 1.0, 0.04 },
    accent = { 0.86, 0.69, 0.22, 1.0 },
}

local SkinPanel = ARL.UI and ARL.UI.SkinPanel
local SkinActionButton = ARL.UI and ARL.UI.SkinActionButton
if not SkinPanel or not SkinActionButton then
    Print("UI helpers are unavailable; settings window is disabled.")
    return
end

local function SkinInputBox(edit)
    if not edit or edit._arlSkinned then return end

    local regions = { edit:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetAlpha(0)
        end
    end

    local skin = CreateFrame("Frame", nil, edit, BackdropTemplateMixin and "BackdropTemplate" or nil)
    skin:SetPoint("TOPLEFT", edit, "TOPLEFT", -2, 2)
    skin:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT", 2, -2)
    skin:SetFrameLevel(math.max(1, edit:GetFrameLevel() - 1))
    skin:EnableMouse(false)
    SkinPanel(skin, 0.05, 0.08, 0.12, 0.96, 0.32, 0.41, 0.53, 0.92)

    if edit.SetTextInsets then
        edit:SetTextInsets(8, 8, 4, 4)
    end

    edit._arlSkinned = true
end

local function StyleCheckbox(cb)
    if not cb or cb._arlStyled then return end

    local label = cb.Text or cb:GetFontString()
    if label and label.SetTextColor then
        label:SetTextColor(THEME.mutedText[1], THEME.mutedText[2], THEME.mutedText[3])
    end

    cb:HookScript("OnEnter", function(self)
        local text = self.Text or self:GetFontString()
        if text and text.SetTextColor then
            text:SetTextColor(0.92, 0.94, 0.98)
        end
    end)

    cb:HookScript("OnLeave", function(self)
        local text = self.Text or self:GetFontString()
        if text and text.SetTextColor then
            text:SetTextColor(THEME.mutedText[1], THEME.mutedText[2], THEME.mutedText[3])
        end
    end)

    cb._arlStyled = true
end

-- ============================================================
-- Tab panels
-- Each panel is a child of the main frame occupying the content
-- area below the title/tab bar, leaving room for the Close button.
-- ============================================================

local navContainer = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
navContainer:SetPoint("TOPLEFT", 8, -58)
navContainer:SetPoint("BOTTOMRIGHT", -8, 44)
SkinPanel(navContainer, 0.05, 0.08, 0.12, 0.86, 0.23, 0.30, 0.40, 0.42)

local navBG = navContainer:CreateTexture(nil, "BACKGROUND")
navBG:SetAllPoints()
navBG:SetColorTexture(0.03, 0.04, 0.06, 0.18)

local subTabSidebar = CreateFrame("Frame", nil, navContainer, BackdropTemplateMixin and "BackdropTemplate" or nil)
subTabSidebar:SetPoint("TOPLEFT", 8, -8)
subTabSidebar:SetPoint("BOTTOMLEFT", 8, 8)
subTabSidebar:SetWidth(165)
SkinPanel(subTabSidebar, 0.08, 0.11, 0.16, 0.72, 0.24, 0.31, 0.42, 0.40)

local sidebarBG = subTabSidebar:CreateTexture(nil, "BACKGROUND")
sidebarBG:SetAllPoints()
sidebarBG:SetColorTexture(0.06, 0.08, 0.12, 0.20)

local contentHost = CreateFrame("Frame", nil, navContainer)
contentHost:SetPoint("TOPLEFT", subTabSidebar, "TOPRIGHT", 10, 0)
contentHost:SetPoint("BOTTOMRIGHT", navContainer, "BOTTOMRIGHT", -8, 8)

local contentBG = contentHost:CreateTexture(nil, "BACKGROUND")
contentBG:SetAllPoints()
contentBG:SetColorTexture(0.05, 0.07, 0.10, 0.24)

local sidebarDivider = navContainer:CreateTexture(nil, "BORDER")
sidebarDivider:SetColorTexture(0.62, 0.69, 0.78, 0.08)
sidebarDivider:SetPoint("TOPLEFT", subTabSidebar, "TOPRIGHT", 4, -4)
sidebarDivider:SetPoint("BOTTOMLEFT", subTabSidebar, "BOTTOMRIGHT", 4, 4)
sidebarDivider:SetWidth(1)

local function CreatePanel()
    local p = CreateFrame("Frame", nil, contentHost)
    p:SetPoint("TOPLEFT", 4, -4)
    p:SetPoint("BOTTOMRIGHT", -4, 4)
    p:Hide()
    return p
end

local panels = {
    CreatePanel(),  -- 1: General
    CreatePanel(),  -- 2: Leaders
    CreatePanel(),  -- 3: Guild Ranks
    CreatePanel(),  -- 4: Consumables
    CreatePanel(),  -- 5: Deaths
}

-- ============================================================
-- Navigation buttons
-- ============================================================

local MAIN_TABS = {
    {
        label = "Auto Invite",
        subTabs = {
            { label = "General", panel = 1 },
            { label = "Leaders", panel = 2 },
            { label = "Guild Ranks", panel = 3 },
        },
    },
    {
        label = "Consumable Checks",
        subTabs = {
            { label = "Consumables", panel = 4 },
        },
    },
    {
        label = "Death Recaps",
        subTabs = {
            { label = "Death Recap", panel = 5 },
        },
    },
}

local mainTabs = {}
local subTabButtons = {}
local currentMainTabIndex = 0
local SelectMainTab

local function ShowOnlyPanel(panelIndex)
    for i, panel in ipairs(panels) do
        if i == panelIndex then panel:Show() else panel:Hide() end
    end
end

for i, tabConfig in ipairs(MAIN_TABS) do
    local tab = CreateFrame("Button", nil, frame)
    tab:SetSize(170, 24)
    if i == 1 then
        tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -34)
    else
        tab:SetPoint("LEFT", mainTabs[i - 1], "RIGHT", 6, 0)
    end
    tab:SetID(i)

    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(THEME.tabIdleBG[1], THEME.tabIdleBG[2], THEME.tabIdleBG[3], THEME.tabIdleBG[4])
    tab._bg = bg

    local hover = tab:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(THEME.hover[1], THEME.hover[2], THEME.hover[3], THEME.hover[4])

    local indicator = tab:CreateTexture(nil, "ARTWORK")
    indicator:SetPoint("BOTTOMLEFT", 1, 0)
    indicator:SetPoint("BOTTOMRIGHT", -1, 0)
    indicator:SetHeight(3)
    indicator:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], THEME.accent[4])
    indicator:Hide()
    tab._indicator = indicator

    local label = tab:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", 10, 0)
    label:SetPoint("RIGHT", -10, 0)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    label:SetText(tabConfig.label)
    tab.Label = label

    tab:SetScript("OnClick", function(self) SelectMainTab(self:GetID()) end)
    mainTabs[i] = tab
end

for i = 1, 6 do
    local btn = CreateFrame("Button", nil, subTabSidebar)
    btn:SetSize(145, 24)
    if i == 1 then
        btn:SetPoint("TOPLEFT", 10, -10)
    else
        btn:SetPoint("TOPLEFT", subTabButtons[i - 1], "BOTTOMLEFT", 0, -4)
    end
    btn:EnableMouse(true)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(THEME.tabIdleBG[1], THEME.tabIdleBG[2], THEME.tabIdleBG[3], THEME.tabIdleBG[4])
    btn._bg = bg

    local hover = btn:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(THEME.hover[1], THEME.hover[2], THEME.hover[3], THEME.hover[4])

    local indicator = btn:CreateTexture(nil, "ARTWORK")
    indicator:SetPoint("TOPLEFT", 0, -1)
    indicator:SetPoint("BOTTOMLEFT", 0, 1)
    indicator:SetWidth(3)
    indicator:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], THEME.accent[4])
    indicator:Hide()
    btn._indicator = indicator

    local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", 12, 0)
    label:SetPoint("RIGHT", -8, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    btn.Label = label

    btn:Hide()
    subTabButtons[i] = btn
end

local function SetTabLabelColor(tab, r, g, b)
    local label = tab.Text or tab.Label or tab:GetFontString()
    if label and label.SetTextColor then
        label:SetTextColor(r, g, b)
    end
end

local function SetMainTabVisual(selectedIndex)
    for i, tab in ipairs(mainTabs) do
        if i == selectedIndex then
            SetTabLabelColor(tab, THEME.goldActiveText[1], THEME.goldActiveText[2], THEME.goldActiveText[3])
            if tab._bg then
                tab._bg:SetColorTexture(
                    THEME.tabActiveBG[1], THEME.tabActiveBG[2], THEME.tabActiveBG[3], THEME.tabActiveBG[4]
                )
            end
            if tab._indicator then tab._indicator:Show() end
        else
            SetTabLabelColor(tab, THEME.mutedText[1], THEME.mutedText[2], THEME.mutedText[3])
            if tab._bg then
                tab._bg:SetColorTexture(THEME.tabIdleBG[1], THEME.tabIdleBG[2], THEME.tabIdleBG[3], THEME.tabIdleBG[4])
            end
            if tab._indicator then tab._indicator:Hide() end
        end
    end
end

local function SetSubTabVisual(selectedIndex)
    for i, tab in ipairs(subTabButtons) do
        if tab:IsShown() then
            if i == selectedIndex then
                SetTabLabelColor(tab, THEME.goldActiveText[1], THEME.goldActiveText[2], THEME.goldActiveText[3])
                if tab._bg then
                    tab._bg:SetColorTexture(
                        THEME.tabActiveBG[1], THEME.tabActiveBG[2], THEME.tabActiveBG[3], THEME.tabActiveBG[4]
                    )
                end
                if tab._indicator then tab._indicator:Show() end
            else
                SetTabLabelColor(tab, THEME.mutedText[1], THEME.mutedText[2], THEME.mutedText[3])
                if tab._bg then
                    tab._bg:SetColorTexture(
                        THEME.tabIdleBG[1], THEME.tabIdleBG[2], THEME.tabIdleBG[3], THEME.tabIdleBG[4]
                    )
                end
                if tab._indicator then tab._indicator:Hide() end
            end
        end
    end
end

local function SelectSubTab(index)
    local mainConfig = MAIN_TABS[currentMainTabIndex]
    if not mainConfig then return end
    local subConfig = mainConfig.subTabs[index]
    if not subConfig then return end

    SetSubTabVisual(index)
    ShowOnlyPanel(subConfig.panel)
end

local function BuildSubTabs(mainIndex)
    local mainConfig = MAIN_TABS[mainIndex]
    if not mainConfig then return end

    for i, btn in ipairs(subTabButtons) do
        local subConfig = mainConfig.subTabs[i]
        if subConfig then
            btn.Label:SetText(subConfig.label)
            btn:SetScript("OnClick", function() SelectSubTab(i) end)
            btn:Show()
        else
            btn.Label:SetText("")
            btn:Hide()
        end
    end
end

SelectMainTab = function(index)
    currentMainTabIndex = index
    SetMainTabVisual(index)

    BuildSubTabs(index)
    SelectSubTab(1)
end

-- ============================================================
-- Helper: create a checkbox parented to the given panel frame.
-- ============================================================

local function CreateCheckbox(parent, label, tooltip, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(label)
    if tooltip then cb.tooltipText = tooltip end
    return cb
end

-- ============================================================
-- Close button (always visible on the main frame)
-- ============================================================

local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
closeButton:SetPoint("BOTTOMRIGHT", -12, 12)
closeButton:SetSize(100, 24)
closeButton:SetText("Close")
closeButton:SetScript("OnClick", function() frame:Hide() end)

-- ============================================================
-- Tab 1 – General
-- ============================================================

local p1 = panels[1]

local autoCB = CreateCheckbox(p1,
    "Enable auto-promote",
    "Automatically promote the highest-priority preferred leader when available.",
    8, -8)

local reminderCB = CreateCheckbox(p1,
    "Enable reminder chat messages",
    "Show reminder messages when members join and no preferred leader is present.",
    8, -36)

local notifyCB = CreateCheckbox(p1,
    "Enable manual-promote popup",
    "Show a popup with a Promote button when auto-promote is disabled and a preferred leader is available.",
    8, -64)

local notifySoundCB = CreateCheckbox(p1,
    "Enable popup sound",
    "Play a sound when the manual-promote popup is shown.",
    8, -92)

local quietCB = CreateCheckbox(p1,
    "Enable quiet mode",
    "Suppress all chat output from AstralRaidLeader (auto-promote still works silently).",
    8, -120)

local reminderHelpText = p1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
reminderHelpText:SetPoint("TOPLEFT", 8, -160)
reminderHelpText:SetWidth(528)
reminderHelpText:SetJustifyH("LEFT")
reminderHelpText:SetText("Reminders are event-driven and trigger when party/raid roster changes.")

local groupTypeLabel = p1:CreateFontString(nil, "ARTWORK", "GameFontNormal")
groupTypeLabel:SetPoint("TOPLEFT", 8, -196)
groupTypeLabel:SetText("Auto-promote in:")

local groupAllCB = CreateCheckbox(p1,
    "All groups",
    "Auto-promote in both raids and parties.",
    8, -218)

local groupRaidCB = CreateFrame("CheckButton", nil, p1, "InterfaceOptionsCheckButtonTemplate")
groupRaidCB:SetPoint("TOPLEFT", p1, "TOPLEFT", 140, -218)
groupRaidCB.Text:SetText("Raids only")
groupRaidCB.tooltipText = "Only auto-promote when in a raid group."

local groupPartyCB = CreateFrame("CheckButton", nil, p1, "InterfaceOptionsCheckButtonTemplate")
groupPartyCB:SetPoint("TOPLEFT", p1, "TOPLEFT", 270, -218)
groupPartyCB.Text:SetText("Parties only")
groupPartyCB.tooltipText = "Only auto-promote when in a party (not a raid)."

-- ============================================================
-- Tab 2 – Leaders
-- ============================================================

local p2 = panels[2]

local preferredHeader = p2:CreateFontString(nil, "ARTWORK", "GameFontNormal")
preferredHeader:SetPoint("TOPLEFT", 8, -8)
preferredHeader:SetText("Preferred leaders (highest priority first)")

local listInset = CreateFrame("Frame", nil, p2, BackdropTemplateMixin and "BackdropTemplate" or nil)
listInset:SetPoint("TOPLEFT", 8, -28)
listInset:SetSize(528, 140)
SkinPanel(listInset, 0.07, 0.10, 0.14, 0.34, 0.22, 0.28, 0.36, 0.24)

local listText = listInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
listText:SetPoint("TOPLEFT", 8, -8)
listText:SetPoint("TOPRIGHT", -8, -8)
listText:SetJustifyH("LEFT")
listText:SetJustifyV("TOP")

local nameLabel = p2:CreateFontString(nil, "ARTWORK", "GameFontNormal")
nameLabel:SetPoint("TOPLEFT", 8, -178)
nameLabel:SetText("Character")

local nameEdit = CreateFrame("EditBox", nil, p2, "InputBoxTemplate")
nameEdit:SetPoint("TOPLEFT", 8, -198)
nameEdit:SetSize(180, 24)
nameEdit:SetAutoFocus(false)
nameEdit:SetMaxLetters(48)

local addButton = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
addButton:SetPoint("LEFT", nameEdit, "RIGHT", 10, 0)
addButton:SetSize(70, 24)
addButton:SetText("Add")

local removeButton = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
removeButton:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
removeButton:SetSize(90, 24)
removeButton:SetText("Remove")

local clearButton = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
clearButton:SetPoint("LEFT", removeButton, "RIGHT", 8, 0)
clearButton:SetSize(70, 24)
clearButton:SetText("Clear")

local promoteButton = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
promoteButton:SetPoint("LEFT", clearButton, "RIGHT", 8, 0)
promoteButton:SetSize(70, 24)
promoteButton:SetText("Promote")

local moveUpButton = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
moveUpButton:SetPoint("TOPLEFT", 8, -228)
moveUpButton:SetSize(90, 24)
moveUpButton:SetText("Move Up")

local moveDownButton = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
moveDownButton:SetPoint("LEFT", moveUpButton, "RIGHT", 8, 0)
moveDownButton:SetSize(100, 24)
moveDownButton:SetText("Move Down")

-- ============================================================
-- Tab 3 – Guild Ranks
-- ============================================================

local p3 = panels[3]

local useGuildRankCB = CreateCheckbox(p3,
    "Enable guild rank priority (fallback when no preferred leader is in group)",
    "When no character from the preferred leaders list is present, promote the "
    .. "highest-priority guild rank member instead.",
    8, -8)

local guildRankListLabel = p3:CreateFontString(nil, "ARTWORK", "GameFontNormal")
guildRankListLabel:SetPoint("TOPLEFT", 8, -44)
guildRankListLabel:SetText("Guild rank priority (highest priority first)")

local guildRankListInset = CreateFrame("Frame", nil, p3, BackdropTemplateMixin and "BackdropTemplate" or nil)
guildRankListInset:SetPoint("TOPLEFT", 8, -64)
guildRankListInset:SetSize(528, 96)
SkinPanel(guildRankListInset, 0.07, 0.10, 0.14, 0.34, 0.22, 0.28, 0.36, 0.24)

local guildRankListText = guildRankListInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
guildRankListText:SetPoint("TOPLEFT", 8, -8)
guildRankListText:SetPoint("TOPRIGHT", -8, -8)
guildRankListText:SetJustifyH("LEFT")
guildRankListText:SetJustifyV("TOP")

local rankNameLabel = p3:CreateFontString(nil, "ARTWORK", "GameFontNormal")
rankNameLabel:SetPoint("TOPLEFT", 8, -170)
rankNameLabel:SetText("Guild Rank")

local rankNameEdit = CreateFrame("EditBox", nil, p3, "InputBoxTemplate")
rankNameEdit:SetPoint("TOPLEFT", 8, -190)
rankNameEdit:SetSize(180, 24)
rankNameEdit:SetAutoFocus(false)
rankNameEdit:SetMaxLetters(48)

local addRankButton = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
addRankButton:SetPoint("LEFT", rankNameEdit, "RIGHT", 10, 0)
addRankButton:SetSize(70, 24)
addRankButton:SetText("Add")

local removeRankButton = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
removeRankButton:SetPoint("LEFT", addRankButton, "RIGHT", 8, 0)
removeRankButton:SetSize(90, 24)
removeRankButton:SetText("Remove")

local clearRanksButton = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
clearRanksButton:SetPoint("LEFT", removeRankButton, "RIGHT", 8, 0)
clearRanksButton:SetSize(70, 24)
clearRanksButton:SetText("Clear")

local moveRankUpButton = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
moveRankUpButton:SetPoint("TOPLEFT", 8, -220)
moveRankUpButton:SetSize(90, 24)
moveRankUpButton:SetText("Move Up")

local moveRankDownButton = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
moveRankDownButton:SetPoint("LEFT", moveRankUpButton, "RIGHT", 8, 0)
moveRankDownButton:SetSize(100, 24)
moveRankDownButton:SetText("Move Down")

local guildRankPickerLabel = p3:CreateFontString(nil, "ARTWORK", "GameFontNormal")
guildRankPickerLabel:SetPoint("TOPLEFT", 8, -252)
guildRankPickerLabel:SetText("Available ranks in your guild (click to add):")

local refreshGuildRanksButton = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
refreshGuildRanksButton:SetPoint("LEFT", guildRankPickerLabel, "RIGHT", 10, 0)
refreshGuildRanksButton:SetSize(80, 22)
refreshGuildRanksButton:SetText("Refresh")

-- Pool of up to 10 clickable rank buttons (2 columns x 5 rows)
local MAX_RANK_BUTTONS = 10
local guildRankButtons = {}
for _i = 1, MAX_RANK_BUTTONS do
    local col = (_i - 1) % 2
    local row = math.floor((_i - 1) / 2)
    local btn = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", 8 + col * 266, -270 + row * -22)
    btn:SetSize(257, 20)
    btn:SetText("")
    btn:Hide()
    guildRankButtons[_i] = btn
end

local noGuildRanksText = p3:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
noGuildRanksText:SetPoint("TOPLEFT", 8, -274)
noGuildRanksText:SetText("")
noGuildRanksText:Hide()

-- ============================================================
-- Tab 4 – Consumables
-- ============================================================

local p4 = panels[4]

local consumableAuditCB = CreateCheckbox(p4,
    "Enable consumable audit on ready check",
    "When a ready check is initiated, report which group members are missing tracked consumable buffs.",
    8, -8)

local consumableListLabel = p4:CreateFontString(nil, "ARTWORK", "GameFontNormal")
consumableListLabel:SetPoint("TOPLEFT", 8, -44)
consumableListLabel:SetText("Tracked consumable categories")

local consumableListInset = CreateFrame("Frame", nil, p4, BackdropTemplateMixin and "BackdropTemplate" or nil)
consumableListInset:SetPoint("TOPLEFT", 8, -64)
consumableListInset:SetSize(528, 140)
SkinPanel(consumableListInset, 0.07, 0.10, 0.14, 0.34, 0.22, 0.28, 0.36, 0.24)

local consumableListText = consumableListInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
consumableListText:SetPoint("TOPLEFT", 8, -8)
consumableListText:SetPoint("TOPRIGHT", -8, -8)
consumableListText:SetJustifyH("LEFT")
consumableListText:SetJustifyV("TOP")

local catLabelTitle = p4:CreateFontString(nil, "ARTWORK", "GameFontNormal")
catLabelTitle:SetPoint("TOPLEFT", 8, -214)
catLabelTitle:SetText("Category")

local spellIdTitle = p4:CreateFontString(nil, "ARTWORK", "GameFontNormal")
spellIdTitle:SetPoint("TOPLEFT", 270, -214)
spellIdTitle:SetText("Spell ID")

local catEdit = CreateFrame("EditBox", nil, p4, "InputBoxTemplate")
catEdit:SetPoint("TOPLEFT", 8, -234)
catEdit:SetSize(250, 24)
catEdit:SetAutoFocus(false)
catEdit:SetMaxLetters(64)

local spellIdEdit = CreateFrame("EditBox", nil, p4, "InputBoxTemplate")
spellIdEdit:SetPoint("TOPLEFT", 270, -234)
spellIdEdit:SetSize(90, 24)
spellIdEdit:SetAutoFocus(false)
spellIdEdit:SetMaxLetters(12)

local addConsumableButton = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
addConsumableButton:SetPoint("TOPLEFT", 8, -266)
addConsumableButton:SetSize(160, 24)
addConsumableButton:SetText("Add Spell ID")

local removeSpellIdButton = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
removeSpellIdButton:SetPoint("LEFT", addConsumableButton, "RIGHT", 10, 0)
removeSpellIdButton:SetSize(160, 24)
removeSpellIdButton:SetText("Remove Spell ID")

local deleteCatButton = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
deleteCatButton:SetPoint("LEFT", removeSpellIdButton, "RIGHT", 10, 0)
deleteCatButton:SetSize(160, 24)
deleteCatButton:SetText("Delete Category")

local clearConsumablesButton = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
clearConsumablesButton:SetPoint("TOPLEFT", 8, -298)
clearConsumablesButton:SetSize(160, 24)
clearConsumablesButton:SetText("Clear All")

local runAuditButton = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
runAuditButton:SetPoint("LEFT", clearConsumablesButton, "RIGHT", 10, 0)
runAuditButton:SetSize(160, 24)
runAuditButton:SetText("Run Audit Now")

-- ============================================================
-- Tab 5 - Deaths
-- ============================================================

local p5 = panels[5]

local deathTrackingCB = CreateCheckbox(p5,
    "Enable death tracking during encounters",
    "Record raid and party deaths during encounter attempts.",
    8, -8)

local showRecapCB = CreateCheckbox(p5,
    "Open recap window automatically on wipe",
    "Show the Death Recap window automatically when an encounter ends in a wipe.",
    8, -36)

local showRecapOnAnyEndCB = CreateCheckbox(p5,
    "Open recap window on encounter kill",
    "Also open the Death Recap when the encounter ends successfully.",
    8, -64)

local recapInfoText = p5:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
recapInfoText:SetPoint("TOPLEFT", 8, -96)
recapInfoText:SetWidth(520)
recapInfoText:SetJustifyH("LEFT")
recapInfoText:SetText("Use /arl deaths to open the recap at any time.")

local openRecapButton = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
openRecapButton:SetPoint("TOPLEFT", 8, -126)
openRecapButton:SetSize(140, 24)
openRecapButton:SetText("Open Last Recap")

for _, cb in ipairs({
    autoCB, reminderCB, notifyCB, notifySoundCB, quietCB,
    groupAllCB, groupRaidCB, groupPartyCB,
    useGuildRankCB, consumableAuditCB,
    deathTrackingCB, showRecapCB, showRecapOnAnyEndCB,
}) do
    StyleCheckbox(cb)
end

for _, edit in ipairs({ nameEdit, rankNameEdit, catEdit, spellIdEdit }) do
    SkinInputBox(edit)
end

for _, btn in ipairs({
    closeButton,
    addButton, removeButton, clearButton, promoteButton, moveUpButton, moveDownButton,
    addRankButton, removeRankButton, clearRanksButton, moveRankUpButton, moveRankDownButton, refreshGuildRanksButton,
    addConsumableButton, removeSpellIdButton, deleteCatButton, clearConsumablesButton, runAuditButton,
    openRecapButton,
}) do
    SkinActionButton(btn)
end

for _, btn in ipairs(guildRankButtons) do
    SkinActionButton(btn)
end

-- ============================================================
-- Refresh helpers
-- ============================================================

local function RefreshListText()
    if not ARL.db then
        listText:SetText("Waiting for saved variables to load...")
        return
    end
    if #ARL.db.preferredLeaders == 0 then
        listText:SetText("No preferred leaders configured. Add one below.")
        return
    end
    local lines = {}
    for i, name in ipairs(ARL.db.preferredLeaders) do
        lines[#lines + 1] = string.format("%d. %s", i, name)
    end
    listText:SetText(table.concat(lines, "\n"))
end

local function RefreshRankListText()
    if not ARL.db then
        guildRankListText:SetText("Waiting for saved variables to load...")
        return
    end
    if #ARL.db.guildRankPriority == 0 then
        guildRankListText:SetText("No guild ranks configured. Add a rank name below.")
        return
    end
    local lines = {}
    for i, entry in ipairs(ARL.db.guildRankPriority) do
        local name = type(entry) == "table" and entry.name or tostring(entry)
        lines[#lines + 1] = string.format("%d. %s", i, name)
    end
    guildRankListText:SetText(table.concat(lines, "\n"))
end

local function RefreshGuildRankButtons()
    for _, btn in ipairs(guildRankButtons) do btn:Hide() end
    noGuildRanksText:Hide()
    if not IsInGuild() then
        noGuildRanksText:SetText("Not in a guild.")
        noGuildRanksText:Show()
        return
    end
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
    local numRanks = GuildControlGetNumRanks()
    if numRanks == 0 then
        noGuildRanksText:SetText("Guild data not yet loaded. Click Refresh.")
        noGuildRanksText:Show()
        return
    end
    for i = 1, math.min(numRanks, MAX_RANK_BUTTONS) do
        local rankName = GuildControlGetRankName(i)
        if rankName and rankName ~= "" then
            guildRankButtons[i]:SetText(rankName)
            guildRankButtons[i]._rankIndex = i
            guildRankButtons[i]:Show()
        end
    end
end

local function RefreshConsumableListText()
    if not ARL.db then
        consumableListText:SetText("Waiting for saved variables to load...")
        return
    end
    local lines = {}
    local sys = ARL.SYSTEM_CONSUMABLES or {}
    lines[#lines + 1] = "|cffffff00System (built-in):|r"
    if #sys > 0 then
        for _, cat in ipairs(sys) do
            local parts = {}
            if #cat.spellIds > 0 then
                parts[#parts + 1] = "IDs: " .. table.concat(cat.spellIds, ", ")
            end
            if cat.namePatterns and #cat.namePatterns > 0 then
                parts[#parts + 1] = 'names: "' .. table.concat(cat.namePatterns, '", "') .. '"'
            end
            lines[#lines + 1] = string.format("  %s - %s",
                cat.label, #parts > 0 and table.concat(parts, "; ") or "(empty)")
        end
    else
        lines[#lines + 1] = "  (none)"
    end
    lines[#lines + 1] = "|cffffff00Custom:|r"
    if #ARL.db.trackedConsumables > 0 then
        for i, cat in ipairs(ARL.db.trackedConsumables) do
            local parts = {}
            if #cat.spellIds > 0 then
                parts[#parts + 1] = "IDs: " .. table.concat(cat.spellIds, ", ")
            end
            if cat.namePatterns and #cat.namePatterns > 0 then
                parts[#parts + 1] = 'names: "' .. table.concat(cat.namePatterns, '", "') .. '"'
            end
            lines[#lines + 1] = string.format("  %d. %s - %s",
                i, cat.label, #parts > 0 and table.concat(parts, "; ") or "(empty)")
        end
    else
        lines[#lines + 1] = "  No custom categories. Add one below."
    end
    consumableListText:SetText(table.concat(lines, "\n"))
end

local function RefreshUI()
    if not ARL.db then return end

    updating = true

    autoCB:SetChecked(ARL.db.autoPromote)
    reminderCB:SetChecked(ARL.db.reminderEnabled)
    notifyCB:SetChecked(ARL.db.notifyEnabled)
    notifySoundCB:SetChecked(ARL.db.notifySound)
    quietCB:SetChecked(ARL.db.quietMode)

    local filter = ARL.db.groupTypeFilter or "all"
    groupAllCB:SetChecked(filter == "all")
    groupRaidCB:SetChecked(filter == "raid")
    groupPartyCB:SetChecked(filter == "party")

    useGuildRankCB:SetChecked(ARL.db.useGuildRankPriority)
    consumableAuditCB:SetChecked(ARL.db.consumableAuditEnabled)
    deathTrackingCB:SetChecked(ARL.db.deathTrackingEnabled)
    showRecapCB:SetChecked(ARL.db.showRecapOnWipe)
    showRecapOnAnyEndCB:SetChecked(ARL.db.showRecapOnEncounterEnd)

    RefreshListText()
    RefreshRankListText()
    RefreshConsumableListText()
    RefreshGuildRankButtons()

    updating = false
end

-- ============================================================
-- Tab 1 – General: handlers
-- ============================================================

autoCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.autoPromote = self:GetChecked() and true or false
    Print(string.format("Auto-promote |cff%s%s|r.",
        ARL.db.autoPromote and "00ff00" or "ff0000",
        ARL.db.autoPromote and "enabled" or "disabled"))
end)

reminderCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.reminderEnabled = self:GetChecked() and true or false
    if not ARL.db.reminderEnabled and ARL.CancelReminder then ARL:CancelReminder() end
    Print(string.format("Reminder |cff%s%s|r.",
        ARL.db.reminderEnabled and "00ff00" or "ff0000",
        ARL.db.reminderEnabled and "enabled" or "disabled"))
end)

notifyCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.notifyEnabled = self:GetChecked() and true or false
    if not ARL.db.notifyEnabled and ARL.HideManualPromotePopup then ARL:HideManualPromotePopup() end
    Print(string.format("Manual-promote popup |cff%s%s|r.",
        ARL.db.notifyEnabled and "00ff00" or "ff0000",
        ARL.db.notifyEnabled and "enabled" or "disabled"))
end)

notifySoundCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.notifySound = self:GetChecked() and true or false
    Print(string.format("Manual-promote popup sound |cff%s%s|r.",
        ARL.db.notifySound and "00ff00" or "ff0000",
        ARL.db.notifySound and "enabled" or "disabled"))
end)

quietCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.quietMode = self:GetChecked() and true or false
    if ARL.db.quietMode then
        Print("Quiet mode |cff00ff00enabled|r. Chat output suppressed.")
    else
        Print("Quiet mode |cffff0000disabled|r.")
    end
end)

local function SetGroupTypeFilter(filter)
    if not ARL.db then return end
    ARL.db.groupTypeFilter = filter
    groupAllCB:SetChecked(filter == "all")
    groupRaidCB:SetChecked(filter == "raid")
    groupPartyCB:SetChecked(filter == "party")
    local labels = { all = "all groups", raid = "raids only", party = "parties only" }
    Print(string.format("Group type filter set to |cffffff00%s|r.", labels[filter]))
end

groupAllCB:SetScript("OnClick",  function() if not updating then SetGroupTypeFilter("all")   end end)
groupRaidCB:SetScript("OnClick", function() if not updating then SetGroupTypeFilter("raid")  end end)
groupPartyCB:SetScript("OnClick",function() if not updating then SetGroupTypeFilter("party") end end)

-- ============================================================
-- Tab 2 – Leaders: handlers
-- ============================================================

addButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local name = Normalize(nameEdit:GetText())
    if name == "" then return end
    for _, existing in ipairs(ARL.db.preferredLeaders) do
        if NamesMatch(existing, name) then
            Print(string.format("|cffffd100%s|r is already in the preferred leaders list.", name))
            return
        end
    end
    table.insert(ARL.db.preferredLeaders, name)
    nameEdit:SetText("")
    RefreshListText()
    Print(string.format("Added |cffffd100%s|r to the preferred leaders list.", name))
end)

removeButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local name = Normalize(nameEdit:GetText())
    if name == "" then Print("Enter a character name to remove.") return end
    for i, existing in ipairs(ARL.db.preferredLeaders) do
        if NamesMatch(existing, name) then
            table.remove(ARL.db.preferredLeaders, i)
            nameEdit:SetText("")
            RefreshListText()
            Print(string.format("Removed |cffffd100%s|r from the preferred leaders list.", existing))
            return
        end
    end
    Print(string.format("|cffffd100%s|r was not found in the preferred leaders list.", name))
end)

clearButton:SetScript("OnClick", function()
    if not ARL.db then return end
    ARL.db.preferredLeaders = {}
    if ARL.CancelReminder then ARL:CancelReminder() end
    if ARL.HideManualPromotePopup then ARL:HideManualPromotePopup() end
    RefreshListText()
    Print("Cleared the preferred leaders list.")
end)

promoteButton:SetScript("OnClick", function()
    if SlashCmdList and SlashCmdList["ASTRALRAIDLEADER"] then
        SlashCmdList["ASTRALRAIDLEADER"]("promote")
    end
end)

moveUpButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local name = Normalize(nameEdit:GetText())
    if name == "" then Print("Enter a character name to move.") return end
    local foundAt = nil
    for i, n in ipairs(ARL.db.preferredLeaders) do
        if NamesMatch(n, name) then foundAt = i break end
    end
    if not foundAt then
        Print(string.format("|cffffd100%s|r was not found in the preferred leaders list.", name))
        return
    end
    if foundAt == 1 then
        Print(string.format("|cffffd100%s|r is already at the top of the list.", ARL.db.preferredLeaders[foundAt]))
        return
    end
    local entry = table.remove(ARL.db.preferredLeaders, foundAt)
    table.insert(ARL.db.preferredLeaders, foundAt - 1, entry)
    RefreshListText()
    Print(string.format("Moved |cffffd100%s|r to position %d.", entry, foundAt - 1))
end)

moveDownButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local name = Normalize(nameEdit:GetText())
    if name == "" then Print("Enter a character name to move.") return end
    local foundAt = nil
    for i, n in ipairs(ARL.db.preferredLeaders) do
        if NamesMatch(n, name) then foundAt = i break end
    end
    if not foundAt then
        Print(string.format("|cffffd100%s|r was not found in the preferred leaders list.", name))
        return
    end
    if foundAt == #ARL.db.preferredLeaders then
        Print(string.format("|cffffd100%s|r is already at the bottom of the list.", ARL.db.preferredLeaders[foundAt]))
        return
    end
    local entry = table.remove(ARL.db.preferredLeaders, foundAt)
    table.insert(ARL.db.preferredLeaders, foundAt + 1, entry)
    RefreshListText()
    Print(string.format("Moved |cffffd100%s|r to position %d.", entry, foundAt + 1))
end)

nameEdit:SetScript("OnEnterPressed", function() addButton:Click() end)

-- ============================================================
-- Tab 3 – Guild Ranks: handlers
-- ============================================================

useGuildRankCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.useGuildRankPriority = self:GetChecked() and true or false
    Print(string.format("Guild rank priority |cff%s%s|r.",
        ARL.db.useGuildRankPriority and "00ff00" or "ff0000",
        ARL.db.useGuildRankPriority and "enabled" or "disabled"))
end)

addRankButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local rank = Normalize(rankNameEdit:GetText())
    if rank == "" then return end
    -- Resolve rank index for unambiguous storage when duplicate rank names exist.
    local rankIndex = 0
    if IsInGuild() then
        local numRanks = GuildControlGetNumRanks()
        for ri = 1, numRanks do
            if (GuildControlGetRankName(ri) or ""):lower() == rank:lower() then
                rankIndex = ri
                break
            end
        end
    end
    for _, existing in ipairs(ARL.db.guildRankPriority) do
        local existingName  = type(existing) == "table" and existing.name  or tostring(existing)
        local existingIndex = type(existing) == "table" and (existing.rankIndex or 0) or 0
        local isDup = (rankIndex > 0 and existingIndex == rankIndex)
                   or (rankIndex == 0 and existingName:lower() == rank:lower())
        if isDup then
            Print(string.format("|cffffd100%s|r is already in the guild rank priority list.", rank))
            return
        end
    end
    table.insert(ARL.db.guildRankPriority, { name = rank, rankIndex = rankIndex })
    rankNameEdit:SetText("")
    RefreshRankListText()
    Print(string.format("Added |cffffd100%s|r to the guild rank priority list.", rank))
end)

removeRankButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local rank = Normalize(rankNameEdit:GetText())
    if rank == "" then Print("Enter a guild rank name to remove.") return end
    for i, existing in ipairs(ARL.db.guildRankPriority) do
        local existingName = type(existing) == "table" and existing.name or tostring(existing)
        if existingName:lower() == rank:lower() then
            table.remove(ARL.db.guildRankPriority, i)
            rankNameEdit:SetText("")
            RefreshRankListText()
            Print(string.format("Removed |cffffd100%s|r from the guild rank priority list.", existingName))
            return
        end
    end
    Print(string.format("|cffffd100%s|r was not found in the guild rank priority list.", rank))
end)

clearRanksButton:SetScript("OnClick", function()
    if not ARL.db then return end
    ARL.db.guildRankPriority = {}
    RefreshRankListText()
    Print("Cleared the guild rank priority list.")
end)

moveRankUpButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local rank = Normalize(rankNameEdit:GetText())
    if rank == "" then Print("Enter a guild rank name to move.") return end
    local foundAt = nil
    for i, r in ipairs(ARL.db.guildRankPriority) do
        local rName = type(r) == "table" and r.name or tostring(r)
        if rName:lower() == rank:lower() then foundAt = i break end
    end
    if not foundAt then
        Print(string.format("|cffffd100%s|r was not found in the guild rank priority list.", rank))
        return
    end
    if foundAt == 1 then
        local topEntry = ARL.db.guildRankPriority[foundAt]
        local topName = type(topEntry) == "table" and topEntry.name or tostring(topEntry)
        Print(string.format("|cffffd100%s|r is already at the top of the list.", topName))
        return
    end
    local entry = table.remove(ARL.db.guildRankPriority, foundAt)
    local entryName = type(entry) == "table" and entry.name or tostring(entry)
    table.insert(ARL.db.guildRankPriority, foundAt - 1, entry)
    RefreshRankListText()
    Print(string.format("Moved |cffffd100%s|r to position %d.", entryName, foundAt - 1))
end)

moveRankDownButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local rank = Normalize(rankNameEdit:GetText())
    if rank == "" then Print("Enter a guild rank name to move.") return end
    local foundAt = nil
    for i, r in ipairs(ARL.db.guildRankPriority) do
        local rName = type(r) == "table" and r.name or tostring(r)
        if rName:lower() == rank:lower() then foundAt = i break end
    end
    if not foundAt then
        Print(string.format("|cffffd100%s|r was not found in the guild rank priority list.", rank))
        return
    end
    if foundAt == #ARL.db.guildRankPriority then
        local bottomEntry = ARL.db.guildRankPriority[foundAt]
        local botName = type(bottomEntry) == "table" and bottomEntry.name or tostring(bottomEntry)
        Print(string.format("|cffffd100%s|r is already at the bottom of the list.", botName))
        return
    end
    local entry = table.remove(ARL.db.guildRankPriority, foundAt)
    local entryName = type(entry) == "table" and entry.name or tostring(entry)
    table.insert(ARL.db.guildRankPriority, foundAt + 1, entry)
    RefreshRankListText()
    Print(string.format("Moved |cffffd100%s|r to position %d.", entryName, foundAt + 1))
end)

rankNameEdit:SetScript("OnEnterPressed", function() addRankButton:Click() end)

refreshGuildRanksButton:SetScript("OnClick", function()
    RefreshGuildRankButtons()
end)

for _, btn in ipairs(guildRankButtons) do
    btn:SetScript("OnClick", function(self)
        if not ARL.db then return end
        local rank = self:GetText()
        local rankIndex = self._rankIndex or 0
        if rank == "" then return end
        for _, existing in ipairs(ARL.db.guildRankPriority) do
            local existingName  = type(existing) == "table" and existing.name  or tostring(existing)
            local existingIndex = type(existing) == "table" and (existing.rankIndex or 0) or 0
            local isDup = (rankIndex > 0 and existingIndex == rankIndex)
                       or (rankIndex == 0 and existingName:lower() == rank:lower())
            if isDup then
                Print(string.format("|cffffd100%s|r is already in the guild rank priority list.", rank))
                return
            end
        end
        table.insert(ARL.db.guildRankPriority, { name = rank, rankIndex = rankIndex })
        RefreshRankListText()
        Print(string.format("Added |cffffd100%s|r to the guild rank priority list.", rank))
    end)
end

-- ============================================================
-- Tab 4 – Consumables: handlers
-- ============================================================

consumableAuditCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.consumableAuditEnabled = self:GetChecked() and true or false
    Print(string.format("Consumable audit on ready check |cff%s%s|r.",
        ARL.db.consumableAuditEnabled and "00ff00" or "ff0000",
        ARL.db.consumableAuditEnabled and "enabled" or "disabled"))
end)

local FindConsumableCategory = ARL.FindConsumableCategory

addConsumableButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local label   = Normalize(catEdit:GetText())
    local spellId = tonumber(spellIdEdit:GetText())
    if label == "" then Print("Enter a category name.") return end
    if not spellId or spellId < 1 then Print("Enter a valid spell ID.") return end
    local _, cat, isSystem = FindConsumableCategory(label)
    if isSystem then
        Print(string.format("|cffffd100%s|r is a built-in category and cannot be modified.", label))
        return
    end
    if cat then
        for _, id in ipairs(cat.spellIds) do
            if id == spellId then
                Print(string.format("Spell ID %d is already in |cffffd100%s|r.", spellId, cat.label))
                return
            end
        end
        table.insert(cat.spellIds, spellId)
        Print(string.format("Added spell ID %d to |cffffd100%s|r.", spellId, cat.label))
    else
        table.insert(ARL.db.trackedConsumables, { label = label, spellIds = { spellId } })
        Print(string.format("Created category |cffffd100%s|r with spell ID %d.", label, spellId))
    end
    spellIdEdit:SetText("")
    RefreshConsumableListText()
end)

removeSpellIdButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local label   = Normalize(catEdit:GetText())
    local spellId = tonumber(spellIdEdit:GetText())
    if label == "" then Print("Enter a category name.") return end
    if not spellId or spellId < 1 then Print("Enter a valid spell ID.") return end
    local idx, cat, isSystem = FindConsumableCategory(label)
    if not cat then Print(string.format("Category |cffffd100%s|r not found.", label)) return end
    if isSystem then
        Print(string.format("|cffffd100%s|r is a built-in category and cannot be modified.", label))
        return
    end
    for i, id in ipairs(cat.spellIds) do
        if id == spellId then
            table.remove(cat.spellIds, i)
            Print(string.format("Removed spell ID %d from |cffffd100%s|r.", spellId, cat.label))
            if #cat.spellIds == 0 then
                table.remove(ARL.db.trackedConsumables, idx)
                Print(string.format("Category |cffffd100%s|r deleted (no spell IDs remaining).", cat.label))
            end
            spellIdEdit:SetText("")
            RefreshConsumableListText()
            return
        end
    end
    Print(string.format("Spell ID %d was not found in |cffffd100%s|r.", spellId, cat.label))
end)

deleteCatButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local label = Normalize(catEdit:GetText())
    if label == "" then Print("Enter a category name to delete.") return end
    local idx, cat, isSystem = FindConsumableCategory(label)
    if not cat then Print(string.format("Category |cffffd100%s|r not found.", label)) return end
    if isSystem then
        Print(string.format("|cffffd100%s|r is a built-in category and cannot be deleted.", label))
        return
    end
    table.remove(ARL.db.trackedConsumables, idx)
    catEdit:SetText("")
    RefreshConsumableListText()
    Print(string.format("Deleted category |cffffd100%s|r.", cat.label))
end)

clearConsumablesButton:SetScript("OnClick", function()
    if not ARL.db then return end
    ARL.db.trackedConsumables = {}
    RefreshConsumableListText()
    Print("Cleared all custom consumable categories.")
end)

runAuditButton:SetScript("OnClick", function()
    if ARL.RunConsumableAudit then ARL.RunConsumableAudit(true) end
end)

catEdit:SetScript("OnEnterPressed",    function() spellIdEdit:SetFocus() end)
spellIdEdit:SetScript("OnEnterPressed", function() addConsumableButton:Click() end)

-- ============================================================
-- Tab 5 - Deaths: handlers
-- ============================================================

deathTrackingCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.deathTrackingEnabled = self:GetChecked() and true or false
    Print(string.format("Death tracking |cff%s%s|r.",
        ARL.db.deathTrackingEnabled and "00ff00" or "ff0000",
        ARL.db.deathTrackingEnabled and "enabled" or "disabled"))
end)

showRecapCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.showRecapOnWipe = self:GetChecked() and true or false
    Print(string.format("Auto-open death recap on wipe |cff%s%s|r.",
        ARL.db.showRecapOnWipe and "00ff00" or "ff0000",
        ARL.db.showRecapOnWipe and "enabled" or "disabled"))
end)

    showRecapOnAnyEndCB:SetScript("OnClick", function(self)
        if updating or not ARL.db then return end
        ARL.db.showRecapOnEncounterEnd = self:GetChecked() and true or false
        Print(string.format("Auto-open death recap on encounter kill |cff%s%s|r.",
        ARL.db.showRecapOnEncounterEnd and "00ff00" or "ff0000",
        ARL.db.showRecapOnEncounterEnd and "enabled" or "disabled"))
    end)

openRecapButton:SetScript("OnClick", function()
    if ARL.ShowDeathRecap then
        ARL:ShowDeathRecap()
    else
        Print("Death recap UI is not available yet. Try again in a moment.")
    end
end)

-- ============================================================
-- ShowOptions
-- ============================================================

function ARL:ShowOptions()
    if not self.db then
        Print("Not fully loaded yet. Please wait a moment.")
        return
    end
    RefreshUI()
    frame:Show()
    frame:Raise()
    if currentMainTabIndex == 0 then
        SelectMainTab(1)
    else
        SelectMainTab(currentMainTabIndex)
    end
end
