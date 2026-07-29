class_name ToastLayer
extends CanvasLayer
## Short notices that slide in under the readout board.

var _stack: VBoxContainer
var _active: PanelContainer
var _queue: Array[Dictionary] = []
var _last_started_at := -1.0
var _safe_rect := Rect2()


func _ready() -> void:
	layer = 7
	_stack = VBoxContainer.new()
	_stack.position = Vector2(10, 60)
	_stack.add_theme_constant_override(&"separation", 3)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)
	get_viewport().size_changed.connect(_layout)
	EventBus.toast.connect(show_toast)
	EventBus.notification_requested.connect(show_notification)
	_layout()


func show_toast(text: String) -> void:
	_enqueue(text)


func show_priority_toast(text: String, priority: int = 0) -> void:
	_enqueue(text, priority)


func show_notification(payload: Dictionary) -> void:
	var text := str(payload.get("text", ""))
	if text.is_empty():
		return
	_enqueue(text, int(payload.get("priority", 0)))


func _enqueue(text: String, priority: int = 0) -> void:
	var entry := {"text": text, "priority": priority}
	if priority > 0:
		_queue.push_front(entry)
	else:
		_queue.append(entry)
	_try_show_next()


func _try_show_next() -> void:
	if _active != null and is_instance_valid(_active):
		return
	if _queue.is_empty() or Time.get_ticks_msec() * 0.001 - _last_started_at < 1.0:
		return
	var entry: Dictionary = _queue.pop_front()
	_last_started_at = Time.get_ticks_msec() * 0.001
	var text := str(entry.text)

	var panel := PanelContainer.new()
	UiTheme.apply_panel(panel, UiTheme.dark_panel(6, UiTheme.TEAL))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(UiTheme.icon(UiTheme.Icon.TEU))

	var label := UiTheme.label(text, UiTheme.SIZE_SMALL, UiTheme.PLATE_TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = maxf(80.0, _stack.custom_minimum_size.x - 40.0)
	row.add_child(label)
	_stack.add_child(panel)
	_active = panel

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_interval(3.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free()
		if _active == panel:
			_active = null
		_try_show_next())


func _process(_delta: float) -> void:
	_try_show_next()


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := _resolved_safe_rect(view)
	var width := minf(300.0, maxf(120.0, safe.size.x - 20.0))
	_stack.position = Vector2(
		safe.position.x + (safe.size.x - width) * 0.5,
		safe.position.y + 60.0)
	_stack.custom_minimum_size.x = width


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get(
		"safe_rect", Rect2(Vector2.ZERO, view))
	_layout()


func _resolved_safe_rect(view: Vector2) -> Rect2:
	var viewport_rect := Rect2(Vector2.ZERO, view)
	if _safe_rect.size.x <= 0.0 or _safe_rect.size.y <= 0.0:
		return viewport_rect
	var clipped := _safe_rect.intersection(viewport_rect)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 \
		else viewport_rect
