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
for _, flurryName in ipairs(FLURRY_BUFF_NAMES) do
	FLURRY_BUFF_NAME_LOOKUP[flurryName] = true
end
local FLURRY_BUFF_SPELL_IDS = {
	[12319] = true, -- Flurry (all ranks)
	[16280] = true, -- Flurry (rank 4+)
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

	-- Semi-transparent border
	icon.border = icon:CreateTexture(nil, "OVERLAY")
	icon.border:SetDrawLayer("OVERLAY", -1)
	icon.border:SetColorTexture(0, 0, 0, 0.65)
	icon.border:SetPoint("TOPLEFT", -1, 1)
	icon.border:SetPoint("BOTTOMRIGHT", 1, -1)

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
	if not unit or not index then
		return nil
	end

	local name
	local a5
	local a6
	local a7
	local a10
	local a11
	if UnitBuff then
		name, _, _, _, a5, a6, a7, _, _, a10, a11 = UnitBuff(unit, index)
	elseif UnitAura then
		name, _, _, _, a5, a6, a7, _, _, a10, a11 = UnitAura(unit, index, "HELPFUL")
	end

	if not name then
		return nil
	end

	local duration
	local expirationTime
	local spellId

	if type(a10) == "number" then
		-- Current Classic / TBC Anniversary helpful-aura shape.
		duration = a5
		expirationTime = a6
		spellId = a10
	else
		-- Older Classic-compatible helpful-aura shape.
		duration = a6
		expirationTime = a7
		spellId = type(a11) == "number" and a11 or nil
	end

	return name, duration, expirationTime, spellId
end

local function GetHarmfulAuraData(unit, index, filter)
	if not unit or not index or not UnitAura then
		return nil
	end

	local name
	local auraCountRaw
	local auraTypeOrDuration
	local maybeDuration
	local maybeExpiration
	local maybeCaster
	local maybeSpellId
	local legacySpellId

	name, _, auraCountRaw, auraTypeOrDuration, maybeDuration, maybeExpiration, maybeCaster, _, _, maybeSpellId, legacySpellId = UnitAura(unit, index, filter or "HARMFUL")
	if not name then
		return nil
	end

	local auraCount = tonumber(auraCountRaw) or 0
	local duration
	local expirationTime
	local caster

	-- Classic-family builds can shift harmful-aura tuple fields. Prefer typed parsing.
	if type(auraTypeOrDuration) == "number" and type(maybeDuration) == "number" then
		-- Current Classic/TBC Anniversary harmful-aura shape.
		duration = auraTypeOrDuration
		expirationTime = maybeDuration
		caster = maybeExpiration
	elseif type(maybeDuration) == "number" and type(maybeExpiration) == "number" then
		-- Older Classic-compatible harmful-aura shape.
		duration = maybeDuration
		expirationTime = maybeExpiration
		caster = maybeCaster
	else
		duration = tonumber(auraTypeOrDuration) or tonumber(maybeDuration)
		expirationTime = tonumber(maybeDuration) or tonumber(maybeExpiration)
		caster = maybeExpiration or maybeCaster
	end

	local spellId = type(maybeSpellId) == "number" and maybeSpellId or (type(legacySpellId) == "number" and legacySpellId or nil)

	return name, auraCount, duration, expirationTime, caster, spellId
end

local function EnsureVerticalHelperBar(frameName, anchorBar, width, texturePath)
	local bar = rawget(_G, frameName)
	if not bar then
		bar = CreateFrame("StatusBar", frameName, UIParent)
	end

	local baseBar = anchorBar or ns.mhBar or ns.rangedBar
	local resolvedTexture = texturePath or (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
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
	local backgroundColor = ns.GetBarBackgroundColor and ns.GetBarBackgroundColor() or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBackgroundColor)
	backgroundColor = backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
	backgroundTexture:SetColorTexture(backgroundColor.r or 0, backgroundColor.g or 0, backgroundColor.b or 0, 1)
	backgroundTexture:SetAlpha(backgroundColor.a ~= nil and backgroundColor.a or 0.5)

	if not bar.borderTextures then
		local borderColor = ns.GetBarBorderColor and ns.GetBarBorderColor() or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBorderColor)
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

		bar.borderTextures = {
			top = borderTop,
			bottom = borderBottom,
			left = borderLeft,
			right = borderRight,
		}
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
			duration = (type(mainHandSpeed) == "number" and mainHandSpeed > 0) and mainHandSpeed
			        or (timer and timer.duration and timer.duration > 0 and timer.duration)
			        or 2.0
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
		local resealX = math.max(math.min((barWidth * resealTick) - (resealLineWidth * 0.5), barWidth - resealLineWidth), 0)

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
			duration = (type(mainHandSpeed) == "number" and mainHandSpeed > 0) and mainHandSpeed
			        or (timer and timer.duration and timer.duration > 0 and timer.duration)
			        or 2.0
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

	ns.HandlePaladinLibramEquipmentChanged = function(slot)
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
	ns.OnBarsCreated = function()
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



		local origOnUpdate = ns.OnUpdate
		ns.OnUpdate = function(elapsed)
			origOnUpdate(elapsed)
			UpdateSealColorAndLabel()
			UpdateSealBreakpointLine()
			UpdateJudgementMarker()
			UpdateReckoningBadge()
			UpdatePaladinLibramSwapBadge()
			CheckTwistSuccess()
		end
		-- Force initial update of seal zone and markers
		UpdateSealColorAndLabel()
		UpdateSealBreakpointLine()
		UpdateJudgementMarker()
		UpdateReckoningBadge()
		UpdatePaladinLibramSwapBadge()
	end

	-- Register a handler for when a melee swing lands, used to detect seal twists.
	-- Uses ns.OnMeleeSwing (called from State.lua) matching the pattern other classes use.
	ns.OnMeleeSwing = function(slot)
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
		ns.RestoreMainHandColor = function()
			if not ns.mhBar then return end
			local c = ns.mhBarBaseColor or (ns.GetBarColor and ns.GetBarColor("mh"))
			if c then
				ns.mhBar:SetStatusBarColor(c.r or 0, c.g or 0, c.b or 0, c.a or 1)
			end
		end
	end
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
			ns.mhBar:SetStatusBarColor(WARRIOR_HEROIC_STRIKE_TINT.r, WARRIOR_HEROIC_STRIKE_TINT.g, WARRIOR_HEROIC_STRIKE_TINT.b, alpha)
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
			ns.mhBar:SetStatusBarColor(WARRIOR_HEROIC_STRIKE_TINT.r, WARRIOR_HEROIC_STRIKE_TINT.g, WARRIOR_HEROIC_STRIKE_TINT.b, alpha) -- Heroic Strike: yellow
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
	ns.OnMeleeSwing = function(slot)
		if slot == "mh" and ns.mhBar then
			ns.warriorQueuedMeleeSpell = nil
			RestoreMainHandColor()
		end
	end

	ns.ClearWarriorQueueTint = function()
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
		return ns.PAUSE_SWING_SPELLS and (ns.PAUSE_SWING_SPELLS[spellToken] or ns.PAUSE_SWING_SPELLS[tonumber(spellToken) or -1]) or false
	end

	local function GetSpellCastDuration(spellToken)
		local GetSpellInfo = ns.GetSpellInfo or rawget(_G, "GetSpellInfo")
		if GetSpellInfo then
			local _, _, _, castTimeMs = GetSpellInfo(spellToken)
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
			warriorSlamBar:SetStatusBarTexture(ns.GetBarTexture and ns.GetBarTexture() or "Interface\\TargetingFrame\\UI-StatusBar")
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

	ns.UpdateWarriorRageBar = function()
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

	ns.UpdateWarriorShieldBlockBar = function(elapsed, force)
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

			local backgroundTexture = shieldBlockBar.backgroundTexture or shieldBlockBar:CreateTexture(nil, "BACKGROUND")
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
					right = borderRight,
				}
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
		shieldBlockBar:SetStatusBarTexture(ns.GetBarTexture and ns.GetBarTexture() or "Interface\\TargetingFrame\\UI-StatusBar")
		shieldBlockBar:SetSize((ns.mhBar and ns.mhBar:GetWidth()) or ns.BAR_WIDTH or 240, ns.WARRIOR_SHIELD_BLOCK_BAR_HEIGHT or 4)
		local shieldColor = ns.GetBarColor and ns.GetBarColor("shieldBlockBar") or { r = 0.20, g = 0.55, b = 1.00, a = 0.90 }
		shieldBlockBar:SetStatusBarColor(shieldColor.r or 0.20, shieldColor.g or 0.55, shieldColor.b or 1.00, shieldColor.a or 0.90)

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
		bar:SetSize(
			(ns.mhBar and ns.mhBar:GetWidth()) or ns.BAR_WIDTH or 240,
			4
		)
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
		local backgroundColor = ns.GetBarBackgroundColor and ns.GetBarBackgroundColor() or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBackgroundColor)
		backgroundColor = backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
		backgroundTexture:SetColorTexture(backgroundColor.r or 0, backgroundColor.g or 0, backgroundColor.b or 0, 1)
		backgroundTexture:SetAlpha(backgroundColor.a ~= nil and backgroundColor.a or 0.5)

		if not bar.borderTextures then
			local borderColor = ns.GetBarBorderColor and ns.GetBarBorderColor() or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBorderColor)
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

			bar.borderTextures = {
				top = borderTop,
				bottom = borderBottom,
				left = borderLeft,
				right = borderRight,
			}
		end

		bar.backgroundTexture = backgroundTexture
		bar.statusBarTexture = statusBarTexture
		bar:SetAlpha(0)
		ns.warriorRageBar = bar
	end

	-- Chain into OnUpdate
	local origWarriorOnUpdate = ns.OnUpdate or function() end
	ns.OnUpdate = function(elapsed)
		origWarriorOnUpdate(elapsed)
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
	end

	ns.UpdateWarriorRageBar()
	ns.UpdateWarriorShieldBlockBar(0, true)

	-- Hook warrior queued attacks so each special gets its own tint.
	if ns.RegisterSpellcastSucceededHook then
		ns.RegisterSpellcastSucceededHook(function(unit, castGUIDOrSpellName, spellId)
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
	ns.UpdateWarriorFlurryCounter = function()
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
		local topFallbackTexture = ns.GetWeaveTriangleTopTexture and ns.GetWeaveTriangleTopTexture() or "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow"
		local bottomFallbackTexture = ns.GetWeaveTriangleBottomTexture and ns.GetWeaveTriangleBottomTexture() or "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow"
		local sparkFallbackTexture = ns.GetWeaveSparkTexture and ns.GetWeaveSparkTexture() or "Interface\\CastingBar\\UI-CastingBar-Spark"
		local sparkWidth = ns.GetWeaveSparkWidth and ns.GetWeaveSparkWidth() or 14
		local sparkHeight = ns.GetWeaveSparkHeight and ns.GetWeaveSparkHeight() or 30
		local clampedSparkHeight = math.max(1, math.min(sparkHeight, (ns.mhBar and ns.mhBar:GetHeight()) or ns.BAR_HEIGHT or sparkHeight))
		local sparkAlpha = ns.GetWeaveSparkAlpha and ns.GetWeaveSparkAlpha() or 0.95
		local triangleAlpha = ns.GetWeaveTriangleAlpha and ns.GetWeaveTriangleAlpha() or 1
		local sparkPos = 0
		local sparkVisualWidth = sparkWidth
		local sparkVisualHeight = clampedSparkHeight

		if showSpark then
			local castStartFraction = info.castStartSwingFraction or info.currentSwingFraction or info.markerFraction or 0
			local castProgress = math.max(0, math.min(info.castProgress or 0, 1))
			local movingFraction = math.max(0, math.min(castStartFraction + ((1 - castStartFraction) * castProgress), 1))
			sparkPos = movingFraction * barWidth
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
		ApplyWeaveSparkTexture(ns.weaveSpark, nil, sparkFallbackTexture, sparkVisualWidth, sparkVisualHeight, sparkAlpha, color)
		ns.weaveSpark:SetShown(showSpark)

		-- OH spark (mirrors MH spark when dual-wielding)
		if ns.weaveSparkOH then
			local ohSparkHeight = math.max(1, math.min(sparkHeight, (ns.ohBar and ns.ohBar:GetHeight()) or sparkHeight))
			ns.weaveSparkOH:ClearAllPoints()
			ns.weaveSparkOH:SetPoint("CENTER", ns.ohBar, "LEFT", sparkPos, 0)
			ApplyWeaveSparkTexture(ns.weaveSparkOH, nil, sparkFallbackTexture, sparkVisualWidth, ohSparkHeight, sparkAlpha, color)
			ns.weaveSparkOH:SetShown(showSpark and hasOffHand)
		end

		-- Top triangle: always above MH bar
		ns.weaveTriangleTop:ClearAllPoints()
		ns.weaveTriangleTop:SetPoint("BOTTOM", barAnchor, "TOPLEFT", markerPos, triangleGap)
		ApplyWeaveMarkerTexture(ns.weaveTriangleTop, iconTexture, topFallbackTexture, triangleSize, triangleAlpha, color)
		ns.weaveTriangleTop:Show()

		-- Bottom triangle: below OH when visible, below MH otherwise
		local bottomAnchor = hasOffHand and ns.ohBar and GetOverlayParent(ns.ohBar) or barAnchor
		ns.weaveTriangleBottom:ClearAllPoints()
		ns.weaveTriangleBottom:SetPoint("TOP", bottomAnchor, "BOTTOMLEFT", markerPos, -triangleGap)
		ApplyWeaveMarkerTexture(ns.weaveTriangleBottom, iconTexture, bottomFallbackTexture, triangleSize, triangleAlpha, color)
		ns.weaveTriangleBottom:Show()
		if ns.weaveMarker then
			ns.weaveMarker:SetShown(showSpark)
		end
	end

	local LIGHTNING_SHIELD_RECT_WIDTH      = 5
	local LIGHTNING_SHIELD_RECT_GAP        = 1
	local LIGHTNING_SHIELD_NUM_RECTS       = 3
	local LIGHTNING_SHIELD_BAR_GAP_DEFAULT = 6

	ns.OnBarsCreated = function()
		if not ns.mhBar then
			return
		end
		if ns.weaveSpark and ns.weaveTriangleTop and ns.weaveTriangleBottom and ns.shamanLightningContainer and ns.shamanLightningRects then
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
		weaveSpark:SetTexture(ns.GetWeaveSparkTexture and ns.GetWeaveSparkTexture() or "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_FullWhite")
		weaveSpark:SetDrawLayer("OVERLAY", 7)
		weaveSpark:SetBlendMode(ns.GetIndicatorBlendMode and ns.GetIndicatorBlendMode() or "ADD")
		weaveSpark:SetAlpha(ns.GetWeaveSparkAlpha and ns.GetWeaveSparkAlpha() or 0.95)
		weaveSpark:SetWidth(ns.GetWeaveSparkWidth and ns.GetWeaveSparkWidth() or 14)
		weaveSpark:SetHeight(math.max(1, math.min((ns.GetWeaveSparkHeight and ns.GetWeaveSparkHeight() or 30), (ns.mhBar and ns.mhBar:GetHeight()) or (ns.BAR_HEIGHT or 30))))
		weaveSpark:SetPoint("CENTER", weaveOverlayFrame, "LEFT", 0, 0)

		local weaveTriangleTop = weaveOverlayFrame:CreateTexture(nil, "OVERLAY")
		weaveTriangleTop:SetTexture(ns.GetWeaveTriangleTopTexture and ns.GetWeaveTriangleTopTexture() or "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow")
		if ns.SetTextureLayerAboveBar then
			ns.SetTextureLayerAboveBar(weaveTriangleTop, ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY", ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK")
		else
			weaveTriangleTop:SetDrawLayer(ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY", 7)
		end
		weaveTriangleTop:SetBlendMode(ns.GetIndicatorBlendMode and ns.GetIndicatorBlendMode() or "ADD")
		weaveTriangleTop:SetAlpha(ns.GetWeaveTriangleAlpha and ns.GetWeaveTriangleAlpha() or 1)
		weaveTriangleTop:SetWidth(ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14)
		weaveTriangleTop:SetHeight(ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14)

		local weaveTriangleBottom = weaveOverlayFrame:CreateTexture(nil, "OVERLAY")
		weaveTriangleBottom:SetTexture(ns.GetWeaveTriangleBottomTexture and ns.GetWeaveTriangleBottomTexture() or "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow")
		if ns.SetTextureLayerAboveBar then
			ns.SetTextureLayerAboveBar(weaveTriangleBottom, ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY", ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK")
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
			weaveSparkOH:SetTexture(ns.GetWeaveSparkTexture and ns.GetWeaveSparkTexture() or "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_FullWhite")
			weaveSparkOH:SetDrawLayer("OVERLAY", 7)
			weaveSparkOH:SetBlendMode(ns.GetIndicatorBlendMode and ns.GetIndicatorBlendMode() or "ADD")
			weaveSparkOH:SetAlpha(ns.GetWeaveSparkAlpha and ns.GetWeaveSparkAlpha() or 0.95)
			weaveSparkOH:SetWidth(ns.GetWeaveSparkWidth and ns.GetWeaveSparkWidth() or 14)
			weaveSparkOH:SetHeight(math.max(1, math.min((ns.GetWeaveSparkHeight and ns.GetWeaveSparkHeight() or 30), (ns.ohBar and ns.ohBar:GetHeight()) or (ns.BAR_HEIGHT or 30))))
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
		[33757] = true,
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

	ns.UpdateShamanWindfuryIcd = function()
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
		if not shouldGlow then
			for _, edge in ipairs(glowBorder) do
				edge:Hide()
			end
			return
		end

		local now = GetCurrentTime()
		local pulse = 0.5 + (0.5 * math.sin(now * 10))
		local alpha = 0.35 + (0.45 * pulse)
		for _, edge in ipairs(glowBorder) do
			edge:SetColorTexture(1.0, 0.45, 0.08, alpha)
			edge:Show()
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
		flameShockBar:SetStatusBarTexture((ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar")
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
		local glowTop = flameShockBar:CreateTexture(nil, "OVERLAY")
		glowTop:SetPoint("TOPLEFT", flameShockBar, "TOPLEFT", -1, 1)
		glowTop:SetPoint("TOPRIGHT", flameShockBar, "TOPRIGHT", 1, 1)
		glowTop:SetHeight(1)
		glowTop:SetColorTexture(1.0, 0.45, 0.08, 0)
		glowTop:Hide()
		glowBorder[#glowBorder + 1] = glowTop

		local glowBottom = flameShockBar:CreateTexture(nil, "OVERLAY")
		glowBottom:SetPoint("BOTTOMLEFT", flameShockBar, "BOTTOMLEFT", -1, -1)
		glowBottom:SetPoint("BOTTOMRIGHT", flameShockBar, "BOTTOMRIGHT", 1, -1)
		glowBottom:SetHeight(1)
		glowBottom:SetColorTexture(1.0, 0.45, 0.08, 0)
		glowBottom:Hide()
		glowBorder[#glowBorder + 1] = glowBottom

		local glowLeft = flameShockBar:CreateTexture(nil, "OVERLAY")
		glowLeft:SetPoint("TOPLEFT", flameShockBar, "TOPLEFT", -1, 1)
		glowLeft:SetPoint("BOTTOMLEFT", flameShockBar, "BOTTOMLEFT", -1, -1)
		glowLeft:SetWidth(1)
		glowLeft:SetColorTexture(1.0, 0.45, 0.08, 0)
		glowLeft:Hide()
		glowBorder[#glowBorder + 1] = glowLeft

		local glowRight = flameShockBar:CreateTexture(nil, "OVERLAY")
		glowRight:SetPoint("TOPRIGHT", flameShockBar, "TOPRIGHT", 1, 1)
		glowRight:SetPoint("BOTTOMRIGHT", flameShockBar, "BOTTOMRIGHT", 1, -1)
		glowRight:SetWidth(1)
		glowRight:SetColorTexture(1.0, 0.45, 0.08, 0)
		glowRight:Hide()
		glowBorder[#glowBorder + 1] = glowRight

		flameShockBar.glowBorder = glowBorder

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
			local auraName, _, duration, expirationTime, caster, auraSpellId = GetHarmfulAuraData("target", index, "HARMFUL")

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

		bar:SetStatusBarTexture((ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar")
		bar:SetMinMaxValues(0, duration)
		bar:SetValue(remaining)
		bar:SetHeight(FLAME_SHOCK_BAR_HEIGHT)
		bar:ClearAllPoints()
		bar:SetPoint("BOTTOMLEFT", ns.mhBar, "TOPLEFT", 0, 2)
		bar:SetPoint("BOTTOMRIGHT", ns.mhBar, "TOPRIGHT", 0, 2)
		SetFlameShockGlow(bar, remaining)
		bar:Show()
	end

	ns.UpdateShamanFlameShockBar = function(force)
		UpdateShamanFlameShockBar(force == true)
	end

	local WATER_SHIELD_OVERRIDE_COLOR  = { r = 0.50, g = 0.80, b = 1.0, a = 0.90 }

	local function IsLightningShieldActive()
		for index = 1, 40 do
			local auraName, _, _, auraSpellId = GetHelpfulAuraData("player", index)
			if not auraName then
				break
			end

			local normalizedAuraName = type(auraName) == "string" and auraName:lower() or nil
			if type(auraSpellId) == "number" and ns.SHAMAN_LIGHTNING_SHIELD_IDS and ns.SHAMAN_LIGHTNING_SHIELD_IDS[auraSpellId] then
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
			trackerGap = (ns.DB_DEFAULTS and ns.DB_DEFAULTS.shamanLightningTrackerGap) or LIGHTNING_SHIELD_BAR_GAP_DEFAULT
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

	local previousOnUpdate2 = ns.OnUpdate or function() end
	ns.OnUpdate = function(elapsed)
		previousOnUpdate2(elapsed)
		UpdateWeaveVisuals()
		UpdateShamanFlameShockBar(false)
		UpdateShamanFlurryIcon()
		UpdateShamanStormstrikeBadge()
		UpdateShamanisticRageBadge()
		UpdateLightningShieldVisual()
	end

	local function SafeInitCall(fn)
		if type(fn) ~= "function" then
			return
		end
		pcall(fn)
	end

	SafeInitCall(UpdateWeaveVisuals)
	SafeInitCall(function() UpdateShamanFlameShockBar(true) end)
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
	ns.OnMeleeSwing = function(slot)
		if slot == "mh" and ns.mhBar then
			ns.druidQueuedMeleeSpell = nil
			RestoreMainHandColor()
		end
	end

	ns.ClearDruidQueueTint = function()
		ns.druidQueuedMeleeSpell = nil
		RestoreMainHandColor()
	end

	ns.OnDruidFormChange = function(_formSpellId)
		if ns.mhBar and ns.mhBar.labelText then
			ns.mhBar.labelText:SetText(GetDruidFormLabel())
		end
		ns.druidLastEnergy = type(UnitPower) == "function" and UnitPower("player") or ns.druidLastEnergy
		ns.druidEnergyTickStartTime = GetCurrentTime()
		UpdateDruidEnergyTickVisual()
		UpdateDruidQueueTint()
	end

	ns.OnBarsCreated = function()
		if not ns.mhBar then
			return
		end

		if not ns.druidEnergyTickBar then
			ns.druidEnergyTickBar = EnsureVerticalHelperBar("SuperSwingTimerDruidEnergyTickBar", ns.mhBar, ns.DRUID_ENERGY_TICK_BAR_WIDTH or ns.DB_DEFAULTS.druidEnergyTickBarWidth or 4)
		end

		ApplyDruidEnergyTickColor()
		ns.druidLastEnergy = type(UnitPower) == "function" and UnitPower("player") or ns.druidLastEnergy
		if not ns.druidEnergyTickStartTime then
			ns.druidEnergyTickStartTime = GetCurrentTime()
		end
		if ns.mhBar.labelText then
			ns.mhBar.labelText:SetText(GetDruidFormLabel())
		end

		local previousOnUpdate = ns.OnUpdate or function() end
		ns.OnUpdate = function(elapsed)
			previousOnUpdate(elapsed)
			UpdateDruidQueueTint()
			UpdateDruidEnergyTickVisual()
		end

		UpdateDruidEnergyTickVisual()
		UpdateDruidQueueTint()
	end

	-- Hook druid queued attacks (Maul)
	if ns.RegisterSpellcastSucceededHook then
		ns.RegisterSpellcastSucceededHook(function(unit, castGUIDOrSpellName, spellId)
			local spellToken = spellId ~= nil and spellId or castGUIDOrSpellName
			if unit == "player" and ns.DRUID_MAUL_SPELLS and ns.DRUID_MAUL_SPELLS[spellToken] then
				ApplyDruidQueueTint(spellToken)
			end
			if ns.UpdateDruidQueueTint then
				ns.UpdateDruidQueueTint()
			end
		end)
	end
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
		local color = ns.GetBarColor and ns.GetBarColor(colorKey) or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.colors and ns.DB_DEFAULTS.colors[colorKey])
		if not color then
			return
		end

		helperBar:SetStatusBarColor(
			color.r or 1,
			color.g or 1,
			color.b or 1,
			color.a ~= nil and color.a or 1
		)
	end

	local function GetHunterRangeHelperAnchors()
		local previewActive = ns.barTestActive == true
		local topAnchor = ns.rangedBar
		local bottomAnchor = ns.rangedBar

		-- Cast bar extends below the ranged bar when visible (MH bar does NOT affect height)
		if ns.hunterCastBar and (previewActive or ((ns.hunterCastBar.GetAlpha and ns.hunterCastBar:GetAlpha()) or 0) > 0) then
			bottomAnchor = ns.hunterCastBar
		end

		return topAnchor, bottomAnchor
	end

	local function UpdateHunterRangeHelperVisual(forcedRangeState)
		local helperBar = ns.hunterRangeHelperBar
		local db = SuperSwingTimerDB or ns.DB_DEFAULTS
		local previewActive = ns.barTestActive == true
		local rangedVisible = ns.rangedBar and (previewActive or ((ns.rangedBar.GetAlpha and ns.rangedBar:GetAlpha()) or 0) > 0)
		if not helperBar or ns.playerClass ~= "HUNTER" or db.showHunterRangeHelper == false or (ns.IsMinimalMode and ns.IsMinimalMode()) or not rangedVisible then
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
	ns.UpdateHunterRangeHelperColor = function(rangeState)
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
	ns.OnMeleeSwing = function(slot)
		if slot == "mh" and ns.mhBar then
			ns.hunterQueuedMeleeSpell = nil
			RestoreMainHandColor()
		end
	end

	ns.ClearHunterQueueTint = function()
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
		ns.RegisterSpellcastSucceededHook(function(unit, castGUIDOrSpellName, spellId)
			local spellToken = spellId ~= nil and spellId or castGUIDOrSpellName
			if unit == "player" and ns.HUNTER_RAPTOR_STRIKE_SPELLS and ns.HUNTER_RAPTOR_STRIKE_SPELLS[spellToken] then
				ApplyHunterQueueTint(spellToken)
			end
			if ns.UpdateHunterQueueTint then
				ns.UpdateHunterQueueTint(true)
			end
		end)
	end

	ns.OnBarsCreated = function()
		if not ns.rangedBar then
			return
		end

		if not ns.hunterRangeHelperBar then
			ns.hunterRangeHelperBar = EnsureVerticalHelperBar(
				"SuperSwingTimerHunterRangeHelperBar",
				ns.rangedBar,
				ns.GetHunterRangeHelperWidth and ns.GetHunterRangeHelperWidth() or 7,
				(ns.GetRangedBarTexture and ns.GetRangedBarTexture()) or (ns.GetBarTexture and ns.GetBarTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
			)
		end

		UpdateHunterRangeHelperVisual()
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
		if not changed then
			changed = cache.texture ~= texture
				or cache.width ~= width
				or cache.height ~= height
				or cache.r ~= r
				or cache.g ~= g
				or cache.b ~= b
				or cache.a ~= a
				or cache.anchor ~= ns.rangedBar
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
			anchor = ns.rangedBar,
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

	ns.ForceHunterRapidFireRefresh = function()
		rapidFireTimer = rapidFireUpdateInterval
		if ns.UpdateHunterRapidFire then
			ns.UpdateHunterRapidFire(rapidFireUpdateInterval, true)
		end
	end

	ns.UpdateHunterRapidFire = function(elapsed, force)
		if not ns.rangedBar then return end
		local db = SuperSwingTimerDB or ns.DB_DEFAULTS
		if not db or db.showHunterRapidFireBar == false then
			if rapidFireBar then rapidFireBar:Hide() end
			return
		end
		-- Create lazily
	if not rapidFireBar then
		rapidFireBar = CreateFrame("StatusBar", nil, ns.rangedBar)
		rapidFireBar:SetSize((ns.rangedBar and ns.rangedBar:GetWidth()) or ns.BAR_WIDTH or 240, ns.HUNTER_RAPID_FIRE_BAR_HEIGHT or 4)
		rapidFireBar:SetPoint("BOTTOM", ns.rangedBar, "TOP", 0, 2)
			rapidFireBar:SetStatusBarTexture(ns.GetBarTexture and ns.GetBarTexture() or "Interface\\TargetingFrame\\UI-StatusBar")
			local rfColor = ns.GetBarColor and ns.GetBarColor("rapidFireBar") or { r = 0.10, g = 0.80, b = 0.30, a = 0.85 }
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

			local duration = (type(auraDuration) == "number" and auraDuration > 0) and auraDuration or RAPID_FIRE_DURATION
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
		cue:SetColorTexture(
			color.r or 1,
			color.g or 0,
			color.b or 0,
			alpha
		)
	end

	local function ApplyRogueEnergyTickColor()
		local tickBar = ns.rogueEnergyTickBar
		if tickBar then
			local tickColor = GetRogueEnergyTickColor()
			tickBar:SetStatusBarColor(
				tickColor.r or 1,
				tickColor.g or 0.82,
				tickColor.b or 0.18,
				tickColor.a ~= nil and tickColor.a or 1
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
		sndBar:SetStatusBarColor(
			color.r or 0.95,
			color.g or 0.82,
			color.b or 0.22,
			color.a ~= nil and color.a or 0.95
		)
	end

	local BLADE_FLURRY_SPELL_ID = 13877
	local BLADE_FLURRY_NAME = ns.GetSpellInfo and (ns.GetSpellInfo(BLADE_FLURRY_SPELL_ID) or "Blade Flurry") or "Blade Flurry"
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
		local backgroundColor = ns.GetBarBackgroundColor and ns.GetBarBackgroundColor() or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBackgroundColor)
		backgroundColor = backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
		backgroundTexture:SetColorTexture(backgroundColor.r or 0, backgroundColor.g or 0, backgroundColor.b or 0, 1)
		backgroundTexture:SetAlpha(backgroundColor.a ~= nil and backgroundColor.a or 0.5)

		if not bar.borderTextures then
			local borderColor = ns.GetBarBorderColor and ns.GetBarBorderColor() or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBorderColor)
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

			bar.borderTextures = {
				top = borderTop,
				bottom = borderBottom,
				left = borderLeft,
				right = borderRight,
			}
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
			if not ns.rogueSliceAndDiceNextRefreshAt or now >= ns.rogueSliceAndDiceNextRefreshAt or not ns.rogueSliceAndDiceExpirationTime then
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

	ns.OnBarsCreated = function()
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
			ns.rogueEnergyTickBar = EnsureRogueVerticalHelperBar("SuperSwingTimerRogueEnergyTickBar", ROGUE_ENERGY_TICK_BAR_WIDTH)
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
			sndBar:SetStatusBarTexture(ns.GetBarTexture and ns.GetBarTexture() or "Interface\\TargetingFrame\\UI-StatusBar")
			sndBar:SetSize(
				(ns.mhBar and ns.mhBar:GetWidth()) or ns.BAR_WIDTH or 240,
				ns.ROGUE_SLICE_AND_DICE_BAR_HEIGHT or 4
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
			local backgroundColor = ns.GetBarBackgroundColor and ns.GetBarBackgroundColor() or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBackgroundColor)
			backgroundColor = backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
			backgroundTexture:SetColorTexture(backgroundColor.r or 0, backgroundColor.g or 0, backgroundColor.b or 0, 1)
			backgroundTexture:SetAlpha(backgroundColor.a ~= nil and backgroundColor.a or 0.5)

			if not sndBar.borderTextures then
				local borderColor = ns.GetBarBorderColor and ns.GetBarBorderColor() or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBorderColor)
				borderColor = borderColor or { r = 0, g = 0, b = 0, a = 1 }
				local borderTop = sndBar:CreateTexture(nil, "OVERLAY")
				borderTop:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
				borderTop:SetPoint("TOPLEFT", -1, 1)
				borderTop:SetPoint("TOPRIGHT", 1, 1)
				borderTop:SetHeight(1)

				local borderBottom = sndBar:CreateTexture(nil, "OVERLAY")
				borderBottom:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
				borderBottom:SetPoint("BOTTOMLEFT", -1, -1)
				borderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
				borderBottom:SetHeight(1)

				local borderLeft = sndBar:CreateTexture(nil, "OVERLAY")
				borderLeft:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
				borderLeft:SetPoint("TOPLEFT", -1, 1)
				borderLeft:SetPoint("BOTTOMLEFT", -1, -1)
				borderLeft:SetWidth(1)

				local borderRight = sndBar:CreateTexture(nil, "OVERLAY")
				borderRight:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
				borderRight:SetPoint("TOPRIGHT", 1, 1)
				borderRight:SetPoint("BOTTOMRIGHT", 1, -1)
				borderRight:SetWidth(1)

				sndBar.borderTextures = {
					top = borderTop,
					bottom = borderBottom,
					left = borderLeft,
					right = borderRight,
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

		local origOnUpdate = ns.OnUpdate or function() end
		ns.OnUpdate = function(elapsed)
			origOnUpdate(elapsed)
			UpdateRogueSinisterAssistVisual()
			UpdateRogueEnergyTickVisual()
			UpdateRogueSliceAndDiceVisual()
			UpdateRogueBladeFlurryBadge()
			UpdateRogueColdBloodBadge()
		end
	end

	-- Phase 2: Rogue Adrenaline Rush CD + duration bar
	local ADRENALINE_RUSH_SPELL_ID = ns.ROGUE_ADRENALINE_RUSH_ID or 13750
	local ADRENALINE_RUSH_NAME = ns.ROGUE_ADRENALINE_RUSH_NAME or (ns.GetSpellInfo and ns.GetSpellInfo(ADRENALINE_RUSH_SPELL_ID)) or "Adrenaline Rush"
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

	ns.ForceRogueAdrenalineRushRefresh = function()
		adrenalineRushTimer = ADRENALINE_RUSH_REFRESH_INTERVAL
		if ns.UpdateRogueAdrenalineRush then
			ns.UpdateRogueAdrenalineRush(ADRENALINE_RUSH_REFRESH_INTERVAL)
		end
	end

	ns.UpdateRogueAdrenalineRush = function(elapsed)
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
			adrenalineRushBar:SetStatusBarTexture(ns.GetBarTexture and ns.GetBarTexture() or "Interface\\TargetingFrame\\UI-StatusBar")
			local arColor = ns.GetBarColor and ns.GetBarColor("adrenalineRushBar") or { r = 1.0, g = 0.30, b = 0.30, a = 0.85 }
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
end

-- ============================================================
-- Dispatch: pick class mods for the current class
-- ============================================================
-- Dispatch: pick class mods for the current class
-- ============================================================
function ns.InitClassMods()
	ns.OnBarsCreated = nil
	ns.OnDruidFormChange = nil
	ns.OnMeleeSwing = nil
	ns.OnRangedSwing = nil
	ns.UpdateWarriorQueueTint = nil
	ns.ClearWarriorQueueTint = nil
	ns.UpdateWarriorRageBar = nil
	ns.UpdateWarriorShieldBlockBar = nil
	ns.UpdateDruidQueueTint = nil
	ns.ClearDruidQueueTint = nil
	ns.IsDruidCatFormActive = nil
	ns.UpdateDruidEnergyTickColor = nil
	ns.UpdateDruidEnergyTickVisual = nil
	ns.HandleDruidEnergyPowerUpdate = nil
	ns.UpdateDruidRavageCue = nil
	ns.UpdateDruidMangleTimer = nil
	ns.UpdateDruidRipTracker = nil
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
	ns.UpdateShamanFlameShockBar = nil
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