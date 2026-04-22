# Super Swing Timer Widget Notes

This document captures widget-level patterns that matter for `/sst`.

## Dropdown menus

- Use `UIDropDownMenuTemplate` for finite option lists.
- Populate choices with `UIDropDownMenu_CreateInfo()` and `UIDropDownMenu_AddButton()`.
- Use `checked` for the active value instead of relying on `SetSelected*` helpers.
- Use `hasArrow` and `menuList` only when a submenu is genuinely useful.

## Scrollable lists

- Prefer `ScrollFrame` or modern `ScrollBox` patterns for long option panels when available.
- Reusable rows should reset state cleanly when they are reused or refreshed.
- A managed scrollbar feels more polished when the content size changes.

## Texture-based indicators

- `TextureBase:SetVertexColor()` is the right way to tint an indicator image per spell.
- `TextureBase:SetColorTexture()` is useful for placeholder blocks but not for a triangle icon.
- `TextureBase:SetTexCoord()` can crop or transform texture display.
- `TextureBase:SetRotation()` can orient a square or triangular texture when needed.
- `LayeredRegion:SetDrawLayer(layer, subLayer)` controls overlap order within the same frame.

## Suggested weave indicator approach

- Use a small triangle or chevron texture, not a full bar.
- Tint it by spell family:
  - Lightning Bolt: lighter blue
  - Chain Lightning: darker blue
  - Healing spells: green
- Place it near the expected swing boundary on the MH bar or in a dedicated overlay zone.
- Let the indicator use a configurable draw layer so it can sit above or below the bar fill as needed.

## Texture browser pattern

- Use a searchable popup with preview swatches for common assets.
- Keep a manual path entry in the same popup so users can type any valid texture path.
- Show the current texture preview beside the row so the selected asset is obvious.

## Blizzard references checked

- `Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenu.lua`
- `Interface/AddOns/Blizzard_FrameXMLBase/GradualAnimatedStatusBar.lua`
- `Interface/AddOns/Blizzard_SharedXMLBase/TextureUtil.lua`
- `Interface/AddOns/Blizzard_UIPanels_Game/Mainline/CastingBarFrame.lua`
