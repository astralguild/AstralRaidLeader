-- AstralRaidLeader_Deaths.lua
-- Death Recap dashboard: shows who died, to what mechanic, during a raid wipe.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

local GameTooltip = _G.GameTooltip
local GetSpellInfo = _G.GetSpellInfo
local C_Spell = _G.C_Spell

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

local FRAME_W, FRAME_H = 520, 430

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
subtitleText:SetWidth(FRAME_W - 56)
subtitleText:SetJustifyH("LEFT")
subtitleText:SetTextColor(0.82, 0.86, 0.93)
subtitleText:SetText("")

-- Summary line (e.g. "5 deaths recorded")
local summaryText = contentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
summaryText:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 10, -30)
summaryText:SetWidth(FRAME_W - 56)
summaryText:SetJustifyH("LEFT")
summaryText:SetTextColor(0.96, 0.82, 0.22)
summaryText:SetText("")

-- Scroll frame for the death list
-- Right inset is -30 to leave room for the scroll bar track inside the panel.
local SCROLL_TOP_OFFSET = 56
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

local function ShowSpellTooltip(owner, spellId, entry)
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
        local hitAmount = FormatExactAmount(entry.hitAmount)
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

local function IsMissingMechanicName(value)
    if type(value) ~= "string" then
        return not value
    end
    local trimmed = value:gsub("^%s+", ""):gsub("%s+$", "")
    return trimmed == "" or trimmed == "..." or trimmed == "…"
end

local function BuildDeathLine(i, entry)
    local prefix = string.format(
        "%2d. %s%s%s  died to",
        i,
        COLOR_PLAYER, entry.playerName, COLOR_RESET
    )

    local spellId = entry.spellId
    local mechanicName = entry.mechanic
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
        COLOR_SOURCE, entry.source, COLOR_RESET,
        COLOR_TIME,   entry.timeStr, COLOR_RESET
    )

    return prefix, spellText, suffix
end

local function PopulateDeathRow(row, i, entry)
    local prefix, spellText, suffix = BuildDeathLine(i, entry)

    row.prefixText:SetText(prefix)
    row.spellText:SetText(spellText)
    row.suffixText:SetText(suffix)

    local hasSpellTooltip = entry.spellId and entry.spellId > 0
    row.spellButton.spellId = hasSpellTooltip and entry.spellId or nil
    row.spellButton.entry = entry
    row.spellButton:EnableMouse(hasSpellTooltip)
end

local function RefreshRecap()
    if not ARL.db then
        subtitleText:SetText("Waiting for saved variables to load...")
        summaryText:SetText("")
        listText:SetText("")
        HideAllDeathRows()
        return
    end

    local encounter = ARL.db.lastWipeEncounter
    local wipeDate  = ARL.db.lastWipeDate
    local deaths    = ARL.db.lastWipeDeaths

    if encounter and encounter ~= "" then
        subtitleText:SetText(string.format(
            "Encounter: |cffffd100%s|r  –  %s",
            encounter,
            wipeDate ~= "" and wipeDate or "unknown time"
        ))
    else
        subtitleText:SetText("No wipe data recorded yet.")
    end

    if not deaths or #deaths == 0 then
        summaryText:SetText("No reliable death-cause data found.")
        listText:SetText("(C_DamageMeter did not provide death details for this wipe.)")
        listText:Show()
        HideAllDeathRows()

        -- Resize content to fit the message
        content:SetHeight(40)
        return
    end

    summaryText:SetText(string.format(
        "%d death%s recorded during this attempt. Hover spell names to inspect the killing spell.",
        #deaths,
        #deaths == 1 and "" or "s"
    ))

    listText:SetText("")
    listText:Hide()

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
end

-- ============================================================
-- Public API
-- ============================================================

function ARL.ShowDeathRecap()
    RefreshRecap()
    frame:Show()
    frame:Raise()
    -- Reset scroll to top
    scrollFrame:SetVerticalScroll(0)
end

function ARL.HideDeathRecap()
    frame:Hide()
end
