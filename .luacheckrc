std = "lua51"
max_line_length = 120

read_globals = {
    -- WoW UI framework
    "BackdropTemplateMixin",
    "CreateFrame",
    "UIParent",
    "UISpecialFrames",

    -- Group and unit APIs
    "GetNumGroupMembers",
    "GetNumSubgroupMembers",
    "IsInGroup",
    "IsInRaid",
    "UnitExists",
    "UnitIsGroupLeader",
    "UnitName",

    -- Guild APIs
    "C_GuildInfo",
    "GetGuildRosterInfo",
    "GetNumGuildMembers",
    "GuildControlGetNumRanks",
    "GuildControlGetRankName",
    "IsInGuild",

    -- Aura and combat APIs
    "C_DamageMeter",
    "C_UnitAuras",
    "InCombatLockdown",
    "PromoteToLeader",

    -- Time and utility
    "GetTime",
    "date",

    -- Sound
    "PlaySound",
    "SOUNDKIT",

    -- StaticPopup system (read-only pieces)
    "STATICPOPUP_NUMDIALOGS",
    "StaticPopup_Hide",
    "StaticPopup_Show",
    "StaticPopup_Visible",
}

globals = {
    -- Addon saved variables and slash command globals
    "AstralRaidLeaderDB",
    "SLASH_ASTRALRAIDLEADER1",
    "SLASH_ASTRALRAIDLEADER2",

    -- WoW mutable global tables used by addons
    "SlashCmdList",
    "StaticPopupDialogs",
}