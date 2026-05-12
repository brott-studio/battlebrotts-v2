# Sprint Plan — O.3: Swarm Death Freeze Fix

**Arc:** O — Control Feel  
**Sub-sprint:** O.3  
**Issue:** #361 (P1 — Swarm Death Freeze)  
**Branch:** arc-o-ett-o3  
**Date:** 2026-05-09  
**Planner:** Ett

---

## Step 0 — Audit Verification Gate

Prior audit: `audits/battlebrotts-v2/v2-sprint-O.2.md` — **PRESENT** on `studio-audits/main`. ✅  
Gate: PASS. Proceeding to Step A.

---

## Step A — Continue-or-Complete

**DECISION: continue**

**REASON:** O.3 has not yet been implemented or merged. Arc-intent verdict from Gizmo is `satisfied` — but that verdict is *prospective*: it states that once O.3 is merged, all three Arc O pillars will be addressed. The spec exists; the code does not yet exist in main. The arc is NOT complete until the implementation is built, reviewed, verified, and audited. Continue with O.3 sprint. Arc-complete marker fires AFTER Specc closes O.3.

**GIZMO ARC-INTENT:** `satisfied` (prospective — contingent on O.3 merge)  

---

## Goals

1. Implement the swarm death freeze fix in `godot/arena/arena_renderer.gd` per Gizmo's spec
2. Verify: 5 simultaneous deaths → no freeze, frame time < 33ms, `active_particle_count ≤ 120`
3. Close the final Arc O blocker (#361, P1)
4. Address O.2 carry-forward items in-scope for this sprint (stale assertion grep checklist — process only; documentation item deferred)
5. Land sprint with full pipeline: Nutts → Boltz → Optic → Specc
6. **Arc-complete** expected after Specc audit closes O.3 — this is the final sub-sprint of Arc O

---

## Design Input Summary

**Source:** Gizmo spec on `arc-o-gizmo-o3` at `specs/arc-o-o3-swarm-death-freeze.md`

Root cause: `_on_death()` runs synchronously on signal, spawning 20–30 particles × O(200) linear scan each. Multi-death compound: `death_freeze_timer` resets on every death, preventing particle cleanup during burst. Two compounding fixes required:

- **Fix 2A** — `DEATH_BURST_MAX = 120` constant + `_drain_oldest_particles()` helper + cap pre-check in `_spawn_death_burst()`  
- **Fix 2B** — Refactor `_on_death()` to keep timers synchronous; defer particle/debris burst via `call_deferred("_spawn_death_burst", pos)`
- **Debris guard** — add `death_debris.size() < 30` guard inside `_spawn_death_burst()` (noted in Gizmo acceptance criteria, AC #4)

No GDD changes. No combat simulation changes. Pure renderer internals.

---

## Task Breakdown

### Build (Nutts)

| ID | Task | Source | Agent |
|----|------|--------|-------|
| SO.3-001 | Add `DEATH_BURST_MAX = 120` constant to top of `arena_renderer.gd` | [#361] + Gizmo spec | Nutts |
| SO.3-002 | Add `_drain_oldest_particles(count: int)` helper — linear pass, deactivate oldest N active pool slots | [#361] + Gizmo spec | Nutts |
| SO.3-003 | Refactor `_on_death()`: extract particle/debris loops into `_spawn_death_burst(pos)`, keep timers synchronous, add `call_deferred("_spawn_death_burst", brott.position.duplicate())` | [#361] + Gizmo spec | Nutts |
| SO.3-004 | Add debris unbounded guard: `death_debris.size() < 30` check inside `_spawn_death_burst()` | [#361] + Gizmo spec AC#4 | Nutts |
| SO.3-005 | Write arc test file `godot/tests/test_arc_o3_death_freeze.gd` — 5 tests covering all 5 Gizmo acceptance criteria | [#361] + Gizmo spec | Nutts |
| SO.3-006 | Register test file in `godot/tests/test_runner.gd` `SPRINT_TEST_FILES` | new this sprint | Nutts |
| SO.3-007 | **Pre-push checklist (O.2 lesson):** run `grep -r "<old_value>" godot/tests/` for any changed constants before committing; confirm zero stale hits | [#365] carry-forward | Nutts |

**Implementation notes for Nutts:**
- Reference Gizmo's spec (`specs/arc-o-o3-swarm-death-freeze.md` on branch `arc-o-gizmo-o3`) for exact GDScript snippets. Use them directly — spec was written from code analysis.
- `call_deferred` signature: `call_deferred("_spawn_death_burst", brott.position.duplicate())` — pass `.duplicate()` of position to avoid mutation in the deferred call.
- O(1) free-list optimization for `_claim_particle()` is **explicitly out of scope** — Gizmo flagged it as optional tidy-up, not a merge requirement.
- Commit prefix: `[SO.3-NNN]` — one commit per logical unit; fix commits follow `fix(test):` or `fix(renderer):` prefix.
- `idempotency-key: sprint-O.3` in PR body.

### Review (Boltz)

| ID | Task | Source | Agent |
|----|------|--------|-------|
| SO.3-008 | Review Nutts PR — confirm: (a) `_on_death()` timers still synchronous, (b) `_spawn_death_burst` has 2A cap check before debris/particle loops, (c) deferred call passes position copy not reference, (d) debris guard present, (e) no changes outside `arena_renderer.gd` + test file | new this sprint | Boltz |

**Boltz note:** O.2 audit identified that Nutts fixed iteratively rather than grepping the full test suite. Verify Nutts ran the `grep -r` checklist (SO.3-007) — look for a note in the PR description or commit message confirming it. If not present, request it explicitly.

### Verify (Optic)

| ID | Task | Source | Agent |
|----|------|--------|-------|
| SO.3-009 | Gate 1: Code presence — `DEATH_BURST_MAX`, `_drain_oldest_particles`, `_spawn_death_burst`, deferred call all present in `arena_renderer.gd` | Gizmo spec | Optic |
| SO.3-010 | Gate 2: Test file present and registered in `test_runner.gd` `SPRINT_TEST_FILES` | new this sprint | Optic |
| SO.3-011 | Gate 3: CI green on merge commit | standing | Optic |
| SO.3-012 | Gate 4: AC verification — code-path trace for all 5 Gizmo ACs: (1) single death VFX intact, (2) 3-burst active_particle_count ≤ 120, (3) 5-burst no freeze, (4) debris ≤ 30 entries on 5-burst, (5) death_freeze_timer resets to 6.0 | Gizmo spec | Optic |

### Audit (Specc)

| ID | Task | Source | Agent |
|----|------|--------|-------|
| SO.3-013 | Full sprint audit → `audits/battlebrotts-v2/v2-sprint-O.3.md` on `studio-audits/main` | standing | Specc |
| SO.3-014 | Include arc-close note in audit: O.3 is the final sub-sprint of Arc O; arc-complete marker expected from Riv after audit lands | new this sprint | Specc |

---

## Acceptance Criteria

Directly from Gizmo spec:

1. **Single death regression:** explosion VFX (hit-stop, flash, shake, debris, sparks) plays identically to pre-fix
2. **3-death burst:** `active_particle_count ≤ 120` after burst; no >32ms frame spike
3. **5-death burst in ≤3 frames:** game does not freeze; `tick_visuals()` advances `death_freeze_timer` normally
4. **Debris guard:** `death_debris` does not grow beyond 30 entries during 5-enemy burst
5. **Hit-stop timing:** `death_freeze_timer` resets to 6.0 per death (confirmed via test)

All 5 must be green for Optic PASS.

---

## Agent Assignments

| Phase | Agent | Tasks |
|-------|-------|-------|
| Build | Nutts | SO.3-001 through SO.3-007 |
| Review | Boltz | SO.3-008 |
| Verify | Optic | SO.3-009 through SO.3-012 |
| Audit | Specc | SO.3-013 through SO.3-014 |

Pipeline order: Nutts → Boltz (review + merge) → Optic → Specc

---

## Dependencies

- Gizmo spec: `specs/arc-o-o3-swarm-death-freeze.md` on branch `arc-o-gizmo-o3` — Nutts must read this before writing any code
- No external blockers; #361 is self-contained to `arena_renderer.gd`

---

## Infra / Cleanup

- No CI changes required
- No new dependencies
- O(1) free-list optimization (`_claim_particle()`) explicitly deferred per Gizmo — not in scope

---

## BACKLOG HYGIENE

**Carry-forward from O.2 audit → GitHub Issues check:**

| O.2 Carry-forward | Issue Filed? | Disposition this sprint |
|---|---|---|
| Stale cross-suite assertion pattern (#365) | ✅ `#365` open | Addressed via process: SO.3-007 requires Nutts to run grep checklist before push. No code change needed. |
| `speed_override` field undocumented (#366) | ✅ `#366` open | Out of scope for O.3 (area:docs, prio:low, unrelated to freeze fix). Remains in backlog. |

**O.1 carry-forward:**
- `#363` (25-tick suppression window hardcoded) — open, prio:P3, out of Arc O scope. Remains in backlog.

**Backlog query used:** `GET /repos/brott-studio/battlebrotts-v2/issues?state=open&labels=backlog&per_page=100`  
All O.2 carry-forward items confirmed filed as issues. No compliance gaps.

**Other backlog items reviewed:** No backlog item is within Arc O scope or high enough priority to pull into O.3. Remaining P1+ items are audio, UX, and framework work belonging to future arcs.

---

## Arc Status Note

**This is the final sub-sprint of Arc O.**

Arc-complete fires after Specc's O.3 audit lands on `studio-audits/main`. Riv should emit the arc-complete marker at that point and report to The Bott. Do not emit arc-complete before Specc closes.

Arc O goal ("Make the player feel in control — clicks go where intended, battle is readable at a glance, and the game doesn't freeze under stress") will be fully satisfied upon O.3 merge:
- O.1 ✅ Click-to-move reliability
- O.2 ✅ Brawler speed correction
- O.3 → Swarm death freeze (pending implementation)
