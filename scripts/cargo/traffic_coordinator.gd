class_name TrafficCoordinator
extends RefCounted
## Keeps the terminal's vehicles out of each other.
##
## The first version only checked a distance at the gate and then held that
## "lane" for the whole job, so by the time a second hauler asked for clearance
## the first one was already parked three blocks away and the check always
## passed — vehicles spawned on top of each other and drove straight through
## one another on the driving lanes.
##
## Two rules replace it, and between them they make a deadlock impossible:
##
## 1. **One-way geometry.** The service road is two columns (in on the left,
##    out on the right) and a hauler reserves the whole driving lane it is
##    about to work. Nothing ever meets anything head-on.
## 2. **Following distance.** A vehicle may only advance if no other vehicle is
##    within `MIN_GAP` of where it is going *and ahead of it*. Because every
##    shared stretch is one-way, "ahead" is unambiguous and traffic queues
##    instead of blocking.
##
## It is deliberately independent from rendering so it stays valid when the
## yard is rebuilt, a parcel is bought, or a save is restored.

const MIN_GAP := 15.0
## Oncoming traffic in the parallel column is only 14px away, well inside the
## following gap. Judging it by the same rule froze both columns solid: each
## vehicle counted the other as an obstacle in front of it and neither could
## ever move. You queue behind someone going your way; you do not stop for the
## next lane over unless you are about to drive into it.
const CROSS_GAP := 10.0
const SAME_WAY := 0.3
const GATE_GAP := 26.0
## Vehicles converging from different yard rows briefly retain their old
## horizontal heading after joining the same vertical exit column. Geometry,
## not that stale heading, identifies that they are now in one lane.
const SAME_LANE_WIDTH := 7.0

var _vehicles: Array = []          # Array[WeakRef] of Node2D
var _lanes: Dictionary = {}        # lane key -> WeakRef of the holder
var _headings: Dictionary = {}     # instance id -> Vector2 unit heading


func join(actor: Node2D) -> void:
	if actor == null or _index_of(actor) >= 0:
		return
	_vehicles.append(weakref(actor))


func leave(actor: Node2D) -> void:
	var index := _index_of(actor)
	if index >= 0:
		_vehicles.remove_at(index)
	if actor != null:
		_headings.erase(actor.get_instance_id())
	release(actor)


func reserve_lane(actor: Node2D, lane_key: String) -> bool:
	## Exactly one hauler works a driving lane at a time. A lane is a dead end
	## for a vehicle that has to come back out of it, so sharing one is the
	## only way two haulers could ever meet nose to nose.
	if actor == null:
		return false
	var holder: Node2D = _lane_holder(lane_key)
	if holder != null and holder != actor:
		return false
	release(actor)
	_lanes[lane_key] = weakref(actor)
	return true


func release(actor: Node2D) -> void:
	for key: String in _lanes.keys():
		var holder: Node2D = _lane_holder(key)
		if holder == null or holder == actor:
			_lanes.erase(key)


func holds_lane(actor: Node2D, lane_key: String) -> bool:
	return _lane_holder(lane_key) == actor


func can_advance(actor: Node2D, to: Vector2, gap: float = MIN_GAP) -> bool:
	## True when the step is clear.
	##
	## Only vehicles *in front* block — a vehicle being tailgated must never be
	## stopped by the one behind it, or the whole column freezes — and only
	## vehicles going the same way get the full following gap.
	if actor == null:
		return true
	var heading := to - actor.global_position
	if heading.length_squared() <= 0.0001:
		return true
	heading = heading.normalized()
	_headings[actor.get_instance_id()] = heading
	for other in _live_vehicles():
		if other == actor:
			continue
		var offset := other.global_position - actor.global_position
		var other_to_next := other.global_position.distance_to(to)
		var directly_ahead := offset.dot(heading) > 0.0 \
			and absf(offset.cross(heading)) < SAME_LANE_WIDTH
		if directly_ahead and other_to_next < gap:
			return false
		var other_heading: Vector2 = _headings.get(other.get_instance_id(), heading)
		var same_way := other_heading.dot(heading) > SAME_WAY
		if same_way:
			# A follower only yields to the vehicle ahead. Applying this to the
			# one behind makes both stop and freezes the whole column.
			if offset.dot(heading) > 0.0 and other_to_next < gap:
				return false
			continue
		if other_to_next >= CROSS_GAP:
			continue
		# Two vehicles converging on a junction each have the other in front of
		# them only until their noses cross. Testing "ahead" before recognising
		# the crossing used to let the second half of that manoeuvre overlap by
		# several pixels. The same stable priority applies on both sides of the
		# crossing: the lower instance id clears it, the other waits.
		if actor.get_instance_id() < other.get_instance_id():
			continue
		return false
	return true


func any_within(point: Vector2, radius: float) -> bool:
	## Is anything on this piece of road? Used by the gate barrier, which has
	## to lift for a hauler exactly as readily as for a city truck.
	for other in _live_vehicles():
		if other.global_position.distance_to(point) < radius:
			return true
	return false


func gate_clear(actor: Node2D, entry: Vector2, gap: float = GATE_GAP) -> bool:
	## The gate is a single point every hauler passes through, so it needs a
	## wider bubble than a moving column does.
	for other in _live_vehicles():
		if other != actor and other.global_position.distance_to(entry) < gap:
			return false
	return true


func clear() -> void:
	_vehicles.clear()
	_lanes.clear()
	_headings.clear()


func _live_vehicles() -> Array[Node2D]:
	var alive: Array[Node2D] = []
	var kept: Array = []
	for weak: WeakRef in _vehicles:
		var node := weak.get_ref() as Node2D
		if node != null and node.is_inside_tree():
			alive.append(node)
			kept.append(weak)
	_vehicles = kept
	return alive


func _lane_holder(lane_key: String) -> Node2D:
	var held: Variant = _lanes.get(lane_key)
	if not held is WeakRef:
		return null
	return (held as WeakRef).get_ref() as Node2D


func _index_of(actor: Node2D) -> int:
	for i in _vehicles.size():
		if (_vehicles[i] as WeakRef).get_ref() == actor:
			return i
	return -1
