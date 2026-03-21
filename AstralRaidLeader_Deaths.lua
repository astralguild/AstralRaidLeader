-- AstralRaidLeader_Deaths.lua
-- Death Recap dashboard: shows who died, to what mechanic, during a raid wipe.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

local function Print(msg)
    print("|cff00ccff[AstralRaidLeader]|r " .. tostring(msg))
end

-- ============================================================
-- Frame construction
-- ============================================================

local FRAME_W, FRAME_H = 520, 430

local frame = CreateFrame("Frame", "AstralRaidLeaderDeathRecapFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(FRAME_W, FRAME_H)
frame:SetPoint("CENTER")
frame:SetClampedToScreen(true)
frame:SetFrameStrata("DIALOG")
frame:SetFrameLevel(110)
frame:SetToplevel(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:Hide()

if frame.TitleText then
    frame.TitleText:SetText("Death Recap")
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

-- Subtitle line (encounter + date)
local subtitleText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitleText:SetPoint("TOPLEFT", 16, -32)
subtitleText:SetWidth(FRAME_W - 40)
subtitleText:SetJustifyH("LEFT")
subtitleText:SetText("")

-- Summary line (e.g. "5 deaths recorded")
local summaryText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
summaryText:SetPoint("TOPLEFT", 16, -52)
summaryText:SetWidth(FRAME_W - 40)
summaryText:SetJustifyH("LEFT")
summaryText:SetText("")

-- Scroll frame for the death list
local scrollFrame = CreateFrame("ScrollFrame", "AstralRaidLeaderDeathScroll", frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT",  16, -80)
scrollFrame:SetPoint("BOTTOMRIGHT", -32, 44)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(scrollFrame:GetWidth() or (FRAME_W - 48), 1)
scrollFrame:SetScrollChild(content)

local listText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
listText:SetPoint("TOPLEFT", 4, -4)
listText:SetPoint("TOPRIGHT", -4, -4)
listText:SetJustifyH("LEFT")
listText:SetJustifyV("TOP")
listText:SetSpacing(3)
listText:SetText("")

-- Close button
local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
closeButton:SetPoint("BOTTOMRIGHT", -12, 12)
closeButton:SetSize(100, 24)
closeButton:SetText("Close")
closeButton:SetScript("OnClick", function() frame:Hide() end)

-- ============================================================
-- Populate helpers
-- ============================================================

local COLOR_PLAYER   = "|cffffff00"   -- yellow
local COLOR_MECHANIC = "|cffff4444"   -- red
local COLOR_SOURCE   = "|cffff8000"   -- orange
local COLOR_TIME     = "|cff888888"   -- grey
local COLOR_RESET    = "|r"

local function BuildDeathLine(i, entry)
    return string.format(
        "%2d. %s%s%s  died to %s%s%s  (from %s%s%s)  %sat %s%s",
        i,
        COLOR_PLAYER,   entry.playerName, COLOR_RESET,
        COLOR_MECHANIC, entry.mechanic,   COLOR_RESET,
        COLOR_SOURCE,   entry.source,     COLOR_RESET,
        COLOR_TIME,     entry.timeStr,    COLOR_RESET
    )
end

local function RefreshRecap()
    if not ARL.db then
        subtitleText:SetText("Waiting for saved variables to load...")
        summaryText:SetText("")
        listText:SetText("")
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
        summaryText:SetText("No deaths recorded.")
        listText:SetText("(No data – death tracking may have been disabled, or no wipe has occurred.)")

        -- Resize content to fit the message
        content:SetHeight(40)
        return
    end

    summaryText:SetText(string.format(
        "%d death%s recorded during this attempt.",
        #deaths,
        #deaths == 1 and "" or "s"
    ))

    local lines = {}
    for i, entry in ipairs(deaths) do
        lines[#lines + 1] = BuildDeathLine(i, entry)
    end
    listText:SetText(table.concat(lines, "\n"))

    -- Allow the content frame to resize so the scroll frame works correctly.
    listText:SetWidth((scrollFrame:GetWidth() or (FRAME_W - 48)) - 8)
    content:SetHeight(listText:GetStringHeight() + 12)
end

-- ============================================================
-- Public API
-- ============================================================

function ARL:ShowDeathRecap()
    RefreshRecap()
    frame:Show()
    frame:Raise()
    -- Reset scroll to top
    scrollFrame:SetVerticalScroll(0)
end

function ARL:HideDeathRecap()
    frame:Hide()
end
