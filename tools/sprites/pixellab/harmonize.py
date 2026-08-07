"""Making a generated sprite a citizen of this game rather than a visitor.

A model answers with its own pigments, its own idea of an outline and a canvas
of whatever size was asked for. Four passes fix that, and they are separate
because different assets need different subsets:

  * `snap` pulls every colour to the nearest one HarborClick already paints
    with — but only if it is close enough to be the same intent. A gold that
    lands 6 units from the game's gold becomes the game's gold; a colour with
    no neighbour is left alone rather than dragged somewhere wrong.
  * `harden` kills partial alpha. Pixel art with soft edges shimmers under
    nearest-neighbour scaling.
  * `trim` crops the transparent margin a fixed canvas leaves around a subject,
    so layout code positions the drawing and not the padding.
  * `halve` is the only resize allowed: exact 2:1, nearest. Any other ratio
    invents pixels that were never drawn.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import palette as P  # noqa: E402
from PIL import Image  # noqa: E402


def _game_colors() -> list[tuple[int, int, int]]:
    """Every opaque pigment the hand-drawn sprites already use."""
    found: list[tuple[int, int, int]] = []
    for name in dir(P):
        if name.startswith("_"):
            continue
        value = getattr(P, name)
        if isinstance(value, tuple) and len(value) == 4 and value[3] == 255:
            found.append(value[:3])
        elif isinstance(value, dict):
            for pair in value.values():
                if isinstance(pair, tuple):
                    for color in pair:
                        if isinstance(color, tuple) and len(color) == 4:
                            found.append(color[:3])
    return found


# The UI's own enamel and lamp colours are not in `palette.py` — that module is
# the world's. A crest sits on the UI, so it has to be able to land on both.
UI_COLORS = [
    (16, 22, 34), (28, 37, 54), (42, 54, 74), (58, 44, 46), (34, 30, 44),
    (28, 80, 80), (44, 116, 110), (104, 194, 176),
    (128, 78, 18), (252, 202, 96), (252, 226, 168),
    (176, 190, 212), (226, 232, 242),
    (206, 188, 156), (238, 224, 198), (250, 240, 218),
]
GAME_COLORS = sorted(set(_game_colors() + UI_COLORS))


def _distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    """Weighted RGB — green carries most of perceived brightness, so an
    unweighted distance happily swaps a warm grey for a green one."""
    dr, dg, db = a[0] - b[0], a[1] - b[1], a[2] - b[2]
    return 0.30 * dr * dr + 0.59 * dg * dg + 0.11 * db * db


def snap(img: Image.Image, tolerance: float = 34.0) -> Image.Image:
    """Pull colours onto the game's palette when they are near enough to it.

    `tolerance` is in weighted-RGB units, so 34 is roughly "a human would call
    these the same colour". Raising it recolours the art; lowering it leaves it
    as the model drew it."""
    img = img.convert("RGBA")
    limit = tolerance * tolerance
    mapping: dict[tuple, tuple] = {}
    out = img.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            source = pixels[x, y]
            if source[3] == 0:
                continue
            if source not in mapping:
                best = min(GAME_COLORS, key=lambda c: _distance(source[:3], c))
                near = _distance(source[:3], best) <= limit
                mapping[source] = (best + (source[3],)) if near else source
            pixels[x, y] = mapping[source]
    return out


def harden(img: Image.Image, threshold: int = 128) -> Image.Image:
    img = img.convert("RGBA")
    out = img.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (r, g, b, 255 if a >= threshold else 0)
    return out


def trim(img: Image.Image, pad: int = 0) -> Image.Image:
    box = img.getbbox()
    if box is None:
        return img
    left, top, right, bottom = box
    left = max(0, left - pad)
    top = max(0, top - pad)
    right = min(img.width, right + pad)
    bottom = min(img.height, bottom + pad)
    return img.crop((left, top, right, bottom))


def halve(img: Image.Image) -> Image.Image:
    return img.resize((img.width // 2, img.height // 2), Image.NEAREST)


def dim(img: Image.Image, k: float, tint: tuple[int, int, int] = (20, 26, 46),
        mix: float = 0.0) -> Image.Image:
    """Night. Multiplying towards a cool tint is what the title backdrop does to
    every hand-drawn colour, so generated art has to go through the same dusk to
    sit in the same picture."""
    out = img.convert("RGBA").copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            r, g, b = int(r * k), int(g * k), int(b * k)
            if mix > 0.0:
                r = int(r * (1 - mix) + tint[0] * mix)
                g = int(g * (1 - mix) + tint[1] * mix)
                b = int(b * (1 - mix) + tint[2] * mix)
            pixels[x, y] = (r, g, b, a)
    return out


def frame(img: Image.Image, ink: tuple[int, int, int, int],
          inner: tuple[int, int, int, int] | None = None) -> Image.Image:
    """A mounted photograph: ink border, optional highlight inside it. A square
    of art dropped on a card looks unfinished; the same square with an edge
    looks placed."""
    out = img.convert("RGBA").copy()
    pixels = out.load()
    w, h = out.size
    for x in range(w):
        pixels[x, 0] = ink
        pixels[x, h - 1] = ink
    for y in range(h):
        pixels[0, y] = ink
        pixels[w - 1, y] = ink
    if inner is not None:
        for x in range(1, w - 1):
            pixels[x, 1] = inner
        for y in range(1, h - 1):
            pixels[1, y] = inner
    return out
