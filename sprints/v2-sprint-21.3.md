# Sprint 21.3 — Arena onboarding: in-arena HUD overlays (Arc B)

**Status:** Planning
**Arc:** Arc B — Content & Feel
**Sub-sprint:** 3 of (open fuse, arc continues per HCD ruling 2026-04-24)
**Planned by:** Ett
**Prior audit:** [`studio-audits/audits/battlebrotts-v2/v2-sprint-21.2.md`](https://github.com/brott-studio/studio-audits/blob/main/audits/battlebrotts-v2/v2-sprint-21.2.md) — **B+** (blob SHA `e506ddf`)

> **Note:** Phase 3 build loop starts in a separate Riv-orchestrated spawn after this plan PR lands. This document is **planning only**.

---

## DECISION

**continue** — pre-decided by HCD (2026-04-24 00:40 UTC) and ratified against Gizmo's arc-intent verdict `progressing`. S21.2 closed B+ with the generic FE_COPY scaffold landed (PR #244 merged, commit `179f660`), but two spec invariants on issue #107 were missed on implementation: overlays anchored to **screens**, not HUD elements, and fired on **screen entry**, not **arena entry**. S21.3 delivers the real #107 payload against those invariants and hardens the invariant class structurally so the same class of miss cannot recur.

**REASON:** Arc-intent = `progressing`; #107 is explicit arc carry-forward (issue [#245](https://github.com/brott-studio/battlebrotts-v2/issues/245)); audit §7 flagged the anchor + trigger invariants as the primary grade-depressors on S21.2. Single-scope, no fuse pressure.

---

## Audit Verification Gate (Step 0)

**Status:** ✅ PASS.
- Prior audit file present: `audits/battlebrotts-v2/v2-sprint-21.2.md` on `studio-audits/main`.
- Verification SHA: `e506ddf572de9c25ecb386d55df8794aa0b48d5a`.
- Step 0 satisfied. Proceeding to Step B (plan) — Step A continuation pre-decided by HCD ruling.

---

## Arc-intent verdict (from Gizmo, 2026-04-24 00:16 UTC)

**Progressing.** S21.2 landed the FE_COPY scaffold and per-screen overlays as an additive bonus, but the real #107 payload — in-arena HUD element sequencing — remains unbuilt. Gizmo's framing (HCD-ratified 2026-04-24 00:40 UTC): four fixed-order keys, anchored to four arena HUD element nodes, fired on **arena entry** (not screen entry), one-per-entry, ~12s budget, 0.25× sim slowdown.

---

## Scope statement

S21.3 delivers the in-arena HUD-element onboarding sequence: four first-encounter overlays anchored to real arena HUD elements, sequenced across arena entries, with the S17.1-004 `energy_explainer` save state carried forward (already-seen overlays do not re-fire).

### Fixed key order (4 keys, no additions, no reordering)

| # | Key | Anchor target (arena HUD element node) | Copy origin |
|---|---|---|---|
| 1 | `energy_explainer` | Energy bar / legend node (`UI/EnergyLegend` or canonical energy HUD node — Nutts resolves exact node path) | S17.1-004 (reuse; save-carryforward required) |
| 2 | `combatants_explainer` | Combatants panel — the `UI/PlayerInfo` + `UI/EnemyInfo` pair or their common parent panel | `new this sprint` |
| 3 | `time_explainer` | `UI/TimeLabel` | `new this sprint` |
| 4 | `concede_explainer` | Concede button node (Nutts resolves — if absent, **file issue, do not add**; see Out-of-Scope #2) | `new this sprint` |

### Hard invariants (structural enforcement below)

1. **Trigger invariant:** fires on **arena entry**, not screen entry. ("Arena entry" = the per-match hook in `main.gd` that triggers when a fight begins, not screen show/enter.)
2. **Anchor invariant:** each overlay's `anchor_target` is a node reference to the HUD element itself, **not** a screen / canvas layer / root container. ▲ pointer must visibly point from the overlay card to the anchor element.
3. **Placement invariant:** top-center placement disallowed. Overlay card is positioned relative to the anchor (offset so ▲ lands on anchor).
4. **Sequencing invariant:** one overlay per arena entry, maximum. Already-seen keys are skipped; advance to the next unseen key in fixed order.
5. **Save-carryforward invariant:** if `FirstRunState.has_seen("energy_explainer")` returns true from an S17.1-era save, `energy_explainer` is NOT re-shown and sequencing begins at `combatants_explainer`.

### Timing

- ~12 s budget per overlay (auto-dismiss on budget expiry or click).
- 0.25× sim slowdown while overlay is visible; restore to prior speed on dismiss.
- No overlap: if a prior overlay is still visible when a new arena entry happens (shouldn't — see sequencing invariant), the new one waits.

### Reuse

Extend the S21.2 `FE_COPY` scaffold in `godot/main.gd` (GameMainScript). Do NOT rebuild the scaffold. FE_COPY currently has 4 keys (per `test_s21_2_003_first_encounter_overlays.gd:61`); this sprint replaces or augments them to match the fixed order above. Key-name alignment with S17.1-004 (`energy_explainer`) is a hard requirement for save-carryforward.

---

## Task breakdown

Task IDs `[S21.3-NNN]`. Single-scope, single-PR preferred unless build-size demands a split.

### [S21.3-001] *(Nutts — build + tests; `new this sprint`)* Arena onboarding sequencer

**Deliverable:** one PR on `battlebrotts-v2` implementing the four overlays anchored to arena HUD elements, arena-entry-triggered, sequenced, budget + slowdown wired, save-carryforward intact.

**Implementation constraints:**
- Extend `godot/main.gd` `FE_COPY` and `_maybe_spawn_first_encounter(key)` (the S21.2 generic scaffold). Do NOT fork a new module.
- Add/confirm one arena-entry hook point in `main.gd` (the per-match entry, not per-screen). Attach the sequencer there.
- `anchor_target` field on each FE_COPY entry is a **NodePath** (or equivalent Node reference) to one of the four HUD element nodes listed above. Must resolve to an existing node, not a screen container.
- ▲ pointer: visible UI element on the overlay card that visually anchors to the HUD element. Presence is asserted by test (see below).
- `energy_explainer` reuses the S17.1-004 save key exactly. The save-has-seen check must run before the sequencer decides which key to show.

**Acceptance criteria (explicit, test-shaped — Optic will execute):**

1. **Anchor node-type assertion (one per key):** for each of the 4 keys, a test instantiates the overlay and asserts `overlay.anchor_target` is a reference to the expected HUD element node (energy bar / combatants panel / time label / concede button) — **not** a `CanvasLayer`, not a screen root, not `self`, not the arena viewport. Test shape:
   ```gdscript
   var overlay = GameMainScript._spawn_first_encounter("energy_explainer")
   assert_not_null(overlay.anchor_target, "energy_explainer has anchor_target")
   assert_true(overlay.anchor_target is Control, "anchor_target is Control node")
   assert_eq(overlay.anchor_target.name, "EnergyLegend", "anchor_target is energy HUD element, not screen")
   assert_false(overlay.anchor_target is CanvasLayer, "anchor_target is not a canvas layer")
   ```
   Apply the same shape (`name` + type asserts) for `combatants_explainer`, `time_explainer`, `concede_explainer` against their respective HUD element nodes.
2. **Sequencing order assertion:** with a fresh `FirstRunState` (no keys seen), simulate 4 arena entries; assert the overlays shown are in order `[energy_explainer, combatants_explainer, time_explainer, concede_explainer]` and exactly 4 distinct overlays were shown.
3. **One-per-entry invariant:** simulate one arena entry with no keys seen; assert exactly one overlay spawns (not two, not a queue).
4. **Save-carryforward assertion:** pre-seed `FirstRunState.mark_seen("energy_explainer")`; simulate first arena entry; assert the overlay shown is `combatants_explainer`, NOT `energy_explainer`.
5. **▲-pointer presence assertion:** for each key's overlay, assert the overlay has a visible pointer child node (by name convention, e.g., `AnchorArrow` / `Pointer`, or a typed predicate — Nutts picks a stable test handle and documents it in the test file).
6. **Trigger assertion (arena-entry, not screen-entry):** assert that navigating between non-arena screens does NOT spawn any of the 4 overlays. Only the arena-entry hook does.
7. **Placement invariant assertion:** for each key, assert the overlay's on-screen position is computed relative to its anchor_target (not pinned top-center). Shape: `assert_ne(overlay.position.y, 0)` plus an assertion that the overlay's rect intersects a region adjacent to the anchor's global rect.

All seven assertion classes must be present as GdUnit-style tests under `godot/tests/test_s21_3_arena_onboarding.gd` (or equivalent). Merging without all seven present is a review-reject.

**Size:** L. **Dependency:** S21.2's FE_COPY scaffold on `main` (present — commit `179f660`).

---

## Structural invariant enforcement (the S21.2 corrective)

S21.2 dropped to B+ because the anchor + trigger invariants lived as prose-only acceptance criteria and got missed on implementation. S21.3 hardens the same class of invariant across three surfaces:

### 1. Optic acceptance criteria — explicit test shape (not prose)

Optic MUST assert `anchor_target` node-type for each of the 4 overlays. Test shape is spelled out in [S21.3-001] acceptance criterion #1 above (node reference type + name assertion + negative assertions against `CanvasLayer` / screen root). Optic's verification report must include the raw assertion output for all four keys. "Optic will verify" is **not** sufficient — the test must exist in the test file at merge time and must run green in CI.

### 2. Boltz review checklist — verbatim line items

Boltz MUST apply the following checklist to the S21.3 PR before approving. Each item is a reject condition if violated:

- [ ] PR touches `godot/main.gd` FE_COPY registry and exactly 4 keys are present in fixed order: `energy_explainer`, `combatants_explainer`, `time_explainer`, `concede_explainer`.
- [ ] For each of the 4 keys, the `anchor_target` value in FE_COPY (or equivalent field) resolves to one of the four arena HUD element nodes — NOT a screen container, canvas layer, or viewport root. Diff-verify: grep for the FE_COPY block and confirm each anchor is a node path pointing into the arena HUD.
- [ ] Arena-entry hook is wired on the per-match arena entry point, NOT on `_ready` of a screen or a screen `show`/`enter` callback.
- [ ] Test file `test_s21_3_arena_onboarding.gd` (or equivalent) contains all 7 assertion classes from [S21.3-001]: anchor node-type (×4 keys), sequencing order, one-per-entry, save-carryforward, ▲-pointer presence, trigger-is-arena-entry, placement-not-top-center.
- [ ] `energy_explainer` key unchanged from S17.1-004 (save-carryforward): no rename, no namespace change.
- [ ] PR body has the "Invariants verified" section filled out (see template below) with all 4 invariant checkboxes ticked and evidence provided.

**Boltz reject protocol:** if any checklist item fails, `REQUEST CHANGES` with the specific item cited. Do NOT approve on "will fix follow-up" — these are the corrective items from S21.2.

### 3. PR body template (Nutts must use verbatim)

Nutts MUST include this section in the S21.3 PR description. Unfilled or partially-filled = Boltz reject.

```markdown
## Invariants verified

This PR implements the real #107 payload. The following invariants were
missed on S21.2 (prose-only acceptance criteria) and are now verified
both by test and by explicit review:

- [ ] **Anchor invariant** — each of the 4 overlays' `anchor_target` is a
  reference to an arena HUD element node (energy bar / combatants panel /
  time label / concede button), NOT a screen / canvas layer / viewport.
  Evidence: `test_s21_3_arena_onboarding.gd::test_anchor_node_type_*` — 4
  assertions, one per key.

- [ ] **Trigger invariant** — overlays fire on **arena entry**, not
  screen entry. Hook is on the per-match arena entry point in
  `main.gd`.
  Evidence: `test_s21_3_arena_onboarding.gd::test_trigger_arena_entry_only`.

- [ ] **Sequencing invariant** — fixed order: energy → combatants → time
  → concede. One per arena entry. Already-seen skipped.
  Evidence: `test_s21_3_arena_onboarding.gd::test_sequencing_order` +
  `::test_one_per_entry`.

- [ ] **Save-carryforward invariant** — S17.1-004 `energy_explainer`
  save state honored. If already seen, sequencing starts at
  `combatants_explainer`.
  Evidence: `test_s21_3_arena_onboarding.gd::test_save_carryforward`.

## Placement + pointer

- [ ] ▲ pointer visibly anchors each overlay card to its HUD element.
- [ ] No top-center placement (placement is computed relative to anchor).
- Evidence: `test_s21_3_arena_onboarding.gd::test_pointer_presence` +
  `::test_placement_not_top_center`.

## Scope

- [ ] No audio work.
- [ ] No new HUD elements added (beyond the 4 already in arena).
- [ ] S21.2 per-screen overlays untouched (additive bonus preserved).
- [ ] #248 (test brittleness) NOT bundled — single scope.
```

---

## Model assignments

Per HCD standing ruling 2026-04-23 22:49 UTC (tracked at [brott-studio/studio-framework#57](https://github.com/brott-studio/studio-framework/issues/57)):

| Agent | Model |
|---|---|
| Nutts | `github-copilot/claude-sonnet-4.6` |
| Boltz | `github-copilot/claude-opus-4.7` |
| Optic | `github-copilot/claude-sonnet-4.6` |
| Specc | `github-copilot/claude-sonnet-4.6` |

Riv's execution-phase spawn prompts must cite these explicitly.

---

## Sprint-level acceptance criteria

- [ ] [S21.3-001] PR merged on `battlebrotts-v2:main` with all 7 test assertion classes present and green in CI.
- [ ] FE_COPY has exactly 4 keys in the fixed order above.
- [ ] All 4 overlays anchor to HUD element nodes (verified by Boltz diff-check + Optic test-output).
- [ ] Arena-entry trigger wired (not screen-entry).
- [ ] `energy_explainer` save-carryforward from S17.1-004 preserved.
- [ ] PR body uses the "Invariants verified" template with all 4 invariants ticked + evidence.
- [ ] Specc audit for S21.3 lands on `studio-audits/main` at `audits/battlebrotts-v2/v2-sprint-21.3.md` before any S21.4 planning PR opens (sub-sprint close-out invariant — structurally enforced by `Audit Gate`).
- [ ] No regressions in existing required checks on `battlebrotts-v2:main`.
- [ ] S21.2 per-screen overlays untouched (additive bonus preserved).

---

## Out of scope (hard restatement — reject if Nutts attempts)

1. 🚧 **No audio work.** Audio is a future-arc concern; this sprint is visual/interaction only.
2. 🚧 **No new HUD elements beyond the 4.** If the concede button does not exist in the current arena, **file a backlog issue, do not add it**. Anchoring to missing elements is a dependency issue; adding elements is out-of-scope creep.
3. 🚧 **No per-screen overlay additions.** S21.2's per-screen overlays (`shop_first_visit`, `brottbrain_first_visit`, `opponent_first_visit`) are preserved as additive bonus. Do NOT modify, remove, or extend them in this sprint.
4. 🚧 **Do NOT bundle #248 (test brittleness).** This is the S21.2 failure-mode the scope discipline rule exists to prevent. One scope, one sub-sprint. #248 is a separate future sub-sprint.
5. 🚧 **Do NOT touch `studio-audits` from this sprint.** Specc writes the S21.3 audit in the normal Phase 6 flow; nothing earlier.

---

## BACKLOG HYGIENE

**Primary issue:** [#245](https://github.com/brott-studio/battlebrotts-v2/issues/245) — HUD element sequencing carry-forward from S21.2.
**Parent issue:** [#107](https://github.com/brott-studio/battlebrotts-v2/issues/107) — in-arena first-encounter overlays (real payload).
**Explicitly deferred:** [#248](https://github.com/brott-studio/battlebrotts-v2/issues/248) — test brittleness (NOT bundled; future sub-sprint).

**Carry-forward from S21.2 audit §7:**
- HUD element sequencing (#107 real payload) → filed as #245 → addressed this sprint ✓
- Test brittleness (#248) → filed → explicitly deferred per scope-discipline ruling ✓

**Result: clean.** The two S21.2 audit carry-forwards are both filed as open issues; #245 is this sprint's primary deliverable and #248 is explicitly deferred per the S21.2-learning out-of-scope rule.

---

## Links

- [#245](https://github.com/brott-studio/battlebrotts-v2/issues/245) — primary (HUD element sequencing carry-forward)
- [#107](https://github.com/brott-studio/battlebrotts-v2/issues/107) — parent (in-arena first-encounter overlays)
- [#248](https://github.com/brott-studio/battlebrotts-v2/issues/248) — deferred (test brittleness; out-of-scope)
- S21.2 audit: [`studio-audits/audits/battlebrotts-v2/v2-sprint-21.2.md`](https://github.com/brott-studio/studio-audits/blob/main/audits/battlebrotts-v2/v2-sprint-21.2.md) (blob `e506ddf`)
- S21.2 merged PR: [#244](https://github.com/brott-studio/battlebrotts-v2/pull/244) (commit `179f660`)
- Model-assignment ruling: [studio-framework#57](https://github.com/brott-studio/studio-framework/issues/57)
- S17.1-004 origin of `energy_explainer` key: `godot/main.gd` `_spawn_energy_explainer` + `godot/ui/first_run_state.gd`
