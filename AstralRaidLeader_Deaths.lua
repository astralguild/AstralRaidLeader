-- AstralRaidLeader_Deaths.lua
-- Death Recap dashboard: shows who died, to what mechanic, during a raid wipe.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

local GameTooltip = _G.GameTooltip
local GetSpellInfo = _G.GetSpellInfo
local C_Spell = _G.C_Spell
local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local ToggleDropDownMenu = _G.ToggleDropDownMenu

local function ResolveSpellNameAndIcon(spellId)
    if not spellId or spellId <= 0 then
        return nil, nil
    end

    if GetSpellInfo then
        local name, _, icon = GetSpellInfo(spellId)
        if name or icon then
            return name, icon
        end
    end

    if C_Spell then
        if C_Spell.GetSpellInfo then
            local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
            if ok and type(info) == "table" then
                local name = info.name or info.spellName
                local icon = info.iconID or info.icon
                if name or icon then
                    return name, icon
                end
            end
        end

        local name
        if C_Spell.GetSpellName then
            local ok, value = pcall(C_Spell.GetSpellName, spellId)
            if ok then
                name = value
            end
        end

        local icon
        if C_Spell.GetSpellTexture then
            local ok, value = pcall(C_Spell.GetSpellTexture, spellId)
            if ok then
                icon = value
            end
        end

        return name, icon
    end

    return nil, nil
end

local function Print(msg)
    print("|cff00ccff[AstralRaidLeader]|r " .. tostring(msg))
end

-- ============================================================
-- Frame construction
-- ============================================================

local FRAME_W, FRAME_H = 700, 500

local frame = CreateFrame(
    "Frame",
    "AstralRaidLeaderDeathRecapFrame",
    UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil
)
frame:SetSize(FRAME_W, FRAME_H)
frame:SetPoint("CENTER")
frame:SetClampedToScreen(true)
frame:SetFrameStrata("DIALOG")
frame:SetFrameLevel(110)
frame:SetToplevel(true)
frame:SetMovable(true)
frame:EnableMouse(false)
frame:SetAlpha(0)
frame:Hide()

frame:HookScript("OnShow", function(self)
    self:SetAlpha(1)
    self:EnableMouse(true)
end)

frame:HookScript("OnHide", function(self)
    self:SetAlpha(0)
    self:EnableMouse(false)
end)

if frame.SetBackdrop then
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.03, 0.05, 0.08, 0.985)
    frame:SetBackdropBorderColor(0.34, 0.42, 0.54, 0.96)
end

local header = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
header:SetPoint("TOPLEFT", 7, -7)
header:SetPoint("TOPRIGHT", -30, -7)
header:SetHeight(28)
header:SetFrameLevel(frame:GetFrameLevel() + 8)
if header.SetBackdrop then
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    header:SetBackdropColor(0.05, 0.09, 0.15, 0.88)
end

local headerDivider = header:CreateTexture(nil, "BORDER")
headerDivider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
headerDivider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
headerDivider:SetHeight(1)
headerDivider:SetColorTexture(0.44, 0.54, 0.68, 0.70)

local titleText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("CENTER", header, "CENTER", 0, 0)
titleText:SetText("Death Recap")
titleText:SetTextColor(1.0, 0.96, 0.78)
titleText:SetShadowColor(0.0, 0.0, 0.0, 0.95)
titleText:SetShadowOffset(1, -1)
titleText:SetAlpha(1)

local topCloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
topCloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
topCloseButton:SetScript("OnClick", function() frame:Hide() end)

local SkinPanel = ARL.UI and ARL.UI.SkinPanel
local SkinActionButton = ARL.UI and ARL.UI.SkinActionButton
if not SkinPanel or not SkinActionButton then
    Print("UI helpers are unavailable; death recap window is disabled.")
    return
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

local contentPanel = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
contentPanel:SetPoint("TOPLEFT", 8, -40)
contentPanel:SetPoint("BOTTOMRIGHT", -8, 44)
SkinPanel(contentPanel, 0.05, 0.08, 0.12, 0.86, 0.23, 0.30, 0.40, 0.42)

-- Subtitle line (encounter + date)
local subtitleText = contentPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitleText:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 10, -10)
subtitleText:SetPoint("TOPRIGHT", contentPanel, "TOPRIGHT", -12, -10)
subtitleText:SetJustifyH("LEFT")
subtitleText:SetTextColor(0.82, 0.86, 0.93)
subtitleText:SetText("")

-- Summary line (e.g. "5 deaths recorded")
local summaryText = contentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
summaryText:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 10, -30)
summaryText:SetJustifyH("LEFT")
summaryText:SetTextColor(0.96, 0.82, 0.22)
summaryText:SetText("")

local recapIndexText = contentPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
recapIndexText:SetPoint("TOPRIGHT", contentPanel, "TOPRIGHT", -12, -30)
recapIndexText:SetJustifyH("RIGHT")
recapIndexText:SetTextColor(0.82, 0.86, 0.93)
recapIndexText:SetText("")

summaryText:SetPoint("TOPRIGHT", recapIndexText, "TOPLEFT", -16, 0)

local recapSelectorLabel = contentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
recapSelectorLabel:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 10, -66)
recapSelectorLabel:SetText("Recap")

local recapDropDown = CreateFrame(
    "Frame",
    "AstralRaidLeaderDeathRecapDropDown",
    contentPanel,
    "UIDropDownMenuTemplate"
)
recapDropDown:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", -6, -76)
if UIDropDownMenu_SetWidth then
    UIDropDownMenu_SetWidth(recapDropDown, 580)
end
if UIDropDownMenu_SetText then
    UIDropDownMenu_SetText(recapDropDown, "No stored recaps")
end
recapDropDown:EnableMouse(false)

local suppressRecapDropDownMouseDown = false

local recapDropDownButton = _G["AstralRaidLeaderDeathRecapDropDownButton"]
if recapDropDownButton then
    recapDropDownButton:EnableMouse(true)
    recapDropDownButton:SetHitRectInsets(0, 0, 0, 0)
    recapDropDownButton:SetScript("OnClick", function()
        if ToggleDropDownMenu then
            suppressRecapDropDownMouseDown = true
            ToggleDropDownMenu(1, nil, recapDropDown)
        end
    end)
end

recapDropDown:SetScript("OnMouseDown", function(_, mouseButton)
    if suppressRecapDropDownMouseDown then
        suppressRecapDropDownMouseDown = false
        return
    end
    if mouseButton == "LeftButton" and ToggleDropDownMenu then
        ToggleDropDownMenu(1, nil, recapDropDown)
    end
end)

local recapDropDownText = _G["AstralRaidLeaderDeathRecapDropDownText"]
if recapDropDownText then
    recapDropDownText:ClearAllPoints()
    recapDropDownText:SetPoint("LEFT", recapDropDown, "LEFT", 32, 2)
    recapDropDownText:SetPoint("RIGHT", recapDropDown, "RIGHT", -43, 2)
    recapDropDownText:SetJustifyH("LEFT")
end

-- Scroll frame for the death list
-- Right inset is -30 to leave room for the scroll bar track inside the panel.
local SCROLL_TOP_OFFSET = 104
local SCROLL_BOTTOM_OFFSET = 10
local SCROLL_RIGHT_INSET = 34
local SCROLLBAR_RIGHT_INSET = 8
local SCROLLBAR_TOP_INSET = 8
local SCROLLBAR_BOTTOM_INSET = 8

local scrollFrame = CreateFrame(
    "ScrollFrame",
    "AstralRaidLeaderDeathScroll",
    contentPanel,
    "UIPanelScrollFrameTemplate"
)
scrollFrame:SetPoint("TOPLEFT",  contentPanel, "TOPLEFT", 10, -SCROLL_TOP_OFFSET)
scrollFrame:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", -SCROLL_RIGHT_INSET, SCROLL_BOTTOM_OFFSET)

-- Reanchor the template scrollbar so it sits inside contentPanel rather than
-- spilling outside (the template default is +24px right of the scroll frame).
local _sb = _G["AstralRaidLeaderDeathScrollScrollBar"]
if _sb then
    _sb:ClearAllPoints()
    _sb:SetWidth(12)
    _sb:SetPoint(
        "TOPRIGHT",
        contentPanel,
        "TOPRIGHT",
        -SCROLLBAR_RIGHT_INSET,
        -(SCROLL_TOP_OFFSET + SCROLLBAR_TOP_INSET)
    )
    _sb:SetPoint(
        "BOTTOMRIGHT",
        contentPanel,
        "BOTTOMRIGHT",
        -SCROLLBAR_RIGHT_INSET,
        SCROLL_BOTTOM_OFFSET + SCROLLBAR_BOTTOM_INSET
    )
end

local listInset = CreateFrame("Frame", nil, contentPanel, BackdropTemplateMixin and "BackdropTemplate" or nil)
listInset:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -4, 4)
listInset:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 4, -4)
SkinPanel(listInset, 0.07, 0.10, 0.14, 0.34, 0.22, 0.28, 0.36, 0.24)
listInset:SetFrameLevel(scrollFrame:GetFrameLevel() - 1)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(scrollFrame:GetWidth() or (FRAME_W - 48), 1)
scrollFrame:SetScrollChild(content)

local listText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
listText:SetPoint("TOPLEFT", 4, -4)
listText:SetPoint("TOPRIGHT", -4, -4)
listText:SetJustifyH("LEFT")
listText:SetJustifyV("TOP")
listText:SetSpacing(3)
listText:SetTextColor(0.90, 0.92, 0.96)
listText:SetText("")

local deathRows = {}
local DEATH_ROW_HEIGHT = 18
local selectedRecapIndex = 1

local function FormatRecapDifficulty(value)
    local text = tostring(value or "")
    if text == "" then
        return "Unknown"
    end
    if ARL.FormatRaidDifficultyDisplay then
        return ARL.FormatRaidDifficultyDisplay(text)
    end
    return text
end

local function GetStoredRecapHistory()
    if not ARL.db then return {}, 0 end

    local history = ARL.db.deathRecapHistory
    if type(history) ~= "table" then
        history = {}
    end

    local total = #history
    if total == 0 and (
        (ARL.db.lastWipeEncounter and ARL.db.lastWipeEncounter ~= "")
        or (ARL.db.lastWipeDate and ARL.db.lastWipeDate ~= "")
        or (type(ARL.db.lastWipeDeaths) == "table" and #ARL.db.lastWipeDeaths > 0)
    ) then
        return {
            {
                encounter = ARL.db.lastWipeEncounter or "",
                difficulty = "",
                date = ARL.db.lastWipeDate or "",
                outcome = "wipe",
                deaths = ARL.db.lastWipeDeaths,
            }
        }, 1
    end

    return history, total
end

local function BuildRecapSelectionLabel(recap, index)
    local outcome = (recap and recap.outcome == "kill") and "Kill" or "Wipe"
    local difficulty = FormatRecapDifficulty(recap and recap.difficulty)
    local encounter = recap and recap.encounter or "Unknown Encounter"
    local recapDate = recap and recap.date or "unknown time"
    return string.format(
        "%d. [%s] %s %s - %s",
        index,
        outcome,
        difficulty,
        encounter,
        recapDate
    )
end

local function FormatExactAmount(value)
    if type(value) ~= "number" then
        return nil
    end

    value = math.floor(value + 0.5)
    if value <= 0 then
        return nil
    end

    local formatted = tostring(value)
    while true do
        local replaced, count = formatted:gsub("^(%d+)(%d%d%d)", "%1,%2")
        formatted = replaced
        if count == 0 then
            break
        end
    end

    return formatted
end

local function FormatCompactAmount(value)
    if type(value) ~= "number" then
        return nil
    end

    value = math.floor(value + 0.5)
    if value <= 0 then
        return nil
    end

    if value >= 1000000 then
        local millions = value / 1000000
        if millions >= 10 then
            return string.format("%.0fM", millions)
        end
        return string.format("%.1fM", millions)
    end

    if value >= 1000 then
        local thousands = value / 1000
        if thousands >= 10 then
            return string.format("%.0fk", thousands)
        end
        return string.format("%.1fk", thousands)
    end

    return tostring(value)
end

local function FormatHealthState(current, maxValue)
    if type(current) ~= "number" or current < 0 then
        return nil
    end

    local currentText = FormatCompactAmount(current) or FormatExactAmount(current) or tostring(current)
    if type(maxValue) == "number" and maxValue > 0 then
        local pct = math.floor(((current / maxValue) * 100) + 0.5)
        local maxText = FormatCompactAmount(maxValue) or FormatExactAmount(maxValue) or tostring(maxValue)
        return string.format("%s%% (%s/%s)", pct, currentText, maxText)
    end

    return currentText
end

local detailsFrame
local detailsSummaryText
local detailsHealthText
local detailsTimelineText
local detailsTimelineRows = {}
local DETAILS_TIMELINE_ROW_HEIGHT = 20
local ShowSpellTooltip

local function EnsureDetailsFrame()
    if detailsFrame then
        return detailsFrame
    end

    local f = CreateFrame(
        "Frame",
        "AstralRaidLeaderDeathDetailsFrame",
        UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil
    )
    f:SetSize(560, 380)
    f:SetPoint("CENTER", UIParent, "CENTER", 44, -24)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(frame:GetFrameLevel() + 4)
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(false)
    f:SetAlpha(0)
    f:Hide()

    f:HookScript("OnShow", function(self)
        self:SetAlpha(1)
        self:EnableMouse(true)
    end)

    f:HookScript("OnHide", function(self)
        self:SetAlpha(0)
        self:EnableMouse(false)
    end)

    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        f:SetBackdropColor(0.03, 0.05, 0.08, 0.985)
        f:SetBackdropBorderColor(0.34, 0.42, 0.54, 0.96)
    end

    local dHeader = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    dHeader:SetPoint("TOPLEFT", 7, -7)
    dHeader:SetPoint("TOPRIGHT", -30, -7)
    dHeader:SetHeight(28)
    dHeader:SetFrameLevel(f:GetFrameLevel() + 8)
    if dHeader.SetBackdrop then
        dHeader:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        dHeader:SetBackdropColor(0.05, 0.09, 0.15, 0.88)
    end

    local dHeaderDivider = dHeader:CreateTexture(nil, "BORDER")
    dHeaderDivider:SetPoint("BOTTOMLEFT", dHeader, "BOTTOMLEFT", 0, 0)
    dHeaderDivider:SetPoint("BOTTOMRIGHT", dHeader, "BOTTOMRIGHT", 0, 0)
    dHeaderDivider:SetHeight(1)
    dHeaderDivider:SetColorTexture(0.44, 0.54, 0.68, 0.70)

    local dTitle = dHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dTitle:SetPoint("CENTER", dHeader, "CENTER", 0, 0)
    dTitle:SetText("Death Details")
    dTitle:SetTextColor(1.0, 0.96, 0.78)
    dTitle:SetShadowColor(0.0, 0.0, 0.0, 0.95)
    dTitle:SetShadowOffset(1, -1)
    f.titleText = dTitle

    local dTopClose = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    dTopClose:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    dTopClose:SetScript("OnClick", function() f:Hide() end)

    local dDragRegion = CreateFrame("Frame", nil, f)
    dDragRegion:SetPoint("TOPLEFT", 8, -6)
    dDragRegion:SetPoint("TOPRIGHT", -28, -6)
    dDragRegion:SetHeight(22)
    dDragRegion:EnableMouse(true)
    dDragRegion:RegisterForDrag("LeftButton")
    dDragRegion:SetScript("OnDragStart", function() f:StartMoving() end)
    dDragRegion:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    local dContentPanel = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    dContentPanel:SetPoint("TOPLEFT", 8, -40)
    dContentPanel:SetPoint("BOTTOMRIGHT", -8, 44)
    SkinPanel(dContentPanel, 0.05, 0.08, 0.12, 0.86, 0.23, 0.30, 0.40, 0.42)

    detailsSummaryText = dContentPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailsSummaryText:SetPoint("TOPLEFT", dContentPanel, "TOPLEFT", 10, -10)
    detailsSummaryText:SetPoint("TOPRIGHT", dContentPanel, "TOPRIGHT", -12, -10)
    detailsSummaryText:SetJustifyH("LEFT")
    detailsSummaryText:SetTextColor(0.90, 0.92, 0.96)
    detailsSummaryText:SetText("")

    detailsHealthText = dContentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detailsHealthText:SetPoint("TOPLEFT", detailsSummaryText, "BOTTOMLEFT", 0, -6)
    detailsHealthText:SetPoint("TOPRIGHT", detailsSummaryText, "BOTTOMRIGHT", 0, -6)
    detailsHealthText:SetJustifyH("LEFT")
    detailsHealthText:SetTextColor(0.82, 0.86, 0.93)
    detailsHealthText:SetText("")

    local timelineLabel = dContentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timelineLabel:SetPoint("TOPLEFT", detailsHealthText, "BOTTOMLEFT", 0, -10)
    timelineLabel:SetText("Recent events")
    timelineLabel:SetTextColor(0.96, 0.82, 0.22)

    local dScrollFrame = CreateFrame(
        "ScrollFrame",
        "AstralRaidLeaderDeathDetailsScroll",
        dContentPanel,
        "UIPanelScrollFrameTemplate"
    )
    dScrollFrame:SetPoint("TOPLEFT", dContentPanel, "TOPLEFT", 10, -72)
    dScrollFrame:SetPoint("BOTTOMRIGHT", dContentPanel, "BOTTOMRIGHT", -34, 10)

    local dSb = _G["AstralRaidLeaderDeathDetailsScrollScrollBar"]
    if dSb then
        dSb:ClearAllPoints()
        dSb:SetWidth(12)
        dSb:SetPoint("TOPRIGHT", dContentPanel, "TOPRIGHT", -8, -80)
        dSb:SetPoint("BOTTOMRIGHT", dContentPanel, "BOTTOMRIGHT", -8, 18)
    end

    local dListInset = CreateFrame("Frame", nil, dContentPanel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    dListInset:SetPoint("TOPLEFT", dScrollFrame, "TOPLEFT", -4, 4)
    dListInset:SetPoint("BOTTOMRIGHT", dScrollFrame, "BOTTOMRIGHT", 4, -4)
    SkinPanel(dListInset, 0.07, 0.10, 0.14, 0.34, 0.22, 0.28, 0.36, 0.24)
    dListInset:SetFrameLevel(dScrollFrame:GetFrameLevel() - 1)

    local dContent = CreateFrame("Frame", nil, dScrollFrame)
    dContent:SetSize((dScrollFrame:GetWidth() or 500), 1)
    dScrollFrame:SetScrollChild(dContent)
    f.scrollFrame = dScrollFrame
    f.scrollContent = dContent

    detailsTimelineText = dContent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detailsTimelineText:SetPoint("TOPLEFT", dContent, "TOPLEFT", 4, -4)
    detailsTimelineText:SetPoint("TOPRIGHT", dContent, "TOPRIGHT", -4, -4)
    detailsTimelineText:SetJustifyH("LEFT")
    detailsTimelineText:SetJustifyV("TOP")
    detailsTimelineText:SetSpacing(3)
    detailsTimelineText:SetTextColor(0.90, 0.92, 0.96)
    detailsTimelineText:SetText("")

    local dCloseButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    dCloseButton:SetPoint("BOTTOMRIGHT", -12, 12)
    dCloseButton:SetSize(100, 24)
    dCloseButton:SetText("Close")
    dCloseButton:SetScript("OnClick", function() f:Hide() end)
    SkinActionButton(dCloseButton)

    table.insert(UISpecialFrames, f:GetName())

    detailsFrame = f
    return detailsFrame
end

local function BuildTimelineDetailsLine(index, event)
    local eventType = tostring((event and event.eventType) or "")
    local eventToken = tostring((event and event.eventToken) or "")
    local shownTime = tostring((event and event.timeStr) or "?:??")

    local spellName = event and event.spellName
    local spellId = event and event.spellId
    if (not spellName or spellName == "") and spellId and spellId > 0 then
        spellName = ResolveSpellNameAndIcon(spellId)
    end
    if not spellName or spellName == "" then
        spellName = "Unknown"
    end

    local sourceName = tostring((event and event.source) or "Unknown")
    local amountText = nil
    local rawAmount = event and event.amount
    if type(rawAmount) == "number" and rawAmount > 0 then
        local compact = FormatCompactAmount(rawAmount) or tostring(rawAmount)
        if eventType == "heal" then
            amountText = "|cff55ff88+" .. compact .. "|r"
        elseif eventType == "damage" then
            amountText = "|cffff6666-" .. compact .. "|r"
        end
    end

    local overkillText = nil
    local rawOverkill = event and event.overkill
    if type(rawOverkill) == "number" and rawOverkill > 0 then
        overkillText = "|cffffaa33 overkill " .. (FormatCompactAmount(rawOverkill) or rawOverkill) .. "|r"
    end

    local healthAtEvent = nil
    if type(event) == "table" then
        local healthCurrent = event.healthAfter
        if type(healthCurrent) ~= "number" then
            healthCurrent = event.healthBefore
        end
        healthAtEvent = FormatHealthState(healthCurrent, event.healthMax)
    end

    local eventLabel = "Event"
    if eventType == "damage" then
        eventLabel = "Damage"
    elseif eventType == "heal" then
        eventLabel = "Heal"
    elseif eventType == "aura" then
        eventLabel = "Aura"
    end

    local auraSuffix = ""
    if eventType == "aura" and eventToken ~= "" then
        auraSuffix = " (" .. eventToken:gsub("_", " ") .. ")"
    end

    local line = string.format(
        "%d. [%s] |cffd7dde9%s|r%s: |cffffd100%s|r from |cffffa133%s|r",
        index,
        shownTime,
        eventLabel,
        auraSuffix,
        spellName,
        sourceName
    )

    if amountText then
        line = line .. "  " .. amountText
    end
    if overkillText then
        line = line .. "  " .. overkillText
    end
    if healthAtEvent then
        line = line .. "  |cff9fb0c8HP " .. healthAtEvent .. "|r"
    end

    return line
end

local function HideAllDetailsTimelineRows()
    for _, row in ipairs(detailsTimelineRows) do
        row.event = nil
        row.spellId = nil
        row:Hide()
    end
end

local function AcquireDetailsTimelineRow(index, popup)
    local row = detailsTimelineRows[index]
    if row then
        return row
    end

    row = CreateFrame("Button", nil, popup.scrollContent)
    row:SetHeight(DETAILS_TIMELINE_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 4, -4 - ((index - 1) * DETAILS_TIMELINE_ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", -4, -4 - ((index - 1) * DETAILS_TIMELINE_ROW_HEIGHT))
    row:EnableMouse(false)

    local hoverBG = row:CreateTexture(nil, "BACKGROUND")
    hoverBG:SetAllPoints(row)
    hoverBG:SetColorTexture(1, 1, 1, 0.04)
    hoverBG:Hide()
    row.hoverBG = hoverBG

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    icon:Hide()
    row.spellIcon = icon

    local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("LEFT", row, "LEFT", 0, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    text:SetTextColor(0.90, 0.92, 0.96)
    row.lineText = text

    row:SetScript("OnEnter", function(self)
        if self.hoverBG then
            self.hoverBG:Show()
        end
        if self.spellId and self.spellId > 0 then
            ShowSpellTooltip(self, self.spellId, self.event)
        end
    end)

    row:SetScript("OnLeave", function(self)
        if self.hoverBG then
            self.hoverBG:Hide()
        end
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    detailsTimelineRows[index] = row
    return row
end

local function PopulateDetailsTimelineRow(row, index, event)
    row.event = event
    row.spellId = nil
    row.lineText:SetText(BuildTimelineDetailsLine(index, event))

    local spellId = type(event) == "table" and event.spellId or nil
    if type(spellId) == "number" and spellId > 0 then
        row.spellId = spellId
        local _, icon = ResolveSpellNameAndIcon(spellId)
        if icon then
            row.spellIcon:SetTexture(icon)
            row.spellIcon:Show()
            row.lineText:ClearAllPoints()
            row.lineText:SetPoint("LEFT", row.spellIcon, "RIGHT", 6, 0)
            row.lineText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        else
            row.spellIcon:Hide()
            row.lineText:ClearAllPoints()
            row.lineText:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.lineText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        end
    else
        row.spellIcon:Hide()
        row.lineText:ClearAllPoints()
        row.lineText:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.lineText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    end

    row:EnableMouse(row.spellId ~= nil)
end

local function ShowDeathDetails(entry)
    if type(entry) ~= "table" then
        return
    end

    local popup = EnsureDetailsFrame()
    if not popup then
        return
    end

    local playerName = tostring(entry.playerName or "Unknown")
    if popup.titleText then
        popup.titleText:SetText("Death Details - " .. playerName)
    end

    local shownTime = tostring(entry.timeStr or "?:??")
    local mechanicName = tostring(entry.mechanic or "Unknown")
    local sourceName = tostring(entry.source or "Unknown")
    local summary = string.format(
        "%s died to %s (from %s) at %s.",
        playerName,
        mechanicName,
        sourceName,
        shownTime
    )

    local amount = FormatExactAmount(entry.hitAmount)
    if amount then
        summary = summary .. " Killing blow: " .. amount .. "."
    end

    detailsSummaryText:SetText(summary)

    local healthText = FormatHealthState(entry.healthAtDeath, entry.healthMaxAtDeath)
    if healthText then
        detailsHealthText:SetText("Health after death event: " .. healthText)
    else
        detailsHealthText:SetText("Health after death event: unavailable")
    end

    local timeline = entry.eventTimeline
    HideAllDetailsTimelineRows()

    local lines = {}
    local shownRows = 0
    if type(timeline) == "table" and #timeline > 0 then
        for i, event in ipairs(timeline) do
            local row = AcquireDetailsTimelineRow(i, popup)
            PopulateDetailsTimelineRow(row, i, event)
            row:Show()
            shownRows = i
        end
        if entry.timelineTruncated then
            lines[#lines + 1] = "|cff9fb0c8Showing last 10 relevant events.|r"
        end
    else
        lines[#lines + 1] = "No additional timeline data is available for this recap entry."
    end

    local timelineText = table.concat(lines, "\n")
    detailsTimelineText:SetText(timelineText)

    detailsTimelineText:ClearAllPoints()
    local messageTop = -4 - (shownRows * DETAILS_TIMELINE_ROW_HEIGHT)
    detailsTimelineText:SetPoint("TOPLEFT", popup.scrollContent, "TOPLEFT", 4, messageTop)
    detailsTimelineText:SetPoint("TOPRIGHT", popup.scrollContent, "TOPRIGHT", -4, messageTop)
    local textHeight = detailsTimelineText:GetStringHeight() or 0
    local totalHeight = (shownRows * DETAILS_TIMELINE_ROW_HEIGHT) + textHeight + 16
    popup.scrollContent:SetHeight(math.max(1, math.floor(totalHeight)))
    popup.scrollFrame:SetVerticalScroll(0)
    popup:Show()
    popup:Raise()
end

function ShowSpellTooltip(owner, spellId, entry)
    if not GameTooltip or not spellId or spellId <= 0 then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR_RIGHT")
    local ok = false
    if GameTooltip.SetSpellByID then
        ok = pcall(GameTooltip.SetSpellByID, GameTooltip, spellId)
    end

    if not ok then
        local spellName = ResolveSpellNameAndIcon(spellId)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(spellName or "Unknown Spell", 1.0, 1.0, 1.0)
        GameTooltip:AddLine("Spell ID: " .. spellId, 0.82, 0.86, 0.93)
    end

    if type(entry) == "table" then
        local hitAmount = FormatExactAmount(entry.hitAmount or entry.amount)
        local overkill = FormatExactAmount(entry.overkill)
        if hitAmount then
            GameTooltip:AddLine("Killing blow: " .. hitAmount, 0.90, 0.92, 0.96)
        end
        if overkill then
            GameTooltip:AddLine("Overkill: " .. overkill, 0.96, 0.82, 0.22)
        end
    end

    GameTooltip:Show()
end

local function HideAllDeathRows()
    for _, row in ipairs(deathRows) do
        row.entry = nil
        row:Hide()
    end
end

local function AcquireDeathRow(index)
    local row = deathRows[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, content)
    row:SetHeight(DEATH_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 4, -4 - ((index - 1) * DEATH_ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", -4, -4 - ((index - 1) * DEATH_ROW_HEIGHT))

    local prefix = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    prefix:SetPoint("LEFT", row, "LEFT", 0, 0)
    prefix:SetJustifyH("LEFT")
    prefix:SetJustifyV("MIDDLE")
    prefix:SetWordWrap(false)
    prefix:SetTextColor(0.90, 0.92, 0.96)
    row.prefixText = prefix

    local spellButton = CreateFrame("Button", nil, row)
    spellButton:SetHeight(DEATH_ROW_HEIGHT)
    spellButton:EnableMouse(true)

    local spellText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    spellText:SetPoint("LEFT", row.prefixText, "RIGHT", 4, 0)
    spellText:SetJustifyH("LEFT")
    spellText:SetJustifyV("MIDDLE")
    spellText:SetWordWrap(false)
    spellText:SetTextColor(0.90, 0.92, 0.96)
    row.spellText = spellText

    spellButton:SetPoint("TOPLEFT", spellText, "TOPLEFT", 0, 0)
    spellButton:SetPoint("BOTTOMRIGHT", spellText, "BOTTOMRIGHT", 0, 0)
    row.spellButton = spellButton

    local suffix = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    suffix:SetPoint("LEFT", spellText, "RIGHT", 6, 0)
    suffix:SetJustifyH("LEFT")
    suffix:SetJustifyV("MIDDLE")
    suffix:SetWordWrap(false)
    suffix:SetTextColor(0.90, 0.92, 0.96)
    row.suffixText = suffix

    spellButton:SetScript("OnEnter", function(self)
        ShowSpellTooltip(self, self.spellId, self.entry)
    end)

    spellButton:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    spellButton:SetScript("OnClick", function(self, button)
        if button ~= "LeftButton" or type(self.entry) ~= "table" then
            return
        end
        ShowDeathDetails(self.entry)
    end)

    deathRows[index] = row
    return row
end

-- Close button
local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
closeButton:SetPoint("BOTTOMRIGHT", -12, 12)
closeButton:SetSize(100, 24)
closeButton:SetText("Close")
closeButton:SetScript("OnClick", function() frame:Hide() end)
SkinActionButton(closeButton)

local newerRecapButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
newerRecapButton:SetPoint("BOTTOMLEFT", 12, 12)
newerRecapButton:SetSize(110, 24)
newerRecapButton:SetText("Newer")
SkinActionButton(newerRecapButton)

local olderRecapButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
olderRecapButton:SetPoint("LEFT", newerRecapButton, "RIGHT", 8, 0)
olderRecapButton:SetSize(110, 24)
olderRecapButton:SetText("Older")
SkinActionButton(olderRecapButton)

-- ============================================================
-- Populate helpers
-- ============================================================

local COLOR_PLAYER   = "|cffffff00"   -- yellow
local COLOR_MECHANIC = "|cffff4444"   -- red
local COLOR_SOURCE   = "|cffff8000"   -- orange
local COLOR_TIME     = "|cff888888"   -- grey
local COLOR_RESET    = "|r"

local function IsMissingMechanicName(value)
    if type(value) ~= "string" then
        return not value
    end
    local trimmed = value:gsub("^%s+", ""):gsub("%s+$", "")
    return trimmed == "" or trimmed == "..." or trimmed == "…"
end

local function BuildDeathLine(i, entry)
    local playerName = tostring((entry and entry.playerName) or "Unknown")
    local sourceName = tostring((entry and entry.source) or "Unknown")
    local shownTime = tostring((entry and entry.timeStr) or "?:??")

    local prefix = string.format(
        "%2d. %s%s%s  died to",
        i,
        COLOR_PLAYER, playerName, COLOR_RESET
    )

    local spellId = entry and entry.spellId
    local mechanicName = entry and entry.mechanic
    if IsMissingMechanicName(mechanicName)
        and spellId and spellId > 0
    then
        local resolvedName = ResolveSpellNameAndIcon(spellId)
        if resolvedName and resolvedName ~= "" then
            mechanicName = resolvedName
        else
            mechanicName = string.format("Spell %d", spellId)
        end
    end

    if IsMissingMechanicName(mechanicName) then
        mechanicName = "Unknown Spell"
    end

    local spellText = string.format(
        "%s%s%s",
        COLOR_MECHANIC, mechanicName or "Unknown", COLOR_RESET
    )

    if spellId and spellId > 0 then
        local _, icon = ResolveSpellNameAndIcon(spellId)
        if icon then
            spellText = string.format("|T%s:14:14:0:0:64:64:4:60:4:60|t %s", icon, spellText)
        end
    end

    local overkillText = FormatCompactAmount(entry.overkill)
    if overkillText then
        spellText = string.format(
            "%s |cff888888(-%s)%s",
            spellText,
            overkillText,
            COLOR_RESET
        )
    end

    local suffix = string.format(
        "(from %s%s%s) %sat %s%s",
        COLOR_SOURCE, sourceName, COLOR_RESET,
        COLOR_TIME,   shownTime, COLOR_RESET
    )

    return prefix, spellText, suffix
end

local function PopulateDeathRow(row, i, entry)
    local prefix, spellText, suffix = BuildDeathLine(i, entry)

    row.prefixText:SetText(prefix)
    row.spellText:SetText(spellText)
    row.suffixText:SetText(suffix)

    local hasSpellTooltip = entry.spellId and entry.spellId > 0
    local hasDetails = type(entry.eventTimeline) == "table" and #entry.eventTimeline > 0
    row.spellButton.spellId = hasSpellTooltip and entry.spellId or nil
    row.spellButton.entry = entry
    row.spellButton:EnableMouse(hasSpellTooltip or hasDetails)
end

local function RefreshRecapDropDown(selectedIndex)
    local history, total = GetStoredRecapHistory()
    if not UIDropDownMenu_SetText then return end

    if total <= 0 then
        UIDropDownMenu_SetText(recapDropDown, "No stored recaps")
        return
    end

    local recap = history[selectedIndex]
    UIDropDownMenu_SetText(
        recapDropDown,
        BuildRecapSelectionLabel(recap, selectedIndex)
    )
end

local RefreshRecap

UIDropDownMenu_Initialize(recapDropDown, function(_, level)
    if level ~= 1 then return end

    local history, total = GetStoredRecapHistory()
    if total <= 0 then
        local info = UIDropDownMenu_CreateInfo()
        info.text = "No stored recaps"
        info.disabled = true
        UIDropDownMenu_AddButton(info, level)
        return
    end

    for index, recap in ipairs(history) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = BuildRecapSelectionLabel(recap, index)
        info.checked = index == selectedRecapIndex
        info.func = function()
            RefreshRecap(index)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

function RefreshRecap(requestedIndex)
    if not ARL.db then
        subtitleText:SetText("Waiting for saved variables to load...")
        summaryText:SetText("")
        recapIndexText:SetText("")
        listText:SetText("")
        HideAllDeathRows()
        newerRecapButton:Disable()
        olderRecapButton:Disable()
        RefreshRecapDropDown(1)
        return
    end

    local history, total = GetStoredRecapHistory()

    if type(requestedIndex) == "number" then
        selectedRecapIndex = math.floor(requestedIndex)
    end

    if total <= 0 then
        selectedRecapIndex = 1
    elseif selectedRecapIndex < 1 then
        selectedRecapIndex = 1
    elseif selectedRecapIndex > total then
        selectedRecapIndex = total
    end

    local recap = history[selectedRecapIndex] or {}
    local encounter = recap.encounter or ""
    local difficulty = FormatRecapDifficulty(recap.difficulty)
    local wipeDate  = recap.date or ""
    local deaths    = type(recap.deaths) == "table" and recap.deaths or {}
    local outcome = recap.outcome == "kill" and "Kill" or "Wipe"

    if encounter and encounter ~= "" then
        subtitleText:SetText(string.format(
            "[%s] |cffffd100%s|r Encounter: |cffffd100%s|r  –  %s",
            outcome,
            difficulty,
            encounter,
            wipeDate ~= "" and wipeDate or "unknown time"
        ))
    else
        subtitleText:SetText("No wipe data recorded yet.")
    end

    if total > 0 then
        recapIndexText:SetText(string.format("Recap %d/%d", selectedRecapIndex, total))
    else
        recapIndexText:SetText("Recap 0/0")
    end

    newerRecapButton:SetEnabled(total > 0 and selectedRecapIndex > 1)
    olderRecapButton:SetEnabled(total > 0 and selectedRecapIndex < total)
    RefreshRecapDropDown(selectedRecapIndex)

    -- Always clear previous recap state before rendering the current selection.
    summaryText:SetText("")
    listText:SetText("")
    listText:Hide()
    HideAllDeathRows()
    content:SetHeight(40)
    scrollFrame:SetVerticalScroll(0)

    if #deaths == 0 then
        summaryText:SetText("No reliable death-cause data found.")
        listText:SetText("(C_DamageMeter did not provide death details for this wipe.)")
        listText:Show()
        return
    end

    summaryText:SetText(string.format(
        "%d death%s recorded. Hover spell names for tooltips, left-click for event timeline details.",
        #deaths,
        #deaths == 1 and "" or "s"
    ))
    for i, entry in ipairs(deaths) do
        local row = AcquireDeathRow(i)
        row.entry = entry
        PopulateDeathRow(row, i, entry)
        row:Show()
    end
    for i = #deaths + 1, #deathRows do
        deathRows[i].entry = nil
        deathRows[i]:Hide()
    end

    -- Allow the content frame to resize so the scroll frame works correctly.
    content:SetHeight((#deaths * DEATH_ROW_HEIGHT) + 8)
    scrollFrame:SetVerticalScroll(0)
end

newerRecapButton:SetScript("OnClick", function()
    RefreshRecap(selectedRecapIndex - 1)
end)

olderRecapButton:SetScript("OnClick", function()
    RefreshRecap(selectedRecapIndex + 1)
end)

-- ============================================================
-- Public API
-- ============================================================

function ARL.ShowDeathRecap(index)
    if type(index) ~= "number" then
        index = 1
    end
    RefreshRecap(index)
    frame:Show()
    frame:Raise()
    -- Reset scroll to top
    scrollFrame:SetVerticalScroll(0)
end

function ARL.HideDeathRecap()
    frame:Hide()
end
