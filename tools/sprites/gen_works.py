"""The building site a parcel is made on (`scripts/world/land_works_site.gd`).

Top-down, like every machine in the yard, but these face EAST (right): the
works advance west to east across the strip and the machines drive along it,
so the game only ever mirrors them. The tower crane's jib is one horizontal
strip the game rotates about its mast (`works_jib`, pivot at JIB_PIVOT).

Sheets:
- works_excavator  4 frames 44x22: the dig cycle (reach, bite, curl, lift).
- works_dumper     2 frames 32x16: empty, loaded.
- works_mixer      4 frames 34x16: the drum turning.
- works_roller     2 frames 26x16: drum stripes rolling.
- works_jib        1 frame 84x11: counter-jib + weights | slewing ring | jib.
- works_crane_base 1 frame 16x16: the mast's foot seen from above.
- works_trolley    1 frame 7x7.
- works_loads      3 frames 12x10: rebar bundle, concrete skip, brick pallet.
- works_props      6 frames 20x18: site cabin half, toilet, rebar stack, pipes,
                   spoil heap, generator.
- works_cabin      1 frame 34x20: the site office.
"""
import palette as P
from common import new_img, rect, hline, vline, px, outline, save, sheet, speckle

INK = (40, 34, 44, 255)
GLINT = (214, 242, 248, 255)
BEACON = [(214, 96, 28, 255), (255, 170, 60, 255), (255, 236, 170, 255)]
HAZARD_K = (52, 46, 54, 255)
CHROME = (206, 212, 220, 255)
REBAR = (160, 82, 52, 255)
REBAR_L = (204, 120, 76, 255)
CONCRETE = (178, 176, 170, 255)
CONCRETE_D = (140, 138, 134, 255)
CONCRETE_L = (206, 204, 198, 255)
BRICK = (184, 86, 64, 255)
BRICK_L = (220, 124, 92, 255)
WOOD = (160, 118, 70, 255)
WOOD_D = (118, 84, 50, 255)
DRUM_W = (232, 226, 214, 255)
DRUM_W_D = (186, 180, 170, 255)
BLUE = (64, 110, 170, 255)
BLUE_L = (106, 152, 206, 255)
BLUE_D = (42, 76, 124, 255)
GREEN = (72, 150, 96, 255)
GREEN_D = (48, 108, 66, 255)

JIB_PIVOT = (26, 5)


def tyres(img, x, y, w, h):
    rect(img, x, y, w, h, P.TIRE)
    hline(img, x, y, w, P.TIRE_L)
    for tx in range(x + 1, x + w, 2):
        px(img, tx, y + h - 1, INK)


def body(img, x, y, w, h, ramp=None):
    d, m, l = ramp or (P.SAFETY_D, P.SAFETY, P.SAFETY_L)
    rect(img, x, y, w, h, m)
    hline(img, x, y, w, l)
    vline(img, x, y, h, l)
    hline(img, x, y + h - 1, w, d)
    vline(img, x + w - 1, y, h, d)


def glass(img, x, y, w, h):
    rect(img, x, y, w, h, P.GLASS)
    hline(img, x, y, w, P.GLASS_D)
    vline(img, x, y, h, P.GLASS_D)
    for i in range(min(w - 1, 3)):
        px(img, x + 1 + i, y + h - 2 - i if h > 2 else y, GLINT)


def beacon(img, x, y):
    rect(img, x, y, 2, 2, BEACON[1])
    px(img, x, y, BEACON[2])
    px(img, x + 1, y + 1, BEACON[0])


def hazard(img, x, y, w, h=2):
    for i in range(w):
        for j in range(h):
            px(img, x + i, y + j, P.SAFETY_L if ((i + j) // 2) % 2 == 0 else HAZARD_K)


def tracks(img, x, y, w, h):
    """A crawler track from above: rubber-dark plates, a lit edge, cleats."""
    rect(img, x, y, w, h, P.TIRE)
    hline(img, x, y, w, P.TIRE_L)
    for tx in range(x + 1, x + w - 1, 2):
        vline(img, tx, y + 1, h - 1, INK)
    px(img, x, y, INK)
    px(img, x + w - 1, y + h - 1, INK)


# --- excavator ---------------------------------------------------------------

def gen_excavator():
    """Crawler excavator, arm reaching east. Four frames of the dig cycle."""
    w, h = 44, 22
    # (boom end x, stick end x, bucket open?, bucket loaded?)
    poses = [(30, 41, True, False), (29, 38, False, False),
             (27, 33, False, True), (28, 36, True, True)]
    frames = []
    for boom_x, stick_x, open_, loaded in poses:
        img = new_img(w, h)
        tracks(img, 1, 2, 20, 5)
        tracks(img, 1, 15, 20, 5)
        rect(img, 4, 7, 14, 8, P.STEEL_D)  # undercarriage between the tracks
        # the house: engine deck behind, counterweight at the back (west)
        body(img, 2, 5, 18, 12)
        rect(img, 2, 6, 3, 10, P.SAFETY_D)
        hline(img, 3, 6, 2, P.STEEL)
        hline(img, 3, 15, 2, P.STEEL)
        for gy in range(8, 14, 2):
            hline(img, 6, gy, 4, INK)  # engine grille
        # the cab on the north-east corner of the house
        body(img, 12, 5, 7, 6)
        glass(img, 14, 6, 4, 4)
        beacon(img, 10, 6)
        # boom: from the house front, thick, two-tone
        by = 11
        rect(img, 18, by - 1, boom_x - 18, 3, P.SAFETY)
        hline(img, 18, by - 1, boom_x - 18, P.SAFETY_L)
        hline(img, 18, by + 1, boom_x - 18, P.SAFETY_D)
        vline(img, 22, by - 2, 5, P.STEEL_D)  # hydraulic ram mounts
        rect(img, 23, by - 2, boom_x - 24, 1, CHROME)
        # stick
        rect(img, boom_x, by, stick_x - boom_x, 2, P.SAFETY_D)
        hline(img, boom_x, by, stick_x - boom_x, P.SAFETY)
        px(img, boom_x, by - 1, INK)
        # bucket
        bx = stick_x
        if open_:
            rect(img, bx, by - 3, 3, 8, P.STEEL_D)
            vline(img, bx + 2, by - 3, 8, P.STEEL_L)
            for ty in range(by - 3, by + 5, 2):
                px(img, bx + 3, ty, CHROME)  # teeth
        else:
            rect(img, bx - 2, by - 2, 4, 6, P.STEEL_D)
            vline(img, bx - 2, by - 2, 6, P.STEEL)
        if loaded:
            rect(img, bx - 2 if not open_ else bx, by - 1, 3, 4, P.DIRT)
            px(img, bx - 1 if not open_ else bx + 1, by, P.DIRT_L)
        frames.append(outline(img))
    save(sheet(frames), "works_excavator")


# --- dump truck --------------------------------------------------------------

def gen_dumper():
    w, h = 32, 16
    frames = []
    for loaded in (False, True):
        img = new_img(w, h)
        for tx in (4, 12, 24):
            tyres(img, tx, 0, 5, 3)
            tyres(img, tx, 13, 5, 3)
        # tipper body at the back (west), cab at the front (east)
        body(img, 1, 2, 21, 12, (P.CRANE_D, P.CRANE, P.CRANE_L))
        rect(img, 3, 4, 17, 8, P.CRANE_D)
        for rib in range(5, 20, 4):
            vline(img, rib, 4, 8, P.CRANE)
        if loaded:
            rect(img, 3, 4, 17, 8, P.DIRT)
            speckle(img, 3, 4, 17, 8, [P.DIRT_L, P.DIRT_D], density=0.3, seed=11)
            rect(img, 7, 5, 9, 6, P.DIRT_L)
            speckle(img, 7, 5, 9, 6, [P.DIRT], density=0.3, seed=12)
        hline(img, 1, 2, 21, P.CRANE_L)
        body(img, 23, 3, 8, 10)
        glass(img, 27, 4, 3, 8)
        hline(img, 24, 7, 2, INK)
        px(img, 30, 3, P.WINDOW_LIT)
        px(img, 30, 12, P.WINDOW_LIT)
        beacon(img, 24, 4)
        frames.append(outline(img))
    save(sheet(frames), "works_dumper")


# --- concrete mixer ------------------------------------------------------------

def gen_mixer():
    w, h = 34, 16
    frames = []
    for f in range(4):
        img = new_img(w, h)
        for tx in (3, 11, 25):
            tyres(img, tx, 0, 5, 3)
            tyres(img, tx, 13, 5, 3)
        rect(img, 2, 4, 22, 8, P.STEEL_D)
        # the drum: a fat barrel along the truck, spiral stripes walking west
        rect(img, 3, 3, 20, 10, DRUM_W)
        hline(img, 4, 2, 18, DRUM_W)
        hline(img, 4, 13, 18, DRUM_W_D)
        hline(img, 3, 3, 20, (250, 248, 240, 255))
        hline(img, 3, 12, 20, DRUM_W_D)
        for s in range(-2, 6):
            sx = 3 + s * 5 + f
            for j in range(10):
                x = sx + j // 3
                if 3 <= x < 23:
                    px(img, x, 3 + j, P.SAFETY_D if j in (0, 9) else P.SAFETY)
        rect(img, 1, 6, 2, 4, P.STEEL)  # the chute at the back
        px(img, 0, 7, P.STEEL_L)
        px(img, 0, 8, CONCRETE_D)
        # cab
        body(img, 24, 3, 9, 10, (BLUE_D, BLUE, BLUE_L))
        glass(img, 29, 4, 3, 8)
        px(img, 32, 3, P.WINDOW_LIT)
        px(img, 32, 12, P.WINDOW_LIT)
        beacon(img, 25, 7)
        frames.append(outline(img))
    save(sheet(frames), "works_mixer")


# --- road roller -------------------------------------------------------------

def gen_roller():
    w, h = 26, 16
    frames = []
    for f in range(2):
        img = new_img(w, h)
        # rear tyres, frame, canopy, front drum (east)
        tyres(img, 2, 0, 6, 3)
        tyres(img, 2, 13, 6, 3)
        body(img, 1, 3, 13, 10)
        rect(img, 3, 5, 6, 6, P.SAFETY_D)
        rect(img, 4, 6, 4, 4, INK)  # seat
        hline(img, 3, 4, 8, P.STEEL_L)  # ROPS bar
        hline(img, 3, 11, 8, P.STEEL_L)
        beacon(img, 10, 7)
        rect(img, 14, 6, 3, 4, P.STEEL_D)
        # drum: steel, with roll lines that move
        rect(img, 17, 1, 8, 14, P.STEEL)
        vline(img, 17, 1, 14, P.STEEL_L)
        vline(img, 24, 1, 14, P.STEEL_D)
        for ry in range(1 + f, 15, 3):
            hline(img, 18, ry, 6, P.STEEL_D)
        rect(img, 16, 0, 10, 1, P.SAFETY_D)
        rect(img, 16, 15, 10, 1, P.SAFETY_D)
        frames.append(outline(img))
    save(sheet(frames), "works_roller")


# --- tower crane ---------------------------------------------------------------

def gen_jib():
    """Counter-jib with its concrete blocks | slewing ring and cab | jib.

    Pivot (the mast centre) at JIB_PIVOT; the jib points east from it."""
    w, h = 84, 11
    img = new_img(w, h)
    cy = JIB_PIVOT[1]
    # counter-jib: a flat walkway with the weights on the end
    rect(img, 4, cy - 2, 20, 5, P.SAFETY_D)
    hline(img, 4, cy - 2, 20, P.SAFETY)
    for x in range(6, 22, 3):
        vline(img, x, cy - 1, 3, INK)
    for i in range(3):
        rect(img, 1 + i * 4, cy - 4, 4, 9, CONCRETE)
        hline(img, 1 + i * 4, cy - 4, 4, CONCRETE_L)
        vline(img, 4 + i * 4, cy - 4, 9, CONCRETE_D)
    rect(img, 13, cy - 3, 6, 7, P.STEEL_D)  # hoist winch
    vline(img, 15, cy - 2, 5, CHROME)
    # the jib: a triangular lattice, two chords and the zigzag between
    x0, x1 = 30, w - 1
    hline(img, x0, cy - 3, x1 - x0, P.SAFETY)
    hline(img, x0, cy + 3, x1 - x0, P.SAFETY_D)
    hline(img, x0, cy, x1 - x0, P.SAFETY_D)  # the trolley rail on the bottom chord
    # lacing: one clean zigzag between the chords, a diagonal every 6 pixels
    for x in range(x0, x1 - 6, 6):
        for j in range(6):
            px(img, x + j // 2, cy - 2 + j, P.SAFETY_L)
            px(img, x + 3 + j // 2, cy + 3 - j, P.SAFETY)
    for x in range(x0, x1 - 2, 12):
        vline(img, x, cy - 3, 7, P.SAFETY_D)
    rect(img, x1 - 2, cy - 3, 3, 7, P.CRANE)  # the red tip
    # slewing platform and the operator's cab over the mast
    rect(img, 20, 0, 11, 11, P.STEEL_D)
    rect(img, 21, 1, 9, 9, P.SAFETY)
    hline(img, 21, 1, 9, P.SAFETY_L)
    vline(img, 29, 1, 9, P.SAFETY_D)
    rect(img, 27, 2, 4, 4, P.GLASS)
    px(img, 28, 3, GLINT)
    beacon(img, 22, 7)
    save(outline(img), "works_jib")


def gen_crane_base():
    w, h = 16, 16
    img = new_img(w, h)
    rect(img, 0, 0, 16, 16, CONCRETE_D)
    rect(img, 1, 1, 14, 14, CONCRETE)
    hline(img, 1, 1, 14, CONCRETE_L)
    # the mast seen down its length: four legs and the bracing between
    rect(img, 4, 4, 8, 8, INK)
    for (x, y) in ((4, 4), (10, 4), (4, 10), (10, 10)):
        rect(img, x, y, 2, 2, P.SAFETY)
    for i in range(4):
        px(img, 6 + i, 5 + i, P.SAFETY_D)
        px(img, 9 - i, 5 + i, P.SAFETY_D)
    for (x, y) in ((1, 1), (13, 1), (1, 13), (13, 13)):
        rect(img, x, y, 2, 2, P.STEEL)
    save(img, "works_crane_base")


def gen_trolley():
    img = new_img(7, 7)
    rect(img, 0, 1, 7, 5, P.STEEL_D)
    hline(img, 0, 1, 7, P.STEEL_L)
    rect(img, 2, 2, 3, 3, P.SAFETY)
    px(img, 3, 3, INK)
    save(img, "works_trolley")


def gen_loads():
    frames = []
    # rebar bundle on two slings
    img = new_img(12, 10)
    for y in range(2, 8):
        hline(img, 0, y, 12, REBAR if y % 2 else REBAR_L)
    vline(img, 3, 1, 8, INK)
    vline(img, 8, 1, 8, INK)
    frames.append(outline(img))
    # concrete skip
    img = new_img(12, 10)
    rect(img, 1, 1, 10, 8, P.STEEL_D)
    rect(img, 2, 2, 8, 6, CONCRETE)
    speckle(img, 2, 2, 8, 6, [CONCRETE_L, CONCRETE_D], density=0.3, seed=4)
    hline(img, 1, 1, 10, P.STEEL_L)
    frames.append(outline(img))
    # brick pallet
    img = new_img(12, 10)
    rect(img, 0, 6, 12, 3, WOOD)
    hline(img, 0, 8, 12, WOOD_D)
    for y in range(1, 6, 2):
        for x in range(0 + (y // 2) % 2 * 2, 12, 4):
            rect(img, x, y, 3, 2, BRICK)
            px(img, x, y, BRICK_L)
    frames.append(outline(img))
    save(sheet(frames), "works_loads")


# --- the site's furniture -----------------------------------------------------

def gen_cabin():
    """The site office: a blue portacabin seen from above, door to the south."""
    w, h = 34, 20
    img = new_img(w, h)
    rect(img, 0, 0, 34, 16, BLUE)
    hline(img, 0, 0, 34, BLUE_L)
    for x in range(2, 34, 3):
        vline(img, x, 1, 14, BLUE_D)  # corrugated roof
    rect(img, 0, 15, 34, 5, BLUE_D)
    hline(img, 0, 15, 34, INK)
    for wx in (3, 21):
        rect(img, wx, 16, 8, 3, P.GLASS)
        px(img, wx + 1, 16, GLINT)
    rect(img, 14, 16, 5, 4, WOOD)
    px(img, 17, 18, P.SAFETY_L)
    rect(img, 26, 2, 5, 4, P.STEEL)  # air conditioner on the roof
    hline(img, 26, 2, 5, P.STEEL_L)
    px(img, 28, 4, INK)
    save(outline(img), "works_cabin")


def gen_props():
    w, h = 20, 18
    frames = []
    # portable toilet
    img = new_img(w, h)
    rect(img, 6, 2, 9, 9, GREEN)
    hline(img, 6, 2, 9, (110, 190, 130, 255))
    rect(img, 6, 11, 9, 6, GREEN_D)
    rect(img, 8, 11, 5, 6, GREEN)
    px(img, 12, 14, P.SAFETY_L)
    rect(img, 9, 12, 3, 1, INK)  # the little moon slot
    frames.append(outline(img))
    # rebar stack on timbers
    img = new_img(w, h)
    for y in (12, 14):
        rect(img, 1, y, 18, 1, WOOD_D)
    for y in range(4, 13):
        hline(img, 0, y, 20, REBAR if y % 2 else REBAR_L)
    for y in range(4, 13, 2):
        px(img, 19, y, INK)
    frames.append(outline(img))
    # concrete pipe stack
    img = new_img(w, h)
    for (x, y) in ((1, 8), (8, 8), (4, 2), (11, 2)):
        rect(img, x, y, 7, 7, CONCRETE)
        hline(img, x, y, 7, CONCRETE_L)
        rect(img, x + 2, y + 2, 3, 3, INK)
        px(img, x + 2, y + 2, CONCRETE_D)
    frames.append(outline(img))
    # spoil heap
    img = new_img(w, h)
    for r, col in ((9, P.DIRT_D), (7, P.DIRT), (4, P.DIRT_L)):
        for y in range(h):
            for x in range(w):
                if ((x - 10) / (r + 1)) ** 2 + ((y - 10) / (r * 0.75)) ** 2 <= 1.0:
                    px(img, x, y, col)
    speckle(img, 2, 3, 16, 14, [P.DIRT_D, (110, 80, 54, 255)], density=0.12, seed=9)
    frames.append(outline(img))
    # generator
    img = new_img(w, h)
    rect(img, 2, 5, 16, 9, P.SAFETY)
    hline(img, 2, 5, 16, P.SAFETY_L)
    rect(img, 2, 13, 16, 3, P.SAFETY_D)
    for gx in range(4, 10, 2):
        vline(img, gx, 7, 5, INK)
    rect(img, 12, 7, 4, 4, P.STEEL_D)
    px(img, 13, 8, (120, 220, 120, 255))
    rect(img, 15, 3, 2, 2, P.STEEL)  # exhaust
    frames.append(outline(img))
    # brick pallets
    img = new_img(w, h)
    for (bx, by) in ((1, 6), (10, 7)):
        rect(img, bx, by + 7, 9, 2, WOOD)
        for y in range(by, by + 7, 2):
            for x in range(bx + (y // 2) % 2, bx + 9, 3):
                rect(img, x, y, 2, 2, BRICK)
                px(img, x, y, BRICK_L)
    frames.append(outline(img))
    save(sheet(frames), "works_props")


if __name__ == "__main__":
    gen_excavator()
    gen_dumper()
    gen_mixer()
    gen_roller()
    gen_jib()
    gen_crane_base()
    gen_trolley()
    gen_loads()
    gen_cabin()
    gen_props()
