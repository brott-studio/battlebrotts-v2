# Sprint 17.1 — Shop/Loadout/Event UX fixes

**PM:** Ett
**Status:** Planning (iteration 1 of S17 — arc-opening sub-sprint)
**Sprint type:** Sub-sprint (UX polish, Shop/Loadout/Event surfaces)
**Parent arc:** [`sprints/sprint-17.md`](./sprint-17.md) — see §"S17.1 — Shop/Loadout/Event UX fixes"

---

> ## 🛑 SCOPE GATE — READ FIRST
>
> **This sub-sprint is UX polish on Shop / Loadout / Event popup surfaces only.** No behavior changes to `godot/combat/**`, `godot/data/**`, `godot/arena/**`, or `docs/gdd.md`. Tooltips, scroll behavior, layout, and event-popup framing only.
>
> See the full scope gate, sacred-paths list, and escalation triggers in the arc brief: [`sprints/sprint-17.md`](./sprint-17.md) §"🛑 SCOPE GATE", §"Sacred", §"Escalation triggers". **Do not duplicate the arc-level gate here** — the arc brief is the authoritative reference. If a task in this plan seems to drift outside those gates, stop and escalate to Riv.
>
> Arc scope streak (S15.2 → S16.3): clean. S17.1 opens the S17 arc — hold the line.

---

## Goal (condensed from arc brief §S17.1)

Remove the top Shop/Loadout/Event UX friction points from the 2026-04-18 playtest. The HCD charter frames the arc as "convert playable-but-rough into something that feels professional, clean, polished" (Eve from WALL-E vision, `docs/kb/ux-vision.md`). S17.1 is the first slice of that — the surfaces the HCD touches most in a run.

**Gizmo design drift this sprint:** primarily layout, scroll behavior, and tooltip visibility. S17.1-004 (first-encounter HUD explainer) and S17.1-005 / S17.1-006 (random-event / crate popup redesign) have more UX-design surface than the others — Gizmo should produce explicit interaction specs for those before Nutts builds.

---

## Tasks

S17.1 contains **6 tasks**, [S17.1-001]..[S17.1-006]. Task IDs are derived from arc brief §S17.1 and are used verbatim in branches, PR titles, and commit messages.

Per-task format: title + summary, playtest citation + backlog issue, acceptance criteria, scope notes, proposed complexity. Gizmo converts acceptance criteria into concrete technical specs task-by-task.

### [S17.1-001] Shop scroll behavior — respect OS scroll + preserve position on click

- **Summary:** Fix two related Shop scroll bugs: scroll is too fast (doesn't respect OS scroll-speed conventions) and clicking any Shop item snaps the view back to the top.
- **Citation — playtest (2026-04-18, in arc brief §S17.1 Citations):**
  > "very hard to scroll in the shop - scrolls too fast"
  > "whenever i click something in the shop it shoves me all the way back to the top of the screen"
- **Backlog:** [#105](https://github.com/brott-studio/battlebrotts-v2/issues/105) — `UX: Scroll behaviors respect user position` (prio:mid).
- **Acceptance criteria (concrete / testable):**
  - Shop scroll wheel delta per tick matches OS scroll-speed convention (no custom multiplier overriding the platform default).
  - After clicking any Shop item (buy, inspect, tooltip-trigger), the Shop scroll position is unchanged from pre-click state. Verified by Playwright (or equivalent) test capturing `scrollTop` (or Godot scroll-container equivalent) before and after a click on an item mid-list.
  - Regression coverage: at least one automated test exercises "scroll to middle of Shop, click item, assert scroll position preserved."
- **Scope notes — do NOT change:**
  - Shop item data, prices, or inventory logic (touches `godot/data/**` — sacred).
  - Shop-enter / shop-exit flow or the Shop button's visibility rules (that's S17.1-002's turf; keep changes separable).
  - Layout beyond what's strictly required to adjust scroll-container behavior.
- **Proposed complexity:** **S** (small, well-scoped UI fix).

### [S17.1-002] Loadout UI overlap — shop button always accessible

- **Summary:** When the Loadout inventory is populated heavily, UI elements overlap the Shop button and block the player from re-entering the Shop. Fix the layout so the Shop button is always reachable.
- **Citation — playtest:**
  > "in loadout when i have a lot of stuff they cover the shop button"
- **Backlog:** [#104](https://github.com/brott-studio/battlebrotts-v2/issues/104) — `UX: No UI overlap at full inventory / loadout` (prio:high).
- **Acceptance criteria (concrete / testable):**
  - At maximum inventory size (worst-case populated Loadout — Gizmo to enumerate what "max" means based on current inventory cap), the Shop button is fully visible AND clickable (not occluded, not rendered below a competing panel).
  - Verified by a Playwright / visual-snapshot test with a synthetic max-inventory save or dev fixture.
  - No change to the Shop button's position on an empty Loadout (i.e. the fix must not regress the default-state layout).
- **Scope notes — do NOT change:**
  - Inventory cap, inventory model, or any `godot/data/**` schema.
  - Shop button's action / behavior (just its reachability).
  - Loadout item drag/drop behavior (out of scope for S17.1 — that surface is S17.3 adjacent if anywhere).
- **Proposed complexity:** **S** (layout-only fix, likely z-order / anchor / minimum-size tweak).

### [S17.1-003] Tooltips visible-by-default for critical Loadout info

- **Summary:** The playtester couldn't double-check what Loadout items were/did without discovering hover (which was later confirmed to work but was non-obvious). Make critical item info visible-by-default rather than hover-gated.
- **Citation — playtest:**
  > "in loadout view there's no way to double check what an item is or does" (later found hover works)
- **Backlog:** [#103](https://github.com/brott-studio/battlebrotts-v2/issues/103) — `UX: Tooltips visible by default (not hover-only)` (prio:high).
- **Acceptance criteria (concrete / testable):**
  - In Loadout view, for every item in the inventory, at least the item's **name** and **one-line role/stat summary** is visible without requiring hover. Gizmo defines the exact info tier ("critical info") during design — at minimum name + primary-stat line.
  - Hover / focus still surfaces full detail (don't remove the richer hover tooltip — just stop gating the essentials behind it).
  - Playwright / visual-snapshot test confirms the visible-by-default text renders for at least 3 distinct item types.
  - No regression in Loadout layout density — if visible-by-default labels push other UI off-screen at max inventory, coordinate with S17.1-002.
- **Scope notes — do NOT change:**
  - Item data or stats (touches `godot/data/**` — sacred).
  - Shop tooltips (different surface; can be a separate ticket if playtest flags it later).
  - Full re-tooltip of every HUD element — that's S17.1-004's scope.
- **Proposed complexity:** **M** (touches every Loadout item render path; interacts with S17.1-002 layout).

### [S17.1-004] First-encounter HUD explainer — energy bar (and adjacent HUD elements)

- **Summary:** Player didn't know what the blue bar was or what energy is for. Add a one-sentence, dismissible explainer on first encounter for the energy bar and any other HUD element that has no self-evident meaning.
- **Citation — playtest:**
  > "i'm confused what the blue bar is - is that energy? What is energy for?"
- **Backlog:** [#107](https://github.com/brott-studio/battlebrotts-v2/issues/107) — `UX: First-encounter explanation for every HUD element` (prio:mid).
- **Acceptance criteria (concrete / testable):**
  - On first encounter with the energy bar (i.e. the first game state where energy is non-zero or the bar is first rendered), a one-sentence explainer tooltip / overlay is shown. One sentence, ≤25 words.
  - The explainer is dismissible (click / ESC / timeout — Gizmo picks one interaction model and documents it).
  - Dismissal state persists across sessions (saved to user profile / settings store) — don't re-show on every launch.
  - Gizmo enumerates during design which HUD elements qualify for the first-encounter explainer pass. At minimum: energy bar. Non-obvious elements like currency / crate-count may be included if Gizmo judges them non-self-evident; obvious elements (HP bar, score) do not need explainers.
  - Verified by a test that asserts: (a) first-run shows explainer, (b) dismissed state suppresses on reload.
- **Scope notes — do NOT change:**
  - What energy does (game mechanic — sacred).
  - Energy bar's visual design beyond adding the explainer overlay.
  - HUD layout for HP / score / other non-ambiguous bars.
- **Proposed complexity:** **M** (new "first-encounter" infra — persistence + overlay + first-run detection).

### [S17.1-005] Random-event popup polish — less interruptive, more skippable

- **Summary:** Random-event popups (trading, crate, random-decision) feel chaotic and take items from the player in ways that read as punitive rather than rewarding. Polish toward "skippable or rarer," following ux-vision.md anti-patterns.
- **Citation — playtest:**
  > "the popup asking for trading or opening crates is kind of annoying"
  > "the random events with decision are pretty chaotic, taking my items"
- **Backlog:** [#106](https://github.com/brott-studio/battlebrotts-v2/issues/106) — `UX: Random-event popup redesign` (prio:mid).
- **Acceptance criteria (concrete / testable):**
  - Random-event popup has a clear, always-present "skip / decline" affordance (e.g. explicit button, not just ESC). Gizmo picks the affordance during design.
  - Frequency of random-event popups per run is either (a) reduced by a measurable amount, or (b) held constant if Gizmo and Riv determine frequency is already correct and the problem is purely UX framing. Whichever: documented in the Gizmo spec with rationale.
  - Events that remove items from the player must signal the removal clearly **before** the player commits (pre-commit preview), not as a surprise consequence.
  - Playwright / functional test asserts the skip affordance exists and exits cleanly without affecting game state.
- **Scope notes — do NOT change:**
  - Random-event content / outcome tables (data — sacred unless Gizmo explicitly scopes a minimal frequency tweak as part of (a) above, with Ett sign-off).
  - `godot/combat/**` or `godot/arena/**`.
  - Shop or Loadout flow.
- **Proposed complexity:** **M** (UX framing + possibly a small frequency tweak; could be L if Gizmo decides item-removal preview needs a new UI component).

### [S17.1-006] First-run crate decision — contextualize or defer

- **Summary:** "The screen asking whether I want to open a crate was jarring to be the first thing I see." The first-run crate-decision popup lands with no context. Either contextualize it (brief framing / onboarding line) or defer it until after the player has some grounding in the loop.
- **Citation — playtest:**
  > "the screen asking whether i want to open a crate was jarring to be the first thing i see"
- **Backlog:** [#107](https://github.com/brott-studio/battlebrotts-v2/issues/107) (broader — first-encounter HUD / decision-surface explanation).
- **Acceptance criteria (concrete / testable):**
  - On first run, the crate-decision popup either (a) includes a one-line contextual framing above the choice (what a crate is, what opening does), OR (b) is deferred to after the first shop/loadout interaction — whichever Gizmo recommends based on ux-vision.md.
  - Gizmo's design spec explicitly states which path (a or b) was chosen and why, referencing ux-vision.md.
  - On non-first runs, popup behavior is unchanged (don't punish returning players with a re-shown tutorial).
  - Verified by a test asserting (a) first-run context is present OR first-run popup is gated as designed, and (b) second-run popup behaves per existing logic.
- **Scope notes — do NOT change:**
  - Crate mechanics or loot tables (sacred).
  - The crate-decision popup's look outside the framing line (if path a) or its trigger location outside the deferral point (if path b).
  - First-run state detection if one already exists — reuse existing infra if possible; introduce new infra only if strictly necessary (coordinate with S17.1-004's first-run persistence).
- **Proposed complexity:** **S–M** (S if path (a) contextualization; M if path (b) requires wiring a new gating point).

---

## Pipeline flow (standard S17)

Standard pipeline per arc brief §"Pipeline flow":

**Gizmo designs task-by-task → Nutts builds → Boltz reviews → Optic verifies → Specc audits → Gizmo validates → Ett decides continuation.**

Riv loops the sub-sprint. Task-by-task is the key phrase — Gizmo does not batch-design all six at once. Each task's acceptance criteria above feed Gizmo's per-task technical spec.

**Design-first tasks this sprint:** S17.1-004 (first-encounter explainer — new infra), S17.1-005 (popup redesign — UX framing), and S17.1-006 (first-run crate path selection) have the most design surface. Gizmo writes explicit interaction specs before Nutts starts.

**Build-mostly tasks:** S17.1-001, S17.1-002, S17.1-003 are primarily layout/behavior fixes with well-scoped acceptance. Gizmo still designs, but the spec is shorter.

---

## Acceptance for S17.1 (from arc brief)

- All 6 tasks either land (PR merged) or get **HCD-visible defer notes** (surfaced to HCD via The Bott with rationale).
- Optic Playwright run confirms no regressions in Shop / Loadout / Event popup screens.
- Scope gate held — zero diffs to `godot/combat/**`, `godot/data/**`, `godot/arena/**`, `docs/gdd.md`.

---

## Audit gate (HARD RULE)

Per `PIPELINE.md` sub-sprint close-out invariant (added by studio-framework PR #12, 2026-04-20):

**S17.1 is NOT closed until `audits/battlebrotts-v2/v2-sprint-17.1.md` lands on `studio-audits/main`.**

Specc produces the audit. Riv does not spawn Ett for S17.2 planning until the audit PR is merged on `studio-audits/main`. No shortcuts, no "close now, audit later."

---

## Review / verify / audit assignments

| Task | Build | Review | Verify | Audit |
|---|---|---|---|---|
| S17.1-001 | Nutts | Boltz | Optic | Specc (sub-sprint audit) |
| S17.1-002 | Nutts | Boltz | Optic | Specc |
| S17.1-003 | Nutts | Boltz | Optic | Specc |
| S17.1-004 | Nutts | Boltz | Optic | Specc |
| S17.1-005 | Nutts | Boltz | Optic | Specc |
| S17.1-006 | Nutts | Boltz | Optic | Specc |

**Sprint audit:** Specc → `audits/battlebrotts-v2/v2-sprint-17.1.md` on `studio-audits/main`.

---

## Exit criteria

- [ ] [S17.1-001] Shop scroll respects OS speed + preserves position on click — PR merged, Playwright regression test present.
- [ ] [S17.1-002] Loadout UI overlap fixed — Shop button always reachable at max inventory.
- [ ] [S17.1-003] Loadout tooltips visible-by-default for critical info — PR merged, visual-snapshot test present.
- [ ] [S17.1-004] First-encounter HUD explainer for energy bar (+ any Gizmo-identified adjacent elements) — PR merged, dismissal persistence verified.
- [ ] [S17.1-005] Random-event popup has skip/decline affordance, pre-commit item-removal preview — PR merged.
- [ ] [S17.1-006] First-run crate popup contextualized OR deferred per Gizmo decision — PR merged, non-first-run behavior unchanged.
- [ ] Optic verification doc: no regressions in Shop / Loadout / Event popup screens.
- [ ] Scope-gate verification: zero diffs across all S17.1 PRs to `godot/combat/**`, `godot/data/**`, `godot/arena/**`, `docs/gdd.md`.
- [ ] Specc audit `audits/battlebrotts-v2/v2-sprint-17.1.md` merged to `studio-audits/main`.

---

## Risks

- **Risk: task interaction S17.1-002 ↔ S17.1-003.** Adding visible-by-default tooltips to Loadout items (S17.1-003) increases per-item vertical space, which could worsen the overlap issue S17.1-002 is fixing.
  **Mitigation:** Gizmo designs these two together. Acceptance criteria for S17.1-003 explicitly coordinate with S17.1-002's max-inventory layout. If sequential, S17.1-002 lands first; if parallel, Boltz reviews the integrated layout before either merges.

- **Risk: first-run persistence infra sprawl (S17.1-004 ↔ S17.1-006).** Both tasks may want "has user seen this before" state. Two separate systems = tech debt.
  **Mitigation:** Gizmo's S17.1-004 spec defines the first-run persistence infra; S17.1-006 reuses it if path (a) is chosen, or references it if path (b) is chosen. One system, two consumers.

- **Risk: S17.1-005 frequency tweak drifts into data/balance.** "Reduce frequency" could be read as a tweak to data config, which borders on `godot/data/**`.
  **Mitigation:** Acceptance criteria explicitly carve out "UX framing only OR minimal frequency tweak with Ett sign-off." Any change to random-event outcome tables, rewards, or probabilities beyond spawn frequency escalates to Ett.

- **Risk: scope creep from "while we're here" Loadout UX ideas.** S17.1-003 touches every Loadout item render path — tempting to also fix drag-and-drop or reorder behavior.
  **Mitigation:** Scope notes on S17.1-003 explicitly exclude drag/drop. Any adjacent finding goes to the carry-forward section below, not into this sub-sprint.

- **Risk: Optic can't regression-test Shop/Loadout/Event without test fixtures for max-inventory / first-run / first-crate states.** These states may not exist in the test harness.
  **Mitigation:** Gizmo's per-task spec calls out any needed test fixture. Nutts adds fixture alongside the fix if missing. If fixture work explodes, Ett carry-forwards and Optic verifies what's testable.

---

## Open questions / 🟡 surfaced

- **🟡 S17.1-006 path selection (a vs b) is a Gizmo call with UX design implications.** Path (a) contextualize is smaller scope; path (b) defer is cleaner onboarding but requires wiring a new gate. If Gizmo lands on (b) and the gate proves non-trivial, escalate to Ett for a carry-forward decision rather than ballooning the task.

- **🟢 S17.1-005 frequency question.** The playtest complaint reads as UX framing ("chaotic," "annoying"), not necessarily frequency. Gizmo's first pass should evaluate whether UX framing alone (skip affordance + pre-commit preview) resolves the complaint. Frequency tweak should be the second lever, not the first.

---

## Carry-forward backlog (populated during sub-sprint)

*(Entries added by Ett/Riv as S17.1 surfaces non-scope findings. Typical pattern: Nutts or Gizmo hits a "would also fix X" thought, files a carry-forward instead of expanding scope.)*

---

## References

- Arc brief: [`sprints/sprint-17.md`](./sprint-17.md) §"S17.1 — Shop/Loadout/Event UX fixes", §"🛑 SCOPE GATE", §"Sacred", §"Escalation triggers".
- Playtest source of truth: HCD-authored 2026-04-18 playtest notes, captured at workspace `memory/2026-04-20.md` §18:23. Citations above are quoted from the arc brief's Citations table, which transcribes the playtest notes verbatim (or near-verbatim) per §"Citations (playtest → backlog)".
- Backlog issues: [#103](https://github.com/brott-studio/battlebrotts-v2/issues/103), [#104](https://github.com/brott-studio/battlebrotts-v2/issues/104), [#105](https://github.com/brott-studio/battlebrotts-v2/issues/105), [#106](https://github.com/brott-studio/battlebrotts-v2/issues/106), [#107](https://github.com/brott-studio/battlebrotts-v2/issues/107).
- UX design reference: `docs/kb/ux-vision.md` (Eve from WALL-E vision, anti-patterns, checklist).
- Precedent sub-sprint plan format: [`sprints/sprint-16.3.md`](./sprint-16.3.md).
- Framework: `studio-framework/PIPELINE.md` §"Sub-sprint close-out invariant" (hard audit gate).

---

**Plan authored by Ett, 2026-04-20. Next step: Riv spawns Gizmo on [S17.1-001] (start sequentially; S17.1-002 and S17.1-003 can be staged in parallel once S17.1-002 layout baseline is set).**
