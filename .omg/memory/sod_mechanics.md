# Season of Discovery (SoD 1.15.x) Integration

## 1. Rune Architecture (`SuperSwingTimer_SoD.lua`)

Season of Discovery introduces runes that alter standard swing dynamics, rotation priorities, and spell cast mechanics across all physical classes.

## 2. Tracked Runes & Aura Mappings

- **Warrior**:
  - Rampage: Active spell ID `426940`, Proc Buff `426942`.
  - Quick Strike (`429765`), Raging Blow (`402911`).
  - Devastate (`407133` / `407135`), Blood Surge Slam (`413380` / `413399`).
  - Precise Timing (`426956`), Sudden Death proc alert (`440114`).
- **Rogue**:
  - Saber Slash (`402780`), Main Gauche (`409509`).
  - Envenom (`400011`), Blade Dance (`400012`).
  - Mutilate (`409510` / `409513`), Shadowstrike (`400029`), Quick Draw (`409898`).
  - Poison Knife (`424785`), Crimson Tempest (`412096`), Secret Technique (`426640`).
- **Shaman**:
  - Way of Earth (`408531`), Shield Mastery (`408527`), Molten Blast (`408247`).
  - Lava Lash (`408507`), Fire Nova (`408331`), Dual Wield Spec (`408498`).
  - Power Surge (`415100` - instant Lava Burst / Chain Lightning).
  - Maelstrom Weapon (`408505` - 20% cast time reduction per stack, instant at 5 stacks).
- **Hunter**:
  - Melee Specialist (`415318`), Dual Wield Specialization (`425515`).
  - Aspect of the Viper (`415423`), Flanking Strike (`415320`), Carve (`425711`).
  - Chimera Shot (`53209` / `409433`), Explosive Shot (`53301` / `409552`).
- **Paladin**:
  - Aegis (`407630`), Hand of Reckoning (`409859`), Guarded by the Light (`408435`).
  - Sacred Shield (`407627`), Fanaticism (`408434`), Art of War (`408432`).
  - Divine Storm (`407778`), Crusader Strike (`409553`), Hammer of the Righteous (`409456`).
- **Druid**:
  - Savage Roar (`407988`), Wild Strikes (`407982`), Berserk (`417141`).
  - Mangle Cat/Bear (`3355` / `409805` / `33878` / `409804`), Lacerate (`414644`).
  - Sunfire Cat/Bear (`414689` / `414684`), Survival Instincts (`408005`).

## 3. Dynamic Spell Injection

- In `SuperSwingTimer_ClassMods.lua`, SoD runes are conditionally merged using:

  ```lua
  if ns.SOD_TRACKED_SPELLS and ns.SOD_TRACKED_SPELLS[playerClass] then
      MergeTrackedSpells(TRACKED_SPELLS, ns.SOD_TRACKED_SPELLS[playerClass])
  end
  ```

- `MergeTrackedSpells` de-duplicates entries by name and merges alternate spell IDs into `existing.altSpellIds` to avoid duplicate buff/CD icons.
