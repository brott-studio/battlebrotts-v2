# Fun Evaluation Approaches

> Spike sprint findings — April 2026

## Three Approaches to Measuring Fun

### Approach A: Proxy Metrics
Tension (lead changes), drama (close finishes), variety (event diversity), momentum shifts. Combine into a composite "fun score."

**Status:** 🔴 BLOCKED — needs JSON match logging from combat engine.

### Approach B: LLM-as-Critic
Feed match replay narrative to LLM, get excitement rating 1–10 with explanation.

**Status:** 🔴 BLOCKED — needs JSON match logging.

### Approach C: Comparative Evaluation
Run matches with different settings, rank from most to least fun, analyze what makes the best ones better.

**Status:** 🟢 WORKS NOW — no JSON needed, uses sim output directly.

---

## What Makes Combat Fun (Approach C Findings)

- **Loadout diversity is the #1 fun driver**
- Sweet spot: **5–10s duration**, diverse weapons, close HP finishes
- Shotgun is most entertaining (risk/reward gameplay)
- Plasma Cutter is dead — 1.5 tile range means it never fires
- BrottBrain AI is essential — brainless matches are boring
- Overtime threshold should be **45s not 60s**

---

## Proposed Production Fun Score

Five metrics, weighted:

| Metric | Weight |
|---|---|
| Loadout Diversity Index | 25% |
| HP Closeness | 25% |
| Duration Score (bell curve centered at 7s) | 20% |
| Lead Changes | 15% |
| Weapon Variety Hits | 15% |

---

## Three-Layer Verification System

| Layer | What | When |
|---|---|---|
| **L1** | Automated `fun_score` from telemetry | Every match |
| **L2** | Comparative tuning sessions | Per-patch |
| **L3** | LLM narrative evaluation | On-demand for outliers |

---

## Blockers & Next Steps

**Critical blocker:** JSON match logging needed to unblock Approaches A and B.

**Prerequisite for next spike re-run:** Add `--json-log` flag to combat engine that dumps per-tick state.
