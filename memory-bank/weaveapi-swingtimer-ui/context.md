# Context

## Updated

- Date: 2026-04-23
- Time: current session
- Status: In progress

## Purpose

Publish-ready plan for the weave API plus swingtimer UI work. The plan must keep the main-hand swing timer fully functional while weave assist remains cast-driven, latency-aware, and visually separate from melee timing.

## Current focus

- Main-hand swing state must remain authoritative for melee timing.
- Ranged timing must remain independent and unchanged.
- Weave breakpoints must move with the spell cast, haste buffs, and latency in real time.
- The weave spark must show only while casting.
- The breakpoint triangles must remain visible on the MH bar.
- Texture selection must use a dropdown list with category + label entries, not a browser window.

## In-scope systems

| System | Responsibility | Must not do |
| --- | --- | --- |
| `SuperSwingTimer_State.lua` | Own MH / OH / ranged timer state, combat-log event handling, reset logic, delta correction, and speed rescale | Depend on weave overlay state |
| `SuperSwingTimer_Weaving.lua` | Own cast-time breakpoint math, haste handling, and latency-aware weave display data | Reset timers or drive bar state |
| `SuperSwingTimer_ClassMods.lua` | Draw weave spark and breakpoint markers on the MH bar | Change melee timing behavior |
| `SuperSwingTimer_Config.lua` | Provide config controls and texture/layer selectors | Open a browser picker |
| `SuperSwingTimer_Constants.lua` | Provide texture library, draw-layer lists, and defaults | Hide any layer or media source without explicit reason |

## Classes in scope

- Shaman
- Warrior
- Hunter
- Rogue
- Paladin
- Druid

## Live constraints

- Do not edit the feature-template folder.
- Do not touch code while this planning refresh is in progress.
- Keep timestamped notes so later sessions can resume without guessing.

## Release-facing files

The plan is connected to the files that ship with the addon, not just the Lua runtime files.

| File | Purpose |
| --- | --- |
| `README.md` | Player-facing feature summary, slash commands, and usage guidance |
| `SuperSwingTimer.toc` | Addon metadata, load order, and SavedVariables registration |
| `CHANGELOG.md` | Release history and version-specific behavior notes |
| `docs/SharedMedia.md` | Texture catalog source used by the config dropdown |
| `SuperSwingTimer.lua` | Bootstrap, SavedVariables migration, slash commands, and event wiring |
| `SuperSwingTimer_Constants.lua` | Defaults, texture libraries, and layer lists |
| `SuperSwingTimer_State.lua` | Main-hand, off-hand, and ranged timing state |
| `SuperSwingTimer_Weaving.lua` | Cast-driven weave breakpoint math |
| `SuperSwingTimer_ClassMods.lua` | Weave spark and breakpoint visual overlay |
| `SuperSwingTimer_Config.lua` | `/sst` settings panel and dropdown selectors |

## Known risks

- A melee reset bug can look like a weave bug if the spark and triangles still animate.
- A cast-time bug can look like a swing bug if the overlay is drawn on the MH bar.
- A dropdown or layer-list bug can hide valid texture choices and make the config appear incomplete.
- A diagnostics gap can hide bugs in unopened files if the plan only checks the file currently in focus.
