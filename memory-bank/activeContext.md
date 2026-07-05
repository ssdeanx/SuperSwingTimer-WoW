# Active Context

## Active Context Update (2026-07-05 - Global Scale slider + deep quality audit)

- **Deep quality audit completed**: Created `AUDIT.md` with 10-section scoring (overall 7.2/10). Identified critical issues: `ns.OnUpdate` chain fragility, fresh-install block duplication, zero test infrastructure, 8 Hunter bar globals suppressed in `.luacheckrc`, and missing global scale slider.
- **Global Scale slider implemented**: Added `globalScale = 1.0` to `ns.DB_DEFAULTS`, `ns.GetGlobalScale()` (0.5x–3.0x clamped range), `ns.Scale()` helper function. Modified `CreateBar()`, `ApplyBarSize()`, `ApplyBarBorderSize()`, and `CreateGcdTickerBar()` to apply scale internally. Added `ns.ApplyGlobalScale()` that refreshes all 6 classes' helpers after scale change. Placed slider as **first control** at top of `/sst` panel with gold label + descriptive subtitle. Quick Controls shifted down by slider height. Fresh-install, migration nil-guard, reset defaults, and panel refresh all wired.
- **Scale formula**: `finalSize = math.floor(savedValue × scale + 0.5)`, min 1px. Individual sliders set base size, global scale multiplies everything proportionally.
- **`get_errors` clean**: All edited files (Constants, SuperSwingTimer, UI, Config) pass diagnostics.
- **Known follow-up**: 8 Hunter bar globals still need `ns.*` migration, `ns.OnUpdate` chain needs registration pattern.

## Active Context Update (2026-06-17 - Hunter buff icon redesign + Shaman buff icon group)

- **Hunter buff icons redesigned**: Removed the dim/shading overlay from `ns.UpdateHunterBuffIcons()`. Added gold glow (`icon.glow`) with ADD blend mode that pulses between 0.15-0.55 alpha during the last 4 seconds of any tracked buff/CD. Added racial ability tracking (Blood Fury, Berserking, Stoneform, Shadowmeld, War Stomp, Gift of the Naaru). Buff group Y offset raised from 4 to 9 (+5px).
- **Shaman buff icons implemented**: Created full buff/CD tracking system for Shaman in `SetupEnhShaman()` — `SHAMAN_TRACKED_SPELLS` (Shamanistic Rage, Heroism, Stormstrike, Flurry, Windfury Weapon, Elemental Devastation, racials), `CreateShamanBuffIcons()`, `ns.UpdateShamanBuffIcons()` with gold glow matching the hunter pattern. Wired into the Shaman OnUpdate chain. Config toggle "Buff Icons" + "Buff Icon Size" slider added to config panel.
- **DB/migration**: `showShamanBuffIcons = true`, `shamanBuffIconSize = 25` added to `ns.DB_DEFAULTS`. Migration guard added in `MigrateDB()`. Reset defaults in Config.
- **Quality gates**: luac syntax OK, luacheck 0 warnings 0 errors on all 7 files. TOC bumped to v0.1.4, CHANGELOG updated.

## Active Context Update (2026-06-01 - class-init fail-open hardening)

- User reported class-level no-show risk (Shaman bars not showing) and asked for a pass to ensure other classes cannot hit the same failure mode.
- Implemented class-wide fail-open init wrapper in `ns.InitClassMods()` so class helper init errors do not suppress core bar visibility.
- Applied across Paladin, Warrior, Rogue, Hunter, Shaman, and Druid setup dispatch.
- Kept targeted Shaman helper fallback cleanup in the SHAMAN branch.

## Active Context Update (2026-05-31 - final class audit)

- User requested a last pre-test audit for all class runtime paths (Warrior, Hunter, Rogue, Shaman, Druid) and asked for any failures or bug risks to be recorded.
- Completed a file-by-file review of the live class blocks in `SuperSwingTimer_ClassMods.lua` plus the supporting state/weave/UI hooks.
- Audit result: no new crash-level blocker was found in the class code; the remaining confidence gap is in-game smoke validation of class-specific overlays and combat-state transitions, not a known code defect.
- No version bump; addon remains locked to `v0.1.2` for final testing.

## Active Context Update (2026-05-31 - timing clock cleanup)

- User asked to audit `GetTimePreciseSec()` usage and fix the remaining clock code smells.
- Result: the last inline fallback smell in live runtime code was normalized. `SuperSwingTimer.lua` and `SuperSwingTimer_Config.lua` now route through shared local clock helpers instead of repeating `GetTimePreciseSec() or GetTime()` inline, and the matching hidden worktree UI copy was aligned as well.
- No version bump; addon remains locked to `v0.1.2` for final testing.

## Active Context Update (2026-05-31 - broader non-ClassMods alias sweep)

- User explicitly requested a file-by-file audit beyond `ClassMods.lua`.
- Completed the core non-ClassMods runtime audit across `SuperSwingTimer.lua`, `SuperSwingTimer_State.lua`, `SuperSwingTimer_Weaving.lua`, `SuperSwingTimer_UI.lua`, and `SuperSwingTimer_Config.lua`.
- Audit result: the remaining files were already using Blizzard-style API aliases consistently; the only actual leftover lower-case legacy cooldown fallback was removed from `SuperSwingTimer_State.lua`, so the core runtime is now consistent on that front.
- No version bump; still locked to `v0.1.2` for final testing.

## Active Context Update (2026-05-31 - alias consistency audit)

- User requested a beast-mode audit for alias consistency and correct Blizzard naming practices across all Lua files.
- Audit result: the spell-API local aliasing now consistently uses `C_Spell` in runtime code; the prior `cSpell` spelling was just inconsistent naming, not a separate API.
- Performance note: using one local alias per file is fine; the important production practice is to avoid repeated global table lookups in hot paths.
- No version bump; still locked to `v0.1.2` for final testing.

## Active Context Update (2026-05-31 - warrior Overpower glow hardening)

- User asked why alias spelling varied and requested enterprise-grade consistency.
- Normalized remaining runtime spell-API alias usage to `C_Spell` in the class-mod runtime so the naming is consistent and easier to maintain.
- Improved Warrior Overpower feedback to a pulsing border glow on the MH bar, using the already-tracked proc window from combat events, so the proc cue is more visible without filling the bar.
- No version bump; the addon is still locked to `v0.1.2` for final testing.

## Active Context Update (2026-05-31 - shaman cast-motion final hardening)

- User requested enterprise-grade final hardening for Shaman weave motion and Flame Shock warning UX.
- Implemented live cast timing preference in `SuperSwingTimer_Weaving.lua`:
  - current cast motion now follows `UnitCastingInfo("player")` / `UnitChannelInfo("player")` timestamps first;
  - haste-adjusted spell timing is used only as fallback when live timestamps are unavailable;
  - spark/triangle weave visuals were moved to a higher dedicated overlay frame above the bars for visibility.
- Implemented Flame Shock warning in `SuperSwingTimer_ClassMods.lua`:
  - bar remains aura-driven/countdown-driven;
  - border glow activates only in the last 4 seconds and resets cleanly when the aura disappears.
- Release metadata remains locked to `v0.1.2` until the user’s final validation passes.

## Active Context Update (2026-05-31 - user-blocking config UI fixes)

- User reported two blocking production issues after prior pass: invisible slider tracks and texture browser rendering behind UI.
- Applied hard fixes in `SuperSwingTimer_Config.lua`:
  - slider track now uses a dedicated row child frame (`trackLayer`) with explicit frame levels and ARTWORK textures, anchored to slider bounds for deterministic visibility;
  - texture browser now forces `FULLSCREEN_DIALOG`, `SetToplevel(true)`, and reasserts frame level + `Raise()` on show to stay above panel stack.
- Kept release metadata on `v0.1.2` for final validation.

## Active Context Update (2026-05-31 - final v0.1.2 pre-test lock-in)

- User requested a production-grade final pass before testing and explicitly required no premature version bump.
- Implemented global slider track visibility fix in `SuperSwingTimer_Config.lua` by rendering shared row-owned track textures in the common slider builder (`CreateLabeledSliderRow`), covering all slider instances.
- Performed focused Shaman deep audit across runtime layers:
  - `SuperSwingTimer.lua`: verified SHAMAN event wiring for `UNIT_SPELLCAST_*`, `UNIT_AURA`, `PLAYER_TARGET_CHANGED`, `SPELLS_CHANGED` and hand-off to weave/flame-shock/lightning visual updates.
  - `SuperSwingTimer_State.lua`: verified spellcast payload safety path that rejects castGUID-as-spell fallback.
  - `SuperSwingTimer_Weaving.lua`: verified highest-known-rank spell selection and cast-progress display inputs.
  - `SuperSwingTimer_ClassMods.lua`: verified red cast spark behavior and cast-following indicator motion-to-bar-end while casting; verified configurable Lightning Shield tracker gap usage.
- Metadata corrected for test cycle: `SuperSwingTimer.toc` remains `v0.1.2` until user confirms final test success.

## Active Context Update (2026-05-31 - extreme timing/aura hardening pass)

- User asked for an extreme deep pass centered on real production timing, exact reset behavior, and Anniversary-era API correctness rather than perf-driven simplification.
- Completed a code-proven timing/aura trace across `SuperSwingTimer_State.lua`, `SuperSwingTimer_UI.lua`, and `SuperSwingTimer_ClassMods.lua`.
- Fixed a real GCD ticker lifecycle bug:
  - previous code set `ns.gcdActive = false` in `HandleSpellcastStop()`, which could truncate the visible GCD window before the actual global cooldown finished.
  - new behavior queries spell `61304` through `C_Spell.GetSpellCooldown` with legacy fallback, refreshes on cast start/channel start/success, conditionally clears on failed/interrupted casts only when no real cooldown is active, and self-expires in `UpdateGcdTicker()`.
- Fixed two aura-tuple correctness bugs in `SuperSwingTimer_ClassMods.lua`:
  - `GetHarmfulAuraData()` now reads harmful aura counts from the correct return slot for Classic/Anniversary API shape.
  - Shaman `GetShieldChargeCount()` now reads the actual aura stack count instead of the dispel-type slot, which previously risked showing a fake default 3-charge shield state.
- Extended reset hardening so GCD state is cleared on both `PLAYER_REGEN_ENABLED` and `OnPlayerEnteringWorld()`, preventing stale ticker carryover after combat end, zoning, or reload.
- Targeted diagnostics on `SuperSwingTimer_State.lua`, `SuperSwingTimer_ClassMods.lua`, `SuperSwingTimer_UI.lua`, and `SuperSwingTimer.lua` are clean after the pass.

## Active Context Update (2026-05-31 - 4th pass timing/reset/API hardening)

- User requested deeper production drilldown emphasizing TBC Classic Anniversary (2026 API), reset correctness, and timing-critical reliability without stripping behavior.
- Implemented modern API-aware cooldown hardening:
  - `State.GetAutoShotCooldown()` now prefers `C_Spell.GetSpellCooldown` and falls back to legacy `GetSpellCooldown`.
  - `ClassMods` now uses unified `QuerySpellCooldown()` for Paladin GCD/Judgement marker timing and Warrior cooldown badge timing.
- Tightened reset guarantees across world-entry/combat-end:
  - Explicitly clears transient cast/channel/pause/proc state on world entry and combat end.
  - Ensures queued-melee spell caches are hard-cleared after tint cleanup.
- Timing/perf improvements made without removing UX features:
  - Shield Block style sync moved off per-frame path to its existing throttle cadence.
  - Rapid Fire helper style updates now cached and forced when needed (config apply), reducing frame churn while preserving immediate visual feedback.
- Diagnostics after all edits are clean.

## Active Context Update (2026-05-31 - third deep pass with double-check)

- Executed a deeper third pass centered on dead-path/event-feed mismatches and callback lifecycle validation across class-mod runtime hooks.
- Confirmed and fixed a Warrior runtime logic gap: Protection-hide (`showWarriorRageProtection`) previously relied on `GetSpecialization()` only, which is unreliable on Classic/TBC-family clients.
- Added a Classic-safe Protection fallback (talent-tree primary-spec inference via `GetNumTalentTabs` + `GetTalentTabInfo`) with a short cache window to avoid heavy per-frame scanning.
- Confirmed and fixed Hunter Rapid Fire helper styling deadness after first creation: runtime now re-applies texture/height/width/anchor/color each update so `/sst` style changes are live.
- Updated shared color-application path so `ApplyBarColors()` explicitly refreshes Druid energy-tick tint and Hunter Rapid Fire helper visuals.
- Post-fix targeted diagnostics on modified files are clean.

## Active Context Update (2026-05-31 - second pass on remaining classes)

- Completed a second production sanity sweep focused on Hunter/Rogue/Paladin/Druid runtime paths after the Warrior/Shaman pass.
- Found and fixed a real Paladin runtime issue: `GetReckoningStackCount()` unpacked `UnitBuff` spellId from slot 10 instead of slot 11, which could break ID-based Reckoning detection on non-English clients or name-fallback variance.
- Patched `SuperSwingTimer_ClassMods.lua` to use the correct tuple slot; diagnostics on the edited file are clean.

## Active Context Update (2026-05-31 - warrior/shaman production correctness)

- Verified a live-code mismatch: Warrior Overpower flash UI existed but had no proc source writing `ns.warriorOverpowerProcUntil`; feature was effectively dead despite older notes claiming implemented.
- Shipped runtime fix in `SuperSwingTimer_State.lua`: set Overpower proc window on player dodge outcomes from CLEU (`SWING_MISSED` and queued-melee `SPELL_MISSED` when miss type is `DODGE`).
- Shipped Shaman aura-shape hardening in `SuperSwingTimer_ClassMods.lua`:
  - Added normalized harmful-aura reader and switched Flame Shock target scan to it.
  - Corrected shield charge stack reads (use real aura-count field).
  - Corrected Shaman/Warrior Flurry counters to use aura stack counts rather than counting aura rows.
- Targeted diagnostics after patching are clean on edited runtime files.

## Active Context Update (2026-05-31 - shaman production pass: proven runtime fixes)

- Completed a Shaman-only production pass focused on code-proven failures before the user's live test session.
- Fixed a real Shamanistic Rage aura-read bug in `SuperSwingTimer_ClassMods.lua`: `GetShamanAuraRemaining()` was unpacking the shared `GetHelpfulAuraData()` helper as if it returned the full `UnitAura` tuple, which left `expirationTime` / `spellId` wrong and could make the SR badge fail.
- Fixed weave marker rendering mismatch in `SuperSwingTimer_ClassMods.lua`: the top/bottom breakpoint markers now use the tracked spell icon texture when available instead of always falling back to static arrow textures.
- Hardened Flame Shock target tracking in `SuperSwingTimer_ClassMods.lua` by adding a fallback from `UnitDebuff("target", index, "PLAYER")` to `UnitAura("target", index, "HARMFUL|PLAYER")`, reducing client-variance risk in the target DoT scan.
- Hardened Lightning/Water Shield tracker rendering in `SuperSwingTimer_ClassMods.lua`: the charge container is now parented/layered with the MH overlay instead of raw `UIParent`, hides when MH is not visible, and uses cleaner single-anchor positioning for MH-only vs MH+OH layouts.
- Targeted diagnostics on `SuperSwingTimer_ClassMods.lua` are clean after the Shaman pass.

## Active Context Update (2026-05-31 - migration alignment and Druid cat energy restoration)

- Corrected the mixed migration/default state created during the prior de-bloat pass: runtime schema is aligned back to `v47`, and stale Druid helper removal now lives inside migration `47` instead of silently bumping defaults to `48` without a matching migration step.
- Narrowed supported Druid runtime scope to the features the user still wants live: Maul queue tint plus Cat-form energy tick. Removed stale normalization for unsupported Druid helpers from `SuperSwingTimer.lua` while preserving old historical migration steps.
- Restored the actual missing Druid runtime wiring: Druid power events now register, `UPDATE_SHAPESHIFT_FORM` is now actually registered, `HandleDruidEnergyPowerUpdate()` exists again, and `SuperSwingTimer_ClassMods.lua` now creates/updates a real Cat energy tick helper bar left of MH.
- Added `/sst` wiring for the restored Druid helper: quick toggle, quick color row, and width slider for `showDruidEnergyTickBar` / `druidEnergyTickBarWidth`.
- Targeted diagnostics on `SuperSwingTimer.lua`, `SuperSwingTimer_State.lua`, `SuperSwingTimer_ClassMods.lua`, `SuperSwingTimer_Config.lua`, and `SuperSwingTimer_Constants.lua` are clean after the correction pass.

## Active Context Update (2026-05-30 - migration ladder refactor complete)

- User requested table-driven migration conversion be done correctly.
- Completed refactor of `MigrateDB()` in `SuperSwingTimer.lua` from a long sequential `if (version < X)` ladder to an ordered table-driven migration list.
- Preserved every existing migration step’s behavior and ordering while improving auditability and reducing edit-risk.
- Targeted diagnostics on `SuperSwingTimer.lua` are clean after the refactor.
- Separate follow-up smell remains outside this request: `RegisterSlashCommands()` is still invoked in two places (file scope and `OnAddonLoaded()`), which is a high-quality-code concern but not part of the migration refactor.

## Active Context Update (2026-05-30 - migration table corrected to exact ladder shape)

- The table-driven migration path had a real mismatch: `v44` was missing and `v45` was empty compared to the old ladder.
- Restored the exact missing Druid steps:
  - `v44`: Druid energy tick color normalization plus Tiger's Fury / Faerie Fire badge defaults
  - `v45`: Druid Mangle timer / Rip tracker defaults plus their color normalization
- Restored the corresponding Druid defaults/colors in `SuperSwingTimer_Constants.lua` so migrations have matching backing fields.
- Validation after the fix: `SuperSwingTimer.lua` and `SuperSwingTimer_Constants.lua` both pass targeted diagnostics.

## Active Context Update (2026-05-30 - deep risk audit: critical/high/medium)

- Executed full core Lua fallback/risk audit with severity triage per user request.
- No syntax/parser diagnostics found across core modules.
- Applied additional runtime hardening:
  - `SuperSwingTimer_State.lua` `ns.HandleCLEU()` now guards missing `CombatLogGetCurrentEventInfo` and empty payload (`subEvent == nil`) before dispatch.
  - `SuperSwingTimer_UI.lua` bar input path already hardened with safe camera fallback wrappers and visibility/cleanup guards.
- Audit summary:
  - Critical: none currently identified after applied guards.
  - High: migration-chain maintainability risk (long sequential migration ladder) remains process-level risk, not immediate runtime break.
  - Medium: broad shield fallback ID/name matching remains intentionally resilient but should be periodically trimmed to live-verified mappings to minimize accidental overmatching.

## Active Context Update (2026-05-30 - enterprise fallback hardening: input/camera path)

- User requested enterprise-grade fallback quality pass.
- Completed a reliability-focused fallback hardening update for core bar input in `SuperSwingTimer_UI.lua`:
  - added safe right-click camera wrappers with guarded `pcall` start/stop behavior
  - tightened mouse-enable visibility checks from alpha-only to `IsShown + alpha` semantics
  - added automatic cleanup of active right-click fallback state when bars are force mouse-disabled
  - preserved existing UX intent: left-click drag when unlocked, camera-safe behavior in combat
- Targeted diagnostics on edited runtime file are clean.

## Active Context Update (2026-05-30 - mouse-input scope audit + propagation)

- User asked for confirmation that camera bug was not hiding outside UI.
- Audit result: class-mod helper bars/overlays are mouse-disabled; primary input-capture path is the draggable core bars in `SuperSwingTimer_UI.lua`.
- Added bar-level click propagation (`SetPropagateMouseClicks(true)` when available) so right-click camera input can pass through bars naturally out of combat while left-click drag still works when unlocked.
- Retained guarded fallback right-click start/stop path for clients where click-propagation API is unavailable.

## Active Context Update (2026-05-30 - combat camera safety hard-stop)

- User flagged camera interruption as a critical gameplay bug; accepted as a hard safety requirement.
- Updated `ns.ApplyLockBars()` in `SuperSwingTimer_UI.lua` to force all core bars mouse-disabled while in combat (`ns.inCombat || InCombatLockdown`), independent of lock/unlock state.
- Outcome: bars can no longer eat mouse interaction during combat, preventing right-click camera/turn disruption mid-fight.
- Out-of-combat behavior preserved: unlocked bars remain left-draggable for setup.

## Active Context Update (2026-05-30 - unlocked bar right-click camera fix)

- User clarified intended UX: in combat, right-click over bars must still control camera while left-click remains drag when bars are unlocked.
- Updated `SuperSwingTimer_UI.lua` drag handler path to use `TurnOrActionStart()` / `TurnOrActionStop()` for right-button interactions over unlocked bars (Classic world-right-click semantic), with fallback to `MouselookStart/Stop` where needed.
- Added per-frame camera-state tracking (`sstRightCameraActive`) and OnHide cleanup so stop calls only fire if the frame started right-click camera mode.
- This addresses the symptom where right-click over bars felt non-functional for camera movement even though left drag was working.

## Active Context Update (2026-05-30 - memory-bank-instructions rewrite)

- User copied in `memory-bank/memory-bank-instructions.md` from another folder and requested analysis/update.
- Replaced generic non-repo template content (notification-service examples, JS toolchain validation hooks, unrelated slash-command flows) with a SuperSwingTimer-specific memory protocol.
- New instructions now explicitly cover:
  - required core memory load order
  - on-demand context loading strategy
  - BC Classic Anniversary 2026 / 2.5.5 runtime baseline
  - addon settings wiring checklist (defaults/migration/runtime/config/docs/toc)
  - targeted `get_errors` validation protocol
  - mandatory AGENTS + memory + docs sync after code changes

## Active Context Update (2026-05-30 - Anniversary baseline clarification)

- Added explicit repository-level baseline that this project targets **World of Warcraft: Burning Crusade Classic Anniversary Edition** (2026, patch line 2.5.5), not the 2021 BC Classic launch branch.
- Updated future-context docs (`AGENTS.md`, `memory-bank/techContext.md`, `memory-bank/projectBrief.md`, `memory-bank/systemPatterns.md`) to encode this as default engineering scope.
- Captured source-priority rule: prefer Anniversary-targeted references first (warcraft.wiki.gg Anniversary pages + current classic UI-source mirror branches), then older forum-era posts only as secondary context.
- Captured high-confidence difference framing from re-check: public Anniversary deltas are largely gameplay/system-level (e.g., attunement and interface-era changes), while no definitive evidence was found that core swing-timer addon APIs used in this repo are invalidated specifically by 2.5.5.

## Active Context Update (2026-05-30 - lightweight WA-like direction + druid schema cleanup)

- User clarified product direction: SuperSwingTimer should feel like a lightweight WeakAuras-style combat helper (high signal, low bloat), with reliability prioritized over feature sprawl.
- Applied de-bloat follow-up in core data paths:
  - removed stale Druid post-streamline defaults from `ns.DB_DEFAULTS` in `SuperSwingTimer_Constants.lua`
  - removed stale v43->v45 Druid migration writes in `SuperSwingTimer.lua` that were re-adding stripped feature keys/colors to SavedVariables
- Result: stripped Druid features are no longer silently reintroduced into fresh or upgraded profiles, reducing schema noise and long-term config drift.
- Synced docs (`README.md`, `CHANGELOG.md`) so published behavior matches the streamlined Druid scope and lightweight design intent.

## Active Context Update (2026-05-30 - full core Lua audit on BCC Anniversary 2.5.5)

- Per user request, performed a deeper end-to-end audit of all core addon Lua files on live BCC Anniversary assumptions (Patch 2.5.5): `SuperSwingTimer.lua`, `_Constants.lua`, `_State.lua`, `_Weaving.lua`, `_UI.lua`, `_ClassMods.lua`, `_Config.lua`.
- Diagnostics status: no parser/lint issues reported by targeted checks on all seven core files.
- API-context verification: checked current wiki references for Anniversary/Classic aura and spellcast behaviors; no evidence the addon's core `UnitAura`/`UnitBuff`/`UNIT_SPELLCAST_*` approach is invalidated specifically by 2.5.5.
- Smell-level findings (not hard failures):
  - stale Druid helper toggles/migration keys still exist in defaults/schema after streamlining, creating config/migration noise
  - broadened Water Shield fallback ID table should be validated on live 2.5.5 and trimmed to known-good mappings where redundant

## Active Context Update (2026-05-30 - Lightning/Water shield no-show hardening)

- Per user follow-up about shield tracker not working, completed a focused compatibility audit for Lightning Shield and Water/Mana Shield detection.
- Found and fixed two reliability gaps:
  - shield detection previously depended too heavily on spell IDs in aura payloads
  - Water Shield spell ID coverage was too narrow for cross-client/build aura mapping behavior
- Implemented fixes:
  - expanded shield ID coverage in `SuperSwingTimer_Constants.lua` (Lightning ranks + Water rank/alternate aura mappings)
  - added normalized shield name lookup tables for resilient fallback matching
  - updated `IsLightningShieldActive()` in `SuperSwingTimer_ClassMods.lua` to do ID-first matching with name fallback (`Water Shield` / `Mana Shield` alias-safe)
- Updated `README.md` and `CHANGELOG.md` to document shield compatibility hardening in `v0.1.2`.
- Targeted diagnostics on edited runtime files remained clean after patch.

## Active Context Update (2026-05-30 - shaman Lightning Shield stack-height correction)

- Follow-up UX correction from user visual review: Lightning Shield tracker should not remain MH-only height during MH/OH dual-wield display.
- Updated `UpdateLightningShieldVisual()` sizing in `SuperSwingTimer_ClassMods.lua`:
  - single-bar mode -> tracker height = MH height
  - dual-wield mode -> tracker height = MH + 2px gap + OH height
- Kept the tracker anchored left of MH and top-aligned to MH in dual-wield mode so the expanded height correctly covers the full melee stack.
- Synced `memory-bank/visualContext.md` mini-map and `CHANGELOG.md` to reflect the corrected runtime behavior.

## Active Context Update (2026-05-30 - shaman helper checkbox wiring + visualContext sync)

- Added full SavedVariables/UI wiring for disabling the new Enhancement Shaman Flame Shock helper bar from `/sst` Quick Controls.
- Added `showShamanFlameShockBar` to defaults (`SuperSwingTimer_Constants.lua`), normalized it in migration bootstrap (`SuperSwingTimer.lua`), and added explicit migration step `v46 -> v47` so existing users receive a stable default.
- Updated `SuperSwingTimer_ClassMods.lua` runtime path so `UpdateShamanFlameShockBar()` respects the DB toggle and hides immediately when disabled.
- Confirmed Lightning helper has explicit checkbox control and polished label text from `Lightning Shield` to `Lightning Shield Tracker` for clearer operator intent in Quick Controls.
- Reset Defaults now restores both `showShamanLightningTracker` and `showShamanFlameShockBar` from `ns.DB_DEFAULTS`.
- Updated `memory-bank/visualContext.md` to reflect the current real `/sst` panel structure, including shaman quick toggles (`Lightning Shield Tracker`, `Flame Shock Bar`) and the helper mini-map.
- Synced README/CHANGELOG/docs (`docs/UI.md`) to describe the new professional-grade helper toggle behavior.

## Active Context Update (2026-05-30 - Lightning Shield wiring fix + unlocked camera passthrough)

- Follow-up reliability pass addressed user-reported Shaman Lightning Shield tracker no-show behavior after the v0.1.2 rollout.
- Root cause: `IsLightningShieldActive()` in `SuperSwingTimer_ClassMods.lua` unpacked `GetHelpfulAuraData()` as if it returned the full UnitAura tuple; the helper actually returns a normalized 4-value shape (`name, duration, expirationTime, spellId`), so `auraSpellId` stayed nil and shield detection failed.
- Fixes implemented:
  - corrected helper unpacking in `IsLightningShieldActive()`
  - removed an `OnBarsCreated()` early-return edge case so shaman overlay recovery does not skip creating `shamanLightningContainer` when weave textures already exist
  - added explicit `UNIT_AURA` (player) -> `UpdateLightningShieldVisual()` refresh in `SuperSwingTimer.lua` for immediate charge updates
- Camera/interaction polish: unlocked bars now preserve right-click camera look by forwarding right-button down/up to `MouselookStart()` / `MouselookStop()` in `SuperSwingTimer_UI.lua`, while left-click drag behavior remains unchanged.
- Targeted diagnostics on the touched runtime files remained clean after the patch.

## Active Context Update (2026-05-30 - shaman weave no-show deep analysis + Flame Shock bar)

- Completed a deep shaman weave no-show investigation across `SuperSwingTimer.lua` event dispatch, `SuperSwingTimer_Weaving.lua` spell/cast-state matching, `SuperSwingTimer_ClassMods.lua` overlay rendering, and `SuperSwingTimer_UI.lua` visibility interactions.
- Verified the `UNIT_SPELLCAST_*` payload assumptions and Classic/TBC cast-token fallback behavior against current wiki references; no Lua diagnostics were present in the shaman-related files.
- Added a runtime hardening path in `SetupEnhShaman()` so `UpdateWeaveVisuals()` re-attempts `OnBarsCreated()` before returning when weave textures are unexpectedly missing, improving recovery when overlays are rebuilt late.
- Implemented a new Enhancement Shaman Flame Shock target-duration helper bar above MH (6px stock height), including:
  - rank-safe Flame Shock spell-ID constants in `SuperSwingTimer_Constants.lua`
  - player-filtered target debuff tracking in `SuperSwingTimer_ClassMods.lua`
  - immediate refresh hooks for `PLAYER_TARGET_CHANGED` + `UNIT_AURA` target updates in `SuperSwingTimer.lua`
  - shared visibility refresh hook in `SuperSwingTimer_UI.lua`
- Synced docs + metadata for the change: `README.md`, `CHANGELOG.md`, `docs/UI.md`, `docs/swingtimer.md`, and `SuperSwingTimer.toc` (version `v0.1.2`).

## Active Context Update (2026-05-30 - wow-classic-lua v0.5.0 10/10 operator pass)

- Final 10/10 pass added three execution-grade references under `.github/skills/wow-classic-lua/references/`:
  - `operator-cheatsheet.md` (fastest routing for live coding/debugging)
  - `class-quickmaps.md` (class-specific file ownership jump map)
  - `incident-first-5-minutes.md` (deterministic first-response bug triage workflow)
- Updated `SKILL.md` to `v0.5.0` and indexed the three new references.
- Updated `api-notes.md` quick-start map + start-here list to include the new operator/class/incident docs.
- This remains documentation/skill-only work; addon runtime behavior unchanged.

## Active Context Update (2026-05-30 - wow-classic-lua visuals expansion across all references)

- Follow-up pass expanded visuals beyond only the three operational docs.
- Added compact ASCII visual maps to the rest of the reference pack where they improve scan speed and decision-making:
  - `api-notes.md`
  - `api-core.md`
  - `ui-frames-and-widgets.md`
  - `framexml-and-xml.md`
  - `research-links.md`
  - `superswingtimer.md`
  - `runtime-safety.md`
- Existing visualized operational files (`compatibility-matrix.md`, `event-payload-cheatsheet.md`, `verification-playbooks.md`) were kept as-is from the prior pass.
- This remains doc/skill-only work; no runtime addon Lua behavior changed.

## Active Context Update (2026-05-30 - wow-classic-lua v0.4.0 final 10/10 pass)

- Completed the final operational pass on `.github/skills/wow-classic-lua` and bumped `SKILL.md` to `v0.4.0`.
- Added three high-leverage reference files requested for a 10/10 quality bar:
  - `references/compatibility-matrix.md`
  - `references/event-payload-cheatsheet.md`
  - `references/verification-playbooks.md`
- The skill now has explicit branch-safe fallback guidance, a compact high-risk event parsing reference, and subsystem-specific in-game test playbooks.
- This was a skill/docs pass only; no runtime addon Lua logic changed.

## Active Context Update (2026-05-30 - wow-classic-lua v0.3.0 final polish)

- Final-polished `.github/skills/wow-classic-lua/SKILL.md` and bumped the skill to `v0.3.0`.
- Tightened wording for accuracy and added explicit runtime-safety scope: combat-lockdown / taint / protected-action constraints now appear in workflow, core rules, and debugging guidance.
- Added an in-game validation checklist directly in the skill so edits include practical `/reload`, `/sst`, combat visibility, drag/lock, and class-specific verification steps.
- Added a new reference file: `.github/skills/wow-classic-lua/references/runtime-safety.md` covering secure behavior guardrails, SavedVariables lifecycle timing (`ADDON_LOADED` vs `PLAYER_LOGIN`), performance patterns, and combat-only bug triage flow.
- This is a documentation/skill pass only; runtime addon logic is unchanged.

## Active Context Update (2026-05-30 - shaman weave actual-cast rescale follow-up)

- Corrected the Enhancement Shaman weave model so the moving icon is driven by elapsed cast time against the current haste-adjusted cast duration each frame instead of only acting like a static helper.
- The safe breakpoint markers remain fixed for readability, but the live spell icon now animates and resizes with spell haste/buffs while the cast is active.
- Kept the Quick Controls title-gap polish in place so the `Key Colors` header still has extra breathing room above the first swatch row.
- Targeted source review is the validation path in this session; the edited weave and class-mod files read clean after the follow-up patch.

## Active Context Update (2026-05-30 - wow-classic-lua skill reference-pack refresh)

- Expanded `.github/skills/wow-classic-lua/` from a thin single-note skill into a fuller Classic/TBC addon reference pack.
- Refreshed the skill against current `warcraft.wiki.gg` pages for Classic API coverage, `CreateFrame`, Frame, StatusBar, Texture, FontString, ScrollFrame, Slider, widget script handlers, XML schema, combat-log APIs, cast/channel APIs, cooldown APIs, and latency APIs.
- Added dedicated reference files for API core behavior, UI/frame/widget construction, FrameXML/XML guidance, curated research links, and a new `superswingtimer.md` project-specific architecture guide so future addon work can reuse the current repo's proven patterns.
- This pass is documentation/skill infrastructure only; no runtime addon Lua behavior changed.

## Active Context Update (2026-05-30 - quick-controls gap + shaman weave live-position follow-up)

- Nudged the `/sst` Quick Controls column titles down a hair more in `SuperSwingTimer_Config.lua` and increased the first-row gap so the `Key Colors` heading no longer visually overlaps or kisses the first compact swatch row.
- Reworked the Enhancement Shaman weave display split across `SuperSwingTimer_Weaving.lua` and `SuperSwingTimer_ClassMods.lua`: the upper/lower breakpoint markers are fixed on the safe cast-start point again, while the moving weave icon now starts from the live cast-start position on the MH swing and travels toward projected landing instead of making the breakpoint markers themselves masquerade as the active spell position.
- Hardened the weave cast-state capture to fall back to `ns.GetUnitCastingSpellInfo("player")` when event spell tokens are incomplete, and now store cast-start / predicted-end timing in weave state so Lightning Bolt or Chain Lightning motion can start immediately on the first cast frame.
- Targeted diagnostics on `SuperSwingTimer_Config.lua`, `SuperSwingTimer_ClassMods.lua`, and `SuperSwingTimer_Weaving.lua` are the validation target after the patch.

## Active Context Update (2026-05-28 - `/sst` row-width + class-only slider follow-up)

- Tightened the `/sst` config panel again in `SuperSwingTimer_Config.lua`: Hunter / Rogue / Warrior helper sliders in Appearance are now only created for the active class instead of being instantiated for every class and then hidden later, which removes the leaked off-class slider rows the user was still seeing in-game.
- Reworked the main config row builders so the standard Appearance / Shaman / General rows use more of the panel width: texture pickers now span the row width, browser path boxes fill the row minus the browse button, cycle rows use wider dropdowns, and default toggle/action rows now keep the label above the control instead of cramming everything into the far-left side.
- Quick Controls remains the compact two-column area, but its `Visibility` / `Key Colors` labels now sit with explicit vertical space below the section header before the first compact rows begin, preventing the section title from colliding with the column labels.
- Re-ran targeted diagnostics on `SuperSwingTimer_Config.lua` after the follow-up and the file remains clean.

## Active Context Update (2026-05-28 - shaman weave motion + /sst layout fix)

- Updated the Enhancement Shaman weave visuals so active tracked casts no longer stay pinned to one fixed projected-impact point. `SuperSwingTimer_Weaving.lua` now exposes normalized cast progress, and `SuperSwingTimer_ClassMods.lua` moves the weave icon pair plus center spark from the safe cast-start breakpoint toward the projected landing point across the current MH swing.
- Fixed the `/sst` open-path runtime error in `SuperSwingTimer_Config.lua` by guarding the stale `panel.druidPowerShiftSlider` / `panel.druidEnergyTickSlider` refresh calls that survived the Druid streamlining pass.
- Reworked the `/sst` section layout for `Appearance`, `Shaman Weave Assist`, `General Behavior`, and `Weave Families` so those sections are reflowed from real widget heights instead of brittle hard-coded Y offsets, which removes the overlapping header/slider issue from the current live panel. Follow-up polish now re-runs that section reflow when the relevant headers collapse/expand and whenever `/sst` is reopened, so the spacing stays correct during real config use instead of only on initial panel creation.
- Replaced the old tiny `OptionsSliderTemplate` anchors in `SuperSwingTimer_Config.lua` with labeled full-width slider rows that put the title above the control, keep the numeric entry box on the right side of the same row, and stop wasting the panel width with 100px-wide slider strips.
- Re-ran targeted diagnostics on `SuperSwingTimer_Config.lua`, `SuperSwingTimer_ClassMods.lua`, and `SuperSwingTimer_Weaving.lua`; all three edited files are clean.

## Active Context Update (2026-05-27 - Enhancement Shaman Windfury crash + projected weave icon)

- Fixed the Enhancement Shaman `UpdateWindfuryIcd()` runtime crash in `SuperSwingTimer_ClassMods.lua` by replacing the brittle raw `UnitBuff()` scan with the shared `GetHelpfulAuraData()` helper and explicit numeric spell-ID checks, which removes the `attempt to compare number with boolean` failure on current Classic/TBC helpful-aura payloads.
- Replaced the broken self-rebuilding shaman update chain: `UpdateShamanisticRageBadge()` no longer reassigns `ns.OnUpdate` from inside itself. `SetupEnhShaman()` now installs one stable wrapper that refreshes weave visuals plus Flurry / Stormstrike / Shamanistic Rage badges each frame.
- Updated the active shaman weave display so tracked casts such as Lightning Bolt and Chain Lightning temporarily swap the moving weave spark to the real spell icon and pin it to the projected landing point on the current main-hand swing instead of raw cast-progress, then restore/hide cleanly after the cast ends.
- Re-ran targeted diagnostics on `SuperSwingTimer_ClassMods.lua` after the fix and confirmed the edited file is clean.

## Active Context Update (2026-05-20 - v0.0.9 Druid Streamlining & Shaman Weaving Fix)

- Resolved the Shaman weaving cast-by threshold indicator alignment bug by switching triangle marker relative anchors from `"TOP"` / `"BOTTOM"` to `"TOPLEFT"` / `"BOTTOMLEFT"`. This offsets markers correctly from the left-zero boundary using the proportional MH bar width and current spellcast timing plus latency.
- Completely streamlined the Feral Druid options by stripping out bloated, non-essential status rows and visual indicators (such as the Mangle debuff bar, Rip bleed bar, Omen of Clarity procs, Tiger's Fury badge, Faerie Fire left glow, shapeshift form colors/labels, and Bear rage-dimming).
- Retained only the core swing timber status bars and the signature Bear Form Maul yellow queue overlay (`DRUID_MAUL_TINT`) to provide a high-frequency, minimal, high-refresh-rate utility for Druids.
- Cleared out retired configuration controls sequentially inside `SuperSwingTimer_Config.lua` to maintain safe column limits and preserve subsection header collapses.
- Verified that all edited code paths pass diagnostic checks end-to-end.

## Active Context Update (2026-05-20 - v0.0.8 bugfix release FINAL)

- Fixed the line-71 crash in `SuperSwingTimer_ClassMods.lua`: a bare `local updateInterval = 0.016` before `ns` existed killed the entire file for every non-hunter class.
- Fixed Paladin seal twist zone layering: seal textures were routing through the Shaman weave marker system; now use `SetDrawLayer("OVERLAY", 0)` directly.
- Fixed the missing `end` in `UpdateShamanisticRageBadge()` that caused LSP cascade errors.
- Fixed the Shaman OnUpdate chain: `prevOnUpdate(elapsed)` was an undefined global. Captured `ns.OnUpdate` directly and added bootstrap call.
- Fixed `end` indentation at lines 239–241 and OnUpdate body indentation inside `SetupEnhShaman()`.
- Fixed `strtrim` undefined in UI.lua: added `local strtrim = rawget(_G, "strtrim")` at import block.
- Tuned latency refresh: `LATENCY_REFRESH_INTERVAL` 5.0s → 0.05s with `RefreshLatencyCache()` in `HandleSpellcastDelayed`.
- Consolidated CHANGELOG, AGENTS, and memory-bank docs under v0.0.8.
- Updated ROADMAP.md with Phase 8 completed, corrected Phase 0/Phase 1 to unchecked (still v0.0.9 target), added Phase 9 (LSP Health), Phase 10 (Testing/Automation), Phase 11 (Integration/Ecosystem). Updated execution strategy and effort summary.

## Active Context Update (2026-05-20 - final pass: every class helper bar wired in `/sst`)

- Every buff-duration and helper bar across all 6 classes now has both a show/hide toggle and an adjustable height/width slider in the `/sst` config panel:
  - **Warrior**: Shield Block Height slider + toggle (existing)
  - **Hunter**: Rapid Fire Height slider + Range Helper Width slider + toggles (this session)
  - **Rogue**: SnD Height + Energy Tick Width + Adrenaline Rush Height sliders + toggles (this session)
  - **Druid**: Power Shift Height + Energy Tick Width sliders + Power Shift/Energy Tick visibility toggles (this session)
- New DB keys this session: `rogueSliceAndDiceBarHeight`, `rogueEnergyTickBarWidth`, `warriorShieldBlockBarHeight`, `hunterRangeHelperWidth`, `hunterRapidFireBarHeight`, `druidPowerShiftBarHeight`, `druidEnergyTickBarWidth`, `rogueAdrenalineRushBarHeight`, `showDruidPowerShiftBar`, `showDruidEnergyTickBar`.
- DB migration v43→v44 for the bar-size keys.
- Updated README class-support tables, CHANGELOG, and memory-bank docs.

## Active Context Update (2026-05-19 - roadmap closure and completion state)

- Closed out the active roadmap phases in `ROADMAP.md`: Phase 6 is now fully checked off, Phase 7 is checked off, and the only remaining broad idea was moved into an explicit archived / future wishlist section instead of leaving an active phase half-open.
- Refreshed `README.md` and `CHANGELOG.md` so the repository now reads as final-prep / feature-complete, with shipped tank/class-polish features separated from archived wishlist material.

## Active Context Update (2026-05-19 - tank utility and class polish start)

- Implemented the first Phase 6 slice: Warrior now has a real Shield Block duration bar above the MH stack, and Druid now has an amber Ravage opener cue that only shows when Cat Form Ravage is actually usable on the current target.
- Added the supporting SavedVariables defaults, migration/version bump, config toggles, color swatches, event refresh hooks, and UI on-update wiring, then updated `ROADMAP.md`, `README.md`, and `CHANGELOG.md` so the docs match the current runtime state.

## Active Context Update (2026-05-19 - phase 5 final polish and validation)

- Finished the Phase 5 final-polish pass: replaced the fragile spellcast-success wrapper pattern with an explicit hook registration path, removed the remaining shadowed/unused Lua locals in ClassMods and Config, collapsed the duplicate UI GCD/flash helper definitions, tightened the swing-start fallback so it prefers the last known timer speed before the generic 2.0 fallback, and confirmed the full workspace now passes project-wide diagnostics with zero reported errors.
- Marked the Rogue Combo Points roadmap item as already wired in Quick Controls and updated the roadmap to reflect the resolved state.

## Active Context Update (2026-05-19 - hunter cast API and latency slice polish)

- Tightened the Hunter cast path again in `SuperSwingTimer_Constants.lua`, `SuperSwingTimer_State.lua`, and `SuperSwingTimer_UI.lua`: live Hunter cast detection now goes through a Classic-safe `UnitCastingInfo()` spell-name-first helper instead of assuming a modern spellID return, the Hunter spellcast start/succeed/delayed paths preserve recovered Hunter spell tokens more safely when event payloads are incomplete, and the dedicated Steady Shot / Aimed Shot bar now paints a trailing latency slice that scales with cached latency and the current cast duration.

## Active Context Update (2026-05-19 - hunter state hardening review follow-up)

- Closed the follow-up hunter review findings in `SuperSwingTimer_State.lua`, `SuperSwingTimer_UI.lua`, `SuperSwingTimer.lua`, and `SuperSwingTimer_ClassMods.lua`: queued Raptor now only affects MH-bar visibility instead of counting as full melee-active state for ranged suppression, hidden stored hunter-cast state now expires cleanly, `STOP_AUTOREPEAT_SPELL` can force a false fallback when no authoritative spell-state query exists, and the localized Raptor name is cached once inside Hunter setup.
- Re-ran a focused review subagent after those fixes and it reported no remaining concrete hunter issues in those reviewed areas.

## Active Context Update (2026-05-19 - hunter clip-safety and class-color label polish)

- Added one more Hunter precision pass in `SuperSwingTimer.lua`, `SuperSwingTimer_State.lua`, and `SuperSwingTimer_UI.lua`: `UNIT_SPELLCAST_DELAYED` now updates stored Hunter cast timing, and the dedicated hunter cast bar now tints real Steady Shot / Aimed Shot casts by whether they still finish before the next Auto Shot so clip risk is easier to read live.
- Added a shared bar-label styling path in `SuperSwingTimer_UI.lua`: when `Use Class Colors` is enabled, MH/OH/ranged and the hunter cast bar now show black text with a white outlined backing instead of the old plain white label, improving readability on bright class-colored fills.

## Active Context Update (2026-05-19 - hunter melee handoff and steady cast-bar pass)

- Tightened the Hunter melee/ranged handoff in `SuperSwingTimer_UI.lua`, `SuperSwingTimer_State.lua`, and `SuperSwingTimer_ClassMods.lua`: the Hunter MH bar is now anchored to the ranged stack, only appears for a live MH swing or queued Raptor Strike, queued Raptor uses its own yellow next-attack tint, and the ranged bar is no longer allowed to stay stuck full red after the last ranged cycle expires while the hunter is committed to melee.
- Expanded the dedicated hunter helper bar in `SuperSwingTimer_Constants.lua` and `SuperSwingTimer_UI.lua` so it still covers the hidden Auto Shot / Multi-Shot window but now also shows real Steady Shot and Aimed Shot cast progress from `UnitCastingInfo()` / stored cast state.

## Active Context Update (2026-05-18 - hunter mount loop fix)

- Tightened the Hunter Auto Shot polish again in `SuperSwingTimer_State.lua` and `SuperSwingTimer.lua`: mounted Hunters are now treated as not auto-repeating via `IsMounted()`, and cooldown resync is blocked while the ranged bar is pinned in the red moving window so mount / long-movement cases no longer make the ranged bar loop repeatedly until the player stops.

## Active Context Update (2026-05-18 - hunter auto-repeat and quick-controls polish)

- Polished the Hunter Auto Shot path in `SuperSwingTimer.lua`, `SuperSwingTimer_State.lua`, and `SuperSwingTimer_UI.lua`: transient `STOP_AUTOREPEAT_SPELL` events no longer hard-reset the ranged timer, cooldown-driven cycle starts now cross-check Blizzard's current auto-repeat spell state first, and the current cycle is allowed to finish cleanly so the red late window can stay visible instead of clunkily resetting while Auto Shot still fires.
- Polished `/sst` copy/layout in `SuperSwingTimer_Config.lua`: the top Quick Controls area now has explicit `Visibility` and `Key Colors` column headers, a shorter clearer subtitle, and the Hunter red window swatch is labeled `Auto Shot Late` for more intuitive setup wording.

## Active Context Update (2026-05-18 - rogue helper cleanup follow-up)

- Removed the experimental Rogue combo-point strip and the right-side total-energy battery helper from the active Rogue runtime/config path, leaving one slim 4px energy-tick bar to the left of MH and removing the extra Quick Controls rows that were only there for those experiments.
- Polished the Rogue Slice and Dice helper in `SuperSwingTimer_ClassMods.lua`: it is anchored directly above MH again, hides whenever the MH bar itself is hidden, and rechecks the player buff state on a short throttle so it is less sensitive to late aura updates.

## Active Context Update (2026-05-17 - rogue combo-point strip follow-up)

- Added a Rogue-only five-box combo-point strip in `SuperSwingTimer_ClassMods.lua`, `SuperSwingTimer.lua`, `SuperSwingTimer_Config.lua`, `SuperSwingTimer_UI.lua`, and defaults/migration wiring: the strip sits directly above MH, fits the full MH width with compact 4px-tall boxes, reads current-target points from `GetComboPoints("player", "target")`, refreshes on `UNIT_COMBO_POINTS` plus `PLAYER_TARGET_CHANGED`, and has its own Quick Controls toggle/color row.
- Stacked the existing Rogue Slice and Dice bar above that combo-point strip instead of directly on MH, while keeping the paired Rogue energy helpers untouched to the left of the MH/OH stack.

## Active Context Update (2026-05-17 - rogue energy battery test follow-up)

- Reworked the Rogue energy helper test pass in `SuperSwingTimer_ClassMods.lua`, `SuperSwingTimer_UI.lua`, and `SuperSwingTimer_Config.lua`: the old single vertical energy helper is now a paired 4px setup with a left tick bar and a right total-energy battery bar, both anchored to the left of the MH/OH stack, sharing the existing helper toggle, and exposing separate color swatches in Quick Controls.

## Active Context Update (2026-05-17 - v0.0.7 rogue aura and widget follow-up)

- Tightened the Rogue helper pass one more time: the Slice and Dice helper now reads player buffs through a Classic-safe `UnitBuff` / `UnitAura` signature-tolerant helper in `SuperSwingTimer_ClassMods.lua`, which fixes the SnD bar not appearing on current Classic/TBC clients where helpful-aura return positions differ.
- Rechecked Warcraft Wiki / Blizzard widget references during the same pass and kept `/sst` on the current `UIPanelScrollFrameTemplate` path for production safety, while documenting `HybridScrollFrame` only as a future optimization for very long picker lists instead of doing a risky late rewrite.

## Active Context Update (2026-05-17 - v0.0.6 rogue Slice and Dice pass)

- Added the last Rogue production helper in `SuperSwingTimer_ClassMods.lua`, `SuperSwingTimer_UI.lua`, `SuperSwingTimer_Config.lua`, and bootstrap/default wiring: Rogues now get a slim Slice and Dice duration bar above the MH bar that tracks the active buff from `UnitAura` in real time, uses the shared bar texture/background/border styling path, and exposes its own toggle/color control in Quick Controls.
- Tightened the slimmer live profile again during the same pass by reducing the derived OH default from 10px to 8px while keeping the new SnD helper clamped to a 3-4px height.

## Active Context Update (2026-05-17 - rogue helper polish follow-up)

- Polished the Rogue helpers in `SuperSwingTimer_ClassMods.lua` and `SuperSwingTimer_Config.lua`: the Sinister Strike end-window now keeps a softer default alpha and slightly softens again while it is showing from the weapon-speed fallback path instead of a live swing, the vertical Rogue energy helper now fills upward again, and the existing Rogue energy checkbox in Quick Controls is labeled more clearly as `Rogue Energy Helper`.

## Active Context Update (2026-05-17 - release polish ui follow-up)

- Polished the `/sst` shell for release in `SuperSwingTimer_Config.lua`: config backdrops now go through an optional `BackdropTemplate` helper for safer Classic/TBC compatibility, the main options scrollframe supports mouse-wheel scrolling, and the Quick Controls section now pushes the next header down from its real runtime height so Rogue/Hunter rows cannot overlap the next section.
- Rechecked the shared live visibility path during the same pass and left the current gameplay behavior intact on purpose: live bars remain hidden out of combat, while `/sst` preview/Test Bars stay on their separate explicit preview path. The panel subtitle and README now call that split out more clearly.

## Active Context Update (2026-05-17 - visibility correction follow-up)

- Corrected the over-broad visibility regression in `SuperSwingTimer_UI.lua`: normal gameplay bars are combat-only again, hidden bars now reset their displayed value back to empty, and entering combat no longer shows stale full MH/OH/ranged/enemy bars before the first live timer begins.

## Active Context Update (2026-05-17 - active-timer visibility follow-up)

- Found the broader visibility gap after Rogue testing: melee/enemy bars were still stricter than ranged and would not show from their own active timers. `SuperSwingTimer_UI.lua` now lets MH/OH/enemy bars stay visible whenever their real timer state is active, and `SuperSwingTimer_State.lua` now reapplies shared visibility immediately on timer start/reset so melee bars no longer wait for a separate later event to wake them up.

## Active Context Update (2026-05-17 - rogue combat visibility fix)

- Found the likely root cause of Rogue melee bars not appearing until a later unrelated path refreshed visibility: `SuperSwingTimer_UI.lua` was still depending only on `InCombatLockdown()` timing inside `ApplyVisibility()`. The addon now tracks combat explicitly from `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` in `SuperSwingTimer.lua` and feeds that shared flag into visibility decisions, which should make Rogue MH/OH bars appear reliably as soon as combat starts.

## Active Context Update (2026-05-17 - rogue cue consistency follow-up)

- Tightened the Rogue helper one more time in `SuperSwingTimer_ClassMods.lua`: the SS cue no longer requires an already-active MH swing timer and now falls back to the live MH weapon speed whenever the MH bar itself is visible, which keeps the cue present at opener and other brief timer-idle moments during Rogue testing.

## Active Context Update (2026-05-17 - all-classes final polish)

- Rechecked the remaining class-specific timing paths and tightened only the two real regressions: BC Classic Hunter Multi-Shot now seeds the dedicated hunter helper bar from stored state when the client exposes no live cast, and the Rogue Sinister cue now stays visually under the shared spark so the spark remains readable through the red end slice.
- Kept the shared spark-height model unchanged because it was already correct for the slimmer v0.0.5 profile: the default spark height follows the 15px main bars, clamps down to the 10px OH bar and 10px hunter helper bar automatically, and does not need a separate per-class default override.

## Active Context Update (2026-05-16 - hunter startup and visibility hardening)

- Hardened the Hunter path in `SuperSwingTimer.lua` and `SuperSwingTimer_UI.lua`: `START_AUTOREPEAT_SPELL` now seeds the ranged timer immediately instead of requiring the cooldown API to already be active, `SPELL_UPDATE_COOLDOWN` refreshes visibility after hunter cooldown sync/start, and the combat-entry `ShowBars()` helper now defers to `ns.ApplyVisibility()` so ranged/hunter bars follow the same visibility rules as the rest of the addon.

## Active Context Update (2026-05-16 - config open-path hardening)

- Hardened `SuperSwingTimer_Config.lua` so `/sst` now lazily re-initializes the panel if needed, the quick color swatches use pure texture-backed buttons instead of backdrop-on-button styling, and the pre-show color refresh is guarded so one malformed color row cannot block the whole panel from opening.

## Active Context Update (2026-05-16 - config row interaction hardening)

- Hardened `SuperSwingTimer_Config.lua` row click handling so row-level helper clicks now back off when the cursor is already on the real button, toggle, or dropdown control, preventing duplicate activations that could make the `/sst` panel feel buggy.

## Active Context Update (2026-05-16 - config swatch bugfix)

- Fixed the `/sst` color selector regression in `SuperSwingTimer_Config.lua` by replacing the broken button-template override with a plain `BackdropTemplate` preview tile that keeps a visible gray base behind each swatch, restoring the missing-but-clickable quick colors and the Hunter/class color rows.

## Active Context Update (2026-05-16 - config color swatch readability follow-up)

- Reworked `CreateColorButton` in `SuperSwingTimer_Config.lua` so the `/sst` color selectors now use flatter high-contrast preview tiles instead of washed-out stock button art, which makes the chosen MH/OH/ranged/enemy/Rogue/Hunter colors much easier to read during setup.

## Active Context Update (2026-05-16 - final fit-and-finish quick-controls, Rogue test bar, and spark polish)

- Tightened the `/sst` top Quick Controls layout so the two-column toggle/color area now uses compact non-overlapping row spacing and no longer collides when Rogue/Hunter-specific quick rows are present.
- Polished the Rogue test energy helper in `SuperSwingTimer_ClassMods.lua`: it is now a 5px-wide vertical bar that matches the visible MH/OH bar heights (25px at the stock 15px MH + 10px OH profile) instead of stretching across the inter-bar gap.
- Polished `SuperSwingTimer_UI.lua` spark positioning for the thinner stock profile by pixel-snapping the live fill-edge anchor and adding a very small forward bias so the 3px spark reads closer to the true leading edge.

## Active Context Update (2026-05-16 - final pre-test Rogue energy tick and slimmer live profile)

- Tightened the live v0.0.5 bar profile again before gameplay testing: shared main bars now default to 15px, the OH bar derives to 10px, and the default spark height follows the slimmer main bars while still clamping to each specific host bar.
- Added a Rogue-only test energy-tick helper in `SuperSwingTimer_ClassMods.lua`: a slim vertical status bar anchored to the left of the MH/OH stack that uses `StatusBar:SetOrientation("VERTICAL")`, `SetReverseFill(true)`, `UnitPower("player")`, and Rogue-only `UNIT_POWER_UPDATE` / `UNIT_POWER_FREQUENT` hooks to track the observed 2-second energy cadence without touching the authoritative swing timers.
- Added SavedVariables defaults/migration/reset support plus top quick-control toggle/color wiring for `showRogueEnergyTick` and the `rogueEnergyTick` color, while keeping the existing Rogue Sinister Strike end-window cue MH-only.

## Active Context Update (2026-05-16 - v0.0.5 rogue cue and quick-controls pass)

- Reworked the top of `/sst` into a two-column Quick Controls section so the most-used visibility toggles stay in a left column while the primary bar-color swatches live in a right column near the top of the panel.
- Moved the core bar color controls into that top section, keeping class-specific quick colors conditional: Hunter Auto Shot safe/unsafe colors show only on Hunter, Rogue gets a dedicated `Rogue SS Cue Color`, and Paladin keeps the seal line swatch available without leaving the core bar colors buried far down the panel.
- Added a Rogue-only MH overlay in `SuperSwingTimer_ClassMods.lua` that paints a latency-adjusted red end window on the right side of the MH bar. The window uses cached latency plus a small input cushion so pressing Sinister Strike as the bar enters the red slice better lands it immediately after the main-hand swing without changing the authoritative swing clock.
- Added SavedVariables defaults/migration/reset support for `showRogueSinisterAssist` and the `rogueSinister` helper color, and hooked the new Rogue overlay into bar-color, bar-size, visibility, minimal-mode, and overlay-layer refresh paths so it behaves like the other class overlays.
- Hid the shaman-only weave config section on non-shaman classes for a cleaner production panel.

## Active Context Update (2026-05-15 - v0.0.4 enemy bar and spark sync pass)

- Added a new current-target enemy swing bar path that tracks the selected hostile target through `PLAYER_TARGET_CHANGED`, `UnitGUID("target")`, `UnitAttackSpeed("target")`, and hostile target `SWING_DAMAGE` / `SWING_MISSED` combat-log events while ignoring off-hand enemy hits to keep the single enemy bar readable.
- The enemy bar now has SavedVariables defaults/migration, its own red default color and saved anchor, a `/sst` visibility toggle, and an `Enemy Color` swatch in the color section.
- Centralized main-bar spark positioning in the UI module so the spark anchors from the actual rendered status-bar fill edge instead of only bar-width math; the stock spark width is now 3px and older untouched 4px installs migrate down to that default.
- Timing follow-up: tightened hunter ranged live resync by reusing the active Auto Shot cooldown start anchor from `GetSpellCooldown(75)` during mid-swing sync instead of only rescaling duration, and then moved cached latency off the shared base timer clock so swing motion stays on a `GetTime()`-aligned precise time path while predictive windows still apply latency separately.
- Weave follow-up: `SuperSwingTimer_Weaving.lua` now carries the tracked spell icon through the weave display info, the shaman class-mod overlay swaps the old triangle markers to those small spell icons, and the breakpoint marker itself stays fixed on the full cast-time-plus-latency start point while the separate weave spark still shows live cast progress.
- Timing audit follow-up: rechecked the remaining cast/channel timing paths against current Warcraft Wiki docs and kept the final split explicit — swing timers and movement anchors now stay on a `GetTime()`-aligned precise clock, while cached latency is only added to predictive windows such as Auto Shot safe-stop timing and weave clip math.
- Hunter/UI follow-up: `/sst` now exposes `Auto Shot Safe Color` and `Auto Shot Unsafe Color` swatches so the ranged cast-window feedback can be tuned independently from the base ranged bar color.
- Visibility follow-up: `SuperSwingTimer_UI.lua` now gates the shared `ApplyVisibility()` path behind combat state for MH/OH/enemy bars, which stops out-of-combat reappearance after config refreshes or OH/equipment apply paths while still allowing Test Bars preview and live ranged visibility.
- Preview cleanup follow-up: ending Test Bars preview now restores the shared visibility helper instead of force-hiding all bars, which keeps live out-of-combat ranged visibility consistent after preview mode ends.
- TOC metadata, README, changelog, API/UI notes, AGENTS, and memory-bank progress were updated for the requested v0.0.4 release line.

## Active Context Update (2026-05-05 - bar texture picker final UI polish)

- Replaced the MH/OH and ranged nested texture dropdown path with a scrolling full-preview bar-texture picker that stretches each texture across the row behind its label.
- The new bar picker stays fixed-height with scroll support, anchors from the texture control, and keeps bar textures focused on Blizzard fallbacks plus LibSharedMedia / WeakAuras / installed addon bar media instead of paging through nested UIDropDownMenu categories.
- Spark and weave-spark selection remain on the thumbnail-browser path, so the bar picker change stays isolated to bar-style media only.

## Active Context Update (2026-05-05 - final release prep timing and UI pass)

- Verified against warcraft.wiki that BCC Anniversary `UNIT_SPELLCAST_START` uses `unitTarget, castGUID, spellID` (and related `UNIT_SPELLCAST_*` events stay on the spell-ID payload path), then restored the addon's state/classmod/weaving handlers to resolve spell IDs instead of treating the second argument as a spell name.
- Re-validated the timer clock against current Classic/TBC API references: the addon remains on latency-adjusted `GetTimePreciseSec()` / `GetTime()`, primes the precise clock once, and keeps MH/OH/ranged swing anchors, queued next-attack landed resets, parry haste, and druid form resets on that existing live timer path after the experimental CLEU remap made timers lead early.
- Kept Hunter's core ranged timer path intact while stabilizing the dedicated hidden cast bar on the same end-of-cycle stop-to-fire window as the ranged red/green feedback.
- Fixed the `/sst` MH/OH layout so the `Bar Width` slider sits below the section header instead of sharing the collapse-toggle hit area.

## Active Context Update (2026-05-05 - class-local next-attack isolation)

- The queued next-attack path is now fully class-local: Warrior Heroic Strike / Cleave, Druid Maul, and Hunter Raptor Strike each keep their own queued state and interruption cleanup instead of sharing one generic pending queue path.
- `SuperSwingTimer_State.lua` no longer relies on a shared next-attack landed-hit lookup table; queued MH resets now check only the active class spell tables.
- Druid Maul now uses its own bear-yellow tint, while queued next-attack tint remains MH-fill-only and does not touch spark color.

## Active Context Update (2026-05-04 - final production polish and class/UI correctness)

- Narrowed the hunter follow-up back to the dedicated Auto Shot cast-bar path: the hidden cast bar stays locked to the end-of-cycle stop-to-fire window and no longer bounces, while the broader hunter ranged start/restart behavior was restored to the previous live path.
- Ret paladin reseal math now uses current swing elapsed plus remaining GCD time, which matches the intended twist-bar behavior much more closely than a simple `duration - gcdRemaining` offset.
- Shaman weave spell-name resolution now routes through `ns.GetSpellInfo`, and weave visuals now stay hidden when Minimal Mode or the weave-assist toggle disables them.
- UI/setup polish: the OH bar is reused safely across equipment swaps, anchor bars now use true drag start/stop handlers plus a wider hit area, Reset Defaults restores saved positions, and Test Bars / config preview now force created bars visible after the normal visibility pass.
- Off-hand starts still require a real OH weapon speed so empty off-hand slots cannot carry hidden OH swing state.

## Active Context Update (2026-05-04 - class-color restore and spark blend correction)

- `Use Class Colors` now keeps the stored manual MH/OH/ranged colors intact while the toggle is on, and turning it off restores those saved manual colors instead of leaving class tint baked into the saved values.
- Added a fallback cleanup path so older saved bar/spark colors that still exactly match the class color can snap back to defaults when class colors are turned off.
- The main swing spark now uses a color-preserving `BLEND` mode so a white/manual spark stays visually white instead of looking warmed by the colored bar fill underneath.

## Active Context Update (2026-05-04 - queued-melee tint ownership split)

- Warrior Heroic Strike / Cleave and druid Maul now track queued-tint ownership separately via class-specific pending queue state instead of sharing one generic NMA pending-tint path.
- The shared `HandleSpellcastSucceeded` path no longer writes queued tint state for all NMAs, which prevents Maul from piggybacking on Warrior queue cleanup semantics.
- World/combat reset and interrupted/failed queue cleanup now clear the pending tint through the correct class-specific owner path.

## Active Context Update (2026-05-04 - one-time stale class-color cleanup)

- Added a one-time SavedVariables migration that detects the old broken account-wide class-color bleed case: if class colors are off but MH/OH/ranged all still exactly match the same WoW class color, the addon now resets them to the default black palette on load.
- The same migration also resets the spark to white when its saved tint matches that same stale class-colored palette.
- This specifically covers old druid-colored saves bleeding into Warrior or other classes even after the live tint hooks were already fixed.

## Active Context Update (2026-05-04 - spark/color decoupling and hunter hidden-window lock)

- Decoupled the shared spark tint from `useClassColors`, so Heroic Strike / Cleave / Maul queued-bar fill colors no longer imply a spark recolor and white/manual spark choices stay readable.
- Locked the hunter hidden cast window to a stable end-of-cycle anchor per ranged cycle, preventing the dedicated Auto Shot cast bar from bouncing when the ranged timer is movement-pinned in the red zone.
- Stopped the UI/state fallback paths from persisting synthetic Auto Shot cast state outside the hidden-window path, reducing random cast-bar activations near the end of the hunter cycle.
- Hardened interrupted / failed Maul cleanup so the druid queue tint can restore through the druid clear path.

## Active Context Update (2026-05-01 - TBC Anniversary Compatibility & Hunter Sync)

- Achieved full TBC Classic Anniversary (1.15.x) engine support by implementing a robust `ns.GetSpellInfo` wrapper and safe-accessing Blizzard UI globals via `_G`.
- Synchronized the dedicated Hunter cast bar with the ranged timer's latency-aware "red zone," providing perfect visual alignment for move-safety feedback.
- Optimized the configuration UI with 20-item paging and texture previews, and enforced high-visibility defaults (Class Colors: OFF).

## Active Context Update (2026-04-30 - hunter ranged reset-state hardening)

- `ResetTimer("ranged")` now also clears hunter cast state, preventing stale hidden-cast bar remnants when ranged cycling is explicitly stopped/reset.

## Active Context Update (2026-04-30 - hunter end-of-cycle hidden cast window)

- Hunter cast-bar display now includes a ranged-timer-derived hidden cast window path (`windowEnd - ns.CAST_WINDOW`) so the cast bar reflects the stop-to-fire period at the end of the ranged cycle.
- Hunter `HandleSpellcastSucceeded` no longer forces a synthetic post-shot cast window when no active hunter cast can be confirmed.

## Active Context Update (2026-04-30 - broad audit hunter fallback fix)

- During broad release audit, found and fixed a hunter cast fallback bug in `HandleSpellcastSucceeded`: the fallback start time now uses `now` instead of `now - CAST_WINDOW`, so missed-start-event recovery shows a full cast window instead of instantly completing.

## Active Context Update (2026-04-30 - release hardening haste fallbacks)

- Added ranged-haste-aware fallback scaling in `SuperSwingTimer_State.lua` so hunter ranged timers can still resync if `UnitRangedDamage()` temporarily fails to return a usable speed.
- Added explicit `GetRangedHaste` fallback handling in ranged state helpers.
- Added `GetSpellHaste` fallback handling in `SuperSwingTimer_Weaving.lua` so shaman weave spell-haste math remains available when `UnitSpellHaste("player")` is unavailable.

## Active Context Update (2026-04-30 - hunter cast-start window and player-only speed events)

- Hunter hidden cast-window timing was refined again: the fixed `ns.CAST_WINDOW` bar now anchors to cast/shot start timing instead of end-of-cycle alignment, which keeps the cast bar focused on the actual move-safe hidden cast period.
- `UNIT_ATTACK_SPEED` and `UNIT_RANGEDDAMAGE` sync handlers now filter to `unit == "player"` before forcing timer resync, reducing unnecessary event work.

## Active Context Update (2026-04-30 - hunter cast-window separation and swing-start sync)

- Hunter cast-bar timing is now fully separated from ranged swing duration: the cast bar uses a fixed `ns.CAST_WINDOW` window only, instead of inheriting full ranged cooldown duration.
- Hunter cast-window start alignment now prefers end-of-cast timing, so the bar reflects the hidden Auto Shot move-safe window more accurately.
- Swing starts now trigger an immediate speed resync (melee/ranged) to reduce first-frame timer drift and tighten white-swing/ranged alignment.

## Active Context Update (2026-04-30 - final state and class-module polish)

- Repaired `SuperSwingTimer_State.lua` after rejection by removing a duplicated `ResetTimer` definition so the start/stop/restart paths all flow through one canonical timer reset implementation.
- Exported `ns.ClearHunterCastState` and now clear hunter cast state on world/combat reset paths, which prevents stale hunter cast-bar state from leaking across state resets.
- Hardened hunter cast-bar detection so `UnitCastingInfo` spell-name payloads can still resolve hunter cast spells when spell IDs are absent in Classic-era payloads.
- Fixed shaman weave color stability by cloning spell-family colors before applying unsafe alpha, preventing accidental mutation of shared constants.
- Re-polished ret paladin seal-twist visuals so the end-of-swing strike marker stays visible for active twist families and the reseal marker remains GCD-aware.

## Active Context Update (2026-04-29 - final release polish pass)

- The hunter Auto Shot / Multi-Shot cast bar now uses the shared `ns.CAST_WINDOW` timing instead of a duplicate 0.5s constant, and it has a `UnitCastingInfo` fallback so the dedicated cast bar can still recover if the live hunter cast state is briefly missing.
- Warrior queue tinting now scans only numeric queued-spell IDs so Heroic Strike and Cleave can light up and clear reliably without string-key false positives, while Slam still uses the pause/extend path.
- The unlocked drag hitbox is wider now so the bars are easier to grab and move during setup.
- The README was expanded into a more professional project page with at-a-glance tables, a timing-model table, a texture-source table, and a note to prefer tables/images over Mermaid on CurseForge-facing pages.

- The hunter Auto Shot / Multi-Shot bar now uses a separate active-state path, so Auto Shot keeps its cooldown preview alive instead of being cleared immediately by the generic stop event.
- `/sst` now has a temporary Test Bars action plus a clearer `Lock / Unlock Bars` control, which makes moving the frames much easier when the preview is visible.
- The main bar color swatches now open the color picker with opacity enabled, so class colors and custom colors can keep their alpha while the live update paths stay in sync.
- The `/sst` docs, changelog, and TOC were updated to match the final release polish pass.

## Active Context Update (2026-04-29 - final hunter cast-bar and collapsible section polish)

- The base spark width is back to 4px, the spark tint now follows the ranged class color by default when class colors are enabled, and the Hunter Auto Shot / Multi-Shot cast bar now uses stored cast timing so it can render reliably instead of depending solely on live `UnitCastingInfo`.
- The `/sst` collapsible row groups have been stabilized again, and the spark / weave defaults were slimmed to compact bar-height-aligned markers so the glow cannot render as a full-height white block.
- The Hunter Auto Shot / Multi-Shot cast bar now keeps a separate test-preview path so it can be shown for repositioning while the panel is open, while the live bar itself still uses its separate active-state logic beneath the ranged timer.
- The Hunter Auto Shot / Multi-Shot cast bar now stays cast-only, so it appears beneath the ranged timer only while a tracked hunter cast is actually in progress.
- The update loop now stays alive for channeling (`ns.channeling`) so channel-based ranged visuals can keep animating even if no swing timer is active.
- The `/sst` panel section headers now collapse/expand their row groups, giving the config UI a more WeakAuras-like section workflow while keeping the existing texture / color / slider layout intact.
- The changelog and UI notes were refreshed so the release docs match the final cast-bar and config polish pass.

## Active Context Update (2026-04-29 - hunter cast bar and TBC spell IDs)

- Hunter now has a dedicated 10px Auto Shot / Multi-Shot cast bar beneath the ranged timer, and it stays tied to the ranged bar's texture, spark settings, and visibility rules instead of floating independently.
- The hunter spellcast handlers now read Classic's 3-argument `UNIT_SPELLCAST_*` payloads, which lets the cast state and swing-reset logic see the live spell ID correctly.
- The TBC Multi-Shot ranks and Slam ranks 5-6 were synced into the addon tables and the `docs/swingtimer.md` reference so the no-reset and pause logic stay aligned before release.

## Active Context Update (2026-04-29 - texture catalog and browser polish)

- The MH/OH and ranged texture rows now filter down to bar-style textures from Blizzard, SharedMedia, WeakAuras, and installed addon packs, so the bar selectors stay focused on actual bar skins.
- The spark row and the shaman weave spark row now open folder-style thumbnail browsers, the browse buttons use the WeakAuras browse icon, and the spark alpha slider is restored in the config panel.
- `README.md`, `CHANGELOG.md`, `docs/SharedMedia.md`, and `docs/UI.md` were refreshed so the user-facing docs match the broader texture catalog and the new picker behavior.

## Active Context Update (2026-04-29 - spark picker final polish)

- The MH/OH spark texture row now opens a dedicated square-thumbnail browser instead of the old rectangular selector, and the browser title / tooltip copy now reads like a polished final-release picker.
- The WeakAuras `Square_FullWhite` spark preset is surfaced as `Normal`, while the shaman weave spark now reads as `Target Indicator`; the alternate triangle shape remains available in the same texture library.
- `README.md`, `CHANGELOG.md`, `SuperSwingTimer.toc`, `docs/SharedMedia.md`, and `docs/UI.md` were refreshed so the release notes, metadata, and UI docs match the polished spark picker and final wording.

## Active Context Update (2026-04-28 - ranged safe-state and WeakAuras bridge)

- The hunter ranged cast window now has a true green-safe state: the red zone turns green when the player stops before the breakpoint, while still staying red if the player is moving too late.
- `SuperSwingTimer_UI.lua` now uses a movement-stop timestamp plus the existing latency-aware breakpoint math to color the cast window and the overlay consistently.
- `README.md`, `CHANGELOG.md`, and `SuperSwingTimer.toc` were refreshed so the user-facing docs and addon metadata match the new green/red ranged feedback.
- `docs/swingtimer.md` was updated to mirror the current addon timing model more closely, including Auto Shot cooldown preference, ranged resync hooks, and clearer start/end/reset/restart comments.
- `docs/WeakAuras/Expert-Patterns.md` now includes a bridge example for consuming swing-timer events and carrying the ranged safe-state into a WeakAura state table.

## Active Context Update (2026-04-27 - dropdown interaction and spark refresh cleanup)

- Dropdown rows now open from the full row body, the old texture-browser popup was removed, and the moving spark anchors are cleared before each update so the visuals stay stable and the config is easier to use.
- Added subtle hover highlights to the interactive rows so the dropdowns, toggles, and texture selectors are easier to discover at a glance.
- Enabled mouse interaction on the texture rows so the hover highlight and click-open dropdown behavior actually activates.
- Added hover tooltips to the config rows and controls so the panel now explains what each setting represents when hovered.

## Active Context Update (2026-04-27 - overlay frame and UI control refit)

- Moved hunter, shaman, and ret paladin visual cues onto dedicated non-mouse overlay frames above each bar so the spark / breakpoint markers no longer depend on the HIGHLIGHT draw layer and cannot disappear on hover.
- Converted the cycle-style config rows to visible dropdowns and added editable numeric boxes beside the slider rows for faster direct value entry.
- Synced `README.md` and `docs/UI.md` to describe the dropdown selectors, numeric fields, and overlay-frame behavior.

## Active Context Update (2026-04-27 - hunter spark / breakpoint visibility fix)

- Fixed the overlay visibility regression by keeping the MH / OH / ranged bar fills on their requested draw layer and forcing spark / breakpoint overlays one sublayer above the fill again.
- Clarified the `/sst` subtitle so it tells players to hover for help and use the right-side controls to change settings.
- Added a changelog note for the visibility fix so the hunter, shaman, and ret paladin marker behavior stays documented.

## Active Context Update (2026-04-24 - breakpoint overlays above bar fill)

- Added a shared above-bar texture-layer helper so breakpoint visuals stay visible even if the bar texture layer is raised.
- Rewired the shaman weave spark, triangles, the ranged cast-threshold marker, and the ret paladin seal breakpoint lines to use that above-bar layering path.
- Updated shaman weave positioning to use the actual MH bar width instead of only the static default width.
- Synced README.md and CHANGELOG.md with the new above-bar breakpoint behavior; the addon TOC already carries v3.1.2.

## Active Context Update (2026-04-24 - final paladin seal coverage)

- Expanded the paladin seal family table to match `docs/spellIds.md` for Command, Corruption, Blood, Martyr, Vengeance, Justice, Wisdom, Righteousness, Light, and Crusader.
- Restored the ret paladin breakpoint line so the actual strike-edge marker stays visible again, with a second latency-aware reseal marker for twist seals, still aura-driven and opaque black.
- Anchored Hunter Auto Shot cooldown start to the addon’s latency-adjusted clock so the ranged timer and cooldown API stay on the same time base.
- Re-reviewed the shaman weave-assist and melee white-damage reset/start flow; no further structural changes were needed in this pass.

## Active Context Update (2026-04-23 - final hunter/paladin polish pass)

- Anchored Hunter Auto Shot to the cooldown API start time when active, while keeping `UnitRangedDamage()` as the ranged-speed fallback.
- Hardened the paladin seal breakpoint lookup so it prefers aura names, still falls back to verified spell IDs, and survives missing rank IDs with localized name fallback.
- Reviewed the shaman and melee white-damage end/reset/start paths again; no further structural changes were needed in this pass.
- Updated the changelog and repo notes to reflect the final accuracy pass.

## Active Context Update (2026-04-23 - hunter cooldown API and paladin polish)

- Hunter Auto Shot now uses `GetSpellCooldown(75)` / `GetSpellCooldown("Auto Shot")` as the authoritative active-cooldown signal, with `UnitRangedDamage()` first-return ranged speed as the haste-aware fallback.
- `SPELL_UPDATE_COOLDOWN` now participates in hunter start/resync so the ranged bar can react immediately when Auto Shot becomes active.
- The ret paladin seal breakpoint line remains UnitAura-driven, latency-aware, and opaque black, with the seal family table kept in sync with the active aura.
- README, API notes, changelog, and the addon TOC were updated to match the API-backed hunter timing path.

## Active Context Update (2026-04-23 - config reflow and seal-twist timing pass)

- Reworked the `/sst` config rows so labels sit above the controls and the texture, cycle, toggle, and color rows are clickable across the row.
- Made the ret paladin seal-twist overlay latency-aware by expanding the fixed 0.4s window with cached latency.
- Refreshed the README and changelog to match the reflowed UI and updated timing notes.
- Hunter validation is still the final in-game test step.

## Active Context Update (2026-04-23 - hunter Auto Shot test-ready)

- Hunter Auto Shot now has a latency-aware red-zone marker, a dedicated ranged texture picker, and deduped start handling across CLEU and spellcast success.
- The `/sst` panel now separates MH/OH, ranged, and weave-breakpoint appearance controls more clearly.
- Current focus is in-game validation for the hunter timing path, then the paladin seal-twist review.
- Seal-twist behavior is still handled in the ret paladin class mod; the width is driven by a fixed 0.4s window and the color comes from SavedVariables.

## Active Context Update (2026-04-23 - hunter Auto Shot marker and ranged texture split)

- Added a latency-aware black threshold marker to the hunter Auto Shot bar so the red cast window is visible before it starts.
- Added a dedicated ranged bar texture selector so hunters can skin Auto Shot separately from MH / OH bars.
- Widened the `/sst` panel and relabeled the appearance rows to clearly separate MH/OH, ranged, and weave-breakpoint controls.
- Kept the existing Blizzard AddOns registration, class-color defaults, and indicator glow/opaque toggle intact.
- Targeted diagnostics on the touched runtime files still need to be run/confirmed after the latest UI pass.

## Active Context Update (2026-04-23 - Blizzard options, class colors, and preview polish)

- Registered the addon in Blizzard's Interface Options / AddOns flow and added TOC icon metadata for the addon list.
- Switched the primary slash aliases to `/sst`, `/super`, and `/superswingtimer`, removing the old `/swangthang` alias.
- Default MH / OH / ranged bar colors now follow the player's class color until custom swatches are chosen; a `Use Class Colors` toggle now makes that mode explicit.
- Added an `Indicator Glow Mode` toggle so sparks and weave markers can switch between bright additive glow and a more opaque blend.
- Reworked the texture dropdown into a preview-based picker, widened and relabeled the `/sst` panel, and tightened the row spacing/section labels.
- Targeted diagnostics on the touched runtime files are clean after the UI pass.

## Active Context Update (2026-04-23 - weave family controls and UI polish)

- Added color-coded, individually disable-able weave-family toggles for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal.
- Made the weave marker pair smaller and clearer by retitling the controls as upper/lower marker settings.
- Widened the `/sst` panel and added a bottom legend/description block for the weave families.
- Targeted diagnostics on the edited runtime files are clean after the weave/UI pass.

## Current focus

1. **v0.1.3 is in development** (2026-06-19) — Combat bar drag + camera interaction fix.
2. **Completed**: 
   - Hunter cast bar color separation, height increase, bar-jumping critical fix, stance icon, CD/buff icon group.
   - **Combat bar drag fix**: Bars can now be left-click dragged even during combat when unlocked.
     - Removed `inCombat` blanket mouse-disable in `ns.ApplyLockBars()` — mouse stays enabled on unlocked bars during combat.
     - Right-click camera control preserved via pre-existing `SetPropagateMouseClicks(true)`.
     - Added manual drag (cursor delta tracking via `GetCursorPosition`/`SetPoint`) for combat, since `StartMoving()` is protected during combat lockdown.
3. **Pending in-game validation**: All changes need testing on a live Classic/TBC Anniversary client.

## What we know right now

- The `hunterCastBar` color key is now independent from `ranged` at all three wiring points (CreateHunterCastBar, ApplyHunterCastBarColor, ApplyBarColors).
- A config swatch "Cast Bar" was added to the Quick Controls section for Hunters.
- The cast bar height default was increased from 10px to 13px.
- The bar-jumping bug (MH bar flickering during ranged-only auto shot cycles) is fixed via a 0.1s `rangedTimerHoldEnd` mechanism.
- Hunter stance icon is implemented: an icon frame left of the range helper bar showing the active Aspect (Hawk, Cheetah, Monkey, Pack, Wild, Viper, Beast) via GetSpellTexture.
- Hunter CD/buff icon group is implemented: 25x25px icons for Bestial Wrath, Rapid Fire, The Beast Within, Quick Shots, and Rapid Killing. Icons dim as buffs expire with duration countdown text.
- Migration v49 seeds the new hunterCastBar color for existing users.

## Likely bug area

- `UpdateHunterAspect` and `UpdateHunterBuffIcons` in `SuperSwingTimer_ClassMods.lua` — new code paths that need in-game validation.
- `ns.ApplyVisibility()` — the `rangedTimerHoldEnd` logic needs testing to ensure the fix works without causing the ranged bar to stay visible longer than intended.

## Working assumptions

- The aspect icon visibility follows the ranged bar + range helper visibility (hidden when range helper is hidden).
- The buff icons stack horizontally above the ranged bar, expanding leftward as more buffs become active.
- `GetSpellTexture` resolves spell icons reliably on Classic/TBC Anniversary clients.

## Next steps

1. **In-game validation**: Test all changes on a live Classic/TBC Anniversary client.
2. **Config toggle for buff icons**: Add a `showHunterBuffIcons` toggle in Quick Controls.
3. **TOC update**: v0.1.3 bumped.
4. **CHANGELOG/README**: Updated for v0.1.3.
