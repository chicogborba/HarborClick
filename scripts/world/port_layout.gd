class_name PortLayout
## Pure geometry for the top-down terminal. No nodes, no state — just the
## numbers every other system agrees on.
##
##   x:  gate | ---- yard ---- | quay | water
##   y:  scrolls; the berth sits near the top, the yard grows downward.

const WORLD_W := 320.0
const VIEW_H := 480.0

const GATE_X := -30.0             # trucks vanish past this, off to the city
const YARD_X0 := 14.0             # paved area starts (service road)
const GATE_ROAD_X := 22.0         # centre line of the vertical service road
## The service road carries traffic both ways, so it is split into two
## one-way columns. Without this, a hauler driving in and a hauler driving out
## share a centre line and either overlap or deadlock waiting for each other.
const ROAD_LANE_HALF := 7.0
const ROAD_IN_X := GATE_ROAD_X - ROAD_LANE_HALF
const ROAD_OUT_X := GATE_ROAD_X + ROAD_LANE_HALF
const BLOCK_X0 := 36.0            # first container block
const QUAY_X0 := 196.0
const QUAY_X1 := 240.0
const WATER_X0 := 240.0

const TOP_MARGIN := 30.0
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
const BLOCK_GAP_X := 10.0                  # RTG runway between block columns
const BLOCK_GAP_Y := 18.0                  # driving lane between block rows

const BLOCK_COLUMNS := 3
const BASE_BLOCK_ROWS := 3
const PARCEL_BLOCK_ROWS := 2

const YARD_Y0 := 70.0

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
	## Vertical RTG runways between block columns, plus the quay approach.
	var xs: Array[float] = []
	for col in range(1, BLOCK_COLUMNS):
		xs.append(BLOCK_X0 + col * (BLOCK_W + BLOCK_GAP_X) - BLOCK_GAP_X * 0.5)
	xs.append(QUAY_X0 - 6.0)
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
