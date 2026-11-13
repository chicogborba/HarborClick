"""Decorations: the props new cosmetics put in the port, and the picture each
cosmetic shows on its shelf (`ui_decor_art`, one 56x44 frame per item, in the
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

W, H = 56, 44


def backdrop(img, top, bottom):
    for y in range(H):
        t = y / (H - 1)
        hline(img, 0, y, W, tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))


def frame(img):
    hline(img, 0, 0, W, INK)
    hline(img, 0, H - 1, W, INK)
    vline(img, 0, 0, H, INK)
    vline(img, W - 1, 0, H, INK)


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


def art_hat(item):
    img = new_img(W, H)
    backdrop(img, (120, 176, 210), (190, 214, 226))
    rect(img, 0, 34, W, 10, P.YARD)
    if item == "rainbow_hats":
        for i, hue in enumerate(((236, 80, 70), (250, 200, 70), (90, 200, 110), (80, 150, 230))):
            head(img, 10 + i * 12, 22 + (i % 2) * 2, hue)
    elif item == "party_hats":
        for i, hue in enumerate(((236, 90, 160), (90, 200, 220), (250, 200, 70))):
            head(img, 14 + i * 14, 24, hue, party=True)
    else:
        hat = HATS[item]
        head(img, 20, 22, hat)
        head(img, 37, 24, hat, skin=P.SKIN_DARK)
        if item == "gold_hats":
            for (x, y) in ((12, 8), (44, 10), (28, 4)):
                px(img, x, y, (255, 255, 230, 255))
                px(img, x - 1, y, (255, 230, 140, 255))
                px(img, x + 1, y, (255, 230, 140, 255))
                px(img, x, y - 1, (255, 230, 140, 255))
                px(img, x, y + 1, (255, 230, 140, 255))
        if item == "camo_hats":
            for (x, y) in ((17, 18), (22, 19), (34, 20), (39, 21)):
                px(img, x, y, (64, 80, 44, 255))
                px(img, x + 1, y, (150, 140, 90, 255))
    frame(img)
    return img


def art_rgb():
    img = new_img(W, H)
    backdrop(img, (24, 22, 48), (50, 44, 80))
    rect(img, 0, 36, W, 8, (60, 56, 70, 255))
    for i, c in enumerate(((255, 80, 120), (80, 220, 255), (160, 255, 100), (255, 200, 60))):
        x = 6 + i * 13
        ellipse(img, x + 2, 12, 7, 6, c + (70,))
        vline(img, x + 2, 12, 26, P.STEEL)
        rect(img, x, 8, 5, 4, c + (255,))
        ellipse(img, x + 2, 38, 5, 2, c + (90,))
    frame(img)
    return img


def art_bunting():
    img = new_img(W, H)
    backdrop(img, (130, 190, 230), (200, 226, 240))
    vline(img, 3, 6, 34, P.STEEL)
    vline(img, 52, 6, 34, P.STEEL)
    colors = [(236, 80, 70), (250, 200, 70), (90, 190, 110), (80, 150, 230), (236, 120, 190)]
    for row, sag in ((10, 6), (24, 5)):
        for x in range(4, 52):
            y = row + int(sag * math.sin(math.pi * (x - 4) / 48))
            px(img, x, y, INK)
            if (x - 4) % 6 == 0:
                c = colors[((x - 4) // 6 + row) % 5] + (255,)
                for j in range(6):
                    hline(img, x + j // 2, y + 1 + j, 5 - j, c)
    frame(img)
    return img


def art_sprite(name, bg_top, bg_bottom, ground=None, region=None, scale=1, at=None):
    img = new_img(W, H)
    backdrop(img, bg_top, bg_bottom)
    if ground:
        rect(img, 0, ground[0], W, H - ground[0], ground[1])
    spr = load(name)
    if region:
        spr = spr.crop(region)
    if scale != 1:
        spr = spr.resize((spr.width * scale, spr.height * scale), Image.NEAREST)
    x, y = at if at else ((W - spr.width) // 2, (H - spr.height) // 2)
    img.alpha_composite(spr, (x, y))
    return img


def art_planters():
    img = art_sprite("prop_planter", (180, 214, 230), (210, 226, 232), (30, P.QUAY),
                     scale=2, at=(12, 12))
    frame(img)
    return img


def art_duck():
    img = new_img(W, H)
    backdrop(img, (62, 126, 158), (44, 96, 130))
    for y in range(4, H, 7):
        for x in range((y * 3) % 9, W, 11):
            hline(img, x, y, 4, P.SEA_LIGHT)
    duck = load("prop_duck")
    img.alpha_composite(duck, ((W - duck.width) // 2, 0))
    frame(img)
    return img


def art_cats():
    img = new_img(W, H)
    backdrop(img, (150, 190, 214), (200, 220, 230))
    rect(img, 4, 22, 48, 18, P.CONTAINER_RAMPS["rust"][2])
    for x in range(6, 50, 3):
        vline(img, x, 23, 16, P.CONTAINER_RAMPS["rust"][1])
    hline(img, 4, 22, 48, P.CONTAINER_RAMPS["rust"][4])
    cat = load("prop_cat")
    for i, x in enumerate((8, 24, 38)):
        c = cat.crop((0 if i % 2 == 0 else 14, 0, 14 if i % 2 == 0 else 28, 12))
        img.alpha_composite(c, (x, 11))
    for (x, y) in ((22, 6), (25, 4), (28, 6)):
        px(img, x, y, WHITE)
    frame(img)
    return img


def art_palms():
    img = new_img(W, H)
    backdrop(img, (120, 190, 230), (250, 220, 170))
    rect(img, 0, 36, W, 8, (230, 206, 150, 255))
    palm(img, 2, 6)
    palm(img, 28, 4)
    frame(img)
    return img


def art_lighthouse():
    img = new_img(W, H)
    backdrop(img, (30, 40, 80), (90, 80, 130))
    for (x0, x1) in ((27, 2), (27, 54)):
        for j in range(14):
            x = x0 + (x1 - x0) * j // 14
            for k in range(-j // 4, j // 4 + 1):
                px(img, x, 6 + k + j // 6, (255, 236, 150, 60))
    rect(img, 0, 38, W, 6, P.SEA_DEEP)
    lighthouse(img, 18, 2)
    frame(img)
    return img


def art_balloon():
    img = new_img(W, H)
    backdrop(img, (110, 180, 230), (200, 226, 240))
    ellipse(img, 10, 34, 9, 3, (250, 250, 255, 255))
    ellipse(img, 46, 12, 8, 3, (250, 250, 255, 255))
    balloon(img, 17, 6)
    frame(img)
    return img


def art_dolphins():
    img = new_img(W, H)
    backdrop(img, (110, 180, 220), (62, 126, 158))
    rect(img, 0, 26, W, 18, P.SEA)
    for y in range(28, H, 5):
        hline(img, (y * 7) % 13, y, 6, P.SEA_LIGHT)
    dolphin(img, 8, 14, True)
    dolphin(img, 30, 18, False)
    for (x, y) in ((6, 26), (9, 25), (46, 27), (49, 26)):
        px(img, x, y, P.FOAM)
    frame(img)
    return img


def art_flags():
    img = new_img(W, H)
    backdrop(img, (130, 190, 230), (200, 226, 240))
    flags = load("ui_flags")
    for i, code in enumerate((0, 1, 3, 16)):
        x = 4 + i * 13
        vline(img, x, 8, 32, P.STEEL_L)
        f = flags.crop((code * 16, 0, code * 16 + 16, 11)).resize((10, 7), Image.NEAREST)
        img.alpha_composite(f, (x + 1, 9 + (i % 2) * 2))
    rect(img, 0, 40, W, 4, P.QUAY)
    frame(img)
    return img


def art_fireworks():
    img = new_img(W, H)
    backdrop(img, (14, 14, 36), (40, 30, 70))
    rect(img, 0, 36, W, 8, P.SEA_DEEP)
    for (cx, cy, c) in ((16, 14, (255, 120, 150)), (38, 10, (120, 220, 255)), (30, 24, (255, 220, 90))):
        for a in range(0, 360, 30):
            for r in (3, 5, 7):
                px(img, int(cx + r * math.cos(math.radians(a))),
                   int(cy + r * math.sin(math.radians(a))), c + (255 if r < 7 else 160,))
        px(img, cx, cy, (255, 255, 255, 255))
        for y in range(36, H - 1, 2):
            px(img, cx, y, c + (120,))
    frame(img)
    return img


def gen_art():
    makers = {
        "rgb_lamps": art_rgb, "bunting": art_bunting, "planters": art_planters,
        "duck": art_duck, "cats": art_cats, "palms": art_palms,
        "lighthouse": art_lighthouse, "balloon": art_balloon, "dolphins": art_dolphins,
        "flags": art_flags, "fireworks": art_fireworks,
    }
    frames = []
    for item in ART:
        if item in makers:
            frames.append(makers[item]())
        else:
            frames.append(art_hat(item))
    save(sheet(frames), "ui_decor_art")


if __name__ == "__main__":
    gen_palm()
    gen_lighthouse()
    gen_balloon()
    gen_dolphin()
    gen_flagpole()
    gen_art()
