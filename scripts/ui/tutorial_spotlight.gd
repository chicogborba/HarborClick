class_name TutorialSpotlight
extends CanvasLayer
## Seven data-driven harbour orientation steps. Target callbacks can return a
## Rect2, allowing the real control to remain interactive beneath the overlay.

signal step_changed(index: int, step: Dictionary)
signal finished(skipped: bool)

const STEPS := [
	{"id":"navio", "title":"spot.ship.title", "text":"spot.ship.text", "target":"ship"},
	{"id":"teu", "title":"spot.teu.title", "text":"spot.teu.text", "target":"teu"},
	{"id":"meta", "title":"spot.goal.title", "text":"spot.goal.text", "target":"objective"},
	{"id":"diario", "title":"spot.journal.title", "text":"spot.journal.text", "target":"journal"},
	{"id":"loja", "title":"spot.shop.title", "text":"spot.shop.text", "target":"shop"},
	{"id":"capital", "title":"spot.capital.title", "text":"spot.capital.text", "target":"prestige"},
	{"id":"rotas", "title":"spot.routes.title", "text":"spot.routes.text", "target":"routes"},
]

var _callbacks: Dictionary = {}
var _safe_rect := Rect2()
var _index := 0
var _active := false
var _veil: Control
var _panel: PanelContainer
var _title: Label
var _body: Label


func setup(manager_or_callbacks: Variant, callbacks: Dictionary = {}) -> void:
	_callbacks = manager_or_callbacks.duplicate() if manager_or_callbacks is Dictionary else callbacks.duplicate()


func _ready() -> void:
	layer = 20
	_veil = _SpotlightVeil.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.board_style(8))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	_panel.add_child(col)
	_title = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK)
	col.add_child(_title)
	_body = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Autowrap needs a real width before PanelContainer computes its minimum
	# height; otherwise a zero-width first pass wraps one glyph per line and can
	# turn this compact tutorial card into a full-height sheet.
	_body.custom_minimum_size = Vector2(280.0, 26.0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 4)
	col.add_child(actions)
	var skip := UiTheme.button("PULAR", &"ghost", UiTheme.SIZE_SMALL)
	skip.custom_minimum_size = Vector2(60, 26)
	skip.pressed.connect(func() -> void: _finish(true))
	actions.add_child(skip)
	var next_button := UiTheme.button(Loc.t("spot.next"), &"amber", UiTheme.SIZE_SMALL)
	next_button.custom_minimum_size.y = 26.0
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.pressed.connect(next)
	actions.add_child(next_button)
	visible = false


func start() -> void:
	_active = true
	_index = 0
	visible = true
	_show_step()


func replay() -> void: start()


func is_active() -> bool: return _active


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


func next() -> void:
	if not _active: return
	_index += 1
	if _index >= STEPS.size(): _finish(false)
	else: _show_step()


func _unhandled_input(event: InputEvent) -> void:
	if not _active: return
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		_finish(true)
	elif ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)) and not _target_rect().has_point(event.position):
		next()


func _show_step() -> void:
	var step: Dictionary = STEPS[_index]
	# The table holds keys, not sentences: resolving here means a language change
	# mid-tour reflows the card instead of leaving the tour in the language it
	# started in.
	_title.text = Loc.t(str(step.title))
	_body.text = Loc.t(str(step.text))
	_veil.cutout = _target_rect().grow(5.0)
	_veil.reduced_motion = _reduced_motion()
	_veil.queue_redraw()
	_layout()
	step_changed.emit(_index, step.duplicate(true))


func _target_rect() -> Rect2:
	var callback: Callable = _callbacks.get("get_target_rect", Callable())
	if callback.is_valid():
		var result: Variant = callback.call(str(STEPS[_index].get("target", "")))
		if result is Rect2: return result
	return Rect2()


func _reduced_motion() -> bool:
	var callback: Callable = _callbacks.get("reduced_motion", Callable())
	return bool(callback.call()) if callback.is_valid() else false


func _layout() -> void:
	if _panel == null or not is_instance_valid(_panel): return
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_panel.size = Vector2(minf(340.0, safe.size.x - 16.0), 96.0)
	var target := _target_rect() if _active else Rect2()
	var bottom_position := Vector2(
		safe.get_center().x - _panel.size.x * 0.5,
		safe.end.y - _panel.size.y - 10.0)
	var top_position := Vector2(bottom_position.x, safe.position.y + 10.0)
	var bottom_rect := Rect2(bottom_position, _panel.size)
	_panel.position = top_position if not target.size.is_zero_approx() \
		and bottom_rect.intersects(target.grow(8.0)) else bottom_position


func _finish(skipped: bool) -> void:
	_active = false
	visible = false
	finished.emit(skipped)


class _SpotlightVeil extends Control:
	var cutout := Rect2()
	var reduced_motion := false
	func _draw() -> void:
		var full := Rect2(Vector2.ZERO, size)
		var shade := Color(0.02, 0.02, 0.06, 0.72)
		if cutout.size == Vector2.ZERO:
			draw_rect(full, shade)
			return
		draw_rect(Rect2(full.position, Vector2(full.size.x, cutout.position.y)), shade)
		draw_rect(Rect2(Vector2(0, cutout.end.y), Vector2(full.size.x, maxf(0, full.end.y - cutout.end.y))), shade)
		draw_rect(Rect2(Vector2(0, cutout.position.y), Vector2(cutout.position.x, cutout.size.y)), shade)
		draw_rect(Rect2(Vector2(cutout.end.x, cutout.position.y), Vector2(maxf(0, full.end.x - cutout.end.x), cutout.size.y)), shade)
		draw_rect(cutout, UiTheme.TEAL, false, 2.0)
