# Project Brief

## Project

Super Swing Timer is a World of Warcraft Classic/TBC addon for melee and ranged swing-timer tracking.

**Branch baseline:** BC Classic Anniversary Edition (2026), patch-family 2.5.5.

- **Current Version**: `v0.2.4` (DB Schema Migration `v64`)
- **Target Environments**: Classic Era / Season of Discovery (`11509`) and TBC Anniversary (`20506`).

## Purpose

The addon helps players time white swings, next-melee-attack abilities, parry haste windows, ranged shot timing, spell-weaving breakpoints, and class resource bars.

## Core goals

- Track main-hand, off-hand, and ranged swing timers with sub-millisecond precision via `GetTimePreciseSec()`.
- Preserve dual-client compatibility across Classic Era and TBC Anniversary without global leaks or lua warnings.
- Expose comprehensive configuration through `/sst` (Quick Controls, Appearance, Colors, Weaving, Advanced).
- Provide class-specific modules for Hunter, Warrior, Rogue, Paladin, Shaman, and Druid.
- Maintain unified 10px player power tracking and 15px Hunter Auto Shot cast bar.

## Current emphasis

- **C-Level Unit Event Filtering**: `RegisterUnitEventSafe` drops 95%+ of raid event churn at the C engine level.
- **Zero-Allocation Hotpaths & Idle Sleep**: Unrolled timer checks, string caching, spark de-duplication, and idle `OnUpdate` sleep reducing idle CPU to 0%.
- **Headless Test Automation**: Standalone CLI test execution runner (`run_tests.lua`) testing all 7 groups (68 tests) in ~0.013s.
- **Hunter Dual-Bar Engine**: 15px Auto Shot cast bar with unobstructed dark background, independent Clip Zone ("red zone") color controls, and target melee range gating.
- **Unified Power Bar**: Standardized 10px power bar across all physical classes with dynamic shapeshift and Execute alert support.
- **Migration & Settings Robustness**: Migration v64 ensuring default dimensions and class-colored power bars.

## Primary files (12 Files)

- `SuperSwingTimer.toc` — TOC manifest, interface versioning, load order.
- `SuperSwingTimer_Constants.lua` — Colors, dimensions, sound IDs, DB defaults, font resolver.
- `Media/SuperSwingTimer_Media.lua` — Status bar, spark, and border textures.
- `SuperSwingTimer_State.lua` — Swing timer state machine, speed changes, pause/resume, CLEU parsing.
- `SuperSwingTimer_Weaving.lua` — Shaman spell-weaving calculations, cast time scaling, clip detection.
- `SuperSwingTimer_Hooks.lua` — Combat log and spellcast event routing, swing resets.
- `SuperSwingTimer_UI.lua` — Frame creation, layout, Hunter Auto Shot 15px cast bar, latency markers.
- `SuperSwingTimer_ClassMods.lua` — Class modules (6 classes), unified power bar, debuffs, buff icons.
- `SuperSwingTimer_Config.lua` — Options panel, Quick Controls, `/sst` slash dispatcher.
- `SuperSwingTimer.lua` — Addon bootstrap, DB migrations (v64), lifecycle events.
- `SuperSwingTimer_SoD.lua` — Season of Discovery rune matrices, aura maps, spell definitions.
- `SuperSwingTimer_Tests.lua` — In-game WoWUnit test suite across 7 functional groups (`/ssttest`).
- `run_tests.lua` — Standalone CLI test runner with mock WoW 5.1/Classic environment.

## Success criteria

- Zero linter warnings/errors in `luacheck .` across all 12 Lua files.
- Context survives chat resets and memory graphs remain intact.
- Seamless DB migration upgrades without player profile resets.
