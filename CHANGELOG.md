# Super Swing Timer Changelog

## 0.0.7 - 2026-05-17

- Rogue cleanup follow-up: removed the Rogue combo-point strip and the right-side total-energy battery test helper, leaving a single 4px energy-tick bar anchored to the left of the MH bar.
- Rogue Slice and Dice polish: the SnD helper now anchors directly above MH again, stays hidden whenever the MH bar is hidden, and rechecks the player buff state on a short throttle so it feels less buggy if aura events arrive late.
- Rogue Slice and Dice fix: the SnD helper now reads helpful auras through a Classic-safe `UnitBuff` / `UnitAura` signature-tolerant path, which fixes the bar not showing on current Classic/TBC clients where helpful-aura return positions differ.
- Widget audit follow-up: rechecked Warcraft Wiki / Blizzard options-panel references and kept `/sst` on the current `UIPanelScrollFrameTemplate` path for production safety, while documenting `HybridScrollFrame` as a future optimization candidate only for very long picker lists.

## 0.0.6 - 2026-05-17

- Rogue production follow-up: Rogues now get a slim Slice and Dice duration bar above the main-hand bar that tracks the active buff in real time from `UnitAura`, uses the shared MH bar width/texture styling path, and can be toggled or recolored from `/sst`.
- Profile polish follow-up: the derived off-hand bar is slimmer again at 8px on the stock 15px main-bar profile, while the new Rogue Slice and Dice helper stays on a compact 3-4px height.

## 0.0.5 - 2026-05-16

- Rogue polish follow-up: the Rogue Sinister Strike cue now uses a softer stock alpha while still updating live from the saved swatch, and the opener/fallback path slightly softens that tint when the bar is only showing from weapon-speed fallback instead of an active live swing.
- Rogue energy helper follow-up: the vertical Rogue energy bar now fills upward again, and the top Quick Controls checkbox is labeled `Rogue Energy Helper` so the toggle is easier to find during Rogue setup.
- Final release UI polish: `/sst` now keeps later sections pushed below the actual Quick Controls height, so Rogue/Hunter class-specific quick rows no longer risk overlapping the next section header.
- Config shell polish: the main `/sst` panel now supports mouse-wheel scrolling, the subtitle more clearly distinguishes setup preview bars from live combat-driven bars, and the small texture browse button uses a slightly larger click target.
- Classic/TBC UI safety follow-up: config frames that need backdrops now use an optional `BackdropTemplate` path instead of assuming the newer template always exists, which keeps the panel safer for Classic-era UI variants while preserving the current Anniversary look.
- Visibility correction: normal bars are combat-only again, hidden bars now reset to an empty state, and entering combat no longer shows stale full bars before the first real swing or shot starts.

- Active-timer visibility fix: melee and enemy bars now follow the same model ranged already used — an active timer can keep its bar visible even if the combat-flag path is late — and timer start/reset now refreshes the shared visibility rules immediately.
- Rogue cue consistency follow-up: the Rogue Sinister Strike slice now falls back to the live MH weapon speed whenever the MH bar is visible, so it no longer disappears at opener or other moments where the MH timer has not started yet.
- Final all-classes timing polish: BC Classic Hunter Multi-Shot now seeds the small hunter helper bar from stored state even when Classic does not expose a live cast, so the dedicated hunter bar no longer disappears for instant Multi-Shot shots.
- Rogue cue polish: the latency-adjusted red Sinister Strike slice now stays under the spark layer so the spark remains readable through the red tail section.
- Reworked the top of `/sst` into a two-column Quick Controls section so the most-used visibility toggles stay on the left while the primary bar-color swatches sit on the right for faster setup.
- Moved the main bar color controls into that top quick-control area, including class-specific swatches such as Hunter Auto Shot safe/unsafe feedback, the enemy bar, the Rogue Sinister cue, and the Paladin seal line when relevant.
- Added a Rogue-only latency-adjusted red end-window overlay on the MH bar so Combat Rogues can press Sinister Strike into the swing landing and more reliably have it fire immediately after the main-hand hit.
- Added a `Rogue SS Cue` toggle plus a `Rogue SS Cue Color` swatch so the new Rogue timing helper can be turned off or retuned without recoloring the entire MH bar.
- Slimmed the stock live profile for the release build: main bars now default to 15px tall, the OH bar derives to 10px by default, and the default spark height follows that slimmer profile while still clamping to each host bar.
- Added a test Rogue energy-tick helper bar: a slim vertical status bar anchored to the left of the MH/OH stack that fills upward over the observed 2-second TBC energy cadence, with a toggle and color swatch in the top quick controls.
- Final pre-test polish: tightened the Quick Controls spacing so the two top columns no longer overlap when Rogue/Hunter-specific quick rows are present, resized the Rogue test energy bar to a 5px-wide helper that matches the visible MH/OH bar heights, and slightly forward-biased plus pixel-snapped the 3px spark so the thin spark reads closer to the true fill edge.
- UI readability follow-up: the `/sst` color swatches now use flatter high-contrast preview tiles instead of the washed-out stock button look, so MH/OH/ranged/enemy/Rogue/Hunter colors read much more clearly while configuring the addon.
- UI bugfix follow-up: the color selectors now use a plain `BackdropTemplate` preview button with a visible gray base, which fixes the broken invisible-but-clickable swatches and restores the Hunter/class quick colors in the panel.
- UI interaction hardening: row-level click helpers now ignore clicks that are already landing on the actual button, toggle, or dropdown control, which removes double-trigger behavior that could make the config panel feel buggy.
- Config open-path hardening: `/sst` now lazily re-initializes the panel if needed and safely refreshes quick color rows before showing, while the color swatches themselves no longer rely on backdrop methods on buttons. This prevents malformed quick-color controls from blocking the panel entirely.
- Hunter stability follow-up: `START_AUTOREPEAT_SPELL` now seeds the ranged timer immediately instead of waiting for the cooldown API to already be active, hunter cooldown updates refresh visibility through the shared rules, and the combat-entry helper now defers to `ApplyVisibility()` so ranged/hunter bars do not get forced visible on the wrong path.
- Hid the shaman-only weave section on non-shaman classes so `/sst` stays cleaner during normal Warrior, Rogue, Hunter, and Paladin setup.

## 0.0.4 - 2026-05-15

- Added a new current-target enemy swing bar that uses `PLAYER_TARGET_CHANGED`, `UnitGUID("target")`, `UnitAttackSpeed("target")`, and hostile-target `SWING_DAMAGE` / `SWING_MISSED` combat-log events to track the selected enemy's main-hand swing timing.
- The enemy bar is enabled by default, uses a red default color, stores its own position in SavedVariables, resets cleanly when the target dies or changes, and can be turned off from the `/sst` config panel.
- Added an `Enemy Color` swatch to the color section so the new target bar can be recolored without tying it to `Use Class Colors`.
- Moved cached latency off the shared base timer clock: swing bars and motion now stay on a `GetTime()`-aligned precise clock, while latency is applied only to predictive windows such as Auto Shot safe-stop timing and weave clip math.
- Added `Auto Shot Safe Color` and `Auto Shot Unsafe Color` swatches so the hunter red/green feedback can be tuned independently from the base ranged bar color.
- Tightened hunter ranged live resync: when `GetSpellCooldown(75)` exposes an active Auto Shot cooldown, the ranged timer now reuses that cooldown start as the live swing anchor instead of only stretching the duration mid-cycle.
- Fixed the shared visibility pass so MH/OH/enemy bars no longer leak visible outside combat when config refreshes, equipment changes, or other UI apply paths run out of combat; preview mode and active ranged behavior still stay visible when appropriate.
- Tightened Test Bars cleanup so ending the preview now restores the normal shared visibility rules instead of force-hiding active out-of-combat ranged behavior.
- Smoothed shaman weave timing by keeping the breakpoint marker locked to the full cast-time-plus-latency start point instead of letting that marker slide with `castRemaining` while you are already casting.
- Replaced the shaman weave triangle markers with small tracked-spell icons so the breakpoint helper shows the real spell family icon directly on the MH bar overlay.
- Fixed the shared spark drifting behind the visible fill by anchoring it from the actual rendered status-bar texture edge instead of only re-deriving it from the saved frame width.
- Changed the stock spark width default to 3px and migrated older untouched 4px default installs down to the new width while preserving custom user sizes.
- Synced the addon metadata and docs to the requested v0.0.4 release line.
  
## 3.1.26 - 2026-05-05

- Final release-prep session pass: re-audited the swing timer against current Classic/TBC API behavior and kept the live timer model on latency-adjusted `GetTimePreciseSec()` with `GetTime()` fallback, including priming the precise clock once before the first live timestamp.
- Restored swing, parry-haste, hunter Auto Shot CLEU, queued next-attack landed-reset, and druid form-reset anchors to the addon's existing latency-aware live clock after the experimental CLEU timestamp normalization caused timers to lead early.
- Kept Hunter's core ranged timer path intact while stabilizing the dedicated Auto Shot hidden cast bar on the same end-of-cycle stop-to-fire window as the red/green ranged feedback.
- Split next-melee queue handling fully by class: Warrior Heroic Strike / Cleave, Druid Maul, and Hunter Raptor Strike now keep separate queued state, landed-hit reset detection, interruption cleanup, and tint ownership.
- Changed Druid Maul to its own bear-yellow and kept queued next-attack tint scoped to the MH bar fill only; the spark remains on its independent manual/default color path.
- Corrected ret paladin reseal timing to use current swing elapsed plus remaining GCD time, which matches the real twist window much more closely than the older fixed-offset marker.
- Routed shaman weave spell resolution through `ns.GetSpellInfo`, kept weave overlays respecting Minimal Mode / weave visibility, and preserved the above-bar overlay layering for shaman, hunter, and paladin helpers.
- Polished setup and config behavior: real drag handlers plus a wider grab area for moving bars, safer OH-frame reuse across equipment changes, Reset Defaults restoring saved positions, Test Bars staying visible after the normal visibility pass, and the MH/OH `Bar Width` slider now sitting below its section header instead of overlapping the collapse toggle.
- Replaced the compact MH/OH and ranged texture dropdowns with a full-preview scrolling picker that shows each bar texture across the full row, keeps a fixed visible list size with scroll support, and anchors the popup from the texture control instead of paging nested UIDropDownMenu submenus.
- Kept the bar-texture picker focused on bar media only: it now surfaces the guaranteed built-in Blizzard fallback textures plus all LibSharedMedia-registered statusbar entries from installed media packs such as SharedMedia-Blizzard, while leaving the spark and weave-spark pickers on the dedicated thumbnail-browser path.

## 3.1.18 - 2026-05-02
  
- Added next-melee-attack (NMA) queue tinting for Druid Maul. The Main Hand bar now turns yellow when Maul is queued, matching the Warrior Heroic Strike behavior.
- Registered additional Maul spell IDs for TBC Classic Anniversary compatibility.
- Wired Druid queue tint updates into the main UI loop and color restoration logic.

## 3.1.17 - 2026-05-01

- Added TBC Classic Anniversary (1.15.x) compatibility by implementing a robust `ns.GetSpellInfo` wrapper that supports both legacy `GetSpellInfo` and modern `C_Spell.GetSpellInfo`.
- Fixed the "Undefined global" and "Undefined field" errors in the IDE and game by safe-accessing Blizzard UI globals (`UIDropDownMenu`, `C_Spell`, etc.) via `_G`.
- Synchronized the Hunter Auto Shot cast bar with the ranged timer's latency-aware "red zone." The cast bar now starts exactly when the ranged cycle hits the hidden-cast window.
- Improved the configuration panel's texture dropdown:
  - Implemented 20-item paging for better menu height on all screen resolutions.
  - Added visual texture previews (icons) next to each texture name in the list.
  - Increased the font size to `GameFontNormal` for better readability.
- Hardened default settings: Class Colors are now OFF by default to ensure maximum visual clarity for Rogue and Warrior ability indicators.

## 3.1.16 - 2026-04-30

- Release hardening: added ranged-haste-aware fallback resync for hunter ranged timing so the ranged timer can still estimate and adjust speed when `UnitRangedDamage()` is briefly unavailable.
- Added `GetRangedHaste` fallback support in the ranged state path, with safe scaling from the previous known ranged speed.
- Added `GetSpellHaste` fallback support in shaman weaving haste calculations when `UnitSpellHaste("player")` is unavailable.
- Minor robustness cleanup for hunter Auto Shot cooldown tuple usage in cast-window initialization.
- Fixed hunter cast-bar fallback in `HandleSpellcastSucceeded` so missed start events now open a full `ns.CAST_WINDOW` window (using `now`) instead of immediately completing from `now - ns.CAST_WINDOW`.
- Re-polished hunter hidden-cast behavior so the dedicated hunter cast bar can derive from the end-of-ranged-cycle hidden window (`windowEnd - ns.CAST_WINDOW`) instead of appearing as a start-of-cycle cast proxy.
- Hardened hunter `HandleSpellcastSucceeded` so it no longer forces a post-shot fallback cast window when no active hunter cast is actually detectable.
- Hardened hunter spellcast-start/UI glue so Auto Shot start events no longer seed cast-active fallback timing that can flash the cast bar at cycle start; cast-bar fallback seeding is now limited to live/active hunter cast contexts.
- Ranged timer reset paths now clear hunter cast state too, preventing stale hidden-cast bar remnants after auto-repeat stops or other ranged reset flows.

## 3.1.15 - 2026-04-30

- Polished Hunter hidden cast-window behavior so the fixed `ns.CAST_WINDOW` bar now anchors to cast/shot start timing, preventing the cast bar from visually stretching toward the full ranged cycle.
- Updated Hunter `UnitCastingInfo` fallback alignment to cast start timestamps for cleaner Auto Shot / Multi-Shot hidden-window display.
- Optimized timer sync events by filtering `UNIT_ATTACK_SPEED` and `UNIT_RANGEDDAMAGE` updates to `unit == "player"` before resyncing bars.

## 3.1.14 - 2026-04-30

- Decoupled the Hunter cast bar from full ranged swing duration so it now always renders as the fixed `ns.CAST_WINDOW` hidden Auto Shot cast window.
- Updated hunter cast-window start alignment to use end-of-cast timing (`UnitCastingInfo` end-time when available) so the cast bar shows the move-safe window rather than mirroring the full ranged cycle.
- Added an immediate swing-speed sync on swing start for melee/ranged timers to reduce first-frame drift and tighten white-swing/ranged timing accuracy.

## 3.1.13 - 2026-04-30

- Fixed a duplicated `ResetTimer` definition in the state engine so start/stop/restart flows use a single consistent idle reset path.
- Hardened hunter cast-state recovery by clearing hunter cast state on world/combat reset paths and accepting Classic `UnitCastingInfo` spell-name payloads when spell IDs are unavailable.
- Fixed shaman weave-family tint stability by copying family color tables before applying safe/unsafe alpha changes, preventing persistent color drift across casts.
- Polished ret paladin seal-twist overlays so the end-of-swing strike line stays visible for active twist families, while the separate reseal marker remains GCD-aware.

## 3.1.12 - 2026-04-29

- Unified the Hunter Auto Shot / Multi-Shot cast bar on the shared `ns.CAST_WINDOW` timing so the cast window stays consistent and no longer tracks the full ranged swing timer.
- Added a `UnitCastingInfo` fallback for the Hunter cast bar so the display can recover cleanly if the live cast state is briefly missing.
- Switched warrior queue tinting to a numeric queued-spell check so Heroic Strike and Cleave light up and clear reliably while Slam still uses the pause/extend path.
- Increased the unlocked-bar drag hit area so the frames are easier to grab and move during setup.
- Separated the bar background tint from the fill color so the background now has its own color swatch plus alpha control.
- Added a configurable bar border color swatch to go with the border-size slider, and kept the border rendering tied to the live bars during preview and reset.

## 3.1.11 - 2026-04-29

- Reworked the hunter Auto Shot / Multi-Shot cast-bar checks so they use shared spell-name lookups and keep the cast bar attached beneath the ranged timer when those shots fire.
- Split the warrior queue tints so Heroic Strike stays yellow, Cleave turns green, and Slam uses a white queue tint while the actual MH timer reset now lands on the combat-log hit.
- Added an adjustable bar border size control and widened the draggable hit area so unlocked bars are easier to move during the final polish pass.

## 3.1.10 - 2026-04-29

- Restored the hunter Auto Shot / Multi-Shot cast bar as a separate active-state preview so Auto Shot no longer drops out on the generic stop event.
- Added a `/sst` Test Bars action that temporarily previews the bars for repositioning, plus a clearer `Lock / Unlock Bars` control for moving frames.
- Enabled alpha selection on the main color swatches so class colors and custom colors can keep their opacity all the way through the live bar updates.
- Kept the base spark width at 4px and preserved the spark / class-color tint behavior during the final polish pass.

## 3.1.9 - 2026-04-29

- Restored the hunter Auto Shot / Multi-Shot bar with stored cast timing so it no longer depends only on live `UnitCastingInfo` reads.
- Bumped the base spark width back to 4px and kept the spark tint aligned with the ranged class color when class colors are enabled.
- Synced the docs and release notes to match the final polish pass.

## 3.1.8 - 2026-04-29

- Restored the `/sst` collapsible section layout with stable row groups so the config panel renders cleanly again.
- Slimmed the spark / weave defaults to compact bar-height-aligned markers and clamped the hunter, melee, paladin, and shaman overlays so they cannot balloon into full-height white bars.
- Kept the Hunter Auto Shot / Multi-Shot cast bar cast-only and positioned directly beneath the ranged timer.

## 3.1.7 - 2026-04-29

- Added a dedicated 10px Hunter Auto Shot / Multi-Shot cast bar beneath the ranged timer and kept it synced to the ranged texture, spark settings, and visibility rules.
- Corrected the TBC Multi-Shot and Slam rank spell IDs in the addon tables and swing-timer reference docs so the no-reset and pause logic stays aligned.
- Fixed the spellcast event handling to use Classic's 3-argument `UNIT_SPELLCAST_*` payloads so the hunter cast state and swing-reset logic read the live spell ID correctly.
- Polished the `/sst` panel with collapsible section headers and kept the Hunter cast bar cast-only so it appears only during actual Auto Shot / Multi-Shot casts.

## 3.1.6 - 2026-04-29

- Expanded the texture catalog so MH/OH and ranged bar rows stay focused on bar-style textures from Blizzard, SharedMedia, WeakAuras, and installed addon packs, while spark and weave spark rows can browse the broader thumbnail library.
- Switched the spark and shaman weave spark rows to folder-style browse buttons and kept the WeakAuras `Square_FullWhite` preset surfaced as `Normal`.
- Restored the spark alpha slider in the config panel so spark opacity can be tuned again alongside width, height, layer, and color.

## 3.1.5 - 2026-04-29

- Polished the spark texture picker into a dedicated thumbnail browser and surfaced the WeakAuras `Square_FullWhite` preset as `Normal`.
- Cleaned up the spark row labels and tooltip copy so the final release reads more like a curated UI than an internal settings panel.
- Kept the shaman weave default on `Target Indicator` and preserved the alternate triangle preset in the same texture library.

## 3.1.4 - 2026-04-28

- Added a green-safe hunter ranged cast-window state so the red zone now turns green when you stop before the breakpoint and only stays red when you are still moving too late.
- Kept the latency-aware cast-window math and black breakpoint marker intact while refreshing the movement feedback text in the README.

## 3.1.3 - 2026-04-27

- Kept the hunter Auto Shot spark and the shaman / ret paladin breakpoint markers above the bar fill by moving them to dedicated non-mouse overlay frames, so the overlays no longer disappear behind the status bar skin or mouse-hover HIGHLIGHT behavior.
- Stopped the bar fill itself from being promoted into the overlay layer when textures are changed, which preserves the intended draw order for sparks and breakpoint lines.
- Reworked the `/sst` config rows so cycle settings use visible dropdowns and slider rows include editable numeric fields.
- Let the dropdown rows open from the full row body, removed the dead texture-browser popup, and clear spark anchors before each update so the moving visuals stay stable and the settings panel is easier to use.
- Added subtle hover highlights to the clickable config rows so the dropdowns, toggles, and texture selectors read more clearly as interactive controls.
- Enabled mouse interaction on the texture rows so their hover highlights and click-open dropdowns actually work.
- Added hover tooltips to the config rows and controls so the UI explains what each setting represents when you mouse over it.

## 3.1.2 - 2026-04-24

- Kept the shaman weave spark, triangles, and ranged cast-threshold marker above the bar fill even when the user raises the bar texture layer.
- Kept the ret paladin seal breakpoint lines above the MH bar fill so the strike-edge and reseal markers stay visible during seal twisting.
- Re-resolved weave and breakpoint overlays whenever the bar texture layer changes so the visuals stay on top of the active bar skin.
- Updated shaman weave positioning to use the actual MH bar width instead of only the static default width.

## 3.1.1 - 2026-04-23

- Added a latency-aware hunter Auto Shot red-zone marker so the cast window shows up before the bar turns red.
- Added a dedicated ranged bar texture selector so Hunters can skin Auto Shot separately from MH / OH.
- Switched Hunter Auto Shot timing to use the Auto Shot cooldown API when active, anchoring the ranged bar to the cooldown start and falling back to `UnitRangedDamage()` when needed.
- Widened the `/sst` panel and clarified the MH / OH, ranged, and weave breakpoint appearance sections.
- Reflowed the `/sst` rows so labels sit above the controls and the texture, cycle, toggle, and color rows are easier to click.
- Hardened the paladin seal breakpoint lookup so it prefers aura names, uses verified seal IDs, and still works when a rank ID is missing.
- Expanded the paladin seal family table to match `docs/spellIds.md` for Command, Corruption, Blood, Martyr, Vengeance, Justice, Wisdom, Righteousness, Light, and Crusader.
- Restored the ret paladin seal breakpoint line so the actual strike-edge marker stays visible again, with a second latency-aware reseal marker for twist seals and an opaque black default color.

## 3.1.0 - 2026-04-23

- Added Blizzard Interface Options / AddOns registration so the config panel is available in-game without slash commands.
- Switched the primary slash aliases to `/sst`, `/super`, and `/superswingtimer`, and removed the `/swangthang` alias.
- Made the default MH / OH / ranged bar colors follow the player class color until you choose custom swatches.
- Added an indicator glow mode toggle so weave and spark markers can use either a bright glow or a more opaque blend.
- Reworked the texture dropdown to show actual texture previews alongside the texture names.
- Widened and re-labeled the `/sst` UI into clearer bar, weave, and color groups.

## 3.0.1 - 2026-04-23

- Added color-coded weave-family toggles for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal.
- Made the weave marker pair smaller and clarified the upper/lower marker labels in `/sst`.
- Widened the `/sst` panel and added clearer weave-assist descriptions and spacing.

## 3.0.0 - 2026-04-21

- Rebranded SwangThang to Super Swing Timer.
- Added /sst as the primary slash command.
- Kept legacy /swang and /swangthang aliases for migration.
- Added shaman weave assist for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal breakpoint tracking.
- Updated project metadata for CurseForge project 1521271 and author AcidBomb.
- Kept Classic/TBC-compatible timing fallbacks.
- Expanded the `/sst` panel with bar visibility toggles and a shaman weave-assist toggle.
- Replaced the browser texture picker with an in-addon dropdown showing `[category] label` entries (SharedMedia + Blizzard fallbacks). This enables quick texture selection without leaving the game.

## 2.5 - 2026-03-31

- Added texture-layer controls for both bar fill and spark.
- Added bar background alpha, spark alpha, minimal mode, and lock-bars controls.
- Added PLAYER_ENTERING_WORLD, throttled UNIT_AURA, and a low-frequency combat sanity ticker for accuracy.
- Bar and spark texture paths still accept any installed texture path.
- Kept GetTimePreciseSec as a safe preference with GetTime fallback.

## 2.4

- Added a bar texture selector to the config panel.
- Improved texture application and preview handling.

## 2.1

- Added the seal-twist overlay preview.
- Added the config panel and initial melee support refinements.
