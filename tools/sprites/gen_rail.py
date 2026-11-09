"""Furniture for the branch line: the signal, the level crossing, the boards.

A railway tells you what it is about to do before it does it, and it does so with
paint and lamps rather than with a HUD. The terminal's branch gets the same
treatment: a three-aspect signal that clears before the train appears, a crossing
that starts flashing while the road is still empty, and a board at the ramp with
the road's name on it.

Every lit part is a separate sprite drawn on the same canvas as its dark one, the
way `prop_lamp`/`prop_lamp_lit` already work, so the game switches an aspect by
showing a frame instead of by tinting a sprite it would then have to un-tint.
"""
import palette as P
from common import (hline, new_img, outline, px, rect, save, sheet, text,
                    text_width, vline)
from gen_buildings import ridged_roof

SIGNAL_W, SIGNAL_H = 10, 18
CROSSING_W, CROSSING_H = 12, 15
## Aspect order, from the top of the head down — the order they sit on a real
## signal, and the order `RailYard` names them in.
ASPECTS = ["danger", "approach", "clear"]
ASPECT_COLOURS = {
    "danger": P.RED_LIGHT,
    "approach": P.SAFETY_L,
    "clear": P.GREEN_LIGHT,
}
LAMP_ROWS = {"danger": 1, "approach": 4, "clear": 7}
LAMP_DARK = (46, 44, 52, 255)


def gen_signal():
    """Three-aspect colour light on a post, seen from above.

    Foreshortened like every other mast in the yard: the head is most of what a
    top-down camera sees of a signal, so it gets most of the sprite."""
    img = new_img(SIGNAL_W, SIGNAL_H)
    # base plinth
    rect(img, 3, 13, 5, 4, P.QUAY_D)
    hline(img, 3, 13, 5, P.QUAY)
    # post
    rect(img, 4, 10, 3, 4, P.STEEL_D)
    vline(img, 4, 10, 4, P.STEEL)
    # head with three dark lenses
    rect(img, 1, 0, 8, 10, P.STEEL_D)
    hline(img, 1, 0, 8, P.STEEL)
    vline(img, 1, 0, 10, P.STEEL)
    for row in LAMP_ROWS.values():
        rect(img, 3, row, 3, 2, LAMP_DARK)
        px(img, 3, row, (70, 66, 76, 255))
    save(outline(img), "rail_signal")

    frames = []
    for aspect in ASPECTS:
        lit = new_img(SIGNAL_W, SIGNAL_H)
        row = LAMP_ROWS[aspect]
        colour = ASPECT_COLOURS[aspect]
        rect(lit, 3, row, 3, 2, colour)
        # A lens throws a little light onto the housing around it, which is what
        # makes the aspect readable at this size without a glow sprite.
        px(lit, 2, row, _halo(colour))
        px(lit, 6, row, _halo(colour))
        px(lit, 2, row + 1, _halo(colour))
        px(lit, 6, row + 1, _halo(colour))
        frames.append(lit)
    save(sheet(frames), "rail_signal_lit")


def _halo(colour):
    return (colour[0], colour[1], colour[2], 120)


def gen_crossing():
    """Level crossing mast: St Andrew's cross over a pair of wig-wag lamps."""
    img = new_img(CROSSING_W, CROSSING_H)
    rect(img, 4, 11, 4, 3, P.QUAY_D)
    hline(img, 4, 11, 4, P.QUAY)
    rect(img, 5, 8, 2, 4, P.STEEL_D)
    vline(img, 5, 8, 4, P.STEEL)
    # the cross
    for step in range(7):
        px(img, 2 + step, step, P.PAINT_W)
        px(img, 9 - step, step, P.PAINT_W)
        px(img, 2 + step, step + 1, (206, 200, 186, 255))
        px(img, 9 - step, step + 1, (206, 200, 186, 255))
    # dark lamps either side of the post
    for x in (1, 8):
        rect(img, x, 8, 3, 3, P.STEEL_D)
        rect(img, x + 1, 9, 1, 1, LAMP_DARK)
    save(outline(img), "rail_crossing")

    frames = []
    for side in (1, 8):
        lit = new_img(CROSSING_W, CROSSING_H)
        rect(lit, side + 1, 9, 1, 1, P.RED_LIGHT)
        px(lit, side, 9, _halo(P.RED_LIGHT))
        px(lit, side + 2, 9, _halo(P.RED_LIGHT))
        px(lit, side + 1, 8, _halo(P.RED_LIGHT))
        px(lit, side + 1, 10, _halo(P.RED_LIGHT))
        frames.append(lit)
    save(sheet(frames), "rail_crossing_lit")


def gen_board():
    """The ramp's name board. A place in a terminal has a name on a post."""
    label = "RAMAL 1"
    inner_w = text_width(label) + 4
    w = inner_w + 4
    h = 20
    img = new_img(w, h)
    # posts first, so the board sits over them
    for post_x in (3, w - 5):
        rect(img, post_x, 12, 2, 7, P.WOOD_D)
        vline(img, post_x, 12, 7, P.WOOD)
    rect(img, 0, 0, w, 14, P.OUTLINE)
    rect(img, 1, 1, w - 2, 12, (36, 62, 92, 255))
    hline(img, 1, 1, w - 2, (52, 84, 118, 255))
    rect(img, 2, 2, w - 4, 10, (26, 48, 74, 255))
    text(img, 2 + (inner_w - text_width(label)) // 2, 2, label, P.SAFETY_L)
    save(outline(img), "rail_board")


def gen_shed():
    """The transit shed at the head of the platform. 44x30.

    A goods station is a shed with a track beside it. Everything that comes off a
    wagon and is not going straight onto a stack waits in here, which is why it
    stands at the buffer-stop end — where the head of every rake stops.

    Roofed in the same blue as the customs booth so the two administrative
    buildings on the terminal read as belonging to the same authority, and given
    roller doors down the platform edge so it is obvious which side is worked.
    """
    w, h = 44, 30
    img = new_img(w, h)
    ridged_roof(img, 1, 1, w - 2, h - 2, P.ROOF_BLUE, (110, 142, 176, 255),
                P.ROOF_BLUE_D, ridge_step=6)
    # Skylight strips either side of the ridge — a shed this deep is dark.
    for sx in range(6, w - 10, 12):
        rect(img, sx, 5, 8, 4, P.GLASS)
        hline(img, sx, 5, 8, P.GLASS_D)
        rect(img, sx, h - 10, 8, 4, P.GLASS)
        hline(img, sx, h - 10, 8, P.GLASS_D)
    # Roller doors along the north (platform) edge, where the wagons stand.
    for dx in range(5, w - 8, 11):
        rect(img, dx, 0, 8, 3, P.STEEL_D)
        hline(img, dx, 0, 8, P.STEEL_L)
    # Vent stack on the ridge and a lamp over the doors.
    rect(img, w // 2 - 3, h // 2 - 3, 6, 5, P.STEEL)
    hline(img, w // 2 - 3, h // 2 - 3, 6, P.STEEL_L)
    rect(img, 2, 3, 3, 2, P.SAFETY)
    save(outline(img), "rail_shed")


## Centre-to-centre of the gantry's two sill beams. It is the crane's rail gauge,
## and `GroundBaker._paint_rail_platform` paints steel at exactly this spacing —
## the machine has to stand on the rails that are drawn for it, or it reads as
## parked in mid-air over the ballast.
GANTRY_GAUGE = 32
GANTRY_SILL_H = 6


def gen_gantry():
    """The rail-mounted gantry that spans the running line. 30x44.

    Drawn as the portal it is, along the branch rather than across it: two legs
    on their own rails, a beam between them, and the trolley that runs the beam
    sitting over the track. The camera looks straight down, so what a portal
    crane mostly shows is its beam — that gets the pixels.
    """
    top = 3
    bottom = top + GANTRY_GAUGE
    w, h = 30, bottom + GANTRY_SILL_H + 3
    img = new_img(w, h)
    # Sill beams, one on each rail, running along the branch.
    for by in (top, bottom):
        rect(img, 2, by, w - 4, GANTRY_SILL_H, P.STEEL_D)
        hline(img, 2, by, w - 4, P.STEEL_L)
        for foot in range(4, w - 6, 8):
            rect(img, foot, by + 1, 3, 4, P.STEEL)
    # The two legs, seen end-on as short stubs, and the span between them.
    var_top = top + GANTRY_SILL_H
    leg_h = bottom - var_top
    for lx in (5, w - 9):
        rect(img, lx, var_top, 4, leg_h, P.STEEL)
        vline(img, lx, var_top, leg_h, P.STEEL_L)
        vline(img, lx + 3, var_top, leg_h, P.STEEL_D)
    mid = var_top + leg_h // 2
    rect(img, 9, mid - 5, w - 18, 10, P.CRANE_D)
    hline(img, 9, mid - 5, w - 18, P.CRANE)
    hline(img, 9, mid + 4, w - 18, (110, 44, 42, 255))
    # Trolley and spreader, parked over the running line.
    rect(img, 11, mid - 8, 8, 6, P.SAFETY_D)
    hline(img, 11, mid - 8, 8, P.SAFETY)
    rect(img, 12, mid + 5, 6, 3, P.STEEL_D)
    save(outline(img), "rail_gantry")


if __name__ == "__main__":
    print("rail:")
    gen_signal()
    gen_crossing()
    gen_board()
    gen_shed()
    gen_gantry()
