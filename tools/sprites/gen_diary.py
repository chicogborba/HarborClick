"""The port diary: the book that replaced the notice bell.

ui_diary_key.png    24x24  the gantry key: a leather book with a gold anchor
ui_diary_open.png   5 x 64x48  the book opening, shown at 3x before the pages
ui_trophy_final.png 32x32  the completionist's trophy (dimmed until earned)
"""
from common import new_img, rect, hline, vline, px, save, sheet, outline

LEATHER = [(64, 30, 22, 255), (102, 50, 30, 255), (138, 72, 40, 255),
           (172, 98, 56, 255)]
GOLD = [(140, 92, 24, 255), (214, 160, 52, 255), (252, 214, 96, 255),
        (255, 244, 186, 255)]
PAGE = [(196, 178, 140, 255), (232, 218, 186, 255), (250, 242, 220, 255)]
INK = (84, 68, 64, 255)
RIBBON = [(140, 30, 40, 255), (196, 56, 64, 255)]


def _anchor(img, cx, cy, big=False):
    """A small gold anchor, the terminal's mark."""
    g = GOLD
    vline(img, cx, cy - (4 if big else 3), 8 if big else 6, g[2])
    hline(img, cx - 1, cy - (3 if big else 2), 3, g[2])
    px(img, cx, cy - (5 if big else 4), g[3])
    w = 3 if big else 2
    hline(img, cx - w, cy + (3 if big else 2), 2 * w + 1, g[1])
    px(img, cx - w, cy + (2 if big else 1), g[2])
    px(img, cx + w, cy + (2 if big else 1), g[2])


def _cover(img, x, y, w, h, inside=False):
    """A closed cover from (x, y), `w` wide: leather, gold corners, an anchor."""
    if w <= 0:
        return
    base = LEATHER[1] if not inside else LEATHER[0]
    rect(img, x, y, w, h, base)
    hline(img, x, y, w, LEATHER[2] if not inside else LEATHER[1])
    vline(img, x, y, h, LEATHER[3] if not inside else LEATHER[1])
    hline(img, x, y + h - 1, w, LEATHER[0])
    if w >= 8 and not inside:
        for (cx, cy) in ((x + 1, y + 1), (x + w - 3, y + 1),
                         (x + 1, y + h - 3), (x + w - 3, y + h - 3)):
            rect(img, cx, cy, 2, 2, GOLD[1])
            px(img, cx, cy, GOLD[2])
        if w >= 14:
            _anchor(img, x + w // 2, y + h // 2, big=h > 20)


def gen_key():
    img = new_img(24, 24)
    # page block peeking out on the right and bottom
    rect(img, 6, 4, 14, 17, PAGE[1])
    for yy in range(5, 20, 2):
        hline(img, 18, yy, 2, PAGE[0])
    _cover(img, 4, 3, 15, 17)
    # ribbon hanging out of the bottom
    vline(img, 15, 20, 3, RIBBON[1])
    px(img, 15, 22, RIBBON[0])
    save(outline(img), "ui_diary_key", preview_scale=8)


def _spread(img, x, y, w, h):
    """An open book: leather border, two cream pages, a few written lines."""
    rect(img, x, y, w, h, LEATHER[1])
    hline(img, x, y, w, LEATHER[2])
    hline(img, x, y + h - 1, w, LEATHER[0])
    half = w // 2
    rect(img, x + 2, y + 2, half - 3, h - 4, PAGE[2])
    rect(img, x + half + 1, y + 2, half - 3, h - 4, PAGE[2])
    vline(img, x + half - 1, y + 2, h - 4, PAGE[0])
    vline(img, x + half, y + 2, h - 4, PAGE[0])
    for i in range(5):
        yy = y + 6 + i * 6
        if yy < y + h - 5:
            hline(img, x + 5, yy, half - 9 - (i % 2) * 4, PAGE[0])
            hline(img, x + half + 4, yy, half - 9 - ((i + 1) % 2) * 5, PAGE[0])
    # the ribbon across the gutter
    vline(img, x + half, y + 1, h - 1, RIBBON[1])
    px(img, x + half, y + h - 1, RIBBON[0])


def gen_open():
    frames = []
    W, H = 64, 48
    bx, by, bw, bh = 16, 3, 32, 42
    for step in range(5):
        img = new_img(W, H)
        if step < 4:
            # the page block under the cover
            rect(img, bx + 2, by + 1, bw - 1, bh - 1, PAGE[1])
            for yy in range(by + 3, by + bh - 2, 3):
                hline(img, bx + bw - 1, yy, 2, PAGE[0])
        if step == 0:
            _cover(img, bx, by, bw, bh)
        elif step == 1:
            # the cover swinging toward the viewer: narrower and lit
            _cover(img, bx, by, 20, bh)
            vline(img, bx + 20, by, bh, LEATHER[3])
        elif step == 2:
            # edge-on, the spine side: a thin strip
            rect(img, bx - 2, by, 4, bh, LEATHER[2])
            vline(img, bx - 2, by, bh, LEATHER[3])
            rect(img, bx + 2, by + 1, bw - 1, bh - 1, PAGE[2])
        elif step == 3:
            # past vertical: the inside of the cover on the left
            _cover(img, bx - 18, by, 18, bh, inside=True)
            rect(img, bx + 2, by + 1, bw - 1, bh - 1, PAGE[2])
        else:
            _spread(img, 2, 3, 60, 42)
        frames.append(outline(img))
    save(sheet(frames), "ui_diary_open", preview_scale=4)


def gen_trophy():
    img = new_img(32, 32)
    g = GOLD
    # cup bowl
    for yy in range(4, 16):
        half = 9 - max(0, (yy - 10) // 2)
        for xx in range(16 - half, 16 + half):
            c = g[2] if xx < 13 else (g[1] if xx < 20 else g[0])
            px(img, xx, yy, c)
    hline(img, 7, 4, 18, g[3])
    # handles
    for (hx, d) in ((5, -1), (26, 1)):
        vline(img, hx, 6, 6, g[1])
        px(img, hx - d, 5, g[1])
        px(img, hx - d, 12, g[1])
    # stem and base
    rect(img, 14, 16, 4, 5, g[1])
    vline(img, 14, 16, 5, g[2])
    rect(img, 10, 21, 12, 3, g[1])
    hline(img, 10, 21, 12, g[2])
    rect(img, 8, 24, 16, 4, LEATHER[1])
    hline(img, 8, 24, 16, LEATHER[2])
    rect(img, 13, 25, 6, 2, g[2])
    # star on the bowl
    for (sx, sy) in ((16, 7), (15, 8), (16, 8), (17, 8), (14, 9), (15, 9),
                     (16, 9), (17, 9), (18, 9), (15, 10), (17, 10)):
        px(img, sx, sy, g[3])
    px(img, 10, 6, g[3])
    px(img, 11, 7, g[3])
    save(outline(img), "ui_trophy_final", preview_scale=8)


def gen_diary():
    gen_key()
    gen_open()
    gen_trophy()


if __name__ == "__main__":
    gen_diary()
