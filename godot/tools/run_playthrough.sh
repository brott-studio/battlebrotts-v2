#!/bin/bash
# Run the BattleBrotts test harness playthrough
# Usage: ./run_playthrough.sh [commands.json]
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT_DIR="$(dirname "$SCRIPT_DIR")"
CMD_FILE="${1:-res://tools/playthrough.json}"

cd "$GODOT_DIR"

echo "=== BattleBrotts Test Harness ==="
echo "Commands: $CMD_FILE"
echo "================================="

# Clean previous screenshots
rm -f tools/screenshots/*.png

# Run headless
godot --headless --script res://tools/test_harness.gd -- "$CMD_FILE"

echo ""
echo "Screenshots saved to tools/screenshots/"
ls -la tools/screenshots/ 2>/dev/null || echo "(no screenshots found)"
