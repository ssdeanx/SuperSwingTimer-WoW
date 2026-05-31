# AGENTS.md - Super Swing Timer

## Project overview

Super Swing Timer is a World of Warcraft Classic/TBC addon for swing-timer tracking.
It shows melee and ranged bars for supported classes, with class-specific
behavior for hunter auto shot, warrior slam/NMA handling, parry haste, druid
form resets, ret paladin seal-twist timing, and shaman weaving breakpoint help.

## Runtime target baseline (critical)

- This repo targets **World of Warcraft: Burning Crusade Classic Anniversary Edition**
  (**2026 live branch**, current addon target patch line: **2.5.5**).
- Do **not** treat this project as the original 2021 BC Classic launch branch.
- Practical engineering implication: use Anniversary-era docs/source snapshots first,
  then verify behavior in-game when API payloads are known to vary in Classic
  families (especially aura/spellcast payload shape and optional return values).
- Gameplay-system changes from launch-era BC Classic (account-wide attunement flows,
  Edit Mode availability, etc.) are mostly non-addon API changes; they matter for
  user environment assumptions, not core swing-timer API semantics.

## Core file responsibilities

- `SuperSwingTimer.lua` â€” bootstrap, SavedVariables migration, slash commands,
  event registration, and addon initialization.
- `SuperSwingTimer_Constants.lua` â€” spell IDs, class config, default SavedVariables,
  and static tuning values.
- `SuperSwingTimer_State.lua` â€” timer state and combat-log / spellcast detection.
- `SuperSwingTimer_Weaving.lua` â€” shaman spell catalog, breakpoint math, and cast tracking.
- `SuperSwingTimer_UI.lua` â€” bar creation, visuals, drag handling, show/hide,
  and runtime apply functions for size, colors, and textures.
- `SuperSwingTimer_ClassMods.lua` â€” class-specific overlays and behavior hooks.
- `SuperSwingTimer_Config.lua` â€” the `/sst` settings panel and live preview.

## Working rules

- Follow WoW addon Lua conventions and keep compatibility with Classic-era UI
  APIs.
- Keep swing-timer logic on `OnUpdate` for per-frame bar updates; use
  `C_Timer` only for one-shot or low-frequency UI delays.
- When adding a new setting, update all of these together:
  1. `ns.DB_DEFAULTS`
  2. SavedVariables migration in `SuperSwingTimer.lua`
  3. Runtime apply function in `SuperSwingTimer_UI.lua`
  4. Config-panel controls in `SuperSwingTimer_Config.lua`
  5. Documentation (`README.md`)
  6. Addon version metadata (`SuperSwingTimer.toc`)
- Keep class-specific behavior isolated in `SuperSwingTimer_ClassMods.lua`.
- Preserve current defaults unless a change is explicitly requested.

## Texture-setting guidance

- Bar texture selection should be stored in SavedVariables and applied to all
  status bars consistently.
- Prefer built-in WoW texture paths unless a packaged media asset is added to
  the addon.
- If the config panel changes the texture, the preview bars should update live.

## Accuracy / API guidance

- Verify WoW Classic API behavior before relying on newer functions.
- For timer questions, `C_Timer.After` is one-shot, `C_Timer.NewTimer` is the
  single-fire helper, and short repeating work is still better handled with
  `OnUpdate`.
- If an API difference is unclear, check current wiki docs before coding.
- Prefer Anniversary-targeted references first (warcraft.wiki.gg BC Classic
  Anniversary pages + current classic branch UI source mirrors) before consulting
  older TBC Classic forum-era notes.

## Url references

- [WoW TBC & Classic API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API/Classic)
- [TBC Classic](https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Burning_Crusade_Classic_Anniversary_Edition)

## Research reference URLs

Use these links first when checking Classic addon UI behavior, widgets, frames, events, and Blizzard source examples.

- <https://wowpedia.fandom.com/wiki/World_of_Warcraft_API/Classic>
- <https://wowpedia.fandom.com/wiki/Lua_functions>
- <https://wowpedia.fandom.com/wiki/Widget_API>
- <https://wowpedia.fandom.com/wiki/Widget_script_handlers>
- <https://wowpedia.fandom.com/wiki/XML_schema>
- <https://wowpedia.fandom.com/wiki/FrameXML_functions>
- <https://wowpedia.fandom.com/wiki/Events/Classic>
- <https://wowpedia.fandom.com/wiki/Console_variables/Classic>
- <https://github.com/Gethe/wow-ui-source>
- <https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns/Blizzard_APIDocumentation>
- <https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns/Blizzard_APIDocumentationGenerated>

## Current progress

- v0.1.2 extreme timing/aura audit follow-up (2026-05-31): completed a deeper combat-simulation-style trace on the live timing and aura-consumer paths instead of treating helper behavior as "close enough." Fixed a real GCD ticker timing bug in `SuperSwingTimer_State.lua`/`SuperSwingTimer_UI.lua`: the ticker was being deactivated on `UNIT_SPELLCAST_STOP`, which could truncate the visible GCD window early; it now tracks the live 61304 cooldown through Anniversary-safe `C_Spell.GetSpellCooldown` with `GetSpellCooldown` fallback, refreshes on cast start/channel start/success, only clears on failure when no real cooldown is active, and self-expires cleanly in the renderer. Also corrected two real aura-shape bugs in `SuperSwingTimer_ClassMods.lua`: `GetHarmfulAuraData()` now reads harmful aura counts from the actual count slot, and Shaman shield charge tracking now reads the real aura stack field instead of the dispel-type slot, which previously could leave Lightning/Water Shield stuck at a fake default count. Reset hardening was extended so GCD state is explicitly cleared on world entry and combat end.

- v0.1.2 Shaman production pass before live testing (2026-05-31): completed a strict Shaman-only reliability pass in `SuperSwingTimer_ClassMods.lua` and fixed only code-proven failures. `GetShamanAuraRemaining()` now reads the shared `GetHelpfulAuraData()` helper correctly, so Shamanistic Rage duration/cooldown badge logic is no longer unpacking the wrong tuple shape. Weave breakpoint markers now use the tracked spell icon texture when available instead of always rendering fallback arrow textures. Flame Shock target tracking was hardened with a fallback from `UnitDebuff("target", index, "PLAYER")` to `UnitAura("target", index, "HARMFUL|PLAYER")`, and the Lightning/Water Shield charge tracker container is now parented/layered with the MH overlay, hides when the MH bar is not visible, and uses cleaner anchoring for MH-only vs dual-wield layouts. Targeted diagnostics on the edited Shaman runtime file are clean.

- v0.1.2 retry correction pass (2026-05-31): fixed a real mixed-state regression introduced during the prior migration/de-bloat work. `ns.DB_DEFAULTS.version` is aligned back to schema `47`, Druid stale-feature cleanup now happens inside migration `v47` instead of silently drifting defaults to `48`, and the supported Druid surface is now explicitly narrowed to Cat energy tick + Maul queue tint instead of half-removed dead helpers. Also restored the missing Druid runtime wiring: `UNIT_POWER_UPDATE` / `UNIT_POWER_FREQUENT` + `UPDATE_SHAPESHIFT_FORM` registration, `HandleDruidEnergyPowerUpdate()`, a real left-side Cat energy tick bar in `SuperSwingTimer_ClassMods.lua`, config toggle/color/width wiring, and Druid queue cleanup in `SuperSwingTimer_State.lua`.

- v0.1.2 migration table correctness repair (2026-05-30): restored the missing Druid migration steps in `SuperSwingTimer.lua` so the table now includes the original `v43 -> v44` and `v44 -> v45` behavior instead of compressing them into a gap. Also restored the corresponding Druid SavedVariables defaults/colors in `SuperSwingTimer_Constants.lua` so the migration steps have matching backing fields.

- v0.1.2 migration ladder refactor (2026-05-30): converted `MigrateDB()` in `SuperSwingTimer.lua` from a long chained `if (version < X)` ladder into an ordered table-driven migration list. Behavior was preserved step-for-step, and the resulting file now validates cleanly under targeted diagnostics. This reduces future migration-edit risk and makes the upgrade path more auditable.

- v0.1.2 deep fallback risk audit (2026-05-30): completed a full reliability sweep across all core Lua files with severity triage (critical/high/medium). No parser issues found. Applied additional hardening at `SuperSwingTimer_State.lua` CLEU entrypoint (`ns.HandleCLEU`) by guarding `CombatLogGetCurrentEventInfo` availability and empty-payload cases before dispatch logic. Combined with the prior UI input fallback wrappers, this reduces hard-failure risk on edge runtime/API states.

- v0.1.2 enterprise fallback hardening pass (2026-05-30): performed a reliability-focused fallback audit and strengthened the bar input/camera fallback path in `SuperSwingTimer_UI.lua` by adding guarded start/stop wrappers (`pcall`), tightening visibility gating to `IsShown + alpha`, and forcing cleanup of any active right-click fallback state when bars become mouse-disabled. This reduces edge-case camera/input desync risk without changing normal left-drag UX.

- v0.1.2 mouse-handler correction (2026-05-30): fixed a UI input bug in `SuperSwingTimer_UI.lua` where right-click fallback detection used `self.SetPropagateMouseClicks` directly inside frame handlers, which is not a reliable capability check. Bars now store explicit support as `sstHasPropagateMouseClicks` at creation and use that flag for right-click fallback routing.

- v0.1.2 mouse-input scope audit + propagation pass (2026-05-30): verified the camera-intercept risk path is localized to draggable core bars in `SuperSwingTimer_UI.lua`; class-mod helper overlays/bars in `SuperSwingTimer_ClassMods.lua` are already mouse-disabled. Added `SetPropagateMouseClicks(true)` on core status bars when API support exists so right-click camera/world input passes through naturally out of combat while left-click drag remains active when unlocked. Kept guarded right-click fallback logic for clients lacking click-propagation support.

- v0.1.2 combat camera safety fix (2026-05-30): after user escalation that any camera interruption is unacceptable in combat, hardened `ns.ApplyLockBars()` in `SuperSwingTimer_UI.lua` so bars never capture mouse while in combat (`ns.inCombat` / `InCombatLockdown` guard). This prevents right-click/turn input disruption from bar hitboxes mid-fight while preserving left-click drag behavior out of combat when unlocked.

- v0.1.2 right-click camera correction follow-up (2026-05-30): clarified user intent that camera control should work over bars in combat while bars remain left-draggable when unlocked. Updated `AttachDrag()` in `SuperSwingTimer_UI.lua` to use `TurnOrActionStart()` / `TurnOrActionStop()` for right-click camera behavior (with `MouselookStart/Stop` fallback), and added per-frame `sstRightCameraActive` guard + OnHide cleanup so stop calls only fire when the bar initiated camera mode.

- memory-bank protocol normalization (2026-05-30): reviewed the newly copied `memory-bank/memory-bank-instructions.md` (previously a generic cross-stack template) and rewrote it into a SuperSwingTimer-specific protocol. New version now encodes required load order, Anniversary 2026/2.5.5 runtime baseline, repo-specific settings wiring checklist, targeted `get_errors` validation flow, and mandatory AGENTS/activeContext/progress/doc sync after code changes.

- context hardening: anniversary-branch baseline update (2026-05-30): clarified project-wide guidance that this addon targets **BC Classic Anniversary Edition (2026, patch line 2.5.5)** and not the 2021 BC Classic launch branch. Added explicit notes in AGENTS + memory-bank context docs to prioritize Anniversary-targeted sources and treat gameplay-system changes (attunement/edit-mode era changes) as environment context rather than automatic addon-API changes.

- v0.1.2 lightweight-focus follow-up (2026-05-30): aligned implementation with user direction to keep SuperSwingTimer as a "WeakAuras-like but lightweight" combat helper. Removed stale post-streamline Druid schema bloat from runtime defaults/migrations (`showDruidTigerFuryBadge`, `showDruidFaerieFireBadge`, `showDruidMangleTimer`, `showDruidRipTracker`, and legacy Mangle/Rip color seeding) so stripped features are not silently re-added to SavedVariables. README/CHANGELOG were synced to reflect the streamlined Feral scope (form reset + Maul queue tint) and current helper focus.

- v0.1.2 full-core Lua audit for BCC Anniversary 2.5.5 (2026-05-30): completed a full review of all 7 core addon modules (`SuperSwingTimer.lua`, `_Constants.lua`, `_State.lua`, `_Weaving.lua`, `_UI.lua`, `_ClassMods.lua`, `_Config.lua`) with targeted diagnostics and API-context verification for the Anniversary branch. High-confidence result: no parser/runtime diagnostics and no obvious event-wire breaks in the core shaman/hunter/paladin paths. Smell notes identified for future cleanup: (1) lingering Druid helper toggles/migrations remain in DB defaults even after the Druid streamlining pass, creating config/schema noise; (2) shield compatibility tables now prioritize resilience, but some alternate Water Shield IDs should be validated in-game on live 2.5.5 and trimmed to verified mappings if redundant.

- v0.1.2 shaman shield compatibility hardening (2026-05-30): deep-audited Lightning/Water shield tracker no-show risk and fixed two missed gaps. Expanded shield spell coverage in `SuperSwingTimer_Constants.lua` (Lightning ranks + Water Shield rank/alternate aura mappings) and introduced normalized name lookup tables. Updated `IsLightningShieldActive()` in `SuperSwingTimer_ClassMods.lua` to use resilient ID-first plus aura-name fallback matching, including `Water Shield` / `Mana Shield` alias handling when client aura payloads omit or vary spell IDs. This pass specifically targets prior user reports that the shield tracker "didn't work at all" under some test conditions.

- v0.1.2 shaman tracker sizing correction (2026-05-30): adjusted the Enhancement Shaman Lightning Shield charge tracker geometry so it uses MH height when only MH is visible, and expands to the full MH+OH stack height (including the 2px inter-bar gap) when OH is visible. This aligns runtime behavior with the intended visual model and avoids the earlier dual-wield mismatch where the tracker top-aligned to MH but kept MH-only height.

- v0.1.2 shaman ui-wiring polish pass (2026-05-30): finished full Quick Controls wiring for shaman helper bars so both are explicitly user-disableable. Added new `showShamanFlameShockBar` SavedVariables default + migration (`v46 -> v47`) and runtime gating in `UpdateShamanFlameShockBar()` so the 6px target-duration bar hides immediately when disabled. Kept Lightning support as a first-class checkbox by renaming the shaman toggle row to `Lightning Shield Tracker` (clearer intent) while preserving the existing swatch/update path. Reset Defaults now restores both shaman helper toggles, and memory-bank `visualContext.md` was refreshed to match the real `/sst` panel structure and shaman quick rows.

- v0.1.2 shaman reliability + camera pass-through follow-up (2026-05-30): completed a second wiring audit after user feedback that Lightning Shield still was not showing. Fixed the root cause in `SuperSwingTimer_ClassMods.lua` where `IsLightningShieldActive()` parsed `GetHelpfulAuraData()` with the wrong return shape, which left `auraSpellId` nil and prevented shield detection. Also removed an `OnBarsCreated()` early-return edge case so shaman overlay recovery does not skip charge-tracker container creation when weave textures already exist, and added explicit `UNIT_AURA` player refresh wiring in `SuperSwingTimer.lua` for immediate shield updates. For UX, unlocked bars now keep left-click drag while right-click over bars forwards to `MouselookStart()` / `MouselookStop()` in `SuperSwingTimer_UI.lua`, preventing camera control frustration during repositioning.

- v0.1.2 shaman deep-dive + flame shock follow-up (2026-05-30): performed an end-to-end shaman weave analysis (event payloads, cast token recovery, weave state build, class-mod overlay draw lifecycle, and visibility gating), then hardened runtime recovery by making `UpdateWeaveVisuals()` attempt `OnBarsCreated()` reinitialization before giving up when weave textures are missing. Added an Enhancement Shaman Flame Shock target-duration helper bar (6px) above MH in `SuperSwingTimer_ClassMods.lua`, wired through player-filtered target debuff scanning, `PLAYER_TARGET_CHANGED` and `UNIT_AURA` target refresh hooks in `SuperSwingTimer.lua`, plus shared `ApplyVisibility()` refresh in `SuperSwingTimer_UI.lua`. Added rank-safe Flame Shock IDs/constants in `SuperSwingTimer_Constants.lua`, bumped addon metadata to `v0.1.2`, and synced README/CHANGELOG/docs for the new behavior.

- wow-classic-lua v0.5.0 operator-grade final pass (2026-05-30): added three new execution-focused references to complete the skill pack: `references/operator-cheatsheet.md` (rapid issue routing), `references/class-quickmaps.md` (class ownership and first-file targeting), and `references/incident-first-5-minutes.md` (deterministic incident triage flow). Updated `SKILL.md` to v0.5.0 and wired the new references into `api-notes.md` so operators can jump directly from quick-start to exact triage mode.

- wow-classic-lua visual coverage follow-up (2026-05-30): expanded visual aids across the full skill reference pack after user feedback that visuals should not be limited to only three docs. Added compact decision/flow maps to `api-notes.md`, `api-core.md`, `ui-frames-and-widgets.md`, `framexml-and-xml.md`, `research-links.md`, `superswingtimer.md`, and `runtime-safety.md`, while preserving the previously-added visuals in `compatibility-matrix.md`, `event-payload-cheatsheet.md`, and `verification-playbooks.md`.

- wow-classic-lua v0.4.0 final pass (2026-05-30): completed the final skill quality upgrade by adding three operational references under `.github/skills/wow-classic-lua/references`: `compatibility-matrix.md` (branch-safe API variance/fallback guidance), `event-payload-cheatsheet.md` (high-risk event parsing patterns for CLEU and spellcast families), and `verification-playbooks.md` (subsystem-specific in-game validation checklists). `SKILL.md` was bumped to v0.4.0 and now indexes these files directly.

- wow-classic-lua v0.3.0 final polish (2026-05-30): completed an accuracy/quality pass on `.github/skills/wow-classic-lua/SKILL.md`, normalized wording/formatting, and added explicit runtime-safety guidance for secure/protected behavior in combat (taint/combat-lockdown constraints). Added `references/runtime-safety.md` to cover secure UI guardrails, SavedVariables lifecycle timing (`ADDON_LOADED` vs `PLAYER_LOGIN`), performance patterns, and combat-only bug triage steps.

- v0.0.10 shaman weave actual-cast rescale follow-up (2026-05-30): corrected the Enhancement Shaman weave model so the active icon is driven by elapsed cast time against the current haste-adjusted duration each frame, which makes the visible spell position animate like a real cast and rescale if spell haste/buffs change mid-cast. The earlier fixed-marker guidance remains, but only the markers stay static now.

- wow-classic-lua skill refresh (2026-05-30): expanded `.github/skills/wow-classic-lua` into a fuller reference pack for future Classic/TBC addon work. The skill now includes refreshed `warcraft.wiki.gg`-based references for core combat/cast/cooldown APIs, `CreateFrame`, widgets, layers, handlers, FrameXML/XML, curated research links, and a new `references/superswingtimer.md` file that summarizes this repo's architecture and proven addon patterns.

- v0.0.10 quick-controls + shaman follow-up (2026-05-30): added a little more measured gap below the `/sst` `Visibility` / `Key Colors` column titles so the first quick-color row no longer crowds the title text in live panel use. Reworked the Enhancement Shaman weave display split so the upper/lower breakpoint markers stay fixed on the safe cast-start point again while the moving spell icon now starts from the live cast-start position on the MH swing and travels toward projected landing, with the weave cast-state path now falling back to `ns.GetUnitCastingSpellInfo("player")` timing when the event payload does not resolve the tracked spell cleanly. README / docs / changelog were synced to the new behavior.

- v0.0.10 config follow-up (2026-05-28): hardened `/sst` again after the bad layout pass. The Appearance helper sliders are now created only for the active class instead of being created for every class and hidden later, which fixes Hunter still seeing Rogue / Warrior helper-size rows. The standard config row builders now use much more of the section width: bar-texture preview rows stretch across the panel, texture path boxes fill the row minus the browse button, dropdown rows are wider, and the default toggle/action rows keep the label above the control instead of wasting the right half of the section. Quick Controls kept its compact two-column treatment, but the `Visibility` / `Key Colors` labels now sit lower below the header with a real measured gap before the first compact row. Targeted diagnostics on `SuperSwingTimer_Config.lua` are clean.

- v0.0.10 follow-up polish (2026-05-28): updated the Enhancement Shaman weave visuals so active tracked casts no longer stay pinned to one fixed projected-impact point; the icon pair plus center spark now begin at the safe breakpoint and travel toward the projected landing point across the current MH swing, making it easier to see the cast stay ahead of MH in real time. Fixed the `/sst` line-3352 runtime error by guarding the stale `panel.druidPowerShiftSlider` / `panel.druidEnergyTickSlider` refresh calls left behind after the Druid streamlining pass. Reflowed the `Appearance`, `Shaman Weave Assist`, `General Behavior`, and `Weave Families` config sections from real widget heights instead of brittle fixed Y offsets so slider rows no longer overlap their headers, then wired that reflow back into live section collapse/expand plus the `/sst` open-path refresh so the spacing stays correct during real panel use instead of only on initial creation. Follow-up slider cleanup replaced the old narrow `OptionsSliderTemplate` anchors with labeled full-width slider rows so each control has a readable title above it and uses the panel width properly instead of tiny unlabelled strips. Targeted diagnostics on `SuperSwingTimer_Config.lua`, `SuperSwingTimer_ClassMods.lua`, and `SuperSwingTimer_Weaving.lua` are clean.

- v0.0.10 shaman bugfix pass (2026-05-27): fixed the Enhancement Shaman `UpdateWindfuryIcd()` runtime crash by routing the helpful-buff scan through `GetHelpfulAuraData()`, guarding spell-ID comparisons with numeric checks, and timing the ICD from `ns.timers.mh.lastSwing` on the addon's aligned clock. Reworked the shaman update chain so `UpdateShamanisticRageBadge()` no longer rewraps `ns.OnUpdate` inside itself; `SetupEnhShaman()` now installs one stable wrapper for weave visuals plus Flurry / Stormstrike / Shamanistic Rage badge refreshes. Updated the live weave assist so tracked shaman casts (LB / CL / HW / LHW / CH) swap the moving spark to the real spell icon and position it at the projected landing point on the current MH swing, then restore / hide cleanly after the cast ends.

- v0.0.8 bugfix release (2026-05-20): fixed a line-71 crash in `ClassMods.lua` where a bare `local updateInterval = 0.016` sat before the `ns` namespace, silently killing all `Setup*()` functions for every non-hunter class. Fixed the Paladin seal twist zone layering: the three seal textures (twist zone, reseal line, judgement marker) were routing through `SetTextureLayerAboveBar()` which depended on the Shaman weave marker system, so Paladins only got the red zone when the shaman code path was active — now all three textures use `SetDrawLayer("OVERLAY", 0)` directly. Added missing `end` for `UpdateShamanisticRageBadge()` at line 1544, which was the root cause of LSP cascade errors. Fixed `prevOnUpdate` undefined global in the same function's OnUpdate hook by capturing `ns.OnUpdate` directly as `prevOnUpdate` and adding a bootstrap call so the shaman badge chain initializes. Dropped `LATENCY_REFRESH_INTERVAL` from 5.0s to 0.05s and wired `RefreshLatencyCache()` into `HandleSpellcastDelayed`. Version bumped to v0.0.8.; the only remaining broad idea was moved to an archived / future wishlist section, and the README / CHANGELOG now describe the repo as final-prep / feature-complete.

- Phase 6 tank-utility start (2026-05-19): added a real Warrior Shield Block duration bar above the MH stack, added a Druid Ravage opener cue that only glows when Cat Form Ravage is actually usable on the current target, wired both helpers through SavedVariables defaults, config toggles, event refresh hooks, and UI update paths, and updated the roadmap / README / changelog / memory bank to track the new phase.

- Phase 5 final polish (2026-05-19): completed the spellcast-success hook cleanup, removed the remaining shadowed/unused locals in ClassMods and Config, collapsed the duplicate UI helper definitions, tightened the swing-start fallback so it prefers last-known speed before the generic 2.0 placeholder, and verified project-wide diagnostics are clean end-to-end before in-game testing.

- TBC Hunter Steady Shot grace period & Paladin seal twist zone (2026-05-19): the safe/unsafe clip-safety tint on the hunter cast bar now accounts for the 0.5s TBC mechanic where Auto Shot fires during the last 0.5s of Steady Shot without clipping (green/red now match real TBC behavior instead of being conservative). Paladin seal twist zone was fully rewritten: COMMAND seal added to twist families, the twist marker changed from a thin left-anchored black line to a right-anchored proportional-width red fill zone (matching the Rogue Sinister Strike pattern), and the default color changed from opaque black to transparent red (`{1,0,0,0.35}`). DB migration v33→v34 updates old defaults. Constants `ns.STEADY_SHOT_CAST_TIME = 1.5` and `ns.STEADY_SHOT_GRACE = 0.5` added.
- GetTimePreciseSec audit (2026-05-19): verified all 6 files correctly prefer `GetTimePreciseSec()` with `GetTime()` fallback via `ns.GetCurrentTime()`. No bare `GetTime()` calls found. Timing domain is clean.
- TBC Hunter mechanics research (2026-05-19): Auto Shot cooldown = weapon speed after haste (`GetSpellCooldown(75)`), Steady Shot = 1.5s fixed cast (haste-immune) with 0.5s grace period, Multi-Shot = instant 6s CD in TBC, 1:1 rotation (1 Steady per 1 Auto) with 1:2 at high haste, French rotation (5:5:1:1) available. Verified clip-prevention logic location at `ApplyHunterCastBarColor` line 797 in UI.lua.

- Hunter cast-bar API/latency polish (2026-05-19): the live Hunter cast path now resolves `UnitCastingInfo()` through a Classic-safe spell-name-first helper instead of assuming a modern spellID return, `UNIT_SPELLCAST_START` / `SUCCEEDED` / `DELAYED` fallbacks now preserve recovered Hunter spell tokens more safely, and the dedicated Steady Shot / Aimed Shot bar now shades a trailing latency slice that updates from cached latency and live cast duration for more top-end no-clip timing.
- Hunter state-hardening follow-up (2026-05-19): split queued Raptor visibility from true Hunter MH-active state so queued Raptor no longer suppresses the ranged hidden-window helper early, hidden hunter cast state now expires cleanly even if the bar is not visible, `STOP_AUTOREPEAT_SPELL` now forces a clean false fallback when no authoritative spell-state API is available, and the follow-up review found no remaining high-severity hunter issues in those areas.
- Hunter precision/readability follow-up (2026-05-19): `UNIT_SPELLCAST_DELAYED` now refreshes stored Hunter Steady Shot / Aimed Shot timing, the dedicated hunter cast bar tints real casts by whether they still fit before the next Auto Shot, and class-colored MH/OH/ranged labels now flip to black with a white outlined backing for much stronger contrast on bright fills.
- Hunter melee/cast follow-up (2026-05-19): the Hunter MH bar is now attached to the ranged stack, only shows during a real MH swing or queued Raptor Strike, queued Raptor uses its own yellow next-attack tint, melee handoffs no longer leave the ranged bar stuck full red after the last ranged cycle expires, and the dedicated hunter bar now shows real Steady Shot / Aimed Shot cast progress in addition to the hidden Auto Shot window.
- Hunter mount-loop follow-up (2026-05-18): mounted Hunters are now treated as not auto-repeating, and the ranged timer ignores cooldown re-anchors while the bar is pinned in the red moving window so mount / long-movement cases no longer make the Auto Shot bar loop until the player stops.
- Hunter Auto Shot final polish follow-up (2026-05-18): the Hunter ranged timer now cross-checks Blizzard's current auto-repeat spell state before seeding cooldown-driven cycles, transient `STOP_AUTOREPEAT_SPELL` events no longer hard-reset a still-valid Auto Shot cycle, and the current cycle is allowed to finish cleanly so the red late window stays readable instead of resetting while Auto Shot still fires.
- `/sst` quick-controls polish follow-up (2026-05-18): the top section now has explicit `Visibility` and `Key Colors` column labels, a shorter clearer subtitle, and the Hunter red cast-window swatch is labeled `Auto Shot Late` for easier setup language.

- Rogue helper cleanup follow-up (2026-05-18): removed the experimental Rogue combo-point strip and the right-side total-energy battery helper, returning Rogues to a single 4px energy-tick bar on the left of MH while polishing Slice and Dice so it anchors directly above MH, hides with MH, and rechecks the player buff state on a short throttle.
- Rogue combo-point follow-up (2026-05-17): Rogues now get a compact five-box strip directly above the MH bar, driven by `GetComboPoints("player", "target")`, refreshed on `UNIT_COMBO_POINTS` plus `PLAYER_TARGET_CHANGED`, sized to the full MH width with 4px-tall boxes, and exposed through a dedicated Quick Controls toggle and color swatch while Slice and Dice now stacks above that strip.
- Rogue energy battery test follow-up (2026-05-17): the Rogue energy helper is now a paired vertical set again — a 4px left tick bar plus a 4px right total-energy battery bar — with separate tick vs battery color swatches while the existing helper toggle still controls both bars together.
- v0.0.7 rogue helper follow-up (2026-05-17): the Slice and Dice bar now reads player helpful auras through a Classic-safe `UnitBuff` / `UnitAura` signature-tolerant helper so the SnD bar shows correctly on current Classic/TBC clients.
- v0.0.6 Rogue completion pass (2026-05-17): Rogues now get a slim Slice and Dice duration bar above the MH bar that tracks the active buff in real time from `UnitAura`, uses the shared bar width/texture/background/border styling path, exposes its own Quick Controls toggle and color swatch, and the slimmer live profile now derives the OH bar to 8px while the SnD helper stays on a compact 3-4px height.
- Rogue helper polish follow-up (2026-05-17): the Rogue Sinister Strike end-window now uses a softer stock alpha and slightly softens again on the opener/weapon-speed fallback path so it stays readable while still updating live from the configured swatch, the Rogue energy helper fills upward again, and the Quick Controls checkbox is labeled `Rogue Energy Helper` for clearer Rogue setup.
- Release polish follow-up (2026-05-17): `/sst` now uses an optional `BackdropTemplate` path for Classic/TBC-safe config backdrops, the main config scrollframe supports mouse-wheel scrolling, the top Quick Controls section pushes later headers down from its real runtime height so class-specific rows cannot overlap the next section, and the panel subtitle now makes the preview-vs-live visibility split explicit while the shared live bar visibility audit remained combat-only out of combat.
- Visibility correction follow-up (2026-05-17): normal gameplay bars are combat-only again, and hidden or idle MH/OH/ranged/enemy bars now reset to an empty state so combat entry no longer shows stale full bars before the first real swing or shot starts.
- Rogue combat-visibility fix (2026-05-17): the shared visibility path now honors an explicit combat flag set by `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` instead of relying only on `InCombatLockdown()` timing, which fixes Rogues sometimes getting no melee bars until a later unrelated event refreshed visibility.
- Rogue cue consistency follow-up (2026-05-17): the Rogue Sinister Strike slice now falls back to the current MH weapon speed whenever the MH bar is visible, so it does not disappear at opener or other moments where the MH timer is not active yet.
- Active-timer visibility follow-up (2026-05-17): shared visibility now lets MH/OH/enemy bars stay visible while their real timers are active, and timer start/reset now reapplies visibility immediately, which fixes melee classes such as Rogue not showing bars until an unrelated later refresh path fired.
- Final all-classes polish (2026-05-17): BC Classic Hunter Multi-Shot now seeds the small hunter helper bar from stored state even when Classic exposes no live cast, and the Rogue Sinister cue now stays under the shared spark layer so the spark stays readable through the red tail slice.
- Hunter stability follow-up (2026-05-16): auto-repeat start now seeds the ranged swing immediately instead of waiting for the cooldown API to become active first, hunter cooldown events refresh visibility through the shared path, and combat-entry bar showing now defers to `ApplyVisibility()` so ranged visibility stays consistent with the real hunter state.
- Config open-path hardening (2026-05-16): `/sst` now lazily re-initializes the panel if needed, the quick color swatches use pure texture-backed buttons instead of backdrop-on-button styling, and the pre-show color-row refresh is guarded so a bad row cannot block the whole panel.
- UI interaction hardening (2026-05-16): the config row click handlers now defer to the real right-side button/toggle/dropdown when the cursor is already over that control, which removes duplicate-trigger behavior from the `/sst` panel.
- UI swatch bugfix follow-up (2026-05-16): replaced the broken color selector button styling with a plain `BackdropTemplate` preview tile that keeps a visible gray base under the swatch, which restores the missing-but-clickable quick colors and makes Hunter/class rows readable again.
- UI color-readability follow-up (2026-05-16): the `/sst` color swatches now use flatter high-contrast preview tiles instead of the washed-out default button look, so the selected bar colors read much more clearly during setup.
- Final v0.0.5 fit-and-finish (2026-05-16): the top Quick Controls rows now use compact non-overlapping spacing, the Rogue test energy bar is a 5px helper that matches the visible MH/OH bar heights instead of spanning the inter-bar gap, and the thin 3px spark now uses a slight forward-biased pixel snap so it reads closer to the live fill edge.
- Final v0.0.5 pre-test polish (2026-05-16): the stock live profile now defaults the main shared bars to 15px, derives the OH bar to 10px with matching clamped spark height, and adds a Rogue-only test vertical energy-tick bar to the left of the MH/OH stack with its own toggle and color swatch in the top quick controls.
- v0.0.5 prep (2026-05-16): `/sst` now uses a two-column Quick Controls section at the top so the most-used visibility toggles stay on the left while the primary bar-color swatches live on the right, which brings MH/OH/ranged/enemy/Hunter/Rogue color tuning much closer to the top of the panel.
- Rogue helper follow-up (2026-05-16): Rogues now get a latency-adjusted red end-window overlay on the MH bar that marks when to press Sinister Strike into the swing landing, plus a dedicated toggle and color swatch so the helper remains optional and readable without recoloring the whole MH fill.
- Class-panel polish follow-up (2026-05-16): the shaman weave section is now hidden on non-shaman classes, which keeps `/sst` cleaner during normal Warrior/Rogue/Hunter setup.

- v0.0.4 prep (2026-05-15): added a current-target enemy swing bar with a red default color, SavedVariables/config/reset support, `PLAYER_TARGET_CHANGED` + `UnitAttackSpeed("target")` tracking, and a spark-position refresh path that anchors the shared spark to the actual rendered fill edge with a 3px stock width.
- Timing follow-up (2026-05-15): hunter ranged live resync now reuses the active `GetSpellCooldown(75)` start anchor during mid-swing cooldown sync instead of only rescaling duration, and the shared base timer clock now stays on a `GetTime()`-aligned precise path while cached latency is applied only to predictive windows so latency refreshes cannot shove every live timer forward.
- Weave follow-up (2026-05-15): shaman breakpoint markers now use the tracked spell's small icon instead of the old triangle textures, and the breakpoint marker itself stays fixed at the full cast-time-plus-latency start point while the separate weave spark continues to show cast progress.
- Hunter/UI follow-up (2026-05-15): `/sst` now exposes dedicated `Auto Shot Safe Color` / `Auto Shot Unsafe Color` swatches for the hunter red/green feedback, while the existing `Enemy Color` row continues to drive the current-target enemy bar directly.
- Visibility follow-up (2026-05-16): the shared `ApplyVisibility()` path now respects combat state for MH/OH/enemy bars, which stops those bars from reappearing out of combat after config refreshes or equipment-driven apply calls while preserving Test Bars preview and active ranged visibility.
- Preview cleanup follow-up (2026-05-16): ending Test Bars preview now hands visibility back to `ns.ApplyVisibility()` instead of hard-zeroing every bar, so active ranged behavior outside combat can recover cleanly after a preview pass.
- Timing audit follow-up (2026-05-15): rechecked the remaining live timing paths against Warcraft Wiki notes and left the existing clock-domain split intact on purpose — swing bars still use the addon's latency-adjusted `GetTimePreciseSec()` / `GetTime()` helper, while direct cast/channel timestamp reads stay on their raw API times so the addon does not reintroduce mixed-clock drift.

- Config texture picker follow-up (2026-05-05): MH/OH and ranged textures now open a scrolling full-preview bar list instead of the nested paged UIDropDownMenu path, so each texture fills its row behind the label while Blizzard fallbacks and LibSharedMedia statusbar packs stay in one fixed-height scrollable picker.
- Spellcast payload correction (2026-05-05): BCC Anniversary `UNIT_SPELLCAST_*` handling is back on the `unit, castGUID, spellID` payload path in state, class queue hooks, and shaman weaving, which restores spell-driven timer/reset/pause behavior that broke when the handlers were switched to spell-name parsing.
- Final release-prep pass (2026-05-05): the live timer model stays on latency-adjusted `GetTimePreciseSec()` / `GetTime()`, primes the precise clock once, and keeps MH/OH/ranged swing anchors, queued next-attack landed resets, parry haste, and druid form resets on that existing live clock after the experimental CLEU remap proved too aggressive.
- Config polish follow-up (2026-05-05): the MH/OH `Bar Width` row now sits below its section header so adjusting width no longer also toggles the collapsible section, and the other setup/dragging polish from this session remains intact.
- Next-attack isolation follow-up (2026-05-05): Warrior Heroic Strike / Cleave, Druid Maul, and Hunter Raptor Strike now keep fully class-local queued state plus class-local landed-hit reset detection, so the old shared next-attack lookup path is gone.
- Druid Maul tint follow-up (2026-05-05): Maul now uses its own bear-yellow tint instead of sharing Warrior Heroic Strike's yellow, which makes Warrior vs Druid queued MH feedback visually distinct.
- Spark scope follow-up (2026-05-05): queued next-attack tint still only touches the MH status-bar fill; the spark remains on the separate spark-color path in the UI module.

- Visual-correctness follow-up (2026-05-04): `Use Class Colors` no longer overwrites the stored manual MH/OH/ranged colors, so toggling it off restores the real saved colors instead of leaving the bars class-tinted.
- Spark follow-up (2026-05-04): the main swing spark now renders with a color-preserving blend mode, so a white/manual spark stays visually white instead of picking up warmth from the colored bar fill.

- Final production polish pass (2026-05-04): narrowed the hunter work back to cast-bar-only stabilization so the core Auto Shot ranged timer keeps its existing live behavior, while the red-zone hidden-window cast bar stays locked and no longer bounces near cycle end.
- Class/system correctness follow-up (2026-05-04): ret paladin reseal timing now uses swing-elapsed-plus-GCD math, shaman weave spell-name resolution now flows through `ns.GetSpellInfo`, weave overlays now respect Minimal Mode / weave visibility, off-hand handling now reuses the named OH bar safely across equipment swaps, and Reset Defaults / Test Bars / drag handling were hardened for real in-game setup.

- Release follow-up (2026-05-04): the shared spark tint is manual/default again and no longer follows `Use Class Colors` or queued MH fill tints, so Heroic Strike / Cleave / Maul keep the spark readable.
- Hunter hidden-window stabilization (2026-05-04): the dedicated Auto Shot cast bar now locks to a stable end-of-cycle hidden-window anchor instead of re-seeding itself from the movement-pinned ranged timer every frame, and Auto Shot no longer persists separate cast-state fallback outside that hidden-window path, which removes the end-of-swing bounce and reduces random activations.
- Queue cleanup follow-up (2026-05-04): interrupted / failed Maul now restores the druid queue tint through the druid clear path instead of relying only on the warrior cleanup path.

- Release hardening pass (2026-05-01): achieved full TBC Classic Anniversary (1.15.x) compatibility by implementing a robust `ns.GetSpellInfo` wrapper and safe-accessing Blizzard UI globals (`UIDropDownMenu`, `C_Spell`) via `_G`, eliminating all linting and runtime errors.
- Hunter Auto Shot Sync (2026-05-01): synchronized the dedicated hunter cast bar with the ranged timer's latency-aware "red zone," ensuring the move-safety feedback and cast window are perfectly aligned for pixel-perfect shot timing.
- Config UI Polish (2026-05-01): optimized the texture selection dropdown with 20-item paging, visual texture previews, and increased font readability, while enforcing visual-safe defaults (Class Colors: OFF) for maximum clarity in high-intensity combat.

- Release hardening pass (2026-04-30): hunter ranged state now supports `GetRangedHaste`-based fallback scaling when `UnitRangedDamage()` is briefly unavailable, and shaman weaving haste math now falls back from `UnitSpellHaste("player")` to `GetSpellHaste()` when needed.
- Broad audit follow-up (2026-04-30): fixed a hunter cast fallback bug where `HandleSpellcastSucceeded` could seed `hunterCastStartTime` as `now - CAST_WINDOW`, which could instantly complete the cast bar if the start event was missed.
- Hunter cast-window hardening (2026-04-30): the hunter cast bar now derives from the end-of-ranged-cycle hidden cast window when active, and spellcast-succeeded fallback no longer fabricates a post-shot cast window.
- Final hook/state polish (2026-04-30): hunter spellcast-start handling now avoids setting cast-active fallback state for Auto Shot, and UI cast fallback seeding now requires live/active hunter cast context to prevent cycle-start cast flashes.
- Final reset-state polish (2026-04-30): ranged timer resets now also clear hunter cast state so hidden-cast bar state cannot leak across STOP_AUTOREPEAT and other ranged reset paths.

- Additional final polish (2026-04-30): hunter hidden cast-window timing now anchors to cast/shot start for the fixed `ns.CAST_WINDOW` bar, and player-only filtering was added for `UNIT_ATTACK_SPEED` / `UNIT_RANGEDDAMAGE` sync events to cut extra update noise.

- Hunter cast bar timing was reworked again so it is fully separate from ranged-bar duration and now always uses the fixed `ns.CAST_WINDOW` hidden Auto Shot window, with end-of-cast alignment when `UnitCastingInfo` data is present.
- Swing startup now does an immediate speed resync on both melee and ranged starts, reducing first-frame drift so white-swing and Auto Shot bars settle to live weapon/cooldown timing faster.

- Final timing/state polish (2026-04-30): `SuperSwingTimer_State.lua` now has one canonical `ResetTimer` path again, hunter cast state is explicitly cleared on world/combat resets, and hunter cast-bar detection now tolerates Classic `UnitCastingInfo` payloads that provide spell names without stable spell IDs.
- Shaman weave family tinting now avoids mutating shared color tables, so safe/unsafe alpha transitions stay visually consistent while the MH cast-before-clip marker logic remains intact.
- Ret paladin seal-twist markers were re-polished so the end-of-swing strike marker stays visible for active twist families while the secondary reseal marker remains GCD-aware.

- The final release polish pass now keeps the hunter Auto Shot / Multi-Shot cast bar on the shared `ns.CAST_WINDOW` timing with a `UnitCastingInfo` fallback, while warrior queue tinting only scans numeric queued-spell IDs so Heroic Strike and Cleave can light up and clear reliably.
- The unlocked bar drag hitboxes were widened again, and the README was expanded into a more professional project page with at-a-glance tables, a timing model, and a texture-source table for CurseForge-friendly Markdown.

- The final release polish pass is in progress: the hunter Auto Shot / Multi-Shot bar now has separate active-state logic, `/sst` gained a temporary Test Bars action plus a clearer `Lock / Unlock Bars` control, and the main color swatches now allow opacity selection.

- The base spark width is back to 4px, the spark tint now follows the ranged class color when class colors are enabled, and the Hunter Auto Shot / Multi-Shot cast bar uses stored cast timing so it renders reliably again.

- The `/sst` panel has stable collapsible section rows again, and the spark / weave defaults were slimmed down so the glow now stays bar-height aligned instead of rendering as a huge white block.
- The Hunter Auto Shot / Multi-Shot cast bar remains cast-only and sits directly beneath the ranged timer without forcing a persistent preview state.

- The `/sst` panel now uses collapsible section headers for the major groups, and the Hunter Auto Shot / Multi-Shot cast bar is cast-only so it appears beneath the ranged timer only during real hunter casts.
- The channeling update loop now stays alive while `ns.channeling` is active, which keeps ranged channel visuals animating even when no swing timer is currently swinging.

- Hunter now has a dedicated 10px Auto Shot / Multi-Shot cast bar beneath the ranged timer, tied to the ranged texture, spark settings, and visibility rules instead of floating independently.
- The hunter spellcast handlers were corrected to consume Classic's 3-argument `UNIT_SPELLCAST_*` payloads so the cast state and swing-reset logic can read the live spell ID.
- The TBC Multi-Shot ranks and Slam ranks 5-6 were synced into the addon tables and `docs/swingtimer.md`, and the TOC / changelog were bumped to `v3.1.7`.

- The MH/OH and ranged texture rows now stay focused on bar-style textures from Blizzard, SharedMedia, WeakAuras, and installed addon packs, while the spark and shaman weave spark rows open folder-style thumbnail browsers with `Square_FullWhite` surfaced as `Normal`.
- The spark alpha slider has been restored in the config panel, and the spark / weave browse buttons now use the dedicated WeakAuras browse icon for a more polished picker feel.

- The MH/OH spark texture row now opens a dedicated square-thumbnail browser, the WeakAuras `Square_FullWhite` spark preset is surfaced as `Normal`, and the shaman weave spark reads as `Target Indicator` for cleaner final-release wording.
- README, CHANGELOG, `SuperSwingTimer.toc`, `docs/SharedMedia.md`, and `docs/UI.md` were refreshed to match the polished spark picker and metadata bump.

- Hunter Auto Shot now has a green-safe cast-window state: the cast window turns green when the player stops before the breakpoint and stays red when the player is still moving too late.
- The ranged safe-state uses a stored movement-stop timestamp plus the existing latency-aware breakpoint math, and the overlay updates immediately on movement start/stop.
- README, CHANGELOG, `SuperSwingTimer.toc`, `docs/swingtimer.md`, and `docs/WeakAuras/Expert-Patterns.md` were refreshed so the docs, addon metadata, and WeakAuras bridge example match the new behavior.

- Dropdown rows now open from the full row body, the dead texture-browser popup has been removed, and the moving spark anchors are cleared before each update so the visuals stay stable.
- The `/sst` config now feels more like a real settings panel: visible dropdowns for selector rows, checkboxes for toggles, editable numeric fields for sliders, and section backdrops for visual grouping.
- Hover highlights were added to the clickable config rows so the selectors are easier to discover.
- Hover tooltips now explain what each config row means so the panel is easier to understand without guessing.

- Hunter Auto Shot, shaman weave, and ret paladin seal-breakpoint visuals now live on dedicated non-mouse overlay frames above the bars, which removes the hover-sensitive HIGHLIGHT fallback and keeps the spark / markers visible.
- The `/sst` config now uses visible dropdowns for cycle settings and editable numeric fields beside sliders.
- README and `docs/UI.md` were updated to match the new control layout and overlay-frame behavior.

- Hunter Auto Shot, shaman weave, and ret paladin seal-breakpoint overlays are now kept above the bar fill again when textures are reapplied, which fixes the visibility regression where the spark / markers could disappear behind the skin.
- The `/sst` subtitle now tells players to hover for help and then use the right-side checkbox, dropdown, numeric field, or swatch button to change each setting.

- Breakpoint overlays now resolve to an above-bar draw layer, so the shaman weave spark/triangles, the ranged cast-threshold marker, and the ret paladin seal lines stay visible when the bar texture layer is raised.
- Shaman weave positioning now uses the actual MH bar width instead of only the static default width.

- Final paladin pass expanded the seal family table to match `docs/spellIds.md` for Command, Corruption, Blood, Martyr, Vengeance, Justice, Wisdom, Righteousness, Light, and Crusader.
- Hunter Auto Shot cooldown start is now aligned to the addon’s latency-adjusted clock so the ranged bar and cooldown API share the same timing base.
- The ret paladin seal breakpoint line now keeps the actual strike-edge marker visible and adds a second latency-aware reseal marker for twist seals while staying aura-driven and opaque black.

- Final pass tightened Hunter Auto Shot by anchoring the ranged bar to the cooldown API start time when active, with `UnitRangedDamage()` still as the fallback.
- Paladin seal breakpoint lookup now prefers aura names, falls back to verified IDs, and survives missing rank IDs via localized name fallback.
- The shaman weave-assist and melee white-damage start/reset/end paths were reviewed again and left structurally unchanged after the final polish pass.

- Hunter Auto Shot timing now uses `GetSpellCooldown(75)` / `GetSpellCooldown("Auto Shot")` as the active cooldown source, with `UnitRangedDamage()` as the ranged-speed fallback and `SPELL_UPDATE_COOLDOWN` as the reactive trigger.
- The ret paladin seal breakpoint line remains UnitAura-aware, latency-aware, and opaque black.
- README, API notes, changelog, TOC, and memory-bank notes were synced to the new hunter timing path.
- The `/sst` config rows now use a labels-above-controls layout with full-row click targets for texture, cycle, toggle, and color settings.
- Ret paladin seal-twist timing is now latency-aware, using the fixed 0.4s window plus cached latency.
- Blizzard Interface Options / AddOns registration is now wired for the config panel.
- Primary slash aliases are `/sst`, `/super`, and `/superswingtimer`; `/swangthang` has been removed.
- Default bar colors now use class colors until the user picks custom swatches, and the indicator blend mode can switch between glow and opaque.
- The texture dropdown now uses preview thumbnails, and the `/sst` panel is wider with clearer grouping and labels.
- Hunter Auto Shot now has a latency-aware red-zone marker plus a dedicated ranged texture picker, and the `/sst` appearance rows now split MH/OH and ranged controls more clearly.

- **v0.0.8 bugfix release (2026-05-20)**: Fixed line-71 crash where bare `local updateInterval = 0.016` before `ns` killed every non-hunter class. Fixed Paladin seal twist zone layering — seal textures were routing through Shaman weave system instead of using direct `SetDrawLayer("OVERLAY", 0)`. Fixed missing `end` in `UpdateShamanisticRageBadge()` that caused LSP cascade errors. Fixed Shaman OnUpdate chain (`prevOnUpdate` was undefined global) by capturing `ns.OnUpdate` directly with bootstrap. Fixed `strtrim` undefined in UI.lua via `rawget` import. Fixed indentation at lines 239–241 and OnUpdate body in `SetupEnhShaman()`. Tuned latency refresh: `LATENCY_REFRESH_INTERVAL` 5.0s → 0.05s with `RefreshLatencyCache()` in `HandleSpellcastDelayed`. **All 7 source files now pass LSP diagnostics clean.**

- **ROADMAP updated**: Phase 8 (v0.0.8 bugfix) added as completed. Phase 0/1 corrected to v0.0.9 target (unchecked). Added Phase 9 (LSP Health), Phase 10 (Testing & Automation), Phase 11 (Integration & Ecosystem).

- **v0.0.9 Druid Streamlining & Shaman Weaving Fix (2026-05-20)**: Re-anchored the Shaman weaving cast-by threshold indicator triangles from horizontal-midpoint relative offsets ("TOP" / "BOTTOM") to the left margin ("TOPLEFT" / "BOTTOMLEFT"), resolving the offset alignment bug so the cast-by marker precisely indicates where a cast must be completed relative to the swing's progress. Streamlined Feral Druid options in `SuperSwingTimer_ClassMods.lua`, `SuperSwingTimer_UI.lua`, and `SuperSwingTimer_Config.lua` by stripping bloated extra elements (mangle debuff bar, rip bleed bar, Omen flash, Tiger's Fury badge, Faerie Fire glow, shapeshift form bar-coloring, form labels, and Bear rage-dimming). Feral Druids now enjoy a clean, high-performance minimal swing timer layout while maintaining their signature bear-yellow Maul queue styling.
