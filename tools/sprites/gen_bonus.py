"""The golden gull and the sparkle it trails.

The rare thing a clicker is played *for*: something crosses the screen for a
few seconds, worth a lot, gone if nobody taps it. It is a bird and not a box on
purpose — cargo in this terminal only ever enters by ship, road or rail, so a
gift that appears out of nowhere cannot be a container. A gull carrying a
parcel can.

- `fx_gold_gull`  4 frames of 24x20, facing EAST (the game mirrors it to fly
                  west). Wingbeat order: up, level, down, level.
- `fx_sparkle`    4 frames of 7x7, a star that opens, flares and closes.
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
    img = new_img(24, 20)
    cy = 10
    # wings first, so the body sits on them. Swept back, tapering to the tip.
    reach = (8, 6, 4, 6)[frame]           # how far each wing extends north/south
    lift = (-1, 0, 1, 0)[frame]
    for side in (-1, 1):
        for i in range(1, reach + 1):
            y = cy + side * (i + 1) + (lift if side < 0 else -lift) * (i // 3)
            x_root = 13 - i // 2           # swept back toward the tail
            width = max(1, 5 - i // 2)
            for dx in range(width):
                col = GOLD[3] if side < 0 else GOLD[2]
                if dx == 0:
                    col = GOLD[4] if side < 0 else GOLD[3]   # leading edge catches light
                if i == reach and dx == width - 1:
                    col = GOLD[1]                            # dark wingtip
                px(img, x_root - dx, y, col)
    # body: a fat teardrop along the flight line
    for x in range(6, 18):
        half = 2 if 8 <= x <= 15 else 1
        for y in range(cy - half, cy + half + 1):
            col = GOLD[2]
            if y < cy:
                col = GOLD[3]
            if y == cy - half:
                col = GOLD[4]
            px(img, x, y, col)
    # head and beak
    rect(img, 17, cy - 1, 3, 3, GOLD[3])
    px(img, 17, cy - 1, WHITE)
    px(img, 19, cy - 1, INK)               # eye
    px(img, 20, cy, BEAK)
    px(img, 21, cy, BEAK)
    # tail fan
    for dy in (-1, 0, 1):
        px(img, 5, cy + dy, GOLD[1])
    px(img, 4, cy, GOLD[1])
    # the parcel in its feet, a little south of the body so it reads under it
    rect(img, 9, cy + 2, 5, 4, GOLD[1])
    rect(img, 9, cy + 2, 5, 1, GOLD[3])
    rect(img, 11, cy + 2, 1, 4, RIBBON[2])
    rect(img, 9, cy + 3, 5, 1, RIBBON[2])
    px(img, 11, cy + 1, RIBBON[3])
    # glints
    px(img, 12, cy - 1, WHITE)
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


def gen_bonus():
    save(sheet([gull(f) for f in range(4)]), "fx_gold_gull")
    save(sheet([sparkle(f) for f in range(4)]), "fx_sparkle")


if __name__ == "__main__":
    print("bonus:")
    gen_bonus()
