"""Shared drawing helpers for HarborClick sprite generators."""
import os
from PIL import Image, ImageDraw

import palette as P

SPRITES_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites"))
PREVIEW_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "preview"))


def new_img(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), P.TRANSPARENT)


def d(img: Image.Image) -> ImageDraw.ImageDraw:
    return ImageDraw.Draw(img)


def rect(img, x, y, w, h, color):
    """Filled rect, inclusive pixel coords + size."""
    if w <= 0 or h <= 0:
        return
    ImageDraw.Draw(img).rectangle([x, y, x + w - 1, y + h - 1], fill=color)


def hline(img, x, y, w, color):
    rect(img, x, y, w, 1, color)


def vline(img, x, y, h, color):
    rect(img, x, y, 1, h, color)


def px(img, x, y, color):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color)


def outline(img: Image.Image, color=P.OUTLINE) -> Image.Image:
    """Draw a 1px outline around every opaque region (outside the region,
    only where currently transparent). Grows the silhouette by 1px."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] != 0:
                    dst[x, y] = color
                    break
    return out


def dither_rows(img, x, y, w, h, color, offset=0):
    """Checkerboard dither fill (50%)."""
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if (xx + yy + offset) % 2 == 0:
                px(img, xx, yy, color)


def speckle(img, x, y, w, h, colors, density=0.14, seed=None):
    """Scatter texture pixels over a region — the Stardew-ish 'lived-in' look."""
    import random as _random
    rng = _random.Random(seed)
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if rng.random() < density:
                px(img, xx, yy, colors[rng.randrange(len(colors))])


def patch(img, cx, cy, rx, ry, color, seed=None):
    """Irregular blob — asphalt repairs, dirt patches, moss."""
    import random as _random
    rng = _random.Random(seed)
    for yy in range(cy - ry, cy + ry + 1):
        for xx in range(cx - rx, cx + rx + 1):
            dx = (xx - cx) / max(1.0, rx)
            dy = (yy - cy) / max(1.0, ry)
            if dx * dx + dy * dy <= 1.0 + rng.uniform(-0.22, 0.14):
                px(img, xx, yy, color)


def shadow_under(img, x, y, w, h, color=None):
    """Soft contact shadow under an object (top-down)."""
    import palette as _P
    color = color or _P.SHADOW
    for yy in range(y, y + h):
        inset = 1 if yy in (y, y + h - 1) else 0
        for xx in range(x + inset, x + w - inset):
            if 0 <= xx < img.width and 0 <= yy < img.height:
                base = img.getpixel((xx, yy))
                if base[3] == 0:
                    img.putpixel((xx, yy), color)


def sheet(frames, pad=0) -> Image.Image:
    """Horizontal strip spritesheet from equally sized frames."""
    fw, fh = frames[0].size
    out = Image.new("RGBA", ((fw + pad) * len(frames) - pad, fh), P.TRANSPARENT)
    for i, f in enumerate(frames):
        out.paste(f, (i * (fw + pad), 0))
    return out


def save(img: Image.Image, name: str, preview_scale: int = 4):
    """Save sprite PNG to assets/sprites and an upscaled preview for inspection."""
    os.makedirs(SPRITES_DIR, exist_ok=True)
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    img.save(os.path.join(SPRITES_DIR, name + ".png"))
    big = img.resize((img.width * preview_scale, img.height * preview_scale), Image.NEAREST)
    # checkerboard bg so transparency is visible in preview
    bg = Image.new("RGBA", big.size, (60, 60, 66, 255))
    ck = bg.load()
    for y in range(0, big.height, 8):
        for x in range(0, big.width, 8):
            if (x // 8 + y // 8) % 2 == 0:
                for yy in range(y, min(y + 8, big.height)):
                    for xx in range(x, min(x + 8, big.width)):
                        ck[xx, yy] = (74, 74, 82, 255)
    bg.alpha_composite(big)
    bg.save(os.path.join(PREVIEW_DIR, name + ".png"))
    print(f"  {name}.png  {img.width}x{img.height}")
