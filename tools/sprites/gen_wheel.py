"""The Roda da Sorte: a carnival wheel bolted to the terminal's steel.

Pixel art cannot be rotated — a sprite turned 13 degrees is resampled into mush
— so the disc is not one picture spun in-engine. It is 64 pictures, each
computed pixel by pixel at its own angle (`DISC_FRAMES`), so every segment edge
is crisp at every step of the spin. The lighting does not turn with it: the
sheen is a separate static layer, because the sun does not rotate with a wheel.

Contract with `LuckyWheelPanel` (scripts/ui/lucky_wheel_panel.gd):

- `ui_wheel_disc`    DISC_FRAMES frames of DISC x DISC, laid out in a horizontal
                     strip. Frame k is the disc turned clockwise by k * 360/64
                     degrees. Segment i is centred on the pointer (12 o'clock) in
                     frame (64 - i * 8) % 64. Centre at (DISC/2, DISC/2).
- `ui_wheel_sheen`   DISC x DISC, static light over the disc.
- `ui_wheel_rim`     RIM x RIM brass ring with 16 bulb sockets, drawn over the
                     disc, same centre.
- `ui_wheel_bulbs`   2 frames of RIM x RIM: the even and the odd bulbs lit.
                     Meant to be drawn additively.
- `ui_wheel_pointer` 2 frames of 15x19: at rest, and kicked by a peg.
                     Pivot at (7, 2); the tip points down at the disc.
- `ui_wheel_hub`     22x22 cap over the centre.
- `ui_wheel_icons`   8 frames of 14x14, one per segment in `LuckyWheel.SEGMENTS`
                     order. Drawn upright at ICON_RADIUS from the centre.
- `ui_wheel_stand`   the pedestal the wheel stands on.
- `ui_wheel_badge`   2 frames of 24x24: the small wheel on the HUD button, and
                     the same with its bulbs lit (a free spin is waiting).
"""
import math

import palette as P
from common import new_img, px, rect, save, sheet

DISC = 104
DISC_FRAMES = 64
RIM = 124
SEGMENTS = 8
ICON_RADIUS = 31
INK = (34, 26, 38, 255)

# One ramp per segment, in `LuckyWheel.SEGMENTS` order. Neighbours alternate
# warm and cool so no two adjacent slices read as one; the jackpot is the only
# gold and the frenzy the only hot pink, so the two big prizes find the eye.
SEGMENT_BASES = [
    (54, 168, 156),    # cash_s   teal
    (238, 132, 48),    # surge2   orange
    (64, 112, 204),    # cash_m   blue
    (96, 178, 74),     # respin   green
    (250, 200, 64),    # jackpot  gold
    (226, 76, 60),     # surge3   red
    (138, 84, 196),    # cash_l   purple
    (234, 72, 150),    # frenzy   hot pink
]
SEG = [P.ramp(c, 5, hue_shift=14.0, dark=0.42, light=0.5) for c in SEGMENT_BASES]
BRASS = P.ramp((214, 160, 64), 5, hue_shift=14.0, dark=0.45, light=0.6)
STEEL = P.ramp((70, 82, 112), 5, hue_shift=12.0, dark=0.45, light=0.55)
CREAM = (252, 240, 214, 255)
BULB_OFF = (120, 84, 60, 255)
BULB_ON = (255, 236, 150, 255)


def _angle_cw_from_top(dx, dy):
    """Degrees clockwise from 12 o'clock, screen coordinates (y down)."""
    return math.degrees(math.atan2(dx, -dy)) % 360.0


def disc_frame(k):
    img = new_img(DISC, DISC)
    c = (DISC - 1) / 2.0
    rot = k * 360.0 / DISC_FRAMES
    seg_span = 360.0 / SEGMENTS
    r_out = DISC / 2.0 - 1.0
    for y in range(DISC):
        for x in range(DISC):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy)
            if r > r_out:
                continue
            # angle in the disc's own frame: the disc turned clockwise by `rot`
            a = (_angle_cw_from_top(dx, dy) - rot) % 360.0
            seg = int(((a + seg_span / 2.0) % 360.0) // seg_span)
            within = ((a + seg_span / 2.0) % 360.0) - seg * seg_span  # 0..span
            ramp_ = SEG[seg]
            if r > r_out - 2.0:
                col = INK
            elif r > r_out - 7.0:
                col = ramp_[3]                 # the outer band, nearest the bulbs
            elif r > 26.0:
                col = ramp_[2]
            else:
                col = ramp_[1]
            # dividers: a cream spoke at each segment boundary
            edge_px = min(within, seg_span - within) * math.pi / 180.0 * r
            if edge_px < 0.75 and r < r_out - 2.0:
                col = CREAM if r > 13.0 else BRASS[3]
            elif edge_px < 1.6 and r < r_out - 2.0:
                col = P.mix(col, INK, 0.35)  # the shadow beside each spoke
            px(img, x, y, col)
    # pegs: brass studs on the rim at every boundary — the pointer ticks on these
    for i in range(SEGMENTS):
        a = math.radians(i * seg_span - seg_span / 2.0 + rot)
        pr = r_out - 4.5
        sx, sy = c + math.sin(a) * pr, c - math.cos(a) * pr
        ix, iy = int(round(sx - 0.5)), int(round(sy - 0.5))
        rect(img, ix, iy, 2, 2, BRASS[2])
        px(img, ix, iy, BRASS[4])
        px(img, ix + 1, iy + 1, BRASS[0])
    return img


def sheen():
    """Static light over the disc: a warm glint up-left, a cool shade down-right."""
    img = new_img(DISC, DISC)
    c = (DISC - 1) / 2.0
    r_out = DISC / 2.0 - 3.0
    for y in range(DISC):
        for x in range(DISC):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy)
            if r > r_out:
                continue
            # project on the light direction (from the north-west)
            t = (-dx - dy) / (r_out * 1.414)
            if t > 0.62 and r > r_out * 0.7:
                px(img, x, y, (255, 250, 220, 56))
            elif t < -0.55 and r > r_out * 0.6:
                px(img, x, y, (20, 10, 40, 52))
    return img


def _ring(img, cx, cy, r0, r1, colour_at):
    for y in range(img.height):
        for x in range(img.width):
            r = math.hypot(x - cx, y - cy)
            if r0 <= r <= r1:
                c = colour_at(x - cx, y - cy, r)
                if c:
                    px(img, x, y, c)


def rim():
    img = new_img(RIM, RIM)
    c = (RIM - 1) / 2.0
    r_in = DISC / 2.0 - 2.0

    def brass(dx, dy, r):
        t = (-dx - dy) / max(1.0, r * 1.414)       # lit from the north-west
        band = 4 if t > 0.6 else 3 if t > 0.1 else 2 if t > -0.5 else 1
        if r > RIM / 2.0 - 2.0 or r < r_in + 1.0:
            return INK
        if abs(r - (r_in + 4.0)) < 0.6:
            return BRASS[0]                          # the groove the bulbs sit in
        return BRASS[band]

    _ring(img, c, c, r_in, RIM / 2.0 - 1.0, brass)
    for x, y in _bulb_positions():
        rect(img, x - 1, y - 1, 3, 3, INK)
        px(img, x, y, BULB_OFF)
    return img


def _bulb_positions():
    c = (RIM - 1) / 2.0
    r = (DISC / 2.0 - 2.0 + RIM / 2.0 - 1.0) / 2.0 + 1.0
    out = []
    for i in range(16):
        a = math.radians(i * 22.5)
        out.append((int(round(c + math.sin(a) * r)), int(round(c - math.cos(a) * r))))
    return out


def bulbs():
    frames = []
    for phase in range(2):
        img = new_img(RIM, RIM)
        for i, (x, y) in enumerate(_bulb_positions()):
            if i % 2 != phase:
                continue
            px(img, x, y, BULB_ON)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                px(img, x + dx, y + dy, (255, 210, 110, 150))
            for dx, dy in ((1, 1), (-1, -1), (1, -1), (-1, 1)):
                px(img, x + dx, y + dy, (255, 190, 90, 60))
        frames.append(img)
    return frames


def pointer(kicked=False):
    """A red flag-shaped pointer under a brass cap. Kicked, it leans back as a
    peg passes under it — the tick you can see."""
    img = new_img(15, 19)
    red = P.ramp((222, 58, 52), 5, hue_shift=14.0)
    lean = 1 if kicked else 0
    for y in range(4, 18):
        half = max(0, 5 - (y - 4) * 5 // 13)
        x0 = 7 - half + (lean if y > 9 else 0)
        for x in range(x0, x0 + half * 2 + 1):
            col = red[3] if x < x0 + half else red[2]
            px(img, x, y, col)
        px(img, x0, y, red[4])
        px(img, x0 + half * 2, y, red[1])
    rect(img, 4, 0, 7, 5, BRASS[2])                  # the cap that holds the pivot
    rect(img, 4, 0, 7, 1, BRASS[4])
    rect(img, 4, 4, 7, 1, BRASS[0])
    px(img, 7, 2, INK)
    return _outline_soft(img)


def _outline_soft(img):
    from common import outline
    return outline(img, INK)


def hub():
    img = new_img(22, 22)
    c = 10.5
    for y in range(22):
        for x in range(22):
            r = math.hypot(x - c, y - c)
            if r > 10.5:
                continue
            t = (-(x - c) - (y - c)) / 15.0
            col = BRASS[4] if t > 0.55 else BRASS[3] if t > 0.0 else BRASS[2] if t > -0.6 else BRASS[1]
            if r > 9.6:
                col = INK
            px(img, x, y, col)
    # a five-point star stamped in the cap
    star = ["....##....",
            "....##....",
            "...####...",
            "##########",
            ".########.",
            "..######..",
            "..##..##..",
            ".##....##."]
    for sy, row in enumerate(star):
        for sx, ch in enumerate(row):
            if ch == "#":
                px(img, 6 + sx, 7 + sy, CREAM if sy < 4 else P.mix(CREAM, BRASS[2], 0.4))
    return img


# --------------------------------------------------------------------- icons

def _icon_canvas():
    return new_img(14, 14)


def icon_coins(stack=2):
    """Three gold coins in a little pile, face on."""
    img = _icon_canvas()
    gold = BRASS
    for cx, cy in ((4.5, 9.0), (9.5, 9.0), (7.0, 4.5)):
        for y in range(14):
            for x in range(14):
                d = math.hypot(x - cx, y - cy)
                if d <= 3.3:
                    t = (cx - x) + (cy - y)
                    px(img, x, y, gold[4] if t > 2.0 else gold[3] if t > -1.2 else gold[1])
        px(img, int(cx), int(cy), gold[0])
    return _outline_soft(img)


def icon_mult(digit):
    """x2 / x3: a turbo chip with the multiplier on it."""
    img = _icon_canvas()
    chip = P.ramp((60, 70, 96), 5)
    rect(img, 1, 2, 12, 10, chip[1])
    rect(img, 1, 2, 12, 1, chip[3])
    rect(img, 1, 11, 12, 1, chip[0])
    lit = (255, 226, 120, 255)
    # x
    for i in range(4):
        px(img, 2 + i, 5 + i, lit)
        px(img, 5 - i, 5 + i, lit)
    # digit, 3x5
    glyphs = {2: ["###", "..#", "###", "#..", "###"],
              3: ["###", "..#", "###", "..#", "###"],
              7: ["###", "..#", ".#.", ".#.", ".#."]}
    for gy, row in enumerate(glyphs[digit]):
        for gx, ch in enumerate(row):
            if ch == "#":
                px(img, 8 + gx, 4 + gy, lit)
    return _outline_soft(img)


def icon_bag():
    img = _icon_canvas()
    sack = P.ramp((186, 140, 82), 5)
    for y in range(4, 13):
        half = 2 + min(3, (y - 4))
        rect(img, 7 - half, y, half * 2, 1, sack[2] if y < 9 else sack[1])
        px(img, 7 - half, y, sack[3])
    rect(img, 5, 2, 4, 2, sack[1])
    rect(img, 4, 4, 6, 1, BRASS[3])                  # the tie
    rect(img, 6, 7, 2, 4, BRASS[3])                  # a coin mark on the sack
    px(img, 6, 7, BRASS[4])
    return _outline_soft(img)


def icon_ticket():
    img = _icon_canvas()
    t = P.ramp((96, 178, 74), 5)
    rect(img, 1, 3, 12, 8, t[3])
    rect(img, 1, 3, 12, 1, t[4])
    rect(img, 1, 10, 12, 1, t[1])
    px(img, 1, 6, (0, 0, 0, 0))                       # the notches
    px(img, 1, 7, (0, 0, 0, 0))
    px(img, 12, 6, (0, 0, 0, 0))
    px(img, 12, 7, (0, 0, 0, 0))
    for y in range(4, 10, 2):
        px(img, 4, y, t[1])                          # perforation
    rect(img, 7, 5, 3, 1, CREAM)                     # "+1"
    rect(img, 8, 4, 1, 3, CREAM)
    rect(img, 11, 4, 1, 5, CREAM)
    return _outline_soft(img)


def icon_crown():
    img = _icon_canvas()
    g = BRASS
    rect(img, 2, 7, 10, 5, g[2])
    rect(img, 2, 11, 10, 1, g[0])
    for x, h in ((2, 4), (6, 5), (11, 4)):
        rect(img, x, 7 - h, 1 if x != 6 else 2, h, g[3])
        px(img, x, 7 - h, g[4])
    rect(img, 3, 5, 8, 2, g[3])
    px(img, 4, 9, (232, 72, 96, 255))                # jewels
    px(img, 7, 9, (80, 170, 240, 255))
    px(img, 9, 9, (232, 72, 96, 255))
    return _outline_soft(img)


def icon_safe():
    img = _icon_canvas()
    s = P.ramp((92, 100, 128), 5)
    rect(img, 1, 2, 12, 10, s[2])
    rect(img, 1, 2, 12, 1, s[4])
    rect(img, 1, 11, 12, 1, s[0])
    rect(img, 12, 3, 1, 8, s[1])
    rect(img, 3, 4, 8, 6, s[1])
    rect(img, 6, 5, 2, 2, BRASS[3])                  # the dial
    px(img, 6, 5, BRASS[4])
    px(img, 9, 7, BRASS[3])                          # the handle
    px(img, 9, 8, BRASS[2])
    return _outline_soft(img)


def icon_bolt():
    img = _icon_canvas()
    y_ = (255, 226, 96, 255)
    w_ = (255, 250, 220, 255)
    pts = [(8, 1), (7, 2), (6, 3), (5, 4), (4, 5), (3, 6), (4, 7), (5, 7), (6, 7),
           (7, 7), (6, 8), (5, 9), (4, 10), (3, 11), (3, 12)]
    for x, yy in pts:
        rect(img, x, yy, 3, 1, y_)
    for x, yy in pts[:5]:
        px(img, x + 1, yy, w_)
    return _outline_soft(img)


def icons():
    return [icon_coins(1), icon_mult(2), icon_bag(), icon_ticket(), icon_crown(),
            icon_mult(3), icon_safe(), icon_bolt()]


def stand():
    """Steel pedestal under the wheel, riveted like the gantry it shares a HUD with."""
    img = new_img(56, 26)
    rect(img, 22, 0, 12, 14, STEEL[2])
    rect(img, 22, 0, 2, 14, STEEL[3])
    rect(img, 32, 0, 2, 14, STEEL[1])
    rect(img, 4, 14, 48, 10, STEEL[2])
    rect(img, 4, 14, 48, 1, STEEL[4])
    rect(img, 4, 23, 48, 1, STEEL[0])
    rect(img, 4, 18, 48, 2, BRASS[2])
    rect(img, 4, 18, 48, 1, BRASS[4])
    for rx in range(8, 50, 8):
        px(img, rx, 16, STEEL[4])
        px(img, rx, 21, STEEL[0])
    return _outline_soft(img)


def badge(lit=False):
    """The HUD button's wheel: eight slices, a hub, and a pointer on top."""
    img = new_img(24, 24)
    c = 11.5
    for y in range(24):
        for x in range(24):
            dx, dy = x - c, y - c + 1
            r = math.hypot(dx, dy)
            if r > 10.0:
                continue
            if r > 9.0:
                px(img, x, y, BULB_ON if lit and (x + y) % 3 == 0 else BRASS[1])
                continue
            a = _angle_cw_from_top(dx, dy)
            seg = int(((a + 22.5) % 360.0) // 45.0)
            px(img, x, y, SEG[seg][3] if r > 5.0 else SEG[seg][2])
    rect(img, 10, 10, 4, 4, BRASS[3])
    px(img, 10, 10, BRASS[4])
    rect(img, 10, 0, 4, 3, (222, 58, 52, 255))
    px(img, 11, 3, (222, 58, 52, 255))
    px(img, 12, 3, (222, 58, 52, 255))
    return _outline_soft(img)


def gen_wheel():
    save(sheet([disc_frame(k) for k in range(DISC_FRAMES)]), "ui_wheel_disc", preview_scale=1)
    save(sheen(), "ui_wheel_sheen")
    save(rim(), "ui_wheel_rim")
    save(sheet(bulbs()), "ui_wheel_bulbs")
    save(sheet([pointer(False), pointer(True)]), "ui_wheel_pointer")
    save(hub(), "ui_wheel_hub")
    save(sheet(icons()), "ui_wheel_icons")
    save(stand(), "ui_wheel_stand")
    save(sheet([badge(False), badge(True)]), "ui_wheel_badge")


if __name__ == "__main__":
    print("wheel:")
    gen_wheel()
