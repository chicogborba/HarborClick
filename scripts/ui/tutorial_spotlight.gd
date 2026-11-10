class_name TutorialSpotlight
extends CanvasLayer
## The first minute, as four things to *do* rather than seven things to read.
##
## The tour used to be seven cards you tapped through, pointing at keys a new
## terminal does not have yet and — on the very first card — at an empty patch of
## water, because the ship was still coming in. Now every step but the two
## explanations waits for the player to do what it says: tap the ship fifteen
## times (the first card does not appear until a ship is actually alongside),
## open the shop and buy a docker. Target callbacks can return a Rect2, allowing
## the real control to remain interactive beneath the overlay.

signal step_changed(index: int, step: Dictionary)
signal finished(skipped: bool)

## `until`: "taps" waits for `goal` paid taps, "buy" for a machine purchase, "ok"
## for a tap on the card. `wait` names a callback that must answer true before
## the step is shown at all.
const STEPS := [
	{"id": "navio", "title": "spot.ship.title", "text": "spot.ship.text2",
		"target": "ship", "until": "taps", "goal": 15, "wait": "ship_ready"},
	{"id": "teu", "title": "spot.teu.title", "text": "spot.teu.text2",
		"target": "teu", "until": "ok"},
	{"id": "loja", "title": "spot.shop.title2", "text": "spot.shop.text2",
		"target": "shop", "until": "buy"},
	{"id": "fim", "title": "spot.done.title", "text": "spot.done.text",
		"target": "", "until": "ok"},
]

var _callbacks: Dictionary = {}
var _safe_rect := Rect2()
var _index := 0
var _active := false
var _veil: Control
var _panel: PanelContainer
var _title: Label
var _body: Label
var _hint: Label
var _skip: Button
var _taps := 0
var _waiting := false


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
	_hint = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	_hint.clip_text = true
	col.add_child(_hint)
	EventBus.manual_reward_committed.connect(_on_tap_paid)
	EventBus.structure_purchase_committed.connect(_on_purchase)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 4)
	col.add_child(actions)
	_skip = UiTheme.button(Loc.t("spot.skip"), &"ghost", UiTheme.SIZE_SMALL)
	_skip.custom_minimum_size = Vector2(60, 26)
	_skip.pressed.connect(func() -> void: _finish(true))
	actions.add_child(_skip)
	var next_button := UiTheme.button(Loc.t("spot.next"), &"amber", UiTheme.SIZE_SMALL)
	next_button.custom_minimum_size.y = 26.0
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.pressed.connect(next)
	actions.add_child(next_button)
	visible = false


func start() -> void:
	_active = true
	_index = 0
	_taps = 0
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
	_taps = 0
	if _index >= STEPS.size(): _finish(false)
	else: _show_step()


func _until() -> String:
	return str(STEPS[_index].get("until", "ok"))


func _on_tap_paid(_payload: Dictionary) -> void:
	if not _active or _waiting or _until() != "taps":
		return
	_taps += 1
	var goal := int(STEPS[_index].get("goal", 1))
	if _taps >= goal:
		next()
	else:
		_hint.text = Loc.t("spot.hint.tap", {"n": str(_taps), "goal": str(goal)})


func _on_purchase(_quote: Dictionary) -> void:
	if _active and _until() == "buy":
		next()


func _process(_delta: float) -> void:
	## The first step does not exist until there is a ship to tap.
	if not _active or not _waiting:
		return
	var ready: Callable = _callbacks.get(str(STEPS[_index].get("wait", "")), Callable())
	if not ready.is_valid() or bool(ready.call()):
		_waiting = false
		_show_step()


func _unhandled_input(event: InputEvent) -> void:
	if not _active: return
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		_finish(true)
	elif _until() == "ok" and not _waiting \
			and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)) \
			and not _target_rect().has_point(event.position):
		next()


func _show_step() -> void:
	Telemetry.track(&"tutorial_step", {"index": _index})
	var step: Dictionary = STEPS[_index]
	# The table holds keys, not sentences: resolving here means a language change
	# mid-tour reflows the card instead of leaving the tour in the language it
	# started in.
	var wait_cb: Callable = _callbacks.get(str(step.get("wait", "")), Callable())
	_waiting = wait_cb.is_valid() and not bool(wait_cb.call())
	_title.text = Loc.t(str(step.title))
	_body.text = Loc.t("spot.wait.text") if _waiting else Loc.t(str(step.text))
	match str(step.get("until", "ok")):
		"taps":
			_hint.text = "" if _waiting else Loc.t("spot.hint.tap",
				{"n": str(_taps), "goal": str(int(step.goal))})
		"buy":
			_hint.text = Loc.t("spot.hint.buy")
		_:
			_hint.text = Loc.t("spot.hint.ok")
	# Nobody skips the first thing the game asks of them.
	_skip.visible = _index > 0
	_veil.cutout = _target_rect().grow(5.0) if not _waiting else Rect2()
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
	Telemetry.track(&"tutorial_finished", {"skipped": skipped})
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
