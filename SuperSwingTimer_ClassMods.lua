local _, ns = ...
---@diagnostic disable: undefined-field
local CreateFrame = rawget(_G, "CreateFrame")
local UIParent = rawget(_G, "UIParent")
local UnitAura = rawget(_G, "UnitAura")
local UnitBuff = rawget(_G, "UnitBuff")
local UnitPower = rawget(_G, "UnitPower")
local UnitPowerType = rawget(_G, "UnitPowerType")
local UnitExists = rawget(_G, "UnitExists")
local UnitCanAttack = rawget(_G, "UnitCanAttack")
local UnitIsDead = rawget(_G, "UnitIsDead")
local UnitAttackSpeed = rawget(_G, "UnitAttackSpeed")
local IsSpellInRange = rawget(_G, "IsSpellInRange")
local SpellHasRange = rawget(_G, "SpellHasRange")
local CheckInteractDistance = rawget(_G, "CheckInteractDistance")
local GetSpellTexture = rawget(_G, "GetSpellTexture")
local InCombatLockdown = rawget(_G, "InCombatLockdown")
local GetSpecialization = rawget(_G, "GetSpecialization")
local GetNumTalentTabs = rawget(_G, "GetNumTalentTabs")
local GetTalentTabInfo = rawget(_G, "GetTalentTabInfo")
local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local GetTime = rawget(_G, "GetTime")
local GetSpellCooldown = rawget(_G, "GetSpellCooldown")
local C_Spell = rawget(_G, "C_Spell")
local pcall = pcall
local GCD_SPELL_ID = 61304 -- Spell ID used to query the GCD for seal twist timing.
local WARRIOR_HEROIC_STRIKE_TINT = { r = 1.0, g = 0.92, b = 0.20 }
local WARRIOR_CLEAVE_TINT = { r = 0.20, g = 0.80, b = 0.25 }
local DRUID_MAUL_TINT = { r = 1.0, g = 0.78, b = 0.10 }
local HUNTER_RAPTOR_TINT = { r = 1.0, g = 0.92, b = 0.20 }

-- Shared Flurry buff lookup tables (used by both Warrior and Shaman code paths)
local FLURRY_BUFF_NAMES = { "Flurry" }
local FLURRY_BUFF_NAME_LOOKUP = {}

-- Helper: compute buff icon Y offset above all visible target debuff duration bars.
-- bars = ordered list of bar references (may be nil). Queries each bar's actual
-- screen position so the calculation is always correct regardless of SetPoint offsets.
-- referenceBar = the main bar to use as origin (e.g. ns.mhBar for melee, ns.rangedBar for hunter).
-- Returns a BOTTOM-to-referenceBar.TOP Y offset for SetPoint.
-- Uses a visibility-bitmask cache to avoid one-frame bounce from WoW's deferred
-- SetPoint layout: GetTop() is stale in the frame where a bar is shown/hidden.
local _debuffStackCache = nil
local _debuffStackCacheBars = nil
local function GetDebuffStackOffset(bars, referenceBar)
    if not referenceBar then return 11 end
    local refTop = type(referenceBar.GetTop) == "function" and referenceBar:GetTop() or 0
    if not refTop or refTop == 0 then return 11 end
    -- Compute visibility bitmask to detect bar-set changes
    local visMask = 0
    for i, bar in ipairs(bars or {}) do
        if bar then
            visMask = visMask + ((bar.IsShown and bar:IsShown()) and (2 ^ (i - 1)) or 0)
        end
    end
    -- Use cached offset if the visible bar set hasn't changed
    if _debuffStackCache and _debuffStackCacheBars == visMask then
        return _debuffStackCache
    end
    -- Track the highest bar's top edge (most negative offset from refTop).
    -- RestackDebuffBars stacks bars below refTop, so their tops extend above
    -- refTop (negative offset). The MOST negative offset = the HIGHEST bar.
    local minBarTop = 0
    for _, bar in ipairs(bars or {}) do
        if bar and bar.IsShown and bar:IsShown() then
            local barTop = type(bar.GetTop) == "function" and bar:GetTop()
            if barTop then
                local offset = barTop - refTop
                if offset < minBarTop then
                    minBarTop = offset
                end
            end
        end
    end
    local result = minBarTop - 16  -- 16px gap above the highest visible bar
    _debuffStackCache = result
    _debuffStackCacheBars = visMask
    return result
end

-- Universal debuff bar restacker: positions visible bars in order above referenceBar.
-- Accepts an ordered table of bar references (bottom to top stacking order).
-- Removes old anchor points and re-stacks with (gap)px spacing between bars.
-- Returns the Y offset (relative to referenceBar:GetTop()) for placing buff icons above all bars.
-- Handles nil/invalid/hidden bars gracefully — never errors.
-- referenceBar = the main bar to stack above (typically ns.mhBar)
-- gap = pixels between stacked bars and above the top bar (default 2)
local function RestackDebuffBars(barList, referenceBar, gap)
    if not referenceBar then return 2 end
    if type(referenceBar.GetAlpha) == "function" and (referenceBar:GetAlpha() or 0) <= 0 then
        return 2
    end
    gap = gap or 2
    local currentY = gap
    local hasAny = false
    for _, bar in ipairs(barList) do
        if bar and bar.IsShown and bar:IsShown() then
            local h = (bar.GetHeight and bar:GetHeight()) or 6
            if type(h) ~= "number" then h = 6 end
            bar:ClearAllPoints()
            bar:SetPoint("BOTTOMLEFT", referenceBar, "TOPLEFT", 0, currentY)
            bar:SetPoint("BOTTOMRIGHT", referenceBar, "TOPRIGHT", 0, currentY)
            currentY = currentY + h + gap
            hasAny = true
        end
    end
    if not hasAny then return gap end
    return currentY
end

-- Returns the best reference bar for stacking target debuff bars and buff icons.
-- For Hunters: prefers MH bar when visible, falls back to ranged bar.
-- For all other classes: always returns MH bar.
-- This is deliberately a closure, not on ns.*, to keep it private.
local function GetDebuffAnchorBar()
    if ns.playerClass == "HUNTER" then
        if ns.mhBar and ns.mhBar.IsShown and ns.mhBar:IsShown()
            and ns.mhBar.GetAlpha and (ns.mhBar:GetAlpha() or 0) > 0 then
            return ns.mhBar
        end
        if ns.rangedBar and ns.rangedBar.GetAlpha and (ns.rangedBar:GetAlpha() or 0) > 0 then
            return ns.rangedBar
        end
        return ns.rangedBar or ns.mhBar
    end
    return ns.mhBar
end

for _, flurryName in ipairs(FLURRY_BUFF_NAMES) do
    FLURRY_BUFF_NAME_LOOKUP[flurryName] = true
end
local FLURRY_BUFF_SPELL_IDS = {
    [12319] = true, -- Flurry (all ranks)
    [16280] = true  -- Flurry (rank 4+)
}

-- Returns: charges (number or nil), expirationTime (number or nil)
-- Handles both TBC Anniversary (2.5.5) and older Classic UnitBuff payload shapes.
-- Dispatch logic matches GetHelpfulAuraData() in this file.
local function GetFlurryBuffInfo()
    if not UnitBuff then
        return nil, nil
    end

    for i = 1, 40 do
        local name, _, _, auraCount, _, a6, a7, _, _, a10, a11 = UnitBuff("player", i)
        if not name then
            break
        end

        local expirationTime
        local spellId
        if type(a10) == "number" then
            -- TBC Anniversary (2.5.5) shape: expiration = a6, spellId = a10
            expirationTime = a6
            spellId = a10
        else
            -- Older Classic shape: expiration = a7, spellId = a11
            expirationTime = a7
            spellId = type(a11) == "number" and a11 or nil
        end

        if FLURRY_BUFF_NAME_LOOKUP[name] or (type(spellId) == "number" and FLURRY_BUFF_SPELL_IDS[spellId]) then
            local charges = math.min(math.max(tonumber(auraCount) or 1, 1), 3)
            return charges, expirationTime
        end
    end
    return nil, nil
end

-- Creates a 30x30 Flurry icon frame (texture + stack count + duration timer).
-- Parented to UIParent with DIALOG strata so it renders above all bars.
-- Returns the frame (hidden). Caller must anchor and call Show/Hide per update.
local function CreateFlurryIconFrame()
    local icon = CreateFrame("Frame", nil, UIParent)
    icon:SetSize(30, 30)
    icon:SetFrameStrata("DIALOG")
    icon:EnableMouse(false)

    -- Spell texture
    icon.texture = icon:CreateTexture(nil, "BACKGROUND")
    icon.texture:SetAllPoints()
    local texturePath = GetSpellTexture and GetSpellTexture(12319) or "Interface\\Icons\\Ability_Warrior_FocusedRage"
    icon.texture:SetTexture(texturePath)

    -- 4-edge outline border (not a full-face overlay)
    icon.border = {}
    icon.border.top = icon:CreateTexture(nil, "OVERLAY")
    icon.border.top:SetDrawLayer("OVERLAY", -1)
    icon.border.top:SetPoint("TOPLEFT", -1, 1)
    icon.border.top:SetPoint("TOPRIGHT", 1, 1)
    icon.border.top:SetHeight(1)
    icon.border.top:SetColorTexture(0, 0, 0, 0.65)
    icon.border.bottom = icon:CreateTexture(nil, "OVERLAY")
    icon.border.bottom:SetDrawLayer("OVERLAY", -1)
    icon.border.bottom:SetPoint("BOTTOMLEFT", -1, -1)
    icon.border.bottom:SetPoint("BOTTOMRIGHT", 1, -1)
    icon.border.bottom:SetHeight(1)
    icon.border.bottom:SetColorTexture(0, 0, 0, 0.65)
    icon.border.left = icon:CreateTexture(nil, "OVERLAY")
    icon.border.left:SetDrawLayer("OVERLAY", -1)
    icon.border.left:SetPoint("TOPLEFT", -1, 1)
    icon.border.left:SetPoint("BOTTOMLEFT", -1, -1)
    icon.border.left:SetWidth(1)
    icon.border.left:SetColorTexture(0, 0, 0, 0.65)
    icon.border.right = icon:CreateTexture(nil, "OVERLAY")
    icon.border.right:SetDrawLayer("OVERLAY", -1)
    icon.border.right:SetPoint("TOPRIGHT", 1, 1)
    icon.border.right:SetPoint("BOTTOMRIGHT", 1, -1)
    icon.border.right:SetWidth(1)
    icon.border.right:SetColorTexture(0, 0, 0, 0.65)

    -- Stack count (bottom-right, overlaid on the icon)
    icon.stackText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icon.stackText:SetPoint("BOTTOMRIGHT", 1, 0)
    icon.stackText:SetJustifyH("RIGHT")
    icon.stackText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    icon.stackText:SetTextColor(1, 0.82, 0, 1)

    -- Duration text (below icon, centered)
    icon.durationText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icon.durationText:SetPoint("TOP", icon, "BOTTOM", 0, -2)
    icon.durationText:SetJustifyH("CENTER")
    icon.durationText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    icon.durationText:SetTextColor(0.75, 0.75, 0.75, 0.9)

    icon:Hide()
    return icon
end

local function GetCurrentTime()
    if ns.GetAlignedTime then
        return ns.GetAlignedTime()
    end
    if GetTimePreciseSec then
        return GetTimePreciseSec()
    end

    return GetTime()
end

local function QuerySpellCooldown(spellToken)
    local startTime
    local duration
    local enabled

    if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
        local ok, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellToken)
        if ok and type(cooldownInfo) == "table" then
            startTime = tonumber(cooldownInfo.startTime or cooldownInfo.start_time)
            duration = tonumber(cooldownInfo.duration)
            enabled = cooldownInfo.isEnabled
            if enabled == nil then
                enabled = cooldownInfo.enabled
            end
        end
    end

    if (not duration or duration <= 0) and type(GetSpellCooldown) == "function" then
        startTime, duration, enabled = GetSpellCooldown(spellToken)
    end

    local isEnabled = enabled == nil or enabled == 1 or enabled == true
    if not isEnabled or type(startTime) ~= "number" or type(duration) ~= "number" or duration <= 0 then
        return nil, nil
    end

    return startTime, duration
end

local function GetOverlayParent(bar)
    if ns.GetOverlayFrame then
        return ns.GetOverlayFrame(bar)
    end
    return bar
end

local function GetHelpfulAuraData(unit, index)
    if not unit or not index then return nil end
    local name, _, _, _, _, dur, expT, _, _, _, sId = ns.UnitBuff(unit, index)
    if not name then return nil end
    return name, dur, expT, sId
end

local function GetHarmfulAuraData(unit, index, filter)
    if not unit or not index then return nil end
    local name, _, _, count, _, dur, expT, caster, _, _, sId = ns.UnitAura(unit, index, filter or "HARMFUL")
    if not name then return nil end
    return name, count or 0, dur, expT, caster, sId
end

local function EnsureVerticalHelperBar(frameName, anchorBar, width, texturePath)
    local bar = rawget(_G, frameName)
    if not bar then
        bar = CreateFrame("StatusBar", frameName, UIParent)
    end

    local baseBar = anchorBar or ns.mhBar or ns.rangedBar
    local resolvedTexture = texturePath or (ns.GetBarTexture and ns.GetBarTexture())
        or "Interface\\TargetingFrame\\UI-StatusBar"
    bar:SetStatusBarTexture(resolvedTexture)
    if bar.SetOrientation then
        bar:SetOrientation("VERTICAL")
    end
    if bar.SetReverseFill then
        bar:SetReverseFill(false)
    end
    bar:SetSize(width, (baseBar and baseBar:GetHeight()) or ns.BAR_HEIGHT or 15)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetFrameStrata((baseBar and baseBar:GetFrameStrata()) or "MEDIUM")
    bar:SetFrameLevel(((baseBar and baseBar:GetFrameLevel()) or 0) + 1)
    bar:EnableMouse(false)

    local statusBarTexture = bar:GetStatusBarTexture()
    if statusBarTexture then
        statusBarTexture:SetDrawLayer(ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK")
    end

    local backgroundTexture = bar.backgroundTexture or bar:CreateTexture(nil, "BACKGROUND")
    backgroundTexture:SetAllPoints(true)
    local backgroundColor = ns.GetBarBackgroundColor and ns.GetBarBackgroundColor()
        or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBackgroundColor)
    backgroundColor = backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
    backgroundTexture:SetColorTexture(backgroundColor.r or 0, backgroundColor.g or 0, backgroundColor.b or 0, 1)
    backgroundTexture:SetAlpha(backgroundColor.a ~= nil and backgroundColor.a or 0.5)

    if not bar.borderTextures then
        local borderColor = ns.GetBarBorderColor and ns.GetBarBorderColor()
            or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBorderColor)
        borderColor = borderColor or { r = 0, g = 0, b = 0, a = 1 }
        local borderTop = bar:CreateTexture(nil, "OVERLAY")
        borderTop:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
        borderTop:SetPoint("TOPLEFT", -1, 1)
        borderTop:SetPoint("TOPRIGHT", 1, 1)
        borderTop:SetHeight(1)

        local borderBottom = bar:CreateTexture(nil, "OVERLAY")
        borderBottom:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
        borderBottom:SetPoint("BOTTOMLEFT", -1, -1)
        borderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
        borderBottom:SetHeight(1)

        local borderLeft = bar:CreateTexture(nil, "OVERLAY")
        borderLeft:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
        borderLeft:SetPoint("TOPLEFT", -1, 1)
        borderLeft:SetPoint("BOTTOMLEFT", -1, -1)
        borderLeft:SetWidth(1)

        local borderRight = bar:CreateTexture(nil, "OVERLAY")
        borderRight:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
        borderRight:SetPoint("TOPRIGHT", 1, 1)
        borderRight:SetPoint("BOTTOMRIGHT", 1, -1)
        borderRight:SetWidth(1)

        bar.borderTextures = { top = borderTop, bottom = borderBottom, left = borderLeft, right = borderRight }
    end

    bar.backgroundTexture = backgroundTexture
    bar.statusBarTexture = statusBarTexture
    bar:SetAlpha(0)
    return bar
end

-- ============================================================
-- Class-specific visual overlays and behavior hooks.
-- Each class mod sets callbacks on ns (OnMeleeSwing, OnRangedSwing,
-- OnBarsCreated, OnDruidFormChange) as needed.
-- ============================================================

local function SetupRetPaladin()
    local function GetActivePaladinSeal()
        if not UnitAura then
            return nil
        end

        for index = 1, 40 do
            local auraName, _, _, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then
                break
            end

            local familyKey = ns.GetPaladinSealFamilyByAuraName and ns.GetPaladinSealFamilyByAuraName(auraName) or nil
            if not familyKey and ns.GetPaladinSealFamilyBySpellId then
                familyKey = ns.GetPaladinSealFamilyBySpellId(auraSpellId)
            end

            if familyKey then
                return familyKey, auraSpellId, auraName
            end
        end

        return nil
    end

    local PALADIN_TWIST_WINDOW = 0.4 -- seconds before swing landing for the seal twist window

    local function GetPerSealColor(familyKey)
        if not familyKey or not SuperSwingTimerDB or not SuperSwingTimerDB.colors then
            return nil
        end
        local colorKey = "sealColor" .. familyKey
        local color = SuperSwingTimerDB.colors[colorKey]
        if color and color.r ~= nil then
            return color
        end
        -- Fall back to static defaults
        local static = ns.PALADIN_SEAL_COLORS and ns.PALADIN_SEAL_COLORS[familyKey]
        return static
    end

    local function UpdateSealColorAndLabel()
        if not ns.mhBar then
            return
        end
        local activeFamily, _, activeName = GetActivePaladinSeal()
        local showSealColor = SuperSwingTimerDB and SuperSwingTimerDB.showPaladinSealColor ~= false

        if activeFamily and showSealColor then
            local classColorsOn = SuperSwingTimerDB and SuperSwingTimerDB.useClassColors == true
            if not classColorsOn then
                local sealColor = GetPerSealColor(activeFamily)
                if sealColor then
                    local alpha = (ns.mhBarBaseColor and ns.mhBarBaseColor.a) or 1
                    ns.mhBar:SetStatusBarColor(sealColor.r, sealColor.g, sealColor.b, alpha)
                end
                ns.paladinLastSealColor = true
                -- Update seal label on MH bar (controlled by its own toggle)
                local showSealLabel = SuperSwingTimerDB and SuperSwingTimerDB.showPaladinSealLabel ~= false
                if showSealLabel then
                    local labelText = activeName or activeFamily
                    ns.SetBarLabelText(ns.mhBar, labelText, true)
                end
            end
        else
            -- No seal active: restore default color if we changed it
            if ns.paladinLastSealColor then
                ns.paladinLastSealColor = nil
                if ns.RestoreMainHandColor then
                    ns.RestoreMainHandColor()
                elseif ns.mhBarBaseColor then
                    local c = ns.mhBarBaseColor
                    ns.mhBar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
                elseif ns.GetBarColor then
                    local c = ns.GetBarColor("mh")
                    if c then
                        ns.mhBar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
                    end
                end
            end
            -- Restore default MH label
            if ns.RestoreBarDefaultLabel then
                ns.RestoreBarDefaultLabel(ns.mhBar)
            end
        end
    end

    -- Paladin seal-based MH bar color override (called from UpdateSealColorAndLabel + ApplyBarColors)
    ns.UpdatePaladinSealVisual = UpdateSealColorAndLabel

    local function UpdateSealBreakpointLine()
        local sealZone = ns.sealTwistBreakpoint
        local sealResealLine = ns.sealTwistResealBreakpoint
        local activeFamily = GetActivePaladinSeal()
        if not sealZone or not ns.mhBar then
            return
        end

        -- Preview fallback matching Rogue Sinister Strike pattern:
        -- show the zone during Test Bars even without an active swing timer.
        local previewActive = ns.barTestActive == true
        local timer = ns.timers and ns.timers.mh
        local activeSwing = timer and timer.state == "swinging" and timer.duration and timer.duration > 0

        if not activeSwing and not previewActive then
            sealZone:Hide()
            if sealResealLine then
                sealResealLine:Hide()
            end
            return
        end

        if not activeFamily or not ns.PALADIN_SEAL_TWIST_FAMILIES or not ns.PALADIN_SEAL_TWIST_FAMILIES[activeFamily] then
            sealZone:Hide()
            if sealResealLine then
                sealResealLine:Hide()
            end
            return
        end

        local barWidth = (ns.mhBar and ns.mhBar:GetWidth()) or (ns.mhBar and ns.mhBar.barWidth) or ns.BAR_WIDTH or 0
        if barWidth <= 0 then
            sealZone:Hide()
            if sealResealLine then
                sealResealLine:Hide()
            end
            return
        end

        -- Resolve duration and lastSwing — real timer when swinging, preview fallback when testing
        local now = GetCurrentTime()
        local duration
        local lastSwing
        if activeSwing then
            duration = timer.duration
            lastSwing = timer.lastSwing
        else
            local mainHandSpeed = type(UnitAttackSpeed) == "function" and UnitAttackSpeed("player") or nil
            duration = (type(mainHandSpeed) == "number" and mainHandSpeed > 0) and mainHandSpeed or (timer and timer.duration
                    and timer.duration > 0 and timer.duration) or 2.0
            -- Simulate swing starting ~1s ago so the zone is positioned mid-swing
            lastSwing = now - 1.0
        end

        if not duration or duration <= 0 then
            sealZone:Hide()
            if sealResealLine then
                sealResealLine:Hide()
            end
            return
        end

        -- Calculate twist zone width proportional to the end-of-swing window
        local twistWindow = PALADIN_TWIST_WINDOW + math.max(ns.cachedLatency or 0, 0)
        local zoneWidth = math.min(math.max((twistWindow / duration) * barWidth, 1), barWidth * 0.5)

        local barAnchor = GetOverlayParent(ns.mhBar)
        sealZone:ClearAllPoints()
        sealZone:SetPoint("TOPRIGHT", barAnchor, "TOPRIGHT", 0, 0)
        sealZone:SetPoint("BOTTOMRIGHT", barAnchor, "BOTTOMRIGHT", 0, 0)
        sealZone:SetWidth(zoneWidth)
        sealZone:Show()

        -- Reseal marker: a GCD-aware line (now 3px wide for better visibility)
        if not sealResealLine then
            return
        end

        local gcdStart, gcdDuration = QuerySpellCooldown(GCD_SPELL_ID)
        if type(gcdStart) ~= "number" or type(gcdDuration) ~= "number" or gcdDuration <= 0 then
            sealResealLine:Hide()
            return
        end

        local gcdRemaining = (gcdStart + gcdDuration) - now
        if gcdRemaining <= 0 then
            sealResealLine:Hide()
            return
        end

        local swingElapsed = math.max(0, now - (lastSwing or now))
        local resealTick = (swingElapsed + gcdRemaining) / duration
        while resealTick > 1 do
            resealTick = resealTick - 1
        end
        if resealTick < 0 then
            resealTick = 0
        elseif resealTick > 1 then
            resealTick = 1
        end
        local resealLineWidth = math.min(3, barWidth) -- 3px for better visibility
        local resealX = math.max(
            math.min((barWidth * resealTick) - (resealLineWidth * 0.5), barWidth - resealLineWidth), 0
        )

        sealResealLine:ClearAllPoints()
        sealResealLine:SetPoint("TOPLEFT", barAnchor, "LEFT", resealX, 0)
        sealResealLine:SetPoint("BOTTOMLEFT", barAnchor, "LEFT", resealX, 0)
        sealResealLine:SetWidth(resealLineWidth)
        sealResealLine:Show()
    end

    -- Judgement cooldown marker
    local function UpdateJudgementMarker()
        local jgMarker = ns.paladinJudgementMarker
        if not jgMarker or not ns.mhBar then
            return
        end

        local showJgMarker = SuperSwingTimerDB and SuperSwingTimerDB.showPaladinJudgementMarker ~= false
        if not showJgMarker then
            jgMarker:Hide()
            return
        end

        -- Preview fallback matching the twist zone + Rogue pattern
        local previewActive = ns.barTestActive == true
        local timer = ns.timers and ns.timers.mh
        local activeSwing = timer and timer.state == "swinging" and timer.duration and timer.duration > 0

        if not activeSwing and not previewActive then
            jgMarker:Hide()
            return
        end

        -- Read the first available Judgement spell cooldown
        local jgStart, jgDuration
        if ns.PALADIN_JUDGEMENT_SPELLS then
            for id in pairs(ns.PALADIN_JUDGEMENT_SPELLS) do
                jgStart, jgDuration = QuerySpellCooldown(id)
                if type(jgStart) == "number" and type(jgDuration) == "number" and jgDuration > 0 then
                    break
                end
            end
        end

        local now = GetCurrentTime()
        local jgRemaining
        if type(jgStart) == "number" and type(jgDuration) == "number" and jgDuration > 0 then
            jgRemaining = (jgStart + jgDuration) - now
        end

        local barWidth = (ns.mhBar and ns.mhBar:GetWidth()) or (ns.mhBar and ns.mhBar.barWidth) or ns.BAR_WIDTH or 0
        if barWidth <= 0 then
            jgMarker:Hide()
            return
        end

        -- Resolve duration and lastSwing
        local duration
        local lastSwing
        if activeSwing then
            duration = timer.duration
            lastSwing = timer.lastSwing
        else
            local mainHandSpeed = type(UnitAttackSpeed) == "function" and UnitAttackSpeed("player") or nil
            duration = (type(mainHandSpeed) == "number" and mainHandSpeed > 0) and mainHandSpeed or (timer and timer.duration
                    and timer.duration > 0 and timer.duration) or 2.0
            lastSwing = now - 0.5
            -- Preview: if no real judgement CD, simulate one at the 75% position
            if not jgRemaining or jgRemaining <= 0 then
                jgRemaining = duration * 0.75
            end
        end

        if not duration or duration <= 0 then
            jgMarker:Hide()
            return
        end

        if not jgRemaining or jgRemaining <= 0 then
            jgMarker:Hide()
            return
        end

        local swingElapsed = math.max(0, now - (lastSwing or now))
        -- Position the marker where the swing will be when Judgement CD comes back
        local jgTick = (swingElapsed + jgRemaining) / duration
        while jgTick > 1 do
            jgTick = jgTick - 1
        end
        jgTick = math.max(0, math.min(1, jgTick))

        local markerWidth = math.min(4, barWidth)
        local markerX = math.max(math.min((barWidth * jgTick) - (markerWidth * 0.5), barWidth - markerWidth), 0)

        local barAnchor = GetOverlayParent(ns.mhBar)
        jgMarker:ClearAllPoints()
        jgMarker:SetPoint("TOPLEFT", barAnchor, "LEFT", markerX, 0)
        jgMarker:SetPoint("BOTTOMLEFT", barAnchor, "LEFT", markerX, 0)
        jgMarker:SetWidth(markerWidth)
        jgMarker:Show()
    end

    local function GetReckoningStackCount()
        if not UnitBuff then
            return nil
        end

        local reckoningName = ns.GetSpellInfo and (ns.GetSpellInfo(20178) or "Reckoning") or "Reckoning"
        for index = 1, 40 do
            local auraName, _, _, auraCount, _, _, _, _, _, _, auraSpellId = UnitBuff("player", index)
            if not auraName then
                break
            end

            if auraName == reckoningName or auraSpellId == 20178 then
                return math.max(tonumber(auraCount) or 1, 1)
            end
        end

        return nil
    end

    local function UpdateReckoningBadge()
        if not ns.mhBar then
            return
        end

        local reckoningText = ns.mhBar.reckoningText
        if not reckoningText then
            reckoningText = ns.mhBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            reckoningText:SetPoint("LEFT", ns.mhBar, "RIGHT", 3, 0)
            reckoningText:SetJustifyH("LEFT")
            reckoningText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            reckoningText:SetTextColor(1.0, 0.84, 0.0, 0.95)
            ns.mhBar.reckoningText = reckoningText
        end

        local count = GetReckoningStackCount()
        if not count then
            reckoningText:Hide()
            return
        end

        reckoningText:SetText("R" .. tostring(count))
        reckoningText:Show()
    end

    local PALADIN_LIBRAM_SWAP_DURATION = 1.5
    local function UpdatePaladinLibramSwapBadge()
        if not ns.mhBar then
            return
        end

        local libramText = ns.mhBar.paladinLibramText
        if not libramText then
            libramText = ns.mhBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            libramText:SetPoint("TOPLEFT", ns.mhBar, "TOPRIGHT", 3, -18)
            libramText:SetJustifyH("LEFT")
            libramText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            libramText:SetTextColor(0.95, 0.85, 0.25, 0.95)
            ns.mhBar.paladinLibramText = libramText
        end

        local currentItemId = GetInventoryItemID and GetInventoryItemID("player", 18) or nil
        if ns.paladinLibramLastItemId == nil then
            ns.paladinLibramLastItemId = currentItemId
        end
        if currentItemId ~= ns.paladinLibramLastItemId then
            ns.paladinLibramLastItemId = currentItemId
            ns.paladinLibramSwapStartTime = GetCurrentTime()
        end

        local swapStart = ns.paladinLibramSwapStartTime
        if not swapStart then
            libramText:Hide()
            return
        end

        local elapsed = GetCurrentTime() - swapStart
        local remaining = PALADIN_LIBRAM_SWAP_DURATION - elapsed
        if remaining <= 0 then
            libramText:Hide()
            return
        end

        libramText:SetText(string.format("LIB %.1fs", remaining))
        libramText:Show()
    end

    ns.HandlePaladinLibramEquipmentChanged = function (slot)
        if slot ~= 18 then
            return
        end
        ns.paladinLibramSwapStartTime = GetCurrentTime()
        ns.paladinLibramLastItemId = GetInventoryItemID and GetInventoryItemID("player", 18) or nil
    end

    -- Twist success detection
    local function CheckTwistSuccess()
        if ns.playerClass ~= "PALADIN" then
            return
        end
        if SuperSwingTimerDB and SuperSwingTimerDB.showPaladinTwistFlash == false then
            return
        end

        -- On each swing landed, check if we successfully twisted
        -- We track the previous seal family when a swing completes
        -- If the seal changed during the swing, and both are twist families, it's a success
        -- For now this is a read-only detection that stores the result for visual feedback
    end

    -- Expose the seal breakpoint-line update so ApplyBarColors (UI.lua) can call it
    -- directly, matching the Rogue Sinister Strike pattern (ns.UpdateRogueSinisterAssistVisual).
    ns.UpdatePaladinSealZone = UpdateSealBreakpointLine

    -- Seal twist zone: proportional-width filled zone at the RIGHT edge of the MH bar,
    -- showing the latency-aware end-of-swing window for seal twisting.
    -- Keeps a separate thin reseal marker at the GCD-based position.
    -- NEW: Adds per-seal color, seal label, and Judgement marker.
    ns.OnBarsCreated = function ()
        if not ns.mhBar then return end

        local barParent = GetOverlayParent(ns.mhBar)

        -- Twist zone: red right-end fill matching Rogue Sinister Strike pattern.
        -- Created on parent overlay frame, set to OVERLAY draw layer for reliable top-of-bar rendering.
        if not ns.sealTwistBreakpoint then
            local sealZone = barParent:CreateTexture(nil, "ARTWORK")
            sealZone:SetColorTexture(1, 0, 0, 0.35)
            sealZone:SetPoint("TOPRIGHT", barParent, "TOPRIGHT", 0, 0)
            sealZone:SetPoint("BOTTOMRIGHT", barParent, "BOTTOMRIGHT", 0, 0)
            sealZone:SetWidth(1)
            sealZone:SetDrawLayer("OVERLAY", 0)
            sealZone:Hide()
            ns.sealTwistBreakpoint = sealZone
            ns.sealTwistZone = sealZone
        end

        -- Reseal GCD marker (existing, now 3px)
        if not ns.sealTwistResealBreakpoint then
            local sealResealLine = barParent:CreateTexture(nil, "ARTWORK")
            sealResealLine:SetColorTexture(0, 0, 0, 1)
            sealResealLine:SetPoint("TOPLEFT", barParent, "LEFT", 0, 0)
            sealResealLine:SetPoint("BOTTOMLEFT", barParent, "LEFT", 0, 0)
            sealResealLine:SetWidth(3)
            sealResealLine:SetDrawLayer("OVERLAY", 0)
            sealResealLine:Hide()
            ns.sealTwistResealBreakpoint = sealResealLine
            ns.sealTwistResealZone = sealResealLine
        end

        -- Judgement cooldown marker (NEW)
        if not ns.paladinJudgementMarker then
            local jgMark = barParent:CreateTexture(nil, "ARTWORK")
            -- Use a distinct color: gold/yellow to stand out from the red twist zone and black reseal line
            jgMark:SetColorTexture(1, 0.84, 0, 0.7) -- gold semi-transparent
            jgMark:SetPoint("TOPLEFT", barParent, "LEFT", 0, 0)
            jgMark:SetPoint("BOTTOMLEFT", barParent, "LEFT", 0, 0)
            jgMark:SetWidth(4)
            jgMark:SetDrawLayer("OVERLAY", 0)
            jgMark:Hide()
            ns.paladinJudgementMarker = jgMark
        end

        -- Register paladin seal/zone/badge OnUpdate hook
        ns.RegisterOnUpdateHook(function (elapsed)
            UpdateSealColorAndLabel()
            UpdateSealBreakpointLine()
            UpdateJudgementMarker()
            UpdateReckoningBadge()
            UpdatePaladinLibramSwapBadge()
            CheckTwistSuccess()
            if ns.UpdatePaladinBuffIcons then
                ns.UpdatePaladinBuffIcons(elapsed)
            end
        end)
        -- Force initial update of seal zone and markers
        UpdateSealColorAndLabel()
        UpdateSealBreakpointLine()
        UpdateJudgementMarker()
        UpdateReckoningBadge()
        UpdatePaladinLibramSwapBadge()
    end

    -- Register a handler for when a melee swing lands, used to detect seal twists.
    -- Uses ns.OnMeleeSwing (called from State.lua) matching the pattern other classes use.
    ns.OnMeleeSwing = function (slot)
        if ns.playerClass == "PALADIN" and slot == "mh" then
            -- Store previous seal for twist success detection
            local activeFamily = GetActivePaladinSeal()
            if activeFamily then
                ns.paladinSealAtSwingEnd = activeFamily
            else
                ns.paladinSealAtSwingEnd = nil
            end
        end
    end

    -- Expose RestoreMainHandColor for the seal color override system
    if not ns.RestoreMainHandColor then
        ns.RestoreMainHandColor = function ()
            if not ns.mhBar then return end
            local c = ns.mhBarBaseColor or (ns.GetBarColor and ns.GetBarColor("mh"))
            if c then
                ns.mhBar:SetStatusBarColor(c.r or 0, c.g or 0, c.b or 0, c.a or 1)
            end
        end
    end

    -- ========================================================================
    -- Paladin buff / CD icon tracking (same pattern as Warrior/Rogue/Shaman)
    -- ========================================================================
    local PALADIN_RACIAL_SPELLS = {
        { spellId = 20600, name = "Perception", label = "Per", kind = "buff" },
        { spellId = 28730, name = "Arcane Torrent", label = "AT", kind = "buff" },
    }
    local PALADIN_TRACKED_SPELLS = {
        { spellId = 31884, name = "Avenging Wrath", label = "AW", kind = "buff" },
        { spellId = 642, name = "Divine Shield", label = "DS", kind = "buff" },
        { spellId = 853, name = "Hammer of Justice", label = "HoJ", kind = "cd" },
        { spellId = 10278, name = "Blessing of Protection", label = "BoP", kind = "buff" },
        { spellId = 2812, name = "Holy Wrath", label = "HW", kind = "cd" },
        { spellId = 633, name = "Lay on Hands", label = "LoH", kind = "cd" },
        { spellId = 35395, name = "Crusader Strike", label = "CS", kind = "cd" },
        { spellId = 20053, name = "Vengeance", label = "Veng", kind = "buff" },
        { spellId = 20925, name = "Holy Shield", label = "HS", kind = "buff" },
        { spellId = 498, name = "Divine Protection", label = "DP", kind = "buff" },
        -- External buffs (party/raid-wide, consumables, not learned spells):
        { spellId = 2825, name = "Bloodlust", label = "BL", kind = "buff", external = true },
        { spellId = 32182, name = "Heroism", label = "Hero", kind = "buff", external = true },
        { spellId = 35476, name = "Drums of Battle", label = "DoB", kind = "buff", external = true },
        { spellId = 35477, name = "Drums of Speed", label = "DoS", kind = "buff", external = true },
        { spellId = 28507, name = "Haste Potion", label = "HP", kind = "buff", external = true },
    }
    for _, racial in ipairs(PALADIN_RACIAL_SPELLS) do
        table.insert(PALADIN_TRACKED_SPELLS, racial)
    end

    local paladinBuffIcons = {}
    local paladinBuffTimer = 0
    local PALADIN_BUFF_UPDATE_INTERVAL = 0.15
    local PALADIN_BUFF_ICON_GAP = 3

    local function GetPaladinSpellRemaining(info)
        -- Step 1: Scan helpful auras on the player (buffs)
        for index = 1, 40 do
            local auraName, duration, expirationTime, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then break end
            if auraSpellId == info.spellId or auraName == info.name then
                if type(expirationTime) == "number" and expirationTime > 0 then
                    return math.max(expirationTime - GetCurrentTime(), 0), math.max(duration or 1, 1)
                end
                return nil, nil
            end
        end
        -- Step 2: For CD-type, scan target harmful auras (debuffs like Judgement)
        if info.kind == "cd" then
            if type(UnitExists) == "function" and UnitExists("target")
                and type(UnitCanAttack) == "function" and UnitCanAttack("player", "target") then
                for index = 1, 40 do
                    local debuffName, _, debuffDuration, debuffExpiration, caster, debuffSpellId = GetHarmfulAuraData("target", index)
                    if not debuffName then break end
                    if caster == "player" and (debuffSpellId == info.spellId or debuffName == info.name) then
                        if type(debuffExpiration) == "number" and debuffExpiration > 0 then
                            return math.max(debuffExpiration - GetCurrentTime(), 0), math.max(debuffDuration or 1, 1)
                        end
                        return nil, nil
                    end
                end
            end
            -- Step 3: Fall back to cooldown tracking
            local startTime, cdDuration
            if type(GetSpellCooldown) == "function" then
                startTime, cdDuration = GetSpellCooldown(info.spellId)
            elseif C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
                local ok, cdInfo = pcall(C_Spell.GetSpellCooldown, info.spellId)
                if ok and cdInfo then
                    startTime = cdInfo.startTime
                    cdDuration = cdInfo.duration
                end
            end
            if type(startTime) ~= "number" or type(cdDuration) ~= "number" or cdDuration <= 0 then
                return nil, nil
            end
            -- Filter out the global cooldown (1.5s) from real spell cooldowns
            if cdDuration <= 2.5 then
                return nil, nil
            end
            local remaining = math.max((startTime + cdDuration) - GetCurrentTime(), 0)
            if remaining <= 0 then return nil, nil end
            return remaining, cdDuration
        end
        return nil, nil
    end

    local function CreatePaladinBuffIcons()
        if #paladinBuffIcons > 0 then return end
        local iconSize = SuperSwingTimerDB and SuperSwingTimerDB.paladinBuffIconSize or 25
        if type(iconSize) ~= "number" or iconSize <= 0 then iconSize = 25 end

        for _, spell in ipairs(PALADIN_TRACKED_SPELLS) do
            local icon = CreateFrame("Frame", nil, UIParent)
            icon:SetSize(iconSize, iconSize)
            icon:SetFrameStrata("DIALOG")
            icon:EnableMouse(false)
            icon.texture = icon:CreateTexture(nil, "BACKGROUND")
            icon.texture:SetAllPoints()
            icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            local texPath = GetSpellTexture and GetSpellTexture(spell.spellId)
            if texPath then icon.texture:SetTexture(texPath) end
            icon.glow = icon:CreateTexture(nil, "OVERLAY", nil, 7)
            icon.glow:SetAllPoints()
            icon.glow:SetColorTexture(1, 0.85, 0, 0)
            icon.glow:SetBlendMode("ADD")
            -- 4-edge outline border (not a full-face overlay)
            icon.border = {}
            icon.border.top = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.top:SetPoint("TOPLEFT", -1, 1)
            icon.border.top:SetPoint("TOPRIGHT", 1, 1)
            icon.border.top:SetHeight(1)
            icon.border.top:SetColorTexture(0, 0, 0, 0.65)
            icon.border.bottom = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.bottom:SetPoint("BOTTOMLEFT", -1, -1)
            icon.border.bottom:SetPoint("BOTTOMRIGHT", 1, -1)
            icon.border.bottom:SetHeight(1)
            icon.border.bottom:SetColorTexture(0, 0, 0, 0.65)
            icon.border.left = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.left:SetPoint("TOPLEFT", -1, 1)
            icon.border.left:SetPoint("BOTTOMLEFT", -1, -1)
            icon.border.left:SetWidth(1)
            icon.border.left:SetColorTexture(0, 0, 0, 0.65)
            icon.border.right = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.right:SetPoint("TOPRIGHT", 1, 1)
            icon.border.right:SetPoint("BOTTOMRIGHT", 1, -1)
            icon.border.right:SetWidth(1)
            icon.border.right:SetColorTexture(0, 0, 0, 0.65)
            icon.durationText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            icon.durationText:SetPoint("CENTER", icon, "TOP", 0, 0)
            icon.durationText:SetJustifyH("CENTER")
            icon.durationText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            icon.durationText:SetTextColor(1, 1, 1, 0.95)
            icon.durationText:Hide()
            icon:Hide()
            icon.spellId = spell.spellId
            icon.label = spell.label
            icon.kind = spell.kind
            table.insert(paladinBuffIcons, icon)
        end
    end

    ns.UpdatePaladinBuffIcons = function (elapsed)
        CreatePaladinBuffIcons()
        if #paladinBuffIcons == 0 then return end

        paladinBuffTimer = paladinBuffTimer + (elapsed or 0.03)
        if paladinBuffTimer < PALADIN_BUFF_UPDATE_INTERVAL then return end
        paladinBuffTimer = 0

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showPaladinBuffIcons == false then
            for _, icon in ipairs(paladinBuffIcons) do
                if icon and icon.Hide then icon:Hide() end
            end
            return
        end
        if ns.playerInCombat ~= true then
            for _, icon in ipairs(paladinBuffIcons) do
                if icon and icon.Hide then icon:Hide() end
            end
            return
        end

        local iconSize = SuperSwingTimerDB and SuperSwingTimerDB.paladinBuffIconSize or 25
        if type(iconSize) ~= "number" or iconSize <= 0 then iconSize = 25 end

        local activeIcons = {}
        for _, icon in ipairs(paladinBuffIcons) do
            if icon and icon.spellId then
                for _, spell in ipairs(PALADIN_TRACKED_SPELLS) do
                    if spell.spellId == icon.spellId then
                        local remaining, totalDuration = GetPaladinSpellRemaining(spell)
                        if type(remaining) == "number" and remaining > 0
                            and type(totalDuration) == "number" and totalDuration > 0 then
                            table.insert(activeIcons, {
                                icon = icon,
                                remaining = remaining,
                                totalDuration = totalDuration
                            })
                        else
                            if icon.Hide then icon:Hide() end
                        end
                        break
                    end
                end
            elseif icon and icon.Hide then
                icon:Hide()
            end
        end

        local numActive = #activeIcons
        if numActive == 0 then return end

        local referenceBar = ns.mhBar
        if not referenceBar then return end
        -- Position icons above all visible target debuff duration bars
        local iconY = GetDebuffStackOffset({
            ns.paladinSealVengeanceBar,
            ns.paladinJudgementBar,
        }, ns.mhBar)
        local barGetWidth = referenceBar.GetWidth
        if not barGetWidth then return end

        for idx, entry in ipairs(activeIcons) do
            local icon = entry.icon
            local remaining = entry.remaining
            local totalDuration = entry.totalDuration

            if icon.SetSize then icon:SetSize(iconSize, iconSize) end

            -- Right-align icons
            local xOffset = -(numActive - idx) * (iconSize + PALADIN_BUFF_ICON_GAP)
            local rightAlign = -(iconSize / 2)
            local finalX = rightAlign + xOffset

            if icon.ClearAllPoints then icon:ClearAllPoints() end
            if icon.SetPoint then icon:SetPoint("BOTTOM", referenceBar, "TOP", finalX, iconY) end

            -- No shading
            if icon.dim and icon.dim.SetColorTexture then
                icon.dim:SetColorTexture(0, 0, 0, 0)
            end

            -- Glow in last 4 seconds
            if icon.glow and icon.glow.SetColorTexture then
                local shouldGlow = remaining <= 4 and remaining > 0
                if shouldGlow and totalDuration > 0 then
                    local pulseAlpha = 0.15 + 0.40 * (0.5 + 0.5 * math.sin(GetCurrentTime() * 6))
                    icon.glow:SetColorTexture(1, 0.85, 0, pulseAlpha)
                    if icon.glow.Show then icon.glow:Show() end
                elseif icon.glow.Hide then
                    icon.glow:Hide()
                end
            end

            -- Countdown text
            if icon.durationText and icon.durationText.SetText then
                local text = remaining >= 3 and string.format("%.0f", remaining) or string.format("%.1f", remaining)
                icon.durationText:SetText(text)
                if icon.durationText.Show then icon.durationText:Show() end
            end

            if icon.Show then icon:Show() end
        end
    end

    -- ========================================================================
    -- Judgement of the Crusader debuff bar (thin gold bar above MH bar)
    -- ========================================================================
    local JOTC_BAR_HEIGHT = 6
    local JOTC_FALLBACK_DURATION = 20
    local JOTC_GLOW_WINDOW = 4
    local judgementBar = nil
    local nextJudgementUpdateAt = 0

    local function SetJudgementGlow(bar, remaining)
        if not bar or not bar.glowBorder then return end
        local shouldGlow = remaining > 0 and remaining <= JOTC_GLOW_WINDOW
        if shouldGlow then
            local pulseAlpha = 0.3 + 0.5 * (0.5 + 0.5 * math.sin(GetCurrentTime() * 8))
            for _, border in ipairs(bar.glowBorder) do
                if border and border.SetAlpha then
                    border:SetAlpha(pulseAlpha)
                    border:Show()
                end
            end
        else
            for _, border in ipairs(bar.glowBorder) do
                if border and border.Hide then
                    border:Hide()
                end
            end
        end
    end

    local function EnsureJudgementBar()
        if judgementBar and judgementBar.GetObjectType then
            return judgementBar
        end
        if not ns.mhBar then return nil end

        local bar = CreateFrame("StatusBar", nil, ns.mhBar)
        bar:SetHeight(JOTC_BAR_HEIGHT)
        bar:SetStatusBarColor(0.85, 0.70, 0.10, 1)
        bar:SetFrameStrata("DIALOG")
        bar:EnableMouse(false)

        -- Dark background
        bar.background = bar:CreateTexture(nil, "BACKGROUND")
        bar.background:SetAllPoints()
        bar.background:SetColorTexture(0, 0, 0, 0.5)

        -- Spell icon
        local iconPath = GetSpellTexture and GetSpellTexture(21183)
        if iconPath then
            bar.icon = bar:CreateTexture(nil, "OVERLAY")
        bar.icon:SetSize(JOTC_BAR_HEIGHT, JOTC_BAR_HEIGHT)
        bar.icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
        bar.icon:SetTexture(iconPath)
        bar.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    -- Label
    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.label:SetPoint("LEFT", bar, "LEFT", 12, 0)
    bar.label:SetText("JoC")
        bar.label:SetFont("Fonts\\\\FRIZQT__.TTF", 8, "OUTLINE")
        bar.label:SetTextColor(0.85, 0.70, 0.10, 1)
        bar.label:SetJustifyH("LEFT")

        -- Glow borders (4 sides)
        bar.glowBorder = {}
        local function MakeGlowBorder(layer, point, relativePoint, xOff, yOff, width, height)
            local tex = bar:CreateTexture(nil, "OVERLAY", nil, layer)
            tex:SetColorTexture(0.85, 0.70, 0.10, 0)
            tex:SetPoint(point, bar, relativePoint, xOff, yOff)
            if width then tex:SetWidth(width) end
            if height then tex:SetHeight(height) end
            tex:Hide()
            return tex
        end
        table.insert(bar.glowBorder, MakeGlowBorder(7, "TOPLEFT", "TOPLEFT", -1, 1, nil, 1))   -- top
        table.insert(bar.glowBorder, MakeGlowBorder(7, "BOTTOMLEFT", "BOTTOMLEFT", -1, -1, nil, 1)) -- bottom
        table.insert(bar.glowBorder, MakeGlowBorder(7, "TOPLEFT", "TOPLEFT", -1, 1, 1, nil))   -- left
        table.insert(bar.glowBorder, MakeGlowBorder(7, "TOPRIGHT", "TOPRIGHT", 1, 1, 1, nil))  -- right

        -- Position 2px above MH bar
        bar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, 2)
        bar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, 2)

        bar:Hide()
        judgementBar = bar
        ns.paladinJudgementBar = bar
        return bar
    end

    local function GetTargetJudgementData()
        if not UnitExists or not UnitExists("target") then return nil, nil end
        if not UnitCanAttack or not UnitCanAttack("player", "target") then return nil, nil end

        for i = 1, 40 do
            local name, _, duration, expirationTime, caster, spellId = GetHarmfulAuraData("target", i, "HARMFUL")
            if not name then break end
            if caster == "player" then
                local isMatch = (ns.PALADIN_JUDGEMENT_CRUSADER_IDS and ns.PALADIN_JUDGEMENT_CRUSADER_IDS[spellId])
                    or (ns.PALADIN_JUDGEMENT_CRUSADER_NAME and name == ns.PALADIN_JUDGEMENT_CRUSADER_NAME)
                if isMatch then
                    if type(expirationTime) == "number" and expirationTime > 0 then
                        return math.max(expirationTime - GetCurrentTime(), 0), math.max(duration or 1, 1)
                    end
                    return nil, nil
                end
            end
        end
        return nil, nil
    end

    local function UpdatePaladinJudgementBar(force)
        -- Throttle: 0.05s same as other bars
        if not force then
            local t = GetCurrentTime and GetCurrentTime() or GetTime()
            if t < nextJudgementUpdateAt then return end
            nextJudgementUpdateAt = t + 0.05
        end

        if not ns.mhBar then return end

        local bar = EnsureJudgementBar()
        if not bar then return end

        -- Nil-guard checks
        if not bar.label or not bar.label.SetText then return end
        if not bar.icon or not bar.icon.SetTexture then return end

        local show = false

        if UnitExists and UnitExists("target")
            and UnitCanAttack and UnitCanAttack("player", "target") then

            local remaining, totalDuration = GetTargetJudgementData()
            if type(remaining) == "number" and remaining > 0
                and type(totalDuration) == "number" and totalDuration > 0 then

                show = true

                -- Min duration fallback
                local effectiveDuration = math.max(totalDuration, JOTC_FALLBACK_DURATION)

                -- Set bar value
                if bar.SetMinMaxValues then bar:SetMinMaxValues(0, effectiveDuration) end
                if bar.SetValue then bar:SetValue(remaining) end

                -- Label
                if bar.label and bar.label.SetText then
                    if remaining >= 3 then
                        bar.label:SetText(string.format("JoC %.0f", remaining))
                    else
                        bar.label:SetText(string.format("JoC %.1f", remaining))
                    end
                end

                -- Icon alpha (fade in last seconds)
                if bar.icon and bar.icon.SetAlpha then
                    if remaining <= 4 and totalDuration > 0 then
                        local fadeAlpha = 0.3 + 0.7 * (remaining / 4)
                        bar.icon:SetAlpha(math.max(fadeAlpha, 0.1))
                    else
                        bar.icon:SetAlpha(1)
                    end
                end

                -- Glow
                SetJudgementGlow(bar, remaining)

                if bar.Show then bar:Show() end
            end
        end

        if not show then
            SetJudgementGlow(bar, 0)
            if bar.Hide then bar:Hide() end
            if bar.label and bar.label.SetText then
                bar.label:SetText("JoC")
            end
        end
    end

    -- Initial call
    pcall(UpdatePaladinJudgementBar, true)

    -- Export
    ns.UpdatePaladinJudgementBar = UpdatePaladinJudgementBar

    -- Register Judgement bar OnUpdate hook
    ns.RegisterOnUpdateHook(function (elapsed)
        UpdatePaladinJudgementBar(false)
    end)

    -- Initial forced update
    pcall(UpdatePaladinJudgementBar, true)

    -- ========================================================================
    -- Seal of Vengeance / Corruption target debuff duration bar (thin gold bar above MH)
    -- ========================================================================
    local SEAL_VENGEANCE_BAR_HEIGHT = 5
    local SEAL_VENGEANCE_FALLBACK_DURATION = 15
    local SEAL_VENGEANCE_GLOW_WINDOW = 4
    local sealVengeanceBar = nil
    local nextSealVengeanceUpdateAt = 0

    local function SetSealVengeanceGlow(bar, remaining)
        if not bar or not bar.glowBorder then return end
        local shouldGlow = remaining > 0 and remaining <= SEAL_VENGEANCE_GLOW_WINDOW
        if shouldGlow then
            local pulseAlpha = 0.3 + 0.5 * (0.5 + 0.5 * math.sin(GetCurrentTime() * 8))
            for _, border in ipairs(bar.glowBorder) do
                if border and border.SetAlpha then
                    border:SetAlpha(pulseAlpha)
                    border:Show()
                end
            end
        else
            for _, border in ipairs(bar.glowBorder) do
                if border and border.Hide then
                    border:Hide()
                end
            end
        end
    end

    local function EnsureSealVengeanceBar()
        if sealVengeanceBar and sealVengeanceBar.GetObjectType then
            return sealVengeanceBar
        end
        if not ns.mhBar then return nil end

        local bar = CreateFrame("StatusBar", nil, ns.mhBar)
        bar:SetHeight(SEAL_VENGEANCE_BAR_HEIGHT)
        bar:SetStatusBarColor(1.0, 0.85, 0.2, 1)
        bar:SetFrameStrata("DIALOG")
        bar:EnableMouse(false)

        -- Dark background
        bar.background = bar:CreateTexture(nil, "BACKGROUND")
        bar.background:SetAllPoints()
        bar.background:SetColorTexture(0, 0, 0, 0.5)

        -- Spell icon (Seal of Vengeance)
        local iconPath = GetSpellTexture and GetSpellTexture(31801)
        if iconPath then
            bar.icon = bar:CreateTexture(nil, "OVERLAY")
            bar.icon:SetSize(SEAL_VENGEANCE_BAR_HEIGHT, SEAL_VENGEANCE_BAR_HEIGHT)
            bar.icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
            bar.icon:SetTexture(iconPath)
            bar.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end

        -- Label
        bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bar.label:SetPoint("LEFT", bar, "LEFT", 12, 0)
        bar.label:SetText("SoV")
        bar.label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        bar.label:SetTextColor(1.0, 0.85, 0.2, 1)
        bar.label:SetJustifyH("LEFT")

        -- Glow borders (4 sides)
        bar.glowBorder = {}
        local function MakeGlowBorder(layer, point, relativePoint, xOff, yOff, width, height)
            local tex = bar:CreateTexture(nil, "OVERLAY", nil, layer)
            tex:SetColorTexture(1.0, 0.85, 0.2, 0)
            tex:SetPoint(point, bar, relativePoint, xOff, yOff)
            if width then tex:SetWidth(width) end
            if height then tex:SetHeight(height) end
            tex:Hide()
            return tex
        end
        table.insert(bar.glowBorder, MakeGlowBorder(7, "TOPLEFT", "TOPLEFT", -1, 1, nil, 1))
        table.insert(bar.glowBorder, MakeGlowBorder(7, "BOTTOMLEFT", "BOTTOMLEFT", -1, -1, nil, 1))
        table.insert(bar.glowBorder, MakeGlowBorder(7, "TOPLEFT", "TOPLEFT", -1, 1, 1, nil))
        table.insert(bar.glowBorder, MakeGlowBorder(7, "TOPRIGHT", "TOPRIGHT", 1, 1, 1, nil))

        -- Position 11px above MH bar (3px gap above Judgement bar which ends at MH top + 8)
        bar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, 11)
        bar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, 11)

        bar:Hide()
        sealVengeanceBar = bar
        ns.paladinSealVengeanceBar = bar
        return bar
    end

    local function GetTargetSealVengeanceData()
        if not UnitExists or not UnitExists("target") then return nil, nil end
        if not UnitCanAttack or not UnitCanAttack("player", "target") then return nil, nil end

        for i = 1, 40 do
            local name, _, duration, expirationTime, caster, spellId = GetHarmfulAuraData("target", i, "HARMFUL")
            if not name then break end
            if caster == "player" then
                local isMatch = (ns.PALADIN_SEAL_VENGEANCE_IDS and ns.PALADIN_SEAL_VENGEANCE_IDS[spellId])
                    or (ns.PALADIN_SEAL_VENGEANCE_NAME and name == ns.PALADIN_SEAL_VENGEANCE_NAME)
                if isMatch then
                    if type(expirationTime) == "number" and expirationTime > 0 then
                        return math.max(expirationTime - GetCurrentTime(), 0), math.max(duration or 1, 1)
                    end
                    return nil, nil
                end
            end
        end
        return nil, nil
    end

    local function UpdatePaladinSealVengeanceBar(force)
        -- Throttle: 0.05s same as other bars
        if not force then
            local t = GetCurrentTime and GetCurrentTime() or GetTime()
            if t < nextSealVengeanceUpdateAt then return end
            nextSealVengeanceUpdateAt = t + 0.05
        end

        if not ns.mhBar then return end

        local bar = EnsureSealVengeanceBar()
        if not bar then return end

        -- Nil-guard checks
        if not bar.label or not bar.label.SetText then return end
        if not bar.icon or not bar.icon.SetTexture then return end

        -- Check if the toggle is on
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        local disabled = db and db.showPaladinSealVengeanceBar == false
        if disabled then
            SetSealVengeanceGlow(bar, 0)
            if bar.Hide then bar:Hide() end
            if bar.label and bar.label.SetText then
                bar.label:SetText("SoV")
            end
            return
        end

        local show = false

        if UnitExists and UnitExists("target")
            and UnitCanAttack and UnitCanAttack("player", "target") then

            local remaining, totalDuration = GetTargetSealVengeanceData()
            if type(remaining) == "number" and remaining > 0
                and type(totalDuration) == "number" and totalDuration > 0 then

                show = true

                local effectiveDuration = math.max(totalDuration, SEAL_VENGEANCE_FALLBACK_DURATION)

                if bar.SetMinMaxValues then bar:SetMinMaxValues(0, effectiveDuration) end
                if bar.SetValue then bar:SetValue(remaining) end

                if bar.label and bar.label.SetText then
                    if remaining >= 3 then
                        bar.label:SetText(string.format("SoV %.0f", remaining))
                    else
                        bar.label:SetText(string.format("SoV %.1f", remaining))
                    end
                end

                -- Icon alpha (fade in last seconds)
                if bar.icon and bar.icon.SetAlpha then
                    if remaining <= 4 and totalDuration > 0 then
                        local fadeAlpha = 0.3 + 0.7 * (remaining / 4)
                        bar.icon:SetAlpha(math.max(fadeAlpha, 0.1))
                    else
                        bar.icon:SetAlpha(1)
                    end
                end

                SetSealVengeanceGlow(bar, remaining)

                if bar.Show then bar:Show() end
            end
        end

        if not show then
            SetSealVengeanceGlow(bar, 0)
            if bar.Hide then bar:Hide() end
            if bar.label and bar.label.SetText then
                bar.label:SetText("SoV")
            end
        end
    end

    -- Initial call
    pcall(UpdatePaladinSealVengeanceBar, true)

    -- Export
    ns.UpdatePaladinSealVengeanceBar = UpdatePaladinSealVengeanceBar

    -- Register Seal Vengeance OnUpdate hook (includes restack + buff icons)
    ns.RegisterOnUpdateHook(function (elapsed)
        UpdatePaladinSealVengeanceBar(false)
        -- Restack all visible debuff bars above MH dynamically
        RestackDebuffBars({ns.paladinJudgementBar, ns.paladinSealVengeanceBar}, ns.mhBar)
        -- Re-call buff icons so they use the restacked bar positions
        if ns.UpdatePaladinBuffIcons then ns.UpdatePaladinBuffIcons(elapsed) end
    end)

    -- Initial forced update
    pcall(UpdatePaladinSealVengeanceBar, true)
    RestackDebuffBars({ns.paladinJudgementBar, ns.paladinSealVengeanceBar}, ns.mhBar)
end

local function SetupWarrior()
    local IsCurrentSpell = rawget(_G, "IsCurrentSpell")
    if not IsCurrentSpell then
        if C_Spell and C_Spell.IsCurrentSpell then
            IsCurrentSpell = C_Spell.IsCurrentSpell
        end
    end

    local function FindCurrentQueuedSpell(spellSet)
        if not IsCurrentSpell or not spellSet then
            return nil
        end

        -- Priority 1: Check by name (most reliable for Heroic Strike/Cleave in TBC)
        -- We use rank 1 IDs to get the localized names
        local heroicName = ns.GetSpellInfo(78)
        local cleaveName = ns.GetSpellInfo(845)

        if heroicName and spellSet == ns.WARRIOR_HEROIC_STRIKE_SPELLS and IsCurrentSpell(heroicName) then
            return heroicName
        end
        if cleaveName and spellSet == ns.WARRIOR_CLEAVE_SPELLS and IsCurrentSpell(cleaveName) then
            return cleaveName
        end

        -- Priority 2: Fallback to ID iteration if needed (for other abilities)
        for key in pairs(spellSet) do
            if type(key) == "number" and IsCurrentSpell(key) then
                return key
            end
        end

        return nil
    end

    local function RestoreMainHandColor()
        if not ns.mhBar then
            return
        end

        local c = ns.mhBarBaseColor or (ns.GetBarColor and ns.GetBarColor("mh"))
        if c then
            ns.mhBar:SetStatusBarColor(c.r or 0, c.g or 0, c.b or 0, c.a or 1)
        else
            ns.mhBar:SetStatusBarColor(0, 0, 0, 1)
        end
    end

    local function UpdateWarriorQueueTint()
        if ns.playerClass ~= "WARRIOR" or not ns.mhBar then
            return
        end

        local alpha = (ns.mhBarBaseColor and ns.mhBarBaseColor.a) or 1
        local queuedSpellId = FindCurrentQueuedSpell(ns.WARRIOR_HEROIC_STRIKE_SPELLS)
        if queuedSpellId then
            ns.warriorQueuedMeleeSpell = queuedSpellId
            ns.mhBar:SetStatusBarColor(
                WARRIOR_HEROIC_STRIKE_TINT.r, WARRIOR_HEROIC_STRIKE_TINT.g, WARRIOR_HEROIC_STRIKE_TINT.b, alpha
            )
            return
        end

        queuedSpellId = FindCurrentQueuedSpell(ns.WARRIOR_CLEAVE_SPELLS)
        if queuedSpellId then
            ns.warriorQueuedMeleeSpell = queuedSpellId
            ns.mhBar:SetStatusBarColor(WARRIOR_CLEAVE_TINT.r, WARRIOR_CLEAVE_TINT.g, WARRIOR_CLEAVE_TINT.b, alpha)
            return
        end

        if ns.warriorQueuedMeleeSpell then
            ns.warriorQueuedMeleeSpell = nil
            RestoreMainHandColor()
        end
    end

    ns.UpdateWarriorQueueTint = UpdateWarriorQueueTint

    local function ApplyWarriorQueueTint(spellValue)
        if not ns.mhBar then
            return
        end

        local alpha = (ns.mhBarBaseColor and ns.mhBarBaseColor.a) or 1
        if ns.WARRIOR_HEROIC_STRIKE_SPELLS and ns.WARRIOR_HEROIC_STRIKE_SPELLS[spellValue] then
            ns.warriorQueuedMeleeSpell = spellValue
            ns.mhBar:SetStatusBarColor(
                WARRIOR_HEROIC_STRIKE_TINT.r, WARRIOR_HEROIC_STRIKE_TINT.g, WARRIOR_HEROIC_STRIKE_TINT.b, alpha
            ) -- Heroic Strike: yellow
        elseif ns.WARRIOR_CLEAVE_SPELLS and ns.WARRIOR_CLEAVE_SPELLS[spellValue] then
            ns.warriorQueuedMeleeSpell = spellValue
            ns.mhBar:SetStatusBarColor(WARRIOR_CLEAVE_TINT.r, WARRIOR_CLEAVE_TINT.g, WARRIOR_CLEAVE_TINT.b, alpha) -- Cleave: green
        else
            RestoreMainHandColor()
        end
    end

    local function ApplyWarriorSlamTint(spellValue)
        if not ns.mhBar then
            return
        end

        local alpha = (ns.mhBarBaseColor and ns.mhBarBaseColor.a) or 1
        if ns.PAUSE_SWING_SPELLS and ns.PAUSE_SWING_SPELLS[spellValue] then
            ns.mhBar:SetStatusBarColor(1.0, 1.0, 1.0, alpha) -- slam: white
        end
    end

    -- Queue indicator colors restore to the base MH tint on the next real swing.
    ns.OnMeleeSwing = function (slot)
        if slot == "mh" and ns.mhBar then
            ns.warriorQueuedMeleeSpell = nil
            RestoreMainHandColor()
        end
    end

    ns.ClearWarriorQueueTint = function ()
        ns.warriorQueuedMeleeSpell = nil
        RestoreMainHandColor()
    end

    -- ============================================================
    -- Warrior Rage Bar
    -- ============================================================
    local function GetWarriorRageBarColor()
        local db = SuperSwingTimerDB
        if db and db.colors and db.colors.warriorRageBarColor then
            return db.colors.warriorRageBarColor
        end
        return { r = 0.80, g = 0.20, b = 0.10, a = 0.85 }
    end

    local shieldBlockBar = nil
    local shieldBlockUpdateTimer = 0
    local shieldBlockUpdateInterval = 0.05
    local warriorSlamBar = nil
    local warriorOverpowerGlow = nil
    local warriorOverpowerText = nil
    local warriorVisualUpdateTimer = 0
    local WARRIOR_VISUAL_UPDATE_INTERVAL = 0.05
    local cachedWarriorProtectionSpec = nil
    local nextWarriorProtectionScanAt = 0

    local function GetShieldBlockAuraData()
        for index = 1, 40 do
            local auraName, duration, expirationTime, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then
                break
            end

            if auraSpellId == ns.SHIELD_BLOCK_ID or auraName == ns.SHIELD_BLOCK_NAME then
                return duration, expirationTime, auraSpellId, auraName
            end
        end

        return nil
    end

    local function IsWarriorSlamCast(spellToken)
        if not spellToken then
            return false
        end
        return ns.PAUSE_SWING_SPELLS
            and (ns.PAUSE_SWING_SPELLS[spellToken] or ns.PAUSE_SWING_SPELLS[tonumber(spellToken) or -1])
            or false
    end

    local function GetSpellCastDuration(spellToken)
        local spellInfoFn = ns.GetSpellInfo or rawget(_G, "GetSpellInfo")
        if spellInfoFn then
            local _, _, _, castTimeMs = spellInfoFn(spellToken)
            if type(castTimeMs) == "number" and castTimeMs > 0 then
                return castTimeMs / 1000
            end
        end
        return 1.5
    end

    local function GetCooldownRemaining(spellId)
        local startTime, duration = QuerySpellCooldown(spellId)
        if type(startTime) ~= "number" or type(duration) ~= "number" or duration <= 0 then
            return nil
        end

        local remaining = (startTime + duration) - GetCurrentTime()
        if remaining <= 0 then
            return nil
        end

        return remaining, duration
    end

    local function IsWarriorProtectionSpec()
        local now = GetCurrentTime()
        if cachedWarriorProtectionSpec ~= nil and now < nextWarriorProtectionScanAt then
            return cachedWarriorProtectionSpec
        end

        local isProtection = false
        if type(GetSpecialization) == "function" then
            local specId = GetSpecialization()
            isProtection = (specId == 3)
        else
            -- Classic/TBC fallback: infer primary talent tree from points spent.
            if type(GetNumTalentTabs) == "function" and type(GetTalentTabInfo) == "function" then
                local numTabs = tonumber(GetNumTalentTabs()) or 0
                local protPoints = 0
                local maxPoints = 0
                for tab = 1, numTabs do
                    local _, _, pointsSpent = GetTalentTabInfo(tab)
                    local points = tonumber(pointsSpent) or 0
                    if tab == 3 then
                        protPoints = points
                    end
                    if points > maxPoints then
                        maxPoints = points
                    end
                end
                isProtection = protPoints > 0 and protPoints >= maxPoints
            end
        end

        cachedWarriorProtectionSpec = isProtection
        nextWarriorProtectionScanAt = now + 1.0
        return isProtection
    end

    local function EnsureWarriorBadge(parent, fieldName, yOffset, textColor)
        local text = parent[fieldName]
        if not text then
            text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("TOPLEFT", parent, "TOPRIGHT", 3, yOffset)
            text:SetJustifyH("LEFT")
            text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            text:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 0.95)
            parent[fieldName] = text
        end
        return text
    end

    local function UpdateWarriorCooldownBadges()
        local parent = ns.mhBar or ns.warriorRageBar
        if not parent then
            return
        end

        local btText = EnsureWarriorBadge(parent, "warriorBloodthirstText", 2, { 0.95, 0.35, 0.25, 0.95 })
        local wwText = EnsureWarriorBadge(parent, "warriorWhirlwindText", -8, { 0.25, 0.85, 1.0, 0.95 })

        local btRemaining = GetCooldownRemaining(ns.WARRIOR_BLOODTHIRST_ID)
        if btRemaining then
            btText:SetText(string.format("BT %.0fs", btRemaining))
            btText:Show()
        else
            btText:Hide()
        end

        local wwRemaining = GetCooldownRemaining(ns.WARRIOR_WHIRLWIND_ID)
        if wwRemaining then
            wwText:SetText(string.format("WW %.0fs", wwRemaining))
            wwText:Show()
        else
            wwText:Hide()
        end
    end

    local function UpdateWarriorSlamBar()
        if not ns.mhBar then
            return
        end

        local currentCast = ns.currentCastSpellId
        if not currentCast or not ns.casting or not IsWarriorSlamCast(currentCast) then
            if warriorSlamBar then
                warriorSlamBar:Hide()
            end
            return
        end

        if not warriorSlamBar then
            warriorSlamBar = CreateFrame("StatusBar", nil, ns.mhBar)
            warriorSlamBar:SetStatusBarTexture(
                ns.GetBarTexture and ns.GetBarTexture() or "Interface\\TargetingFrame\\UI-StatusBar"
            )
            warriorSlamBar:SetSize((ns.mhBar:GetWidth() or ns.BAR_WIDTH or 240), 4)
            warriorSlamBar:SetPoint("BOTTOM", ns.mhBar, "TOP", 0, 2)
            warriorSlamBar:SetFrameStrata((ns.mhBar and ns.mhBar:GetFrameStrata()) or "MEDIUM")
            warriorSlamBar:SetFrameLevel(((ns.mhBar and ns.mhBar:GetFrameLevel()) or 0) + 1)
            warriorSlamBar:EnableMouse(false)
            warriorSlamBar:SetMinMaxValues(0, 1)
            warriorSlamBar:SetValue(0)
            local bg = warriorSlamBar:CreateTexture(nil, "BACKGROUND")
            bg:SetColorTexture(0, 0, 0, 0.5)
            bg:SetAllPoints(true)
            local label = warriorSlamBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("LEFT", warriorSlamBar, "RIGHT", 2, 0)
            label:SetJustifyH("LEFT")
            label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            label:SetTextColor(1.0, 0.85, 0.15, 0.95)
            warriorSlamBar.label = label
        end

        local startTime = ns.currentCastStartTime or GetCurrentTime()
        local duration = GetSpellCastDuration(currentCast)
        local remaining = math.max((startTime + duration) - GetCurrentTime(), 0)
        if remaining <= 0 then
            warriorSlamBar:Hide()
            return
        end

        warriorSlamBar:SetMinMaxValues(0, duration)
        warriorSlamBar:SetValue(remaining)
        warriorSlamBar:Show()
        if warriorSlamBar.label then
            warriorSlamBar.label:SetText(string.format("SLAM %.1fs", remaining))
        end
    end

    local function UpdateWarriorOverpowerFlash()
        if not ns.mhBar then
            return
        end

        if not warriorOverpowerGlow then
            local glowBorder = {}

            local glowTop = ns.mhBar:CreateTexture(nil, "OVERLAY")
            glowTop:SetPoint("TOPLEFT", ns.mhBar, "TOPLEFT", -1, 1)
            glowTop:SetPoint("TOPRIGHT", ns.mhBar, "TOPRIGHT", 1, 1)
            glowTop:SetHeight(1)
            glowTop:SetColorTexture(1, 0.85, 0.10, 0)
            glowTop:Hide()
            glowBorder[#glowBorder + 1] = glowTop

            local glowBottom = ns.mhBar:CreateTexture(nil, "OVERLAY")
            glowBottom:SetPoint("BOTTOMLEFT", ns.mhBar, "BOTTOMLEFT", -1, -1)
            glowBottom:SetPoint("BOTTOMRIGHT", ns.mhBar, "BOTTOMRIGHT", 1, -1)
            glowBottom:SetHeight(1)
            glowBottom:SetColorTexture(1, 0.85, 0.10, 0)
            glowBottom:Hide()
            glowBorder[#glowBorder + 1] = glowBottom

            local glowLeft = ns.mhBar:CreateTexture(nil, "OVERLAY")
            glowLeft:SetPoint("TOPLEFT", ns.mhBar, "TOPLEFT", -1, 1)
            glowLeft:SetPoint("BOTTOMLEFT", ns.mhBar, "BOTTOMLEFT", -1, -1)
            glowLeft:SetWidth(1)
            glowLeft:SetColorTexture(1, 0.85, 0.10, 0)
            glowLeft:Hide()
            glowBorder[#glowBorder + 1] = glowLeft

            local glowRight = ns.mhBar:CreateTexture(nil, "OVERLAY")
            glowRight:SetPoint("TOPRIGHT", ns.mhBar, "TOPRIGHT", 1, 1)
            glowRight:SetPoint("BOTTOMRIGHT", ns.mhBar, "BOTTOMRIGHT", 1, -1)
            glowRight:SetWidth(1)
            glowRight:SetColorTexture(1, 0.85, 0.10, 0)
            glowRight:Hide()
            glowBorder[#glowBorder + 1] = glowRight

            warriorOverpowerGlow = glowBorder
        end
        if not warriorOverpowerText then
            warriorOverpowerText = ns.mhBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            warriorOverpowerText:SetPoint("CENTER", ns.mhBar, "CENTER", 0, 0)
            warriorOverpowerText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            warriorOverpowerText:SetTextColor(1.0, 0.95, 0.2, 1)
        end

        local procUntil = ns.warriorOverpowerProcUntil or 0
        if not ns.playerInCombat or procUntil <= GetCurrentTime() then
            for _, edge in ipairs(warriorOverpowerGlow) do
                edge:Hide()
            end
            warriorOverpowerText:Hide()
            return
        end

        local pulse = 0.5 + (0.5 * math.sin(GetCurrentTime() * 10))
        local alpha = 0.25 + (0.45 * pulse)
        for _, edge in ipairs(warriorOverpowerGlow) do
            edge:SetColorTexture(1, 0.85, 0.10, alpha)
            edge:Show()
        end
        warriorOverpowerText:SetText("OP")
        warriorOverpowerText:Show()
    end

    ns.UpdateWarriorRageBar = function ()
        local bar = ns.warriorRageBar
        if not bar then
            return
        end

        local showBar = SuperSwingTimerDB and SuperSwingTimerDB.showWarriorRageBar ~= false
        local showProt = SuperSwingTimerDB and SuperSwingTimerDB.showWarriorRageProtection
        local isProt = IsWarriorProtectionSpec()
        local inCombat = (ns.playerInCombat == true) or (InCombatLockdown and InCombatLockdown() or false)
        if ns.playerClass ~= "WARRIOR" or not showBar or not inCombat or (isProt and not showProt) then
            bar:SetAlpha(0)
            return
        end

        local rage = UnitPower and UnitPower("player", 1) or 0
        local maxRage = 100
        bar:SetMinMaxValues(0, maxRage)
        bar:SetValue(rage)

        local color = GetWarriorRageBarColor()
        bar:SetStatusBarColor(color.r or 0.80, color.g or 0.20, color.b or 0.10, color.a or 0.85)
        bar:SetAlpha(1)

        local targetHealth = UnitHealth and UnitHealth("target") or 0
        local targetMaxHealth = UnitHealthMax and UnitHealthMax("target") or 0
        local executeActive = targetHealth > 0 and targetMaxHealth > 0 and (targetHealth / targetMaxHealth) <= 0.20
        if executeActive then
            if not bar.executeText then
                bar.executeText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                bar.executeText:SetPoint("LEFT", bar, "RIGHT", 3, 0)
                bar.executeText:SetJustifyH("LEFT")
                bar.executeText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
                bar.executeText:SetTextColor(1.0, 0.35, 0.20, 0.95)
            end
            bar.executeText:SetText("EXEC")
            bar.executeText:Show()
        elseif bar.executeText then
            bar.executeText:Hide()
        end
    end

    ns.UpdateWarriorShieldBlockBar = function (elapsed, force)
        if not ns.mhBar then
            return
        end

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if not db or db.showWarriorShieldBlockBar == false then
            if shieldBlockBar then
                shieldBlockBar:Hide()
            end
            return
        end

        if not shieldBlockBar then
            shieldBlockBar = CreateFrame("StatusBar", nil, ns.mhBar)
            shieldBlockBar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, 2)
            shieldBlockBar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, 2)
            shieldBlockBar:SetFrameStrata((ns.mhBar and ns.mhBar:GetFrameStrata()) or "MEDIUM")
            shieldBlockBar:SetFrameLevel(((ns.mhBar and ns.mhBar:GetFrameLevel()) or 0) + 1)
            shieldBlockBar:EnableMouse(false)

            local backgroundTexture = shieldBlockBar.backgroundTexture
                or shieldBlockBar:CreateTexture(nil, "BACKGROUND")
            backgroundTexture:SetAllPoints(true)
            backgroundTexture:SetColorTexture(0, 0, 0, 0.5)
            shieldBlockBar.backgroundTexture = backgroundTexture

            if not shieldBlockBar.borderTextures then
                local borderTop = shieldBlockBar:CreateTexture(nil, "OVERLAY")
                borderTop:SetColorTexture(0, 0, 0, 1)
                borderTop:SetPoint("TOPLEFT", -1, 1)
                borderTop:SetPoint("TOPRIGHT", 1, 1)
                borderTop:SetHeight(1)

                local borderBottom = shieldBlockBar:CreateTexture(nil, "OVERLAY")
                borderBottom:SetColorTexture(0, 0, 0, 1)
                borderBottom:SetPoint("BOTTOMLEFT", -1, -1)
                borderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
                borderBottom:SetHeight(1)

                local borderLeft = shieldBlockBar:CreateTexture(nil, "OVERLAY")
                borderLeft:SetColorTexture(0, 0, 0, 1)
                borderLeft:SetPoint("TOPLEFT", -1, 1)
                borderLeft:SetPoint("BOTTOMLEFT", -1, -1)
                borderLeft:SetWidth(1)

                local borderRight = shieldBlockBar:CreateTexture(nil, "OVERLAY")
                borderRight:SetColorTexture(0, 0, 0, 1)
                borderRight:SetPoint("TOPRIGHT", 1, 1)
                borderRight:SetPoint("BOTTOMRIGHT", 1, -1)
                borderRight:SetWidth(1)

                shieldBlockBar.borderTextures = {
                    top = borderTop,
                    bottom = borderBottom,
                    left = borderLeft,
                    right = borderRight
                }
            end

            -- Spell icon (left side)
            local sbIconPath = GetSpellTexture and GetSpellTexture(2565)
            if sbIconPath then
                local sbIcon = shieldBlockBar:CreateTexture(nil, "OVERLAY")
                sbIcon:SetSize(ns.WARRIOR_SHIELD_BLOCK_BAR_HEIGHT or 4, ns.WARRIOR_SHIELD_BLOCK_BAR_HEIGHT or 4)
                sbIcon:SetPoint("LEFT", shieldBlockBar, "LEFT", 1, 0)
                sbIcon:SetTexture(sbIconPath)
                sbIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                shieldBlockBar.icon = sbIcon
            end

            shieldBlockBar:SetMinMaxValues(0, 1)
            shieldBlockBar:SetValue(0)
            shieldBlockBar:Hide()
            -- Export for UI.lua apply-function access
            ns.warriorShieldBlockBar = shieldBlockBar
        end

        shieldBlockUpdateTimer = shieldBlockUpdateTimer + (elapsed or 0)
        if not force and shieldBlockUpdateTimer < shieldBlockUpdateInterval then
            return
        end
        shieldBlockUpdateTimer = 0

        -- Style sync is throttled with data updates to avoid per-frame churn.
        shieldBlockBar:SetStatusBarTexture(
            ns.GetBarTexture and ns.GetBarTexture() or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        shieldBlockBar:SetSize(
            (ns.mhBar and ns.mhBar:GetWidth()) or ns.BAR_WIDTH or 240, ns.WARRIOR_SHIELD_BLOCK_BAR_HEIGHT or 4
        )
        local shieldColor = ns.GetBarColor and ns.GetBarColor("shieldBlockBar")
            or { r = 0.20, g = 0.55, b = 1.00, a = 0.90 }
        shieldBlockBar:SetStatusBarColor(
            shieldColor.r or 0.20, shieldColor.g or 0.55, shieldColor.b or 1.00, shieldColor.a or 0.90
        )

        local duration, expirationTime = GetShieldBlockAuraData()
        if type(duration) ~= "number" or type(expirationTime) ~= "number" or duration <= 0 or expirationTime <= 0 then
            shieldBlockBar:Hide()
            return
        end

        local remaining = math.max(expirationTime - GetCurrentTime(), 0)
        shieldBlockBar:SetMinMaxValues(0, duration)
        shieldBlockBar:SetValue(remaining)
        shieldBlockBar:Show()
    end

    -- Create the rage bar on first call
    if not ns.warriorRageBar then
        local bar = rawget(_G, "SuperSwingTimerWarriorRageBar")
        if not bar then
            bar = CreateFrame("StatusBar", "SuperSwingTimerWarriorRageBar", UIParent)
        end
        bar:SetStatusBarTexture(ns.GetBarTexture and ns.GetBarTexture() or "Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetSize((ns.mhBar and ns.mhBar:GetWidth()) or ns.BAR_WIDTH or 240, 4)
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(0)
        bar:SetFrameStrata((ns.mhBar and ns.mhBar:GetFrameStrata()) or "MEDIUM")
        bar:SetFrameLevel(((ns.mhBar and ns.mhBar:GetFrameLevel()) or 0) + 1)
        bar:EnableMouse(false)
        local statusBarTexture = bar:GetStatusBarTexture()
        if statusBarTexture then
            statusBarTexture:SetDrawLayer(ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK")
        end

        local backgroundTexture = bar.backgroundTexture or bar:CreateTexture(nil, "BACKGROUND")
        backgroundTexture:SetAllPoints(true)
        local backgroundColor = ns.GetBarBackgroundColor and ns.GetBarBackgroundColor()
            or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBackgroundColor)
        backgroundColor = backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
        backgroundTexture:SetColorTexture(backgroundColor.r or 0, backgroundColor.g or 0, backgroundColor.b or 0, 1)
        backgroundTexture:SetAlpha(backgroundColor.a ~= nil and backgroundColor.a or 0.5)

        if not bar.borderTextures then
            local borderColor = ns.GetBarBorderColor and ns.GetBarBorderColor()
                or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBorderColor)
            borderColor = borderColor or { r = 0, g = 0, b = 0, a = 1 }
            local borderTop = bar:CreateTexture(nil, "OVERLAY")
            borderTop:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
            borderTop:SetPoint("TOPLEFT", -1, 1)
            borderTop:SetPoint("TOPRIGHT", 1, 1)
            borderTop:SetHeight(1)

            local borderBottom = bar:CreateTexture(nil, "OVERLAY")
            borderBottom:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
            borderBottom:SetPoint("BOTTOMLEFT", -1, -1)
            borderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
            borderBottom:SetHeight(1)

            local borderLeft = bar:CreateTexture(nil, "OVERLAY")
            borderLeft:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
            borderLeft:SetPoint("TOPLEFT", -1, 1)
            borderLeft:SetPoint("BOTTOMLEFT", -1, -1)
            borderLeft:SetWidth(1)

            local borderRight = bar:CreateTexture(nil, "OVERLAY")
            borderRight:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
            borderRight:SetPoint("TOPRIGHT", 1, 1)
            borderRight:SetPoint("BOTTOMRIGHT", 1, -1)
            borderRight:SetWidth(1)

            bar.borderTextures = { top = borderTop, bottom = borderBottom, left = borderLeft, right = borderRight }
        end

        bar.backgroundTexture = backgroundTexture
        bar.statusBarTexture = statusBarTexture
        bar:SetAlpha(0)
        ns.warriorRageBar = bar
    end

    -- ============================================================
    -- Deep Wounds target debuff duration bar (Warrior)
    -- ============================================================
    local DEEP_WOUND_BAR_HEIGHT = 6
    local DEEP_WOUND_FALLBACK_DURATION = 12
    local DEEP_WOUND_GLOW_WINDOW = 4
    local deepWoundsBar = nil
    local nextDeepWoundsUpdateAt = 0

    local function SetDeepWoundsGlow(bar, remaining)
        if not bar or not bar.glowBorder then return end
        local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= DEEP_WOUND_GLOW_WINDOW
        for _, edge in ipairs(bar.glowBorder) do
            if shouldGlow then edge:Show() else edge:Hide() end
        end
    end

    local function EnsureDeepWoundsBar()
        if deepWoundsBar then return deepWoundsBar end
        if not ns.mhBar then return nil end

        deepWoundsBar = CreateFrame("StatusBar", nil, ns.mhBar)
        deepWoundsBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        deepWoundsBar:SetStatusBarColor(0.70, 0.15, 0.15, 0.90)  -- dark red
        deepWoundsBar:SetMinMaxValues(0, 1)
        deepWoundsBar:SetValue(0)
        deepWoundsBar:SetHeight(DEEP_WOUND_BAR_HEIGHT)
        deepWoundsBar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, 2)
        deepWoundsBar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, 2)
        deepWoundsBar:EnableMouse(false)

        local bg = deepWoundsBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        deepWoundsBar.backgroundTexture = bg

        local glowBorder = {}
        for _, edgeDef in ipairs({
            { "TOPLEFT", "TOPRIGHT", "Height", 1, -1, 1, 1, 1 },
            { "BOTTOMLEFT", "BOTTOMRIGHT", "Height", 1, -1, -1, 1, -1 },
            { "TOPLEFT", "BOTTOMLEFT", "Width", 1, -1, 1, -1, -1 },
            { "TOPRIGHT", "BOTTOMRIGHT", "Width", 1, 1, 1, 1, -1 }
        }) do
            local tex = deepWoundsBar:CreateTexture(nil, "OVERLAY")
            tex:SetPoint(edgeDef[1], deepWoundsBar, edgeDef[2], edgeDef[4], edgeDef[5])
            tex:SetPoint(edgeDef[3], edgeDef[6], edgeDef[7], edgeDef[8])
            tex:SetColorTexture(0.85, 0.20, 0.20, 0.85)
            tex:Hide()
            glowBorder[#glowBorder + 1] = tex
        end
        deepWoundsBar.glowBorder = glowBorder

        -- Spell icon (left side)
        local dwIcon = deepWoundsBar:CreateTexture(nil, "OVERLAY")
        dwIcon:SetSize(DEEP_WOUND_BAR_HEIGHT, DEEP_WOUND_BAR_HEIGHT)
        dwIcon:SetPoint("LEFT", deepWoundsBar, "LEFT", 2, 0)
        local dwTexPath = GetSpellTexture and GetSpellTexture(12721)
        if dwTexPath then dwIcon:SetTexture(dwTexPath) end
        deepWoundsBar.icon = dwIcon

        local label = deepWoundsBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", deepWoundsBar, "CENTER", 0, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        label:SetTextColor(1.0, 0.85, 0.25, 0.95)
        label:SetText("DW")
        deepWoundsBar.label = label

        deepWoundsBar:Hide()
        ns.warriorDeepWoundsBar = deepWoundsBar
        return deepWoundsBar
    end

    local function GetTargetDeepWoundsData()
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId =
                GetHarmfulAuraData("target", index, "HARMFUL")
            if not auraName then break end

            local isDeepWound = false
            if type(auraSpellId) == "number" and ns.DEEP_WOUND_IDS and ns.DEEP_WOUND_IDS[auraSpellId] then
                isDeepWound = true
            elseif auraName == ns.DEEP_WOUND_NAME then
                isDeepWound = true
            end

            if isDeepWound and (caster == "player" or caster == nil) then
                return duration, expirationTime
            end
        end
        return nil
    end

    local function UpdateWarriorDeepWoundsBar(force)
        local now = GetCurrentTime()
        if not force and now < nextDeepWoundsUpdateAt then return end
        nextDeepWoundsUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showWarriorDeepWoundsBar == false then
            if deepWoundsBar then deepWoundsBar:Hide() end
            return
        end

        local bar = EnsureDeepWoundsBar()
        if not bar or not ns.mhBar then return end

        if not UnitExists or not UnitExists("target")
            or (UnitCanAttack and not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        if (ns.mhBar:GetAlpha() or 0) <= 0 then
            bar:Hide()
            return
        end

        local duration, expirationTime = GetTargetDeepWoundsData()
        if not duration and not expirationTime then
            SetDeepWoundsGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then
            duration = DEEP_WOUND_FALLBACK_DURATION
        end

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetDeepWoundsGlow(bar, remaining)

        if bar.label and bar.label.SetText then
            bar.label:SetText(string.format("%.0f", math.max(remaining, 0)))
        end
        if bar.icon and bar.icon.SetTexture then
            local texPath = GetSpellTexture and GetSpellTexture(12721)
            if texPath then bar.icon:SetTexture(texPath) end
        end

        bar:Show()
    end

    -- ============================================================
    -- Sunder Armor target debuff bar (Warrior armor reduction, stacks 1-5)
    -- ============================================================
    local SUNDER_ARMOR_BAR_HEIGHT = 6
    local SUNDER_ARMOR_GLOW_WINDOW = 4
    local sunderArmorBar = nil
    local nextSunderArmorUpdateAt = 0

    local function SetSunderArmorGlow(bar, remaining)
        if not bar then return end
        if bar.glowBorder then
            local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= SUNDER_ARMOR_GLOW_WINDOW
            for _, edge in ipairs(bar.glowBorder) do
                if shouldGlow then edge:Show() else edge:Hide() end
            end
        end
    end

    local function EnsureSunderArmorBar()
        if sunderArmorBar then return sunderArmorBar end
        if not ns.mhBar then return nil end

        sunderArmorBar = CreateFrame("StatusBar", nil, ns.mhBar)
        sunderArmorBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        sunderArmorBar:SetStatusBarColor(0.55, 0.35, 0.15, 0.90)  -- brown/earth
        sunderArmorBar:SetMinMaxValues(0, 1)
        sunderArmorBar:SetValue(0)
        sunderArmorBar:SetHeight(SUNDER_ARMOR_BAR_HEIGHT)
        sunderArmorBar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, 2)
        sunderArmorBar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, 2)
        sunderArmorBar:EnableMouse(false)

        local bg = sunderArmorBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        sunderArmorBar.backgroundTexture = bg

        local glowBorder = {}
        for _, edgeDef in ipairs({
            { "TOPLEFT", "TOPRIGHT", "Height", 1, -1, 1, 1, 1 },
            { "BOTTOMLEFT", "BOTTOMRIGHT", "Height", 1, -1, -1, 1, -1 },
            { "TOPLEFT", "BOTTOMLEFT", "Width", 1, -1, 1, -1, -1 },
            { "TOPRIGHT", "BOTTOMRIGHT", "Width", 1, 1, 1, 1, -1 }
        }) do
            local tex = sunderArmorBar:CreateTexture(nil, "OVERLAY")
            tex:SetPoint(edgeDef[1], sunderArmorBar, edgeDef[2], edgeDef[4], edgeDef[5])
            tex:SetPoint(edgeDef[3], edgeDef[6], edgeDef[7], edgeDef[8])
            tex:SetColorTexture(0.55, 0.35, 0.15, 0.85)
            tex:Hide()
            glowBorder[#glowBorder + 1] = tex
        end
        sunderArmorBar.glowBorder = glowBorder

        -- Stack count in center (1-5, large text)
        local stackText = sunderArmorBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        stackText:SetPoint("CENTER", sunderArmorBar, "CENTER", 0, 1)
        stackText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        stackText:SetTextColor(1.0, 0.85, 0.25, 0.95)
        stackText:SetText("")
        sunderArmorBar.stackText = stackText

        -- Spell icon (left side)
        local spellIcon = sunderArmorBar:CreateTexture(nil, "OVERLAY")
        spellIcon:SetSize(SUNDER_ARMOR_BAR_HEIGHT, SUNDER_ARMOR_BAR_HEIGHT)
        spellIcon:SetPoint("LEFT", sunderArmorBar, "LEFT", 2, 0)
        local texPath = GetSpellTexture and GetSpellTexture(7386)
        if texPath then spellIcon:SetTexture(texPath) end
        sunderArmorBar.icon = spellIcon

        sunderArmorBar:Hide()
        return sunderArmorBar
    end

    local function GetTargetSunderArmorData()
        local saName = ns.WARRIOR_SUNDER_ARMOR_NAME or (ns.GetSpellInfo and ns.GetSpellInfo(7386) or "Sunder Armor")
        if not saName then return nil end
        local saDuration, saExpiration, saStacks
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId, _, _, _, auraStackCount =
                GetHarmfulAuraData("target", index, "HARMFUL")
            if not auraName then break end
            local isSA = false
            if type(auraSpellId) == "number" and ns.WARRIOR_SUNDER_ARMOR_IDS and ns.WARRIOR_SUNDER_ARMOR_IDS[auraSpellId] then
                isSA = true
            elseif auraName == saName then
                isSA = true
            end
            if isSA and (caster == "player" or caster == nil) then
                saDuration = duration
                saExpiration = expirationTime
                saStacks = tonumber(auraStackCount) or 1
                break
            end
        end
        if saStacks then
            return saDuration, saExpiration, saStacks
        end
        return nil, nil, nil
    end

    local function UpdateWarriorSunderArmorBar(force)
        local now = GetCurrentTime()
        if not force and now < nextSunderArmorUpdateAt then return end
        nextSunderArmorUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showWarriorSunderArmorBar == false then
            if sunderArmorBar then sunderArmorBar:Hide() end
            return
        end

        local bar = EnsureSunderArmorBar()
        if not bar or not ns.mhBar then return end

        if type(UnitExists) ~= "function" or not UnitExists("target")
            or (type(UnitCanAttack) ~= "function" or not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        if ns.mhBar and ns.mhBar.GetAlpha and (ns.mhBar:GetAlpha() or 0) <= 0 then
            bar:Hide()
            return
        end

        local duration, expirationTime, stacks = GetTargetSunderArmorData()
        if not stacks then
            SetSunderArmorGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then duration = 30 end

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetSunderArmorGlow(bar, remaining)

        -- Show stack count 1-5 centered in bar
        if bar.stackText and bar.stackText.SetText then
            bar.stackText:SetText(tostring(stacks))
        end

        bar:Show()
    end

    -- Register Warrior OnUpdate hook (rage bar + shield block + cooldown badges)
    ns.RegisterOnUpdateHook(function (elapsed)
        if ns.UpdateWarriorRageBar then
            ns.UpdateWarriorRageBar()
        end
        if ns.UpdateWarriorShieldBlockBar then
            ns.UpdateWarriorShieldBlockBar(elapsed)
        end
        warriorVisualUpdateTimer = warriorVisualUpdateTimer + (elapsed or 0)
        if warriorVisualUpdateTimer >= WARRIOR_VISUAL_UPDATE_INTERVAL then
            warriorVisualUpdateTimer = 0
            UpdateWarriorCooldownBadges()
        end
        UpdateWarriorSlamBar()
        UpdateWarriorOverpowerFlash()
        UpdateWarriorDeepWoundsBar(false)
        UpdateWarriorSunderArmorBar(false)
        -- Restack all visible debuff bars above MH dynamically
        RestackDebuffBars({deepWoundsBar, ns.warriorShieldBlockBar, sunderArmorBar}, ns.mhBar)
        if ns.UpdateWarriorBuffIcons then ns.UpdateWarriorBuffIcons(elapsed) end
    end)

    ns.UpdateWarriorRageBar()
    ns.UpdateWarriorShieldBlockBar(0, true)
    UpdateWarriorDeepWoundsBar(true)
    UpdateWarriorSunderArmorBar(true)
    -- Restack after initial force-update
    RestackDebuffBars({deepWoundsBar, ns.warriorShieldBlockBar, sunderArmorBar}, ns.mhBar)

    -- Hook warrior queued attacks so each special gets its own tint.
    if ns.RegisterSpellcastSucceededHook then
        ns.RegisterSpellcastSucceededHook(function (unit, castGUIDOrSpellName, spellId)
            local spellToken = spellId ~= nil and spellId or castGUIDOrSpellName
            if unit == "player" then
                if ns.WARRIOR_HEROIC_STRIKE_SPELLS and ns.WARRIOR_HEROIC_STRIKE_SPELLS[spellToken] then
                    ApplyWarriorQueueTint(spellToken)
                elseif ns.WARRIOR_CLEAVE_SPELLS and ns.WARRIOR_CLEAVE_SPELLS[spellToken] then
                    ApplyWarriorQueueTint(spellToken)
                elseif ns.PAUSE_SWING_SPELLS and ns.PAUSE_SWING_SPELLS[spellToken] then
                    ApplyWarriorSlamTint(spellToken)
                end
            end
            if ns.UpdateWarriorQueueTint then
                ns.UpdateWarriorQueueTint()
            end
        end)
    end

    -- Phase 2: Warrior Flurry icon (stacks + duration, centered above all bars)
    local warriorFlurryIcon = nil
    ns.UpdateWarriorFlurryCounter = function ()
        if not ns.mhBar then return end
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if not db or db.showWarriorFlurryCounter == false then
            if warriorFlurryIcon then warriorFlurryIcon:Hide() end
            return
        end

        if not warriorFlurryIcon then
            warriorFlurryIcon = CreateFlurryIconFrame()
            warriorFlurryIcon:SetPoint("BOTTOM", ns.mhBar, "TOP", 0, 12)
        end

        local charges, expirationTime = GetFlurryBuffInfo()
        if not charges then
            warriorFlurryIcon:Hide()
            return
        end

        -- Update stack count
        warriorFlurryIcon.stackText:SetText("x" .. charges)

        -- Update duration remaining (GetTimePreciseSec shares the same monotonic
        -- game clock as UnitBuff's expirationTime — no offset alignment needed)
        if type(expirationTime) == "number" and expirationTime > 0 then
            local remaining = expirationTime - GetTimePreciseSec()
            if remaining > 0 then
                warriorFlurryIcon.durationText:SetText(string.format("%.1f", remaining))
                warriorFlurryIcon.durationText:Show()
            else
                warriorFlurryIcon.durationText:Hide()
            end
        else
            warriorFlurryIcon.durationText:Hide()
        end

        warriorFlurryIcon:Show()
    end

    -- ============================================================
    -- Phase 4: Warrior CD/Buff Duration Icon Group
    -- ============================================================
    local WARRIOR_RACIAL_SPELLS = {
        { spellId = 20572, name = "Blood Fury", label = "BF", kind = "buff" },
        { spellId = 26297, name = "Berserking", label = "BZ", kind = "buff" },
        { spellId = 20594, name = "Stoneform", label = "SF", kind = "buff" },
        { spellId = 58984, name = "Shadowmeld", label = "SM", kind = "buff" },
        { spellId = 20549, name = "War Stomp", label = "WS", kind = "cd" },
        { spellId = 28880, name = "Gift of the Naaru", label = "GN", kind = "buff" },
        { spellId = 20589, name = "Escape Artist", label = "EA", kind = "buff" },
        { spellId = 7744, name = "Will of the Forsaken", label = "WotF", kind = "buff" },
        { spellId = 20600, name = "Perception", label = "Per", kind = "buff" },
        { spellId = 28730, name = "Arcane Torrent", label = "AT", kind = "buff" },
    }
    local WARRIOR_TRACKED_SPELLS = {
        { spellId = 12292, name = "Death Wish", label = "DW", kind = "buff" },
        { spellId = 1719, name = "Recklessness", label = "Reck", kind = "buff" },
        { spellId = 12328, name = "Sweeping Strikes", label = "Sweep", kind = "buff" },
        { spellId = 20230, name = "Retaliation", label = "Retal", kind = "buff" },
        { spellId = 871, name = "Shield Wall", label = "SW", kind = "buff" },
        { spellId = 12975, name = "Last Stand", label = "LS", kind = "buff" },
        { spellId = 23920, name = "Spell Reflection", label = "SR", kind = "buff" },
        { spellId = 18499, name = "Berserker Rage", label = "BR", kind = "buff" },
        { spellId = 30033, name = "Rampage", label = "Ramp", kind = "buff" },
        { spellId = 2687, name = "Bloodrage", label = "BRg", kind = "buff" },
        { spellId = 12317, name = "Enrage", label = "ER", kind = "buff" },
        -- External buffs (party/raid-wide, consumables, not learned spells):
        { spellId = 2825, name = "Bloodlust", label = "BL", kind = "buff", external = true },
        { spellId = 32182, name = "Heroism", label = "Hero", kind = "buff", external = true },
        { spellId = 35476, name = "Drums of Battle", label = "DoB", kind = "buff", external = true },
        { spellId = 35477, name = "Drums of Speed", label = "DoS", kind = "buff", external = true },
        { spellId = 28507, name = "Haste Potion", label = "HP", kind = "buff", external = true },
    }
    for _, racial in ipairs(WARRIOR_RACIAL_SPELLS) do
        table.insert(WARRIOR_TRACKED_SPELLS, racial)
    end

    local warriorBuffIcons = {}
    local warriorBuffTimer = 0
    local WARRIOR_BUFF_UPDATE_INTERVAL = 0.15
    local WARRIOR_BUFF_ICON_GAP = 3

    local function GetWarriorSpellRemaining(info)
        -- Step 1: Scan helpful auras on the player (buffs)
        for index = 1, 40 do
            local auraName, duration, expirationTime, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then break end
            if auraSpellId == info.spellId or auraName == info.name then
                if type(expirationTime) == "number" and expirationTime > 0 then
                    return math.max(expirationTime - GetCurrentTime(), 0), math.max(duration or 1, 1)
                end
                return nil, nil
            end
        end
        -- Step 2: For CD-type, scan target harmful auras (debuffs)
        if info.kind == "cd" then
            if type(UnitExists) == "function" and UnitExists("target")
                and type(UnitCanAttack) == "function" and UnitCanAttack("player", "target") then
                for index = 1, 40 do
                    local debuffName, _, debuffDuration, debuffExpiration, caster, debuffSpellId = GetHarmfulAuraData("target", index)
                    if not debuffName then break end
                    if caster == "player" and (debuffSpellId == info.spellId or debuffName == info.name) then
                        if type(debuffExpiration) == "number" and debuffExpiration > 0 then
                            return math.max(debuffExpiration - GetCurrentTime(), 0), math.max(debuffDuration or 1, 1)
                        end
                        return nil, nil
                    end
                end
            end
            -- Step 3: Fall back to cooldown tracking
            local startTime, cdDuration
            if type(GetSpellCooldown) == "function" then
                startTime, cdDuration = GetSpellCooldown(info.spellId)
            elseif C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
                local ok, cdInfo = pcall(C_Spell.GetSpellCooldown, info.spellId)
                if ok and cdInfo then
                    startTime = cdInfo.startTime
                    cdDuration = cdInfo.duration
                end
            end
            if type(startTime) ~= "number" or type(cdDuration) ~= "number" or cdDuration <= 0 then
                return nil, nil
            end
            -- Filter out GCD (1.5s) from real cooldowns
            if cdDuration <= 2.5 then
                return nil, nil
            end
            local remaining = math.max((startTime + cdDuration) - GetCurrentTime(), 0)
            if remaining <= 0 then return nil, nil end
            return remaining, cdDuration
        end
        return nil, nil
    end

    local function CreateWarriorBuffIcons()
        if #warriorBuffIcons > 0 then return end
        local iconSize = SuperSwingTimerDB and SuperSwingTimerDB.warriorBuffIconSize or 25
        if type(iconSize) ~= "number" or iconSize <= 0 then iconSize = 25 end

        for _, spell in ipairs(WARRIOR_TRACKED_SPELLS) do
            local icon = CreateFrame("Frame", nil, UIParent)
            icon:SetSize(iconSize, iconSize)
            icon:SetFrameStrata("DIALOG")
            icon:EnableMouse(false)
            icon.texture = icon:CreateTexture(nil, "BACKGROUND")
            icon.texture:SetAllPoints()
            icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            local texPath = GetSpellTexture and GetSpellTexture(spell.spellId)
            if texPath then icon.texture:SetTexture(texPath) end
            icon.glow = icon:CreateTexture(nil, "OVERLAY", nil, 7)
            icon.glow:SetAllPoints()
            icon.glow:SetColorTexture(1, 0.85, 0, 0)
            icon.glow:SetBlendMode("ADD")
            -- 4-edge outline border (not a full-face overlay)
            icon.border = {}
            icon.border.top = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.top:SetPoint("TOPLEFT", -1, 1)
            icon.border.top:SetPoint("TOPRIGHT", 1, 1)
            icon.border.top:SetHeight(1)
            icon.border.top:SetColorTexture(0, 0, 0, 0.65)
            icon.border.bottom = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.bottom:SetPoint("BOTTOMLEFT", -1, -1)
            icon.border.bottom:SetPoint("BOTTOMRIGHT", 1, -1)
            icon.border.bottom:SetHeight(1)
            icon.border.bottom:SetColorTexture(0, 0, 0, 0.65)
            icon.border.left = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.left:SetPoint("TOPLEFT", -1, 1)
            icon.border.left:SetPoint("BOTTOMLEFT", -1, -1)
            icon.border.left:SetWidth(1)
            icon.border.left:SetColorTexture(0, 0, 0, 0.65)
            icon.border.right = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.right:SetPoint("TOPRIGHT", 1, 1)
            icon.border.right:SetPoint("BOTTOMRIGHT", 1, -1)
            icon.border.right:SetWidth(1)
            icon.border.right:SetColorTexture(0, 0, 0, 0.65)
            icon.durationText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            icon.durationText:SetPoint("CENTER", icon, "TOP", 0, 0)
            icon.durationText:SetJustifyH("CENTER")
            icon.durationText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            icon.durationText:SetTextColor(1, 1, 1, 0.95)
            icon.durationText:Hide()
            icon:Hide()
            icon.spellId = spell.spellId
            icon.label = spell.label
            icon.kind = spell.kind
            table.insert(warriorBuffIcons, icon)
        end
    end

    ns.UpdateWarriorBuffIcons = function (elapsed)
        CreateWarriorBuffIcons()
        if #warriorBuffIcons == 0 then return end

        warriorBuffTimer = warriorBuffTimer + (elapsed or 0.03)
        if warriorBuffTimer < WARRIOR_BUFF_UPDATE_INTERVAL then return end
        warriorBuffTimer = 0

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showWarriorBuffIcons == false then
            for _, icon in ipairs(warriorBuffIcons) do
                if icon and icon.Hide then icon:Hide() end
            end
            return
        end
        if ns.playerInCombat ~= true then
            for _, icon in ipairs(warriorBuffIcons) do
                if icon and icon.Hide then icon:Hide() end
            end
            return
        end

        local iconSize = SuperSwingTimerDB and SuperSwingTimerDB.warriorBuffIconSize or 25
        if type(iconSize) ~= "number" or iconSize <= 0 then iconSize = 25 end

        local activeIcons = {}
        for _, icon in ipairs(warriorBuffIcons) do
            if icon and icon.spellId then
                for _, spell in ipairs(WARRIOR_TRACKED_SPELLS) do
                    if spell.spellId == icon.spellId then
                        local remaining, totalDuration = GetWarriorSpellRemaining(spell)
                        if type(remaining) == "number" and remaining > 0
                            and type(totalDuration) == "number" and totalDuration > 0 then
                            table.insert(activeIcons, {
                                icon = icon,
                                remaining = remaining,
                                totalDuration = totalDuration
                            })
                        else
                            if icon.Hide then icon:Hide() end
                        end
                        break
                    end
                end
            elseif icon and icon.Hide then
                icon:Hide()
            end
        end

        local numActive = #activeIcons
        if numActive == 0 then return end

        local referenceBar = ns.mhBar
        if not referenceBar then return end
        -- Position icons above all visible target debuff duration bars
        local iconY = GetDebuffStackOffset({
            deepWoundsBar,
            shieldBlockBar,
            sunderArmorBar,
        }, ns.mhBar)
        local barGetWidth = referenceBar.GetWidth
        if not barGetWidth then return end

        for idx, entry in ipairs(activeIcons) do
            local icon = entry.icon
            local remaining = entry.remaining
            local totalDuration = entry.totalDuration

            if icon.SetSize then icon:SetSize(iconSize, iconSize) end

            -- Right-align icons
            local xOffset = -(numActive - idx) * (iconSize + WARRIOR_BUFF_ICON_GAP)
            local rightAlign = -(iconSize / 2)
            local finalX = rightAlign + xOffset

            if icon.ClearAllPoints then icon:ClearAllPoints() end
            if icon.SetPoint then icon:SetPoint("BOTTOM", referenceBar, "TOP", finalX, iconY) end

            -- No shading
            if icon.dim and icon.dim.SetColorTexture then
                icon.dim:SetColorTexture(0, 0, 0, 0)
            end

            -- Glow in last 4 seconds
            if icon.glow and icon.glow.SetColorTexture then
                local shouldGlow = remaining <= 4 and remaining > 0
                if shouldGlow and totalDuration > 0 then
                    local pulseAlpha = 0.15 + 0.40 * (0.5 + 0.5 * math.sin(GetCurrentTime() * 6))
                    icon.glow:SetColorTexture(1, 0.85, 0, pulseAlpha)
                    if icon.glow.Show then icon.glow:Show() end
                elseif icon.glow.Hide then
                    icon.glow:Hide()
                end
            end

            -- Countdown text
            if icon.durationText and icon.durationText.SetText then
                local text = remaining >= 3 and string.format("%.0f", remaining) or string.format("%.1f", remaining)
                icon.durationText:SetText(text)
                if icon.durationText.Show then icon.durationText:Show() end
            end

            if icon.Show then icon:Show() end
        end
    end

    ns.UpdateWarriorSunderArmorBar = UpdateWarriorSunderArmorBar
end

local function SetupEnhShaman()
    local function ApplyWeaveMarkerTexture(texture, iconTexture, fallbackTexture, size, alpha, color)
        if not texture then
            return
        end

        texture:SetWidth(size)
        texture:SetHeight(size)
        texture:SetAlpha(alpha)

        if iconTexture then
            texture:SetTexture(iconTexture)
            texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            texture:SetBlendMode("BLEND")
            texture:SetVertexColor(1, 1, 1, 1)
        else
            texture:SetTexture(fallbackTexture)
            texture:SetTexCoord(0, 1, 0, 1)
            texture:SetBlendMode(ns.GetIndicatorBlendMode and ns.GetIndicatorBlendMode() or "ADD")
            texture:SetVertexColor(color.r, color.g, color.b, 1)
        end
    end

    local function ApplyWeaveSparkTexture(texture, iconTexture, fallbackTexture, width, height, alpha, color)
        if not texture then
            return
        end

        texture:SetWidth(width)
        texture:SetHeight(height)
        texture:SetAlpha(alpha)

        if iconTexture then
            texture:SetTexture(iconTexture)
            texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            texture:SetBlendMode("BLEND")
            texture:SetVertexColor(1, 1, 1, 1)
        else
            texture:SetTexture(fallbackTexture)
            texture:SetTexCoord(0, 1, 0, 1)
            texture:SetBlendMode(ns.GetIndicatorBlendMode and ns.GetIndicatorBlendMode() or "ADD")
            -- Cast spark uses solid red so it reads clearly above the MH bar fill
            texture:SetVertexColor(1, 0, 0, 1)
        end
    end

    local function UpdateWeaveVisuals()
        if (not ns.weaveSpark or not ns.weaveTriangleTop or not ns.weaveTriangleBottom) and ns.OnBarsCreated then
            ns.OnBarsCreated()
        end

        if not ns.weaveSpark or not ns.weaveTriangleTop or not ns.weaveTriangleBottom then
            return
        end

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if (db and db.showWeaveAssist == false) or (ns.IsMinimalMode and ns.IsMinimalMode()) then
            ns.weaveSpark:Hide()
            if ns.weaveSparkOH then ns.weaveSparkOH:Hide() end
            ns.weaveTriangleTop:Hide()
            ns.weaveTriangleBottom:Hide()
            return
        end

        local info = ns.GetWeaveDisplayInfo and ns.GetWeaveDisplayInfo() or nil
        if not info then
            ns.weaveSpark:Hide()
            if ns.weaveSparkOH then ns.weaveSparkOH:Hide() end
            ns.weaveTriangleTop:Hide()
            ns.weaveTriangleBottom:Hide()
            return
        end

        local timer = ns.timers and ns.timers.mh
        if not timer or timer.state ~= "swinging" or not timer.duration or timer.duration <= 0 then
            ns.weaveSpark:Hide()
            if ns.weaveSparkOH then ns.weaveSparkOH:Hide() end
            ns.weaveTriangleTop:Hide()
            ns.weaveTriangleBottom:Hide()
            return
        end

        local showSpark = info.isCasting == true
        local barWidth = (ns.mhBar and ns.mhBar:GetWidth()) or (ns.mhBar and ns.mhBar.barWidth) or ns.BAR_WIDTH or 0
        local barAnchor = GetOverlayParent(ns.mhBar)
        local ohVisible = ns.ohBar and ns.ohBar:IsShown() and (ns.ohBar:GetAlpha() or 0) > 0
        local ohHeight = ns.ohBar and ohVisible and ns.ohBar:GetHeight() or 0
        local hasOffHand = ohVisible and ohHeight > 0

        local markerPos = (math.max(0, math.min(info.markerFraction or 0, 1))) * barWidth
        if markerPos < 0 then
            markerPos = 0
        elseif markerPos > (barWidth or markerPos) then
            markerPos = barWidth
        end

        local color = info.color or { r = 0.7, g = 0.8, b = 1, a = 1 }
        local iconTexture = info.iconTexture
        local triangleGap = ns.GetWeaveTriangleGap and ns.GetWeaveTriangleGap() or 2
        local triangleSize = ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14
        local topFallbackTexture = ns.GetWeaveTriangleTopTexture and ns.GetWeaveTriangleTopTexture()
            or "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow"
        local bottomFallbackTexture = ns.GetWeaveTriangleBottomTexture and ns.GetWeaveTriangleBottomTexture()
            or "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow"
        local sparkFallbackTexture = ns.GetWeaveSparkTexture and ns.GetWeaveSparkTexture()
            or "Interface\\CastingBar\\UI-CastingBar-Spark"
        local sparkWidth = ns.GetWeaveSparkWidth and ns.GetWeaveSparkWidth() or 14
        local sparkHeight = ns.GetWeaveSparkHeight and ns.GetWeaveSparkHeight() or 30
        local clampedSparkHeight = math.max(
            1, math.min(sparkHeight, (ns.mhBar and ns.mhBar:GetHeight()) or ns.BAR_HEIGHT or sparkHeight)
        )
        local sparkAlpha = ns.GetWeaveSparkAlpha and ns.GetWeaveSparkAlpha() or 0.95
        local triangleAlpha = ns.GetWeaveTriangleAlpha and ns.GetWeaveTriangleAlpha() or 1
        local sparkPos = 0
        local sparkVisualWidth = sparkWidth
        local sparkVisualHeight = clampedSparkHeight

        if showSpark then
            -- Spark is driven purely by the cast's own progress (0 -> 1) and
            -- intentionally ignores MH swing fractions. The weave spark should
            -- track the cast itself, not where MH happens to be in its swing.
            local castProgress = math.max(0, math.min(info.castProgress or 0, 1))
            sparkPos = castProgress * barWidth
            markerPos = sparkPos
        end

        if sparkPos < 0 then
            sparkPos = 0
        elseif sparkPos > (barWidth or sparkPos) then
            sparkPos = barWidth
        end

        -- MH spark
        ns.weaveSpark:ClearAllPoints()
        ns.weaveSpark:SetPoint("CENTER", ns.mhBar, "LEFT", sparkPos, 0)
        ApplyWeaveSparkTexture(
            ns.weaveSpark, nil, sparkFallbackTexture, sparkVisualWidth, sparkVisualHeight, sparkAlpha, color
        )
        ns.weaveSpark:SetShown(showSpark)

        -- OH spark (mirrors MH spark when dual-wielding)
        if ns.weaveSparkOH then
            local ohSparkHeight = math.max(1, math.min(sparkHeight, (ns.ohBar and ns.ohBar:GetHeight()) or sparkHeight))
            ns.weaveSparkOH:ClearAllPoints()
            ns.weaveSparkOH:SetPoint("CENTER", ns.ohBar, "LEFT", sparkPos, 0)
            ApplyWeaveSparkTexture(
                ns.weaveSparkOH, nil, sparkFallbackTexture, sparkVisualWidth, ohSparkHeight, sparkAlpha, color
            )
            ns.weaveSparkOH:SetShown(showSpark and hasOffHand)
        end

        -- Top triangle: always above MH bar
        ns.weaveTriangleTop:ClearAllPoints()
        ns.weaveTriangleTop:SetPoint("BOTTOM", barAnchor, "TOPLEFT", markerPos, triangleGap)
        ApplyWeaveMarkerTexture(
            ns.weaveTriangleTop, iconTexture, topFallbackTexture, triangleSize, triangleAlpha, color
        )
        ns.weaveTriangleTop:Show()

        -- Bottom triangle: below OH when visible, below MH otherwise
        local bottomAnchor = hasOffHand and ns.ohBar and GetOverlayParent(ns.ohBar) or barAnchor
        ns.weaveTriangleBottom:ClearAllPoints()
        ns.weaveTriangleBottom:SetPoint("TOP", bottomAnchor, "BOTTOMLEFT", markerPos, -triangleGap)
        ApplyWeaveMarkerTexture(
            ns.weaveTriangleBottom, iconTexture, bottomFallbackTexture, triangleSize, triangleAlpha, color
        )
        ns.weaveTriangleBottom:Show()
        if ns.weaveMarker then
            ns.weaveMarker:SetShown(showSpark)
        end
    end

    local LIGHTNING_SHIELD_RECT_WIDTH = 5
    local LIGHTNING_SHIELD_RECT_GAP = 1
    local LIGHTNING_SHIELD_NUM_RECTS = 3
    local LIGHTNING_SHIELD_BAR_GAP_DEFAULT = 6

    ns.OnBarsCreated = function ()
        if not ns.mhBar then
            return
        end
        if ns.weaveSpark and ns.weaveTriangleTop and ns.weaveTriangleBottom and ns.shamanLightningContainer
            and ns.shamanLightningRects then
            return
        end

        local barParent = GetOverlayParent(ns.mhBar)
        local weaveOverlayFrame = CreateFrame("Frame", nil, barParent)
        weaveOverlayFrame:SetAllPoints(barParent)
        weaveOverlayFrame:SetFrameStrata(barParent:GetFrameStrata())
        weaveOverlayFrame:SetFrameLevel((barParent:GetFrameLevel() or 0) + 6)
        weaveOverlayFrame:EnableMouse(false)

        -- Weave spark uses a dedicated overlay frame above the bars so it stays visible
        -- even when the bar fill / border draw layers are raised.
        local weaveSpark = weaveOverlayFrame:CreateTexture(nil, "OVERLAY")
        weaveSpark:SetTexture(
            ns.GetWeaveSparkTexture and ns.GetWeaveSparkTexture()
                or "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_FullWhite"
        )
        weaveSpark:SetDrawLayer("OVERLAY", 7)
        weaveSpark:SetBlendMode(ns.GetIndicatorBlendMode and ns.GetIndicatorBlendMode() or "ADD")
        weaveSpark:SetAlpha(ns.GetWeaveSparkAlpha and ns.GetWeaveSparkAlpha() or 0.95)
        weaveSpark:SetWidth(ns.GetWeaveSparkWidth and ns.GetWeaveSparkWidth() or 14)
        weaveSpark:SetHeight(
            math.max(
                1,
                math.min(
                    (ns.GetWeaveSparkHeight and ns.GetWeaveSparkHeight() or 30),
                    (ns.mhBar and ns.mhBar:GetHeight()) or (ns.BAR_HEIGHT or 30)
                )
            )
        )
        weaveSpark:SetPoint("CENTER", weaveOverlayFrame, "LEFT", 0, 0)

        local weaveTriangleTop = weaveOverlayFrame:CreateTexture(nil, "OVERLAY")
        weaveTriangleTop:SetTexture(
            ns.GetWeaveTriangleTopTexture and ns.GetWeaveTriangleTopTexture()
                or "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow"
        )
        if ns.SetTextureLayerAboveBar then
            ns.SetTextureLayerAboveBar(
                weaveTriangleTop, ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY",
                ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK"
            )
        else
            weaveTriangleTop:SetDrawLayer(ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY", 7)
        end
        weaveTriangleTop:SetBlendMode(ns.GetIndicatorBlendMode and ns.GetIndicatorBlendMode() or "ADD")
        weaveTriangleTop:SetAlpha(ns.GetWeaveTriangleAlpha and ns.GetWeaveTriangleAlpha() or 1)
        weaveTriangleTop:SetWidth(ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14)
        weaveTriangleTop:SetHeight(ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14)

        local weaveTriangleBottom = weaveOverlayFrame:CreateTexture(nil, "OVERLAY")
        weaveTriangleBottom:SetTexture(
            ns.GetWeaveTriangleBottomTexture and ns.GetWeaveTriangleBottomTexture()
                or "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow"
        )
        if ns.SetTextureLayerAboveBar then
            ns.SetTextureLayerAboveBar(
                weaveTriangleBottom, ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY",
                ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK"
            )
        else
            weaveTriangleBottom:SetDrawLayer(ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY", 7)
        end
        weaveTriangleBottom:SetBlendMode(ns.GetIndicatorBlendMode and ns.GetIndicatorBlendMode() or "ADD")
        weaveTriangleBottom:SetAlpha(ns.GetWeaveTriangleAlpha and ns.GetWeaveTriangleAlpha() or 1)
        weaveTriangleBottom:SetWidth(ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14)
        weaveTriangleBottom:SetHeight(ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14)

        -- OH spark: mirrors MH spark when dual-wielding
        local weaveSparkOH = nil
        if ns.ohBar then
            local ohOverlayFrame = CreateFrame("Frame", nil, GetOverlayParent(ns.ohBar) or ns.ohBar)
            ohOverlayFrame:SetAllPoints(GetOverlayParent(ns.ohBar) or ns.ohBar)
            ohOverlayFrame:SetFrameStrata((GetOverlayParent(ns.ohBar) or ns.ohBar):GetFrameStrata())
            ohOverlayFrame:SetFrameLevel(((GetOverlayParent(ns.ohBar) or ns.ohBar):GetFrameLevel() or 0) + 6)
            ohOverlayFrame:EnableMouse(false)

            weaveSparkOH = ohOverlayFrame:CreateTexture(nil, "OVERLAY")
            weaveSparkOH:SetTexture(
                ns.GetWeaveSparkTexture and ns.GetWeaveSparkTexture()
                    or "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_FullWhite"
            )
            weaveSparkOH:SetDrawLayer("OVERLAY", 7)
            weaveSparkOH:SetBlendMode(ns.GetIndicatorBlendMode and ns.GetIndicatorBlendMode() or "ADD")
            weaveSparkOH:SetAlpha(ns.GetWeaveSparkAlpha and ns.GetWeaveSparkAlpha() or 0.95)
            weaveSparkOH:SetWidth(ns.GetWeaveSparkWidth and ns.GetWeaveSparkWidth() or 14)
            weaveSparkOH:SetHeight(
                math.max(
                    1,
                    math.min(
                        (ns.GetWeaveSparkHeight and ns.GetWeaveSparkHeight() or 30),
                        (ns.ohBar and ns.ohBar:GetHeight()) or (ns.BAR_HEIGHT or 30)
                    )
                )
            )
            weaveSparkOH:SetPoint("CENTER", ohOverlayFrame, "LEFT", 0, 0)
            weaveSparkOH:Hide()
        end

        weaveSpark:Hide()
        weaveTriangleTop:Hide()
        weaveTriangleBottom:Hide()

        ns.weaveSpark = weaveSpark
        ns.weaveSparkOH = weaveSparkOH
        ns.weaveTriangleTop = weaveTriangleTop
        ns.weaveTriangleBottom = weaveTriangleBottom
        ns.weaveMarker = weaveSpark

        -- Lightning Shield / Water Shield charge tracker: 3 thin vertical rects left of MH bar
        if not ns.shamanLightningContainer then
            local shieldParent = GetOverlayParent(ns.mhBar) or UIParent
            local shieldContainer = CreateFrame("Frame", nil, shieldParent)
            shieldContainer:SetWidth(1)
            shieldContainer:SetHeight(1)
            shieldContainer:SetFrameStrata((ns.mhBar and ns.mhBar:GetFrameStrata()) or "MEDIUM")
            shieldContainer:SetFrameLevel(((ns.mhBar and ns.mhBar:GetFrameLevel()) or 0) + 3)
            shieldContainer:EnableMouse(false)
            shieldContainer:Hide()

            local rects = {}
            for shieldIdx = 1, LIGHTNING_SHIELD_NUM_RECTS do
                local rect = shieldContainer:CreateTexture(nil, "OVERLAY")
                rect:SetWidth(LIGHTNING_SHIELD_RECT_WIDTH)
                rect:SetHeight(1)
                if shieldIdx == 1 then
                    rect:SetPoint("LEFT", shieldContainer, "LEFT", 0, 0)
                else
                    rect:SetPoint("LEFT", rects[shieldIdx - 1], "RIGHT", LIGHTNING_SHIELD_RECT_GAP, 0)
                end
                rect:SetColorTexture(0.25, 0.72, 1.0, 0.9)
                rect:Hide()
                rects[shieldIdx] = rect
            end

            ns.shamanLightningContainer = shieldContainer
            ns.shamanLightningRects = rects
        end
    end

    -- Phase 2: Shaman Flurry icon (stacks + duration, centered above all bars)
    local shamanFlurryIcon = nil
    local function UpdateShamanFlurryIcon()
        if not ns.mhBar then
            return
        end

        if not shamanFlurryIcon then
            shamanFlurryIcon = CreateFlurryIconFrame()
            shamanFlurryIcon:SetPoint("BOTTOM", ns.mhBar, "TOP", 0, 12)
        end

        local charges, expirationTime = GetFlurryBuffInfo()
        if not charges then
            shamanFlurryIcon:Hide()
            return
        end

        -- Update stack count
        shamanFlurryIcon.stackText:SetText("x" .. charges)

        -- Update duration remaining (direct GetTimePreciseSec — same clock domain as expirationTime)
        if type(expirationTime) == "number" and expirationTime > 0 then
            local clockNow = (GetTimePreciseSec and GetTimePreciseSec()) or GetCurrentTime()
            local remaining = expirationTime - clockNow
            if remaining > 0 then
                shamanFlurryIcon.durationText:SetText(string.format("%.1f", remaining))
                shamanFlurryIcon.durationText:Show()
            else
                shamanFlurryIcon.durationText:Hide()
            end
        else
            shamanFlurryIcon.durationText:Hide()
        end

        shamanFlurryIcon:Show()
    end

    local function GetShamanCooldownRemaining(spellId)
        local startTime, duration = QuerySpellCooldown(spellId)
        if type(startTime) ~= "number" or type(duration) ~= "number" or duration <= 0 then
            return nil
        end

        local remaining = (startTime + duration) - GetCurrentTime()
        if remaining <= 0 then
            return nil
        end

        return remaining
    end

    local function GetShamanAuraRemaining(spellId, spellName)
        for index = 1, 40 do
            local auraName, _, expirationTime, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then
                break
            end
            if auraSpellId == spellId or auraName == spellName then
                if type(expirationTime) == "number" and expirationTime > 0 then
                    return math.max(expirationTime - GetCurrentTime(), 0)
                end
                return nil
            end
        end
        return nil
    end

    local function UpdateShamanStormstrikeBadge()
        if not ns.mhBar then
            return
        end

        local badge = ns.mhBar.shamanStormstrikeText
        if not badge then
            badge = ns.mhBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            badge:SetPoint("TOPLEFT", ns.mhBar, "TOPRIGHT", 3, 2)
            badge:SetJustifyH("LEFT")
            badge:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            badge:SetTextColor(0.25, 0.85, 1.0, 0.95)
            ns.mhBar.shamanStormstrikeText = badge
        end

        local remaining = GetShamanCooldownRemaining(ns.SHAMAN_STORMSTRIKE_ID)
        if remaining then
            badge:SetText(string.format("SS %.0fs", remaining))
            badge:Show()
        else
            badge:Hide()
        end
    end

    local function UpdateShamanisticRageBadge()
        if not ns.mhBar then
            return
        end

        local badge = ns.mhBar.shamanisticRageText
        if not badge then
            badge = ns.mhBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            badge:SetPoint("TOPLEFT", ns.mhBar, "TOPRIGHT", 3, -8)
            badge:SetJustifyH("LEFT")
            badge:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            badge:SetTextColor(0.15, 0.85, 1.0, 0.95)
            ns.mhBar.shamanisticRageText = badge
        end

        local auraRemaining = GetShamanAuraRemaining(ns.SHAMANISTIC_RAGE_ID, ns.SHAMANISTIC_RAGE_NAME)
        if auraRemaining then
            badge:SetText(string.format("SR %.0fs", auraRemaining))
            badge:Show()
            return
        end

        local remaining = GetShamanCooldownRemaining(ns.SHAMANISTIC_RAGE_ID)
        if remaining then
            badge:SetText(string.format("SR %.0fs", remaining))
            badge:Show()
        else
            badge:Hide()
        end
    end

    -- Phase 2: Shaman Windfury ICD tracker — 3s internal cooldown bar
    local WINDFURY_BUFF_NAMES = { "Windfury Weapon", "Windfury" }
    local WINDFURY_BUFF_NAME_LOOKUP = {}
    for _, windfuryBuffName in ipairs(WINDFURY_BUFF_NAMES) do
        WINDFURY_BUFF_NAME_LOOKUP[windfuryBuffName] = true
    end
    local WINDFURY_BUFF_SPELL_IDS = {
        [8232] = true,
        [8233] = true,
        [8234] = true,
        [8235] = true,
        [16316] = true,
        [16317] = true,
        [25585] = true,
        [33757] = true
    }
    local WINDFURY_ICD = 3.0
    local wfIcdBar = nil
    local wfLastSwingTime = 0
    local function PlayerHasWindfuryBuff()
        for index = 1, 40 do
            local auraName, _, _, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then
                break
            end

            if WINDFURY_BUFF_NAME_LOOKUP[auraName] then
                return true
            end

            if type(auraSpellId) == "number" and WINDFURY_BUFF_SPELL_IDS[auraSpellId] then
                return true
            end
        end

        return false
    end

    local function GetLastMainHandSwingTime()
        local timer = ns.timers and ns.timers.mh
        local liveLastSwing = timer and timer.lastSwing
        if type(liveLastSwing) == "number" and liveLastSwing > 0 then
            wfLastSwingTime = liveLastSwing
        end

        if type(wfLastSwingTime) == "number" and wfLastSwingTime > 0 then
            return wfLastSwingTime
        end

        return nil
    end

    ns.UpdateShamanWindfuryIcd = function ()
        if not ns.mhBar then return end
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if not db or db.showShamanWindfuryIcd == false then
            if wfIcdBar then wfIcdBar:Hide() end
            return
        end
        if not wfIcdBar then
            wfIcdBar = CreateFrame("StatusBar", nil, ns.mhBar)
            wfIcdBar:SetSize(3, (ns.mhBar:GetHeight() or 15))
            wfIcdBar:SetPoint("LEFT", ns.mhBar, "RIGHT", -2, 0)
            wfIcdBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            wfIcdBar:SetStatusBarColor(0, 1, 0, 0.85)
            wfIcdBar:SetMinMaxValues(0, WINDFURY_ICD)
            wfIcdBar:SetValue(WINDFURY_ICD)
            wfIcdBar:EnableMouse(false)
            local bg = wfIcdBar:CreateTexture(nil, "BACKGROUND")
            bg:SetColorTexture(0, 0, 0, 0.5)
            bg:SetAllPoints(true)
        end

        wfIcdBar:SetHeight((ns.mhBar:GetHeight() or 15))

        if not PlayerHasWindfuryBuff() then
            wfIcdBar:Hide()
            return
        end

        local lastSwingTime = GetLastMainHandSwingTime()
        if not lastSwingTime then
            wfIcdBar:Hide()
            return
        end

        local now = GetCurrentTime()
        local sinceLastSwing = math.max(now - lastSwingTime, 0)
        local icdRemaining = math.max(WINDFURY_ICD - sinceLastSwing, 0)
        wfIcdBar:SetValue(icdRemaining)
        if icdRemaining > 2.0 then
            wfIcdBar:SetStatusBarColor(1, 0, 0, 0.85) -- just procced, red
        elseif icdRemaining > 0.5 then
            wfIcdBar:SetStatusBarColor(1, 0.65, 0, 0.85) -- winding down, orange
        else
            wfIcdBar:SetStatusBarColor(0, 1, 0, 0.85) -- ready, green
        end
        wfIcdBar:Show()
    end

    local FLAME_SHOCK_BAR_HEIGHT = 6
    local FLAME_SHOCK_FALLBACK_DURATION = 12
    local FLAME_SHOCK_GLOW_WINDOW = 4
    local flameShockBar = nil
    local nextFlameShockUpdateAt = 0

    local function SetFlameShockGlow(bar, remaining)
        if not bar then
            return
        end

        local glowBorder = bar.glowBorder
        if not glowBorder then
            return
        end

        local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= FLAME_SHOCK_GLOW_WINDOW
        for _, edge in ipairs(glowBorder) do
            if shouldGlow then
                edge:Show()
            else
                edge:Hide()
            end
        end
    end

    local function EnsureFlameShockBar()
        if flameShockBar then
            return flameShockBar
        end

        if not ns.mhBar then
            return nil
        end

        flameShockBar = CreateFrame("StatusBar", nil, ns.mhBar)
        -- All static setup is done once at creation and never touched again
        -- at runtime. Per-frame updates in UpdateShamanFlameShockBar only
        -- modify SetMinMaxValues, SetValue, glow Show/Hide, and the label
        -- text.  Eliminating per-frame ClearAllPoints / SetPoint /
        -- SetStatusBarTexture / SetColorTexture on glow edges fixes the
        -- visible flash these calls cause on Classic/TBC's rendering path.
        flameShockBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        flameShockBar:SetStatusBarColor(1.0, 0.35, 0.10, 0.90)
        flameShockBar:SetMinMaxValues(0, 1)
        flameShockBar:SetValue(0)
        flameShockBar:SetHeight(FLAME_SHOCK_BAR_HEIGHT)
        flameShockBar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, 2)
        flameShockBar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, 2)
        flameShockBar:EnableMouse(false)

        local bg = flameShockBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        flameShockBar.backgroundTexture = bg

        local glowBorder = {}
        -- Glow edges use the final steady alpha at creation time so
        -- SetFlameShockGlow only calls Show/Hide, never SetColorTexture.
        local glowTop = flameShockBar:CreateTexture(nil, "OVERLAY")
        glowTop:SetPoint("TOPLEFT", flameShockBar, "TOPLEFT", -1, 1)
        glowTop:SetPoint("TOPRIGHT", flameShockBar, "TOPRIGHT", 1, 1)
        glowTop:SetHeight(1)
        glowTop:SetColorTexture(1.0, 0.45, 0.08, 0.85)
        glowTop:Hide()
        glowBorder[#glowBorder + 1] = glowTop

        local glowBottom = flameShockBar:CreateTexture(nil, "OVERLAY")
        glowBottom:SetPoint("BOTTOMLEFT", flameShockBar, "BOTTOMLEFT", -1, -1)
        glowBottom:SetPoint("BOTTOMRIGHT", flameShockBar, "BOTTOMRIGHT", 1, -1)
        glowBottom:SetHeight(1)
        glowBottom:SetColorTexture(1.0, 0.45, 0.08, 0.85)
        glowBottom:Hide()
        glowBorder[#glowBorder + 1] = glowBottom

        local glowLeft = flameShockBar:CreateTexture(nil, "OVERLAY")
        glowLeft:SetPoint("TOPLEFT", flameShockBar, "TOPLEFT", -1, 1)
        glowLeft:SetPoint("BOTTOMLEFT", flameShockBar, "BOTTOMLEFT", -1, -1)
        glowLeft:SetWidth(1)
        glowLeft:SetColorTexture(1.0, 0.45, 0.08, 0.85)
        glowLeft:Hide()
        glowBorder[#glowBorder + 1] = glowLeft

        local glowRight = flameShockBar:CreateTexture(nil, "OVERLAY")
        glowRight:SetPoint("TOPRIGHT", flameShockBar, "TOPRIGHT", 1, 1)
        glowRight:SetPoint("BOTTOMRIGHT", flameShockBar, "BOTTOMRIGHT", 1, -1)
        glowRight:SetWidth(1)
        glowRight:SetColorTexture(1.0, 0.45, 0.08, 0.85)
        glowRight:Hide()
        glowBorder[#glowBorder + 1] = glowRight

        flameShockBar.glowBorder = glowBorder

        -- Spell icon (left side)
        local fsIcon = flameShockBar:CreateTexture(nil, "OVERLAY")
        fsIcon:SetSize(FLAME_SHOCK_BAR_HEIGHT, FLAME_SHOCK_BAR_HEIGHT)
        fsIcon:SetPoint("LEFT", flameShockBar, "LEFT", 2, 0)
        local fsTexPath = GetSpellTexture and GetSpellTexture(8050)
        if fsTexPath then fsIcon:SetTexture(fsTexPath) end
        flameShockBar.icon = fsIcon

        local label = flameShockBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", flameShockBar, "CENTER", 0, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        label:SetTextColor(1.0, 0.85, 0.25, 0.95)
        label:SetText("FS")
        flameShockBar.label = label

        flameShockBar:Hide()
        ns.shamanFlameShockBar = flameShockBar
        return flameShockBar
    end

    local function GetTargetFlameShockData()
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId = GetHarmfulAuraData(
                "target", index, "HARMFUL"
            )

            if not auraName then
                break
            end

            local isFlameShock = false
            if type(auraSpellId) == "number" and ns.SHAMAN_FLAME_SHOCK_IDS and ns.SHAMAN_FLAME_SHOCK_IDS[auraSpellId] then
                isFlameShock = true
            elseif auraName == ns.SHAMAN_FLAME_SHOCK_NAME then
                isFlameShock = true
            end

            if isFlameShock and (caster == "player" or caster == nil) then
                return duration, expirationTime
            end
        end

        return nil
    end

    local function UpdateShamanFlameShockBar(force)
        local now = GetCurrentTime()
        if not force and now < nextFlameShockUpdateAt then
            return
        end
        nextFlameShockUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showShamanFlameShockBar == false then
            if flameShockBar then
                flameShockBar:Hide()
            end
            return
        end

        local bar = EnsureFlameShockBar()
        if not bar or not ns.mhBar then
            return
        end

        if not UnitExists or not UnitExists("target") or (UnitCanAttack and not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        if (ns.mhBar:GetAlpha() or 0) <= 0 then
            bar:Hide()
            return
        end

        local duration, expirationTime = GetTargetFlameShockData()
        if not duration and not expirationTime then
            SetFlameShockGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then
            duration = FLAME_SHOCK_FALLBACK_DURATION
        end

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetFlameShockGlow(bar, remaining)
        -- Update the countdown label each frame. Matches the RapidFire /
        -- AdrenalineRush whole-second countdown pattern (no prefix, just
        -- the remaining seconds as a rounded whole number).
        if bar.label and bar.label.SetText then
            bar.label:SetText(string.format("%.0f", math.max(remaining, 0)))
        end
        if bar.icon and bar.icon.SetTexture then
            local texPath = GetSpellTexture and GetSpellTexture(8050)
            if texPath then bar.icon:SetTexture(texPath) end
        end
        bar:Show()
    end

    ns.UpdateShamanFlameShockBar = function (force)
        UpdateShamanFlameShockBar(force == true)
    end

    local WATER_SHIELD_OVERRIDE_COLOR = { r = 0.50, g = 0.80, b = 1.0, a = 0.90 }

    local function IsLightningShieldActive()
        for index = 1, 40 do
            local auraName, _, _, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then
                break
            end

            local normalizedAuraName = type(auraName) == "string" and auraName:lower() or nil
            if type(auraSpellId) == "number" and ns.SHAMAN_LIGHTNING_SHIELD_IDS
                and ns.SHAMAN_LIGHTNING_SHIELD_IDS[auraSpellId] then
                return auraName, auraSpellId, true, index
            end
            if type(auraSpellId) == "number" and ns.SHAMAN_WATER_SHIELD_IDS and ns.SHAMAN_WATER_SHIELD_IDS[auraSpellId] then
                return auraName, auraSpellId, false, index
            end
            if ns.SHAMAN_LIGHTNING_SHIELD_NAMES and ns.SHAMAN_LIGHTNING_SHIELD_NAMES[auraName] then
                return auraName, auraSpellId, true, index
            end
            if ns.SHAMAN_WATER_SHIELD_NAMES and ns.SHAMAN_WATER_SHIELD_NAMES[auraName] then
                return auraName, auraSpellId, false, index
            end
            if normalizedAuraName == "lightning shield" then
                return auraName, auraSpellId, true, index
            end
            if normalizedAuraName == "water shield" or normalizedAuraName == "mana shield" then
                return auraName, auraSpellId, false, index
            end
        end
        return nil
    end

    local function GetShieldChargeCount(auraIndex)
        if not auraIndex then
            return nil
        end
        if not UnitBuff then
            return nil
        end
        local _, _, count = UnitBuff("player", auraIndex)
        if type(count) ~= "number" or count <= 0 then
            if UnitAura then
                local _, _, auraCount = UnitAura("player", auraIndex, "HELPFUL")
                if type(auraCount) == "number" and auraCount > 0 then
                    return auraCount
                end
            end
            return nil
        end
        return count
    end

    local function UpdateLightningShieldVisual()
        if (not ns.shamanLightningContainer or not ns.shamanLightningRects) and ns.OnBarsCreated then
            ns.OnBarsCreated()
        end

        if not ns.shamanLightningContainer or not ns.shamanLightningRects then
            return
        end

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db.showShamanLightningTracker == false then
            ns.shamanLightningContainer:Hide()
            return
        end

        if not ns.mhBar or (ns.mhBar:GetAlpha() or 0) <= 0 then
            ns.shamanLightningContainer:Hide()
            return
        end

        local shieldName, _, isLightning, auraIndex = IsLightningShieldActive()
        if not shieldName or not auraIndex then
            ns.shamanLightningContainer:Hide()
            return
        end

        local chargeCount = GetShieldChargeCount(auraIndex)
        if not chargeCount then
            chargeCount = 3
        end

        -- Determine color: Water Shield always light blue, Lightning Shield uses swatch
        local rectColor
        if not isLightning then
            rectColor = WATER_SHIELD_OVERRIDE_COLOR
        else
            rectColor = ns.GetBarColor and ns.GetBarColor("shamanLightningShield")
            if not rectColor then
                local defaults = ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors
                rectColor = defaults and defaults.shamanLightningShield or WATER_SHIELD_OVERRIDE_COLOR
            end
        end

        -- Size the rectangles to match the visible melee stack height.
        -- Single-bar mode: MH height.
        -- Dual-wield mode: MH + OH + the 2px inter-bar gap.
        local mhHeight = (ns.mhBar and ns.mhBar:GetHeight()) or ns.BAR_HEIGHT or 15
        local ohVisible = ns.ohBar and ns.ohBar:IsShown() and (ns.ohBar:GetAlpha() or 0) > 0
        local ohHeight = ns.ohBar and ohVisible and ns.ohBar:GetHeight() or 0
        local hasOffHand = ohVisible and ohHeight > 0
        local rectHeight = mhHeight
        if hasOffHand then
            local offHandGap = 2
            rectHeight = mhHeight + offHandGap + ohHeight
        end

        -- Container spans all 3 rects + gaps horizontally
        local totalWidth = LIGHTNING_SHIELD_NUM_RECTS * LIGHTNING_SHIELD_RECT_WIDTH
            + (LIGHTNING_SHIELD_NUM_RECTS - 1) * LIGHTNING_SHIELD_RECT_GAP
        ns.shamanLightningContainer:SetSize(totalWidth, rectHeight)

        -- Update each rect: filled color or dimmed alpha
        local dimAlpha = 0.20
        for i = 1, LIGHTNING_SHIELD_NUM_RECTS do
            local rect = ns.shamanLightningRects[i]
            if rect then
                local filled = i <= chargeCount
                rect:SetHeight(rectHeight)
                rect:SetColorTexture(
                    rectColor.r or 0.25, rectColor.g or 0.72, rectColor.b or 1.0,
                    filled and (rectColor.a or 0.9) or dimAlpha
                )
                rect:Show()
            end
        end

        local trackerGap = tonumber(db.shamanLightningTrackerGap)
        if not trackerGap then
            trackerGap = (ns.DB_DEFAULTS and ns.DB_DEFAULTS.shamanLightningTrackerGap)
                or LIGHTNING_SHIELD_BAR_GAP_DEFAULT
        end
        trackerGap = math.max(0, math.min(trackerGap, 40))

        -- Position: left of the MH/OH bar stack
        ns.shamanLightningContainer:ClearAllPoints()
        if hasOffHand then
            ns.shamanLightningContainer:SetPoint("TOPRIGHT", ns.mhBar, "TOPLEFT", -trackerGap, 0)
        else
            ns.shamanLightningContainer:SetPoint("RIGHT", ns.mhBar, "LEFT", -trackerGap, 0)
        end

        ns.shamanLightningContainer:Show()
    end

    ns.UpdateLightningShieldVisual = UpdateLightningShieldVisual

    -- ============================================================
    -- Phase 4: Shaman CD/Buff Duration Icon Group (configurable via shamanBuffIconSize)
    -- ============================================================
    local SHAMAN_TRACKED_SPELLS = {
        { spellId = 30823, name = "Shamanistic Rage", label = "SR", kind = "buff" },
        { spellId = 32182, name = "Heroism", label = "Hero", kind = "buff" },
        { spellId = 17364, name = "Stormstrike", label = "SS", kind = "cd" },
        { spellId = 16280, name = "Flurry", label = "Flurry", kind = "buff" },
        { spellId = 8232, name = "Windfury Weapon", label = "WF", kind = "buff" },
        { spellId = 29180, name = "Elemental Devastation", label = "ED", kind = "buff" },
        { spellId = 2825, name = "Bloodlust", label = "BL", kind = "buff" },
    }
    -- Shaman racial buffs
    local SHAMAN_RACIAL_SPELLS = {
        { spellId = 20572, name = "Blood Fury", label = "BF", kind = "buff" },
        { spellId = 26297, name = "Berserking", label = "BZ", kind = "buff" },
        { spellId = 28880, name = "Gift of the Naaru", label = "GN", kind = "buff" },
        { spellId = 20549, name = "War Stomp", label = "WS", kind = "cd" },
    }
    for _, racial in ipairs(SHAMAN_RACIAL_SPELLS) do
        table.insert(SHAMAN_TRACKED_SPELLS, racial)
    end

    local shamanBuffIcons = {}
    local shamanBuffTimer = 0
    local SHAMAN_BUFF_UPDATE_INTERVAL = 0.15
    local SHAMAN_BUFF_ICON_GAP = 3

    local function GetShamanSpellRemaining(info)
        -- Step 1: Scan helpful auras on the player (buffs)
        for index = 1, 40 do
            local auraName, duration, expirationTime, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then break end
            if auraSpellId == info.spellId or auraName == info.name then
                if type(expirationTime) == "number" and expirationTime > 0 then
                    return math.max(expirationTime - GetCurrentTime(), 0), math.max(duration or 1, 1)
                end
                return nil, nil
            end
        end
        -- Step 2: For CD-type, scan target harmful auras (debuffs like Stormstrike)
        if info.kind == "cd" then
            if type(UnitExists) == "function" and UnitExists("target")
                and type(UnitCanAttack) == "function" and UnitCanAttack("player", "target") then
                for index = 1, 40 do
                    local debuffName, _, debuffDuration, debuffExpiration, caster, debuffSpellId = GetHarmfulAuraData("target", index)
                    if not debuffName then break end
                    if caster == "player" and (debuffSpellId == info.spellId or debuffName == info.name) then
                        if type(debuffExpiration) == "number" and debuffExpiration > 0 then
                            return math.max(debuffExpiration - GetCurrentTime(), 0), math.max(debuffDuration or 1, 1)
                        end
                        return nil, nil
                    end
                end
            end
            -- Step 3: Fall back to cooldown tracking
            local startTime, cdDuration
            if type(GetSpellCooldown) == "function" then
                startTime, cdDuration = GetSpellCooldown(info.spellId)
            elseif C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
                local ok, cdInfo = pcall(C_Spell.GetSpellCooldown, info.spellId)
                if ok and cdInfo then
                    startTime = cdInfo.startTime
                    cdDuration = cdInfo.duration
                end
            end
            if type(startTime) ~= "number" or type(cdDuration) ~= "number" or cdDuration <= 0 then
                return nil, nil
            end
            -- Filter out GCD (1.5s) from real cooldowns
            if cdDuration <= 2.5 then
                return nil, nil
            end
            local remaining = math.max((startTime + cdDuration) - GetCurrentTime(), 0)
            if remaining <= 0 then return nil, nil end
            return remaining, cdDuration
        end
        return nil, nil
    end

    local function CreateShamanBuffIcons()
        if #shamanBuffIcons > 0 then return end
        local iconSize = SuperSwingTimerDB and SuperSwingTimerDB.shamanBuffIconSize or 25
        if type(iconSize) ~= "number" or iconSize <= 0 then iconSize = 25 end

        for _, spell in ipairs(SHAMAN_TRACKED_SPELLS) do
            local icon = CreateFrame("Frame", nil, UIParent)
            icon:SetSize(iconSize, iconSize)
            icon:SetFrameStrata("DIALOG")
            icon:EnableMouse(false)
            icon.texture = icon:CreateTexture(nil, "BACKGROUND")
            icon.texture:SetAllPoints()
            icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            local texPath = GetSpellTexture and GetSpellTexture(spell.spellId)
            if texPath then icon.texture:SetTexture(texPath) end
            icon.glow = icon:CreateTexture(nil, "OVERLAY", nil, 7)
            icon.glow:SetAllPoints()
            icon.glow:SetColorTexture(1, 0.85, 0, 0)
            icon.glow:SetBlendMode("ADD")
            -- 4-edge outline border (not a full-face overlay)
            icon.border = {}
            icon.border.top = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.top:SetPoint("TOPLEFT", -1, 1)
            icon.border.top:SetPoint("TOPRIGHT", 1, 1)
            icon.border.top:SetHeight(1)
            icon.border.top:SetColorTexture(0, 0, 0, 0.65)
            icon.border.bottom = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.bottom:SetPoint("BOTTOMLEFT", -1, -1)
            icon.border.bottom:SetPoint("BOTTOMRIGHT", 1, -1)
            icon.border.bottom:SetHeight(1)
            icon.border.bottom:SetColorTexture(0, 0, 0, 0.65)
            icon.border.left = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.left:SetPoint("TOPLEFT", -1, 1)
            icon.border.left:SetPoint("BOTTOMLEFT", -1, -1)
            icon.border.left:SetWidth(1)
            icon.border.left:SetColorTexture(0, 0, 0, 0.65)
            icon.border.right = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.right:SetPoint("TOPRIGHT", 1, 1)
            icon.border.right:SetPoint("BOTTOMRIGHT", 1, -1)
            icon.border.right:SetWidth(1)
            icon.border.right:SetColorTexture(0, 0, 0, 0.65)
            icon.durationText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            icon.durationText:SetPoint("CENTER", icon, "TOP", 0, 0)
            icon.durationText:SetJustifyH("CENTER")
            icon.durationText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            icon.durationText:SetTextColor(1, 1, 1, 0.95)
            icon.durationText:Hide()
            icon:Hide()
            icon.spellId = spell.spellId
            icon.label = spell.label
            icon.kind = spell.kind
            table.insert(shamanBuffIcons, icon)
        end
    end

    ns.UpdateShamanBuffIcons = function (elapsed)
        CreateShamanBuffIcons()
        if #shamanBuffIcons == 0 then return end

        shamanBuffTimer = shamanBuffTimer + (elapsed or 0.03)
        if shamanBuffTimer < SHAMAN_BUFF_UPDATE_INTERVAL then return end
        shamanBuffTimer = 0

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showShamanBuffIcons == false then
            for _, icon in ipairs(shamanBuffIcons) do
                if icon and icon.Hide then icon:Hide() end
            end
            return
        end
        if ns.playerInCombat ~= true then
            for _, icon in ipairs(shamanBuffIcons) do
                if icon and icon.Hide then icon:Hide() end
            end
            return
        end

        local iconSize = SuperSwingTimerDB and SuperSwingTimerDB.shamanBuffIconSize or 25
        if type(iconSize) ~= "number" or iconSize <= 0 then iconSize = 25 end

        local activeIcons = {}
        for _, icon in ipairs(shamanBuffIcons) do
            if icon and icon.spellId then
                for _, spell in ipairs(SHAMAN_TRACKED_SPELLS) do
                    if spell.spellId == icon.spellId then
                        local remaining, totalDuration = GetShamanSpellRemaining(spell)
                        if type(remaining) == "number" and remaining > 0
                            and type(totalDuration) == "number" and totalDuration > 0 then
                            table.insert(activeIcons, {
                                icon = icon,
                                remaining = remaining,
                                totalDuration = totalDuration
                            })
                        else
                            if icon.Hide then icon:Hide() end
                        end
                        break
                    end
                end
            elseif icon and icon.Hide then
                icon:Hide()
            end
        end

        local numActive = #activeIcons
        if numActive == 0 then return end

        local referenceBar = ns.mhBar
        if not referenceBar then return end
        -- Position icons above all visible target debuff duration bars
        local iconY = GetDebuffStackOffset({
            flameShockBar,
        }, ns.mhBar)
        local barGetWidth = referenceBar.GetWidth
        if not barGetWidth then return end

        for idx, entry in ipairs(activeIcons) do
            local icon = entry.icon
            local remaining = entry.remaining
            local totalDuration = entry.totalDuration

            if icon.SetSize then icon:SetSize(iconSize, iconSize) end

            -- Right-align icons: first at bar right edge, stack leftward
            local xOffset = -(numActive - idx) * (iconSize + SHAMAN_BUFF_ICON_GAP)
            local rightAlign = -(iconSize / 2)
            local finalX = rightAlign + xOffset

            if icon.ClearAllPoints then icon:ClearAllPoints() end
            if icon.SetPoint then icon:SetPoint("BOTTOM", referenceBar, "TOP", finalX, iconY) end

            -- Glow effect in the last 4 seconds
            if icon.glow and icon.glow.SetColorTexture then
                local shouldGlow = remaining <= 4 and remaining > 0
                if shouldGlow and totalDuration > 0 then
                    local pulseAlpha = 0.15 + 0.40 * (0.5 + 0.5 * math.sin(GetCurrentTime() * 6))
                    icon.glow:SetColorTexture(1, 0.85, 0, pulseAlpha)
                    if icon.glow.Show then icon.glow:Show() end
                elseif icon.glow.Hide then
                    icon.glow:Hide()
                end
            end

            -- Countdown text
            if icon.durationText and icon.durationText.SetText then
                local text = remaining >= 3 and string.format("%.0f", remaining) or string.format("%.1f", remaining)
                icon.durationText:SetText(text)
                if icon.durationText.Show then icon.durationText:Show() end
            end

            if icon.Show then icon:Show() end
        end
    end

    -- Register Shaman OnUpdate hook (weave + flame shock + flurry + shields)
    ns.RegisterOnUpdateHook(function (elapsed)
        UpdateWeaveVisuals()
        UpdateShamanFlameShockBar(false)
        UpdateShamanFlurryIcon()
        UpdateShamanStormstrikeBadge()
        UpdateShamanisticRageBadge()
        UpdateLightningShieldVisual()
        -- Restack all visible debuff bars above MH dynamically
        RestackDebuffBars({flameShockBar}, ns.mhBar)
        if ns.UpdateShamanBuffIcons then ns.UpdateShamanBuffIcons(elapsed) end
    end)

    local function SafeInitCall(fn)
        if type(fn) ~= "function" then
            return
        end
        pcall(fn)
    end

    SafeInitCall(UpdateWeaveVisuals)
    SafeInitCall(function ()
        UpdateShamanFlameShockBar(true)
    end)
    SafeInitCall(UpdateShamanFlurryIcon)
    SafeInitCall(UpdateShamanStormstrikeBadge)
    SafeInitCall(UpdateShamanisticRageBadge)
    SafeInitCall(UpdateLightningShieldVisual)
end

local function SetupDruid()
    local IsCurrentSpell = rawget(_G, "IsCurrentSpell")
    local DRUID_ENERGY_TICK_DURATION = 2.0
    local DRUID_ENERGY_TICK_GAP = 2
    if not IsCurrentSpell then
        if C_Spell and C_Spell.IsCurrentSpell then
            IsCurrentSpell = C_Spell.IsCurrentSpell
        end
    end

    local function GetDruidFormLabel()
        local powerType = type(UnitPowerType) == "function" and UnitPowerType("player") or nil
        if powerType == 3 then
            return "Cat"
        elseif powerType == 1 then
            return "Bear"
        end
        return "Caster"
    end

    local function IsDruidCatFormActive()
        return type(UnitPowerType) == "function" and UnitPowerType("player") == 3
    end

    local function IsLikelyNaturalDruidEnergyGain(delta)
        return type(delta) == "number" and delta >= 19 and delta <= 22
    end

    local function GetDruidEnergyTickColor()
        return ns.GetBarColor and ns.GetBarColor("druidEnergyTick") or { r = 1.0, g = 0.82, b = 0.18, a = 1 }
    end

    local function ApplyDruidEnergyTickColor()
        local tickBar = ns.druidEnergyTickBar
        if not tickBar then
            return
        end

        local tickColor = GetDruidEnergyTickColor()
        tickBar:SetStatusBarColor(tickColor.r or 1.0, tickColor.g or 0.82, tickColor.b or 0.18, tickColor.a or 1)
    end

    local function FindCurrentQueuedSpell(spellSet)
        if not IsCurrentSpell or not spellSet then
            return nil
        end

        local maulName = ns.GetSpellInfo(6807)
        if maulName and spellSet == ns.DRUID_MAUL_SPELLS and IsCurrentSpell(maulName) then
            return maulName
        end

        for key in pairs(spellSet) do
            if type(key) == "number" and IsCurrentSpell(key) then
                return key
            end
        end

        return nil
    end

    local function RestoreMainHandColor()
        if not ns.mhBar then
            return
        end

        local c = ns.mhBarBaseColor or (ns.GetBarColor and ns.GetBarColor("mh"))
        if c then
            ns.mhBar:SetStatusBarColor(c.r or 0, c.g or 0, c.b or 0, c.a or 1)
        else
            ns.mhBar:SetStatusBarColor(0, 0, 0, 1)
        end
    end

    local function UpdateDruidQueueTint()
        if ns.playerClass ~= "DRUID" or not ns.mhBar then
            return
        end

        local alpha = (ns.mhBarBaseColor and ns.mhBarBaseColor.a) or 1
        local queuedSpellId = FindCurrentQueuedSpell(ns.DRUID_MAUL_SPELLS)
        if queuedSpellId then
            ns.druidQueuedMeleeSpell = queuedSpellId
            ns.mhBar:SetStatusBarColor(DRUID_MAUL_TINT.r, DRUID_MAUL_TINT.g, DRUID_MAUL_TINT.b, alpha) -- Maul: bear yellow
            return
        end

        if ns.druidQueuedMeleeSpell then
            ns.druidQueuedMeleeSpell = nil
            RestoreMainHandColor()
        end
    end

    ns.UpdateDruidQueueTint = UpdateDruidQueueTint
    ns.IsDruidCatFormActive = IsDruidCatFormActive

    local function UpdateDruidEnergyTickVisual()
        local tickBar = ns.druidEnergyTickBar
        local mhBar = ns.mhBar
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if not tickBar or not mhBar then
            return
        end

        if ns.playerClass ~= "DRUID" or db.showDruidEnergyTickBar == false or (ns.IsMinimalMode and ns.IsMinimalMode()) then
            tickBar:SetAlpha(0)
            tickBar:SetValue(0)
            return
        end

        local previewActive = ns.barTestActive == true
        local mhVisible = mhBar.GetAlpha and (mhBar:GetAlpha() or 0) > 0
        if not previewActive and (not mhVisible or not IsDruidCatFormActive()) then
            tickBar:SetAlpha(0)
            tickBar:SetValue(0)
            return
        end

        tickBar:ClearAllPoints()
        tickBar:SetPoint("TOPRIGHT", mhBar, "TOPLEFT", -DRUID_ENERGY_TICK_GAP, 0)
        tickBar:SetWidth(ns.DRUID_ENERGY_TICK_BAR_WIDTH or ns.DB_DEFAULTS.druidEnergyTickBarWidth or 4)
        tickBar:SetHeight((mhBar:GetHeight() or ns.BAR_HEIGHT or 15))
        tickBar:SetMinMaxValues(0, 1)

        local now = GetCurrentTime()
        if not ns.druidEnergyTickStartTime then
            ns.druidEnergyTickStartTime = now
        end

        local elapsed = now - ns.druidEnergyTickStartTime
        if elapsed < 0 then
            elapsed = 0
        end

        local tickProgress = (elapsed % DRUID_ENERGY_TICK_DURATION) / DRUID_ENERGY_TICK_DURATION
        tickBar:SetValue(tickProgress)
        ApplyDruidEnergyTickColor()
        tickBar:SetAlpha(1)
    end

    local function HandleDruidEnergyPowerUpdate(unit, powerType)
        if ns.playerClass ~= "DRUID" or unit ~= "player" or type(UnitPower) ~= "function" then
            return
        end
        if powerType and powerType ~= "ENERGY" then
            return
        end

        local currentEnergy = UnitPower("player") or 0
        local previousEnergy = ns.druidLastEnergy
        if IsDruidCatFormActive() and previousEnergy ~= nil then
            local delta = currentEnergy - previousEnergy
            if IsLikelyNaturalDruidEnergyGain(delta) then
                ns.druidEnergyTickStartTime = GetCurrentTime()
            end
        end

        ns.druidLastEnergy = currentEnergy
        UpdateDruidEnergyTickVisual()
    end

    ns.UpdateDruidEnergyTickColor = ApplyDruidEnergyTickColor
    ns.UpdateDruidEnergyTickVisual = UpdateDruidEnergyTickVisual
    ns.HandleDruidEnergyPowerUpdate = HandleDruidEnergyPowerUpdate

    local function ApplyDruidQueueTint(spellValue)
        if not ns.mhBar then
            return
        end

        local alpha = (ns.mhBarBaseColor and ns.mhBarBaseColor.a) or 1
        if ns.DRUID_MAUL_SPELLS and ns.DRUID_MAUL_SPELLS[spellValue] then
            ns.druidQueuedMeleeSpell = spellValue
            ns.mhBar:SetStatusBarColor(DRUID_MAUL_TINT.r, DRUID_MAUL_TINT.g, DRUID_MAUL_TINT.b, alpha) -- Maul: bear yellow
        else
            RestoreMainHandColor()
        end
    end

    -- Queue indicator colors restore to the base MH tint on the next real swing.
    ns.OnMeleeSwing = function (slot)
        if slot == "mh" and ns.mhBar then
            ns.druidQueuedMeleeSpell = nil
            RestoreMainHandColor()
        end
    end

    ns.ClearDruidQueueTint = function ()
        ns.druidQueuedMeleeSpell = nil
        RestoreMainHandColor()
    end

    ns.OnDruidFormChange = function (_formSpellId)
        if ns.mhBar and ns.mhBar.labelText then
            ns.mhBar.labelText:SetText(GetDruidFormLabel())
        end
        ns.druidLastEnergy = type(UnitPower) == "function" and UnitPower("player") or ns.druidLastEnergy
        ns.druidEnergyTickStartTime = GetCurrentTime()
        UpdateDruidEnergyTickVisual()
        UpdateDruidQueueTint()
    end

    ns.OnBarsCreated = function ()
        if not ns.mhBar then
            return
        end

        if not ns.druidEnergyTickBar then
            ns.druidEnergyTickBar = EnsureVerticalHelperBar(
                "SuperSwingTimerDruidEnergyTickBar", ns.mhBar,
                ns.DRUID_ENERGY_TICK_BAR_WIDTH or ns.DB_DEFAULTS.druidEnergyTickBarWidth or 4
            )
        end

        ApplyDruidEnergyTickColor()
        ns.druidLastEnergy = type(UnitPower) == "function" and UnitPower("player") or ns.druidLastEnergy
        if not ns.druidEnergyTickStartTime then
            ns.druidEnergyTickStartTime = GetCurrentTime()
        end
        if ns.mhBar.labelText then
            ns.mhBar.labelText:SetText(GetDruidFormLabel())
        end

        -- Register Druid OnUpdate hook (queue tint + energy tick)
        ns.RegisterOnUpdateHook(function (elapsed)
            UpdateDruidQueueTint()
            UpdateDruidEnergyTickVisual()
        end)

        UpdateDruidEnergyTickVisual()
        UpdateDruidQueueTint()
    end

    -- Hook druid queued attacks (Maul)
    if ns.RegisterSpellcastSucceededHook then
        ns.RegisterSpellcastSucceededHook(function (unit, castGUIDOrSpellName, spellId)
            local spellToken = spellId ~= nil and spellId or castGUIDOrSpellName
            if unit == "player" and ns.DRUID_MAUL_SPELLS and ns.DRUID_MAUL_SPELLS[spellToken] then
                ApplyDruidQueueTint(spellToken)
            end
            if ns.UpdateDruidQueueTint then
                ns.UpdateDruidQueueTint()
            end
        end)
    end

    -- ============================================================
    -- Mangle and Rip debuff duration bars (Druid Feral)
    -- ============================================================
    local MANGLE_BAR_HEIGHT = 6
    local MANGLE_FALLBACK_DURATION = 12
    local MANGLE_GLOW_WINDOW = 4
    local mangleBar = nil
    local nextMangleUpdateAt = 0

    local function SetMangleGlow(bar, remaining)
        if not bar or not bar.glowBorder then return end
        local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= MANGLE_GLOW_WINDOW
        for _, edge in ipairs(bar.glowBorder) do
            if shouldGlow then edge:Show() else edge:Hide() end
        end
    end

    local function EnsureMangleBar()
        if mangleBar then return mangleBar end
        if not ns.mhBar then return nil end

        mangleBar = CreateFrame("StatusBar", nil, ns.mhBar)
        mangleBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        mangleBar:SetStatusBarColor(0.90, 0.60, 0.10, 0.90)  -- orange
        mangleBar:SetMinMaxValues(0, 1)
        mangleBar:SetValue(0)
        mangleBar:SetHeight(MANGLE_BAR_HEIGHT)
        mangleBar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, 2)
        mangleBar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, 2)
        mangleBar:EnableMouse(false)

        local bg = mangleBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        mangleBar.backgroundTexture = bg

        local glowBorder = {}
        for _, edgeDef in ipairs({
            { "TOPLEFT", "TOPRIGHT", "Height", 1, -1, 1, 1, 1 },
            { "BOTTOMLEFT", "BOTTOMRIGHT", "Height", 1, -1, -1, 1, -1 },
            { "TOPLEFT", "BOTTOMLEFT", "Width", 1, -1, 1, -1, -1 },
            { "TOPRIGHT", "BOTTOMRIGHT", "Width", 1, 1, 1, 1, -1 }
        }) do
            local tex = mangleBar:CreateTexture(nil, "OVERLAY")
            tex:SetPoint(edgeDef[1], mangleBar, edgeDef[2], edgeDef[4], edgeDef[5])
            tex:SetPoint(edgeDef[3], edgeDef[6], edgeDef[7], edgeDef[8])
            tex:SetColorTexture(0.90, 0.60, 0.10, 0.85)
            tex:Hide()
            glowBorder[#glowBorder + 1] = tex
        end
        mangleBar.glowBorder = glowBorder

        local spellIcon = mangleBar:CreateTexture(nil, "OVERLAY")
        spellIcon:SetSize(MANGLE_BAR_HEIGHT, MANGLE_BAR_HEIGHT)
        spellIcon:SetPoint("LEFT", mangleBar, "LEFT", 2, 0)
        local texPath = GetSpellTexture and GetSpellTexture(33983)
        if texPath then spellIcon:SetTexture(texPath) end
        mangleBar.icon = spellIcon

        local label = mangleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", mangleBar, "CENTER", 0, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        label:SetTextColor(1.0, 0.85, 0.25, 0.95)
        label:SetText("Mg")
        mangleBar.label = label

        mangleBar:Hide()
        return mangleBar
    end

    local function GetTargetMangleData()
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId =
                GetHarmfulAuraData("target", index, "HARMFUL")
            if not auraName then break end

            local isMangle = false
            if type(auraSpellId) == "number" and ns.DRUID_MANGLE_IDS and ns.DRUID_MANGLE_IDS[auraSpellId] then
                isMangle = true
            elseif auraName == ns.DRUID_MANGLE_NAME then
                isMangle = true
            end

            if isMangle and (caster == "player" or caster == nil) then
                return duration, expirationTime
            end
        end
        return nil
    end

    local function UpdateDruidMangleBar(force)
        local now = GetCurrentTime()
        if not force and now < nextMangleUpdateAt then return end
        nextMangleUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showDruidMangleBar == false then
            if mangleBar then mangleBar:Hide() end
            return
        end

        local bar = EnsureMangleBar()
        if not bar or not ns.mhBar then return end

        if type(UnitExists) ~= "function" or not UnitExists("target")
            or (type(UnitCanAttack) ~= "function" or not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        if (ns.mhBar:GetAlpha() or 0) <= 0 then
            bar:Hide()
            return
        end

        local duration, expirationTime = GetTargetMangleData()
        if not duration and not expirationTime then
            SetMangleGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then
            duration = MANGLE_FALLBACK_DURATION
        end

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetMangleGlow(bar, remaining)

        if bar.label and bar.label.SetText then
            bar.label:SetText(string.format("%.0f", math.max(remaining, 0)))
        end

        bar:Show()
    end

    -- ============================================================
    -- Rip debuff duration bar (Druid Feral)
    -- ============================================================
    local RIP_BAR_HEIGHT = 6
    local RIP_FALLBACK_DURATION = 12
    local RIP_GLOW_WINDOW = 4
    local ripBar = nil
    local nextRipUpdateAt = 0

    local function SetRipGlow(bar, remaining)
        if not bar or not bar.glowBorder then return end
        local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= RIP_GLOW_WINDOW
        for _, edge in ipairs(bar.glowBorder) do
            if shouldGlow then edge:Show() else edge:Hide() end
        end
    end

    local function EnsureRipBar()
        if ripBar then return ripBar end
        if not ns.mhBar then return nil end

        ripBar = CreateFrame("StatusBar", nil, ns.mhBar)
        ripBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        ripBar:SetStatusBarColor(0.20, 0.75, 0.20, 0.90)  -- green
        ripBar:SetMinMaxValues(0, 1)
        ripBar:SetValue(0)
        ripBar:SetHeight(RIP_BAR_HEIGHT)
        ripBar:EnableMouse(false)

        local bg = ripBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        ripBar.backgroundTexture = bg

        local glowBorder = {}
        for _, edgeDef in ipairs({
            { "TOPLEFT", "TOPRIGHT", "Height", 1, -1, 1, 1, 1 },
            { "BOTTOMLEFT", "BOTTOMRIGHT", "Height", 1, -1, -1, 1, -1 },
            { "TOPLEFT", "BOTTOMLEFT", "Width", 1, -1, 1, -1, -1 },
            { "TOPRIGHT", "BOTTOMRIGHT", "Width", 1, 1, 1, 1, -1 }
        }) do
            local tex = ripBar:CreateTexture(nil, "OVERLAY")
            tex:SetPoint(edgeDef[1], ripBar, edgeDef[2], edgeDef[4], edgeDef[5])
            tex:SetPoint(edgeDef[3], edgeDef[6], edgeDef[7], edgeDef[8])
            tex:SetColorTexture(0.20, 0.75, 0.20, 0.85)
            tex:Hide()
            glowBorder[#glowBorder + 1] = tex
        end
        ripBar.glowBorder = glowBorder

        local spellIcon = ripBar:CreateTexture(nil, "OVERLAY")
        spellIcon:SetSize(RIP_BAR_HEIGHT, RIP_BAR_HEIGHT)
        spellIcon:SetPoint("LEFT", ripBar, "LEFT", 2, 0)
        local texPath = GetSpellTexture and GetSpellTexture(27008)
        if texPath then spellIcon:SetTexture(texPath) end
        ripBar.icon = spellIcon

        local label = ripBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", ripBar, "CENTER", 0, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        label:SetTextColor(1.0, 0.85, 0.25, 0.95)
        label:SetText("Rp")
        ripBar.label = label

        ripBar:Hide()
        return ripBar
    end

    local function GetTargetRipData()
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId =
                GetHarmfulAuraData("target", index, "HARMFUL")
            if not auraName then break end

            local isRip = false
            if type(auraSpellId) == "number" and ns.DRUID_RIP_IDS and ns.DRUID_RIP_IDS[auraSpellId] then
                isRip = true
            elseif auraName == ns.DRUID_RIP_NAME then
                isRip = true
            end

            if isRip and (caster == "player" or caster == nil) then
                return duration, expirationTime
            end
        end
        return nil
    end

    local function UpdateDruidRipBar(force)
        local now = GetCurrentTime()
        if not force and now < nextRipUpdateAt then return end
        nextRipUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showDruidRipBar == false then
            if ripBar then ripBar:Hide() end
            return
        end

        local bar = EnsureRipBar()
        if not bar or not ns.mhBar then return end

        if type(UnitExists) ~= "function" or not UnitExists("target")
            or (type(UnitCanAttack) ~= "function" or not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        if (ns.mhBar:GetAlpha() or 0) <= 0 then
            bar:Hide()
            return
        end

        local duration, expirationTime = GetTargetRipData()
        if not duration and not expirationTime then
            SetRipGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then
            duration = RIP_FALLBACK_DURATION
        end

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetRipGlow(bar, remaining)

        if bar.label and bar.label.SetText then
            bar.label:SetText(string.format("%.0f", math.max(remaining, 0)))
        end

        -- Dynamic positioning: Rip sits above Mangle (or directly above MH if Mangle hidden)
        local mangleShown = mangleBar and mangleBar:IsShown()
        local ripOffset = 2
        if mangleShown then
            ripOffset = 2 + MANGLE_BAR_HEIGHT + 5
        end
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, ripOffset)
        bar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, ripOffset)

        bar:Show()
    end

    -- ============================================================
    -- Rake debuff duration bar (Druid Feral Cat bleed, 9s)
    -- ============================================================
    local RAKE_BAR_HEIGHT = 5
    local RAKE_FALLBACK_DURATION = 9
    local RAKE_GLOW_WINDOW = 4
    local rakeBar = nil
    local nextRakeUpdateAt = 0

    local function SetRakeGlow(bar, remaining)
        if not bar or not bar.glowBorder then return end
        local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= RAKE_GLOW_WINDOW
        for _, edge in ipairs(bar.glowBorder) do
            if shouldGlow then edge:Show() else edge:Hide() end
        end
    end

    local function EnsureRakeBar()
        if rakeBar then return rakeBar end
        if not ns.mhBar then return nil end

        rakeBar = CreateFrame("StatusBar", nil, ns.mhBar)
        rakeBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        rakeBar:SetStatusBarColor(0.85, 0.40, 0.10, 0.90)  -- burnt orange
        rakeBar:SetMinMaxValues(0, 1)
        rakeBar:SetValue(0)
        rakeBar:SetHeight(RAKE_BAR_HEIGHT)
        rakeBar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, 2)
        rakeBar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, 2)
        rakeBar:EnableMouse(false)

        local bg = rakeBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        rakeBar.backgroundTexture = bg

        local glowBorder = {}
        for _, edgeDef in ipairs({
            { "TOPLEFT", "TOPRIGHT", "Height", 1, -1, 1, 1, 1 },
            { "BOTTOMLEFT", "BOTTOMRIGHT", "Height", 1, -1, -1, 1, -1 },
            { "TOPLEFT", "BOTTOMLEFT", "Width", 1, -1, 1, -1, -1 },
            { "TOPRIGHT", "BOTTOMRIGHT", "Width", 1, 1, 1, 1, -1 }
        }) do
            local tex = rakeBar:CreateTexture(nil, "OVERLAY")
            tex:SetPoint(edgeDef[1], rakeBar, edgeDef[2], edgeDef[4], edgeDef[5])
            tex:SetPoint(edgeDef[3], edgeDef[6], edgeDef[7], edgeDef[8])
            tex:SetColorTexture(0.85, 0.40, 0.10, 0.85)
            tex:Hide()
            glowBorder[#glowBorder + 1] = tex
        end
        rakeBar.glowBorder = glowBorder

        local spellIcon = rakeBar:CreateTexture(nil, "OVERLAY")
        spellIcon:SetSize(RAKE_BAR_HEIGHT, RAKE_BAR_HEIGHT)
        spellIcon:SetPoint("LEFT", rakeBar, "LEFT", 2, 0)
        local texPath = GetSpellTexture and GetSpellTexture(1822)
        if texPath then spellIcon:SetTexture(texPath) end
        rakeBar.icon = spellIcon

        local label = rakeBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", rakeBar, "CENTER", 0, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        label:SetTextColor(1.0, 0.85, 0.25, 0.95)
        label:SetText("Rk")
        rakeBar.label = label

        rakeBar:Hide()
        return rakeBar
    end

    local function GetTargetRakeData()
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId =
                GetHarmfulAuraData("target", index, "HARMFUL")
            if not auraName then break end

            local isRake = false
            if type(auraSpellId) == "number" and ns.DRUID_RAKE_IDS and ns.DRUID_RAKE_IDS[auraSpellId] then
                isRake = true
            elseif auraName == ns.DRUID_RAKE_NAME then
                isRake = true
            end

            if isRake and (caster == "player" or caster == nil) then
                return duration, expirationTime
            end
        end
        return nil
    end

    local function UpdateDruidRakeBar(force)
        local now = GetCurrentTime()
        if not force and now < nextRakeUpdateAt then return end
        nextRakeUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showDruidRakeBar == false then
            if rakeBar then rakeBar:Hide() end
            return
        end

        local bar = EnsureRakeBar()
        if not bar or not ns.mhBar then return end

        if type(UnitExists) ~= "function" or not UnitExists("target")
            or (type(UnitCanAttack) ~= "function" or not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        if (ns.mhBar:GetAlpha() or 0) <= 0 then
            bar:Hide()
            return
        end

        local duration, expirationTime = GetTargetRakeData()
        if not duration and not expirationTime then
            SetRakeGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then
            duration = RAKE_FALLBACK_DURATION
        end

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetRakeGlow(bar, remaining)

        if bar.label and bar.label.SetText then
            bar.label:SetText(string.format("%.0f", math.max(remaining, 0)))
        end

        -- Dynamic positioning: Rake sits above Rip (or Mangle if Rip hidden, or MH if neither)
        local ripShown = ripBar and ripBar:IsShown()
        local mangleShown = mangleBar and mangleBar:IsShown()
        local rakeOffset = 2
        if ripShown then
            local ripTop = 2
            if mangleShown then
                ripTop = 2 + MANGLE_BAR_HEIGHT + 5
            end
            rakeOffset = ripTop + RIP_BAR_HEIGHT + 4
        elseif mangleShown then
            rakeOffset = 2 + MANGLE_BAR_HEIGHT + 4
        end
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, rakeOffset)
        bar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, rakeOffset)

        bar:Show()
    end

    -- ============================================================
    -- Druid buff / CD icon tracking (same pattern as Warrior/Paladin)
    -- ============================================================
    local DRUID_RACIAL_SPELLS = {
        { spellId = 20572, name = "Blood Fury", label = "BF", kind = "buff" },
        { spellId = 26297, name = "Berserking", label = "BZ", kind = "buff" },
        { spellId = 58984, name = "Shadowmeld", label = "SM", kind = "buff" },
        { spellId = 20549, name = "War Stomp", label = "WS", kind = "cd" },
        { spellId = 28880, name = "Gift of the Naaru", label = "GN", kind = "buff" },
    }
    local DRUID_TRACKED_SPELLS = {
        { spellId = 5217, name = "Tiger's Fury", label = "TF", kind = "buff" },
        { spellId = 22842, name = "Frenzied Regeneration", label = "FR", kind = "buff" },
        { spellId = 22812, name = "Barkskin", label = "Brk", kind = "buff" },
        { spellId = 1850, name = "Dash", label = "Dash", kind = "buff" },
        { spellId = 5229, name = "Enrage", label = "ER", kind = "buff" },
        { spellId = 5211, name = "Bash", label = "Bash", kind = "cd" },
        { spellId = 29166, name = "Innervate", label = "Inn", kind = "buff" },
        -- External buffs (party/raid-wide, consumables):
        { spellId = 2825, name = "Bloodlust", label = "BL", kind = "buff", external = true },
        { spellId = 32182, name = "Heroism", label = "Hero", kind = "buff", external = true },
        { spellId = 35476, name = "Drums of Battle", label = "DoB", kind = "buff", external = true },
        { spellId = 35477, name = "Drums of Speed", label = "DoS", kind = "buff", external = true },
        { spellId = 28507, name = "Haste Potion", label = "HP", kind = "buff", external = true },
    }
    for _, racial in ipairs(DRUID_RACIAL_SPELLS) do
        table.insert(DRUID_TRACKED_SPELLS, racial)
    end

    local druidBuffIcons = {}
    local druidBuffTimer = 0
    local DRUID_BUFF_UPDATE_INTERVAL = 0.15
    local DRUID_BUFF_ICON_GAP = 3

    local function GetDruidSpellRemaining(info)
        -- Step 1: Scan helpful auras on the player (buffs)
        for index = 1, 40 do
            local auraName, duration, expirationTime, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then break end
            if auraSpellId == info.spellId or auraName == info.name then
                if type(expirationTime) == "number" and expirationTime > 0 then
                    return math.max(expirationTime - GetCurrentTime(), 0), math.max(duration or 1, 1)
                end
                return nil, nil
            end
        end
        -- Step 2: For CD-type, scan target harmful auras
        if info.kind == "cd" then
            if type(UnitExists) == "function" and UnitExists("target")
                and type(UnitCanAttack) == "function" and UnitCanAttack("player", "target") then
                for index = 1, 40 do
                    local debuffName, _, debuffDuration, debuffExpiration, caster, debuffSpellId = GetHarmfulAuraData("target", index)
                    if not debuffName then break end
                    if caster == "player" and (debuffSpellId == info.spellId or debuffName == info.name) then
                        if type(debuffExpiration) == "number" and debuffExpiration > 0 then
                            return math.max(debuffExpiration - GetCurrentTime(), 0), math.max(debuffDuration or 1, 1)
                        end
                        return nil, nil
                    end
                end
            end
            -- Step 3: Fall back to cooldown tracking
            local startTime, cdDuration
            if type(GetSpellCooldown) == "function" then
                startTime, cdDuration = GetSpellCooldown(info.spellId)
            elseif C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
                local ok, cdInfo = pcall(C_Spell.GetSpellCooldown, info.spellId)
                if ok and cdInfo then
                    startTime = cdInfo.startTime
                    cdDuration = cdInfo.duration
                end
            end
            if type(startTime) ~= "number" or type(cdDuration) ~= "number" or cdDuration <= 0 then
                return nil, nil
            end
            if cdDuration <= 2.5 then
                return nil, nil
            end
            local remaining = math.max((startTime + cdDuration) - GetCurrentTime(), 0)
            if remaining <= 0 then return nil, nil end
            return remaining, cdDuration
        end
        return nil, nil
    end

    local function CreateDruidBuffIcons()
        if #druidBuffIcons > 0 then return end
        local iconSize = SuperSwingTimerDB and SuperSwingTimerDB.druidBuffIconSize or 25
        if type(iconSize) ~= "number" or iconSize <= 0 then iconSize = 25 end

        for _, spell in ipairs(DRUID_TRACKED_SPELLS) do
            local icon = CreateFrame("Frame", nil, UIParent)
            icon:SetSize(iconSize, iconSize)
            icon:SetFrameStrata("DIALOG")
            icon:EnableMouse(false)
            icon.texture = icon:CreateTexture(nil, "BACKGROUND")
            icon.texture:SetAllPoints()
            icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            local texPath = GetSpellTexture and GetSpellTexture(spell.spellId)
            if texPath then icon.texture:SetTexture(texPath) end
            icon.glow = icon:CreateTexture(nil, "OVERLAY", nil, 7)
            icon.glow:SetAllPoints()
            icon.glow:SetColorTexture(1, 0.85, 0, 0)
            icon.glow:SetBlendMode("ADD")
            -- 4-edge outline border (not a full-face overlay)
            icon.border = {}
            icon.border.top = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.top:SetPoint("TOPLEFT", -1, 1)
            icon.border.top:SetPoint("TOPRIGHT", 1, 1)
            icon.border.top:SetHeight(1)
            icon.border.top:SetColorTexture(0, 0, 0, 0.65)
            icon.border.bottom = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.bottom:SetPoint("BOTTOMLEFT", -1, -1)
            icon.border.bottom:SetPoint("BOTTOMRIGHT", 1, -1)
            icon.border.bottom:SetHeight(1)
            icon.border.bottom:SetColorTexture(0, 0, 0, 0.65)
            icon.border.left = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.left:SetPoint("TOPLEFT", -1, 1)
            icon.border.left:SetPoint("BOTTOMLEFT", -1, -1)
            icon.border.left:SetWidth(1)
            icon.border.left:SetColorTexture(0, 0, 0, 0.65)
            icon.border.right = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.right:SetPoint("TOPRIGHT", 1, 1)
            icon.border.right:SetPoint("BOTTOMRIGHT", 1, -1)
            icon.border.right:SetWidth(1)
            icon.border.right:SetColorTexture(0, 0, 0, 0.65)
            icon.durationText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            icon.durationText:SetPoint("CENTER", icon, "TOP", 0, 0)
            icon.durationText:SetJustifyH("CENTER")
            icon.durationText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            icon.durationText:SetTextColor(1, 1, 1, 0.95)
            icon.durationText:Hide()
            icon:Hide()
            icon.spellId = spell.spellId
            icon.label = spell.label
            icon.kind = spell.kind
            table.insert(druidBuffIcons, icon)
        end
    end

    ns.UpdateDruidBuffIcons = function (elapsed)
        CreateDruidBuffIcons()
        if #druidBuffIcons == 0 then return end

        druidBuffTimer = druidBuffTimer + (elapsed or 0.03)
        if druidBuffTimer < DRUID_BUFF_UPDATE_INTERVAL then return end
        druidBuffTimer = 0

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showDruidBuffIcons == false then
            for _, icon in ipairs(druidBuffIcons) do
                if icon and icon.Hide then icon:Hide() end
            end
            return
        end
        if ns.playerInCombat ~= true then
            for _, icon in ipairs(druidBuffIcons) do
                if icon and icon.Hide then icon:Hide() end
            end
            return
        end

        local iconSize = SuperSwingTimerDB and SuperSwingTimerDB.druidBuffIconSize or 25
        if type(iconSize) ~= "number" or iconSize <= 0 then iconSize = 25 end

        local activeIcons = {}
        for _, icon in ipairs(druidBuffIcons) do
            if icon and icon.spellId then
                for _, spell in ipairs(DRUID_TRACKED_SPELLS) do
                    if spell.spellId == icon.spellId then
                        local remaining, totalDuration = GetDruidSpellRemaining(spell)
                        if type(remaining) == "number" and remaining > 0
                            and type(totalDuration) == "number" and totalDuration > 0 then
                            table.insert(activeIcons, {
                                icon = icon,
                                remaining = remaining,
                                totalDuration = totalDuration
                            })
                        else
                            if icon.Hide then icon:Hide() end
                        end
                        break
                    end
                end
            elseif icon and icon.Hide then
                icon:Hide()
            end
        end

        local numActive = #activeIcons
        if numActive == 0 then return end

        local referenceBar = ns.mhBar
        if not referenceBar then return end

        -- Position icons above all visible target debuff duration bars (Mangle bottom, Rip middle, Rake top)
        local iconY = GetDebuffStackOffset({
            mangleBar,
            ripBar,
            rakeBar,
        }, ns.mhBar)

        local barGetWidth = referenceBar.GetWidth
        if not barGetWidth then return end

        for idx, entry in ipairs(activeIcons) do
            local icon = entry.icon
            local remaining = entry.remaining
            local totalDuration = entry.totalDuration

            if icon.SetSize then icon:SetSize(iconSize, iconSize) end

            local xOffset = -(numActive - idx) * (iconSize + DRUID_BUFF_ICON_GAP)
            local rightAlign = -(iconSize / 2)
            local finalX = rightAlign + xOffset

            if icon.ClearAllPoints then icon:ClearAllPoints() end
            if icon.SetPoint then icon:SetPoint("BOTTOM", referenceBar, "TOP", finalX, iconY) end

            if icon.dim and icon.dim.SetColorTexture then
                icon.dim:SetColorTexture(0, 0, 0, 0)
            end

            if icon.glow and icon.glow.SetColorTexture then
                local shouldGlow = remaining <= 4 and remaining > 0
                if shouldGlow and totalDuration > 0 then
                    local pulseAlpha = 0.15 + 0.40 * (0.5 + 0.5 * math.sin(GetCurrentTime() * 6))
                    icon.glow:SetColorTexture(1, 0.85, 0, pulseAlpha)
                    if icon.glow.Show then icon.glow:Show() end
                elseif icon.glow.Hide then
                    icon.glow:Hide()
                end
            end

            if icon.durationText and icon.durationText.SetText then
                local text = remaining >= 3 and string.format("%.0f", remaining) or string.format("%.1f", remaining)
                icon.durationText:SetText(text)
                if icon.durationText.Show then icon.durationText:Show() end
            end

            if icon.Show then icon:Show() end
        end
    end
    pcall(UpdateDruidMangleBar, true)
    pcall(UpdateDruidRipBar, true)
    pcall(UpdateDruidRakeBar, true)
    if ns.UpdateDruidBuffIcons then ns.UpdateDruidBuffIcons() end

    -- Export update functions
    ns.UpdateDruidMangleBar = UpdateDruidMangleBar
    ns.UpdateDruidRipBar = UpdateDruidRipBar
    ns.UpdateDruidRakeBar = UpdateDruidRakeBar

    -- Register Druid debuff bars + buff icons OnUpdate hook
    ns.RegisterOnUpdateHook(function (elapsed)
        UpdateDruidMangleBar(false)
        UpdateDruidRipBar(false)
        UpdateDruidRakeBar(false)
        -- Restack all visible debuff bars above MH dynamically
        RestackDebuffBars({mangleBar, ripBar, rakeBar}, ns.mhBar)
        if ns.UpdateDruidBuffIcons then ns.UpdateDruidBuffIcons(elapsed) end
    end)
end

local function SetupHunter()
    local IsCurrentSpell = rawget(_G, "IsCurrentSpell")
    if not IsCurrentSpell then
        if C_Spell and C_Spell.IsCurrentSpell then
            IsCurrentSpell = C_Spell.IsCurrentSpell
        end
    end
    local raptorSpellName = ns.GetSpellInfo and ns.GetSpellInfo(2973) or nil
    local nextHunterQueuePollAt = 0
    local HUNTER_QUEUE_POLL_INTERVAL = 0.05
    local HUNTER_RANGE_HELPER_GAP = 3
    local HUNTER_SWEET_SPOT_INTERACT_INDEX = 3

    local function HasAttackableTarget()
        if type(UnitExists) == "function" and not UnitExists("target") then
            return false
        end
        if type(UnitCanAttack) == "function" and not UnitCanAttack("player", "target") then
            return false
        end
        if type(UnitIsDead) == "function" and UnitIsDead("target") then
            return false
        end
        return true
    end

    local function IsSpellTokenInRange(spellToken, unit)
        if not spellToken or not unit then
            return nil
        end

        if type(SpellHasRange) == "function" then
            local okHasRange, hasRange = pcall(SpellHasRange, spellToken)
            if okHasRange and hasRange == false then
                return nil
            end
        end

        if type(IsSpellInRange) == "function" then
            local ok, inRange = pcall(IsSpellInRange, spellToken, unit)
            if ok and inRange ~= nil then
                return inRange == 1
            end
        end

        return nil
    end

    local function IsHunterTargetInSweetSpotBand()
        if not HasAttackableTarget() or type(CheckInteractDistance) ~= "function" then
            return nil
        end

        local ok, inRange = pcall(CheckInteractDistance, "target", HUNTER_SWEET_SPOT_INTERACT_INDEX)
        if not ok or inRange == nil then
            return nil
        end

        return inRange == true or inRange == 1
    end

    local function IsHunterTargetInMeleeRange()
        local inRange = IsSpellTokenInRange(ns.WING_CLIP_NAME, "target")
        if inRange == nil and raptorSpellName and raptorSpellName ~= ns.WING_CLIP_NAME then
            inRange = IsSpellTokenInRange(raptorSpellName, "target")
        end
        return inRange
    end
    ns.IsHunterTargetInMeleeRange = IsHunterTargetInMeleeRange

    local function IsHunterTargetInRangedShotRange()
        return IsSpellTokenInRange(ns.AUTO_SHOT_NAME, "target")
    end

    local function GetHunterRangeState(previewActive)
        if previewActive then
            return "ranged"
        end
        if not HasAttackableTarget() then
            return nil
        end

        if IsHunterTargetInMeleeRange() == true then
            return "melee"
        end

        if IsHunterTargetInSweetSpotBand() == true then
            return "sweetSpot"
        end

        if IsHunterTargetInRangedShotRange() == true then
            return "ranged"
        end

        return "outOfRange"
    end

    local function GetHunterRangeColorKey(rangeState)
        if rangeState == "melee" then
            return "hunterRangeMelee"
        elseif rangeState == "sweetSpot" then
            return "hunterRangeSweetSpot"
        elseif rangeState == "ranged" then
            return "hunterRangeRanged"
        end

        return "hunterRangeOutOfRange"
    end

    local function ApplyHunterRangeHelperColor(rangeState)
        local helperBar = ns.hunterRangeHelperBar
        if not helperBar then
            return
        end

        local colorKey = GetHunterRangeColorKey(rangeState)
        local color = ns.GetBarColor and ns.GetBarColor(colorKey)
            or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors and ns.DB_DEFAULTS.colors[colorKey])
        if not color then
            return
        end

        helperBar:SetStatusBarColor(color.r or 1, color.g or 1, color.b or 1, color.a ~= nil and color.a or 1)
    end

    local function GetHunterRangeHelperAnchors()
        local previewActive = ns.barTestActive == true
        local topAnchor = ns.rangedBar
        local bottomAnchor = ns.rangedBar

        -- Cast bar extends below the ranged bar when visible (MH bar does NOT affect height)
        if ns.hunterCastBar
            and (previewActive or ((ns.hunterCastBar.GetAlpha and ns.hunterCastBar:GetAlpha()) or 0) > 0) then
            bottomAnchor = ns.hunterCastBar
        end

        return topAnchor, bottomAnchor
    end

    local function UpdateHunterRangeHelperVisual(forcedRangeState)
        local helperBar = ns.hunterRangeHelperBar
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        local previewActive = ns.barTestActive == true
        local rangedVisible = ns.rangedBar
            and (previewActive or ((ns.rangedBar.GetAlpha and ns.rangedBar:GetAlpha()) or 0) > 0)
        if not helperBar or ns.playerClass ~= "HUNTER" or db.showHunterRangeHelper == false
            or (ns.IsMinimalMode and ns.IsMinimalMode()) or not rangedVisible then
            if helperBar then
                helperBar:SetAlpha(0)
                helperBar:SetValue(0)
            end
            return
        end

        local rangeState = forcedRangeState or GetHunterRangeState(previewActive)
        if not rangeState then
            helperBar:SetAlpha(0)
            helperBar:SetValue(0)
            return
        end

        local topAnchor, bottomAnchor = GetHunterRangeHelperAnchors()
        if not topAnchor or not bottomAnchor then
            helperBar:SetAlpha(0)
            helperBar:SetValue(0)
            return
        end

        helperBar:ClearAllPoints()
        helperBar:SetPoint("TOPRIGHT", topAnchor, "TOPLEFT", -HUNTER_RANGE_HELPER_GAP, 0)
        helperBar:SetPoint("BOTTOMRIGHT", bottomAnchor, "BOTTOMLEFT", -HUNTER_RANGE_HELPER_GAP, 0)
        helperBar:SetWidth(ns.GetHunterRangeHelperWidth and ns.GetHunterRangeHelperWidth() or 7)
        helperBar:SetMinMaxValues(0, 1)
        helperBar:SetValue(1)
        ApplyHunterRangeHelperColor(rangeState)
        helperBar:SetAlpha(1)
    end

    local function RefreshHunterVisibility()
        if ns.ApplyVisibility then
            ns.ApplyVisibility()
        end
    end

    local function FindCurrentQueuedSpell(spellSet)
        if not IsCurrentSpell or not spellSet then
            return nil
        end

        if raptorSpellName and spellSet == ns.HUNTER_RAPTOR_STRIKE_SPELLS and IsCurrentSpell(raptorSpellName) then
            return raptorSpellName
        end

        for key in pairs(spellSet) do
            if type(key) == "number" and IsCurrentSpell(key) then
                return key
            end
        end

        return nil
    end

    local function RestoreMainHandColor()
        if not ns.mhBar then
            return
        end

        local c = ns.mhBarBaseColor or (ns.GetBarColor and ns.GetBarColor("mh"))
        if c then
            ns.mhBar:SetStatusBarColor(c.r or 0, c.g or 0, c.b or 0, c.a or 1)
        else
            ns.mhBar:SetStatusBarColor(0, 0, 0, 1)
        end
    end

    local function UpdateHunterQueueTint(force)
        if ns.playerClass ~= "HUNTER" or not ns.mhBar then
            return
        end

        if not force then
            local now = GetCurrentTime()
            if now < nextHunterQueuePollAt then
                return
            end
            nextHunterQueuePollAt = now + HUNTER_QUEUE_POLL_INTERVAL
        else
            nextHunterQueuePollAt = 0
        end

        local alpha = (ns.mhBarBaseColor and ns.mhBarBaseColor.a) or 1
        local queuedSpellId = FindCurrentQueuedSpell(ns.HUNTER_RAPTOR_STRIKE_SPELLS)
        if queuedSpellId then
            local queueChanged = ns.hunterQueuedMeleeSpell ~= queuedSpellId
            ns.hunterQueuedMeleeSpell = queuedSpellId
            ns.mhBar:SetStatusBarColor(HUNTER_RAPTOR_TINT.r, HUNTER_RAPTOR_TINT.g, HUNTER_RAPTOR_TINT.b, alpha)
            if queueChanged then
                RefreshHunterVisibility()
            end
            return
        end

        if ns.hunterQueuedMeleeSpell then
            ns.hunterQueuedMeleeSpell = nil
            RestoreMainHandColor()
            RefreshHunterVisibility()
        end
    end

    ns.UpdateHunterQueueTint = UpdateHunterQueueTint
    ns.UpdateHunterRangeHelperColor = function (rangeState)
        ApplyHunterRangeHelperColor(rangeState or GetHunterRangeState(ns.barTestActive == true) or "ranged")
    end
    ns.UpdateHunterRangeHelperVisual = UpdateHunterRangeHelperVisual

    local function ApplyHunterQueueTint(spellValue)
        if not ns.mhBar then
            return
        end

        local alpha = (ns.mhBarBaseColor and ns.mhBarBaseColor.a) or 1
        if ns.HUNTER_RAPTOR_STRIKE_SPELLS and ns.HUNTER_RAPTOR_STRIKE_SPELLS[spellValue] then
            local queueChanged = ns.hunterQueuedMeleeSpell ~= spellValue
            ns.hunterQueuedMeleeSpell = spellValue
            ns.mhBar:SetStatusBarColor(HUNTER_RAPTOR_TINT.r, HUNTER_RAPTOR_TINT.g, HUNTER_RAPTOR_TINT.b, alpha)
            if queueChanged then
                RefreshHunterVisibility()
            end
        else
            RestoreMainHandColor()
        end
    end

    -- Queue indicator colors restore to the base MH tint on the next real swing.
    ns.OnMeleeSwing = function (slot)
        if slot == "mh" and ns.mhBar then
            ns.hunterQueuedMeleeSpell = nil
            RestoreMainHandColor()
        end
    end

    ns.ClearHunterQueueTint = function ()
        if ns.hunterQueuedMeleeSpell then
            ns.hunterQueuedMeleeSpell = nil
            RestoreMainHandColor()
            RefreshHunterVisibility()
            return
        end
        RestoreMainHandColor()
    end

    -- Hook hunter queued attacks so Raptor Strike owns its own next-attack tint.
    if ns.RegisterSpellcastSucceededHook then
        ns.RegisterSpellcastSucceededHook(function (unit, castGUIDOrSpellName, spellId)
            local spellToken = spellId ~= nil and spellId or castGUIDOrSpellName
            if unit == "player" and ns.HUNTER_RAPTOR_STRIKE_SPELLS and ns.HUNTER_RAPTOR_STRIKE_SPELLS[spellToken] then
                ApplyHunterQueueTint(spellToken)
            end
            if ns.UpdateHunterQueueTint then
                ns.UpdateHunterQueueTint(true)
            end
        end)
    end

    local hunterAspectIcon = nil
    local function CreateHunterAspectIcon()
        if hunterAspectIcon then return hunterAspectIcon end
        local icon = CreateFrame("Frame", nil, UIParent)
        icon:SetFrameStrata("DIALOG")
        icon:EnableMouse(false)
        icon.defaultSize = ns.GetHunterRangeHelperWidth and ns.GetHunterRangeHelperWidth() or 7
        icon:SetSize(icon.defaultSize, icon.defaultSize)
        icon.texture = icon:CreateTexture(nil, "BACKGROUND")
        icon.texture:SetAllPoints()
        icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon.border = icon:CreateTexture(nil, "OVERLAY")
        icon.border:SetDrawLayer("OVERLAY", -1)
        icon.border:SetColorTexture(0, 0, 0, 0.65)
        icon.border:SetPoint("TOPLEFT", -1, 1)
        icon.border:SetPoint("BOTTOMRIGHT", 1, -1)
        icon:Hide()
        hunterAspectIcon = icon
        return icon
    end

    ns.OnBarsCreated = function ()
        if not ns.rangedBar then
            return
        end

        if not ns.hunterRangeHelperBar then
            ns.hunterRangeHelperBar = EnsureVerticalHelperBar(
                "SuperSwingTimerHunterRangeHelperBar", ns.rangedBar,
                ns.GetHunterRangeHelperWidth and ns.GetHunterRangeHelperWidth() or 7,
                (ns.GetRangedBarTexture and ns.GetRangedBarTexture()) or (ns.GetBarTexture and ns.GetBarTexture())
                    or "Interface\\TargetingFrame\\UI-StatusBar"
            )
        end

        UpdateHunterRangeHelperVisual()

        -- Phase 3: Create + anchor aspect icon to the left of range helper
        local icon = CreateHunterAspectIcon()
        if icon.ClearAllPoints then icon:ClearAllPoints() end
        if icon.SetPoint then
            if ns.hunterRangeHelperBar then
                icon:SetPoint("RIGHT", ns.hunterRangeHelperBar, "LEFT", -2, 0)
            else
                icon:SetPoint("TOPRIGHT", ns.rangedBar, "TOPLEFT", -2, 0)
            end
        end
        if icon.SetAlpha then icon:SetAlpha(0) end
    end

    -- Phase 2: Hunter Rapid Fire CD + duration bar
    local RAPID_FIRE_SPELL_ID = 3045
    local RAPID_FIRE_NAME = ns.GetSpellInfo and (ns.GetSpellInfo(RAPID_FIRE_SPELL_ID) or "Rapid Fire") or "Rapid Fire"
    local RAPID_FIRE_DURATION = 15
    local rapidFireBar = nil
    local rapidFireUpdateInterval = 0.1
    local rapidFireTimer = 0
    local rapidFireStyleCache = nil

    local function SyncRapidFireBarStyle(force)
        if not rapidFireBar or not ns.rangedBar then
            return
        end

        local texture = (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        local width = (ns.rangedBar and ns.rangedBar:GetWidth()) or ns.BAR_WIDTH or 240
        local height = ns.HUNTER_RAPID_FIRE_BAR_HEIGHT or 4
        local color = ns.GetBarColor and ns.GetBarColor("rapidFireBar") or { r = 0.10, g = 0.80, b = 0.30, a = 0.85 }
        local r = color.r or 0.10
        local g = color.g or 0.80
        local b = color.b or 0.30
        local a = color.a or 0.85

        local cache = rapidFireStyleCache
        local changed = force == true or not cache
        if cache and not changed then
            changed = cache.texture ~= texture or cache.width ~= width
                or cache.height ~= height or cache.r ~= r
                or cache.g ~= g or cache.b ~= b
                or cache.a ~= a or cache.anchor ~= ns.rangedBar
        end

        if not changed then
            return
        end

        rapidFireBar:SetStatusBarTexture(texture)
        rapidFireBar:ClearAllPoints()
        rapidFireBar:SetPoint("BOTTOM", ns.rangedBar, "TOP", 0, 2)
        rapidFireBar:SetSize(width, height)
        rapidFireBar:SetStatusBarColor(r, g, b, a)
        if rapidFireBar.label then
            rapidFireBar.label:SetTextColor(r, g, b, a)
        end

        rapidFireStyleCache = {
            texture = texture,
            width = width,
            height = height,
            r = r,
            g = g,
            b = b,
            a = a,
            anchor = ns.rangedBar
        }
    end

    local function GetRapidFireAuraData()
        for index = 1, 40 do
            local auraName, duration, expirationTime, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then
                break
            end

            if auraSpellId == RAPID_FIRE_SPELL_ID or auraName == RAPID_FIRE_NAME then
                return auraName, duration, expirationTime, auraSpellId
            end
        end

        return nil
    end

    ns.ForceHunterRapidFireRefresh = function ()
        rapidFireTimer = rapidFireUpdateInterval
        if ns.UpdateHunterRapidFire then
            ns.UpdateHunterRapidFire(rapidFireUpdateInterval, true)
        end
    end

    ns.UpdateHunterRapidFire = function (elapsed, force)
        if not ns.rangedBar then return end
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if not db or db.showHunterRapidFireBar == false then
            if rapidFireBar then rapidFireBar:Hide() end
            return
        end
        -- Create lazily
        if not rapidFireBar then
            rapidFireBar = CreateFrame("StatusBar", nil, ns.rangedBar)
            rapidFireBar:SetSize(
                (ns.rangedBar and ns.rangedBar:GetWidth()) or ns.BAR_WIDTH or 240, ns.HUNTER_RAPID_FIRE_BAR_HEIGHT or 4
            )
            rapidFireBar:SetPoint("BOTTOM", ns.rangedBar, "TOP", 0, 2)
            rapidFireBar:SetStatusBarTexture(
                ns.GetBarTexture and ns.GetBarTexture() or "Interface\\TargetingFrame\\UI-StatusBar"
            )
            local rfColor = ns.GetBarColor and ns.GetBarColor("rapidFireBar")
                or { r = 0.10, g = 0.80, b = 0.30, a = 0.85 }
            rapidFireBar:SetStatusBarColor(rfColor.r, rfColor.g, rfColor.b, rfColor.a)
            rapidFireBar:SetMinMaxValues(0, 1)
            rapidFireBar:SetValue(0)
            rapidFireBar:EnableMouse(false)
            -- Background
            local bg = rapidFireBar:CreateTexture(nil, "BACKGROUND")
            bg:SetColorTexture(0, 0, 0, 0.5)
            bg:SetAllPoints(true)
            rapidFireBar.bg = bg
            -- Label
            local label = rapidFireBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("LEFT", rapidFireBar, "RIGHT", 2, 0)
            label:SetJustifyH("LEFT")
            label:SetTextColor(0.10, 0.80, 0.30, 0.85)
            label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
            rapidFireBar.label = label
        end

        rapidFireTimer = rapidFireTimer + (elapsed or 0)
        if not force and rapidFireTimer < rapidFireUpdateInterval then return end
        rapidFireTimer = 0

        SyncRapidFireBarStyle(force)

        local now = GetCurrentTime()
        local auraName, auraDuration, auraExpirationTime = GetRapidFireAuraData()
        if auraName then
            local remaining = 0
            if type(auraExpirationTime) == "number" and auraExpirationTime > 0 then
                remaining = math.max(auraExpirationTime - now, 0)
            elseif type(auraDuration) == "number" and auraDuration > 0 then
                remaining = auraDuration
            end

            local duration = (type(auraDuration) == "number" and auraDuration > 0) and auraDuration
                or RAPID_FIRE_DURATION
            rapidFireBar:SetMinMaxValues(0, duration)
            rapidFireBar:SetValue(math.max(remaining, 0))
            rapidFireBar:Show()
            if rapidFireBar.label then
                rapidFireBar.label:SetText(string.format("%.0fs", math.max(remaining, 0)))
            end
            return
        end

        -- No active aura — hide bar. Only show during Rapid Fire's DURATION, not its cooldown.
        rapidFireBar:Hide()
    end

    -- ============================================================
    -- Phase 3: Hunter Stance Icon (Aspect indicator)
    -- ============================================================
    -- Maps aspect aura names to spell IDs for proper spell icon textures
    local HUNTER_ASPECT_SPELL_IDS = {
        [13165] = true, -- Aspect of the Hawk (rank 1)
        [27044] = true, -- Aspect of the Hawk (rank 2)
        [5118] = true,  -- Aspect of the Cheetah
        [13163] = true, -- Aspect of the Monkey
        [13159] = true, -- Aspect of the Pack
        [20190] = true, -- Aspect of the Wild
        [34074] = true, -- Aspect of the Viper (TBC)
        [13171] = true  -- Aspect of the Beast
    }
    local HUNTER_ASPECT_NAMES = {}
    for spellId in pairs(HUNTER_ASPECT_SPELL_IDS) do
        local name = ns.GetSpellInfo and ns.GetSpellInfo(spellId)
        if name then
            HUNTER_ASPECT_NAMES[name] = true
        end
    end
    -- Fallback names for localized clients
    HUNTER_ASPECT_NAMES["Aspect of the Hawk"] = true
    HUNTER_ASPECT_NAMES["Aspect of the Cheetah"] = true
    HUNTER_ASPECT_NAMES["Aspect of the Monkey"] = true
    HUNTER_ASPECT_NAMES["Aspect of the Pack"] = true
    HUNTER_ASPECT_NAMES["Aspect of the Wild"] = true
    HUNTER_ASPECT_NAMES["Aspect of the Viper"] = true
    HUNTER_ASPECT_NAMES["Aspect of the Beast"] = true

    local function GetCurrentAspectData()
        for index = 1, 40 do
            local auraName, _, _, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then
                break
            end
            if HUNTER_ASPECT_NAMES[auraName] or (type(auraSpellId) == "number" and HUNTER_ASPECT_SPELL_IDS[auraSpellId]) then
                return auraName, auraSpellId or auraName
            end
        end
        return nil, nil
    end

    -- Update aspect icon each frame via ns.UpdateHunterAspect
    local hunterAspectTimer = 0
    local HUNTER_ASPECT_UPDATE_INTERVAL = 0.2
    ns.UpdateHunterAspect = function (elapsed)
        local icon = hunterAspectIcon
        if not icon or not ns.rangedBar then return end

        -- Guard: ranged bar may not be fully initialized
        local rangedGetAlpha = ns.rangedBar.GetAlpha
        if not rangedGetAlpha then
            icon:SetAlpha(0)
            return
        end
        local rangedVisible = (rangedGetAlpha(ns.rangedBar) or 0) > 0
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        local helperDisabled = (db and db.showHunterRangeHelper == false)
        if not rangedVisible or helperDisabled or (ns.IsMinimalMode and ns.IsMinimalMode()) then
            if icon.SetAlpha then
                icon:SetAlpha(0)
            end
            return
        end

        -- Throttle to avoid per-frame aura scan overhead
        hunterAspectTimer = hunterAspectTimer + (elapsed or 0)
        if hunterAspectTimer < HUNTER_ASPECT_UPDATE_INTERVAL then return end
        hunterAspectTimer = 0

        local aspectName, aspectToken = GetCurrentAspectData()
        if not aspectName then
            if icon.SetAlpha then
                icon:SetAlpha(0)
            end
            return
        end

        -- Resolve spell ID for icon texture with fallback
        local spellId = tonumber(aspectToken)
        local resolvedSpellId = spellId or aspectName
        if type(GetSpellTexture) == "function" then
            local ok, texturePath = pcall(GetSpellTexture, resolvedSpellId)
            if ok and type(texturePath) == "string" and texturePath ~= "" then
                if icon.texture and icon.texture.SetTexture then
                    icon.texture:SetTexture(texturePath)
                end
            end
        end

        -- Size: match the range helper width so it feels proportional
        local size = 7
        if type(ns.GetHunterRangeHelperWidth) == "function" then
            size = ns.GetHunterRangeHelperWidth() or 7
        end
        if type(size) ~= "number" or size < 4 then
            size = 4
        end
        if icon.SetSize then
            icon:SetSize(size, size)
        end

        if icon.SetAlpha then
            icon:SetAlpha(1)
        end
    end

    -- ============================================================
    -- Phase 3: Hunter CD/Buff Duration Icon Group (configurable via hunterBuffIconSize)
    -- ============================================================
    -- Racial ability spell IDs by race
    -- Orc: Blood Fury (20572), Troll: Berserking (26297), Dwarf: Stoneform (20594),
    -- Night Elf: Shadowmeld (58984), Tauren: War Stomp (20549), Draenei: Gift of the Naaru (28880)
    local HUNTER_RACIAL_SPELLS = {
        { spellId = 20572, name = "Blood Fury", label = "BF", kind = "buff" },
        { spellId = 26297, name = "Berserking", label = "BZ", kind = "buff" },
        { spellId = 20594, name = "Stoneform", label = "SF", kind = "buff" },
        { spellId = 58984, name = "Shadowmeld", label = "SM", kind = "buff" },
        { spellId = 20549, name = "War Stomp", label = "WS", kind = "cd" },
        { spellId = 28880, name = "Gift of the Naaru", label = "GN", kind = "buff" },
        { spellId = 20600, name = "Perception", label = "Per", kind = "buff" },
        { spellId = 28730, name = "Arcane Torrent", label = "AT", kind = "buff" },
    }
    local HUNTER_TRACKED_SPELLS = {
        { spellId = 19574, name = "Bestial Wrath", label = "BW", kind = "buff" },
        { spellId = 3045, name = "Rapid Fire", label = "RF", kind = "buff" },
        { spellId = 34692, name = "The Beast Within", label = "TBW", kind = "buff" },
        { spellId = 6150, name = "Quick Shots", label = "QS", kind = "buff" },
        { spellId = 34949, name = "Rapid Killing", label = "RK", kind = "buff" },
        { spellId = 34026, name = "Kill Command", label = "KC", kind = "cd" },
        { spellId = 23989, name = "Readiness", label = "Read", kind = "cd" },
        { spellId = 34477, name = "Misdirection", label = "MD", kind = "cd" },
    }
    -- Merge racials into tracked spells
    for _, racial in ipairs(HUNTER_RACIAL_SPELLS) do
        table.insert(HUNTER_TRACKED_SPELLS, racial)
    end
    local hunterBuffIcons = {}
    local hunterBuffTimer = 0
    local HUNTER_BUFF_UPDATE_INTERVAL = 0.15
    local HUNTER_BUFF_ICON_GAP = 3

    local function GetHunterSpellRemaining(info)
        -- Step 1: Scan helpful auras on the player (buffs)
        for index = 1, 40 do
            local auraName, duration, expirationTime, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then break end
            if auraSpellId == info.spellId or auraName == info.name then
                if type(expirationTime) == "number" and expirationTime > 0 then
                    return math.max(expirationTime - GetCurrentTime(), 0), math.max(duration or 1, 1)
                end
                return nil, nil
            end
        end
        -- Step 2: For CD-type, scan target harmful auras (debuffs like Hunter's Mark, Serpent Sting)
        if info.kind == "cd" then
            if type(UnitExists) == "function" and UnitExists("target")
                and type(UnitCanAttack) == "function" and UnitCanAttack("player", "target") then
                for index = 1, 40 do
                    local debuffName, _, debuffDuration, debuffExpiration, caster, debuffSpellId = GetHarmfulAuraData("target", index)
                    if not debuffName then break end
                    if caster == "player" and (debuffSpellId == info.spellId or debuffName == info.name) then
                        if type(debuffExpiration) == "number" and debuffExpiration > 0 then
                            return math.max(debuffExpiration - GetCurrentTime(), 0), math.max(debuffDuration or 1, 1)
                        end
                        return nil, nil
                    end
                end
            end
            -- Step 3: Fall back to cooldown tracking
            local startTime, cdDuration
            if type(GetSpellCooldown) == "function" then
                startTime, cdDuration = GetSpellCooldown(info.spellId)
            elseif C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
                local ok, cdInfo = pcall(C_Spell.GetSpellCooldown, info.spellId)
                if ok and cdInfo then
                    startTime = cdInfo.startTime
                    cdDuration = cdInfo.duration
                end
            end
            if type(startTime) ~= "number" or type(cdDuration) ~= "number" or cdDuration <= 0 then
                return nil, nil
            end
            -- Filter out GCD (1.5s) from real cooldowns
            if cdDuration <= 2.5 then
                return nil, nil
            end
            local remaining = math.max((startTime + cdDuration) - GetCurrentTime(), 0)
            if remaining <= 0 then return nil, nil end
            return remaining, cdDuration
        end
        return nil, nil
    end

    local function CreateHunterBuffIcons()
        if #hunterBuffIcons > 0 then return end
        local iconSize = SuperSwingTimerDB and SuperSwingTimerDB.hunterBuffIconSize or 25
        if type(iconSize) ~= "number" or iconSize <= 0 then iconSize = 25 end

        for _, spell in ipairs(HUNTER_TRACKED_SPELLS) do
            local icon = CreateFrame("Frame", nil, UIParent)
            icon:SetSize(iconSize, iconSize)
            icon:SetFrameStrata("DIALOG")
            icon:EnableMouse(false)
            icon.texture = icon:CreateTexture(nil, "BACKGROUND")
            icon.texture:SetAllPoints()
            icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            local texPath = GetSpellTexture and GetSpellTexture(spell.spellId)
            if texPath then icon.texture:SetTexture(texPath) end
            icon.glow = icon:CreateTexture(nil, "OVERLAY", nil, 7)
            icon.glow:SetAllPoints()
            icon.glow:SetColorTexture(1, 0.85, 0, 0)
            icon.glow:SetBlendMode("ADD")
            -- 4-edge outline border (not a full-face overlay)
            icon.border = {}
            icon.border.top = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.top:SetPoint("TOPLEFT", -1, 1)
            icon.border.top:SetPoint("TOPRIGHT", 1, 1)
            icon.border.top:SetHeight(1)
            icon.border.top:SetColorTexture(0, 0, 0, 0.65)
            icon.border.bottom = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.bottom:SetPoint("BOTTOMLEFT", -1, -1)
            icon.border.bottom:SetPoint("BOTTOMRIGHT", 1, -1)
            icon.border.bottom:SetHeight(1)
            icon.border.bottom:SetColorTexture(0, 0, 0, 0.65)
            icon.border.left = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.left:SetPoint("TOPLEFT", -1, 1)
            icon.border.left:SetPoint("BOTTOMLEFT", -1, -1)
            icon.border.left:SetWidth(1)
            icon.border.left:SetColorTexture(0, 0, 0, 0.65)
            icon.border.right = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.right:SetPoint("TOPRIGHT", 1, 1)
            icon.border.right:SetPoint("BOTTOMRIGHT", 1, -1)
            icon.border.right:SetWidth(1)
            icon.border.right:SetColorTexture(0, 0, 0, 0.65)
            icon.durationText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            icon.durationText:SetPoint("CENTER", icon, "TOP", 0, 0)
            icon.durationText:SetJustifyH("CENTER")
            icon.durationText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            icon.durationText:SetTextColor(1, 1, 1, 0.95)
            icon.durationText:Hide()
            icon:Hide()
            icon.spellId = spell.spellId
            icon.label = spell.label
            icon.kind = spell.kind
            table.insert(hunterBuffIcons, icon)
        end
    end

    ns.UpdateHunterBuffIcons = function (elapsed)
        CreateHunterBuffIcons()
        if not ns.rangedBar then return end
        if #hunterBuffIcons == 0 then return end

        hunterBuffTimer = hunterBuffTimer + (elapsed or 0.03)
        if hunterBuffTimer < HUNTER_BUFF_UPDATE_INTERVAL then return end
        hunterBuffTimer = 0

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showHunterBuffIcons == false then
            for _, icon in ipairs(hunterBuffIcons) do
                if icon and icon.Hide then icon:Hide() end
            end
            return
        end
        if ns.playerInCombat ~= true then
            for _, icon in ipairs(hunterBuffIcons) do
                if icon and icon.Hide then icon:Hide() end
            end
            return
        end

        local iconSize = SuperSwingTimerDB and SuperSwingTimerDB.hunterBuffIconSize or 25
        if type(iconSize) ~= "number" or iconSize <= 0 then iconSize = 25 end

        local activeIcons = {}
        for _, icon in ipairs(hunterBuffIcons) do
            if icon and icon.spellId then
                for _, spell in ipairs(HUNTER_TRACKED_SPELLS) do
                    if spell.spellId == icon.spellId then
                        local remaining, totalDuration = GetHunterSpellRemaining(spell)
                        if type(remaining) == "number" and remaining > 0
                            and type(totalDuration) == "number" and totalDuration > 0 then
                            table.insert(activeIcons, {
                                icon = icon,
                                remaining = remaining,
                                totalDuration = totalDuration
                            })
                        else
                            if icon.Hide then icon:Hide() end
                        end
                        break
                    end
                end
            elseif icon and icon.Hide then
                icon:Hide()
            end
        end

        local numActive = #activeIcons
        if numActive == 0 then return end

        local anchorBar = GetDebuffAnchorBar()
        if not anchorBar then return end
        -- Position icons above all visible target debuff duration bars
        local iconY = GetDebuffStackOffset({
            serpentStingBar,
            wingClipBar,
            concussionShotBar,
            immolationTrapBar,
            explosiveTrapBar,
            freezingTrapBar,
            frostTrapBar,
        }, anchorBar)
        if iconY < 4 then iconY = 4 end
        local barGetWidth = anchorBar.GetWidth
        if not barGetWidth then return end

        for idx, entry in ipairs(activeIcons) do
            local icon = entry.icon
            local remaining = entry.remaining
            local totalDuration = entry.totalDuration

            if icon.SetSize then icon:SetSize(iconSize, iconSize) end

            -- Right-align icons: first at bar right edge, stack leftward
            local xOffset = -(numActive - idx) * (iconSize + HUNTER_BUFF_ICON_GAP)
            local rightAlign = -(iconSize / 2)
            local finalX = rightAlign + xOffset

            if icon.ClearAllPoints then icon:ClearAllPoints() end
            if icon.SetPoint then icon:SetPoint("BOTTOM", anchorBar, "TOP", finalX, iconY) end

            -- Glow effect in the last 4 seconds
            if icon.glow and icon.glow.SetColorTexture then
                local shouldGlow = remaining <= 4 and remaining > 0
                if shouldGlow and totalDuration > 0 then
                    -- Pulse alpha between 0.15 and 0.55
                    local pulseAlpha = 0.15 + 0.40 * (0.5 + 0.5 * math.sin(GetCurrentTime() * 6))
                    icon.glow:SetColorTexture(1, 0.85, 0, pulseAlpha)
                    if icon.glow.Show then icon.glow:Show() end
                elseif icon.glow.Hide then
                    icon.glow:Hide()
                end
            end

            -- Countdown text
            if icon.durationText and icon.durationText.SetText then
                local text = remaining >= 3 and string.format("%.0f", remaining) or string.format("%.1f", remaining)
                icon.durationText:SetText(text)
                if icon.durationText.Show then icon.durationText:Show() end
            end

            if icon.Show then icon:Show() end
        end
    end

    -- ============================================================
    -- Serpent Sting debuff duration bar (Hunter)
    -- ============================================================
    local SERPENT_STING_BAR_HEIGHT = 6
    local SERPENT_STING_FALLBACK_DURATION = 15
    local SERPENT_STING_GLOW_WINDOW = 4
    local serpentStingBar = nil
    local nextSerpentStingUpdateAt = 0

    local function SetSerpentStingGlow(bar, remaining)
        if not bar then return end
        if bar.glowBorder then
            local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= SERPENT_STING_GLOW_WINDOW
            for _, edge in ipairs(bar.glowBorder) do
                if shouldGlow then edge:Show() else edge:Hide() end
            end
        end
    end

    local function EnsureSerpentStingBar()
        if serpentStingBar then return serpentStingBar end

        serpentStingBar = CreateFrame("StatusBar", nil, UIParent)
        serpentStingBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        serpentStingBar:SetStatusBarColor(0.10, 0.85, 0.15, 0.90)  -- bright serpent green
        serpentStingBar:SetMinMaxValues(0, 1)
        serpentStingBar:SetValue(0)
        serpentStingBar:SetHeight(SERPENT_STING_BAR_HEIGHT)
        serpentStingBar:EnableMouse(false)

        local bg = serpentStingBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        serpentStingBar.backgroundTexture = bg

        local glowBorder = {}
        for _, edgeDef in ipairs({
            { "TOPLEFT", "TOPRIGHT", "Height", 1, -1, 1, 1, 1 },
            { "BOTTOMLEFT", "BOTTOMRIGHT", "Height", 1, -1, -1, 1, -1 },
            { "TOPLEFT", "BOTTOMLEFT", "Width", 1, -1, 1, -1, -1 },
            { "TOPRIGHT", "BOTTOMRIGHT", "Width", 1, 1, 1, 1, -1 }
        }) do
            local tex = serpentStingBar:CreateTexture(nil, "OVERLAY")
            tex:SetPoint(edgeDef[1], serpentStingBar, edgeDef[2], edgeDef[4], edgeDef[5])
            tex:SetPoint(edgeDef[3], edgeDef[6], edgeDef[7], edgeDef[8])
            tex:SetColorTexture(0.10, 0.85, 0.15, 0.85)
            tex:Hide()
            glowBorder[#glowBorder + 1] = tex
        end
        serpentStingBar.glowBorder = glowBorder

        local label = serpentStingBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", serpentStingBar, "CENTER", 0, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        label:SetTextColor(1.0, 0.85, 0.25, 0.95)
        label:SetText("SS")
        serpentStingBar.label = label

        -- Spell icon (left side)
        local spellIcon = serpentStingBar:CreateTexture(nil, "OVERLAY")
        spellIcon:SetSize(SERPENT_STING_BAR_HEIGHT, SERPENT_STING_BAR_HEIGHT)
        spellIcon:SetPoint("LEFT", serpentStingBar, "LEFT", 2, 0)
        local texPath = GetSpellTexture and GetSpellTexture(27019)
        if texPath then spellIcon:SetTexture(texPath) end
        serpentStingBar.icon = spellIcon

        serpentStingBar:Hide()
        return serpentStingBar
    end

    local function GetTargetSerpentStingData()
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId =
                GetHarmfulAuraData("target", index, "HARMFUL")
            if not auraName then break end

            local isSerpentSting = false
            if type(auraSpellId) == "number" and ns.HUNTER_SERPENT_STING_IDS and ns.HUNTER_SERPENT_STING_IDS[auraSpellId] then
                isSerpentSting = true
            elseif auraName == ns.HUNTER_SERPENT_STING_NAME then
                isSerpentSting = true
            end

            if isSerpentSting and (caster == "player" or caster == nil) then
                return duration, expirationTime
            end
        end
        return nil
    end

    local function UpdateHunterSerpentStingBar(force)
        local now = GetCurrentTime()
        if not force and now < nextSerpentStingUpdateAt then return end
        nextSerpentStingUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showHunterSerpentStingBar == false then
            if serpentStingBar then serpentStingBar:Hide() end
            return
        end

        local bar = EnsureSerpentStingBar()
        if not bar then return end

        if type(UnitExists) ~= "function" or not UnitExists("target")
            or (type(UnitCanAttack) ~= "function" or not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        local duration, expirationTime = GetTargetSerpentStingData()
        if not duration and not expirationTime then
            SetSerpentStingGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then
            duration = SERPENT_STING_FALLBACK_DURATION
        end

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetSerpentStingGlow(bar, remaining)

        if bar.label and bar.label.SetText then
            bar.label:SetText(string.format("%.0f", math.max(remaining, 0)))
        end

        bar:Show()
    end

    -- ============================================================
    -- Wing Clip target debuff bar (Hunter melee snare)
    -- ============================================================
    local WING_CLIP_BAR_HEIGHT = 6
    local WING_CLIP_GLOW_WINDOW = 4
    local wingClipBar = nil
    local nextWingClipUpdateAt = 0

    local function SetWingClipGlow(bar, remaining)
        if not bar then return end
        if bar.glowBorder then
            local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= WING_CLIP_GLOW_WINDOW
            for _, edge in ipairs(bar.glowBorder) do
                if shouldGlow then edge:Show() else edge:Hide() end
            end
        end
    end

    local function EnsureWingClipBar()
        if wingClipBar then return wingClipBar end

        wingClipBar = CreateFrame("StatusBar", nil, UIParent)
        wingClipBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        wingClipBar:SetStatusBarColor(0.85, 0.75, 0.10, 0.90)  -- yellow
        wingClipBar:SetMinMaxValues(0, 1)
        wingClipBar:SetValue(0)
        wingClipBar:SetHeight(WING_CLIP_BAR_HEIGHT)
        wingClipBar:EnableMouse(false)

        local bg = wingClipBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        wingClipBar.backgroundTexture = bg

        local glowBorder = {}
        for _, edgeDef in ipairs({
            { "TOPLEFT", "TOPRIGHT", "Height", 1, -1, 1, 1, 1 },
            { "BOTTOMLEFT", "BOTTOMRIGHT", "Height", 1, -1, -1, 1, -1 },
            { "TOPLEFT", "BOTTOMLEFT", "Width", 1, -1, 1, -1, -1 },
            { "TOPRIGHT", "BOTTOMRIGHT", "Width", 1, 1, 1, 1, -1 }
        }) do
            local tex = wingClipBar:CreateTexture(nil, "OVERLAY")
            tex:SetPoint(edgeDef[1], wingClipBar, edgeDef[2], edgeDef[4], edgeDef[5])
            tex:SetPoint(edgeDef[3], edgeDef[6], edgeDef[7], edgeDef[8])
            tex:SetColorTexture(0.85, 0.75, 0.10, 0.85)
            tex:Hide()
            glowBorder[#glowBorder + 1] = tex
        end
        wingClipBar.glowBorder = glowBorder

        local label = wingClipBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", wingClipBar, "CENTER", 0, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        label:SetTextColor(1.0, 0.85, 0.25, 0.95)
        label:SetText("WC")
        wingClipBar.label = label

        -- Spell icon (left side)
        local spellIcon = wingClipBar:CreateTexture(nil, "OVERLAY")
        spellIcon:SetSize(WING_CLIP_BAR_HEIGHT, WING_CLIP_BAR_HEIGHT)
        spellIcon:SetPoint("LEFT", wingClipBar, "LEFT", 2, 0)
        local texPath = GetSpellTexture and GetSpellTexture(2974)
        if texPath then spellIcon:SetTexture(texPath) end
        wingClipBar.icon = spellIcon

        wingClipBar:Hide()
        return wingClipBar
    end

    local function GetTargetWingClipData()
        local wcName = ns.GetSpellInfo and ns.GetSpellInfo(2974) or "Wing Clip"
        if not wcName then return nil end
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId =
                GetHarmfulAuraData("target", index, "HARMFUL")
            if not auraName then break end
            local isWC = false
            if type(auraSpellId) == "number" and auraSpellId == 2974 then
                isWC = true
            elseif auraName == wcName then
                isWC = true
            end
            if isWC and (caster == "player" or caster == nil) then
                return duration, expirationTime
            end
        end
        return nil
    end

    local function UpdateHunterWingClipBar(force)
        local now = GetCurrentTime()
        if not force and now < nextWingClipUpdateAt then return end
        nextWingClipUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showHunterWingClipBar == false then
            if wingClipBar then wingClipBar:Hide() end
            return
        end

        local bar = EnsureWingClipBar()
        if not bar then return end

        if type(UnitExists) ~= "function" or not UnitExists("target")
            or (type(UnitCanAttack) ~= "function" or not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        local duration, expirationTime = GetTargetWingClipData()
        if not duration and not expirationTime then
            SetWingClipGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then duration = 10 end  -- WC has 10s duration

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetWingClipGlow(bar, remaining)

        if bar.label and bar.label.SetText then
            bar.label:SetText(string.format("%.0f", math.max(remaining, 0)))
        end

        bar:Show()
    end

    -- ============================================================
    -- Concussion Shot target debuff bar (Hunter ranged snare)
    -- ============================================================
    local CONCUSSION_SHOT_BAR_HEIGHT = 6
    local CONCUSSION_SHOT_GLOW_WINDOW = 4
    local concussionShotBar = nil
    local nextConcussionShotUpdateAt = 0

    local function SetConcussionShotGlow(bar, remaining)
        if not bar then return end
        if bar.glowBorder then
            local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= CONCUSSION_SHOT_GLOW_WINDOW
            for _, edge in ipairs(bar.glowBorder) do
                if shouldGlow then edge:Show() else edge:Hide() end
            end
        end
    end

    local function EnsureConcussionShotBar()
        if concussionShotBar then return concussionShotBar end

        concussionShotBar = CreateFrame("StatusBar", nil, UIParent)
        concussionShotBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        concussionShotBar:SetStatusBarColor(0.55, 0.55, 0.55, 0.90)  -- grey
        concussionShotBar:SetMinMaxValues(0, 1)
        concussionShotBar:SetValue(0)
        concussionShotBar:SetHeight(CONCUSSION_SHOT_BAR_HEIGHT)
        concussionShotBar:EnableMouse(false)

        local bg = concussionShotBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        concussionShotBar.backgroundTexture = bg

        local glowBorder = {}
        for _, edgeDef in ipairs({
            { "TOPLEFT", "TOPRIGHT", "Height", 1, -1, 1, 1, 1 },
            { "BOTTOMLEFT", "BOTTOMRIGHT", "Height", 1, -1, -1, 1, -1 },
            { "TOPLEFT", "BOTTOMLEFT", "Width", 1, -1, 1, -1, -1 },
            { "TOPRIGHT", "BOTTOMRIGHT", "Width", 1, 1, 1, 1, -1 }
        }) do
            local tex = concussionShotBar:CreateTexture(nil, "OVERLAY")
            tex:SetPoint(edgeDef[1], concussionShotBar, edgeDef[2], edgeDef[4], edgeDef[5])
            tex:SetPoint(edgeDef[3], edgeDef[6], edgeDef[7], edgeDef[8])
            tex:SetColorTexture(0.55, 0.55, 0.55, 0.85)
            tex:Hide()
            glowBorder[#glowBorder + 1] = tex
        end
        concussionShotBar.glowBorder = glowBorder

        local label = concussionShotBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", concussionShotBar, "CENTER", 0, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        label:SetTextColor(1.0, 0.85, 0.25, 0.95)
        label:SetText("CS")
        concussionShotBar.label = label

        -- Spell icon (left side)
        local spellIcon = concussionShotBar:CreateTexture(nil, "OVERLAY")
        spellIcon:SetSize(CONCUSSION_SHOT_BAR_HEIGHT, CONCUSSION_SHOT_BAR_HEIGHT)
        spellIcon:SetPoint("LEFT", concussionShotBar, "LEFT", 2, 0)
        local csTexPath = GetSpellTexture and GetSpellTexture(5116)
        if csTexPath then spellIcon:SetTexture(csTexPath) end
        concussionShotBar.icon = spellIcon

        concussionShotBar:Hide()
        return concussionShotBar
    end

    local function GetTargetConcussionShotData()
        local csName = ns.HUNTER_CONCUSSION_SHOT_NAME or (ns.GetSpellInfo and ns.GetSpellInfo(5116) or "Concussion Shot")
        if not csName then return nil end
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId =
                GetHarmfulAuraData("target", index, "HARMFUL")
            if not auraName then break end
            local isCS = false
            if type(auraSpellId) == "number" and ns.HUNTER_CONCUSSION_SHOT_IDS and ns.HUNTER_CONCUSSION_SHOT_IDS[auraSpellId] then
                isCS = true
            elseif auraName == csName then
                isCS = true
            end
            if isCS and (caster == "player" or caster == nil) then
                return duration, expirationTime
            end
        end
        return nil
    end

    local function UpdateHunterConcussionShotBar(force)
        local now = GetCurrentTime()
        if not force and now < nextConcussionShotUpdateAt then return end
        nextConcussionShotUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showHunterConcussionShotBar == false then
            if concussionShotBar then concussionShotBar:Hide() end
            return
        end

        local bar = EnsureConcussionShotBar()
        if not bar then return end

        if type(UnitExists) ~= "function" or not UnitExists("target")
            or (type(UnitCanAttack) ~= "function" or not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        local duration, expirationTime = GetTargetConcussionShotData()
        if not duration and not expirationTime then
            SetConcussionShotGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then duration = 4 end  -- CS has 4s duration

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetConcussionShotGlow(bar, remaining)

        if bar.label and bar.label.SetText then
            bar.label:SetText(string.format("%.0f", math.max(remaining, 0)))
        end

        bar:Show()
    end

    -- ============================================================
    -- Immolation Trap target debuff bar (Hunter fire trap)
    -- ============================================================
    local IMMOLATION_TRAP_BAR_HEIGHT = 6
    local IMMOLATION_TRAP_GLOW_WINDOW = 4
    local immolationTrapBar = nil
    local nextImmolationTrapUpdateAt = 0

    local function SetImmolationTrapGlow(bar, remaining)
        if not bar then return end
        if bar.glowBorder then
            local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= IMMOLATION_TRAP_GLOW_WINDOW
            for _, edge in ipairs(bar.glowBorder) do
                if shouldGlow then edge:Show() else edge:Hide() end
            end
        end
    end

    local function EnsureImmolationTrapBar()
        if immolationTrapBar then return immolationTrapBar end

        immolationTrapBar = CreateFrame("StatusBar", nil, UIParent)
        immolationTrapBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        immolationTrapBar:SetStatusBarColor(0.85, 0.40, 0.10, 0.90)  -- fire orange
        immolationTrapBar:SetMinMaxValues(0, 1)
        immolationTrapBar:SetValue(0)
        immolationTrapBar:SetHeight(IMMOLATION_TRAP_BAR_HEIGHT)
        immolationTrapBar:EnableMouse(false)

        local bg = immolationTrapBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        immolationTrapBar.backgroundTexture = bg

        local glowBorder = {}
        for _, edgeDef in ipairs({
            { "TOPLEFT", "TOPRIGHT", "Height", 1, -1, 1, 1, 1 },
            { "BOTTOMLEFT", "BOTTOMRIGHT", "Height", 1, -1, -1, 1, -1 },
            { "TOPLEFT", "BOTTOMLEFT", "Width", 1, -1, 1, -1, -1 },
            { "TOPRIGHT", "BOTTOMRIGHT", "Width", 1, 1, 1, 1, -1 }
        }) do
            local tex = immolationTrapBar:CreateTexture(nil, "OVERLAY")
            tex:SetPoint(edgeDef[1], immolationTrapBar, edgeDef[2], edgeDef[4], edgeDef[5])
            tex:SetPoint(edgeDef[3], edgeDef[6], edgeDef[7], edgeDef[8])
            tex:SetColorTexture(0.85, 0.40, 0.10, 0.85)
            tex:Hide()
            glowBorder[#glowBorder + 1] = tex
        end
        immolationTrapBar.glowBorder = glowBorder

        local label = immolationTrapBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", immolationTrapBar, "CENTER", 0, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        label:SetTextColor(1.0, 0.85, 0.25, 0.95)
        label:SetText("IT")
        immolationTrapBar.label = label

        -- Spell icon (left side)
        local spellIcon = immolationTrapBar:CreateTexture(nil, "OVERLAY")
        spellIcon:SetSize(IMMOLATION_TRAP_BAR_HEIGHT, IMMOLATION_TRAP_BAR_HEIGHT)
        spellIcon:SetPoint("LEFT", immolationTrapBar, "LEFT", 2, 0)
        local itFirstId = next(ns.HUNTER_IMMOLATION_TRAP_IDS)
        local itTexPath = itFirstId and GetSpellTexture and GetSpellTexture(itFirstId)
        if itTexPath then spellIcon:SetTexture(itTexPath) end
        immolationTrapBar.icon = spellIcon

        immolationTrapBar:Hide()
        return immolationTrapBar
    end

    local function GetTargetImmolationTrapData()
        local trapName = ns.HUNTER_IMMOLATION_TRAP_NAME or (ns.GetSpellInfo and ns.GetSpellInfo(13795) or "Immolation Trap")
        if not trapName then return nil end
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId =
                GetHarmfulAuraData("target", index, "HARMFUL")
            if not auraName then break end
            local isTrap = false
            if type(auraSpellId) == "number" and ns.HUNTER_IMMOLATION_TRAP_IDS and ns.HUNTER_IMMOLATION_TRAP_IDS[auraSpellId] then
                isTrap = true
            elseif auraName == trapName then
                isTrap = true
            end
            if isTrap and (caster == "player" or caster == nil) then
                return duration, expirationTime
            end
        end
        return nil
    end

    local function UpdateHunterImmolationTrapBar(force)
        local now = GetCurrentTime()
        if not force and now < nextImmolationTrapUpdateAt then return end
        nextImmolationTrapUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showHunterImmolationTrapBar == false then
            if immolationTrapBar then immolationTrapBar:Hide() end
            return
        end

        local bar = EnsureImmolationTrapBar()
        if not bar then return end

        if type(UnitExists) ~= "function" or not UnitExists("target")
            or (type(UnitCanAttack) ~= "function" or not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        local duration, expirationTime = GetTargetImmolationTrapData()
        if not duration and not expirationTime then
            SetImmolationTrapGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then duration = 15 end  -- Immolation Trap has 15s duration

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetImmolationTrapGlow(bar, remaining)

        if bar.label and bar.label.SetText then
            bar.label:SetText(string.format("%.0f", math.max(remaining, 0)))
        end

        bar:Show()
    end

    -- ============================================================
    -- Explosive Trap target debuff bar (Hunter fire trap)
    -- ============================================================
    local EXPLOSIVE_TRAP_BAR_HEIGHT = 6
    local EXPLOSIVE_TRAP_GLOW_WINDOW = 4
    local explosiveTrapBar = nil
    local nextExplosiveTrapUpdateAt = 0

    local function SetExplosiveTrapGlow(bar, remaining)
        if not bar then return end
        if bar.glowBorder then
            local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= EXPLOSIVE_TRAP_GLOW_WINDOW
            for _, edge in ipairs(bar.glowBorder) do
                if shouldGlow then edge:Show() else edge:Hide() end
            end
        end
    end

    local function EnsureExplosiveTrapBar()
        if explosiveTrapBar then return explosiveTrapBar end

        explosiveTrapBar = CreateFrame("StatusBar", nil, UIParent)
        explosiveTrapBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        explosiveTrapBar:SetStatusBarColor(0.90, 0.30, 0.10, 0.90)  -- red-orange
        explosiveTrapBar:SetMinMaxValues(0, 1)
        explosiveTrapBar:SetValue(0)
        explosiveTrapBar:SetHeight(EXPLOSIVE_TRAP_BAR_HEIGHT)
        explosiveTrapBar:EnableMouse(false)

        local bg = explosiveTrapBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        explosiveTrapBar.backgroundTexture = bg

        local glowBorder = {}
        for _, edgeDef in ipairs({
            { "TOPLEFT", "TOPRIGHT", "Height", 1, -1, 1, 1, 1 },
            { "BOTTOMLEFT", "BOTTOMRIGHT", "Height", 1, -1, -1, 1, -1 },
            { "TOPLEFT", "BOTTOMLEFT", "Width", 1, -1, 1, -1, -1 },
            { "TOPRIGHT", "BOTTOMRIGHT", "Width", 1, 1, 1, 1, -1 }
        }) do
            local tex = explosiveTrapBar:CreateTexture(nil, "OVERLAY")
            tex:SetPoint(edgeDef[1], explosiveTrapBar, edgeDef[2], edgeDef[4], edgeDef[5])
            tex:SetPoint(edgeDef[3], edgeDef[6], edgeDef[7], edgeDef[8])
            tex:SetColorTexture(0.90, 0.30, 0.10, 0.85)
            tex:Hide()
            glowBorder[#glowBorder + 1] = tex
        end
        explosiveTrapBar.glowBorder = glowBorder

        local label = explosiveTrapBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", explosiveTrapBar, "CENTER", 0, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        label:SetTextColor(1.0, 0.85, 0.25, 0.95)
        label:SetText("ET")
        explosiveTrapBar.label = label

        -- Spell icon (left side)
        local spellIcon = explosiveTrapBar:CreateTexture(nil, "OVERLAY")
        spellIcon:SetSize(EXPLOSIVE_TRAP_BAR_HEIGHT, EXPLOSIVE_TRAP_BAR_HEIGHT)
        spellIcon:SetPoint("LEFT", explosiveTrapBar, "LEFT", 2, 0)
        local etFirstId = next(ns.HUNTER_EXPLOSIVE_TRAP_IDS)
        local etTexPath = etFirstId and GetSpellTexture and GetSpellTexture(etFirstId)
        if etTexPath then spellIcon:SetTexture(etTexPath) end
        explosiveTrapBar.icon = spellIcon

        explosiveTrapBar:Hide()
        return explosiveTrapBar
    end

    local function GetTargetExplosiveTrapData()
        local trapName = ns.HUNTER_EXPLOSIVE_TRAP_NAME or (ns.GetSpellInfo and ns.GetSpellInfo(13813) or "Explosive Trap")
        if not trapName then return nil end
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId =
                GetHarmfulAuraData("target", index, "HARMFUL")
            if not auraName then break end
            local isTrap = false
            if type(auraSpellId) == "number" and ns.HUNTER_EXPLOSIVE_TRAP_IDS and ns.HUNTER_EXPLOSIVE_TRAP_IDS[auraSpellId] then
                isTrap = true
            elseif auraName == trapName then
                isTrap = true
            end
            if isTrap and (caster == "player" or caster == nil) then
                return duration, expirationTime
            end
        end
        return nil
    end

    local function UpdateHunterExplosiveTrapBar(force)
        local now = GetCurrentTime()
        if not force and now < nextExplosiveTrapUpdateAt then return end
        nextExplosiveTrapUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showHunterExplosiveTrapBar == false then
            if explosiveTrapBar then explosiveTrapBar:Hide() end
            return
        end

        local bar = EnsureExplosiveTrapBar()
        if not bar then return end

        if type(UnitExists) ~= "function" or not UnitExists("target")
            or (type(UnitCanAttack) ~= "function" or not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        local duration, expirationTime = GetTargetExplosiveTrapData()
        if not duration and not expirationTime then
            SetExplosiveTrapGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then duration = 15 end  -- Explosive Trap has 15s duration

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetExplosiveTrapGlow(bar, remaining)

        if bar.label and bar.label.SetText then
            bar.label:SetText(string.format("%.0f", math.max(remaining, 0)))
        end

        bar:Show()
    end

    -- ============================================================
    -- Freezing Trap target debuff bar (Hunter CC trap)
    -- ============================================================
    local FREEZING_TRAP_BAR_HEIGHT = 6
    local FREEZING_TRAP_GLOW_WINDOW = 4
    local freezingTrapBar = nil
    local nextFreezingTrapUpdateAt = 0

    local function SetFreezingTrapGlow(bar, remaining)
        if not bar then return end
        if bar.glowBorder then
            local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= FREEZING_TRAP_GLOW_WINDOW
            for _, edge in ipairs(bar.glowBorder) do
                if shouldGlow then edge:Show() else edge:Hide() end
            end
        end
    end

    local function EnsureFreezingTrapBar()
        if freezingTrapBar then return freezingTrapBar end

        freezingTrapBar = CreateFrame("StatusBar", nil, UIParent)
        freezingTrapBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        freezingTrapBar:SetStatusBarColor(0.30, 0.65, 0.95, 0.90)  -- icy blue
        freezingTrapBar:SetMinMaxValues(0, 1)
        freezingTrapBar:SetValue(0)
        freezingTrapBar:SetHeight(FREEZING_TRAP_BAR_HEIGHT)
        freezingTrapBar:EnableMouse(false)

        local bg = freezingTrapBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        freezingTrapBar.backgroundTexture = bg

        local glowBorder = {}
        for _, edgeDef in ipairs({
            { "TOPLEFT", "TOPRIGHT", "Height", 1, -1, 1, 1, 1 },
            { "BOTTOMLEFT", "BOTTOMRIGHT", "Height", 1, -1, -1, 1, -1 },
            { "TOPLEFT", "BOTTOMLEFT", "Width", 1, -1, 1, -1, -1 },
            { "TOPRIGHT", "BOTTOMRIGHT", "Width", 1, 1, 1, 1, -1 }
        }) do
            local tex = freezingTrapBar:CreateTexture(nil, "OVERLAY")
            tex:SetPoint(edgeDef[1], freezingTrapBar, edgeDef[2], edgeDef[4], edgeDef[5])
            tex:SetPoint(edgeDef[3], edgeDef[6], edgeDef[7], edgeDef[8])
            tex:SetColorTexture(0.30, 0.65, 0.95, 0.85)
            tex:Hide()
            glowBorder[#glowBorder + 1] = tex
        end
        freezingTrapBar.glowBorder = glowBorder

        local label = freezingTrapBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", freezingTrapBar, "CENTER", 0, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        label:SetTextColor(1.0, 0.85, 0.25, 0.95)
        label:SetText("FZ")
        freezingTrapBar.label = label

        -- Spell icon (left side)
        local spellIcon = freezingTrapBar:CreateTexture(nil, "OVERLAY")
        spellIcon:SetSize(FREEZING_TRAP_BAR_HEIGHT, FREEZING_TRAP_BAR_HEIGHT)
        spellIcon:SetPoint("LEFT", freezingTrapBar, "LEFT", 2, 0)
        local ftFirstId = next(ns.HUNTER_FREEZING_TRAP_IDS)
        local ftTexPath = ftFirstId and GetSpellTexture and GetSpellTexture(ftFirstId)
        if ftTexPath then spellIcon:SetTexture(ftTexPath) end
        freezingTrapBar.icon = spellIcon

        freezingTrapBar:Hide()
        return freezingTrapBar
    end

    local function GetTargetFreezingTrapData()
        local trapName = ns.HUNTER_FREEZING_TRAP_NAME or (ns.GetSpellInfo and ns.GetSpellInfo(1499) or "Freezing Trap")
        if not trapName then return nil end
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId =
                GetHarmfulAuraData("target", index, "HARMFUL")
            if not auraName then break end
            local isTrap = false
            if type(auraSpellId) == "number" and ns.HUNTER_FREEZING_TRAP_IDS and ns.HUNTER_FREEZING_TRAP_IDS[auraSpellId] then
                isTrap = true
            elseif auraName == trapName then
                isTrap = true
            end
            if isTrap and (caster == "player" or caster == nil) then
                return duration, expirationTime
            end
        end
        return nil
    end

    local function UpdateHunterFreezingTrapBar(force)
        local now = GetCurrentTime()
        if not force and now < nextFreezingTrapUpdateAt then return end
        nextFreezingTrapUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showHunterFreezingTrapBar == false then
            if freezingTrapBar then freezingTrapBar:Hide() end
            return
        end

        local bar = EnsureFreezingTrapBar()
        if not bar then return end

        if type(UnitExists) ~= "function" or not UnitExists("target")
            or (type(UnitCanAttack) ~= "function" or not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        local duration, expirationTime = GetTargetFreezingTrapData()
        if not duration and not expirationTime then
            SetFreezingTrapGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then duration = 10 end  -- Freezing Trap has 10s base duration

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetFreezingTrapGlow(bar, remaining)

        if bar.label and bar.label.SetText then
            bar.label:SetText(string.format("%.0f", math.max(remaining, 0)))
        end

        bar:Show()
    end

    -- ============================================================
    -- Frost Trap target debuff bar (Hunter slow trap)
    -- ============================================================
    local FROST_TRAP_BAR_HEIGHT = 6
    local FROST_TRAP_GLOW_WINDOW = 4
    local frostTrapBar = nil
    local nextFrostTrapUpdateAt = 0

    local function SetFrostTrapGlow(bar, remaining)
        if not bar then return end
        if bar.glowBorder then
            local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= FROST_TRAP_GLOW_WINDOW
            for _, edge in ipairs(bar.glowBorder) do
                if shouldGlow then edge:Show() else edge:Hide() end
            end
        end
    end

    local function EnsureFrostTrapBar()
        if frostTrapBar then return frostTrapBar end

        frostTrapBar = CreateFrame("StatusBar", nil, UIParent)
        frostTrapBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        frostTrapBar:SetStatusBarColor(0.50, 0.70, 0.95, 0.90)  -- pale blue
        frostTrapBar:SetMinMaxValues(0, 1)
        frostTrapBar:SetValue(0)
        frostTrapBar:SetHeight(FROST_TRAP_BAR_HEIGHT)
        frostTrapBar:EnableMouse(false)

        local bg = frostTrapBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        frostTrapBar.backgroundTexture = bg

        local glowBorder = {}
        for _, edgeDef in ipairs({
            { "TOPLEFT", "TOPRIGHT", "Height", 1, -1, 1, 1, 1 },
            { "BOTTOMLEFT", "BOTTOMRIGHT", "Height", 1, -1, -1, 1, -1 },
            { "TOPLEFT", "BOTTOMLEFT", "Width", 1, -1, 1, -1, -1 },
            { "TOPRIGHT", "BOTTOMRIGHT", "Width", 1, 1, 1, 1, -1 }
        }) do
            local tex = frostTrapBar:CreateTexture(nil, "OVERLAY")
            tex:SetPoint(edgeDef[1], frostTrapBar, edgeDef[2], edgeDef[4], edgeDef[5])
            tex:SetPoint(edgeDef[3], edgeDef[6], edgeDef[7], edgeDef[8])
            tex:SetColorTexture(0.50, 0.70, 0.95, 0.85)
            tex:Hide()
            glowBorder[#glowBorder + 1] = tex
        end
        frostTrapBar.glowBorder = glowBorder

        local label = frostTrapBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", frostTrapBar, "CENTER", 0, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        label:SetTextColor(1.0, 0.85, 0.25, 0.95)
        label:SetText("FT")
        frostTrapBar.label = label

        -- Spell icon (left side)
        local spellIcon = frostTrapBar:CreateTexture(nil, "OVERLAY")
        spellIcon:SetSize(FROST_TRAP_BAR_HEIGHT, FROST_TRAP_BAR_HEIGHT)
        spellIcon:SetPoint("LEFT", frostTrapBar, "LEFT", 2, 0)
        local froFirstId = next(ns.HUNTER_FROST_TRAP_IDS)
        local froTexPath = froFirstId and GetSpellTexture and GetSpellTexture(froFirstId)
        if froTexPath then spellIcon:SetTexture(froTexPath) end
        frostTrapBar.icon = spellIcon

        frostTrapBar:Hide()
        return frostTrapBar
    end

    local function GetTargetFrostTrapData()
        local trapName = ns.HUNTER_FROST_TRAP_NAME or (ns.GetSpellInfo and ns.GetSpellInfo(13809) or "Frost Trap")
        if not trapName then return nil end
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId =
                GetHarmfulAuraData("target", index, "HARMFUL")
            if not auraName then break end
            local isTrap = false
            if type(auraSpellId) == "number" and ns.HUNTER_FROST_TRAP_IDS and ns.HUNTER_FROST_TRAP_IDS[auraSpellId] then
                isTrap = true
            elseif auraName == trapName then
                isTrap = true
            end
            if isTrap and (caster == "player" or caster == nil) then
                return duration, expirationTime
            end
        end
        return nil
    end

    local function UpdateHunterFrostTrapBar(force)
        local now = GetCurrentTime()
        if not force and now < nextFrostTrapUpdateAt then return end
        nextFrostTrapUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showHunterFrostTrapBar == false then
            if frostTrapBar then frostTrapBar:Hide() end
            return
        end

        local bar = EnsureFrostTrapBar()
        if not bar then return end

        if type(UnitExists) ~= "function" or not UnitExists("target")
            or (type(UnitCanAttack) ~= "function" or not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        local duration, expirationTime = GetTargetFrostTrapData()
        if not duration and not expirationTime then
            SetFrostTrapGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then duration = 12 end  -- Frost Trap has 12s duration

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetFrostTrapGlow(bar, remaining)

        if bar.label and bar.label.SetText then
            bar.label:SetText(string.format("%.0f", math.max(remaining, 0)))
        end

        bar:Show()
    end

    -- Register Hunter OnUpdate hook (aspect + debuff bars + buff icons)
    -- Guard prevents double-registration on UI reload.
    if not ns._hunterHookRegistered then
        ns.RegisterOnUpdateHook(function (elapsed)
            if ns.UpdateHunterAspect then ns.UpdateHunterAspect(elapsed) end
            UpdateHunterSerpentStingBar(false)
            UpdateHunterWingClipBar(false)
            UpdateHunterConcussionShotBar(false)
            UpdateHunterImmolationTrapBar(false)
            UpdateHunterExplosiveTrapBar(false)
            UpdateHunterFreezingTrapBar(false)
            UpdateHunterFrostTrapBar(false)
            -- Restack all visible debuff bars above the anchor bar dynamically
            RestackDebuffBars({serpentStingBar, wingClipBar, concussionShotBar, immolationTrapBar, explosiveTrapBar, freezingTrapBar, frostTrapBar}, GetDebuffAnchorBar())
            if ns.UpdateHunterBuffIcons then ns.UpdateHunterBuffIcons(elapsed) end
        end)
        ns._hunterHookRegistered = true
    end
    pcall(UpdateHunterSerpentStingBar, true)
    pcall(UpdateHunterWingClipBar, true)
    pcall(UpdateHunterConcussionShotBar, true)
    pcall(UpdateHunterImmolationTrapBar, true)
    pcall(UpdateHunterExplosiveTrapBar, true)
    pcall(UpdateHunterFreezingTrapBar, true)
    pcall(UpdateHunterFrostTrapBar, true)
    -- Restack after initial force-update
    RestackDebuffBars({serpentStingBar, wingClipBar, concussionShotBar, immolationTrapBar, explosiveTrapBar, freezingTrapBar, frostTrapBar}, GetDebuffAnchorBar())
    ns.UpdateHunterSerpentStingBar = UpdateHunterSerpentStingBar
    ns.UpdateHunterWingClipBar = UpdateHunterWingClipBar
    ns.UpdateHunterConcussionShotBar = UpdateHunterConcussionShotBar
    ns.UpdateHunterImmolationTrapBar = UpdateHunterImmolationTrapBar
    ns.UpdateHunterExplosiveTrapBar = UpdateHunterExplosiveTrapBar
    ns.UpdateHunterFreezingTrapBar = UpdateHunterFreezingTrapBar
    ns.UpdateHunterFrostTrapBar = UpdateHunterFrostTrapBar
    -- WoWUnit test harness
    if WoWUnit then
        if not ns._Test then ns._Test = {} end
        ns._Test.GetTargetSerpentStingData = GetTargetSerpentStingData
    end
end

local function SetupRogue()
    local DEFAULT_ROGUE_QUEUE_WINDOW = 0.08
    local ROGUE_QUEUE_INPUT_CUSHION = 0.03
    local MAX_ROGUE_QUEUE_WINDOW = 0.22
    local ROGUE_CUE_FALLBACK_ALPHA_MULTIPLIER = 0.82
    local ROGUE_SLICE_AND_DICE_BAR_GAP = 2
    local ROGUE_SLICE_AND_DICE_REFRESH_INTERVAL = 0.15
    local ROGUE_ENERGY_TICK_DURATION = 2.0
    local ROGUE_ENERGY_TICK_BAR_WIDTH = ns.ROGUE_ENERGY_TICK_BAR_WIDTH or 4
    local ROGUE_ENERGY_STACK_GAP = 3
    local SLICE_AND_DICE_SPELL_ID = ns.ROGUE_SLICE_AND_DICE_ID or 5171
    local SLICE_AND_DICE_NAME = ns.GetSpellInfo and ns.GetSpellInfo(SLICE_AND_DICE_SPELL_ID) or "Slice and Dice"

    local function GetRogueCueColor()
        return ns.GetBarColor and ns.GetBarColor("rogueSinister") or { r = 1, g = 0, b = 0, a = 0.35 }
    end

    local function GetRogueEnergyTickColor()
        return ns.GetBarColor and ns.GetBarColor("rogueEnergyTick") or { r = 1.0, g = 0.82, b = 0.18, a = 1 }
    end

    local function GetRogueSliceAndDiceColor()
        return ns.GetBarColor and ns.GetBarColor("rogueSliceAndDice") or { r = 0.95, g = 0.82, b = 0.22, a = 0.95 }
    end

    local function ApplyRogueCueColor(alphaScale)
        local cue = ns.rogueSinisterAssistZone
        if not cue then
            return
        end

        local color = GetRogueCueColor()
        local alpha = color.a ~= nil and color.a or 0.35
        alphaScale = tonumber(alphaScale) or 1
        alpha = math.max(0, math.min(alpha * alphaScale, 1))
        cue:SetColorTexture(color.r or 1, color.g or 0, color.b or 0, alpha)
    end

    local function ApplyRogueEnergyTickColor()
        local tickBar = ns.rogueEnergyTickBar
        if tickBar then
            local tickColor = GetRogueEnergyTickColor()
            tickBar:SetStatusBarColor(
                tickColor.r or 1, tickColor.g or 0.82, tickColor.b or 0.18, tickColor.a ~= nil and tickColor.a or 1
            )
        end

        local totalBar = ns.rogueEnergyTotalBar
        if totalBar then
            totalBar:SetAlpha(0)
            totalBar:SetValue(0)
        end
    end

    local function ApplyRogueComboPointColor()
        if ns.rogueComboPointContainer then
            ns.rogueComboPointContainer:Hide()
        end
        if ns.rogueComboPointBars then
            for _, bar in ipairs(ns.rogueComboPointBars) do
                if bar then
                    bar:SetAlpha(0)
                    bar:SetValue(0)
                end
            end
        end
    end

    local function ApplyRogueSliceAndDiceColor()
        local sndBar = ns.rogueSliceAndDiceBar
        if not sndBar then
            return
        end

        local color = GetRogueSliceAndDiceColor()
        sndBar:SetStatusBarColor(color.r or 0.95, color.g or 0.82, color.b or 0.22, color.a ~= nil and color.a or 0.95)
    end

    local BLADE_FLURRY_SPELL_ID = 13877
    local BLADE_FLURRY_NAME = ns.GetSpellInfo and (ns.GetSpellInfo(BLADE_FLURRY_SPELL_ID) or "Blade Flurry")
        or "Blade Flurry"
    local COLD_BLOOD_SPELL_ID = 14177
    local COLD_BLOOD_NAME = ns.GetSpellInfo and (ns.GetSpellInfo(COLD_BLOOD_SPELL_ID) or "Cold Blood") or "Cold Blood"

    local function GetBladeFlurryAuraData()
        for index = 1, 40 do
            local auraName, duration, expirationTime, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then
                break
            end

            if auraSpellId == BLADE_FLURRY_SPELL_ID or auraName == BLADE_FLURRY_NAME then
                return auraName, duration, expirationTime
            end
        end

        return nil
    end

    local function UpdateRogueBladeFlurryBadge()
        if not ns.mhBar then
            return
        end

        local badge = ns.mhBar.bladeFlurryText
        if not badge then
            badge = ns.mhBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            badge:SetPoint("TOPLEFT", ns.mhBar, "TOPRIGHT", 3, 2)
            badge:SetJustifyH("LEFT")
            badge:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            badge:SetTextColor(1.0, 0.78, 0.10, 0.95)
            ns.mhBar.bladeFlurryText = badge
        end

        local auraName, auraDuration, auraExpirationTime = GetBladeFlurryAuraData()
        if not auraName then
            badge:Hide()
            return
        end

        local now = GetCurrentTime()
        local remaining = 0
        if type(auraExpirationTime) == "number" and auraExpirationTime > 0 then
            remaining = math.max(auraExpirationTime - now, 0)
        elseif type(auraDuration) == "number" and auraDuration > 0 then
            remaining = auraDuration
        end

        badge:SetText(string.format("BF %.0fs", math.max(remaining, 0)))
        badge:Show()
    end

    local function GetColdBloodAuraActive()
        for index = 1, 40 do
            local auraName, _, _, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then
                break
            end

            if auraSpellId == COLD_BLOOD_SPELL_ID or auraName == COLD_BLOOD_NAME then
                return true
            end
        end

        return false
    end

    local function UpdateRogueColdBloodBadge()
        if not ns.mhBar then
            return
        end

        local badge = ns.mhBar.coldBloodText
        if not badge then
            badge = ns.mhBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            badge:SetPoint("TOPLEFT", ns.mhBar, "TOPRIGHT", 3, -8)
            badge:SetJustifyH("LEFT")
            badge:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            badge:SetTextColor(1.0, 0.88, 0.20, 0.95)
            ns.mhBar.coldBloodText = badge
        end

        if not GetColdBloodAuraActive() then
            badge:Hide()
            return
        end

        badge:SetText("CB")
        badge:Show()
    end

    local function EnsureRogueVerticalHelperBar(frameName, width)
        local bar = rawget(_G, frameName)
        if not bar then
            bar = CreateFrame("StatusBar", frameName, UIParent)
        end

        bar:SetStatusBarTexture(ns.GetBarTexture and ns.GetBarTexture() or "Interface\\TargetingFrame\\UI-StatusBar")
        if bar.SetOrientation then
            bar:SetOrientation("VERTICAL")
        end
        if bar.SetReverseFill then
            bar:SetReverseFill(false)
        end
        bar:SetSize(width, (ns.mhBar and ns.mhBar:GetHeight()) or ns.BAR_HEIGHT or 15)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar:SetFrameStrata((ns.mhBar and ns.mhBar:GetFrameStrata()) or "MEDIUM")
        bar:SetFrameLevel(((ns.mhBar and ns.mhBar:GetFrameLevel()) or 0) + 1)
        bar:EnableMouse(false)

        local statusBarTexture = bar:GetStatusBarTexture()
        if statusBarTexture then
            statusBarTexture:SetDrawLayer(ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK")
        end

        local backgroundTexture = bar.backgroundTexture or bar:CreateTexture(nil, "BACKGROUND")
        backgroundTexture:SetAllPoints(true)
        local backgroundColor = ns.GetBarBackgroundColor and ns.GetBarBackgroundColor()
            or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBackgroundColor)
        backgroundColor = backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
        backgroundTexture:SetColorTexture(backgroundColor.r or 0, backgroundColor.g or 0, backgroundColor.b or 0, 1)
        backgroundTexture:SetAlpha(backgroundColor.a ~= nil and backgroundColor.a or 0.5)

        if not bar.borderTextures then
            local borderColor = ns.GetBarBorderColor and ns.GetBarBorderColor()
                or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBorderColor)
            borderColor = borderColor or { r = 0, g = 0, b = 0, a = 1 }
            local borderTop = bar:CreateTexture(nil, "OVERLAY")
            borderTop:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
            borderTop:SetPoint("TOPLEFT", -1, 1)
            borderTop:SetPoint("TOPRIGHT", 1, 1)
            borderTop:SetHeight(1)

            local borderBottom = bar:CreateTexture(nil, "OVERLAY")
            borderBottom:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
            borderBottom:SetPoint("BOTTOMLEFT", -1, -1)
            borderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
            borderBottom:SetHeight(1)

            local borderLeft = bar:CreateTexture(nil, "OVERLAY")
            borderLeft:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
            borderLeft:SetPoint("TOPLEFT", -1, 1)
            borderLeft:SetPoint("BOTTOMLEFT", -1, -1)
            borderLeft:SetWidth(1)

            local borderRight = bar:CreateTexture(nil, "OVERLAY")
            borderRight:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
            borderRight:SetPoint("TOPRIGHT", 1, 1)
            borderRight:SetPoint("BOTTOMRIGHT", 1, -1)
            borderRight:SetWidth(1)

            bar.borderTextures = { top = borderTop, bottom = borderBottom, left = borderLeft, right = borderRight }
        end

        bar.backgroundTexture = backgroundTexture
        bar.statusBarTexture = statusBarTexture
        bar:SetAlpha(0)
        return bar
    end

    local function GetPreviewMeleeDuration()
        local mainHandSpeed = type(UnitAttackSpeed) == "function" and UnitAttackSpeed("player") or nil
        if type(mainHandSpeed) == "number" and mainHandSpeed > 0 then
            return mainHandSpeed
        end

        local timer = ns.timers and ns.timers.mh
        if timer and timer.duration and timer.duration > 0 then
            return timer.duration
        end

        return 2.0
    end

    local function GetRogueCueWindow(timerDuration)
        if not timerDuration or timerDuration <= 0 then
            return 0
        end
        local latency = math.max(ns.cachedLatency or 0, 0)
        local window = latency + ROGUE_QUEUE_INPUT_CUSHION
        local maxWindow = math.max(math.min(timerDuration * 0.35, MAX_ROGUE_QUEUE_WINDOW), DEFAULT_ROGUE_QUEUE_WINDOW)
        if window < DEFAULT_ROGUE_QUEUE_WINDOW then
            window = DEFAULT_ROGUE_QUEUE_WINDOW
        elseif window > maxWindow then
            window = maxWindow
        end

        return window
    end

    local function IsLikelyNaturalRogueEnergyGain(delta)
        delta = tonumber(delta)
        if not delta or delta <= 0 then
            return false
        end

        return (delta >= 18 and delta <= 22) or (delta >= 38 and delta <= 42)
    end

    local function GetRogueEnergyAnchorBar()
        return ns.mhBar
    end

    local function GetRogueEnergyBarHeight(mhBar)
        return (mhBar and mhBar:GetHeight()) or ns.BAR_HEIGHT or 15
    end

    local function GetRogueSliceAndDiceAura()
        if not UnitAura and not UnitBuff then
            return nil
        end

        for index = 1, 40 do
            local auraName, duration, expirationTime, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then
                break
            end

            if auraSpellId == SLICE_AND_DICE_SPELL_ID or auraName == SLICE_AND_DICE_NAME then
                return duration, expirationTime, auraSpellId, auraName
            end
        end

        return nil
    end

    local function SyncRogueSliceAndDiceAura()
        local duration, expirationTime = GetRogueSliceAndDiceAura()
        if type(duration) == "number" and duration > 0 and type(expirationTime) == "number" and expirationTime > 0 then
            ns.rogueSliceAndDiceDuration = duration
            ns.rogueSliceAndDiceExpirationTime = expirationTime
            return true
        end

        ns.rogueSliceAndDiceDuration = nil
        ns.rogueSliceAndDiceExpirationTime = nil
        return false
    end

    local function GetRogueSliceAndDiceAnchorFrame(mhBar)
        return mhBar
    end

    local function UpdateRogueComboPointVisual()
        ApplyRogueComboPointColor()
    end

    local function UpdateRogueEnergyTickVisual()
        local tickBar = ns.rogueEnergyTickBar
        local mhBar = ns.mhBar
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if not tickBar or not mhBar then
            return
        end

        if ns.rogueEnergyTotalBar then
            ns.rogueEnergyTotalBar:SetAlpha(0)
            ns.rogueEnergyTotalBar:SetValue(0)
        end

        if ns.playerClass ~= "ROGUE" or db.showRogueEnergyTick == false or (ns.IsMinimalMode and ns.IsMinimalMode()) then
            tickBar:SetAlpha(0)
            tickBar:SetValue(0)
            return
        end

        local previewActive = ns.barTestActive == true
        local mhVisible = mhBar.GetAlpha and (mhBar:GetAlpha() or 0) > 0
        if not previewActive and not mhVisible then
            tickBar:SetAlpha(0)
            tickBar:SetValue(0)
            return
        end

        local anchorBar = GetRogueEnergyAnchorBar() or mhBar
        local energyHeight = GetRogueEnergyBarHeight(anchorBar)
        tickBar:ClearAllPoints()
        tickBar:SetPoint("TOPRIGHT", mhBar, "TOPLEFT", -ROGUE_ENERGY_STACK_GAP, 0)
        tickBar:SetWidth(ROGUE_ENERGY_TICK_BAR_WIDTH)
        tickBar:SetHeight(energyHeight)
        tickBar:SetMinMaxValues(0, 1)

        local now = GetCurrentTime()
        if not ns.rogueEnergyTickStartTime then
            ns.rogueEnergyTickStartTime = now
        end

        local elapsed = now - ns.rogueEnergyTickStartTime
        if elapsed < 0 then
            elapsed = 0
        end
        local tickProgress = (elapsed % ROGUE_ENERGY_TICK_DURATION) / ROGUE_ENERGY_TICK_DURATION
        tickBar:SetValue(tickProgress)

        local currentEnergy = (UnitPower and UnitPower("player")) or 0
        if currentEnergy >= 100 then
            tickBar:SetStatusBarColor(1.0, 0.2, 0.2, 1)
        elseif currentEnergy >= 90 then
            tickBar:SetStatusBarColor(1.0, 0.6, 0.2, 1)
        else
            ApplyRogueEnergyTickColor()
        end
        tickBar:SetAlpha(1)

        -- Rogue energy countdown text: show seconds until next tick
        local db2 = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db2.showRogueEnergyCountdown ~= false then
            if not tickBar.countdownText then
                tickBar.countdownText = tickBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                tickBar.countdownText:SetPoint("LEFT", tickBar, "RIGHT", 2, 0)
                tickBar.countdownText:SetJustifyH("LEFT")
                tickBar.countdownText:SetTextColor(1, 1, 1, 0.7)
                tickBar.countdownText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            end
            local elapsedInTick = elapsed % ROGUE_ENERGY_TICK_DURATION
            local remainingTick = ROGUE_ENERGY_TICK_DURATION - elapsedInTick
            tickBar.countdownText:SetText(string.format("%.1f", math.max(remainingTick, 0)))
            tickBar.countdownText:Show()
        elseif tickBar.countdownText then
            tickBar.countdownText:Hide()
        end
    end

    local function UpdateRogueSliceAndDiceVisual()
        local sndBar = ns.rogueSliceAndDiceBar
        local mhBar = ns.mhBar
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if not sndBar or not mhBar then
            return
        end

        if ns.playerClass ~= "ROGUE" or db.showRogueSliceAndDice == false or (ns.IsMinimalMode and ns.IsMinimalMode()) then
            sndBar:SetAlpha(0)
            sndBar:SetValue(0)
            return
        end

        local previewActive = ns.barTestActive == true
        local mhVisible = mhBar.GetAlpha and (mhBar:GetAlpha() or 0) > 0
        if not previewActive and not mhVisible then
            sndBar:SetAlpha(0)
            sndBar:SetValue(0)
            return
        end

        local isActive = false
        local progress = 0
        local now = GetCurrentTime()
        if previewActive then
            isActive = true
            progress = 0.66
        else
            if not ns.rogueSliceAndDiceNextRefreshAt or now >= ns.rogueSliceAndDiceNextRefreshAt
                or not ns.rogueSliceAndDiceExpirationTime then
                SyncRogueSliceAndDiceAura()
                ns.rogueSliceAndDiceNextRefreshAt = now + ROGUE_SLICE_AND_DICE_REFRESH_INTERVAL
            end

            local duration = ns.rogueSliceAndDiceDuration
            local expirationTime = ns.rogueSliceAndDiceExpirationTime
            if type(duration) == "number" and duration > 0 and type(expirationTime) == "number" and expirationTime > 0 then
                local remaining = expirationTime - now
                if remaining > 0 then
                    isActive = true
                    progress = remaining / duration
                else
                    ns.rogueSliceAndDiceDuration = nil
                    ns.rogueSliceAndDiceExpirationTime = nil
                    ns.rogueSliceAndDiceNextRefreshAt = nil
                end
            end
        end

        if not isActive then
            sndBar:SetAlpha(0)
            sndBar:SetValue(0)
            return
        end

        local anchorFrame = GetRogueSliceAndDiceAnchorFrame(mhBar)
        sndBar:ClearAllPoints()
        sndBar:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, ROGUE_SLICE_AND_DICE_BAR_GAP)
        sndBar:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", 0, ROGUE_SLICE_AND_DICE_BAR_GAP)
        sndBar:SetHeight(ns.ROGUE_SLICE_AND_DICE_BAR_HEIGHT or 4)
        sndBar:SetMinMaxValues(0, 1)
        sndBar:SetValue(math.max(0, math.min(progress, 1)))
        ApplyRogueSliceAndDiceColor()
        sndBar:SetAlpha(1)
    end

    local function HandleRogueComboPointsChanged(unit)
        UpdateRogueComboPointVisual()
        UpdateRogueSliceAndDiceVisual()
    end

    local function HandleRogueEnergyPowerUpdate(unit, powerType)
        if ns.playerClass ~= "ROGUE" or unit ~= "player" or type(UnitPower) ~= "function" then
            return
        end
        if powerType and powerType ~= "ENERGY" then
            return
        end

        local currentEnergy = UnitPower("player") or 0
        local previousEnergy = ns.rogueLastEnergy
        if previousEnergy ~= nil then
            local delta = currentEnergy - previousEnergy
            if IsLikelyNaturalRogueEnergyGain(delta) then
                ns.rogueEnergyTickStartTime = GetCurrentTime()
            end
        end

        ns.rogueLastEnergy = currentEnergy
        UpdateRogueEnergyTickVisual()
    end

    local function HandleRogueSliceAndDiceAura(unit)
        if ns.playerClass ~= "ROGUE" or unit ~= "player" then
            return
        end

        SyncRogueSliceAndDiceAura()
        ns.rogueSliceAndDiceNextRefreshAt = nil
        UpdateRogueSliceAndDiceVisual()
    end

    local function UpdateRogueSinisterAssistVisual()
        local cue = ns.rogueSinisterAssistZone
        local mhBar = ns.mhBar
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if not cue or not mhBar then
            return
        end

        if ns.playerClass ~= "ROGUE" or db.showRogueSinisterAssist == false or (ns.IsMinimalMode and ns.IsMinimalMode()) then
            cue:Hide()
            return
        end

        local timer = ns.timers and ns.timers.mh or nil
        local duration = timer and timer.duration or nil
        local activeSwing = timer and timer.state == "swinging" and duration and duration > 0
        local previewActive = ns.barTestActive == true
        if not activeSwing then
            duration = GetPreviewMeleeDuration()
        end

        if (mhBar.GetAlpha and (mhBar:GetAlpha() or 0) <= 0) or not duration or duration <= 0 then
            cue:Hide()
            return
        end

        local barWidth = mhBar:GetWidth() or mhBar.barWidth or ns.BAR_WIDTH or 0
        if barWidth <= 0 then
            cue:Hide()
            return
        end

        local cueWindow = GetRogueCueWindow(duration)
        if cueWindow <= 0 then
            cue:Hide()
            return
        end

        local cueWidth = math.min((cueWindow / duration) * barWidth, barWidth)
        cueWidth = math.max(cueWidth, 1)
        local barAnchor = GetOverlayParent(mhBar)
        cue:ClearAllPoints()
        cue:SetPoint("TOPRIGHT", barAnchor, "TOPRIGHT", 0, 0)
        cue:SetPoint("BOTTOMRIGHT", barAnchor, "BOTTOMRIGHT", 0, 0)
        cue:SetWidth(cueWidth)
        local alphaScale = 1
        if not activeSwing and not previewActive then
            alphaScale = ROGUE_CUE_FALLBACK_ALPHA_MULTIPLIER
        end
        ApplyRogueCueColor(alphaScale)
        cue:Show()
    end

    ns.UpdateRogueSinisterAssistColor = ApplyRogueCueColor
    ns.UpdateRogueSinisterAssistVisual = UpdateRogueSinisterAssistVisual
    ns.UpdateRogueEnergyTickColor = ApplyRogueEnergyTickColor
    ns.UpdateRogueEnergyTickVisual = UpdateRogueEnergyTickVisual
    ns.UpdateRogueComboPointColor = ApplyRogueComboPointColor
    ns.UpdateRogueComboPointVisual = UpdateRogueComboPointVisual
    ns.UpdateRogueSliceAndDiceColor = ApplyRogueSliceAndDiceColor
    ns.UpdateRogueSliceAndDiceVisual = UpdateRogueSliceAndDiceVisual
    ns.HandleRogueComboPointsChanged = HandleRogueComboPointsChanged
    ns.HandleRogueEnergyPowerUpdate = HandleRogueEnergyPowerUpdate
    ns.HandleRogueSliceAndDiceAura = HandleRogueSliceAndDiceAura

    -- ============================================================
    -- Rupture target debuff duration bar (Rogue)
    -- ============================================================
    local RUPTURE_BAR_HEIGHT = 6
    local RUPTURE_FALLBACK_DURATION = 16
    local RUPTURE_GLOW_WINDOW = 4
    local ruptureBar = nil
    local nextRuptureUpdateAt = 0

    local function SetRuptureGlow(bar, remaining)
        if not bar then return end
        if bar.glowBorder then
            local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= RUPTURE_GLOW_WINDOW
            for _, edge in ipairs(bar.glowBorder) do
                if shouldGlow then edge:Show() else edge:Hide() end
            end
        end
    end

    local function EnsureRuptureBar()
        if ruptureBar then return ruptureBar end
        if not ns.mhBar then return nil end

        ruptureBar = CreateFrame("StatusBar", nil, ns.mhBar)
        ruptureBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        ruptureBar:SetStatusBarColor(0.60, 0.20, 0.80, 0.90)  -- purple
        ruptureBar:SetMinMaxValues(0, 1)
        ruptureBar:SetValue(0)
        ruptureBar:SetHeight(RUPTURE_BAR_HEIGHT)
        ruptureBar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, 2)
        ruptureBar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, 2)
        ruptureBar:EnableMouse(false)

        local bg = ruptureBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        ruptureBar.backgroundTexture = bg

        local glowBorder = {}
        for _, edgeDef in ipairs({
            { "TOPLEFT", "TOPRIGHT", "Height", 1, -1, 1, 1, 1 },
            { "BOTTOMLEFT", "BOTTOMRIGHT", "Height", 1, -1, -1, 1, -1 },
            { "TOPLEFT", "BOTTOMLEFT", "Width", 1, -1, 1, -1, -1 },
            { "TOPRIGHT", "BOTTOMRIGHT", "Width", 1, 1, 1, 1, -1 }
        }) do
            local tex = ruptureBar:CreateTexture(nil, "OVERLAY")
            tex:SetPoint(edgeDef[1], ruptureBar, edgeDef[2], edgeDef[4], edgeDef[5])
            tex:SetPoint(edgeDef[3], edgeDef[6], edgeDef[7], edgeDef[8])
            tex:SetColorTexture(0.60, 0.20, 0.80, 0.85)
            tex:Hide()
            glowBorder[#glowBorder + 1] = tex
        end
        ruptureBar.glowBorder = glowBorder

        local label = ruptureBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", ruptureBar, "CENTER", 0, 0)
        label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        label:SetTextColor(1.0, 0.85, 0.25, 0.95)
        label:SetText("Rp")
        ruptureBar.label = label

        -- Spell icon (left side)
        local spellIcon = ruptureBar:CreateTexture(nil, "OVERLAY")
        spellIcon:SetSize(RUPTURE_BAR_HEIGHT, RUPTURE_BAR_HEIGHT)
        spellIcon:SetPoint("LEFT", ruptureBar, "LEFT", 2, 0)
        local texPath = GetSpellTexture and GetSpellTexture(26867)
        if texPath then spellIcon:SetTexture(texPath) end
        ruptureBar.icon = spellIcon

        ruptureBar:Hide()
        ns.rogueRuptureBar = ruptureBar
        return ruptureBar
    end

    local function GetTargetRuptureData()
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId =
                GetHarmfulAuraData("target", index, "HARMFUL")
            if not auraName then break end

            local isRupture = false
            if type(auraSpellId) == "number" and ns.ROGUE_RUPTURE_IDS and ns.ROGUE_RUPTURE_IDS[auraSpellId] then
                isRupture = true
            elseif auraName == ns.ROGUE_RUPTURE_NAME then
                isRupture = true
            end

            if isRupture and (caster == "player" or caster == nil) then
                return duration, expirationTime
            end
        end
        return nil
    end

    local function UpdateRogueRuptureBar(force)
        local now = GetCurrentTime()
        if not force and now < nextRuptureUpdateAt then return end
        nextRuptureUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showRogueRuptureBar == false then
            if ruptureBar then ruptureBar:Hide() end
            return
        end

        local bar = EnsureRuptureBar()
        if not bar or not ns.mhBar then return end

        if type(UnitExists) ~= "function" or not UnitExists("target")
            or (type(UnitCanAttack) ~= "function" or not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        if ns.mhBar and ns.mhBar.GetAlpha and (ns.mhBar:GetAlpha() or 0) <= 0 then
            bar:Hide()
            return
        end

        local duration, expirationTime = GetTargetRuptureData()
        if not duration and not expirationTime then
            SetRuptureGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then
            duration = RUPTURE_FALLBACK_DURATION
        end

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetRuptureGlow(bar, remaining)

        if bar.label and bar.label.SetText then
            bar.label:SetText(string.format("%.0f", math.max(remaining, 0)))
        end

        bar:Show()
    end

    -- ============================================================
    -- Expose Armor target debuff bar (Rogue armor reduction)
    -- ============================================================
    local EXPOSE_ARMOR_BAR_HEIGHT = 6
    local EXPOSE_ARMOR_GLOW_WINDOW = 4
    local exposeArmorBar = nil
    local nextExposeArmorUpdateAt = 0

    local function SetExposeArmorGlow(bar, remaining)
        if not bar then return end
        if bar.glowBorder then
            local shouldGlow = type(remaining) == "number" and remaining > 0 and remaining <= EXPOSE_ARMOR_GLOW_WINDOW
            for _, edge in ipairs(bar.glowBorder) do
                if shouldGlow then edge:Show() else edge:Hide() end
            end
        end
    end

    local function EnsureExposeArmorBar()
        if exposeArmorBar then return exposeArmorBar end
        if not ns.mhBar then return nil end

        exposeArmorBar = CreateFrame("StatusBar", nil, ns.mhBar)
        exposeArmorBar:SetStatusBarTexture(
            (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
        )
        exposeArmorBar:SetStatusBarColor(0.50, 0.40, 0.20, 0.90)  -- bronze
        exposeArmorBar:SetMinMaxValues(0, 1)
        exposeArmorBar:SetValue(0)
        exposeArmorBar:SetHeight(EXPOSE_ARMOR_BAR_HEIGHT)
        exposeArmorBar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, 2)
        exposeArmorBar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, 2)
        exposeArmorBar:EnableMouse(false)

        local bg = exposeArmorBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.45)
        exposeArmorBar.backgroundTexture = bg

        local glowBorder = {}
        for _, edgeDef in ipairs({
            { "TOPLEFT", "TOPRIGHT", "Height", 1, -1, 1, 1, 1 },
            { "BOTTOMLEFT", "BOTTOMRIGHT", "Height", 1, -1, -1, 1, -1 },
            { "TOPLEFT", "BOTTOMLEFT", "Width", 1, -1, 1, -1, -1 },
            { "TOPRIGHT", "BOTTOMRIGHT", "Width", 1, 1, 1, 1, -1 }
        }) do
            local tex = exposeArmorBar:CreateTexture(nil, "OVERLAY")
            tex:SetPoint(edgeDef[1], exposeArmorBar, edgeDef[2], edgeDef[4], edgeDef[5])
            tex:SetPoint(edgeDef[3], edgeDef[6], edgeDef[7], edgeDef[8])
            tex:SetColorTexture(0.50, 0.40, 0.20, 0.85)
            tex:Hide()
            glowBorder[#glowBorder + 1] = tex
        end
        exposeArmorBar.glowBorder = glowBorder

        -- Center label shows "EA" when active
        local label = exposeArmorBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetPoint("CENTER", exposeArmorBar, "CENTER", 0, 1)
        label:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        label:SetTextColor(1.0, 0.85, 0.25, 0.95)
        label:SetText("")
        exposeArmorBar.label = label

        -- Spell icon (left side)
        local spellIcon = exposeArmorBar:CreateTexture(nil, "OVERLAY")
        spellIcon:SetSize(EXPOSE_ARMOR_BAR_HEIGHT, EXPOSE_ARMOR_BAR_HEIGHT)
        spellIcon:SetPoint("LEFT", exposeArmorBar, "LEFT", 2, 0)
        local texPath = GetSpellTexture and GetSpellTexture(8647)
        if texPath then spellIcon:SetTexture(texPath) end
        exposeArmorBar.icon = spellIcon

        exposeArmorBar:Hide()
        return exposeArmorBar
    end

    local function GetTargetExposeArmorData()
        local eaName = ns.ROGUE_EXPOSE_ARMOR_NAME or (ns.GetSpellInfo and ns.GetSpellInfo(8647) or "Expose Armor")
        if not eaName then return nil end
        for index = 1, 40 do
            local auraName, _, duration, expirationTime, caster, auraSpellId =
                GetHarmfulAuraData("target", index, "HARMFUL")
            if not auraName then break end
            local isEA = false
            if type(auraSpellId) == "number" and ns.ROGUE_EXPOSE_ARMOR_IDS and ns.ROGUE_EXPOSE_ARMOR_IDS[auraSpellId] then
                isEA = true
            elseif auraName == eaName then
                isEA = true
            end
            if isEA and (caster == "player" or caster == nil) then
                return duration, expirationTime
            end
        end
        return nil
    end

    local function UpdateRogueExposeArmorBar(force)
        local now = GetCurrentTime()
        if not force and now < nextExposeArmorUpdateAt then return end
        nextExposeArmorUpdateAt = now + 0.05

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showRogueExposeArmorBar == false then
            if exposeArmorBar then exposeArmorBar:Hide() end
            return
        end

        local bar = EnsureExposeArmorBar()
        if not bar or not ns.mhBar then return end

        if type(UnitExists) ~= "function" or not UnitExists("target")
            or (type(UnitCanAttack) ~= "function" or not UnitCanAttack("player", "target")) then
            bar:Hide()
            return
        end

        if ns.mhBar and ns.mhBar.GetAlpha and (ns.mhBar:GetAlpha() or 0) <= 0 then
            bar:Hide()
            return
        end

        local duration, expirationTime = GetTargetExposeArmorData()
        if not duration and not expirationTime then
            SetExposeArmorGlow(bar, 0)
            bar:Hide()
            return
        end

        duration = tonumber(duration)
        if not duration or duration <= 0 then duration = 30 end  -- EA has 30s base, ~6s per CP

        local remaining = duration
        if type(expirationTime) == "number" and expirationTime > 0 then
            remaining = math.max(expirationTime - now, 0)
        end

        bar:SetMinMaxValues(0, duration)
        bar:SetValue(remaining)
        SetExposeArmorGlow(bar, remaining)

        if bar.label and bar.label.SetText then
            bar.label:SetText("EA")
        end

        bar:Show()
    end

    -- Export
    ns.UpdateRogueRuptureBar = UpdateRogueRuptureBar
    ns.UpdateRogueExposeArmorBar = UpdateRogueExposeArmorBar

    ns.OnBarsCreated = function ()
        if not ns.mhBar then
            return
        end

        if not ns.rogueSinisterAssistZone then
            local barParent = GetOverlayParent(ns.mhBar)
            local cue = barParent:CreateTexture(nil, "ARTWORK")
            cue:SetColorTexture(1, 0, 0, 0.35)
            cue:SetPoint("TOPRIGHT", barParent, "TOPRIGHT", 0, 0)
            cue:SetPoint("BOTTOMRIGHT", barParent, "BOTTOMRIGHT", 0, 0)
            cue:SetWidth(0)
            cue:Hide()
            ns.rogueSinisterAssistZone = cue
            if ns.ApplyRogueCueLayer then
                ns.ApplyRogueCueLayer()
            elseif cue.SetDrawLayer then
                cue:SetDrawLayer("OVERLAY", 0)
            end
        end

        if not ns.rogueEnergyTickBar then
            ns.rogueEnergyTickBar = EnsureRogueVerticalHelperBar(
                "SuperSwingTimerRogueEnergyTickBar", ROGUE_ENERGY_TICK_BAR_WIDTH
            )
        end

        if ns.rogueEnergyTotalBar then
            ns.rogueEnergyTotalBar:SetAlpha(0)
            ns.rogueEnergyTotalBar:SetValue(0)
        end
        if ns.rogueComboPointContainer then
            ns.rogueComboPointContainer:Hide()
        end
        if ns.rogueComboPointBars then
            for _, bar in ipairs(ns.rogueComboPointBars) do
                if bar then
                    bar:SetAlpha(0)
                    bar:SetValue(0)
                end
            end
        end

        if not ns.rogueSliceAndDiceBar then
            local sndBar = rawget(_G, "SuperSwingTimerRogueSliceAndDiceBar")
            if not sndBar then
                sndBar = CreateFrame("StatusBar", "SuperSwingTimerRogueSliceAndDiceBar", UIParent)
            end
            sndBar:SetStatusBarTexture(
                ns.GetBarTexture and ns.GetBarTexture() or "Interface\\TargetingFrame\\UI-StatusBar"
            )
            sndBar:SetSize(
                (ns.mhBar and ns.mhBar:GetWidth()) or ns.BAR_WIDTH or 240, ns.ROGUE_SLICE_AND_DICE_BAR_HEIGHT or 4
            )
            sndBar:SetMinMaxValues(0, 1)
            sndBar:SetValue(0)
            sndBar:SetFrameStrata((ns.mhBar and ns.mhBar:GetFrameStrata()) or "MEDIUM")
            sndBar:SetFrameLevel(((ns.mhBar and ns.mhBar:GetFrameLevel()) or 0) + 1)
            sndBar:EnableMouse(false)
            local statusBarTexture = sndBar:GetStatusBarTexture()
            if statusBarTexture then
                statusBarTexture:SetDrawLayer(ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK")
            end

            local backgroundTexture = sndBar.backgroundTexture or sndBar:CreateTexture(nil, "BACKGROUND")
            backgroundTexture:SetAllPoints(true)
            local backgroundColor = ns.GetBarBackgroundColor and ns.GetBarBackgroundColor()
                or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBackgroundColor)
            backgroundColor = backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
            backgroundTexture:SetColorTexture(backgroundColor.r or 0, backgroundColor.g or 0, backgroundColor.b or 0, 1)
            backgroundTexture:SetAlpha(backgroundColor.a ~= nil and backgroundColor.a or 0.5)

            if not sndBar.borderTextures then
                local borderColor = ns.GetBarBorderColor and ns.GetBarBorderColor()
                    or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBorderColor)
                borderColor = borderColor or { r = 0, g = 0, b = 0, a = 1 }
                local borderTop = sndBar:CreateTexture(nil, "OVERLAY")
                borderTop:SetColorTexture(
                    borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1
                )
                borderTop:SetPoint("TOPLEFT", -1, 1)
                borderTop:SetPoint("TOPRIGHT", 1, 1)
                borderTop:SetHeight(1)

                local borderBottom = sndBar:CreateTexture(nil, "OVERLAY")
                borderBottom:SetColorTexture(
                    borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1
                )
                borderBottom:SetPoint("BOTTOMLEFT", -1, -1)
                borderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
                borderBottom:SetHeight(1)

                local borderLeft = sndBar:CreateTexture(nil, "OVERLAY")
                borderLeft:SetColorTexture(
                    borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1
                )
                borderLeft:SetPoint("TOPLEFT", -1, 1)
                borderLeft:SetPoint("BOTTOMLEFT", -1, -1)
                borderLeft:SetWidth(1)

                local borderRight = sndBar:CreateTexture(nil, "OVERLAY")
                borderRight:SetColorTexture(
                    borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1
                )
                borderRight:SetPoint("TOPRIGHT", 1, 1)
                borderRight:SetPoint("BOTTOMRIGHT", 1, -1)
                borderRight:SetWidth(1)

                sndBar.borderTextures = {
                    top = borderTop,
                    bottom = borderBottom,
                    left = borderLeft,
                    right = borderRight
                }
            end

            sndBar.backgroundTexture = backgroundTexture
            sndBar.statusBarTexture = statusBarTexture
            sndBar:SetAlpha(0)
            ns.rogueSliceAndDiceBar = sndBar
        end

        ApplyRogueCueColor()
        if ns.ApplyRogueCueLayer then
            ns.ApplyRogueCueLayer()
        end
        ApplyRogueEnergyTickColor()
        ApplyRogueSliceAndDiceColor()
        ns.rogueLastEnergy = UnitPower and UnitPower("player") or ns.rogueLastEnergy
        if not ns.rogueEnergyTickStartTime then
            ns.rogueEnergyTickStartTime = GetCurrentTime()
        end
        ns.rogueSliceAndDiceNextRefreshAt = nil
        SyncRogueSliceAndDiceAura()

        -- Register Rogue OnUpdate hook (sinister assist + energy + SnD + rupture + expose)
        ns.RegisterOnUpdateHook(function (elapsed)
            UpdateRogueSinisterAssistVisual()
            UpdateRogueEnergyTickVisual()
            UpdateRogueSliceAndDiceVisual()
            UpdateRogueBladeFlurryBadge()
            UpdateRogueColdBloodBadge()
            UpdateRogueRuptureBar(false)
            UpdateRogueExposeArmorBar(false)
            -- Restack all visible debuff bars above MH dynamically
            RestackDebuffBars({ruptureBar, exposeArmorBar}, ns.mhBar)
            if ns.UpdateRogueBuffIcons then ns.UpdateRogueBuffIcons(elapsed) end
        end)

        pcall(UpdateRogueRuptureBar, true)
        pcall(UpdateRogueExposeArmorBar, true)
        -- Restack after initial force-update
        RestackDebuffBars({ruptureBar, exposeArmorBar}, ns.mhBar)
    end

    -- Phase 2: Rogue Adrenaline Rush CD + duration bar
    local ADRENALINE_RUSH_SPELL_ID = ns.ROGUE_ADRENALINE_RUSH_ID or 13750
    local ADRENALINE_RUSH_NAME = ns.ROGUE_ADRENALINE_RUSH_NAME or (ns.GetSpellInfo
        and ns.GetSpellInfo(ADRENALINE_RUSH_SPELL_ID))
        or "Adrenaline Rush"
    local adrenalineRushBar = nil
    local adrenalineRushTimer = 0
    local ADRENALINE_RUSH_REFRESH_INTERVAL = 0.1

    local function GetAdrenalineRushAuraData()
        for index = 1, 40 do
            local auraName, duration, expirationTime, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then
                break
            end

            if auraSpellId == ADRENALINE_RUSH_SPELL_ID or auraName == ADRENALINE_RUSH_NAME then
                return auraName, duration, expirationTime, auraSpellId
            end
        end

        return nil
    end

    ns.ForceRogueAdrenalineRushRefresh = function ()
        adrenalineRushTimer = ADRENALINE_RUSH_REFRESH_INTERVAL
        if ns.UpdateRogueAdrenalineRush then
            ns.UpdateRogueAdrenalineRush(ADRENALINE_RUSH_REFRESH_INTERVAL)
        end
    end

    ns.UpdateRogueAdrenalineRush = function (elapsed)
        if not ns.mhBar then return end
        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if not db or db.showRogueAdrenalineRushBar == false then
            if adrenalineRushBar then adrenalineRushBar:Hide() end
            return
        end
        if not adrenalineRushBar then
            adrenalineRushBar = CreateFrame("StatusBar", nil, UIParent)
            adrenalineRushBar:SetSize(60, ns.ROGUE_ADRENALINE_RUSH_BAR_HEIGHT or 4)
            adrenalineRushBar:SetPoint("TOP", ns.rogueSliceAndDiceBar or ns.mhBar, "BOTTOM", 0, -2)
            adrenalineRushBar:SetStatusBarTexture(
                ns.GetBarTexture and ns.GetBarTexture() or "Interface\\TargetingFrame\\UI-StatusBar"
            )
            local arColor = ns.GetBarColor and ns.GetBarColor("adrenalineRushBar")
                or { r = 1.0, g = 0.30, b = 0.30, a = 0.85 }
            adrenalineRushBar:SetStatusBarColor(arColor.r, arColor.g, arColor.b, arColor.a)
            adrenalineRushBar:SetMinMaxValues(0, 1)
            adrenalineRushBar:SetValue(0)
            adrenalineRushBar:EnableMouse(false)
            local bg = adrenalineRushBar:CreateTexture(nil, "BACKGROUND")
            bg:SetColorTexture(0, 0, 0, 0.5)
            bg:SetAllPoints(true)
            local label = adrenalineRushBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("LEFT", adrenalineRushBar, "RIGHT", 2, 0)
            label:SetJustifyH("LEFT")
            label:SetTextColor(1.0, 0.30, 0.30, 0.85)
            label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
            adrenalineRushBar.label = label
        end

        adrenalineRushTimer = adrenalineRushTimer + (elapsed or 0)
        if adrenalineRushTimer < ADRENALINE_RUSH_REFRESH_INTERVAL then return end
        adrenalineRushTimer = 0

        local now = GetCurrentTime()
        local auraName, auraDuration, auraExpirationTime = GetAdrenalineRushAuraData()
        if auraName then
            local remaining = 0
            if type(auraExpirationTime) == "number" and auraExpirationTime > 0 then
                remaining = math.max(auraExpirationTime - now, 0)
            elseif type(auraDuration) == "number" and auraDuration > 0 then
                remaining = auraDuration
            end

            local duration = (type(auraDuration) == "number" and auraDuration > 0) and auraDuration or 15
            adrenalineRushBar:SetMinMaxValues(0, duration)
            adrenalineRushBar:SetValue(math.max(remaining, 0))
            adrenalineRushBar:Show()
            if adrenalineRushBar.label then
                adrenalineRushBar.label:SetText(string.format("%.0fs", math.max(remaining, 0)))
            end
            return
        end

        if not GetSpellCooldown then return end
        local start, duration = GetSpellCooldown(ADRENALINE_RUSH_SPELL_ID)
        if not duration or duration <= 0 then
            adrenalineRushBar:Hide()
            return
        end
        local remaining = math.max((start + duration) - now, 0)
        adrenalineRushBar:SetMinMaxValues(0, duration)
        adrenalineRushBar:SetValue(remaining)
        adrenalineRushBar:Show()
        if adrenalineRushBar.label then
            adrenalineRushBar.label:SetText(string.format("%.0fs", remaining))
        end
    end

    -- ============================================================
    -- Phase 3: Rogue CD/Buff Duration Icon Group
    -- ============================================================
    local ROGUE_RACIAL_SPELLS = {
        { spellId = 20572, name = "Blood Fury", label = "BF", kind = "buff" },
        { spellId = 26297, name = "Berserking", label = "BZ", kind = "buff" },
        { spellId = 20594, name = "Stoneform", label = "SF", kind = "buff" },
        { spellId = 58984, name = "Shadowmeld", label = "SM", kind = "buff" },
        { spellId = 20589, name = "Escape Artist", label = "EA", kind = "buff" },
        { spellId = 7744, name = "Will of the Forsaken", label = "WotF", kind = "buff" },
        { spellId = 20600, name = "Perception", label = "Per", kind = "buff" },
        { spellId = 28730, name = "Arcane Torrent", label = "AT", kind = "buff" },
    }
    local ROGUE_TRACKED_SPELLS = {
        { spellId = 13750, name = "Adrenaline Rush", label = "AR", kind = "buff" },
        { spellId = 13877, name = "Blade Flurry", label = "BF", kind = "buff" },
        { spellId = 14177, name = "Cold Blood", label = "CB", kind = "buff" },
        { spellId = 5277, name = "Evasion", label = "Eva", kind = "buff" },
        { spellId = 2983, name = "Sprint", label = "Spr", kind = "buff" },
        { spellId = 1856, name = "Vanish", label = "Van", kind = "buff" },
        { spellId = 14179, name = "Premeditation", label = "Pre", kind = "buff" },
        { spellId = 36554, name = "Shadowstep", label = "ShS", kind = "buff" },
        { spellId = 31209, name = "Cloak of Shadows", label = "CoS", kind = "buff" },
        -- External buffs (party/raid-wide, consumables, not learned spells):
        { spellId = 2825, name = "Bloodlust", label = "BL", kind = "buff", external = true },
        { spellId = 32182, name = "Heroism", label = "Hero", kind = "buff", external = true },
        { spellId = 35476, name = "Drums of Battle", label = "DoB", kind = "buff", external = true },
        { spellId = 35477, name = "Drums of Speed", label = "DoS", kind = "buff", external = true },
        { spellId = 28507, name = "Haste Potion", label = "HP", kind = "buff", external = true },
    }
    for _, racial in ipairs(ROGUE_RACIAL_SPELLS) do
        table.insert(ROGUE_TRACKED_SPELLS, racial)
    end

    local rogueBuffIcons = {}
    local rogueBuffTimer = 0
    local ROGUE_BUFF_UPDATE_INTERVAL = 0.15
    local ROGUE_BUFF_ICON_GAP = 3

    local function GetRogueSpellRemaining(info)
        -- Step 1: Scan helpful auras on the player (buffs)
        for index = 1, 40 do
            local auraName, duration, expirationTime, auraSpellId = GetHelpfulAuraData("player", index)
            if not auraName then break end
            if auraSpellId == info.spellId or auraName == info.name then
                if type(expirationTime) == "number" and expirationTime > 0 then
                    return math.max(expirationTime - GetCurrentTime(), 0), math.max(duration or 1, 1)
                end
                return nil, nil
            end
        end
        -- Step 2: For CD-type, scan target harmful auras (debuffs like Rupture)
        if info.kind == "cd" then
            if type(UnitExists) == "function" and UnitExists("target")
                and type(UnitCanAttack) == "function" and UnitCanAttack("player", "target") then
                for index = 1, 40 do
                    local debuffName, _, debuffDuration, debuffExpiration, caster, debuffSpellId = GetHarmfulAuraData("target", index)
                    if not debuffName then break end
                    if caster == "player" and (debuffSpellId == info.spellId or debuffName == info.name) then
                        if type(debuffExpiration) == "number" and debuffExpiration > 0 then
                            return math.max(debuffExpiration - GetCurrentTime(), 0), math.max(debuffDuration or 1, 1)
                        end
                        return nil, nil
                    end
                end
            end
            -- Step 3: Fall back to cooldown tracking
            local startTime, cdDuration
            if type(GetSpellCooldown) == "function" then
                startTime, cdDuration = GetSpellCooldown(info.spellId)
            elseif C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
                local ok, cdInfo = pcall(C_Spell.GetSpellCooldown, info.spellId)
                if ok and cdInfo then
                    startTime = cdInfo.startTime
                    cdDuration = cdInfo.duration
                end
            end
            if type(startTime) ~= "number" or type(cdDuration) ~= "number" or cdDuration <= 0 then
                return nil, nil
            end
            -- Filter out GCD (1.5s) from real cooldowns
            if cdDuration <= 2.5 then
                return nil, nil
            end
            local remaining = math.max((startTime + cdDuration) - GetCurrentTime(), 0)
            if remaining <= 0 then return nil, nil end
            return remaining, cdDuration
        end
        return nil, nil
    end

    local function CreateRogueBuffIcons()
        if #rogueBuffIcons > 0 then return end
        local iconSize = SuperSwingTimerDB and SuperSwingTimerDB.rogueBuffIconSize or 25
        if type(iconSize) ~= "number" or iconSize <= 0 then iconSize = 25 end

        for _, spell in ipairs(ROGUE_TRACKED_SPELLS) do
            local icon = CreateFrame("Frame", nil, UIParent)
            icon:SetSize(iconSize, iconSize)
            icon:SetFrameStrata("DIALOG")
            icon:EnableMouse(false)
            icon.texture = icon:CreateTexture(nil, "BACKGROUND")
            icon.texture:SetAllPoints()
            icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            local texPath = GetSpellTexture and GetSpellTexture(spell.spellId)
            if texPath then icon.texture:SetTexture(texPath) end
            icon.glow = icon:CreateTexture(nil, "OVERLAY", nil, 7)
            icon.glow:SetAllPoints()
            icon.glow:SetColorTexture(1, 0.85, 0, 0)
            icon.glow:SetBlendMode("ADD")
            -- 4-edge outline border (not a full-face overlay)
            icon.border = {}
            icon.border.top = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.top:SetPoint("TOPLEFT", -1, 1)
            icon.border.top:SetPoint("TOPRIGHT", 1, 1)
            icon.border.top:SetHeight(1)
            icon.border.top:SetColorTexture(0, 0, 0, 0.65)
            icon.border.bottom = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.bottom:SetPoint("BOTTOMLEFT", -1, -1)
            icon.border.bottom:SetPoint("BOTTOMRIGHT", 1, -1)
            icon.border.bottom:SetHeight(1)
            icon.border.bottom:SetColorTexture(0, 0, 0, 0.65)
            icon.border.left = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.left:SetPoint("TOPLEFT", -1, 1)
            icon.border.left:SetPoint("BOTTOMLEFT", -1, -1)
            icon.border.left:SetWidth(1)
            icon.border.left:SetColorTexture(0, 0, 0, 0.65)
            icon.border.right = icon:CreateTexture(nil, "OVERLAY", nil, -1)
            icon.border.right:SetPoint("TOPRIGHT", 1, 1)
            icon.border.right:SetPoint("BOTTOMRIGHT", 1, -1)
            icon.border.right:SetWidth(1)
            icon.border.right:SetColorTexture(0, 0, 0, 0.65)
            icon.durationText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            icon.durationText:SetPoint("CENTER", icon, "TOP", 0, 0)
            icon.durationText:SetJustifyH("CENTER")
            icon.durationText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            icon.durationText:SetTextColor(1, 1, 1, 0.95)
            icon.durationText:Hide()
            icon:Hide()
            icon.spellId = spell.spellId
            icon.label = spell.label
            icon.kind = spell.kind
            table.insert(rogueBuffIcons, icon)
        end
    end

    ns.UpdateRogueBuffIcons = function (elapsed)
        CreateRogueBuffIcons()
        if #rogueBuffIcons == 0 then return end

        rogueBuffTimer = rogueBuffTimer + (elapsed or 0.03)
        if rogueBuffTimer < ROGUE_BUFF_UPDATE_INTERVAL then return end
        rogueBuffTimer = 0

        local db = SuperSwingTimerDB or ns.DB_DEFAULTS
        if db and db.showRogueBuffIcons == false then
            for _, icon in ipairs(rogueBuffIcons) do
                if icon and icon.Hide then icon:Hide() end
            end
            return
        end
        if ns.playerInCombat ~= true then
            for _, icon in ipairs(rogueBuffIcons) do
                if icon and icon.Hide then icon:Hide() end
            end
            return
        end

        local iconSize = SuperSwingTimerDB and SuperSwingTimerDB.rogueBuffIconSize or 25
        if type(iconSize) ~= "number" or iconSize <= 0 then iconSize = 25 end

        local activeIcons = {}
        for _, icon in ipairs(rogueBuffIcons) do
            if icon and icon.spellId then
                for _, spell in ipairs(ROGUE_TRACKED_SPELLS) do
                    if spell.spellId == icon.spellId then
                        local remaining, totalDuration = GetRogueSpellRemaining(spell)
                        if type(remaining) == "number" and remaining > 0
                            and type(totalDuration) == "number" and totalDuration > 0 then
                            table.insert(activeIcons, {
                                icon = icon,
                                remaining = remaining,
                                totalDuration = totalDuration
                            })
                        else
                            if icon.Hide then icon:Hide() end
                        end
                        break
                    end
                end
            elseif icon and icon.Hide then
                icon:Hide()
            end
        end

        local numActive = #activeIcons
        if numActive == 0 then return end

        local referenceBar = ns.mhBar
        if not referenceBar then return end
        -- Position icons above all visible target debuff duration bars
        local iconY = GetDebuffStackOffset({
            ruptureBar,
            exposeArmorBar,
        }, ns.mhBar)
        local barGetWidth = referenceBar.GetWidth
        if not barGetWidth then return end

        for idx, entry in ipairs(activeIcons) do
            local icon = entry.icon
            local remaining = entry.remaining
            local totalDuration = entry.totalDuration

            if icon.SetSize then icon:SetSize(iconSize, iconSize) end

            -- Right-align icons
            local xOffset = -(numActive - idx) * (iconSize + ROGUE_BUFF_ICON_GAP)
            local rightAlign = -(iconSize / 2)
            local finalX = rightAlign + xOffset

            if icon.ClearAllPoints then icon:ClearAllPoints() end
            if icon.SetPoint then icon:SetPoint("BOTTOM", referenceBar, "TOP", finalX, iconY) end

            -- No shading
            if icon.dim and icon.dim.SetColorTexture then
                icon.dim:SetColorTexture(0, 0, 0, 0)
            end

            -- Glow in last 4 seconds
            if icon.glow and icon.glow.SetColorTexture then
                local shouldGlow = remaining <= 4 and remaining > 0
                if shouldGlow and totalDuration > 0 then
                    local pulseAlpha = 0.15 + 0.40 * (0.5 + 0.5 * math.sin(GetCurrentTime() * 6))
                    icon.glow:SetColorTexture(1, 0.85, 0, pulseAlpha)
                    if icon.glow.Show then icon.glow:Show() end
                elseif icon.glow.Hide then
                    icon.glow:Hide()
                end
            end

            -- Countdown text
            if icon.durationText and icon.durationText.SetText then
                local text = remaining >= 3 and string.format("%.0f", remaining) or string.format("%.1f", remaining)
                icon.durationText:SetText(text)
                if icon.durationText.Show then icon.durationText:Show() end
            end

            if icon.Show then icon:Show() end
        end
    end
end

-- ============================================================
-- Dispatch: pick class mods for the current class
-- ============================================================
-- ============================================================
-- Dispatch: pick class mods for the current class
-- ============================================================

--- Initialize class-specific mods for the current player class.
--  Dispatches to the correct Setup*() function. Nil-clears all
--  class-specific ns.Update* symbols before setup so stale closures
--  from a previous init never call into the wrong class's helpers.
--  @return (nil)
--  @usage Called during OnAddonLoaded before InitBars()
function ns.InitClassMods()
    ns.OnBarsCreated = nil
    ns.OnDruidFormChange = nil
    ns.OnMeleeSwing = nil
    ns.OnRangedSwing = nil
    ns.IsHunterTargetInMeleeRange = nil
    ns.UpdateWarriorQueueTint = nil
    ns.ClearWarriorQueueTint = nil
    ns.UpdateWarriorRageBar = nil
    ns.UpdateWarriorShieldBlockBar = nil
    ns.UpdateWarriorDeepWoundsBar = nil
    ns.UpdateDruidQueueTint = nil
    ns.ClearDruidQueueTint = nil
    ns.IsDruidCatFormActive = nil
    ns.UpdateDruidEnergyTickColor = nil
    ns.UpdateDruidEnergyTickVisual = nil
    ns.HandleDruidEnergyPowerUpdate = nil
    ns.UpdateDruidRavageCue = nil
    ns.UpdateDruidMangleTimer = nil
    ns.UpdateDruidRipTracker = nil
    ns.UpdateDruidMangleBar = nil
    ns.UpdateDruidRipBar = nil
    ns.UpdateDruidRakeBar = nil
    ns.UpdateDruidBuffIcons = nil
    ns.UpdateHunterQueueTint = nil
    ns.ClearHunterQueueTint = nil
    ns.UpdateHunterRangeHelperColor = nil
    ns.UpdateHunterRangeHelperVisual = nil
    ns.UpdateRogueSinisterAssistColor = nil
    ns.UpdateRogueSinisterAssistVisual = nil
    ns.UpdateRogueEnergyTickColor = nil
    ns.UpdateRogueEnergyTickVisual = nil
    ns.UpdateRogueComboPointColor = nil
    ns.UpdateRogueComboPointVisual = nil
    ns.UpdateRogueSliceAndDiceColor = nil
    ns.UpdateRogueSliceAndDiceVisual = nil
    ns.UpdatePaladinJudgementBar = nil
    ns.UpdatePaladinSealVengeanceBar = nil
    ns.UpdateShamanFlameShockBar = nil
    ns.UpdateHunterAspect = nil
    ns.UpdateHunterBuffIcons = nil
    ns.UpdateHunterSerpentStingBar = nil
    ns.UpdateHunterWingClipBar = nil
    ns.UpdateHunterConcussionShotBar = nil
    ns.UpdateHunterImmolationTrapBar = nil
    ns.UpdateHunterExplosiveTrapBar = nil
    ns.UpdateHunterFreezingTrapBar = nil
    ns.UpdateHunterFrostTrapBar = nil
    ns.UpdateRogueRuptureBar = nil
    ns.UpdateRogueExposeArmorBar = nil
    ns.UpdateWarriorSunderArmorBar = nil
    ns._hunterOnUpdateWrapped = nil
    ns.HandleRogueComboPointsChanged = nil
    ns.HandleRogueEnergyPowerUpdate = nil
    ns.HandleRogueSliceAndDiceAura = nil
    ns.warriorQueuedMeleeSpell = nil
    ns.druidQueuedMeleeSpell = nil
    ns.hunterQueuedMeleeSpell = nil
    ns.druidLastEnergy = nil
    ns.druidEnergyTickStartTime = nil
    ns.rogueLastEnergy = nil
    ns.rogueEnergyTickStartTime = nil
    ns.rogueComboPointCount = nil
    ns.rogueSliceAndDiceDuration = nil
    ns.rogueSliceAndDiceExpirationTime = nil
    ns.rogueSliceAndDiceNextRefreshAt = nil
    if ns.rogueSinisterAssistZone then
        ns.rogueSinisterAssistZone:Hide()
    end
    if ns.rogueEnergyTickBar then
        ns.rogueEnergyTickBar:SetAlpha(0)
    end
    if ns.druidEnergyTickBar then
        ns.druidEnergyTickBar:SetAlpha(0)
    end
    if ns.rogueEnergyTotalBar then
        ns.rogueEnergyTotalBar:SetAlpha(0)
    end
    if ns.rogueComboPointContainer then
        ns.rogueComboPointContainer:Hide()
    end
    if ns.rogueComboPointBars then
        for _, bar in ipairs(ns.rogueComboPointBars) do
            if bar then
                bar:SetAlpha(0)
            end
        end
    end
    if ns.rogueSliceAndDiceBar then
        ns.rogueSliceAndDiceBar:SetAlpha(0)
    end
    if ns.hunterRangeHelperBar then
        ns.hunterRangeHelperBar:SetAlpha(0)
        ns.hunterRangeHelperBar:SetValue(0)
    end
    if ns.warriorRageBar then
        ns.warriorRageBar:SetAlpha(0)
    end
    if ns.shamanFlameShockBar then
        ns.shamanFlameShockBar:Hide()
    end

    local class = ns.playerClass
    if class == "PALADIN" then
        pcall(SetupRetPaladin)
    elseif class == "WARRIOR" then
        pcall(SetupWarrior)
    elseif class == "ROGUE" then
        pcall(SetupRogue)
    elseif class == "HUNTER" then
        pcall(SetupHunter)
    elseif class == "SHAMAN" then
        -- Save base OnUpdate before SetupEnhShaman wraps it, so we can restore
        -- the chain if the initializer fails silently (e.g. from a weave catalog
        -- lookup error on Anniversary 2.5.5).
        local preShamanOnUpdate = ns.OnUpdate
        local ok = pcall(SetupEnhShaman)
        if not ok then
            -- Fail-open for production safety: keep core bars operational even if a
            -- class helper initializer throws in edge client/API states.
            -- Clear ALL partial Shaman state so OnUpdate doesn't call broken upvalues.
            ns.OnBarsCreated = nil
            ns.UpdateLightningShieldVisual = nil
            ns.UpdateShamanFlameShockBar = nil
            ns.UpdateShamanWindfuryIcd = nil
            ns.UpdateShamanBuffIcons = nil
            -- Restore OnUpdate to the pre-Shaman version so bar rendering chain
            -- is intact even though Shaman overlays are offline.
            if preShamanOnUpdate then
                ns.OnUpdate = preShamanOnUpdate
            end
        end
    elseif class == "DRUID" then
        pcall(SetupDruid)
    end
end

-- ============================================================
-- WoWUnit test harness: expose internal functions for in-game
-- unit tests. Only loaded when WoWUnit addon is present.
-- ============================================================
if WoWUnit then
    ns._Test = {}
    ns._Test.GetHarmfulAuraData = GetHarmfulAuraData
    ns._Test.GetHelpfulAuraData = GetHelpfulAuraData
    ns._Test.GetDebuffStackOffset = GetDebuffStackOffset
    ns._Test.RestackDebuffBars = RestackDebuffBars
    ns._Test.GetFlurryBuffInfo = GetFlurryBuffInfo
end
