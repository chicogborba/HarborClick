"""Turns the cached PixelLab generations into game-ready PNGs.

This is a normal member of `tools/generate_all.sh`: offline, deterministic,
same output every run. The model was called once, by hand, and its answers live
in `pixellab/raw/`. See `pixellab/client.py` for how they get there and
`pixellab/recipes.py` for what was asked.

What comes out:

  * `ui_title_crest` — the mark astride the title plate. Generated at 128 and
    halved rather than generated at 64: the model puts more structure into a
    big canvas, and an exact 2:1 reduction keeps all of it while landing on the
    chunkier pixel size the rest of the UI is drawn at.
  * `ui_title_ship` — the ship at the title's berth, at 1:1 with the backdrop.
  * `ui_berth_a|b|c` — the three terminals on the selection board, one painting
    each instead of a numbered black square.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "pixellab"))

import harmonize as H
from common import save
from PIL import Image

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pixellab", "raw")

INK = (26, 20, 28, 255)
BADGE_EDGE = (128, 78, 18, 255)


def raw(name: str) -> Image.Image:
    path = os.path.join(RAW, name + ".png")
    if not os.path.exists(path):
        raise SystemExit(
            f"missing {path}. Run: PIXELLAB_API_KEY=... "
            f"tools/venv/bin/python tools/sprites/pixellab/client.py {name}")
    return Image.open(path).convert("RGBA")


def crest() -> None:
    art = H.halve(H.harden(raw("crest")))
    save(H.trim(H.snap(art, tolerance=30.0)), "ui_title_crest", 6)


def ship() -> None:
    art = H.trim(H.harden(raw("ship_hero")))
    save(H.snap(art, tolerance=26.0), "ui_title_ship", 2)


def berths() -> None:
    # Snapped harder than the crest: these are little paintings of *the yard*,
    # and the yard has a palette. The frame is the mount, so the art can meet
    # the paper of the board without a raw edge.
    for name, out in (("berth_dawn", "ui_berth_a"), ("berth_busy", "ui_berth_b"),
                      ("berth_night", "ui_berth_c")):
        art = H.snap(H.harden(raw(name)), tolerance=40.0)
        save(H.frame(art, INK, BADGE_EDGE), out, 4)


if __name__ == "__main__":
    print("pixellab assets")
    crest()
    ship()
    berths()
