"""Alisson, the terminal's project manager, who walks a new player through the port.

A 64x64 bust for the tutorial's dialogue box, shown at 2x. The same Alisson as
the crew roster (`npc_catalog.gd`): fair skin, short brown hair, and the blue
hard hat he never takes off, over a navy polo, the terminal's high-vis vest, a
radio and his ID badge.

Frames (`ui_guide.png`, a strip of 64x64):
    0 talking, mouth closed     1 talking, mouth open
    2 blink                     3 pointing (hand raised, mouth open)

One light source (upper left), hue-shifted ramps (warm lights, cool shadows),
a dark selout. Critiqued against the pixel-art-studio checklist at 1x and 4x.
"""
from common import new_img, rect, hline, vline, px, save, sheet

OUT = (34, 24, 30, 255)
# fair skin: peach lights, rosy-cool shadows
SKIN = [(146, 86, 78, 255), (196, 128, 108, 255), (230, 168, 140, 255),
        (246, 200, 172, 255), (255, 226, 204, 255)]
BLUSH = (236, 150, 140, 255)
# short brown hair
HAIR = [(58, 34, 26, 255), (92, 56, 38, 255), (128, 82, 52, 255),
        (164, 112, 72, 255)]
HAT = [(20, 42, 98, 255), (36, 74, 156, 255), (63, 122, 214, 255),
       (110, 166, 236, 255), (196, 224, 252, 255)]
POLO = [(18, 24, 44, 255), (30, 40, 70, 255), (48, 62, 100, 255),
        (72, 90, 134, 255)]
VEST = [(140, 58, 20, 255), (206, 98, 28, 255), (242, 140, 44, 255),
        (255, 186, 98, 255)]
REFLECT = [(140, 150, 164, 255), (214, 222, 232, 255), (246, 250, 252, 255)]
IRIS = [(66, 44, 30, 255), (110, 76, 46, 255)]
WHITE = (250, 246, 240, 255)
EYE_DARK = (34, 24, 30, 255)
MOUTH = [(110, 40, 46, 255), (160, 70, 72, 255)]
TEETH = (248, 244, 236, 255)
RADIO = [(24, 24, 30, 255), (56, 58, 68, 255), (96, 100, 112, 255)]
BADGE = [(200, 206, 214, 255), (246, 248, 250, 255)]
GOLD = (236, 184, 72, 255)


def selout(img, color=OUT):
    w, h = img.size
    src = img.copy().load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3]:
                    img.putpixel((x, y), color)
                    break
    return img


def shade_fill(img, mask, ramp, cx, cy, rx, ry, bias=0.0):
    """Fill `mask` points with `ramp`, lit from the upper left, banded softly."""
    n = len(ramp)
    for (x, y) in mask:
        dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        lit = -(dx * 0.75 + dy * 0.55) + bias
        if lit > 0.55:
            i = n - 1
        elif lit > 0.15:
            i = n - 2
        elif lit > -0.3:
            i = n - 3
        elif lit > -0.75:
            i = max(0, n - 4)
        else:
            i = 0
        px(img, x, y, ramp[i])


def ellipse_mask(cx, cy, rx, ry):
    pts = []
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                pts.append((x, y))
    return pts


def torso(img, pointing):
    """A small round body: the crew are all head and hard hat, so is he."""
    mask = []
    for y in range(48, 64):
        half = min(25, 12 + int((y - 48) * 1.1))
        for x in range(32 - half, 32 + half):
            mask.append((x, y))
    shade_fill(img, mask, POLO[1:], 26, 52, 28, 16, bias=0.1)
    rect(img, 28, 46, 8, 4, SKIN[1])
    hline(img, 28, 46, 8, SKIN[0])
    # hi-vis vest: two panels with a lit leading edge, open down the middle
    for y in range(49, 64):
        half = min(25, 12 + int((y - 48) * 1.1))
        lo, hi = 32 - half, 32 + half
        for x in range(lo, 28):
            px(img, x, y, VEST[3] if x < lo + 2 else VEST[2])
        for x in range(36, hi):
            px(img, x, y, VEST[1] if x < hi - 2 else VEST[0])
        px(img, 28, y, VEST[0])
        px(img, 35, y, VEST[2])
    for x in range(8, 28):
        px(img, x, 58, REFLECT[2] if x < 14 else REFLECT[1])
    for x in range(36, 57):
        px(img, x, 58, REFLECT[1])
    # ID badge and radio, scaled down to a toy's
    rect(img, 18, 51, 5, 5, BADGE[0])
    rect(img, 19, 52, 3, 2, BADGE[1])
    px(img, 19, 54, HAT[2])
    rect(img, 41, 50, 5, 7, RADIO[0])
    rect(img, 42, 51, 3, 2, RADIO[1])
    vline(img, 44, 46, 4, RADIO[0])
    px(img, 42, 54, (120, 230, 130, 255))
    if pointing:
        # a round mitten waving up beside the hat, one finger out
        hand = ellipse_mask(54.0, 40.0, 4.6, 4.6)
        shade_fill(img, hand, SKIN[1:], 53, 38, 4.6, 4.6)
        rect(img, 53, 31, 3, 6, SKIN[2])
        vline(img, 53, 31, 6, SKIN[3])
        px(img, 54, 31, SKIN[4])
        rect(img, 51, 44, 7, 5, VEST[1])
        vline(img, 51, 44, 5, VEST[2])


def head(img, mouth_open, blink):
    # a broad round head, wider than the shoulders
    for (ex, light) in ((13, True), (49, False)):
        for (x, y) in ellipse_mask(ex + 1.0, 36.0, 2.6, 3.4):
            px(img, x, y, SKIN[3] if light else SKIN[1])
    face = [p for p in ellipse_mask(32.0, 32.0, 18.5, 14.5) if p[1] < 47]
    shade_fill(img, face, SKIN, 28, 28, 19, 15, bias=0.2)
    # a little brown hair at the temples under the brim
    for y in range(22, 31):
        taper = max(0, y - 26)
        for x in range(15 + taper, 19 + taper // 2):
            px(img, x, y, HAIR[2] if x < 17 else HAIR[1])
        for x in range(46 - taper // 2, 50 - taper):
            px(img, x, y, HAIR[0])
    for x in range(21, 43, 3):
        px(img, x, 23, HAIR[1])
        px(img, x + 1, 23, HAIR[2])
    for x in range(20, 45):
        if img.getpixel((x, 22)) in SKIN:
            px(img, x, 22, SKIN[1])
    # big shiny eyes, wide apart
    if blink:
        for ex in (22, 38):
            hline(img, ex, 35, 5, EYE_DARK)
            px(img, ex, 34, EYE_DARK)
            px(img, ex + 4, 34, EYE_DARK)
    else:
        for ex in (22, 38):
            rect(img, ex, 30, 5, 7, EYE_DARK)
            px(img, ex, 30, SKIN[2]); px(img, ex + 4, 30, SKIN[2])
            px(img, ex, 36, SKIN[2]); px(img, ex + 4, 36, SKIN[2])
            rect(img, ex + 1, 31, 2, 2, WHITE)       # big catchlight
            px(img, ex + 3, 34, (96, 70, 62, 255))   # small one below
    # brows, high and soft
    for (x, y) in ((22, 28), (23, 27), (24, 27), (25, 27), (26, 28)):
        px(img, x, y, HAIR[0])
    for (x, y) in ((38, 28), (39, 27), (40, 27), (41, 27), (42, 28)):
        px(img, x, y, HAIR[0])
    # cheeks, round and pink
    for (x, y) in ((18, 38), (19, 38), (20, 38), (19, 39), (20, 39), (18, 39)):
        px(img, x, y, BLUSH)
    for (x, y) in ((44, 38), (45, 38), (46, 38), (44, 39), (45, 39), (46, 39)):
        px(img, x, y, BLUSH)
    # a button nose and a small happy mouth
    px(img, 32, 37, SKIN[1])
    px(img, 33, 37, SKIN[1])
    px(img, 32, 36, SKIN[3])
    if mouth_open:
        rect(img, 29, 40, 6, 3, MOUTH[0])
        hline(img, 30, 40, 4, TEETH)
        hline(img, 30, 42, 4, MOUTH[1])
    else:
        hline(img, 29, 40, 6, MOUTH[0])
        px(img, 28, 39, MOUTH[0])
        px(img, 35, 39, MOUTH[0])
        hline(img, 30, 41, 4, SKIN[1])
    hline(img, 29, 45, 6, SKIN[3])


def hard_hat(img):
    dome = []
    for y in range(4, 24):
        for x in range(11, 54):
            dx, dy = (x + 0.5 - 32.0) / 21.0, (y + 0.5 - 23.0) / 19.0
            if dx * dx + dy * dy <= 1.0:
                dome.append((x, y))
    shade_fill(img, dome, HAT[:4], 26, 10, 22, 14, bias=0.1)
    vline(img, 31, 5, 17, HAT[3])
    vline(img, 32, 5, 17, HAT[2])
    vline(img, 33, 5, 17, HAT[1])
    # a short round brim, tipped up at the front
    rect(img, 9, 21, 46, 2, HAT[2])
    hline(img, 9, 21, 46, HAT[3])
    hline(img, 11, 23, 42, HAT[0])
    # anchor sticker
    rect(img, 22, 11, 6, 6, (240, 238, 230, 255))
    vline(img, 25, 12, 4, GOLD)
    hline(img, 24, 13, 3, GOLD)
    hline(img, 24, 15, 3, GOLD)
    rect(img, 17, 8, 4, 2, HAT[4])
    px(img, 21, 7, HAT[4])
    px(img, 16, 10, HAT[3])


def frame(mouth_open=False, blink=False, pointing=False):
    """Drawn on a 16x16 grid and shown at 4x: each pixel is a 4x4 block, so he
    is a sign, not a portrait - hat, two dots, a vest."""
    g = new_img(16, 16)
    H, V, S = HAT, VEST, SKIN
    # hard hat: dome, a lit stripe, a wider brim
    rect(g, 5, 2, 6, 1, H[1]); rect(g, 4, 3, 8, 2, H[2])
    px(g, 5, 3, H[3]); px(g, 6, 3, H[3]); hline(g, 3, 5, 10, H[1])
    hline(g, 3, 5, 3, H[2])
    # face
    rect(g, 4, 6, 8, 5, S[3]); vline(g, 11, 6, 5, S[2]); hline(g, 4, 10, 8, S[2])
    if not blink:
        px(g, 6, 8, EYE_DARK); px(g, 9, 8, EYE_DARK)
    else:
        px(g, 6, 8, S[1]); px(g, 9, 8, S[1])
    px(g, 5, 9, BLUSH); px(g, 10, 9, BLUSH)
    px(g, 7, 10, MOUTH[0]); px(g, 8, 10, MOUTH[0])
    if mouth_open:
        px(g, 7, 9, MOUTH[0]); px(g, 8, 9, MOUTH[0])
    # body: hi-vis vest around a navy shirt, one reflective stripe
    rect(g, 2, 11, 12, 5, V[2]); rect(g, 7, 11, 2, 5, POLO[1])
    hline(g, 2, 13, 12, REFLECT[1]); px(g, 7, 13, POLO[2]); px(g, 8, 13, POLO[2])
    vline(g, 13, 11, 5, V[1]); hline(g, 2, 11, 12, V[3])
    if pointing:
        rect(g, 13, 7, 2, 4, S[3]); px(g, 13, 6, S[3])
    out = selout(g)
    big = out.resize((64, 64), 0)  # nearest: chunky pixels on purpose
    return big


def gen_guide():
    save(sheet([frame(), frame(mouth_open=True), frame(blink=True),
                frame(mouth_open=True, pointing=True)]), "ui_guide",
         preview_scale=6)


if __name__ == "__main__":
    gen_guide()
