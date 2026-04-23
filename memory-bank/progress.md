# Progress

## Completed (2026-04-23)

- Created `.github/skills/wow-classic-lua/SKILL.md` plus a small API-notes reference so future sessions can load WoW Classic Lua guidance immediately.
- Added a `.github/hooks/` session-start hook that injects the WoW Classic Lua skill and memory-bank context automatically.
- Cleaned the swing state file's CLEU unpacking so it only binds the fields the timer actually uses.
- Refreshed latency every frame while the update loop is active, which keeps white-hit end timing and parry responses tighter.
- Scaled parry haste with `GetMeleeHaste()` / `GetHaste()` fallback to make late-swing parries feel less abrupt.
- Kept white-hit resets split correctly by hand and preserved ranged reset behavior for ranged-side spells.
- Kept hunter channel behavior on the ranged bar without leaking it into shaman weave timing.
- Updated the memory-bank notes so the current state-engine and timing findings are persisted for the next session.
- Re-ran targeted `get_errors` on the runtime addon files after the CLEU cleanup; all remain clean.

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
- Updated the SharedMedia texture picker to a dropdown-style selector with name/category labels.
- Updated the weave spark to follow cast progress instead of swing progress.
- Re-ran targeted `get_errors` on `SuperSwingTimer_Config.lua`, `SuperSwingTimer_Constants.lua`, and `SuperSwingTimer.lua`; all are clean.
- Re-ran targeted `get_errors` on `SuperSwingTimer_Config.lua`, `SuperSwingTimer_Constants.lua`, `SuperSwingTimer.lua`, and `SuperSwingTimer_ClassMods.lua`; all are clean.
- Synced `docs/SharedMedia.md` with the new dropdown selector behavior.
- Rebuilt `memory-bank/weaveapi-swingtimer-ui` with a production-ready design, PRD, and 24-task implementation plan.
- Verified targeted diagnostics are clean on the edited shipping files.
- Restored the feature-template reference file to its original reusable content.

## In progress

- None currently.

## Next

- Keep the plan and shipping docs synchronized with the addon source as future work lands.
