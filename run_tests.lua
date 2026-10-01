---@diagnostic disable
-- luacheck: std lua51, globals arg unpack
-- ============================================================
-- SuperSwingTimer Standalone Headless Test Runner
-- Run: lua run_tests.lua  OR  luajit run_tests.lua
-- ============================================================

local startTime = os.clock and os.clock() or 0
local unpack = rawget(_G, "unpack") or rawget(table, "unpack")

-- ANSI color codes (disabled if NO_COLOR is set)
local useColor = not os.getenv("NO_COLOR")
local function color(code, text)
    if not useColor then return text end
    return "\27[" .. code .. "m" .. text .. "\27[0m"
end
local function green(t) return color("32", t) end
local function red(t) return color("31", t) end
local function cyan(t) return color("36", t) end
local function bold(t) return color("1", t) end

print(bold(cyan("============================================================")))
print(bold(cyan("   SuperSwingTimer Headless Test Suite (TBC / Classic)      ")))
print(bold(cyan("============================================================")))

-- ============================================================
-- 1. Mock WoW C/Lua Environment
-- ============================================================
local nowSec = 1000.0
_G.GetTime = function() return nowSec end
_G.GetTimePreciseSec = function() return nowSec end
_G.UnitClass = function(u) return "Hunter", "HUNTER" end
_G.UnitName = function(u) return "Player" end
_G.UnitGUID = function(u) return "Player-001" end
_G.GetPlayerGUID = function() return "Player-001" end
_G.UnitExists = function(u) return true end
_G.UnitIsDead = function(u) return false end
_G.UnitCanAttack = function(u1, u2) return false end
_G.UnitHealth = function(u) return 100 end
_G.UnitHealthMax = function(u) return 100 end
_G.UnitPowerType = function(u) return 0, "MANA" end
_G.UnitPowerMax = function(u) return 100 end
_G.UnitAttackSpeed = function(u) return 2.6, 2.6 end
_G.UnitRangedDamage = function(u) return 2.8 end
_G.InCombatLockdown = function() return false end
_G.GetNetStats = function() return 0, 0, 45, 45 end
_G.GetSpellInfo = function(id)
    local castTimeMs = 1500
    if id == 403 then castTimeMs = 2000 end
    return "Spell-" .. tostring(id), "", "Interface\\Icons\\INV_Misc_QuestionMark", castTimeMs, 0, 30, id
end
_G.GetItemInfo = function(id) return "Item-" .. tostring(id) end
_G.GetInventoryItemLink = function(u, slot) return nil end
_G.GetInventoryItemID = function(u, slot) return nil end
_G.GetSpellCooldown = function(id) return 0, 0 end
_G.GetComboPoints = function(u1, u2) return 0 end
_G.UnitAttackPower = function(u) return 100, 0, 0 end
_G.UnitDamage = function(u) return 50, 70, 0, 0, 0, 0, 0 end
_G.GetWeaponEnchantInfo = function() return false end
_G.PlaySound = function(id) end
_G.PlaySoundFile = function(f) end
_G.SlashCmdList = {}
_G.hooksecurefunc = function(tbl, name, fn)
    if type(tbl) == "string" then
        fn = name
        name = tbl
        tbl = _G
    end
    local orig = tbl[name]
    tbl[name] = function(...)
        if orig then orig(...) end
        return fn(...)
    end
end
_G.geterrorhandler = function()
    return function(err) return err end
end
_G.C_Timer = {
    After = function(sec, cb) end,
    NewTicker = function(sec, cb, count) return { Cancel = function() end } end,
}

local allCreatedFrames = {}

local function createMockObject()
    local obj = {
        _points = {},
        _scripts = {},
        _shown = true,
        _width = 100,
        _height = 20,
        _alpha = 1.0,
    }
    function obj:SetScript(name, handler) self._scripts[name] = handler end
    function obj:GetScript(name) return self._scripts[name] end
    function obj:HookScript(name, handler)
        local orig = self._scripts[name]
        self._scripts[name] = function(...)
            if orig then orig(...) end
            return handler(...)
        end
    end
    function obj:SetPoint(pt, rel, relPt, x, y)
        table.insert(self._points, { pt, rel, relPt, x or 0, y or 0 })
    end
    function obj:SetAllPoints(...) end
    function obj:ClearAllPoints() self._points = {} end
    function obj:GetPoint(i)
        local p = self._points[i or 1]
        if p then return unpack(p) end
    end
    function obj:SetWidth(w) self._width = w end
    function obj:SetHeight(h) self._height = h end
    function obj:GetWidth() return self._width end
    function obj:GetHeight() return self._height end
    function obj:SetSize(w, h) self._width = w; self._height = h end
    function obj:Show() self._shown = true end
    function obj:Hide() self._shown = false end
    function obj:IsShown() return self._shown end
    function obj:SetShown(s) self._shown = not not s end
    function obj:SetAlpha(a) self._alpha = a end
    function obj:GetAlpha() return self._alpha end
    function obj:GetTop() return 500 end
    function obj:GetBottom() return 480 end
    function obj:GetLeft() return 200 end
    function obj:GetRight() return 300 end
    function obj:SetText(t) self._text = t end
    function obj:GetText() return self._text end
    function obj:SetTextColor(...) end
    function obj:SetFont(...) end
    function obj:GetFont() return "Fonts\\FRIZQT__.TTF", 10, "" end
    function obj:SetJustifyH(j) self._justifyH = j end
    function obj:SetJustifyV(j) self._justifyV = j end
    function obj:SetTexture(...) end
    function obj:SetColorTexture(...) end
    function obj:SetVertexColor(...) end
    function obj:SetTexCoord(...) end
    function obj:SetBlendMode(...) end
    function obj:SetDrawLayer(...) end
    function obj:SetMinMaxValues(...) end
    function obj:SetValue(...) end
    function obj:GetValue() return 0 end
    function obj:SetStatusBarTexture(...) end
    function obj:SetStatusBarColor(...) end
    function obj:GetStatusBarTexture() return createMockObject() end
    function obj:RegisterEvent(e) end
    function obj:UnregisterEvent(e) end
    function obj:RegisterUnitEvent(e, ...) end
    function obj:SetFrameStrata(...) end
    function obj:GetFrameStrata() return "MEDIUM" end
    function obj:SetFrameLevel(...) end
    function obj:GetFrameLevel() return 1 end
    function obj:EnableMouse(...) end
    function obj:SetMovable(...) end
    function obj:RegisterForDrag(...) end
    function obj:CreateTexture(...) return createMockObject() end
    function obj:CreateFontString(...) return createMockObject() end
    return obj
end

_G.CreateFrame = function(frameType, name, parent, template)
    local f = createMockObject()
    f._type = frameType
    f._name = name
    f._parent = parent
    table.insert(allCreatedFrames, f)
    return f
end
_G.UIParent = createMockObject()

-- ============================================================
-- 2. Mock WoWUnit Framework Implementation
-- ============================================================
local WoWUnitMock = {
    children = {},
    _replaces = {},
}

setmetatable(WoWUnitMock, {
    __call = function(self, name, event)
        local group = { name = name, event = event, tests = {} }
        setmetatable(group, {
            __newindex = function(t, k, v)
                if type(v) == "function" then
                    table.insert(t.tests, { name = k, fn = v })
                end
                rawset(t, k, v)
            end,
            __call = function(t)
                local gPass, gFail = 0, 0
                io.write(cyan(string.format("  [%s]\n", t.name)))
                for _, test in ipairs(t.tests) do
                    local ok, err = pcall(test.fn, t)
                    if ok then
                        gPass = gPass + 1
                        io.write(string.format("    %s %s\n", green("✓"), test.name))
                    else
                        gFail = gFail + 1
                        io.write(string.format("    %s %s\n", red("✗"), test.name))
                        io.write(string.format("      %s\n", red(tostring(err))))
                    end
                end
                return gPass, gFail
            end,
        })
        table.insert(self.children, group)
        return group
    end
})

function WoWUnitMock.IsTrue(cond, msg)
    assert(cond, msg or "Expected true, got " .. tostring(cond))
end

function WoWUnitMock.IsFalse(cond, msg)
    assert(not cond, msg or "Expected false, got " .. tostring(cond))
end

function WoWUnitMock.Exists(val, msg)
    assert(val ~= nil, msg or "Expected non-nil value")
end

function WoWUnitMock.AreEqual(a, b, msg)
    assert(a == b, (msg and (msg .. ": ") or "") .. string.format("expected '%s', got '%s'", tostring(b), tostring(a)))
end

function WoWUnitMock.Replace(key, mockFn)
    if WoWUnitMock._replaces[key] == nil then
        WoWUnitMock._replaces[key] = _G[key] or false
    end
    _G[key] = mockFn
end

function WoWUnitMock.ClearReplaces()
    for k, v in pairs(WoWUnitMock._replaces) do
        if v == false then
            _G[k] = nil
        else
            _G[k] = v
        end
    end
    WoWUnitMock._replaces = {}
end

_G.WoWUnit = WoWUnitMock

-- ============================================================
-- 3. Load Addon Files in TOC Order
-- ============================================================
local ns = {}
local files = {
    "SuperSwingTimer_Constants.lua",
    "Media/SuperSwingTimer_Media.lua",
    "SuperSwingTimer_State.lua",
    "SuperSwingTimer_Weaving.lua",
    "SuperSwingTimer_Hooks.lua",
    "SuperSwingTimer_UI.lua",
    "SuperSwingTimer_ClassMods.lua",
    "SuperSwingTimer_Config.lua",
    "SuperSwingTimer.lua",
    "SuperSwingTimer_SoD.lua",
    "SuperSwingTimer_Tests.lua",
}

for _, file in ipairs(files) do
    local chunk, err = loadfile(file)
    if not chunk then
        error("Failed to compile " .. file .. ": " .. tostring(err))
    end
    local ok, lerr = pcall(chunk, "SuperSwingTimer", ns)
    if not ok then
        error("Failed to execute " .. file .. ": " .. tostring(lerr))
    end
end

-- ============================================================
-- 4. Pump Lifecycle Events
-- ============================================================
-- Pump initial OnUpdate to register WoWUnit tests
for _, f in ipairs(allCreatedFrames) do
    local onUpdate = f:GetScript("OnUpdate")
    if onUpdate then
        onUpdate(f, 0.016)
    end
end

-- Fire ADDON_LOADED to initialize DB and layout
for _, f in ipairs(allCreatedFrames) do
    local onEvent = f:GetScript("OnEvent")
    if onEvent then
        onEvent(f, "ADDON_LOADED", "SuperSwingTimer")
    end
end

-- ============================================================
-- 5. Execute Test Suite
-- ============================================================
print(string.format("\nDiscovered %d test groups. Executing...\n", #WoWUnitMock.children))

local totalPass, totalFail = 0, 0
for _, group in ipairs(WoWUnitMock.children) do
    if group.name and group.name:match("^SST%-") then
        local p, f = group()
        totalPass = totalPass + p
        totalFail = totalFail + f
    end
end

local elapsed = (os.clock and os.clock() or 0) - startTime

print(bold(cyan("\n============================================================")))
print(bold(string.format("RESULTS: %d Total | %s Passed | %s Failed (%.3fs)",
    totalPass + totalFail,
    green(tostring(totalPass)),
    (totalFail > 0 and red(tostring(totalFail)) or green("0")),
    elapsed
)))
print(bold(cyan("============================================================")))

if totalFail > 0 then
    print(bold(red("\nTEST SUITE FAILED!\n")))
    os.exit(1)
else
    print(bold(green("\nALL TESTS PASSED SUCCESSFULLY!\n")))
    os.exit(0)
end
