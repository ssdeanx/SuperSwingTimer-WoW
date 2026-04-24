local addonName, ns = ...
local UnitAura = rawget(_G, "UnitAura")

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

		local barWidth = ns.mhBar.barWidth or ns.BAR_WIDTH or 0
		if barWidth <= 0 then
			sealEndLine:Hide()
			if sealResealLine then
				sealResealLine:Hide()
			end
			return
		end

		local sealTwistLead = 0.4 + (ns.cachedLatency or 0)
		local duration = timer.duration
		local width = math.min(5, barWidth)
		local offset = math.min((sealTwistLead / duration) * barWidth, barWidth)
		local endLineX = math.max(barWidth - width, 0)
		if endLineX < 0 then
			endLineX = 0
		elseif endLineX > (barWidth - width) then
			endLineX = math.max(barWidth - width, 0)
		end

		sealEndLine:ClearAllPoints()
		sealEndLine:SetPoint("TOPLEFT", ns.mhBar, "LEFT", endLineX, 0)
		sealEndLine:SetPoint("BOTTOMLEFT", ns.mhBar, "LEFT", endLineX, 0)
		sealEndLine:SetWidth(width)
		sealEndLine:Show()

		local activeFamily = GetActivePaladinSeal()
		if sealResealLine and activeFamily and ns.PALADIN_SEAL_TWIST_FAMILIES and ns.PALADIN_SEAL_TWIST_FAMILIES[activeFamily] then
			-- Twist seal active: show the reseal breakpoint earlier in the swing.
			local resealLineX = barWidth - offset - (width * 0.5)
			if resealLineX < 0 then
				resealLineX = 0
			elseif resealLineX > (barWidth - width) then
				resealLineX = math.max(barWidth - width, 0)
			end

			sealResealLine:ClearAllPoints()
			sealResealLine:SetPoint("TOPLEFT", ns.mhBar, "LEFT", resealLineX, 0)
			sealResealLine:SetPoint("BOTTOMLEFT", ns.mhBar, "LEFT", resealLineX, 0)
			sealResealLine:SetWidth(width)
			sealResealLine:Show()
		elseif sealResealLine then
			sealResealLine:Hide()
		end
	end

	-- Seal breakpoint lines: end-of-swing twist marker plus optional reseal marker.
	ns.OnBarsCreated = function()
		if not ns.mhBar then return end
		if not ns.sealTwistBreakpoint then
			local sealEndLine = ns.mhBar:CreateTexture(nil, "OVERLAY")
			sealEndLine:SetColorTexture(0, 0, 0, 1)
			sealEndLine:SetPoint("TOPLEFT", ns.mhBar, "LEFT", 0, 0)
			sealEndLine:SetPoint("BOTTOMLEFT", ns.mhBar, "LEFT", 0, 0)
			sealEndLine:SetWidth(5)
			sealEndLine:Hide()
			ns.sealTwistBreakpoint = sealEndLine
			ns.sealTwistZone = sealEndLine
		end

		if not ns.sealTwistResealBreakpoint then
			local sealResealLine = ns.mhBar:CreateTexture(nil, "OVERLAY")
			sealResealLine:SetColorTexture(0, 0, 0, 1)
			sealResealLine:SetPoint("TOPLEFT", ns.mhBar, "LEFT", 0, 0)
			sealResealLine:SetPoint("BOTTOMLEFT", ns.mhBar, "LEFT", 0, 0)
			sealResealLine:SetWidth(5)
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

		local castWindow = math.max((info.castRemaining or info.castTime or 0) + (info.latency or 0), 0)
		local markerPos = ((timer.duration - castWindow) / timer.duration) * (ns.BAR_WIDTH or 0)
		if markerPos < 0 then
			markerPos = 0
		elseif markerPos > (ns.BAR_WIDTH or markerPos) then
			markerPos = ns.BAR_WIDTH
		end

		local castTime = math.max(info.castTime or 0, 0)
		local castRemaining = math.max(info.castRemaining or castTime, 0)
		local castElapsed = math.max(0, castTime - castRemaining)
		local sparkPos = castTime > 0 and ((castElapsed / castTime) * (ns.BAR_WIDTH or 0)) or 0
		if sparkPos < 0 then
			sparkPos = 0
		elseif sparkPos > (ns.BAR_WIDTH or sparkPos) then
			sparkPos = ns.BAR_WIDTH
		end

		local color = info.color or { r = 0.7, g = 0.8, b = 1, a = 1 }
		local triangleGap = ns.GetWeaveTriangleGap and ns.GetWeaveTriangleGap() or 2
		local triangleSize = ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14
		local sparkWidth = ns.GetWeaveSparkWidth and ns.GetWeaveSparkWidth() or 14
		local sparkHeight = ns.GetWeaveSparkHeight and ns.GetWeaveSparkHeight() or 30
		local sparkAlpha = ns.GetWeaveSparkAlpha and ns.GetWeaveSparkAlpha() or 0.95
		local triangleAlpha = ns.GetWeaveTriangleAlpha and ns.GetWeaveTriangleAlpha() or 1

		ns.weaveSpark:ClearAllPoints()
		ns.weaveSpark:SetPoint("CENTER", ns.mhBar, "LEFT", sparkPos, 0)
		ns.weaveSpark:SetWidth(sparkWidth)
		ns.weaveSpark:SetHeight(sparkHeight)
		ns.weaveSpark:SetVertexColor(color.r, color.g, color.b, sparkAlpha)
		if showSpark then
			ns.weaveSpark:Show()
		else
			ns.weaveSpark:Hide()
		end

		ns.weaveTriangleTop:ClearAllPoints()
		ns.weaveTriangleTop:SetPoint("BOTTOM", ns.mhBar, "TOP", markerPos, triangleGap)
		ns.weaveTriangleTop:SetWidth(triangleSize)
		ns.weaveTriangleTop:SetHeight(triangleSize)
		ns.weaveTriangleTop:SetVertexColor(color.r, color.g, color.b, triangleAlpha)
		ns.weaveTriangleTop:Show()

		ns.weaveTriangleBottom:ClearAllPoints()
		ns.weaveTriangleBottom:SetPoint("TOP", ns.mhBar, "BOTTOM", markerPos, -triangleGap)
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

		local weaveSpark = ns.mhBar:CreateTexture(nil, "OVERLAY")
		weaveSpark:SetTexture(ns.GetWeaveSparkTexture and ns.GetWeaveSparkTexture() or "Interface\\CastingBar\\UI-CastingBar-Spark")
		weaveSpark:SetDrawLayer(ns.GetWeaveSparkLayer and ns.GetWeaveSparkLayer() or "OVERLAY")
		weaveSpark:SetBlendMode(ns.GetIndicatorBlendMode and ns.GetIndicatorBlendMode() or "ADD")
		weaveSpark:SetAlpha(ns.GetWeaveSparkAlpha and ns.GetWeaveSparkAlpha() or 0.95)
		weaveSpark:SetWidth(ns.GetWeaveSparkWidth and ns.GetWeaveSparkWidth() or 14)
		weaveSpark:SetHeight(ns.GetWeaveSparkHeight and ns.GetWeaveSparkHeight() or 30)
		weaveSpark:SetPoint("CENTER", ns.mhBar, "LEFT", 0, 0)

		local weaveTriangleTop = ns.mhBar:CreateTexture(nil, "OVERLAY")
		weaveTriangleTop:SetTexture(ns.GetWeaveTriangleTopTexture and ns.GetWeaveTriangleTopTexture() or "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow")
		weaveTriangleTop:SetDrawLayer(ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY")
		weaveTriangleTop:SetBlendMode(ns.GetIndicatorBlendMode and ns.GetIndicatorBlendMode() or "ADD")
		weaveTriangleTop:SetAlpha(ns.GetWeaveTriangleAlpha and ns.GetWeaveTriangleAlpha() or 1)
		weaveTriangleTop:SetWidth(ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14)
		weaveTriangleTop:SetHeight(ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14)

		local weaveTriangleBottom = ns.mhBar:CreateTexture(nil, "OVERLAY")
		weaveTriangleBottom:SetTexture(ns.GetWeaveTriangleBottomTexture and ns.GetWeaveTriangleBottomTexture() or "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow")
		weaveTriangleBottom:SetDrawLayer(ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY")
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

