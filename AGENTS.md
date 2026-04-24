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
