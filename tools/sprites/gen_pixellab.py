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
  * `prop_duck` — the giant inflatable the shop sells. A joke asset still has to
    be a well drawn one, and a shape this simple is all silhouette.
  * `ui_medal_*` — one struck coin per achievement category. Eight medallions
    that have to read as a *set* is the second thing worth generating: one
    shared style sentence buys the same rim, metal and light on all of them.
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


def duck() -> None:
    ## The one decoration a player can moor in their own harbour, and the only
    ## sprite in the yard drawn from slightly above rather than straight down —
    ## which is right for it: an inflatable that size has a *side* to see.
    art = H.trim(H.harden(raw("duck")))
    save(H.snap(art, tolerance=34.0), "prop_duck", 4)


## The eight achievement categories, in the order the tree shows them.
MEDALS = ["teu", "ships", "structures", "cargo", "critical", "events",
          "routes", "terrain", "collection", "contracts", "prestige",
          "tutorial"]


def medals() -> None:
    """One coin per achievement category, halved to 32 and left alone.

    Snapped only lightly: these are the one place in the game where *gold* is
    the subject rather than an accent, and pulling a struck-metal ramp onto the
    yard's four ambers flattens the relief that makes them read as coins. The
    rim the model draws is the outline, so no frame is added — a medallion with
    a square border round it is a sticker of a medallion.
    """
    for key in MEDALS:
        art = H.trim(H.halve(H.harden(raw("medal_" + key))))
        # Every coin on the same 32x32 blank, centred. Trimmed to their own
        # bounds they came out 28 to 31 across, and a row of medallions that
        # each sit a pixel differently reads as a row that is slightly broken.
        coin = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        coin.alpha_composite(H.snap(art, tolerance=18.0),
                             ((32 - art.width) // 2, (32 - art.height) // 2))
        save(coin, "ui_medal_" + key, 6)


## The port's cats, by candidate index in `raw/cats/` (one create_image_pro
## call, 64 answers). Loafers first — they nap on the stacks — then sitters.
CATS = [7, 17, 26, 5, 33, 35, 44, 30, 0, 11, 3, 36]
CAT_CELL = 24


def cats() -> None:
    """Twelve cats on one strip of 24x24 cells, bottom-aligned.

    They replace a hand-drawn 14x12 ellipse with two dots for eyes that read as
    a potato. A cat is all silhouette — ears, loaf, tail — and that is exactly
    the kind of drawing a loop is bad at and the model is good at.
    """
    strip = Image.new("RGBA", (CAT_CELL * len(CATS), CAT_CELL), (0, 0, 0, 0))
    for i, idx in enumerate(CATS):
        art = H.trim(H.harden(raw(f"cats/cat_{idx}")))
        x = i * CAT_CELL + (CAT_CELL - art.width) // 2
        strip.alpha_composite(art, (x, CAT_CELL - art.height))
    save(strip, "prop_cats", 6)


## Staff photographs, by candidate index in `raw/portraits/` (one
## create_image_pro call, 25 answers). The first half is drawn masculine and the
## second feminine — `UiTheme.portrait_index` picks the half by the person.
FACES_M = [0, 2, 4, 8, 9, 11, 13, 15, 17, 19, 21, 23]
FACES_F = [1, 3, 5, 7, 10, 12, 14, 16, 18, 20, 22, 24]
FACE = 48


def portraits() -> None:
    """The badge photographs: 24 people at 48x48 on one strip.

    They replace eight 24x28 faces drawn by code — two dots, a line and a hat —
    which were the right size for a sprite and the wrong size for the biggest
    thing on a staff card. Not snapped: a face is skin ramps, and the UI palette
    has none, so pulling it onto the yard's colours turns everybody grey.
    """
    order = FACES_M + FACES_F
    strip = Image.new("RGBA", (FACE * len(order), FACE), (0, 0, 0, 0))
    for i, idx in enumerate(order):
        strip.alpha_composite(H.harden(raw(f"portraits/face_{idx}")), (i * FACE, 0))
    save(strip, "portrait_photos", 3)


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
    duck()
    medals()
    cats()
    portraits()
    berths()
