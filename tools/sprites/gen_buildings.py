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


def small_building(w, h, roof_base, wall_base, eave, door_x=None, windows=()):
    """A small building in the yard's 3/4 view: pitched roof over a south wall.

    The same grammar as the warehouse, so a booth and a shed stand on the same
    ground: north slope lit, south slope in shade, the wall under the eaves in
    the roof's shadow, a cast shadow east and south. Returns the image, the
    ramps and the eave row so callers can add their own details."""
    img = new_img(w, h)
    roof = P.ramp(roof_base, 5, hue_shift=14.0, dark=0.4, light=0.5)
    wall = P.ramp(wall_base, 5, hue_shift=12.0, dark=0.3, light=0.6)
    x0, x1 = 1, w - 4
    ridge = (1 + eave) // 2
    base = h - 4
    rect(img, x0, 1, x1 - x0 + 1, ridge - 1, roof[3])
    rect(img, x0, ridge + 1, x1 - x0 + 1, eave - ridge - 1, roof[2])
    for rx in range(x0 + 2, x1, 3):
        vline(img, rx, 2, ridge - 2, roof[4])
        vline(img, rx, ridge + 1, eave - ridge - 2, roof[3])
    hline(img, x0, ridge, x1 - x0 + 1, roof[4])
    hline(img, x0, ridge + 1, x1 - x0 + 1, roof[0])
    hline(img, x0, 1, x1 - x0 + 1, roof[4])
    hline(img, x0, eave, x1 - x0 + 1, roof[0])
    vline(img, x1, 1, eave, roof[1])
    rect(img, x0, eave + 1, x1 - x0 + 1, base - eave, wall[2])
    hline(img, x0, eave + 1, x1 - x0 + 1, P.mix(wall[1], roof[0], 0.45))
    hline(img, x0, base, x1 - x0 + 1, wall[0])
    glass = P.ramp(P.GLASS, 5, hue_shift=10.0)
    for wx in windows:
        rect(img, wx, eave + 3, 4, 3, glass[1])
        px(img, wx, eave + 3, glass[4])
        hline(img, wx, eave + 6, 4, wall[0])
    if door_x is not None:
        rect(img, door_x, eave + 3, 4, base - eave - 3, P.ramp(P.WOOD, 5)[1])
        px(img, door_x + 3, (eave + base) // 2 + 1, P.SAFETY_L)
    img = outline(img)
    for y in range(3, base + 2):
        for x in (x1 + 2, x1 + 3):
            if 0 <= x < w and img.getpixel((x, y))[3] == 0:
                px(img, x, y, P.SHADOW)
    for x in range(3, x1 + 3):
        if base + 2 < h and img.getpixel((x, base + 2))[3] == 0:
            px(img, x, base + 2, P.SHADOW)
    return img, roof, wall


def gen_customs():
    """Customs / gate booth, 28x24, with its barrier arm drawn separately."""
    img, roof, wall = small_building(28, 24, P.ROOF_BLUE, (224, 220, 206), 13,
                                     door_x=16, windows=(5, 10))
    rect(img, 4, 3, 3, 2, P.SAFETY)          # roof beacon
    px(img, 4, 3, P.SAFETY_L)
    # an air-conditioning unit on the south slope, and the sign over the door
    rect(img, 18, 8, 5, 3, P.STEEL)
    hline(img, 18, 8, 5, P.STEEL_L)
    px(img, 20, 9, P.STEEL_D)
    rect(img, 14, 15, 8, 2, (34, 70, 110, 255))
    for sx in (15, 17, 19):
        px(img, sx, 15, P.SAFETY_L)
    # a striped kerb where the lorries stop
    for kx in range(2, 24, 2):
        px(img, kx, 20, P.SAFETY if (kx // 2) % 2 == 0 else (52, 46, 54, 255))
    save(img, "bld_customs")

    arm = new_img(40, 6)
    for i in range(0, 38, 6):
        color = P.CRANE if (i // 6) % 2 == 0 else P.SUPER_W
        rect(arm, i + 1, 2, 6, 2, color)
    rect(arm, 0, 1, 4, 4, P.STEEL_D)     # pivot
    save(outline(arm), "bld_customs_arm")


def gen_tower():
    """Round control tower, 26x26, with a rotating radar exported separately.

    Seen from straight above, so everything it has to say is in rings: a
    white parapet lit from the north-west, a band of tinted glass with the
    mullions showing and the sun on its north-west arc, then the blue roof
    with its plant, a hatch and the radar's pedestal."""
    w = 26
    img = new_img(w, w)
    c = w / 2.0
    roof = P.ramp(P.ROOF_BLUE, 5, hue_shift=12.0, dark=0.4, light=0.5)
    glass = P.ramp(P.GLASS, 5, hue_shift=10.0)
    wall = P.ramp(P.SUPER_W, 5, hue_shift=10.0, dark=0.3, light=0.5)
    for y in range(w):
        for x in range(w):
            dx, dy = x - c + 0.5, y - c + 0.5
            d = math.hypot(dx, dy)
            if d > 11.5:
                continue
            lit = -(dx + dy) / max(d, 0.01)          # +1.4 NW .. -1.4 SE
            if d > 10.0:                              # parapet
                tone = wall[4] if lit > 0.5 else (wall[2] if lit > -0.5 else wall[1])
            elif d > 8.0:                             # the glazed ring
                a = math.degrees(math.atan2(dy, dx)) % 360
                if int(a) % 30 < 4:
                    tone = wall[1]                    # mullion
                elif lit > 0.9:
                    tone = glass[4]
                elif lit > 0.1:
                    tone = glass[3]
                else:
                    tone = glass[1]
            else:                                     # roof
                tone = roof[3] if lit > 0.6 and d > 4.5 else \
                    (roof[1] if lit < -0.8 and d > 4.5 else roof[2])
            img.putpixel((x, y), tone)
    # rooftop: plant, hatch, the radar pedestal in the middle, a beacon
    rect(img, 9, 15, 4, 3, P.STEEL_D)
    hline(img, 9, 15, 4, P.STEEL_L)
    rect(img, 15, 9, 3, 3, roof[0])
    px(img, 15, 9, roof[4])
    rect(img, 11, 11, 4, 4, P.STEEL)
    hline(img, 11, 11, 4, P.STEEL_L)
    px(img, 14, 14, P.STEEL_D)
    px(img, 9, 9, P.RED_LIGHT)
    img = outline(img)
    save(img, "bld_tower")

    radar = new_img(16, 16)
    # bar antenna: a tapered blade with a lit leading edge, on a hub
    rect(radar, 7, 1, 2, 14, P.STEEL_D)
    vline(radar, 7, 1, 14, P.STEEL_L)
    rect(radar, 6, 1, 4, 2, P.STEEL_L)
    rect(radar, 6, 13, 4, 2, P.STEEL)
    rect(radar, 6, 6, 4, 4, P.STEEL)
    px(radar, 7, 7, (214, 220, 228, 255))
    px(radar, 8, 8, P.STEEL_D)
    save(outline(radar), "bld_tower_radar")


def gen_ai_hub():
    """Automation hub: flat roof with solar panels and cooling units. 38x32.

    A server hall, so the roof is all equipment: a parapet, a solar array
    whose cells catch the sky, three chillers with their fans, a cable tray
    and a mast with a status lamp."""
    w, h = 38, 32
    img = new_img(w, h)
    slab = P.ramp((118, 112, 130), 5, hue_shift=10.0, dark=0.35, light=0.45)
    cell = P.ramp((48, 62, 96), 5, hue_shift=14.0, dark=0.3, light=0.7)
    steel = P.ramp(P.STEEL, 5, hue_shift=10.0)
    rect(img, 2, 2, w - 4, h - 4, slab[2])
    # parapet: lit on the north and west, in shade on the south and east
    hline(img, 2, 2, w - 4, slab[4])
    vline(img, 2, 2, h - 4, slab[4])
    hline(img, 3, 3, w - 6, slab[3])
    vline(img, w - 3, 2, h - 4, slab[1])
    hline(img, 2, h - 3, w - 4, slab[1])
    hline(img, 3, h - 4, w - 6, slab[1])
    # solar array: framed panels, a cell grid, one glint of sky on each
    for sy in range(5, h - 13, 6):
        for sx in range(5, w - 9, 9):
            rect(img, sx, sy, 8, 5, cell[1])
            hline(img, sx, sy, 8, cell[3])
            vline(img, sx, sy, 5, cell[2])
            vline(img, sx + 4, sy + 1, 4, cell[0])
            hline(img, sx + 1, sy + 2, 7, cell[0])
            px(img, sx + 1, sy + 1, cell[4])
            px(img, sx + 2, sy + 1, cell[3])
            px(img, sx + 6, sy + 3, cell[2])
            hline(img, sx, sy + 5, 8, slab[1])            # its shadow
    # chillers: a casing, a round fan with a hub, a louvre
    for cx in (5, 15, 25):
        rect(img, cx, h - 12, 8, 8, steel[2])
        hline(img, cx, h - 12, 8, steel[4])
        vline(img, cx, h - 12, 8, steel[3])
        vline(img, cx + 7, h - 12, 8, steel[1])
        hline(img, cx, h - 5, 8, steel[0])
        rect(img, cx + 2, h - 10, 4, 4, steel[0])
        px(img, cx + 2, h - 10, steel[2])
        px(img, cx + 5, h - 10, steel[2])
        px(img, cx + 2, h - 7, steel[2])
        px(img, cx + 5, h - 7, steel[2])
        px(img, cx + 3, h - 9, steel[4])
    # cable tray from the array to the chillers, and the mast
    vline(img, w - 6, 5, h - 12, slab[1])
    for ty in range(6, h - 8, 2):
        px(img, w - 6, ty, P.SAFETY)
    rect(img, w - 7, 4, 3, 3, steel[1])
    px(img, w - 6, 5, P.GREEN_LIGHT)
    img = outline(img)
    for y in range(4, h - 1):
        if img.getpixel((w - 1, y))[3] == 0:
            px(img, w - 1, y, P.SHADOW)
    for x in range(4, w - 1):
        if img.getpixel((x, h - 1))[3] == 0:
            px(img, x, h - 1, P.SHADOW)
    save(img, "bld_ai_hub")


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
    img, roof, wall = small_building(34, 26, P.WOOD, (230, 214, 190), 14,
                                     door_x=13, windows=(5, 20, 25))
    rect(img, 23, 3, 4, 4, (86, 78, 78, 255))   # chimney
    hline(img, 23, 3, 4, (120, 110, 108, 255))
    px(img, 24, 4, (52, 46, 54, 255))
    # a skylight on the lit slope, an awning over the door, a flower box
    glass = P.ramp(P.GLASS, 5, hue_shift=10.0)
    rect(img, 8, 3, 6, 3, glass[2])
    hline(img, 8, 3, 6, glass[4])
    px(img, 13, 5, glass[1])
    for ax in range(12, 18):
        px(img, ax, 16, P.CRANE if ax % 2 == 0 else P.SUPER_W)
    hline(img, 20, 21, 9, P.WOOD_D)
    for fx in (21, 23, 25, 27):
        px(img, fx, 20, P.GRASS_L if fx % 4 == 1 else P.RED_LIGHT)
    save(img, "bld_office")


if __name__ == "__main__":
    print("buildings:")
    gen_warehouse()
    gen_customs()
    gen_tower()
    gen_ai_hub()
    gen_portal()
    gen_office()
