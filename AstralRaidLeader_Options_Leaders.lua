-- AstralRaidLeader_Options_Leaders.lua
-- Modular builder for the Leaders options panel.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

ARL.OptionsBuilders = ARL.OptionsBuilders or {}

function ARL.OptionsBuilders.BuildLeadersPanel(deps)
    local panel = deps and deps.panel
    local SkinPanel = deps and deps.SkinPanel
    if not panel or not SkinPanel then
        return {}
    end

    local ui = {}

    local preferredHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    preferredHeader:SetPoint("TOPLEFT", 8, -8)
    preferredHeader:SetText("Preferred leaders (highest priority first)")

    local listInset = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    listInset:SetPoint("TOPLEFT", 8, -28)
    listInset:SetSize(528, 140)
    SkinPanel(listInset, 0.07, 0.10, 0.14, 0.34, 0.22, 0.28, 0.36, 0.24)

    ui.listText = listInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ui.listText:SetPoint("TOPLEFT", 8, -8)
    ui.listText:SetPoint("TOPRIGHT", -8, -8)
    ui.listText:SetJustifyH("LEFT")
    ui.listText:SetJustifyV("TOP")

    local nameLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 8, -178)
    nameLabel:SetText("Character")

    ui.nameEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    ui.nameEdit:SetPoint("TOPLEFT", 8, -198)
    ui.nameEdit:SetSize(180, 24)
    ui.nameEdit:SetAutoFocus(false)
    ui.nameEdit:SetMaxLetters(48)

    ui.addButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.addButton:SetPoint("LEFT", ui.nameEdit, "RIGHT", 10, 0)
    ui.addButton:SetSize(70, 24)
    ui.addButton:SetText("Add")

    ui.removeButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.removeButton:SetPoint("LEFT", ui.addButton, "RIGHT", 8, 0)
    ui.removeButton:SetSize(90, 24)
    ui.removeButton:SetText("Remove")

    ui.clearButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.clearButton:SetPoint("LEFT", ui.removeButton, "RIGHT", 8, 0)
    ui.clearButton:SetSize(70, 24)
    ui.clearButton:SetText("Clear")

    ui.promoteButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.promoteButton:SetPoint("LEFT", ui.clearButton, "RIGHT", 8, 0)
    ui.promoteButton:SetSize(70, 24)
    ui.promoteButton:SetText("Promote")

    ui.moveUpButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.moveUpButton:SetPoint("TOPLEFT", 8, -228)
    ui.moveUpButton:SetSize(90, 24)
    ui.moveUpButton:SetText("Move Up")

    ui.moveDownButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.moveDownButton:SetPoint("LEFT", ui.moveUpButton, "RIGHT", 8, 0)
    ui.moveDownButton:SetSize(100, 24)
    ui.moveDownButton:SetText("Move Down")

    return ui
end
