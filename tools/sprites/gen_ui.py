"""UI chrome, in the two materials the terminal is actually made of.

**Container** is everything you open. A board is the end wall of a shipping
container: corrugated steel painted in one of the yard's liveries (rust, sea,
green, steel, gold — one per kind of board), a corner casting in each corner,
and a cream manifest sheet sunk into it. It hangs from the same yellow spreader
the quay cranes carry. What is on the sheet is cargo labels: thick cream
stickers with a brown edge, a sky-blue window the item stands in, and the
price as a moulded green key. Green means "this spends cargo" and nothing else
is green.

**Steel** is the terminal's own signage: the gantry bolted across the top of
the quay carrying the tally and the clock, the console the keys sit on, and
the dark glass a number is lit behind. It is hull-green enamel with a lit lip
and a brushed pinstripe.

Two rules keep it looking like a material instead of a diagram:

* **Every layer casts a shadow onto the one below it.**
* **Nothing is a two-tone rectangle.** Every surface runs a four or five step
  ramp.

The nine-patch centre is *tiled*, not stretched (`AXIS_STRETCH_MODE_TILE` in
`UiTheme.nine`), which is what lets the paper carry real fibre texture — a
stretched centre would smear one row of pixels across the whole panel.
"""
from common import new_img, rect, hline, vline, px, save, sheet, speckle

# --- wood: five steps, warm, with a cool dark edge ---
WOOD_XD = (48, 32, 26, 255)
WOOD_D = (76, 52, 38, 255)
WOOD = (112, 78, 54, 255)
WOOD_L = (146, 104, 70, 255)
WOOD_XL = (180, 136, 96, 255)

# --- steel: five steps so a rivet and a brushed face can coexist ---
STEEL_XD = (52, 50, 62, 255)
STEEL_D = (88, 86, 100, 255)
STEEL = (136, 134, 148, 255)
STEEL_L = (184, 182, 194, 255)
STEEL_XL = (226, 226, 234, 255)

# --- paper: the field colours are fixed by the contrast suite; the extra
# steps exist only for fibre, edges and shadow, and stay within a few points
# of luminance of the field so AA still holds.
# "Paper" is a name kept from the clipboard era. Since the control-room pass
# every opened board is a deck panel: the same navy enamel as the gantry, one
# family of slabs stepping up in lightness from the tray to a lit card.
PAPER_XD = (96, 70, 50, 255)      # the brown edge of every label
PAPER_D = (210, 190, 154, 255)    # the tray a list lies in
PAPER = (244, 232, 206, 255)      # a label
PAPER_L = (255, 248, 228, 255)    # a label you can afford
PAPER_XL = (255, 255, 244, 255)   # the lit lip
PAPER_FIBRE = (236, 222, 194, 255)
PAPER_RULE = (222, 206, 176, 255)
DECK = (228, 210, 174, 255)       # the sheet a board holds
DECK_DOT = (214, 194, 156, 255)
DECK_SHADE = (188, 166, 130, 255)
WELL = (190, 222, 218, 255)       # sky behind an item

# The "go" green: every key that spends cargo is this colour and nothing else is.
GO_XD = (18, 62, 32, 255)
GO_D = (26, 86, 40, 255)
GO = (36, 114, 52, 255)
GO_L = (96, 180, 98, 255)
GO_XL = (172, 228, 160, 255)

## Container liveries, darkest to lightest. A board's frame and nameplate are
## painted in one of these; which is `UiTheme.board_style(content, tone)`.
LIVERY = {
    "rust": ((92, 34, 20, 255), (150, 58, 28, 255), (200, 88, 38, 255),
             (228, 124, 60, 255), (250, 176, 104, 255)),
    "sea": ((14, 44, 78, 255), (24, 74, 118, 255), (38, 106, 156, 255),
            (78, 148, 194, 255), (146, 200, 228, 255)),
    "green": ((18, 58, 38, 255), (30, 90, 54, 255), (48, 126, 74, 255),
              (92, 168, 106, 255), (160, 214, 162, 255)),
    "steel": ((42, 44, 54, 255), (70, 74, 88, 255), (102, 108, 124, 255),
              (146, 152, 168, 255), (198, 204, 216, 255)),
    "gold": ((84, 50, 6, 255), (128, 82, 10, 255), (176, 118, 18, 255),
             (220, 166, 50, 255), (250, 214, 120, 255)),
}
PRINT_WHITE = (244, 240, 228, 255)

# --- enamelled navy steel: the HUD's own material ---
# Dark enough that cream and amber both clear AA on it, and blue enough that it
# never reads as "grey box" over the warm greys of the yard.
HULL_XD = (10, 30, 36, 255)
HULL_D = (18, 48, 56, 255)
HULL = (28, 68, 76, 255)
HULL_L = (56, 106, 112, 255)
HULL_XL = (112, 164, 166, 255)

# --- the dark glass a lit number sits behind ---
GLASS_XD = (8, 11, 18, 255)
GLASS_D = (17, 21, 32, 255)
GLASS = (25, 31, 46, 255)
GLASS_GLOW = (38, 47, 66, 255)

SLATE_XD = (18, 14, 22, 255)
SLATE_D = (34, 30, 44, 255)
SLATE = (52, 46, 62, 255)
SLATE_L = (84, 76, 96, 255)
SLATE_XL = (128, 118, 140, 255)

AMBER_XD = (128, 78, 18, 255)
AMBER_D = (176, 112, 30, 255)
AMBER = (232, 160, 48, 255)
AMBER_L = (252, 202, 96, 255)
AMBER_XL = (255, 228, 158, 255)
# The teal and rust keys carry cream text, so their bases are darkened until
# that text clears 4.5:1 — see tests/contrast_test_runner.gd.
TEAL_XD = (16, 52, 52, 255)
TEAL_D = (26, 74, 74, 255)
TEAL = (44, 116, 110, 255)
TEAL_L = (92, 178, 166, 255)
TEAL_XL = (150, 214, 200, 255)
RUST_XD = (78, 28, 24, 255)
RUST_D = (112, 42, 34, 255)
RUST = (150, 60, 48, 255)
RUST_L = (196, 100, 78, 255)
INK = (58, 44, 46, 255)
INK_SOFT = (84, 68, 64, 255)

## Every layer drops the same shadow, so the whole interface agrees about
## where the light is (upper left) and how thick the paper is.
SHADOW_1 = (4, 6, 12, 120)
SHADOW_2 = (4, 6, 12, 60)

# Legacy names still generated so an older save/scene never loads a hole.
FRAME_D, FRAME, FRAME_L = WOOD_D, WOOD, WOOD_L


def rivet(img, x, y):
    """A domed steel rivet: lit crown, dark seat, one specular pixel."""
    px(img, x, y, STEEL_L)
    px(img, x + 1, y, STEEL_XL)
    px(img, x, y + 1, STEEL_D)
    px(img, x + 1, y + 1, STEEL)


def bevel(img, x, y, w, h, light, dark):
    """Top-left lit, bottom-right shaded — the whole kit is lit from up-left."""
    hline(img, x, y, w, light)
    vline(img, x, y, h, light)
    hline(img, x, y + h - 1, w, dark)
    vline(img, x + w - 1, y, h, dark)


def corner_notch(img, w, h, depth=2):
    """Chamfer all four corners so no surface is a hard rectangle."""
    for step in range(depth):
        for dx in range(depth - step):
            for cx, cy in ((dx, step), (w - 1 - dx, step),
                           (dx, h - 1 - step), (w - 1 - dx, h - 1 - step)):
                px(img, cx, cy, (0, 0, 0, 0))


def drop_shadow(img, x, y, w, h):
    """The two-step shadow every layer casts on the one beneath it."""
    hline(img, x + 1, y + h, w - 1, SHADOW_1)
    hline(img, x + 2, y + h + 1, w - 2, SHADOW_2)
    vline(img, x + w, y + 1, h - 1, SHADOW_1)
    vline(img, x + w + 1, y + 2, h - 2, SHADOW_2)


def wood_grain(img, x, y, w, h, seed=3):
    """Streaks along the grain, plus a couple of knots."""
    import random as _random
    rng = _random.Random(seed)
    for row in range(y, y + h):
        if rng.random() < 0.34:
            length = rng.randint(2, max(2, w - 2))
            start = rng.randint(x, max(x, x + w - length))
            tone = WOOD_L if rng.random() < 0.6 else WOOD_D
            hline(img, start, row, length, tone)
    for _ in range(2):
        kx = rng.randint(x + 1, x + max(1, w - 2))
        ky = rng.randint(y, y + max(0, h - 1))
        px(img, kx, ky, WOOD_XD)


def paper_fibre(img, x, y, w, h, seed=11):
    """Sparse fibre flecks. Kept within a few points of the field's luminance
    so the contrast suite still measures what it thinks it measures."""
    speckle(img, x, y, w, h, [PAPER_FIBRE, PAPER_L], 0.16, seed=seed)


# ------------------------------------------------------------------ surfaces

def _container_board(name, t):
    """32x32 nine-patch, margin 12: a board is the end wall of a container.

    Painted corrugated steel in one of the yard's liveries, a corner casting
    in each corner, and the manifest sheet sunk into it. The ribs are on a
    4px period so they tile along every edge.
    """
    xd, d, base, l, xl = t
    s = 32
    img = new_img(s, s)
    rect(img, 0, 0, s, s, xd)
    rect(img, 1, 1, s - 2, s - 2, base)
    hline(img, 1, 1, s - 2, xl)
    vline(img, 1, 2, s - 3, l)
    hline(img, 1, s - 2, s - 2, d)
    vline(img, s - 2, 2, s - 3, d)
    for x in range(2, s - 2):
        if x % 4 == 0:
            for y in (2, 3, 4, s - 5, s - 4, s - 3):
                px(img, x, y, d)
        elif x % 4 == 1:
            for y in (2, 3, 4, s - 5, s - 4, s - 3):
                px(img, x, y, l)
    for y in range(6, s - 6):
        if y % 4 == 0:
            for x in (2, 3, 4, s - 5, s - 4, s - 3):
                px(img, x, y, d)
        elif y % 4 == 1:
            for x in (2, 3, 4, s - 5, s - 4, s - 3):
                px(img, x, y, l)
    # corner castings: the steel blocks a spreader locks into
    for cx, cy in ((1, 1), (s - 6, 1), (1, s - 6), (s - 6, s - 6)):
        rect(img, cx, cy, 5, 5, STEEL_D)
        hline(img, cx, cy, 5, STEEL_XL)
        vline(img, cx, cy, 5, STEEL_L)
        hline(img, cx, cy + 4, 5, STEEL_XD)
        vline(img, cx + 4, cy, 5, STEEL_XD)
        rect(img, cx + 2, cy + 1, 1, 3, STEEL_XD)
    # the sheet, sunk into the wall
    rect(img, 5, 5, s - 10, s - 10, xd)
    rect(img, 6, 6, s - 12, s - 12, PAPER_XD)
    rect(img, 7, 7, s - 14, s - 14, DECK)
    hline(img, 7, 7, s - 14, DECK_SHADE)
    vline(img, 7, 7, s - 14, DECK_SHADE)
    hline(img, 7, s - 8, s - 14, PAPER_XL)
    save(img, name)


def gen_board():
    for tone, ramp in LIVERY.items():
        _container_board("ui_board" if tone == "rust" else "ui_board_" + tone,
                         ramp)


def gen_clip():
    """The spreader a board hangs from, 72x22.

    Every board is lowered into view by the same yellow spreader the quay
    cranes carry: two cables, a beam with hazard ends, and a twist-lock
    gripping each top corner. Same footprint as the old clip, because
    `UiTheme.place_clip` and the rise animation are cut to it.
    """
    w, h = 72, 22
    img = new_img(w, h)
    YEL_XD, YEL_D, YEL, YEL_L = (104, 66, 10, 255), (188, 128, 22, 255), \
        (244, 190, 44, 255), (255, 228, 128, 255)
    HAZ = (40, 34, 36, 255)
    rect(img, 6, h - 3, w - 12, 2, SHADOW_1)
    rect(img, 9, h - 1, w - 18, 1, SHADOW_2)
    for cx in (22, w - 25):
        rect(img, cx, 0, 3, 7, STEEL_XD)
        vline(img, cx + 1, 0, 7, STEEL_L)
    # head block the cables meet at
    rect(img, 28, 2, w - 56, 5, STEEL_XD)
    rect(img, 29, 3, w - 58, 3, STEEL_D)
    hline(img, 29, 3, w - 58, STEEL_L)
    # the beam
    rect(img, 1, 6, w - 2, 11, YEL_XD)
    rect(img, 2, 7, w - 4, 9, YEL)
    hline(img, 3, 7, w - 6, YEL_L)
    hline(img, 2, 14, w - 4, YEL_D)
    hline(img, 2, 15, w - 4, YEL_D)
    for end in (3, w - 17):
        for x in range(14):
            for y in range(7):
                if (x + y) % 6 < 3:
                    px(img, end + x, 8 + y, HAZ)
    # nameplate
    rect(img, 26, 9, w - 52, 5, YEL_XD)
    rect(img, 27, 10, w - 54, 3, HAZ)
    for lx in (30, 35, 40):
        px(img, lx, 11, YEL_L)
    # twist-locks reaching down onto the board
    for fx in (5, w - 11):
        rect(img, fx, 16, 6, 4, STEEL_XD)
        rect(img, fx + 1, 16, 4, 3, STEEL)
        hline(img, fx + 1, 16, 4, STEEL_XL)
    corner_notch(img, w, h, 1)
    save(img, "ui_clip")


def gen_paper():
    """16x16 nine-patch, margin 5: the tray a list of labels lies in."""
    s = 16
    img = new_img(s, s)
    rect(img, 0, 0, s, s, PAPER_XD)
    rect(img, 1, 1, s - 2, s - 2, PAPER_D)
    hline(img, 1, 1, s - 2, (176, 154, 118, 255))
    vline(img, 1, 1, s - 2, (190, 168, 132, 255))
    hline(img, 1, s - 2, s - 2, (236, 220, 188, 255))
    for cx, cy in ((0, 0), (s - 1, 0), (0, s - 1), (s - 1, s - 1)):
        px(img, cx, cy, (0, 0, 0, 0))
    save(img, "ui_paper")


def _card(name, field, edge, edge_hi, rail=None, fibre_seed=31):
    """16x16 nine-patch, margin 5: one cargo label.

    A thick sticker: clean field, a white top edge, a two-step skirt so it has
    thickness, and a hard shadow under it. A coloured stub on the left says
    what state it is in (green: you can buy it, teal: done).
    """
    s = 16
    img = new_img(s, s)
    hline(img, 2, s - 1, s - 3, SHADOW_1)
    vline(img, s - 1, 2, s - 3, SHADOW_2)
    rect(img, 0, 0, s - 1, s - 1, edge)
    rect(img, 1, 1, s - 3, s - 3, field)
    hline(img, 1, 1, s - 3, edge_hi)
    hline(img, 1, s - 4, s - 3, _shade(field, 0.90))
    hline(img, 1, s - 3, s - 3, _shade(field, 0.74))
    if rail is not None:
        vline(img, 1, 1, s - 3, rail[1])
        vline(img, 2, 1, s - 3, rail[1])
        vline(img, 3, 1, s - 3, rail[2])
        hline(img, 1, 1, 3, rail[2])
        hline(img, 1, s - 3, 3, rail[0])
    for cx, cy in ((0, 0), (s - 2, 0), (0, s - 2), (s - 2, s - 2)):
        px(img, cx, cy, (0, 0, 0, 0))
    save(img, name)


def _mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def _shade(color, k):
    return (int(color[0] * k), int(color[1] * k), int(color[2] * k), 255)


def gen_cards():
    _card("ui_card", PAPER, PAPER_XD, PAPER_XL)
    _card("ui_card_hi", PAPER_L, GO_XD, PAPER_XL, rail=(GO_D, GO, GO_L))
    _card("ui_card_off", (218, 206, 186, 255), (150, 132, 110, 255),
          (232, 222, 204, 255))
    _card("ui_card_done", (212, 234, 216, 255), TEAL_XD, (240, 250, 240, 255),
          rail=(TEAL_D, TEAL, TEAL_L))


def gen_slate():
    """14x14 nine-patch, margin 5: the chalkboard plate a number is written on."""
    def plate(name, border):
        s = 14
        img = new_img(s, s)
        hline(img, 2, s - 1, s - 3, SHADOW_1)
        rect(img, 0, 0, s - 1, s - 1, border)
        rect(img, 1, 1, s - 3, s - 3, SLATE_D)
        hline(img, 1, 1, s - 3, SLATE_XD)
        vline(img, 1, 1, s - 3, SLATE_XD)
        hline(img, 1, s - 3, s - 3, SLATE)
        vline(img, s - 3, 1, s - 3, SLATE)
        for cx, cy in ((0, 0), (s - 2, 0), (0, s - 2), (s - 2, s - 2)):
            px(img, cx, cy, (0, 0, 0, 0))
        save(img, name)

    plate("ui_slate", SLATE_XD)
    plate("ui_slate_lit", AMBER_D)


def gen_well():
    """14x14 nine-patch, margin 5: the sky-blue window an item stands in."""
    s = 14
    img = new_img(s, s)
    rect(img, 0, 0, s, s, PAPER_XD)
    rect(img, 1, 1, s - 2, s - 2, WELL)
    hline(img, 1, 1, s - 2, (138, 180, 186, 255))
    hline(img, 1, 2, s - 2, (166, 204, 206, 255))
    vline(img, 1, 1, s - 2, (152, 192, 196, 255))
    hline(img, 1, s - 2, s - 2, (232, 246, 240, 255))
    corner_notch(img, s, s, 1)
    save(img, "ui_well")



def gen_badge():
    """The staff ID card: laminate, a teal header band, a photo mount and a clip.

    A personnel record printed as rows of text reads as a form. The same record
    on a card with the person's photograph on it reads as their badge, which is
    what it actually is — so this is the one overlay that is not a slip off the
    manifest.
    """
    s = 16
    # --- the laminated card ---
    card = new_img(s, s)
    hline(card, 2, s - 1, s - 3, SHADOW_1)
    vline(card, s - 1, 2, s - 3, SHADOW_1)
    rect(card, 0, 0, s - 1, s - 1, TEAL_D)
    rect(card, 1, 1, s - 3, s - 3, PAPER)
    hline(card, 1, 1, s - 3, PAPER_XL)
    vline(card, 1, 1, s - 3, (58, 74, 100, 255))
    hline(card, 1, s - 3, s - 3, PAPER_D)
    for cx, cy in ((0, 0), (s - 2, 0), (0, s - 2), (s - 2, s - 2)):
        px(card, cx, cy, (0, 0, 0, 0))
    save(card, "ui_badge")

    # --- the header band the port's name sits on ---
    head = new_img(s, s)
    rect(head, 0, 0, s, s, TEAL_D)
    rect(head, 0, 1, s, s - 3, TEAL)
    hline(head, 0, 1, s, TEAL_L)
    hline(head, 0, s - 2, s, TEAL_XD)
    hline(head, 0, s - 1, s, SHADOW_1)
    save(head, "ui_badge_head")

    # --- the photo mount: white print border, sunk into the card ---
    photo = new_img(s, s)
    rect(photo, 0, 0, s, s, PAPER_XD)
    rect(photo, 1, 1, s - 2, s - 2, PRINT_WHITE)
    rect(photo, 3, 3, s - 6, s - 6, (58, 62, 78, 255))
    hline(photo, 1, 1, s - 2, (176, 170, 158, 255))
    vline(photo, 1, 1, s - 2, (176, 170, 158, 255))
    hline(photo, 1, s - 2, s - 2, (255, 255, 250, 255))
    hline(photo, 3, 3, s - 6, (36, 40, 52, 255))
    save(photo, "ui_photo")

    # --- the bulldog clip the lanyard hangs from ---
    w, h = 26, 11
    clip = new_img(w, h)
    rect(clip, 3, h - 2, w - 6, 2, SHADOW_1)
    rect(clip, 6, 0, w - 12, 3, STEEL_D)
    rect(clip, 7, 0, w - 14, 2, STEEL_L)
    rect(clip, 1, 3, w - 2, h - 5, STEEL_XD)
    rect(clip, 2, 4, w - 4, h - 8, STEEL)
    hline(clip, 3, 4, w - 6, STEEL_XL)
    hline(clip, 2, h - 5, w - 4, STEEL_D)
    for rx in (5, w - 7):
        rivet(clip, rx, 5)
    corner_notch(clip, w, h, 1)
    save(clip, "ui_badge_clip", preview_scale=8)


# ------------------------------------------------- steel: the terminal's own

def _steel_panel(name, rows, rivet_y):
    """32x24 nine-patch, margin 11: a bolted enamel panel.

    The geometry is dictated by how a nine-patch tiles. The middle band is two
    rows and repeats, so those two rows are body and body-dark and the repeat
    *is* the brushed pinstripe rather than a seam. Everything else that runs
    across the panel is a full-width horizontal line, which tiles invisibly;
    anything that must not repeat — rivets, end caps — lives in the 11px corner
    regions, which a nine-patch never tiles.
    """
    w, h = 32, 24
    img = new_img(w, h)
    rect(img, 0, 0, w, h, HULL)
    for row, tone in rows:
        hline(img, 0, row, w, tone)
    # The tiled middle: body over body-dark, which repeats into a fine pinstripe.
    hline(img, 0, 11, w, HULL)
    hline(img, 0, 12, w, HULL_D)
    for cx in (0, w - 1):
        vline(img, cx, 0, h, HULL_XD)
    for cx in (4, w - 5):
        rivet(img, cx, rivet_y)
    save(img, name)


def gen_gantry():
    """The two panels the HUD is bolted to.

    Both are lit from above, like everything else in the game — the amber
    hairline, not the highlight, is what moves to whichever edge faces the port,
    because it is a painted edge marking rather than a reflection.
    """
    _steel_panel("ui_gantry", [
        (0, HULL_XL),           # lit lip along the top
        (1, HULL_L),
        (3, HULL_L),            # brushed streak
        (19, HULL_D),
        (20, HULL_D),
        (21, HULL_XD),
        (22, AMBER),            # the edge facing the port
        (23, AMBER_XD),
    ], rivet_y=6)
    _steel_panel("ui_console", [
        (0, AMBER_XD),
        (1, AMBER),             # the edge facing the port
        (2, HULL_XL),           # lit lip under it
        (3, HULL_L),
        (5, HULL_L),            # brushed streak
        (21, HULL_D),
        (22, HULL_D),
        (23, HULL_XD),
    ], rivet_y=17)


def gen_glass():
    """16x16 nine-patch, margin 5: the dark glass a lit number sits behind.

    A tally is an instrument, not a caption, so the digits are lit behind glass
    set into the panel rather than printed on it. Recessed: the top-left edge is
    the shadow the frame casts inside, the bottom-right catches the light, and
    the field carries 2px scanlines so it reads as something switched on.
    """
    s = 16
    img = new_img(s, s)
    rect(img, 0, 0, s, s, HULL_XD)
    rect(img, 1, 1, s - 2, s - 2, GLASS_D)
    # scanlines: pitch 2 over an even-height middle band, so the tile is seamless
    for ry in range(1, s - 1, 2):
        hline(img, 1, ry, s - 2, GLASS)
    # the recess — dark where the frame overhangs, lit on the far side
    hline(img, 1, 1, s - 2, GLASS_XD)
    vline(img, 1, 1, s - 2, GLASS_XD)
    hline(img, 1, s - 2, s - 2, GLASS_GLOW)
    vline(img, s - 2, 1, s - 2, GLASS_GLOW)
    # the frame's own lit bottom-right lip, outside the glass
    hline(img, 1, 0, s - 2, HULL_D)
    hline(img, 1, s - 1, s - 2, HULL_L)
    vline(img, s - 1, 1, s - 2, HULL_L)
    for cx, cy in ((0, 0), (s - 1, 0), (0, s - 1), (s - 1, s - 1)):
        px(img, cx, cy, (0, 0, 0, 0))
    save(img, "ui_glass")


def gen_tip():
    """10x10 nine-patch, margin 3: the caption a hover puts under the pointer.

    Godot draws its own tooltip, so until now it borrowed the gantry's enamel
    job tag — a sixteen-pixel sign with a teal service spine, rivets and five
    pixels of margin on every side. Around a single word like RAMAL that is a
    road sign hanging over the terminal, and it is the only object on screen not
    drawn at the game's own weight.

    This is the smallest thing that can hold a line of text: one pixel of ink,
    a dark face, a lit top edge and nothing else. It gets three pixels of
    margin, not five, because a tooltip is a caption and a caption is mostly
    the words in it.
    """
    s = 10
    img = new_img(s, s)
    rect(img, 0, 0, s, s, INK)
    rect(img, 1, 1, s - 2, s - 2, HULL_D)
    hline(img, 1, 1, s - 2, HULL)
    hline(img, 1, s - 2, s - 2, HULL_XD)
    # The corners knocked off, so it reads as a small chip rather than a slab.
    for cx, cy in ((0, 0), (s - 1, 0), (0, s - 1), (s - 1, s - 1)):
        px(img, cx, cy, (0, 0, 0, 0))
    save(img, "ui_tip", preview_scale=8)


def gen_tag():
    """16x16 nine-patch, margin 5: the enamel job tag that hangs off the gantry.

    Whatever the berth is doing is the one line of text that changes every few
    seconds, so it gets its own object instead of a slab of the bar: a small
    dark sign with a teal service spine down the left and a screw at each end.
    """
    s = 16
    img = new_img(s, s)
    hline(img, 2, s - 1, s - 3, SHADOW_1)
    rect(img, 0, 0, s, s - 1, HULL_XD)
    rect(img, 1, 1, s - 2, s - 3, HULL_D)
    hline(img, 1, 1, s - 2, HULL_L)
    hline(img, 1, s - 3, s - 2, HULL_XD)
    # the service spine, in the left margin so it is drawn once however wide the
    # tag has to grow
    vline(img, 1, 1, s - 3, TEAL_D)
    vline(img, 2, 1, s - 3, TEAL)
    px(img, 2, 1, TEAL_L)
    for sx in (5, s - 4):
        px(img, sx, 2, HULL_XL)
        px(img, sx, 3, HULL_XD)
    for cx, cy in ((0, 0), (s - 1, 0), (0, s - 2), (s - 1, s - 2)):
        px(img, cx, cy, (0, 0, 0, 0))
    save(img, "ui_tag")


def gen_indicators():
    """The two small lights the HUD blinks: a status LED and a notice pip.

    A key that has something waiting behind it and a berth that wants a tap are
    both "look here" with no room for a word, and a lamp is how a control panel
    has always said it.
    """
    # LED: dim, teal (running), amber (wants you)
    frames = []
    for core, ring, glow in (
            ((58, 70, 90, 255), HULL_XD, None),
            (TEAL_L, TEAL_XD, TEAL),
            (AMBER_L, AMBER_XD, AMBER)):
        img = new_img(8, 8)
        for y in range(8):
            for x in range(8):
                d = ((x - 3.5) ** 2 + (y - 3.5) ** 2) ** 0.5
                if d <= 3.5:
                    px(img, x, y, ring)
                if d <= 2.5:
                    px(img, x, y, glow or core)
                if d <= 1.6:
                    px(img, x, y, core)
        px(img, 2, 2, (255, 255, 255, 190))
        frames.append(img)
    save(sheet(frames), "ui_led", preview_scale=8)

    pip = new_img(6, 6)
    for y in range(6):
        for x in range(6):
            d = ((x - 2.5) ** 2 + (y - 2.5) ** 2) ** 0.5
            if d <= 2.9:
                px(pip, x, y, AMBER_XD)
            if d <= 2.1:
                px(pip, x, y, AMBER)
            if d <= 1.2:
                px(pip, x, y, AMBER_L)
    px(pip, 2, 1, AMBER_XL)
    save(pip, "ui_pip", preview_scale=10)


# ------------------------------------------------------------------- controls

def _button(base, light, xlight, dark, xdark, name):
    """16x16 nine-patch, margin 5: a chunky moulded key.

    Lit top face, a two-row skirt and a hard cast shadow: thick enough that it
    reads as something you push down, not a coloured rectangle.
    """
    s = 16
    img = new_img(s, s)
    hline(img, 2, s - 1, s - 3, SHADOW_1)
    vline(img, s - 1, 2, s - 3, SHADOW_1)
    rect(img, 0, 0, s - 1, s - 1, xdark)
    rect(img, 1, 1, s - 3, s - 3, base)
    hline(img, 2, 1, s - 5, xlight)
    hline(img, 1, 2, s - 3, light)
    vline(img, 1, 2, s - 6, light)
    px(img, 2, 3, xlight)
    hline(img, 1, s - 5, s - 3, dark)
    hline(img, 1, s - 4, s - 3, dark)
    hline(img, 1, s - 3, s - 3, xdark)
    vline(img, s - 3, 2, s - 5, dark)
    for cx, cy in ((0, 0), (s - 2, 0), (0, s - 2), (s - 2, s - 2)):
        px(img, cx, cy, (0, 0, 0, 0))
    save(img, name)


def _flat_key(field, edge, name):
    """16x16 nine-patch, margin 5: a key that is not there yet — flat, no
    shadow, the colour of the sheet it sits on."""
    s = 16
    img = new_img(s, s)
    rect(img, 0, 0, s - 1, s - 1, edge)
    rect(img, 1, 1, s - 3, s - 3, field)
    for cx, cy in ((0, 0), (s - 2, 0), (0, s - 2), (s - 2, s - 2)):
        px(img, cx, cy, (0, 0, 0, 0))
    save(img, name)


def gen_buttons():
    _button(AMBER, AMBER_L, AMBER_XL, AMBER_D, AMBER_XD, "ui_btn")
    _button(AMBER_D, AMBER, AMBER_L, AMBER_XD, AMBER_XD, "ui_btn_down")
    _button(GO, GO_L, GO_XL, GO_D, GO_XD, "ui_btn_go")
    _button(TEAL, TEAL_L, TEAL_XL, TEAL_D, TEAL_XD, "ui_btn_alt")
    _flat_key((214, 198, 170, 255), (170, 150, 120, 255), "ui_btn_off")
    _button(RUST, RUST_L, (222, 140, 116, 255), RUST_D, RUST_XD, "ui_btn_danger")
    _button(PAPER, PAPER_L, PAPER_XL, (206, 188, 156, 255), PAPER_XD,
            "ui_btn_ghost")
    _button(HULL, HULL_L, HULL_XL, HULL_D, HULL_XD, "ui_btn_steel")
    _button(HULL_D, HULL, HULL_L, HULL_XD, HULL_XD, "ui_btn_steel_down")


def gen_tabs():
    """16x16 nine-patch, margin 5: index dividers standing on the sheet.

    The open one is a bright label with the livery's stripe across its top;
    the rest are kraft dividers behind it.
    """
    s = 16
    on = new_img(s, s)
    rect(on, 0, 0, s, s, PAPER_XD)
    rect(on, 1, 1, s - 2, s - 1, PAPER_L)
    hline(on, 1, 1, s - 2, AMBER_L)
    hline(on, 1, 2, s - 2, AMBER)
    hline(on, 1, 3, s - 2, AMBER_D)
    for cx in (0, s - 1):
        px(on, cx, 0, (0, 0, 0, 0))
    save(on, "ui_tab_on")

    off = new_img(s, s)
    rect(off, 0, 2, s, s - 2, (128, 104, 78, 255))
    rect(off, 1, 3, s - 2, s - 4, (210, 188, 152, 255))
    hline(off, 2, 3, s - 4, (230, 212, 180, 255))
    hline(off, 1, s - 2, s - 2, (170, 146, 110, 255))
    for cx in (0, s - 1):
        px(off, cx, 2, (0, 0, 0, 0))
    save(off, "ui_tab_off")


def gen_header():
    """16x16 nine-patch, margin 5: the painted band across the top of a board.

    The container's own livery with a stencilled title, ribbed like the wall,
    and a hazard stripe along its foot. One per livery.
    """
    HAZ_Y, HAZ_K = (248, 198, 44, 255), (40, 34, 36, 255)
    for tone, (xd, d, base, l, xl) in LIVERY.items():
        s = 16
        img = new_img(s, s)
        hline(img, 1, s - 1, s - 2, SHADOW_1)
        rect(img, 0, 0, s, s - 1, xd)
        rect(img, 1, 1, s - 2, s - 5, base)
        hline(img, 1, 1, s - 2, xl)
        hline(img, 1, 2, s - 2, l)
        for x in range(1, s - 1):
            if x % 3 == 2:
                vline(img, x, 3, s - 8, _mix(base, d, 0.45))
        hline(img, 1, s - 5, s - 2, d)
        for x in range(1, s - 1):
            px(img, x, s - 4, HAZ_Y if x % 6 < 3 else HAZ_K)
            px(img, x, s - 3, HAZ_Y if (x + 1) % 6 < 3 else HAZ_K)
        for cx, cy in ((0, 0), (s - 1, 0)):
            px(img, cx, cy, (0, 0, 0, 0))
        save(img, "ui_header" if tone == "rust" else "ui_header_" + tone)


def gen_segments():
    """10x10 nine-patch, margin 4: the x1/x10/x25/MAX segmented control."""
    on = new_img(10, 10)
    rect(on, 0, 0, 10, 9, AMBER_XD)
    rect(on, 1, 1, 8, 7, AMBER)
    hline(on, 2, 1, 6, AMBER_XL)
    hline(on, 1, 2, 8, AMBER_L)
    hline(on, 1, 7, 8, AMBER_D)
    hline(on, 1, 9, 8, SHADOW_2)
    save(on, "ui_seg_on")

    off = new_img(10, 10)
    rect(off, 0, 0, 10, 9, (128, 104, 78, 255))
    rect(off, 1, 1, 8, 7, (232, 218, 190, 255))
    hline(off, 1, 1, 8, PAPER_XL)
    hline(off, 1, 7, 8, (204, 186, 152, 255))
    save(off, "ui_seg_off")


def gen_focus():
    """12x12 nine-patch, margin 4: the keyboard focus ring, hollow centre.
    Two tones, so one of them reads on paper and the other on steel."""
    s = 12
    img = new_img(s, s)
    rect(img, 0, 0, s, s, INK)
    rect(img, 1, 1, s - 2, s - 2, (255, 250, 236, 255))
    rect(img, 2, 2, s - 4, s - 4, (0, 0, 0, 0))
    save(img, "ui_focus")


def gen_bar():
    """10x10 nine-patch, margin 4: a progress trough cut into the sheet."""
    bg = new_img(10, 10)
    rect(bg, 0, 0, 10, 10, PAPER_XD)
    rect(bg, 1, 1, 8, 8, (170, 148, 114, 255))
    hline(bg, 1, 1, 8, (140, 118, 88, 255))
    hline(bg, 1, 8, 8, (200, 180, 146, 255))
    save(bg, "ui_bar_bg")

    fill = new_img(10, 10)
    rect(fill, 0, 0, 10, 10, GO_XD)
    rect(fill, 1, 1, 8, 8, GO)
    hline(fill, 1, 1, 8, GO_XL)
    hline(fill, 1, 2, 8, GO_L)
    hline(fill, 1, 8, 8, GO_D)
    save(fill, "ui_bar_fill")


def gen_scroll():
    """10x10 nine-patches, margin 4: a sunk channel and a painted grip."""
    bg = new_img(10, 10)
    rect(bg, 0, 0, 10, 10, (0, 0, 0, 0))
    rect(bg, 3, 0, 4, 10, (186, 164, 128, 255))
    vline(bg, 3, 0, 10, (150, 128, 96, 255))
    vline(bg, 6, 0, 10, (226, 208, 176, 255))
    save(bg, "ui_scroll_bg")

    xd, d, base, l, xl = LIVERY["rust"]
    grab = new_img(10, 10)
    rect(grab, 0, 0, 10, 10, (0, 0, 0, 0))
    rect(grab, 2, 0, 6, 10, xd)
    rect(grab, 3, 1, 4, 8, base)
    vline(grab, 3, 1, 8, l)
    vline(grab, 6, 1, 8, d)
    hline(grab, 3, 1, 4, xl)
    for cx, cy in ((2, 0), (7, 0), (2, 9), (7, 9)):
        px(grab, cx, cy, (0, 0, 0, 0))
    save(grab, "ui_scroll_grab")



def gen_desk_props():
    """Loose objects that live on the board: a carpenter's pencil and a clip.

    Pure ornament, and worth it. A clipboard with nothing but printed rows on
    it reads as a form; one with a pencil lying across the bottom reads as
    something a person was just holding.
    """
    # --- flat carpenter's pencil, lying at a slight angle ---
    w, h = 34, 9
    pencil = new_img(w, h)
    rect(pencil, 2, h - 2, w - 5, 1, SHADOW_1)
    body_x, body_w = 6, w - 12
    rect(pencil, body_x, 1, body_w, 6, (198, 148, 44, 255))
    hline(pencil, body_x, 1, body_w, (232, 186, 78, 255))
    hline(pencil, body_x, 2, body_w, (216, 166, 60, 255))
    hline(pencil, body_x, 6, body_w, (156, 110, 28, 255))
    # painted band and the maker's stripe
    rect(pencil, body_x + 4, 1, 2, 6, (172, 122, 34, 255))
    hline(pencil, body_x + 9, 3, body_w - 14, (240, 206, 120, 255))
    # sharpened tip
    for i in range(5):
        rect(pencil, body_x + body_w + i, 2 + (i // 2), 1, 5 - i, (206, 176, 132, 255))
    rect(pencil, w - 2, 4, 2, 1, (48, 44, 52, 255))
    px(pencil, w - 3, 4, (72, 66, 76, 255))
    # ferrule and eraser
    rect(pencil, body_x - 4, 1, 3, 6, STEEL)
    hline(pencil, body_x - 4, 1, 3, STEEL_L)
    hline(pencil, body_x - 4, 6, 3, STEEL_D)
    rect(pencil, body_x - 6, 2, 2, 4, (206, 128, 116, 255))
    hline(pencil, body_x - 6, 2, 2, (228, 158, 146, 255))
    save(pencil, "ui_pencil")

    # --- steel paperclip, seen flat on ---
    cw, ch = 14, 20
    clip = new_img(cw, ch)
    rect(clip, 3, ch - 2, 8, 1, SHADOW_2)
    for x in (3, 9):
        vline(clip, x, 2, ch - 6, STEEL_D)
    for x in (4, 10):
        vline(clip, x, 2, ch - 6, STEEL_L)
    hline(clip, 3, 2, 8, STEEL_L)
    hline(clip, 3, ch - 4, 8, STEEL_D)
    vline(clip, 6, 5, ch - 10, STEEL)
    vline(clip, 7, 5, ch - 10, STEEL_XL)
    hline(clip, 6, 5, 2, STEEL_L)
    save(clip, "ui_paperclip")


def gen_scrims():
    """The flat dim behind a modal.

    There used to be a vertical fade at the top of the screen here, buying
    legibility for HUD text that had nothing behind it. The tally and the clock
    are instruments set into a steel gantry now, so the fade has nothing left to
    protect and the port keeps those pixels.
    """
    dim = new_img(4, 4)
    rect(dim, 0, 0, 4, 4, (12, 10, 18, 190))
    save(dim, "ui_scrim", preview_scale=8)


def gen_arcade():
    """The cabinet the maze charter is played on.

    A nine-patch of moulded plastic: a dark outer shell, a bevelled lip catching
    the light from above, and a recessed inner edge for the glass to sit behind.
    Everything else about the cabinet — the screen, its scanlines, the stick and
    the buttons — is drawn at runtime, because a tilting joystick as a sprite is
    a sprite per angle.
    """
    w, h = 26, 26
    img = new_img(w, h)
    shell = (44, 40, 52, 255)
    shell_l = (74, 68, 84, 255)
    shell_d = (26, 23, 32, 255)
    rect(img, 0, 0, w, h, (14, 12, 18, 255))
    rect(img, 1, 1, w - 2, h - 2, shell)
    hline(img, 2, 1, w - 4, shell_l)
    vline(img, 1, 2, h - 4, shell_l)
    hline(img, 2, h - 2, w - 4, shell_d)
    vline(img, w - 2, 2, h - 4, shell_d)
    # Speckle in the plastic, so a wide panel is not a flat slab.
    speckle(img, 2, 2, w - 4, h - 4, [shell_l, shell_d], 0.05, seed=515)
    # The recess the glass sits in: dark line, then a lit under-edge.
    rect(img, 6, 6, w - 12, h - 12, (10, 9, 14, 255))
    hline(img, 7, 7, w - 14, (20, 18, 26, 255))
    hline(img, 7, h - 8, w - 14, (58, 52, 66, 255))
    save(img, "ui_arcade_bezel", preview_scale=4)


# ------------------------------------------------------------------ icons

def _icon_base():
    return new_img(12, 12)


def _blit_rows(img, rows, ox, oy, color):
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == "#":
                px(img, x + ox, y + oy, color)


def gen_icons():
    icons = {}

    # TEU: a container seen at a slight angle
    i = _icon_base()
    rect(i, 1, 4, 10, 5, (198, 108, 70, 255))
    hline(i, 1, 4, 10, (232, 148, 100, 255))
    hline(i, 1, 8, 10, (150, 74, 50, 255))
    for x in range(2, 10, 2):
        vline(i, x, 5, 3, (162, 84, 56, 255))
    icons["teu"] = i

    # crane: a gantry in elevation, hoisting.
    #
    # The old one was a red lintel on two red posts with a small amber box
    # between them — a torii gate, which is what it read as on the shop tab that
    # is meant to say "equipment". A crane is legible at 12px only if the *load*
    # is in the silhouette: portal, trolley, a wire, and a box hanging off it,
    # with the legs splayed so the shape is not a rectangle.
    i = _icon_base()
    CRANE_I = (200, 92, 78, 255)
    CRANE_ID = (150, 60, 58, 255)
    hline(i, 1, 1, 10, CRANE_I)                 # top chord
    hline(i, 1, 2, 10, CRANE_ID)
    for step in range(7):                       # splayed legs
        px(i, 2 - step // 4, 3 + step, CRANE_I)
        px(i, 9 + step // 4, 3 + step, CRANE_I)
    rect(i, 5, 1, 3, 2, (226, 138, 112, 255))   # trolley on the chord
    vline(i, 6, 3, 3, (176, 190, 212, 255))     # the wire
    rect(i, 4, 6, 5, 4, (238, 176, 62, 255))    # the box on the hook
    hline(i, 4, 6, 5, (252, 210, 128, 255))
    hline(i, 4, 9, 5, (176, 118, 30, 255))
    icons["crane"] = i

    # ship: a laden hull from above. The old one was a plain taper with a white
    # block on it, which at 2x on a console key read as a house with a door.
    # A pointed bow, a squared stern and two rows of boxes on deck read as a
    # container ship at any size.
    i = _icon_base()
    HULL_ICON = (70, 94, 128, 255)
    HULL_ICON_D = (44, 60, 88, 255)
    for y, half in ((1, 1), (2, 2), (3, 3), (4, 4), (5, 4), (6, 4), (7, 4),
                    (8, 4), (9, 4), (10, 3)):
        rect(i, 6 - half, y, half * 2, 1, HULL_ICON)
    hline(i, 3, 10, 6, HULL_ICON_D)
    px(i, 5, 1, (150, 178, 210, 255))
    for row, tone in ((4, (198, 108, 70, 255)), (5, (110, 154, 96, 255)),
                      (6, (198, 108, 70, 255)), (7, (86, 128, 168, 255))):
        rect(i, 3, row, 2, 1, tone)
        rect(i, 7, row, 2, 1, tone)
    # The accommodation block, aft, with two lit windows. It was six pixels of
    # flat cream across the whole beam, which is the brightest thing in the icon
    # and was reading as the *subject* — a white bar with a blue hat on it.
    rect(i, 4, 8, 4, 2, (226, 218, 202, 255))
    hline(i, 4, 9, 4, (168, 162, 150, 255))
    px(i, 4, 8, (252, 246, 232, 255))
    px(i, 5, 8, (250, 214, 138, 255))
    px(i, 7, 8, (250, 214, 138, 255))
    icons["ship"] = i

    # land: a plot with a post at the corner of it.
    #
    # The old one was a speckled brown rectangle with a white line on top,
    # which reads as a crate, a doormat or a loaf. A parcel of ground needs two
    # things at this size: a *corner* (so it is a plot rather than an object)
    # and a marker standing on it.
    i = _icon_base()
    rect(i, 1, 4, 10, 7, (152, 114, 76, 255))
    speckle(i, 2, 5, 8, 5, [(122, 88, 58, 255), (182, 144, 100, 255)], 0.28,
            seed=2)
    hline(i, 1, 4, 10, (182, 144, 100, 255))    # the lit near edge
    hline(i, 1, 10, 10, (108, 78, 52, 255))
    for gx in range(2, 11, 3):                  # a little planting on it
        px(i, gx, 6, (106, 156, 78, 255))
        px(i, gx + 1, 8, (78, 122, 62, 255))
    vline(i, 9, 0, 5, (226, 218, 202, 255))     # the surveyor's post
    rect(i, 6, 0, 4, 3, (232, 160, 48, 255))    # and its flag
    px(i, 6, 0, (252, 202, 96, 255))
    icons["land"] = i

    # star: prestige
    i = _icon_base()
    _blit_rows(i, ["....##....", "....##....", ".########.", "..######..",
                   "..######..", ".##....##."], 1, 3, (250, 208, 96, 255))
    icons["star"] = i

    # gear: settings. Drawn from an angle-modulated radius rather than a hand
    # bitmap — the hand-drawn one had teeth one pixel deep, and at 2x on a
    # console key a gear with shallow teeth is just a doughnut.
    import math as _math
    i = _icon_base()
    for y in range(12):
        for x in range(12):
            dx = x - 5.5
            dy = y - 5.5
            dist = _math.hypot(dx, dy)
            if dist < 0.1:
                continue
            # Six teeth, each 1.4px proud of the body.
            tooth = _math.cos(6.0 * _math.atan2(dy, dx))
            radius = 4.0 + (1.4 if tooth > 0.35 else 0.0)
            if dist > radius:
                continue
            if dist <= 1.9:
                continue                      # the bore, punched right through
            lit = dx + dy < -1.6
            px(i, x, y, (228, 224, 224, 255) if lit else (176, 170, 172, 255))
            if dist > radius - 1.0 and not lit:
                px(i, x, y, (128, 122, 126, 255))
    icons["gear"] = i

    # speaker: audio toggle
    i = _icon_base()
    rect(i, 2, 5, 2, 3, (196, 190, 190, 255))
    _blit_rows(i, ["..#", ".##", "###", "###", ".##", "..#"], 4, 3,
               (196, 190, 190, 255))
    for wy, wx in ((4, 8), (5, 9), (6, 9), (7, 8)):
        px(i, wx, wy, TEAL_L)
    icons["sound"] = i

    # clock: idle rate
    i = _icon_base()
    for y in range(12):
        for x in range(12):
            dist = ((x - 5.5) ** 2 + (y - 5.5) ** 2) ** 0.5
            if dist <= 4.6:
                px(i, x, y, (226, 218, 202, 255))
            if 3.6 < dist <= 4.6:
                px(i, x, y, (140, 128, 128, 255))
    vline(i, 5, 3, 3, INK)
    hline(i, 6, 6, 2, INK)
    icons["clock"] = i

    # cat paw: a pad and four toes, with a gap between them.
    #
    # The old one ran the four toes edge to edge above a solid bar, which merges
    # into one blob the moment it is tinted. Toes have to be separated by a
    # background pixel each, and the pad has to be rounded, or this is a comb.
    i = _icon_base()
    PAW_I = (206, 158, 106, 255)
    PAW_ID = (162, 116, 74, 255)
    for row, half in ((6, 3), (7, 4), (8, 4), (9, 3)):
        rect(i, 6 - half, row, half * 2, 1, PAW_I)
    hline(i, 3, 9, 6, PAW_ID)
    for cx in (1, 4, 7, 10):                    # four toes, one gap apart
        rect(i, cx, 3, 2, 2, PAW_I)
        px(i, cx, 3, (232, 190, 142, 255))
        px(i, cx, 4, PAW_ID)
    icons["paw"] = i

    # glove: a work glove with the fingers apart and a cuff at the wrist.
    #
    # The old one was a filled amber blob with two notches in the top edge,
    # which at 12px is a mitten at best and a potato at worst. Fingers need a
    # background pixel between them, and the *cuff* is what turns a hand shape
    # into a piece of kit.
    i = _icon_base()
    GLOVE_I = (232, 150, 60, 255)
    GLOVE_IL = (252, 194, 112, 255)
    GLOVE_ID = (176, 106, 34, 255)
    for fx in (2, 4, 6):                        # three fingers, gapped
        rect(i, fx, 1, 1, 3, GLOVE_I)
        px(i, fx, 1, GLOVE_IL)
    rect(i, 8, 3, 2, 2, GLOVE_I)                # the thumb, off to one side
    px(i, 9, 3, GLOVE_IL)
    rect(i, 2, 4, 8, 4, GLOVE_I)                # the palm
    hline(i, 2, 4, 8, GLOVE_IL)
    hline(i, 2, 7, 8, GLOVE_ID)
    rect(i, 3, 8, 6, 3, (196, 190, 190, 255))   # the cuff
    hline(i, 3, 8, 6, (238, 232, 232, 255))
    hline(i, 3, 10, 6, (140, 134, 134, 255))
    icons["glove"] = i

    # globe: a sphere with land on it, not a wheel.
    #
    # A disc with one horizontal and one vertical line through it is a gunsight.
    # What says "globe" at 12px is a *curved* meridian and a couple of blobs of
    # land that break the symmetry.
    i = _icon_base()
    SEA_I = (62, 126, 158, 255)
    SEA_ID = (40, 92, 124, 255)
    for y in range(12):
        for x in range(12):
            dist = ((x - 5.5) ** 2 + (y - 5.5) ** 2) ** 0.5
            if dist <= 5.2:
                px(i, x, y, SEA_I)
            if 4.2 < dist <= 5.2:
                px(i, x, y, SEA_ID)
    hline(i, 2, 5, 8, (120, 180, 202, 255))     # the equator
    for row, half in ((1, 1), (2, 2), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3),
                      (8, 2), (9, 1)):          # a meridian, bowed
        px(i, 5 - half + 2, row, (120, 180, 202, 255))
    for lx, ly, lw in ((2, 3, 3), (7, 4, 3), (3, 7, 4), (8, 8, 2)):
        hline(i, lx, ly, lw, (106, 156, 78, 255))
        px(i, lx, ly, (140, 186, 100, 255))
    px(i, 3, 2, (168, 214, 224, 255))           # specular
    icons["globe"] = i

    # padlock: brass body, steel shackle, one keyhole.
    #
    # The old one was a grey arch on a grey rectangle, and grey is what the
    # gear, the speaker, the clock and the lorry are already made of — on a
    # shelf of twenty-one icons it was one more grey box. A padlock is brass in
    # every game that has ever drawn one, and the two materials are what give
    # the shape a shackle *and* a body instead of one silhouette.
    i = _icon_base()
    for sx in (3, 8):                            # the shackle's two legs
        vline(i, sx, 2, 3, (176, 174, 188, 255))
        px(i, sx, 2, (214, 212, 222, 255))
    hline(i, 4, 1, 4, (196, 194, 206, 255))      # and its crown
    hline(i, 4, 0, 4, (226, 226, 234, 255))
    rect(i, 1, 5, 10, 6, (176, 112, 30, 255))    # the body
    hline(i, 1, 5, 10, (232, 160, 48, 255))      # lit top edge
    hline(i, 1, 10, 10, (128, 78, 18, 255))
    px(i, 1, 5, (252, 202, 96, 255))
    rect(i, 5, 7, 2, 2, (58, 44, 46, 255))       # the keyhole, round and slot
    px(i, 5, 9, (58, 44, 46, 255))
    px(i, 6, 9, (58, 44, 46, 255))
    icons["lock"] = i

    # tick: completed
    i = _icon_base()
    _blit_rows(i, ["......##", ".....##.", "##...##.", ".##.##..",
                   "..###...", "...#...."], 2, 3, TEAL_L)
    icons["check"] = i

    # cross: close
    i = _icon_base()
    _blit_rows(i, ["##....##", ".##..##.", "..####..", "...##...",
                   "..####..", ".##..##.", "##....##"], 2, 3, (232, 118, 96, 255))
    icons["close"] = i

    # chevron: drill into a screen
    i = _icon_base()
    _blit_rows(i, ["##...", ".##..", "..##.", "...##", "..##.", ".##..",
                   "##..."], 4, 3, INK_SOFT)
    icons["chevron"] = i

    # truck: a box body, a cab stepped down in front of it, and wheels under
    # both. The old one had the cab and the body at the same height, so the
    # silhouette was one long rectangle on two dots — a bus, or a bench.
    i = _icon_base()
    rect(i, 0, 3, 7, 5, (72, 116, 172, 255))    # the box body
    hline(i, 0, 3, 7, (110, 154, 206, 255))
    hline(i, 0, 7, 7, (48, 82, 130, 255))
    for rib in range(2, 6, 2):
        vline(i, rib, 4, 3, (58, 96, 148, 255))
    rect(i, 7, 5, 4, 3, (150, 144, 148, 255))   # the cab, lower and forward
    hline(i, 7, 5, 4, (200, 194, 196, 255))
    px(i, 10, 6, (150, 206, 216, 255))          # windscreen
    for wx in (1, 4, 8):
        rect(i, wx, 8, 2, 2, (40, 36, 42, 255))
        px(i, wx, 9, (96, 92, 100, 255))
    icons["truck"] = i

    # trophy: career and achievements
    i = _icon_base()
    rect(i, 3, 2, 6, 4, AMBER)
    hline(i, 3, 2, 6, AMBER_L)
    _blit_rows(i, ["####", ".##.", "####"], 4, 6, AMBER_D)
    px(i, 2, 3, AMBER_D)
    px(i, 9, 3, AMBER_D)
    icons["trophy"] = i

    # bell: the notice log. Nothing interrupts the port any more, so this is the
    # only thing that says a notice happened at all.
    # What makes a bell a bell is the *waist*: a narrow round shoulder that
    # hangs almost straight down and then flares hard in the last two rows. The
    # first version widened one pixel per row from the crown to the lip, which
    # is a cone — and a small amber cone with a dot under it is a traffic cone,
    # or a Christmas tree, which is what the player saw on the gantry.
    i = _icon_base()
    px(i, 5, 0, AMBER_D)                       # the loop it hangs from
    px(i, 6, 0, AMBER_D)
    px(i, 5, 1, AMBER_L)
    px(i, 6, 1, AMBER_D)
    # Shoulder, body, flare: 2, 3, 3, 3, 4, 5 half-widths — flat through the
    # middle so the silhouette has a straight side to read against, then out.
    for row, half in ((2, 2), (3, 3), (4, 3), (5, 3), (6, 4), (7, 5)):
        rect(i, 6 - half, row, half * 2, 1, AMBER)
        px(i, 6 - half, row, AMBER_L)          # lit edge, light from upper left
        px(i, 5 + half, row, AMBER_D)
    hline(i, 0, 8, 12, AMBER)                  # the lip, proud of the body
    px(i, 0, 8, AMBER_L)
    px(i, 11, 8, AMBER_D)
    hline(i, 1, 9, 10, AMBER_XD)               # the rim's shadow under it
    rect(i, 5, 10, 2, 2, AMBER_D)              # the clapper, swung clear
    px(i, 4, 3, AMBER_XL)                      # one specular on the shoulder
    icons["bell"] = i

    # chat: the feedback key on the title screen. A speech bubble is the one
    # shape that says "tell us" without a word in it, but only if the tail is
    # unmistakable — a rounded box with three dots is a loading spinner.
    i = _icon_base()
    rect(i, 0, 0, 12, 9, (58, 42, 52, 255))
    rect(i, 1, 1, 10, 7, (226, 218, 202, 255))
    hline(i, 2, 1, 8, (250, 244, 232, 255))
    hline(i, 2, 7, 8, (186, 176, 166, 255))
    rect(i, 2, 9, 4, 2, (58, 42, 52, 255))     # the tail, stepping down left
    rect(i, 2, 11, 2, 1, (58, 42, 52, 255))
    for x in (3, 5, 7):                        # mid-sentence
        px(i, x, 4, (110, 96, 100, 255))
    icons["chat"] = i

    # crew: two of the terminal's own people, and the front one wears the hat.
    #
    # Two rules at this size, both learned by breaking them. A figure has to be
    # one *continuous* silhouette — head sitting straight on the shoulders with
    # no row between them, or it reads as a ball above a box. And the two of
    # them are separated by a column of nothing, not by a line of ink: ink is
    # invisible against the navy keys half of these icons live on, and the gap
    # has to work on any background.
    i = _icon_base()
    STEEL_I = (150, 146, 160, 255)
    CREAM_I = (236, 228, 212, 255)
    # Behind: taller, cooler, offset right. Head straight onto the shoulders.
    rect(i, 7, 1, 3, 3, STEEL_I)
    px(i, 7, 1, (190, 186, 198, 255))
    rect(i, 6, 4, 5, 8, STEEL_I)
    hline(i, 6, 4, 5, (186, 182, 194, 255))
    # In front: shorter, warmer, in an amber hard hat with a brim.
    rect(i, 1, 3, 3, 1, (232, 160, 48, 255))
    hline(i, 0, 4, 5, (252, 202, 96, 255))
    rect(i, 1, 5, 3, 2, CREAM_I)
    px(i, 1, 5, (198, 190, 176, 255))
    rect(i, 0, 7, 5, 5, CREAM_I)
    hline(i, 0, 7, 5, (255, 250, 236, 255))
    icons["crew"] = i

    # train: the branch line. The third door into the terminal had to borrow the
    # lorry for its notices, which read as a road delivery every time — and the
    # one thing a player needs from a rail notice is to know it is *not* one.
    # Drawn from the side rather than from above like the world sprite: at 12px
    # a plan-view locomotive is a rectangle, and the silhouette that says
    # "train" is a cab, a hood and a row of wheels under it.
    i = _icon_base()
    rect(i, 1, 5, 6, 4, (46, 116, 116, 255))        # hood
    hline(i, 1, 5, 6, (72, 156, 150, 255))
    hline(i, 1, 8, 6, (26, 74, 74, 255))
    rect(i, 7, 2, 4, 7, (46, 116, 116, 255))        # cab, standing above it
    hline(i, 7, 2, 4, (122, 196, 182, 255))
    rect(i, 8, 4, 3, 2, (150, 206, 216, 255))       # cab window
    # The warning panel on the nose. A teal loco on a navy key is one value all
    # the way through; every real shunter has a yellow end for exactly this
    # reason, and it is what separates the front from the back at 12px.
    rect(i, 0, 5, 1, 4, (238, 176, 62, 255))
    px(i, 2, 4, (94, 90, 104, 255))                 # exhaust stack
    px(i, 2, 3, (176, 190, 212, 255))
    for wx in (2, 5, 8):                            # wheels on the rail
        rect(i, wx, 9, 2, 2, (48, 44, 50, 255))
    hline(i, 0, 11, 12, (130, 126, 138, 255))       # the rail itself
    icons["train"] = i

    order = ["teu", "crane", "ship", "land", "star", "gear", "sound", "clock",
             "paw", "glove", "globe", "lock", "check", "close", "chevron",
             "truck", "trophy", "bell", "chat", "crew", "train"]
    save(sheet([icons[k] for k in order]), "ui_icons")
    print("    icon order:", ", ".join(order))


if __name__ == "__main__":
    print("ui:")
    gen_arcade()
    gen_board()
    gen_clip()
    gen_paper()
    gen_cards()
    gen_slate()
    gen_well()
    gen_badge()
    gen_gantry()
    gen_glass()
    gen_tag()
    gen_tip()
    gen_indicators()
    gen_buttons()
    gen_tabs()
    gen_header()
    gen_segments()
    gen_focus()
    gen_bar()
    gen_scroll()
    gen_desk_props()
    gen_scrims()
    gen_icons()
