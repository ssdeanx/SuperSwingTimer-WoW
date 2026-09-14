# Architecture & Runtime Overview

## File Structure & Load Order

Defined in `SuperSwingTimer.toc` for Classic Era (`11509`) and TBC Anniversary (`20506`):

1. `SuperSwingTimer_Constants.lua`: Color palettes, default configs (`ns.DB_DEFAULTS`), font resolvers (`ns.GetDefaultFont`), sound IDs, dimensions.
2. `Media/Media.xml` & `Media/SuperSwingTimer_Media.lua`: Shared texture definitions, bar textures, spark textures, border assets.
3. `SuperSwingTimer_State.lua`: State machine tracking player swings (`ns.timers.mh`, `ns.timers.oh`, `ns.timers.ranged`), auto-shot states, attack speeds, pause/resume.
4. `SuperSwingTimer_Weaving.lua`: Spell-weaving calculation engine, live cast time tracking, haste/Maelstrom scaling, clip detection.
5. `SuperSwingTimer_Hooks.lua`: Combat log parsers (`COMBAT_LOG_EVENT_UNFILTERED`), spellcast events (`UNIT_SPELLCAST_*`), swing resets, range checker.
6. `SuperSwingTimer_UI.lua`: Primary frame construction (`ns.mhBar`, `ns.ohBar`, `ns.rangedBar`, `ns.enemyBar`), layout management, Hunter Auto Shot cast bar (15px), latency overlays.
7. `SuperSwingTimer_ClassMods.lua`: Class-specific mechanics (Warrior, Paladin, Shaman, Druid, Hunter, Rogue), debuff duration bars, buff icons, unified power bar (`SuperSwingTimerPlayerPowerBar`).
8. `SuperSwingTimer_Config.lua`: Blizzard Settings / Interface Options panels, Quick Controls, slash command dispatcher (`/sst`).
9. `SuperSwingTimer.lua`: Addon initialization (`ADDON_LOADED`, `PLAYER_LOGIN`), SavedVariables migration pipeline (`ns.DB_CURRENT_VERSION = 63`), event dispatcher.
10. `SuperSwingTimer_SoD.lua`: Season of Discovery rune database, spell matrices, aura maps.
11. `SuperSwingTimer_Tests.lua`: WoWUnit in-game test suite (`/ssttest`), test registration across 7 functional groups.

## Core Namespace & State

- All internal tables and routines share the private namespace `ns` passed into each file: `local _, ns = ...`.
- SavedVariables: `SuperSwingTimerDB` (primary schema v63), with legacy profile imports from `SwangThangDB` and `HunterTimerDB`.
- Timing Engine: Uses `GetTimePreciseSec()` for sub-millisecond precision with `GetTime()` fallback backup.

## Frame Strata & Layering

- Swing Bars (`ns.mhBar`, `ns.ohBar`, `ns.rangedBar`, `ns.enemyBar`): `MEDIUM` strata.
- Hunter Cast Bar: 15px standard height, maintaining an unobstructed dark status bar background with fill colored by `colors.hunterCastBar`.
- Debuff Duration Bars: Anchored dynamically above the swing bars via `RestackDebuffBars`.
- Unified Power Bar: `SuperSwingTimerPlayerPowerBar`, anchored beneath the lowest active bar at height 10px.
- Weave Spark Overlay: Dedicated child frame at `FrameLevel + 6` to avoid being clipped by bar textures or borders.
- Buff / CD Icons: `DIALOG` strata, positioned above active debuff bars via `ComputeBuffIconOffset`.
