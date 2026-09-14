# SuperSwingTimer Project Memory Index

> High-signal project index for SuperSwingTimer (WoW Classic Era 1.15.x & TBC Anniversary 2.5.6).

## Overview & Addon Identity

- **Name**: SuperSwingTimer
- **Current Version**: `v0.2.3` (DB schema migration `v63`)
- **Author**: AcidBomb
- **Target Clients**: Classic Era (`11509`) and TBC Anniversary (`20506`), including Season of Discovery (SoD).
- **Core Purpose**: Ultra-accurate melee, ranged, and target swing timers with class-specific power/debuff bars, spell-weaving assistance, and buff tracking.

## Core File Index (11 Files)

| File | Role |
| :--- | :--- |
| [SuperSwingTimer.toc](file:///home/sam/SuperSwingTimer-WoW/SuperSwingTimer.toc) | TOC metadata, dual-interface support, file load order. |
| [SuperSwingTimer_Constants.lua](file:///home/sam/SuperSwingTimer-WoW/SuperSwingTimer_Constants.lua) | Colors, dimensions, sound IDs, DB defaults, `ns.GetDefaultFont()`. |
| [Media/SuperSwingTimer_Media.lua](file:///home/sam/SuperSwingTimer-WoW/Media/SuperSwingTimer_Media.lua) | Status bar, spark, and border texture registrations. |
| [SuperSwingTimer_State.lua](file:///home/sam/SuperSwingTimer-WoW/SuperSwingTimer_State.lua) | Swing timer state machine (MH, OH, Ranged), pause/resume, speed changes. |
| [SuperSwingTimer_Weaving.lua](file:///home/sam/SuperSwingTimer-WoW/SuperSwingTimer_Weaving.lua) | Shaman spell-weaving calculations, live cast/haste scaling, clip detection. |
| [SuperSwingTimer_Hooks.lua](file:///home/sam/SuperSwingTimer-WoW/SuperSwingTimer_Hooks.lua) | Combat log and spellcast event routing, swing resets, auto-shot gating. |
| [SuperSwingTimer_UI.lua](file:///home/sam/SuperSwingTimer-WoW/SuperSwingTimer_UI.lua) | Primary swing bars, Hunter 15px Auto Shot cast bar, latency markers. |
| [SuperSwingTimer_ClassMods.lua](file:///home/sam/SuperSwingTimer-WoW/SuperSwingTimer_ClassMods.lua) | Class modules (6 physical classes), unified power bar, debuff bars, buff icons. |
| [SuperSwingTimer_Config.lua](file:///home/sam/SuperSwingTimer-WoW/SuperSwingTimer_Config.lua) | Settings UI panel, Quick Controls, `/sst` slash commands. |
| [SuperSwingTimer.lua](file:///home/sam/SuperSwingTimer-WoW/SuperSwingTimer.lua) | Addon lifecycle, DB migrations (v63), event dispatching. |
| [SuperSwingTimer_SoD.lua](file:///home/sam/SuperSwingTimer-WoW/SuperSwingTimer_SoD.lua) | Season of Discovery rune matrices, aura maps, spell definitions. |
| [SuperSwingTimer_Tests.lua](file:///home/sam/SuperSwingTimer-WoW/SuperSwingTimer_Tests.lua) | In-game WoWUnit test suite across 7 functional groups (`/ssttest`). |

## Key Architectural Decisions

1. **Unified Power Bar**:
   - Single frame `SuperSwingTimerPlayerPowerBar` (`ns.playerPowerBar`) used across all classes at standardized 10px height.
   - Rage (Warrior), Energy (Rage/Druid), Mana (Paladin/Shaman/Hunter/Druid). Dynamic shapeshifting supported.
   - Warrior Execute indicator: texture 5308 with red pulse glow at $\le 20\%$ target HP; text label hidden.
2. **Debuff Bars**:
   - Outside-left icon anchoring (`RIGHT`, `bar`, `LEFT`, -2, 0) with `0.07-0.93` texture coordinates.
   - Bars align 100% with the swing bar width at $X=0$.
3. **Buff & CD Icons**:
   - Timer text centered strictly **above** the icon (`"BOTTOM", icon, "TOP", 0, 2`, centered justify).
   - Only stack count text appears over the icon face (`"BOTTOMRIGHT"`, 11pt, outline, white text).
4. **Shaman Spell-Weaving**:
   - Live cast duration dynamically resolved via `GetSpellInfo(spellId)`.
   - Real-time scaling from active haste buffs and SoD Maelstrom Weapon (20%/stack, instant at 5 stacks).
   - Over-bar spark overlay visible only while casting; Shaman blue if safe, bright red if clipped.

## Topic References

- [Architecture & Runtime Details](file:///home/sam/SuperSwingTimer-WoW/.omg/memory/architecture.md)
- [Melee Swing Engine & Combat Mechanics](file:///home/sam/SuperSwingTimer-WoW/.omg/memory/swing_engine.md)
- [Hunter Ranged Engine & Auto Shot](file:///home/sam/SuperSwingTimer-WoW/.omg/memory/ranged_engine.md)
- [Class Systems, Power Bar & Icons](file:///home/sam/SuperSwingTimer-WoW/.omg/memory/class_systems.md)
- [Shaman Spell-Weaving Engine](file:///home/sam/SuperSwingTimer-WoW/.omg/memory/weaving.md)
- [Season of Discovery Mechanics](file:///home/sam/SuperSwingTimer-WoW/.omg/memory/sod_mechanics.md)
- [SavedVariables & Migration Engine](file:///home/sam/SuperSwingTimer-WoW/.omg/memory/config_and_migrations.md)
- [Performance Guidelines & Gotchas](file:///home/sam/SuperSwingTimer-WoW/.omg/memory/performance_and_gotchas.md)
- [Development & Quality Standards](file:///home/sam/SuperSwingTimer-WoW/.omg/memory/standards.md) (includes `wow-ui-source` API research guide)

## Blizzard API Research (wow-ui-source)

- **Primary Source**: Community-maintained mirror of Blizzard's FrameXML and interface code: [github.com/Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source).
- **Branches to Target**:
  - `classic_era`: Use for Classic Era / Season of Discovery (`1.15.x`).
  - `classic` / `bcc`: Use for Burning Crusade Classic / TBC Anniversary (`2.5.6`).
  - `live`: Use for modern retail reference.
- **Key Inspection Paths**:
  - `Interface/FrameXML/`: Core frame behaviors (`Constants.lua`, `UnitPower.lua`, `UIParent.lua`, `PowerBarColor`).
  - `Interface/SharedXML/`: Shared utilities (`C_Spell`, `C_UnitAuras`, math and table libraries).
  - `Interface/AddOns/Blizzard_APIDocumentationGenerated/`: Official Blizzard API documentation files with typed parameters, return signatures, and event payloads.
  - `Interface/FrameXML/GlobalStrings.lua`: Localized tokens, global strings, and format specifiers.

## Active Rule Packs

- [Classic Compatibility Rule Pack](file:///home/sam/SuperSwingTimer-WoW/.omg/rules/classic_compatibility.md) (`alwaysApply: true`)
- [UI & Typography Standards Rule Pack](file:///home/sam/SuperSwingTimer-WoW/.omg/rules/ui_standards.md) (`globs: ["SuperSwingTimer_ClassMods.lua", "SuperSwingTimer_UI.lua", "SuperSwingTimer_Weaving.lua"]`)
