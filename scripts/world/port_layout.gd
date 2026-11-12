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

## Bollards down the quay edge. The ship's mooring lines and the decal that
## draws them read the same numbers, so a rope always lands on an actual bollard
## instead of near one.
const BOLLARD_X := WATER_X0 - 20.0
const BOLLARD_Y0 := TOP_MARGIN + 10.0
const BOLLARD_PITCH := 46.0
## The centre of the bollard sprite, from its top-left anchor.
const BOLLARD_CENTRE := Vector2(4.0, 4.0)

const SHIP_X := 244.0
## The first berth starts below the gate apron rather than level with it. The
## bow used to tie up at the very top of the world, where the HUD gantry and the
## approach road are, so the hull was half chrome and half off-frame exactly when
## the player was meant to be tapping it.
const SHIP_Y := 96.0
const SHIP_W := 66.0
const SHIP_H := 232.0

# --- the berths ------------------------------------------------------------
## Berths run down the quay, north to south, and share one fairway. The world is
## 320 px wide: the water is 80 and a hull is 66, so **two hulls cannot pass**.
## There is no offset that clears one moored ship — a passing hull would have to
## start at x 310 and end at 376, which is off the map. Holding it a few pixels
## outboard and drawing it on top only makes one ship slide through another with
## its edges showing, which is what the quay used to look like.
##
## So nothing ever passes. A hull can only travel north bow-first, so the channel
## runs south to north: in from the open water below, out past the top. Whether
## that run is possible depends on who is already alongside:
##
##   * the way is clear — the ship makes the full run up or down the fairway,
##     which is the arrival and the departure the port is built around;
##   * somebody is moored in the way — the tugs take it **straight out to sea**
##     instead, beam-on, off the seaward edge of the frame. Which is how a ship
##     leaves a berth anyway: warped off sideways before it is under way at all.
##
## `PortWorld.lane_clear_north/south` decide, and `OFFING_X` is where the
## sideways route ends up.
const BERTH_MAX := 3
const BERTH_GAP := 26.0
const BERTH_PITCH := SHIP_H + BERTH_GAP
## The lane a moving hull uses, held off the quay so coming off the berth is a
## move the player can see. Its outboard edge is a few pixels past the frame,
## which the camera never shows.
const FAIRWAY_X := SHIP_X + 14.0
## Out to sea, past the seaward edge of the world: where a hull that cannot use
## the channel goes instead, and where one arriving that way comes from.
const OFFING_X := WORLD_W + 26.0
## How far off the top and bottom of the world the channel reaches, so a hull
## enters and leaves out of frame rather than appearing on the water.
const CHANNEL_MARGIN := 40.0


static func channel_entry_y() -> float:
	## Where a hull picks up the channel, and where it leaves it. `ship_top.png`
	## is drawn **bow up** (see `tools/sprites/gen_ship.py`), so a ship can only
	## steam bow-first toward **negative y** — the channel therefore runs
	## south → north past the quay: in from below, out past the top.
	##
	## These are functions rather than raw arithmetic at the call site because
	## getting the sign wrong is invisible in code and unmistakable on screen: the
	## hull reverses into its berth and reverses back out to sea. It has happened
	## once already, when the sprite was flipped back to bow-up and the manoeuvre
	## was left driving the other way.
	return world_bottom() + SHIP_H * 0.5 + CHANNEL_MARGIN


static func channel_exit_y() -> float:
	return -SHIP_H - CHANNEL_MARGIN


static func bollard_position(index: int) -> Vector2:
	return Vector2(BOLLARD_X, BOLLARD_Y0 + maxi(0, index) * BOLLARD_PITCH)


static func bollard_count() -> int:
	return maxi(1, ceili((world_bottom() - BOLLARD_Y0) / BOLLARD_PITCH))


static func nearest_bollard(y: float, forward: bool) -> Vector2:
	## The bollard a line should be led to: forward of the fairlead for a head or
	## after spring, aft of it for the other pair. Clamped to the quay, so a hull
	## at either end still finds something to make fast to.
	var raw := (y - BOLLARD_Y0) / BOLLARD_PITCH
	var index := floori(raw) if forward else ceili(raw)
	if forward and is_equal_approx(float(index), raw):
		index -= 1
	elif not forward and is_equal_approx(float(index), raw):
		index += 1
	return bollard_position(clampi(index, 0, bollard_count() - 1))


static func berth_y(index: int) -> float:
	return SHIP_Y + maxi(0, index) * BERTH_PITCH


static func berth_count() -> int:
	## As many berths as there is quay to put them on. Derived from the world's own
	## depth rather than from a parcel count, so buying land is what lengthens the
	## quay and the two can never disagree.
	var count := 1
	while count < BERTH_MAX \
			and berth_y(count) + SHIP_H + BASIN_H <= world_bottom():
		count += 1
	return count

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

## The unpaved strip along the southern boundary. It used to be where the branch
## line ran, and the branch has moved inland — see `rail_y`.
##
## It also carries `BASIN_H`: the world is that much deeper than the moorings
## need, so reserving the basin costs no berths. Trimming this without trimming
## that would quietly cost the terminal one.
const SOUTH_MARGIN := 102.0

## Clear water kept south of the last hull.
##
## The moorings pack down the quay until they run out of world, so without a
## reserved basin there is no stretch of water some berth is not already using —
## and `DecorLayer._duck_home` moors in exactly that water, on the stated promise
## that it is always clear. It was 20, which is less than the 46 the duck moors
## at, so the duck rode under the last hull; it only became visible when the
## branch corridor grew and the packing shifted, which is what a latent geometry
## bug looks like.
const BASIN_H := 76.0
## Vertical room the branch corridor needs between the yard and the workshop
## band: the run-around loop, the running line, the signal that stands north of
## both, and — south of the rails — the goods platform the whole thing exists to
## serve. It was 62 while the branch was two stripes of ballast on bare asphalt;
## a railhead with no platform, no ramp and no shed is a level crossing with
## ambitions, and the extra thirty pixels are where the station goes.
const RAIL_BAND_H := 92.0


static func block_rows() -> int:
	## Each purchased parcel contributes its declared capacity.  Two terrain
	## slots make a visual row of container blocks.
	return BASE_BLOCK_ROWS + ceili(float(LandDB.owned_slots(GameState.land)) / 2.0)


static func slot_rows() -> int:
	return ceili(float(BASE_SLOT_ROWS * SLOTS_PER_ROW + LandDB.owned_slots(GameState.land)) /
		float(SLOTS_PER_ROW))


static func block_count() -> int:
	return block_rows() * BLOCK_COLUMNS


static func slot_count() -> int:
	return BASE_SLOT_ROWS * SLOTS_PER_ROW + LandDB.owned_slots(GameState.land)


## What a block is *for*, which is the terminal's whole sense of direction.
##
## A container yard is not a car park: a box is stacked where the machine that
## handles it next will want it, and that decides which way it crosses the
## terminal. The gate is west and the quay is east, so:
##
##   * the **landward** column is the import yard. A box discharged from a ship
##     is driven the full width of the terminal to get here, and leaves by road
##     from right beside the gate;
##   * the **seaward** column is the export yard. A box that came in by road is
##     driven the full width to get here, and is lifted onto a hull from right
##     beside the crane;
##   * everything between is buffer — overflow either way, and where a
##     transhipment box waits for the hull that is actually taking it.
##
## So the two long hauls run in opposite directions and the two short ones do
## not, which is what makes the yard read as having an in and an out rather than
## as machines shuffling boxes about.
const ROLE_IMPORT := &"import"
const ROLE_EXPORT := &"export"
const ROLE_BUFFER := &"buffer"


static func block_role(index: int) -> StringName:
	var col := posmod(index, BLOCK_COLUMNS)
	if col == BLOCK_COLUMNS - 1:
		return ROLE_EXPORT
	if col == 0:
		return ROLE_IMPORT
	return ROLE_BUFFER


static func role_heads_seaward(role: StringName) -> bool:
	## Which way this block's cargo leaves. Drawn on the ground as a chevron, so
	## the arrow and the routing can never disagree.
	return role == ROLE_EXPORT


## Which block row the branch corridor is threaded *before*. Everything from this
## row on is laid out on the far side of the railway.
##
## The branch used to hang off `yard_bottom()`, which grows every time a parcel is
## bought — so the railhead, its signal, its crossing and its board all slid a
## block row further south each time the terminal expanded, and a player who had
## learned where the station was found it somewhere else. A railhead is the one
## piece of a port that is genuinely immovable: the line was there before the
## terminal and the terminal was built around it. It is a fixed row now, and the
## yard grows *past* it, which is also how a real terminal expands.
const RAIL_ROW := BASE_BLOCK_ROWS


static func block_row_pitch() -> float:
	return BLOCK_H + BLOCK_GAP_Y


static func block_row_y(row: int) -> float:
	## Top edge of block row `row`, with the branch corridor threaded in at
	## `RAIL_ROW`. The single place that knows the yard is interrupted — every
	## other row calculation goes through here so a block, its driving lane and the
	## machine that works it can never end up on opposite sides of the railway.
	var y := YARD_Y0 + float(row) * block_row_pitch()
	if row >= RAIL_ROW:
		y += RAIL_BAND_H
	return y


static func block_origin(index: int) -> Vector2:
	## Top-left corner of block `index` (row-major, left to right).
	var col := index % BLOCK_COLUMNS
	@warning_ignore("integer_division") var row := index / BLOCK_COLUMNS
	return Vector2(BLOCK_X0 + col * (BLOCK_W + BLOCK_GAP_X), block_row_y(row))


static func slot_position(index: int) -> Vector2:
	## Top-left corner of building slot `index`.
	var col := index % SLOTS_PER_ROW
	@warning_ignore("integer_division") var row := index / SLOTS_PER_ROW
	return Vector2(
		BLOCK_X0 + col * SLOT_W,
		service_y() + 12.0 + row * SLOT_ROW_H)


static func yard_bottom() -> float:
	## The southern edge of the last block row, corridor included when the yard has
	## grown past it.
	return block_row_y(block_rows() - 1) + block_row_pitch()


static func rail_corridor_bottom() -> float:
	return YARD_Y0 + float(RAIL_ROW) * block_row_pitch() + RAIL_BAND_H


static func service_y() -> float:
	## The workshop band sits south of everything the terminal operates — the
	## blocks and the branch both. On a young port the corridor is the lower of the
	## two and sets this line; once the yard has grown past the railway the blocks
	## do, and the sheds move down with them.
	return maxf(yard_bottom(), rail_corridor_bottom()) + SERVICE_GAP


static func world_bottom() -> float:
	return service_y() + slot_rows() * SLOT_ROW_H + SOUTH_MARGIN


static func rail_y() -> float:
	## The running line. A constant, and it has to stay one.
	##
	## Two earlier versions were not. The first was `world_bottom() - 26`, which
	## put the whole branch on the southern boundary below the workshop band, in
	## the one strip a player never pans to: the feature worked and nobody ever saw
	## it work. The second was `yard_bottom() + 44`, which fixed the visibility and
	## introduced a worse problem — the yard grows with every parcel, so the
	## railhead crept a block row south each time the terminal expanded, and the
	## station a player had learned the position of was simply somewhere else the
	## next time they looked.
	##
	## It is pinned to `RAIL_ROW` now, and the yard is laid out around it. Every
	## other figure on the branch derives from this one, so moving this line moves
	## the railway — which is exactly why it does not move.
	return YARD_Y0 + float(RAIL_ROW) * block_row_pitch() + 44.0


# --- the branch line ------------------------------------------------------
## The corridor is a stub: a rake runs in from the interior, is worked, and goes
## back out the way it came. That is one track and one direction, and a
## locomotive that cannot turn round would have to be shunted out backwards —
## which is why there is a **run-around loop**.
##
## The loop is a second road laid north of the running line and joined to it by a
## turnout at each end. With the rake standing at the buffer stop the loco
## uncouples, draws forward past the east turnout, crosses to the loop, runs back
## west alongside its own train, crosses again at the west turnout and couples to
## what used to be the tail. The train now faces the way it came in, which is the
## only way a stub-ended siding works in real life.
const RAIL_LOOP_DY := -17.0
## Length of a wagon plus its couplings, on the ground rather than in the sprite.
const RAIL_WAGON_PITCH := 21.0
## Head of the rake, short of the buffer stop, and the wagon nearest it.
const RAIL_STOP_MARGIN := 34.0
## Where a rake waits out of sight, west of the map.
const RAIL_STAGING_X := -170.0
## The signal protecting the entrance to the terminal's rail limit.
const RAIL_SIGNAL_X := 96.0


static func rail_loop_y() -> float:
	## The run-around road. North of the running line so the loco passes between
	## its train and the yard, where the player can see it happen.
	return rail_y() + RAIL_LOOP_DY


static func rail_buffer_x() -> float:
	## The buffer stop: east of this is the quay, and then the sea.
	return WATER_X0 - 15.0


static func rail_stop_x() -> float:
	## Where the head of the rake stands to be worked.
	return rail_buffer_x() - RAIL_STOP_MARGIN


static func rail_east_turnout_x() -> float:
	## Between the head of the standing rake and the buffer stop — the loco has to
	## be able to draw forward clear of its train before it crosses over.
	return rail_stop_x() + 20.0


static func rail_west_turnout_x() -> float:
	## Clear of the tail of the longest rake it will ever have to run round.
	##
	## Derived from `RailCargoPolicy.MAX_RAKE` rather than written down, because
	## the branch's upgrades move the rake. A hardcoded seven pitches was correct
	## exactly while six wagons was the only length the branch could produce; the
	## first upgrade that added a wagon would have left the loco coupling up west
	## of its own turnout.
	return rail_stop_x() - RAIL_WAGON_PITCH * float(RailCargoPolicy.MAX_RAKE + 1)


static func rail_wagon_x(slot: int) -> float:
	## Wagon `slot` counted back from the head of the standing rake.
	return rail_stop_x() - RAIL_WAGON_PITCH * (slot + 1)


# --- the goods station ------------------------------------------------------
## What makes the branch a *place* rather than a line the train happens to cross.
##
## A railhead in a container terminal is not bare track: it is a paved apron the
## full length of the standing rake, at wagon-deck height, with a hard edge the
## boxes are worked across and a shed at the end for whatever is not going
## straight onto a stack. Without it the corridor read as two stripes of ballast
## and a locomotive sliding over them, and the board naming the place stood in
## the middle of the yard attached to nothing.
##
## It sits **south** of the running line — between the rails and the sheds —
## because the loop is north and the loco has to be able to pass its own train.

## Top of the platform, clear of the running line and its ballast shoulder.
const RAIL_PLATFORM_DY := 11.0
const RAIL_PLATFORM_H := 26.0
## How far past the ends of the standing rake the apron runs. A platform exactly
## as long as the train reads as a coincidence; a little over reads as built.
const RAIL_PLATFORM_OVERRUN := 14.0


static func rail_platform_top() -> float:
	return rail_y() + RAIL_PLATFORM_DY


static func rail_platform_rect() -> Rect2:
	## The working face of the station, in world pixels.
	##
	## Sized off the longest rake the branch can ever stand, then cut back at both
	## ends by the two things that were already there: the public road the branch
	## crosses on the level, and the quay. Concrete poured across a live
	## carriageway is not a platform, it is a paving error — and the first version
	## of this did exactly that, running the apron out to x=9 straight over the
	## road and the level crossing.
	##
	## A very long rake therefore has its last wagon or two standing off the end of
	## the apron, over the crossing. That is correct rather than a compromise: it
	## is what an over-length train does at a short goods platform, and it gives
	## the shuttle a reason to be short.
	var west := maxf(rail_wagon_x(RailCargoPolicy.MAX_RAKE - 1)
		- RAIL_PLATFORM_OVERRUN, ROAD_X1 + 4.0)
	var east := minf(rail_stop_x() + RAIL_PLATFORM_OVERRUN, QUAY_X0 - 4.0)
	return Rect2(west, rail_platform_top(), east - west, RAIL_PLATFORM_H)


static func rail_shed_rect() -> Rect2:
	## The transit shed, at the buffer-stop end where the head of every rake
	## stops. Cargo that is not going straight onto a stack waits here, and it is
	## what gives the east end of the platform a reason to be the east end.
	var platform := rail_platform_rect()
	return Rect2(platform.end.x - 46.0, platform.position.y - 2.0, 44.0,
		RAIL_PLATFORM_H + 4.0)


static func rail_board_position() -> Vector2:
	## The name board, standing on its own platform at the west end — the end a
	## train arrives from, so the first thing a service passes is the sign saying
	## where it has arrived. It used to float over the middle of the standing rake
	## with nothing under it.
	var platform := rail_platform_rect()
	return Vector2(platform.position.x + 6.0, platform.position.y + 4.0)


static func rail_gantry_x() -> float:
	## Centre of the rail gantry that spans the running line and the apron. Over
	## the middle of the platform rather than the middle of the longest possible
	## rake: the crane works what the apron can serve, and parking it out over the
	## level crossing would have it straddling the public road.
	var platform := rail_platform_rect()
	return platform.position.x + platform.size.x * 0.5


static func rail_wagon_centre(slot: int) -> Vector2:
	## The wagon deck — the point a box flies to and from.
	return Vector2(rail_wagon_x(slot), rail_y() - 2.0)


static func rail_wagon_rect(slot: int) -> Rect2:
	## Generous on purpose: this is a touch target on a phone, not a hitbox.
	var centre := rail_wagon_centre(slot)
	return Rect2(centre - Vector2(RAIL_WAGON_PITCH * 0.5 + 3.0, 13.0),
		Vector2(RAIL_WAGON_PITCH + 6.0, 26.0))


static func rail_signal_position() -> Vector2:
	## North of *both* roads, on the yard side, where it is read against the dark
	## ballast rather than against the fence.
	##
	## It used to be `rail_y() - 24`, which was clear of a single-track corridor
	## and then stopped being clear of anything the moment the run-around loop was
	## laid 17px north of the running line: the mast ended up standing on the
	## loop's own rails, so the signal protecting the branch was an obstruction on
	## it. The sprite is 18px tall and drawn from its top-left, so this puts its
	## foot just short of the loop's north rail.
	return Vector2(RAIL_SIGNAL_X, rail_loop_y() - 23.0)


static func rail_crossing_mast(side: int) -> Vector2:
	## The two masts at the level crossing, one either side of the public road
	## and each outside the track it protects — north of the loop, south of the
	## running line. Same correction as the signal: the north one was pitched for
	## a corridor with one road in it.
	if side == 0:
		return Vector2(ROAD_X0 - 14.0, rail_loop_y() - 21.0)
	return Vector2(ROAD_X1 + 2.0, rail_y() + 7.0)


static func rail_crossing_x() -> float:
	## Centre of the panels where the branch crosses the public road.
	return (ROAD_X0 + ROAD_X1) * 0.5


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


static func xray_station_position() -> Vector2:
	## The Receita's post: east of gate bay G3, clear of both truck routes (the
	## approach runs along GATE_QUEUE_Y below it, the exit along GATE_EXIT_Y
	## above), on the gate apron where an inspection belongs.
	var bay := gate_bay_position(GATE_BAY_COUNT - 1)
	return Vector2(bay.x + GATE_BAY_W + 6.0, GATE_APRON_Y - 4.0)


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
		for runway_x: float in runway_xs():
			spots.append({"pos": Vector2(runway_x - 6.0, lanes[row] - 8.0),
				"quay": false, "tone": "yard", "energy": 0.92})

	# Road verge and workshop band bridge the dark gaps between gate, stacks
	# and service buildings without putting a pole in a driven lane.
	var road_y := YARD_Y0 + 28.0
	while road_y < service_y() - 20.0:
		spots.append({"pos": Vector2(YARD_X0 - 8.0, road_y),
			"quay": false, "tone": "road", "energy": 0.70})
		road_y += BLOCK_H + BLOCK_GAP_Y
	for row in slot_rows():
		var service_lamp_y := service_y() + 28.0 + row * SLOT_ROW_H
		spots.append({"pos": Vector2(BLOCK_X0 - 8.0, service_lamp_y),
			"quay": false, "tone": "service", "energy": 0.78})
		spots.append({"pos": Vector2(QUAY_X0 - 12.0, service_lamp_y),
			"quay": true, "tone": "service", "energy": 0.84})

	# The quay keeps the same rhythm, carried up past the yard so the berth is
	# lit even before the first block row exists.
	var pitch := BLOCK_H + BLOCK_GAP_Y
	var quay_y: float = lanes[0] - 8.0
	while quay_y - pitch > TOP_MARGIN:
		quay_y -= pitch
	while quay_y < world_bottom() - 30.0:
		spots.append({"pos": Vector2(QUAY_X0 - 12.0, quay_y),
			"quay": true, "tone": "quay", "energy": 1.0})
		quay_y += pitch
	return spots


static func lane_ys() -> Array[float]:
	## Horizontal driving lanes between the container block rows.
	var lanes: Array[float] = []
	for row in block_rows():
		lanes.append(block_row_y(row) + BLOCK_H + BLOCK_GAP_Y * 0.5)
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
	return block_row_y(row) + BLOCK_H + BLOCK_GAP_Y * 0.5


static func quay_lane_x() -> float:
	return QUAY_X0 + 8.0


# --- the interchange -------------------------------------------------------
## A container never crosses this terminal by itself. It is lifted by whatever
## machine reaches its current home, set down where a chassis can take it,
## driven, and lifted again by the machine that owns the stacks it is going to.
##
## These are the three places a hand-off can happen, and they are geometry, not
## taste: the apron under the crane rail, the driving lane at the seaward end of
## a block, and the approach in front of a parking bay. `CargoRelay` builds every
## itinerary out of them, so a box is only ever in one of two states — held by a
## named machine, or standing on ground a machine can reach.

## The quay apron, which is also the terminal's north-south trunk road: it runs
## the whole depth of the map under the crane rail and crosses no stacking slot,
## so it is the one road a tractor can always use to get from any berth to any
## block row.
static func interchange_spine_x() -> float:
	return quay_lane_x()


static func quay_interchange(y: float) -> Vector2:
	## Where a portainer sets a box down on the apron, in line with the bay it
	## came out of.
	return Vector2(quay_lane_x(), y)


static func block_interchange(block_index: int) -> Vector2:
	## The chassis position a transtainer or reach stacker reaches for: in the
	## driving lane, at the seaward end of the block it serves.
	var origin := block_origin(maxi(0, block_index))
	return Vector2(origin.x + BLOCK_W + 4.0, block_lane_y(maxi(0, block_index)))


static func gate_interchange(x: float) -> Vector2:
	## In front of a parking bay, on the approach. The empty handler works the
	## road chassis from here and hands the box to a tractor on the same lane.
	return Vector2(clampf(x, GATE_BAY_X, GATE_BAY_X
		+ GATE_BAY_COUNT * (GATE_BAY_W + GATE_BAY_GAP)), GATE_QUEUE_Y)


static func nearest_block(pos: Vector2) -> int:
	## Which block a yard position belongs to, asked of a point rather than of a
	## slot index so the relay can stay ignorant of the yard's slot numbering.
	var best := 0
	var best_distance := INF
	var centre := Vector2(BLOCK_W, BLOCK_H) * 0.5
	for index in block_count():
		var distance := (block_origin(index) + centre).distance_squared_to(pos)
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


static func depot_slot(index: int) -> Vector2:
	## Where idle plant stands. A machine the player paid for has to be somewhere
	## they can see it between jobs — parking the fleet off-map is why buying a
	## tractor used to change nothing on screen.
	##
	## The ranks sit on the interchange spine, one per driving lane, which is
	## both clear ground and exactly where a tractor waiting for work belongs.
	var lanes := lane_ys()
	var lane: float = lanes[index % lanes.size()]
	@warning_ignore("integer_division") var rank: int = index / lanes.size()
	return Vector2(interchange_spine_x() + float(rank % 2) * 13.0, lane)


static func sts_y(index: int, count: int) -> float:
	## Cranes spread along the whole worked quay, not just the first berth: with
	## three ships alongside, three portainers bunched at the top would leave two
	## hulls with nothing over them.
	var quay := berth_y(berth_count() - 1) + SHIP_H - SHIP_Y
	var span := maxf(SHIP_H - 80.0, quay - 80.0)
	if count <= 1:
		return SHIP_Y + 46.0
	return SHIP_Y + 30.0 + span * (float(index) / float(count - 1))


const SHIP_BAY_COLS := 2
const SHIP_BAY_ROWS := 12
