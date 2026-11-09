"""Top-down quay cranes: STS (straddles the quay, boom reaching over the ship)
and RTG (straddles a container block in the yard).

Layout convention: X runs yard -> water, Y runs along the quay.
"""
import palette as P
from common import new_img, rect, hline, vline, px, outline, save, speckle


# ------------------------------------------------------------------ STS
STS_BEAM_W, STS_BEAM_H = 128, 16
STS_BASE_X = 26          # where the portal legs sit inside the beam sprite


def gen_sts_beam():
    """Boom + backreach seen from above: a lattice girder running in X."""
    img = new_img(STS_BEAM_W, STS_BEAM_H)
    # two main chords
    hline(img, 0, 3, STS_BEAM_W, P.CRANE)
    hline(img, 0, 4, STS_BEAM_W, P.CRANE_L)
    hline(img, 0, 11, STS_BEAM_W, P.CRANE)
    hline(img, 0, 12, STS_BEAM_W, P.CRANE_D)
    # lattice bracing between the chords
    for x in range(2, STS_BEAM_W - 2, 8):
        for i in range(6):
            px(img, x + i, 5 + i, P.CRANE_D)
            px(img, x + 7 - i, 5 + i, P.CRANE_D)
    # trolley rails on the top chord
    hline(img, 0, 2, STS_BEAM_W, P.STEEL_L)
    hline(img, 0, 13, STS_BEAM_W, P.STEEL_D)
    # tapered boom tip (seaward end, right)
    for i in range(6):
        for y in range(0, 16):
            if y < 3 + i or y > 12 - i:
                px(img, STS_BEAM_W - 1 - i, y, P.TRANSPARENT)
    save(outline(img), "sts_beam")


def gen_sts_base():
    """Portal legs, sills, bogies and machinery house, seen from above.

    A ship-to-shore crane is the biggest object on the terminal, so from above
    it is mostly *structure*: two sill beams on the quay rails, four bogies
    under them, a lattice portal joining them and the machinery house bridging
    the top. The first version drew a flat slab with a hatch on it, which read
    as a shipping container with a lid.
    """
    w, h = 30, 46
    img = new_img(w, h)
    # Sill beams running along the quay, with lit top edges.
    for sx in (2, w - 8):
        rect(img, sx, 1, 6, h - 2, P.CRANE_D)
        vline(img, sx, 1, h - 2, P.CRANE)
        vline(img, sx + 5, 1, h - 2, (110, 42, 40, 255))
    # Four bogies, each a truck of two wheels on the rail.
    for y in (2, h - 10):
        for bx in (1, w - 9):
            rect(img, bx, y, 8, 8, P.STEEL_D)
            hline(img, bx, y, 8, P.STEEL_L)
            for wy in (y + 1, y + 5):
                rect(img, bx + 1, wy, 6, 2, (34, 32, 38, 255))
    # Lattice portal between the sills: the crane's own legs, braced.
    rect(img, 8, 8, w - 16, h - 16, P.CRANE_D)
    for y in range(9, h - 9, 4):
        hline(img, 8, y, w - 16, (108, 40, 38, 255))
    for i in range(0, h - 18, 3):
        px(img, 9 + i % (w - 18), 9 + i, (150, 60, 58, 255))
    # Machinery house bridging the legs, with a lit control room.
    rect(img, 5, 13, w - 10, 20, P.CRANE)
    hline(img, 5, 13, w - 10, P.CRANE_L)
    vline(img, 5, 13, 20, P.CRANE_L)
    vline(img, w - 6, 13, 20, P.CRANE_D)
    hline(img, 5, 32, w - 10, P.CRANE_D)
    speckle(img, 6, 14, w - 12, 18, [P.CRANE_D], 0.06, seed=2)
    # Roof walkway, hatch and two vents: the detail that gives it scale.
    rect(img, 7, 16, w - 14, 3, (108, 40, 38, 255))
    rect(img, 10, 21, 10, 7, P.STEEL_D)
    hline(img, 10, 21, 10, P.STEEL_L)
    rect(img, 12, 23, 6, 3, P.WINDOW_LIT)
    for vy in (29, 31):
        hline(img, 9, vy, 12, (108, 40, 38, 255))
    # Safety chevrons on the seaward sill, as every quay crane wears.
    for cy in range(4, h - 6, 6):
        px(img, w - 4, cy, P.SAFETY)
        px(img, w - 3, cy + 1, P.SAFETY)
    save(outline(img), "sts_base")


def gen_sts_trolley():
    """Trolley + operator cab that runs out along the beam."""
    img = new_img(18, 20)
    rect(img, 2, 2, 14, 10, P.SAFETY)
    hline(img, 2, 2, 14, P.SAFETY_L)
    vline(img, 15, 2, 10, P.SAFETY_D)
    hline(img, 2, 11, 14, P.SAFETY_D)
    # cab glass looking down at the hold
    rect(img, 5, 13, 8, 5, P.GLASS)
    hline(img, 5, 13, 8, P.GLASS_D)
    px(img, 11, 14, (200, 236, 244, 255))
    save(outline(img), "sts_trolley")


def gen_spreader():
    """Container-sized spreader frame that grabs boxes (24x13)."""
    img = new_img(24, 13)
    rect(img, 1, 2, 22, 9, P.SAFETY)
    hline(img, 1, 2, 22, P.SAFETY_L)
    hline(img, 1, 10, 22, P.SAFETY_D)
    # open middle so the container shows through when carried
    rect(img, 4, 4, 16, 5, P.TRANSPARENT)
    # twistlocks at the corners
    for cx in (1, 21):
        for cy in (2, 9):
            rect(img, cx, cy, 2, 2, P.STEEL_D)
    save(outline(img), "spreader")


# ------------------------------------------------------------------ RTG
def gen_rtg():
    """Rubber-tyred gantry straddling a yard block, portal running in X.

    Redrawn with the things that make an RTG recognisable from above: a lattice
    top beam with real cross-bracing rather than tick marks, eight tyres in four
    bogies with the steering pair called out, a cab on an arm off the near leg,
    and safety chevrons on both legs. The first version was two blocks and a
    bar, which read as a bench.
    """
    w, h = 72, 34
    img = new_img(w, h)
    # Top beam: two chords with a braced web between them.
    rect(img, 4, 3, w - 8, 10, P.TEAL_D)
    hline(img, 4, 3, w - 8, P.TEAL_L)
    hline(img, 4, 4, w - 8, P.TEAL)
    hline(img, 4, 11, w - 8, P.TEAL)
    hline(img, 4, 12, w - 8, (26, 70, 70, 255))
    for x in range(6, w - 10, 8):
        for i in range(6):
            px(img, x + i, 5 + i, P.TEAL)
            px(img, x + 7 - i, 5 + i, P.TEAL)
    # Legs at both ends, running down in Y, with a lit inner face.
    for lx in (0, w - 12):
        rect(img, lx, 1, 12, h - 2, P.TEAL_D)
        rect(img, lx + 1, 2, 10, h - 4, P.TEAL)
        hline(img, lx + 1, 2, 10, P.TEAL_L)
        vline(img, lx + 11, 1, h - 2, (26, 70, 70, 255))
        # Four tyres a side, in two bogies. The forward pair is the steering
        # one, so it is drawn turned a pixel out of line.
        for index, ty in enumerate((2, h - 11)):
            for tx in (lx + 1, lx + 7):
                rect(img, tx, ty, 4, 9, P.TIRE)
                hline(img, tx, ty, 4, P.TIRE_L)
                px(img, tx + 1, ty + 4, P.TIRE_L)
                if index == 0:
                    px(img, tx + 3, ty, P.TIRE_L)
        # Safety chevrons up the leg.
        for cy in range(13, h - 13, 4):
            px(img, lx + 4, cy, P.SAFETY)
            px(img, lx + 5, cy + 1, P.SAFETY)
    # Operator cab on an arm off the near leg, glazed and lit.
    rect(img, w - 20, 19, 6, 3, P.TEAL_D)
    rect(img, w - 22, 17, 11, 11, P.SAFETY_D)
    rect(img, w - 21, 18, 9, 9, P.SAFETY)
    hline(img, w - 21, 18, 9, P.SAFETY_L)
    rect(img, w - 20, 20, 7, 5, P.GLASS)
    px(img, w - 15, 21, (200, 236, 244, 255))
    save(outline(img), "rtg")


def gen_rtg_trolley():
    img = new_img(20, 12)
    rect(img, 2, 2, 16, 8, P.TEAL)
    hline(img, 2, 2, 16, P.TEAL_L)
    hline(img, 2, 9, 16, P.TEAL_D)
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
