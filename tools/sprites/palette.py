"""HarborClick palette — Stardew-flavoured: warm, earthy, softly shaded.
Top-down view. Light comes from the upper-left; every object gets a warm top
face, a cooler right/bottom shade, and a soft brown-plum outline.

Materials that need more than three steps are built with `ramp()`, the
hue-shifted ramp from the vendored pixel-art-studio library: shadows rotate
toward blue, highlights toward yellow, saturation peaks at the midtone. A shade
is never just the base colour with the lights turned down — that is what made
the old art read flat.
"""
import os as _os
import sys as _sys

_sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "vendor"))
from pixelstudio import hex2rgba as _hex2rgba  # noqa: E402
from pixelstudio import ramp as _ramp  # noqa: E402


def ramp(base, steps=5, hue_shift=14.0, dark=0.38, light=0.62):
    """A hue-shifted shading ramp, dark -> light, as RGBA tuples.

    With an odd `steps` the middle entry is `base` exactly, so a ramp built
    from an existing palette colour keeps that colour as its midtone."""
    if isinstance(base, (tuple, list)):
        base = "#%02x%02x%02x" % tuple(base[:3])
    return [_hex2rgba(c) for c in _ramp(base, steps, hue_shift, dark, light)]


def mix(a, b, t=0.5):
    """Blend two RGBA colours; alpha comes from `a`."""
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (a[3] if len(a) > 3 else 255,)


def with_alpha(c, alpha):
    return tuple(c[:3]) + (alpha,)


# --- Outlines / ink (warm, never pure black) ---
OUTLINE = (58, 42, 52, 255)
OUTLINE_SOFT = (92, 72, 82, 255)
SHADOW = (58, 46, 58, 90)            # drop shadow (semi-transparent)

# --- Water (top-down harbour water) ---
SEA_DEEP = (44, 96, 130, 255)
SEA = (62, 126, 158, 255)
SEA_LIGHT = (92, 158, 184, 255)
SEA_SPARK = (168, 214, 224, 255)
FOAM = (226, 240, 240, 255)

# --- Paved yard (warm asphalt) ---
YARD_D = (96, 88, 92, 255)
YARD = (122, 114, 116, 255)
YARD_L = (146, 138, 138, 255)
YARD_PATCH = (108, 98, 100, 255)

# --- Concrete quay ---
QUAY_D = (140, 128, 118, 255)
QUAY = (172, 160, 146, 255)
QUAY_L = (200, 188, 172, 255)

# --- Road paint ---
PAINT_W = (232, 226, 208, 255)
PAINT_Y = (226, 182, 78, 255)

# --- Dirt / unbought land ---
DIRT_D = (122, 88, 58, 255)
DIRT = (152, 114, 76, 255)
DIRT_L = (182, 144, 100, 255)
GRASS_D = (78, 122, 62, 255)
GRASS = (106, 156, 78, 255)
GRASS_L = (140, 186, 100, 255)

# --- Steel / machinery frames ---
STEEL_D = (94, 90, 104, 255)
STEEL = (130, 126, 138, 255)
STEEL_L = (170, 166, 176, 255)

# --- Machine paint ---
SAFETY_D = (198, 134, 40, 255)
SAFETY = (238, 176, 62, 255)
SAFETY_L = (252, 212, 116, 255)
CRANE_D = (150, 60, 58, 255)         # STS/RTG red-orange
CRANE = (200, 92, 78, 255)
CRANE_L = (232, 138, 112, 255)
TEAL_D = (46, 116, 116, 255)
TEAL = (72, 156, 150, 255)
TEAL_L = (122, 196, 182, 255)

# --- Ship ---
HULL_D = (48, 66, 94, 255)
HULL = (70, 94, 128, 255)
HULL_L = (104, 132, 168, 255)
DECK_D = (110, 96, 88, 255)
DECK = (140, 124, 112, 255)
DECK_L = (170, 154, 138, 255)
SUPER_W = (226, 218, 202, 255)       # superstructure cream
SUPER_W_D = (182, 172, 158, 255)
HATCH = (128, 118, 118, 255)
HATCH_L = (156, 146, 144, 255)

# --- Containers (top face, side/shadow) ---
CONTAINERS = {
    "rust":   ((186, 92, 62, 255),  (140, 64, 46, 255)),
    "blue":   ((72, 116, 172, 255), (48, 82, 130, 255)),
    "green":  ((92, 148, 88, 255),  (62, 110, 62, 255)),
    "amber":  ((216, 152, 62, 255), (166, 110, 42, 255)),
    "sand":   ((206, 186, 138, 255),(160, 142, 102, 255)),
    "cream":  ((214, 208, 190, 255),(166, 160, 146, 255)),
    "plum":   ((142, 96, 138, 255), (102, 66, 102, 255)),
    "teal":   ((76, 150, 146, 255), (48, 110, 110, 255)),
}
CONTAINER_NAMES = list(CONTAINERS.keys())
## Five steps per livery, darkest first: 0 is the selout and the bottom rail,
## 1 the shaded side wall, 2 the roof, 3 the lit corrugation, 4 the glint.
CONTAINER_RAMPS = {name: ramp(top, 5, hue_shift=16.0, dark=0.42, light=0.55)
                   for name, (top, _side) in CONTAINERS.items()}

# --- People (top-down) ---
SKIN = (236, 190, 152, 255)
SKIN_D = (200, 152, 116, 255)
SKIN_DARK = (166, 118, 82, 255)
SKIN_DARK_D = (128, 88, 60, 255)
HAIR_1 = (86, 58, 42, 255)
HAIR_2 = (48, 40, 44, 255)
HAIR_3 = (162, 118, 62, 255)
VEST = (238, 150, 54, 255)
VEST_L = (252, 194, 96, 255)
VEST_D = (192, 110, 34, 255)
HELMET = (240, 196, 66, 255)
HELMET_D = (196, 152, 40, 255)
HELMET_W = (228, 224, 214, 255)
PANTS = (74, 84, 118, 255)
PANTS_D = (54, 62, 92, 255)
BOOTS = (72, 56, 52, 255)

# --- Vegetation ---
TREE_D = (52, 92, 56, 255)
TREE = (76, 124, 68, 255)
TREE_L = (110, 160, 86, 255)
TRUNK = (98, 70, 46, 255)
BUSH = (88, 134, 74, 255)
BUSH_L = (124, 172, 92, 255)

# --- Sky / celestial (used by the lighting tint, not drawn as sky) ---
SUN = (252, 232, 160, 255)
MOON = (232, 234, 240, 255)
STAR = (250, 246, 214, 255)

# --- Misc ---
GLASS = (146, 194, 208, 255)
GLASS_D = (100, 152, 174, 255)
WINDOW_LIT = (252, 214, 128, 255)
ROOF_RED = (166, 82, 68, 255)
ROOF_RED_D = (124, 58, 52, 255)
ROOF_RED_L = (200, 116, 92, 255)
ROOF_BLUE = (78, 106, 140, 255)
ROOF_BLUE_D = (56, 78, 108, 255)
WOOD = (150, 108, 68, 255)
WOOD_D = (112, 78, 48, 255)
WOOD_L = (186, 146, 96, 255)
RUST = (154, 96, 58, 255)
TIRE = (62, 56, 62, 255)
TIRE_L = (92, 86, 92, 255)
RED_LIGHT = (238, 92, 78, 255)
GREEN_LIGHT = (104, 216, 120, 255)
SMOKE = (196, 190, 190, 255)
TRANSPARENT = (0, 0, 0, 0)


# --- Hue shifting the three-step materials ----------------------------------
# Every `X_D, X, X_L` triple above was drawn as one colour with the lights
# turned up and down. The values are kept — the generators were designed around
# those steps — but the shade now rotates toward blue and the light toward
# yellow, the way light and shadow actually tint a surface. One pass here
# reaches every sprite drawn from these names.

def _shift(c, target_deg, amount_deg, sat_mul):
    import colorsys
    r, g, b = (v / 255.0 for v in c[:3])
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s < 0.04:
        # Greys have no hue to rotate; give them a whisper of one instead.
        h, s = target_deg / 360.0, 0.06 * sat_mul
    else:
        deg = h * 360.0
        diff = ((target_deg - deg + 180.0) % 360.0) - 180.0
        deg += max(-amount_deg, min(amount_deg, diff))
        h, s = (deg % 360.0) / 360.0, min(1.0, s * sat_mul)
    rr, gg, bb = colorsys.hsv_to_rgb(h, s, v)
    return (round(rr * 255), round(gg * 255), round(bb * 255), c[3] if len(c) > 3 else 255)


_HUE_SHIFTED = ("YARD", "QUAY", "DIRT", "GRASS", "STEEL", "SAFETY", "CRANE", "TEAL",
                "HULL", "DECK", "ROOF_RED", "ROOF_BLUE", "WOOD", "TREE", "VEST",
                "SUPER_W", "GLASS")
for _name in _HUE_SHIFTED:
    _g = globals()
    if _name + "_D" in _g:
        _g[_name + "_D"] = _shift(_g[_name + "_D"], 235.0, 12.0, 1.12)
    if _name + "_L" in _g:
        _g[_name + "_L"] = _shift(_g[_name + "_L"], 55.0, 9.0, 0.9)
del _g, _name
