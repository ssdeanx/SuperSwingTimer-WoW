---
description: Visual layout, typography, and anchoring rules for SuperSwingTimer UI components
globs:
  - "SuperSwingTimer_ClassMods.lua"
  - "SuperSwingTimer_UI.lua"
  - "SuperSwingTimer_Weaving.lua"
alwaysApply: false
---

# UI & Typography Standards

1. **Buff & Cooldown Icon Typography**:
   - `durationText` must be anchored centered directly **above** the icon: `icon.durationText:SetPoint("BOTTOM", icon, "TOP", 0, 2)` with `SetJustifyH("CENTER")`.
   - The icon face itself must remain completely clear of timer text.
   - `countText` (stacks) is the only text rendered on the icon face, anchored at `"BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1` with `SetJustifyH("RIGHT")`, 11pt outline font, white color.
   - Stacks display for `stacks > 1`, plus `stacks == 1` for Maelstrom Weapon (`408505` / `MSW`) and Paladin Reckoning.

2. **Debuff Duration Bar Alignment**:
   - Icons must be placed outside to the left of the bar: `spellIcon:SetPoint("RIGHT", bar, "LEFT", -2, 0)` with `SetTexCoord(0.07, 0.93, 0.07, 0.93)`.
   - Debuff bar frame itself aligns directly with the swing bar at $X=0$, without bar offset.

3. **Unified Power Bar**:
   - Standard height is 10px (`ns.POWER_BAR_HEIGHT = 10`).
   - Sits below off-hand (or main-hand) melee bar or Auto Shot cast bar.

4. **Weave Spark Overlay**:
   - Weave spark overlay must live in a dedicated overlay frame at `FrameLevel + 6`.
   - Active only while casting (`isCasting == true`).
   - Color is Shaman class color when safe, bright red when clipped.
