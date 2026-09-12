# Performance Guidelines, Frame Safety & Gotchas

## 1. OnUpdate Performance Rules

- **Zero Table Allocations in Hot Paths**:
  - `OnUpdate` handlers execute up to 144+ times per second. Never create tables `{}` inside an `OnUpdate` script.
  - Reuse pre-allocated module tables (e.g. `activeIcons`, `seenAuras`) or static scratch buffers.
- **Local Function Caching**:
  - Cache global library functions at file scope: `local math_max = math.max`, `local math_min = math.min`, `local math_sin = math.sin`.
- **Throttled Updates**:
  - Buff icon scans, latency queries, and power checks run on explicit elapsed timers (`paladinBuffTimer`, `speedCheckTimer`, `latencyRefreshTimer`) rather than re-running heavy aura scans on every single frame.

## 2. Combat Lockdown & Secure Execution

- SuperSwingTimer is an informational visual addon and does **not** create or modify SecureActionButton frames.
- **Safe in Combat**: Moving, resizing, and showing/hiding custom non-secure status bars (`SuperSwingTimerMHBar`, `SuperSwingTimerPlayerPowerBar`) is 100% permitted during combat lockdown (`InCombatLockdown()`).
- Never anchor or re-parent non-secure frames to protected Blizzard action bars or unit frames while in combat.

## 3. Frame Strata & Draw Layers

- **Strata Order**:
  - Background/Backdrop: `BACKGROUND`
  - Bars (`mhBar`, `ohBar`, `rangedBar`, `enemyBar`): `MEDIUM`
  - Power Bar (`playerPowerBar`): `MEDIUM` (or matched to `mhBar`), `FrameLevel + 1`
  - Weave Spark Overlay (`weaveSpark`): Dedicated child frame at `FrameLevel + 6` to guarantee it renders overtop bar fills and borders
  - Buff & Cooldown Icons: `DIALOG` strata, positioned above active debuff duration bars
- **Draw Layers within Frames**:
  - Bar Background: `BACKGROUND`
  - Status Bar Texture: `ARTWORK`
  - Spark & Indicators: `OVERLAY`
  - Text & Labels: `OVERLAY`

## 4. Common FrameXML Pitfalls

- **`STANDARD_TEXT_FONT`**: Always use `rawget(_G, "STANDARD_TEXT_FONT")` before falling back to Western `"Fonts\\FRIZQT__.TTF"`.
- **Border Offsets**: Always create explicit 4-texture borders (`top`, `bottom`, `left`, `right`) with direct numeric coordinate offsets.
- **Power Colors**: In Classic FrameXML, `PowerBarColor[powerType]` is a table `{ r, g, b }`, not tuple return arguments.
- **Spell Info APIs**: Use `C_Spell.GetSpellInfo` if present, but fallback to `GetSpellInfo(id)` which returns `name, rank, icon, castTime, minRange, maxRange, spellID`. Note that `castTime` in `GetSpellInfo` is in milliseconds (divide by 1000 for seconds).
