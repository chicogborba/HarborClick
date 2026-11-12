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
}


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
                if dp[x, y][3] == 255 and not (HOUSE_TOP + 20 <= y <= HOUSE_TOP + 22 and 26 <= x < 40):
                    pp[x, y] = (0, 0, 0, 0)
        # keep the boot-topping red: it is antifouling, not livery
        for y in range(H - 4, H - 1):
            for x in range(W):
                if pp[x, y][3] and pp[x, y][0] != pp[x, y][1]:
                    pp[x, y] = (0, 0, 0, 0)
        save(paint, "ship_paint" + suffix)
    PROFILE = PROFILES["panamax"]


if __name__ == "__main__":
    print("ship:")
    gen_ship()
