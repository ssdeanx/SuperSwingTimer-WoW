# SavedVariables, Settings & Migration Engine

## SavedVariables Architecture
- Primary global: `SuperSwingTimerDB` (Schema Migration `v63`).
- Automatic migration on load from legacy profiles: `SwangThangDB`, `HunterTimerDB`.
- Default configuration defined in `ns.DB_DEFAULTS` (`SuperSwingTimer_Constants.lua`).

## Sequential Migration Pipeline (`SuperSwingTimer.lua`)
- Monotonically increments from `db.version + 1` up to `ns.DB_CURRENT_VERSION` (63).
- Migration 62: Multi-class power bar settings, Hunter 15px cast bar default, class resource colors.
- Migration 63: Repairs corrupted white `autoShotUnsafe` back to red `{ r = 1, g = 0, b = 0, a = 0.4 }`, seeds `clipZone`/`clipSafe` aliases, and ensures independent Hunter Cast Bar color.

## Color Picker Hardening Rule
- Pre-seed `ColorPickerFrame:SetColorRGB()` and `ColorPickerFrame:SetColorAlpha()` prior to opening so unseeded white is never saved on click.

## Configuration UI (`SuperSwingTimer_Config.lua`)
- Quick Controls: Two-column layout for Visibility toggles and Key Color swatches.
- Appearance: Sliders for dimensions, spacing, texture browsers, and layer dropdowns.
- Slash commands: `/sst` (config), `/sst test` (previews), `/sst lock`/`unlock`, `/sst reset`, `/ssttest` (WoWUnit tests).

## Related Memories
- Main architecture map: `mem:core`
- UI and typography conventions: `mem:conventions`
- Hunter ranged engine: `mem:ranged_engine`
