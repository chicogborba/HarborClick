"""The port's VFX strips, drawn for the pooled emitter in `scripts/fx/fx.gd`.

Five little sheets, each a horizontal strip of frames played over a particle's
life:

- `fx_dust`     4 frames of 10x10, a grey puff that grows and fades.
- `fx_spark`    4 frames of 7x7, an orange-yellow star that opens, flares, closes.
- `fx_splash`   4 frames of 12x8, water: the base widens while droplets rise
                and fall back into it.
- `fx_coin`     4 frames of 8x8, a gold coin spinning on its vertical axis
                (edge, narrow, full face, narrow).
- `fx_confetti` 6 frames of 4x4, solid blocks cycling the container liveries.

In game the particles are never rotated and never scaled, and every position is
a whole pixel, so every frame here is drawn axis-aligned.
"""
import palette as P
from common import new_img, patch, px, rect, save, sheet

GREY = P.ramp((172, 166, 168), 5, hue_shift=8.0, dark=0.35, light=0.6)
FIRE = P.ramp((250, 172, 56), 5, hue_shift=18.0, dark=0.5, light=0.75)
GOLD = P.ramp((246, 196, 64), 5, hue_shift=16.0, dark=0.45, light=0.7)
WATER = P.ramp((96, 164, 190), 5, hue_shift=10.0, dark=0.4, light=0.7)
FOAM = (232, 244, 244, 255)
## The container liveries, so confetti reads as cargo-coloured paper.
CONFETTI = [
    (214, 52, 70, 255), (246, 196, 64, 255), (72, 156, 150, 255),
    (72, 116, 172, 255), (142, 96, 138, 255), (92, 148, 88, 255),
]


def dust(frame):
    """A soft grey puff: bigger and fainter on each frame."""
    img = new_img(10, 10)
    radius = (2, 3, 3, 4)[frame]
    alpha = (255, 200, 130, 70)[frame]
    ry = radius if radius <= 2 else radius - 1
    patch(img, 5, 5, radius, ry, P.with_alpha(GREY[2], alpha), seed=frame + 1)
    inner = max(1, radius - 1)
    patch(img, 5, 5, inner, inner, P.with_alpha(GREY[3], alpha), seed=frame + 7)
    return img


def spark(frame):
    """A star that opens, flares and closes — the same beat as fx_sparkle,
    but in orange-yellow instead of gold."""
    img = new_img(7, 7)
    c = 3
    arm = (1, 2, 3, 1)[frame]
    core = (FIRE[3], FIRE[4], (255, 244, 210, 255), FIRE[3])[frame]
    for i in range(1, arm + 1):
        col = FIRE[4] if i < arm else FIRE[2]
        for dx, dy in ((i, 0), (-i, 0), (0, i), (0, -i)):
            px(img, c + dx, c + dy, col)
    if frame == 2:
        for dx, dy in ((1, 1), (-1, -1), (1, -1), (-1, 1)):
            px(img, c + dx, c + dy, FIRE[3])
    px(img, c, c, core)
    return img


def splash(frame):
    """Top-down water hit: a widening base along the bottom and droplets that
    pop up on frame 1 and fall back by frame 3."""
    img = new_img(12, 8)
    base_w = (4, 6, 8, 11)[frame]
    x0 = 6 - base_w // 2
    rect(img, x0, 6, base_w, 2, WATER[2])
    rect(img, x0, 6, base_w, 1, WATER[4])
    rect(img, x0 + 1, 7, base_w - 2, 1, WATER[1])
    drop_y = (4, 2, 3, 5)[frame]
    px(img, 5, drop_y, FOAM)
    px(img, 6, min(7, drop_y + 1), WATER[3])
    side_y = (5, 4, 4, 6)[frame]
    px(img, 3, side_y, WATER[3])
    px(img, 8, side_y, WATER[3])
    if frame == 3:
        px(img, 4, 5, FOAM)
        px(img, 7, 5, FOAM)
    return img


def coin(frame):
    """A gold coin spinning around its vertical axis: frame 0 is the edge,
    frame 2 the full face with a glint."""
    img = new_img(8, 8)
    rx = (0, 2, 3, 2)[frame]
    for x in range(4 - rx, 4 + rx + 1):
        t = (x - 4) / max(1, rx)
        hy = int(round(3.0 * (1.0 - t * t) ** 0.5))
        for y in range(4 - hy, 4 + hy + 1):
            edge = abs(x - 4) == rx or abs(y - 4) == hy
            if edge:
                px(img, x, y, GOLD[0])
            else:
                px(img, x, y, GOLD[2] if (x + y) % 2 == 0 else GOLD[3])
    if frame == 2:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            px(img, 4 + dx, 4 + dy, GOLD[1])
        px(img, 3, 3, GOLD[4])
    else:
        px(img, 4, 4, GOLD[3])
    return img


def confetti(frame):
    """One solid 4x4 block; the six frames cycle the livery colours."""
    img = new_img(4, 4)
    rect(img, 0, 0, 4, 4, CONFETTI[frame % len(CONFETTI)])
    return img


def gen_fx():
    save(sheet([dust(f) for f in range(4)]), "fx_dust")
    save(sheet([spark(f) for f in range(4)]), "fx_spark")
    save(sheet([splash(f) for f in range(4)]), "fx_splash")
    save(sheet([coin(f) for f in range(4)]), "fx_coin")
    save(sheet([confetti(f) for f in range(6)]), "fx_confetti")


if __name__ == "__main__":
    print("fx:")
    gen_fx()
