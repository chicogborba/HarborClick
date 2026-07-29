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
	var splash := AnimatedSprite2D.new()
	splash.sprite_frames = _splash_frames()
	splash.animation = &"default"
	splash.centered = false
	splash.position = Vector2(PortLayout.WATER_X0 + 42.0 + index * 22.0, 96.0 + index * 94.0)
	splash.z_index = -6
	splash.frame = index % 5
	splash.play()
	add_child(splash)
	_splashes.append(splash)


func _process(delta: float) -> void:
	_time += delta
	# Only a handful of transforms change; the shader owns continuous water motion.
	for item: Dictionary in _foam:
		var sprite: Sprite2D = item.node
		if is_instance_valid(sprite):
			sprite.position.x = float(item.base_x) + roundf(sin(_time * 0.75 + float(item.phase)) * 2.0)


func _foam_frame(frame: int) -> AtlasTexture:
	var texture: Texture2D = preload("res://assets/sprites/foam_sheet.png")
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(frame * 16, 0, 16, 6)
	return atlas


func _splash_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 3.0)
	var texture: Texture2D = preload("res://assets/sprites/prop_splash.png")
	for frame in 5:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(frame * 16, 0, 16, 14)
		frames.add_frame(&"default", atlas)
	return frames
