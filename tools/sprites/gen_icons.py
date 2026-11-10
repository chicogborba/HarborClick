"""PWA / home-screen icons, drawn from the title crest on the app's navy.

The crest is the one piece of key art that is already square-ish and reads at
small sizes, so the icons are it centred on the background colour, scaled with
nearest neighbour (pixel art never resamples). Sizes are the ones the Web
preset's progressive_web_app block asks for: 144, 180 and 512.
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "sprites"))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "icons"))

BG = (13, 11, 17, 255)  # matches the PWA background_color in export_presets.cfg
SIZES = (144, 180, 512)


def main():
    os.makedirs(OUT, exist_ok=True)
    crest = Image.open(os.path.join(SPRITES, "ui_title_crest.png")).convert("RGBA")
    for size in SIZES:
        icon = Image.new("RGBA", (size, size), BG)
        # 78% of the tile is art, 11% margin each side — a crest that touches
        # the edge reads as a sticker, not an icon.
        art = size * 78 // 100
        scaled = crest.resize((art, art), Image.NEAREST)
        icon.alpha_composite(scaled, ((size - art) // 2, (size - art) // 2))
        path = os.path.join(OUT, "icon_%d.png" % size)
        icon.save(path)
        print("icon_%d.png %dx%d" % (size, size, size))


if __name__ == "__main__":
    main()
