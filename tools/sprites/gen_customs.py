"""The Receita Federal at the terminal: the customs auditor and his X-ray scanner.

Outputs (all nearest-neighbour, shown at integer scale):

- `ui_customs_body`  7 frames of 18x22, the same layout as `ui_guide_body`
                     (idle, bob, step A, step B, jump, talk, stamp) so
                     `TutorialSpotlight` animates both guides with one table.
                     Leôncio, auditor-fiscal - "o Leão": a tawny mane and
                     moustache, round glasses, the navy vest with the yellow
                     band every Receita agent wears on a quay, a clipboard
                     under one arm. Where Alisson is blue and orange, he is
                     navy and gold; where Alisson waves, he lifts his stamp.
- `ui_xray_items`    18 frames of 16x16: cargo silhouettes for the scan. Order is
                     the `XrayScan.ITEMS` table. The board recolours each by
                     the view that shows it (metal blue, organic orange, glass
                     green, RAIO+ violet), reading only the sprite's lightness.
                     Cartoon shapes, nothing graphic.
- `ui_xray_portal`   4 frames of 76x74: the drive-through container scanner
                     side-on, in two layers so the lorry drives through it
                     (back idle, back scanning, front idle, front scanning).
- `ui_xray_truck`    6 frames of 112x44: a cab-over lorry with a 20ft box,
                     side-on, facing east (3 box liveries x 2 wheel phases).
- `xray_station`    4 frames of 42x60: the drive-through lane in the yard,
                     beside gate bay G3 (abandoned, repaired, a lorry under the
                     beam, the same on the lamp's off beat).
- `ui_xray_badge`    2 frames of 24x24: the HUD key, a little scanner monitor;
                     lit, a red beacon and a flagged silhouette on screen.
"""
from PIL import Image

from common import new_img, rect, hline, vline, px, save, sheet
from gen_guide import selout, BW, BH, MOUTH

P_GLASS = [(70, 110, 140, 255), (150, 200, 220, 255)]

# ----------------------------------------------------------------- the officer

# Leôncio: "o Leão" is what Brazil calls the Receita Federal, so its man on
# the quay is one. A tawny mane and a moustache that hides his mouth, round
# glasses, a rolled-sleeve shirt under the navy vest with the yellow band, a
# lanyard badge in green and yellow, a clipboard that never leaves his left
# hand. Nothing about him is a policeman: he is the civil servant who reads
# every line of the manifest, and enjoys it.
SKIN = [(160, 100, 84, 255), (214, 152, 128, 255), (244, 198, 170, 255),
        (255, 224, 202, 255)]
TASH = [(84, 42, 22, 255), (122, 64, 28, 255), (164, 94, 40, 255)]
MANE = [(132, 70, 24, 255), (192, 114, 36, 255), (232, 160, 60, 255),
        (252, 206, 112, 255)]
VEST = [(20, 28, 58, 255), (34, 48, 92, 255), (56, 76, 130, 255)]
BAND = [(196, 150, 20, 255), (250, 210, 60, 255)]
SHIRT = [(150, 178, 208, 255), (206, 224, 240, 255), (244, 248, 252, 255)]
PANTS = [(38, 42, 62, 255), (58, 64, 90, 255)]
SHOES = (72, 40, 26, 255)
FRAME = (40, 30, 38, 255)
LENS = [(150, 196, 222, 255), (232, 246, 252, 255)]
BADGE = [(246, 248, 250, 255), (40, 150, 84, 255)]
BOARD = [(120, 78, 44, 255), (246, 238, 214, 255), (170, 150, 120, 255)]
STAMP = [(150, 30, 34, 255), (214, 58, 52, 255), (120, 80, 50, 255)]


def officer_frame(kind):
    g = new_img(BW, BH)
    S = SKIN
    o = 1 if kind == "bob" else 0
    jump = kind == "jump"
    lift_l = 1 if kind in ("stepA", "jump") else 0
    lift_r = 1 if kind in ("stepB", "jump") else 0
    # legs: pressed trousers, brown office shoes
    rect(g, 6, 16 - lift_l, 2, 3, PANTS[1]); rect(g, 6, 19 - lift_l, 2, 1, SHOES)
    rect(g, 10, 16 - lift_r, 2, 3, PANTS[0]); rect(g, 10, 19 - lift_r, 2, 1, SHOES)
    if kind == "stepA":
        px(g, 5, 19 - lift_l, SHOES)
    if kind == "stepB":
        px(g, 12, 19 - lift_r, SHOES)
    # torso: the shirt shows down the middle of the open vest
    rect(g, 5, 10 + o, 8, 6, VEST[1])
    vline(g, 5, 10 + o, 6, VEST[2]); vline(g, 12, 10 + o, 6, VEST[0])
    rect(g, 8, 10 + o, 2, 6, SHIRT[1]); px(g, 8, 10 + o, SHIRT[2])
    # the yellow RECEITA band, broken by the shirt
    hline(g, 5, 13 + o, 3, BAND[1]); hline(g, 10, 13 + o, 3, BAND[1])
    px(g, 12, 13 + o, BAND[0])
    # lanyard and badge
    px(g, 8, 11 + o, BAND[1]); px(g, 9, 12 + o, BAND[1])
    px(g, 10, 11 + o, BADGE[0]); px(g, 11, 11 + o, BADGE[1])
    hline(g, 5, 15 + o, 8, VEST[0])
    # arms: rolled sleeves, so forearms are skin
    if jump:
        rect(g, 3, 8, 2, 3, SHIRT[1]); rect(g, 3, 6, 2, 2, S[2])
        rect(g, 13, 8, 2, 3, SHIRT[0]); rect(g, 13, 6, 2, 2, S[2])
        # the clipboard goes up with him
        rect(g, 1, 3, 4, 3, BOARD[1]); hline(g, 1, 3, 4, BOARD[0])
        px(g, 2, 5, BOARD[2]); px(g, 3, 5, BOARD[2])
    else:
        # left arm bent across, holding the clipboard against his side
        px(g, 4, 11 + o, SHIRT[1]); px(g, 4, 12 + o, S[2])
        rect(g, 1, 11 + o, 3, 5, BOARD[1]); hline(g, 1, 11 + o, 3, BOARD[0])
        hline(g, 2, 13 + o, 1, BOARD[2]); hline(g, 2, 14 + o, 1, BOARD[2])
        px(g, 3, 13 + o, S[3])
        if kind == "wave":
            # the rubber stamp, raised: a wooden knob over a red pad
            rect(g, 13, 8 + o, 1, 3, SHIRT[0]); px(g, 13, 7 + o, S[2])
            px(g, 14, 4 + o, STAMP[2])
            rect(g, 13, 5 + o, 3, 2, STAMP[1]); hline(g, 13, 6 + o, 3, STAMP[0])
        else:
            px(g, 13, 11 + o, SHIRT[0]); rect(g, 13, 12 + o, 1, 2, S[2])
            # and the stamp, at rest in his fist
            px(g, 13, 14 + o, STAMP[2]); px(g, 13, 15 + o, STAMP[1])
    # the mane first: a ragged gold halo, lit from the upper left
    M = MANE
    rect(g, 5, 2 + o, 8, 2, M[2]); hline(g, 6, 2 + o, 5, M[3])
    rect(g, 4, 3 + o, 10, 7, M[1])
    vline(g, 4, 3 + o, 6, M[2]); vline(g, 13, 4 + o, 6, M[0])
    for (tx, ty, tone) in ((3, 4, M[2]), (3, 6, M[1]), (3, 8, M[1]),
                           (14, 5, M[0]), (14, 7, M[0]), (7, 1, M[3]),
                           (10, 1, M[2]), (5, 10, M[0]), (12, 10, M[0])):
        px(g, tx, ty + o, tone)
    # face: fair, so it reads against the mane
    rect(g, 6, 4 + o, 6, 6, S[2]); hline(g, 6, 4 + o, 5, S[3])
    vline(g, 11, 5 + o, 5, S[1])
    # round glasses: two pale lenses with the eyes looking out of them
    for ex in (6, 10):
        rect(g, ex, 5 + o, 2, 2, LENS[1])
        px(g, ex + 1, 5 + o, LENS[0])
    px(g, 7, 6 + o, FRAME); px(g, 10, 6 + o, FRAME)     # pupils, a little crossed
    px(g, 8, 5 + o, FRAME); px(g, 9, 5 + o, FRAME)      # the bridge
    # the moustache: dark, wider than the face, drooping at both ends
    hline(g, 6, 8 + o, 6, TASH[1]); hline(g, 7, 8 + o, 2, TASH[2])
    px(g, 5, 8 + o, TASH[0]); px(g, 12, 8 + o, TASH[0])
    px(g, 5, 9 + o, TASH[0]); px(g, 12, 9 + o, TASH[0])
    px(g, 6, 9 + o, TASH[1]); px(g, 11, 9 + o, TASH[0])
    if kind in ("talk", "jump", "wave"):
        px(g, 8, 9 + o, MOUTH[0]); px(g, 9, 9 + o, MOUTH[0])
    return selout(g)


def gen_customs_body():
    frames = [officer_frame(k) for k in
              ("idle", "bob", "stepA", "stepB", "jump", "talk", "wave")]
    save(sheet(frames), "ui_customs_body", preview_scale=8)


# ------------------------------------------------------------ x-ray silhouettes

# false colour, as a baggage scanner draws it
XR = {
    "o": (238, 152, 66, 255), "O": (198, 100, 36, 255), "X": (132, 58, 22, 255),
    "m": (78, 128, 216, 255), "M": (34, 58, 134, 255),
    "g": (112, 188, 106, 255), "G": (58, 126, 66, 255),
}

ITEMS = {
    "bear": [
        "................",
        "...oo......oo...",
        "..oooo....oooo..",
        "..oooooooooooo..",
        "...oOooooooOo...",
        "...oooooooooo...",
        "...ooooOOoooo...",
        "....oooooooo....",
        "..oooooooooooo..",
        ".oooooooooooooo.",
        ".oo.oooooooo.oo.",
        "....oooooooo....",
        "....oooooooo....",
        "...ooo....ooo...",
        "...ooo....ooo...",
        "................"],
    "guitar": [
        "............MM..",
        "...........MMm..",
        "..........mm....",
        ".........mm.....",
        "........mm......",
        ".......mm.......",
        "....oommo.......",
        "...ooomooo......",
        "..oooooooo......",
        "...ooo.ooo......",
        "..ooooooooo.....",
        ".ooooooooooo....",
        ".oooooOooooo....",
        "..ooooooooo.....",
        "...ooooooo......",
        "................"],
    "bike": [
        "................",
        "................",
        "................",
        "......MM........",
        "......m....mm...",
        ".....mmmmmmm....",
        "....m.m...m.m...",
        "..mmmm.m.m.mmm..",
        ".m..m.m.m.m.m.m.",
        "m...m..mMm..m..m",
        "m....mm...mm...m",
        "m......m.......m",
        ".m....m.m.....m.",
        "..mmmm...mmmmm..",
        "................",
        "................"],
    "shoe": [
        "................",
        "................",
        "................",
        "................",
        "................",
        "..oooo..........",
        "..oOoo..........",
        "..ooooo.........",
        "..oOooo.........",
        "..oooooo........",
        "..ooooooooo.....",
        "..oooooooooooo..",
        "..ooooooooooooo.",
        "..OOOOOOOOOOOOO.",
        "................",
        "................"],
    "bottle": [
        "................",
        "......GG........",
        "......gg........",
        "......gg........",
        ".....gggg.......",
        "....gggggg......",
        "....gggggg......",
        "....gggggg......",
        "....oooooo......",
        "....oOOOOo......",
        "....oooooo......",
        "....gggggg......",
        "....gggggg......",
        "....gggggg......",
        "....GGGGGG......",
        "................"],
    "tv": [
        "................",
        "...M......M.....",
        "....M....M......",
        ".....M..M.......",
        "......MM........",
        "..mmmmmmmmmmmm..",
        "..mggggggggggm..",
        "..mggggggggggm..",
        "..mggggggggggm..",
        "..mggggggggggm..",
        "..mggggggggggm..",
        "..mmmmmmmmmmmm..",
        "..mmmmmmmmmMmm..",
        "...MM......MM...",
        "................",
        "................"],
    "chair": [
        "................",
        "...oo...........",
        "...oO...........",
        "...oo...........",
        "...oO...........",
        "...oo...........",
        "...oo...........",
        "...oooooooooo...",
        "...oOOOOOOOOo...",
        "...oo......oo...",
        "...oo......oo...",
        "...oo......oo...",
        "...oo......oo...",
        "...OO......OO...",
        "................",
        "................"],
    "laptop": [
        "................",
        "................",
        "................",
        "....MMMMMMMM....",
        "....MggggggM....",
        "....MggggggM....",
        "....MggggggM....",
        "....MggggggM....",
        "....MMMMMMMM....",
        "...mmmmmmmmmm...",
        "..mMmMmMmMmMmm..",
        "..mmmmmmmmmmmm..",
        "..MMMMMMMMMMMM..",
        "................",
        "................",
        "................"],
    "ball": [
        "................",
        "................",
        "......oooo......",
        "....oooooooo....",
        "...ooOOooooOo...",
        "...oOOOoooooo...",
        "..ooOOooooOOoo..",
        "..ooooooooOOOo..",
        "..oooOOooooOoo..",
        "..ooOOOOoooooo..",
        "...ooOOooooOo...",
        "...oooooooOOo...",
        "....oooooooo....",
        "......oooo......",
        "................",
        "................"],
    "umbrella": [
        "................",
        ".......M........",
        ".....oooooo.....",
        "...oooooooooo...",
        "..oooooooooooo..",
        ".oooooooooooooo.",
        ".m.oo.m.mo.oo.m.",
        ".......m........",
        ".......m........",
        ".......m........",
        ".......m........",
        ".......m........",
        ".......m........",
        "....m..m........",
        ".....mm.........",
        "................"],
    "dryer": [
        "................",
        "................",
        "................",
        "....mmmmm.......",
        "...mmmmmmmmmmmg.",
        "...mmMMmmmmmmmg.",
        "...mmMMmmmmmmmg.",
        "...mmmmmmmmmmmg.",
        "....mmmmm.......",
        ".....ggg........",
        ".....ggg........",
        ".....ggg........",
        ".....gggg.......",
        "......G.........",
        ".......G........",
        "................"],
    "drill": [
        "................",
        "................",
        "................",
        "...mmmmmmm......",
        "...mmmmmmmMMMMMM",
        "...mmMmmmm......",
        "....ggg.........",
        "....ggg.........",
        "....gggg........",
        "....gggg........",
        "...GGGGGG.......",
        "...GgggggG......",
        "...GGGGGG.......",
        "................",
        "................",
        "................"],
    # ----- contraband: what the player is hunting for
    "pistol": [
        "................",
        "................",
        "................",
        "................",
        "..MMMMMMMMMMMMM.",
        "..MmmmmmmmmmmMM.",
        "..MMMMMMMMMMMMM.",
        ".........MMMMM..",
        "........M.MMMM..",
        "........MMMMMM..",
        "..........MMMM..",
        "..........MMMM..",
        "..........MMMMM.",
        "...........MMMM.",
        "................",
        "................"],
    "rifle": [
        "................",
        "................",
        "................",
        "................",
        "................",
        "......M.........",
        "MMMMMMMMMMMMM...",
        ".mmmmmMMMMMMMOO.",
        "......MM.MMMOOOO",
        "......M...MOOOOO",
        "......M.....OOOO",
        "............OOO.",
        "................",
        "................",
        "................",
        "................"],
    "bricks": [
        "................",
        "................",
        "..OOOOOO.OOOOOO.",
        "..OXOOXO.OXOOXO.",
        "..OOXXOO.OOXXOO.",
        "..OOXXOO.OOXXOO.",
        "..OXOOXO.OXOOXO.",
        "..OOOOOO.OOOOOO.",
        "................",
        ".OOOOOO.OOOOOO..",
        ".OXOOXO.OXOOXO..",
        ".OOXXOO.OOXXOO..",
        ".OOXXOO.OOXXOO..",
        ".OXOOXO.OXOOXO..",
        ".OOOOOO.OOOOOO..",
        "................"],
    "grenade": [
        "................",
        "................",
        "......MMM.......",
        ".....M..MM......",
        ".....M.MMMM.....",
        "......MMMMM.....",
        ".....mmmmmmm....",
        "....mMmMmMmMm...",
        "....mmmmmmmmm...",
        "....mMmMmMmMm...",
        "....mmmmmmmmm...",
        "....mMmMmMmMm...",
        ".....mmmmmmm....",
        "......mmmmm.....",
        "................",
        "................"],
    # ----- added with the filter views: a decoy for the bricks, and the
    # contraband the Receita seizes most on Brazilian quays after drugs:
    # rapadura is shaped like a taped brick, the macaw is wildlife traffic
    "rapadura": [
        "................",
        "................",
        "................",
        "................",
        ".....OOOOOO.....",
        ".....OoooXO.....",
        ".....OoXooO.....",
        ".....OOOOOO.....",
        "..OOOOOOOOOOOO..",
        "..OooXoOOoooXO..",
        "..OoooooOooXoO..",
        "..OXoooOOoXooO..",
        "..OooXoOOoooXO..",
        "..OOOOOOOOOOOO..",
        "................",
        "................"],
    "macaw": [
        "................",
        ".....OOOO.......",
        "...OOooooO......",
        "..OXOoXooO......",
        "..OO.ooooO......",
        "..O..oooooO.....",
        ".....ooooooO....",
        ".....oooOoooO...",
        "......ooOOooO...",
        "......oooOOoO...",
        ".......ooooOO...",
        "...MMMMMMMMMMM..",
        "........OooO....",
        ".........OoO....",
        "..........OoO...",
        "...........OO..."],
}

# The order is the contract with `XrayScan.ITEMS`: frame index = table index.
ORDER = ["bear", "guitar", "bike", "shoe", "bottle", "tv", "chair", "laptop",
         "ball", "umbrella", "dryer", "drill",
         "pistol", "rifle", "bricks", "grenade", "rapadura", "macaw"]


def xray_item(name):
    rows = ITEMS[name]
    assert len(rows) == 16, name
    g = new_img(16, 16)
    for y, row in enumerate(rows):
        assert len(row) == 16, (name, y, row)
        for x, ch in enumerate(row):
            if ch in XR:
                px(g, x, y, XR[ch])
    return g


def gen_xray_items():
    save(sheet([xray_item(n) for n in ORDER]), "ui_xray_items", preview_scale=6)


# --------------------------------------------------------------- the portal

STEEL = [(54, 60, 74, 255), (92, 100, 118, 255), (140, 150, 168, 255),
         (196, 204, 218, 255)]
HAZ = [(246, 196, 40, 255), (24, 22, 30, 255)]
OUT = (24, 20, 30, 255)
# The scanner's own paint: Receita navy housing, white panels, yellow trim.
HOUSE = [(26, 36, 64, 255), (40, 56, 96, 255), (62, 84, 132, 255),
         (96, 122, 172, 255)]
PANEL = [(170, 178, 190, 255), (214, 220, 228, 255), (244, 246, 250, 255)]
BEAM = (120, 236, 255, 255)
CONCRETE = [(120, 118, 112, 255), (156, 152, 144, 255), (186, 182, 172, 255)]

PT_W, PT_H = 76, 74
# The lane surface is the frame's last row: the board draws the road there.
PT_ROAD = 70


def _trefoil(g, x, y):
    """The radiation sign: a 5x5 yellow plate with the black trefoil."""
    rect(g, x, y, 5, 5, HAZ[0])
    for (dx, dy) in ((2, 2), (1, 1), (3, 1), (2, 3), (1, 3), (3, 3)):
        if (dx, dy) in ((2, 2), (1, 1), (3, 1), (2, 4)):
            px(g, x + dx, y + dy, HAZ[1])
    px(g, x + 2, y + 4, HAZ[1])
    px(g, x + 2, y + 2, HAZ[1])


def portal(layer, scanning):
    """The drive-through container scanner, seen from the kerb.

    The road runs left to right; the gantry spans it, so from the side the
    near leg, the far wall and the beam housing on top are what show. Drawn
    in two layers so the lorry can drive *through* it: `back` (far wall,
    detector column, the shade inside the tunnel) under the lorry, `front`
    (near legs, housing, lead curtains, the lit beam, the traffic light)
    over it."""
    g = new_img(PT_W, PT_H)
    x0, x1 = 8, 64              # the tunnel's extent along the road
    top = 20                    # underside of the housing
    if layer == "back":
        # far wall: a pale panel wall with the detector column in the middle
        rect(g, x0 + 4, top, x1 - x0 - 8, PT_ROAD - top, PANEL[0])
        for x in range(x0 + 4, x1 - 4, 6):
            vline(g, x, top, PT_ROAD - top, PANEL[1])
        rect(g, 33, top, 6, PT_ROAD - top, HOUSE[1])
        for y in range(top + 3, PT_ROAD - 2, 4):
            rect(g, 34, y, 4, 2, BEAM if scanning else HOUSE[2])
        # the tunnel's shade, darker at the top
        for y in range(top, top + 6):
            hline(g, x0 + 4, y, x1 - x0 - 8, (60, 66, 84, 160 - (y - top) * 20))
        return g
    # --- front layer
    # the beam housing on top: navy box, white side panel, yellow trim
    rect(g, x0 - 2, 6, x1 - x0 + 4, top - 6, HOUSE[1])
    hline(g, x0 - 2, 6, x1 - x0 + 4, HOUSE[3])
    hline(g, x0 - 2, top - 1, x1 - x0 + 4, HOUSE[0])
    rect(g, x0 + 2, 9, x1 - x0 - 4, 7, PANEL[1])
    hline(g, x0 + 2, 9, x1 - x0 - 4, PANEL[2])
    hline(g, x0 + 2, 15, x1 - x0 - 4, PANEL[0])
    # a yellow-and-black trim along the underside
    for x in range(x0 - 2, x1 + 2):
        px(g, x, top - 2, HAZ[0] if (x // 3) % 2 == 0 else HAZ[1])
    # the lamp and the bar of warning lights on the roof
    lamp = (255, 70, 56, 255) if scanning else (80, 210, 110, 255)
    rect(g, 33, 2, 6, 4, lamp)
    px(g, 34, 2, (255, 240, 230, 255))
    hline(g, 31, 5, 10, STEEL[0])
    _trefoil(g, x0 + 4, 10)
    _trefoil(g, x1 - 9, 10)
    # near legs, at the tunnel's mouth and its exit, on concrete plinths
    for lx in (x0 - 2, x1 - 3):
        rect(g, lx, top, 5, PT_ROAD - top - 3, HOUSE[1])
        vline(g, lx, top, PT_ROAD - top - 3, HOUSE[2])
        vline(g, lx + 4, top, PT_ROAD - top - 3, HOUSE[0])
        for y in range(top + 4, PT_ROAD - 6, 8):
            hline(g, lx + 1, y, 3, HAZ[0])
        rect(g, lx - 2, PT_ROAD - 3, 9, 3, CONCRETE[1])
        hline(g, lx - 2, PT_ROAD - 3, 9, CONCRETE[2])
    # lead curtains hanging in both mouths: strips the lorry pushes through
    for cx in (x0 + 4, x1 - 7):
        for i in range(3):
            rect(g, cx + i, top, 1, 22 + (i % 2) * 3, (40, 44, 58, 150))
    # the beam: a fan of light down the middle when the lorry is in it
    if scanning:
        for y in range(top, PT_ROAD):
            a = 110 if (y // 2) % 2 == 0 else 70
            hline(g, 34, y, 4, (BEAM[0], BEAM[1], BEAM[2], a))
            px(g, 33, y, (BEAM[0], BEAM[1], BEAM[2], 40))
            px(g, 38, y, (BEAM[0], BEAM[1], BEAM[2], 40))
    # the traffic light past the exit, on its own pole
    tx = PT_W - 6
    vline(g, tx + 2, 24, PT_ROAD - 24, STEEL[1])
    vline(g, tx + 1, 24, PT_ROAD - 24, STEEL[2])
    rect(g, tx, 16, 5, 11, (30, 30, 36, 255))
    red = (255, 70, 56, 255) if scanning else (90, 30, 30, 255)
    green = (60, 60, 50, 255) if scanning else (90, 230, 120, 255)
    rect(g, tx + 1, 17, 3, 3, red)
    rect(g, tx + 1, 22, 3, 3, green)
    return selout(g, OUT)


def gen_xray_portal():
    frames = [portal("back", False), portal("back", True),
              portal("front", False), portal("front", True)]
    save(sheet(frames), "ui_xray_portal", preview_scale=5)


# ------------------------------------------------------ the lorry, side-on

# `ui_xray_truck`, frames of TR_W x TR_H: a Brazilian cab-over tractor with a
# 20ft box on a skeletal trailer, facing right (east), as the drive-through
# sees it. Three box liveries x two wheel phases: frame = livery * 2 + phase.
TR_W, TR_H = 112, 44
CAB = [(150, 30, 34, 255), (196, 52, 48, 255), (232, 96, 80, 255)]
CAB_WHITE = [(176, 180, 188, 255), (222, 226, 232, 255), (248, 250, 252, 255)]
TYRE = [(26, 24, 30, 255), (52, 50, 58, 255)]
BOXES = [
    [(110, 46, 32, 255), (150, 66, 44, 255), (186, 92, 62, 255), (214, 130, 96, 255)],
    [(32, 60, 104, 255), (48, 86, 140, 255), (72, 116, 172, 255), (120, 160, 210, 255)],
    [(40, 86, 50, 255), (62, 116, 66, 255), (92, 148, 88, 255), (140, 190, 130, 255)],
]


def _wheel(g, cx, cy, phase):
    r = 5
    for y in range(-r, r + 1):
        for x in range(-r, r + 1):
            d = x * x + y * y
            if d <= r * r:
                px(g, cx + x, cy + y, TYRE[0] if d > 9 else STEEL[1])
    px(g, cx, cy, STEEL[3])
    spokes = ((0, -2), (0, 2), (-2, 0), (2, 0)) if phase == 0 else \
        ((-1, -1), (1, 1), (-1, 1), (1, -1))
    for (dx, dy) in spokes:
        px(g, cx + dx, cy + dy, STEEL[0])
    px(g, cx - 3, cy - 3, TYRE[1])


def truck_side(livery, phase):
    g = new_img(TR_W, TR_H)
    box = BOXES[livery]
    road = TR_H - 1
    axle = road - 5
    # --- the trailer: a skeletal chassis under the box
    rect(g, 2, axle - 7, 78, 3, STEEL[0])
    hline(g, 2, axle - 7, 78, STEEL[1])
    rect(g, 70, axle - 4, 2, 4, STEEL[1])          # landing leg
    # --- the box: a twenty-footer, doors at the back (left)
    bx0, by0, bw, bh = 4, 7, 72, 25
    rect(g, bx0, by0, bw, bh, box[2])
    for x in range(bx0 + 2, bx0 + bw - 2, 3):
        vline(g, x, by0 + 2, bh - 4, box[3])
        vline(g, x + 1, by0 + 2, bh - 4, box[1])
    hline(g, bx0, by0, bw, box[3])
    hline(g, bx0, by0 + 1, bw, box[2])
    hline(g, bx0, by0 + bh - 1, bw, box[0])
    hline(g, bx0, by0 + bh - 2, bw, box[1])
    for cx in (bx0, bx0 + bw - 3):
        for cy in (by0, by0 + bh - 3):
            rect(g, cx, cy, 3, 3, STEEL[1])
            px(g, cx + 1, cy + 1, STEEL[0])
    # door end: two locking bars and the CSC plate
    for lx in (bx0 + 4, bx0 + 8):
        vline(g, lx, by0 + 3, bh - 6, STEEL[2])
    rect(g, bx0 + 12, by0 + bh - 9, 5, 3, PANEL[2])
    # the operator's mark, stencilled
    for i, x in enumerate(range(bx0 + 30, bx0 + 52, 2)):
        px(g, x, by0 + 6, PANEL[2] if i % 4 != 3 else box[2])
        px(g, x, by0 + 7, PANEL[1] if i % 4 != 3 else box[2])
    # trailer wheels: a tandem at the back, mudflaps
    _wheel(g, 16, axle, phase)
    _wheel(g, 28, axle, phase)
    rect(g, 34, axle - 3, 2, 6, TYRE[0])
    # --- the tractor: a cab-over, red and white, facing right
    rect(g, 74, axle - 6, 34, 3, STEEL[0])        # its own frame
    _wheel(g, 86, axle, phase)
    _wheel(g, 102, axle, phase)
    # fuel tank and step
    rect(g, 88, axle - 9, 9, 4, STEEL[2])
    hline(g, 88, axle - 9, 9, STEEL[3])
    hline(g, 88, axle - 6, 9, STEEL[1])
    # the exhaust stack behind the cab
    rect(g, 80, 8, 2, axle - 14, STEEL[2])
    px(g, 80, 8, STEEL[3])
    # cab body: white top, red skirt, a sleeper box behind the doors
    cx0, cy0, cw, ch = 83, 9, 24, axle - 18
    rect(g, cx0, cy0, cw, ch, CAB_WHITE[1])
    hline(g, cx0, cy0, cw, CAB_WHITE[2])
    vline(g, cx0, cy0, ch, CAB_WHITE[0])
    rect(g, cx0, cy0 + ch - 8, cw, 8, CAB[1])
    hline(g, cx0, cy0 + ch - 8, cw, CAB[2])
    hline(g, cx0, cy0 + ch - 1, cw, CAB[0])
    # front face: the windscreen leaning back, the grille, the headlamp
    rect(g, cx0 + cw - 1, cy0 + 1, 2, ch - 1, CAB_WHITE[0])
    rect(g, cx0 + 13, cy0 + 3, 9, 8, P_GLASS[1])
    hline(g, cx0 + 13, cy0 + 3, 9, P_GLASS[0])
    px(g, cx0 + 20, cy0 + 4, (240, 252, 255, 255))
    px(g, cx0 + 19, cy0 + 5, (240, 252, 255, 255))
    # the door with its window, handle and mirror arm
    rect(g, cx0 + 4, cy0 + 3, 7, 6, P_GLASS[1])
    hline(g, cx0 + 4, cy0 + 3, 7, P_GLASS[0])
    vline(g, cx0 + 3, cy0 + 2, ch - 3, CAB_WHITE[0])
    vline(g, cx0 + 12, cy0 + 2, ch - 3, CAB_WHITE[0])
    px(g, cx0 + 10, cy0 + 11, STEEL[0])
    rect(g, cx0 + cw + 1, cy0 + 2, 2, 5, STEEL[1])
    rect(g, cx0 + cw - 1, cy0 + ch - 4, 3, 2, (252, 230, 150, 255))   # headlamp
    rect(g, cx0 + cw - 2, cy0 + ch - 1, 5, 3, STEEL[1])               # bumper
    # roof: sun visor and the amber light bar
    hline(g, cx0 + 12, cy0 - 1, 12, CAB_WHITE[0])
    for x in (cx0 + 14, cx0 + 17, cx0 + 20):
        px(g, x, cy0 - 2, (255, 170, 60, 255))
    return selout(g, OUT)


def gen_xray_truck():
    frames = [truck_side(livery, phase) for livery in range(3) for phase in range(2)]
    save(sheet(frames), "ui_xray_truck", preview_scale=4)


# ---------------------------------------------------------------- HUD badge

def badge(lit):
    g = new_img(24, 24)
    # a squat monitor on a stand
    rect(g, 2, 4, 20, 15, STEEL[0])
    rect(g, 3, 5, 18, 13, STEEL[1])
    hline(g, 3, 5, 18, STEEL[2])
    rect(g, 5, 7, 14, 9, (226, 232, 220, 255))
    # a box on the belt, and what is inside it
    rect(g, 6, 9, 12, 6, (190, 196, 186, 255))
    hline(g, 6, 9, 12, (150, 156, 150, 255))
    if lit:
        for (x, y) in ((8, 11), (9, 11), (10, 11), (11, 11), (12, 11), (11, 12),
                       (12, 12), (12, 13)):
            px(g, x, y, XR["M"])
        rect(g, 14, 11, 3, 3, XR["o"])
        # the flag box round the find
        for x in range(7, 14):
            px(g, x, 10, (220, 50, 46, 255)); px(g, x, 14, (220, 50, 46, 255))
        vline(g, 7, 10, 5, (220, 50, 46, 255)); vline(g, 13, 10, 5, (220, 50, 46, 255))
    else:
        rect(g, 8, 11, 3, 3, XR["o"])
        rect(g, 12, 11, 4, 2, XR["m"])
        rect(g, 12, 13, 2, 1, XR["g"])
    rect(g, 10, 19, 4, 2, STEEL[0])
    rect(g, 7, 21, 10, 1, STEEL[1])
    # the beacon
    beacon = (236, 60, 52, 255) if lit else (90, 96, 110, 255)
    rect(g, 10, 1, 4, 3, beacon)
    if lit:
        px(g, 11, 1, (255, 220, 210, 255))
    return selout(g, OUT)


def gen_xray_badge():
    save(sheet([badge(False), badge(True)]), "ui_xray_badge", preview_scale=8)


# ------------------------------------------------------ the post on the quay

# `xray_station`, 4 frames of ST_W x ST_H, in the yard's top-down view: the
# Receita's drive-through scanner beside gate bay G3. A short concrete lane runs
# south to north under a gantry; the source tower stands on its east side with
# the operator's booth below it, and a barrier closes the exit.
#   0  abandoned: the lane cracked and weedy, the gantry rusted and missing
#      panels, cones across the mouth, the barrier snapped, every light dead
#   1  repaired and waiting: clean lane, green light, barrier up, no lorry
#   2  an inspection is due: a lorry stopped under the beam, red light, the
#      beam lit across the box
#   3  the same on the lamp's off beat
# Repairing it is the purchase, so frame 0 has to read as "this could work":
# the same shape, gone to seed.
ST_W, ST_H = 42, 60
ROOF = [(26, 36, 64, 255), (40, 56, 96, 255), (62, 84, 132, 255),
        (96, 122, 172, 255)]
SIGN = [(28, 40, 70, 255), (246, 204, 52, 255)]
GLASS = [(70, 110, 140, 255), (150, 200, 220, 255), (252, 230, 150, 255)]
RUST = [(104, 56, 32, 255), (140, 80, 44, 255), (176, 110, 60, 255)]
WEED = [(60, 104, 52, 255), (92, 140, 70, 255)]
PAD = [(138, 136, 130, 255), (164, 160, 152, 255), (190, 186, 176, 255)]
PAD_OLD = [(112, 106, 96, 255), (132, 126, 114, 255), (150, 144, 130, 255)]
LANE_X0, LANE_W = 3, 24          # the lane, west to east
BEAM_Y = 24                       # the gantry's beam, north edge


def _top_truck(g, x, y, livery):
    """A lorry from above, facing north: cab-over tractor, a 20ft box."""
    box = BOXES[livery]
    # tyres peeking out under the body
    for ty in (y + 4, y + 22, y + 34):
        rect(g, x - 1, ty, 2, 5, TYRE[0])
        rect(g, x + 16, ty, 2, 5, TYRE[0])
    # the cab: white roof with a red nose and a windscreen
    rect(g, x + 1, y, 15, 12, CAB_WHITE[1])
    hline(g, x + 1, y, 15, CAB[1])
    hline(g, x + 1, y + 1, 15, CAB[2])
    rect(g, x + 2, y + 2, 13, 3, P_GLASS[1])
    hline(g, x + 2, y + 2, 13, P_GLASS[0])
    px(g, x + 12, y + 3, (240, 252, 255, 255))
    vline(g, x + 1, y, 12, CAB_WHITE[0])
    vline(g, x + 15, y, 12, CAB_WHITE[0])
    hline(g, x + 3, y + 7, 11, CAB_WHITE[2])
    for bx in (x + 5, x + 8, x + 11):
        px(g, bx, y + 6, (255, 170, 60, 255))
    px(g, x, y + 3, STEEL[1]); px(g, x + 16, y + 3, STEEL[1])     # mirrors
    # the box: corrugated roof across, corner castings
    rect(g, x, y + 13, 17, 30, box[2])
    for yy in range(y + 15, y + 41, 3):
        hline(g, x + 1, yy, 15, box[3])
        hline(g, x + 1, yy + 1, 15, box[1])
    hline(g, x, y + 13, 17, box[3])
    vline(g, x + 16, y + 13, 30, box[0])
    hline(g, x, y + 42, 17, box[0])
    for (cx, cy) in ((x, y + 13), (x + 15, y + 13), (x, y + 41), (x + 15, y + 41)):
        rect(g, cx, cy, 2, 2, STEEL[1])


def station(state):
    g = new_img(ST_W, ST_H)
    broken = state == 0
    pad = PAD_OLD if broken else PAD
    # --- the lane: a concrete slab with kerbs and paint
    rect(g, LANE_X0, 0, LANE_W, ST_H, pad[1])
    vline(g, LANE_X0, 0, ST_H, pad[0])
    vline(g, LANE_X0 + LANE_W - 1, 0, ST_H, pad[0])
    for y in range(0, ST_H, 6):
        hline(g, LANE_X0 + 1, y, LANE_W - 2, pad[2] if not broken else pad[0])
    paint = (236, 196, 60, 255) if not broken else (150, 130, 80, 255)
    for y in range(1, ST_H - 1):
        if not broken or (y // 3) % 3:
            px(g, LANE_X0 + 2, y, paint)
            px(g, LANE_X0 + LANE_W - 3, y, paint)
    # the stop line under the beam and the chevrons on the approach
    hline(g, LANE_X0 + 3, BEAM_Y + 12, LANE_W - 6,
          (244, 244, 240, 255) if not broken else pad[2])
    if not broken:
        for i, cy in enumerate((ST_H - 10, ST_H - 5)):
            for k in range(5):
                px(g, LANE_X0 + 8 + k, cy - k // 2, (244, 244, 240, 255))
                px(g, LANE_X0 + 15 - k, cy - k // 2, (244, 244, 240, 255))
    else:
        # cracks, a pothole, weeds pushing through
        for (x, y) in ((6, 8), (7, 9), (8, 9), (9, 10), (18, 40), (19, 41),
                       (19, 42), (20, 43), (12, 50), (13, 51)):
            px(g, x, y, pad[0])
        rect(g, 14, 30, 4, 3, (82, 76, 70, 255))
        for (x, y, h) in ((5, 20, 2), (24, 14, 3), (10, 46, 2), (22, 54, 3),
                          (16, 3, 2)):
            vline(g, x, y, h, WEED[0])
            px(g, x, y, WEED[1])
    # --- the lorry, under the beam, when an inspection is due
    if state >= 2:
        _top_truck(g, LANE_X0 + 3, 9, 1)
    # --- the gantry: two footings and a beam across the lane
    metal = RUST if broken else ROOF
    for fx in (LANE_X0 - 3, LANE_X0 + LANE_W - 1):
        rect(g, fx, BEAM_Y - 1, 4, 10, metal[1])
        hline(g, fx, BEAM_Y - 1, 4, metal[3] if not broken else metal[2])
        vline(g, fx + 3, BEAM_Y - 1, 10, metal[0])
    rect(g, LANE_X0 - 3, BEAM_Y, LANE_W + 6, 7, metal[1])
    hline(g, LANE_X0 - 3, BEAM_Y, LANE_W + 6, metal[3] if not broken else metal[2])
    hline(g, LANE_X0 - 3, BEAM_Y + 6, LANE_W + 6, metal[0])
    # the beam's underside trim, and the detector windows along it
    for x in range(LANE_X0 - 3, LANE_X0 + LANE_W + 3):
        if broken and 14 <= x <= 20:
            continue          # a panel missing: the frame shows through
        px(g, x, BEAM_Y + 5, HAZ[0] if (x // 2) % 2 == 0 else HAZ[1])
    for x in range(LANE_X0 + 2, LANE_X0 + LANE_W - 2, 4):
        lit = state >= 2 and (x // 4 + state) % 2 == 0
        rect(g, x, BEAM_Y + 2, 2, 2, BEAM if lit else (metal[0] if broken else ROOF[2]))
    if broken:
        rect(g, 14, BEAM_Y + 1, 7, 4, RUST[0])
        hline(g, 15, BEAM_Y + 3, 5, STEEL[0])
    elif state >= 2:
        # the beam's light falling across the box
        for x in range(LANE_X0 + 1, LANE_X0 + LANE_W - 1):
            px(g, x, BEAM_Y + 7, (BEAM[0], BEAM[1], BEAM[2], 170))
            px(g, x, BEAM_Y + 8, (BEAM[0], BEAM[1], BEAM[2], 80))
    # --- the source tower, east of the lane, with the radiation sign
    tx, ty = LANE_X0 + LANE_W + 1, BEAM_Y - 8
    rect(g, tx, ty, 11, 18, metal[1])
    hline(g, tx, ty, 11, metal[3] if not broken else metal[2])
    vline(g, tx, ty, 18, metal[2])
    vline(g, tx + 10, ty, 18, metal[0])
    hline(g, tx, ty + 17, 11, metal[0])
    rect(g, tx + 2, ty + 3, 7, 5, (228, 232, 238, 255) if not broken else (150, 146, 136, 255))
    _trefoil(g, tx + 3, ty + 3)
    if broken:
        px(g, tx + 4, ty + 4, RUST[1]); px(g, tx + 7, ty + 6, RUST[1])
    # the lamp on the tower
    lamp = {0: (70, 70, 80, 255), 1: (80, 210, 110, 255),
            2: (255, 70, 56, 255), 3: (150, 40, 40, 255)}[state]
    rect(g, tx + 4, ty - 3, 3, 3, lamp)
    if state in (1, 2):
        px(g, tx + 4, ty - 3, (255, 240, 230, 255))
    # --- the operator's booth, south of the tower
    by = ty + 21
    rect(g, tx, by, 11, 9, ROOF[1] if not broken else (78, 74, 70, 255))
    hline(g, tx, by, 11, ROOF[3] if not broken else (100, 96, 90, 255))
    vline(g, tx + 10, by, 9, ROOF[0])
    rect(g, tx, by + 9, 11, 7, (222, 216, 200, 255) if not broken else (170, 160, 140, 255))
    hline(g, tx, by + 9, 11, (176, 170, 156, 255))
    rect(g, tx + 1, by + 10, 9, 2, SIGN[0])
    for x in range(tx + 2, tx + 9, 2):
        px(g, x, by + 10, SIGN[1] if not broken or x % 4 else SIGN[0])
    if broken:
        rect(g, tx + 2, by + 13, 6, 3, (110, 74, 44, 255))
        px(g, tx + 3, by + 14, (150, 106, 64, 255))
        px(g, tx + 6, by + 13, (150, 106, 64, 255))
    else:
        rect(g, tx + 2, by + 13, 4, 2, GLASS[2] if state else GLASS[1])
        if state >= 2:
            rect(g, tx + 2, by + 13, 4, 2, (255, 150, 120, 255))
        rect(g, tx + 7, by + 12, 2, 4, STEEL[1])
    # --- the exit barrier across the north end
    if broken:
        # snapped: a stub on the post, the arm lying on the slab
        rect(g, LANE_X0 + LANE_W - 1, 2, 3, 3, STEEL[1])
        for i in range(10):
            px(g, LANE_X0 + 6 + i, 6 + i // 4,
               (220, 60, 50, 255) if (i // 2) % 2 == 0 else (240, 236, 230, 255))
        # cones across the mouth
        for cx in (LANE_X0 + 4, LANE_X0 + 11, LANE_X0 + 18):
            rect(g, cx, ST_H - 6, 3, 3, (236, 120, 40, 255))
            px(g, cx + 1, ST_H - 7, (250, 200, 120, 255))
            hline(g, cx, ST_H - 5, 3, (244, 240, 230, 255))
    else:
        rect(g, LANE_X0 + LANE_W - 1, 1, 3, 3, STEEL[1])
        if state >= 2:
            # down: the lorry waits for the scan
            for i in range(LANE_W - 2):
                px(g, LANE_X0 + 1 + i, 2,
                   (220, 60, 50, 255) if (i // 3) % 2 == 0 else (240, 236, 230, 255))
        else:
            # up: the arm stands along the kerb
            for i in range(8):
                px(g, LANE_X0 + LANE_W, 4 + i,
                   (220, 60, 50, 255) if (i // 2) % 2 == 0 else (240, 236, 230, 255))
    return selout(g, OUT)


def gen_xray_station():
    save(sheet([station(i) for i in range(4)]), "xray_station", preview_scale=6)


if __name__ == "__main__":
    gen_customs_body()
    gen_xray_items()
    gen_xray_portal()
    gen_xray_truck()
    gen_xray_badge()
    gen_xray_station()
