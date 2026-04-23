# Progress

## Completed

- Loaded the repo instructions, memory-bank instructions, and current weaving/UI code context.
- Confirmed the project is a Classic/TBC WoW addon with separate state, UI, constants, config, and class-mod layers.
- Identified that the shaman weave overlay currently hides markers unless `info.isCasting` is true.
- Initialized the persistent memory-bank notes so later chats can resume without rediscovery.
- Applied the first weave overlay fix so breakpoint triangles stay visible when the MH timer is active.
- Updated the weave breakpoint math to use the current cast window instead of a full cast-time-only threshold.
- Applied latency-adjusted melee swing starts for MH/OH combat-log events.
- Ran a lightweight `git diff --check`; no patch errors were reported.
- Targeted `get_errors` on `SuperSwingTimer_State.lua`, `SuperSwingTimer_ClassMods.lua`, `SuperSwingTimer_Weaving.lua`, and `SuperSwingTimer_UI.lua` returned clean.

## In progress

- Verifying the weave overlay behavior and melee timing drift in live use.

## Next

- Validate the change in-game and record any remaining edge cases if they appear.
