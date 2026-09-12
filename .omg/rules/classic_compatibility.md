---
description: Client compatibility standards for Classic Era (1.15.x) and TBC Anniversary (2.5.6)
globs: "*.lua"
alwaysApply: true
---

# Classic Era & TBC Anniversary Compatibility Rules

1. **Dual-API Branching**:
   - For spell information: check `C_Spell.GetSpellInfo` first, fallback to `GetSpellInfo`.
   - For spell cooldowns: check `GetSpellCooldown`, fallback to `C_Spell.GetSpellCooldown`.
   - For auras: check `C_UnitAuras.GetAuraDataByIndex` first, fallback to `UnitBuff` / `UnitDebuff`.
   - For spell knowledge: check `IsSpellKnownOrOverridesKnown`, then `IsSpellKnown`, then `IsPlayerSpell`.

2. **Localized Font Resolution**:
   - Never hardcode `"Fonts\\FRIZQT__.TTF"`.
   - Always query `rawget(_G, "STANDARD_TEXT_FONT")` before Western fallback to avoid Lua errors and unreadable question marks on ruRU/koKR/zhCN/zhTW clients.

3. **Glow Border Construction**:
   - Construct 4 explicit named border textures (`top`, `bottom`, `left`, `right`).
   - Do not pass table iteration variables or strings like `"Height"` into `SetPoint()`.

4. **Zero Luacheck Warnings**:
   - All code edits must preserve zero warnings and zero errors under `luacheck .`.
