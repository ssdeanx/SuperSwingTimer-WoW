---
session: ses_1bfa
updated: 2026-05-19T13:01:12.951Z
---

# Session Summary

## Goal
Find and understand every bar creation function, SetPoint anchor relationship, and stacking/hierarchy variable in Super Swing Timer to enable restructuring of the hunter bar layout (melee above ranged, cast below ranged).

## Constraints & Preferences
- Must preserve existing non-hunter bar behavior
- Must understand the dynamic anchoring (cast bar visibility toggles MH position)
- Need to identify all places where bar parent/child relationships are established or re-anchored
- The hunter range helper bar (vertical bar) also depends on this hierarchy

## Progress
### Done
- [x] Found `CreateBar` (465-569, UI.lua): Factory for all bars. Creates `StatusBar` parented to `UIParent`, sets size (BAR_WIDTH/BAR_HEIGHT), centers at `(0, -100)`, creates overlay, border, spark, label, drag handling.
- [x] Found `CreateRangedBar` (589-627, UI.lua): Creates ranged bar via `CreateBar`, adds `castOverlay` (TOPLEFT/BOTTOMRIGHT anchored to bar), `castThresholdMarker` (TOPLEFT/BOTTOMLEFT), `latencyOverlay` (TOPRIGHT/BOTTOMRIGHT), `latencyMarker` (TOPLEFT/BOTTOMLEFT).
- [x] Found `CreateHunterCastBar` (629-682, UI.lua): Creates bar with `HUNTER_CAST_BAR_HEIGHT`, anchors `TOPLEFT/TOPRIGHT` to `rangedBar: BOTTOMLEFT/BOTTOMRIGHT` with offset `0, -(HUNTER_CAST_BAR_GAP or 2)`.
- [x] Found `CreateMHBar` (684-698, UI.lua): Creates bar, adds `hunterQueueOverlay` and `weaveSpark`.
- [x] Found `CreateOHBar` (699-727, UI.lua): Creates bar, anchors `TOPLEFT/TOPRIGHT` to `MH bar: BOTTOMLEFT/BOTTOMRIGHT` with offset `0, -2`.
- [x] Found `UpdateHunterMeleeBarAnchor` (995-1016, UI.lua): **KEY FUNCTION FOR RESTRUCTURING**. If cast bar visible, anchors MH below cast bar; else below ranged bar. Uses `TOPLEFT/TOPRIGHT` → `BOTTOMLEFT/BOTTOMRIGHT` with `0, -2`.
- [x] Found `ShouldShowHunterCastBar` (428-456, UI.lua): Logic for when cast bar appears (Auto Shot window, live Multi-Shot/Steady Shot cast, stored cast state).
- [x] Found `UpdateHunterCastBar` (868-1050, UI.lua): Updates cast bar state; calls `UpdateHunterMeleeBarAnchor(false)` when hiding, call chain passes through `SetAlpha(0)` → triggers re-anchor.
- [x] Found `ApplyBarSize` (1340-1381, UI.lua): Re-anchors OH to MH, calls `UpdateHunterMeleeBarAnchor`, re-anchors rogue slice/dice.
- [x] Found `ns.InitBars` (2081-2125, UI.lua): Init sequence: enemy→ranged→hunterCast→MH→OH→rogue bars. For HUNTER with ranged, calls `UpdateHunterMeleeBarAnchor(false, true)`, makes MH unmovable/undraggable.
- [x] Found `OnBarsCreated` for hunter (1075-1090, ClassMods.lua): Creates `hunterRangeHelperBar` via `EnsureVerticalHelperBar` anchored to `ns.rangedBar`.
- [x] Found `GetHunterRangeHelperAnchors` (893-906, ClassMods.lua): Bottom anchor dynamically picks between cast bar and MH bar depending on visibility.
- [x] Found all layout constants: `HUNTER_CAST_BAR_HEIGHT` (default 10), `HUNTER_CAST_BAR_GAP` (default 2), `BAR_WIDTH`/`BAR_HEIGHT` from DB, no explicit `barStack` variable.
- [x] Found `ApplyVisibility` (1883-2035, UI.lua): Controls which bars are visible; controls cast window, label, and spark updates per bar.

### In Progress
- [ ] None — all discovery complete

### Blocked
- (none)

## Key Decisions
- **(not yet made)**: User wants to change layout from current `ranged→cast→MH→OH` (top to bottom) to `MH→ranged→cast` (melee above ranged, cast below ranged). All discovery is done; code change not yet implemented.

## Critical Context
**Current Hunter Bar Hierarchy (top to bottom, centered as a group on UIParent):**

```
rangedBar (independently positioned, center of the group)
  │ gap=2 (HUNTER_CAST_BAR_GAP)
  ├─ hunterCastBar (only visible during cast/Auto Shot window)
  │   └─ if visible: MH anchors below this
  │ gap=2
  │   └─ if hidden: MH anchors directly below rangedBar
  ├─ mhBar  (dynamically re-anchored by UpdateHunterMeleeBarAnchor)
  │   │ gap=2
  │   └─ ohBar (always below MH, automatically follows via anchors)
```

**The two-point SetPoint pattern family (same pattern everywhere):**
```lua
child:SetPoint("TOPLEFT",     parent, "BOTTOMLEFT",  0, -gap)
child:SetPoint("TOPRIGHT",    parent, "BOTTOMRIGHT", 0, -gap)
```

**Files and key line numbers for the restructuring:**
| What                        | File          | Lines     |
| --------------------------- | ------------- | --------- |
| `UpdateHunterMeleeBarAnchor`  | UI.lua        | 995-1016  |
| `CreateRangedBar`             | UI.lua        | 589-627   |
| `CreateHunterCastBar`         | UI.lua        | 629-682   |
| `CreateMHBar`                 | UI.lua        | 684-698   |
| `CreateOHBar`                 | UI.lua        | 699-727   |
| `InitBars`                    | UI.lua        | 2081-2125 |
| `ApplyBarSize` (re-anchors)   | UI.lua        | 1340-1381 |
| `ApplyVisibility`             | UI.lua        | 1883-2035 |
| `GetHunterRangeHelperAnchors` | ClassMods.lua | 893-906   |
| `OnBarsCreated` (helper bar)  | ClassMods.lua | 1075-1090 |
| `EnsureVerticalHelperBar`     | ClassMods.lua | 82-155    |
| `ShouldShowHunterCastBar`     | UI.lua        | 428-456   |
| `UpdateHunterCastBar`         | UI.lua        | 868-1050  |

**Key insight for restructuring:** The current system uses `UpdateHunterMeleeBarAnchor` to keep the MH bar below the cast bar (when visible) or below the ranged bar. To make MH above ranged, you will need to:
1. Either make ranged bar independent and anchor MH above it OR make MH the new top anchor bar
2. Change `UpdateHunterMeleeBarAnchor` to set MH `BOTTOMLEFT/BOTTOMRIGHT` → ranged `TOPLEFT/TOPRIGHT`
3. Update `GetHunterRangeHelperAnchors` since the vertical helper currently sits between rangedBar and bottomAnchor (cast bar or MH) — placement logic may need revision
4. Update `ApplyBarSize` re-anchoring for OH and cast bar relative to the new top/bottom positions
5. The cast bar anchoring (`CreateHunterCastBar` lines 638-639) already puts it below ranged, which is what you want — that likely stays unchanged
6. `UsesInvertedClassLabelStyle` (line 234) lists `mhBar, ohBar, rangedBar, hunterCastBar` — these bars get inverted labels when class colors are on

## Next Steps
1. Decide restructuring strategy: (a) Make MH a fixed top bar and anchor ranged below it, or (b) keep ranged as positional anchor but set MH above it with negative gap, (c) use a master anchor frame to control the full stack order
2. Implement the new anchoring in `UpdateHunterMeleeBarAnchor` — change from anchoring MH below something to anchoring it above the ranged bar
3. Update `CreateHunterCastBar` anchoring if needed (currently below ranged, which matches desired layout)
4. Update `ApplyBarSize` re-anchoring logic for all bars
5. Update `GetHunterRangeHelperAnchors` to handle the new layout
6. Test with `ShouldShowHunterCastBar` both true and false
7. Ensure OH bar still follows MH bar correctly

## File Operations
### Read
- `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_ClassMods.lua`
- `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_State.lua`
- `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\SuperSwingTimer\SuperSwingTimer_UI.lua`

### Modified
- (none)
