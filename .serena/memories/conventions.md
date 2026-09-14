# Code Conventions & Patterns

## Namespace & Globals

- **File Header Pattern**:
  ```lua
  local addonName, ns = ...
  local CreateFrame = rawget(_G, "CreateFrame")
  local UIParent = rawget(_G, "UIParent")
  ```
- **Namespace Scope**: All inter-file routines, timers, configurations, and frame references attach to `ns`.
- **Zero Global Leaks**: Every variable must be `local` or explicitly assigned to `ns` or `_G[key]`.
- **Avoid Upvalue Shadowing**: In callbacks, use descriptive parameter names (e.g., `fs` or `frame`) rather than shadowing `self`.

## Typography & Localization

- **Font Resolver**: Never hardcode `"Fonts\\FRIZQT__.TTF"` or path strings.
- Always resolve fonts through `ns.GetDefaultFont()` or `GetFontPath()` to query `rawget(_G, "STANDARD_TEXT_FONT")`.
- Guarantees proper rendering on Cyrillic (`ruRU`), Korean (`koKR`), and Chinese (`zhCN`, `zhTW`) clients.

## Frame Geometry & UI Construction

- **Unified Power Bar**: `SuperSwingTimerPlayerPowerBar` (`ns.playerPowerBar`) used across all classes at standardized 10px height.
- **Hunter Auto Shot Bar**: Standardized at 15px height (`ns.HUNTER_CAST_BAR_HEIGHT = 15`).
- **Hunter Cast Bar & Clip Zone**:
  - Keep the Hunter cast bar background an unobstructed dark status bar; do not overlay full-bar opaque textures.
  - Keep Clip Zone ("red zone") / Clip Safe colors independently configurable from Cast Bar color (`colors.hunterCastBar`).
  - Pre-seed `ColorPickerFrame:SetColorRGB()` and `ColorPickerFrame:SetColorAlpha()` before opening color pickers.
- **Debuff Bars**: Anchored strictly to the outside left (`RIGHT`, `bar`, `LEFT`, -2, 0) with texture crop `SetTexCoord(0.07, 0.93, 0.07, 0.93)`. Bars align at X=0.
- **Buff & Cooldown Icons**:
  - Timer text centered strictly **above** the icon (`"BOTTOM", icon, "TOP", 0, 2`, centered justify).
  - Stack count text on the icon face (`"BOTTOMRIGHT"`, 11pt outline, white text).
- **Glow & Border Textures**: Construct explicit named textures (`top`, `bottom`, `left`, `right`) with direct numeric offsets (`SetPoint("TOPLEFT", -1, 1)` etc.). Never iterate positional arrays over coordinate tuples.
- **Frame Strata**: Swing bars on `MEDIUM`, Buff/CD icons on `DIALOG`, Weave Spark Overlay on child frame at `FrameLevel + 6`.

## Dual-Client Compatibility Patterns

- Gracefully check for Modern Classic APIs (`C_Spell`, `C_UnitAuras`, `IsSpellKnownOrOverridesKnown`) and fall back to Classic Era globals (`GetSpellInfo`, `UnitBuff`, `UnitDebuff`, `IsPlayerSpell`).
- For DB migrations, increment `ns.DB_CURRENT_VERSION` and add sequential migrations in `MigrateDB()` in `SuperSwingTimer.lua`.
- Timing engine relies on `GetTimePreciseSec()` for sub-millisecond precision with `GetTime()` fallback.