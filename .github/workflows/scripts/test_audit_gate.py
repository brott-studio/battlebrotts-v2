"""Unit tests for .github/workflows/scripts/audit_gate.py

Covers the parseable logic — file-path parsing, tuple-sort discovery, retry
loop semantics — without hitting the GitHub API. Token mint and the live
HTTP path are exercised end-to-end by the real workflow runs.

Run: `pytest .github/workflows/scripts/test_audit_gate.py`
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from unittest import mock

import pytest

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))

import audit_gate  # noqa: E402


# ---------------------------------------------------------------------------
# Regex / path parsing
# ---------------------------------------------------------------------------

class TestSprintRegex:
    def test_matches_well_formed(self):
        m = audit_gate.SPRINT_FILE_RE.match("sprints/sprint-18.2.md")
        assert m and m.group(1) == "18" and m.group(2) == "2"

    def test_single_digit_both_sides(self):
        m = audit_gate.SPRINT_FILE_RE.match("sprints/sprint-3.1.md")
        assert m and m.group(1) == "3" and m.group(2) == "1"

    def test_multi_digit_M(self):
        m = audit_gate.SPRINT_FILE_RE.match("sprints/sprint-18.12.md")
        assert m and m.group(2) == "12"

    def test_rejects_bare_N_no_M(self):
        # Legacy `sprint-17.md` shape — pass-through neutral path, not gated.
        assert audit_gate.SPRINT_FILE_RE.match("sprints/sprint-17.md") is None

    def test_rejects_non_sprint_file(self):
        assert audit_gate.SPRINT_FILE_RE.match("docs/gdd.md") is None

    def test_any_sprint_regex_covers_legacy(self):
        assert audit_gate.SPRINT_ANY_RE.match("sprints/sprint-17.md")
        assert audit_gate.SPRINT_ANY_RE.match("sprints/sprint-18.2.md")
        assert not audit_gate.SPRINT_ANY_RE.match("arcs/arc-18.md")


# ---------------------------------------------------------------------------
# current_closed_sprint discovery — tuple-sort, not string-sort
# ---------------------------------------------------------------------------

class TestTupleSort:
    def test_numeric_ordering_beats_lexicographic(self):
        # String-sorted: "sprint-9.1" > "sprint-10.1" (wrong).
        # Tuple-sorted: (10, 1) > (9, 1) (correct).
        files = ["sprints/sprint-10.1.md", "sprints/sprint-9.1.md"]
        tuples = sorted(
            (int(m.group(1)), int(m.group(2)), f)
            for f in files
            for m in [audit_gate.SPRINT_FILE_RE.match(f)]
            if m
        )
        assert tuples[-1][:2] == (10, 1)

    def test_picks_most_recent_within_same_arc(self):
        files = [
            "sprints/sprint-18.1.md",
            "sprints/sprint-18.2.md",
            "sprints/sprint-18.10.md",
        ]
        tuples = sorted(
            (int(m.group(1)), int(m.group(2)), f)
            for f in files
            for m in [audit_gate.SPRINT_FILE_RE.match(f)]
            if m
        )
        assert tuples[-1][2] == "sprints/sprint-18.10.md"


# ---------------------------------------------------------------------------
# check_prior_audit_exists — URL shape + 404 handling
# ---------------------------------------------------------------------------

class TestPriorAuditLookup:
    def test_builds_expected_path(self):
        expected = "audits/battlebrotts-v2/v2-sprint-18.1.md"
        assert audit_gate.AUDIT_PATH_TEMPLATE.format(n=18, m=1) == expected

    def test_200_returns_true(self):
        with mock.patch.object(audit_gate, "gh_api", return_value={"name": "v2-sprint-18.1.md"}) as gh:
            assert audit_gate.check_prior_audit_exists("tok", 18, 2) is True
            # Confirm it queried the immediately-preceding sprint (18.1), not
            # the current one (18.2).
            call = gh.call_args
            assert "v2-sprint-18.1.md" in call.args[1]
            assert "v2-sprint-18.2.md" not in call.args[1]
            assert call.kwargs.get("params", {}).get("ref") == "main"

    def test_404_returns_false(self):
        with mock.patch.object(audit_gate, "gh_api", side_effect=audit_gate.GHNotFound("not found")):
            assert audit_gate.check_prior_audit_exists("tok", 18, 2) is False

    def test_outage_propagates(self):
        with mock.patch.object(audit_gate, "gh_api", side_effect=audit_gate.GHUnreachable("down")):
            with pytest.raises(audit_gate.GHUnreachable):
                audit_gate.check_prior_audit_exists("tok", 18, 2)

    def test_immediately_preceding_not_highest_le(self):
        """For (N=18, M=3), the lookup must target v2-sprint-18.2.md even if
        18.1 exists — 'immediately-preceding', not 'highest ≤ N.M'."""
        with mock.patch.object(audit_gate, "gh_api", return_value={}) as gh:
            audit_gate.check_prior_audit_exists("tok", 18, 3)
            path_arg = gh.call_args.args[1]
            assert path_arg.endswith("v2-sprint-18.2.md")


# ---------------------------------------------------------------------------
# Retry / back-off semantics (logic point 5)
# ---------------------------------------------------------------------------

class TestRetryPolicy:
    def test_retry_delays_are_10_30_60(self):
        assert audit_gate.RETRY_DELAYS == (10, 30, 60)

    def test_attempts_count_is_4_total(self):
        """Initial attempt + 3 retries = 4 total urlopen calls before giving up."""
        # Simulate persistent 500 to exhaust retries.
        import urllib.error

        fake_err = urllib.error.HTTPError(
            "https://api.github.com/x", 500, "srv err", {}, None  # type: ignore[arg-type]
        )
        fake_err.read = lambda: b"upstream blip"  # type: ignore[assignment]

        call_count = {"n": 0}

        def fake_urlopen(*_a, **_kw):
            call_count["n"] += 1
            raise fake_err

        with mock.patch("urllib.request.urlopen", side_effect=fake_urlopen), \
             mock.patch("time.sleep"):  # don't actually wait
            with pytest.raises(audit_gate.GHUnreachable):
                audit_gate.gh_api("GET", "/repos/x/y/installation", bearer="jwt")
            assert call_count["n"] == 4, "expected 1 initial + 3 retries"

    def test_404_is_not_retried(self):
        import urllib.error
        err404 = urllib.error.HTTPError(
            "https://api.github.com/x", 404, "nf", {}, None  # type: ignore[arg-type]
        )
        err404.read = lambda: b""  # type: ignore[assignment]
        call_count = {"n": 0}

        def fake_urlopen(*_a, **_kw):
            call_count["n"] += 1
            raise err404

        with mock.patch("urllib.request.urlopen", side_effect=fake_urlopen), \
             mock.patch("time.sleep"):
            with pytest.raises(audit_gate.GHNotFound):
                audit_gate.gh_api("GET", "/repos/x/y/contents/z.md", token="t")
            assert call_count["n"] == 1, "404 must be terminal (no retry)"

    def test_401_is_not_retried(self):
        import urllib.error
        err401 = urllib.error.HTTPError(
            "https://api.github.com/x", 401, "bad", {}, None  # type: ignore[arg-type]
        )
        err401.read = lambda: b"bad token"  # type: ignore[assignment]
        call_count = {"n": 0}

        def fake_urlopen(*_a, **_kw):
            call_count["n"] += 1
            raise err401

        with mock.patch("urllib.request.urlopen", side_effect=fake_urlopen), \
             mock.patch("time.sleep"):
            with pytest.raises(RuntimeError):
                audit_gate.gh_api("GET", "/x", token="t")
            assert call_count["n"] == 1


# ---------------------------------------------------------------------------
# Constants contract — the plan pins these
# ---------------------------------------------------------------------------

class TestContracts:
    def test_audits_repo(self):
        assert audit_gate.AUDITS_REPO == "brott-studio/studio-audits"

    def test_project(self):
        assert audit_gate.PROJECT == "battlebrotts-v2"

    def test_audit_path_shape(self):
        p = audit_gate.AUDIT_PATH_TEMPLATE.format(n=18, m=2)
        assert p == "audits/battlebrotts-v2/v2-sprint-18.2.md"

    def test_arc_path_shape(self):
        assert audit_gate.ARC_PATH_TEMPLATE.format(n=18) == "arcs/arc-18.md"
