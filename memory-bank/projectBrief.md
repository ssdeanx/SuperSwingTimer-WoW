# Project Brief

## Project

Super Swing Timer is a World of Warcraft Classic/TBC addon for melee and ranged swing-timer tracking.

## Purpose

The addon helps players time white swings, next-melee-attack abilities, parry haste windows, ranged shot timing, and shaman weave breakpoints.

## Core goals

- Track main-hand, off-hand, and ranged swing timers accurately.
- Preserve Classic/TBC-compatible behavior and API usage.
- Expose configurable bars, textures, sparks, colors, alpha, and lock state through `/sst`.
- Provide class-specific support for Hunter, Warrior, Rogue, Paladin, Shaman, and Druid behavior.

## Current emphasis

- Shaman weaving assist: display breakpoint markers above and below the MH swing bar.
- Weave visuals should show the safe cast breakpoint, not just a live casting state.
- Debug the current report where the melee bar appears to stop behaving normally after a landed strike.

## Primary files

- `SuperSwingTimer.lua` — bootstrap, SavedVariables migration, slash commands, event registration.
- `SuperSwingTimer_Constants.lua` — spell IDs, class config, defaults, texture helpers.
- `SuperSwingTimer_State.lua` — timer state, combat-log handling, swing rescaling.
- `SuperSwingTimer_Weaving.lua` — shaman weave breakpoint math and display info.
- `SuperSwingTimer_UI.lua` — bar creation, texture application, visuals, drag handling.
- `SuperSwingTimer_ClassMods.lua` — class-specific overlays and behavior hooks.
- `SuperSwingTimer_Config.lua` — config panel and live preview.

## Success criteria

- Context survives chat resets.
- Future work can resume from the saved memory-bank without re-discovery.
- Weave breakpoint visuals are clear, stable, and tied to the MH swing timer.
