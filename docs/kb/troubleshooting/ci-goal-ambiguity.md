# Troubleshooting: CI goal ambiguity — narrow vs broad framing

## Problem

A sprint goal phrased as "restore CI green" or "close CI health" reads, in the sprint plan, as a binary: either CI is green on `main` at end of sprint, or it isn't. In practice, a CI job is usually one shell-glob loop over many test files, and the failure set is often *non-disjoint*: the test this sprint is fixing, plus N unrelated pre-existing failures, plus maybe a parse error somewhere. The narrow fix can land correctly and the CI job can still read ❌ on `main`.

If the sprint plan does not disambiguate, the completion read-out ("violations 2 → 0 ✅, merged") will frame a narrow win as a broad one, and the git history will misrepresent goal closure.

## Canonical example — Sprint 15.2

- **Narrow goal (met ✅):** `test_away_juke_cap_across_seeds` == 0/100; `test_sprint11_2.gd` passes end-to-end.
- **Broad goal (not met ❌):** CI `Godot Unit Tests` job green on `main`.

The broad goal did not land because three unrelated tests (`test_sprint12_1.gd` 4 fails, `test_sprint12_2.gd` 1 fail, `test_sprint10.gd` parse error) still fail, and the test runner has `|| exit 1` in the glob loop — so the job bails on the first non-zero exit. The S15.1 audit flagged these as tech debt. S15.2 did not inherit a mandate to fix them; the plan did not scope them. But the sprint readout still read like a broad win.

## How to prevent the ambiguity

### In the sprint plan (Ett's job)

Under the "Goal" section, explicitly name:

1. **Which CI job** — e.g. "`Godot Unit Tests` job on PR and `main`."
2. **Which test files are in scope** — e.g. "`test_sprint11_2.gd :: test_away_juke_cap_across_seeds`."
3. **Stance on unrelated failing tests** — one of:
   - *out of scope, tech debt* (name them, note they will remain ❌ after merge),
   - *in scope, fix-in-this-sprint* (scope each),
   - *in scope, blocker* (sprint does not merge until they pass).

Without this, "restore CI green" is a Rorschach test for the reviewer.

### In the merge PR body (Boltz / merger's job)

If unrelated failures remain and will cause the CI job to read ❌ on `main` after merge, **banner-flag it** in the PR body. Something like:

> ⚠️ **Note on CI status:** `Godot Unit Tests` on `main` will remain ❌ after merge for reasons **unrelated** to this sprint — specifically `test_sprint12_1.gd`, `test_sprint12_2.gd`, and `test_sprint10.gd`, all flagged as tech debt in audit S15.1. This sprint's narrow goal (target test 0/100) is met.

### In the audit (Specc's job)

If the narrow goal met and broad goal did not, name both explicitly in the Headline. Do not let "violations → 0 ✅" obscure the CI-state reality.

## Diagnostic commands

```bash
# Is the CI job red on main? For what reason?
gh run list --branch main --workflow 'Godot Unit Tests' --limit 3

# What test files fail locally (aggregating, not bail-on-first)?
for f in godot/tests/test_*.gd; do
  godot --headless --script "$f" || echo "FAIL: $f"
done

# Diff pre-sprint baseline to confirm a failure is pre-existing, not introduced
git log --oneline -- godot/tests/test_<name>.gd
```

## Related

- `docs/kb/reviewer-runs-actual-ci-before-approving.md` — reviewer discipline on actual CI state.
- `docs/kb/patterns/layered-design-rulings.md` — why "one fix" sometimes isn't.
- `docs/kb/partial-pass-merge-with-diagnosed-residual.md` — when partial-merge is honest.

## Date

2026-04-17, crystallized from Sprint 15.2.
