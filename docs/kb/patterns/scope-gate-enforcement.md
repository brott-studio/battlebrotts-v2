# Pattern: Scope-gate enforcement across multi-iteration fixes

## Problem

A sprint declares a narrow scope gate — "test-only change," "docs-only," "no production code touched" — and then the fix turns out to need multiple iterations. Each iteration is a fresh opportunity to break the gate: when a test-only fix doesn't close the gap, the fastest-looking path is almost always "just patch the simulation to avoid this edge case." That's the wrong move. Once production code is in the diff, the sprint's verification story (and the regression detector the test was guarding) becomes entangled with new behavior, and the original bar ("does the guard still fire on the original regression?") gets harder to prove.

## Pattern

Three roles collaborate to hold the gate. Each has a distinct job; any one of them defecting breaks the pattern.

### Gizmo (Design) — frame every ruling as measurement, never motion

When a test-metric question surfaces, rulings must describe *how the metric observes the world*, not *how the world should be changed to satisfy the metric*. Pre-tick vs post-tick sampling is a measurement change. Resetting an accumulator on a period boundary is a measurement change. Adding a sim-side clamp to prevent a state the test doesn't like is a motion change — out of scope.

When a ruling ships, include a walkthrough proving the existing regression guard still fires on its original target. This is the falsifiable half of "the metric still works" — without it, a metric fix can silently neuter the regression guard it's attached to.

### Boltz (Lead Dev) — enforce the diff on review

Every iteration's PR gets a scope-gate diff check on review: the files the gate forbids (e.g. `combat_sim.gd` for a test-only moonwalk fix) must show no diff vs pre-sprint main. Approve only when the diff confirms the gate. If an iteration's fix does need production code, that's a scope escalation to Riv/HCD, not a silent sprint expansion.

### Nutts (Implementation) — surface residual failures honestly

When an iteration drops violations but doesn't hit zero, report the residual seeds / cases plainly. Do not paper over the gap with a "small" production tweak to close it. The explicit surface is what triggers the next design addendum and keeps the gate intact.

## Convention: production-code diff summary in verify

For any sprint whose plan declares a scope gate, Optic's verify report should include an explicit diff summary for the gated paths against pre-sprint `main`. This converts the gate from an implicit norm into a falsifiable artifact.

Example (Sprint 15.2, PR #85):

> `combat_sim.gd` diff vs pre-S15.2 main: **EMPTY** across 3 iterations.

The gate is proven, not asserted.

## Why it matters

Scope gates exist because regression guards are expensive to re-earn. A test that has been carefully tuned to detect a specific past regression loses all its value the instant its semantics get entangled with a production-side workaround. Keeping the gate intact across N iterations is not pedantry — it's what preserves the test's load-bearing function for the next time the same regression tries to come back.

## Worked example

Sprint 15.2 closed the `test_away_juke_cap_across_seeds` violation arc from 7 → 0 across three iterations (Gizmo Ruling 1 → Addendum 1 → Addendum 2, each followed by a Nutts iteration). Every iteration preserved `combat_sim.gd` untouched. The fix lived entirely in test-harness measurement changes: sampling-phase correction, period-boundary reset of the backup-run counter, and a budget-gated raw accumulator that freezes when the clamp caps it.

Addendum 2 shipped with an empirical walkthrough proving the original S11.1 regression detector still fires on its original moonwalk target — closing the "did the metric fix silently kill the guard?" question before merge.

## Related entries

- `docs/kb/patterns/layered-design-rulings.md` — why a "trivial" metric fix needed three rulings.
- `docs/kb/troubleshooting/ci-goal-ambiguity.md` — narrow vs broad "CI green" framing.
- `docs/kb/moonwalk-diagnosis-debug-harness.md` — how the debug harness accelerated iteration speed.
- `docs/kb/partial-pass-merge-with-diagnosed-residual.md` — when it's correct to merge with a known-red residual.

## Date

2026-04-17, crystallized from Sprint 15.2.
