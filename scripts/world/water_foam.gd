class_name WaterFoam
extends Node2D
## A tiny sprite layer over the shader: static quay foam and a few ambient
## splash animations. Count is capped by quality rather than world height.

const MAX_FOAM := [6, 10, 14]
const MAX_SPLASH := [0, 1, 2]

var quality: WaterQuality.Level = WaterQuality.Level.MEDIUM
var _world_bottom := 480.0
var _foam: Array[Dictionary] = []
var _splashes: Array[AnimatedSprite2D] = []
## Seconds until each splash next breaks the surface somewhere new.
var _splash_waits: Array[float] = []
var _time := 0.0


func setup(level: WaterQuality.Level, world_bottom: float) -> void:
	quality = level
	_world_bottom = world_bottom
	rebuild(world_bottom)


func set_quality(level: WaterQuality.Level) -> void:
	if quality == level:
		return
	quality = level
	rebuild(_world_bottom)


func rebuild(world_bottom: float) -> void:
	_world_bottom = world_bottom
	for child in get_children():
		child.queue_free()
	_foam.clear()
	_splashes.clear()
	_splash_waits.clear()
	var spacing := WaterQuality.foam_spacing(quality)
	var count := mini(MAX_FOAM[int(quality)], maxi(1, int(ceil(world_bottom / spacing))))
	for index in count:
		_add_foam(index, count)
	for index in MAX_SPLASH[int(quality)]:
		_add_splash(index)


func foam_count() -> int:
	return _foam.size()


func splash_count() -> int:
	return _splashes.size()


func _add_foam(index: int, count: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _foam_frame(index % 4)
	sprite.centered = false
	sprite.position = Vector2(PortLayout.WATER_X0 + 1.0, 14.0 + (float(index) + 0.5) * _world_bottom / float(count))
	sprite.z_index = -7
	add_child(sprite)
	_foam.append({"node": sprite, "base_x": sprite.position.x, "phase": float(index) * 1.73})


func _add_splash(index: int) -> void:
	## A disturbance on the water, not an ornament fixed to it.
	##
	## These used to be looping animations parked at a constant position, so the
	## same ring of foam opened in the same square metre of harbour every second
	## and a quarter, for the whole session. Read as a bug, and fairly: nothing
	## in open water repeats on the spot. Each one now plays once, goes away, and
	## comes back somewhere else after a while.
	var splash := AnimatedSprite2D.new()
	splash.sprite_frames = _splash_frames()
	splash.animation = &"default"
	splash.centered = false
	splash.z_index = -6
	splash.visible = false
	add_child(splash)
	_splashes.append(splash)
	_splash_waits.append(1.5 + index * 2.6)


func _process(delta: float) -> void:
	_time += delta
	# Only a handful of transforms change; the shader owns continuous water motion.
	for item: Dictionary in _foam:
		var sprite: Sprite2D = item.node
		if is_instance_valid(sprite):
			sprite.position.x = float(item.base_x) + roundf(sin(_time * 0.75 + float(item.phase)) * 2.0)
	for index in _splashes.size():
		var splash: AnimatedSprite2D = _splashes[index]
		if not is_instance_valid(splash):
			continue
		_splash_waits[index] -= delta
		if _splash_waits[index] > 0.0:
			# Hidden once the ring has finished opening, rather than looping.
			splash.visible = splash.is_playing()
			continue
		_splash_waits[index] = randf_range(4.0, 11.0)
		splash.position = Vector2(
			randf_range(PortLayout.WATER_X0 + 16.0, PortLayout.WORLD_W - 22.0),
			randf_range(40.0, maxf(60.0, _world_bottom - 40.0)))
		splash.visible = true
		splash.frame = 0
		splash.play()


func _foam_frame(frame: int) -> AtlasTexture:
	var texture: Texture2D = preload("res://assets/sprites/foam_sheet.png")
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(frame * 16, 0, 16, 6)
	return atlas


func _splash_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 6.0)
	# Played once per disturbance, so it must be able to finish.
	frames.set_animation_loop(&"default", false)
	# Four frames of 20, which is what `gen_splash` writes. Read as five of 16 it
	# still filled the 80px sheet, so nothing errored — every ambient splash was
	# just two half-rings sliced out of the middle of two others.
	var texture: Texture2D = preload("res://assets/sprites/prop_splash.png")
	for frame in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(frame * 20, 0, 20, 14)
		frames.add_frame(&"default", atlas)
	return frames
