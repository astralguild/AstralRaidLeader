-- AstralRaidLeader.lua
-- Automatically passes Raid Leader to a configurable list of preferred
-- characters. When the player holds Raid Leader, the addon first tries to
-- promote the highest-priority preferred leader that is currently in the
-- group. If none are present, a periodic reminder is shown until one joins
-- or the player leaves the group.

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
    reminderEnabled        = true,  -- show periodic reminders when holding an unwanted lead
    reminderInterval       = 30,    -- seconds between reminder messages
    notifyEnabled          = true,  -- show a popup when manual promotion is available
    notifySound            = true,  -- play a UI sound when the popup is shown
    quietMode              = false, -- suppress all chat output when true
    groupTypeFilter        = "all", -- "all", "raid", or "party"
    consumableAuditEnabled = true,  -- run a consumable audit when a ready check fires
    trackedConsumables     = {},    -- list of { label=string, spellIds={...} } entries
}

-- ============================================================
-- Helpers
-- ============================================================

local function Print(msg)
    if ARL.db and ARL.db.quietMode then return end
    print("|cff00ccff[AstralRaidLeader]|r " .. tostring(msg))
end

-- Initialise (or migrate) the saved-variable database.
local function InitDB()
    if type(AstralRaidLeaderDB) ~= "table" then
        AstralRaidLeaderDB = {}
    end
    for k, v in pairs(DEFAULTS) do
        if AstralRaidLeaderDB[k] == nil then
            -- Deep-copy table defaults so each character's db gets its own table.
            if type(v) == "table" then
                local copy = {}
                for i, item in ipairs(v) do copy[i] = item end
                AstralRaidLeaderDB[k] = copy
            else
                AstralRaidLeaderDB[k] = v
            end
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

-- Try to promote the highest-priority preferred leader found in the group.
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

    return false
end

-- ============================================================
-- Manual promote popup (when auto-promote is disabled)
-- ============================================================

local notifyCooldownSeconds = 20
local lastNotifyAt = 0
local pendingNotifyName = nil
local lastGroupMemberCount = 0

StaticPopupDialogs["ASTRALRAIDLEADER_MANUAL_PROMOTE"] = {
    text = "A preferred leader is in your group: %s\n\nPromote now?",
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
    if #self.db.preferredLeaders == 0 then return end
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

local function EvaluateLeaderState(trigger)
    if not ARL.db then return end
    if #ARL.db.preferredLeaders == 0 then
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
        if not ok then StartReminder() end
        return
    end

    StartReminder()
    local preferredName = GetTopAvailablePreferredLeader()
    if not preferredName then
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
local function HasBuff(unit, spellId)
    local i = 1
    while i <= 64 do
        local buffName, _, _, _, _, _, _, _, _, buffSpellId = UnitBuff(unit, i)
        if not buffName then break end
        if buffSpellId == spellId then return true end
        i = i + 1
    end
    return false
end

-- Return the index and table of the consumable category matching label, or nil, nil.
local function FindConsumableCategory(label)
    local lower = label:lower()
    for i, cat in ipairs(ARL.db.trackedConsumables) do
        if cat.label:lower() == lower then
            return i, cat
        end
    end
    return nil, nil
end

-- Scan all group members for missing tracked consumable buffs and print a report.
local function RunConsumableAudit()
    if not ARL.db or not ARL.db.consumableAuditEnabled then return end
    if #ARL.db.trackedConsumables == 0 then return end
    if not IsInRelevantGroup() then return end

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

    local missing = {}
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local name = UnitName(unit)
            if name and name ~= "" then
                local missingCats = {}
                for _, consumable in ipairs(ARL.db.trackedConsumables) do
                    local hasIt = false
                    for _, spellId in ipairs(consumable.spellIds) do
                        if HasBuff(unit, spellId) then
                            hasIt = true
                            break
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

-- ============================================================
-- Reminder timer
-- ============================================================

local reminderFrame   = CreateFrame("Frame")
local reminderActive  = false
local reminderElapsed = 0

function ARL:CancelReminder()
    reminderActive  = false
    reminderElapsed = 0
end

StartReminder = function()
    if not ARL.db or not ARL.db.reminderEnabled then return end
    if #ARL.db.preferredLeaders == 0 then return end
    reminderActive  = true
    reminderElapsed = 0
end

reminderFrame:SetScript("OnUpdate", function(_, elapsed)
    if not reminderActive then return end

    reminderElapsed = reminderElapsed + elapsed
    if reminderElapsed < ARL.db.reminderInterval then return end
    reminderElapsed = 0

    -- Stop reminding if we are no longer the group leader.
    if not UnitIsGroupLeader("player") or not IsInRelevantGroup() then
        ARL:CancelReminder()
        ARL:HideManualPromotePopup()
        return
    end

    -- Try to auto-promote before showing the reminder.
    if ARL.db.autoPromote and TryAutoPromote() then
        return
    end

    if not ARL.db.autoPromote then
        local preferredName = GetTopAvailablePreferredLeader()
        if preferredName then
            ARL:ShowManualPromotePopup(preferredName, false)
        end
    end

    -- Build a friendly list of preferred names.
    local names = table.concat(ARL.db.preferredLeaders, ", ")
    Print(string.format(
        "Reminder: You are the Raid Leader. Preferred leader(s): |cffffd100%s|r. "
        .. "Use |cffffff00/arl promote|r to hand off when they join.",
        names
    ))
end)

-- ============================================================
-- Event handling
-- ============================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("READY_CHECK")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        InitDB()
        lastGroupMemberCount = GetNumGroupMembers()
        Print("Loaded. Type |cffffff00/arl help|r for commands.")

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- db may already be set from PLAYER_LOGIN; guard against double-init.
        if not ARL.db then InitDB() end
        lastGroupMemberCount = GetNumGroupMembers()
        EvaluateLeaderState("instance_change")

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        EvaluateLeaderState("instance_change")

    elseif event == "PLAYER_REGEN_ENABLED" then
        ARL:TryShowPendingManualPromotePopup()

    elseif event == "READY_CHECK" then
        RunConsumableAudit()

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

    -- /arl reminder [on|off|<seconds>]
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
            local secs = tonumber(arg)
            if secs and secs >= 5 then
                ARL.db.reminderInterval = secs
                Print(string.format("Reminder interval set to |cffffff00%d|r seconds.", secs))
            else
                Print("Interval must be a number >= 5. Usage: /arl reminder <seconds>")
            end
        else
            Print(string.format(
                "Reminder is |cff%s%s|r. Interval: |cffffff00%d|r seconds.",
                ARL.db.reminderEnabled and "00ff00" or "ff0000",
                ARL.db.reminderEnabled and "enabled" or "disabled",
                ARL.db.reminderInterval
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
                    Print(string.format("  %d. |cffffd100%s|r – spell IDs: %s",
                        i, cat.label, table.concat(cat.spellIds, ", ")))
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
            RunConsumableAudit()

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

    -- /arl settings | /arl options | /arl config
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        if ARL.ShowOptions then
            ARL:ShowOptions()
        else
            Print("Settings UI is not available yet. Try again in a moment.")
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
        Print("  |cffffff00/arl reminder [on|off|N]|r – Toggle or set the reminder interval (seconds)")
        Print("  |cffffff00/arl notify [on|off]|r    – Toggle the manual-promote popup when auto is off")
        Print("  |cffffff00/arl notifysound [on|off]|r – Toggle sound for the manual-promote popup")
        Print("  |cffffff00/arl quiet [on|off]|r     – Suppress all chat output from this addon")
        Print("  |cffffff00/arl grouptype [all|raid|party]|r – Restrict auto-promote to a group type")
        Print("  |cffffff00/arl consumable ...|r     – Manage tracked consumable categories (run for sub-commands)")
        Print("  |cffffff00/arl consumableaudit [on|off]|r – Toggle consumable audit on ready check")
        Print("  |cffffff00/arl settings|r           – Open the in-game settings window")
        Print("  |cffffff00/arl help|r               – Show this help message")

    else
        Print(string.format("Unknown command: |cffffff00%s|r. Type /arl help for a list of commands.", cmd))
    end
end
