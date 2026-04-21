# Sprint 18.1 — Optic + Boltz GitHub Apps + Required-Check Wiring

**Status:** Complete
**Arc:** Framework Hardening (S18)
**Sub-sprint:** 1 of 5 (per arc-open shape; see §"Sub-sprint shape reminder")
**Planned by:** Ett
**Arc docket:** [PR #173](https://github.com/brott-studio/battlebrotts-v2/pull/173)

---

## Sprint goal

Close the S17.1-005 structural breach by making `Optic Verified` a branch-protection–required check on `battlebrotts-v2:main`, and stand up per-agent GitHub Apps for Optic and Boltz so check-run posting and reviewer identity run on distinct actors (not the shared PAT).

---

## Arc context

S18 is a **framework arc**, not game-content. Five sub-sprints, in order: **S18.1 Apps + required check (this sprint) → S18.2 self-sufficiency → S18.3 cold-start validation → S18.4 branch-protection tightening (battlebrotts-v2 + studio-audits + studio-framework) → S18.5 simplification passes**. Arc fuse: 5 sub-sprints per the shape above; revisit with HCD if scope expands. Arc priorities, in order: (1) structural enforcement of the audit-gate / verify-gate family so pipeline hygiene cannot drift (P0), (2) self-sufficiency so a fresh project can cold-start the pipeline (P0), (3) drift-prevention surfaces (P1–P2). S18.1 lands the first P0 brick — every subsequent sub-sprint depends on these Apps existing and the required check being wired.

Naming: numeric `S18.1` … `S18.5`, task IDs `[S18.1-NNN]` — slots into existing PR-title CI checks and sprint-file discovery globs (zero tooling churn).

---

## In scope

- Create `brott-studio-optic` GitHub App (org-level, scoped permissions, webhook disabled). Install on `battlebrotts-v2`.
- Create `brott-studio-boltz` GitHub App (org-level, scoped permissions, webhook disabled). Install on `battlebrotts-v2`.
- Deploy token helpers `~/bin/optic-gh-token` and `~/bin/boltz-gh-token` (copies of the Specc helper, s/specc/<agent>/g).
- Wire Optic subagent to post an `Optic Verified` check-run via the Checks API on verify completion (PASS or FAIL, head SHA of the PR).
- Add `Optic Verified` to required status checks on `battlebrotts-v2:main` branch protection.
- Update agent profiles: `studio-framework/agents/optic.md`, `agents/boltz.md`, `agents/specc.md` (cross-reference only for Specc — no rule-duplication).
- Update `studio-framework/SECRETS.md` (App IDs + installation IDs + PEM/token paths for Optic and Boltz).
- Update `studio-framework/SPAWN_PROTOCOL.md` (Optic and Boltz preambles reference their own App tokens).
- End-to-end validation: mock-PR test for `Optic Verified` gate + mock-PR test for Boltz cross-actor review/merge returning HTTP 200.

---

## Out of scope (explicitly — these are later sub-sprints)

- **`BOOTSTRAP_NEW_PROJECT.md`, per-agent-App bootstrap doc, cross-reference audit of `ESCALATION.md` from agent profiles.** → **S18.2** (self-sufficiency).
  - Note: the arc docket §2 lists several self-sufficiency items (ESCALATION.md at framework root, FRAMEWORK.md Riv-retired contradiction, CI-gate hardcoded names). Gizmo's arc-opening review found ~50% of these already done on `main`. Real remaining S18.2 scope is the three items above.
- **Cold-start validation protocol.** → **S18.3**.
- **Branch-protection tightening** (Specc bypass removal, `enforce_admins` on `main`, application to `studio-audits` **and** `studio-framework`). → **S18.4**.
- **Simplification passes** (5a–5g: Patch→Nutts fold, Ett-fold investigation, prune-structurally-enforced prompt rules, delete `ORCHESTRATION_PATTERNS.md`, collapse FRAMEWORK/PIPELINE, light agent-profile audit, 5g tool-allowlist tracking). → **S18.5**.
- **Audit-gate planning-PR structural enforcement decision.** See Open Question O1 below. Does not block S18.1; affects S18.2 shape.
- **Game code.** No `godot/**`, no `docs/gdd.md` changes. Hard scope-gate.

---

## Task breakdown

Task IDs `[S18.1-NNN]`. Agents: Nutts (builder; in this sprint, also infra scaffolding per the 5a "fold Patch into Nutts with infra-only scope tag" direction — the fold itself is S18.5, but infra-only Nutts is already how we run per arc docket §5a). Boltz (reviewer). Optic (verifier). Apps creation itself is **HCD-facing** (needs GitHub web UI — see `docs/kb/per-agent-github-apps.md` §"Setup steps"); Nutts deploys the helper scripts and agent-profile wiring afterward.

### HCD-facing setup (prerequisite for all below)

**[S18.1-001]** *(HCD)* Create `brott-studio-optic` GitHub App on the brott-studio org. Permissions: **Contents: Read & write**, **Checks: Read & write**, **Metadata: Read-only**. Webhook disabled. Install on `battlebrotts-v2`. Download `.pem` to `~/.config/gh/brott-studio-optic-app.pem` (mode `0600`). Record **App ID** + **Installation ID**. Dependency: none. Reference: `docs/kb/per-agent-github-apps.md` §"Setup steps".
*Note: PEM path follows the established Specc convention `~/.config/gh/brott-studio-<agent>-app.pem`, not the `~/.config/brott-studio/optic-app.pem` variant mentioned in the arc docket — conforming to the S16.2 pattern eliminates tooling churn in the token-helper template.*

**[S18.1-002]** *(HCD)* `[#210]` Create `brott-studio-boltz` GitHub App on the brott-studio org. Permissions: **Contents: Read & write**, **Pull requests: Read & write**, **Metadata: Read-only**. Webhook disabled. Install on `battlebrotts-v2`. Download `.pem` to `~/.config/gh/brott-studio-boltz-app.pem` (mode `0600`). Record App ID + Installation ID. Dependency: none. Reference: `docs/kb/per-agent-github-apps.md` + `docs/kb/shared-token-self-review-422.md` (root-cause issue that Boltz App resolves). Source issue: **#210**.

### Nutts — token helpers + profile wiring

**[S18.1-003]** *(Nutts, infra-only)* Deploy `~/bin/optic-gh-token` by copying `~/bin/specc-gh-token` and substituting `SPECC` → `OPTIC` (upper for env vars) and `specc` → `optic` (lower for paths). Verify: `OPTIC_APP_ID=<id> OPTIC_INSTALLATION_ID=<id> ~/bin/optic-gh-token` prints a 40-char token. Same fallback-refusal rule as Specc (no silent PAT fallback). Dependency: S18.1-001 complete.

**[S18.1-004]** *(Nutts, infra-only)* `[#210]` Deploy `~/bin/boltz-gh-token` (same pattern, s/specc/boltz/g). Verify: prints a 40-char token. Dependency: S18.1-002 complete.

**[S18.1-005]** *(Nutts)* Update `studio-framework/SECRETS.md`: add Optic App inventory entry (App ID, Installation ID as inline comments matching the Specc pattern at `SECRETS.md` §"🔐 Specc GitHub App Private Key"), PEM path, token-helper path. Add Boltz App inventory entry in the same form. Dependency: S18.1-001, S18.1-002.

**[S18.1-006]** *(Nutts)* Update `studio-framework/SPAWN_PROTOCOL.md`: Optic preamble exports `OPTIC_APP_ID` / `OPTIC_INSTALLATION_ID` and mints `$TOKEN` from `~/bin/optic-gh-token` for any git/gh/curl call that should run as Optic; Boltz preamble mirrors with `BOLTZ_*`. Preserve existing Specc preamble as reference template. Dependency: S18.1-005.

### Optic check-run wiring

**[S18.1-007]** *(Nutts + Optic spec input)* Optic subagent gains a check-run posting step at verify-completion time. Posts `Optic Verified` check via `POST /repos/{owner}/{repo}/check-runs` using the Optic App token, with `head_sha` = PR head, `conclusion` = `success` on PASS or `failure` on FAIL (and descriptive `output.summary`). Happens **after** the local verify runs produce a PASS/FAIL verdict, before Optic returns to Riv. Dependency: S18.1-003, S18.1-006.

**[S18.1-008]** *(Nutts, branch-protection config)* Add `Optic Verified` to required status checks on `battlebrotts-v2:main` via the branch-protection API. Leave existing required checks (`Godot Unit Tests`, `Playwright Smoke Tests`, PR-title check, etc.) untouched. Do NOT modify bypass lists, admin enforcement, or apply to other repos — those are S18.4 scope. Dependency: S18.1-007 merged and validated once (§Acceptance AC-1 below) so we don't gate on a check nobody posts.

### Agent profile updates

**[S18.1-009]** *(Nutts)* Update `studio-framework/agents/optic.md`: document the check-run posting flow (which endpoint, what the conclusion map is, when it fires). One section; operational content only, no aspirational prose.

**[S18.1-010]** *(Nutts)* `[#210]` Update `studio-framework/agents/boltz.md`: document that Boltz now authenticates via its own App token (not the shared PAT), the review-then-merge flow using the App token, and that cross-actor APPROVE events now return HTTP 200 instead of 422 when Nutts is the PR author. Cross-reference `docs/kb/shared-token-self-review-422.md` and `docs/kb/per-agent-github-apps.md`.

**[S18.1-011]** *(Nutts)* Update `studio-framework/agents/specc.md`: cross-reference (one line + link) noting that merging `battlebrotts-v2:main` now requires `Optic Verified` as a structural check. **Do not duplicate the rule.** Per the arc-docket §5c framework principle ("if a structural gate enforces X, profiles should not talk about X"), the profile points at the gate rather than restating the rule. S17.1-005 breach prevention is now physical, not convention.

### Acceptance / validation

**[S18.1-012]** *(Nutts + Optic)* **Headless `Optic Verified` gate test.** Open a throwaway PR on `battlebrotts-v2` (branch off `main`, no-op change, e.g., whitespace in a doc file). Attempt Specc-flow merge **before** Optic posts the check — confirm branch protection blocks the merge with "Required status check `Optic Verified` is missing." Then spawn Optic on the PR, let it post `conclusion: success`, re-attempt merge — confirm it succeeds. Delete throwaway PR/branch. Evidence: PR URL, screenshot/JSON of the pre-post merge-block, screenshot/JSON of the post-post merge-success. Dependency: S18.1-008.

**[S18.1-013]** *(Boltz + Nutts)* `[#210]` **Headless Boltz cross-actor review test.** Nutts opens a throwaway PR (same pattern as above). Boltz reviews-and-approves using its new App token (`~/bin/boltz-gh-token`). Confirm the GitHub API response is **HTTP 200** (not 422) and the review shows as `brott-studio-boltz[bot]`. Confirm Boltz can then merge via the Merge API using the same App token. Delete throwaway PR/branch. Evidence: API response JSON, PR URL. Dependency: S18.1-004, S18.1-006.

---

## Acceptance criteria

- **AC-1 (S17.1-005 "physically impossible to bypass"):** ✅ PASS (narrow — pipeline actors blocked; admin-PAT bypass → S18.4). On `battlebrotts-v2:main`, a PR cannot be merged until `Optic Verified` check-run has posted `conclusion: success` from the Optic App. Recreating the S17.1 sequence (Specc/Nutts/auto-merge attempts to merge before Optic posts) is blocked by branch protection, not by prompt convention. Verified via **[S18.1-012]**.
- **AC-2 (Boltz self-review-422 resolved):** ✅ PASS. Boltz can APPROVE a Nutts-authored PR using its own App token and receive HTTP 200. Audit trail shows reviewer as `brott-studio-boltz[bot]`, distinct from the PR author. Same-actor 422 edge cases remain (platform-level, per `per-agent-github-apps.md`) but cross-actor flow — the actual pipeline requirement — works. Verified via **[S18.1-013]**.
- **AC-3 (Inventory documented):** ✅ PASS. `studio-framework/SECRETS.md` lists Optic + Boltz App IDs, Installation IDs, PEM paths, token-helper paths in the same inline-comment shape as the existing Specc entry.
- **AC-4 (Profiles updated):** ✅ PASS. `optic.md` documents check-run posting; `boltz.md` documents App-token auth + cross-actor review flow; `specc.md` cross-references the structural gate without restating the rule. `SPAWN_PROTOCOL.md` preambles for Optic and Boltz reference their own App tokens.
- **AC-5 (No silent PAT fallback):** ✅ PASS. Token helpers exit non-zero on config/API failure; agents stop and report. No agent code path falls back to `~/.config/gh/brott-studio-token` silently.
- **AC-6 (Scope-gate held):** ✅ PASS. Zero diffs under `godot/**`, `docs/gdd.md`. All changes land in `studio-framework/**`, `docs/kb/**` (if any), `~/bin/**` (workspace-host only, not in repo), or the `battlebrotts-v2` branch-protection config.

---

## Close-out residuals

*Added at S18.1 close-out (2026-04-21) per HCD-delegated Bott decisions.*

### AC-1 interpretation (narrow read)

Per HCD-delegated Bott decision 2026-04-21, AC-1 is interpreted as **"pipeline actors (App tokens) cannot bypass the branch-protection gate."** Under that reading, AC-1 is **PASS**: PR #222 — a pre-Optic Boltz-App-token merge attempt — returned **HTTP 405**, confirming the pipeline gate holds against normal pipeline actors.

**Admin-PAT bypass is a known residual.** Branch protection on `main` does not currently have `enforce_admins` set, so an admin-PAT probe (PR #221) returned **HTTP 200**. This is deferred to **S18.4** (Optic as sole-merger / admin lockdown), per the original arc plan. **Do NOT flip `enforce_admins` this sprint** — that's S18.4 scope.

### Evidence

- **PR #222** — pre-Optic Boltz-App-token merge attempt → **HTTP 405** → **PASS (pipeline gate holds).**
- **PR #221** — admin-PAT probe → **HTTP 200** → **residual, carry to S18.4.**

### O1 resolved (planning-PR audit-gate)

Open Question **O1** (audit-gate planning-PR structural enforcement) resolved by Bott decision 2026-04-21: **Option B.** S18.2 will add a CI check that fails a planning PR when the prior sprint's audit file is absent from `brott-studio/studio-audits` on `main`. This is a **carry-forward to S18.2 scope**.

---

## Open questions

**O1 — Audit-gate planning-PR structural enforcement.** Gizmo's arc-opening review flagged that S17.1-005 is actually two breaches, and the arc docket §1 only addresses breach (b) (merge-before-verify). Breach (a) — **audit-gate planning PR enforcement** — is the recurring S15.2 → S16.1 → S17.1 pattern where a sub-sprint's plan PR lands before the previous sprint's Specc audit lands on `studio-audits/main`. Two candidate fixes:
  - **Option A:** Rely on studio-framework PR #20 (already landed; worked successfully at S17.2 close-out). Argues the gate is adequate as-is.
  - **Option B:** Add an additional structural check on planning PRs (e.g., a CI check that queries `studio-audits/main` for the prior sprint's audit file and fails the planning PR if absent).

**This is HCD / The Bott's call.** Not a blocker for S18.1 — S18.1 is strictly the Apps/required-check sub-sprint. **Answer needed before S18.2 planning** because it affects S18.2 scope (self-sufficiency) either by including an additional CI check (Option B) or omitting it (Option A).

---

## BACKLOG HYGIENE

**Backlog query used:** `GET /repos/brott-studio/battlebrotts-v2/issues?state=open&labels=backlog&per_page=100` — 41 open backlog issues pulled 2026-04-21.

**Prior-audit carry-forward cross-reference** (S17.1 through S17.4 audits):

| Audit | Carry-forward item | Issue | Filed? |
|---|---|---|---|
| S17.2 | Sprint-doc close-out hygiene | [#193](https://github.com/brott-studio/battlebrotts-v2/issues/193) | ✓ |
| S17.2 | PR-body narrative drift | [#194](https://github.com/brott-studio/battlebrotts-v2/issues/194) | ✓ |
| S17.2 | Optic verify artifact inconsistency | [#195](https://github.com/brott-studio/battlebrotts-v2/issues/195) | ✓ |
| S17.2 | HCD 5-min scout-feel playtest | [#196](https://github.com/brott-studio/battlebrotts-v2/issues/196) | ✓ |
| S17.3 | Drag-to-reorder in BrottBrain | [#201](https://github.com/brott-studio/battlebrotts-v2/issues/201) | ✓ (filed by Nutts at PR #202 merge) |
| S17.3 | Cherry-pick scope-gate near-miss | [#208](https://github.com/brott-studio/battlebrotts-v2/issues/208) | ✓ |
| S17.3 | Sprint-plan enum-ordinal wording | [#209](https://github.com/brott-studio/battlebrotts-v2/issues/209) | ✓ |
| S17.3 | Boltz self-approve — separate GitHub App | **[#210](https://github.com/brott-studio/battlebrotts-v2/issues/210)** | ✓ — **source issue for S18.1-002, -004, -010, -013** |
| S17.4 | (no new carry-forwards, all prior items tracked) | — | — |

**Gaps:** none identified. All S17.x carry-forwards are filed as issues with appropriate labels. S17.4 audit explicitly confirms "Four carry-forward items (#201, #208, #209, #210) post-arc-close, aligned with S17.4 sprint plan's explicit rationale. No backlog gap."

**Issue references in S18.1 task IDs:**
- **#210** (Boltz App) → explicit source for [S18.1-002], [S18.1-004], [S18.1-010], [S18.1-013].
- No open issue exists for "Optic App" specifically — it's a new arc-level item introduced by the Framework Hardening docket (PR #173), not a pre-existing backlog entry. Tasks [S18.1-001], [S18.1-003], [S18.1-007], [S18.1-008], [S18.1-009], [S18.1-012] are marked `new this sprint` (origin: arc docket §1).

---

## Sub-sprint shape reminder

Per Gizmo's arc-opening review, concurring with Ett's framing: **S18.1** (this sprint) = Optic App + Boltz App + required-check wiring. **S18.2** = self-sufficiency (smaller than the docket implies — `BOOTSTRAP_NEW_PROJECT.md`, per-agent-App bootstrap doc, ESCALATION cross-reference audit across all 8 profiles). **S18.3** = cold-start validation protocol + arc-close protocol update. **S18.4** = branch-protection tightening across `battlebrotts-v2`, `studio-audits`, **and `studio-framework`** (scope addition from Gizmo's review). **S18.5** = simplification passes (5a–5g; 5e "collapse FRAMEWORK + PIPELINE" may earn its own treatment as "eliminate overlap drift surface" rather than one-line bullet).

Arc fuse: 5 sub-sprints; re-evaluate with HCD if any sub-sprint grows or additional scope surfaces.

---

## Risks

- **R1 — GitHub App creation is HCD-gated.** [S18.1-001] and [S18.1-002] cannot be executed by the pipeline — they require GitHub web-UI access to create Apps under the brott-studio org. Pipeline stalls at S18.1-003 / S18.1-004 until HCD completes the creation and drops the `.pem` files. Mitigation: surface this at sprint-plan merge so HCD can schedule App creation in parallel with any other S18.1 prep.
- **R2 — Chicken-and-egg on `Optic Verified` required check.** If [S18.1-008] (adding the required check) lands before [S18.1-007] (Optic actually posting it), every subsequent PR is blocked until Optic's first run. Ordering matters: validate [S18.1-012] end-to-end on a throwaway PR, then flip the branch-protection requirement. Mitigation: explicit dependency ordering documented in task breakdown; [S18.1-008] depends on [S18.1-007] having run at least once successfully.
- **R3 — Auto-merge shadow (from `per-agent-github-apps.md` §"Caveat").** On PRs with auto-merge enabled, `github-actions[bot]` may execute the merge after Optic posts success, not Boltz's App. This is benign for audit-trail purposes (the gating approval is Boltz's) but means S18.1 does **not** guarantee "merged_by = Boltz[bot]" on every PR. Out of scope for S18.1; surface in profile doc so future-us doesn't chase it as a regression.
- **R4 — Same-actor 422 is not fixed by this sprint, and cannot be.** Platform-level. Out of scope; documented in [S18.1-010] profile update for Boltz.
- **R5 — Token-helper deployment is workspace-host-local, not repo-tracked.** `~/bin/optic-gh-token` and `~/bin/boltz-gh-token` live on the host, not in the repo. Rotation / re-deploy on a new host is a manual step. S18.2 `BOOTSTRAP_NEW_PROJECT.md` needs to document this (not S18.1's problem, flagging for handoff).

---

## Exit criteria

- [x] All AC-1 through AC-6 satisfied and evidenced. *(AC-1 narrow — pipeline actors blocked; admin-PAT bypass → S18.4. See Close-out residuals.)*
- [x] `sprint-18.1.md` status updated from `Planning` to `Complete` at close-out; exit-criteria checkboxes ticked; carry-forwards (if any) listed.
- [x] Specc audit for S18.1 lands on `studio-audits/main` before S18.2 planning PR opens (audit-gate discipline).
- [x] No regressions in existing required checks on `battlebrotts-v2:main`.
