class_name Skyscape
extends Node2D
## Weather and sky, expressed the way a top-down camera can actually see them.
##
## You cannot look up from here, so none of this is drawn as sky. Clouds appear
## only as the shadows they drop on the terminal; the moon and the stars appear
## only as reflections on the water, under the hull rather than over it. That
## keeps the whole thing out of the reading path — the yard, the quay and the
## boxes are never covered by decoration.
##
## Everything fades with the day/night curve and with fog, and the drifting
## cloud shadows stand down entirely under reduced motion.

const CLOUD_COUNT := 3
const STAR_COUNT := 16
const CLOUD_ALPHA := 0.17
const CLOUD_SPEED := Vector2(-5.5, 2.2)

var world: PortWorld

var _shadows: Node2D
var _reflections: Node2D
var _clouds: Array[Sprite2D] = []
var _stars: Array[Dictionary] = []
var _moon: Sprite2D
var _t := 0.0
var _daylight := 0.0
var _night := 0.0


func setup(port: PortWorld) -> void:
	world = port
	# Cloud shadows fall on everything standing on the ground, so they sit
	# above the y-sorted entities but below the HUD.
	_shadows = Node2D.new()
	_shadows.name = "CloudShadows"
	_shadows.z_index = 40
	_shadows.z_as_relative = false
	world.add_child(_shadows)
	# Reflections are *in* the water, so the hull and the foam cover them.
	_reflections = Node2D.new()
	_reflections.name = "WaterReflections"
	_reflections.z_index = -8
	_reflections.z_as_relative = false
	world.add_child(_reflections)
	_build_clouds()
	_build_night_sky()
	rebuild()


func rebuild() -> void:
	## Land purchases make the water column longer; the reflections spread over
	## whatever water there is now.
	var bottom := PortLayout.world_bottom()
	for cloud in _clouds:
		cloud.position.y = fmod(cloud.position.y, bottom + 200.0)
	_place_night_sky(bottom)


func _build_clouds() -> void:
	var sheet: Texture2D = preload("res://assets/sprites/prop_cloud.png")
	for i in CLOUD_COUNT:
		var cloud := Sprite2D.new()
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2((i % 2) * 40, 0, 40, 18)
		cloud.texture = frame
		cloud.centered = true
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cloud.scale = Vector2.ONE * randf_range(2.2, 3.4)
		cloud.modulate = Color(0.10, 0.11, 0.20, 0.0)
		# Cloud shadows fall on the terminal, never on the sea. A 17% dark blob
		# drifting over open water does not read as a cloud, it reads as dirt
		# on the screen — which is exactly what the playtest saw.
		cloud.position = Vector2(
			randf_range(-40.0, PortLayout.WATER_X0),
			randf_range(0.0, PortLayout.world_bottom()))
		_shadows.add_child(cloud)
		_clouds.append(cloud)


func _build_night_sky() -> void:
	_moon = Sprite2D.new()
	_moon.texture = preload("res://assets/sprites/prop_moon.png")
	_moon.centered = true
	_moon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_moon.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_reflections.add_child(_moon)

	var sheet: Texture2D = preload("res://assets/sprites/prop_star.png")
	for i in STAR_COUNT:
		var star := Sprite2D.new()
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(0, 0, 3, 3)
		star.texture = frame
		star.centered = true
		star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		star.modulate.a = 0.0
		_reflections.add_child(star)
		_stars.append({"node": star, "frame": frame,
			"rate": randf_range(0.7, 2.1), "phase": randf() * TAU})


func _place_night_sky(bottom: float) -> void:
	## Open water only: south of the berth, clear of the hull and the tugs'
	## patrol line, so nothing that matters is ever behind a glint.
	var water_left := PortLayout.WATER_X0 + 6.0
	var water_right := PortLayout.WORLD_W - 6.0
	var open_top := PortLayout.SHIP_Y + PortLayout.SHIP_H + 26.0
	var span := maxf(60.0, bottom + 140.0 - open_top)
	_moon.position = Vector2((water_left + water_right) * 0.5, open_top + span * 0.32)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for entry: Dictionary in _stars:
		(entry.node as Sprite2D).position = Vector2(
			rng.randf_range(water_left, water_right),
			open_top + rng.randf_range(0.0, span))


func _process(delta: float) -> void:
	_t += delta
	var time_of_day := TimeManager.time_of_day
	_night = _night_factor(time_of_day)
	_daylight = 1.0 - _night
	var fog := 1.0 if TimeManager.fog_active else 0.0
	_drift_clouds(delta, fog)
	_shine_reflections(delta, fog)


func _drift_clouds(delta: float, fog: float) -> void:
	# No sun, no shadow. Fog already flattens the whole scene, so a second
	# darkening layer under it only muddies the yard.
	var animate := UserPreferences.can_animate()
	var target := CLOUD_ALPHA * _daylight * (1.0 - fog) * (1.0 if animate else 0.0)
	var bottom := PortLayout.world_bottom() + 200.0
	for cloud in _clouds:
		cloud.modulate.a = move_toward(cloud.modulate.a, target, delta * 0.35)
		if not animate:
			continue
		cloud.position += CLOUD_SPEED * delta
		if cloud.position.x < -70.0:
			cloud.position.x = PortLayout.WATER_X0
		if cloud.position.y > bottom:
			cloud.position.y = -60.0


func _shine_reflections(delta: float, fog: float) -> void:
	var target := _night * (1.0 - fog * 0.8)
	_moon.modulate.a = move_toward(_moon.modulate.a, target * 0.30, delta * 0.5)
	_moon.position.y += sin(_t * 0.6) * 0.06
	for entry: Dictionary in _stars:
		var star: Sprite2D = entry.node
		star.modulate.a = move_toward(star.modulate.a, target * 0.75, delta * 0.5)
		var step := int(fmod(_t * float(entry.rate) + float(entry.phase), 3.0))
		(entry.frame as AtlasTexture).region = Rect2(step * 3, 0, 3, 3)


static func _night_factor(t: float) -> float:
	## Same curve Atmosphere uses to strike the flood lights, so the sky and the
	## lamps can never disagree about whether it is night.
	if t < 0.20 or t >= 0.88:
		return 1.0
	elif t < 0.32:
		return 1.0 - smoothstep(0.20, 0.32, t)
	elif t < 0.74:
		return 0.0
	return smoothstep(0.74, 0.88, t)
