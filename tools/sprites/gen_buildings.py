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
    """Big shed, 76x48: a pitched steel roof and the south wall under it.

    Drawn the way the stacks are — top-down with the south face showing — so a
    shed reads as a building with height rather than a red rug on the yard.
    Light from the north-west: the north slope catches it, the south slope
    turns away, and the wall under the eaves sits in the roof's shadow."""
    w, h = 76, 48
    img = new_img(w, h)
    roof = P.ramp(P.ROOF_RED, 5, hue_shift=14.0, dark=0.4, light=0.5)
    wall = P.ramp((214, 206, 190), 5, hue_shift=12.0, dark=0.3, light=0.6)
    steel = P.ramp(P.STEEL, 5, hue_shift=12.0)
    x0, x1 = 1, 72                 # building, outline included later
    ridge, eave, base = 15, 31, 45
    # --- roof: north slope lit, south slope in shade, ribs running down both
    rect(img, x0, 1, x1 - x0 + 1, ridge - 1, roof[3])
    rect(img, x0, ridge + 1, x1 - x0 + 1, eave - ridge - 1, roof[2])
    for rx in range(x0 + 2, x1, 3):
        vline(img, rx, 2, ridge - 2, roof[4])
        vline(img, rx + 1, 2, ridge - 2, P.mix(roof[3], roof[2], 0.5))
        vline(img, rx, ridge + 1, eave - ridge - 2, roof[3])
        vline(img, rx + 1, ridge + 1, eave - ridge - 2, roof[1])
    hline(img, x0, ridge, x1 - x0 + 1, roof[4])         # ridge cap, in full sun
    hline(img, x0, ridge + 1, x1 - x0 + 1, roof[0])
    hline(img, x0, 1, x1 - x0 + 1, roof[4])
    hline(img, x0, eave, x1 - x0 + 1, roof[0])          # the gutter
    vline(img, x0, 1, eave, roof[4])
    vline(img, x1, 1, eave, roof[1])
    # skylights: translucent sheets on the north slope, one per bay
    glass = P.ramp(P.GLASS, 5, hue_shift=10.0)
    for sx in range(6, x1 - 8, 15):
        rect(img, sx, 4, 8, 8, glass[2])
        rect(img, sx, 4, 8, 1, glass[4])
        rect(img, sx + 7, 5, 1, 7, glass[1])
        px(img, sx + 1, 5, glass[4])
        rect(img, sx, ridge + 4, 8, 6, P.mix(glass[1], roof[1], 0.4))
    # turbine vents along the ridge
    for vx in range(12, x1 - 6, 18):
        rect(img, vx, ridge - 2, 4, 4, steel[2])
        rect(img, vx, ridge - 2, 4, 1, steel[4])
        px(img, vx + 1, ridge - 1, steel[0])
        px(img, vx + 3, ridge + 1, steel[1])
    # --- south wall, under the eaves
    rect(img, x0, eave + 1, x1 - x0 + 1, base - eave, wall[2])
    hline(img, x0, eave + 1, x1 - x0 + 1, P.mix(wall[1], roof[0], 0.45))  # eave shadow
    hline(img, x0, eave + 2, x1 - x0 + 1, wall[1])
    for px_ in range(x0 + 3, x1, 4):                    # cladding seams
        vline(img, px_, eave + 3, base - eave - 3, wall[1])
    hline(img, x0, base, x1 - x0 + 1, wall[0])          # plinth
    # roller doors: three bays, slatted steel, one half open onto the dark inside
    for i, dx in enumerate((6, 30, 54)):
        rect(img, dx, eave + 4, 13, base - eave - 4, steel[1])
        rect(img, dx, eave + 4, 13, 1, steel[3])
        for sy in range(eave + 6, base, 2):
            hline(img, dx, sy, 13, steel[0])
        if i == 1:
            rect(img, dx + 1, eave + 9, 11, base - eave - 9, (40, 34, 44, 255))
            hline(img, dx + 1, eave + 9, 11, steel[0])
        vline(img, dx - 1, eave + 4, base - eave - 4, wall[0])
        vline(img, dx + 13, eave + 4, base - eave - 4, wall[3])
        # yellow-black dock bumpers either side of each door
        px(img, dx - 1, base - 2, P.SAFETY)
        px(img, dx + 13, base - 2, P.SAFETY)
    # a lit window and a personnel door between the bays
    for wx in (22, 46):
        rect(img, wx, eave + 5, 4, 3, glass[1])
        px(img, wx, eave + 5, glass[4])
        rect(img, wx + 1, eave + 10, 3, base - eave - 10, steel[0])
    img = outline(img)
    # cast shadow, east and south, onto the yard
    for y in range(4, base + 2):
        for x in (x1 + 2, x1 + 3):
            if img.getpixel((x, y))[3] == 0:
                px(img, x, y, P.SHADOW)
    for x in range(4, x1 + 3):
        if img.getpixel((x, base + 2))[3] == 0:
            px(img, x, base + 2, P.SHADOW)
    save(img, "bld_warehouse")


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
