# Migration Notes

Tracks deletions / replacements of legacy code & tests so future archaeologists know
why something disappeared.

## Sprint 13.10 (pre-stage)

### Deleted: `godot/tests/test_sprint2.gd`

- **Why:** Dormant legacy. Tested the preserved-but-unused
  `OpponentData.get_opponent()` path. No CI workflow, runner, or other test
  references it (CI glob is `test_sprint13_*.gd`; `test_runner.gd` does not
  invoke it).
- **Verdict source:** Boltz S13.9 review — "dormant legacy, no urgency."
  Decision recorded in `docs/design/sprint13.10-arc-wrap-polish.md` §3.4.
- **Replacement:** `OpponentData.build_opponent_brott` is now the single
  opponent-construction path; covered by `test_sprint13_9.gd` (T11–T14) and
  `test_sprint13_10.gd` (empty-pool fallback chain).
- **Action if you need it back:** `git log --diff-filter=D --
  godot/tests/test_sprint2.gd` to recover.
