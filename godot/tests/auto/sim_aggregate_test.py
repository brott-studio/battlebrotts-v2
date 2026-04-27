#!/usr/bin/env python3
"""Unit tests for sim_aggregate.py"""

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sim_aggregate import load_results, aggregate, render_markdown, BALANCE_MIN_RUNS


def _make_run(
    chassis_name="SCOUT", chassis=0, terminal_state="win",
    battles_won=7, battles_lost=1, total_ticks=10000,
    wall_clock_seconds=20.0, seed=1, schema_version=1,
) -> dict:
    return {
        "schema_version": schema_version,
        "seed": seed,
        "chassis": chassis,
        "chassis_name": chassis_name,
        "battles_won": battles_won,
        "battles_lost": battles_lost,
        "total_ticks": total_ticks,
        "terminal_state": terminal_state,
        "reward_picks": [],
        "final_loadout": {},
        "wall_clock_seconds": wall_clock_seconds,
    }


def _write_run(directory: Path, index: int, data: dict) -> None:
    (directory / f"run_{index:03d}.json").write_text(json.dumps(data))


class TestLoadResults(unittest.TestCase):
    def test_empty_dir(self):
        with tempfile.TemporaryDirectory() as d:
            runs, errs = load_results(Path(d))
        self.assertEqual(runs, [])
        self.assertEqual(errs["parse_errors"], 0)

    def test_malformed_json(self):
        with tempfile.TemporaryDirectory() as d:
            dp = Path(d)
            (dp / "run_000.json").write_text("{not valid json}")
            _write_run(dp, 1, _make_run())
            runs, errs = load_results(dp)
        self.assertEqual(len(runs), 1)
        self.assertEqual(errs["parse_errors"], 1)

    def test_schema_mismatch(self):
        with tempfile.TemporaryDirectory() as d:
            dp = Path(d)
            _write_run(dp, 0, _make_run(schema_version=99))
            runs, errs = load_results(dp)
        self.assertEqual(len(runs), 0)
        self.assertEqual(errs["schema_skips"], 1)


class TestAggregate(unittest.TestCase):
    def test_empty_runs(self):
        stats = aggregate([])
        self.assertEqual(stats, {})

    def test_zero_battles(self):
        runs = [_make_run(battles_won=0, battles_lost=0, seed=i) for i in range(3)]
        try:
            stats = aggregate(runs)
            self.assertAlmostEqual(stats["SCOUT"]["battle_win_rate"], 0.0)
        except ZeroDivisionError:
            self.fail("aggregate() raised ZeroDivisionError on zero battles")

    def test_win_rate_calculation(self):
        runs = (
            [_make_run(terminal_state="win", seed=i) for i in range(3)] +
            [_make_run(terminal_state="death", seed=i+100) for i in range(7)]
        )
        stats = aggregate(runs)
        self.assertAlmostEqual(stats["SCOUT"]["win_rate"], 0.30)
        self.assertAlmostEqual(stats["SCOUT"]["death_rate"], 0.70)


class TestBalanceFlags(unittest.TestCase):
    def _render(self, runs):
        stats = aggregate(runs)
        meta = {"runs_collected": len(runs), "runs_attempted": len(runs), "error_counts": {}}
        return render_markdown(stats, meta)

    def _flags_block(self, report):
        return report.split("## ⚠️ Balance flags")[1].split("## Failures")[0]

    def test_flag_below_30(self):
        # 0% win rate with 6 runs → flagged
        runs = [_make_run(terminal_state="death", seed=i) for i in range(6)]
        report = self._render(runs)
        self.assertIn("**SCOUT**", self._flags_block(report))
        self.assertIn("below", self._flags_block(report))

    def test_flag_above_70(self):
        # 100% win rate with 6 runs → flagged
        runs = [_make_run(terminal_state="win", seed=i) for i in range(6)]
        report = self._render(runs)
        self.assertIn("**SCOUT**", self._flags_block(report))
        self.assertIn("above", self._flags_block(report))

    def test_no_flag_at_exactly_30(self):
        # Exactly 30%: 3 wins / 10 runs → NOT flagged (strict <)
        runs = (
            [_make_run(terminal_state="win", seed=i) for i in range(3)] +
            [_make_run(terminal_state="death", seed=i+100) for i in range(7)]
        )
        report = self._render(runs)
        self.assertNotIn("**SCOUT**", self._flags_block(report))

    def test_no_flag_at_exactly_70(self):
        # Exactly 70%: 7 wins / 10 runs → NOT flagged (strict >)
        runs = (
            [_make_run(terminal_state="win", seed=i) for i in range(7)] +
            [_make_run(terminal_state="death", seed=i+100) for i in range(3)]
        )
        report = self._render(runs)
        self.assertNotIn("**SCOUT**", self._flags_block(report))

    def test_insufficient_data_no_flag(self):
        # 4 runs at 0% → NOT flagged (runs < BALANCE_MIN_RUNS=5)
        runs = [_make_run(terminal_state="death", seed=i) for i in range(BALANCE_MIN_RUNS - 1)]
        report = self._render(runs)
        self.assertNotIn("**SCOUT**", self._flags_block(report))

    def test_no_valid_runs_no_crash(self):
        report = render_markdown({}, {"runs_collected": 0, "runs_attempted": 0, "error_counts": {}})
        self.assertIn("No valid runs collected", report)


if __name__ == "__main__":
    unittest.main()
