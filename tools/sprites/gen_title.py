"""Generates the title screen's harbour backdrop.

The first version was a dusk *panorama* — sky, sun, a city skyline, water on the
horizon. It was a nice painting of somewhere else. The game is a top-down
terminal, and every screen after this one looks straight down at it, so the title
now looks at the same thing from the same angle: this is the port you are about
to run, at night, already working.

Painted at 320x720 rather than the old 160x240. The design viewport is 320 wide,
so this is 1:1 horizontally — no nearest-neighbour doubling to hide detail behind.
The height matters as much: the backdrop is drawn COVERED, so a source shorter
than the tallest phone gets scaled *up* to fill it and the sides are cropped off
— which is how the ship ended up half out of frame. At 720 the tallest common
viewport is covered without scaling at all, and the crop is vertical, where the
composition can afford it. Anything that must survive lives in the middle band.
"""
import palette as P
from common import hline, new_img, px, rect, save, speckle, vline

W, H = 320, 720

NIGHT = 0.66  # everything is multiplied down to this, then the lights go on top


def dim(color, k=NIGHT):
    """Dusk in one place. Painting each colour dark by hand drifts; multiplying
    the shared palette keeps the title made of the same pigments as the yard."""
    a = color[3] if len(color) > 3 else 255
    return (int(color[0] * k), int(color[1] * k), int(color[2] * k), a)


def _container(img, x, y, pair, w=13, h=6):
    top, side = pair
    rect(img, x, y, w, h, dim(P.OUTLINE))
    rect(img, x + 1, y + 1, w - 2, h - 3, dim(top))
    hline(img, x + 1, y + h - 2, w - 2, dim(side))
    for rib in range(x + 3, x + w - 2, 3):
        vline(img, rib, y + 1, h - 3, dim(side))


def _stack(img, x, y, pair, levels=1):
    """A pile, drawn top box last so the lower ones peek out below it."""
    for level in range(levels):
        _container(img, x, y - level * 3, pair)


def _shed(img, x, y, w, h, lit_rows=2):
    rect(img, x, y, w, h, dim(P.OUTLINE))
    rect(img, x + 1, y + 1, w - 2, h - 2, dim((150, 78, 66, 255)))
    rect(img, x + 2, y + 2, w - 4, 2, dim((178, 96, 80, 255)))
    for rib in range(x + 4, x + w - 3, 6):
        vline(img, rib, y + 2, h - 4, dim((124, 62, 54, 255)))
    # Lit skylights: the only warm thing on the land side.
    for row in range(lit_rows):
        for lx in range(x + 3, x + w - 4, 7):
            rect(img, lx, y + 5 + row * 6, 4, 3, (236, 196, 118, 255))


def _rtg(img, x, y, span):
    """A transtainer straddling a block: two legs, a beam and a trolley."""
    rect(img, x, y, 4, 26, dim(P.TEAL_D))
    rect(img, x + span - 4, y, 4, 26, dim(P.TEAL_D))
    rect(img, x + 1, y + 1, 2, 24, dim(P.TEAL))
    rect(img, x + span - 3, y + 1, 2, 24, dim(P.TEAL))
    rect(img, x - 1, y, span + 2, 5, dim(P.OUTLINE))
    rect(img, x, y + 1, span, 3, dim(P.TEAL))
    hline(img, x, y + 1, span, dim(P.TEAL_L))
    rect(img, x + span // 2 - 3, y + 1, 6, 6, dim(P.OUTLINE))
    rect(img, x + span // 2 - 2, y + 2, 4, 4, dim(P.SAFETY))


def _sts(img, x, y):
    """A ship-to-shore gantry: legs on the quay, boom out over the water."""
    rect(img, x, y, 5, 30, dim(P.OUTLINE))
    rect(img, x + 1, y + 1, 3, 28, dim(P.CRANE_D))
    rect(img, x + 20, y, 5, 30, dim(P.OUTLINE))
    rect(img, x + 21, y + 1, 3, 28, dim(P.CRANE_D))
    rect(img, x + 2, y + 6, 22, 14, dim(P.OUTLINE))
    rect(img, x + 3, y + 7, 20, 12, dim(P.CRANE))
    rect(img, x + 5, y + 9, 5, 4, (240, 206, 128, 255))
    rect(img, x + 14, y + 9, 5, 4, (240, 206, 128, 255))
    # The boom runs out over the hold and stops there — a boom that oversails the
    # far side of the ship reads as a girder lying across it.
    rect(img, x + 24, y + 10, 62, 5, dim(P.OUTLINE))
    rect(img, x + 25, y + 11, 60, 3, dim(P.CRANE))
    hline(img, x + 25, y + 11, 60, dim(P.CRANE_L))
    # Trolley, wire and a box on the spreader, which is what the boom is *for*.
    rect(img, x + 60, y + 8, 8, 8, dim(P.OUTLINE))
    rect(img, x + 61, y + 9, 6, 6, dim(P.CRANE_L))
    vline(img, x + 64, y + 16, 10, dim(P.STEEL_L))
    rect(img, x + 57, y + 26, 15, 4, dim(P.OUTLINE))
    rect(img, x + 58, y + 27, 13, 2, dim(P.SAFETY))
    _container(img, x + 58, y + 30, P.CONTAINERS["rust"], w=13, h=6)


def _person(img, x, y):
    px(img, x, y, dim(P.HELMET))
    rect(img, x - 1, y + 1, 3, 3, dim(P.VEST))
    px(img, x - 1, y + 4, dim(P.PANTS))
    px(img, x + 1, y + 4, dim(P.PANTS))


def _forklift(img, x, y):
    rect(img, x, y, 7, 9, dim(P.OUTLINE))
    rect(img, x + 1, y + 1, 5, 7, dim(P.SAFETY))
    rect(img, x + 2, y + 2, 3, 3, dim(P.SAFETY_D))
    vline(img, x + 1, y - 3, 3, dim(P.STEEL_D))
    vline(img, x + 5, y - 3, 3, dim(P.STEEL_D))


def _truck(img, x, y):
    rect(img, x, y, 9, 8, dim(P.OUTLINE))
    rect(img, x + 1, y + 1, 7, 6, dim(P.HULL_L))
    rect(img, x, y + 9, 9, 16, dim(P.OUTLINE))
    rect(img, x + 1, y + 10, 7, 14, dim(P.STEEL))
    px(img, x + 2, y, (246, 232, 190, 255))
    px(img, x + 6, y, (246, 232, 190, 255))


def _lamp(img, x, y):
    """A mast and the pool it throws. The pools are what make it read as night
    rather than as a daylight painting somebody turned the brightness down on."""
    for radius, alpha in ((13, 24), (9, 36), (5, 56)):
        for oy in range(-radius, radius + 1):
            span = int((radius * radius - oy * oy) ** 0.5)
            for ox in range(-span, span + 1):
                cx, cy = x + ox, y + oy + 4
                if 0 <= cx < W and 0 <= cy < H:
                    base = img.getpixel((cx, cy))
                    img.putpixel((cx, cy), (
                        min(255, base[0] + alpha),
                        min(255, base[1] + int(alpha * 0.86)),
                        min(255, base[2] + int(alpha * 0.52)), 255))
    rect(img, x - 1, y - 6, 3, 8, dim(P.STEEL_D))
    rect(img, x - 2, y - 8, 5, 3, dim(P.OUTLINE))
    rect(img, x - 1, y - 7, 3, 1, (250, 224, 150, 255))


NAVY = (32, 44, 68, 255)
NAVY_D = (20, 28, 46, 255)
NAVY_L = (56, 74, 106, 255)
AMBER = (250, 196, 92, 255)
AMBER_D = (186, 130, 44, 255)
AMBER_L = (254, 226, 158, 255)
EDGE = (12, 16, 28, 255)


def _bevel_panel(img, x, y, w, h, face, light, dark, edge=EDGE):
    """A slab with a lit top-left and a shaded bottom-right. Every plate on the
    title is built from this so the whole screen is lit from one direction."""
    rect(img, x, y, w, h, edge)
    rect(img, x + 1, y + 1, w - 2, h - 2, face)
    hline(img, x + 2, y + 1, w - 4, light)
    vline(img, x + 1, y + 2, h - 4, light)
    hline(img, x + 2, y + h - 2, w - 4, dark)
    vline(img, x + w - 2, y + 2, h - 4, dark)


def gen_title_plate():
    """The board the wordmark is bolted to, as a nine-patch.

    Nine-patch, so the plate fits whatever the title string measures rather than
    the string being sized to fit a picture. The middle is flat on purpose — a
    stretched middle with texture in it becomes a smear on a wide panel.
    """
    w, h = 24, 26
    img = new_img(w, h)
    _bevel_panel(img, 0, 0, w, h, NAVY, NAVY_L, NAVY_D)
    # Amber hairline along the bottom lip, the same accent the gantry wears.
    hline(img, 2, h - 3, w - 4, AMBER_D)
    # Rivets in the corners: four dots is all it takes to read as bolted down.
    for rx, ry in ((4, 4), (w - 5, 4), (4, h - 6), (w - 5, h - 6)):
        px(img, rx, ry, NAVY_D)
        px(img, rx, ry - 1, NAVY_L)
    save(img, "ui_title_plate", preview_scale=4)


def gen_title_ribbon():
    """The motto banner under the plate, also a nine-patch."""
    w, h = 18, 14
    img = new_img(w, h)
    _bevel_panel(img, 0, 0, w, h, (46, 38, 34, 255), (68, 58, 50, 255),
                 (30, 24, 22, 255))
    hline(img, 1, 1, w - 2, AMBER_D)
    hline(img, 1, h - 2, w - 2, AMBER_D)
    save(img, "ui_title_ribbon", preview_scale=4)


def gen_title_anchor():
    """The mark. It sits astride the top edge of the plate, so it has to read at
    26px with no outline help from the plate behind it."""
    w, h = 28, 30
    img = new_img(w, h)
    c, cl, cd = AMBER, AMBER_L, AMBER_D
    mid = 13
    # Ring
    for oy in range(0, 8):
        for ox in range(-5, 6):
            d2 = ox * ox + (oy - 4) * (oy - 4) * 1.4
            if 9 <= d2 <= 26:
                px(img, mid + ox, 1 + oy, c)
    rect(img, mid - 1, 1, 3, 2, cl)
    # Shank
    rect(img, mid - 1, 8, 3, 16, c)
    vline(img, mid - 1, 8, 16, cl)
    vline(img, mid + 1, 8, 16, cd)
    # Stock
    rect(img, mid - 7, 11, 15, 3, c)
    hline(img, mid - 7, 11, 15, cl)
    hline(img, mid - 7, 13, 15, cd)
    # Arms, curving up into flukes
    for step, (dx, dy) in enumerate(((0, 0), (1, 1), (2, 2), (3, 2), (4, 1))):
        rect(img, mid - 6 - dx, 23 - dy, 3, 3, c)
        rect(img, mid + 4 + dx, 23 - dy, 3, 3, c)
    for side in (-1, 1):
        tip = mid + side * 10
        rect(img, tip - 1, 18, 3, 5, c)
        px(img, tip - 1 if side < 0 else tip + 1, 17, cl)
    save(img, "ui_title_anchor", preview_scale=4)


def gen_title_port():
    img = new_img(W, H)
    colors = list(P.CONTAINERS.values())

    # ---------------------------------------------------------------- ground
    rect(img, 0, 0, W, H, dim(P.YARD_D))
    speckle(img, 0, 0, W, H, [dim(P.YARD), dim(P.YARD_PATCH), dim(P.YARD_L)],
            0.06, seed=90210)

    # Green edge on the landward side, where the city would be.
    rect(img, 0, 0, 34, H, dim(P.GRASS_D))
    speckle(img, 0, 0, 34, H, [dim(P.GRASS), dim(P.GRASS_L)], 0.10, seed=7)
    for ty in range(14, H, 46):
        rect(img, 6, ty, 12, 12, dim(P.GRASS_D))
        rect(img, 7, ty + 1, 10, 10, dim(P.GRASS))
        rect(img, 9, ty + 3, 6, 5, dim(P.GRASS_L))

    # ----------------------------------------------------------------- water
    water_x = 236
    rect(img, water_x, 0, W - water_x, H, dim(P.SEA_DEEP))
    for y in range(0, H, 7):
        hline(img, water_x + 4 + (y % 11), y, 26 + (y % 23), dim(P.SEA))
        hline(img, water_x + 30 - (y % 9), y + 3, 18 + (y % 13), dim(P.SEA_LIGHT))
    # The quay wall, and the fender line down its face.
    rect(img, water_x - 16, 0, 16, H, dim(P.QUAY_D))
    vline(img, water_x - 16, 0, H, dim(P.OUTLINE))
    vline(img, water_x - 14, 0, H, dim(P.QUAY_L))
    vline(img, water_x - 2, 0, H, dim(P.PAINT_Y))
    for by in range(10, H, 34):
        rect(img, water_x - 8, by, 5, 6, dim(P.OUTLINE))
        rect(img, water_x - 7, by + 1, 3, 4, dim(P.STEEL))

    # ------------------------------------------------------------- the roads
    # A spine down the terminal and two cross roads, all with real markings: an
    # empty slab of grey reads as unfinished, a marked one reads as a place where
    # things get routed.
    rect(img, 36, 0, 22, H, dim((88, 82, 86, 255)))
    for y in range(4, H, 14):
        rect(img, 46, y, 2, 7, dim(P.PAINT_W))
    for road_y in (150, 372, 596):
        rect(img, 36, road_y, W - 36 - 84, 18, dim((88, 82, 86, 255)))
        for x in range(42, W - 90, 14):
            rect(img, x, road_y + 8, 7, 2, dim(P.PAINT_W))

    # ------------------------------------------------------------- the sheds
    _shed(img, 62, 16, 74, 40)
    _shed(img, 144, 16, 62, 40, lit_rows=1)
    _shed(img, 62, 470, 84, 46)
    _shed(img, 156, 470, 56, 46, lit_rows=1)
    _shed(img, 62, 630, 66, 44)
    _shed(img, 138, 630, 74, 44, lit_rows=1)

    # ------------------------------------------------------------ yard blocks
    # Three blocks of stacked boxes with lanes between them, which is the
    # terminal's actual geometry rather than a decorative grid.
    for block, block_y in enumerate((176, 250, 396, 528)):
        for row in range(4):
            y = block_y + row * 15
            for col in range(9):
                x = 66 + col * 15
                if (row * 5 + col * 3 + block) % 9 == 0:
                    continue
                levels = 1 + ((row + col + block) % 3)
                _stack(img, x, y, colors[(row * 2 + col + block * 3)
                                         % len(colors)], levels)
        # Painted bay stripes at the head of the block.
        for col in range(10):
            vline(img, 64 + col * 15, block_y - 6, 4, dim(P.PAINT_Y))

    _rtg(img, 60, 168, 148)
    _rtg(img, 60, 388, 148)
    _rtg(img, 60, 520, 148)

    # -------------------------------------------------------------- the ship
    # Bow up, like every hull in the game: this is the same vessel the player is
    # about to tap, alongside, being worked.
    sx, sy, sw, sh = 246, 96, 64, 292
    # A real taper rather than a lid: the beam comes in a step at a time from the
    # stem, which is the only thing that says which end is the front.
    for step, inset in enumerate((26, 21, 17, 13, 10, 7, 5, 3, 2, 1)):
        y = sy - 26 + step * 3
        rect(img, sx + inset, y, sw - inset * 2, 4, dim(P.OUTLINE))
        rect(img, sx + inset + 1, y + 1, sw - inset * 2 - 2, 3, dim(P.HULL_D))
    rect(img, sx, sy, sw, sh, dim(P.OUTLINE))
    rect(img, sx + 2, sy + 2, sw - 4, sh - 4, dim(P.HULL_D))
    rect(img, sx + 4, sy + 4, sw - 8, sh - 8, dim(P.HULL))
    # Sheer strake down both sides, so the hull is not one flat slab of blue.
    vline(img, sx + 4, sy + 4, sh - 8, dim(P.HULL_L))
    vline(img, sx + sw - 5, sy + 4, sh - 8, dim(P.HULL_L))
    # Forecastle: windlass, bitts and the bow mast.
    rect(img, sx + 20, sy - 2, 24, 20, dim(P.DECK_D))
    rect(img, sx + 22, sy + 2, 20, 5, dim(P.STEEL_D))
    rect(img, sx + 26, sy + 10, 4, 4, dim(P.STEEL))
    rect(img, sx + 34, sy + 10, 4, 4, dim(P.STEEL))
    vline(img, sx + 31, sy - 14, 12, dim(P.STEEL_L))
    # Hatch coamings and the deck cargo in two rows, as on the real sprite.
    rect(img, sx + 6, sy + 26, sw - 12, sh - 66, dim(P.DECK_D))
    for row, y in enumerate(range(sy + 30, sy + sh - 52, 14)):
        for col, x in enumerate((sx + 8, sx + 36)):
            _container(img, x, y, colors[(row * 3 + col) % len(colors)],
                       w=22, h=11)
    # Accommodation block and funnel, aft.
    rect(img, sx + 8, sy + sh - 48, sw - 16, 34, dim(P.OUTLINE))
    rect(img, sx + 9, sy + sh - 47, sw - 18, 32, dim(P.SUPER_W_D))
    rect(img, sx + 11, sy + sh - 45, sw - 22, 12, dim(P.SUPER_W))
    for wx in range(sx + 13, sx + sw - 14, 7):
        rect(img, wx, sy + sh - 43, 4, 4, (246, 214, 140, 255))
        rect(img, wx, sy + sh - 30, 4, 3, (232, 196, 124, 255))
    rect(img, sx + 26, sy + sh - 22, 12, 12, dim(P.OUTLINE))
    rect(img, sx + 27, sy + sh - 21, 10, 10, dim(P.CRANE_D))
    # Navigation lights: red to port, green to starboard, white at the masthead.
    px(img, sx + 1, sy + 6, (246, 76, 62, 255))
    px(img, sx + sw - 2, sy + 6, (108, 236, 128, 255))
    px(img, sx + 31, sy - 12, (240, 248, 236, 255))
    # Wash where the hull meets the water. Irregular on purpose: evenly spaced
    # marks down a hull read as a ladder bolted to the plating, not as water.
    for y in range(sy - 10, sy + sh + 8):
        h = (y * 2654435761) & 0xFFFF
        if h % 7 == 0:
            hline(img, sx + sw, y, 1 + h % 4, dim(P.FOAM, 0.55 + (h % 5) * 0.09))
        if h % 11 == 3:
            hline(img, sx - 1 - h % 3, y, 1 + h % 3, dim(P.FOAM, 0.42))

    # ------------------------------------------------------------ small life
    for x, y in ((92, 138), (128, 344), (188, 232), (74, 452), (206, 128),
                 (110, 610), (176, 690)):
        _person(img, x, y)
    for x, y in ((40, 210), (44, 330), (196, 300), (196, 560)):
        _forklift(img, x, y)
    _truck(img, 40, 96)
    _truck(img, 42, 424)
    _truck(img, 40, 640)
    # Channel marks, offset from the hull so they read as marks and not litter.
    for y in (60, 214, 368, 500, 640):
        rect(img, W - 12, y, 5, 7, dim(P.OUTLINE))
        rect(img, W - 11, y + 1, 3, 5, dim(P.CRANE))
        px(img, W - 10, y - 1, (250, 150, 90, 255))

    # ------------------------------------------------------ the quay gantries
    # Drawn after the ship: their booms reach out over it and must sit on top.
    _sts(img, 206, 130)
    _sts(img, 206, 300)
    _sts(img, 206, 470)

    # ------------------------------------------------------------ lamp masts
    # Last of all, because a light falls *on* the terminal.
    for x, y in ((58, 92), (58, 300), (58, 500), (58, 664), (150, 148),
                 (150, 370), (150, 594), (222, 60), (222, 460), (222, 660)):
        _lamp(img, x, y)

    save(img, "ui_title_port", preview_scale=2)


if __name__ == "__main__":
    gen_title_port()
    gen_title_plate()
    gen_title_ribbon()
    gen_title_anchor()
