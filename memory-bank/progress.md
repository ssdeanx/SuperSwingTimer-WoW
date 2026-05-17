# Progress

## Progress Update (2026-05-17 - v0.0.6 Rogue Slice and Dice completion)

- Added a Rogue-only Slice and Dice duration helper above the MH bar, driven by `UnitAura("player", ..., "HELPFUL")` plus real-time expiration tracking so the bar appears only while the buff is active and stays wired into the existing bar texture/border/background/color refresh paths.
- Added SavedVariables defaults, migration, `/sst` Quick Controls toggle/color wiring, docs, and v0.0.6 metadata for the new Rogue helper, and slimmed the derived OH stock profile down to 8px while keeping the SnD helper on a 3-4px height.

## Progress Update (2026-05-17 - rogue helper polish follow-up)

- Polished the Rogue Sinister cue so its stock alpha is softer by default, it still updates live from the saved color swatch, and the fallback display path softens that tint a little further when the cue is only using weapon-speed preview instead of an active swing.
- Fixed the Rogue energy helper orientation so the slim vertical bar fills upward again, and clarified the existing `/sst` Rogue checkbox label to `Rogue Energy Helper`.

## Progress Update (2026-05-17 - release polish ui follow-up)

- Hardened the `/sst` config shell for release by adding an optional `BackdropTemplate` helper, mouse-wheel scrolling on the main config panel, a slightly larger texture-browse click target, and dynamic post-Quick-Controls section spacing so class-specific quick rows no longer collide with the next header.
- Re-audited live bar visibility during the same pass and kept the combat-only out-of-combat behavior intact; the UI/docs now explicitly distinguish `/sst` preview mode from live combat-driven bars.

## Progress Update (2026-05-17 - visibility correction follow-up)

- Corrected the normal bar visibility regression: gameplay bars are combat-only again, and hidden or idle MH/OH/ranged/enemy bars now reset to an empty state so combat entry does not show stale full fills before a real timer starts.

## Progress Update (2026-05-17 - active-timer visibility follow-up)

- Fixed the broader visibility issue behind the Rogue reports: MH/OH/enemy bars now follow the same active-timer visibility model as ranged, and timer start/reset now refreshes shared visibility immediately instead of waiting for a separate combat/UI event.

## Progress Update (2026-05-17 - rogue combat visibility fix)

- Fixed the likely Rogue root cause where melee bars sometimes stayed hidden until another event refreshed visibility: the shared combat visibility path now uses an explicit regen-event combat flag instead of depending only on `InCombatLockdown()` timing.

## Progress Update (2026-05-17 - rogue cue consistency follow-up)

- Fixed the intermittent Rogue cue visibility issue by letting the SS helper fall back to the live MH weapon speed whenever the MH bar is visible, instead of hiding the cue unless a live MH swing timer is already running.

## Progress Update (2026-05-17 - all-classes final polish)

- Fixed the Hunter Multi-Shot regression for BC Classic/TBC behavior by seeding the dedicated hunter helper bar from stored success/start state even when Classic does not expose a live cast through `UnitCastingInfo()`.
- Kept the Rogue Sinister cue under the shared spark layer so the spark stays visible through the red end-window slice instead of getting buried by the overlay.

## Progress Update (2026-05-16 - hunter startup and visibility hardening)

- Hardened Hunter startup/visibility: auto-repeat now seeds ranged timing immediately, cooldown updates refresh shared visibility, and combat-entry bar showing now routes through `ApplyVisibility()` instead of force-showing ranged bars.

## Progress Update (2026-05-16 - config open-path hardening)

- Hardened the `/sst` open path: lazy panel re-init, pure texture-backed quick swatches, and guarded color-row refresh before show so the config panel cannot be blocked by a bad quick-color row.

## Progress Update (2026-05-16 - config row interaction hardening)

- Hardened the `/sst` row click helpers so clicks on the actual right-side button/toggle/dropdown no longer double-trigger through the parent row.

## Progress Update (2026-05-16 - config swatch bugfix)

- Fixed the broken `/sst` color selector buttons by switching them to plain `BackdropTemplate` preview tiles with a visible gray base, which restores the missing-but-clickable swatches and Hunter/class quick colors.

## Progress Update (2026-05-16 - config color swatch readability follow-up)

- Reworked the `/sst` color selector buttons to use flatter high-contrast preview tiles so the chosen bar colors show much more clearly in the config UI.

## Progress Update (2026-05-16 - final fit-and-finish quick-controls, Rogue test bar, and spark polish)

- Tightened the top `/sst` Quick Controls spacing so the Rogue/Hunter two-column quick rows no longer overlap in the live panel.
- Resized the Rogue test energy helper to a 5px-wide vertical bar that matches the visible melee-bar heights instead of spanning the inter-bar gap.
- Polished the thin stock spark by pixel-snapping the fill-edge anchor and adding a tiny forward bias so it reads closer to the live edge on the 15px/10px bar profile.

## Progress Update (2026-05-16 - final pre-test Rogue energy tick and slimmer defaults)

- Changed the stock live profile so the main shared bars now default to 15px, the OH bar derives to 10px, and the default spark height follows the slimmer main-bar profile while still clamping to each host bar.
- Added a Rogue-only test vertical energy-tick helper to the left of the MH/OH stack, driven by `UnitPower("player")` plus Rogue-only `UNIT_POWER_UPDATE` / `UNIT_POWER_FREQUENT` hooks and observed natural energy gains, without disturbing the aligned swing clock.
- Added `/sst` quick-control toggle/color wiring, migration/reset defaults, and release/doc updates for the new Rogue energy tick helper.

## Progress Update (2026-05-16 - v0.0.5 rogue cue and quick-controls)

- Reworked the top of `/sst` into a two-column Quick Controls section so visibility toggles sit on the left while the primary bar-color swatches sit on the right.
- Moved the most-used bar colors to that top section and kept the class-specific quick colors conditional, including Hunter Auto Shot safe/unsafe colors, the enemy bar color, the Rogue Sinister cue color, and the Paladin seal line where relevant.
- Added a Rogue-only latency-adjusted red end-window overlay on the MH bar so players can press Sinister Strike into the end of the swing and more reliably land it immediately after the main-hand hit.
- Added `showRogueSinisterAssist` defaults/migration/reset support plus a dedicated Rogue cue color, and wired the overlay into the existing bar-color, size, visibility, minimal-mode, and layer-refresh paths.
- Hid the shaman weave section on non-shaman classes so the config panel stays cleaner during production use.

## Progress Update (2026-05-15 - v0.0.4 enemy bar and spark sync)

- Added the new enemy target bar end-to-end: defaults/migration in constants/bootstrap, enemy timer state in `SuperSwingTimer_State.lua`, a draggable/shared-style enemy frame in `SuperSwingTimer_UI.lua`, and `/sst` toggle/color/reset support in `SuperSwingTimer_Config.lua`.
- Wired enemy tracking to current Classic/TBC-safe APIs and events: `PLAYER_TARGET_CHANGED`, `UnitGUID("target")`, `UnitAttackSpeed("target")`, and hostile target `SWING_DAMAGE` / `SWING_MISSED` via `CombatLogGetCurrentEventInfo()`.
- Tightened hunter ranged timing by anchoring active Auto Shot live resync back to the cooldown API start when `GetSpellCooldown(75)` is available, instead of only rescaling duration.
- Moved cached latency off the shared base timer clock so swing motion stays on a `GetTime()`-aligned `GetTimePreciseSec()` / `GetTime()` path while latency remains on predictive windows like Auto Shot safe-stop timing and weave clip math.
- Added `Auto Shot Safe Color` / `Auto Shot Unsafe Color` UI swatches so hunters can tune the red/green ranged feedback without changing the base ranged bar color; the existing `Enemy Color` swatch continues to drive the current-target enemy bar.
- Fixed the shared visibility pass so MH/OH/enemy bars stay hidden out of combat during normal play even if config/equipment apply paths call `ns.ApplyVisibility()`.
- Fixed Test Bars cleanup so preview end now restores `ns.ApplyVisibility()` instead of forcing every bar fully hidden.
- Improved shaman weave smoothness by keeping the breakpoint marker locked to the full cast-time-plus-latency start point and replacing the old triangle textures with the tracked spell's small icon.
- Re-audited the remaining timing paths against Warcraft Wiki and kept the final clock split on purpose: the shared swing clock is now raw, while direct `UnitCastingInfo` / `UnitChannelInfo` timestamp reads remain raw and cached latency is applied only where the gameplay model needs prediction.
- Fixed spark drift by centralizing spark positioning on the actual rendered fill edge and changed the stock spark width default to 3px, with migration logic that only rewrites untouched old 4px defaults.
- Synced `SuperSwingTimer.toc`, `README.md`, `CHANGELOG.md`, `docs/APIS.md`, `docs/UI.md`, `docs/swingtimer.md`, `AGENTS.md`, and the memory-bank notes to the requested v0.0.4 release update.

## Progress Update (2026-05-05 - bar texture picker final UI polish)

- Replaced the compact MH/OH and ranged texture dropdowns with a scrolling full-preview bar-texture picker that keeps each texture visible behind its label and removes the old paged submenu path.
- Kept the list focused on bar media only by using Blizzard fallback textures plus LibSharedMedia-registered statusbars from installed media packs, while leaving the spark and weave-spark pickers on the thumbnail browser.
- Synced the README/UI/SharedMedia notes and the combined 3.1.26 changelog entry to the new picker behavior.

## Progress Update (2026-05-05 - final release prep timing and UI pass)

- Restored BCC Anniversary `UNIT_SPELLCAST_*` handling to the `unit, castGUID, spellID` payload path across `SuperSwingTimer_State.lua`, `SuperSwingTimer_ClassMods.lua`, and `SuperSwingTimer_Weaving.lua`, which should bring spell-driven timer reset/pause/queue behavior back after the bad spell-name regression.
- Kept the live timer model on latency-adjusted `GetTimePreciseSec()` / `GetTime()`, primed the precise clock once, and restored MH/OH/ranged starts, queued next-attack landed resets, parry haste, and druid form resets to that existing live clock after the CLEU remap caused early-leading timers.
- Preserved Hunter's core ranged behavior while keeping the hidden cast bar locked to the same end-of-cycle stop-to-fire window as the red/green ranged feedback.
- Fixed the MH/OH config spacing so the `Bar Width` slider no longer overlaps the section header collapse toggle.

## Progress Update (2026-05-05 - class-local next-attack refactor)

- Removed the shared queued next-attack state and split Warrior Heroic Strike / Cleave, Druid Maul, and Hunter Raptor Strike onto fully class-local queue state.
- Removed the shared next-attack landed-hit lookup path and now reset MH only from the active class spell tables.
- Changed Druid Maul to a distinct bear-yellow tint so it no longer visually matches Warrior Heroic Strike, while keeping queued tint scoped to the MH fill only.

## Progress Update (2026-05-04 - stale account-wide class-color cleanup)

- Added a one-time migration that resets stale class-colored MH/OH/ranged manual palettes back to black when class colors are off and all three bars still exactly match one WoW class color.
- Added matching spark-color cleanup so stale class-colored spark values are restored to white in that same broken-save scenario.
- This specifically addresses old druid-colored SavedVariables bleeding into Warrior on account-wide saves.

## Progress Update (2026-05-04 - warrior/druid queue tint split)

- Split queued-melee tint ownership so Warrior Heroic Strike / Cleave and druid Maul no longer share one generic pending queue state.
- Removed the generic NMA pending-tint write from the shared spellcast-success path and kept queued-tint ownership inside the class-mod layer where it belongs.
- Added safer queued-tint cleanup on world/combat reset and interruption paths.

## Progress Update (2026-05-04 - class-color and spark visual fix)

- Fixed the class-color toggle so enabling it no longer overwrites the stored MH/OH/ranged manual colors.
- Turning class colors off now restores the saved manual bar colors, and older saved bar/spark colors that still match the class color can be cleaned back to defaults.
- Changed the main swing spark to a color-preserving blend mode so white/manual spark colors stay visually accurate instead of warming from the bar fill underneath.

## Progress Update (2026-05-04 - final production polish and corrective pass)

- Rechecked current Classic/TBC API and addon patterns with live web/GitHub search before patching the remaining class and UI issues.
- Narrowed the hunter work back to the Auto Shot cast-bar fix only: kept the hidden-window stabilization and visual-only red-zone clamp, but restored the broader ranged start/restart behavior so the live ranged timer keeps its prior path.
- Corrected ret paladin reseal marker math to use swing elapsed + remaining GCD time.
- Routed shaman weave spell resolution through `ns.GetSpellInfo` and stopped weave overlays from reappearing while Minimal Mode or the weave toggle is off.
- Hardened UI/setup behavior by reusing the OH frame across equipment changes, adding real drag handlers to the anchor bars, forcing Test Bars / config preview visible after `ApplyVisibility()`, and restoring saved positions during Reset Defaults.
- Updated README, CHANGELOG, TOC metadata, API/UI notes, AGENTS, and memory-bank context to match the final code behavior.

## Progress Update (2026-05-04 - spark tint follow-up and hunter cast-bar stabilization)

- Fixed the shared spark-color path so `Use Class Colors` no longer recolors the spark; Heroic Strike, Cleave, and Maul remain MH-fill-only queue tints.
- Stabilized the Hunter Auto Shot hidden cast bar by locking it to one hidden-window anchor per ranged cycle instead of re-deriving it from the movement-pinned ranged timer every frame.
- Stopped the UI/state hunter fallback paths from writing persistent synthetic Auto Shot cast state outside the hidden-window path, which should reduce random cast-bar activations.
- Hardened interrupted / failed Maul cleanup by falling back to the druid queue-tint clear path when appropriate.
- Updated README, CHANGELOG, TOC metadata, API/UI notes, AGENTS, and memory-bank context to match the live code behavior.

## Progress Update (2026-05-01 - TBC Anniversary Compatibility & Hunter Sync)

- Achieved full TBC Classic Anniversary (1.15.x) engine support by implementing a robust `ns.GetSpellInfo` wrapper and safe-accessing Blizzard UI globals via `_G`.
- Synchronized the dedicated Hunter cast bar with the ranged timer's latency-aware "red zone."
- Optimized the configuration UI with 20-item paging and texture previews.
- Hardened default settings: Class Colors: OFF for better visibility.
- Updated all project documentation and bumped version to v3.1.17.

## Progress Update (2026-04-30 - final reset-state bug polish)

- Added hunter cast-state cleanup to ranged reset paths (`ResetTimer("ranged")`) so hidden cast-bar state cannot persist after ranged stop/reset transitions.
- Synced changelog/AGENTS/memory context for this final hook/event state hardening fix.

## Progress Update (2026-04-30 - hunter stop-to-fire window hardening)

- Reworked hunter cast-bar display logic so it can derive from the end-of-ranged-cycle hidden cast window (`windowEnd - ns.CAST_WINDOW`) instead of relying only on cast events.
- Hardened hunter `HandleSpellcastSucceeded` fallback to avoid creating synthetic post-shot cast windows when no active cast is detected.
- Synced changelog/README/AGENTS/memory context to the refined hunter stop-to-fire semantics.

## Progress Update (2026-04-30 - broad audit and hunter fallback correction)

- Ran a broader smell/audit pass using the project API reference list (`docs/urls.md`) and external API checks for `GetRangedHaste`, `UnitSpellHaste`, and `UnitRangedDamage` signatures.
- Found and fixed one concrete bug: hunter cast fallback in `HandleSpellcastSucceeded` now seeds start time with `now` (not `now - CAST_WINDOW`) so the cast bar does not auto-complete instantly when start events are missed.

## Progress Update (2026-04-30 - release hardening haste fallback pass)

- Added hunter ranged-speed fallback estimation driven by `GetRangedHaste`/`GetHaste` when `UnitRangedDamage()` is missing, and wired it into ranged timer rescaling.
- Added shaman weave spell-haste fallback from `UnitSpellHaste("player")` to `GetSpellHaste()`.
- Updated changelog with `3.1.16` release-hardening notes and synced AGENTS/memory context.

## Progress Update (2026-04-30 - follow-up polish pass)

- Refined hunter hidden cast-window timing to cast/shot start anchoring while keeping the cast bar fixed to `ns.CAST_WINDOW`.
- Updated the hunter `UnitCastingInfo` fallback to start-time alignment for cleaner cast-bar behavior.
- Added player-only guards to `UNIT_ATTACK_SPEED` and `UNIT_RANGEDDAMAGE` event handlers before forcing speed resync.
- Updated changelog to `3.1.15` for this follow-up polish pass.

## Progress Update (2026-04-30 - hunter cast-window separation and timer-start polish)

- Reworked hunter cast-bar timing so it no longer mirrors full ranged duration and now always uses fixed `ns.CAST_WINDOW` timing.
- Updated both state and UI hunter timing paths to align cast-window start to end-of-cast data when available.
- Added immediate speed synchronization on swing start for melee and ranged timers to reduce startup drift.
- Updated `CHANGELOG.md` with `3.1.14` notes for this timing pass.

## Progress Update (2026-04-30 - state/class timing polish after State.lua rejection)

- Re-validated and patched `SuperSwingTimer_State.lua`: removed the duplicate `ResetTimer` implementation and kept a single canonical idle-reset path.
- Added/exported `ns.ClearHunterCastState` and invoked it on `PLAYER_ENTERING_WORLD` and `PLAYER_REGEN_ENABLED` reset paths to avoid stale hunter cast state.
- Hardened hunter cast-bar detection in `SuperSwingTimer_UI.lua` so Classic spellcast payloads that expose spell names but not IDs still resolve hunter cast spells correctly.
- Fixed shared color mutation in `SuperSwingTimer_Weaving.lua` by copying family colors before applying safe/unsafe alpha changes.
- Polished `SuperSwingTimer_ClassMods.lua` paladin twist markers so the end-of-swing strike marker remains visible while a separate GCD-aware reseal marker is maintained.
- Updated `CHANGELOG.md` with a new `3.1.13` entry covering this final polish pass.

## Progress Update (2026-04-29 - final release polish pass)

- Unified the hunter Auto Shot / Multi-Shot cast bar on `ns.CAST_WINDOW` instead of a second 0.5-second constant, and added a `UnitCastingInfo` fallback so the dedicated cast bar has a cleaner recovery path.
- Fixed warrior queue tint scanning so only numeric queued-spell IDs are polled, which makes Heroic Strike and Cleave more reliable while Slam keeps its pause/extend behavior.
- Increased the unlocked drag hit area so the bars are easier to grab and move during setup.
- Reworked the README into a more professional project page with at-a-glance tables, a timing-model table, a texture-source table, and a markdown note about keeping CurseForge pages table/image friendly instead of relying on Mermaid.

- Switched the hunter Auto Shot / Multi-Shot bar to separate active-state logic so the cooldown preview survives the generic stop event and can expire on its own timing.
- Added a temporary `/sst` Test Bars action, a clearer `Lock / Unlock Bars` control, and alpha-enabled color swatches for the main bar palette.
- Bumped the addon metadata to `v3.1.10` and refreshed the changelog, README, UI notes, and memory bank to match the final polish pass.

## Progress Update (2026-04-29 - final hunter cast-bar and collapsible section polish)

- Restored the base spark width to 4px and aligned the default spark tint with the ranged class color when class colors are enabled.
- Added stored hunter cast timing so the Auto Shot / Multi-Shot cast bar can render even when the live casting API is sparse.
- Restored the `/sst` panel so its collapsible sections use stable row groups again, which keeps the config content visible and functional.
- Slimmed the spark and weave defaults to compact bar-height-aligned markers so the glow no longer balloons into a huge white block, and added a hunter cast-bar test preview so the frame can be repositioned more easily.
- Tightened the Hunter cast bar so it is cast-only and only appears while Auto Shot or Multi-Shot is actively being cast.
- Kept the update loop alive for channeling by treating `ns.channeling` as an active-timer state, which preserves ranged channel animations even without a swing timer.
- Added collapsible `/sst` section headers for the main config groups to make the panel easier to scan and closer to the WeakAuras-style section workflow.
- Synced `docs/UI.md`, `CHANGELOG.md`, and the memory bank with the final release polish pass.

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
