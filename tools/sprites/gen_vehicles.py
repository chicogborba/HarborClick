"""Top-down port vehicles. All face UP (north); the game rotates/flips them.

The branch-line train is not here: it is drawn facing east, at its shown size,
in `gen_train.py`."""
import palette as P
from common import new_img, rect, hline, vline, px, outline, save, speckle, sheet


INK = (40, 34, 44, 255)
GLINT = (214, 242, 248, 255)
BEACON = [(214, 96, 28, 255), (255, 170, 60, 255), (255, 236, 170, 255)]
HAZARD_K = (52, 46, 54, 255)
CHROME = (206, 212, 220, 255)


def tyres(img, x, y, w, h):
    """A tyre seen from above: dark rubber, a lit shoulder, tread bars."""
    rect(img, x, y, w, h, P.TIRE)
    vline(img, x, y, h, P.TIRE_L)
    for ty in range(y + 1, y + h, 2):
        px(img, x + w - 1, ty, INK)


def body(img, x, y, w, h, ramp=None):
    """A painted steel panel lit from the north-west: a light lip on the top
    and left, a dark one on the bottom and right, and one soft band of
    highlight inside the lip so a roof reads as curved rather than flat."""
    d, m, l = ramp or (P.SAFETY_D, P.SAFETY, P.SAFETY_L)
    rect(img, x, y, w, h, m)
    hline(img, x, y, w, l)
    vline(img, x, y, h, l)
    hline(img, x, y + h - 1, w, d)
    vline(img, x + w - 1, y, h, d)
    px(img, x + w - 1, y, m)
    px(img, x, y + h - 1, m)


def glass(img, x, y, w, h):
    """A windscreen: a dark frame line on top, the pane, one diagonal glint."""
    rect(img, x, y, w, h, P.GLASS)
    hline(img, x, y, w, P.GLASS_D)
    vline(img, x, y, h, P.GLASS_D)
    for i in range(min(h - 1, 3)):
        px(img, x + w - 2 - i, y + 1 + i, GLINT)
    if w >= 8:
        px(img, x + 2, y + 1, GLINT)


def beacon(img, x, y):
    """The amber rotating lamp every yard machine carries, 2x2."""
    rect(img, x, y, 2, 2, BEACON[1])
    px(img, x, y, BEACON[2])
    px(img, x + 1, y + 1, BEACON[0])


def hazard(img, x, y, w, h=2):
    """Black-and-yellow chevron tape."""
    for i in range(w):
        for j in range(h):
            px(img, x + i, y + j,
               P.SAFETY_L if ((i + j) // 2) % 2 == 0 else HAZARD_K)


def gen_tt():
    """Terminal tractor + chassis. 20x52; container sits at y=20..44."""
    w, h = 20, 52
    img = new_img(w, h)
    # chassis rails (rear): open steel, cross members, twist locks
    rect(img, 3, 18, 14, 28, P.STEEL_D)
    hline(img, 3, 18, 14, P.STEEL)
    vline(img, 4, 19, 26, P.STEEL)
    vline(img, 15, 19, 26, P.STEEL)
    vline(img, 8, 20, 24, P.STEEL)
    vline(img, 11, 20, 24, P.STEEL)
    for cross in (24, 32, 40):
        hline(img, 5, cross, 10, P.STEEL)
    for ty in (20, 43):
        px(img, 3, ty, P.STEEL_L)
        px(img, 16, ty, P.STEEL_L)
    tyres(img, 1, 24, 3, 8)
    tyres(img, 16, 24, 3, 8)
    tyres(img, 1, 36, 3, 8)
    tyres(img, 16, 36, 3, 8)
    # tail: underrun bar in hazard tape, two red lamps
    hazard(img, 4, 46, 12, 1)
    px(img, 4, 47, P.RED_LIGHT)
    px(img, 15, 47, P.RED_LIGHT)
    # tractor cab (front)
    tyres(img, 0, 6, 3, 7)
    tyres(img, 17, 6, 3, 7)
    body(img, 2, 2, 16, 17)
    glass(img, 4, 4, 12, 5)
    # roof panel behind the screen, then the engine cover with its grille
    hline(img, 4, 10, 12, P.SAFETY_L)
    rect(img, 4, 12, 12, 5, P.SAFETY_D)
    for gx in range(5, 15, 2):
        vline(img, gx, 13, 3, INK)
    hline(img, 4, 12, 12, P.SAFETY)
    beacon(img, 9, 10)
    # headlights, mirrors, exhaust stack
    px(img, 3, 2, P.WINDOW_LIT)
    px(img, 16, 2, P.WINDOW_LIT)
    px(img, 1, 4, P.STEEL_L)
    px(img, 18, 4, P.STEEL_L)
    rect(img, 15, 15, 2, 2, CHROME)
    px(img, 16, 16, INK)
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
    tyres(img, 0, 5, 3, 7)
    tyres(img, 15, 5, 3, 7)
    tyres(img, 0, 14, 3, 6)
    tyres(img, 15, 14, 3, 6)
    # chrome bumper, then bonnet and cab body
    hline(img, 3, 1, 12, CHROME)
    body(img, 2, 2, 14, 18)
    glass(img, 4, 5, 10, 5)
    # bonnet grille ahead of the screen
    for gx in range(6, 12, 2):
        vline(img, gx, 3, 2, P.SAFETY_D)
    # sleeper roof with its wind deflector
    rect(img, 4, 11, 10, 5, P.SAFETY_D)
    hline(img, 4, 11, 10, P.SAFETY_L)
    hline(img, 5, 13, 8, P.SAFETY)
    px(img, 1, 6, P.STEEL_L)
    px(img, 16, 6, P.STEEL_L)
    # fifth wheel: the plate the chassis pivots on
    rect(img, 6, 17, 6, 4, P.STEEL_D)
    hline(img, 6, 17, 6, P.STEEL)
    px(img, 8, 19, INK)
    px(img, 9, 19, INK)
    # headlights, marker lamps, twin exhaust stacks
    px(img, 3, 2, P.WINDOW_LIT)
    px(img, 14, 2, P.WINDOW_LIT)
    px(img, 6, 11, BEACON[1])
    px(img, 11, 11, BEACON[1])
    px(img, 3, 16, CHROME)
    px(img, 14, 16, CHROME)
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
    px(img, 8, 2, P.STEEL_L)
    # main rails and cross members: skeletal, so the deck reads as open steel
    rect(img, 3, 5, 12, 38, P.STEEL_D)
    vline(img, 4, 6, 36, P.STEEL)
    vline(img, 13, 6, 36, P.STEEL)
    vline(img, 3, 6, 36, P.STEEL_L)
    for cross in (7, 14, 24, 34, 41):
        hline(img, 4, cross, 10, P.STEEL)
    # the gaps between the rails show the road
    for gy0, gy1 in ((9, 13), (16, 23), (26, 33), (36, 40)):
        rect(img, 6, gy0, 6, gy1 - gy0, INK)
    # twist locks: four corners per box slot, at y=14 and y=34
    for ty in (7, 21, 27, 41):
        px(img, 3, ty, P.SAFETY_L)
        px(img, 14, ty, P.SAFETY_L)
    # tandem bogie under the rear box slot
    rect(img, 2, 31, 14, 2, P.STEEL_D)
    tyres(img, 0, 30, 3, 7)
    tyres(img, 15, 30, 3, 7)
    tyres(img, 0, 38, 3, 6)
    tyres(img, 15, 38, 3, 6)
    # rear underrun bar in hazard tape, and lamps
    hazard(img, 3, 45, 12, 1)
    rect(img, 3, 46, 12, 1, P.STEEL_D)
    px(img, 4, 46, P.RED_LIGHT)
    px(img, 13, 46, P.RED_LIGHT)
    save(outline(img), "veh_truck_chassis")


def gen_forklift():
    """Container-handling forklift, 16x26."""
    w, h = 16, 26
    img = new_img(w, h)
    # forks reaching forward (up): lit tines with worn tips
    for fx in (3, 11):
        rect(img, fx, 0, 2, 8, P.STEEL_L)
        vline(img, fx + 1, 1, 7, P.STEEL)
        px(img, fx, 0, CHROME)
    # carriage and mast rails
    rect(img, 2, 7, 12, 3, P.STEEL_D)
    hline(img, 2, 7, 12, P.STEEL)
    px(img, 5, 8, P.STEEL_L)
    px(img, 10, 8, P.STEEL_L)
    tyres(img, 1, 11, 2, 6)
    tyres(img, 13, 11, 2, 6)
    tyres(img, 1, 19, 2, 5)
    tyres(img, 13, 19, 2, 5)
    # body
    body(img, 2, 10, 12, 13)
    # overhead guard: a cage you can see the driver's seat through
    rect(img, 4, 12, 8, 7, INK)
    glass(img, 5, 13, 6, 5)
    vline(img, 8, 13, 5, INK)
    # counterweight at the back, in hazard tape, with the beacon on it
    rect(img, 3, 20, 10, 2, P.SAFETY_D)
    hazard(img, 3, 21, 10, 1)
    beacon(img, 7, 19)
    px(img, 3, 10, P.WINDOW_LIT)
    px(img, 12, 10, P.WINDOW_LIT)
    save(outline(img), "veh_forklift")


def gen_reach_stacker():
    """Reach stacker, 20x40. Boom folds forward over the load."""
    w, h = 20, 40
    img = new_img(w, h)
    tyres(img, 0, 20, 3, 8)
    tyres(img, 17, 20, 3, 8)
    tyres(img, 0, 30, 3, 7)
    tyres(img, 17, 30, 3, 7)
    # spreader head at the front: a steel beam with four twist locks
    rect(img, 2, 0, 16, 5, P.STEEL_D)
    hline(img, 2, 0, 16, P.STEEL_L)
    hline(img, 3, 2, 14, P.STEEL)
    for tx in (2, 17):
        px(img, tx, 0, P.SAFETY_L)
        px(img, tx, 4, P.SAFETY_L)
    rect(img, 8, 1, 4, 3, P.SAFETY)
    # body + counterweight
    body(img, 2, 18, 16, 19)
    # telescopic boom: outer box, the paler inner section sliding out of it
    body(img, 6, 4, 8, 20)
    rect(img, 7, 4, 6, 7, P.SAFETY_L)
    hline(img, 7, 10, 6, P.SAFETY_D)
    for by in (14, 18):
        hline(img, 7, by, 6, P.SAFETY_D)
    # hydraulic rams either side of the boom foot
    vline(img, 5, 17, 6, CHROME)
    vline(img, 14, 17, 6, CHROME)
    # the cab, offset left as on the real machine
    rect(img, 2, 22, 5, 7, INK)
    glass(img, 2, 22, 5, 6)
    # engine deck louvres and the counterweight block
    for ly in (25, 27):
        hline(img, 9, ly, 7, P.SAFETY_D)
    rect(img, 3, 30, 14, 6, P.STEEL_D)
    hline(img, 3, 30, 14, P.STEEL)
    hazard(img, 3, 34, 14, 2)
    beacon(img, 13, 22)
    px(img, 4, 37, P.RED_LIGHT)
    px(img, 15, 37, P.RED_LIGHT)
    save(outline(img), "veh_reach_stacker")


def gen_tug():
    """Harbour tug, bow up, 26x44.

    A working boat, so it is drawn as one: a black rubbing strake right round
    the hull, a planked deck inside the bulwark, tyre fenders hung over the
    side, a wheelhouse with windows on three faces, a banded funnel and the
    towing winch on the after deck."""
    w, h = 26, 44
    img = new_img(w, h)
    cx = w // 2
    rows = {}
    for y in range(2, h - 2):
        k = min(1.0, (y - 2) / 14.0)
        half = 4 + int((k ** 0.6) * 8)
        if y > h - 10:
            half = 12 - int((y - (h - 10)) * 0.7)
        rows[y] = half
        rect(img, cx - half, y, half * 2, 1, P.CRANE)
    # bulwark: lit on the port bow, dark to starboard, then the strake
    for y, half in rows.items():
        px(img, cx - half, y, P.CRANE_L)
        px(img, cx + half - 1, y, P.CRANE_D)
        if half > 3:
            px(img, cx - half + 1, y, P.CRANE)
            px(img, cx + half - 2, y, P.CRANE_D)
    # planked deck inside the bulwark
    for y, half in rows.items():
        inner = half - 2
        if inner > 0 and 5 <= y <= h - 5:
            rect(img, cx - inner, y, inner * 2, 1,
                 P.DECK if y % 3 else P.DECK_D)
    # bow bitts and the pudding fender on the stem
    rect(img, cx - 2, 3, 4, 2, P.TIRE)
    px(img, cx - 1, 3, P.TIRE_L)
    px(img, cx - 3, 8, P.STEEL_L)
    px(img, cx + 2, 8, P.STEEL_L)
    # wheelhouse: cream, windows on three sides, a darker roof panel
    rect(img, 7, 13, 12, 12, P.SUPER_W_D)
    rect(img, 7, 13, 12, 11, P.SUPER_W)
    hline(img, 7, 13, 12, (246, 240, 228, 255))
    rect(img, 8, 14, 10, 3, P.GLASS_D)
    for wx in (8, 11, 15):
        rect(img, wx, 14, 2 if wx != 11 else 3, 3, P.GLASS)
    px(img, 16, 14, GLINT)
    px(img, 9, 14, GLINT)
    rect(img, 9, 18, 8, 5, P.SUPER_W_D)
    hline(img, 9, 18, 8, P.SUPER_W)
    # mast with the two towing lights, and the radar bar
    px(img, cx, 19, INK)
    px(img, cx, 20, P.WINDOW_LIT)
    hline(img, cx - 2, 21, 5, P.STEEL_L)
    beacon(img, 9, 19)
    # funnel: black, a red band, soot at the lip
    rect(img, 10, 26, 6, 5, (48, 42, 46, 255))
    hline(img, 10, 28, 6, P.CRANE_L)
    hline(img, 10, 26, 6, (84, 78, 84, 255))
    rect(img, 12, 27, 2, 1, INK)
    # towing winch and hook on the after deck
    rect(img, 9, 33, 8, 3, P.STEEL_D)
    hline(img, 9, 33, 8, P.STEEL_L)
    vline(img, cx, 36, 3, P.STEEL)
    px(img, cx, 38, CHROME)
    # tyre fenders hung over the side
    for fx, fy in ((4, 9), (19, 9), (1, 17), (22, 17), (1, 26), (22, 26),
                   (3, 34), (20, 34)):
        rect(img, fx, fy, 3, 3, P.TIRE)
        px(img, fx + 1, fy + 1, P.TIRE_L)
    # navigation lights
    px(img, 6, 13, P.RED_LIGHT)
    px(img, 19, 13, P.GREEN_LIGHT)
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
