# Task Completion Checklist

Before considering any task complete in SuperSwingTimer, verify each of the following:

## 1. Zero-Warning Lint Pass

Run the linter across all codebase files from the project root:
```bash
luacheck .
```
- Must produce **0 warnings and 0 errors**.
- Do not add ad-hoc suppression comments unless handling false positives documented in `.luacheckrc`.

## 2. Configuration & Migration Integrity

- If adding or changing default settings, ensure keys are defined in `ns.DB_DEFAULTS` (`SuperSwingTimer_Constants.lua`).
- If schema changes are required:
  - Increment `ns.DB_CURRENT_VERSION` in `SuperSwingTimer.lua`.
  - Add sequential migration logic inside `MigrateDB()` preserving legacy and existing user profiles.

## 3. Localization & Font Safety Check

- Verify no hardcoded `"Fonts\\FRIZQT__.TTF"` or Western font strings were introduced.
- Confirm all font paths use `ns.GetDefaultFont()` or `GetFontPath()`.

## 4. Dual-Client API Safety

- Verify any new WoW API calls have safe fallbacks for both Classic Era (`11509`) and TBC Anniversary (`20506`).
- Reference `wow-ui-source` (`classic_era` and `bcc` branches) if unsure about return types or event signatures.

## 5. In-Game Testing

- In a running WoW client, run `/ssttest` to execute the WoWUnit test suite.
- Test preview bars with `/sst test` and test locking with `/sst lock` / `/sst unlock`.

## 6. Serena Memories Check

Run from project root:
```bash
serena memories check
```
Verify that all referenced memories exist and references are intact.