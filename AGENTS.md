# Super Swing Timer

Classic Era + TBC Anniversary melee/ranged swing timer addon, thousands of users. **9 Lua files**, single `ns` table, zero dependencies.  
**v0.1.7** | **DB schema: v54** (`ns.DB_DEFAULTS.version`) | **CurseForge / GitHub Releases**

> **Research note:** AGENTS.md adds 0% task improvement with 20%+ inference cost (ICLR 2026, ETH Zurich). This file is stripped to what agents *cannot* discover from the code itself.

---

## Live install (Wine, NOT source repo)

The live game path is the authoritative copy. Source repo at `~/SuperSwingTimer-WoW/` is a git mirror, not what WoW reads.

```
/home/sam/Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft/_anniversary_/Interface/AddOns/SuperSwingTimer/
```

File permission quirk: `write_file` creates 600. WoW under Wine needs 644 (`chmod 644` after every write_file or files silently fail to load).

---

## Quality gates

Manual QA is the only bug barrier. Every change:

1. `luac -p` on ALL 9 `.lua` files (Lua 5.1 — no `<<` operator, use `2 ^ n`)
2. `luacheck` 0 warnings (Windows: `C:\Users\ssdsk\luacheck.exe`)
3. In-game: combat→bars appear, swing→timer resets, class overlays for correct class only, `/sst reset` no errors
4. CHANGELOG.md updated
5. **Dual-client:** TBC Anniversary 2.5.5 differs from Classic Era — wrappers must not break the other
6. **CLEU payloads:** Classic sends numeric spellIDs, TBC Anniversary sends localized strings — populate both key types at init

---

## Architecture essentials

**Dependency order:** Constants → State → Weaving → Hooks → UI → ClassMods → Config → Main → Tests

**10 files:**

| File | Purpose |
|------|---------|
| `Constants.lua` | DB defaults, spell catalog, ALL ns.* wrappers (`ns.UnitAura`, `ns.GetSpellInfo`, `ns.GetAlignedTime`, `ns.GetUnitCastingSpellInfo`) |
| `State.lua` | Timer structs (`ns.timers.mh/oh/ranged/enemy`), CLEU/spellcast handlers, speed sync |
| `Weaving.lua` | Shaman weave breakpoints (SHAMAN only) |
| `Hooks.lua` | OnUpdate hook registration (`ns.RegisterOnUpdateHook`) |
| `UI.lua` | Bar frames, `ns.OnUpdate()` render, Apply* styling |
| `ClassMods.lua` | 6 Setup* functions + `GetHarmfulAuraData`/`GetHelpfulAuraData` locals |
| `Config.lua` | Config panel, sliders, swatches, texture browser |
| `Main.lua` | Event routing, slash commands, init, migration, flags |
| `Tests.lua` | WoWUnit test suite (see below) |

**Render order:** `ns.OnUpdate()` in UI.lua — call order IS render order  
**Event map:** `OnEvent` elseif chain in Main.lua  
**Clock:** `GetTimePreciseSec()` via `ns.GetAlignedTime()` — never bare `GetTime()`  
**Timers:** `{ state, startTime, endTime, duration, speed, holdEnd }`  
**CLEU:** `SWING_DAMAGE`/`SWING_MISSED` drives `StartSwing`. Extra attacks/Slam/haste use short-lived flags.  
**ClassMods:** Nil-guard all dynamic calls (`if ns.Func then ns.Func() end`) — crashes on wrong class

---

## Canonical API wrappers (CRITICAL — single source of truth)

All raw Blizzard API calls route through `ns.UnitAura(unit, index, filter)` in Constants.lua. This normalizes 4+ client return shapes into:
`name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID`

Use `ns.UnitBuff(unit, index)` and `ns.UnitDebuff(unit, index)` for convenience.  
**Never call raw `UnitAura()`, `UnitBuff()`, or `UnitDebuff()` directly.** If you add a new Blizzard API wrapper, add it next to `ns.UnitAura` in Constants.lua.

Other wrappers: `ns.GetSpellInfo(id)`, `ns.GetUnitCastingSpellInfo(unit)`, `ns.GetAlignedTime()`

---

## New settings protocol (6 files)

Every setting touches exactly: `ns.DB_DEFAULTS` (Constants) → migration case in `MigrateDB()` (Main.lua) → Apply* (UI.lua) → config control (Config.lua) → README.md → TOC version.

**Never remove old migration cases.** Users skip versions. Breaking a migration corrupts user settings irreversibly.

---

## WoWUnit tests

73 tests across 4 groups: **SST-Core** (constants/clock/migrate), **SST-Auras** (wrapper parsing), **SST-Combat** (CLEU/timers), **SST-Hunter** (gated on class).  
Tests run on `PLAYER_ENTERING_WORLD` via deferred OnUpdate registration. Use `/ssttest` to manually trigger all groups.  
Enable via `## OptionalDeps: WoWUnit` — WoWUnit loads from CurseForge, installs to `_anniversary_/Interface/AddOns/WoWUnit/`.  
Load order not guaranteed on Classic/TBC ("should" not "must").

WoWUnit API: `WoWUnit('GroupName', 'EVENT')` creates a group, test functions defined as `function Group:testName()`. Assertions: `AreEqual`, `IsTrue`, `IsFalse`. Mocking: `Replace('globalFunc', mockFn)` / `ClearReplaces()`.

---

## Migration

MigrateDB() chain in Main.lua — handles v1→v54. Every case upgrades FROM that version. Factory reset: `/sst reset`.

---

## Boundaries

| Tier | Action |
|------|--------|
| **Always** | ns.* for state. Nil-guard ClassMods. Use wrappers. luacheck before commit. 644 perms on wine path. |
| **Ask first** | New setting (6 files). New event/file. DB version bump. Migration case changes. |
| **Never** | `<<` operator (Lua 5.1). Hardcode queryable spell IDs. Dependencies. Delete old migration cases. |

---

## Blizzard API verification

**TBC Anniversary 2.5.5 runs TBC mechanics, not Legion/Retail.** Haste is separate per domain — never assume unified (that happened in 6.0.2).

| How | What |
|-----|------|
| **Search** `Blizzard_APIDocumentationGenerated/` in wow-ui-source | Confirms C API exists |
| **Check** `Gethe/wow-ui-source` branch `classic_anniversary` | TBC Anniv source |
| **Cross-check** FrameXML & TOC files | Function is actually callable |
| **Never** use `live` branch | Retail, wrong for Classic |

| API | Domain |
|-----|--------|
| `GetMeleeHaste()` / `GetHaste()` / `CR_HASTE_MELEE` | Melee |
| `GetRangedHaste()` / `CR_HASTE_RANGED` | Ranged |
| `UnitSpellHaste()` / `CR_HASTE_SPELL` | Spell |

| Pitfall | Fix |
|---------|-----|
| `GetHaste()` = ranged | It's **melee** haste |
| Trusting wiki docs | Cross-check wow-ui-source |
| Not checking TOC | Function exists only if addon loads for that game type |
