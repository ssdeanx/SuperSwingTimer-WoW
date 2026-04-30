# Super Swing Timer Changelog

## 3.1.12 - 2026-04-29

- Separated the bar background tint from the fill color so the background now has its own color swatch plus alpha control.
- Added a configurable bar border color swatch to go with the border-size slider, and kept the border rendering tied to the live bars during preview and reset.
- Kept the warrior next-melee queue split cleanly from Slam so Heroic Strike / Cleave can cancel back to the MH base color while Slam still uses the pause/extend path.
- Relaxed the hunter cast-bar stop handling so the Auto Shot / Multi-Shot cast bar can remain visible for its actual duration instead of clearing immediately on the stop event.

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
