"""UI chrome, in the two materials the terminal is actually made of.

**Paper** is the paperwork you pick up: every overlay is one weathered wooden
clipboard with steel corner protectors, a chrome spring clip, and a stack of
manifest sheets under it. Cards are slips torn off that manifest and prices are
ink stamped into a steel plate.

**Steel** is the terminal's own signage and instrumentation: the gantry bolted
across the top of the quay carrying the tally and the clock, the console the
keys sit on, and the dark glass a number is lit behind. It is navy enamel with
a lit lip, a fine brushed pinstripe and one amber hairline along the edge that
faces the port — the same amber the machines wear.

The split is the point. Anything permanent over the port is steel, so it reads
as part of the terminal rather than a panel floating on it; anything you open
is paper, so it reads as something handed to you. The only saturated colours in
either are the amber "GO" keys and the teal service tags.

Two rules keep it looking like a material instead of a diagram:

* **Every layer casts a shadow onto the one below it.** Board on world, paper
  on board, slip on paper, clip on paper. Without that the whole thing reads
  flat no matter how good the individual pieces are.
* **Nothing is a two-tone rectangle.** Wood, steel, paper and every key run a
  four or five step ramp, and the flat faces carry grain, fibre or a brushed
  streak.

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
PAPER_XD = (168, 148, 118, 255)
PAPER_D = (206, 188, 156, 255)
PAPER = (238, 224, 198, 255)
PAPER_L = (250, 240, 218, 255)
PAPER_XL = (255, 250, 236, 255)
PAPER_FIBRE = (228, 213, 186, 255)
PAPER_RULE = (216, 202, 176, 255)

# --- enamelled navy steel: the HUD's own material ---
# Dark enough that cream and amber both clear AA on it, and blue enough that it
# never reads as "grey box" over the warm greys of the yard.
HULL_XD = (16, 22, 34, 255)
HULL_D = (28, 37, 54, 255)
HULL = (42, 54, 74, 255)
HULL_L = (68, 86, 112, 255)
HULL_XL = (112, 136, 166, 255)

# --- the dark glass a lit number sits behind ---
GLASS_XD = (8, 11, 18, 255)
GLASS_D = (17, 21, 32, 255)
GLASS = (25, 31, 46, 255)
GLASS_GLOW = (38, 47, 66, 255)

SLATE_XD = (20, 18, 27, 255)
SLATE_D = (34, 30, 44, 255)
SLATE = (52, 46, 66, 255)
SLATE_L = (78, 70, 96, 255)
SLATE_XL = (104, 96, 124, 255)

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
SHADOW_1 = (38, 26, 24, 70)
SHADOW_2 = (38, 26, 24, 36)

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

def gen_board():
    """32x32 nine-patch, margin 12: the clipboard itself.

    Wood back board with grain and steel corner protectors, a sunk well, and
    the manifest paper inside it. Everything decorative lives within 12px of an
    edge; the middle 8x8 is plain fibred paper and tiles.
    """
    s = 32
    img = new_img(s, s)
    # --- wooden back board ---
    rect(img, 0, 0, s, s, WOOD_XD)
    rect(img, 1, 1, s - 2, s - 2, WOOD)
    wood_grain(img, 2, 2, s - 4, s - 4, seed=5)
    bevel(img, 1, 1, s - 2, s - 2, WOOD_L, WOOD_D)
    hline(img, 2, 2, s - 4, WOOD_XL)

    # --- steel corner protectors ---
    for ox, oy, flip_x, flip_y in ((1, 1, 1, 1), (s - 2, 1, -1, 1),
                                   (1, s - 2, 1, -1), (s - 2, s - 2, -1, -1)):
        for i in range(6):
            px(img, ox + flip_x * i, oy, STEEL_D if i > 3 else STEEL)
            px(img, ox, oy + flip_y * i, STEEL_D if i > 3 else STEEL)
        px(img, ox, oy, STEEL_XL)
        px(img, ox + flip_x, oy + flip_y, STEEL_L)
        rivet(img, ox + flip_x * 2, oy + flip_y * 2)

    # --- the well the paper sits in, with its own cast shadow ---
    rect(img, 5, 5, s - 10, s - 10, WOOD_XD)
    rect(img, 6, 6, s - 12, s - 12, PAPER_XD)
    rect(img, 7, 7, s - 14, s - 14, PAPER)
    paper_fibre(img, 8, 8, s - 16, s - 16, seed=17)
    # light falls in from the upper left: the well's top and left edges are in
    # shadow, the opposite pair catches it
    hline(img, 7, 7, s - 14, PAPER_D)
    hline(img, 7, 8, s - 14, PAPER_XD)
    vline(img, 7, 7, s - 14, PAPER_D)
    hline(img, 7, s - 8, s - 14, PAPER_L)
    vline(img, s - 8, 7, s - 14, PAPER_L)
    corner_notch(img, s, s, 2)
    save(img, "ui_board")


def gen_clip():
    """The chrome spring clip. Drawn big enough to read as hardware.

    It straddles the top edge of a board: raised thumb plate with a knurled
    grip, a jaw biting the paper, side springs, and a shadow on the sheet.
    """
    w, h = 72, 22
    img = new_img(w, h)

    # cast shadow first, so the metal sits on top of it
    rect(img, 6, h - 3, w - 12, 2, SHADOW_1)
    rect(img, 9, h - 1, w - 18, 1, SHADOW_2)

    # --- raised thumb plate ---
    plate_x, plate_w = 20, w - 40
    rect(img, plate_x, 0, plate_w, 6, STEEL_XD)
    rect(img, plate_x + 1, 1, plate_w - 2, 4, STEEL)
    hline(img, plate_x + 2, 1, plate_w - 4, STEEL_XL)
    hline(img, plate_x + 1, 4, plate_w - 2, STEEL_D)
    # knurled grip
    for gx in range(plate_x + 3, plate_x + plate_w - 3, 3):
        vline(img, gx, 2, 3, STEEL_L)
        vline(img, gx + 1, 2, 3, STEEL_XD)

    # --- jaw body ---
    rect(img, 2, 5, w - 4, h - 9, STEEL_XD)
    rect(img, 3, 6, w - 6, h - 12, STEEL)
    # brushed streaks along the jaw
    for sy, tone in ((6, STEEL_XL), (7, STEEL_L), (10, STEEL_D), (12, STEEL_D)):
        hline(img, 4, sy, w - 8, tone)
    # the bite line where the paper enters
    hline(img, 3, h - 6, w - 6, STEEL_XD)
    hline(img, 3, h - 5, w - 6, (30, 28, 38, 255))
    hline(img, 3, h - 4, w - 6, STEEL_D)

    # --- side springs and rivets ---
    for sx in (1, w - 3):
        rect(img, sx, 7, 2, h - 13, STEEL_D)
        px(img, sx, 7, STEEL_L)
    for rx in (10, w - 12):
        rivet(img, rx, 8)

    corner_notch(img, w, h, 2)
    save(img, "ui_clip")


def gen_paper():
    """16x16 nine-patch, margin 5: the sheet cards are laid out on.

    A shade darker than a card so a list reads as separate slips rather than
    one block of cream, ruled like a real manifest, and creased along the top
    where the clip holds it down.
    """
    s = 16
    img = new_img(s, s)
    rect(img, 0, 0, s, s, PAPER_XD)
    rect(img, 1, 1, s - 2, s - 2, PAPER_D)
    speckle(img, 1, 1, s - 2, s - 2, [(198, 180, 148, 255), (214, 197, 166, 255)],
            0.14, seed=23)
    # faint rules every four pixels: the centre tiles, so they carry on down
    for ry in range(3, s - 1, 4):
        hline(img, 1, ry, s - 2, PAPER_RULE)
    # the crease under the clip and the lift at the bottom edge
    hline(img, 1, 1, s - 2, (188, 170, 140, 255))
    hline(img, 1, 2, s - 2, (198, 180, 150, 255))
    hline(img, 1, s - 2, s - 2, PAPER)
    save(img, "ui_paper")


def _card(name, field, edge, edge_hi, rail=None, fibre_seed=31):
    """16x16 nine-patch, margin 5: one slip torn off the manifest.

    The right edge is perforated and the whole slip drops a shadow, so a list
    of them reads as loose paper on a sheet instead of a stack of divs.
    """
    s = 16
    img = new_img(s, s)
    # shadow under the slip
    hline(img, 2, s - 1, s - 3, SHADOW_1)
    vline(img, s - 1, 2, s - 3, SHADOW_1)

    rect(img, 0, 0, s - 1, s - 1, edge)
    rect(img, 1, 1, s - 3, s - 3, field)
    speckle(img, 2, 2, s - 5, s - 5, [PAPER_FIBRE, PAPER_XL], 0.10,
            seed=fibre_seed)
    hline(img, 1, 1, s - 3, edge_hi)
    vline(img, 1, 1, s - 3, edge_hi)
    hline(img, 1, s - 3, s - 3, PAPER_D)
    # perforation: the torn side of a slip
    for py in range(2, s - 2, 3):
        px(img, s - 2, py, PAPER_XD)
    if rail is not None:
        # a colour-coded spine, like a file label
        vline(img, 0, 1, s - 3, rail[0])
        vline(img, 1, 1, s - 3, rail[1])
        px(img, 1, 1, rail[2] if len(rail) > 2 else rail[1])
    for cx, cy in ((0, 0), (s - 2, 0), (0, s - 2), (s - 2, s - 2)):
        px(img, cx, cy, (0, 0, 0, 0))
    save(img, name)


def gen_cards():
    _card("ui_card", PAPER, PAPER_XD, PAPER_L, fibre_seed=31)
    _card("ui_card_hi", PAPER_L, AMBER_D, PAPER_XL,
          rail=(AMBER_XD, AMBER, AMBER_L), fibre_seed=37)
    _card("ui_card_off", (200, 190, 176, 255), (156, 146, 136, 255),
          (216, 208, 196, 255), fibre_seed=41)
    _card("ui_card_done", (206, 220, 208, 255), TEAL_D, (230, 242, 232, 255),
          rail=(TEAL_XD, TEAL, TEAL_L), fibre_seed=43)


def gen_slate():
    """14x14 nine-patch, margin 5: the steel plate a number is stamped into.

    Was a flat dark rounded box. It is a bevelled plate now: dark recessed
    face, lit top-left lip, shaded bottom-right, and two screws holding it on.
    """
    def plate(name, border):
        s = 14
        img = new_img(s, s)
        hline(img, 2, s - 1, s - 3, SHADOW_1)
        rect(img, 0, 0, s - 1, s - 1, border)
        rect(img, 1, 1, s - 3, s - 3, SLATE_D)
        # the recess: light catches the far edge, the near edge is in shadow
        hline(img, 1, 1, s - 3, SLATE_XD)
        vline(img, 1, 1, s - 3, SLATE_XD)
        hline(img, 1, s - 3, s - 3, SLATE)
        vline(img, s - 3, 1, s - 3, SLATE)
        hline(img, 2, 3, s - 5, SLATE)
        for sx, sy in ((2, 2), (s - 4, s - 4)):
            px(img, sx, sy, SLATE_XL)
            px(img, sx + 1, sy + 1, SLATE_XD)
        for cx, cy in ((0, 0), (s - 2, 0), (0, s - 2), (s - 2, s - 2)):
            px(img, cx, cy, (0, 0, 0, 0))
        save(img, name)

    plate("ui_slate", SLATE_XD)
    plate("ui_slate_lit", AMBER_D)


def gen_well():
    """14x14 nine-patch, margin 5: the socket an item sprite sits in.

    A hole punched in the paper: hard shadow on the lit side, a bright lip
    opposite, and a slightly cooler floor so the sprite in it pops.
    """
    s = 14
    img = new_img(s, s)
    rect(img, 0, 0, s, s, PAPER_XD)
    rect(img, 1, 1, s - 2, s - 2, (220, 204, 176, 255))
    speckle(img, 2, 2, s - 4, s - 4, [(212, 196, 168, 255)], 0.12, seed=53)
    # inset: the top-left of a hole is the dark side
    hline(img, 1, 1, s - 2, (160, 140, 112, 255))
    hline(img, 1, 2, s - 2, (186, 168, 138, 255))
    vline(img, 1, 1, s - 2, (168, 148, 120, 255))
    hline(img, 1, s - 2, s - 2, PAPER_XL)
    vline(img, s - 2, 1, s - 2, PAPER_L)
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
    rect(card, 1, 1, s - 3, s - 3, PAPER_L)
    speckle(card, 2, 2, s - 5, s - 5, [PAPER_XL, PAPER_FIBRE], 0.10, seed=71)
    hline(card, 1, 1, s - 3, PAPER_XL)
    vline(card, 1, 1, s - 3, PAPER_XL)
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
    rect(photo, 1, 1, s - 2, s - 2, PAPER_XL)
    rect(photo, 3, 3, s - 6, s - 6, (58, 62, 78, 255))
    hline(photo, 1, 1, s - 2, (152, 132, 104, 255))
    vline(photo, 1, 1, s - 2, (152, 132, 104, 255))
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
    """16x16 nine-patch, margin 5: a chunky physical key.

    Five tones and a cast shadow. The old two-tone version read as a coloured
    rectangle; this one has a lit top face, a shaded skirt and a shadow, so it
    looks like something that can be pressed.
    """
    s = 16
    img = new_img(s, s)
    hline(img, 2, s - 1, s - 3, SHADOW_1)
    vline(img, s - 1, 2, s - 3, SHADOW_1)

    rect(img, 0, 0, s - 1, s - 1, xdark)
    rect(img, 1, 1, s - 3, s - 3, base)
    hline(img, 2, 1, s - 5, xlight)
    hline(img, 1, 2, s - 3, light)
    vline(img, 1, 2, s - 5, light)
    hline(img, 1, s - 4, s - 3, dark)
    hline(img, 1, s - 3, s - 3, xdark)
    vline(img, s - 3, 2, s - 5, dark)
    for cx, cy in ((0, 0), (s - 2, 0), (0, s - 2), (s - 2, s - 2)):
        px(img, cx, cy, (0, 0, 0, 0))
    save(img, name)


def gen_buttons():
    _button(AMBER, AMBER_L, AMBER_XL, AMBER_D, AMBER_XD, "ui_btn")
    # pressed: the key sinks, so light and shade swap
    _button(AMBER_D, AMBER, AMBER_L, AMBER_XD, AMBER_XD, "ui_btn_down")
    _button(TEAL, TEAL_L, TEAL_XL, TEAL_D, TEAL_XD, "ui_btn_alt")
    _button((178, 168, 156, 255), (204, 196, 186, 255), (224, 218, 210, 255),
            (138, 128, 118, 255), (104, 96, 88, 255), "ui_btn_off")
    _button(RUST, RUST_L, (222, 140, 116, 255), RUST_D, RUST_XD, "ui_btn_danger")
    _button(PAPER, PAPER_L, PAPER_XL, PAPER_D, PAPER_XD, "ui_btn_ghost")
    # The console keys. Paper keys on a steel console read as sticky notes; these
    # are the same enamel as the panel they are bolted to, one step lighter so
    # they still stand off it.
    _button(HULL, HULL_L, HULL_XL, HULL_D, HULL_XD, "ui_btn_steel")
    _button(HULL_D, HULL, HULL_L, HULL_XD, HULL_XD, "ui_btn_steel_down")


def gen_tabs():
    """16x16 nine-patch, margin 5: file-folder tabs sitting on the board."""
    s = 16
    # active: continuous with the sheet below, so the bottom edge is open
    on = new_img(s, s)
    rect(on, 0, 0, s, s - 1, PAPER_XD)
    rect(on, 1, 0, s - 2, s - 1, PAPER)
    speckle(on, 2, 2, s - 4, s - 4, [PAPER_FIBRE], 0.10, seed=61)
    hline(on, 2, 0, s - 4, PAPER_XL)
    hline(on, 1, 1, s - 2, PAPER_L)
    vline(on, 1, 1, s - 2, PAPER_L)
    vline(on, s - 2, 1, s - 2, PAPER_D)
    hline(on, 1, s - 1, s - 2, PAPER)
    for cx in (0, s - 1):
        px(on, cx, 0, (0, 0, 0, 0))
    save(on, "ui_tab_on")

    # inactive: pushed back into the board's shadow, with a fold at the base
    off = new_img(s, s)
    rect(off, 0, 1, s, s - 1, WOOD_XD)
    rect(off, 1, 2, s - 2, s - 3, (196, 178, 150, 255))
    speckle(off, 2, 3, s - 4, s - 5, [(184, 166, 138, 255)], 0.12, seed=67)
    hline(off, 2, 2, s - 4, (214, 198, 172, 255))
    hline(off, 1, s - 2, s - 2, (168, 150, 124, 255))
    hline(off, 1, s - 1, s - 2, WOOD_XD)
    for cx in (0, s - 1):
        px(off, cx, 1, (0, 0, 0, 0))
    save(off, "ui_tab_off")


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
    rect(off, 0, 0, 10, 9, PAPER_XD)
    rect(off, 1, 1, 8, 7, (226, 212, 186, 255))
    hline(off, 1, 1, 8, PAPER_XL)
    hline(off, 1, 7, 8, PAPER_D)
    save(off, "ui_seg_off")


def gen_focus():
    """12x12 nine-patch, margin 4: the keyboard focus ring, hollow centre.

    Two tones on purpose. A single-colour ring cannot be visible on both the
    cream paper of a board and the near-black steel of a readout, so the outer
    pixel is ink and the inner one is cream: whichever it lands on, one reads.
    """
    s = 12
    img = new_img(s, s)
    rect(img, 0, 0, s, s, INK)
    rect(img, 1, 1, s - 2, s - 2, PAPER_XL)
    rect(img, 2, 2, s - 4, s - 4, (0, 0, 0, 0))
    save(img, "ui_focus")


def gen_bar():
    """10x10 nine-patch, margin 4: a progress trough cut into the paper."""
    bg = new_img(10, 10)
    rect(bg, 0, 0, 10, 10, PAPER_XD)
    rect(bg, 1, 1, 8, 8, (200, 184, 154, 255))
    hline(bg, 1, 1, 8, (172, 154, 126, 255))
    hline(bg, 1, 8, 8, PAPER_L)
    save(bg, "ui_bar_bg")

    fill = new_img(10, 10)
    rect(fill, 0, 0, 10, 10, TEAL_XD)
    rect(fill, 1, 1, 8, 8, TEAL)
    hline(fill, 1, 1, 8, TEAL_L)
    hline(fill, 1, 2, 8, TEAL_XL)
    hline(fill, 1, 8, 8, TEAL_D)
    save(fill, "ui_bar_fill")


def gen_scroll():
    """10x10 nine-patches, margin 4: a sunk channel and a wooden grip."""
    bg = new_img(10, 10)
    rect(bg, 0, 0, 10, 10, (0, 0, 0, 0))
    rect(bg, 3, 0, 4, 10, (186, 168, 140, 255))
    vline(bg, 3, 0, 10, (160, 142, 116, 255))
    vline(bg, 6, 0, 10, PAPER_L)
    save(bg, "ui_scroll_bg")

    grab = new_img(10, 10)
    rect(grab, 0, 0, 10, 10, (0, 0, 0, 0))
    rect(grab, 2, 0, 6, 10, WOOD_XD)
    rect(grab, 3, 1, 4, 8, WOOD)
    vline(grab, 3, 1, 8, WOOD_L)
    vline(grab, 6, 1, 8, WOOD_D)
    hline(grab, 3, 1, 4, WOOD_XL)
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

    # crane: gantry silhouette
    i = _icon_base()
    hline(i, 1, 2, 10, (200, 92, 78, 255))
    hline(i, 1, 3, 10, (150, 60, 58, 255))
    vline(i, 2, 3, 8, (200, 92, 78, 255))
    vline(i, 9, 3, 8, (200, 92, 78, 255))
    vline(i, 6, 4, 3, (130, 126, 138, 255))
    rect(i, 5, 7, 3, 2, (238, 176, 62, 255))
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
    rect(i, 3, 8, 6, 2, (226, 218, 202, 255))
    hline(i, 3, 9, 6, (168, 162, 150, 255))
    icons["ship"] = i

    # land: a fenced plot
    i = _icon_base()
    rect(i, 1, 3, 10, 7, (152, 114, 76, 255))
    speckle(i, 2, 4, 8, 5, [(122, 88, 58, 255)], 0.3, seed=2)
    for x in range(1, 12, 3):
        vline(i, x, 2, 3, (226, 218, 202, 255))
    hline(i, 1, 3, 10, (226, 218, 202, 255))
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

    # cat paw: the boost
    i = _icon_base()
    rect(i, 3, 6, 6, 4, (196, 148, 96, 255))
    for cx in (2, 4, 6, 8):
        rect(i, cx, 3, 2, 2, (196, 148, 96, 255))
    icons["paw"] = i

    # glove: the click upgrades
    i = _icon_base()
    _blit_rows(i, ["..##.##.", ".#######", "#.######", "#.######",
                   ".#######", ".######.", "..####..", "..####.."], 2, 2,
               (232, 150, 60, 255))
    _blit_rows(i, ["..##.##.", ".......", ".......", "......."], 2, 2,
               (252, 194, 112, 255))
    icons["glove"] = i

    # globe: the terminal-wide upgrades
    i = _icon_base()
    for y in range(12):
        for x in range(12):
            dist = ((x - 5.5) ** 2 + (y - 5.5) ** 2) ** 0.5
            if dist <= 4.7:
                px(i, x, y, (86, 158, 168, 255))
            if 3.7 < dist <= 4.7:
                px(i, x, y, (44, 104, 118, 255))
    hline(i, 2, 5, 8, (176, 220, 214, 255))
    vline(i, 5, 2, 8, (176, 220, 214, 255))
    icons["globe"] = i

    # padlock: not unlocked yet
    i = _icon_base()
    _blit_rows(i, [".####.", "#....#", "#....#"], 3, 1, (150, 140, 132, 255))
    rect(i, 2, 5, 8, 6, (176, 166, 154, 255))
    hline(i, 2, 5, 8, (204, 196, 186, 255))
    rect(i, 5, 7, 2, 3, (96, 88, 84, 255))
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

    # truck: the gate traffic / contracts
    i = _icon_base()
    rect(i, 1, 4, 6, 4, (72, 116, 172, 255))
    hline(i, 1, 4, 6, (110, 154, 206, 255))
    rect(i, 7, 5, 3, 3, (196, 190, 190, 255))
    for wx in (2, 8):
        rect(i, wx, 8, 2, 2, (48, 44, 50, 255))
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
    i = _icon_base()
    px(i, 5, 0, AMBER_D)                       # the loop it hangs from
    px(i, 6, 0, AMBER_D)
    for row, half in ((1, 1), (2, 2), (3, 3), (4, 3), (5, 4), (6, 4), (7, 5)):
        rect(i, 6 - half, row, half * 2, 1, AMBER)
        px(i, 6 - half, row, AMBER_L)          # lit edge, light from upper left
        px(i, 5 + half, row, AMBER_D)
    hline(i, 1, 8, 10, AMBER_D)                # the rim, wider than the body
    hline(i, 1, 9, 10, AMBER_XD)
    rect(i, 5, 10, 2, 2, AMBER_D)              # the clapper, swung clear
    px(i, 4, 2, AMBER_XL)
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

    # crew: the community key. Two figures, the near one overlapping the far one.
    # Three at 12px is a smudge; two with a gap between them reads as people.
    i = _icon_base()
    for cx, top, tone in ((8, 1, (168, 160, 174, 255)),
                          (4, 3, (236, 228, 212, 255))):
        rect(i, cx - 2, top, 5, 4, (58, 42, 52, 255))       # head
        rect(i, cx - 1, top + 1, 3, 2, tone)
        rect(i, cx - 3, top + 4, 7, 8, (58, 42, 52, 255))   # shoulders
        rect(i, cx - 2, top + 5, 5, 7, tone)
    icons["crew"] = i

    order = ["teu", "crane", "ship", "land", "star", "gear", "sound", "clock",
             "paw", "glove", "globe", "lock", "check", "close", "chevron",
             "truck", "trophy", "bell", "chat", "crew"]
    save(sheet([icons[k] for k in order]), "ui_icons")
    print("    icon order:", ", ".join(order))


if __name__ == "__main__":
    print("ui:")
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
    gen_indicators()
    gen_buttons()
    gen_tabs()
    gen_segments()
    gen_focus()
    gen_bar()
    gen_scroll()
    gen_desk_props()
    gen_scrims()
    gen_icons()
