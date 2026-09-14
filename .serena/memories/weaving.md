# Shaman Spell-Weaving Engine

## Core Calculation (`SuperSwingTimer_Weaving.lua`)
- Dynamic cast-by breakpoint indicators projected onto the MH swing bar.
- Calculates maximum safe cast window before next MH swing lands without clipping.
- Factors in live player cast time, current haste buffs, and latency via `GetNetStats()`.

## SoD Maelstrom Weapon Integration
- Tracks Maelstrom Weapon (`408505` / `MSW`) stacks.
- 20% cast time reduction per stack; instant cast at 5 stacks.
- Dynamic cast time updates live as stacks accumulate during swing.

## Visual Overlays (`SuperSwingTimer_ClassMods.lua`)
- Upper and lower triangle breakpoint markers positioned at safe cast-start threshold.
- Moving weave spark tracks active cast progress from start point toward projected impact.
- Dedicated overlay frame at `FrameLevel + 6` ensures weave visuals never clip behind bar textures.
- Color is Shaman blue when safe, bright red when clipped.

## Related Memories
- Main architecture map: `mem:core`
- Melee swing engine: `mem:swing_engine`
- Season of Discovery mechanics: `mem:sod_mechanics`
