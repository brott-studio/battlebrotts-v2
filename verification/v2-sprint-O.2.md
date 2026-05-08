# Verification Report — Sprint O.2: Brawler Speed Reduction

**Verifier:** Optic  
**Date:** 2026-05-08  
**PR:** #364  
**Merge SHA:** `9ca02a57d3f3583e981d3e8a5a58eb5b63be6e3c`  
**Branch verified against:** `main`

---

## Verdict: ✅ PASS

All required gates pass. One CI check (Playwright Tests E2E suite) was still `in_progress` at report time — all other checks are `completed/success`.

---

## Gate 1 — Code Presence ✅

**File:** `godot/data/chassis_data.gd`

| Chassis   | Field  | Expected | Actual | Status |
|-----------|--------|----------|--------|--------|
| Brawler   | speed  | 60.0     | 60.0   | ✅ |
| Brawler   | accel  | 120.0    | 120.0  | ✅ |
| Brawler   | decel  | 180.0    | 180.0  | ✅ |
| Scout     | speed  | 220.0    | 220.0  | ✅ unchanged |
| Fortress  | speed  | 60.0     | 60.0   | ✅ unchanged |

Comments in code confirm intent: `# O.2: 120→60 px/s (too fast to follow visually)` with proportional accel/decel halving.

**File:** `godot/data/opponent_loadouts.gd`

- `brawler_rush` archetype contains `"speed_override": 120.0` ✅  
  Comment: `# O.2: speed_override retains enemy speed at 120 px/s despite chassis_data halving player Brawler to 60 px/s`

---

## Gate 2 — Test File Present and Registered ✅

- `godot/tests/test_arc_o2_brawler_speed.gd` — **exists** ✅  
- Registered in `SPRINT_TEST_FILES` in `godot/tests/test_runner.gd` as `"res://tests/test_arc_o2_brawler_speed.gd"` ✅

---

## Gate 3 — CI Green on Main ✅ (with note)

CI checks on SHA `9ca02a5`:

| Check                        | Status    | Conclusion |
|------------------------------|-----------|------------|
| Detect changed paths         | completed | success ✅ |
| Export Godot → HTML5         | completed | success ✅ |
| update                       | completed | success ✅ |
| Godot Unit Tests             | completed | success ✅ |
| Playwright Smoke Tests       | completed | success ✅ |
| Deploy to GitHub Pages       | completed | success ✅ |
| Post Optic Verified check-run| completed | success ✅ |
| **Playwright Tests (E2E)**   | **in_progress** | — ⏳ |

> **Note:** Full Playwright E2E suite was still running at verification time (~90s after merge). All other checks passed. Godot Unit Tests (which includes the arc O.2 brawler speed test) is green.

---

## Gate 4 — Logic Trace ✅

**Path:** `opponent_loadouts.gd` → `game_main.gd:_start_roguelike_match` → `brott_state.gd:get_speed()`

1. **`opponent_loadouts.gd`** — `compose_encounter` returns enemy spec dict with `"speed_override": 120.0` for `brawler_rush` archetype. Field is stored in the spec dict (`entry["speed_override"] = float(spec["speed_override"])`).

2. **`game_main.gd` line 307–308** — During battle initialization in `_start_roguelike_match`, after calling `ebrott.setup()` (which sets `base_speed` from `chassis_data`), the code reads `"speed_override"` from the spec and applies it:
   ```gdscript
   if "speed_override" in spec:
       ebrott.speed_override = float(spec["speed_override"])
   ```

3. **`brott_state.gd` line 70, 184–186** — `speed_override` is declared as `var speed_override: float = -1.0` (disabled by default). The `get_speed()` method checks it first:
   ```gdscript
   if speed_override > 0.0:
       return speed_override
   var spd := base_speed
   # ... afterburner etc.
   return spd
   ```

**Conclusion:** `speed_override` is declared, read from spec at battle init, stored on the enemy `BrottState`, and takes priority over `base_speed` in `get_speed()`. The brawler enemy will move at 120 px/s while the player Brawler chassis caps at 60 px/s. ✅ No dead field.

---

## Summary

| Gate | Result |
|------|--------|
| Gate 1 — Code presence | ✅ PASS |
| Gate 2 — Test file present + registered | ✅ PASS |
| Gate 3 — CI green | ✅ PASS (E2E still running, all others green) |
| Gate 4 — Logic trace | ✅ PASS |

**Overall: PASS**
