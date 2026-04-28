# Arc 27 — Arc I: Optic Plays The Game

**Arc:** I (internal arc label)
**Sprint range:** 27.x
**Status:** In progress
**Started:** 2026-04-27
**Direction source:** HCD greenlight 2026-04-27 13:47 UTC after S26.8 P0 blank-screen incident.

## Thesis

Optic currently verifies the page loads — not that the player can play. Arc I closes that gap by giving Optic the ability to drive the actual game via three complementary pillars:

1. **Pillar 1** — Native GDScript auto-driver (headless `godot --headless --script`), exercises full user flows in ~10s. Per-PR gate. S27.1–S27.2.
2. **Pillar 3** — Combat-sim agent (N parallel headless runs, aggregate stats). Nightly gate. S27.3–S27.4.
3. **Pillar 2** — `window.bb_test` JS bridge + Playwright on real WebGL. Arc-close gate. S27.5–S27.7 (+ S27.8 optional flake-tuning, S27.9 optional generalization).

## Success criteria

**A grade:** All three pillars closed. Per-PR gate catches S26.8-class regression in <10s, nightly sim report flags balance outliers, Pillar 2 chassis-pick gate catches web-export regression with ≤5% flake.
**B grade:** Pillars 1+3 closed; Pillar 2 bridge shipped but Playwright spec too flaky for arc-close gate.
**C grade:** Pillar 1 closes with S26.8-class regression caught; Pillar 3 lands as scaffold.
**Fail:** Pillar 1 does not produce a per-PR gate that catches the S26.8-equivalent regression.

## Sub-sprints

| Sprint | Pillar | Description |
|---|---|---|
| 27.1 | 1 | AutoDriver base + chassis-pick flow + CI step |
| 27.2 | 1 | Full 4 user flows (reward-pick, run-end, settings) |
| 27.3 | 3 | Sim-loop scaffold + random-pick policy |
| 27.4 | 3 | Aggregate stats + dashboard |
| 27.5 | 2 | bb_test JS bridge (debug-only) |
| 27.6 | 2 | Playwright chassis-pick spec on real WebGL |
| 27.7 | 2 | Playwright reward-pick spec |
| 27.8 | 2 | Optional: CI flake-rate tuning (hard cap 1) |
| 27.9 | 2 | Optional: bridge surface generalization |

## Constraints

- API surface ≤6 verbs (locked in S27.1 Boltz review).
- `bb_test` bridge gated on export-time feature flag; production build must not contain `bb_test`.
- No self-hosted GPU runner work in this arc.
- No content/balance changes.
- Arc F.6 helpers stay in current location.
- `noUpstreamOpenClawPRs` in effect.
