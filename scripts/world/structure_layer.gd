class_name StructureLayer
extends Node2D
## Places the visible copies of bought structures around the terminal.
##
## Counts are capped hard — the economy keeps counting every unit you buy, but
## a readable terminal beats a screen full of overlapping sprites.

const CAPS := {
	"estivador": 4, "empilhadeira": 2, "tt": 3, "reach_stacker": 2,
	"rtg": 3, "sts": 3, "armazem": 2, "rebocador": 2, "trem": 1,
	"flutuante": 1, "alfandega": 1, "torre": 1, "drone": 2,
	"porto_ia": 1, "portal": 1,
}

## Gantries and aircraft ride above the yard; everything else is y-sorted with
## the container stacks.
const OVERHEAD_TYPES := ["sts", "rtg", "drone"]

## Structures that occupy a building slot in the service band.
const SLOT_TYPES := ["armazem", "alfandega", "torre", "porto_ia", "portal"]

var world: PortWorld
var _actors: Dictionary = {}     # id -> Array[StructureActor]


func _ready() -> void:
	EventBus.structure_bought.connect(_on_structure_bought)


func rebuild() -> void:
	for list: Array in _actors.values():
		for a: StructureActor in list:
			a.queue_free()
	_actors.clear()
	for item in StructureDB.ITEMS:
		var count: int = GameState.structure_count(item.id)
		for i in mini(count, CAPS.get(item.id, 2)):
			_spawn(item.id, i, false)
	for id: String in _actors:
		_relayout(id)


func _on_structure_bought(id: String, count: int) -> void:
	if count <= CAPS.get(id, 2):
		_spawn(id, count - 1, true)
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


func _relayout(id: String) -> void:
	var list: Array = _actors.get(id, [])
	for i in list.size():
		_place(list[i], id, i)


func _place(actor: StructureActor, id: String, index: int) -> void:
	var n: int = maxi(1, (_actors.get(id, []) as Array).size())
	match id:
		"sts":
			actor.position = Vector2(PortLayout.QUAY_X0 + 4.0,
				PortLayout.sts_y(index, maxi(n, 2)))
		"rtg":
			var block := _rtg_block(index)
			actor.set_block(block)
			actor.position = Vector2(block.x - 13.0, block.y - 8.0)
		"estivador":
			var lanes := PortLayout.lane_ys()
			var lane: float = lanes[index % lanes.size()]
			actor.set_lane(lane + 3.0)
			actor.position = Vector2(
				PortLayout.BLOCK_X0 + (index * 47) % 120, lane + 3.0)
		"tt", "empilhadeira", "reach_stacker":
			# haulers park off-site; their route is decided per job
			actor.position = Vector2(PortLayout.GATE_ROAD_X,
				PortLayout.TOP_MARGIN - 30.0)
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
	## Keeps harbour craft clear of the berth so the ship stays readable.
	var berth_end := PortLayout.SHIP_Y + PortLayout.SHIP_H + 30.0
	var span := maxf(120.0, PortLayout.world_bottom() - berth_end - 80.0)
	return berth_end + fmod(index * spacing, span)


func _rtg_block(index: int) -> Vector2:
	var blocks := PortLayout.block_count()
	if blocks == 0:
		return PortLayout.block_origin(0)
	@warning_ignore("integer_division")
	var stride: int = maxi(1, blocks / maxi(1, CAPS.get("rtg", 3)))
	return PortLayout.block_origin((index * stride) % blocks)


func _slot_index(id: String, index: int) -> int:
	var cursor := 0
	for t: String in SLOT_TYPES:
		if t == id:
			return (cursor + index) % maxi(1, PortLayout.slot_count())
		cursor += mini((_actors.get(t, []) as Array).size(), CAPS.get(t, 2))
	return (cursor + index) % maxi(1, PortLayout.slot_count())
