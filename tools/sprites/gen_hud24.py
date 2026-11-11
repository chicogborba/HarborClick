"""The console's own glyphs: 24x24, drawn for the size they are shown at.

The command rail used to blow the 12px utility icons up 2x, which turned a
gantry crane into a red-and-yellow lump and the globe into scattered noise.
These are native 24px, one light source (upper left), hue-shifted ramps and a
1px navy selout, so each one reads as a silhouette first:

    0 SHOP      a container hanging from a crane hook
    1 ROUTES    a globe with two continents and a meridian
    2 LOGBOOK   a bound log with a ribbon and a brass anchor
    3 SETTINGS  an eight-tooth gear

Critiqued against the pixel-art-studio checklist (silhouette at 1x, clusters of
3+ px, no pillow shading, hue-shifted ramps, uniform outline).
"""
import math

from common import new_img, rect, hline, vline, px, save, sheet

OUT = (16, 22, 34, 255)

# Container: rust-orange, warm highlight, cool shadow.
BOX = [(92, 34, 30, 255), (150, 62, 38, 255), (206, 104, 48, 255),
       (238, 150, 70, 255), (255, 200, 120, 255)]
STEEL = [(44, 50, 66, 255), (84, 92, 112, 255), (138, 146, 164, 255),
         (190, 198, 212, 255), (236, 240, 246, 255)]
SEA = [(18, 40, 86, 255), (30, 74, 140, 255), (52, 118, 190, 255),
       (98, 168, 222, 255), (170, 214, 240, 255)]
LAND = [(34, 78, 50, 255), (60, 122, 66, 255), (110, 170, 84, 255),
        (176, 210, 116, 255)]
LEATHER = [(56, 24, 30, 255), (100, 40, 44, 255), (148, 60, 54, 255),
           (190, 92, 70, 255)]
PAGE = [(176, 160, 132, 255), (224, 212, 186, 255), (248, 240, 220, 255)]
BRASS = [(110, 70, 24, 255), (176, 122, 40, 255), (232, 178, 64, 255),
         (255, 226, 132, 255)]
RIBBON = [(120, 24, 40, 255), (196, 48, 60, 255)]


def selout(img, color=OUT):
    """1px outline outside every opaque pixel (4-neighbour)."""
    w, h = img.size
    src = img.copy().load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3]:
                    img.putpixel((x, y), color)
                    break
    return img


def shop():
    img = new_img(24, 24)
    # hook block and hook
    rect(img, 9, 1, 6, 3, STEEL[2])
    hline(img, 9, 1, 6, STEEL[3])
    hline(img, 9, 3, 6, STEEL[1])
    rect(img, 11, 4, 2, 2, STEEL[2])
    px(img, 11, 4, STEEL[3])
    # the hook's curl
    for x, y, c in ((10, 6, STEEL[3]), (11, 6, STEEL[2]), (12, 6, STEEL[2]),
                    (13, 6, STEEL[1]), (10, 7, STEEL[2]), (13, 7, STEEL[1])):
        px(img, x, y, c)
    # slings from the hook to the box's corner castings
    for i in range(5):
        px(img, 10 - i * 2, 8 + i, STEEL[3] if i < 2 else STEEL[2])
        px(img, 9 - i * 2, 8 + i, STEEL[1])
        px(img, 13 + i * 2, 8 + i, STEEL[2])
        px(img, 14 + i * 2, 8 + i, STEEL[1])
    # the container, 3/4 top: a lit roof strip then the corrugated side
    rect(img, 1, 12, 22, 10, BOX[2])
    hline(img, 1, 12, 22, BOX[4])
    hline(img, 1, 13, 22, BOX[3])
    for x in range(3, 22, 3):
        vline(img, x, 14, 7, BOX[1])
        vline(img, x + 1, 14, 7, BOX[3])
    hline(img, 1, 21, 22, BOX[0])
    # corner castings
    for cx in (1, 21):
        rect(img, cx, 12, 2, 2, BOX[4] if cx == 1 else BOX[3])
        rect(img, cx, 20, 2, 2, BOX[0])
    return selout(img)


def routes():
    img = new_img(24, 24)
    c = 11.5
    for y in range(24):
        for x in range(24):
            r = math.hypot(x - c, y - c)
            if r > 10.6:
                continue
            # light from the upper left: a ramp across the sphere, no pillow
            lx = (x - c) / 10.6 + (y - c) / 10.6
            tone = 3 if lx < -0.7 else 2 if lx < 0.2 else 1 if lx < 0.95 else 0
            px(img, x, y, SEA[tone])
    # continents as solid clusters (two masses, one island)
    americas = [(6, 5, 3), (5, 6, 5), (5, 7, 5), (6, 8, 4), (7, 9, 3),
                (8, 10, 3), (9, 11, 3), (9, 12, 4), (9, 13, 4), (10, 14, 3),
                (10, 15, 2), (10, 16, 2)]
    afro = [(14, 6, 4), (13, 7, 6), (13, 8, 7), (14, 9, 6), (14, 10, 5),
            (15, 11, 5), (15, 12, 4), (16, 13, 4), (16, 14, 3), (16, 15, 2)]
    for shape in (americas, afro):
        for x, y, w in shape:
            for i in range(w):
                lx = (x + i - c) / 10.6 + (y - c) / 10.6
                px(img, x + i, y, LAND[3] if lx < -0.6 else LAND[2]
                   if lx < 0.4 else LAND[1])
    rect(img, 18, 16, 2, 2, LAND[1])
    # a meridian and the equator, faint
    for y in range(3, 21):
        if img.getpixel((12, y))[3] and img.getpixel((12, y)) in SEA:
            px(img, 12, y, SEA[min(4, SEA.index(img.getpixel((12, y))) + 1)])
    # specular glint
    rect(img, 5, 5, 2, 1, SEA[4])
    px(img, 5, 6, SEA[4])
    return selout(img)


def logbook():
    img = new_img(24, 24)
    # page block (right and bottom edge), then the cover over it
    rect(img, 4, 3, 17, 18, PAGE[1])
    for y in range(5, 20, 2):
        hline(img, 19, y, 2, PAGE[0])
    hline(img, 5, 20, 15, PAGE[0])
    rect(img, 3, 2, 16, 18, LEATHER[2])
    hline(img, 3, 2, 16, LEATHER[3])
    vline(img, 3, 2, 18, LEATHER[3])
    hline(img, 3, 19, 16, LEATHER[0])
    # spine band
    rect(img, 4, 2, 3, 18, LEATHER[1])
    vline(img, 4, 2, 18, LEATHER[2])
    for y in (5, 16):
        hline(img, 4, y, 3, BRASS[1])
    # brass anchor on the cover
    vline(img, 12, 6, 9, BRASS[2])
    hline(img, 10, 7, 5, BRASS[2])
    rect(img, 11, 5, 3, 2, BRASS[3])
    px(img, 12, 5, BRASS[1])
    hline(img, 9, 14, 7, BRASS[2])
    px(img, 9, 13, BRASS[3])
    px(img, 15, 13, BRASS[1])
    px(img, 12, 15, BRASS[1])
    # ribbon hanging out of the bottom
    vline(img, 16, 20, 3, RIBBON[1])
    vline(img, 17, 20, 2, RIBBON[0])
    return selout(img)


def settings():
    img = new_img(24, 24)
    c = 11.5
    for y in range(24):
        for x in range(24):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy)
            a = (math.degrees(math.atan2(dy, dx)) + 360.0) % 45.0
            tooth = 13.0 <= a <= 32.0
            outer = 10.6 if tooth else 7.8
            if r > outer or r < 3.0:
                continue
            lx = dx / 10.6 + dy / 10.6
            tone = 4 if lx < -0.9 else 3 if lx < -0.2 else 2 if lx < 0.6 else 1
            if 3.0 <= r < 4.2:
                tone = 0 if lx < 0 else 3  # the bore: lit on the far side
            px(img, x, y, STEEL[tone])
    return selout(img)


def gen_hud24():
    save(sheet([shop(), routes(), logbook(), settings()]), "ui_hud24",
         preview_scale=8)


if __name__ == "__main__":
    gen_hud24()
