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


def line(d: ImageDraw.ImageDraw, a, b, colour, width=1) -> None:
    d.line([a, b], fill=colour, width=width)


def crane(width: int, word_w: int, drop: int) -> Image.Image:
    """Drawn at one pixel per game pixel; scaled up whole by the caller.

    `width` is the boom's length, `word_w` the span the spreader must cover and
    `drop` how far the ropes fall from the trolley to the spreader."""
    boom_h = 15
    h = boom_h + 12 + drop + 6
    img = Image.new("RGBA", (width, h))
    d = ImageDraw.Draw(img)
    # --- the boom: two chords and a zigzag web, outlined ---
    d.rectangle((0, 0, width - 1, boom_h), fill=INK)
    d.rectangle((0, 1, width - 1, 2), fill=RED_L)
    d.rectangle((0, boom_h - 2, width - 1, boom_h - 1), fill=RED)
    d.rectangle((0, 3, width - 1, boom_h - 3), fill=RED_D)
    for x in range(-10, width + 10, 10):
        line(d, (x, boom_h - 3), (x + 5, 3), RED, 2)
        line(d, (x + 5, 3), (x + 10, boom_h - 3), RED, 2)
    # Hazard band at the seaward tip.
    for x in range(width - 22, width, 4):
        d.rectangle((x, 1, x + 1, 2), fill=YELLOW)
    # --- the trolley riding the bottom chord, cab hung off its side ---
    cx = width // 2
    tw = 26
    top = boom_h - 1
    d.rectangle((cx - tw // 2, top, cx + tw // 2, top + 8), fill=INK)
    d.rectangle((cx - tw // 2 + 1, top + 1, cx + tw // 2 - 1, top + 7), fill=YELLOW)
    d.rectangle((cx - tw // 2 + 1, top + 6, cx + tw // 2 - 1, top + 7), fill=YELLOW_D)
    for wx in (cx - tw // 2 + 4, cx + tw // 2 - 4):
        d.ellipse((wx - 2, top - 2, wx + 2, top + 2), fill=INK)
        d.point((wx, top), fill=STEEL_L)
    cab_x = cx - tw // 2 - 11
    d.rectangle((cab_x, top + 2, cab_x + 11, top + 11), fill=INK)
    d.rectangle((cab_x + 1, top + 3, cab_x + 10, top + 10), fill=CAB)
    d.rectangle((cab_x + 2, top + 4, cab_x + 8, top + 7), fill=GLASS)
    # --- wire ropes: from two sheaves under the trolley out to the spreader ---
    rope_top = top + 9
    bar_y = rope_top + drop
    sway = 3       # swung a touch off plumb: it is moving
    left = cx - word_w // 2 + sway
    right = cx + word_w // 2 + sway
    for sx, ex in ((cx - 5, left + word_w // 5), (cx + 5, right - word_w // 5)):
        line(d, (sx, rope_top), (ex, bar_y), INK, 4)
        line(d, (sx, rope_top), (ex, bar_y), STEEL_L, 2)
    # --- the spreader: a yellow frame with twistlocks biting the word ---
    d.rectangle((left, bar_y, right, bar_y + 5), fill=INK)
    d.rectangle((left + 1, bar_y + 1, right - 1, bar_y + 4), fill=YELLOW)
    d.rectangle((left + 1, bar_y + 4, right - 1, bar_y + 4), fill=YELLOW_D)
    for tx in (left + 2, left + word_w // 2 - 2, right - 6):
        d.rectangle((tx, bar_y + 5, tx + 4, bar_y + 7), fill=INK)
        d.rectangle((tx + 1, bar_y + 5, tx + 3, bar_y + 6), fill=STEEL)
    return img


def main() -> None:
    word = cut_word()
    scale = 9
    word_u = word.width // scale
    boom = crane(word_u + 40, int(word_u * 0.86), 16)
    big = boom.resize((boom.width * scale, boom.height * scale), Image.NEAREST)
    out = Image.new("RGBA", (big.width, big.height + word.height - 2 * scale))
    out.alpha_composite(big)
    # The word hangs under the spreader, shifted with its sway.
    x = (out.width - word.width) // 2 + 3 * scale
    out.alpha_composite(word, (x, big.height - 3 * scale))
    os.makedirs(OUT, exist_ok=True)
    out.save(os.path.join(OUT, "logo_crane.png"))
    print(f"  brand/logo_crane.png  {out.width}x{out.height}")


if __name__ == "__main__":
    main()
