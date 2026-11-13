"""Minigame art: the late-lorry road (`traffic_minigame.gd`) and the cover
picture every minigame shows where it is offered (`ui_minigame_art`).

Road sprites face UP (the rig drives north).

Road sprites are drawn at the size the board shows them (two screen pixels
per road pixel), so their detail is real pixels, not doubled ones.

- mg_rig        28x64  the player's cab and reefer box.
- mg_cars       4 frames 22x40: red hatch, blue saloon, taxi, green van.
- mg_bus        26x80.
- mg_moto       12x24.
- mg_items      5 frames 28x24: cone, pothole, oil, coffee, clock.
- mg_roadside   4 frames 44x44: tree, lamp post, flower bed, kiosk.
- mg_roofs      3 frames 56x72: the blocks either side of the avenue.
- ui_minigame_art 4 frames 112x56: stack, maze, traffic, xray covers.
"""
import math

import palette as P
from common import new_img, rect, hline, vline, px, outline, save, sheet, speckle

INK = (40, 34, 44, 255)
GLINT = (214, 242, 248, 255)
CHROME = (206, 212, 220, 255)
ASPH = (70, 66, 76, 255)
ASPH_L = (88, 84, 94, 255)
LINE = (236, 226, 196, 255)
TAXI = ((196, 150, 30, 255), (240, 196, 54, 255), (255, 228, 120, 255))
RED = ((150, 40, 40, 255), (200, 64, 56, 255), (236, 112, 96, 255))
BLUE = ((42, 70, 124, 255), (64, 108, 170, 255), (108, 150, 206, 255))
GREEN = ((46, 104, 64, 255), (72, 150, 96, 255), (120, 196, 138, 255))
WHITE = ((176, 172, 166, 255), (226, 222, 212, 255), (250, 248, 240, 255))
ORANGE = (244, 132, 40, 255)


def body(img, x, y, w, h, ramp):
    d, m, l = ramp
    rect(img, x, y, w, h, m)
    hline(img, x, y, w, l)
    vline(img, x, y, h, l)
    hline(img, x, y + h - 1, w, d)
    vline(img, x + w - 1, y, h, d)


def glass(img, x, y, w, h):
    rect(img, x, y, w, h, P.GLASS)
    hline(img, x, y, w, P.GLASS_D)
    px(img, x + w - 2, y + 1, GLINT)


def wheels(img, x0, x1, ys, h=4):
    for y in ys:
        rect(img, x0, y, 1, h, P.TIRE)
        rect(img, x1, y, 1, h, P.TIRE)


# --- road sprites ---------------------------------------------------------------
# Drawn at the size the board shows them (2 screen px per road px), so the
# detail is real pixels rather than doubled ones.


def shape(img, x, y, w, h, color, cut=2):
    """A rounded box: the corners clipped by `cut` pixels on a diagonal."""
    for j in range(h):
        inset = 0
        if j < cut:
            inset = cut - j
        elif j >= h - cut:
            inset = j - (h - cut - 1)
        hline(img, x + inset, y + j, w - 2 * inset, color)


def car_body(img, w, h, r, glass_rows, roof_rows, taxi=False, van=False):
    """A car from above. `r` is a 5-step ramp, dark to light."""
    # wheels peeking out at the arches
    for wy in (int(h * 0.16), int(h * 0.68)):
        rect(img, 0, wy, 2, 7, P.TIRE)
        rect(img, w - 2, wy, 2, 7, P.TIRE)
    shape(img, 1, 0, w - 2, h, r[1], 3)
    shape(img, 2, 1, w - 4, h - 2, r[2], 3)
    # bonnet crease and the light down its left side
    vline(img, w // 2, 4, glass_rows[0] - 5, r[3])
    vline(img, 3, 4, h - 8, r[3])
    vline(img, w - 4, 4, h - 8, r[1])
    # windscreen: dark top edge, sky in the glass, one glint
    g0, g1 = glass_rows
    for j in range(g0, g1):
        t = (j - g0) / max(1, g1 - g0 - 1)
        c = P.mix(P.GLASS_D, P.GLASS, t)
        inset = 3 + (g1 - j) // 3
        hline(img, inset, j, w - 2 * inset, c)
    px(img, w - 7, g0 + 1, GLINT)
    px(img, w - 8, g0 + 2, GLINT)
    # roof
    r0, r1 = roof_rows
    rect(img, 4, r0, w - 8, r1 - r0, r[3] if not van else r[2])
    hline(img, 4, r0, w - 8, r[4])
    vline(img, 4, r0, r1 - r0, r[4])
    if van:
        for j in range(r0 + 3, r1 - 1, 3):
            hline(img, 5, j, w - 10, r[1])
    # rear window
    if not van:
        for j in range(r1, r1 + 4):
            inset = 4 + (j - r1) // 2
            hline(img, inset, j, w - 2 * inset, P.GLASS_D)
    # mirrors
    px(img, 0, g0 + 1, r[1])
    px(img, w - 1, g0 + 1, r[1])
    # lamps
    rect(img, 3, 1, 3, 2, P.WINDOW_LIT)
    rect(img, w - 6, 1, 3, 2, P.WINDOW_LIT)
    px(img, 4, 1, (255, 250, 220, 255))
    rect(img, 3, h - 2, 3, 1, P.RED_LIGHT)
    rect(img, w - 6, h - 2, 3, 1, P.RED_LIGHT)
    hline(img, 6, h - 1, w - 12, P.STEEL_D)  # rear bumper
    if taxi:
        rect(img, w // 2 - 3, r0 + 3, 6, 3, INK)
        hline(img, w // 2 - 2, r0 + 4, 4, P.WINDOW_LIT)
        for x in range(4, w - 4, 2):
            px(img, x, r1 - 1, INK if (x // 2) % 2 else LINE)


def car(base, taxi=False, van=False):
    w, h = 22, 40
    img = new_img(w, h)
    r = P.ramp(base, 5)
    car_body(img, w, h, r, (11, 17) if not van else (6, 11),
             (17, 27) if not van else (11, 36), taxi, van)
    return outline(img)


def gen_cars():
    save(sheet([car((200, 64, 56)), car((64, 108, 170)), car((240, 196, 54), taxi=True),
                car((72, 150, 96), van=True)]), "mg_cars")


def gen_rig():
    w, h = 28, 64
    img = new_img(w, h)
    red = P.ramp((200, 64, 56), 5)
    white = P.ramp((226, 222, 212), 5, dark=0.3, light=0.4)
    # wheels: steer axle, then the trailer's tandem at the back
    for wy in (4, 46, 54):
        rect(img, 0, wy, 2, 7, P.TIRE)
        rect(img, w - 2, wy, 2, 7, P.TIRE)
    # cab
    shape(img, 2, 0, w - 4, 18, red[1], 3)
    shape(img, 3, 1, w - 6, 16, red[2], 2)
    rect(img, 5, 2, w - 10, 2, P.STEEL_L)  # grille
    for x in range(6, w - 6, 2):
        px(img, x, 3, INK)
    for j in range(5, 9):
        hline(img, 5, j, w - 10, P.mix(P.GLASS_D, P.GLASS, (j - 5) / 3))
    px(img, w - 8, 6, GLINT)
    px(img, w - 9, 7, GLINT)
    rect(img, 5, 9, w - 10, 7, red[3])  # sleeper roof
    hline(img, 5, 9, w - 10, red[4])
    rect(img, 8, 11, w - 16, 3, red[1])  # wind deflector
    for x in (6, 10, 14, 18, 21):
        px(img, x, 9, (255, 190, 80, 255))  # roof marker lamps
    px(img, 0, 6, P.STEEL_L)
    px(img, w - 1, 6, P.STEEL_L)
    rect(img, 4, 0, 4, 2, P.WINDOW_LIT)
    rect(img, w - 8, 0, 4, 2, P.WINDOW_LIT)
    rect(img, 4, 16, 2, 3, P.STEEL)  # exhaust stacks
    rect(img, w - 6, 16, 2, 3, P.STEEL)
    # the reefer box
    rect(img, 1, 19, w - 2, h - 20, white[1])
    rect(img, 2, 20, w - 4, h - 22, white[2])
    rect(img, 6, 20, w - 12, 5, P.STEEL)  # fridge unit
    hline(img, 6, 20, w - 12, P.STEEL_L)
    for x in range(8, w - 8, 2):
        vline(img, x, 21, 3, INK)
    for j in range(27, h - 3, 3):
        hline(img, 3, j, w - 6, white[3])
        hline(img, 3, j + 1, w - 6, white[1])
    vline(img, 2, 20, h - 22, white[4])
    rect(img, 6, 34, w - 12, 10, P.ramp((64, 156, 160), 5)[2])  # livery stripe
    hline(img, 6, 34, w - 12, P.ramp((64, 156, 160), 5)[4])
    for y in range(26, h - 4, 8):
        px(img, 1, y, (255, 170, 60, 255))
        px(img, w - 2, y, (255, 170, 60, 255))
    rect(img, 3, h - 2, 4, 2, P.RED_LIGHT)
    rect(img, w - 7, h - 2, 4, 2, P.RED_LIGHT)
    hline(img, 8, h - 1, w - 16, P.STEEL_D)
    save(outline(img), "mg_rig")


def gen_bus():
    w, h = 26, 80
    img = new_img(w, h)
    r = P.ramp((64, 156, 160), 5)
    for wy in (8, 60):
        rect(img, 0, wy, 2, 8, P.TIRE)
        rect(img, w - 2, wy, 2, 8, P.TIRE)
    shape(img, 1, 0, w - 2, h, r[1], 3)
    shape(img, 2, 1, w - 4, h - 2, r[3], 2)
    for j in range(2, 7):
        hline(img, 4, j, w - 8, P.mix(P.GLASS_D, P.GLASS, (j - 2) / 4))
    px(img, w - 7, 3, GLINT)
    rect(img, 6, 8, w - 12, 3, INK)  # destination board
    hline(img, 7, 9, w - 14, P.WINDOW_LIT)
    # side windows along both flanks
    for y in range(13, h - 6, 6):
        rect(img, 2, y, 2, 4, P.GLASS)
        rect(img, w - 4, y, 2, 4, P.GLASS)
    # roof furniture: two hatches and the air conditioner pod
    rect(img, 8, 16, w - 16, 5, r[2])
    rect(img, 7, 30, w - 14, 14, P.STEEL_L)
    rect(img, 8, 31, w - 16, 12, P.STEEL)
    for y in range(32, 43, 2):
        hline(img, 9, y, w - 18, P.STEEL_D)
    rect(img, 8, 52, w - 16, 5, r[2])
    hline(img, 4, h - 6, w - 8, r[0])
    rect(img, 3, h - 2, 3, 2, P.RED_LIGHT)
    rect(img, w - 6, h - 2, 3, 2, P.RED_LIGHT)
    rect(img, 3, 0, 3, 2, P.WINDOW_LIT)
    rect(img, w - 6, 0, 3, 2, P.WINDOW_LIT)
    save(outline(img), "mg_bus")


def gen_moto():
    w, h = 12, 24
    img = new_img(w, h)
    rect(img, 5, 0, 2, 5, P.TIRE)
    rect(img, 5, 19, 2, 5, P.TIRE)
    rect(img, 4, 5, 4, 14, P.ramp((64, 108, 170), 5)[2])
    hline(img, 1, 6, 10, CHROME)  # handlebar
    px(img, 0, 6, INK)
    px(img, 11, 6, INK)
    rect(img, 2, 8, 8, 6, (54, 62, 92, 255))  # rider's shoulders
    rect(img, 3, 7, 6, 6, (240, 196, 66, 255))  # helmet
    hline(img, 4, 7, 4, (255, 228, 120, 255))
    hline(img, 4, 12, 4, (196, 152, 40, 255))
    rect(img, 4, 15, 4, 4, INK)
    px(img, 5, 23, P.RED_LIGHT)
    px(img, 5, 0, P.WINDOW_LIT)
    save(outline(img), "mg_moto")


def ellipse(img, cx, cy, rx, ry, color):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                px(img, x, y, color)


def gen_items():
    fw, fh = 28, 24
    frames = []
    # cone, with its rubber base and two reflective bands
    img = new_img(fw, fh)
    rect(img, 7, 18, 14, 4, (60, 52, 58, 255))
    hline(img, 7, 18, 14, (90, 82, 88, 255))
    for j in range(2, 18):
        half = 1 + j // 3
        hline(img, 14 - half, j, half * 2, ORANGE if j not in (7, 8, 12, 13) else LINE)
        px(img, 14 - half, j, (255, 176, 90, 255) if j not in (7, 8, 12, 13) else (255, 255, 240, 255))
    frames.append(outline(img))
    # pothole: a broken rim, depth, cracks running off it
    img = new_img(fw, fh)
    ellipse(img, 14, 12, 12, 8, (104, 98, 108, 255))
    ellipse(img, 14, 12, 10, 6.5, (52, 48, 58, 255))
    ellipse(img, 14, 13, 8, 4.5, (32, 28, 38, 255))
    ellipse(img, 12, 14, 3, 1.5, (60, 90, 120, 255))  # a puddle in it
    for (x, y) in ((2, 6), (1, 5), (0, 4), (25, 16), (26, 17), (27, 18), (20, 3), (21, 2)):
        px(img, x, y, (40, 36, 44, 255))
    frames.append(img)
    # oil slick, shimmering
    img = new_img(fw, fh)
    for y in range(fh):
        for x in range(fw):
            r = ((x - 14) / 13.0) ** 2 + ((y - 12) / 10.0) ** 2
            wob = 0.18 * math.sin(x * 0.9 + y * 0.6)
            if r <= 0.85 + wob:
                px(img, x, y, (24, 20, 32, 255))
    for i, c in enumerate(((150, 90, 220, 255), (80, 190, 210, 255), (220, 200, 90, 255),
                           (120, 210, 120, 255))):
        for k in range(5):
            px(img, 6 + i * 4 + k // 2, 7 + k + i % 2 * 4, c)
    frames.append(img)
    # coffee: lidded takeaway cup with its sleeve, steam curling off
    img = new_img(fw, fh)
    rect(img, 9, 7, 10, 15, LINE)
    vline(img, 9, 7, 15, (255, 255, 248, 255))
    vline(img, 18, 7, 15, (200, 192, 170, 255))
    rect(img, 9, 11, 10, 6, (150, 96, 56, 255))
    hline(img, 9, 11, 10, (186, 126, 80, 255))
    rect(img, 8, 5, 12, 3, (70, 50, 40, 255))
    hline(img, 8, 5, 12, (110, 80, 62, 255))
    for (x, y) in ((11, 3), (12, 2), (11, 1), (16, 3), (15, 2), (16, 1), (16, 0)):
        px(img, x, y, (230, 230, 240, 255))
    frames.append(outline(img))
    # alarm clock with its two bells
    img = new_img(fw, fh)
    ellipse(img, 9, 4, 3, 3, (220, 60, 50, 255))
    ellipse(img, 19, 4, 3, 3, (220, 60, 50, 255))
    ellipse(img, 14, 13, 9, 9, (220, 60, 50, 255))
    ellipse(img, 14, 13, 7, 7, LINE)
    for a in range(0, 360, 30):
        px(img, int(14 + 6 * math.cos(math.radians(a))), int(13 + 6 * math.sin(math.radians(a))), INK)
    vline(img, 14, 8, 6, INK)
    hline(img, 14, 13, 4, INK)
    rect(img, 9, 21, 2, 2, INK)
    rect(img, 17, 21, 2, 2, INK)
    frames.append(outline(img))
    save(sheet(frames), "mg_items")


def gen_roadside():
    fw = fh = 44
    frames = []
    # street tree: a canopy of clusters, lit from the north-west
    img = new_img(fw, fh)
    for (cx, cy, r) in ((22, 22, 19), (14, 16, 10), (29, 15, 10), (16, 29, 10), (30, 29, 10)):
        ellipse(img, cx, cy, r, r, P.TREE_D)
    for (cx, cy, r) in ((20, 19, 14), (13, 15, 7), (27, 14, 7), (15, 27, 7)):
        ellipse(img, cx, cy, r, r, P.TREE)
    for (cx, cy, r) in ((16, 14, 6), (25, 12, 4), (12, 22, 4)):
        ellipse(img, cx, cy, r, r, P.TREE_L)
    speckle(img, 6, 6, 32, 32, [P.TREE_D], density=0.06, seed=7)
    frames.append(outline(img))
    # lamp post head and arm, lamp lit
    img = new_img(fw, fh)
    ellipse(img, 10, 22, 4, 4, P.STEEL_D)
    rect(img, 12, 21, 22, 3, P.STEEL)
    hline(img, 12, 21, 22, P.STEEL_L)
    rect(img, 32, 19, 8, 7, P.STEEL_D)
    rect(img, 33, 20, 6, 5, P.WINDOW_LIT)
    px(img, 34, 21, (255, 250, 220, 255))
    frames.append(outline(img))
    # flower bed
    img = new_img(fw, fh)
    rect(img, 4, 10, 36, 26, (120, 100, 80, 255))
    rect(img, 6, 12, 32, 22, P.DIRT)
    for (cx, cy) in ((12, 18), (22, 16), (32, 19), (16, 28), (28, 28)):
        ellipse(img, cx, cy, 5, 4, P.GRASS)
        px(img, cx, cy - 1, (236, 120, 150, 255))
        px(img, cx + 2, cy + 1, (250, 220, 90, 255))
        px(img, cx - 2, cy + 1, (240, 240, 250, 255))
    frames.append(outline(img))
    # news kiosk under a striped awning
    img = new_img(fw, fh)
    for x in range(4, 40):
        vline(img, x, 8, 22, ORANGE if (x // 4) % 2 == 0 else LINE)
    for x in range(4, 40, 4):
        px(img, x + 1, 30, ORANGE if (x // 4) % 2 == 0 else LINE)
    hline(img, 4, 8, 36, (255, 190, 120, 255))
    rect(img, 8, 32, 28, 6, (64, 108, 170, 255))
    for x in range(10, 34, 5):
        rect(img, x, 33, 3, 4, LINE)
    frames.append(outline(img))
    save(sheet(frames), "mg_roadside")


def gen_roofs():
    """Rooftops for the blocks either side of the avenue, 56x72 each."""
    fw, fh = 56, 72
    frames = []
    for i, base in enumerate(((168, 112, 92), (132, 142, 160), (190, 170, 130))):
        img = new_img(fw, fh)
        r = P.ramp(base, 5)
        rect(img, 0, 0, fw, fh, r[1])
        rect(img, 2, 2, fw - 4, fh - 4, r[2])
        hline(img, 2, 2, fw - 4, r[4])
        vline(img, 2, 2, fh - 4, r[3])
        # roof furniture: a water tank, AC units, a skylight
        ellipse(img, 16 + i * 6, 18, 7, 7, P.STEEL_D)
        ellipse(img, 16 + i * 6, 17, 6, 6, P.STEEL)
        px(img, 14 + i * 6, 15, P.STEEL_L)
        for k in range(2):
            rect(img, 30, 34 + k * 12, 14, 8, P.STEEL_L)
            rect(img, 31, 35 + k * 12, 12, 6, P.STEEL)
            ellipse(img, 37, 38 + k * 12, 2, 2, INK)
        rect(img, 8, 44, 14, 18, P.GLASS_D)
        for y in range(46, 62, 4):
            hline(img, 9, y, 12, P.GLASS)
        frames.append(outline(img))
    save(sheet(frames), "mg_roofs")


# --- cover art -----------------------------------------------------------------

W, H = 112, 56


def sky(img, top, bottom):
    for y in range(H):
        t = y / (H - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        hline(img, 0, y, W, c)


def container(img, x, y, w, h, name):
    r = P.CONTAINER_RAMPS[name]
    rect(img, x, y, w, h, r[2])
    hline(img, x, y, w, r[4])
    hline(img, x, y + h - 1, w, r[0])
    vline(img, x, y, h, r[0])
    vline(img, x + w - 1, y, h, r[0])
    for cx in range(x + 2, x + w - 1, 2):
        vline(img, cx, y + 1, h - 2, r[3] if (cx // 2) % 2 else r[1])


def frame_border(img):
    rect(img, 0, 0, W, 1, INK)
    rect(img, 0, H - 1, W, 1, INK)
    rect(img, 0, 0, 1, H, INK)
    rect(img, W - 1, 0, 1, H, INK)


def cover_stack():
    img = new_img(W, H)
    sky(img, (250, 176, 110), (120, 170, 200))
    rect(img, 0, 44, W, 12, P.QUAY)
    hline(img, 0, 44, W, P.QUAY_L)
    for x in range(0, W, 8):
        rect(img, x, 52, 4, 2, P.SAFETY if (x // 8) % 2 else INK)
    # the quay crane's legs and boom, red
    for lx in (14, 34):
        rect(img, lx, 8, 3, 36, P.CRANE)
        vline(img, lx, 8, 36, P.CRANE_L)
    rect(img, 6, 6, 92, 4, P.CRANE)
    hline(img, 6, 6, 92, P.CRANE_L)
    for x in range(8, 96, 5):
        px(img, x, 8, P.CRANE_D)
    # trolley and a box on the spreader
    rect(img, 60, 10, 12, 3, P.STEEL_D)
    vline(img, 62, 13, 6, INK)
    vline(img, 69, 13, 6, INK)
    rect(img, 58, 19, 16, 2, P.SAFETY)
    container(img, 58, 21, 16, 7, "amber")
    # a leaning tower
    names = ["blue", "rust", "green", "teal", "plum"]
    for i, n in enumerate(names):
        container(img, 54 + i * 2 - (1 if i == 4 else 0), 37 - i * 7, 18, 7, n)
    frame_border(img)
    return img


def cover_maze():
    img = new_img(W, H)
    rect(img, 0, 0, W, H, P.YARD)
    speckle(img, 0, 0, W, H, [P.YARD_D, P.YARD_L], density=0.08, seed=5)
    names = P.CONTAINER_NAMES
    k = 0
    for row in range(4):
        for col in range(6):
            if (row, col) in ((1, 2), (2, 4), (0, 5), (3, 1)):
                continue
            container(img, 4 + col * 18, 4 + row * 13, 14, 8, names[k % len(names)])
            k += 1
    # dashed route through the gaps, the tractor on it, the glowing lost box
    for x in range(4, 60, 3):
        px(img, x, 15, P.PAINT_Y)
    for y in range(15, 42, 3):
        px(img, 58, y, P.PAINT_Y)
    rect(img, 22, 12, 8, 6, P.SAFETY)
    rect(img, 27, 13, 2, 4, P.GLASS)
    for r in range(3):
        for a in range(0, 360, 30):
            x = int(96 + (7 + r) * math.cos(math.radians(a)))
            y = int(40 + (5 + r) * math.sin(math.radians(a)))
            px(img, x, y, (255, 236, 120, 255) if r < 2 else (255, 200, 80, 255))
    container(img, 90, 37, 14, 8, "amber")
    frame_border(img)
    return img


def cover_traffic():
    img = new_img(W, H)
    sky(img, (120, 176, 220), (196, 220, 236))
    # skyline
    for i, (x, w, h) in enumerate(((2, 12, 14), (16, 10, 20), (28, 14, 10), (44, 9, 24),
                                    (56, 16, 12), (74, 10, 18), (86, 14, 26), (102, 10, 12))):
        rect(img, x, 22 - h + 6, w, h, (110, 124, 150, 255) if i % 2 else (130, 142, 166, 255))
        for wy in range(22 - h + 8, 26, 4):
            for wx in range(x + 2, x + w - 1, 3):
                px(img, wx, wy, P.WINDOW_LIT if (wx + wy) % 5 else (90, 100, 124, 255))
    # the road, running across
    rect(img, 0, 28, W, 26, ASPH)
    hline(img, 0, 28, W, LINE)
    hline(img, 0, 53, W, LINE)
    for x in range(0, W, 10):
        hline(img, x, 36, 5, LINE)
        hline(img, x + 4, 45, 5, LINE)
    # the rig, facing right, and the traffic it is weaving through
    rect(img, 24, 39, 26, 8, WHITE[1])
    hline(img, 24, 39, 26, WHITE[2])
    rect(img, 50, 39, 10, 8, RED[1])
    rect(img, 56, 40, 3, 6, P.GLASS)
    for wx in (27, 44, 53):
        rect(img, wx, 47, 4, 2, P.TIRE)
    for (x, y, r) in ((70, 30, BLUE), (86, 47, TAXI), (100, 30, GREEN)):
        rect(img, x, y, 12, 6, r[1])
        rect(img, x + 8, y + 1, 2, 4, P.GLASS)
    rect(img, 68, 47, 4, 4, ORANGE)
    px(img, 69, 46, ORANGE)
    # speed lines behind the rig
    for y in (40, 43, 46):
        hline(img, 10 + (y % 3) * 2, y, 10, (150, 146, 156, 255))
    # the clock that says why
    for a in range(0, 360, 20):
        x = int(98 + 7 * math.cos(math.radians(a)))
        y = int(10 + 7 * math.sin(math.radians(a)))
        px(img, x, y, INK)
    rect(img, 92, 5, 12, 11, LINE)
    vline(img, 98, 6, 5, INK)
    hline(img, 98, 10, 4, (200, 60, 50, 255))
    frame_border(img)
    return img


def cover_xray():
    img = new_img(W, H)
    rect(img, 0, 0, W, H, (24, 36, 44, 255))
    for y in range(0, H, 4):
        hline(img, 0, y, W, (30, 48, 56, 255))
    # the scan screen: a lorry in green phosphor with a hidden pistol
    rect(img, 8, 8, 96, 40, (14, 40, 30, 255))
    rect(img, 8, 8, 96, 1, (90, 220, 150, 255))
    green = (90, 220, 150, 255)
    dim = (50, 140, 96, 255)
    rect(img, 18, 20, 56, 18, dim)
    rect(img, 76, 24, 16, 14, dim)
    for x in range(20, 72, 7):
        rect(img, x, 22, 5, 14, (40, 110, 76, 255))
    rect(img, 40, 27, 10, 3, green)
    rect(img, 47, 29, 2, 4, green)
    for wx in (24, 64, 84):
        rect(img, wx, 38, 6, 4, green)
    # beam sweeping
    vline(img, 60, 9, 38, (200, 255, 220, 255))
    vline(img, 61, 9, 38, (120, 240, 170, 255))
    rect(img, 86, 11, 14, 6, (200, 56, 48, 255))
    px(img, 88, 13, (255, 230, 220, 255))
    frame_border(img)
    return img


def gen_covers():
    save(sheet([cover_stack(), cover_maze(), cover_traffic(), cover_xray()]), "ui_minigame_art")


if __name__ == "__main__":
    gen_rig()
    gen_cars()
    gen_bus()
    gen_moto()
    gen_items()
    gen_roadside()
    gen_roofs()
    gen_covers()
