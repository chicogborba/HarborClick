"""Generates the profile-screen harbour panorama.

The title art is source-controlled as code like every other HarborClick
sprite. It is intentionally a tiny 160x240 painting so nearest-neighbour
scaling keeps the same pixel vocabulary as the live terminal.
"""
from PIL import ImageDraw

import palette as P
from common import dither_rows, hline, new_img, px, rect, save, speckle, vline


W, H = 160, 240


def _container(img, x, y, color_pair):
    top, side = color_pair
    rect(img, x, y, 11, 5, P.OUTLINE)
    rect(img, x + 1, y + 1, 9, 3, top)
    hline(img, x + 1, y + 4, 9, side)
    for rib in range(x + 3, x + 10, 3):
        vline(img, rib, y + 1, 3, side)


def _crane(img, x, y, height):
    # Gantry legs and boom, with one lit machinery cabin.
    rect(img, x, y - height, 3, height, P.CRANE_D)
    rect(img, x + 22, y - height, 3, height, P.CRANE_D)
    rect(img, x + 1, y - height + 1, 2, height - 2, P.CRANE)
    rect(img, x + 23, y - height + 1, 2, height - 2, P.CRANE)
    rect(img, x - 2, y - height, 34, 3, P.OUTLINE)
    rect(img, x - 1, y - height + 1, 32, 1, P.CRANE_L)
    rect(img, x + 27, y - height + 2, 3, 18, P.CRANE)
    rect(img, x + 26, y - 17, 7, 6, P.OUTLINE)
    rect(img, x + 27, y - 16, 5, 4, P.WINDOW_LIT)
    px(img, x + 28, y - 15, P.SUN)


def gen_title_port():
    img = new_img(W, H)

    # Layered dusk sky. Wide hard bands read as hand-placed pixel clusters
    # once doubled on a phone rather than as a smooth digital gradient.
    sky = [
        (26, 31, 52, 255), (34, 43, 68, 255), (45, 60, 84, 255),
        (66, 78, 96, 255), (108, 91, 96, 255), (170, 112, 94, 255),
    ]
    band_h = 15
    for i, color in enumerate(sky):
        rect(img, 0, i * band_h, W, band_h + 1, color)
    dither_rows(img, 0, 58, W, 24, (196, 126, 94, 255), 1)

    # Sun, clouds and distant city.
    ImageDraw.Draw(img).ellipse([111, 29, 131, 49], fill=(244, 177, 91, 255))
    ImageDraw.Draw(img).ellipse([115, 33, 127, 45], fill=(252, 210, 125, 255))
    for x, y, width in ((12, 25, 27), (66, 39, 22), (125, 18, 18)):
        hline(img, x, y, width, (51, 55, 76, 255))
        hline(img, x + 5, y - 2, width - 10, (61, 64, 85, 255))
    rect(img, 0, 76, W, 15, (37, 42, 56, 255))
    for x, height in ((3, 8), (12, 13), (21, 6), (33, 17), (47, 10),
                      (59, 15), (74, 7), (85, 18), (99, 11), (117, 15),
                      (133, 9), (145, 18)):
        rect(img, x, 90 - height, 8, height, (31, 35, 48, 255))
        if x % 3 == 0:
            px(img, x + 3, 86 - height // 2, P.WINDOW_LIT)

    # Harbour water and reflections.
    rect(img, 105, 89, 55, H - 89, P.SEA_DEEP)
    for y in range(94, H, 9):
        hline(img, 108 + (y % 5), y, 20 + (y % 17), P.SEA)
        hline(img, 132 - (y % 7), y + 2, 18, P.SEA_LIGHT)
    for y in range(92, 170, 5):
        width = max(1, 13 - (y - 92) // 8)
        hline(img, 121 - width // 2, y, width, (214, 151, 88, 190))

    # Yard, quay edge, service road and markings.
    rect(img, 0, 89, 101, H - 89, P.YARD_D)
    speckle(img, 0, 89, 101, H - 89,
            [P.YARD, P.YARD_PATCH, P.YARD_L], 0.07, seed=3107)
    rect(img, 101, 89, 5, H - 89, P.QUAY_D)
    vline(img, 102, 89, H - 89, P.QUAY_L)
    vline(img, 105, 89, H - 89, P.PAINT_Y)
    rect(img, 5, 95, 14, 145, (76, 74, 82, 255))
    vline(img, 11, 98, 137, P.PAINT_W)
    for y in range(101, 235, 12):
        rect(img, 11, y, 1, 6, P.YARD_D)

    # Container blocks in perspective-like bands.
    colors = list(P.CONTAINERS.values())
    for row, y in enumerate(range(104, 213, 14)):
        for col, x in enumerate(range(25, 91, 13)):
            if (row * 3 + col) % 7 == 0:
                continue
            _container(img, x, y, colors[(row + col * 2) % len(colors)])
            if (row + col) % 4 == 0:
                _container(img, x, y - 5,
                           colors[(row + col * 2 + 3) % len(colors)])

    # Two ship-to-shore cranes frame the playable-looking terminal.
    _crane(img, 77, 157, 54)
    _crane(img, 69, 223, 48)

    # Ship alongside, lights and wake.
    rect(img, 119, 103, 27, 103, P.OUTLINE)
    rect(img, 121, 105, 23, 98, P.HULL_D)
    rect(img, 123, 108, 19, 91, P.DECK)
    rect(img, 125, 111, 15, 18, P.SUPER_W_D)
    rect(img, 126, 112, 13, 16, P.SUPER_W)
    rect(img, 128, 114, 3, 4, P.GLASS_D)
    rect(img, 134, 114, 3, 4, P.GLASS_D)
    for row, y in enumerate(range(134, 190, 8)):
        _container(img, 126, y, colors[(row * 2) % len(colors)])
    px(img, 121, 108, (246, 72, 62, 255))
    px(img, 143, 108, (238, 248, 232, 255))
    for y in range(207, 231, 5):
        hline(img, 122 + (y % 3), y, 21 - (y - 207) // 2, P.FOAM)

    # Foreground fence and lamps give the panorama depth.
    hline(img, 0, 226, 103, P.OUTLINE)
    hline(img, 0, 228, 103, P.STEEL)
    for x in range(2, 101, 10):
        vline(img, x, 222, 18, P.STEEL_D)
    for x in (20, 54, 94):
        vline(img, x, 211, 16, P.STEEL_D)
        rect(img, x - 2, 208, 5, 4, P.OUTLINE)
        rect(img, x - 1, 209, 3, 2, P.WINDOW_LIT)
        px(img, x, 208, P.SUN)

    save(img, "ui_title_port", preview_scale=3)


if __name__ == "__main__":
    gen_title_port()
