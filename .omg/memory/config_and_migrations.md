# SavedVariables, Settings & Migration Engine

## 1. SavedVariables Architecture

- **Primary Global**: `SuperSwingTimerDB`
- **Legacy Profiles**: Automatically detected and migrated on first load:
  - `SwangThangDB`
  - `HunterTimerDB`
- **Default Database**: Stored in `ns.DB_DEFAULTS` in `SuperSwingTimer_Constants.lua`.

## 2. Sequential Migration Pipeline (`ns.DB_MIGRATIONS`)

- Located in `SuperSwingTimer.lua`.
- Tracked via `ns.DB_CURRENT_VERSION` (currently **63**).
- When a user logs in with an older schema version, migrations run sequentially from `db.version + 1` up to `ns.DB_CURRENT_VERSION`:
  - Ensures seamless upgrades without resetting player configurations.
  - Seeds missing color swatches, new bar toggles, or standardized dimensions.
  - Migration **v62**: Seeds `showPowerBar`, default Hunter cast bar height (15px), and per-class resource bar colors.
  - Migration **v63**: Repairs corrupted white `autoShotUnsafe` back to red, synchronizes `clipZone`/`clipSafe` color aliases, and guarantees independent Hunter Cast Bar color.

## 3. Options Panel Architecture (`SuperSwingTimer_Config.lua`)

- **Integration**: Registered with Blizzard's modern `Settings.RegisterCanvasLayoutCategory` or legacy `InterfaceOptions_AddCategory`.
- **Addon Compartment**: Registered with `AddonCompartmentFrame` for drop-down access on modern clients.
- **Layout**:
  - **Quick Controls**: Two-column layout at top of panel for rapid toggling of Visibility (bars, helpers, icons) and Key Colors (swing, spark, debuffs).
  - **Sliders**: Bar dimensions, alpha, spacing, update intervals.
  - **Color Pickers**: Uses Blizzard's `ColorPickerFrame` with full opacity support.
- **Slash Commands**:
  - `/sst` or `/superswingtimer`: Opens configuration dialog.
  - `/sst test`: Toggles visual test bars for frame positioning.
  - `/sst reset`: Resets current profile to defaults.
  - `/ssttest`: Runs in-game WoWUnit test suite.
