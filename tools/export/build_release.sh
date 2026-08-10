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
for page in index.html styles.css script.js i18n.js; do
  cp "$ROOT/landing/$page" "$OUT/$page"
done
cp "$ROOT/landing/assets/"* "$OUT/media/"
cp -R "$ROOT/build/web/." "$OUT/jogar/"

echo "==> release ready: $OUT"
