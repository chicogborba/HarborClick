"""What HarborClick asks a pixel-art model for, and why it asks a model at all.

Almost every PNG in this game is drawn by code, because code is the only way to
keep a hundred sprites honest to one palette. That breaks down for exactly one
kind of art: the *illustrated* piece — a crest, a badge, a painting of a place —
where the value is in the drawing and a nested loop is the wrong instrument.
Those live here.

Two rules keep a generated asset from looking like a guest:

  * every request carries `PALETTE_STRIP` as a forced colour image, so the model
    picks from the game's pigments rather than inventing its own;
  * `gen_pixellab.py` snaps the answer to the nearest UI colour afterwards
    anyway, because "forced palette" is guidance, not a contract.

`seed` is set on every recipe. A recipe with a fixed seed and a cached answer
is as reproducible as the drawing code beside it.
"""
from __future__ import annotations

import base64
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from PIL import Image  # noqa: E402

# The UI's own colours, from `UiTheme` — navy enamel, amber lamp, cream paper,
# teal, harbour steel — plus the warm ink the sprites are outlined in.
PALETTE = [
    (16, 22, 34), (28, 37, 54), (42, 54, 74), (58, 44, 46),
    (28, 80, 80), (44, 116, 110), (104, 194, 176),
    (128, 78, 18), (198, 134, 40), (252, 202, 96), (252, 226, 168),
    (150, 60, 48), (200, 92, 78), (232, 138, 112),
    (94, 90, 104), (130, 126, 138), (176, 190, 212), (226, 232, 242),
    (206, 188, 156), (238, 224, 198), (250, 240, 218),
    (62, 126, 158), (92, 158, 184), (168, 214, 224),
]


def _palette_strip() -> str:
    """The palette as a base64 PNG — one pixel per colour is enough."""
    strip = Image.new("RGB", (len(PALETTE), 1))
    strip.putdata(PALETTE)
    buffer = io.BytesIO()
    strip.save(buffer, format="PNG")
    return base64.b64encode(buffer.getvalue()).decode()


PALETTE_STRIP = _palette_strip()

# Said on every request. The model is being asked to join a style, not to start
# one, and naming the light direction matters as much as naming the colours.
STYLE = ("pixel art, warm earthy game palette of navy, amber gold, teal and "
         "cream, soft dark plum outline, light from the upper left, no text, "
         "no letters, centered, transparent background")


SPRITES = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "..",
    "assets", "sprites"))


def _init_from(name: str, scale: int = 2) -> tuple[str, int, int]:
    """An existing sprite as the seed for its own replacement.

    This is the answer to the one thing the model would not do: a plan view.
    Asked in words for a gantry crane "seen from directly above" it returns a
    side elevation every time, whatever the phrasing — but handed the game's own
    top-down sprite as an init image it keeps the projection and spends its
    effort on the plating, the shadows and the detail instead.

    Doubled first, because the model puts more structure into a bigger canvas
    and `gen_pixellab.py` halves the answer back down. The floor matters too:
    the API refuses anything under 32x32 of area, and a locomotive is 22x46."""
    art = Image.open(os.path.join(SPRITES, name + ".png")).convert("RGBA")
    big = art.resize((art.width * scale, art.height * scale), Image.NEAREST)
    # Sent with its alpha intact, and asked for the answer the same way. The
    # first attempt flattened these onto asphalt so the model would not treat
    # the hole as scenery to fill — and got back machines with an opaque grey
    # rectangle welded around them, which is worse than either problem.
    buffer = io.BytesIO()
    big.save(buffer, format="PNG")
    return base64.b64encode(buffer.getvalue()).decode(), big.width, big.height


def _remake(name: str, prompt: str, seed: int, keep: int = 130,
            scale: int = 2) -> dict:
    """Redraw one of the game's own machines, at twice its size."""
    init, width, height = _init_from(name, scale)
    return {
        "prompt": f"{prompt}. {STYLE}",
        "width": width,
        "height": height,
        "seed": seed,
        "palette": PALETTE_STRIP,
        "text_guidance_scale": 8,
        "init_image": init,
        "init_image_strength": keep,
        "no_background": True,
        "view": "high top-down",
        "outline": "selective outline",
        "shading": "detailed shading",
        "detail": "highly detailed",
    }


def _recipe(prompt: str, width: int, height: int, seed: int, **extra) -> dict:
    recipe = {
        "prompt": f"{prompt}. {STYLE}",
        "width": width,
        "height": height,
        "seed": seed,
        "no_background": True,
        "palette": PALETTE_STRIP,
        "text_guidance_scale": 9,
        "outline": "selective outline",
        "shading": "medium shading",
        "detail": "highly detailed",
    }
    recipe.update(extra)
    return recipe


RECIPES: dict[str, dict] = {
    # The mark over the title plate. It replaces a 28x30 hand-drawn anchor that
    # read as an ornament; a crest reads as a company, which is what the player
    # is about to be handed.
    "crest": _recipe(
        "heraldic harbour badge emblem: a large golden ship anchor standing "
        "upright, a coiled rope wreath curving around it, two red gantry crane "
        "booms crossed behind, a small navy shield at the base",
        128, 128, seed=20260806, view="side"),

    # The three terminals on the board. Each is a different berth, so each gets
    # a different painting rather than a numbered black square. They are a set:
    # one camera, one sea, three times of day — say the water is deep blue in
    # every one of them or the model paints one of them on a lawn.
    "berth_dawn": _recipe(
        "isometric diorama of a small container terminal built on deep blue "
        "ocean water: a concrete quay, one red gantry crane, three stacks of "
        "coloured shipping containers, early morning light",
        64, 64, seed=8411, isometric=True, no_background=False),
    "berth_busy": _recipe(
        "isometric diorama of a busy container terminal on deep blue ocean "
        "water: two red gantry cranes working a moored cargo ship at the quay, "
        "many stacks of coloured shipping containers, bright midday light",
        64, 64, seed=8412, isometric=True, no_background=False),
    "berth_night": _recipe(
        "isometric diorama of a container terminal at night on dark blue ocean "
        "water: a navy quay lit by warm amber floodlights, one red gantry "
        "crane, stacks of coloured shipping containers, glowing yellow windows",
        64, 64, seed=8413, isometric=True, no_background=False),

    # The ship at the title's berth. The procedural one is a rectangle with
    # boxes on it; a painting of a ship is the one thing on that screen the
    # player is supposed to want to walk towards.
    "ship_hero": _recipe(
        "a large container ship seen from directly above, bow pointing up, "
        "dark navy hull, cream white superstructure and bridge at the stern, "
        "long deck packed with rows of small coloured shipping containers, "
        "moored, night lighting",
        96, 320, seed=907, view="high top-down", direction="north"),

}

# Asked for and rejected, so nobody spends the generations again:
#
#   * a plan-view ship-to-shore gantry — the model answers every phrasing of
#     "from directly above" with a side elevation, which is the one projection
#     this game cannot use. The quay cranes stay hand-drawn.
#   * the crest at 64 directly, and a round medallion variant. Generating the
#     crest at 128 and halving it beats both: the big canvas is where the model
#     puts the rope, the flukes and the shield.
#   * the yard's machines — locomotive, wagon, transtainer — redrawn img2img
#     from their own sprites at twice size, at every init strength from 130 to
#     220. High strength returns the input back with a grey plate welded round
#     it; low strength returns a smooth slab with a smeared window on it. The
#     model is good at an *illustration* and bad at a 22x46 functional sprite
#     whose silhouette has to stay readable at 1:1, which is exactly the class
#     of art `tools/sprites` already draws better. Four generations bought that
#     sentence; do not buy it twice.
