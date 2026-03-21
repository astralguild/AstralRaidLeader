# AstralRaidLeader

A World of Warcraft addon that keeps your raid leader hand-offs consistent.

## Screenshot

![AstralRaidLeader Settings UI](docs/images/settings-ui.png)

In-game settings window for configuring auto-promote, reminder behavior, popup notifications, and preferred leaders.

## Features

- **Preferred-leader list** – maintain an ordered list of characters who should hold Raid Leader.
- **Auto-promote** – whenever a roster update fires and you are the group/raid leader, the addon automatically promotes the highest-priority preferred leader who is currently in the group.
- **Guild rank priority** – define an ordered list of guild ranks; when no preferred leader is present the addon automatically promotes the highest-priority guild rank member in the group instead.
- **Manual-promotion popup** – when auto-promote is off and a preferred leader is present, a configurable popup appears with a one-click **Promote** button. It can reappear after **Not Now** on later roster/instance changes, and defers while in combat.
- **Reminder system** – if no preferred leader is present in the group, an event-driven in-chat reminder fires on member-join/instance-change style triggers.
- **List reordering** – move preferred leaders up or down in priority using slash commands or the **Move Up** / **Move Down** buttons in the settings window; no need to remove and re-add entries.
- **Group-type filter** – restrict auto-promote to raids only, parties only, or all group types. Great for players who run both M+ keys and raids.
- **Consumable audit** – when a ready check is initiated, the addon scans every group member's active buffs and prints a report of who is missing tracked consumable categories (e.g. Flask, Food). Consumable categories are fully configurable via `/arl consumable add`. The audit can be toggled on or off without affecting any other feature.
- **Death recap** – records wipe deaths and displays them in a recap window (`/arl deaths`). In current Midnight-compatible builds, death data is sourced from the built-in `C_DamageMeter` combat session API.
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
| `/arl reminder [on\|off]` | Enable or disable event-driven reminders |
| `/arl notify [on\|off]` | Enable or disable the manual-promote popup when auto-promote is off |
| `/arl notifysound [on\|off]` | Enable or disable sound for the manual-promote popup |
| `/arl quiet [on\|off]` | Suppress all addon chat output (auto-promote still works silently) |
| `/arl grouptype [all\|raid\|party]` | Restrict auto-promote to all groups, raids only, or parties only |
| `/arl consumable list` | List all tracked consumable categories and their spell IDs |
| `/arl consumable add <label> <spellId>` | Add a spell ID to a consumable category (creates the category if needed) |
| `/arl consumable remove <label> <spellId>` | Remove a spell ID from a consumable category |
| `/arl consumable delete <label>` | Delete an entire consumable category |
| `/arl consumable clear` | Remove all tracked consumable categories |
| `/arl consumable audit` | Run the consumable audit immediately |
| `/arl consumableaudit [on\|off]` | Enable or disable the automatic consumable audit on ready check |
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

### Death recap

Use `/arl deaths` to open the last wipe recap window.

The recap records who died and when during a failed encounter attempt. Death source/mechanic data is pulled from the built-in `C_DamageMeter` combat session API when available.

## How it works

1. On every `GROUP_ROSTER_UPDATE` / `RAID_ROSTER_UPDATE` event, if the local player is the group/raid leader, the addon walks the preferred-leaders list from top to bottom.
2. The first name found in the current group is promoted via `PromoteToLeader()`.
3. If no match is found **and** guild rank priority is enabled, the addon walks the guild rank priority list and promotes the first group member whose guild rank matches the highest-priority entry.
4. If still no match is found **and** the reminder is enabled, an event-driven chat reminder can fire on relevant roster/instance triggers.
5. Popup prompts are subject to their own cooldown after **Not Now** and can bypass cooldown on specific high-signal triggers like member joins.
6. When a `READY_CHECK` event fires, the addon scans each group member's active buffs. For every tracked consumable category, it checks whether the member has at least one of the listed spell IDs as an active buff. Anyone missing one or more categories is included in a chat report.

### Setting up consumable tracking

Consumable categories are empty by default. Add them with the spell IDs relevant to your current tier, for example:

```
/arl consumable add Flask 431972
/arl consumable add Flask 432021
/arl consumable add Food  457302
```

You can look up spell IDs on [Wowhead](https://www.wowhead.com) by searching for the buff name and noting the ID in the URL. Run `/arl consumable list` to review what is currently tracked.

## Saved variables

Settings are stored in `AstralRaidLeaderDB` (per-account). The file is located at:
```
WTF/Account/<account>/SavedVariables/AstralRaidLeader.lua
```

## Compatibility

Targets **WoW Retail** (currently tested with Interface 12.0.1). The addon uses only standard group/raid APIs that have been stable for many expansion cycles.