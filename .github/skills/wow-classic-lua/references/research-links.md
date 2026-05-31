# WoW Classic / TBC Addon Research Links

This is the curated link file for future addon work.
Use it as the first stop before guessing at API or widget behavior.

## ASCII research path

```ascii
Question appears
  |
  +-- API signature/returns?
  |      -> Classic API + specific API page
  +-- widget/handler behavior?
  |      -> Widget API + Widget script handlers
  +-- XML/template behavior?
  |      -> XML schema + FrameXML + Blizzard source
  +-- still uncertain?
         -> compare wiki.gg with Gethe source and test in-client
```

## Best first links

- Classic API hub:
  <https://warcraft.wiki.gg/wiki/World_of_Warcraft_API/Classic>
- Widget API:
  <https://warcraft.wiki.gg/wiki/Widget_API>
- Widget script handlers:
  <https://warcraft.wiki.gg/wiki/Widget_script_handlers>
- XML schema:
  <https://warcraft.wiki.gg/wiki/XML_schema>
- CreateFrame:
  <https://warcraft.wiki.gg/wiki/API_CreateFrame>

## Core widget pages

- Frame: <https://warcraft.wiki.gg/wiki/UIOBJECT_Frame>
- StatusBar: <https://warcraft.wiki.gg/wiki/UIOBJECT_StatusBar>
- Texture: <https://warcraft.wiki.gg/wiki/UIOBJECT_Texture>
- FontString: <https://warcraft.wiki.gg/wiki/UIOBJECT_FontString>
- ScrollFrame: <https://warcraft.wiki.gg/wiki/UIOBJECT_ScrollFrame>
- Slider: <https://warcraft.wiki.gg/wiki/UIOBJECT_Slider>
- Layer details: <https://warcraft.wiki.gg/wiki/Layer>

## Event and timing APIs

- Combat log: <https://warcraft.wiki.gg/wiki/API_CombatLogGetCurrentEventInfo>
- Melee speed: <https://warcraft.wiki.gg/wiki/API_UnitAttackSpeed>
- Ranged speed: <https://warcraft.wiki.gg/wiki/API_UnitRangedDamage>
- Casting: <https://warcraft.wiki.gg/wiki/API_UnitCastingInfo>
- Channeling: <https://warcraft.wiki.gg/wiki/API_UnitChannelInfo>
- Spell haste: <https://warcraft.wiki.gg/wiki/API_UnitSpellHaste>
- Cooldowns: <https://warcraft.wiki.gg/wiki/API_GetSpellCooldown>
- Net stats / latency: <https://warcraft.wiki.gg/wiki/API_GetNetStats>
- `OnEvent`: <https://warcraft.wiki.gg/wiki/UIHANDLER_OnEvent>
- `OnUpdate`: <https://warcraft.wiki.gg/wiki/UIHANDLER_OnUpdate>

## Dropdown / config helpers

- `UIDropDownMenu_Initialize`:
  <https://warcraft.wiki.gg/wiki/API_UIDropDownMenu_Initialize>
- `UIDropDownMenu_CreateInfo`:
  <https://warcraft.wiki.gg/wiki/API_UIDropDownMenu_CreateInfo>

## Blizzard / extracted source

- Gethe UI source root:
  <https://github.com/Gethe/wow-ui-source>
- Blizzard API docs folder:
  <https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns/Blizzard_APIDocumentation>
- Blizzard generated API docs folder:
  <https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns/Blizzard_APIDocumentationGenerated>

## Older fallback references

These are still useful when a page is missing on wiki.gg, but treat them as
secondary after current wiki.gg pages:

- <https://wowpedia.fandom.com/wiki/World_of_Warcraft_API/Classic>
- <https://wowpedia.fandom.com/wiki/Lua_functions>
- <https://wowpedia.fandom.com/wiki/Widget_API>
- <https://wowpedia.fandom.com/wiki/Widget_script_handlers>
- <https://wowpedia.fandom.com/wiki/XML_schema>
- <https://wowpedia.fandom.com/wiki/FrameXML_functions>
- <https://wowpedia.fandom.com/wiki/Events/Classic>

## ASCII source-of-truth priority

```ascii
+-------------------------------+
| Source priority                |
+-------------------------------+
| Primary:   warcraft.wiki.gg    |
| Secondary: Gethe / Blizzard UI |
| Fallback:  legacy wowpedia     |
+-------------------------------+
```

## Research notes from 2026-05-30 refresh

- `warcraft.wiki.gg/wiki/World_of_Warcraft_API/Classic` reported current branch
  coverage for Classic Anniversary and TBC Anniversary builds.
- Core widget pages for Frame, StatusBar, Texture, ScrollFrame, and Slider were
  all current enough to use as primary references.
- `Widget_API` and `Widget_script_handlers` remain the fastest way to confirm
  whether a handler or method belongs to a given widget class.
- `CreateFrame` and object pages remain better than memory for template and
  widget details.
