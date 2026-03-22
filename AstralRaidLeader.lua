-- AstralRaidLeader.lua
-- Automatically passes Raid Leader to a configurable list of preferred
-- characters. When the player holds Raid Leader, the addon first tries to
-- promote the highest-priority preferred leader that is currently in the
-- group. If none are present, an event-driven reminder is shown when roster
-- state changes.

local ADDON_NAME = "AstralRaidLeader"

-- Addon namespace exposed as a global so other files / the console can reach it.
local ARL = {}
_G[ADDON_NAME] = ARL

-- ============================================================
-- Defaults
-- ============================================================

local DEFAULTS = {
    preferredLeaders       = {},    -- ordered list of character names (highest priority first)
    autoPromote            = true,  -- attempt to promote automatically on roster changes
    reminderEnabled        = true,  -- show event-driven reminders when holding an unwanted lead
    notifyEnabled          = true,  -- show a popup when manual promotion is available
    notifySound            = true,  -- play a UI sound when the popup is shown
    quietMode              = false, -- suppress all chat output when true
    groupTypeFilter        = "all", -- "all", "raid", or "party"
    consumableAuditEnabled = true,  -- run a consumable audit when a ready check fires
    trackedConsumables     = {},    -- user-defined additions (system defaults are always included)
    guildRankPriority      = {},    -- ordered list of {name, rankIndex} tables (highest priority first)
    useGuildRankPriority   = false, -- fall back to guild rank priority when no preferred leader is present
    -- Death tracking
    deathTrackingEnabled   = true,  -- record deaths during raid encounters
    showRecapOnWipe        = true,  -- automatically open the recap window after a wipe
    lastWipeDeaths         = {},    -- list of death records from the most recent wipe
    lastWipeEncounter      = "",    -- name of the encounter that wiped
    lastWipeDate           = "",    -- human-readable timestamp of the wipe
}

-- Built-in consumable categories - always checked, never stored in SavedVariables.
local SYSTEM_CONSUMABLES = {
    { label = "Flasks", spellIds = { 1235108, 1235111, 241320, 241324 } },
    { label = "Food",   spellIds = {}, namePatterns = { "Well Fed" } },
}

-- ============================================================
-- Helpers
-- ============================================================

local function Print(msg)
    if ARL.db and ARL.db.quietMode then return end
    print("|cff00ccff[AstralRaidLeader]|r " .. tostring(msg))
end

-- Shared UI helpers consumed by the options and death-recap windows.
ARL.UI = ARL.UI or {}

local function UISkinPanel(panel, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA)
    if not panel or not panel.SetBackdrop then return end
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    panel:SetBackdropColor(bgR, bgG, bgB, bgA)
    panel:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
end

local function UISkinActionButton(btn)
    if not btn or btn._arlSkinned then return end

    local regions = { btn:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetAlpha(0)
        end
    end

    if btn.Left and btn.Left.SetAlpha then btn.Left:SetAlpha(0) end
    if btn.Middle and btn.Middle.SetAlpha then btn.Middle:SetAlpha(0) end
    if btn.Right and btn.Right.SetAlpha then btn.Right:SetAlpha(0) end

    local normal = btn.GetNormalTexture and btn:GetNormalTexture() or nil
    if normal and normal.SetAlpha then normal:SetAlpha(0) end
    local pushed = btn.GetPushedTexture and btn:GetPushedTexture() or nil
    if pushed and pushed.SetAlpha then pushed:SetAlpha(0) end
    local highlight = btn.GetHighlightTexture and btn:GetHighlightTexture() or nil
    if highlight and highlight.SetAlpha then highlight:SetAlpha(0) end

    local skin = CreateFrame("Frame", nil, btn, BackdropTemplateMixin and "BackdropTemplate" or nil)
    skin:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    skin:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    skin:SetFrameLevel(math.max(1, btn:GetFrameLevel() - 1))
    skin:EnableMouse(false)
    UISkinPanel(skin, 0.10, 0.14, 0.20, 0.92, 0.30, 0.40, 0.54, 0.78)

    local function UpdateButtonState()
        if not btn:IsEnabled() then
            skin:SetBackdropColor(0.08, 0.10, 0.14, 0.72)
            skin:SetBackdropBorderColor(0.23, 0.29, 0.36, 0.56)
        elseif btn:IsMouseOver() then
            skin:SetBackdropColor(0.13, 0.18, 0.26, 0.95)
            skin:SetBackdropBorderColor(0.44, 0.56, 0.74, 0.88)
        else
            skin:SetBackdropColor(0.10, 0.14, 0.20, 0.92)
            skin:SetBackdropBorderColor(0.30, 0.40, 0.54, 0.78)
        end
    end

    btn:HookScript("OnEnter", UpdateButtonState)
    btn:HookScript("OnLeave", UpdateButtonState)
    btn:HookScript("OnEnable", UpdateButtonState)
    btn:HookScript("OnDisable", UpdateButtonState)
    btn:HookScript("OnShow", UpdateButtonState)

    local text = btn.Text or btn:GetFontString()
    if text and text.SetTextColor then
        text:SetTextColor(0.90, 0.92, 0.96)
    end

    btn._arlSkinned = true
end

ARL.UI.SkinPanel = UISkinPanel
ARL.UI.SkinActionButton = UISkinActionButton

-- Initialise (or migrate) the saved-variable database.
local function InitDB()
    if type(AstralRaidLeaderDB) ~= "table" then
        AstralRaidLeaderDB = {}
    end
    local function DeepCopy(orig)
        local copy = {}
        for k, v in pairs(orig) do
            copy[k] = type(v) == "table" and DeepCopy(v) or v
        end
        return copy
    end

    for k, v in pairs(DEFAULTS) do
        if AstralRaidLeaderDB[k] == nil then
            AstralRaidLeaderDB[k] = type(v) == "table" and DeepCopy(v) or v
        end
    end
    ARL.db = AstralRaidLeaderDB
end

-- Return a lookup table { lowercaseName -> originalName } of every current
-- group / raid member.
local function GetGroupMemberMap()
    local members = {}

    local function AddName(name)
        if not name or name == "" then return end
        -- Strip the realm suffix (e.g. "Thrall-Silvermoon" -> "Thrall")
        local shortName = name:match("^([^%-]+)") or name
        members[shortName:lower()] = name
        members[name:lower()] = name
    end

    if IsInRaid() then
        local n = GetNumGroupMembers()
        for i = 1, n do
            AddName(GetRaidRosterInfo(i))
        end
    elseif IsInGroup() then
        AddName(UnitName("player"))
        local n = GetNumSubgroupMembers()
        for i = 1, n do
            AddName(UnitName("party" .. i))
        end
    end

    return members
end

-- Return true when the current group type matches the configured groupTypeFilter.
local function IsInRelevantGroup()
    local inRaid  = IsInRaid()
    local inGroup = IsInGroup()
    if not (inRaid or inGroup) then return false end
    local filter = ARL.db and ARL.db.groupTypeFilter or "all"
    if filter == "raid"  then return inRaid end
    if filter == "party" then return inGroup and not inRaid end
    return true  -- "all"
end

-- ============================================================
-- Auto-promote logic
-- ============================================================

-- Return the highest-priority preferred leader currently in the group.
-- Returns preferredName, rosterName or nil, nil when no match is found.
local function GetTopAvailablePreferredLeader()
    local memberMap = GetGroupMemberMap()

    for _, leaderName in ipairs(ARL.db.preferredLeaders) do
        local normalized = leaderName:lower()
        local shortName = (leaderName:match("^([^%-]+)") or leaderName):lower()
        local target = memberMap[normalized] or memberMap[shortName]
        if target then
            return leaderName, target
        end
    end

    return nil, nil
end

local RequestGuildRosterIfStale

-- Build a map of { name:lower() -> {rankName, rankIndex} } for all guild members
-- using the cached guild roster.  rankIndex is 1-based (matches GuildControlGetRankName).
-- Returns an empty table when the player is not in a guild.
local function GetGuildMemberRankMap()
    if not IsInGuild() then return {} end
    local rankMap = {}
    local numMembers = GetNumGuildMembers()
    if numMembers == 0 then
        RequestGuildRosterIfStale()
        return rankMap
    end
    for i = 1, numMembers do
        -- GetGuildRosterInfo: name, rankName, rankIndex (0-based), ...
        local name, rankName, rankIndex0 = GetGuildRosterInfo(i)
        if name and rankName then
            local shortName = (name:match("^([^%-]+)") or name):lower()
            -- Convert 0-based rankIndex to 1-based so it aligns with GuildControlGetRankName(i).
            local entry = { rankName = rankName, rankIndex = (tonumber(rankIndex0) or 0) + 1 }
            rankMap[shortName]    = entry
            rankMap[name:lower()] = entry
        end
    end
    return rankMap
end

-- Return the highest-priority group member found via the guild rank priority list.
-- Skips the current player (who already holds leadership).
-- Returns rankName, rosterName or nil, nil.
-- Priority entries may be plain strings (legacy) or {name, rankIndex} tables.
-- When rankIndex is known, matching is done by index so duplicate-named ranks are
-- handled correctly.
local function GetTopAvailableByGuildRank()
    if not ARL.db.useGuildRankPriority then return nil, nil end
    if #ARL.db.guildRankPriority == 0 then return nil, nil end
    if not IsInGuild() then return nil, nil end

    local memberMap    = GetGroupMemberMap()
    local guildRankMap = GetGuildMemberRankMap()
    local playerName   = UnitName("player")

    for _, priorityEntry in ipairs(ARL.db.guildRankPriority) do
        -- Support legacy string entries and new {name, rankIndex} table entries.
        local priorityName  = type(priorityEntry) == "table" and priorityEntry.name  or tostring(priorityEntry)
        local priorityIndex = type(priorityEntry) == "table" and (priorityEntry.rankIndex or 0) or 0
        local priorityLower = priorityName:lower()

        for memberLower, memberName in pairs(memberMap) do
            local memberData = guildRankMap[memberLower]
            if memberData then
                local matched
                if priorityIndex > 0 and memberData.rankIndex and memberData.rankIndex > 0 then
                    -- Unambiguous: compare by rank slot index.
                    matched = (memberData.rankIndex == priorityIndex)
                else
                    -- Fall back to name comparison for legacy entries.
                    matched = (memberData.rankName:lower() == priorityLower)
                end
                if matched and (not playerName or memberName:lower() ~= playerName:lower()) then
                    return priorityName, memberName
                end
            end
        end
    end

    return nil, nil
end

-- Try to promote the highest-priority preferred leader found in the group.
-- Falls back to guild rank priority when no preferred leader is present and
-- useGuildRankPriority is enabled.
-- Returns true if a promotion was issued, false otherwise.
local function TryAutoPromote()
    if not UnitIsGroupLeader("player") then return false end
    if not IsInRelevantGroup() then return false end

    local leaderName, target = GetTopAvailablePreferredLeader()
    if leaderName and target then
        PromoteToLeader(target)
        Print(string.format("Promoted |cffffd100%s|r to Raid Leader.", leaderName))
        ARL:CancelReminder()
        ARL:HideManualPromotePopup()
        return true
    end

    -- Fall back to guild rank priority when no preferred leader is in the group.
    if ARL.db.useGuildRankPriority and #ARL.db.guildRankPriority > 0 then
        local rankName, rankTarget = GetTopAvailableByGuildRank()
        if rankName and rankTarget then
            PromoteToLeader(rankTarget)
            Print(string.format("Promoted |cffffd100%s|r to Raid Leader (guild rank: %s).", rankTarget, rankName))
            ARL:CancelReminder()
            ARL:HideManualPromotePopup()
            return true
        end
    end

    return false
end

-- ============================================================
-- Manual promote popup (when auto-promote is disabled)
-- ============================================================

local notifyCooldownSeconds = 20
local lastNotifyAt = 0
local pendingNotifyName = nil
local lastGroupMemberCount = 0
local guildRosterRequestThrottleSeconds = 10
local lastGuildRosterRequestAt = 0

RequestGuildRosterIfStale = function()
    if not IsInGuild() then return end
    local now = GetTime()
    if (now - lastGuildRosterRequestAt) < guildRosterRequestThrottleSeconds then return end
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
    lastGuildRosterRequestAt = now
end

StaticPopupDialogs["ASTRALRAIDLEADER_MANUAL_PROMOTE"] = {
    text = "A promotion candidate is in your group: %s\n\nPromote now?",
    button1 = "Promote",
    button2 = "Not Now",
    OnAccept = function()
        TryAutoPromote()
    end,
    OnCancel = function()
        -- "Not Now" snoozes the popup; it can reappear after cooldown on later triggers.
        lastNotifyAt = GetTime()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = STATICPOPUP_NUMDIALOGS,
}

function ARL:HideManualPromotePopup()
    pendingNotifyName = nil
    StaticPopup_Hide("ASTRALRAIDLEADER_MANUAL_PROMOTE")
end

function ARL:ShowManualPromotePopup(preferredName, bypassCooldown)
    if not self.db.notifyEnabled then return end
    if self.db.autoPromote then return end
    local hasPreferredLeaders    = #self.db.preferredLeaders > 0
    local hasGuildRankPriority   = self.db.useGuildRankPriority and #self.db.guildRankPriority > 0
    if not hasPreferredLeaders and not hasGuildRankPriority then return end
    if not UnitIsGroupLeader("player") then return end
    if not IsInRelevantGroup() then return end

    local memberMap = GetGroupMemberMap()
    local normalized = (preferredName or ""):lower()
    local shortName = ((preferredName or ""):match("^([^%-]+)") or preferredName or ""):lower()
    if not (memberMap[normalized] or memberMap[shortName]) then return end

    if InCombatLockdown() then
        pendingNotifyName = preferredName
        return
    end

    local now = GetTime()
    if not bypassCooldown and (now - lastNotifyAt) < notifyCooldownSeconds then return end
    if StaticPopup_Visible("ASTRALRAIDLEADER_MANUAL_PROMOTE") then return end

    pendingNotifyName = nil
    lastNotifyAt = now
    StaticPopup_Show("ASTRALRAIDLEADER_MANUAL_PROMOTE", preferredName)
    if self.db.notifySound then
        PlaySound(SOUNDKIT.READY_CHECK, "Master")
    end
end

function ARL:TryShowPendingManualPromotePopup()
    if not pendingNotifyName then return end
    self:ShowManualPromotePopup(pendingNotifyName, true)
end

local StartReminder

local function PrintLeaderReminderMessage()
    local parts = {}
    if #ARL.db.preferredLeaders > 0 then
        parts[#parts + 1] = "Preferred leader(s): |cffffd100"
            .. table.concat(ARL.db.preferredLeaders, ", ") .. "|r"
    end
    if ARL.db.useGuildRankPriority and #ARL.db.guildRankPriority > 0 then
        local rankNames = {}
        for _, e in ipairs(ARL.db.guildRankPriority) do
            rankNames[#rankNames + 1] = type(e) == "table" and e.name or tostring(e)
        end
        parts[#parts + 1] = "guild rank priority: |cffffd100"
            .. table.concat(rankNames, ", ") .. "|r"
    end
    local detail = #parts > 0 and (" " .. table.concat(parts, "; ") .. ".") or ""
    Print("Reminder: You are the Raid Leader." .. detail
        .. " Use |cffffff00/arl promote|r to hand off when they join.")
end

local function EvaluateLeaderState(trigger)
    if not ARL.db then return end
    local hasPreferredLeaders  = #ARL.db.preferredLeaders > 0
    local hasGuildRankPriority = ARL.db.useGuildRankPriority and #ARL.db.guildRankPriority > 0
    if not hasPreferredLeaders and not hasGuildRankPriority then
        ARL:CancelReminder()
        ARL:HideManualPromotePopup()
        return
    end

    if not UnitIsGroupLeader("player") or not IsInRelevantGroup() then
        ARL:CancelReminder()
        ARL:HideManualPromotePopup()
        return
    end

    if ARL.db.autoPromote then
        ARL:HideManualPromotePopup()
        local ok = TryAutoPromote()
        if not ok then StartReminder(trigger) end
        return
    end

    local preferredName = GetTopAvailablePreferredLeader()
    -- Fall back to a guild rank candidate for the popup when no preferred leader
    -- is present but guild rank priority is enabled.
    if not preferredName and ARL.db.useGuildRankPriority then
        local _, rankTarget = GetTopAvailableByGuildRank()
        preferredName = rankTarget
    end
    if not preferredName then
        StartReminder(trigger)
        ARL:HideManualPromotePopup()
        return
    end

    -- New-member and instance-change events should surface the action promptly.
    local bypassCooldown = (trigger == "new_member" or trigger == "instance_change")
    ARL:ShowManualPromotePopup(preferredName, bypassCooldown)
end

-- ============================================================
-- Consumable audit (triggered on READY_CHECK)
-- ============================================================

-- Return true when unit currently has a buff with the given spell ID.
-- the deprecated multi-return UnitBuff signature removed in 11.0+.
local function HasBuff(unit, spellId)
    local i = 1
    while i <= 64 do
        local buffData = C_UnitAuras.GetBuffDataByIndex(unit, i)
        if not buffData then break end
        if buffData.spellId == spellId then return true end
        i = i + 1
    end
    return false
end

-- Return the index, table, and isSystem flag for the consumable category matching label.
local function FindConsumableCategory(label)
    local lower = label:lower()
    for i, cat in ipairs(SYSTEM_CONSUMABLES) do
        if cat.label:lower() == lower then
            return i, cat, true
        end
    end
    for i, cat in ipairs(ARL.db.trackedConsumables) do
        if cat.label:lower() == lower then
            return i, cat, false
        end
    end
    return nil, nil, false
end

-- Scan all group members for missing tracked consumable buffs and print a report.
-- Pass force=true to run even when solo (e.g. from the settings UI).
local function RunConsumableAudit(force)
    if not ARL.db or not ARL.db.consumableAuditEnabled then return end
    if not force and not IsInRelevantGroup() then return end

    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
    else
        units[#units + 1] = "player"
        for i = 1, GetNumSubgroupMembers() do
            units[#units + 1] = "party" .. i
        end
    end

    -- Build full list: system defaults + user additions.
    local allConsumables = {}
    for _, cat in ipairs(SYSTEM_CONSUMABLES) do allConsumables[#allConsumables + 1] = cat end
    for _, cat in ipairs(ARL.db.trackedConsumables) do allConsumables[#allConsumables + 1] = cat end
    if #allConsumables == 0 then return end

    local missing = {}
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local name = UnitName(unit)
            if name and name ~= "" then
                local missingCats = {}
                for _, consumable in ipairs(allConsumables) do
                    local hasIt = false
                    for _, spellId in ipairs(consumable.spellIds) do
                        if HasBuff(unit, spellId) then
                            hasIt = true
                            break
                        end
                    end
                    -- Fall back to buff-name substring matching (e.g. "Well Fed" food buffs).
                    if not hasIt and consumable.namePatterns then
                        for _, pattern in ipairs(consumable.namePatterns) do
                            local j = 1
                            while j <= 64 do
                                local aura = C_UnitAuras.GetBuffDataByIndex(unit, j)
                                if not aura then break end
                                if aura.name and aura.name:find(pattern, 1, true) then
                                    hasIt = true
                                    break
                                end
                                j = j + 1
                            end
                            if hasIt then break end
                        end
                    end
                    if not hasIt then
                        missingCats[#missingCats + 1] = consumable.label
                    end
                end
                if #missingCats > 0 then
                    missing[#missing + 1] = { name = name, cats = missingCats }
                end
            end
        end
    end

    if #missing == 0 then
        Print("Ready check: All group members have their consumables!")
    else
        Print(string.format("Ready check: %d group member(s) missing consumables:", #missing))
        for _, entry in ipairs(missing) do
            Print(string.format("  |cffffd100%s|r – missing: |cffff6666%s|r",
                entry.name, table.concat(entry.cats, ", ")))
        end
    end
end

-- Expose audit entry points on the ARL namespace so other files
-- (e.g. the Options window) can invoke them without going through
-- the slash-command dispatcher.
ARL.RunConsumableAudit     = RunConsumableAudit
ARL.FindConsumableCategory = FindConsumableCategory
ARL.SYSTEM_CONSUMABLES     = SYSTEM_CONSUMABLES


function ARL:CancelReminder()
    -- Event-driven reminders do not keep timer state.
end

StartReminder = function(trigger)
    if not ARL.db or not ARL.db.reminderEnabled then return end
    local hasPreferredLeaders  = #ARL.db.preferredLeaders > 0
    local hasGuildRankPriority = ARL.db.useGuildRankPriority and #ARL.db.guildRankPriority > 0
    if not hasPreferredLeaders and not hasGuildRankPriority then return end
    if not UnitIsGroupLeader("player") or not IsInRelevantGroup() then return end

    -- Event-driven reminders: only announce on join/world-change style triggers.
    if trigger ~= "new_member" and trigger ~= "instance_change" then return end

    PrintLeaderReminderMessage()
end

-- ============================================================
-- Event handling
-- ============================================================

local HandleDeathTrackingEvent

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("READY_CHECK")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        InitDB()
        lastGroupMemberCount = GetNumGroupMembers()
        RequestGuildRosterIfStale()
        Print("Loaded. Type |cffffff00/arl help|r for commands.")

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- db may already be set from PLAYER_LOGIN; guard against double-init.
        if not ARL.db then InitDB() end
        lastGroupMemberCount = GetNumGroupMembers()
        RequestGuildRosterIfStale()
        EvaluateLeaderState("instance_change")

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        EvaluateLeaderState("instance_change")

    elseif event == "PLAYER_REGEN_ENABLED" then
        ARL:TryShowPendingManualPromotePopup()

    elseif event == "READY_CHECK" then
        RunConsumableAudit()

    elseif event == "ENCOUNTER_START" or event == "ENCOUNTER_END"
    then
        if HandleDeathTrackingEvent then
            HandleDeathTrackingEvent(event, ...)
        end

    elseif event == "GUILD_ROSTER_UPDATE" then
        EvaluateLeaderState("roster")

    elseif event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" then
        local currentCount = GetNumGroupMembers()
        local trigger = "roster"
        if currentCount > lastGroupMemberCount then
            trigger = "new_member"
        end
        lastGroupMemberCount = currentCount
        EvaluateLeaderState(trigger)
    end
end)

-- ============================================================
-- Death tracking
-- ============================================================

-- Per-session state (not persisted).
local currentEncounterDeaths = {}   -- death records for the active encounter
local currentEncounterName   = ""
local currentEncounterStart  = 0
local inEncounter            = false
local currentEncounterID     = 0

-- Format seconds as M:SS for the recap display.
local function FormatEncounterTime(seconds)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%d:%02d", m, s)
end

local function BuildDeathsFromDamageMeter()
    if not C_DamageMeter or type(C_DamageMeter.GetCombatSessionFromID) ~= "function" then
        return {}
    end

    local sessionId = nil
    if type(C_DamageMeter.GetCurrentCombatSessionID) == "function" then
        sessionId = C_DamageMeter.GetCurrentCombatSessionID()
    elseif type(C_DamageMeter.GetLastCombatSessionID) == "function" then
        sessionId = C_DamageMeter.GetLastCombatSessionID()
    end

    if (not sessionId or sessionId == 0) and currentEncounterID ~= 0 and type(C_DamageMeter.GetCombatSessionIDByEncounterID) == "function" then
        sessionId = C_DamageMeter.GetCombatSessionIDByEncounterID(currentEncounterID)
    end

    if not sessionId then return {} end

    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, sessionId)
    if not ok or type(session) ~= "table" then return {} end

    local deathList = session.deaths or session.Deaths or session.deathLog or session.DeathLog
    if type(deathList) ~= "table" then return {} end

    local results = {}
    for _, entry in ipairs(deathList) do
        if type(entry) == "table" then
            local playerName = entry.playerName or entry.destName or entry.name or entry.player or "Unknown"
            local mechanic   = entry.mechanic or entry.spellName or entry.abilityName or entry.cause or "Unknown"
            local source     = entry.sourceName or entry.source or entry.killerName or "Unknown"
            local timeOffset = tonumber(entry.timeOffset or entry.elapsedTime or entry.time) or 0
            if timeOffset < 0 then timeOffset = 0 end
            results[#results + 1] = {
                playerName = playerName,
                mechanic   = mechanic,
                source     = source,
                timeOffset = timeOffset,
                timeStr    = FormatEncounterTime(math.floor(timeOffset)),
            }
        end
    end

    return results
end

HandleDeathTrackingEvent = function(event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        currentEncounterID     = tonumber(encounterID) or 0
        currentEncounterName   = encounterName or "Unknown"
        currentEncounterStart  = GetTime()
        currentEncounterDeaths = {}
        inEncounter            = true

    elseif event == "ENCOUNTER_END" then
        local _, encounterName, _, _, success = ...
        inEncounter = false

        if success == 0 and ARL.db and ARL.db.deathTrackingEnabled then
            local deaths = BuildDeathsFromDamageMeter()
            if #deaths > 0 then
                currentEncounterDeaths = deaths
            end

            -- Persist deaths recorded for this attempt.
            ARL.db.lastWipeDeaths    = currentEncounterDeaths
            ARL.db.lastWipeEncounter = encounterName or currentEncounterName
            ARL.db.lastWipeDate      = date("%Y-%m-%d %H:%M")
            Print(string.format(
                "Wipe recorded on |cffffd100%s|r – %d death(s). Type |cffffff00/arl deaths|r to view the recap.",
                ARL.db.lastWipeEncounter,
                #currentEncounterDeaths
            ))
            if ARL.db.showRecapOnWipe and ARL.ShowDeathRecap then
                ARL:ShowDeathRecap()
            end
        end

        currentEncounterDeaths = {}
        currentEncounterID     = 0
    end
end

-- ============================================================
-- Slash commands
-- ============================================================

SLASH_ASTRALRAIDLEADER1 = "/arl"
SLASH_ASTRALRAIDLEADER2 = "/astralraidleader"

SlashCmdList["ASTRALRAIDLEADER"] = function(msg)
    if not ARL.db then
        Print("Not fully loaded yet. Please wait a moment.")
        return
    end

    -- Split into command + optional argument.
    local cmd, arg = msg:match("^(%S+)%s*(.*)")
    if not cmd then cmd = "" end
    cmd = cmd:lower()
    arg = arg or ""

    -- /arl add <name>
    if cmd == "add" then
        if arg == "" then
            Print("Usage: /arl add <CharacterName>")
            return
        end
        for _, name in ipairs(ARL.db.preferredLeaders) do
            if name:lower() == arg:lower() then
                Print(string.format("|cffffd100%s|r is already in the preferred leaders list.", arg))
                return
            end
        end
        table.insert(ARL.db.preferredLeaders, arg)
        Print(string.format("Added |cffffd100%s|r to the preferred leaders list.", arg))

    -- /arl remove <name>
    elseif cmd == "remove" then
        if arg == "" then
            Print("Usage: /arl remove <CharacterName>")
            return
        end
        for i, name in ipairs(ARL.db.preferredLeaders) do
            if name:lower() == arg:lower() then
                table.remove(ARL.db.preferredLeaders, i)
                Print(string.format("Removed |cffffd100%s|r from the preferred leaders list.", name))
                return
            end
        end
        Print(string.format("|cffffd100%s|r was not found in the preferred leaders list.", arg))

    -- /arl list
    elseif cmd == "list" then
        if #ARL.db.preferredLeaders == 0 then
            Print("The preferred leaders list is empty. Add names with /arl add <name>.")
        else
            Print("Preferred leaders (highest priority first):")
            for i, name in ipairs(ARL.db.preferredLeaders) do
                Print(string.format("  %d. |cffffd100%s|r", i, name))
            end
        end

    -- /arl clear
    elseif cmd == "clear" then
        ARL.db.preferredLeaders = {}
        ARL:CancelReminder()
        ARL:HideManualPromotePopup()
        Print("Cleared the preferred leaders list.")

    -- /arl promote   (manual one-shot)
    elseif cmd == "promote" then
        if not UnitIsGroupLeader("player") then
            Print("You are not the Raid / Group Leader.")
            return
        end
        local ok = TryAutoPromote()
        if not ok then
            Print("None of your preferred leaders are currently in the group.")
        end

    -- /arl auto [on|off]
    elseif cmd == "auto" then
        if arg:lower() == "on" then
            ARL.db.autoPromote = true
            Print("Auto-promote |cff00ff00enabled|r.")
        elseif arg:lower() == "off" then
            ARL.db.autoPromote = false
            Print("Auto-promote |cffff0000disabled|r.")
        else
            Print(string.format("Auto-promote is currently |cff%s%s|r.",
                ARL.db.autoPromote and "00ff00" or "ff0000",
                ARL.db.autoPromote and "enabled" or "disabled"))
        end

    -- /arl reminder [on|off]
    elseif cmd == "reminder" then
        local lower = arg:lower()
        if lower == "on" then
            ARL.db.reminderEnabled = true
            Print("Reminder |cff00ff00enabled|r.")
        elseif lower == "off" then
            ARL.db.reminderEnabled = false
            ARL:CancelReminder()
            Print("Reminder |cffff0000disabled|r.")
        elseif arg ~= "" then
            Print("Reminder is event-driven now. Usage: /arl reminder [on|off]")
        else
            Print(string.format(
                "Reminder is |cff%s%s|r. Trigger: |cffffff00member join / instance change|r.",
                ARL.db.reminderEnabled and "00ff00" or "ff0000",
                ARL.db.reminderEnabled and "enabled" or "disabled"
            ))
        end

    -- /arl notify [on|off]
    elseif cmd == "notify" then
        if arg:lower() == "on" then
            ARL.db.notifyEnabled = true
            Print("Manual-promote popup |cff00ff00enabled|r.")
        elseif arg:lower() == "off" then
            ARL.db.notifyEnabled = false
            ARL:HideManualPromotePopup()
            Print("Manual-promote popup |cffff0000disabled|r.")
        else
            Print(string.format("Manual-promote popup is currently |cff%s%s|r.",
                ARL.db.notifyEnabled and "00ff00" or "ff0000",
                ARL.db.notifyEnabled and "enabled" or "disabled"))
        end

    -- /arl notifysound [on|off]
    elseif cmd == "notifysound" then
        if arg:lower() == "on" then
            ARL.db.notifySound = true
            Print("Manual-promote popup sound |cff00ff00enabled|r.")
        elseif arg:lower() == "off" then
            ARL.db.notifySound = false
            Print("Manual-promote popup sound |cffff0000disabled|r.")
        else
            Print(string.format("Manual-promote popup sound is currently |cff%s%s|r.",
                ARL.db.notifySound and "00ff00" or "ff0000",
                ARL.db.notifySound and "enabled" or "disabled"))
        end

    -- /arl move <name> <position>
    elseif cmd == "move" then
        local name, posStr = arg:match("^(%S+)%s+(%S+)$")
        if not name or not posStr then
            Print("Usage: /arl move <name> <position>")
            return
        end
        local pos = tonumber(posStr)
        if not pos or pos < 1 then
            Print("Position must be a positive integer.")
            return
        end
        local foundAt = nil
        for i, n in ipairs(ARL.db.preferredLeaders) do
            if n:lower() == name:lower() then
                foundAt = i
                break
            end
        end
        if not foundAt then
            Print(string.format("|cffffd100%s|r was not found in the preferred leaders list.", name))
            return
        end
        pos = math.min(pos, #ARL.db.preferredLeaders)
        if foundAt == pos then
            Print(string.format("|cffffd100%s|r is already at position %d.", ARL.db.preferredLeaders[foundAt], pos))
            return
        end
        local entry = table.remove(ARL.db.preferredLeaders, foundAt)
        table.insert(ARL.db.preferredLeaders, pos, entry)
        Print(string.format("Moved |cffffd100%s|r to position %d.", entry, pos))

    -- /arl quiet [on|off]
    elseif cmd == "quiet" then
        if arg:lower() == "on" then
            ARL.db.quietMode = true
            -- This is the last thing we print before going silent.
            Print("Quiet mode |cff00ff00enabled|r. Chat output suppressed.")
        elseif arg:lower() == "off" then
            ARL.db.quietMode = false
            Print("Quiet mode |cffff0000disabled|r.")
        else
            Print(string.format("Quiet mode is currently |cff%s%s|r.",
                ARL.db.quietMode and "00ff00" or "ff0000",
                ARL.db.quietMode and "enabled" or "disabled"))
        end

    -- /arl consumable [list|add|remove|delete|clear|audit]
    elseif cmd == "consumable" then
        local subcmd, rest = arg:match("^(%S+)%s*(.*)")
        if not subcmd then subcmd = "" end
        subcmd = subcmd:lower()
        rest = rest or ""

        if subcmd == "list" then
            if #ARL.db.trackedConsumables == 0 then
                Print("No consumables are being tracked. Use |cffffff00/arl consumable add <label> <spellId>|r to add one.")
            else
                Print("Tracked consumables:")
                for i, cat in ipairs(ARL.db.trackedConsumables) do
                    local parts = {}
                    if #cat.spellIds > 0 then
                        parts[#parts + 1] = "spell IDs: " .. table.concat(cat.spellIds, ", ")
                    end
                    if cat.namePatterns and #cat.namePatterns > 0 then
                        parts[#parts + 1] = 'names: "' .. table.concat(cat.namePatterns, '", "') .. '"'
                    end
                    Print(string.format("  %d. |cffffd100%s|r - %s",
                        i, cat.label, #parts > 0 and table.concat(parts, "; ") or "(empty)"))
                end
            end

        elseif subcmd == "add" then
            local label, idStr = rest:match("^(.-)%s+(%d+)$")
            if not label or label == "" or not idStr then
                Print("Usage: /arl consumable add <label> <spellId>")
                return
            end
            local spellId = tonumber(idStr)
            if not spellId or spellId < 1 then
                Print("Invalid spell ID. Must be a positive integer.")
                return
            end
            local _, cat = FindConsumableCategory(label)
            if cat then
                for _, id in ipairs(cat.spellIds) do
                    if id == spellId then
                        Print(string.format("Spell ID %d is already in the |cffffd100%s|r category.", spellId, cat.label))
                        return
                    end
                end
                table.insert(cat.spellIds, spellId)
                Print(string.format("Added spell ID %d to |cffffd100%s|r.", spellId, cat.label))
            else
                table.insert(ARL.db.trackedConsumables, { label = label, spellIds = { spellId } })
                Print(string.format("Created new category |cffffd100%s|r with spell ID %d.", label, spellId))
            end

        elseif subcmd == "remove" then
            local label, idStr = rest:match("^(.-)%s+(%d+)$")
            if not label or label == "" or not idStr then
                Print("Usage: /arl consumable remove <label> <spellId>")
                return
            end
            local spellId = tonumber(idStr)
            local idx, cat = FindConsumableCategory(label)
            if not cat then
                Print(string.format("Category |cffffd100%s|r not found.", label))
                return
            end
            for i, id in ipairs(cat.spellIds) do
                if id == spellId then
                    table.remove(cat.spellIds, i)
                    Print(string.format("Removed spell ID %d from |cffffd100%s|r.", spellId, cat.label))
                    if #cat.spellIds == 0 then
                        table.remove(ARL.db.trackedConsumables, idx)
                        Print(string.format("Category |cffffd100%s|r removed (no spell IDs remaining).", cat.label))
                    end
                    return
                end
            end
            Print(string.format("Spell ID %d was not found in |cffffd100%s|r.", spellId, cat.label))

        elseif subcmd == "delete" then
            if rest == "" then
                Print("Usage: /arl consumable delete <label>")
                return
            end
            local idx, cat = FindConsumableCategory(rest)
            if not cat then
                Print(string.format("Category |cffffd100%s|r not found.", rest))
                return
            end
            table.remove(ARL.db.trackedConsumables, idx)
            Print(string.format("Deleted category |cffffd100%s|r.", cat.label))

        elseif subcmd == "clear" then
            ARL.db.trackedConsumables = {}
            Print("Cleared all tracked consumable categories.")

        elseif subcmd == "audit" then
            RunConsumableAudit(true)  -- force=true so it works solo

        else
            Print("Consumable sub-commands:")
            Print("  |cffffff00/arl consumable list|r                        – List tracked consumable categories")
            Print("  |cffffff00/arl consumable add <label> <spellId>|r       – Add a spell ID to a category")
            Print("  |cffffff00/arl consumable remove <label> <spellId>|r    – Remove a spell ID from a category")
            Print("  |cffffff00/arl consumable delete <label>|r              – Delete an entire category")
            Print("  |cffffff00/arl consumable clear|r                       – Remove all tracked consumable categories")
            Print("  |cffffff00/arl consumable audit|r                       – Run the consumable audit now")
        end

    -- /arl consumableaudit [on|off]
    elseif cmd == "consumableaudit" then
        if arg:lower() == "on" then
            ARL.db.consumableAuditEnabled = true
            Print("Consumable audit on ready check |cff00ff00enabled|r.")
        elseif arg:lower() == "off" then
            ARL.db.consumableAuditEnabled = false
            Print("Consumable audit on ready check |cffff0000disabled|r.")
        else
            Print(string.format("Consumable audit on ready check is currently |cff%s%s|r.",
                ARL.db.consumableAuditEnabled and "00ff00" or "ff0000",
                ARL.db.consumableAuditEnabled and "enabled" or "disabled"))
        end

    -- /arl grouptype [all|raid|party]
    elseif cmd == "grouptype" then
        local lower = arg:lower()
        if lower == "all" or lower == "raid" or lower == "party" then
            ARL.db.groupTypeFilter = lower
            local labels = { all = "all groups", raid = "raids only", party = "parties only" }
            Print(string.format("Group type filter set to |cffffff00%s|r.", labels[lower]))
        elseif arg == "" then
            local labels = { all = "all groups", raid = "raids only", party = "parties only" }
            Print(string.format("Group type filter is |cffffff00%s|r.",
                labels[ARL.db.groupTypeFilter] or ARL.db.groupTypeFilter))
        else
            Print("Usage: /arl grouptype [all|raid|party]")
        end

    -- /arl rankpriority [on|off]
    elseif cmd == "rankpriority" then
        if arg:lower() == "on" then
            ARL.db.useGuildRankPriority = true
            Print("Guild rank priority |cff00ff00enabled|r.")
        elseif arg:lower() == "off" then
            ARL.db.useGuildRankPriority = false
            Print("Guild rank priority |cffff0000disabled|r.")
        else
            Print(string.format("Guild rank priority is currently |cff%s%s|r.",
                ARL.db.useGuildRankPriority and "00ff00" or "ff0000",
                ARL.db.useGuildRankPriority and "enabled" or "disabled"))
        end

    -- /arl addrank <rankname>
    elseif cmd == "addrank" then
        if arg == "" then
            Print("Usage: /arl addrank <GuildRankName>")
            return
        end
        -- Resolve the rank index so duplicate-named ranks are stored unambiguously.
        local resolvedIndex = 0
        if IsInGuild() then
            local numRanks = GuildControlGetNumRanks()
            for ri = 1, numRanks do
                if (GuildControlGetRankName(ri) or ""):lower() == arg:lower() then
                    resolvedIndex = ri
                    break
                end
            end
        end
        for _, entry in ipairs(ARL.db.guildRankPriority) do
            local entryName  = type(entry) == "table" and entry.name  or tostring(entry)
            local entryIndex = type(entry) == "table" and (entry.rankIndex or 0) or 0
            local isDup = (resolvedIndex > 0 and entryIndex == resolvedIndex)
                       or (resolvedIndex == 0 and entryName:lower() == arg:lower())
            if isDup then
                Print(string.format("|cffffd100%s|r is already in the guild rank priority list.", arg))
                return
            end
        end
        table.insert(ARL.db.guildRankPriority, { name = arg, rankIndex = resolvedIndex })
        Print(string.format("Added |cffffd100%s|r to the guild rank priority list.", arg))

    -- /arl removerank <rankname>
    elseif cmd == "removerank" then
        if arg == "" then
            Print("Usage: /arl removerank <GuildRankName>")
            return
        end
        for i, entry in ipairs(ARL.db.guildRankPriority) do
            local entryName = type(entry) == "table" and entry.name or tostring(entry)
            if entryName:lower() == arg:lower() then
                table.remove(ARL.db.guildRankPriority, i)
                Print(string.format("Removed |cffffd100%s|r from the guild rank priority list.", entryName))
                return
            end
        end
        Print(string.format("|cffffd100%s|r was not found in the guild rank priority list.", arg))

    -- /arl ranklist
    elseif cmd == "ranklist" then
        if #ARL.db.guildRankPriority == 0 then
            Print("The guild rank priority list is empty. Add ranks with /arl addrank <rankname>.")
        else
            Print("Guild rank priority (highest priority first):")
            for i, entry in ipairs(ARL.db.guildRankPriority) do
                local entryName = type(entry) == "table" and entry.name or tostring(entry)
                Print(string.format("  %d. |cffffd100%s|r", i, entryName))
            end
        end

    -- /arl clearranks
    elseif cmd == "clearranks" then
        ARL.db.guildRankPriority = {}
        Print("Cleared the guild rank priority list.")

    -- /arl moverank <rankname> <position>
    elseif cmd == "moverank" then
        -- Use a pattern that captures the position number from the end, allowing
        -- rank names that contain spaces (e.g. "Senior Officer 2").
        local name, posStr = arg:match("^(.-)%s+(%d+)%s*$")
        if not name or not posStr or name == "" then
            Print("Usage: /arl moverank <rankname> <position>")
            return
        end
        local pos = tonumber(posStr)
        if not pos or pos < 1 then
            Print("Position must be a positive integer.")
            return
        end
        local foundAt = nil
        for i, r in ipairs(ARL.db.guildRankPriority) do
            local rName = type(r) == "table" and r.name or tostring(r)
            if rName:lower() == name:lower() then
                foundAt = i
                break
            end
        end
        if not foundAt then
            Print(string.format("|cffffd100%s|r was not found in the guild rank priority list.", name))
            return
        end
        pos = math.min(pos, #ARL.db.guildRankPriority)
        local currentName = type(ARL.db.guildRankPriority[foundAt]) == "table" and ARL.db.guildRankPriority[foundAt].name or tostring(ARL.db.guildRankPriority[foundAt])
        if foundAt == pos then
            Print(string.format("|cffffd100%s|r is already at position %d.", currentName, pos))
            return
        end
        local entry = table.remove(ARL.db.guildRankPriority, foundAt)
        local entryName = type(entry) == "table" and entry.name or tostring(entry)
        table.insert(ARL.db.guildRankPriority, pos, entry)
        Print(string.format("Moved |cffffd100%s|r to position %d.", entryName, pos))

    -- /arl settings | /arl options | /arl config
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        if ARL.ShowOptions then
            ARL:ShowOptions()
        else
            Print("Settings UI is not available yet. Try again in a moment.")
        end

    -- /arl deaths | /arl wipe  – show the last wipe death recap
    elseif cmd == "deaths" or cmd == "wipe" then
        if ARL.ShowDeathRecap then
            ARL:ShowDeathRecap()
        else
            Print("Death recap UI is not available yet. Try again in a moment.")
        end

    -- /arl deathtracking [on|off]
    elseif cmd == "deathtracking" then
        local lower = arg:lower()
        if lower == "on" then
            ARL.db.deathTrackingEnabled = true
            Print("Death tracking |cff00ff00enabled|r.")
        elseif lower == "off" then
            ARL.db.deathTrackingEnabled = false
            Print("Death tracking |cffff0000disabled|r.")
        else
            Print(string.format("Death tracking is currently |cff%s%s|r.",
                ARL.db.deathTrackingEnabled and "00ff00" or "ff0000",
                ARL.db.deathTrackingEnabled and "enabled" or "disabled"))
        end

    -- bare /arl opens settings
    elseif cmd == "" then
        if ARL.ShowOptions then
            ARL:ShowOptions()
        else
            Print("Settings UI is not available yet. Try again in a moment.")
        end

    -- /arl help
    elseif cmd == "help" then
        Print("Available commands:")
        Print("  |cffffff00/arl add <name>|r        – Add a character to the preferred leaders list")
        Print("  |cffffff00/arl remove <name>|r     – Remove a character from the list")
        Print("  |cffffff00/arl move <name> <pos>|r – Move a character to a specific position in the list")
        Print("  |cffffff00/arl list|r               – Show the preferred leaders list")
        Print("  |cffffff00/arl clear|r              – Clear the entire list")
        Print("  |cffffff00/arl promote|r            – Manually promote the top available preferred leader")
        Print("  |cffffff00/arl auto [on|off]|r      – Toggle automatic promotion on roster changes")
        Print("  |cffffff00/arl reminder [on|off]|r – Toggle event-driven leader reminders")
        Print("  |cffffff00/arl notify [on|off]|r    – Toggle the manual-promote popup when auto is off")
        Print("  |cffffff00/arl notifysound [on|off]|r – Toggle sound for the manual-promote popup")
        Print("  |cffffff00/arl quiet [on|off]|r     – Suppress all chat output from this addon")
        Print("  |cffffff00/arl grouptype [all|raid|party]|r – Restrict auto-promote to a group type")
        Print("  |cffffff00/arl deaths|r             – Show the death recap from the last wipe")
        Print("  |cffffff00/arl deathtracking [on|off]|r – Toggle death tracking during encounters")
        Print("  |cffffff00/arl consumable ...|r     – Manage tracked consumable categories (run for sub-commands)")
        Print("  |cffffff00/arl consumableaudit [on|off]|r – Toggle consumable audit on ready check")
        Print("  |cffffff00/arl rankpriority [on|off]|r – Toggle guild rank priority fallback")
        Print("  |cffffff00/arl addrank <rank>|r     – Add a guild rank to the priority list")
        Print("  |cffffff00/arl removerank <rank>|r  – Remove a guild rank from the priority list")
        Print("  |cffffff00/arl ranklist|r            – Show the guild rank priority list")
        Print("  |cffffff00/arl clearranks|r          – Clear the guild rank priority list")
        Print("  |cffffff00/arl moverank <rank> <pos>|r – Move a guild rank to a specific position")
        Print("  |cffffff00/arl settings|r           – Open the in-game settings window")
        Print("  |cffffff00/arl help|r               – Show this help message")

    else
        Print(string.format("Unknown command: |cffffff00%s|r. Type /arl help for a list of commands.", cmd))
    end
end
