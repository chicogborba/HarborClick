"""Top-down container ship, bow pointing UP, moored along a vertical quay.

Canvas 66x232, and every coordinate below is a contract with `Ship`:
deck cargo is drawn at runtime with container_sheet, 2 columns (x=8 and x=34)
x 12 rows starting at y=44, 11px apart; the accommodation block starts at
y=180; sidelights sit at (4,46) and (61,46), the masthead at (33,8), the stern
lamp at (33,226).

Two images, one coordinate system:

- `ship_top.png` — the ship itself in its own colours: slate deck, steel hatch
  covers, a white house, an orange lifeboat. The hull's paint is drawn in a
  neutral grey here.
- `ship_paint.png` — only the painted hull and the funnel band, as a white-to-
  grey ramp. `Ship` lays it over the hull and tints it with the livery.
- `ship_trim_<hull>.png` — four 66x232 frames, one per `TRIM_PATTERNS` entry:
  the second livery colour (always with the funnel band).
- `ship_house.png` — the white of the house alone, for non-white houses.
- `ship_side_<hull>.png` — the album portrait, side-on on a 112x34 canvas, as
  seven frames: base, paint, house, then the four trim patterns.

Five hulls (`PROFILES`): coaster, feeder, panamax, new panamax and ULCV.

The catalogue used to tint the *whole* hull sprite with its livery, which
multiplied the deck, the bridge and the lifeboats by brick red or bottle green:
every ship in the game was one muddy colour from bow to stern.
"""
import math

import palette as P
from common import new_img, outline, px, rect, save, sheet

W, H = 66, 232
BOW_TIP = 3
DECK_X0, DECK_X1 = 2, 64      # hull outer edges
IN_X0, IN_X1 = 7, 59          # deck plating (inside the bulwarks)
BAY_X = (8, 34)
BAY_Y0, BAY_PITCH, BAY_ROWS = 44, 11, 12
HOUSE_TOP, HOUSE_H = 180, 30

INK = P.OUTLINE
DECK = P.ramp((84, 98, 96), 5, hue_shift=12.0, dark=0.35, light=0.45)
STEEL = P.ramp((118, 122, 136), 5, hue_shift=12.0)
HATCH = P.ramp((112, 120, 132), 5, hue_shift=10.0, dark=0.32, light=0.5)
WHITE = P.ramp((226, 222, 212), 5, hue_shift=12.0, dark=0.28, light=0.8)
ORANGE = P.ramp((236, 120, 44), 5, hue_shift=14.0, dark=0.35, light=0.55)
GLASS = P.ramp((76, 128, 156), 5, hue_shift=10.0, dark=0.45, light=0.6)
## The hull paint before the livery: neutral, so `ship_top.png` reads on its
## own (the fallback, the outline shader) and the tint has a ramp to multiply.
PAINT = [(150, 150, 156, 255), (186, 186, 192, 255), (214, 214, 218, 255),
         (236, 236, 238, 255), (255, 255, 255, 255)]
BOOT = P.ramp((150, 58, 50), 5, hue_shift=12.0)    # anti-fouling red below the paint
SHADOW = (20, 22, 36, 90)


# The silhouette profile: (bow exponent, stern taper). Three native hulls share
# the same 66x232 canvas and the same 24-bay deck grid — they differ in how the
# bow fills out and how the stern pulls in, never in a fractional scale that
# would sand the pixels off the containers. Feeder = fine bow, pinched stern;
# panamax = the reference; new panamax = blunt bow, nearly square stern.
PROFILE = (0.55, 12.0)
PROFILES = {
    "feeder": (0.75, 22.0),
    "panamax": (0.55, 12.0),
    "new_panamax": (0.28, 3.0),
    # The album's two extra hulls: a coaster with a knife of a bow and a stern
    # pinched almost to a point, and an ultra-large box ship that is a brick
    # with a rounded end.
    "coaster": (1.0, 26.0),
    "ulcv": (0.16, 0.0),
}

## The second livery colour goes on one of these, picked per ship in
## `FleetDB` (`trim`). Every pattern carries the funnel band.
TRIM_PATTERNS = ("band", "stripe", "bow", "stern")


def _half_beam(y):
    """Half the hull's width at row y — the one silhouette everything follows."""
    cx = W / 2
    bow_exp, stern_taper = PROFILE
    if y < BOW_TIP:
        return 0
    if y < 40:
        k = (y - BOW_TIP) / 37.0
        return 2 + int((k ** bow_exp) * (cx - DECK_X0 - 2))
    if y < H - 7:
        return int(cx - DECK_X0)
    k = (y - (H - 7)) / 6.0
    return int(cx - DECK_X0 - (k * k) * stern_taper)


def _hull_mask():
    rows = {}
    for y in range(BOW_TIP, H - 1):
        half = _half_beam(y)
        if half > 0:
            cx = W // 2
            rows[y] = (cx - half, cx + half - 1)
    return rows


def hull(img, paint):
    """The hull's top strake and bulwark: a ring of paint round the deck.

    `paint` is the ramp to draw it in — the neutral grey for the ship sprite,
    the white ramp for the livery layer."""
    rows = _hull_mask()
    for y, (x0, x1) in rows.items():
        for x in range(x0, x1 + 1):
            # light from the north-west: the port side and the bow's west flank
            # are lit, starboard turns away
            t = (x - x0) / max(1, x1 - x0)
            shade = 3 if t < 0.12 else 2 if t < 0.8 else 1
            if y < 40 and x < W // 2:
                shade = min(4, shade + 1)
            px(img, x, y, paint[shade])
        px(img, x0, y, paint[4] if y < H - 20 else paint[3])
        px(img, x1, y, paint[0])
    # boot-topping: the red below the paint line shows along the stern quarter
    for y in range(H - 9, H - 1):
        if y in rows:
            x0, x1 = rows[y]
            for x in range(x0 + 1, x1):
                if y >= H - 4:
                    px(img, x, y, BOOT[2] if x < W // 2 else BOOT[1])


def deck(img):
    """Deck plating inside the bulwarks, hatch covers over the holds."""
    rows = _hull_mask()
    for y, (x0, x1) in rows.items():
        if y < 12 or y > H - 10:
            continue
        inset = 5 if y >= 30 else 4
        a, b = x0 + inset, x1 - inset
        if b <= a:
            continue
        for x in range(a, b + 1):
            px(img, x, y, DECK[2] if (x * 7 + y * 3) % 23 else DECK[1])
        px(img, a, y, P.mix(DECK[0], INK, 0.3))         # bulwark's inner face, in shade
        px(img, b, y, DECK[3])                           # starboard bulwark catches light
    # forecastle: a raised deck over the bow, a step up and a step lighter
    for y in range(10, 36):
        x0, x1 = rows[y]
        for x in range(x0 + 4, x1 - 3):
            px(img, x, y, DECK[3] if (x + y) % 9 else DECK[2])
    for x in range(10, 56):
        px(img, x, 36, DECK[0])                          # the step down to the main deck
    # breakwater: the V-shaped wall that keeps green water off the first bay
    for i in range(22):
        y = 39 - i // 4
        px(img, W // 2 - 1 - i, y, STEEL[3])
        px(img, W // 2 + i, y, STEEL[2])
        px(img, W // 2 - 1 - i, y + 1, STEEL[0])
        px(img, W // 2 + i, y + 1, STEEL[0])
    # windlasses and the anchor cables running to the hawse pipes
    for wx in (24, 38):
        rect(img, wx, 18, 5, 5, STEEL[1])
        rect(img, wx + 1, 19, 3, 3, STEEL[0])
        px(img, wx + 1, 19, STEEL[3])
        px(img, wx, 18, STEEL[4])
    for i in range(9):
        px(img, 25 - i, 23 + i // 2 * 1, INK if i % 2 else STEEL[0])
        px(img, 41 + i, 23 + i // 2 * 1, INK if i % 2 else STEEL[0])
    # bow mast with its foot plate
    rect(img, 31, 7, 4, 4, STEEL[2])
    rect(img, 31, 7, 4, 1, STEEL[4])
    px(img, 32, 6, STEEL[3])

    # hatch coamings and covers: what shows where no box stands
    for row in range(BAY_ROWS):
        y = BAY_Y0 + row * BAY_PITCH
        for bx in BAY_X:
            rect(img, bx, y, 22, 10, HATCH[2])
            rect(img, bx, y, 22, 1, HATCH[4])            # lit north edge
            rect(img, bx, y + 9, 22, 1, HATCH[0])        # south lip in shade
            rect(img, bx + 21, y + 1, 1, 8, HATCH[1])
            for sx in range(bx + 4, bx + 21, 5):         # cover panel seams
                rect(img, sx, y + 1, 1, 8, HATCH[1])
                px(img, sx + 1, y + 1, HATCH[3])
            px(img, bx + 2, y + 4, P.SAFETY)             # lifting lugs
            px(img, bx + 19, y + 4, P.SAFETY)
        # lashing bridge between rows: a yellow-railed walkway athwartships
        if row < BAY_ROWS - 1:
            rect(img, IN_X0 + 1, y + 10, IN_X1 - IN_X0 - 2, 1, P.mix(P.SAFETY_D, DECK[1], 0.35))
    # mooring bitts along both bulwarks
    for y in range(52, H - 60, 22):
        for bx in (DECK_X0 + 3, DECK_X1 - 5):
            rect(img, bx, y, 2, 2, STEEL[1])
            px(img, bx, y, STEEL[4])


def superstructure(img, paint_layer=None):
    """The house: accommodation tiers, the bridge across its forward face, the
    funnel aft of it, lifeboats on both sides. It is the tallest thing on the
    ship, so it casts the longest shadow — south-east onto the deck."""
    top = HOUSE_TOP
    # shadow first, so everything after it sits on it: the house rect pushed
    # south-east, darkening whatever deck it falls on
    for y in range(top + 11, top + HOUSE_H + 4):
        for x in range(14, 59):
            if img.getpixel((x, y))[3] == 255 and DECK_X0 + 3 < x < DECK_X1 - 3:
                c = img.getpixel((x, y))
                img.putpixel((x, y), P.mix(c, SHADOW[:3] + (255,), 0.5))
    # bridge wings: a deck that reaches out to both rails so the officer of the
    # watch can see the ship's side alongside
    rect(img, 4, top + 2, 58, 6, WHITE[2])
    rect(img, 4, top + 2, 58, 1, WHITE[4])
    rect(img, 4, top + 7, 58, 1, WHITE[0])
    for wx in range(6, 61, 4):                          # bridge windows, forward face
        rect(img, wx, top + 3, 2, 2, GLASS[1])
        px(img, wx, top + 3, GLASS[4])
    # the house itself, tier on tier
    rect(img, 11, top + 8, 44, 21, WHITE[2])
    rect(img, 11, top + 8, 44, 1, WHITE[4])
    rect(img, 11, top + 8, 1, 21, WHITE[3])
    rect(img, 54, top + 8, 1, 21, WHITE[1])
    rect(img, 11, top + 28, 44, 1, WHITE[0])
    rect(img, 15, top + 12, 36, 14, WHITE[3])           # upper tier, closer to the sun
    rect(img, 15, top + 12, 36, 1, WHITE[4])
    rect(img, 50, top + 12, 1, 14, WHITE[1])
    rect(img, 15, top + 25, 36, 1, WHITE[1])
    # radar mast athwartships with two scanners on it
    rect(img, 18, top + 15, 30, 2, STEEL[1])
    rect(img, 18, top + 15, 30, 1, STEEL[3])
    for rx in (21, 41):
        rect(img, rx, top + 14, 5, 1, INK)
        px(img, rx + 2, top + 13, STEEL[4])
    # funnel, aft, with the livery band round it
    rect(img, 26, top + 18, 14, 9, P.mix(WHITE[1], STEEL[1], 0.5))
    rect(img, 26, top + 18, 14, 1, WHITE[3])
    band = paint_layer if paint_layer is not None else img
    rect(band, 26, top + 20, 14, 3, PAINT[3])
    rect(band, 26, top + 22, 14, 1, PAINT[1])
    rect(img, 29, top + 23, 8, 3, (38, 34, 40, 255))    # the smoke uptakes
    px(img, 30, top + 23, (70, 64, 70, 255))
    px(img, 34, top + 23, (70, 64, 70, 255))
    # lifeboats in their davits, one each side
    for lx, lit in ((4, True), (56, False)):
        rect(img, lx, top + 12, 6, 12, ORANGE[3] if lit else ORANGE[2])
        rect(img, lx, top + 12, 6, 1, ORANGE[4])
        rect(img, lx + 1, top + 14, 4, 8, ORANGE[2] if lit else ORANGE[1])
        rect(img, lx + 2, top + 15, 2, 6, WHITE[3])     # the canopy hatch
    # stern: mooring winches and the ensign staff
    for wx in (16, 44):
        rect(img, wx, H - 18, 7, 5, STEEL[1])
        rect(img, wx, H - 18, 7, 1, STEEL[3])
        rect(img, wx + 2, H - 17, 3, 3, STEEL[0])
    px(img, 33, H - 8, STEEL[4])
    px(img, 33, H - 7, STEEL[2])


def details(img):
    # nav lights on the bridge-wing-free bow: red to port, green to starboard
    px(img, 4, 46, P.RED_LIGHT)
    px(img, W - 5, 46, P.GREEN_LIGHT)
    px(img, 33, 8, P.WINDOW_LIT)
    px(img, 33, 226, P.WINDOW_LIT)


def _funnel_band(img):
    top = HOUSE_TOP
    rect(img, 26, top + 20, 14, 3, PAINT[3])
    rect(img, 26, top + 22, 14, 1, PAINT[1])


def _is_funnel_band(x, y):
    return HOUSE_TOP + 20 <= y <= HOUSE_TOP + 22 and 26 <= x < 40


def _trim(pattern, deck_cut):
    """The second livery colour, top-down: one pattern, white-to-grey so the
    tint has a ramp to multiply, cut wherever the deck or the house covers it."""
    img = new_img(W, H)
    rows = _hull_mask()
    for y, (x0, x1) in rows.items():
        inset = 5 if y >= 30 else 4
        for x in range(x0, x1 + 1):
            ring = x < x0 + inset or x > x1 - inset
            if not ring:
                continue
            t = (x - x0) / max(1, x1 - x0)
            shade = 3 if t < 0.12 else 2 if t < 0.8 else 1
            if pattern == "stripe":
                # the two ring columns nearest the deck: a sheer stripe
                hit = 12 <= y <= H - 10 and (x0 + inset - 2 <= x < x0 + inset
                                            or x1 - inset < x <= x1 - inset + 2)
            elif pattern == "bow":
                hit = y < 60
            elif pattern == "stern":
                hit = y > 168
            else:
                hit = False
            if hit:
                px(img, x, y, PAINT[min(4, shade + 1)])
    dp, tp = deck_cut.load(), img.load()
    for y in range(H):
        for x in range(W):
            if dp[x, y][3] == 255:
                tp[x, y] = (0, 0, 0, 0)
    for y in range(H - 4, H - 1):            # the boot-topping stays antifouling red
        for x in range(W):
            tp[x, y] = (0, 0, 0, 0)
    _funnel_band(img)
    return img


def _house_layer():
    """Only the white of the house and bridge wings, for `Ship` to tint cream,
    sky blue or ochre. Identical on every hull: the house is not shaped by the
    bow."""
    probe = new_img(W, H)
    superstructure(probe)
    out = new_img(W, H)
    whites = set(WHITE)
    pp, op = probe.load(), out.load()
    for y in range(H):
        for x in range(W):
            if pp[x, y] in whites:
                op[x, y] = pp[x, y]
    return out


# ------------------------------------------------------------------- side view
#
# The album shows each ship side-on, bow to the right, on one 112x34 canvas so
# the cards line up: the length, the height of the stack and the place of the
# house are what tell a coaster from an ULCV at a glance. Seven frames per hull,
# in a horizontal sheet: base, paint, house, then the four trim patterns.

SIDE_W, SIDE_H = 112, 34
SIDE_WL = 28                 # waterline
SIDE = {
    #               length, hull height, tiers, house at (0 = stern, 1 = bow)
    "coaster":      (60, 6, 2, 0.0),
    "feeder":       (72, 7, 3, 0.0),
    "panamax":      (86, 8, 4, 0.0),
    "new_panamax":  (98, 9, 5, 0.0),
    "ulcv":         (110, 10, 6, 0.62),
}
SIDE_BOXES = [P.CONTAINER_RAMPS[n] for n in P.CONTAINER_NAMES]


def _side_geometry(hull_id):
    length, hull_h, tiers, house_at = SIDE[hull_id]
    xs = (SIDE_W - length) // 2
    xb = xs + length - 1
    deck_y = SIDE_WL - hull_h
    return length, hull_h, tiers, house_at, xs, xb, deck_y


def _side_rows(hull_id):
    """x-extent of the hull per row, deck to keel: a transom stern, a raked
    stem, and a bulb under the waterline."""
    length, hull_h, _t, _h, xs, xb, deck_y = _side_geometry(hull_id)
    rows = {}
    bottom = SIDE_WL + 2
    for y in range(deck_y, bottom + 1):
        t = (y - deck_y) / max(1, bottom - deck_y)
        left = xs + round(3 * t)
        right = xb - round(5 * t)
        if y >= SIDE_WL:
            right = xb - 4                # the bulb pushes back out
        rows[y] = (left, right)
    return rows


def _side_frames(hull_id):
    length, hull_h, tiers, house_at, xs, xb, deck_y = _side_geometry(hull_id)
    rows = _side_rows(hull_id)
    base, paint, house = (new_img(SIDE_W, SIDE_H) for _ in range(3))
    trims = {p: new_img(SIDE_W, SIDE_H) for p in TRIM_PATTERNS}

    # hull: paint between the deck edge and the waterline, red below it
    for y, (x0, x1) in rows.items():
        for x in range(x0, x1 + 1):
            if y == deck_y:
                px(base, x, y, STEEL[3])
            elif y < SIDE_WL:
                shade = 3 if y == deck_y + 1 else 2 if y < SIDE_WL - 2 else 1
                px(base, x, y, PAINT[shade])
                px(paint, x, y, PAINT[shade])
                if y == deck_y + 2 and x0 + 1 < x < x1 - 1:
                    px(trims["stripe"], x, y, PAINT[4])
                if x > xb - length * 0.26:
                    px(trims["bow"], x, y, PAINT[shade + 1])
                if x < xs + length * 0.2:
                    px(trims["stern"], x, y, PAINT[shade + 1])
            else:
                px(base, x, y, BOOT[2] if y == SIDE_WL else BOOT[1])
    # a forecastle step up at the bow, painted like the hull
    for x in range(xb - 7, xb - 1):
        px(base, x, deck_y - 1, PAINT[3])
        px(paint, x, deck_y - 1, PAINT[3])
        px(trims["bow"], x, deck_y - 1, PAINT[4])
    # hawse pipe and a draught mark
    px(base, xb - 4, deck_y + 2, INK)
    px(paint, xb - 4, deck_y + 2, (0, 0, 0, 0))

    # where the house stands
    hw = 9 + tiers
    if house_at <= 0.0:
        hx = xs + 4
    else:
        hx = xs + int(length * house_at) - hw // 2
    house_h = tiers * 3 + 6
    htop = deck_y - house_h

    # containers: everything forward of the forecastle step and clear of the house
    import random
    rng = random.Random(hull_id)
    fore = xb - 9
    aft_limit = xs + 3 if house_at > 0.0 else hx + hw + 1
    x = fore - 5
    while x >= aft_limit:
        if house_at > 0.0 and hx - 2 < x + 5 and x < hx + hw + 1:
            x = hx - 7
            continue
        stack = tiers - (1 if rng.random() < 0.18 else 0)
        for k in range(stack):
            ramp = SIDE_BOXES[rng.randrange(len(SIDE_BOXES))]
            y = deck_y - 3 * (k + 1)
            rect(base, x, y, 5, 3, ramp[2])
            rect(base, x, y, 5, 1, ramp[3])
            px(base, x + 4, y + 1, ramp[1])
            px(base, x + 4, y + 2, ramp[1])
        x -= 6

    # the house: white tiers, a dark band of bridge windows, wings one px proud
    for y in range(htop, deck_y):
        for xx in range(hx, hx + hw):
            c = WHITE[3] if xx == hx else WHITE[1] if xx == hx + hw - 1 else WHITE[2]
            px(base, xx, y, c)
            px(house, xx, y, c)
    for xx in range(hx - 1, hx + hw + 1):
        px(base, xx, htop, WHITE[4])
        px(house, xx, htop, WHITE[4])
    for xx in range(hx, hx + hw):
        px(base, xx, htop + 2, GLASS[1] if xx % 2 else GLASS[3])
    for y in range(htop + 5, deck_y - 1, 3):          # cabin portholes
        for xx in range(hx + 2, hx + hw - 2, 3):
            px(base, xx, y, GLASS[2])
    # lifeboat hung on the house's flank
    rect(base, hx + hw - 1, deck_y - 4, 3, 2, ORANGE[3])

    # funnel: on the house aft end, or on its own near the stern of an ULCV
    fx = hx + 1 if house_at <= 0.0 else xs + 6
    ftop = htop - 4 if house_at <= 0.0 else deck_y - tiers * 3 - 4
    rect(base, fx, ftop, 4, (htop if house_at <= 0.0 else deck_y) - ftop,
         P.mix(WHITE[1], STEEL[1], 0.5))
    rect(base, fx, ftop, 4, 1, (38, 34, 40, 255))
    for layer in [paint] + list(trims.values()):
        rect(layer, fx, ftop + 1, 4, 2, PAINT[3])
    rect(base, fx, ftop + 1, 4, 2, PAINT[3])

    # foremast and the jackstaff
    for y in range(deck_y - 6, deck_y - 1):
        px(base, xb - 4, y, STEEL[2])
    px(base, xb - 4, deck_y - 7, P.WINDOW_LIT)

    # one outline round the lot, on the base layer
    whole = base.copy()
    ringed = outline(whole)
    bp, rp = base.load(), ringed.load()
    for yy in range(SIDE_H):
        for xx in range(SIDE_W):
            if bp[xx, yy][3] == 0 and rp[xx, yy][3]:
                bp[xx, yy] = rp[xx, yy]
    return [base, paint, house] + [trims[p] for p in TRIM_PATTERNS]


def gen_ship():
    global PROFILE
    for name, profile in PROFILES.items():
        PROFILE = profile
        suffix = "" if name == "panamax" else "_" + name
        img = new_img(W, H)
        hull(img, PAINT)
        # the neutral hull is darker than the livery layer will be, so the
        # untinted fallback still reads as paint rather than as primer
        deck(img)
        superstructure(img)
        details(img)
        save(outline(img), "ship_top" + suffix)

        # livery layer: hull paint and funnel band only, same canvas
        paint = new_img(W, H)
        hull(paint, PAINT)
        deck_cut = new_img(W, H)
        deck(deck_cut)
        superstructure(deck_cut, paint_layer=paint)
        # anything the deck or the house covers is not hull paint
        pp, dp = paint.load(), deck_cut.load()
        for y in range(H):
            for x in range(W):
                if dp[x, y][3] == 255 and not _is_funnel_band(x, y):
                    pp[x, y] = (0, 0, 0, 0)
        # keep the boot-topping red: it is antifouling, not livery
        for y in range(H - 4, H - 1):
            for x in range(W):
                if pp[x, y][3] and pp[x, y][0] != pp[x, y][1]:
                    pp[x, y] = (0, 0, 0, 0)
        save(paint, "ship_paint" + suffix)

        # trim sheet: one 66x232 frame per pattern, same order as TRIM_PATTERNS
        clean_cut = new_img(W, H)
        deck(clean_cut)
        superstructure(clean_cut)
        save(sheet([_trim(p, clean_cut) for p in TRIM_PATTERNS]),
             "ship_trim_" + name, preview_scale=2)

        # the album's side-on portrait
        save(sheet(_side_frames(name)), "ship_side_" + name, preview_scale=4)
    PROFILE = PROFILES["panamax"]
    save(_house_layer(), "ship_house")


if __name__ == "__main__":
    print("ship:")
    gen_ship()
