# Sprint O.2 — Brawler Speed Tuning

**Arc:** O — Feel-Pass: Combat Pacing
**Sub-sprint:** O.2 of 3
**Date:** 2026-05-08
**PM:** Ett

---

## DECISION: continue

**REASON:** Gizmo arc-intent is `progressing` — O.2 (Brawler speed) and O.3 (swarm death freeze) remain pending. Arc has not converged. Continue per Step A criteria.

---

## GIZMO ARC-INTENT: progressing

O.1 ✅ merged (Grade A audit confirmed on studio-audits/main). O.2 and O.3 still pending. Arc intent not yet satisfied.

---

## DESIGN INPUT

- **Brawler speed:** 120 → 60, accel: 240 → 120, decel: 360 → 180 (proportional halving)
- **Conflict resolution (Riv, final — do not re-open):** `chassis_data.gd` is shared with `brawler_rush` enemy archetype. Resolution: **Option B** — add `speed_override: 120.0` to `brawler_rush` enemy template, mirroring `first_battle_intro` pattern. Arc brief constraint ("enemy bot speed: do not change") satisfied.
- Source: Gizmo O.2 output + Riv Option B resolution

---

## AUDIT VERIFICATION GATE

- Prior audit: `audits/battlebrotts-v2/v2-sprint-O.1.md` on `studio-audits/main` → ✅ EXISTS
- Grade: A (carry-forward: #363 only — out of scope for O.2)

---

## BACKLOG HYGIENE

- Backlog query: `GET /repos/brott-studio/battlebrotts-v2/issues?state=open&labels=backlog&per_page=100`
- O.2-related items found: **none** (Brawler speed tuning is new this sprint, no prior issue)
- #363 `[O.1 carry-forward] 25-tick override suppression window is hardcoded` — open, confirmed out of scope for O.2 per arc brief
- No carry-forward gaps from O.1 audit — all flagged items are filed as issues

---

## SPRINT PLAN

### Tasks

| ID | Source | Description | Agent |
|----|--------|-------------|-------|
| SO.2-001 | `new this sprint` | In `chassis_data.gd`: change Brawler `speed`: 120→60, `accel`: 240→120, `decel`: 360→180 | Nutts |
| SO.2-002 | `new this sprint` | In `brawler_rush` enemy template: add `speed_override: 120.0` to preserve enemy archetype speed (Option B, Riv-resolved) | Nutts |
| SO.2-003 | `new this sprint` | Test: AutoDriver chassis-pick regression — all chassis complete 5-tick navigation sequence without errors | Nutts |
| SO.2-004 | `new this sprint` | Test: `brawler_rush` enemy speed is NOT affected — verify `speed_override: 120.0` applied and in effect | Nutts |

### Acceptance Criteria

- [ ] `chassis_data.gd` Brawler `speed` == 60.0
- [ ] `brawler_rush` enemy template contains `speed_override: 120.0`
- [ ] AutoDriver chassis-pick regression passes (all chassis, 5-tick nav)
- [ ] `brawler_rush` enemy speed confirmed unaffected by chassis_data change
- [ ] No sim win-rate gate required (per arc brief)

### Dependencies

- SO.2-002 depends on SO.2-001 (need to know which field/format chassis_data uses before mirroring in enemy template)
- SO.2-003 and SO.2-004 depend on SO.2-001 and SO.2-002 (tests run after changes)

### Infra / Cleanup

- None this sprint. #363 (hardcoded 25-tick constant) remains open backlog — out of scope here, tracked.

### Not in scope

- O.3 (swarm death freeze) — next sprint
- #363 carry-forward — deliberate deferral, no arc dependency

---

## NEXT

After Nutts completes + Boltz merges + Optic verifies + Specc audits O.2 → Riv spawns O.3 sprint.
