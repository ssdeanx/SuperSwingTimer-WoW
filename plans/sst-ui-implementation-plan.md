# Plan: Super Swing Timer UI overhaul

Build a polished `/sst` configuration experience without losing Classic/TBC compatibility. The current custom panel is functional but long and flat; the new version should be scrollable, sectioned, easier to scan, and better suited to bar personalization and the shaman weave overlay.

## User stories

1. As a hunter, I want to quickly tune the ranged bar, spark, and warning colors so I can see auto-shot windows clearly in raid and solo play.
2. As an enhancement shaman, I want a compact weave marker that shows the safe Lightning Bolt / Chain Lightning / healing cast window so I can weave without clipping swings.
3. As a raid leader or power user, I want presets and clear grouping so I can switch between a minimal setup and a high-information setup quickly.
4. As a casual player, I want the panel to be easy to scan without knowing addon internals, so the important options are obvious and not buried.
5. As an accessibility-focused player, I want text, contrast, and layering controls so I can make the bars readable for my UI setup.
6. As a returning user, I want settings to persist cleanly and the layout to survive reloads so I do not have to reconfigure every session.
7. As a power user, I want a searchable texture browser plus a manual texture path field so I can use common Blizzard textures or any custom texture path without guessing names.

## Steps

1. Expand the settings schema in `SuperSwingTimer_Constants.lua` and `SuperSwingTimer.lua` to cover the new UI state we want to expose: layer selectors per texture, weave triangle presentation settings, and any additional display toggles.
2. Refactor `SuperSwingTimer_Config.lua` into a scrollable categorized panel with section headers for General, Visibility, Appearance, Class, Shaman Weave Assist, and Advanced.
3. Add data-driven option row helpers so dropdowns, toggles, sliders, and color buttons can be reused instead of hand-built in one-off blocks.
4. Add a dedicated weave marker row group that uses a small triangle-style texture instead of a normal bar, with spell-family colors and layer controls.
5. Wire the new controls to the runtime apply functions in `SuperSwingTimer_UI.lua`, keeping live preview behavior intact.
6. Update the docs and release notes after the UI is stable.
7. Provide a searchable texture browser with preview swatches and a manual path entry so users can select preset textures or any valid texture path.

## Relevant files

- `C:\Users\ssdsk\SuperSwingTimer\SuperSwingTimer_Config.lua` — rebuild the panel shell and add grouped controls.
- `C:\Users\ssdsk\SuperSwingTimer\SuperSwingTimer_UI.lua` — runtime apply behavior for bar visibility, layers, and weave marker display.
- `C:\Users\ssdsk\SuperSwingTimer\SuperSwingTimer_Constants.lua` — defaults and option metadata.
- `C:\Users\ssdsk\SuperSwingTimer\SuperSwingTimer.lua` — migration / initialization hooks.
- `C:\Users\ssdsk\SuperSwingTimer\SuperSwingTimer_Weaving.lua` — weave alert display rules and spell-specific presentation.
- `C:\Users\ssdsk\SuperSwingTimer\docs\UI.md` — UI research notes.
- `C:\Users\ssdsk\SuperSwingTimer\docs\Widgets.md` — widget/API implementation notes.
- `C:\Users\ssdsk\SuperSwingTimer\docs\APIS.md` — API facts and caveats.
- `C:\Users\ssdsk\SuperSwingTimer\AGENTS.md` — authoritative project rules and research references.

## Relevant Blizzard source references

These files from `Gethe/wow-ui-source` are the most useful anchors for the UI refactor:

- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua` — current settings framework entry points and pattern usage.
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua` — Blizzard settings implementation guidance.
- `Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenu.lua` — dropdown behavior and patterns.
- `Interface/AddOns/Blizzard_FrameXMLBase/GradualAnimatedStatusBar.lua` — status bar animation/behavior reference.
- `Interface/AddOns/Blizzard_UIWidgets/Mainline/Blizzard_UIWidgetTemplateBase.lua` — base widget/template patterns.
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/ScreenDocumentation.lua` — generated API docs layout and naming conventions.

## Verification

1. Open `/sst` and confirm the panel scrolls cleanly on a small window.
2. Test each section toggle and dropdown to confirm the correct live preview changes.
3. On a Shaman, verify the triangle weave marker colors and layers update correctly.
4. Confirm bar fill, spark, and weave marker overlap as expected after layer changes.
5. Check that settings persist across reloads and that the workspace diagnostics remain clean.
6. Compare the implementation against the Blizzard source reference files above to ensure the panel design matches native UI expectations.

## Decisions

- Use the current custom UI path first rather than adopting Ace3 immediately.
- Keep the panel Classic/TBC-safe.
- Use a triangle-style weave marker instead of a full-width bar so the alert is more compact and readable.
- Expose draw-layer selection for each major texture region so advanced users can control overlap.
- Keep the UI data-driven so new settings can be added without rewriting the layout every time.
- Add a texture browser popup with preset texture swatches and a freeform path field because WoW Classic does not expose a complete texture-file enumeration API.
- Finalize the Shaman weave presentation as a three-part overlay: a casting-only spark plus an upper and lower triangle marker, each with independent size, texture, alpha, and layer controls.
- Treat version 8 as the SavedVariables migration point for the new weave spark and triangle settings.

## Further considerations

1. Add search/filter once the panel exceeds one scroll page.
2. Add presets such as Default, Minimal, Raid, Solo, and Shaman Weave Focus.
3. Consider Ace3 only if we later want built-in profiles and Blizzard settings integration.
4. Consider optional profile import/export text later if advanced users ask for sharing setups.
