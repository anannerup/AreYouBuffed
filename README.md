<p align="center">
  <img src="art/logo_256.png" alt="AreYouBuffed logo" width="128" height="128">
</p>

# AreYouBuffed

A lightweight raid-readiness checker for **World of Warcraft: Burning Crusade Classic (Anniversary)**.

Configure exactly which flasks, elixirs, weapon enchants, and group buffs matter for each of your characters, then run `/buffed` to get an instant on-screen checklist — green if you have it, red if you don't. Optionally, AreYouBuffed can auto-decline ready checks on your behalf when something required is missing, so you never accidentally ready up half-buffed.

There's no per-item consumable tracking, no DPS meter, no bloat — just "am I buffed, yes or no."

---

## Table of contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [Slash commands](#slash-commands)
  - [The config window](#the-config-window)
  - [The on-screen checklist](#the-on-screen-checklist)
- [How detection works](#how-detection-works)
- [FAQ](#faq)
- [For developers](#for-developers)
  - [Codebase layout](#codebase-layout)
  - [Data model](#data-model)
  - [Load order & module pattern](#load-order--module-pattern)
  - [Detection engine](#detection-engine-corelua)
  - [Display / checklist popup](#display--checklist-popup-displaylua)
  - [Config UI](#config-ui-uilua)
  - [Saved variables](#saved-variables)
  - [Maintaining the spell database](#maintaining-the-spell-database)
  - [Extending the addon](#extending-the-addon)
- [Contributing](#contributing)

---

## Features

- **Per-character configuration.** Every character tracks its own list of buffs — a tank and a healer don't need the same checklist.
- **Curated built-in database.** Flasks, battle/guardian elixirs, food buffs, weapon enchants (oils, stones, shaman imbues), class/group buffs (Fortitude, Blessings, totems, auras, shouts), and world buffs — all pre-loaded with every known rank/variant spell ID, cross-checked against a full TBC spell dump (see [Maintaining the spell database](#maintaining-the-spell-database)).
- **`/buffed`** — a single command that instantly scans everything you're tracking and shows a green/red checklist on screen for a few seconds.
- **Ready check integration.** Optionally auto-click "No" on a raid ready check if a *required* buff is missing, and post a chat warning naming exactly what's missing.
- **Required vs. optional buffs.** Track something just to keep an eye on it without it blocking ready checks.
- **Add anything by spell ID.** Not in the built-in list? Paste a spell ID from Wowhead and track it directly — works for auras and weapon enchants alike.
- **Class default sets.** One click loads a sensible starting checklist for your class, fully editable afterwards.
- **Self-validating.** At login, every built-in entry is checked against your own client's spell data. Anything that doesn't resolve is flagged `(unverified)` in the config UI instead of silently failing.
- **No dependencies.** Plain Blizzard UI widgets only — no Ace3, no external libraries. One folder, four Lua files.

## Installation

1. Download or clone this repository.
2. Copy (or symlink) the `AreYouBuffed` folder into your WoW Anniversary/TBC `Interface/AddOns/` directory, so that `Interface/AddOns/AreYouBuffed/AreYouBuffed.toc` exists.
3. Restart WoW (or reload UI with `/reload`) and enable **AreYouBuffed** at the character-select AddOns list.

If the AddOns list flags it as "out of date," tick **Load out of date AddOns** — the `## Interface:` number in the `.toc` just needs bumping after a client patch; it doesn't mean anything actually broke.

## Usage

### Slash commands

| Command | Effect |
|---|---|
| `/ayb` or `/areyoubuffed` | Opens the config window (Browse / My Buffs / Options). |
| `/buffed` | Re-scans everything you're tracking, shows the on-screen checklist, and fires the same chat + sound alarm a failed ready check would if something required is missing. |
| `/ayb check` | Same as `/buffed`, under the `/ayb` namespace. |
| `/ayb lock` | Locks the checklist popup in place (stops it from being dragged). |
| `/ayb unlock` | Unlocks it so you can drag it to a new position. |
| `/ayb reset` | Resets the checklist popup back to its default position. |

### The config window (`/ayb`)

- **Browse tab** — pick buffs to track from the built-in database, organized into categories (Flasks, Battle Elixirs, Guardian Elixirs, Food & Drink, Weapon Enchants, Class/Group Buffs, World Buffs) with a search box. Check a box to start tracking it for the current character.
- **My Buffs tab** — everything you're currently tracking. Uncheck "required" on an entry to keep watching it without it blocking ready checks. Remove entries with the `x` button. Paste a numeric spell ID from Wowhead to track anything not in the built-in list — tick "Weapon enchant" (and "Off-hand" if needed) for temporary weapon buffs. A "Load Class Defaults" button seeds a starting list for your class.
- **Options tab** — toggle the alarm sound, and toggle whether ready checks are auto-declined when a required buff is missing.

### The on-screen checklist

Hidden at login. Running `/buffed` (or `/ayb check`) pops up a small icon strip — one icon per tracked buff, colored by status — and hides itself again after 10 seconds:

- 🟩 **Green border** — active, confirmed.
- 🟥 **Red border, desaturated icon** — missing, or a weapon enchant is on but this client build can't identify exactly which one. Hover the icon for the exact reason.

Drag the header to reposition it; click the header to open the config window; hover an icon for its name and status.

## How detection works

- **Auras** (flasks, elixirs, food, class/group buffs) are detected by scanning the player's buff list and matching by spell ID *and* by name. Name matching exists because ranks, "Greater" versions, and duplicate spell IDs across factions/versions of the Anniversary realm all display the same buff name — e.g. every rank of "Greater Blessing of Kings" contains the text "Blessing of Kings." Matching on name is far more durable than trying to enumerate every id variant by hand.
- **Weapon enchants** (oils, stones, shaman imbues) are *not* regular auras — WoW's API only exposes them through `GetWeaponEnchantInfo()`. On builds that expose the specific enchant ID, a mismatch (wrong oil on your weapon) is reported the same as "missing." On builds that only expose "something is applied, but not what," it's reported as **unknown** rather than a false positive or negative — the addon would rather stay quiet than nag you about a buff you already have.
- At `PLAYER_LOGIN`, every built-in database entry is resolved against your own client's spell data (no network calls — the client already ships name/icon for every real spell ID). Entries that don't resolve are flagged in the UI so you can see at a glance if something in the built-in list is stale.

## FAQ

**Does this track other raid members' buffs?**
No — player-only, by design. It's a personal readiness check, not a raid buff monitor.

**Will it interrupt me by force-declining ready checks?**
Only if you leave "Automatically click 'No'..." enabled in Options (on by default) *and* you're missing something marked **required**. Optional entries never block a ready check.

**A buff I picked from the Browse list shows `(unverified)`. What does that mean?**
None of its spell IDs matched anything in your client's own spell database. It may be a stale ID from a patch change. Please verify on Wowhead and either report it, or track the correct one manually via "Add custom spell ID" in the My Buffs tab.

**Can I use this on multiple characters?**
Yes — tracked buffs are stored per-character (`AreYouBuffedCharDB`), while sound/ready-check/position options are shared account-wide (`AreYouBuffedDB`).

---

## For developers

### Codebase layout

```
AreYouBuffed/
├── AreYouBuffed.toc      # Addon manifest: metadata + explicit load order
├── Database.lua          # Static, curated buff/enchant database + class defaults
├── Core.lua              # Saved variables, detection engine, ready-check hook, slash commands
├── Display.lua           # The on-screen checklist popup (icon strip)
├── UI.lua                # The /ayb config window (Browse / My Buffs / Options tabs)
├── data/
│   └── tbc_spells.json   # Reference dump used to cross-check Database.lua ids (not loaded by the addon)
└── art/
    ├── logo.svg, logo_64.png, logo_256.png
```

No build step, no bundler, no external Lua dependencies (Ace3, LibStub, etc.) — the four `.lua` files are loaded directly by the WoW client in the order listed in the `.toc`. This keeps the addon a single self-contained folder that's trivial to install by hand.

### Load order & module pattern

Every file starts with the same guard:

```lua
AreYouBuffed = AreYouBuffed or {}
local AYB = AreYouBuffed
```

`AreYouBuffed` is one global table acting as the addon's namespace; each file attaches its own sub-table (`AYB.Database`, `AYB.Display`, `AYB.UI`) and functions directly onto `AYB`. The `.toc` load order matters and is intentional:

1. **`Database.lua`** — defines `AYB.Database` (static data) and `AYB:FindGroupByName`. Loaded first because `Core.lua` references it immediately.
2. **`Core.lua`** — defines saved-variable defaults, the detection engine, tracked-list management, the ready-check hook, and slash commands. This is the addon's "backend"; it has no dependency on the UI files and would function (minus visible output) without them.
3. **`Display.lua`** — the checklist popup. Reads results produced by `Core.lua`, never the other way around.
4. **`UI.lua`** — the config window. Calls into `Core.lua` (`AYB:AddTracked`, `AYB:RemoveTracked`, etc.) to mutate state, and into `Display`/itself to refresh what's on screen.

Cross-file calls always go through `AYB:MethodName(...)` — there are no `require`/`import` semantics in WoW's Lua environment, so correctness depends on load order, not module resolution.

### Data model

`Database.lua` defines categories → groups:

```lua
AYB.Database = {
  categories = {
    {
      key = "flasks",
      label = "Flasks",
      groups = {
        { name = "Flask of the Titans", ids = { 17626, 17635 } },
        ...
      },
    },
    ...
  },
  classDefaults = {
    WARRIOR = { "Fortitude (...)", "Battle Shout", ... }, -- group names, resolved via FindGroupByName
    ...
  },
}
```

A **group** describes one trackable thing:

| Field | Meaning |
|---|---|
| `name` | Display name; used as the unique key for tracked entries. Must be unique across the whole database. |
| `ids` | Every known spell ID for this buff/enchant across ranks, factions, and Anniversary-realm duplicates. Matching *any* id counts as active — an extra id that turns out to be a harmless duplicate costs nothing. |
| `match` | *(optional)* Explicit substring patterns to match against the aura's displayed name, for cases where multiple distinct spells (e.g. "Power Word: Fortitude" and "Prayer of Fortitude") should count as the same tracked thing. Falls back to `{ name }` if omitted. |
| `type` | `"aura"` (default) or `"weaponEnchant"`. |
| `slot` | For `weaponEnchant` only: `"main"` or `"off"`. |

A **tracked entry** (what actually lives in `AreYouBuffedCharDB.tracked`) is a copy of the fields above plus `required` (boolean) and, for manually-added spells, `custom = true`.

### Detection engine (`Core.lua`)

The core loop, `AYB:CheckEntry(entry)`:

- For `type == "weaponEnchant"`: calls `GetWeaponEnchantInfo()`. If the client exposes the actual enchant ID, it's checked against `entry.ids` (exact match) and, failing that, against `entry`'s resolved match patterns by name (catches variants never hardcoded). If the client only reports *that* something is applied but not *what*, the result is `"unknown"` — deliberately not treated as missing.
- Otherwise: scans the player's own buffs (`C_UnitAuras.GetBuffDataByIndex` on modern clients, `UnitBuff` fallback) up to 60 slots, matching each aura by id (if `entry.ids` given) or by name substring via `AYB:ResolveMatchPatterns(entry)`.

Results are one of `"active"`, `"missing"`, or `"unknown"`. `AYB:GetMissingRequired()` filters `"missing"` entries where `entry.required` is true — `"unknown"` never counts as missing, by design (the addon would rather stay silent than falsely nag about a buff that's actually on).

Refreshes are debounced: `UNIT_AURA` events call `AYB:RequestRefresh()`, which coalesces bursts into a single `C_Timer.After(0.2, ...)` call rather than re-scanning on every individual aura event. A `C_Timer.NewTicker(2, ...)` also re-checks every 2 seconds as a safety net (e.g. for weapon enchants, which don't fire `UNIT_AURA`).

`AYB:ValidateDatabase()` runs once at `PLAYER_LOGIN`: it resolves every id in every built-in group against the client's own spell data via `C_Spell.GetSpellInfo`/`GetSpellInfo`, and stores per-group pass/fail in `AYB.validation`, which `UI.lua` reads to show the `(unverified)` warning.

### Display / checklist popup (`Display.lua`)

A pooled-icon-button grid (`iconPool`), sized and repositioned per call to `RenderIcons(results)`. Two entry points:

- `Display:Trigger(results)` — called by `/buffed`: renders, shows the frame, and (re)starts a 10-second auto-hide timer.
- `Display:Update(results)` — called on every background refresh (login, ticker, aura change): re-renders *only if the frame is already shown*, so background scans never pop the checklist open on their own.

### Config UI (`UI.lua`)

Built entirely from Blizzard's built-in widget templates (`UICheckButtonTemplate`, `UIPanelButtonTemplate`, `UIPanelScrollFrameTemplate`, `BackdropTemplate`, ...) — no third-party UI library. Three tab panels are created once in `UI:Init()` and shown/hidden by `SelectTab(index)`; each panel's row widgets are pooled and repositioned the same way `Display.lua` pools icons, to avoid recreating widgets on every refresh.

### Saved variables

Declared in the `.toc`:

- `AreYouBuffedDB` (`SavedVariables`, account-wide) — `sound`, `autoDeclineReadyCheck`, `lockDisplay`, `displayPoint`.
- `AreYouBuffedCharDB` (`SavedVariablesPerCharacter`) — `tracked` (the array of tracked entries described above).

Both are initialized/backfilled via `CopyDefaults()` on `ADDON_LOADED`, which fills in any missing keys without clobbering existing saved values — this is what lets new default fields get added across versions without wiping a user's existing config.

### Maintaining the spell database

`data/tbc_spells.json` is a harvested reference dump (~28k spells) used *offline*, when editing `Database.lua`, to verify a spell name/id pair actually exists before adding it — it is **not** loaded by the addon at runtime. When adding or editing entries in `Database.lua`:

1. Look up the exact spell name in `data/tbc_spells.json` (or Wowhead) rather than typing an ID from memory.
2. Include every rank/variant/duplicate id for that display name in the group's `ids` array — matching any one is enough to count as active, so extra ids are harmless.
3. If no exact name match can be found at all, don't guess — leave it out of the built-in database (a couple of categories were dropped in early drafts for exactly this reason) and let users add it manually via the custom spell ID field instead.
4. `AYB:ValidateDatabase()` will automatically flag any group whose ids don't resolve on a real client, surfacing mistakes in the config UI rather than failing silently.

### Extending the addon

- **New built-in buff/enchant** → add a group to the relevant category in `Database.lua` (see above).
- **New class default set / tweak** → edit `AYB.Database.classDefaults`; entries are group *names*, resolved at runtime via `AYB:FindGroupByName`.
- **New detection type** beyond `"aura"`/`"weaponEnchant"` → add a branch in `AYB:CheckEntry` (`Core.lua`) and teach `Display.lua`/`UI.lua` to render/label the new `entry.type` if it needs different treatment.
- **New slash command** → extend the `SlashCmdList["AREYOUBUFFED"]` handler in `Core.lua`.

## Contributing

Issues and pull requests are welcome — particularly reports of stale/incorrect spell IDs (please include the correct id from Wowhead) or missing buffs worth adding to the built-in database.
