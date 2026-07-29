class_name RoadTruck
extends Node2D
## A city truck on the terminal's road.
##
## It exists so that nothing on the apron appears out of nowhere. A bay's cargo
## is only ever on screen because a truck drove it in through the gate, and it
## only ever leaves because a truck drove it out again — the box is visible on
## the bed for the whole trip in both directions.
##
## A road chassis takes one forty-foot box or two twenty-foot ones, so the bed
## is drawn for exactly `GateDock.TRUCK_CAPACITY` and nothing else fits.
##
## The route comes from `PortLayout`, which is one-way end to end: the truck
## never reverses and never meets anything head-on. Traffic is deferred to the
## shared `TrafficCoordinator`, the same one the yard haulers use, so a truck
## queues behind a reach stacker instead of driving through it.

signal arrived
signal departed

const BODY_SCALE := 0.70
const BOX_SCALE := 0.62
## Offsets inside the sprite: veh_tt is a cab over a flat bed, and the boxes
## belong on the bed rather than on the driver.
const BED_HEAD := -4.9
const BOX_PITCH := 8.1

const SPEED := 42.0
const ACCELERATION := 44.0
const BRAKING := 72.0
const BRAKE_DISTANCE := 18.0
const TURN_RATE := 6.0
## A truck wedged behind something that will never move must not hold its bay
## for ever, so after this long it stops giving way and crawls on through.
const STALL_TIMEOUT := 9.0

var bay := 0

var _world: PortWorld
var _body: Node2D
var _boxes: Array[Sprite2D] = []
var _waypoints: Array[Vector2] = []
var _cruise := 0.0
var _facing := 0.0
var _stalled := 0.0
var _leaving := false
var _leave_on_arrival := false
var _done := false


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
		_face(Vector2.UP)
	else:
		position = PortLayout.gate_entry()
		_face(Vector2.DOWN)
		_waypoints = PortLayout.gate_arrival_route(bay)


func set_colors(colors: Array[int]) -> void:
	## The bed shows what is actually on it. An outbound truck fills up one box
	## at a time as the yard is worked; an inbound one empties the same way.
	for index in _boxes.size():
		var box := _boxes[index]
		box.visible = index < colors.size()
		if box.visible:
			var atlas := box.texture as AtlasTexture
			atlas.region = Rect2(posmod(colors[index], 8) * 24, 0, 24, 13)


func depart() -> void:
	if _leaving or _done:
		return
	if not _waypoints.is_empty():
		# Turned away while still on its way in. It finishes the run first
		# rather than cutting the corner: the routes are axis-aligned one-way
		# legs, and a truck that beelines from halfway along the approach to
		# the exit lane drives diagonally across the parking bays to get there.
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


# ---------------------------------------------------------------- building

func _build() -> void:
	_body = Node2D.new()
	add_child(_body)

	var shadow := Sprite2D.new()
	shadow.texture = preload("res://assets/sprites/prop_shadow.png")
	shadow.centered = true
	shadow.scale = Vector2(14.0 / 32.0, 34.0 / 20.0)
	shadow.modulate.a = 0.34
	# Inside the body, so it turns with the truck instead of staying a
	# north-south smudge while the truck drives east.
	_body.add_child(shadow)

	var cab := Sprite2D.new()
	cab.texture = preload("res://assets/sprites/veh_tt.png")
	cab.centered = true
	cab.scale = Vector2(BODY_SCALE, BODY_SCALE)
	_body.add_child(cab)

	for slot in GateDock.TRUCK_CAPACITY:
		var box := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = preload("res://assets/sprites/container_sheet.png")
		atlas.region = Rect2(0, 0, 24, 13)
		box.texture = atlas
		box.centered = true
		box.scale = Vector2(BOX_SCALE, BOX_SCALE)
		box.position = Vector2(0.0, BED_HEAD + BOX_PITCH * (slot + 0.5))
		box.visible = false
		_body.add_child(box)
		_boxes.append(box)


func _enter_tree() -> void:
	if _world != null and _world.traffic != null:
		_world.traffic.join(self)


func _exit_tree() -> void:
	if _world != null and _world.traffic != null:
		_world.traffic.leave(self)


# ----------------------------------------------------------------- driving

func _process(delta: float) -> void:
	if _done or _waypoints.is_empty():
		return
	var target: Vector2 = _waypoints[0]
	var to_target := target - position
	var wanted := SPEED
	if _waypoints.size() == 1 and not _leaving:
		# Pull up into the bay rather than stopping dead on the mark.
		wanted = SPEED * clampf(to_target.length() / BRAKE_DISTANCE, 0.2, 1.0)
	_cruise = move_toward(_cruise, wanted,
		(ACCELERATION if wanted > _cruise else BRAKING) * delta)
	var step := _cruise * delta
	if to_target.length() <= maxf(step, 0.5):
		position = target
		_waypoints.pop_front()
		if _waypoints.is_empty():
			_finish()
		return
	var dir := to_target.normalized()
	if _stalled < STALL_TIMEOUT and _world != null and _world.traffic != null \
			and not _world.traffic.can_advance(self, position + dir * step):
		_cruise = move_toward(_cruise, 0.0, BRAKING * delta)
		_face(dir, delta)
		_stalled += delta
		return
	_stalled = 0.0
	position += dir * step
	_face(dir, delta)


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


func _face(dir: Vector2, delta: float = 0.0) -> void:
	## Four sides, like every other vehicle here, but turned into rather than
	## snapped to — a truck that pivots 90 degrees in one frame reads as a
	## sliding box, not as something with mass.
	##
	## Every vehicle sprite in the game is drawn nose-up, so heading north is
	## rotation zero.
	var wanted: float
	if absf(dir.x) > absf(dir.y):
		wanted = PI / 2.0 if dir.x > 0.0 else -PI / 2.0
	else:
		wanted = PI if dir.y > 0.0 else 0.0
	_facing = wanted if delta <= 0.0 \
		else rotate_toward(_facing, wanted, TURN_RATE * delta)
	_body.rotation = _facing
