-- AstralRaidLeader_Options.lua
-- Lightweight in-game settings window for AstralRaidLeader.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

local ChatFontNormal = _G.ChatFontNormal
local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local ToggleDropDownMenu = _G.ToggleDropDownMenu

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
frame:SetSize(860, 700)
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
subTabSidebar:SetWidth(172)
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
    CreatePanel(),  -- 6: Raid Groups Layouts
    CreatePanel(),  -- 7: Raid Groups Import
    CreatePanel(),  -- 8: Raid Groups Settings
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
    {
        label = "Raid Groups",
        subTabs = {
            { label = "Layouts", panel = 6 },
            { label = "Import", panel = 7 },
            { label = "Settings", panel = 8 },
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

local function AttachButtonTooltip(btn, title, body)
    local GameTooltip = _G.GameTooltip
    if not btn or not GameTooltip then
        return
    end

    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title and title ~= "" then
            GameTooltip:AddLine(title, 1.0, 0.96, 0.78)
        end
        if body and body ~= "" then
            GameTooltip:AddLine(body, 0.90, 0.92, 0.96, true)
        end
        GameTooltip:Show()
    end)

    btn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
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

local groupRaidCB = CreateFrame("CheckButton", nil, p1, "InterfaceOptionsCheckButtonTemplate")
groupRaidCB:SetPoint("TOPLEFT", p1, "TOPLEFT", 8, -218)
groupRaidCB.Text:SetText("Raids")
groupRaidCB.tooltipText = "Auto-promote when in any raid group."

local groupPartyCB = CreateFrame("CheckButton", nil, p1, "InterfaceOptionsCheckButtonTemplate")
groupPartyCB:SetPoint("TOPLEFT", p1, "TOPLEFT", 175, -218)
groupPartyCB.Text:SetText("Parties")
groupPartyCB.tooltipText = "Auto-promote when in a party (not a raid)."

local groupGuildRaidCB = CreateFrame("CheckButton", nil, p1, "InterfaceOptionsCheckButtonTemplate")
groupGuildRaidCB:SetPoint("TOPLEFT", p1, "TOPLEFT", 8, -246)
groupGuildRaidCB.Text:SetText("Guild Raids")
groupGuildRaidCB.tooltipText = "Auto-promote in raids that Blizzard marks as guild groups."

local groupGuildPartyCB = CreateFrame("CheckButton", nil, p1, "InterfaceOptionsCheckButtonTemplate")
groupGuildPartyCB:SetPoint("TOPLEFT", p1, "TOPLEFT", 175, -246)
groupGuildPartyCB.Text:SetText("Guild Parties")
groupGuildPartyCB.tooltipText = "Auto-promote in parties that Blizzard marks as guild groups."

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

local deathGroupFilterLabel = p5:CreateFontString(nil, "ARTWORK", "GameFontNormal")
deathGroupFilterLabel:SetPoint("TOPLEFT", 8, -96)
deathGroupFilterLabel:SetText("Track recap data in:")

local deathGroupRaidCB = CreateFrame("CheckButton", nil, p5, "InterfaceOptionsCheckButtonTemplate")
deathGroupRaidCB:SetPoint("TOPLEFT", p5, "TOPLEFT", 8, -118)
deathGroupRaidCB.Text:SetText("Raids")
deathGroupRaidCB.tooltipText = "Track death recap data in any raid group."

local deathGroupPartyCB = CreateFrame("CheckButton", nil, p5, "InterfaceOptionsCheckButtonTemplate")
deathGroupPartyCB:SetPoint("TOPLEFT", p5, "TOPLEFT", 175, -118)
deathGroupPartyCB.Text:SetText("Parties")
deathGroupPartyCB.tooltipText = "Track death recap data in parties (not raids)."

local deathGroupGuildRaidCB = CreateFrame("CheckButton", nil, p5, "InterfaceOptionsCheckButtonTemplate")
deathGroupGuildRaidCB:SetPoint("TOPLEFT", p5, "TOPLEFT", 8, -146)
deathGroupGuildRaidCB.Text:SetText("Guild Raids")
deathGroupGuildRaidCB.tooltipText = "Track death recap data in raids that Blizzard marks as guild groups."

local deathGroupGuildPartyCB = CreateFrame("CheckButton", nil, p5, "InterfaceOptionsCheckButtonTemplate")
deathGroupGuildPartyCB:SetPoint("TOPLEFT", p5, "TOPLEFT", 175, -146)
deathGroupGuildPartyCB.Text:SetText("Guild Parties")
deathGroupGuildPartyCB.tooltipText = "Track death recap data in parties that Blizzard marks as guild groups."

local recapInfoText = p5:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
recapInfoText:SetPoint("TOPLEFT", 8, -184)
recapInfoText:SetWidth(520)
recapInfoText:SetJustifyH("LEFT")
recapInfoText:SetText("Use /arl deaths to open the recap at any time.")

local openRecapButton = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
openRecapButton:SetPoint("TOPLEFT", 8, -214)
openRecapButton:SetSize(140, 24)
openRecapButton:SetText("Open Last Recap")

-- ============================================================
-- Tab 6 - Raid Groups
-- ============================================================

local p6 = panels[6]

-- ---- Dropdown selector (top) --------------------------------
local raidLayoutListLabel = p6:CreateFontString(
    nil, "ARTWORK", "GameFontNormal"
)
raidLayoutListLabel:SetPoint("TOPLEFT", 8, -8)
raidLayoutListLabel:SetText("Saved raid layout")

local raidLayoutDropDown = CreateFrame(
    "Frame",
    "AstralRaidLeaderRaidLayoutDropDown",
    p6,
    "UIDropDownMenuTemplate"
)
raidLayoutDropDown:SetPoint("TOPLEFT", p6, "TOPLEFT", -8, -24)
UIDropDownMenu_SetWidth(raidLayoutDropDown, 590)
UIDropDownMenu_SetText(raidLayoutDropDown, "No saved raid layouts")
raidLayoutDropDown:EnableMouse(false)

local raidLayoutDropDownButton =
    _G["AstralRaidLeaderRaidLayoutDropDownButton"]
if raidLayoutDropDownButton then
    raidLayoutDropDownButton:EnableMouse(true)
    raidLayoutDropDownButton:SetHitRectInsets(0, 0, 0, 0)
    raidLayoutDropDownButton:SetScript("OnClick", function()
        if InCombatLockdown() then
            Print("Cannot change the selected raid layout"
                .. " while in combat.")
            return
        end
        if ToggleDropDownMenu then
            ToggleDropDownMenu(1, nil, raidLayoutDropDown)
        end
    end)
end

raidLayoutDropDown:SetScript("OnMouseDown",
    function(_, mouseButton)
        if mouseButton == "LeftButton"
            and ToggleDropDownMenu
            and not InCombatLockdown()
        then
            ToggleDropDownMenu(1, nil, raidLayoutDropDown)
        elseif mouseButton == "LeftButton"
            and InCombatLockdown()
        then
            Print("Cannot change the selected raid layout"
                .. " while in combat.")
        end
    end)

local raidLayoutDropDownText =
    _G["AstralRaidLeaderRaidLayoutDropDownText"]
if raidLayoutDropDownText then
    raidLayoutDropDownText:ClearAllPoints()
    raidLayoutDropDownText:SetPoint(
        "LEFT", raidLayoutDropDown, "LEFT", 32, 2)
    raidLayoutDropDownText:SetPoint(
        "RIGHT", raidLayoutDropDown, "RIGHT", -43, 2)
    raidLayoutDropDownText:SetJustifyH("LEFT")
end

-- ---- Top action buttons (Apply / Delete / Clear Saved) ------
local applyRaidLayoutButton = CreateFrame(
    "Button", nil, p6, "UIPanelButtonTemplate"
)
applyRaidLayoutButton:SetPoint("TOPLEFT", 8, -64)
applyRaidLayoutButton:SetSize(112, 24)
applyRaidLayoutButton:SetText("Apply")

local deleteRaidLayoutButton = CreateFrame(
    "Button", nil, p6, "UIPanelButtonTemplate"
)
deleteRaidLayoutButton:SetPoint(
    "LEFT", applyRaidLayoutButton, "RIGHT", 10, 0)
deleteRaidLayoutButton:SetSize(112, 24)
deleteRaidLayoutButton:SetText("Delete")

local clearRaidLayoutsButton = CreateFrame(
    "Button", nil, p6, "UIPanelButtonTemplate"
)
clearRaidLayoutsButton:SetPoint(
    "LEFT", deleteRaidLayoutButton, "RIGHT", 10, 0)
clearRaidLayoutsButton:SetSize(124, 24)
clearRaidLayoutsButton:SetText("Clear Saved")

local raidGroupsUI = {}

raidGroupsUI.layoutPlanningHelp = p6:CreateFontString(
    nil, "ARTWORK", "GameFontHighlightSmall")
raidGroupsUI.layoutPlanningHelp:SetPoint("TOPLEFT", 8, -94)
raidGroupsUI.layoutPlanningHelp:SetWidth(640)
raidGroupsUI.layoutPlanningHelp:SetJustifyH("LEFT")
raidGroupsUI.layoutPlanningHelp:SetText(
    "Start from the selected saved layout, adjust the draft below, then save a new version or overwrite the baseline.")

local raidImportPanel = panels[7]
local raidSettingsPanel = panels[8]

local raidEditorSection = CreateFrame("Frame", nil, p6)
raidEditorSection:SetPoint("TOPLEFT", 8, -108)
raidEditorSection:SetPoint("BOTTOMRIGHT", p6, "BOTTOMRIGHT", -8, -8)

raidGroupsUI.editorInset = CreateFrame(
    "Frame", nil, raidEditorSection,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
raidGroupsUI.editorInset:SetPoint("TOPLEFT", 0, 0)
raidGroupsUI.editorInset:SetPoint("BOTTOMRIGHT", raidEditorSection, "BOTTOMRIGHT", 0, 0)
SkinPanel(
    raidGroupsUI.editorInset,
    0.05, 0.09, 0.15, 0.22,
    0.22, 0.28, 0.36, 0.18)

raidGroupsUI.editorHeader = raidEditorSection:CreateFontString(
    nil, "OVERLAY", "GameFontNormal")
raidGroupsUI.editorHeader:SetPoint("TOPLEFT", 10, -10)
raidGroupsUI.editorHeader:SetText("Draft planner")

raidGroupsUI.editorHelp = raidEditorSection:CreateFontString(
    nil, "OVERLAY", "GameFontHighlightSmall")
raidGroupsUI.editorHelp:SetPoint("TOPLEFT", 10, -28)
raidGroupsUI.editorHelp:SetWidth(620)
raidGroupsUI.editorHelp:SetJustifyH("LEFT")
raidGroupsUI.editorHelp:SetText(
    "Plan subgroup assignments here. Left-click a player to pick up, click a group header to drop, right-click to remove.")

raidGroupsUI.editorStatusText = raidEditorSection:CreateFontString(
    nil, "OVERLAY", "GameFontHighlightSmall")
raidGroupsUI.editorStatusText:SetPoint("TOPLEFT", 10, -168)
raidGroupsUI.editorStatusText:SetWidth(620)
raidGroupsUI.editorStatusText:SetJustifyH("LEFT")
raidGroupsUI.editorStatusText:SetText("")

-- ---- Import section -----------------------------------------
local raidImportHeader = raidImportPanel:CreateFontString(
    nil, "ARTWORK", "GameFontNormal")
raidImportHeader:SetPoint("TOPLEFT", 8, -8)
raidImportHeader:SetText("Import raid layouts")

local raidImportHelp = raidImportPanel:CreateFontString(
    nil, "ARTWORK", "GameFontHighlightSmall")
raidImportHelp:SetPoint("TOPLEFT", 8, -28)
raidImportHelp:SetWidth(520)
raidImportHelp:SetJustifyH("LEFT")
raidImportHelp:SetText(
    "Paste a raid layout note here, then import it directly or load the first parsed layout into the visual editor.")

local raidImportInset = CreateFrame(
    "Frame", nil, raidImportPanel,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
raidImportInset:SetPoint("TOPLEFT", 8, -50)
raidImportInset:SetPoint("BOTTOMRIGHT", raidImportPanel, "BOTTOMRIGHT", -8, 34)
SkinPanel(
    raidImportInset,
    0.07, 0.10, 0.14, 0.34,
    0.22, 0.28, 0.36, 0.24)

local raidImportScroll = CreateFrame(
    "ScrollFrame",
    "AstralRaidLeaderRaidImportScrollFrame",
    raidImportInset,
    "UIPanelScrollFrameTemplate"
)
raidImportScroll:SetPoint("TOPLEFT", 10, -10)
raidImportScroll:SetPoint("BOTTOMRIGHT", -30, 10)

local raidImportScrollBar =
    _G["AstralRaidLeaderRaidImportScrollFrameScrollBar"]
if raidImportScrollBar then
    raidImportScrollBar:ClearAllPoints()
    raidImportScrollBar:SetPoint(
        "TOPRIGHT", raidImportInset, "TOPRIGHT", -4, -18)
    raidImportScrollBar:SetPoint(
        "BOTTOMRIGHT", raidImportInset,
        "BOTTOMRIGHT", -4, 18)
end

local raidImportEdit = CreateFrame(
    "EditBox", nil, raidImportScroll
)
raidImportEdit:SetMultiLine(true)
raidImportEdit:SetAutoFocus(false)
raidImportEdit:SetFontObject(ChatFontNormal)
raidImportEdit:SetWidth(484)
raidImportEdit:SetHeight(1024)
raidImportEdit:SetTextInsets(4, 4, 4, 4)
raidImportEdit:SetScript("OnEscapePressed",
    function(self) self:ClearFocus() end)
raidImportEdit:SetScript("OnTextChanged", function()
    raidImportScroll:UpdateScrollChildRect()
end)
raidImportEdit:SetScript("OnCursorChanged",
    function(_, _, y)
        raidImportScroll:SetVerticalScroll(
            math.max(0, y - 12))
    end)
raidImportScroll:SetScrollChild(raidImportEdit)

-- ---- Import section buttons ---------------------------------
local importRaidLayoutsButton = CreateFrame(
    "Button", nil, raidImportPanel, "UIPanelButtonTemplate"
)
importRaidLayoutsButton:ClearAllPoints()
importRaidLayoutsButton:SetPoint("BOTTOMLEFT", raidImportPanel, "BOTTOMLEFT", 8, 2)
importRaidLayoutsButton:SetSize(100, 24)
importRaidLayoutsButton:SetText("Import Note")

local clearRaidImportButton = CreateFrame(
    "Button", nil, raidImportPanel, "UIPanelButtonTemplate"
)
clearRaidImportButton:SetPoint(
    "LEFT", importRaidLayoutsButton, "RIGHT", 8, 0)
clearRaidImportButton:SetSize(90, 24)
clearRaidImportButton:SetText("Clear Text")

local loadToEditorButton = CreateFrame(
    "Button", nil, raidImportPanel, "UIPanelButtonTemplate"
)
loadToEditorButton:SetPoint(
    "LEFT", clearRaidImportButton, "RIGHT", 8, 0)
loadToEditorButton:SetSize(110, 24)
loadToEditorButton:SetText("Load To Editor")

-- ---- Editor section model + controls ------------------------
local raidEditorState = {
    encounterID = 0,
    difficulty = "mythic",
    name = "",
    groups = {},
}

local raidEditorLoadedKey = nil
local raidEditorHasDraft = false

for i = 1, 8 do
    raidEditorState.groups[i] = {}
end

local raidEditorDrag = nil
local raidEditorTargetGroup = 1
local raidEditorGroupButtons = {}
local raidEditorPlayerButtons = {}
local raidEditorMoreText = {}

local editorEncounterLabel = raidEditorSection:CreateFontString(
    nil, "ARTWORK", "GameFontNormalSmall")
editorEncounterLabel:SetPoint("TOPLEFT", 10, -58)
editorEncounterLabel:SetText("Encounter")

local editorEncounterEdit = CreateFrame(
    "EditBox", nil, raidEditorSection, "InputBoxTemplate")
editorEncounterEdit:SetPoint("LEFT", editorEncounterLabel, "RIGHT", 6, 0)
editorEncounterEdit:SetSize(58, 22)
editorEncounterEdit:SetAutoFocus(false)

local editorDifficultyLabel = raidEditorSection:CreateFontString(
    nil, "ARTWORK", "GameFontNormalSmall")
editorDifficultyLabel:SetPoint("LEFT", editorEncounterEdit, "RIGHT", 10, 0)
editorDifficultyLabel:SetText("Difficulty")

local editorDifficultyEdit = CreateFrame(
    "EditBox", nil, raidEditorSection, "InputBoxTemplate")
editorDifficultyEdit:SetPoint("LEFT", editorDifficultyLabel, "RIGHT", 6, 0)
editorDifficultyEdit:SetSize(68, 22)
editorDifficultyEdit:SetAutoFocus(false)

local editorNameLabel = raidEditorSection:CreateFontString(
    nil, "ARTWORK", "GameFontNormalSmall")
editorNameLabel:SetPoint("LEFT", editorDifficultyEdit, "RIGHT", 10, 0)
editorNameLabel:SetText("Name")

local editorNameEdit = CreateFrame(
    "EditBox", nil, raidEditorSection, "InputBoxTemplate")
editorNameEdit:SetAutoFocus(false)

local loadSelectedToEditorButton = CreateFrame(
    "Button", nil, raidEditorSection, "UIPanelButtonTemplate")
loadSelectedToEditorButton:SetSize(104, 24)
loadSelectedToEditorButton:SetText("Load Saved")

editorNameEdit:SetPoint("LEFT", editorNameLabel, "RIGHT", 6, 0)
editorNameEdit:SetPoint("RIGHT", raidEditorSection, "RIGHT", -116, 0)
editorNameEdit:SetHeight(22)

loadSelectedToEditorButton:SetPoint("LEFT", editorNameEdit, "RIGHT", 8, 0)

local editorPlayerLabel = raidEditorSection:CreateFontString(
    nil, "ARTWORK", "GameFontNormalSmall")
editorPlayerLabel:SetPoint("TOPLEFT", 10, -98)
editorPlayerLabel:SetText("Player")

local editorPlayerEdit = CreateFrame(
    "EditBox", nil, raidEditorSection, "InputBoxTemplate")
editorPlayerEdit:SetPoint("LEFT", editorPlayerLabel, "RIGHT", 6, 0)
editorPlayerEdit:SetSize(144, 22)
editorPlayerEdit:SetAutoFocus(false)

local editorGroupLabel = raidEditorSection:CreateFontString(
    nil, "ARTWORK", "GameFontNormalSmall")
editorGroupLabel:SetPoint("LEFT", editorPlayerEdit, "RIGHT", 10, 0)
editorGroupLabel:SetText("Group")

raidGroupsUI.editorGroupPrevButton = CreateFrame(
    "Button", nil, raidEditorSection, "UIPanelButtonTemplate")
raidGroupsUI.editorGroupPrevButton:SetPoint("LEFT", editorGroupLabel, "RIGHT", 6, 0)
raidGroupsUI.editorGroupPrevButton:SetSize(24, 24)
raidGroupsUI.editorGroupPrevButton:SetText("<")

raidGroupsUI.editorGroupValueFrame = CreateFrame(
    "Frame", nil, raidEditorSection,
    BackdropTemplateMixin and "BackdropTemplate" or nil)
raidGroupsUI.editorGroupValueFrame:SetPoint(
    "LEFT", raidGroupsUI.editorGroupPrevButton, "RIGHT", 4, 0)
raidGroupsUI.editorGroupValueFrame:SetSize(34, 22)
SkinPanel(
    raidGroupsUI.editorGroupValueFrame,
    0.05, 0.08, 0.12, 0.96,
    0.32, 0.41, 0.53, 0.92)

raidGroupsUI.editorGroupValueText = raidGroupsUI.editorGroupValueFrame:CreateFontString(
    nil, "OVERLAY", "GameFontNormalSmall")
raidGroupsUI.editorGroupValueText:SetPoint("CENTER")
raidGroupsUI.editorGroupValueText:SetText("1")

raidGroupsUI.editorGroupNextButton = CreateFrame(
    "Button", nil, raidEditorSection, "UIPanelButtonTemplate")
raidGroupsUI.editorGroupNextButton:SetPoint(
    "LEFT", raidGroupsUI.editorGroupValueFrame, "RIGHT", 4, 0)
raidGroupsUI.editorGroupNextButton:SetSize(24, 24)
raidGroupsUI.editorGroupNextButton:SetText(">")

local editorAddPlayerButton = CreateFrame(
    "Button", nil, raidEditorSection, "UIPanelButtonTemplate")
editorAddPlayerButton:SetPoint("LEFT", raidGroupsUI.editorGroupNextButton, "RIGHT", 8, 0)
editorAddPlayerButton:SetSize(54, 24)
editorAddPlayerButton:SetText("Add")

local newEmptyRaidLayoutButton = CreateFrame(
    "Button", nil, raidEditorSection, "UIPanelButtonTemplate"
)
newEmptyRaidLayoutButton:SetSize(66, 24)
newEmptyRaidLayoutButton:SetText("Empty")

local newFromRaidLayoutButton = CreateFrame(
    "Button", nil, raidEditorSection, "UIPanelButtonTemplate"
)
newFromRaidLayoutButton:SetSize(88, 24)
newFromRaidLayoutButton:SetText("From Raid")

local reorganizeRaidLayoutButton = CreateFrame(
    "Button", nil, raidEditorSection, "UIPanelButtonTemplate"
)
reorganizeRaidLayoutButton:SetSize(96, 24)
reorganizeRaidLayoutButton:SetText("Reorganize")

local saveNewRaidLayoutButton = CreateFrame(
    "Button", nil, raidEditorSection, "UIPanelButtonTemplate"
)
saveNewRaidLayoutButton:SetPoint("TOPRIGHT", raidEditorSection, "TOPRIGHT", -110, -74)
saveNewRaidLayoutButton:SetSize(98, 24)
saveNewRaidLayoutButton:SetText("Save New")

local overwriteRaidLayoutButton = CreateFrame(
    "Button", nil, raidEditorSection, "UIPanelButtonTemplate"
)
overwriteRaidLayoutButton:SetPoint("TOPRIGHT", raidEditorSection, "TOPRIGHT", -2, -74)
overwriteRaidLayoutButton:SetSize(100, 24)
overwriteRaidLayoutButton:SetText("Overwrite")

saveNewRaidLayoutButton:ClearAllPoints()
saveNewRaidLayoutButton:SetPoint("LEFT", newFromRaidLayoutButton, "RIGHT", 10, 0)

overwriteRaidLayoutButton:ClearAllPoints()
overwriteRaidLayoutButton:SetPoint("LEFT", saveNewRaidLayoutButton, "RIGHT", 10, 0)

newEmptyRaidLayoutButton:ClearAllPoints()
newEmptyRaidLayoutButton:SetPoint("TOPLEFT", raidEditorSection, "TOPLEFT", 10, -132)

newFromRaidLayoutButton:ClearAllPoints()
newFromRaidLayoutButton:SetPoint("LEFT", newEmptyRaidLayoutButton, "RIGHT", 10, 0)

reorganizeRaidLayoutButton:ClearAllPoints()
reorganizeRaidLayoutButton:SetPoint("LEFT", newFromRaidLayoutButton, "RIGHT", 10, 0)

saveNewRaidLayoutButton:ClearAllPoints()
saveNewRaidLayoutButton:SetPoint("LEFT", reorganizeRaidLayoutButton, "RIGHT", 10, 0)

local function CreateEditorGroupBox(groupIndex, x, y)
    local frame = CreateFrame(
        "Frame", nil, raidEditorSection,
        BackdropTemplateMixin and "BackdropTemplate" or nil
    )
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetSize(148, 118)
    SkinPanel(
        frame,
        0.07, 0.10, 0.14, 0.34,
        0.22, 0.28, 0.36, 0.24)

    local header = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    header:SetPoint("TOPLEFT", 4, -4)
    header:SetSize(140, 20)
    header:SetText("Group " .. tostring(groupIndex))
    header._groupIndex = groupIndex
    raidEditorGroupButtons[groupIndex] = header

    raidEditorPlayerButtons[groupIndex] = {}
    for slot = 1, 5 do
        local btn = CreateFrame("Button", nil, frame)
        btn:SetPoint("TOPLEFT", 6, -10 - (slot * 15))
        btn:SetSize(134, 14)
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("LEFT", 2, 0)
        txt:SetJustifyH("LEFT")
        txt:SetJustifyV("MIDDLE")
        txt:SetWordWrap(false)
        txt:SetWidth(130)
        btn.Text = txt
        btn._groupIndex = groupIndex
        btn._slot = slot
        raidEditorPlayerButtons[groupIndex][slot] = btn
    end

    local more = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    more:SetPoint("BOTTOMLEFT", 6, 5)
    more:SetJustifyH("LEFT")
    more:SetText("")
    raidEditorMoreText[groupIndex] = more
end

for groupIndex = 1, 8 do
    local col = (groupIndex - 1) % 4
    local row = math.floor((groupIndex - 1) / 4)
    CreateEditorGroupBox(groupIndex, 10 + (col * 153), -190 - (row * 126))
end

-- ---- Checkboxes (bottom) ------------------------------------
-- ---- Panel 7 - Raid Groups Settings ------------------------
local p8 = raidSettingsPanel

local raidGroupSettingsHeader = p8:CreateFontString(
    nil, "ARTWORK", "GameFontNormal")
raidGroupSettingsHeader:SetPoint("TOPLEFT", 8, -8)
raidGroupSettingsHeader:SetText("Raid Group Settings")

local raidGroupSettingsHelp = p8:CreateFontString(
    nil, "ARTWORK", "GameFontHighlightSmall")
raidGroupSettingsHelp:SetPoint("TOPLEFT", 8, -28)
raidGroupSettingsHelp:SetWidth(520)
raidGroupSettingsHelp:SetJustifyH("LEFT")
raidGroupSettingsHelp:SetText(
    "These options control apply behavior for saved raid layouts.")

local raidGroupAutoApplyOnJoinListCB = CreateCheckbox(p8,
    "Auto-apply selected layout when a member joins",
    "When enabled, the selected layout is re-applied"
        .. " whenever a new raid member joins.",
    8, -60)

local raidGroupShowMissingNamesCB = CreateCheckbox(p8,
    "Show names of missing players in apply output",
    "When enabled, the apply completion message lists each"
        .. " invited player that was not in the raid.",
    8, -88)

local raidGroupInviteMissingPlayersCB = CreateCheckbox(p8,
    "Invite listed players not already in the raid on apply",
    "When enabled, applying the selected raid layout also"
        .. " invites listed players who are not already in"
        .. " the group.",
    8, -116)

for _, cb in ipairs({
    autoCB, reminderCB, notifyCB, notifySoundCB, quietCB,
    groupRaidCB, groupPartyCB, groupGuildRaidCB, groupGuildPartyCB,
    useGuildRankCB, consumableAuditCB,
    deathTrackingCB, showRecapCB, showRecapOnAnyEndCB,
    deathGroupRaidCB, deathGroupPartyCB, deathGroupGuildRaidCB, deathGroupGuildPartyCB,
    raidGroupAutoApplyOnJoinListCB,
    raidGroupShowMissingNamesCB,
    raidGroupInviteMissingPlayersCB,
}) do
    StyleCheckbox(cb)
end

for _, edit in ipairs({
    nameEdit, rankNameEdit, catEdit, spellIdEdit,
    editorEncounterEdit, editorDifficultyEdit,
    editorNameEdit, editorPlayerEdit,
}) do
    SkinInputBox(edit)
end

for _, btn in ipairs({
    closeButton,
    addButton, removeButton, clearButton, promoteButton, moveUpButton, moveDownButton,
    addRankButton, removeRankButton, clearRanksButton, moveRankUpButton, moveRankDownButton, refreshGuildRanksButton,
    addConsumableButton, removeSpellIdButton, deleteCatButton, clearConsumablesButton, runAuditButton,
    openRecapButton,
    importRaidLayoutsButton, clearRaidImportButton, loadToEditorButton, applyRaidLayoutButton,
    deleteRaidLayoutButton, clearRaidLayoutsButton,
    loadSelectedToEditorButton,
    raidGroupsUI.editorGroupPrevButton, raidGroupsUI.editorGroupNextButton,
    editorAddPlayerButton,
    newEmptyRaidLayoutButton, newFromRaidLayoutButton, reorganizeRaidLayoutButton,
    saveNewRaidLayoutButton, overwriteRaidLayoutButton,
}) do
    SkinActionButton(btn)
end

for _, btn in ipairs(guildRankButtons) do
    SkinActionButton(btn)
end

for _, btn in ipairs(raidEditorGroupButtons) do
    SkinActionButton(btn)
end

AttachButtonTooltip(
    applyRaidLayoutButton,
    "Apply Layout",
    "Moves current raid members into the saved subgroup layout for the selected encounter."
)
AttachButtonTooltip(
    deleteRaidLayoutButton,
    "Delete Layout",
    "Removes the currently selected saved raid layout."
)
AttachButtonTooltip(
    clearRaidLayoutsButton,
    "Clear Saved Layouts",
    "Deletes every saved raid layout and clears the current selection."
)
AttachButtonTooltip(
    importRaidLayoutsButton,
    "Import Note",
    "Parses the text in the import box and adds or updates saved raid layouts from that note format."
)
AttachButtonTooltip(
    clearRaidImportButton,
    "Clear Text",
    "Clears the import text box without changing any saved layouts."
)
AttachButtonTooltip(
    loadToEditorButton,
    "Load To Editor",
    "Parses the first layout found in the import text and opens it in the visual editor."
)
AttachButtonTooltip(
    loadSelectedToEditorButton,
    "Reset To Saved",
    "Reloads the selected saved layout into the draft planner. If the draft has unsaved changes, you will be asked before they are discarded."
)
AttachButtonTooltip(
    raidGroupsUI.editorGroupPrevButton,
    "Previous Group",
    "Moves the add-player target group down by one."
)
AttachButtonTooltip(
    raidGroupsUI.editorGroupNextButton,
    "Next Group",
    "Moves the add-player target group up by one."
)
AttachButtonTooltip(
    editorAddPlayerButton,
    "Add Player",
    "Adds the typed player name to the chosen group in the visual editor. Existing entries are moved instead of duplicated."
)
AttachButtonTooltip(
    newEmptyRaidLayoutButton,
    "Empty Layout",
    "Starts a blank layout template in the editor using the current encounter fields."
)
AttachButtonTooltip(
    newFromRaidLayoutButton,
    "From Raid",
    "Builds an editor layout from the current raid roster order so you can adjust it visually."
)
AttachButtonTooltip(
    reorganizeRaidLayoutButton,
    "Reorganize",
    "Compacts the draft into sequential five-player groups while keeping the current top-to-bottom order."
)
AttachButtonTooltip(
    saveNewRaidLayoutButton,
    "Save New",
    "Saves the current editor layout as a new saved raid layout."
)
AttachButtonTooltip(
    overwriteRaidLayoutButton,
    "Overwrite",
    "Replaces the currently selected saved layout with the contents of the visual editor."
)

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

local function ResetRaidEditorState()
    raidEditorState.encounterID = 0
    raidEditorState.difficulty = "mythic"
    raidEditorState.name = ""
    for i = 1, 8 do
        raidEditorState.groups[i] = {}
    end
    raidEditorDrag = nil
    raidEditorTargetGroup = 1
    raidGroupsUI.editorGroupValueText:SetText("1")
    raidEditorLoadedKey = nil
    raidEditorHasDraft = false
end

local function GetActiveRaidLayoutKey()
    if not ARL or not ARL.db then
        return nil
    end
    local activeKey = Normalize(ARL.db.activeRaidLayoutKey or "")
    if activeKey == "" then
        return nil
    end
    return activeKey
end

local function SetEditorTargetGroup(groupIndex)
    raidEditorTargetGroup = math.max(1, math.min(8, tonumber(groupIndex) or 1))
    raidGroupsUI.editorGroupValueText:SetText(tostring(raidEditorTargetGroup))
end

local function BuildEditorGroupsFromProfile(profile)
    local groups = {}
    for groupIndex = 1, 8 do
        groups[groupIndex] = {}
    end

    if not profile then
        return groups
    end

    local hasGroupedAssignments = false
    local seenNames = {}
    if type(profile.groups) == "table" then
        for groupIndex = 1, 8 do
            if type(profile.groups[groupIndex]) == "table" then
                for _, playerName in ipairs(profile.groups[groupIndex]) do
                    local cleanName = Normalize(playerName)
                    local key = cleanName:lower()
                    if cleanName ~= "" and not seenNames[key] then
                        seenNames[key] = true
                        groups[groupIndex][#groups[groupIndex] + 1] = cleanName
                        hasGroupedAssignments = true
                    end
                end
            end
        end
    end

    if hasGroupedAssignments or #(profile.invitelist or {}) == 0 then
        return groups
    end

    local flattenedCount = 0
    seenNames = {}
    for _, playerName in ipairs(profile.invitelist or {}) do
        local cleanName = Normalize(playerName)
        local key = cleanName:lower()
        if cleanName ~= "" and not seenNames[key] then
            seenNames[key] = true
            flattenedCount = flattenedCount + 1
            local groupIndex = math.max(1, math.min(8, math.floor((flattenedCount - 1) / 5) + 1))
            groups[groupIndex][#groups[groupIndex] + 1] = cleanName
        end
    end

    return groups
end

local function BuildRaidEditorSnapshot()
    local difficulty = Normalize(editorDifficultyEdit:GetText()):lower()
    local snapshot = {
        encounterID = tonumber(editorEncounterEdit:GetText()) or 0,
        difficulty = difficulty,
        name = Normalize(editorNameEdit:GetText()),
        groups = {},
    }

    if snapshot.difficulty == "" then
        snapshot.difficulty = "mythic"
    end

    for groupIndex = 1, 8 do
        snapshot.groups[groupIndex] = {}
        for _, playerName in ipairs(raidEditorState.groups[groupIndex] or {}) do
            snapshot.groups[groupIndex][#snapshot.groups[groupIndex] + 1] = playerName
        end
    end

    return snapshot
end

local function BuildProfileSnapshot(profile)
    if not profile then
        return nil
    end

    local difficulty = Normalize(profile.difficulty or ""):lower()

    local snapshot = {
        encounterID = tonumber(profile.encounterID) or 0,
        difficulty = difficulty,
        name = Normalize(profile.name or ""),
        groups = {},
    }

    if snapshot.difficulty == "" then
        snapshot.difficulty = "mythic"
    end

    local groups = BuildEditorGroupsFromProfile(profile)
    for groupIndex = 1, 8 do
        snapshot.groups[groupIndex] = {}
        for _, playerName in ipairs(groups[groupIndex] or {}) do
            snapshot.groups[groupIndex][#snapshot.groups[groupIndex] + 1] = playerName
        end
    end

    return snapshot
end

local function RaidEditorSnapshotsMatch(left, right)
    if not left or not right then
        return false
    end
    if left.encounterID ~= right.encounterID
        or left.difficulty ~= right.difficulty
        or left.name ~= right.name
    then
        return false
    end

    for groupIndex = 1, 8 do
        local leftGroup = left.groups[groupIndex] or {}
        local rightGroup = right.groups[groupIndex] or {}
        if #leftGroup ~= #rightGroup then
            return false
        end
        for slot = 1, #leftGroup do
            if not NamesMatch(leftGroup[slot], rightGroup[slot]) then
                return false
            end
        end
    end

    return true
end

local function UpdateRaidEditorDraftState()
    local active = ARL.GetActiveRaidLayoutProfile
        and ARL.GetActiveRaidLayoutProfile() or nil
    local activeKey = GetActiveRaidLayoutKey()
    if not active or not activeKey then
        raidEditorHasDraft = true
        return
    end

    local current = BuildRaidEditorSnapshot()
    local baseline = BuildProfileSnapshot(active)
    raidEditorHasDraft = raidEditorLoadedKey ~= activeKey
        or not RaidEditorSnapshotsMatch(current, baseline)
end

local function GetEditorTargetGroup()
    return raidEditorTargetGroup
end

local function FindEditorPlayer(name)
    for groupIndex = 1, 8 do
        for slot, existing in ipairs(raidEditorState.groups[groupIndex]) do
            if NamesMatch(existing, name) then
                return groupIndex, slot
            end
        end
    end
    return nil, nil
end

local function RemoveEditorPlayer(name)
    local groupIndex, slot = FindEditorPlayer(name)
    if not groupIndex then
        return false
    end
    table.remove(raidEditorState.groups[groupIndex], slot)
    return true
end

local function BuildProfileFromEditorState()
    local encounterID = tonumber(editorEncounterEdit:GetText()) or 0
    local difficulty = Normalize(editorDifficultyEdit:GetText())
    local layoutName = Normalize(editorNameEdit:GetText())
    if difficulty == "" then
        difficulty = "mythic"
    end
    if layoutName == "" then
        layoutName = "Custom Layout"
    end

    raidEditorState.encounterID = encounterID
    raidEditorState.difficulty = difficulty
    raidEditorState.name = layoutName

    local groups = {}
    for groupIndex = 1, 8 do
        groups[groupIndex] = {}
        for _, name in ipairs(raidEditorState.groups[groupIndex]) do
            groups[groupIndex][#groups[groupIndex] + 1] = name
        end
    end

    return {
        encounterID = encounterID,
        difficulty = difficulty,
        name = layoutName,
        groups = groups,
    }
end

local function LoadEditorFromProfile(profile)
    ResetRaidEditorState()
    raidEditorState.encounterID = profile.encounterID or 0
    raidEditorState.difficulty = profile.difficulty or "mythic"
    raidEditorState.name = profile.name or ""
    local groups = BuildEditorGroupsFromProfile(profile)
    for groupIndex = 1, 8 do
        for _, playerName in ipairs(groups[groupIndex] or {}) do
            raidEditorState.groups[groupIndex][#raidEditorState.groups[groupIndex] + 1] = playerName
        end
    end
    raidEditorLoadedKey = GetActiveRaidLayoutKey()
    raidEditorHasDraft = false
end

local function ReorganizeRaidEditorGroups()
    local orderedNames = {}
    for groupIndex = 1, 8 do
        for _, playerName in ipairs(raidEditorState.groups[groupIndex] or {}) do
            orderedNames[#orderedNames + 1] = playerName
        end
    end

    for groupIndex = 1, 8 do
        raidEditorState.groups[groupIndex] = {}
    end

    for index, playerName in ipairs(orderedNames) do
        local groupIndex = math.max(1, math.min(8, math.floor((index - 1) / 5) + 1))
        raidEditorState.groups[groupIndex][#raidEditorState.groups[groupIndex] + 1] = playerName
    end

    raidEditorDrag = nil
    SetEditorTargetGroup(1)
end

local function LoadEditorFromImportText(text)
    if not ARL.ParseRaidLayoutImport then
        return false, "Raid layout parser is not available yet."
    end
    local profiles, err = ARL.ParseRaidLayoutImport(text or "")
    if not profiles then
        return false, err
    end
    if #profiles == 0 then
        return false, "No raid layout entries were found."
    end
    LoadEditorFromProfile(profiles[1])
    raidEditorLoadedKey = nil
    raidEditorHasDraft = true
    return true
end

local function LoadEditorFromCurrentRaid()
    if not IsInRaid() then
        return false, "You must be in a raid group to seed from roster."
    end
    if not ARL.BuildNewRaidLayoutImportText then
        return false, "Raid layout template tools are not available yet."
    end

    local ok, result = ARL.BuildNewRaidLayoutImportText(false)
    if not ok then
        return false, result
    end

    local loaded, err = LoadEditorFromImportText(result)
    if not loaded then
        return false, err
    end

    for groupIndex = 1, 8 do
        raidEditorState.groups[groupIndex] = {}
    end

    local seen = {}
    for raidIndex = 1, MAX_RAID_MEMBERS do
        local name, _, subgroup = GetRaidRosterInfo(raidIndex)
        local cleanName = Normalize(name)
        if cleanName ~= "" then
            local key = cleanName:lower()
            if not seen[key] then
                seen[key] = true
                local targetGroup = math.max(1, math.min(8, tonumber(subgroup) or 1))
                raidEditorState.groups[targetGroup][#raidEditorState.groups[targetGroup] + 1] = cleanName
            end
        end
    end

    raidEditorDrag = nil
    SetEditorTargetGroup(1)
    raidEditorLoadedKey = nil
    raidEditorHasDraft = true
    return true
end

local function RefreshRaidEditorBoard()
    editorEncounterEdit:SetText(tostring(raidEditorState.encounterID or 0))
    local displayDifficulty = ARL.FormatRaidDifficultyDisplay
        and ARL.FormatRaidDifficultyDisplay(raidEditorState.difficulty or "mythic")
        or tostring(raidEditorState.difficulty or "mythic")
    editorDifficultyEdit:SetText(tostring(displayDifficulty))
    editorNameEdit:SetText(tostring(raidEditorState.name or ""))
    raidGroupsUI.editorGroupValueText:SetText(tostring(raidEditorTargetGroup))

    for groupIndex = 1, 8 do
        local groupList = raidEditorState.groups[groupIndex] or {}
        local header = raidEditorGroupButtons[groupIndex]
        if header then
            if raidEditorDrag then
                header:SetText(string.format("Drop G%d (%d)", groupIndex, #groupList))
            else
                header:SetText(string.format("Group %d (%d)", groupIndex, #groupList))
            end
            local headerText = header:GetFontString()
            if headerText and headerText.SetTextColor then
                if raidEditorDrag then
                    headerText:SetTextColor(0.95, 0.81, 0.24)
                else
                    headerText:SetTextColor(0.90, 0.92, 0.96)
                end
            end
        end
        for slot = 1, 5 do
            local btn = raidEditorPlayerButtons[groupIndex][slot]
            local name = groupList[slot]
            btn._playerName = name
            if name then
                btn.Text:SetText(ShortName(name))
                if raidEditorDrag
                    and raidEditorDrag.name == name
                    and raidEditorDrag.fromGroup == groupIndex
                then
                    btn.Text:SetTextColor(0.95, 0.81, 0.24)
                else
                    btn.Text:SetTextColor(0.90, 0.92, 0.96)
                end
                btn:Show()
            else
                btn:Hide()
            end
        end
        local overflow = #groupList - 5
        if raidEditorMoreText[groupIndex] then
            if overflow > 0 then
                raidEditorMoreText[groupIndex]:SetText("+" .. tostring(overflow) .. " more")
            else
                raidEditorMoreText[groupIndex]:SetText("")
            end
        end
    end

    UpdateRaidEditorDraftState()

    if raidEditorDrag then
        raidGroupsUI.editorStatusText:SetText(
            "Placing " .. ShortName(raidEditorDrag.name)
                .. ". Click a group header to drop them.")
        raidGroupsUI.editorStatusText:SetTextColor(0.95, 0.81, 0.24)
    else
        raidGroupsUI.editorStatusText:SetText("")
        raidGroupsUI.editorStatusText:SetTextColor(0.80, 0.82, 0.86)
    end

    if raidEditorHasDraft then
        loadSelectedToEditorButton:SetText("Reset To Saved")
    else
        loadSelectedToEditorButton:SetText("Load Saved")
    end
end

local function RefreshRaidEditorPanel()
    if not raidEditorLoadedKey and not raidEditorHasDraft then
        local active = ARL.GetActiveRaidLayoutProfile
            and ARL.GetActiveRaidLayoutProfile() or nil
        if active then
            LoadEditorFromProfile(active)
        end
    end
    RefreshRaidEditorBoard()
end

for groupIndex = 1, 8 do
    local header = raidEditorGroupButtons[groupIndex]
    if header then
        header:SetScript("OnClick", function(self)
            if not raidEditorDrag then
                SetEditorTargetGroup(self._groupIndex)
                return
            end
            local toGroup = self._groupIndex
            local fromGroup = raidEditorDrag.fromGroup
            if toGroup == fromGroup then
                raidEditorDrag = nil
                RefreshRaidEditorBoard()
                return
            end
            if #raidEditorState.groups[toGroup] >= 5 then
                Print("Target group is full (5 players max).")
                return
            end
            RemoveEditorPlayer(raidEditorDrag.name)
            raidEditorState.groups[toGroup][#raidEditorState.groups[toGroup] + 1] = raidEditorDrag.name
            raidEditorDrag = nil
            RefreshRaidEditorBoard()
        end)
    end

    for slot = 1, 5 do
        local playerBtn = raidEditorPlayerButtons[groupIndex][slot]
        playerBtn:SetScript("OnClick", function(self, button)
            local playerName = self._playerName
            if not playerName then
                return
            end
            if button == "RightButton" then
                RemoveEditorPlayer(playerName)
                if raidEditorDrag and raidEditorDrag.name == playerName then
                    raidEditorDrag = nil
                end
                RefreshRaidEditorBoard()
                return
            end
            if raidEditorDrag and raidEditorDrag.name == playerName then
                raidEditorDrag = nil
                RefreshRaidEditorBoard()
                return
            end
            raidEditorDrag = {
                name = playerName,
                fromGroup = self._groupIndex,
            }
            RefreshRaidEditorBoard()
            Print("Picked up " .. playerName .. ". Click a group header to drop.")
        end)
    end
end

raidGroupsUI.editorGroupPrevButton:SetScript("OnClick", function()
    SetEditorTargetGroup(raidEditorTargetGroup - 1)
end)

raidGroupsUI.editorGroupNextButton:SetScript("OnClick", function()
    SetEditorTargetGroup(raidEditorTargetGroup + 1)
end)

local function RefreshRaidLayoutUI()
    applyRaidLayoutButton:Disable()
    deleteRaidLayoutButton:Disable()
    clearRaidLayoutsButton:Disable()
    overwriteRaidLayoutButton:Disable()
    loadSelectedToEditorButton:Disable()

    if not ARL.db then
        UIDropDownMenu_SetText(
            raidLayoutDropDown,
            "Waiting for saved variables to load...")
        RefreshRaidEditorBoard()
        return
    end

    if #ARL.db.raidLayouts == 0 then
        UIDropDownMenu_SetText(raidLayoutDropDown, "No saved raid layouts")
        RefreshRaidEditorBoard()
        return
    end

    clearRaidLayoutsButton:Enable()

    local active = ARL.GetActiveRaidLayoutProfile
        and ARL.GetActiveRaidLayoutProfile() or nil
    if not active then
        UIDropDownMenu_SetText(raidLayoutDropDown, "None (disabled)")
        RefreshRaidEditorBoard()
        return
    end

    UIDropDownMenu_SetText(
        raidLayoutDropDown,
        ARL.GetRaidLayoutLabel
            and ARL.GetRaidLayoutLabel(active)
            or (active.name or "Unknown")
    )

    applyRaidLayoutButton:Enable()
    deleteRaidLayoutButton:Enable()
    overwriteRaidLayoutButton:Enable()
    loadSelectedToEditorButton:Enable()

    RefreshRaidEditorPanel()
end

UIDropDownMenu_Initialize(raidLayoutDropDown, function(_, level)
    if level ~= 1 or not ARL.db then
        return
    end

    local activeKey = ARL.db.activeRaidLayoutKey or ""

    local noneInfo = UIDropDownMenu_CreateInfo()
    noneInfo.text = "None (disabled)"
    noneInfo.checked = activeKey == ""
    noneInfo.func = function()
        if InCombatLockdown() then
            Print("Cannot change the selected raid layout while in combat.")
            return
        end
        if activeKey == "" then
            return
        end
        if raidEditorHasDraft and _G.StaticPopup_Show then
            _G.StaticPopup_Show(
                "ASTRALRAIDLEADER_SWITCH_LAYOUT_CONFIRM",
                "(disable layout selection)",
                nil,
                { layoutKey = "" }
            )
            return
        end
        ARL.db.activeRaidLayoutKey = ""
        raidEditorLoadedKey = nil
        raidEditorHasDraft = false
        RefreshRaidLayoutUI()
        Print("Cleared selected raid layout.")
    end
    UIDropDownMenu_AddButton(noneInfo, level)

    for _, profile in ipairs(ARL.db.raidLayouts or {}) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = ARL.GetRaidLayoutLabel and ARL.GetRaidLayoutLabel(profile) or (profile.name or "Unknown")
        info.checked = profile.key == activeKey
        info.func = function()
            if InCombatLockdown() then
                Print("Cannot change the selected raid layout while in combat.")
                return
            end
            if ARL.db.activeRaidLayoutKey == profile.key then
                Print("That raid layout is already selected.")
                return
            end
            if raidEditorHasDraft and _G.StaticPopup_Show then
                local label = ARL.GetRaidLayoutLabel and ARL.GetRaidLayoutLabel(profile)
                    or (profile.name or "Unknown")
                _G.StaticPopup_Show(
                    "ASTRALRAIDLEADER_SWITCH_LAYOUT_CONFIRM",
                    label,
                    nil,
                    { layoutKey = profile.key }
                )
                return
            end
            if not ARL.SetActiveRaidLayoutByQuery then return end
            local ok, result = ARL.SetActiveRaidLayoutByQuery(profile.key)
            if not ok then
                Print(result)
                return
            end
            LoadEditorFromProfile(result)
            raidEditorLoadedKey = result.key
            raidEditorHasDraft = false
            RefreshRaidEditorBoard()
            RefreshRaidLayoutUI()
            Print(string.format(
                "Selected raid layout |cffffd100%s|r.",
                ARL.GetRaidLayoutLabel and ARL.GetRaidLayoutLabel(result) or (result.name or "Unknown")
            ))
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

local function RefreshUI()
    if not ARL.db then return end

    updating = true

    autoCB:SetChecked(ARL.db.autoPromote)
    reminderCB:SetChecked(ARL.db.reminderEnabled)
    notifyCB:SetChecked(ARL.db.notifyEnabled)
    notifySoundCB:SetChecked(ARL.db.notifySound)
    quietCB:SetChecked(ARL.db.quietMode)

    local filter = ARL.db.groupTypeFilter or "all"
    local ft = type(filter) == "table" and filter or {}
    groupRaidCB:SetChecked(ft.raid and true or false)
    groupPartyCB:SetChecked(ft.party and true or false)
    groupGuildRaidCB:SetChecked(ft.guild_raid and true or false)
    groupGuildPartyCB:SetChecked(ft.guild_party and true or false)

    useGuildRankCB:SetChecked(ARL.db.useGuildRankPriority)
    consumableAuditCB:SetChecked(ARL.db.consumableAuditEnabled)
    deathTrackingCB:SetChecked(ARL.db.deathTrackingEnabled)
    showRecapCB:SetChecked(ARL.db.showRecapOnWipe)
    showRecapOnAnyEndCB:SetChecked(ARL.db.showRecapOnEncounterEnd)

    local deathFilter = ARL.db.deathGroupTypeFilter or "raid"
    local dft = type(deathFilter) == "table" and deathFilter or {}
    deathGroupRaidCB:SetChecked(dft.raid and true or false)
    deathGroupPartyCB:SetChecked(dft.party and true or false)
    deathGroupGuildRaidCB:SetChecked(dft.guild_raid and true or false)
    deathGroupGuildPartyCB:SetChecked(dft.guild_party and true or false)

    raidGroupAutoApplyOnJoinListCB:SetChecked(ARL.db.raidGroupAutoApplyOnJoin == true)
    raidGroupShowMissingNamesCB:SetChecked(ARL.db.raidGroupShowMissingNames ~= false)
    raidGroupInviteMissingPlayersCB:SetChecked(ARL.db.raidGroupInviteMissingPlayers == true)

    RefreshListText()
    RefreshRankListText()
    RefreshConsumableListText()
    RefreshGuildRankButtons()
    RefreshRaidLayoutUI()

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
    if type(ARL.db.groupTypeFilter) ~= "table" then ARL.db.groupTypeFilter = {} end
    ARL.db.groupTypeFilter[filter] = not ARL.db.groupTypeFilter[filter]
    local FLBL = { raid="raids", party="parties", guild_raid="guild raids", guild_party="guild parties" }
    local en = ARL.db.groupTypeFilter[filter]
    Print(string.format("Group type filter: %s |cff%s%s|r.",
        FLBL[filter] or filter, en and "00ff00" or "ff0000", en and "enabled" or "disabled"))
end

groupRaidCB:SetScript("OnClick",      function() if not updating then SetGroupTypeFilter("raid")        end end)
groupPartyCB:SetScript("OnClick",     function() if not updating then SetGroupTypeFilter("party")       end end)
groupGuildRaidCB:SetScript("OnClick", function() if not updating then SetGroupTypeFilter("guild_raid")  end end)
groupGuildPartyCB:SetScript("OnClick",function() if not updating then SetGroupTypeFilter("guild_party") end end)

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

local function SetDeathGroupTypeFilter(filter)
    if not ARL.db then return end
    if type(ARL.db.deathGroupTypeFilter) ~= "table" then ARL.db.deathGroupTypeFilter = {} end
    ARL.db.deathGroupTypeFilter[filter] = not ARL.db.deathGroupTypeFilter[filter]
    local FLBL = { raid="raids", party="parties", guild_raid="guild raids", guild_party="guild parties" }
    local en = ARL.db.deathGroupTypeFilter[filter]
    Print(string.format("Death recap group filter: %s |cff%s%s|r.",
        FLBL[filter] or filter, en and "00ff00" or "ff0000", en and "enabled" or "disabled"))
end

deathGroupRaidCB:SetScript("OnClick", function()
    if not updating then SetDeathGroupTypeFilter("raid") end
end)
deathGroupPartyCB:SetScript("OnClick", function()
    if not updating then SetDeathGroupTypeFilter("party") end
end)
deathGroupGuildRaidCB:SetScript("OnClick", function()
    if not updating then SetDeathGroupTypeFilter("guild_raid") end
end)
deathGroupGuildPartyCB:SetScript("OnClick", function()
    if not updating then SetDeathGroupTypeFilter("guild_party") end
end)

openRecapButton:SetScript("OnClick", function()
    if ARL.ShowDeathRecap then
        ARL:ShowDeathRecap()
    else
        Print("Death recap UI is not available yet. Try again in a moment.")
    end
end)

-- ============================================================
-- Tab 6 - Raid Groups: handlers
-- ============================================================

local function SetRaidLayoutImportText(text)
    raidImportEdit:SetText(text or "")
    raidImportEdit:ClearFocus()
    raidImportScroll:UpdateScrollChildRect()
    raidImportScroll:SetVerticalScroll(0)
end

local function SaveEditedRaidLayout(options)
    if not ARL.SaveRaidLayoutProfileData then
        Print("Raid layout save is not available yet. Try again in a moment.")
        return false
    end

    local profile = BuildProfileFromEditorState()
    local ok, result = ARL.SaveRaidLayoutProfileData(profile, options)
    if not ok then
        Print(result)
        return false
    end

    if result and result.profile then
        LoadEditorFromProfile(result.profile)
        raidEditorLoadedKey = result.profile.key
        raidEditorHasDraft = false
    end

    RefreshRaidLayoutUI()
    local label = ARL.GetRaidLayoutLabel and ARL.GetRaidLayoutLabel(result.profile)
        or (result.profile and result.profile.name or "Unknown")
    if result.overwritten then
        Print(string.format("Overwrote raid layout |cffffd100%s|r.", label))
    else
        Print(string.format("Saved new raid layout |cffffd100%s|r.", label))
    end
    return true
end

if _G.StaticPopupDialogs and not _G.StaticPopupDialogs["ASTRALRAIDLEADER_OVERWRITE_LAYOUT"] then
    _G.StaticPopupDialogs["ASTRALRAIDLEADER_OVERWRITE_LAYOUT"] = {
        text = "Overwrite selected raid layout |cffffd100%s|r?",
        button1 = "Overwrite",
        button2 = "Cancel",
        OnAccept = function(_, data)
            if not data or not data.targetKey then return end
            local ok = SaveEditedRaidLayout({ overwrite = true, targetKey = data.targetKey })
            if ok and data.afterSave and type(data.afterSave) == "function" then
                data.afterSave()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

if _G.StaticPopupDialogs and not _G.StaticPopupDialogs["ASTRALRAIDLEADER_SWITCH_LAYOUT_CONFIRM"] then
    _G.StaticPopupDialogs["ASTRALRAIDLEADER_SWITCH_LAYOUT_CONFIRM"] = {
        text = "Discard changes to current draft and switch to |cffffd100%s|r?",
        button1 = "Discard and Switch",
        button2 = "Cancel",
        OnAccept = function(_, data)
            if not data then return end
            local layoutKey = data.layoutKey
            if layoutKey == "" then
                ARL.db.activeRaidLayoutKey = ""
                raidEditorLoadedKey = nil
                raidEditorHasDraft = false
                RefreshRaidLayoutUI()
                Print("Cleared selected raid layout.")
                return
            end
            if not ARL.SetActiveRaidLayoutByQuery then return end
            local ok, result = ARL.SetActiveRaidLayoutByQuery(layoutKey)
            if not ok then
                Print(result)
                return
            end
            raidEditorLoadedKey = nil
            raidEditorHasDraft = false
            RefreshRaidLayoutUI()
            Print(string.format(
                "Switched to raid layout |cffffd100%s|r.",
                ARL.GetRaidLayoutLabel and ARL.GetRaidLayoutLabel(result) or (result.name or "Unknown")
            ))
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

if _G.StaticPopupDialogs and not _G.StaticPopupDialogs["ASTRALRAIDLEADER_RESET_LAYOUT_DRAFT"] then
    _G.StaticPopupDialogs["ASTRALRAIDLEADER_RESET_LAYOUT_DRAFT"] = {
        text = "Discard the current draft and reload |cffffd100%s|r from saved layouts?",
        button1 = "Reset Draft",
        button2 = "Cancel",
        OnAccept = function(_, data)
            if not data or not data.profile then return end
            LoadEditorFromProfile(data.profile)
            RefreshRaidEditorBoard()
            Print("Draft reset to the saved raid layout.")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

loadSelectedToEditorButton:SetScript("OnClick", function()
    if not ARL.GetActiveRaidLayoutProfile then
        Print("Raid layout selection is not available yet. Try again in a moment.")
        return
    end
    local active = ARL.GetActiveRaidLayoutProfile()
    if not active then
        Print("Select a saved raid layout to load into the editor.")
        return
    end
    local label = ARL.GetRaidLayoutLabel and ARL.GetRaidLayoutLabel(active)
        or (active.name or "Unknown")

    if raidEditorHasDraft and _G.StaticPopup_Show then
        _G.StaticPopup_Show(
            "ASTRALRAIDLEADER_RESET_LAYOUT_DRAFT",
            label,
            nil,
            { profile = active }
        )
        return
    end

    LoadEditorFromProfile(active)
    RefreshRaidEditorBoard()
    Print("Loaded the saved raid layout into the draft editor.")
end)

editorAddPlayerButton:SetScript("OnClick", function()
    local playerName = Normalize(editorPlayerEdit:GetText())
    if playerName == "" then
        Print("Enter a player name first.")
        return
    end
    local groupIndex = GetEditorTargetGroup()
    if #raidEditorState.groups[groupIndex] >= 5 then
        Print("Target group is full (5 players max).")
        return
    end
    RemoveEditorPlayer(playerName)
    raidEditorState.groups[groupIndex][#raidEditorState.groups[groupIndex] + 1] = playerName
    editorPlayerEdit:SetText("")
    RefreshRaidEditorBoard()
end)

loadToEditorButton:SetScript("OnClick", function()
    local ok, err = LoadEditorFromImportText(raidImportEdit:GetText())
    if not ok then
        Print(err)
        return
    end
    RefreshRaidEditorBoard()
    if currentMainTabIndex == 4 then
        SelectSubTab(1)
    end
    Print("Loaded import text into the visual editor.")
end)

newEmptyRaidLayoutButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        Print("Cannot create a new raid layout while in combat.")
        return
    end
    if not ARL.BuildNewRaidLayoutImportText then
        Print("Raid layout template tools are not available yet. Try again in a moment.")
        return
    end
    local ok, result = ARL.BuildNewRaidLayoutImportText(false)
    if not ok then
        Print(result)
        return
    end
    local loaded, err = LoadEditorFromImportText(result)
    if not loaded then
        Print(err)
        return
    end
    RefreshRaidEditorBoard()
    Print("Created a new empty raid layout in the visual editor.")
end)

newFromRaidLayoutButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        Print("Cannot create a raid layout from roster while in combat.")
        return
    end

    local loaded, err = LoadEditorFromCurrentRaid()
    if not loaded then
        Print(err)
        return
    end

    RefreshRaidEditorBoard()
    Print("Created a raid-seeded layout with current subgroup assignments.")
end)

reorganizeRaidLayoutButton:SetScript("OnClick", function()
    ReorganizeRaidEditorGroups()
    RefreshRaidEditorBoard()
    Print("Reorganized the draft into sequential five-player groups.")
end)

saveNewRaidLayoutButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        Print("Cannot save raid layouts while in combat.")
        return
    end
    SaveEditedRaidLayout({ overwrite = false })
end)

overwriteRaidLayoutButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        Print("Cannot overwrite raid layouts while in combat.")
        return
    end
    if not ARL.GetActiveRaidLayoutProfile then
        Print("Raid layout selection is not available yet. Try again in a moment.")
        return
    end

    local active = ARL.GetActiveRaidLayoutProfile()
    if not active then
        Print("Select a saved raid layout to overwrite.")
        return
    end

    local label = ARL.GetRaidLayoutLabel and ARL.GetRaidLayoutLabel(active) or (active.name or "Unknown")
    if _G.StaticPopup_Show then
        _G.StaticPopup_Show(
            "ASTRALRAIDLEADER_OVERWRITE_LAYOUT",
            label,
            nil,
            { targetKey = active.key }
        )
    else
        Print("Overwrite confirmation dialog is unavailable in this client.")
    end
end)

importRaidLayoutsButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        Print("Cannot import raid layouts while in combat.")
        return
    end
    if not ARL.ImportRaidLayouts then
        Print("Raid layout import is not available yet. Try again in a moment.")
        return
    end

    local ok, result = ARL.ImportRaidLayouts(raidImportEdit:GetText())
    if not ok then
        Print(result)
        return
    end

    RefreshRaidLayoutUI()
    Print(string.format(
        "Imported %d raid layout(s): %d added, %d updated.",
        result.imported or 0,
        result.added or 0,
        result.updated or 0
    ))
end)

clearRaidImportButton:SetScript("OnClick", function()
    SetRaidLayoutImportText("")
end)

editorPlayerEdit:SetScript("OnEnterPressed", function()
    editorAddPlayerButton:Click()
end)
editorEncounterEdit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)
editorDifficultyEdit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)
editorNameEdit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)

applyRaidLayoutButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        Print("Cannot apply a raid layout while in combat.")
        return
    end
    if not ARL.ApplyRaidLayoutByQuery then
        Print("Raid layout apply is not available yet. Try again in a moment.")
        return
    end
    local ok, result = ARL.ApplyRaidLayoutByQuery("")
    if not ok then
        Print(result)
        return
    end
    if result then
        RefreshRaidLayoutUI()
    end
end)

deleteRaidLayoutButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        Print("Cannot delete a raid layout while in combat.")
        return
    end
    if not ARL.DeleteRaidLayoutByQuery then
        Print("Raid layout deletion is not available yet. Try again in a moment.")
        return
    end
    local ok, result = ARL.DeleteRaidLayoutByQuery("")
    if not ok then
        Print(result)
        return
    end
    RefreshRaidLayoutUI()
    Print(string.format(
        "Deleted raid layout |cffffd100%s|r.",
        ARL.GetRaidLayoutLabel and ARL.GetRaidLayoutLabel(result) or (result.name or "Unknown")
    ))
end)

clearRaidLayoutsButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        Print("Cannot clear raid layouts while in combat.")
        return
    end
    if not ARL.db then return end
    ARL.db.raidLayouts = {}
    ARL.db.activeRaidLayoutKey = ""
    RefreshRaidLayoutUI()
    Print("Cleared all saved raid layouts.")
end)

-- ============================================================
-- Tab 6 - Raid Groups: checkbox handlers (merged from panel 7)
-- ============================================================

raidGroupShowMissingNamesCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.raidGroupShowMissingNames = self:GetChecked()
        and true or false
    Print(string.format(
        "Show missing player names |cff%s%s|r.",
        ARL.db.raidGroupShowMissingNames
            and "00ff00" or "ff0000",
        ARL.db.raidGroupShowMissingNames
            and "enabled" or "disabled"))
end)

raidGroupAutoApplyOnJoinListCB:SetScript("OnClick",
    function(self)
        if updating or not ARL.db then return end
        ARL.db.raidGroupAutoApplyOnJoin =
            self:GetChecked() and true or false
        Print(string.format(
            "Auto-apply on join |cff%s%s|r.",
            ARL.db.raidGroupAutoApplyOnJoin
                and "00ff00" or "ff0000",
            ARL.db.raidGroupAutoApplyOnJoin
                and "enabled" or "disabled"))
    end)

raidGroupInviteMissingPlayersCB:SetScript("OnClick",
    function(self)
        if updating or not ARL.db then return end
        ARL.db.raidGroupInviteMissingPlayers =
            self:GetChecked() and true or false
        Print(string.format(
            "Invite missing listed players on apply"
            .. " |cff%s%s|r.",
            ARL.db.raidGroupInviteMissingPlayers
                and "00ff00" or "ff0000",
            ARL.db.raidGroupInviteMissingPlayers
                and "enabled" or "disabled"))
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
