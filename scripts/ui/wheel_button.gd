class_name WheelButton
extends CanvasLayer
## The Roda da Sorte's key: a small steel key under the gantry's left end, with
## the wheel badge on its face and a token count pinned to its corner.
##
## The badge frame itself says whether a free spin is waiting (frame 1 = bulbs
## lit), and while it is waiting the whole key bobs a pixel — position only,
## never a scale, so the pixel art stays crisp.

signal pressed

## 44: the smallest target a thumb hits reliably. The badge stays 24.
const SIZE := 44.0
const BADGE := 24.0
const TEX_BADGE := preload("res://assets/sprites/ui_wheel_badge.png")

var _service: WheelService
var _button: Button
var _badge_atlas: AtlasTexture
var _token_badge: Label
var _token_pill: PanelContainer
var _safe_rect := Rect2()
var _world_rect := Rect2()
var _home := Vector2.ZERO
var _tick := 0.0
var _bob := false
var _bob_up := false
var _bob_tick := 0.0


func _ready() -> void:
	layer = 6
	_button = UiTheme.button("", &"steel", UiTheme.SIZE_SMALL)
	_button.custom_minimum_size = Vector2(SIZE, SIZE)
	_button.size = Vector2(SIZE, SIZE)
	_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button.expand_icon = false
	_badge_atlas = AtlasTexture.new()
	_badge_atlas.atlas = TEX_BADGE
	_badge_atlas.region = Rect2(0, 0, BADGE, BADGE)
	# The badge rides as a child TextureRect, not as the Button's own icon:
	# the built-in icon slot pins to the top of a 44px key, leaving the badge
	# floating high with dead steel under it.
	var badge := TextureRect.new()
	badge.name = "Badge"
	badge.texture = _badge_atlas
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_button.add_child(badge)
	UiTheme.describe(_button, Loc.t("wheel.title"))
	_button.tooltip_text = Loc.t("wheel.title")
	_button.pressed.connect(_on_pressed)
	add_child(_button)

	_token_pill = UiTheme.count_pill(UiTheme.AMBER, UiTheme.INK)
	_token_badge = _token_pill.get_node(^"Value")
	add_child(_token_pill)
	refresh()
	_layout()


func setup(service: WheelService) -> void:
	_service = service
	if _service != null and not _service.state_changed.is_connected(refresh):
		_service.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	## Rewrites the badge frame and the token count in place. Called on
	## state_changed and once per second; never rebuilds anything.
	if _service == null or _service.wheel == null or _token_badge == null:
		return
	var wheel := _service.wheel
	var free := wheel.free_spin_ready(Time.get_unix_time_from_system())
	_badge_atlas.region = Rect2(BADGE if free else 0.0, 0.0, BADGE, BADGE)
	_bob = free
	if not _bob:
		_bob_up = false
	_token_badge.text = str(wheel.tokens)
	_token_pill.visible = wheel.tokens > 0


func _on_pressed() -> void:
	AudioManager.play_sfx("tap")
	pressed.emit()


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		refresh()
	if _bob and UserPreferences.can_animate():
		_bob_tick += delta
		if _bob_tick >= 0.4:
			_bob_tick = 0.0
			_bob_up = not _bob_up
	elif _bob_up:
		_bob_up = false
	_button.position = _home + Vector2(0.0, -1.0 if _bob_up else 0.0)


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, view))
	_world_rect = metrics.get("world_rect", _safe_rect)
	_layout()


func _layout() -> void:
	if _button == null or not is_instance_valid(_button):
		return
	var view := get_viewport().get_visible_rect().size
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, view)
	var area := _resolved_world_rect(view, safe)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		area = safe
	# Under the gantry's left end, on the world rect resolved inside the safe
	# area, and clamped so an inset world can never push the key off screen.
	var pos := area.position + Vector2(6.0, Hud.BAR_H + 30.0)
	pos.x = clampf(pos.x, safe.position.x, safe.end.x - SIZE)
	pos.y = clampf(pos.y, safe.position.y, safe.end.y - SIZE)
	_home = pos
	_button.size = Vector2(SIZE, SIZE)
	_button.position = pos + Vector2(0.0, -1.0 if _bob_up else 0.0)
	_token_pill.position = (pos + Vector2(SIZE - 10.0, -5.0)).round()


func _resolved_world_rect(view: Vector2, safe: Rect2) -> Rect2:
	## Same rule the gantry uses: the key belongs to the port, not the window,
	## so the world rect is resolved inside the safe area before placing it.
	var viewport_rect := Rect2(Vector2.ZERO, view)
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		safe = viewport_rect
	if _world_rect.size.x <= 0.0 or _world_rect.size.y <= 0.0:
		return safe
	var world := _world_rect.intersection(safe)
	return world if world.size.x > 0.0 and world.size.y > 0.0 else safe
