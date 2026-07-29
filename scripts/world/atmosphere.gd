class_name Atmosphere
extends Node2D
## Day/night lighting for the top-down port: global tint, flood-light masts
## that strike at dusk, and rolling fog on foggy days.

const KEYS := [
	{"t": 0.00, "tint": Color(0.34, 0.40, 0.68)},
	{"t": 0.20, "tint": Color(0.40, 0.46, 0.72)},
	{"t": 0.26, "tint": Color(0.86, 0.68, 0.66)},
	{"t": 0.34, "tint": Color(1.00, 0.98, 0.94)},
	{"t": 0.68, "tint": Color(1.00, 1.00, 1.00)},
	{"t": 0.76, "tint": Color(1.00, 0.76, 0.60)},
	{"t": 0.86, "tint": Color(0.44, 0.48, 0.76)},
	{"t": 1.00, "tint": Color(0.34, 0.40, 0.68)},
]

const LAMP_ENERGY := 1.05
## How hard the quay masts burn while a ship is being worked, regardless of
## the time of day.
const BERTH_WORK_ENERGY := 0.55

var world: PortWorld
var _berth_active := false

var _tint: CanvasModulate
var _lamps_root: Node2D
var _lamps: Array[Dictionary] = []
var _fog_rect: ColorRect
var _fog_mat: ShaderMaterial
var _fog_amount := 0.0
var _foghorn_timer := 0.0


func setup(port: PortWorld) -> void:
	world = port
	_tint = CanvasModulate.new()
	_tint.name = "WorldTint"
	world.add_child(_tint)
	_lamps_root = Node2D.new()
	_lamps_root.name = "Lamps"
	_lamps_root.y_sort_enabled = true
	# masts belong in the y-sorted world so stacks can stand in front of them
	world.entities.add_child(_lamps_root)
	rebuild_lamps()
	_build_fog()
	EventBus.fog_changed.connect(_on_fog_changed)
	_on_fog_changed(TimeManager.fog_active)


func rebuild_lamps() -> void:
	for child in _lamps_root.get_children():
		child.queue_free()
	_lamps.clear()
	## Where the masts stand is geometry, so `PortLayout` decides it. The old
	## version walked down the yard on a 150px stride that agreed with nothing
	## and picked a runway per row by modulo, which put masts in the middle of
	## the road and left the pattern looking like spilt change.
	for spot: Dictionary in PortLayout.lamp_spots():
		_add_lamp(spot.pos, bool(spot.quay))


func tap_lamp(world_pos: Vector2) -> bool:
	## Tapping a mast forces it on or off. The override is deliberately not
	## permanent: it is cleared the next time the natural curve agrees with it,
	## so the yard always drifts back to lighting up at dusk on its own instead
	## of leaving the player with a checklist of lamps to reset.
	for lamp: Dictionary in _lamps:
		var root: Node2D = lamp.root
		if root == null or not is_instance_valid(root):
			continue
		if not Rect2(root.position - Vector2(6, 6), Vector2(24, 30)).has_point(world_pos):
			continue
		var natural_on := _lamp_natural_target() > 0.5
		lamp["override"] = -1 if (lamp.lit.modulate.a > 0.5) else 1
		if (lamp.override > 0) == natural_on:
			lamp["override"] = 0
		AudioManager.play_sfx("tap", 0.08)
		return true
	return false


func _lamp_natural_target() -> float:
	var target := clampf(_night_factor(TimeManager.time_of_day) * 1.25, 0.0, 1.0)
	if _fog_amount > 0.0:
		target = maxf(target, _fog_amount * 0.5)
	return target


func set_berth_active(active: bool) -> void:
	## A working berth is lit whatever the clock says — that is what a real
	## terminal does, and it makes the one place the player should be tapping
	## the brightest thing on screen during a call.
	_berth_active = active


func _add_lamp(pos: Vector2, quay: bool) -> void:
	var root := Node2D.new()
	root.position = pos
	_lamps_root.add_child(root)

	var post := Sprite2D.new()
	post.texture = preload("res://assets/sprites/prop_lamp.png")
	post.centered = false
	root.add_child(post)

	var lit := Sprite2D.new()
	lit.texture = preload("res://assets/sprites/prop_lamp_lit.png")
	lit.centered = false
	lit.modulate.a = 0.0
	root.add_child(lit)

	var light := PointLight2D.new()
	light.texture = preload("res://assets/sprites/prop_glow.png")
	light.position = Vector2(6, 6)
	light.texture_scale = 1.5
	light.energy = 0.0
	light.color = Color8(255, 228, 172)
	root.add_child(light)

	_lamps.append({"lit": lit, "light": light, "phase": randf() * 10.0,
		"quay": quay, "root": root, "override": 0})


func _build_fog() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	world.add_child(layer)
	_fog_rect = ColorRect.new()
	_fog_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = preload("res://assets/shaders/fog.gdshader")
	_fog_mat.set_shader_parameter("amount", 0.0)
	_fog_rect.material = _fog_mat
	layer.add_child(_fog_rect)


func _on_fog_changed(active: bool) -> void:
	var tween := create_tween()
	tween.tween_method(_set_fog, _fog_amount, 1.0 if active else 0.0, 7.0)


func _set_fog(value: float) -> void:
	_fog_amount = value
	_fog_mat.set_shader_parameter("amount", value)


func _process(delta: float) -> void:
	var tint := _sample(TimeManager.time_of_day)
	if _fog_amount > 0.0:
		tint = tint.lerp(Color(0.80, 0.84, 0.88), _fog_amount * 0.30)
	_tint.color = tint

	var night := _night_factor(TimeManager.time_of_day)
	var target := clampf(night * 1.25, 0.0, 1.0)
	if _fog_amount > 0.0:
		target = maxf(target, _fog_amount * 0.5)
	for lamp: Dictionary in _lamps:
		var lit: Sprite2D = lamp.lit
		var light: PointLight2D = lamp.light
		var lamp_target := target
		if bool(lamp.quay) and _berth_active:
			lamp_target = maxf(lamp_target, BERTH_WORK_ENERGY)
		var override := int(lamp.override)
		if override != 0:
			# The moment the clock agrees with the switch, the switch is spent.
			if (override > 0) == (lamp_target > 0.5):
				lamp["override"] = 0
			else:
				lamp_target = 1.0 if override > 0 else 0.0
		var flicker := 1.0
		if lamp_target > 0.05 and lit.modulate.a < 0.85:
			flicker = 0.4 + 0.6 * absf(sin(lamp.phase + Time.get_ticks_msec() * 0.02))
		lit.modulate.a = move_toward(lit.modulate.a, lamp_target, delta * 0.8)
		light.energy = move_toward(light.energy,
			lamp_target * LAMP_ENERGY * flicker, delta * 1.1)
		light.texture_scale = 1.5 + _fog_amount * 0.9

	if _fog_amount > 0.5:
		_foghorn_timer -= delta
		if _foghorn_timer <= 0.0:
			_foghorn_timer = randf_range(14.0, 26.0)
			AudioManager.play_sfx("foghorn", 0.03, -8.0)


func _sample(t: float) -> Color:
	for i in range(KEYS.size() - 1):
		var a: Dictionary = KEYS[i]
		var b: Dictionary = KEYS[i + 1]
		if t >= a.t and t <= b.t:
			var k: float = 0.0 if is_equal_approx(b.t, a.t) else (t - a.t) / (b.t - a.t)
			return (a.tint as Color).lerp(b.tint, smoothstep(0.0, 1.0, k))
	return KEYS[-1].tint


func _night_factor(t: float) -> float:
	## One curve, shared with Skyscape: the flood lights and the reflections on
	## the water can never disagree about whether it is night.
	return Skyscape._night_factor(t)
