class_name ToastLayer
extends CanvasLayer
## Renders one notice at a time, below the readout and the objective chip.
##
## This layer no longer decides anything: what is worth showing, how repeats
## collapse and how fast banners may follow each other all belong to
## NotificationCoordinator. Here there is only a slate chip that fades in,
## waits, fades out and reports that its slot is free again.

var _stack: VBoxContainer
var _active: PanelContainer
var _coordinator: NotificationCoordinator
var _safe_rect := Rect2()


func _ready() -> void:
	layer = 7
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override(&"separation", 3)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)
	get_viewport().size_changed.connect(_layout)
	_layout()


func setup(coordinator: NotificationCoordinator) -> void:
	if _coordinator != null and _coordinator.presented.is_connected(_present):
		_coordinator.presented.disconnect(_present)
	_coordinator = coordinator
	if _coordinator != null:
		_coordinator.presented.connect(_present)


func show_toast(text: String) -> void:
	_submit({"text": text})


func show_priority_toast(text: String, priority: int = 0) -> void:
	_submit({"text": text, "priority": priority})


func show_notification(payload: Dictionary) -> void:
	_submit(payload)


func _submit(payload: Dictionary) -> void:
	if _coordinator != null:
		_coordinator.submit(payload)
	else:
		EventBus.notification_requested.emit(payload)


func _present(notice: Dictionary) -> void:
	var text := str(notice.get("text", ""))
	if text.is_empty():
		_finish(null)
		return
	if _active != null and is_instance_valid(_active):
		_active.queue_free()

	var panel := UiTheme.panel(UiTheme.slate_style(true, 5))
	panel.modulate.a = 0.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(UiTheme.icon(notice.get("icon", UiTheme.Icon.TEU)))

	var count := int(notice.get("count", 1))
	var label := UiTheme.label(text if count <= 1 else "%s  x%d" % [text, count],
		UiTheme.SIZE_SMALL, UiTheme.SLATE_TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = maxf(80.0, _stack.custom_minimum_size.x - 40.0)
	row.add_child(label)
	_stack.add_child(panel)
	_active = panel

	if not UserPreferences.can_animate():
		panel.modulate.a = 1.0
		get_tree().create_timer(float(notice.get("duration", 3.2))).timeout.connect(
			_finish.bind(panel))
		return
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_interval(float(notice.get("duration", 3.2)))
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_finish.bind(panel))


func _finish(panel: Variant) -> void:
	if panel is PanelContainer and is_instance_valid(panel):
		(panel as PanelContainer).queue_free()
		if _active == panel:
			_active = null
	if _coordinator != null:
		_coordinator.notify_shown_finished()


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := _resolved_safe_rect(view)
	var width := minf(300.0, maxf(120.0, safe.size.x - 20.0))
	# Below the readout and the objective chip, so a notice never buries the
	# two things that are always true.
	_stack.position = Vector2(
		safe.position.x + (safe.size.x - width) * 0.5,
		safe.position.y + 112.0)
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
