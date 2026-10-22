# Enterprise Polish & Performance Design Document

- **Date**: 2026-10-22
- **Topic**: Enterprise-Grade Engine Performance & Studio UI Readability Overhaul
- **Version**: v0.2.5
- **Status**: Approved by User

---

## 1. Executive Summary & Goals

This document specifies the enterprise-grade performance optimizations and UI readability overhaul for **SuperSwingTimer v0.2.5**.

### Key Objectives
1. **Raid & Battleground Engine Performance**:
   - Filter ~98% of third-party `COMBAT_LOG_EVENT_UNFILTERED` events immediately before clock alignment or state parsing.
   - Restrict per-frame `OnUpdate` render hooks strictly to the active player class, eliminating 6-7 redundant function queries per frame at 144 FPS.
   - Enforce a strict zero-garbage-collection policy in all combat render paths.
2. **Config Studio UI Spacing & Readability**:
   - Expand inter-section spacing from 22px to 46px so section headers never visually collide with slider min/max labels.
   - Enhance section headers with solid dark backdrops (`0.08, 0.08, 0.12, 0.95`), 3px color accent badges, and clean divider lines.
   - Increase row spacing between controls to 18px and expand 2-column color swatch gutters from 16px to 24px with 8px vertical spacing.
   - Ensure all controls have generous, misclick-proof hitboxes with zero overlapping text or editboxes.
3. **Enterprise Verification**:
   - Maintain 100% test pass rate across all test groups in `run_tests.lua`.
   - Maintain 0 warnings and 0 errors across all Lua files in `luacheck`.

---

## 2. Architecture & Engine Performance

### 2.1 Fast-Path Combat Log Filter (`SuperSwingTimer_State.lua`)
- **Current Behavior**: `ns.HandleCLEU()` runs on every combat log event. In 25-man / 40-man raids, this fires 300-800+ times per second. Even if the event belongs to an unrelated player or pet, it executes `ns.GetAlignedTime()`, calculates epoch offsets, and queries tables.
- **Optimized Implementation**:
  - Cache `ns.playerGUID` during `PLAYER_LOGIN` / `ADDON_LOADED` (`UnitGUID("player")`).
  - Read `sourceGUID` and `targetGUID` from `CombatLogGetCurrentEventInfo()`.
  - Add an early-exit guard:
    ```lua
    local playerGUID = ns.playerGUID or UnitGUID("player")
    local enemyGUID = ns.enemyTargetGUID
    if sourceGUID ~= playerGUID and sourceGUID ~= enemyGUID
       and targetGUID ~= playerGUID and targetGUID ~= enemyGUID then
        return
    end
    ```
  - Only when the event directly involves the player or the current target does `ns.GetAlignedTime()` execute and full subEvent parsing commence.

### 2.2 Class-Gated Frame Render Loop (`SuperSwingTimer_UI.lua`)
- **Current Behavior**: `CoreRenderHook(elapsed)` runs every frame (at 144 FPS = 144 times/sec). It sequentially checks and calls:
  `UpdateWarriorQueueTint`, `UpdateDruidQueueTint`, `UpdateHunterQueueTint`, `UpdateHunterRangeHelperVisual`, `UpdateHunterRapidFire`, `UpdateRogueAdrenalineRush`, `UpdateShamanWindfuryIcd`.
- **Optimized Implementation**:
  - Dispatch class-specific visual updates exclusively based on `ns.playerClass`:
    ```lua
    if ns.playerClass == "WARRIOR" then
        if ns.UpdateWarriorQueueTint then ns.UpdateWarriorQueueTint() end
    elseif ns.playerClass == "DRUID" then
        if ns.UpdateDruidQueueTint then ns.UpdateDruidQueueTint() end
    elseif ns.playerClass == "HUNTER" then
        if ns.UpdateHunterQueueTint then ns.UpdateHunterQueueTint() end
        if ns.UpdateHunterRangeHelperVisual then ns.UpdateHunterRangeHelperVisual() end
        if ns.UpdateHunterRapidFire then ns.UpdateHunterRapidFire(elapsed) end
    elseif ns.playerClass == "ROGUE" then
        if ns.UpdateRogueAdrenalineRush then ns.UpdateRogueAdrenalineRush(elapsed) end
    elseif ns.playerClass == "SHAMAN" then
        if ns.UpdateShamanWindfuryIcd then ns.UpdateShamanWindfuryIcd() end
    end
    ```
  - This eliminates 6-7 redundant function calls and global table accesses every frame.

### 2.3 Zero-GC Policy
- No temporary tables (`{}`) created inside `OnUpdate`, `UpdateMeleeBar`, or `UpdateRangedBar`.
- String formatting is restricted to throttled UI displays (e.g. text labels).

---

## 3. Config Studio UI Spacing & Readability

### 3.1 Inter-Section Spacing & Geometry (`SuperSwingTimer_Config.lua`)
- **Spacing Enhancement**:
  - In `ReflowConfigSections()`:
    - Increase `gapAfterHeader` to 20px.
    - Set the vertical gap between the bottom of one section's rows and the next header to **32px** (resulting in a total visual separation of ~46px including row padding).
    - Prevents low/high slider labels (`slider.Low`, `slider.High`) from touching or crowding the next section header.

### 3.2 Visual Section Headers (`CreateSectionHeader`)
- **Design Specifications**:
  - Height: 26px; Layout height: 36px.
  - Background texture: Solid dark panel bar `0.08, 0.08, 0.12, 0.95`.
  - Left Accent Badge: A 3px colored indicator bar on the left edge:
    - Cyan (`#00ccff`) for Appearance / Sliders.
    - Gold (`#ffcc00`) for Combat & Timer Behavior.
    - Emerald (`#50fa7b`) for Shaman Weave Assist & Spells.
    - Blue (`#3399ff`) for Bar Visibility / Quick Controls.
  - Bottom Divider Line: 1px subtle divider `0.2, 0.2, 0.28, 0.6` across the header width.
  - Collapse Indicator: Clean `[-]` / `[+]` indicator aligned left of the section title.

### 3.3 Control Hitboxes & Anti-Overlap Protection
- **Control Row Spacing**: Increase `rowSpacing` in `LayoutSectionRows()` from 14px to **18px**.
- **Slider Rows (`CreateLabeledSliderRow`)**:
  - Title text strictly bounded: `TOPLEFT (0, 0)` to `TOPRIGHT (-(valueBoxWidth + 16), 0)`.
  - Slider track: 16px height, placed at Y = -30.
  - Value EditBox: 58px width, 22px height, placed at `TOPRIGHT (0, -22)`, with a darkened background (`0.03, 0.03, 0.05, 0.95`) and clear border.
- **Toggle Rows (`CreateToggleRow`)**:
  - Full-row clickability: clicking anywhere on the label row toggles the checkbox.
  - Hover highlight provides instant visual feedback.
  - Label text wraps cleanly on the left with an explicit 36px right margin.
- **Action Rows (`CreateActionRow`)**:
  - Clean up conflicting right-anchor points on the label text fontstring.
  - Explicit 12px margin between description text and action buttons.

### 3.4 Quick Controls Multi-Column Layout (`ReflowQuickControls`)
- **Key Colors Tab**:
  - Increase the 2-column gutter from 16px to **24px**.
  - Increase vertical row spacing between color swatches from 4px to **8px**.
  - Swatch buttons maintain generous 160px width x 24px height hitboxes.
- **Tab Buttons (`quickTabButtons`)**:
  - Active tab receives bright cyan accent text and highlighted border.
  - Inactive tabs maintain muted slate text and dark borders.

---

## 4. Verification & Testing Strategy

1. **Unit Testing (`SuperSwingTimer_Tests.lua`)**:
   - `CLEU_FastPath_IgnoresThirdParty`: verifies events where neither source nor target matches player/enemy exit instantly without time alignment or state mutations.
   - `OnUpdate_ClassIsolation`: verifies non-player class hooks are never executed.
   - `Config_SectionSpacing`: verifies calculated vertical distance between section headers and prior rows is >= 40px.
2. **Automated Verification**:
   - Run `lua run_tests.lua`: 100% pass across all test groups.
   - Run `luacheck *.lua`: 0 errors, 0 warnings across all 11 files.
   - Run `luac -p *.lua`: Clean bytecode compilation.
3. **Documentation**:
   - Update `CHANGELOG.md` with enterprise performance optimizations and studio spacing enhancements.
   - Update `README.md` reflecting final test counts and performance characteristics.
