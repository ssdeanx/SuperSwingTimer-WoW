# Progress

## Progress Update (2026-04-29 - hunter cast bar and TBC spell IDs)

- Added a dedicated Hunter Auto Shot / Multi-Shot cast bar beneath the ranged timer and wired it to the ranged bar's texture, spark settings, and visibility rules.
- Fixed the Classic spellcast handler signatures so the 3-argument `UNIT_SPELLCAST_*` payloads populate the hunter cast state correctly.
- Synced the TBC Multi-Shot ranks and Slam ranks 5-6 into the addon tables and `docs/swingtimer.md`, then bumped the addon metadata and release notes to `v3.1.7`.

## Progress Update (2026-04-29 - texture catalog and browser polish)

- Reworked the texture catalog so MH/OH and ranged rows now stay on bar-style textures from Blizzard, SharedMedia, WeakAuras, and installed addon packs instead of showing the entire generic texture list.
- Switched the spark and shaman weave spark rows to folder-style browse buttons with the WeakAuras browse icon, restored the spark alpha slider, and kept the `Square_FullWhite` / `Normal` default behavior intact.
- Refreshed README, changelog, UI docs, and SharedMedia notes so the release-facing documentation matches the new picker behavior.

## Progress Update (2026-04-29 - spark picker final polish)

- Reworked the spark texture row into a dedicated thumbnail browser so the default `Square_FullWhite` preset now presents as `Normal` and the picker feels closer to the WeakAuras texture browser.
- Cleaned up the spark row labels and tooltip copy for the final release pass, and kept the shaman weave default on `Target Indicator`.
- Refreshed the README, changelog, TOC, and texture/UI docs so the release-facing wording matches the polished browser and default labels.

## Progress Update (2026-04-28 - ranged safe-state and WeakAuras bridge)

- Added a green-safe hunter ranged cast-window state so the red zone now turns green when you stop before the breakpoint and only stays red when you are still moving too late.
- Kept the existing latency-aware breakpoint math intact while refreshing the ranged movement feedback and immediate overlay updates on movement start/stop.
- Refreshed `README.md`, `CHANGELOG.md`, `SuperSwingTimer.toc`, `docs/swingtimer.md`, and `docs/WeakAuras/Expert-Patterns.md` so the addon docs, metadata, and WeakAuras bridge example match the new behavior.

## Progress Update (2026-04-27 - dropdown interaction and spark refresh cleanup)

- Improved the dropdown UX so cycle and texture rows open from the whole row instead of only the small control area.
- Removed the unused texture-browser popup implementation to keep the config code aligned with the actual dropdown UI.
- Cleared spark anchors before each update so the moving overlays do not accumulate stale points.
- Added subtle hover highlights to the interactive rows so users can spot the clickable controls faster.
- Enabled mouse interaction on the texture rows so the new hover and click-open behavior is actually reachable.
- Added hover tooltips to the config rows and controls so the panel explains what each setting means when hovered.

## Progress Update (2026-04-27 - overlay frame and UI control refit)

- Reworked the bar visual path so overlay textures are parented to dedicated non-mouse frames above the bars, eliminating the hover-sensitive HIGHLIGHT fallback that was making the hunter spark appear and disappear.
- Updated the `/sst` config to use visible dropdowns for cycle settings and editable numeric fields beside sliders.
- Synced the README and UI notes to match the new control layout and overlay-frame strategy.

## Progress Update (2026-04-27 - hunter spark / breakpoint visibility fix)

- Fixed the fill-vs-overlay layering bug that could bury the hunter Auto Shot spark and the shaman / ret paladin breakpoint markers behind the bar skin.
- Updated the config subtitle copy so it tells players to hover for help and then use the right-side controls to change settings.
- Recorded the fix in `CHANGELOG.md` as a 3.1.3 entry so the visibility regression is tracked for the next release.

## Progress Update (2026-04-24 - breakpoint overlays above bar fill)

- Added a shared above-bar texture-layer helper so breakpoint visuals stay visible even when the bar texture layer is raised.
- Rewired the shaman weave spark, triangles, the ranged cast-threshold marker, and the ret paladin seal breakpoint lines to use that above-bar layering path.
- Updated shaman weave positioning to use the actual MH bar width instead of only the static default width.
- Synced README.md and CHANGELOG.md with the above-bar breakpoint behavior; the TOC already carries v3.1.2.

## Progress Update (2026-04-24 - final paladin seal coverage)

- Expanded the paladin seal family lookup to cover every seal and spell ID listed in `docs/spellIds.md`.
- Restored the ret paladin breakpoint line so the actual strike-edge marker stays visible again, with a second latency-aware reseal marker for twist seals, still UnitAura-aware and black.
- Anchored Hunter Auto Shot cooldown start to the addon’s latency-adjusted clock so the cooldown API and the ranged bar share the same time base.
- Re-reviewed the shaman weave-assist and melee white-damage reset/start flow; no extra logic changes were required in this pass.

## Progress Update (2026-04-23 - final hunter/paladin polish pass)

- Anchored Hunter Auto Shot to the cooldown API start time when active, keeping the ranged timer tied to the API instead of only the event timestamp.
- Hardened the paladin seal breakpoint lookup so aura names win first, verified IDs still work, and missing rank IDs do not break the seal line.
- Re-reviewed the shaman weave-assist and melee white-damage reset/start flow; no extra logic changes were required in this pass.
- Synced the changelog and repo notes with the final accuracy pass.

## Progress Update (2026-04-23 - hunter cooldown API and paladin polish)

- Hunter Auto Shot now uses the Auto Shot cooldown API when active, with ranged weapon speed coming from `UnitRangedDamage()` as the fallback timing source.
- Added `SPELL_UPDATE_COOLDOWN` handling so the hunter ranged bar can start/resync as soon as the cooldown changes.
- Kept the ret paladin seal breakpoint line UnitAura-aware, latency-aware, and opaque black.
- Synced the README, API notes, changelog, TOC, and memory bank with the new timing model.

## Progress Update (2026-04-23 - config reflow and seal-twist timing pass)

- Reflowed the `/sst` config so labels sit above the controls, and the texture, cycle, toggle, and color rows are much easier to click.
- Made the ret paladin seal-twist overlay latency-aware by expanding the fixed 0.4s window with cached latency.
- Updated the README and changelog to match the revised UI wording and timing notes.
- Hunter validation is still the last live test step.

## Progress Update (2026-04-23 - hunter Auto Shot test-ready)

- Hunter Auto Shot now has a latency-aware black threshold marker, deduped restart logic, and a dedicated ranged texture path.
- The `/sst` layout now clearly separates MH/OH, ranged, and weave settings.
- Hunter validation is the remaining live test step before moving on to seal-twist follow-up.

## Progress Update (2026-04-23 - hunter Auto Shot marker and ranged texture split)

- Added a latency-aware hunter Auto Shot red-zone marker so the cast window shows up before the bar turns red.
- Added a dedicated ranged bar texture selector and split the appearance labels for MH/OH versus ranged control.
- Widened the `/sst` panel for clearer spacing and revalidated the updated docs/memory notes.

## Progress Update (2026-04-23 - Blizzard options, class colors, and preview polish)

- Registered Super Swing Timer in Blizzard's Interface Options / AddOns flow and added TOC icon metadata.
- Replaced the old `/swangthang` path with the primary `/sst`, `/super`, and `/superswingtimer` aliases.
- Made the default MH / OH / ranged bars follow the player's class color, with a `Use Class Colors` toggle for explicit control.
- Added an `Indicator Glow Mode` control for bright glow versus opaque blend behavior on sparks and weave markers.
- Reworked the texture dropdown into a preview-based picker and widened the `/sst` config panel with clearer labels and spacing.
- The spark row now opens a dedicated thumbnail browser for the Normal `Square_FullWhite` preset, while bar/ranged textures stay on compact preview dropdown rows.
- Revalidated the touched runtime Lua files with targeted diagnostics; they are clean.

## Progress Update (2026-04-23 - weave family controls and UI polish)

- Added color-coded, individually disable-able weave-family toggles for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal.
- Shrunk and renamed the weave marker controls so the upper/lower pair reads more clearly in `/sst`.
- Widened the `/sst` panel and added a clearer weave-family legend block.
- Targeted diagnostics on the edited runtime files are clean after the weave/UI pass.

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
