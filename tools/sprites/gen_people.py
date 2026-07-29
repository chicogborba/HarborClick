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


if __name__ == "__main__":
    print("people:")
    gen_worker()
    gen_foreman()
