-- AstralRaidLeader_Options_General.lua
-- Modular builder for the General options panel.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

ARL.OptionsBuilders = ARL.OptionsBuilders or {}

function ARL.OptionsBuilders.BuildGeneralPanel(deps)
    local panel = deps and deps.panel
    local CreateCheckbox = deps and deps.CreateCheckbox
    if not panel or not CreateCheckbox then
        return {}
    end

    local ui = {}

    ui.autoCB = CreateCheckbox(panel,
        "Enable auto-promote",
        "Automatically promote the highest-priority preferred leader when available.",
        8, -8)

    ui.reminderCB = CreateCheckbox(panel,
        "Enable reminder chat messages",
        "Show reminder messages when members join and no preferred leader is present.",
        8, -36)

    ui.notifyCB = CreateCheckbox(panel,
        "Enable manual-promote popup",
        "Show a popup with a Promote button when auto-promote is disabled and a preferred leader is available.",
        8, -64)

    ui.notifySoundCB = CreateCheckbox(panel,
        "Enable popup sound",
        "Play a sound when the manual-promote popup is shown.",
        8, -92)

    ui.quietCB = CreateCheckbox(panel,
        "Enable quiet mode",
        "Suppress all chat output from AstralRaidLeader (auto-promote still works silently).",
        8, -120)

    local reminderHelpText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    reminderHelpText:SetPoint("TOPLEFT", 8, -160)
    reminderHelpText:SetWidth(528)
    reminderHelpText:SetJustifyH("LEFT")
    reminderHelpText:SetText("Reminders are event-driven and trigger when party/raid roster changes.")

    local groupTypeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    groupTypeLabel:SetPoint("TOPLEFT", 8, -196)
    groupTypeLabel:SetText("Auto-promote in:")

    ui.groupRaidCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    ui.groupRaidCB:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -218)
    ui.groupRaidCB.Text:SetText("Raids")
    ui.groupRaidCB.tooltipText = "Auto-promote when in any raid group."

    ui.groupPartyCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    ui.groupPartyCB:SetPoint("TOPLEFT", panel, "TOPLEFT", 175, -218)
    ui.groupPartyCB.Text:SetText("Parties")
    ui.groupPartyCB.tooltipText = "Auto-promote when in a party (not a raid)."

    ui.groupGuildRaidCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    ui.groupGuildRaidCB:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -246)
    ui.groupGuildRaidCB.Text:SetText("Guild Raids")
    ui.groupGuildRaidCB.tooltipText = "Auto-promote in raids that Blizzard marks as guild groups."

    ui.groupGuildPartyCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    ui.groupGuildPartyCB:SetPoint("TOPLEFT", panel, "TOPLEFT", 175, -246)
    ui.groupGuildPartyCB.Text:SetText("Guild Parties")
    ui.groupGuildPartyCB.tooltipText = "Auto-promote in parties that Blizzard marks as guild groups."

    return ui
end
