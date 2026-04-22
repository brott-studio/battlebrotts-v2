#!/usr/bin/env python3
"""Unit tests for optic_verified.build_check_run_body — pure-function checks
for the JWT mint + POST-body construction contract in the S18.4-001 brief.

The JWT mint itself is exercised implicitly by the live workflow; here we
assert the body contract (name/status/conclusion mapping, output shape)
deterministically without network I/O.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

# Import sibling module.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import optic_verified as ov  # noqa: E402


class BuildCheckRunBodyTests(unittest.TestCase):
    SHA = "a" * 40

    def _assert_common(self, body: dict) -> None:
        self.assertEqual(body["name"], "Optic Verified")
        self.assertEqual(body["status"], "completed")
        self.assertEqual(body["head_sha"], self.SHA)
        self.assertIn("output", body)
        self.assertEqual(body["output"]["title"], "Optic verification")
        self.assertIsInstance(body["output"]["summary"], str)
        self.assertTrue(body["output"]["summary"])

    def test_success_maps_to_success(self) -> None:
        body = ov.build_check_run_body(self.SHA, "success")
        self._assert_common(body)
        self.assertEqual(body["conclusion"], "success")
        self.assertIn("PASS", body["output"]["summary"])

    def test_failure_maps_to_failure(self) -> None:
        body = ov.build_check_run_body(self.SHA, "failure")
        self._assert_common(body)
        self.assertEqual(body["conclusion"], "failure")
        self.assertIn("FAIL", body["output"]["summary"])

    def test_cancelled_maps_to_failure(self) -> None:
        body = ov.build_check_run_body(self.SHA, "cancelled")
        self.assertEqual(body["conclusion"], "failure")

    def test_timed_out_maps_to_failure(self) -> None:
        body = ov.build_check_run_body(self.SHA, "timed_out")
        self.assertEqual(body["conclusion"], "failure")

    def test_neutral_maps_to_failure(self) -> None:
        # Binary PASS/FAIL per optic.md — only "success" is success.
        body = ov.build_check_run_body(self.SHA, "neutral")
        self.assertEqual(body["conclusion"], "failure")

    def test_empty_conclusion_maps_to_failure(self) -> None:
        body = ov.build_check_run_body(self.SHA, "")
        self.assertEqual(body["conclusion"], "failure")

    def test_html_url_included_in_summary(self) -> None:
        url = "https://github.com/brott-studio/battlebrotts-v2/actions/runs/123"
        body = ov.build_check_run_body(self.SHA, "failure", url)
        self.assertIn(url, body["output"]["summary"])

    def test_exact_name_string(self) -> None:
        # Acceptance criterion #3: name: "Optic Verified" (exact).
        body = ov.build_check_run_body(self.SHA, "success")
        self.assertEqual(body["name"], "Optic Verified")

    def test_body_json_serialisable(self) -> None:
        import json
        body = ov.build_check_run_body(self.SHA, "success")
        json.dumps(body)  # must not raise


if __name__ == "__main__":
    unittest.main()
