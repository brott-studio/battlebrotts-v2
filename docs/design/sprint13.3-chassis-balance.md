# Sprint 13.3 — Chassis Balance Pass (post-TCR)

**Author:** Gizmo
**Date:** 2026-04-16
**Status:** Design spec, handoff to Ett for sprint planning
**Replaces:** Original S13.3 plan ("Combat Rhythm: Stance Modifiers") — deferred to S13.4

---

## 1. Problem Statement

TCR (S13.2) works correctly in mirror matchups. Cross-chassis matchups are catastrophically lopsided:

| Matchup | Current win rate | Current match length |
|---|---|---|
| Scout vs Fortress | **100–0** | 7–13s |
| Brawler vs Scout | **92–8** | ~15s |
| Brawler vs Fortress | **100–0** | ~15s |
| Fortress mirror | 50–50 | 38.4s ✓ |
| Scout mirror | 50–50 | **10s** ✗ too fast |

**Target (acceptance criteria):**
- All six matchups in **40–60% win rate**.
- All matchups in **30–60s match length**.
- No chassis is strictly dominant (no 1-of-3 wins all, none loses all).

## 2. Root Cause Analysis

### 2.1 Commit speed multiplier compounds the speed gap

TCR's commit dash is `base_speed × 1.4` for 0.8s. This multiplier amplifies — rather than compresses — the chassis speed gap:

| Chassis | Base | Commit (×1.4) | Commit distance over 0.8s | In tiles (32px) |
|---|---|---|---|---|
| Scout | 220 | **308 px/s** | 246 px | **7.7 tiles** |
| Brawler | 120 | 168 | 134 | 4.2 |
| Fortress | 60 | **84** | 67 | **2.1** |

Scout's commit *alone* spans the entire close range band. Fortress can barely change posture during its commit. Scout can complete TENSION→COMMIT→RECOVERY in ~4s; Fortress spends that same budget barely moving. Result: Scout dictates every engagement, Fortress is a stationary target.

### 2.2 HP doesn't compensate enough for mobility

Current HP ratios: Scout 100, Brawler 150, Fortress 180 (1.0 : 1.5 : 1.8).
Speed ratios: Scout 220, Brawler 120, Fortress 60 (3.67 : 2.0 : 1.0).

HP scales 1.8× from Scout to Fortress; speed gap scales 3.67×. HP isn't close to compensating. Fortress effectively trades away ~73% of its mobility for ~80% more HP — a bad deal when mobility governs hit rate, range control, and TCR tempo.

### 2.3 Mirror-match length is a speed artifact, not balance

Scout mirror ending in 10s isn't an imbalance — both bots have the same tools. It's that Scout's combination of speed + low HP + no armor collapses TTK. Bumping Scout HP slightly (or toning down commit burst) fixes this alongside the cross-chassis issue.

## 3. Design Changes

Four levers, ordered from most to least impactful. All are numeric; none touch TCR correctness.

### 3.1 Absolute commit-speed cap (primary fix)

Replace pure multiplier with `min(base_speed × 1.4, COMMIT_SPEED_CAP)`.

**Proposed cap: `COMMIT_SPEED_CAP = 200 px/s`**

Effects:
| Chassis | Old commit | New commit | Δ |
|---|---|---|---|
| Scout | 308 | **200 (capped)** | −35% |
| Brawler | 168 | 168 (unaffected) | 0 |
| Fortress | 84 | 84 (unaffected) | 0 |

Scout's commit dash over 0.8s drops from 7.7 → 5.0 tiles (still decisive, no longer teleportation).
Brawler and Fortress keep the full 1.4× burst — they *need* the relative speed-up to close distance.

**Rationale:** TCR's commit is about *committing to a direction*, not about raw speed. A 5-tile dash is plenty of spectacle. Capping just the top end preserves chassis identity (Scout is still fastest) while removing the degenerate teleport case. This is a single-constant change with the biggest effect on win rates.

### 3.2 Per-chassis TCR phase durations (identity & counterplay)

Currently all chassis use the same TCR timings (TENSION 2.0–3.5s, COMMIT 0.8s, RECOVERY 1.2s). Give each chassis a distinct rhythm that matches its fantasy and creates counter-play windows:

| Chassis | TENSION | COMMIT | RECOVERY | Fantasy |
|---|---|---|---|---|
| **Scout** | **2.5–4.0s** (longer) | **0.6s** (shorter) | **1.5s** (longer) | Slippery, cautious, commits briefly |
| **Brawler** | 2.0–3.5s (baseline) | 0.8s (baseline) | 1.2s (baseline) | Well-rounded, no quirks |
| **Fortress** | **1.5–2.5s** (shorter) | **1.2s** (longer) | **0.9s** (shorter) | Relentless — short windups, long commits, quick to reset |

**Rationale:**
- Scout's shorter commit window = less dash distance = less free reposition, even above the cap.
- Fortress's longer commit (1.2s at 84 px/s = 101 px / 3.15 tiles) is the single biggest buff to Fortress — it finally moves a meaningful distance per commit cycle.
- Fortress's shorter TENSION means it spends more of the match *committing* (the phase with highest damage potential) and less orbiting in place being peppered.
- These create genuine counterplay: Scout's long TENSION is a window where Fortress can land plasma/railgun shots; Scout's short commit is a brief dodge window.

### 3.3 HP adjustments (final balance knob)

Bump HP to better reflect the remaining mobility gap:

| Chassis | Old HP | New HP | Δ |
|---|---|---|---|
| Scout | 100 | **110** | +10% |
| Brawler | 150 | 150 | 0 |
| Fortress | 180 | **220** | +22% |

**Rationale:**
- Scout +10 HP: makes Scout mirror matches last ~15s instead of 10s (moves toward the 30–60s band). Keeps Scout's "glass cannon" identity intact (still lowest HP by far).
- Fortress +40 HP: compensates for the mobility gap that remains even after the commit cap. Fortress should be a wall — 220 HP with Ablative Shell and Plating options lets it actually tank.
- Brawler untouched: it's the baseline, and its current 92-8 vs Scout is driven by Scout's commit abuse, not Brawler stats. Once 3.1 lands, Brawler vs Scout should normalize without HP changes.

### 3.4 Scout dodge passive — consistency check

Scout's 15% dodge chance (existing GDD entry) is implemented per-shot. No change proposed, but flag for Optic: **verify dodge is applied after the per-shot hit-rate instrumentation fix below**. If it turns out dodge is being double-counted or applied to pellets individually, that's a separate bug worth catching here.

## 4. Small Fix: Shotgun Hit-Rate Instrumentation (Specc finding #3)

Shotgun hit-rate counter double-counts because pellets increment per-pellet but shots-fired increments per-trigger-pull.

**Fix (scope: ~10 lines in `combat_sim.gd` / logging):**
- Option A (preferred): Track `pellets_fired` and `pellets_hit` separately. Report hit rate as `pellets_hit / pellets_fired`. This is the intuitive "per-pellet accuracy" metric that compares apples-to-apples with single-projectile weapons.
- Option B: Track `shots_fired` and `shots_hit_at_least_one_pellet`. Report "shot effectiveness". Less useful for balance.

**Recommendation: Option A.** Instrument `pellets_fired` on projectile spawn for spread weapons, use that as denominator.

Acceptance: sim logs should never show hit rate >100% for any weapon in any matchup.

## 5. Acceptance Criteria (for Optic)

**Required for sprint pass:**

1. **Win rates in 40–60%** for all 6 matchups (Scout-mirror, Brawler-mirror, Fortress-mirror, Scout-Brawler, Scout-Fortress, Brawler-Fortress), N≥100 sims each, using default loadouts.
2. **Match lengths in 30–60s** for all 6 matchups (mean, N≥100).
3. **No chassis is strictly dominant**: no chassis wins all 4 non-mirror matchups (2 directions × 2 opponents), none loses all 4.
4. **Shotgun hit rate ≤100%** in all sim reports. Pellet-level metric present and labeled.
5. **Mirror matchups still hit TCR-correctness bar** from S13.2: hit rates 50–80%, ~3+ TCR cycles per match.

**Soft targets (nice-to-have):**
- Standard deviation on match lengths < 15s (tight distributions = more predictable balance).
- Cross-chassis hit rates all ≥40% (no "I can't hit that at all" matchups).

## 6. GDD Updates Required

**§3.1 Chassis Types** — update HP column:
```
Scout:    100 → 110
Fortress: 180 → 220
```

**§5.3.1 Combat Movement** — TCR subsection:
- Add "**Commit speed is capped at 200 px/s**" line under COMMIT phase.
- Replace single TCR timing list with per-chassis table:

```
| Chassis  | TENSION     | COMMIT | RECOVERY |
|---|---|---|---|
| Scout    | 2.5–4.0s    | 0.6s   | 1.5s     |
| Brawler  | 2.0–3.5s    | 0.8s   | 1.2s     |
| Fortress | 1.5–2.5s    | 1.2s   | 0.9s     |
```

**New §5.2.1 "Hit Rate Instrumentation"** — short paragraph clarifying that spread weapons are measured per-pellet, with `hits / pellets_fired` as the canonical metric.

**§12 Balance Changes v3** — new entry documenting the commit cap, per-chassis TCR, and HP bumps. Reference Sprint 13.3 audit.

## 7. Scope Recommendation for Ett

**In scope:**
- 3.1 Commit speed cap (constant + one line change in `combat_sim.gd`)
- 3.2 Per-chassis TCR durations (chassis config — probably add fields to `chassis_data.gd` or equivalent; branch on chassis in phase-transition handler)
- 3.3 HP adjustments (data-only change)
- 4. Shotgun hit-rate fix (small instrumentation change)
- Tests: add cross-chassis integration tests covering all 3 asymmetric matchups with win-rate assertions (this is Specc's finding #1 — landing a mechanics change with mirror-only tests is a recurring gap). Suggest N=100 sim assertions with tolerance bands 35–65% (slightly looser than acceptance for test flakiness headroom).
- GDD updates above.

**Out of scope (defer to S13.4):**
- Stance modifiers (original 13.3 plan). Once chassis balance is in the 40–60% band, stance-tier adjustments are meaningful; right now they'd be layered on top of a broken baseline.
- Weapon-by-weapon balance. Shotgun data can't be trusted until the hit-rate instrumentation is fixed, but actual weapon tuning should wait until post-13.3 telemetry.
- Any armor or module tuning.

**Pipeline notes for Ett:**
- This is a tuning sprint. Expect an iteration loop: initial changes may overshoot (Fortress could go from 0% → 70% win rate). Build in time for one balance re-pass if Optic's first sim round is out-of-band. Recommend Ett scope for **1 balance re-pass** (not 0, not 2) before calling the sprint.
- Changes are low-risk / high-value. No architectural work. Nutts should be able to ship this in a single PR.

## 8. GDD Drift Check (per Gizmo's review mandate)

Reviewed `docs/gdd.md` against current codebase. Findings:

- **No significant drift.** TCR constants in §5.3.1 match `combat_sim.gd` as of `main` HEAD. S13.2 updated both in sync — good pipeline hygiene.
- **Minor:** §5.2 "Pellet weapons" text says "each pellet rolls independently" which is accurate to the implementation, but the implied measurement convention (per-pellet) isn't stated. The new §5.2.1 hit-rate paragraph (above) closes that gap.
- **Minor:** §11 "Balance Metrics" doesn't list target win-rate band explicitly. Suggest Ett add "40–60% across all matchups" as a success metric — this is what Optic is measuring against, and should be first-class in the GDD.
- **Flag, not drift:** §4.3 Stances table and §5.3.1 engagement-band table both live on — stance modifiers land in S13.4 and will need both sections updated then.

No DRIFT DETECTED escalation. Proceed with S13.3 as specified.

---

## TL;DR for Ett

1. **Cap commit speed at 200 px/s** (biggest lever, single constant).
2. **Give each chassis its own TCR timings** (Scout: quick+cautious, Fortress: patient+relentless).
3. **Bump Scout to 110 HP, Fortress to 220 HP.**
4. **Fix shotgun per-pellet instrumentation** while you're in there.
5. **Add cross-chassis tests** so this class of regression gets caught in PR, not sim.
6. Stance modifiers slip to S13.4.
7. Budget for one balance re-pass if first numbers miss.
