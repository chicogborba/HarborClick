class_name RateBreakdown
extends CanvasLayer
## Why the rate is what it is: the factors, in the order the economy applies them.
##
## `+25%` of a base nobody knows is superstition, not strategy. The counter shows
## the product of six or seven multipliers and the player has no way to tell
## which one moved, so a purchase reads as "a number changed somewhere". This is
## the formula itself: machines at catalogue rate, then every multiplier stacked
## on top, then the total the counter is showing.

signal open_changed(opened: bool)

const MAX_WIDTH := 300.0

var _dim: ColorRect
var _panel: PanelContainer
var _rows: VBoxContainer
var _total: Label
var _safe_rect := Rect2()
var _open := false
var _focus_return: Control


func _ready() -> void:
	layer = 11
	_build()
	visible = false
	get_viewport().size_changed.connect(_layout)


func _build() -> void:
	_dim = UiTheme.scrim(0.62)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(_dim)

	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.board_style(10))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	_panel.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 4)
	col.add_child(header)
	var title := UiTheme.label("DE ONDE VEM A TAXA", UiTheme.SIZE_BODY, UiTheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := UiTheme.button("X", &"ghost", UiTheme.SIZE_SMALL)
	close_button.custom_minimum_size = Vector2(26, 22)
	close_button.tooltip_text = "Fechar (Esc)"
	close_button.accessibility_name = "Fechar"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 2)
	col.add_child(_rows)

	col.add_child(UiTheme.divider())
	_total = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_total)


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_focus_return = get_viewport().gui_get_focus_owner()
	_refresh()
	_open = true
	visible = true
	_layout()
	open_changed.emit(true)


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if _focus_return != null and is_instance_valid(_focus_return):
		_focus_return.grab_focus()
	open_changed.emit(false)


func _unhandled_key_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	for entry in GameState.cps_breakdown():
		_rows.add_child(_row(String(entry.label), _value_text(entry)))
	_total.text = "= %s TEU/s" % GameState.fmt(GameState.cps)


static func _value_text(entry: Dictionary) -> String:
	var value := float(entry.get("value", 0.0))
	if String(entry.get("kind", "mult")) == "base":
		return "%s TEU/s" % GameState.fmt(value)
	# Two decimals below ten: a "x1" where the real factor is 1.4 is the same lie
	# the panel exists to stop telling.
	return "x%.2f" % value if value < 10.0 else "x%s" % GameState.fmt(value)


func _row(name_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	var label := UiTheme.label(name_text, UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := UiTheme.label(value_text, UiTheme.SIZE_SMALL, UiTheme.INK)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return row


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect", Rect2())
	_layout()


func _layout() -> void:
	if _panel == null:
		return
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	# Fixed on both axes, like every other board here: a panel that asks for its
	# own height depends on Godot's deferred minimum-size pass and can draw one
	# frame at the wrong size.
	var wanted := Vector2(minf(MAX_WIDTH, safe.size.x - 24.0),
		minf(240.0, safe.size.y - 24.0))
	_panel.custom_minimum_size = wanted
	_panel.size = wanted
	_panel.position = safe.position + (safe.size - wanted) * 0.5
