"""The golden gull and the sparkle it trails.

The rare thing a clicker is played *for*: something crosses the screen for a
few seconds, worth a lot, gone if nobody taps it. It is a bird and not a box on
purpose — cargo in this terminal only ever enters by ship, road or rail, so a
gift that appears out of nowhere cannot be a container. A gull carrying a
parcel can.

- `fx_gold_gull`  4 frames of 26x22, facing EAST (the game mirrors it to fly
                  west). Wingbeat order: up, level, down, level.
- `fx_sparkle`    4 frames of 7x7, a star that opens, flares and closes.
- `ui_daily_badge` 2 frames of 24x24: the Missões do Dia key, plain and lit.
"""
import math

import palette as P
from common import new_img, outline, px, rect, save, sheet

GOLD = P.ramp((246, 196, 64), 5, hue_shift=16.0, dark=0.45, light=0.7)
WHITE = (255, 252, 236, 255)
BEAK = (232, 104, 48, 255)
RIBBON = P.ramp((214, 52, 70), 5, hue_shift=12.0)
INK = (74, 44, 30, 255)


def gull(frame):
    """A gull from above, flying east, wings out to north and south.

    Built like the yard's white gulls — long angled wings with an elbow and
    dark tips, a slim body, a fanned tail — so it reads as *a bird* first and
    as gold second, with the parcel slung under it."""
    from PIL import ImageDraw
    img = new_img(26, 22)
    cy = 11
    draw = ImageDraw.Draw(img)
    # wing pose per frame: (elbow reach, tip reach, tip sweep back)
    elbow, tip, sweep = ((6, 10, 6), (5, 9, 4), (4, 6, 2), (5, 9, 4))[frame]
    for side in (-1, 1):
        shoulder = (13, cy + side * 1)
        elbow_pt = (12, cy + side * elbow)
        tip_pt = (12 - sweep, cy + side * tip)
        trail_elbow = (9, cy + side * (elbow - 1))
        trail_root = (8, cy + side * 1)
        poly = [shoulder, elbow_pt, tip_pt, trail_elbow, trail_root]
        draw.polygon(poly, fill=GOLD[3] if side < 0 else GOLD[2])
        # leading edge in the light, a dark tip
        draw.line([shoulder, elbow_pt, tip_pt], fill=GOLD[4] if side < 0 else GOLD[3])
        px(img, tip_pt[0], tip_pt[1], GOLD[0])
        px(img, tip_pt[0] + 1, tip_pt[1] - side, GOLD[1])
    # body: slim, along the flight line
    for x in range(6, 19):
        half = 1 if 7 <= x <= 17 else 0
        for y in range(cy - half, cy + half + 1):
            px(img, x, y, GOLD[3] if y < cy else GOLD[2])
        px(img, x, cy - half, GOLD[4])
    # head and beak
    rect(img, 18, cy - 1, 3, 3, GOLD[3])
    px(img, 18, cy - 1, WHITE)
    px(img, 20, cy - 1, INK)
    px(img, 21, cy, BEAK)
    px(img, 22, cy, BEAK)
    # fanned tail
    for dy in (-1, 0, 1):
        px(img, 5, cy + dy, GOLD[1])
    px(img, 4, cy - 1, GOLD[1])
    px(img, 4, cy + 1, GOLD[1])
    # the parcel slung under it, a little south so it reads beneath the bird
    rect(img, 11, cy + 2, 4, 3, GOLD[1])
    rect(img, 11, cy + 2, 4, 1, GOLD[3])
    rect(img, 12, cy + 2, 1, 3, RIBBON[2])
    px(img, 12, cy + 1, RIBBON[3])
    px(img, 13, cy - 1, WHITE)
    return outline(img, INK)


def sparkle(frame):
    img = new_img(7, 7)
    c = 3
    arm = (1, 2, 3, 1)[frame]
    core = (GOLD[3], WHITE, WHITE, GOLD[2])[frame]
    for i in range(1, arm + 1):
        col = GOLD[4] if i < arm else GOLD[3]
        for dx, dy in ((i, 0), (-i, 0), (0, i), (0, -i)):
            px(img, c + dx, c + dy, col)
    if frame == 2:
        for dx, dy in ((1, 1), (-1, -1), (1, -1), (-1, 1)):
            px(img, c + dx, c + dy, GOLD[3])
    px(img, c, c, core)
    return img


def daily_badge(lit=False):
    """The Missões do Dia key: a clipboard with three ticked lines. Lit, the
    paper glows and a gold star sits on the clip — something is waiting."""
    img = new_img(24, 24)
    board = P.ramp((150, 104, 62), 5, hue_shift=12.0)
    paper = (246, 238, 214, 255) if not lit else (255, 248, 204, 255)
    rect(img, 4, 3, 16, 19, board[2])
    rect(img, 4, 3, 16, 1, board[4])
    rect(img, 19, 4, 1, 18, board[1])
    rect(img, 6, 6, 12, 14, paper)
    rect(img, 17, 7, 1, 13, (214, 200, 168, 255))
    tick = (64, 150, 86, 255)
    for i, y in enumerate((8, 12, 16)):
        rect(img, 7, y, 2, 2, (214, 200, 168, 255))
        if i < 2 or lit:
            px(img, 7, y + 1, tick)
            px(img, 8, y, tick)
        rect(img, 10, y + 1, 6, 1, (150, 136, 112, 255))
    # the spring clip
    rect(img, 9, 1, 6, 4, P.ramp(P.STEEL, 5)[2])
    rect(img, 9, 1, 6, 1, P.ramp(P.STEEL, 5)[4])
    rect(img, 11, 2, 2, 1, P.ramp(P.STEEL, 5)[0])
    if lit:
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1), (0, 0)):
            px(img, 20 + dx, 3 + dy, GOLD[4] if (dx, dy) == (0, 0) else GOLD[3])
    return outline(img, INK)


def gen_bonus():
    save(sheet([gull(f) for f in range(4)]), "fx_gold_gull")
    save(sheet([sparkle(f) for f in range(4)]), "fx_sparkle")
    save(sheet([daily_badge(False), daily_badge(True)]), "ui_daily_badge")


if __name__ == "__main__":
    print("bonus:")
    gen_bonus()
