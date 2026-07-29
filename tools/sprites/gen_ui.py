"""UI chrome: 9-patch panels, buttons, tabs and icons.

The look is a dockside manifest board — riveted steel frame around warm
parchment, amber buttons, everything with a hard 1px shadow.
"""
import palette as P
from common import new_img, rect, hline, vline, px, save, sheet, speckle

# --- UI palette (kept local so the world palette stays about the world) ---
FRAME_D = (52, 40, 46, 255)
FRAME = (86, 70, 74, 255)
FRAME_L = (124, 104, 104, 255)
PAPER = (238, 224, 198, 255)
PAPER_D = (214, 196, 166, 255)
PAPER_L = (250, 240, 218, 255)
PLATE_D = (34, 30, 44, 255)
PLATE = (52, 46, 66, 255)
PLATE_L = (78, 70, 96, 255)
AMBER_D = (176, 112, 30, 255)
AMBER = (232, 160, 48, 255)
AMBER_L = (252, 202, 96, 255)
TEAL_D = (34, 96, 96, 255)
TEAL = (60, 148, 140, 255)
TEAL_L = (104, 194, 176, 255)
INK = (58, 44, 46, 255)


def rivet(img, x, y, light=FRAME_L, dark=FRAME_D):
    px(img, x, y, light)
    px(img, x + 1, y + 1, dark)


def gen_panel():
    """18x18 nine-patch: riveted steel frame, parchment field. Margin 6."""
    s = 18
    img = new_img(s, s)
    rect(img, 0, 0, s, s, FRAME)
    hline(img, 0, 0, s, FRAME_L)
    vline(img, 0, 0, s, FRAME_L)
    hline(img, 0, s - 1, s, FRAME_D)
    vline(img, s - 1, 0, s, FRAME_D)
    # inner bevel + paper field
    rect(img, 3, 3, s - 6, s - 6, FRAME_D)
    rect(img, 4, 4, s - 8, s - 8, PAPER)
    hline(img, 4, 4, s - 8, PAPER_L)
    vline(img, 4, 4, s - 8, PAPER_L)
    hline(img, 4, s - 5, s - 8, PAPER_D)
    # corner rivets
    for rx, ry in ((1, 1), (s - 4, 1), (1, s - 4), (s - 4, s - 4)):
        rivet(img, rx, ry)
    save(img, "ui_panel")


def gen_plate():
    """18x18 nine-patch: dark navy readout plate for the counter."""
    s = 18
    img = new_img(s, s)
    rect(img, 0, 0, s, s, FRAME)
    hline(img, 0, 0, s, FRAME_L)
    vline(img, 0, 0, s, FRAME_L)
    hline(img, 0, s - 1, s, FRAME_D)
    vline(img, s - 1, 0, s, FRAME_D)
    rect(img, 3, 3, s - 6, s - 6, PLATE_D)
    # the centre tile gets stretched, so it has to stay perfectly flat —
    # any texture in there turns into big rectangles on a wide panel
    rect(img, 4, 4, s - 8, s - 8, PLATE)
    hline(img, 4, 4, s - 8, PLATE_L)
    for rx, ry in ((1, 1), (s - 4, 1), (1, s - 4), (s - 4, s - 4)):
        rivet(img, rx, ry, AMBER, FRAME_D)
    save(img, "ui_plate")


def gen_row():
    """12x12 nine-patch: shop row card. Margin 4."""
    s = 12
    img = new_img(s, s)
    rect(img, 0, 0, s, s, PAPER_D)
    rect(img, 1, 1, s - 2, s - 2, PAPER)
    hline(img, 1, 1, s - 2, PAPER_L)
    vline(img, 1, 1, s - 2, PAPER_L)
    hline(img, 1, s - 2, s - 2, PAPER_D)
    hline(img, 0, 0, s, (188, 168, 138, 255))
    vline(img, 0, 0, s, (188, 168, 138, 255))
    save(img, "ui_row")

    # dimmed variant for anything you cannot afford yet
    off = new_img(s, s)
    rect(off, 0, 0, s, s, (176, 164, 148, 255))
    rect(off, 1, 1, s - 2, s - 2, (198, 186, 168, 255))
    hline(off, 1, 1, s - 2, (212, 202, 184, 255))
    hline(off, 0, 0, s, (152, 140, 126, 255))
    save(off, "ui_row_off")


def _button(base, light, dark, name):
    s = 12
    img = new_img(s, s)
    rect(img, 0, 0, s, s, dark)
    rect(img, 1, 0, s - 2, s - 1, base)
    hline(img, 2, 0, s - 4, light)
    vline(img, 1, 1, s - 3, light)
    hline(img, 1, s - 1, s - 2, dark)
    # clipped corners so it reads as a rounded key
    px(img, 0, 0, (0, 0, 0, 0))
    px(img, s - 1, 0, (0, 0, 0, 0))
    px(img, 0, s - 1, (0, 0, 0, 0))
    px(img, s - 1, s - 1, (0, 0, 0, 0))
    save(img, name)


def gen_buttons():
    _button(AMBER, AMBER_L, AMBER_D, "ui_btn")
    _button(AMBER_D, AMBER, (128, 78, 20, 255), "ui_btn_down")
    _button(TEAL, TEAL_L, TEAL_D, "ui_btn_alt")
    _button((110, 100, 112, 255), (146, 136, 146, 255), (74, 66, 78, 255),
            "ui_btn_off")


def gen_tabs():
    s = 12
    for name, base, light, dark in (
            ("ui_tab_on", PAPER, PAPER_L, PAPER_D),
            ("ui_tab_off", (150, 134, 120, 255), (176, 160, 144, 255),
             (118, 104, 94, 255))):
        img = new_img(s, s)
        rect(img, 0, 0, s, s, base)
        hline(img, 1, 0, s - 2, light)
        vline(img, 0, 1, s - 1, light)
        vline(img, s - 1, 1, s - 1, dark)
        px(img, 0, 0, (0, 0, 0, 0))
        px(img, s - 1, 0, (0, 0, 0, 0))
        save(img, name)


def gen_bar():
    """Progress bar background + fill, 8x8 nine-patch."""
    bg = new_img(8, 8)
    rect(bg, 0, 0, 8, 8, PLATE_D)
    rect(bg, 1, 1, 6, 6, (44, 38, 54, 255))
    hline(bg, 1, 1, 6, (30, 26, 40, 255))
    save(bg, "ui_bar_bg")

    fill = new_img(8, 8)
    rect(fill, 0, 0, 8, 8, TEAL)
    hline(fill, 0, 0, 8, TEAL_L)
    hline(fill, 0, 7, 8, TEAL_D)
    save(fill, "ui_bar_fill")


# ------------------------------------------------------------------ icons
def _icon_base():
    return new_img(12, 12)


def gen_icons():
    icons = {}

    # TEU: a container seen at a slight angle
    i = _icon_base()
    rect(i, 1, 4, 10, 5, (198, 108, 70, 255))
    hline(i, 1, 4, 10, (232, 148, 100, 255))
    hline(i, 1, 8, 10, (150, 74, 50, 255))
    for x in range(2, 10, 2):
        vline(i, x, 5, 3, (162, 84, 56, 255))
    icons["teu"] = i

    # crane: gantry silhouette
    i = _icon_base()
    hline(i, 1, 2, 10, (200, 92, 78, 255))
    hline(i, 1, 3, 10, (150, 60, 58, 255))
    vline(i, 2, 3, 8, (200, 92, 78, 255))
    vline(i, 9, 3, 8, (200, 92, 78, 255))
    vline(i, 6, 4, 3, (130, 126, 138, 255))
    rect(i, 5, 7, 3, 2, (238, 176, 62, 255))
    icons["crane"] = i

    # ship: hull from above
    i = _icon_base()
    for y in range(2, 10):
        k = min(1.0, (y - 2) / 3.0)
        half = int(1 + k * 3)
        rect(i, 6 - half, y, half * 2, 1, (70, 94, 128, 255))
    rect(i, 4, 6, 4, 3, (226, 218, 202, 255))
    icons["ship"] = i

    # land: a fenced plot
    i = _icon_base()
    rect(i, 1, 3, 10, 7, (152, 114, 76, 255))
    speckle(i, 2, 4, 8, 5, [(122, 88, 58, 255)], 0.3, seed=2)
    for x in range(1, 12, 3):
        vline(i, x, 2, 3, (226, 218, 202, 255))
    hline(i, 1, 3, 10, (226, 218, 202, 255))
    icons["land"] = i

    # star: prestige
    i = _icon_base()
    for y, row in enumerate([
            "....##....", "....##....", ".########.", "..######..",
            "..######..", ".##....##."]):
        for x, c in enumerate(row):
            if c == "#":
                px(i, x + 1, y + 3, (250, 208, 96, 255))
    icons["star"] = i

    # gear: settings
    i = _icon_base()
    for y, row in enumerate([
            "..#..#..", ".######.", "#.####.#", "##.##.##",
            "##.##.##", "#.####.#", ".######.", "..#..#.."]):
        for x, c in enumerate(row):
            if c == "#":
                px(i, x + 2, y + 2, (196, 190, 190, 255))
    rect(i, 5, 5, 2, 2, PLATE_D)
    icons["gear"] = i

    # speaker: audio toggle
    i = _icon_base()
    rect(i, 2, 5, 2, 3, (196, 190, 190, 255))
    for y, row in enumerate(["..#", ".##", "###", "###", ".##", "..#"]):
        for x, c in enumerate(row):
            if c == "#":
                px(i, x + 4, y + 3, (196, 190, 190, 255))
    for wy, wx in ((4, 8), (5, 9), (6, 9), (7, 8)):
        px(i, wx, wy, (104, 194, 176, 255))
    icons["sound"] = i

    # clock: idle rate
    i = _icon_base()
    for y in range(12):
        for x in range(12):
            d = ((x - 5.5) ** 2 + (y - 5.5) ** 2) ** 0.5
            if d <= 4.6:
                px(i, x, y, (226, 218, 202, 255))
            if 3.6 < d <= 4.6:
                px(i, x, y, (140, 128, 128, 255))
    vline(i, 5, 3, 3, INK)
    hline(i, 6, 6, 2, INK)
    icons["clock"] = i

    # cat paw: the boost
    i = _icon_base()
    rect(i, 3, 6, 6, 4, (196, 148, 96, 255))
    for cx in (2, 4, 6, 8):
        rect(i, cx, 3, 2, 2, (196, 148, 96, 255))
    icons["paw"] = i

    order = ["teu", "crane", "ship", "land", "star", "gear", "sound", "clock",
             "paw"]
    save(sheet([icons[k] for k in order]), "ui_icons")
    print("    icon order:", ", ".join(order))


if __name__ == "__main__":
    print("ui:")
    gen_panel()
    gen_plate()
    gen_row()
    gen_buttons()
    gen_tabs()
    gen_bar()
    gen_icons()
