-- AstralRaidLeader_Options.lua
-- Lightweight in-game settings window for AstralRaidLeader.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

local function Print(msg)
    print("|cff00ccff[AstralRaidLeader]|r " .. tostring(msg))
end

local function Normalize(name)
    if not name then return "" end
    return name:match("^%s*(.-)%s*$")
end

local function ShortName(name)
    return (name and (name:match("^([^%-]+)") or name) or "")
end

local function NamesMatch(a, b)
    local al = (a or ""):lower()
    local bl = (b or ""):lower()
    if al == bl then return true end
    return ShortName(al) == ShortName(bl)
end

local frame = CreateFrame("Frame", "AstralRaidLeaderOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(560, 500)
frame:SetPoint("CENTER")
frame:SetClampedToScreen(true)
frame:SetFrameStrata("DIALOG")
frame:SetFrameLevel(100)
frame:SetToplevel(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:Hide()

if frame.TitleText then
    frame.TitleText:SetText("AstralRaidLeader Settings")
end

local dragRegion = CreateFrame("Frame", nil, frame)
dragRegion:SetPoint("TOPLEFT", 8, -6)
dragRegion:SetPoint("TOPRIGHT", -28, -6)
dragRegion:SetHeight(22)
dragRegion:EnableMouse(true)
dragRegion:RegisterForDrag("LeftButton")
dragRegion:SetScript("OnDragStart", function() frame:StartMoving() end)
dragRegion:SetScript("OnDragStop",  function() frame:StopMovingOrSizing() end)

table.insert(UISpecialFrames, frame:GetName())

local updating = false

-- ============================================================
-- Tab panels
-- Each panel is a child of the main frame occupying the content
-- area below the title/tab bar, leaving room for the Close button.
-- ============================================================

local function CreatePanel()
    local p = CreateFrame("Frame", nil, frame)
    p:SetPoint("TOPLEFT",     frame, "TOPLEFT",      8,  -32)
    p:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",  -8,  44)
    p:Hide()
    return p
end

local panels = {
    CreatePanel(),  -- 1: General
    CreatePanel(),  -- 2: Leaders
    CreatePanel(),  -- 3: Guild Ranks
    CreatePanel(),  -- 4: Consumables
    CreatePanel(),  -- 5: Deaths
}

-- ============================================================
-- Tab buttons (PanelTabButtonTemplate)
-- Names must be frame:GetName().."Tab"..i for PanelTemplates_* to work.
-- ============================================================

local TAB_LABELS = { "General", "Leaders", "Guild Ranks", "Consumables", "Deaths" }
local tabs = {}
local currentTabIndex = 0  -- tracked locally; PanelTemplates_SetSelectedTab removed in 12.x

local function SelectTab(index)
    for i, panel in ipairs(panels) do
        if i == index then panel:Show() else panel:Hide() end
    end
    currentTabIndex = index
    frame.selectedTab = index
    for i, tab in ipairs(tabs) do
        if PanelTemplates_SelectTab and PanelTemplates_DeselectTab then
            if i == index then PanelTemplates_SelectTab(tab)
            else PanelTemplates_DeselectTab(tab) end
        end
    end
end

for i, label in ipairs(TAB_LABELS) do
    local tab = CreateFrame("Button", frame:GetName() .. "Tab" .. i, frame, "PanelTabButtonTemplate")
    tab:SetText(label)
    if i == 1 then
        tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 4, 2)
    else
        tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", -14, 0)
    end
    tab:SetID(i)
    tab:SetScript("OnClick", function(self) SelectTab(self:GetID()) end)
    PanelTemplates_TabResize(tab, 0)
    tabs[i] = tab
end

PanelTemplates_SetNumTabs(frame, #TAB_LABELS)

-- ============================================================
-- Helper: create a checkbox parented to the given panel frame.
-- ============================================================

local function CreateCheckbox(parent, label, tooltip, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(label)
    if tooltip then cb.tooltipText = tooltip end
    return cb
end

-- ============================================================
-- Close button (always visible on the main frame)
-- ============================================================

local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
closeButton:SetPoint("BOTTOMRIGHT", -12, 12)
closeButton:SetSize(100, 24)
closeButton:SetText("Close")
closeButton:SetScript("OnClick", function() frame:Hide() end)

-- ============================================================
-- Tab 1 – General
-- ============================================================

local p1 = panels[1]

local autoCB = CreateCheckbox(p1,
    "Enable auto-promote",
    "Automatically promote the highest-priority preferred leader when available.",
    8, -8)

local reminderCB = CreateCheckbox(p1,
    "Enable reminder chat messages",
    "Show reminder messages when members join and no preferred leader is present.",
    8, -36)

local notifyCB = CreateCheckbox(p1,
    "Enable manual-promote popup",
    "Show a popup with a Promote button when auto-promote is disabled and a preferred leader is available.",
    8, -64)

local notifySoundCB = CreateCheckbox(p1,
    "Enable popup sound",
    "Play a sound when the manual-promote popup is shown.",
    8, -92)

local quietCB = CreateCheckbox(p1,
    "Enable quiet mode",
    "Suppress all chat output from AstralRaidLeader (auto-promote still works silently).",
    8, -120)

local reminderHelpText = p1:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
reminderHelpText:SetPoint("TOPLEFT", 8, -160)
reminderHelpText:SetWidth(528)
reminderHelpText:SetJustifyH("LEFT")
reminderHelpText:SetText("Reminders are event-driven and trigger when party/raid roster changes.")

local groupTypeLabel = p1:CreateFontString(nil, "ARTWORK", "GameFontNormal")
groupTypeLabel:SetPoint("TOPLEFT", 8, -196)
groupTypeLabel:SetText("Auto-promote in:")

local groupAllCB = CreateCheckbox(p1,
    "All groups",
    "Auto-promote in both raids and parties.",
    8, -218)

local groupRaidCB = CreateFrame("CheckButton", nil, p1, "InterfaceOptionsCheckButtonTemplate")
groupRaidCB:SetPoint("TOPLEFT", p1, "TOPLEFT", 140, -218)
groupRaidCB.Text:SetText("Raids only")
groupRaidCB.tooltipText = "Only auto-promote when in a raid group."

local groupPartyCB = CreateFrame("CheckButton", nil, p1, "InterfaceOptionsCheckButtonTemplate")
groupPartyCB:SetPoint("TOPLEFT", p1, "TOPLEFT", 270, -218)
groupPartyCB.Text:SetText("Parties only")
groupPartyCB.tooltipText = "Only auto-promote when in a party (not a raid)."

-- ============================================================
-- Tab 2 – Leaders
-- ============================================================

local p2 = panels[2]

local preferredHeader = p2:CreateFontString(nil, "ARTWORK", "GameFontNormal")
preferredHeader:SetPoint("TOPLEFT", 8, -8)
preferredHeader:SetText("Preferred leaders (highest priority first)")

local listInset = CreateFrame("Frame", nil, p2, "InsetFrameTemplate3")
listInset:SetPoint("TOPLEFT", 8, -28)
listInset:SetSize(528, 140)

local listText = listInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
listText:SetPoint("TOPLEFT", 8, -8)
listText:SetPoint("TOPRIGHT", -8, -8)
listText:SetJustifyH("LEFT")
listText:SetJustifyV("TOP")

local nameLabel = p2:CreateFontString(nil, "ARTWORK", "GameFontNormal")
nameLabel:SetPoint("TOPLEFT", 8, -178)
nameLabel:SetText("Character")

local nameEdit = CreateFrame("EditBox", nil, p2, "InputBoxTemplate")
nameEdit:SetPoint("TOPLEFT", 8, -198)
nameEdit:SetSize(180, 24)
nameEdit:SetAutoFocus(false)
nameEdit:SetMaxLetters(48)

local addButton = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
addButton:SetPoint("LEFT", nameEdit, "RIGHT", 10, 0)
addButton:SetSize(70, 24)
addButton:SetText("Add")

local removeButton = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
removeButton:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
removeButton:SetSize(90, 24)
removeButton:SetText("Remove")

local clearButton = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
clearButton:SetPoint("LEFT", removeButton, "RIGHT", 8, 0)
clearButton:SetSize(70, 24)
clearButton:SetText("Clear")

local promoteButton = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
promoteButton:SetPoint("LEFT", clearButton, "RIGHT", 8, 0)
promoteButton:SetSize(70, 24)
promoteButton:SetText("Promote")

local moveUpButton = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
moveUpButton:SetPoint("TOPLEFT", 8, -228)
moveUpButton:SetSize(90, 24)
moveUpButton:SetText("Move Up")

local moveDownButton = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
moveDownButton:SetPoint("LEFT", moveUpButton, "RIGHT", 8, 0)
moveDownButton:SetSize(100, 24)
moveDownButton:SetText("Move Down")

-- ============================================================
-- Tab 3 – Guild Ranks
-- ============================================================

local p3 = panels[3]

local useGuildRankCB = CreateCheckbox(p3,
    "Enable guild rank priority (fallback when no preferred leader is in group)",
    "When no character from the preferred leaders list is present, promote the "
    .. "highest-priority guild rank member instead.",
    8, -8)

local guildRankListLabel = p3:CreateFontString(nil, "ARTWORK", "GameFontNormal")
guildRankListLabel:SetPoint("TOPLEFT", 8, -44)
guildRankListLabel:SetText("Guild rank priority (highest priority first)")

local guildRankListInset = CreateFrame("Frame", nil, p3, "InsetFrameTemplate3")
guildRankListInset:SetPoint("TOPLEFT", 8, -64)
guildRankListInset:SetSize(528, 120)

local guildRankListText = guildRankListInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
guildRankListText:SetPoint("TOPLEFT", 8, -8)
guildRankListText:SetPoint("TOPRIGHT", -8, -8)
guildRankListText:SetJustifyH("LEFT")
guildRankListText:SetJustifyV("TOP")

local rankNameLabel = p3:CreateFontString(nil, "ARTWORK", "GameFontNormal")
rankNameLabel:SetPoint("TOPLEFT", 8, -194)
rankNameLabel:SetText("Guild Rank")

local rankNameEdit = CreateFrame("EditBox", nil, p3, "InputBoxTemplate")
rankNameEdit:SetPoint("TOPLEFT", 8, -214)
rankNameEdit:SetSize(180, 24)
rankNameEdit:SetAutoFocus(false)
rankNameEdit:SetMaxLetters(48)

local addRankButton = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
addRankButton:SetPoint("LEFT", rankNameEdit, "RIGHT", 10, 0)
addRankButton:SetSize(70, 24)
addRankButton:SetText("Add")

local removeRankButton = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
removeRankButton:SetPoint("LEFT", addRankButton, "RIGHT", 8, 0)
removeRankButton:SetSize(90, 24)
removeRankButton:SetText("Remove")

local clearRanksButton = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
clearRanksButton:SetPoint("LEFT", removeRankButton, "RIGHT", 8, 0)
clearRanksButton:SetSize(70, 24)
clearRanksButton:SetText("Clear")

local moveRankUpButton = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
moveRankUpButton:SetPoint("TOPLEFT", 8, -244)
moveRankUpButton:SetSize(90, 24)
moveRankUpButton:SetText("Move Up")

local moveRankDownButton = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
moveRankDownButton:SetPoint("LEFT", moveRankUpButton, "RIGHT", 8, 0)
moveRankDownButton:SetSize(100, 24)
moveRankDownButton:SetText("Move Down")

local guildRankPickerLabel = p3:CreateFontString(nil, "ARTWORK", "GameFontNormal")
guildRankPickerLabel:SetPoint("TOPLEFT", 8, -278)
guildRankPickerLabel:SetText("Available ranks in your guild (click to add):")

local refreshGuildRanksButton = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
refreshGuildRanksButton:SetPoint("LEFT", guildRankPickerLabel, "RIGHT", 10, 0)
refreshGuildRanksButton:SetSize(80, 22)
refreshGuildRanksButton:SetText("Refresh")

-- Pool of up to 10 clickable rank buttons (2 columns x 5 rows)
local MAX_RANK_BUTTONS = 10
local guildRankButtons = {}
for _i = 1, MAX_RANK_BUTTONS do
    local col = (_i - 1) % 2
    local row = math.floor((_i - 1) / 2)
    local btn = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", 8 + col * 266, -300 + row * -28)
    btn:SetSize(257, 22)
    btn:SetText("")
    btn:Hide()
    guildRankButtons[_i] = btn
end

local noGuildRanksText = p3:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
noGuildRanksText:SetPoint("TOPLEFT", 8, -304)
noGuildRanksText:SetText("")
noGuildRanksText:Hide()

-- ============================================================
-- Tab 4 – Consumables
-- ============================================================

local p4 = panels[4]

local consumableAuditCB = CreateCheckbox(p4,
    "Enable consumable audit on ready check",
    "When a ready check is initiated, report which group members are missing tracked consumable buffs.",
    8, -8)

local consumableListLabel = p4:CreateFontString(nil, "ARTWORK", "GameFontNormal")
consumableListLabel:SetPoint("TOPLEFT", 8, -44)
consumableListLabel:SetText("Tracked consumable categories")

local consumableListInset = CreateFrame("Frame", nil, p4, "InsetFrameTemplate3")
consumableListInset:SetPoint("TOPLEFT", 8, -64)
consumableListInset:SetSize(528, 140)

local consumableListText = consumableListInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
consumableListText:SetPoint("TOPLEFT", 8, -8)
consumableListText:SetPoint("TOPRIGHT", -8, -8)
consumableListText:SetJustifyH("LEFT")
consumableListText:SetJustifyV("TOP")

local catLabelTitle = p4:CreateFontString(nil, "ARTWORK", "GameFontNormal")
catLabelTitle:SetPoint("TOPLEFT", 8, -214)
catLabelTitle:SetText("Category")

local spellIdTitle = p4:CreateFontString(nil, "ARTWORK", "GameFontNormal")
spellIdTitle:SetPoint("TOPLEFT", 196, -214)
spellIdTitle:SetText("Spell ID")

local catEdit = CreateFrame("EditBox", nil, p4, "InputBoxTemplate")
catEdit:SetPoint("TOPLEFT", 8, -234)
catEdit:SetSize(180, 24)
catEdit:SetAutoFocus(false)
catEdit:SetMaxLetters(64)

local spellIdEdit = CreateFrame("EditBox", nil, p4, "InputBoxTemplate")
spellIdEdit:SetPoint("TOPLEFT", 196, -234)
spellIdEdit:SetSize(100, 24)
spellIdEdit:SetAutoFocus(false)
spellIdEdit:SetMaxLetters(12)

local addConsumableButton = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
addConsumableButton:SetPoint("LEFT", spellIdEdit, "RIGHT", 10, 0)
addConsumableButton:SetSize(90, 24)
addConsumableButton:SetText("Add Spell ID")

local removeSpellIdButton = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
removeSpellIdButton:SetPoint("LEFT", addConsumableButton, "RIGHT", 6, 0)
removeSpellIdButton:SetSize(110, 24)
removeSpellIdButton:SetText("Remove Spell ID")

local deleteCatButton = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
deleteCatButton:SetPoint("TOPLEFT", 8, -264)
deleteCatButton:SetSize(110, 24)
deleteCatButton:SetText("Delete Category")

local clearConsumablesButton = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
clearConsumablesButton:SetPoint("LEFT", deleteCatButton, "RIGHT", 8, 0)
clearConsumablesButton:SetSize(80, 24)
clearConsumablesButton:SetText("Clear All")

local runAuditButton = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
runAuditButton:SetPoint("LEFT", clearConsumablesButton, "RIGHT", 8, 0)
runAuditButton:SetSize(110, 24)
runAuditButton:SetText("Run Audit Now")

-- ============================================================
-- Tab 5 - Deaths
-- ============================================================

local p5 = panels[5]

local deathTrackingCB = CreateCheckbox(p5,
    "Enable death tracking during encounters",
    "Record raid and party deaths during encounter attempts.",
    8, -8)

local showRecapCB = CreateCheckbox(p5,
    "Open recap window automatically on wipe",
    "Show the Death Recap window automatically when an encounter ends in a wipe.",
    8, -36)

local recapInfoText = p5:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
recapInfoText:SetPoint("TOPLEFT", 8, -70)
recapInfoText:SetWidth(520)
recapInfoText:SetJustifyH("LEFT")
recapInfoText:SetText("Use /arl deaths to open the recap at any time.")

local openRecapButton = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
openRecapButton:SetPoint("TOPLEFT", 8, -100)
openRecapButton:SetSize(140, 24)
openRecapButton:SetText("Open Last Recap")

-- ============================================================
-- Refresh helpers
-- ============================================================

local function RefreshListText()
    if not ARL.db then
        listText:SetText("Waiting for saved variables to load...")
        return
    end
    if #ARL.db.preferredLeaders == 0 then
        listText:SetText("No preferred leaders configured. Add one below.")
        return
    end
    local lines = {}
    for i, name in ipairs(ARL.db.preferredLeaders) do
        lines[#lines + 1] = string.format("%d. %s", i, name)
    end
    listText:SetText(table.concat(lines, "\n"))
end

local function RefreshRankListText()
    if not ARL.db then
        guildRankListText:SetText("Waiting for saved variables to load...")
        return
    end
    if #ARL.db.guildRankPriority == 0 then
        guildRankListText:SetText("No guild ranks configured. Add a rank name below.")
        return
    end
    local lines = {}
    for i, rank in ipairs(ARL.db.guildRankPriority) do
        lines[#lines + 1] = string.format("%d. %s", i, rank)
    end
    guildRankListText:SetText(table.concat(lines, "\n"))
end

local function RefreshGuildRankButtons()
    for _, btn in ipairs(guildRankButtons) do btn:Hide() end
    noGuildRanksText:Hide()
    if not IsInGuild() then
        noGuildRanksText:SetText("Not in a guild.")
        noGuildRanksText:Show()
        return
    end
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
    local numRanks = GuildControlGetNumRanks()
    if numRanks == 0 then
        noGuildRanksText:SetText("Guild data not yet loaded. Click Refresh.")
        noGuildRanksText:Show()
        return
    end
    for i = 1, math.min(numRanks, MAX_RANK_BUTTONS) do
        local rankName = GuildControlGetRankName(i)
        if rankName and rankName ~= "" then
            guildRankButtons[i]:SetText(rankName)
            guildRankButtons[i]:Show()
        end
    end
end

local function RefreshConsumableListText()
    if not ARL.db then
        consumableListText:SetText("Waiting for saved variables to load...")
        return
    end
    local lines = {}
    local sys = ARL.SYSTEM_CONSUMABLES or {}
    lines[#lines + 1] = "|cffffff00System (built-in):|r"
    if #sys > 0 then
        for _, cat in ipairs(sys) do
            local parts = {}
            if #cat.spellIds > 0 then
                parts[#parts + 1] = "IDs: " .. table.concat(cat.spellIds, ", ")
            end
            if cat.namePatterns and #cat.namePatterns > 0 then
                parts[#parts + 1] = 'names: "' .. table.concat(cat.namePatterns, '", "') .. '"'
            end
            lines[#lines + 1] = string.format("  %s - %s",
                cat.label, #parts > 0 and table.concat(parts, "; ") or "(empty)")
        end
    else
        lines[#lines + 1] = "  (none)"
    end
    lines[#lines + 1] = "|cffffff00Custom:|r"
    if #ARL.db.trackedConsumables > 0 then
        for i, cat in ipairs(ARL.db.trackedConsumables) do
            local parts = {}
            if #cat.spellIds > 0 then
                parts[#parts + 1] = "IDs: " .. table.concat(cat.spellIds, ", ")
            end
            if cat.namePatterns and #cat.namePatterns > 0 then
                parts[#parts + 1] = 'names: "' .. table.concat(cat.namePatterns, '", "') .. '"'
            end
            lines[#lines + 1] = string.format("  %d. %s - %s",
                i, cat.label, #parts > 0 and table.concat(parts, "; ") or "(empty)")
        end
    else
        lines[#lines + 1] = "  No custom categories. Add one below."
    end
    consumableListText:SetText(table.concat(lines, "\n"))
end

local function RefreshUI()
    if not ARL.db then return end

    updating = true

    autoCB:SetChecked(ARL.db.autoPromote)
    reminderCB:SetChecked(ARL.db.reminderEnabled)
    notifyCB:SetChecked(ARL.db.notifyEnabled)
    notifySoundCB:SetChecked(ARL.db.notifySound)
    quietCB:SetChecked(ARL.db.quietMode)

    local filter = ARL.db.groupTypeFilter or "all"
    groupAllCB:SetChecked(filter == "all")
    groupRaidCB:SetChecked(filter == "raid")
    groupPartyCB:SetChecked(filter == "party")

    useGuildRankCB:SetChecked(ARL.db.useGuildRankPriority)
    consumableAuditCB:SetChecked(ARL.db.consumableAuditEnabled)
    deathTrackingCB:SetChecked(ARL.db.deathTrackingEnabled)
    showRecapCB:SetChecked(ARL.db.showRecapOnWipe)

    RefreshListText()
    RefreshRankListText()
    RefreshConsumableListText()
    RefreshGuildRankButtons()

    updating = false
end

-- ============================================================
-- Tab 1 – General: handlers
-- ============================================================

autoCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.autoPromote = self:GetChecked() and true or false
    Print(string.format("Auto-promote |cff%s%s|r.",
        ARL.db.autoPromote and "00ff00" or "ff0000",
        ARL.db.autoPromote and "enabled" or "disabled"))
end)

reminderCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.reminderEnabled = self:GetChecked() and true or false
    if not ARL.db.reminderEnabled and ARL.CancelReminder then ARL:CancelReminder() end
    Print(string.format("Reminder |cff%s%s|r.",
        ARL.db.reminderEnabled and "00ff00" or "ff0000",
        ARL.db.reminderEnabled and "enabled" or "disabled"))
end)

notifyCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.notifyEnabled = self:GetChecked() and true or false
    if not ARL.db.notifyEnabled and ARL.HideManualPromotePopup then ARL:HideManualPromotePopup() end
    Print(string.format("Manual-promote popup |cff%s%s|r.",
        ARL.db.notifyEnabled and "00ff00" or "ff0000",
        ARL.db.notifyEnabled and "enabled" or "disabled"))
end)

notifySoundCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.notifySound = self:GetChecked() and true or false
    Print(string.format("Manual-promote popup sound |cff%s%s|r.",
        ARL.db.notifySound and "00ff00" or "ff0000",
        ARL.db.notifySound and "enabled" or "disabled"))
end)

quietCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.quietMode = self:GetChecked() and true or false
    if ARL.db.quietMode then
        Print("Quiet mode |cff00ff00enabled|r. Chat output suppressed.")
    else
        Print("Quiet mode |cffff0000disabled|r.")
    end
end)

local function SetGroupTypeFilter(filter)
    if not ARL.db then return end
    ARL.db.groupTypeFilter = filter
    groupAllCB:SetChecked(filter == "all")
    groupRaidCB:SetChecked(filter == "raid")
    groupPartyCB:SetChecked(filter == "party")
    local labels = { all = "all groups", raid = "raids only", party = "parties only" }
    Print(string.format("Group type filter set to |cffffff00%s|r.", labels[filter]))
end

groupAllCB:SetScript("OnClick",  function() if not updating then SetGroupTypeFilter("all")   end end)
groupRaidCB:SetScript("OnClick", function() if not updating then SetGroupTypeFilter("raid")  end end)
groupPartyCB:SetScript("OnClick",function() if not updating then SetGroupTypeFilter("party") end end)

-- ============================================================
-- Tab 2 – Leaders: handlers
-- ============================================================

addButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local name = Normalize(nameEdit:GetText())
    if name == "" then return end
    for _, existing in ipairs(ARL.db.preferredLeaders) do
        if NamesMatch(existing, name) then
            Print(string.format("|cffffd100%s|r is already in the preferred leaders list.", name))
            return
        end
    end
    table.insert(ARL.db.preferredLeaders, name)
    nameEdit:SetText("")
    RefreshListText()
    Print(string.format("Added |cffffd100%s|r to the preferred leaders list.", name))
end)

removeButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local name = Normalize(nameEdit:GetText())
    if name == "" then Print("Enter a character name to remove.") return end
    for i, existing in ipairs(ARL.db.preferredLeaders) do
        if NamesMatch(existing, name) then
            table.remove(ARL.db.preferredLeaders, i)
            nameEdit:SetText("")
            RefreshListText()
            Print(string.format("Removed |cffffd100%s|r from the preferred leaders list.", existing))
            return
        end
    end
    Print(string.format("|cffffd100%s|r was not found in the preferred leaders list.", name))
end)

clearButton:SetScript("OnClick", function()
    if not ARL.db then return end
    ARL.db.preferredLeaders = {}
    if ARL.CancelReminder then ARL:CancelReminder() end
    if ARL.HideManualPromotePopup then ARL:HideManualPromotePopup() end
    RefreshListText()
    Print("Cleared the preferred leaders list.")
end)

promoteButton:SetScript("OnClick", function()
    if SlashCmdList and SlashCmdList["ASTRALRAIDLEADER"] then
        SlashCmdList["ASTRALRAIDLEADER"]("promote")
    end
end)

moveUpButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local name = Normalize(nameEdit:GetText())
    if name == "" then Print("Enter a character name to move.") return end
    local foundAt = nil
    for i, n in ipairs(ARL.db.preferredLeaders) do
        if NamesMatch(n, name) then foundAt = i break end
    end
    if not foundAt then
        Print(string.format("|cffffd100%s|r was not found in the preferred leaders list.", name))
        return
    end
    if foundAt == 1 then
        Print(string.format("|cffffd100%s|r is already at the top of the list.", ARL.db.preferredLeaders[foundAt]))
        return
    end
    local entry = table.remove(ARL.db.preferredLeaders, foundAt)
    table.insert(ARL.db.preferredLeaders, foundAt - 1, entry)
    RefreshListText()
    Print(string.format("Moved |cffffd100%s|r to position %d.", entry, foundAt - 1))
end)

moveDownButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local name = Normalize(nameEdit:GetText())
    if name == "" then Print("Enter a character name to move.") return end
    local foundAt = nil
    for i, n in ipairs(ARL.db.preferredLeaders) do
        if NamesMatch(n, name) then foundAt = i break end
    end
    if not foundAt then
        Print(string.format("|cffffd100%s|r was not found in the preferred leaders list.", name))
        return
    end
    if foundAt == #ARL.db.preferredLeaders then
        Print(string.format("|cffffd100%s|r is already at the bottom of the list.", ARL.db.preferredLeaders[foundAt]))
        return
    end
    local entry = table.remove(ARL.db.preferredLeaders, foundAt)
    table.insert(ARL.db.preferredLeaders, foundAt + 1, entry)
    RefreshListText()
    Print(string.format("Moved |cffffd100%s|r to position %d.", entry, foundAt + 1))
end)

nameEdit:SetScript("OnEnterPressed", function() addButton:Click() end)

-- ============================================================
-- Tab 3 – Guild Ranks: handlers
-- ============================================================

useGuildRankCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.useGuildRankPriority = self:GetChecked() and true or false
    Print(string.format("Guild rank priority |cff%s%s|r.",
        ARL.db.useGuildRankPriority and "00ff00" or "ff0000",
        ARL.db.useGuildRankPriority and "enabled" or "disabled"))
end)

addRankButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local rank = Normalize(rankNameEdit:GetText())
    if rank == "" then return end
    for _, existing in ipairs(ARL.db.guildRankPriority) do
        if existing:lower() == rank:lower() then
            Print(string.format("|cffffd100%s|r is already in the guild rank priority list.", rank))
            return
        end
    end
    table.insert(ARL.db.guildRankPriority, rank)
    rankNameEdit:SetText("")
    RefreshRankListText()
    Print(string.format("Added |cffffd100%s|r to the guild rank priority list.", rank))
end)

removeRankButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local rank = Normalize(rankNameEdit:GetText())
    if rank == "" then Print("Enter a guild rank name to remove.") return end
    for i, existing in ipairs(ARL.db.guildRankPriority) do
        if existing:lower() == rank:lower() then
            table.remove(ARL.db.guildRankPriority, i)
            rankNameEdit:SetText("")
            RefreshRankListText()
            Print(string.format("Removed |cffffd100%s|r from the guild rank priority list.", existing))
            return
        end
    end
    Print(string.format("|cffffd100%s|r was not found in the guild rank priority list.", rank))
end)

clearRanksButton:SetScript("OnClick", function()
    if not ARL.db then return end
    ARL.db.guildRankPriority = {}
    RefreshRankListText()
    Print("Cleared the guild rank priority list.")
end)

moveRankUpButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local rank = Normalize(rankNameEdit:GetText())
    if rank == "" then Print("Enter a guild rank name to move.") return end
    local foundAt = nil
    for i, r in ipairs(ARL.db.guildRankPriority) do
        if r:lower() == rank:lower() then foundAt = i break end
    end
    if not foundAt then
        Print(string.format("|cffffd100%s|r was not found in the guild rank priority list.", rank))
        return
    end
    if foundAt == 1 then
        Print(string.format("|cffffd100%s|r is already at the top of the list.", ARL.db.guildRankPriority[foundAt]))
        return
    end
    local entry = table.remove(ARL.db.guildRankPriority, foundAt)
    table.insert(ARL.db.guildRankPriority, foundAt - 1, entry)
    RefreshRankListText()
    Print(string.format("Moved |cffffd100%s|r to position %d.", entry, foundAt - 1))
end)

moveRankDownButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local rank = Normalize(rankNameEdit:GetText())
    if rank == "" then Print("Enter a guild rank name to move.") return end
    local foundAt = nil
    for i, r in ipairs(ARL.db.guildRankPriority) do
        if r:lower() == rank:lower() then foundAt = i break end
    end
    if not foundAt then
        Print(string.format("|cffffd100%s|r was not found in the guild rank priority list.", rank))
        return
    end
    if foundAt == #ARL.db.guildRankPriority then
        Print(string.format("|cffffd100%s|r is already at the bottom of the list.", ARL.db.guildRankPriority[foundAt]))
        return
    end
    local entry = table.remove(ARL.db.guildRankPriority, foundAt)
    table.insert(ARL.db.guildRankPriority, foundAt + 1, entry)
    RefreshRankListText()
    Print(string.format("Moved |cffffd100%s|r to position %d.", entry, foundAt + 1))
end)

rankNameEdit:SetScript("OnEnterPressed", function() addRankButton:Click() end)

refreshGuildRanksButton:SetScript("OnClick", function()
    RefreshGuildRankButtons()
end)

for _, btn in ipairs(guildRankButtons) do
    btn:SetScript("OnClick", function(self)
        if not ARL.db then return end
        local rank = self:GetText()
        if rank == "" then return end
        for _, existing in ipairs(ARL.db.guildRankPriority) do
            if existing:lower() == rank:lower() then
                Print(string.format("|cffffd100%s|r is already in the guild rank priority list.", rank))
                return
            end
        end
        table.insert(ARL.db.guildRankPriority, rank)
        RefreshRankListText()
        Print(string.format("Added |cffffd100%s|r to the guild rank priority list.", rank))
    end)
end

-- ============================================================
-- Tab 4 – Consumables: handlers
-- ============================================================

consumableAuditCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.consumableAuditEnabled = self:GetChecked() and true or false
    Print(string.format("Consumable audit on ready check |cff%s%s|r.",
        ARL.db.consumableAuditEnabled and "00ff00" or "ff0000",
        ARL.db.consumableAuditEnabled and "enabled" or "disabled"))
end)

local FindConsumableCategory = ARL.FindConsumableCategory or function(label)
    local lower = label:lower()
    local sys = ARL.SYSTEM_CONSUMABLES or {}
    for i, cat in ipairs(sys) do
        if cat.label:lower() == lower then return i, cat, true end
    end
    for i, cat in ipairs(ARL.db.trackedConsumables) do
        if cat.label:lower() == lower then return i, cat, false end
    end
    return nil, nil, false
end

addConsumableButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local label   = Normalize(catEdit:GetText())
    local spellId = tonumber(spellIdEdit:GetText())
    if label == "" then Print("Enter a category name.") return end
    if not spellId or spellId < 1 then Print("Enter a valid spell ID.") return end
    local _, cat, isSystem = FindConsumableCategory(label)
    if isSystem then
        Print(string.format("|cffffd100%s|r is a built-in category and cannot be modified.", label))
        return
    end
    if cat then
        for _, id in ipairs(cat.spellIds) do
            if id == spellId then
                Print(string.format("Spell ID %d is already in |cffffd100%s|r.", spellId, cat.label))
                return
            end
        end
        table.insert(cat.spellIds, spellId)
        Print(string.format("Added spell ID %d to |cffffd100%s|r.", spellId, cat.label))
    else
        table.insert(ARL.db.trackedConsumables, { label = label, spellIds = { spellId } })
        Print(string.format("Created category |cffffd100%s|r with spell ID %d.", label, spellId))
    end
    spellIdEdit:SetText("")
    RefreshConsumableListText()
end)

removeSpellIdButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local label   = Normalize(catEdit:GetText())
    local spellId = tonumber(spellIdEdit:GetText())
    if label == "" then Print("Enter a category name.") return end
    if not spellId or spellId < 1 then Print("Enter a valid spell ID.") return end
    local idx, cat, isSystem = FindConsumableCategory(label)
    if not cat then Print(string.format("Category |cffffd100%s|r not found.", label)) return end
    if isSystem then
        Print(string.format("|cffffd100%s|r is a built-in category and cannot be modified.", label))
        return
    end
    for i, id in ipairs(cat.spellIds) do
        if id == spellId then
            table.remove(cat.spellIds, i)
            Print(string.format("Removed spell ID %d from |cffffd100%s|r.", spellId, cat.label))
            if #cat.spellIds == 0 then
                table.remove(ARL.db.trackedConsumables, idx)
                Print(string.format("Category |cffffd100%s|r deleted (no spell IDs remaining).", cat.label))
            end
            spellIdEdit:SetText("")
            RefreshConsumableListText()
            return
        end
    end
    Print(string.format("Spell ID %d was not found in |cffffd100%s|r.", spellId, cat.label))
end)

deleteCatButton:SetScript("OnClick", function()
    if not ARL.db then return end
    local label = Normalize(catEdit:GetText())
    if label == "" then Print("Enter a category name to delete.") return end
    local idx, cat, isSystem = FindConsumableCategory(label)
    if not cat then Print(string.format("Category |cffffd100%s|r not found.", label)) return end
    if isSystem then
        Print(string.format("|cffffd100%s|r is a built-in category and cannot be deleted.", label))
        return
    end
    table.remove(ARL.db.trackedConsumables, idx)
    catEdit:SetText("")
    RefreshConsumableListText()
    Print(string.format("Deleted category |cffffd100%s|r.", cat.label))
end)

clearConsumablesButton:SetScript("OnClick", function()
    if not ARL.db then return end
    ARL.db.trackedConsumables = {}
    RefreshConsumableListText()
    Print("Cleared all custom consumable categories.")
end)

runAuditButton:SetScript("OnClick", function()
    if ARL.RunConsumableAudit then ARL.RunConsumableAudit(true) end
end)

catEdit:SetScript("OnEnterPressed",    function() spellIdEdit:SetFocus() end)
spellIdEdit:SetScript("OnEnterPressed", function() addConsumableButton:Click() end)

-- ============================================================
-- Tab 5 - Deaths: handlers
-- ============================================================

deathTrackingCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.deathTrackingEnabled = self:GetChecked() and true or false
    Print(string.format("Death tracking |cff%s%s|r.",
        ARL.db.deathTrackingEnabled and "00ff00" or "ff0000",
        ARL.db.deathTrackingEnabled and "enabled" or "disabled"))
end)

showRecapCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.showRecapOnWipe = self:GetChecked() and true or false
    Print(string.format("Auto-open death recap on wipe |cff%s%s|r.",
        ARL.db.showRecapOnWipe and "00ff00" or "ff0000",
        ARL.db.showRecapOnWipe and "enabled" or "disabled"))
end)

openRecapButton:SetScript("OnClick", function()
    if ARL.ShowDeathRecap then
        ARL:ShowDeathRecap()
    else
        Print("Death recap UI is not available yet. Try again in a moment.")
    end
end)

-- ============================================================
-- ShowOptions
-- ============================================================

function ARL:ShowOptions()
    if not self.db then
        Print("Not fully loaded yet. Please wait a moment.")
        return
    end
    RefreshUI()
    frame:Show()
    frame:Raise()
    if currentTabIndex == 0 then
        SelectTab(1)
    end
end
