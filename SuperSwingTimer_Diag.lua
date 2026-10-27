-- ============================================================
-- SuperSwingTimer_Diag.lua
-- Enterprise diagnostics: error capture, compact health report,
-- copyable export, and opt-in per-hook profiling.
--
-- This file is intentionally loaded FIRST (before Constants/State/UI)
-- so /sst diag still works when a later addon file fails to load.
-- It must never depend on anything defined by later SST files at load
-- time. All checks run lazily, inside pcall.
-- ============================================================
local addonName, ns = ...

local rawget = rawget
local type = type
local tostring = tostring
local tonumber = tonumber
local pcall = pcall
local ipairs = ipairs
local pairs = pairs
local table_insert = table.insert
local table_remove = table.remove
local table_concat = table.concat
local string_format = string.format
local string_match = string.match
local math_floor = math.floor
local GetTime = rawget(_G, "GetTime")
local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local GetBuildInfo = rawget(_G, "GetBuildInfo")
local GetFramerate = rawget(_G, "GetFramerate")
local UpdateAddOnMemoryUsage = rawget(_G, "UpdateAddOnMemoryUsage")
local GetAddOnMemoryUsage = rawget(_G, "GetAddOnMemoryUsage")
local UpdateAddOnCPUUsage = rawget(_G, "UpdateAddOnCPUUsage")
local GetAddOnCPUUsage = rawget(_G, "GetAddOnCPUUsage")
local debugstack = rawget(_G, "debugstack")
local debugprofilestart = rawget(_G, "debugprofilestart")
local debugprofilestop = rawget(_G, "debugprofilestop")
local SlashCmdList = rawget(_G, "SlashCmdList")
local CreateFrame = rawget(_G, "CreateFrame")
local UIParent = rawget(_G, "UIParent")
local C_Timer = rawget(_G, "C_Timer")

local D = {}
ns.Diag = D

D.addonName = addonName or "SuperSwingTimer"
D.maxErrors = 40
D.errors = {}
D.errorTotal = 0
D.errorUnique = 0
D.lastErrorAt = nil
D.installed = false
D.fallbackSlashRegistered = false
D.profile = nil

local COLORS = {
    ok = "|cff44ff44",
    warn = "|cffffcc00",
    fail = "|cffff4444",
    info = "|cff888888",
    reset = "|r",
    accent = "|cff00ccff",
}

local STATUS_TAG = {
    ok = COLORS.ok .. "[OK]" .. COLORS.reset,
    warn = COLORS.warn .. "[!!]" .. COLORS.reset,
    fail = COLORS.fail .. "[XX]" .. COLORS.reset,
    skip = COLORS.info .. "[--]" .. COLORS.reset,
}

local function now()
    if GetTime then
        local ok, value = pcall(GetTime)
        if ok and type(value) == "number" then return value end
    end
    if GetTimePreciseSec then
        local ok, value = pcall(GetTimePreciseSec)
        if ok and type(value) == "number" then return value end
    end
    return 0
end

local function safeStack(level)
    if type(debugstack) ~= "function" then return nil end
    local ok, stack = pcall(debugstack, level or 3)
    if ok and type(stack) == "string" then return stack end
    return nil
end
D.Stack = safeStack

local function firstLine(text)
    text = tostring(text or "unknown error")
    return string_match(text, "^[^\n]*") or text
end

local function signatureFor(message, stack)
    -- The first line of a WoW Lua error already contains file:line plus the
    -- failing expression, so it is the most stable dedupe key. Messages that
    -- lack a file:line anchor get the top stack frame appended so two generic
    -- failures at different sites do not collapse into one entry.
    local line = string_match(firstLine(message), "^%s*(.-)%s*$")
    local topFrame = string_match(tostring(stack or ""), "^%s*([^\n]+)")
    if line and line ~= "" and line ~= "unknown error" then
        if line:find("%.lua:%d+") or line:find(":%d+:") then
            return line
        end
        return topFrame and (line .. " @ " .. topFrame) or line
    end
    return topFrame or "unknown error"
end

--- Record one captured error/warning/taint event.
-- Deduplicates by signature so a per-frame failure does not create
-- thousands of entries. The ring buffer keeps the newest 40 signatures.
-- @param message (string) Error text
-- @param stack (string|nil) Stack trace
-- @param source (string|nil) "lua" | "warning" | "taint" | "init" | "slash" | "diag"
-- @return (table) stored entry
local function isAttributed(message, stack, source)
    if source == "init" or source == "slash" or source == "diag" or source == "glow" then
        return true
    end
    if tostring(message or ""):find("SuperSwingTimer", 1, true) then
        return true
    end
    return stack ~= nil and tostring(stack):find("SuperSwingTimer", 1, true) ~= nil
end

function D.Record(message, stack, source)
    local text = tostring(message or "unknown error")
    local sig = signatureFor(text, stack)
    local stamp = now()
    local sourceKey = source or "lua"
    local attributed = isAttributed(text, stack, sourceKey)

    for _, entry in ipairs(D.errors) do
        if entry.signature == sig then
            entry.count = entry.count + 1
            entry.lastSeen = stamp
            entry.attributed = entry.attributed or attributed
            if sourceKey ~= entry.source then
                entry.sources = entry.sources or { [entry.source] = true }
                entry.sources[sourceKey] = true
            end
            D.errorTotal = D.errorTotal + 1
            D.lastErrorAt = stamp
            return entry
        end
    end

    local entry = {
        signature = sig,
        message = text:sub(1, 500),
        stack = stack and tostring(stack):sub(1, 2500) or nil,
        source = sourceKey,
        attributed = attributed,
        count = 1,
        firstSeen = stamp,
        lastSeen = stamp,
    }
    table_insert(D.errors, 1, entry)
    while #D.errors > D.maxErrors do
        -- Keep SST's own errors for longer: evict the oldest external entry
        -- first, then fall back to the oldest entry overall.
        local removed = false
        for index = #D.errors, 1, -1 do
            if not D.errors[index].attributed then
                table_remove(D.errors, index)
                removed = true
                break
            end
        end
        if not removed then
            table_remove(D.errors)
        end
    end
    D.errorTotal = D.errorTotal + 1
    D.errorUnique = D.errorUnique + 1
    D.lastErrorAt = stamp
    if attributed and not D._errorHintShown then
        D._errorHintShown = true
        pcall(D.Print, "error captured. Type |cffffffff/stt diag|r for details.")
    end
    return entry
end

--- Wrap the Blizzard/client error handler so SST can observe errors that
-- reach the top level without replacing the user's normal error display.
-- Safe to call more than once; the first install wins.
function D.Install()
    if D.installed then return true end
    local getHandler = rawget(_G, "geterrorhandler")
    local setHandler = rawget(_G, "seterrorhandler")
    if type(getHandler) ~= "function" or type(setHandler) ~= "function" then
        return false
    end

    local ok, current = pcall(getHandler)
    if not ok or type(current) ~= "function" then
        current = nil
    end

    local function wrapper(message)
        pcall(D.Record, message, safeStack(3), "lua")
        if current then
            pcall(current, message)
        end
    end

    local installedOk = pcall(setHandler, wrapper)
    if not installedOk then return false end
    D.previousHandler = current
    D.wrapper = wrapper
    D.installed = true
    return true
end

local function getMetadata(field)
    local cAddOns = rawget(_G, "C_AddOns")
    if type(cAddOns) == "table" and type(cAddOns.GetAddOnMetadata) == "function" then
        local ok, value = pcall(cAddOns.GetAddOnMetadata, D.addonName, field)
        if ok and value ~= nil then return value end
    end
    local legacy = rawget(_G, "GetAddOnMetadata")
    if type(legacy) == "function" then
        local ok, value = pcall(legacy, D.addonName, field)
        if ok and value ~= nil then return value end
    end
    return nil
end
D.GetMetadata = getMetadata

local function projectName()
    -- Prefer the TOC interface number: Titanforge reuses WOW_PROJECT_CLASSIC
    -- (2), so the project ID alone would mislabel it as Classic Era.
    if type(GetBuildInfo) == "function" then
        local ok, _, _, _, toc = pcall(GetBuildInfo)
        if ok then
            if toc == 11509 then return "Classic Era" end
            if toc == 20506 then return "TBC Anniversary" end
            if toc == 38002 then return "Titanforge" end
        end
    end
    local id = rawget(_G, "WOW_PROJECT_ID")
    local projects = {
        { "WOW_PROJECT_MAINLINE", "Retail" },
        { "WOW_PROJECT_CLASSIC", "Classic Era" },
        { "WOW_PROJECT_BURNING_CRUSADE_CLASSIC", "TBC Anniversary" },
        { "WOW_PROJECT_WRATH_CLASSIC", "Wrath Classic" },
        { "WOW_PROJECT_CATACLYSM_CLASSIC", "Cata Classic" },
        { "WOW_PROJECT_MISTS_CLASSIC", "Mists Classic" },
    }
    for _, project in ipairs(projects) do
        local value = rawget(_G, project[1])
        if value ~= nil and value == id then
            return project[2]
        end
    end
    return id ~= nil and ("project " .. tostring(id)) or "unknown client"
end

local function clientHeader()
    local version, build, _, toc = nil, nil, nil, nil
    if type(GetBuildInfo) == "function" then
        local ok, v, b, _, t = pcall(GetBuildInfo)
        if ok then
            version, build, toc = v, b, t
        end
    end
    local client = projectName()
    local buildText = version and (tostring(version) .. (build and ("." .. tostring(build)) or "")) or "build ?"
    local tocText = toc and (" | toc " .. tostring(toc)) or ""
    return string_format("%s  |  %s%s", buildText, client, tocText)
end

local function addonVersion()
    local version = getMetadata("Version")
    if version and version ~= "" then return tostring(version) end
    return "v?"
end

-- ============================================================
-- Checks
-- Each check returns: status ("ok"|"warn"|"fail"|"skip"), detail
-- ============================================================
local CHECKS = {}
local function addCheck(id, label, run)
    CHECKS[#CHECKS + 1] = { id = id, label = label, run = run }
end

addCheck("client", "client", function()
    local version, build, _, toc = nil, nil, nil, nil
    if type(GetBuildInfo) == "function" then
        local ok, v, b, _, t = pcall(GetBuildInfo)
        if ok then version, build, toc = v, b, t end
    end
    if not version then return "skip", "GetBuildInfo unavailable" end
    return "ok", string_format("%s.%s | %s | toc %s",
        tostring(version), tostring(build or "?"), projectName(), tostring(toc or "?"))
end)

addCheck("addon", "addon", function()
    local version = getMetadata("Version")
    if not version then return "warn", "version metadata unavailable" end
    return "ok", tostring(version)
end)

addCheck("libs", "libs", function()
    local libStub = rawget(_G, "LibStub")
    if libStub == nil then
        return "warn", "LibStub missing (glow disabled)"
    end
    local ok, lib, minor = pcall(libStub, "LibCustomGlow-1.0", true)
    if not ok then return "warn", "LibStub lookup failed" end
    local libStubMinor = (type(libStub) == "table" and libStub.minor) or "?"
    if not lib then
        return "warn", "LibStub " .. tostring(libStubMinor) .. ", LCG missing (fallback)"
    end
    return "ok", string_format("LibStub %s | LCG %s", tostring(libStubMinor), tostring(minor or "?"))
end)

addCheck("db", "db", function()
    local db = rawget(_G, "SuperSwingTimerDB")
    if type(db) ~= "table" then return "fail", "SuperSwingTimerDB missing" end
    local current = ns.DB_CURRENT_VERSION
    local version = tonumber(db.version)
    if not current then return "warn", "DB_CURRENT_VERSION unavailable" end
    if version ~= current then
        return "warn", string_format("db v%s != current v%s", tostring(version), tostring(current))
    end
    return "ok", "v" .. tostring(version)
end)

addCheck("class", "class", function()
    local class = ns.playerClass
    if not class then return "fail", "player class not detected" end
    local cfg = ns.classConfig
    if type(cfg) ~= "table" then return "fail", class .. " has no class config" end
    local bars = 0
    for _, key in ipairs({ "mhBar", "ohBar", "rangedBar", "enemyBar" }) do
        if ns[key] then bars = bars + 1 end
    end
    local hooks = type(ns.OnUpdateHooks) == "table" and #ns.OnUpdateHooks or 0
    return "ok", string_format("%s | %d bars | %d hooks", class, bars, hooks)
end)

addCheck("aura", "aura", function()
    local cUnitAuras = rawget(_G, "C_UnitAuras")
    local modern = type(cUnitAuras) == "table" and type(cUnitAuras.GetAuraDataByIndex) == "function"
    local legacy = type(rawget(_G, "UnitAura")) == "function"
    if not modern and not legacy then return "fail", "no aura API available" end

    local path = modern and "C_UnitAuras" or "UnitAura"
    local elapsedMs = nil
    if modern and type(debugprofilestart) == "function" and type(debugprofilestop) == "function" then
        local ok = pcall(debugprofilestart)
        if ok then
            for _ = 1, 10 do
                pcall(cUnitAuras.GetAuraDataByIndex, "player", 1, "HELPFUL")
            end
            local okStop, ms = pcall(debugprofilestop)
            if okStop and type(ms) == "number" then elapsedMs = ms / 10 end
        end
    end
    if elapsedMs then
        return "ok", string_format("%s | %.3f ms/scan", path, elapsedMs)
    end
    return "ok", path
end)

addCheck("timing", "timing", function()
    local precise = type(GetTimePreciseSec) == "function"
    local aligned = ns.GetAlignedTime
    if type(aligned) ~= "function" then return "fail", "GetAlignedTime missing" end
    local okA, a = pcall(aligned)
    local okB, b = pcall(aligned)
    if not okA or not okB or type(a) ~= "number" or type(b) ~= "number" then
        return "fail", "aligned clock returned non-number"
    end
    if b < a then return "fail", "aligned clock moved backwards" end
    local latencyMs = math_floor((ns.cachedLatency or 0) * 1000 + 0.5)
    return "ok", string_format("%s | offset %.4f | latency %d ms",
        precise and "precise" or "GetTime", ns.preciseClockOffset or 0, latencyMs)
end)

addCheck("events", "events", function()
    local frame = ns.eventFrame
    if not frame or type(frame.IsEventRegistered) ~= "function" then
        return "skip", "event frame not exposed"
    end
    local required = {
        "COMBAT_LOG_EVENT_UNFILTERED",
        "PLAYER_TARGET_CHANGED",
        "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED",
    }
    local missing = {}
    for _, event in ipairs(required) do
        if not frame:IsEventRegistered(event) then
            missing[#missing + 1] = event
        end
    end
    if #missing > 0 then
        return "fail", "missing " .. table_concat(missing, ", ")
    end
    return "ok", string_format("%d/%d core events", #required, #required)
end)

addCheck("render", "render", function()
    local frame = ns.eventFrame
    local loopOn = frame and type(frame.GetScript) == "function" and frame:GetScript("OnUpdate") ~= nil
    local active = type(ns.HasActiveTimers) == "function" and ns.HasActiveTimers() or false
    local hooks = type(ns.OnUpdateHooks) == "table" and #ns.OnUpdateHooks or 0
    local detail = string_format("loop %s | active %s | %d hooks",
        loopOn and "ON" or "off", active and "yes" or "no", hooks)
    if loopOn and not active then
        return "warn", detail .. " | loop on while idle"
    end
    return "ok", detail
end)

addCheck("perf", "perf", function()
    local fps = nil
    if type(GetFramerate) == "function" then
        local ok, value = pcall(GetFramerate)
        if ok then fps = value end
    end
    local memKb = nil
    if type(UpdateAddOnMemoryUsage) == "function" and type(GetAddOnMemoryUsage) == "function" then
        pcall(UpdateAddOnMemoryUsage)
        local ok, value = pcall(GetAddOnMemoryUsage, D.addonName)
        if ok then memKb = value end
    end
    local cpuMs = nil
    if type(UpdateAddOnCPUUsage) == "function" and type(GetAddOnCPUUsage) == "function" then
        pcall(UpdateAddOnCPUUsage)
        local ok, value = pcall(GetAddOnCPUUsage, D.addonName)
        if ok then cpuMs = value end
    end
    local parts = {}
    if fps then parts[#parts + 1] = string_format("fps %d", math_floor(fps + 0.5)) end
    if memKb then parts[#parts + 1] = string_format("mem %d KB", math_floor(memKb + 0.5)) end
    if cpuMs then parts[#parts + 1] = string_format("cpu %.2f ms", cpuMs) end
    if #parts == 0 then return "skip", "performance APIs unavailable" end
    return "ok", table_concat(parts, " | ")
end)

addCheck("glow", "glow", function()
    local glow = ns.Glow
    if type(glow) ~= "table" then return "warn", "glow adapter missing" end
    if not glow.available then
        return "warn", "LibCustomGlow unavailable (fallback active)"
    end
    local required = {
        "ProcGlow_Start", "ProcGlow_Stop",
        "AutoCastGlow_Start", "AutoCastGlow_Stop",
        "ButtonGlow_Start", "ButtonGlow_Stop",
    }
    for _, name in ipairs(required) do
        if type(glow.lib and glow.lib[name]) ~= "function" then
            return "warn", "LibCustomGlow missing " .. name
        end
    end
    if glow.lastError then
        return "warn", "last glow error: " .. tostring(glow.lastError):sub(1, 80)
    end
    return "ok", "LibCustomGlow " .. tostring(glow.minor or "?")
end)

addCheck("sod", "sod", function()
    local tracked = rawget(ns, "SOD_TRACKED_SPELLS")
    if not tracked then return "warn", "SoD module not loaded" end
    if ns.isSoD == true then return "ok", "loaded (active season)" end
    return "ok", "loaded (inactive season)"
end)

addCheck("slash", "slash", function()
    local list = rawget(_G, "SlashCmdList")
    if type(list) ~= "table" or type(list["SUPERSWINGTIMER"]) ~= "function" then
        return "fail", "slash handler missing"
    end
    return "ok", "/sst /super /superswingtimer /swang"
end)

addCheck("errors", "errors", function()
    if #D.errors == 0 then return "ok", "none captured" end
    local sstUnique, sstTotal, externalTotal = 0, 0, 0
    for _, entry in ipairs(D.errors) do
        if entry.attributed then
            sstUnique = sstUnique + 1
            sstTotal = sstTotal + entry.count
        else
            externalTotal = externalTotal + entry.count
        end
    end
    if sstUnique > 0 then
        return "warn", string_format("%d unique / %d total from SST", sstUnique, sstTotal)
    end
    if externalTotal > 0 then
        return "ok", string_format("none from SST (%d external)", externalTotal)
    end
    return "ok", "none captured"
end)

local function runChecks()
    local results = {}
    for _, check in ipairs(CHECKS) do
        local ok, status, detail = pcall(check.run)
        if not ok then
            status, detail = "fail", "check crashed: " .. tostring(status)
        end
        results[#results + 1] = {
            id = check.id,
            label = check.label,
            status = status or "skip",
            detail = detail or "",
        }
    end
    return results
end

local function formatCheck(check)
    return string_format("%s %-8s %s", STATUS_TAG[check.status] or STATUS_TAG.skip,
        check.label or check.id or "?", check.detail or "")
end

local function summaryLine(results)
    local byId = {}
    for _, check in ipairs(results) do byId[check.id] = check end

    local parts = {}
    local db = byId.db
    if db and db.status == "ok" then parts[#parts + 1] = "db " .. db.detail end
    local class = byId["class"]
    if class and class.status == "ok" then
        parts[#parts + 1] = string_match(class.detail, "^%S+") or class.detail
    end
    local perf = byId.perf
    if perf and perf.status == "ok" then parts[#parts + 1] = perf.detail end
    local render = byId.render
    if render and render.status == "ok" then
        local loop = string_match(render.detail, "loop (%S+)") or "?"
        parts[#parts + 1] = "loop " .. loop
    end
    return table_concat(parts, "  |  ")
end

local function errorLine(entry, showExternal)
    local when = tonumber(entry.lastSeen) or 0
    local age = math.max(0, now() - when)
    local ageText = age < 60 and string_format("%ds", math_floor(age + 0.5))
        or string_format("%dm", math_floor(age / 60 + 0.5))
    local tag = (showExternal and not entry.attributed) and (COLORS.info .. "[external]" .. COLORS.reset .. " ") or ""
    local message = firstLine(entry.message)
    if #message > 160 then
        message = message:sub(1, 157) .. "..."
    end
    return string_format("%s%sx%d  %s  (%s ago)", tag, COLORS.fail .. "!" .. COLORS.reset,
        entry.count, message, ageText)
end

--- Build the diagnostic report as text.
-- @param mode (string|nil) "compact" | "full" | "errors"
-- @return (string) report text, (table) lines
function D.BuildReport(mode)
    mode = mode or "compact"
    local results = runChecks()
    local lines = {}

    local function push(line) lines[#lines + 1] = line end

    push(string_format("%sSST diag%s  %s  |  %s", COLORS.accent, COLORS.reset,
        tostring(addonVersion()), clientHeader()))
    push(summaryLine(results))

    if mode == "errors" then
        if #D.errors == 0 then
            push(STATUS_TAG.ok .. " errors    none captured")
        else
            for _, entry in ipairs(D.errors) do
                push(errorLine(entry, true) .. " [" .. tostring(entry.source or "lua") .. "]")
                if entry.stack and entry.stack ~= "" then
                    for stackLine in tostring(entry.stack):gmatch("[^\n]+") do
                        push("    " .. COLORS.info .. stackLine .. COLORS.reset)
                    end
                end
            end
        end
        return table_concat(lines, "\n"), lines
    end

    local shown = 0
    local hidden = 0
    for _, check in ipairs(results) do
        local shouldShow = (mode == "full") or (check.status ~= "ok")
        if shouldShow then
            if mode == "compact" and shown >= 6 then
                hidden = hidden + 1
            else
                push(formatCheck(check))
                shown = shown + 1
            end
        end
    end
    if hidden > 0 then
        push(COLORS.info .. string_format("... %d more (use /stt diag full)", hidden) .. COLORS.reset)
    end

    local attributedErrors, externalTotal = {}, 0
    for _, entry in ipairs(D.errors) do
        if entry.attributed then
            attributedErrors[#attributedErrors + 1] = entry
        else
            externalTotal = externalTotal + entry.count
        end
    end

    local errorList = attributedErrors
    if #errorList > 0 then
        local limit = (mode == "full") and 3 or 2
        for index = 1, math.min(limit, #errorList) do
            push(errorLine(errorList[index], false))
        end
        if #errorList > limit then
            push(COLORS.info .. string_format("... %d more error signature(s) (use /stt diag errors)",
                #errorList - limit) .. COLORS.reset)
        end
    end
    if externalTotal > 0 and mode == "full" then
        push(COLORS.info .. string_format("%d external error(s) from other addons (use /stt diag errors)",
            externalTotal) .. COLORS.reset)
    end

    if mode == "full" then
        push(COLORS.info .. string_format("hooks %d | error buffer %d/%d | db current v%s",
            type(ns.OnUpdateHooks) == "table" and #ns.OnUpdateHooks or 0,
            #D.errors, D.maxErrors, tostring(ns.DB_CURRENT_VERSION or "?")) .. COLORS.reset)
    end

    push(COLORS.info .. "/stt diag full | errors | export | clear | test | profile [sec]" .. COLORS.reset)
    return table_concat(lines, "\n"), lines
end

function D.Print(message)
    print(COLORS.accent .. "SST|r " .. tostring(message))
end

function D.Run(mode)
    local text = D.BuildReport(mode)
    print(text)
end

function D.Clear()
    D.errors = {}
    D.errorTotal = 0
    D.errorUnique = 0
    D.lastErrorAt = nil
    D._errorHintShown = nil
end

-- ============================================================
-- Self-test probes
-- ============================================================
function D.RunTests()
    local probes = {
        {
            name = "clock",
            run = function()
                return type(ns.GetAlignedTime) == "function" and type(ns.GetAlignedTime()) == "number"
            end,
        },
        {
            name = "spell",
            run = function()
                return type(ns.GetSpellInfo) == "function" and ns.GetSpellInfo(75) ~= nil
            end,
        },
        {
            name = "aura",
            run = function()
                if type(ns.UnitAura) ~= "function" then return false end
                ns.UnitAura("player", 1, "HELPFUL")
                return true
            end,
        },
        {
            name = "metadata",
            run = function()
                return getMetadata("Version") ~= nil
            end,
        },
        {
            name = "glow",
            run = function()
                if not (ns.Glow and ns.Glow.available) then return true end
                if type(CreateFrame) ~= "function" or not UIParent then return false end
                ns.Glow.lastError = nil
                local probe = CreateFrame("Frame", nil, UIParent)
                if not probe then return false end
                probe:SetSize(40, 40)
                ns.Glow.SetBar(probe, "selftest", true, { 1, 1, 1, 1 }, "proc")
                ns.Glow.SetBar(probe, "selftest", false)
                probe:Hide()
                return ns.Glow.lastError == nil
            end,
        },
    }

    local passed, failed = 0, 0
    D.Print("self-test")
    for _, probe in ipairs(probes) do
        local ok, result = pcall(probe.run)
        if ok and result then
            passed = passed + 1
            print(string_format("  %s %s", STATUS_TAG.ok, probe.name))
        else
            failed = failed + 1
            print(string_format("  %s %s  %s", STATUS_TAG.fail, probe.name,
                tostring(not ok and result or "returned false")))
        end
    end
    print(string_format("  %s %d passed, %d failed", failed == 0 and STATUS_TAG.ok or STATUS_TAG.warn,
        passed, failed))
end

-- ============================================================
-- Export (copyable EditBox; no file I/O)
-- ============================================================
function D.ShowExport(text)
    if type(CreateFrame) ~= "function" or not UIParent then
        print(text)
        return
    end

    local frame = D.exportFrame or rawget(_G, "SuperSwingTimerDiagExportFrame")
    if not frame then
        frame = CreateFrame("Frame", "SuperSwingTimerDiagExportFrame", UIParent)
        frame:SetSize(660, 440)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:SetToplevel(true)
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.04, 0.04, 0.04, 0.96)

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", frame, "TOP", 0, -12)
        title:SetText("SuperSwingTimer diagnostic report")

        local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
        hint:SetText("Ctrl+A, then Ctrl+C to copy")

        local editBox = CreateFrame("EditBox", nil, frame)
        editBox:SetMultiLine(true)
        editBox:SetSize(620, 350)
        editBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -58)
        editBox:SetAutoFocus(false)
        editBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
        editBox:SetText(text)
        frame.editBox = editBox

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
        frame:SetScript("OnShow", function(self)
            self.editBox:SetFocus()
            self.editBox:HighlightText()
        end)
        D.exportFrame = frame
    else
        frame.editBox:SetText(text)
    end

    frame:Show()
    frame.editBox:SetFocus()
    frame.editBox:HighlightText()
end

function D.Export()
    local full = D.BuildReport("full")
    local errors = D.BuildReport("errors")
    local text = full .. "\n\n" .. errors
    D.ShowExport(text)
end

-- ============================================================
-- Profiler (opt-in, explicit /sst diag profile)
-- ============================================================
local PROFILE_DEFAULT_SECONDS = 10

function D.StartProfile(seconds)
    seconds = tonumber(seconds) or PROFILE_DEFAULT_SECONDS
    if seconds <= 0 then seconds = PROFILE_DEFAULT_SECONDS end
    local startedAt = now()
    D.profile = {
        active = true,
        startedAt = startedAt,
        endsAt = startedAt + seconds,
        seconds = seconds,
        frames = 0,
        hooks = {},
    }
    D.Print(string_format("profiling for %ds... type /sst diag profile again to stop early",
        math_floor(seconds + 0.5)))
    -- Guarantee the profile ends even when the render loop is idle and
    -- TickProfile never runs. startedAt prevents an older timer from
    -- stopping a newer profile.
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(seconds, function()
            local profile = D.profile
            if profile and profile.active and profile.startedAt == startedAt then
                D.StopProfile()
            end
        end)
    end
end

function D.StopProfile()
    local profile = D.profile
    if not profile or not profile.active then return end
    profile.active = false

    local rows = {}
    for index, stats in pairs(profile.hooks) do
        if stats.count > 0 then
            rows[#rows + 1] = {
                index = index,
                name = stats.name or ("hook#" .. tostring(index)),
                total = stats.total,
                count = stats.count,
                max = stats.max,
            }
        end
    end
    table.sort(rows, function(a, b) return a.total > b.total end)

    local totalMs = 0
    for _, row in ipairs(rows) do totalMs = totalMs + row.total end

    D.Print(string_format("profile %.1fs | %d frames | %.2f ms total",
        profile.seconds, profile.frames, totalMs))
    for index = 1, math.min(#rows, 6) do
        local row = rows[index]
        local share = totalMs > 0 and (row.total / totalMs * 100) or 0
        print(string_format("  %-10s %6.3f ms/frame  %5.1f%%  max %.3f",
            row.name:sub(1, 10), row.total / row.count, share, row.max))
    end
    if #rows == 0 then
        print("  " .. STATUS_TAG.info .. " no samples captured")
    end
    print("  " .. COLORS.info .. "tip: run /sst diag profile while actively swinging" .. COLORS.reset)
end

function D.RecordHookTime(index, ms, name)
    local profile = D.profile
    if not profile or not profile.active then return end
    local stats = profile.hooks[index]
    if not stats then
        stats = { total = 0, count = 0, max = 0, name = name }
        profile.hooks[index] = stats
    end
    if name and not stats.name then stats.name = name end
    stats.total = stats.total + ms
    stats.count = stats.count + 1
    if ms > stats.max then stats.max = ms end
end

function D.TickProfile()
    local profile = D.profile
    if not profile or not profile.active then return false end
    profile.frames = profile.frames + 1
    if now() >= profile.endsAt then
        D.StopProfile()
        return false
    end
    return true
end

function D.ToggleProfile(seconds)
    if D.profile and D.profile.active then
        D.StopProfile()
    else
        D.StartProfile(seconds)
    end
end

-- ============================================================
-- Slash integration
-- ============================================================
local function handleSlashInner(text)
    text = tostring(text or ""):lower()
    text = string_match(text, "^%s*(.-)%s*$") or text

    if text == "diag" then
        D.Run("compact")
        return true
    end

    local sub = string_match(text, "^diag%s+(.+)$")
    if not sub then return false end

    sub = string_match(sub, "^%s*(.-)%s*$") or sub
    if sub == "full" then
        D.Run("full")
    elseif sub == "errors" then
        D.Run("errors")
    elseif sub == "export" then
        D.Export()
    elseif sub == "clear" then
        D.Clear()
        D.Print("error buffer cleared.")
    elseif sub == "test" then
        D.RunTests()
    elseif sub == "profile" then
        D.ToggleProfile()
    elseif string_match(sub, "^profile%s+%d+$") then
        local seconds = tonumber(string_match(sub, "(%d+)"))
        D.StartProfile(seconds)
    elseif sub == "help" then
        D.Print("/sst diag [full|errors|export|clear|test|profile [sec]]")
    else
        D.Print("usage: /sst diag [full|errors|export|clear|test|profile [sec]]")
    end
    return true
end

--- Handle the "diag" branch of the /sst command.
-- Returns true when the message was consumed.
function D.HandleSlash(message)
    local ok, handled = pcall(handleSlashInner, message)
    if not ok then
        pcall(D.Record, handled, safeStack(3), "diag")
        D.Print(COLORS.fail .. "diag error:" .. COLORS.reset .. " " .. tostring(handled))
        return true
    end
    return handled == true
end

--- Register a minimal /sst fallback at load so diagnostics remain reachable
-- even if a later SuperSwingTimer file fails. The main file replaces this
-- handler with the full command dispatcher once it loads.
function D.RegisterSlashFallback()
    if D.fallbackSlashRegistered then return end
    if type(SlashCmdList) ~= "table" then return end
    _G.SLASH_SUPERSWINGTIMER1 = "/sst"
    _G.SLASH_SUPERSWINGTIMER2 = "/super"
    _G.SLASH_SUPERSWINGTIMER3 = "/superswingtimer"
    _G.SLASH_SUPERSWINGTIMER4 = "/swang"
    _G.SLASH_SUPERSWINGTIMER5 = "/stt"
    SlashCmdList["SUPERSWINGTIMER"] = function(message)
        if D.HandleSlash(message) then return end
        D.Print("still initializing. Try |cffffffff/stt diag|r.")
    end
    D.fallbackSlashRegistered = true
end

-- ============================================================
-- Event capture: warnings and tainted/blocked actions
-- ============================================================
local eventFrame
local function ensureEventFrame()
    if eventFrame then return eventFrame end
    if type(CreateFrame) ~= "function" or not UIParent then return nil end
    eventFrame = rawget(_G, "SuperSwingTimerDiagFrame")
    if not eventFrame then
        eventFrame = CreateFrame("Frame", "SuperSwingTimerDiagFrame", UIParent)
    end
    eventFrame:RegisterEvent("LUA_WARNING")
    eventFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
    eventFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "LUA_WARNING" then
            local warning = ...
            pcall(D.Record, warning, safeStack(3), "warning")
        elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
            local culprit, action = ...
            local text = string_format("%s: %s (%s)", tostring(event), tostring(action), tostring(culprit))
            pcall(D.Record, text, safeStack(3), "taint")
        elseif event == "PLAYER_ENTERING_WORLD" then
            if not D._loadReported then
                D._loadReported = true
                local sstTotal = 0
                for _, entry in ipairs(D.errors) do
                    if entry.attributed then sstTotal = sstTotal + entry.count end
                end
                if sstTotal > 0 then
                    D.Print(string_format("%d SST error(s) captured since load. Type |cffffffff/stt diag|r.",
                        sstTotal))
                end
            end
            if D._glowRefresh then D._glowRefresh() end
        end
    end)
    return eventFrame
end

-- ============================================================
-- Boot
-- ============================================================
D.Install()
D.RegisterSlashFallback()
ensureEventFrame()

return D
