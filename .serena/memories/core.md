# SuperSwingTimer Core Architecture & Map

World of Warcraft combat swing timer addon for Classic Era (1.15.x / SoD) and TBC Anniversary (2.5.6).
Addon private namespace: `local addonName, ns = ...` shared across all files.

## Source Map & TOC Load Order

1. `SuperSwingTimer_Constants.lua`: Color palettes, `ns.DB_DEFAULTS`, font resolvers (`ns.GetDefaultFont`), sound IDs, bar dimensions.
2. `Media/Media.xml` & `Media/SuperSwingTimer_Media.lua`: Status bar, spark, and border textures.
3. `SuperSwingTimer_State.lua`: Swing timer state machine (`ns.timers.mh`, `ns.timers.oh`, `ns.timers.ranged`), auto-shot states, attack speeds, mid-swing haste scaling (`ns.RescaleTimer`), parry haste (`ns.ApplyParryHaste`). High-precision sub-millisecond timer engine driven by `GetTimePreciseSec()` with `GetTime()` fallback.
4. `SuperSwingTimer_Weaving.lua`: Spell-weaving calculation engine, live cast time tracking, haste/Maelstrom scaling, clip detection.
5. `SuperSwingTimer_Hooks.lua`: Event hooks, combat log routing (`COMBAT_LOG_EVENT_UNFILTERED`), spellcast events (`UNIT_SPELLCAST_*`), swing resets.
6. `SuperSwingTimer_UI.lua`: Frame creation (`ns.mhBar`, `ns.ohBar`, `ns.rangedBar`, `ns.enemyBar`), layout management, Hunter Auto Shot cast bar (15px), latency overlays.
7. `SuperSwingTimer_ClassMods.lua`: Class modules (Warrior, Paladin, Shaman, Druid, Hunter, Rogue), debuff duration bars, buff icons, unified power bar (`SuperSwingTimerPlayerPowerBar`).
8. `SuperSwingTimer_Config.lua`: Blizzard Settings / Interface Options panel, Quick Controls, `/sst` slash command dispatcher.
9. `SuperSwingTimer.lua`: Addon lifecycle (`ADDON_LOADED`, `PLAYER_LOGIN`), SavedVariables migrations (`ns.DB_CURRENT_VERSION = 63`), event dispatching.
10. `SuperSwingTimer_SoD.lua`: Season of Discovery rune matrices, aura maps, spell definitions.
11. `SuperSwingTimer_Tests.lua`: WoWUnit in-game test suite (`/ssttest`) covering 7 functional groups.

## Invariants

- Dual-client support: Must run without errors on both Classic Era (11509) and TBC Anniversary (20506).
- Zero linter warnings/errors: Must strictly pass `luacheck .` with 0 warnings.
- Private namespace `ns`: All inter-file state and functions must attach to `ns`. Never leak globals.
- SavedVariables: Primary `SuperSwingTimerDB` (schema v63). Migrations handled sequentially in `SuperSwingTimer.lua`.
- Timing Engine: Uses `GetTimePreciseSec()` for sub-millisecond precision with `GetTime()` fallback.
- Hunter Cast Bar & Clip Zone: Hunter cast bar background remains an unobstructed dark status bar; clip zone / clip safe colors are independently configurable from cast bar color.
- Localized fonts: Never hardcode `"Fonts\\FRIZQT__.TTF"`. Always resolve via `ns.GetDefaultFont()` or `GetFontPath()`.

## Related Project Domain Memories

- Melee swing engine, CLEU routing, and parry haste: `mem:swing_engine`
- Hunter ranged engine, Auto Shot dual-bar, and clip zones: `mem:ranged_engine`
- Shaman spell-weaving calculations and breakpoint markers: `mem:weaving`
- Multi-class resource power bars, debuffs, and buff icons: `mem:class_systems`
- SavedVariables migrations, settings UI, and color pickers: `mem:config_and_migrations`
- Season of Discovery runes, aura handling, and isolation: `mem:sod_mechanics`
- Technology stack and runtime requirements: `mem:tech_stack`
- Development commands and validation tools: `mem:suggested_commands`
- Codebase style, layout, and UI standards: `mem:conventions`
- Task verification and completion checklist: `mem:task_completion`
- Memory maintenance and progressive discovery graph: `mem:memory_maintenance`
