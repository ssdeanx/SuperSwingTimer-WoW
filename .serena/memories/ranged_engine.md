# Hunter Ranged Engine & Auto Shot Mechanics

## Dual-Bar Architecture
- **Ranged Bar (`ns.rangedBar`)**: Represents physical weapon speed cooldown cycle.
- **Auto Shot Cast Bar (`ns.hunterCastBar`)**: Standardized 15px height (`ns.HUNTER_CAST_BAR_HEIGHT = 15`). Displays 0.5s windup and hard casts (Aimed Shot, Steady Shot).
- **Unobstructed Dark Background**: Clean status bar background with fill colored by `colors.hunterCastBar`. Never overlay full-frame opaque textures (`clipZoneOverlay` removed).

## Clip Detection & Latency Buffers
- Visual color cues distinguish safe cast windows from clipped windows.
- **Independent Color Settings**: Clip Zone ("red zone") color (`clipZone`/`autoShotUnsafe`) and Clip Safe color (`clipSafe`/`autoShotSafe`) are configured independently from Cast Bar color (`hunterCastBar`).
- Trailing latency slice based on real-time `GetNetStats()` (`ns.cachedLatency`).

## Event Gating & State Transitions
- **Transient Stop Filtering**: Avoids false `STOP_AUTOREPEAT_SPELL` resets during jumping/spellcasts by checking `GetAutoRepeatSpell()`.
- **Melee Keep-Alive Distance Gating**: `ShouldKeepHunterRangedTimerActive()` checks `ns.IsHunterTargetInMeleeRange() == true` before keeping melee active, preventing MH bar flash and ranged resets.
- **Stored Cast Cleanup**: Cleared immediately at cast landing in `HandleSpellcastSucceeded()` so the cycle smoothly transitions to Auto Shot.

## Related Memories
- Main architecture map: `mem:core`
- UI and typography conventions: `mem:conventions`
- Config and migration engine: `mem:config_and_migrations`
