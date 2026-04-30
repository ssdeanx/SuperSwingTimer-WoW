# Super Swing Timer UI Notes

This document captures the UI direction for `/sst`.

## Panel direction

- Use a scrollable custom panel instead of a flat, fixed-height stack.
- Keep the footer actions fixed outside the scrolling area so Reset and Close stay visible.
- Group options into visible, collapsible sections with stable row groups: Visibility, Appearance, Behavior, Colors, and Shaman Weave Assist.

## Layout patterns to keep

- Use compact row helpers for toggles, sliders with editable numeric fields, text inputs, and dropdown selector rows.
- Prefer data-driven refresh helpers so live preview updates stay in one place.
- Use a small subtitle under the title to explain what the panel controls.
- Avoid one dense vertical wall of controls; sectioning is the readability win.

## Addon-specific UI goals

- Add dropdown layer selectors for each visible texture region:
  - bar fill layer
  - spark layer
  - weave marker layer
  - any new overlay layers later
- Keep visual cues on a dedicated overlay frame above the bar fill so breakpoint markers never depend on hover-sensitive HIGHLIGHT ordering.
- Keep the hunter Auto Shot / Multi-Shot cast bar separate from the ranged swing bar, with a small previewable bar that can be shown during `/sst` testing even when it is not actively casting.
- Add weave-assist presentation options:
  - show / hide weave overlay
  - tiny upper / lower marker pair that follows the spell-haste-adjusted safe swing point
  - marker size, gap, alpha, and layer controls, with compact spark defaults that stay bar-height aligned instead of becoming a full-height glow
  - color selection by spell family
  - per-family enable / disable toggles for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal
- Texture selection should use compact preview dropdown rows for the MH/OH and ranged bars, but those dropdowns should stay focused on bar-style textures from Blizzard, SharedMedia, WeakAuras, and installed addon packs. The spark row and the shaman weave spark row should open a dedicated thumbnail browser seeded with the Normal `Square_FullWhite` preset, and the collapsed rows should summarize the current texture and the active bar texture while the spark previews clamp to the host bar height.
- Make the row controls obvious: toggles use the right-side checkbox, selector settings use the right-side dropdown, and sliders expose a right-side editable numeric field.
- Include a `Lock / Unlock Bars` control plus a temporary `Test Bars` action so players can preview and reposition the bars without fighting the normal combat visibility rules.
- Make the unlocked bars easy to grab by giving them a slightly larger drag hit area, and expose a bar border size control so the frame outline can be tuned instead of being fixed at a single pixel thickness.
- Let every main bar color swatch open the color picker with opacity support so the class-color palette can still be tuned with alpha.
- Add hover tooltips to explain what each row changes so the panel remains understandable without memorizing the labels.
- Keep the panel responsive and straightforward to scan.

## Texture browser constraint

- WoW does not expose a full API that enumerates every texture file on disk.
- The addon should therefore provide:
  - a preset texture browser for common UI assets gathered from Blizzard fallbacks, LibSharedMedia registrations, and curated addon texture packs
  - a manual texture path entry for any custom or packaged texture

## Blizzard references checked

- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_CategoryList.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua`

## Notes for the addon

- Keep the panel Classic/TBC-safe.
- Use the current custom UI path first; do not depend on Blizzard's new settings UI for compatibility.
- Preserve live preview behavior when changing colors, textures, or visibility.
