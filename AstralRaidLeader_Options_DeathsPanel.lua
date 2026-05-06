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
    deathGroupFilterLabel:SetPoint("TOPLEFT", 8, -124)
    deathGroupFilterLabel:SetText("Track recap data in:")

    ui.deathGroupRaidCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    ui.deathGroupRaidCB:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -146)
    ui.deathGroupRaidCB.Text:SetText("Raids")
    ui.deathGroupRaidCB.tooltipText = "Track death recap data in any raid group."

    ui.deathGroupPartyCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    ui.deathGroupPartyCB:SetPoint("TOPLEFT", panel, "TOPLEFT", 175, -146)
    ui.deathGroupPartyCB.Text:SetText("Parties")
    ui.deathGroupPartyCB.tooltipText = "Track death recap data in parties (not raids)."

    ui.deathGroupGuildRaidCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    ui.deathGroupGuildRaidCB:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -174)
    ui.deathGroupGuildRaidCB.Text:SetText("Guild Raids")
    ui.deathGroupGuildRaidCB.tooltipText = "Track death recap data in raids that Blizzard marks as guild groups."

    ui.deathGroupGuildPartyCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    ui.deathGroupGuildPartyCB:SetPoint("TOPLEFT", panel, "TOPLEFT", 175, -174)
    ui.deathGroupGuildPartyCB.Text:SetText("Guild Parties")
    ui.deathGroupGuildPartyCB.tooltipText = "Track death recap data in parties that Blizzard marks as guild groups."

    local maxRecapsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    maxRecapsLabel:SetPoint("TOPLEFT", 8, -212)
    maxRecapsLabel:SetText("Stored recap history size")

    ui.maxRecapsStoredEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    ui.maxRecapsStoredEdit:SetPoint("TOPLEFT", 8, -232)
    ui.maxRecapsStoredEdit:SetSize(78, 24)
    ui.maxRecapsStoredEdit:SetAutoFocus(false)
    ui.maxRecapsStoredEdit:SetMaxLetters(3)

    ui.applyMaxRecapsStoredButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.applyMaxRecapsStoredButton:SetPoint("LEFT", ui.maxRecapsStoredEdit, "RIGHT", 10, 0)
    ui.applyMaxRecapsStoredButton:SetSize(110, 24)
    ui.applyMaxRecapsStoredButton:SetText("Apply")

    local recapInfoText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    recapInfoText:SetPoint("TOPLEFT", 8, -264)
    recapInfoText:SetWidth(520)
    recapInfoText:SetJustifyH("LEFT")
    recapInfoText:SetText("Use /arl deaths or /arl deaths <index> to open stored recaps.")

    ui.openRecapButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.openRecapButton:SetPoint("TOPLEFT", 8, -294)
    ui.openRecapButton:SetSize(140, 24)
    ui.openRecapButton:SetText("Open Latest Recap")

    -- ============================================================
    -- Debug Section
    -- ============================================================
    local debugDivider = panel:CreateTexture(nil, "ARTWORK")
    debugDivider:SetPoint("TOPLEFT", 8, -330)
    debugDivider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -330)
    debugDivider:SetHeight(1)
    debugDivider:SetColorTexture(0.44, 0.54, 0.68, 0.70)

    local debugSectionLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    debugSectionLabel:SetPoint("TOPLEFT", 8, -352)
    debugSectionLabel:SetText("Debug Tools")
    debugSectionLabel:SetTextColor(0.95, 0.81, 0.24)

    ui.deathPayloadDebugCB = CreateCheckbox(panel,
        "Enable post-combat death payload debug capture",
        "Allows you to capture raw C_DamageMeter death payloads after encounters for debugging.",
        8, -374)

    ui.armDeathPayloadDebugButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.armDeathPayloadDebugButton:SetPoint("TOPLEFT", 8, -404)
    ui.armDeathPayloadDebugButton:SetSize(170, 24)
    ui.armDeathPayloadDebugButton:SetText("Arm Debug For Pull")

    ui.dumpDeathPayloadButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.dumpDeathPayloadButton:SetPoint("LEFT", ui.armDeathPayloadDebugButton, "RIGHT", 8, 0)
    ui.dumpDeathPayloadButton:SetSize(170, 24)
    ui.dumpDeathPayloadButton:SetText("View Captured Payload")

    return ui
end
