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
    # shoulders: a trapezoid of navy polo
    mask = []
    for y in range(46, 64):
        half = min(29, 11 + int((y - 46) * 1.9))
        for x in range(32 - half, 32 + half):
            mask.append((x, y))
    shade_fill(img, mask, POLO[1:], 26, 50, 30, 18, bias=0.1)
    # collar points and the open neck
    for i in range(5):
        px(img, 25 + i, 46 + i, POLO[3])
        px(img, 38 - i, 46 + i, POLO[2])
    rect(img, 29, 46, 6, 4, SKIN[1])
    hline(img, 29, 46, 6, SKIN[0])
    # vest panels with a lit leading edge
    for y in range(49, 64):
        half = min(29, 11 + int((y - 46) * 1.9))
        lo, hi = 32 - half, 32 + half
        for x in range(lo, 27):
            px(img, x, y, VEST[3] if x < lo + 2 else VEST[2] if x < 22 else VEST[1])
        for x in range(37, hi):
            px(img, x, y, VEST[1] if x < hi - 3 else VEST[0])
        px(img, 26, y, VEST[0])
        px(img, 37, y, VEST[2])
    # reflective bands
    for x in range(4, 27):
        px(img, x, 57, REFLECT[2] if x < 12 else REFLECT[1])
        px(img, x, 58, REFLECT[0])
    for x in range(37, 61):
        px(img, x, 57, REFLECT[1])
        px(img, x, 58, REFLECT[0])
    # ID badge on the left panel, lanyard clip
    rect(img, 14, 50, 7, 6, BADGE[0])
    rect(img, 15, 51, 5, 2, BADGE[1])
    rect(img, 15, 53, 2, 2, HAT[2])
    hline(img, 17, 54, 3, POLO[2])
    vline(img, 17, 48, 2, RADIO[2])
    # radio on the right panel, antenna up, a green led
    rect(img, 42, 49, 6, 9, RADIO[0])
    rect(img, 43, 50, 4, 3, RADIO[1])
    hline(img, 43, 54, 4, RADIO[1])
    hline(img, 43, 56, 4, RADIO[1])
    vline(img, 46, 43, 6, RADIO[0])
    px(img, 46, 43, RADIO[2])
    px(img, 44, 51, (120, 230, 130, 255))
    if pointing:
        # raised hand at his left shoulder, index finger up
        hand = ellipse_mask(55.0, 40.0, 4.2, 4.6)
        shade_fill(img, hand, SKIN[1:], 54, 39, 4.2, 4.6)
        rect(img, 53, 30, 3, 7, SKIN[2])
        vline(img, 53, 30, 7, SKIN[3])
        vline(img, 55, 31, 6, SKIN[1])
        px(img, 54, 30, SKIN[4])
        hline(img, 52, 38, 6, SKIN[1])
        rect(img, 52, 44, 7, 4, VEST[1])
        vline(img, 52, 44, 4, VEST[2])


def head(img, mouth_open, blink):
    # neck with a soft shadow under the jaw
    rect(img, 27, 38, 10, 9, SKIN[2])
    hline(img, 27, 38, 10, SKIN[1])
    hline(img, 27, 39, 10, SKIN[1])
    vline(img, 36, 38, 9, SKIN[1])
    # ears
    for (ex, light) in ((16, True), (46, False)):
        ear = ellipse_mask(ex + 1.0, 29.0, 2.4, 3.6)
        for (x, y) in ear:
            px(img, x, y, SKIN[3] if light else SKIN[1])
        px(img, ex + 1, 29, SKIN[1] if light else SKIN[0])
    # face: a slightly long oval with a defined jaw
    face = [p for p in ellipse_mask(32.0, 28.0, 13.5, 14.5) if p[1] < 41]
    shade_fill(img, face, SKIN, 30, 25, 14, 15, bias=0.15)
    # jaw shadow on the far side
    for y in range(31, 41):
        for x in range(40, 46):
            if img.getpixel((x, y))[3] and img.getpixel((x, y)) in SKIN[2:]:
                px(img, x, y, SKIN[1])
    # hair: short brown, full at the temples and over the ears under the hat,
    # tapering into sideburns
    for y in range(19, 31):
        taper = max(0, y - 26)
        for x in range(16 + taper // 2, 21 - taper):
            px(img, x, y, HAIR[3] if x == 16 + taper // 2 and y < 24 else
               HAIR[2] if x < 19 else HAIR[1])
        for x in range(43 + taper, 48 - taper // 2):
            px(img, x, y, HAIR[0] if x >= 46 - taper // 2 else HAIR[1])
    for y in range(21, 26):
        px(img, 17, y, HAIR[3])
    # fringe peeking under the brim
    for x in range(20, 44):
        if x % 3 != 0:
            px(img, x, 19, HAIR[1] if x < 32 else HAIR[0])
    for x in range(21, 30, 2):
        px(img, x, 20, HAIR[2])
    # ears over the hair
    for (ex, light) in ((15, True), (47, False)):
        for (x, y) in ellipse_mask(ex + 1.0, 30.0, 2.2, 3.4):
            px(img, x, y, SKIN[3] if light else SKIN[1])
        px(img, ex + 1, 30, SKIN[1] if light else SKIN[0])
    # brim shadow across the forehead
    for x in range(20, 45):
        if img.getpixel((x, 20)) in SKIN:
            px(img, x, 20, SKIN[1])
    # eyebrows: brown, a friendly arch
    for (x, y) in ((22, 24), (23, 23), (24, 23), (25, 23), (26, 23), (27, 24)):
        px(img, x, y, HAIR[0])
    for (x, y) in ((36, 24), (37, 23), (38, 23), (39, 23), (40, 23), (41, 24)):
        px(img, x, y, HAIR[0])
    # eyes
    if blink:
        hline(img, 23, 27, 5, EYE_DARK)
        hline(img, 37, 27, 5, EYE_DARK)
        px(img, 23, 26, SKIN[1])
        px(img, 41, 26, SKIN[1])
    else:
        for ex in (23, 37):
            rect(img, ex, 26, 5, 3, WHITE)
            rect(img, ex + 1, 26, 3, 3, IRIS[1])
            px(img, ex + 2, 27, EYE_DARK)
            px(img, ex + 2, 26, IRIS[0])
            px(img, ex + 1, 26, WHITE)  # catchlight
            hline(img, ex, 25, 5, EYE_DARK)  # upper lid line
            px(img, ex - 1, 26, EYE_DARK)
    # nose: lit bridge, shadowed side and tip
    vline(img, 32, 27, 4, SKIN[3])
    vline(img, 33, 28, 4, SKIN[1])
    hline(img, 31, 32, 4, SKIN[1])
    px(img, 30, 32, SKIN[0])
    px(img, 34, 32, SKIN[0])
    # cheeks
    for (x, y) in ((22, 31), (23, 31), (22, 32)):
        px(img, x, y, BLUSH)
    for (x, y) in ((41, 31), (42, 31), (42, 32)):
        px(img, x, y, (216, 136, 128, 255))
    # mouth: an easy smile, or mid-word
    if mouth_open:
        hline(img, 28, 35, 9, MOUTH[0])
        rect(img, 29, 36, 7, 2, MOUTH[0])
        hline(img, 29, 35, 7, TEETH)
        hline(img, 30, 37, 5, MOUTH[1])
        hline(img, 30, 38, 5, SKIN[1])
    else:
        hline(img, 28, 35, 9, MOUTH[0])
        px(img, 27, 34, MOUTH[0])
        px(img, 37, 34, MOUTH[0])
        hline(img, 29, 36, 7, SKIN[1])
    # chin light
    hline(img, 30, 39, 4, SKIN[3])


def hard_hat(img):
    dome = []
    for y in range(3, 20):
        for x in range(14, 51):
            dx, dy = (x + 0.5 - 32.0) / 17.0, (y + 0.5 - 20.0) / 17.0
            if dx * dx + dy * dy <= 1.0:
                dome.append((x, y))
    shade_fill(img, dome, HAT[:4], 27, 10, 18, 12, bias=0.1)
    # centre ridge
    vline(img, 31, 4, 15, HAT[3])
    vline(img, 32, 4, 15, HAT[2])
    vline(img, 33, 4, 15, HAT[1])
    # brim: wide, lit lip, shadowed under-edge
    rect(img, 10, 19, 44, 2, HAT[2])
    hline(img, 10, 19, 44, HAT[3])
    hline(img, 12, 21, 40, HAT[0])
    # the terminal's anchor sticker
    rect(img, 22, 11, 5, 5, (240, 238, 230, 255))
    vline(img, 24, 12, 3, GOLD)
    hline(img, 23, 12, 3, GOLD)
    hline(img, 23, 14, 3, GOLD)
    # specular glint
    rect(img, 19, 7, 3, 2, HAT[4])
    px(img, 22, 6, HAT[4])
    px(img, 18, 9, HAT[3])


def frame(mouth_open=False, blink=False, pointing=False):
    img = new_img(64, 64)
    torso(img, pointing)
    head(img, mouth_open, blink)
    hard_hat(img)
    return selout(img)


def gen_guide():
    save(sheet([frame(), frame(mouth_open=True), frame(blink=True),
                frame(mouth_open=True, pointing=True)]), "ui_guide",
         preview_scale=6)


if __name__ == "__main__":
    gen_guide()
