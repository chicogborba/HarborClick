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
QUAY_X0, QUAY_X1 = 204, 228
## The shore. Moved left rather than widening `W`: the backdrop is drawn COVERED
## into a 320-wide viewport, so 320 is the one width that lands on an exact 1:1
## and anything else makes every pixel in the picture shimmer.
WATER_X0 = 228

## Bay grid: three rows of boxes across, five bays down, which is what fills the
## visible band without turning into wallpaper.
BAY_XS = (62, 112, 162)
## Four rows, starting below the service band. The first row used to sit at 96,
## which is above the visible band anyway — see the note on `_buildings`.
BAY_YS = (176, 294, 412, 530)
BAY_W, BAY_H = 48, 78
BOX_W, BOX_H = 24, 13

## Dusk, not noon.
##
## The picture used to be lit at 0.92 with a warm cast, which is the yard's own
## daylight with the contrast taken out — everything landed in the same middle
## value and the whole port read as flat. The hour is later now: the ground goes
## down far enough for the lit windows and the lamp pools to be the brightest
## things in the frame, and the cast is cooler so those warm notes have something
## to be warm *against*.
##
## Still not a night filter. The terminal the player opens two taps later is
## bright, and a title three stops darker than the game is a different game —
## `title_screen.gd` also lays a 16% navy wash over this at runtime, so the grade
## has to be judged in the running screen and not in the preview PNG.
WARM = (0.94, 0.96, 1.06)
SHADE = 0.80

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


def tile(img, name, x0, y0, x1, y1, variants=None, k=None, warm=None):
    """Fill a rect with a ground tile, exactly the way `GroundBaker` fills the
    real yard — including picking a variant per cell, which is what stops a
    hundred square metres of asphalt reading as one flat colour."""
    tiles = [tint(sprite(n), SHADE if k is None else k,
                  warm=WARM if warm is None else warm) for n in (variants or [name])]
    step = tiles[0].width
    for ty in range(y0, y1, step):
        for tx in range(x0, x1, step):
            art = tiles[_rng.randrange(len(tiles))]
            box = (max(0, x0 - tx), max(0, y0 - ty),
                   min(art.width, x1 - tx), min(art.height, y1 - ty))
            if box[2] <= box[0] or box[3] <= box[1]:
                continue
            img.alpha_composite(art.crop(box), (tx + box[0], ty + box[1]))


## Cargo is lit hotter than the ground it stands on.
##
## Everything used to go through the same `SHADE`, and the measurement said what
## the eye already suspected: the boxes came out at luminance 83 against asphalt
## at 89 — the subject of the picture was *darker* than the floor. A container
## yard reads because the steel is the brightest, most saturated thing in it and
## the tarmac is not, so the boxes get their own key above the ambient one.
BOX_LIGHT = 1.55
BOX_WARM = (1.05, 1.0, 0.94)


def container(img, x, y, color, levels=1):
    """A box, or a pile of them. The sheet is the yard's own: eight liveries,
    24x13, and the pile is drawn bottom box first so the top one overlaps."""
    sheet = tint(sprite("container_sheet"), SHADE * BOX_LIGHT, warm=BOX_WARM)
    # The shadow stays on the ambient key — a lit box does not cast a lit shadow.
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
    # Darker than the tint alone would make it: at dusk the one thing with no
    # light on it at all is the ground outside the fence, and a bright green lawn
    # beside a navy sea is where the eye goes instead of to the port.
    verge = tint(sprite("gr_grass"), SHADE * 0.62, warm=(0.86, 0.98, 0.94))
    for ty in range(0, H, verge.height):
        for tx in range(0, GRASS_X1, verge.width):
            img.alpha_composite(verge, (tx, ty))
    tile(img, "gr_yard_b", ROAD_X0, 0, ROAD_X1, H, k=SHADE * 0.70)
    tile(img, "gr_yard", YARD_X0, 0, YARD_X1, H,
         variants=["gr_yard_0", "gr_yard_1", "gr_yard_2", "gr_yard_3"],
         k=SHADE * 0.80)
    # Concrete keeps its own value: the apron is the pale band that separates a
    # dark yard from a dark sea, and flattening it into either loses the quay.
    tile(img, "gr_quay", QUAY_X0, 0, QUAY_X1, H, k=SHADE * 1.02)
    tile(img, "gr_water", WATER_X0, 0, W, H)
    _water_depth(img)

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


def _water_depth(img):
    """Water that gets deeper as it leaves the quay.

    One flat tile across ninety pixels reads as a painted floor, not as a sea:
    the eye needs the shoal to be lighter than the channel to believe there is
    anything under it. Four bands, each a step colder and darker than the last,
    laid over the tile as a translucent wash so the tile's own ripple survives.

    The lightest band hugs the quay, which is also where the ship sits — so the
    hull gets a pale ground to read against and the deep navy stays out at the
    edge of the frame where it does the most for the picture's contrast."""
    bands = (
        (0, 9, (170, 224, 228), 0.42),
        (9, 24, (96, 168, 190), 0.34),
        (24, 50, (32, 84, 124), 0.46),
        (50, W - WATER_X0, (14, 38, 72), 0.62),
    )
    wash = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for x0, x1, colour, alpha in bands:
        rect(wash, WATER_X0 + x0, 0, x1 - x0, H,
             colour + (int(round(alpha * 255)),))
    img.alpha_composite(wash)
    # A seam of light where the shoal meets the channel: the one line that says
    # the bottom drops away rather than fading.
    for y in range(0, H, 3):
        px(img, WATER_X0 + 26, y, (168, 220, 226, 90))


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


## The band of the 720px canvas a phone actually shows. The backdrop is drawn
## COVERED into a 320-wide viewport, so it is 1:1 horizontally and cropped
## vertically — roughly this. Anything painted outside it is invisible work.
VISIBLE_Y0, VISIBLE_Y1 = 120, 600


def _buildings(img):
    """The service band, and the only warm light in the picture.

    Every roof and every lit window used to be painted at y 14-32 and y 654-668
    — both *outside* the band a phone shows. The terminal therefore opened on a
    strip of grass, a road and nothing else on its landward side, and the four
    windows that were supposed to be the one warm note against all that blue
    were never once on screen. They live in the frame now.

    The sheds head the yard, the way they do at the landward end of a real
    terminal, and the control tower closes it at the foot."""
    paste(img, "bld_warehouse", 62, VISIBLE_Y0 + 8, shadow=True)
    paste(img, "bld_office", 146, VISIBLE_Y0 + 12, shadow=True)
    paste(img, "bld_customs", 184, VISIBLE_Y0 + 14, shadow=True)
    paste(img, "bld_warehouse", 66, VISIBLE_Y1 - 54, shadow=True)
    paste(img, "bld_tower", 168, VISIBLE_Y1 - 50, shadow=True)
    paste(img, "bld_tower_radar", 173, VISIBLE_Y1 - 54)
    # Lit windows. Late afternoon is when the offices are still on, and this is
    # the picture's warm accent — a row of them, not a token pair, and bloomed
    # hard enough to pool on the tarmac.
    warm = (252, 220, 148, 255)
    for wx, wy in ((70, VISIBLE_Y0 + 16), (82, VISIBLE_Y0 + 16),
                   (94, VISIBLE_Y0 + 16), (106, VISIBLE_Y0 + 16),
                   (118, VISIBLE_Y0 + 16),
                   (152, VISIBLE_Y0 + 20), (160, VISIBLE_Y0 + 20),
                   (190, VISIBLE_Y0 + 22),
                   (74, VISIBLE_Y1 - 46), (86, VISIBLE_Y1 - 46),
                   (98, VISIBLE_Y1 - 46), (176, VISIBLE_Y1 - 44)):
        rect(img, wx, wy, 3, 2, warm)
        _bloom(img, wx + 1, wy + 1, 9, 34)


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


## The two strips of backdrop the finished screen actually leaves uncovered.
##
## The 320-wide viewport shows texture y 106-614, and the marquee then covers the
## head of it with the plate and the ribbon, the middle with the three keys, and
## the foot with the corner keys. What is left is these two bands — so a lamp
## anywhere else is a lamp nobody sees, which is the same mistake `_buildings`
## made with every one of its windows.
LIT_STRIPS = ((267, 348), (488, 540))


def _yard_lights(img):
    """Lamp masts standing in the yard, in the bands the screen leaves open.

    The quay already had lamps, but all four sat outside the open strips, so at
    dusk the terminal's own lighting was invisible and the picture had no warm
    note at all against ninety pixels of navy. These stand where they can be
    seen, and they pool on the tarmac hard enough to read as light rather than
    as a lighter patch of asphalt."""
    for y0, y1 in LIT_STRIPS:
        for mast_x in (58, 148, 200):
            mast_y = y0 + (y1 - y0) // 2 - 6
            paste(img, "prop_lamp_lit", mast_x, mast_y)
            _bloom(img, mast_x + 6, mast_y + 12, 26, 46)


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


def _remap(art, table, tolerance=26):
    """Swap one palette family for another on a sprite as it is pasted.

    Cheaper and safer than a second generator: the gantry the yard uses is
    painted in the game's crane red, and the title wants the safety yellow a
    ship-to-shore actually wears — but `gen_cranes.py` draws the machine the
    *player* buys, and repainting it there would repaint the terminal too."""
    out = art.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            for src, dst in table:
                if (abs(r - src[0]) <= tolerance and abs(g - src[1]) <= tolerance
                        and abs(b - src[2]) <= tolerance):
                    pixels[x, y] = (dst[0], dst[1], dst[2], a)
                    break
    return out


## Crane red to safety yellow. A ship-to-shore gantry is the tallest thing in a
## container terminal and it is painted so that it can be seen from the bridge of
## a ship — three dark red girders laid across a dark quay at dusk is the one
## object in this picture that had no business being hard to find.
GANTRY_PAINT = (
    ((150, 60, 58), (176, 116, 30)),
    ((200, 92, 78), (238, 176, 62)),
    ((232, 138, 112), (252, 216, 130)),
)


def _cranes(img):
    """Three ship-to-shore gantries, assembled from the same four sprites the
    machine in the yard is: beam, base, and — added by the title screen so it
    can move them — trolley and spreader.

    Mirrored, because the world's boom reaches left over the yard and this one
    has to reach right over the ship."""
    beam = tint(_remap(sprite("sts_beam").transpose(Image.FLIP_LEFT_RIGHT),
                       GANTRY_PAINT), SHADE * 1.12)
    base = tint(_remap(sprite("sts_base"), GANTRY_PAINT), SHADE * 1.12)
    for base_y in CRANE_YS:
        img.alpha_composite(beam, (QUAY_X0 - 10, base_y + 8))
        _contact_shadow(img, QUAY_X0 + 10 - base.width // 2,
                        base_y - base.height // 2, base)
        img.alpha_composite(base, (QUAY_X0 + 10 - base.width // 2,
                                   base_y - base.height // 2))


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
    for index, ty in enumerate(range(6, H, 22)):
        if index % 4 == 3:
            paste(img, "prop_bush", 3 + (index % 3) * 8, ty + 4)
        else:
            paste(img, "prop_tree", 1 + (index % 3) * 7, ty, shadow=True)
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
    _yard_lights(img)
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
    # An inner rule all the way round, not a stripe along the bottom. A frame is
    # what makes a panel read as a *sign*; one edge of it reads as a mistake, and
    # on a nine-patch the middle stretches so only the four corners carry it —
    # which is exactly where a real signboard's beading would be.
    hline(img, 5, 4, w - 10, AMBER_D)
    hline(img, 5, h - 5, w - 10, AMBER_D)
    vline(img, 4, 5, h - 10, AMBER_D)
    vline(img, w - 5, 5, h - 10, AMBER_D)
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


def _key_slab(img, w, h, face, light, dark, ink=INK, radius=4, pressed=False):
    """A pressed-steel key: ink edge, knocked corners, a banded bevel and rivets.

    The first version drew a one-pixel highlight along the top and a one-pixel
    shadow along the bottom. On a 26-pixel sprite that is a reasonable bevel; on
    the 56-pixel-tall key the layout actually stretches it into, it is a hairline
    nobody sees, and the biggest button on the screen read as a flat rectangle.
    The bands are three pixels now and they live in the nine-patch's *corners*,
    where stretching cannot thin them.
    """
    # Ink edge with the corners knocked off, two pixels thick.
    for row in range(h):
        inset = 0
        for step in range(radius):
            if row < radius - step or row >= h - (radius - step):
                inset = step + 1
        hline(img, inset, row, w - inset * 2, ink)
    # The face, inset by the ink.
    for row in range(2, h - 2):
        inset = 2
        for step in range(radius):
            if row < radius - step or row >= h - (radius - step):
                inset = step + 3
        if w - inset * 2 <= 0:
            continue
        hline(img, inset, row, w - inset * 2, face)

    top_ink, bottom_ink = (dark, light) if pressed else (light, dark)
    # Banded bevel: three rows lit across the top, three shaded across the
    # bottom, two columns down each side. Kept inside the corner radius so the
    # knocked corners stay clean.
    for band in range(3):
        hline(img, 5 - band // 2, 2 + band, w - 10 + band, top_ink
              if band == 0 else _mix(top_ink, face, 0.45 + band * 0.2))
        hline(img, 5 - band // 2, h - 3 - band, w - 10 + band, bottom_ink
              if band == 0 else _mix(bottom_ink, face, 0.45 + band * 0.2))
    for band in range(2):
        vline(img, 2 + band, 5, h - 10, top_ink if band == 0
              else _mix(top_ink, face, 0.55))
        vline(img, w - 3 - band, 5, h - 10, bottom_ink if band == 0
              else _mix(bottom_ink, face, 0.55))

    # Rivets, in the corners so the nine-patch keeps them whatever the key is
    # stretched to. Two pixels with a lit top and a shaded bottom: one pixel is
    # a speck, and a speck on a photograph is dirt.
    for rx, ry in ((7, 7), (w - 9, 7), (7, h - 9), (w - 9, h - 9)):
        rect(img, rx, ry, 2, 2, _mix(dark, ink, 0.35))
        px(img, rx, ry, light)
        px(img, rx + 1, ry + 1, ink)


def _mix(a, b, t):
    return tuple(int(round(a[i] * (1.0 - t) + b[i] * t)) for i in range(3)) + (255,)


def gen_title_keys():
    """The three keys down the middle and the four in the corners.

    They are the title's own furniture rather than `UiTheme`'s: the console's
    keys are steel bolted to the port and read against navy, and these have to
    read against whatever the backdrop is doing behind them. Same material as
    the plate, so the sign and its buttons are visibly one object."""
    for name, face, light, dark, pressed in (
            ("ui_title_key", (246, 186, 74, 255), (255, 232, 168, 255),
             (158, 100, 22, 255), False),
            ("ui_title_key_down", (208, 152, 54, 255), (240, 200, 118, 255),
             (132, 82, 18, 255), True),
            ("ui_title_key_steel", (48, 64, 92, 255), (96, 122, 160, 255),
             (18, 24, 40, 255), False),
            ("ui_title_key_steel_down", (36, 48, 72, 255), (72, 94, 128, 255),
             (14, 18, 32, 255), True)):
        # 34, not 26: the bevel bands and the rivets all have to fit inside the
        # nine-patch corner, and `UiTheme.title_button_style` cuts that at 13.
        w, h = 34, 34
        img = new_img(w, h)
        _key_slab(img, w, h, face, light, dark, pressed=pressed)
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

## A display face, drawn for this word and no other.
##
## The wordmark used to be the game's own 5x7 glyphs at 3x. That is a scaled
## *caption*, not a logo: 5x7 has one-pixel stems, so blowing it up gives thin
## strokes with wide monospace gaps between them, and no amount of extrusion or
## ringing rescues a letterform that thin. These ten letters are drawn instead,
## on a 12-row grid with two-cell stems and their own widths, so the word sets
## tight and heavy the way a title should.
##
## Caps fill all twelve rows; x-height letters start at row 4; ascenders climb
## back to row 0. Only the letters in `WORDMARK` exist here — anything else
## falls through to the game font, which is the right answer for a stray glyph.
TITLE_FACE = {
    "H": ["##.....##", "##.....##", "##.....##", "##.....##", "##.....##",
          "#########", "#########", "##.....##", "##.....##", "##.....##",
          "##.....##", "##.....##"],
    "C": ["..######..", ".###..###.", "##......##", "##........", "##........",
          "##........", "##........", "##........", "##........", "##......##",
          ".###..###.", "..######.."],
    "a": ["..........", "..........", "..........", "..######..", ".##....##.",
          ".......##.", "..#######.", ".##.....##", "##......##", "##.....##.",
          "##....###.", ".#####..##"],
    "r": ["......", "......", "......", "##.###", "######",
          "###..#", "##....", "##....", "##....", "##....",
          "##....", "##...."],
    "b": ["##........", "##........", "##........", "##.#####..", "###...###.",
          "##......##", "##......##", "##......##", "##......##", "##......##",
          "###...###.", "##.#####.."],
    "o": ["..........", "..........", "..........", "..######..", ".###..###.",
          "##......##", "##......##", "##......##", "##......##", "##......##",
          ".###..###.", "..######.."],
    "l": ["####.", "####.", "..##.", "..##.", "..##.",
          "..##.", "..##.", "..##.", "..##.", "..##.",
          "#####", "#####"],
    "i": [".##..", ".##..", ".....", "###..", "###..",
          ".##..", ".##..", ".##..", ".##..", ".##..",
          "#####", "#####"],
    "c": ["..........", "..........", "..........", "..######..", ".###..###.",
          "##......##", "##........", "##........", "##......##", "##......##",
          ".###..###.", "..######.."],
    "k": ["##......", "##......", "##......", "##...##.", "##..##..",
          "##.##...", "#####...", "#####...", "##.##...", "##..##..",
          "##...##.", "##....##"],
}
## Rows in the display face. Everything that sizes the logo reads this rather
## than the font's 7.
FACE_ROWS = 12
## Air between letters, in face cells. One cell: the ink ring is two pixels and
## needs somewhere to happen, but the old four *pixels* of extra tracking on top
## of a monospace advance is what made the word read as l e t t e r s.
TRACK = 1

## Where the gold takes over from the teal.
SPLIT = 6
## 2x on a twelve-row face is taller than the old 3x on a seven-row one, and
## narrower: the plate is clamped to 340 logical pixels and the phone this is
## designed for gives it 272, so the word has to set tight to be big.
SCALE = 2


def _glyph_rows(char: str):
    rows = TITLE_FACE.get(char)
    if rows is not None:
        return rows
    rows = gen_font.G.get(char)
    if rows is None:
        rows = gen_font.G.get(char.upper())
    return rows


def _advance(char: str) -> int:
    """How far the cursor moves after this letter. Proportional: an `i` takes
    the room an `i` needs. The monospace advance the font sets is right for a
    console readout and wrong for a word anybody is meant to read as a shape."""
    rows = _glyph_rows(char)
    width = len(rows[0]) if rows else 5
    return (width + TRACK) * SCALE


def _word_width() -> int:
    return sum(_advance(char) for char in WORDMARK) - TRACK * SCALE


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
        cursor += _advance(char)
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
        cursor += _advance(char)
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
    body = (18, 44, 48, 255)
    gold_body = (76, 44, 12, 255)
    ring = (10, 14, 24, 255)

    depth = SCALE + 1
    # One pixel, not two. Two closed every counter in the word: a dilation grows
    # into a bowl from all four sides at once, and an `o` whose hole has been
    # filled in is not a bolder `o`, it is a blob.
    ring_px = 1
    pad = ring_px + 1
    size = (_word_width() + pad * 2,
            FACE_ROWS * SCALE + pad * 2 + depth)
    img = new_img(*size)

    face = _word_mask(size, range(len(WORDMARK)), pad, pad)
    left = _word_mask(size, range(SPLIT), pad, pad)
    right = _word_mask(size, range(SPLIT, len(WORDMARK)), pad, pad)
    # The letter and everything under it: the solid the logo is cut from.
    solid = _union([_shift(face, 0, step) for step in range(depth + 1)])
    left_solid = _union([_shift(left, 0, step) for step in range(depth + 1)])
    right_solid = _union([_shift(right, 0, step) for step in range(depth + 1)])

    _fill(img, _dilate(solid, ring_px), ring)
    # The body under each half is a darkened version of that half, not one shared
    # near-black. A shadow is the colour of the thing casting it, and two letters
    # of different colours sitting on the same slab of ink read as printed rather
    # than as cut out of something.
    _fill(img, left_solid, body)
    _fill(img, right_solid, gold_body)
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
