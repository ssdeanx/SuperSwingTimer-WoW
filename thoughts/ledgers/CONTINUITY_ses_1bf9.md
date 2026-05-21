---
session: ses_1bf9
updated: 2026-05-19T13:23:34.873Z
---

# Session Summary

## Goal
Exhaustively document every SetPoint, anchor, and positioning call for the hunter ranged bar, melee bars (MH/OH), and hunter cast bar across all four SuperSwingTimer source files so the layout/anchoring architecture can be understood for modification.

## Constraints & Preferences
- Preserve exact file paths, line numbers, and function/variable names in all output.
- Focus only on the four listed files (`SuperSwingTimer_UI.lua`, `SuperSwingTimer_ClassMods.lua`, `SuperSwingTimer_State.lua`, `SuperSwingTimer_Constants.lua`).
- Terse bullets over paragraphs; every anchor/SetPoint call must be accounted.

## Progress
### Done
- [x] **Constant definitions located** (`SuperSwingTimer_Constants.lua`):
  - Line 70: `ns.BAR_WIDTH = 240`
  - Line 71: `ns.BAR_HEIGHT = 15`
  - Line 72: `ns.HUNTER_CAST_BAR_HEIGHT = 10`
  - Line 73: `ns.HUNTER_CAST_BAR_GAP = 2`
  - Line 74: `ns.HUNTER_RANGE_HELPER_WIDTH = 7`
  - Line 75: `ns.CAST_WINDOW = 0.5`
  - Line 458-459: DB defaults `barWidth = 240`, `barHeight = 15`
  - Lines 1008-1022: `HUNTER_RANGE_HELPER_WIDTH` helper in range-helper width resolution
- [x] **Bar creation functions found** (`SuperSwingTimer_UI.lua`):
  - Line 465: `CreateBar(frameName, width, height)` – generic factory, `SetPoint("CENTER", UIParent, "CENTER", 0, -100)` at line 468
  - Line 589: `CreateRangedBar()` – calls `CreateBar("SuperSwingTimerRangedBar")` (no width/height overrides → default 240×15)
  - Line 629: `CreateHunterCastBar()` – calls `CreateBar("SuperSwingTimerHunterCastBar", nil, ns.HUNTER_CAST_BAR_HEIGHT or 10)` → height forced to 10, width falls back to BAR_WIDTH (240)
  - Line 684: `CreateMHBar()` – calls `CreateBar("SuperSwingTimerMHBar")`
  - Line 699-705: `CreateOHBar()` – calls `CreateBar("SuperSwingTimerOHBar", offHandWidth, offHandHeight)` where offHandHeight is computed via `GetOffHandBarHeight(height)` (line 1353)
- [x] **Hunter cast bar anchoring** (`SuperSwingTimer_UI.lua`):
  - Lines 638-639: `f:SetPoint("TOPLEFT", rangedBar, "BOTTOMLEFT", 0, -(ns.HUNTER_CAST_BAR_GAP or 2))` and `f:SetPoint("TOPRIGHT", rangedBar, "BOTTOMRIGHT", 0, -(ns.HUNTER_CAST_BAR_GAP or 2))` — hunter cast bar sits **below** the ranged bar with a gap of 2 (HUNTER_CAST_BAR_GAP, negative offset, meaning down)
- [x] **Hunter melee bar anchoring via `UpdateHunterMeleeBarAnchor`** (`SuperSwingTimer_UI.lua`:
  - Lines 995-1016: Function that re-anchors `ns.mhBar`:
    - Line 1000: Default `anchorBar = ns.rangedBar`
    - Line 1005: If hunter cast bar is visible, `anchorBar = ns.hunterCastBar`
    - Lines 1013-1014: `ns.mhBar:SetPoint("TOPLEFT", anchorBar, "BOTTOMLEFT", 0, -2)` and `ns.mhBar:SetPoint("TOPRIGHT", anchorBar, "BOTTOMRIGHT", 0, -2)` — MH sits **below** whichever anchor bar (ranged bar or hunter cast bar) is lowest
- [x] **OH bar anchoring to MH** (`SuperSwingTimer_UI.lua`):
  - Lines 722-723: Inside `CreateOHBar`: `f:SetPoint("TOPLEFT", mh, "BOTTOMLEFT", 0, -2)` and `f:SetPoint("TOPRIGHT", mh, "BOTTOMRIGHT", 0, -2)` — OH sits **below** MH with a 2px gap
  - Lines 1369-1371: In `ApplyBarSize` for re-anchoring: same two-point anchoring
- [x] **Rogue Slice and Dice bar** (`SuperSwingTimer_UI.lua`):
  - Lines 1377-1379: `rogueSliceAndDiceBar:SetPoint("BOTTOMLEFT", mhBar, "TOPLEFT", 0, 2)` and `rogueSliceAndDiceBar:SetPoint("BOTTOMRIGHT", mhBar, "TOPRIGHT", 0, 2)` — sits **above** MH with 2px gap (positive 2 offset means upward)
- [x] **Enemy bar** (`SuperSwingTimer_UI.lua`):
  - Line 571: `CreateBar("SuperSwingTimerEnemyBar")` — default size, default center anchor
- [x] **Hunter range helper bar** (`SuperSwingTimer_ClassMods.lua`):
  - Line 775: `local HUNTER_RANGE_HELPER_GAP = 3`
  - Lines 893-906: `GetHunterRangeHelperAnchors()` — determines topAnchor = `ns.rangedBar`, bottomAnchor extends through `ns.hunterCastBar` (if visible) then `ns.mhBar` (if visible)
  - Lines 936-937: `helperBar:SetPoint("TOPRIGHT", topAnchor, "TOPLEFT", -HUNTER_RANGE_HELPER_GAP, 0)` and `helperBar:SetPoint("BOTTOMRIGHT", bottomAnchor, "BOTTOMLEFT", -HUNTER_RANGE_HELPER_GAP, 0)` — helper bar anchored **to the left** of the entire ranged/cast/melee stack with 3px gap
- [x] **Rogue energy tick bar** (`SuperSwingTimer_ClassMods.lua`):
  - Line 1103: `local ROGUE_ENERGY_STACK_GAP = 3`
  - Line 1376: `tickBar:SetPoint("TOPRIGHT", mhBar, "TOPLEFT", -ROGUE_ENERGY_STACK_GAP, 0)` — attached **left** of MH bar
- [x] **Rogue Slice and Dice bar (ClassMods version)** (`SuperSwingTimer_ClassMods.lua`):
  - Line 1099: `local ROGUE_SLICE_AND_DICE_BAR_GAP = 2`
  - Lines 1454-1455: `sndBar:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, ROGUE_SLICE_AND_DICE_BAR_GAP)` and `sndBar:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", 0, ROGUE_SLICE_AND_DICE_BAR_GAP)` — **above** its anchor frame
- [x] **Bar initialization order** (`SuperSwingTimer_UI.lua`):
  - Line 2086: `CreateEnemyBar()`
  - Lines 2090-2093: If cfg.ranged → `CreateRangedBar()` then if HUNTER → `CreateHunterCastBar()`
  - Lines 2099-2108: If cfg.melee → `CreateMHBar()`; for hunter: `UpdateHunterMeleeBarAnchor(false, true)`, `:SetMovable(false)`, `:EnableMouse(false)`
  - Lines 2111-2116: If cfg.melee and cfg.dualWield → `CreateOHBar()`
  - Line 2122: `ns.OnBarsCreated()` — triggers class-specific setup
- [x] **Timer state interaction** (`SuperSwingTimer_State.lua`):
  - Line 31: Four independent timers: `mh`, `oh`, `ranged`, `enemy`
  - Lines 39-44: Initialization structs with `state = "idle"`
  - Line 42: `ranged = { state = "idle", lastSwing = 0, duration = 0, speed = 0, nextSpeedCheckAt = 0 }`
  - Lines 561-614: `StartSwing(slot, _, startTime)` — slot can be `"mh"`, `"oh"`, `"ranged"`; ranged uses `UnitRangedDamage()` / `GetAutoShotCooldown()`; melee uses `UnitAttackSpeed()`
  - Lines 468-472: `ResetTimer("ranged")` during OnPlayerEnteringWorld also calls `ns.UpdateOHBar()` if it exists
  - Lines 518-556: Ranged timer sync/rescale logic calling `ns.RescaleTimer("ranged", value)`
- [x] **`CreateOverlayFrame`** (`SuperSwingTimer_UI.lua`):
  - Lines 212-218: `SetAllPoints(parent)`, strata/level inheritance

### In Progress
- [ ] Full audit of all spark overlay, latency overlay, cast threshold marker, and label sub-frame SetPoint calls still in progress (lines 184, 545, 548, 557, 602-603, 614-615, 655-656, 665-666, 770-771, 861-862 also exist in `SuperSwingTimer_UI.lua`) — these are relative to the bar's overlay frame, not cross-bar anchors.

### Blocked
- (none)

## Key Decisions
- **Anchor-on-bottom-edge pattern**: All bar stacking (cast bar below ranged, MH below cast bar, OH below MH) uses the same two-point TOPLEFT/TOPRIGHT to BOTTOMLEFT/BOTTOMRIGHT pattern with a small positive vertical gap constant (2px).
- **Hunter melee bar is not independently movable**: When `cfg.ranged` is enabled, `ns.mhBar:SetMovable(false)` and `:EnableMouse(false)` — it is positioned programmatically relative to the ranged/cast bar stack.
- **Hunter range helper bar attaches to the left edge** of the entire vertical stack (top anchor = ranged bar, bottom anchor extends through cast bar → MH bar) so it always spans full stack height.
- **`HUNTER_CAST_BAR_GAP` is used negatively** in `SetPoint` offset: `0, -(ns.HUNTER_CAST_BAR_GAP or 2)` = the cast bar is placed below the ranged bar by gap pixels.

## Next Steps
1. Review the spark/latency/threshold marker sub-frame positioning (lines 770-771, 861-862, 184, 545, 602-603, 614-615, 655-656) if those details are needed for a complete layout picture.
2. Check `ApplyBarSize` (line 1340) to understand how size changes propagate through the anchor chain.
3. Verify the `GetAutoShotCooldown()` interaction in `StartSwing("ranged")` to understand ranged swing timing vs. cast bar animation.

## Critical Context
- **Visual stacking order (top to bottom)**:
  1. Rogue Slice & Dice bar (above MH, gap 2)
  2. Rogue Energy Tick bar (left of MH, vertical stack gap 3)
  3. Hunter Range Helper bar (left of full ranged+cast+melee stack, gap 3)
  4. Enemy bar (independent, center-anchored)
  5. **Ranged bar** (default 240×15, center-anchored by CreateBar)
  6. **Hunter cast bar** (height 10, below ranged bar, gap 2 using HUNTER_CAST_BAR_GAP)
  7. **MH bar** (default 240×15, below hunter cast bar if visible, otherwise below ranged bar, gap 2)
  8. **OH bar** (below MH bar, gap 2)
- **Anchor constants used directly**:
  - `(ns.HUNTER_CAST_BAR_GAP or 2)` — from `SuperSwingTimer_Constants.lua` line 73
  - `-2` hardcoded (MH→OH gap, MH→anchor gap)
  - `2` hardcoded (Rogue Slice & Dice → MH gap, positive for upward)
  - `HUNTER_RANGE_HELPER_GAP = 3` — ClassMods line 775, used as `-3` (leftward)
  - `ROGUE_ENERGY_STACK_GAP = 3` — used as `-3` (leftward)
  - `ROGUE_SLICE_AND_DICE_BAR_GAP = 2` — used as `+2` (upward)
- **No gap constant exists between MH and OH** — the `-2` is hardcoded in two places (lines 722 and 1370).
- **`OnBarsCreated` is a one-shot hook** set by each class's setup function (Hunter at line 1075, Rogue at line 273, etc.) and cleared to `nil` at `SuperSwingTimer_UI.lua` line 2161 after one call.

## File Operations
### Read
- `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_UI.lua` (lines 1-50, 200-229, 460-720, 975-1020, 1340-1383, 2070-2163)
- `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua` (lines 750-906, 1060-1090, 1340-1469)
- `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_Constants.lua` (lines 55-84, 447-476)
- `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_State.lua` (lines 25-49, 440-614)

### Modified
- (none)
