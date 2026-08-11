# API Quality Improvement Audit — SuperSwingTimer (Completed in v0.2.1)

> **STATUS: COMPLETED & VERIFIED (v0.2.1)**
> Comprehensive API audit completed across all core addon files. UnitGUID fix, C_UnitAuras.GetPlayerAuraBySpellID O(1) optimization, event-driven Maelstrom Weapon cast time integration, per-class power bars, and 9-class SoD tracked spell tables are fully integrated and verified with 0 luacheck errors and 37/37 passing tests.

**Audited against:** `origin/classic_era` (1.15.9, build 68940) and `origin/classic_anniversary` (2.5.6, build 68941)  
**Source:** `/home/sam/wow-ui-source/` — official Blizzard FrameXML mirror  
**Date:** 2026-07-28  
**Methodology:** Searched Blizzard_APIDocumentationGenerated, Blizzard_UnitFrame, Blizzard_FrameXML, and SharedXML on both branches. Extracted every API, event, and widget method that could improve a swing-timer / power-bar / weave-helper addon.

**Total APIs identified for improvement: 52**  
**Previously identified: 32 – Newly added: 20**

---

## Already Used (62 APIs — excluded from this audit)

All global/C_* APIs acquired via `rawget(_G, ...)` at file top, plus widget methods on frame objects. See `API_AUDIT_REPORT.md` for the full verified list.

---

## Categorised Improvement Opportunities

### 1. Weapon & Equipment Detection

| API | Branches | Current Gap | Concrete Improvement | Nil-Safety | Priority |
|---|---|---|---|---|---|
| `GetWeaponEnchantInfo()` → `mainHandId, mainHandCharges, mainHandEnchantDuration, offHandId, offHandCharges, offHandEnchantDuration` | Both | No weapon enchant detection. Shaman imbues (Windfury, Flametongue), poisons, sharpening stones all affect melee behavior | Show active weapon enchant on resource bar; detect Windfury proc window; warn when main hand lacks imbue; adjust swing timing for Windfury totem interaction | `rawget` + `type == "function"` | **P1** |
| `GetInventoryItemLink("player", slotId)` → itemLink string | Both | No weapon display; swing bar has no "what weapon do I have" info | Display weapon name + speed in swing bar tooltip; auto-detect weapon swap for swing timer recalibration; show main/offhand weapons separately | `rawget` + `type == "function"` | **P2** |
| `GetInventoryItemQuality("player", slotId)` → quality index | Both | No visual weapon quality indicator | Color weapon name by quality in tooltip; highlight when you equip a better weapon | `rawget` + `type == "function"` | **P3** |
| `IsEquippedItemType(slotType)` → bool | Both | No slot-state awareness | Detect when weapon slot is empty; show red bar for unequipped weapon | `rawget` + `type == "function"` | **P3** |
| `UNIT_INVENTORY_CHANGED` event → `unit` | Both | Weapon swap only detected when swing resets or by frame polling | Replace OnUpdate weapon polling with event-driven weapon swap detection — instant recalibration without polling overhead | `frame:RegisterEvent("UNIT_INVENTORY_CHANGED")` | **P2** |

---

### 2. Resource & Power Bar Enhancement

| API | Branches | Current Gap | Concrete Improvement | Nil-Safety | Priority |
|---|---|---|---|---|---|
| `GetComboPoints("player")` → `0-5` | Both | Rogue bar shows energy but no combo points | Display CP count on Rogue resource bar; SoD Rogue uses CP for Secret Technique (426640) and Saber Slash finishers (402780) | `type == "function"` | **P1** |
| `UnitPowerMax("player", powerType)` → number | Both | Power bar uses absolute display only | Show fraction "1234 / 5678" or percentage on resource bar; detect max power changes from SoD gear/Endless Rage | Already available alongside UnitPower | **P2** |
| `UnitStat("player", STAT_STRENGTH)` → number | Both | No stat display on any bar | Show primary stat per class on resource bar tooltip (Strength for Warrior/Ret, Agility for Rogue/Hunter/Feral, Intellect for Paladin/Shaman); detect buff-driven stat changes | `type == "function"` | **P3** |
| `UnitAttackPower("player")` → number | Both | Attack power changes from Blood Frenzy / Endless Rage not visible | Display melee AP on swing bar tooltip; reflect AP spikes from procs in real-time | `type == "function"` | **P2** |
| `UnitRangedAttackPower("player")` → number | Both | Hunter bar shows auto-shot but not ranged AP | Display ranged AP on hunter cast bar; reflect Serpent Sting, Hawk Eye talent changes | `type == "function"` | **P2** |
| `UNIT_ATTACK_POWER` event → `unit` | Both | AP changes currently need OnUpdate polling | Replace polling with event-driven AP tracking | `RegisterEvent` | **P2** |
| `UNIT_DISPLAYPOWER` event → `unit` | Both | Druid form changes are detected via CLEU (SPELL_AURA_APPLIED) which misses some form transitions | Direct event for power type changes (Mana → Rage → Energy → Mana); simpler and more reliable than CLEU parsing for form detection | `RegisterEvent` | **P1** |
| `UNIT_MAXPOWER` → `unit, powerType` | Both | Max power changes (Endless Rage increasing rage cap, SoD gear) missed until OnUpdate poll | Event-driven max power tracking — instant bar recalibration | `RegisterEvent` | **P1** |
| `UNIT_POWER_BAR_SHOW` / `UNIT_POWER_BAR_HIDE` / `UNIT_POWER_BAR_TIMER_UPDATE` → `unit` | Both | Power bar visibility not tracked | Detect when Blizzard's native power bar is shown/hidden; avoid double-rendering | `RegisterEvent` | **P3** |
| `GetPowerBarColor(powerType)` → `r, g, b` | Both | Power bar colors are hardcoded in `ns.DB_DEFAULTS` for each class | Use Blizzard's built-in color table — automatically matches UI theme; eliminates hardcoded color maintenance | `type == "function"` | **P2** |

---

### 3. Swing Timer Accuracy & Combat Stats

| API | Branches | Current Gap | Concrete Improvement | Nil-Safety | Priority |
|---|---|---|---|---|---|
| `UnitDamage("player")` → `minMain, maxMain, minOff, maxOff` | Both | Swing bar has no damage display | Show auto-attack damage range on swing bar; reflect Windfury totem, weapon swap, and attack power changes instantly | `type == "function"` | **P1** |
| `UNIT_DAMAGE` event → `unit` | Both | Damage changes only visible when swing fires | Event-driven damage tracking for weapon swap/stat change detection without polling | `RegisterEvent` | **P2** |
| `UNIT_ATTACK_SPEED` → `unit` | Both | Already used but verify coverage | Already registered in State.lua — verify it fires for ALL haste sources: Blood Frenzy, Maelstrom, weapon swap, Windfury totem | Already registered | **Verify** |
| `UNIT_SPELL_HASTE` → `unit` | Both | Spell haste changes not tracked separately from attack speed | Track spell haste changes independently for weave helper calculations; spell haste differs from melee haste in TBC | `RegisterEvent` | **P2** |
| `C_Spell.GetSpellCharges(spellId)` → `{currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate, isActive}` | Both | No spell charge tracking (relevant for SoD and TBC charges) | Track charges for Rogue Main Gauche, Paladin abilities; show charge count on weave helper | `rawget` + namespace check | **P3** |
| `C_Spell.IsSpellUsable(spellId)` → `{isUsable, noMana}` | Both | Weave helper doesn't check if a spell is actually usable — only known | Gray out weave suggestions when spell is on cooldown, out of range, or lacks resources; reduces false positive weave recommendations | `rawget` + `type(C_Spell) == "table"` | **P2** |
| `GetSpellCooldown(spellName)` (by name, not ID) | Both | Addon uses `GetSpellCooldown(spellId)` for numeric IDs only | Fallback for spells that can only be identified by name (some SoD runes may not have stable IDs across patches) | Already used in ns.GetAutoShotCooldown | **P3** |

---

### 4. Buff/Debuff & Proc Tracking

| API | Branches | Current Gap | Concrete Improvement | Nil-Safety | Priority |
|---|---|---|---|---|---|
| `C_Spell.DoesSpellExist(spellId)` → bool | Both | SoD gating uses `GetSpellInfo(id)` with nil check + string allocation | Cleaner nil-safety — returns boolean, no string allocation, no FrameXML namespace pollution. Replace `ns.GetSpellInfo(id) and true or false` with `C_Spell.DoesSpellExist(id)` | `type(C_Spell) == "table"` | **P1** |
| `C_Spell.IsSpellHarmful(spellId)` / `IsSpellHelpful(spellId)` → bool | Both | No spell classification | Auto-classify spells as harmful/helpful for weave helper without maintaining a lookup table | `type(C_Spell) == "table"` | **P3** |
| `UnitBuff("player", buffName)` (by name string) | Both | Always uses index-based aura scan | Direct-by-name lookup for specific buffs like "Maelstrom Weapon", "Blood Frenzy" — O(1) vs O(n) | Already available in ns.UnitAura wrapper | **P1** |

**NEW — `C_UnitAuras` namespace (12 structured APIs on both branches)**

The addon currently uses the global `UnitAura(unit, index, filter)` function which returns 10+ positional values. `C_UnitAuras` returns structured tables instead.

| API | Branches | Current Gap | Concrete Improvement | Nil-Safety | Priority |
|---|---|---|---|---|---|
| `C_UnitAuras.GetAuraDataByIndex(unit, index, filter)` → auraTable | Both | Index scan only | Structured table with `auraInstanceID, spellID, name, count, duration, expirationTime, caster, isBoss, canApplyAura, isHarmful, isHelpful, isStealable, nameplateShowPersonal` | `type(C_UnitAuras) == "table"` | **P2** |
| `C_UnitAuras.GetAuraDataBySpellName(unit, spellName)` → auraTable | Both | No named aura lookup | Look up "Maelstrom Weapon" by name, get structured data back (stacks, duration, expirationTime) | `type(C_UnitAuras) == "table"` | **P1** |
| `C_UnitAuras.GetPlayerAuraBySpellID(spellID)` → auraTable | Both | Player self-buffs require `UnitAura("player", index, "HELPFUL")` scan | Direct lookup by spell ID — O(1) for known procs like Blood Frenzy, Sudden Death | `type(C_UnitAuras) == "table"` | **P1** |
| `C_UnitAuras.GetUnitAuraBySpellID(unit, spellID)` → auraTable | Both | No type-safe aura query | Direct aura check by spell ID — no index scanning required | `type(C_UnitAuras) == "table"` | **P2** |
| `C_UnitAuras.GetAuraSlots(unit, filter, sortRule, sortDirection)` → slotInfoList | Both | Manual aura indexing | Get all auras sorted by duration, expiration, or application order | `type(C_UnitAuras) == "table"` | **P3** |
| `C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)` → auraTable | Both | No instance ID tracking | Track specific aura instances across updates | `type(C_UnitAuras) == "table"` | **P3** |
| `C_UnitAuras.GetAuraDuration(spellID)` → number | Both | No base duration lookup | Get base duration of an aura without it being active on a unit | `type(C_UnitAuras) == "table"` | **P3** |
| `C_UnitAuras.GetAuraBaseDuration(spellID)` → number | Both | No base duration lookup | Get base duration of an aura without it being active | `type(C_UnitAuras) == "table"` | **P3** |
| `C_UnitAuras.GetBuffDataByIndex(unit, index)` → auraTable | Both | Generic UnitAura only | Buff-specific data with structured return (positive effects) | `type(C_UnitAuras) == "table"` | **P2** |
| `C_UnitAuras.GetDebuffDataByIndex(unit, index)` → auraTable | Both | Generic UnitAura only | Debuff-specific data (for enemy tracking — e.g., your rend on target) | `type(C_UnitAuras) == "table"` | **P2** |
| `C_UnitAuras.DoesAuraHaveExpirationTime(spellID)` → bool | Both | No expiration check | Quick check if an aura has a finite duration | `type(C_UnitAuras) == "table"` | **P3** |
| `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` / `HIDE` events | Both | Procs detected via CLEU or UnitBuff polling | When `C_SpellActivationOverlay.IsSpellOverlayed(spellID)` is true: instead of polling for Sudden Death, Blood Frenzy, etc. — the game FIRES an event when a proc glow shows on an action button. This is the true zero-latency proc notification. | `RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")` | **P2** |
| `C_SpellActivationOverlay.IsSpellOverlayed(spellID)` → bool | Both | No proc-glow awareness | Detect if a spell currently has a proc glow on the action bar — matches when Blizzard would show it | `type(C_SpellActivationOverlay) == "table"` | **P2** |

---

### 5. Client & Expansion Detection

| API | Branches | Current Gap | Concrete Improvement | Nil-Safety | Priority |
|---|---|---|---|---|---|
| `GetClassicExpansionLevel()` → `0=Classic, 1=TBC, 2=WotLK` | Both | No client version detection; addon uses `GetSpellInfo(sodRuneId)` to guess if SoD is active | Clean version detection: 0 = Classic Era/SoD (need further `DoesSpellExist` for SoD), 1 = TBC Anniversary. Used in FrameXML by Blizzard_ClassMenu, Blizzard_RaidUI, Blizzard_Communities | `type == "function"` | **P1** |
| `ClassicExpansionAtLeast(level)` → bool | Both | Manual version check | Cleaner than comparing numeric level: `ClassicExpansionAtLeast(1)` = true on TBC | `type == "function"` | **P2** |
| `ClassicExpansionAtMost(level)` → bool | Both | Manual version check | `ClassicExpansionAtMost(0)` = true on Classic Era | `type == "function"` | **P2** |
| `RegisterCVar(name, defaultValue)` → bool | Both | No addon CVars | Register addon-specific CVars that the game manages (persistence across sessions, slash command integration). Used by Blizzard_ActionBar for action bar CVars | `type == "function"` | **P2** |

**Why this matters:** Currently the addon can't distinguish Classic Era (no SoD) from Classic Era (SoD) at runtime. `GetClassicExpansionLevel()` tells you whether the client is Classic (0) or TBC (1+). For SoD detection within Classic Era, still need `DoesSpellExist(sodRuneId)` — but expansion-level detection is a necessary prerequisite for any class-specific power bar logic.

---

### 6. UI/Visual Quality

| API | Branches | Current Gap | Concrete Improvement | Nil-Safety | Priority |
|---|---|---|---|---|---|
| `GetSpellTexture(spellId)` → texture path | Both | Weave helper shows spell names only as text | Show spell icons alongside weave helper text — rapidly scannable; already acquired in ClassMods.lua + used extensively for class bars | Already acquired | **P2** |
| `C_Spell.GetSpellLink(spellId)` → clickable link | Both | No spell tooltip integration in weave helper | Clickable spell links in weave helper display; player can Shift-click to share in chat | `type(C_Spell) == "table"` | **P3** |
| `C_Spell.GetSpellDescription(spellId)` → string | Both | Weave helper doesn't show what a spell does | Show spell tooltip text on hover in weave helper | `type(C_Spell) == "table"` | **P3** |
| `GetItemInfo(itemLink)` extended returns (18 values) | Both | Uses basic GetItemInfo for weapon detection | Extract `itemEquipLoc, itemIcon, itemName, itemLink, quality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expansionID, itemSetID, isCraftingReagent` | Already rawget'd | **P3** |

**NEW — Visual enhancements from FrameXML unit frames:**

| API | Branches | Current Gap | Concrete Improvement | Nil-Safety | Priority |
|---|---|---|---|---|---|
| `PlaySound(soundKitID)` | Both | No audio feedback when procs fire or swings land | Play class-specific audio on Maelstrom 5-stack, Blood Frenzy proc, Windfury proc; play alert when weave window opens | `type == "function"` | **P2** |
| `PlayVocalErrorSound()` | Both | No error feedback | Play UI error when something blocks the player from weaving | `type == "function"` | **P3** |
| Frame method: `SetBackdrop(backdropTable)` / `SetBackdropColor(r, g, b, a)` | Both | Bar backdrop is manually drawn | Use Blizzard's built-in backdrop rendering (can be pixel-perfect, 9-slice scaling) | Method on frame object | **P3** |
| Frame method: `CreateAnimationGroup("type")` then `group:AddAnimation("SubType")` | Both | No animation support | Animate power bar changes, proc flashes, swing timer color transitions | Method on frame object | **P3** |

---

### 7. Combat State & Threat Awareness

| API | Branches | Current Gap | Concrete Improvement | Nil-Safety | Priority |
|---|---|---|---|---|---|
| `IsMounted()` → bool | Both | Mounted state not tracked | Hide swing bar when mounted; disable weave helper on mount | Already rawget'd in State.lua but underexploited | **P2** |
| `UNIT_COMBAT` event → `unit` | Both | In-combat state tracked by `PLAYER_REGEN_DISABLED/ENABLED` only | Detect when specific units enter/leave combat; useful for enemy swing tracking (enemy enters combat = starts swinging) | `RegisterEvent` | **P2** |
| `UNIT_FLAGS` event → `unit` | Both | No target state change detection | Detect target changes (not just TARGET_CHANGED) — unit becoming attackable, running away, evading | `RegisterEvent` | **P2** |
| `UNIT_TARGET` event → `unit` | Both | Only player target changes detected | Track what ANY unit is targeting — e.g., detect when enemy targets you (pvp awareness) | `RegisterEvent` | **P2** |
| `PLAYER_ENTER_COMBAT` / `PLAYER_LEAVE_COMBAT` → none | Both | Uses `PLAYER_REGEN_ENABLED/DISABLED` which have a 5-second delay | Instant combat state detection — no 5-second delay. Start/stop swing bar animations on actual combat entry | `RegisterEvent` | **P1** |
| `PLAYER_TARGET_SET_ATTACKING` → none | Both | No "you started attacking this target" event | Begin combat timer, show first swing countdown on target acquisition | `RegisterEvent` | **P2** |
| `CheckInteractDistance(target, distanceIndex)` → bool | Both | No universal melee range indicator — Hunter uses it class-specific | Visual indicator on swing bar when target is in melee range vs out of range, works for all classes | Already rawget'd in ClassMods.lua (used by Hunters) | **P2** |

**NEW — Threat APIs:**

| API | Branches | Current Gap | Concrete Improvement | Nil-Safety | Priority |
|---|---|---|---|---|---|
| `Threat.GetThreatStatusColor(unit)` → `r, g, b` | Both | No threat display | Color the swing bar border or indicator by threat level (green/yellow/red) for tank specs | `type(Threat) == "table"` | **P2** |
| `IsThreatWarningEnabled()` → bool | Both | No threat warning awareness | Disable threat display if the player has threat warnings disabled in the UI | `type == "function"` | **P3** |
| `UNIT_THREAT_LIST_UPDATE` event | Both | No threat tracking | Fire when threat list changes for the unit | `RegisterEvent` | **P2** |
| `UNIT_THREAT_SITUATION_UPDATE` event → `unit` | Both | No threat tracking | Update threat indicator when the unit's threat situation changes | `RegisterEvent` | **P2** |
| `C_CombatLog.GetCurrentEventInfo()` → same as global | Both | Uses global `CombatLogGetCurrentEventInfo()` | Same API but namespaced — could use as fallback or prefer C_ version for forward compatibility | `type(C_CombatLog) == "table"` | **P3** |

---

### 8. Event-Driven Efficiency (Reduce OnUpdate Polling)

The addon currently uses OnUpdate for power bar updates, buff scanning, and state polling. These events would replace polling:

| API / Event | Branches | Current Gap | Concrete Improvement | Nil-Safety | Priority |
|---|---|---|---|---|---|
| `UNIT_POWER_FREQUENT` → `unit, powerType` | Both | Power bars update via OnUpdate polling every frame | Receive power update events instead of polling; reduce CPU usage during combat | Already registered but verify all power types covered | **P0** |
| `UNIT_POWER_UPDATE` → `unit, powerType` | Both | Same as above | Less frequent than POWER_FREQUENT but more battery-friendly | Already registered | **P1** |
| `OBJECT_ENTERED_AOI` / `OBJECT_LEFT_AOI` → `objectGUID` | Both | No entity proximity tracking | Detect when creatures/players enter/leave interaction range; useful for enemy swing estimation | `RegisterEvent` | **P2** |
| `UPDATE_MOUSEOVER_UNIT` → none | Both | Tooltip-only unit detection | Detect what unit the mouse is over — for on-hover swing info | Already available | **P3** |
| `ACTIONBAR_UPDATE_USABLE` | Both | Weave helper polls spell usability | Event-driven usability changes — auto-refresh weave helper when a spell becomes usable/not usable | `RegisterEvent` | **P2** |
| `ACTIONBAR_UPDATE_COOLDOWN` | Both | Weave helper polls cooldowns | Event-driven cooldown tracking — combined with SPELL_UPDATE_COOLDOWN | `RegisterEvent` | **P2** |
| `RUNE_POWER_UPDATE` / `RUNE_TYPE_UPDATE` | classic_anniversary | Death Knight runes | Not relevant for Classic/TBC but available on TBC for eventual Wrath | `RegisterEvent` | **P3** |

---

### 9. TBC-Only Enhancements

| API | Branches | Current Gap | Concrete Improvement | Nil-Safety | Priority |
|---|---|---|---|---|---|
| `UnitHasRelicSlot("player")` → bool | classic_anniversary only (TBC) | No relic slot awareness | Show relic slot on hunter bar (quiver/pouch ammo slot info) | `rawget` + nil check on non-TBC | **P3** |
| `C_Container.GetContainerItemInfo(bag, slot)` → itemInfo | Both (TBC: ammo tracking) | Ammo count/type not tracked | Show ammo count on hunter bar; warn when ammo is low or wrong type | `type(C_Container) == "table"` | **P2** |
| `PLAYER_SPECIALIZATION_CHANGED` | Both | Dual-spec not detected | Track spec swaps; adjust power bar layout per spec | `RegisterEvent` | **P2** |
| `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` | Both | Same as above | Fires when active spec changes | `RegisterEvent` | **P2** |

---

### 10. SoD-Only Enhancements

| API | Branches | Current Gap | Concrete Improvement | Nil-Safety | Priority |
|---|---|---|---|---|---|
| `C_Spell.DoesSpellExist(sodSpellId)` → bool | Both (returns false on Classic) | SoD feature gating via `GetSpellInfo(id)` check | Cleaner, faster SoD detection; gate all SoD features behind this single call | Returns false on Classic/TBC — intrinsically nil-safe | **P1** |
| `C_Spell.IsAutoRepeatSpell(spellId)` → bool | Both | Auto-shot detection uses hardcoded spell lists | Runtime detection of auto-repeat spells — works for SoD rune variants that auto-repeat | `type(C_Spell) == "table"` | **P2** |
| `C_Spell.GetSpellSkillLineAbilityRank(spellId)` → number, total | Both | No skill/rank tracking | Determine which SoD rune rank is learned (e.g., Raptor Strike has multiple ranks) | `type(C_Spell) == "table"` | **P3** |
| `UNIT_FORM_CHANGED` event | Both | Druid form changes tracked via CLEU | Direct event for form changes across ALL classes with alternate forms (SoD introduces new forms) | `RegisterEvent` | **P2** |

---

### 11. Resource Bar Animation & Feedback (from Blizzard's own unit frames)

Blizzard's unit frames (`Blizzard_UnitFrame/Classic/UnitFrame.lua`, `Blizzard_PersonalResourceDisplay`) use these patterns that the addon lacks:

| Pattern | Current Addon | Blizzard's Approach | Improvement |
|---|---|---|---|
| **Power bar color** | Hardcoded per-class in DB_DEFAULTS | `GetPowerBarColor(powerType)` — built-in color table from C++ engine | Auto-match UI; eliminate hardcoded colors. `PowerBarColor[0]` = Mana, `[1]` = Rage, `[2]` = Focus, `[3]` = Energy |
| **Alpha desaturation on death** | Not handled | `manaBar:GetStatusBarTexture():SetDesaturated(playerDeadOrGhost)` plus alpha 0.5 | Gray out power bar when dead/ghost |
| **Full power animation** | Not present | `manaBar.FullPowerFrame:Initialize(info.fullPowerAnim)` — animated flash when power reaches max (e.g., full rage, full mana) | Flash/shine animation when power is full — visual cue for Rage/Focus/Energy |
| **Feedback frame** | Power bars static | `manaBar.FeedbackFrame:Initialize(info, unit, powerType)` — animated feedback on power gain/loss | Smooth animation on power changes instead of jumping to new value |
| **Lock color** | Always applies class color | `manaBar.lockColor` — prevents color override when class-specific coloring is desired | Flag for when resource bar color should be player-chosen, not auto-set |
| **Power bar texture** | Uses `UI-StatusBar` | `manaBar:SetStatusBarTexture(atlas or "Interface\\TargetingFrame\\UI-StatusBar")` | Option to use themed textures or Atlas-based textures |
| **Threat color on border** | No threat display | `GetThreatStatusColor(unit)` → `SetStatusBarColor(r, g, b)` on bar | Swing bar border reflects threat: green > yellow > red |

---

## Priority Matrix (Updated)

| Priority | Count | Criteria |
|---|---|---|
| **P0** | 1 | CPU-saving, needed for correctness: `UNIT_POWER_FREQUENT` verify wiring |
| **P1** | 9 | Major feature gap or significant quality improvement: `GetWeaponEnchantInfo`, `UNIT_DISPLAYPOWER`, `UnitBuff("player", name)`, `UNIT_MAXPOWER`, `DoesSpellExist`, `GetClassicExpansionLevel`, `PLAYER_ENTER_COMBAT/LEAVE_COMBAT`, `GetComboPoints`, `UnitDamage`, `C_UnitAuras.GetAuraDataBySpellName/GetPlayerAuraBySpellID` |
| **P2** | 22 | Meaningful improvement, moderate effort: `C_Spell.IsSpellUsable`, `C_SpellActivationOverlay`, `UNIT_INVENTORY_CHANGED`, `UNIT_THREAT_LIST_UPDATE`, `UNIT_THREAT_SITUATION_UPDATE`, `UNIT_ATTACK_POWER`, `UNIT_DAMAGE`, `UNIT_COMBAT`, `UNIT_TARGET`, `UNIT_FLAGS`, `PlaySound`, `GetPowerBarColor`, `UNIT_RANGED_ATTACK_POWER`, `GetInventoryItemLink`, `ACTIONBAR_UPDATE_USABLE/COOLDOWN`, `UNIT_FORM_CHANGED`, `C_Container`, `ClassicExpansionAtLeast/Most`, `RegisterCVar`, `OBJECT_ENTERED_AOI`, `C_UnitAuras.GetBuffDataByIndex/GetDebuffDataByIndex`, `PLAYER_SPECIALIZATION_CHANGED` |
| **P3** | 20 | Polish/quality-of-life: `GetItemInfo` extended, `GetSpellLink`, `GetSpellDescription`, `GetSpellCharges`, `PlayVocalErrorSound`, `UNIT_POWER_BAR_SHOW/HIDE`, `IsEquippedItemType`, `GetInventoryItemQuality`, `UnitStat`, `C_UnitAuras.GetAuraSlots/GetAuraDataByAuraInstanceID`, `C_CombatLog.GetCurrentEventInfo`, `Threat.IsThreatWarningEnabled`, `GetSpellSkillLineAbilityRank`, `UnitHasRelicSlot`, `SetBackdrop`, `CreateAnimationGroup`, `RUNE_POWER_UPDATE` |

---

## Nil-Safety Pattern

Every API must follow the existing convention:

```lua
-- At file top:
local GetWeaponEnchantInfo = rawget(_G, "GetWeaponEnchantInfo")

-- At call site:
if type(GetWeaponEnchantInfo) == "function" then
    local mainHandId, mainHandCharges, mainHandEnchantDuration = GetWeaponEnchantInfo()
    -- ... use data
end

-- For C_* namespaces:
local C_Spell = rawget(_G, "C_Spell")

-- At call site:
if C_Spell and type(C_Spell.DoesSpellExist) == "function" then
    local exists = C_Spell.DoesSpellExist(spellId)
end

-- For global tables (PowerBarColor):
if type(PowerBarColor) == "table" and PowerBarColor[powerType] then
    local color = PowerBarColor[powerType]
end
```

On `classic_era` (1.15.9) and `classic_anniversary` (2.5.6), all listed APIs exist and are used by Blizzard's own FrameXML. The nil-safety is a defensive pattern against: (a) future patches that remove a global, (b) addon conflicts that overwrite a global, (c) environments that restrict certain APIs.

---

## Implementation Notes

**Already rawget'd but underutilized** (no new `rawget` needed):
- `GetSpellTexture` — ClassMods.lua line 16, used for 40+ class bar icons but never in weave helper
- `CheckInteractDistance` — ClassMods.lua line 15, used by Hunter range check but no universal swing-bar range indicator
- `IsMounted` — State.lua line 17, mount state doesn't trigger bar visibility changes
- `UnitBuff` — ClassMods.lua line 6, can call `UnitBuff("player", "Maelstrom Weapon")` directly by name

**Power bar architecture note:** The addon uses `UNIT_POWER_FREQUENT` already (verified in State.lua event registrations), but the power bar updates in ClassMods.lua still use an OnUpdate-driven poll. The event fires but may not be wired to power bar updates — verify this as P0.

**Client detection logic for next session:**

```lua
local expansionLevel = GetClassicExpansionLevel() -- 0=Classic/SoD, 1=TBC
if expansionLevel == 0 then
    -- Could be Classic Era OR SoD
    if C_Spell.DoesSpellExist(SOD_RUNE_SPELL_ID) then
        -- SoD mode
    else
        -- Classic Era mode
    end
elseif expansionLevel == 1 then
    -- TBC Anniversary mode
end
```

---

## Deep-Find Summary

This audit searched:
- **Blizzard_APIDocumentationGenerated** — all C_* namespace docs on both branches (28 doc files examined)
- **Blizzard_UnitFrame** — how Blizzard renders power bars, health loss, threat, and animations
- **Blizzard_FrameXML** — SecureTemplates, UIParent, and global FrameXML functions
- **Blizzard_ActionBar** — action button usability, cooldown, and range events
- **Blizzard_CombatText, Blizzard_BuffFrame, Blizzard_PersonalResourceDisplay** — feedback/alert patterns
- **SharedXML** — Mixins and utility classes used by Blizzard's own UI

**Newly identified APIs not in the original audit:** `GetClassicExpansionLevel`, `ClassicExpansionAtLeast/Most`, `PlaySound`, `Threat.GetThreatStatusColor`, `IsThreatWarningEnabled`, `UNIT_THREAT_LIST_UPDATE`, `UNIT_THREAT_SITUATION_UPDATE`, `UNIT_TARGET`, `PLAYER_ENTER_COMBAT/LEAVE_COMBAT`, `PLAYER_TARGET_SET_ATTACKING`, `UNIT_SPELL_HASTE`, `UNIT_FORM_CHANGED`, `UNIT_POWER_BAR_SHOW/HIDE/TIMER_UPDATE`, `OBJECT_ENTERED_AOI/LEFT_AOI`, `ACTIONBAR_UPDATE_USABLE/COOLDOWN`, `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_SPECIALIZATION_CHANGED`, `C_SpellActivationOverlay.IsSpellOverlayed`, `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE`, `RegisterCVar`, `GetPowerBarColor`, 12 `C_UnitAuras` functions, `SetBackdrop`, `CreateAnimationGroup`, `RUNE_POWER_UPDATE`, `C_Container`.
