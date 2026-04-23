# Feature Context: Shaman Weave Assist

## Phase

INVESTIGATION

## Session

2026-04-23

## Scope

Diagnose why the weave overlay / melee bar behavior looks wrong after a landed strike and make the breakpoint markers behave like a persistent cast-threshold guide.

## Decisions so far

| Decision | Choice | Reason |
| --- | --- | --- |
| Breakpoint source | Current cast window | Weave safety is based on cast remaining or cast time plus latency. |
| Marker canvas | MH bar | The overlay is drawn on the melee bar, but it does not use swing progress as the breakpoint source. |
| Marker visibility | Breakpoint markers should not require an active cast | The desired UX is a persistent breakpoint guide, not a cast-only flash. |
| Timing model | Latency-aware cast timing | The cast window must include network delay. |

## Likely code path

- `SuperSwingTimer_ClassMods.lua` → `SetupEnhShaman()` → `UpdateWeaveVisuals()`

## Known behavior

- Spark and triangle textures are already created and anchored to the MH bar.
- The current code now keeps the triangle breakpoint markers visible when the MH timer is active.
- `SuperSwingTimer_Weaving.lua` now returns cast-window-based breakpoint math that is still drawn onto the MH bar.
- The spark remains cast-only; the triangles are the persistent breakpoint guide.

## Open questions

- Should the triangle markers be anchored to the exact threshold even while idle?
- Is the reported “weird image” caused by visibility gating or by an incorrect anchor/width calculation?

## Blockers

- Need one focused code change and validation pass to confirm the overlay is not suppressing the MH bar display.

## Notes for future sessions

- Keep this file updated with the exact decision once the weave overlay fix is applied.
- Do not let the separate `weavingapi.md` reference get mixed up with the addon’s live weave overlay implementation.
