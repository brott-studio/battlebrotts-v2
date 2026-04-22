# Sprint 18.3 — Cold-start validation for BOOTSTRAP_NEW_PROJECT.md

**Status:** Planning
**Arc:** Framework Hardening (S18)
**Sub-sprint:** 3 of 5
**Planned by:** Ett
**Prior audit:** [`studio-audits/audits/battlebrotts-v2/v2-sprint-18.2.md`](https://github.com/brott-studio/studio-audits/blob/main/audits/battlebrotts-v2/v2-sprint-18.2.md) — **A−**

> **Note:** Phase 3 build loop starts in a separate spawn after The Bott merges this plan PR. This document is **planning only**.

---

## DECISION

**continue** — S18.2 audit grade A−, scope-streak clean (9 sub-sprints), `Audit Gate` live on `main`. S18.3's defined scope (cold-start validation of `BOOTSTRAP_NEW_PROJECT.md`) is unbuilt. Gizmo's arc-intent verdict is `progressing` with a Phase-1 mechanism recommendation in-hand (Option C). Arc fuse is 5 sub-sprints; 2 complete, 3 remain, no fuse pressure. Nothing in Step A's decision inputs weights toward `complete`.

**REASON:** Arc-intent = `progressing`; S18.3 is this sub-sprint's named scope; `BOOTSTRAP_NEW_PROJECT.md` has never been exercised end-to-end by anyone other than its author — validation is the whole point.

---

## Audit Verification Gate

**Status:** ✅ PASS.
- Prior audit file present: `audits/battlebrotts-v2/v2-sprint-18.2.md` on `studio-audits/main`.
- Verification SHA: `dd082055643e`.
- Step 0 satisfied. Proceeding to Step A (continue-or-complete), then Step B (plan).

**Note:** this plan PR is the **first real exercise** of the `Audit Gate` check on a non-throwaway PR (per S18.2 audit §7). The prior-audit lookup will hit `v2-sprint-18.2.md` on `studio-audits/main` — which is present. Gate should PASS. If it FAILS, that is a sprint regression and must be surfaced immediately to The Bott before the plan PR is force-merged.

---

## Arc-intent verdict (from Gizmo, this sprint)

**Progressing — on track. No drift. Proceed.** 2 of 5 sub-sprints complete; S18.3 (cold-start validation), S18.4 (branch-protection tightening), S18.5 (simplification passes) remain. Gizmo recommends **Option C (hybrid)**: a static acceptance rubric (`BOOTSTRAP_ACCEPTANCE.md`) combined with **one** live sandbox dry-run against a throwaway `brott-studio/bootstrap-sandbox` repo. All findings from the dry-run are patched into `BOOTSTRAP_NEW_PROJECT.md` / `SECRETS.md` / `REPO_MAP.md` **this sprint**, not deferred.

---

## Scope statement

S18.3 delivers the cold-start validation pass for `studio-framework/BOOTSTRAP_NEW_PROJECT.md` (landed in S18.2 as [S18.2-007]). Three concurrent workstreams:

1. **Rubric** — author `studio-framework/BOOTSTRAP_ACCEPTANCE.md`, a static checklist a cold-start agent can self-score against while walking the 5 bootstrap steps. Pass-bar: every step has a verifiable assertion (file exists, API returns 200, token mints, etc.).
2. **Dry-run** — a cold-start subagent (fresh spawn, no arc context) executes `BOOTSTRAP_NEW_PROJECT.md` end-to-end against a throwaway `brott-studio/bootstrap-sandbox` repo, self-scoring against the rubric as it goes. Every blocking question, ambiguity, or doc gap is captured in a **findings log**.
3. **Patch-back** — every finding is patched **this sprint** into the source docs (`BOOTSTRAP_NEW_PROJECT.md`, `SECRETS.md`, `REPO_MAP.md`, or the rubric itself). Then the sandbox is torn down and the dry-run result is recorded in the sprint close-out residuals.

Neither workstream touches `godot/**` or `docs/gdd.md` — framework arc, hard scope-gate (streak = 9).

---

## Mechanism decision

**Option C (hybrid: rubric + live dry-run + same-sprint patch-back).** One-line rationale: a rubric alone is confirmation bias (the author self-grades the same mental model that wrote the doc); a live dry-run alone has no objective acceptance bar and risks bikeshedding on "is this good enough." Option C forces an adversarial exercise against a concrete bar and closes the loop in-sprint so findings don't rot in a backlog.

**Trade-offs considered:**
- **Option A (rubric-only):** cheaper, reversible, but confirms-the-prior. Rejected.
- **Option B (dry-run-only, no rubric):** catches real gaps but has no completion criterion. Rejected.
- **Option C (hybrid):** one sprint of cost, one sandbox repo to tear down, produces both an asset (the rubric) and evidence (dry-run findings + patches). **Selected.**

**Cold-start agent identity.** The dry-run runs as a fresh Nutts spawn with `lightContext` (no arc-brief injection, no prior-sprint context). Spawn task prompt is capped at: *"You are Nutts. Read `studio-framework/BOOTSTRAP_NEW_PROJECT.md` on `main`. Execute all 5 steps against `brott-studio/bootstrap-sandbox`. Score yourself against `BOOTSTRAP_ACCEPTANCE.md` at each step. Log any blocking question, ambiguity, or gap to the findings file. Do not read any other framework doc unless `BOOTSTRAP_NEW_PROJECT.md` links to it."* This is the closest honest approximation to a cold-start agent inside the current framework.

**Sandbox repo.** `brott-studio/bootstrap-sandbox`, created fresh this sprint, torn down in the same sprint's close-out. Public or private is immaterial — it is throwaway.

---

## Task breakdown

Task IDs `[S18.3-NNN]`. Agents: **Nutts** (build + dry-run execution; infra-only scope), **Specc** (rubric authorship — rubric is an acceptance/audit artifact, natively Specc-shaped), **Boltz** (review + merge), **Optic** (verify). Sub-agent delegation by Nutts is permitted and expected for the dry-run (main Nutts orchestrates; cold-start subagent executes).

### Workstream A — Rubric

**[S18.3-001]** *(Specc — doc)* `new this sprint` Author `studio-framework/BOOTSTRAP_ACCEPTANCE.md`: a 5-section acceptance rubric, one section per bootstrap step in `BOOTSTRAP_NEW_PROJECT.md`.
- **Shape:** each section is a table of assertions. Columns: *assertion* (what must be true), *verification command* (a literal shell or `gh api` call a cold-start agent can run), *expected result* (200, exit 0, exact string match, file exists, etc.), *failure → which doc needs patching* (pointer back to the source doc if the assertion fails).
- **Bar:** every assertion must be **verifiable without subjective judgment**. No "the doc is clear" — instead "the doc contains a literal `gh api` example for step 2 that returns 200." If an assertion can't be made verifiable, it doesn't belong in the rubric.
- **Minimum assertion count per step:** 2. Total ≥ 10 assertions across the 5 steps.
- **Acceptance:** file exists at `studio-framework/BOOTSTRAP_ACCEPTANCE.md`; ≥ 10 verifiable assertions; `BOOTSTRAP_NEW_PROJECT.md` updated to link to the rubric in its opening "Status" section.
- **Size:** M.

### Workstream B — Dry-run execution

**[S18.3-002]** *(Nutts — infra)* `new this sprint` Create the throwaway sandbox repo `brott-studio/bootstrap-sandbox` with an empty initial commit + default-branch `main`. No other setup — this is step 1 of the bootstrap walk, done by the cold-start subagent itself, not by main Nutts.
- **Clarification:** main Nutts creates **only the empty repo shell** (because repo-create requires org admin; the cold-start subagent does not have that). Everything downstream of "repo exists" is the cold-start subagent's job.
- **Admin-PAT carve-out:** repo-creation via org-admin-PAT is a scoped admin action; annotate per S18.2 §11.2 precedent (Option A carve-out; reason = sandbox setup for S18.3 dry-run; no `enforce_admins` or `restrictions` touch). Log in the S18.3 close-out residuals section.
- **Acceptance:** `gh api /repos/brott-studio/bootstrap-sandbox` returns 200; repo is empty except for initial commit on `main`.
- **Size:** XS. **Dependency:** none.

**[S18.3-003]** *(Nutts — test; delegates to cold-start subagent)* `new this sprint` Execute the cold-start dry-run.
- Main Nutts spawns a **fresh subagent** (label: `bootstrap-cold-start`) with `lightContext=true` and the capped task prompt (see Mechanism section above). The subagent reads **only** `BOOTSTRAP_NEW_PROJECT.md` on `main` (plus its cross-references, as the doc itself prescribes) and executes steps 1–5 against `brott-studio/bootstrap-sandbox`. At each step, the subagent self-scores against `BOOTSTRAP_ACCEPTANCE.md` and appends any blocking question, ambiguity, or gap to a findings file at `/home/openclaw/.openclaw/workspace/tmp-s18.3-findings.md`.
- **Step 5 note:** the cold-start agent cannot spawn HCD; for step 5 ("First-arc kickoff"), the subagent writes a *placeholder* `arcs/arc-1.md` into the sandbox (stub, not a real brief) and opens one throwaway planning PR (`sprints/sprint-1.1.md`) to exercise the `Audit Gate` first-sprint-of-arc rule against the new `<project>`. PR closed unmerged; gate outcome recorded in findings.
- **If `Audit Gate` does not fire or fails unexpectedly on the sandbox:** document — **do not fix**. That's S18.4/#229 paper-tiger territory and is a Gizmo guardrail (see Out-of-Scope).
- **Acceptance:** findings file exists with ≥ 1 entry per step (minimum = "step N completed cleanly, no gaps") and any real gaps enumerated; rubric self-score for every assertion recorded (PASS / FAIL / N/A with one-line reason).
- **Size:** L (the subagent does the work; main Nutts orchestrates and collects output). **Dependency:** [S18.3-001] (rubric must exist) + [S18.3-002] (sandbox must exist).

### Workstream C — Patch-back

**[S18.3-004]** *(Nutts — doc)* `new this sprint` For every finding in `tmp-s18.3-findings.md`, author a doc patch **this sprint**. Patches land on `studio-framework/main` as one PR per target file (or one grouped PR if findings are small in aggregate; Nutts decides by volume).
- **Targets in priority order:** `BOOTSTRAP_NEW_PROJECT.md` (most likely target), `SECRETS.md` (for any App-bootstrap gap), `REPO_MAP.md` (for cross-link gaps), `BOOTSTRAP_ACCEPTANCE.md` (if rubric itself was insufficient).
- **Out-of-bounds for this task:** any finding that is not a doc gap — if the dry-run surfaces an infrastructural gap (e.g., `Audit Gate` paper-tiger, missing workflow template), document it as a backlog issue under Workstream D, **do not fix here** (Gizmo guardrails 1 and 2).
- **Acceptance:** every finding in the findings file is either (a) resolved by a merged doc patch PR this sprint, or (b) filed as a backlog issue with the finding text attached and labeled `prio:high`/`mid`/`low` per severity (per Gizmo's "file-don't-fix" rule for out-of-scope items).
- **Size:** M. **Dependency:** [S18.3-003].

**[S18.3-005]** *(Nutts — infra)* `new this sprint` Tear down `brott-studio/bootstrap-sandbox` **after [S18.3-004] is merged**. Archive-then-delete: first archive (reversible), then delete after 24h if no objections surface in the S18.3 close-out review.
- **Admin-PAT carve-out:** same as [S18.3-002] — repo-delete is admin-PAT; Option A annotation; sandbox-teardown reason logged in close-out residuals.
- **Acceptance:** `gh api /repos/brott-studio/bootstrap-sandbox` returns 404.
- **Size:** XS. **Dependency:** [S18.3-004] merged.

### Workstream D — Backlog hygiene on dry-run surfaces

**[S18.3-006]** *(Specc — doc)* `new this sprint` For every out-of-scope finding surfaced by the dry-run (Gizmo guardrails 1, 2, and any infra gaps not patchable in-sprint), file a backlog issue on `brott-studio/battlebrotts-v2` (or `brott-studio/studio-framework` if framework-side) with labels `backlog`, `area:framework`, appropriate priority, and a pointer to the S18.3 findings file line.
- **Acceptance:** every finding in `tmp-s18.3-findings.md` is either patched ([S18.3-004]) or filed as an issue here. Zero findings left uncategorised at sprint close-out.
- **Size:** S. **Dependency:** [S18.3-003] + [S18.3-004] triage pass complete.

---

## Sequencing

```
[S18.3-001 Specc: rubric] ──┐
                            ├──► [S18.3-003 Nutts: dry-run] ──► [S18.3-004 Nutts: patch-back] ──► [S18.3-005 Nutts: teardown]
[S18.3-002 Nutts: sandbox]──┘                                       │
                                                                    └──► [S18.3-006 Specc: file residual issues]
```

Critical path: `[001] → [003] → [004] → [005]`. `[002]` parallel with `[001]`. `[006]` branches off `[003]`+`[004]` triage (can run concurrent with `[005]`).

---

## Sprint-level acceptance criteria

- [ ] [S18.3-001] `studio-framework/BOOTSTRAP_ACCEPTANCE.md` merged on `main` with ≥ 10 verifiable assertions (≥ 2 per bootstrap step).
- [ ] [S18.3-002] `brott-studio/bootstrap-sandbox` exists (empty-main-only).
- [ ] [S18.3-003] Cold-start dry-run executed by fresh Nutts subagent; findings file populated with rubric self-score per assertion and ≥ 1 entry per step.
- [ ] [S18.3-004] **Every dry-run finding is patched or filed this sprint** (per Gizmo's "not deferred" rule). Zero findings in a "to be resolved later" state.
- [ ] [S18.3-005] Sandbox torn down (`gh api /repos/brott-studio/bootstrap-sandbox` → 404) after [S18.3-004] merge + 24h archive window.
- [ ] [S18.3-006] All out-of-scope findings filed as backlog issues with priority labels.
- [ ] Specc audit for S18.3 lands on `studio-audits/main` at `audits/battlebrotts-v2/v2-sprint-18.3.md` before S18.4 planning PR opens (sub-sprint close-out invariant, now structurally enforced by `Audit Gate`).
- [ ] No regressions in existing required checks on `battlebrotts-v2:main`.
- [ ] No diffs under `godot/**` or `docs/gdd.md`.
- [ ] Admin-PAT carve-outs (sandbox create, sandbox delete) logged in close-out residuals with Option A annotation per S18.2 §11.2 precedent.

---

## Out of scope (hard restatement — Gizmo's 4 guardrails)

1. 🚧 **S18.4 creep:** do NOT touch Optic automation ([#229](https://github.com/brott-studio/battlebrotts-v2/issues/229)) or admin-bypass ([#224](https://github.com/brott-studio/battlebrotts-v2/issues/224) / [#225](https://github.com/brott-studio/battlebrotts-v2/issues/225)). If the dry-run hits the `Optic Verified` paper-tiger (required-but-non-functional), **document — do not fix**. That's S18.4 work.
2. 🚧 **S18.5 creep:** no simplification passes. If the dry-run surfaces doc overlap or redundancy (e.g., between `FRAMEWORK.md` and `PIPELINE.md`, between agent profiles and `ESCALATION.md`), **file — do not fix**. That's S18.5 work.
3. 🚧 **Game-code hard line:** zero diffs under `godot/**` or `docs/gdd.md`. Streak = 9 sub-sprints clean; S18.3 is a framework-only sprint. Any drift here is a sprint regression and must be surfaced immediately.
4. 🚧 **Admin-PAT discipline:** sandbox setup admin actions (repo create in [S18.3-002]; repo delete in [S18.3-005]) carry an **Option A carve-out annotation** per S18.2 §11.2 precedent. No silent admin-PAT use; every carve-out is logged in the S18.3 close-out residuals with reason (sandbox setup / teardown for cold-start dry-run) and scope (creates/deletes `bootstrap-sandbox`; does not touch `enforce_admins`, `restrictions`, or bypass lists on any existing repo).

**Additional out-of-scope restatements:**
- **Branch-protection tightening** ([#224](https://github.com/brott-studio/battlebrotts-v2/issues/224), [#225](https://github.com/brott-studio/battlebrotts-v2/issues/225), [#229](https://github.com/brott-studio/battlebrotts-v2/issues/229)) → **S18.4**.
- **Simplification passes 5a–5g** → **S18.5**.
- **Writes to `studio-audits`** — the dry-run does not write to `studio-audits`. Specc writes the S18.3 audit in the normal Phase 6 flow; nothing earlier.

---

## BACKLOG HYGIENE

**Backlog query used:**
- `gh issue list --repo brott-studio/battlebrotts-v2 --state open --label backlog` (44 open as of this plan; run against `api.github.com/repos/brott-studio/battlebrotts-v2/issues?state=open&labels=backlog`).
- `gh issue list --repo brott-studio/studio-framework --state open --label backlog` (0 open).

**Cross-reference against S18.2 audit §7 carry-forwards:**

| Carry-forward item | Target sub-sprint | Filed as issue | Status |
|---|---|---|---|
| Optic automation build-out (Finding 1 from S18.2 audit) | S18.4 | [#229](https://github.com/brott-studio/battlebrotts-v2/issues/229) | ✓ filed (pre-existing; S18.2 sharpened the P0 framing) |
| Admin-bypass closure (`enforce_admins`) | S18.4 | [#224](https://github.com/brott-studio/battlebrotts-v2/issues/224) | ✓ filed |
| Optic-as-sole-merger (`restrictions`) | S18.4 | [#225](https://github.com/brott-studio/battlebrotts-v2/issues/225) | ✓ filed |
| Ordering constraint: Optic automation precedes admin-bypass closure in S18.4 | S18.4 | Not a standalone issue — documented on #224 + this plan | Acceptable (constraint is a sequencing rule, not a deliverable) |
| Net-new from S18.2 execution | S18.3 | "None net-new" per S18.2 audit §7 | N/A |

**Result: clean.** All S18.2 audit §7 carry-forwards targeted at S18.4 are filed as open backlog issues with correct priority and area labels. No gaps. The ordering-constraint note rides along on #224/#229 rather than a separate issue — acceptable because it's a sequencing rule for S18.4's plan, not a build deliverable.

**Non-S18 backlog items reviewed but not pulled into S18.3** (out of arc scope, remain in backlog for future arcs): gameplay/art/audio/UX issues (#94–#117), tech-debt (#118–#122), HCD playtest (#196), S17.x carry-forwards (#193–#195, #208–#210, #201), older dashboard/tests (#123, #124, #137, #139). S18 is a framework arc; these stay put.

---

## S18.4 carry-forward (ordering constraint — carry verbatim)

Per S18.2 audit §7 "To S18.4":

> **Build Optic automation (close [#229](https://github.com/brott-studio/battlebrotts-v2/issues/229)) BEFORE closing admin-bypass ([#224](https://github.com/brott-studio/battlebrotts-v2/issues/224)), or land them atomically. Admin-bypass-first harden-locks the repo.**

Ett must reflect this ordering constraint in the S18.4 sprint plan acceptance criteria (not this plan's — noting here so the next Ett spawn has it on hand). S18.3 does not touch either issue.

---

## Audit-gate expectation for this plan's own PR

This plan PR will be the **first real (non-throwaway) exercise** of the `Audit Gate` check on `battlebrotts-v2:main` (per S18.2 audit §7 "To S18.3" note).

**Expected behavior:**
- Trigger: PR adds `sprints/sprint-18.3.md`.
- Parsed `(N, M) = (18, 3)`; `M >= 2`, so the gate does **not** short-circuit on arc-file presence — it performs the prior-audit lookup.
- Lookup: `GET /repos/brott-studio/studio-audits/contents/audits/battlebrotts-v2/v2-sprint-18.2.md?ref=main` → **200** (verified above, SHA `dd082055643e`).
- Expected result: **`Audit Gate` = success (PASS).**

**If `Audit Gate` FAILS on this PR:** that is a sprint regression on the S18.2 delivery, not an S18.3 planning issue. Surface immediately to The Bott. Do NOT proceed with Phase 3 build until the gate behavior is explained. Distinguish:
- `"audit missing: ..."` summary → real gap (re-check `studio-audits/main`; shouldn't happen given the verification above).
- `"API unreachable: ..."` summary → transient GitHub API outage; manual admin-PAT override (#224 bypass) is justified per the S18.2 CI-check spec, with carve-out annotation.

---

## Sub-sprint shape reminder

S18 arc fuse: **5 sub-sprints.** S18.1 (apps + required check) ✓ · S18.2 (audit-gate CI + self-sufficiency docs) ✓ · **S18.3 (this — cold-start validation)** · S18.4 (branch-protection tightening: Optic automation, then admin-bypass closure — ordering constraint above) · S18.5 (simplification passes 5a–5g). If S18.3 scope expands beyond the in-scope list above (notably if the dry-run tempts a "just fix #229 while we're here" move), **escalate to The Bott before proceeding** — don't silently stretch the sub-sprint. Gizmo guardrails 1 and 2 exist for exactly this failure mode.
