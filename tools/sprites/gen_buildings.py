"""Top-down port buildings — roofs with ridges, vents and skylights."""
import math
import palette as P
from common import (new_img, rect, hline, vline, px, outline, save, speckle,
                    sheet)


def ridged_roof(img, x, y, w, h, base, light, dark, ridge_step=5):
    """Pitched roof seen from above: ridge line down the middle, ribs."""
    rect(img, x, y, w, h, base)
    hline(img, x, y, w, light)
    vline(img, x, y, h, light)
    vline(img, x + w - 1, y, h, dark)
    hline(img, x, y + h - 1, w, dark)
    mid = y + h // 2
    hline(img, x, mid, w, dark)          # ridge
    hline(img, x, mid - 1, w, light)
    for rx in range(x + 2, x + w - 2, ridge_step):
        vline(img, rx, y + 1, h - 2, dark)


def gen_warehouse():
    """Big shed with roller doors on the yard side. 76x48."""
    w, h = 76, 48
    img = new_img(w, h)
    ridged_roof(img, 2, 2, w - 4, h - 4, P.ROOF_RED, P.ROOF_RED_L, P.ROOF_RED_D)
    # skylight strips
    for sx in range(8, w - 12, 16):
        rect(img, sx, 8, 10, 5, P.GLASS)
        hline(img, sx, 8, 10, P.GLASS_D)
        rect(img, sx, h - 14, 10, 5, P.GLASS)
        hline(img, sx, h - 14, 10, P.GLASS_D)
    # roof vents on the ridge
    for vx in range(14, w - 14, 18):
        rect(img, vx, h // 2 - 3, 6, 6, P.STEEL)
        hline(img, vx, h // 2 - 3, 6, P.STEEL_L)
    # apron + roller doors along the left (yard) edge
    rect(img, 0, 6, 3, h - 12, P.QUAY)
    for dy in range(10, h - 14, 12):
        rect(img, 0, dy, 3, 8, P.STEEL_D)
        px(img, 1, dy, P.STEEL_L)
    save(outline(img), "bld_warehouse")


def gen_customs():
    """Customs / gate booth with a barrier arm. 28x24 + separate arm."""
    img = new_img(28, 24)
    ridged_roof(img, 2, 2, 24, 20, P.ROOF_BLUE, (110, 142, 176, 255),
                P.ROOF_BLUE_D, ridge_step=4)
    rect(img, 9, 8, 10, 8, P.GLASS)      # skylight over the counter
    hline(img, 9, 8, 10, P.GLASS_D)
    rect(img, 4, 4, 4, 3, P.SAFETY)      # roof beacon
    save(outline(img), "bld_customs")

    arm = new_img(40, 6)
    for i in range(0, 38, 6):
        color = P.CRANE if (i // 6) % 2 == 0 else P.SUPER_W
        rect(arm, i + 1, 2, 6, 2, color)
    rect(arm, 0, 1, 4, 4, P.STEEL_D)     # pivot
    save(outline(arm), "bld_customs_arm")


def gen_tower():
    """Round control tower, 26x26, with a rotating radar exported separately."""
    w = 26
    img = new_img(w, w)
    c = w / 2.0
    for y in range(w):
        for x in range(w):
            d = math.hypot(x - c + 0.5, y - c + 0.5)
            if d <= 11.5:
                img.putpixel((x, y), P.SUPER_W if d > 8.0 else P.ROOF_BLUE)
            if 10.0 < d <= 11.5 and (x < c or y < c):
                img.putpixel((x, y), (242, 236, 224, 255))
    # glazed ring
    for a in range(0, 360, 12):
        rx = int(c + math.cos(math.radians(a)) * 9.6)
        ry = int(c + math.sin(math.radians(a)) * 9.6)
        px(img, rx, ry, P.GLASS)
    rect(img, 10, 10, 6, 6, P.ROOF_BLUE_D)   # rooftop plant
    save(outline(img), "bld_tower")

    radar = new_img(16, 16)
    rect(radar, 7, 2, 2, 12, P.STEEL_D)      # bar antenna
    rect(radar, 6, 2, 4, 3, P.STEEL_L)
    px(radar, 7, 7, P.STEEL_L)
    save(outline(radar), "bld_tower_radar")


def gen_ai_hub():
    """Automation hub: flat roof with solar panels and cooling units. 38x32."""
    w, h = 38, 32
    img = new_img(w, h)
    rect(img, 2, 2, w - 4, h - 4, (118, 112, 130, 255))
    hline(img, 2, 2, w - 4, (150, 144, 162, 255))
    vline(img, 2, 2, h - 4, (150, 144, 162, 255))
    vline(img, w - 3, 2, h - 4, (86, 82, 98, 255))
    hline(img, 2, h - 3, w - 4, (86, 82, 98, 255))
    # solar array
    for sy in range(5, h - 12, 6):
        for sx in range(5, w - 8, 9):
            rect(img, sx, sy, 8, 5, (48, 62, 96, 255))
            hline(img, sx, sy, 8, (78, 100, 140, 255))
            vline(img, sx + 4, sy, 5, (40, 52, 82, 255))
    # cooling units + antenna
    for cx in (6, 16, 26):
        rect(img, cx, h - 11, 7, 7, P.STEEL)
        hline(img, cx, h - 11, 7, P.STEEL_L)
        px(img, cx + 3, h - 8, P.STEEL_D)
    px(img, w - 6, 5, P.RED_LIGHT)
    save(outline(img), "bld_ai_hub")


def gen_portal():
    """Logistics portal: steel ring around a swirling void. 3 frames, 34x34."""
    frames = []
    for f in range(3):
        img = new_img(34, 34)
        c = 17.0
        for y in range(34):
            for x in range(34):
                d = math.hypot(x - c + 0.5, y - c + 0.5)
                if d <= 15.5:
                    if d > 12.5:
                        img.putpixel((x, y), P.STEEL if (x + y) % 2 else P.STEEL_L)
                    else:
                        a = math.degrees(math.atan2(y - c, x - c))
                        swirl = (a + d * 22 + f * 40) % 90
                        if swirl < 30:
                            img.putpixel((x, y), P.TEAL_L)
                        elif swirl < 60:
                            img.putpixel((x, y), P.TEAL)
                        else:
                            img.putpixel((x, y), P.TEAL_D)
        for sx, sy, sf in ((10, 12, 0), (22, 20, 1), (16, 25, 2)):
            if (f + sf) % 3 == 0:
                px(img, sx, sy, P.STAR)
        frames.append(outline(img))
    save(sheet(frames), "bld_portal")


def gen_office():
    """Small port office / admin building used as generic filler. 34x26."""
    w, h = 34, 26
    img = new_img(w, h)
    ridged_roof(img, 2, 2, w - 4, h - 4, P.WOOD, P.WOOD_L, P.WOOD_D, 4)
    rect(img, 8, 6, 8, 5, P.GLASS)
    hline(img, 8, 6, 8, P.GLASS_D)
    rect(img, 20, h - 12, 8, 5, P.GLASS)
    rect(img, 5, h - 9, 5, 5, (86, 78, 78, 255))   # chimney
    save(outline(img), "bld_office")


if __name__ == "__main__":
    print("buildings:")
    gen_warehouse()
    gen_customs()
    gen_tower()
    gen_ai_hub()
    gen_portal()
    gen_office()
