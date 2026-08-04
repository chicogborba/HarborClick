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
"$PYTHON" tools/docs/generate_code_map.py --check
"$GODOT" --headless --quiet --path . --editor --quit

scenes=(
  core cargo ui_p0 phase3_economy phase3_progression_ui
  phase4_ship phase4_water traffic notification contrast a11y
  backup profile automation gate wake route npc special relay
)

for suite in "${scenes[@]}"; do
  echo "[qa] $suite"
  "$GODOT" --headless --quiet --path . "res://tests/${suite}_test_runner.tscn"
done

echo "[qa] phase3_progression"
"$GODOT" --headless --quiet --path . \
  --script res://tests/phase3_progression_test_runner.gd

echo "[qa] all checks passed"
