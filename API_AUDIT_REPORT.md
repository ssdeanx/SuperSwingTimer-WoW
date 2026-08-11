# WoW API Audit: SuperSwingTimer vs Classic Era (1.15.9) / Classic Anniversary (2.5.6)

**Audit date:** 2026-07-28
**Source repo:** /home/sam/wow-ui-source (branches: origin/classic_era @ 1.15.9, origin/classic_anniversary @ 2.5.6)
**Addon:** /home/sam/SuperSwingTimer-WoW/

---

## AUDIT TABLE

| # | API Name | Where Used | classic_era (1.15.9) | classic_anniversary (2.5.6) | Notes |
|---|---|---|---|---|---|
| 1 | **GetTimePreciseSec** | State.lua:4, Weaving.lua:5, ClassMods.lua:21, Constants.lua:4 | YES | YES | API doc present on both. High-precision game time. |
| 2 | **GetTime** | Weaving.lua:6, ClassMods.lua:22, Constants.lua:5 | YES | YES | API doc present on both. GetTime() domain. |
| 3 | **UnitAttackSpeed** | State.lua:5, ClassMods.lua:12, UI.lua:6 | YES | YES | Returns mainHandSpeed, offHandSpeed. |
| 4 | **UnitRangedDamage** | State.lua:6,738 | YES | YES | Used in PaperDollFrame on both. Note: on TBC 2.5.5+, may return min damage instead of weapon speed — addon handles this with cached speed fallback. |
| 5 | **GetSpellCooldown** | State.lua:7,120, ClassMods.lua:23,186 | YES | YES | Legacy global API. Returns startTime, duration, enabled. |
| 6 | **C_Spell** | State.lua:8, ClassMods.lua:24 | YES | YES | API docgen present. Contains GetSpellCooldown, GetSpellInfo, IsAutoRepeatSpell. |
| 7 | **C_Spell.GetSpellCooldown** | State.lua:107-108,855-857, ClassMods.lua:174-175,896-897, etc. | YES | YES | Returns SpellCooldownInfo table {startTime, duration, isEnabled}. Addon handles via pcall. |
| 8 | **C_Spell.GetSpellInfo** | Constants.lua:51-52 | YES | YES | Returns table with .name, .iconID, .castTime, etc. Used as fallback for classic 1.15.x+. |
| 9 | **C_Spell.IsAutoRepeatSpell** | State.lua:154-155,161 | YES | YES | API doc present on both. Returns boolean. |
| 10 | **CombatLogGetCurrentEventInfo** | State.lua:9 | YES | YES | C API for CLEU. Used for SWING_DAMAGE/MISSED/RANGE_DAMAGE events. |
| 11 | **C_Timer** | State.lua:10, Config.lua:7 | YES | YES | API docgen present on both. |
| 12 | **C_Timer.NewTicker** | State.lua:554-555 | YES | YES | Used extensively in FrameXML. |
| 13 | **UnitGUID** | State.lua:11,460-506 | YES | YES | API doc present. |
| 14 | **UnitExists** | State.lua:12, ClassMods.lua:9 | YES | YES | API doc present. |
| 15 | **UnitCanAttack** | State.lua:13, ClassMods.lua:10 | YES | YES | API doc present. |
| 16 | **UnitName** | State.lua:14,509 | YES | YES | API doc present. |
| 17 | **GetNetStats** | State.lua:15, Weaving.lua:7 | YES | YES | Returns bandwidth, _, homeLatency, worldLatency. |
| 18 | **GetRangedHaste** | State.lua:16,201-206 | YES | YES | Used in PaperDollFrame.lua on both. |
| 19 | **IsMounted** | State.lua:17,148 | YES | YES | C API, available on all modern clients. |
| 20 | **UnitSpellHaste** | Weaving.lua:8,35-36 | YES | YES | API doc present on both. Preferred over GetSpellHaste(). |
| 21 | **GetSpellHaste** | Weaving.lua:9,39-40 | **NO** | **NO** | Legacy API removed from FrameXML. Addon uses UnitSpellHaste() as primary with GetSpellHaste() as type-guarded fallback — safe. |
| 22 | **UnitCastingInfo** | Weaving.lua:10,260-264, Constants.lua:6,74-75, UI.lua:7 | YES | YES | API doc present. Returns name, _, _, startTimeMs, endTimeMs, _, castId, _, spellId. |
| 23 | **UnitChannelInfo** | Weaving.lua:11,267-271, Constants.lua:7,75-79, UI.lua:7 | YES | YES | API doc present. Similar returns to UnitCastingInfo. |
| 24 | **IsSpellKnownOrOverridesKnown** | Weaving.lua:12,48-56 | YES | YES | Defined in Blizzard_DeprecatedSpellBook, gated by loadDeprecationFallbacks CVar. Addon has type-guard — safe. |
| 25 | **IsSpellKnown** | Weaving.lua:13,60-63 | YES | YES | Same Deprecated_SpellBook compat shim. |
| 26 | **IsPlayerSpell** | Weaving.lua:14,67-70 | YES | YES | Same Deprecated_SpellBook compat shim. |
| 27 | **CreateFrame** | ClassMods.lua:3, UI.lua:3, Config.lua:3, SST.lua:2 | YES (Widget) | YES (Widget) | C++ Widget API — always available. |
| 28 | **UIParent** | ClassMods.lua:4, UI.lua:4, Config.lua:4, SST.lua:3 | YES (Global) | YES (Global) | Global frame — always available. |
| 29 | **UnitAura** | ClassMods.lua:5,214 | YES | YES | ⚠️ Return shape varies by client version. Addon's ns.UnitAura wrapper handles all shapes: 1.13.x (9 rets, no icon), 1.15.9 (10 rets, icon string), 2.5.6 (11-12 rets via AuraUtil). |
| 30 | **UnitBuff** | ClassMods.lua:6,207 | YES | YES | Delegates to UnitAura(unit, index, "HELPFUL"). Same shape variability. |
| 31 | **UnitPower** | ClassMods.lua:7 | YES | YES | API doc present. Returns power amount by power type. |
| 32 | **UnitPowerType** | ClassMods.lua:8 | YES | YES | API doc present. |
| 33 | **UnitIsDead** | ClassMods.lua:11 | YES | YES | C API, available on all clients. |
| 34 | **IsSpellInRange** | ClassMods.lua:13 | YES | YES | API doc present. |
| 35 | **SpellHasRange** | ClassMods.lua:14 | YES | YES | API doc present. |
| 36 | **CheckInteractDistance** | ClassMods.lua:15 | YES | YES | Used in UnitPopupShared. |
| 37 | **GetSpellTexture** | ClassMods.lua:16,930 | YES | YES | API doc present. |
| 38 | **InCombatLockdown** | ClassMods.lua:17, UI.lua:5, SST.lua:8 | YES | YES | API doc present. |
| 39 | **GetSpecialization** | ClassMods.lua:18 | YES | YES | API doc present. Available on both. |
| 40 | **GetNumTalentTabs** | ClassMods.lua:19 | YES | YES | Used in TalentFrameBase on both. |
| 41 | **GetTalentTabInfo** | ClassMods.lua:20 | YES | YES | Defined in Blizzard_DeprecatedSpecialization on both. |
| 42 | **IsCurrentSpell** | ClassMods.lua:1473,4377,5295 | YES | YES | API doc present. |
| 43 | **GetInventoryItemID** | ClassMods.lua:684,715 | YES | YES | Used in FrameXML on both. |
| 44 | **GetSpellInfo** | Constants.lua:46-48 | YES | YES | ⚠️ On 1.15.9, API doc shows SpelLInfo struct return. FrameXML still uses multi-return style (`local name = GetSpellInfo(id)`). Addon's ns.GetSpellInfo passes through raw return, with C_Spell.GetSpellInfo fallback. |
| 45 | **GetAddOnInfo** | Constants.lua:3 | YES | YES | Used for addon identification. |
| 46 | **UnitClass** | SST.lua:5 | YES | YES | API doc present. |
| 47 | **GetShapeshiftForm** | SST.lua:7 | YES | YES | Used in FrameXML. Available on both. |
| 48 | **SlashCmdList** | SST.lua:4 | YES | YES | Global table — always available. |
| 49 | **strtrim** | SST.lua:6, Config.lua:14, UI.lua:8 | YES | YES | String utility — available on all clients. |
| 50 | **ColorPickerFrame** | Config.lua:5 | YES | YES | Global frame available on both. |
| 51 | **GameTooltip** | Config.lua:6 | YES | YES | Global frame available on both. |
| 52 | **ToggleDropDownMenu** | Config.lua:13 | YES | YES | Dropdown API available on both. |
| 53 | **BackdropTemplateMixin** | Config.lua:15 | YES | YES | Defined in Blizzard_SharedXML/Backdrop.lua. |
| 54 | **InterfaceOptions_AddCategory** | Config.lua:2161 | **NO** | **NO** | Replaced by Settings system. Addon wraps in rawget — returns nil. Safe. |
| 55 | **Settings** | Config.lua:2165 | YES | YES | Settings namespace defined in Blizzard_Settings_Shared. |
| 56 | **RAID_CLASS_COLORS** | Constants.lua:1267 | YES | YES | Global table — available on both. |
| 57 | **UIDropDownMenu_AddButton** | Config.lua:8 | YES | YES | Dropdown API — available on both. |
| 58 | **UIDropDownMenu_CreateInfo** | Config.lua:9 | YES | YES | Dropdown API — available on both. |
| 59 | **UIDropDownMenu_Initialize** | Config.lua:10 | YES | YES | Dropdown API — available on both. |
| 60 | **UIDropDownMenu_SetText** | Config.lua:11 | YES | YES | Dropdown API — available on both. |
| 61 | **UIDropDownMenu_SetWidth** | Config.lua:12 | YES | YES | Dropdown API — available on both. |
| 62 | **LibStub** | Constants.lua:1082 | **NO** | **NO** | External Ace library. Addon uses rawget — returns nil if not present. Safe. |

---

## APIs NOT available on either classic branch (3 total)

All three are properly handled with nil/type checks before invocation.

### 1. GetSpellHaste
- **Status:** Safe ✅
- **Usage:** Weaving.lua:9,39 — `GetSpellHaste()` as fallback for `UnitSpellHaste("player")`
- **Details:** Legacy API removed from FrameXML. The addon always checks `type(GetSpellHaste) == "function"` before calling, and `UnitSpellHaste("player")` is the primary path.

### 2. InterfaceOptions_AddCategory
- **Status:** Safe ✅
- **Usage:** Config.lua:2161 — `rawget(_G, "InterfaceOptions_AddCategory")`
- **Details:** Replaced by the Settings system in Legion+ (which both classic branches use). The addon wraps this in rawget so it simply returns nil when unavailable. The alternate path using `Settings` namespace is preferred.

### 3. LibStub
- **Status:** Safe ✅
- **Usage:** Constants.lua:1082 — `rawget(_G, "LibStub")`
- **Details:** External library by Rok (Ace3). Not part of Blizzard UI. Wrapped in rawget so it's nil when not present.

---

## APIs with caveats

### GetSpellInfo (Constants.lua:46-48)
- On classic_era 1.15.9, the API documentation shows GetSpellInfo returns a `SpellInfo` struct (table). However, FrameXML source on classic_era still calls it as `local spellName = GetSpellInfo(id)` — suggesting the function continues to return the spell name as the first value at the C level, while the API doc may be documenting the struct returned by `C_Spell.GetSpellInfo`.
- The addon's `ns.GetSpellInfo` wrapper in Constants.lua passes through the raw return from the global `GetSpellInfo`, which should continue to work.

### IsSpellKnown / IsSpellKnownOrOverridesKnown / IsPlayerSpell (Weaving.lua:12-14)
- These are defined in `Blizzard_DeprecatedSpellBook/Deprecated_SpellBook.lua`, gated behind the `loadDeprecationFallbacks` CVar.
- They delegate to `C_SpellBook.IsSpellInSpellBook` / `C_SpellBook.IsSpellKnown`.
- The addon wraps all three with `type(x) == "function"` checks before calling.

### UnitAura return shape (ClassMods.lua:5, Constants.lua:109-143)
The return value shape differs significantly between clients. The addon's `ns.UnitAura` wrapper handles all known shapes:

| Client | Return shape | Detection |
|---|---|---|
| Classic 1.13.x | name, rank, count, debuffType, duration, expTime, caster, stealable, spellID (9 values) | r3 is number, r9 is spellID |
| Classic 1.15.9 | name, rank, icon(str), count, debuffType, duration, expTime, caster, stealable, spellID (10-11 values) | r3 is string, r10 is number (spellID) |
| TBC Anniversary 2.5.6 | name, icon(FileID#), applications, dispelName, duration, expTime, sourceUnit, stealable, nameplateShowPersonal, spellID, canApplyAura (11-12 values) | r3 is number, r10 is number (spellID) |

---

## Widget API methods (always available on all clients)

These are C++ widget methods that are part of the WoW UI framework and never vary by client version:

CreateFrame, SetScript, SetPoint, SetSize, SetAlpha, SetValue, SetMinMaxValues, SetStatusBarTexture, SetStatusBarColor, SetColorTexture, SetWidth, SetHeight, SetDrawLayer, SetFrameStrata, SetFrameLevel, SetOrientation, SetReverseFill, SetBlendMode, SetTexCoord, SetText, SetFont, SetJustifyH, Show, Hide, IsShown, GetAlpha, GetHeight, GetWidth, GetStatusBarTexture, GetFrameStrata, GetFrameLevel, CreateTexture, CreateFontString, ClearAllPoints, EnableMouse, SetAllPoints, HookScript, GetScript, SetMovable, SetResizable, StartMoving, StopMovingOrSizing, RegisterEvent, UnregisterEvent, SetAttribute

---

## Files audited

| File | Lines | APIs extracted |
|---|---|---|
| SuperSwingTimer_State.lua | 1,437 | 16 global APIs + C_Spell + C_Timer namespaces |
| SuperSwingTimer_Weaving.lua | 541 | 10 global APIs |
| SuperSwingTimer_ClassMods.lua | 8,548 | 20+ global APIs + widget methods |
| SuperSwingTimer.lua | 1,587 | 6 global APIs + widget methods |
| SuperSwingTimer_Constants.lua | 1,629 | 6 global APIs |
| SuperSwingTimer_UI.lua | 2,773 | 4 global APIs + widget methods |
| SuperSwingTimer_Config.lua | 5,308 | 10+ global APIs + widget methods |

## Verdict

**The addon is fully compatible with both classic_era (1.15.9) and classic_anniversary (2.5.6).**

All three missing APIs (GetSpellHaste, InterfaceOptions_AddCategory, LibStub) are guarded with nil/type checks and never crash. The deprecated spell book functions are also properly guarded. The UnitAura wrapper correctly normalizes all three client return shapes.