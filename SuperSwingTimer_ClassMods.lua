local addonName, ns = ...
local UnitAura = rawget(_G, "UnitAura")
local GetTimePreciseSec = rawget(_G, "GetTimePreciseSec")
local GetTime = rawget(_G, "GetTime")
local GetSpellCooldown = rawget(_G, "GetSpellCooldown")
local GCD_SPELL_ID = 61304 -- Spell ID used to query the GCD for seal twist timing.

local function GetCurrentTime()
	if GetTimePreciseSec then
		return GetTimePreciseSec() + (ns.cachedLatency or 0)
	end

	return GetTime() + (ns.cachedLatency or 0)
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
		local swingRemaining = (timer.lastSwing + timer.duration) - now
		if swingRemaining < 0 then
			swingRemaining = 0
		end

		local swingElapsed = timer.duration - swingRemaining
		if swingElapsed < 0 then
			swingElapsed = 0
		end

		-- Query GCD in seconds and handle API failures gracefully. The GCD is used as a proxy for the seal twist window, which is generally accurate but may not be perfect in all cases (e.g. if the player has a haste effect that reduces GCD but not swing timer).
		-- We also add latency to the current time when calculating the GCD remaining, to help compensate for latency in the spellcast that triggers the seal twist.
		local gcdStart, gcdDuration
		if GetSpellCooldown then
			gcdStart, gcdDuration = GetSpellCooldown(GCD_SPELL_ID)
		end
		if type(gcdStart) ~= "number" or type(gcdDuration) ~= "number" or gcdDuration <= 0 then
			sealEndLine:Hide()
			if sealResealLine then
				sealResealLine:Hide()
			end
			return
		end

		local gcdRemaining = (gcdStart + gcdDuration) - now
		if gcdRemaining <= 0 then
			sealEndLine:Hide()
			if sealResealLine then
				sealResealLine:Hide()
			end
			return
		end

		local gcdTick = (swingElapsed + gcdRemaining) / timer.duration
		if gcdTick > 1 then
			gcdTick = gcdTick - 1
		end
		if gcdTick < 0 then
			gcdTick = 0
		end

		local width = math.min(2, barWidth)
		local lineX = math.max(math.min((barWidth * gcdTick) - (width * 0.5), barWidth - width), 0)

		local barAnchor = GetOverlayParent(ns.mhBar)
		sealEndLine:ClearAllPoints()
		sealEndLine:SetPoint("TOPLEFT", barAnchor, "LEFT", lineX, 0)
		sealEndLine:SetPoint("BOTTOMLEFT", barAnchor, "LEFT", lineX, 0)
		sealEndLine:SetWidth(width)
		sealEndLine:Show()
		if sealResealLine then
			sealResealLine:Hide()
		end
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
			sealEndLine:SetWidth(5)
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
			sealResealLine:SetWidth(5)
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
	-- Slam pending indicator: yellow bar tint while the MH timer
	-- resets and starts fresh. Restores to base color on next swing.
	ns.OnMeleeSwing = function(slot)
		if slot == "mh" and ns.mhBar then
			local c = ns.mhBarBaseColor
			if c then
				ns.mhBar:SetStatusBarColor(c.r, c.g, c.b, c.a)
			else
				ns.mhBar:SetStatusBarColor(0, 0, 0, 1)
			end
		end
	end

	-- Hook slam cast to show yellow tint
	local origHandleSpellcast = ns.HandleSpellcastSucceeded
	ns.HandleSpellcastSucceeded = function(unit, castGUID, spellId)
		if unit == "player" and ns.PAUSE_SWING_SPELLS and ns.PAUSE_SWING_SPELLS[spellId] and ns.mhBar then
			ns.mhBar:SetStatusBarColor(0.8, 0.8, 0.1, 1)  -- yellow during pause/extend cast
		end
		origHandleSpellcast(unit, castGUID, spellId)
	end
end

local function SetupEnhShaman()
	local function UpdateWeaveVisuals()
		if not ns.weaveSpark or not ns.weaveTriangleTop or not ns.weaveTriangleBottom then
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

		local castWindow = math.max((info.castRemaining or info.castTime or 0) + (info.latency or 0), 0)
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
		local triangleGap = ns.GetWeaveTriangleGap and ns.GetWeaveTriangleGap() or 2
		local triangleSize = ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14
		local sparkWidth = ns.GetWeaveSparkWidth and ns.GetWeaveSparkWidth() or 14
		local sparkHeight = ns.GetWeaveSparkHeight and ns.GetWeaveSparkHeight() or 30
		local sparkAlpha = ns.GetWeaveSparkAlpha and ns.GetWeaveSparkAlpha() or 0.95
		local triangleAlpha = ns.GetWeaveTriangleAlpha and ns.GetWeaveTriangleAlpha() or 1

		ns.weaveSpark:ClearAllPoints()
		ns.weaveSpark:SetPoint("CENTER", barAnchor, "LEFT", sparkPos, 0)
		ns.weaveSpark:SetWidth(sparkWidth)
		ns.weaveSpark:SetHeight(sparkHeight)
		ns.weaveSpark:SetVertexColor(color.r, color.g, color.b, sparkAlpha)
		if showSpark then
			ns.weaveSpark:Show()
		else
			ns.weaveSpark:Hide()
		end

		ns.weaveTriangleTop:ClearAllPoints()
		ns.weaveTriangleTop:SetPoint("BOTTOM", barAnchor, "TOP", markerPos, triangleGap)
		ns.weaveTriangleTop:SetWidth(triangleSize)
		ns.weaveTriangleTop:SetHeight(triangleSize)
		ns.weaveTriangleTop:SetVertexColor(color.r, color.g, color.b, triangleAlpha)
		ns.weaveTriangleTop:Show()

		ns.weaveTriangleBottom:ClearAllPoints()
		ns.weaveTriangleBottom:SetPoint("TOP", barAnchor, "BOTTOM", markerPos, -triangleGap)
		ns.weaveTriangleBottom:SetWidth(triangleSize)
		ns.weaveTriangleBottom:SetHeight(triangleSize)
		ns.weaveTriangleBottom:SetVertexColor(color.r, color.g, color.b, triangleAlpha)
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
		weaveSpark:SetHeight(ns.GetWeaveSparkHeight and ns.GetWeaveSparkHeight() or 30)
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

-- ============================================================
-- Dispatch: pick class mods for the current class
-- ============================================================
function ns.InitClassMods()
	local class = ns.playerClass
	if class == "PALADIN" then
		SetupRetPaladin()
	elseif class == "WARRIOR" then
		SetupWarrior()
	elseif class == "SHAMAN" then
		SetupEnhShaman()
	elseif class == "DRUID" then
		SetupDruid()
	end
	-- HUNTER, ROGUE: no special overlays beyond dual bars
	-- Pure casters: no bars created, no mods needed
end

