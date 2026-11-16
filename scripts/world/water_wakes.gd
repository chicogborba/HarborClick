class_name WaterWakes
extends RefCounted
## The water's memory of everything that has crossed it.
##
## A wake drawn relative to the hull — the old analytic V — vanishes the instant
## the hull stops or turns, and it trails *behind the sprite* rather than lying on
## the sea: a ship easing into its berth dragged a perfect V up to the quay with
## it and then switched it off. Real water keeps the track. So each moving hull
## or boat drops a sample where its stern is every few pixels, the samples age,
## and the shader draws the band between consecutive samples: aerated water
## inside, a bright seam at each edge, widening and fading with age. Straight
## travel gives the classic V on its own; a turn bends it; a stop leaves the
## track behind to dissolve.
##
## Pure data. `PortWorld` feeds emitters and hands `pack()` to
## `water_top.gdshader`; nothing here touches a node.

## Must match `MAX_TRAIL` in water_top.gdshader.
const MAX_POINTS := 40
## Seconds a sample stays on the water.
const LIFE := 9.0
## A jump longer than this between two feeds is a teleport (a hull respawned
## off-map, a boat re-laid after a purchase), not travel: it starts a new chain
## instead of drawing a wake across the harbour.
const TELEPORT := 48.0

## emitter id -> {"points": Array[Vector4] (x, y, age, half), "head": Vector4,
## "step": float, "life": float, "fresh": bool}
var _chains: Dictionary = {}


func feed(id: StringName, stern: Vector2, half_width: float, strength: float,
		step: float = 18.0, life: float = LIFE) -> void:
	## Called every frame an emitter is making way. `strength` 0..1 is folded
	## into the age the shader sees, so a slow hull leaves a weaker track
	## without needing a fifth component per sample.
	var chain: Dictionary = _chains.get(id, {})
	if chain.is_empty():
		chain = {"points": [], "step": step, "life": life}
		_chains[id] = chain
	chain.step = step
	chain.life = life
	var points: Array = chain.points
	var bias := (1.0 - clampf(strength, 0.0, 1.0)) * life * 0.55
	var head := Vector4(stern.x, stern.y, bias, half_width)
	if not points.is_empty():
		var last: Vector4 = points[points.size() - 1]
		var gap := Vector2(last.x, last.y).distance_to(stern)
		if gap > TELEPORT:
			# Leave the old track to fade where it is; start fresh here.
			_retire(id, chain)
			chain = {"points": [], "step": step, "life": life}
			_chains[id] = chain
			points = chain.points
		elif gap < step:
			chain.head = head
			chain.fresh = true
			return
	points.append(head)
	chain.head = head
	chain.fresh = true


func tick(delta: float) -> void:
	## Ages every sample and forgets the dead. An emitter that was not fed since
	## the last tick has stopped: its head is no longer drawn, but its track stays.
	for id: StringName in _chains.keys():
		var chain: Dictionary = _chains[id]
		var life: float = chain.life
		var alive: Array = []
		for point: Vector4 in chain.points:
			point.z += delta
			if point.z < life:
				alive.append(point)
		chain.points = alive
		if not chain.get("fresh", false):
			chain.erase("head")
		chain.fresh = false
		if alive.is_empty() and not chain.has("head"):
			_chains.erase(id)


func clear() -> void:
	_chains.clear()


func point_count() -> int:
	var total := 0
	for chain: Dictionary in _chains.values():
		total += chain.points.size() + (1 if chain.has("head") else 0)
	return total


func chain_count() -> int:
	return _chains.size()


func pack(origin: Vector2, limit: int = MAX_POINTS) -> PackedVector4Array:
	## Oldest to newest per chain, the live head last. `w` is the half-width,
	## negated on the first sample of a chain so the shader never joins two
	## different emitters with a segment. `z` is the age in seconds already
	## scaled to `LIFE`, so chains with their own lifetime share one shader
	## constant.
	var out := PackedVector4Array()
	# Newest chains first when the budget runs out: the track a player just
	# watched being laid matters more than the tail of an old one.
	for id: StringName in _chains.keys():
		var chain: Dictionary = _chains[id]
		var scale: float = LIFE / maxf(float(chain.life), 0.01)
		var points: Array = chain.points.duplicate()
		if chain.has("head"):
			var head: Vector4 = chain.head
			var last: Vector4 = points[points.size() - 1] if not points.is_empty() \
				else Vector4(-1.0e9, 0.0, 0.0, 0.0)
			if Vector2(last.x, last.y).distance_to(Vector2(head.x, head.y)) > 0.5:
				points.append(head)
		if points.size() < 2:
			continue
		var room := limit - out.size()
		if room < 2:
			break
		var start := maxi(0, points.size() - room)
		for index in range(start, points.size()):
			var point: Vector4 = points[index]
			var half := point.w if index > start else -maxf(point.w, 0.01)
			out.append(Vector4(point.x - origin.x, point.y - origin.y,
				point.z * scale, half))
	return out


func _retire(id: StringName, chain: Dictionary) -> void:
	## Moves a finished track under its own key so it keeps fading.
	var ghost_id := StringName("%s~%d" % [id, Time.get_ticks_usec()])
	chain.erase("head")
	chain.fresh = false
	_chains[ghost_id] = chain
