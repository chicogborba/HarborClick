"""The chart on the clipboard: a hand-authored pixel world map.

The route board used to draw the world at runtime as filled polygons — a dozen
smooth outlines scaled to whatever height the panel happened to be. Polygons do
not become pixel art by being drawn small; they become *blurry* pixel art, which
is why the chart looked like a diagram in a game made of sprites.

So the world is authored here instead, once, at a fixed resolution, and the
board blits it at an integer scale like every other sprite in the project.

**How the coastline is written.** Not as ASCII art — forty-eight rows of
ninety-six characters cannot be proofread. Each row of the grid is a latitude
band and lists the *column spans* that are land, so every entry can be checked
against a real coordinate:

    column = (longitude + 180) / 3.75      row = (90 - latitude) / 3.75

That makes the data reviewable ("Rotterdam is 4E/52N, so col 49 row 10 must be
land") and keeps the map honest about where the routes in `RouteDB` actually go.

**What makes it read as a chart and not a texture.** Four things, in order of
how much they matter: a lit north-west coast edge and a dark south-east one, so
continents have a light direction like everything else in the game; three
dithered depth bands stepping out from every shore, which is what sells water on
a printed atlas; ice at both poles with a ragged edge rather than a straight
line; and dry/temperate/boreal banding across the land so the continents are not
one flat green.
"""
import random

from common import new_img, px, rect, save

# 3.75 degrees per cell. Small enough to keep Britain, Japan and the Gulf of
# Mexico; large enough that the whole world is proofreadable by hand.
W, H = 96, 48
DEG = 3.75

# --- water -------------------------------------------------------------------
ABYSS = (18, 44, 68, 255)
DEEP = (24, 58, 88, 255)
SEA = (32, 76, 108, 255)
SHELF = (46, 104, 130, 255)
SURF = (86, 152, 166, 255)

# --- land: four climate bands, each with a lit and a shaded step --------------
ICE = (214, 228, 232, 255)
ICE_D = (170, 192, 206, 255)
BOREAL = (78, 104, 82, 255)
BOREAL_L = (98, 124, 96, 255)
TEMPERATE = (110, 138, 84, 255)
TEMPERATE_L = (136, 162, 100, 255)
DRY = (166, 148, 92, 255)
DRY_L = (192, 174, 114, 255)
COAST_DARK = (44, 60, 56, 255)
GRID = (120, 170, 176, 40)

# --- the world ----------------------------------------------------------------
# row -> spans of land columns, inclusive. See the module docstring for the
# coordinate conversion; every span below was placed from a real lat/long.
LAND = {
    2: [(27, 29), (40, 43)],                                    # Ellesmere, N Greenland
    3: [(24, 29), (36, 43), (52, 54)],                          # + Svalbard
    4: [(13, 29), (33, 43), (62, 63), (64, 95)],                # N Canada, Greenland, Siberia
    5: [(4, 11), (12, 29), (35, 41), (52, 56), (59, 95)],       # + Alaska, Scandinavia
    6: [(3, 10), (11, 31), (42, 42), (51, 56), (57, 95)],       # + Iceland
    7: [(4, 10), (11, 32), (42, 44), (49, 56), (57, 95)],
    8: [(5, 9), (12, 33), (49, 56), (57, 95)],
    9: [(13, 32), (45, 47), (50, 56), (57, 95)],                # + British Isles
    10: [(13, 33), (45, 47), (48, 56), (57, 95)],
    11: [(14, 32), (46, 47), (48, 56), (57, 95)],
    12: [(14, 29), (45, 49), (49, 56), (57, 86)],               # + Iberia, Hokkaido
    13: [(14, 29), (45, 58), (59, 85)],
    14: [(15, 28), (45, 57), (58, 82), (84, 85)],               # + Honshu
    15: [(16, 28), (45, 56), (57, 64), (64, 80), (83, 85)],
    16: [(17, 26), (44, 57), (57, 62), (64, 80), (82, 83)],
    17: [(18, 22), (26, 26), (44, 57), (57, 63), (66, 72), (73, 80)],  # + Florida
    18: [(19, 22), (25, 27), (43, 58), (58, 63), (66, 73), (73, 80)],  # + Cuba
    19: [(20, 22), (25, 27), (43, 58), (59, 62), (67, 73), (73, 77)],
    20: [(23, 25), (43, 59), (68, 73), (74, 77), (80, 81)],     # + Philippines
    21: [(26, 31), (44, 60), (69, 69), (74, 76), (80, 81)],     # + Sri Lanka
    22: [(27, 31), (45, 60), (75, 76), (81, 82)],
    23: [(28, 34), (46, 60), (74, 79)],                         # + Sumatra/Borneo
    24: [(28, 35), (50, 59), (74, 79)],
    25: [(28, 37), (51, 58), (75, 80)],
    26: [(28, 38), (51, 58), (76, 79), (83, 88)],               # + New Guinea
    27: [(29, 38), (51, 58), (76, 79), (84, 88)],
    28: [(29, 37), (51, 58), (80, 86)],                         # + N Australia
    29: [(29, 37), (51, 58), (78, 87)],
    30: [(30, 37), (51, 57), (78, 88)],
    31: [(31, 36), (52, 56), (78, 88)],
    32: [(29, 34), (52, 56), (78, 88)],
    33: [(28, 33), (52, 55), (79, 88)],
    34: [(28, 32), (79, 87), (93, 95)],                         # + New Zealand
    35: [(28, 31), (86, 87), (93, 94)],                         # + Tasmania
    36: [(28, 30), (92, 94)],
    37: [(28, 30)],
    38: [(28, 30)],
}

# Antarctica is a cap rather than a coastline: at this scale its real outline is
# a ring of noise, and a clean ice shelf reads better on a chart.
ANTARCTIC_ROW = 43
ARCTIC_ROW = 2


def _land_grid() -> list[list[bool]]:
    grid = [[False] * W for _ in range(H)]
    for row, spans in LAND.items():
        for c0, c1 in spans:
            for c in range(max(0, c0), min(W - 1, c1) + 1):
                grid[row][c] = True
    for row in range(ANTARCTIC_ROW, H):
        for c in range(W):
            grid[row][c] = True
    return grid


def _distance(grid: list[list[bool]], from_land: bool) -> list[list[int]]:
    """Multi-source BFS from every coast cell.

    Run outwards it gives the depth bands, which is what makes the shelf hug
    every bay and strait instead of being a rectangle. Run inwards it gives how
    far inland a cell is, which is where the interiors and the ranges come from —
    a continent that is one flat colour reads as a shape, not as land.
    """
    far = 99
    seed = (lambda v: v) if from_land else (lambda v: not v)
    dist = [[0 if seed(grid[y][x]) else far for x in range(W)] for y in range(H)]
    frontier = [(x, y) for y in range(H) for x in range(W) if seed(grid[y][x])]
    step = 0
    while frontier:
        step += 1
        nxt = []
        for x, y in frontier:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                # The map wraps east to west: the Pacific is one ocean.
                nx, ny = (x + dx) % W, y + dy
                if ny < 0 or ny >= H or dist[ny][nx] != far:
                    continue
                dist[ny][nx] = step
                nxt.append((nx, ny))
        frontier = nxt
    return dist


def _shade(colour: tuple) -> tuple:
    r, g, b, a = colour
    return (max(0, r - 22), max(0, g - 20), max(0, b - 16), a)


def _climate(row: int, rng: random.Random) -> tuple:
    """Land colour by latitude, with the band edges roughed up a pixel."""
    jitter = rng.choice((-1, 0, 0, 1))
    band = row + jitter
    if band <= 4 or band >= 42:
        return ICE, ICE_D
    if band <= 8 or band >= 36:
        return BOREAL_L, BOREAL
    # The two dry belts sit either side of the equator, not on it.
    if 15 <= band <= 19 or 28 <= band <= 31:
        return DRY_L, DRY
    return TEMPERATE_L, TEMPERATE


def build() -> "Image.Image":
    rng = random.Random(20260805)
    img = new_img(W, H)
    grid = _land_grid()
    dist = _distance(grid, from_land=True)
    inland = _distance(grid, from_land=False)

    for y in range(H):
        for x in range(W):
            if grid[y][x]:
                continue
            d = dist[y][x]
            if d == 1:
                colour = SHELF
            elif d <= 3:
                colour = SEA
            elif d <= 6:
                colour = DEEP
            else:
                colour = ABYSS
            px(img, x, y, colour)

    # Dithered step between each depth band. One checkerboard row along the
    # boundary is the whole trick that makes flat bands read as a printed chart.
    for y in range(H):
        for x in range(W):
            if grid[y][x]:
                continue
            d = dist[y][x]
            if d in (2, 4, 7) and (x + y) % 2 == 0:
                px(img, x, y, {2: SHELF, 4: SEA, 7: DEEP}[d])

    # Graticule, under the land so continents stay clean.
    for gx in range(0, W, 12):
        for y in range(0, H, 2):
            if not grid[y][gx]:
                px(img, gx, y, GRID)
    for gy in range(0, H, 8):
        for x in range(0, W, 2):
            if not grid[gy][x]:
                px(img, x, gy, GRID)

    for y in range(H):
        for x in range(W):
            if not grid[y][x]:
                continue
            light, shade = _climate(y, rng)
            north_west = (y > 0 and not grid[y - 1][x]) \
                or (x > 0 and not grid[y][x - 1])
            south_east = (y < H - 1 and not grid[y + 1][x]) \
                or (x < W - 1 and not grid[y][x + 1])
            if south_east:
                px(img, x, y, COAST_DARK)
                continue
            if north_west:
                px(img, x, y, light)
                continue
            depth = inland[y][x]
            # Deep interior sits a step darker than the seaboard, and the very
            # deepest cells carry a range. Uneven on purpose: a regular pattern
            # here reads as hatching across the whole continent.
            if depth >= 4 and rng.random() < 0.55:
                px(img, x, y, _shade(shade))
            elif depth >= 2 and rng.random() < 0.45:
                px(img, x, y, shade)
            else:
                px(img, x, y, light)

    # A ring of surf on the water side of every coast, broken so it reads as
    # spray rather than as an outline.
    for y in range(H):
        for x in range(W):
            if not grid[y][x] and dist[y][x] == 1 and (x * 3 + y) % 3 != 0:
                px(img, x, y, SURF)

    return img


def main() -> None:
    save(build(), "map_world")


if __name__ == "__main__":
    main()
