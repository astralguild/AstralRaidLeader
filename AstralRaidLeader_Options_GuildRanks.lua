-- AstralRaidLeader_Options_GuildRanks.lua
-- Modular builder for the Guild Ranks options panel.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

ARL.OptionsBuilders = ARL.OptionsBuilders or {}

function ARL.OptionsBuilders.BuildGuildRanksPanel(deps)
    local panel = deps and deps.panel
    local CreateCheckbox = deps and deps.CreateCheckbox
    local SkinPanel = deps and deps.SkinPanel
    if not panel or not CreateCheckbox or not SkinPanel then
        return {}
    end

    local ui = {}

    ui.useGuildRankCB = CreateCheckbox(panel,
        "Enable guild rank priority (fallback when no preferred leader is in group)",
        "When no character from the preferred leaders list is present, promote the "
            .. "highest-priority guild rank member instead.",
        8, -8)

    local guildRankListLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    guildRankListLabel:SetPoint("TOPLEFT", 8, -44)
    guildRankListLabel:SetText("Guild rank priority (highest priority first)")

    local guildRankListInset = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    guildRankListInset:SetPoint("TOPLEFT", 8, -64)
    guildRankListInset:SetSize(528, 96)
    SkinPanel(guildRankListInset, 0.07, 0.10, 0.14, 0.34, 0.22, 0.28, 0.36, 0.24)

    ui.guildRankListText = guildRankListInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ui.guildRankListText:SetPoint("TOPLEFT", 8, -8)
    ui.guildRankListText:SetPoint("TOPRIGHT", -8, -8)
    ui.guildRankListText:SetJustifyH("LEFT")
    ui.guildRankListText:SetJustifyV("TOP")

    local rankNameLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rankNameLabel:SetPoint("TOPLEFT", 8, -170)
    rankNameLabel:SetText("Guild Rank")

    ui.rankNameEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    ui.rankNameEdit:SetPoint("TOPLEFT", 8, -190)
    ui.rankNameEdit:SetSize(180, 24)
    ui.rankNameEdit:SetAutoFocus(false)
    ui.rankNameEdit:SetMaxLetters(48)

    ui.addRankButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.addRankButton:SetPoint("LEFT", ui.rankNameEdit, "RIGHT", 10, 0)
    ui.addRankButton:SetSize(70, 24)
    ui.addRankButton:SetText("Add")

    ui.removeRankButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.removeRankButton:SetPoint("LEFT", ui.addRankButton, "RIGHT", 8, 0)
    ui.removeRankButton:SetSize(90, 24)
    ui.removeRankButton:SetText("Remove")

    ui.clearRanksButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.clearRanksButton:SetPoint("LEFT", ui.removeRankButton, "RIGHT", 8, 0)
    ui.clearRanksButton:SetSize(70, 24)
    ui.clearRanksButton:SetText("Clear")

    ui.moveRankUpButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.moveRankUpButton:SetPoint("TOPLEFT", 8, -220)
    ui.moveRankUpButton:SetSize(90, 24)
    ui.moveRankUpButton:SetText("Move Up")

    ui.moveRankDownButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.moveRankDownButton:SetPoint("LEFT", ui.moveRankUpButton, "RIGHT", 8, 0)
    ui.moveRankDownButton:SetSize(100, 24)
    ui.moveRankDownButton:SetText("Move Down")

    local guildRankPickerLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    guildRankPickerLabel:SetPoint("TOPLEFT", 8, -252)
    guildRankPickerLabel:SetText("Available ranks in your guild (click to add):")

    ui.refreshGuildRanksButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.refreshGuildRanksButton:SetPoint("LEFT", guildRankPickerLabel, "RIGHT", 10, 0)
    ui.refreshGuildRanksButton:SetSize(80, 22)
    ui.refreshGuildRanksButton:SetText("Refresh")

    ui.guildRankButtons = {}
    for i = 1, 10 do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", 8 + col * 266, -270 + row * -22)
        btn:SetSize(257, 20)
        btn:SetText("")
        btn:Hide()
        ui.guildRankButtons[i] = btn
    end

    ui.noGuildRanksText = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    ui.noGuildRanksText:SetPoint("TOPLEFT", 8, -274)
    ui.noGuildRanksText:SetText("")
    ui.noGuildRanksText:Hide()

    return ui
end
