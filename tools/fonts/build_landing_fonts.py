"""Fetches and repairs the two pixel webfonts the landing page self-hosts.

The landing makes no third-party request at runtime, so the fonts are served
from `/media` rather than from Google. Until the page spoke nine languages one
Latin subset each was enough; Polish, Turkish and Russian need Latin Extended
and Cyrillic as well, and a glyph a font does not have is a blank rectangle in
the middle of a sentence.

Two things this does that a plain download would not:

* It keeps the subsets separate and lets `styles.css` declare a `unicode-range`
  for each, so a Portuguese reader still downloads only the Latin file.
* **It repairs Pixelify Sans.** Its published Cyrillic subset is missing
  U+041E О and U+041F П — two of the most common letters in Russian — so body
  copy would fall out of the pixel font mid-word. О is the Latin O and is
  copied straight across; П is built from the stem and bar metrics the font's
  own Н and Г already use, so it lands on the same pixel grid as everything
  around it.

Run it by hand when a font needs refreshing; the release build never calls out
to the network.

  tools/venv/bin/python tools/fonts/build_landing_fonts.py
"""
import os
import re
import urllib.request

from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "landing", "assets")

API = ("https://fonts.googleapis.com/css2"
       "?family=Press+Start+2P&family=Pixelify+Sans:wght@400..700&display=swap")
# A modern browser UA is what makes the API answer in woff2 rather than ttf.
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")

# family -> file stem, and the subsets the page actually needs. Greek and
# cyrillic-ext are on offer and deliberately not taken: nothing on the page is
# written in either.
FAMILIES = {
    "Press Start 2P": "press-start-2p",
    "Pixelify Sans": "pixelify-sans",
}
SUBSETS = ("latin", "latin-ext", "cyrillic")


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def sources() -> dict:
    """{(family, subset): url} straight out of the stylesheet Google serves."""
    css = fetch(API).decode("utf-8")
    found = {}
    for subset, body in re.findall(r"/\* (\S+) \*/\s*@font-face \{(.*?)\}",
                                   css, re.S):
        family = re.search(r"font-family: '([^']+)'", body).group(1)
        url = re.search(r"url\((\S+?)\)", body).group(1)
        found[(family, subset)] = url
    return found


def _contour(pen, points) -> None:
    pen.moveTo(points[0])
    for point in points[1:]:
        pen.lineTo(point)
    pen.closePath()


def repair_cyrillic(font: TTFont, latin: TTFont) -> list:
    """Add the two letters Pixelify Sans's Cyrillic subset leaves out."""
    cmap = {}
    for table in font["cmap"].tables:
        cmap.update(table.cmap)
    if 0x41E in cmap and 0x41F in cmap:
        return []

    # Every upright capital in this font shares one skeleton, which is why the
    # two new letters can be stated in its own numbers rather than guessed:
    # stems at x 60..161 and 423..525, baseline -12, cap 629, bar bottom 528.
    added = []
    glyf, hmtx = font["glyf"], font["hmtx"]

    # О is the Latin O — same letter, same drawing, in every typeface there is.
    latin_cmap = {}
    for table in latin["cmap"].tables:
        latin_cmap.update(table.cmap)
    pen = TTGlyphPen(None)
    latin.getGlyphSet()[latin_cmap[ord("O")]].draw(pen)
    glyf["uni041E"] = pen.glyph()
    hmtx["uni041E"] = latin["hmtx"][latin_cmap[ord("O")]]
    added.append((0x41E, "uni041E"))

    # П: two stems under one bar, on the grid Н and Г already stand on.
    pen = TTGlyphPen(None)
    _contour(pen, [(60, -12), (60, 629), (525, 629), (525, -12),
                   (423, -12), (423, 528), (161, 528), (161, -12)])
    glyf["uni041F"] = pen.glyph()
    hmtx["uni041F"] = hmtx["uni041D"]
    added.append((0x41F, "uni041F"))

    # `glyf.__setitem__` has already appended each new name to the order it
    # shares with the font; copying it back is all the bookkeeping left.
    font.setGlyphOrder(list(glyf.glyphOrder))
    for table in font["cmap"].tables:
        for code, name in added:
            table.cmap[code] = name
    return added


def raise_dotted_i(font: TTFont) -> bool:
    """Give Turkish İ back most of its cap height.

    Press Start 2P fits every accent inside the em box, which works for Ö and
    Ü — a squashed O still reads as an O — but leaves U+0130 as a stem only 71%
    of cap height with a fat dot over it, so `LİMAN` reads as `LiMAN`. The stem
    is redrawn to 85% and the dot slimmed to match. Nothing leaves the em box,
    so no line can clip against the one above it."""
    cmap = {}
    for table in font["cmap"].tables:
        cmap.update(table.cmap)
    name = cmap.get(0x130)
    if name is None:
        return False

    pen = TTGlyphPen(None)
    _contour(pen, [(375, 900), (625, 900), (625, 1000), (375, 1000)])
    _contour(pen, [(125, 125), (125, 250), (375, 250), (375, 725), (125, 725),
                   (125, 850), (875, 850), (875, 725), (625, 725), (625, 250),
                   (875, 250), (875, 125)])
    font["glyf"][name] = pen.glyph()
    return True


def main() -> None:
    urls = sources()
    os.makedirs(OUT, exist_ok=True)
    print("landing fonts:")
    for family, stem in FAMILIES.items():
        latin_path = os.path.join(OUT, f"{stem}-latin.woff2")
        for subset in SUBSETS:
            url = urls.get((family, subset))
            if url is None:
                print(f"  {stem}-{subset}: not published, skipped")
                continue
            path = os.path.join(OUT, f"{stem}-{subset}.woff2")
            with open(path, "wb") as handle:
                handle.write(fetch(url))
            note = ""
            if subset == "cyrillic" and family == "Pixelify Sans":
                font = TTFont(path)
                added = repair_cyrillic(font, TTFont(latin_path))
                if added:
                    font.flavor = "woff2"
                    font.save(path)
                    note = "  (+%s)" % " ".join(
                        chr(code) for code, _ in added)
            if subset == "latin-ext" and family == "Press Start 2P":
                font = TTFont(path)
                if raise_dotted_i(font):
                    font.flavor = "woff2"
                    font.save(path)
                    note = "  (İ raised)"
            print(f"  {os.path.basename(path)}  "
                  f"{os.path.getsize(path) // 1024 or 1}k{note}")


if __name__ == "__main__":
    main()
