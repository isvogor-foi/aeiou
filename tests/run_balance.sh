#!/usr/bin/env bash
# Runs the balance harness in parallel and prints the summary.
#   tests/run_balance.sh <out_dir> [games_per_worker] [workers] [difficulty] [max_minutes]
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=${1:?out dir}
PER=${2:-3}
WORKERS=${3:-6}
DIFF=${4:-normal}
MAX=${5:-60}
mkdir -p "$OUT"
for w in $(seq 0 $((WORKERS - 1))); do
	tools/godot --headless --path . -s tests/balance.gd -- $((1000 + w * PER)) "$PER" "$DIFF" "$MAX" \
		> "$OUT/worker_$w.log" 2>&1 &
done
wait
python3 tests/balance_report.py "$OUT"/worker_*.log
