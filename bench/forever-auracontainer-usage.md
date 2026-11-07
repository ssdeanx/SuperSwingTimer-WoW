# Forever client (12.1+) — AuraContainer / AuraButton addon usage

**Verdict: the pattern in the brief works, and it is the documented addon-facing pattern.**
Everything below is traced to the read-only client source at `/home/sam/wow-ui-source` (branch
`origin/forever`, commit `eac30af`, `1.60.1 (70790)`, 2026-11-04) or to a cited public
addon / wiki page. Anything I could not establish is marked **[UNVERIFIED]**.

---

## 0. TL;DR

| # | Question | Answer |
|---|---|---|
| 1 | `CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")` from addon code | **Yes.** Supported by design; 9+ public addons ship it. |
| 2 | `SetUnit` / `AddAuraSlot` / `AddAuraGroup` / `candidateFilters` | Yes, as documented. `includeSpellIDs` is a **set**: `{ [1126] = true }`. |
| 3 | `initializeFrame(frame)` styling | Yes. Signature is `initializeFrame(button)`, one arg, run inside `securecallfunction`. |
| 4 | `SetPoint` / `SetSize` on returned frames | **Yes** for the aura buttons and for the container. One anchoring caveat (below). |
| 5 | Real public addons | **Yes** — BigWigs, ElvUI, DBM, oUF, Grid2, ConsolePort, QUI, RealUI, Inomena, **Northern Sky Raid Tools** (named in the Wowhead piece). |

**The one restriction that actually bites you:** `Enum.ScriptObjectAccessRestriction.DenyTaintedAccessWhenAurasAreSecret`
is applied to every aura button after creation. While aura info is secret, tainted code cannot
touch the buttons at all. It is *not* a creation-time blocker, and it is deliberately deferred
past `PLAYER_LOGIN` so addons can configure their buttons first.

---

## 1. Can addon code create the container?

**Yes.** Three independent pieces of source evidence, plus shipping addons.

### 1.1 The TOC says so outright

`Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainer.toc`:

```
## AllowLoad: game
## UseSecureEnvironment: 1

# XML files need to be loaded into the global environment in order to allow
# intrinsics and templates to be instantiated by external code without making
# their created objects implicitly forbidden. The Lua files must however be
# loaded into the secure environment.

Blizzard_AuraContainer.xml [LoadIntoEnvironment global]
...
Blizzard_CustomAuraContainer.xml [LoadIntoEnvironment global]
Blizzard_CustomAuraButton.xml [LoadIntoEnvironment global]
```

"External code" = addons. The XML carrying the intrinsic and the template is deliberately loaded
into the **global** environment so addon-created instances are not implicitly forbidden.
`AllowLoad: game` and no `LoadOnDemand`: the addon is always loaded in game, so the
template is always resolvable at addon `ADDON_LOADED` / `PLAYER_LOGIN` time.

### 1.2 The template is marked addon-creatable; the button template is not

`Blizzard_CustomAuraContainer.xml`:

```xml
<ScopedModifier useForbiddenObjectTable="true" allowUntaintedCreation="true">
    <AuraContainer name="CustomAuraContainerTemplate" virtual="true">
        <Mixins>
            <Mixin key="CustomAuraContainerInboundMixin" source="secure" targetPartition="public" inboundPartition="forbidden" secureDelegates="true"/>
            <Mixin key="CustomAuraContainerPrivateMixin" source="secure"/>
        </Mixins>
        ...
```

`allowUntaintedCreation="true"` appears **exactly twice in the whole UI source** — on
`Blizzard_AuraContainer.xml` (the `AuraContainer` intrinsic) and on
`Blizzard_CustomAuraContainer.xml` (this template). It never appears on
`Blizzard_AuraButton.xml` / `Blizzard_CustomAuraButton.xml`, which carry only
`useForbiddenObjectTable="true"`.

Read that as the intended contract: **addons create containers; Blizzard's frame provider creates
buttons and hands them to you.** You should not `CreateFrame("AuraButton", ...)` yourself.

### 1.3 The access restrictions are explicitly deferred *for addons*

`Blizzard_AuraContainerUtil.lua:403` `AuraContainerUtil.ApplyAccessRestrictions`:

```lua
-- Access restrictions are applied in a deferred manner. If we've begun
-- signaling the PLAYER_LOGIN event, apply them immediately - else,
-- wait until PLAYER_ENTERING_WORLD to restrict them.
--
-- This allows user addons to set up aura buttons on login and UI reload
-- and give them ample time to apply configuration through execution of
-- PLAYER_LOGIN. We use PLAYER_ENTERING_WORLD for deferred restrictions
-- to avoid racing our event handlers against theirs.
```

That comment is a direct statement that addons are expected to configure aura buttons at login.

### 1.4 Taint restrictions on creation

None found. There is no `IsForbidden`/`IsProtected` guard on the *container*, and no
`assert` about caller identity anywhere in `AddAuraSlot`/`AddAuraGroup`. The frame
provider creates buttons in the **global** environment on purpose:

```lua
-- Blizzard_AuraContainerFrameProviders.lua
function CreateFrameOutbound(frameType, name, parent, inherits)
    -- Frame creation occurs in the global environment as this API can use the
    -- caller's environment for resolution of mixins. Untrusted frames should
    -- always use global mixins.
    return CreateFrame(frameType, name, parent, inherits);
end
```

### 1.5 Shipping proof

Public addons on GitHub (details in §5) all do the same one-liner, several with a `nil` name and
`UIParent` as parent exactly as proposed:

```lua
local container = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
```

RealUI even wraps it defensively: `pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")`
— that is version-skew hardening, not evidence of a failure.

---

## 2. SetUnit / AddAuraSlot / AddAuraGroup / candidateFilters

### 2.1 `SetUnit(unitToken)`

`Blizzard_AuraContainer.lua:40`:

```lua
function AuraContainerSharedMixin:SetUnit(unitToken)
    assert(type(unitToken) == "string");
    if self.unitToken ~= unitToken then
        self.unitToken = unitToken;
        self:UpdateEventRegistrations();
        self:UpdateAllAuras();
    end
end
```

Any unit token string works (`"player"`, `"target"`, `"focus"`, `"party1"`, `"raid12"`).
Defaults to `"none"` from the XML KeyValues. I found no allow-list and no forbidden check.

### 2.2 `AddAuraSlot(slotKey, filterString, options)`

* `slotKey` — non-empty string, must be unique (`self:HasAuraSlot(slotKey)` is asserted false).
* `filterString` — asserted with `AuraUtil.IsValidFilterString(filterString)`. Pipe-separated
  tokens: `HELPFUL`, `HARMFUL`, `PLAYER`, `RAID`, `RAID_PLAYER_DISPELLABLE`,
  `RAID_IN_COMBAT`, `CANCELABLE`, `INCLUDE_NAME_PLATE_ONLY`, `MAW`,
  `EXTERNAL_DEFENSIVE`, `CROWD_CONTROL`, `BIG_DEFENSIVE`, `IMPORTANT`,
  `DISPELLABLE`. `!` negates (`!PLAYER`); `IncludeNamePlateOnly` and `Maw` are not negatable.
* Returns the aura frame (the inbound wrapper translates it to a public object reference):
  `return auraFrame;`
* Slots are **not** part of flow layout — you must anchor them yourself. Source comment:

  ```lua
  -- Default options for aura slot displays. An aura slot renders a single aura
  -- at the front of a priority list. They do not take part in dynamic layout
  -- and must be manually anchored.
  --
  -- This can be used to replicate "big defensive" style displays, dispel
  -- type indicators, or indicators for specific spells by ID.
  ```

**Slot options** (`CustomAuraContainerSlotDefaultOptions`): `templateNames`, `initializeFrame`,
`candidateFilters`, `sortMethod`, `sortDirection`.

### 2.3 `AddAuraGroup(groupKey, filterString, options)`

Same key/filter rules, plus **`maxFrameCount`** (default `math.huge`) and **`layout`**
(flow layout). Groups *are* laid out by the container.

**Group options** (`CustomAuraContainerGroupDefaultOptions`): `maxFrameCount`, `templateNames`,
`initializeFrame`, `candidateFilters`, `sortMethod`, `sortDirection`, `layout`.

**`layout` fields** (`CustomAuraContainerGroupLayoutDefaultOptions`):
`elementSpacing`, `lineSpacing`, `groupSpacing`, `groupLineSpacing`,
`forceNewLine` (bool), `elementWidth`, `elementHeight`, `layoutIndex` (number, orders groups).

**Container-level flow layout** (`AuraContainerFlowLayout*Mixin`, callable from addon code):
`SetFlowLayoutAxis`, `SetFlowLayoutAnchorPoint`, `SetFlowLayoutGrowthDirection(h, v)`,
`SetFlowLayoutPadding(l, r, t, b)`, `SetFlowLayoutMaximumLineSize` (row wrap width).

### 2.4 Mutators after creation

All asserted-safe and hot-swappable, so you can reconfigure without recreating:
`SetAuraSlotFilterString`, `SetAuraSlotCandidateFilters`, `SetAuraSlotSortMethod`,
`SetAuraSlotEnabled`, `SetAuraGroupFilterString`, `SetAuraGroupCandidateFilters`,
`SetAuraGroupMaxFrameCount`, `SetAuraGroupSortMethod`, `SetAuraGroupLayout`,
`SetAuraGroupEnabled`, `SetAuraProcessingPolicy`, `SetEnabled`, `SetUnit`,
`UpdateAllAuras`.

There is deliberately **no** `RemoveAuraGroup` / `ClearAuraGroups`: the private mixin comment says
clearing would make pooled frames irrecoverable, so they expose "reconfigure" instead. Plan for a
fixed set of keys, and disable (`SetAuraGroupEnabled(key, false)`) or set `maxFrameCount = 0`
rather than trying to delete.

### 2.5 `candidateFilters` — exact shape and rules

Shape: a plain table, every field optional. Spell IDs are a **set keyed by spellID → truthy**:

```lua
candidateFilters = {
    includeSpellIDs      = { [1126] = true, [10060] = true },  -- Mark of the Wild, Power Infusion
    excludeSpellIDs      = { [57723] = true },                 -- Exhaustion
    includeDispelTypes   = { Magic = true, Curse = true },     -- keys are auraData.dispelName
    excludeDispelTypes   = { Bleed = true },
    maxDuration          = 300,          -- seconds; IMPLICITLY hides permanent auras (duration == 0)
    processedAuraType    = Enum.AuraUpdateChangedType.Buff,   -- requires ProcessAura policy
    isFromPlayerOrPlayerPet = true,
    isRoleAura           = true,
    isPriorityAura       = true,
    isStealable          = true,
    nameplateShowAll     = false,
    nameplateShowPersonal= false,
    canApplyAura         = true,
    isBossAura           = true,
    isBossOrRoleAura     = true,
}
```

Validation is in `Blizzard_CustomAuraContainer.lua` `ValidateCandidateFilters`; evaluation is in
`Blizzard_AuraContainerUtil.lua` `AuraContainerUtil.DoesAuraPassCandidateFilters`.

**The identity-filter rule** (this is the one the brief asks about). From source:

> Map of permitted spell IDs. Any spell IDs outside of this set are ignored and will not be
> visible in the container. Spell ID matching is only permitted for helpful buffs on assistable
> units, and harmful buffs on non-assistable units.
>
> Auras that can't be matched by spell ID are rejected outright, so this can only ever admit
> never-secret spells on units where matching isn't permitted.

The gate is `CanApplyIdentityCandidateFilters(unitToken, auraData)`, which returns `true` when:

1. `C_Secrets.GetSpellAuraSecrecy(auraData.spellId) == Enum.SecrecyLevel.NeverSecret` — the
   "noisy debuff" exemption (**this is why Exhaustion `57723` works**, matching Wowhead's wording), **or**
2. `auraData.isHelpful and UnitIsPlayerControlledOrGroupMember(unitToken)` — buffs on the player,
   group members and their pets are always matchable (with an explicit Mind Control note in source), **or**
3. not (`isHarmful and UnitCanAssist("player", unitToken, true, true)`) and
   not (`isHelpful and not UnitCanAssist(...)`).

Concretely that means **allowed**: helpful on assistable (friendly) units, harmful on non-assistable
(hostile) units. **Blocked**: harmful on friendly units, helpful on hostile units.

When the gate is `false`:
* if `includeSpellIDs` is set → **default-deny everything** (`return false`);
* if only `excludeSpellIDs` is set → it is **silently ignored**, everything passes.

Practical consequence: `includeSpellIDs` is safe to use unconditionally. It either shows exactly
your list, or shows nothing. It can never leak encounter mechanics. This is the intended design,
not a bug.

Note also `AppendCandidateFilterUnitEvents`: setting `includeSpellIDs`/`excludeSpellIDs`
auto-registers `UNIT_FLAGS` and `UNIT_FACTION` on `player` and on the tracked unit, because
assist state can change mid-fight. You get that for free.

`processedAuraType` only works if you first called
`container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.ProcessAura, opts)`;
otherwise it hides all auras. `opts` = `ignoreBuffs`, `ignoreDebuffs`,
`ignoreDispelDebuffs`, `displayOnlyDispellableDebuffs`.

### 2.6 Sorting

`AuraContainerSortMethod`: `Default`, `BigDefensive`, `UnitFrameDebuff`,
`ImportantOnly`, `Expiration`, `ExpirationOnly`, `Name`, `NameOnly`,
`AuraInstanceIDOnly`. Direction: `AuraContainerSortDirection.Normal` / `.Reverse`.

---

## 3. `initializeFrame` and the styling API

### 3.1 Call signature

`Blizzard_AuraContainerFrameProviders.lua` `CreateFrame`:

```lua
function AuraContainerCustomFrameProviderMixin:CreateFrame()
    local auraFrame = CreateFrameOutbound("AuraButton", nil, self:GetParent(), self:GetTemplateString());

    if self.initializeFrame ~= nil then
        securecallfunction(self.initializeFrame, auraFrame:GetObjectTable());
    end

    -- Access restrictions should be applied after (potentially tainted)
    -- post-creation callbacks.
    if self.accessRestrictions then
        AuraContainerUtil.ApplyAccessRestrictions(auraFrame, self.accessRestrictions);
    end

    auraFrame:UpdateAuraDisplay();
    ...
```

Things that matter:

* **One argument.** The frame/object table. Treat it as the button; `button:CreateTexture`,
  `button:SetSize`, `button:SetIcon` all work (oUF, BigWigs, ElvUI all do exactly this).
* **`securecallfunction`.** An error inside your callback does **not** propagate to your addon;
  it goes to the secure error handler. Your styling silently half-applies. Wrap your own body in
  `pcall` and print while developing.
* **Called before access restrictions.** So it is legal to configure at creation time; the
  `DenyTaintedAccessWhenAurasAreSecret` restriction lands afterwards.
* **`FrameCreationBatchSize = 10`.** Buttons are allocated in batches of 10 up front
  ("Must be sufficiently high to obfuscate the number of auras as this invokes initialization
  callbacks"). Your `initializeFrame` will be called ~10 times immediately, and again whenever the
  pool grows. **It must be idempotent-safe and must not assume it is called once per visible aura.**
* `templateNames` are appended after `CustomAuraButtonTemplate`:
  `string.join(", ", "CustomAuraButtonTemplate", unpack(templateNames))`.

### 3.2 The display-element setters

All are on `CustomAuraButtonSharedMixin` (`Blizzard_CustomAuraButton.lua`). Each one validates the
argument, calls `AuraContainerUtil.InitializeInboundScriptObject` (adds forbidden aspects
`RemoveSecretAspects` + `ChangeParent` to your region), adds secret aspects, then
`UpdateAuraDisplay()`.

| Call | Argument | Options | Secret aspects added to your region |
|---|---|---|---|
| `SetIcon(texture)` | Texture | — | *(none — but the aura texture value is `secretwrap`'d)* |
| `SetDurationText(fontString, options)` | FontString | yes | `Text`, `Alpha`, `VertexColor` |
| `SetApplicationCount(fontString, options)` | FontString | yes | `Text`, `Shown` |
| `SetDurationBar(statusBar, options)` | StatusBar | yes | `BarValue` |
| `SetDurationCooldown(cooldown)` | Cooldown | **no options** | `Cooldown`, `Shown` |
| `SetApplicationBar(statusBar, options)` | StatusBar | yes | `BarValue` |
| `AddDispelTypeTexture(texture, options)` | Texture | yes | `Alpha`, `VertexColor`, `TexCoords`, `Shown` |
| `SetDispelTypeText(fontString, options)` | FontString | yes | `Text`, `Shown` |
| `SetSpellName(fontString)` | FontString | — | `Text`, `Shown` |
| `SetCasterName(fontString, options)` | FontString | yes | `Text`, `Shown` |
| `AddPandemicRegion(region)` | Region | — | `Shown` |

There are matching `Clear*` methods (`ClearIcon`, `ClearDurationText`, …) and `Get*` accessors.

**Hard rule on the region argument.** `AuraContainerUtil.ValidateInboundScriptObject` →
`ValidateInboundScriptObjectInternal` enforces:

```lua
local isOwnerValid = allowOwner and (object == owner);
if not isOwnerValid and not RegionUtil.IsDescendantOf(object, owner) then
    error(string.format("bad object '%s' in function call (must be the owner or a direct or indirect descendant of owner)", ...));
end
```

So the texture/fontstring **must be created as a child of the aura button**:
`button:CreateTexture(nil, "OVERLAY")`, `button:CreateFontString(nil, "OVERLAY", ...)`, or a
child of such a child. A region parented elsewhere is a hard Lua error. It also rejects explicitly
protected objects, and an object must not be explicitly `IsForbidden()`.

**Consequence of the secret aspects:** once you hand a region to `SetDurationText` /
`SetApplicationCount`, that region's text/color/shown state is engine-owned. Do not `SetText`/
`SetTextColor`/`Show`/`Hide` it afterwards from addon code — that is exactly the "restricted
operation on a secret aspect" error class. Same for `SetVertexColor` on a dispel texture, and
`GetTexture()` on the icon. Create separate decorative regions for anything you want to control.

### 3.3 Options structures (from `Blizzard_APIDocumentationGenerated/AuraContainerUtilDocumentation.lua`)

```lua
CustomAuraButtonDurationTextOptions = {
    binding       = DurationTextBinding,               -- optional; copied before association
    textFormatter = NumericFormatter,                  -- ignored if textFormat is set
    textFormat    = DurationTextBindingFormatOptions,  -- { formatString, components }
    textColor     = DurationTextBindingColorOptions,   -- { curve, property }
}

CustomAuraButtonDurationBarOptions = {
    interpolation = Enum.StatusBarInterpolation,   -- optional
    direction     = Enum.StatusBarTimerDirection,  -- optional
}

CustomAuraButtonApplicationCountOptions = {
    formatter = NumericFormatter,  -- optional; else literal count, hidden when <= 1
}

CustomAuraButtonApplicationBarOptions = {
    minApplications = 0,      -- number, default 0
    maxApplications = ?,      -- number, REQUIRED
    interpolation   = Enum.StatusBarInterpolation,  -- optional
}

CustomAuraButtonDispelTypeTextureOptions = {
    style               = Enum.CustomAuraButtonDispelTypeTextureStyle.{Border,BorderWithIcon,Icon,PreserveAsset,CustomAsset},
    showAlways          = bool,
    showWhenHarmful     = bool,
    showWhenHelpful     = bool,
    showWithoutDispelType = bool,
    stealableFilter     = Enum.CustomAuraButtonDispelTypeStealableFilter.{Stealable,NotStealable},
    customDispelAssetMap = table,   -- [dispelName] = { asset, useAtlasSize, texCoords }
    customDispelColorMap = table,   -- [dispelName] = Color
    customDispelColorCurve = ColorCurve,
}

CustomAuraButtonCasterNameOptions = { showRealmName = false, useClassColors = false }
```

`SetDurationCooldown(cooldown)` genuinely takes **no options table** — passing one is ignored by
the signature (`function ...:SetDurationCooldown(cooldown)`). Configure the cooldown frame
yourself (`SetReverse`, `SetDrawEdge`, `SetDrawBling`, `SetHideCountdownNumbers`, …) before
associating it, as BigWigs does.

Other per-button API worth knowing: `SetTooltipAnchorPoint(point, x, y)`,
`SetHideTooltipInCombat(bool)`, `SetCancelAuraButtons(...)`, and the animation hooks
`AddAuraAssignedAnimation`, `AddAuraShownAnimation`, `AddPandemicEnterAnimation`,
`AddPandemicActiveAnimation`, `AddPandemicLeaveAnimation` (call these **last**, after the regions
they target exist — the animation group's targets are validated as descendants at add time).

---

## 4. Repositioning with SetPoint / SetSize

**Yes, and it is required for slots.** The aura button's forbidden aspects are:

```xml
<ForbiddenAspect aspect="UntrustedScriptExecution"/>
<ForbiddenAspect aspect="UntrustedLayoutScriptExecution"/>
<ForbiddenAspect aspect="ScriptedInput"/>
<ForbiddenAspect aspect="AlwaysPropagateInput"/>
<ForbiddenAspect aspect="QueryFocus"/>
<ForbiddenAspect aspect="ChangeParent"/>
<ForbiddenAspect aspect="RemoveSecretAspects"/>
```

`UntrustedLayoutScriptExecution` is documented in
`ForbiddenAspectConstantsDocumentation.lua` as:

> Restricts execution of **layout scripts (eg. OnSizeChanged)** for this object. Propagates to any
> children of this object, and anything anchored to this object.

It restricts the running of *scripts* (handler execution), **not** the `SetPoint` / `SetSize`
API calls. Confirmed empirically: oUF's `CreateButton` does `button:SetSize(width, height)` on
every group button and its docs state slots "can be overridden with `ClearAllPoints` and
`SetPoint`"; BigWigs does `aura:SetSize(optionsDB.width, optionsDB.height)` inside
`initializeFrame` with the note "CustomAuraContainerFlowLayoutDescription:ApplyElementLayout
doesn't set size".

Two real caveats:

1. **`ChangeParent` is forbidden on buttons.** Never `button:SetParent(...)`. Use `SetPoint`
   with a `relativeTo` instead, and put the button in a normal `Frame` you own if you need a
   movable container.
2. **Anchoring *your* frames to an aspect-bearing object.** `AddAuraGroup` does this:

   ```lua
   self:AddForbiddenAspects(Enum.ForbiddenAspect.UntrustedLayoutScriptExecution);

   -- Aura groups resize the container, and so adding any to a group should
   -- disable OnSizeChanged. This has the side effect of making it impossible
   -- for user addons to anchor other frames that don't have this aspect applied
   -- to the container once a group is set - for that, they can
   -- inherit DisableUntrustedLayoutScriptsTemplate on those frames at the
   -- point of creation to opt-in to this aspect.
   ```

   So: if you anchor a frame **of yours** to a container that has groups, create it with the
   opt-in template:

   ```lua
   local mine = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
   mine:SetPoint("TOPLEFT", container, "TOPLEFT")
   ```

   `DisableUntrustedLayoutScriptsTemplate` lives in `Blizzard_SharedXMLBase/ForbiddenAspectTemplates.xml`
   and exists precisely for this ("exposed for user addons that need to opt their own Lua-created
   frames into disallowing script execution via forbidden aspects … we don't allow implicit
   inheritance of forbidden aspects through SetParent / SetPoint calls").

   **[UNVERIFIED]** whether omitting it raises a Lua error or merely misbehaves, and why ElvUI and
   one NSRT file put `DisableUntrustedLayoutScriptsTemplate` on the **container's** own template
   string (`"CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate"`) — that aspect is
   already added by `AddAuraGroup`, so it looks defensive/redundant. BigWigs, DBM and oUF do
   *not* do it and ship fine. If you hit an anchoring error, add the template — cheapest fix.

Also note `AddAuraGroup` adds the aspect to the container, but `AddAuraSlot` does **not**. A
slots-only container never gets the layout aspect. Keep your own anchor frames opt-in anyway if you
mix both.

---

## 5. Real public addons

All verified by GitHub code search (`gh search code "CustomAuraContainerTemplate"`).

| Addon | File | Notes |
|---|---|---|
| **BigWigs** | `Plugins/Auras.lua` | Group-based, `initializeFrame` + `SetSize`, custom duration bindings, `SetDurationCooldown`. |
| **ElvUI** | `ElvUI/Game/Shared/Modules/Auras/Containers.lua` | Full groups + slots + item enchantments; uses `CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate`. |
| **Deadly Boss Mods** | `DBM-Core/modules/AuraTracking.lua` | `CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")` verbatim. |
| **oUF** | `elements/auras.lua` | Best-documented reference; `Auras:AddGroup` / `AddSlot` wrapper, `candidateFilters.includeSpellIDs = {[1126]=true}`. |
| **Grid2** | `GridIndicatorAuras.lua` | Container per grid frame. |
| **ConsolePort** | `ConsolePort_Target/View/Ring/TargetframeAurasMainline.lua` | `CreateFrame('AuraContainer', nil, parent, 'CustomAuraContainerTemplate')`. |
| **QUI** | `core/aura_surface.lua`, `modules/qol/lusttimer.lua` | Also uses it for a Bloodlust timer. |
| **RealUI** | `RealUI_Auras/Containers.lua` | `pcall`-guarded creation. |
| **Inomena** | `modules/widgets/buffs.lua` | |
| **Northern Sky Raid Tools** | `NorthernSkyRaidTools/AuraTracking.lua` (repo `Reloe/NorthernSkyRaidTools`) | The addon named in the Wowhead article. Uses groups with `initializeFrame`, `candidateFilters = { includeSpellIDs = ... }`, `SetAuraProcessingPolicy`, container `SetPoint`/`SetSize`/`ClearAllPoints`. |
| **Northern Sky Raid Tools** | `AuraGlows.lua`, `EncounterAlerts/MidnightS1/Beloren.lua` | Named container parented to an NSRT frame. |

### Source URLs

* `https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua`
* `https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua`
* `https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerFrameProviders.lua`
* `https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerShared.lua`
* `https://github.com/Gethe/wow-ui-source/blob/12.1.0/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua`
* `https://github.com/tukui-org/ElvUI/blob/main/ElvUI/Game/Shared/Modules/Auras/Containers.lua`
* `https://github.com/BigWigsMods/BigWigs/blob/master/Plugins/Auras.lua`
* `https://github.com/oUF-wow/oUF/blob/master/elements/auras.lua`
* `https://github.com/Reloe/NorthernSkyRaidTools/blob/main/NorthernSkyRaidTools/AuraTracking.lua`
* `https://github.com/wealdly/JustAC/blob/main/Documentation/AURA_CONTAINER_12.1.md` — third-party field notes, validated in game 2026-08-11 (build 69214). Useful traps list; **its claim that the frame "does not run in our taint" is that author's interpretation, not a Blizzard statement**.
* `https://warcraft.wiki.gg/wiki/INTRINSIC_AuraContainer` — explicitly documents `CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")`.
* `https://warcraft.wiki.gg/wiki/INTRINSIC_AuraButton` — forbidden aspect table.
* `https://warcraft.wiki.gg/wiki/API:AuraContainer_AddAuraSlot`
* `https://warcraft.wiki.gg/wiki/API:AuraContainer_AddAuraGroup`
* `https://warcraft.wiki.gg/wiki/API:AuraContainer_SetAuraGroupCandidateFilters`
* `https://warcraft.wiki.gg/wiki/API:AuraContainer_SetUnit`, `https://warcraft.wiki.gg/wiki/API:AuraContainer_SetAuraProcessingPolicy`
* `https://warcraft.wiki.gg/wiki/Secret_Values` — secret/forbidden aspect model.
* `https://warcraft.wiki.gg/wiki/Patch_12.1.0/API_changes` — "Added AuraContainer and AuraButton intrinsic frames" (12.1.0, build 69587, Aug 27 2026).
* `https://www.wowhead.com/news/addon-changes-in-patch-12-1-custom-aura-trackers-with-addons-382338` — 2026/08/03, names NSRT; states "Only debuffs on enemies" / "Only buffs on allies", Exhaustion exception.
* `https://www.townlong-yak.com/framexml/ptr/go/CustomAuraContainerSharedMixin:AddAuraSlot` (and siblings) — live framexml browser.

---

## 6. The restrictions, assembled

1. **Secret-aura access denial (the real one).**
   `CustomAuraContainerConstants.AccessRestrictionFlags = Enum.ScriptObjectAccessRestriction.DenyTaintedAccessWhenAurasAreSecret`,
   applied to **every aura button** after creation
   (`AuraContainerUtil.ApplyAccessRestrictions(auraFrame, self.accessRestrictions)`).
   Doc: "Denies access to this script object from tainted execution while aura information is
   secret." While secrets are active you cannot call methods on the buttons at all. Deferred past
   `PLAYER_LOGIN` (`IsLoggedIn()` check) to give addons a configuration window.
2. **Identity filtering is geography-limited.** Spell-ID matching only for helpful-on-assistable and
   harmful-on-non-assistable, plus never-secret spells. Otherwise fail-closed (show nothing) when
   `includeSpellIDs` is present.
3. **No parent changes.** `ChangeParent` forbidden on buttons; also added to any region you pass to a
   `Set*` display setter.
4. **No script-driven input.** `ScriptedInput` + `AlwaysPropagateInput` forbidden on buttons —
   you cannot synthesise clicks, and mouse input always propagates.
5. **Regions must be descendants of the button.** Enforced, hard error otherwise.
6. **You cannot un-secret your own regions.** `RemoveSecretAspects` forbidden, and the setters add
   secret aspects (`Text`, `Shown`, `Alpha`, `VertexColor`, `TexCoords`, `BarValue`,
   `Cooldown`) to them. Read-back of icon texture / duration text / count is denied.
7. **Layout-script aspect on containers with groups.** See §4.2.
8. **No removal API.** Groups/slots can be disabled or zero-sized, not deleted.
9. **Batch-of-10 frame creation** invokes `initializeFrame` more often than you have auras.

---

## 7. Verified usage recipe

```lua
-- Runs in the addon's (tainted) execution context. Everything here is verified against
-- origin/forever eac30af and matches shipping addons.

local container = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
container:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
container:SetSize(180, 40)                 -- container is repositionable (§4)
container:SetUnit("target")

container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
container:SetFlowLayoutAnchorPoint("TOPLEFT")
container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
container:SetFlowLayoutMaximumLineSize(180)
container:SetFlowLayoutPadding(0, 0, 0, 0)

-- 1) A flow-laid-out group: all player debuffs on the target.
container:AddAuraGroup("debuffs", "HARMFUL|PLAYER", {
    maxFrameCount = 8,
    sortMethod    = AuraContainerSortMethod.Expiration,
    sortDirection = AuraContainerSortDirection.Normal,
    layout = { elementWidth = 32, elementHeight = 32, elementSpacing = 2, lineSpacing = 2 },
    initializeFrame = function(button)
        button:SetSize(32, 32)                                  -- required; flow layout won't size it

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        button:SetIcon(icon)

        local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cd:SetAllPoints()
        cd:SetReverse(true)
        cd:SetHideCountdownNumbers(true)
        button:SetDurationCooldown(cd)                          -- no options table

        -- text parented to the button, not to the cooldown, so it validates as a descendant
        local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", -1, 1)
        button:SetApplicationCount(count, {})                   -- {} works; formatter optional

        local duration = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        duration:SetPoint("TOPLEFT", 1, -1)
        button:SetDurationText(duration, {
            -- textFormatter / textFormat / textColor / binding all optional
        })

        -- a dispel border, if you have no other use for the texture
        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints(button)
        button:AddDispelTypeTexture(border, {
            style           = Enum.CustomAuraButtonDispelTypeTextureStyle.Border,
            showWhenHarmful = true,
        })
    end,
})

-- 2) A manually anchored slot: one big tracker, spell-ID locked.
local slotOptions = {
    candidateFilters = {
        includeSpellIDs = { [1126] = true },                    -- set, not array
    },
    sortMethod = AuraContainerSortMethod.ExpirationOnly,
    initializeFrame = function(button)
        button:SetSize(64, 64)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        button:SetIcon(icon)
        button:SetTooltipAnchorPoint("ANCHOR_RIGHT", 4, 0)
    end,
}

local slot = container:AddAuraSlot("mow", "HELPFUL", slotOptions)   -- returns the frame
-- slot == container:GetAuraSlotFrame("mow") after creation
slot:ClearAllPoints()
slot:SetPoint("LEFT", container, "RIGHT", 8, 0)
```

**Verification checklist if you build on this**

* Put `pcall` inside `initializeFrame` and print the error — `securecallfunction` otherwise
  swallows it (§3.1).
* When nothing appears: check you passed a *set* `{ [id] = true }`, not `{ id }`.
* When nothing appears on a **friendly** unit with `HARMFUL` + `includeSpellIDs`: expected,
  fail-closed by design (§2.5).
* Never `SetText`/`SetTextColor`/`Show` a fontstring you handed to `SetDurationText` /
  `SetApplicationCount` (§3.2).

---

## 8. Marked unverified

* **[UNVERIFIED]** Exact engine error (vs. silent no-op) when anchoring a non-opt-in frame to a
  container that has groups. Source comment says "impossible"; no error text found in the UI source.
* **[UNVERIFIED]** Why ElvUI / one NSRT file also add `DisableUntrustedLayoutScriptsTemplate` to the
  **container** template string, when `AddAuraGroup` already adds that aspect. Possibly harmless,
  possibly required for an anchoring direction I could not test.
* **[UNVERIFIED]** Whether `templateNames` entries must themselves be addon-creatable templates;
  only `DisableUntrustedLayoutScriptsTemplate` is observed in the wild.
* **[UNVERIFIED]** Runtime behaviour on the live 12.1.x client — all of the above is source + public
  addon code, not a live session. No client is available in this environment.
* **[UNVERIFIED]** The JustAC doc's framing that addon-created containers "do not run in our taint" is
  an interpretation; the primary source statement is the TOC comment in §1.1.
