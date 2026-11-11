class_name CargoRelay
extends FlyingContainer
## The visible chain of custody for one container.
##
## A box does not fly from a ship's hold to a stack. A portainer lifts it off the
## hull and sets it on the apron; a terminal tractor drives it down the quay and
## into the block row it belongs to; the transtainer that owns those stacks lifts
## it off the chassis and puts it away. Every one of those hand-offs is a machine
## the player bought, which is the whole point: the itinerary *is* the equipment
## list, read out loud.
##
## The contract with `FlyingContainer` is unchanged, and the cargo layer depends
## on all of it: `duration()` answers before the first frame, `landed` fires
## exactly once, and the node frees itself immediately after. So every leg is
## bounded. A tractor that never turns up, a machine that is freed mid-leg, a
## relay force-landed by the capture harness — each of them collapses the rest of
## the itinerary into the plain arc this class inherits. **Nothing here can stall
## a transfer**, because a stalled transfer is a container that never commits.

## What the leg is, which decides who performs it and how the box moves.
enum Kind {
	HOP,      ## the box crosses on its own — no machine owns this stretch yet
	LIFT,     ## a gantry or stacker swings it between ground and its home
	RIDE,     ## a tractor carries it along a road
}

## Ceiling on one ride, counted from the moment the box is aboard. A tractor
## boxed in by traffic hands the box back rather than holding a berth transfer
## open indefinitely.
const RIDE_DEADLINE := 12.0
## How long the box may sit on the apron waiting for its tractor to arrive.
##
## This is the number that used to read as a bug. The box left the hull, stopped
## dead on the quay, and stayed there for as long as the tractor took to fight
## its way over — up to the full ride deadline. Meanwhile the berth still counted
## it as in flight, so the ship could not change phase and the player could not
## tap anything: one slow tractor froze the whole terminal. A transfer is allowed
## to wait for its presentation for about as long as one crane cycle, and after
## that the box flies itself.
const APPROACH_GRACE := 1.6
## Absolute ceiling on an itinerary, over its own planned length. Nothing may
## hold a transfer open past this, whatever combination of legs went wrong.
const ITINERARY_SLACK := 6.0
## Amplitude of the settle while the box rests on the apron. A box that is not
## moving at all reads as a frozen game; a box that breathes reads as waiting.
const REST_BOB := 0.7
## Metres per second the box appears to travel on a chassis, in world pixels.
const RIDE_SPEED := 46.0
## A lift is a fixed beat regardless of reach: spreader down, lock, up, across.
const LIFT_TIME := 0.72
## Arc height for the short hand-off hops, well under the full-flight `LIFT`.
const HANDOFF_LIFT := 12.0
## How fast a load settles onto the chassis's heading, in radians per second.
## Deliberately slower than `StructureActor.TURN_RATE`.
const BOX_TURN_RATE := 5.0

## Which gantry can work each end of a move. Order is preference: the first one
## with a free operator takes it. The gate has none on purpose — a road chassis
## is worked by the wheeled machine that then carries the box away, so at the
## gate the lift and the ride are the same machine and the same leg.
const LIFTERS := {
	"ship": ["sts", "flutuante"],
	"yard": ["rtg"],
	"gate": [],
}

var _world: Node = null
var _legs: Array[Dictionary] = []
var _leg := -1
var _leg_from := Vector2.ZERO
var _leg_to := Vector2.ZERO
var _leg_lift := HANDOFF_LIFT
var _leg_time := 0.0
var _leg_duration := 0.0
var _deadline := 0.0
var _carrier: Node = null
var _mirror: Node = null
var _planned := 0.0
var _approach_left := 0.0
var _alive := 0.0


func plan(world: Node, start: Vector2, end: Vector2) -> bool:
	## Build the itinerary. Returns false when the two ends are close enough, the
	## terminal bare enough, or the fleet busy enough that the plain arc is the
	## honest picture — the caller then uses this node exactly as a
	## `FlyingContainer`.
	##
	## The chassis is booked **here**, before the crane has lifted anything, and a
	## run that cannot book one is not a relay at all. That is what keeps a tap
	## feeling like a tap: the number of boxes being driven is exactly the number
	## of machines free to drive them, and every other box crosses at the old
	## speed instead of standing on the apron waiting for a tractor that may never
	## come. It also means the tractor is already on its way to the hook while the
	## box is still in the air on its first leg.
	_world = world
	var from_zone := _zone_of(start)
	var to_zone := _zone_of(end)
	if from_zone == to_zone or from_zone == "" or to_zone == "":
		return false
	var pick := PortLayout.quay_interchange(start.y) if from_zone == "ship" \
		else _land_interchange(from_zone, start)
	var drop := PortLayout.quay_interchange(end.y) if to_zone == "ship" \
		else _land_interchange(to_zone, end)
	_carrier = _claim_tractor(pick, drop)
	if _carrier == null:
		return false
	_legs = [
		{"kind": Kind.LIFT, "from": start, "to": pick, "zone": from_zone,
			"dur": LIFT_TIME},
		{"kind": Kind.RIDE, "from": pick, "to": drop, "zone": "",
			"dur": maxf(0.6, _road_length(pick, drop) / RIDE_SPEED)},
		{"kind": Kind.LIFT, "from": drop, "to": end, "zone": to_zone,
			"dur": LIFT_TIME},
	]
	_planned = 0.0
	for leg: Dictionary in _legs:
		_planned += float(leg.dur)
	_end = end
	return true


func duration() -> float:
	return _planned if not _legs.is_empty() else super.duration()


func _ready() -> void:
	if _legs.is_empty():
		set_process(false)
		super._ready()
		return
	# No tween drives a relay: legs hand over to each other, and two of the three
	# are paced by a machine rather than by the clock.
	set_process(true)
	_begin_leg(0)


func _process(delta: float) -> void:
	if _leg < 0 or _leg >= _legs.size():
		return
	# The watchdog is outside the per-leg logic on purpose: it is the one promise
	# that holds even if a leg forgets to fail.
	_alive += delta
	if _alive > _planned + ITINERARY_SLACK and int(_legs[_leg].kind) != Kind.HOP:
		_hop_the_rest()
		return
	if int(_legs[_leg].kind) == Kind.RIDE:
		_ride(delta)
		return
	_leg_time += delta
	var k := clampf(_leg_time / maxf(0.01, _leg_duration), 0.0, 1.0)
	_step(k)
	if k >= 1.0:
		_next_leg()


# ------------------------------------------------------------------- planning

func _zone_of(pos: Vector2) -> String:
	## Which part of the terminal a transfer endpoint belongs to. Positions come
	## from the ship's bays, the yard's slots and the gate's truck beds, so the
	## three regions are disjoint by construction.
	if pos.x >= PortLayout.QUAY_X1:
		return "ship"
	if pos.y < PortLayout.YARD_Y0:
		return "gate"
	if pos.x < PortLayout.QUAY_X0:
		return "yard"
	return ""


func _land_interchange(zone: String, pos: Vector2) -> Vector2:
	if zone == "gate":
		return PortLayout.gate_interchange(pos.x)
	return PortLayout.block_interchange(PortLayout.nearest_block(pos))


static func _road_length(a: Vector2, b: Vector2) -> float:
	## Tractors drive the spine and then a lane, never the diagonal, so the ride
	## has to be priced the way it will actually be driven.
	return absf(a.x - PortLayout.interchange_spine_x()) + absf(a.y - b.y) \
		+ absf(b.x - PortLayout.interchange_spine_x())


# ---------------------------------------------------------------------- legs

func _begin_leg(index: int) -> void:
	# Only the gantry claim is per-leg. The chassis was booked when the itinerary
	# was drawn and is driving to meet the box; releasing it here would send it
	# home between the lift and the ride it was called out for.
	_release_mirror()
	_leg = index
	var leg: Dictionary = _legs[index]
	_leg_from = leg.from
	_leg_to = leg.to
	_leg_time = 0.0
	_leg_duration = float(leg.dur)
	_leg_lift = HANDOFF_LIFT if int(leg.kind) != Kind.HOP else _lift
	position = _leg_from
	_step(0.0)
	match int(leg.kind):
		Kind.LIFT:
			_mirror = _claim_lifter(str(leg.zone), _leg_from, _leg_to,
				_leg_duration)
		Kind.RIDE:
			_deadline = RIDE_DEADLINE
			_approach_left = APPROACH_GRACE
		_:
			pass


func _next_leg() -> void:
	if _leg + 1 < _legs.size():
		_begin_leg(_leg + 1)
		return
	_release_claims()
	set_process(false)
	_start = _leg_from
	_land()


func _step(k: float) -> void:
	## One leg's worth of the parent's travel maths. Rotation only settles on the
	## last leg: a box carried lengthwise on a road chassis must not start
	## rotating into its stack while it is still two hand-offs away.
	var eased := _ease(k)
	position = _leg_from.lerp(_leg_to, eased)
	var height := sin(k * PI) * _leg_lift
	_box.position = Vector2(0, -height)
	var final_leg := _leg >= _legs.size() - 1
	_box.rotation = lerp_angle(_start_rotation, _end_rotation, eased) \
		if final_leg else _start_rotation
	_shadow.visible = true
	_shadow.scale = Vector2.ONE * (1.0 - height / (_leg_lift * 2.6))
	_shadow.modulate.a = 0.45 - height / (_leg_lift * 5.0)
	_glint.position.y = 6.0 - height
	_glint.modulate.a = sin(k * PI) * 0.3


var _snatched := false


func snatch() -> bool:
	## The player's finger takes the box off whatever machine is carrying it,
	## and it hops straight to its destination, quickly. Once per box.
	if _snatched or not is_processing():
		return false
	_snatched = true
	_release_claims()
	_legs = [{"kind": Kind.HOP, "from": position, "to": _end, "zone": "",
		"dur": 0.28}]
	_begin_leg(0)
	return true


func _hop_the_rest() -> void:
	## Everything from here to the destination, on the box's own. This is the
	## escape hatch every failure funnels into, and it is the behaviour the game
	## had before relays existed, so it can never look broken.
	_release_claims()
	_legs = [{"kind": Kind.HOP, "from": position, "to": _end, "zone": "",
		"dur": clampf(0.42 + position.distance_to(_end) / 520.0, 0.5, 0.9)}]
	_begin_leg(0)


# --------------------------------------------------------------------- riding

func _ride(delta: float) -> void:
	if _carrier == null or not is_instance_valid(_carrier):
		# Booked at plan time, so losing it now means it was freed or gave up.
		_carrier = null
		_hop_the_rest()
		return
	var stage: int = _carrier.call("relay_stage")
	if stage == StructureActor.RELAY_APPROACH:
		# Waiting on the apron, not stalled. The grace is short and the box keeps
		# breathing, so a tractor that is not almost there loses the run instead
		# of holding the berth open.
		_approach_left -= delta
		if _approach_left <= 0.0:
			_hop_the_rest()
			return
		position = _leg_from
		_box.position = Vector2(0, -absf(sin(_approach_left * 6.0)) * REST_BOB)
		_shadow.visible = true
		return
	_deadline -= delta
	match stage:
		StructureActor.RELAY_CARRY:
			position = _carrier.call("relay_bed_position")
			# Swing with the chassis rather than snap: the tractor itself turns
			# over `TURN_RATE`, and a load that arrives at the new heading first
			# reads as the box steering the truck.
			_box.rotation = rotate_toward(_box.rotation,
				float(_carrier.call("relay_bed_rotation")), BOX_TURN_RATE * delta)
			_box.position = Vector2.ZERO
			_shadow.visible = true
			_shadow.scale = Vector2.ONE
			_shadow.modulate.a = 0.45
		StructureActor.RELAY_DONE:
			position = _leg_to
			_next_leg()
			return
		StructureActor.RELAY_NONE:
			# The tractor gave the run back — blocked, freed, or rebuilt under it.
			_carrier = null
			_hop_the_rest()
			return
		_:
			position = _leg_from
	if _deadline <= 0.0:
		_hop_the_rest()


# --------------------------------------------------------------------- claims

func _structures() -> Node:
	if _world == null or not is_instance_valid(_world):
		return null
	return _world.get("structures") as Node


func _claim_lifter(zone: String, from: Vector2, to: Vector2,
		seconds: float) -> Node:
	var layer := _structures()
	if layer == null or not layer.has_method("claim_lifter"):
		return null
	return layer.call("claim_lifter", LIFTERS.get(zone, []), from, to, seconds)


func _claim_tractor(from: Vector2, to: Vector2) -> Node:
	var layer := _structures()
	if layer == null or not layer.has_method("claim_tractor"):
		return null
	return layer.call("claim_tractor", from, to)


func _release_mirror() -> void:
	if _mirror != null and is_instance_valid(_mirror):
		_mirror.call("release_relay")
	_mirror = null


func _release_claims() -> void:
	_release_mirror()
	if _carrier != null and is_instance_valid(_carrier):
		_carrier.call("release_relay")
	_carrier = null


# ------------------------------------------------------------------ teardown

func _finish_landing() -> void:
	## Also the capture harness's force-land, so it has to be safe to call at any
	## point in the itinerary.
	set_process(false)
	_release_claims()
	super._finish_landing()


func _exit_tree() -> void:
	## A rolled-back transfer frees the traveller outright. Whatever was holding
	## the box has to be told, or a tractor drives an empty chassis to a block
	## for a container that no longer exists.
	_release_claims()
