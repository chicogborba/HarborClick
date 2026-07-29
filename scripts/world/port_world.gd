class_name PortWorld
extends Node2D
## Top-down terminal: yard on the left, quay and berth on the right.
##
## Draw order is handled by a single y-sorted `Entities` node so machines,
## people and container stacks never punch through each other. Anything that
## genuinely flies above the terminal (gantry booms, drones, boxes in transit)
## lives in `Overhead` instead.

var ship: Ship
var yard: ContainerYard
var structures: StructureLayer
var atmosphere: Atmosphere
var critters: Critters

var entities: Node2D          # y-sorted ground level
var overhead: Node2D          # gantries, drones, boxes in flight

var _ground: Sprite2D
var _water: ColorRect
var _decals: Node2D
var _pressed := false
var _drag_accum := 0.0


@onready var _containers: Texture2D = preload("res://assets/sprites/container_sheet.png")


func _ready() -> void:
	_build_water()
	_build_ground()

	_decals = Node2D.new()
	_decals.name = "Decals"
	_decals.z_index = -7
	_decals.z_as_relative = false
	add_child(_decals)

	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	entities.z_index = 0
	entities.z_as_relative = false
	add_child(entities)

	overhead = Node2D.new()
	overhead.name = "Overhead"
	overhead.z_index = 30
	overhead.z_as_relative = false
	add_child(overhead)

	yard = ContainerYard.new()
	yard.name = "Yard"
	yard.y_sort_enabled = true
	entities.add_child(yard)

	structures = StructureLayer.new()
	structures.world = self
	add_child(structures)

	_spawn_ship()
	_rebuild_decals()
	structures.rebuild()

	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	atmosphere.setup(self)

	critters = Critters.new()
	add_child(critters)
	critters.setup(self)

	EventBus.container_unloaded.connect(_on_container_unloaded)
	EventBus.land_bought.connect(_on_land_bought)


# ---------- construction ----------

func _build_ground() -> void:
	_ground = Sprite2D.new()
	_ground.name = "Ground"
	_ground.centered = false
	_ground.z_index = -8
	_ground.z_as_relative = false
	add_child(_ground)
	_rebake_ground()


func _rebake_ground() -> void:
	_ground.texture = GroundBaker.bake(int(PortLayout.world_bottom() + 90.0))


func _build_water() -> void:
	_water = ColorRect.new()
	_water.name = "Water"
	_water.position = Vector2(PortLayout.WATER_X0 - 12.0, 0)
	_water.size = Vector2(PortLayout.WORLD_W - PortLayout.WATER_X0 + 12.0,
		PortLayout.world_bottom() + 220.0)
	_water.z_index = -9
	_water.z_as_relative = false
	_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/water_top.gdshader")
	mat.set_shader_parameter("world_offset", _water.position)
	_water.material = mat
	add_child(_water)


func _spawn_ship() -> void:
	ship = Ship.new()
	ship.name = "Ship"
	ship.z_index = 8
	ship.z_as_relative = false
	add_child(ship)
	ship.departed.connect(_on_ship_departed)
	ship.arrive()


func _rebuild_decals() -> void:
	for child in _decals.get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 776655

	# bollards along the quay edge
	var y := PortLayout.TOP_MARGIN + 10.0
	while y < PortLayout.world_bottom():
		var b := Sprite2D.new()
		b.texture = preload("res://assets/sprites/prop_bollard.png")
		b.centered = false
		b.position = Vector2(PortLayout.WATER_X0 - 20.0, y)
		_decals.add_child(b)
		y += 46.0

	# puddles and oil marks on the pavement
	for i in 18:
		var p := Sprite2D.new()
		p.texture = preload("res://assets/sprites/prop_puddle.png")
		p.centered = false
		p.position = Vector2(rng.randf_range(16.0, PortLayout.QUAY_X1 - 20.0),
			rng.randf_range(PortLayout.TOP_MARGIN, PortLayout.world_bottom() - 40.0))
		_decals.add_child(p)

	# greenery on the verge, and cones dotted around the yard
	for i in int(PortLayout.world_bottom() / 76.0):
		var ty := 24.0 + i * 76.0 + rng.randf_range(-14.0, 14.0)
		var tree := Sprite2D.new()
		tree.texture = preload("res://assets/sprites/prop_tree.png")
		tree.centered = false
		tree.position = Vector2(-12.0 + rng.randf_range(0.0, 4.0), ty)
		entities.add_child(tree)
		if rng.randf() < 0.55:
			var bush := Sprite2D.new()
			bush.texture = preload("res://assets/sprites/prop_bush.png")
			bush.centered = false
			bush.position = Vector2(-4.0, ty + 34.0)
			entities.add_child(bush)
	for i in 7:
		var c := Sprite2D.new()
		c.texture = preload("res://assets/sprites/prop_cone.png")
		c.centered = false
		c.position = Vector2(rng.randf_range(PortLayout.GATE_ROAD_X, PortLayout.QUAY_X1 - 16.0),
			rng.randf_range(PortLayout.YARD_Y0, PortLayout.world_bottom() - 70.0))
		entities.add_child(c)


# ---------- land ----------

func _on_land_bought(_id: String) -> void:
	yard.resize()
	_rebake_ground()
	_water.size.y = PortLayout.world_bottom() + 220.0
	_rebuild_decals()
	structures.rebuild()
	atmosphere.rebuild_lamps()
	for i in 6:
		spawn_dust(Vector2(randf_range(40.0, 180.0),
			PortLayout.yard_bottom() - randf_range(10.0, 80.0)))


func visible_bottom() -> float:
	return PortLayout.world_bottom()


# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_pressed = true
			_drag_accum = 0.0
		else:
			if _pressed and _drag_accum < 10.0:
				_try_tap(_to_world(event.position))
			_pressed = false
	elif event is InputEventScreenDrag and _pressed:
		_drag_accum += event.relative.length()


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _try_tap(world_pos: Vector2) -> void:
	if ship != null and ship.is_working() and ship.hit_test(world_pos):
		GameState.do_click(world_pos)
		AudioManager.play_sfx("click", 0.12)
	elif critters != null and critters.tap_cat(world_pos):
		AudioManager.play_sfx("meow", 0.10)


# ---------- cargo flow ----------

func _on_container_unloaded(_world_pos: Vector2, value: float, crit: bool) -> void:
	if ship == null or not ship.is_working():
		return
	if ship.is_discharging():
		_move_ship_to_yard(value, crit)
	else:
		_move_yard_to_ship(value, crit)


func _move_ship_to_yard(value: float, crit: bool) -> void:
	var take := ship.take_container()
	if take.is_empty():
		return
	var landing := yard.pick_landing_slot()
	_fly(take.color, take.pos, landing.pos, func() -> void:
		yard.place(landing.slot, landing.level, take.color)
		spawn_dust(landing.pos + Vector2(4, 4)))
	_spawn_float_text(take.pos + Vector2(4, -8), value, crit)
	ship.nudge()


func _move_yard_to_ship(value: float, crit: bool) -> void:
	var bay := ship.reserve_bay()
	if bay.is_empty():
		# stow is complete (or the ship is full) — she sails
		ship.depart()
		return
	var box := yard.take_top()
	if box.is_empty():
		# nothing left to export — let her sail
		EventBus.toast.emit("Pátio vazio. O navio zarpou com o que tinha.")
		ship.depart()
		return
	var color: int = randi() % 8
	_fly(color, box.pos, bay.pos, func() -> void:
		ship.place_container(bay.col, bay.row, color))
	_spawn_float_text(box.pos + Vector2(4, -8), value, crit)
	ship.nudge()


func _fly(color: int, from: Vector2, to: Vector2, on_land: Callable) -> void:
	var fly := FlyingContainer.new()
	fly.setup(_containers, color, from, to)
	fly.landed.connect(on_land)
	overhead.add_child(fly)


func spawn_dust(pos: Vector2) -> void:
	var puff := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 14.0)
	frames.set_animation_loop(&"default", false)
	var tex: Texture2D = preload("res://assets/sprites/prop_dust.png")
	for i in 4:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 16, 0, 16, 12)
		frames.add_frame(&"default", at)
	puff.sprite_frames = frames
	puff.centered = false
	puff.position = pos - Vector2(2, 2)
	puff.animation_finished.connect(puff.queue_free)
	overhead.add_child(puff)
	puff.play()


func _spawn_float_text(pos: Vector2, value: float, crit: bool) -> void:
	var ft := FloatText.new()
	ft.setup("+" + GameState.fmt(value), pos, crit)
	overhead.add_child(ft)


func _on_ship_departed() -> void:
	EventBus.ship_departed.emit()
	await get_tree().create_timer(3.0).timeout
	ship.arrive()


# ---------- yard traffic dispatch ----------

func target_fill() -> float:
	## How full the yard "should" look for the current throughput. Growing
	## income means a busier terminal, which is the whole visual payoff.
	var cps := maxf(1.0, GameState.cps)
	return clampf(0.08 + log(cps) / log(10.0) / 11.0, 0.08, 0.95)


func request_job() -> Dictionary:
	## Machines ask for work here. Returns a pickup (box leaves by gate) or a
	## delivery (box arrives from the city), whichever the yard needs.
	var fill := yard.fill_ratio()
	var target := target_fill()
	if fill > target + 0.04:
		var slot := yard.fullest_slot()
		if slot >= 0:
			return {"type": "pickup", "slot": slot,
				"pos": yard.slot_position(slot)}
	elif fill < target - 0.04:
		var landing := yard.pick_landing_slot()
		return {"type": "deliver", "slot": landing.slot, "level": landing.level,
			"pos": landing.pos, "color": randi() % 8}
	return {}


func complete_pickup(slot: int) -> Dictionary:
	return yard.take_top(slot)


func complete_delivery(slot: int, level: int, color: int) -> void:
	yard.place(slot, level, color)
	spawn_dust(yard.level_position(slot, level) + Vector2(4, 4))
