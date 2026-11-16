"""Store and social pictures: screenshots with captions, feature graphic, banners.

    tools/venv/bin/python tools/docs/gen_store_media.py

Inputs:
* real captures of the running game, one folder per language
  (`STACKYARD_SHOTS_PT`, `STACKYARD_SHOTS_EN`; default `user://uishots`), shot with
  `tools/capture/closeup.tscn -- lang=pt_BR "ship+wake_trail+shop_upgrades+..."`;
* the generated brand art in `docs/media/store/keyart/` (`gen_keyart.py`): the
  STACKYARD logo (cut out of its magenta ground here), the icon and key art.

Copy is set in the game's own bitmap font (harbor_font), outlined and shadowed
at the font's pixel and scaled by whole numbers, next to the crane-lifted logo
(`gen_brand_logo.py`). Two earlier tries were rejected: the 5x7 tool font was
thin and pale, and a rounded TTF looked like a different product — the store convention for game screenshots,
because these are read as thumbnails. The first version set captions in the
5x7 tool font at whole-number scales: on a phone's store page it was thin,
pale and did not say what kind of game this is. Every screen now leads with a
verb, and the pitch — an idle clicker — is on the badge, the hero and banners.
Output goes to `docs/media/store/`. Nothing here ships in the game pack.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_readme_media as R  # noqa: E402

ROOT = R.ROOT
OUT = os.path.join(ROOT, "docs", "media", "store")
KEYART = os.path.join(OUT, "keyart")
DEFAULT_SHOTS = R.SHOTS

INK = (18, 14, 30, 255)
WHITE = (255, 251, 240, 255)
AMBER = (255, 196, 60, 255)
TEAL = (76, 214, 196, 255)
NAVY_TOP = (16, 28, 58, 255)
NAVY_BOTTOM = (8, 70, 86, 255)

# (capture, headline, word to highlight, sub-line) per language.
SCREENS = {
    "pt_BR": [
        ("ship", "TOQUE NO NAVIO", "TOQUE", "Cada toque, um contêiner"),
        ("wake_trail", "AUTOMATIZE O PORTO", "AUTOMATIZE", "Máquinas trabalham por você"),
        ("shop_upgrades", "CRESÇA SEM LIMITES", "SEM LIMITES", "De 1 contêiner a trilhões"),
        ("ports", "ABRA PORTOS PELO MUNDO", "PELO MUNDO", "Santos, Long Beach, Xangai"),
        ("landworks", "EXPANDA O TERMINAL", "EXPANDA", "Compre terreno e construa"),
        ("decor_night", "GANHE ATÉ DORMINDO", "DORMINDO", "O porto rende offline"),
    ],
    "en": [
        ("ship", "TAP THE SHIP", "TAP", "Every tap, one container"),
        ("wake_trail", "AUTOMATE YOUR PORT", "AUTOMATE", "Machines work for you"),
        ("rail", "TRAINS, TUGS, TRUCKS", "TRAINS", "A port that keeps growing"),
        ("decor_night", "EARN WHILE YOU SLEEP", "SLEEP", "Your port works offline"),
    ],
}
SHOT_DIRS = {
    "pt_BR": os.environ.get("STACKYARD_SHOTS_PT", DEFAULT_SHOTS),
    "en": os.environ.get("STACKYARD_SHOTS_EN", DEFAULT_SHOTS),
}
# App Store 6.7" and Google Play phone.
FORMATS = {"appstore": (1290, 2796), "play": (1080, 1920)}
BADGE = {"pt_BR": "IDLE CLICKER DE PORTO", "en": "IDLE PORT CLICKER"}
PITCH = {"pt_BR": ("Toque, automatize e construa", "o maior porto do mundo"),
         "en": ("Tap, automate and build", "the world's biggest port")}
FREE = {"pt_BR": "JOGUE GRÁTIS", "en": "PLAY FREE"}


# ----------------------------------------------------------------- type

class _Bitmap:
    """The game's own BMFont (`assets/fonts/harbor_font.fnt`), read directly."""

    def __init__(self) -> None:
        base = os.path.join(ROOT, "assets", "fonts")
        self.sheet = Image.open(os.path.join(base, "harbor_font.png")).convert("RGBA")
        self.chars = {}
        self.line = 11
        for row in open(os.path.join(base, "harbor_font.fnt"), encoding="utf-8"):
            parts = dict(p.split("=", 1) for p in row.split()[1:] if "=" in p)
            if row.startswith("common"):
                self.line = int(parts["lineHeight"])
            elif row.startswith("char "):
                self.chars[int(parts["id"])] = {k: int(parts[k]) for k in (
                    "x", "y", "width", "height", "xoffset", "yoffset", "xadvance")}

    def width(self, message: str) -> int:
        return sum(self.chars.get(ord(c), self.chars[32])["xadvance"] for c in message)

    def draw(self, img: Image.Image, x: int, y: int, message: str, colour) -> None:
        for ch in message:
            g = self.chars.get(ord(ch), self.chars[32])
            if g["width"] and g["height"]:
                glyph = self.sheet.crop((g["x"], g["y"], g["x"] + g["width"],
                                         g["y"] + g["height"]))
                mask = glyph.getchannel("A")
                solid = Image.new("RGBA", glyph.size, colour)
                img.paste(solid, (x + g["xoffset"], y + g["yoffset"]), mask)
            x += g["xadvance"]


BITMAP = None


def words(message: str, scale: int, fill=WHITE, highlight: str = "") -> Image.Image:
    """One line of the game's font: one-pixel ink outline and drop shadow drawn
    at the font's own pixel, then scaled by a whole number — the exact way the
    game draws its type, so captions and screenshots are one family."""
    global BITMAP
    if BITMAP is None:
        BITMAP = _Bitmap()
    w = BITMAP.width(message) + 4
    h = BITMAP.line + 4
    spans = [(message, fill)]
    if highlight and highlight in message:
        head, tail = message.split(highlight, 1)
        spans = [(head, fill), (highlight, AMBER), (tail, fill)]
    face = Image.new("RGBA", (w, h))
    x = 1
    for chunk, colour in spans:
        BITMAP.draw(face, x, 1, chunk, colour)
        x += BITMAP.width(chunk)
    mask = face.getchannel("A").point(lambda a: 255 if a > 0 else 0)
    ink = Image.new("RGBA", (w, h), INK)
    out = Image.new("RGBA", (w, h))
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1),
                   (1, 2), (2, 2), (0, 2)):   # outline, then the shadow below-right
        out.paste(ink, (dx, dy), mask)
    out.alpha_composite(face)
    out = out.crop(out.getbbox())
    return out.resize((out.width * scale, out.height * scale), Image.NEAREST)


def fit(message: str, scale: int, max_width: int, **kw) -> Image.Image:
    img = words(message, scale, **kw)
    while img.width > max_width and scale > 1:
        scale -= 1
        img = words(message, scale, **kw)
    return img


def badge(message: str, scale: int, colour=AMBER) -> Image.Image:
    """A pixel plate in amber — where the game says what kind of game it is."""
    text_img = words(message, scale, fill=INK)
    # Ink-on-amber reads cleaner without the outline the words carry.
    global BITMAP
    w = BITMAP.width(message) + 8
    h = BITMAP.line + 5
    plate = Image.new("RGBA", (w + 1, h + 1))
    d = ImageDraw.Draw(plate)
    d.rectangle((1, 1, w, h), fill=INK)                 # shadow
    d.rectangle((0, 0, w - 1, h - 1), fill=INK)
    d.rectangle((1, 1, w - 2, h - 2), fill=colour)
    d.line((1, 1, w - 2, 1), fill=(255, 230, 150, 255))
    for cx, cy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        plate.putpixel((cx, cy), (0, 0, 0, 0))
    BITMAP.draw(plate, 4, 2, message, INK)
    del text_img
    return plate.resize((plate.width * scale, plate.height * scale), Image.NEAREST)


# ----------------------------------------------------------------- brand art

_LOGO = None


def logo() -> Image.Image:
    """The generated STACKYARD logo, keyed out of its flat magenta ground."""
    global _LOGO
    if _LOGO is None:
        src = Image.open(os.path.join(KEYART, "logo.png")).convert("RGBA")
        px = src.load()
        for y in range(src.height):
            for x in range(src.width):
                r, g, b, _ = px[x, y]
                m = min(r, b) - g          # how magenta the pixel is
                if m > 110:
                    px[x, y] = (0, 0, 0, 0)
                elif m > 30:
                    # The anti-aliased fringe: fade it and take the pink out.
                    a = int(255 * (110 - m) / 80)
                    px[x, y] = (max(0, r - m), g, max(0, b - m), a)
        _LOGO = src.crop(src.getbbox())
    return _LOGO


def logo_at(width: int, max_height: int = 0) -> Image.Image:
    """The crane-lifted logo (gen_brand_logo.py) when it has been built.

    The lockup is a whole crane now, legs to apex, so it is nearly as tall as
    it is wide: a banner has to be able to cap it by height as well."""
    crane = os.path.join(OUT, "brand", "logo_crane.png")
    art = Image.open(crane).convert("RGBA") if os.path.exists(crane) else logo()
    if max_height and art.height * width / art.width > max_height:
        width = round(art.width * max_height / art.height)
    return art.resize((width, round(art.height * width / art.width)), Image.LANCZOS)


def cover(img: Image.Image, w: int, h: int, anchor_y: float = 0.5) -> Image.Image:
    k = max(w / img.width, h / img.height)
    big = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
    x = (big.width - w) // 2
    y = round((big.height - h) * anchor_y)
    return big.crop((x, y, x + w, y + h))


def backdrop(w: int, h: int) -> Image.Image:
    """Navy into harbour teal, with the port strip faint behind it."""
    grad = Image.new("RGBA", (1, 256))
    for y in range(256):
        t = y / 255
        grad.putpixel((0, y), tuple(round(a + (b - a) * t)
                                    for a, b in zip(NAVY_TOP, NAVY_BOTTOM)))
    img = grad.resize((w, h), Image.BILINEAR)
    texture = R.backdrop(w, h)
    texture.putalpha(46)
    img.alpha_composite(texture)
    return img


def glow(img: Image.Image, radius: int = 28, alpha: int = 120) -> Image.Image:
    """A soft dark halo behind a cut-out, so it lifts off busy key art."""
    halo = Image.new("RGBA", img.size)
    mask = img.getchannel("A").point(lambda a: alpha if a > 20 else 0)
    halo.putalpha(mask)
    pad = radius * 2
    out = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2))
    out.alpha_composite(halo, (pad, pad))
    out = out.filter(ImageFilter.GaussianBlur(radius))
    out.alpha_composite(img, (pad, pad))
    return out


def tap_marker(img: Image.Image, at, size: int) -> None:
    """Rings where a finger would land, so screen one *shows* the tap."""
    draw = ImageDraw.Draw(img)
    x, y = at
    for i, r in enumerate((size, size * 0.66, size * 0.33)):
        draw.ellipse((x - r, y - r, x + r, y + r), outline=(255, 255, 255, 230 - i * 40),
                     width=max(4, size // 14))
    draw.ellipse((x - size * 0.14, y - size * 0.14, x + size * 0.14, y + size * 0.14),
                 fill=AMBER)


# ----------------------------------------------------------------- outputs

def save(img: Image.Image, *parts: str) -> None:
    # JPEG at high quality: both stores and every social site take it, and the
    # PNGs of these gradients and photos-of-pixels were ~56 MB for one set.
    path = os.path.splitext(os.path.join(OUT, *parts))[0] + ".jpg"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.convert("RGB").save(path, quality=92, optimize=True, subsampling=0)
    print(f"  {os.path.relpath(path, OUT)}  {img.width}x{img.height}")


def screen(lang: str, fmt: str, index: int, spec) -> None:
    name, headline, hot, sub = spec
    w, h = FORMATS[fmt]
    path = os.path.join(SHOT_DIRS[lang], f"closeup_{name}.png")
    if not os.path.exists(path):
        print(f"  {lang}/{fmt}: no capture for {name}, skipped")
        return
    img = backdrop(w, h)
    unit = w / 1290
    margin = round(70 * unit)
    blocks = []
    if index == 0:
        blocks.append(glow(logo_at(round(w * 0.94), round(h * 0.3)), round(18 * unit), 140))
        blocks.append(badge(BADGE[lang], max(3, round(6 * unit))))
    blocks.append(fit(headline, max(4, round(11 * unit)), w - margin * 2, highlight=hot))
    blocks.append(fit(sub, max(4, round(7 * unit)), w - margin * 2, fill=(206, 236, 240, 255)))
    head_h = sum(b.height for b in blocks) + round(18 * unit) * (len(blocks) - 1)
    shot = Image.open(path).convert("RGBA")
    room = h - head_h - round(110 * unit)
    shot_w = min(round(w * 0.9), round((room - 88) * shot.width / shot.height))
    shot = shot.resize((shot_w, round(shot.height * shot_w / shot.width)), Image.LANCZOS)
    if index == 0:
        tap_marker(shot, (shot.width * 0.84, shot.height * 0.40), round(shot.width * 0.075))
    framed = R.phone(shot)
    gap = max(round(24 * unit), (h - head_h - framed.height) // 3)
    y = gap
    for block in blocks:
        img.alpha_composite(block, ((w - block.width) // 2, y))
        y += block.height + round(18 * unit)
    img.alpha_composite(framed, ((w - framed.width) // 2, h - framed.height - gap // 2))
    save(img, lang, fmt, f"{index + 1:02d}_{name}.png")


def hero(art: Image.Image, w: int, h: int, lang: str, logo_w: float, left: bool) -> Image.Image:
    """Key art with the logo, the badge and the pitch over its open water."""
    img = art.copy()
    mark = glow(logo_at(round(w * logo_w), round(h * (0.56 if left else 0.56))),
                round(h * 0.03), 150)
    tag = badge(BADGE[lang], max(2, round(h / 160)))
    lines = [fit(t, max(2, round(h / 150)), round(w * (0.48 if left else 0.92)))
             for t in PITCH[lang]]
    pitch = Image.new("RGBA", (max(l.width for l in lines), sum(l.height for l in lines)))
    y_line = 0
    for l in lines:
        pitch.alpha_composite(l, ((pitch.width - l.width) // 2, y_line))
        y_line += l.height
    stack_h = mark.height + tag.height + pitch.height
    x_mid = round(w * 0.25) if left else w // 2
    y = (h - stack_h) // 2 if left else round(h * 0.04)
    for part in (mark, tag, pitch):
        img.alpha_composite(part, (max(0, x_mid - part.width // 2), y))
        y += part.height + round(h * 0.01)
    return img


def social(lang: str) -> None:
    wide = Image.open(os.path.join(KEYART, "keyart_wide.png")).convert("RGBA")
    square = Image.open(os.path.join(KEYART, "keyart_square.png")).convert("RGBA")
    save(hero(cover(wide, 1920, 1080, 0.4), 1920, 1080, lang, 0.56, True),
         lang, "social_1920x1080.png")
    save(hero(cover(square, 1080, 1080), 1080, 1080, lang, 0.96, False),
         lang, "social_1080x1080.png")
    save(hero(cover(wide, 1500, 500, 0.45), 1500, 500, lang, 0.50, True),
         lang, "header_1500x500.png")
    # The link preview a chat app draws for the landing (og:image).
    save(hero(cover(wide, 1200, 630, 0.4), 1200, 630, lang, 0.56, True),
         lang, "og_1200x630.png")


def feature_graphic() -> None:
    """Google Play's 1024x500: key art, logo and pitch over the open sea."""
    art = cover(Image.open(os.path.join(KEYART, "keyart_wide.png")).convert("RGBA"),
                1024, 500, 0.35)
    save(hero(art, 1024, 500, "en", 0.54, True), "feature_graphic_1024x500.png")


def brand() -> None:
    save_rgba = os.path.join(OUT, "brand")
    os.makedirs(save_rgba, exist_ok=True)
    logo().save(os.path.join(save_rgba, "logo_transparent.png"))
    print("  brand/logo_transparent.png")


def main() -> None:
    # `logo` redoes only the pieces that carry the lockup (first screen of each
    # set, banners, feature graphic), for when the logo changed and the other
    # captures did not.
    logo_only = "logo" in sys.argv[1:]
    brand()
    for lang, specs in SCREENS.items():
        for fmt in FORMATS:
            for index, spec in enumerate(specs[:1] if logo_only else specs):
                screen(lang, fmt, index, spec)
        social(lang)
    feature_graphic()


if __name__ == "__main__":
    main()
