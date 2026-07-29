class_name PortLayout
## Pure geometry for the top-down terminal. No nodes, no state — just the
## numbers every other system agrees on.
##
##   x:  road | ---- yard ---- | quay | water
##   y:  the city is off the top, the gate crosses the fence, the yard grows
##       downward from the apron.

const WORLD_W := 320.0
const VIEW_H := 480.0

# --- the road to the city -------------------------------------------------
## Every container either came from somewhere or is going somewhere, and half
## of them travel by land. The road is that half made visible: it runs off the
## top of the map towards the city, crosses the perimeter at the gate, and
## feeds the parking bays on the apron. Nothing appears inside the fence
## without having driven through it.

const CITY_Y := -40.0             # vehicles spawn and vanish here, off-camera
const FENCE_Y := 16.0             # the perimeter fence line
const GATE_ARM_Y := 30.0          # the barrier across the carriageway

const YARD_X0 := 14.0             # kerb: the terminal's paved area starts here
const ROAD_X0 := 16.0             # west edge of the carriageway
const ROAD_X1 := 44.0             # east edge, and the first block's kerb
const GATE_ROAD_X := 30.0         # painted centre line
## The road carries traffic both ways, so it is two one-way lanes. Without
## this, a hauler driving in and a hauler driving out share a centre line and
## either overlap or deadlock waiting for each other.
const ROAD_LANE_HALF := 7.0
const ROAD_IN_X := GATE_ROAD_X - ROAD_LANE_HALF    # southbound, from the city
const ROAD_OUT_X := GATE_ROAD_X + ROAD_LANE_HALF   # northbound, to the city

const TOP_MARGIN := 30.0

# --- the gate apron -------------------------------------------------------
## The apron is the terminal's second door: without it cargo can only arrive
## and leave by sea, and a closed loop can jam.
##
## Its circulation is one-way, so no truck ever reverses or meets another head
## on:
##
##   in   down the west lane -> east along the approach -> north into a bay
##   out  north out of the bay -> west along the exit -> up the east lane
##
## The two apron lanes sit north and south of the bays, and neither reaches
## across the stretch of carriageway the other one uses — an arriving truck
## and a departing truck never share a square of road.
const GATE_EXIT_Y := 42.0         # westbound, back to the northbound lane
const GATE_APRON_Y := 54.0        # top edge of the parking bays
const GATE_BAY_COUNT := 3
const GATE_BAY_W := 20.0
const GATE_BAY_H := 40.0
const GATE_BAY_GAP := 24.0
const GATE_BAY_X := 50.0
const GATE_QUEUE_Y := 106.0       # eastbound approach, off the southbound lane

const BLOCK_X0 := 44.0            # first container block, hard against the road
const QUAY_X0 := 196.0
const QUAY_X1 := 240.0
const WATER_X0 := 240.0

const SHIP_X := 244.0
const SHIP_Y := 60.0
const SHIP_W := 66.0
const SHIP_H := 232.0

# --- container yard geometry ---
const BOX_W := 23.0
const BOX_H := 12.0
const BOX_LIFT := 4.0             # visual y-offset per stacked level
const BLOCK_COLS := 2
const BLOCK_ROWS := 4
const STACK_MAX := 3

const BLOCK_W := BOX_W * BLOCK_COLS        # 46
const BLOCK_H := BOX_H * BLOCK_ROWS        # 48
const BLOCK_GAP_X := 6.0                   # RTG runway between block columns
const BLOCK_GAP_Y := 18.0                  # driving lane between block rows

const BLOCK_COLUMNS := 3
const BASE_BLOCK_ROWS := 3
const PARCEL_BLOCK_ROWS := 2

const YARD_Y0 := 120.0

# --- service band below the yard ---
const SERVICE_GAP := 20.0
const SLOT_W := 84.0
const SLOT_H := 52.0
const SLOTS_PER_ROW := 2
const SLOT_ROW_H := 64.0
const BASE_SLOT_ROWS := 2
const PARCEL_SLOT_ROWS := 1

const RAIL_MARGIN := 46.0


static func block_rows() -> int:
	## Each purchased parcel contributes its declared capacity.  Two terrain
	## slots make a visual row of container blocks.
	return BASE_BLOCK_ROWS + ceili(float(LandDB.owned_slots()) / 2.0)


static func slot_rows() -> int:
	return ceili(float(BASE_SLOT_ROWS * SLOTS_PER_ROW + LandDB.owned_slots()) /
		float(SLOTS_PER_ROW))


static func block_count() -> int:
	return block_rows() * BLOCK_COLUMNS


static func slot_count() -> int:
	return BASE_SLOT_ROWS * SLOTS_PER_ROW + LandDB.owned_slots()


static func block_origin(index: int) -> Vector2:
	## Top-left corner of block `index` (row-major, left to right).
	var col := index % BLOCK_COLUMNS
	@warning_ignore("integer_division") var row := index / BLOCK_COLUMNS
	return Vector2(
		BLOCK_X0 + col * (BLOCK_W + BLOCK_GAP_X),
		YARD_Y0 + row * (BLOCK_H + BLOCK_GAP_Y))


static func slot_position(index: int) -> Vector2:
	## Top-left corner of building slot `index`.
	var col := index % SLOTS_PER_ROW
	@warning_ignore("integer_division") var row := index / SLOTS_PER_ROW
	return Vector2(
		BLOCK_X0 + col * SLOT_W,
		service_y() + 12.0 + row * SLOT_ROW_H)


static func yard_bottom() -> float:
	return YARD_Y0 + block_rows() * (BLOCK_H + BLOCK_GAP_Y)


static func service_y() -> float:
	return yard_bottom() + SERVICE_GAP


static func world_bottom() -> float:
	return service_y() + slot_rows() * SLOT_ROW_H + RAIL_MARGIN


static func rail_y() -> float:
	return world_bottom() - 26.0


static func gate_bay_position(bay: int) -> Vector2:
	## Top-left of a parking bay on the gate apron.
	return Vector2(GATE_BAY_X + bay * (GATE_BAY_W + GATE_BAY_GAP), GATE_APRON_Y)


static func gate_bay_centre(bay: int) -> Vector2:
	## Where a parked truck's bed sits — the point boxes fly to and from.
	return gate_bay_position(bay) + Vector2(GATE_BAY_W, GATE_BAY_H) * 0.5


static func gate_bay_rect(bay: int) -> Rect2:
	## Generous on purpose: this is a touch target on a phone, not a hitbox.
	return Rect2(gate_bay_position(bay) - Vector2(4, 4),
		Vector2(GATE_BAY_W + 8.0, GATE_BAY_H + 8.0))


static func gate_entry() -> Vector2:
	## Where anything coming in off the public road appears. Above the camera's
	## top edge, so a vehicle is only ever seen once it is on the road.
	return Vector2(ROAD_IN_X, CITY_Y)


static func gate_exit() -> Vector2:
	return Vector2(ROAD_OUT_X, CITY_Y)


static func gate_arrival_route(bay: int) -> Array[Vector2]:
	## City -> southbound lane -> east along the approach -> north into the bay.
	## The truck ends up nose-out, which is both how you park at a loading bay
	## and what lets it leave again without reversing.
	var centre := gate_bay_centre(bay)
	return [
		Vector2(ROAD_IN_X, GATE_QUEUE_Y),
		Vector2(centre.x, GATE_QUEUE_Y),
		centre,
	]


static func gate_departure_route(bay: int) -> Array[Vector2]:
	## Bay -> north onto the exit lane -> west -> up the northbound lane.
	var centre := gate_bay_centre(bay)
	return [
		Vector2(centre.x, GATE_EXIT_Y),
		Vector2(ROAD_OUT_X, GATE_EXIT_Y),
		gate_exit(),
	]


static func lamp_spots() -> Array[Dictionary]:
	## Where the flood-light masts stand. Fixed, and on a grid the terminal's
	## own geometry decides: two at the gate, then one in every other driving
	## lane on each RTG runway and on the quay seam. A mast never lands on a
	## stacking block, in a parking bay or in the middle of a carriageway, and
	## the pattern reads as lighting somebody planned rather than scatter.
	var spots: Array[Dictionary] = []
	# the gate: one on the verge by the guard house, then one in each gap
	# between parking bays
	spots.append({"pos": Vector2(ROAD_X1 + 34.0, FENCE_Y - 4.0), "quay": false})
	var pitch_x := GATE_BAY_W + GATE_BAY_GAP
	for gap in GATE_BAY_COUNT - 1:
		spots.append({"pos": Vector2(
			GATE_BAY_X + GATE_BAY_W + gap * pitch_x + 6.0,
			GATE_APRON_Y + 10.0), "quay": false})

	var lanes := lane_ys()
	for row in lanes.size():
		if row % 2 == 1:
			continue
		for runway_x: float in runway_xs():
			spots.append({"pos": Vector2(runway_x - 6.0, lanes[row] - 8.0),
				"quay": false})

	# The quay keeps the same rhythm, carried up past the yard so the berth is
	# lit even before the first block row exists.
	var pitch := (BLOCK_H + BLOCK_GAP_Y) * 2.0
	var quay_y: float = lanes[0] - 8.0
	while quay_y - pitch > TOP_MARGIN:
		quay_y -= pitch
	while quay_y < world_bottom() - 30.0:
		spots.append({"pos": Vector2(QUAY_X0 - 12.0, quay_y), "quay": true})
		quay_y += pitch
	return spots


static func lane_ys() -> Array[float]:
	## Horizontal driving lanes between the container block rows.
	var lanes: Array[float] = []
	for row in block_rows():
		lanes.append(YARD_Y0 + row * (BLOCK_H + BLOCK_GAP_Y) + BLOCK_H + BLOCK_GAP_Y * 0.5)
	return lanes


static func nearest_lane(y: float) -> float:
	var lanes := lane_ys()
	var best: float = lanes[0]
	for lane in lanes:
		if absf(lane - y) < absf(best - y):
			best = lane
	return best


static func runway_xs() -> Array[float]:
	## Centre of each vertical RTG runway between the block columns.
	var xs: Array[float] = []
	for col in range(1, BLOCK_COLUMNS):
		xs.append(BLOCK_X0 + col * (BLOCK_W + BLOCK_GAP_X) - BLOCK_GAP_X * 0.5)
	return xs


static func block_lane_y(block_index: int) -> float:
	## The driving lane a machine works this block from (just below it).
	@warning_ignore("integer_division") var row := block_index / BLOCK_COLUMNS
	return YARD_Y0 + row * (BLOCK_H + BLOCK_GAP_Y) + BLOCK_H + BLOCK_GAP_Y * 0.5


static func quay_lane_x() -> float:
	return QUAY_X0 + 8.0


static func sts_y(index: int, count: int) -> float:
	var span := SHIP_H - 80.0
	if count <= 1:
		return SHIP_Y + 46.0
	return SHIP_Y + 30.0 + span * (float(index) / float(count - 1))


const SHIP_BAY_COLS := 2
const SHIP_BAY_ROWS := 12
