# Deep Init Summary — SuperSwingTimer

## Repository Context

- **Name**: SuperSwingTimer-WoW
- **Type**: World of Warcraft Addon (LUA)
- **Supported Clients**: Classic Era / Season of Discovery (1.15.9, TOC Interface `11509`) and TBC Anniversary (2.5.6, TOC Interface `20506`).
- **Current Version**: `v0.2.3` (DB Schema Migration `v63`)

## Primary Architectural Boundaries

1. **Isolated Season of Discovery (`SuperSwingTimer_SoD.lua`)**: All SoD 1.15.9 rune ability tables, Maelstrom Weapon (`408505`) stack tracking, Sudden Death (`440114`) proc alerts, and `ns.SOD_TRACKED_SPELLS` tables reside strictly in `SuperSwingTimer_SoD.lua` and do not alter base files.
2. **Canonical High-Precision Clock (`SuperSwingTimer_Constants.lua`)**: High-precision timing driven by `GetTimePreciseSec()` with `GetTime()` fallback.
3. **Dedicated Class Resource Power Bars (`SuperSwingTimer_ClassMods.lua`)**: Self-contained per-class setup functions (`SetupWarrior`, `SetupRogue`, `SetupEnhShaman`, `SetupHunter`, `SetupDruid`, `SetupRetPaladin`) and unified power bar renderer `SuperSwingTimerPlayerPowerBar` (`ns.playerPowerBar` at 10px height; Rage, Energy, Mana).
4. **Hunter Auto Shot & Cast Bar (`SuperSwingTimer_UI.lua`)**: Standardized 15px height, clean unobstructed dark status bar background, independent clip zone ("red zone") color separation from cast bar color.
5. **Combat Log State Engine (`SuperSwingTimer_State.lua`)**: `ns.HandleCLEU()` processes swing timing, extra attack procs (`SPELL_EXTRA_ATTACKS`), and spell cast resets/pauses.

## High-Risk Zones & Constraints

- **Zero Git Command Execution**: NEVER execute git commands without explicit user permission.
- **Client API Return Shapes**: `ns.UnitAura()` handles 4 return shapes across Classic 1.13, Classic 1.15, TBC 2.5.6 (`UnpackAuraData`), and Retail.
- **Nil Safety**: All FrameXML/Blizzard API calls must be rawget-guarded or nil-checked.
