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

## Current user-reported issue

The melee/weave visuals appear to become incorrect after a landed strike. The suspicion is that weave overlays or timing math are hiding the expected breakpoint markers or misrepresenting the swing position.

## Desired behavior

- The MH bar should continue to animate normally after swings land.
- Weave markers should sit above and below the MH bar as breakpoint indicators.
- The breakpoint should show where a cast must begin to avoid clipping the next MH swing.
- The assist should use latency-aware cast timing, not a static snapshot.
