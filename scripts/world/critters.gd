class_name Critters
extends Node2D
## Ambient life: gulls wheeling over the water and a cat that naps on the
## container stacks, moving to a new spot each day.

const GULL_COUNT := 4

var world: PortWorld
var _gulls: Array[Dictionary] = []
var _cat: Sprite2D
var _cat_outline: ClickOutline
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


## The cat sheet: twelve 24x24 cells, loafers first (they nap on the stacks),
## sitters last. Generated — see `tools/sprites/gen_pixellab.py`.
const CAT_SHEET := preload("res://assets/sprites/prop_cats.png")
const CAT_CELL := 24
const CAT_VARIANTS := 12
const CAT_LOAFERS := 8


static func make_cat(variant: int) -> Sprite2D:
	## One cat, bottom-centre anchored so a squash breathes from the ground up.
	var cat := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = CAT_SHEET
	at.region = Rect2(posmod(variant, CAT_VARIANTS) * CAT_CELL, 0, CAT_CELL, CAT_CELL)
	cat.texture = at
	cat.centered = false
	cat.offset = Vector2(-CAT_CELL * 0.5, -CAT_CELL)
	cat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return cat


static func breathe(cat: Sprite2D, seed_value: int) -> void:
	## A nap is slow breathing, and now and then a stretch. Whole-sprite motion
	## only: there is one frame per cat, and a tail drawn by code next to a
	## generated cat would be the potato again.
	if not UserPreferences.can_animate():
		return
	var tween := cat.create_tween().set_loops()
	tween.tween_interval(1.2 + float(posmod(seed_value, 7)) * 0.35)
	tween.tween_property(cat, "scale", Vector2(1.06, 0.94), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cat, "scale", Vector2.ONE, 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _add_cat() -> void:
	# The yard's own cat is the orange loafer: the one the colony is built round.
	_cat = make_cat(0)
	world.entities.add_child(_cat)
	breathe(_cat, 0)
	# The cat can be petted, so it is outlined like everything else tappable.
	_cat_outline = ClickOutline.attach(_cat)
	_cat.position = _cat_spot()
	_cat.set_meta("placed", true)


func _cat_spot() -> Vector2:
	var blocks := PortLayout.block_count()
	var origin := PortLayout.block_origin(randi() % maxi(1, blocks))
	return origin + Vector2(randf_range(12.0, PortLayout.BLOCK_W - 12.0),
		randf_range(14.0, PortLayout.BLOCK_H))


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
	if not Rect2(_cat.position - Vector2(14, 20), Vector2(28, 24)).has_point(world_pos):
		return false
	var granted := GameState.grant_cat_boost()
	if granted:
		EventBus.notification_requested.emit({
			"id": "cat_boost", "kind": &"cat", "priority": 1,
			"text": "O gato aprovou. Cliques turbinados!"})
	var tween := create_tween()
	tween.tween_property(_cat, "scale", Vector2(1.2, 0.8), 0.08)
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
		# Face along the velocity (the derivative of the orbit), not the orbit
		# angle — `a + PI/2` made the gull tumble continuously. Flip horizontally
		# when heading left so the sprite never flies upside-down.
		var vel := Vector2(-sin(a) * gull.rx, cos(a * 1.3) * gull.ry * 1.3)
		var ang := vel.angle()
		node.flip_h = cos(ang) < 0.0
		node.rotation = ang + (PI if node.flip_h else 0.0)
