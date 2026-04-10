-- AstralRaidLeader_Options_RaidGroupsLayouts.lua
-- Modular builder for Raid Groups layouts/editor panel (panel 6).

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

ARL.OptionsBuilders = ARL.OptionsBuilders or {}

function ARL.OptionsBuilders.BuildRaidGroupsLayoutsPanel(deps)
    local panel = deps and deps.panel
    local SkinPanel = deps and deps.SkinPanel
    local UIDropDownMenu_SetWidth = deps and deps.UIDropDownMenu_SetWidth
    local UIDropDownMenu_SetText = deps and deps.UIDropDownMenu_SetText
    local ToggleDropDownMenu = deps and deps.ToggleDropDownMenu
    local Print = deps and deps.Print
    if not panel or not SkinPanel then
        return {}
    end

    local ui = {}

    local raidLayoutListLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    raidLayoutListLabel:SetPoint("TOPLEFT", 8, -8)
    raidLayoutListLabel:SetText("Saved raid layout")

    local raidLayoutDropDown = CreateFrame(
        "Frame",
        "AstralRaidLeaderRaidLayoutDropDown",
        panel,
        "UIDropDownMenuTemplate"
    )
    raidLayoutDropDown:SetPoint("TOPLEFT", panel, "TOPLEFT", -8, -24)
    if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(raidLayoutDropDown, 590) end
    if UIDropDownMenu_SetText then UIDropDownMenu_SetText(raidLayoutDropDown, "No saved raid layouts") end
    raidLayoutDropDown:EnableMouse(false)

    local raidLayoutDropDownButton = _G["AstralRaidLeaderRaidLayoutDropDownButton"]
    if raidLayoutDropDownButton then
        raidLayoutDropDownButton:EnableMouse(true)
        raidLayoutDropDownButton:SetHitRectInsets(0, 0, 0, 0)
        raidLayoutDropDownButton:SetScript("OnClick", function()
            if InCombatLockdown() then
                if Print then
                    Print("Cannot change the selected raid layout while in combat.")
                end
                return
            end
            if ToggleDropDownMenu then
                ToggleDropDownMenu(1, nil, raidLayoutDropDown)
            end
        end)
    end

    raidLayoutDropDown:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" and ToggleDropDownMenu and not InCombatLockdown() then
            ToggleDropDownMenu(1, nil, raidLayoutDropDown)
        elseif mouseButton == "LeftButton" and InCombatLockdown() and Print then
            Print("Cannot change the selected raid layout while in combat.")
        end
    end)

    local raidLayoutDropDownText = _G["AstralRaidLeaderRaidLayoutDropDownText"]
    if raidLayoutDropDownText then
        raidLayoutDropDownText:ClearAllPoints()
        raidLayoutDropDownText:SetPoint("LEFT", raidLayoutDropDown, "LEFT", 32, 2)
        raidLayoutDropDownText:SetPoint("RIGHT", raidLayoutDropDown, "RIGHT", -43, 2)
        raidLayoutDropDownText:SetJustifyH("LEFT")
    end

    local applyRaidLayoutButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    applyRaidLayoutButton:SetPoint("TOPLEFT", 8, -64)
    applyRaidLayoutButton:SetSize(112, 24)
    applyRaidLayoutButton:SetText("Apply")

    local deleteRaidLayoutButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    deleteRaidLayoutButton:SetPoint("LEFT", applyRaidLayoutButton, "RIGHT", 10, 0)
    deleteRaidLayoutButton:SetSize(112, 24)
    deleteRaidLayoutButton:SetText("Delete")

    local clearRaidLayoutsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearRaidLayoutsButton:SetPoint("LEFT", deleteRaidLayoutButton, "RIGHT", 10, 0)
    clearRaidLayoutsButton:SetSize(124, 24)
    clearRaidLayoutsButton:SetText("Delete All")

    local raidGroupsUI = {}

    raidGroupsUI.layoutPlanningHelp = panel:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontHighlightSmall"
    )
    raidGroupsUI.layoutPlanningHelp:SetPoint("TOPLEFT", 8, -94)
    raidGroupsUI.layoutPlanningHelp:SetWidth(640)
    raidGroupsUI.layoutPlanningHelp:SetJustifyH("LEFT")
    raidGroupsUI.layoutPlanningHelp:SetText(
        "Start from the selected saved layout, adjust the draft below,"
            .. " then save a new version or overwrite the baseline."
    )

    local raidEditorSection = CreateFrame("Frame", nil, panel)
    raidEditorSection:SetPoint("TOPLEFT", 8, -108)
    raidEditorSection:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, -8)

    raidGroupsUI.editorInset = CreateFrame(
        "Frame",
        nil,
        raidEditorSection,
        BackdropTemplateMixin and "BackdropTemplate" or nil
    )
    raidGroupsUI.editorInset:SetPoint("TOPLEFT", 0, 0)
    raidGroupsUI.editorInset:SetPoint("BOTTOMRIGHT", raidEditorSection, "BOTTOMRIGHT", 0, 0)
    SkinPanel(raidGroupsUI.editorInset, 0.05, 0.09, 0.15, 0.22, 0.22, 0.28, 0.36, 0.18)

    raidGroupsUI.editorHeader = raidEditorSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidGroupsUI.editorHeader:SetPoint("TOPLEFT", 10, -10)
    raidGroupsUI.editorHeader:SetText("Draft planner")

    raidGroupsUI.editorHelp = raidEditorSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    raidGroupsUI.editorHelp:SetPoint("TOPLEFT", 10, -28)
    raidGroupsUI.editorHelp:SetWidth(620)
    raidGroupsUI.editorHelp:SetJustifyH("LEFT")
    raidGroupsUI.editorHelp:SetText(
        "Plan subgroup assignments here. Left-click a player to pick up,"
            .. " click a group header to drop, right-click to remove."
    )

    raidGroupsUI.editorStatusText = raidEditorSection:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    raidGroupsUI.editorStatusText:SetPoint("TOPLEFT", 10, -168)
    raidGroupsUI.editorStatusText:SetWidth(620)
    raidGroupsUI.editorStatusText:SetJustifyH("LEFT")
    raidGroupsUI.editorStatusText:SetText("")

    local raidEditorState = {
        encounterID = 0,
        difficulty = "mythic",
        name = "",
        groups = {},
    }
    for i = 1, 8 do
        raidEditorState.groups[i] = {}
    end

    local raidEditorGroupButtons = {}
    local raidEditorPlayerButtons = {}
    local raidEditorMoreText = {}

    local editorEncounterLabel = raidEditorSection:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    editorEncounterLabel:SetPoint("TOPLEFT", 10, -58)
    editorEncounterLabel:SetText("Encounter")

    local editorEncounterEdit = CreateFrame("EditBox", nil, raidEditorSection, "InputBoxTemplate")
    editorEncounterEdit:SetPoint("LEFT", editorEncounterLabel, "RIGHT", 6, 0)
    editorEncounterEdit:SetSize(58, 22)
    editorEncounterEdit:SetAutoFocus(false)

    local editorDifficultyLabel = raidEditorSection:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    editorDifficultyLabel:SetPoint("LEFT", editorEncounterEdit, "RIGHT", 10, 0)
    editorDifficultyLabel:SetText("Difficulty")

    local editorDifficultyEdit = CreateFrame("EditBox", nil, raidEditorSection, "InputBoxTemplate")
    editorDifficultyEdit:SetPoint("LEFT", editorDifficultyLabel, "RIGHT", 6, 0)
    editorDifficultyEdit:SetSize(68, 22)
    editorDifficultyEdit:SetAutoFocus(false)

    local editorNameLabel = raidEditorSection:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    editorNameLabel:SetPoint("LEFT", editorDifficultyEdit, "RIGHT", 10, 0)
    editorNameLabel:SetText("Name")

    local editorNameEdit = CreateFrame("EditBox", nil, raidEditorSection, "InputBoxTemplate")
    editorNameEdit:SetAutoFocus(false)

    local loadSelectedToEditorButton = CreateFrame("Button", nil, raidEditorSection, "UIPanelButtonTemplate")
    loadSelectedToEditorButton:SetSize(104, 24)
    loadSelectedToEditorButton:SetText("Load Saved")

    editorNameEdit:SetPoint("LEFT", editorNameLabel, "RIGHT", 6, 0)
    editorNameEdit:SetPoint("RIGHT", raidEditorSection, "RIGHT", -116, 0)
    editorNameEdit:SetHeight(22)
    loadSelectedToEditorButton:SetPoint("LEFT", editorNameEdit, "RIGHT", 8, 0)

    local editorPlayerLabel = raidEditorSection:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    editorPlayerLabel:SetPoint("TOPLEFT", 10, -98)
    editorPlayerLabel:SetText("Player")

    local editorPlayerEdit = CreateFrame("EditBox", nil, raidEditorSection, "InputBoxTemplate")
    editorPlayerEdit:SetPoint("LEFT", editorPlayerLabel, "RIGHT", 6, 0)
    editorPlayerEdit:SetSize(144, 22)
    editorPlayerEdit:SetAutoFocus(false)

    local editorGroupLabel = raidEditorSection:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    editorGroupLabel:SetPoint("LEFT", editorPlayerEdit, "RIGHT", 10, 0)
    editorGroupLabel:SetText("Group")

    raidGroupsUI.editorGroupPrevButton = CreateFrame("Button", nil, raidEditorSection, "UIPanelButtonTemplate")
    raidGroupsUI.editorGroupPrevButton:SetPoint("LEFT", editorGroupLabel, "RIGHT", 6, 0)
    raidGroupsUI.editorGroupPrevButton:SetSize(24, 24)
    raidGroupsUI.editorGroupPrevButton:SetText("<")

    raidGroupsUI.editorGroupValueFrame = CreateFrame(
        "Frame",
        nil,
        raidEditorSection,
        BackdropTemplateMixin and "BackdropTemplate" or nil
    )
    raidGroupsUI.editorGroupValueFrame:SetPoint("LEFT", raidGroupsUI.editorGroupPrevButton, "RIGHT", 4, 0)
    raidGroupsUI.editorGroupValueFrame:SetSize(34, 22)
    SkinPanel(raidGroupsUI.editorGroupValueFrame, 0.05, 0.08, 0.12, 0.96, 0.32, 0.41, 0.53, 0.92)

    raidGroupsUI.editorGroupValueText = raidGroupsUI.editorGroupValueFrame:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    raidGroupsUI.editorGroupValueText:SetPoint("CENTER")
    raidGroupsUI.editorGroupValueText:SetText("1")

    raidGroupsUI.editorGroupNextButton = CreateFrame("Button", nil, raidEditorSection, "UIPanelButtonTemplate")
    raidGroupsUI.editorGroupNextButton:SetPoint("LEFT", raidGroupsUI.editorGroupValueFrame, "RIGHT", 4, 0)
    raidGroupsUI.editorGroupNextButton:SetSize(24, 24)
    raidGroupsUI.editorGroupNextButton:SetText(">")

    local editorAddPlayerButton = CreateFrame("Button", nil, raidEditorSection, "UIPanelButtonTemplate")
    editorAddPlayerButton:SetPoint("LEFT", raidGroupsUI.editorGroupNextButton, "RIGHT", 8, 0)
    editorAddPlayerButton:SetSize(54, 24)
    editorAddPlayerButton:SetText("Add")

    local newEmptyRaidLayoutButton = CreateFrame("Button", nil, raidEditorSection, "UIPanelButtonTemplate")
    newEmptyRaidLayoutButton:SetSize(66, 24)
    newEmptyRaidLayoutButton:SetText("Empty")

    local newFromRaidLayoutButton = CreateFrame("Button", nil, raidEditorSection, "UIPanelButtonTemplate")
    newFromRaidLayoutButton:SetSize(88, 24)
    newFromRaidLayoutButton:SetText("From Raid")

    local reorganizeRaidLayoutButton = CreateFrame("Button", nil, raidEditorSection, "UIPanelButtonTemplate")
    reorganizeRaidLayoutButton:SetSize(96, 24)
    reorganizeRaidLayoutButton:SetText("Reorganize")

    local splitRaidLayoutButton = CreateFrame("Button", nil, raidEditorSection, "UIPanelButtonTemplate")
    splitRaidLayoutButton:SetSize(88, 24)
    splitRaidLayoutButton:SetText("Split Raid")

    local saveNewRaidLayoutButton = CreateFrame("Button", nil, raidEditorSection, "UIPanelButtonTemplate")
    saveNewRaidLayoutButton:SetPoint("TOPRIGHT", raidEditorSection, "TOPRIGHT", -110, -74)
    saveNewRaidLayoutButton:SetSize(98, 24)
    saveNewRaidLayoutButton:SetText("Save New")

    local overwriteRaidLayoutButton = CreateFrame("Button", nil, raidEditorSection, "UIPanelButtonTemplate")
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

    splitRaidLayoutButton:ClearAllPoints()
    splitRaidLayoutButton:SetPoint("LEFT", reorganizeRaidLayoutButton, "RIGHT", 10, 0)

    saveNewRaidLayoutButton:ClearAllPoints()
    saveNewRaidLayoutButton:SetPoint("LEFT", splitRaidLayoutButton, "RIGHT", 10, 0)

    local function CreateEditorGroupBox(groupIndex, x, y)
        local groupFrame = CreateFrame(
            "Frame",
            nil,
            raidEditorSection,
            BackdropTemplateMixin and "BackdropTemplate" or nil
        )
        groupFrame:SetPoint("TOPLEFT", x, y)
        groupFrame:SetSize(148, 118)
        SkinPanel(groupFrame, 0.07, 0.10, 0.14, 0.34, 0.22, 0.28, 0.36, 0.24)

        local groupHeader = CreateFrame("Button", nil, groupFrame, "UIPanelButtonTemplate")
        groupHeader:SetPoint("TOPLEFT", 4, -4)
        groupHeader:SetSize(140, 20)
        groupHeader:SetText("Group " .. tostring(groupIndex))
        groupHeader._groupIndex = groupIndex
        raidEditorGroupButtons[groupIndex] = groupHeader

        raidEditorPlayerButtons[groupIndex] = {}
        for slot = 1, 5 do
            local btn = CreateFrame("Button", nil, groupFrame)
            btn:SetPoint("TOPLEFT", 6, -10 - (slot * 15))
            btn:SetSize(134, 14)
            local roleIcon = btn:CreateTexture(nil, "OVERLAY")
            roleIcon:SetSize(10, 10)
            roleIcon:SetPoint("LEFT", btn, "LEFT", 2, 0)
            roleIcon:Hide()
            btn.RoleIcon = roleIcon
            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            txt:SetPoint("LEFT", 14, 0)
            txt:SetJustifyH("LEFT")
            txt:SetJustifyV("MIDDLE")
            txt:SetWordWrap(false)
            txt:SetWidth(118)
            btn.Text = txt
            btn._groupIndex = groupIndex
            btn._slot = slot
            raidEditorPlayerButtons[groupIndex][slot] = btn
        end

        local more = groupFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
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

    ui.raidLayoutDropDown = raidLayoutDropDown
    ui.applyRaidLayoutButton = applyRaidLayoutButton
    ui.deleteRaidLayoutButton = deleteRaidLayoutButton
    ui.clearRaidLayoutsButton = clearRaidLayoutsButton
    ui.raidGroupsUI = raidGroupsUI
    ui.raidEditorState = raidEditorState
    ui.raidEditorGroupButtons = raidEditorGroupButtons
    ui.raidEditorPlayerButtons = raidEditorPlayerButtons
    ui.raidEditorMoreText = raidEditorMoreText
    ui.editorEncounterEdit = editorEncounterEdit
    ui.editorDifficultyEdit = editorDifficultyEdit
    ui.editorNameEdit = editorNameEdit
    ui.loadSelectedToEditorButton = loadSelectedToEditorButton
    ui.editorPlayerEdit = editorPlayerEdit
    ui.editorAddPlayerButton = editorAddPlayerButton
    ui.newEmptyRaidLayoutButton = newEmptyRaidLayoutButton
    ui.newFromRaidLayoutButton = newFromRaidLayoutButton
    ui.reorganizeRaidLayoutButton = reorganizeRaidLayoutButton
    ui.splitRaidLayoutButton = splitRaidLayoutButton
    ui.saveNewRaidLayoutButton = saveNewRaidLayoutButton
    ui.overwriteRaidLayoutButton = overwriteRaidLayoutButton

    return ui
end
