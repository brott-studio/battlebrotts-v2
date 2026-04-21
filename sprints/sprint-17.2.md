# Sprint 17.2 — Scout feel + wall-stuck bug triage

**PM:** Ett
**Status:** Planning (iteration 2 of S17 — scout feel + wall-stuck)
**Sprint type:** Sub-sprint (movement feel polish + bug triage)
**Parent arc:** [`sprints/sprint-17.md`](./sprint-17.md) — see §"S17.2 — Scout feel + wall-stuck bug triage"

---

## SCOPE GATE — READ FIRST

This sub-sprint is a **movement-feel + bug-triage** slice. Scope-gate state from the arc brief is unchanged:

- No balance changes to `godot/data/**` (`chassis_data.gd`, `weapon_data.gd`, `armor_data.gd`, etc.). No scalar tweaks to Scout speed/accel/decel/turn_speed, no weapon or HP changes.
- No edits to `docs/gdd.md`.
- No changes to `godot/arena/**`.
- `godot/combat/**` is **scope-exception territory** for this sub-sprint only:
  - The wall-stuck task (S17.2-001 / S17.2-002) almost certainly roots in `combat_sim.gd` or `brott_state.gd`; the arc brief explicitly permits this.
  - The scout-feel task (S17.2-003) is a Gizmo-sign-off combat-sim change (design landed on main at `docs/design/s17.2-scout-feel.md`).
- This is still a polish/feel arc. "While we're here, let's also refactor X" thoughts go to carry-forward, not into S17.2.

Arc scope streak (S15.2 → S17.1): clean. Hold the line.

Full gate/sacred-paths/escalation reference: `sprints/sprint-17.md` §"SCOPE GATE", §"Sacred", §"Escalation triggers".

---

## Goal (condensed from arc brief §S17.2)

Fix the two immersion-breaking movement complaints from the 2026-04-18 playtest:

1. Scouts read as "mice running" not "weighty brotts" — jerky instantaneous direction flips break the lifelike feel.
2. Bots get stuck on walls mid-match; occasionally late-match both bots stop moving and only shoot.

Gizmo has landed the scout-feel design (`docs/design/s17.2-scout-feel.md`, 384 lines) on main. That spec frames the scout-feel task. The wall-stuck bug has no filed design doc yet — the first S17.2 task is a Gizmo-led root-cause investigation.

**Arc acceptance bar for S17.2 (from arc brief):**
- Wall-stuck bug fixed OR quarantined with filed carry-forward issue plus documented root cause.
- Scout "mice to brott" feel shift confirmed by Optic and (ideally) HCD spot-check before arc close.
- Zero combat-balance number changes in `godot/data/**`.

---

## Task list

S17.2 contains **4 tasks**. Task IDs match the arc brief plus a new small task for debug overlay.

| ID | Title | Complexity | Dependencies | AC count |
|---|---|---|---|---|
| S17.2-001 | Wall-stuck bug — root-cause investigation | M | none | 4 |
| S17.2-002 | Wall-stuck minimal patch | S–M | S17.2-001 | 4 |
| S17.2-003 | Scout movement feel pass (smoothing + angular cap) | M | S17.2-002 | 6 behavioral + 3 automated |
| S17.2-004 | Dev-only velocity debug overlay | S | S17.2-003 | 2 |

**Ordering:** S17.2-001 → S17.2-002 → S17.2-003 → S17.2-004. See §"Decisions for HCD" for the ordering rationale.

**Playtest drop:** scheduled between S17.2-003 (Nutts implement) and the Specc audit — see §"Playtest plan".

---

## Per-task briefs

### [S17.2-001] Wall-stuck bug — root-cause investigation

- **Summary:** Investigate the playtest-reported wall-stuck bug. Produce a root-cause KB note before any code patch is written. Also evaluate whether the "last 5 shots, both bots stop moving" complaint shares this root cause.
- **Citation — playtest (2026-04-18, arc brief §S17.2 Citations):**
  - "occasionally bots stop moving... it's always next to a wall, i think they get stuck on walls? happened again, sometimes only to one bot - gets stuck on a wall and can't move"
  - "Toward the last 5 or so shots, both bots stopped moving and just shot at each other - is this a bug?"
- **Issue:** no filed GitHub issue at plan time. Nutts (or Boltz) files one during investigation; use the body of the KB note as the issue description.
- **Design doc:** Gizmo produces a short diagnosis note at `docs/design/s17.2-wall-stuck-triage.md`. Does not need to be long — a one-page root-cause + proposed minimal patch strategy is enough.
- **Acceptance criteria:**
  - Reproducible repro case identified (seed + scenario that produces a wall-stuck bot within N ticks), captured as a test fixture if feasible.
  - Root cause named precisely: which code path, which state, which condition sets up the stuck state.
  - Evaluation of the "last 5 shots stop moving" complaint: is it the same root cause, a sibling issue, or a separate bug? Conclusion documented.
  - Gizmo signs off on a proposed minimal-patch strategy before S17.2-002 begins.
- **Scope notes:**
  - Investigation may touch `godot/combat/**` — explicit scope-exception per arc brief and per Gizmo scout-feel spec §7.
  - No `godot/data/**` edits during investigation.
  - If root cause turns out to be in `godot/arena/**` (navmesh), escalate to Ett: arena changes are sacred and need Riv and HCD visibility.
- **Expected files touched (investigation only — no fixes land in this task):** `docs/design/s17.2-wall-stuck-triage.md` (new), `docs/kb/` (optional KB entry), possibly `godot/tests/` (new repro fixture).

### [S17.2-002] Wall-stuck minimal patch

- **Summary:** Land the smallest, safest change that unblocks the stuck bot, following the S17.2-001 root-cause diagnosis. No pathfinding refactor; anything larger than a minimal patch becomes a carry-forward.
- **Citation:** inherits from S17.2-001.
- **Issue:** whatever issue S17.2-001 files.
- **Design doc:** `docs/design/s17.2-wall-stuck-triage.md` (from S17.2-001). Patch strategy section of that doc is the spec.
- **Acceptance criteria:**
  - Repro case from S17.2-001 no longer reproduces. Verified by the fixture test (if one was added) or by a Playwright/headless-combat run with the identified seed/scenario.
  - No new test regressions. Full suite green.
  - Unstick nudge write-site exposes a `bypass_smoothing=true` opt-out path (or equivalent) so that S17.2-003 can route all other position writes through the new velocity-smoothing helper without worsening wall-stuck. See scout-feel spec §7.
  - Patch is additive/minimal. If diagnosis reveals the fix needs a broader rework (e.g., navmesh rebuild, pathfinding replan), file a carry-forward issue and ship the minimal unblock in this task.
- **Scope notes:**
  - `godot/combat/**` touches permitted (scope-exception).
  - No `godot/data/**`, no `docs/gdd.md`, no `godot/arena/**` without Ett/HCD escalation.
  - If patch drifts larger than the Gizmo-approved minimal strategy, stop and escalate.
- **Expected files touched:** `godot/combat/combat_sim.gd` (most likely the `_check_and_handle_stuck` / unstick path), possibly `godot/combat/brott_state.gd`, new or updated test in `godot/tests/`.

### [S17.2-003] Scout movement feel pass — velocity smoothing + angular-velocity cap

- **Summary:** Implement the Gizmo-designed velocity-smoothing layer in `combat_sim.gd`, add real `velocity: Vector2` and `max_angular_velocity` state in `brott_state.gd`, and route combat-movement position writes through a new `_smooth_velocity` helper. Per-chassis angular caps applied (see decision D4 for scope). Tuning pass expected post-implementation.
- **Citation — playtest:**
  - "scout still feels a little bit too fast to follow... makes it feel like I'm watching mice run around rather than weighty brotts"
  - "the way scout moves is so crazy fast, ruins the robot feel"
  - "its movements are very jerky too"
- **Issue:** no separate issue needed; design doc is the source of truth.
- **Design doc:** `docs/design/s17.2-scout-feel.md` (landed on main, 384 lines). Source of truth for spec, proposed constants, acceptance criteria, open questions, and landmines.
- **Acceptance criteria (from spec §8, summarized — full text in design doc):**
  - AC-1 visible-arc: Scout takes >= 3 ticks (300 ms) to complete a 180° turn under commit-phase transition. Verified by sampling `b.velocity.angle()` per tick.
  - AC-2 no straight-line slowdown: peak speed reached in same tick-count +/- 1 as today.
  - AC-3 pursuit still closes: chase-scenario regression <= +15% tick count.
  - AC-4 phase-transition damping visible: current_speed dips >= 35% for 2 ticks on hard reversals.
  - AC-5 no teleport: 3-tick position delta satisfies magnitude bound in spec.
  - AC-6 HCD subjective: Optic visual-diff passes; feel reads as "brott" not "mouse".
  - AC-T1: unit test for `_smooth_velocity` angular bound.
  - AC-T2: replay determinism (fixed RNG seed, byte-identical logs).
  - AC-T3: full existing test suite passes unchanged — no quarantining.
- **Scope notes:**
  - Touches `godot/combat/combat_sim.gd` and `godot/combat/brott_state.gd` — scope-exception per arc brief and Gizmo spec §0.
  - No `godot/data/chassis_data.gd` edit. Tunable constants live in `combat_sim.gd`, not data files. This is a deliberate design decision to preserve the `godot/data/**` scope gate.
  - `docs/gdd.md` untouched. Scout's agility archetype identity preserved (highest speed, accel, and now angular velocity).
  - Unstick nudge write-site must use the `bypass_smoothing` opt-out landed in S17.2-002 (hence the ordering dependency).
- **Expected files touched:** `godot/combat/combat_sim.gd` (~90 LoC: helper + 4 constants + callsite migration), `godot/combat/brott_state.gd` (~15 LoC: activate `velocity`, add `max_angular_velocity`, add `reversal_damping_timer`, set in `setup()`), `godot/tests/test_s17_2_scout_feel.gd` (new, ~60 LoC).

### [S17.2-004] Dev-only velocity debug overlay

- **Summary:** Add a dev-flag-gated debug draw in the arena renderer that, for each bot, draws a short vector for `b.velocity` and a second vector for this tick's `desired`. Makes rotation-lag and smoothing behavior visually inspectable. Non-blocking; ships only if S17.2-003 lands with time to spare.
- **Citation:** Gizmo spec §9 "Debug overlay (recommended, non-blocking)".
- **Design doc:** `docs/design/s17.2-scout-feel.md` §9 — one paragraph is the full spec.
- **Acceptance criteria:**
  - Dev-only toggle (compile flag, env var, or hidden hotkey — Nutts picks the smallest mechanism). Off by default in shipping builds.
  - When enabled, each bot draws two short vectors per frame: current `b.velocity` and the tick's `desired` vector, distinguishable by color.
- **Scope notes:**
  - Touches `godot/arena/arena_renderer.gd` (or equivalent) — this is a `godot/arena/**` touch but is *additive and dev-only*; no gameplay change. Flag this as a minor scope-exception and proceed. If Nutts judges it breaks the arena scope gate, defer to S17.3 carry-forward.
  - No balance, no data, no GDD.
- **Expected files touched:** `godot/arena/arena_renderer.gd` (+20 LoC, dev-flag-gated), possibly a new `project.godot` dev flag.

---

## Open decisions for HCD

These are the Gizmo-surfaced open questions from `docs/design/s17.2-scout-feel.md` §11, plus ordering. Ett's recommendation is given for each; HCD can override.

- **D1 — Task numbering.** Gizmo spec assumed `[S17.2-003]` for the scout-feel pass. Confirmed: S17.2-003 is scout-feel in this plan. Wall-stuck triage is `[S17.2-001]` (investigation) and `[S17.2-002]` (patch). Debug overlay is `[S17.2-004]`. Matches arc brief §S17.2 numbering.
- **D2 — Ordering with wall-stuck.** Scout-feel (S17.2-003) lands AFTER wall-stuck (S17.2-001 + S17.2-002) because the new `_smooth_velocity` helper changes every combat-movement position write and the unstick nudge needs a `bypass_smoothing=true` opt-out. Decided: sequential ordering, wall-stuck first. Gizmo spec §7 confirms.
- **D3 — Post-implementation HCD feel-check playtest.** Gizmo recommends a 5-minute HCD feel-check build between Nutts-implements-S17.2-003 and Specc-audit. Ett recommendation: schedule in S17.2 as a 5-minute gated check, not a full playtest. See §"Playtest plan". Does not push S17.3 back; it's a same-day check not a multi-hour session. Surface to HCD for approval.
- **D4 — Brawler/Fortress scope.** Gizmo spec proposes extending angular-velocity caps to all three chassis (Scout 540°/s, Brawler 270°/s, Fortress 150°/s). The helper is generic; the per-chassis setup step in `brott_state.gd::setup()` costs ~3 lines. Ett recommendation: apply to all three this sprint. Scout is the only chassis the playtest flagged, but applying only to Scout would create a motion-model inconsistency across chassis, and the Brawler/Fortress caps are high enough that typical gameplay won't feel different. HCD can veto if "scout-only" is preferred.
- **D5 — Debug overlay.** Ett recommendation: keep S17.2-004 as a small in-sprint task (complexity S). The overlay makes S17.2-003 tuning and S17.2-001 wall-stuck diagnosis both easier. If S17.2-003 runs long, S17.2-004 carries forward to S17.3 with no loss.

HCD, please confirm or redirect D3, D4, D5 before Nutts begins. D1 and D2 are structural and proceed unless explicitly challenged.

---

## Playtest plan

Gizmo spec §9 and decision D3 above: a 5-minute HCD feel-check between Nutts-implements-S17.2-003 and the Specc audit close.

- **What:** Nutts produces a playable build with S17.2-003 landed. HCD spends ~5 minutes in combat scenarios that exercise phase transitions (Scout vs Brawler, commit/recover cycles).
- **Question for HCD:** does Scout now read as "brott" not "mouse"? Single-question, subjective.
- **If pass:** Specc proceeds to sub-sprint audit. Tuning complete.
- **If fail:** Gizmo tuning pass (adjust `MAX_ANGULAR_VELOCITY_SCOUT_DEG`, `REVERSAL_DAMPING_FACTOR`, `REVERSAL_DAMPING_TICKS` per spec §9). Re-check. All tunables already in `combat_sim.gd`, so no re-design needed.
- **Not a full playtest session.** A full arc-close playtest is the arc acceptance bar (arc brief), scheduled at end of S17. This is a 5-minute subjective check only.
- **Delivery:** Riv (or The Bott) packages the playable build per standard playtest-ready handoff pattern. Subagents do not ping HCD directly.

---

## Pipeline flow

Standard per arc brief §"Pipeline flow": Gizmo design → Nutts build → Boltz review → Optic verify → Specc audit → Gizmo validate → Ett continuation.

- **Gizmo-heavy tasks this sprint:** S17.2-001 (root-cause investigation is pure diagnosis work) and S17.2-003 (design already landed, but any tuning-pass decisions route through Gizmo).
- **Nutts handles S17.2-002 implementation once Gizmo signs off on the minimal-patch strategy.** Do not start S17.2-002 without Gizmo sign-off.
- **S17.2-004 is a Nutts solo task** once S17.2-003 is building — no Gizmo design needed beyond the spec paragraph.

---

## Audit gate (HARD RULE)

Per `PIPELINE.md` sub-sprint close-out invariant (added by studio-framework PR #12, 2026-04-20):

**S17.2 is NOT closed until `audits/battlebrotts-v2/v2-sprint-17.2.md` lands on `studio-audits/main`.**

Specc produces the audit. Riv does not spawn Ett for S17.3 planning until the audit PR is merged on `studio-audits/main`. No shortcuts, no "close now, audit later."

---

## Review / verify / audit assignments

| Task | Build | Review | Verify | Audit |
|---|---|---|---|---|
| S17.2-001 | Gizmo (investigation) | Ett (diagnosis review) | N/A (no code) | Specc (sub-sprint audit rollup) |
| S17.2-002 | Nutts | Boltz | Optic | Specc |
| S17.2-003 | Nutts | Boltz | Optic | Specc |
| S17.2-004 | Nutts | Boltz | Optic (visual confirm) | Specc |

**Sprint audit:** Specc → `audits/battlebrotts-v2/v2-sprint-17.2.md` on `studio-audits/main`.

---

## S17.1 carry-forwards — triage

Riv surfaced three S17.1 residuals for triage. Decisions:

- **`_lose_trick_item` ownership check (S17.1-005 Boltz note).** Triage: **push to S17.3.** Not in scope of S17.2 movement/feel arc. Small enough to land as a one-off cleanup in S17.3 alongside BrottBrain work, or as a standalone Patch-driven PR if Riv prefers. Not urgent — no playtest issue traces to this.
- **"a Overclock" grammar nit.** Triage: **push to S17.3** (or land as a zero-risk Patch PR at any time — The Bott can ship this autonomously per the pre-approved-housekeeping rule, does not need to be in any sub-sprint plan). Trivial.
- **Live-scene ESC e2e test.** Triage: **keep visible but not in S17.2.** Push to S17.3. S17.2 is movement-layer work; e2e test plumbing belongs with the BrottBrain UI sprint where live-scene interactions are already in scope.

Net: all three push to S17.3 (or land via out-of-band Patch for the grammar nit). None block S17.2.

---

## Out of scope for S17.2 / deferrals to S17.3

- BrottBrain UI / drag / delete / card library — S17.3.
- Stale PR #76, #77 triage — S17.3.
- Any combat-balance number change (weapon damage, HP, chassis speed/accel/decel values) — out of arc entirely.
- Pathfinding or navmesh refactor — if wall-stuck diagnosis reveals a broader issue, file carry-forward; do NOT execute in S17.2.
- Full playtest session — arc-close bar, scheduled at end of S17.
- Sprite-rotation-vs-motion-direction sync (Gizmo spec §2.5) — not in spec; if Optic flags it post-S17.2, carry-forward to a future feel arc.

---

## Exit criteria

- [ ] [S17.2-001] Wall-stuck root-cause diagnosis landed as `docs/design/s17.2-wall-stuck-triage.md`. Repro scenario documented. Gizmo signs off on minimal-patch strategy.
- [ ] [S17.2-002] Wall-stuck minimal patch merged. Repro no longer reproduces. Unstick-nudge write-site exposes `bypass_smoothing` opt-out. Full test suite green.
- [ ] [S17.2-003] Scout-feel velocity smoothing merged per `docs/design/s17.2-scout-feel.md`. All 6 behavioral + 3 automated acceptance criteria met. 5-minute HCD feel-check passed (or tuning pass landed and re-check passed).
- [ ] [S17.2-004] Dev-only velocity debug overlay landed (or carry-forwarded with explicit Ett decision).
- [ ] Scope-gate verification: zero diffs across all S17.2 PRs to `godot/data/**`, `docs/gdd.md`. `godot/combat/**` diffs justified by scope-exceptions above. `godot/arena/**` touches limited to S17.2-004 additive dev-only overlay (or none).
- [ ] Specc audit `audits/battlebrotts-v2/v2-sprint-17.2.md` merged to `studio-audits/main`.

---

## Risks

- **Risk: wall-stuck root-cause is in `godot/arena/**` (navmesh).** If the bug is a navmesh edge case rather than a combat-sim/brott-state bug, the patch would touch sacred `godot/arena/**` territory.
  **Mitigation:** escalation trigger. S17.2-001 surfaces the file location during diagnosis. If it's `godot/arena/**`, Ett escalates to Riv, Riv to HCD for scope-exception approval before S17.2-002 begins.
- **Risk: scout-feel smoothing makes wall-stuck worse.** Per Gizmo spec §7, routing the unstick nudge through `_smooth_velocity` can add 100–300 ms of "rotate out of wall direction" lag, potentially making the stuck-bot take longer to escape.
  **Mitigation:** hard ordering — S17.2-002 lands `bypass_smoothing` opt-out first; S17.2-003 uses it for the unstick write-site.
- **Risk: feel tuning takes more than one pass.** Gizmo spec §9 assumes one tuning pass; subjective feel often needs iteration.
  **Mitigation:** all tunables in `combat_sim.gd` as named constants. Each tuning iteration is a single-file PR, not a re-design. Budget up to 2 tuning passes before escalating.
- **Risk: replay determinism breaks.** The new vector-math in `_smooth_velocity` introduces float operations not present in the current scalar path. Different float ordering can diverge JSON replay logs.
  **Mitigation:** AC-T2 in the spec is explicit. Nutts runs a replay-determinism test (two runs, fixed seed, byte-diff) before opening the PR. If divergence appears, Gizmo audits the math order.
- **Risk: Brawler/Fortress angular caps (if D4 applies to all three) change pursuit patterns subtly.** Brawler at 270°/s may feel different in `LaunchDrag` scenarios.
  **Mitigation:** Optic visual-diff covers Brawler and Fortress reference scenarios too, not just Scout. If regressions appear, fall back to Scout-only.
- **Risk: scope creep on S17.2-001.** Diagnosis can expand into "let's also fix X, Y, Z."
  **Mitigation:** Gizmo diagnosis note is capped at one page. Anything beyond minimal patch is a carry-forward, not this sprint.

---

## Open questions — surfaced

- **🟡 D3 playtest scheduling.** HCD approval needed for the 5-minute feel-check in-sprint. If HCD declines, the check becomes Optic-only (visual diff) and the audit proceeds.
- **🟡 D4 chassis scope.** HCD preference: all three chassis or Scout-only. Ett recommends all three; implementation cost is negligible.
- **🟢 D5 debug overlay.** Low-stakes. Ett recommends include; easy to carry-forward if time-pressured.

---

## References

- Arc brief: [`sprints/sprint-17.md`](./sprint-17.md) §"S17.2 — Scout feel + wall-stuck bug triage", §"SCOPE GATE", §"Sacred", §"Escalation triggers".
- Scout-feel design doc: [`docs/design/s17.2-scout-feel.md`](../docs/design/s17.2-scout-feel.md) (Gizmo, landed on main).
- S17.1 precedent plan: [`sprints/sprint-17.1.md`](./sprint-17.1.md).
- Playtest source of truth: HCD-authored 2026-04-18 playtest notes, captured at workspace `memory/2026-04-20.md` §18:23. Citations above are from the arc brief's Citations table.
- UX design reference: `docs/kb/ux-vision.md` (Eve from WALL-E vision).
- Framework: `studio-framework/PIPELINE.md` §"Sub-sprint close-out invariant" (hard audit gate).

---

**Plan authored by Ett, 2026-04-21. Hard HOLD: HCD reviews this plan before Nutts begins S17.2-001. Riv does not spawn implementation subagents until HCD greenlight.**
