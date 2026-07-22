-- AstralRaidLeader_RaidLayouts_BossAssignments.lua
-- Boss-specific raid layout parsing and subgroup assignment helpers.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

local UnitName = _G.UnitName
local GetNumGroupMembers = _G.GetNumGroupMembers
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned

ARL.RaidLayoutBossAssignments = ARL.RaidLayoutBossAssignments or {}

local function Trim(value)
    if value == nil then return "" end
    return tostring(value):match("^%s*(.-)%s*$")
end

local function GetShortName(name)
    local trimmed = Trim(name)
    return trimmed:match("^([^%-]+)") or trimmed
end

local function NormalizeDifficultyToken(value)
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

local function GetEncounterDifficultyKey(encounterID, difficultyToken)
    local id = tonumber(encounterID)
    local diff = NormalizeDifficultyToken(difficultyToken)
    if not id or id <= 0 or diff == "" then
        return ""
    end
    return tostring(id) .. ":" .. diff
end

local ASSIGNMENT_MODE_CATALOG = {
    {
        key = GetEncounterDifficultyKey(3306, "mythic"),
        encounterID = 3306,
        difficultyToken = "mythic",
        encounterLabel = "Chimaerus (Mythic)",
        modes = {
            { key = "default", label = "Alndust Upheaval Soaks" },
        },
        defaultMode = "default",
    },
    {
        key = GetEncounterDifficultyKey(3180, "mythic"),
        encounterID = 3180,
        difficultyToken = "mythic",
        encounterLabel = "Vanguard (Mythic)",
        modes = {
            { key = "execution_sentence", label = "Execution Sentence Soaks" },
            { key = "tyrs_wrath_group4", label = "Normal Split + Tyr's Wrath in Group 4" },
        },
        defaultMode = "execution_sentence",
    },
    {
        key = GetEncounterDifficultyKey(3183, "mythic"),
        encounterID = 3183,
        difficultyToken = "mythic",
        encounterLabel = "Nexus-King Salhadaar (Mythic)",
        modes = {
            { key = "default", label = "P3 Sides Left/Right" },
        },
        defaultMode = "default",
    },
}

local ASSIGNMENT_MODE_BY_KEY = {}
for _, entry in ipairs(ASSIGNMENT_MODE_CATALOG) do
    if entry.key and entry.key ~= "" then
        ASSIGNMENT_MODE_BY_KEY[entry.key] = entry
    end
end

local function ResolveConfiguredModeForEncounter(encounterID, difficultyToken, modeOverrides, fallbackMode)
    local encounterKey = GetEncounterDifficultyKey(encounterID, difficultyToken)
    if encounterKey == "" then
        return fallbackMode
    end

    if type(modeOverrides) == "table" then
        local configured = Trim(modeOverrides[encounterKey])
        if configured == "disabled" then
            return "disabled"
        end
        if configured ~= "" then
            return configured
        end
    end

    local catalog = ASSIGNMENT_MODE_BY_KEY[encounterKey]
    if type(catalog) == "table" and Trim(catalog.defaultMode) ~= "" then
        return catalog.defaultMode
    end

    return fallbackMode
end

function ARL.RaidLayoutBossAssignments.GetAssignmentModeCatalog()
    local list = {}
    for _, entry in ipairs(ASSIGNMENT_MODE_CATALOG) do
        local copy = {
            key = entry.key,
            encounterID = entry.encounterID,
            difficultyToken = entry.difficultyToken,
            encounterLabel = entry.encounterLabel,
            defaultMode = entry.defaultMode,
            modes = {},
        }
        for _, mode in ipairs(entry.modes or {}) do
            copy.modes[#copy.modes + 1] = {
                key = mode.key,
                label = mode.label,
            }
        end
        list[#list + 1] = copy
    end
    return list
end

function ARL.RaidLayoutBossAssignments.ResolveModeForEncounter(encounterID, difficulty, modeOverrides)
    return ResolveConfiguredModeForEncounter(encounterID, difficulty, modeOverrides, "default")
end

local function NewRaidLayoutGroups()
    local groups = {}
    for subgroup = 1, 8 do
        groups[subgroup] = {}
    end
    return groups
end

local function ParseImportNameList(rawText)
    local parsed = {}
    local seen = {}
    local text = Trim(rawText)
    if text == "" then
        return parsed
    end

    local hasComma = text:find(",", 1, true) ~= nil
    if hasComma then
        for token in text:gmatch("([^,]+)") do
            local clean = Trim(token)
            local key = clean:lower()
            if clean ~= "" and not seen[key] then
                seen[key] = true
                parsed[#parsed + 1] = clean
            end
        end
    else
        for token in text:gmatch("%S+") do
            local clean = Trim(token)
            local key = clean:lower()
            if clean ~= "" and not seen[key] then
                seen[key] = true
                parsed[#parsed + 1] = clean
            end
        end
    end

    return parsed
end

function ARL.RaidLayoutBossAssignments.ParseBossSoakAssignmentHints(encounterID, difficulty, bodyText, invitelist)
    local difficultyToken = NormalizeDifficultyToken(difficulty)
    local numericEncounterID = tonumber(encounterID)
    if difficultyToken ~= "mythic" then
        return nil
    end
    if numericEncounterID ~= 3306 and numericEncounterID ~= 3180 and numericEncounterID ~= 3183 then
        return nil
    end

    local inviteLookup = {}
    for _, inviteName in ipairs(invitelist or {}) do
        local clean = Trim(inviteName)
        local fullKey = clean:lower()
        local shortKey = GetShortName(clean):lower()
        if clean ~= "" then
            inviteLookup[fullKey] = clean
            inviteLookup[shortKey] = clean
        end
    end

    local assignments = {}
    local modeAssignments = {}
    local defaultMode = "default"
    local normalizedBody = Trim(bodyText)
    local claimedNames = {}

    local function ClaimCanonicalName(canonicalName)
        local canonicalKey = canonicalName:lower()
        if claimedNames[canonicalKey] then
            return false
        end
        claimedNames[canonicalKey] = true
        return true
    end

    local function BuildOrderedNamesFromSet(nameSet)
        local ordered = {}
        for _, inviteName in ipairs(invitelist or {}) do
            local key = Trim(inviteName):lower()
            if nameSet[key] then
                ordered[#ordered + 1] = inviteName
            end
        end
        return ordered
    end

    local function AddCanonicalNameToSet(nameSet, parsedName)
        local fullKey = parsedName:lower()
        local shortKey = GetShortName(parsedName):lower()
        local canonicalName = inviteLookup[fullKey] or inviteLookup[shortKey]
        if canonicalName then
            nameSet[canonicalName:lower()] = true
        end
    end

    if numericEncounterID == 3306 then
        local laneASet = {}
        local laneBSet = {}

        for line in normalizedBody:gmatch("[^\n]+") do
            local soakLabels, rawNames = line:match("^%s*[Ss][Oo][Aa][Kk]%s+([%d,%s]+)%s*:%s*(.-)%s*$")
            if soakLabels and rawNames then
                local targetsLaneA = false
                local targetsLaneB = false

                for numberText in soakLabels:gmatch("%d+") do
                    local soakNumber = tonumber(numberText)
                    if soakNumber == 2 then
                        targetsLaneB = true
                    elseif soakNumber == 1 or soakNumber == 3 or soakNumber == 4 then
                        targetsLaneA = true
                    end
                end

                for _, parsedName in ipairs(ParseImportNameList(rawNames)) do
                    local fullKey = parsedName:lower()
                    local shortKey = GetShortName(parsedName):lower()
                    local canonicalName = inviteLookup[fullKey] or inviteLookup[shortKey]
                    if canonicalName and ClaimCanonicalName(canonicalName) then
                        local canonicalKey = canonicalName:lower()
                        if targetsLaneA then
                            laneASet[canonicalKey] = true
                        end
                        if targetsLaneB then
                            laneBSet[canonicalKey] = true
                        end
                    end
                end
            end
        end

        local laneA = BuildOrderedNamesFromSet(laneASet)
        local laneB = BuildOrderedNamesFromSet(laneBSet)
        if #laneA > 0 then
            assignments[#assignments + 1] = {
                soakLabel = "soak_1_3_4",
                targetGroups = { 1, 3 },
                names = laneA,
            }
        end
        if #laneB > 0 then
            assignments[#assignments + 1] = {
                soakLabel = "soak_2",
                targetGroups = { 2, 4 },
                names = laneB,
            }
        end
        modeAssignments.default = {
            label = "Alndust Upheaval Soaks",
            assignments = assignments,
        }
    elseif numericEncounterID == 3183 then
        -- Midnight: parse "P3 Sides" section for Left / Right lane assignments.
        local leftSet = {}
        local rightSet = {}
        local inP3Sides = false

        for line in normalizedBody:gmatch("[^\n]+") do
            local trimmedLine = Trim(line)
            if trimmedLine:match("^[Pp]3%s+[Ss]ides%s*$") then
                inP3Sides = true
            elseif inP3Sides then
                local sideLabel, rawNames = trimmedLine:match("^([Ll]eft)%s*:%s*(.-)%s*$")
                if sideLabel and rawNames then
                    for _, parsedName in ipairs(ParseImportNameList(rawNames)) do
                        local fullKey = parsedName:lower()
                        local shortKey = GetShortName(parsedName):lower()
                        local canonicalName = inviteLookup[fullKey] or inviteLookup[shortKey]
                        if canonicalName and ClaimCanonicalName(canonicalName) then
                            leftSet[canonicalName:lower()] = true
                        end
                    end
                else
                    sideLabel, rawNames = trimmedLine:match("^([Rr]ight)%s*:%s*(.-)%s*$")
                    if sideLabel and rawNames then
                        for _, parsedName in ipairs(ParseImportNameList(rawNames)) do
                            local fullKey = parsedName:lower()
                            local shortKey = GetShortName(parsedName):lower()
                            local canonicalName = inviteLookup[fullKey] or inviteLookup[shortKey]
                            if canonicalName and ClaimCanonicalName(canonicalName) then
                                rightSet[canonicalName:lower()] = true
                            end
                        end
                    elseif trimmedLine ~= "" then
                        -- any other non-blank line ends the section
                        inP3Sides = false
                    end
                end
            end
        end

        local leftNames  = BuildOrderedNamesFromSet(leftSet)
        local rightNames = BuildOrderedNamesFromSet(rightSet)
        if #leftNames > 0 then
            assignments[#assignments + 1] = {
                soakLabel    = "side_left",
                targetGroups = { 1, 2 },
                names        = leftNames,
            }
        end
        if #rightNames > 0 then
            assignments[#assignments + 1] = {
                soakLabel    = "side_right",
                targetGroups = { 3, 4 },
                names        = rightNames,
            }
        end
        modeAssignments.default = {
            label = "P3 Sides Left/Right",
            assignments = assignments,
        }
    elseif numericEncounterID == 3180 then
        local executionBySoak = {
            [1] = {},
            [2] = {},
            [3] = {},
            [4] = {},
        }
        local inExecutionSentenceSoaks = false
        local tyrsWrathNamesSet = {}
        local inTyrsWrathSection = false

        for line in normalizedBody:gmatch("[^\n]+") do
            local trimmedLine = Trim(line)

            if trimmedLine:match("^[Ee]xecution%s+[Ss]entence%s+[Ss]oaks%s*$") then
                inExecutionSentenceSoaks = true
                inTyrsWrathSection = false
            elseif inExecutionSentenceSoaks then
                local soakLabel, rawNames = trimmedLine:match("^[Ss][Oo][Aa][Kk]%s+(%d+)%s*:%s*(.-)%s*$")
                local soakNumber = tonumber(soakLabel)
                if soakNumber and executionBySoak[soakNumber] and rawNames then
                    for _, parsedName in ipairs(ParseImportNameList(rawNames)) do
                        AddCanonicalNameToSet(executionBySoak[soakNumber], parsedName)
                    end
                elseif trimmedLine ~= "" then
                    -- Stop once we reach the next section header.
                    inExecutionSentenceSoaks = false
                end
            elseif trimmedLine:match("^[Tt]yr['’]?[Ss]%s+[Ww]rath%s+[Hh]ealing%s+[Aa]bsorbs%s*$") then
                inTyrsWrathSection = true
            elseif inTyrsWrathSection then
                local rawNames = trimmedLine:match("^[Ss]et%s+%d+%s*:%s*(.-)%s*$")
                if rawNames then
                    for _, parsedName in ipairs(ParseImportNameList(rawNames)) do
                        AddCanonicalNameToSet(tyrsWrathNamesSet, parsedName)
                    end
                elseif trimmedLine ~= "" then
                    inTyrsWrathSection = false
                end
            end
        end

        local executionAssignments = {}
        for soakNumber = 1, 4 do
            local names = BuildOrderedNamesFromSet(executionBySoak[soakNumber])
            if #names > 0 then
                executionAssignments[#executionAssignments + 1] = {
                    soakLabel = "soak_" .. tostring(soakNumber),
                    targetGroups = { soakNumber },
                    names = names,
                }
            end
        end

        local tyrsWrathAssignments = {}
        local tyrsWrathNames = BuildOrderedNamesFromSet(tyrsWrathNamesSet)
        local tyrsWrathNameLookup = {}
        for _, playerName in ipairs(tyrsWrathNames) do
            tyrsWrathNameLookup[playerName:lower()] = true
        end
        if #tyrsWrathNames > 0 then
            tyrsWrathAssignments[#tyrsWrathAssignments + 1] = {
                soakLabel = "tyrs_wrath_all",
                targetGroups = { 4 },
                names = tyrsWrathNames,
            }
        end

        for soakNumber = 1, 4 do
            local names = BuildOrderedNamesFromSet(executionBySoak[soakNumber])
            local filteredNames = {}
            for _, playerName in ipairs(names) do
                if not tyrsWrathNameLookup[playerName:lower()] then
                    filteredNames[#filteredNames + 1] = playerName
                end
            end
            if #filteredNames > 0 then
                local targetGroups = { soakNumber }
                if soakNumber == 4 then
                    targetGroups = { 1, 2, 3 }
                end
                tyrsWrathAssignments[#tyrsWrathAssignments + 1] = {
                    soakLabel = "soak_" .. tostring(soakNumber),
                    targetGroups = targetGroups,
                    names = filteredNames,
                }
            end
        end
        modeAssignments.execution_sentence = {
            label = "Execution Sentence Soaks",
            assignments = executionAssignments,
        }
        modeAssignments.tyrs_wrath_group4 = {
            label = "Normal Split + Tyr's Wrath in Group 4",
            assignments = tyrsWrathAssignments,
        }

        assignments = executionAssignments
        defaultMode = "execution_sentence"
    end

    if #assignments == 0 and type(modeAssignments) == "table" then
        for modeKey, modeData in pairs(modeAssignments) do
            if type(modeData) == "table" and type(modeData.assignments) == "table" then
                if #modeData.assignments > 0 then
                    assignments = modeData.assignments
                    if Trim(defaultMode) == "" or not modeAssignments[defaultMode]
                        or #(modeAssignments[defaultMode].assignments or {}) == 0
                    then
                        defaultMode = modeKey
                    end
                    break
                end
            end
        end
    end

    if #assignments == 0 then
        return nil
    end

    return {
        kind = "soak_assignments",
        encounterID = numericEncounterID,
        difficultyToken = difficultyToken,
        defaultMode = defaultMode,
        modes = modeAssignments,
        assignments = assignments,
    }
end

function ARL.RaidLayoutBossAssignments.GetAssignmentsForHints(hints, modeOverrides)
    if type(hints) ~= "table" then
        return {}, nil, nil
    end

    if hints.kind == "chimaerus_soaks" then
        return {
            { targetGroups = { 1, 3 }, names = hints.laneA or {} },
            { targetGroups = { 2, 4 }, names = hints.laneB or {} },
        }, "legacy", "Legacy Chimaerus"
    end

    if hints.kind ~= "soak_assignments" then
        return {}, nil, nil
    end

    local selectedMode = ResolveConfiguredModeForEncounter(
        hints.encounterID,
        hints.difficultyToken or hints.difficulty,
        modeOverrides,
        hints.defaultMode or "default"
    )

    if selectedMode == "disabled" then
        return {}, selectedMode, "Disabled"
    end

    local modeData = type(hints.modes) == "table" and hints.modes[selectedMode] or nil
    local modeLabel = type(modeData) == "table" and Trim(modeData.label) or ""
    if type(modeData) == "table" and type(modeData.assignments) == "table" then
        return modeData.assignments, selectedMode, modeLabel
    end

    if type(hints.assignments) == "table" then
        return hints.assignments, selectedMode, modeLabel
    end

    return {}, selectedMode, modeLabel
end

local function BuildRaidRoleLookupByName()
    local lookup = {}
    local numMembers = tonumber(GetNumGroupMembers and GetNumGroupMembers()) or 0
    for raidIndex = 1, numMembers do
        local unit = "raid" .. raidIndex
        local name, realm = UnitName(unit)
        if name and name ~= "" then
            local fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name
            local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
            local key = Trim(fullName):lower()
            local shortKey = GetShortName(fullName):lower()
            lookup[key] = role
            lookup[shortKey] = role
        end
    end
    return lookup
end

function ARL.RaidLayoutBossAssignments.BuildRaidLayoutGroupsFromHints(rawInvitelist, hints)
    local groups = NewRaidLayoutGroups()
    local invitelist = {}
    local seenNames = {}
    local roleLookup = BuildRaidRoleLookupByName()

    for _, rawName in ipairs(rawInvitelist or {}) do
        local cleanName = Trim(rawName)
        local key = cleanName:lower()
        if cleanName ~= "" and not seenNames[key] then
            seenNames[key] = true
            invitelist[#invitelist + 1] = cleanName
        end
    end

    local assigned = {}

    local function AddToGroup(groupIndex, playerName)
        if not groupIndex or groupIndex < 1 or groupIndex > 8 then
            return false
        end
        if #(groups[groupIndex] or {}) >= 5 then
            return false
        end
        groups[groupIndex][#groups[groupIndex] + 1] = playerName
        assigned[playerName:lower()] = true
        return true
    end

    local function AddToFirstAvailable(preferred)
        for _, groupIndex in ipairs(preferred or {}) do
            if #(groups[groupIndex] or {}) < 5 then
                return groupIndex
            end
        end
        local fallbackOrder = { 5, 6, 7, 8, 1, 2, 3, 4 }
        for _, groupIndex in ipairs(fallbackOrder) do
            if #(groups[groupIndex] or {}) < 5 then
                return groupIndex
            end
        end
        return nil
    end

    local function PickAssignmentTarget(targetGroups, assignmentTankCounts, preferTankSpread)
        if preferTankSpread and type(targetGroups) == "table" and #targetGroups > 0 then
            local bestGroup
            local bestTankCount
            local bestSize
            for _, groupIndex in ipairs(targetGroups) do
                local group = groups[groupIndex] or {}
                local groupSize = #group
                if groupSize < 5 then
                    local tankCount = assignmentTankCounts[groupIndex] or 0
                    if not bestGroup
                        or tankCount < bestTankCount
                        or (tankCount == bestTankCount and groupSize < bestSize)
                    then
                        bestGroup = groupIndex
                        bestTankCount = tankCount
                        bestSize = groupSize
                    end
                end
            end
            if bestGroup then
                return bestGroup
            end
        end

        return AddToFirstAvailable(targetGroups)
    end

    local modeOverrides = type(ARL.db) == "table" and ARL.db.raidGroupAssignmentModes or nil
    local normalizedAssignments = ARL.RaidLayoutBossAssignments.GetAssignmentsForHints(hints, modeOverrides)

    local function PlaceAssignment(names, targetGroups)
        local tanks = {}
        local healers = {}
        local others = {}

        for _, playerName in ipairs(names or {}) do
            local key = playerName:lower()
            if not assigned[key] then
                local role = roleLookup[key] or roleLookup[GetShortName(playerName):lower()] or "NONE"
                if role == "TANK" then
                    tanks[#tanks + 1] = playerName
                elseif role == "HEALER" then
                    healers[#healers + 1] = playerName
                else
                    others[#others + 1] = playerName
                end
            end
        end

        local assignmentTankCounts = {}

        for _, playerName in ipairs(tanks) do
            local target = PickAssignmentTarget(targetGroups, assignmentTankCounts, true)
            if target then
                AddToGroup(target, playerName)
                assignmentTankCounts[target] = (assignmentTankCounts[target] or 0) + 1
            end
        end

        for _, playerName in ipairs(healers) do
            local target = PickAssignmentTarget(targetGroups, assignmentTankCounts, false)
            if target then
                AddToGroup(target, playerName)
            end
        end

        for _, playerName in ipairs(others) do
            local target = PickAssignmentTarget(targetGroups, assignmentTankCounts, false)
            if target then
                AddToGroup(target, playerName)
            end
        end
    end

    for _, assignment in ipairs(normalizedAssignments) do
        local targets = type(assignment.targetGroups) == "table"
            and assignment.targetGroups
            or {}
        PlaceAssignment(assignment.names or {}, targets)
    end

    for _, playerName in ipairs(invitelist) do
        local key = playerName:lower()
        if not assigned[key] then
            local target = AddToFirstAvailable({ 5, 6, 7, 8, 1, 2, 3, 4 })
            if target then
                AddToGroup(target, playerName)
            end
        end
    end

    return groups, invitelist
end