# Sprint 16 — Tech Debt Cleanup + Infrastructure Health

**PM:** Ett
**Status:** Planning (iteration 1 of S16)
**Sprint type:** Multi sub-sprint cleanup/infra arc
**Iteration sizing target:** S16.1 small, S16.2 medium, S16.3 small

---

> ## 🛑 SCOPE GATE — READ FIRST
>
> **NO behavior changes to `godot/combat/**` gameplay code, especially `godot/combat/combat_sim.gd` and `godot/combat/brott_state.gd`.**
>
> This sprint is **cleanup + infrastructure only**. Any test failure that traces back to a real combat-side regression (Scout accel/decel, 2v2 overtime/SD, `fire_at_range` if triaged as combat-side) **must be quarantined with `skip-with-reason`, not fixed** — preserve the canary, do NOT delete tests, do NOT loosen assertions. Violators: your PR gets rejected; quarantine the assertion instead.
>
> Gameplay/balance fixes for the quarantined items carry forward to a future gameplay sprint (see Carry-Forward Backlog at the bottom of this file).

---

## Goal (condensed from HCD charter)

Close out accumulated test + CI tech debt so the pipeline stops papering over silently-failing tests and opaque main-branch health, and establish per-agent GitHub identities so reviewer-self-approval stops depending on PAT 422 workarounds.

**Acceptance for the S16 arc as a whole (HCD bar):**
- `Godot Unit Tests` passes cleanly on `main` (`push: main`) AND on a dummy code-path PR — both ✅.
- `test_runner.gd` enumerates all sprint test files explicitly — no reliance on shell glob `|| exit 1`.
- At least one agent (Specc) has a per-agent GitHub App or equivalent distinct identity wired into the review/merge path.

---

## Sub-sprint breakdown

S16 is split into three sub-sprints. They are **sequential** (S16.1 → S16.2 → S16.3) because S16.3's acceptance ("Verify green on push: main") depends on S16.1 having already made the suite green.

| Sub-sprint | Theme | Exit criterion | Expected size |
|---|---|---|---|
| **S16.1** | Test suite cleanup + quarantines | `Godot Unit Tests` ✅ on dummy code-path PR | Medium (6 tasks) |
| **S16.2** | Per-agent GitHub App (Specc) | Specc can self-merge an audit PR w/o 422 workaround | Medium (3–4 tasks, ops-heavy) |
| **S16.3** | Main-branch CI observability | `Verify` ✅ on `push: main` | Small (1–2 tasks) |

Ett will re-spawn per iteration to emit each sub-sprint's individual plan file (`sprint-16.1.md`, etc.) once the prior audit lands. **This file is the arc-level plan; per-iteration task IDs below are the definitive list.**

---

## S16.1 — Test suite cleanup

**Goal:** Godot Unit Tests suite passes cleanly on a dummy code-path PR, with every failing test either fixed or quarantined with a recorded reason.

### Tasks

#### [S16.1-001] Fix `test_sprint12_2.gd` Plasma Cutter + Plating weight
- **Owner:** Nutts
- **Scope:** pure test-data fix. Update the expected value to match canon: Plasma Cutter (8 kg) + Plating (**15 kg**) = 23 total, well under the 30-cap. Gizmo confirmed `armor_data.gd` and GDD both say Plating = 15 kg; the test has stale `5` for Plating.
- **Files:** `godot/tests/test_sprint12_2.gd` only. `armor_data.gd` diff must be empty.
- **Acceptance:** `test_sprint12_2.gd` passes the Plasma Cutter + Plating case locally and in CI.

#### [S16.1-002] Fix `test_sprint10.gd` parse error
- **Owner:** Nutts
- **Scope:** resolve `Cannot infer the type of "d"` by adding an explicit type annotation to the offending loop variable (or local). If the fix is non-trivial (> ~10 lines) or requires changing what `d` refers to, **quarantine instead** by wrapping the affected test case in `skip-with-reason` and file a backlog note. Do NOT rewrite the test logic.
- **Files:** `godot/tests/test_sprint10.gd` only.
- **Acceptance:** `test_sprint10.gd` parses and runs under Godot 4.4.1 headless.

#### [S16.1-003] Triage `test_sprint12_1.gd` Plasma Cutter fire-at-range
- **Owner:** Nutts (triage) → Patch if combat-side (quarantine only)
- **Scope:** determine whether the failure is test-scaffolding drift against the new `simulate_tick` API (in-scope fix) or a real `fire_at_range` regression in `godot/combat/**` (out-of-scope → quarantine). Dump the failure path, read `simulate_tick` signature, compare to what the test is calling.
- **Decision rule:**
  - If test-side (scaffolding drift): **fix** the test call site. Keep diff narrow. `godot/combat/**` diff must be empty.
  - If combat-side (real `fire_at_range` regression): **quarantine** via `skip-with-reason` with a pointer: `# SKIP: real fire_at_range regression at 2.5-tile range, carry-forward to gameplay sprint per sprint-16.md carry-forward backlog`. Do NOT fix the code.
- **Acceptance:** failure no longer trips CI (either passing or skipped-with-reason).

#### [S16.1-004] Quarantine combat-side regressions
- **Owner:** Nutts
- **Scope:** mark the three combat-side failures in `test_sprint12_1.gd` as `skip-with-reason`. Do NOT delete tests. Do NOT loosen assertions. Do NOT touch `godot/combat/**`.
  - Scout 0→max accel ~0.33s → `brott_state.accelerate_toward_speed` regression
  - Scout decel-to-stop ~0.25s → same code path as above
  - 2v2 overtime 60s / SD 75s / timeout 120s → `combat_sim.gd` overtime/SD plumbing regression
- **Skip format:** add a `skip-with-reason` helper (or the project's existing equivalent) that prints `SKIP: <test name> — <reason> — carry-forward to future gameplay sprint (see sprints/sprint-16.md)` and does not increment `fail_count`. If no such helper exists, add a minimal one in `test_runner.gd` / shared test util. Gizmo must still be able to see the canaries exist; the quarantine is a pause, not a delete.
- **Acceptance:** these three cases do not fail CI; `Godot Unit Tests` logs print the skip reasons verbatim; tests are still present and discoverable in the source tree.

#### [S16.1-005] Extend `test_runner.gd` to explicit enumeration (sprints 11+)
- **Owner:** Nutts
- **Scope:** remove reliance on the shell glob `for f in godot/tests/test_sprint1[0-9]_*.gd godot/tests/test_sprint1[0-9].gd; do ... || exit 1; done` in `.github/workflows/verify.yml`. Replace with explicit function calls inside `test_runner.gd` — add `_run_sprint11_tests()`, `_run_sprint11_2_tests()`, `_run_sprint12_*`, `_run_sprint13_*`, etc., calling each file's top-level entrypoint. The runner must exit non-zero if any test file fails; no file can silently exit 0 after reporting failures.
- **Workflow change:** simplify `.github/workflows/verify.yml` to just `godot --headless --path godot/ --script res://tests/test_runner.gd` (no glob loop).
- **Acceptance:**
  - `test_runner.gd` explicitly references every `test_sprint*.gd` file currently in `godot/tests/` (use `ls godot/tests/test_sprint*.gd | grep -v .uid` at plan time to enumerate).
  - `verify.yml` no longer has the glob-for-loop.
  - A test file that intentionally fails causes the runner to exit non-zero (validate via a throwaway smoke test before PR, remove before merge).

#### [S16.1-006] Minor doc + warning fixes (doc-only / cosmetic)
- **Owner:** Nutts (fold into S16.1-001 PR if trivial; separate PR otherwise)
- **Scope:**
  - Fix GDD §3.2 weapon table: Plasma Cutter `Range` row shows `1.5`; canonical is `2.5` per S12 spec + `weapon_data.gd`. Update the GDD row.
  - Audit Minigun row in the same table: GDD shows fire rate `10`, Balance v2 says `6`. Verify which is canon (`weapon_data.gd` is the tiebreaker); update whichever is stale. If `weapon_data.gd` itself is out of date relative to Balance v2, **surface as 🟡** — do NOT change `weapon_data.gd` (that's a balance decision, out of scope here).
  - Fix `godot/arena/arena_renderer.gd` warnings-as-errors parse warning. Either fix the warning at the source (preferred, if trivial) or suppress it consistently via the standard GDScript annotation. No renderer behavior change.
- **Acceptance:** GDD §3.2 matches `weapon_data.gd`; `arena_renderer.gd` no longer emits the warning; any balance-data mismatches are called out in PR description, not silently edited.

### S16.1 review/verify/audit assignments

- **Build:** Nutts
- **Review:** Boltz
- **Verify:** Optic — targeted run of `Godot Unit Tests` on a dummy code-path PR (e.g., a no-op comment in `godot/combat_sim.gd`). Confirm:
  1. Full suite exits green.
  2. Skip messages for quarantined cases appear in the log.
  3. No test file silently exits 0 after a failure.
- **Audit:** Specc → `studio-audits/audits/battlebrotts-v2/v2-sprint-16.1.md`

### S16.1 exit criteria

- [ ] S16.1-001 through S16.1-006 all landed on main.
- [ ] Dummy code-path PR shows `Godot Unit Tests` ✅.
- [ ] Skip reasons visible in CI log for the three combat-side quarantined cases (+ possibly #3 if triaged combat-side).
- [ ] `test_runner.gd` explicitly enumerates sprint 11+ test files.
- [ ] `godot/combat/**` diff across all S16.1 PRs is empty (verified via `git diff origin/main...sprint-16.1-* -- godot/combat/`).

### S16.1 risks

- **Risk:** quarantine helper doesn't exist; adding one grows scope.
  **Mitigation:** minimal helper (< 15 lines) in `test_runner.gd` or a new `godot/tests/test_util.gd`. If it grows, split into S16.1-004a (add helper) and S16.1-004b (apply to failures).
- **Risk:** Triage on #3 (`fire_at_range`) ambiguous, Nutts spends too long deciding.
  **Mitigation:** 30-min triage budget, then escalate to Riv for a "test-side or quarantine-it" call. Default if unclear: **quarantine**.
- **Risk:** Explicit-enumeration change to `test_runner.gd` breaks the runner itself.
  **Mitigation:** validate locally with `godot --headless --script res://tests/test_runner.gd` before opening PR.

---

## S16.2 — Per-agent GitHub App for Specc

**Goal:** Specc has a distinct GitHub identity (App or bot account) so its reviewer self-approval doesn't need the shared-PAT 422 workaround documented in the S15.1 KB.

### Tasks

#### [S16.2-001] Create Specc GitHub App + install on org
- **Owner:** Patch (infra) — needs HCD org-admin approval to install
- **Scope:** create a GitHub App named `brott-studio-specc` (or equivalent). Minimal permissions: `contents:write`, `pull_requests:write`, `issues:write`, `metadata:read`. Install on `brott-studio` org scoped to `battlebrotts-v2` and `studio-audits` repos. Generate private key. Store securely.
- **HCD escalation:** 🔴 — App creation + install requires HCD action on the GitHub org. Riv surfaces this to The Bott to coordinate.
- **Acceptance:** App exists, installed on both repos, private key stored at `~/.config/gh/brott-studio-specc-app.pem` (mode 0600) on the agent host.

#### [S16.2-002] Wire Specc's spawn/tooling to use the App
- **Owner:** Patch → The Bott (profile update)
- **Scope:**
  - Add a helper script (e.g. `~/bin/specc-gh-token` or similar) that mints a short-lived installation token from the Specc App private key. Tokens expire in 1 hour — fine for Specc's typical audit duration.
  - Update Specc's spawn prompt / profile at `studio-framework/agents/specc.md` (and its inline Core Rules) to: (a) read the App token for any `gh` / `git` operations that require Specc identity, (b) fall back to the shared PAT only for read-only metadata queries.
  - Branch protection on `studio-audits` does not currently block Specc's merges, so the immediate win is Specc self-review/self-merge on PRs Specc opens in `battlebrotts-v2` for KB updates. Confirm branch protection on `battlebrotts-v2` main allows the Specc App as a reviewer.
- **Acceptance:** Specc spawned in a dry-run session can `gh pr create --repo brott-studio/battlebrotts-v2 ...` as its own identity (commit author shows `brott-studio-specc[bot]`, review shows same).

#### [S16.2-003] Validate end-to-end on a dummy audit PR
- **Owner:** Specc (dry-run)
- **Scope:** run a dry-run mini-audit that opens a KB PR in `battlebrotts-v2`, approves-self, and merges. Confirm: no 422, no shared-PAT fallback on the review/merge path.
- **Acceptance:** dummy PR merged by `brott-studio-specc[bot]` with no manual intervention and no PAT-reuse 422.

#### [S16.2-004] Document the setup in `docs/kb/`
- **Owner:** Specc (post-validation)
- **Scope:** write `docs/kb/per-agent-github-apps.md` describing the Specc App setup, token helper, rotation, and a template for adding similar apps for Boltz / Nutts if future sprints extend this pattern.
- **Acceptance:** KB entry committed, referenced from the S16.2 audit.

### S16.2 review/verify/audit

- **Build:** Patch (ops) + The Bott (profile update)
- **Review:** Boltz (profile/tooling PR), HCD (App install approval)
- **Verify:** Specc (S16.2-003 dry-run IS the verification)
- **Audit:** Specc → `v2-sprint-16.2.md`

### S16.2 risks

- **Risk:** HCD unavailable to approve org-level App install → S16.2 blocked.
  **Mitigation:** 🔴 escalate on first iteration of S16.2 planning so HCD has lead time. If blocked > 1 sprint, S16.3 proceeds independently (S16.2 and S16.3 are independent once S16.1 is done).
- **Risk:** App token rotation breaks Specc mid-audit.
  **Mitigation:** 1-hour token window is longer than any observed Specc audit; helper mints fresh on each spawn.

---

## S16.3 — Main-branch CI observability

**Goal:** Verify workflow runs on merges to main, so main-branch health is visible in the Actions tab without opening a PR.

### Tasks

#### [S16.3-001] Add `push: main` trigger to `verify.yml`
- **Owner:** Patch
- **Scope:**
  - Add `push: { branches: [main], paths-ignore: [docs/**, sprints/**, '**/*.md'] }` alongside the existing `pull_request` trigger.
  - Keep `paths-ignore` the same as the PR trigger so doc-only merges still don't spin up Godot.
- **Files:** `.github/workflows/verify.yml` only.
- **Acceptance:** after merge to main, a Verify run appears in Actions for the merge commit.

#### [S16.3-002] Confirm warnings-as-errors consistency
- **Owner:** Nutts
- **Scope:** check that the `project.godot` `warnings_as_errors` setting (if any) is consistent between local Godot and CI Godot. If the `arena_renderer.gd` warning from S16.1-006 re-surfaces, iterate. No new warnings-as-errors policy — just confirm existing setting is applied uniformly.
- **Acceptance:** `Godot Unit Tests` job passes on main post-merge with no warning-as-error regressions.

#### [S16.3-003] End-to-end validation
- **Owner:** Optic
- **Scope:** after S16.3-001 merges, observe the next `main` push CI run. Confirm ✅ on both the merge commit AND on a subsequent dummy code-path PR. Report via Optic verification doc as usual.
- **Acceptance:** two green Verify runs in the Actions tab — one from `push: main`, one from a fresh PR — both after S16.3 changes land.

### S16.3 risks

- **Risk:** `push: main` trigger spams CI on doc-only merges → waste.
  **Mitigation:** `paths-ignore` filter matches the PR trigger exactly. Doc merges still skip Godot.
- **Risk:** If main is red at the moment S16.3-001 lands, everyone sees it — which is the point, but HCD/Bott may want a heads-up.
  **Mitigation:** S16.3 runs **after** S16.1, so main should already be green when the push trigger lands. Sequencing is the mitigation.

---

## Cross-sub-sprint conventions

- **Branch naming:** `sprint-16.1-<slug>`, `sprint-16.2-<slug>`, etc.
- **PR titles:** `[S16.1-001] <summary>`, etc. Use task IDs verbatim.
- **Commit messages:** include task ID; small coherent commits per task.
- **Agent assignments:** Nutts owns code + tests; Patch owns CI/ops/infra; Boltz reviews + merges; Optic verifies; Specc audits per sub-sprint.
- **Iteration discipline:** per HCD charter — don't ship everything in one iteration. Ett will re-plan per sub-sprint based on the prior Specc audit.
- **Iteration-sizing learning from S15:** S15.2 burned three Gizmo rulings for a "trivial" fix. Expect S16.1 to surface at least one "wait, is this combat-side or test-side?" moment that needs escalation. Don't over-optimize for one-shot success.

---

## Carry-Forward Backlog (explicit)

These items are **out of scope for S16** by HCD decree (scope gate). They carry forward to a future gameplay/balance sprint. Preserved as `skip-with-reason` quarantines in S16.1-004 so the canaries remain visible.

| # | Source test | Failure | Likely code path |
|---|---|---|---|
| 1 | `test_sprint12_1.gd :: Scout 0→max accel ~0.33s` | Real regression — matches S12 spec | `godot/combat/brott_state.gd :: accelerate_toward_speed` |
| 2 | `test_sprint12_1.gd :: Scout decel-to-stop ~0.25s` | Real regression — same path as #1 | `godot/combat/brott_state.gd :: accelerate_toward_speed` (decel branch) |
| 4 | `test_sprint12_1.gd :: 2v2 overtime 60s / SD 75s / timeout 120s` | Real regression — matches GDD | `godot/combat/combat_sim.gd` overtime/SD plumbing |
| 3? | `test_sprint12_1.gd :: Plasma Cutter fire at 2.5 tiles` | **Pending triage in S16.1-003.** If combat-side → carry-forward. | `godot/combat/**` (likely `fire_at_range`) |

**Handoff instructions for the future gameplay sprint:**
- Pull up the skip-with-reason messages first — they point at the exact file/function.
- Do NOT start by deleting the quarantines; start by running the un-skipped tests and confirming the failure reproduces.
- Scout accel/decel (#1, #2) share a code path; likely one fix covers both.
- 2v2 overtime/SD (#4) is its own investigation — plumbing, not tuning.

---

## Open questions / 🟡 surfaced

- **Minigun fire rate canon:** if Balance v2 says `6` and `weapon_data.gd` says `10` (or vice versa), HCD should rule before any balance PR. S16.1-006 surfaces the mismatch but does not change balance data.
- **S16.2 App install timing:** needs HCD org-admin action. Surface to The Bott at S16.2 spawn time (not this plan).

---

## References

- HCD charter: this task spec (2026-04-17).
- Gizmo's design input for S16 (failure classification table): incorporated above.
- S15 close-out + carry-forward: `sprints/sprint-15.md` bottom.
- S15.1 audit (Grade B): `studio-audits/audits/battlebrotts-v2/v2-sprint-15.1.md` — includes the PAT 422 KB note.
- S15.2 audit (Grade A−): `studio-audits/audits/battlebrotts-v2/v2-sprint-15.2.md` — scope-gate discipline reference.
- CI config snapshot: `.github/workflows/verify.yml` (commit `cf24719`).

---

**Plan authored by Ett, 2026-04-17. Next step: Riv spawns Nutts on [S16.1-001].**
