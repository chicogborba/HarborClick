#!/bin/bash
# Regenerate all HarborClick assets (sprites + audio).
set -e
cd "$(dirname "$0")/sprites"
PY="../venv/bin/python"
for f in gen_*.py; do
  [ "$f" = "gen_landing.py" ] && continue
  "$PY" "$f"
done
# The landing composes its art out of the sprites above, so it goes last.
"$PY" gen_landing.py
if [ -d ../audio ]; then
  cd ../audio
  for f in gen_*.py; do
    [ -e "$f" ] && "$PY" "$f"
  done
fi
echo "done."
