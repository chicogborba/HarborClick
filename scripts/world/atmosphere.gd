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

var world: PortWorld

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
	## Masts only ever stand on paved gaps — never on top of a stacking block.
	var spots: Array[Vector2] = []
	# along the service road at the gate side
	var y := PortLayout.YARD_Y0 - 10.0
	while y < PortLayout.world_bottom() - 40.0:
		spots.append(Vector2(PortLayout.GATE_ROAD_X - 4.0, y))
		y += 150.0
	# in the runways between block columns, staggered down the yard
	var runways := PortLayout.runway_xs()
	for row in PortLayout.block_rows():
		var lane_y: float = PortLayout.YARD_Y0 \
			+ row * (PortLayout.BLOCK_H + PortLayout.BLOCK_GAP_Y) \
			+ PortLayout.BLOCK_H + 3.0
		var rx: float = runways[row % runways.size()]
		spots.append(Vector2(rx - 5.0, lane_y))
	# on the quay, clear of the crane rails
	y = PortLayout.TOP_MARGIN + 40.0
	while y < PortLayout.world_bottom() - 20.0:
		spots.append(Vector2(PortLayout.QUAY_X0 - 12.0, y))
		y += 150.0
	for spot in spots:
		_add_lamp(spot)


func _add_lamp(pos: Vector2) -> void:
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

	_lamps.append({"lit": lit, "light": light, "phase": randf() * 10.0})


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
		var flicker := 1.0
		if target > 0.05 and lit.modulate.a < 0.85:
			flicker = 0.4 + 0.6 * absf(sin(lamp.phase + Time.get_ticks_msec() * 0.02))
		lit.modulate.a = move_toward(lit.modulate.a, target, delta * 0.8)
		light.energy = move_toward(light.energy, target * LAMP_ENERGY * flicker,
			delta * 1.1)
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
	if t < 0.20 or t >= 0.88:
		return 1.0
	elif t < 0.32:
		return 1.0 - smoothstep(0.20, 0.32, t)
	elif t < 0.74:
		return 0.0
	return smoothstep(0.74, 0.88, t)
