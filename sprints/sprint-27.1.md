# Sprint 27.1 — Arc I S(I).1: AutoDriver harness scaffold + chassis-pick flow

**Arc:** I — "Optic Plays The Game"
**Sub-sprint:** S(I).1 (first of arc, fuse-cap 9)
**Pillar:** 1 of 3 — Native GDScript auto-driver, `godot --headless`, per-PR gate
**Author:** Ett
**Date:** 2026-04-27

---

## Step A — Continue or Complete?

**DECISION: continue**
**REASON:** First sprint of Arc I. Gizmo arc-intent verdict = `progressing` (Pillar 1 scaffold + first flow lands here; S(I).2 full flows, Pillar 2 bridge, Pillar 3 sims still missing). No prior audit (first sub-sprint, audit-verification gate skipped). Fuse 1/9.

---

## Goals

S(I).1 ships the Pillar 1 foundation:
1. **`AutoDriver` base class** — 6-verb headless driving API (locked in Gizmo's spec)
2. **`TestFirstFlowChassisPick`** — first end-to-end user flow (boot → menu → NEW RUN → chassis pick → arena loaded → first tick)
3. **CI integration** — verify.yml runs all `godot/tests/auto/test_*.gd` files headless on every PR

**Per-PR gate:** a synthetic break of `_on_chassis_picked` must fail CI in <10s wall clock for the test invocation.

---

## Design Input (Gizmo)

- **GDD drift:** PASS. §14 "Testing Infrastructure" added via PR #324 (`arc-i-gdd-auto-driver-section` → `main`). Docs only, awaiting Boltz review.
- **Headless boot:** No `--test-mode` path. Main scene boots headless-safe. OGG preloads handled by existing `--import` step. `_setup_test_environment()` helper (<10 LOC, harness-internal) pre-marks `FE_KEY_*` entries to suppress overlay flakiness.
- **AutoDriver API (locked, 6 verbs + 1 helper):**
  - `click_chassis(index: int)` — invokes UI button signal path
  - `click_reward(index: int)` — invokes `RewardPickScreen.picked` signal
  - `tick(n: int)` — advance SceneTree n frames at 1/60s each
  - `get_arena_state() → Dictionary` — `{in_arena, tick_count, match_over, player{hp,max_hp,energy,alive}, enemies[...], winner_team}`
  - `get_run_state() → Dictionary` — `{active, current_battle_index, battles_won, retries_remaining, equipped_chassis, equipped_weapons, equipped_armor, equipped_modules, current_screen, current_encounter{archetype_id,tier,arena_seed}}`
  - `force_battle_end(winner_team: int)` — forces match over, emits `on_match_end`
  - `assert_state(path, value)` — dot-path against `{arena: ..., run: ...}`, collects failures (helper, NOT a verb)
- **First flow (TestFirstFlowChassisPick):**
  ```
  boot → tick(30) → assert menu → click NEW RUN → tick(15) →
  assert RUN_START screen → click_chassis(0) → tick(60) →
  assert arena loaded + chassis=0 → tick(60) → assert tick_count≥1 → finish
  ```

---

## Tasks

### T1 [SI1-001] — `AutoDriver` base class + `TestFirstFlowChassisPick`
**Owner:** Nutts
**Source:** new this sprint (Gizmo S(I).1 design output)

**Deliverables:**
- `godot/tests/auto/auto_driver.gd` — base class implementing the 6 verbs + `assert_state` helper + `_setup_test_environment()`
- `godot/tests/auto/test_first_flow_chassis_pick.gd` — extends `auto_driver.gd`, implements the chassis-pick(0) → arena-loaded → first-tick flow
- Register both files in `godot/tests/test_runner.gd` `SPRINT_TEST_FILES` array (**hard rule: every new test file must be registered**)
- Wire API verbs against actual game scene nodes — Nutts must read `/tmp/bb2/godot/` to resolve exact NodePaths for GameFlow, RunState, ArenaRenderer (Gizmo's spec uses conceptual names; Nutts resolves them)
- Include any auto-generated `.uid` files in the PR (Godot 4 generates these on first import)

**Acceptance:**
- `godot --headless --path godot/ --script "res://tests/auto/test_first_flow_chassis_pick.gd"` exits 0 on a clean checkout
- A deliberate break in `_on_chassis_picked` (synthetic throw or null deref) → exit 1
- Test wall-clock <15s

### T2 [SI1-002] — CI step in `verify.yml`
**Owner:** Nutts (same PR as T1)
**Source:** new this sprint (Gizmo S(I).1 CI spec)

**Deliverables:**
- Add new step "Run AutoDriver headless flow tests" after the existing "Run Godot tests" step in `.github/workflows/verify.yml`
- Iterate all `godot/tests/auto/test_*.gd` files via shell glob; each gets its own `godot --headless --script` invocation (one process per file — isolation)
- Gate on `needs.changes.outputs.code == 'true'` (same condition as the existing godot-tests job)
- Confirm `--import` step (currently ~line 113 of verify.yml) runs before this step so OGGs/.uids are ready

**Acceptance:**
- verify.yml CI green end-to-end on the merged PR
- AutoDriver step runs and passes; intentional pre-merge break-test (manually verified by Nutts before pushing the final commit) proves the gate fires

### T3 [SI1-003] — Boltz review + merge of PR #324 (GDD §14 docs)
**Owner:** Boltz
**Source:** Gizmo S(I).1 GDD update

**Deliverables:**
- Review `arc-i-gdd-auto-driver-section` → `main` (PR #324)
- Docs-only — no code changes; verify §14 "Testing Infrastructure" content matches the locked AutoDriver API from Gizmo's spec
- Merge under standing branch-protection rules using Boltz's GitHub App identity (`BOLTZ_APP_ID=3459519`, `BOLTZ_INSTALLATION_ID=125975574`, token via `~/bin/boltz-gh-token`)

**Acceptance:**
- PR #324 merged to `main`
- §14 lives in GDD on `main` before Specc audits S(I).1

---

## Acceptance Criteria (sprint-level)

1. `godot --headless --script godot/tests/auto/test_first_flow_chassis_pick.gd` exits 0 on a clean main branch.
2. A deliberate break in `_on_chassis_picked` causes the harness to exit 1, caught by CI.
3. Total Pillar-1 suite (one test file) runs in <15s wall clock.
4. PR #324 merged.
5. verify.yml CI green end-to-end on the Nutts PR.

---

## Risks

- **Node-path discovery.** Gizmo's API spec uses conceptual node names (GameFlow, RunState, ArenaRenderer). Nutts must read the actual `/tmp/bb2/godot/` project to resolve concrete NodePaths. Mitigation: this is task T1 work — explicit in deliverable.
- **`.uid` file generation.** Godot 4 generates `.uid` companion files for every new `.gd` on import. If Nutts forgets to commit them, CI's `--import` step regenerates them, but this can produce post-merge churn. Mitigation: Nutts to confirm `.uid` files committed alongside the new `.gd` files.
- **Headless flakiness from `FE_KEY_*` overlays.** Mitigated by Gizmo's `_setup_test_environment()` helper (pre-marks first-time-seen overlay keys).
- **Single-test suite isolation.** Running each `test_*.gd` as its own godot process is intentional (state isolation) but adds ~3-5s startup overhead per file. With one file in S(I).1 we're well under budget; revisit if Pillar-1 grows past ~5 files.

---

## Agent Assignments

| Task | Owner | Model |
|------|-------|-------|
| T1 [SI1-001] AutoDriver base + first flow | **Nutts** | Sonnet 4.6 |
| T2 [SI1-002] verify.yml CI step (same PR) | **Nutts** | Sonnet 4.6 |
| T3 [SI1-003] PR #324 review + merge | **Boltz** | Opus 4.7 |
| Verify (Godot unit tests + AutoDriver suite, CI green) | **Optic** | Sonnet 4.6 |
| Audit S(I).1 | **Specc** | Sonnet 4.6 |

**Spawn config reminder for Boltz:** include `BOLTZ_APP_ID=3459519` and `BOLTZ_INSTALLATION_ID=125975574` in task prompt (per TOOLS.md GitHub App rule, learned from S24.1).

---

## Dependencies

- T3 (PR #324 merge) is independent of T1/T2 and can run in parallel. Specc's audit benefits from #324 being on `main` first (so §14 is in the GDD when audited), but does not block.
- T1 and T2 ship in **one PR** to keep the gate atomic (harness + CI integration land together).

---

## Out of Scope (DO NOT do this sprint)

- Additional flows beyond `TestFirstFlowChassisPick` — those are S(I).2.
- Pillar 2 (Playwright/JS bridge) — S(I).5+.
- Pillar 3 (combat-sim agent, nightly stats) — S(I).3+.
- Any content/balance changes.
- Any upstream OpenClaw PRs.

---

## BACKLOG HYGIENE

**Carry-forward audit:** First sub-sprint of Arc I — no prior arc-internal Specc audit to cross-reference. Backlog query used:
```
GET /repos/brott-studio/battlebrotts-v2/issues?state=open&labels=backlog&per_page=100
```

**Findings:**
- Arc I has **no pre-existing prerequisite issues** filed against it — this is a greenfield arc launched from the 2026-04-27 brief. Expected.
- **Pre-existing infra/framework backlog items relevant to Arc I** (visible to future sub-sprints, NOT pulled into S(I).1):
  - **#246** [framework, prio:high] Subagent event-truncation pattern on Opus 4.7 build/verifier roles. **Relevant to Arc I:** Optic verifications of headless Godot runs may run long; if event-truncation recurs, S(I).1 verify could be affected. Standing rule: keep Optic on Sonnet 4.6 (already in agent assignments). No action needed this sprint.
  - **#247** [framework, prio:mid] Optic spec must require screenshot paths in return payload. **Relevant to Arc I:** AutoDriver suite verification doesn't produce screenshots (headless GDScript), so this is partially obviated by Pillar 1, but still applies to Pillar 2 (Playwright). Track for S(I).5.
  - **#240** [framework, prio:high] Structural audit-gate: CI check blocks sub-sprint plan-merge if prior audit missing. **Cross-cutting.** Not Arc I scope.
  - **#239** [ci, prio:high] Required-context reachability preventive check (S18.4 Finding 2). **Cross-cutting CI.** Not Arc I scope.
  - **#225** [framework, prio:mid] Enforce Optic-as-sole-merger on `main`. **Cross-cutting.** Not Arc I scope.
  - **#121** [tech-debt, prio:mid] Godot headless class-cache — one-time import in CI + worktree bootstrap. **Adjacent to Pillar 1:** verify.yml already does `--import`; if AutoDriver suite hits cold-cache flakiness, revisit. Not pulled into S(I).1.
- **No carry-forward gaps to flag** — there are no prior Arc I audits, so there's nothing missing from the issue tracker. ✓

**Recommendation to The Bott:** None. Backlog hygiene is clean for Arc I launch. Watch #246 across the arc for build-agent event-truncation; first natural review point is post-Specc-audit of S(I).1.
