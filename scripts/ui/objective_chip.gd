class_name ObjectiveChip
extends CanvasLayer
## Compact objective launcher. Its data source is injected so it can be used in
## previews and tests without the progression autoload being present.

signal journal_requested

var _source: Variant
var _callbacks: Dictionary = {}
var _safe_rect := Rect2()
var _panel: PanelContainer
var _title: Label
var _progress: Label
var _desktop := false


func setup(manager_or_callbacks: Variant, callbacks: Dictionary = {}) -> void:
	_source = manager_or_callbacks
	_callbacks = callbacks.duplicate()
	_refresh()


func _ready() -> void:
	layer = 7
	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.slate_style(true, 5))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(func() -> void: journal_requested.emit())
	_panel.add_child(button)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	_panel.add_child(row)
	row.add_child(UiTheme.icon(UiTheme.Icon.STAR))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	_title = UiTheme.label("PRÓXIMA META", UiTheme.SIZE_SMALL, UiTheme.SLATE_TEXT)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(_title)
	_progress = UiTheme.label("Abra o diário", UiTheme.SIZE_SMALL, UiTheme.AMBER)
	_progress.clip_text = true
	text.add_child(_progress)
	var chevron := UiTheme.icon(UiTheme.Icon.CHEVRON)
	chevron.modulate = UiTheme.SLATE_DIM
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chevron)
	_layout()
	_refresh()


func refresh() -> void:
	_refresh()


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	# On a wide screen the command rail carries the objective; a second copy
	# floating over the port would just be clutter beside it.
	_desktop = str(metrics.get("profile", "")) == "desktop"
	_layout()


func _refresh() -> void:
	if not is_instance_valid(_title):
		return
	var objective := _objective()
	if objective.is_empty():
		_title.text = "PRÓXIMA META"
		_progress.text = "Abra o diário"
		return
	var pinned := bool(objective.get("pinned", false))
	_title.text = ("FIXADA: " if pinned else "RECOMENDADA: ") + str(objective.get("title", "Meta"))
	_progress.text = "%s / %s" % [_fmt(float(objective.get("progress", 0.0))), _fmt(float(objective.get("target", 0.0)))]


func _objective() -> Dictionary:
	var getter: Callable = _callbacks.get("get_objective", Callable())
	if getter.is_valid():
		var value: Variant = getter.call()
		return value.duplicate(true) if value is Dictionary else {}
	if _source != null and _source.has_method("get_pinned_objective"):
		var pinned: Dictionary = _source.get_pinned_objective()
		if not pinned.is_empty():
			pinned["pinned"] = true
			return pinned
	if _callbacks.has("get_recommended") and _callbacks["get_recommended"] is Callable:
		var recommended: Variant = _callbacks["get_recommended"].call()
		return recommended.duplicate(true) if recommended is Dictionary else {}
	return {}


func _layout() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	var safe := _safe_rect
	if safe.size == Vector2.ZERO:
		safe = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	# Nothing permanent floats over the port any more. The rail carries the
	# objective on a wide screen; in portrait the DIÁRIO key is right there and
	# a banner sitting on the quay all session was covering the game.
	_panel.visible = false
	_panel.size = Vector2(minf(220.0, safe.size.x - 16.0), 34.0)
	_panel.position = Vector2(safe.position.x + 8.0, safe.position.y + 72.0)


func _fmt(value: float) -> String:
	## Career targets reach the billions; the chip is 220px wide. Raw digits
	## ("3180843 / 100000000") never fit and cannot be read at a glance.
	if Engine.has_singleton("GameState") or GameState != null:
		return GameState.fmt(value)
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
