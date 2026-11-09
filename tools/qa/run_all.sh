#!/bin/bash
# Documentation freshness, import check and every deterministic headless suite.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [ ! -x "$GODOT" ]; then
  GODOT="${GODOT_BIN:-godot}"
fi

PYTHON="$ROOT/tools/venv/bin/python"
if [ ! -x "$PYTHON" ]; then
  PYTHON="${PYTHON_BIN:-python3}"
fi
"$PYTHON" tools/docs/generate_code_map.py --check
# The landing has no Godot suite, and a key renamed on one side of it publishes
# the key itself to the front page in nine languages.
"$PYTHON" tools/qa/check_landing_strings.py
# Import before the suites, and *fail* if it could not: a suite whose sprite the
# importer has never seen does not fail cleanly — see run_suite below.
"$GODOT" --headless --quiet --path . --editor --quit

# A GDScript runtime error does not raise. It prints, aborts the function it
# happened in, and returns to the caller as though that function had finished,
# so a runner that counts only the assertions it was handed will print PASSED
# with stack traces above it. That is not hypothetical: two rail tests spent a
# build silently not running because `preload` was failing on a PNG that had no
# `.import` yet, and the suite reported success and exited 0.
#
# Individual runners defend themselves where they can — `rail_test_runner.gd`
# keeps a roll call of tests that reached their last line. This is the backstop
# that covers every suite at once and needs nothing from them: any engine-level
# script error in a run is a failed run, whatever the runner thought.
run_suite() {
  local label="$1"
  shift
  echo "[qa] $label"
  local log
  log="$(mktemp)"
  local status=0
  "$@" >"$log" 2>&1 || status=$?
  cat "$log"
  if [ "$status" -ne 0 ]; then
    rm -f "$log"
    echo "[qa] FAILED: $label exited $status" >&2
    return "$status"
  fi
  # "SCRIPT ERROR" is the engine's own prefix for a parse, compile or runtime
  # script fault. Deliberately not "ERROR", which is what `push_error` emits —
  # runners use that to report their own assertion failures, and they already
  # exit non-zero when they do.
  if grep -q "SCRIPT ERROR" "$log"; then
    echo "[qa] FAILED: $label reported a script error while claiming success" >&2
    grep -n "SCRIPT ERROR" "$log" >&2
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
}

scenes=(
  core cargo ui_p0 phase3_economy phase3_progression_ui
  phase4_ship phase4_water traffic notification contrast a11y
  backup profile automation gate rail wake route route_ui npc special relay
  i18n settings wheel gull clicks daily
)

for suite in "${scenes[@]}"; do
  run_suite "$suite" \
    "$GODOT" --headless --quiet --path . "res://tests/${suite}_test_runner.tscn"
done

run_suite phase3_progression \
  "$GODOT" --headless --quiet --path . \
  --script res://tests/phase3_progression_test_runner.gd

echo "[qa] all checks passed"
