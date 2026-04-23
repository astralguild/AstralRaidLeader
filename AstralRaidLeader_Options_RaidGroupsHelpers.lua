-- AstralRaidLeader_Options_RaidGroupsHelpers.lua
-- Shared helpers for raid-group editor role-aware assignment and boss-specific grouping.

local ARL = _G["AstralRaidLeader"]
if not ARL then return end

local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local GetPartyAssignment = _G.GetPartyAssignment
local GetInspectSpecialization = _G.GetInspectSpecialization
local GetSpecialization = _G.GetSpecialization
local GetSpecializationInfo = _G.GetSpecializationInfo
local GetSpecializationInfoByID = _G.GetSpecializationInfoByID
local UnitClass = _G.UnitClass
local UnitName = _G.UnitName
local GetNumGroupMembers = _G.GetNumGroupMembers

ARL.OptionsRaidGroupsHelpers = ARL.OptionsRaidGroupsHelpers or {}

local RANGED_SPEC_IDS = {
    [62] = true, [63] = true, [64] = true,
    [102] = true,
    [258] = true,
    [262] = true,
    [253] = true, [254] = true,
    [1467] = true, [1473] = true,
    [265] = true, [266] = true, [267] = true,
}

local MELEE_SPEC_IDS = {
    [70] = true,
    [71] = true, [72] = true,
    [251] = true, [252] = true,
    [577] = true,
    [103] = true,
    [255] = true,
    [268] = true, [269] = true,
    [263] = true,
    [259] = true, [260] = true, [261] = true,
}

local RANGED_ONLY_CLASSES = {
    MAGE = true,
    PRIEST = true,
    WARLOCK = true,
    EVOKER = true,
}

local MELEE_ONLY_CLASSES = {
    WARRIOR = true,
    DEATHKNIGHT = true,
    ROGUE = true,
    DEMONHUNTER = true,
}

function ARL.OptionsRaidGroupsHelpers.ResolveUnitRole(unit)
    if GetPartyAssignment and GetPartyAssignment("MAINTANK", unit) then
        return "TANK"
    end

    local assigned = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
    if assigned ~= "NONE" then
        return assigned
    end

    if unit == "player" and GetSpecialization and GetSpecializationInfo then
        local specIndex = GetSpecialization()
        if specIndex and specIndex > 0 then
            local _, _, _, _, role = GetSpecializationInfo(specIndex)
            if role and role ~= "" then
                return role
            end
        end
    end

    local specID = GetInspectSpecialization and GetInspectSpecialization(unit)
    if specID and specID > 0 and GetSpecializationInfoByID then
        local _, _, _, _, role = GetSpecializationInfoByID(specID)
        if role and role ~= "" then
            return role
        end
    end

    return "NONE"
end

local function ResolveUnitCombatType(unit, classToken, role)
    if role == "TANK" or role == "HEALER" then
        return nil
    end

    local specID = GetInspectSpecialization and GetInspectSpecialization(unit)
    if unit == "player" and GetSpecialization and GetSpecializationInfo then
        local specIndex = GetSpecialization()
        if specIndex and specIndex > 0 then
            local specInfoID = select(1, GetSpecializationInfo(specIndex))
            if specInfoID and specInfoID > 0 then
                specID = specInfoID
            end
        end
    end

    if specID and specID > 0 then
        if RANGED_SPEC_IDS[specID] then
            return "ranged"
        end
        if MELEE_SPEC_IDS[specID] then
            return "melee"
        end
    end

    if classToken and RANGED_ONLY_CLASSES[classToken] then
        return "ranged"
    end
    if classToken and MELEE_ONLY_CLASSES[classToken] then
        return "melee"
    end

    if classToken == "HUNTER" or classToken == "DRUID" or classToken == "SHAMAN" then
        return "ranged"
    end

    if classToken == "PALADIN" or classToken == "MONK" then
        return "melee"
    end

    return nil
end

function ARL.OptionsRaidGroupsHelpers.BuildRaidRosterRoleLookup(normalize, shortName)
    local lookup = {}
    local numMembers = GetNumGroupMembers and GetNumGroupMembers() or 0
    for raidIndex = 1, numMembers do
        local unit = "raid" .. raidIndex
        local name, realm = UnitName(unit)
        if name then
            local fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name
            local _, classToken = UnitClass(unit)
            local role = ARL.OptionsRaidGroupsHelpers.ResolveUnitRole(unit)
            local info = {
                classToken = classToken,
                role = role,
                combatType = ResolveUnitCombatType(unit, classToken, role),
            }
            lookup[normalize(fullName):lower()] = info
            lookup[normalize(name):lower()] = info
            lookup[shortName(fullName):lower()] = info
        end
    end
    return lookup
end

function ARL.OptionsRaidGroupsHelpers.TryApplyBossSoakAssignmentsToEditor(args)
    args = type(args) == "table" and args or {}

    local raidEditorState = args.raidEditorState
    local orderedNames = args.orderedNames or {}
    local rosterLookup = args.rosterLookup or {}
    local fallbackOrder = args.fallbackOrder or { 5, 6, 7, 8, 1, 2, 3, 4 }
    local normalize = args.Normalize
    local shortName = args.ShortName
    local isAssignmentHintsApplicable = args.IsAssignmentHintsApplicable
    local setEditorTargetGroup = args.SetEditorTargetGroup
    local clearDrag = args.ClearDrag

    if type(raidEditorState) ~= "table"
        or type(normalize) ~= "function"
        or type(shortName) ~= "function"
        or type(isAssignmentHintsApplicable) ~= "function"
    then
        return false
    end

    local hints = raidEditorState.assignmentHints
    if not isAssignmentHintsApplicable(hints, raidEditorState.encounterID, raidEditorState.difficulty) then
        return false
    end

    local assignments
    if hints.kind == "soak_assignments" and type(hints.assignments) == "table" then
        assignments = hints.assignments
    elseif hints.kind == "chimaerus_soaks" then
        assignments = {
            { targetGroups = { 1, 3 }, names = hints.laneA or {} },
            { targetGroups = { 2, 4 }, names = hints.laneB or {} },
        }
    else
        return false
    end

    local prepared = {}
    for _, assignment in ipairs(assignments) do
        local nameSet = {}
        for _, playerName in ipairs(assignment.names or {}) do
            local clean = normalize(playerName)
            if clean ~= "" then
                nameSet[clean:lower()] = true
                nameSet[shortName(clean):lower()] = true
            end
        end
        prepared[#prepared + 1] = {
            targetGroups = type(assignment.targetGroups) == "table"
                and assignment.targetGroups
                or {},
            nameSet = nameSet,
            names = {},
        }
    end

    local matchedCount = 0
    local remaining = {}
    local seen = {}

    for _, playerName in ipairs(orderedNames) do
        local clean = normalize(playerName)
        local fullKey = clean:lower()
        local shortKey = shortName(clean):lower()
        if clean ~= "" and not seen[fullKey] then
            seen[fullKey] = true
            local assignedToHint = false
            for _, assignment in ipairs(prepared) do
                if assignment.nameSet[fullKey] or assignment.nameSet[shortKey] then
                    assignment.names[#assignment.names + 1] = playerName
                    matchedCount = matchedCount + 1
                    assignedToHint = true
                    break
                end
            end
            if not assignedToHint then
                remaining[#remaining + 1] = playerName
            end
        end
    end

    if matchedCount == 0 then
        return false
    end

    for groupIndex = 1, 8 do
        raidEditorState.groups[groupIndex] = {}
    end

    local function AddToGroup(groupIndex, playerName)
        raidEditorState.groups[groupIndex][#raidEditorState.groups[groupIndex] + 1] = playerName
    end

    local function PickFirstOpen(groupOrder)
        for _, groupIndex in ipairs(groupOrder or {}) do
            if #(raidEditorState.groups[groupIndex] or {}) < 5 then
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
                local group = raidEditorState.groups[groupIndex] or {}
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

        return PickFirstOpen(targetGroups) or PickFirstOpen(fallbackOrder)
    end

    local function PlaceAssignment(names, targetGroups)
        local tanksLane = {}
        local healersLane = {}
        local dpsLane = {}

        for _, playerName in ipairs(names or {}) do
            local cleanName = normalize(playerName)
            local lowerName = cleanName:lower()
            local shortLower = shortName(cleanName):lower()
            local info = rosterLookup[lowerName] or rosterLookup[shortLower]
            local role = info and info.role or "NONE"
            if role == "TANK" then
                tanksLane[#tanksLane + 1] = playerName
            elseif role == "HEALER" then
                healersLane[#healersLane + 1] = playerName
            else
                dpsLane[#dpsLane + 1] = playerName
            end
        end

        local assignmentTankCounts = {}

        for _, playerName in ipairs(tanksLane) do
            local target = PickAssignmentTarget(targetGroups, assignmentTankCounts, true)
            if target then
                AddToGroup(target, playerName)
                assignmentTankCounts[target] = (assignmentTankCounts[target] or 0) + 1
            end
        end

        for _, playerName in ipairs(healersLane) do
            local target = PickAssignmentTarget(targetGroups, assignmentTankCounts, false)
            if target then
                AddToGroup(target, playerName)
            end
        end

        for _, playerName in ipairs(dpsLane) do
            local target = PickAssignmentTarget(targetGroups, assignmentTankCounts, false)
            if target then
                AddToGroup(target, playerName)
            end
        end
    end

    for _, assignment in ipairs(prepared) do
        PlaceAssignment(assignment.names, assignment.targetGroups)
    end

    for _, playerName in ipairs(remaining) do
        local target = PickFirstOpen(fallbackOrder)
        if target then
            AddToGroup(target, playerName)
        end
    end

    if type(clearDrag) == "function" then
        clearDrag()
    end
    if type(setEditorTargetGroup) == "function" then
        setEditorTargetGroup(1)
    end
    return true
end