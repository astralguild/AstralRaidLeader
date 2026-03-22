# AstralRaidLeader – GitHub Copilot Instructions

## Project Overview

AstralRaidLeader is a **World of Warcraft (Retail) addon** written in Lua. It manages automatic raid leader hand-offs, consumable audits, guild rank priority, and death recaps. Target interface version: `120001` (Midnight).

### File Layout

| File | Purpose |
|---|---|
| `AstralRaidLeader.lua` | Core logic: event handling, auto-promote, guild rank resolution, consumable audit, death tracking, slash commands |
| `AstralRaidLeader_Options.lua` | In-game settings window (760×500 custom frame) |
| `AstralRaidLeader_Deaths.lua` | Death recap window (520×430 custom frame) |
| `AstralRaidLeader.toc` | Addon manifest; load order is `.lua` → `_Options.lua` → `_Deaths.lua` |

The addon namespace is exposed as `_G["AstralRaidLeader"]` and referenced as `ARL` in every file.

---

## WoW API Constraints (Retail / Midnight)

### Frame Templates
- **Custom shell pattern** — both windows use `BackdropTemplateMixin` instead of `BasicFrameTemplateWithInset`. Always guard with:
  ```lua
  CreateFrame("Frame", name, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  ```
- **`SetBackdrop` must be guarded** — only call it when the method exists:
  ```lua
  if frame.SetBackdrop then frame:SetBackdrop({...}) end
  ```
- **`SetNormalTexture(nil)` crashes** — never call it. Use `btn:GetNormalTexture():SetAlpha(0)` instead.

### Texture / Backdrop conventions
- Background: `"Interface\\Buttons\\WHITE8x8"` for both `bgFile` and `edgeFile`.
- Edge size: `1` (thin 1 px border).
- Main frame background: `SetBackdropColor(0.03, 0.05, 0.08, 0.985)`.
- Main frame border: `SetBackdropBorderColor(0.34, 0.42, 0.54, 0.96)`.
- Header fill: `SetBackdropColor(0.05, 0.09, 0.15, 0.88)`.
- Header divider: `SetColorTexture(0.44, 0.54, 0.68, 0.70)`, height 1.

### Text / FontString layering
- **Title text must be a child of the `header` frame**, not the root `frame`. The `header` has `SetFrameLevel(frame:GetFrameLevel() + 8)`, which ensures it renders above any content panel backdrops.
- Use `header:CreateFontString(nil, "OVERLAY", ...)` — not `"ARTWORK"` — for text meant to appear on top of backdrop fills.
- Content text inside a skinned panel must be either a child of that panel at `"OVERLAY"` layer, or placed after (`SetFrameLevel` high enough).

### Scrollbar
- `UIPanelScrollFrameTemplate` places its scrollbar at `+24px` right of the scroll frame. To keep it inside a panel:
  1. Set the scroll frame's right edge to `-30` from the panel's right edge.
  2. After creation, reanchor `_G[frameName .. "ScrollBar"]` explicitly:
     ```lua
     local _sb = _G["MyScrollFrameScrollBar"]
     if _sb then
         _sb:ClearAllPoints()
         _sb:SetPoint("TOPRIGHT",    panel, "TOPRIGHT",    -4, -topOffset)
         _sb:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, bottomOffset)
     end
     ```

### Button skinning (`SkinActionButton`)
- Hide all template textures via `:SetAlpha(0)` on every texture region and the named Left/Middle/Right regions.
- Create a `BackdropTemplate` child frame (`skin`) anchored to all four corners, set to `frameLevel - 1`, with `EnableMouse(false)`.
- Hook `OnEnter`, `OnLeave`, `OnEnable`, `OnDisable`, `OnShow` to update the skin backdrop colors for idle/hover/disabled states.
- Set font string color explicitly: `btn:GetFontString():SetTextColor(0.90, 0.92, 0.96)`.

### CheckButton
- `cb.Text` is the label `FontString` for `InterfaceOptionsCheckButtonTemplate` buttons.
- Set color via `cb.Text:SetTextColor(...)`.

### Tab buttons
- Tab labels are stored as `tab.Label` (custom font string, not `tab.Text`).
- Use the `SetTabLabelColor` helper pattern that checks both `.Text` and `.Label`.

---

## UI Architecture

### Options Window (`AstralRaidLeader_Options.lua`)

```
frame (760×500, DIALOG strata, level 100)
├── header (TOPLEFT 7,-7 → TOPRIGHT -30,-7, height 28, level+8)
│   ├── headerDivider (bottom edge texture)
│   └── titleText (OVERLAY FontString, centered)
├── topCloseButton (UIPanelCloseButton, TOPRIGHT)
├── dragRegion (TOPLEFT 8,-6 → TOPRIGHT -28,-6, height 22)
├── navContainer (TOPLEFT 8,-58 → BOTTOMRIGHT -8,44)
│   ├── subTabSidebar (width 165, left-aligned)
│   │   └── subTabButtons[1..6]
│   └── contentHost (right of sidebar)
│       └── panels[1..5] (one visible at a time)
└── closeButton (BOTTOMRIGHT -12,12)
```

**Panel assignments:**
- `panels[1]` – General (auto-promote toggles, group type filter)
- `panels[2]` – Leaders (preferred leaders list)
- `panels[3]` – Guild Ranks
- `panels[4]` – Consumables
- `panels[5]` – Deaths settings

**Main tab → sub-tabs mapping** is defined in `MAIN_TABS` and drives `SelectMainTab` / `SelectSubTab`.

### Death Recap Window (`AstralRaidLeader_Deaths.lua`)

```
frame (520×430, DIALOG strata, level 110)
├── header (same pattern as Options)
├── topCloseButton
├── dragRegion
├── contentPanel (TOPLEFT 8,-40 → BOTTOMRIGHT -8,44)
│   ├── subtitleText (OVERLAY, child of contentPanel)
│   ├── summaryText  (OVERLAY, child of contentPanel)
│   ├── scrollFrame  (TOPLEFT 10,-56 → BOTTOMRIGHT -30,10)
│   │   └── content (scroll child, auto-sized)
│   │       └── listText
│   └── listInset (backdrop behind scrollFrame, level-1)
└── closeButton (BOTTOMRIGHT -12,12)
```

---

## THEME / Color Palette

```lua
THEME = {
    goldActiveText = { 0.95, 0.81, 0.24 },   -- active tab labels
    mutedText      = { 0.80, 0.82, 0.86 },   -- idle tab labels / checkbox text
    tabIdleBG      = { 0.11, 0.13, 0.17, 0.24 },
    tabActiveBG    = { 0.16, 0.19, 0.25, 0.34 },
    hover          = { 1.0,  1.0,  1.0,  0.04 },
    accent         = { 0.86, 0.69, 0.22, 1.0  },  -- bottom/left indicator stripe
}
```

Title text color: `(1.0, 0.96, 0.78)` with shadow `(0,0,0,0.95)`.
Sub-title (death recap): `(0.82, 0.86, 0.93)`.
Summary gold (death recap): `(0.96, 0.82, 0.22)`.
List body text: `(0.90, 0.92, 0.96)`.

---

## Guild Rank Priority — Data Model

`ARL.db.guildRankPriority` is an **ordered array of tables**:
```lua
{ name = "Officer", rankIndex = 2 }
```
- `rankIndex` is **1-based** and corresponds to `GuildControlGetRankName(i)`.
- `GetGuildRosterInfo(i)` returns a 0-based rank index → add 1 to align.
- Matching in `GetTopAvailableByGuildRank` prefers `rankIndex` when > 0; falls back to name comparison for legacy plain-string entries.
- All Add/Remove/Move paths must use `type(entry) == "table" and entry.name or tostring(entry)` to handle both formats gracefully.
- Duplicate-name detection compares by `rankIndex` when available, otherwise by lowercased name.

---

## SavedVariables Schema (`AstralRaidLeaderDB`)

```lua
{
    preferredLeaders       = {},     -- string[]
    autoPromote            = true,
    reminderEnabled        = true,
    notifyEnabled          = true,
    notifySound            = true,
    quietMode              = false,
    groupTypeFilter        = "all",  -- "all"|"raid"|"party"
    consumableAuditEnabled = true,
    trackedConsumables     = {},     -- {label, spellIds[], namePatterns?}[]
    guildRankPriority      = {},     -- {name, rankIndex}[]  (may contain legacy strings)
    useGuildRankPriority   = false,
    deathTrackingEnabled   = true,
    showRecapOnWipe        = true,
    lastWipeDeaths         = {},     -- death record[]
    lastWipeEncounter      = "",
    lastWipeDate           = "",
}
```

---

## Helper Patterns

### `SkinPanel(panel, bgR,g,b,a, borderR,g,b,a)`
Applies a `BackdropTemplate` with `WHITE8x8` bg+border at 1px edge size.

### `SkinActionButton(btn)`
Strips template chrome, creates a backdrop child for styled rendering, hooks state colors. Idempotent via `btn._arlSkinned`.

### `SkinInputBox(edit)`
Strips `InputBoxTemplate` textures, attaches a backdrop child slightly larger than the edit box.

### `StyleCheckbox(cb)`
Sets muted text color on `cb.Text`, brightens on hover. Idempotent via `cb._arlStyled`.

---

## Common Pitfalls to Avoid

1. **Never call `SetNormalTexture(nil)`** — use `GetNormalTexture():SetAlpha(0)`.
2. **Text behind backdrop** — if text appears faded/invisible, check that the FontString's parent frame has a higher `FrameLevel` than the backdrop frame covering it. Move it to `"OVERLAY"` layer or reparent to the covering frame.
3. **Scrollbar outside container** — `UIPanelScrollFrameTemplate` anchors its bar +24px right of the scroll frame; always inset the scroll frame and reanchor the named scrollbar child.
4. **Guild rank name collision** — always store `{name, rankIndex}` not bare strings so duplicate-named ranks are distinguishable.
5. **Backward compatibility** — saved variables may contain legacy plain strings in `guildRankPriority`; always guard with `type(entry) == "table" and entry.name or tostring(entry)`.
6. **Tab label field** — custom tab buttons use `.Label` not `.Text`; `InterfaceOptionsCheckButtonTemplate` uses `.Text`.
7. **`frame:EnableMouse`** — the main frame starts with `EnableMouse(false)` and an alpha of 0, then enables on `OnShow`. This prevents click-through issues when hidden.
