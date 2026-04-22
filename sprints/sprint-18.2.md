# Sprint 18.2 — Self-Sufficiency Remainder + O1 Audit-Gate CI Check

**Status:** Planning
**Arc:** Framework Hardening (S18)
**Sub-sprint:** 2 of 5
**Planned by:** Ett
**Arc docket:** [PR #173](https://github.com/brott-studio/battlebrotts-v2/pull/173)
**Prior audit:** [`studio-audits/audits/battlebrotts-v2/v2-sprint-18.1.md`](https://github.com/brott-studio/studio-audits/blob/main/audits/battlebrotts-v2/v2-sprint-18.1.md) — **A−**

> **Note:** Phase 3 build loop starts in a separate spawn after Bott merges this plan PR. This document is **planning only**.

---

## Arc-intent verdict (from Gizmo, this sprint)

**Progressing — on track. No drift. Proceed.** S18.1 landed the first P0 brick (per-agent Apps + `Optic Verified` required check). 4 of 5 sub-sprints remain. S18.2 delivers the self-sufficiency remainder (P0) and the structural CI gate that closes the planning-PR audit-gate breach surface (`#226`).

---

## Scope statement

S18.2 delivers two concurrent workstreams:

1. **O1 Option B** — a dedicated CI workflow on `battlebrotts-v2` that fails a planning PR touching `sprints/sprint-*.md` when the prior sub-sprint's Specc audit is absent from `studio-audits/main`. Closes `#226`. Completes the structural closure of the sub-sprint close-out invariant (previously compliance-reliant).
2. **Self-sufficiency docs** on `studio-framework` — `BOOTSTRAP_NEW_PROJECT.md`, a per-agent-GitHub-App bootstrap section in `SECRETS.md`, and an `ESCALATION.md` cross-reference audit across all 9 agent profiles (8 canonical + Patch).

Neither workstream touches `godot/**` or `docs/gdd.md` — framework arc, hard scope-gate.

---

## Task breakdown

Task IDs `[S18.2-NNN]`. Agents: **Nutts** (build; infra-only scope tag on all non-game work per arc docket §5a — fold itself is S18.5, but infra-only Nutts is how we run now). **Boltz** reviews + merges. **Optic** verifies. Sub-agent delegation by Nutts is permitted and expected for parallel doc-sweep work (Nutts → doc-sub-agent for the ESCALATION audit while main Nutts drives the CI-check workstream).

### Workstream A — O1 audit-gate CI check

**[S18.2-001]** *(Nutts — infra)* `[#226]` Install the `brott-studio-boltz` GitHub App on `brott-studio/studio-audits` with `Contents: Read-only` permission. Record the new `studio-audits`-scoped installation ID. This is the cross-repo credential for the audit-presence lookup. (HCD-facing sub-step if GitHub org UI is needed — Nutts attempts via API first; falls back to HCD install request only if permissions insufficient.)
- **Why Boltz App, not Specc or new `studio-ci`:** Specc writes audits — gating on Specc's own absence is a circular identity. Optic is narrowly scoped to check-runs. Boltz already holds `Contents` on project repos and is the reviewer/merger identity; adding one more installation to an existing App keeps inventory at 3. Justification: one line in workflow header comment.
- **Acceptance:** `gh api /repos/brott-studio/studio-audits/installation` returns `app_id: 3459519` (Boltz). SECRETS.md inventory entry updated with the new installation ID.
- **Size:** S.

**[S18.2-002]** *(Nutts — infra)* `[#226]` Add Actions secrets to `battlebrotts-v2` for the Boltz App: `BOLTZ_APP_ID` (3459519) and `BOLTZ_APP_PRIVATE_KEY` (PEM contents). Secrets scope = repo-level (not env-level). Reuse Boltz PEM on the workspace host; copy contents into the Actions secret exactly once. Do NOT commit the PEM. Do NOT echo the PEM in any log statement. **Acceptance:** both secrets exist per `gh secret list --repo brott-studio/battlebrotts-v2 | grep BOLTZ_APP`; workflow can reference `${{ secrets.BOLTZ_APP_ID }}`. **Size:** S.

**[S18.2-003]** *(Nutts — infra)* `[#226]` Create new dedicated workflow file at `.github/workflows/audit-gate.yml` on `battlebrotts-v2`. Job name: `audit-gate`. Check-run name that will appear in branch-protection required-status-checks: **`Audit Gate`** (title-case, matches existing required-check naming convention: `Godot Unit Tests`, `Playwright Smoke Tests`, `Optic Verified`).
- **Decision: new dedicated workflow, not extension of `verify.yml`'s "Detect changed paths" job.** Justification (one line): the audit-gate fires on planning PRs that deliberately touch only `sprints/**` and must *not* depend on Godot/Playwright infra — coupling to `verify.yml` would inherit unrelated failure modes and muddy the required-check surface.
- **Trigger:** `pull_request` events of type `[opened, synchronize, reopened]` with `paths: ['sprints/sprint-*.md']`.
- **Logic (match Gizmo's O1 design anchors 1–5 verbatim):**
  1. Parse `(N, M)` from the added/modified filename `sprints/sprint-<N>.<M>.md` inside the check (sprint-*.md paths that don't match the `<N>.<M>` shape → pass-through with `neutral` conclusion and an explanatory `output.summary`).
  2. Mint installation token via Boltz App (`BOLTZ_APP_ID` + `BOLTZ_APP_PRIVATE_KEY`) scoped to `studio-audits`.
  3. **First-sprint-of-arc rule:** if `M == 1`, require the PR tree contains `arcs/arc-<N>.md`; if present → PASS and SKIP the prior-audit lookup. If missing → FAIL with summary: "first sprint of an arc must introduce arcs/arc-<N>.md".
  4. **Prior-audit lookup (M ≥ 2):** `GET /repos/brott-studio/studio-audits/contents/audits/battlebrotts-v2/v2-sprint-<N>.<M-1>.md` on `ref=main`. **Immediately-preceding** sub-sprint (not highest ≤ N.M). If 200 → PASS. If 404 → FAIL with summary: `"audit missing: audits/battlebrotts-v2/v2-sprint-<N>.<M-1>.md not on studio-audits/main"`.
  5. **Fail-closed on GitHub API outage** with 3 retries (10s → 30s → 60s backoff). On final failure → FAIL with summary prefixed `"API unreachable:"` so admins can distinguish "audit missing" (real gap, real fix) from "API unreachable" (transient, manual admin-PAT override via #224 bypass list is justified).
  6. `current_closed_sprint` discovery is file-based lexicographic tuple-sort `(N, M)` on `audits/battlebrotts-v2/v2-sprint-<N>.<M>.md` — **no new manifest file.**
- **Out-of-scope within this workflow:** closed-sprint liveness beyond the immediate predecessor; cross-arc gap detection; any write to `studio-audits`. Read-only.
- **Acceptance:** `audit-gate.yml` exists on `main`; workflow appears in the Actions tab; `Audit Gate` check name visible on a mock PR.
- **Size:** M.

**[S18.2-004]** *(Nutts — infra, branch-protection)* `[#226]` After [S18.2-003] merges AND at least one real PR has successfully produced an `Audit Gate` check-run, add `Audit Gate` to required status checks on `battlebrotts-v2:main` via the branch-protection API. Do NOT modify `enforce_admins`, `restrictions`, or bypass lists — that's S18.4 scope. **Acceptance:** `gh api /repos/brott-studio/battlebrotts-v2/branches/main/protection` shows `Audit Gate` in `required_status_checks.contexts`. **Size:** S. **Dependency:** [S18.2-003] merged + one real check-run recorded (same don't-gate-on-a-check-nobody-posts rule as S18.1-008).

**[S18.2-005]** *(Nutts — test)* `[#226]` End-to-end validation via two throwaway PRs:
- **AG-1 (missing-audit FAIL):** open a throwaway PR adding `sprints/sprint-99.2.md` (arbitrary non-existent sub-sprint). Expect `Audit Gate` = FAIL with `output.summary` containing `"audit missing"`. Close unmerged. Captures the negative path.
- **AG-2 (arc-first PASS):** open a throwaway PR adding `sprints/sprint-99.1.md` + `arcs/arc-99.md`. Expect `Audit Gate` = PASS per first-sprint-of-arc rule. Close unmerged.
- **Size:** S. **Dependency:** [S18.2-003].

**[S18.2-006]** *(Nutts — doc)* `[#226]` Update `studio-framework/PIPELINE.md` §"Sub-sprint close-out invariant": annotate the close-out-invariant bullet with `[Structural — enforced by audit-presence CI check]` (replacing or complementing the existing `[Compliance-reliant]` language as appropriate). Bundle into the same PR as [S18.2-003] if feasible (keeps docs in sync with code) or file as follow-up PR. **Acceptance:** one edit to `PIPELINE.md` on `studio-framework/main`. **Size:** S.

### Workstream B — Self-sufficiency docs

**[S18.2-007]** *(Nutts — doc)* `new this sprint` Create `studio-framework/BOOTSTRAP_NEW_PROJECT.md` at framework root. Exactly 5 ordered steps (per Gizmo's shape anchors):
1. Create the project repo — minimum file skeleton: `sprints/`, `arcs/`, `docs/gdd.md`, `.github/workflows/`.
2. Provision per-agent GitHub Apps (install Optic/Boltz/Specc on the new repo; write private keys; confirm installation). Link to `SECRETS.md §"Per-Agent GitHub App Bootstrap"` ([S18.2-008]).
3. Wire secrets + CI gates — required status checks, branch-protection skeleton matching `battlebrotts-v2`; point `Audit Gate` at `studio-audits:audits/<project>/`.
4. Point framework at the new project — update `REPO_MAP.md`; create `audits/<project>/` in `studio-audits` with README; confirm project-name variable usage (no hardcoded `battlebrotts-v2`).
5. First-arc kickoff — HCD writes `arcs/arc-1.md`; The Bott spawns Riv; first sprint runs with audit-gate SKIPPED per the arc-first-sprint rule ([S18.2-003] anchor 3).
- **Acceptance note (framing only, no test this sprint):** "A cold-start agent can run this without blocking questions" — this is the target S18.3 will validate. Do NOT implement validation here.
- **Size:** M.

**[S18.2-008]** *(Nutts — doc)* `new this sprint` Add a new section to `studio-framework/SECRETS.md` titled `## Per-Agent GitHub App Bootstrap` (not a standalone file — Gizmo's explicit shape anchor). Subsections:
- *Create the App* (org-level, webhook disabled, minimum permissions table per role)
- *Install on the target repo* (`gh api` or web-UI path)
- *Write the private key* to `~/.config/gh/brott-studio-<agent>-app.pem`, mode `0600`
- *Verify via token mint* (run `~/bin/<agent>-gh-token` → expect 40-char output, exit 0)
- **Worked example:** existing Specc App (App ID 3459479's neighbor — Specc's real App ID from SECRETS.md §"🔐 Specc GitHub App Private Key"). **Canonical peers:** Optic (App ID 3459479) and Boltz (App ID 3459519) — reference both as additional canonical examples.
- **Acceptance:** section exists in `SECRETS.md` on `studio-framework/main`; `BOOTSTRAP_NEW_PROJECT.md` step 2 links to it.
- **Size:** S.

**[S18.2-009]** *(Nutts — doc, delegated to doc-sub-agent)* `new this sprint` ESCALATION cross-reference audit across all 9 agent profiles in `studio-framework/agents/`: `the-bott.md`, `riv.md`, `ett.md`, `gizmo.md`, `nutts.md`, `boltz.md`, `optic.md`, `specc.md`, `patch.md`.
- **Bar (Gizmo's anchor):** "link, not mirror." Each profile must have **exactly one** link to `../ESCALATION.md` near the top of Core Rules, plus any agent-specific escalation nuance below. No rule-duplication.
- **Per-profile pass:**
  1. Confirm one link exists in Core Rules.
  2. If multiple exist, consolidate to one at top; leave inline links only where they disambiguate a specific 🔴/🚨 call-out (not boilerplate).
  3. Remove any prose that duplicates ESCALATION.md tiers (🟢🟡🔴🚨) — replace with the single link.
- **Current state (from local inspection): `boltz.md` and `nutts.md` have 2 refs each; `ett.md` has 3; `the-bott.md` has 2. These are the primary audit targets.** Other profiles already at 1 ref.
- **Patch decision (mine):** **audit Patch too.** Rationale: cheap, keeps the doc clean in the meantime, and the fold into Nutts in S18.5 (§5a) is still a sprint away. Flag in the PR body: "Patch audited per S18.2; will be folded into Nutts in S18.5." Defers no work, creates no rework.
- **Acceptance:** `grep -c "ESCALATION.md"` on each of the 9 profiles returns exactly 1, unless the audit pass found a justified exception (documented in the PR body).
- **Size:** M.

---

## CI-check task specifics (consolidated, O1)

| Decision | Choice | One-line rationale |
|---|---|---|
| Workflow shape | **New dedicated** `.github/workflows/audit-gate.yml` | Planning PRs must not inherit Godot/Playwright failure modes from `verify.yml`. |
| Check-name (branch-protection) | **`Audit Gate`** | Matches existing title-case convention (`Godot Unit Tests`, `Optic Verified`). |
| Cross-repo credential | **Boltz App — install on `studio-audits` with `Contents: Read-only`** | Specc can't gate its own absence (circular); Optic is narrowly scoped to check-runs; Boltz already holds `Contents` on project repos → keeps App inventory at 3, zero new Apps. |
| `current_closed_sprint` discovery | **File-based lexicographic tuple-sort on `studio-audits/main`** | No new manifest file — zero drift surface. |
| Failure mode on GH outage | **Fail-closed, 3 retries (10s/30s/60s)** | Error summary distinguishes `"audit missing"` from `"API unreachable:"` so admins know when manual admin-PAT override (#224) is justified. |
| Workflow file path | `.github/workflows/audit-gate.yml` | — |
| Branch-protection context string | `Audit Gate` | Added in [S18.2-004], not [S18.2-003]. |

---

## BACKLOG HYGIENE

**Backlog query used:**
- `gh issue list --repo brott-studio/battlebrotts-v2 --state open --label backlog` (44 open)
- `gh issue list --repo brott-studio/studio-framework --state open --label backlog` (0 open)

**Cross-reference against S18.1 audit §4 carry-forwards:**

| Carry-forward item | Target sub-sprint | Filed as issue | Status |
|---|---|---|---|
| Admin-PAT bypass (enforce_admins not set) | S18.4 | [#224](https://github.com/brott-studio/battlebrotts-v2/issues/224) | ✓ filed |
| Optic-as-sole-merger (restrictions null) | S18.4 | [#225](https://github.com/brott-studio/battlebrotts-v2/issues/225) | ✓ filed |
| Planning-PR audit-gate CI check (O1 Option B) | **S18.2 (this sprint)** | [#226](https://github.com/brott-studio/battlebrotts-v2/issues/226) | ✓ filed, executed this sprint |

**Result: clean.** All S18.1 carry-forwards are filed as backlog issues with correct priority and area labels. No gaps.

**Non-S18 backlog items reviewed but not pulled into S18.2** (out of arc scope, remain in backlog for future arcs): gameplay/art/audio/UX issues (#94–#117), tech-debt (#118–#122), HCD playtest (#196), S17.x carry-forwards (#193–#195, #208–#210, #201), older dashboard/tests (#123, #124, #137, #139). S18 is a framework arc; these stay put.

---

## Out of scope (hard restatement)

- **Cold-start validation protocol** → S18.3
- **Branch-protection tightening** ([#224](https://github.com/brott-studio/battlebrotts-v2/issues/224) admin-PAT bypass, [#225](https://github.com/brott-studio/battlebrotts-v2/issues/225) Optic-restrictions) → S18.4
- **Simplification passes 5a–5g** (Patch fold into Nutts, FRAMEWORK/PIPELINE collapse, `ORCHESTRATION_PATTERNS.md` delete, light profile audit, tool-allowlist tracking) → S18.5
- **Any `godot/**` or `docs/gdd.md` changes** — framework arc, hard scope-gate.
- **Writes to `studio-audits`** — the Boltz App installation on `studio-audits` is `Contents: Read-only`; the CI check does not write.

---

## Context carry-forwards from S18.1

- **`enforce_admins` stays `false` this sprint** (S18.4 scope). Plan tasks must not attempt to flip it.
- **Doc-only close-out merges may use admin-PAT bypass for `Optic Verified`** — documented gap until S18.4. **Call-out for S18.2:** [S18.2-006] (the `PIPELINE.md` `[Structural]` annotation) and any sprint-plan close-out amendment PR on this sprint are docs-only and may require admin-PAT merge. Expected; not a sprint regression. Log in the eventual S18.2 close-out residuals section the same way S18.1 did.
- **O1 Option B is this sprint's work.** After [S18.2-004] lands, the *next* sprint (S18.3 and later) will have the audit-gate CI check as a required status check — planning PRs from S18.3 onward must satisfy `Audit Gate` before merge. S18.2's own plan PR (this file) is submitted **before** [S18.2-004] wires the required check, so it is not subject to the gate.

---

## Exit criteria (acceptance / done-definition for S18.2 as a whole)

- [ ] [S18.2-001] Boltz App installed on `studio-audits` (`Contents: Read-only`); SECRETS.md inventory updated.
- [ ] [S18.2-002] `BOLTZ_APP_ID` + `BOLTZ_APP_PRIVATE_KEY` Actions secrets present on `battlebrotts-v2`.
- [ ] [S18.2-003] `audit-gate.yml` merged to `battlebrotts-v2/main`; `Audit Gate` check-run visible in Actions.
- [ ] [S18.2-004] `Audit Gate` added to required status checks on `main` (post-real-check-run, not before).
- [ ] [S18.2-005] AG-1 (FAIL, missing-audit) and AG-2 (PASS, arc-first) throwaway PRs recorded as evidence in the S18.2 close-out residuals.
- [ ] [S18.2-006] `studio-framework/PIPELINE.md` close-out invariant annotated `[Structural — enforced by audit-presence CI check]`.
- [ ] [S18.2-007] `studio-framework/BOOTSTRAP_NEW_PROJECT.md` exists with 5 ordered steps.
- [ ] [S18.2-008] `studio-framework/SECRETS.md` has new `## Per-Agent GitHub App Bootstrap` section with subsections + worked example + canonical peers.
- [ ] [S18.2-009] All 9 agent profiles have exactly one `ESCALATION.md` link in Core Rules (or a justified documented exception).
- [ ] Specc audit for S18.2 lands on `studio-audits/main` at `audits/battlebrotts-v2/v2-sprint-18.2.md` before S18.3 planning PR opens (sub-sprint close-out invariant, now structurally enforced by [S18.2-003] once required).
- [ ] No regressions in existing required checks on `battlebrotts-v2:main`.
- [ ] No diffs under `godot/**` or `docs/gdd.md`.

---

## Sub-sprint shape reminder

S18 arc fuse: **5 sub-sprints.** S18.1 (apps + required check) ✓ · **S18.2 (this)** · S18.3 (cold-start validation) · S18.4 (branch-protection tightening) · S18.5 (simplification passes 5a–5g). If S18.2 scope expands beyond the in-scope list above, escalate to The Bott before proceeding — don't silently stretch the sub-sprint.

---

## Close-out residuals

*Added at S18.4 close-out (2026-04-22) per S18.3 §7 merge-commit hygiene + S18.1 close-out-residuals precedent.*

### §11.2 Option A bootstrap carve-out ledger

This sub-section tracks admin-PAT / bootstrap carve-out merges on `brott-studio/battlebrotts-v2` that predated the S18.4 structural closure of `Optic Verified` + `enforce_admins`. Each entry is a one-time annotated carve-out with explicit reason and scope. **The ledger is closed as of S18.4-001 landing (2026-04-22).** No further entries will be added — from S18.4-001 onward, every PR must pass the 4 required contexts on its own, and no admin override is available (S18.4-002 applied `enforce_admins: true`).

- **PR #233** — `brott-studio/battlebrotts-v2` — [S18.4-001] — merged `7e16b95c` on 2026-04-22 — reason: `Optic Verified` producer workflow did not yet exist on `main`, so the required context was unreachable for PR #233 itself. Post-merge validation: `Optic Verified` posted green by `brott-studio-optic` App on PR #152 head (first live PR after merge) and PR #234 head. **Ledger closed.**

Prior carve-outs (S18.3 sandbox setup / teardown admin-PAT uses for the cold-start dry-run; S18.2 `[S18.2-006]` doc-only close-out amendment; S18.1 `PR #221` admin-PAT probe) are logged in their respective sprint close-out residuals sections; this §11.2 ledger is scoped to S18.2-and-forward admin-PAT use on `battlebrotts-v2:main` and supersedes no prior record.
