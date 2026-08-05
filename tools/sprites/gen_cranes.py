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
    """Crane barge seen from above, 46x62."""
    w, h = 46, 62
    img = new_img(w, h)
    # pontoon
    rect(img, 2, 4, w - 4, h - 8, P.SAFETY_D)
    hline(img, 2, 4, w - 4, P.SAFETY)
    vline(img, 2, 4, h - 8, P.SAFETY)
    speckle(img, 3, 5, w - 6, h - 10, [P.SAFETY_D], 0.05, seed=4)
    for cy in (6, h - 10):           # rounded corners
        for cx in (2, w - 3):
            px(img, cx, cy - 2, P.TRANSPARENT)
    # slew ring + house
    rect(img, 12, 24, 22, 20, P.CRANE)
    hline(img, 12, 24, 22, P.CRANE_L)
    vline(img, 33, 24, 20, P.CRANE_D)
    rect(img, 16, 28, 8, 6, P.GLASS)
    # lattice jib pointing up (bow)
    for i in range(20):
        y = 24 - i
        half = 5 - i // 6
        rect(img, 23 - half, y, half * 2, 1, P.CRANE_D if i % 3 else P.CRANE)
    rect(img, 20, 2, 7, 4, P.STEEL_D)   # jib head
    save(outline(img), "flutuante")


if __name__ == "__main__":
    print("cranes:")
    gen_sts_beam()
    gen_sts_base()
    gen_sts_trolley()
    gen_spreader()
    gen_rtg()
    gen_rtg_trolley()
    gen_floating_crane()
