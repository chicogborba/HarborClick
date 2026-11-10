#!/bin/bash
# Reproducible web build.
#
#   tools/export/build_web.sh [godot-binary]
#
# Needs the export templates for the running Godot version — install them once
# from Editor > Manage Export Templates, or drop the .tpz contents into
# ~/Library/Application Support/Godot/export_templates/<version>/.
#
# The renderer is already gl_compatibility (WebGL2) in project.godot, and the
# preset excludes tools/ and tests/ so the dev probes never ship.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${1:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT="$ROOT/build/web"

if [ ! -x "$GODOT" ] && ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "Godot not found at '$GODOT'. Pass the binary as the first argument." >&2
  exit 1
fi

echo "==> import"
"$GODOT" --headless --path "$ROOT" --import

echo "==> regression"
for suite in core cargo traffic notification contrast a11y backup ui_p0 \
             phase3_economy phase3_progression_ui phase4_ship phase4_water; do
  printf '    %-24s' "$suite"
  if "$GODOT" --headless --path "$ROOT" "res://tests/${suite}_test_runner.tscn" \
      2>&1 | grep -q "TESTS PASSED"; then
    echo "ok"
  else
    echo "FAILED"
    exit 1
  fi
done

echo "==> export"
rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT/index.html"

echo "==> done: $OUT"
echo "    The export runs without threads, so no COOP/COEP are needed."
echo "    Serve it locally with: python3 tools/export/serve_web.py"
