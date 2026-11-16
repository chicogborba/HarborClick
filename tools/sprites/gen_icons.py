"""App, PWA and home-screen icons, from the generated brand icon.

The icon is the one illustrated piece of branding (see `tools/docs/gen_keyart.py`
and `docs/media/store/keyart/generations.json` for its prompt): a red gantry
crane lifting a container at sunset. It is committed as a 1024 px answer and
this generator only resizes it, offline, into the sizes the presets ask for:

* 144, 180, 512 — the Web preset's progressive_web_app block, and 512 is also
  `application/config/icon` (the favicon and boot icon of `/jogar/`) and the
  Android legacy icon;
* 432 foreground + background — Android adaptive icons. The art is full-bleed,
  so it is the foreground whole and the background is its own sky colour; a
  launcher's mask trims the edges, never the crane in the middle.

Downscaling is LANCZOS, not nearest: a 1024 painting taken to 144 by dropping
pixels shimmers. The landing's favicons are made from the same file
(`gen_landing.gen_favicon`).
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SOURCE = os.path.join(ROOT, "docs", "media", "store", "keyart", "icon.png")
OUT = os.path.join(ROOT, "assets", "icons")

SIZES = (144, 180, 512)
ADAPTIVE = 432


def icon(size: int) -> Image.Image:
    return Image.open(SOURCE).convert("RGBA").resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    for size in SIZES:
        icon(size).save(os.path.join(OUT, f"icon_{size}.png"))
    fg = icon(ADAPTIVE)
    fg.save(os.path.join(OUT, "icon_432_fg.png"))
    sky = fg.getpixel((ADAPTIVE // 2, 4))
    Image.new("RGBA", (ADAPTIVE, ADAPTIVE), sky).save(
        os.path.join(OUT, "icon_432_bg.png"))
    print("  icons: 144 180 512 + adaptive 432")


if __name__ == "__main__":
    main()
