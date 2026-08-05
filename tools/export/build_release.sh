#!/bin/bash
# Build the Godot Web game and assemble the static landing page in one release.
#
#   tools/export/build_release.sh [godot-binary]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/build/release"

"$ROOT/tools/export/build_web.sh" "${1:-/Applications/Godot.app/Contents/MacOS/Godot}"

rm -rf "$OUT"
mkdir -p "$OUT/jogar" "$OUT/media"
cp "$ROOT/landing/index.html" "$OUT/index.html"
cp "$ROOT/landing/styles.css" "$OUT/styles.css"
cp "$ROOT/landing/script.js" "$OUT/script.js"
cp "$ROOT/landing/assets/"* "$OUT/media/"
cp -R "$ROOT/build/web/." "$OUT/jogar/"

echo "==> release ready: $OUT"
