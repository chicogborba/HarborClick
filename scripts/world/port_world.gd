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
var skyscape: Skyscape
var critters: Critters
var berth: BerthCallController
var gate: GateDock
var traffic: TrafficCoordinator
var _gate_view: Node2D

var entities: Node2D          # y-sorted ground level
var overhead: Node2D          # gantries, drones, boxes in flight

var _ground: Sprite2D
var _water: ColorRect
var _water_foam: WaterFoam
var _water_quality: WaterQuality.Level = WaterQuality.Level.MEDIUM
var _decals: Node2D
var _marks: Node2D
var _props: Node2D
var _pressed := false
var _drag_accum := 0.0
var _traffic_in_transit: Dictionary = {} # token -> taken IMPORT record


@onready var _containers: Texture2D = preload("res://assets/sprites/container_sheet.png")


func _ready() -> void:
	_build_water()
	_build_ground()

	_decals = Node2D.new()
	_decals.name = "Decals"
	_decals.z_index = -7
	_decals.z_as_relative = false
	add_child(_decals)
	# Channel marks stand off the starboard side of the fairway and draw *over*
	# the hull, so a ship passes behind them the way it passes a real mark.
	# Underneath, they were simply run over.
	_marks = Node2D.new()
	_marks.name = "ChannelMarks"
	_marks.z_index = 9
	_marks.z_as_relative = false
	add_child(_marks)
	_props = Node2D.new()
	_props.name = "Props"
	_props.z_index = -1
	add_child(_props)

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

	skyscape = Skyscape.new()
	skyscape.name = "Skyscape"
	add_child(skyscape)
	skyscape.setup(self)

	critters = Critters.new()
	add_child(critters)
	critters.setup(self)

	EventBus.land_bought.connect(_on_land_bought)
	EventBus.prestiged.connect(_on_prestiged)


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
	mat.set_shader_parameter("shore_x", PortLayout.WATER_X0)
	_water.material = mat
	add_child(_water)
	_water_quality = WaterQuality.choose(get_viewport().get_visible_rect().size)
	mat.set_shader_parameter("quality_level", int(_water_quality))
	_water_foam = WaterFoam.new()
	_water_foam.name = "WaterFoam"
	_water_foam.z_index = -7
	_water_foam.z_as_relative = false
	add_child(_water_foam)
	_water_foam.setup(_water_quality, PortLayout.world_bottom())


func _spawn_ship() -> void:
	ship = Ship.new()
	ship.name = "Ship"
	ship.z_index = 8
	ship.z_as_relative = false
	add_child(ship)
	ship.departed.connect(_on_ship_departed)
	berth = BerthCallController.new()
	berth.setup(self, ship, yard)
	# Named sections coexist with Main's legacy compact-yard handoff.  The
	# manifest section keeps every outbound UID, while ContainerYard ignores the
	# old flattened restore once this richer section has been applied.
	SaveManager.register_section(&"cargo_yard", yard.snapshot, yard.restore)
	SaveManager.register_section(&"berth_call", berth.snapshot, berth.restore, berth.seed_new)
	traffic = TrafficCoordinator.new()
	SaveManager.register_section(
		&"traffic_cargo", _traffic_snapshot, _traffic_restore, _traffic_seed)
	gate = GateDock.new()
	gate.setup(self, yard)
	gate.changed.connect(_rebuild_gate_view)
	gate.notice_requested.connect(
		func(notice: Dictionary) -> void:
			EventBus.notification_requested.emit({
				"id": "gate_%s" % notice.get("code", "notice"),
				"kind": &"blocked", "priority": 1,
				"text": notice.get("text", "")}))
	SaveManager.register_section(
		&"gate_dock", gate.snapshot, gate.restore, gate.seed_new)
	if ship.phase == Ship.Phase.AWAY:
		berth.arrive()


func _rebuild_decals() -> void:
	for child in _decals.get_children():
		child.queue_free()
	for child in _marks.get_children():
		child.queue_free()
	_build_channel_marks()
	for child in _props.get_children():
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
		_props.add_child(tree)
		if rng.randf() < 0.55:
			var bush := Sprite2D.new()
			bush.texture = preload("res://assets/sprites/prop_bush.png")
			bush.centered = false
			bush.position = Vector2(-4.0, ty + 34.0)
			_props.add_child(bush)
	for i in 7:
		var c := Sprite2D.new()
		c.texture = preload("res://assets/sprites/prop_cone.png")
		c.centered = false
		c.position = Vector2(rng.randf_range(PortLayout.GATE_ROAD_X, PortLayout.QUAY_X1 - 16.0),
			rng.randf_range(PortLayout.YARD_Y0, PortLayout.world_bottom() - 70.0))
		_props.add_child(c)


func _build_channel_marks() -> void:
	## A line of port-hand marks down the edge of the fairway, from the open
	## water south of the berth to the exit past the top of the quay.
	var sheet: Texture2D = preload("res://assets/sprites/prop_buoy.png")
	var lane_x := PortLayout.WORLD_W - 9.0
	var y := PortLayout.TOP_MARGIN - 10.0
	var index := 0
	while y < PortLayout.world_bottom() + 60.0:
		var buoy := Sprite2D.new()
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2((index % 2) * 12, 0, 12, 14)
		buoy.texture = frame
		buoy.centered = true
		buoy.position = Vector2(lane_x, y)
		_marks.add_child(buoy)
		y += 104.0
		index += 1


# ---------- land ----------

func _on_land_bought(_id: String) -> void:
	yard.resize()
	_rebake_ground()
	_water.size.y = PortLayout.world_bottom() + 220.0
	if _water_foam != null:
		_water_foam.rebuild(PortLayout.world_bottom())
	_rebuild_decals()
	structures.rebuild()
	atmosphere.rebuild_lamps()
	if skyscape != null:
		skyscape.rebuild()
	for i in 6:
		spawn_dust(Vector2(randf_range(40.0, 180.0),
			PortLayout.yard_bottom() - randf_range(10.0, 80.0)))


func _on_prestiged(_shares: int) -> void:
	## Visual state is rebuilt from economic state, avoiding stale actors and
	## duplicate props after a prestige reset.
	yard.resize()
	_rebake_ground()
	_water.size.y = PortLayout.world_bottom() + 220.0
	if _water_foam != null:
		_water_foam.rebuild(PortLayout.world_bottom())
	if structures != null:
		structures.rebuild()
	_rebuild_decals()
	structures.rebuild()
	atmosphere.rebuild_lamps()
	if skyscape != null:
		skyscape.rebuild()


func visible_bottom() -> float:
	return PortLayout.world_bottom()


func set_input_enabled(input_allowed: bool) -> void:
	if berth != null:
		berth.set_input_enabled(input_allowed)


func apply_view_metrics(metrics: Dictionary) -> void:
	_apply_water_quality(metrics)
	if berth != null:
		berth.apply_view_metrics(metrics)


func _apply_water_quality(metrics: Dictionary) -> void:
	var level := WaterQuality.from_metrics(metrics, get_viewport().get_visible_rect().size)
	if level == _water_quality:
		return
	_water_quality = level
	if _water != null and _water.material is ShaderMaterial:
		(_water.material as ShaderMaterial).set_shader_parameter("quality_level", int(level))
	if _water_foam != null:
		_water_foam.set_quality(level)


func _process(delta: float) -> void:
	_feed_water_shader()
	if berth != null:
		berth.tick(delta)
	if gate != null:
		gate.tick(delta)


func _rebuild_gate_view() -> void:
	## One sprite per parked truck, plus the boxes still on its bed, so the
	## player can see at a glance which way this one is running.
	if _gate_view == null:
		_gate_view = Node2D.new()
		_gate_view.name = "GateDock"
		entities.add_child(_gate_view)
	for child in _gate_view.get_children():
		child.queue_free()
	if gate == null:
		return
	for bay: int in gate.bays.keys():
		var truck: Dictionary = gate.bays[bay]
		var root := Node2D.new()
		root.position = PortLayout.gate_bay_position(bay)
		_gate_view.add_child(root)
		var body := Sprite2D.new()
		body.texture = preload("res://assets/sprites/veh_tt.png")
		body.centered = false
		body.scale = Vector2(0.7, 0.7)
		root.add_child(body)
		var carried: Array = truck.cargo
		for index in carried.size():
			var box := Sprite2D.new()
			var atlas := AtlasTexture.new()
			atlas.atlas = _containers
			atlas.region = Rect2(
				posmod((carried[index] as CargoUnit).color, 8) * 24, 0, 24, 13)
			box.texture = atlas
			box.centered = false
			box.scale = Vector2(0.62, 0.62)
			box.position = Vector2(-1, 12.0 + index * 8.0)
			root.add_child(box)


func _feed_water_shader() -> void:
	if _water == null or ship == null or not (_water.material is ShaderMaterial):
		return
	var mat := _water.material as ShaderMaterial
	var strength := ship.wake_strength() if ship.visible else 0.0
	mat.set_shader_parameter("ship_speed", strength)
	if strength > 0.0:
		# Shader space is world space offset by the water rect's own origin.
		mat.set_shader_parameter("ship_centre",
			ship.hull_centre() - _water.position)
		mat.set_shader_parameter("ship_half",
			Vector2(PortLayout.SHIP_W, PortLayout.SHIP_H) * 0.5)


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
		if berth != null and berth.handle_tap(world_pos):
			AudioManager.play_sfx("click", 0.12)
	elif critters != null and critters.tap_cat(world_pos):
		AudioManager.play_sfx("meow", 0.10)
	elif gate != null and gate.handle_tap(world_pos):
		AudioManager.play_sfx("click", 0.12)
	elif atmosphere != null and atmosphere.tap_lamp(world_pos):
		pass


# ---------- cargo flow ----------

func _on_container_unloaded(_world_pos: Vector2, _value: float, _crit: bool) -> void:
	## Legacy compatibility only; the berth controller now owns cargo/reward
	## ordering and calls this flow directly from input.
	if berth != null:
		berth.handle_tap(_world_pos)


func _move_ship_to_yard(_value: float, _crit: bool) -> void:
	if berth != null:
		berth.handle_tap(ship.global_position)


func _move_yard_to_ship(_value: float, _crit: bool) -> void:
	if berth != null:
		berth.handle_tap(ship.global_position)


func fly_cargo(color: int, from: Vector2, to: Vector2) -> FlyingContainer:
	var fly := FlyingContainer.new()
	fly.setup(_containers, color, from, to)
	overhead.add_child(fly)
	return fly


func _fly(color: int, from: Vector2, to: Vector2, on_land: Callable) -> void:
	var fly := fly_cargo(color, from, to)
	fly.landed.connect(on_land)


func show_cargo_reward(pos: Vector2, value: float, crit: bool) -> void:
	## Reward accounting happens in BerthCallController before this presentation
	## hook. Hiding feedback must therefore never suppress an earned reward.
	if not UserPreferences.floating_numbers:
		return
	_spawn_float_text(pos + Vector2(4, -8), value, crit)


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
	if berth != null:
		berth.seed_new()
		berth.arrive()


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
	if fill > target + 0.04 and yard.has_sector(CargoUnit.IMPORT):
		var slot := yard.fullest_slot(CargoUnit.IMPORT)
		if slot >= 0:
			return {"type": "pickup", "slot": slot,
				"pos": yard.slot_position(slot)}
	elif fill < target - 0.04:
		var landing := yard.pick_landing_slot(CargoUnit.EXPORT)
		if landing.is_empty():
			return {}
		return {"type": "deliver", "slot": landing.slot, "level": landing.level,
			"pos": landing.pos, "color": randi() % 8, "token": landing.token}
	return {}


func complete_pickup(slot: int) -> Dictionary:
	return yard.take_import(slot)


func begin_hauler_pickup(slot: int) -> Dictionary:
	## The box leaves the rendered stack now, but remains in a persisted transit
	## ledger until the vehicle clears the gate.
	var taken := yard.take_import(slot)
	if taken.is_empty():
		return {}
	var return_token := yard.reserve_taken_return(taken)
	if return_token.is_empty():
		yard.restore_taken(taken)
		return {}
	var token := CargoUnit.new_uid("haul")
	taken["traffic_token"] = token
	taken["return_token"] = return_token
	_traffic_in_transit[token] = taken
	return taken


func complete_delivery(slot: int, level: int, color: int, token: String = "") -> bool:
	var unit := CargoUnit.new("", CargoUnit.EXPORT, color)
	var placed := yard.place_unit(slot, level, unit, token)
	if placed:
		spawn_dust(yard.level_position(slot, level) + Vector2(4, 4))
	else:
		yard.release_landing(token)
	return placed


func cancel_job(job: Dictionary) -> void:
	## A delivery reserves physical yard capacity before the vehicle starts.
	## A pickup already lifted by a vehicle remains port property until that
	## vehicle exits the gate. Rebuild/prestige must return either resource.
	if job.get("type", "") == "deliver":
		yard.release_landing(str(job.get("token", "")))
	elif job.get("type", "") == "pickup":
		var job_taken: Dictionary = job.get("taken", {})
		var token := str(job.get("traffic_token",
			job_taken.get("traffic_token", "")))
		var taken: Variant = _traffic_in_transit.get(
			token, job_taken)
		if taken is Dictionary and not taken.is_empty():
			var restored := yard.restore_reserved_taken(
				taken, str(taken.get("return_token", "")))
			if not restored:
				yard.release_landing(str(taken.get("return_token", "")))
				restored = yard.restore_taken(taken)
			if restored:
				_traffic_in_transit.erase(token)


func commit_job(job: Dictionary) -> void:
	if job.get("type", "") != "pickup":
		return
	var taken: Dictionary = job.get("taken", {})
	var token := str(job.get(
		"traffic_token", taken.get("traffic_token", "")))
	var tracked: Dictionary = _traffic_in_transit.get(token, taken)
	yard.release_landing(str(tracked.get("return_token", "")))
	_traffic_in_transit.erase(token)
	SaveManager.request_save(&"traffic_pickup_committed")


func _traffic_snapshot() -> Dictionary:
	var records: Array = []
	for taken: Dictionary in _traffic_in_transit.values():
		var record := taken.duplicate(true)
		if record.get("unit") is CargoUnit:
			record["unit"] = (record.unit as CargoUnit).snapshot()
		records.append(record)
	return {"in_transit": records}


func _traffic_restore(data: Dictionary) -> void:
	for taken: Dictionary in _traffic_in_transit.values():
		yard.release_landing(str(taken.get("return_token", "")))
	_traffic_in_transit.clear()
	if traffic != null:
		traffic.clear()
	for raw in data.get("in_transit", []):
		if not raw is Dictionary:
			continue
		var taken: Dictionary = raw.duplicate(true)
		if taken.get("unit") is Dictionary:
			taken["unit"] = CargoUnit.from_snapshot(taken.unit)
		var old_token := str(taken.get("traffic_token", ""))
		var return_token := yard.reserve_taken_return(taken)
		taken["return_token"] = return_token
		var restored := not return_token.is_empty() \
			and yard.restore_reserved_taken(taken, return_token)
		if not restored:
			yard.release_landing(return_token)
			restored = yard.restore_taken(taken)
		if not restored:
			# Keep ownership in the persisted ledger rather than silently
			# discarding a UID from a malformed/full restored yard.
			_traffic_in_transit[old_token] = taken


func _traffic_seed() -> void:
	for taken: Dictionary in _traffic_in_transit.values():
		yard.release_landing(str(taken.get("return_token", "")))
	_traffic_in_transit.clear()
	if traffic != null:
		traffic.clear()
