class_name StructureActor
extends Node2D
## One visible instance of a bought structure.
##
## Haulers (reach stacker, empty handler, terminal tractor) actually work:
## they come in through the gate, run down the service road, reach into a
## block from the driving lane, and carry the box back out of the terminal.
## Gantries and buildings animate in place.

const CONTAINERS := preload("res://assets/sprites/container_sheet.png")
const HAULERS := ["tt", "empilhadeira", "reach_stacker"]

enum Job { IDLE, ENTERING, TO_TARGET, WORKING, TO_ROAD, LEAVING }

var id: String = ""
var index := 0

var _sprite: Node2D
var _extra: Node2D            # trolley / radar / barrier arm
var _spreader: Sprite2D
var _cargo: Sprite2D
var _shadow: Sprite2D
var _walk: AnimatedSprite2D

var _t := 0.0
var _phase := 0.0
var _dir := 1.0
var _lane_y := 0.0
var _lane_x := 0.0
var _vertical := false
var _block_origin := Vector2.ZERO
var _speed := 26.0

# hauler job state
var _job: Job = Job.IDLE
var _job_data: Dictionary = {}
var _waypoints: Array[Vector2] = []
var _cooldown := 0.0
var _work_timer := 0.0
var _carrying := false
var _world: PortWorld


func setup(structure_id: String, actor_index: int, world: PortWorld) -> void:
	id = structure_id
	index = actor_index
	_world = world
	_phase = randf() * TAU
	_dir = 1.0 if actor_index % 2 == 0 else -1.0
	_cooldown = randf_range(0.5, 5.0)
	_build()


func is_hauler() -> bool:
	return HAULERS.has(id)


func _exit_tree() -> void:
	if _world == null:
		return
	if not _job_data.is_empty():
		_world.cancel_job(_job_data)
		_job_data = {}
	if _world.traffic != null:
		_world.traffic.release(self)


# ---------------------------------------------------------------- building

func _build() -> void:
	match id:
		"estivador":
			_build_worker()
		"empilhadeira":
			_build_vehicle("veh_forklift", 34.0)
		"tt":
			_build_vehicle("veh_tt", 46.0)
		"reach_stacker":
			_build_vehicle("veh_reach_stacker", 30.0)
		"rtg":
			_build_rtg()
		"sts":
			_build_sts()
		"rebocador":
			_build_boat("veh_tug", 16.0)
		"trem":
			_build_train()
		"flutuante":
			_build_static("flutuante")
		"drone":
			_build_drone()
		"armazem":
			_build_static("bld_warehouse")
		"alfandega":
			_build_customs()
		"torre":
			_build_tower()
		"porto_ia":
			_build_static("bld_ai_hub")
		"portal":
			_build_portal()
		_:
			_build_static("bld_office")


func _sprite2d(sprite_name: String, centered: bool = false) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/sprites/%s.png" % sprite_name)
	spr.centered = centered
	return spr


func _anim(sheet_name: String, count: int, fw: int, fh: int, fps: float,
		centered: bool = false) -> AnimatedSprite2D:
	var spr := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	var tex: Texture2D = load("res://assets/sprites/%s.png" % sheet_name)
	frames.set_animation_speed(&"default", fps)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		frames.add_frame(&"default", at)
	spr.sprite_frames = frames
	spr.centered = centered
	spr.frame = randi() % count
	spr.play()
	return spr


func _add_shadow(w: float, h: float, offset := Vector2.ZERO) -> void:
	_shadow = _sprite2d("prop_shadow")
	_shadow.centered = true
	_shadow.scale = Vector2(w / 32.0, h / 20.0)
	_shadow.modulate.a = 0.4
	_shadow.position = offset
	_shadow.z_index = -1
	add_child(_shadow)


func _build_static(sprite_name: String) -> void:
	var tex: Texture2D = load("res://assets/sprites/%s.png" % sprite_name)
	_add_shadow(tex.get_width() + 4, 12.0,
		Vector2(tex.get_width() / 2.0, tex.get_height() - 2.0))
	_sprite = _sprite2d(sprite_name)
	add_child(_sprite)


func _build_worker() -> void:
	_walk = _anim("worker_sheet", 12, 9, 12, 7.0)
	_sprite = _walk
	add_child(_walk)
	_speed = randf_range(11.0, 17.0)


func _build_vehicle(sprite_name: String, speed: float) -> void:
	_add_shadow(15.0, 9.0, Vector2(0, 6))
	_sprite = _sprite2d(sprite_name, true)
	_sprite.scale = Vector2(0.70, 0.70)
	add_child(_sprite)
	_speed = speed
	_cargo = _container_sprite()
	_cargo.centered = true
	_cargo.scale = Vector2(0.70, 0.70)
	_cargo.visible = false
	add_child(_cargo)
	visible = false          # haulers stay off-site until they get a job


func _build_boat(sprite_name: String, speed: float) -> void:
	_sprite = _sprite2d(sprite_name, true)
	_sprite.scale = Vector2(0.70, 0.70)
	add_child(_sprite)
	_speed = speed
	_vertical = true


func _build_rtg() -> void:
	_sprite = _sprite2d("rtg")
	add_child(_sprite)
	_extra = _sprite2d("rtg_trolley")
	add_child(_extra)
	_spreader = _sprite2d("spreader")
	_spreader.visible = false
	add_child(_spreader)
	_cargo = _container_sprite()
	_cargo.visible = false
	add_child(_cargo)


func _build_sts() -> void:
	var beam := _sprite2d("sts_beam")
	beam.position = Vector2(-44, 15)
	add_child(beam)
	_sprite = _sprite2d("sts_base")
	add_child(_sprite)
	_extra = _sprite2d("sts_trolley")
	add_child(_extra)
	_spreader = _sprite2d("spreader")
	_spreader.visible = false
	add_child(_spreader)
	_cargo = _container_sprite()
	_cargo.visible = false
	add_child(_cargo)


func _build_train() -> void:
	_sprite = Node2D.new()
	_sprite.scale = Vector2(0.70, 0.70)
	add_child(_sprite)
	var loco := _sprite2d("veh_loco", true)
	loco.rotation = PI / 2.0
	_sprite.add_child(loco)
	for w in 3:
		var wagon := _sprite2d("veh_wagon", true)
		wagon.rotation = PI / 2.0
		wagon.position.x = -40.0 - w * 32.0
		_sprite.add_child(wagon)
		var box := _container_sprite()
		box.centered = true
		box.rotation = PI / 2.0
		box.position.x = wagon.position.x
		_sprite.add_child(box)
	_speed = 34.0


func _build_drone() -> void:
	_sprite = _anim("veh_drone", 2, 18, 18, 16.0, true)
	_sprite.scale = Vector2(0.70, 0.70)
	add_child(_sprite)
	_add_shadow(9.0, 6.0, Vector2(2, 14))


func _build_customs() -> void:
	_build_static("bld_customs")
	_extra = _sprite2d("bld_customs_arm")
	_extra.position = Vector2(26, 10)
	add_child(_extra)


func _build_tower() -> void:
	_build_static("bld_tower")
	_extra = _sprite2d("bld_tower_radar", true)
	_extra.position = Vector2(14, 14)
	add_child(_extra)


func _build_portal() -> void:
	_add_shadow(32.0, 12.0, Vector2(17, 32))
	_sprite = _anim("bld_portal", 3, 34, 34, 6.0)
	add_child(_sprite)


func _container_sprite() -> Sprite2D:
	var spr := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = CONTAINERS
	at.region = Rect2((randi() % 8) * 24, 0, 24, 13)
	spr.texture = at
	spr.centered = false
	return spr


func _set_cargo_color(color_idx: int) -> void:
	var at := _cargo.texture as AtlasTexture
	if at != null:
		at.region = Rect2(color_idx * 24, 0, 24, 13)


# ---------------------------------------------------------------- placement

func set_lane(lane_y: float, vertical: bool = false, lane_x: float = 0.0) -> void:
	_lane_y = lane_y
	_lane_x = lane_x
	_vertical = vertical


func set_block(origin: Vector2) -> void:
	_block_origin = origin


# ------------------------------------------------------------------ process

func _process(delta: float) -> void:
	_t += delta
	match id:
		"estivador":
			_walk_lane(delta)
		"empilhadeira", "tt", "reach_stacker":
			_run_job(delta)
		"rebocador":
			_patrol_water(delta)
		"trem":
			_run_rail(delta)
		"drone":
			_fly()
		"rtg":
			_rtg_cycle()
		"sts":
			_sts_cycle()
		"torre":
			if _extra != null:
				_extra.rotation = _t * 1.1
		"alfandega":
			if _extra != null:
				_extra.rotation = -0.9 + absf(sin(_t * 0.5)) * 0.9
		"flutuante":
			position.y = _lane_y + sin(_t * 0.7 + _phase) * 3.0
			if _sprite != null:
				_sprite.rotation = sin(_t * 0.5 + _phase) * 0.015


# ---------- haulers ----------

func _run_job(delta: float) -> void:
	match _job:
		Job.IDLE:
			_cooldown -= delta
			if _cooldown <= 0.0:
				_try_take_job()
		Job.WORKING:
			_work_timer -= delta
			# little lift bob while the spreader does its thing
			_sprite.position.y = -sin(maxf(0.0, _work_timer) * 6.0) * 1.5
			if _work_timer <= 0.0:
				_finish_work()
		_:
			_follow_waypoints(delta)


func _try_take_job() -> void:
	if _world == null:
		_cooldown = 1.0
		return
	var road_x := PortLayout.GATE_ROAD_X
	var entry := Vector2(road_x, PortLayout.TOP_MARGIN - 24.0)
	# Check the shared gate before request_job reserves an EXPORT landing.
	if _world.traffic != null and not _world.traffic.can_enter(self, "gate", entry):
		_cooldown = 0.5
		return
	var job := _world.request_job()
	if job.is_empty():
		_cooldown = randf_range(1.5, 3.5)
		return
	if _world.traffic != null:
		_world.traffic.reserve(self, "gate")
	_job_data = job
	_carrying = job.type == "deliver"
	_cargo.visible = _carrying
	if _carrying:
		_set_cargo_color(job.color)

	var target: Vector2 = job.pos
	var lane_y := PortLayout.nearest_lane(target.y + 6.0)
	position = entry
	visible = true
	_waypoints = [
		Vector2(road_x, lane_y),
		Vector2(target.x + PortLayout.BOX_W * 0.5, lane_y),
	]
	_job = Job.ENTERING


func _follow_waypoints(delta: float) -> void:
	if _waypoints.is_empty():
		_on_waypoints_done()
		return
	var target: Vector2 = _waypoints[0]
	var delta_v := target - position
	var step := _speed * delta
	if delta_v.length() <= step:
		position = target
		_waypoints.pop_front()
		if _waypoints.is_empty():
			_on_waypoints_done()
		return
	var dir := delta_v.normalized()
	position += dir * step
	_face(dir)


func _face(dir: Vector2) -> void:
	## Pixel art only survives 90° steps, so snap to the dominant axis.
	var rot: float
	if absf(dir.x) > absf(dir.y):
		rot = PI / 2.0 if dir.x > 0.0 else -PI / 2.0
	else:
		rot = 0.0 if dir.y > 0.0 else PI
	_sprite.rotation = rot
	if _shadow != null:
		_shadow.rotation = rot
	if _cargo != null:
		_cargo.rotation = rot


func _on_waypoints_done() -> void:
	match _job:
		Job.ENTERING, Job.TO_TARGET:
			_job = Job.WORKING
			_work_timer = 0.9
		Job.TO_ROAD:
			_waypoints = [Vector2(PortLayout.GATE_ROAD_X, PortLayout.TOP_MARGIN - 30.0)]
			_job = Job.LEAVING
		Job.LEAVING:
			_end_job()
		_:
			_end_job()


func _finish_work() -> void:
	_sprite.position.y = 0.0
	if _world != null:
		if _job_data.get("type") == "pickup":
			var box: Dictionary = _world.begin_hauler_pickup(_job_data.slot)
			if not box.is_empty():
				_job_data["taken"] = box
				_job_data["traffic_token"] = str(box.get("traffic_token", ""))
				_carrying = true
				_cargo.visible = true
				var carried_unit: CargoUnit = box.get("unit")
				_set_cargo_color(carried_unit.color if carried_unit != null else 0)
		else:
			_world.complete_delivery(_job_data.slot, _job_data.level,
				_job_data.color, str(_job_data.get("token", "")))
			_carrying = false
			_cargo.visible = false
	var lane_y := position.y
	_waypoints = [Vector2(PortLayout.GATE_ROAD_X, lane_y)]
	_job = Job.TO_ROAD


func _end_job() -> void:
	if _world != null and not _job_data.is_empty():
		_world.commit_job(_job_data)
	_job = Job.IDLE
	_job_data = {}
	_waypoints.clear()
	_carrying = false
	_cargo.visible = false
	visible = false
	if _world != null and _world.traffic != null:
		_world.traffic.release(self)
	_cooldown = randf_range(1.0, 4.0)


# ---------- other behaviours ----------

func _walk_lane(delta: float) -> void:
	position.x += _dir * _speed * delta
	if position.x < PortLayout.GATE_ROAD_X:
		_dir = 1.0
	elif position.x > PortLayout.QUAY_X1 - 12.0:
		_dir = -1.0
	_walk.flip_h = _dir < 0.0
	if _walk.frame >= 4:
		_walk.frame = _walk.frame % 4
	position.y = _lane_y + sin(_t * 5.0 + _phase) * 0.5


func _patrol_water(delta: float) -> void:
	position.y += _dir * _speed * delta
	if position.y < PortLayout.SHIP_Y + PortLayout.SHIP_H + 20.0:
		_dir = 1.0
	elif position.y > PortLayout.world_bottom() - 50.0:
		_dir = -1.0
	_sprite.rotation = 0.0 if _dir > 0.0 else PI
	position.x = _lane_x + sin(_t * 0.6 + _phase) * 3.0


func _run_rail(delta: float) -> void:
	position.x += _speed * delta
	if position.x > PortLayout.WORLD_W + 220.0:
		position.x = -220.0


func _fly() -> void:
	var home: Vector2 = get_meta("home", position)
	position = home + Vector2(sin(_t * 0.55 + _phase) * 46.0,
		sin(_t * 0.9 + _phase) * 26.0)
	if _shadow != null:
		_shadow.position = Vector2(2, 14 + sin(_t * 0.9 + _phase) * 1.5)


func _rtg_cycle() -> void:
	var travel := PortLayout.BLOCK_H - 22.0
	position.y = _block_origin.y - 8.0 + (sin(_t * 0.25 + _phase) * 0.5 + 0.5) * travel
	var cycle := 5.0
	var t: float = fmod(_t + _phase, cycle) / cycle
	var span := PortLayout.BLOCK_W - 4.0
	var x: float = 14.0 + (sin(t * TAU) * 0.5 + 0.5) * span
	_extra.position = Vector2(x - 10.0, 6.0)
	var drop: float = 10.0 if fmod(t * 2.0, 1.0) > 0.55 else 2.0
	_spreader.visible = true
	_spreader.position = Vector2(x - 12.0, 8.0 + drop)
	var carrying := t > 0.5
	_cargo.visible = carrying
	if carrying:
		_cargo.position = _spreader.position


func _sts_cycle() -> void:
	var cycle := 6.0
	var t: float = fmod(_t + _phase, cycle) / cycle
	var yard_x := -30.0
	var ship_x := 52.0
	var x: float
	var carrying := false
	var drop := 0.0
	if t < 0.28:
		x = lerpf(yard_x, ship_x, _ease(t / 0.28))
	elif t < 0.42:
		x = ship_x
		drop = sin((t - 0.28) / 0.14 * PI) * 7.0
		carrying = (t - 0.28) / 0.14 > 0.55
	elif t < 0.72:
		x = lerpf(ship_x, yard_x, _ease((t - 0.42) / 0.30))
		carrying = true
	elif t < 0.86:
		x = yard_x
		drop = sin((t - 0.72) / 0.14 * PI) * 7.0
		carrying = (t - 0.72) / 0.14 < 0.5
	else:
		x = yard_x
	_extra.position = Vector2(x - 2.0, 12.0)
	_spreader.visible = true
	_spreader.position = Vector2(x - 5.0, 18.0 + drop)
	_cargo.visible = carrying
	if carrying:
		_cargo.position = _spreader.position


static func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


func pop_in() -> void:
	if is_hauler():
		return       # haulers appear when they drive in, not on purchase
	modulate.a = 0.0
	scale = Vector2(0.6, 0.6)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.20)
	tween.tween_property(self, "scale", Vector2.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
