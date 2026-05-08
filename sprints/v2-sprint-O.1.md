# Sprint Plan — Arc O, Sub-sprint O.1
**Agent:** Ett  
**Date:** 2026-05-08  
**Branch (plan):** arc-o-ett-O.1  
**Arc:** O — "Make the player feel in control"  
**Sub-sprint:** O.1 — Click-to-move tick-suppression override

---

## DECISION: CONTINUE
**Reason:** First sub-sprint of Arc O. O.1, O.2, and O.3 are all pending. Gizmo arc-intent verdict: `progressing`. No prior audit (first sprint in arc — audit gate skipped per ett.md §Step 0). Arc has not converged.

---

## GIZMO ARC-INTENT: progressing

## DESIGN INPUT
Spec ready: `specs/arc-o-o1-click-to-move.md` on branch `arc-o-gizmo-specs`.

Summary:
- Add `_override_ticks_remaining: int = 0` to `brottbrain.gd` alongside `_override_move_pos`
- `set_move_override()` sets counter to 25 (latest-wins — resets on any new click)
- `clear_move_override()` resets counter to 0
- `evaluate()` guard: fires before `movement_override = ""` reset; decrements counter per tick; holds AI off for full 25-tick window even after waypoint arrival
- Weapon firing and target override path are unaffected
- Pure `brottbrain.gd` change — no `combat_sim` edits expected
- No GDD update required (§13.7 remains accurate)

---

## BACKLOG HYGIENE

**Prior audit carry-forward:** None — first sub-sprint of Arc O, no prior audit to cross-reference.

**Backlog query used:** `GET /repos/brott-studio/battlebrotts-v2/issues?state=open&labels=backlog&per_page=100`

**Arc O relevant items from open backlog:**
- No open backlog issues directly scope to Arc O (O.1/O.2/O.3 are net-new from the arc brief, not filed as backlog issues).
- Arc O items will be filed by Specc post-sprint if any carry-forward emerges.

**Framework issue noted (non-blocking 🟡):**
- Issue #240: CI audit-gate for sub-sprint plan-merge (structural gate to enforce no-plan-without-audit). Not blocking O.1 — surfaced for pipeline awareness.

---

## SPRINT GOAL

Implement the click-to-move 25-tick suppression window in `brottbrain.gd` so AI cannot pull back a player's intended positional command before the tick window expires. Unit-test all acceptance criteria (ACs 1–7 from spec).

---

## SPRINT TASKS

### [SO.1-001] Implement tick-based click-to-move suppression override
**Source:** `new this sprint` (Arc O brief + `specs/arc-o-o1-click-to-move.md`)  
**Agent:** Nutts  
**Spec ref:** `specs/arc-o-o1-click-to-move.md` on branch `arc-o-gizmo-specs`  
**Scope:** `godot/brain/brottbrain.gd` only. No combat_sim changes.

Implementation checklist (from spec — Nutts must verify each):
- [ ] `var _override_ticks_remaining: int = 0` added alongside `_override_move_pos`
- [ ] `set_move_override(pos)` sets `_override_ticks_remaining = 25`
- [ ] `clear_move_override()` resets `_override_ticks_remaining = 0`
- [ ] `evaluate()` guard fires **before** the `movement_override = ""` reset:
  - Decrements `_override_ticks_remaining` by 1 per tick
  - If `_override_move_pos != Vector2.INF`: sets `movement_override = "move_to_override"`
  - Else (arrived but window still active): sets `movement_override = ""`
  - Returns `true` in both cases (AI suppressed for full window)
- [ ] On tick 26+: falls through to baseline AI logic (no special handling)
- [ ] `set_target_override()` path unchanged (target override fires after window check)
- [ ] Weapon/gadget state (`weapon_mode`, `_pending_gadget`) unchanged during window

**Branch:** `arc-o-nutts-O.1` (Nutts creates, PR into `main`)  
**PR must include:** implementation + unit tests in same commit set.

---

### [SO.1-002] Unit tests for tick-countdown suppression (ACs 1–7)
**Source:** `new this sprint` (spec ACs from `specs/arc-o-o1-click-to-move.md`)  
**Agent:** Nutts (bundled with SO.1-001 — same PR)  
**Scope:** `brottbrain_test.gd` (or equivalent test file)

Acceptance criteria to cover:
1. **Suppression active:** After `set_move_override()`, `movement_override == "move_to_override"` for 25 consecutive ticks
2. **Countdown decrements:** `_override_ticks_remaining` reaches 0 after exactly 25 `evaluate()` calls
3. **AI resumes tick 26:** Tick 26 falls through to baseline AI (not waypoint-driven)
4. **Latest-wins:** `set_move_override()` at tick 10 resets to 25; 25 more suppressed ticks follow
5. **Weapon unaffected:** `weapon_mode` / `_pending_gadget` unchanged during override window
6. **Target override unaffected:** `set_target_override()` path fires correctly after window expires
7. **`clear_move_override()` resets countdown:** `_override_ticks_remaining == 0` post-clear; next tick falls to AI

---

### [SO.1-003] Optic verification — click-to-move integration test
**Source:** `new this sprint` (Arc O brief AC)  
**Agent:** Optic  
**Triggered after:** Nutts PR merged to `main`

Integration test (headless):
- Spawn Brott bot at position A, click target 200px away (position B)
- Assert bot reaches within 32px of B **before** 25 ticks expire, with no AI pullback during the window
- Assert suppression window expires cleanly (AI resumes after tick 25)

Pass threshold: both asserts green. Optic produces verification report. No screenshot required (unit-level test).

---

## AGENT ASSIGNMENTS

| Task | Agent | Input | Output |
|---|---|---|---|
| SO.1-001 + SO.1-002 | Nutts | `specs/arc-o-o1-click-to-move.md` (branch `arc-o-gizmo-specs`) | PR to `main` with impl + tests |
| SO.1-003 | Optic | Merged `main` | Verification report |
| PR review + merge | Boltz | Nutts' PR | Approved + merged |

**Riv orchestration order:** Nutts → Boltz → Optic → Specc

---

## DEPENDENCIES

- `specs/arc-o-o1-click-to-move.md` on `arc-o-gizmo-specs` must be readable by Nutts at spawn (branch exists, confirmed)
- O.2 and O.3 are independent — not blocked by O.1, but not in this sprint's scope

---

## INFRA / CLEANUP

None required this sprint. No CI changes, no dependency updates, no framework overhead for O.1.

---

## SCOPE BOUNDARY

This sprint covers **O.1 only**. O.2 (Brawler speed 120→60px/s) and O.3 (swarm death freeze #361) are separate sub-sprints. Do not scope-creep into either.

---

## ARC CLOSE CONDITION (reminder)

Arc O closes after HCD playtest confirms all three sub-sprints feel correct. **Not automatic.** Riv/Specc do not close the arc; HCD confirmation is required.
