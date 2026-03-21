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
    preferredLeaders  = {},   -- ordered list of character names (highest priority first)
    autoPromote       = true, -- attempt to promote automatically on roster changes
    reminderEnabled   = true, -- show periodic reminders when holding an unwanted lead
    reminderInterval  = 30,   -- seconds between reminder messages
}

-- ============================================================
-- Helpers
-- ============================================================

local function Print(msg)
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
    local n = GetNumGroupMembers()
    if n == 0 then return members end

    for i = 1, n do
        local name = GetRaidRosterInfo(i)
        if name then
            -- Strip the realm suffix (e.g. "Thrall-Silvermoon" -> "Thrall")
            local shortName = name:match("^([^%-]+)") or name
            members[shortName:lower()] = name
            members[name:lower()]      = name
        end
    end
    return members
end

-- ============================================================
-- Auto-promote logic
-- ============================================================

-- Try to promote the highest-priority preferred leader found in the group.
-- Returns true if a promotion was issued, false otherwise.
local function TryAutoPromote()
    if not UnitIsGroupLeader("player") then return false end
    if not (IsInRaid() or IsInGroup()) then return false end

    local memberMap = GetGroupMemberMap()

    for _, leaderName in ipairs(ARL.db.preferredLeaders) do
        local target = memberMap[leaderName:lower()]
        if target then
            PromoteToLeader(target)
            Print(string.format("Promoted |cffffd100%s|r to Raid Leader.", leaderName))
            ARL:CancelReminder()
            return true
        end
    end
    return false
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

local function StartReminder()
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
    if not UnitIsGroupLeader("player") or not (IsInRaid() or IsInGroup()) then
        ARL:CancelReminder()
        return
    end

    -- Try to auto-promote before showing the reminder.
    if ARL.db.autoPromote and TryAutoPromote() then
        return
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

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        InitDB()
        Print("Loaded. Type |cffffff00/arl help|r for commands.")

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- db may already be set from PLAYER_LOGIN; guard against double-init.
        if not ARL.db then InitDB() end

    elseif event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" then
        if not ARL.db then return end
        if #ARL.db.preferredLeaders == 0 then return end

        if UnitIsGroupLeader("player") and (IsInRaid() or IsInGroup()) then
            if ARL.db.autoPromote then
                local ok = TryAutoPromote()
                if not ok then StartReminder() end
            else
                StartReminder()
            end
        else
            ARL:CancelReminder()
        end
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

    -- /arl help  (or bare /arl)
    elseif cmd == "help" or cmd == "" then
        Print("Available commands:")
        Print("  |cffffff00/arl add <name>|r        – Add a character to the preferred leaders list")
        Print("  |cffffff00/arl remove <name>|r     – Remove a character from the list")
        Print("  |cffffff00/arl list|r               – Show the preferred leaders list")
        Print("  |cffffff00/arl clear|r              – Clear the entire list")
        Print("  |cffffff00/arl promote|r            – Manually promote the top available preferred leader")
        Print("  |cffffff00/arl auto [on|off]|r      – Toggle automatic promotion on roster changes")
        Print("  |cffffff00/arl reminder [on|off|N]|r – Toggle or set the reminder interval (seconds)")
        Print("  |cffffff00/arl help|r               – Show this help message")

    else
        Print(string.format("Unknown command: |cffffff00%s|r. Type /arl help for a list of commands.", cmd))
    end
end
