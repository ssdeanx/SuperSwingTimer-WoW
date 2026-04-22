# Super Swing Timer FrameXML Notes

This document stores frame and XML-level facts that matter for `/sst`.

## Useful implementation anchors

- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua` for Blizzard settings guidance.
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua` for panel structure ideas.
- `Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenu.lua` for dropdown behavior.
- `Interface/AddOns/Blizzard_FrameXMLBase/GradualAnimatedStatusBar.lua` for animated bar behavior.

## Frames and layered regions

- `CreateFrame()` can create frames, status bars, textures, font strings, and other UI objects.
- Frames own layered regions; draw order is managed through layers and sublayers.
- Layer order matters for overlapping UI:
  - BACKGROUND
  - BORDER
  - ARTWORK
  - OVERLAY
  - HIGHLIGHT

## Practical implications for `/sst`

- Bar fill, spark, weave marker, and overlays should each have their own layering strategy.
- A small weave marker can be a separate texture region rather than trying to fake it with the status bar fill.
- Keep the preview widgets in the same frame tree as the config panel so live changes are easy to see.

## Scroll frames

- Scrollable UI is the right choice for a growing settings panel.
- Reused frames need explicit reset logic when repopulated with new data.

## XML / UI notes

- Use `BackdropTemplate` where needed for classic panel styling.
- Use `Frame:CreateTexture()`, `Frame:CreateFontString()`, and `Frame:CreateMaskTexture()` for custom controls and icons.
- Be careful with secure / restricted behavior when working with protected objects in combat.

## Source references

- Warcraft Wiki: Making scrollable frames
- Warcraft Wiki: Layer
- Warcraft Wiki: Frame / Widget API
