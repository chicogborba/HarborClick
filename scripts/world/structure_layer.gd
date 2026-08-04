class_name StructureLayer
extends Node2D
## Places the visible copies of bought structures around the terminal.
##
## Counts are capped hard — the economy keeps counting every unit you buy, but
## a readable terminal beats a screen full of overlapping sprites.
##
## The caps were lowered once the crew became people with names and stations
## (`NpcCatalog`): four stevedores wandering the same lanes and three portainers
## on a one-hull berth read as scatter, not as a terminal. Two of each is enough
## for the yard to look staffed and few enough that the player can follow what any
## one of them is doing — which is the whole point of giving them a task at all.
const CAPS := {
	"estivador": 2, "empilhadeira": 2, "tt": 5, "reach_stacker": 2,
	"rtg": 3, "sts": 3, "armazem": 2, "rebocador": 2, "trem": 1,
	"flutuante": 1, "alfandega": 1, "torre": 1, "drone": 1,
	"porto_ia": 1, "portal": 1,
}
## The machines that carry a `CargoRelay` leg. Their caps are the highest here on
## purpose: every one of them is a box that gets driven across the terminal
## instead of crossing on its own, so the fleet size is something the player can
## *watch* grow rather than only read in a tooltip.
const RELAY_FLEET := ["tt", "reach_stacker", "empilhadeira"]

## Gantries and aircraft ride above the yard; everything else is y-sorted with
## the container stacks.
const OVERHEAD_TYPES := ["sts", "rtg", "drone"]

## Structures that occupy a building slot in the service band.
const SLOT_TYPES := ["armazem", "alfandega", "torre", "porto_ia", "portal"]

var world: PortWorld
var _actors: Dictionary = {}     # id -> Array[StructureActor]


func _ready() -> void:
	EventBus.structure_bought.connect(_on_structure_bought)
	EventBus.structure_purchase_committed.connect(_announce)


func _announce(quote: Dictionary) -> void:
	## Point at the machine that was just paid for.
	##
	## Every kind has a readable cap, so most purchases past the first few add
	## nothing to the yard — and a purchase that changes nothing on screen is the
	## whole of "I buy things and nothing happens". When the cap is already met
	## the badge goes over a machine of that kind that *is* there, and it shudders
	## on its springs, so the money always lands somewhere the player can see.
	var id := str(quote.get("id", ""))
	var gain := float(quote.get("nominal_cps_gain", 0.0))
	var fleet := live(id)
	if fleet.is_empty() or world == null or gain <= 0.0:
		return
	var actor: StructureActor = fleet[fleet.size() - 1]
	actor.acknowledge()
	world.show_world_badge(actor.position + Vector2(0.0, -14.0),
		"+%s TEU/s" % GameState.fmt(gain))


func rebuild() -> void:
	for id: String in _actors.keys():
		for actor in live(id):
			actor.queue_free()
	_actors.clear()
	for item in StructureDB.ITEMS:
		var count: int = GameState.structure_count(item.id)
		for i in mini(count, CAPS.get(item.id, 2)):
			_spawn(item.id, i, false)
	for id: String in _actors:
		_relayout(id)


func _on_structure_bought(id: String, count: int) -> void:
	var target := mini(count, CAPS.get(id, 2))
	var current := live(id).size()
	while current < target:
		_spawn(id, current, true)
		current += 1
	_relayout(id)


func _spawn(id: String, index: int, animate: bool) -> void:
	var actor := StructureActor.new()
	actor.setup(id, index, world)
	if not _actors.has(id):
		_actors[id] = []
	_actors[id].append(actor)
	if OVERHEAD_TYPES.has(id):
		world.overhead.add_child(actor)
	elif id in ["rebocador", "flutuante"]:
		world.add_child(actor)
		actor.z_index = 5
		actor.z_as_relative = false
	else:
		world.entities.add_child(actor)
	_place(actor, id, index)
	if animate:
		actor.pop_in()


func live(id: String) -> Array[StructureActor]:
	## The actors of one kind that still exist, pruning any that were freed under
	## us. A typed `for` over the raw array *throws* on a freed instance rather
	## than yielding something `is_instance_valid` can reject, so the check has to
	## happen before the assignment, not inside the loop body.
	var list: Array = _actors.get(id, [])
	var alive: Array[StructureActor] = []
	var stale := false
	for entry in list:
		# Validity first: `is` also throws on a freed instance, so the type check
		# cannot be the guard.
		if is_instance_valid(entry) and entry is StructureActor:
			alive.append(entry)
		else:
			stale = true
	if stale:
		_actors[id] = alive
	return alive


func claim_tractor(from: Vector2, to: Vector2) -> StructureActor:
	## The nearest idle machine that can carry a box, for one relay leg. Nearest
	## rather than first so a run does not summon a tractor from the far end of
	## the terminal while one is parked on the same lane.
	var best: StructureActor = null
	var best_distance := INF
	for id: String in RELAY_FLEET:
		for actor in live(id):
			if not actor.is_free_for_relay():
				continue
			var distance := actor.position.distance_squared_to(from)
			if distance < best_distance:
				best_distance = distance
				best = actor
	if best == null:
		return null
	return best if best.take_relay_haul(from, to) else null


func has_free_tractor() -> bool:
	## Whether the terminal can drive a box at all. Before the first machine is
	## bought there is nobody to hand a container to, and a relay would only make
	## every transfer wait for a chassis that does not exist.
	for id: String in RELAY_FLEET:
		for actor in live(id):
			if actor.is_free_for_relay():
				return true
	return false


func claim_lifter(kinds: Array, from: Vector2, to: Vector2,
		seconds: float) -> StructureActor:
	## The nearest gantry that can shadow a relay leg, preferring the first kind
	## listed. With no crane bought nothing claims it and the box makes the short
	## hand-off hop by itself.
	for kind in kinds:
		var best: StructureActor = null
		var best_distance := INF
		for actor in live(str(kind)):
			if not actor.is_free_for_relay():
				continue
			var distance := absf(actor.position.y - from.y)
			if distance < best_distance:
				best_distance = distance
				best = actor
		if best != null and best.mirror_relay(from, to, seconds):
			return best
	return null


func dispatch_berth_move(payload: Dictionary) -> bool:
	## Hand a real berth transfer to a quay crane that is free to animate it, so
	## the box in the air is visibly the box that crane just lifted.
	##
	## With several berths the *nearest* free crane takes it, or the box would fly
	## out from under a gantry two hundred pixels up the quay. With no portainer
	## bought, nothing claims it and the flight simply flies.
	var from: Vector2 = payload.get("from", Vector2.ZERO)
	var best: StructureActor = null
	var best_distance := INF
	for actor in live("sts"):
		if not actor.is_free_for_berth_move():
			continue
		var distance := absf(actor.global_position.y - from.y)
		if distance < best_distance:
			best_distance = distance
			best = actor
	return best.play_berth_move(payload) if best != null else false


func crew() -> Array[StructureActor]:
	## Every actor that is somebody, for hit-testing an inspection tap.
	var people: Array[StructureActor] = []
	for id: String in _actors.keys():
		for actor in live(id):
			if actor.is_crew():
				people.append(actor)
	return people


func _relayout(id: String) -> void:
	var list := live(id)
	for i in list.size():
		_place(list[i], id, i)


func _place(actor: StructureActor, id: String, index: int) -> void:
	var n: int = maxi(1, (_actors.get(id, []) as Array).size())
	match id:
		"sts":
			actor.position = Vector2(PortLayout.QUAY_X0 + 4.0,
				PortLayout.sts_y(index, maxi(n, 2)))
		"rtg":
			var block_index := _rtg_block_index(index)
			var block := PortLayout.block_origin(block_index)
			actor.set_block(block, block_index)
			actor.position = Vector2(block.x - 13.0, block.y - 8.0)
		"estivador":
			var lanes := PortLayout.lane_ys()
			var lane: float = lanes[index % lanes.size()]
			actor.set_lane(lane + 3.0)
			actor.position = Vector2(
				PortLayout.BLOCK_X0 + (index * 47) % 120, lane + 3.0)
		"tt":
			# The terminal tractor lives here. It has a numbered space on the rank
			# and stands in it whenever it is not under a box, because a machine
			# the player bought has to be a machine the player can point at.
			var rank := PortLayout.depot_slot(index)
			actor.set_depot(rank)
			if actor.is_idle_at_home():
				actor.position = rank
		"empilhadeira", "reach_stacker":
			# Road-plated machines come in for a job and leave again; their route
			# is decided per job and off-site is where they wait.
			if actor.is_idle_at_home():
				actor.position = PortLayout.gate_entry()
		"trem":
			actor.position = Vector2(-200.0, PortLayout.rail_y())
		"drone":
			var home := Vector2(70.0 + (index % 2) * 70.0,
				PortLayout.YARD_Y0 + 50.0 + index * 130.0)
			actor.set_meta("home", home)
			actor.position = home
		"rebocador":
			var lane_x := PortLayout.WATER_X0 + 30.0 + (index % 2) * 22.0
			actor.set_lane(0.0, true, lane_x)
			actor.position = Vector2(lane_x, _south_water(index, 90.0))
		"flutuante":
			var y := _south_water(index, 170.0)
			actor.set_lane(y, false, 0.0)
			actor.position = Vector2(PortLayout.WATER_X0 + 18.0, y)
		_:
			actor.position = PortLayout.slot_position(_slot_index(id, index))


func _south_water(index: int, spacing: float) -> float:
	## Keeps harbour craft clear of *every* berth so the ships stay readable.
	var berth_end := PortLayout.berth_y(PortLayout.berth_count() - 1) \
		+ PortLayout.SHIP_H + 30.0
	var span := maxf(120.0, PortLayout.world_bottom() - berth_end - 80.0)
	return berth_end + fmod(index * spacing, span)


func _rtg_block_index(index: int) -> int:
	var blocks := PortLayout.block_count()
	if blocks == 0:
		return 0
	@warning_ignore("integer_division")
	var stride: int = maxi(1, blocks / maxi(1, CAPS.get("rtg", 3)))
	return (index * stride) % blocks


func _slot_index(id: String, index: int) -> int:
	var cursor := 0
	for t: String in SLOT_TYPES:
		if t == id:
			return (cursor + index) % maxi(1, PortLayout.slot_count())
		cursor += mini((_actors.get(t, []) as Array).size(), CAPS.get(t, 2))
	return (cursor + index) % maxi(1, PortLayout.slot_count())
