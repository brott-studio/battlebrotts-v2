# Sprint 26.1 — Arc F.5 Playtest Triage

**Arc:** F.5 — Playtest Triage (P0 hotfix)
**Sub-sprint:** S26.1 (first sub-sprint of Arc F.5)
**Build under triage:** `main` @ `9aa417f` (S25.10), live at https://studio.brotatotes.com/battlebrotts-v2/
**Author:** Ett
**Date:** 2026-04-27

---

## Phase 0 — Audit-Gate

**Skipped.** First sub-sprint of Arc F.5 → no prior Arc F.5 audit expected. (Arc F closed at S25.10 / S25.9 ARC COMPLETE; Arc F.5 is a new playtest-triage hotfix arc, not a continuation of Arc F.)

## Step A — Continue-or-Complete

**Decision: CONTINUE.**

Rationale (one-liner): First sub-sprint of Arc F.5; arc goal is to fix 3 P0/P1 playtest bugs + close the framework gap that let them ship. Zero of the bugs are fixed; Gizmo's arc-intent verdict = `progressing`; GDD drift detected. Nothing is converged.

## Arc Goal

Fix 3 bugs surfaced in the first roguelike playtest (2026-04-27) AND close the framework gap (existing smoke tests didn't catch any of them).

1. **Bug 1 (P0):** Blank screen on chassis-pick → battle-start (intermittent, unknown root cause).
2. **Bug 2 (P1):** Settings popup cut off on right edge (root cause known: anchor/position math).
3. **Bug 3 (P1):** Battles too fast to interact (likely tuning, possibly mechanics bug).
4. **Framework gap:** Existing smoke tests pass on the live build but don't exercise the chassis-pick → battle-start handoff. Need an end-to-end gameplay smoke that would have caught Bug 1.
5. **GDD drift:** GDD documents the abandoned league system; zero spec for the roguelike loop. Add `§13 Roguelike Run Loop`.

## Sprint Overview

6 sub-sprints, ordered by P0 → framework → P1 → docs → audit-close:

| # | Title | Lead agent | Output |
|---|---|---|---|
| S26.1 | Repro + fix blank-screen bug (P0) | Optic → Nutts → Boltz | Merged fix + regression test |
| S26.2 | Fix settings popup cutoff (P1) | Nutts → Boltz | Merged fix + Playwright snapshot test |
| S26.3 | End-to-end gameplay smoke (framework gap) | Nutts → Boltz | New Playwright spec in `Verify` workflow |
| S26.4 | Investigate battle pacing (P1) | Optic → (Nutts if mechanics bug, else surface to Bott) | Combat-sim findings + fix-or-escalate |
| S26.5 | GDD update — §13 Roguelike Run Loop | Nutts → Boltz | `docs/gdd.md` PR |
| S26.6 | Specc audit arc-close | Specc | `studio-audits/audits/battlebrotts-v2/v2-sprint-26.1.md` (final arc-F.5 audit) |

Note: I'm naming the audit at the *arc* level (`v2-sprint-26.1.md`) per the framework's per-sub-sprint audit convention, but Specc should mark this audit as the arc-closing audit covering S26.1 through S26.6.

## Sub-sprint Breakdown

### S26.1 — Repro + Fix: Blank-screen bug (P0)

**Source:** Playtest 2026-04-27 (new this sprint, not yet filed).
**Design spec (from Gizmo):** Every archetype in the T1 mix table (`standard_duel`, `small_swarm`, `large_swarm`, `glass_cannon_blitz`) must successfully transition from chassis-pick to a rendered, playable arena. All 3 chassis × multiple seeds must work. Silent-failure-as-blank-screen is prohibited.

**Tasks:**
- **[S26.1-001]** Optic: headless repro pass.
  - Acceptance: load https://studio.brotatotes.com/battlebrotts-v2/, click NEW RUN, click each of the 3 chassis cards 5× per chassis (15 attempts minimum), capture browser console + Godot debug output for every attempt. Record which seeds + which archetypes correlate with failures. Return: failure rate per chassis, console error signature(s), and any pattern identifying the failing archetype/code path.
  - Suggested instrumentation: dump `RunState`, `current_battle_archetype`, and pre-spawn enemy loadout to console at scene-transition.
- **[S26.1-002]** Optic: code read.
  - Files to read: `godot/game_flow.gd`, `godot/run_state.gd`, `godot/run_start_screen.gd`, `godot/game_main.gd`, `godot/opponent_loadouts.gd`. Output: 1-paragraph summary of the chassis-pick → battle-start handoff with hypothesized failure point(s) backed by console signature from S26.1-001.
- **[S26.1-003]** Nutts: implement fix.
  - Must include a regression test (GUT or Playwright) that **reproduces the original failure on main @ 9aa417f** before applying the fix. Verify the test fails pre-fix, passes post-fix.
  - Add explicit error-surfacing: if the chassis-pick → battle-start handoff fails, log a hard error (not a silent return). No more silent-failure-as-blank-screen.
- **[S26.1-004]** Boltz: APPROVE + auto-merge per branch protection.

**Acceptance criteria (Optic verifies post-merge):**
- 15/15 chassis-pick → arena transitions succeed (3 chassis × 5 seeds).
- Browser console clean (no uncaught exceptions, no Godot script errors).
- Regression test in CI green.

---

### S26.2 — Fix: Settings popup cutoff (P1)

**Source:** Playtest 2026-04-27 (new this sprint, not yet filed).
**Root cause (Gizmo):** `main_menu_screen.gd:117–132` — `set_anchors_preset(PRESET_CENTER)` then `position = Vector2(390, 200)`. Anchors-at-center + raw position offset pushes panel off-screen right at 1280×720.
**Design spec (from Gizmo):** panel fully within viewport at 1280×720 and 1920×1080, centered ±20px, 24px margin minimum.

**Tasks:**
- **[S26.2-001]** Nutts: fix anchor/position logic in `main_menu_screen.gd`.
  - Recommended: keep `PRESET_CENTER` and set `position = Vector2(-panel_width/2, -panel_height/2)` to actually center (since with center-anchors the position is offset from the anchor point, not top-left). Alternatively use `set_offsets_preset(PRESET_CENTER)`.
  - No regression to other popups using the same pattern — grep for similar usage and verify.
- **[S26.2-002]** Nutts: Playwright snapshot test at 1280×720 and 1920×1080.
  - Acceptance: open settings popup; assert all 4 panel edges within viewport; assert center within ±20px of viewport center; assert ≥24px margin from any viewport edge.
  - Test must FAIL on `main @ 9aa417f` (pre-fix) to prove it actually catches the bug.
- **[S26.2-003]** Boltz: APPROVE + merge.

**Acceptance criteria (Optic verifies post-merge):**
- Snapshot test green at both resolutions.
- Manual visual check: settings popup fully visible, centered, on a 1280×720 page load.

---

### S26.3 — End-to-end gameplay smoke (closes framework gap)

**Source:** Framework gap exposed by playtest (new this sprint).
**Goal:** Add a Playwright spec that exercises the chassis-pick → battle-start handoff that existing smoke tests miss.

**Tasks:**
- **[S26.3-001]** Nutts: write Playwright spec.
  - Loads `/game/`, clicks NEW RUN, picks each of the 3 chassis (one per test case), asserts a battle scene loads (player sprite + ≥1 enemy sprite + HUD elements visible). Runs 5 iterations per chassis = 15 total assertions. Uses any deterministic-seed mechanism available, OR runs without seed and accepts that flake-rate must be 0/15.
  - Captures screenshot on failure to `verify-artifacts/`.
- **[S26.3-002]** Nutts: pre-merge gauntlet — verify the new smoke FAILS on `main @ 9aa417f` (pre-Bug-1 fix).
  - Workflow: branch from main @ 9aa417f, drop in only the new spec, run CI. Confirm ≥1 of the 15 assertions fails (proves the smoke detects the live bug). Capture run URL in PR body. THEN rebase on top of S26.1's fix and confirm 15/15 pass.
- **[S26.3-003]** Nutts: add the new spec to the `Verify` workflow CI matrix.
- **[S26.3-004]** Boltz: APPROVE + merge.

**Acceptance criteria (Optic verifies post-merge):**
- New spec in `Verify` workflow.
- Pre-fix run produces ≥1 failure (run URL pasted in PR).
- Post-fix run produces 15/15 pass.

**Risk:** S26.3 depends on S26.1 fix being merged for the post-fix verification step. Order: S26.1 → S26.3. (S26.2 is parallel-safe with both.)

---

### S26.4 — Investigate battle pacing (P1)

**Source:** Playtest 2026-04-27 (new this sprint, not yet filed).
**Note:** Battle pacing is **HCD's call (CD decision)**. This sub-sprint **investigates and reports**, it does not prescribe a rebalance.

**Tasks:**
- **[S26.4-001]** Optic: combat-sim battery on the T1 roguelike encounter pool vs. fresh-chassis player (no armor, no modules).
  - Pool: `standard_duel`, `small_swarm` (1v3), `large_swarm` (1v5), `glass_cannon_blitz`.
  - Per archetype, 50 sims; record: avg duration, player HP loss/sec, player win rate, time-to-first-player-hit, time-to-first-player-fire-event.
- **[S26.4-002]** Optic: mechanics-correctness check.
  - Verify player AI is engaging: autofiring on cooldown, moving when expected, weapons firing at intended cadence. If any of these are broken (e.g., player never autofires) it's a mechanics bug, not tuning.
- **[S26.4-003]** Decision branch:
  - **If mechanics bug found:** Nutts implements fix in this sub-sprint. Boltz APPROVE + merge.
  - **If pure tuning gap:** document findings (sim numbers + qualitative observations) in the sprint-26.1 doc under a `S26.4 Findings` appendix and surface to The Bott as an HCD decision point. Do NOT prescribe new tuning numbers.

**Acceptance criteria (Optic self-reports):**
- Sim battery completed, numbers in sprint doc.
- Mechanics-correctness verdict (working / broken-as-detailed) in sprint doc.
- If fix applied: regression sim showing post-fix numbers.

---

### S26.5 — GDD update: §13 Roguelike Run Loop

**Source:** Gizmo Phase 1 verdict — DRIFT DETECTED.
**Goal:** Document the roguelike loop as currently shipped on `main`. This is a doc-only change; no code touches.

**Tasks:**
- **[S26.5-001]** Nutts: write `§13 Roguelike Run Loop` in `docs/gdd.md`.
  - Required sections (per Gizmo's recommendation): run start, chassis pick, RunState, 15-battle ladder, tier→HP mapping, encounter archetype pool with specs (incl. T1 mix table from Bug-1 spec), run guarantees, retry rule, reward UX, click overrides, IRONCLAD PRIME / CEO Brott boss.
  - Cross-reference: read `godot/run_state.gd`, `godot/game_flow.gd`, `godot/opponent_loadouts.gd` to ensure spec matches shipped behavior.
- **[S26.5-002]** Nutts: review prior league-system §§ in GDD; mark abandoned sections as `DEPRECATED — superseded by §13 (Arc F)` rather than deleting (preserves audit trail).
- **[S26.5-003]** Boltz: APPROVE + merge.

**Acceptance criteria (Optic verifies post-merge):**
- `docs/gdd.md` contains a `§13 Roguelike Run Loop` section.
- Section accurately reflects what's in `run_state.gd` / `game_flow.gd` / `opponent_loadouts.gd` (spot-check 3 specs vs code).
- Old league sections marked DEPRECATED.

---

### S26.6 — Specc audit arc-close

**Source:** Standard pipeline phase 3e.
**Goal:** Final Arc F.5 audit covering S26.1–S26.5 + arc-complete verdict.

**Tasks:**
- **[S26.6-001]** Specc: audit each merged sub-sprint (verify acceptance criteria met, KB entries written for any patterns worth preserving).
- **[S26.6-002]** Specc: produce arc-close audit at `audits/battlebrotts-v2/v2-sprint-26.1.md` on `studio-audits/main`. Audit must explicitly verify:
  - Bug 1 (blank screen) closed: 15/15 chassis-pick → arena transitions succeed.
  - Bug 2 (settings popup) closed: snapshot tests green at 1280×720 and 1920×1080.
  - Bug 3 (battle pacing) addressed: either mechanics bug fixed OR finding documented + escalated to Bott (note in audit either way).
  - Framework gap closed: new smoke in Verify workflow, pre-fix-fail / post-fix-pass evidence captured.
  - GDD updated: §13 Roguelike Run Loop landed; abandoned league sections marked deprecated.
- **[S26.6-003]** Specc: file any new backlog issues for items deferred (esp. anything from S26.4 if surfaced to HCD).

**Acceptance criteria:**
- Audit committed to `studio-audits/main`.
- All 3 bugs + framework gap + GDD drift closed or explicitly carried forward.

---

## Carry-forwards / risks

- **S26.1 root cause unknown.** If Optic's repro can't characterize the failure pattern (e.g., it's truly stochastic with no archetype correlation), Nutts may need to spawn deeper into engine internals. Time-budget S26.1: if repro+diagnose exceeds 90 minutes, Riv escalates to The Bott for direction.
- **S26.3 dependency on S26.1.** S26.3's post-fix verification step requires S26.1 merged first. If S26.1 stalls, S26.3 still ships the spec + pre-fix-fail evidence; post-fix-pass step waits.
- **S26.4 may trigger CD escalation.** If pacing is pure tuning, this becomes a HCD-direction ask, not a Nutts task. The Bott handles that surface.
- **Audit-naming convention.** Per framework, audits are `v2-sprint-<N.M>.md`. Arc F.5 first sub-sprint = `v2-sprint-26.1.md`. If S26.2–S26.6 each get their own audit, naming would be `v2-sprint-26.2.md` ... `v2-sprint-26.6.md`. Recommendation: **one arc-rolled audit** at `v2-sprint-26.1.md` covering all six, since this is a tight P0 hotfix arc, not a multi-sprint feature build. Riv decides.

## BACKLOG HYGIENE

**Compliance gap detected.** The 3 playtest bugs that drove this arc are **not yet filed as GitHub issues**. They were surfaced via direct playtest report → Gizmo → arc spawn, bypassing the issue-tracker.

Action for The Bott: file 3 issues under `repo:battlebrotts-v2` with labels `playtest`, `prio:P0` (Bug 1) or `prio:P1` (Bugs 2 + 3) so the audit trail exists when Specc files carry-forwards. Suggested titles:

- **[playtest 2026-04-27] Blank screen on chassis-pick → battle-start (intermittent)** — `prio:P0`, `area:game-code`, `area:run-loop`
- **[playtest 2026-04-27] Settings popup cut off on right edge at 1280×720** — `prio:P1`, `area:ui`
- **[playtest 2026-04-27] T1 swarm encounters too fast vs fresh chassis** — `prio:P1`, `area:gameplay`, `pillar:roguelike`

**Prior-audit carry-forward verification:** N/A. Arc F closed at S25.9 ARC COMPLETE; Arc F's final audit's carry-forwards (if any) belong to a follow-on Arc F continuation, not Arc F.5. Arc F.5 is a new, scoped hotfix arc spawned from playtest; it inherits no prior-audit carry-forwards.

**Open backlog snapshot (for Riv awareness, not in-scope this arc):** 50+ open `label:backlog` issues, oldest dating to S16.1. None are P0. None are touched by this arc.

---

*End of sprint-26.1 plan. Ett out.*
