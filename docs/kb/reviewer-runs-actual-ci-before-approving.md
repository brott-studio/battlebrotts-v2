# KB: Reviewer Runs Actual CI on Merged Branch Before Approving

**Source:** Sprint 13.8 audit
**Category:** Pipeline / Process

## Pattern

Before the reviewer (Boltz) approves a PR, they pull the **actual
CI run output on the merged branch** and verify it green — not
just the local test run reported by the implementer.

Local tests are necessary but not sufficient. The merge gate is
CI on the merged branch. If local is green but CI is red, the
reviewer holds the merge.

## Why It Works

1. **Catches environment drift.** Local toolchains can silently
   diverge from CI (Godot version, shell, file discovery glob).
   The CI run is the only ground truth for the merge gate.
2. **Catches scope-expansion bugs.** Workflow changes (e.g. test
   discovery globs) can silently pull in files that local runs
   never touch. CI is where the real file set is enumerated.
3. **Closes the "all green locally" failure mode.** The most
   dangerous PR is the one where everyone's local passes but CI
   fails on the merged branch. This pattern makes that state
   impossible to approve through.
4. **Pairs with TPM-verifies-spec-before-brief.** Both patterns
   push verification to the layer where the failure actually
   surfaces. TPM catches spec errors before code; reviewer
   catches CI errors before merge. Together they bracket the
   pipeline.

## Sprint 13.8 Evidence

On PR #69 (Modal Hardening + CI Glob + Dynamic Toast), all local
tests passed. The implementer reported green. CI Run 24535475729
failed on `test_sprint10.gd` — a legacy Godot 3 file that the
new glob-based test discovery had silently pulled in.

Boltz did not approve on the local-green basis. He pulled the CI
run, saw the parse failure, and held the merge. Parent narrowed
the glob from `test_sprint*.gd` to `test_sprint13_*.gd` in one
line; Boltz re-reviewed on the amended branch, CI ran green, and
only then did the merge land.

Without this pattern the PR would have merged red, and the next
PR would have inherited a broken main.

## The Check (concrete)

Before approving, the reviewer:

1. Pulls the PR's latest CI run (`gh pr checks <N>` or via the
   Checks tab on the merged branch).
2. Confirms the run is green **on the merged branch**, not on
   the source branch alone.
3. If red or pending, holds the merge until green.
4. Reads at least one CI log on a failure class they haven't
   seen before — don't trust summary status blindly when the
   workflow itself has changed in the PR.

## Pairs With

- **TPM verifies spec against codebase before brief** (KB PR
  #68). Both are verification-pushdown patterns: catch the
  failure at the layer where it's cheapest to fix.

## Anti-Pattern

"Local tests pass, LGTM." This is the failure mode this pattern
exists to prevent. Local-green is a prerequisite for review, not
a substitute for CI-green.
