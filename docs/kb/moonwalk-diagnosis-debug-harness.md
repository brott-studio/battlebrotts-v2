# KB: Diagnosing moonwalk regressions with the debug harness

**Added:** 2026-04-17 (Sprint 15 audit, Specc)
**Applies to:** `test_sprint11_2.gd`, `godot/combat/combat_sim.gd`, any movement-cap regression in Battlebrotts.

## When to use

The `test_away_juke_cap_across_seeds` test in `test_sprint11_2.gd` measures the moonwalk invariant across 100 seeds of close-quarters Scout-vs-Scout combat. When it fails with `violations > 0`, some movement path is producing backward motion against facing without clamping against the shared `backup_distance` budget.

Don't guess which path. Use the harness.

## Tool

`godot/tests/harness/debug_moonwalk.gd` (added S15 by Nutts). Turnkey per-seed repro.

### Modes

- **`scan` (default):** Sweep seeds 0–99, print violating seeds with tick-at-first-violation and max backward-run length.
- **`seed=N`:** Dump per-tick trace for one seed. Columns: `phase` (movement phase: ORBIT=0, COMMIT=1, etc.), `bd` (backup_distance), `mv` (net movement magnitude), `dot` (movement·to_target normalized, post-tick), `run` (accumulating backward-run length), plus unstick flags.

### Run

```
godot --headless --path godot/ --script res://tests/harness/debug_moonwalk.gd
godot --headless --path godot/ --script res://tests/harness/debug_moonwalk.gd -- seed=80
```

## Known bypass-path signatures

When reading a per-tick trace, match the failure pattern to one of these known sources:

| Signature | Path | Status |
|---|---|---|
| `phase=0 (ORBIT)`, `bd=0`, `mv≈11`, `dot < -0.7`, repeated ticks | **Separation force** (`_move_brott` ~L535) | **Clamped in S15** (`dc0e49d`). If this shows up again, the clamp regressed or `sep_dist < 2*BOT_HITBOX_RADIUS` overlap-exception is firing too often. |
| `phase=*`, unstick flag set, `mv≈7`, backward direction | **Unstick nudge** (`_check_and_handle_stuck` ~L613) | **Clamped in S15** (`1e60bb6`). If regressed, check `_wall_escape_direction` resolution. |
| `phase=1 (COMMIT)`, `bd=0`, `mv > 20`, `dot ≈ -1.0`, single-tick spike then stable | **COMMIT-crossover test-metric artifact** | **Not a code bug.** Bots swap positions during COMMIT; forward dash reads as backward under post-tick `to_target`. Fix is in the test (pre-tick sampling) or in movement pipeline (prevent crossover). See S15 audit for ruling state. |
| None of the above | **New bypass path** | Write a new clamp, append this table. |

## Historical context

Do **not** re-chase the `juke` "away" branch. It was removed before S15 (see `docs/kb/juke-bypass-movement-caps.md` S15 update). `git grep 'juke' godot/combat/combat_sim.gd` should return zero.

## Pattern

1. Run `scan` mode → get violating seed list.
2. Pick worst-offender (highest `max_run`).
3. Run `seed=N` mode → read per-tick trace near `violated_at_tick`.
4. Match the tick-level signature against the table above.
5. If new: add clamp along the existing per-path pattern (decompose vs `to_target`, clamp backward component against `TILE_SIZE - backup_distance`, pass lateral/forward through). Update this table.

## Related

- `docs/kb/juke-bypass-movement-caps.md` — original anti-pattern.
- S15 audit: `studio-audits/audits/battlebrotts-v2/v2-sprint-15.md`.
- Test: `godot/tests/test_sprint11_2.gd :: test_away_juke_cap_across_seeds`.
