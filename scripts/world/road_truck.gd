class_name RoadTruck
extends Node2D
## A city truck on the terminal's road: a tractor unit and the chassis it pulls.
##
## It exists so that nothing on the apron appears out of nowhere. A bay's cargo
## is only ever on screen because a truck drove it in through the gate, and it
## only ever leaves because a truck drove it out again — the box is visible on
## the bed for the whole trip in both directions.
##
## A road chassis takes one forty-foot box or two twenty-foot ones, so the bed is
## drawn for exactly `GateDock.TRUCK_CAPACITY` and nothing else fits.
##
## **It is two bodies, not one, and it drives on its nose.** Both of those are
## rewrites of the first version and both are the same bug seen from different
## ends. That truck moved along the direction of the next waypoint while its
## sprite rotation eased towards it, so through every corner the body was still
## pointing one way while the vehicle travelled another — the box on the bed
## looked like it was sliding a beat behind the wheels. And it carried its boxes
## on a single 20x52 sprite whose bed was 28 px long for 29 px of cargo, so the
## second box hung off the tail.
##
## Now: velocity is always along the nose, so the rig physically cannot move
## sideways and a load cannot lag; and the chassis is a separate body pivoting on
## the fifth wheel, so it swings out through a corner the way a real semitrailer
## does. The boxes are rigid children of that chassis, which makes lag not a
## thing that has to be tuned — it is a thing that cannot be expressed.
##
## **It steers; it does not rotate.** That is the third rewrite and the one a
## playtest asked for. The version before this turned the cab at a fixed angular
## rate toward the bearing of the next mark, which is wrong twice over. Wrong
## once because the rate did not depend on speed, so the harder the rig braked
## for a corner the *tighter* it span — at the corner floor it was pirouetting
## almost on the spot. Wrong twice because aiming at the next mark makes a
## vehicle swing hard at it, cut the inside of the bend, and swing back the
## moment the mark is retired.
##
## So there is a wheel now. `_steer` is state, wound at a finite rate and stopped
## at full lock; yaw comes out of the bicycle model, `speed / wheelbase * tan
## steer`, so a stopped truck cannot turn at all and a slow one turns slowly. The
## driver aims by pure pursuit at a point *along the route*, further ahead the
## faster it goes. Corner speed is `sqrt(a_lat * r)` off the tightest radius in
## the road ahead — a bend is taken slowly because it is tight, not because a
## constant said so.
##
## The route comes from `PortLayout`, which is one-way end to end: the truck
## never reverses and never meets anything head-on. Traffic is deferred to the
## shared `TrafficCoordinator`, the same one the yard haulers use, so a truck
## queues behind a reach stacker instead of driving through it.

signal arrived
signal departed

## One scale for cab and chassis: they are one vehicle cut in two, and any
## mismatch reads as a toy towing a lorry.
const RIG_SCALE := 0.72
const BOX_SCALE := 0.60

# --- geometry read straight off `tools/sprites/gen_vehicles.py` -------------
## Cab sprite is 18x24 centred; its fifth wheel is drawn at y=19.
const CAB_H := 24.0
const CAB_FIFTH_WHEEL_Y := 19.0
## Chassis sprite is 18x48 centred; kingpin at y=2, rear axle and box slots as
## drawn. Everything below is those numbers in node space.
const CHASSIS_H := 48.0
const CHASSIS_KINGPIN_Y := 2.0
const CHASSIS_AXLE_Y := 34.0
const BOX_SLOT_Y := [14.0, 34.0]

## How far behind the cab's centre the fifth wheel sits.
const HITCH_BACK := (CAB_FIFTH_WHEEL_Y - CAB_H * 0.5) * RIG_SCALE
## Kingpin to the chassis sprite's own centre, and kingpin to its rear axle. The
## second one is the lever the trailer swings on.
const KINGPIN_TO_CENTRE := (CHASSIS_H * 0.5 - CHASSIS_KINGPIN_Y) * RIG_SCALE
const TRAILER_LEN := (CHASSIS_AXLE_Y - CHASSIS_KINGPIN_Y) * RIG_SCALE

const SPEED := 42.0
const ACCELERATION := 44.0
const BRAKING := 72.0
## Front axle to rear axle, in world pixels. The whole steering model hangs off
## this one number: a bicycle-model vehicle yaws at `speed / wheelbase * tan(steer)`,
## so a longer rig needs more road to come round and a stopped one cannot turn at
## all — which is the single thing the old model got wrong.
const WHEELBASE := 13.0
## Full lock, and how fast the wheel can be wound to it. A steer angle that
## snaps to its limit in one frame is a vehicle that pivots rather than steers.
const MAX_STEER := 0.62
const STEER_RATE := 2.9
## The most sideways acceleration the rig will accept before it slows for a bend.
## This is what decides corner speed now — not a hand-tuned floor — so a tight
## turn is taken slowly because it is tight, not because a constant said so.
const MAX_LATERAL := 30.0
## How far down the path the driver looks. Pure pursuit: aim at a point *along
## the route* rather than at the next mark, or the rig saws left and right as
## each mark passes and cuts every corner on the inside.
const LOOKAHEAD_MIN := 11.0
const LOOKAHEAD_PER_SPEED := 0.34
## How close counts as reaching a waypoint. A steered vehicle arcs into its mark
## instead of landing on it exactly, so a zero-radius test never fires.
const ARRIVE_RADIUS := 2.0
## A mark that has gone behind the nose this close counts as taken. Comfortably
## larger than the tightest turning circle the rig can hold.
const PASS_RADIUS := 16.0
## How far ahead the driver reads the road for bends to slow down for.
const SCAN_AHEAD := 44.0
const BRAKE_DISTANCE := 18.0
## Slowest a corner may be taken, as a fraction of `SPEED`, so a hairpin still
## crawls through rather than stopping dead in it.
const CORNER_FLOOR := 0.20
## A truck wedged behind something that will never move must not hold its bay for
## ever, so after this long it stops giving way and crawls on through.
const STALL_TIMEOUT := 9.0

var bay := 0
## Who is driving. Assigned by `PortWorld` before the truck enters the tree, from
## the same small pool of hauliers each time, so the player meets the same people.
var driver: NpcProfile

var _world: PortWorld
var _cab: Node2D
var _trailer: Node2D
var _boxes: Array[Sprite2D] = []
var _box_outlines: Array[Node2D] = []
var _outline_parts: Array[Node2D] = []
var _light_glows: Array[Sprite2D] = []
var _waypoints: Array[Vector2] = []
var _cruise := 0.0
var _facing := 0.0
var _trailer_facing := 0.0
## Where the chassis's rear axle currently sits, in the same space as `position`.
## The trailer's heading is solved from this each frame; see `_articulate`.
var _trailer_axle := Vector2.ZERO
var _stalled := 0.0
## Where the wheel actually is. State, not a target: winding it takes time, which
## is what gives a corner its entry arc instead of a hinge.
var _steer := 0.0
var _leaving := false
var _leave_on_arrival := false
var _done := false
var _wheel_phase := 0.0


func setup(world: PortWorld, bay_index: int, colors: Array[int],
		parked: bool) -> void:
	_world = world
	bay = bay_index
	_build()
	set_colors(colors)
	if parked:
		# A restored save is a terminal caught mid-shift, not one starting over:
		# a truck that had already docked is still docked when the game comes
		# back, rather than driving in a second time.
		position = PortLayout.gate_bay_centre(bay)
		_snap_heading(0.0)
	else:
		position = PortLayout.gate_entry()
		_snap_heading(PI)
		_waypoints = PortLayout.gate_arrival_route(bay)


func set_colors(colors: Array[int]) -> void:
	## The bed shows what is actually on it. An outbound truck fills up one box
	## at a time as the yard is worked; an inbound one empties the same way.
	for index in _boxes.size():
		var box := _boxes[index]
		box.visible = index < colors.size()
		_box_outlines[index].visible = box.visible and _outline_parts[0].visible
		if box.visible:
			var atlas := box.texture as AtlasTexture
			atlas.region = Rect2(posmod(colors[index], 8) * 24, 0, 24, 13)


func bed_slot_global_position(slot: int) -> Vector2:
	## The transfer follows the chassis, including its articulation, and lands on
	## the actual longitudinal slot rather than the painted bay centre.
	if slot >= 0 and slot < _boxes.size() and is_instance_valid(_boxes[slot]):
		return _boxes[slot].global_position
	return global_position


func depart() -> void:
	if _leaving or _done:
		return
	if not _waypoints.is_empty():
		# Turned away while still on its way in. It finishes the run first rather
		# than cutting the corner: the routes are axis-aligned one-way legs, and a
		# truck that beelines from halfway along the approach to the exit lane
		# drives diagonally across the parking bays to get there.
		_leave_on_arrival = true
		return
	_start_departure()


func _start_departure() -> void:
	_leaving = true
	_leave_on_arrival = false
	_stalled = 0.0
	_waypoints = PortLayout.gate_departure_route(bay)


func is_leaving() -> bool:
	return _leaving


func hit_test(world_pos: Vector2) -> bool:
	## Covers the whole rig, not just the cab: the boxes are the reason to tap it,
	## and they are at the far end from the node's own position.
	var centre := global_position + _heading(_facing) \
		* (-(HITCH_BACK + KINGPIN_TO_CENTRE) * 0.5)
	return Rect2(centre - Vector2(15.0, 30.0),
		Vector2(30.0, 60.0)).has_point(world_pos)


func objective_text() -> String:
	## What this run is for, in the driver's own terms.
	if _world == null or _world.tasks == null:
		return ""
	return _world.tasks.label_of(self)


func stage_text() -> String:
	if _leaving:
		return "voltando"
	return "a caminho" if not _waypoints.is_empty() else "na baia"


func set_interaction_state(actionable: bool, hovered: bool) -> void:
	var color := Color(1.0, 1.0, 1.0, 0.98) if hovered \
		else Color(0.20, 0.22, 0.26, 0.92)
	var width := 2.0 if hovered else 1.0
	for part in _outline_parts:
		part.visible = actionable
		for child in part.get_children():
			var copy := child as Sprite2D
			copy.position = copy.get_meta("outline_direction", Vector2.ZERO) * width
			(copy.material as ShaderMaterial).set_shader_parameter(
				"outline_color", color)
	for index in _box_outlines.size():
		_box_outlines[index].visible = actionable and _boxes[index].visible


# ---------------------------------------------------------------- building

func _build() -> void:
	# The trailer is a sibling of the cab, never a child: a child would inherit
	# the cab's rotation and the articulation would be a lie drawn on top of a
	# rigid rig.
	_trailer = Node2D.new()
	_trailer.name = "Chassis"
	add_child(_trailer)
	_cab = Node2D.new()
	_cab.name = "Cab"
	add_child(_cab)

	_build_trailer()
	_build_cab()
	_build_vehicle_lights()


func _build_cab() -> void:
	var shadow := Sprite2D.new()
	shadow.texture = preload("res://assets/sprites/prop_shadow.png")
	shadow.centered = true
	shadow.scale = Vector2(13.0 / 32.0, 18.0 / 20.0)
	shadow.modulate.a = 0.34
	shadow.position = Vector2(1.5, 2.0)
	_cab.add_child(shadow)

	var cab := Sprite2D.new()
	cab.texture = PortDB.tex("veh_truck_cab")
	cab.centered = true
	cab.scale = Vector2(RIG_SCALE, RIG_SCALE)
	var cab_outline := _outline_for(cab)
	_cab.add_child(cab_outline)
	_outline_parts.append(cab_outline)
	_cab.add_child(cab)


func _build_trailer() -> void:
	var shadow := Sprite2D.new()
	shadow.texture = preload("res://assets/sprites/prop_shadow.png")
	shadow.centered = true
	shadow.scale = Vector2(13.0 / 32.0, 34.0 / 20.0)
	shadow.modulate.a = 0.30
	shadow.position = Vector2(1.5, KINGPIN_TO_CENTRE + 2.0)
	_trailer.add_child(shadow)

	var chassis := Sprite2D.new()
	chassis.texture = preload("res://assets/sprites/veh_truck_chassis.png")
	chassis.centered = true
	chassis.scale = Vector2(RIG_SCALE, RIG_SCALE)
	chassis.position = Vector2(0.0, KINGPIN_TO_CENTRE)
	var chassis_outline := _outline_for(chassis)
	_trailer.add_child(chassis_outline)
	_outline_parts.append(chassis_outline)
	_trailer.add_child(chassis)

	for slot in GateDock.TRUCK_CAPACITY:
		var box := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = preload("res://assets/sprites/container_sheet.png")
		atlas.region = Rect2(0, 0, 24, 13)
		box.texture = atlas
		box.centered = true
		box.scale = Vector2(BOX_SCALE, BOX_SCALE)
		# Container art is drawn landscape; the chassis is nose-up. Rotating the
		# box makes a bitrem read as two lengthwise boxes in a row rather than as
		# cargo laid sideways across the trailer.
		box.rotation = PI / 2.0
		box.position = Vector2(0.0, slot_offset(slot))
		box.visible = false
		var box_outline := _outline_for(box)
		box_outline.visible = false
		_trailer.add_child(box_outline)
		_outline_parts.append(box_outline)
		_box_outlines.append(box_outline)
		_trailer.add_child(box)
		_boxes.append(box)


static func slot_offset(slot: int) -> float:
	## A box slot in trailer space: measured from the drawing, then shifted so the
	## trailer's own origin is the kingpin rather than the sprite's centre.
	var index := clampi(slot, 0, BOX_SLOT_Y.size() - 1)
	return (float(BOX_SLOT_Y[index]) - CHASSIS_KINGPIN_Y) * RIG_SCALE


func _outline_for(source: Sprite2D) -> Node2D:
	var root := Node2D.new()
	root.position = source.position
	root.rotation = source.rotation
	root.scale = source.scale
	root.visible = false
	for direction in [
		Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
		Vector2(-1, 0), Vector2(1, 0),
		Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1),
	]:
		var copy := Sprite2D.new()
		copy.texture = source.texture
		copy.centered = source.centered
		copy.position = direction
		copy.set_meta("outline_direction", direction)
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/interaction_outline.gdshader")
		copy.material = material
		root.add_child(copy)
	return root


func _build_vehicle_lights() -> void:
	# Headlamps on the cab, tail lamps on the chassis: they belong to different
	# bodies and must swing with the one they are bolted to.
	_add_vehicle_light(_cab, Vector2(-3.8, -9.0), Color8(255, 247, 214), 0.07)
	_add_vehicle_light(_cab, Vector2(3.8, -9.0), Color8(255, 247, 214), 0.07)
	var tail := KINGPIN_TO_CENTRE + (CHASSIS_H * 0.5 - 2.0) * RIG_SCALE
	_add_vehicle_light(_trailer, Vector2(-3.4, tail), Color8(255, 45, 38), 0.055)
	_add_vehicle_light(_trailer, Vector2(3.4, tail), Color8(255, 45, 38), 0.055)


func _add_vehicle_light(parent: Node2D, pos: Vector2, color: Color,
		scale_value: float) -> void:
	var glow := Sprite2D.new()
	glow.texture = preload("res://assets/sprites/prop_glow.png")
	glow.position = pos
	glow.scale = Vector2.ONE * scale_value
	glow.modulate = color
	glow.modulate.a = 0.0
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	parent.add_child(glow)
	_light_glows.append(glow)


func _enter_tree() -> void:
	if _world == null:
		return
	if _world.traffic != null:
		_world.traffic.join(self)
	# The trip itself is this driver's task, keyed on the bay, so the card can say
	# what the run is for and no two drivers share a bay.
	if _world.tasks != null and driver != null:
		_world.tasks.claim(self, NpcCatalog.STATION_CITY, "cidade:baia%d" % bay)


func _exit_tree() -> void:
	if _world == null:
		return
	if _world.traffic != null:
		_world.traffic.leave(self)
	if _world.tasks != null:
		# A completed round trip counts for the driver: it came in loaded and it
		# is leaving loaded.
		if _done and driver != null:
			_world.tasks.complete(self)
		else:
			_world.tasks.release(self)


# ----------------------------------------------------------------- driving

static func _heading(facing: float) -> Vector2:
	## Nose direction. Every vehicle sprite in this game is drawn nose-up, so
	## heading north is rotation zero.
	return Vector2(sin(facing), -cos(facing))


static func _bearing_to(delta: Vector2) -> float:
	return atan2(delta.x, -delta.y)


func _snap_heading(facing: float) -> void:
	## Place the rig straight, cab and trailer in line. Used on spawn and on a
	## restore, where there is no previous frame to articulate from.
	_facing = facing
	_steer = 0.0
	_trailer_facing = facing
	_cab.rotation = _facing
	_trailer.rotation = _trailer_facing
	_trailer.position = -_heading(_facing) * HITCH_BACK
	_trailer_axle = position + _trailer.position \
		- _heading(_facing) * TRAILER_LEN


func _process(delta: float) -> void:
	_update_vehicle_lights()
	_animate_suspension(delta)
	if not _done and not _waypoints.is_empty():
		_drive(delta)
	_articulate()


func _drive(delta: float) -> void:
	var target: Vector2 = _waypoints[0]
	var to_target := target - position
	var heading := _heading(_facing)
	# Reached, **or passed**. A steered vehicle cannot land on a point: if the
	# only test is a small radius, a mark the rig sweeps past just outside it
	# becomes a roundabout it circles for ever. Accepting a mark that has gone
	# behind the nose is what makes the route finite.
	if to_target.length() <= ARRIVE_RADIUS \
			or (to_target.length() < PASS_RADIUS and heading.dot(to_target) <= 0.0):
		_waypoints.pop_front()
		if _waypoints.is_empty():
			# Park **on** the mark. A steered vehicle arrives near a point, never
			# on it, and the last point of a route is a painted bay or the edge of
			# the map — both of which want to be exact. It brakes into the last
			# leg, so this is a pixel or two, not a jump.
			position = target
			_finish()
		return

	# --- steer -------------------------------------------------------------
	# Pure pursuit onto a point *along the route*, then a bicycle model. Aiming
	# straight at the next mark is what produced the corners that looked wrong:
	# the rig swung hard at each mark, cut the inside of the bend, then swung
	# back when the mark behind it was replaced.
	var aim := _pursuit_point()
	_steer = move_toward(_steer, _wanted_steer(aim), STEER_RATE * delta)

	# --- speed -------------------------------------------------------------
	# A bend is taken as slowly as its own radius demands, not as slowly as a
	# constant says. v = sqrt(a_lat * r), which is the same sum a driver does
	# without noticing.
	var wanted := SPEED * _bend_throttle()
	if _waypoints.size() == 1 and not _leaving:
		# Pull up into the bay rather than stopping dead on the mark.
		wanted *= clampf(to_target.length() / BRAKE_DISTANCE, 0.2, 1.0)
	_cruise = move_toward(_cruise, wanted,
		(ACCELERATION if wanted > _cruise else BRAKING) * delta)

	# --- and only now does the rig turn ------------------------------------
	# Yaw comes out of *travelling* while the wheel is over, so a stopped truck
	# cannot rotate on the spot and a slow one turns slowly. The old model span at
	# a fixed rate regardless of speed, which meant the tighter it braked for a
	# corner the harder it pirouetted through it.
	#
	# Both the turn and the step are held back until traffic has been asked, so a
	# rig queueing behind a reach stacker sits still instead of slowly winding
	# itself round while it waits.
	var travel := _cruise * delta
	var next_facing := wrapf(_facing + yaw_for(travel, _steer), -PI, PI)
	var step := _heading(next_facing) * travel
	if _stalled < STALL_TIMEOUT and _world != null and _world.traffic != null \
			and not _world.traffic.can_advance(self, position + step):
		_cruise = move_toward(_cruise, 0.0, BRAKING * delta)
		_stalled += delta
		return
	_stalled = 0.0
	_facing = next_facing
	position += step
	_cab.rotation = _facing


static func yaw_for(travel: float, steer: float) -> float:
	## The bicycle model, on its own so it can be reasoned about and tested.
	##
	## Yaw is a function of *distance covered*, not of time: a rig that has not
	## moved has not turned, however hard the wheel is over. That single sentence
	## is the whole difference from the version a playtest called unrealistic.
	if absf(steer) < 0.0001 or absf(travel) < 0.0001:
		return 0.0
	return travel / WHEELBASE * tan(steer)


func _pursuit_point() -> Vector2:
	## The point the driver is actually looking at: `lookahead` pixels along the
	## remaining route, interpolated across marks rather than snapping between
	## them. Looking further ahead the faster it goes is why a rig can hold a
	## motorway line and still place itself in a bay.
	var lookahead := LOOKAHEAD_MIN + _cruise * LOOKAHEAD_PER_SPEED
	var from := position
	var budget := lookahead
	for mark: Vector2 in _waypoints:
		var leg := mark - from
		var span := leg.length()
		if span >= budget:
			return from + leg / maxf(span, 0.0001) * budget
		budget -= span
		from = mark
	# Route shorter than the lookahead: aim at the end of it, which is what makes
	# the last few metres into a bay a straight line rather than a wander.
	return from


func _wanted_steer(aim: Vector2) -> float:
	## The steer angle whose arc passes through the aim point. Standard pure
	## pursuit: `atan(2 L sin(a) / d)`, with `a` the bearing error off the nose.
	var to_aim := aim - position
	var span := to_aim.length()
	if span < 0.01:
		return 0.0
	var error := wrapf(_bearing_to(to_aim) - _facing, -PI, PI)
	return clampf(atan2(2.0 * WHEELBASE * sin(error), span),
		-MAX_STEER, MAX_STEER)


func _bend_throttle() -> float:
	## How fast the road ahead allows. The sharpest corner within `SCAN_AHEAD`
	## sets the limit, and the limit is the physical one — the speed at which the
	## rig would start sliding rather than turning.
	var radius := _tightest_radius_ahead()
	if radius >= INF:
		return 1.0
	return clampf(sqrt(MAX_LATERAL * radius) / SPEED, CORNER_FLOOR, 1.0)


func _tightest_radius_ahead() -> float:
	## The radius of the tightest bend within scanning distance, from the angle
	## between consecutive legs. A right angle over a short leg is a tight bend;
	## the same angle over a long one is barely a bend at all.
	var radius := INF
	var from := position
	var travelled := 0.0
	for index in _waypoints.size() - 1:
		var mark: Vector2 = _waypoints[index]
		var leg := mark - from
		travelled += leg.length()
		if travelled > SCAN_AHEAD:
			break
		var next_leg: Vector2 = _waypoints[index + 1] - mark
		if leg.length_squared() < 0.01 or next_leg.length_squared() < 0.01:
			from = mark
			continue
		var turn := absf(wrapf(_bearing_to(next_leg) - _bearing_to(leg), -PI, PI))
		if turn > 0.05:
			# The arc that joins the two legs, taken over the shorter of them.
			var reach := minf(leg.length(), next_leg.length()) * 0.5
			radius = minf(radius, reach / tan(minf(turn, PI * 0.98) * 0.5))
		from = mark
	return maxf(radius, 1.0) if radius < INF else INF


func _articulate() -> void:
	## The chassis pivots on the fifth wheel and drags its axle behind it.
	##
	## The axle is **state**, not something derived from the trailer's heading —
	## that was the first attempt and it is a fixed point: recomputing the axle
	## from the heading and then the heading from the axle leaves the trailer
	## permanently in line with the cab. What actually makes a semitrailer cut in
	## through a corner is that the axle stays where it was while the hitch moves
	## on, and the body between them turns to follow.
	var hitch := position - _heading(_facing) * HITCH_BACK
	var span := hitch - _trailer_axle
	if span.length_squared() > 0.0001:
		_trailer_facing = _bearing_to(span)
	_trailer_axle = hitch - _heading(_trailer_facing) * TRAILER_LEN
	_trailer.position = hitch - position
	_trailer.rotation = _trailer_facing


func _animate_suspension(delta: float) -> void:
	## A sub-pixel vibration gives the truck weight without moving its route,
	## collision or traffic reservation. Cab only — a loaded chassis on air
	## suspension does not bounce, and a shaking container reads as a bug.
	var rolling := not _waypoints.is_empty() and _cruise > 2.0
	if rolling:
		_wheel_phase += delta * (5.0 + _cruise * 0.16)
	var target := Vector2(sin(_wheel_phase) * 0.24,
		cos(_wheel_phase * 0.5) * 0.16) if rolling else Vector2.ZERO
	_cab.position = _cab.position.lerp(target, minf(1.0, delta * 10.0))


func _finish() -> void:
	_cruise = 0.0
	if _leaving:
		_done = true
		departed.emit()
		queue_free()
		return
	if _world != null:
		_world.spawn_dust(position + Vector2(-7.0, 12.0))
	arrived.emit()
	if _leave_on_arrival:
		_start_departure()


func _update_vehicle_lights() -> void:
	var night := Skyscape._night_factor(TimeManager.time_of_day)
	var target := maxf(clampf(night * 1.2, 0.0, 1.0),
		0.32 if not _waypoints.is_empty() else 0.14)
	for index in _light_glows.size():
		var tail := index >= 2
		_light_glows[index].modulate.a = target * (0.72 if tail else 0.55)
