"""Generates every pixel asset the public landing page ships.

The landing is not in the game pack, so its art lives in `landing/assets` and is
copied to `/media` by `tools/export/build_release.sh`. Everything written here is
either a lossless transform of a game sprite or drawn from `palette.py`, so the
front door and the terminal behind it are made of the same pixels.

Nothing is upscaled on disk. The page scales every sprite by an integer factor at
runtime, which is the only way nearest-neighbour art stays honest.
"""
import os
import random

from PIL import Image

import palette as P
from common import (hline, new_img, outline, px, rect, sheet, speckle,
                    text, text_width, vline)

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SPRITES = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(ROOT, "landing", "assets")

# Night grade of the title backdrop, reused so overlays sit on the same dusk.
NIGHT = (0.66, 0.66, 0.74)


def save(img: Image.Image, name: str) -> None:
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name + ".png"))
    print(f"  {name}.png  {img.width}x{img.height}")


def sprite(name: str) -> Image.Image:
    return Image.open(os.path.join(SPRITES, name + ".png")).convert("RGBA")


def dim(color, k=0.66):
    a = color[3] if len(color) > 3 else 255
    return (int(color[0] * k), int(color[1] * k), int(color[2] * k), a)


# --------------------------------------------------------------------------
# Wordmark
# --------------------------------------------------------------------------
# A 9x12 body with a 2px stroke: heavy enough to carry a hero at any scale, and
# still a grid a human can read as drawn rather than as a font stretched fat.
LETTERS = {
    "H": ["##.....##", "##.....##", "##.....##", "##.....##", "##.....##",
          "#########", "#########", "##.....##", "##.....##", "##.....##",
          "##.....##", "##.....##"],
    "A": ["...###...", "..#####..", ".##...##.", "##.....##", "##.....##",
          "#########", "#########", "##.....##", "##.....##", "##.....##",
          "##.....##", "##.....##"],
    "R": ["#######..", "########.", "##....##.", "##....##.", "########.",
          "#######..", "##..##...", "##...##..", "##....##.", "##....##.",
          "##.....##", "##.....##"],
    "B": ["#######..", "########.", "##....##.", "##....##.", "#######..",
          "#######..", "##....##.", "##.....##", "##.....##", "##....##.",
          "########.", "#######.."],
    "O": [".#######.", "#########", "##.....##", "##.....##", "##.....##",
          "##.....##", "##.....##", "##.....##", "##.....##", "##.....##",
          "#########", ".#######."],
    "C": [".#######.", "#########", "##.....##", "##.......", "##.......",
          "##.......", "##.......", "##.......", "##.......", "##.....##",
          "#########", ".#######."],
    "L": ["##.......", "##.......", "##.......", "##.......", "##.......",
          "##.......", "##.......", "##.......", "##.......", "##.......",
          "#########", "#########"],
    "I": ["#########", "#########", "...###...", "...###...", "...###...",
          "...###...", "...###...", "...###...", "...###...", "...###...",
          "#########", "#########"],
    "K": ["##.....##", "##....##.", "##...##..", "##..##...", "##.##....",
          "#####....", "#####....", "##.##....", "##..##...", "##...##..",
          "##....##.", "##.....##"],
}

GLYPH_W, GLYPH_H = 9, 12
TRACK = 2          # letter spacing
PAD = 1            # room for the outline
SHADOW_DROP = 3    # hard shadow under every letter

# Row bands: lit top, body, shaded base. Chunky type reads as metal when the
# light comes from one place, so the ramp is by row and never per letter.
BANDS = [
    (0, 2, P.SAFETY_L),
    (2, 9, P.SAFETY),
    (9, 12, P.SAFETY_D),
]
LOGO_SHADOW = (26, 18, 30, 255)


def _word(text: str) -> Image.Image:
    w = len(text) * GLYPH_W + (len(text) - 1) * TRACK + PAD * 2
    h = GLYPH_H + PAD * 2 + SHADOW_DROP
    img = new_img(w, h)
    body = new_img(w, h)
    for index, char in enumerate(text):
        rows = LETTERS[char]
        ox = PAD + index * (GLYPH_W + TRACK)
        for ry, row in enumerate(rows):
            color = next(c for lo, hi, c in BANDS if lo <= ry < hi)
            for rx, cell in enumerate(row):
                if cell == "#":
                    px(body, ox + rx, PAD + ry, color)
    # hard shadow first, then the outlined body over it
    for y in range(h):
        for x in range(w):
            if body.getpixel((x, y))[3] and y + SHADOW_DROP < h:
                px(img, x, y + SHADOW_DROP, LOGO_SHADOW)
    img.alpha_composite(outline(body))
    return img


def gen_logo():
    save(_word("HARBORCLICK"), "logo")


# --------------------------------------------------------------------------
# Backdrop
# --------------------------------------------------------------------------
def gen_port_strip():
    """The title backdrop plus its mirror, so the hero can tile horizontally.

    `ui_title_port` runs from grass on the left to open water on the right. A
    mirrored second copy puts water against water in the middle and grass
    against grass at the repeat, which is the only pair of edges that meets
    without a seam."""
    src = sprite("ui_title_port")
    strip = new_img(src.width * 2, src.height)
    strip.paste(src, (0, 0))
    strip.paste(src.transpose(Image.FLIP_LEFT_RIGHT), (src.width, 0))
    save(strip, "port-strip")


# --------------------------------------------------------------------------
# Seamless bands
# --------------------------------------------------------------------------
def gen_water():
    """Seamless 64x32 harbour water, scrolled sideways by the page.

    Dimmed harder than the rest of the night: it sits directly under the title
    backdrop, and water that reads brighter than the yard behind it breaks the
    illusion that both are the same basin."""
    w, h = 64, 32
    deep = 0.46
    img = new_img(w, h)
    rect(img, 0, 0, w, h, dim(P.SEA_DEEP, deep))
    rng = random.Random(704)
    for _ in range(26):
        y = rng.randrange(h)
        x = rng.randrange(w)
        length = rng.choice((3, 4, 5, 7))
        tone = dim(rng.choice((P.SEA, P.SEA, P.SEA_LIGHT)), deep + 0.06)
        for i in range(length):
            px(img, (x + i) % w, y, tone)
    for _ in range(10):
        px(img, rng.randrange(w), rng.randrange(h), dim(P.SEA_SPARK, 0.62))
    save(img, "water")


def gen_road():
    """Seamless 64x44 stretch of the terminal's public road, running east."""
    w, h = 64, 44
    img = new_img(w, h)
    rect(img, 0, 0, w, h, dim(P.YARD))
    speckle(img, 0, 0, w, h, [dim(P.YARD_D), dim(P.YARD_L), dim(P.YARD_PATCH)],
            density=0.10, seed=41)
    # kerbs top and bottom
    for y in (0, 1, h - 2, h - 1):
        hline(img, 0, y, w, dim(P.QUAY_D))
    hline(img, 0, 2, w, dim(P.QUAY))
    hline(img, 0, h - 3, w, dim(P.QUAY))
    # centre dashes: period 16 divides 64, so the tile repeats clean
    for x in range(0, w, 16):
        hline(img, x, h // 2 - 1, 8, dim(P.PAINT_W))
    save(img, "road")


# --------------------------------------------------------------------------
# Gulls
# --------------------------------------------------------------------------
# The page used to borrow `prop_seagull`, which is drawn from directly above
# because that is the angle the game is played at. Crossing a hero in front of
# a side-on ship and a side-on sea, a bird seen from above reads as a little
# person holding its arms out. These are drawn from the side instead: one body,
# one wing, four positions through a beat.
GULL_W, GULL_H = 16, 16

# Drawn whole per frame rather than as a body plus a pasted wing: at sixteen
# pixels the join between the two is most of the bird, and a wing that floats a
# pixel clear of the shoulder reads as a bird that has come apart.
GULL_FRAMES = [
    # wing at the top of the stroke
    ["................",
     "....oo..........",
     "...o##o.........",
     "...o###o........",
     "....o###o.......",
     ".....o###o......",
     "......o###o.....",
     ".......o###o....",
     "........o###o...",
     "..ooooo######oo.",
     ".o#############y",
     ".o############yy",
     "..oo#########o..",
     "....ooooooooo...",
     "................",
     "................"],
    # coming down
    ["................",
     "................",
     "................",
     "..ooo...........",
     ".o###o..........",
     "..o###oo........",
     "...o#####o......",
     "....o######o....",
     ".....o######o...",
     "..ooooo######oo.",
     ".o#############y",
     ".o############yy",
     "..oo#########o..",
     "....ooooooooo...",
     "................",
     "................"],
    # level, swept back
    ["................",
     "................",
     "................",
     "................",
     "................",
     "................",
     "oo..............",
     "o##ooo..........",
     ".o######ooooo...",
     "..ooo########oo.",
     ".o#############y",
     ".o############yy",
     "..oo#########o..",
     "....ooooooooo...",
     "................",
     "................"],
    # bottom of the stroke
    ["................",
     "................",
     "................",
     "................",
     "................",
     "................",
     "................",
     "................",
     ".....ooooooooo..",
     "..ooo#########oo",
     ".o#############y",
     ".o############yy",
     "..oo#########o..",
     "..o####ooooooo..",
     ".o#####o........",
     "o###oo.........."],
]

GULL_INK = {"#": P.FOAM, "o": P.OUTLINE, "y": P.SAFETY}


def _gull(frame: int) -> Image.Image:
    img = new_img(GULL_W, GULL_H)
    for ry, row in enumerate(GULL_FRAMES[frame]):
        for rx, cell in enumerate(row):
            if cell in GULL_INK:
                px(img, rx, ry, GULL_INK[cell])
    px(img, 12, 10, P.OUTLINE)                # eye
    return img


def gen_seagull():
    """Four frames of one flap, as a strip the page steps through."""
    save(sheet([_gull(frame) for frame in range(4)]), "seagull")


def gen_skyline():
    """A seamless 320x120 band of terminal silhouettes for the hero's middle
    distance.

    The backdrop behind the hero is the game's title art mirrored, which on a
    wide screen reads as one symmetrical wall. A separate band of gantries,
    sheds and light masts scrolling at its own rate breaks that symmetry and
    gives the hero something between the sky and the water — which is the whole
    reason a wide hero felt empty. Drawn as flat silhouettes in two values, so
    it never competes with the copy in front of it."""
    w, h = 320, 120
    ground = h - 1
    far = (16, 36, 58, 255)
    near = (5, 13, 24, 255)
    glow = (238, 176, 62, 190)
    img = new_img(w, h)

    def leg(x, top, thick, tone):
        rect(img, x, top, thick, ground - top + 1, tone)

    def gantry(x, tone, height, boom):
        """One ship-to-shore crane: portal legs, machinery house, boom."""
        top = ground - height
        leg(x, top + 6, 4, tone)
        leg(x + 26, top + 6, 4, tone)
        rect(img, x, top + 6, 30, 4, tone)              # portal beam
        rect(img, x + 4, top, 22, 8, tone)              # machinery house
        # A-frame and the stays that hold the boom out over the water
        rect(img, x + 12, top - 16, 3, 17, tone)
        for i in range(boom):
            px(img, x + 15 + i, top - 16 + i * 16 // boom, tone)
            px(img, x + 14 - i * 12 // boom, top - 16 + i * 14 // boom, tone)
        rect(img, x + 12, top + 2, boom + 18, 3, tone)  # the boom itself
        # cross-bracing in the legs
        for y in range(top + 12, ground - 6, 6):
            px(img, x + 2, y, tone)
            px(img, x + 28, y, tone)

    def shed(x, wide, tall, tone):
        top = ground - tall
        rect(img, x, top, wide, tall, tone)
        hline(img, x, top, wide, tone)
        for lx in range(x + 3, x + wide - 3, 7):
            px(img, lx, top + 4, glow)

    def mast(x, tall, tone):
        rect(img, x, ground - tall, 2, tall, tone)
        rect(img, x - 2, ground - tall - 3, 6, 3, tone)
        for gx in range(-2, 4):
            px(img, x + gx, ground - tall - 4, glow)

    # far layer first, so the near one reads as standing in front of it
    shed(6, 54, 26, far)
    gantry(96, far, 44, 26)
    shed(180, 46, 22, far)
    gantry(240, far, 40, 24)
    mast(70, 52, far)
    mast(292, 48, far)

    gantry(28, near, 62, 34)
    shed(132, 40, 30, near)
    gantry(196, near, 58, 32)
    mast(120, 66, near)
    mast(288, 62, near)

    # stacked boxes along the quay, and the odd lit window in them
    rng = random.Random(311)
    for x in range(0, w, 13):
        tiers = rng.choice((1, 1, 2, 2, 3))
        for tier in range(tiers):
            rect(img, x, ground - 5 - tier * 5, 12, 5, near)
            px(img, x + 1, ground - 5 - tier * 5, far)

    save(img, "skyline")


# --------------------------------------------------------------------------
# Rigs
# --------------------------------------------------------------------------
BOX_W, BOX_COUNT = 24, 8


def _rig(colour: int) -> Image.Image:
    """Tractor, chassis and one forty-foot box on the game's own hitch points.

    Container art is drawn landscape and the chassis is nose-up, so the box is
    turned a quarter before it is laid on the bed — the same trick
    `road_truck.gd` plays."""
    cab = sprite("veh_truck_cab")
    chassis = sprite("veh_truck_chassis")
    sheet = sprite("container_sheet")
    box = sheet.crop((colour % BOX_COUNT * BOX_W, 0,
                      (colour % BOX_COUNT + 1) * BOX_W, sheet.height))
    box = box.transpose(Image.ROTATE_90)
    # cab fifth wheel y=19 meets chassis kingpin y=2 (see road_truck.gd)
    top = 19 - 2
    img = new_img(chassis.width, top + chassis.height)
    img.paste(chassis, (0, top), chassis)
    img.paste(box, ((chassis.width - box.width) // 2,
                    top + (chassis.height - box.height) // 2), box)
    img.paste(cab, (0, 0), cab)
    return img.transpose(Image.ROTATE_270)


def gen_truck():
    """Three liveries in one strip, so the road never repeats the same rig."""
    rigs = [_rig(c) for c in (0, 1, 7)]
    strip = new_img(sum(r.width for r in rigs), rigs[0].height)
    for index, rig in enumerate(rigs):
        strip.paste(rig, (index * rig.width, 0), rig)
    save(strip, "truck")


# --------------------------------------------------------------------------
# The ship
# --------------------------------------------------------------------------
# The hero used to borrow `ship_cute`, the game's little top-down harbour boat,
# and read on a wide screen as a bath toy crossing a container terminal. A port
# game's front door has to show the thing the port is for, so the ship is drawn
# here instead: a full side-on container vessel, bow to the right because that
# is the way the hero animation sails it.
#
# One routine draws both the hero ship and the small one on the first card —
# they differ only in how many container bays fit between the accommodation
# block and the forecastle, which is exactly how real classes differ.

DECK_Y = 60       # main deck line
WATER_Y = 78      # the ship's own waterline: 18 rows of freeboard
KEEL_Y = 83       # last hull row drawn; the page's water covers the rest
SHIP_H = 88
SMOKE_ROOM = 16   # blank rows above the funnel for the plume to climb into
BOW_RAKE = 20     # how far the stem leans forward over that freeboard
FORECASTLE = 34   # length of the raised bow deck

BAY_PITCH = 22    # one container bay plus the lashing gap after it
BOX_H = 9         # one tier
TIER_TOP = 56     # top of the hatch covers, where tier 1 sits

# How tall each bay is stacked, forward of the house. Read left to right; the
# forward bays come down so the sheer of the stack follows the sheer of the
# hull instead of walling the ship off in a flat block.
HERO_TIERS = (4, 4, 4, 3, 3, 2)
CARD_TIERS = (3, 3, 2)

NIGHT_K = 0.86    # the hull is lit by the terminal, not by the sun


def _night(color, k=NIGHT_K):
    return (int(color[0] * k), int(color[1] * k), int(color[2] * k),
            color[3] if len(color) > 3 else 255)


def _box(key: str) -> Image.Image:
    """One forty-foot box seen from the side: 20x9, ribbed, corner castings."""
    face, side = P.CONTAINERS[key]
    face, side = _night(face), _night(side)
    img = new_img(20, BOX_H)
    rect(img, 0, 0, 20, BOX_H, face)
    hline(img, 0, 0, 20, _night(P.OUTLINE))
    hline(img, 0, 1, 20, tuple(min(255, c + 22) for c in face[:3]) + (255,))
    hline(img, 0, BOX_H - 1, 20, _night(P.OUTLINE))
    hline(img, 0, BOX_H - 2, 20, side)
    # corrugation: the ribs are what say "container" rather than "crate"
    for x in range(2, 18, 3):
        for y in range(2, BOX_H - 2):
            px(img, x, y, side)
    # corner castings
    for cx in (0, 1, 18, 19):
        px(img, cx, 1, side)
        px(img, cx, BOX_H - 2, side)
    return img


def _hull_span(y: int, bow: int, stern: int):
    """Left and right edge of the hull at row `y`.

    Above the waterline the stem rakes forward and the sides are near vertical;
    below it the bow carries a bulb and the run aft cuts away to the skeg."""
    if y <= WATER_Y:
        # the stem leans forward, quickly at first and then straighter, so the
        # bow reads as flared rather than as a diagonal cut. Rows above the
        # deck are the forecastle and carry the same rake on.
        t = (WATER_Y - y) / (WATER_Y - DECK_Y)
        right = bow - BOW_RAKE + round(BOW_RAKE * (t if t > 1 else t ** 0.72))
        # the transom overhangs aft and tucks back in below the waterline
        left = stern - 2 + max(0, y - (WATER_Y - 6)) // 2
    else:
        bulb = {79: 6, 80: 8, 81: 8, 82: 6, 83: 1}
        right = bow - BOW_RAKE + bulb.get(y, -8)
        cut = {79: 6, 80: 10, 81: 16, 82: 24, 83: 36}
        left = stern + cut.get(y, 48)
    return left, right


def _draw_ship(tiers, name: str) -> Image.Image:
    """A container vessel in side profile, drawn on the game's own palette."""
    bays = len(tiers)
    stern = 6
    nose = FORECASTLE if bays > 4 else 22      # a feeder gets a shorter bow
    cargo_x = stern + 52                       # forward face of the house
    bow = cargo_x + bays * BAY_PITCH + nose    # deck edge at the stem
    width = bow + 4
    img = new_img(width, SHIP_H)
    rng = random.Random(9301 + bays)

    # ------------------------------------------------------------ the hull
    for y in range(DECK_Y, KEEL_Y + 1):
        left, right = _hull_span(y, bow, stern)
        if y == DECK_Y:
            tone = _night(P.HULL_L)
        elif y < WATER_Y - 5:
            tone = _night(P.HULL)
        elif y < WATER_Y - 1:
            tone = _night(P.HULL_D)
        elif y == WATER_Y - 1:
            tone = _night(P.OUTLINE)
        elif y == WATER_Y:
            tone = _night(P.CRANE)
        else:
            tone = _night(P.CRANE_D)
        rect(img, left, y, right - left + 1, 1, tone)

    # the sheer strake: one lit row under the deck edge carries the whole length
    left, right = _hull_span(DECK_Y + 1, bow, stern)
    rect(img, left, DECK_Y + 1, right - left + 1, 1, _night(P.HULL_L))

    # the stem itself, picked out so the flare reads at a glance
    for y in range(DECK_Y, WATER_Y):
        _, right = _hull_span(y, bow, stern)
        px(img, right, y, _night(P.HULL_L))

    # raised forecastle. Real box boats have one, and without it the deck line
    # is a dead-straight rule from stem to stern.
    fc_top = DECK_Y - 5
    for y in range(fc_top, DECK_Y):
        _, right = _hull_span(y, bow, stern)
        span = right - (bow - nose) + 1
        tone = _night(P.HULL_L) if y == fc_top else _night(P.HULL)
        rect(img, bow - nose, y, span, 1, tone)
    # bulwark rail along it
    _, rail_end = _hull_span(fc_top, bow, stern)
    for x in range(bow - nose, rail_end, 2):
        px(img, x, fc_top - 1, _night(P.STEEL_L))

    # name on the bow quarter, in the game's own 5x7 font
    text(img, cargo_x + 4, DECK_Y + 4, name, _night(P.SUPER_W))

    # draft marks forward
    for y in range(WATER_Y - 10, WATER_Y - 1, 3):
        _, right = _hull_span(y, bow, stern)
        rect(img, right - 11, y, 4, 1, _night(P.SUPER_W_D))

    # hawse pipe and anchor at the stem
    _, right = _hull_span(DECK_Y + 7, bow, stern)
    rect(img, right - 9, DECK_Y + 5, 4, 5, _night(P.OUTLINE))
    rect(img, right - 8, DECK_Y + 6, 2, 3, _night(P.STEEL_L))

    # ----------------------------------------------- hatch covers and cargo
    hatch_w = (bow - nose) - (stern + 48)
    rect(img, stern + 48, TIER_TOP, hatch_w, DECK_Y - TIER_TOP, _night(P.HATCH))
    hline(img, stern + 48, TIER_TOP, hatch_w, _night(P.HATCH_L))

    for index, height in enumerate(tiers):
        bx = cargo_x + index * BAY_PITCH
        for tier in range(height):
            key = P.CONTAINER_NAMES[rng.randrange(len(P.CONTAINER_NAMES))]
            img.alpha_composite(_box(key), (bx, TIER_TOP - (tier + 1) * BOX_H))
        # lashing bridge between bays, two tiers up
        if index < bays - 1 and min(height, tiers[index + 1]) >= 2:
            rect(img, bx + 20, TIER_TOP - 2 * BOX_H, 2, 2 * BOX_H,
                 _night(P.STEEL_D))

    # ------------------------------------------------- accommodation block
    house_x, house_w = stern + 15, 28
    house_top = TIER_TOP - 32
    rect(img, house_x, house_top, house_w, DECK_Y - house_top, _night(P.SUPER_W))
    vline(img, house_x + house_w - 1, house_top, DECK_Y - house_top,
          _night(P.SUPER_W_D))
    for deck in range(house_top + 6, DECK_Y - 2, 6):
        hline(img, house_x, deck, house_w, _night(P.SUPER_W_D))
        for wx in range(house_x + 3, house_x + house_w - 3, 6):
            lit = P.WINDOW_LIT if rng.random() < 0.55 else _night(P.GLASS_D)
            rect(img, wx, deck - 3, 3, 2, lit)

    # bridge, with wings out past the house so it reads as a bridge
    bridge_y = house_top - 7
    rect(img, house_x - 4, bridge_y, house_w + 8, 7, _night(P.SUPER_W))
    hline(img, house_x - 4, bridge_y, house_w + 8, _night(P.STEEL_D))
    rect(img, house_x - 3, bridge_y + 2, house_w + 6, 3, _night(P.GLASS_D))
    for wx in range(house_x - 2, house_x + house_w + 3, 4):
        rect(img, wx, bridge_y + 2, 3, 3, P.WINDOW_LIT)

    # funnel: the one place the terminal's own amber shows on the ship
    fun_x, fun_w = house_x + 8, 13
    fun_top = bridge_y - 13
    rect(img, fun_x, fun_top, fun_w, bridge_y - fun_top, _night(P.STEEL_D))
    rect(img, fun_x + 1, fun_top + 1, fun_w - 2, bridge_y - fun_top - 1,
         _night(P.STEEL))
    rect(img, fun_x + 1, fun_top + 4, fun_w - 2, 4, _night(P.SAFETY))
    hline(img, fun_x + 1, fun_top + 5, fun_w - 2, _night(P.SAFETY_L))
    rect(img, fun_x + 2, fun_top, fun_w - 4, 2, _night(P.OUTLINE))
    px(img, fun_x + fun_w // 2, fun_top - 1, P.RED_LIGHT)

    # foremast, standing on the forecastle
    mast_x = bow - nose + 8
    rect(img, mast_x, fc_top - 22, 2, 22, _night(P.STEEL))
    rect(img, mast_x - 5, fc_top - 18, 12, 2, _night(P.STEEL_D))
    px(img, mast_x, fc_top - 23, P.WINDOW_LIT)
    px(img, mast_x + 1, fc_top - 23, P.WINDOW_LIT)

    # lifeboat on its davit, on the scrap of open deck aft of the house
    boat_x, boat_y = stern + 2, DECK_Y - 9
    rect(img, boat_x, boat_y + 2, 11, 4, _night(P.VEST))
    hline(img, boat_x + 1, boat_y + 2, 9, _night(P.VEST_L))
    hline(img, boat_x + 1, boat_y + 5, 9, _night(P.VEST_D))
    rect(img, boat_x + 4, boat_y, 2, 2, _night(P.STEEL_D))

    # mooring winch on the forecastle
    rect(img, bow - nose + 15, fc_top - 4, 7, 4, _night(P.STEEL_D))
    hline(img, bow - nose + 15, fc_top - 4, 7, _night(P.STEEL))

    # navigation lights: green to starboard forward, red aft
    px(img, bow - nose + 2, fc_top, P.GREEN_LIGHT)
    px(img, stern + 3, DECK_Y - 1, P.RED_LIGHT)

    # One ink line around the whole silhouette. Every sprite in the game wears
    # one; without it the ship dissolves into a night sky the same value as its
    # own hull.
    return outline(img)


def _wash(img: Image.Image, frame: int, bow: int, stern: int,
          top: int = 0) -> None:
    """Bow wave, quarter wake and funnel smoke — the three things that make a
    still ship read as a moving one. One frame's worth, drawn in place.

    `top` is where the hull was pasted into the taller canvas: the smoke needs
    room above the funnel, and without it the plume was flat-topped against the
    edge of the sprite."""
    rng = random.Random(4700 + frame * 31)
    foam = _night(P.FOAM, 0.94)
    spray = _night(P.SEA_SPARK, 0.9)
    stem = bow - BOW_RAKE
    water = WATER_Y + top

    # bow wave: a shoulder of white thrown out ahead of and beside the stem
    for i in range(14):
        x = stem - 4 + i
        crest = water - 2 + abs(i - 5) // 3
        px(img, x, crest, foam)
        if (i + frame) % 2 == 0:
            px(img, x, crest + 1, spray)
    for i in range(7):
        px(img, stem + 6 + i, water + 1 + i // 3, foam if i < 4 else spray)

    # a broken line of wash down the waterline
    for x in range(stern + 10, stem - 6, 3):
        if (x // 3 + frame) % 3 == 0:
            px(img, x, water - 1, foam)
            px(img, x + 1, water - 1, spray)

    # quarter wake trailing aft of the stern
    for i in range(20):
        x = stern - 1 - i
        if x < 0:
            break
        y = water + (i // 7)
        if (i + frame) % 2 == 0:
            px(img, x, y, foam if i < 9 else spray)
            px(img, x, y - 1, spray if i < 5 else P.TRANSPARENT)

    # funnel smoke, drifting aft and thinning as it goes
    puffs = ((0, 0, 3), (-5, -4, 3), (-11, -7, 2), (-18, -9, 2), (-25, -10, 1))
    base_x, base_y = stern + 23, top + 2
    for index, (dx, dy, r) in enumerate(puffs):
        cx = base_x + dx - frame * 3
        cy = base_y + dy - frame
        alpha = 156 - index * 28
        for oy in range(-r, r + 1):
            for ox in range(-r, r + 1):
                if ox * ox + oy * oy <= r * r + rng.randrange(2):
                    if 0 <= cx + ox < img.width and 0 <= cy + oy < img.height:
                        if img.getpixel((cx + ox, cy + oy))[3] == 0:
                            px(img, cx + ox, cy + oy,
                               P.SMOKE[:3] + (max(0, alpha),))


def gen_ship():
    """The hero ship as a three-frame strip, and the small one for card 01.

    The strip is stepped by CSS rather than tweened: a pixel ship whose foam
    cross-fades is a pixel ship with grey edges."""
    for tiers, name, out, frames in (
        (HERO_TIERS, "HARBORCLICK", "ship-side", 3),
        (CARD_TIERS, "HC LINE", "ship-feeder", 3),
    ):
        base = _draw_ship(tiers, name)
        stern, bow = 6, base.width - 4
        tall = SHIP_H + SMOKE_ROOM
        strip = new_img(base.width * frames, tall)
        for frame in range(frames):
            cell = new_img(base.width, tall)
            cell.paste(base, (0, SMOKE_ROOM))
            _wash(cell, frame, bow, stern, SMOKE_ROOM)
            strip.paste(cell, (frame * base.width, 0))
        save(strip, out)
        print(f"      frame {base.width}x{tall}")


# --------------------------------------------------------------------------
# Marks
# --------------------------------------------------------------------------
# Press Start 2P has no play/diamond/check glyphs, and borrowing them from a
# system font drops a smooth vector shape into a page made of pixels. They are
# drawn here instead and used as CSS masks, so each one takes its text colour.
MARKS = [
    # play
    ["..#.....", "..##....", "..###...", "..####..",
     "..####..", "..###...", "..##....", "..#....."],
    # down
    ["........", "........", "########", ".######.",
     "..####..", "...##...", "........", "........"],
    # diamond
    ["........", "...##...", "..####..", ".######.",
     ".######.", "..####..", "...##...", "........"],
    # up-right arrow
    ["....####", ".....###", "....#..#", "...#....",
     "..#.....", ".#......", "#.......", "........"],
    # check
    ["......##", ".....##.", "....##..", "...##...",
     "#..##...", "##.#....", ".###....", "..#....."],
    # cross
    ["##....##", "###..###", ".######.", "..####..",
     "..####..", ".######.", "###..###", "##....##"],
]


def gen_chips():
    """Four 16x16 badges for the feature cards: crane, globe, share, box.

    Drawn rather than borrowed because the shop icons they would otherwise come
    from are sized for a 320px board and read as mush at card scale."""
    cell = 16
    img = new_img(cell * 4, cell)

    def at(index, x, y, w, h, color):
        rect(img, index * cell + x, y, w, h, color)

    # crane: a gantry with a box on the hook, which is the one silhouette that
    # cannot be read as a doorway
    at(0, 1, 13, 14, 2, P.STEEL_D)
    at(0, 2, 5, 2, 8, P.CRANE)
    at(0, 11, 5, 2, 8, P.CRANE)
    at(0, 1, 3, 13, 2, P.CRANE_L)
    at(0, 4, 1, 11, 2, P.SAFETY)
    at(0, 6, 0, 2, 1, P.SAFETY_L)
    at(0, 12, 3, 1, 5, P.STEEL_L)
    at(0, 10, 8, 5, 3, P.CONTAINERS["blue"][0])
    at(0, 10, 10, 5, 1, P.CONTAINERS["blue"][1])

    # globe: a disc with a meridian and two parallels
    at(1, 5, 2, 6, 12, P.TEAL)
    at(1, 3, 4, 10, 8, P.TEAL)
    at(1, 2, 6, 12, 4, P.TEAL)
    at(1, 7, 2, 2, 12, P.TEAL_L)
    at(1, 2, 7, 12, 1, P.TEAL_L)
    at(1, 3, 4, 10, 1, P.TEAL_D)
    at(1, 3, 11, 10, 1, P.TEAL_D)

    # golden share: a coin on its stack
    at(2, 4, 2, 8, 2, P.SAFETY_L)
    at(2, 3, 4, 10, 6, P.SAFETY)
    at(2, 4, 10, 8, 2, P.SAFETY_D)
    at(2, 6, 5, 4, 4, P.SAFETY_L)
    at(2, 3, 13, 10, 1, P.OUTLINE)

    # container: ribbed box with corner castings
    at(3, 1, 4, 14, 8, P.CONTAINERS["rust"][0])
    at(3, 1, 4, 14, 1, (214, 128, 96, 255))
    at(3, 1, 11, 14, 1, P.CONTAINERS["rust"][1])
    for rib in range(3, 14, 3):
        at(3, rib, 5, 1, 6, P.CONTAINERS["rust"][1])
    at(3, 1, 3, 3, 1, P.STEEL_L)
    at(3, 12, 3, 3, 1, P.STEEL_L)

    save(outline(img), "chips")


def gen_marks():
    cell = 8
    img = new_img(cell * len(MARKS), cell)
    for index, rows in enumerate(MARKS):
        for y, row in enumerate(rows):
            for x, cellchar in enumerate(row):
                if cellchar == "#":
                    px(img, index * cell + x, y, (255, 255, 255, 255))
    save(img, "marks")


# --------------------------------------------------------------------------
# Nine-slice chrome
# --------------------------------------------------------------------------
# Every panel and button on the page is one of these stretched by `border-image`.
# Drawing them as sprites rather than as CSS borders keeps the chrome made of the
# same pixels as the art, and keeps the corners chamfered at any scale.
NAVY = (16, 34, 56, 255)
NAVY_D = (10, 22, 38, 255)


def _chamfer(img):
    """Knock the single corner pixel out of each corner."""
    w, h = img.size
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        img.putpixel((x, y), P.TRANSPARENT)


def gen_panel():
    """Steel screen: ink rim, lit top edge, amber inner rule, corner rivets."""
    size = 24
    img = new_img(size, size)
    rect(img, 0, 0, size, size, P.OUTLINE)
    rect(img, 1, 1, size - 2, size - 2, P.STEEL_D)
    hline(img, 1, 1, size - 2, P.STEEL)
    rect(img, 2, 2, size - 4, size - 4, P.SAFETY_D)
    rect(img, 3, 3, size - 6, size - 6, NAVY_D)
    rect(img, 4, 4, size - 8, size - 8, NAVY)
    for cx, cy in ((5, 5), (size - 6, 5), (5, size - 6), (size - 6, size - 6)):
        px(img, cx, cy, P.SAFETY_L)
    _chamfer(img)
    save(img, "panel")


def gen_board():
    """Warm board for the manifest: timber rim over a paper field."""
    size = 24
    img = new_img(size, size)
    rect(img, 0, 0, size, size, P.OUTLINE)
    rect(img, 1, 1, size - 2, size - 2, P.WOOD_D)
    hline(img, 1, 1, size - 2, P.WOOD)
    rect(img, 3, 3, size - 6, size - 6, P.OUTLINE)
    rect(img, 4, 4, size - 8, size - 8, (222, 212, 184, 255))
    hline(img, 4, 4, size - 8, (238, 230, 206, 255))
    for cx, cy in ((2, 2), (size - 3, 2), (2, size - 3), (size - 3, size - 3)):
        px(img, cx, cy, P.STEEL_L)
    _chamfer(img)
    save(img, "board")


def _button(face, top, base) -> Image.Image:
    size = 16
    img = new_img(size, size)
    rect(img, 0, 0, size, size, P.OUTLINE)
    rect(img, 1, 1, size - 2, size - 2, face)
    hline(img, 1, 1, size - 2, top)
    hline(img, 1, 2, size - 2, top)
    hline(img, 1, size - 3, size - 2, base)
    hline(img, 1, size - 2, size - 2, base)
    _chamfer(img)
    return img


def gen_button():
    save(_button(P.SAFETY, P.SAFETY_L, P.SAFETY_D), "btn")


# --------------------------------------------------------------------------
# Social card
# --------------------------------------------------------------------------
def _plate(w: int, h: int) -> Image.Image:
    """The title plate: dark steel, amber double rule, rivets in the corners."""
    img = new_img(w, h)
    rect(img, 0, 0, w, h, P.OUTLINE)
    rect(img, 1, 1, w - 2, h - 2, P.SAFETY_D)
    rect(img, 2, 2, w - 4, h - 4, (22, 44, 70, 255))
    rect(img, 4, 4, w - 8, h - 8, P.OUTLINE)
    rect(img, 5, 5, w - 10, h - 10, (16, 34, 56, 255))
    for cx, cy in ((7, 7), (w - 8, 7), (7, h - 8), (w - 8, h - 8)):
        rect(img, cx - 1, cy - 1, 3, 3, P.SAFETY_D)
        px(img, cx, cy, P.SAFETY_L)
    return img


def gen_og():
    """1200x630 social card, painted at 300x158 and scaled by exactly 4."""
    scale = 4
    w, h = 300, 158
    strip = Image.open(os.path.join(OUT, "port-strip.png")).convert("RGBA")
    card = strip.crop((150, 170, 150 + w, 170 + h)).copy()
    veil = new_img(w, h)
    rect(veil, 0, 0, w, h, (8, 20, 34, 118))
    card.alpha_composite(veil)

    logo = Image.open(os.path.join(OUT, "logo.png")).convert("RGBA")
    subtitle = "O PORTO NUNCA DORME"
    plate = _plate(logo.width + 28, logo.height + 34)
    plate.alpha_composite(logo, (14, 11))
    text(plate, (plate.width - text_width(subtitle)) // 2, plate.height - 17,
         subtitle, P.SAFETY_L)
    card.alpha_composite(plate, ((w - plate.width) // 2, (h - plate.height) // 2))

    tag = "JOGUE GRÁTIS NO NAVEGADOR"
    band_w = text_width(tag) + 11
    band = new_img(band_w, 15)
    rect(band, 0, 0, band_w, 15, (10, 22, 36, 220))
    hline(band, 0, 0, band_w, P.SAFETY_D)
    hline(band, 0, 14, band_w, P.SAFETY_D)
    text(band, 5, 3, tag, P.PAINT_W)
    card.alpha_composite(band, ((w - band_w) // 2, h - 26))

    big = card.resize((w * scale, h * scale), Image.NEAREST)
    save(big.crop((0, 1, 1200, 631)), "og")


# --------------------------------------------------------------------------
# Sprites the page borrows from the game, copied verbatim
# --------------------------------------------------------------------------
BORROWED = {
    "ui_title_anchor": "anchor",
    "sts": "crane",
    "container_sheet": "containers",
    "prop_cat": "cat",
    "map_world": "world-map",
}


def copy_borrowed():
    for source, name in BORROWED.items():
        save(sprite(source), name)


if __name__ == "__main__":
    print("landing:")
    gen_logo()
    gen_port_strip()
    gen_water()
    gen_road()
    gen_seagull()
    gen_skyline()
    gen_truck()
    gen_ship()
    gen_panel()
    gen_board()
    gen_button()
    gen_marks()
    gen_chips()
    copy_borrowed()
    gen_og()
