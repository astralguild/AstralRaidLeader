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
frame:SetSize(560, 630)
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
dragRegion:SetScript("OnDragStart", function()
    frame:StartMoving()
end)
dragRegion:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
end)

table.insert(UISpecialFrames, frame:GetName())

local updating = false

local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", 16, -32)
subtitle:SetText("Configure automatic and manual raid leader hand-off behavior.")

local function CreateCheckbox(label, tooltip, anchor, x, y)
    local cb = CreateFrame("CheckButton", nil, frame, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint(anchor, x, y)
    cb.Text:SetText(label)
    if tooltip then
        cb.tooltipText = tooltip
    end
    return cb
end

local autoCB = CreateCheckbox(
    "Enable auto-promote",
    "Automatically promote the highest-priority preferred leader when available.",
    "TOPLEFT", 16, -58
)

local reminderCB = CreateCheckbox(
    "Enable reminder chat messages",
    "Show periodic reminder messages when no preferred leader is present.",
    "TOPLEFT", 16, -86
)

local notifyCB = CreateCheckbox(
    "Enable manual-promote popup",
    "Show a popup with a Promote button when auto-promote is disabled and a preferred leader is available.",
    "TOPLEFT", 16, -114
)

local notifySoundCB = CreateCheckbox(
    "Enable popup sound",
    "Play a sound when the manual-promote popup is shown.",
    "TOPLEFT", 16, -142
)

local quietCB = CreateCheckbox(
    "Enable quiet mode",
    "Suppress all chat output from AstralRaidLeader (auto-promote still works silently).",
    "TOPLEFT", 16, -170
)

local consumableAuditCB = CreateCheckbox(
    "Enable consumable audit on ready check",
    "When a ready check is initiated, report which group members are missing tracked consumable buffs.",
    "TOPLEFT", 16, -198
)

local sliderLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
sliderLabel:SetPoint("TOPLEFT", 16, -236)
sliderLabel:SetText("Reminder interval (seconds)")

local reminderSlider = CreateFrame("Slider", "AstralRaidLeaderReminderSlider", frame, "OptionsSliderTemplate")
reminderSlider:SetPoint("TOPLEFT", 16, -260)
reminderSlider:SetMinMaxValues(5, 120)
reminderSlider:SetValueStep(5)
reminderSlider:SetObeyStepOnDrag(true)
reminderSlider:SetWidth(240)

_G[reminderSlider:GetName() .. "Low"]:SetText("5")
_G[reminderSlider:GetName() .. "High"]:SetText("120")

local sliderValue = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
sliderValue:SetPoint("LEFT", reminderSlider, "RIGHT", 10, 0)
sliderValue:SetText("30s")

-- Group type filter
local groupTypeLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
groupTypeLabel:SetPoint("TOPLEFT", 16, -306)
groupTypeLabel:SetText("Auto-promote in:")

local groupAllCB = CreateCheckbox(
    "All groups",
    "Auto-promote in both raids and parties.",
    "TOPLEFT", 16, -328
)
local groupRaidCB = CreateCheckbox(
    "Raids only",
    "Only auto-promote when in a raid group.",
    "LEFT", groupAllCB, "RIGHT", 20, 0
)
local groupPartyCB = CreateCheckbox(
    "Parties only",
    "Only auto-promote when in a party (not a raid).",
    "LEFT", groupRaidCB, "RIGHT", 20, 0
)

local preferredHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
preferredHeader:SetPoint("TOPLEFT", 16, -372)
preferredHeader:SetText("Preferred leaders (highest priority first)")

local listInset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
listInset:SetPoint("TOPLEFT", 16, -394)
listInset:SetSize(528, 130)

local listText = listInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
listText:SetPoint("TOPLEFT", 8, -8)
listText:SetPoint("TOPRIGHT", -8, -8)
listText:SetJustifyH("LEFT")
listText:SetJustifyV("TOP")

local nameLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
nameLabel:SetPoint("TOPLEFT", 16, -534)
nameLabel:SetText("Character")

local nameEdit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
nameEdit:SetPoint("TOPLEFT", 16, -556)
nameEdit:SetSize(180, 24)
nameEdit:SetAutoFocus(false)
nameEdit:SetMaxLetters(48)

local addButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
addButton:SetPoint("LEFT", nameEdit, "RIGHT", 10, 0)
addButton:SetSize(70, 24)
addButton:SetText("Add")

local removeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
removeButton:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
removeButton:SetSize(90, 24)
removeButton:SetText("Remove")

local clearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
clearButton:SetPoint("LEFT", removeButton, "RIGHT", 8, 0)
clearButton:SetSize(70, 24)
clearButton:SetText("Clear")

local promoteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
promoteButton:SetPoint("LEFT", clearButton, "RIGHT", 8, 0)
promoteButton:SetSize(70, 24)
promoteButton:SetText("Promote")

local moveUpButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
moveUpButton:SetPoint("TOPLEFT", 16, -586)
moveUpButton:SetSize(90, 24)
moveUpButton:SetText("Move Up")

local moveDownButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
moveDownButton:SetPoint("LEFT", moveUpButton, "RIGHT", 8, 0)
moveDownButton:SetSize(100, 24)
moveDownButton:SetText("Move Down")

local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
closeButton:SetPoint("BOTTOMRIGHT", -12, 12)
closeButton:SetSize(100, 24)
closeButton:SetText("Close")
closeButton:SetScript("OnClick", function()
    frame:Hide()
end)

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

local function RefreshUI()
    if not ARL.db then return end

    updating = true

    autoCB:SetChecked(ARL.db.autoPromote)
    reminderCB:SetChecked(ARL.db.reminderEnabled)
    notifyCB:SetChecked(ARL.db.notifyEnabled)
    notifySoundCB:SetChecked(ARL.db.notifySound)
    quietCB:SetChecked(ARL.db.quietMode)
    consumableAuditCB:SetChecked(ARL.db.consumableAuditEnabled)

    local filter = ARL.db.groupTypeFilter or "all"
    groupAllCB:SetChecked(filter == "all")
    groupRaidCB:SetChecked(filter == "raid")
    groupPartyCB:SetChecked(filter == "party")

    local interval = tonumber(ARL.db.reminderInterval) or 30
    reminderSlider:SetValue(interval)
    sliderValue:SetText(string.format("%ds", interval))

    RefreshListText()

    updating = false
end

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
    if not ARL.db.reminderEnabled and ARL.CancelReminder then
        ARL:CancelReminder()
    end
    Print(string.format("Reminder |cff%s%s|r.",
        ARL.db.reminderEnabled and "00ff00" or "ff0000",
        ARL.db.reminderEnabled and "enabled" or "disabled"))
end)

notifyCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.notifyEnabled = self:GetChecked() and true or false
    if not ARL.db.notifyEnabled and ARL.HideManualPromotePopup then
        ARL:HideManualPromotePopup()
    end
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
        -- Print the confirmation before going silent.
        Print("Quiet mode |cff00ff00enabled|r. Chat output suppressed.")
    else
        Print("Quiet mode |cffff0000disabled|r.")
    end
end)

consumableAuditCB:SetScript("OnClick", function(self)
    if updating or not ARL.db then return end
    ARL.db.consumableAuditEnabled = self:GetChecked() and true or false
    Print(string.format("Consumable audit on ready check |cff%s%s|r.",
        ARL.db.consumableAuditEnabled and "00ff00" or "ff0000",
        ARL.db.consumableAuditEnabled and "enabled" or "disabled"))
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

groupAllCB:SetScript("OnClick", function()
    if updating then return end
    SetGroupTypeFilter("all")
end)

groupRaidCB:SetScript("OnClick", function()
    if updating then return end
    SetGroupTypeFilter("raid")
end)

groupPartyCB:SetScript("OnClick", function()
    if updating then return end
    SetGroupTypeFilter("party")
end)

reminderSlider:SetScript("OnValueChanged", function(self, value)
    if updating or not ARL.db then return end
    local rounded = math.floor((value / 5) + 0.5) * 5
    if rounded < 5 then rounded = 5 end
    if rounded > 120 then rounded = 120 end

    self:SetValue(rounded)
    ARL.db.reminderInterval = rounded
    sliderValue:SetText(string.format("%ds", rounded))
end)

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
    if name == "" then
        Print("Enter a character name to remove.")
        return
    end

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
    if ARL.CancelReminder then
        ARL:CancelReminder()
    end
    if ARL.HideManualPromotePopup then
        ARL:HideManualPromotePopup()
    end
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
    if name == "" then
        Print("Enter a character name to move.")
        return
    end
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
    if name == "" then
        Print("Enter a character name to move.")
        return
    end
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

nameEdit:SetScript("OnEnterPressed", function()
    addButton:Click()
end)

function ARL:ShowOptions()
    if not self.db then
        Print("Not fully loaded yet. Please wait a moment.")
        return
    end

    RefreshUI()
    frame:Show()
    frame:Raise()
end
