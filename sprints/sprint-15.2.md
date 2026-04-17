# Sprint 15.2 — Moonwalk Metric Fix

**PM:** Ett
**Status:** In progress (executing at build stage)
**Sprint type:** Sub-sprint (closes CI health gap from Sprint 15.1)
**Scope:** trivial (per Gizmo's ruling — ~5–10 line test change)

## Goal

Close CI health by resolving `test_away_juke_cap_across_seeds` residual 7/100 failures. Gizmo's ruling (`docs/design/sprint15-moonwalk-metric-ruling.md`) determined the failures are a **metric artifact**, not a runtime bug: the test sampled `to_target` post-tick, producing false positives when two bots COMMIT-dash through each other and swap positions in a single tick.

## Design input

- **Metric ruling:** PRE-TICK sampling. Moonwalk invariant measures *intent to retreat* (bot's own frame at tick start), not post-tick net displacement.
- **COMMIT pass-through:** ALLOWED by design. No collision-resolution guard added.
- **GDD change:** None required. Ruling clarifies existing canon (L286 "retreat" = intent-frame, L276 commit dash implies pass-through at close range).

Full spec: `docs/design/sprint15-moonwalk-metric-ruling.md` (landed via PR #83).

## Tasks

### SN-103 — Fix moonwalk metric: sample `to_target` pre-tick
**Owner:** Nutts
**Files:** `godot/tests/test_sprint11_2.gd`
**Scope gate:** `combat_sim.gd` diff must be empty. No runtime code change permitted.
**Substance:** apply pre-tick sampling block from Gizmo's ruling doc to `test_away_juke_cap_across_seeds` loop. `test_away_juke_capped_at_one_tile` has no `to_target`/dot-product sampling logic to change — it asserts on `b0.backup_distance` directly — so no change needed there (Gizmo's "for consistency" note applies only where post-tick sampling existed).

**Acceptance:**
1. `test_away_juke_cap_across_seeds` reports `No moonwalk violations (0/100)`.
2. Full `test_sprint11_2.gd` suite passes.
3. `combat_sim.gd` unchanged between main-pre-S15.2 and main-post-S15.2.

### SN-104 — Merge choreography + verify
**Owner:** Nutts (open PR) → Boltz (review + merge) → Optic (verify) → Specc (audit)
**Steps:**
1. Merge PR #83 (Gizmo's ruling doc) → lands ruling on main. ✅ done.
2. Branch `sprint-15.2-metric-fix` from updated main.
3. Apply SN-103 test change + push.
4. Run full Godot suite locally; confirm 0/100 violations.
5. Open S15.2 PR targeting main, signal Boltz for review.
6. Boltz reviews + merges.
7. Optic verifies (spot-check 10 random seeds from previously-violating set: 2, 23, 45, 63, 67, 80, 84).
8. Specc audits + adds KB note to `docs/kb/juke-bypass-movement-caps.md` clarifying metric-artifact resolution.

## Scope discipline

**Out of scope for S15.2:**
- Any change to `combat_sim.gd`.
- Collision-resolution system for COMMIT pass-through (deferred to a future design sprint if playtest surfaces issues).
- S13.3 commit cap revisions.

## Completion criteria

Sprint 15.2 is complete when:
- S15.2 PR merged to main with test-metric fix only.
- `test_away_juke_cap_across_seeds` = 0/100 on main CI.
- Specc audit committed to `studio-audits/audits/battlebrotts-v2/sprint-15.2.md`.
- KB note added per Gizmo's AC #6.

Then Ett's next continuation-check decides whether Sprint 15 as a whole converges or needs further sub-sprints.
