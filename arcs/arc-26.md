# Arc 26 — Arc F.5: Playtest Triage (P0 Hotfix)

**Arc ID:** F.5 (internal), 26 (sprint numbering)
**Date:** 2026-04-27
**Trigger:** First roguelike playtest (HCD, 2026-04-27 01:29 UTC)
**Build baseline:** `main` @ `9aa417f` (S25.10)

## Arc Goal

Fix 3 bugs surfaced in the first roguelike playtest AND close the framework gap that allowed them to ship undetected.

## Bugs

| # | Sev | Bug | Issue |
|---|---|---|---|
| 1 | 🔴 P0 | Blank screen on most chassis-pick → battle-start attempts | #312 |
| 2 | 🟡 P1 | Settings popup cut off on right edge of viewport | #313 |
| 3 | 🟡 P1 | Battles too fast to interact (swarm encounters) | #314 |

## Framework Gap

Existing smoke tests (page-load only) do not exercise the user-flow gameplay path. Optic verified every PR in Arc F as PASS; the blank-screen bug shipped undetected.

## Sub-sprint Plan

| Sub-sprint | Title | Output |
|---|---|---|
| S26.1 | Repro + fix blank-screen bug (P0) | Merged fix + regression test |
| S26.2 | Fix settings popup cutoff (P1) | Merged fix + Playwright snapshot |
| S26.3 | End-to-end gameplay smoke | New Playwright spec in CI |
| S26.4 | Investigate battle pacing (P1) | Combat sims + fix or surface to HCD |
| S26.5 | GDD update — §13 Roguelike Run Loop | Updated docs/gdd.md |
| S26.6 | Specc audit arc-close | Audit at studio-audits |

## Arc-close Criteria

- All 3 bugs fixed (or pacing surfaced to HCD as CD decision)
- New gameplay smoke passing in CI on merged main
- GDD §13 written
- Specc arc-close audit landed at `audits/battlebrotts-v2/v2-sprint-26.1.md`

## Hard Rules

- Battle pacing (Bug 3) is HCDs call if it is pure tuning — do not autonomously rebalance
- No Arc G work in this arc
- Smoke must be proven to FAIL pre-fix before merging

