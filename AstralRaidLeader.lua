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
local UnitIsGroupAssistant = _G.UnitIsGroupAssistant
local MAX_RAID_MEMBERS = _G.MAX_RAID_MEMBERS or 40
local MAX_PARTY_MEMBERS = _G.MAX_PARTY_MEMBERS or 4
local C_Timer = _G.C_Timer
local GetRaidRosterInfo = _G.GetRaidRosterInfo
local SetRaidSubgroup = _G.SetRaidSubgroup
local InviteUnit = (_G.C_PartyInfo and _G.C_PartyInfo.InviteUnit) or _G.InviteUnit
local CanInvite = _G.C_PartyInfo and _G.C_PartyInfo.CanInvite
local ENABLE_RAID_LAYOUT_MISSING_INVITES = true
local IsGuildGroup = _G.IsGuildGroup
local UnitInPhase = _G.UnitInPhase
local UnitPosition = _G.UnitPosition
local UnitInRaid = _G.UnitInRaid

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
    groupTypeFilter        = {
        raid = true,
        party = true,
        guild_raid = true,
        guild_party = true,
    }, -- independent per-type toggles
    consumableAuditEnabled = true,  -- run a consumable audit when a ready check fires
    trackedConsumables     = {},    -- user-defined additions (system defaults are always included)
    guildRankPriority      = {},    -- ordered list of {name, rankIndex} tables (highest priority first)
    useGuildRankPriority   = false, -- fall back to guild rank priority when no preferred leader is present
    raidLayouts            = {},    -- ordered list of saved raid-group layouts imported from external notes
    activeRaidLayoutKey    = "",   -- currently selected raid-group layout key
    raidGroupShowMissingNames = true, -- include missing player names in the apply completion message
    raidGroupAutoApplyOnJoin  = false, -- automatically re-apply the selected layout when a raid member joins
    raidGroupInviteMissingPlayers = false, -- invite listed players who are not already in the raid when applying
    -- Death tracking
    deathTrackingEnabled   = true,  -- record deaths during raid encounters
    deathGroupTypeFilter   = {
        raid = true,
        party = false,
        guild_raid = false,
        guild_party = false,
    }, -- independent per-type toggles
    showRecapOnWipe        = true,  -- automatically open the recap window after a wipe
    showRecapOnEncounterEnd = false, -- automatically open the recap window after any encounter end (kill or wipe)
    lastWipeDeaths         = {},    -- list of death records from the most recent wipe
    lastWipeEncounter      = "",    -- name of the encounter that wiped
    lastWipeDate           = "",    -- human-readable timestamp of the wipe
    deathRecapHistory      = {},    -- newest-first recap history entries
                                  -- {encounter,difficulty,date,outcome,deaths}
    maxDeathRecapsStored   = 20,    -- maximum recap history entries to keep
}

-- Built-in consumable categories - always checked, never stored in SavedVariables.
local SYSTEM_CONSUMABLES = {
    { label = "Flasks", spellIds = { 1235108, 1235111, 1235110, 1235057, 1230875, 1235057 } },
    { label = "Food",   spellIds = {}, namePatterns = { "Well Fed" } },
}

-- ============================================================
-- Helpers
-- ============================================================

local function Print(msg)
    if ARL.db and ARL.db.quietMode then return end
    print("|cff00ccff[AstralRaidLeader]|r " .. tostring(msg))
end

local function Trim(value)
    if value == nil then return "" end
    return tostring(value):match("^%s*(.-)%s*$")
end

local function GetShortName(name)
    local trimmed = Trim(name)
    return trimmed:match("^([^%-]+)") or trimmed
end

local function CanManageRaidSubgroups()
    return UnitIsGroupLeader("player")
        or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
end

-- Forward declarations used by raid-layout helpers before death-tracking setup.
local currentEncounterName = ""
local currentEncounterID = 0

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
    -- GetNormalTexture/GetPushedTexture/GetHighlightTexture are intentionally omitted:
    -- GetRegions() above already covers those, and calling these Get* methods in
    -- Midnight triggers an internal SetNormalTexture(nil) error.

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

    -- Migrate old string filter values (pre-multi-select) to the new table format.
    local function MigrateFilter(val)
        if val == "all"             then return { raid=true,  party=true,  guild_raid=true,  guild_party=true  }
        elseif val == "party"       then return { raid=false, party=true,  guild_raid=false, guild_party=false }
        elseif val == "guild_raid"  then return { raid=false, party=false, guild_raid=true,  guild_party=false }
        elseif val == "guild_party" then return { raid=false, party=false, guild_raid=false, guild_party=true  }
        else                             return { raid=true,  party=false, guild_raid=false, guild_party=false }
        end
    end
    if type(ARL.db.groupTypeFilter) ~= "table" then
        ARL.db.groupTypeFilter = MigrateFilter(ARL.db.groupTypeFilter)
    end
    if type(ARL.db.deathGroupTypeFilter) ~= "table" then
        ARL.db.deathGroupTypeFilter = MigrateFilter(ARL.db.deathGroupTypeFilter)
    end

    if type(ARL.db.deathRecapHistory) ~= "table" then
        ARL.db.deathRecapHistory = {}
    end
    if type(ARL.db.maxDeathRecapsStored) ~= "number"
        or ARL.db.maxDeathRecapsStored < 1
    then
        ARL.db.maxDeathRecapsStored = DEFAULTS.maxDeathRecapsStored
    end

    -- One-time migration path for legacy installs that only stored the latest recap.
    if #ARL.db.deathRecapHistory == 0
        and (
            (type(ARL.db.lastWipeEncounter) == "string" and ARL.db.lastWipeEncounter ~= "")
            or (type(ARL.db.lastWipeDate) == "string" and ARL.db.lastWipeDate ~= "")
            or (type(ARL.db.lastWipeDeaths) == "table" and #ARL.db.lastWipeDeaths > 0)
        )
    then
        ARL.db.deathRecapHistory[1] = {
            encounter = ARL.db.lastWipeEncounter or "",
            difficulty = "",
            date = ARL.db.lastWipeDate or "",
            outcome = "wipe",
            deaths = type(ARL.db.lastWipeDeaths) == "table" and ARL.db.lastWipeDeaths or {},
        }
    end

    if #ARL.db.deathRecapHistory > ARL.db.maxDeathRecapsStored then
        for i = #ARL.db.deathRecapHistory, ARL.db.maxDeathRecapsStored + 1, -1 do
            ARL.db.deathRecapHistory[i] = nil
        end
    end
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
            AddName(UnitName("raid" .. i))
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
local function IsInGuildGroupByBlizzardRules()
    if not IsGuildGroup then return false end
    return IsGuildGroup() and true or false
end

local function IsInRelevantGroup()
    local inRaid  = IsInRaid()
    local inGroup = IsInGroup()
    if not (inRaid or inGroup) then return false end
    local filter = ARL.db and ARL.db.groupTypeFilter
    if type(filter) ~= "table" then return true end
    local isGuild = IsInGuildGroupByBlizzardRules()
    if inRaid then
        return (filter.raid and true or false) or (filter.guild_raid and isGuild or false)
    else
        return (filter.party and true or false) or (filter.guild_party and isGuild or false)
    end
end

-- Return true when death recap tracking should run for the current group type.
local function IsInRelevantDeathGroup()
    local inRaid  = IsInRaid()
    local inGroup = IsInGroup()
    if not (inRaid or inGroup) then return false end
    local filter = ARL.db and ARL.db.deathGroupTypeFilter
    if type(filter) ~= "table" then return inRaid end
    local isGuild = IsInGuildGroupByBlizzardRules()
    if inRaid then
        return (filter.raid and true or false) or (filter.guild_raid and isGuild or false)
    else
        return (filter.party and true or false) or (filter.guild_party and isGuild or false)
    end
end

-- ============================================================
-- Raid layout import / apply
-- ============================================================

local NormalizeDifficultyToken
local GetCurrentRaidDifficultyInfo

local function GetRaidLayoutKey(profile)
    return string.format(
        "%s::%s::%s",
        tostring(tonumber(profile.encounterID) or Trim(profile.encounterID)),
        Trim(profile.difficulty):lower(),
        Trim(profile.name):lower()
    )
end

local function FormatRaidDifficultyDisplay(value)
    local token = NormalizeDifficultyToken and NormalizeDifficultyToken(value) or Trim(value):lower()
    if token == "mythic" then
        return "Mythic"
    elseif token == "heroic" then
        return "Heroic"
    elseif token == "normal" then
        return "Normal"
    elseif token == "lfr" then
        return "LFR"
    end

    local text = Trim(value)
    if text == "" then
        return "Unknown"
    end
    return text
end

local function GetRaidLayoutLabel(profile)
    local encounterName = Trim(profile and profile.name)
    local difficulty = FormatRaidDifficultyDisplay(profile and profile.difficulty)
    if encounterName == "" then encounterName = "Unknown Encounter" end
    return string.format("%s %s", difficulty, encounterName)
end

local function FindRaidLayoutIndexByKey(key)
    if not ARL.db or type(ARL.db.raidLayouts) ~= "table" then return nil end
    for i, profile in ipairs(ARL.db.raidLayouts) do
        if profile.key == key then
            return i
        end
    end
    return nil
end

local function GetActiveRaidLayoutProfile()
    if not ARL.db or type(ARL.db.raidLayouts) ~= "table" then return nil end
    local activeKey = Trim(ARL.db.activeRaidLayoutKey)
    if activeKey == "" then return nil end
    local index = FindRaidLayoutIndexByKey(activeKey)
    if not index then return nil end
    return ARL.db.raidLayouts[index]
end

local function GetRaidLayoutProfileByQuery(query)
    if not ARL.db or type(ARL.db.raidLayouts) ~= "table" then return nil, nil end

    local trimmed = Trim(query)
    if trimmed == "" then
        local active = GetActiveRaidLayoutProfile()
        if not active then return nil, nil end
        return FindRaidLayoutIndexByKey(active.key), active
    end

    local exactKeyIndex = FindRaidLayoutIndexByKey(trimmed)
    if exactKeyIndex then
        return exactKeyIndex, ARL.db.raidLayouts[exactKeyIndex]
    end

    local encounterID = tonumber(trimmed)
    if encounterID then
        for i, profile in ipairs(ARL.db.raidLayouts) do
            if tonumber(profile.encounterID) == encounterID then
                return i, profile
            end
        end
    end

    local lower = trimmed:lower()
    for i, profile in ipairs(ARL.db.raidLayouts) do
        if Trim(profile.name):lower() == lower then
            return i, profile
        end
    end

    for i, profile in ipairs(ARL.db.raidLayouts) do
        if Trim(profile.name):lower():find(lower, 1, true) then
            return i, profile
        end
    end

    return nil, nil
end

local function GetRaidLayoutPreviewLines(profile)
    local grouped = {}
    for subgroup = 1, 8 do
        grouped[subgroup] = {}
    end

    if type(profile and profile.groups) == "table" then
        for subgroup = 1, 8 do
            for _, playerName in ipairs(profile.groups[subgroup] or {}) do
                grouped[subgroup][#grouped[subgroup] + 1] = playerName
            end
        end
    else
        for index, playerName in ipairs(profile and profile.invitelist or {}) do
            local subgroup = math.max(1, math.min(8, math.floor((index - 1) / 5) + 1))
            grouped[subgroup][#grouped[subgroup] + 1] = playerName
        end
    end

    local lines = {}
    for subgroup = 1, 8 do
        if grouped[subgroup] and #grouped[subgroup] > 0 then
            lines[#lines + 1] = string.format("Group %d: %s", subgroup, table.concat(grouped[subgroup], ", "))
        end
    end
    return lines
end

local function NewRaidLayoutGroups()
    local groups = {}
    for subgroup = 1, 8 do
        groups[subgroup] = {}
    end
    return groups
end

local function GetOverfullRaidLayoutGroups(groups)
    local overfull = {}
    for subgroup = 1, 8 do
        local count = #(groups and groups[subgroup] or {})
        if count > 5 then
            overfull[#overfull + 1] = {
                subgroup = subgroup,
                count = count,
            }
        end
    end
    return overfull
end

local function BuildRaidLayoutOverfullGroupsText(overfull)
    local parts = {}
    for _, entry in ipairs(overfull or {}) do
        parts[#parts + 1] = string.format("G%d=%d", entry.subgroup, entry.count)
    end
    return table.concat(parts, ", ")
end

local function BuildRaidLayoutOverfullGroupsError(profileLabel, overfull)
    return string.format(
        "Raid layout |cffffd100%s|r has subgroup(s) with more than 5 players: %s.",
        profileLabel,
        BuildRaidLayoutOverfullGroupsText(overfull)
    )
end

local function NormalizeRaidLayoutGroups(rawGroups)
    local groups = NewRaidLayoutGroups()
    local invitelist = {}
    local seenNames = {}

    if type(rawGroups) ~= "table" then
        return groups, invitelist
    end

    for subgroup = 1, 8 do
        if type(rawGroups[subgroup]) == "table" then
            for _, rawName in ipairs(rawGroups[subgroup]) do
                local cleanName = Trim(rawName)
                local key = cleanName:lower()
                if cleanName ~= "" and not seenNames[key] then
                    seenNames[key] = true
                    groups[subgroup][#groups[subgroup] + 1] = cleanName
                    invitelist[#invitelist + 1] = cleanName
                end
            end
        end
    end

    return groups, invitelist
end

local function BuildRaidLayoutGroupsFromInvitelist(rawInvitelist)
    local groups = NewRaidLayoutGroups()
    local invitelist = {}
    local seenNames = {}

    for _, rawName in ipairs(rawInvitelist or {}) do
        local cleanName = Trim(rawName)
        local key = cleanName:lower()
        if cleanName ~= "" and not seenNames[key] then
            local subgroup = math.max(1, math.min(8, math.floor(#invitelist / 5) + 1))
            seenNames[key] = true
            groups[subgroup][#groups[subgroup] + 1] = cleanName
            invitelist[#invitelist + 1] = cleanName
        end
    end

    return groups, invitelist
end

local function GetRaidLayoutGroups(profile)
    if type(profile and profile.groups) == "table" then
        local groups, invitelist = NormalizeRaidLayoutGroups(profile.groups)
        if #invitelist > 0 or #(profile.invitelist or {}) == 0 then
            return groups, invitelist
        end
    end

    return BuildRaidLayoutGroupsFromInvitelist(profile and profile.invitelist or {})
end

local function BuildRaidLayoutProfile(input)
    if type(input) ~= "table" then
        return nil, "Raid layout data is invalid."
    end

    local encounterID = tonumber(input.encounterID)
    if not encounterID or encounterID <= 0 then
        return nil, "Encounter ID must be a positive number."
    end

    local encounterName = Trim(input.name)
    if encounterName == "" then
        return nil, "Encounter name cannot be empty."
    end

    local difficultyToken = NormalizeDifficultyToken(input.difficulty)
    local difficulty = difficultyToken ~= "" and difficultyToken or Trim(input.difficulty)
    if difficulty == "" then
        difficulty = "Unknown"
    end

    local groups, invitelist
    if type(input.groups) == "table" then
        groups, invitelist = NormalizeRaidLayoutGroups(input.groups)
    else
        groups, invitelist = BuildRaidLayoutGroupsFromInvitelist(input.invitelist)
    end

    local assignmentHints
    local bossAssignmentHelpers = ARL.RaidLayoutBossAssignments
    if type(input.assignmentHints) == "table" then
        assignmentHints = input.assignmentHints
    elseif bossAssignmentHelpers and bossAssignmentHelpers.ParseBossSoakAssignmentHints then
        assignmentHints = bossAssignmentHelpers.ParseBossSoakAssignmentHints(
            encounterID,
            difficulty,
            input and input.noteBody,
            invitelist
        )
    end

    if type(input.groups) ~= "table"
        and type(assignmentHints) == "table"
        and (
            assignmentHints.kind == "soak_assignments"
            or assignmentHints.kind == "chimaerus_soaks"
        )
        and bossAssignmentHelpers
        and bossAssignmentHelpers.BuildRaidLayoutGroupsFromHints
    then
        groups, invitelist = bossAssignmentHelpers.BuildRaidLayoutGroupsFromHints(invitelist, assignmentHints)
    end

    local overfullGroups = GetOverfullRaidLayoutGroups(groups)
    if #overfullGroups > 0 then
        return nil, BuildRaidLayoutOverfullGroupsError(encounterName, overfullGroups)
    end

    local profile = {
        encounterID = encounterID,
        difficulty = difficulty,
        name = encounterName,
        groups = groups,
        invitelist = invitelist,
        assignmentHints = assignmentHints,
    }
    profile.key = GetRaidLayoutKey(profile)

    return profile, nil
end

local function BuildRaidLayoutImportText(profile)
    local invitelist = profile and profile.invitelist or {}
    local inviteText = #invitelist > 0 and table.concat(invitelist, " ") or ""
    return string.format(
        "EncounterID: %d; Difficulty: %s; Name: %s;\ninvitelist: %s;",
        tonumber(profile.encounterID) or 0,
        Trim(profile.difficulty),
        Trim(profile.name),
        inviteText
    )
end

local function BuildCurrentRaidInvitelist()
    local invitelist = {}
    local seen = {}
    for raidIndex = 1, MAX_RAID_MEMBERS do
        local unit = "raid" .. raidIndex
        if UnitExists(unit) then
            local name, realm = UnitName(unit)
            local fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name
            if fullName and fullName ~= "" then
                local key = fullName:lower()
                if not seen[key] then
                    seen[key] = true
                    invitelist[#invitelist + 1] = fullName
                end
            end
        end
    end
    return invitelist
end

local function BuildNewRaidLayoutTemplate(seedFromCurrentRaid)
    local encounterID = tonumber(currentEncounterID) or 0
    if encounterID <= 0 then
        encounterID = 1
    end

    local encounterName = Trim(currentEncounterName)
    if encounterName == "" then
        encounterName = "New Layout"
    end

    local _, currentDifficultyName = GetCurrentRaidDifficultyInfo()
    local difficulty = NormalizeDifficultyToken(currentDifficultyName)
    if difficulty == "" then
        difficulty = Trim(currentDifficultyName)
    end
    if difficulty == "" then
        difficulty = "normal"
    end

    local profile = {
        encounterID = encounterID,
        difficulty = difficulty,
        name = encounterName,
        invitelist = seedFromCurrentRaid and BuildCurrentRaidInvitelist() or {},
    }

    local normalized, err = BuildRaidLayoutProfile(profile)
    if not normalized then
        return nil, err
    end
    return normalized, nil
end

local function ExportRaidLayoutToImportText(query)
    local _, profile = GetRaidLayoutProfileByQuery(query)
    if not profile then
        return false, "Raid layout not found."
    end
    return true, BuildRaidLayoutImportText(profile)
end

local function BuildNewRaidLayoutImportText(seedFromCurrentRaid)
    local profile, err = BuildNewRaidLayoutTemplate(seedFromCurrentRaid)
    if not profile then
        return false, err
    end
    return true, BuildRaidLayoutImportText(profile)
end

local function ParseRaidLayoutImport(text)
    local normalized = Trim((text or ""):gsub("\r\n", "\n"):gsub("\r", "\n"))
    if normalized == "" then
        return nil, "Paste at least one encounter block to import."
    end

    local byKey = {}
    local orderedKeys = {}
    for encounterIDText, difficultyText, encounterNameText, noteBodyText, inviteListText in normalized:gmatch(
        "EncounterID:%s*([^;\r\n]+)%s*;%s*Difficulty:%s*([^;\r\n]+)%s*;%s*Name:%s*([^;\r\n]+)%s*;?(.-)"
            .. "invitelist:%s*(.-)%s*;"
    ) do
        local encounterID = tonumber(Trim(encounterIDText))
        local difficulty = Trim(difficultyText)
        local encounterName = Trim(encounterNameText)
        local noteBody = Trim(noteBodyText)
        local inviteList = {}
        local seenNames = {}

        for rawName in Trim(inviteListText):gmatch("%S+") do
            local cleanName = Trim(rawName)
            local key = cleanName:lower()
            if cleanName ~= "" and not seenNames[key] then
                seenNames[key] = true
                inviteList[#inviteList + 1] = cleanName
            end
        end

        if encounterID and encounterID > 0 and encounterName ~= "" then
            local rawProfile = {
                encounterID = encounterID,
                difficulty = difficulty ~= "" and difficulty or "Unknown",
                name = encounterName,
                invitelist = inviteList,
                noteBody = noteBody,
            }
            local profile = BuildRaidLayoutProfile(rawProfile)

            if profile then
                if not byKey[profile.key] then
                    orderedKeys[#orderedKeys + 1] = profile.key
                end
                byKey[profile.key] = profile
            end
        end
    end

    if #orderedKeys == 0 then
        return nil, "Could not parse any raid layouts. Expected EncounterID/Difficulty/Name followed by invitelist."
    end

    local profiles = {}
    for _, key in ipairs(orderedKeys) do
        profiles[#profiles + 1] = byKey[key]
    end
    return profiles, nil
end

local function UpsertRaidLayoutProfile(profile)
    if type(ARL.db.raidLayouts) ~= "table" then
        ARL.db.raidLayouts = {}
    end

    local existingIndex = FindRaidLayoutIndexByKey(profile.key)
    if existingIndex then
        ARL.db.raidLayouts[existingIndex] = profile
        return false, existingIndex
    end

    ARL.db.raidLayouts[#ARL.db.raidLayouts + 1] = profile
    return true, #ARL.db.raidLayouts
end

local function SaveRaidLayoutProfile(profile, options)
    if not ARL.db then
        return false, "Not fully loaded yet. Please wait a moment."
    end

    local normalized, err = BuildRaidLayoutProfile(profile)
    if not normalized then
        return false, err
    end

    options = type(options) == "table" and options or {}
    local overwrite = options.overwrite and true or false
    local targetKey = Trim(options.targetKey)

    if overwrite then
        if targetKey == "" then
            return false, "Select a saved raid layout to overwrite."
        end

        local targetIndex = FindRaidLayoutIndexByKey(targetKey)
        if not targetIndex then
            return false, "Selected raid layout to overwrite was not found."
        end

        local conflictIndex = FindRaidLayoutIndexByKey(normalized.key)
        if conflictIndex and conflictIndex ~= targetIndex then
            return false,
                "Another saved layout already uses that encounter/difficulty/name. Use Save New with a different name."
        end

        ARL.db.raidLayouts[targetIndex] = normalized
        ARL.db.activeRaidLayoutKey = normalized.key
        return true, {
            profile = normalized,
            overwritten = true,
            previousKey = targetKey,
        }
    end

    if FindRaidLayoutIndexByKey(normalized.key) then
        return false,
            "A raid layout with that encounter/difficulty/name already exists. Use Overwrite Selected instead."
    end

    ARL.db.raidLayouts[#ARL.db.raidLayouts + 1] = normalized
    ARL.db.activeRaidLayoutKey = normalized.key
    return true, {
        profile = normalized,
        overwritten = false,
    }
end

local function SaveRaidLayoutFromImportText(text, options)
    local profiles, err = ParseRaidLayoutImport(text)
    if not profiles then
        return false, err
    end
    if #profiles ~= 1 then
        return false, "Editor save expects exactly one encounter block."
    end
    return SaveRaidLayoutProfile(profiles[1], options)
end

local function ImportRaidLayouts(text)
    if not ARL.db then
        return false, "Not fully loaded yet. Please wait a moment."
    end

    local profiles, err = ParseRaidLayoutImport(text)
    if not profiles then
        return false, err
    end

    local added = 0
    local updated = 0
    for _, profile in ipairs(profiles) do
        local inserted = UpsertRaidLayoutProfile(profile)
        if inserted then
            added = added + 1
        else
            updated = updated + 1
        end
    end

    ARL.db.activeRaidLayoutKey = profiles[1].key
    return true, {
        imported = #profiles,
        added = added,
        updated = updated,
        activeKey = profiles[1].key,
    }
end

local function DeleteRaidLayoutByQuery(query)
    local index, profile = GetRaidLayoutProfileByQuery(query)
    if not index or not profile then
        return false, "Raid layout not found."
    end

    table.remove(ARL.db.raidLayouts, index)
    if ARL.db.activeRaidLayoutKey == profile.key then
        local fallback = ARL.db.raidLayouts[1]
        ARL.db.activeRaidLayoutKey = fallback and fallback.key or ""
    end
    return true, profile
end

local function SetActiveRaidLayoutByQuery(query)
    local _, profile = GetRaidLayoutProfileByQuery(query)
    if not profile then
        return false, "Raid layout not found."
    end

    ARL.db.activeRaidLayoutKey = profile.key
    return true, profile
end

local function GetRaidRosterSnapshot()
    local snapshot = {
        entries = {},
        fullMap = {},
        shortMap = {},
    }

    for raidIndex = 1, MAX_RAID_MEMBERS do
        local unit = "raid" .. raidIndex
        if UnitExists(unit) then
            local name, realm = UnitName(unit)
            local fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name
            if fullName and fullName ~= "" then
                local rosterIndex = UnitInRaid and UnitInRaid(unit) or raidIndex
                local subgroup = 1
                if GetRaidRosterInfo and rosterIndex then
                    local _, _, actualSubgroup = GetRaidRosterInfo(rosterIndex)
                    subgroup = tonumber(actualSubgroup) or subgroup
                end
                local entry = {
                    index = tonumber(rosterIndex) or raidIndex,
                    name = fullName,
                    subgroup = subgroup or 1,
                }
                snapshot.entries[#snapshot.entries + 1] = entry
                snapshot.fullMap[fullName:lower()] = entry

                local shortKey = GetShortName(fullName):lower()
                if shortKey ~= "" then
                    if snapshot.shortMap[shortKey] and snapshot.shortMap[shortKey] ~= entry then
                        snapshot.shortMap[shortKey] = false
                    else
                        snapshot.shortMap[shortKey] = entry
                    end
                end
            end
        end
    end

    return snapshot
end

local function ResolveRaidRosterEntry(snapshot, importedName, used)
    local fullKey = Trim(importedName):lower()
    if fullKey == "" then return nil end

    local fullMatch = snapshot.fullMap[fullKey]
    if fullMatch and not used[fullMatch.name:lower()] then
        return fullMatch
    end

    local shortKey = GetShortName(importedName):lower()
    local shortMatch = snapshot.shortMap[shortKey]
    if shortMatch and shortMatch ~= false and not used[shortMatch.name:lower()] then
        return shortMatch
    end

    return nil
end

local function BuildRaidLayoutTargets(profile, snapshot)
    local targetByName = {}
    local used = {}
    local groupCounts = {}
    local missing = {}
    local matchedCount = 0
    local importedCount = 0
    local groupedTargets = GetRaidLayoutGroups(profile)

    local overfullGroups = GetOverfullRaidLayoutGroups(groupedTargets)
    if #overfullGroups > 0 then
        return nil, BuildRaidLayoutOverfullGroupsError(GetRaidLayoutLabel(profile), overfullGroups)
    end

    for desiredGroup = 1, 8 do
        for _, importedName in ipairs(groupedTargets[desiredGroup] or {}) do
            local cleanName = Trim(importedName)
            if cleanName ~= "" then
                importedCount = importedCount + 1
                local entry = ResolveRaidRosterEntry(snapshot, cleanName, used)
                if entry then
                    local rosterKey = entry.name:lower()
                    used[rosterKey] = true
                    targetByName[rosterKey] = desiredGroup
                    groupCounts[desiredGroup] = (groupCounts[desiredGroup] or 0) + 1
                    matchedCount = matchedCount + 1
                else
                    missing[#missing + 1] = cleanName
                end
            end
        end
    end

    local overflowGroups = { 8, 7, 6, 5 }
    local overflowCount = 0
    for _, entry in ipairs(snapshot.entries) do
        local rosterKey = entry.name:lower()
        if not used[rosterKey] then
            local assigned = false
            for _, subgroup in ipairs(overflowGroups) do
                if (groupCounts[subgroup] or 0) < 5 then
                    targetByName[rosterKey] = subgroup
                    groupCounts[subgroup] = (groupCounts[subgroup] or 0) + 1
                    overflowCount = overflowCount + 1
                    assigned = true
                    break
                end
            end
            if not assigned then
                return nil, string.format(
                    "Raid layout |cffffd100%s|r cannot be applied because groups 8, 7, 6, and 5 are already full.",
                    GetRaidLayoutLabel(profile)
                )
            end
        end
    end

    return {
        targetByName = targetByName,
        targetCounts = groupCounts,
        matchedCount = matchedCount,
        importedCount = importedCount,
        missing = missing,
        overflowCount = overflowCount,
    }
end

local function BuildRaidLayoutOccupancyText(occupancy)
    local parts = {}
    for subgroup = 1, 8 do
        parts[#parts + 1] = string.format("G%d=%d", subgroup, occupancy[subgroup] or 0)
    end
    return table.concat(parts, ", ")
end

local function BuildRaidLayoutPendingText(pending)
    local parts = {}
    for index, move in ipairs(pending or {}) do
        if index > 8 then
            parts[#parts + 1] = string.format("... +%d more", #pending - 8)
            break
        end
        parts[#parts + 1] = string.format(
            "%s:%d->%d",
            GetShortName(move.name),
            tonumber(move.subgroup) or 0,
            tonumber(move.desiredGroup) or 0
        )
    end
    return table.concat(parts, ", ")
end

local RAID_DIFFICULTY_IDS = {
    lfr = { [17] = true },
    normal = { [14] = true },
    heroic = { [15] = true },
    mythic = { [16] = true },
}

NormalizeDifficultyToken = function(value)
    local token = Trim(value):lower()
    token = token:gsub("%s+", "")

    if token == "" or token == "unknown" then
        return ""
    elseif token == "mythic" or token == "m" or token == "16" then
        return "mythic"
    elseif token == "heroic" or token == "h" or token == "15" then
        return "heroic"
    elseif token == "normal" or token == "n" or token == "14" then
        return "normal"
    elseif token == "lfr" or token == "17" then
        return "lfr"
    end

    return token
end

GetCurrentRaidDifficultyInfo = function()
    local raidDifficultyID = 0
    if _G.GetRaidDifficultyID then
        raidDifficultyID = tonumber(_G.GetRaidDifficultyID()) or 0
    end

    local difficultyName = ""
    if raidDifficultyID > 0 and _G.GetDifficultyInfo then
        local name = _G.GetDifficultyInfo(raidDifficultyID)
        difficultyName = Trim(name)
    end

    if (raidDifficultyID <= 0 or difficultyName == "") and _G.GetInstanceInfo then
        local _, _, difficultyID, difficultyText = _G.GetInstanceInfo()
        if raidDifficultyID <= 0 then
            raidDifficultyID = tonumber(difficultyID) or 0
        end
        if difficultyName == "" then
            difficultyName = Trim(difficultyText)
        end
    end

    return raidDifficultyID, difficultyName
end

local function IsRaidLayoutDifficultyMatch(profile)
    local expectedToken = NormalizeDifficultyToken(profile and profile.difficulty)
    if expectedToken == "" then
        return true
    end

    local currentID, currentName = GetCurrentRaidDifficultyInfo()
    local expectedIDs = RAID_DIFFICULTY_IDS[expectedToken]
    if expectedIDs and currentID > 0 then
        if expectedIDs[currentID] then
            return true
        end
    end

    local currentToken = NormalizeDifficultyToken(currentName)
    if currentToken ~= "" and currentToken == expectedToken then
        return true
    end

    local shownCurrent = Trim(currentName)
    if shownCurrent == "" then
        shownCurrent = currentID > 0 and ("ID " .. tostring(currentID)) or "Unknown"
    end

    return false, string.format(
        "Raid layout |cffffd100%s|r is for |cffffd100%s|r, but current raid difficulty is |cffffd100%s|r.",
        GetRaidLayoutLabel(profile),
        Trim(profile.difficulty),
        shownCurrent
    )
end

local function StopRaidLayoutApply(message)
    ARL.raidLayoutApplyState = nil
    if message and message ~= "" then
        Print(message)
    end
end

-- Max raid sizes per normalized difficulty token.
local DIFFICULTY_MAX_PLAYERS = {
    mythic = 20,
    heroic = 30,
    normal = 30,
    lfr    = 25,
}

-- Returns true when the current group cannot accept more invites.
local function IsGroupAtInviteCapacity(_expectedMaxSize)
    -- Raid groups can always invite up to the hard 40-player cap.
    -- _expectedMaxSize is kept for call-site compatibility.
    local memberCount = tonumber(GetNumGroupMembers and GetNumGroupMembers()) or 0
    if IsInRaid() then
        return memberCount >= MAX_RAID_MEMBERS
    end

    local partyMembers = tonumber(_G.GetNumSubgroupMembers and _G.GetNumSubgroupMembers()) or 0
    return partyMembers >= MAX_PARTY_MEMBERS
end

-- Returns a set of short names (lowercased, realm stripped) for everyone currently in the raid.
local function GetCurrentRaidShortNameSet()
    local set = {}
    for raidIndex = 1, MAX_RAID_MEMBERS do
        local unit = "raid" .. raidIndex
        if UnitExists(unit) then
            local name = UnitName(unit)
            if name and name ~= "" then
                set[GetShortName(name):lower()] = true
            end
        end
    end
    return set
end

local function InviteMissingRaidLayoutPlayers(missingNames, expectedMaxSize)
    if not ENABLE_RAID_LAYOUT_MISSING_INVITES then
        return 0, 0
    end
    if ARL._allowRaidLayoutInvites ~= true then
        return 0, 0
    end
    if not ARL.db or not ARL.db.raidGroupInviteMissingPlayers then
        return 0, 0
    end
    if not InviteUnit or type(missingNames) ~= "table" then
        return 0, 0
    end
    if CanInvite and not CanInvite() then
        return 0, #missingNames
    end
    -- Bail out immediately if the group is already at capacity before the first invite attempt.
    if IsGroupAtInviteCapacity(expectedMaxSize) then
        return 0, #missingNames
    end

    -- Build a live short-name set so we never invite someone already in the raid
    -- (name-matching failures can cause them to appear in the missing list even
    -- when they are physically present in the group).
    local inRaidAlready = GetCurrentRaidShortNameSet()

    local invitedCount = 0
    local skippedCount = 0
    for _, missingName in ipairs(missingNames) do
        local cleanName = Trim(missingName)
        if cleanName ~= "" then
            local shortKey = GetShortName(cleanName):lower()
            if inRaidAlready[shortKey] then
                -- Already in raid under a different name format; skip silently.
                skippedCount = skippedCount + 1
            elseif IsGroupAtInviteCapacity(expectedMaxSize) then
                skippedCount = skippedCount + 1
            else
                InviteUnit(cleanName)
                invitedCount = invitedCount + 1
            end
        end
    end

    return invitedCount, skippedCount
end

local function ScheduleRaidLayoutApplyRetry(state, delaySeconds)
    if not state then return end

    state.waiting = true
    state.retryAt = GetTime() + delaySeconds
    state.retryToken = (state.retryToken or 0) + 1

    if C_Timer and C_Timer.After then
        local token = state.retryToken
        C_Timer.After(delaySeconds, function()
            local active = ARL.raidLayoutApplyState
            if active == state and active.waiting and active.retryToken == token then
                active.waiting = false
                if ARL.ContinueRaidLayoutApply then
                    ARL:ContinueRaidLayoutApply()
                end
            end
        end)
    end
end

local function ContinueRaidLayoutApply()
    local state = ARL.raidLayoutApplyState
    if not state then return end

    if state.waiting then
        local nowWaiting = GetTime()
        if state.retryAt and nowWaiting >= state.retryAt then
            state.waiting = false
        else
            return
        end
    end

    local now = GetTime()
    if state.retryAt and now < state.retryAt then
        ScheduleRaidLayoutApplyRetry(state, state.retryAt - now)
        return
    end

    if InCombatLockdown() then
        if not state.combatPaused then
            state.combatPaused = true
            Print("Raid layout apply paused until combat ends.")
        end
        return
    end

    if not IsInRaid() then
        StopRaidLayoutApply("Raid layout apply stopped because you are no longer in a raid.")
        return
    end

    if not CanManageRaidSubgroups() then
        StopRaidLayoutApply("Raid layout apply stopped because you are no longer the raid leader or an assistant.")
        return
    end

    local snapshot = GetRaidRosterSnapshot()
    local occupancy = {}
    local entriesBySubgroup = {}
    local pending = {}
    for _, entry in ipairs(snapshot.entries) do
        occupancy[entry.subgroup] = (occupancy[entry.subgroup] or 0) + 1
        local members = entriesBySubgroup[entry.subgroup]
        if not members then
            members = {}
            entriesBySubgroup[entry.subgroup] = members
        end
        members[#members + 1] = entry
    end

    for _, entry in ipairs(snapshot.entries) do
        local desiredGroup = state.targetByName[entry.name:lower()]
        if desiredGroup and entry.subgroup ~= desiredGroup then
            pending[#pending + 1] = {
                index = entry.index,
                name = entry.name,
                subgroup = entry.subgroup,
                desiredGroup = desiredGroup,
            }
        end
    end

    if #pending == 0 then
        local missingSuffix = ""
        if #state.missing > 0 then
            local invitedCount = state.invitedMissingCount or 0
            local skippedCount = state.skippedInviteCount or 0
            if invitedCount > 0 or skippedCount > 0 then
                local detail = ""
                if ARL.db and ARL.db.raidGroupShowMissingNames then
                    detail = ": " .. table.concat(state.missing, ", ")
                end
                if skippedCount > 0 then
                    missingSuffix = string.format(
                        " %d listed member(s) are not yet in the raid (%d invited, %d invite(s) skipped"
                            .. " because your group is full)%s",
                        #state.missing,
                        invitedCount,
                        skippedCount,
                        detail
                    )
                else
                    missingSuffix = string.format(
                        " %d listed member(s) were invited but are not yet in the raid%s",
                        #state.missing,
                        detail
                    )
                end
            elseif ARL.db and ARL.db.raidGroupShowMissingNames then
                missingSuffix = string.format(" %d listed member(s) not in raid: %s",
                    #state.missing, table.concat(state.missing, ", "))
            else
                missingSuffix = string.format(" %d listed member(s) were not in the raid.", #state.missing)
            end
        end
        StopRaidLayoutApply(string.format(
            "Applied raid layout for |cffffd100%s|r. %d listed member(s) matched, "
                .. "%d unlisted member(s) moved into overflow groups.%s",
            GetRaidLayoutLabel(state.profile),
            state.matchedCount,
            state.overflowCount,
            missingSuffix
        ))
        return
    end

    local pendingSignatureParts = {}
    local pendingTokenSet = {}
    for _, move in ipairs(pending) do
        local token = string.format("%s>%d", move.name, move.desiredGroup)
        pendingSignatureParts[#pendingSignatureParts + 1] = token
        pendingTokenSet[token] = true
    end
    local pendingSignature = table.concat(pendingSignatureParts, "|")
    if state.lastPendingSignature == pendingSignature then
        if state.lastIssuedMove and pendingTokenSet[state.lastIssuedMove] then
            state.noProgressCount = (state.noProgressCount or 0) + 1
        else
            state.noProgressCount = 0
        end
    else
        state.lastPendingSignature = pendingSignature
        state.noProgressCount = 0
    end

    if (state.noProgressCount or 0) >= 30 then
        StopRaidLayoutApply(
            "Raid layout apply stopped because raid subgroup changes are being "
                .. "throttled. Wait a moment, then apply again."
        )
        return
    end

    table.sort(pending, function(left, right)
        if left.desiredGroup ~= right.desiredGroup then
            return left.desiredGroup > right.desiredGroup
        end
        if left.subgroup ~= right.subgroup then
            return left.subgroup < right.subgroup
        end
        return left.name < right.name
    end)

    for _, move in ipairs(pending) do
        if (occupancy[move.desiredGroup] or 0) < 5 then
            state.combatPaused = false
            state.lastIssuedMove = string.format("%s>%d", move.name, move.desiredGroup)
            SetRaidSubgroup(move.index, move.desiredGroup)
            ScheduleRaidLayoutApplyRetry(state, 1.5)
            return
        end
    end

    local bufferGroup = nil
    for subgroup = 1, 8 do
        if (occupancy[subgroup] or 0) < 5 then
            bufferGroup = subgroup
            break
        end
    end

    local function FindBufferChainMove(targetGroup, visitedGroups)
        if not bufferGroup then
            return nil, nil
        end

        visitedGroups = visitedGroups or {}
        if visitedGroups[targetGroup] then
            return nil, nil
        end
        visitedGroups[targetGroup] = true

        local blockers = entriesBySubgroup[targetGroup]
        if not blockers then
            return nil, nil
        end

        for _, blocker in ipairs(blockers) do
            local blockerDesired = state.targetByName[blocker.name:lower()]
            if blockerDesired and blockerDesired ~= blocker.subgroup then
                if blockerDesired == bufferGroup or (occupancy[blockerDesired] or 0) < 5 then
                    return blocker, blockerDesired
                end
            end
        end

        for _, blocker in ipairs(blockers) do
            local blockerDesired = state.targetByName[blocker.name:lower()]
            if blockerDesired and blockerDesired ~= blocker.subgroup and not visitedGroups[blockerDesired] then
                local moveEntry, moveGroup = FindBufferChainMove(blockerDesired, visitedGroups)
                if moveEntry and moveGroup then
                    return moveEntry, moveGroup
                end
            end
        end

        for _, blocker in ipairs(blockers) do
            local blockerDesired = state.targetByName[blocker.name:lower()]
            if blockerDesired and blockerDesired ~= blocker.subgroup and blocker.subgroup ~= bufferGroup then
                return blocker, bufferGroup
            end
        end

        return nil, nil
    end

    if bufferGroup then
        for _, move in ipairs(pending) do
            local blocker, blockerDestination = FindBufferChainMove(move.desiredGroup)
            if blocker and blockerDestination then
                state.combatPaused = false
                state.lastIssuedMove = string.format("%s>%d", blocker.name, blockerDestination)
                SetRaidSubgroup(blocker.index, blockerDestination)
                ScheduleRaidLayoutApplyRetry(state, 1.5)
                return
            end
        end
    end

    StopRaidLayoutApply(string.format(
        "Raid layout apply for |cffffd100%s|r stalled because the remaining target groups are full"
            .. " and no buffer move was available. Current=%s; Targets=%s; Pending=%s",
        GetRaidLayoutLabel(state.profile),
        BuildRaidLayoutOccupancyText(occupancy),
        BuildRaidLayoutOccupancyText(state.targetCounts or {}),
        BuildRaidLayoutPendingText(pending)
    ))
end

local function ApplyRaidLayoutProfile(profile, options)
    if not profile then
        return false, "Raid layout not found."
    end
    if InCombatLockdown() then
        return false, "Cannot apply a raid layout while in combat."
    end
    if not IsInRaid() then
        return false, "You must be in a raid to apply a raid layout."
    end
    if not CanManageRaidSubgroups() then
        return false,
            "You must be the raid leader or an assistant to apply a raid layout."
    end

    local difficultyOK, difficultyErr = IsRaidLayoutDifficultyMatch(profile)
    if not difficultyOK then
        return false, difficultyErr
    end

    local snapshot = GetRaidRosterSnapshot()
    if #snapshot.entries == 0 then
        return false, "No raid roster data is available yet. Try again in a moment."
    end

    local targetState, err = BuildRaidLayoutTargets(profile, snapshot)
    if not targetState then
        return false, err
    end
    if (targetState.importedCount or 0) == 0 then
        return false, "Raid layout has no listed players. Add at least one name before applying."
    end

    options = type(options) == "table" and options or nil
    local dbInviteEnabled = ARL.db and ARL.db.raidGroupInviteMissingPlayers == true
    local optionInviteValue = options and options.inviteMissing
    local shouldInviteMissing
    if optionInviteValue == nil then
        shouldInviteMissing = dbInviteEnabled
    else
        shouldInviteMissing = optionInviteValue == true
    end
    ARL._allowRaidLayoutInvites = shouldInviteMissing and dbInviteEnabled

    local invitedMissingCount = 0
    local skippedInviteCount = 0
    if ARL._allowRaidLayoutInvites and #targetState.missing > 0 then
        -- Derive the expected max size directly from the layout's difficulty field so the
        -- capacity check is reliable even when GetRaidDifficultyID / GetInstanceInfo returns
        -- stale or zero values (e.g. outside the instance or after a reload).
        local diffToken = NormalizeDifficultyToken(profile.difficulty)
        local expectedMaxSize = DIFFICULTY_MAX_PLAYERS[diffToken] or MAX_RAID_MEMBERS
        invitedMissingCount, skippedInviteCount = InviteMissingRaidLayoutPlayers(targetState.missing, expectedMaxSize)
        if skippedInviteCount > 0 then
            Print("Skipped " .. tostring(skippedInviteCount)
                .. " missing-player invite(s) because your current group is full.")
        end
    end
    ARL._allowRaidLayoutInvites = false

    ARL.db.activeRaidLayoutKey = profile.key
    ARL.raidLayoutApplyState = {
        profile = profile,
        targetByName = targetState.targetByName,
        targetCounts = targetState.targetCounts,
        matchedCount = targetState.matchedCount,
        importedCount = targetState.importedCount,
        missing = targetState.missing,
        invitedMissingCount = invitedMissingCount,
        skippedInviteCount = skippedInviteCount,
        overflowCount = targetState.overflowCount,
        waiting = false,
        combatPaused = false,
        retryAt = 0,
        retryToken = 0,
        noProgressCount = 0,
        lastPendingSignature = nil,
    }

    Print(string.format("Applying raid layout for |cffffd100%s|r...", GetRaidLayoutLabel(profile)))
    ContinueRaidLayoutApply()
    return true, profile
end

local function ApplyRaidLayoutByQuery(query, options)
    local _, profile = GetRaidLayoutProfileByQuery(query)
    if not profile then
        return false, "Raid layout not found."
    end
    return ApplyRaidLayoutProfile(profile, options)
end

-- ============================================================
-- Auto-promote logic
-- ============================================================

-- Return the highest-priority preferred leader currently in the group.
-- Returns preferredName, rosterName or nil, nil when no match is found.
local function GetTopAvailablePreferredLeader()
    local memberMap = GetGroupMemberMap()
    local playerName = UnitName("player") or ""
    local playerShort = (playerName:match("^([^%-]+)") or playerName):lower()

    for _, leaderName in ipairs(ARL.db.preferredLeaders) do
        local normalized = leaderName:lower()
        local shortName = (leaderName:match("^([^%-]+)") or leaderName):lower()
        local target = memberMap[normalized] or memberMap[shortName]
        local targetShort = target and (target:match("^([^%-]+)") or target):lower() or ""
        if target and targetShort ~= playerShort then
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
    local playerName = UnitName("player") or ""
    local playerShort = (playerName:match("^([^%-]+)") or playerName):lower()

    local leaderName, target = GetTopAvailablePreferredLeader()
    if leaderName and target then
        local targetShort = (target:match("^([^%-]+)") or target):lower()
        if targetShort == playerShort then
            return false
        end
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

function ARL.HideManualPromotePopup()
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
    local function SafePlainNumber(value)
        if type(value) == "number" then
            local ok, plain = pcall(function() return value + 0 end)
            if ok then return plain end
            return nil
        end
        if type(value) == "string" then
            local parsed = tonumber(value)
            if type(parsed) == "number" then
                return parsed
            end
        end
        return nil
    end

    local targetSpellId = SafePlainNumber(spellId)
    if not targetSpellId then
        return false
    end

    local i = 1
    while i <= 64 do
        local buffData = C_UnitAuras.GetBuffDataByIndex(unit, i)
        if not buffData then break end
        local auraSpellId = SafePlainNumber(buffData.spellId)
        if auraSpellId and auraSpellId == targetSpellId then
            return true
        end
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

    local playerInstanceID = nil
    if UnitPosition then
        playerInstanceID = select(4, UnitPosition("player"))
    end

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
    local skipped = 0
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local canQueryUnit = true
            if UnitInPhase and not UnitInPhase(unit) then
                canQueryUnit = false
            end
            if canQueryUnit and UnitPosition and playerInstanceID then
                local _, _, _, unitInstanceID = UnitPosition(unit)
                if unitInstanceID ~= playerInstanceID then
                    canQueryUnit = false
                end
            end

            -- Skip players outside the current instance/phase. Their auras are not
            -- queryable and they would otherwise appear to be missing every buff.
            if not canQueryUnit then
                skipped = skipped + 1
            else
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
    end

    if #missing == 0 then
        local msg = "Ready check: All group members have their consumables!"
        if skipped > 0 then
            msg = msg .. string.format(
                " |cff888888(%d member(s) outside your current instance or phase were skipped.)|r",
                skipped
            )
        end
        Print(msg)
    else
        Print(string.format("Ready check: %d group member(s) missing consumables:", #missing))
        for _, entry in ipairs(missing) do
            Print(string.format("  |cffffd100%s|r – missing: |cffff6666%s|r",
                entry.name, table.concat(entry.cats, ", ")))
        end
        if skipped > 0 then
            Print(string.format(
                "  |cff888888(%d member(s) outside your current instance or phase were not checked.)|r",
                skipped
            ))
        end
    end
end

-- Expose audit entry points on the ARL namespace so other files
-- (e.g. the Options window) can invoke them without going through
-- the slash-command dispatcher.
ARL.RunConsumableAudit     = RunConsumableAudit
ARL.FindConsumableCategory = FindConsumableCategory
ARL.SYSTEM_CONSUMABLES     = SYSTEM_CONSUMABLES
ARL.ParseRaidLayoutImport  = ParseRaidLayoutImport
ARL.ImportRaidLayouts      = ImportRaidLayouts
ARL.GetActiveRaidLayoutProfile = GetActiveRaidLayoutProfile
ARL.GetRaidLayoutProfileByQuery = GetRaidLayoutProfileByQuery
ARL.GetRaidLayoutLabel     = GetRaidLayoutLabel
ARL.FormatRaidDifficultyDisplay = FormatRaidDifficultyDisplay
ARL.GetRaidLayoutPreviewLines = GetRaidLayoutPreviewLines
ARL.SetActiveRaidLayoutByQuery = SetActiveRaidLayoutByQuery
ARL.DeleteRaidLayoutByQuery = DeleteRaidLayoutByQuery
ARL.ApplyRaidLayoutByQuery = ApplyRaidLayoutByQuery
ARL.ExportRaidLayoutToImportText = ExportRaidLayoutToImportText
ARL.BuildNewRaidLayoutImportText = BuildNewRaidLayoutImportText
ARL.SaveRaidLayoutFromImportText = SaveRaidLayoutFromImportText
ARL.SaveRaidLayoutProfileData = SaveRaidLayoutProfile
ARL.ContinueRaidLayoutApply = ContinueRaidLayoutApply


function ARL.CancelReminder()
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
        if ARL.raidLayoutApplyState then
            local state = ARL.raidLayoutApplyState
            state.waiting = false
            state.retryAt = 0
            if state.combatPaused then
                state.combatPaused = false
                Print("Resuming raid layout apply.")
            end
            ARL:ContinueRaidLayoutApply()
        end

    elseif event == "READY_CHECK" then
        RunConsumableAudit()

    elseif event == "ENCOUNTER_START" or event == "ENCOUNTER_END"
    then
        if HandleDeathTrackingEvent then
            HandleDeathTrackingEvent(event, ...)
        end

    elseif event == "GUILD_ROSTER_UPDATE" then
        EvaluateLeaderState("roster")

    elseif event == "GROUP_ROSTER_UPDATE" then
        local currentCount = GetNumGroupMembers()
        local trigger = "roster"
        if currentCount > lastGroupMemberCount then
            trigger = "new_member"
        end
        lastGroupMemberCount = currentCount
        if ARL.raidLayoutApplyState then
            local state = ARL.raidLayoutApplyState
            if state.waiting and state.retryAt and GetTime() >= state.retryAt then
                state.waiting = false
            end
            if not state.waiting then
                ARL:ContinueRaidLayoutApply()
            end
        end
        if trigger == "new_member"
            and ARL.db
            and ARL.db.raidGroupAutoApplyOnJoin
            and not ARL.raidLayoutApplyState
            and not InCombatLockdown()
            and ARL.db.activeRaidLayoutKey ~= ""
        then
            ApplyRaidLayoutByQuery("", { inviteMissing = false })
        end
        EvaluateLeaderState(trigger)
    end
end)

-- ============================================================
-- Death tracking
-- ============================================================

-- Per-session state (not persisted).
local WIPE_FINALIZE_MAX_RETRIES = 12
local WIPE_FINALIZE_RETRY_DELAY = 0.75

-- Format seconds as M:SS for the recap display.
local function FormatEncounterTime(seconds)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%d:%02d", m, s)
end

local function BuildDeathsFromDamageMeter(encounterIDForLookup)
    if not C_DamageMeter or type(C_DamageMeter.GetCombatSessionFromID) ~= "function" then
        return {}
    end

    -- Some Blizzard APIs can surface protected "secret number" values.
    -- These have type "number" but raise an error on any arithmetic operation.
    -- Use pcall to probe the value; if arithmetic fails it is a secret number.
    local function SafeNumber(value)
        local valueType = type(value)
        if valueType == "number" then
            local ok, plain = pcall(function() return value + 0 end)
            if ok then return plain end
            return nil
        end
        if valueType == "string" then
            local parsed = tonumber(value)
            if type(parsed) == "number" then
                return parsed
            end
        end
        return nil
    end

    local function SafeNonNegativeNumber(...)
        for i = 1, select("#", ...) do
            local parsed = SafeNumber(select(i, ...))
            if parsed ~= nil then
                local okIsNegative, isNegative = pcall(function()
                    return parsed < 0
                end)
                if okIsNegative and isNegative then
                    return 0
                end
                return parsed
            end
        end
        return nil
    end

    local deathsType = (_G.Enum and _G.Enum.DamageMeterType and _G.Enum.DamageMeterType.Deaths) or 9

    local sessionId = nil
    if type(C_DamageMeter.GetCurrentCombatSessionID) == "function" then
        sessionId = C_DamageMeter.GetCurrentCombatSessionID()
    elseif type(C_DamageMeter.GetLastCombatSessionID) == "function" then
        sessionId = C_DamageMeter.GetLastCombatSessionID()
    end

    if (not sessionId or sessionId == 0)
        and (encounterIDForLookup or 0) ~= 0
        and type(C_DamageMeter.GetCombatSessionIDByEncounterID) == "function"
    then
        sessionId = C_DamageMeter.GetCombatSessionIDByEncounterID(encounterIDForLookup)
    end

    local RECAP_TIMELINE_EVENT_LIMIT = 10

    local function ResolveSpellNameByID(spellId)
        if not spellId or spellId <= 0 then
            return nil
        end

        local GetSpellInfo = _G.GetSpellInfo
        if type(GetSpellInfo) == "function" then
            local name = GetSpellInfo(spellId)
            if type(name) == "string" and name ~= "" then
                return name
            end
        end

        local C_Spell = _G.C_Spell
        if type(C_Spell) == "table" then
            if type(C_Spell.GetSpellInfo) == "function" then
                local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
                if ok and type(info) == "table" then
                    local name = info.name or info.spellName
                    if type(name) == "string" and name ~= "" then
                        return name
                    end
                end
            end

            if type(C_Spell.GetSpellName) == "function" then
                local ok, name = pcall(C_Spell.GetSpellName, spellId)
                if ok and type(name) == "string" and name ~= "" then
                    return name
                end
            end
        end

        return nil
    end

    local function ExtractOrderedRecapEvents(payload)
        if type(payload) ~= "table" then
            return nil
        end

        local candidateContainer = payload
        if type(payload.events) == "table" then
            candidateContainer = payload.events
        elseif type(payload.recapEvents) == "table" then
            candidateContainer = payload.recapEvents
        elseif type(payload.deathEvents) == "table" then
            candidateContainer = payload.deathEvents
        end

        local indexed = {}
        for key, value in pairs(candidateContainer) do
            if type(key) == "number" and type(value) == "table" then
                indexed[#indexed + 1] = { index = key, event = value }
            end
        end

        if #indexed == 0 and type(candidateContainer[1]) == "table" then
            indexed[1] = { index = 1, event = candidateContainer[1] }
        end

        if #indexed == 0 and type(payload[1]) == "table" then
            indexed[1] = { index = 1, event = payload[1] }
        end

        if #indexed == 0 then
            return nil
        end

        table.sort(indexed, function(a, b)
            return a.index < b.index
        end)

        local events = {}
        for _, item in ipairs(indexed) do
            events[#events + 1] = item.event
        end
        return events
    end

    local function BuildRawTimelineEvents(recapEvents)
        local okExtract, events = pcall(ExtractOrderedRecapEvents, recapEvents)
        if not okExtract or type(events) ~= "table" then
            return nil
        end

        local timeline = {}
        for eventIndex, eventData in ipairs(events) do
            if type(eventData) == "table" then
                local eventToken = string.upper(tostring(
                    eventData.event
                    or eventData.eventType
                    or eventData.logEvent
                    or eventData.combatLogEvent
                    or eventData.subEvent
                    or ""
                ))
                local eventType = nil
                if eventToken:find("AURA", 1, true) then
                    eventType = "aura"
                elseif eventToken:find("HEAL", 1, true) then
                    eventType = "heal"
                elseif eventToken:find("DAMAGE", 1, true)
                    or eventToken == "SWING_DAMAGE"
                    or eventToken == "RANGE_DAMAGE"
                    or eventToken == "SPELL_DAMAGE"
                then
                    eventType = "damage"
                end

                if not eventType then
                    if eventData.auraType or eventData.dispelType or eventData.isAura then
                        eventType = "aura"
                    elseif SafeNonNegativeNumber(
                        eventData.heal,
                        eventData.healAmount,
                        eventData.healing,
                        eventData.healValue
                    ) then
                        eventType = "heal"
                    elseif SafeNonNegativeNumber(
                        eventData.damage,
                        eventData.damageAmount,
                        eventData.hitAmount,
                        eventData.rawDamage,
                        eventData.amount,
                        eventData.value
                    ) then
                        eventType = "damage"
                    end
                end

                if eventType then
                    local spellId = SafeNumber(eventData.spellID or eventData.spellId or eventData.abilityId)
                    local spellName = eventData.spellName
                        or eventData.abilityName
                        or eventData.spell
                        or eventData.ability
                    if (not spellName or spellName == "") and spellId and spellId > 0 then
                        spellName = ResolveSpellNameByID(spellId)
                    end

                    local source = nil
                    if not eventData.hideCaster then
                        source = eventData.sourceName
                            or eventData.source
                            or eventData.srcName
                            or eventData.casterName
                    end

                    local amount = nil
                    if eventType == "damage" then
                        amount = SafeNonNegativeNumber(
                            eventData.amount,
                            eventData.damage,
                            eventData.damageAmount,
                            eventData.hitAmount,
                            eventData.killingBlowAmount,
                            eventData.value,
                            eventData.rawDamage
                        )
                    elseif eventType == "heal" then
                        amount = SafeNonNegativeNumber(
                            eventData.amount,
                            eventData.heal,
                            eventData.healAmount,
                            eventData.healing,
                            eventData.value
                        )
                    end

                    local overkill = SafeNonNegativeNumber(
                        eventData.overkill,
                        eventData.overKill,
                        eventData.overkillAmount,
                        eventData.killingBlowOverkill,
                        eventData.excessDamage
                    )

                    local healthBefore = SafeNonNegativeNumber(
                        eventData.healthBefore,
                        eventData.destHealthBefore,
                        eventData.preHealth,
                        eventData.remainingHealthBefore
                    )
                    local healthAfter = SafeNonNegativeNumber(
                        eventData.healthAfter,
                        eventData.remainingHealth,
                        eventData.finalHealth,
                        eventData.destHealth
                    )
                    local healthMax = SafeNonNegativeNumber(
                        eventData.maxHealth,
                        eventData.healthMax,
                        eventData.destMaxHealth,
                        eventData.targetMaxHealth,
                        eventData.maxHP
                    )

                    local rawTimeOffset = SafeNumber(
                        eventData.timeOffset
                        or eventData.deathTimeOffset
                        or eventData.deathTimeOffsetSeconds
                        or eventData.timeSinceEncounterStart
                        or eventData.timeSinceCombatStart
                        or eventData.relativeTime
                        or eventData.relativeTimeSeconds
                        or eventData.eventTime
                        or eventData.combatTime
                        or eventData.offset
                        or eventData.elapsedTime
                        or eventData.secondsFromStart
                        or eventData.timeOfDeath
                        or eventData.timeOfDeathSeconds
                        or eventData.deathTime
                        or eventData.deathTimeSeconds
                        or eventData.timestamp
                        or eventData.timeStamp
                        or eventData.time
                    )

                    timeline[#timeline + 1] = {
                        eventType = eventType,
                        eventToken = eventToken ~= "" and eventToken or nil,
                        spellId = spellId,
                        spellName = spellName,
                        source = source,
                        amount = amount,
                        overkill = overkill,
                        auraType = eventData.auraType or eventData.dispelType,
                        healthBefore = healthBefore,
                        healthAfter = healthAfter,
                        healthMax = healthMax,
                        rawTimeOffset = rawTimeOffset,
                        rawOrder = eventIndex,
                    }
                end
            end
        end

        if #timeline == 0 then
            return nil
        end
        return timeline
    end

    local function ResolveCauseFromEventData(eventData)
        if type(eventData) ~= "table" then
            return nil, nil, nil, nil, nil, nil
        end

        local mechanic = eventData.spellName or eventData.abilityName or nil
        if not mechanic or mechanic == "" then
            local eventType = eventData.event
            if eventType == "SWING_DAMAGE" then
                mechanic = _G.ACTION_SWING or "Melee"
            elseif eventType == "ENVIRONMENTAL_DAMAGE" then
                local envType = string.upper(tostring(eventData.environmentalType or ""))
                mechanic = _G["ACTION_ENVIRONMENTAL_DAMAGE_" .. envType] or "Environmental"
            else
                mechanic = eventType or nil
            end
        end

        local source = nil
        if not eventData.hideCaster then
            source = eventData.sourceName
        end

        local spellId = SafeNumber(eventData.spellID or eventData.spellId or eventData.abilityId)
        local recapTimeOffset = SafeNumber(
            eventData.timeOffset
            or eventData.deathTimeOffset
            or eventData.deathTimeOffsetSeconds
            or eventData.timeSinceEncounterStart
            or eventData.timeSinceCombatStart
            or eventData.elapsedTime
            or eventData.secondsFromStart
            or eventData.timeOfDeath
            or eventData.timeOfDeathSeconds
            or eventData.deathTime
            or eventData.deathTimeSeconds
            or eventData.timestamp
            or eventData.time
        )

        local recapOverkill = SafeNonNegativeNumber(
            eventData.overkill,
            eventData.overKill,
            eventData.overkillAmount,
            eventData.killingBlowOverkill,
            eventData.excessDamage
        )
        local recapAmount = SafeNonNegativeNumber(
            eventData.amount,
            eventData.damage,
            eventData.damageAmount,
            eventData.hitAmount,
            eventData.killingBlowAmount,
            eventData.value,
            eventData.rawDamage
        )

        if recapOverkill == nil then
            local healthAfter = SafeNumber(
                eventData.remainingHealth
                or eventData.finalHealth
                or eventData.healthAfter
                or eventData.destHealth
            )
            local okIsNegative, isNegative = pcall(function()
                return healthAfter and healthAfter < 0
            end)
            if okIsNegative and isNegative then
                recapOverkill = -healthAfter
            end
        end

        local healthAtDeath = SafeNonNegativeNumber(
            eventData.healthAfter,
            eventData.remainingHealth,
            eventData.finalHealth,
            eventData.destHealth,
            eventData.health
        )
        local healthMaxAtDeath = SafeNonNegativeNumber(
            eventData.maxHealth,
            eventData.healthMax,
            eventData.destMaxHealth,
            eventData.targetMaxHealth
        )

        return mechanic, source, spellId, recapTimeOffset, recapOverkill, recapAmount, nil,
            healthAtDeath, healthMaxAtDeath
    end

    local function ResolveRecapCause(entry)
        local recapID = SafeNumber(entry and entry.deathRecapID) or 0
        if recapID > 0
            and _G.C_DeathRecap
            and type(_G.C_DeathRecap.GetRecapEvents) == "function"
        then
            local okRecap, recapEvents = pcall(_G.C_DeathRecap.GetRecapEvents, recapID)
            if okRecap and type(recapEvents) == "table" then
                local m, s, sp, o, ok, am, tl, hd, hm = ResolveCauseFromEventData(recapEvents[1])
                if m or s or sp then
                    local okTimeline, timelineResult = pcall(BuildRawTimelineEvents, recapEvents)
                    if okTimeline then
                        tl = timelineResult
                    end
                    return m, s, sp, o, ok, am, tl, hd, hm
                end
            end
        end

        local destGUID = entry and (entry.destGUID or entry.destGuid or entry.playerGUID or entry.playerGuid)
        sessionId = SafeNonNegativeNumber(sessionId)
        if not destGUID or destGUID == "" or not sessionId or sessionId == 0 then
            return nil, nil, nil, nil, nil, nil, nil, nil, nil
        end
        if type(C_DamageMeter.GetDamageDataForPlayerByType) ~= "function" then
            return nil, nil, nil, nil, nil, nil, nil, nil, nil
        end

        local okDamageMeter, recapEvents = pcall(function()
            return C_DamageMeter.GetDamageDataForPlayerByType(sessionId, destGUID, deathsType)
        end)
        if not okDamageMeter or type(recapEvents) ~= "table" then
            return nil, nil, nil, nil, nil, nil, nil, nil, nil
        end

        local m, s, sp, o, ok, am, tl, hd, hm = ResolveCauseFromEventData(recapEvents[1])
        local okTimeline, timelineResult = pcall(BuildRawTimelineEvents, recapEvents)
        if okTimeline then
            tl = timelineResult
        end
        return m, s, sp, o, ok, am, tl, hd, hm
    end

    local function ParseDeathEntries(container, encounterDuration, sessionStartTime)
        if type(container) ~= "table" then return {} end

        local function ToPlainNumber(...)
            for i = 1, select("#", ...) do
                local value = select(i, ...)
                local parsed = SafeNumber(value)
                if parsed ~= nil then
                    return parsed
                end
            end
            return 0
        end

        local function ClampNonNegative(value)
            local okIsNegative, isNegative = pcall(function()
                return value < 0
            end)
            if okIsNegative and isNegative then
                return 0
            end
            return value
        end

        local function IsPlausibleOffset(value)
            if value == nil then return false end
            local bounded = ClampNonNegative(value)
            local maxExpected = 7200
            if encounterDuration and encounterDuration > 0 then
                maxExpected = encounterDuration + 5
            end
            return bounded <= maxExpected
        end

        local function NormalizeCandidateSeconds(candidate)
            candidate = ClampNonNegative(candidate)
            if IsPlausibleOffset(candidate) then
                return candidate
            end

            -- Some APIs expose milliseconds; convert when plausible.
            local asSeconds = candidate / 1000
            if IsPlausibleOffset(asSeconds) then
                return asSeconds
            end

            return nil
        end

        local function ResolveRelativeSeconds(candidate, startTime)
            if not startTime or startTime <= 0 then return nil end

            local delta = NormalizeCandidateSeconds(candidate - startTime)
            if delta ~= nil then
                return delta
            end

            -- Handle mixed precision (seconds vs milliseconds) timestamps.
            delta = NormalizeCandidateSeconds((candidate / 1000) - startTime)
            if delta ~= nil then
                return delta
            end
            delta = NormalizeCandidateSeconds(candidate - (startTime / 1000))
            if delta ~= nil then
                return delta
            end
            delta = NormalizeCandidateSeconds((candidate / 1000) - (startTime / 1000))
            if delta ~= nil then
                return delta
            end

            return nil
        end

        local function ResolveEncounterTimeOffset(entry, recapTimeOffset)
            -- Special handling for deathTimeSeconds, which may be a tainted "secret number".
            -- SafeNumber untaints it via pcall(value + 0); without this the bare comparison
            -- below throws "attempt to compare ... a secret number value tainted by ...".
            if entry and type(entry.deathTimeSeconds) == "number" then
                local val = SafeNumber(entry.deathTimeSeconds)
                if val ~= nil then
                    val = ClampNonNegative(val)
                    local okCmp, inRange = pcall(function() return val > 0 and val <= 7200 end)
                    if okCmp and inRange then
                        return val
                    end
                end
            end

            local rawCandidates = {
                entry and entry.timeOffset,
                entry and entry.deathTimeOffset,
                entry and entry.deathTimeOffsetSeconds,
                entry and entry.timeSinceEncounterStart,
                entry and entry.timeSinceCombatStart,
                entry and entry.elapsedSeconds,
                entry and entry.secondsFromStart,
                entry and entry.timeOfDeath,
                entry and entry.timeOfDeathSeconds,
                entry and entry.deathTime,
                recapTimeOffset,
                -- Last-resort fields for clients that only expose generic time values.
                entry and entry.elapsedTime,
                entry and entry.time,
            }

            for _, raw in ipairs(rawCandidates) do
                local candidate = SafeNumber(raw)
                if candidate ~= nil then
                    local normalized = NormalizeCandidateSeconds(candidate)
                    if normalized ~= nil then
                        return normalized
                    end

                    local relative = ResolveRelativeSeconds(candidate, sessionStartTime)
                    if relative ~= nil then
                        return relative
                    end
                end
            end

            return nil
        end

        local function NormalizeTimelineEvents(rawEvents, fallbackAnchorOffset)
            if type(rawEvents) ~= "table" then
                return nil, false
            end

            local normalized = {}
            for _, event in ipairs(rawEvents) do
                if type(event) == "table" then
                    local eventOffset = ResolveEncounterTimeOffset(event, event.rawTimeOffset)
                    local eventTimeStr = "?:??"
                    if eventOffset ~= nil then
                        eventTimeStr = FormatEncounterTime(math.floor(eventOffset))
                    end

                    normalized[#normalized + 1] = {
                        eventType = event.eventType,
                        eventToken = event.eventToken,
                        spellId = event.spellId,
                        spellName = event.spellName,
                        source = event.source,
                        amount = event.amount,
                        overkill = event.overkill,
                        auraType = event.auraType,
                        healthBefore = event.healthBefore,
                        healthAfter = event.healthAfter,
                        healthMax = event.healthMax,
                        timeOffset = eventOffset,
                        timeStr = eventTimeStr,
                        rawOrder = event.rawOrder,
                    }
                end
            end

            table.sort(normalized, function(a, b)
                local left = a and a.timeOffset
                local right = b and b.timeOffset
                local leftOrder = ToPlainNumber(a and a.rawOrder)
                local rightOrder = ToPlainNumber(b and b.rawOrder)
                if left == nil and right == nil then
                    return leftOrder < rightOrder
                end
                if left == nil or right == nil then
                    return leftOrder < rightOrder
                end
                left = ToPlainNumber(left)
                right = ToPlainNumber(right)
                local okCompare, result = pcall(function()
                    return left < right
                end)
                if okCompare then
                    return result
                end
                return tostring(left) < tostring(right)
            end)

            if #normalized == 0 then
                return nil, false
            end

            local timelineTruncated = #normalized > RECAP_TIMELINE_EVENT_LIMIT
            if timelineTruncated then
                local trimmed = {}
                local startIndex = #normalized - RECAP_TIMELINE_EVENT_LIMIT + 1
                for i = startIndex, #normalized do
                    trimmed[#trimmed + 1] = normalized[i]
                end
                normalized = trimmed
            end

            local hasPreciseTime = false
            for _, event in ipairs(normalized) do
                if event and event.timeOffset ~= nil then
                    hasPreciseTime = true
                    break
                end
            end

            local function NormalizeSyntheticOffset(value)
                local plain = SafeNumber(value)
                if plain == nil then
                    return nil
                end
                plain = ClampNonNegative(plain)
                if plain == nil then
                    return nil
                end
                return math.floor(plain)
            end

            local anchorOffset = NormalizeSyntheticOffset(fallbackAnchorOffset)

            if not hasPreciseTime then
                if anchorOffset ~= nil then
                    local newestIndex = #normalized
                    for i, event in ipairs(normalized) do
                        local syntheticOffset = anchorOffset - (newestIndex - i)
                        syntheticOffset = math.max(0, syntheticOffset)
                        event.timeOffset = syntheticOffset
                        event.timeStr = FormatEncounterTime(syntheticOffset)
                    end
                else
                    for _, event in ipairs(normalized) do
                        event.timeStr = "?:??"
                    end
                end
            else
                for i, event in ipairs(normalized) do
                    if event.timeOffset == nil then
                        local inferredOffset

                        for j = i + 1, #normalized do
                            local nextOffset = NormalizeSyntheticOffset(normalized[j].timeOffset)
                            if nextOffset ~= nil then
                                inferredOffset = math.max(0, nextOffset - (j - i))
                                break
                            end
                        end

                        if inferredOffset == nil then
                            for j = i - 1, 1, -1 do
                                local prevOffset = NormalizeSyntheticOffset(normalized[j].timeOffset)
                                if prevOffset ~= nil then
                                    inferredOffset = prevOffset + (i - j)
                                    break
                                end
                            end
                        end

                        if inferredOffset == nil and anchorOffset ~= nil then
                            inferredOffset = math.max(0, anchorOffset - (#normalized - i))
                        end

                        if inferredOffset ~= nil then
                            event.timeOffset = inferredOffset
                            event.timeStr = FormatEncounterTime(inferredOffset)
                        else
                            event.timeStr = "?:??"
                        end
                    end
                end
            end

            return normalized, timelineTruncated
        end

        local parsed = {}
        for _, entry in pairs(container) do
            if type(entry) == "table" then
                local playerName = entry.playerName or entry.destName or entry.name or entry.player or "Unknown"
                local mechanic   = entry.mechanic or entry.spellName or entry.abilityName or entry.cause or "Unknown"
                local source     = entry.sourceName or entry.source or entry.killerName or "Unknown"
                local spellId    = SafeNumber(
                    entry.spellID or entry.spellId or entry.abilityId
                    or entry.mechanicSpellID or entry.causeSpellID or entry.causeSpellId
                )
                local overkill = SafeNonNegativeNumber(
                    entry.overkill,
                    entry.overKill,
                    entry.overkillAmount,
                    entry.killingBlowOverkill,
                    entry.excessDamage
                )
                local hitAmount = SafeNonNegativeNumber(
                    entry.amount,
                    entry.damage,
                    entry.damageAmount,
                    entry.hitAmount,
                    entry.killingBlowAmount,
                    entry.finalAmount,
                    entry.value
                )
                local recapMechanic, recapSource, recapSpellId, recapTimeOffset,
                    recapOverkill, recapAmount, recapTimelineRaw,
                    recapHealthAtDeath, recapHealthMaxAtDeath = ResolveRecapCause(entry)
                if recapMechanic and recapMechanic ~= "" then
                    mechanic = recapMechanic
                end
                if recapSource and recapSource ~= "" then
                    source = recapSource
                end
                if recapSpellId and recapSpellId > 0 then
                    spellId = recapSpellId
                end
                if recapOverkill and recapOverkill > 0 then
                    overkill = recapOverkill
                end
                if recapAmount and recapAmount > 0 then
                    hitAmount = recapAmount
                end

                local timeOffset = ResolveEncounterTimeOffset(entry, recapTimeOffset)
                local timeStr = "?:??"
                if timeOffset ~= nil then
                    timeStr = FormatEncounterTime(math.floor(timeOffset))
                end
                local eventTimeline, timelineTruncated = NormalizeTimelineEvents(recapTimelineRaw, timeOffset)
                parsed[#parsed + 1] = {
                    playerName = playerName,
                    mechanic   = mechanic,
                    source     = source,
                    spellId    = spellId,
                    overkill   = overkill,
                    hitAmount  = hitAmount,
                    timeOffset = timeOffset,
                    timeStr    = timeStr,
                    eventTimeline = eventTimeline,
                    timelineTruncated = timelineTruncated,
                    healthAtDeath = recapHealthAtDeath,
                    healthMaxAtDeath = recapHealthMaxAtDeath,
                }
            end
        end
        table.sort(parsed, function(a, b)
            local left = (a and a.timeOffset)
            local right = (b and b.timeOffset)
            if left == nil and right == nil then return false end
            if left == nil then return false end
            if right == nil then return true end
            left = ToPlainNumber(left)
            right = ToPlainNumber(right)
            local okCompare, result = pcall(function()
                return left < right
            end)
            if okCompare then
                return result
            end
            return tostring(left) < tostring(right)
        end)
        return parsed
    end

    local function ExtractDeathsFromSession(session)
        if type(session) ~= "table" then return {} end

        local encounterDuration = SafeNumber(session.durationSeconds)
            or SafeNumber(session.combatDurationSeconds)
            or SafeNumber(session.elapsedTime)
            or SafeNumber(session.duration)
            or 0
        local sessionStartTime = SafeNumber(
            session.startTimeSeconds
            or session.combatStartTimeSeconds
            or session.startTime
            or session.combatStartTime
        )
        local sessionEndTime = SafeNumber(
            session.endTimeSeconds
            or session.combatEndTimeSeconds
            or session.endTime
            or session.combatEndTime
        )

        if (not sessionStartTime or sessionStartTime <= 0)
            and sessionEndTime and sessionEndTime > 0
            and encounterDuration and encounterDuration > 0
        then
            local candidates = {
                sessionEndTime - encounterDuration,
                (sessionEndTime / 1000) - encounterDuration,
                sessionEndTime - (encounterDuration * 1000),
                (sessionEndTime / 1000) - (encounterDuration / 1000),
            }
            for _, candidate in ipairs(candidates) do
                local plain = SafeNumber(candidate)
                if plain and plain > 0 then
                    sessionStartTime = plain
                    break
                end
            end
        end

        -- Older/alternate layouts.
        local deathList = session.deaths or session.Deaths or session.deathLog or session.DeathLog
        local parsed = ParseDeathEntries(deathList, encounterDuration, sessionStartTime)
        if #parsed > 0 then return parsed end

        -- Midnight 12.x layout for Deaths meter type.
        parsed = ParseDeathEntries(session.combatSources, encounterDuration, sessionStartTime)
        if #parsed > 0 then return parsed end

        return {}
    end

    local function GetSessionByID(id)
        if not id then return nil end
        local ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, id, deathsType)
        if ok and type(session) == "table" then
            return session
        end
        return nil
    end

    local function GetSessionByType(sessionType)
        if type(C_DamageMeter.GetCombatSessionFromType) ~= "function" then
            return nil
        end
        local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, deathsType)
        if ok and type(session) == "table" then
            return session
        end
        return nil
    end

    local session = GetSessionByID(sessionId)
    if not session then
        -- Fall back to session-type lookup when an ID is unavailable at wipe end.
        local dmSessionType = _G.Enum and _G.Enum.DamageMeterSessionType
        local currentSessionType = (dmSessionType and dmSessionType.Current) or 1
        local expiredSessionType = (dmSessionType and dmSessionType.Expired) or 2
        session = GetSessionByType(currentSessionType) or GetSessionByType(expiredSessionType)
    end

    return ExtractDeathsFromSession(session)
end

local function PersistEncounterRecap(encounterName, deaths, encounterOutcome, autoOpen)
    if not ARL.db then return end
    local recapDate = date("%Y-%m-%d %H:%M")
    local _, difficultyName = GetCurrentRaidDifficultyInfo()
    local recap = {
        encounter = encounterName,
        difficulty = Trim(difficultyName),
        date = recapDate,
        outcome = (encounterOutcome == "wipe") and "wipe" or "kill",
        deaths = deaths,
    }

    if type(ARL.db.deathRecapHistory) ~= "table" then
        ARL.db.deathRecapHistory = {}
    end
    table.insert(ARL.db.deathRecapHistory, 1, recap)

    local maxStored = tonumber(ARL.db.maxDeathRecapsStored) or DEFAULTS.maxDeathRecapsStored
    if maxStored < 1 then
        maxStored = DEFAULTS.maxDeathRecapsStored
        ARL.db.maxDeathRecapsStored = maxStored
    end
    if #ARL.db.deathRecapHistory > maxStored then
        for i = #ARL.db.deathRecapHistory, maxStored + 1, -1 do
            ARL.db.deathRecapHistory[i] = nil
        end
    end

    -- Keep legacy fields synchronized for backward compatibility.
    ARL.db.lastWipeDeaths = recap.deaths
    ARL.db.lastWipeEncounter = recap.encounter
    ARL.db.lastWipeDate = recap.date

    local outcomeText = recap.outcome
    Print(string.format(
        "Encounter (%s) recorded on |cffffd100%s|r - %d death(s). "
            .. "Stored %d recap(s). Type |cffffff00/arl deaths|r to view the latest.",
        outcomeText,
        ARL.db.lastWipeEncounter,
        #deaths,
        #ARL.db.deathRecapHistory
    ))

    if autoOpen and ARL.ShowDeathRecap then
        ARL:ShowDeathRecap()
    end
end

local function HasReliableDeathTiming(deaths)
    if type(deaths) ~= "table" then return false end
    for _, entry in ipairs(deaths) do
        local offset = entry and entry.timeOffset
        if type(offset) == "number" then
            local ok, valid = pcall(function()
                return offset > 0
            end)
            if ok and valid then
                return true
            end
        end
    end
    return false
end

local function HasDamageDetailValues(deaths)
    if type(deaths) ~= "table" then return false end
    for _, entry in ipairs(deaths) do
        local hitAmount = entry and entry.hitAmount
        if type(hitAmount) == "number" then
            local ok, valid = pcall(function()
                return hitAmount > 0
            end)
            if ok and valid then
                return true
            end
        end

        local overkill = entry and entry.overkill
        if type(overkill) == "number" then
            local ok, valid = pcall(function()
                return overkill > 0
            end)
            if ok and valid then
                return true
            end
        end
    end
    return false
end

local function FinalizeEncounterRecapWithRetries(encounterName, encounterID, encounterOutcome, autoOpen, attempt)
    if not ARL.db or not ARL.db.deathTrackingEnabled then return end

    local meterDeaths = BuildDeathsFromDamageMeter(encounterID)
    if #meterDeaths > 0 then
        local hasTiming = HasReliableDeathTiming(meterDeaths)
        local hasDamageDetails = HasDamageDetailValues(meterDeaths)
        local isLikelyPartial = (not hasTiming) and (not hasDamageDetails)
        if isLikelyPartial and attempt < WIPE_FINALIZE_MAX_RETRIES then
            _G.C_Timer.After(WIPE_FINALIZE_RETRY_DELAY, function()
                FinalizeEncounterRecapWithRetries(encounterName, encounterID, encounterOutcome, autoOpen, attempt + 1)
            end)
            return
        end

        PersistEncounterRecap(encounterName, meterDeaths, encounterOutcome, autoOpen)
        return
    end

    if attempt < WIPE_FINALIZE_MAX_RETRIES then
        _G.C_Timer.After(WIPE_FINALIZE_RETRY_DELAY, function()
            FinalizeEncounterRecapWithRetries(encounterName, encounterID, encounterOutcome, autoOpen, attempt + 1)
        end)
        return
    end

    PersistEncounterRecap(encounterName, {}, encounterOutcome, autoOpen)
end

HandleDeathTrackingEvent = function(event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        currentEncounterID     = tonumber(encounterID) or 0
        currentEncounterName   = encounterName or "Unknown"

    elseif event == "ENCOUNTER_END" then
        local _, encounterName, _, _, success = ...

        if ARL.db and ARL.db.deathTrackingEnabled and IsInRelevantDeathGroup() then
            local finalEncounterName = encounterName or currentEncounterName
            local finalEncounterID = currentEncounterID
            if success == 0 then
                FinalizeEncounterRecapWithRetries(
                    finalEncounterName,
                    finalEncounterID,
                    "wipe",
                    ARL.db.showRecapOnWipe,
                    0
                )
            elseif ARL.db.showRecapOnEncounterEnd then
                FinalizeEncounterRecapWithRetries(
                    finalEncounterName,
                    finalEncounterID,
                    "kill",
                    true,
                    0
                )
            end
        end

        currentEncounterID     = 0
        currentEncounterName   = ""
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
                Print(
                    "No consumables are being tracked. "
                    .. "Use |cffffff00/arl consumable add <label> <spellId>|r to add one."
                )
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
                        Print(string.format(
                            "Spell ID %d is already in the |cffffd100%s|r category.",
                            spellId,
                            cat.label
                        ))
                        return
                    end
                end
                table.insert(cat.spellIds, spellId)
                Print(string.format("Added spell ID %d to |cffffd100%s|r.", spellId, cat.label))
            else
                table.insert(ARL.db.trackedConsumables, { label = label, spellIds = { spellId } })
                Print(string.format(
                    "Created new category |cffffd100%s|r with spell ID %d.",
                    label,
                    spellId
                ))
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
            Print(
                "  |cffffff00/arl consumable remove <label> <spellId>|r    – Remove a spell ID from a category"
            )
            Print("  |cffffff00/arl consumable delete <label>|r              – Delete an entire category")
            Print(
                "  |cffffff00/arl consumable clear|r                       "
                .. "– Remove all tracked consumable categories"
            )
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
            Print(string.format(
                "Consumable audit on ready check is currently |cff%s%s|r.",
                ARL.db.consumableAuditEnabled and "00ff00" or "ff0000",
                ARL.db.consumableAuditEnabled and "enabled" or "disabled"))
        end

    -- /arl grouptype [all|raid|party|guild_raid|guild_party]
    elseif cmd == "grouptype" then
        local key, onoff = arg:lower():match("^(%S+)%s*(.*)$")
        local VALID = { raid=true, party=true, guild_raid=true, guild_party=true }
        local FLBL  = { raid="raids", party="parties", guild_raid="guild raids", guild_party="guild parties" }
        if key and VALID[key] then
            if type(ARL.db.groupTypeFilter) ~= "table" then ARL.db.groupTypeFilter = {} end
            if onoff == "on" then
                ARL.db.groupTypeFilter[key] = true
            elseif onoff == "off" then
                ARL.db.groupTypeFilter[key] = false
            else
                ARL.db.groupTypeFilter[key] = not ARL.db.groupTypeFilter[key]
            end
            local en = ARL.db.groupTypeFilter[key]
            Print(string.format("Group type filter: %s |cff%s%s|r.",
                FLBL[key], en and "00ff00" or "ff0000", en and "enabled" or "disabled"))
        else
            local f = type(ARL.db.groupTypeFilter) == "table" and ARL.db.groupTypeFilter or {}
            local parts = {}
            for _, k in ipairs({"raid","party","guild_raid","guild_party"}) do
                if f[k] then parts[#parts+1] = FLBL[k] end
            end
            Print(string.format("Group type filter: |cffffff00%s|r.",
                #parts > 0 and table.concat(parts, ", ") or "none"))
            if key then Print("Usage: /arl grouptype [raid|party|guild_raid|guild_party] [on|off]") end
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
        local currentEntry = ARL.db.guildRankPriority[foundAt]
        local currentName = type(currentEntry) == "table" and currentEntry.name or tostring(currentEntry)
        if foundAt == pos then
            Print(string.format("|cffffd100%s|r is already at position %d.", currentName, pos))
            return
        end
        local entry = table.remove(ARL.db.guildRankPriority, foundAt)
        local entryName = type(entry) == "table" and entry.name or tostring(entry)
        table.insert(ARL.db.guildRankPriority, pos, entry)
        Print(string.format("Moved |cffffd100%s|r to position %d.", entryName, pos))

    -- /arl raidgroups [list|select|apply|delete|clear|status]
    elseif cmd == "raidgroups" or cmd == "raidgroup" then
        local subcmd, rest = arg:match("^(%S+)%s*(.*)")
        if not subcmd then subcmd = "status" end
        subcmd = subcmd:lower()
        rest = rest or ""

        if subcmd == "list" then
            if #ARL.db.raidLayouts == 0 then
                Print("No raid layouts are saved yet. Open /arl settings and use the Raid Groups panel to import one.")
                return
            end
            Print("Saved raid layouts:")
            for i, profile in ipairs(ARL.db.raidLayouts) do
                local marker = (profile.key == ARL.db.activeRaidLayoutKey) and "*" or " "
                Print(string.format("  %s %d. |cffffd100%s|r", marker, i, GetRaidLayoutLabel(profile)))
            end

        elseif subcmd == "select" then
            if Trim(rest) == "" then
                Print("Usage: /arl raidgroups select <encounterID|name>")
                return
            end
            local ok, result = SetActiveRaidLayoutByQuery(rest)
            if not ok then
                Print(result)
                return
            end
            Print(string.format("Selected raid layout |cffffd100%s|r.", GetRaidLayoutLabel(result)))

        elseif subcmd == "apply" then
            local ok, result = ApplyRaidLayoutByQuery(rest)
            if not ok then
                Print(result)
            end

        elseif subcmd == "delete" then
            if Trim(rest) == "" then
                Print("Usage: /arl raidgroups delete <encounterID|name>")
                return
            end
            local ok, result = DeleteRaidLayoutByQuery(rest)
            if not ok then
                Print(result)
                return
            end
            Print(string.format("Deleted raid layout |cffffd100%s|r.", GetRaidLayoutLabel(result)))

        elseif subcmd == "clear" then
            ARL.db.raidLayouts = {}
            ARL.db.activeRaidLayoutKey = ""
            Print("Cleared all saved raid layouts.")

        elseif subcmd == "status" then
            local active = GetActiveRaidLayoutProfile()
            if active then
                Print(string.format(
                    "Saved raid layouts: |cffffff00%d|r. Active layout: |cffffd100%s|r.",
                    #ARL.db.raidLayouts,
                    GetRaidLayoutLabel(active)
                ))
            else
                Print(string.format(
                    "Saved raid layouts: |cffffff00%d|r. No active layout selected.",
                    #ARL.db.raidLayouts
                ))
            end
            Print("Use /arl settings to import Viserio notes, or /arl raidgroups list to inspect saved layouts.")

        else
            Print("Raid group sub-commands:")
            Print("  |cffffff00/arl raidgroups status|r                 – Show the active saved raid layout")
            Print("  |cffffff00/arl raidgroups list|r                   – List all saved raid layouts")
            Print("  |cffffff00/arl raidgroups select <id|name>|r       – Select a saved raid layout")
            Print("  |cffffff00/arl raidgroups apply [id|name]|r        – Apply the active or named raid layout")
            Print("  |cffffff00/arl raidgroups delete <id|name>|r       – Delete a saved raid layout")
            Print("  |cffffff00/arl raidgroups clear|r                  – Delete all saved raid layouts")
        end

    -- /arl settings | /arl options | /arl config
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        if ARL.ShowOptions then
            ARL:ShowOptions()
        else
            Print("Settings UI is not available yet. Try again in a moment.")
        end

    -- /arl deaths [index] | /arl wipe  – show stored death recap(s)
    elseif cmd == "deaths" or cmd == "wipe" then
        if ARL.ShowDeathRecap then
            local requestedIndex = tonumber(Trim(arg))
            ARL:ShowDeathRecap(requestedIndex)
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

    -- /arl deathgrouptype [all|raid|party|guild_raid|guild_party]
    elseif cmd == "deathgrouptype" then
        local key, onoff = arg:lower():match("^(%S+)%s*(.*)$")
        local VALID = { raid=true, party=true, guild_raid=true, guild_party=true }
        local FLBL  = { raid="raids", party="parties", guild_raid="guild raids", guild_party="guild parties" }
        if key and VALID[key] then
            if type(ARL.db.deathGroupTypeFilter) ~= "table" then ARL.db.deathGroupTypeFilter = {} end
            if onoff == "on" then
                ARL.db.deathGroupTypeFilter[key] = true
            elseif onoff == "off" then
                ARL.db.deathGroupTypeFilter[key] = false
            else
                ARL.db.deathGroupTypeFilter[key] = not ARL.db.deathGroupTypeFilter[key]
            end
            local en = ARL.db.deathGroupTypeFilter[key]
            Print(string.format("Death recap group filter: %s |cff%s%s|r.",
                FLBL[key], en and "00ff00" or "ff0000", en and "enabled" or "disabled"))
        else
            local f = type(ARL.db.deathGroupTypeFilter) == "table" and ARL.db.deathGroupTypeFilter or {}
            local parts = {}
            for _, k in ipairs({"raid","party","guild_raid","guild_party"}) do
                if f[k] then parts[#parts+1] = FLBL[k] end
            end
            Print(string.format("Death recap group filter: |cffffff00%s|r.",
                #parts > 0 and table.concat(parts, ", ") or "none"))
            if key then Print("Usage: /arl deathgrouptype [raid|party|guild_raid|guild_party] [on|off]") end
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
        Print(
            "  |cffffff00/arl grouptype [raid|party|guild_raid|guild_party] [on|off]|r "
            .. "– Toggle auto-promote per group type"
        )
        Print("  |cffffff00/arl deaths [index]|r     – Show latest death recap or a specific stored recap")
        Print("  |cffffff00/arl deathtracking [on|off]|r – Toggle death tracking during encounters")
        Print(
            "  |cffffff00/arl deathgrouptype [raid|party|guild_raid|guild_party] [on|off]|r "
            .. "– Toggle death recap capture per group type"
        )
        Print("  |cffffff00/arl consumable ...|r     – Manage tracked consumable categories (run for sub-commands)")
        Print("  |cffffff00/arl consumableaudit [on|off]|r – Toggle consumable audit on ready check")
        Print("  |cffffff00/arl rankpriority [on|off]|r – Toggle guild rank priority fallback")
        Print("  |cffffff00/arl addrank <rank>|r     – Add a guild rank to the priority list")
        Print("  |cffffff00/arl removerank <rank>|r  – Remove a guild rank from the priority list")
        Print("  |cffffff00/arl ranklist|r            – Show the guild rank priority list")
        Print("  |cffffff00/arl clearranks|r          – Clear the guild rank priority list")
        Print("  |cffffff00/arl moverank <rank> <pos>|r – Move a guild rank to a specific position")
        Print("  |cffffff00/arl raidgroups ...|r      – Manage imported raid-group layouts")
        Print("  |cffffff00/arl settings|r           – Open the in-game settings window")
        Print("  |cffffff00/arl help|r               – Show this help message")

    else
        Print(string.format("Unknown command: |cffffff00%s|r. Type /arl help for a list of commands.", cmd))
    end
end
