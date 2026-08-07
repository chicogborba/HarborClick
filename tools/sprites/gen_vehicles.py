"""Top-down port vehicles. All face UP (north); the game rotates/flips them."""
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


def gen_train():
    """Locomotive 22x46 + flat wagon 26x34 (carries a container).

    A shunter from above is three blocks and a walkway: the long hood with the
    engine under it, the cab, the short hood, and a plated footway down each
    side with handrails on it. The first version drew one flat teal rectangle
    with a grey square in the middle, which at 1:1 read as a wheelie bin — and
    this is the machine the rail branch exists to show off.
    """
    loco = new_img(22, 46)
    # --- running plate and side walkways -------------------------------------
    rect(loco, 1, 2, 20, 42, P.STEEL_D)
    vline(loco, 1, 3, 40, P.STEEL)
    vline(loco, 20, 3, 40, (58, 56, 66, 255))
    # Handrails: two dots per stanchion, down both walkways.
    for ry in range(6, 40, 4):
        px(loco, 1, ry, P.STEEL_L)
        px(loco, 20, ry, P.STEEL_L)

    # --- body ----------------------------------------------------------------
    rect(loco, 3, 3, 16, 40, P.TEAL)
    hline(loco, 3, 3, 16, P.TEAL_L)         # lit edge, light from the north
    vline(loco, 3, 3, 40, P.TEAL_L)
    vline(loco, 18, 3, 40, P.TEAL_D)
    hline(loco, 3, 42, 16, P.TEAL_D)

    # --- short hood, bonnet forward ------------------------------------------
    rect(loco, 4, 5, 14, 11, P.TEAL_D)
    hline(loco, 4, 5, 14, P.TEAL)
    for gy in range(7, 14, 2):              # radiator grille
        hline(loco, 6, gy, 10, (30, 74, 74, 255))
    rect(loco, 9, 9, 4, 4, P.STEEL_D)       # exhaust stack
    hline(loco, 9, 9, 4, P.STEEL_L)
    px(loco, 10, 10, (44, 40, 46, 255))
    px(loco, 11, 10, (44, 40, 46, 255))

    # --- cab, amidships ------------------------------------------------------
    rect(loco, 4, 17, 14, 11, P.TEAL_L)     # roof, catching the most light
    hline(loco, 4, 17, 14, (150, 214, 202, 255))
    rect(loco, 6, 19, 10, 7, P.GLASS_D)     # roof skylight
    rect(loco, 7, 20, 8, 5, P.GLASS)
    px(loco, 13, 21, (206, 240, 246, 255))  # the reflection off the glass
    px(loco, 5, 18, P.SAFETY)               # roof beacons, one per corner
    px(loco, 16, 18, P.SAFETY)

    # --- long hood, engine under it ------------------------------------------
    rect(loco, 4, 29, 14, 12, P.TEAL_D)
    hline(loco, 4, 29, 14, P.TEAL)
    for fan_y in (31, 36):                  # two radiator fans in their wells
        rect(loco, 6, fan_y, 10, 4, (30, 74, 74, 255))
        hline(loco, 6, fan_y, 10, (24, 62, 62, 255))
        for spoke in range(7, 15, 2):
            px(loco, spoke, fan_y + 1, P.TEAL)
            px(loco, spoke + 1, fan_y + 2, P.TEAL)

    # --- headstocks: buffers, coupler and the chevrons every shunter wears ----
    for hy, forward in ((1, True), (43, False)):
        rect(loco, 3, hy, 16, 2, P.STEEL_D)
        hline(loco, 3, hy, 16, P.STEEL_L if forward else P.STEEL)
        rect(loco, 10, hy - 1 if forward else hy + 2, 2, 2, (44, 40, 46, 255))
        for cx in range(4, 18, 4):          # amber warning chevrons
            px(loco, cx, hy, P.SAFETY)
            px(loco, cx + 1, hy + 1, P.SAFETY_D)

    # --- bogies: three wheelsets a side, on the rail -------------------------
    for wy in (7, 21, 35):
        for side in (0, 19):
            rect(loco, side, wy, 3, 5, P.TIRE)
            hline(loco, side, wy, 3, (52, 48, 58, 255))
            px(loco, side + 1, wy + 2, (86, 82, 92, 255))
    save(outline(loco), "veh_loco")

    # No outline on the lamp: `outline` darkens the transparent ring around any
    # opaque region, and a light with a black edge is a decal of a light.
    save(_loco_lamp(), "veh_loco_lamp")
    save(sheet([outline(f) for f in _wagon_frames()]), "veh_wagon")


def _wagon_deck(wagon):
    """Solebars, headstocks and bogies — what every wagon has in common.

    The bogies are the part worth the pixels. A wagon seen from above is mostly
    deck, so the only thing that says *rail vehicle* rather than *steel pallet*
    is a pair of two-axle trucks poking out either side with the wheels drawn
    on them."""
    rect(wagon, 2, 2, 22, 30, P.STEEL_D)        # solebars and floor
    hline(wagon, 2, 2, 22, P.STEEL)             # lit edge, light from the north
    vline(wagon, 2, 2, 30, P.STEEL)
    vline(wagon, 23, 3, 28, (58, 56, 66, 255))  # shaded solebar, south side
    for wy in (4, 23):                          # bogies, one at each end
        for side in (0, 23):
            rect(wagon, side, wy, 3, 7, (52, 48, 58, 255))
            for axle in (wy + 1, wy + 4):       # two wheelsets per truck
                hline(wagon, side, axle, 3, P.TIRE)
                px(wagon, side + 1, axle, (96, 92, 102, 255))
        # The bolster the truck pivots on, visible between the solebars.
        rect(wagon, 4, wy + 2, 18, 2, (74, 70, 82, 255))
    for hy in (2, 31):                          # headstocks with a drawhook
        hline(wagon, 9, hy, 8, P.STEEL_L)
    px(wagon, 12, 1, P.STEEL_D)
    px(wagon, 13, 1, P.STEEL_D)
    px(wagon, 12, 32, P.STEEL_D)
    px(wagon, 13, 32, P.STEEL_D)


def _wagon_frames():
    """Three flat wagons, 26x34, every one of them able to take a container.

    A block train is not six copies of one vehicle. It is whatever the interior
    could couple up that morning, and at this size the thing that says so is the
    *deck*: a plain container flat, a well wagon with its floor dropped between
    the bogies, and a skeletal spine with daylight through the middle of it.

    The constraint is that `RailYard` addresses every slot identically — a box
    may land on any wagon in the rake — so all three are flats. A tank or a van
    would read as a lie the first time a container appeared on top of it.
    """
    frames = []

    # 1. Container flat: plain plated deck, the standard vehicle of the fleet.
    flat = new_img(26, 34)
    _wagon_deck(flat)
    rect(flat, 4, 5, 18, 24, P.STEEL)
    speckle(flat, 4, 5, 18, 24, [P.STEEL_D, P.STEEL_L], 0.10, seed=6)
    for ty in (7, 16, 26):                      # twist-lock sockets down the deck
        px(flat, 5, ty, P.STEEL_D)
        px(flat, 20, ty, P.STEEL_D)
    frames.append(flat)

    # 2. Well wagon: the floor drops between the bogies, so the box rides lower
    # and the frame stands proud around it.
    well = new_img(26, 34)
    _wagon_deck(well)
    rect(well, 4, 4, 18, 26, P.STEEL)
    rect(well, 5, 8, 16, 18, P.STEEL_D)         # the well itself, in shadow
    speckle(well, 5, 8, 16, 18, [(78, 74, 88, 255), P.STEEL], 0.12, seed=11)
    hline(well, 5, 8, 16, (70, 66, 80, 255))    # the lip the floor drops from
    for ry in range(10, 26, 4):                 # cross-members under the well
        hline(well, 5, ry, 16, (86, 82, 96, 255))
    frames.append(well)

    # 3. Skeletal spine: a centre girder and outriggers, daylight either side.
    spine = new_img(26, 34)
    _wagon_deck(spine)
    rect(spine, 10, 4, 6, 26, P.STEEL)          # the spine
    hline(spine, 10, 4, 6, P.STEEL_L)
    speckle(spine, 10, 4, 6, 26, [P.STEEL_D], 0.14, seed=17)
    for oy in (6, 12, 18, 25):                  # outriggers the box sits across
        rect(spine, 4, oy, 18, 2, P.STEEL_D)
        hline(spine, 4, oy, 18, P.STEEL)
    frames.append(spine)
    return frames


def _loco_lamp():
    """The headlight's throw, 16x14, drawn nose-up like the locomotive itself.

    A separate sprite rather than a tint, for the same reason the signal has a
    separate lit frame: the game turns a lamp on by showing something, never by
    recolouring the thing that owns it. Widening as it goes so it reads as light
    on ballast instead of as a bar welded to the front of the engine."""
    img = new_img(16, 14)
    for row in range(14):
        # Bright and narrow at the lens, wide and nearly gone by the far end.
        half = 1 + row * 4 // 9
        alpha = int(150 * (1.0 - row / 15.0))
        for x in range(8 - half, 8 + half):
            px(img, x, 13 - row, (255, 236, 176, alpha))
    rect(img, 7, 12, 2, 2, (255, 248, 214, 220))
    return img


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
    gen_train()
    gen_drone()
