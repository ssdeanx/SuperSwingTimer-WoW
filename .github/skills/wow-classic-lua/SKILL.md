---
name: wow-classic-lua
description: This skill should be used when the user asks to "write WoW Classic Lua", "debug a WoW addon", "fix Classic/TBC addon APIs", "build a swing timer", "edit Blizzard UI code", or mentions `CombatLogGetCurrentEventInfo`, `UnitAttackSpeed`, `UnitSpellHaste`, or `UnitChannelInfo`.
version: 0.1.0
---

# WoW Classic Lua

## Purpose

Treat this skill as the operating guide for WoW Classic and TBC addon work. Keep code aligned with Classic-era API behavior, preserve the separation between state, UI, config, and class-specific logic, and favor precise timer logic over speculative changes.

## Workflow

1. Inspect the current addon files and workspace instructions before editing.
2. Identify whether the task touches timer state, rendering, configuration, or class-specific behavior.
3. Confirm the relevant Classic API signatures and event payloads before relying on them.
4. Keep white-swing, spell-cast, channel, and UI rendering paths separate.
5. Make the smallest correct change, then validate the edited files with targeted diagnostics.

## API priorities

- Use `CombatLogGetCurrentEventInfo` for combat-log driven swing events.
- Use `UnitAttackSpeed` for melee swing speed.
- Use `UnitRangedDamage` for ranged swing speed.
- Use `GetMeleeHaste` for melee-haste adjustments.
- Use `UnitSpellHaste` for cast-time breakpoint math.
- Use `UnitCastingInfo` and `UnitChannelInfo` to track active cast and channel windows.
- Use `GetTimePreciseSec` or `GetTime` for frame timing, then apply cached latency only where the timing model requires it.

## Timer rules

- Keep main-hand, off-hand, and ranged timers independent.
- Treat parry haste as a swing-state adjustment, not a UI-only effect.
- Refresh latency frequently while timers are active.
- Prefer per-frame `OnUpdate` for live timer motion; reserve `C_Timer` for delayed one-shot work.
- Preserve white-hit accuracy at the end of each swing; avoid broad resets that restart the wrong hand.
- Keep Volley and other hunter channels on the ranged side; do not let them leak into shaman weave timing.

## Addon structure rules

- Keep timer state in the state module, visuals in the UI module, configuration in the config module, and class-specific behavior in the class-mod module.
- Keep config values user-adjustable when introducing new visible behavior.
- Avoid hidden hard-coding when a setting belongs in `/sst`.
- Use `_` placeholders or helper functions to avoid unused locals, especially when unpacking CLEU payloads.

## Validation

- Run targeted diagnostics on the edited files after code changes.
- Verify event-index assumptions and timer resets against the Classic API before relying on them.
- Prefer narrow fixes over broad refactors unless the user explicitly asks for a redesign.

## Additional resources

- `references/api-notes.md` for API and event reminders.
