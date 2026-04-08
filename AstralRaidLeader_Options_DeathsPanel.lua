-- AstralRaidLeader_Options_DeathsPanel.lua
-- Modular builder for the Deaths options panel.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

ARL.OptionsBuilders = ARL.OptionsBuilders or {}

function ARL.OptionsBuilders.BuildDeathsPanel(deps)
    local panel = deps and deps.panel
    local CreateCheckbox = deps and deps.CreateCheckbox
    if not panel or not CreateCheckbox then
        return {}
    end

    local ui = {}

    ui.deathTrackingCB = CreateCheckbox(panel,
        "Enable death tracking during encounters",
        "Record raid and party deaths during encounter attempts.",
        8, -8)

    ui.showRecapCB = CreateCheckbox(panel,
        "Open recap window automatically on wipe",
        "Show the Death Recap window automatically when an encounter ends in a wipe.",
        8, -36)

    ui.showRecapOnAnyEndCB = CreateCheckbox(panel,
        "Open recap window on encounter kill",
        "Also open the Death Recap when the encounter ends successfully.",
        8, -64)

    local deathGroupFilterLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    deathGroupFilterLabel:SetPoint("TOPLEFT", 8, -96)
    deathGroupFilterLabel:SetText("Track recap data in:")

    ui.deathGroupRaidCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    ui.deathGroupRaidCB:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -118)
    ui.deathGroupRaidCB.Text:SetText("Raids")
    ui.deathGroupRaidCB.tooltipText = "Track death recap data in any raid group."

    ui.deathGroupPartyCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    ui.deathGroupPartyCB:SetPoint("TOPLEFT", panel, "TOPLEFT", 175, -118)
    ui.deathGroupPartyCB.Text:SetText("Parties")
    ui.deathGroupPartyCB.tooltipText = "Track death recap data in parties (not raids)."

    ui.deathGroupGuildRaidCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    ui.deathGroupGuildRaidCB:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -146)
    ui.deathGroupGuildRaidCB.Text:SetText("Guild Raids")
    ui.deathGroupGuildRaidCB.tooltipText = "Track death recap data in raids that Blizzard marks as guild groups."

    ui.deathGroupGuildPartyCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    ui.deathGroupGuildPartyCB:SetPoint("TOPLEFT", panel, "TOPLEFT", 175, -146)
    ui.deathGroupGuildPartyCB.Text:SetText("Guild Parties")
    ui.deathGroupGuildPartyCB.tooltipText = "Track death recap data in parties that Blizzard marks as guild groups."

    local recapInfoText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    recapInfoText:SetPoint("TOPLEFT", 8, -184)
    recapInfoText:SetWidth(520)
    recapInfoText:SetJustifyH("LEFT")
    recapInfoText:SetText("Use /arl deaths to open the recap at any time.")

    ui.openRecapButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.openRecapButton:SetPoint("TOPLEFT", 8, -214)
    ui.openRecapButton:SetSize(140, 24)
    ui.openRecapButton:SetText("Open Last Recap")

    return ui
end
