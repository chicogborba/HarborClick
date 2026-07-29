"""Top-down container ship, bow pointing UP, moored along a vertical quay.

Canvas 60x232. Deck cargo bays are drawn at runtime with container_sheet:
2 columns (x=6 and x=31 inside the sprite) x 11 rows starting at y=44,
each row 11px apart.
"""
import palette as P
from common import new_img, rect, hline, vline, px, outline, save, speckle

W, H = 66, 232
BOW_TIP = 3
DECK_X0, DECK_X1 = 2, 64      # hull outer edges
IN_X0, IN_X1 = 7, 59          # deck plating (inside the bulwarks)


def hull(img):
    # bow taper: from the tip down to full beam
    for y in range(BOW_TIP, 40):
        k = (y - BOW_TIP) / 36.0
        half = 2 + int((k ** 0.58) * 29)
        cx = W // 2
        rect(img, cx - half, y, half * 2, 1, P.HULL)
    # parallel midbody + stern
    for y in range(40, H - 6):
        rect(img, DECK_X0, y, DECK_X1 - DECK_X0, 1, P.HULL)
    # rounded stern
    for y in range(H - 6, H - 1):
        k = (y - (H - 6)) / 5.0
        inset = int(k * k * 10)
        rect(img, DECK_X0 + inset, y, (DECK_X1 - DECK_X0) - inset * 2, 1, P.HULL)
    # port highlight / starboard shade (light from upper-left)
    for y in range(BOW_TIP, H - 2):
        for x in range(W):
            if img.getpixel((x, y))[3] != 0:
                px(img, x, y, P.HULL_L)
                break
        for x in range(W - 1, -1, -1):
            if img.getpixel((x, y))[3] != 0:
                px(img, x, y, P.HULL_D)
                break


def deck(img):
    """Weathered deck plating between the bulwarks."""
    deck_w = IN_X1 - IN_X0
    rect(img, IN_X0, 30, deck_w, H - 44, P.DECK)
    speckle(img, IN_X0, 30, deck_w, H - 44, [P.DECK_D, P.DECK_L], 0.10, seed=3)
    # bulwark inner edges (dark line where the deck meets the rail)
    vline(img, IN_X0 - 1, 30, H - 44, P.HULL_D)
    vline(img, IN_X1, 30, H - 44, P.HULL_D)
    # forecastle deck (bow)
    for y in range(12, 30):
        k = (y - 12) / 18.0
        half = 4 + int(k * 22)
        cx = W // 2
        rect(img, cx - half, y, half * 2, 1, P.DECK_D)
    # windlass + anchor gear on the forecastle
    rect(img, 27, 18, 12, 5, P.STEEL_D)
    hline(img, 27, 18, 12, P.STEEL)
    px(img, 25, 20, P.STEEL_L)
    px(img, 40, 20, P.STEEL_L)
    # hatch coaming rails down the cargo area
    for x in (IN_X0, 32, IN_X1 - 1):
        vline(img, x, 44, 132, P.HATCH)
    # cargo hold hatch covers (seen where no containers sit)
    for row in range(12):
        y = 44 + row * 11
        for bx in (8, 34):
            rect(img, bx, y, 22, 10, P.HATCH)
            hline(img, bx, y, 22, P.HATCH_L)
            speckle(img, bx, y + 1, 22, 8, [P.DECK_D], 0.08, seed=row + bx)


def superstructure(img):
    """Accommodation block + funnel at the stern."""
    top = H - 52
    rect(img, 10, top, 46, 30, P.SUPER_W)
    hline(img, 10, top, 46, (240, 234, 222, 255))
    vline(img, 10, top, 30, (240, 234, 222, 255))
    vline(img, 55, top, 30, P.SUPER_W_D)
    hline(img, 10, top + 29, 46, P.SUPER_W_D)
    # bridge wings poking out over both sides
    rect(img, 4, top + 4, 6, 8, P.SUPER_W)
    rect(img, 56, top + 4, 6, 8, P.SUPER_W_D)
    # skylights on the roof
    for sx in (15, 26, 37, 48):
        rect(img, sx, top + 5, 5, 4, P.GLASS)
        px(img, sx, top + 5, P.GLASS_D)
    # funnel
    rect(img, 25, top + 13, 16, 12, P.CRANE_D)
    hline(img, 25, top + 13, 16, P.CRANE)
    rect(img, 28, top + 16, 10, 6, (48, 42, 46, 255))
    hline(img, 28, top + 16, 10, (70, 62, 66, 255))
    # lifeboats
    rect(img, 3, top + 16, 7, 10, P.SAFETY)
    hline(img, 3, top + 16, 7, P.SAFETY_L)
    rect(img, 56, top + 16, 7, 10, P.SAFETY_D)
    # stern mooring winches
    rect(img, 16, H - 18, 8, 5, P.STEEL_D)
    rect(img, 42, H - 18, 8, 5, P.STEEL_D)


def details(img):
    # nav lights: red to port (left), green to starboard (right)
    px(img, 4, 46, P.RED_LIGHT)
    px(img, W - 5, 46, P.GREEN_LIGHT)
    # bow mast
    rect(img, 31, 8, 4, 4, P.STEEL)
    px(img, 32, 7, P.STEEL_L)
    # mooring bitts along both bulwarks
    for y in range(52, H - 60, 34):
        px(img, DECK_X0 + 1, y, P.STEEL_L)
        px(img, DECK_X1 - 2, y, P.STEEL_L)


def gen_ship():
    img = new_img(W, H)
    hull(img)
    deck(img)
    superstructure(img)
    details(img)
    save(outline(img), "ship_top")


def gen_ship_wake():
    """Bow wake / moored ripple ring, drawn under the hull. 76x40, 4 frames."""
    from common import sheet
    frames = []
    for f in range(4):
        img = new_img(76, 40)
        for i in range(3):
            r = 8 + i * 9 + f * 2
            for a in range(0, 360, 6):
                import math
                x = int(38 + math.cos(math.radians(a)) * r)
                y = int(20 + math.sin(math.radians(a)) * r * 0.45)
                if 0 <= x < 76 and 0 <= y < 40:
                    px(img, x, y, P.SEA_SPARK if i < 2 else P.FOAM)
        frames.append(img)
    save(sheet(frames), "ship_wake")


if __name__ == "__main__":
    print("ship:")
    gen_ship()
    gen_ship_wake()
