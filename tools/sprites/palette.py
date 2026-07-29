"""HarborClick palette — Stardew-flavoured: warm, earthy, softly shaded.
Top-down view. Light comes from the upper-left; every object gets a warm top
face, a cooler right/bottom shade, and a soft brown-plum outline.
"""

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
