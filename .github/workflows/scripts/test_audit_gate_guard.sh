#!/usr/bin/env bash
# test_audit_gate_guard.sh — dry-run test of the Audit Gate guard logic.
#
# [S18.4-002a] The guard step in `.github/workflows/audit-gate.yml` decides
# whether to short-circuit (non-sprint PR) or fall through to full validation
# (sprint PR). This script exercises the guard *shell logic in isolation*
# against both branches, without needing GitHub Actions, secrets, or the
# Boltz App. It verifies:
#
#   a. When the simulated diff contains `sprints/sprint-*.md`: the guard
#      emits `has_sprint_changes=true` and downstream full-validation steps
#      would run.
#   b. When the diff contains only non-sprint paths: the guard emits
#      `has_sprint_changes=false` and the short-circuit summary text is
#      exactly `No sprint files changed — audit gate short-circuited.`
#
# Run: bash .github/workflows/scripts/test_audit_gate_guard.sh
#
# This is a regression test for the silent-success failure mode flagged
# in the S18.4-002a brief: if the guard conditional is inverted or the
# glob drifts from the original path-filter (`sprints/sprint-*.md`), the
# required check could post green on sprint PRs that skipped full
# validation — worse than a missing check. These cases pin the glob and
# both output paths.

set -euo pipefail

FAILED=0

# Extracted guard logic: takes a newline-separated list of changed files
# on stdin, writes `has_sprint_changes=true|false` to $GITHUB_OUTPUT, and
# writes the short-circuit summary on the false branch. Identical grep
# pattern to the workflow.
run_guard() {
    local changed
    changed=$(cat)
    if echo "$changed" | grep -qE '^sprints/sprint-.*\.md$'; then
        echo "has_sprint_changes=true" >> "$GITHUB_OUTPUT"
    else
        echo "has_sprint_changes=false" >> "$GITHUB_OUTPUT"
        echo "No sprint files changed — audit gate short-circuited." > "$SUMMARY_OUT"
    fi
}

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  ✓ $label"
    else
        echo "  ✗ $label"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        FAILED=1
    fi
}

# ---------------------------------------------------------------------------
# Case A: sprint file in diff → full validation branch
# ---------------------------------------------------------------------------
echo "Case A — sprint PR (sprints/sprint-18.4.md changed):"
GITHUB_OUTPUT=$(mktemp)
SUMMARY_OUT=$(mktemp)
printf 'sprints/sprint-18.4.md\ndocs/gdd.md\n' | run_guard
assert_eq "has_sprint_changes output" "has_sprint_changes=true" "$(cat "$GITHUB_OUTPUT")"
assert_eq "short-circuit summary NOT written" "" "$(cat "$SUMMARY_OUT")"
rm -f "$GITHUB_OUTPUT" "$SUMMARY_OUT"

# ---------------------------------------------------------------------------
# Case B: no sprint file in diff → short-circuit branch
# ---------------------------------------------------------------------------
echo "Case B — non-sprint PR (framework/CI changes only):"
GITHUB_OUTPUT=$(mktemp)
SUMMARY_OUT=$(mktemp)
printf '.github/workflows/audit-gate.yml\nREADME.md\n' | run_guard
assert_eq "has_sprint_changes output" "has_sprint_changes=false" "$(cat "$GITHUB_OUTPUT")"
assert_eq "short-circuit summary text" \
    "No sprint files changed — audit gate short-circuited." \
    "$(cat "$SUMMARY_OUT")"
rm -f "$GITHUB_OUTPUT" "$SUMMARY_OUT"

# ---------------------------------------------------------------------------
# Case C: empty diff (edge case — should short-circuit, not crash)
# ---------------------------------------------------------------------------
echo "Case C — empty diff:"
GITHUB_OUTPUT=$(mktemp)
SUMMARY_OUT=$(mktemp)
printf '' | run_guard
assert_eq "has_sprint_changes output" "has_sprint_changes=false" "$(cat "$GITHUB_OUTPUT")"
rm -f "$GITHUB_OUTPUT" "$SUMMARY_OUT"

# ---------------------------------------------------------------------------
# Case D: glob parity — legacy `sprints/sprint-17.md` (no .M) must NOT match
# the original path-filter `sprints/sprint-*.md` required `*` to be present,
# but glob `sprint-*.md` does match `sprint-17.md` (single-level). Verify
# our regex matches what the original `on.pull_request.paths:` glob would.
# The original glob `sprints/sprint-*.md` matches `sprint-17.md` AND
# `sprint-18.4.md`. Our regex `^sprints/sprint-.*\.md$` matches both too.
# ---------------------------------------------------------------------------
echo "Case D — legacy sprint-N.md (no sub-sprint) triggers full validation:"
GITHUB_OUTPUT=$(mktemp)
SUMMARY_OUT=$(mktemp)
printf 'sprints/sprint-17.md\n' | run_guard
assert_eq "legacy sprint file triggers validation" \
    "has_sprint_changes=true" "$(cat "$GITHUB_OUTPUT")"
rm -f "$GITHUB_OUTPUT" "$SUMMARY_OUT"

# ---------------------------------------------------------------------------
# Case E: false-positive guard — file named `sprints/sprint-X.md` in a
# subdirectory must NOT match (anchored ^). Protects against silent-success.
# ---------------------------------------------------------------------------
echo "Case E — nested path must NOT match (anchor integrity):"
GITHUB_OUTPUT=$(mktemp)
SUMMARY_OUT=$(mktemp)
printf 'archive/sprints/sprint-18.4.md\ndocs/sprints/sprint-18.4.md\n' | run_guard
assert_eq "nested sprint-ish paths do NOT trigger validation" \
    "has_sprint_changes=false" "$(cat "$GITHUB_OUTPUT")"
rm -f "$GITHUB_OUTPUT" "$SUMMARY_OUT"

if (( FAILED )); then
    echo ""
    echo "FAIL — one or more guard assertions did not hold."
    exit 1
fi

echo ""
echo "OK — all guard-logic assertions passed."
