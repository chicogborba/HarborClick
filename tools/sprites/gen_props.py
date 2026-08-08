"""Top-down scenery props: lamps, bollards, greenery, wildlife, FX."""
import math
import palette as P
from common import (new_img, rect, hline, vline, px, outline, save, sheet,
                    speckle, patch)


def gen_lamp():
    """Flood-light mast from above: base ring, mast, and a head casting light."""
    img = new_img(12, 16)
    # base plinth
    rect(img, 3, 10, 6, 5, P.QUAY_D)
    hline(img, 3, 10, 6, P.QUAY)
    # mast (foreshortened, so mostly the head is visible)
    rect(img, 5, 5, 3, 6, P.STEEL)
    vline(img, 5, 5, 6, P.STEEL_L)
    # head pointing up-left
    rect(img, 2, 1, 8, 5, P.STEEL_D)
    hline(img, 2, 1, 8, P.STEEL)
    rect(img, 3, 3, 6, 2, P.SAFETY_L)
    save(outline(img), "prop_lamp")

    lit = new_img(12, 16)
    rect(lit, 3, 3, 6, 2, P.WINDOW_LIT)
    save(lit, "prop_lamp_lit")


def gen_glow():
    """Radial light texture for PointLight2D."""
    size = 64
    img = new_img(size, size)
    c = size / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c + 0.5, y - c + 0.5) / c
            if d < 1.0:
                img.putpixel((x, y), (255, 238, 196, int((1.0 - d) ** 2.2 * 255)))
    save(img, "prop_glow", preview_scale=2)


def gen_bollard():
    img = new_img(8, 8)
    for y in range(8):
        for x in range(8):
            d = math.hypot(x - 3.5, y - 3.5)
            if d <= 3.4:
                img.putpixel((x, y), P.CRANE if d > 2.0 else P.CRANE_L)
    px(img, 2, 2, P.CRANE_L)
    save(outline(img), "prop_bollard")


def gen_cone():
    img = new_img(7, 7)
    for y in range(7):
        for x in range(7):
            d = math.hypot(x - 3, y - 3)
            if d <= 3.2:
                img.putpixel((x, y), (232, 110, 58, 255))
            if d <= 1.6:
                img.putpixel((x, y), (250, 168, 110, 255))
    save(outline(img), "prop_cone")


def gen_tree():
    """Round canopy tree seen from above, 22x22."""
    img = new_img(22, 22)
    c = 11.0
    for y in range(22):
        for x in range(22):
            d = math.hypot(x - c + 0.5, y - c + 0.5)
            if d <= 9.6:
                img.putpixel((x, y), P.TREE)
            if d <= 7.4 and (x - c) + (y - c) < -1:
                img.putpixel((x, y), P.TREE_L)
            if d > 8.2 and d <= 9.6 and (x - c) + (y - c) > 2:
                img.putpixel((x, y), P.TREE_D)
    # leaf clumps
    for a in range(0, 360, 45):
        lx = int(c + math.cos(math.radians(a)) * 7)
        ly = int(c + math.sin(math.radians(a)) * 7)
        patch(img, lx, ly, 2, 2, P.TREE_D if a % 90 else P.TREE_L, seed=a)
    px(img, 11, 11, P.TRUNK)
    save(outline(img), "prop_tree")


def gen_bush():
    img = new_img(14, 12)
    for cx, cy, r in ((4, 6, 4), (9, 5, 4), (7, 8, 3)):
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if math.hypot(x - cx, y - cy) <= r:
                    img.putpixel((x, y), P.BUSH)
    speckle(img, 1, 1, 12, 10, [P.BUSH_L], 0.18, seed=3)
    save(outline(img), "prop_bush")


def gen_puddle():
    img = new_img(16, 10)
    for y in range(10):
        t = abs(y - 4.5) / 5.0
        w = int(16 - t * 11)
        rect(img, (16 - w) // 2, y, w, 1, (86, 106, 118, 130))
    hline(img, 5, 3, 5, (168, 200, 212, 150))
    save(img, "prop_puddle")


def gen_seagull():
    """Gull from above, 4-frame flap, 14x12."""
    frames = []
    for f in range(4):
        img = new_img(14, 12)
        spread = (5, 6, 5, 3)[f]
        # wings
        for i in range(spread):
            px(img, 6 - i, 5 - i // 2, P.SUPER_W)
            px(img, 7 + i, 5 - i // 2, P.SUPER_W)
            px(img, 6 - i, 6 - i // 2, P.SUPER_W_D)
            px(img, 7 + i, 6 - i // 2, P.SUPER_W_D)
        # body
        rect(img, 6, 4, 2, 6, P.SUPER_W)
        px(img, 6, 3, P.SAFETY)     # beak
        px(img, 7, 3, P.SAFETY)
        px(img, 6, 10, P.SUPER_W_D)
        frames.append(outline(img))
    save(sheet(frames), "prop_seagull")


def gen_cat():
    """Curled sleeping cat from above, 2 frames, 14x12."""
    frames = []
    for f in range(2):
        img = new_img(14, 12)
        for y in range(12):
            for x in range(14):
                if math.hypot((x - 6.5) / 5.4, (y - 5.5) / 4.4) <= 1.0:
                    img.putpixel((x, y), (176, 132, 88, 255))
        speckle(img, 2, 2, 10, 8, [(142, 104, 66, 255)], 0.22, seed=4)
        # head tucked in
        for y in range(2, 8):
            for x in range(7, 13):
                if math.hypot(x - 9.5, y - 4.5) <= 2.6:
                    img.putpixel((x, y), (204, 162, 112, 255))
        px(img, 8, 4, P.OUTLINE)
        px(img, 11, 4, P.OUTLINE)
        # tail curls around, flicking between frames
        ty = 9 if f == 0 else 8
        px(img, 3, ty, (176, 132, 88, 255))
        px(img, 2, ty - 1, (176, 132, 88, 255))
        px(img, 1, ty - 2, (176, 132, 88, 255))
        frames.append(outline(img))
    save(sheet(frames), "prop_cat")


def gen_dust():
    """Dust puff when a container lands, 4 frames 16x12."""
    frames = []
    for f in range(4):
        img = new_img(16, 12)
        alpha = (210, 180, 130, 70)[f]
        color = (P.QUAY_L[0], P.QUAY_L[1], P.QUAY_L[2], alpha)
        r = 2 + f * 2
        for side in (-1, 1):
            cx = 8 + side * (2 + f * 2)
            for y in range(6 - f, 10 - f):
                for x in range(cx - r // 2, cx + r // 2 + 1):
                    px(img, x, y, color)
        frames.append(img)
    save(sheet(frames), "prop_dust")


def gen_exhaust():
    """Diesel exhaust, 4 frames 12x12, for the locomotive's stack.

    Not the landing dust in a different colour. Dust is thrown sideways off a
    stack and settles; exhaust leaves the stack as a tight dark knot, opens out
    as it rises and goes pale as it thins, and the last frame is nearly nothing.
    The rake is small on screen, so what has to survive is the *change*: a hard
    dot becoming a soft blur is legible at four pixels where a fading disc of
    constant size is not.
    """
    frames = []
    for f in range(4):
        img = new_img(12, 12)
        r = 2.6 + f * 1.2
        # Dark and dense at the stack, pale and open by the time it has risen.
        # The first frame has to be near-opaque and near-black: the branch runs
        # over grey ballast, and a translucent grey dot on grey ballast is a
        # locomotive that appears to be running clean.
        tone = ((38, 35, 42), (74, 70, 80), (122, 118, 128), (166, 162, 170))[f]
        alpha = (238, 196, 132, 58)[f]
        for y in range(12):
            for x in range(12):
                # Squashed vertically, because it is drawn under a top-down
                # camera: a plume goes *up*, and up is towards the viewer.
                d = math.hypot((x - 5.5) / r, (y - 5.5) / (r * 0.85))
                if d <= 1.0:
                    fade = 1.0 - 0.45 * d
                    px(img, x, y, (tone[0], tone[1], tone[2],
                                   int(alpha * fade)))
        frames.append(img)
    save(sheet(frames), "prop_exhaust")


def gen_splash():
    """Water splash ring, 4 frames 20x14."""
    frames = []
    for f in range(4):
        img = new_img(20, 14)
        r = 3 + f * 3
        for a in range(0, 360, 12):
            x = int(10 + math.cos(math.radians(a)) * r)
            y = int(7 + math.sin(math.radians(a)) * r * 0.55)
            if 0 <= x < 20 and 0 <= y < 14:
                px(img, x, y, P.FOAM if f < 2 else P.SEA_SPARK)
        frames.append(img)
    save(sheet(frames), "prop_splash")


def gen_shadow_blob():
    """Generic soft shadow used under vehicles and buildings (32x20)."""
    img = new_img(32, 20)
    for y in range(20):
        t = abs(y - 9.5) / 10.0
        w = int(32 - t * 20)
        rect(img, (32 - w) // 2, y, w, 1, P.SHADOW)
    save(img, "prop_shadow")


def gen_buoy():
    """Port-hand channel mark, seen from above: red can with a lamp on top.

    Two frames — upright and heeled over — so a line of them can bob out of
    phase in the approach channel without any per-buoy animation code.
    """
    frames = []
    for tilt in (0, 1):
        img = new_img(12, 14)
        cx = 5 + tilt
        # wake collar where the hull meets the water
        for wy, ww in ((11, 9), (12, 7)):
            rect(img, 5 - ww // 2 + tilt, wy, ww, 1, (198, 226, 232, 150))
        rect(img, cx - 3, 5, 7, 7, (186, 66, 54, 255))
        hline(img, cx - 3, 5, 7, (222, 104, 84, 255))
        hline(img, cx - 3, 11, 7, (140, 42, 38, 255))
        vline(img, cx + 3, 5, 7, (140, 42, 38, 255))
        rect(img, cx - 1, 1, 3, 4, (120, 112, 118, 255))
        px(img, cx - 1, 1, (170, 164, 168, 255))
        rect(img, cx - 1, 0, 2, 2, (250, 208, 96, 255))
        frames.append(outline(img))
    save(sheet(frames), "prop_buoy")


def gen_cloud():
    """Two soft cloud silhouettes.

    Drawn as flat white blobs: the world tints them at runtime, and the same
    sprite is reused darkened as the shadow it drops on the terminal.
    """
    frames = []
    for seed, lumps in ((7, ((7, 9, 6, 4), (15, 7, 8, 5), (24, 9, 7, 4),
                             (31, 10, 5, 3))),
                        (11, ((6, 10, 5, 3), (13, 8, 8, 5), (22, 10, 6, 4)))):
        img = new_img(40, 18)
        for cx, cy, rx, ry in lumps:
            patch(img, cx, cy, rx, ry, (250, 250, 252, 255), seed=seed + cx)
        # a flatter, slightly grey underside reads as bulk from above
        for cx, cy, rx, ry in lumps:
            patch(img, cx, cy + ry - 1, rx - 1, 1, (222, 226, 236, 255),
                  seed=seed + cx)
        frames.append(img)
    # both frames share a canvas so they can live in one AtlasTexture
    save(sheet(frames), "prop_cloud")


def gen_moon():
    """The moon as it appears reflected on the water, not as a sky object."""
    img = new_img(18, 18)
    for y in range(18):
        for x in range(18):
            dist = math.hypot(x - 8.5, y - 8.5)
            if dist <= 8.0:
                px(img, x, y, P.MOON)
            if 6.6 < dist <= 8.0:
                px(img, x, y, (196, 200, 214, 255))
    for cx, cy, r in ((6, 6, 2), (11, 9, 1), (8, 12, 1)):
        patch(img, cx, cy, r, r, (206, 210, 222, 255), seed=cx * 13)
    save(img, "prop_moon")


def gen_star():
    """Three twinkle frames of a single glint, 3x3 each."""
    frames = []
    for bright in (255, 190, 120):
        img = new_img(3, 3)
        px(img, 1, 1, (P.STAR[0], P.STAR[1], P.STAR[2], bright))
        for x, y in ((0, 1), (2, 1), (1, 0), (1, 2)):
            px(img, x, y, (P.STAR[0], P.STAR[1], P.STAR[2], bright // 3))
        frames.append(img)
    save(sheet(frames), "prop_star")


def gen_harbor_furniture():
    """Small pieces that make the quay feel operated, not decorated."""
    # Red fire point / hydrant, deliberately bright enough to remain legible
    # on the concrete after the day/night tint.
    hydrant = new_img(8, 8)
    rect(hydrant, 2, 2, 4, 5, (176, 50, 42, 255))
    hline(hydrant, 1, 2, 6, (236, 104, 72, 255))
    rect(hydrant, 3, 0, 2, 3, (214, 76, 54, 255))
    px(hydrant, 3, 1, (255, 160, 104, 255))
    save(outline(hydrant), "prop_hydrant")

    # Lifebuoy cabinet on the quay. The white centre keeps it distinct from
    # the red channel buoys in the water.
    lifebuoy = new_img(10, 10)
    for y in range(10):
        for x in range(10):
            d = math.hypot(x - 4.5, y - 4.5)
            if 2.3 <= d <= 4.2:
                img_color = (230, 92, 54, 255) if (x + y) % 4 < 2 \
                    else (244, 224, 190, 255)
                px(lifebuoy, x, y, img_color)
    save(outline(lifebuoy), "prop_lifebuoy")

    # Palletised spare parts and a cable reel for the workshop apron.
    pallet = new_img(14, 10)
    rect(pallet, 1, 2, 12, 7, (124, 82, 50, 255))
    for y in (2, 5, 8):
        hline(pallet, 1, y, 12, (188, 132, 76, 255))
    for x in (2, 7, 12):
        vline(pallet, x, 2, 7, (92, 62, 46, 255))
    rect(pallet, 3, 3, 4, 3, (78, 112, 126, 255))
    rect(pallet, 8, 3, 3, 4, (154, 92, 56, 255))
    save(outline(pallet), "prop_pallet")

    reel = new_img(12, 12)
    for y in range(12):
        for x in range(12):
            d = math.hypot(x - 5.5, y - 5.5)
            if d <= 5:
                px(reel, x, y, (126, 86, 58, 255))
            if 2.1 <= d <= 3.5:
                px(reel, x, y, (48, 52, 58, 255))
    rect(reel, 5, 4, 2, 4, (196, 142, 82, 255))
    save(outline(reel), "prop_cable_reel")


def gen_rope():
    """A tileable mooring rope, drawn along its length.

    `Line2D` tiles this over the whole span, so the twist has to close at the
    seam or the rope reads as a dashed line. Six pixels wide and three body rows
    is exactly one turn of the spiral: the lit strand steps down a row every two
    pixels and wraps at the tile edge.
    """
    W, H = 6, 4
    # Tarred mooring rope, not hemp: a working ship's lines are near black, and
    # the pale hemp read as spaghetti draped over the quay.
    hemp_l = (96, 86, 78, 255)
    hemp = (68, 60, 56, 255)
    hemp_d = (44, 38, 36, 255)
    img = new_img(W, H)
    for x in range(W):
        px(img, x, 0, P.OUTLINE)
        px(img, x, 3, P.OUTLINE)
        # Two body rows and a half-tile stagger: at three pixels thick the twist
        # has to be suggested, not drawn, or it turns into stripes.
        lit = 1 if (x % 4) < 2 else 2
        px(img, x, 1, hemp_l if lit == 1 else hemp)
        px(img, x, 2, hemp_d if lit == 1 else hemp)
    save(img, "prop_rope", preview_scale=12)


def gen_rope_knot():
    """The eye splice that drops over a bollard."""
    hemp_l = (96, 86, 78, 255)
    hemp = (68, 60, 56, 255)
    hemp_d = (44, 38, 36, 255)
    img = new_img(7, 7)
    ring = [(2, 1), (3, 1), (4, 1), (5, 2), (5, 3), (5, 4),
            (4, 5), (3, 5), (2, 5), (1, 4), (1, 3), (1, 2)]
    for index, point in enumerate(ring):
        # Light on the upper-left of the loop, shade on the lower-right, so the
        # eye reads as rope lying over something rather than as a drawn ring.
        shade = hemp_l if index < 4 else (hemp if index < 8 else hemp_d)
        px(img, point[0], point[1], shade)
    rect(img, 3, 3, 2, 2, (52, 40, 34, 255))
    save(outline(img), "prop_rope_knot", preview_scale=12)


def gen_clock_face():
    """The sky itself, painted round a disc, so the clock shows the day turning.

    A hand sweeping a flat dial tells you the time; a window onto the sky tells
    you what the port *looks* like right now without reading anything. The disc
    is painted with noon at the top and midnight at the bottom, and the view
    rotates it so the current hour is always under the fixed pointer.
    """
    import math
    # Sized for the gantry: the dial is one instrument on a 44px bar beside the
    # tally, not a wall clock. Everything below is measured off R so the disc can
    # be resized without redrawing the sky by hand.
    R = 12
    SIZE = R * 2
    img = new_img(SIZE, SIZE)
    cx = cy = R - 0.5

    # Sky, hour by hour round the rim. The bands are the same ones
    # `TimeManager` uses, so the picture and the clock agree.
    def sky(f):
        if 0.30 <= f < 0.70:
            return ((124, 196, 236, 255), (168, 218, 246, 255))      # day
        if 0.22 <= f < 0.30:
            return ((214, 150, 122, 255), (240, 190, 146, 255))      # dawn
        if 0.70 <= f < 0.80:
            return ((206, 124, 104, 255), (236, 168, 118, 255))      # dusk
        return ((26, 32, 66, 255), (44, 52, 96, 255))                # night

    for y in range(SIZE):
        for x in range(SIZE):
            dx = x - cx
            dy = y - cy
            dist = math.hypot(dx, dy)
            if dist > R - 0.5:
                continue
            # Angle measured *counter*-clockwise from straight up, as a day
            # fraction with noon at the top. Counter-clockwise so that as the
            # disc turns the sun rises on the left and sets on the right, the way
            # it does in the sky rather than the other way round.
            ang = math.atan2(-dx, -dy)
            f = (0.5 + ang / (2.0 * math.pi)) % 1.0
            deep, high = sky(f)
            # Lighter towards the rim so the disc reads as a dome rather than a
            # flat wheel.
            px(img, x, y, high if dist > R * 0.58 else deep)

    def blob(bx, by, r, core, edge):
        for yy in range(SIZE):
            for xx in range(SIZE):
                d = math.hypot(xx - bx, yy - by)
                if d <= r:
                    px(img, xx, yy, core if d <= r - 1.2 else edge)

    # The sun rides at the top of the disc, the moon at the bottom.
    blob(cx, cy - R * 0.60, R * 0.21, (255, 236, 150, 255), (250, 206, 96, 255))
    for a in range(0, 360, 60):
        px(img, int(round(cx + math.cos(math.radians(a)) * R * 0.36)),
           int(round(cy - R * 0.60 + math.sin(math.radians(a)) * R * 0.36)),
           (252, 220, 120, 255))
    blob(cx, cy + R * 0.60, R * 0.18, (238, 242, 252, 255), (198, 206, 232, 255))
    # A bite out of the moon makes it a crescent rather than a pale sun.
    blob(cx + R * 0.14, cy + R * 0.60 - R * 0.09, R * 0.15,
         (30, 36, 72, 255), (30, 36, 72, 255))
    # Stars, only on the night side.
    for sx, sy in ((-0.39, 0.50), (0.33, 0.61), (-0.17, 0.72),
                   (0.50, 0.33), (-0.55, 0.28), (0.11, 0.83)):
        if math.hypot(sx, sy) * R < R - 1.8:
            px(img, int(round(cx + sx * R)), int(round(cy + sy * R)),
               (226, 232, 250, 255))
    save(img, "prop_clock_face", preview_scale=8)


def gen_clock_bezel():
    """The brass porthole the sky turns behind, with the pointer at the top.

    Brass on navy enamel is the one warm thing on the gantry, which is what
    makes the dial read as an instrument someone screwed on rather than another
    panel. The ring carries a tick at every third hour, a screw at the quarters,
    and a diagonal sheen across the glass so the sky behind it looks covered.
    """
    import math
    R = 14
    SIZE = R * 2 + 2          # a pixel of air all round, so the outline fits
    img = new_img(SIZE, SIZE)
    cx = cy = R
    brass = (196, 152, 74, 255)
    brass_l = (232, 196, 116, 255)
    brass_d = (140, 100, 48, 255)
    brass_xd = (94, 66, 30, 255)
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot(x - cx, y - cy)
            if d > R - 0.5 or d < R - 3.6:
                continue
            # Lit from the upper left like everything else in the game.
            if (x - cx) + (y - cy) < -2.0:
                px(img, x, y, brass_l)
            elif (x - cx) + (y - cy) > 2.0:
                px(img, x, y, brass_d)
            else:
                px(img, x, y, brass)

    # Every third hour gets a tick cut into the ring: enough rhythm to read the
    # disc as a 24-hour face, few enough that it stays a picture of the sky.
    for hour in range(0, 24, 3):
        a = math.radians(hour * 15.0 - 90.0)
        px(img, int(round(cx + math.cos(a) * (R - 3.0))),
           int(round(cy + math.sin(a) * (R - 3.0))), brass_xd)
    for a in (45, 135, 225, 315):
        sx = int(round(cx + math.cos(math.radians(a)) * (R - 1.8)))
        sy = int(round(cy + math.sin(math.radians(a)) * (R - 1.8)))
        px(img, sx, sy, brass_xd)
        px(img, sx, sy - 1, brass_l)

    # The pointer at noon: a wedge biting into the ring, so the hour under it is
    # unmistakable.
    for i in range(4):
        rect(img, int(cx) - i // 2, int(cy) - R + 1 + i, 1 + (i // 2) * 2, 1,
             (250, 236, 200, 255))
    px(img, int(cx), int(cy) - R + 5, brass_xd)

    ringed = outline(img)
    # The glass: one diagonal sheen across the upper left, kept faint so the sun
    # and the moon still read through it. Drawn *after* the outline pass, which
    # treats any non-zero alpha as solid and would otherwise trace a dark rim
    # around the streak.
    for step in range(-R * 2, R * 2):
        gx = int(cx + step * 0.5) - 3
        gy = int(cy - step * 0.5) - 3
        for run in range(2):
            if math.hypot(gx + run - cx, gy + run - cy) < R - 4.5:
                px(ringed, gx + run, gy + run, (208, 232, 244, 38))
    save(ringed, "prop_clock_bezel", preview_scale=8)


def gen_windsock():
    """A windsock on its pole, in three degrees of fill.

    The port's own instrument: the sock is limp in calm air, half up in a
    breeze, and streaming straight out when it blows. Drawn pointing right; the
    view flips it for the other wind direction.
    """
    FW, FH = 20, 14
    frames = []
    for step, lift in enumerate((0, 3, 5)):
        img = new_img(FW, FH)
        # the mast, and the hoop the sock is laced to
        vline(img, 3, 2, 11, P.STEEL_D)
        px(img, 3, 2, P.STEEL_L)
        rect(img, 2, 12, 4, 2, P.STEEL_D)
        vline(img, 5, 3, 5, P.STEEL)
        # the sock: bands of orange and white, narrowing as it streams
        length = 6 + step * 5
        for i in range(length):
            x = 6 + i
            half = max(1, 3 - i // 3)
            y = 5 - lift + (i * lift) // max(1, length)
            band = P.SAFETY if (i // 2) % 2 == 0 else (240, 236, 226, 255)
            rect(img, x, y - half + 1, 1, half * 2, band)
        frames.append(outline(img))
    save(sheet(frames), "prop_windsock")


# --------------------------------------------------------------- decorations
# Bought in the shop's ENFEITES tab and switched on and off from there. They are
# scenery with no rule attached, which is exactly why they are worth drawing
# well: the only reason to own one is that the terminal looks better with it.

## The eight liveries a bunting flag can be cut from. Bright, and deliberately
## the container palette rather than a new one — a party in this port is a party
## made of the things this port has.
BUNTING = [
    (226, 92, 74, 255), (238, 176, 62, 255), (104, 194, 176, 255),
    (92, 148, 88, 255), (142, 96, 138, 255), (72, 116, 172, 255),
    (250, 240, 218, 255), (232, 138, 112, 255),
]


def gen_bunting():
    """A run of pennant flags on a line, 64x14, tiling in X.

    Drawn as one span between two masts and repeated along the quay, so the
    line has to leave and enter the sprite at the same height or every joint in
    the yard shows. The flags hang below it: from above you see the string, the
    top edge of each triangle and the shadow it drops on the concrete.
    """
    w, h = 64, 14
    img = new_img(w, h)
    for x in range(w):
        # The line sags between the masts, and the flags sag with it.
        sag = int(2.0 * math.sin(math.pi * x / (w - 1)))
        px(img, x, 2 + sag, (46, 38, 42, 255))
        px(img, x, 3 + sag, (86, 74, 76, 255))
    for index, start in enumerate(range(1, w - 6, 8)):
        colour = BUNTING[index % len(BUNTING)]
        shade = tuple(int(c * 0.72) for c in colour[:3]) + (255,)
        sag = int(2.0 * math.sin(math.pi * (start + 3) / (w - 1)))
        for row in range(5):
            half = 3 - row // 2
            if half <= 0:
                continue
            span = half * 2
            left = start + 3 - half
            hline(img, left, 4 + sag + row, span, colour)
            px(img, left + span - 1, 4 + sag + row, shade)
        # The shadow on the apron, one pixel down and to the right of the flag.
        px(img, start + 3, 10 + sag, (40, 36, 44, 70))
    save(img, "prop_bunting")


def gen_planter():
    """A concrete planter with something growing out of it, 16x14.

    The apron of a real terminal is grey from the kerb to the water, and a row
    of these along it is the cheapest thing that says somebody works here and
    cares. Three flower heads, because two reads as eyes.
    """
    img = new_img(16, 14)
    rect(img, 1, 3, 14, 10, P.QUAY_D)
    rect(img, 2, 4, 12, 8, P.QUAY)
    hline(img, 2, 4, 12, P.QUAY_L)
    hline(img, 2, 11, 12, P.QUAY_D)
    # Soil, then planting.
    rect(img, 3, 5, 10, 6, (78, 58, 44, 255))
    speckle(img, 3, 5, 10, 6, [(96, 72, 54, 255)], 0.3, seed=41)
    for cx, cy in ((5, 7), (10, 6), (8, 9)):
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                if abs(dx) + abs(dy) <= 1:
                    px(img, cx + dx, cy + dy, P.BUSH)
        px(img, cx, cy - 1, P.BUSH_L)
    for cx, cy, tone in ((5, 6, (240, 118, 126, 255)),
                         (10, 5, (250, 216, 122, 255)),
                         (8, 8, (226, 158, 226, 255))):
        px(img, cx, cy, tone)
        px(img, cx - 1, cy, tuple(int(c * 0.8) for c in tone[:3]) + (255,))
    save(outline(img), "prop_planter")


def gen_flag():
    """A pennant on a pole, three frames of the same wave."""
    FW, FH = 16, 16
    frames = []
    for step in range(3):
        img = new_img(FW, FH)
        vline(img, 2, 1, 14, P.WOOD_D)
        px(img, 2, 1, P.WOOD_L)
        for i in range(10):
            # A travelling wave rather than a flap: the crest moves along the
            # cloth instead of the whole flag jumping.
            import math
            wave = int(round(math.sin((i * 0.7) - step * 1.6) * 1.4))
            top = 2 + wave
            rect(img, 3 + i, top, 1, 6 - i // 4, P.TEAL)
            px(img, 3 + i, top, P.TEAL_L)
        frames.append(outline(img))
    save(sheet(frames), "prop_flag")


def gen_weather_glyphs():
    """Sun, moon, cloud, rain and fog for the port clock. 14x14 each."""
    FW = 14
    frames = []

    sun = new_img(FW, FW)
    for a in range(0, 360, 45):
        import math
        x = int(7 + math.cos(math.radians(a)) * 5)
        y = int(7 + math.sin(math.radians(a)) * 5)
        px(sun, x, y, P.SAFETY_L)
    patch(sun, 7, 7, 3, 3, P.SAFETY, seed=1)
    patch(sun, 6, 6, 2, 2, P.SAFETY_L, seed=2)
    frames.append(outline(sun))

    def disc(img, cx, cy, r, color):
        for y in range(FW):
            for x in range(FW):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    px(img, x, y, color)

    def cut(img, cx, cy, r):
        for y in range(FW):
            for x in range(FW):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    px(img, x, y, P.TRANSPARENT)

    # A crescent is a disc with a second disc taken out of it. The blob helper
    # made a shape that read as a bird.
    moon = new_img(FW, FW)
    disc(moon, 7, 7, 5, (226, 230, 244, 255))
    disc(moon, 6, 6, 4, (240, 243, 252, 255))
    cut(moon, 10, 5, 5)
    px(moon, 5, 9, (196, 202, 220, 255))
    px(moon, 4, 6, (196, 202, 220, 255))
    frames.append(outline(moon))

    # Three puffs on a flat base, which is what makes a cloud a cloud.
    cloud = new_img(FW, FW)
    disc(cloud, 5, 8, 3, (214, 220, 232, 255))
    disc(cloud, 9, 8, 3, (214, 220, 232, 255))
    disc(cloud, 7, 6, 3, (232, 238, 248, 255))
    rect(cloud, 2, 8, 10, 3, (214, 220, 232, 255))
    rect(cloud, 3, 5, 3, 2, (240, 244, 250, 255))
    frames.append(outline(cloud))

    rain = new_img(FW, FW)
    disc(rain, 5, 6, 3, (188, 196, 212, 255))
    disc(rain, 9, 6, 3, (188, 196, 212, 255))
    rect(rain, 2, 6, 10, 3, (188, 196, 212, 255))
    rect(rain, 3, 4, 3, 2, (214, 220, 232, 255))
    for index, x in enumerate((4, 7, 10)):
        vline(rain, x, 10 + (index % 2), 3, (150, 196, 224, 255))
    frames.append(outline(rain))

    fog = new_img(FW, FW)
    for i, y in enumerate((4, 6, 8, 10)):
        rect(fog, 2 + (i % 2), y, 9 - (i % 2) * 2, 1, (206, 212, 220, 255))
    frames.append(outline(fog))

    save(sheet(frames), "ui_weather")


if __name__ == "__main__":
    print("props:")
    gen_clock_face()
    gen_clock_bezel()
    gen_windsock()
    gen_flag()
    gen_bunting()
    gen_planter()
    gen_weather_glyphs()
    gen_rope()
    gen_rope_knot()
    gen_lamp()
    gen_glow()
    gen_bollard()
    gen_cone()
    gen_tree()
    gen_bush()
    gen_puddle()
    gen_seagull()
    gen_cat()
    gen_dust()
    gen_exhaust()
    gen_splash()
    gen_shadow_blob()
    gen_buoy()
    gen_cloud()
    gen_moon()
    gen_star()
    gen_harbor_furniture()
