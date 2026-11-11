class_name XrayButton
extends CanvasLayer
## The scanner's key: a little X-ray monitor in the HUD column under the wheel
## and the daily orders. Same steel key and rules as `WheelButton` — built
## once, rewritten in place, it bobs a pixel while something waits: the
## scanner affordable but not bought, or an inspection due (beacon lit, red
## "!" pinned to its corner).

signal pressed

const SIZE := 34.0
const BADGE := 24.0
const TEX_BADGE := preload("res://assets/sprites/ui_xray_badge.png")

var _service: XrayService
var _button: Button
var _badge_atlas: AtlasTexture
var _pill: PanelContainer
var _safe_rect := Rect2()
var _world_rect := Rect2()
var _home := Vector2.ZERO
## Which slot of the HUD column it sits in (0 = the wheel's): Main packs the
## column so a key still locked behind a level does not leave a hole.
var _slot := 2
var _tick := 0.0
var _bob := false
var _bob_up := false
var _bob_tick := 0.0


func _ready() -> void:
	layer = 6
	_button = UiTheme.button("", &"steel", UiTheme.SIZE_SMALL)
	_button.custom_minimum_size = Vector2(SIZE, SIZE)
	_button.size = Vector2(SIZE, SIZE)
	_badge_atlas = AtlasTexture.new()
	_badge_atlas.atlas = TEX_BADGE
	_badge_atlas.region = Rect2(0, 0, BADGE, BADGE)
	var badge := TextureRect.new()
	badge.texture = _badge_atlas
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_button.add_child(badge)
	UiTheme.describe(_button, Loc.t("xray.panel.title"))
	_button.pressed.connect(func() -> void:
		AudioManager.play_sfx("tap")
		pressed.emit())
	add_child(_button)
	_pill = UiTheme.count_pill(UiTheme.DANGER)
	(_pill.get_node(^"Value") as Label).text = "!"
	add_child(_pill)
	refresh()
	_layout()


func setup(service: XrayService) -> void:
	_service = service
	if _service != null and not _service.state_changed.is_connected(refresh):
		_service.state_changed.connect(refresh)
	refresh()


func set_slot(slot: int) -> void:
	if slot != _slot:
		_slot = slot
		_layout()


func button_rect() -> Rect2:
	return _button.get_global_rect() if visible and _button != null else Rect2()


func refresh() -> void:
	if _service == null or _pill == null:
		return
	var due := _service.is_due()
	_badge_atlas.region = Rect2(BADGE if due else 0.0, 0.0, BADGE, BADGE)
	_bob = due or _service.can_buy()
	if not _bob:
		_bob_up = false
	_pill.visible = due


func _process(delta: float) -> void:
	if not visible:
		return
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
	# The column the wheel and daily keys stand in: 40px a slot.
	var pos := area.position + Vector2(6.0, Hud.BAR_H + 30.0 + 40.0 * float(_slot))
	pos.x = clampf(pos.x, safe.position.x, safe.end.x - SIZE)
	pos.y = clampf(pos.y, safe.position.y, safe.end.y - SIZE)
	_home = pos.round()
	_button.size = Vector2(SIZE, SIZE)
	_button.position = _home + Vector2(0.0, -1.0 if _bob_up else 0.0)
	_pill.position = (_home + Vector2(SIZE - 10.0, -5.0)).round()
