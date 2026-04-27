#!/usr/bin/env bash
# sim_runner.sh — Run N parallel headless combat sims, collect JSON output.
#
# Usage: ./sim_runner.sh [N=10] [SEED_BASE=auto]
#   N          number of parallel runs (default 10)
#   SEED_BASE  starting seed (default: unix time)
#
# Output: per-run JSON in /tmp/sim_results_YYYYMMDD_HHMMSS/run_NNN.json
#         summary line to stdout on completion
#
# Env: GODOT — path to godot binary (default: godot)

set -euo pipefail

N=${1:-10}
SEED_BASE=${2:-$(date +%s)}
GODOT=${GODOT:-godot}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_PROJECT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)/godot"
RESULTS_DIR="/tmp/sim_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${RESULTS_DIR}"

echo "[sim_runner] N=${N} SEED_BASE=${SEED_BASE} results=${RESULTS_DIR}"

PIDS=()
for i in $(seq 0 $((N - 1))); do
    SEED=$(( SEED_BASE + i ))
    OUT="${RESULTS_DIR}/run_$(printf '%03d' ${i}).json"
    LOG="${RESULTS_DIR}/run_$(printf '%03d' ${i}).log"
    "${GODOT}" --headless --path "${GODOT_PROJECT_DIR}" \
        --script "res://tests/auto/sim_single_run.gd" \
        -- --seed="${SEED}" \
        > "${OUT}" 2>"${LOG}" &
    PIDS+=($!)
done

FAILED=0
for i in "${!PIDS[@]}"; do
    PID="${PIDS[$i]}"
    if wait "${PID}"; then
        : # ok
    else
        EXIT_CODE=$?
        if [[ "${EXIT_CODE}" == "2" ]]; then
            echo "[sim_runner] run ${i} TIMEOUT (exit 2)"
        else
            echo "[sim_runner] run ${i} FAILED (exit ${EXIT_CODE})"
        fi
        FAILED=$((FAILED + 1))
    fi
done

TOTAL_RUNS=$(ls "${RESULTS_DIR}"/run_*.json 2>/dev/null | wc -l)
echo "[sim_runner] Done: ${TOTAL_RUNS}/${N} runs collected, ${FAILED} failed"
echo "[sim_runner] Results: ${RESULTS_DIR}"

exit "${FAILED}"
