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

- Blizzard Interface Options / AddOns registration is now wired for the config panel.
- Primary slash aliases are `/sst`, `/super`, and `/superswingtimer`; `/swangthang` has been removed.
- Default bar colors now use class colors until the user picks custom swatches, and the indicator blend mode can switch between glow and opaque.
- The texture dropdown now uses preview thumbnails, and the `/sst` panel is wider with clearer grouping and labels.
