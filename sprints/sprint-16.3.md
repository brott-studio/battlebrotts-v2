# Sprint 16.3 — Main-branch CI Observability (S16 arc close)

**PM:** Ett
**Status:** Planning (iteration 3 of S16 — arc-closing sub-sprint)
**Sprint type:** Sub-sprint (CI/ops, observability only)
**Parent arc:** [`sprints/sprint-16.md`](./sprint-16.md) — see §"S16.3 — Main-branch CI observability"

---

> ## 🛑 SCOPE GATE — READ FIRST
>
> **Scope gate (S16.3).** This sub-sprint is CI observability only. In-scope files: `.github/workflows/verify.yml` (S16.3-001, add `push: main` trigger) and read-only inspection of `godot/project.godot` for the `warnings_as_errors` setting (S16.3-002). If S16.3-002 surfaces a warnings-as-errors regression that requires a code fix (e.g. a re-surfaced `arena_renderer.gd` warning), that fix stays in-scope **only if it is a one-line suppression or existing-warning resolution**; anything larger escalates to Ett and becomes a carry-forward, not a scope expansion. No new tests, no new workflows, no gameplay/sim/UI changes. If you find yourself editing any `.gd` file outside of a one-line warning fix, stop and escalate.

---

## Goal (condensed from arc plan §S16.3)

Make main-branch CI health visible in real time. Today `verify.yml` only runs on `pull_request`, so a merge-queue race or post-merge regression is invisible until the next PR opens. S16.3 adds a `push: main` trigger so every merge commit produces a Verify run in the Actions tab, and then confirms the warnings-as-errors contract is consistent between local Godot and CI Godot so the new signal is trustworthy.

S16.3 is the **arc-closing** sub-sprint: landing it satisfies the third HCD acceptance criterion for the S16 arc (`Verify` ✅ on `push: main`, alongside the S16.1 suite-green and S16.2 Specc-App criteria).

**Gizmo design drift this sprint:** none. Pure CI/ops.

---

## Tasks

S16.3 contains **3 tasks**. Task IDs are from arc plan §S16.3; use verbatim in branches, PRs, and commits.

### [S16.3-001] Add `push: main` trigger to `verify.yml`

- **Owner:** Patch
- **Scope:**
  - Add a `push:` trigger to `.github/workflows/verify.yml` alongside the existing `pull_request:` trigger, scoped to `branches: [main]`.
  - **No `paths-ignore`.** The PR trigger deliberately does not use `paths-ignore` (inline comment in the current file explains why: required-status-checks would deadlock doc-only auto-merge PRs, so doc filtering happens at runtime via the `changes` job short-circuit). Mirror that pattern on the push trigger for symmetry — a single source of truth on "what counts as doc-only." This overrides the arc-plan §S16.3-001 wording that prescribed `paths-ignore: [docs/**, sprints/**, '**/*.md']`; that wording predates the S15/S16.1 required-status-checks lesson.
  - Add an inline YAML comment explaining *why* no `paths-ignore` on the push trigger, so the next agent reading this file doesn't re-propose `paths-ignore`. Reference the existing comment on the PR trigger.
  - **`changes` job compatibility:** the existing `changes` job reads `github.event.pull_request.base.sha` / `.head.sha`, which are unset on a `push` event. The short-circuit detector must work for both event types. Two acceptable implementations — Patch picks whichever is cleaner:
    - (a) Parameterize the diff range: on `push`, diff `${{ github.event.before }}..${{ github.sha }}`; on `pull_request`, keep the current `base.sha..head.sha`. Same glob rules for doc-only classification.
    - (b) On `push` events, just force `code=true` (always run the suite on main merges). Simpler, slightly more CI cost on doc-only merges to main — acceptable since doc-only merges to main are rare relative to PRs.
  - **Recommendation to Patch:** start with (a) for symmetry. If `github.event.before` is unreliable for the first commit after trigger activation (e.g. returns a zero SHA), fall back to (b) and note it in the PR.
- **Files:** `.github/workflows/verify.yml` only.
- **Acceptance:**
  - After S16.3-001 merges to main, a `Verify` run appears in the Actions tab for the merge commit itself (not just for PRs).
  - Doc-only merges to main still short-circuit to ✅ without invoking Godot (whichever implementation Patch picks, the observable end state is the same).
  - The new inline comment explains the no-`paths-ignore` decision.
- **Notes:** Branch `sprint-16.3-push-main-trigger`. PR title `[S16.3-001] Add push: main trigger to verify.yml`.

### [S16.3-002] Confirm warnings-as-errors consistency local vs CI

- **Owner:** Nutts
- **Scope:** **Read-only diff/confirm.** Check that the `warnings_as_errors` setting (and any related `debug/gdscript/warnings/*` flags) in `godot/project.godot` is applied identically by local Godot 4.4.1 headless and by the CI Godot 4.4.1 headless in `verify.yml`'s `Run Godot tests` step.
  - Enumerate the current `debug/gdscript/warnings/*` settings in `project.godot` (or confirm they are defaulted).
  - Run `godot --headless --path godot/ --script res://tests/test_runner.gd` locally and capture any warning output.
  - Compare against the most recent green CI run's log for the same step.
  - If they match: pass. Document the settings in the PR body for the record and close the task.
  - If they disagree: **do not silently edit `project.godot` to align.** Surface the divergence in the PR body as a finding. If the disagreement would cause CI to fail on the first `push: main` run, that's a 🟡 — escalate to Ett. The arc plan §S16.3-002 explicitly says "no new warnings-as-errors policy"; this task confirms the existing policy is applied uniformly, nothing more.
  - **One-line-fix carve-out:** if the `arena_renderer.gd` warning fixed in S16.1-006 has re-surfaced and the fix is a single-line suppression or resolution identical to what landed in S16.1-006, Nutts may re-apply it in the same PR. Any larger fix becomes a carry-forward.
- **Files:** Expected: none (read-only confirm). Allowed if strictly necessary: a one-line warning suppression in a single `.gd` file per the carve-out above. **`godot/combat/**`, `godot/data/**`, `godot/arena/**` (beyond the one-line carve-out) diffs must be empty.**
- **Acceptance:**
  - PR body contains the local-vs-CI warning comparison (either "matches" with evidence, or a documented finding).
  - If a one-line warning fix was applied, it's identical in shape to S16.1-006 and explicitly called out in the PR body.
  - `Godot Unit Tests` CI job passes on the PR and (via S16.3-003) on the subsequent `push: main` run.
- **Notes:** Branch `sprint-16.3-warnings-consistency`. PR title `[S16.3-002] Confirm warnings-as-errors consistency local vs CI`. If the task resolves as pure confirmation with no diff, still open a tiny doc-PR (e.g. a note in the PR description linked from the audit) rather than reporting verbally — this sub-sprint needs a paper trail for the arc close.

### [S16.3-003] End-to-end validation — two green runs, arc-acceptance moment

- **Owner:** Optic
- **Depends on:** S16.3-001 merged; S16.3-002 completed (or documented as no-op).
- **Scope:** after S16.3-001 lands on main, observe the next `push: main` Verify run produced by the trigger and a fresh PR's `pull_request` Verify run. Confirm both ✅. Author the standard Optic verification doc.
- **Arc-acceptance framing:** the verification doc must **explicitly call the arc-acceptance moment.** This is not just "S16.3 done" — it is "S16 arc complete, all three HCD acceptance criteria met," specifically:
  1. `Godot Unit Tests` passes cleanly on `main` (push: main) AND on a dummy code-path PR — both ✅. ← confirmed by this task's two green runs.
  2. `test_runner.gd` enumerates all sprint test files explicitly — no reliance on shell glob `|| exit 1`. ← already satisfied by S16.1-005 + S16.2-005 enumeration; Optic re-confirms the enumeration is intact in the runs observed here.
  3. At least one agent (Specc) has a per-agent GitHub App or equivalent distinct identity wired into the review/merge path. ← already satisfied by S16.2; Optic references the S16.2 audit for the evidence trail, doesn't re-verify mechanically.
- **Files:** verification doc only (per Optic convention — not in this repo; follows the standard Optic output path).
- **Acceptance:**
  - Two green `Verify` runs observed and linked from the verification doc: one `push: main` (the S16.3-001 merge commit or the next merge after), one `pull_request` (any fresh code-path PR — can be the S16.3-002 PR itself if still open, or a synthetic no-op PR).
  - Verification doc explicitly states "S16 arc complete — all three HCD acceptance criteria met" with per-criterion pointers.
- **Notes:** no repo branch/PR from Optic; this is an observation + writeup task. Optic's output triggers the Specc arc-complete audit.

---

## Review / verify / audit assignments

| Task | Build | Review | Verify | Audit |
|---|---|---|---|---|
| S16.3-001 | Patch | Boltz | Optic (rolled into S16.3-003) | Specc (sub-sprint + arc-complete audit) |
| S16.3-002 | Nutts | Boltz | Optic (rolled into S16.3-003) | Specc |
| S16.3-003 | Optic | n/a (verification task) | Optic (self-evident) | Specc |

**Sprint audit:** Specc → `studio-audits/audits/battlebrotts-v2/v2-sprint-16.3.md` **and** an arc-complete retrospective covering S16.1 + S16.2 + S16.3 as a unit (see Arc-close notes below).

---

## Exit criteria

- [ ] S16.3-001, S16.3-002, S16.3-003 all landed (001/002 as PRs to `main`; 003 as a verification doc).
- [ ] `push: main` trigger present in `.github/workflows/verify.yml` with inline comment explaining the no-`paths-ignore` decision.
- [ ] Warnings-as-errors settings confirmed consistent between local Godot 4.4.1 headless and CI Godot 4.4.1 headless, evidence in S16.3-002 PR body.
- [ ] Two green `Verify` runs observed post-S16.3-001 merge: one `push: main`, one `pull_request` — both ✅, both linked from the S16.3-003 verification doc.
- [ ] **Arc-acceptance moment recorded in S16.3-003 verification doc:** "S16 arc complete — all three HCD acceptance criteria met" with per-criterion pointers.
- [ ] `godot/combat/**`, `godot/data/**`, `godot/arena/**` diffs across all S16.3 PRs are empty **except** for the S16.3-002 one-line warning-fix carve-out, if exercised.

---

## Risks

- **Risk: `paths-ignore` drift re-proposal.** Agents reading the arc plan will see `paths-ignore: [docs/**, sprints/**, '**/*.md']` and may re-propose it on the push trigger.
  **Mitigation:** S16.3-001 scope explicitly overrides the arc-plan wording and bakes the rationale (required-status-checks deadlock, doc filtering happens at runtime in the `changes` job) into an inline YAML comment on the push trigger. Boltz reviewer: if the PR reintroduces `paths-ignore`, kick it back.

- **Risk: `changes` job compatibility on push events.** The current `changes` job uses `github.event.pull_request.base.sha` and `.head.sha`, which are unset on `push`. If Patch doesn't adapt it, the doc-short-circuit breaks on main merges.
  **Mitigation:** S16.3-001 scope enumerates two acceptable implementations (parameterized diff range vs. always-run on push) and names a default (parameterized, fall back to always-run if `github.event.before` is unreliable). Boltz reviewer: confirm whichever implementation is used actually handles both event types.

- **Risk: first-red heads-up.** 🟢 Once S16.3-001 lands, main's health is visible in real time. If main happens to be red at the moment the trigger first activates — or if it goes red later from a merge-queue race — everyone sees it immediately. That's the feature, not a bug.
  **Mitigation:** Ett/Riv will give HCD a 1-line heads-up via The Bott when S16.3-001 merges, so the first red run (whenever it eventually occurs) isn't a surprise. Currently main should be green post-S16.1/S16.2, so this heads-up is a one-time pre-announcement, not an incident report.

- **Risk: S16.3-002 read-only constraint burns iteration if warnings genuinely diverge.** If local vs CI warning output disagrees in a non-trivial way, the one-line carve-out won't cover it and the task becomes a surfaced finding rather than a fix.
  **Mitigation:** explicitly fine. Arc plan says no new warnings policy; the right move is to document the finding and carry it forward, not to force a fix inside a tiny arc-closing sub-sprint.

- **Risk: `push: main` spam on doc-only merges.** If Patch picks implementation (b) (always-run on push), every doc-only merge to main spins up Godot.
  **Mitigation:** doc-only merges to main are rare (most docs flow through PRs that already get the short-circuit treatment). If this starts costing material CI minutes, file a carry-forward. Implementation (a) is the preferred path precisely to avoid this.

---

## Open questions / 🟡 surfaced

- **🟡 `paths-ignore` arc-plan vs current reality (resolved in this plan, flagged for posterity):** arc plan §S16.3-001 prescribed `paths-ignore: [docs/**, sprints/**, '**/*.md']`, but current `verify.yml` deliberately removed `paths-ignore` from the PR trigger due to a required-status-checks deadlock on doc-only auto-merge PRs. S16.3-001 mirrors the current pattern (no `paths-ignore`, runtime short-circuit) for symmetry. Rationale baked into the YAML inline comment and into this plan's scope.

- **🟢 Carry-forward integration (informational):** neither [#137](https://github.com/brott-studio/battlebrotts-v2/issues/137) (Scout approach-tick canary — S17 gameplay) nor [#139](https://github.com/brott-studio/battlebrotts-v2/issues/139) (ObjectDB / resource leaks — tech-debt backlog) folds into S16.3. Confirmed: S16.3 is CI observability only; both issues stay in their target backlogs (#137 → S17 gameplay, #139 → tech-debt backlog).

---

## Arc-close notes

S16.3 is the **arc-closing** sub-sprint for the S16 arc (Tech Debt Cleanup + Infrastructure Health). After S16.3-003 lands, Riv/Specc produce the arc-complete retrospective. Two items must be explicitly carried into that retrospective:

1. **Pipeline audit-gate framework-patch recommendation.** Specc's S16.1 audit (§7) and S16.2 audit (§7, §8.2) have now flagged the same framework-level gap two sprints running: `PIPELINE.md` should require `audits/<project>/v2-sprint-<N.M>.md` to exist on `studio-audits/main` before a sub-sprint is considered closed. S16.1 itself shipped without its audit at the time (the retroactive audit was only written at arc resumption); the gate would have caught that miss. **At arc complete, Riv includes the pipeline-gate framework-patch recommendation (from `v2-sprint-16.1.md` §7 and `v2-sprint-16.2.md` process flags) in the arc-complete report.** This is a framework-level change, not a S16.3 task — S16.3 just keeps the pointer alive so it doesn't get lost in the arc-close handoff.

2. **Arc-acceptance evidence bundle.** The arc-complete retrospective needs to link all three HCD acceptance criteria to concrete evidence:
   - Criterion 1 (Verify ✅ on push: main AND on dummy code-path PR): S16.3-003 verification doc + linked run URLs.
   - Criterion 2 (`test_runner.gd` explicit enumeration): S16.1-005 merge SHA `36e64f8` + S16.2-005 enumeration extensions.
   - Criterion 3 (Specc per-agent GitHub App): S16.2 audit + `docs/kb/per-agent-github-apps.md`.

---

## References

- Arc plan: [`sprints/sprint-16.md`](./sprint-16.md) §"S16.3 — Main-branch CI observability" and §"Acceptance for the S16 arc as a whole".
- Prior sub-sprints:
  - S16.1 close-out: in-line in [`sprints/sprint-16.md`](./sprint-16.md) §"S16.1 Close-Out (sealed 2026-04-17)".
  - S16.2 plan: [`sprints/sprint-16.2.md`](./sprint-16.2.md).
- Audits (for arc-close retrospective context):
  - `studio-audits/audits/battlebrotts-v2/v2-sprint-16.1.md` (Grade A−; framework-patch recommendation §7).
  - `studio-audits/audits/battlebrotts-v2/v2-sprint-16.2.md` (Grade A; framework-patch recommendation §7/§8.2).
- CI config snapshot: `.github/workflows/verify.yml` (pre-S16.3 state — `pull_request` only, runtime `changes` short-circuit for doc-only PRs).
- Carry-forward issues (not in S16.3 scope, noted for posterity): [#137](https://github.com/brott-studio/battlebrotts-v2/issues/137) (S17+), [#139](https://github.com/brott-studio/battlebrotts-v2/issues/139) (tech-debt backlog).

---

**Plan authored by Ett, 2026-04-20. Next step: Riv spawns Patch on S16.3-001 and Nutts on S16.3-002 in parallel; Optic picks up S16.3-003 after 001 merges.**
