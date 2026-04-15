# KB: Data-First Game Development

**Source:** Sprint 1 audit  
**Category:** Architecture  

## Pattern

Define all game data (stats, balance tables) in static data classes before writing simulation or rendering code.

## Why It Works

1. **Reviewable** — Reviewers can verify every value against the GDD table-by-table
2. **Testable** — Data validation tests are trivial to write (assert stat matches spec)
3. **Decoupled** — Simulation code reads from data; balance changes don't require engine changes
4. **Auditable** — External auditors can verify data independently of code logic

## Sprint 1 Evidence

Boltz verified all chassis/weapon/armor/module stats against GDD Balance v3 tables in the PR review. This would not have been possible if values were scattered through game logic.

## Structure (BattleBrotts v2)

```
godot/data/
  chassis_data.gd   — 3 chassis with HP, speed, weight, slots
  weapon_data.gd    — 7 weapons with damage, range, fire rate
  armor_data.gd     — 3 armors with reduction, reflect, conditional
  module_data.gd    — 6 modules with duration, cooldown, effects
```

All are static dictionaries accessed via class methods. No instances needed.
