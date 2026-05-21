---
globs:
  - '**/*UI.lua'
  - '**/*Config.lua'
---

# UI & Visibility — Rules for bar/display files

## Bar creation
- Use `CreateFrame("StatusBar", ...)` for all swing bars
- Bar frames created once on init, not dynamically
- Each bar type: `mh`, `oh`, `ranged`, `enemy`, class helpers (SnD, shield block, etc.)

## Textures
- Bar texture selection in SavedVariables, applied to all status bars consistently
- Prefer built-in WoW texture paths unless packaged media added
- **Overlay textures:** `SetDrawLayer("OVERLAY", 0)` — never route through shared shaman code path
- **Spark:** color-preserving blend mode (`"BLEND"`), not additive — keeps manual spark tint accurate
- Config panel texture changes update preview bars live

## OnUpdate rendering
```mermaid
flowchart TD
    OU[OnUpdate fires] --> T[Get ns.GetCurrentTime()]
    T --> V{Bar visible?}
    V -->|No| RETURN[Early return - no work]
    V -->|Yes| F[Calculate fill percent]
    F --> S[SetStatusBarColor + SetValue]
    S --> SP[Update spark position]
    SP --> CHK{Class overlays active?}
    CHK -->|Yes| CO[Update class mods]
    CHK -->|No| DONE[Done]
    CO --> DONE
```

## Visibility rules
- MH/OH/enemy bars: **combat-only** by default (`InCombatLockdown()` + combat flag)
- Hidden/idle bars reset to empty state (no stale bars on combat entry)
- Ranged bar visible while auto-repeat active regardless of combat state
- Preview mode defers to `ns.ApplyVisibility()` on exit (not hard-zero)
- Class-color toggling preserves manual saved colors (doesn't overwrite)

## Bar text
- Class-colored MH/OH/ranged labels flip to **black on white outline** for contrast on bright fills
- Text uses `GameFontNormal` or game font template

## Config panel
- Labels-above-controls layout with full-row click targets
- Controls: checkbox (toggle), slider (numeric), UIDropDownMenu (texture/cycle), color swatch
- Section headers collapsible
- Hover tooltips for each config row
- `Reset Defaults` restores `ns.DB_DEFAULTS` through all 6 update paths

## Drag handling
- Hitboxes wide enough for easy mouse targeting
- Mouse-down starts drag, mouse-up ends
- Spark/overlays follow bar position on drag

## Quick Controls structure (Config.lua:1790–2417)
- Two-column layout: left "Visibility" toggles + right "Key Colors" swatches
- `AddQuickToggle(label, getValue, applyValue)` — checkbox row; DB key matches label (e.g., `showMH`, `showRogueEnergyTick`)
- `AddQuickColor(label, colorKey, opts)` — color swatch row; DB key is `colors.<colorKey>`
- Full DB key mapping: `references/config-panel.md`
- All toggle DB keys and default values: `references/db-migrations.md`

## MH/OH Bar Appearance section (Config.lua:2425–2867)
- 25 rows: width slider, height slider, hunter cast bar height, 2 texture pickers, 2 layer cycles, 3 spark sliders, 2 color buttons, alpha slider, glow mode, border color/size, **8 class helper sliders** (Rogue SnD Height, Rogue Energy Tick Width, Hunter Range Helper Width, Hunter Rapid Fire Height, Warrior Shield Block Height, Druid Power Shift Height, Druid Energy Tick Width, Rogue Adrenaline Rush Height)
- Class-specific sliders hidden for non-matching classes
- All DB keys: `references/config-panel.md`

## Shaman Weave Assist section (Config.lua:2669–2791)
- Hidden for non-Shaman classes
- 10 rows: weave spark textures, layers, sizes, alpha, spell icon size/gap/alpha
- Per-family toggles in "Weave Families" sub-section

## Texture browser categories
- All, Shapes(WeakAuras), SharedMedia, Blizzard, Platynator
- MH/OH and ranged use scrolling full-preview `barList` mode
- Spark and weave spark use square thumbnail `browser` mode

## Spark settings (critical for consistency)
- Default: 3px width, 15px height, alpha 1.0, `"OVERLAY"` layer, `"BLEND"` blend
- Spark color: `{r=1,g=1,b=1,a=1}` white — independent from bar colors
- `ApplySparkSettings()` handles texture, size, layer, alpha, color in one call
- For detailed constants: `references/core-timing.md`

---
**🔄 Sync hook:** If bar creation, texture handling, visibility, or config panel structure changes, update this file. Master protocol → `standards/code.md`
