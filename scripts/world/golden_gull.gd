class_name GoldenGull
extends Node2D
## The gaivota dourada: a golden gull carrying a parcel across the visible
## part of the terminal for a few seconds. Tapping it pays a prize (rolled by
## `GoldenGullPolicy` in `PortWorld`); letting it fly off costs nothing and
## emits `escaped`.
##
## Pixel rules: the sprites are never rotated and never scaled by anything but
## the glow's fixed factor, every position is rounded to whole pixels, and the
## textures stay on nearest-neighbour filtering. The sparkle trail is a fixed
## pool — no node is ever created per frame.

signal escaped

const GULL_SHEET := preload("res://assets/sprites/fx_gold_gull.png")
const SPARKLE_SHEET := preload("res://assets/sprites/fx_sparkle.png")
const GLOW_SHEET := preload("res://assets/sprites/prop_glow.png")
## `fx_gold_gull.png`: 4 frames of 26x22 in a strip, facing EAST. Wingbeat
## order up / level / down / level, so frame 0 is the top of the stroke.
const FRAME_W := 26.0
const FRAME_H := 22.0
## `fx_sparkle.png`: 4 frames of 7x7 — the star opens, flares and closes.
const SPARKLE_SIZE := 7.0
const FLAP_FPS := 10.0
const BOB_AMPLITUDE := 2.0
const BOB_SPEED := 6.0
## A moving thing gets a generous touch target.
const HIT_RADIUS := 18.0
const TRAIL_POOL := 10
const TRAIL_INTERVAL := 0.12
const TRAIL_LIFE := 0.4
const BURST_COUNT := 12
const BURST_TIME := 0.5
const BURST_RADIUS := 28.0
## Seconds the catch burst lingers before the node frees itself.
const FREE_DELAY := 0.6
const GLOW_SCALE := 0.35
const GLOW_COLOR := Color(1.0, 0.85, 0.35)

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _duration := 1.0
var _t := 0.0
var _caught := false
var _finished := false
var _freeing := false
var _caught_t := 0.0
var _trail_due := 0.0
var _next_sparkle := 0
var _animate := true
var _burst_centre := Vector2.ZERO
var _bird: Sprite2D
var _glow: Sprite2D
var _gull_atlas: AtlasTexture
var _sparkles: Array[Sprite2D] = []
var _sparkle_atlases: Array[AtlasTexture] = []
## Per-sparkle state, index-aligned with `_sparkles`: {active, age, dir, burst}.
var _sparkle_state: Array[Dictionary] = []


func setup(from: Vector2, to: Vector2, duration: float) -> void:
	## Arm one flight: a straight line from `from` to `to` over `duration`
	## seconds, mirrored when it flies west.
	_from = from
	_to = to
	_duration = maxf(0.1, duration)
	_animate = UserPreferences.can_animate()
	position = from
	_build()


func hit_test(world_pos: Vector2) -> bool:
	## Distance to the gull's centre, generous because the thing is moving.
	if _caught or _finished:
		return false
	return global_position.distance_to(world_pos) < HIT_RADIUS


func catch() -> void:
	## Tapped: stop flying, hide the bird and burst sparkles outward from the
	## centre. `hit_test` goes false from here on.
	if _caught or _finished:
		return
	_caught = true
	_burst_centre = Vector2(roundf(global_position.x), roundf(global_position.y))
	_bird.visible = false
	_glow.visible = false
	for i in BURST_COUNT:
		var angle := TAU * float(i) / float(BURST_COUNT)
		_emit_sparkle(_burst_centre, true, Vector2(cos(angle), sin(angle)))


func _build() -> void:
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.texture = GLOW_SHEET
	_glow.centered = true
	_glow.scale = Vector2.ONE * GLOW_SCALE
	_glow.modulate = GLOW_COLOR
	_glow.modulate.a = 0.6
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	add_child(_glow)

	_bird = Sprite2D.new()
	_bird.name = "Bird"
	_bird.centered = true
	_bird.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bird.flip_h = _to.x < _from.x
	_gull_atlas = AtlasTexture.new()
	_gull_atlas.atlas = GULL_SHEET
	_gull_atlas.region = Rect2(0, 0, FRAME_W, FRAME_H)
	_bird.texture = _gull_atlas
	add_child(_bird)

	for i in TRAIL_POOL:
		var atlas := AtlasTexture.new()
		atlas.atlas = SPARKLE_SHEET
		atlas.region = Rect2(0, 0, SPARKLE_SIZE, SPARKLE_SIZE)
		var s := Sprite2D.new()
		s.name = "Sparkle%d" % i
		s.centered = true
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.texture = atlas
		s.visible = false
		# Top-level: a trail stays where it was dropped while the bird flies
		# on, and every sparkle position below is in world space. As plain
		# children they were offset by the gull's own position a second time
		# and the whole trail drew somewhere off to the side, or off screen.
		s.top_level = true
		add_child(s)
		_sparkles.append(s)
		_sparkle_atlases.append(atlas)
		_sparkle_state.append({"active": false, "age": 0.0,
			"dir": Vector2.ZERO, "burst": false})


func _process(delta: float) -> void:
	if _finished or _freeing:
		return
	if _caught:
		_caught_t += delta
		_drive_burst(_caught_t)
		_drive_trail(delta)
		if _caught_t >= FREE_DELAY:
			_finished = true
			_free_self()
		return
	_t += delta
	if _t >= _duration:
		# Uncaught: land exactly on `to`, say so once, and go away.
		position = _to
		_finished = true
		escaped.emit()
		_free_self()
		return
	var base := _from.lerp(_to, _t / _duration)
	var bob := 0.0
	if _animate:
		bob = roundf(sin(_t * BOB_SPEED) * BOB_AMPLITUDE)
	position = Vector2(roundf(base.x), roundf(base.y) + bob)
	var frame := int(_t * FLAP_FPS) % 4
	_gull_atlas.region = Rect2(frame * FRAME_W, 0, FRAME_W, FRAME_H)
	if _animate:
		_glow.modulate.a = 0.625 + sin(_t * 5.0) * 0.175
		_trail_due -= delta
		if _trail_due <= 0.0:
			_trail_due = TRAIL_INTERVAL
			_emit_sparkle(_tail_position(), false, Vector2.ZERO)
	_drive_trail(delta)


func _tail_position() -> Vector2:
	## Behind the bird: the sprite faces east unless mirrored for a westward
	## flight, in which case the tail is on the +x side.
	var dir := -1.0 if _bird.flip_h else 1.0
	return global_position + Vector2(-10.0 * dir, 2.0)


func _emit_sparkle(at: Vector2, burst: bool, dir: Vector2) -> void:
	## Take a free sparkle from the pool, or recycle the oldest slot when the
	## whole pool is live — never a new node.
	var index := -1
	for i in _sparkle_state.size():
		if not bool(_sparkle_state[i].active):
			index = i
			break
	if index < 0:
		index = _next_sparkle
		_next_sparkle = (_next_sparkle + 1) % TRAIL_POOL
	var st: Dictionary = _sparkle_state[index]
	st.active = true
	st.age = 0.0
	st.dir = dir
	st.burst = burst
	var s := _sparkles[index]
	s.visible = true
	s.position = Vector2(roundf(at.x), roundf(at.y))
	_sparkle_atlases[index].region = Rect2(0, 0, SPARKLE_SIZE, SPARKLE_SIZE)


func _drive_trail(delta: float) -> void:
	## Each trail sparkle plays its 4 frames over TRAIL_LIFE at the spot it was
	## emitted, then hides.
	for i in _sparkle_state.size():
		var st: Dictionary = _sparkle_state[i]
		if not bool(st.active) or bool(st.burst):
			continue
		st.age = float(st.age) + delta
		if float(st.age) >= TRAIL_LIFE:
			st.active = false
			_sparkles[i].visible = false
			continue
		var frame := mini(int(float(st.age) / TRAIL_LIFE * 4.0), 3)
		_sparkle_atlases[i].region = Rect2(frame * SPARKLE_SIZE, 0,
			SPARKLE_SIZE, SPARKLE_SIZE)


func _drive_burst(t: float) -> void:
	## The catch burst: sparkles fly outward from the centre over BURST_TIME.
	for i in _sparkle_state.size():
		var st: Dictionary = _sparkle_state[i]
		if not bool(st.active) or not bool(st.burst):
			continue
		if t >= BURST_TIME:
			st.active = false
			_sparkles[i].visible = false
			continue
		var dir: Vector2 = st.dir
		var p := _burst_centre + dir * (BURST_RADIUS * t / BURST_TIME)
		_sparkles[i].position = Vector2(roundf(p.x), roundf(p.y))
		var frame := mini(int(t / BURST_TIME * 4.0), 3)
		_sparkle_atlases[i].region = Rect2(frame * SPARKLE_SIZE, 0,
			SPARKLE_SIZE, SPARKLE_SIZE)


func _free_self() -> void:
	_freeing = true
	# A headless suite drives this node outside the tree, where queue_free has
	# nothing to defer to; the _finished flag keeps it inert either way.
	if is_inside_tree():
		queue_free()


func show_hint(text: String) -> void:
	## A caption that flies with the bird for its first few seconds — the first
	## gull of a session saying what it is for. Outlined like FloatText so it
	## survives over any pixel art under it.
	var label := Label.new()
	label.text = text
	label.label_settings = UiTheme.settings(UiTheme.SIZE_SMALL, UiTheme.AMBER, 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(120.0, 12.0)
	label.position = Vector2(-60.0, -26.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)
