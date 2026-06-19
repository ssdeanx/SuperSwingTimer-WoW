# Super Swing Timer

Live WoW Classic Era and TBC Anniversary addon, thousands of users. 7 Lua files, single `ns` table, zero dependencies.
**v0.1.4** | **DB schema: v49** (`ns.DB_DEFAULTS.version`) | **CurseForge / GitHub Releases**

---

## Quality gates (MANDATORY)

This addon has thousands of users. There is no test framework — manual QA is the ONLY bug barrier. Every change must pass:

1. **luacheck: 0 warnings, 0 errors** before any commit.
2. **`luac -p` syntax check** on all 7 files.
3. **Manual in-game QA** on the correct client (Classic Era or TBC Anniversary):
   - Enter combat → bars appear with correct weapon speed
   - Swing lands → timer resets (watch CLEU SWING_DAMAGE/SWING_MISSED)
   - Class overlays appear for the current class only
   - Config panel toggles visibility correctly
   - `/sst reset` restores defaults without errors
4. **Dual-client awareness:** TBC Anniversary has different spell/aura return slots than Classic Era. Changes to wrappers (`ns.GetSpellInfo`, `ns.GetUnitCastingSpellInfo`) must not break the other client.

5. **CLEU payload difference:** Classic Era `COMBAT_LOG_EVENT` sends numeric spell IDs for `SWING_DAMAGE`, `SWING_MISSED`, and `SPELL_CAST_SUCCESS`. TBC Anniversary sends localized spell names (strings) instead. All swing-affecting lookup tables (`RESET_SWING_SPELLS`, `NO_RESET_SWING_SPELLS`, `PAUSE_SWING_SPELLS`, `RESET_RANGED_SWING_SPELLS`, plus NMA sets for Heroic Strike, Cleave, Maul, Raptor Strike, Paladin Judgement) populate **both** key types at init time via `ns.GetSpellInfo(id)` — never assume only numeric IDs will match. When adding a new lookup table that gates swing behavior, always register both key types or document why it's single-key only.
6. **CHANGELOG.md updated** and TOC version bumped for any release-worthy change.

---

## Commands

```bash
# Syntax check (luac from Lua 5.1)
luac -p SuperSwingTimer.lua SuperSwingTimer_Constants.lua SuperSwingTimer_State.lua SuperSwingTimer_Weaving.lua SuperSwingTimer_UI.lua SuperSwingTimer_ClassMods.lua SuperSwingTimer_Config.lua

# Lint (adjust path to your luacheck install)
"C:\Users\ssdsk\luacheck.exe" SuperSwingTimer.lua SuperSwingTimer_Constants.lua SuperSwingTimer_State.lua SuperSwingTimer_Weaving.lua SuperSwingTimer_UI.lua SuperSwingTimer_ClassMods.lua SuperSwingTimer_Config.lua
```

### In-game

| Action | Command |
|--------|---------|
| Open config panel | `/sst`, `/super`, `/superswingtimer` |
| Factory reset | `/sst reset` |
| Help | `/sst help` |
| Legacy alias | `/swang` |

---

## DB schema & migrations (USER DATA)

**v49** — `ns.SuperSwingTimerDB` is a SavedVariables table. Every user who upgrades carries their config forward through `MigrateDB()` in `SuperSwingTimer.lua`.

- Every `case` in `MigrateDB()` must handle upgrading FROM that version TO v49.
- Adding a new default alone is NOT enough — old users who install the update mid-patch will have nil values for new keys. Always add a migration case.
- **Never remove old migration cases.** Users skip versions. The chain must work from any v1..v48 → current.
- Breaking a migration corrupts user settings irreversibly (no backup). Test `/sst reset` after any migration change to confirm.
- Factory reset (`/sst reset`) calls `ResetConfigDefaults()` which wipes to `ns.DB_DEFAULTS`.

---

## Conventions

### ns.* namespace

All public functions and state on the shared `ns` table. No globals. No file-level `function foo()`.

```lua
-- ✓ correct
ns.StartSwing = function(slot) ... end
local function helper() ... end  -- private

-- ✗ wrong — creates a global, pollutes namespace, breaks other addons
function StartSwing(slot) ... end
```

### Clock domain

Single clock source. `GetTimePreciseSec()` via `ns.GetAlignedTime()`. `GetTime()` is fallback-only.

```lua
-- ✓ correct
local now = ns.GetAlignedTime()
ns.timers.mh.endTime = now + duration

-- ✗ wrong — GetTime() drift causes visible timer desync for users
local now = GetTime()
```

Bare `GetTime()` anywhere outside `GetAlignedTime()`'s nil fallback is a correctness bug. Fix on sight.

### Nil-guard dynamic calls

ClassMods registers functions at init that don't exist for most classes. Missing guard = LUA ERROR for that class.

```lua
-- ✓ correct
if ns.UpdateHunterRangeHelperVisual then
    ns.UpdateHunterRangeHelperVisual()
end

-- ✗ wrong — errors on non-Hunter classes
ns.UpdateHunterRangeHelperVisual()
```

### Blizzard API wrappers

Use Classic-safe wrappers, not raw Blizzard APIs. Classic Era and Anniversary payloads differ from Retail:

| Raw API | Wrapper | Reason |
|---------|---------|--------|
| `GetSpellInfo(id)` | `ns.GetSpellInfo(id)` | Different return slot counts per client |
| `UnitCastingInfo(unit)` | `ns.GetUnitCastingSpellInfo(unit)` | Classic-safe return types |
| `UnitChannelInfo(unit)` | `ns.GetUnitCastingSpellInfo(unit)` | Same wrapper covers both |
| `CombatLogGetCurrentEventInfo()` | Wrap with explicit arg checks | CLEU payloads differ between clients |
| `GetTime()` | `ns.GetAlignedTime()` | Clock domain — single source |
| `UnitAura(unit, index)` / `UnitBuff` / `UnitDebuff` | Check client branch payloads first | Return slot counts differ per client |

### New settings: 6-file protocol

Every setting touches exactly 6 files in this order:
`ns.DB_DEFAULTS` (Constants) → migration case in `MigrateDB()` (SuperSwingTimer.lua) → Apply* function (UI.lua) → config control (Config.lua) → README.md → TOC version

Example: `barHeight` → add `barHeight = 15` to `ns.DB_DEFAULTS`, a `case "barHeight"` in `MigrateDB()`, `ns.ApplyBarHeight()` in UI.lua, a slider in Config.lua, a row in README.md tables, bump TOC version.

---

## Boundaries

| Tier | Action |
|------|--------|
| **Always** | ns.* for cross-file state. Nil-guard ClassMods. Wrap Blizzard APIs. Run luacheck before any commit. |
| **Ask first** | Adding a setting (6 files). New event registration. New Lua file. DB schema version bump. Migration case changes. |
| **Never** | `--[[ @debugger ]]` as type suppression. Hardcode queryable spell IDs. Dependencies. Secrets. Commit without luacheck. Delete old migration cases. |

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
| File exports | `grep "ns\." <filename>` — every public symbol is ns.* |
| Render order | Read `ns.OnUpdate()` in `SuperSwingTimer_UI.lua` — call order = render order |
| Event wiring | Read the `OnEvent` elseif chain in `SuperSwingTimer.lua` |
| Timer/shared state | `grep "^ns\." SuperSwingTimer_State.lua` for timers; `grep "ns\." SuperSwingTimer.lua` for combat flags |
| Declared globals | Read `.luacheckrc` |
| Blizzard API payloads | Search `classic_anniversary` or `classic` branch (not `live`/Retail) |

---

## Architecture

- **7 files, strict dependency order:** Constants → State/Weaving → UI → ClassMods → Config
- **Clock:** `GetTimePreciseSec()` via `ns.GetAlignedTime()` — never bare `GetTime()`
- **Timers:** `ns.timers.mh/oh/ranged/enemy` with `{ state, startTime, endTime, duration, speed, holdEnd }`
- **Event dispatch:** SuperSwingTimer.lua owns the `OnEvent` handler; the `elseif` chain IS the event map
- **CLEU** drives all timer starts. `SWING_DAMAGE`/`SWING_MISSED` → `StartSwing`. Extra attacks, Slam, and haste changes use short-lived flags to suppress/adjust resets.
- **Render:** `OnUpdate()` in UI.lua — function call order = render order. Class overlays are nil-guarded.
- ✅ [WIRING.md](./docs/WIRING.md) for full event, ns.* surface, and shared-state reference.

---

## External references

### Primary — TBC Anniversary (use first)

- [Gethe/wow-ui-source — `classic_anniversary` branch](https://github.com/Gethe/wow-ui-source/tree/classic_anniversary)
- [Blizzard_APIDocumentationGenerated (Lua API stubs)](https://github.com/Gethe/wow-ui-source/tree/classic_anniversary/Interface/AddOns/Blizzard_APIDocumentationGenerated)
- [FrameXML](https://github.com/Gethe/wow-ui-source/tree/classic_anniversary/Interface/FrameXML)

### Also relevant — Classic Era

- [Gethe/wow-ui-source — `classic` branch](https://github.com/Gethe/wow-ui-source/tree/classic)
- [Blizzard_APIDocumentationGenerated (Lua API stubs)](https://github.com/Gethe/wow-ui-source/tree/classic/Interface/AddOns/Blizzard_APIDocumentationGenerated)
- [FrameXML](https://github.com/Gethe/wow-ui-source/tree/classic/Interface/FrameXML)
- [All branches](https://github.com/Gethe/wow-ui-source/branches)
