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
    """Portal legs + machinery house standing on the quay rails."""
    w, h = 30, 46
    img = new_img(w, h)
    # sill beams running along the quay (in Y)
    rect(img, 2, 2, 6, h - 4, P.CRANE_D)
    rect(img, w - 8, 2, 6, h - 4, P.CRANE_D)
    hline(img, 2, 2, 6, P.CRANE)
    hline(img, w - 8, 2, 6, P.CRANE)
    # bogies on the rails
    for y in (4, h - 10):
        rect(img, 1, y, 8, 6, P.STEEL_D)
        rect(img, w - 9, y, 8, 6, P.STEEL_D)
        hline(img, 1, y, 8, P.STEEL)
        hline(img, w - 9, y, 8, P.STEEL)
    # machinery house bridging the legs
    rect(img, 6, 12, w - 12, 22, P.CRANE)
    hline(img, 6, 12, w - 12, P.CRANE_L)
    vline(img, 6, 12, 22, P.CRANE_L)
    vline(img, w - 7, 12, 22, P.CRANE_D)
    hline(img, 6, 33, w - 12, P.CRANE_D)
    speckle(img, 7, 13, w - 14, 20, [P.CRANE_D], 0.07, seed=2)
    # roof hatch + vents
    rect(img, 11, 17, 8, 6, P.STEEL_D)
    hline(img, 11, 17, 8, P.STEEL)
    for vy in (26, 29):
        hline(img, 10, vy, 10, P.CRANE_D)
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
    """Rubber-tyred gantry straddling a yard block, portal running in X."""
    w, h = 72, 34
    img = new_img(w, h)
    # top beam (spans the block)
    rect(img, 4, 4, w - 8, 8, P.TEAL)
    hline(img, 4, 4, w - 8, P.TEAL_L)
    hline(img, 4, 11, w - 8, P.TEAL_D)
    for x in range(8, w - 8, 7):     # lattice ticks
        vline(img, x, 5, 6, P.TEAL_D)
    # legs at both ends, running down in Y
    for lx in (0, w - 12):
        rect(img, lx, 2, 12, h - 4, P.TEAL)
        hline(img, lx, 2, 12, P.TEAL_L)
        vline(img, lx + 11, 2, h - 4, P.TEAL_D)
        # rubber tyres, two per corner
        for ty in (4, h - 12):
            rect(img, lx + 1, ty, 4, 8, P.TIRE)
            rect(img, lx + 7, ty, 4, 8, P.TIRE)
            px(img, lx + 2, ty + 1, P.TIRE_L)
            px(img, lx + 8, ty + 1, P.TIRE_L)
    # operator cab hanging off the near leg
    rect(img, w - 14, 20, 10, 9, P.SAFETY)
    hline(img, w - 14, 20, 10, P.SAFETY_L)
    rect(img, w - 12, 22, 6, 5, P.GLASS)
    px(img, w - 8, 23, (200, 236, 244, 255))
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
