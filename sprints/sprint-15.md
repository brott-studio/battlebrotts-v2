# Sprint 15 — CI Health (Moonwalk Regression Fix)

## Goal
Restore CI green by fixing the moonwalk invariant regression surfaced by `test_away_juke_cap_across_seeds`.

## Context
- GDD moonwalk invariant is canonical — design bar is `violations == 0`.
- KB entry `docs/kb/juke-bypass-movement-caps.md` identifies the failure mode: the juke "away" branch in `_do_combat_movement()` moves backward without clamping against `backup_distance`.
- Stale `≤9` threshold references in `docs/design/sprint14.2-brottbrain-aggression.md` should be ignored; the test at HEAD is authoritative.

## Tasks

### [SN-101] Fix juke away-branch to clamp against `backup_distance`
- Locate the juke "away" branch inside `_do_combat_movement()`.
- Mirror the clamp logic already used by the normal backup-movement path.
- Keep the diff narrow — per-path clamp, no refactor into a post-processing clamp.
- Do NOT fix other movement paths (toward/lateral/dash/knockback) in this PR; note observations in PR body for a follow-up.

### [SN-102] Verify locally + in CI
- Run the Godot test suite locally if a `godot` binary is available; otherwise rely on the CI `Godot Unit Tests` job.
- Confirm `test_away_juke_cap_across_seeds` reports `violations == 0`.
- Confirm `test_away_juke_capped_at_one_tile` remains green.
- Confirm the full Godot suite is green.

## Acceptance
- [ ] `test_away_juke_cap_across_seeds` violations == 0
- [ ] `test_away_juke_capped_at_one_tile` still green
- [ ] Full Godot suite green
- [ ] CI `Godot Unit Tests` job green on PR branch

## Notes
- Establishes the `sprints/` directory convention per CONVENTIONS.md.
- Plan authored by Ett (PM), executed by Nutts on branch `sprint-15-fix-moonwalk-regression`.
