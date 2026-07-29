class_name ToastLayer
extends CanvasLayer
## Short notices that slide in under the readout board.

const MAX_VISIBLE := 3

var _stack: VBoxContainer


func _ready() -> void:
	layer = 8
	_stack = VBoxContainer.new()
	_stack.position = Vector2(10, 96)
	_stack.custom_minimum_size.x = PortLayout.WORLD_W - 20
	_stack.add_theme_constant_override(&"separation", 3)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)
	EventBus.toast.connect(show_toast)


func show_toast(text: String) -> void:
	while _stack.get_child_count() >= MAX_VISIBLE:
		var oldest := _stack.get_child(0)
		_stack.remove_child(oldest)
		oldest.queue_free()

	var panel := PanelContainer.new()
	UiTheme.apply_panel(panel, UiTheme.plate_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(UiTheme.icon(UiTheme.Icon.TEU))

	var label := UiTheme.label(text, UiTheme.SIZE_SMALL, UiTheme.PLATE_TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = PortLayout.WORLD_W - 60
	row.add_child(label)
	_stack.add_child(panel)

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_interval(3.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)
