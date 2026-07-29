class_name TrafficCoordinator
extends RefCounted
## Keeps vehicles on a lane separated.  It is intentionally independent from
## rendering so it remains valid when the yard is rebuilt or restored.

const MIN_DISTANCE := 22.0
var _lanes: Dictionary = {} # lane key -> actor instance ids


func can_enter(actor: Node2D, lane_key: String, pos: Vector2,
		minimum: float = MIN_DISTANCE) -> bool:
	if actor == null:
		return false
	for other: WeakRef in _lanes.get(lane_key, []):
		var node := other.get_ref() as Node2D
		if node != null and node != actor and node.global_position.distance_to(pos) < minimum:
			return false
	return true


func reserve(actor: Node2D, lane_key: String) -> void:
	release(actor)
	if not _lanes.has(lane_key):
		_lanes[lane_key] = []
	_lanes[lane_key].append(weakref(actor))


func release(actor: Node2D) -> void:
	for lane: String in _lanes.keys():
		var kept: Array = []
		for ref: WeakRef in _lanes[lane]:
			var node := ref.get_ref() as Node2D
			if node != null and node != actor:
				kept.append(ref)
		_lanes[lane] = kept


func clear() -> void:
	_lanes.clear()
