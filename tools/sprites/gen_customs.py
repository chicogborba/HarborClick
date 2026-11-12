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
- `ui_xray_items`    16 frames of 16x16: cargo as an X-ray scanner shows it,
                     in false colour (orange organic, blue metal, green
                     glass/plastic). Order is the `XrayScan.ITEMS` table:
                     twelve ordinary goods, then four contraband silhouettes.
                     Cartoon shapes, nothing graphic.
- `ui_xray_portal`   2 frames of 44x36: the drive-through scanner portal
                     (idle lamp green, scanning lamp red with the beam lit).
- `xray_station`    4 frames of 34x46: the inspection post in the world, beside
                     gate bay G3 (abandoned, repaired, due, due off-beat).
- `ui_xray_badge`    2 frames of 24x24: the HUD key, a little scanner monitor;
                     lit, a red beacon and a flagged silhouette on screen.
"""
from PIL import Image

from common import new_img, rect, hline, vline, px, save, sheet
from gen_guide import selout, BW, BH, MOUTH

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
}

# The order is the contract with `XrayScan.ITEMS`: frame index = table index.
ORDER = ["bear", "guitar", "bike", "shoe", "bottle", "tv", "chair", "laptop",
         "ball", "umbrella", "dryer", "drill",
         "pistol", "rifle", "bricks", "grenade"]


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
CURTAIN = (40, 44, 58, 150)
OUT = (24, 20, 30, 255)


def portal(scanning):
    g = new_img(44, 36)
    # pillars
    for x0 in (2, 35):
        rect(g, x0, 8, 7, 26, STEEL[1])
        vline(g, x0, 8, 26, STEEL[2])
        vline(g, x0 + 6, 8, 26, STEEL[0])
        # the emitter windows down each pillar
        for y in range(12, 31, 4):
            rect(g, x0 + 2, y, 3, 2, (120, 230, 250, 255) if scanning
                 else (40, 70, 90, 255))
        rect(g, x0 - 1, 33, 9, 2, STEEL[0])
    # the top beam with hazard stripes
    rect(g, 1, 3, 42, 6, HAZ[1])
    for x in range(1, 43):
        for y in range(4, 8):
            if ((x + y) // 3) % 2 == 0:
                px(g, x, y, HAZ[0])
    hline(g, 1, 3, 42, STEEL[3])
    hline(g, 1, 8, 42, STEEL[0])
    # a lamp on top
    lamp = (232, 60, 52, 255) if scanning else (80, 210, 110, 255)
    rect(g, 19, 0, 6, 3, lamp)
    px(g, 20, 0, (255, 230, 220, 255) if scanning else (210, 255, 220, 255))
    hline(g, 18, 2, 8, STEEL[0])
    # lead curtain strips across the opening (translucent: the box shows through)
    for x in range(9, 35, 3):
        rect(g, x, 9, 2, 22, CURTAIN)
    if scanning:
        for y in (14, 20, 26):
            hline(g, 9, y, 26, (120, 230, 250, 110))
    out = g.copy()
    # outline only the opaque frame, not the curtains
    src = g.load()
    w, h = g.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] == 255:
                    out.putpixel((x, y), OUT)
                    break
    return out


def gen_xray_portal():
    save(sheet([portal(False), portal(True)]), "ui_xray_portal", preview_scale=6)


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

# `xray_station`, 4 frames of 34x46: the Receita's inspection post beside gate
# bay G3, in the yard's 3/4 view (roof from above, south wall showing).
#   0  abandoned: the roof patched and holed, the window and door boarded up,
#      rust running down the wall, weeds at the plinth, the lamp dead
#   1  repaired and waiting: clean, lit window, green lamp
#   2  an inspection is due: red lamp, bright
#   3  the same, the lamp's off beat
# The gantry on the roof is the scanner itself; the post is somewhere a person
# sits under it. Repairing it is the purchase, so the abandoned frame has to
# read as "this could work" at a glance — a shape you recognise, gone to seed.
ST_W, ST_H = 34, 46
ROOF = [(40, 52, 74, 255), (58, 74, 102, 255), (82, 100, 132, 255),
        (112, 132, 164, 255)]
WALL = [(170, 160, 140, 255), (206, 198, 178, 255), (230, 224, 206, 255)]
SIGN = [(28, 40, 70, 255), (246, 204, 52, 255)]
GLASS = [(70, 110, 140, 255), (150, 200, 220, 255), (252, 230, 150, 255)]
RUST = [(120, 66, 36, 255), (156, 90, 46, 255)]
PLANK = [(110, 74, 44, 255), (150, 106, 64, 255)]
WEED = [(60, 104, 52, 255), (92, 140, 70, 255)]


def station(state):
    g = new_img(ST_W, ST_H)
    broken = state == 0
    # --- the roof: a flat slab seen from above, lit north-west
    rx0, ry0, rw, rh = 2, 10, 30, 16
    rect(g, rx0, ry0, rw, rh, ROOF[1])
    hline(g, rx0, ry0, rw, ROOF[3])
    vline(g, rx0, ry0, rh, ROOF[2])
    vline(g, rx0 + rw - 1, ry0, rh, ROOF[0])
    hline(g, rx0, ry0 + rh - 1, rw, ROOF[0])
    # the roof unit and its vent
    rect(g, 22, 13, 7, 5, STEEL[2] if not broken else STEEL[1])
    hline(g, 22, 13, 7, STEEL[3])
    px(g, 25, 15, STEEL[0])
    if broken:
        # holes, a tarp patch and a water stain
        rect(g, 6, 18, 4, 3, OUT)
        px(g, 7, 18, ROOF[0])
        rect(g, 13, 20, 6, 4, (120, 96, 60, 255))
        hline(g, 13, 20, 6, (150, 122, 78, 255))
        for (x, y) in ((4, 13), (5, 14), (18, 12), (27, 22), (28, 23)):
            px(g, x, y, ROOF[0])
    # --- the scanner gantry across the roof: two legs, a taped beam
    for lx in (3, 28):
        rect(g, lx, 4, 3, 10, STEEL[1])
        vline(g, lx, 4, 10, STEEL[2])
    rect(g, 2, 2, 30, 4, HAZ[0])
    for x in range(2, 32):
        for y in range(3, 5):
            if ((x + y) // 2) % 2 == 0:
                px(g, x, y, HAZ[1])
    hline(g, 2, 2, 30, (255, 236, 150, 255) if not broken else (200, 170, 70, 255))
    if broken:
        # tape faded, one end of the beam sagging
        for x in range(22, 32):
            if x % 3 == 0:
                px(g, x, 4, STEEL[1])
        px(g, 31, 5, HAZ[0])
    # the lamp on the beam
    lamp = {0: (70, 70, 80, 255), 1: (80, 210, 110, 255),
            2: (255, 70, 56, 255), 3: (150, 40, 40, 255)}[state]
    rect(g, 15, 0, 4, 3, lamp)
    if state in (1, 2):
        px(g, 16, 0, (255, 240, 230, 255))
    # --- the south wall under the eave
    wy0 = ry0 + rh
    rect(g, rx0, wy0, rw, 15, WALL[1])
    hline(g, rx0, wy0, rw, WALL[0])                # eave shadow
    hline(g, rx0, wy0 + 14, rw, WALL[0])           # plinth
    vline(g, rx0 + rw - 1, wy0, 15, WALL[0])
    # the sign band: RECEITA in gold on navy, as a 1px pattern
    rect(g, 5, wy0 + 2, 24, 4, SIGN[0])
    for x in range(7, 27, 2):
        px(g, x, wy0 + 3, SIGN[1] if not broken or x % 4 else SIGN[0])
        px(g, x, wy0 + 4, SIGN[1] if not broken or x % 6 else SIGN[0])
    # window and door
    wx, wy = 6, wy0 + 7
    dx = 22
    if broken:
        rect(g, wx, wy, 8, 5, PLANK[0])
        for i in range(8):
            px(g, wx + i, wy + i * 5 // 8, PLANK[1])
            px(g, wx + 7 - i, wy + i * 5 // 8, PLANK[1])
        rect(g, dx, wy - 1, 6, 8, PLANK[0])
        hline(g, dx, wy + 1, 6, PLANK[1])
        hline(g, dx, wy + 4, 6, PLANK[1])
        # rust bleeding down from the eave and the sign
        for (x, y0, n) in ((4, wy0 + 1, 6), (12, wy0 + 6, 5), (29, wy0 + 1, 9),
                           (17, wy0 + 6, 3)):
            vline(g, x, y0, n, RUST[0])
            px(g, x, y0, RUST[1])
        # weeds at the plinth
        for (x, h) in ((3, 3), (5, 2), (14, 2), (19, 3), (30, 2)):
            vline(g, x, wy0 + 15 - h, h, WEED[0])
            px(g, x, wy0 + 15 - h, WEED[1])
    else:
        rect(g, wx, wy, 8, 5, GLASS[0])
        rect(g, wx + 1, wy + 1, 6, 3, GLASS[2] if state else GLASS[1])
        if state >= 2:
            rect(g, wx + 1, wy + 1, 6, 3, (255, 150, 120, 255))
        px(g, wx + 6, wy + 1, (255, 255, 255, 255))
        rect(g, dx, wy - 1, 6, 8, STEEL[1])
        vline(g, dx, wy - 1, 8, STEEL[2])
        px(g, dx + 4, wy + 3, SIGN[1])
        # a striped kerb where a lorry pulls up
        for x in range(2, 32, 2):
            px(g, x, wy0 + 15, HAZ[0] if (x // 2) % 2 == 0 else HAZ[1])
    return selout(g, OUT)


def gen_xray_station():
    save(sheet([station(i) for i in range(4)]), "xray_station", preview_scale=6)


if __name__ == "__main__":
    gen_customs_body()
    gen_xray_items()
    gen_xray_portal()
    gen_xray_badge()
    gen_xray_station()
