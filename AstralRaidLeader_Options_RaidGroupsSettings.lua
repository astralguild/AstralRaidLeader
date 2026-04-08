-- AstralRaidLeader_Options_RaidGroupsSettings.lua
-- Modular builder for Raid Groups settings panel (panel 8).

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

ARL.OptionsBuilders = ARL.OptionsBuilders or {}

function ARL.OptionsBuilders.BuildRaidGroupsSettingsPanel(deps)
    local panel = deps and deps.panel
    local CreateCheckbox = deps and deps.CreateCheckbox
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

    return ui
end
