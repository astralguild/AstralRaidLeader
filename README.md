# AstralRaidLeader

A World of Warcraft addon that keeps your raid leader hand-offs consistent.

## Screenshot

![AstralRaidLeader Settings UI](docs/images/settings-ui.png)

In-game settings window for configuring auto-promote, reminder behavior, popup notifications, and preferred leaders.

## Features

- **Preferred-leader list** – maintain an ordered list of characters who should hold Raid Leader.
- **Auto-promote** – whenever a roster update fires and you are the group/raid leader, the addon automatically promotes the highest-priority preferred leader who is currently in the group.
- **Guild rank priority** – define an ordered list of guild ranks; when no preferred leader is present the addon automatically promotes the highest-priority guild rank member in the group instead.
- **Manual-promotion popup** – when auto-promote is off and a preferred leader is present, a configurable popup appears with a one-click **Promote** button. It can reappear after **Not Now** on later roster/instance changes (or periodic reminders), and defers while in combat.
- **Reminder system** – if no preferred leader is present in the group, a periodic in-chat reminder fires until one joins (or you hand off leadership manually).
- **List reordering** – move preferred leaders up or down in priority using slash commands or the **Move Up** / **Move Down** buttons in the settings window; no need to remove and re-add entries.
- **Group-type filter** – restrict auto-promote to raids only, parties only, or all group types. Great for players who run both M+ keys and raids.
- **Quiet mode** – suppress all addon chat output so auto-promotion happens silently in the background.
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
| `/arl move <name> <pos>` | Move a character to a specific position in the list |
| `/arl list` | Show the preferred leaders list (highest priority first) |
| `/arl clear` | Clear the entire list |
| `/arl promote` | Manually promote the highest-priority preferred leader currently in the group |
| `/arl auto [on\|off]` | Enable or disable automatic promotion on roster changes |
| `/arl reminder [on\|off\|N]` | Enable/disable reminders, or set the interval in seconds (minimum 5 s) |
| `/arl notify [on\|off]` | Enable or disable the manual-promote popup when auto-promote is off |
| `/arl notifysound [on\|off]` | Enable or disable sound for the manual-promote popup |
| `/arl quiet [on\|off]` | Suppress all addon chat output (auto-promote still works silently) |
| `/arl grouptype [all\|raid\|party]` | Restrict auto-promote to all groups, raids only, or parties only |
| `/arl rankpriority [on\|off]` | Enable or disable guild rank priority fallback |
| `/arl addrank <rank>` | Add a guild rank to the rank priority list |
| `/arl removerank <rank>` | Remove a guild rank from the rank priority list |
| `/arl ranklist` | Show the guild rank priority list (highest priority first) |
| `/arl clearranks` | Clear the entire guild rank priority list |
| `/arl moverank <rank> <pos>` | Move a guild rank to a specific position in the list |
| `/arl settings` | Open the in-game settings window |
| `/arl help` | Show all available commands |

### Quick-start example

```
/arl add Thrall
/arl add Jaina
/arl list
```

The addon will now automatically pass Raid Leader to **Thrall** whenever he joins your group while you are the leader. If Thrall is absent, it will try **Jaina** next. If neither is present, a reminder is printed every 30 seconds (configurable).

### Guild rank priority quick-start

```
/arl rankpriority on
/arl addrank Officer
/arl addrank Raider
/arl ranklist
```

If no character from the preferred leaders list is in the group, the addon will now automatically promote the first **Officer** it finds; if no Officers are present it will try **Raiders**. This fallback integrates seamlessly with auto-promote and the manual-promote popup.

## How it works

1. On every `GROUP_ROSTER_UPDATE` / `RAID_ROSTER_UPDATE` event, if the local player is the group/raid leader, the addon walks the preferred-leaders list from top to bottom.
2. The first name found in the current group is promoted via `PromoteToLeader()`.
3. If no match is found **and** guild rank priority is enabled, the addon walks the guild rank priority list and promotes the first group member whose guild rank matches the highest-priority entry.
4. If still no match is found **and** the reminder is enabled, a timer fires every `reminderInterval` seconds with a chat message listing the preferred leaders and/or configured guild ranks.
5. The reminder is automatically cancelled when the player is no longer the group leader.

## Saved variables

Settings are stored in `AstralRaidLeaderDB` (per-account). The file is located at:
```
WTF/Account/<account>/SavedVariables/AstralRaidLeader.lua
```

## Compatibility

Targets **WoW Retail** (currently tested with Interface 12.0.1). The addon uses only standard group/raid APIs that have been stable for many expansion cycles.