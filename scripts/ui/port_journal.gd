class_name PortJournal
extends CanvasLayer
## The objective board. The optional callbacks are deliberately tiny adapters:
## get_objectives() -> Array[Dictionary], pin(id) -> bool.

signal open_changed(opened: bool)
signal objective_pinned(id: StringName)
signal contract_accepted(id: StringName)

const TABS := [["next", "PRÓXIMAS"], ["all", "TODAS"], ["done", "CONCLUÍDAS"]]

var _source: Variant
var _callbacks: Dictionary = {}
var _safe_rect := Rect2()
var _profile := ""
var _open := false
var _active_tab := "next"
var _backdrop: ColorRect
var _sheet: PanelContainer
var _list: VBoxContainer
var _tab_buttons: Dictionary = {}


func setup(manager_or_callbacks: Variant, callbacks: Dictionary = {}) -> void:
	_source = manager_or_callbacks
	_callbacks = callbacks.duplicate()
	_refresh()


func _ready() -> void:
	layer = 12
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.03, 0.025, 0.07, 0.72)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)
	_sheet = PanelContainer.new()
	UiTheme.apply_panel(_sheet, UiTheme.dark_panel(10, UiTheme.TEAL))
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 5)
	_sheet.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := UiTheme.label("DIÁRIO DO PORTO", UiTheme.SIZE_BODY, UiTheme.CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := UiTheme.button("X", "off", UiTheme.SIZE_TITLE)
	close_button.custom_minimum_size = Vector2(32, 28)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 3)
	column.add_child(tabs)
	for tab: Array in TABS:
		var button := UiTheme.button(tab[1], "alt", UiTheme.SIZE_SMALL)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_tab.bind(tab[0]))
		tabs.add_child(button)
		_tab_buttons[tab[0]] = button
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 4)
	scroll.add_child(_list)
	_layout()
	_refresh()


func open(tab := "next") -> void:
	_active_tab = tab if TABS.any(func(entry: Array) -> bool: return entry[0] == tab) else "next"
	_open = true
	_refresh()
	_layout()
	open_changed.emit(true)


func close() -> void:
	if not _open:
		return
	_open = false
	_layout()
	open_changed.emit(false)


func is_open() -> bool:
	return _open


func refresh() -> void:
	_refresh()


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_profile = str(metrics.get("profile", ""))
	_layout()


func _unhandled_key_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		close()
		get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		close()


func _select_tab(tab: String) -> void:
	_active_tab = tab
	_refresh()


func _refresh() -> void:
	if _list == null or not is_instance_valid(_list):
		return
	for child in _list.get_children():
		child.queue_free()
	for key in _tab_buttons:
		_tab_buttons[key].modulate = Color.WHITE if key == _active_tab else Color(0.7, 0.67, 0.78)
	if _active_tab == "next":
		var contract := _contract()
		if not contract.is_empty():
			_list.add_child(_make_contract_card(contract))
	var objectives := _objectives()
	for objective: Dictionary in objectives:
		var done := bool(objective.get("complete", false))
		if (_active_tab == "done" and not done) or (_active_tab == "next" and done):
			continue
		_list.add_child(_make_card(objective))
	if _list.get_child_count() == 0:
		_list.add_child(UiTheme.label("Nenhuma meta nesta página.", UiTheme.SIZE_SMALL, UiTheme.PLATE_TEXT))


func _contract() -> Dictionary:
	var getter: Callable = _callbacks.get("get_contract", Callable())
	if getter.is_valid():
		var supplied: Variant = getter.call()
		return supplied.duplicate(true) if supplied is Dictionary else {}
	if _source != null and _source.has_method("get_active_contract"):
		return _source.get_active_contract()
	return {}


func _objectives() -> Array:
	var getter: Callable = _callbacks.get("get_objectives", Callable())
	if getter.is_valid():
		var supplied: Variant = getter.call()
		return supplied if supplied is Array else []
	if _source != null and _source.has_method("get_pinned_objective"):
		var pinned: Dictionary = _source.get_pinned_objective()
		return [pinned] if not pinned.is_empty() else []
	return []


func _make_card(objective: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.y = 44.0
	UiTheme.apply_panel(card, UiTheme.dark_panel(5, UiTheme.TEAL if bool(objective.get("pinned", false)) else Color8(82, 71, 103)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	card.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UiTheme.label(str(objective.get("title", "Meta de operação")), UiTheme.SIZE_SMALL, UiTheme.CREAM))
	var progress := float(objective.get("progress", 0.0))
	var target := float(objective.get("target", 0.0))
	var reward: Variant = objective.get("reward", {})
	text.add_child(UiTheme.label("%d / %d  •  %s" % [int(progress), int(target), _reward_text(reward)], UiTheme.SIZE_SMALL, UiTheme.AMBER))
	var pin := UiTheme.button("FIXAR" if not bool(objective.get("pinned", false)) else "FIXADA", "off", UiTheme.SIZE_SMALL)
	pin.custom_minimum_size = Vector2(48, 30)
	pin.disabled = bool(objective.get("pinned", false))
	pin.pressed.connect(_pin.bind(StringName(objective.get("id", ""))))
	row.add_child(pin)
	return card


func _make_contract_card(contract: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.y = 54.0
	UiTheme.apply_panel(card, UiTheme.dark_panel(5, UiTheme.AMBER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	card.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UiTheme.label("CONTRATO: " + str(contract.get("title", "Turno")), UiTheme.SIZE_SMALL, UiTheme.CREAM))
	var active := StringName(contract.get("status", &"offered")) == &"active"
	var progress := float(contract.get("progress", 0.0))
	var target := float(contract.get("target", 0.0))
	var reward: Dictionary = contract.get("reward", {})
	var detail := "%d / %d  •  +%s TEU" % [int(progress), int(target), _compact_number(float(reward.get("amount", 0.0)))]
	if active:
		var elapsed := float(contract.get("active_elapsed", 0.0))
		var duration := float(contract.get("active_duration", 0.0))
		var remaining_seconds := int(maxf(0.0, duration - elapsed))
		detail += "  •  %d:%02d" % [int(remaining_seconds / 60.0), remaining_seconds % 60]
	text.add_child(UiTheme.label(detail, UiTheme.SIZE_SMALL, UiTheme.AMBER))
	var action := UiTheme.button("ATIVO" if active else "ACEITAR", "off" if active else "amber", UiTheme.SIZE_SMALL)
	action.custom_minimum_size = Vector2(58, 30)
	action.disabled = active
	if not active:
		action.pressed.connect(_accept_contract.bind(contract.duplicate(true)))
	row.add_child(action)
	return card


func _pin(id: StringName) -> void:
	if id.is_empty():
		return
	var pin_callback: Callable = _callbacks.get("pin", Callable())
	if pin_callback.is_valid():
		pin_callback.call(id)
	elif _source != null and _source.has_method("pin_objective"):
		_source.pin_objective(id)
	objective_pinned.emit(id)
	_refresh()


func _accept_contract(contract: Dictionary) -> void:
	var accept_callback: Callable = _callbacks.get("accept_contract", Callable())
	var accepted := false
	if accept_callback.is_valid():
		accepted = bool(accept_callback.call(contract))
	elif _source != null and _source.has_method("accept_contract"):
		accepted = bool(_source.accept_contract(contract))
	if accepted:
		contract_accepted.emit(StringName(contract.get("id", "")))
	_refresh()


func _reward_text(reward: Variant) -> String:
	if reward is Dictionary and not reward.is_empty():
		return "recompensa: " + str(reward.values()[0])
	return "recompensa pendente"


func _compact_number(value: float) -> String:
	return str(int(value)) if value < 1000.0 else "%.1fK" % (value / 1000.0)


func _layout() -> void:
	if _sheet == null or not is_instance_valid(_sheet):
		return
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var desktop := _profile == "desktop" or (_profile.is_empty() and safe.size.x >= 700.0)
	if desktop:
		_sheet.size = Vector2(clampf(safe.size.x * 0.34, 280.0, 390.0), safe.size.y - 16.0)
		_sheet.position = Vector2(safe.end.x - _sheet.size.x - 8.0, safe.position.y + 8.0)
	else:
		_sheet.size = Vector2(safe.size.x - 12.0, maxf(220.0, safe.size.y - 20.0))
		_sheet.position = Vector2(safe.position.x + 6.0, safe.end.y - _sheet.size.y - 6.0)
	_backdrop.visible = _open
	_sheet.visible = _open
