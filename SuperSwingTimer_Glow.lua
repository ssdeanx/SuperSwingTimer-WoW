-- ============================================================
-- SuperSwingTimer_Glow.lua
-- Thin, lifecycle-safe adapter over LibCustomGlow-1.0.
--
-- Design rules:
--   * If LibCustomGlow is missing, every call is a no-op. The rest of
--     the addon never has to branch on library availability.
--   * Callers may invoke SetBar/SetIcon every frame. Only state
--     transitions touch the library, so there is no per-frame churn.
--   * Every library call is pcall-guarded. A library bug must never
--     break swing rendering; it is recorded for /stt diag instead.
--   * AutoCastGlow/ProcGlow/ButtonGlow only. PixelGlow's "empty" mask asset
--     is not referenced by Classic Era, TBC Anniversary, or Titanforge
--     FrameXML, so it is deliberately not used until a known-good mask ships.
-- ============================================================
local _, ns = ...

local rawget = rawget
local type = type
local pcall = pcall
local pairs = pairs
local setmetatable = setmetatable

local LibStub = rawget(_G, "LibStub")
local LCG, LCGMinor = nil, nil
if LibStub ~= nil then
    local ok, lib, minor = pcall(LibStub, "LibCustomGlow-1.0", true)
    if ok then
        LCG, LCGMinor = lib, minor
    end
end

local Glow = {
    available = LCG ~= nil,
    lib = LCG,
    minor = LCGMinor,
    state = setmetatable({}, { __mode = "k" }),
    icons = setmetatable({}, { __mode = "k" }),
    failedBars = setmetatable({}, { __mode = "k" }),
    failedIcons = setmetatable({}, { __mode = "k" }),
    lastError = nil,
}
ns.Glow = Glow

-- Test seam: lets the headless suite exercise the transition logic
-- without loading the real library (which needs the WoW texture/frame
-- environment).
local function getLib()
    if Glow._testLib then return Glow._testLib end
    if LCG then return LCG end
    -- Defensive: resolve on first use if LibCustomGlow was registered after
    -- this file loaded (load-on-demand library managers, hot reload, tests).
    local libStub = rawget(_G, "LibStub")
    if libStub ~= nil then
        local ok, lib, minor = pcall(libStub, "LibCustomGlow-1.0", true)
        if ok and lib then
            LCG = lib
            Glow.lib = lib
            Glow.minor = minor
            Glow.available = true
            Glow.failedBars = setmetatable({}, { __mode = "k" })
            Glow.failedIcons = setmetatable({}, { __mode = "k" })
        end
    end
    return LCG
end

local function enabled()
    local db = rawget(_G, "SuperSwingTimerDB")
    return not (type(db) == "table" and db.showGlowEffects == false)
end

local function recordError(err)
    Glow.lastError = tostring(err)
    if ns.Diag and ns.Diag.Record then
        pcall(ns.Diag.Record, "Glow: " .. tostring(err), nil, "glow")
    end
end

local function stateFor(frame)
    local state = Glow.state[frame]
    if not state then
        state = {}
        Glow.state[frame] = state
    end
    return state
end

local function startBarGlow(lib, bar, key, style, color)
    if style == "autocast" then
        if type(lib.AutoCastGlow_Start) ~= "function" then
            return false, "AutoCastGlow_Start missing"
        end
        return pcall(lib.AutoCastGlow_Start, bar, color, 2, 0.25, 0.8, 0, 0, key, 8)
    end
    if type(lib.ProcGlow_Start) ~= "function" then
        return false, "ProcGlow_Start missing"
    end
    return pcall(lib.ProcGlow_Start, bar, {
        key = key,
        color = color,
        startAnim = true,
        duration = 0.8,
        frameLevel = 8,
    })
end

local function stopBarGlow(lib, bar, key, style)
    if style == "autocast" then
        if type(lib.AutoCastGlow_Stop) ~= "function" then return true end
        return pcall(lib.AutoCastGlow_Stop, bar, key)
    end
    if type(lib.ProcGlow_Stop) ~= "function" then return true end
    return pcall(lib.ProcGlow_Stop, bar, key)
end

local function stopFrameGlows(frame)
    local state = Glow.state[frame]
    if not state then return end
    local lib = getLib()
    for key, style in pairs(state) do
        if lib then
            local ok, err = stopBarGlow(lib, frame, key, style)
            if not ok then recordError(err) end
        end
    end
    Glow.state[frame] = nil
end

--- Start or stop a keyed glow on a bar/statusbar.
-- Safe to call every frame: only active<->inactive transitions call
-- into LibCustomGlow.
-- @param bar (Frame) Target frame
-- @param key (string) Stable per-feature key (e.g. "jotc", "snd")
-- @param active (boolean) Desired state
-- @param color (table|nil) {r,g,b,a}
-- @param style (string|nil) "autocast" (default, best for thin bars) or "proc"
function Glow.SetBar(bar, key, active, color, style)
    if not bar then return end
    key = key or "default"
    if style ~= "autocast" and style ~= "proc" then
        style = "autocast"
    end

    -- Stop every keyed glow on the bar when the bar itself hides (config
    -- toggle, combat end, minimal mode). Hidden glow frames would otherwise
    -- keep their own OnUpdate running.
    if not bar._sstGlowHooked then
        bar._sstGlowHooked = true
        if type(bar.HookScript) == "function" then
            bar:HookScript("OnHide", function(self)
                stopFrameGlows(self)
            end)
        end
    end

    local state = stateFor(bar)
    local current = state[key]
    local lib = getLib()

    if active and enabled() and lib then
        if current then return end
        local failed = Glow.failedBars[bar]
        if failed and failed[key] then return end
        local ok, err = startBarGlow(lib, bar, key, style, color)
        if ok then
            state[key] = style
        else
            recordError(err)
            failed = failed or {}
            failed[key] = true
            Glow.failedBars[bar] = failed
        end
    elseif current then
        state[key] = nil
        if Glow.failedBars[bar] then Glow.failedBars[bar][key] = nil end
        if lib then
            local ok, err = stopBarGlow(lib, bar, key, current)
            if not ok then recordError(err) end
        end
    end
end

--- Start or stop the standard button/proc glow on an icon frame.
-- ButtonGlow is one-per-frame, so no key is needed.
function Glow.SetIcon(icon, active, color)
    if not icon then return end
    -- Stop the glow automatically whenever the host icon hides (aura expired,
    -- feature toggled off, HUD hidden). This keeps every class's icon loop
    -- clean: no per-class "dropped out of the active set" bookkeeping.
    if not icon._sstGlowHooked then
        icon._sstGlowHooked = true
        if type(icon.HookScript) == "function" then
            icon:HookScript("OnHide", function(self)
                Glow.SetIcon(self, false)
            end)
        end
    end
    local lib = getLib()

    if active and enabled() and lib then
        if Glow.icons[icon] or Glow.failedIcons[icon] then return end
        if type(lib.ButtonGlow_Start) ~= "function" then
            recordError("ButtonGlow_Start missing")
            Glow.failedIcons[icon] = true
            return
        end
        local ok, err = pcall(lib.ButtonGlow_Start, icon, color, 0.25, 8)
        if ok then
            Glow.icons[icon] = true
        else
            recordError(err)
            Glow.failedIcons[icon] = true
        end
    elseif Glow.icons[icon] then
        Glow.icons[icon] = nil
        if lib and type(lib.ButtonGlow_Stop) == "function" then
            local ok, err = pcall(lib.ButtonGlow_Stop, icon)
            if not ok then recordError(err) end
        end
    end
end

--- Stop every tracked glow. Call before re-initializing class modules or
-- when the visual-effects toggle is switched off.
function Glow.StopAll()
    local lib = getLib()
    for frame in pairs(Glow.state) do
        stopFrameGlows(frame)
    end
    Glow.failedBars = setmetatable({}, { __mode = "k" })
    for icon in pairs(Glow.icons) do
        if lib and type(lib.ButtonGlow_Stop) == "function" then
            local ok, err = pcall(lib.ButtonGlow_Stop, icon)
            if not ok then recordError(err) end
        end
        Glow.icons[icon] = nil
    end
    Glow.failedIcons = setmetatable({}, { __mode = "k" })
end

--- Re-apply the user's visual-effects preference.
-- Also clears failure latches so toggling the feature re-attempts once.
function Glow.Refresh()
    Glow.failedBars = setmetatable({}, { __mode = "k" })
    Glow.failedIcons = setmetatable({}, { __mode = "k" })
    Glow.lastError = nil
    if not enabled() then
        Glow.StopAll()
    end
end

function Glow.IsEnabled()
    return enabled()
end

-- Let the diagnostics event frame refresh glows after PLAYER_ENTERING_WORLD
-- (for example when SavedVariables arrive before the class modules finish).
if ns.Diag then
    ns.Diag._glowRefresh = Glow.Refresh
end

return Glow
