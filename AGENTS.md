# AGENTS.md - Super Swing Timer

## Project overview

Super Swing Timer is a World of Warcraft Classic/TBC addon for swing-timer tracking.
It shows melee and ranged bars for supported classes, with class-specific
behavior for hunter auto shot, warrior slam/NMA handling, parry haste, druid
form resets, ret paladin seal-twist timing, and shaman weaving breakpoint help.

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
- Current focus is in-game validation for hunter Auto Shot, then a look at the ret paladin seal-twist window and coloring.
