# Shaman Spell-Weaving Engine

## Overview

Shaman spell-weaving allows Enhancement and hybrid Shamans to interleave hard-cast spells (primarily Lightning Bolt) between melee swings without delaying/clipping their main-hand swing.

## Timing Math & Breakpoint Calculation

1. **Effective Cast Time**:
   - Resolved dynamically via `GetSpellInfo(spellId)` for current spell cast duration (`liveCastTime`).
   - Spell haste buffs applied: Bloodlust / Heroism (30%), Berserking, Drums of Battle, and native haste rating.
   - Season of Discovery Maelstrom Weapon (`408505`): Each stack provides 20% reduction, reaching 0s (instant cast) at 5 stacks.
   - Instant cast procs (Nature's Swiftness, Elemental Mastery, Power Surge) return `0.0s`.
2. **Breakpoint Marker Fraction**:
   $$\text{markerFraction} = \frac{D_{swing} - (C_{effective} + \text{latency})}{D_{swing}}$$
   - As cast time shortens (e.g., higher haste or more Maelstrom stacks), the breakpoint marker dynamically shifts toward the right end of the bar in real time, widening the safe weave window.
3. **Fixed Cutoff Marker Icons**:
   - Top and bottom indicator icons (`ns.weaveTriangleTop`, `ns.weaveTriangleBottom`) remain anchored at `markerFraction * barWidth`.
   - The player must initiate the cast before the swing bar reaches these marker icons to weave safely without clipping.

## Cast Spark Overlay & Visual Feedback

- **Overlay Layering**: Renders on a dedicated frame at `FrameLevel + 6` directly overtop of the main bar (and off-hand bar if dual-wielding).
- **Active State Only**: Spark is visible **only while actively casting** (`isCasting == true`), moving smoothly from 0 to 1 across the bar based on `castProgress * barWidth`.
- **Color Differentiation**:
  - **Shaman Class Blue** (`#0070DE` / `{ r = 0.0, g = 0.44, b = 0.87 }`): Rendered when the cast was started *before* the swing passed the breakpoint (safe weave, zero clip).
  - **Bright Red** (`#FF2626` / `{ r = 1.0, g = 0.15, b = 0.15 }`): Rendered when the cast was started *after* the swing passed the breakpoint (clipped weave, delays swing).
