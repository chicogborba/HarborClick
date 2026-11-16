"""Decorations: the props new cosmetics put in the port, and the picture each
cosmetic shows on its shelf (`ui_decor_icons`, one 48x40 frame per item, in the
order of ART below; `CosmeticDb` names the frame with `art`).

World props (3/4 view, like prop_lamp):
- prop_palm        24x32
- prop_lighthouse  18x40
- prop_balloon     22x30
- prop_dolphin     2 frames 18x12 (rising, falling)
- prop_flagpole    5x22 (the flag is drawn from ui_flags in the game)
"""
import math
import os

from PIL import Image

import palette as P
from common import new_img, rect, hline, vline, px, outline, save, sheet, speckle, SPRITES_DIR

INK = (40, 34, 44, 255)
WHITE = (244, 240, 230, 255)
RED = (206, 64, 56, 255)
RED_D = (150, 40, 40, 255)

# Shelf order. Must match the `art` index on every CosmeticDb item.
ART = [
    "teal_hats", "pink_hats", "purple_hats", "white_hats", "rainbow_hats",
    "black_hats", "rgb_lamps", "bunting", "planters", "duck", "cats",
    "party_hats", "gold_hats", "palms", "lighthouse", "balloon", "dolphins",
    "flags", "fireworks", "neon_hats", "camo_hats",
]
HATS = {
    "teal_hats": (70, 196, 178), "pink_hats": (242, 127, 182),
    "purple_hats": (155, 108, 224), "white_hats": (244, 242, 234),
    "black_hats": (48, 48, 60), "gold_hats": (248, 206, 92),
    "neon_hats": (166, 255, 60), "camo_hats": (104, 120, 70),
}


def ellipse(img, cx, cy, rx, ry, color):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                px(img, x, y, color)


def load(name):
    return Image.open(os.path.join(SPRITES_DIR, name + ".png")).convert("RGBA")


# --- world props ---------------------------------------------------------------

def palm(img, ox, oy):
    # trunk, curved and ringed
    for j in range(14):
        x = ox + 11 + int(math.sin(j / 5.0) * 2)
        rect(img, x, oy + 17 + j, 3, 1, (150, 110, 70, 255) if j % 3 else (118, 84, 50, 255))
    # fronds radiating from the crown
    crown = (ox + 12, oy + 15)
    for a in range(0, 360, 45):
        for r in range(1, 12):
            x = int(crown[0] + r * math.cos(math.radians(a)))
            y = int(crown[1] + r * 0.7 * math.sin(math.radians(a)) + (r * r) / 30.0)
            px(img, x, y, P.TREE if r < 9 else P.TREE_D)
            px(img, x, y + 1, P.TREE_D)
    ellipse(img, crown[0], crown[1], 3, 2, P.TREE_L)
    px(img, crown[0] - 1, crown[1] + 2, (120, 84, 50, 255))
    px(img, crown[0] + 2, crown[1] + 2, (120, 84, 50, 255))


def gen_palm():
    img = new_img(24, 32)
    palm(img, 0, 0)
    save(outline(img), "prop_palm")


def lighthouse(img, ox, oy):
    # tower, tapering, red and white bands
    for j in range(26):
        half = 4 + j // 7
        c = RED if (j // 5) % 2 == 0 else WHITE
        hline(img, ox + 9 - half, oy + 12 + j, half * 2, c)
        px(img, ox + 9 - half, oy + 12 + j, P.mix(c, (255, 255, 255, 255), 0.3))
    rect(img, ox + 3, oy + 37, 13, 3, P.STEEL_D)
    # gallery, lantern, cap
    rect(img, ox + 3, oy + 10, 12, 2, INK)
    rect(img, ox + 5, oy + 4, 8, 6, (255, 236, 150, 255))
    vline(img, ox + 9, oy + 4, 6, INK)
    rect(img, ox + 4, oy + 2, 10, 2, RED_D)
    rect(img, ox + 7, oy, 4, 2, RED_D)
    rect(img, ox + 7, oy + 24, 3, 4, P.GLASS)  # a window


def gen_lighthouse():
    img = new_img(18, 40)
    lighthouse(img, 0, 0)
    save(outline(img), "prop_lighthouse")


def balloon(img, ox, oy):
    stripes = [(232, 80, 70, 255), (250, 200, 80, 255), (80, 150, 220, 255), (250, 240, 220, 255)]
    for y in range(20):
        for x in range(22):
            r = ((x - 10.5) / 10.5) ** 2 + ((y - 9.5) / 10.0) ** 2
            if r <= 1.0 and y < 18 or (y >= 17 and abs(x - 10.5) < 18 - y + 3):
                if r <= 1.0:
                    k = int((x - 10.5) / 10.5 * 2.2 + 2.2)
                    c = stripes[min(3, max(0, k)) % 4]
                    if x < 7 and y < 8:
                        c = P.mix(c, (255, 255, 255, 255), 0.35)
                    px(img, ox + x, oy + y, c)
    for (x0, x1) in ((5, 9), (16, 12)):
        for j in range(6):
            px(img, ox + x0 + (x1 - x0) * j // 6, oy + 19 + j, INK)
    rect(img, ox + 8, oy + 25, 6, 5, (150, 110, 70, 255))
    hline(img, ox + 8, oy + 25, 6, (186, 140, 90, 255))


def gen_balloon():
    img = new_img(22, 30)
    balloon(img, 0, 0)
    save(outline(img), "prop_balloon")


def dolphin(img, ox, oy, rising):
    body = (90, 120, 150, 255)
    belly = (200, 214, 222, 255)
    pts = [(x, int(6 - 5 * math.sin(math.pi * x / 17.0))) for x in range(18)]
    for i, (x, y) in enumerate(pts):
        if (rising and x < 14) or (not rising and x > 3):
            rect(img, ox + x, oy + y, 1, 3, body)
            px(img, ox + x, oy + y + 2, belly)
    fx = 8 if rising else 9
    px(img, ox + fx, oy + 0, body)
    px(img, ox + fx + 1, oy + 0, body)
    if rising:
        px(img, ox + 13, oy + 3, INK)
        rect(img, ox + 0, oy + 8, 3, 2, body)
    else:
        rect(img, ox + 15, oy + 8, 3, 2, body)


def gen_dolphin():
    frames = []
    for rising in (True, False):
        img = new_img(18, 12)
        dolphin(img, 0, 0, rising)
        frames.append(outline(img))
    save(sheet(frames), "prop_dolphin")


def gen_flagpole():
    img = new_img(5, 22)
    vline(img, 2, 1, 20, P.STEEL_L)
    vline(img, 3, 1, 20, P.STEEL)
    rect(img, 1, 0, 3, 2, (250, 220, 120, 255))
    rect(img, 0, 20, 5, 2, P.STEEL_D)
    save(outline(img), "prop_flagpole")


# --- shelf art -----------------------------------------------------------------

def head(img, cx, cy, hat, party=False, skin=P.SKIN):
    """A worker from the shoulders up, wearing the hat."""
    rect(img, cx - 9, cy + 9, 18, 8, P.VEST)
    hline(img, cx - 9, cy + 9, 18, P.VEST_L)
    vline(img, cx - 3, cy + 9, 8, (230, 230, 210, 255))
    vline(img, cx + 3, cy + 9, 8, (230, 230, 210, 255))
    ellipse(img, cx, cy + 3, 6, 6, skin)
    px(img, cx - 2, cy + 3, INK)
    px(img, cx + 2, cy + 3, INK)
    hline(img, cx - 1, cy + 6, 3, P.SKIN_D)
    if party:
        for j in range(12):
            half = max(0, j // 2)
            hline(img, cx - half, cy - 12 + j, half * 2 + 1, hat if j % 4 else (255, 255, 255, 255))
        ellipse(img, cx, cy - 13, 2, 2, (255, 236, 120, 255))
        return
    h = tuple(hat[:3]) + (255,)
    light = P.mix(h, (255, 255, 255, 255), 0.4)
    dark = P.mix(h, (0, 0, 0, 255), 0.3)
    ellipse(img, cx, cy - 1, 8, 5, h)
    rect(img, cx - 9, cy + 1, 18, 2, dark)
    ellipse(img, cx - 3, cy - 3, 2, 1.5, light)
    vline(img, cx, cy - 6, 6, dark)


# --- shelf icons -----------------------------------------------------------------
#
# The shelf used to show each piece as a little framed painting with its own sky.
# Next to the equipment tab - machines standing on the sheet's light well - the
# paintings read as dark holes. These are the same pieces as objects: no sky, no
# frame, an outline and a soft shadow, so they stand on the well the way a crane
# does. One 48x40 frame per item, in ART order (`ui_decor_icons`).

IW, IH = 48, 40
SHADOW = (40, 60, 70, 60)


def shadow(img, cx, cy, rx, ry=2):
    ellipse(img, cx, cy, rx, ry, SHADOW)


def icon_hat(item):
    img = new_img(IW, IH)
    if item == "rainbow_hats":
        for i, hue in enumerate(((236, 80, 70), (250, 200, 70), (90, 200, 110))):
            shadow(img, 10 + i * 14, 37, 8)
            head(img, 10 + i * 14, 18 + (i % 2) * 2, hue)
    elif item == "party_hats":
        for i, hue in enumerate(((236, 90, 160), (90, 200, 220), (250, 200, 70))):
            shadow(img, 10 + i * 14, 37, 8)
            head(img, 10 + i * 14, 20, hue, party=True)
    else:
        hat = HATS[item]
        shadow(img, 13, 37, 9)
        shadow(img, 35, 37, 9)
        head(img, 13, 18, hat)
        head(img, 35, 20, hat, skin=P.SKIN_DARK)
        if item == "gold_hats":
            for (x, y) in ((6, 6), (42, 6), (24, 2)):
                px(img, x, y, (255, 255, 230, 255))
                for (dx, dy) in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    px(img, x + dx, y + dy, (255, 210, 90, 255))
        if item == "neon_hats":
            for (x, y) in ((7, 9), (41, 10)):
                px(img, x, y, (200, 255, 120, 255))
        if item == "camo_hats":
            for (x, y) in ((13, 14), (18, 15), (30, 16), (35, 17)):
                px(img, x, y, (64, 80, 44, 255))
                px(img, x + 1, y, (150, 140, 90, 255))
    return outline(img)


def icon_rgb():
    img = new_img(IW, IH)
    for i, c in enumerate(((255, 80, 120), (80, 200, 255), (130, 230, 80), (255, 190, 50))):
        x = 6 + i * 12
        shadow(img, x + 2, 37, 4, 1.5)
        ellipse(img, x + 2, 8, 6, 5, c + (80,))
        vline(img, x + 2, 9, 27, P.STEEL)
        vline(img, x + 3, 9, 27, P.STEEL_D)
        rect(img, x, 5, 5, 4, c + (255,))
        hline(img, x, 5, 5, P.mix(c + (255,), (255, 255, 255, 255), 0.5))
        rect(img, x, 35, 6, 2, P.STEEL_D)
    return outline(img)


def icon_bunting():
    img = new_img(IW, IH)
    for x in (3, 44):
        shadow(img, x + 1, 37, 3, 1.5)
        vline(img, x, 3, 34, P.STEEL_L)
        vline(img, x + 1, 3, 34, P.STEEL)
    colors = [(236, 80, 70), (250, 200, 70), (90, 190, 110), (80, 150, 230), (236, 120, 190)]
    for row, sag in ((6, 6), (19, 5)):
        for x in range(5, 44):
            y = row + int(sag * math.sin(math.pi * (x - 5) / 39))
            px(img, x, y, INK)
            if (x - 5) % 6 == 1:
                c = colors[((x - 5) // 6 + row) % 5] + (255,)
                for j in range(6):
                    hline(img, x + j // 2, y + 1 + j, 5 - j, c)
    return outline(img)


def icon_sprite(name, scale=1, at=None, region=None, shade=True):
    img = new_img(IW, IH)
    spr = load(name)
    if region:
        spr = spr.crop(region)
    if scale != 1:
        spr = spr.resize((spr.width * scale, spr.height * scale), Image.NEAREST)
    x, y = at if at else ((IW - spr.width) // 2, IH - 2 - spr.height)
    if shade:
        shadow(img, x + spr.width // 2, y + spr.height, spr.width // 2 + 1)
    img.alpha_composite(spr, (x, y))
    return img


def icon_planters():
    """Two wooden troughs seen from the quay, spilling leaves and flowers."""
    img = new_img(IW, IH)
    wood, wood_l, wood_d = (168, 112, 70, 255), (204, 148, 96, 255), (120, 78, 48, 255)
    flowers = [(236, 80, 110, 255), (250, 210, 80, 255), (240, 240, 250, 255), (180, 110, 230, 255)]
    for n, (ox, oy) in enumerate(((2, 18), (25, 22))):
        shadow(img, ox + 10, oy + 16, 11)
        # leaves, a mound over the trough
        for j in range(9):
            half = 9 - abs(j - 4) // 2 - (1 if j in (0, 8) else 0)
            for k in range(-half, half + 1):
                c = P.TREE if (k + j) % 3 else P.TREE_D
                px(img, ox + 10 + k, oy + j - 2, c if j > 1 else P.TREE_L)
        for i, (fx, fy) in enumerate(((4, 0), (9, -2), (14, 1), (7, 3), (16, -1), (12, 4))):
            c = flowers[(i + n) % 4]
            px(img, ox + fx, oy + fy, c)
            px(img, ox + fx + 1, oy + fy, c)
            px(img, ox + fx, oy + fy + 1, c)
            px(img, ox + fx + 1, oy + fy + 1, P.mix(c, (0, 0, 0, 255), 0.2))
        rect(img, ox, oy + 6, 21, 9, wood)
        hline(img, ox, oy + 6, 21, wood_l)
        hline(img, ox, oy + 10, 21, wood_d)
        hline(img, ox, oy + 14, 21, wood_d)
        vline(img, ox + 2, oy + 7, 7, wood_d)
        vline(img, ox + 18, oy + 7, 7, wood_d)
    return outline(img)


def icon_duck():
    img = new_img(IW, IH)
    spr = load("prop_duck").crop((0, 0, 42, 40))
    ellipse(img, 24, 36, 21, 3, (90, 170, 210, 140))
    img.alpha_composite(spr, (3, 0))
    return img


def icon_cats():
    img = new_img(IW, IH)
    ramp = P.CONTAINER_RAMPS["rust"]
    shadow(img, 24, 37, 22)
    rect(img, 2, 20, 44, 16, ramp[2])
    for x in range(4, 46, 3):
        vline(img, x, 21, 14, ramp[1])
    hline(img, 2, 20, 44, ramp[4])
    hline(img, 2, 35, 44, ramp[0])
    img = outline(img)
    cat = load("prop_cat")
    for i, x in enumerate((5, 19, 33)):
        c = cat.crop((0 if i % 2 == 0 else 14, 0, 14 if i % 2 == 0 else 28, 12))
        img.alpha_composite(c, (x, 9))
    return img


def icon_palms():
    img = new_img(IW, IH)
    shadow(img, 13, 37, 8)
    shadow(img, 35, 37, 8)
    palm(img, 0, 6)
    palm(img, 22, 4)
    return outline(img)


def icon_lighthouse():
    img = new_img(IW, IH)
    for side in (-1, 1):
        for j in range(16):
            x = 24 + side * (3 + j)
            for k in range(-(j // 4), j // 4 + 1):
                px(img, x, 4 + k + j // 5, (255, 220, 110, 130))
    shadow(img, 24, 38, 10)
    lighthouse(img, 15, 0)
    return outline(img)


def icon_balloon():
    img = new_img(IW, IH)
    ellipse(img, 8, 30, 7, 2.5, (250, 250, 255, 255))
    ellipse(img, 41, 12, 6, 2.5, (250, 250, 255, 255))
    balloon(img, 13, 5)
    return outline(img)


def icon_dolphins():
    img = new_img(IW, IH)
    for y, x0, x1 in ((31, 2, 46), (34, 6, 42), (37, 12, 36)):
        hline(img, x0, y, x1 - x0, (90, 170, 210, 170))
    dolphin(img, 4, 12, True)
    dolphin(img, 26, 16, False)
    img = outline(img)
    for (x, y) in ((4, 29), (7, 28), (40, 30), (43, 29)):
        px(img, x, y, P.FOAM)
    return img


def icon_flags():
    img = new_img(IW, IH)
    flags = load("ui_flags")
    for i, code in enumerate((0, 1, 3, 16)):
        x = 4 + i * 11
        shadow(img, x + 1, 37, 3, 1.5)
        vline(img, x, 6, 31, P.STEEL_L)
        vline(img, x + 1, 6, 31, P.STEEL)
        f = flags.crop((code * 16, 0, code * 16 + 16, 11)).resize((10, 7), Image.NEAREST)
        img.alpha_composite(f, (x + 2, 7 + (i % 2) * 2))
    return outline(img)


def icon_fireworks():
    img = new_img(IW, IH)
    for (cx, cy, c) in ((13, 13, (240, 70, 120)), (34, 9, (40, 150, 230)), (27, 23, (250, 170, 30))):
        for a in range(0, 360, 30):
            for r in (3, 5, 7):
                px(img, int(cx + r * math.cos(math.radians(a))),
                   int(cy + r * math.sin(math.radians(a))), c + (255 if r < 7 else 170,))
        px(img, cx, cy, (255, 255, 255, 255))
        for y in range(cy + 9, 37, 2):
            px(img, cx, y, c + (150,))
    shadow(img, 24, 37, 12)
    rect(img, 18, 33, 12, 4, (150, 70, 50, 255))
    hline(img, 18, 33, 12, (200, 110, 70, 255))
    return outline(img)


def gen_icons():
    makers = {
        "rgb_lamps": icon_rgb, "bunting": icon_bunting, "planters": icon_planters,
        "duck": icon_duck, "cats": icon_cats, "palms": icon_palms,
        "lighthouse": icon_lighthouse, "balloon": icon_balloon, "dolphins": icon_dolphins,
        "flags": icon_flags, "fireworks": icon_fireworks,
    }
    frames = []
    for item in ART:
        frames.append(makers[item]() if item in makers else icon_hat(item))
    save(sheet(frames), "ui_decor_icons")


if __name__ == "__main__":
    gen_palm()
    gen_lighthouse()
    gen_balloon()
    gen_dolphin()
    gen_flagpole()
    gen_icons()
