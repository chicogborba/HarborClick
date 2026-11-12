"""Top-down quay cranes: STS (straddles the quay, boom reaching over the ship)
and RTG (straddles a container block in the yard).

Layout convention: X runs yard -> water, Y runs along the quay.
"""
import palette as P
from common import new_img, rect, hline, vline, px, outline, save
from gen_vehicles import (body, glass, beacon, hazard, INK, CHROME, GLINT,
                          BEACON)

CRANE_XD = (108, 40, 38, 255)
CRANE_RAMP = (P.CRANE_D, P.CRANE, P.CRANE_L)
TEAL_XD = (26, 70, 70, 255)
TEAL_RAMP = (P.TEAL_D, P.TEAL, P.TEAL_L)
WHEEL = (34, 32, 38, 255)


# ------------------------------------------------------------------ STS
STS_BEAM_W, STS_BEAM_H = 128, 16
STS_BASE_X = 26          # where the portal legs sit inside the beam sprite


def gen_sts_beam():
    """Boom + backreach seen from above: a lattice girder running in X.

    Two box chords with the trolley rails on them, K-bracing between, a
    grated walkway down the landward half and a hazard-taped tip with its
    aircraft lamp — the boom is the longest thing on the screen, so it is the
    one that most needs to read as engineering rather than as a red ribbon."""
    img = new_img(STS_BEAM_W, STS_BEAM_H)
    W = STS_BEAM_W
    # the web between the chords, in shade, so the bracing has something to sit on
    rect(img, 0, 5, W, 6, CRANE_XD)
    # two main chords, each a lit top and a dark underside
    for y0 in (2, 11):
        hline(img, 0, y0, W, P.CRANE_L)
        hline(img, 0, y0 + 1, W, P.CRANE)
        hline(img, 0, y0 + 2, W, P.CRANE_D)
    # trolley rails riding the chords
    hline(img, 0, 2, W, P.STEEL_L)
    hline(img, 0, 13, W, P.STEEL_D)
    # K-bracing: one diagonal pair per 8px panel, a batten at every node
    for x in range(1, W - 8, 8):
        for i in range(6):
            px(img, x + i, 5 + i, P.CRANE)
            px(img, x + 7 - i, 5 + i, P.CRANE_D)
        vline(img, x + 7, 5, 6, P.CRANE)
        px(img, x + 7, 5, P.CRANE_L)
    # grated walkway along the backreach (landward of the legs)
    for x in range(2, STS_BASE_X - 2, 2):
        px(img, x, 7, P.STEEL)
        px(img, x + 1, 8, P.STEEL_D)
    # hinge where the boom lifts, just seaward of the legs
    rect(img, STS_BASE_X + 30, 1, 3, 14, P.STEEL_D)
    vline(img, STS_BASE_X + 30, 1, 14, P.STEEL_L)
    px(img, STS_BASE_X + 31, 7, CHROME)
    # tapered boom tip (seaward end, right), taped, with its lamp
    for i in range(6):
        for y in range(0, 16):
            if y < 3 + i or y > 12 - i:
                px(img, W - 1 - i, y, P.TRANSPARENT)
    hazard(img, W - 14, 7, 8, 2)
    px(img, W - 4, 7, P.RED_LIGHT)
    px(img, W - 4, 8, P.RED_LIGHT)
    save(outline(img), "sts_beam")


def gen_sts_base():
    """Portal legs, sills, bogies and machinery house, seen from above.

    A ship-to-shore crane is the biggest object on the terminal, so from above
    it is mostly *structure*: two sill beams on the quay rails, four bogies
    under them, a lattice portal joining them and the machinery house bridging
    the top. The first version drew a flat slab with a hatch on it, which read
    as a shipping container with a lid; the second speckled it, which read as
    rust. This one is clean plate with seams, and the detail is equipment."""
    w, h = 30, 46
    img = new_img(w, h)
    # Four bogies first, each a truck of two wheels on the rail.
    for y in (1, h - 10):
        for bx in (1, w - 9):
            rect(img, bx, y, 8, 9, P.STEEL_D)
            hline(img, bx, y, 8, P.STEEL_L)
            vline(img, bx, y, 9, P.STEEL)
            for wy in (y + 2, y + 6):
                rect(img, bx + 1, wy, 6, 2, WHEEL)
                px(img, bx + 1, wy, P.TIRE_L)
    # Sill beams running along the quay, with lit top edges.
    for sx in (2, w - 8):
        body(img, sx, 9, 6, h - 18, CRANE_RAMP)
        for sy in range(13, h - 12, 6):
            hline(img, sx + 1, sy, 4, P.CRANE_D)        # plate seams
    # Portal between the sills: braced legs, seen down through the frame.
    rect(img, 8, 8, w - 16, h - 16, CRANE_XD)
    for i in range(0, w - 16):
        px(img, 8 + i, 9 + (i * 2) % (h - 18), P.CRANE_D)
        px(img, w - 9 - i, 9 + (i * 2) % (h - 18), P.CRANE_D)
    # Machinery house bridging the legs.
    body(img, 5, 12, w - 10, 22, CRANE_RAMP)
    for sx in (11, 18):
        vline(img, sx, 13, 20, P.CRANE_D)               # roof sheet seams
        vline(img, sx + 1, 13, 20, P.CRANE_L)
    # walkway with a handrail round the landward side, and the access ladder
    hline(img, 6, 14, w - 12, CRANE_XD)
    for rx in range(6, w - 6, 2):
        px(img, rx, 14, P.STEEL_L)
    vline(img, 6, 15, 18, CRANE_XD)
    for ly in range(16, 32, 2):
        px(img, 6, ly, P.STEEL_L)
    # roof hatch with the lit control room showing through
    rect(img, 12, 18, 7, 6, P.STEEL_D)
    hline(img, 12, 18, 7, P.STEEL_L)
    rect(img, 13, 20, 5, 3, P.WINDOW_LIT)
    px(img, 13, 20, (255, 244, 200, 255))
    # hoist-motor vents, two louvred panels
    for vy in (26, 28, 30):
        hline(img, 9, vy, 5, CRANE_XD)
        hline(img, 16, vy, 5, CRANE_XD)
    beacon(img, 20, 15)
    # Hazard tape down the seaward sill, as every quay crane wears.
    for cy in range(10, h - 11, 1):
        px(img, w - 4, cy, P.SAFETY_L if (cy // 2) % 2 == 0 else INK)
    save(outline(img), "sts_base")


def gen_sts_trolley():
    """Trolley + operator cab that runs out along the beam."""
    img = new_img(18, 20)
    # machinery deck: hoist drums under a lifted cover
    body(img, 2, 2, 14, 10)
    rect(img, 4, 4, 10, 6, P.SAFETY_D)
    hline(img, 4, 4, 10, P.SAFETY)
    for dx in (5, 10):
        rect(img, dx, 5, 3, 4, P.STEEL_D)               # the two rope drums
        vline(img, dx, 5, 4, P.STEEL_L)
        px(img, dx + 1, 6, INK)
        px(img, dx + 1, 8, INK)
    # wheels on the boom rails
    for wx in (2, 13):
        px(img, wx, 1, CHROME)
        px(img, wx + 2, 1, CHROME)
    beacon(img, 13, 3)
    # cab hung below, glass floor looking down at the hold
    rect(img, 4, 12, 10, 7, INK)
    glass(img, 5, 13, 8, 5)
    save(outline(img), "sts_trolley")


def gen_spreader():
    """Container-sized spreader frame that grabs boxes (24x13)."""
    img = new_img(24, 13)
    rect(img, 1, 2, 22, 9, P.SAFETY)
    hline(img, 1, 2, 22, P.SAFETY_L)
    vline(img, 1, 2, 9, P.SAFETY_L)
    hline(img, 1, 10, 22, P.SAFETY_D)
    vline(img, 22, 2, 9, P.SAFETY_D)
    # open middle so the container shows through when carried
    rect(img, 4, 4, 16, 5, P.TRANSPARENT)
    # headblock in the middle of each long side, where the ropes land
    for hy in (2, 9):
        rect(img, 10, hy, 4, 2, P.STEEL_D)
        hline(img, 10, hy, 4, P.STEEL_L)
    # twistlocks at the corners
    for cx in (1, 21):
        for cy in (2, 9):
            rect(img, cx, cy, 2, 2, P.STEEL_D)
            px(img, cx, cy, CHROME)
    save(outline(img), "spreader")


# ------------------------------------------------------------------ RTG
def gen_rtg():
    """Rubber-tyred gantry straddling a yard block, portal running in X.

    The things that make an RTG recognisable from above: a lattice top beam
    with real cross-bracing, eight tyres in four bogies, a cab on an arm off
    the near leg, a ladder and a power cabinet on the far one, hazard tape on
    both sills. Same plate-and-seam language as the quay crane, in teal."""
    w, h = 72, 34
    img = new_img(w, h)
    # Top beam: two box chords with a braced web between them.
    rect(img, 4, 3, w - 8, 10, TEAL_XD)
    for y0 in (3, 10):
        hline(img, 4, y0, w - 8, P.TEAL_L)
        hline(img, 4, y0 + 1, w - 8, P.TEAL)
        hline(img, 4, y0 + 2, w - 8, P.TEAL_D)
    hline(img, 12, 3, w - 24, P.STEEL_L)                # trolley rail
    for x in range(13, w - 20, 8):
        for i in range(4):
            px(img, x + i, 6 + i, P.TEAL)
            px(img, x + 7 - i, 6 + i, P.TEAL_D)
        vline(img, x + 7, 6, 4, P.TEAL)
    # Legs at both ends, running down in Y.
    for index, lx in enumerate((0, w - 12)):
        # Four tyres a side, in two bogies.
        for ty in (1, h - 10):
            for tx in (lx + 1, lx + 7):
                rect(img, tx, ty, 4, 9, P.TIRE)
                vline(img, tx, ty, 9, P.TIRE_L)
                for by in range(ty + 1, ty + 9, 2):
                    px(img, tx + 3, by, INK)
        body(img, lx + 1, 4, 10, h - 8, TEAL_RAMP)
        for sy in (11, 22):
            hline(img, lx + 2, sy, 8, P.TEAL_D)         # plate seams
        # hazard tape along the sill's outer edge
        ox = lx + 2 if index == 0 else lx + 9
        for cy in range(6, h - 6):
            px(img, ox, cy, P.SAFETY_L if (cy // 2) % 2 == 0 else INK)
    # far leg: access ladder and the diesel/power cabinet
    for ly in range(13, 21, 2):
        hline(img, 5, ly, 3, P.STEEL_L)
    rect(img, 4, 23, 6, 5, P.STEEL_D)
    hline(img, 4, 23, 6, P.STEEL_L)
    px(img, 6, 25, P.GREEN_LIGHT)
    px(img, 8, 25, INK)
    beacon(img, 6, 6)
    # Operator cab on an arm off the near leg, glazed and lit.
    rect(img, w - 20, 19, 6, 3, P.TEAL_D)
    body(img, w - 23, 16, 12, 12)
    rect(img, w - 21, 18, 8, 8, INK)
    glass(img, w - 20, 19, 7, 6)
    beacon(img, w - 14, 17)
    save(outline(img), "rtg")


def gen_rtg_trolley():
    """The RTG's trolley: a hoist deck with two drums and a service hatch."""
    img = new_img(20, 12)
    body(img, 2, 2, 16, 8, TEAL_RAMP)
    for dx in (4, 12):
        rect(img, dx, 4, 4, 4, P.STEEL_D)
        hline(img, dx, 4, 4, P.STEEL_L)
        px(img, dx + 1, 6, INK)
        px(img, dx + 2, 6, INK)
    rect(img, 9, 4, 2, 4, P.TEAL_D)
    px(img, 9, 4, P.SAFETY_L)
    for wx in (2, 16):
        px(img, wx, 1, CHROME)
        px(img, wx + 1, 10, CHROME)
    save(outline(img), "rtg_trolley")


# ---------------------------------------------------- floating crane barge
def gen_floating_crane():
    """Crane barge seen from above, 46x62, bow up.

    A pontoon with a revolving house aft and a lattice boom over the bow,
    hook block at its head. The old one was an orange rectangle with a red
    box on it — at a glance, a shipping container that had fallen in."""
    w, h = 46, 62
    img = new_img(w, h)
    hull = P.ramp((70, 92, 112), 5, hue_shift=12.0, dark=0.4, light=0.5)
    deck = P.ramp((150, 142, 128), 5, hue_shift=10.0, dark=0.35, light=0.45)
    red = P.ramp(P.CRANE, 5, hue_shift=14.0, dark=0.4, light=0.5)
    yel = P.ramp(P.SAFETY, 5, hue_shift=12.0)
    steel = P.ramp(P.STEEL, 5)
    # pontoon: a hull band round a working deck, corners chamfered
    rect(img, 2, 18, w - 4, h - 20, hull[2])
    for cx, cy in ((2, 18), (w - 3, 18), (2, h - 3), (w - 3, h - 3)):
        px(img, cx, cy, (0, 0, 0, 0))
    vline(img, 2, 19, h - 22, hull[4])
    vline(img, w - 3, 19, h - 22, hull[1])
    hline(img, 3, 18, w - 6, hull[4])
    hline(img, 3, h - 3, w - 6, hull[0])
    rect(img, 5, 21, w - 10, h - 26, deck[2])
    for y in range(21, h - 5, 4):                     # deck plate seams
        hline(img, 5, y, w - 10, deck[1])
    for y in range(22, h - 5, 6):                     # fender tyres along the sides
        px(img, 1, y, (40, 36, 42, 255))
        px(img, w - 2, y, (40, 36, 42, 255))
    for bx, by in ((7, 23), (w - 9, 23), (7, h - 8), (w - 9, h - 8)):
        rect(img, bx, by, 2, 2, steel[1])              # bitts
        px(img, bx, by, steel[4])
    # revolving house: machinery and counterweight, aft
    rect(img, 12, 34, 22, 18, red[2])
    rect(img, 12, 34, 22, 1, red[4])
    vline(img, 12, 35, 17, red[3])
    vline(img, 33, 35, 17, red[0])
    hline(img, 12, 51, 22, red[0])
    rect(img, 14, 46, 18, 4, steel[1])                 # counterweight block
    rect(img, 14, 46, 18, 1, steel[3])
    for vx in range(16, 31, 4):
        px(img, vx, 48, steel[0])
    rect(img, 15, 37, 6, 5, (54, 98, 124, 255))        # operator's cab glass
    px(img, 15, 37, (200, 236, 244, 255))
    rect(img, 26, 37, 5, 3, steel[2])                  # winch drum housing
    # A-frame at the boom foot
    for i in range(6):
        px(img, 16 + i // 2, 34 - i, yel[3])
        px(img, 29 - i // 2, 34 - i, yel[1])
    # lattice boom over the bow: a shaded web between two chords, laced
    from PIL import ImageDraw
    top = 3

    def half_at(y):
        k = (34 - y) / (34 - top)
        return int(round(6 - k * 3))

    for y in range(top, 34):
        hw = half_at(y)
        for x in range(23 - hw + 1, 22 + hw):
            px(img, x, y, P.mix(yel[0], hull[1], 0.55))
    draw = ImageDraw.Draw(img)
    panel = 6
    for i, y in enumerate(range(top, 34 - panel + 1, panel)):
        y1 = y + panel
        l0, r0 = 23 - half_at(y) + 1, 22 + half_at(y) - 1
        l1, r1 = 23 - half_at(y1) + 1, 22 + half_at(y1) - 1
        if i % 2 == 0:
            draw.line([(l0, y), (r1, y1)], fill=yel[2])
        else:
            draw.line([(r0, y), (l1, y1)], fill=yel[2])
        draw.line([(l1, y1), (r1, y1)], fill=yel[1])     # batten
    for y in range(top, 34):
        hw = half_at(y)
        px(img, 23 - hw, y, yel[3])
        px(img, 22 + hw, y, yel[1])
    rect(img, 19, top - 1, 8, 3, yel[2])               # boom head sheaves
    rect(img, 19, top - 1, 8, 1, yel[4])
    # hook block hanging below the head, and its shadow on the water
    rect(img, 21, top + 3, 4, 3, steel[1])
    px(img, 22, top + 6, steel[3])
    img = outline(img)
    save(img, "flutuante")


if __name__ == "__main__":
    print("cranes:")
    gen_sts_beam()
    gen_sts_base()
    gen_sts_trolley()
    gen_spreader()
    gen_rtg()
    gen_rtg_trolley()
    gen_floating_crane()
