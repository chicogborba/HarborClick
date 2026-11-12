"""What makes a port not the last one, in pixels.

`ui_flags.png`      6 x 16x11  the flags on the ports chart, in `PortDB.flag` order
`<sprite>__<suffix>.png`       the active port's own painting of a shared sprite

A port does not get a second art set. It gets the *same* drawings re-liveried:
this reads the sprites the other generators wrote and moves the hues that carry
identity — the crane red, the RTG teal, the safety yellow, the asphalt, the
soil, the roof — leaving glass, steel, tyres, hazard tape and outlines alone.
That keeps every port inside the one palette language, and means a machine
redrawn in `gen_cranes.py` is redrawn in Long Beach and Shanghai too. So this
runs after the sprite generators it reads (alphabetical order already does
that for everything it touches except `gen_vehicles`/`gen_worldmap`, which it
does not depend on being *newer* than — only on existing).

`PortDB.sprite_name` picks `<sprite>__<suffix>` when the file exists and the
shared sprite when it does not, so adding a themed sprite is adding a line to
`THEMES` here and nothing anywhere else.
"""
import colorsys
import os

from PIL import Image

from common import new_img, rect, hline, vline, px, save, sheet

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


def gen_flags():
    frames = []
    for make in (_flag_br, _flag_us, _flag_cn, _flag_nl, _flag_sg, _flag_ae):
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

# (sprites, rules). First matching rule wins for a pixel.
THEMES = {
    "usa": [
        # Long Beach: navy-blue quay cranes, white-and-amber yard gantries,
        # red road tractors, pale Californian concrete, sand and dry grass.
        (["sts_base", "sts_beam"], [_shift(*RED, hue=214, sat=0.85, val=0.95)]),
        (["rtg", "rtg_trolley"], [_shift(*TEAL, hue=44, sat=0.95, val=1.25)]),
        (["veh_tt", "veh_truck_cab", "veh_forklift", "veh_reach_stacker"],
         [_shift(*YELLOW, hue=4, sat=0.95, val=0.90, min_sat=0.5)]),
        (["bld_warehouse"], [_shift(*RED, hue=208, sat=0.45, val=1.05)]),
        (["gr_yard_0", "gr_yard_1", "gr_yard_2", "gr_yard_3", "gr_yard",
          "gr_yard_b", "gr_curb"],
         [_shift(*GREEN, add_hue=-22, sat=0.75, val=1.05),
          _tone(sat=0.5, val=1.16, tint=(150, 160, 172), amount=0.30)]),
        (["gr_quay", "gr_quay_edge"],
         [_tone(sat=0.6, val=1.06, tint=(214, 210, 200), amount=0.25)]),
        (["gr_dirt_0", "gr_dirt_1", "gr_dirt_2", "gr_dirt", "gr_dirt_edge"],
         [_shift(*GREEN, add_hue=-25, sat=0.7, val=1.05),
          _shift(*BROWN, add_hue=8, sat=0.62, val=1.22, min_sat=0.15)]),
        (["gr_grass"], [_shift(*GREEN, add_hue=-28, sat=0.72, val=1.06)]),
    ],
    "cn": [
        # Shanghai: the blue cranes of an automated quay, red yard gantries,
        # white-and-blue driverless tractors, new dark asphalt, red clay and
        # wet green.
        (["sts_base", "sts_beam"], [_shift(*RED, hue=196, sat=0.95, val=0.92)]),
        (["rtg", "rtg_trolley"], [_shift(*TEAL, hue=6, sat=1.0, val=1.0)]),
        (["veh_tt", "veh_truck_cab", "veh_forklift", "veh_reach_stacker"],
         [_shift(*YELLOW, hue=204, sat=0.42, val=1.08, min_sat=0.5)]),
        (["bld_warehouse"], [_shift(*RED, hue=152, sat=0.75, val=0.92)]),
        (["gr_yard_0", "gr_yard_1", "gr_yard_2", "gr_yard_3", "gr_yard",
          "gr_yard_b", "gr_curb"],
         [_shift(*GREEN, add_hue=18, sat=1.1, val=0.95),
          _tone(sat=0.6, val=0.80, tint=(70, 78, 92), amount=0.30)]),
        (["gr_quay", "gr_quay_edge"],
         [_tone(sat=0.5, val=0.95, tint=(170, 176, 180), amount=0.30)]),
        (["gr_dirt_0", "gr_dirt_1", "gr_dirt_2", "gr_dirt", "gr_dirt_edge"],
         [_shift(*GREEN, add_hue=18, sat=1.1, val=0.95),
          _shift(*BROWN, add_hue=-14, sat=1.15, val=0.92, min_sat=0.15)]),
        (["gr_grass"], [_shift(*GREEN, add_hue=22, sat=1.12, val=0.92)]),
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
                save(_recolour(img, rules), "%s__%s" % (name, suffix))


if __name__ == "__main__":
    print("ports:")
    gen_flags()
    gen_themes()
