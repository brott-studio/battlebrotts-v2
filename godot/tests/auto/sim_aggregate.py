#!/usr/bin/env python3
"""
sim_aggregate.py — Aggregate combat sim JSON results into a Markdown report.

Usage:
    python3 sim_aggregate.py RESULTS_DIR [--output REPORT_FILE]
                                         [--seed-base N] [--n-runs N]
"""

import argparse
import json
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from statistics import median

SCHEMA_VERSION = 1
BALANCE_MIN = 0.30
BALANCE_MAX = 0.70
BALANCE_MIN_RUNS = 5


def load_results(results_dir: Path) -> tuple[list[dict], dict]:
    """Returns (valid_runs, error_counts)."""
    error_counts = {"parse_errors": 0, "schema_skips": 0, "missing_fields": 0}
    valid_runs = []
    required_fields = {
        "schema_version", "seed", "chassis", "chassis_name",
        "battles_won", "battles_lost", "total_ticks",
        "terminal_state", "wall_clock_seconds",
    }
    for f in sorted(results_dir.glob("run_*.json")):
        try:
            with open(f) as fh:
                data = None
                for line in fh:
                    line = line.strip()
                    if line.startswith('{'):
                        try:
                            data = json.loads(line)
                            break
                        except json.JSONDecodeError:
                            continue
        except OSError:
            error_counts["parse_errors"] += 1
            continue
        if data is None:
            error_counts["parse_errors"] += 1
            continue
        if data.get("schema_version") != SCHEMA_VERSION:
            error_counts["schema_skips"] += 1
            continue
        missing = required_fields - data.keys()
        if missing:
            error_counts["missing_fields"] += 1
            continue
        valid_runs.append(data)
    return valid_runs, error_counts


def aggregate(runs: list[dict]) -> dict:
    """Returns per-chassis and overall stats dict."""
    if not runs:
        return {}
    by_chassis: dict[str, list[dict]] = defaultdict(list)
    for r in runs:
        by_chassis[r["chassis_name"]].append(r)

    def chassis_stats(group: list[dict]) -> dict:
        n = len(group)
        wins = sum(1 for r in group if r["terminal_state"] == "win")
        deaths = sum(1 for r in group if r["terminal_state"] == "death")
        timeouts = sum(1 for r in group if r["terminal_state"] == "timeout")
        total_battles_won = sum(r["battles_won"] for r in group)
        total_battles_lost = sum(r["battles_lost"] for r in group)
        total_battles = total_battles_won + total_battles_lost
        return {
            "runs": n,
            "win_rate": wins / n,
            "death_rate": deaths / n,
            "timeout_rate": timeouts / n,
            "median_battles_won": median(r["battles_won"] for r in group),
            "median_total_ticks": median(r["total_ticks"] for r in group),
            "median_wall_clock_s": median(r["wall_clock_seconds"] for r in group),
            "battle_win_rate": total_battles_won / total_battles if total_battles > 0 else 0.0,
        }

    result = {}
    for name, group in sorted(by_chassis.items()):
        result[name] = chassis_stats(group)
    result["ALL"] = chassis_stats(runs)
    return result


def _append_failures(lines: list, error_counts: dict) -> None:
    lines.append("## Failures")
    lines.append("")
    lines.append(f"- Parse errors: {error_counts.get('parse_errors', 0)}")
    lines.append(f"- Schema skips (version mismatch): {error_counts.get('schema_skips', 0)}")
    lines.append(f"- Missing fields: {error_counts.get('missing_fields', 0)}")
    lines.append("")


def render_markdown(stats: dict, meta: dict) -> str:
    """Returns the full Markdown report string."""
    now = meta.get("generated_at", datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M"))
    date_str = meta.get("date", now[:10])
    runs_collected = meta.get("runs_collected", 0)
    runs_attempted = meta.get("runs_attempted", runs_collected)
    seed_base = meta.get("seed_base", "auto")
    error_counts = meta.get("error_counts", {})

    lines = [
        f"# Combat Sim Report — {date_str}",
        "",
        f"**Generated:** {now} UTC  ",
        f"**Runs collected:** {runs_collected} (of {runs_attempted} attempted)  ",
        f"**Seed base:** {seed_base}",
        "",
    ]

    if not stats:
        lines.append("_No valid runs collected._")
        lines.append("")
        _append_failures(lines, error_counts)
        return "\n".join(lines)

    lines.append("## Per-chassis aggregates")
    lines.append("")
    lines.append(
        "| Chassis | Runs | Run win % | Battle win % | Death % | Timeout % | "
        "Median battles won | Median ticks | Median wall-clock (s) |"
    )
    lines.append("|---|---|---|---|---|---|---|---|---|")

    chassis_names = [k for k in stats if k != "ALL"]
    for name in sorted(chassis_names):
        s = stats[name]
        lines.append(
            f"| {name} | {s['runs']} | {s['win_rate']*100:.1f}% | "
            f"{s['battle_win_rate']*100:.1f}% | {s['death_rate']*100:.1f}% | "
            f"{s['timeout_rate']*100:.1f}% | {s['median_battles_won']:.1f} | "
            f"{s['median_total_ticks']:.0f} | {s['median_wall_clock_s']:.3f} |"
        )
    if "ALL" in stats:
        s = stats["ALL"]
        lines.append(
            f"| **ALL** | {s['runs']} | {s['win_rate']*100:.1f}% | "
            f"{s['battle_win_rate']*100:.1f}% | {s['death_rate']*100:.1f}% | "
            f"{s['timeout_rate']*100:.1f}% | {s['median_battles_won']:.1f} | "
            f"{s['median_total_ticks']:.0f} | {s['median_wall_clock_s']:.3f} |"
        )
    lines.append("")

    lines.append("## ⚠️ Balance flags")
    lines.append("")
    flags = []
    for name in sorted(chassis_names):
        s = stats[name]
        if s["runs"] >= BALANCE_MIN_RUNS:
            wr = s["win_rate"]
            if wr < BALANCE_MIN:
                flags.append(f"- **{name}**: run win-rate {wr*100:.1f}% (below {BALANCE_MIN*100:.0f}% floor)")
            elif wr > BALANCE_MAX:
                flags.append(f"- **{name}**: run win-rate {wr*100:.1f}% (above {BALANCE_MAX*100:.0f}% ceiling)")
    if flags:
        lines.extend(flags)
    else:
        lines.append("_No balance issues detected._")
    lines.append("")

    _append_failures(lines, error_counts)
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Aggregate combat sim results into a Markdown report.")
    parser.add_argument("results_dir", type=Path, help="Directory containing run_NNN.json files")
    parser.add_argument("--output", type=Path, default=None, help="Output file (default: stdout)")
    parser.add_argument("--seed-base", default="auto", help="Seed base used for this run")
    parser.add_argument("--n-runs", type=int, default=None, help="Number of runs attempted")
    args = parser.parse_args()

    if not args.results_dir.is_dir():
        print(f"ERROR: results_dir '{args.results_dir}' not found.", file=sys.stderr)
        sys.exit(1)

    valid_runs, error_counts = load_results(args.results_dir)
    stats = aggregate(valid_runs)
    now = datetime.now(timezone.utc)
    meta = {
        "generated_at": now.strftime("%Y-%m-%d %H:%M"),
        "date": now.strftime("%Y-%m-%d"),
        "runs_collected": len(valid_runs),
        "runs_attempted": args.n_runs if args.n_runs is not None else len(valid_runs),
        "seed_base": args.seed_base,
        "error_counts": error_counts,
    }
    report = render_markdown(stats, meta)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report)
        print(f"Report written to {args.output}", file=sys.stderr)
    else:
        print(report)


if __name__ == "__main__":
    main()
