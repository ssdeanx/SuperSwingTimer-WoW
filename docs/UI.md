# Super Swing Timer UI Notes

This document captures the UI direction for `/sst`.

## Panel direction

- Use a scrollable custom panel instead of a flat, fixed-height stack.
- Keep the footer actions fixed outside the scrolling area so Reset and Close stay visible.
- Group options into visible sections: Visibility, Appearance, Behavior, Colors, and Shaman Weave Assist.

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
- Add weave-assist presentation options:
  - show / hide weave overlay
  - tiny upper / lower marker pair that follows the spell-haste-adjusted safe swing point
  - marker size, gap, alpha, and layer controls
  - color selection by spell family
  - per-family enable / disable toggles for Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, and Chain Heal
- Texture selection should use the in-addon dropdown with preview rows and the SharedMedia / Blizzard fallback library; the collapsed row should summarize the current texture and the active bar texture.
- Make the row controls obvious: toggles use the right-side checkbox, selector settings use the right-side dropdown, and sliders expose a right-side editable numeric field.
- Add hover tooltips to explain what each row changes so the panel remains understandable without memorizing the labels.
- Keep the panel responsive and straightforward to scan.

## Texture browser constraint

- WoW does not expose a full API that enumerates every texture file on disk.
- The addon should therefore provide:
  - a preset texture browser for common UI assets
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
