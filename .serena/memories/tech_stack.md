# Technology Stack & Environment

## Languages & Runtimes

- **Language**: Lua 5.1 (World of Warcraft embedded Lua runtime).
- **Target WoW Interfaces**:
  - Classic Era & Season of Discovery: Interface `11509` (1.15.x).
  - TBC Anniversary: Interface `20506` (2.5.6).
- **API Environment**: Blizzard FrameXML API with dual-client fallback support (Modern Classic APIs like `C_Spell`, `C_UnitAuras` alongside legacy globals like `GetSpellInfo`, `UnitBuff`, `UnitDebuff`).

## Development & Tooling

- **Linter**: `luacheck` configured in `.luacheckrc`.
  - Target std: `lua51+min`.
  - Global whitelist: Extensive WoW globals defined in `.luacheckrc`.
  - Max line length: 260 characters.
  - Policy: Zero warnings, zero errors.
- **Language Server**: Lua Language Server (`LuaLS`) configured via `.luarc.json`.
- **In-Game Testing**: `WoWUnit` test framework integrated into `SuperSwingTimer_Tests.lua` (slash command `/ssttest`).
- **Code Graph**: Indexed via `.codegraph/`.

## Upstream Documentation & Reference

- **Blizzard Interface Source Mirror**: `https://github.com/Gethe/wow-ui-source`
  - Branches: `classic_era` (1.15.x / SoD), `classic` / `bcc` (2.5.6 TBC), `live` (Retail).
  - Key Inspection Paths: `Interface/FrameXML/`, `Interface/SharedXML/`, `Interface/AddOns/Blizzard_APIDocumentationGenerated/`.
  - Used to verify API signatures, FrameXML return types, and payload changes across patches.