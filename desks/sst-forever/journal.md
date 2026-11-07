# Desk: sst-forever

**Purpose:** make SuperSwingTimer load and run correctly on WoW Forever (1.60.1.70790)
by gating every Forever-restricted path, without changing behavior on Classic Era,
TBC Anniversary, or Titanforge.

**Scope:** /home/sam/SuperSwingTimer-WoW (write), /home/sam/wow-ui-source
(read-only, branch `forever`). No game install folders. No destructive git.

**Rule from operator:** do not remove features to make Forever work — gate them.
Interface version is correct and out of scope.

**Evidence grades:** verified (addon code / wow-ui-source), in-game, open.

## 2026-11-06 — Desk opened; Forever gate audit

- state: open
- did:
  - Confirmed Forever API surface from origin/forever:
    C_SwingTimer.{EnableRangeCheck, IsTargetWithinSwingRange}, PLAYER_SWING
    (swingDuration, swingType), PLAYER_SWING_RANGE_UPDATE, Enum.PlayerSwingType
    {MainHand=0, OffHand=1, Ranged=2}.
  - Confirmed secret-value predicates: C_Secrets.HasSecretRestrictions,
    ShouldUnitSpellCastingBeSecret, ShouldUnitStatsBeSecret, ShouldUnitPowerBeSecret,
    ShouldUnitIdentityBeSecret; sanitizers `scrub` / `scrubsecretvalues`;
    `issecretvalue`.
  - Confirmed secret-returning APIs the addon calls: UnitAttackSpeed,
    UnitRangedDamage, UnitCastingInfo, UnitChannelInfo, UnitHealth, UnitHealthMax,
    UnitPower, UnitPowerMax, UnitGUID, UnitName, GetSpellCooldown, C_Spell.GetSpellCooldown.
- next: gate every call site; add Forever regression tests; bump version.

## 2026-11-06 — [signal:done] Forever gate hardened; v0.3.0 prepared

- state: done (working tree; in-game verification pending)
- did:
  - Audited every Forever-restricted call site against origin/forever docs
    (secret markers, C_SwingTimer, C_CombatLog.IsCombatLogRestricted,
    scrubsecretvalues). 17 defect groups fixed, all additive gates.
  - Removed the `SafeNumber(x) or tonumber(x)` fall-through that re-read
    secret values; hardened aura/cooldown tables, cast payloads, spellcast
    payloads, GUID/name comparisons, power/health reads.
  - Corrected the CLEU gate to the authoritative client query; kept
    PLAYER_SWING ownership of the native swing duration.
  - Bumped TOC + Lua fallbacks + tests + README + CHANGELOG to v0.3.0.
  - Gates: 171/171 tests, luac clean, luacheck 0/0.
  - Bench: bench/findings-sst-forever-0.3.0.md.
- next: operator in-game check on WoW Forever (/sst diag), then tag/zip v0.3.0.


## 2026-11-06 — Second pass: pass-through + full coverage

- state: done (working tree; in-game verification pending)
- did:
  - Re-scanned all 194 secret-bearing function entries in origin/forever docs
    against every runtime file; remaining call sites are gated.
  - Implemented pass-through: secret UnitPower/UnitPowerMax now render through
    SetMinMaxValues/SetValue/SetFormattedText, secret enemy UnitName renders
    through SetText, bar labels display secret text without comparing it.
    (SetValue/SetMinMaxValues/SetText/SetFormattedText are AllowedWhenTainted.)
  - Gated UnitPowerType (powerType/powerToken), the secret BarValue readback in
    GetBarProgressFraction, the legacy UnitAura fallback, and the CLEU payload
    (7 fields).
  - PLAYER_SWING is now the single owner of swing starts/flashes when present,
    so CLEU cannot double-start the same swing.
  - Removed all truthiness tests on raw secret API returns (8 sites).
  - Added C_Secrets.HasSecretRestrictions() build-level fast path.
  - Tests 171 -> 173; bench findings updated (F18-F27).
- next: operator in-game check on WoW Forever (/sst diag), then tag/zip v0.3.0.


## 2026-11-07 — Hotfix: ranged cycle + fail-open detector

- state: done (working tree; awaiting in-game confirmation)
- did:
  - Traced the 120x "numeric conversion on a secret number" error to
    GetPlayerRangedHastePercent, which StartSwing("ranged") calls before writing
    the timer. Every ranged start aborted; melee was unaffected.
  - Removed both fail-open paths in ns.IsSecretValue (build-flag fast path and
    probe self-test) and added behavioural probes; SafeNumber now pcall-wraps
    tonumber and re-verifies the result.
  - Restored the CLEU Auto Shot fallback with a 1s native-start guard.
  - Added /sst diag "secrets" and "ranged" lines for in-game proof.
  - Tests 173/173; bench updated with the root-cause trace.
- next: operator reinstalls, runs /sst diag, and reports the secrets/ranged lines.


## 2026-11-07 — Forever native aura groups (buffs/debuffs) + class data

- state: done (working tree; in-game verification pending)
- did:
  - Root cause: C_UnitAuras.GetAuraDataByIndex is SecretWhenUnitAuraRestricted;
    while restrictions are active every AuraData field except auraInstanceID /
    isHelpful / isHarmful / isFromPlayerOrPlayerPet / isNameplateOnly / isRaid
    may be secret, so the classic scan-and-match path cannot identify an aura.
    ns.UnitAura correctly returns nil, which is why buff icons and debuff bars
    went blank on Forever.
  - New SuperSwingTimer_Forever.lua (loaded last, inert off Forever) declares
    the tracked spell IDs to the client's AuraContainer intrinsics
    (CustomAuraContainerTemplate). The client matches auras in secure code and
    writes icon/duration/stacks/bar values; no secret value enters addon logic.
  - Buff row (player, HELPFUL) shown only while ns.IsAuraDataSecret(); classic
    icon groups keep running whenever auras are readable (cooldown-only icons,
    4s glow and formatting preserved). Debuff row (target, HARMFUL|PLAYER) is
    additive and always available, with a 3px duration bar and stack count.
  - Anchoring reuses ns.debuffStackIconOffset published by RestackDebuffBars.
  - Forever class data from bench/forever-melee-changes.md folded in: new
    Warrior/Rogue/Druid/Shaman/Paladin/Hunter buffs and debuffs; removed Mangle,
    Faerie Fire (Feral), Seal of Vengeance/Corruption.
  - /sst diag "auraGroup" line; Forever Debuff Icon Group toggle.
  - Tests 173 -> 184 (SST-ForeverAura incl. recording-container wiring test).
- open: live-client check of AuraContainer creation (/sst diag auraGroup);
  Slam 1240193 + Improved Slam 12862 swing-delay rule; Windfury proc
  PLAYER_SWING filtering; server-derived debuff aura IDs.
- next: operator reinstalls, reports /sst diag auraGroup + secrets lines, then
  verify buffs/debuffs in combat on Forever.

## 2026-11-07 — Shaman weaving + Forever rank/aura-ID audit

- state: done (working tree; in-game verification pending)
- did:
  - Maelstrom Weapon: aura 408505 (Instant, 30 s, -20% Lightning Bolt; verified
    on Wowhead Forever + ForeverDB), talent 408498 (Enhancement tier 6, 5
    ranks). Forever only: scan 408505 then 408498; apply the reduction to
    Lightning Bolt only; reset stale stacks when the aura is unreadable; clear
    the cache on a successful Lightning Bolt.
  - Weave marker: recomputed from the live MH swing duration every frame, and
    ClearWeavePreview() now runs when the render loop idles so a previous
    swing's breakpoint cannot stay on screen.
  - Debuff ownership: the native row uses HARMFUL|PLAYER (client own-caster
    filter), so another hunter's Serpent Sting or shaman's Flame Shock never
    replaces yours on a shared mob.
  - Aura-ID audit: direct debuffs use the cast ID (verified Serpent Sting
    25295, Flame Shock 29228, Rend 11574, Thunder Clap 6343, Demo Shout 1160,
    Sunder Armor 7386); triggered talents differ (Flurry 12320, Vengeance
    20050, Seal of Fury 1311647, Venom 1310703, Deep Wounds 12721).
  - Rank audit: Serpent Sting 25295, Hunter's Mark 14323-14325, Wing Clip
    14267/14268, Frost Shock 8058/10472/10473, Rupture 11275, Rake 9904 (9907
    is Faerie Fire; shared table bug fixed), Faerie Fire/Demo Roar/Lacerate/
    Judgement ranks, all verified buff ranks + triggered buff IDs.
  - New Forever abilities added as per-class candidates.
  - /sst diag: maelstrom + weave lines.
  - Tests 184 -> 191.
- open: in-combat Maelstrom stacks may be secret (the native icon displays
  them; the weave math falls back to 0); Bloodthirst / Shaman Flurry buff aura
  IDs are not published; live AuraContainer check still pending.
- next: operator runs /sst diag (auraGroup, maelstrom, weave) and checks
  Serpent Sting / Flame Shock ownership in combat.
