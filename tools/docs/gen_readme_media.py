"""Builds the pictures the root README shows: a banner and screenshot boards.

    tools/venv/bin/python tools/docs/gen_readme_media.py

The banner is drawn from the landing's own backdrop and wordmark grid, so the
front page of the repository is made of the same pixels as the game. The
boards are framed copies of real captures from `tools/capture` (the closeup and
matrix harnesses write them to `user://uishots`). Re-run those first when the
game changes, then this script. Output goes to `docs/media/readme/`.

Nothing here ships in the game pack: `docs/` is documentation only.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "sprites"))

import palette as P  # noqa: E402
import gen_landing as L  # noqa: E402
from common import hline, new_img, rect, text, text_width  # noqa: E402

OUT = os.path.join(ROOT, "docs", "media", "readme")
SHOTS = os.path.expanduser(
    "~/Library/Application Support/Godot/app_userdata/HarborClick/uishots")

NAME = "STACKYARD"
TAGLINE = "IDLE PORT TYCOON"
BAND = "O PORTO NUNCA DORME"

INK = (12, 22, 36, 255)        # the night every board sits on
INK_L = (24, 40, 60, 255)


def save(img: Image.Image, name: str) -> None:
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    img.save(path, optimize=True)
    print(f"  {name}.png  {img.width}x{img.height}")


def shot(name: str, width: int, keep: float = 1.0) -> Image.Image:
    """A capture scaled to `width`; `keep` < 1 trims the bottom (tab bar)."""
    src = Image.open(os.path.join(SHOTS, name + ".png")).convert("RGBA")
    if keep < 1.0:
        src = src.crop((0, 0, src.width, round(src.height * keep)))
    height = round(src.height * width / src.width)
    return src.resize((width, height), Image.LANCZOS)


def label(message: str, scale: int, color=P.SAFETY_L) -> Image.Image:
    """A line of the game's 5x7 font with a hard drop shadow, scaled whole."""
    w, h = text_width(message) + 2, 11
    img = new_img(w, h)
    text(img, 1, 1, message, L.LOGO_SHADOW)
    text(img, 0, 0, message, color)
    return img.resize((w * scale, h * scale), Image.NEAREST)


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, img.width - 1, img.height - 1), radius, fill=255)
    out = img.copy()
    out.putalpha(mask)
    return out


def phone(img: Image.Image) -> Image.Image:
    """A capture in a dark bezel with a soft shadow, the way a store shows it."""
    bezel = 14
    radius = 34
    body = Image.new("RGBA", (img.width + bezel * 2, img.height + bezel * 2))
    ImageDraw.Draw(body).rounded_rectangle(
        (0, 0, body.width - 1, body.height - 1), radius + bezel,
        fill=(20, 22, 30, 255), outline=(70, 74, 92, 255), width=3)
    body.alpha_composite(rounded(img, radius), (bezel, bezel))
    pad = 30
    out = Image.new("RGBA", (body.width + pad * 2, body.height + pad * 2))
    shadow = Image.new("RGBA", out.size)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (pad, pad + 12, pad + body.width, pad + body.height + 12),
        radius + bezel, fill=(0, 0, 0, 150))
    out.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
    out.alpha_composite(body, (pad, pad))
    return out


def backdrop(w: int, h: int) -> Image.Image:
    """Night ink with the port strip faint behind it, so boards feel on-site."""
    strip = Image.open(os.path.join(ROOT, "landing", "assets",
                                    "port-strip.png")).convert("RGBA")
    k = 3
    tile = strip.resize((strip.width * k, strip.height * k), Image.NEAREST)
    img = Image.new("RGBA", (w, h), INK)
    for x in range(0, w, tile.width):
        img.alpha_composite(tile, (x, (h - tile.height) // 2))
    veil = Image.new("RGBA", (w, h), (10, 20, 34, 214))
    img.alpha_composite(veil)
    return img


# --------------------------------------------------------------------------
# Banner
# --------------------------------------------------------------------------
def gen_banner():
    """1280x400, painted at 320x100 and scaled by exactly 4."""
    scale = 4
    w, h = 320, 100
    strip = Image.open(os.path.join(ROOT, "landing", "assets",
                                    "port-strip.png")).convert("RGBA")
    card = strip.crop((160, 196, 160 + w, 196 + h)).copy()
    veil = new_img(w, h)
    rect(veil, 0, 0, w, h, (8, 20, 34, 104))
    card.alpha_composite(veil)

    logo = L._word(NAME)
    plate = L._plate(logo.width + 28, logo.height + 34)
    plate.alpha_composite(logo, (14, 11))
    text(plate, (plate.width - text_width(TAGLINE)) // 2, plate.height - 17,
         TAGLINE, P.SAFETY_L)
    card.alpha_composite(plate, ((w - plate.width) // 2, 12))

    band_w = text_width(BAND) + 11
    band = new_img(band_w, 15)
    rect(band, 0, 0, band_w, 15, (10, 22, 36, 220))
    hline(band, 0, 0, band_w, P.SAFETY_D)
    hline(band, 0, 14, band_w, P.SAFETY_D)
    text(band, 5, 3, BAND, P.PAINT_W)
    card.alpha_composite(band, ((w - band_w) // 2, h - 22))

    save(card.resize((w * scale, h * scale), Image.NEAREST), "banner")


def gen_logo():
    """The bare wordmark at 6x, for anywhere the name stands alone."""
    logo = L._word(NAME)
    save(logo.resize((logo.width * 6, logo.height * 6), Image.NEAREST), "logo")


# --------------------------------------------------------------------------
# Boards
# --------------------------------------------------------------------------
def board(name: str, shots, captions, width=520, keep=1.0):
    phones = [phone(shot(s, width, keep)) for s in shots]
    gap = 10
    head = 92
    w = sum(p.width for p in phones) + gap * (len(phones) - 1) + 60
    h = max(p.height for p in phones) + head + 20
    img = backdrop(w, h)
    x = 30
    for p, caption in zip(phones, captions):
        tag = label(caption, 4)
        img.alpha_composite(tag, (x + (p.width - tag.width) // 2, 30))
        img.alpha_composite(p, (x, head))
        x += p.width + gap
    save(img.convert("RGB"), name)


def gen_before_after():
    """Day one against level 18: the whole promise of the game in two frames."""
    width = 560
    left = phone(shot("closeup_fresh_played", width))
    right = phone(shot("closeup_ship", width))
    arrow_w = 150
    head = 92
    w = left.width + right.width + arrow_w + 60
    h = max(left.height, right.height) + head + 20
    img = backdrop(w, h)
    x0 = 30
    x1 = x0 + left.width + arrow_w
    for x, p, caption in ((x0, left, "DIA 1"), (x1, right, "NÍVEL 18")):
        tag = label(caption, 4)
        img.alpha_composite(tag, (x + (p.width - tag.width) // 2, 30))
        img.alpha_composite(p, (x, head))
    # a chunky pixel arrow, 6px cells, in the safety-orange of the wordmark
    cell = 8
    rows = ["......#....", "......##...", "#########..", "##########.",
            "###########", "##########.", "#########..", "......##...",
            "......#...."]
    ax = x0 + left.width + (arrow_w - len(rows[0]) * cell) // 2
    ay = head + left.height // 2 - len(rows) * cell // 2
    draw = ImageDraw.Draw(img)
    for ry, row in enumerate(rows):
        for rx, c in enumerate(row):
            if c == "#":
                color = P.SAFETY_L if ry < 4 else P.SAFETY if ry < 6 else P.SAFETY_D
                X, Y = ax + rx * cell, ay + ry * cell
                draw.rectangle((X, Y + 6, X + cell - 1, Y + cell - 1 + 6),
                               fill=L.LOGO_SHADOW)
                draw.rectangle((X, Y, X + cell - 1, Y + cell - 1), fill=color)
    save(img.convert("RGB"), "before_after")


if __name__ == "__main__":
    print("readme:")
    gen_banner()
    gen_logo()
    gen_before_after()
    board("board_port",
          ["closeup_decor_night", "closeup_rail", "closeup_landworks"],
          ["À NOITE", "RAMAL FÉRREO", "OBRAS"],
          # two of these caught a hover tooltip over the tab bar; drop the bar
          keep=0.885)
    board("board_play",
          ["closeup_supplydrop", "closeup_xray_scan", "390x844_wheel"],
          ["PARAQUEDAS", "RAIO-X", "GUINDASTE DA SORTE"])
    board("board_grow",
          ["closeup_roadmap", "closeup_ports", "390x844_journal_trophies"],
          ["PASSE DO PORTO", "PORTOS", "TROFÉUS"])
