# Product Context

## User problem

Players need an accurate swing timer that reflects melee and ranged cooldowns while also showing class-specific timing windows that matter in Classic/TBC combat.

## Why it matters

- Missing or misleading swing timing causes clipped autos, lost damage, and failed weaving.
- Shaman weaving needs a clear breakpoint so players know when a cast is still safe before the next MH swing.
- Hunters, Warriors, and Paladins also depend on timing overlays for their class mechanics.

## User-facing value

- Visible melee/ranged bars that update in combat.
- Configurable textures and overlays so the addon can fit different UI setups.
- Clear weave breakpoint feedback for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal.

## Current Focus & Value Areas

- **Hunter Dual-Bar Engine**: Standardized 15px Auto Shot cast bar with an unobstructed dark status bar background, independent Clip Zone ("red zone") and Clip Safe colors separate from Cast Bar color, and immediate stored-cast clearing at cast landing.
- **Unified Multi-Class Power Bar**: 10px resource tracking across all physical classes (Rage, Energy, Mana, and dynamic shapeshifting) with Warrior Execute range indicator.
- **Timing Engine Precision**: Sub-millisecond swing and cast timing via `GetTimePreciseSec()` with `GetTime()` fallback to prevent timer drift during high-haste combat and weaving.
- **Shaman Weaving Assist**: Dynamic breakpoint markers above and below the MH bar showing safe cast-by thresholds, scaling with haste, Maelstrom Weapon, and latency.

## Desired Behavior & Invariants

- Hunter cast bar maintains a clean dark status bar background; color changes to the cast bar never alter the clip zone ("red zone") color on the ranged bar.
- Hunter melee keep-alive verifies distance to prevent main-hand bar flash at cycle end.
- Swing bars animate smoothly without stutter, jitter, or jump on haste changes (`RescaleTimer`).
- Weave breakpoint markers and latency slices accurately reflect real-time network latency via `GetNetStats()`.
