# Sprint 16.2 — Per-agent GitHub App for Specc + Test Hygiene Carry-Forwards

**PM:** Ett
**Status:** Planning (iteration 2 of S16)
**Sprint type:** Sub-sprint (ops/infra + test-hygiene carry-forward)
**Parent arc:** [`sprints/sprint-16.md`](./sprint-16.md) — see §"S16.2 — Per-agent GitHub App for Specc"

---

> ## 🛑 SCOPE GATE — READ FIRST
>
> **S16.2 is ops/infra only.** NO changes to `godot/**` (all subtrees: `godot/combat/**`, `godot/data/**`, `godot/arena/**`, `godot/tests/**`), `docs/gdd.md`, or any balance/design-of-record file. The only files this sub-sprint should touch are:
>
> - `studio-framework/agents/specc.md` (profile update — S16.2-002)
> - `docs/kb/per-agent-github-apps.md` (new KB doc — S16.2-004)
> - Host-local config: `~/.config/gh/brott-studio-specc-app.pem`, token helper script (e.g. `~/bin/specc-gh-token`) — not committed to a repo
> - The dummy audit PR target file for S16.2-003 validation (pick a low-risk doc file, e.g. a new line in `docs/kb/` or a comment touch)
> - Quarantine/test-runner files under `godot/tests/` ONLY if carry-forward tasks S16.2-005 and/or S16.2-006 land (see below) — `godot/combat/**` diff must remain empty either way.
>
> Any PR with a diff under `godot/combat/**`, `godot/data/**`, `godot/arena/**`, or `docs/gdd.md` is auto-reject during S16.2. Violation disposition: same as S16.1 — PR rejected, refactor into scope.

---

## Goal (condensed from arc plan §S16.2)

Give Specc a distinct GitHub identity (App-based, not shared PAT) so reviewer self-approval and self-merge stop depending on the PAT 422 workaround documented in the S15.1 KB. End state: Specc opens, approves, and merges its own audit PRs as `brott-studio-specc[bot]` with no manual intervention.

In parallel, close out three test-hygiene carry-forwards from the S16.1 process backlog (#138, #140, #141) so the test pipeline keeps converging while the GitHub App work waits on HCD org-admin action.

**Gizmo design drift this sprint:** none. Pure ops/infra. Proceeds without HCD design gate.

---

## Tasks

S16.2 contains **7 tasks**. S16.2-001 through S16.2-004 are the original arc-plan ops scope. S16.2-005 through S16.2-007 are explicit carry-forwards from S16.1 (Process & Infrastructure Carry-Forward table items B, D, E) that Gizmo confirmed for inclusion this sprint.

### [S16.2-001] Create Specc GitHub App + install on org

- **Owner:** Patch (infra) — needs HCD org-admin approval to install
- **🔴 HCD escalation:** App creation + install requires HCD action on the GitHub `brott-studio` org. **Patch is BLOCKED until HCD confirms App creation + install on `battlebrotts-v2` AND `studio-audits`.** Riv surfaces this to The Bott the moment this plan commits.
- **Scope:** create a GitHub App named `brott-studio-specc` (or equivalent). Minimal permissions: `contents:write`, `pull_requests:write`, `issues:write`, `metadata:read`. Install on `brott-studio` org scoped to `battlebrotts-v2` and `studio-audits` repos. Generate private key. Store securely on agent host.
- **Files:** none in repo. Host-local artifact: `~/.config/gh/brott-studio-specc-app.pem` (mode `0600`).
- **Acceptance:** App exists, installed on both repos with the four permissions above, private key on disk at the documented path with `0600` perms.

### [S16.2-002] Wire Specc's spawn/tooling to use the App

- **Owner:** Patch (token helper script) → The Bott (`agents/specc.md` profile update)
- **Depends on:** S16.2-001 (Patch can prep the helper script in dry-run against a personal test App in parallel, but final wiring requires the real installation token endpoint).
- **Scope:**
  - Add a host-local helper script (e.g. `~/bin/specc-gh-token`) that mints a short-lived (~1 hour) installation token from the App private key. Not committed to any repo.
  - Update `studio-framework/agents/specc.md` (profile + inline Core Rules) to: (a) read the App token via the helper for any `gh` / `git` operation that requires Specc identity, (b) fall back to the shared PAT only for read-only metadata queries.
  - Confirm `battlebrotts-v2` `main` branch protection allows the Specc App as a reviewer; adjust if needed (HCD action — same escalation thread as 001).
- **Files:** `studio-framework/agents/specc.md` only (in-repo). Host-local helper script not committed.
- **Design invariant (Gizmo):** profile update must NOT expand Specc's role/authority. Only *how* Specc authenticates. Any creep like "Specc can now also …" = HCD call. Boltz reviewer must diff only the token-handling / identity-binding section; if other sections of `specc.md` change, kick back.
- **Acceptance:** Specc spawned in a dry-run session can `gh pr create --repo brott-studio/battlebrotts-v2 ...` as its own identity (commit author + review reviewer both show `brott-studio-specc[bot]`).

### [S16.2-003] Validate end-to-end on a dummy audit PR

- **Owner:** Specc (dry-run)
- **Depends on:** S16.2-002.
- **Scope:** Specc opens a dry-run mini-audit PR against `battlebrotts-v2`, self-approves, and self-merges. Confirm: no 422, no shared-PAT fallback on the review/merge path.
- **Target file (Gizmo invariant):** `docs/kb/per-agent-github-apps.md` (composes with S16.2-004 — Specc adds a "validation completed" footnote line). NOT `docs/gdd.md`, NOT `godot/data/**`, NOT any balance file. If `per-agent-github-apps.md` doesn't exist yet at validation time (i.e. S16.2-004 hasn't landed first), pick an alternate low-risk doc like an existing `docs/kb/*.md` and add a single comment line — `godot/**` and balance files remain off-limits regardless.
- **Acceptance:** dummy PR merged by `brott-studio-specc[bot]` with no manual intervention and no PAT-reuse 422. Action run URL captured in the S16.2 audit.

### [S16.2-004] Document the setup in `docs/kb/per-agent-github-apps.md`

- **Owner:** Specc (post-validation)
- **Depends on:** S16.2-003 (validation results are part of the doc).
- **Scope:**
  - Write `docs/kb/per-agent-github-apps.md` describing: App creation steps, permissions granted, installation scope, token-helper script location and rotation behavior, branch-protection interactions, and a template section for adding similar Apps for Boltz / Nutts in future sprints.
  - **Also update `studio-framework/SECRETS.md`** to add a line pointing at `~/.config/gh/brott-studio-specc-app.pem` (per Gizmo invariant — the SECRETS index must reflect the new on-disk artifact).
- **Files:** `docs/kb/per-agent-github-apps.md` (new, in `battlebrotts-v2`); `studio-framework/SECRETS.md` (one-line addition, in `studio-framework`).
- **Acceptance:** KB doc committed to `battlebrotts-v2`; SECRETS.md line landed in `studio-framework`; both referenced from the S16.2 audit.

### [S16.2-005] Quarantine-and-enumerate sprints 3/4/5/6 test files

- **Owner:** Nutts
- **Linked issue:** [#138](https://github.com/brott-studio/battlebrotts-v2/issues/138) (S16.1 carry-forward item B)
- **Sequence:** runs **before** S16.2-006 (the registry needs the entries 005 produces).
- **Scope:** triage the failing assertions in pre-sprint-10 test files (`test_sprint3.gd`, `test_sprint4.gd`, `test_sprint5.gd`, `test_sprint6.gd`). For each failing assertion, classify as:
  - **(a) stale-by-design** → retire the assertion with an inline GDD pointer comment naming the canon that supersedes it.
  - **(b) real regression** → quarantine via the S16.1-004 `TestUtil.skip_with_reason` pattern, file or link an issue, do NOT fix.
  - Then add the (now-passing-or-skipped) sprint 3/4/5/6 files to the explicit `SPRINT_TEST_FILES` enumeration in `godot/tests/test_runner.gd` so the runner stops silently ignoring them.
- **Classification budget (Gizmo, S15 learning):** if Nutts can't classify an assertion in <15 min, escalate to Gizmo. Hard cap: **2 Gizmo rulings max** for this task; beyond that, Riv reviews scope and may split the residual to S16.4.
- **Files:** `godot/tests/test_sprint3.gd`, `godot/tests/test_sprint4.gd`, `godot/tests/test_sprint5.gd`, `godot/tests/test_sprint6.gd`, `godot/tests/test_runner.gd`. **`godot/combat/**` diff must be empty.**
- **Acceptance:** sprint 3/4/5/6 test files are enumerated in `SPRINT_TEST_FILES`; full `Godot Unit Tests` job stays green on `main` after the change; every retired assertion has a GDD pointer comment; every quarantined assertion prints a `SKIP:` line per the S16.1-004 format and links a backlog issue.

### [S16.2-006] Machine-readable quarantine registry

- **Owner:** Nutts
- **Linked issue:** [#141](https://github.com/brott-studio/battlebrotts-v2/issues/141) (S16.1 carry-forward item E)
- **Depends on:** S16.2-005 (registry seeds from the quarantine entries 005 produces, plus the existing S16.1-004 entries).
- **Scope:** add `godot/tests/quarantines.json` (or equivalent) containing one entry per currently-quarantined assertion. Schema is intentionally minimal:
  ```json
  { "test_file": "...", "test_name": "...", "skip_reason": "...", "filed_issue": "https://...", "target_sprint": "S17+" }
  ```
  Plus an optional lint hook (~grep-equivalent, ~30 lines max) that fails CI if a `TestUtil.skip_with_reason(...)` call exists in the test sources without a matching registry entry, and vice-versa.
- **Anti-creep guardrail (Gizmo):** keep it dumb. **30-line JSON + grep-equivalent lint.** Do NOT let it grow into a "test metadata system." If lint logic exceeds ~50 lines or starts parsing GDScript ASTs, stop and surface to Riv.
- **Files:** `godot/tests/quarantines.json` (new), optional `godot/tests/quarantine_lint.sh` (or shell snippet inlined in `verify.yml`). **`godot/combat/**` diff must be empty.**
- **Acceptance:** registry file exists and lists every active quarantine (S16.1-004 entries + any added in S16.2-005); lint hook (if implemented) flags drift between source and registry on a synthetic test PR; lint complete in ≤50 lines.

### [S16.2-007] Document `SceneTree.quit()` mid-function semantics in `test_util.gd`

- **Owner:** Nutts
- **Linked issue:** [#140](https://github.com/brott-studio/battlebrotts-v2/issues/140) (S16.1 carry-forward item D)
- **Scope:** add a one-line docstring/comment in `godot/tests/test_util.gd` clarifying that `SceneTree.quit()` called inside `_initialize()` (or any non-final point in a function) only **schedules** quit — trailing code in the same function still runs. Currently safe because all existing test files quit only on their last line; comment is a future-author guard.
- **Fold rule:** if trivial, fold into S16.2-005's PR. Otherwise separate small PR. Either way, it's the smallest task in the sprint.
- **Files:** `godot/tests/test_util.gd` only (1–3 lines).
- **Acceptance:** docstring/comment landed; future test authors will see it before adding a non-final `quit()`.

---

## Review / verify / audit assignments

| Task | Build | Review | Verify | Audit |
|---|---|---|---|---|
| S16.2-001 | Patch | HCD (App install approval) | Patch (App + key on disk verified) | Specc (rolled into S16.2 audit) |
| S16.2-002 | Patch + The Bott (profile) | Boltz (diff-scope-bounded — token/identity section only) | Specc (S16.2-003 IS the verification of wiring) | Specc |
| S16.2-003 | Specc (dry-run) | n/a (validation task) | Specc (self-evident — the merge IS the validation) | Specc |
| S16.2-004 | Specc | Boltz | Optic (KB doc reads cleanly; SECRETS.md line lands in `studio-framework`) | Specc |
| S16.2-005 | Nutts | Boltz | Optic (full Godot Unit Tests green on main post-merge; SKIP lines visible) | Specc |
| S16.2-006 | Nutts | Boltz | Optic (synthetic drift PR trips the lint; clean PR passes) | Specc |
| S16.2-007 | Nutts | Boltz (likely folded into S16.2-005 PR review) | n/a (doc-only) | Specc |

**Sprint audit:** Specc → `studio-audits/audits/battlebrotts-v2/v2-sprint-16.2.md`.

---

## Exit criteria

- [ ] S16.2-001 through S16.2-007 all landed on `main` (or in `studio-framework` for the SECRETS.md / specc.md slices).
- [ ] `brott-studio-specc[bot]` opens, approves, and merges a real audit PR end-to-end with no manual intervention and no PAT 422 fallback (S16.2-003 evidence captured in S16.2 audit).
- [ ] `~/.config/gh/brott-studio-specc-app.pem` exists at `0600` on the agent host; `studio-framework/SECRETS.md` reflects it.
- [ ] `docs/kb/per-agent-github-apps.md` exists, complete, with a template section for future agent Apps.
- [ ] Sprint 3/4/5/6 test files enumerated in `godot/tests/test_runner.gd` `SPRINT_TEST_FILES`; `Godot Unit Tests` job green on `main` post-merge.
- [ ] `godot/tests/quarantines.json` exists and matches every active `TestUtil.skip_with_reason(...)` call in the test sources.
- [ ] `godot/tests/test_util.gd` documents `SceneTree.quit()` mid-function semantics.
- [ ] `godot/combat/**`, `godot/data/**`, `godot/arena/**`, and `docs/gdd.md` diffs across all S16.2 PRs are empty (verify via `git diff origin/main...sprint-16.2-* -- godot/combat/ godot/data/ godot/arena/ docs/gdd.md`).

---

## Sequencing / parallelism

S16.2-001 is **HCD-blocked** (org-admin App install). To avoid burning calendar time on one critical-path blocker:

1. **Patch on S16.2-001:** waits on HCD. While waiting, Patch can prep the `~/bin/specc-gh-token` helper script against a throwaway personal-account test App so the script logic is exercised before the real key arrives. No commits to repos until 001 lands.
2. **Nutts on S16.2-005 → S16.2-006 → S16.2-007:** runs **fully in parallel** with the 001 wait. 005 → 006 is sequential (006 needs 005's quarantine entries); 007 can fold into 005's PR or be a tiny separate PR. None of these touch the GitHub App work.
3. **Once HCD confirms 001:** Patch finishes the real wiring → S16.2-002 (Patch + The Bott) → S16.2-003 (Specc dry-run) → S16.2-004 (Specc KB + SECRETS.md) → audit.

**Recommendation to Riv:** spawn Patch (for 001 prep) AND Nutts (for 005/006/007) immediately after this plan commits, in parallel. The blocker is HCD's calendar, not our agent capacity.

---

## Risks

- **Risk: HCD unavailable to approve org-level App install → S16.2-001 blocks 002/003/004.**
  **Mitigation:** 🔴 escalation goes out the moment this plan commits, so HCD has lead time. If HCD blocks > 1 sprint, the test-hygiene track (005/006/007) still ships independently as the S16.2 deliverable, and the App work splits to S16.4. (This decoupling is explicit per arc-plan §S16.2 risk register.)

- **Risk: App token rotation breaks Specc mid-audit.**
  **Mitigation:** 1-hour token window is longer than any observed Specc audit; helper mints fresh on each spawn. Rotation behavior documented in S16.2-004 KB.

- **Risk: Sprint grew from arc estimate.** Arc plan §S16.2 sized this as "Medium (3–4 tasks, ops-heavy)." With carry-forwards 005/006/007 included, S16.2 is now **7 tasks**. Sized honestly: 001/002/003/004 are small/medium ops tasks (a couple owned by Patch, gated by HCD); 005 is the largest piece (4 test files to triage); 006/007 are small. Total agent-hours land in the same range as S16.1 (which shipped 6 tasks in <70 minutes once unblocked). Surfacing the deviation per arc-plan discipline; Riv recommendation (kept) is to stay parallelized rather than split. If Patch is unblocked quickly AND Nutts hits Gizmo-ruling cap on 005, Riv may spill 006/007 to S16.4.

- **Risk: S16.2-002 profile creep.** Profile updates can quietly expand an agent's role. Mitigation: Boltz reviewer is instructed to diff only the token/identity section; out-of-scope edits to `specc.md` get the PR rejected, not silently merged.

- **Risk: S16.2-006 lint scope creep.** "Quarantine registry" can balloon into a test-metadata framework. Mitigation: hard cap at ~50 lines of lint logic; if it exceeds, surface to Riv. Schema is fixed at five fields.

- **Risk: S16.2-005 classification ambiguity burning Gizmo bandwidth.** S15 burned three Gizmo rulings on a "trivial" fix. Mitigation: 2-ruling hard cap on this task; beyond that, Riv reviews scope.

---

## Open questions / 🟡 surfaced

- **🔴 S16.2-001 HCD blocker:** The Bott to relay to HCD immediately on plan commit. Without it, the entire 001/002/003/004 chain stalls; the 005/006/007 track ships standalone as the S16.2 deliverable.
- **🟡 Branch protection on `battlebrotts-v2` `main`:** S16.2-002 may need the Specc App added as an allowed reviewer. This may be a second HCD action depending on current branch-protection config; surface as a sub-question on the same HCD escalation thread, not a separate one.
- **🟡 Cross-repo PR convention for `studio-framework/SECRETS.md`:** S16.2-004 acceptance requires a one-line edit in `studio-framework`, not `battlebrotts-v2`. The Bott handles the cross-repo PR per existing `agents/specc.md` update precedent; flagged here so it's not forgotten at audit time.

---

## References

- Arc plan: [`sprints/sprint-16.md`](./sprint-16.md) §"S16.2 — Per-agent GitHub App for Specc".
- Prior sub-sprint: [`sprints/sprint-16.1.md`](./sprint-16.1.md) (closed-out section in `sprints/sprint-16.md`).
- S16.1 audit: [`studio-audits/audits/battlebrotts-v2/v2-sprint-16.1.md`](https://github.com/brott-studio/studio-audits/blob/main/audits/battlebrotts-v2/v2-sprint-16.1.md) (Grade A−, exit criteria HOLD).
- S15.1 audit (PAT 422 KB origin): `studio-audits/audits/battlebrotts-v2/v2-sprint-15.1.md`.
- Gizmo design-input for S16.2 (Riv-relayed, 2026-04-20): no design drift, scope-gate paragraph + carry-forward inclusions + design invariants embedded above.
- Linked issues: [#138](https://github.com/brott-studio/battlebrotts-v2/issues/138) (sprint 3/4/5/6 quarantine), [#140](https://github.com/brott-studio/battlebrotts-v2/issues/140) (`SceneTree.quit()` doc), [#141](https://github.com/brott-studio/battlebrotts-v2/issues/141) (quarantine registry).

---

**Plan authored by Ett, 2026-04-20. Next step: Riv surfaces 🔴 S16.2-001 HCD escalation to The Bott, then spawns Patch (001 prep) and Nutts (005/006/007) in parallel.**
