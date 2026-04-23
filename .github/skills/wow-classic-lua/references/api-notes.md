# WoW Classic Lua API Notes

## Swing timing

- `CombatLogGetCurrentEventInfo()` supplies the live combat-log payload.
- `SWING_DAMAGE` and `SWING_MISSED` drive white-hit timing and off-hand detection.
- `UNIT_ATTACK_SPEED` reflects current melee weapon speed and should be treated as the source of truth for active melee haste.
- `GetMeleeHaste()` provides the current melee-haste percentage for parry scaling and related swing adjustments.
- `UnitRangedDamage()` provides the current ranged speed.

## Casting and channels

- `UnitCastingInfo()` provides cast start and end timestamps for cast-time spells.
- `UnitChannelInfo()` provides channel start and end timestamps for channel spells.
- `UnitSpellHaste()` should be used for cast-time breakpoint calculations and live weave-marker updates.

## Timing and latency

- `GetTimePreciseSec()` is useful for frame-accurate UI motion.
- `GetTime()` remains acceptable when the addon is already using that clock consistently.
- Cached network latency should be refreshed while the timer is active so the end of swing stays responsive.

## Addon design reminders

- Keep white-hit timing separate from spell timing.
- Keep melee and ranged timer sections independent.
- Keep channel spells such as hunter Volley on the ranged side.
- Avoid binding unused CLEU locals; use `_` or `select()` for only the values that are actually consumed.
