class_name Critters
extends Node2D
## Ambient life: gulls wheeling over the water and a cat that naps on the
## container stacks, moving to a new spot each day.

const GULL_COUNT := 4

var world: PortWorld
var _gulls: Array[Dictionary] = []
var _cat: AnimatedSprite2D
var _t := 0.0


func setup(port: PortWorld) -> void:
	world = port
	for i in GULL_COUNT:
		_add_gull(i)
	_add_cat()
	EventBus.new_day.connect(func(_d: int) -> void: _move_cat())


func _add_gull(index: int) -> void:
	var gull := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	var tex: Texture2D = preload("res://assets/sprites/prop_seagull.png")
	frames.set_animation_speed(&"default", 9.0)
	for f in 4:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(f * 14, 0, 14, 12)
		frames.add_frame(&"default", at)
	gull.sprite_frames = frames
	gull.centered = true
	gull.frame = index % 4
	gull.play()
	world.overhead.add_child(gull)
	_gulls.append({
		"node": gull,
		"phase": randf() * TAU,
		"rx": randf_range(40.0, 70.0),
		"ry": randf_range(30.0, 70.0),
		"center": Vector2(randf_range(230.0, 300.0), randf_range(90.0, 320.0)),
		"speed": randf_range(0.22, 0.4),
	})


func _add_cat() -> void:
	_cat = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	var tex: Texture2D = preload("res://assets/sprites/prop_cat.png")
	frames.set_animation_speed(&"default", 1.2)
	for f in 2:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(f * 14, 0, 14, 12)
		frames.add_frame(&"default", at)
	_cat.sprite_frames = frames
	_cat.centered = false
	_cat.play()
	world.entities.add_child(_cat)
	_cat.position = _cat_spot()
	_cat.set_meta("placed", true)


func _cat_spot() -> Vector2:
	var blocks := PortLayout.block_count()
	var origin := PortLayout.block_origin(randi() % maxi(1, blocks))
	return origin + Vector2(randf_range(0.0, PortLayout.BLOCK_W - 14.0),
		randf_range(0.0, PortLayout.BLOCK_H - 12.0))


func _move_cat() -> void:
	var target := _cat_spot()
	var tween := create_tween()
	tween.tween_property(_cat, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void: _cat.position = target)
	tween.tween_property(_cat, "modulate:a", 1.0, 0.4)


func tap_cat(world_pos: Vector2) -> bool:
	## Petting the cat grants a short click-power boost.
	if _cat == null or _cat.modulate.a < 0.5:
		return false
	if not Rect2(_cat.position - Vector2(4, 4), Vector2(22, 20)).has_point(world_pos):
		return false
	var granted := GameState.grant_cat_boost()
	if granted:
		EventBus.notification_requested.emit({
			"id": "cat_boost", "kind": &"cat", "priority": 1,
			"text": "O gato aprovou. Cliques turbinados!"})
	var tween := create_tween()
	tween.tween_property(_cat, "scale", Vector2(1.25, 0.8), 0.08)
	tween.tween_property(_cat, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return true


func _process(delta: float) -> void:
	_t += delta
	if randf() < delta * 0.05:
		AudioManager.play_sfx("gull", 0.18, -12.0)
	for gull: Dictionary in _gulls:
		var node: AnimatedSprite2D = gull.node
		var a: float = _t * gull.speed + gull.phase
		node.position = gull.center + Vector2(cos(a) * gull.rx, sin(a * 1.3) * gull.ry)
		node.rotation = a + PI / 2.0
