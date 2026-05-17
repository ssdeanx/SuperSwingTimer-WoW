# Active Context

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

1. In-game validation for the hunter cast bar, warrior queue tinting, and the easier bar drag target.
2. Any follow-up polish for the weave marker spacing, icon choice, or tooltip copy after client testing.
3. Memory-bank persistence and production-ready planning notes.

## What we know right now

- The live feature plan in `memory-bank/weaveapi-swingtimer-ui` now covers the runtime addon, config/media UI, release docs, metadata, and diagnostics surface.
- The weave breakpoint uses the current cast window (cast remaining or cast time plus latency) while still being drawn on the MH bar canvas.
- The main-hand swing timer now refreshes latency in the active update loop, so end-of-swing timing stays closer to live network state.
- Parry haste now scales from the player's current melee haste (`GetMeleeHaste()` / `GetHaste()` fallback) instead of a flat reduction.
- The config panel now has Blizzard AddOns registration, class-color defaults for the main bars, and an indicator glow/opaque mode for sparks and weave markers.
- Bar and ranged texture selection now uses preview dropdown rows, while the spark row opens a dedicated thumbnail browser for the Normal `Square_FullWhite` preset.
- A new WoW Classic Lua skill now exists at `.github/skills/wow-classic-lua` for loading at the start of future sessions.
- White-hit handling still stays split by hand, and ranged reset spells keep their own path.
- The overlay keeps the breakpoint triangles visible while the MH timer is active; the spark remains cast-only.
- The weave spark tracks cast progress instead of swing progress.
- Texture selection in the config panel uses a dropdown list of SharedMedia/Blizzard entries with category labels instead of a browser window.
- Targeted diagnostics on the edited runtime files are clean.

## Likely bug area

- `SuperSwingTimer_State.lua` for white-hit timing, parry haste, and clean CLEU handling.
- `SetupEnhShaman()` / `UpdateWeaveVisuals()` in `SuperSwingTimer_ClassMods.lua` for breakpoint placement.

## Working assumptions

- The cast window is the breakpoint source; the MH bar is just the visual surface the breakpoint is drawn onto.
- The triangle markers represent the safe cast threshold based on cast remaining / cast time and latency.
- The spark remains tied to cast progress while the breakpoint markers stay visible whenever weave assist is enabled and the MH timer is active.

## Next steps

- Keep the state engine lean by removing any leftover unused CLEU unpacking when it appears.
- Preserve the SharedMedia dropdown, cast-spark behavior, and ranged-channel handling as the current working state.
