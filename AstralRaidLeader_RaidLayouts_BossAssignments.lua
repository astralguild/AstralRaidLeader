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
    if numericEncounterID ~= 3306 and numericEncounterID ~= 3180 then
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
    elseif numericEncounterID == 3180 then
        local bySoak = {
            [1] = {},
            [2] = {},
            [3] = {},
            [4] = {},
        }

        for line in normalizedBody:gmatch("[^\n]+") do
            local soakLabel, rawNames = line:match("^%s*[Ss][Oo][Aa][Kk]%s+(%d+)%s*:%s*(.-)%s*$")
            local soakNumber = tonumber(soakLabel)
            if soakNumber and bySoak[soakNumber] and rawNames then
                for _, parsedName in ipairs(ParseImportNameList(rawNames)) do
                    local fullKey = parsedName:lower()
                    local shortKey = GetShortName(parsedName):lower()
                    local canonicalName = inviteLookup[fullKey] or inviteLookup[shortKey]
                    if canonicalName and ClaimCanonicalName(canonicalName) then
                        bySoak[soakNumber][canonicalName:lower()] = true
                    end
                end
            end
        end

        for soakNumber = 1, 4 do
            local names = BuildOrderedNamesFromSet(bySoak[soakNumber])
            if #names > 0 then
                assignments[#assignments + 1] = {
                    soakLabel = "soak_" .. tostring(soakNumber),
                    targetGroups = { soakNumber },
                    names = names,
                }
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
        assignments = assignments,
    }
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

    local normalizedAssignments = {}
    if type(hints) == "table" and hints.kind == "soak_assignments" then
        normalizedAssignments = hints.assignments or {}
    elseif type(hints) == "table" and hints.kind == "chimaerus_soaks" then
        normalizedAssignments = {
            { targetGroups = { 1, 3 }, names = hints.laneA or {} },
            { targetGroups = { 2, 4 }, names = hints.laneB or {} },
        }
    end

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

        local ordered = {}
        for _, name in ipairs(tanks) do
            ordered[#ordered + 1] = name
        end
        for _, name in ipairs(healers) do
            ordered[#ordered + 1] = name
        end
        for _, name in ipairs(others) do
            ordered[#ordered + 1] = name
        end

        for _, playerName in ipairs(ordered) do
            local target = AddToFirstAvailable(targetGroups)
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