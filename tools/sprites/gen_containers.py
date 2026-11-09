"""Top-down containers, Stardew style.

A 40ft box seen from above: 22x11 footprint. The sprite draws the roof plus a
3px side wall so stacks read as solid volumes, shaded from a hue-shifted ramp
per livery (`palette.CONTAINER_RAMPS`). The rail wagons carry the same liveries
cut to their deck in `gen_train.py`.
"""
import palette as P
from common import new_img, rect, hline, vline, px, outline, sheet, save

W, H = 24, 13          # canvas (22x11 box + 1px outline margin)
BOX_W, BOX_H = 22, 11  # roof 22x8 + 3px side wall


def container(ramp_):
    """One forty-footer: 22x8 roof, 3px side wall, 1px ink outline.

    Built from a five-step hue-shifted ramp (`P.CONTAINER_RAMPS`) rather than a
    colour and a darker copy of it: the roof is the midtone, the corrugation
    is lit on its north-west flank and shaded on the other, the side wall sits
    a step down in cool shade and the bottom rail two. The wall is 3px because
    a stack lifts `PortLayout.BOX_LIFT` (4) per tier: wall plus outline is
    exactly one tier, so a stack shows every box's side like a real one."""
    img = new_img(W, H)
    d0, d1, mid, lit, glint = ramp_
    x0, y0 = 1, 1
    roof_h, wall_h = 8, 3
    # roof, corrugated across its width
    rect(img, x0, y0, BOX_W, roof_h, mid)
    shade = P.mix(mid, d1, 0.55)
    for x in range(x0 + 2, x0 + BOX_W - 2, 3):
        vline(img, x, y0 + 1, roof_h - 2, lit)
        vline(img, x + 1, y0 + 1, roof_h - 2, shade)
    hline(img, x0, y0, BOX_W, glint)                       # north edge in the light
    vline(img, x0, y0, roof_h, P.mix(mid, glint, 0.5))     # west edge
    vline(img, x0 + BOX_W - 1, y0 + 1, roof_h - 1, d1)     # east edge turns away
    # corner castings: the four steel blocks a spreader locks into
    for cx in (x0, x0 + BOX_W - 1):
        px(img, cx, y0, P.mix(glint, P.OUTLINE, 0.3))
        px(img, cx, y0 + roof_h - 1, P.mix(d1, P.OUTLINE, 0.4))
    # side wall: vertical corrugation in shade, a bottom rail under it
    rect(img, x0, y0 + roof_h, BOX_W, wall_h, d1)
    for x in range(x0 + 1, x0 + BOX_W - 1, 2):
        px(img, x, y0 + roof_h + 1, P.mix(d1, d0, 0.5))
    hline(img, x0, y0 + roof_h, BOX_W, P.mix(d1, mid, 0.35))  # top rail catches a little
    hline(img, x0, y0 + roof_h + wall_h - 1, BOX_W, d0)
    # the door end, east: locking bars on the wall
    for bx in (x0 + BOX_W - 4, x0 + BOX_W - 2):
        px(img, bx, y0 + roof_h + 1, P.mix(mid, glint, 0.4))
    return outline(img)


def gen_containers():
    frames = [container(P.CONTAINER_RAMPS[name]) for name in P.CONTAINER_NAMES]
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
