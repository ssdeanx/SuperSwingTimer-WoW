# Active Context

## Current focus

1. Memory-bank initialization and persistence.
2. Shaman weaving assist investigation.

## What we know right now

- The weave breakpoint now uses the current cast window (cast remaining or cast time plus latency) while still being drawn on the MH bar canvas.
- Melee swing starts now use the latency-adjusted combat-log path more consistently, which should reduce the post-swing drift seen on MH.
- The overlay now keeps the breakpoint triangles visible while the MH timer is active; the spark remains cast-only.

## Likely bug area

- `SetupEnhShaman()` / `UpdateWeaveVisuals()` in `SuperSwingTimer_ClassMods.lua` for breakpoint placement.
- `SuperSwingTimer_State.lua` for the melee timing origin used after swings land.

## Working assumptions

- The cast window is the breakpoint source; the MH bar is just the visual surface the breakpoint is drawn onto.
- The triangle markers should represent the safe cast threshold based on cast remaining / cast time and latency.
- The spark may remain tied to cast progress, but the breakpoint markers themselves likely need to stay visible whenever weave assist is enabled and the MH timer is active.

## Next steps

- Verify the weave overlay behavior in-game or via targeted diagnostics.
- Confirm the MH bar still renders normally after landed swings.
- Preserve the memory-bank updates after the code change so future chats resume from the exact state.
