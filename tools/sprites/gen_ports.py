"""What makes a port not the last one, in pixels.

`ui_flags.png`      30 x 16x11 the chart's flags first (`PortDB.flag`), then
                               the fleet's and the language picker's (`FleetDB.FLAGS`)
`<sprite>__<suffix>.png`       the active port's own painting of a shared sprite

A port is meant to look like somewhere else at a glance, so it changes three
ways:

- **Repainted palettes** (`_pal`): the ground and the hulls are drawn from a
  handful of palette entries, and a port swaps them entry by entry — Long
  Beach's pale slab concrete, sand and cobalt water; Shanghai's dark asphalt,
  deep-green hills and red-oxide decks — leaving paint lines alone.
- **Hue shifts** (`_shift`) for the machines' identity colours: crane red,
  RTG teal, safety yellow.
- **Drawn sprites** (`gen_port_art`) where a recolour cannot do it: palms and
  agaves, garden pines and boxwood, pennants and lanterns, Long Beach's
  long-nose tractor, Yangshan's cabless AGV, and each port's own container
  liveries (yard sheet and rail sheet).

Recolours read the sprites other generators wrote, so `generate_all.sh` runs
this once more after the loop.

`PortDB.sprite_name` picks `<sprite>__<suffix>` when the file exists and the
shared sprite when it does not, so adding a themed sprite is adding a line to
`THEMES` here and nothing anywhere else.
"""
import colorsys
import os

from PIL import Image

import math

import palette as P
from common import new_img, rect, hline, vline, px, save, sheet, outline
import gen_containers
import gen_train
from gen_vehicles import body, glass, tyres, beacon, hazard, INK, CHROME

HERE = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(HERE, "..", "..", "assets", "sprites")


# ----------------------------------------------------------------------- flags

def _flag_br():
    g = new_img(16, 11)
    rect(g, 0, 0, 16, 11, (38, 150, 84, 255))
    for i, half in enumerate((1, 3, 5, 6, 5, 3, 1)):
        hline(g, 8 - half, 2 + i, half * 2, (250, 212, 60, 255))
    rect(g, 6, 4, 4, 3, (40, 72, 150, 255))
    hline(g, 6, 5, 4, (236, 240, 244, 255))
    return g


def _flag_us():
    g = new_img(16, 11)
    for y in range(11):
        hline(g, 0, y, 16, (198, 58, 60, 255) if y % 2 == 0 else (244, 244, 244, 255))
    rect(g, 0, 0, 7, 6, (44, 62, 128, 255))
    for (x, y) in ((1, 1), (3, 1), (5, 1), (2, 3), (4, 3), (1, 4), (5, 4)):
        px(g, x, y, (244, 244, 244, 255))
    return g


def _flag_cn():
    g = new_img(16, 11)
    rect(g, 0, 0, 16, 11, (212, 52, 44, 255))
    gold = (252, 214, 70, 255)
    rect(g, 2, 2, 3, 3, gold)
    px(g, 3, 1, gold); px(g, 1, 3, gold); px(g, 5, 3, gold)
    for (x, y) in ((7, 1), (8, 3), (8, 5), (7, 7)):
        px(g, x, y, gold)
    return g


def _flag_nl():
    g = new_img(16, 11)
    rect(g, 0, 0, 16, 4, (190, 52, 56, 255))
    rect(g, 0, 4, 16, 3, (244, 244, 244, 255))
    rect(g, 0, 7, 16, 4, (44, 76, 148, 255))
    return g


def _flag_sg():
    g = new_img(16, 11)
    rect(g, 0, 0, 16, 6, (206, 52, 60, 255))
    rect(g, 0, 6, 16, 5, (244, 244, 244, 255))
    w = (244, 244, 244, 255)
    vline(g, 2, 1, 4, w); px(g, 3, 1, w); px(g, 3, 4, w)
    for (x, y) in ((5, 2), (7, 2), (6, 1), (5, 4), (7, 4)):
        px(g, x, y, w)
    return g


def _flag_ae():
    g = new_img(16, 11)
    rect(g, 0, 0, 16, 4, (40, 140, 80, 255))
    rect(g, 0, 4, 16, 3, (244, 244, 244, 255))
    rect(g, 0, 7, 16, 4, (40, 40, 46, 255))
    rect(g, 0, 0, 4, 11, (198, 52, 56, 255))
    return g


# The rest of the world's ensigns: the fleet's registries (`FleetDB.FLAGS`) and
# the language picker. The frame is painted over the outer pixel afterwards, so
# the field below is the 14x9 inside it, x 1..14, y 1..9.
WHITE_F = (244, 244, 244, 255)
RED_F = (204, 46, 52, 255)
BLUE_F = (40, 66, 140, 255)
GOLD_F = (250, 208, 56, 255)
GREEN_F = (36, 140, 76, 255)
BLACK_F = (34, 32, 38, 255)


def _tricolour_h(top, mid, bottom, split=(4, 7)):
    g = new_img(16, 11)
    rect(g, 0, 0, 16, split[0], top)
    rect(g, 0, split[0], 16, split[1] - split[0], mid)
    rect(g, 0, split[1], 16, 11 - split[1], bottom)
    return g


def _tricolour_v(left, mid, right):
    g = new_img(16, 11)
    rect(g, 0, 0, 6, 11, left)
    rect(g, 6, 0, 5, 11, mid)
    rect(g, 11, 0, 5, 11, right)
    return g


def _nordic(field, cross, inner=None):
    g = new_img(16, 11)
    rect(g, 0, 0, 16, 11, field)
    if inner is None:
        rect(g, 5, 0, 2, 11, cross)
        rect(g, 0, 4, 16, 2, cross)
    else:
        rect(g, 4, 0, 4, 11, cross)
        rect(g, 0, 3, 16, 4, cross)
        rect(g, 5, 0, 2, 11, inner)
        rect(g, 0, 4, 16, 2, inner)
    return g


def _flag_pa():
    g = new_img(16, 11)
    rect(g, 0, 0, 8, 5, WHITE_F); rect(g, 8, 0, 8, 5, RED_F)
    rect(g, 0, 5, 8, 6, BLUE_F); rect(g, 8, 5, 8, 6, WHITE_F)
    for (x, y, c) in ((4, 2, BLUE_F), (11, 7, RED_F)):
        px(g, x, y, c); px(g, x - 1, y, c); px(g, x + 1, y, c); px(g, x, y - 1, c); px(g, x, y + 1, c)
    return g


def _flag_lr():
    g = new_img(16, 11)
    for y in range(11):
        hline(g, 0, y, 16, RED_F if y % 2 else WHITE_F)
    rect(g, 1, 1, 5, 5, BLUE_F)
    px(g, 3, 3, WHITE_F); px(g, 2, 3, WHITE_F); px(g, 4, 3, WHITE_F); px(g, 3, 2, WHITE_F)
    return g


def _flag_mh():
    g = new_img(16, 11)
    rect(g, 0, 0, 16, 11, (34, 62, 136, 255))
    for i in range(16):
        y = 10 - (i * 10) // 15
        px(g, i, y, (240, 140, 52, 255)); px(g, i, y - 1, (240, 140, 52, 255))
        px(g, i, y - 2, WHITE_F)
    px(g, 3, 3, WHITE_F); px(g, 2, 3, WHITE_F); px(g, 4, 3, WHITE_F); px(g, 3, 2, WHITE_F); px(g, 3, 4, WHITE_F)
    return g


def _flag_mt():
    g = new_img(16, 11)
    rect(g, 0, 0, 8, 11, WHITE_F); rect(g, 8, 0, 8, 11, RED_F)
    grey = (150, 150, 158, 255)
    rect(g, 3, 2, 1, 3, grey); rect(g, 2, 3, 3, 1, grey)
    return g


def _flag_gr():
    g = new_img(16, 11)
    for y in range(11):
        hline(g, 0, y, 16, (34, 96, 176, 255) if y % 2 else WHITE_F)
    rect(g, 1, 1, 5, 5, (34, 96, 176, 255))
    rect(g, 3, 1, 1, 5, WHITE_F); rect(g, 1, 3, 5, 1, WHITE_F)
    return g


def _flag_gb():
    g = new_img(16, 11)
    rect(g, 0, 0, 16, 11, (30, 50, 118, 255))
    for i in range(16):
        y = round(i * 10 / 15)
        for dy in (-1, 0, 1):
            px(g, i, y + dy, WHITE_F); px(g, i, 10 - y + dy, WHITE_F)
        px(g, i, y, RED_F); px(g, i, 10 - y, RED_F)
    rect(g, 6, 0, 4, 11, WHITE_F); rect(g, 0, 4, 16, 3, WHITE_F)
    rect(g, 7, 0, 2, 11, RED_F); rect(g, 0, 5, 16, 1, RED_F)
    return g


def _flag_es():
    g = _tricolour_h(RED_F, GOLD_F, RED_F, (3, 8))
    rect(g, 3, 4, 2, 3, (176, 40, 44, 255))
    return g


def _flag_jp():
    g = new_img(16, 11)
    rect(g, 0, 0, 16, 11, WHITE_F)
    rect(g, 6, 3, 4, 5, (196, 30, 46, 255)); rect(g, 5, 4, 6, 3, (196, 30, 46, 255))
    return g


def _flag_kr():
    g = new_img(16, 11)
    rect(g, 0, 0, 16, 11, WHITE_F)
    rect(g, 6, 3, 4, 2, (196, 40, 52, 255)); rect(g, 5, 4, 6, 1, (196, 40, 52, 255))
    rect(g, 6, 6, 4, 2, (34, 70, 150, 255)); rect(g, 5, 5, 6, 1, (34, 70, 150, 255))
    for (x, y) in ((2, 2), (12, 2), (2, 7), (12, 7)):
        rect(g, x, y, 2, 2, BLACK_F)
    return g


def _flag_pt():
    g = new_img(16, 11)
    rect(g, 0, 0, 6, 11, (34, 120, 60, 255)); rect(g, 6, 0, 10, 11, RED_F)
    rect(g, 5, 3, 3, 5, GOLD_F); rect(g, 4, 4, 5, 3, GOLD_F)
    px(g, 6, 5, WHITE_F)
    return g


def _flag_in():
    g = _tricolour_h((240, 140, 52, 255), WHITE_F, (30, 130, 60, 255))
    px(g, 7, 5, (30, 50, 140, 255)); px(g, 8, 5, (30, 50, 140, 255))
    return g


def _flag_ar():
    sky = (108, 172, 224, 255)
    g = _tricolour_h(sky, WHITE_F, sky)
    px(g, 7, 5, GOLD_F); px(g, 8, 5, GOLD_F)
    return g


def _flag_mx():
    g = _tricolour_v((0, 110, 70, 255), WHITE_F, (200, 30, 44, 255))
    rect(g, 7, 4, 2, 3, (140, 96, 50, 255))
    return g


def _flag_tr():
    g = new_img(16, 11)
    rect(g, 0, 0, 16, 11, (214, 30, 40, 255))
    rect(g, 4, 3, 1, 5, WHITE_F); rect(g, 5, 2, 2, 1, WHITE_F); rect(g, 5, 8, 2, 1, WHITE_F)
    px(g, 7, 3, WHITE_F); px(g, 7, 7, WHITE_F)
    px(g, 10, 5, WHITE_F); px(g, 9, 5, WHITE_F); px(g, 11, 5, WHITE_F); px(g, 10, 4, WHITE_F); px(g, 10, 6, WHITE_F)
    return g


def _flag_cl():
    g = new_img(16, 11)
    rect(g, 0, 0, 16, 6, WHITE_F); rect(g, 0, 6, 16, 5, RED_F)
    rect(g, 1, 1, 5, 5, (32, 62, 156, 255))
    px(g, 3, 3, WHITE_F)
    return g


def _flag_ca():
    g = new_img(16, 11)
    rect(g, 0, 0, 16, 11, WHITE_F)
    rect(g, 0, 0, 4, 11, RED_F); rect(g, 12, 0, 4, 11, RED_F)
    rect(g, 7, 3, 2, 6, RED_F); rect(g, 6, 4, 4, 2, RED_F); px(g, 5, 4, RED_F); px(g, 10, 4, RED_F)
    return g


## Same order as `FleetDB.FLAGS`: the six chart flags first (their indices are
## `PortDB.flag`), then the registries and the language picker's.
FLAG_MAKERS = (
    _flag_br, _flag_us, _flag_cn, _flag_nl, _flag_sg, _flag_ae,
    _flag_pa, _flag_lr, _flag_mh, _flag_mt, _flag_gr,
    lambda: _nordic(RED_F, WHITE_F),                                  # DK
    lambda: _tricolour_h(BLACK_F, (214, 36, 40, 255), GOLD_F),        # DE
    lambda: _tricolour_v((36, 64, 150, 255), WHITE_F, RED_F),         # FR
    lambda: _tricolour_v((0, 140, 70, 255), WHITE_F, (206, 40, 46, 255)),  # IT
    _flag_es, _flag_gb, _flag_jp, _flag_kr,
    lambda: _nordic((196, 36, 46, 255), WHITE_F, (36, 52, 120, 255)),  # NO
    _flag_pt, _flag_in, _flag_ar, _flag_mx,
    lambda: _tricolour_h(WHITE_F, (36, 72, 160, 255), RED_F),         # RU
    lambda: _tricolour_h(WHITE_F, WHITE_F, RED_F, (3, 6)),            # PL
    _flag_tr, _flag_cl, _flag_ca,
    lambda: _nordic((40, 100, 180, 255), GOLD_F),                     # SE
)


def gen_flags():
    frames = []
    for make in FLAG_MAKERS:
        g = make()
        # a one-pixel dark frame so a white stripe never bleeds into paper
        ink = (40, 34, 44, 255)
        hline(g, 0, 0, 16, ink); hline(g, 0, 10, 16, ink)
        vline(g, 0, 0, 11, ink); vline(g, 15, 0, 11, ink)
        frames.append(g)
    save(sheet(frames), "ui_flags", preview_scale=8)


# ---------------------------------------------------------------------- themes

def _shift(lo, hi, hue=None, sat=1.0, val=1.0, min_sat=0.22, add_hue=0.0):
    """A rule: pixels whose hue is in [lo, hi] degrees and saturated enough
    move to `hue` (or by `add_hue`), with saturation and value scaled."""
    return {"lo": lo, "hi": hi, "hue": hue, "sat": sat, "val": val,
            "min_sat": min_sat, "add": add_hue}


def _tone(sat=1.0, val=1.0, tint=None, amount=0.0):
    """A rule for the nearly-grey pixels a hue test cannot catch (asphalt,
    concrete): scale, then lean toward `tint`."""
    return {"grey": True, "sat": sat, "val": val, "tint": tint, "amount": amount}


RED = (345, 22)        # the quay crane, roofs
TEAL = (160, 200)      # the RTG
YELLOW = (28, 52)      # safety yellow, vehicles
BROWN = (18, 42)       # soil
GREEN = (70, 140)      # grass

def _pal(pairs, tol=12):
    """A rule: pixels within `tol` of a source colour take its target. The
    ground and the hulls are drawn from a handful of palette entries, so a
    port can repaint them entry by entry — concrete for paving, sand for grass
    — which no hue shift can do without dragging the paint lines along."""
    return {"pal": [(tuple(a[:3]), tuple(b[:3])) for a, b in pairs], "tol": tol}


# The shared ground's palette entries, darkest first (read off the tiles).
YARD_SRC = [(96, 87, 93), (96, 88, 92), (108, 98, 100), (109, 100, 104),
            (122, 114, 116), (134, 127, 128), (146, 138, 138), (146, 140, 139)]
QUAY_SRC = [(120, 110, 100), (140, 122, 115), (156, 141, 130), (163, 157, 150),
            (172, 160, 146), (186, 176, 160), (200, 193, 175)]
GRASS_SRC = [(59, 122, 55), (72, 100, 84), (82, 139, 66), (86, 112, 92),
             (106, 156, 78), (131, 171, 94), (156, 186, 109)]
DIRT_SRC = [(122, 70, 50), (137, 92, 63), (152, 114, 76), (167, 136, 92),
            (182, 159, 108)]
# The hulls' deck, hatch and house entries (`gen_ship.py`).
DECK_SRC = [(112, 120, 132), (96, 102, 116), (84, 98, 96), (127, 142, 139),
            (73, 77, 90)]
HOUSE_SRC = [(226, 222, 212), (228, 226, 217), (249, 248, 241)]


def _map(src, dst):
    return list(zip(src, dst))


GROUND = {
    # Long Beach: pale Californian concrete in slabs, sand where Santos has
    # grass, desert dirt, a bright cool apron.
    "usa": {
        "yard": _map(YARD_SRC, [(150, 148, 142), (150, 148, 142), (170, 167, 160),
                                (172, 169, 162), (190, 186, 178), (202, 198, 190),
                                (214, 210, 202), (214, 210, 202)]),
        "quay": _map(QUAY_SRC, [(150, 152, 152), (168, 170, 170), (184, 186, 184),
                                (192, 194, 192), (200, 202, 198), (214, 216, 212),
                                (230, 232, 228)]),
        "grass": _map(GRASS_SRC, [(196, 164, 108), (180, 160, 120), (212, 182, 124),
                                  (196, 176, 136), (226, 200, 144), (236, 214, 162),
                                  (246, 230, 186)]),
        "dirt": _map(DIRT_SRC, [(170, 120, 80), (186, 138, 94), (200, 156, 108),
                                (212, 174, 124), (224, 192, 142)]),
        "joints": (164, 160, 152),
    },
    # Shanghai: new dark asphalt with a blue cast, a grey steel-and-concrete
    # apron, wet deep-green island hills and red clay.
    "cn": {
        "yard": _map(YARD_SRC, [(40, 44, 54), (40, 44, 54), (50, 55, 66), (52, 57, 68),
                                (60, 66, 78), (72, 78, 92), (86, 92, 106), (86, 92, 106)]),
        "quay": _map(QUAY_SRC, [(78, 84, 92), (96, 102, 110), (110, 116, 124),
                                (116, 122, 130), (124, 130, 138), (140, 146, 152),
                                (158, 164, 170)]),
        "grass": _map(GRASS_SRC, [(28, 70, 56), (40, 72, 64), (36, 88, 66), (48, 84, 72),
                                  (46, 106, 76), (62, 126, 88), (84, 148, 100)]),
        "dirt": _map(DIRT_SRC, [(110, 52, 40), (128, 64, 46), (144, 78, 54),
                                (160, 96, 66), (176, 116, 80)]),
        "joints": None,
    },
}

HULLS = {
    # A Pacific liner's green deck and white house; a Chinese yard's red-oxide
    # deck and pale blue-grey house. The livery paint layer stays as it is.
    "usa": _map(DECK_SRC, [(70, 96, 72), (60, 84, 64), (56, 74, 58), (96, 120, 98),
                           (46, 60, 50)]) +
           _map(HOUSE_SRC, [(240, 242, 244), (244, 246, 248), (255, 255, 255)]),
    "cn": _map(DECK_SRC, [(132, 72, 58), (116, 62, 52), (100, 52, 44), (156, 92, 74),
                          (84, 44, 40)]) +
          _map(HOUSE_SRC, [(196, 212, 224), (204, 218, 230), (230, 240, 248)]),
}

YARD_TILES = ["gr_yard_0", "gr_yard_1", "gr_yard_2", "gr_yard_3", "gr_yard", "gr_yard_b"]
QUAY_TILES = ["gr_quay", "gr_quay_edge"]
GRASS_TILES = ["gr_grass", "gr_seam_tufts"]
DIRT_TILES = ["gr_dirt_0", "gr_dirt_1", "gr_dirt_2", "gr_dirt", "gr_dirt_edge"]
SHIPS = ["ship_top", "ship_top_feeder", "ship_top_new_panamax"]


def _ground_rules(suffix):
    g = GROUND[suffix]
    every = g["yard"] + g["quay"] + g["grass"] + g["dirt"]
    return [
        (YARD_TILES, [_pal(g["yard"] + g["grass"])]),
        (QUAY_TILES, [_pal(g["quay"] + g["grass"])]),
        (GRASS_TILES, [_pal(g["grass"] + g["yard"])]),
        (DIRT_TILES, [_pal(g["dirt"] + g["grass"])]),
        (["gr_curb"], [_pal(every)]),
        (SHIPS, [_pal(HULLS[suffix], tol=4)]),
    ]


# (sprites, rules). First matching rule wins for a pixel.
THEMES = {
    "usa": _ground_rules("usa") + [
        # Long Beach: navy-blue quay cranes, white-and-amber yard gantries,
        # red road tractors.
        (["sts_base", "sts_beam"], [_shift(*RED, hue=214, sat=0.85, val=0.95)]),
        (["rtg", "rtg_trolley"], [_shift(*TEAL, hue=44, sat=0.95, val=1.25)]),
        (["veh_tt", "veh_forklift", "veh_reach_stacker"],
         [_shift(*YELLOW, hue=4, sat=0.95, val=0.90, min_sat=0.5)]),
        (["bld_warehouse"], [_shift(*RED, hue=208, sat=0.45, val=1.05)]),
    ],
    "cn": _ground_rules("cn") + [
        # Shanghai: the blue cranes of an automated quay, red yard gantries,
        # white-and-blue machines.
        (["sts_base", "sts_beam"], [_shift(*RED, hue=196, sat=0.95, val=0.92)]),
        (["rtg", "rtg_trolley"], [_shift(*TEAL, hue=6, sat=1.0, val=1.0)]),
        (["veh_truck_cab", "veh_forklift", "veh_reach_stacker"],
         [_shift(*YELLOW, hue=204, sat=0.42, val=1.08, min_sat=0.5)]),
        (["bld_warehouse"], [_shift(*RED, hue=152, sat=0.75, val=0.92)]),
    ],
}


def _in_hue(h, lo, hi):
    return lo <= h <= hi if lo <= hi else (h >= lo or h <= hi)


def _recolour(img, rules):
    out = img.copy()
    src = img.load()
    dst = out.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            deg = h * 360.0
            for rule in rules:
                if "pal" in rule:
                    hit = None
                    best = rule["tol"] ** 2
                    for src_c, dst_c in rule["pal"]:
                        dd = (r - src_c[0]) ** 2 + (g - src_c[1]) ** 2 + (b - src_c[2]) ** 2
                        if dd <= best:
                            best = dd
                            hit = dst_c
                    if hit is None:
                        continue
                    dst[x, y] = hit + (a,)
                    break
                if rule.get("grey"):
                    if s > 0.22:
                        continue
                    s2, v2 = s * rule["sat"], min(1.0, v * rule["val"])
                    nr, ng, nb = colorsys.hsv_to_rgb(h, s2, v2)
                    if rule["tint"] is not None:
                        k = rule["amount"]
                        lum = v2
                        tr, tg, tb = (c / 255.0 for c in rule["tint"])
                        scale = lum / max(0.01, max(tr, tg, tb))
                        nr = nr + (tr * scale - nr) * k
                        ng = ng + (tg * scale - ng) * k
                        nb = nb + (tb * scale - nb) * k
                    dst[x, y] = (round(min(1, nr) * 255), round(min(1, ng) * 255),
                                 round(min(1, nb) * 255), a)
                    break
                if s < rule["min_sat"] or not _in_hue(deg, rule["lo"], rule["hi"]):
                    continue
                if rule["hue"] is not None:
                    # keep the ramp's own hue drift (lights lean warm, shadows
                    # cool) by carrying the offset from the band's middle
                    mid = (rule["lo"] + ((rule["hi"] - rule["lo"]) % 360) / 2.0) % 360
                    drift = ((deg - mid + 180.0) % 360.0) - 180.0
                    nh = (rule["hue"] + drift * 0.6) % 360.0
                else:
                    nh = (deg + rule["add"]) % 360.0
                nr, ng, nb = colorsys.hsv_to_rgb(
                    nh / 360.0, min(1.0, s * rule["sat"]), min(1.0, v * rule["val"]))
                dst[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
                break
    return out


def gen_themes():
    for suffix, groups in THEMES.items():
        for names, rules in groups:
            for name in names:
                path = os.path.join(SPRITES, name + ".png")
                if not os.path.exists(path):
                    continue
                img = Image.open(path).convert("RGBA")
                out = _recolour(img, rules)
                joints = GROUND[suffix]["joints"]
                if joints and name in YARD_TILES:
                    out = _slab_joints(out, joints)
                save(out, "%s__%s" % (name, suffix))


def _slab_joints(img, colour):
    """Concrete is poured in slabs: a joint along the top and left of every
    tile turns the paving into a 16px slab grid. Paint is left alone."""
    out = img.copy()
    src = img.load()
    dst = out.load()
    w, h = img.size
    for x in range(w):
        for y in range(h):
            if x != 0 and y != 0:
                continue
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            _h, s, _v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if s < 0.2:
                dst[x, y] = colour[:3] + (a,)
    return out


# ------------------------------------------------------------- drawn per port
#
# Some of what makes a port itself cannot be a recolour: a palm is not a green
# tree turned yellow, an American tractor has a bonnet, Yangshan's yard
# tractors have no cab at all. These are drawn here, at the size and anchor of
# the shared sprite they stand in for, so the code that places them does not
# know the difference.

PALM_GREEN = [(44, 98, 58, 255), (70, 132, 70, 255), (112, 170, 86, 255)]
PALM_TRUNK = [(110, 80, 52, 255), (150, 112, 70, 255)]


def palm():
    """A fan palm from above, 22x22 like `prop_tree`: fronds radiating from
    a crown, each frond a tapered stroke, the trunk's top in the middle."""
    img = new_img(22, 22)
    c = 10.5
    for k in range(9):
        ang = k * (2 * math.pi / 9) + 0.2
        for t in range(2, 11):
            fx = c + math.cos(ang) * t
            fy = c + math.sin(ang) * t + (t * t) * 0.012
            col = PALM_GREEN[2] if t < 5 else (PALM_GREEN[1] if t < 8 else PALM_GREEN[0])
            px(img, int(fx), int(fy), col)
            if 3 < t < 9:
                # leaflets either side of the rib
                px(img, int(fx - math.sin(ang)), int(fy + math.cos(ang)), PALM_GREEN[0])
                if t % 2:
                    px(img, int(fx + math.sin(ang)), int(fy - math.cos(ang)), PALM_GREEN[1])
    rect(img, 9, 9, 3, 3, PALM_TRUNK[0])
    px(img, 9, 9, PALM_TRUNK[1])
    return outline(img)


def pine():
    """A Chinese black pine from above, 22x22: tiered flat pads of needles
    with gaps between them, the shape of a garden pine, not a round tree."""
    img = new_img(22, 22)
    pads = [(7, 7, 5), (15, 8, 4), (8, 15, 4), (15, 15, 5), (11, 11, 4)]
    dark, mid, lit = (28, 74, 60, 255), (42, 100, 72, 255), (78, 136, 88, 255)
    for (cx, cy, r) in pads:
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r - 1, cx + r + 2):
                dx, dy = (x - cx) / (r + 1.2), (y - cy) / r
                if dx * dx + dy * dy <= 1.0:
                    col = mid
                    if dx + dy < -0.5:
                        col = lit
                    elif dx + dy > 0.6:
                        col = dark
                    px(img, x, y, col)
        # needle texture
        for i in range(-r, r + 1, 2):
            px(img, cx + i, cy, dark)
    px(img, 11, 11, (90, 60, 44, 255))
    return outline(img)


def agave():
    """A blue agave from above, 14x12 like `prop_bush`: spiky rosette."""
    img = new_img(14, 12)
    blue, lit, dark = (96, 150, 140, 255), (150, 196, 176, 255), (60, 104, 100, 255)
    c = (6.5, 6.0)
    for k in range(10):
        ang = k * (2 * math.pi / 10)
        for t in range(1, 7):
            x = c[0] + math.cos(ang) * t
            y = c[1] + math.sin(ang) * t * 0.85
            px(img, int(x), int(y), lit if t < 3 else (blue if t < 5 else dark))
    return outline(img)


def boxwood():
    """A clipped boxwood ball in a stone ring, 14x12."""
    img = new_img(14, 12)
    for y in range(12):
        for x in range(14):
            d = math.hypot(x - 6.5, y - 5.5)
            if 5.0 < d <= 6.2:
                px(img, x, y, (150, 150, 146, 255))
            elif d <= 5.0:
                col = (52, 110, 66, 255)
                if (x - 6.5) + (y - 5.5) < -2:
                    col = (86, 150, 88, 255)
                elif (x - 6.5) + (y - 5.5) > 3:
                    col = (34, 80, 52, 255)
                px(img, x, y, col)
    return outline(img)


def _bunting(colours, kind):
    """`prop_bunting`'s span (64x14, tiling in X) in another port's colours:
    `pennant` flags on a line, or `lantern` round paper lanterns."""
    w, h = 64, 14
    img = new_img(w, h)
    for x in range(w):
        sag = int(2.0 * math.sin(math.pi * x / (w - 1)))
        px(img, x, 2 + sag, (46, 38, 42, 255))
        px(img, x, 3 + sag, (86, 74, 76, 255))
    for index, start in enumerate(range(1, w - 6, 8)):
        colour = colours[index % len(colours)]
        shade = tuple(int(c * 0.7) for c in colour[:3]) + (255,)
        sag = int(2.0 * math.sin(math.pi * (start + 3) / (w - 1)))
        if kind == "lantern":
            cx, cy = start + 3, 6 + sag
            for y in range(-2, 3):
                half = 3 if abs(y) < 2 else 2
                hline(img, cx - half, cy + y, half * 2, colour)
                px(img, cx + half - 1, cy + y, shade)
            hline(img, cx - 1, cy - 3, 2, (60, 40, 30, 255))
            hline(img, cx - 1, cy + 3, 2, (230, 190, 60, 255))
            px(img, cx - 2, cy - 1, (255, 220, 170, 255))
            px(img, cx, cy + 5, (40, 36, 44, 70))
        else:
            for row in range(5):
                half = 3 - row // 2
                if half <= 0:
                    continue
                span = half * 2
                left = start + 3 - half
                hline(img, left, 4 + sag + row, span, colour)
                px(img, left + span - 1, 4 + sag + row, shade)
            px(img, start + 3, 10 + sag, (40, 36, 44, 70))
    return img


US_RED = [(130, 36, 40, 255), (186, 52, 52, 255), (226, 92, 84, 255)]


def long_nose_cab():
    """An American conventional tractor, nose up, 18x30: a long bonnet ahead
    of the cab where Santos' cab-over has none, chrome stacks, a sleeper.
    `RoadTruck` lines it up by its *bottom* edge, so the fifth wheel sits
    where the shared 18x24 cab's does (6 px from the tail)."""
    w, h = 18, 30
    img = new_img(w, h)
    tyres(img, 1, 3, 3, 6)
    tyres(img, 14, 3, 3, 6)
    tyres(img, 0, 20, 3, 6)
    tyres(img, 15, 20, 3, 6)
    # the bonnet: long, narrower than the cab, a chrome grille at the front
    hline(img, 4, 0, 10, CHROME)
    body(img, 4, 1, 10, 10, US_RED)
    for gy in range(2, 10, 2):
        hline(img, 6, gy, 6, US_RED[2])
    # fenders either side of the bonnet
    rect(img, 2, 4, 2, 6, US_RED[0])
    rect(img, 14, 4, 2, 6, US_RED[0])
    # the cab and the windscreen behind the bonnet
    body(img, 2, 11, 14, 8, US_RED)
    glass(img, 4, 11, 10, 3)
    # twin chrome stacks at the back of the cab
    rect(img, 1, 14, 2, 4, CHROME)
    rect(img, 15, 14, 2, 4, CHROME)
    px(img, 1, 14, (255, 255, 255, 255))
    px(img, 15, 14, (255, 255, 255, 255))
    # sleeper roof
    rect(img, 4, 19, 10, 3, US_RED[0])
    hline(img, 4, 19, 10, US_RED[1])
    # fifth wheel, 6 px from the tail like the shared cab
    rect(img, 6, 23, 6, 4, P.STEEL_D)
    hline(img, 6, 23, 6, P.STEEL)
    px(img, 8, 25, INK)
    px(img, 9, 25, INK)
    px(img, 5, 0, P.WINDOW_LIT)
    px(img, 12, 0, P.WINDOW_LIT)
    px(img, 6, 12, BEACON_AMBER)
    px(img, 11, 12, BEACON_AMBER)
    return outline(img)


BEACON_AMBER = (255, 170, 60, 255)
AGV_WHITE = [(176, 184, 196, 255), (220, 226, 234, 255), (246, 248, 252, 255)]
AGV_BLUE = (40, 100, 186, 255)


def agv():
    """A Yangshan automated guided vehicle, 20x52 like `veh_tt`: a long flat
    deck with no cab at all, a sensor bumper and status light at each end,
    eight wheels under it. The container rides at y=20..44 like the tractor's."""
    w, h = 20, 52
    img = new_img(w, h)
    for ty in (6, 18, 30, 42):
        tyres(img, 0, ty, 3, 5)
        tyres(img, 17, ty, 3, 5)
    body(img, 2, 2, 16, 48, AGV_WHITE)
    # the deck the box sits on: a recessed steel bed with guide rails
    rect(img, 4, 8, 12, 36, P.STEEL_D)
    vline(img, 5, 8, 36, P.STEEL)
    vline(img, 14, 8, 36, P.STEEL)
    for cy in (14, 24, 34):
        hline(img, 6, cy, 8, P.STEEL)
    # blue stripes and the sensor bumpers at both ends
    for y0 in (3, 45):
        rect(img, 3, y0, 14, 3, AGV_BLUE)
        hline(img, 5, y0 + 1, 10, (20, 24, 34, 255))
        px(img, 9, y0 + 1, (120, 230, 255, 255))
        px(img, 10, y0 + 1, (120, 230, 255, 255))
    beacon(img, 2, 4)
    beacon(img, 16, 46)
    return outline(img)


# Liveries that call at each port: Santos is earth and rust; the Pacific's
# boxes are white, grey, navy and signal colours; Shanghai's are the bright
# blues and oranges of the big Chinese lines.
CONTAINERS = {
    "usa": [(226, 228, 230), (150, 156, 164), (48, 66, 116), (190, 46, 46),
            (222, 182, 54), (52, 112, 76), (60, 62, 70), (110, 168, 214)],
    "cn": [(36, 96, 178), (238, 122, 36), (200, 44, 44), (232, 232, 228),
           (24, 142, 140), (28, 46, 108), (132, 136, 142), (96, 176, 226)],
}


def _container_ramps(suffix):
    return [P.ramp(c + (255,), 5, hue_shift=16.0, dark=0.42, light=0.55)
            for c in CONTAINERS[suffix]]


def gen_port_art():
    save(palm(), "prop_tree__usa")
    save(agave(), "prop_bush__usa")
    save(pine(), "prop_tree__cn")
    save(boxwood(), "prop_bush__cn")
    save(_bunting([(190, 46, 46, 255), (244, 244, 244, 255), (48, 66, 128, 255)],
                  "pennant"), "prop_bunting__usa")
    save(_bunting([(212, 44, 40, 255), (226, 60, 48, 255)], "lantern"),
         "prop_bunting__cn")
    save(long_nose_cab(), "veh_truck_cab__usa")
    save(agv(), "veh_tt__cn")
    for suffix in CONTAINERS:
        ramps = _container_ramps(suffix)
        save(sheet([gen_containers.container(r) for r in ramps]),
             "container_sheet__%s" % suffix)
        save(sheet([gen_train.rail_box(r) for r in ramps]),
             "rail_box_sheet__%s" % suffix)


if __name__ == "__main__":
    print("ports:")
    gen_flags()
    gen_themes()
    gen_port_art()
