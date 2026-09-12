# Class Modules & Visual Systems

## 1. Unified Multi-Class Resource / Power Bar

- **Frame**: Single global status bar `SuperSwingTimerPlayerPowerBar` (`ns.playerPowerBar`).
- **Standard Height**: 10px (`ns.POWER_BAR_HEIGHT = 10`), matching UI scale across all classes.
- **Supported Classes**:
  - **Warrior**: Rage (0-100). Backward compatibility alias: `ns.warriorRageBar = ns.playerPowerBar`.
  - **Rogue**: Energy (0-Max).
  - **Druid**: Dynamic shapeshifting: Cat (Energy), Bear (Rage), Caster/Forms (Mana `curr/max`).
  - **Paladin / Shaman / Hunter**: Mana (`curr/max`).
- **Execute Range Indicator (Warrior)**:
  - Icon texture (ID `5308`, Execute) attached to the power bar when target HP $\le 20\%$.
  - 4-edge border with animated red pulse glow.
  - Text label is strictly hidden to preserve clean aesthetics.

## 2. Target Debuff Duration Bars

- Rendered above the main-hand bar for active target debuffs:
  - **Warrior**: Sunder Armor, Rend, Thunder Clap, Demoralizing Shout, Shield Block (buff).
  - **Paladin**: Judgement of the Crusader, Seal of Vengeance/Corruption.
  - **Shaman**: Flame Shock.
  - **Druid**: Mangle, Rip, Rake.
  - **Hunter**: Serpent Sting, Freezing/Frost/Immolation/Explosive Traps, Concussive Shot, Wing Clip.
  - **Rogue**: Rupture, Expose Armor.
- **Icon Placement**: Always anchored to the outside left (`RIGHT`, `bar`, `LEFT`, -2, 0) with `SetTexCoord(0.07, 0.93, 0.07, 0.93)`.
- **Bar Alignment**: Debuff bars align 100% with the swing bar width ($X=0$ offset), preventing any icon or label overlap.
- **Dynamic Stacking**: Automatically restacked via `RestackDebuffBars(bars, referenceBar)`.

## 3. Buff & Cooldown Icons

- Available for all 6 physical classes: Paladin, Warrior, Shaman, Druid, Hunter, Rogue.
- **Typography & Positioning Standards**:
  - **Timer Text**: Centered strictly **above** the icon (`"BOTTOM", icon, "TOP", 0, 2`), centered horizontal justification, 12pt outline font. Icon face remains completely clear.
  - **Stack Count Text**: The **only** text overlaid on top of the icon face, anchored at `"BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1`, right-justified, 11pt outline font, white text.
  - **Stack Display Logic**: Displayed when `stacks > 1`, as well as `stacks == 1` for special stacking auras (Maelstrom Weapon `408505` / `MSW`, Paladin Reckoning).
  - **Child Cleanup**: When an aura expires or buff icons are hidden, both `icon.countText:Hide()` and `icon.durationText:SetText("")` are explicitly cleared.
- **Rampage & Aura Deduplication**:
  - `MergeTrackedSpells` merges duplicate entries by name/spellId into `altSpellIds`.
  - `seenAuras` table in update loops prevents duplicate icons when multiple spell ranks or SoD runes are registered.
