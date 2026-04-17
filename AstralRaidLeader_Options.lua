-- AstralRaidLeader_Options.lua
-- Lightweight in-game settings window for AstralRaidLeader.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local ToggleDropDownMenu = _G.ToggleDropDownMenu
local MAX_RAID_MEMBERS = _G.MAX_RAID_MEMBERS or 40
local UnitInRaid = _G.UnitInRaid
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local GetInspectSpecialization = _G.GetInspectSpecialization
local GetSpecialization = _G.GetSpecialization
local GetSpecializationInfo = _G.GetSpecializationInfo
local GetSpecializationInfoByID = _G.GetSpecializationInfoByID
local GetNumGuildMembers = _G.GetNumGuildMembers
local GetGuildRosterInfo = _G.GetGuildRosterInfo
local IsInGuild = _G.IsInGuild
local C_GuildInfo = _G.C_GuildInfo
local GetTime = _G.GetTime
local GetCurrentKeyBoardFocus = _G.GetCurrentKeyBoardFocus
local UnitClass = _G.UnitClass
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local ROLE_ICON_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_ICON_TEX_COORDS = {
    TANK = { 0 / 64, 19 / 64, 22 / 64, 41 / 64 },
    HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}

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

local function RequireBuilderFields(builderName, ui, requiredFields)
    if type(ui) ~= "table" then
        Print(builderName .. " builder returned invalid data.")
        return nil
    end
    for _, field in ipairs(requiredFields) do
        if ui[field] == nil then
            Print(builderName .. " builder is missing field: " .. tostring(field))
            return nil
        end
    end
    return ui
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
    self:EnableKeyboard(false)
end)

frame:HookScript("OnHide", function(self)
    self:SetAlpha(0)
    self:EnableMouse(false)
    self:EnableKeyboard(false)
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

local generalBuilder = ARL.OptionsBuilders and ARL.OptionsBuilders.BuildGeneralPanel
if not generalBuilder then
    Print("General options builder is unavailable; settings window is disabled.")
    return
end

local generalUI = generalBuilder({
    panel = panels[1],
    CreateCheckbox = CreateCheckbox,
})

generalUI = RequireBuilderFields("General", generalUI, {
    "autoCB",
    "reminderCB",
    "notifyCB",
    "notifySoundCB",
    "quietCB",
    "groupRaidCB",
    "groupPartyCB",
    "groupGuildRaidCB",
    "groupGuildPartyCB",
})
if not generalUI then return end

-- ============================================================
-- Tab 2 – Leaders
-- ============================================================

local leadersBuilder = ARL.OptionsBuilders and ARL.OptionsBuilders.BuildLeadersPanel
if not leadersBuilder then
    Print("Leaders options builder is unavailable; settings window is disabled.")
    return
end

local leadersUI = leadersBuilder({
    panel = panels[2],
    SkinPanel = SkinPanel,
})

leadersUI = RequireBuilderFields("Leaders", leadersUI, {
    "listText",
    "nameEdit",
    "addButton",
    "removeButton",
    "clearButton",
    "promoteButton",
    "moveUpButton",
    "moveDownButton",
})
if not leadersUI then return end

-- ============================================================
-- Tab 3 – Guild Ranks
-- ============================================================

local guildRanksBuilder = ARL.OptionsBuilders and ARL.OptionsBuilders.BuildGuildRanksPanel
if not guildRanksBuilder then
    Print("Guild Ranks options builder is unavailable; settings window is disabled.")
    return
end

local guildRanksUI = guildRanksBuilder({
    panel = panels[3],
    CreateCheckbox = CreateCheckbox,
    SkinPanel = SkinPanel,
})

guildRanksUI = RequireBuilderFields("Guild Ranks", guildRanksUI, {
    "useGuildRankCB",
    "guildRankListText",
    "rankNameEdit",
    "addRankButton",
    "removeRankButton",
    "clearRanksButton",
    "moveRankUpButton",
    "moveRankDownButton",
    "refreshGuildRanksButton",
    "guildRankButtons",
    "noGuildRanksText",
})
if not guildRanksUI then return end

-- ============================================================
-- Tab 4 – Consumables
-- ============================================================

local consumablesBuilder = ARL.OptionsBuilders and ARL.OptionsBuilders.BuildConsumablesPanel
if not consumablesBuilder then
    Print("Consumables options builder is unavailable; settings window is disabled.")
    return
end

local consumablesUI = consumablesBuilder({
    panel = panels[4],
    CreateCheckbox = CreateCheckbox,
    SkinPanel = SkinPanel,
})

consumablesUI = RequireBuilderFields("Consumables", consumablesUI, {
    "consumableAuditCB",
    "consumableListText",
    "catEdit",
    "spellIdEdit",
    "addConsumableButton",
    "removeSpellIdButton",
    "deleteCatButton",
    "clearConsumablesButton",
    "runAuditButton",
})
if not consumablesUI then return end

-- ============================================================
-- Tab 5 - Deaths
-- ============================================================

local deathsBuilder = ARL.OptionsBuilders and ARL.OptionsBuilders.BuildDeathsPanel
if not deathsBuilder then
    Print("Deaths options builder is unavailable; settings window is disabled.")
    return
end

local deathsUI = deathsBuilder({
    panel = panels[5],
    CreateCheckbox = CreateCheckbox,
})

deathsUI = RequireBuilderFields("Deaths", deathsUI, {
    "deathTrackingCB",
    "showRecapCB",
    "showRecapOnAnyEndCB",
    "deathGroupRaidCB",
    "deathGroupPartyCB",
    "deathGroupGuildRaidCB",
    "deathGroupGuildPartyCB",
    "maxRecapsStoredEdit",
    "applyMaxRecapsStoredButton",
    "openRecapButton",
})
if not deathsUI then return end

-- ============================================================
-- Tab 6 - Raid Groups
-- ============================================================

local raidGroupsLayoutsBuilder = ARL.OptionsBuilders and ARL.OptionsBuilders.BuildRaidGroupsLayoutsPanel
if not raidGroupsLayoutsBuilder then
    Print("Raid Groups layouts builder is unavailable; settings window is disabled.")
    return
end

local raidGroupsLayoutsUI = raidGroupsLayoutsBuilder({
    panel = panels[6],
    SkinPanel = SkinPanel,
    UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth,
    UIDropDownMenu_SetText = UIDropDownMenu_SetText,
    ToggleDropDownMenu = ToggleDropDownMenu,
    Print = Print,
})

raidGroupsLayoutsUI = RequireBuilderFields("Raid Groups layouts", raidGroupsLayoutsUI, {
    "raidLayoutDropDown",
    "applyRaidLayoutButton",
    "deleteRaidLayoutButton",
    "clearRaidLayoutsButton",
    "raidGroupsUI",
    "raidEditorState",
    "raidEditorGroupButtons",
    "raidEditorPlayerButtons",
    "raidEditorMoreText",
    "editorEncounterEdit",
    "editorDifficultyEdit",
    "editorNameEdit",
    "loadSelectedToEditorButton",
    "editorPlayerEdit",
    "editorAddPlayerButton",
    "newEmptyRaidLayoutButton",
    "newFromRaidLayoutButton",
    "reorganizeRaidLayoutButton",
    "splitRaidLayoutButton",
    "saveNewRaidLayoutButton",
    "overwriteRaidLayoutButton",
})
if not raidGroupsLayoutsUI then return end

local raidLayoutDropDown = raidGroupsLayoutsUI.raidLayoutDropDown
local applyRaidLayoutButton = raidGroupsLayoutsUI.applyRaidLayoutButton
local deleteRaidLayoutButton = raidGroupsLayoutsUI.deleteRaidLayoutButton
local clearRaidLayoutsButton = raidGroupsLayoutsUI.clearRaidLayoutsButton
local raidGroupsUI = raidGroupsLayoutsUI.raidGroupsUI
local raidEditorState = raidGroupsLayoutsUI.raidEditorState
local raidEditorLoadedKey = nil
local raidEditorHasDraft = false
local raidEditorDrag = nil
local raidEditorTargetGroup = 1
local raidEditorGroupButtons = raidGroupsLayoutsUI.raidEditorGroupButtons
local raidEditorPlayerButtons = raidGroupsLayoutsUI.raidEditorPlayerButtons
local raidEditorMoreText = raidGroupsLayoutsUI.raidEditorMoreText
local editorEncounterEdit = raidGroupsLayoutsUI.editorEncounterEdit
local editorDifficultyEdit = raidGroupsLayoutsUI.editorDifficultyEdit
local editorNameEdit = raidGroupsLayoutsUI.editorNameEdit
local loadSelectedToEditorButton = raidGroupsLayoutsUI.loadSelectedToEditorButton
local editorPlayerEdit = raidGroupsLayoutsUI.editorPlayerEdit
local editorAddPlayerButton = raidGroupsLayoutsUI.editorAddPlayerButton
local newEmptyRaidLayoutButton = raidGroupsLayoutsUI.newEmptyRaidLayoutButton
local newFromRaidLayoutButton = raidGroupsLayoutsUI.newFromRaidLayoutButton
local reorganizeRaidLayoutButton = raidGroupsLayoutsUI.reorganizeRaidLayoutButton
local splitRaidLayoutButton = raidGroupsLayoutsUI.splitRaidLayoutButton
local saveNewRaidLayoutButton = raidGroupsLayoutsUI.saveNewRaidLayoutButton
local overwriteRaidLayoutButton = raidGroupsLayoutsUI.overwriteRaidLayoutButton

local raidImportPanel = panels[7]
local raidSettingsPanel = panels[8]

-- ---- Import section -----------------------------------------
local raidImportBuilder = ARL.OptionsBuilders and ARL.OptionsBuilders.BuildRaidGroupsImportPanel
if not raidImportBuilder then
    Print("Raid Groups import builder is unavailable; settings window is disabled.")
    return
end

local raidImportUI = raidImportBuilder({
    panel = raidImportPanel,
    SkinPanel = SkinPanel,
})

raidImportUI = RequireBuilderFields("Raid Groups import", raidImportUI, {
    "raidImportScroll",
    "raidImportEdit",
    "importRaidLayoutsButton",
    "clearRaidImportButton",
    "loadToEditorButton",
})
if not raidImportUI then return end

-- ---- Checkboxes (bottom) ------------------------------------
-- ---- Panel 7 - Raid Groups Settings ------------------------
local raidGroupsSettingsBuilder = ARL.OptionsBuilders and ARL.OptionsBuilders.BuildRaidGroupsSettingsPanel
if not raidGroupsSettingsBuilder then
    Print("Raid Groups settings builder is unavailable; settings window is disabled.")
    return
end

local raidGroupsSettingsUI = raidGroupsSettingsBuilder({
    panel = raidSettingsPanel,
    CreateCheckbox = CreateCheckbox,
})

raidGroupsSettingsUI = RequireBuilderFields("Raid Groups settings", raidGroupsSettingsUI, {
    "raidGroupAutoApplyOnJoinListCB",
    "raidGroupShowMissingNamesCB",
    "raidGroupInviteMissingPlayersCB",
})
if not raidGroupsSettingsUI then return end

for _, cb in ipairs({
    generalUI.autoCB, generalUI.reminderCB, generalUI.notifyCB, generalUI.notifySoundCB, generalUI.quietCB,
    generalUI.groupRaidCB, generalUI.groupPartyCB, generalUI.groupGuildRaidCB, generalUI.groupGuildPartyCB,
    guildRanksUI.useGuildRankCB, consumablesUI.consumableAuditCB,
    deathsUI.deathTrackingCB, deathsUI.showRecapCB, deathsUI.showRecapOnAnyEndCB,
    deathsUI.deathGroupRaidCB, deathsUI.deathGroupPartyCB,
    deathsUI.deathGroupGuildRaidCB, deathsUI.deathGroupGuildPartyCB,
    raidGroupsSettingsUI.raidGroupAutoApplyOnJoinListCB,
    raidGroupsSettingsUI.raidGroupShowMissingNamesCB,
    raidGroupsSettingsUI.raidGroupInviteMissingPlayersCB,
}) do
    StyleCheckbox(cb)
end

for _, edit in ipairs({
    leadersUI.nameEdit, guildRanksUI.rankNameEdit, consumablesUI.catEdit, consumablesUI.spellIdEdit,
    deathsUI.maxRecapsStoredEdit,
    editorEncounterEdit, editorDifficultyEdit,
    editorNameEdit, editorPlayerEdit,
}) do
    SkinInputBox(edit)
end

for _, btn in ipairs({
    closeButton,
    leadersUI.addButton, leadersUI.removeButton, leadersUI.clearButton,
    leadersUI.promoteButton, leadersUI.moveUpButton, leadersUI.moveDownButton,
    guildRanksUI.addRankButton, guildRanksUI.removeRankButton,
    guildRanksUI.clearRanksButton, guildRanksUI.moveRankUpButton,
    guildRanksUI.moveRankDownButton, guildRanksUI.refreshGuildRanksButton,
    consumablesUI.addConsumableButton, consumablesUI.removeSpellIdButton,
    consumablesUI.deleteCatButton, consumablesUI.clearConsumablesButton,
    consumablesUI.runAuditButton,
    deathsUI.applyMaxRecapsStoredButton,
    deathsUI.openRecapButton,
    raidImportUI.importRaidLayoutsButton, raidImportUI.clearRaidImportButton,
    raidImportUI.loadToEditorButton, applyRaidLayoutButton,
    deleteRaidLayoutButton, clearRaidLayoutsButton,
    loadSelectedToEditorButton,
    raidGroupsUI.editorGroupPrevButton, raidGroupsUI.editorGroupNextButton,
    editorAddPlayerButton,
    newEmptyRaidLayoutButton, newFromRaidLayoutButton,
    reorganizeRaidLayoutButton, splitRaidLayoutButton,
    saveNewRaidLayoutButton, overwriteRaidLayoutButton,
}) do
    SkinActionButton(btn)
end

for _, btn in ipairs(guildRanksUI.guildRankButtons) do
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
    "Delete All Layouts",
    "Deletes every saved raid layout and clears the current selection."
)
AttachButtonTooltip(
    raidImportUI.importRaidLayoutsButton,
    "Import Note",
    "Parses the text in the import box and adds or updates saved raid layouts from that note format."
)
AttachButtonTooltip(
    raidImportUI.clearRaidImportButton,
    "Clear Text",
    "Clears the import text box without changing any saved layouts."
)
AttachButtonTooltip(
    raidImportUI.loadToEditorButton,
    "Load To Editor",
    "Parses the first layout found in the import text and opens it in the visual editor."
)
AttachButtonTooltip(
    loadSelectedToEditorButton,
    "Reset To Saved",
    "Reloads the selected saved layout into the draft planner."
        .. " If the draft has unsaved changes, you will be asked before they are discarded."
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
    "Adds the typed player name to the chosen group in the visual editor."
        .. " Existing entries are moved instead of duplicated."
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
    splitRaidLayoutButton,
    "Split Raid",
    "Builds a role split: one tank in groups 1/2, healers balanced into groups 1/2,"
        .. " and melee/ranged spread across odd/even groups."
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
        leadersUI.listText:SetText("Waiting for saved variables to load...")
        return
    end
    if #ARL.db.preferredLeaders == 0 then
        leadersUI.listText:SetText("No preferred leaders configured. Add one below.")
        return
    end
    local lines = {}
    for i, name in ipairs(ARL.db.preferredLeaders) do
        lines[#lines + 1] = string.format("%d. %s", i, name)
    end
    leadersUI.listText:SetText(table.concat(lines, "\n"))
end

local function RefreshRankListText()
    if not ARL.db then
        guildRanksUI.guildRankListText:SetText("Waiting for saved variables to load...")
        return
    end
    if #ARL.db.guildRankPriority == 0 then
        guildRanksUI.guildRankListText:SetText("No guild ranks configured. Add a rank name below.")
        return
    end
    local lines = {}
    for i, entry in ipairs(ARL.db.guildRankPriority) do
        local name = type(entry) == "table" and entry.name or tostring(entry)
        lines[#lines + 1] = string.format("%d. %s", i, name)
    end
    guildRanksUI.guildRankListText:SetText(table.concat(lines, "\n"))
end

local function RefreshGuildRankButtons()
    for _, btn in ipairs(guildRanksUI.guildRankButtons) do btn:Hide() end
    guildRanksUI.noGuildRanksText:Hide()
    if not IsInGuild() then
        guildRanksUI.noGuildRanksText:SetText("Not in a guild.")
        guildRanksUI.noGuildRanksText:Show()
        return
    end
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    end
    local numRanks = GuildControlGetNumRanks()
    if numRanks == 0 then
        guildRanksUI.noGuildRanksText:SetText("Guild data not yet loaded. Click Refresh.")
        guildRanksUI.noGuildRanksText:Show()
        return
    end
    for i = 1, math.min(numRanks, #guildRanksUI.guildRankButtons) do
        local rankName = GuildControlGetRankName(i)
        if rankName and rankName ~= "" then
            guildRanksUI.guildRankButtons[i]:SetText(rankName)
            guildRanksUI.guildRankButtons[i]._rankIndex = i
            guildRanksUI.guildRankButtons[i]:Show()
        end
    end
end

local function RefreshConsumableListText()
    if not ARL.db then
        consumablesUI.consumableListText:SetText("Waiting for saved variables to load...")
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
    consumablesUI.consumableListText:SetText(table.concat(lines, "\n"))
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

local RANGED_SPEC_IDS = {
    [62] = true, [63] = true, [64] = true,
    [102] = true,
    [258] = true,
    [262] = true,
    [253] = true, [254] = true,
    [1467] = true, [1473] = true,
    [265] = true, [266] = true, [267] = true,
}

local MELEE_SPEC_IDS = {
    [70] = true,
    [71] = true, [72] = true,
    [251] = true, [252] = true,
    [577] = true,
    [103] = true,
    [255] = true,
    [268] = true, [269] = true,
    [263] = true,
    [259] = true, [260] = true, [261] = true,
}

local RANGED_ONLY_CLASSES = {
    MAGE = true,
    PRIEST = true,
    WARLOCK = true,
    EVOKER = true,
}

local MELEE_ONLY_CLASSES = {
    WARRIOR = true,
    DEATHKNIGHT = true,
    ROGUE = true,
    DEMONHUNTER = true,
}

local function ResolveUnitRole(unit)
    local assigned = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
    if assigned ~= "NONE" then
        return assigned
    end

    if unit == "player" and GetSpecialization and GetSpecializationInfo then
        local specIndex = GetSpecialization()
        if specIndex and specIndex > 0 then
            local _, _, _, _, role = GetSpecializationInfo(specIndex)
            if role and role ~= "" then
                return role
            end
        end
    end

    local specID = GetInspectSpecialization and GetInspectSpecialization(unit)
    if specID and specID > 0 and GetSpecializationInfoByID then
        local _, _, _, _, role = GetSpecializationInfoByID(specID)
        if role and role ~= "" then
            return role
        end
    end

    return "NONE"
end

local function ResolveUnitCombatType(unit, classToken, role)
    if role == "TANK" or role == "HEALER" then
        return nil
    end

    local specID = GetInspectSpecialization and GetInspectSpecialization(unit)
    if unit == "player" and GetSpecialization and GetSpecializationInfo then
        local specIndex = GetSpecialization()
        if specIndex and specIndex > 0 then
            local specInfoID = select(1, GetSpecializationInfo(specIndex))
            if specInfoID and specInfoID > 0 then
                specID = specInfoID
            end
        end
    end

    if specID and specID > 0 then
        if RANGED_SPEC_IDS[specID] then
            return "ranged"
        end
        if MELEE_SPEC_IDS[specID] then
            return "melee"
        end
    end

    if classToken and RANGED_ONLY_CLASSES[classToken] then
        return "ranged"
    end
    if classToken and MELEE_ONLY_CLASSES[classToken] then
        return "melee"
    end

    if classToken == "HUNTER" or classToken == "DRUID" or classToken == "SHAMAN" then
        return "ranged"
    end

    if classToken == "PALADIN" or classToken == "MONK" then
        return "melee"
    end

    return nil
end

local function BuildRaidRosterRoleLookup()
    local lookup = {}
    local numMembers = GetNumGroupMembers and GetNumGroupMembers() or 0
    for raidIndex = 1, numMembers do
        local unit = "raid" .. raidIndex
        local name, realm = UnitName(unit)
        if name then
            local fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name
            local _, classToken = UnitClass(unit)
            local role = ResolveUnitRole(unit)
            local info = {
                classToken = classToken,
                role = role,
                combatType = ResolveUnitCombatType(unit, classToken, role),
            }
            lookup[Normalize(fullName):lower()] = info
            lookup[Normalize(name):lower()] = info
            lookup[ShortName(fullName):lower()] = info
        end
    end
    return lookup
end

local function SplitRaidEditorGroups()
    local orderedNames = {}
    for groupIndex = 1, 8 do
        for _, playerName in ipairs(raidEditorState.groups[groupIndex] or {}) do
            orderedNames[#orderedNames + 1] = playerName
        end
    end

    local summary = {
        total = #orderedNames,
        tanks = 0,
        healers = 0,
        melee = 0,
        ranged = 0,
        unknown = 0,
    }

    if #orderedNames == 0 then
        raidEditorDrag = nil
        SetEditorTargetGroup(1)
        return summary
    end

    local rosterLookup = BuildRaidRosterRoleLookup()
    local tanks = {}
    local healers = {}
    local melee = {}
    local ranged = {}
    local unknown = {}

    for _, playerName in ipairs(orderedNames) do
        local cleanName = Normalize(playerName)
        local lowerName = cleanName:lower()
        local shortLower = ShortName(cleanName):lower()
        local info = rosterLookup[lowerName] or rosterLookup[shortLower]
        local role = info and info.role or "NONE"

        if role == "TANK" then
            tanks[#tanks + 1] = playerName
        elseif role == "HEALER" then
            healers[#healers + 1] = playerName
        else
            local combatType = info and info.combatType
            if combatType == "melee" then
                melee[#melee + 1] = playerName
            elseif combatType == "ranged" then
                ranged[#ranged + 1] = playerName
            else
                unknown[#unknown + 1] = playerName
            end
        end
    end

    summary.tanks = #tanks
    summary.healers = #healers
    summary.melee = #melee
    summary.ranged = #ranged
    summary.unknown = #unknown

    local activeGroupCount = math.max(1, math.min(8, math.ceil(#orderedNames / 5)))
    if activeGroupCount >= 3 and (activeGroupCount % 2) == 1 and activeGroupCount < 8 then
        activeGroupCount = activeGroupCount + 1
    end
    local activeGroups = {}
    for groupIndex = 1, activeGroupCount do
        activeGroups[#activeGroups + 1] = groupIndex
    end

    local primaryGroups = { 1 }
    if activeGroupCount >= 2 then
        primaryGroups[#primaryGroups + 1] = 2
    end

    local oddGroups = {}
    local evenGroups = {}
    for _, groupIndex in ipairs(activeGroups) do
        if (groupIndex % 2) == 1 then
            oddGroups[#oddGroups + 1] = groupIndex
        else
            evenGroups[#evenGroups + 1] = groupIndex
        end
    end

    for groupIndex = 1, 8 do
        raidEditorState.groups[groupIndex] = {}
    end

    local sideTargets = {
        odd = math.ceil(#orderedNames / 2),
        even = #orderedNames - math.ceil(#orderedNames / 2),
    }
    local sideCounts = { odd = 0, even = 0 }

    local function AddToGroup(groupIndex, playerName)
        raidEditorState.groups[groupIndex][#raidEditorState.groups[groupIndex] + 1] = playerName
        local side = ((groupIndex % 2) == 1) and "odd" or "even"
        sideCounts[side] = sideCounts[side] + 1
    end

    local function PickFirstOpen(candidates)
        for _, groupIndex in ipairs(candidates or {}) do
            local count = #(raidEditorState.groups[groupIndex] or {})
            if count < 5 then
                return groupIndex
            end
        end
        return nil
    end

    local function ChoosePreferredSide(preferredSide)
        local oddDeficit = sideTargets.odd - sideCounts.odd
        local evenDeficit = sideTargets.even - sideCounts.even

        if preferredSide == "odd" or preferredSide == "even" then
            local preferredDeficit = sideTargets[preferredSide] - sideCounts[preferredSide]
            if preferredDeficit > 0 then
                return preferredSide
            end
        end

        if oddDeficit > evenDeficit then
            return "odd"
        end
        if evenDeficit > oddDeficit then
            return "even"
        end

        if preferredSide == "odd" or preferredSide == "even" then
            return preferredSide
        end
        return "odd"
    end

    local function PickSequentialOpenGroup()
        local preferredSide = ChoosePreferredSide(nil)
        local preferredGroups = preferredSide == "odd" and oddGroups or evenGroups
        local fallbackGroups = preferredSide == "odd" and evenGroups or oddGroups

        local sideGroup = PickFirstOpen(preferredGroups)
        if sideGroup then
            return sideGroup
        end

        sideGroup = PickFirstOpen(fallbackGroups)
        if sideGroup then
            return sideGroup
        end

        for _, groupIndex in ipairs(activeGroups) do
            local count = #(raidEditorState.groups[groupIndex] or {})
            if count < 5 then
                return groupIndex
            end
        end
        return nil
    end

    local function AddToFirstAvailable(candidates, playerName)
        local preferredSide = ChoosePreferredSide(nil)
        local candidatePreferred = {}
        local candidateFallback = {}

        for _, groupIndex in ipairs(candidates or {}) do
            if ((groupIndex % 2) == 1 and preferredSide == "odd")
                or ((groupIndex % 2) == 0 and preferredSide == "even") then
                candidatePreferred[#candidatePreferred + 1] = groupIndex
            else
                candidateFallback[#candidateFallback + 1] = groupIndex
            end
        end

        local groupIndex = PickFirstOpen(candidatePreferred)
        if not groupIndex then
            groupIndex = PickFirstOpen(candidateFallback)
        end
        if not groupIndex then
            groupIndex = PickSequentialOpenGroup()
        end
        if not groupIndex then
            groupIndex = activeGroups[1]
        end
        if not groupIndex then
            groupIndex = 1
        end
        AddToGroup(groupIndex, playerName)
        return groupIndex
    end

    if tanks[1] then
        AddToGroup(1, tanks[1])
    end
    if tanks[2] then
        AddToFirstAvailable(primaryGroups, tanks[2])
    end
    for index = 3, #tanks do
        AddToFirstAvailable(primaryGroups, tanks[index])
    end

    for _, healerName in ipairs(healers) do
        AddToFirstAvailable(primaryGroups, healerName)
    end

    local dpsBalance = {
        melee = { odd = 0, even = 0 },
        ranged = { odd = 0, even = 0 },
        total = { odd = 0, even = 0 },
    }

    local function AddDamager(playerName, kind)
        local oddKindCount = dpsBalance[kind].odd
        local evenKindCount = dpsBalance[kind].even

        local side
        if oddKindCount < evenKindCount then
            side = "odd"
        elseif evenKindCount < oddKindCount then
            side = "even"
        elseif dpsBalance.total.odd <= dpsBalance.total.even then
            side = "odd"
        else
            side = "even"
        end

        local preferredGroups = side == "odd" and oddGroups or evenGroups
        local fallbackGroups = side == "odd" and evenGroups or oddGroups
        local targetGroup = PickFirstOpen(preferredGroups)
            or PickFirstOpen(fallbackGroups)
            or PickSequentialOpenGroup()
            or activeGroups[1]
            or 1

        AddToGroup(targetGroup, playerName)
        local actualSide = ((targetGroup % 2) == 1) and "odd" or "even"
        dpsBalance[kind][actualSide] = dpsBalance[kind][actualSide] + 1
        dpsBalance.total[actualSide] = dpsBalance.total[actualSide] + 1
    end

    local meleeIndex = 1
    local rangedIndex = 1
    while meleeIndex <= #melee or rangedIndex <= #ranged do
        if meleeIndex <= #melee then
            AddDamager(melee[meleeIndex], "melee")
            meleeIndex = meleeIndex + 1
        end
        if rangedIndex <= #ranged then
            AddDamager(ranged[rangedIndex], "ranged")
            rangedIndex = rangedIndex + 1
        end
    end

    for _, unknownName in ipairs(unknown) do
        local assignedMelee = dpsBalance.melee.odd + dpsBalance.melee.even
        local assignedRanged = dpsBalance.ranged.odd + dpsBalance.ranged.even
        local kind = assignedMelee <= assignedRanged and "melee" or "ranged"
        AddDamager(unknownName, kind)
    end

    raidEditorDrag = nil
    SetEditorTargetGroup(1)
    return summary
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
        local unit = "raid" .. raidIndex
        if UnitExists(unit) then
            local name, realm = UnitName(unit)
            local fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name
            local cleanName = Normalize(fullName)
            if cleanName ~= "" then
                local rosterIndex = UnitInRaid and UnitInRaid(unit) or raidIndex
                local subgroup = math.floor(((tonumber(rosterIndex) or raidIndex) - 1) / 5) + 1
                local key = cleanName:lower()
                if not seen[key] then
                    seen[key] = true
                    local targetGroup = math.max(1, math.min(8, tonumber(subgroup) or 1))
                    raidEditorState.groups[targetGroup][#raidEditorState.groups[targetGroup] + 1] = cleanName
                end
            end
        end
    end

    raidEditorDrag = nil
    SetEditorTargetGroup(1)
    raidEditorLoadedKey = nil
    raidEditorHasDraft = true
    return true
end

local raidEditorGuildRosterRequestAt = 0
local RAID_EDITOR_GUILD_ROSTER_THROTTLE = 10

local function RequestGuildRosterForRaidEditorIfStale()
    if not IsInGuild or not IsInGuild() then
        return
    end
    if not (C_GuildInfo and C_GuildInfo.GuildRoster and GetTime) then
        return
    end

    local now = GetTime()
    if (now - raidEditorGuildRosterRequestAt) < RAID_EDITOR_GUILD_ROSTER_THROTTLE then
        return
    end

    C_GuildInfo.GuildRoster()
    raidEditorGuildRosterRequestAt = now
end

local function BuildRosterColorLookup()
    local lookup = {}

    local function AddNameLookupVariants(name, info)
        local cleanName = Normalize(name)
        if cleanName == "" then
            return
        end

        lookup[cleanName:lower()] = info
        lookup[ShortName(cleanName):lower()] = info
    end

    local numMembers = GetNumGroupMembers and GetNumGroupMembers() or 0
    for i = 1, numMembers do
        local unit = "raid" .. i
        local name, realm = UnitName(unit)
        if name then
            local fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name
            local _, classToken = UnitClass(unit)
            local role = ResolveUnitRole(unit)
            local info = { classToken = classToken, role = role }
            AddNameLookupVariants(fullName, info)
            AddNameLookupVariants(name, info)
        end
    end
    local selfName, selfRealm = UnitName("player")
    if selfName then
        local fullSelf = (selfRealm and selfRealm ~= "") and (selfName .. "-" .. selfRealm) or selfName
        local _, classToken = UnitClass("player")
        local role = ResolveUnitRole("player")
        local info = { classToken = classToken, role = role }
        AddNameLookupVariants(fullSelf, info)
        AddNameLookupVariants(selfName, info)
    end

    RequestGuildRosterForRaidEditorIfStale()
    if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
        local guildMemberCount = GetNumGuildMembers() or 0
        for i = 1, guildMemberCount do
            local fullName, _, _, _, _, _, _, _, _, _, classToken = GetGuildRosterInfo(i)
            classToken = tostring(classToken or "")
            if fullName and fullName ~= "" and classToken ~= "" then
                local cleanName = Normalize(fullName)
                local lowerName = cleanName:lower()
                local shortLower = ShortName(cleanName):lower()

                local existing = lookup[lowerName] or lookup[shortLower]
                if existing then
                    if not existing.classToken or existing.classToken == "" then
                        existing.classToken = classToken
                    end
                else
                    local fallbackInfo = { classToken = classToken, role = "NONE" }
                    AddNameLookupVariants(cleanName, fallbackInfo)
                end
            end
        end
    end

    return lookup
end

local function RefreshRaidEditorBoard()
    editorEncounterEdit:SetText(tostring(raidEditorState.encounterID or 0))
    local displayDifficulty = ARL.FormatRaidDifficultyDisplay
        and ARL.FormatRaidDifficultyDisplay(raidEditorState.difficulty or "mythic")
        or tostring(raidEditorState.difficulty or "mythic")
    editorDifficultyEdit:SetText(tostring(displayDifficulty))
    editorNameEdit:SetText(tostring(raidEditorState.name or ""))
    raidGroupsUI.editorGroupValueText:SetText(tostring(raidEditorTargetGroup))

    local rosterColors = BuildRosterColorLookup()

    for groupIndex = 1, 8 do
        local groupList = raidEditorState.groups[groupIndex] or {}
        local groupHeader = raidEditorGroupButtons[groupIndex]
        if groupHeader then
            if raidEditorDrag then
                groupHeader:SetText(string.format("Drop G%d (%d)", groupIndex, #groupList))
            else
                groupHeader:SetText(string.format("Group %d (%d)", groupIndex, #groupList))
            end
            local headerText = groupHeader:GetFontString()
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
                local isDragging = raidEditorDrag
                    and raidEditorDrag.name == name
                    and raidEditorDrag.fromGroup == groupIndex
                if isDragging then
                    btn.Text:SetTextColor(0.95, 0.81, 0.24)
                    if btn.RoleIcon then btn.RoleIcon:Hide() end
                else
                    local cleanName = Normalize(name)
                    local info = rosterColors[cleanName:lower()] or rosterColors[ShortName(cleanName):lower()]
                    if info and info.classToken then
                        local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[info.classToken]
                        if cc then
                            btn.Text:SetTextColor(cc.r, cc.g, cc.b)
                        else
                            btn.Text:SetTextColor(0.90, 0.92, 0.96)
                        end
                        local coords = ROLE_ICON_TEX_COORDS[info.role or ""]
                        if btn.RoleIcon and coords then
                            btn.RoleIcon:SetTexture(ROLE_ICON_TEXTURE)
                            btn.RoleIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                            btn.RoleIcon:Show()
                        elseif btn.RoleIcon then
                            btn.RoleIcon:Hide()
                        end
                    else
                        btn.Text:SetTextColor(0.90, 0.92, 0.96)
                        if btn.RoleIcon then btn.RoleIcon:Hide() end
                    end
                end
                btn:Show()
            else
                if btn.RoleIcon then btn.RoleIcon:Hide() end
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

local function UpdateOptionsKeyboardCapture()
    local shouldCapture = frame:IsShown()
        and panels[6]
        and panels[6]:IsShown()
        and raidEditorDrag
        and raidEditorDrag.name

    frame:EnableKeyboard(shouldCapture and true or false)
end

if panels[6] then
    panels[6]:HookScript("OnShow", UpdateOptionsKeyboardCapture)
    panels[6]:HookScript("OnHide", UpdateOptionsKeyboardCapture)
end

frame:SetScript("OnKeyDown", function(_, key)
    if key ~= "DELETE" and key ~= "BACKSPACE" then
        return
    end

    local focused = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() or nil
    if focused and focused.IsObjectType and focused:IsObjectType("EditBox") then
        return
    end

    if not (panels[6] and panels[6]:IsShown()) then
        return
    end

    if not (raidEditorDrag and raidEditorDrag.name) then
        return
    end

    local removedName = raidEditorDrag.name
    RemoveEditorPlayer(removedName)
    raidEditorDrag = nil
    RefreshRaidEditorBoard()
    UpdateOptionsKeyboardCapture()
    Print("Removed " .. removedName .. " from the draft.")
end)

for groupIndex = 1, 8 do
    local groupHeader = raidEditorGroupButtons[groupIndex]
    if groupHeader then
        groupHeader:SetScript("OnClick", function(self)
            if not raidEditorDrag then
                SetEditorTargetGroup(self._groupIndex)
                return
            end
            local toGroup = self._groupIndex
            local fromGroup = raidEditorDrag.fromGroup
            if toGroup == fromGroup then
                raidEditorDrag = nil
                RefreshRaidEditorBoard()
                UpdateOptionsKeyboardCapture()
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
            UpdateOptionsKeyboardCapture()
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
                UpdateOptionsKeyboardCapture()
                return
            end
            if raidEditorDrag and raidEditorDrag.name == playerName then
                raidEditorDrag = nil
                RefreshRaidEditorBoard()
                UpdateOptionsKeyboardCapture()
                return
            end
            raidEditorDrag = {
                name = playerName,
                fromGroup = self._groupIndex,
            }
            RefreshRaidEditorBoard()
            UpdateOptionsKeyboardCapture()
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

    generalUI.autoCB:SetChecked(ARL.db.autoPromote)
    generalUI.reminderCB:SetChecked(ARL.db.reminderEnabled)
    generalUI.notifyCB:SetChecked(ARL.db.notifyEnabled)
    generalUI.notifySoundCB:SetChecked(ARL.db.notifySound)
    generalUI.quietCB:SetChecked(ARL.db.quietMode)

    local filter = ARL.db.groupTypeFilter or "all"
    local ft = type(filter) == "table" and filter or {}
    generalUI.groupRaidCB:SetChecked(ft.raid and true or false)
    generalUI.groupPartyCB:SetChecked(ft.party and true or false)
    generalUI.groupGuildRaidCB:SetChecked(ft.guild_raid and true or false)
    generalUI.groupGuildPartyCB:SetChecked(ft.guild_party and true or false)

    guildRanksUI.useGuildRankCB:SetChecked(ARL.db.useGuildRankPriority)
    consumablesUI.consumableAuditCB:SetChecked(ARL.db.consumableAuditEnabled)
    deathsUI.deathTrackingCB:SetChecked(ARL.db.deathTrackingEnabled)
    deathsUI.showRecapCB:SetChecked(ARL.db.showRecapOnWipe)
    deathsUI.showRecapOnAnyEndCB:SetChecked(ARL.db.showRecapOnEncounterEnd)
    deathsUI.maxRecapsStoredEdit:SetText(tostring(tonumber(ARL.db.maxDeathRecapsStored) or 20))

    local deathFilter = ARL.db.deathGroupTypeFilter or "raid"
    local dft = type(deathFilter) == "table" and deathFilter or {}
    deathsUI.deathGroupRaidCB:SetChecked(dft.raid and true or false)
    deathsUI.deathGroupPartyCB:SetChecked(dft.party and true or false)
    deathsUI.deathGroupGuildRaidCB:SetChecked(dft.guild_raid and true or false)
    deathsUI.deathGroupGuildPartyCB:SetChecked(dft.guild_party and true or false)

    raidGroupsSettingsUI.raidGroupAutoApplyOnJoinListCB:SetChecked(ARL.db.raidGroupAutoApplyOnJoin == true)
    raidGroupsSettingsUI.raidGroupShowMissingNamesCB:SetChecked(ARL.db.raidGroupShowMissingNames ~= false)
    raidGroupsSettingsUI.raidGroupInviteMissingPlayersCB:SetChecked(ARL.db.raidGroupInviteMissingPlayers == true)

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

generalUI.autoCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.autoPromote = self:GetChecked() and true or false
    Print(string.format("Auto-promote |cff%s%s|r.",
        ARL.db.autoPromote and "00ff00" or "ff0000",
        ARL.db.autoPromote and "enabled" or "disabled"))
end)

generalUI.reminderCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.reminderEnabled = self:GetChecked() and true or false
    if not ARL.db.reminderEnabled and ARL.CancelReminder then ARL:CancelReminder() end
    Print(string.format("Reminder |cff%s%s|r.",
        ARL.db.reminderEnabled and "00ff00" or "ff0000",
        ARL.db.reminderEnabled and "enabled" or "disabled"))
end)

generalUI.notifyCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.notifyEnabled = self:GetChecked() and true or false
    if not ARL.db.notifyEnabled and ARL.HideManualPromotePopup then ARL:HideManualPromotePopup() end
    Print(string.format("Manual-promote popup |cff%s%s|r.",
        ARL.db.notifyEnabled and "00ff00" or "ff0000",
        ARL.db.notifyEnabled and "enabled" or "disabled"))
end)

generalUI.notifySoundCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.notifySound = self:GetChecked() and true or false
    Print(string.format("Manual-promote popup sound |cff%s%s|r.",
        ARL.db.notifySound and "00ff00" or "ff0000",
        ARL.db.notifySound and "enabled" or "disabled"))
end)

generalUI.quietCB:SetScript("OnClick", function(self)
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

generalUI.groupRaidCB:SetScript("OnClick", function()
    if not updating then SetGroupTypeFilter("raid") end
end)
generalUI.groupPartyCB:SetScript("OnClick", function()
    if not updating then SetGroupTypeFilter("party") end
end)
generalUI.groupGuildRaidCB:SetScript("OnClick", function()
    if not updating then SetGroupTypeFilter("guild_raid") end
end)
generalUI.groupGuildPartyCB:SetScript("OnClick", function()
    if not updating then SetGroupTypeFilter("guild_party") end
end)

-- ============================================================
-- Tab 2 – Leaders: handlers
-- ============================================================

leadersUI.addButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local name = Normalize(leadersUI.nameEdit:GetText())
    if name == "" then return end
    for _, existing in ipairs(ARL.db.preferredLeaders) do
        if NamesMatch(existing, name) then
            Print(string.format("|cffffd100%s|r is already in the preferred leaders list.", name))
            return
        end
    end
    table.insert(ARL.db.preferredLeaders, name)
    leadersUI.nameEdit:SetText("")
    RefreshListText()
    Print(string.format("Added |cffffd100%s|r to the preferred leaders list.", name))
end)

leadersUI.removeButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local name = Normalize(leadersUI.nameEdit:GetText())
    if name == "" then Print("Enter a character name to remove.") return end
    for i, existing in ipairs(ARL.db.preferredLeaders) do
        if NamesMatch(existing, name) then
            table.remove(ARL.db.preferredLeaders, i)
            leadersUI.nameEdit:SetText("")
            RefreshListText()
            Print(string.format("Removed |cffffd100%s|r from the preferred leaders list.", existing))
            return
        end
    end
    Print(string.format("|cffffd100%s|r was not found in the preferred leaders list.", name))
end)

leadersUI.clearButton:SetScript("OnClick", function()
    if not ARL.db then return end
    ARL.db.preferredLeaders = {}
    if ARL.CancelReminder then ARL:CancelReminder() end
    if ARL.HideManualPromotePopup then ARL:HideManualPromotePopup() end
    RefreshListText()
    Print("Cleared the preferred leaders list.")
end)

leadersUI.promoteButton:SetScript("OnClick", function()
    if SlashCmdList and SlashCmdList["ASTRALRAIDLEADER"] then
        SlashCmdList["ASTRALRAIDLEADER"]("promote")
    end
end)

leadersUI.moveUpButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local name = Normalize(leadersUI.nameEdit:GetText())
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

leadersUI.moveDownButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local name = Normalize(leadersUI.nameEdit:GetText())
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

leadersUI.nameEdit:SetScript("OnEnterPressed", function() leadersUI.addButton:Click() end)

-- ============================================================
-- Tab 3 – Guild Ranks: handlers
-- ============================================================

guildRanksUI.useGuildRankCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.useGuildRankPriority = self:GetChecked() and true or false
    Print(string.format("Guild rank priority |cff%s%s|r.",
        ARL.db.useGuildRankPriority and "00ff00" or "ff0000",
        ARL.db.useGuildRankPriority and "enabled" or "disabled"))
end)

guildRanksUI.addRankButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local rank = Normalize(guildRanksUI.rankNameEdit:GetText())
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
    guildRanksUI.rankNameEdit:SetText("")
    RefreshRankListText()
    Print(string.format("Added |cffffd100%s|r to the guild rank priority list.", rank))
end)

guildRanksUI.removeRankButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local rank = Normalize(guildRanksUI.rankNameEdit:GetText())
    if rank == "" then Print("Enter a guild rank name to remove.") return end
    for i, existing in ipairs(ARL.db.guildRankPriority) do
        local existingName = type(existing) == "table" and existing.name or tostring(existing)
        if existingName:lower() == rank:lower() then
            table.remove(ARL.db.guildRankPriority, i)
            guildRanksUI.rankNameEdit:SetText("")
            RefreshRankListText()
            Print(string.format("Removed |cffffd100%s|r from the guild rank priority list.", existingName))
            return
        end
    end
    Print(string.format("|cffffd100%s|r was not found in the guild rank priority list.", rank))
end)

guildRanksUI.clearRanksButton:SetScript("OnClick", function()
    if not ARL.db then return end
    ARL.db.guildRankPriority = {}
    RefreshRankListText()
    Print("Cleared the guild rank priority list.")
end)

guildRanksUI.moveRankUpButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local rank = Normalize(guildRanksUI.rankNameEdit:GetText())
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

guildRanksUI.moveRankDownButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local rank = Normalize(guildRanksUI.rankNameEdit:GetText())
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

guildRanksUI.rankNameEdit:SetScript("OnEnterPressed", function()
    guildRanksUI.addRankButton:Click()
end)

guildRanksUI.refreshGuildRanksButton:SetScript("OnClick", function()
    RefreshGuildRankButtons()
end)

for _, btn in ipairs(guildRanksUI.guildRankButtons) do
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

consumablesUI.consumableAuditCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.consumableAuditEnabled = self:GetChecked() and true or false
    Print(string.format("Consumable audit on ready check |cff%s%s|r.",
        ARL.db.consumableAuditEnabled and "00ff00" or "ff0000",
        ARL.db.consumableAuditEnabled and "enabled" or "disabled"))
end)

local FindConsumableCategory = ARL.FindConsumableCategory

consumablesUI.addConsumableButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local label   = Normalize(consumablesUI.catEdit:GetText())
    local spellId = tonumber(consumablesUI.spellIdEdit:GetText())
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
    consumablesUI.spellIdEdit:SetText("")
    RefreshConsumableListText()
end)

consumablesUI.removeSpellIdButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local label   = Normalize(consumablesUI.catEdit:GetText())
    local spellId = tonumber(consumablesUI.spellIdEdit:GetText())
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
            consumablesUI.spellIdEdit:SetText("")
            RefreshConsumableListText()
            return
        end
    end
    Print(string.format("Spell ID %d was not found in |cffffd100%s|r.", spellId, cat.label))
end)

consumablesUI.deleteCatButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local label = Normalize(consumablesUI.catEdit:GetText())
    if label == "" then Print("Enter a category name to delete.") return end
    local idx, cat, isSystem = FindConsumableCategory(label)
    if not cat then Print(string.format("Category |cffffd100%s|r not found.", label)) return end
    if isSystem then
        Print(string.format("|cffffd100%s|r is a built-in category and cannot be deleted.", label))
        return
    end
    table.remove(ARL.db.trackedConsumables, idx)
    consumablesUI.catEdit:SetText("")
    RefreshConsumableListText()
    Print(string.format("Deleted category |cffffd100%s|r.", cat.label))
end)

consumablesUI.clearConsumablesButton:SetScript("OnClick", function()
    if not ARL.db then return end
    ARL.db.trackedConsumables = {}
    RefreshConsumableListText()
    Print("Cleared all custom consumable categories.")
end)

consumablesUI.runAuditButton:SetScript("OnClick", function()
    if ARL.RunConsumableAudit then ARL.RunConsumableAudit(true) end
end)

consumablesUI.catEdit:SetScript("OnEnterPressed", function()
    consumablesUI.spellIdEdit:SetFocus()
end)
consumablesUI.spellIdEdit:SetScript("OnEnterPressed", function()
    consumablesUI.addConsumableButton:Click()
end)

-- ============================================================
-- Tab 5 - Deaths: handlers
-- ============================================================

deathsUI.deathTrackingCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.deathTrackingEnabled = self:GetChecked() and true or false
    Print(string.format("Death tracking |cff%s%s|r.",
        ARL.db.deathTrackingEnabled and "00ff00" or "ff0000",
        ARL.db.deathTrackingEnabled and "enabled" or "disabled"))
end)

deathsUI.showRecapCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.showRecapOnWipe = self:GetChecked() and true or false
    Print(string.format("Auto-open death recap on wipe |cff%s%s|r.",
        ARL.db.showRecapOnWipe and "00ff00" or "ff0000",
        ARL.db.showRecapOnWipe and "enabled" or "disabled"))
end)

deathsUI.showRecapOnAnyEndCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.showRecapOnEncounterEnd = self:GetChecked() and true or false
    Print(string.format("Auto-open death recap on encounter kill |cff%s%s|r.",
        ARL.db.showRecapOnEncounterEnd and "00ff00" or "ff0000",
        ARL.db.showRecapOnEncounterEnd and "enabled" or "disabled"))
end)

local function ApplyMaxDeathRecapHistorySetting()
    if not ARL.db then return end

    local requested = tonumber(Normalize(deathsUI.maxRecapsStoredEdit:GetText() or ""))
    if not requested then
        Print("Enter a valid number between 1 and 200 for recap history size.")
        deathsUI.maxRecapsStoredEdit:SetText(tostring(tonumber(ARL.db.maxDeathRecapsStored) or 20))
        return
    end

    requested = math.floor(requested)
    if requested < 1 then requested = 1 end
    if requested > 200 then requested = 200 end

    ARL.db.maxDeathRecapsStored = requested
    if type(ARL.db.deathRecapHistory) ~= "table" then
        ARL.db.deathRecapHistory = {}
    end
    if #ARL.db.deathRecapHistory > requested then
        for i = #ARL.db.deathRecapHistory, requested + 1, -1 do
            ARL.db.deathRecapHistory[i] = nil
        end
    end

    deathsUI.maxRecapsStoredEdit:SetText(tostring(requested))
    Print(string.format("Max stored death recaps set to |cffffff00%d|r.", requested))
end

deathsUI.applyMaxRecapsStoredButton:SetScript("OnClick", function()
    if updating then return end
    ApplyMaxDeathRecapHistorySetting()
end)

deathsUI.maxRecapsStoredEdit:SetScript("OnEnterPressed", function(self)
    if updating then
        self:ClearFocus()
        return
    end
    ApplyMaxDeathRecapHistorySetting()
    self:ClearFocus()
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

deathsUI.deathGroupRaidCB:SetScript("OnClick", function()
    if not updating then SetDeathGroupTypeFilter("raid") end
end)
deathsUI.deathGroupPartyCB:SetScript("OnClick", function()
    if not updating then SetDeathGroupTypeFilter("party") end
end)
deathsUI.deathGroupGuildRaidCB:SetScript("OnClick", function()
    if not updating then SetDeathGroupTypeFilter("guild_raid") end
end)
deathsUI.deathGroupGuildPartyCB:SetScript("OnClick", function()
    if not updating then SetDeathGroupTypeFilter("guild_party") end
end)

deathsUI.openRecapButton:SetScript("OnClick", function()
    if ARL.ShowDeathRecap then
        ARL:ShowDeathRecap()
    else
        Print("Death recap UI is not available yet. Try again in a moment.")
    end
end)

-- ============================================================
-- Tab 6 - Raid Groups: handlers
-- ============================================================

local raidGroupsLogicBinder = ARL.OptionsBuilders and ARL.OptionsBuilders.BindRaidGroupsLogic
if not raidGroupsLogicBinder then
    Print("Raid Groups logic binder is unavailable; settings window is disabled.")
    return
end

raidGroupsLogicBinder({
    Print = Print,
    Normalize = Normalize,
    BuildProfileFromEditorState = BuildProfileFromEditorState,
    LoadEditorFromProfile = LoadEditorFromProfile,
    RefreshRaidEditorBoard = RefreshRaidEditorBoard,
    RefreshRaidLayoutUI = RefreshRaidLayoutUI,
    LoadEditorFromImportText = LoadEditorFromImportText,
    LoadEditorFromCurrentRaid = LoadEditorFromCurrentRaid,
    ReorganizeRaidEditorGroups = ReorganizeRaidEditorGroups,
    SplitRaidEditorGroups = SplitRaidEditorGroups,
    GetEditorTargetGroup = GetEditorTargetGroup,
    RemoveEditorPlayer = RemoveEditorPlayer,
    SelectSubTab = SelectSubTab,

    raidImportUI = raidImportUI,
    raidGroupsSettingsUI = raidGroupsSettingsUI,
    loadSelectedToEditorButton = loadSelectedToEditorButton,
    editorAddPlayerButton = editorAddPlayerButton,
    editorPlayerEdit = editorPlayerEdit,
    editorEncounterEdit = editorEncounterEdit,
    editorDifficultyEdit = editorDifficultyEdit,
    editorNameEdit = editorNameEdit,
    applyRaidLayoutButton = applyRaidLayoutButton,
    deleteRaidLayoutButton = deleteRaidLayoutButton,
    clearRaidLayoutsButton = clearRaidLayoutsButton,
    newEmptyRaidLayoutButton = newEmptyRaidLayoutButton,
    newFromRaidLayoutButton = newFromRaidLayoutButton,
    reorganizeRaidLayoutButton = reorganizeRaidLayoutButton,
    splitRaidLayoutButton = splitRaidLayoutButton,
    saveNewRaidLayoutButton = saveNewRaidLayoutButton,
    overwriteRaidLayoutButton = overwriteRaidLayoutButton,

    raidEditorState = raidEditorState,
    setRaidEditorLoadedKey = function(value) raidEditorLoadedKey = value end,
    getRaidEditorHasDraft = function() return raidEditorHasDraft end,
    setRaidEditorHasDraft = function(value) raidEditorHasDraft = value end,
    getCurrentMainTabIndex = function() return currentMainTabIndex end,
    isUpdating = function() return updating end,
})

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
