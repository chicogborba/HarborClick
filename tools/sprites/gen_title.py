"""Generates the title screen's harbour backdrop and its furniture.

The first version was a dusk *panorama* — sky, sun, a city skyline, water on the
horizon. It was a nice painting of somewhere else. The game is a top-down
terminal, and every screen after this one looks straight down at it, so the title
looks at the same thing from the same angle: this is the port you are about to
run, already working.

The second version drew that port again, from scratch, out of rectangles: its own
containers, its own sheds, its own cranes, at night. It was consistent with
nothing. The terminal the player opens two taps later is tiled ground with kerbs
and bay paint on it, and machines the game already has art for — so this one is
built out of *those*, tile for tile and sprite for sprite. The only thing here
that is not a game sprite is the ship, which is the one drawing worth generating
(`tools/sprites/pixellab`), and the light, which is late afternoon rather than
the yard's noon.

Painted at 320x720. The design viewport is 320 wide, so this is 1:1 horizontally
— no nearest-neighbour doubling to hide detail behind. The height matters as
much: the backdrop is drawn COVERED, so a 2:3 phone shows a 320x480 window into
it. Anything that must survive lives in the middle band, roughly y 120..600.
"""
import os
import random

import gen_font
import palette as P
from common import SPRITES_DIR, hline, new_img, px, rect, save, vline
from PIL import Image

W, H = 320, 720

# ---------------------------------------------------------------- the zoning
# Read left to right, the way the picture is: grass, the road in from the city,
# the yard, the apron, the water. These are the only numbers the composition
# agrees on, so everything else is derived from them.
GRASS_X1 = 30
ROAD_X0, ROAD_X1 = 30, 54
YARD_X0, YARD_X1 = 56, 210
QUAY_X0, QUAY_X1 = 210, 236
WATER_X0 = 236

## Bay grid: three rows of boxes across, five bays down, which is what fills the
## visible band without turning into wallpaper.
BAY_XS = (62, 112, 162)
BAY_YS = (96, 214, 332, 450, 568)
BAY_W, BAY_H = 48, 78
BOX_W, BOX_H = 24, 13

## Late afternoon. Not a night filter — the yard the player is about to open is
## bright, and a title three stops darker than the game is a different game.
WARM = (1.03, 0.99, 0.92)
SHADE = 0.92

_rng = random.Random(20260806)


# --------------------------------------------------------------- ingredients

def sprite(name: str) -> Image.Image:
    """A PNG another generator wrote, as an ingredient here.

    The berth is the one place a loop was the wrong instrument, so the ship is a
    painting `gen_pixellab.py` harmonises; everything else is the yard's own
    art. Alphabetical order in `generate_all.sh` puts `pixellab` before `title`,
    which is the whole reason that ordering is worth keeping."""
    path = os.path.join(SPRITES_DIR, name + ".png")
    if not os.path.exists(path):
        raise SystemExit(f"{name}.png is missing — run the other generators first.")
    return Image.open(path).convert("RGBA")


def tint(art: Image.Image, k=1.0, warm=WARM, alpha=1.0) -> Image.Image:
    """One light for the whole picture. Every sprite pasted in goes through it,
    so a machine borrowed from the yard cannot arrive lit differently from the
    ground it is standing on."""
    out = art.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            pixels[x, y] = (
                min(255, int(r * k * warm[0])),
                min(255, int(g * k * warm[1])),
                min(255, int(b * k * warm[2])),
                a if alpha >= 1.0 else int(a * alpha))
    return out


def paste(img, name, x, y, k=SHADE, center=False, flip=False, shadow=False):
    """Drop a sprite in. `center` matches how the world places it (Sprite2D is
    centred), so a position copied out of the game lands in the same place."""
    art = sprite(name)
    if flip:
        art = art.transpose(Image.FLIP_LEFT_RIGHT)
    art = tint(art, k)
    if center:
        x -= art.width // 2
        y -= art.height // 2
    if shadow:
        _contact_shadow(img, x, y, art)
    img.alpha_composite(art, (int(x), int(y)))
    return art.size


def _contact_shadow(img, x, y, art):
    """A soft dark oval under a machine. Without one every vehicle in the yard
    looks like a sticker lying on the concrete."""
    w, h = art.size
    for oy in range(h // 3):
        for ox in range(w):
            cx, cy = int(x + ox + 1), int(y + h - h // 3 + oy + 1)
            if not (0 <= cx < W and 0 <= cy < H):
                continue
            edge = min(ox, w - 1 - ox, oy, h // 3 - 1 - oy)
            if edge < 1:
                continue
            base = img.getpixel((cx, cy))
            img.putpixel((cx, cy), (int(base[0] * 0.72), int(base[1] * 0.72),
                                    int(base[2] * 0.76), 255))


def tile(img, name, x0, y0, x1, y1, variants=None):
    """Fill a rect with a ground tile, exactly the way `GroundBaker` fills the
    real yard — including picking a variant per cell, which is what stops a
    hundred square metres of asphalt reading as one flat colour."""
    tiles = [tint(sprite(n), SHADE) for n in (variants or [name])]
    step = tiles[0].width
    for ty in range(y0, y1, step):
        for tx in range(x0, x1, step):
            art = tiles[_rng.randrange(len(tiles))]
            box = (max(0, x0 - tx), max(0, y0 - ty),
                   min(art.width, x1 - tx), min(art.height, y1 - ty))
            if box[2] <= box[0] or box[3] <= box[1]:
                continue
            img.alpha_composite(art.crop(box), (tx + box[0], ty + box[1]))


def container(img, x, y, color, levels=1):
    """A box, or a pile of them. The sheet is the yard's own: eight liveries,
    24x13, and the pile is drawn bottom box first so the top one overlaps."""
    sheet = tint(sprite("container_sheet"), SHADE)
    shadow = tint(sprite("container_shadow"), SHADE)
    frame = sheet.crop((color % 8 * BOX_W, 0, color % 8 * BOX_W + BOX_W, BOX_H))
    img.alpha_composite(shadow, (int(x), int(y) + 2))
    for level in range(levels):
        img.alpha_composite(frame, (int(x), int(y) - level * 3))


# --------------------------------------------------------------------- light

def _bloom(img, x, y, radius, strength, warm=(1.0, 0.84, 0.48)):
    """Warm light spilling onto whatever is under it. Additive, so it lifts the
    ship, the quay and the water without knowing which is which."""
    for oy in range(-radius, radius + 1):
        for ox in range(-radius, radius + 1):
            distance = (ox * ox + oy * oy) ** 0.5
            if distance > radius:
                continue
            fade = (1.0 - distance / radius) ** 2
            cx, cy = x + ox, y + oy
            if not (0 <= cx < W and 0 <= cy < H):
                continue
            base = img.getpixel((cx, cy))
            add = strength * fade
            img.putpixel((cx, cy), (
                min(255, base[0] + int(add * warm[0])),
                min(255, base[1] + int(add * warm[1])),
                min(255, base[2] + int(add * warm[2])), 255))


def _reflection(img, x, y, height, color, seed):
    """A light's answer on the water: broken warm dashes running away from the
    source. Water is the only surface in this picture that can show the lamps
    are real, and a striped blue rectangle wastes it."""
    state = seed
    for step in range(height):
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        if state % 5 == 0:
            continue
        width = 1 + (state >> 8) % 3
        offset = ((state >> 16) % 5) - 2
        alpha = 0.5 - step / (height * 2.4)
        for ox in range(width):
            cx, cy = x + offset + ox, y + step
            if not (0 <= cx < W and 0 <= cy < H):
                continue
            base = img.getpixel((cx, cy))
            img.putpixel((cx, cy), (
                min(255, base[0] + int(color[0] * alpha)),
                min(255, base[1] + int(color[1] * alpha)),
                min(255, base[2] + int(color[2] * alpha)), 255))


def _line(img, x0, y0, x1, y1, color):
    """A rope, drawn one pixel at a time. Bresenham on a 320px canvas is cheaper
    than importing a drawing library's line and having it antialias."""
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    step_x = 1 if x0 < x1 else -1
    step_y = 1 if y0 < y1 else -1
    error = dx - dy
    while True:
        px(img, x0, y0, color)
        if x0 == x1 and y0 == y1:
            return
        double = error * 2
        if double > -dy:
            error -= dy
            x0 += step_x
        if double < dx:
            error += dx
            y0 += step_y


def _vignette(img, strength=0.26):
    """Darkened corners. The title has to hold a wordmark, three keys and four
    corner buttons over a picture of a working terminal; without this the type
    fights the containers for every pixel it stands on."""
    cx, cy = W * 0.5, H * 0.5
    longest = (cx * cx + cy * cy) ** 0.5
    for y in range(H):
        for x in range(W):
            distance = (((x - cx) ** 2 + (y - cy) ** 2) ** 0.5) / longest
            if distance < 0.40:
                continue
            fade = ((distance - 0.40) / 0.60) ** 1.6 * strength
            r, g, b, a = img.getpixel((x, y))
            img.putpixel((x, y), (
                int(r * (1.0 - fade)), int(g * (1.0 - fade)),
                int(b * (1.0 - fade * 0.9)), a))


# ---------------------------------------------------------------- the pieces

def _ground(img):
    tile(img, "gr_grass", 0, 0, GRASS_X1, H)
    tile(img, "gr_yard_b", ROAD_X0, 0, ROAD_X1, H)
    tile(img, "gr_yard", YARD_X0, 0, YARD_X1, H,
         variants=["gr_yard_0", "gr_yard_1", "gr_yard_2", "gr_yard_3"])
    tile(img, "gr_quay", QUAY_X0, 0, QUAY_X1, H)
    tile(img, "gr_water", WATER_X0, 0, W, H)

    # Kerbs either side of the carriageway, the way `GroundBaker` sets them.
    for ty in range(0, H, 16):
        paste(img, "gr_curb", ROAD_X0 - 8, ty)
        paste(img, "gr_curb", ROAD_X1 - 2, ty, flip=True)
    for ty in range(0, H, 20):
        paste(img, "gr_lane_dash", (ROAD_X0 + ROAD_X1) // 2 - 8, ty)

    # The seam where the grass gives up and the pavement starts.
    for tx in range(0, GRASS_X1 + 4, 10):
        frame = _rng.randrange(4)
        seam = tint(sprite("gr_seam_tufts").crop(
            (frame * 10, 0, frame * 10 + 10, 8)), SHADE)
        img.alpha_composite(seam, (tx, _rng.randrange(0, H - 8)))

    # Quay edge and the foam running along it: the one line in the picture that
    # says the concrete stops and the sea starts.
    for ty in range(0, H, 16):
        paste(img, "gr_quay_edge", QUAY_X1 - 10, ty)
    foam = tint(sprite("gr_foam"), SHADE, alpha=0.85)
    for ty in range(0, H, 6):
        img.alpha_composite(foam.crop((0, 0, 10, 6)), (WATER_X0 - 2, ty))


def _bays(img):
    """The yard: paint first, then boxes. The bay markings are the same sprite
    the ground bakes under every block in the real terminal."""
    marks = tint(sprite("gr_bay_marks"), SHADE)
    for bay_x in BAY_XS:
        for bay_y in BAY_YS:
            for my in range(bay_y - 2, bay_y + BAY_H, marks.height):
                img.alpha_composite(marks.crop(
                    (0, 0, min(marks.width, BAY_W + 2),
                     min(marks.height, bay_y + BAY_H - my))), (bay_x - 1, my))
            # A head stripe per bay, amber for import and teal for export, which
            # is the yard's own colour code rather than decoration.
            head = (232, 176, 78, 255) if (bay_x // 54 + bay_y // 118) % 2 \
                else (104, 194, 176, 255)
            for hx in range(bay_x, bay_x + BAY_W):
                if (hx // 3) % 2 == 0:
                    px(img, hx, bay_y - 5, head)
                    px(img, hx, bay_y - 4, tuple(int(c * 0.65) for c in head[:3])
                       + (255,))

    for bay_index, bay_x in enumerate(BAY_XS):
        for row_index, bay_y in enumerate(BAY_YS):
            for col in range(2):
                for row in range(5):
                    seed = bay_index * 31 + row_index * 17 + col * 7 + row * 3
                    if seed % 7 == 0:
                        continue
                    container(img, bay_x + col * BOX_W, bay_y + row * 14,
                              seed % 8, levels=1 + (seed % 3 == 0))


def _machines(img):
    """What is working the yard. Every one of these is the sprite the player is
    about to buy, so the title doubles as a picture of the catalogue."""
    for index, bay_y in enumerate(BAY_YS[:4]):
        # A transtainer straddling the middle bay, and a stacker beside another.
        paste(img, "rtg", BAY_XS[index % 3] + BAY_W // 2, bay_y + 30,
              center=True, shadow=True)
        paste(img, "rtg_trolley", BAY_XS[index % 3] + BAY_W // 2,
              bay_y + 30 - 4, center=True)
    for x, y, flip in ((YARD_X0 + 8, 176, False), (198, 300, True),
                       (YARD_X0 + 6, 470, False), (200, 596, True)):
        paste(img, "veh_reach_stacker", x, y, shadow=True, flip=flip)
    for x, y in ((YARD_X0 + 2, 96), (206, 214), (YARD_X0 + 4, 386), (204, 512)):
        paste(img, "veh_forklift", x, y, shadow=True)
    # Road traffic, coming in from the city.
    for y in (60, 300, 560):
        paste(img, "veh_truck_chassis", ROAD_X0 + 4, y + 20, shadow=True)
        paste(img, "veh_truck_cab", ROAD_X0 + 4, y, shadow=True)
    paste(img, "veh_tt", ROAD_X0 + 3, 420, shadow=True)


def _buildings(img):
    """The service band. A terminal with no roof on it is a car park."""
    paste(img, "bld_warehouse", 66, 14, shadow=True)
    paste(img, "bld_office", 154, 20, shadow=True)
    paste(img, "bld_customs", 194, 22, shadow=True)
    paste(img, "bld_warehouse", 74, 654, shadow=True)
    paste(img, "bld_tower", 168, 660, shadow=True)
    paste(img, "bld_tower_radar", 173, 656)
    # Lit windows, because late afternoon is when the offices are still on.
    for wx, wy in ((160, 30), (166, 30), (200, 32), (176, 668)):
        rect(img, wx, wy, 3, 2, (250, 216, 140, 255))
        _bloom(img, wx + 1, wy + 1, 7, 26)


def _quay(img):
    """The apron: rails for the cranes, bollards for the ship, and the clutter
    of a place people actually work in."""
    rail = tint(sprite("crane_rail"), SHADE)
    for ty in range(0, H, 16):
        img.alpha_composite(rail.rotate(90, expand=True), (QUAY_X0 + 3, ty))
        img.alpha_composite(rail.rotate(90, expand=True), (QUAY_X1 - 7, ty))
    for by in range(24, H, 58):
        paste(img, "prop_bollard", QUAY_X1 - 9, by)
    for cx, cy in ((QUAY_X0 + 2, 150), (QUAY_X0 + 12, 268), (QUAY_X0 + 4, 402),
                   (QUAY_X0 + 14, 520), (QUAY_X0 + 6, 636)):
        paste(img, "prop_cone", cx, cy)
    for px_, py in ((QUAY_X0 + 8, 96), (QUAY_X0 + 6, 340), (QUAY_X0 + 10, 580)):
        paste(img, "prop_pallet", px_, py, shadow=True)
    paste(img, "prop_cable_reel", QUAY_X0 + 4, 196, shadow=True)
    paste(img, "prop_lifebuoy", QUAY_X0 + 14, 456)
    # Lamp masts down the apron, lit and throwing a pool.
    for ly in (70, 260, 450, 640):
        paste(img, "prop_lamp_lit", QUAY_X0 + 1, ly)
        _bloom(img, QUAY_X0 + 7, ly + 12, 22, 34)
        _reflection(img, WATER_X0 + 6, ly + 20, 46, (90, 62, 24), ly)


def _clutter(img):
    """The forty-pixel gaps between bays, which is where a terminal keeps the
    things it is between using. Empty asphalt is what makes a yard read as a car
    park, and there is a lot of asphalt in this picture."""
    lane_ys = [bay_y + BAY_H + 6 for bay_y in BAY_YS]
    for index, lane_y in enumerate(lane_ys):
        paste(img, "prop_pallet", YARD_X0 + 12 + (index % 3) * 46, lane_y,
              shadow=True)
        paste(img, "prop_cone", YARD_X0 + 40 + (index % 2) * 60, lane_y + 14)
        paste(img, "prop_cone", YARD_X0 + 96 + (index % 3) * 22, lane_y + 4)
        paste(img, "prop_puddle", YARD_X0 + 60 + (index % 4) * 30, lane_y + 18,
              k=1.0)
        if index % 2 == 0:
            paste(img, "prop_cable_reel", YARD_X0 + 132, lane_y + 12,
                  shadow=True)
        else:
            paste(img, "prop_bush", YARD_X0 + 128, lane_y + 10)
    # Lamp masts down the yard's spine, lit the way the apron's are.
    for ly in (150, 340, 530, 690):
        paste(img, "prop_lamp_lit", YARD_X0 + 100, ly)
        _bloom(img, YARD_X0 + 106, ly + 12, 18, 26)


def _people(img):
    """Nine frames of walking stevedore on one strip; the title takes stills of
    it. A working terminal with nobody in it is a diagram."""
    sheet = tint(sprite("worker_sheet"), SHADE)
    frame_w = sheet.width // 9
    for index, (x, y) in enumerate(((92, 190), (138, 330), (196, 246),
                                    (84, 452), (208, 122), (110, 610),
                                    (176, 690), (QUAY_X0 + 8, 214),
                                    (QUAY_X0 + 12, 508))):
        frame = sheet.crop((index % 9 * frame_w, 0,
                            index % 9 * frame_w + frame_w, sheet.height))
        img.alpha_composite(frame, (x, y))


def _cranes(img):
    """Three ship-to-shore gantries, assembled from the same four sprites the
    machine in the yard is: beam, base, and — added by the title screen so it
    can move them — trolley and spreader.

    Mirrored, because the world's boom reaches left over the yard and this one
    has to reach right over the ship."""
    beam = tint(sprite("sts_beam").transpose(Image.FLIP_LEFT_RIGHT), SHADE)
    for base_y in CRANE_YS:
        img.alpha_composite(beam, (QUAY_X0 - 10, base_y + 8))
        paste(img, "sts_base", QUAY_X0 + 10, base_y, center=True, shadow=True)


def _ship(img):
    """The vessel alongside, and everything that says she is *worked* rather
    than parked: warm accommodation windows, a gangway, mooring lines to the
    bollards on the quay and the wash where her plating meets the water.

    Bow up, like every hull in the game — the painting is flipped to get there,
    because the model put the accommodation block forward and the rudder aft."""
    hull = sprite("ui_title_ship").transpose(Image.FLIP_TOP_BOTTOM)
    sw, sh = hull.size
    sx, sy = WATER_X0 + 4, 176

    lit: list[tuple[int, int]] = []
    pixels = hull.load()
    for y in range(sh):
        for x in range(sw):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            # Remember the accommodation block: cream is the only near-white on
            # the hull, and that is where the lights are.
            if r > 196 and g > 190 and b > 172:
                lit.append((x, y))
    img.alpha_composite(tint(hull, SHADE), (sx, sy))

    # Windows, picked off the cream the model painted rather than from a table
    # of coordinates — regenerate the ship and the lights follow her.
    for index, (x, y) in enumerate(lit):
        if index % 11 == 0:
            px(img, sx + x, sy + y, (250, 214, 138, 255))
        elif index % 23 == 5:
            px(img, sx + x, sy + y, (236, 190, 116, 255))
    if lit:
        _bloom(img, sx + sum(p[0] for p in lit) // len(lit),
               sy + sum(p[1] for p in lit) // len(lit), 15, 18)

    # Mooring lines, fore and aft, to the bollards down the quay face. Rope at
    # this hour, not lightning: bright white line work reads as a scratch.
    for anchor_y, bollard_y in ((sy + 10, sy - 14), (sy + sh - 12, sy + sh + 12)):
        _line(img, sx + 2, anchor_y, QUAY_X1 - 6, bollard_y, (196, 184, 156, 255))
    # Gangway down to the quay, amidships.
    rect(img, QUAY_X1 - 6, sy + sh // 2 - 3, sx - QUAY_X1 + 8, 6,
         (58, 46, 44, 255))
    rect(img, QUAY_X1 - 6, sy + sh // 2 - 2, sx - QUAY_X1 + 8, 4,
         (196, 184, 162, 255))

    px(img, sx + 1, sy + 12, (246, 76, 62, 255))
    px(img, sx + sw - 2, sy + 12, (108, 236, 128, 255))

    for y in range(sy - 6, sy + sh + 8):
        h = (y * 2654435761) & 0xFFFF
        if h % 7 == 0:
            hline(img, sx + sw, y, 1 + h % 4, (226, 240, 240, 255))
        if h % 11 == 3:
            hline(img, sx - 1 - h % 3, y, 1 + h % 3, (196, 220, 226, 255))
    return sx, sy, sw, sh


def _water_life(img):
    """A tug standing off in the channel and marks down the fairway. Two vessels
    make the water a place with traffic on it; one makes it a parking space."""
    paste(img, "veh_tug", W - 34, 566)
    for step in range(14):
        wake = (step * 2654435761) & 0xFF
        hline(img, W - 26 - wake % 5, 610 + step, 2 + wake % 4,
              (206, 228, 232, 255))
    for by in (96, 470, 664):
        paste(img, "prop_buoy", W - 22, by)


def _planting(img):
    """The landward edge. It is the only part of this picture that is not the
    terminal, and it is what makes the terminal read as *somewhere*."""
    for index, ty in enumerate(range(6, H, 44)):
        if index % 3 == 2:
            paste(img, "prop_bush", 4 + (index % 2) * 14, ty + 6)
        else:
            paste(img, "prop_tree", 2 + (index % 3) * 5, ty, shadow=True)
    # No fence line. Tiled down 720 pixels it became a picket wall taller than
    # anything else in the picture and read as the subject of it.


## Where the three gantries stand. The title screen animates a trolley on each,
## so it needs the same list — it is exported rather than inlined.
CRANE_YS = (208, 372, 536)


def gen_title_port():
    img = new_img(W, H)
    _ground(img)
    _bays(img)
    _buildings(img)
    _machines(img)
    _quay(img)
    _clutter(img)
    _ship(img)
    _water_life(img)
    _people(img)
    _planting(img)
    _cranes(img)
    _vignette(img)
    save(img, "ui_title_port", preview_scale=2)


# ------------------------------------------------------------------ the sign

NAVY = (32, 44, 68, 255)
NAVY_D = (20, 28, 46, 255)
NAVY_L = (56, 74, 106, 255)
AMBER = (250, 196, 92, 255)
AMBER_D = (186, 130, 44, 255)
AMBER_L = (254, 226, 158, 255)
EDGE = (12, 16, 28, 255)
INK = (18, 22, 34, 255)


def _bevel_panel(img, x, y, w, h, face, light, dark, edge=EDGE):
    """A slab with a lit top-left and a shaded bottom-right. Every plate on the
    title is built from this so the whole screen is lit from one direction."""
    rect(img, x, y, w, h, edge)
    rect(img, x + 1, y + 1, w - 2, h - 2, face)
    hline(img, x + 2, y + 1, w - 4, light)
    vline(img, x + 1, y + 2, h - 4, light)
    hline(img, x + 2, y + h - 2, w - 4, dark)
    vline(img, x + w - 2, y + 2, h - 4, dark)


def _rounded_plate(img, x, y, w, h, face, light, dark, ink=INK, radius=3):
    """The title's own material: a slab with the corners knocked off, a two-pixel
    ink edge and a bevel inside it.

    A one-pixel outline is what a control wears. Two, with the corners cut, is
    what a *sign* wears — it is the single biggest difference between the keys on
    this screen and the keys on every other one, and it is why the title can hold
    its own over a photograph of a container yard."""
    for row in range(h):
        inset = 0
        for step in range(radius):
            if row < radius - step or row >= h - (radius - step):
                inset = step + 1
        hline(img, x + inset, y + row, w - inset * 2, ink)
    for row in range(1, h - 1):
        inset = 1
        for step in range(radius):
            if row < radius - step or row >= h - (radius - step):
                inset = step + 2
        if w - inset * 2 <= 0:
            continue
        hline(img, x + inset, y + row, w - inset * 2, ink)
    for row in range(2, h - 2):
        inset = 2
        for step in range(radius):
            if row < radius - step or row >= h - (radius - step):
                inset = step + 3
        if w - inset * 2 <= 0:
            continue
        hline(img, x + inset, y + row, w - inset * 2, face)
    hline(img, x + 4, y + 2, w - 8, light)
    hline(img, x + 4, y + h - 3, w - 8, dark)
    vline(img, x + 2, y + 4, h - 8, light)
    vline(img, x + w - 3, y + 4, h - 8, dark)


def _rivets(img, w, h, color, inner):
    for rx, ry in ((5, 5), (w - 6, 5), (5, h - 6), (w - 6, h - 6)):
        px(img, rx, ry, color)
        px(img, rx, ry - 1, inner)


def gen_title_plate():
    """The board the wordmark is bolted to, as a nine-patch.

    Nine-patch, so the plate fits whatever the title string measures rather than
    the string being sized to fit a picture. The middle is flat on purpose — a
    stretched middle with texture in it becomes a smear on a wide panel."""
    w, h = 32, 34
    img = new_img(w, h)
    _rounded_plate(img, 0, 0, w, h, NAVY, NAVY_L, NAVY_D, radius=4)
    hline(img, 5, h - 5, w - 10, AMBER_D)
    _rivets(img, w, h, NAVY_D, NAVY_L)
    save(img, "ui_title_plate", preview_scale=4)


def gen_title_ribbon():
    """The motto banner under the plate, also a nine-patch."""
    w, h = 20, 16
    img = new_img(w, h)
    _rounded_plate(img, 0, 0, w, h, (46, 38, 34, 255), (68, 58, 50, 255),
                   (30, 24, 22, 255), radius=2)
    hline(img, 4, 3, w - 8, AMBER_D)
    hline(img, 4, h - 4, w - 8, AMBER_D)
    save(img, "ui_title_ribbon", preview_scale=4)


def gen_title_keys():
    """The three keys down the middle and the four in the corners.

    They are the title's own furniture rather than `UiTheme`'s: the console's
    keys are steel bolted to the port and read against navy, and these have to
    read against whatever the backdrop is doing behind them. Same material as
    the plate, so the sign and its buttons are visibly one object."""
    for name, face, light, dark in (
            ("ui_title_key", (246, 186, 74, 255), (254, 226, 158, 255),
             (176, 116, 30, 255)),
            ("ui_title_key_down", (214, 158, 58, 255), (238, 196, 110, 255),
             (150, 96, 24, 255)),
            ("ui_title_key_steel", (46, 60, 84, 255), (74, 94, 126, 255),
             (26, 34, 52, 255)),
            ("ui_title_key_steel_down", (36, 48, 70, 255), (58, 74, 102, 255),
             (20, 26, 42, 255))):
        w, h = 26, 26
        img = new_img(w, h)
        _rounded_plate(img, 0, 0, w, h, face, light, dark, radius=3)
        _rivets(img, w, h, dark, light)
        save(img, name, preview_scale=4)


def gen_title_pip():
    """The ornament either side of the version line, drawn at the size it is
    used at. The mark itself is 40px of crest; shrinking that to nine by asking
    a TextureRect to scale it is how pixel art turns to mush."""
    w, h = 9, 11
    img = new_img(w, h)
    for oy in range(0, 4):
        for ox in range(-2, 3):
            if 1 <= ox * ox + (oy - 2) * (oy - 2) <= 4:
                px(img, 4 + ox, oy, AMBER)
    rect(img, 4, 3, 1, 6, AMBER)
    rect(img, 1, 4, 7, 1, AMBER)
    for side in (-1, 1):
        px(img, 4 + side * 3, 8, AMBER)
        px(img, 4 + side * 2, 9, AMBER)
        px(img, 4 + side * 3, 7, AMBER_D)
    px(img, 4, 10, AMBER)
    save(img, "ui_title_pip", preview_scale=8)


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


# ----------------------------------------------------------------- the logo

WORDMARK = "HarborClick"
## Where the gold takes over from the teal.
SPLIT = 6
## 3x, not 4. The plate is clamped to 340 logical pixels and the phone this is
## designed for gives it 272 — a wordmark that does not fit the sign it is
## bolted to is not a bigger logo, it is a broken one.
SCALE = 3
## Advance per glyph. The font sets 6, and at this scale a two-pixel ring welds
## "rb" into one shape without the extra — the ring needs somewhere to happen.
ADVANCE = 6 * SCALE + 4


def _glyph_rows(char: str):
    rows = gen_font.G.get(char)
    if rows is None:
        rows = gen_font.G.get(char.upper())
    return rows


def _word_mask(size, chars, x, y, scale=SCALE) -> Image.Image:
    """The chosen letters as a stencil. Everything the logo does — the body, the
    ring, the rim — is a set operation on this, which is the only way the three
    of them can agree about where a letter is."""
    mask = Image.new("L", size, 0)
    pixels = mask.load()
    cursor = x
    for index, char in enumerate(WORDMARK):
        rows = _glyph_rows(char)
        if rows is not None and index in chars:
            for ry, row in enumerate(rows):
                for rx, cell in enumerate(row):
                    if cell != "#":
                        continue
                    for sy in range(scale):
                        for sx in range(scale):
                            cx, cy = cursor + rx * scale + sx, y + ry * scale + sy
                            if 0 <= cx < size[0] and 0 <= cy < size[1]:
                                pixels[cx, cy] = 255
        cursor += ADVANCE
    return mask


def _shift(mask: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new("L", mask.size, 0)
    out.paste(mask, (dx, dy))
    return out


def _union(masks) -> Image.Image:
    out = None
    for mask in masks:
        out = mask if out is None else Image.composite(
            Image.new("L", mask.size, 255), out, mask)
    return out


def _minus(mask: Image.Image, other: Image.Image) -> Image.Image:
    return Image.composite(Image.new("L", mask.size, 0), mask, other)


def _dilate(mask: Image.Image, radius: int) -> Image.Image:
    shifts = [_shift(mask, dx, dy)
              for dy in range(-radius, radius + 1)
              for dx in range(-radius, radius + 1)
              if dx * dx + dy * dy <= radius * radius + 1]
    return _union(shifts)


def _fill(img: Image.Image, mask: Image.Image, color) -> None:
    img.paste(Image.new("RGBA", img.size, color), (0, 0), mask)


def _blit_word(img, x, y, color, scale=SCALE):
    """The game's own 5x7 glyphs, at 4x, one filled square per bit.

    The wordmark used to be two Labels stacked in the scene. That put the title
    of the game at the same weight as a button caption, because it *was* the
    same font at the same weight — the only way to a logo is to draw one, and
    the only way to keep it the game's logo is to draw it out of the game's
    letters."""
    cursor = x
    for char in WORDMARK:
        rows = _glyph_rows(char)
        if rows is None:
            cursor += 6 * scale
            continue
        for ry, row in enumerate(rows):
            for rx, cell in enumerate(row):
                if cell == "#":
                    rect(img, cursor + rx * scale, y + ry * scale,
                         scale, scale, color)
        cursor += ADVANCE
    return cursor - x


def gen_title_word():
    """`HarborClick` as a single drawn object: extruded, ringed and lit.

    Three passes make the difference between type and a logo — a dark body
    dropped straight down so the letters have thickness, a two-pixel ink ring so
    they survive being read against a container yard, and a pale rim along the
    top of each stroke where the same late-afternoon light that lit the port
    catches them."""
    teal = (86, 198, 184, 255)
    teal_rim = (176, 236, 224, 255)
    gold = (250, 196, 92, 255)
    gold_rim = (254, 232, 176, 255)
    body = (18, 26, 42, 255)
    ring = (10, 14, 24, 255)

    depth = SCALE + 1
    ring_px = 2
    pad = ring_px + 1
    size = (len(WORDMARK) * ADVANCE + pad * 2,
            7 * SCALE + pad * 2 + depth)
    img = new_img(*size)

    face = _word_mask(size, range(len(WORDMARK)), pad, pad)
    left = _word_mask(size, range(SPLIT), pad, pad)
    right = _word_mask(size, range(SPLIT, len(WORDMARK)), pad, pad)
    # The letter and everything under it: the solid the logo is cut from.
    solid = _union([_shift(face, 0, step) for step in range(depth + 1)])

    _fill(img, _dilate(solid, ring_px), ring)
    _fill(img, solid, body)
    _fill(img, left, teal)
    _fill(img, right, gold)
    # A rim along the top of every stroke — half a stroke deep, so the same
    # late-afternoon light that lit the port catches the letters too.
    rim = _minus(face, _shift(face, 0, SCALE // 2))
    _fill(img, Image.composite(rim, Image.new("L", size, 0), left), teal_rim)
    _fill(img, Image.composite(rim, Image.new("L", size, 0), right), gold_rim)
    save(img, "ui_title_word", preview_scale=2)


if __name__ == "__main__":
    gen_title_port()
    gen_title_plate()
    gen_title_ribbon()
    gen_title_keys()
    gen_title_anchor()
    gen_title_pip()
    gen_title_word()
