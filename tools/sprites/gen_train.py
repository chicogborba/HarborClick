"""The branch-line train: locomotive, three kinds of wagon, and the boxes they carry.

Drawn the way the rest of the terminal is drawn — top-down with the south face
showing (the yard's stacks lift `BOX_LIFT` px per tier for the same reason) and
light from the north-west — and drawn **at the size it is shown**. The old rake
was art for a 34px wagon resampled to 62% in-engine, which is the one thing pixel
art cannot survive: pixels of two different sizes on one screen, and boxes on the
wagons a third smaller than the identical boxes in the yard next to them.

Everything faces EAST (the way the branch runs into the terminal) and is never
rotated. A quarter turn would put the south face on the side, and the locomotive
turning round is a horizontal flip, not a rotation.

Geometry is the rake's contract with `RailRake` and `PortLayout`:

- a wagon is exactly `RAIL_WAGON_PITCH` (21) wide, couplers included, so a rake
  of them couples up buffer to buffer;
- every sprite's row `RAIL_ROW` is the running line `PortLayout.rail_y()`; the
  rails are at ±5 from it, which is where the wheels are drawn;
- a box sits with its south face standing on the deck's south edge.
"""
import palette as P
from common import new_img, px, rect, save, sheet

WAGON_W, WAGON_H = 21, 18
## Row of the wagon sprite that sits on the running line.
WAGON_RAIL_ROW = 8
LOCO_W, LOCO_H = 29, 20
LOCO_RAIL_ROW = 10
BOX_W, BOX_H = 18, 11
## Where a box's top-left lands on its wagon's top-left.
BOX_ON_WAGON = (2, 0)
LAMP_W, LAMP_H = 22, 13

INK = (40, 30, 42, 255)

STEEL = P.ramp((112, 116, 132), 5, hue_shift=12.0)
OXIDE = P.ramp((138, 75, 58), 5, hue_shift=14.0)
BLUE = P.ramp((47, 111, 208), 5, hue_shift=18.0, dark=0.45, light=0.55)
YELLOW = P.ramp((242, 182, 50), 5, hue_shift=12.0, dark=0.35, light=0.6)
CREAM = (238, 230, 208, 255)
TYRE = (44, 40, 50, 255)
TYRE_L = (92, 88, 100, 255)
SHADOW = (24, 18, 34, 96)
GLASS = P.ramp(P.GLASS, 5, hue_shift=10.0)
## The cab roof is painted white on every road switcher worth the name: it keeps
## the crew cool and it is the brightest thing on the train from above.
CAB_ROOF = P.ramp((214, 218, 226), 5, hue_shift=10.0, dark=0.3, light=0.7)
LAMP_HOT = (255, 244, 196, 255)
TAIL = (232, 72, 64, 255)


def selout(img, strength=0.62):
    """Selective outline, drawn *inside* the silhouette.

    Every opaque pixel touching transparency is pulled toward the ink, keeping
    its own hue — a blue edge goes navy, an oxide one goes brown. An outline
    grown outside would make a 21px wagon 23px wide and the rake would overlap
    itself at every coupling. Semi-transparent pixels (shadows) are neither
    outlined nor counted as solid."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()

    def solid(x, y):
        return 0 <= x < w and 0 <= y < h and src[x, y][3] == 255

    for y in range(h):
        for x in range(w):
            if not solid(x, y):
                continue
            if all(solid(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                continue
            dst[x, y] = P.mix(src[x, y], INK, strength)
    return out


def shadow(img, x0, y0, x1, y1):
    """Cast shadow on the ballast, only where nothing is drawn yet."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < img.width and 0 <= y < img.height and img.getpixel((x, y))[3] == 0:
                px(img, x, y, SHADOW)


def bogie(img, x, y, axles):
    """A truck seen from the south: a side frame with the wheels hanging off it.

    The wheels sit on the south rail (rail row + 5); `y` is the side frame's
    row, one above the wheel tops."""
    span = axles * 3 - 1
    rect(img, x, y, span, 1, STEEL[0])
    for a in range(axles):
        wx = x + a * 3
        rect(img, wx, y + 1, 2, 2, TYRE)
        px(img, wx, y + 1, TYRE_L)
    # the axlebox springs: one lit pixel per frame end
    px(img, x, y, STEEL[2])
    px(img, x + span - 1, y, STEEL[1])


def coupler(img, x, row):
    rect(img, x, row - 1, 1, 2, STEEL[1])
    px(img, x, row - 1, STEEL[3])


# --------------------------------------------------------------------- wagons

def _wagon_base():
    """Solebars, bogies, couplers and shadow — what every wagon shares."""
    img = new_img(WAGON_W, WAGON_H)
    r = WAGON_RAIL_ROW
    # south solebar: the side face of the frame
    rect(img, 1, r + 3, 19, 2, OXIDE[1])
    rect(img, 1, r + 4, 19, 1, OXIDE[0])
    bogie(img, 2, r + 4, 2)
    bogie(img, 14, r + 4, 2)
    coupler(img, 0, r)
    coupler(img, 20, r)
    return img


def _deck_flat(img):
    """Container flat: a perimeter frame and cross-bearers, twistlocks at the
    corners of where a forty-footer stands."""
    r = WAGON_RAIL_ROW
    top, bot = r - 6, r + 2
    rect(img, 1, top, 19, bot - top + 1, STEEL[1])          # deck plates
    for x in range(3, 19, 3):                               # plate seams
        rect(img, x, top + 1, 1, bot - top - 1, STEEL[0])
    rect(img, 1, top, 19, 1, OXIDE[3])                      # north beam, lit
    rect(img, 1, bot, 19, 1, OXIDE[2])                      # south beam
    rect(img, 1, top, 1, bot - top + 1, OXIDE[2])
    rect(img, 19, top, 1, bot - top + 1, OXIDE[1])
    for tx, ty in ((2, top + 1), (17, top + 1), (2, bot - 1), (17, bot - 1)):
        px(img, tx, ty, YELLOW[3])


def _deck_well(img):
    """Well wagon: the box rides low between two deep side girders."""
    r = WAGON_RAIL_ROW
    top, bot = r - 6, r + 2
    rect(img, 1, top, 19, bot - top + 1, OXIDE[2])
    rect(img, 1, top, 19, 1, OXIDE[4])                      # girder tops, lit
    rect(img, 1, top + 1, 19, 1, OXIDE[3])
    rect(img, 3, top + 2, 15, bot - top - 2, STEEL[0])      # the well floor
    rect(img, 3, top + 2, 15, 1, OXIDE[1])                  # inner north wall, in shade
    for x in range(5, 17, 4):
        px(img, x, bot - 1, STEEL[1])
    rect(img, 1, bot, 19, 1, OXIDE[1])
    for tx in (3, 17):
        px(img, tx, top + 3, YELLOW[3])


def _deck_spine(img):
    """Skeletal spine car: one centre beam and the bearers a box locks to,
    with the ballast showing through everywhere else."""
    r = WAGON_RAIL_ROW
    top, bot = r - 6, r + 2
    rect(img, 1, r - 3, 19, 3, OXIDE[2])                    # spine
    rect(img, 1, r - 3, 19, 1, OXIDE[3])
    rect(img, 1, r - 1, 19, 1, OXIDE[1])
    for bx in (2, 10, 18):                                  # bearers
        rect(img, bx, top, 1, bot - top + 1, OXIDE[2])
        px(img, bx, top, OXIDE[4])
        px(img, bx, bot, OXIDE[1])
    for tx, ty in ((2, top), (18, top), (2, bot), (18, bot)):
        px(img, tx, ty, YELLOW[3])


def wagon_frames():
    frames = []
    for deck in (_deck_flat, _deck_well, _deck_spine):
        img = _wagon_base()
        deck(img)
        img = selout(img, 0.5)
        shadow(img, 2, WAGON_RAIL_ROW + 7, WAGON_W - 1, WAGON_RAIL_ROW + 8)
        frames.append(img)
    return frames


# ---------------------------------------------------------------------- boxes

def rail_box(ramp_):
    """A forty-footer as it rides a wagon: 17x8 roof, 3px side wall, and its
    own shadow falling east onto the deck."""
    img = new_img(BOX_W, BOX_H)
    d0, d1, mid, lit, glint = ramp_
    roof_h, face_h, w = 8, 3, 17
    rect(img, 0, 0, w, roof_h, mid)
    for x in range(2, w - 1, 3):                            # corrugation across the roof
        rect(img, x, 1, 1, roof_h - 2, lit)
        rect(img, x + 1, 1, 1, roof_h - 2, P.mix(mid, d1, 0.5))
    rect(img, 0, 0, w, 1, glint)                            # north edge catches the light
    rect(img, 0, roof_h, w, face_h, d1)                     # side wall, in shade
    for x in range(1, w - 1, 2):
        px(img, x, roof_h + 1, P.mix(d1, d0, 0.45))
    rect(img, 0, roof_h + face_h - 1, w, 1, d0)             # bottom rail
    for cx in (0, w - 1):                                   # corner castings
        px(img, cx, 0, P.mix(glint, INK, 0.25))
        px(img, cx, roof_h + face_h - 1, INK)
    img = selout(img, 0.55)
    for y in range(2, roof_h + face_h):                     # shadow on the deck
        px(img, w, y, SHADOW)
    return img


def rail_boxes():
    return [rail_box(P.CONTAINER_RAMPS[name]) for name in P.CONTAINER_NAMES]


# ----------------------------------------------------------------- locomotive

def locomotive():
    """A road switcher, nose east: long hood, cab, short hood on a walkway.

    Heights are what make it a locomotive rather than a long box: the hoods
    stand 3px, the cab 5px, so the cab's roof rises clear of everything and the
    eye finds the front end without a headlamp."""
    img = new_img(LOCO_W, LOCO_H)
    r = LOCO_RAIL_ROW
    foot_top, foot_bot = r - 6, r + 2          # walkway footprint, rows 4..12

    # --- frame, walkway, running gear ---------------------------------------
    rect(img, 1, foot_top, 27, foot_bot - foot_top + 1, STEEL[1])
    rect(img, 1, foot_bot, 27, 1, STEEL[2])
    for x in range(2, 27, 3):                  # yellow handrail stanchions
        px(img, x, foot_bot, YELLOW[2])
    rect(img, 1, r + 3, 27, 2, BLUE[0])        # solebar
    rect(img, 1, r + 3, 27, 1, BLUE[1])
    rect(img, 12, r + 3, 5, 2, STEEL[0])       # fuel tank between the trucks
    px(img, 12, r + 3, STEEL[2])
    bogie(img, 3, r + 4, 3)
    bogie(img, 17, r + 4, 3)
    coupler(img, 0, r)
    coupler(img, 28, r)
    # chevrons on both end plates, the stripe every shunter wears
    for x in (1, 27):
        for y in range(foot_top, foot_bot + 1):
            px(img, x, y, YELLOW[3] if (y + x) % 3 else INK)

    def hood(x0, x1, height, roof, face, top_lit):
        """A box standing on the walkway: footprint rows foot_top+1..foot_bot-1."""
        f_top, f_bot = foot_top + 1, foot_bot - 1
        rect(img, x0, f_top - height, x1 - x0 + 1, f_bot - f_top + 1, roof)
        rect(img, x0, f_top - height, x1 - x0 + 1, 1, top_lit)
        rect(img, x0, f_bot - height + 1, x1 - x0 + 1, height, face)
        return f_top - height, f_bot - height  # roof rows

    # --- long hood (rear) -----------------------------------------------------
    roof_t, roof_b = hood(2, 17, 3, BLUE[2], BLUE[1], BLUE[3])
    rect(img, 2, roof_b + 2, 16, 1, CREAM)     # cream stripe along the side
    for fx in (3, 8):                          # radiator fans: round grilles, a hub each
        rect(img, fx, roof_t + 1, 4, 4, STEEL[0])
        for cx, cy in ((0, 0), (3, 0), (0, 3), (3, 3)):
            px(img, fx + cx, roof_t + 1 + cy, BLUE[2])
        rect(img, fx + 1, roof_t + 2, 2, 2, STEEL[1])
        px(img, fx + 1, roof_t + 2, STEEL[3])
        px(img, fx + 2, roof_t + 3, INK)
    rect(img, 14, roof_t + 3, 2, 2, INK)       # exhaust stack
    px(img, 14, roof_t + 3, STEEL[2])
    rect(img, 2, roof_t, 1, roof_b - roof_t + 1, BLUE[3])   # west end, toward the light

    # --- cab -----------------------------------------------------------------
    c_t, c_b = hood(18, 23, 5, CAB_ROOF[2], BLUE[1], CAB_ROOF[4])
    rect(img, 19, c_t + 2, 4, 3, STEEL[1])     # roof air-conditioner
    rect(img, 19, c_t + 2, 4, 1, STEEL[3])
    px(img, 20, c_t + 3, STEEL[0])
    px(img, 21, c_t + 3, STEEL[0])
    px(img, 22, c_t + 1, YELLOW[3])            # horn
    rect(img, 19, c_b + 2, 4, 2, GLASS[1])     # side windows
    px(img, 19, c_b + 2, GLASS[4])
    px(img, 21, c_b + 2, GLASS[3])
    rect(img, 18, c_b + 4, 6, 1, CREAM)        # stripe carries on under them
    rect(img, 23, c_t + 1, 1, c_b - c_t, P.mix(CAB_ROOF[1], BLUE[1], 0.5))  # east end in shade

    # --- short hood (nose) ------------------------------------------------------
    n_t, n_b = hood(24, 26, 3, YELLOW[2], YELLOW[1], YELLOW[4])
    for y in range(n_b + 1, n_b + 4):          # black chevron on the nose's flank
        px(img, 24 + (y - n_b) % 3, y, INK)
    # headlamps and the tail lamp, on the end plates
    px(img, 27, foot_top + 2, LAMP_HOT)
    px(img, 27, foot_bot - 2, LAMP_HOT)
    px(img, 1, foot_top + 3, TAIL)

    img = selout(img, 0.5)
    shadow(img, 2, r + 7, LOCO_W - 1, r + 8)
    # the shadow of the cab, longer than the hoods' because the cab is taller
    shadow(img, 24, c_t + 1, 24, foot_bot)
    return img


def loco_lamp():
    """Headlight throw, pointing east from the nose. Additive in-engine, so it
    has no outline and fades to nothing at the far end."""
    img = new_img(LAMP_W, LAMP_H)
    cy = LAMP_H // 2
    for x in range(LAMP_W):
        t = x / (LAMP_W - 1)
        half = 1 + int(t * (LAMP_H // 2 - 1))
        alpha = int(150 * (1.0 - t) ** 1.4)
        for y in range(cy - half, cy + half + 1):
            edge = abs(y - cy) == half
            a = alpha // 2 if edge else alpha
            if a > 0:
                px(img, x, y, (255, 236, 170, a))
    return img


def gen_train():
    save(locomotive(), "veh_loco")
    save(loco_lamp(), "veh_loco_lamp")
    save(sheet(wagon_frames()), "veh_wagon")
    save(sheet(rail_boxes()), "rail_box_sheet")


if __name__ == "__main__":
    print("train:")
    gen_train()
