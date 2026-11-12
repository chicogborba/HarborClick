"""Top-down ground tiles, Stardew-flavoured: textured asphalt, worn concrete,
dirt, grass, water, and the transitions between them."""
import palette as P
from common import (new_img, rect, hline, vline, px, save, speckle, patch,
                    sheet)

T = 16   # tile size


def grain(img, base, dark, light, density, seed):
    """A surface's texture, as texture rather than as static.

    The ground used to be speckled with its ramp's full dark and full light at
    one pixel in six, which at phone size is television snow under everything
    the player is trying to read. This lays the same information down quieter:
    mostly half-steps toward dark and light, a few full-contrast pixels for
    grit, and a handful of two-pixel runs so the eye finds grain, not noise.
    """
    import random
    rng = random.Random(seed)
    soft_d, soft_l = P.mix(base, dark, 0.5), P.mix(base, light, 0.5)
    for y in range(T):
        for x in range(T):
            r = rng.random()
            if r < density * 0.55:
                px(img, x, y, soft_d)
            elif r < density:
                px(img, x, y, soft_l)
            elif r < density * 1.18:
                px(img, x, y, dark if rng.random() < 0.6 else light)
    for _ in range(3):
        x, y = rng.randrange(T - 1), rng.randrange(T)
        px(img, x, y, soft_d)
        px(img, x + 1, y, soft_d)


def gen_yard():
    """Paved yard: warm asphalt. Four variants, randomised in-game so the
    ground never shows an obvious repeat."""
    for v in range(4):
        img = new_img(T, T)
        rect(img, 0, 0, T, T, P.YARD)
        grain(img, P.YARD, P.YARD_D, P.YARD_L, 0.11, seed=10 + v)
        if v in (0, 2):
            patch(img, 3 + v * 4, 10 - v * 2, 4, 3, P.YARD_PATCH, seed=20 + v)
        if v in (1, 3):
            cx = 2 + v * 3
            for y in range(2, 13):
                cx += ((y + v) % 3) - 1
                px(img, max(0, min(T - 1, cx)), y, P.YARD_D)
        save(img, "gr_yard_%d" % v)


def gen_quay():
    """Concrete apron slabs: lighter, with expansion joints."""
    img = new_img(T, T)
    rect(img, 0, 0, T, T, P.QUAY)
    grain(img, P.QUAY, P.QUAY_D, P.QUAY_L, 0.09, seed=3)
    hline(img, 0, 0, T, P.QUAY_L)
    vline(img, 0, 0, T, P.QUAY_L)
    hline(img, 0, T - 1, T, P.QUAY_D)
    vline(img, T - 1, 0, T, P.QUAY_D)
    save(img, "gr_quay")


def gen_dirt():
    """Unbought land: bare dirt with pebbles and weed tufts. 3 variants."""
    for v in range(3):
        img = new_img(T, T)
        rect(img, 0, 0, T, T, P.DIRT)
        grain(img, P.DIRT, P.DIRT_D, P.DIRT_L, 0.13, seed=40 + v)
        patch(img, 4 + v * 5, 5 + v * 3, 3, 2, P.DIRT_D, seed=50 + v)
        for wx, wy in ((3 + v * 4, 12 - v * 3), (12 - v * 3, 4 + v * 4)):
            px(img, wx, wy, P.GRASS)
            px(img, wx + 1, wy - 1, P.GRASS_D)
            px(img, wx - 1, wy - 1, P.GRASS_D)
        save(img, "gr_dirt_%d" % v)


def gen_grass():
    """Grass verge tile."""
    img = new_img(T, T)
    rect(img, 0, 0, T, T, P.GRASS)
    grain(img, P.GRASS, P.GRASS_D, P.GRASS_L, 0.15, seed=8)
    for bx, by in ((2, 4), (9, 3), (5, 11), (13, 9)):
        px(img, bx, by, P.GRASS_L)
        px(img, bx, by - 1, P.GRASS_L)
        px(img, bx + 1, by, P.GRASS_D)
    save(img, "gr_grass")


def gen_water():
    """Fallback still-water tile; the live surface is a shader."""
    img = new_img(T, T)
    rect(img, 0, 0, T, T, P.SEA)
    speckle(img, 0, 0, T, T, [P.SEA_DEEP, P.SEA_LIGHT], 0.10, seed=60)
    save(img, "gr_water")


def gen_quay_edge():
    """Vertical quay coping where the concrete meets the water: 10 wide x 16."""
    img = new_img(10, T)
    rect(img, 0, 0, 7, T, P.QUAY_D)
    vline(img, 0, 0, T, P.QUAY_L)
    vline(img, 1, 0, T, P.QUAY)
    speckle(img, 2, 0, 4, T, [P.QUAY, P.QUAY_D], 0.18, seed=9)
    # slab joints
    for y in range(0, T, 8):
        hline(img, 0, y, 7, (120, 110, 100, 255))
    # algae stripe at the waterline
    vline(img, 7, 0, T, (86, 112, 92, 255))
    for y in range(T):
        if (y * 5) % 7 < 3:
            px(img, 8, y, (72, 100, 84, 255))
    save(img, "gr_quay_edge")


def gen_curb():
    """Kerb + gutter between the grass verge and the paved yard. 10 wide x 16.
    Column 0-1 is grass side, 2-4 kerb stone, 5-9 gutter fading into asphalt."""
    img = new_img(10, T)
    # gutter strip (pavement side): slightly lighter, collects grit
    rect(img, 5, 0, 5, T, P.YARD_L)
    speckle(img, 5, 0, 5, T, [P.YARD, P.YARD_D], 0.22, seed=31)
    # kerb stone with a lit top face
    rect(img, 2, 0, 3, T, P.QUAY)
    vline(img, 2, 0, T, P.QUAY_L)
    vline(img, 4, 0, T, P.QUAY_D)
    for y in range(0, T, 8):          # stone joints
        hline(img, 2, y, 3, P.QUAY_D)
    # grass creeping over the kerb, uneven so the seam never reads as a line
    for y in range(T):
        reach = (y * 7) % 3
        for x in range(0, 2 + reach):
            px(img, x, y, P.GRASS if (x + y) % 3 else P.GRASS_D)
        if (y * 5) % 4 == 0:
            px(img, 2, y, P.GRASS_D)
    save(img, "gr_curb")


def gen_seam_tufts():
    """Weeds and gravel that scatter along a pavement seam. 4 x 10x8."""
    frames = []
    for v in range(4):
        img = new_img(10, 8)
        for i in range(2 + v):
            gx = (i * 3 + v) % 9
            gy = 3 + ((i * 5 + v) % 4)
            px(img, gx, gy, P.GRASS_D)
            px(img, gx, gy - 1, P.GRASS)
            if i % 2 == 0:
                px(img, gx + 1, gy, P.GRASS_D)
        for i in range(3):
            px(img, (i * 4 + v * 2) % 10, (i * 3 + v) % 8, P.DIRT_D)
        frames.append(img)
    save(sheet(frames), "gr_seam_tufts")


def gen_water_edge_foam():
    """Foam lapping the quay: 16x6, 4 frames."""
    frames = []
    for f in range(4):
        img = new_img(T, 6)
        for x in range(T):
            h = 1 + ((x * 3 + f * 2) % 3)
            for y in range(h):
                px(img, x, y, P.FOAM if y == 0 else P.SEA_SPARK)
        for bx, bf in ((3, 0), (10, 1), (14, 2)):
            if (f - bf) % 4 < 2:
                px(img, bx, 2, P.FOAM)
        frames.append(img)
    save(sheet(frames), "gr_foam")


def gen_road_markings():
    """Lane paint decals: dashed centre line and a bay outline corner."""
    dash = new_img(T, 4)
    for x in range(0, T, 8):
        rect(dash, x, 1, 5, 2, P.PAINT_W)
    save(dash, "gr_lane_dash")

    solid = new_img(T, 3)
    hline(solid, 0, 1, T, P.PAINT_Y)
    save(solid, "gr_lane_solid")

    # container bay outline: 44x40 painted rectangle with corner ticks
    bay = new_img(46, 42)
    for x in range(0, 46, 2):
        px(bay, x, 0, P.PAINT_Y)
        px(bay, x, 41, P.PAINT_Y)
    for y in range(0, 42, 2):
        px(bay, 0, y, P.PAINT_Y)
        px(bay, 45, y, P.PAINT_Y)
    for i in range(5):
        px(bay, i, 1, P.PAINT_W)
        px(bay, 45 - i, 40, P.PAINT_W)
    save(bay, "gr_bay_marks")


def gen_dirt_to_yard():
    """Transition strip: paved yard meeting bare dirt (16x8)."""
    img = new_img(T, 8)
    rect(img, 0, 0, T, 3, P.YARD_D)
    for x in range(T):
        depth = 3 + ((x * 7) % 3)
        for y in range(3, depth + 2):
            px(img, x, y, P.DIRT_D)
        for y in range(depth + 2, 8):
            px(img, x, y, P.DIRT)
    speckle(img, 0, 3, T, 5, [P.DIRT_L, P.DIRT_D], 0.16, seed=12)
    save(img, "gr_dirt_edge")


if __name__ == "__main__":
    print("ground:")
    gen_yard()
    gen_quay()
    gen_dirt()
    gen_grass()
    gen_water()
    gen_quay_edge()
    gen_curb()
    gen_seam_tufts()
    gen_water_edge_foam()
    gen_road_markings()
    gen_dirt_to_yard()
