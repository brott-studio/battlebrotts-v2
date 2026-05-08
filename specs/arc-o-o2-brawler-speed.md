# Arc O.2 — Brawler Speed Reduction Design Spec

**Author:** Gizmo  
**Date:** 2026-05-08  
**Arc:** O — Make the player feel in control  
**Sprint:** O.2  
**Status:** Ready for Ett

---

## What to Build

Reduce the player Brawler chassis movement stats in `godot/data/chassis_data.gd`:

```gdscript
ChassisType.BRAWLER: {
    "speed": 60.0,   # O.2: 120→60 px/s (was too fast to follow visually)
    "accel": 120.0,  # O.2: halved proportionally (was 240.0)
    "decel": 180.0,  # O.2: halved proportionally (was 360.0)
    ...
}
```

All other Brawler fields (HP, weight_cap, weapon_slots, module_slots, passive, dodge_chance) are unchanged. Scout and Fortress chassis are unchanged. Enemy bot stats are unchanged (see Implementation Flag below).

---

## Why

Arc O goal: make the player feel in control. O.1 (click-to-move) gave the player explicit movement direction. O.2 makes their bot visually trackable — at 120 px/s the player's bot crosses a 16×16-tile arena (~512 px) in ~4.3s, making it difficult to follow and react. At 60 px/s that becomes ~8.5s — watchable, followable, reactive to player inputs.

Player fantasy at stake: *"My creation is alive."* A player can only feel their bot is responding to their decisions if they can see what it's doing. Speed is the primary enemy of read-ability.

---

## Design Review Findings

### Current values (verified)

`godot/data/chassis_data.gd` Brawler entry as of main:

| Stat | Current | Proposed | Delta |
|---|---|---|---|
| speed | 120.0 | 60.0 | −50% |
| accel | 240.0 | 120.0 | −50% |
| decel | 360.0 | 180.0 | −50% |

Ratios are preserved: accel = 2× speed, decel = 3× speed. Proportional halving is mechanically consistent.

### GDD drift check

**No critical drift.** GDD §3.1 shows Brawler speed at 120 px/s (design spec). This change updates that to 60 px/s. Two downstream effects to verify:

1. **Speed parity with Fortress (60 px/s).** Brawler and Fortress become speed-identical. This collapses the speed tier between them. However, chassis differentiation survives through:
   - HP: Brawler 360 vs Fortress 450 (engine values)
   - Loadout: Brawler 2 weapon/2 module slots vs Fortress 2 weapon/1 module slot; weight cap 55 vs 80
   - TCR timings: Brawler (2.0–3.5s tension, 0.8s commit, 1.2s recovery) vs Fortress (1.5–2.5s tension, 1.2s commit, 0.9s recovery) — distinct combat rhythms persist
   - Fortress's "relentless" identity comes from short windups and long commits; Brawler's "baseline" identity comes from moderate tension and shorter commits
   - **Verdict:** speed parity with Fortress is a trade-off, not a design collapse. Chassis identities remain distinct at the loadout and TCR level.

2. **TCR commit speed impact.** At 60 px/s: COMMIT = min(60 × 1.4, 200) = 84 px/s. At 0.8s commit duration, Brawler closes ~67px (~2.1 tiles) per cycle — down from ~134px at 120 px/s. Brawler's "well-rounded baseline" combat feel becomes tighter and more deliberate. This aligns with Arc O's control-feel goal; it's not a regression.

### ⚠️ Implementation Flag — Enemy Brawler Conflict

**This is the primary design risk for O.2.**

`chassis_data.gd` is a shared data source for all Brotts using the Brawler chassis — player and enemy alike. The `brawler_rush` encounter archetype (GDD §13.4) spawns 1 enemy Brawler bot. Changing `chassis_data.gd` as written will also reduce the brawler_rush enemy's speed from 120→60 px/s, contradicting the arc brief's explicit instruction: *"Enemy bot speed: do NOT change."*

A "brawler rush" that plods at 60 px/s loses its encounter identity (the rush is the threat).

**Recommended resolution (pick one — Nutts to decide with Riv):**

**Option A — Player-only speed override (preferred):** Apply a speed override at the `RunState.build_brott()` or `BrottBrain` layer: when building the player's Brott, multiply speed by 0.5 (or set to 60.0 directly) before the bot is instantiated. `chassis_data.gd` stays at 120.0. This is the cleanest separation — player-feel tuning lives in the run layer, not the chassis layer.

**Option B — Brawler_rush template override:** Keep chassis_data.gd at 60.0 (affects all Brawlers including enemies), and add a `speed_override` field to the `brawler_rush` archetype template (paralleling `speed_override: 50 px/s` already set on `first_battle_intro`) to lock the enemy Brawler at 120.0 px/s. This is an additive change to the existing template override pattern.

**Option C — Accept the slowdown:** If the brawler_rush encounter at 60 px/s still produces acceptable encounter feel, change chassis_data.gd as written and accept that brawler_rush enemies are also slower. This requires Optic to verify that brawler_rush encounter outcomes at T1 still hit the 30–70% win-rate target for Brawler chassis.

Option A is cleanest architecturally. Option B is lowest risk (follows the existing `first_battle_intro` pattern). Option C is fastest to ship but leaves a potential balance hole at brawler_rush encounters.

**This flag is not a blocker on branching/spec writing. It IS a blocker on merging without Riv's explicit choice between A/B/C.**

---

## Acceptance Criteria

For Optic to verify:

1. Player Brawler bot moves at ≤65 px/s peak speed during TENSION phase (visual: orbits slowly enough to track)
2. Player Brawler COMMIT phase closes at ≤90 px/s (min(60×1.4, 200) = 84 px/s)
3. Combat sim: Brawler vs Scout, Brawler vs Fortress — win rates remain within 30–70% (T1 target)
4. Brawler TCR rhythm is unchanged (timings in `TCR_TIMINGS` are not touched by this change)
5. If Option A or B: confirm enemy brawler_rush bots still move at 120 px/s in sim

---

## GDD Update Required

GDD §3.1 chassis table: update Brawler Speed from 120 → 60 px/s.

GDD §5.3.1 TCR table commit speed note: add Brawler commit cap note — min(60×1.4, 200) = 84 px/s.

Note in Balance Changes section: Arc O.2 — Brawler speed 120→60, accel 240→120, decel 360→180. Rationale: player trackability (Arc O control-feel).

---

## Arc-Intent Verdict

**Arc intent: progressing — O.2 speed reduction designed, brawler_rush conflict needs resolution before merge.**

Arc O goal (make the player feel in control) is well-served by this change. At 60 px/s the player's Brawler is visually followable and responds predictably to click-to-move (O.1, already merged). The design is solid; the implementation conflict with enemy Brawler speed requires one explicit architectural choice (A/B/C above) before the sprint can close. Once resolved and merged, O.3 (swarm death freeze fix, #361 P1) is the final O-arc item.
