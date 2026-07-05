-- ============================================================
-- SuperSwingTimer_Hooks.lua
-- OnUpdate hook registration system.
-- Replaces the fragile chain-overwriting pattern where each
-- class Setup() captured and replaced ns.OnUpdate.
-- Loads before UI.lua and ClassMods.lua so the registration
-- function is available before any hooks are registered.
-- ============================================================
-- Dependency order: must load after Constants.lua (for ns.*)
-- Depends on: ns (namespace from parent addon)
-- ============================================================

local _, ns = ...

--- Ordered list of registered OnUpdate hook functions.
--  Each hook receives (elapsed) from the main OnUpdate dispatcher.
--  Hooks run in registration order. See ns.RegisterOnUpdateHook.
--  @type (table) List of function(elapsed) callbacks
--  @see ns.RegisterOnUpdateHook
ns.OnUpdateHooks = ns.OnUpdateHooks or {}

--- Register a per-frame OnUpdate hook.
--  Appends (or inserts at @index) a callback to ns.OnUpdateHooks.
--  The callback will be called every frame by the main OnUpdate
--  dispatcher in SuperSwingTimer_UI.lua.
--  Each hook MUST nil-guard its own dependencies — hook functions
--  should check `if ns.myFeature then ns.myFeature(elapsed) end`
--  before calling class-specific logic. This prevents a nil access
--  in an unused hook from breaking every other hook in the chain.
--  @param hook (function) A function(elapsed) to call each frame.
--         @elapsed (number) Time since last frame in seconds.
--  @param index (number|nil) Optional 1-based insertion position.
--         Omit or pass nil to append at the end. Use 1 to insert
--         at the front (e.g. for pre-render hooks like Test Bars).
--  @return (nil)
--  @usage -- Register a simple nil-guarded hook:
--         ns.RegisterOnUpdateHook(function(elapsed)
--             if ns.UpdateMyHelper then ns.UpdateMyHelper(elapsed) end
--         end)
--  @usage -- Insert a high-priority hook at the front:
--         ns.RegisterOnUpdateHook(function(elapsed)
--             if ns.barTestActive then AnimateTestBars() end
--         end, 1)
--  @see ns.OnUpdateHooks
--  @see ns.OnUpdate (main dispatcher in UI.lua)
local function RegisterOnUpdateHook(hook, index)
    if type(hook) ~= "function" then
        return
    end
    if type(index) == "number" and index >= 1 and index <= #ns.OnUpdateHooks + 1 then
        table.insert(ns.OnUpdateHooks, index, hook)
    else
        ns.OnUpdateHooks[#ns.OnUpdateHooks + 1] = hook
    end
end
ns.RegisterOnUpdateHook = RegisterOnUpdateHook
