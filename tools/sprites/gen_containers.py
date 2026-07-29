"""Top-down containers, Stardew style.

A 40ft box seen from above: 22x10 footprint. The sprite draws the roof plus a
2px front lip so stacks read as solid volumes. Each colour also gets a
"stack shadow" variant used under piled boxes.
"""
import palette as P
from common import new_img, rect, hline, vline, px, outline, sheet, save

W, H = 24, 13          # canvas (22x11 box + 1px outline margin)
BOX_W, BOX_H = 22, 11  # roof 22x9 + 2px front lip


def container(top, side):
    img = new_img(W, H)
    x0, y0 = 1, 1
    roof_h = 9
    # roof
    rect(img, x0, y0, BOX_W, roof_h, top)
    # corrugation ribs running across the roof
    rib = tuple(max(0, c - 22) for c in top[:3]) + (255,)
    for x in range(x0 + 2, x0 + BOX_W - 2, 3):
        vline(img, x, y0 + 1, roof_h - 2, rib)
    # top-left highlight edge (light from upper-left)
    hi = tuple(min(255, c + 26) for c in top[:3]) + (255,)
    hline(img, x0, y0, BOX_W, hi)
    vline(img, x0, y0, roof_h, hi)
    # right edge shade
    vline(img, x0 + BOX_W - 1, y0, roof_h, side)
    # corner castings
    for cx in (x0, x0 + BOX_W - 1):
        for cy in (y0, y0 + roof_h - 1):
            px(img, cx, cy, P.OUTLINE_SOFT)
    # front lip (the 2px face you see below the roof)
    rect(img, x0, y0 + roof_h, BOX_W, 2, side)
    hline(img, x0, y0 + roof_h + 1, BOX_W,
          tuple(max(0, c - 26) for c in side[:3]) + (255,))
    # door end detail on the right of the lip
    px(img, x0 + BOX_W - 3, y0 + roof_h, P.OUTLINE_SOFT)
    px(img, x0 + BOX_W - 5, y0 + roof_h, P.OUTLINE_SOFT)
    return outline(img)


def gen_containers():
    frames = [container(t, s) for t, s in P.CONTAINERS.values()]
    save(sheet(frames), "container_sheet")


def gen_container_shadow():
    """Soft shadow blob cast by a stacked container (24x13)."""
    img = new_img(W, H)
    rect(img, 2, 3, BOX_W, 10, P.SHADOW)
    px(img, 2, 3, P.TRANSPARENT)
    px(img, BOX_W + 1, 3, P.TRANSPARENT)
    px(img, 2, 12, P.TRANSPARENT)
    px(img, BOX_W + 1, 12, P.TRANSPARENT)
    save(img, "container_shadow")


if __name__ == "__main__":
    print("containers:")
    gen_containers()
    gen_container_shadow()
