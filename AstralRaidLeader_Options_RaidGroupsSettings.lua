-- AstralRaidLeader_Options_RaidGroupsSettings.lua
-- Modular builder for Raid Groups settings panel (panel 8).

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

ARL.OptionsBuilders = ARL.OptionsBuilders or {}

function ARL.OptionsBuilders.BuildRaidGroupsSettingsPanel(deps)
    local panel = deps and deps.panel
    local CreateCheckbox = deps and deps.CreateCheckbox
    local UIDropDownMenu_SetWidth = deps and deps.UIDropDownMenu_SetWidth
    local UIDropDownMenu_SetText = deps and deps.UIDropDownMenu_SetText
    local ToggleDropDownMenu = deps and deps.ToggleDropDownMenu
    local Print = deps and deps.Print
    local assignmentModeCatalog = deps and deps.assignmentModeCatalog or {}
    if not panel or not CreateCheckbox then
        return {}
    end

    local ui = {}

    local raidGroupSettingsHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    raidGroupSettingsHeader:SetPoint("TOPLEFT", 8, -8)
    raidGroupSettingsHeader:SetText("Raid Group Settings")

    local raidGroupSettingsHelp = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    raidGroupSettingsHelp:SetPoint("TOPLEFT", 8, -28)
    raidGroupSettingsHelp:SetWidth(520)
    raidGroupSettingsHelp:SetJustifyH("LEFT")
    raidGroupSettingsHelp:SetText("These options control apply behavior for saved raid layouts.")

    ui.raidGroupAutoApplyOnJoinListCB = CreateCheckbox(panel,
        "Auto-apply selected layout when a member joins",
        "When enabled, the selected layout is re-applied"
            .. " whenever a new raid member joins.",
        8, -60)

    ui.raidGroupShowMissingNamesCB = CreateCheckbox(panel,
        "Show names of missing players in apply output",
        "When enabled, the apply completion message lists each"
            .. " invited player that was not in the raid.",
        8, -88)

    ui.raidGroupInviteMissingPlayersCB = CreateCheckbox(panel,
        "Invite listed players not already in the raid on apply",
        "When enabled, applying the selected raid layout also"
            .. " invites listed players who are not already in"
            .. " the group.",
        8, -116)

    local assignmentHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    assignmentHeader:SetPoint("TOPLEFT", 8, -154)
    assignmentHeader:SetText("Encounter Assignment Split Modes")

    local assignmentHelp = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    assignmentHelp:SetPoint("TOPLEFT", 8, -174)
    assignmentHelp:SetWidth(620)
    assignmentHelp:SetJustifyH("LEFT")
    assignmentHelp:SetText(
        "Configure assignment handling per supported encounter."
    )

    ui.assignmentModeRows = {}

    local startY = -206
    for index, entry in ipairs(assignmentModeCatalog) do
        local rowY = startY - ((index - 1) * 54)

        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 8, rowY)
        label:SetWidth(620)
        label:SetJustifyH("LEFT")
        label:SetText(entry.encounterLabel or ("Encounter " .. tostring(entry.encounterID or "?")))

        local dropName = string.format("AstralRaidLeaderAssignmentModeDropDown_%d", index)
        local dropDown = CreateFrame("Frame", dropName, panel, "UIDropDownMenuTemplate")
        dropDown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -16, -4)
        if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dropDown, 284) end
        if UIDropDownMenu_SetText then UIDropDownMenu_SetText(dropDown, "Disabled") end
        dropDown:EnableMouse(false)

        local button = _G[dropName .. "Button"]
        if button then
            button:EnableMouse(true)
            button:SetHitRectInsets(0, 0, 0, 0)
            button:SetScript("OnClick", function()
                if InCombatLockdown() then
                    if Print then Print("Cannot change assignment split settings while in combat.") end
                    return
                end
                if ToggleDropDownMenu then
                    ToggleDropDownMenu(1, nil, dropDown)
                end
            end)
        end

        dropDown:SetScript("OnMouseDown", function(_, mouseButton)
            if mouseButton == "LeftButton" and ToggleDropDownMenu and not InCombatLockdown() then
                ToggleDropDownMenu(1, nil, dropDown)
            elseif mouseButton == "LeftButton" and InCombatLockdown() and Print then
                Print("Cannot change assignment split settings while in combat.")
            end
        end)

        local text = _G[dropName .. "Text"]
        if text then
            text:ClearAllPoints()
            text:SetPoint("LEFT", dropDown, "LEFT", 32, 2)
            text:SetPoint("RIGHT", dropDown, "RIGHT", -43, 2)
            text:SetJustifyH("LEFT")
        end

        ui.assignmentModeRows[#ui.assignmentModeRows + 1] = {
            key = entry.key,
            encounterID = entry.encounterID,
            difficultyToken = entry.difficultyToken,
            encounterLabel = entry.encounterLabel,
            defaultMode = entry.defaultMode,
            modes = entry.modes or {},
            label = label,
            dropDown = dropDown,
        }
    end

    if #ui.assignmentModeRows == 0 then
        local noneText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        noneText:SetPoint("TOPLEFT", 8, -206)
        noneText:SetText("No encounters currently support configurable assignment handling.")
    end

    return ui
end
