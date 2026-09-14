# System Patterns

## Architecture style

Event-driven Lua addon with a clear split between state, UI, class mods, constants, and configuration.

## Key patterns

- `SuperSwingTimer_State.lua` owns timer state and combat-log / spellcast interpretation.
- `SuperSwingTimer_UI.lua` owns frame creation, texture application, visibility, and OnUpdate rendering.
- `SuperSwingTimer_ClassMods.lua` injects class-specific overlays and hooks without polluting the core state engine.
- `SuperSwingTimer_Weaving.lua` computes weave timing and display data; it should not directly own swing state.
- `SuperSwingTimer.lua` performs bootstrap, SavedVariables migration, and event registration.

## Timer & Clock Model

- Separate timers are tracked for `mh`, `oh`, and `ranged`.
- High-precision clock domain: driven by `GetTimePreciseSec()` for sub-millisecond accuracy, with `GetTime()` as a fallback backup.
- Swing start timestamps originate from combat log events (`COMBAT_LOG_EVENT_UNFILTERED`) and are rescaled smoothly on haste changes (`ns.RescaleTimer`).
- Parry haste (40% reduction, 20% floor) and extra attack procs are resolved in `SuperSwingTimer_State.lua`, not UI.

## Hunter Auto Shot & Cast Bar Architecture

- Auto Shot cast bar standardized at 15px height (`ns.HUNTER_CAST_BAR_HEIGHT = 15`).
- Unobstructed dark background: cast bar uses standard status bar fill (`colors.hunterCastBar`) without full-frame overlay textures (`clipZoneOverlay` removed).
- Independent Clip Zone ("red zone") colors: `clipZone` (`autoShotUnsafe`) and `clipSafe` (`autoShotSafe`) are configured separately from `hunterCastBar`.
- Immediate stored-cast cleanup: cast display state is cleared as soon as a cast lands so the trailing cycle cleanly represents Auto Shot.
- Distance gating: `ShouldKeepHunterRangedTimerActive()` verifies target melee range via `ns.IsHunterTargetInMeleeRange()`.

## Unified Power Bar Pattern

- Single frame `SuperSwingTimerPlayerPowerBar` (`ns.playerPowerBar`) at standardized 10px height across all classes.
- Warrior Execute indicator: texture 5308 with pulsing red glow at $\le 20\%$ target HP; text label hidden.

## Color Picker Pattern

- Always pre-seed `ColorPickerFrame:SetColorRGB()` and `ColorPickerFrame:SetColorAlpha()` before calling `SetupColorPickerAndShow()` so opening a color picker never defaults to opaque white.

## Weave-display pattern

- `GetWeaveDisplayInfo()` derives breakpoint information from the current cast window and latency-aware timing, then the UI projects it onto the MH bar.
- The UI layer should position visual markers from that display info.
- Marker visibility should be separated from the question of whether the player is actively casting.

## Important design rules

- Keep dual-client Classic/TBC compatibility first (Classic Era `11509` and TBC Anniversary `20506`).
- Zero global leaks: all inter-file symbols attach to `ns`.
- Treat latency as part of the timing model for weave and clip safety (`GetNetStats()`).
- When adding new settings, update defaults, sequential migrations, runtime application, config panel, and docs together.
