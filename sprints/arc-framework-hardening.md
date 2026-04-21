# Arc: Framework Hardening

**Status:** Docketed. To launch after S17 Eve Polish Arc closes.
**Type:** Framework arc (not game-content).
**Sponsor:** HCD (approved 2026-04-21).
**Origin:** Root-cause of S17.1-005 audit-gate bypass + framework self-sufficiency gap surfaced during S17.

---

## Why this arc

1. **Process-breach root cause (S17.1-005):** PR #171 merged before Optic verified. Root cause: the audit gate is a prompt convention, not a structural check. Branch protection has no way to require "Optic verified" — Specc could auto-merge on green CI + 1 approval alone. Need structural enforcement.
2. **Framework self-sufficiency gap:** A fresh session starting a new project today cannot cleanly adopt the studio pipeline. `FRAMEWORK.md` contradicts `PIPELINE.md` (Riv-retired vs Riv-canon), no `BOOTSTRAP_NEW_PROJECT.md`, secrets and CI-gate names are hardcoded to BattleBrotts, `ESCALATION.md` is orphaned under `docs/kb/`. Known since 2026-04-17 self-sufficiency audit; partially addressed.
3. **Drift prevention:** Without a structural test, framework self-sufficiency will regress every arc as new BattleBrotts-specific conventions leak in.

---

## Scope

### 1. Optic as a structural gate (P0 — addresses S17.1-005 breach)
- Create `brott-studio-optic` GitHub App (same pattern as Specc).
- Optic subagent posts `Optic Verified` check-run via Checks API on verify completion.
- Add `Optic Verified` to required status checks on `main` branch protection.
- Specc cannot auto-merge until Optic has structurally affirmed verify pass.
- Update `studio-framework/agents/optic.md` + `specc.md` to document the new flow.

### 2. Framework self-sufficiency (P0)
- Promote `docs/kb/escalation-policy.md` → `ESCALATION.md` at studio-framework root + cross-reference from all agent profiles.
- Resolve Riv-retired contradiction in `FRAMEWORK.md` (Riv + Ett are canon per 2026-04-17 HCD decision).
- Write `BOOTSTRAP_NEW_PROJECT.md`: the concrete 5-step setup for a fresh project (repo creation, per-agent App bootstrap, secrets provisioning, CI-gate configuration, first-arc spawn recipe).
- Abstract CI-gate names: agent profiles reference configurable gate names, not hardcoded `Godot Unit Tests` / `Playwright Smoke Tests`.
- Document per-agent GitHub App bootstrap procedure (creation, installation, token-file convention).

### 3. Cold-start validation (P1 — prevents future drift)
- Add arc-close protocol step: spawn a fresh subagent with *only* the `studio-framework` repo clone, ask it to plan Sprint 1 of a hypothetical new project.
- Any blocking question the cold-start agent asks becomes a framework PR before the next arc launches.
- Cold-start test runs ~10 min at each arc-close. Cheap to maintain.

### 4. Branch protection tightening (P2)
- Remove Specc from `bypass_pull_request_allowances` (Specc should merge via App, but only after an actual review).
- Enable `enforce_admins` to close the admin-bypass footgun.
- Apply same protection rules to `brott-studio/studio-audits`.

### 5. Simplification passes (P1, approved 2026-04-21)

**5a. Fold Patch into Nutts.** Patch's "on-demand DevOps" role adds maintenance overhead for marginal benefit. Mechanical fixes run through Nutts with an "infra-only" scope tag. Delete `agents/patch.md`; update Nutts profile + framework docs to document the scope-tag convention.

**5b. Investigate Ett fold into Riv.** Invariant that MUST be preserved: **Gizmo stays at head of loop** (design-first principle, load-bearing). Canonical ordering is Gizmo (Phase 1, design) → Ett (Phase 2, plan using design) → execution. Ett is NOT ceremonial one-shot planning — it turns design into a prioritized task breakdown integrating infra + audit findings + backlog. **Bias: keep Ett unless investigation finds it's been a rubber stamp for 2-3 arcs.** 10-min investigation reading Ett outputs across S15–S17. If kept, document Ett's load-bearing contribution explicitly so the question doesn't re-open every arc.

**5c. Remove prompt-level rules enforced structurally.** Once Optic becomes a required check (§1), remove "don't merge until Optic verifies" from Specc/Riv/Boltz prompts. General principle: **if a structural gate enforces X, profiles should not talk about X.** Duplicated rules are drift-surfaces. Audit all 8 profiles; remove redundancies; document the principle as a framework invariant.

**5d. Delete `ORCHESTRATION_PATTERNS.md`.** 203 lines documenting four orchestration patterns, of which only one (sequential pipeline) is canon — the other three are marked "potential future." Aspirational docs confuse fresh agents about what's real. Move one paragraph ("we use sequential pipeline, here's why") into PIPELINE.md; delete the rest. Resurrect only if fan-out/hierarchical becomes real.

**5e. Collapse FRAMEWORK.md + PIPELINE.md.** The two docs overlap heavily (both describe pipeline, agents, core principles). Having two sources of truth is the root of the Riv-retired contradiction — not a bug to fix, a symptom to eliminate. Pick PIPELINE.md as canonical (shorter, more accurate). Move anything unique from FRAMEWORK.md in. Reduce FRAMEWORK.md to a README-style index (or delete). One doc to update per change = eliminates an entire class of drift.

**5f. Light agent-profile audit.** Agent profile sizes are uneven (Nutts 37 lines, Riv 134). Strip aspirational prose; keep operational content. Goal: each profile is as long as it needs to be, no longer. Aim is not uniformity — Riv + Optic earn their size through concrete need; others may not.

### 6. CODEOWNERS — DEFERRED / DECLINED (documented decision)
- HCD does not want to be in the PR-review critical path. Creative-authority enforcement via HCD approval was considered and declined in favor of structural gates (Optic check, Specc-with-receipts pattern).
- Sacred-path concept retained as a scope-gate in agent prompts (existing), but not structurally enforced via CODEOWNERS. Revisit only if a concrete sacred-path breach occurs.

---

## Acceptance criteria

- [ ] `Optic Verified` check is required on `main`, blocks Specc merges until Optic posts success.
- [ ] Recreating the S17.1-005 sequence (Specc tries to merge before Optic verifies) is **physically impossible** — branch protection blocks it.
- [ ] `ESCALATION.md` at studio-framework root, cross-referenced by all 8 agent profiles.
- [ ] `FRAMEWORK.md` and `PIPELINE.md` internally consistent on Riv + Ett canon.
- [ ] `BOOTSTRAP_NEW_PROJECT.md` exists and a cold-start agent can follow it to completion without blocking questions.
- [ ] Cold-start validation step documented in Riv's arc-close protocol.
- [ ] `enforce_admins` enabled on `main` for battlebrotts-v2 and studio-audits.
- [ ] Specc removed from bypass list.

---

## Sub-sprint shape (tentative — Gizmo/Ett to refine)

**Naming note:** sub-sprint IDs (F.1, F.2, ...) and task IDs are **tentative**. Before arc launch, investigate existing numeric-ID assumptions (PR-title CI checks, sprint-file discovery in agent profiles, dashboard enumeration) and either (a) use a numeric-compatible scheme (e.g., Sprint 18 / [S18-NNN]) or (b) formalize non-numeric IDs as a framework-supported case. Bias: (a) — slot into existing scheme, lower tooling churn.

- **F.1** Optic App + structural check (CI workflow + Optic profile update + branch protection update).
- **F.2** Framework self-sufficiency pass (ESCALATION promotion, FRAMEWORK reconciliation on Riv+Ett canon, BOOTSTRAP_NEW_PROJECT.md, CI-gate abstraction).
- **F.3** Cold-start validation + arc-close protocol update.
- **F.4** Branch protection tightening (bypass removal, enforce_admins).
- **F.5** Simplification passes (fold Patch into Nutts; investigate Ett fold with Gizmo-at-head invariant protected and bias toward keep; prune prompt-level rules now structurally enforced; delete ORCHESTRATION_PATTERNS.md; collapse FRAMEWORK.md + PIPELINE.md; audit agent profile sizes).

---

## Notes for the next Riv

- This is a **framework arc**, not a game-content arc. Most work lands in `studio-framework` repo, not `battlebrotts-v2`. F.1 and F.4 land in both (battlebrotts-v2 for branch protection, studio-framework for agent profile updates).
- No sacred-path concern — this arc doesn't touch game data/combat/arena/GDD.
- HCD involvement expected to be minimal (design check-ins only, no PR reviews).
- Arc-close cold-start test is itself a deliverable of this arc — run it *on this arc's own output* before declaring the arc done.
