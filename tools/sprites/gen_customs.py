"""The Receita Federal at the terminal: the customs officer and her X-ray scanner.

Outputs (all nearest-neighbour, shown at integer scale):

- `ui_customs_body`  7 frames of 18x22, the same layout as `ui_guide_body`
                     (idle, bob, step A, step B, jump, talk, stamp) so
                     `TutorialSpotlight` animates both guides with one table.
                     Neide, auditora fiscal: the black tactical vest with the
                     yellow band every Receita agent wears on a quay, a black
                     cap with a gold badge, and the sunglasses she never takes
                     off. Where Alisson is blue and orange, she is black and
                     yellow; where he waves, she lifts her red rubber stamp.
- `ui_xray_items`    16 frames of 16x16: cargo as an X-ray scanner shows it,
                     in false colour (orange organic, blue metal, green
                     glass/plastic). Order is the `XrayScan.ITEMS` table:
                     twelve ordinary goods, then four contraband silhouettes.
                     Cartoon shapes, nothing graphic.
- `ui_xray_portal`   2 frames of 44x36: the drive-through scanner portal
                     (idle lamp green, scanning lamp red with the beam lit).
- `ui_xray_badge`    2 frames of 24x24: the HUD key, a little scanner monitor;
                     lit, a red beacon and a flagged silhouette on screen.
"""
from PIL import Image

from common import new_img, rect, hline, vline, px, save, sheet
from gen_guide import selout, BW, BH, MOUTH, BLUSH, EYE_DARK

# ----------------------------------------------------------------- the officer

SKIN = [(92, 52, 36, 255), (128, 78, 52, 255), (160, 104, 70, 255),
        (190, 132, 92, 255)]
HAIR = (30, 20, 22, 255)
VEST = [(16, 16, 22, 255), (30, 30, 38, 255), (48, 48, 60, 255)]
BAND = [(196, 150, 20, 255), (246, 204, 52, 255)]
PANTS = (34, 38, 56, 255)
SHOES = (14, 14, 18, 255)
CAP = [(14, 14, 20, 255), (36, 36, 48, 255)]
GOLD = (246, 204, 52, 255)
SHADES = [(10, 10, 16, 255), (70, 90, 130, 255)]
STAMP = [(150, 30, 34, 255), (214, 58, 52, 255), (120, 80, 50, 255)]


def officer_frame(kind):
    g = new_img(BW, BH)
    S = SKIN
    o = 1 if kind == "bob" else 0
    jump = kind == "jump"
    lift_l = 1 if kind in ("stepA", "jump") else 0
    lift_r = 1 if kind in ("stepB", "jump") else 0
    # legs and polished shoes
    rect(g, 6, 16 - lift_l, 2, 3, PANTS); rect(g, 6, 19 - lift_l, 2, 1, SHOES)
    rect(g, 10, 16 - lift_r, 2, 3, PANTS); rect(g, 10, 19 - lift_r, 2, 1, SHOES)
    if kind == "stepA":
        px(g, 5, 19 - lift_l, SHOES)
    if kind == "stepB":
        px(g, 12, 19 - lift_r, SHOES)
    # the black vest with the yellow RECEITA band
    rect(g, 5, 10 + o, 8, 6, VEST[1]); vline(g, 12, 10 + o, 6, VEST[0])
    hline(g, 5, 10 + o, 8, VEST[2])
    hline(g, 5, 13 + o, 8, BAND[1]); px(g, 12, 13 + o, BAND[0])
    px(g, 6, 11 + o, GOLD)                     # the badge on her chest
    # arms
    if jump:
        rect(g, 3, 7, 2, 4, VEST[1]); px(g, 3, 6, S[3]); px(g, 4, 6, S[3])
        rect(g, 13, 7, 2, 4, VEST[0]); px(g, 13, 6, S[3]); px(g, 14, 6, S[3])
    else:
        rect(g, 4, 11 + o, 1, 3, VEST[1]); px(g, 4, 14 + o, S[3])
        if kind == "wave":
            # the rubber stamp, raised: a wooden knob over a red pad
            rect(g, 13, 7 + o, 1, 4, VEST[0]); px(g, 13, 6 + o, S[3])
            px(g, 14, 3 + o, STAMP[2])
            rect(g, 13, 4 + o, 3, 2, STAMP[1]); hline(g, 13, 5 + o, 3, STAMP[0])
        else:
            rect(g, 13, 11 + o, 1, 3, VEST[0]); px(g, 13, 14 + o, S[3])
    # head: a bun at the back, sunglasses, a small firm mouth
    rect(g, 5, 5 + o, 8, 5, S[3]); vline(g, 12, 5 + o, 5, S[2]); hline(g, 5, 9 + o, 8, S[2])
    px(g, 4, 6 + o, HAIR); px(g, 4, 7 + o, HAIR); px(g, 5, 5 + o, HAIR)
    hline(g, 6, 7 + o, 6, SHADES[0])
    px(g, 6, 7 + o, SHADES[1]); px(g, 10, 7 + o, SHADES[1])
    px(g, 6, 8 + o, BLUSH); px(g, 11, 8 + o, BLUSH)
    if kind in ("talk", "jump", "wave"):
        px(g, 8, 8 + o, MOUTH[0]); px(g, 9, 8 + o, MOUTH[0])
        px(g, 8, 9 + o, MOUTH[0]); px(g, 9, 9 + o, MOUTH[0])
    else:
        px(g, 8, 9 + o, MOUTH[0]); px(g, 9, 9 + o, MOUTH[0])
    # peaked cap: black crown, gold badge, a visor that sticks out in front
    rect(g, 6, 2 + o, 6, 1, CAP[1]); rect(g, 5, 3 + o, 8, 2, CAP[0])
    px(g, 6, 3 + o, CAP[1]); px(g, 9, 3 + o, GOLD)
    hline(g, 5, 4 + o, 9, CAP[0]); px(g, 13, 4 + o, CAP[1])
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


if __name__ == "__main__":
    gen_customs_body()
    gen_xray_items()
    gen_xray_portal()
    gen_xray_badge()
