"""Top-down port vehicles. All face UP (north); the game rotates/flips them.

The branch-line train is not here: it is drawn facing east, at its shown size,
in `gen_train.py`."""
import palette as P
from common import new_img, rect, hline, vline, px, outline, save, speckle, sheet


def tyres(img, x, y, w, h):
    rect(img, x, y, w, h, P.TIRE)
    px(img, x, y, P.TIRE_L)


def gen_tt():
    """Terminal tractor + chassis. 20x52; container sits at y=20..44."""
    w, h = 20, 52
    img = new_img(w, h)
    # chassis rails (rear)
    rect(img, 3, 18, 14, 28, P.STEEL_D)
    hline(img, 3, 18, 14, P.STEEL)
    vline(img, 8, 20, 24, P.STEEL)
    vline(img, 11, 20, 24, P.STEEL)
    tyres(img, 1, 24, 3, 8)
    tyres(img, 16, 24, 3, 8)
    tyres(img, 1, 36, 3, 8)
    tyres(img, 16, 36, 3, 8)
    # tractor cab (front)
    rect(img, 2, 2, 16, 17, P.SAFETY)
    hline(img, 2, 2, 16, P.SAFETY_L)
    vline(img, 2, 2, 17, P.SAFETY_L)
    vline(img, 17, 2, 17, P.SAFETY_D)
    hline(img, 2, 18, 16, P.SAFETY_D)
    # windscreen + roof
    rect(img, 4, 4, 12, 6, P.GLASS)
    hline(img, 4, 4, 12, P.GLASS_D)
    px(img, 13, 5, (206, 240, 246, 255))
    rect(img, 4, 11, 12, 5, P.SAFETY_D)     # engine hood
    # headlights + beacon
    px(img, 3, 2, P.WINDOW_LIT)
    px(img, 16, 2, P.WINDOW_LIT)
    px(img, 9, 11, P.SAFETY_L)
    tyres(img, 0, 6, 3, 7)
    tyres(img, 17, 6, 3, 7)
    save(outline(img), "veh_tt")


def gen_road_cab():
    """Road tractor unit, nose up. 18x24.

    Drawn as its own sprite because a road rig is two rigid bodies, not one:
    the cab turns first and the trailer follows it round. A single 20x52 sprite
    can only ever pivot about one point, which is why the old truck's boxes
    appeared to lag through every corner — they were being carried by a body
    that was still swinging when the wheels had already changed direction.

    The fifth wheel is at y=19; `RoadTruck.HITCH` is that number.
    """
    w, h = 18, 24
    img = new_img(w, h)
    # bonnet and cab body
    rect(img, 2, 2, 14, 18, P.SAFETY)
    hline(img, 2, 2, 14, P.SAFETY_L)
    vline(img, 2, 2, 18, P.SAFETY_L)
    vline(img, 15, 2, 18, P.SAFETY_D)
    hline(img, 2, 19, 14, P.SAFETY_D)
    # windscreen, roof deflector and mirrors
    rect(img, 4, 4, 10, 6, P.GLASS)
    hline(img, 4, 4, 10, P.GLASS_D)
    px(img, 12, 5, (206, 240, 246, 255))
    rect(img, 4, 11, 10, 4, P.SAFETY_D)
    px(img, 1, 6, P.STEEL_D)
    px(img, 16, 6, P.STEEL_D)
    # fifth wheel: the plate the chassis pivots on
    rect(img, 6, 17, 6, 4, P.STEEL_D)
    hline(img, 6, 17, 6, P.STEEL)
    # headlights, marker lamps, exhaust stacks
    px(img, 3, 2, P.WINDOW_LIT)
    px(img, 14, 2, P.WINDOW_LIT)
    px(img, 8, 2, P.SAFETY_L)
    px(img, 9, 2, P.SAFETY_L)
    tyres(img, 0, 5, 3, 7)
    tyres(img, 15, 5, 3, 7)
    tyres(img, 0, 14, 3, 6)
    tyres(img, 15, 14, 3, 6)
    save(outline(img), "veh_truck_cab")


def gen_road_chassis():
    """Skeletal container chassis, kingpin up. 18x48.

    Long enough for the two twenty-foot boxes a road chassis is allowed to
    carry, which the old drawing was not: the bed was 28 px for 29 px of cargo,
    so the second box always hung off the tail.

    The three numbers `RoadTruck` reads off this drawing: the kingpin at y=2,
    box centres at y=14 and y=34, the rear axle at y=34.
    """
    w, h = 18, 48
    img = new_img(w, h)
    # drawbar reaching forward to the kingpin
    rect(img, 7, 0, 4, 7, P.STEEL_D)
    hline(img, 7, 0, 4, P.STEEL)
    # main rails and cross members: skeletal, so the deck reads as open steel
    rect(img, 3, 5, 12, 38, P.STEEL_D)
    vline(img, 4, 6, 36, P.STEEL)
    vline(img, 13, 6, 36, P.STEEL)
    for cross in (7, 14, 24, 34, 41):
        hline(img, 4, cross, 10, P.STEEL)
    # twist locks: four corners per box slot, at y=14 and y=34
    for ty in (7, 21, 27, 41):
        px(img, 3, ty, P.STEEL_L)
        px(img, 14, ty, P.STEEL_L)
    # tandem bogie under the rear box slot
    rect(img, 2, 31, 14, 2, P.STEEL_D)
    tyres(img, 0, 30, 3, 7)
    tyres(img, 15, 30, 3, 7)
    tyres(img, 0, 38, 3, 6)
    tyres(img, 15, 38, 3, 6)
    # rear underrun bar and lamps
    rect(img, 3, 45, 12, 2, P.STEEL_D)
    px(img, 5, 46, P.RED_LIGHT)
    px(img, 12, 46, P.RED_LIGHT)
    save(outline(img), "veh_truck_chassis")


def gen_forklift():
    """Container-handling forklift, 16x26."""
    w, h = 16, 26
    img = new_img(w, h)
    # forks reaching forward (up)
    rect(img, 3, 0, 2, 8, P.STEEL_L)
    rect(img, 11, 0, 2, 8, P.STEEL_L)
    rect(img, 2, 7, 12, 3, P.STEEL_D)       # carriage
    # body
    rect(img, 2, 10, 12, 13, P.SAFETY)
    hline(img, 2, 10, 12, P.SAFETY_L)
    vline(img, 13, 10, 13, P.SAFETY_D)
    hline(img, 2, 22, 12, P.SAFETY_D)
    # cab cage + seat
    rect(img, 4, 13, 8, 7, P.STEEL_D)
    rect(img, 5, 14, 6, 5, P.GLASS_D)
    px(img, 8, 15, P.GLASS)
    tyres(img, 1, 11, 2, 6)
    tyres(img, 13, 11, 2, 6)
    tyres(img, 1, 19, 2, 5)
    tyres(img, 13, 19, 2, 5)
    save(outline(img), "veh_forklift")


def gen_reach_stacker():
    """Reach stacker, 20x40. Boom folds forward over the load."""
    w, h = 20, 40
    img = new_img(w, h)
    # spreader head at the front
    rect(img, 2, 0, 16, 5, P.SAFETY_D)
    hline(img, 2, 0, 16, P.SAFETY)
    # telescopic boom
    rect(img, 6, 4, 8, 16, P.SAFETY)
    hline(img, 6, 4, 8, P.SAFETY_L)
    vline(img, 13, 4, 16, P.SAFETY_D)
    for by in range(7, 19, 4):
        hline(img, 6, by, 8, P.SAFETY_D)
    # body + counterweight
    rect(img, 2, 18, 16, 19, P.SAFETY)
    hline(img, 2, 18, 16, P.SAFETY_L)
    vline(img, 17, 18, 19, P.SAFETY_D)
    hline(img, 2, 36, 16, P.SAFETY_D)
    rect(img, 3, 30, 14, 6, P.STEEL_D)      # counterweight block
    # cab on the left side
    rect(img, 2, 21, 6, 7, P.GLASS)
    hline(img, 2, 21, 6, P.GLASS_D)
    tyres(img, 0, 20, 3, 8)
    tyres(img, 17, 20, 3, 8)
    tyres(img, 0, 30, 3, 7)
    tyres(img, 17, 30, 3, 7)
    save(outline(img), "veh_reach_stacker")


def gen_tug():
    """Harbour tug, bow up, 26x44."""
    w, h = 26, 44
    img = new_img(w, h)
    for y in range(2, h - 2):
        k = min(1.0, (y - 2) / 14.0)
        half = 4 + int((k ** 0.6) * 8)
        if y > h - 10:
            half = 12 - int((y - (h - 10)) * 0.7)
        cx = w // 2
        rect(img, cx - half, y, half * 2, 1, P.CRANE)
    # deck + shading
    for y in range(2, h - 2):
        for x in range(w):
            if img.getpixel((x, y))[3] != 0:
                px(img, x, y, P.CRANE_L)
                break
        for x in range(w - 1, -1, -1):
            if img.getpixel((x, y))[3] != 0:
                px(img, x, y, P.CRANE_D)
                break
    rect(img, 6, 14, 14, 16, P.DECK)
    speckle(img, 6, 14, 14, 16, [P.DECK_D], 0.12, seed=3)
    # wheelhouse
    rect(img, 8, 17, 10, 9, P.SUPER_W)
    hline(img, 8, 17, 10, (242, 236, 224, 255))
    rect(img, 9, 19, 8, 4, P.GLASS)
    # tyre fenders around the bow
    for fx, fy in ((5, 8), (20, 8), (3, 16), (22, 16), (4, 28), (21, 28)):
        rect(img, fx, fy, 3, 3, P.TIRE)
        px(img, fx + 1, fy + 1, P.TIRE_L)
    # funnel
    rect(img, 11, 30, 5, 5, (48, 42, 46, 255))
    save(outline(img), "veh_tug")


def gen_drone():
    """Quadcopter seen from above, 2-frame rotor blur, 18x18."""
    frames = []
    for f in range(2):
        img = new_img(18, 18)
        # arms
        for ax, ay in ((3, 3), (13, 3), (3, 13), (13, 13)):
            px(img, ax + 1, ay + 1, P.STEEL_D)
        rect(img, 3, 8, 12, 2, P.STEEL_D)
        rect(img, 8, 3, 2, 12, P.STEEL_D)
        # body
        rect(img, 6, 6, 6, 6, P.STEEL)
        hline(img, 6, 6, 6, P.STEEL_L)
        rect(img, 7, 8, 4, 3, P.GLASS_D)
        px(img, 8, 9, P.GLASS)
        # rotor discs
        for cx, cy in ((3, 3), (14, 3), (3, 14), (14, 14)):
            if f == 0:
                for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
                    px(img, cx + dx, cy + dy, P.STEEL_L)
            else:
                for dx, dy in ((-1, -1), (1, 1), (-1, 1), (1, -1)):
                    px(img, cx + dx, cy + dy, P.SMOKE)
        px(img, 2, 15, P.RED_LIGHT)
        px(img, 15, 2, P.GREEN_LIGHT)
        frames.append(outline(img))
    save(sheet(frames), "veh_drone")


if __name__ == "__main__":
    print("vehicles:")
    gen_tt()
    gen_road_cab()
    gen_road_chassis()
    gen_forklift()
    gen_reach_stacker()
    gen_tug()
    gen_drone()
