# System Patterns

## Architecture style

Event-driven Lua addon with a clear split between state, UI, class mods, constants, and configuration.

## Key patterns

- `SuperSwingTimer_State.lua` owns timer state and combat-log / spellcast interpretation.
- `SuperSwingTimer_UI.lua` owns frame creation, texture application, visibility, and OnUpdate rendering.
- `SuperSwingTimer_ClassMods.lua` injects class-specific overlays and hooks without polluting the core state engine.
- `SuperSwingTimer_Weaving.lua` computes weave timing and display data; it should not directly own swing state.
- `SuperSwingTimer.lua` performs bootstrap, SavedVariables migration, and event registration.

## Timer model

- Separate timers are tracked for `mh`, `oh`, and `ranged`.
- Swing start timestamps come from combat log and are rescaled on haste changes.
- Parry haste and extra attacks are handled in the state layer, not the UI layer.

## Weave-display pattern

- `GetWeaveDisplayInfo()` derives breakpoint information from the current cast window and latency-aware timing, then the UI projects it onto the MH bar.
- The UI layer should position visual markers from that display info.
- Marker visibility should be separated from the question of whether the player is actively casting.

## Important design rules

- Keep Classic/TBC compatibility first.
- Treat latency as part of the timing model for weave safety.
- Preserve the distinction between live swing progress and breakpoint guidance.
- When adding new settings, update defaults, migration, runtime application, config panel, and docs together.
