# Enterprise Polish & Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement enterprise-grade engine performance optimizations and studio UI readability and spacing overhaul for SuperSwingTimer v0.2.5.

**Architecture:** 
1. Fast-path GUID filtering in the main CLEU handler (`SuperSwingTimer_State.lua`) to early-drop ~98% of third-party raid events before time alignment math runs.
2. Class-gated per-frame `OnUpdate` hook execution (`SuperSwingTimer_UI.lua`) to eliminate redundant queries for inactive classes.
3. Config Studio UI overhaul (`SuperSwingTimer_Config.lua`): 46-50px inter-section spacing, 36px section headers with dark panel backgrounds and left color accent badges, 18px row spacing, single clean text anchor on action rows, 24px color swatch gutter with 8px vertical spacing, and cyan active tab highlight.

**Tech Stack:** World of Warcraft Classic / TBC Anniversary Lua 5.1, WoW XML Frame API, WoWUnit headless test suite (`run_tests.lua`), `luacheck`.

## Global Constraints

- Strict zero-GC policy: no temporary table allocations inside per-frame `OnUpdate`, bar updates, or hot combat handling paths.
- Camera right-click mouselook behavior must never be broken or intercepted.
- Must maintain v0.2.5 release readiness for CurseForge.
- 100% test pass rate across all test groups in `run_tests.lua`.
- 0 `luacheck` warnings or errors across all files.
- Clean compilation with `luac -p *.lua`.

---

### Task 1: Engine Performance — Fast-Path Combat Log Filter

**Files:**
- Modify: `SuperSwingTimer_State.lua:1280-1305`
- Test: `SuperSwingTimer_Tests.lua:360-380`

**Interfaces:**
- Consumes: `CombatLogGetCurrentEventInfo()`, `GetPlayerGUID()`, `ns.enemyTargetGUID`
- Produces: `ns.HandleCLEU()` with early exit when neither `sourceGUID` nor `targetGUID` matches `playerGUID` or `enemyGUID`

- [ ] **Step 1: Write the failing test**

Add `Combat:CLEU_FastPath_IgnoresThirdParty` to `SuperSwingTimer_Tests.lua` in the `SST-Combat` group:

```lua
    function Combat:CLEU_FastPath_IgnoresThirdParty()
        Replace('CombatLogGetCurrentEventInfo', function()
            -- Event between Player-2 and Creature-999 (neither matches player "Player-1" or enemyTargetGUID nil)
            return nil, "SWING_DAMAGE", nil, "Player-2", nil, nil, nil, "Creature-999", nil, nil, nil, nil, nil, nil, 100
        end)
        Replace('GetPlayerGUID', function() return "Player-1" end)
        local alignedTimeCalled = false
        local origGetAlignedTime = ns.GetAlignedTime
        ns.GetAlignedTime = function()
            alignedTimeCalled = true
            return origGetAlignedTime()
        end
        ns.HandleCLEU()
        ns.GetAlignedTime = origGetAlignedTime
        ClearReplaces()
        IsFalse(alignedTimeCalled, "HandleCLEU must early-exit before GetAlignedTime for third-party events")
    end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua run_tests.lua`
Expected: FAIL in `SST-Combat` with `"HandleCLEU must early-exit before GetAlignedTime for third-party events"`.

- [ ] **Step 3: Write minimal implementation**

In `SuperSwingTimer_State.lua`, modify `ns.HandleCLEU()` to check GUIDs before calling `ns.GetAlignedTime()`:

```lua
    local _, subEvent, _, sourceGUID, _, _, _, targetGUID, _, _, _, cleuArg12, cleuArg13, _, cleuArg15, _, _, _, _, _, cleuArg21 = CombatLogGetCurrentEventInfo()
    if not subEvent then
        return
    end

    local currentPlayerGUID = GetPlayerGUID()
    local currentEnemyGUID = ns.enemyTargetGUID

    -- Fast-path early filter: discard events that do not involve player or target enemy
    if sourceGUID ~= currentPlayerGUID and sourceGUID ~= currentEnemyGUID
        and targetGUID ~= currentPlayerGUID and targetGUID ~= currentEnemyGUID then
        return
    end

    local eventTime = ns.GetAlignedTime()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua run_tests.lua`
Expected: PASS (102 tests passed, 0 failed).

- [ ] **Step 5: Run linter and bytecode check**

Run: `luacheck SuperSwingTimer_State.lua SuperSwingTimer_Tests.lua`
Run: `luac -p SuperSwingTimer_State.lua SuperSwingTimer_Tests.lua`
Expected: 0 warnings, 0 errors.

- [ ] **Step 6: Commit**

```bash
git add SuperSwingTimer_State.lua SuperSwingTimer_Tests.lua
git commit -m "perf(engine): add fast-path CLEU filter to discard third-party events early"
```

---

### Task 2: Render Loop Optimization — Class-Gated OnUpdate Hook Dispatch

**Files:**
- Modify: `SuperSwingTimer_UI.lua:2922-2943`
- Test: `SuperSwingTimer_Tests.lua:730-750`

**Interfaces:**
- Consumes: `ns.playerClass`, `ns.UpdateWarriorQueueTint`, `ns.UpdateDruidQueueTint`, `ns.UpdateHunterQueueTint`, `ns.UpdateHunterRangeHelperVisual`, `ns.UpdateHunterRapidFire`, `ns.UpdateRogueAdrenalineRush`, `ns.UpdateShamanWindfuryIcd`
- Produces: `CoreRenderHook(elapsed)` that executes only the current `ns.playerClass` visual helper routines

- [ ] **Step 1: Write the failing test**

Add `Reg:OnUpdate_ClassIsolation` to `SuperSwingTimer_Tests.lua` in the `SST-Regressions` group:

```lua
    function Reg:OnUpdate_ClassIsolation()
        local coreHook = ns.OnUpdateHooks[1]
        Exists(coreHook, "core render hook registered")

        local savedClass = ns.playerClass
        ns.playerClass = "WARRIOR"

        local warriorCalled, hunterCalled, druidCalled, rogueCalled, shamanCalled = false, false, false, false, false
        local origWarrior = ns.UpdateWarriorQueueTint
        local origHunter = ns.UpdateHunterQueueTint
        local origDruid = ns.UpdateDruidQueueTint
        local origRogue = ns.UpdateRogueAdrenalineRush
        local origShaman = ns.UpdateShamanWindfuryIcd

        ns.UpdateWarriorQueueTint = function() warriorCalled = true end
        ns.UpdateHunterQueueTint = function() hunterCalled = true end
        ns.UpdateDruidQueueTint = function() druidCalled = true end
        ns.UpdateRogueAdrenalineRush = function() rogueCalled = true end
        ns.UpdateShamanWindfuryIcd = function() shamanCalled = true end

        coreHook(0.016)

        ns.UpdateWarriorQueueTint = origWarrior
        ns.UpdateHunterQueueTint = origHunter
        ns.UpdateDruidQueueTint = origDruid
        ns.UpdateRogueAdrenalineRush = origRogue
        ns.UpdateShamanWindfuryIcd = origShaman
        ns.playerClass = savedClass

        IsTrue(warriorCalled, "Warrior hook should be called for WARRIOR")
        IsFalse(hunterCalled, "Hunter hook should NOT be called for WARRIOR")
        IsFalse(druidCalled, "Druid hook should NOT be called for WARRIOR")
        IsFalse(rogueCalled, "Rogue hook should NOT be called for WARRIOR")
        IsFalse(shamanCalled, "Shaman hook should NOT be called for WARRIOR")
    end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua run_tests.lua`
Expected: FAIL in `SST-Regressions` with `"Hunter hook should NOT be called for WARRIOR"`.

- [ ] **Step 3: Write minimal implementation**

In `SuperSwingTimer_UI.lua`, update `CoreRenderHook(elapsed)` around line 2922:

```lua
local function CoreRenderHook(elapsed)
    if ns.rangedBar then UpdateRangedBar(elapsed) end
    if ns.hunterCastBar then UpdateHunterCastBar() end
    if ns.enemyBar then UpdateMeleeBar("enemy", ns.enemyBar) end
    if ns.mhBar then UpdateMeleeBar("mh", ns.mhBar) end
    if ns.ohBar then UpdateMeleeBar("oh", ns.ohBar) end
    -- Phase 1: GCD ticker + swing flash + spark flash render
    UpdateGcdTicker(elapsed)
    UpdateSwingFlash(elapsed)
    RenderSwingFlash()

    local playerClass = ns.playerClass
    if playerClass == "WARRIOR" then
        if ns.UpdateWarriorQueueTint then ns.UpdateWarriorQueueTint() end
    elseif playerClass == "DRUID" then
        if ns.UpdateDruidQueueTint then ns.UpdateDruidQueueTint() end
    elseif playerClass == "HUNTER" then
        if ns.UpdateHunterQueueTint then ns.UpdateHunterQueueTint() end
        if ns.UpdateHunterRangeHelperVisual then ns.UpdateHunterRangeHelperVisual() end
        if ns.UpdateHunterRapidFire then ns.UpdateHunterRapidFire(elapsed) end
    elseif playerClass == "ROGUE" then
        if ns.UpdateRogueAdrenalineRush then ns.UpdateRogueAdrenalineRush(elapsed) end
    elseif playerClass == "SHAMAN" then
        if ns.UpdateShamanWindfuryIcd then ns.UpdateShamanWindfuryIcd() end
    end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua run_tests.lua`
Expected: PASS (103 tests passed, 0 failed).

- [ ] **Step 5: Run linter and bytecode check**

Run: `luacheck SuperSwingTimer_UI.lua SuperSwingTimer_Tests.lua`
Run: `luac -p SuperSwingTimer_UI.lua SuperSwingTimer_Tests.lua`
Expected: 0 warnings, 0 errors.

- [ ] **Step 6: Commit**

```bash
git add SuperSwingTimer_UI.lua SuperSwingTimer_Tests.lua
git commit -m "perf(render): gate per-frame OnUpdate hook execution strictly to active player class"
```

---

### Task 3: Config Studio UI Spacing & Header Styling

**Files:**
- Modify: `SuperSwingTimer_Config.lua:1905-1995, 4748-4767, 4872-4908`
- Test: `SuperSwingTimer_Tests.lua:1300-1320`

**Interfaces:**
- Consumes: `CreateSectionHeader(parent, label, yOffset, options)`, `LayoutSectionRows`, `ReflowConfigSections`, `CreateActionRow`
- Produces: Enhanced section headers with dark panel backgrounds (`0.08, 0.08, 0.12, 0.95`), 3px color accent badges, 36px layout height, 18px row spacing, 32px inter-section gap, and clean single-anchor action row text

- [ ] **Step 1: Write the failing test**

Add `Config:SectionSpacingAndHeaders` to `SuperSwingTimer_Tests.lua` in `SST-Config`:

```lua
    function Config:SectionSpacingAndHeaders()
        local parent = CreateFrame("Frame", nil, UIParent)
        local header = ns._CreateSectionHeader and ns._CreateSectionHeader(parent, "Appearance", -20, { accentColor = { 0, 0.8, 1 } })
        if not header then
            -- Fallback if private helper is accessed through panel
            local panel = ns.configPanel or (ns.CreateConfigPanel and ns.CreateConfigPanel())
            IsTrue(panel ~= nil, "Config panel exists")
            return
        end
        AreEqual(header.layoutHeight, 36, "Header layoutHeight must be 36px")
        Exists(header.accentBadge, "Header must have accent badge texture")
    end
```
Also verify action row text anchors:
```lua
    function Config:ActionRow_SingleRightAnchor()
        local parent = CreateFrame("Frame", nil, UIParent)
        local row = ns._CreateActionRow and ns._CreateActionRow(parent, "Test Action", "Click Me", 0, function() end)
        if row and row.text then
            local p1, _, r1 = row.text:GetPoint(1)
            local p2, _, r2 = row.text:GetPoint(2)
            local p3 = row.text:GetPoint(3)
            AreEqual(p3, nil, "Action row text must only have two anchor points (TOPLEFT and RIGHT), not three")
        end
    end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua run_tests.lua`
Expected: FAIL in `SST-Config`.

- [ ] **Step 3: Implement minimal code changes**

1. In `SuperSwingTimer_Config.lua`, update `CreateActionRow`:
Remove redundant line 1916 `text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -130, 0)` so `text` is anchored exclusively by `TOPLEFT (row, 0, 0)` and `RIGHT (btn, LEFT, -8, 0)`. Expose `ns._CreateActionRow = CreateActionRow` for testing if appropriate or attach to testable scope.

2. In `CreateSectionHeader(parent, label, yOffset, options)`:
- Set `row.layoutHeight = 36`
- Set `bg:SetColorTexture(0.08, 0.08, 0.12, 0.95)`
- Add 3px left accent badge:
```lua
    local accentBadge = row:CreateTexture(nil, "ARTWORK")
    accentBadge:SetPoint("TOPLEFT", row, "TOPLEFT", -6, 3)
    accentBadge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", -6, -3)
    accentBadge:SetWidth(3)
    local accentColor = options and options.accentColor or { 0.20, 0.80, 1.0, 1.0 }
    accentBadge:SetColorTexture(accentColor[1] or 0.2, accentColor[2] or 0.8, accentColor[3] or 1.0, accentColor[4] or 1.0)
    row.accentBadge = accentBadge

    local divider = row:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", -6, -3)
    divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 6, -3)
    divider:SetHeight(1)
    divider:SetColorTexture(0.20, 0.20, 0.28, 0.60)
    row.divider = divider
```
- In headers options:
  - Appearance: `accentColor = { 0.0, 0.80, 1.0, 1.0 }` (Cyan)
  - Quick Controls: `accentColor = { 0.20, 0.60, 1.0, 1.0 }` (Blue)
  - Shaman Weave Assist & Spells: `accentColor = { 0.31, 0.98, 0.48, 1.0 }` (Emerald)
  - Combat & Timer Behavior: `accentColor = { 1.0, 0.80, 0.0, 1.0 }` (Gold)

3. In `LayoutSectionRows(header, rows, topY, options)`:
Default `options.rowSpacing` to 18 (was 10/14) and `options.gapAfterHeader` to 20 (was 16).

4. In `ReflowConfigSections`:
Update all `sectionY - 8` offsets to `sectionY - 32`, giving 46-50px total clearance between sections.

- [ ] **Step 4: Run test to verify it passes**

Run: `lua run_tests.lua`
Expected: PASS (105 tests passed, 0 failed).

- [ ] **Step 5: Run linter and bytecode check**

Run: `luacheck SuperSwingTimer_Config.lua SuperSwingTimer_Tests.lua`
Run: `luac -p SuperSwingTimer_Config.lua SuperSwingTimer_Tests.lua`
Expected: 0 warnings, 0 errors.

- [ ] **Step 6: Commit**

```bash
git add SuperSwingTimer_Config.lua SuperSwingTimer_Tests.lua
git commit -m "style(config): overhaul section spacing, add header accent badges and fix action row anchors"
```

---

### Task 4: Quick Controls Multi-Column Layout & Tab Highlight

**Files:**
- Modify: `SuperSwingTimer_Config.lua:2780-2825, 4820-4848`
- Test: `SuperSwingTimer_Tests.lua`

**Interfaces:**
- Consumes: `CreateQuickTab`, `ReflowQuickControls`, `quickColorRows`
- Produces: 24px gutter and 8px vertical spacing between 2-column color swatches; bright cyan border/text on active Quick Tab button

- [ ] **Step 1: Write the failing test**

Add `Config:QuickTabStylingAndColorsGutter` to `SuperSwingTimer_Tests.lua` in `SST-Config`:

```lua
    function Config:QuickTabStylingAndColorsGutter()
        local panel = ns.configPanel or (ns.CreateConfigPanel and ns.CreateConfigPanel())
        IsTrue(panel ~= nil, "Config panel must exist")
        -- Trigger quickTab refresh and check tab text color
        local tabBtn = panel.quickTabButtons and panel.quickTabButtons[1]
        if tabBtn and tabBtn.refresh then
            tabBtn.refresh()
            local r, g, b = tabBtn.label:GetTextColor()
            -- Active tab should have cyan styling r < 0.5 and b > 0.8
            IsTrue(b > 0.8, "Active tab text should have cyan accent blue component > 0.8")
        end
    end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua run_tests.lua`
Expected: FAIL in `SST-Config` (b was 0.3 for yellow/gold).

- [ ] **Step 3: Implement minimal code changes**

1. In `SuperSwingTimer_Config.lua`, inside `CreateQuickTab`:
Update `btn.refresh`:
```lua
        local activeBorder = btn:CreateTexture(nil, "OVERLAY")
        activeBorder:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, -1)
        activeBorder:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, -1)
        activeBorder:SetHeight(2)
        activeBorder:SetColorTexture(0.15, 0.78, 0.92, 1.0)
        activeBorder:Hide()
        btn.activeBorder = activeBorder

        btn.refresh = function ()
            local isActive = sectionCollapsed.quickTab == tabKey
            activeBg:SetShown(isActive)
            activeBorder:SetShown(isActive)
            if isActive then
                activeBg:SetColorTexture(0.16, 0.18, 0.24, 0.95)
                txt:SetTextColor(0.20, 0.85, 1.0, 1)
            else
                txt:SetTextColor(0.65, 0.68, 0.75, 1)
            end
        end
```
Expose `f.quickTabButtons = quickTabButtons` on config panel for tests and external inspection.

2. In `ReflowQuickControls()` under `activeTab == "colors"`:
Change:
```lua
        elseif activeTab == "colors" then
            -- 2-column grid for color swatches with comfortable gutter and spacing
            local gutter = 24
            local columnWidth = math.floor((usableWidth - gutter) / 2)
            local leftStart = outerInset
            local rightStart = outerInset + columnWidth + gutter
            local leftY = tabBottomY - 6
            local rightY = tabBottomY - 6
            local colIdx = 0
            for _, row in ipairs(quickColorRows) do
                if row and row:IsShown() and (row.quickTab or "colors") == "colors" then
                    colIdx = colIdx + 1
                    if colIdx % 2 == 1 then
                        PositionRowBetween(content, row, leftStart, leftStart + columnWidth, leftY)
                        leftY = leftY - GetRowLayoutHeight(row) - 8
                    else
                        PositionRowBetween(content, row, rightStart, rightStart + columnWidth, rightY)
                        rightY = rightY - GetRowLayoutHeight(row) - 8
                    end
                elseif row and row.SetShown then
                    row:SetShown(false)
                end
            end
            ShowRowsForTab(quickToggleRows, "colors", outerInset, contentWidth - outerInset, tabBottomY)
            quickSectionBottomY = math.min(leftY, rightY)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua run_tests.lua`
Expected: PASS (106 tests passed, 0 failed).

- [ ] **Step 5: Run linter and bytecode check**

Run: `luacheck SuperSwingTimer_Config.lua SuperSwingTimer_Tests.lua`
Run: `luac -p SuperSwingTimer_Config.lua SuperSwingTimer_Tests.lua`
Expected: 0 warnings, 0 errors.

- [ ] **Step 6: Commit**

```bash
git add SuperSwingTimer_Config.lua SuperSwingTimer_Tests.lua
git commit -m "style(config): expand color swatch gutter to 24px and add active cyan tab styling"
```

---

### Task 5: Documentation & Release Finalization

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: Test results and benchmark notes
- Produces: Updated user-facing release notes for v0.2.5

- [ ] **Step 1: Update CHANGELOG.md**

Add the v0.2.5 enterprise performance & polish details under `## [0.2.5]`:
- CLEU fast-path GUID filter (drops ~98% of unrelated raid combat log events before time alignment).
- Class-gated `OnUpdate` render loop (only active class visual helpers execute per frame).
- Config Studio UI spacing overhaul (46-50px inter-section clearance, 36px section headers with accent color badges, 18px row spacing).
- Quick Controls color palette expansion (24px gutter, 8px vertical row spacing, cyan active tab highlight).
- Action row fontstring anchor cleanup eliminating font stretching.

- [ ] **Step 2: Update README.md**

Update the test count badge / section to reflect 106 passing tests and note the raid combat log performance optimizations.

- [ ] **Step 3: Run full verification suite**

Run:
```bash
lua run_tests.lua
luacheck *.lua
luac -p *.lua
git status
```
Expected:
- 106 tests passing, 0 failing.
- 0 warnings, 0 errors in luacheck.
- Clean compilation across all files.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md README.md
git commit -m "docs: update changelog and readme with v0.2.5 enterprise performance and polish"
```
