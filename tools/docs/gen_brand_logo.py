"""The STACKYARD logo lifted by a gantry crane.

    tools/venv/bin/python tools/docs/gen_brand_logo.py

The generated wordmark (`docs/media/store/keyart/logo.png`) came with a lone
hook dangling over the A, which read as decoration, not as a lift. This cuts the
word out of its magenta ground, drops the hook, and hangs the word from a crane
drawn here in the game's own pixels: a red lattice boom across the top, a
trolley riding it with the operator's cab, two wire ropes down to a yellow
spreader that has the word by its top edge, swung a touch off plumb. Writes
`docs/media/store/brand/logo_crane.png` (transparent).
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
KEYART = os.path.join(ROOT, "docs", "media", "store", "keyart")
OUT = os.path.join(ROOT, "docs", "media", "store", "brand")

INK = (26, 18, 30, 255)
RED = (196, 58, 46, 255)
RED_L = (232, 96, 70, 255)
RED_D = (130, 34, 34, 255)
YELLOW = (250, 196, 54, 255)
YELLOW_D = (196, 132, 30, 255)
STEEL = (118, 124, 140, 255)
STEEL_L = (190, 198, 212, 255)
GLASS = (128, 214, 228, 255)
CAB = (236, 150, 44, 255)


def cut_word() -> Image.Image:
    """The wordmark without its magenta ground or the hook above it."""
    src = Image.open(os.path.join(KEYART, "logo.png")).convert("RGBA")
    px = src.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, _ = px[x, y]
            m = min(r, b) - g
            if m > 110:
                px[x, y] = (0, 0, 0, 0)
            elif m > 30:
                px[x, y] = (max(0, r - m), g, max(0, b - m), int(255 * (110 - m) / 80))
    word = src.crop(src.getbbox())
    # The letters start at the first row that is mostly ink; the hook and its
    # cable above are a thin column and never are.
    alpha = word.getchannel("A")
    for y in range(word.height):
        row = sum(1 for x in range(word.width) if alpha.getpixel((x, y)) > 40)
        if row > word.width * 0.30:
            word = word.crop((0, y, word.width, word.height))
            break
    return word.crop(word.getbbox())


def beam(d: ImageDraw.ImageDraw, a, b, width: int, fill, rim=INK) -> None:
    """A member with its ink rim: the rim is the same line, two units fatter."""
    d.line([a, b], fill=rim, width=width + 2)
    d.line([a, b], fill=fill, width=width)


def box(d: ImageDraw.ImageDraw, x0, y0, x1, y1, fill, lit=None, shade=None) -> None:
    """An outlined plate lit from the north-west, like every machine in the yard."""
    d.rectangle((x0, y0, x1, y1), fill=INK)
    d.rectangle((x0 + 1, y0 + 1, x1 - 1, y1 - 1), fill=fill)
    if lit:
        d.line([(x0 + 1, y0 + 1), (x1 - 1, y0 + 1)], fill=lit)
        d.line([(x0 + 1, y0 + 1), (x0 + 1, y1 - 1)], fill=lit)
    if shade:
        d.line([(x0 + 2, y1 - 1), (x1 - 1, y1 - 1)], fill=shade)
        d.line([(x1 - 1, y0 + 2), (x1 - 1, y1 - 1)], fill=shade)


# The crane, in units (one unit is `SCALE` pixels of the finished logo). A
# ship-to-shore crane in side elevation, whole: bogies on a railed quay, a
# braced portal, the A-frame and its stays, a boom with a finished nose. The
# word hangs under the outreach, where a ship would be.
SCALE = 6                  # the steel is finer than the letters: the word is the logo
LEG_L, LEG_R = 13, 35      # landside and waterside leg centres
APEX = (35, 3)
BOOM_Y, BOOM_H = 34, 13
WORD_X = 45                # left edge of the word
DROP = 16                  # trolley to spreader
SWAY = 3                   # swung a touch off plumb: it is moving


def crane(word_u: int, word_h: int, parts=("frame", "trolley", "ropes", "spreader"),
          drop: int = DROP):
    """Returns the drawing and where the word's top-left corner goes.

    `parts` picks what is drawn, always on the same canvas, so the landing can
    take the frame, the trolley and the spreader as three layers and move them
    (`tools/sprites/gen_landing.py`) while the store logo takes all of it."""
    width = WORD_X + SWAY + word_u + 12
    boom_bottom = BOOM_Y + BOOM_H
    rope_top = boom_bottom + 8
    bar_y = rope_top + drop
    ground = bar_y + 4 + word_h + 4
    img = Image.new("RGBA", (width, ground + 7))
    d = ImageDraw.Draw(img)
    tip = width - 3
    cx = WORD_X + SWAY + word_u // 2

    if "frame" in parts:
        _frame(d, width, ground, cx, tip)
    if "trolley" in parts:
        _trolley(d, cx, boom_bottom - 1)
    left = cx - int(word_u * 0.43)
    right = cx + int(word_u * 0.43)
    if "ropes" in parts:
        # Four falls, two sheaves each side, down to the spreader.
        for sx, ex in ((cx - 8, left + word_u // 6), (cx - 4, left + word_u // 4),
                       (cx + 4, right - word_u // 4), (cx + 8, right - word_u // 6)):
            d.line([(sx, rope_top), (ex, bar_y)], fill=INK, width=3)
            d.line([(sx, rope_top), (ex, bar_y)], fill=STEEL_L, width=1)
    if "spreader" in parts:
        _spreader(d, left, right, cx, bar_y)
    return img, (WORD_X + SWAY, bar_y + 6)


def _frame(d, width, ground, cx, tip) -> None:
    boom_bottom = BOOM_Y + BOOM_H
    # --- stays first: everything else is in front of them ---
    for end in (cx - 8, tip - 10):
        beam(d, APEX, (end, BOOM_Y), 2, STEEL_L)
    beam(d, APEX, (5, BOOM_Y), 2, STEEL_L)
    # --- the quay it stands on: a railed slab with a buffer at each end ---
    q0, q1 = 2, LEG_R + 11
    box(d, q0, ground + 1, q1, ground + 6, (150, 144, 150, 255),
        (196, 190, 190, 255), (104, 98, 112, 255))
    d.rectangle((q0 + 3, ground, q1 - 3, ground + 1), fill=INK)
    d.line([(q0 + 4, ground), (q1 - 4, ground)], fill=STEEL_L)
    for bx in (q0 + 1, q1 - 4):
        box(d, bx, ground - 4, bx + 3, ground + 1, YELLOW, None, YELLOW_D)
    # --- the portal: two legs, sill beam, portal beam and the cross brace ---
    sill, tie = ground - 16, boom_bottom + 22
    beam(d, (LEG_L, tie + 2), (LEG_R, sill - 1), 2, RED_D)
    beam(d, (LEG_R, tie + 2), (LEG_L, sill - 1), 2, RED_D)
    for y in (sill, tie):
        box(d, LEG_L, y - 2, LEG_R, y + 3, RED, RED_L, RED_D)
    for lx in (LEG_L, LEG_R):
        box(d, lx - 3, BOOM_Y + 2, lx + 3, ground - 6, RED, RED_L, RED_D)
        # the bogie: an equaliser beam on two flanged wheels
        box(d, lx - 7, ground - 8, lx + 7, ground - 4, STEEL, STEEL_L, None)
        for wx in (lx - 4, lx + 4):
            d.ellipse((wx - 3, ground - 6, wx + 3, ground), fill=INK)
            d.ellipse((wx - 1, ground - 4, wx + 1, ground - 2), fill=STEEL_L)
    # --- the A-frame over the waterside leg ---
    beam(d, (LEG_L, BOOM_Y), APEX, 3, RED)
    beam(d, (LEG_R, BOOM_Y), APEX, 5, RED)
    d.line([(LEG_R - 2, BOOM_Y), (APEX[0] - 2, APEX[1] + 2)], fill=RED_L)
    box(d, APEX[0] - 4, APEX[1] - 2, APEX[0] + 4, APEX[1] + 4, RED, RED_L, RED_D)
    d.rectangle((APEX[0] - 1, APEX[1] - 5, APEX[0] + 1, APEX[1] - 2), fill=INK)
    d.point((APEX[0], APEX[1] - 4), fill=(255, 92, 78, 255))
    # --- the boom: two chords and a zigzag web, backreach to nose ---
    d.rectangle((2, BOOM_Y, tip, boom_bottom), fill=INK)
    d.rectangle((3, BOOM_Y + 1, tip - 1, BOOM_Y + 2), fill=RED_L)
    d.rectangle((3, BOOM_Y + 3, tip - 1, boom_bottom - 3), fill=RED_D)
    d.rectangle((3, boom_bottom - 2, tip - 1, boom_bottom - 1), fill=RED)
    for x in range(3, tip - 6, 10):
        d.line([(x, boom_bottom - 3), (x + 5, BOOM_Y + 3)], fill=RED, width=2)
        d.line([(x + 5, BOOM_Y + 3), (x + 10, boom_bottom - 3)], fill=RED, width=2)
    d.rectangle((tip + 1, BOOM_Y, width, boom_bottom), fill=(0, 0, 0, 0))
    # The nose: a hazard-taped end plate, chamfered, with the tip beacon on it.
    for i, x in enumerate(range(tip - 13, tip - 1, 3)):
        d.rectangle((x, BOOM_Y + 1, x + 2, boom_bottom - 1),
                    fill=YELLOW if i % 2 == 0 else INK)
    d.rectangle((tip - 1, BOOM_Y, tip, boom_bottom), fill=INK)
    for corner in ((tip, BOOM_Y), (tip, boom_bottom), (2, BOOM_Y), (2, boom_bottom)):
        d.point(corner, fill=(0, 0, 0, 0))
    box(d, tip - 5, BOOM_Y - 4, tip - 1, BOOM_Y, STEEL, STEEL_L, None)
    d.rectangle((tip - 4, BOOM_Y - 7, tip - 2, BOOM_Y - 4), fill=INK)
    d.point((tip - 3, BOOM_Y - 6), fill=(255, 92, 78, 255))
    # Where the stays pin to the top chord.
    for end in (cx - 8, tip - 10, 5):
        box(d, end - 2, BOOM_Y - 2, end + 2, BOOM_Y + 1, STEEL, STEEL_L, None)
    # --- machinery house on the backreach, counterweight under it ---
    box(d, 3, BOOM_Y - 11, LEG_L - 3, BOOM_Y, (222, 226, 232, 255),
        (250, 250, 250, 255), (160, 166, 180, 255))
    d.rectangle((3, BOOM_Y - 12, LEG_L - 3, BOOM_Y - 10), fill=INK)
    d.line([(4, BOOM_Y - 11), (LEG_L - 4, BOOM_Y - 11)], fill=RED_L)
    for wx in (5,):
        d.rectangle((wx, BOOM_Y - 7, wx + 3, BOOM_Y - 4), fill=GLASS)
    box(d, 3, boom_bottom, 12, boom_bottom + 8, STEEL, STEEL_L, (84, 88, 104, 255))


def _trolley(d, cx, top) -> None:
    """A steel carriage clamped over the bottom chord, a sheave block under
    each end. No wheels on show and no cab on its side: a yellow box on two
    wheels with a cab at one end is a lorry, and under a boom it is a lorry
    driving upside down."""
    box(d, cx - 13, top - 4, cx + 13, top + 4, (84, 90, 110, 255),
        (150, 158, 178, 255), (52, 56, 74, 255))
    for bx in range(cx - 10, cx + 10, 5):
        d.point((bx, top), fill=STEEL_L)
    for sx in (cx - 10, cx + 4):
        box(d, sx, top + 4, sx + 6, top + 9, YELLOW, (255, 226, 120, 255), YELLOW_D)
        d.point((sx + 3, top + 7), fill=INK)


def _spreader(d, left, right, cx, bar_y) -> None:
    # --- the spreader: a yellow frame with twistlocks biting the word ---
    box(d, left, bar_y, right, bar_y + 5, YELLOW, (255, 226, 120, 255), YELLOW_D)
    for hx in range(left + 6, right - 6, 8):
        d.rectangle((hx, bar_y + 2, hx + 3, bar_y + 3), fill=INK)
    for tx in (left + 2, cx - 2, right - 6):
        d.rectangle((tx, bar_y + 5, tx + 4, bar_y + 8), fill=INK)
        d.rectangle((tx + 1, bar_y + 5, tx + 3, bar_y + 7), fill=STEEL)


def main() -> None:
    word = cut_word()
    word_u = word.width // SCALE
    art, at = crane(word_u, -(-word.height // SCALE))
    out = art.resize((art.width * SCALE, art.height * SCALE), Image.NEAREST)
    # The word hangs under the spreader, its top edge inside the twistlocks.
    out.alpha_composite(word, (at[0] * SCALE, at[1] * SCALE))
    out = out.crop(out.getbbox())
    os.makedirs(OUT, exist_ok=True)
    out.save(os.path.join(OUT, "logo_crane.png"))
    print(f"  brand/logo_crane.png  {out.width}x{out.height}")


if __name__ == "__main__":
    main()
