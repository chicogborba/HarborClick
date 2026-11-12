"""The chart on the ports board: the world, at the interface's own pixel density.

Two earlier charts are worth remembering for what was wrong with them. The
first drew the continents at runtime as filled polygons scaled to the panel:
blurry. The second authored a 96x48 land grid by hand and blew it up three
times: sharp, but a world in which Europe is nine cells wide has no
Mediterranean, no Red Sea and no Japan worth the name, and every pixel of it
was three times the size of the type beside it.

This one keeps what each got right. The coastlines are **polygons in real
longitude and latitude** — reviewable ("Santos is 46W 24S, is that land?") and
detailed enough to carry the seas a shipping game is about — and they are
**rasterised here, once, with no anti-aliasing**, onto a 288x144 sprite the
board blits 1:1. 0.8 px per degree: the Strait of Gibraltar is a pixel, which
is what it should be.

Painted flat: three depth bands stepping out from every shore, a climate tone
per (wandering) latitude belt, a lit north-west coast and an inked south-east
one, a dotted 30-degree graticule out in deep water. No dither, no speckle —
ports and lanes are drawn over this, and they need a calm page.

`RouteDB` and `PortDB` pin things in the map's 0..1 space:
    x = (lon + 180) / 360        y = (90 - lat) / 180
"""
import math

from PIL import Image, ImageDraw

from common import new_img, px, save

MAP_W, MAP_H = 288, 144

SEA_DEEP = (30, 66, 100, 255)
SEA_MID = (38, 86, 122, 255)
SEA_SHELF = (58, 118, 148, 255)
SEA_GRID = (44, 84, 116, 255)
LAND_TONES = (
    # max |latitude|, base, lit
    (12.0, (92, 142, 88, 255), (118, 166, 104, 255)),       # equatorial
    (30.0, (184, 166, 110, 255), (208, 190, 132, 255)),     # dry belts
    (52.0, (124, 154, 96, 255), (148, 176, 112, 255)),      # temperate
    (67.0, (86, 114, 90, 255), (106, 134, 104, 255)),       # boreal
    (90.0, (218, 230, 234, 255), (240, 246, 248, 255)),     # ice
)
# Never blue-dominant: the route suite tells land from water by that, and an
# inked shore that read as sea put every coastal pin "in open water".
COAST_INK = (48, 52, 46, 255)
ICE = LAND_TONES[-1]

# --- the world: (longitude, latitude) rings ----------------------------------
LAND = [
    # North and Central America
    [(-168, 66), (-162, 70), (-156, 71), (-141, 70), (-128, 70), (-115, 69),
     (-108, 68), (-96, 69), (-94, 72), (-86, 70), (-82, 67), (-88, 64),
     (-94, 61), (-93, 58), (-85, 55), (-80, 52), (-79, 55), (-77, 58),
     (-78, 62), (-72, 62), (-65, 60), (-61, 56), (-56, 52), (-60, 50),
     (-66, 50), (-65, 47), (-61, 46), (-66, 44), (-70, 43), (-71, 41),
     (-74, 40), (-76, 37), (-76, 35), (-80, 32), (-81, 29), (-80, 26),
     (-82, 26), (-83, 29), (-85, 30), (-89, 30), (-94, 29), (-97, 27),
     (-98, 22), (-96, 19), (-94, 18), (-91, 19), (-90, 21), (-87, 21),
     (-88, 17), (-84, 15), (-83, 11), (-80, 9), (-77, 8), (-80, 7), (-83, 8),
     (-86, 11), (-88, 13), (-92, 14), (-95, 16), (-100, 17), (-105, 20),
     (-106, 23), (-109, 26), (-112, 30), (-113, 31), (-114, 29), (-111, 24),
     (-110, 23), (-112, 25), (-115, 29), (-117, 33), (-120, 34), (-122, 37),
     (-124, 40), (-124, 46), (-123, 48), (-127, 51), (-131, 55), (-136, 58),
     (-141, 60), (-148, 60), (-152, 58), (-158, 56), (-162, 55), (-160, 58),
     (-164, 60), (-166, 63), (-161, 64)],
    # Greenland, Baffin, the high Arctic islands
    [(-73, 78), (-60, 82), (-35, 83), (-20, 81), (-19, 75), (-23, 70),
     (-33, 67), (-41, 63), (-45, 60), (-50, 62), (-53, 67), (-56, 72),
     (-66, 76)],
    [(-80, 73), (-72, 71), (-62, 66), (-66, 62), (-74, 64), (-80, 68),
     (-88, 71)],
    [(-120, 74), (-95, 75), (-85, 78), (-70, 82), (-90, 82), (-110, 78)],
    # Caribbean
    [(-85, 22), (-80, 23), (-75, 20), (-78, 20)],
    [(-74, 20), (-69, 19.5), (-68.5, 18.3), (-74, 18.2)],
    # South America
    [(-77, 8), (-72, 12), (-68, 11), (-62, 10.5), (-58, 7), (-52, 5),
     (-50, 1), (-48, -1), (-44, -2.5), (-40, -3), (-35, -5.5), (-35, -9),
     (-38, -13), (-39, -18), (-41, -22), (-45, -24), (-48, -26), (-49, -29),
     (-52, -33), (-55, -35), (-57, -36), (-57, -38), (-62, -39), (-65, -41),
     (-64, -43), (-66, -45), (-68, -50), (-69, -52), (-67, -55), (-71, -54),
     (-74, -51), (-75, -46), (-73, -42), (-73, -37), (-71, -32), (-70, -25),
     (-70, -18), (-75, -15), (-77, -12), (-80, -6), (-81, -4), (-80, -2),
     (-80, 1), (-78, 2), (-77, 5)],
    # Africa and Madagascar
    [(-17, 21), (-16, 24), (-13, 28), (-10, 30), (-9, 33), (-6, 35.8),
     (-2, 35), (3, 37), (10, 37.2), (11, 34), (15, 32.5), (20, 31),
     (20, 32.8), (25, 32), (30, 31.3), (33, 31), (34, 28), (36, 24),
     (37, 20), (39, 16), (42, 12), (44, 11), (51, 12), (50, 8), (47, 4),
     (42, -1), (40, -5), (39, -9), (40.5, -15), (37, -18), (35, -21),
     (35.5, -24), (33, -26), (31, -30), (27, -33.8), (22, -34.3),
     (18.3, -34.3), (17.5, -30), (15, -26), (12, -18), (13.5, -12), (12, -6),
     (9, -1), (9.5, 3.5), (6, 4.5), (2, 6.2), (-3, 5), (-7.5, 4.5), (-11, 7),
     (-15, 10.5), (-17, 14.7), (-16, 18)],
    [(49.3, -12), (50.5, -16), (47.5, -25), (44, -25), (43.5, -20),
     (46, -16)],
    # Eurasia, clockwise from Portugal. The Black Sea is an inlet behind the
    # Bosphorus, the Red Sea and the Gulf are the gaps between this ring and
    # Africa's and its own Arabian shore.
    [(-9, 37), (-9, 43), (-2, 43.5), (-1.5, 46), (-4.5, 48.5), (-1.5, 49),
     (2, 51), (4, 52), (6, 53.5), (8.5, 54), (8.3, 57), (10.5, 57.5),
     (10.5, 54.5), (14, 54), (19, 54.5), (21, 57), (24, 57.5), (23.5, 59.5),
     (28, 59.7), (30, 60), (23, 60), (21.5, 61), (25, 65), (22, 65.8),
     (17.5, 62), (18.5, 60), (16.5, 56.5), (13, 55.5), (11, 59), (7, 58),
     (5, 60), (5, 62), (10, 64.5), (14, 68), (19, 70), (25, 71), (31, 70),
     (41, 67), (38, 64.5), (34, 66), (40, 68), (44, 66.5), (47, 67),
     (54, 68.5), (60, 69), (68, 69), (68, 73), (73, 72), (80, 73.5),
     (88, 75.5), (100, 77.5), (112, 76.5), (113, 74), (127, 73), (132, 71),
     (140, 72.5), (150, 71), (160, 70), (170, 69.5), (180, 69), (180, 65),
     (178, 62.5), (170, 60), (163, 58), (162, 55), (156.5, 51), (155.5, 56),
     (156.5, 59), (163, 61.5), (155, 59.3), (143, 59.3), (135, 55), (140, 53),
     (141, 48), (138, 46), (133, 43), (130, 42.5), (127.5, 39.5), (129.5, 37),
     (126.5, 34.5), (126, 37.5), (124.5, 40), (121.5, 39), (122, 37),
     (119.5, 35), (121.5, 31.5), (121.5, 28), (118, 24.5), (113.5, 22.5),
     (110, 21), (108, 21.5), (106, 19), (108.5, 15.5), (109.3, 12),
     (107, 10.5), (105, 8.7), (105, 10.3), (102.5, 12), (100.5, 13.5),
     (99.5, 10), (103.5, 2), (103.5, 1.3), (101, 3), (98.5, 8), (98.5, 12),
     (97.5, 16.5), (94.5, 16), (94, 19), (91.5, 22.5), (89, 22), (86.5, 20),
     (82, 16.5), (80, 13.5), (80, 10), (77.5, 8), (76, 11), (73, 18),
     (72.5, 21), (70, 21), (69, 22.5), (67, 25), (61.5, 25.2), (57, 25.8),
     (56.5, 27), (51.5, 28), (50, 30), (48.5, 29.5), (50.5, 25.5),
     (51.5, 24.2), (54, 24), (56.3, 26), (58.5, 23.5), (59.8, 22.5),
     (57.5, 19), (55, 17), (52, 16), (45, 12.7), (43.3, 13), (42.5, 16.5),
     (39, 21.5), (35, 28), (34.5, 29.5), (34.3, 31.3), (35.8, 35), (36, 36.7),
     (30.5, 36.3), (27.2, 37), (26.2, 39.5), (27, 40.5), (29, 41),
     (31.5, 41.2), (36, 41.7), (41.5, 41.5), (41, 43), (37, 45), (39, 47),
     (35, 46), (33.5, 44.5), (30.5, 46.5), (28.5, 44), (28, 41.5), (26, 40.7),
     (24, 40.8), (23.5, 38), (22.5, 36.5), (21, 39), (19.3, 41.8), (16, 43.5),
     (13.5, 45.6), (12.3, 45), (13.5, 43.5), (16, 41.8), (18.5, 40),
     (16.5, 39.5), (16, 38), (15.6, 40), (12.5, 41.5), (10.5, 43),
     (8.8, 44.4), (6, 43.1), (3, 43.3), (3.2, 41.8), (0.5, 40.5),
     (-0.3, 38.7), (-2, 36.7), (-5.3, 36.1), (-7, 37)],
    # The islands of Europe
    [(-5.5, 50), (1.3, 51.2), (1.7, 52.8), (0, 53.5), (-1.5, 55.5),
     (-2, 57.5), (-4, 58.6), (-6, 57.5), (-5, 55), (-3, 54), (-4.5, 53.3),
     (-5, 51.8), (-3, 51.4)],
    [(-10, 52), (-6, 52.2), (-6, 55), (-8, 55.3), (-10, 54)],
    [(-24, 65.5), (-22, 64), (-14, 64.5), (-14.5, 66.3), (-22, 66.5)],
    [(12.5, 38), (15.5, 38.2), (15, 36.7)],
    [(8.3, 41), (9.7, 41), (9.5, 39), (8.4, 39)],
    [(52, 71), (57, 71), (68, 76.5), (60, 76)],
    [(11, 79.5), (20, 80.5), (26, 79.5), (18, 77)],
    # East and South-East Asia
    [(130, 33), (131, 31.3), (132, 33.5), (135, 33.7), (137, 34.7),
     (140, 35.3), (141, 38), (141.5, 41), (140, 41), (139.8, 38.5), (137, 37),
     (133, 35.5)],
    [(140, 42), (141.5, 45.4), (145.3, 43.5), (143, 42)],
    [(142, 54), (143.5, 50), (143, 46), (142, 47.5)],
    [(121, 25.2), (122, 24.5), (120.8, 22), (120.1, 23.5)],
    [(120.5, 18.5), (122.3, 18.3), (122, 14), (124, 13), (126.5, 7), (125, 6),
     (122, 9), (120, 14)],
    [(95.5, 5.5), (98, 4), (103.5, -1), (106, -5.8), (104, -5.8), (100, -1)],
    [(105.5, -6.5), (108.5, -6.7), (114.5, -7.5), (114.3, -8.6), (108, -7.8)],
    [(109, 1.5), (113, 3), (117, 7), (119, 5), (117.5, 1), (116, -4),
     (110.5, -3)],
    [(119.5, -5.5), (120.5, 0.5), (125, 1.5), (121.5, -1), (123, -5),
     (120.5, -3)],
    [(131, -1), (138, -1.5), (145, -4.5), (150.5, -10.5), (146, -8.5),
     (141, -9), (138, -8), (133, -4)],
    [(80, 9.8), (81.8, 7.5), (80.5, 6), (79.8, 8)],
    # Oceania
    [(114, -22), (116, -20.5), (121, -19.5), (123, -17), (126, -14),
     (129.5, -15), (131, -12.2), (136, -12), (136, -15), (139, -17.5),
     (141, -17), (142.5, -10.8), (145.5, -15), (146.5, -19), (150, -22.5),
     (153, -25.5), (153.5, -28.5), (151, -34), (150, -37.3), (147, -38.5),
     (144, -38), (140.5, -38), (138, -35.5), (137.5, -33), (136, -35),
     (134, -33), (131, -31.5), (126, -32.3), (123.5, -34), (118, -35),
     (115, -34.3), (115.7, -31.5), (113.5, -26)],
    [(145, -40.8), (148.3, -41), (147.5, -43.5), (146, -43.5)],
    [(173, -34.5), (175.5, -36.5), (178.3, -37.7), (177, -39.5), (175, -41.5),
     (174.5, -39)],
    [(172.7, -40.6), (174, -41.8), (171, -44.5), (168.5, -46.5),
     (166.5, -45.8), (170, -43)],
]
# Cut back out of the land after it is filled.
LAKES = [
    [(47, 45), (53, 46.5), (53.5, 42), (54, 37.5), (50, 37), (49, 40.5),
     (47, 43)],                                               # the Caspian
]
ANTARCTIC_LAT = -66.0


def _xy(lon, lat):
    return ((lon + 180.0) * MAP_W / 360.0, (90.0 - lat) * MAP_H / 180.0)


def _land_mask():
    """True where there is land. Filled polygons, no anti-aliasing."""
    mask = Image.new("1", (MAP_W, MAP_H), 0)
    draw = ImageDraw.Draw(mask)
    for ring in LAND:
        draw.polygon([_xy(lon, lat) for lon, lat in ring], fill=1)
    for ring in LAKES:
        draw.polygon([_xy(lon, lat) for lon, lat in ring], fill=0)
    grid = [[bool(mask.getpixel((c, r))) for c in range(MAP_W)]
            for r in range(MAP_H)]
    # Antarctica is a shelf rather than a coastline: at this scale its real
    # outline is a ring of noise, and a ragged ice edge reads better.
    for c in range(MAP_W):
        edge = ANTARCTIC_LAT + 2.5 * math.sin(c * 0.11) + 1.5 * math.sin(c * 0.37)
        first = int((90.0 - edge) * MAP_H / 180.0)
        for r in range(first, MAP_H):
            grid[r][c] = True
    return grid


def _sea_distance(land, limit):
    """Steps from the nearest land, capped at `limit`, wrapping east-west."""
    dist = [[0 if land[r][c] else limit for c in range(MAP_W)]
            for r in range(MAP_H)]
    frontier = [(r, c) for r in range(MAP_H) for c in range(MAP_W)
                if land[r][c]]
    step = 0
    while frontier and step < limit:
        step += 1
        nxt = []
        for r, c in frontier:
            for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                rr, cc = r + dr, (c + dc) % MAP_W
                if 0 <= rr < MAP_H and dist[rr][cc] > step \
                        and not land[rr][cc]:
                    dist[rr][cc] = step
                    nxt.append((rr, cc))
        frontier = nxt
    return dist


def is_land(lon, lat):
    """For the port and lane tables to check a pin against the coast."""
    x, y = _xy(lon, lat)
    return _land_mask()[min(MAP_H - 1, int(y))][min(MAP_W - 1, int(x))]


def build():
    land = _land_mask()
    img = new_img(MAP_W, MAP_H)
    dist = _sea_distance(land, 9)
    for r in range(MAP_H):
        for c in range(MAP_W):
            if land[r][c]:
                continue
            d = dist[r][c]
            tone = SEA_SHELF if d <= 1 else (SEA_MID if d <= 4 else SEA_DEEP)
            # the graticule: every 30 degrees, dotted, only out in deep water
            if d > 4 and (c % (MAP_W // 12) == 0 or r % (MAP_H // 6) == 0) \
                    and (c + r) % 2 == 0:
                tone = SEA_GRID
            px(img, c, r, tone)
    for r in range(MAP_H):
        true_lat = 90.0 - (r + 0.5) * 180.0 / MAP_H
        for c in range(MAP_W):
            if not land[r][c]:
                continue
            # Climate follows latitude, but not along a ruler: the boundary
            # wanders a few degrees with longitude, so the belts read as
            # country rather than as stripes on a flag.
            lat = abs(true_lat) + 4.0 * math.sin(c * 0.085) \
                + 2.5 * math.sin(c * 0.21 + r * 0.13)
            base, lit = ICE[1], ICE[2]
            if true_lat > -60.0:
                for limit, tone, tone_lit in LAND_TONES:
                    if lat <= limit:
                        base, lit = tone, tone_lit
                        break

            def sea(dr, dc):
                rr = r + dr
                return 0 <= rr < MAP_H and not land[rr][(c + dc) % MAP_W]

            if sea(1, 0) or sea(0, 1):
                px(img, c, r, COAST_INK)        # the shaded south-east shore
            elif sea(-1, 0) or sea(0, -1):
                px(img, c, r, lit)              # the lit north-west shore
            else:
                px(img, c, r, base)
    return img


# --- the countries the game is played in ------------------------------------
# `map_countries.png` is a mask, not a picture: red channel = 60 x the index
# below (0 is "no country we play in"). The globe shader tints the active port's
# country, outlines the other two and draws their borders, so the player can
# find Brazil, the United States and China on a planet with no other labels.
COUNTRIES = [
    ("santos", [  # Brazil
        (-60, 5.2), (-51, 4), (-50, 0), (-44, -2.5), (-35, -5.5), (-35, -9),
        (-39, -13), (-39, -18), (-41, -22), (-45, -24), (-48.5, -26),
        (-49, -29), (-53.4, -33.7), (-57.6, -30.2), (-55.5, -27.5),
        (-54.6, -25.6), (-58, -24), (-58, -20), (-60, -16), (-65, -11),
        (-70, -11), (-73.9, -7.4), (-72, -4), (-70, -2), (-69.5, 1), (-67, 2),
        (-63.5, 3.9)]),
    ("long_beach", [  # the contiguous United States
        (-124.7, 48.4), (-123, 49), (-95, 49), (-89, 48), (-84, 46.5),
        (-82.5, 45), (-83, 42), (-79, 43), (-76, 44), (-74.9, 45), (-71, 45),
        (-67, 45), (-67, 44.5), (-70, 43), (-70.5, 41.5), (-74, 40.5),
        (-76, 37), (-75.5, 35.5), (-81, 31.5), (-80, 26), (-81.5, 25.2),
        (-83, 29), (-85.5, 30), (-89.5, 30.2), (-94, 29.5), (-97.2, 26),
        (-99.5, 27.5), (-101.4, 29.8), (-103, 29), (-106.5, 31.8),
        (-108.2, 31.3), (-111, 31.3), (-114.8, 32.5), (-117.1, 32.5),
        (-120.5, 34.5), (-122.5, 37.5), (-124, 40.5)]),
    ("long_beach", [  # Alaska
        (-168, 65.5), (-162, 70), (-156, 71.3), (-141, 69.6), (-141, 60),
        (-148, 60), (-152, 58), (-158, 56.5), (-162, 55), (-160, 58),
        (-164.5, 60.5), (-166, 63)]),
    ("shanghai", [  # China
        (73.6, 39.5), (75, 37), (78.5, 35.5), (79.5, 32.5), (81, 30),
        (85, 28.2), (88, 27.9), (92, 27.8), (97, 28.3), (98.5, 25), (100, 22),
        (101.5, 21.3), (106.5, 22.5), (108, 21.6), (110.4, 21), (111.5, 21.6),
        (113.5, 22.4), (117, 23.5), (119, 25.5), (120.5, 28), (121.9, 30.8),
        (120.5, 32.5), (119.3, 35), (122.5, 37), (119, 37.2), (117.6, 38.8),
        (121.5, 40.8), (124.3, 40), (126, 41.5), (128.5, 42.5), (130.5, 42.6),
        (131.3, 45), (134.5, 48), (130.6, 48.9), (127.5, 49.8), (125.7, 53),
        (122, 53.4), (120, 52.5), (117.8, 49.5), (116, 46.6), (111.8, 45.1),
        (106, 42.4), (101, 42.6), (96.3, 42.7), (95.3, 44.3), (90.9, 45.9),
        (90, 47.8), (87.8, 49.2), (85.4, 47), (82.5, 45.4), (80.2, 42.2),
        (76, 40.5)]),
]
COUNTRY_INDEX = {"santos": 1, "long_beach": 2, "shanghai": 3}


def build_countries():
    land = _land_mask()
    mask = Image.new("RGBA", (MAP_W, MAP_H), (0, 0, 0, 255))
    draw = ImageDraw.Draw(mask)
    for port, ring in COUNTRIES:
        value = 60 * COUNTRY_INDEX[port]
        draw.polygon([_xy(lon, lat) for lon, lat in ring], fill=(value, 0, 0, 255))
    # A country never spills into the sea the coastline drew.
    out = mask.load()
    for r in range(MAP_H):
        for c in range(MAP_W):
            if not land[r][c]:
                out[c, r] = (0, 0, 0, 255)
    return mask


def main() -> None:
    save(build(), "map_world")
    save(build_countries(), "map_countries")


if __name__ == "__main__":
    main()
