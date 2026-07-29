"""UI chrome: the foreman's clipboard.

Every overlay in HarborClick is one physical object you could pick up on the
quay: a weathered wooden clipboard with a steel spring clip holding a stack of
manifest paper. Cards are rows torn off that manifest, prices are ink stamped
on a dark slate, and the only saturated colours are the amber "GO" keys and the
teal service tags — the same two accents the machines wear in the yard.

The old flat rounded panels were drawn at runtime with StyleBoxFlat, which
anti-aliased its corners and never matched the pixel grid. Everything here is
a nine-patch so the interface stays in the same material as the port.
"""
from common import new_img, rect, hline, vline, px, save, sheet, speckle

# --- UI palette (kept local so the world palette stays about the world) ---
WOOD_D = (74, 50, 38, 255)
WOOD = (112, 78, 54, 255)
WOOD_L = (150, 108, 74, 255)
WOOD_XL = (182, 140, 100, 255)

STEEL_D = (86, 84, 96, 255)
STEEL = (140, 138, 150, 255)
STEEL_L = (196, 194, 204, 255)

PAPER_D = (206, 188, 156, 255)
PAPER = (238, 224, 198, 255)
PAPER_L = (250, 240, 218, 255)
PAPER_XD = (176, 158, 130, 255)

SLATE_XD = (26, 23, 34, 255)
SLATE_D = (34, 30, 44, 255)
SLATE = (52, 46, 66, 255)
SLATE_L = (78, 70, 96, 255)

AMBER_D = (176, 112, 30, 255)
AMBER = (232, 160, 48, 255)
AMBER_L = (252, 202, 96, 255)
TEAL_D = (34, 96, 96, 255)
TEAL = (60, 148, 140, 255)
TEAL_L = (104, 194, 176, 255)
RUST_D = (140, 64, 46, 255)
RUST = (186, 92, 62, 255)
INK = (58, 44, 46, 255)
INK_SOFT = (116, 98, 92, 255)

# Legacy names still generated so an older save/scene never loads a hole.
FRAME_D, FRAME, FRAME_L = WOOD_D, WOOD, WOOD_L


def rivet(img, x, y, light=STEEL_L, dark=WOOD_D):
    px(img, x, y, light)
    px(img, x + 1, y + 1, dark)


def bevel(img, x, y, w, h, light, dark):
    """Top-left lit, bottom-right shaded — the whole kit is lit from up-left."""
    hline(img, x, y, w, light)
    vline(img, x, y, h, light)
    hline(img, x, y + h - 1, w, dark)
    vline(img, x + w - 1, y, h, dark)


# ------------------------------------------------------------------ surfaces

def gen_board():
    """24x24 nine-patch, margin 8: the clipboard body.

    Everything decorative lives inside 8px of an edge, so the stretched middle
    stays perfectly flat parchment no matter how wide the overlay gets.
    """
    s = 24
    img = new_img(s, s)
    # wooden back board
    rect(img, 0, 0, s, s, WOOD_D)
    rect(img, 1, 1, s - 2, s - 2, WOOD)
    bevel(img, 1, 1, s - 2, s - 2, WOOD_L, WOOD_D)
    # grain, only in the corner patch so it never tiles into stripes
    for gx, gy in ((2, 4), (3, 5), (4, 4), (s - 5, 3), (s - 4, 4), (3, s - 5)):
        px(img, gx, gy, WOOD_XL)
    # sunk paper well
    rect(img, 4, 4, s - 8, s - 8, WOOD_D)
    rect(img, 5, 5, s - 10, s - 10, PAPER_XD)
    rect(img, 6, 6, s - 12, s - 12, PAPER)
    hline(img, 6, 6, s - 12, PAPER_L)
    vline(img, 6, 6, s - 12, PAPER_L)
    hline(img, 6, s - 7, s - 12, PAPER_D)
    vline(img, s - 7, 6, s - 12, PAPER_D)
    # corner rivets holding the paper down
    for rx, ry in ((2, 2), (s - 4, 2), (2, s - 4), (s - 4, s - 4)):
        rivet(img, rx, ry)
    save(img, "ui_board")


def gen_clip():
    """The steel spring clip that holds the manifest onto the board.

    It straddles the top edge of the board, so the top third is the raised
    thumb plate and the bottom is the jaw biting down on the paper.
    """
    w, h = 46, 15
    img = new_img(w, h)
    # raised thumb plate, narrower than the jaw
    rect(img, 12, 0, w - 24, 4, STEEL_D)
    rect(img, 13, 1, w - 26, 3, STEEL)
    hline(img, 14, 1, w - 28, STEEL_L)
    # jaw body
    rect(img, 1, 3, w - 2, h - 6, STEEL_D)
    rect(img, 2, 4, w - 4, h - 9, STEEL)
    hline(img, 3, 4, w - 6, STEEL_L)
    # the bite line where paper enters
    hline(img, 2, h - 4, w - 4, (52, 50, 62, 255))
    hline(img, 2, h - 3, w - 4, STEEL_D)
    # rivets on each shoulder
    for rx in (5, w - 7):
        px(img, rx, 7, STEEL_L)
        px(img, rx + 1, 8, (52, 50, 62, 255))
    # contact shadow on the paper below
    rect(img, 4, h - 2, w - 8, 1, (0, 0, 0, 70))
    # clipped corners
    for cx, cy in ((1, 3), (w - 2, 3), (12, 0), (w - 13, 0)):
        px(img, cx, cy, (0, 0, 0, 0))
    save(img, "ui_clip")


def gen_paper():
    """12x12 nine-patch, margin 4: the sheet cards are laid out on.

    Deliberately a shade darker than a card so a list of cards reads as
    separate slips of paper rather than one continuous block of cream.
    """
    s = 12
    img = new_img(s, s)
    rect(img, 0, 0, s, s, (166, 148, 122, 255))
    rect(img, 1, 1, s - 2, s - 2, PAPER_D)
    hline(img, 1, 1, s - 2, (188, 170, 142, 255))
    hline(img, 1, s - 2, s - 2, (188, 170, 142, 255))
    save(img, "ui_paper")


def _card(name, field, edge, edge_hi, rail=None):
    """12x12 nine-patch, margin 4: one torn-off manifest row."""
    s = 12
    img = new_img(s, s)
    rect(img, 0, 0, s, s, edge)
    rect(img, 1, 1, s - 2, s - 2, field)
    hline(img, 1, 1, s - 2, edge_hi)
    vline(img, 1, 1, s - 2, edge_hi)
    hline(img, 1, s - 2, s - 2, PAPER_D)
    if rail is not None:
        # a colour-coded spine on the left, like a file label
        vline(img, 0, 1, s - 2, rail[0])
        vline(img, 1, 1, s - 2, rail[1])
    # clipped corners keep it reading as paper, not a web div
    for cx, cy in ((0, 0), (s - 1, 0), (0, s - 1), (s - 1, s - 1)):
        px(img, cx, cy, (0, 0, 0, 0))
    save(img, name)


def gen_cards():
    _card("ui_card", PAPER, PAPER_XD, PAPER_L)
    _card("ui_card_hi", PAPER_L, AMBER_D, PAPER_L, rail=(AMBER_D, AMBER))
    _card("ui_card_off", (200, 190, 176, 255), (162, 152, 142, 255),
          (214, 206, 194, 255))
    _card("ui_card_done", (206, 220, 208, 255), TEAL_D, (228, 240, 230, 255),
          rail=(TEAL_D, TEAL))


def gen_slate():
    """10x10 nine-patch, margin 3: dark readout for numbers and stamps."""
    s = 10
    img = new_img(s, s)
    rect(img, 0, 0, s, s, SLATE_XD)
    rect(img, 1, 1, s - 2, s - 2, SLATE_D)
    hline(img, 1, 1, s - 2, SLATE)
    for cx, cy in ((0, 0), (s - 1, 0), (0, s - 1), (s - 1, s - 1)):
        px(img, cx, cy, (0, 0, 0, 0))
    save(img, "ui_slate")

    lit = new_img(s, s)
    rect(lit, 0, 0, s, s, AMBER_D)
    rect(lit, 1, 1, s - 2, s - 2, SLATE_D)
    hline(lit, 1, 1, s - 2, SLATE)
    for cx, cy in ((0, 0), (s - 1, 0), (0, s - 1), (s - 1, s - 1)):
        px(lit, cx, cy, (0, 0, 0, 0))
    save(lit, "ui_slate_lit")


def gen_well():
    """10x10 nine-patch, margin 3: recessed socket an item sprite sits in."""
    s = 10
    img = new_img(s, s)
    rect(img, 0, 0, s, s, PAPER_D)
    rect(img, 1, 1, s - 2, s - 2, (222, 206, 178, 255))
    # inset shadow: dark on the lit side, highlight opposite
    hline(img, 1, 1, s - 2, PAPER_XD)
    vline(img, 1, 1, s - 2, PAPER_XD)
    hline(img, 1, s - 2, s - 2, PAPER_L)
    vline(img, s - 2, 1, s - 2, PAPER_L)
    save(img, "ui_well")


# ------------------------------------------------------------------- controls

def _button(base, light, dark, name, text_dark=True):
    s = 12
    img = new_img(s, s)
    rect(img, 0, 0, s, s, dark)
    rect(img, 1, 0, s - 2, s - 1, base)
    hline(img, 2, 0, s - 4, light)
    vline(img, 1, 1, s - 3, light)
    hline(img, 1, s - 1, s - 2, dark)
    for cx, cy in ((0, 0), (s - 1, 0), (0, s - 1), (s - 1, s - 1)):
        px(img, cx, cy, (0, 0, 0, 0))
    save(img, name)


def gen_buttons():
    _button(AMBER, AMBER_L, AMBER_D, "ui_btn")
    _button(AMBER_D, AMBER, (128, 78, 20, 255), "ui_btn_down")
    _button(TEAL, TEAL_L, TEAL_D, "ui_btn_alt")
    _button((176, 166, 154, 255), (202, 194, 182, 255), (132, 122, 112, 255),
            "ui_btn_off")
    _button(RUST, (218, 128, 96, 255), RUST_D, "ui_btn_danger")

    # ghost: paper-coloured outline key for secondary actions on the board
    s = 12
    img = new_img(s, s)
    rect(img, 0, 0, s, s, PAPER_XD)
    rect(img, 1, 1, s - 2, s - 2, PAPER)
    hline(img, 1, 1, s - 2, PAPER_L)
    hline(img, 1, s - 2, s - 2, PAPER_D)
    for cx, cy in ((0, 0), (s - 1, 0), (0, s - 1), (s - 1, s - 1)):
        px(img, cx, cy, (0, 0, 0, 0))
    save(img, "ui_btn_ghost")


def gen_tabs():
    """12x12 nine-patch, margin 4: file-folder tabs sitting on the board."""
    s = 12
    # active tab: same parchment as the sheet, so it reads as continuous paper
    on = new_img(s, s)
    rect(on, 0, 0, s, s, PAPER_XD)
    rect(on, 1, 0, s - 2, s - 1, PAPER)
    hline(on, 2, 0, s - 4, PAPER_L)
    vline(on, 1, 1, s - 2, PAPER_L)
    vline(on, s - 2, 1, s - 2, PAPER_D)
    hline(on, 1, s - 1, s - 2, PAPER)          # open bottom: joins the sheet
    for cx in (0, s - 1):
        px(on, cx, 0, (0, 0, 0, 0))
    save(on, "ui_tab_on")

    # inactive tab: pushed back into the shade of the wooden board
    off = new_img(s, s)
    rect(off, 0, 0, s, s, WOOD_D)
    rect(off, 1, 1, s - 2, s - 1, (150, 134, 112, 255))
    hline(off, 2, 1, s - 4, (172, 156, 132, 255))
    hline(off, 1, s - 1, s - 2, WOOD_D)
    for cx in (0, s - 1):
        px(off, cx, 0, (0, 0, 0, 0))
    save(off, "ui_tab_off")


def gen_segments():
    """8x8 nine-patch, margin 3: the x1/x10/x25/MAX segmented control."""
    s = 8
    on = new_img(s, s)
    rect(on, 0, 0, s, s, INK)
    rect(on, 1, 1, s - 2, s - 2, AMBER)
    hline(on, 1, 1, s - 2, AMBER_L)
    hline(on, 1, s - 2, s - 2, AMBER_D)
    save(on, "ui_seg_on")

    off = new_img(s, s)
    rect(off, 0, 0, s, s, PAPER_XD)
    rect(off, 1, 1, s - 2, s - 2, (224, 210, 184, 255))
    hline(off, 1, 1, s - 2, PAPER_L)
    save(off, "ui_seg_off")


def gen_bar():
    """8x8 nine-patch, margin 3: progress trough and fill."""
    bg = new_img(8, 8)
    rect(bg, 0, 0, 8, 8, PAPER_XD)
    rect(bg, 1, 1, 6, 6, (196, 180, 152, 255))
    hline(bg, 1, 1, 6, (172, 156, 130, 255))
    save(bg, "ui_bar_bg")

    fill = new_img(8, 8)
    rect(fill, 0, 0, 8, 8, TEAL_D)
    rect(fill, 1, 1, 6, 6, TEAL)
    hline(fill, 1, 1, 6, TEAL_L)
    save(fill, "ui_bar_fill")


def gen_scroll():
    bg = new_img(6, 6)
    rect(bg, 0, 0, 6, 6, PAPER_D)
    rect(bg, 1, 1, 4, 4, (216, 200, 172, 255))
    save(bg, "ui_scroll_bg")

    grab = new_img(6, 6)
    rect(grab, 0, 0, 6, 6, WOOD_D)
    rect(grab, 1, 1, 4, 4, WOOD_L)
    hline(grab, 1, 1, 4, WOOD_XL)
    save(grab, "ui_scroll_grab")


def gen_scrims():
    """Vertical fades that keep HUD text legible without drawing a box."""
    top = new_img(4, 40)
    for y in range(40):
        k = 1.0 - (y / 39.0)
        a = int(150 * (k ** 1.7))
        rect(top, 0, y, 4, 1, (16, 14, 22, a))
    save(top, "ui_topfade", preview_scale=2)

    dim = new_img(4, 4)
    rect(dim, 0, 0, 4, 4, (12, 10, 18, 190))
    save(dim, "ui_scrim", preview_scale=8)


# ------------------------------------------------------------------ icons

def _icon_base():
    return new_img(12, 12)


def _blit_rows(img, rows, ox, oy, color):
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == "#":
                px(img, x + ox, y + oy, color)


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
    _blit_rows(i, ["....##....", "....##....", ".########.", "..######..",
                   "..######..", ".##....##."], 1, 3, (250, 208, 96, 255))
    icons["star"] = i

    # gear: settings
    i = _icon_base()
    _blit_rows(i, ["..#..#..", ".######.", "#.####.#", "##.##.##",
                   "##.##.##", "#.####.#", ".######.", "..#..#.."], 2, 2,
               (196, 190, 190, 255))
    rect(i, 5, 5, 2, 2, SLATE_D)
    icons["gear"] = i

    # speaker: audio toggle
    i = _icon_base()
    rect(i, 2, 5, 2, 3, (196, 190, 190, 255))
    _blit_rows(i, ["..#", ".##", "###", "###", ".##", "..#"], 4, 3,
               (196, 190, 190, 255))
    for wy, wx in ((4, 8), (5, 9), (6, 9), (7, 8)):
        px(i, wx, wy, TEAL_L)
    icons["sound"] = i

    # clock: idle rate
    i = _icon_base()
    for y in range(12):
        for x in range(12):
            dist = ((x - 5.5) ** 2 + (y - 5.5) ** 2) ** 0.5
            if dist <= 4.6:
                px(i, x, y, (226, 218, 202, 255))
            if 3.6 < dist <= 4.6:
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

    # glove: the click upgrades
    i = _icon_base()
    _blit_rows(i, ["..##.##.", ".#######", "#.######", "#.######",
                   ".#######", ".######.", "..####..", "..####.."], 2, 2,
               (232, 150, 60, 255))
    _blit_rows(i, ["..##.##.", ".......", ".......", "......."], 2, 2,
               (252, 194, 112, 255))
    icons["glove"] = i

    # globe: the terminal-wide upgrades
    i = _icon_base()
    for y in range(12):
        for x in range(12):
            dist = ((x - 5.5) ** 2 + (y - 5.5) ** 2) ** 0.5
            if dist <= 4.7:
                px(i, x, y, (86, 158, 168, 255))
            if 3.7 < dist <= 4.7:
                px(i, x, y, (44, 104, 118, 255))
    hline(i, 2, 5, 8, (176, 220, 214, 255))
    vline(i, 5, 2, 8, (176, 220, 214, 255))
    icons["globe"] = i

    # padlock: not unlocked yet
    i = _icon_base()
    _blit_rows(i, [".####.", "#....#", "#....#"], 3, 1, (150, 140, 132, 255))
    rect(i, 2, 5, 8, 6, (176, 166, 154, 255))
    hline(i, 2, 5, 8, (204, 196, 186, 255))
    rect(i, 5, 7, 2, 3, (96, 88, 84, 255))
    icons["lock"] = i

    # tick: completed
    i = _icon_base()
    _blit_rows(i, ["......##", ".....##.", "##...##.", ".##.##..",
                   "..###...", "...#...."], 2, 3, TEAL_L)
    icons["check"] = i

    # cross: close
    i = _icon_base()
    _blit_rows(i, ["##....##", ".##..##.", "..####..", "...##...",
                   "..####..", ".##..##.", "##....##"], 2, 3, (232, 118, 96, 255))
    icons["close"] = i

    # chevron: drill into a screen
    i = _icon_base()
    _blit_rows(i, ["##...", ".##..", "..##.", "...##", "..##.", ".##..",
                   "##..."], 4, 3, INK_SOFT)
    icons["chevron"] = i

    # truck: the gate traffic / contracts
    i = _icon_base()
    rect(i, 1, 4, 6, 4, (72, 116, 172, 255))
    hline(i, 1, 4, 6, (110, 154, 206, 255))
    rect(i, 7, 5, 3, 3, (196, 190, 190, 255))
    for wx in (2, 8):
        rect(i, wx, 8, 2, 2, (48, 44, 50, 255))
    icons["truck"] = i

    # trophy: career and achievements
    i = _icon_base()
    rect(i, 3, 2, 6, 4, AMBER)
    hline(i, 3, 2, 6, AMBER_L)
    _blit_rows(i, ["####", ".##.", "####"], 4, 6, AMBER_D)
    px(i, 2, 3, AMBER_D)
    px(i, 9, 3, AMBER_D)
    icons["trophy"] = i

    order = ["teu", "crane", "ship", "land", "star", "gear", "sound", "clock",
             "paw", "glove", "globe", "lock", "check", "close", "chevron",
             "truck", "trophy"]
    save(sheet([icons[k] for k in order]), "ui_icons")
    print("    icon order:", ", ".join(order))


if __name__ == "__main__":
    print("ui:")
    gen_board()
    gen_clip()
    gen_paper()
    gen_cards()
    gen_slate()
    gen_well()
    gen_buttons()
    gen_tabs()
    gen_segments()
    gen_bar()
    gen_scroll()
    gen_scrims()
    gen_icons()
