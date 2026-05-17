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
- Current focus is in-game validation for hunter Auto Shot, then a look at the ret paladin seal-twist window and coloring.
