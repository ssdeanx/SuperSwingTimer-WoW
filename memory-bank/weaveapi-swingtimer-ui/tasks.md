# Tasks

## Updated

- Date: 2026-04-23
- Time: current session
- Status: In progress

## Phase 1 — Stabilize swing state

### GOAL-001

Audit and harden the main-hand, off-hand, and ranged timer state so melee timing remains reliable after landed swings, misses, parries, speed changes, and special attacks.

|Task|Description|Completed|Date|
|---|---|---|---|
|TASK-001|Compare `SuperSwingTimer_State.lua` handlers for `SWING_DAMAGE`, `SWING_MISSED`, `SPELL_CAST_SUCCESS`, and `UNIT_SPELLCAST_SUCCEEDED` against the reference swingtimer behavior in `swingtimer.md`.|[x]|2026-04-23|
|TASK-002|Verify `ns.StartSwing`, `ns.ResetTimer`, `ns.RescaleTimer`, and `ns.ApplyParryHaste` in `SuperSwingTimer_State.lua` keep `mh` state stable after a landed swing.|[x]|2026-04-23|
|TASK-003|Confirm ranged timer logic in `SuperSwingTimer_State.lua` remains isolated from MH and OH state changes.|[x]|2026-04-23|
|TASK-004|Validate that `SuperSwingTimer.lua` event registration and reset hooks do not reintroduce state drift when the addon reloads or enters combat.|[x]|2026-04-23|

## Phase 2 — Make weave math cast-driven

### GOAL-002

Ensure weave breakpoint logic is derived from cast timing, haste, and latency, while remaining visually anchored to the MH bar.

|Task|Description|Completed|Date|
|---|---|---|---|
|TASK-005|Re-check `SuperSwingTimer_Weaving.lua` so `GetWeaveDisplayInfo()` and `BuildDisplayInfo()` use cast time, cast remaining, latency, and haste rather than swing progress.|[x]|2026-04-23|
|TASK-006|Verify that `SuperSwingTimer_Weaving.lua` updates breakpoint data in real time when `UnitCastingInfo` or haste changes during an active cast.|[x]|2026-04-23|
|TASK-007|Confirm `SuperSwingTimer_Weaving.lua` never mutates `ns.timers` or any swing state object.|[x]|2026-04-23|
|TASK-008|Validate that the cast breakpoint still reports correct safe-start / clip behavior for Lightning Bolt, Chain Lightning, Healing Wave, and Lesser Healing Wave.|[x]|2026-04-23|

## Phase 3 — Separate overlay roles

### GOAL-003

Keep the weave spark and the breakpoint triangles visually and behaviorally separate so the player can read cast progress without losing the breakpoint guide.

|Task|Description|Completed|Date|
|---|---|---|---|
|TASK-009|Verify `SuperSwingTimer_ClassMods.lua` creates and updates the weave spark as cast-only and does not tie spark movement to swing elapsed time.|[x]|2026-04-23|
|TASK-010|Verify `SuperSwingTimer_ClassMods.lua` keeps the triangle breakpoint markers visible whenever weave assist is enabled and the MH bar exists.|[x]|2026-04-23|
|TASK-011|Confirm that `SuperSwingTimer_ClassMods.lua` uses separate texture, alpha, size, and layer controls for the spark versus the breakpoint triangles.|[x]|2026-04-23|
|TASK-012|Validate that the MH bar remains the visual canvas only and does not become the source of weave timing.|[x]|2026-04-23|

## Phase 4 — Expand texture and layer selection

### GOAL-004

Replace the browser-style texture picker with a categorized dropdown, and expose the full layer set required by the addon.

|Task|Description|Completed|Date|
|---|---|---|---|
|TASK-013|Rebuild the texture selector in `SuperSwingTimer_Config.lua` so each row displays `[category] label` and opens as a dropdown list rather than a browser window.|[x]|2026-04-23|
|TASK-014|Update `SuperSwingTimer_Constants.lua` so `ns.BuildTextureLibrary()` sorts SharedMedia and Blizzard entries into a stable dropdown order.|[x]|2026-04-23|
|TASK-015|Confirm the config UI exposes all intended draw-layer values for bar, spark, weave spark, and triangle visuals.|[x]|2026-04-23|
|TASK-016|Verify texture preview buttons update live when the selected media or layer changes.|[x]|2026-04-23|

## Phase 5 — Validate production readiness

### GOAL-005

Prove that the plan is ready for implementation and publishing by checking diagnostics, reload persistence, and class-specific behavior coverage.

|Task|Description|Completed|Date|
|---|---|---|---|
|TASK-017|Run targeted `get_errors` on `SuperSwingTimer_State.lua`, `SuperSwingTimer_Weaving.lua`, `SuperSwingTimer_ClassMods.lua`, `SuperSwingTimer_Config.lua`, `SuperSwingTimer_Constants.lua`, and `SuperSwingTimer.lua` after implementation.|[x]|2026-04-23|
|TASK-018|Validate persistence across `/reload` for texture, alpha, size, and layer values in `SuperSwingTimer_Config.lua`.|[x]|2026-04-23|
|TASK-019|Verify class-specific behavior coverage for Shaman, Warrior, Hunter, Rogue, Paladin, and Druid does not regress when the swing and weave systems are updated.|[x]|2026-04-23|
|TASK-020|Record final publish-ready acceptance notes in the active context file once validation is complete.|[x]|2026-04-23|

## Phase 6 — Sync release-facing files

### GOAL-006

Bring the release docs, metadata, and diagnostics surface in line with the actual addon behavior so shipping artifacts are not stale.

|Task|Description|Completed|Date|
|---|---|---|---|
|TASK-021|Update `README.md` so the feature summary, class list, `/sst` usage, and weave/texture descriptions match the current plan scope.|[x]|2026-04-23|
|TASK-022|Update `CHANGELOG.md` so the release notes describe the real scope of the swing, weave, and config changes planned for this build.|[x]|2026-04-23|
|TASK-023|Update `SuperSwingTimer.toc` so title, notes, version, and file load order remain aligned with the shipping addon state.|[x]|2026-04-23|
|TASK-024|Sync `docs/SharedMedia.md` and the diagnostics plan so the texture catalog and unopened-file error coverage are both documented for release readiness.|[x]|2026-04-23|

## Dependencies

- `swingtimer.md` reference behavior for main-hand, off-hand, and ranged timer handling.
- `docs/SharedMedia.md` texture catalog for dropdown population.
- WoW Classic/TBC API availability for `GetNetStats`, `UnitAttackSpeed`, `UnitRangedDamage`, `UnitCastingInfo`, and related UI APIs.

## Validation gates

- The main-hand timer must continue to advance after every landed swing.
- Ranged timing must remain unchanged.
- Weave spark must be cast-only.
- Weave triangles must remain visible and correctly positioned.
- The texture dropdown must show category + label entries and remain browser-free.
- The release docs and metadata must match the runtime behavior.
- Diagnostics must cover unopened files and the full shipping surface.
- The plan is not complete until all 24 tasks are explicitly checked off during implementation.
