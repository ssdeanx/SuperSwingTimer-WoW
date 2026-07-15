---@diagnostic disable: undefined-global
-- ============================================================
-- Migration & Fresh-Install Test Harness
-- Run: lua5.1 test_migrations.lua
-- Requires: Lua 5.1 (same version as WoW's embedded Lua)
-- ============================================================
-- Mocks the minimal WoW addon environment needed to test the
-- DeepCopyDefaults and fresh-install path. Does NOT test every
-- individual migration entry — those require Blizzard API mocks.
-- ============================================================

local pass = 0
local fail = 0

local function assert_eq(label, actual, expected)
    if actual == expected then
        pass = pass + 1
    else
        fail = fail + 1
        io.stderr:write(string.format("FAIL [%s]: expected %s, got %s\n", label, tostring(expected), tostring(actual)))
    end
end

-- Mock ns table and DB_DEFAULTS (simplified subset for test)
local ns = {}
ns.DB_DEFAULTS = {
    version = 54,
    showMH = true,
    showOH = true,
    showRanged = true,
    barWidth = 240,
    barHeight = 15,
    minimalMode = false,
    lockBars = false,
    globalScale = 1.0,
    indicatorBlendMode = "ADD",
    barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
    sparkColor = { r = 1, g = 1, b = 1, a = 1 },
    barBackgroundColor = { r = 0, g = 0, b = 0, a = 0.4 },
    barBorderColor = { r = 0, g = 0, b = 0, a = 1 },
    weaveSpellFamilies = { LB = true, CL = true, HW = true, LHW = true, CH = true },
    colors = {
        mh = { r = 0, g = 0, b = 0, a = 1 },
        oh = { r = 0, g = 0, b = 0, a = 1 },
        ranged = { r = 0, g = 0, b = 0, a = 1 },
        enemy = { r = 1, g = 0, b = 0, a = 1 }
    },
    positions = {
        mh = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -120 },
        oh = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -145 },
        ranged = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -100 },
        enemy = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -50 }
    }
}

-- DeepCopyDefaults (extracted from SuperSwingTimer.lua for standalone test)
local function DeepCopyDefaults(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = DeepCopyDefaults(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- ============================================================
-- Test 1: Deep copy produces a table with all keys
-- ============================================================
local copy = DeepCopyDefaults(ns.DB_DEFAULTS)
for k, v in pairs(ns.DB_DEFAULTS) do
    local label = "Top-level key present: " .. tostring(k)
    assert_eq(label, copy[k] ~= nil, true)
end

-- ============================================================
-- Test 2: Deep copy is independent (modifying copy doesn't change original)
-- ============================================================
copy.barWidth = 999
assert_eq("Independent mutation", ns.DB_DEFAULTS.barWidth, 240)
copy.barWidth = 240

-- ============================================================
-- Test 3: Nested tables are deep-copied, not referenced
-- ============================================================
copy.colors.mh.r = 0.5
assert_eq("Nested table independence", ns.DB_DEFAULTS.colors.mh.r, 0)
copy.colors.mh.r = 0

-- ============================================================
-- Test 4: All nested color sub-tables are separate references
-- ============================================================
for key, def in pairs(ns.DB_DEFAULTS.colors) do
    local label = "Color sub-table independent: " .. tostring(key)
    assert_eq(label, copy.colors[key] ~= def, true)
end

-- ============================================================
-- Test 5: All nested position sub-tables are separate references
-- ============================================================
for key, def in pairs(ns.DB_DEFAULTS.positions) do
    local label = "Position sub-table independent: " .. tostring(key)
    assert_eq(label, copy.positions[key] ~= def, true)
end

-- ============================================================
-- Test 6: Version key matches expected
-- ============================================================
assert_eq("Version matches", copy.version, 54)

-- ============================================================
-- Test 7: Boolean values copy correctly
-- ============================================================
assert_eq("showMH type", type(copy.showMH), "boolean")
assert_eq("showMH value", copy.showMH, true)
assert_eq("minimalMode value", copy.minimalMode, false)

-- ============================================================
-- Test 8: String values copy correctly
-- ============================================================
assert_eq("indicatorBlendMode", copy.indicatorBlendMode, "ADD")
assert_eq("barTexture", copy.barTexture, "Interface\\TargetingFrame\\UI-StatusBar")

-- ============================================================
-- Test 9: Numeric values copy correctly
-- ============================================================
assert_eq("globalScale", copy.globalScale, 1.0)
assert_eq("barWidth", copy.barWidth, 240)

-- ============================================================
-- Test 10: weaveSpellFamilies sub-table deep copy
-- ============================================================
assert_eq("weave LB", copy.weaveSpellFamilies.LB, true)
copy.weaveSpellFamilies.LB = false
assert_eq("weave independence", ns.DB_DEFAULTS.weaveSpellFamilies.LB, true)
copy.weaveSpellFamilies.LB = true

-- ============================================================
-- Summary
-- ============================================================
local total = pass + fail
io.write(string.format("\nResults: %d/%d passed, %d failed\n", pass, total, fail))
if fail > 0 then
    io.write("SOME TESTS FAILED\n")
    os.exit(1)
else
    io.write("ALL TESTS PASSED\n")
    os.exit(0)
end
