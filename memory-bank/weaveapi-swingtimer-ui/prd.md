# PRD

## Problem

The addon must be ready to ship without half-finished behavior. The main-hand swing timer needs to remain correct after every landed swing, while the weave assist must remain cast-driven, latency-aware, and updated by haste buffs in real time. Texture selection also needs to be easier to use and more complete than the current browser-based approach.

## Goals

1. Keep the main-hand swing timer fully functional.
2. Preserve ranged timer behavior.
3. Keep weave breakpoints tied to cast timing, not swing timing.
4. Make weave breakpoints react to cast haste changes in real time.
5. Keep the weave spark cast-only.
6. Keep breakpoint triangles visible on the MH bar.
7. Provide a dropdown texture selector that shows category and label.
8. Expose all intended texture layers in the config UI.
9. Maintain clean diagnostics and publish-ready confidence.

## Non-goals

- Do not rebuild the addon into a different UI framework.
- Do not introduce a separate weave bar.
- Do not make swing timing depend on weave math.
- Do not keep the browser texture picker.
- Do not modify the feature-template folder as part of this plan.

## User stories

### Story 1 — Shaman weave timing stays cast-driven

As a Shaman, I want the breakpoint guide to move with my current cast and haste buffs so I know whether I can safely weave before the next clipping window.

Acceptance criteria:

- Breakpoint position updates when cast time changes.
- Breakpoint position updates when haste buffs change.
- Breakpoint position incorporates latency.
- Breakpoint triangles remain visible on the MH bar.

### Story 2 — Shaman spark follows the spell cast only

As a Shaman, I want the spark to represent spell cast progress only so I can distinguish cast timing from melee swing timing.

Acceptance criteria:

- Spark is visible only while casting.
- Spark movement follows cast progress, not swing progress.
- Spark does not affect main-hand timer state.
- Spark and breakpoint triangles have separate behavior controls.

### Story 3 — Warrior main-hand swing resets correctly

As a Warrior, I want Heroic Strike, Cleave, Slam, and landed white swings to keep the MH timer accurate so the swing bar does not stop or drift after a hit.

Acceptance criteria:

- MH timer restarts correctly after landed swings.
- MH timer survives Slam/NMA interactions.
- Parry haste does not corrupt the main-hand bar.
- Ranged timing remains unaffected.

### Story 4 — Hunter ranged timing remains independent

As a Hunter, I want auto-shot timing to remain stable even when melee logic changes so ranged shots are still trustworthy.

Acceptance criteria:

- Ranged timer continues to function independently of MH state.
- Ranged behavior is unchanged by weave overlay updates.
- Texture or config changes do not alter ranged swing math.

### Story 5 — Rogue dual-wield timing remains separated

As a Rogue, I want off-hand and main-hand timers to stay independent so one side does not reset or corrupt the other.

Acceptance criteria:

- OH logic remains separate from MH logic.
- OH events do not trigger weave overlay changes.
- MH overlay changes do not alter OH timer state.

### Story 6 — Paladin seal-twist window remains accurate

As a Paladin, I want the seal-twist window to continue using the MH bar correctly so the timing aid remains usable.

Acceptance criteria:

- MH timing visuals remain accurate for seal-twist workflows.
- No weave changes degrade paladin-specific overlays.
- Color or texture adjustments do not break the timing cue.

### Story 7 — Druid form transitions remain stable

As a Druid, I want shapeshift-related timer resets and labels to keep working so the addon remains reliable across form changes.

Acceptance criteria:

- Form changes still update any form-specific label behavior.
- Main-hand timer resets remain stable through form transitions.
- Weave assist changes do not affect druid-specific timing hooks.

### Story 8 — Texture selection is easy to scan

As a user, I want texture choices in a dropdown list with clear category labels so I can pick a texture quickly without browsing a separate window.

Acceptance criteria:

- Texture rows display as `[category] label`.
- SharedMedia and Blizzard entries are included.
- The selected label updates when a texture is chosen.
- No browser popup is required.

### Story 9 — Texture layers are fully exposed

As a user, I want the texture layer selector to show every supported layer so I can match the addon visuals to my UI setup.

Acceptance criteria:

- All supported draw-layer values appear in the selector.
- Bar texture and spark texture layers can be changed independently.
- Weave spark and triangle layers can be changed independently.
- Layer changes update previews and live bars.

### Story 10 — Config changes persist and preview live

As a user, I want texture, layer, alpha, and size changes to preview immediately and persist after reload so the addon feels dependable.

Acceptance criteria:

- Preview bars update when settings change.
- SavedVariables keep the selected media and layer values.
- Reloading the UI preserves the chosen values.
- Config controls stay readable and usable.

### Story 11 — Fallback behavior works without SharedMedia

As a user, I want the addon to still offer textures when SharedMedia is unavailable so the config never becomes empty.

Acceptance criteria:

- Blizzard fallback entries are always available.
- SharedMedia entries appear only when the library exists.
- The selector remains functional without external media packs.

### Story 12 — Diagnostics remain clean for publication

As a maintainer, I want the edited files to pass targeted diagnostics so we can ship without known lint regressions.

Acceptance criteria:

- Targeted `get_errors` is clean for the edited Lua files.
- No new warnings are introduced in the planning scope.
- The plan documents all live dependencies and validation gates.

### Story 13 — Release documentation stays synchronized

As a maintainer, I want `README.md`, `CHANGELOG.md`, `SuperSwingTimer.toc`, and `docs/SharedMedia.md` to reflect the same behavior as the code so the addon is actually publish-ready.

Acceptance criteria:

- `README.md` describes the current `/sst` behavior and class support.
- `CHANGELOG.md` reflects the current release scope.
- `SuperSwingTimer.toc` reflects the current metadata and file load order.
- `docs/SharedMedia.md` matches the texture dropdown source used by the config UI.

### Story 14 — Hidden-file diagnostics surface regressions

As a maintainer, I want errors from unopened files to surface in diagnostics so bugcatcher-style tooling does not miss regressions that are not on screen.

Acceptance criteria:

- The diagnostic surface includes the full shipping file set, not only the open editor file.
- Errors in core files and release-facing files are visible without opening each file manually.
- The plan describes how unopened-file errors are checked and recorded.

## Success criteria

- Main-hand swing timing remains reliable under repeated landed swings.
- Ranged timing remains unchanged.
- Weave breakpoints follow cast timing and haste in real time.
- The weave spark is cast-only.
- The texture dropdown is complete, categorized, and browser-free.
- Release-facing docs and metadata match runtime behavior.
- Diagnostics surface unopened-file regressions instead of hiding them.
- The feature plan contains enough detail to drive atomic implementation work.

## Constraints

- Keep Classic/TBC compatibility.
- Preserve the current bar layout and addon identity.
- Keep overlay behavior separate from timing state.
- Avoid half-implementations; plan the work so each subsystem can be validated independently.
