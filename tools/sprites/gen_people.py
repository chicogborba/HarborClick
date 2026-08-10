"""Top-down dock workers, Stardew-ish: hard hat and hi-vis vest seen from above.

worker_sheet: 12 frames of 12x16.
  0-3   walking sideways (facing right; flip X for left)
  4-7   walking down (toward the viewer)
  8-11  walking up (away)
"""
import palette as P
from common import new_img, rect, hline, vline, px, outline, sheet, save

## A worker has to read as tiny next to a 40ft box, so the figure is only a
## handful of pixels: hard hat, vest shoulders, two boots.
FW, FH = 9, 12


def _legs(img, frame, cx, top):
    swing = (0, 1, 0, -1)[frame]
    px(img, cx - 2, top + maxi0(swing), P.PANTS)
    px(img, cx + 1, top + maxi0(-swing), P.PANTS)
    px(img, cx - 2, top + 1 + maxi0(swing), P.BOOTS)
    px(img, cx + 1, top + 1 + maxi0(-swing), P.BOOTS)


def maxi0(v):
    return 1 if v > 0 else 0


def _body(img, frame, cx, top):
    bob = 1 if frame % 2 else 0
    rect(img, cx - 3, top + bob, 6, 4, P.VEST)
    hline(img, cx - 3, top + bob, 6, P.VEST_L)
    hline(img, cx - 3, top + 2 + bob, 6, P.VEST_L)
    vline(img, cx + 2, top + bob, 4, P.VEST_D)
    swing = (0, 1, 0, -1)[frame]
    px(img, cx - 4, top + 1 + bob + maxi0(swing), P.SKIN)
    px(img, cx + 3, top + 1 + bob + maxi0(-swing), P.SKIN)
    return bob


def _hat(img, cx, top, face=None):
    rect(img, cx - 2, top, 5, 3, P.HELMET)
    hline(img, cx - 2, top, 5, (252, 216, 108, 255))
    hline(img, cx - 2, top + 2, 5, P.HELMET_D)
    if face == "down":
        rect(img, cx - 1, top + 3, 3, 1, P.SKIN)
    elif face == "side":
        px(img, cx + 1, top + 3, P.SKIN)
        px(img, cx + 2, top + 3, P.SKIN)


def frame_side(i):
    img = new_img(FW, FH)
    cx = 4
    _legs(img, i, cx, 9)
    bob = _body(img, i, cx, 4)
    _hat(img, cx, bob, "side")
    return outline(img)


def frame_down(i):
    img = new_img(FW, FH)
    cx = 4
    _legs(img, i, cx, 9)
    bob = _body(img, i, cx, 4)
    _hat(img, cx, bob, "down")
    return outline(img)


def frame_up(i):
    img = new_img(FW, FH)
    cx = 4
    _legs(img, i, cx, 9)
    bob = _body(img, i, cx, 4)
    _hat(img, cx, bob, None)
    px(img, cx - 1, 7 + bob, P.VEST_L)
    px(img, cx + 1, 7 + bob, P.VEST_L)
    return outline(img)


def gen_worker():
    frames = [frame_side(i) for i in range(4)]
    frames += [frame_down(i) for i in range(4)]
    frames += [frame_up(i) for i in range(4)]
    save(sheet(frames), "worker_sheet")


## The helmet on its own, in greys, frame-aligned to worker_sheet.
##
## A named crew member can be given a helmet colour, and the game finds them in
## the yard by it. Tinting the whole worker sprite would recolour the vest, the
## boots and the skin, so the helmet is a separate overlay — and it is drawn in
## light-to-dark greys rather than in a colour, so `modulate` multiplies it into a
## properly shaded helmet instead of a flat patch.
HAT_HI = (255, 255, 255, 255)
HAT_MID = (222, 222, 222, 255)
HAT_LO = (170, 170, 170, 255)


def hat_frame(i):
    img = new_img(FW, FH)
    cx = 4
    top = 1 if i % 2 else 0          # follows _body's bob exactly
    rect(img, cx - 2, top, 5, 3, HAT_MID)
    hline(img, cx - 2, top, 5, HAT_HI)
    hline(img, cx - 2, top + 2, 5, HAT_LO)
    return img


def gen_worker_hat():
    # Same twelve slots as the body sheet; the helmet does not change with
    # facing, only with the walk bob, so every facing reuses the same pair.
    save(sheet([hat_frame(i) for i in range(12)]), "worker_hat")


## The party hat, frame-aligned to `worker_sheet` exactly like the helmet, and
## drawn in the same light-to-dark greys so `modulate` gives every crew member a
## different colour cone instead of a flat patch. It is the same twelve slots and
## the same bob: the yard has to be able to swap one sheet for the other without
## the head moving a pixel.
def party_frame(i):
    img = new_img(FW, FH)
    cx = 4
    top = 1 if i % 2 else 0
    # Cone: three rows, widening down, with a lit left face.
    px(img, cx, top, HAT_HI)
    hline(img, cx - 1, top + 1, 3, HAT_MID)
    px(img, cx - 1, top + 1, HAT_HI)
    hline(img, cx - 2, top + 2, 5, HAT_LO)
    px(img, cx - 2, top + 2, HAT_MID)
    # The pom on top, one pixel proud of the point.
    px(img, cx, top - 1 if top else 0, HAT_HI)
    return img


def gen_party_hat():
    save(sheet([party_frame(i) for i in range(12)]), "worker_hat_party")


def gen_foreman():
    """Tutorial portrait: white hard hat, clipboard. 3 frames of idle sway."""
    FW, FH = 12, 16
    frames = []
    for i in range(3):
        img = new_img(FW, FH)
        cx = 6
        sway = (0, 1, 0)[i]
        rect(img, cx - 3, 11, 2, 3, P.PANTS)
        rect(img, cx + 1, 11, 2, 3, P.PANTS)
        px(img, cx - 3, 13, P.BOOTS)
        px(img, cx + 2, 13, P.BOOTS)
        rect(img, cx - 4, 5 + sway, 8, 6, (216, 132, 62, 255))
        hline(img, cx - 4, 5 + sway, 8, (240, 168, 92, 255))
        hline(img, cx - 4, 7 + sway, 8, P.VEST_L)
        px(img, cx - 5, 7 + sway, P.SKIN_DARK)
        px(img, cx + 4, 7 + sway, P.SKIN_DARK)
        # white hard hat
        rect(img, cx - 3, sway, 6, 5, P.HELMET_W)
        hline(img, cx - 3, sway, 6, (244, 242, 236, 255))
        hline(img, cx - 3, 4 + sway, 6, (188, 184, 176, 255))
        rect(img, cx - 2, 5 + sway, 4, 2, P.SKIN_DARK)
        px(img, cx - 2, 5 + sway, P.OUTLINE)
        px(img, cx + 1, 5 + sway, P.OUTLINE)
        # clipboard tucked under the arm
        rect(img, cx + 4, 8 + sway, 3, 4, P.WOOD_L)
        hline(img, cx + 4, 8 + sway, 3, P.PAINT_W)
        frames.append(outline(img))
    save(sheet(frames), "foreman_sheet")


## ------------------------------------------------------------ ID photographs
##
## The yard sprite is nine pixels wide. Blown up on a card it is four rectangles,
## which is why the personnel card had no picture on it at all and read as a form
## rather than as somebody's badge. These are head-and-shoulders portraits drawn
## at a size that can carry a face: taken against the same flat backdrop, in the
## vest they work in, so a wall of them reads as one set of staff photographs.
##
## Eight of them. The first pass drew every face from the same mould — a
## perfect ellipse head, a full-width eyebrow slab sitting on the hairline, and
## an eye made of one dark pixel jammed against one stark white one — and it
## read as a mannequin rather than a co-worker: the crew's names are half
## masculine and half feminine, but the portrait set had exactly one hairstyle
## and no version of it was ever chosen to fit the person it was drawn for.
## `FEMININE` marks which half of the set that is, and `NpcCatalog` decides who
## gets pulled from which half — see `presents_feminine()` there and in
## `npc_profile.gd`. The face itself is plainer than before on purpose: fewer
## brush strokes read as a person at 24x28 more reliably than more of them do,
## a lesson the old eyebrow-and-highlight combo learned the hard way.
##
## Picked from the person's uid, so the same operator always has the same
## face. The hard hat is a separate greyscale overlay for the same reason the
## walking sprite's is: a named crew member's helmet colour has to multiply
## into a shaded hat, not flatten it into a patch.
PORTRAIT_W, PORTRAIT_H = 24, 28
PORTRAIT_COUNT = 8

BACKDROP = (118, 138, 158, 255)
BACKDROP_L = (146, 166, 184, 255)
BACKDROP_D = (92, 110, 130, 255)

# Row half-widths for the head, hand-tuned rather than an ellipse formula: a
# jaw that tapers reads as a face, and a perfect oval reads as a balloon.
HEAD_ROWS = {
    6: 3, 7: 5, 8: 6, 9: 6, 10: 7, 11: 7, 12: 7, 13: 7,
    14: 7, 15: 7, 16: 6, 17: 6, 18: 5, 19: 4, 20: 3,
}
HEAD_CX = 12
HEAD_TOP, HEAD_BOTTOM = 6, 20

# index 0-3 short hair, one variant bearded, one moustached, one grey and
# clean; index 4-7 hair past the jaw, never facial hair.
FEMININE = [False, False, False, False, True, True, True, True]
SKINS = [P.SKIN, P.SKIN_D, P.SKIN_DARK, P.SKIN_DARK_D,
         P.SKIN_D, P.SKIN, P.SKIN_DARK_D, P.SKIN_DARK]
HAIRS = [
    (66, 46, 38, 255), (30, 27, 31, 255), (150, 88, 46, 255), (150, 148, 150, 255),
    (54, 35, 30, 255), (26, 23, 27, 255), (128, 66, 42, 255), (172, 168, 168, 255),
]
## 0 clean shaven, 1 full beard, 2 moustache. Only the masculine half ever
## carries one.
BEARDS = [0, 1, 2, 0, 0, 0, 0, 0]


def _shade(color, k):
    return (int(color[0] * k), int(color[1] * k), int(color[2] * k), 255)


def _head_half(y):
    return HEAD_ROWS.get(y, 0)


def _draw_head(img, skin, dark):
    for y in range(HEAD_TOP, HEAD_BOTTOM + 1):
        half = _head_half(y)
        if half <= 0:
            continue
        rect(img, HEAD_CX - half, y, half, 1, skin)
        rect(img, HEAD_CX, y, half, 1, dark)
    ear_y = (HEAD_TOP + HEAD_BOTTOM) // 2
    half = _head_half(ear_y)
    px(img, HEAD_CX - half - 1, ear_y, skin)
    px(img, HEAD_CX + half, ear_y, dark)


def _draw_hair(img, hair, hair_l, feminine, fringe_shift):
    ## The cap: the top third of the head silhouette, cut by a fringe line
    ## that sits a little lower on one side than the other.
    for y in range(HEAD_TOP, HEAD_TOP + 5):
        half = _head_half(y)
        if half <= 0:
            continue
        cut = half if y < HEAD_TOP + 2 else max(0, half - 2 - fringe_shift)
        rect(img, HEAD_CX - half, y, half - cut + half, 1, hair)
        # a lit strip along the crown, so the cap reads as hair and not ink
        if y == HEAD_TOP:
            hline(img, HEAD_CX - half, y, half * 2, hair_l)
    if not feminine:
        return
    # A solid curtain flanking the face, from the temple down past the
    # shoulder — width is what reads as hair; the wire-thin first draft of
    # this read as a chinstrap instead.
    for y in range(HEAD_TOP + 2, HEAD_BOTTOM + 5):
        half = _head_half(min(y, HEAD_BOTTOM))
        width = 4 if y <= HEAD_BOTTOM else 3
        rect(img, HEAD_CX - half - width, y, width, 1, hair)
        rect(img, HEAD_CX + half, y, width, 1, hair)
        if y % 3 == 0:
            px(img, HEAD_CX - half - width, y, hair_l)
            px(img, HEAD_CX + half + width - 1, y, hair_l)


def _draw_face(img, skin, dark, shadow):
    ## One dark pixel per eye, a one-pixel nose shadow, one short mouth line.
    ## The old brow-plus-highlight version was busier than a 24px face can
    ## carry and read as startled; this reads as a face from across a room,
    ## which is the only distance this asset is ever seen from.
    for eye_x in (HEAD_CX - 3, HEAD_CX + 2):
        px(img, eye_x, 14, (44, 37, 41, 255))
    px(img, HEAD_CX - 1, 16, shadow)
    px(img, HEAD_CX, 16, shadow)
    hline(img, HEAD_CX - 2, 18, 4, shadow)


def _draw_beard(img, hair, shadow, style):
    if style == 1:
        for y in range(17, HEAD_BOTTOM + 1):
            half = max(2, _head_half(y) - 1)
            for x in range(HEAD_CX - half, HEAD_CX + half):
                if not (17 <= y <= 18 and HEAD_CX - 2 <= x < HEAD_CX + 2):
                    px(img, x, y, hair)
        hline(img, HEAD_CX - 2, 18, 4, shadow)          # the mouth in the beard
    elif style == 2:
        hline(img, HEAD_CX - 3, 17, 6, hair)


def _portrait(index):
    img = new_img(PORTRAIT_W, PORTRAIT_H)
    feminine = FEMININE[index % len(FEMININE)]
    skin = SKINS[index % len(SKINS)]
    dark = _shade(skin, 0.80)
    shadow = _shade(skin, 0.62)
    hair = HAIRS[index % len(HAIRS)]
    hair_l = _shade(hair, 1.35)
    beard = BEARDS[index % len(BEARDS)]

    # Flat studio backdrop, lit from the upper left like everything else.
    rect(img, 0, 0, PORTRAIT_W, PORTRAIT_H, BACKDROP)
    for y in range(PORTRAIT_H):
        for x in range(PORTRAIT_W):
            if x + y < 15:
                px(img, x, y, BACKDROP_L)
            elif x + y > 42:
                px(img, x, y, BACKDROP_D)

    # Shoulders, cropped by the frame the way a badge photo is.
    for y in range(21, PORTRAIT_H):
        half = min(11, 4 + (y - 21) * 2)
        rect(img, 12 - half, y, half * 2, 1, P.VEST)
    hline(img, 8, 21, 8, P.VEST_L)
    hline(img, 2, 25, 20, P.VEST_L)          # the reflective band
    hline(img, 2, 26, 20, P.VEST_D)
    rect(img, 9, 19, 6, 3, dark)             # neck, in its own shadow
    hline(img, 9, 21, 6, shadow)

    _draw_head(img, skin, dark)
    _draw_hair(img, hair, hair_l, feminine, index % 2)
    _draw_face(img, skin, dark, shadow)
    _draw_beard(img, hair, shadow, beard)
    return img


def gen_portraits():
    save(sheet([_portrait(i) for i in range(PORTRAIT_COUNT)]), "portrait_sheet",
         preview_scale=4)

    # The hard hat, in greys, aligned to the same 24x28 cell.
    hat = new_img(PORTRAIT_W, PORTRAIT_H)
    for y in range(PORTRAIT_H):
        for x in range(PORTRAIT_W):
            ex = (x - 11.5) / 6.2
            ey = (y - 11.0) / 6.4
            if ex * ex + ey * ey <= 1.0 and y <= 10:
                hat.putpixel((x, y), HAT_MID if x + y > 18 else HAT_HI)
    rect(hat, 4, 10, 16, 2, HAT_MID)                 # brim
    hline(hat, 4, 10, 16, HAT_HI)
    hline(hat, 4, 11, 16, HAT_LO)
    vline(hat, 11, 3, 8, HAT_HI)                     # the crown rib
    save(hat, "portrait_hat", preview_scale=4)


if __name__ == "__main__":
    print("people:")
    gen_worker()
    gen_worker_hat()
    gen_party_hat()
    gen_foreman()
    gen_portraits()
