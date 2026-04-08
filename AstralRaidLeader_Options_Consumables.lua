-- AstralRaidLeader_Options_Consumables.lua
-- Modular builder for the Consumables options panel.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

ARL.OptionsBuilders = ARL.OptionsBuilders or {}

function ARL.OptionsBuilders.BuildConsumablesPanel(deps)
    local panel = deps and deps.panel
    local CreateCheckbox = deps and deps.CreateCheckbox
    local SkinPanel = deps and deps.SkinPanel
    if not panel or not CreateCheckbox or not SkinPanel then
        return {}
    end

    local ui = {}

    ui.consumableAuditCB = CreateCheckbox(panel,
        "Enable consumable audit on ready check",
        "When a ready check is initiated, report which group members are missing tracked consumable buffs.",
        8, -8)

    local consumableListLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    consumableListLabel:SetPoint("TOPLEFT", 8, -44)
    consumableListLabel:SetText("Tracked consumable categories")

    local consumableListInset = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    consumableListInset:SetPoint("TOPLEFT", 8, -64)
    consumableListInset:SetSize(528, 140)
    SkinPanel(consumableListInset, 0.07, 0.10, 0.14, 0.34, 0.22, 0.28, 0.36, 0.24)

    ui.consumableListText = consumableListInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ui.consumableListText:SetPoint("TOPLEFT", 8, -8)
    ui.consumableListText:SetPoint("TOPRIGHT", -8, -8)
    ui.consumableListText:SetJustifyH("LEFT")
    ui.consumableListText:SetJustifyV("TOP")

    local catLabelTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    catLabelTitle:SetPoint("TOPLEFT", 8, -214)
    catLabelTitle:SetText("Category")

    local spellIdTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    spellIdTitle:SetPoint("TOPLEFT", 270, -214)
    spellIdTitle:SetText("Spell ID")

    ui.catEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    ui.catEdit:SetPoint("TOPLEFT", 8, -234)
    ui.catEdit:SetSize(250, 24)
    ui.catEdit:SetAutoFocus(false)
    ui.catEdit:SetMaxLetters(64)

    ui.spellIdEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    ui.spellIdEdit:SetPoint("TOPLEFT", 270, -234)
    ui.spellIdEdit:SetSize(90, 24)
    ui.spellIdEdit:SetAutoFocus(false)
    ui.spellIdEdit:SetMaxLetters(12)

    ui.addConsumableButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.addConsumableButton:SetPoint("TOPLEFT", 8, -266)
    ui.addConsumableButton:SetSize(160, 24)
    ui.addConsumableButton:SetText("Add Spell ID")

    ui.removeSpellIdButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.removeSpellIdButton:SetPoint("LEFT", ui.addConsumableButton, "RIGHT", 10, 0)
    ui.removeSpellIdButton:SetSize(160, 24)
    ui.removeSpellIdButton:SetText("Remove Spell ID")

    ui.deleteCatButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.deleteCatButton:SetPoint("LEFT", ui.removeSpellIdButton, "RIGHT", 10, 0)
    ui.deleteCatButton:SetSize(160, 24)
    ui.deleteCatButton:SetText("Delete Category")

    ui.clearConsumablesButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.clearConsumablesButton:SetPoint("TOPLEFT", 8, -298)
    ui.clearConsumablesButton:SetSize(160, 24)
    ui.clearConsumablesButton:SetText("Clear All")

    ui.runAuditButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.runAuditButton:SetPoint("LEFT", ui.clearConsumablesButton, "RIGHT", 10, 0)
    ui.runAuditButton:SetSize(160, 24)
    ui.runAuditButton:SetText("Run Audit Now")

    return ui
end
