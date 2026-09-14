# Hunter Ranged Engine & Auto Shot Mechanics

## 1. Dual-Bar Architecture

The Hunter ranged system operates two synchronized bars:

1. **Ranged Swing Bar (`ns.rangedBar`)**:
   - Represents the physical Auto Shot cooldown cycle (weapon speed).
   - Driven by `START_AUTOREPEAT_SPELL`, `STOP_AUTOREPEAT_SPELL`, and `SPELL_UPDATE_COOLDOWN` for Auto Shot (`spellId = 75`).
2. **Auto Shot Cast Bar (`ns.hunterCastBar`)**:
   - Standardized height: **15px** (`ns.HUNTER_CAST_BAR_HEIGHT = 15`).
   - Displays the 0.5s internal "windup" cast time before an arrow/bullet is released.
   - Also tracks hard-cast shots: Aimed Shot (3.0s base) and Steady Shot (1.5s base).
   - **Clean Dark Background**: `clipZoneOverlay` was completely removed so the dark status bar background remains unobstructed during Auto Shot, Multi-Shot, and Steady Shot. Fills with `colors.hunterCastBar`.
   - **Stored Cast Cleanup**: Cleared immediately at cast landing in `HandleSpellcastSucceeded()` so the trailing cycle displays Auto Shot cleanly instead of a stale cast name.

## 2. Transient Stop Event Filtering (Anniversary / Classic Bug Fix)

- **Problem**: In WoW Classic Era and TBC Anniversary, casting a spell, jumping, or transient movement can fire a false `STOP_AUTOREPEAT_SPELL` event even though the player's Auto Shot mode is still active.
- **Solution**: Auto-repeat state gating:
  - SuperSwingTimer checks `GetAutoRepeatSpell()` or cooldown state before tearing down the ranged timer mid-cycle.
  - Seeding occurs immediately on `START_AUTOREPEAT_SPELL` rather than waiting for cooldown updates.
  - **Melee Keep-Alive**: `ShouldKeepHunterRangedTimerActive()` verifies `ns.IsHunterTargetInMeleeRange() == true` before keeping melee active, preventing MH bar flash and ranged timer resets when the hunter meleed earlier in combat.

## 3. Clip Detection & Latency Buffers

- **Steady Shot & Aimed Shot Weaving**:
  - Hard-cast abilities can clip into the next Auto Shot cycle if cast too late.
  - The cast bar renders a trailing latency slice based on real-time `ns.cachedLatency` from `GetNetStats()`.
  - Visual color cues distinguish "safe" cast windows (Auto Shot will fire cleanly without clipping) from "clipped" windows (Auto Shot will be delayed).
  - **Independent Clip Zone ("Red Zone") Colors**: `clipZone` (`autoShotUnsafe`) and `clipSafe` (`autoShotSafe`) colors are fully separated from the Cast Bar color (`hunterCastBar`).
  - **Color Picker Hardening**: `OpenColorPicker` seeds `ColorPickerFrame:SetColorRGB()` and `ColorPickerFrame:SetColorAlpha()` prior to opening so swatches never default to opaque white.

## 4. Movement & Range Gating

- Auto Shot cannot fire while moving. When moving (`PLAYER_STARTED_MOVING`), the cast zone visual reflects the blocked state.
- **Range Helper**: Detects the classic 8-35 yard sweet spot vs the 0-8 yard deadzone using spell range checks.
