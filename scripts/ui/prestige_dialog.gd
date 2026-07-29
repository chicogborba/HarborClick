class_name PrestigeDialog
extends CanvasLayer
## All state-changing work remains in the supplied callbacks. This surface only
## asks for a quote, confirms it explicitly, and renders the five career lanes.

signal open_changed(opened: bool)
signal prestige_confirmed(quote: Dictionary)
signal node_purchase_requested(id: StringName)

var _callbacks: Dictionary = {}
var _safe_rect := Rect2()
var _open := false
var _quoted := false
var _backdrop: ColorRect
var _panel: PanelContainer
var _summary: Label
var _confirm: Button
var _tree: VBoxContainer


func setup(manager_or_callbacks: Variant, callbacks: Dictionary = {}) -> void:
	_callbacks = manager_or_callbacks.duplicate() if manager_or_callbacks is Dictionary else callbacks.duplicate()


func _ready() -> void:
	layer = 13
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.03, 0.025, 0.07, 0.76)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed): close())
	add_child(_backdrop)
	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.dark_panel(10, UiTheme.AMBER))
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 5)
	_panel.add_child(col)
	var header := HBoxContainer.new()
	col.add_child(header)
	var title := UiTheme.label("RECONSTRUIR O PORTO", UiTheme.SIZE_BODY, UiTheme.CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := UiTheme.button("X", "off", UiTheme.SIZE_TITLE)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	_summary = UiTheme.label("Consulte a proposta de reconstrução.", UiTheme.SIZE_SMALL, UiTheme.PLATE_TEXT)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_summary)
	_confirm = UiTheme.button("VER PROPOSTA", "amber", UiTheme.SIZE_SMALL)
	_confirm.pressed.connect(_confirm_or_quote)
	col.add_child(_confirm)
	var label := UiTheme.label("CAPITAL DO PORTO — 5 RAMOS", UiTheme.SIZE_SMALL, UiTheme.TEAL)
	col.add_child(label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_tree = VBoxContainer.new()
	_tree.add_theme_constant_override(&"separation", 4)
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tree)
	_build_tree()
	_layout()


func open() -> void:
	_open = true
	_quoted = false
	_summary.text = "Consulte a proposta antes de confirmar a reconstrução."
	_confirm.text = "VER PROPOSTA"
	_layout()
	open_changed.emit(true)


func close() -> void:
	if not _open: return
	_open = false
	_layout()
	open_changed.emit(false)


func is_open() -> bool: return _open


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


func _unhandled_key_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		close()


func _confirm_or_quote() -> void:
	if not _quoted:
		var quote: Dictionary = _call("quote", {})
		_summary.text = "Ganho: %s  •  Pico: %s  •  Desconto de reconstrução: %s" % [str(quote.get("gain", 0)), str(quote.get("peak", 0)), str(quote.get("rebuild_discount", "0%"))]
		_confirm.text = "CONFIRMAR RECONSTRUÇÃO"
		_quoted = true
		return
	var committed: Variant = _call("commit", {})
	if not (committed is bool and not committed):
		prestige_confirmed.emit(committed if committed is Dictionary else {})
		close()


func _build_tree() -> void:
	if _tree == null: return
	for branch: Dictionary in PrestigeDB.BRANCHES:
		var row := HBoxContainer.new()
		_tree.add_child(row)
		var title := UiTheme.label(str(branch.get("title", "Ramo")), UiTheme.SIZE_SMALL, UiTheme.CREAM)
		title.custom_minimum_size.x = 58.0
		row.add_child(title)
		for node: Dictionary in branch.get("nodes", []):
			var buy := UiTheme.button(str(node.get("cost", 0)), "alt", UiTheme.SIZE_SMALL)
			buy.tooltip_text = str(node.get("id", ""))
			buy.custom_minimum_size = Vector2(34, 28)
			buy.pressed.connect(_purchase.bind(StringName(node.get("id", ""))))
			row.add_child(buy)


func _purchase(id: StringName) -> void:
	if id.is_empty(): return
	var callback: Callable = _callbacks.get("purchase_node", Callable())
	if callback.is_valid():
		callback.call(id)
	node_purchase_requested.emit(id)


func _call(callback_name: String, fallback: Variant) -> Variant:
	var callback: Callable = _callbacks.get(callback_name, Callable())
	return callback.call() if callback.is_valid() else fallback


func _layout() -> void:
	if _panel == null or not is_instance_valid(_panel): return
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_panel.size = Vector2(minf(440.0, safe.size.x - 16.0), minf(480.0, safe.size.y - 20.0))
	_panel.position = safe.position + (safe.size - _panel.size) * 0.5
	_backdrop.visible = _open
	_panel.visible = _open
