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
# Android adaptive icons want a 432x432 foreground (art on transparent) and a
# background (solid colour) — the launcher masks both into its own shape.
ADAPTIVE = 432


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
    # adaptive pair: the safe zone is the inner 66%, so the crest at 60% of
    # the tile survives every launcher mask.
    fg = Image.new("RGBA", (ADAPTIVE, ADAPTIVE), (0, 0, 0, 0))
    art = ADAPTIVE * 60 // 100
    fg.alpha_composite(crest.resize((art, art), Image.NEAREST),
                       ((ADAPTIVE - art) // 2, (ADAPTIVE - art) // 2))
    fg.save(os.path.join(OUT, "icon_432_fg.png"))
    Image.new("RGBA", (ADAPTIVE, ADAPTIVE), BG).save(
        os.path.join(OUT, "icon_432_bg.png"))
    print("adaptive 432 pair written")


if __name__ == "__main__":
    main()
