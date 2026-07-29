#!/bin/bash
# Regenerate all HarborClick assets (sprites + audio).
set -e
cd "$(dirname "$0")/sprites"
PY="../venv/bin/python"
for f in gen_*.py; do
  "$PY" "$f"
done
if [ -d ../audio ]; then
  cd ../audio
  for f in gen_*.py; do
    [ -e "$f" ] && "$PY" "$f"
  done
fi
echo "done."
