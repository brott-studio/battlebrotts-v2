# Sprint 14.2 — Carry-Forward Housekeeping

Items deferred from S14.1 merge (PR #74 merge commit 5f97cab). Fold into 14.2 planning, don't let them drift further.

## From Boltz S14.1 re-review (non-blocking nits)

1. **Tighten `test_sprint11` AC6 threshold `≤10` → `≤9`.**
   - File: `godot/tests/test_sprint11.gd` (AC6 moonwalk assertion)
   - Rationale: S14.1 shipped with `≤10` (25% headroom over observed 8/100). Boltz called that overly loose; keep the bar honest at observed+1.
   - 1-line diff, no other test implications.

2. **Clean up `test_sprint11_2` duplicate moonwalk assertion.**
   - File: `godot/tests/test_sprint11_2.gd`
   - It was dead-red on main pre-S14.1 (4/100), pushed to 8/100 post-merge (same mechanism as S11 AC6).
   - Options: (a) tighten its threshold to match S11 AC6's new `≤9`, or (b) delete as duplicative of S11 AC6.
   - Recommend (a) — it's at a different call site / assertion style; kill it only if confirmed redundant.

## From Nutts-B PR #74 comment (future path)

3. **"Post-movement stuck evaluation" restructure (S14.1-B2-if-needed).**
   - Current detector runs per-tick with state mutations gated on `_is_near_geometry`. This shape imposes a baseline tick-ordering perturbation cost even when unstick never fires — that's the source of the residual +4 moonwalk seeds we paid for.
   - Alternative shape: compute stuck-ness at the moment the orbit decision is made, not every tick. No persistent per-tick state.
   - **Don't schedule yet.** Only pull forward if either (a) playtest reports the 8/100 wrong-direction arc as visible, or (b) a future feel-arc sprint needs to close the S11 gap to ≤4/100 (match main baseline).

## Playtest watch

- After any playtester logs a Scout vs Scout match in 14.2 builds, eyeball for ~0.8s wrong-direction arcs in close-quarters combat. If it's reported or visible, escalate item 3. If not, hold position.

---

_Added by The Bott 2026-04-17 post-merge of PR #74._

## From Nutts-A PR #76 (S14.2-A findings, 2026-04-17)

4. **test_sprint4 dead-red on main — 15 failures (HP/overtime constants).**
   - Confirmed pre-existing (present before PR #76), not introduced by S14.2.
   - Silent in CI because `test_runner.gd` doesn't gate on it, or the suite's per-file green/red reporting hides it.
   - Recommend: open a standalone Nutts fix-up in a future sub-sprint, OR explicitly quarantine with a skip comment pointing to a tracking issue. Do not ship a new sprint green on "runner says 72/72" without reconciling.

5. **Godot headless class-cache quirk.**
   - Fresh worktree running `godot --headless --script tests/...` parse-errors on tests that use `class_name` identifiers until `godot --headless --import` runs once.
   - Affects: any automation spinning up fresh checkouts (CI matrix, worktree provisioning, Boltz review probes).
   - Fix: add a one-time `godot --headless --import` pass in CI + worktree bootstrap docs. Low-effort, high-value footgun removal.
