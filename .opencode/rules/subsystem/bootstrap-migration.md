---
globs:
  - '**/SuperSwingTimer.lua'
---

# Bootstrap & Migration — Rules for the loader file

## This file ONLY handles
- Addon load order (`## LoadOn`, `## LoadWith` from TOC)
- SavedVariables migration (backward-compatible DB upgrades)
- Slash command registration (`SLASH_SUPERSWINGTIMER1` etc.)
- Event registration (`SuperSwingTimer_EventFrame`)
- Namespace initialization (`ns = SuperSwingTimer`)
- Calling `Setup` functions on all other files

## MUST
- **No feature logic** in this file — no bar updates, no timer math, no class logic
- **Only append** migration entries, never modify shipped versions (v30-v34 exist)
- Migration pattern: version check → transform → save → set `ns.db.version`
- Slash commands route to `ns.Config.Toggle()` or `ns.Config.OpenPanel()`

## Migration pattern
```lua
if ns.db.version < X then
    -- upgrade ns.db.defaults keys that changed
    -- merge old keys into new structure
    -- set ns.db.version = X
end
```

## Event registration pattern
```lua
ns.eventFrame = CreateFrame("Frame")
ns.eventFrame:RegisterEvent("PLAYER_LOGIN")
ns.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
ns.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
ns.eventFrame:SetScript("OnEvent", function(_, event, ...)
    ns.HandleEvent(event, ...)
end)
```

## Migration version history
- Current version: **43** (as of v0.0.8)
- Full changelog with every version's key changes: `references/db-migrations.md`
- Notable versions:
  - **v22**: Enforced black bar defaults + white spark + `useClassColors=false`
  - **v25**: Enemy bar defaults + spark 3px
  - **v34**: Paladin seal twist → transparent red `{1,0,0,0.35}`
  - **v39**: Phase 1 quick wins (swing flash, GCD ticker, rage dim, energy countdown)
  - **v40**: Phase 2 class helpers (Rapid Fire, Flurry, AR, Omen, Windfury ICD, Shield Block, Ravage)
  - **v42**: Independent hunterCastBarHeight
  - **v43**: Per-class helper bar height/width sliders (SnD, energy tick, Shield Block, Range Helper, Rapid Fire, Power Shift, Druid energy tick, Adrenaline Rush)

## DB defaults reference
- All `ns.DB_DEFAULTS` keys, types, and default values: `references/db-migrations.md`
- All config DB keys broken down by toggle/color/slider/texture: `references/config-panel.md`

## Config panel entry points
- `ns.InitConfig()` (Config.lua:3182) — lazy-init the panel
- `ns.ToggleConfig()` (Config.lua:3189) — toggle show/hide, refreshes all values
- `ns.ResetConfigDefaults()` (Config.lua:3335) — full DB + visual reset
- Calls `ShowBarPreview()` on panel open, `HideBarPreview()` via `ApplyVisibility()` on close

---
**🔄 Sync hook:** If migration version bumps, slash commands change, or event registration patterns change, update this file. Master protocol → `standards/code.md`
