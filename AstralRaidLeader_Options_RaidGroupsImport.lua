-- AstralRaidLeader_Options_RaidGroupsImport.lua
-- Modular builder for Raid Groups import panel (panel 7).

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

ARL.OptionsBuilders = ARL.OptionsBuilders or {}

function ARL.OptionsBuilders.BuildRaidGroupsImportPanel(deps)
    local panel = deps and deps.panel
    local SkinPanel = deps and deps.SkinPanel
    if not panel or not SkinPanel then
        return {}
    end

    local ui = {}

    local raidImportHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    raidImportHeader:SetPoint("TOPLEFT", 8, -8)
    raidImportHeader:SetText("Import raid layouts")

    local raidImportHelp = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    raidImportHelp:SetPoint("TOPLEFT", 8, -28)
    raidImportHelp:SetWidth(520)
    raidImportHelp:SetJustifyH("LEFT")
    raidImportHelp:SetText(
        "Paste a raid layout note here, then import it directly"
            .. " or load the first parsed layout into the visual editor."
    )

    local raidImportInset = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    raidImportInset:SetPoint("TOPLEFT", 8, -50)
    raidImportInset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 34)
    SkinPanel(raidImportInset, 0.07, 0.10, 0.14, 0.34, 0.22, 0.28, 0.36, 0.24)

    ui.raidImportScroll = CreateFrame(
        "ScrollFrame",
        "AstralRaidLeaderRaidImportScrollFrame",
        raidImportInset,
        "UIPanelScrollFrameTemplate"
    )
    ui.raidImportScroll:SetPoint("TOPLEFT", 10, -10)
    ui.raidImportScroll:SetPoint("BOTTOMRIGHT", -30, 10)

    local raidImportScrollBar = _G["AstralRaidLeaderRaidImportScrollFrameScrollBar"]
    if raidImportScrollBar then
        raidImportScrollBar:ClearAllPoints()
        raidImportScrollBar:SetPoint("TOPRIGHT", raidImportInset, "TOPRIGHT", -4, -18)
        raidImportScrollBar:SetPoint("BOTTOMRIGHT", raidImportInset, "BOTTOMRIGHT", -4, 18)
    end

    ui.raidImportEdit = CreateFrame("EditBox", nil, ui.raidImportScroll)
    ui.raidImportEdit:SetMultiLine(true)
    ui.raidImportEdit:SetAutoFocus(false)
    ui.raidImportEdit:SetFontObject(_G.ChatFontNormal)
    ui.raidImportEdit:SetWidth(484)
    ui.raidImportEdit:SetHeight(1024)
    ui.raidImportEdit:SetTextInsets(4, 4, 4, 4)
    ui.raidImportEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ui.raidImportEdit:SetScript("OnTextChanged", function()
        ui.raidImportScroll:UpdateScrollChildRect()
    end)
    ui.raidImportEdit:SetScript("OnCursorChanged", function(_, _, y)
        ui.raidImportScroll:SetVerticalScroll(math.max(0, y - 12))
    end)
    ui.raidImportScroll:SetScrollChild(ui.raidImportEdit)

    ui.importRaidLayoutsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.importRaidLayoutsButton:ClearAllPoints()
    ui.importRaidLayoutsButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 2)
    ui.importRaidLayoutsButton:SetSize(100, 24)
    ui.importRaidLayoutsButton:SetText("Import Note")

    ui.clearRaidImportButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.clearRaidImportButton:SetPoint("LEFT", ui.importRaidLayoutsButton, "RIGHT", 8, 0)
    ui.clearRaidImportButton:SetSize(90, 24)
    ui.clearRaidImportButton:SetText("Clear Text")

    ui.loadToEditorButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ui.loadToEditorButton:SetPoint("LEFT", ui.clearRaidImportButton, "RIGHT", 8, 0)
    ui.loadToEditorButton:SetSize(110, 24)
    ui.loadToEditorButton:SetText("Load To Editor")

    return ui
end
