# Super Swing Timer API Notes

This document stores the API facts we should rely on while building the `/sst` UI.

## Classic/TBC API points that matter here

- Frame creation and scripts: `CreateFrame`, `SetScript`, `OnUpdate`, `OnShow`, `OnHide`.
- Bars and overlays: `StatusBar`, `SetStatusBarTexture`, `SetStatusBarColor`, `SetDrawLayer`, `SetAlpha`.
- UI controls: `ScrollFrame`, `EditBox`, `CheckButton`, `Slider`, `UIDropDownMenu` helpers.

## Weaving logic inputs

- `GetNetStats()` for latency estimation.
- `UnitSpellHaste()` when available for cast-time scaling.
- `UnitCastingInfo()` for active cast timing.
- `GetSpellInfo()` for resolving ranks and cast times.

## Hunter ranged timing inputs

- `GetSpellCooldown(75)` / `GetSpellCooldown("Auto Shot")` for the active Auto Shot cooldown when the client exposes it.
- `UnitRangedDamage()` for ranged weapon speed; the first return value is the ranged speed, and it reflects ranged haste rather than melee haste.

## StatusBar / texture reminders

- `StatusBar:SetStatusBarTexture(asset)` sets the fill texture.
- Draw-layer control should be done via `GetStatusBarTexture():SetDrawLayer()`.
- `StatusBar:SetStatusBarColor()` controls the fill tint.
- `StatusBar:SetValue()` and `StatusBar:SetMinMaxValues()` drive the actual timer fill.
- `TextureBase:SetRotation()` can help orient a marker if a triangle asset is used.

## Blizzard source files worth checking

- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_CategoryList.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenu.lua`
- `Interface/AddOns/Blizzard_FrameXMLBase/GradualAnimatedStatusBar.lua`

## Compatibility reminder

- Keep the addon compatible with Classic / TBC-era behavior and avoid assuming Retail-only systems.
