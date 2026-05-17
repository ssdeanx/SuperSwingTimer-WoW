local _, ns = ...
---@diagnostic disable: undefined-field
local CreateFrame = rawget(_G, "CreateFrame")
local UIParent = rawget(_G, "UIParent")
local UnitAura = rawget(_G, "UnitAura")
local UnitPower = rawget(_G, "UnitPower")
local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local GetTime = rawget(_G, "GetTime")
local GetSpellCooldown = rawget(_G, "GetSpellCooldown")
local GCD_SPELL_ID = 61304 -- Spell ID used to query the GCD for seal twist timing.
local WARRIOR_HEROIC_STRIKE_TINT = { r = 1.0, g = 0.92, b = 0.20 }
local WARRIOR_CLEAVE_TINT = { r = 0.20, g = 0.80, b = 0.25 }
local DRUID_MAUL_TINT = { r = 1.0, g = 0.78, b = 0.10 }
local HUNTER_RAPTOR_TINT = { r = 0.55, g = 1.00, b = 0.55 }

local function GetCurrentTime()
	if ns.GetAlignedTime then
		return ns.GetAlignedTime()
	end
	if GetTimePreciseSec then
		return GetTimePreciseSec()
	end

	return GetTime()
end

local function GetOverlayParent(bar)
	if ns.GetOverlayFrame then
		return ns.GetOverlayFrame(bar)
	end
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
			local auraName, _, _, _, _, _, _, _, _, auraSpellId = UnitAura("player", index, "HELPFUL")
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

	local function UpdateSealBreakpointLine()
		local sealEndLine = ns.sealTwistBreakpoint
		local sealResealLine = ns.sealTwistResealBreakpoint
		if not sealEndLine or not ns.mhBar then
			return
		end

		local timer = ns.timers and ns.timers.mh
		if not timer or timer.state ~= "swinging" or not timer.duration or timer.duration <= 0 then
			sealEndLine:Hide()
			if sealResealLine then
				sealResealLine:Hide()
			end
			return
		end

		local activeFamily = GetActivePaladinSeal()
		if not activeFamily or not ns.PALADIN_SEAL_TWIST_FAMILIES or not ns.PALADIN_SEAL_TWIST_FAMILIES[activeFamily] then
			sealEndLine:Hide()
			if sealResealLine then
				sealResealLine:Hide()
			end
			return
		end

		local barWidth = (ns.mhBar and ns.mhBar:GetWidth()) or (ns.mhBar and ns.mhBar.barWidth) or ns.BAR_WIDTH or 0
		if barWidth <= 0 then
			sealEndLine:Hide()
			if sealResealLine then
				sealResealLine:Hide()
			end
			return
		end

		local now = GetCurrentTime()

		local width = math.min(2, barWidth)
		local endLineX = math.max(barWidth - width, 0)

		local barAnchor = GetOverlayParent(ns.mhBar)
		sealEndLine:ClearAllPoints()
		sealEndLine:SetPoint("TOPLEFT", barAnchor, "LEFT", endLineX, 0)
		sealEndLine:SetPoint("BOTTOMLEFT", barAnchor, "LEFT", endLineX, 0)
		sealEndLine:SetWidth(width)
		sealEndLine:Show()

		if not sealResealLine then
			return
		end

		local gcdStart, gcdDuration
		if GetSpellCooldown then
			gcdStart, gcdDuration = GetSpellCooldown(GCD_SPELL_ID)
		end
		if type(gcdStart) ~= "number" or type(gcdDuration) ~= "number" or gcdDuration <= 0 then
			sealResealLine:Hide()
			return
		end

		local gcdRemaining = (gcdStart + gcdDuration) - now
		if gcdRemaining <= 0 then
			sealResealLine:Hide()
			return
		end

		local swingElapsed = math.max(0, now - (timer.lastSwing or now))
		local resealTick = (swingElapsed + gcdRemaining) / timer.duration
		while resealTick > 1 do
			resealTick = resealTick - 1
		end
		if resealTick < 0 then
			resealTick = 0
		elseif resealTick > 1 then
			resealTick = 1
		end
		local resealX = math.max(math.min((barWidth * resealTick) - (width * 0.5), barWidth - width), 0)

		sealResealLine:ClearAllPoints()
		sealResealLine:SetPoint("TOPLEFT", barAnchor, "LEFT", resealX, 0)
		sealResealLine:SetPoint("BOTTOMLEFT", barAnchor, "LEFT", resealX, 0)
		sealResealLine:SetWidth(width)
		sealResealLine:Show()
	end

	-- Seal breakpoint lines: end-of-swing twist marker plus optional reseal marker.
	ns.OnBarsCreated = function()
		if not ns.mhBar then return end
		if not ns.sealTwistBreakpoint then
			local barParent = GetOverlayParent(ns.mhBar)
			local sealEndLine = barParent:CreateTexture(nil, "OVERLAY")
			sealEndLine:SetColorTexture(0, 0, 0, 1)
			sealEndLine:SetPoint("TOPLEFT", barParent, "LEFT", 0, 0)
			sealEndLine:SetPoint("BOTTOMLEFT", barParent, "LEFT", 0, 0)
			sealEndLine:SetWidth(2)
			if ns.SetTextureLayerAboveBar then
				ns.SetTextureLayerAboveBar(sealEndLine, ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY", ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK")
			end
			sealEndLine:Hide()
			ns.sealTwistBreakpoint = sealEndLine
			ns.sealTwistZone = sealEndLine
		end

		if not ns.sealTwistResealBreakpoint then
			local barParent = GetOverlayParent(ns.mhBar)
			local sealResealLine = barParent:CreateTexture(nil, "OVERLAY")
			sealResealLine:SetColorTexture(0, 0, 0, 1)
			sealResealLine:SetPoint("TOPLEFT", barParent, "LEFT", 0, 0)
			sealResealLine:SetPoint("BOTTOMLEFT", barParent, "LEFT", 0, 0)
			sealResealLine:SetWidth(2)
			if ns.SetTextureLayerAboveBar then
				ns.SetTextureLayerAboveBar(sealResealLine, ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY", ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK")
			end
			sealResealLine:Hide()
			ns.sealTwistResealBreakpoint = sealResealLine
			ns.sealTwistResealZone = sealResealLine
		end

		local origOnUpdate = ns.OnUpdate
		ns.OnUpdate = function(elapsed)
			origOnUpdate(elapsed)
			UpdateSealBreakpointLine()
		end
		UpdateSealBreakpointLine()
	end
end

local function SetupWarrior()
	local IsCurrentSpell = rawget(_G, "IsCurrentSpell")
	if not IsCurrentSpell then
		local C_Spell = rawget(_G, "C_Spell")
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

	-- Hook warrior queued attacks so each special gets its own tint.
	local origHandleSpellcast = ns.HandleSpellcastSucceeded
	ns.HandleSpellcastSucceeded = function(unit, castGUIDOrSpellName, spellId)
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
		if origHandleSpellcast then
			origHandleSpellcast(unit, castGUIDOrSpellName, spellId)
		end
		if ns.UpdateWarriorQueueTint then
			ns.UpdateWarriorQueueTint()
		end
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

	local function UpdateWeaveVisuals()
		if not ns.weaveSpark or not ns.weaveTriangleTop or not ns.weaveTriangleBottom then
			return
		end

		local db = SuperSwingTimerDB or ns.DB_DEFAULTS
		if (db and db.showWeaveAssist == false) or (ns.IsMinimalMode and ns.IsMinimalMode()) then
			ns.weaveSpark:Hide()
			ns.weaveTriangleTop:Hide()
			ns.weaveTriangleBottom:Hide()
			return
		end

		local info = ns.GetWeaveDisplayInfo and ns.GetWeaveDisplayInfo() or nil
		if not info then
			ns.weaveSpark:Hide()
			ns.weaveTriangleTop:Hide()
			ns.weaveTriangleBottom:Hide()
			return
		end

		local timer = ns.timers and ns.timers.mh
		if not timer or timer.state ~= "swinging" or not timer.duration or timer.duration <= 0 then
			ns.weaveSpark:Hide()
			ns.weaveTriangleTop:Hide()
			ns.weaveTriangleBottom:Hide()
			return
		end

		local showSpark = info.isCasting == true
		local barWidth = (ns.mhBar and ns.mhBar:GetWidth()) or (ns.mhBar and ns.mhBar.barWidth) or ns.BAR_WIDTH or 0
		local barAnchor = GetOverlayParent(ns.mhBar)

		local castWindow = math.max((info.castTime or 0) + (info.latency or 0), 0)
		local markerPos = ((timer.duration - castWindow) / timer.duration) * barWidth
		if markerPos < 0 then
			markerPos = 0
		elseif markerPos > (barWidth or markerPos) then
			markerPos = barWidth
		end

		local castTime = math.max(info.castTime or 0, 0)
		local castRemaining = math.max(info.castRemaining or castTime, 0)
		local castElapsed = math.max(0, castTime - castRemaining)
		local sparkPos = castTime > 0 and ((castElapsed / castTime) * barWidth) or 0
		if sparkPos < 0 then
			sparkPos = 0
		elseif sparkPos > (barWidth or sparkPos) then
			sparkPos = barWidth
		end

		local color = info.color or { r = 0.7, g = 0.8, b = 1, a = 1 }
		local iconTexture = info.iconTexture
		local triangleGap = ns.GetWeaveTriangleGap and ns.GetWeaveTriangleGap() or 2
		local triangleSize = ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14
		local topFallbackTexture = ns.GetWeaveTriangleTopTexture and ns.GetWeaveTriangleTopTexture() or "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow"
		local bottomFallbackTexture = ns.GetWeaveTriangleBottomTexture and ns.GetWeaveTriangleBottomTexture() or "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow"
		local sparkWidth = ns.GetWeaveSparkWidth and ns.GetWeaveSparkWidth() or 14
		local sparkHeight = ns.GetWeaveSparkHeight and ns.GetWeaveSparkHeight() or 30
		local clampedSparkHeight = math.max(1, math.min(sparkHeight, (ns.mhBar and ns.mhBar:GetHeight()) or ns.BAR_HEIGHT or sparkHeight))
		local sparkAlpha = ns.GetWeaveSparkAlpha and ns.GetWeaveSparkAlpha() or 0.95
		local triangleAlpha = ns.GetWeaveTriangleAlpha and ns.GetWeaveTriangleAlpha() or 1

		ns.weaveSpark:ClearAllPoints()
		ns.weaveSpark:SetPoint("CENTER", barAnchor, "LEFT", sparkPos, 0)
		ns.weaveSpark:SetWidth(sparkWidth)
		ns.weaveSpark:SetHeight(clampedSparkHeight)
		ns.weaveSpark:SetVertexColor(color.r, color.g, color.b, sparkAlpha)
		if showSpark then
			ns.weaveSpark:Show()
		else
			ns.weaveSpark:Hide()
		end

		ns.weaveTriangleTop:ClearAllPoints()
		ns.weaveTriangleTop:SetPoint("BOTTOM", barAnchor, "TOP", markerPos, triangleGap)
		ApplyWeaveMarkerTexture(ns.weaveTriangleTop, iconTexture, topFallbackTexture, triangleSize, triangleAlpha, color)
		ns.weaveTriangleTop:Show()

		ns.weaveTriangleBottom:ClearAllPoints()
		ns.weaveTriangleBottom:SetPoint("TOP", barAnchor, "BOTTOM", markerPos, -triangleGap)
		ApplyWeaveMarkerTexture(ns.weaveTriangleBottom, iconTexture, bottomFallbackTexture, triangleSize, triangleAlpha, color)
		ns.weaveTriangleBottom:Show()
		if ns.weaveMarker then
			ns.weaveMarker:SetShown(showSpark)
		end
	end

	ns.OnBarsCreated = function()
		if not ns.mhBar then
			return
		end
		if ns.weaveSpark and ns.weaveTriangleTop and ns.weaveTriangleBottom then
			return
		end

		local barParent = GetOverlayParent(ns.mhBar)
		local weaveSpark = barParent:CreateTexture(nil, "OVERLAY")
		weaveSpark:SetTexture(ns.GetWeaveSparkTexture and ns.GetWeaveSparkTexture() or "Interface\\CastingBar\\UI-CastingBar-Spark")
		if ns.SetTextureLayerAboveBar then
			ns.SetTextureLayerAboveBar(weaveSpark, ns.GetWeaveSparkLayer and ns.GetWeaveSparkLayer() or "OVERLAY", ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK")
		else
			weaveSpark:SetDrawLayer(ns.GetWeaveSparkLayer and ns.GetWeaveSparkLayer() or "OVERLAY")
		end
		weaveSpark:SetBlendMode(ns.GetIndicatorBlendMode and ns.GetIndicatorBlendMode() or "ADD")
		weaveSpark:SetAlpha(ns.GetWeaveSparkAlpha and ns.GetWeaveSparkAlpha() or 0.95)
		weaveSpark:SetWidth(ns.GetWeaveSparkWidth and ns.GetWeaveSparkWidth() or 14)
		weaveSpark:SetHeight(math.max(1, math.min((ns.GetWeaveSparkHeight and ns.GetWeaveSparkHeight() or 30), (ns.mhBar and ns.mhBar:GetHeight()) or (ns.BAR_HEIGHT or 30))))
		weaveSpark:SetPoint("CENTER", barParent, "LEFT", 0, 0)

		local weaveTriangleTop = barParent:CreateTexture(nil, "OVERLAY")
		weaveTriangleTop:SetTexture(ns.GetWeaveTriangleTopTexture and ns.GetWeaveTriangleTopTexture() or "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow")
		if ns.SetTextureLayerAboveBar then
			ns.SetTextureLayerAboveBar(weaveTriangleTop, ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY", ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK")
		else
			weaveTriangleTop:SetDrawLayer(ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY")
		end
		weaveTriangleTop:SetBlendMode(ns.GetIndicatorBlendMode and ns.GetIndicatorBlendMode() or "ADD")
		weaveTriangleTop:SetAlpha(ns.GetWeaveTriangleAlpha and ns.GetWeaveTriangleAlpha() or 1)
		weaveTriangleTop:SetWidth(ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14)
		weaveTriangleTop:SetHeight(ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14)

		local weaveTriangleBottom = barParent:CreateTexture(nil, "OVERLAY")
		weaveTriangleBottom:SetTexture(ns.GetWeaveTriangleBottomTexture and ns.GetWeaveTriangleBottomTexture() or "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow")
		if ns.SetTextureLayerAboveBar then
			ns.SetTextureLayerAboveBar(weaveTriangleBottom, ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY", ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK")
		else
			weaveTriangleBottom:SetDrawLayer(ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY")
		end
		weaveTriangleBottom:SetBlendMode(ns.GetIndicatorBlendMode and ns.GetIndicatorBlendMode() or "ADD")
		weaveTriangleBottom:SetAlpha(ns.GetWeaveTriangleAlpha and ns.GetWeaveTriangleAlpha() or 1)
		weaveTriangleBottom:SetWidth(ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14)
		weaveTriangleBottom:SetHeight(ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14)

		weaveSpark:Hide()
		weaveTriangleTop:Hide()
		weaveTriangleBottom:Hide()

		ns.weaveSpark = weaveSpark
		ns.weaveTriangleTop = weaveTriangleTop
		ns.weaveTriangleBottom = weaveTriangleBottom
		ns.weaveMarker = weaveSpark
	end

	local origOnUpdate = ns.OnUpdate or function() end
	ns.OnUpdate = function(elapsed)
		origOnUpdate(elapsed)
		UpdateWeaveVisuals()
	end
end

local function SetupDruid()
	local IsCurrentSpell = rawget(_G, "IsCurrentSpell")
	if not IsCurrentSpell then
		local C_Spell = rawget(_G, "C_Spell")
		if C_Spell and C_Spell.IsCurrentSpell then
			IsCurrentSpell = C_Spell.IsCurrentSpell
		end
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

	-- Hook druid queued attacks (Maul)
	local origHandleSpellcast = ns.HandleSpellcastSucceeded
	ns.HandleSpellcastSucceeded = function(unit, castGUIDOrSpellName, spellId)
		local spellToken = spellId ~= nil and spellId or castGUIDOrSpellName
		if unit == "player" then
			if ns.DRUID_MAUL_SPELLS and ns.DRUID_MAUL_SPELLS[spellToken] then
				ApplyDruidQueueTint(spellToken)
			end
		end
		if origHandleSpellcast then
			origHandleSpellcast(unit, castGUIDOrSpellName, spellId)
		end
		if ns.UpdateDruidQueueTint then
			ns.UpdateDruidQueueTint()
		end
	end

	-- Show current form in the MH bar label.
	ns.OnDruidFormChange = function(formSpellId)
		if not ns.mhBar then return end
		local label
		if formSpellId == 0 then
			label = "Caster"
		else
			label = ns.DRUID_FORM_IDS[formSpellId] or "Melee"
		end
		ns.mhBar.labelText:SetText(label)
	end

	ns.OnBarsCreated = function()
		-- Set initial label from current shapeshift form
		local getShapeshiftForm = rawget(_G, "GetShapeshiftForm")
		local form = (getShapeshiftForm and getShapeshiftForm()) or 0
		if form == 0 and ns.mhBar then
			ns.mhBar.labelText:SetText("Caster")
		end
	end
end

local function SetupHunter()
	local IsCurrentSpell = rawget(_G, "IsCurrentSpell")
	if not IsCurrentSpell then
		local C_Spell = rawget(_G, "C_Spell")
		if C_Spell and C_Spell.IsCurrentSpell then
			IsCurrentSpell = C_Spell.IsCurrentSpell
		end
	end

	local function FindCurrentQueuedSpell(spellSet)
		if not IsCurrentSpell or not spellSet then
			return nil
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

	local function UpdateHunterQueueTint()
		if ns.playerClass ~= "HUNTER" or not ns.mhBar then
			return
		end

		local alpha = (ns.mhBarBaseColor and ns.mhBarBaseColor.a) or 1
		local queuedSpellId = FindCurrentQueuedSpell(ns.HUNTER_RAPTOR_STRIKE_SPELLS)
		if queuedSpellId then
			ns.hunterQueuedMeleeSpell = queuedSpellId
			ns.mhBar:SetStatusBarColor(HUNTER_RAPTOR_TINT.r, HUNTER_RAPTOR_TINT.g, HUNTER_RAPTOR_TINT.b, alpha)
			return
		end

		if ns.hunterQueuedMeleeSpell then
			ns.hunterQueuedMeleeSpell = nil
			RestoreMainHandColor()
		end
	end

	ns.UpdateHunterQueueTint = UpdateHunterQueueTint

	local function ApplyHunterQueueTint(spellValue)
		if not ns.mhBar then
			return
		end

		local alpha = (ns.mhBarBaseColor and ns.mhBarBaseColor.a) or 1
		if ns.HUNTER_RAPTOR_STRIKE_SPELLS and ns.HUNTER_RAPTOR_STRIKE_SPELLS[spellValue] then
			ns.hunterQueuedMeleeSpell = spellValue
			ns.mhBar:SetStatusBarColor(HUNTER_RAPTOR_TINT.r, HUNTER_RAPTOR_TINT.g, HUNTER_RAPTOR_TINT.b, alpha)
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
		ns.hunterQueuedMeleeSpell = nil
		RestoreMainHandColor()
	end

	-- Hook hunter queued attacks so Raptor Strike owns its own next-attack tint.
	local origHandleSpellcast = ns.HandleSpellcastSucceeded
	ns.HandleSpellcastSucceeded = function(unit, castGUIDOrSpellName, spellId)
		local spellToken = spellId ~= nil and spellId or castGUIDOrSpellName
		if unit == "player" then
			if ns.HUNTER_RAPTOR_STRIKE_SPELLS and ns.HUNTER_RAPTOR_STRIKE_SPELLS[spellToken] then
				ApplyHunterQueueTint(spellToken)
			end
		end
		if origHandleSpellcast then
			origHandleSpellcast(unit, castGUIDOrSpellName, spellId)
		end
		if ns.UpdateHunterQueueTint then
			ns.UpdateHunterQueueTint()
		end
	end
end

local function SetupRogue()
	local UnitAttackSpeed = rawget(_G, "UnitAttackSpeed")
	local DEFAULT_ROGUE_QUEUE_WINDOW = 0.08
	local ROGUE_QUEUE_INPUT_CUSHION = 0.03
	local MAX_ROGUE_QUEUE_WINDOW = 0.22
	local ROGUE_ENERGY_TICK_DURATION = 2.0
	local ROGUE_ENERGY_BAR_WIDTH = 5
	local ROGUE_ENERGY_BAR_GAP = 3

	local function GetRogueCueColor()
		return ns.GetBarColor and ns.GetBarColor("rogueSinister") or { r = 1, g = 0, b = 0, a = 0.45 }
	end

	local function GetRogueEnergyTickColor()
		return ns.GetBarColor and ns.GetBarColor("rogueEnergyTick") or { r = 1.0, g = 0.82, b = 0.18, a = 1 }
	end

	local function ApplyRogueCueColor()
		local cue = ns.rogueSinisterAssistZone
		if not cue then
			return
		end

		local color = GetRogueCueColor()
		cue:SetColorTexture(
			color.r or 1,
			color.g or 0,
			color.b or 0,
			color.a ~= nil and color.a or 0.45
		)
	end

	local function ApplyRogueEnergyTickColor()
		local energyBar = ns.rogueEnergyTickBar
		if not energyBar then
			return
		end

		local color = GetRogueEnergyTickColor()
		energyBar:SetStatusBarColor(
			color.r or 1,
			color.g or 0.82,
			color.b or 0.18,
			color.a ~= nil and color.a or 1
		)
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
		if ns.ohBar and ns.ohBar.GetAlpha and (ns.ohBar:GetAlpha() or 0) > 0 then
			return ns.ohBar
		end

		return ns.mhBar
	end

	local function GetRogueEnergyBarHeight(mhBar, anchorBottom)
		local totalHeight = (mhBar and mhBar:GetHeight()) or ns.BAR_HEIGHT or 15
		if anchorBottom and anchorBottom ~= mhBar then
			totalHeight = totalHeight + ((anchorBottom:GetHeight() or 0))
		end

		return math.max(1, totalHeight)
	end

	local function UpdateRogueEnergyTickVisual()
		local energyBar = ns.rogueEnergyTickBar
		local mhBar = ns.mhBar
		local db = SuperSwingTimerDB or ns.DB_DEFAULTS
		if not energyBar or not mhBar then
			return
		end

		if ns.playerClass ~= "ROGUE" or db.showRogueEnergyTick == false or (ns.IsMinimalMode and ns.IsMinimalMode()) then
			energyBar:SetAlpha(0)
			return
		end

		local previewActive = ns.barTestActive == true
		local mhVisible = mhBar.GetAlpha and (mhBar:GetAlpha() or 0) > 0
		if not previewActive and not mhVisible then
			energyBar:SetAlpha(0)
			return
		end

		local anchorBottom = GetRogueEnergyAnchorBar() or mhBar
		local energyHeight = GetRogueEnergyBarHeight(mhBar, anchorBottom)
		energyBar:ClearAllPoints()
		energyBar:SetPoint("TOPRIGHT", mhBar, "TOPLEFT", -ROGUE_ENERGY_BAR_GAP, 0)
		energyBar:SetWidth(ROGUE_ENERGY_BAR_WIDTH)
		energyBar:SetHeight(energyHeight)
		energyBar:SetMinMaxValues(0, 1)

		local now = GetCurrentTime()
		if not ns.rogueEnergyTickStartTime then
			ns.rogueEnergyTickStartTime = now
		end

		local elapsed = now - ns.rogueEnergyTickStartTime
		if elapsed < 0 then
			elapsed = 0
		end
		local progress = (elapsed % ROGUE_ENERGY_TICK_DURATION) / ROGUE_ENERGY_TICK_DURATION
		energyBar:SetValue(progress)
		ApplyRogueEnergyTickColor()
		energyBar:SetAlpha(1)
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
		local previewActive = ns.barTestActive == true
		local activeSwing = timer and timer.state == "swinging" and duration and duration > 0
		if not activeSwing then
			if not previewActive then
				cue:Hide()
				return
			end
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
		ApplyRogueCueColor()
		cue:Show()
	end

	ns.UpdateRogueSinisterAssistColor = ApplyRogueCueColor
	ns.UpdateRogueSinisterAssistVisual = UpdateRogueSinisterAssistVisual
	ns.UpdateRogueEnergyTickColor = ApplyRogueEnergyTickColor
	ns.UpdateRogueEnergyTickVisual = UpdateRogueEnergyTickVisual
	ns.HandleRogueEnergyPowerUpdate = HandleRogueEnergyPowerUpdate

	ns.OnBarsCreated = function()
		if not ns.mhBar then
			return
		end

		if not ns.rogueSinisterAssistZone then
			local barParent = GetOverlayParent(ns.mhBar)
			local cue = barParent:CreateTexture(nil, "ARTWORK")
			cue:SetColorTexture(1, 0, 0, 0.45)
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
			local energyBar = rawget(_G, "SuperSwingTimerRogueEnergyTickBar")
			if not energyBar then
				energyBar = CreateFrame("StatusBar", "SuperSwingTimerRogueEnergyTickBar", UIParent)
			end
			energyBar:SetStatusBarTexture(ns.GetBarTexture and ns.GetBarTexture() or "Interface\\TargetingFrame\\UI-StatusBar")
			if energyBar.SetOrientation then
				energyBar:SetOrientation("VERTICAL")
			end
			if energyBar.SetReverseFill then
				energyBar:SetReverseFill(true)
			end
			energyBar:SetSize(ROGUE_ENERGY_BAR_WIDTH, (ns.mhBar and ns.mhBar:GetHeight()) or ns.BAR_HEIGHT or 15)
			energyBar:SetMinMaxValues(0, 1)
			energyBar:SetValue(0)
			energyBar:SetFrameStrata(ns.mhBar:GetFrameStrata())
			energyBar:SetFrameLevel((ns.mhBar:GetFrameLevel() or 0) + 1)
			energyBar:EnableMouse(false)
			local statusBarTexture = energyBar:GetStatusBarTexture()
			if statusBarTexture then
				statusBarTexture:SetDrawLayer(ns.GetBarTextureLayer and ns.GetBarTextureLayer() or "ARTWORK")
			end

			local backgroundTexture = energyBar.backgroundTexture or energyBar:CreateTexture(nil, "BACKGROUND")
			backgroundTexture:SetAllPoints(true)
			local backgroundColor = ns.GetBarBackgroundColor and ns.GetBarBackgroundColor() or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBackgroundColor)
			backgroundColor = backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
			backgroundTexture:SetColorTexture(backgroundColor.r or 0, backgroundColor.g or 0, backgroundColor.b or 0, 1)
			backgroundTexture:SetAlpha(backgroundColor.a ~= nil and backgroundColor.a or 0.5)

			if not energyBar.borderTextures then
				local borderColor = ns.GetBarBorderColor and ns.GetBarBorderColor() or (ns.DB_DEFAULTS and ns.DB_DEFAULTS.barBorderColor)
				borderColor = borderColor or { r = 0, g = 0, b = 0, a = 1 }
				local borderTop = energyBar:CreateTexture(nil, "OVERLAY")
				borderTop:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
				borderTop:SetPoint("TOPLEFT", -1, 1)
				borderTop:SetPoint("TOPRIGHT", 1, 1)
				borderTop:SetHeight(1)

				local borderBottom = energyBar:CreateTexture(nil, "OVERLAY")
				borderBottom:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
				borderBottom:SetPoint("BOTTOMLEFT", -1, -1)
				borderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
				borderBottom:SetHeight(1)

				local borderLeft = energyBar:CreateTexture(nil, "OVERLAY")
				borderLeft:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
				borderLeft:SetPoint("TOPLEFT", -1, 1)
				borderLeft:SetPoint("BOTTOMLEFT", -1, -1)
				borderLeft:SetWidth(1)

				local borderRight = energyBar:CreateTexture(nil, "OVERLAY")
				borderRight:SetColorTexture(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
				borderRight:SetPoint("TOPRIGHT", 1, 1)
				borderRight:SetPoint("BOTTOMRIGHT", 1, -1)
				borderRight:SetWidth(1)

				energyBar.borderTextures = {
					top = borderTop,
					bottom = borderBottom,
					left = borderLeft,
					right = borderRight,
				}
			end

			energyBar.backgroundTexture = backgroundTexture
			energyBar.statusBarTexture = statusBarTexture
			energyBar:SetAlpha(0)
			ns.rogueEnergyTickBar = energyBar
		end

		ApplyRogueCueColor()
		if ns.ApplyRogueCueLayer then
			ns.ApplyRogueCueLayer()
		end
		ApplyRogueEnergyTickColor()
		ns.rogueLastEnergy = UnitPower and UnitPower("player") or ns.rogueLastEnergy
		if not ns.rogueEnergyTickStartTime then
			ns.rogueEnergyTickStartTime = GetCurrentTime()
		end

		local origOnUpdate = ns.OnUpdate or function() end
		ns.OnUpdate = function(elapsed)
			origOnUpdate(elapsed)
			UpdateRogueSinisterAssistVisual()
			UpdateRogueEnergyTickVisual()
		end

		UpdateRogueSinisterAssistVisual()
		UpdateRogueEnergyTickVisual()
	end
end

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
	ns.UpdateDruidQueueTint = nil
	ns.ClearDruidQueueTint = nil
	ns.UpdateHunterQueueTint = nil
	ns.ClearHunterQueueTint = nil
	ns.UpdateRogueSinisterAssistColor = nil
	ns.UpdateRogueSinisterAssistVisual = nil
	ns.UpdateRogueEnergyTickColor = nil
	ns.UpdateRogueEnergyTickVisual = nil
	ns.HandleRogueEnergyPowerUpdate = nil
	ns.warriorQueuedMeleeSpell = nil
	ns.druidQueuedMeleeSpell = nil
	ns.hunterQueuedMeleeSpell = nil
	ns.rogueLastEnergy = nil
	ns.rogueEnergyTickStartTime = nil
	if ns.rogueSinisterAssistZone then
		ns.rogueSinisterAssistZone:Hide()
	end
	if ns.rogueEnergyTickBar then
		ns.rogueEnergyTickBar:SetAlpha(0)
	end
	local class = ns.playerClass
	if class == "PALADIN" then
		SetupRetPaladin()
	elseif class == "WARRIOR" then
		SetupWarrior()
	elseif class == "ROGUE" then
		SetupRogue()
	elseif class == "HUNTER" then
		SetupHunter()
	elseif class == "SHAMAN" then
		SetupEnhShaman()
	elseif class == "DRUID" then
		SetupDruid()
	end
	-- Pure casters: no bars created, no mods needed
end

