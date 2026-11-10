class_name Fx
extends Node2D
## The port's one VFX library: pooled sprite particles living in the world's
## overhead layer. `burst(&"dust", at)` and friends are the whole public API;
## `Fx.haptic()` is the vibration half of a tap's feedback.
##
## Pixel rules, same as the golden gull: particles are never rotated and never
## scaled, every position is rounded to whole pixels, and the textures stay on
## nearest-neighbour filtering. The pool is fixed at [constant POOL_SIZE] sprites
## created once — when it is exhausted the oldest slot is recycled, and no node
## is ever created per burst. Everything is a no-op while the player has
## "movimento reduzido" on.

const POOL_SIZE := 96

## Per-kind tuning. `w`/`h` are the frame size in the strip sheet, `frames` how
## many frames the sheet holds, `gravity` the downward pull in px/s^2, the
## life range in seconds, `speed` the launch speed and `rise` the upward bias
## added to every particle's velocity.
const KINDS := {
	&"dust": {"sheet": "res://assets/sprites/fx_dust.png", "w": 10, "h": 10,
		"frames": 4, "gravity": 26.0, "life_min": 0.35, "life_max": 0.60,
		"speed": 24.0, "rise": -6.0},
	&"spark": {"sheet": "res://assets/sprites/fx_spark.png", "w": 7, "h": 7,
		"frames": 4, "gravity": 70.0, "life_min": 0.35, "life_max": 0.55,
		"speed": 58.0, "rise": -10.0},
	&"splash": {"sheet": "res://assets/sprites/fx_splash.png", "w": 12, "h": 8,
		"frames": 4, "gravity": 150.0, "life_min": 0.40, "life_max": 0.65,
		"speed": 42.0, "rise": -26.0},
	&"coin": {"sheet": "res://assets/sprites/fx_coin.png", "w": 8, "h": 8,
		"frames": 4, "gravity": 230.0, "life_min": 0.55, "life_max": 0.90,
		"speed": 34.0, "rise": -70.0},
	&"confetti": {"sheet": "res://assets/sprites/fx_confetti.png", "w": 4, "h": 4,
		"frames": 6, "gravity": 95.0, "life_min": 0.60, "life_max": 0.90,
		"speed": 60.0, "rise": -30.0},
}

var _built := false
var _next := 0
var _sprites: Array[Sprite2D] = []
var _atlases: Array[AtlasTexture] = []
## Per-particle state, index-aligned with `_sprites`:
## {active, age, life, kind, vel}.
var _state: Array[Dictionary] = []
## kind -> Texture2D (or null when the PNG has not been generated yet).
var _sheets := {}


func _ready() -> void:
	_ensure_pool()


func burst(kind: StringName, at: Vector2, count: int = 6, spread: float = 14.0) -> void:
	## Emit `count` particles of `kind` at the world position `at`. `spread` is
	## added to the launch speed's randomness. A no-op under reduce motion, and
	## an unknown kind warns and emits nothing.
	if not UserPreferences.can_animate():
		return
	if not KINDS.has(kind):
		push_warning("Fx.burst: unknown kind %s" % String(kind))
		return
	_ensure_pool()
	var cfg: Dictionary = KINDS[kind]
	var origin := Vector2(roundf(at.x), roundf(at.y))
	for i in count:
		_emit(kind, cfg, origin, spread)


static func haptic(ms: int = 12) -> void:
	## A short vibration for a tap that paid. Mobile only, and silent under
	## reduce motion — the same contract as every other motion in the game.
	if OS.has_feature("mobile") and UserPreferences.can_animate():
		Input.vibrate_handheld(ms)


func active_count() -> int:
	## How many pooled particles are live right now (the tests read this).
	var n := 0
	for st in _state:
		if bool(st.active):
			n += 1
	return n


func _ensure_pool() -> void:
	## Build the fixed pool once. Textures are loaded here, not preloaded, so a
	## missing PNG degrades to invisible particles instead of a broken script.
	if _built:
		return
	_built = true
	for kind in KINDS:
		_sheets[kind] = _load_sheet(kind)
	for i in POOL_SIZE:
		var s := Sprite2D.new()
		s.name = "Particle%d" % i
		s.centered = true
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.rotation = 0.0
		s.scale = Vector2.ONE
		s.visible = false
		# Top-level so `at` is a world position no matter where this node sits.
		s.top_level = true
		add_child(s)
		_sprites.append(s)
		_atlases.append(null)
		_state.append({"active": false, "age": 0.0, "life": 1.0,
			"kind": &"", "vel": Vector2.ZERO})


func _load_sheet(kind: StringName) -> Texture2D:
	var path: String = KINDS[kind]["sheet"]
	var res := load(path)
	if res is Texture2D:
		return res
	push_warning("Fx: sheet missing for %s, its particles will not draw: %s"
		% [String(kind), path])
	return null


func _emit(kind: StringName, cfg: Dictionary, origin: Vector2, spread: float) -> void:
	## Take a free slot, or recycle the oldest one when the pool is all live —
	## never a new node.
	var index := -1
	for i in _state.size():
		if not bool(_state[i].active):
			index = i
			break
	if index < 0:
		index = _next
		_next = (_next + 1) % POOL_SIZE
	var st: Dictionary = _state[index]
	st.active = true
	st.age = 0.0
	st.life = randf_range(float(cfg.life_min), float(cfg.life_max))
	st.kind = kind
	var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if dir.length_squared() < 0.01:
		dir = Vector2.UP
	var speed := float(cfg.speed) + randf_range(-spread, spread)
	st.vel = dir.normalized() * maxf(4.0, speed) + Vector2(0.0, float(cfg.rise))
	var s := _sprites[index]
	s.visible = true
	s.position = origin
	s.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var sheet: Texture2D = _sheets.get(kind, null)
	if sheet != null:
		var atlas: AtlasTexture = _atlases[index]
		if atlas == null:
			atlas = AtlasTexture.new()
			atlas.atlas = sheet
			_atlases[index] = atlas
		atlas.region = Rect2(0.0, 0.0, float(cfg.w), float(cfg.h))
		s.texture = atlas
	else:
		s.texture = null


func _process(delta: float) -> void:
	if not UserPreferences.can_animate():
		_kill_all()
		return
	for i in _state.size():
		var st: Dictionary = _state[i]
		if not bool(st.active):
			continue
		st.age = float(st.age) + delta
		var life := float(st.life)
		if float(st.age) >= life:
			st.active = false
			_sprites[i].visible = false
			continue
		var cfg: Dictionary = KINDS[st.kind]
		var vel: Vector2 = st.vel
		vel.y += float(cfg.gravity) * delta
		st.vel = vel
		var p: Vector2 = _sprites[i].position + vel * delta
		_sprites[i].position = Vector2(roundf(p.x), roundf(p.y))
		# Frame animation spread over the whole life, fade over the last 40%.
		var t := float(st.age) / life
		var frames := int(cfg.frames)
		var frame := mini(int(t * frames), frames - 1)
		var atlas: AtlasTexture = _atlases[i]
		if atlas != null:
			atlas.region = Rect2(frame * float(cfg.w), 0.0,
				float(cfg.w), float(cfg.h))
		_sprites[i].modulate.a = 1.0 - clampf((t - 0.6) / 0.4, 0.0, 1.0)


func _kill_all() -> void:
	## Reduce motion turned on mid-flight: everything stops and hides at once.
	for i in _state.size():
		_state[i].active = false
		_sprites[i].visible = false
