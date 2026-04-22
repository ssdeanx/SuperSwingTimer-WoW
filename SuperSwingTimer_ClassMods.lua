local addonName, ns = ...

-- ============================================================
-- Class-specific visual overlays and behavior hooks.
-- Each class mod sets callbacks on ns (OnMeleeSwing, OnRangedSwing,
-- OnBarsCreated, OnDruidFormChange) as needed.
-- ============================================================

local function SetupRetPaladin()
	-- Seal-twist window: colored overlay ~0.4s before swing
	ns.OnBarsCreated = function()
		if not ns.mhBar then return end
		local sealZone = ns.mhBar:CreateTexture(nil, "ARTWORK")
		local c = SuperSwingTimerDB and SuperSwingTimerDB.colors and SuperSwingTimerDB.colors.sealTwist
		if c then
			sealZone:SetColorTexture(c.r, c.g, c.b, c.a)
		else
			sealZone:SetColorTexture(0, 0.8, 1, 0.4)  -- cyan default
		end
		sealZone:SetPoint("TOPRIGHT")
		sealZone:SetPoint("BOTTOMRIGHT")
		sealZone:SetWidth(0)
		ns.sealTwistZone = sealZone

		local SEAL_WINDOW = 0.4
		local origOnUpdate = ns.OnUpdate
		ns.OnUpdate = function(elapsed)
			origOnUpdate(elapsed)
			if ns.sealTwistZone and ns.timers.mh.state == "swinging" and ns.mhBar then
				local dur = ns.timers.mh.duration
				if dur > 0 then
					local w = (SEAL_WINDOW / dur) * ns.BAR_WIDTH
					ns.sealTwistZone:SetWidth(math.min(w, ns.BAR_WIDTH))
				end
			end
		end
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
		if unit == "player" and ns.SLAM_IDS[spellId] and ns.mhBar then
			ns.mhBar:SetStatusBarColor(0.8, 0.8, 0.1, 1)  -- yellow during slam
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

		if not info.isCasting then
			ns.weaveSpark:Hide()
			ns.weaveTriangleTop:Hide()
			ns.weaveTriangleBottom:Hide()
			return
		end

		local threshold = math.max((info.castTime or 0) + (info.latency or 0), 0)
		local markerPos = ((timer.duration - threshold) / timer.duration) * (ns.BAR_WIDTH or 0)
		if markerPos < 0 then
			markerPos = 0
		elseif markerPos > (ns.BAR_WIDTH or markerPos) then
			markerPos = ns.BAR_WIDTH
		end

		local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
		local swingElapsed = math.max(0, now - (timer.lastSwing or now))
		local sparkPos = (swingElapsed / timer.duration) * (ns.BAR_WIDTH or 0)
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
		ns.weaveSpark:Show()

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
			ns.weaveMarker:SetShown(true)
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
		weaveSpark:SetBlendMode("ADD")
		weaveSpark:SetAlpha(ns.GetWeaveSparkAlpha and ns.GetWeaveSparkAlpha() or 0.95)
		weaveSpark:SetWidth(ns.GetWeaveSparkWidth and ns.GetWeaveSparkWidth() or 14)
		weaveSpark:SetHeight(ns.GetWeaveSparkHeight and ns.GetWeaveSparkHeight() or 30)
		weaveSpark:SetPoint("CENTER", ns.mhBar, "LEFT", 0, 0)

		local weaveTriangleTop = ns.mhBar:CreateTexture(nil, "OVERLAY")
		weaveTriangleTop:SetTexture(ns.GetWeaveTriangleTopTexture and ns.GetWeaveTriangleTopTexture() or "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Arrow")
		weaveTriangleTop:SetDrawLayer(ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY")
		weaveTriangleTop:SetBlendMode("ADD")
		weaveTriangleTop:SetAlpha(ns.GetWeaveTriangleAlpha and ns.GetWeaveTriangleAlpha() or 1)
		weaveTriangleTop:SetWidth(ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14)
		weaveTriangleTop:SetHeight(ns.GetWeaveTriangleSize and ns.GetWeaveTriangleSize() or 14)

		local weaveTriangleBottom = ns.mhBar:CreateTexture(nil, "OVERLAY")
		weaveTriangleBottom:SetTexture(ns.GetWeaveTriangleBottomTexture and ns.GetWeaveTriangleBottomTexture() or "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Arrow")
		weaveTriangleBottom:SetDrawLayer(ns.GetWeaveTriangleLayer and ns.GetWeaveTriangleLayer() or "OVERLAY")
		weaveTriangleBottom:SetBlendMode("ADD")
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

	local origOnUpdate = ns.OnUpdate
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
		local form = GetShapeshiftForm and GetShapeshiftForm() or 0
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

