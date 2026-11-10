class_name DailyOrdersButton
extends CanvasLayer
## The Missões do Dia key: a clipboard under the wheel's key, with a red count
## of rewards waiting to be claimed. Same steel key, same rules as WheelButton —
## built once, rewritten in place, it bobs a pixel (never scales) while
## something is claimable.

signal pressed

const SIZE := 44.0
const BADGE := 24.0
## Directly under the wheel's key: same column, one key and a gap lower.
const OFFSET := Vector2(6.0, Hud.BAR_H + 30.0 + 50.0)
const TEX_BADGE := preload("res://assets/sprites/ui_daily_badge.png")

var _service: DailyOrdersService
var _button: Button
var _badge_atlas: AtlasTexture
var _count: Label
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
	# Child TextureRect, centred — the Button's own icon slot pins to the top
	# of a 44px key (same fix as WheelButton).
	var badge := TextureRect.new()
	badge.name = "Badge"
	badge.texture = _badge_atlas
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_button.add_child(badge)
	UiTheme.describe(_button, Loc.t("daily.title"))
	_button.pressed.connect(func() -> void:
		AudioManager.play_sfx("tap")
		pressed.emit())
	add_child(_button)

	# Red, not amber: amber is the wheel's token count beside it, and "a reward
	# is waiting for you" is the one thing on the HUD allowed to shout.
	_count = UiTheme.label("", UiTheme.SIZE_SMALL, Color8(255, 236, 220))
	_count.label_settings = UiTheme.settings(UiTheme.SIZE_SMALL, Color8(255, 236, 220), 2)
	_count.label_settings.outline_color = UiTheme.DANGER
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.visible = false
	add_child(_count)
	refresh()
	_layout()


func setup(service: DailyOrdersService) -> void:
	_service = service
	if _service != null and not _service.state_changed.is_connected(refresh):
		_service.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _service == null or _service.orders == null or _count == null:
		return
	var waiting := _service.orders.claimable_count()
	_badge_atlas.region = Rect2(BADGE if waiting > 0 else 0.0, 0.0, BADGE, BADGE)
	_bob = waiting > 0
	if not _bob:
		_bob_up = false
	_count.text = str(waiting)
	_count.visible = waiting > 0


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
	var area := safe
	if _world_rect.size.x > 0.0 and _world_rect.size.y > 0.0:
		var inside := _world_rect.intersection(safe)
		if inside.size.x > 0.0 and inside.size.y > 0.0:
			area = inside
	var pos := area.position + OFFSET
	pos.x = clampf(pos.x, safe.position.x, safe.end.x - SIZE)
	pos.y = clampf(pos.y, safe.position.y, safe.end.y - SIZE)
	_home = pos.round()
	_button.size = Vector2(SIZE, SIZE)
	_button.position = _home + Vector2(0.0, -1.0 if _bob_up else 0.0)
	_count.position = (_home + Vector2(SIZE - 8.0, -4.0)).round()
