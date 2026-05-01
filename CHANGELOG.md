# Super Swing Timer Changelog

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
