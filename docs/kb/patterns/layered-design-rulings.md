# Pattern: Layered design rulings on metric-semantics work

## Problem

A sprint is sized TRIVIAL on the assumption that a metric bug needs one ruling and one fix. In practice, correctness of a measurement is often composed of multiple independent guards (where you sample, what resets a period, when to stop counting). Each guard's necessity is only visible *after* the prior guard's results are in hand. The result is a legitimate, non-thrashing sequence of rulings, each correct, each making progress, that collectively costs far more than the sizing predicted.

## Canonical example — Sprint 15.2 moonwalk metric

`test_away_juke_cap_across_seeds` was failing 8/100. The fix was scoped as a test-metric change (not a movement-model change), sized TRIVIAL.

- **Ruling 1 (pre-tick sampling):** measure `to_target` at the start of the tick, not the end. Applied → 7 → 3 violations. Correct, incomplete.
- **Addendum 1 (per-period reset):** reset the accumulator when `backup_distance` drops to a new period. Applied → 3 → 2 violations. Correct, incomplete.
- **Addendum 2 (budget-gated raw accumulator):** gate on `bd < TILE_SIZE`, freeze once the retreat budget cap is reached. Applied → 2 → 0 violations ✅.

Three rulings, three Nutts iterations, two Riv surfaces. `combat_sim.gd` was never touched — the scope gate held. Each ruling was individually correct and necessary. None of them would have been obvious from the original test before any ruling had been applied.

## The tell

If iteration 1 of a "TRIVIAL" metric fix does not close the acceptance bar (violations > 0, residual > threshold, etc.), **the sizing is probably wrong** — not because the ruling was wrong, but because metric semantics are a layered design problem dressed up as a single fix.

## Recommended behavior

- **Ett:** when planning a metric-semantics sprint, mark it `size-uncertain` and require an explicit re-size checkpoint after iter 1. If iter 1 does not close, re-brief and re-size before iter 2 proceeds.
- **Gizmo:** when issuing the first ruling on metric semantics, note whether the ruling addresses a *local* correctness question (sampling point, reset condition) or a *global* one (what the metric measures end-to-end). Local rulings are more likely to need addenda.
- **Nutts:** if iter N does not close, surface cleanly — do not speculatively fix. The progress arc (8 → 7 → 3 → 2 → 0 in S15.2) is valuable signal for Gizmo's next ruling; don't contaminate it with guesses.
- **Riv:** surface 🟡 after two successive partial closes. Iter 1 not closing is information; iter 2 not closing is a signal that the sizing was off and HCD should know.
- **Boltz / scope-gate owner:** **do not weaken the scope gate under iteration pressure.** This is where metric-chasing most often turns into movement-model churn. In S15.2, `combat_sim.gd` stayed untouched across all three iterations — that discipline is what kept the fix reversible.

## Related

- `docs/kb/patterns/orchestrator-no-yield.md` — same sprint; different pipeline issue.
- `docs/kb/partial-pass-merge-with-diagnosed-residual.md` — when to merge with honest bar-miss.

## Date

2026-04-17, crystallized from Sprint 15.2.
