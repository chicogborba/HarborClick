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


if __name__ == "__main__":
    print("props:")
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
    gen_splash()
    gen_shadow_blob()
