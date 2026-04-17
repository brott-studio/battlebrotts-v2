# Sprint 15 — Moonwalk Metric Ruling (Design Spec)

**Author:** Gizmo (Game Designer)
**Date:** 2026-04-17
**Sprint:** 15.2
**Status:** RULING — binds S15.2 implementation
**Supersedes:** Open question left by Gizmo's S15.1 verdict ("no design drift, proceed")

## Context

Sprint 15 Iteration 1 closed two moonwalk bypass paths (separation force, unstick nudge) via per-path `backup_distance` clamps in PR #80, dropping `test_away_juke_cap_across_seeds` from 8/100 to 7/100 violations. The residual 7 were traced (Boltz) to a metric artifact: the test samples `to_target` **after** `simulate_tick()`, so when two bots COMMIT-dash through each other and swap positions in a single tick, a pure forward push produces `movement · to_target ≈ −1` in the flipped post-tick frame. The test reads a legitimate forward dash as a 40–100+ px moonwalk. Specc's KB entry (`juke-bypass-movement-caps.md`, S15 update) flagged this as "not fixed by S15 — either prevent COMMIT-crossover, or post-process clamp." Boltz and Specc asked Gizmo to rule on two open design questions before S15.2 implementation.

## Ruling on Metric: pre-tick or post-tick

**Ruling: PRE-TICK.** The "no moonwalk" invariant measures **intent to retreat**, not post-tick net displacement.

### Rationale

The invariant's canonical statement lives in `gdd.md` L286:

> **RECOVERY phase:** Respects `backup_distance` cap (max 1 tile retreat before lateral movement)

The authored word is **"retreat"** — a motion-verb defined relative to the actor's own frame (facing, target vector at the moment of decision), not relative to positions after everyone has moved. The GDD's TCR model (L261–287) describes bot behavior as a sequence of intentional actions per chassis rhythm: Scout commits briefly, Fortress commits relentlessly, RECOVERY is where bots "retreat away from target at 90% base speed." Every use of "retreat" in the combat section is framed as a *chosen direction*, not an emergent post-tick fact.

Specc's KB confirms this intent-framing: the original bug (S11.1) was that the `"away"` juke branch literally wrote `b.position -= to_target.normalized() * juke_spd` — a retreat in the bot's *own* reference frame, bypassing the backup budget. S15.1's fixes (separation force clamp, unstick nudge clamp) all operate on pre-tick `to_target` against the path's own backward component. The invariant has always been about the bot's own frame of reference at the moment it decides to move.

A post-tick reading produces false positives on a motion pattern the GDD explicitly endorses: the COMMIT dash (L276, "Dashes toward target at `min(base_speed × 1.4, 200 px/s)`"). Scout's commit cap (200 px/s = 100 px per 0.5s window at the test's tick rate; bots start 20 px apart) **guarantees** crossover on close-quarters mirror matchups — this is the chassis's authored fantasy ("slippery, cautious, commits briefly," L263). Calling a canonical commit-dash a "moonwalk violation" contradicts the GDD's stated movement design.

The **test is the artifact**, not the code. Pre-tick framing restores the invariant's intended meaning: a bot violates moonwalk iff it moves *against the direction it was facing when the tick began* by more than its `backup_distance` budget allows.

### Concrete test change (for Nutts)

In `godot/tests/test_sprint11_2.gd::test_away_juke_cap_across_seeds` (L71–104), sample `to_target` **before** `simulate_tick()`:

```gdscript
for _t in range(300):
    if sim.match_over:
        break
    # Sample target direction BEFORE the tick — intent frame.
    var to_target_pre: Vector2 = Vector2.ZERO
    if b0.alive and b0.target != null:
        to_target_pre = b0.target.position - b0.position
    sim.simulate_tick()
    if b0.alive and b0.target != null:
        var movement: Vector2 = b0.position - prev_pos
        if to_target_pre.length() > 0.1 and movement.length() > 0.1:
            var dot: float = movement.normalized().dot(to_target_pre.normalized())
            if dot < -0.7:
                backup_run += movement.length()
            else:
                backup_run = 0.0
        prev_pos = b0.position
        if backup_run > 32.0 * 1.2:
            violations += 1
            break
```

Apply the same pre-tick sampling to `test_away_juke_capped_at_one_tile` (the direct test, L45) for consistency. No code change in `combat_sim.gd` required — the existing S15.1 clamps already enforce the invariant correctly in the intent frame; the test was measuring the wrong thing.

**Scope flag for Ett:** ~5–10 lines of test change across two test cases, plus re-running the 100-seed suite. This is a trivial S15.2.

## Ruling on COMMIT Pass-Through

**Ruling: YES — COMMIT pass-through is allowed by design.** No collision-resolution guard should be added to COMMIT for S15.2.

### Rationale

Three pillars support this:

1. **Chassis fantasy depends on it.** The GDD's Scout identity (L263: "Slippery, cautious, commits briefly") and Fortress identity ("Relentless — short windups, long commits") both trade on the dash being a full-commitment motion that cannot be soft-blocked by geometry. Fortress at 84 px/s × 1.2s = 101 px commit distance is already balanced against Scout's 200 px/s × 0.6s = 120 px — if either can be halted mid-dash by the other's hitbox, the commit cap (S13.3) that Scout took a nerf on becomes dead weight on Scout and a defensive buff to Fortress. That's a balance change, not a bug fix.

2. **Crossover is already rare.** It requires both bots to COMMIT toward each other on overlapping tick windows at close range. Per Boltz's seed analysis, 7/100 Scout-vs-Scout mirror matchups at 20-px starting distance produce it. Outside mirror at close quarters, it's a negligible fraction of combat time. Adding a collision-resolution system to a rare case introduces a new code surface (edge cases: three-bot pileups, COMMIT-vs-TENSION collisions, COMMIT-vs-knockback) for a problem that is **not observable in gameplay** — no playtest feedback has flagged it as a visual or combat readability issue. The only thing observing it was the broken test.

3. **Speed-vs-collision-mass is not in scope.** Introducing "bots can't pass through each other at COMMIT speed but can at normal speed" is a meaningful physics/combat rule that deserves its own design spec, HCD sign-off, and playtest iteration. Shipping it as a metric-fix side effect violates scope discipline.

### Separation force still does its job

The existing bot-bot separation force (capped by S15.1's `backup_distance` clamp) continues to push bots apart during non-COMMIT states. Pass-through is scoped to COMMIT only as an emergent consequence of dash-speed geometry; nothing in this ruling changes separation behavior outside COMMIT.

### If gameplay ever requires it

If a future playtest reveals that COMMIT pass-through is visually jarring or breaks combat readability, the fix is a **dedicated design sprint** that defines collision mass, dash-halting semantics, and animation polish — not a moonwalk-test patch.

## Acceptance Criteria for S15.2

S15.2 is "sprint complete" when **all** of the following hold:

1. **Test change shipped:** `test_away_juke_cap_across_seeds` and `test_away_juke_capped_at_one_tile` in `godot/tests/test_sprint11_2.gd` sample `to_target` pre-tick per the code block above. No change to `godot/combat/combat_sim.gd` or any runtime code.
2. **Zero violations, 100 seeds:** Running `test_away_juke_cap_across_seeds` produces the exact assertion output `No moonwalk violations (0/100)` and PASS. Re-run against the 7 previously-failing seeds (2, 23, 45, 63, 67, 80, 84) individually via the debug harness to confirm each now passes.
3. **Full test suite green:** `godot/tests/test_sprint11_2.gd` runs all four tests passing; other existing test files unaffected.
4. **CI green:** Full CI (`./run_tests.sh` or equivalent) passes on the PR branch with no new failures.
5. **No code drift:** Diff of `combat_sim.gd` between main and the S15.2 merge commit is empty. S15.1's per-path clamps remain untouched. (If the diff is non-empty, the PR is out of scope and must be split.)
6. **KB update:** Specc adds a one-paragraph note to `docs/kb/juke-bypass-movement-caps.md` clarifying that the residual 7/100 was a metric artifact, resolved in S15.2 via pre-tick sampling; points readers to this ruling.
7. **Harness preserved:** `godot/tests/harness/debug_moonwalk.gd` continues to exist but can be updated to use pre-tick sampling for future-proof diagnostics.

Optic's verification: spot-check 10 random seeds from the previously-violating set and confirm each produces `violations == 0` with the new metric.

## GDD Update

**No GDD change required.** This ruling is a clarification of existing canon:

- The GDD's use of the word "retreat" (L286) already encodes intent-frame semantics.
- COMMIT pass-through is an emergent consequence of the S13.3 commit cap values the GDD already specifies (L251, L276); it is not a rule being added, it is a property of the motion system the GDD already describes.

If future readers find the "intent-frame vs post-tick" distinction non-obvious when authoring new movement invariants, Specc may add a short clarification to `docs/kb/` — but the GDD itself stands as written.

---

**Verdict summary for Riv:**
- Metric: **pre-tick**.
- COMMIT pass-through: **allowed** (no collision guard).
- S15.2 scope: **trivial** — ~5–10 line test change + rerun.

---

## Addendum: period-boundary reset ruling

**Date:** 2026-04-17 (same-day supplement)
**Status:** RULING — extends the S15.2 pre-tick ruling to close AC #2
**Triggered by:** Nutts' PR #84 — pre-tick sampling dropped 7/100 → 3/100; seeds 2, 63, 84 remain.

### Question

GDD L286 reads: *"Respects backup_distance cap (max 1 tile retreat before lateral movement)."* Two candidate readings:

- **(A) Per-period.** The 1-tile cap is a budget that resets once lateral movement (or a phase transition) breaks the retreat. Multiple retreat periods per combat phase are legal as long as each period respects the budget.
- **(B) Absolute rolling.** The 1-tile cap is a cumulative hard ceiling across the entire combat phase regardless of period breaks.

### Ruling: (A) Per-period reset.

Three pillars:

**1. GDD phrasing encodes a budget-with-break semantic, not a hard ceiling.**

The operative clause is *"max 1 tile retreat **before lateral movement**."* The "before lateral" qualifier is load-bearing: it names the event that *bounds* the 1-tile allowance. If the designer had meant an absolute ceiling, the natural phrasing would be *"max 1 tile net retreat per phase"* or *"max 1 tile retreat in any combat cycle."* The actual phrasing reads as a sequencing rule — "you may retreat up to 1 tile, then you must break with lateral motion" — with the implication that after you break, the sequence can restart. This is the same shape as a dash-cooldown or a combo-breaker: a per-use budget gated by an interrupt condition.

**2. Runtime canon is per-period, and it's been stable for 15 sprints.**

`combat_sim.gd` resets `backup_distance = 0.0` at seven authored sites:

- Enter combat (L395), exit combat (L414).
- Phase transitions: COMMIT→RECOVERY (L746), RECOVERY→TENSION (L753).
- TENSION branch: after orbit-out (L776), after lateral (L785), after in-band orbit (L789).

The budget is enforced via `if b.backup_distance < TILE_SIZE` guards (L778, L825); once the budget is exhausted, the code falls through to a lateral branch which resets `bd` to 0 on the *next* reset opportunity. This is a canonical per-period implementation. The runtime has shipped since S11.1 and been playtested through S15.1 without anyone — HCD, Optic, playtesters — flagging a "bot retreats further than it should" gameplay issue. If the design intent were absolute-rolling, the runtime would have been wrong for four sprints, and playtest would have surfaced it. The parsimonious reading is: the runtime is correct; the new test metric is over-counting.

**3. Chassis fantasy relies on TCR rhythm, which inherently creates multi-period retreat sequences.**

The TCR cycle (GDD L261–287) guarantees that within a single combat engagement, a bot cycles through RECOVERY→TENSION→COMMIT→RECOVERY… repeatedly. Each RECOVERY phase is authored to *retreat away from target at 90% base speed* (L285), and each TENSION phase permits *backing away max 1 tile straight line, then lateral* when too close (L289–292). A long engagement will legitimately produce several retreat-then-lateral-then-retreat sequences. Under Reading (B), any multi-phase engagement where the bot retreated in two or more phases would violate — which would make the RECOVERY phase's authored retreat behavior self-contradictory with the backup_distance cap. Reading (A) resolves the contradiction: each phase's retreat is its own budgeted period.

**Seed 84 corroborates.** Nutts' trace shows 4 consecutive backward ticks with `bd` pinned at 32 on some ticks and backward motion continuing. The only way backward motion occurs while `bd == TILE_SIZE` is through a phase transition resetting `bd` mid-run (L746/753) or through separation force (already clamped in S15.1 against the same budget — which itself resets on phase boundaries). Either way, the backward motion is coming from a *new* retreat period the runtime has authorized via the reset. The test's rolling accumulator doesn't observe the reset and mis-attributes the new period's motion to the old one. That is a test-metric artifact of exactly the same shape as the post-tick crossover artifact — it measures state the invariant was never defined against.

**Seed 2 corroborates explicitly.** Nutts' trace: *"`bd` hits 32 then resets to 13.2 at t=44 (new retreat period starts) but test's rolling `backup_run` doesn't reset because `dot < −0.7` stays true across the period boundary."* The runtime has done exactly what the design says: budget exhausted, lateral break (implied by the reset), new period begins. The test is failing to honor the reset.

### Why not (B)?

Adopting (B) would require:

- Reinterpreting GDD L286 against its natural reading.
- Declaring `combat_sim.gd` buggy for 15 sprints against unanimous playtest silence.
- Redesigning RECOVERY to either forbid retreat-after-first-period or track a cross-phase cumulative counter — a balance change that invalidates the S13.3 TCR tuning and the S15.1 budget-clamp design.
- Breaking S15.2's scope gate (runtime frozen) and deferring closure to S15.3/S16.

That's a five-order cascade triggered by a metric that was only added in S15 for regression detection. The alternative is a one-line test change. Occam applies.

### Concrete test change (for Nutts)

In `godot/tests/test_sprint11_2.gd::test_away_juke_cap_across_seeds`, reset the rolling `backup_run` accumulator whenever the runtime's `backup_distance` drops (signaling a period boundary — phase transition or lateral break that the runtime already enforces). Add one variable and one branch inside the existing dot-product block:

```gdscript
var prev_bd := 0.0  # track bd across ticks so we can detect resets
# ...inside the for _t in range(300): loop, after simulate_tick():...
if b0.alive and b0.target != null:
    # Period-boundary reset: if the runtime dropped bd (phase transition or
    # lateral break), we've entered a new retreat period — reset the rolling
    # accumulator. Per Gizmo's S15.2 addendum: the invariant is per-period,
    # not absolute-rolling. GDD L286: "max 1 tile retreat before lateral
    # movement" — the bd drop IS the lateral/phase break.
    if b0.backup_distance < prev_bd:
        backup_run = 0.0
    prev_bd = b0.backup_distance
    var movement: Vector2 = b0.position - prev_pos
    # ...existing dot-product logic unchanged...
```

That's the entire change. Place the reset check **before** the movement/dot block so a period boundary clears the run before the current tick's motion is accumulated into it. Apply the same reset to `godot/tests/harness/debug_moonwalk.gd` for diagnostic consistency (per original AC #7).

### Scope

**`combat_sim.gd` stays untouched.** S15.2's scope gate holds. The runtime is correct; the test was measuring an invariant the runtime was never defined against, and the fix is another test-side refinement in the same spirit as the pre-tick sampling fix.

### Acceptance criteria (unchanged from main ruling)

AC #2 expected outcome after this change: seeds 2, 63, 84 join seeds 23, 45, 67, 80 as passing. `No moonwalk violations (0/100)`. All other ACs from the main ruling remain as written. AC #5 (no `combat_sim.gd` drift) remains intact.

### GDD update

None required. This is a clarification of the existing canon, same as the main ruling. If Specc wants to add a one-line gloss to `docs/kb/juke-bypass-movement-caps.md` noting *"the backup_distance cap is per-retreat-period (runtime resets bd on phase transitions and lateral breaks); tests that measure it must honor the reset"*, that would be useful future-proofing — but not required.

### Verdict summary for Riv

- Reading: **(A) per-period reset.**
- Test change: add a 2-line `if b0.backup_distance < prev_bd: backup_run = 0.0` reset guard (plus a `prev_bd` tracker) ahead of the dot-product block; mirror into `debug_moonwalk.gd`.
- Scope: **TRIVIAL.** `combat_sim.gd` untouched; S15.2 scope gate preserved.
- Expected outcome: 3/100 → 0/100 → S15.2 closes clean in PR #84.

---

## Addendum 2: post-cap freeze ruling (budget-exhaustion is end-of-period)

**Date:** 2026-04-17 (same-day supplement, third ruling in S15.2 metric stream)
**Status:** RULING — extends the period-reset addendum to close seeds 63 and 84
**Triggered by:** Nutts' PR #84 — period-reset dropped 3/100 → 2/100; seeds 63 and 84 remain.

### Question

The period-reset mechanic (`if bd < prev_bd: reset`) cannot fire when `bd` is **pinned at the cap (32) for the full violating window**. Seed 84 trace (Nutts):

```
t  mv    dot    backup_run  bd    phase
31 13.2  -1.00  13.2        0.0   1
32 19.8  -1.00  33.0        19.8  2
33 12.2  -1.00  45.2        32.0  2  ← bd just hit cap (credited)
34 15.3  -0.72  60.5 ← VIOL 32.0  2  ← bd stays at 32; 15.3px backward motion uncounted by runtime
35  0.0   —      0.0              0.0 (reset — one tick too late)
```

At t=34 the runtime credits **zero** retreat to `bd` but the bot physically moved 15.3px with `dot = -0.72` against the pre-tick intent frame. Where does the motion come from, and how should the test treat it?

### Source of the post-cap drift (diagnosis)

Inspection of `combat_sim.gd` shows that **every authored retreat path credits `bd`** (`+=` sites at L569 separation-force, L661 unstick-nudge, L781 orbit-in-band, L828 RECOVERY-retreat), all gated on `if bd < TILE_SIZE`. Once `bd == TILE_SIZE`, the retreat gates close and the code falls through to **lateral branches** (L691–692 juke-away lateral, L784–785 orbit lateral, L832–834 RECOVERY lateral). These lateral branches write `b.position += perp * orbit_direction * spd` — motion that is **perpendicular to the current-tick `to_target`**, which the pre-tick test metric then re-reads against its **stale pre-tick `to_target`**. If the target moved during the tick, the two `to_target` vectors differ by the target's displacement angle. A perpendicular-to-current-tick motion then reads as `dot = -sin(Δθ)` against the pre-tick frame. `dot = -0.72` ⇔ `Δθ ≈ 46°`, which is well within the range produced by two close-quarters Scouts commit-dashing at the test's 20-px start spacing.

The secondary source is separation-force's **overlap bypass** (L557–558): when `sep_dist < 2 × BOT_HITBOX_RADIUS`, the separation push is applied with full authority, including its backward component, *without* being gated by `bd`. This is an authored exception (documented in-code) to resolve actual hitbox overlap — another instance of authored non-retreat motion that the test misreads as retreat.

**Conclusion:** the 13–28px of post-cap backward drift is not a runtime moonwalk; it is authored lateral/orbit/overlap motion being measured against a stale intent vector by a test that has no concept of "retreat period has ended."

### Ruling: α with refinement — post-cap freeze, not post-cap credit

I accept the **spirit** of Nutts' Option 1 ("the test should honor the runtime's own accounting of when a retreat period ends") but reject its **literal** formulation (`backup_run += max(0, bd - prev_bd)`), because the literal form is tautological and **defangs the test against the original regression class**.

#### Why literal Option 1 defangs the test — sanity check

The original S11.1 bug was `b.position -= to_target.normalized() * juke_spd` in the juke-away branch — a backward position write that **did not touch `bd` at all**. Under literal Option 1, `bd` would stay at 0 for the entire buggy window, so `bd - prev_bd == 0`, so `backup_run` never grows, so the test silently passes the exact regression it was authored to catch. That is unacceptable. If S15.1's per-path clamps were reverted tomorrow, the test must catch it — the whole point of this suite is backstop against bypass-class regressions.

#### Refined formulation — "budget-gated raw accumulator"

Measure raw backward motion the way the current test does, **but only while the retreat budget is live** (`bd < TILE_SIZE`). Once `bd` reaches the cap, the runtime has declared the retreat period over; any further apparent-backward motion is authored lateral/orbit/overlap motion, and the test freezes its accumulator until the next period-boundary reset (`bd < prev_bd`, already handled by Addendum 1).

Pseudocode of the full accumulator logic after this ruling:

```gdscript
# Period-boundary reset (Addendum 1): runtime dropped bd → new retreat period.
if b0.backup_distance < prev_bd:
    backup_run = 0.0
prev_bd = b0.backup_distance

if to_target_pre.length() > 0.1 and movement.length() > 0.1:
    var dot: float = movement.normalized().dot(to_target_pre.normalized())
    if dot < -0.7:
        # Addendum 2: only accumulate while the retreat budget is live.
        # Once bd hits cap, the runtime has ended the retreat period; any
        # further backward-appearing motion is authored lateral/orbit/overlap
        # (measured against a stale pre-tick to_target, hence dot<−0.7).
        # Freeze the accumulator until the next period-boundary reset.
        if b0.backup_distance < TILE_SIZE:
            backup_run += movement.length()
        # else: post-cap freeze — do not grow, do not reset.
    else:
        backup_run = 0.0
```

This is stronger than literal Option 1:

- **Pre-cap window:** raw backward motion is still accumulated against the 38.4px (32 × 1.2) threshold. An S11.1-style unclamped backward write with `bd == 0` still trips the assertion at `movement.length() > 38.4` exactly as before. **Original regression class is still protected.**
- **Post-cap window:** the test defers to the runtime's "period is over" signal (`bd == TILE_SIZE`). Authored lateral/orbit/overlap motion no longer produces false positives.
- **Period-boundary:** Addendum 1's reset fires, the next period starts with `backup_run = 0` and `bd < TILE_SIZE`, and the budget-gated accumulator resumes.

#### Sanity check — does the test still protect against the original regression?

**Yes.** Concrete walk-through:

- **Scenario:** S15.1 clamps reverted. Juke-away branch writes `b.position -= to_target.normalized() * juke_spd` without updating `bd`. Scout's juke runs ~8 ticks at ~20 px/tick = ~160px total backward displacement.
- **Tick 1 of bug:** `bd == 0` (below cap). `dot ≈ -1`. `backup_run += 20`. Gate check: `20 < 38.4`, continue.
- **Tick 2:** `bd == 0` still (bug bypasses the increment). `backup_run += 20 → 40`. Gate: `40 > 38.4`. **VIOLATION recorded.** ✅
- The test fires on tick 2 of the bug exactly as it did under the old post-tick metric, because the pre-cap budget-gated accumulator is identical to the old raw accumulator *while bd is below cap*, which is precisely the window the bypass bug operates in.

The test retains full fidelity against the bypass-class regression. It only declines to double-count authored post-cap motion, which was never a moonwalk in the first place.

### Why not (β) — rule it a runtime bug

(β) would require declaring the **lateral branches themselves** buggy (L691, L784, L832) because they produce motion that reads as backward against a stale pre-tick frame. That is not a runtime bug — it's the authored perpendicular-to-current-frame orbit/lateral behavior that every chassis in the GDD's TCR model depends on (L261–292). Declaring it buggy would cascade into redefining "retreat" to mean "any motion with `movement·to_target_pre < −0.7`" — which is the test-as-canon fallacy my original ruling rejected (Pillar 1: the invariant is intent-frame motion, not post-hoc dot-product classification).

The overlap-bypass in separation (L557–568) is a more defensible β target — that path genuinely can push the bot backward past the budget — but its scope is narrow (only fires when `sep_dist < 2 × BOT_HITBOX_RADIUS`, i.e., actual hitbox overlap) and its purpose is documented (resolve overlap to prevent the `sep_dist <= 0.01` explosion branch). Declaring that buggy would re-open the overlap-pathology S15.1 was partly designed around. Out of scope for S15.2; if playtest ever flags visible backward pops during overlap, a future sprint can add commit-mass semantics.

### Why not (γ) — phase-1-only measurement

γ ("measure only during phase 1, ignore phase 2") was tempting but wrong: the S11.1 juke-away bug fires during a juke that can occur in any phase, and RECOVERY (phase 2) has an authored retreat gate (L823–828) that is the primary shape of the invariant. Excluding phase 2 would leave the RECOVERY retreat path unprotected against regression. Budget-gating (this ruling) is strictly better than phase-gating.

### Scope

**`combat_sim.gd` stays untouched.** S15.2's scope gate still holds. This is a third test-side refinement in the same spirit as Ruling 1 (pre-tick) and Addendum 1 (period-reset): the runtime is canon; the test's accumulator is being taught to honor all the signals the runtime already emits.

### Concrete test change (for Nutts)

In `godot/tests/test_sprint11_2.gd::test_away_juke_cap_across_seeds`, add one guard inside the existing `if dot < -0.7:` branch:

```gdscript
if dot < -0.7:
    if b0.backup_distance < TILE_SIZE:  # budget-gated: only accumulate while retreat period is live
        backup_run += movement.length()
    # else: post-cap freeze (Gizmo S15.2 Addendum 2) — authored lateral/orbit
    # motion past the cap is not a moonwalk; wait for period-boundary reset.
else:
    backup_run = 0.0
```

Mirror into `godot/tests/harness/debug_moonwalk.gd` for diagnostic consistency. No other changes.

### Acceptance criteria (unchanged from main ruling)

Expected outcome: seeds 2 (already closed by Addendum 1), 63, 84 all pass. `No moonwalk violations (0/100)`. AC #5 (no `combat_sim.gd` drift) remains intact.

### Verdict summary for Riv

- **Verdict: α with refinement.** Bless the spirit of Option 1; reject its literal form (tautological, defangs original regression); ship the budget-gated raw accumulator above.
- **Test change:** one `if b0.backup_distance < TILE_SIZE:` guard added inside the existing `if dot < -0.7:` block. Roughly 3 lines including comment.
- **Scope: TRIVIAL.** `combat_sim.gd` untouched.
- **Expected outcome:** 2/100 → 0/100. S15.2 closes clean.
- **Sanity check answer:** yes, the test still protects against the original moonwalk regression class. Bypass-class bugs fire with `bd` stuck at 0 (below cap), so the budget-gated accumulator behaves identically to the original raw accumulator during the bug window. Verified by walk-through above.

