# AstralRaidLeader

A World of Warcraft addon that keeps your raid leader hand-offs consistent.

## Features

- **Preferred-leader list** – maintain an ordered list of characters who should hold Raid Leader.
- **Auto-promote** – whenever a roster update fires and you are the group/raid leader, the addon automatically promotes the highest-priority preferred leader who is currently in the group.
- **Manual-promotion popup** – when auto-promote is off and a preferred leader is present, a configurable popup appears with a one-click **Promote** button. It can reappear after **Not Now** on later roster/instance changes (or periodic reminders), and defers while in combat.
- **Reminder system** – if no preferred leader is present in the group, a periodic in-chat reminder fires until one joins (or you hand off leadership manually).
- **Persistent settings** – your list and preferences are saved between sessions via `SavedVariables`.

## Installation

1. Download the latest release.
2. Extract the `AstralRaidLeader` folder into your WoW addons directory:
   ```
   World of Warcraft/_retail_/Interface/AddOns/AstralRaidLeader/
   ```
3. Restart WoW (or reload your UI with `/reload`).
4. The addon is enabled by default for all characters.

## Usage

All commands use the `/arl` (or `/astralraidleader`) prefix.

| Command | Description |
|---|---|
| `/arl add <name>` | Add a character to the preferred leaders list |
| `/arl` | Open the in-game settings window |
| `/arl remove <name>` | Remove a character from the list |
| `/arl list` | Show the preferred leaders list (highest priority first) |
| `/arl clear` | Clear the entire list |
| `/arl promote` | Manually promote the highest-priority preferred leader currently in the group |
| `/arl auto [on\|off]` | Enable or disable automatic promotion on roster changes |
| `/arl reminder [on\|off\|N]` | Enable/disable reminders, or set the interval in seconds (minimum 5 s) |
| `/arl notify [on\|off]` | Enable or disable the manual-promote popup when auto-promote is off |
| `/arl notifysound [on\|off]` | Enable or disable sound for the manual-promote popup |
| `/arl settings` | Open the in-game settings window |
| `/arl help` | Show all available commands |

### Quick-start example

```
/arl add Thrall
/arl add Jaina
/arl list
```

The addon will now automatically pass Raid Leader to **Thrall** whenever he joins your group while you are the leader. If Thrall is absent, it will try **Jaina** next. If neither is present, a reminder is printed every 30 seconds (configurable).

## How it works

1. On every `GROUP_ROSTER_UPDATE` / `RAID_ROSTER_UPDATE` event, if the local player is the group/raid leader, the addon walks the preferred-leaders list from top to bottom.
2. The first name found in the current group is promoted via `PromoteToLeader()`.
3. If no match is found **and** the reminder is enabled, a timer fires every `reminderInterval` seconds with a chat message listing the preferred leaders.
4. The reminder is automatically cancelled when the player is no longer the group leader.

## Saved variables

Settings are stored in `AstralRaidLeaderDB` (per-account). The file is located at:
```
WTF/Account/<account>/SavedVariables/AstralRaidLeader.lua
```

## Compatibility

Targets **WoW Retail** (currently tested with Interface 12.0.1). The addon uses only standard group/raid APIs that have been stable for many expansion cycles.