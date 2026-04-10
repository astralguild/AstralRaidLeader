-- AstralRaidLeader_Options_RaidGroupsLogic.lua
-- Binds Raid Groups panel handlers and popups.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

ARL.OptionsBuilders = ARL.OptionsBuilders or {}

function ARL.OptionsBuilders.BindRaidGroupsLogic(deps)
    if not deps then return end

    local Print = deps.Print
    local Normalize = deps.Normalize
    local BuildProfileFromEditorState = deps.BuildProfileFromEditorState
    local LoadEditorFromProfile = deps.LoadEditorFromProfile
    local RefreshRaidEditorBoard = deps.RefreshRaidEditorBoard
    local RefreshRaidLayoutUI = deps.RefreshRaidLayoutUI
    local LoadEditorFromImportText = deps.LoadEditorFromImportText
    local LoadEditorFromCurrentRaid = deps.LoadEditorFromCurrentRaid
    local ReorganizeRaidEditorGroups = deps.ReorganizeRaidEditorGroups
    local SplitRaidEditorGroups = deps.SplitRaidEditorGroups
    local GetEditorTargetGroup = deps.GetEditorTargetGroup
    local RemoveEditorPlayer = deps.RemoveEditorPlayer
    local SelectSubTab = deps.SelectSubTab

    local raidImportUI = deps.raidImportUI
    local raidGroupsSettingsUI = deps.raidGroupsSettingsUI
    local loadSelectedToEditorButton = deps.loadSelectedToEditorButton
    local editorAddPlayerButton = deps.editorAddPlayerButton
    local editorPlayerEdit = deps.editorPlayerEdit
    local editorEncounterEdit = deps.editorEncounterEdit
    local editorDifficultyEdit = deps.editorDifficultyEdit
    local editorNameEdit = deps.editorNameEdit
    local applyRaidLayoutButton = deps.applyRaidLayoutButton
    local deleteRaidLayoutButton = deps.deleteRaidLayoutButton
    local clearRaidLayoutsButton = deps.clearRaidLayoutsButton
    local newEmptyRaidLayoutButton = deps.newEmptyRaidLayoutButton
    local newFromRaidLayoutButton = deps.newFromRaidLayoutButton
    local reorganizeRaidLayoutButton = deps.reorganizeRaidLayoutButton
    local splitRaidLayoutButton = deps.splitRaidLayoutButton
    local saveNewRaidLayoutButton = deps.saveNewRaidLayoutButton
    local overwriteRaidLayoutButton = deps.overwriteRaidLayoutButton

    local raidEditorState = deps.raidEditorState

    local setRaidEditorLoadedKey = deps.setRaidEditorLoadedKey
    local getRaidEditorHasDraft = deps.getRaidEditorHasDraft
    local setRaidEditorHasDraft = deps.setRaidEditorHasDraft

    local getCurrentMainTabIndex = deps.getCurrentMainTabIndex
    local isUpdating = deps.isUpdating

    local function SetRaidLayoutImportText(text)
        raidImportUI.raidImportEdit:SetText(text or "")
        raidImportUI.raidImportEdit:ClearFocus()
        raidImportUI.raidImportScroll:UpdateScrollChildRect()
        raidImportUI.raidImportScroll:SetVerticalScroll(0)
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
            setRaidEditorLoadedKey(result.profile.key)
            setRaidEditorHasDraft(false)
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
                    setRaidEditorLoadedKey(nil)
                    setRaidEditorHasDraft(false)
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
                setRaidEditorLoadedKey(nil)
                setRaidEditorHasDraft(false)
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

        if getRaidEditorHasDraft() and _G.StaticPopup_Show then
            _G.StaticPopup_Show("ASTRALRAIDLEADER_RESET_LAYOUT_DRAFT", label, nil, { profile = active })
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

    raidImportUI.loadToEditorButton:SetScript("OnClick", function()
        local ok, err = LoadEditorFromImportText(raidImportUI.raidImportEdit:GetText())
        if not ok then
            Print(err)
            return
        end
        RefreshRaidEditorBoard()
        if getCurrentMainTabIndex() == 4 then
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

    splitRaidLayoutButton:SetScript("OnClick", function()
        local summary = SplitRaidEditorGroups and SplitRaidEditorGroups()
        RefreshRaidEditorBoard()
        if summary and summary.total and summary.total > 0 then
            local unknownSuffix = ""
            if (summary.unknown or 0) > 0 then
                unknownSuffix = string.format(" (%d unknown role)", summary.unknown or 0)
            end
            Print(string.format(
                "Split draft: %d tank(s), %d healer(s), %d melee, %d ranged%s.",
                summary.tanks or 0,
                summary.healers or 0,
                summary.melee or 0,
                summary.ranged or 0,
                unknownSuffix
            ))
        else
            Print("Split the draft by role across odd/even groups.")
        end
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

    raidImportUI.importRaidLayoutsButton:SetScript("OnClick", function()
        if InCombatLockdown() then
            Print("Cannot import raid layouts while in combat.")
            return
        end
        if not ARL.ImportRaidLayouts then
            Print("Raid layout import is not available yet. Try again in a moment.")
            return
        end

        local ok, result = ARL.ImportRaidLayouts(raidImportUI.raidImportEdit:GetText())
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

        if getCurrentMainTabIndex() == 4 then
            SelectSubTab(1)
        end
    end)

    raidImportUI.clearRaidImportButton:SetScript("OnClick", function()
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

    raidGroupsSettingsUI.raidGroupShowMissingNamesCB:SetScript("OnClick", function(self)
        if isUpdating() or not ARL.db then return end
        ARL.db.raidGroupShowMissingNames = self:GetChecked() and true or false
        Print(string.format(
            "Show missing player names |cff%s%s|r.",
            ARL.db.raidGroupShowMissingNames and "00ff00" or "ff0000",
            ARL.db.raidGroupShowMissingNames and "enabled" or "disabled"
        ))
    end)

    raidGroupsSettingsUI.raidGroupAutoApplyOnJoinListCB:SetScript("OnClick", function(self)
        if isUpdating() or not ARL.db then return end
        ARL.db.raidGroupAutoApplyOnJoin = self:GetChecked() and true or false
        Print(string.format(
            "Auto-apply on join |cff%s%s|r.",
            ARL.db.raidGroupAutoApplyOnJoin and "00ff00" or "ff0000",
            ARL.db.raidGroupAutoApplyOnJoin and "enabled" or "disabled"
        ))
    end)

    raidGroupsSettingsUI.raidGroupInviteMissingPlayersCB:SetScript("OnClick", function(self)
        if isUpdating() or not ARL.db then return end
        ARL.db.raidGroupInviteMissingPlayers = self:GetChecked() and true or false
        Print(string.format(
            "Invite missing listed players on apply |cff%s%s|r.",
            ARL.db.raidGroupInviteMissingPlayers and "00ff00" or "ff0000",
            ARL.db.raidGroupInviteMissingPlayers and "enabled" or "disabled"
        ))
    end)
end
