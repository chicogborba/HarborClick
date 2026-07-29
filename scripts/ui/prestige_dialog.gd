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
var _scroll: ScrollContainer
var _viewport_clip: Control


func setup(manager_or_callbacks: Variant, callbacks: Dictionary = {}) -> void:
	_callbacks = manager_or_callbacks.duplicate() if manager_or_callbacks is Dictionary else callbacks.duplicate()


func _ready() -> void:
	layer = 13
	_backdrop = UiTheme.scrim(0.78)
	_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed): close())
	add_child(_backdrop)
	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.board_style(9))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 5)
	_panel.add_child(col)
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 5)
	header.custom_minimum_size.y = 24.0
	col.add_child(header)
	var star := UiTheme.icon(UiTheme.Icon.STAR)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(star)
	var title := UiTheme.label("RECONSTRUIR O PORTO", UiTheme.SIZE_BODY, UiTheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	var close_button := UiTheme.icon_button(UiTheme.Icon.CLOSE, &"ghost", 26.0)
	close_button.custom_minimum_size = Vector2(30, 24)
	close_button.tooltip_text = "Fechar (Esc)"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	_summary = UiTheme.label("Consulte a proposta de reconstrução.", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_summary)
	_confirm = UiTheme.button("VER PROPOSTA", &"amber", UiTheme.SIZE_SMALL)
	_confirm.custom_minimum_size.y = 28.0
	_confirm.pressed.connect(_confirm_or_quote)
	col.add_child(_confirm)
	var label := UiTheme.label("CAPITAL DO PORTO - 5 RAMOS", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	col.add_child(label)
	var sheet := UiTheme.panel(UiTheme.paper_style(4))
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sheet)
	# A plain Control does not propagate its children's minimum size. Without
	# this the twelve capital nodes made the dialog 778px tall on a 568px
	# phone, and a PanelContainer can never be shorter than its content — the
	# whole board slid off the top of the screen.
	_viewport_clip = Control.new()
	_viewport_clip.clip_contents = true
	_viewport_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.add_child(_viewport_clip)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.style_scroll(_scroll)
	_viewport_clip.add_child(_scroll)
	_tree = VBoxContainer.new()
	_tree.add_theme_constant_override(&"separation", 4)
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_tree)
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
		_summary.text = "Ganho: %s ações  -  Pico: %s  -  Desconto de reconstrução: %s" % [str(quote.get("gain", 0)), GameState.fmt(float(quote.get("peak", 0.0))), str(quote.get("rebuild_discount", "0%"))]
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
		var caption := UiTheme.label(str(branch.get("title", "Ramo")).to_upper(),
			UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
		_tree.add_child(caption)
		# One node per full-width row. Laying a branch out horizontally made the
		# four-node offline branch wider than the dialog, which pushed the whole
		# panel off screen because a PanelContainer can never be smaller than
		# its content.
		for node: Dictionary in branch.get("nodes", []):
			var row := HBoxContainer.new()
			row.add_theme_constant_override(&"separation", 4)
			_tree.add_child(row)
			var buy := UiTheme.button(_node_label(node), &"alt", UiTheme.SIZE_SMALL)
			buy.clip_text = true
			buy.tooltip_text = "%s - custa %d ação(ões) dourada(s)" \
				% [_node_label(node), int(node.get("cost", 0))]
			buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			buy.custom_minimum_size = Vector2(40, 26)
			buy.pressed.connect(_purchase.bind(StringName(node.get("id", ""))))
			row.add_child(buy)
			var price := UiTheme.stamp("%d" % int(node.get("cost", 0)),
				UiTheme.AMBER, UiTheme.SIZE_SMALL)
			price.custom_minimum_size.x = 30.0
			row.add_child(price)


func _node_label(node: Dictionary) -> String:
	## Branch nodes are declarative effects with no authored title, so the label
	## is derived from the effect itself and stays correct if the data changes.
	var effect: Dictionary = node.get("effect", {})
	var value := float(effect.get("value", 0.0))
	match StringName(effect.get("stat", "")):
		&"cps_multiplier": return "+%d%%" % roundi(value * 100.0)
		&"click_multiplier": return "+%d%% toque" % roundi(value * 100.0)
		&"cps_per_tap": return "toque +%d%%/s" % roundi(value * 100.0)
		&"offline_efficiency": return "offline %d%%" % roundi(value * 100.0)
		&"offline_cap_seconds": return "limite %dh" % roundi(value / 3600.0)
		&"route_reward_multiplier": return "rota +%d%%" % roundi(value * 100.0)
		&"route_slots": return "+%d rota" % roundi(value)
		&"event_reward_multiplier": return "evento +%d%%" % roundi(value * 100.0)
		&"event_duration_multiplier": return "evento +%d%% dur." % roundi(value * 100.0)
	return str(node.get("id", "no"))


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
	var wanted := Vector2(minf(400.0, safe.size.x - 16.0),
		minf(480.0, safe.size.y - 20.0))
	_panel.custom_minimum_size = wanted
	_panel.size = wanted
	if _summary != null:
		# Autowrap needs a real width before the column asks for its height.
		_summary.custom_minimum_size.x = wanted.x - 24.0
	if _tree != null:
		_tree.custom_minimum_size.x = wanted.x - 44.0
	_panel.position = safe.position + (safe.size - _panel.size) * 0.5
	_backdrop.visible = _open
	_panel.visible = _open
