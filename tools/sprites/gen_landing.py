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
from common import hline, new_img, outline, px, rect, speckle, text, text_width

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
    "ship_cute": "ship-side",
    "container_sheet": "containers",
    "prop_seagull": "seagull",
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
    gen_truck()
    gen_panel()
    gen_board()
    gen_button()
    gen_marks()
    copy_borrowed()
    gen_og()
