# Super Swing Timer

Live WoW Classic Era and TBC Anniversary addon, thousands of users. 7 Lua files, single `ns` table, zero dependencies.
**v0.1.5** | **DB schema: v50** (`ns.DB_DEFAULTS.version`) | **CurseForge / GitHub Releases**

---

## Quality gates (MANDATORY)

No test framework — manual QA is the ONLY bug barrier. Every change must pass:

1. **luacheck: 0 warnings, 0 errors** before any commit.
2. **`luac -p` syntax check** on all 7 files.
3. **Manual in-game QA** on the correct client:
   - Enter combat → bars appear with correct weapon speed
   - Swing lands → timer resets (watch CLEU SWING_DAMAGE/SWING_MISSED)
   - Class overlays appear for current class only
   - Config panel toggles visibility correctly
   - `/sst reset` restores defaults without errors
4. **Dual-client awareness:** TBC Anniversary has different spell/aura return slots than Classic Era. Wrapper changes must not break the other client.
5. **CLEU payloads differ:** Classic sends numeric spell IDs, TBC Anniversary sends localized strings. All swing-affecting lookup tables populate **both** key types at init via `ns.GetSpellInfo(id)`.
6. **CHANGELOG.md** updated and TOC version bumped for any release-worthy change.

---

## Commands

```bash
luac -p SuperSwingTimer.lua SuperSwingTimer_Constants.lua SuperSwingTimer_State.lua SuperSwingTimer_Weaving.lua SuperSwingTimer_UI.lua SuperSwingTimer_ClassMods.lua SuperSwingTimer_Config.lua
"C:\Users\ssdsk\luacheck.exe" SuperSwingTimer.lua SuperSwingTimer_Constants.lua SuperSwingTimer_State.lua SuperSwingTimer_Weaving.lua SuperSwingTimer_UI.lua SuperSwingTimer_ClassMods.lua SuperSwingTimer_Config.lua
```

### In-game

| Action | Command |
|--------|---------|
| Open config | `/sst`, `/super`, `/superswingtimer` |
| Factory reset | `/sst reset` |
| Help | `/sst help` |
| Legacy alias | `/swang` |

---

## DB schema & migrations (USER DATA)

**v50** — `ns.SuperSwingTimerDB` is a SavedVariables table, migrated via `MigrateDB()` in `SuperSwingTimer.lua`.

- Every `case` in `MigrateDB()` must handle upgrading FROM that version TO v50.
- **Never remove old migration cases.** Users skip versions — the chain must work from any v1..v49 → v50.
- Adding a new default alone is NOT enough — old users have nil for new keys. Always add a migration case.
- Breaking a migration corrupts user settings irreversibly (no backup).
- Factory reset (`/sst reset`) calls `ResetConfigDefaults()` which wipes to `ns.DB_DEFAULTS`.

---

## Conventions

### ns.* namespace & nil-guards

No globals. All public functions on `ns`. Nil-guard ClassMods dynamic calls:

```lua
-- ✓ correct
if ns.UpdateHunterRangeHelperVisual then ns.UpdateHunterRangeHelperVisual() end

-- ✗ wrong — LUA ERROR on non-Hunter classes
ns.UpdateHunterRangeHelperVisual()
```

### Clock domain

Single source: `GetTimePreciseSec()` via `ns.GetAlignedTime()`. `GetTime()` is fallback-only. Each file has a local `now()` bridge:

```lua
-- ✓ correct
local now = ns.GetAlignedTime()
ns.timers.mh.endTime = now + duration

-- ✗ wrong — bare GetTime() causes visible timer desync
local now = GetTime()
```

Bare `GetTime()` outside `GetAlignedTime()`'s nil fallback is a correctness bug. Fix on sight.

### Blizzard API wrappers

Use Classic-safe wrappers, not raw APIs. Payloads differ per client:

| Raw API | Wrapper | Reason |
|---------|---------|--------|
| `GetSpellInfo(id)` | `ns.GetSpellInfo(id)` | Different return slot counts per client |
| `UnitCastingInfo(unit)` | `ns.GetUnitCastingSpellInfo(unit)` | Classic-safe return types |
| `UnitChannelInfo(unit)` | `ns.GetUnitCastingSpellInfo(unit)` | Same wrapper covers both |
| `CombatLogGetCurrentEventInfo()` | Wrap with explicit arg checks | CLEU payloads differ per client |
| `GetTime()` | `ns.GetAlignedTime()` | Clock domain — single source |
| `UnitAura(unit, index)` / `UnitBuff` / `UnitDebuff` | Check client branch payloads first | Return slot counts differ per client |

### New settings: 6-file protocol

Every setting touches exactly: `ns.DB_DEFAULTS` (Constants) → migration case in `MigrateDB()` (SuperSwingTimer.lua) → Apply* function (UI.lua) → config control (Config.lua) → README.md → TOC version.

---

## Boundaries

| Tier | Action |
|------|--------|
| **Always** | ns.* for cross-file state. Nil-guard ClassMods. Wrap Blizzard APIs. Run luacheck before any commit. |
| **Ask first** | Adding a setting (6 files). New event registration. New Lua file. DB schema version bump. Migration case changes. |
| **Never** | `--[[ @debugger ]]` type suppression. Hardcode queryable spell IDs. Dependencies. Secrets. Commit without luacheck. Delete old migration cases. |

---

## Codebase navigation

### File map

| File | What you'd change it for |
|------|-------------------------|
| `SuperSwingTimer.lua` | Event routing, slash commands, init, migration, combat/movement flags |
| `SuperSwingTimer_Constants.lua` | DB defaults, spell catalog, wrapper helpers, `ns.GetAlignedTime()`, `ns.GetSpellInfo()` |
| `SuperSwingTimer_State.lua` | Timer structs, CLEU/spellcast handlers, speed sync, `ns.timers.*` |
| `SuperSwingTimer_Weaving.lua` | Shaman weave catalog + breakpoint math (SHAMAN only) |
| `SuperSwingTimer_UI.lua` | Bar frames, `ns.OnUpdate()` render, Apply* styling, class overlays |
| `SuperSwingTimer_ClassMods.lua` | 6 Setup* functions — class-specific overlay registration |
| `SuperSwingTimer_Config.lua` | Config panel, swatches, sliders, texture browser |

### Discovery

| What you need | How |
|---------------|-----|
| File exports | `grep "ns\." <filename>` |
| Render order | Read `ns.OnUpdate()` in UI.lua — call order = render order |
| Event wiring | Read the `OnEvent` elseif chain in SuperSwingTimer.lua |
| Timer/shared state | `grep "^ns\." State.lua` for timers; `grep "ns\." SuperSwingTimer.lua` for combat flags |
| Declared globals | Read `.luacheckrc` |
| Blizzard API payloads | Search `classic_anniversary` or `classic` wow-ui-source branches (not `live`) |
| C API existence | See Blizzard API verification section |

### Architecture

- **7 files, strict dependency order:** Constants → State/Weaving → UI → ClassMods → Config
- **Clock:** `GetTimePreciseSec()` via `ns.GetAlignedTime()` — never bare `GetTime()`
- **Timers:** `ns.timers.mh/oh/ranged/enemy` with `{ state, startTime, endTime, duration, speed, holdEnd }`
- **Event dispatch:** SuperSwingTimer.lua owns `OnEvent`; the `elseif` chain IS the event map
- **CLEU** drives all timer starts. `SWING_DAMAGE`/`SWING_MISSED` → `StartSwing`. Extra attacks, Slam, haste changes use short-lived flags.
- **Render:** `OnUpdate()` in UI.lua — function call order = render order. Class overlays nil-guarded.
- ✅ [WIRING.md](./docs/WIRING.md) for full event, ns.* surface, and shared-state reference.

---

## Blizzard API verification (CRITICAL)

**The TBC Anniversary client (2.5.5) runs TBC game mechanics, NOT Legion/Retail.** Haste stats are separate:

| API | Domain |
|-----|--------|
| `GetMeleeHaste()` | Melee haste |
| `GetRangedHaste()` | Ranged haste |
| `GetHaste()` | Melee haste (paired with `CR_HASTE_MELEE` in PaperDollFrame) |
| `UnitSpellHaste()` | Spell haste |
| `GetCombatRating(CR_HASTE_MELEE/RANGED/SPELL)` | Rating pool |

**Never assume unified haste (that happened in 6.0.2).** Always verify function existence per client.

### How to verify a C API function exists

1. **Search `Blizzard_APIDocumentationGenerated/`** in wow-ui-source for the function — confirms C API exists on that branch.
2. **Search FrameXML/Blizzard addon Lua files** for its usage — confirms it's callable.
3. **Search `*.toc` files** to confirm the containing addon is loaded for that client.

| Branch | Client | Repository |
|--------|--------|------------|
| `classic_anniversary` | TBC Anniversary (2.5.5) | `Gethe/wow-ui-source` branch `classic_anniversary` |
| `classic` | Classic Era (1.15.x) | `Gethe/wow-ui-source` branch `classic` |
| `live` | Retail | Do NOT use for Classic/TBC answers |

### Key client files

| File | classic_anniversary (TBC) | classic (Era) |
|------|--------------------------|---------------|
| PaperDollFrame | `Classic/` or `Vanilla/` | `Classic/` or `Vanilla/` |
| SpellBookFrame | `Classic/SpellBookFrame.lua` | `Classic/SpellBookFrame.lua` |
| CastingBarFrame | `Classic/CastingBarFrame.lua` | `Classic/CastingBarFrame.lua` |
| InspectUI | `TBC/Blizzard_InspectUI.lua` | `Vanilla/Blizzard_InspectUI.lua` |

### Common pitfalls

| Mistake | Correction |
|---------|------------|
| `GetHaste()` = ranged haste | It's **melee** haste. Use `GetRangedHaste()` or `GetCombatRatingBonus(CR_HASTE_RANGED)`. |
| Using `live` branch for Classic/TBC | Always use `classic_anniversary` or `classic` branch. |
| Trusting wiki docs for Anniversary APIs | Cross-check against wow-ui-source source code. |
| Assuming unified haste (post-6.0.2) | TBC Anniversary has separate melee/ranged/spell haste. |
| Not checking TOC files | A function exists only if its addon's TOC loads for that `AllowLoadGameType`. |

### Confirmed function existence

| Function | Client | Evidence |
|----------|--------|----------|
| `UnitRangedDamage("player")` | classic_anniversary | Returns speed, minDamage, maxDamage, posBuff, negBuff, percent — speed at index 1 (warcraft.wiki.gg) |
| `C_Spell.GetSpellCooldown(75)` | classic_anniversary | Used in CooldownViewer.lua |
| `GetTimePreciseSec()` | classic_anniversary | Used in Blizzard_Console.lua |
| `GetTimePreciseSec()` + `GetTime()` bridge | classic_anniversary | `ns.GetAlignedTime()` in Constants.lua is sound |

---

## External references

- [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/branches) — `classic_anniversary` (TBC Anniversary), `classic` (Classic Era), `live` (Retail, **don't use**)
- [Blizzard_APIDocumentationGenerated](https://github.com/Gethe/wow-ui-source/tree/classic_anniversary/Interface/AddOns/Blizzard_APIDocumentationGenerated) — Lua API stubs per branch
- [warcraft.wiki.gg Classic API](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API/Classic) — authoritative Classic API docs
- [TOC: Blizzard_UIPanels_Game_TBC](https://github.com/Gethe/wow-ui-source/blob/classic_anniversary/Interface/AddOns/Blizzard_UIPanels_Game/Blizzard_UIPanels_Game_TBC.toc) — TBC Anniversary panel loading
