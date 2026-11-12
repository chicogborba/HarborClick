"""The port diary: the book that replaced the notice bell.

ui_diary_key.png    24x24  the gantry key: a leather book with a gold anchor
ui_book.png         40x40  nine-patch: the open logbook every diary board is
ui_book_cover.png   40x40  nine-patch: its shut cover, swung open by `BookFx`
ui_book_emblem.png  44x44  the anchor-in-rope mark stamped on that cover
ui_book_tab_*.png   16x16  nine-patches: the index tabs, open and shut
ui_book_plate.png   16x16  nine-patch: the gold-ruled title label
ui_book_leaf.png    16x16  nine-patch: the leaf that turns between tabs
ui_trophy_final.png 32x32  the completionist's trophy (dimmed until earned)
"""
from common import new_img, rect, hline, vline, px, save, sheet, outline

LEATHER = [(64, 30, 22, 255), (102, 50, 30, 255), (138, 72, 40, 255),
           (172, 98, 56, 255)]
GOLD = [(140, 92, 24, 255), (214, 160, 52, 255), (252, 214, 96, 255),
        (255, 244, 186, 255)]
PAGE = [(196, 178, 140, 255), (232, 218, 186, 255), (250, 242, 220, 255)]
INK = (84, 68, 64, 255)
RIBBON = [(140, 30, 40, 255), (196, 56, 64, 255), (232, 96, 92, 255)]
LEATHER_XD = (38, 18, 16, 255)
STITCH = (206, 160, 104, 255)
# The top sheet is the UI's own PAPER (gen_ui), so the contrast suite's numbers
# for ink on a board hold on a page too.
SHEET = (238, 224, 198, 255)
SHEET_D = (206, 188, 156, 255)
SHEET_XD = (168, 148, 118, 255)


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


def _corner(img, x, y, fx, fy):
    """A brass corner protector, 6x6, flipped by (fx, fy)."""
    for i in range(6):
        for j in range(6 - i):
            tone = GOLD[1]
            if i == 0 or j == 0:
                tone = GOLD[2]
            if i + j == 5:
                tone = GOLD[0]
            px(img, x + (5 - i if fx else i), y + (5 - j if fy else j), tone)
    px(img, x + (4 if fx else 1), y + (4 if fy else 1), GOLD[3])


def _binding(img, s):
    """The leather every book surface shares: outline, lit top-left edge, a
    line of saddle stitching and brass corners. `s` is the square size."""
    rect(img, 0, 0, s, s, LEATHER_XD)
    rect(img, 1, 1, s - 2, s - 2, LEATHER[1])
    hline(img, 1, 1, s - 2, LEATHER[3])
    vline(img, 1, 1, s - 2, LEATHER[2])
    hline(img, 1, s - 2, s - 2, LEATHER[0])
    vline(img, s - 2, 1, s - 2, LEATHER[0])
    # stitching, period 4 so the 12px edge strips tile cleanly
    for i in range(3, s - 3):
        if i % 4 < 2:
            px(img, i, 3, STITCH); px(img, i, s - 4, STITCH)
            px(img, 3, i, STITCH); px(img, s - 4, i, STITCH)
    for (cx, cy, fx, fy) in ((1, 1, 0, 0), (s - 7, 1, 1, 0),
                             (1, s - 7, 0, 1), (s - 7, s - 7, 1, 1)):
        _corner(img, cx, cy, fx, fy)
    for (x, y) in ((0, 0), (s - 1, 0), (0, s - 1), (s - 1, s - 1)):
        px(img, x, y, (0, 0, 0, 0))


def gen_book():
    """40x40 nine-patch, margin 14: the logbook lying open.

    Leather binding all round, then the page block: two visible leaves of
    thickness on the right and bottom edges, and the top sheet in the game's
    own cream with the shadow of the binding along its top and left. The
    middle 12x12 is plain page and tiles.
    """
    s = 40
    img = new_img(s, s)
    _binding(img, s)
    rect(img, 6, 6, s - 12, s - 12, LEATHER_XD)
    rect(img, 7, 7, s - 14, s - 14, PAGE[0])
    # the leaves underneath, showing on the right and bottom
    rect(img, 7, 7, s - 16, s - 16, PAGE[1])
    vline(img, s - 9, 7, s - 15, PAGE[1]); vline(img, s - 8, 8, s - 15, PAGE[0])
    hline(img, 7, s - 9, s - 15, PAGE[1]); hline(img, 8, s - 8, s - 15, PAGE[0])
    rect(img, 7, 7, s - 17, s - 17, SHEET)
    hline(img, 7, 7, s - 17, SHEET_XD)
    hline(img, 7, 8, s - 17, SHEET_D)
    vline(img, 7, 7, s - 17, SHEET_D)
    save(img, "ui_book", preview_scale=6)


def gen_cover():
    """40x40 nine-patch, margin 14: the same book, shut. A blind-tooled gold
    rule runs inside the stitching; the middle is flat leather and tiles."""
    s = 40
    img = new_img(s, s)
    _binding(img, s)
    for i in range(8, s - 8):
        px(img, i, 8, GOLD[0]); px(img, i, s - 9, GOLD[0])
        px(img, 8, i, GOLD[0]); px(img, s - 9, i, GOLD[0])
    for (x, y) in ((8, 8), (s - 9, 8), (8, s - 9), (s - 9, s - 9)):
        px(img, x, y, GOLD[2])
    hline(img, 9, 9, s - 18, LEATHER[2])
    save(img, "ui_book_cover", preview_scale=6)


def gen_emblem():
    """44x44: the mark stamped on the cover: an anchor in a rope ring."""
    s = 44
    img = new_img(s, s)
    c = s // 2
    for yy in range(s):
        for xx in range(s):
            d2 = (xx - c + 0.5) ** 2 + (yy - c + 0.5) ** 2
            if 17.0 ** 2 <= d2 < 20.0 ** 2:
                twist = (xx + yy) % 4 < 2
                px(img, xx, yy, GOLD[2] if twist else GOLD[1])
            elif 20.0 ** 2 <= d2 < 21.0 ** 2:
                px(img, xx, yy, GOLD[0])
    g = GOLD
    # ring, stock, shank
    for (x, y) in ((c - 1, 9), (c, 9), (c - 2, 10), (c + 1, 10), (c - 2, 11),
                   (c + 1, 11), (c - 1, 12), (c, 12)):
        px(img, x, y, g[3])
    rect(img, c - 7, 15, 14, 2, g[2]); hline(img, c - 7, 16, 14, g[1])
    px(img, c - 8, 15, g[1]); px(img, c + 7, 15, g[1])
    rect(img, c - 1, 13, 2, 20, g[2]); vline(img, c, 13, 20, g[1])
    # arms and flukes
    arm = [(1, 32), (2, 32), (3, 31), (4, 31), (5, 30), (6, 29), (7, 28),
           (8, 27), (8, 26), (9, 25)]
    for (dx, y) in arm:
        for sx in (-1, 1):
            x = c - 1 + (dx if sx > 0 else -dx) + (1 if sx > 0 else 0)
            px(img, x, y, g[2]); px(img, x, y + 1, g[1])
    for sx in (-1, 1):
        tip = c + sx * 10 - (0 if sx > 0 else 1)
        for (dx, dy) in ((0, 23), (0, 24), (-sx, 23), (sx, 24), (sx, 25)):
            px(img, tip + dx, dy, g[3])
    px(img, c - 1, 33, g[1]); px(img, c, 33, g[0])
    save(img, "ui_book_emblem", preview_scale=6)


def gen_tabs():
    """16x16 nine-patches, margin 5: index tabs cut into the fore-edge. The
    open one is the page itself; the others are older, darker stock."""
    for name, face, lip in (("ui_book_tab_on", SHEET, PAGE[2]),
                            ("ui_book_tab_off", PAGE[0], PAGE[1])):
        s = 16
        img = new_img(s, s)
        rect(img, 0, 0, s, s, LEATHER_XD)
        rect(img, 1, 1, s - 2, s - 1, face)
        hline(img, 1, 1, s - 2, lip)
        if name.endswith("off"):
            hline(img, 1, s - 1, s - 2, LEATHER_XD)
            hline(img, 1, s - 2, s - 2, SHEET_XD)
        px(img, 0, 0, (0, 0, 0, 0)); px(img, s - 1, 0, (0, 0, 0, 0))
        save(img, name, preview_scale=8)


def gen_plate():
    """16x16 nine-patch, margin 5: the title label pasted on the binding —
    dark morocco with a gold rule."""
    s = 16
    img = new_img(s, s)
    rect(img, 0, 0, s, s, LEATHER_XD)
    rect(img, 1, 1, s - 2, s - 2, LEATHER[0])
    for i in range(2, s - 2):
        px(img, i, 2, GOLD[0]); px(img, i, s - 3, GOLD[1])
        px(img, 2, i, GOLD[0]); px(img, s - 3, i, GOLD[1])
    for (x, y) in ((2, 2), (s - 3, 2), (2, s - 3), (s - 3, s - 3)):
        px(img, x, y, GOLD[2])
    save(img, "ui_book_plate", preview_scale=8)


def gen_leaf():
    """16x16 nine-patch, margin 5: one loose leaf, for the page that turns."""
    s = 16
    img = new_img(s, s)
    rect(img, 0, 0, s, s, PAGE[0])
    rect(img, 1, 1, s - 2, s - 2, SHEET)
    vline(img, s - 2, 1, s - 2, PAGE[1])
    vline(img, s - 3, 1, s - 2, SHEET_D)
    hline(img, 1, 1, s - 2, PAGE[2])
    save(img, "ui_book_leaf", preview_scale=8)


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
    gen_book()
    gen_cover()
    gen_emblem()
    gen_tabs()
    gen_plate()
    gen_leaf()
    gen_trophy()


if __name__ == "__main__":
    gen_diary()
