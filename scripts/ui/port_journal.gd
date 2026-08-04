class_name PortJournal
extends CanvasLayer
## The career board. The optional callbacks are deliberately tiny adapters:
## get_objectives() -> Array[Dictionary], pin(id) -> bool.
##
## Contracts used to live here as a card at the top of the "next" tab, and they
## were the worst thing on it: a quiet counter you had to remember to come and
## look at, sitting above the goals it had nothing to do with. Charters are events
## now — see `SpecialCallAlert` and `CraneMinigame`. This board is goals only.
##
## The first version printed `245413 / 1000000` and, next to it, the literal
## contents of the reward dictionary — the player read "recompensa: cosmetic".
## Every row now carries a filled bar, formatted numbers and reward text
## written for a person, and a completed goal is marked with a tick instead of
## quietly looking like every other row.

signal open_changed(opened: bool)
signal objective_pinned(id: StringName)

const TABS := [["next", "PRÓXIMAS"], ["all", "TODAS"], ["done", "CONCLUÍDAS"],
	["crew", "EQUIPE"]]

var _source: Variant
var _callbacks: Dictionary = {}
var _safe_rect := Rect2()
var _profile := ""
var _open := false
var _active_tab := "next"
var _backdrop: ColorRect
var _sheet: PanelContainer
var _clip: TextureRect
var _list: VBoxContainer
var _tab_buttons: Dictionary = {}
var _focus_return: Control
var _rail: CommandRail


func setup(manager_or_callbacks: Variant, callbacks: Dictionary = {}) -> void:
	_source = manager_or_callbacks
	_callbacks = callbacks.duplicate()
	_refresh()


func _ready() -> void:
	layer = 12
	_backdrop = UiTheme.scrim(0.76)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	_sheet = PanelContainer.new()
	UiTheme.apply_panel(_sheet, UiTheme.board_style(9))
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	_clip = UiTheme.clip_badge()
	add_child(_clip)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	_sheet.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 5)
	header.custom_minimum_size.y = 24.0
	column.add_child(header)
	var badge := UiTheme.icon(UiTheme.Icon.TROPHY)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(badge)
	var title := UiTheme.label("DIÁRIO DO PORTO", UiTheme.SIZE_BODY, UiTheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	var close_button := UiTheme.icon_button(UiTheme.Icon.CLOSE, &"ghost", 26.0,
		"Fechar o diário")
	close_button.custom_minimum_size = Vector2(30, 24)
	close_button.tooltip_text = "Fechar (Esc)"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 2)
	tabs.custom_minimum_size.y = 22.0
	column.add_child(tabs)
	for tab: Array in TABS:
		var button := Button.new()
		button.text = str(tab[1])
		# Without this the three labels set a 314px floor on the board, which is
		# wider than the command rail it now lives in.
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.apply_font(button, UiTheme.SIZE_SMALL)
		UiTheme.style_tab(button, tab[0] == _active_tab)
		button.pressed.connect(_select_tab.bind(tab[0]))
		tabs.add_child(button)
		_tab_buttons[tab[0]] = button

	var sheet := UiTheme.panel(UiTheme.paper_style(4))
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(sheet)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiTheme.style_scroll(scroll)
	sheet.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 4)
	scroll.add_child(_list)
	_layout()
	_refresh()


func open(tab := "next") -> void:
	_active_tab = tab if TABS.any(func(entry: Array) -> bool: return entry[0] == tab) else "next"
	_open = true
	_focus_return = get_viewport().gui_get_focus_owner()
	_refresh()
	_layout()
	UiTheme.focus_first(_sheet)
	open_changed.emit(true)


func close() -> void:
	if not _open:
		return
	_open = false
	_layout()
	UiTheme.restore_focus(_focus_return)
	_focus_return = null
	open_changed.emit(false)


func is_open() -> bool:
	return _open


func refresh() -> void:
	_refresh()


func set_rail(rail: CommandRail) -> void:
	_rail = rail


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


func _build_crew_page() -> void:
	## Who works here, what each of them is on right now, and the charter record.
	## The whole crew in one place was the thing the individual dossiers could not
	## give: you can tap one person in the yard, but not compare the shift.
	var record := _charter_record()
	if not record.is_empty():
		_list.add_child(_make_record_card(record))
	for member: Dictionary in _crew():
		_list.add_child(_make_crew_card(member))


func _make_record_card(record: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	UiTheme.apply_panel(card, UiTheme.card_style(&"ready"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	card.add_child(row)
	row.add_child(UiTheme.icon(UiTheme.Icon.STAR))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 1)
	row.add_child(text)
	text.add_child(UiTheme.label("ESCALAS ESPECIAIS", UiTheme.SIZE_SMALL,
		UiTheme.INK))
	var played := int(record.get("played", 0))
	var won := int(record.get("won", 0))
	var detail := "nenhuma ainda" if played == 0 \
		else "%d de %d concluídas" % [won, played]
	text.add_child(UiTheme.label(detail, UiTheme.SIZE_SMALL, UiTheme.AMBER_DEEP))
	return card


func _make_crew_card(member: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	UiTheme.apply_panel(card, UiTheme.card_style(
		&"ready" if bool(member.get("special", false)) else &"normal"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	card.add_child(row)
	row.add_child(UiTheme.icon(UiTheme.Icon.GLOVE))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 1)
	row.add_child(text)
	var name_label := UiTheme.label("%s  -  %s" % [str(member.get("name", "")),
		str(member.get("title", ""))], UiTheme.SIZE_SMALL, UiTheme.INK)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(name_label)
	var task := str(member.get("objective", ""))
	var task_label := UiTheme.label(task if not task.is_empty() \
		else "Sem tarefa agora.", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	task_label.clip_text = true
	task_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(task_label)
	var tally := UiTheme.stamp(str(int(member.get("moves", 0))), UiTheme.AMBER,
		UiTheme.SIZE_SMALL)
	tally.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tally)
	return card


func _crew() -> Array:
	var getter: Callable = _callbacks.get("get_crew", Callable())
	if getter.is_valid():
		var value: Variant = getter.call()
		return value if value is Array else []
	return []


func _charter_record() -> Dictionary:
	var getter: Callable = _callbacks.get("get_charters", Callable())
	if getter.is_valid():
		var value: Variant = getter.call()
		return value if value is Dictionary else {}
	return {}


func _select_tab(tab: String) -> void:
	_active_tab = tab
	_refresh()


func _refresh() -> void:
	if _list == null or not is_instance_valid(_list):
		return
	for child in _list.get_children():
		child.queue_free()
	for key: String in _tab_buttons:
		UiTheme.style_tab(_tab_buttons[key], key == _active_tab)
	if _active_tab == "crew":
		_build_crew_page()
	else:
		for objective: Dictionary in _objectives():
			var done := bool(objective.get("complete", false))
			if (_active_tab == "done" and not done) \
					or (_active_tab == "next" and done):
				continue
			_list.add_child(_make_card(objective))
	if _list.get_child_count() == 0:
		var empty := UiTheme.label("Nenhuma meta nesta página."
			if _active_tab != "crew" else "Ninguém contratado ainda.",
			UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(empty)


func _objectives() -> Array:
	var getter: Callable = _callbacks.get("get_objectives", Callable())
	if getter.is_valid():
		var supplied: Variant = getter.call()
		return supplied if supplied is Array else []
	if _source != null and _source.has_method("get_pinned_objective"):
		var pinned: Dictionary = _source.get_pinned_objective()
		return [pinned] if not pinned.is_empty() else []
	return []


# --------------------------------------------------------------------- cards

func _progress_bar(progress: float, target: float) -> ProgressBar:
	var bar := ProgressBar.new()
	var styles := UiTheme.bar_styles()
	bar.add_theme_stylebox_override(&"background", styles[0])
	bar.add_theme_stylebox_override(&"fill", styles[1])
	bar.show_percentage = false
	# Tall enough to read as a bar. At 5px it looked like an underline under
	# the title rather than a measure of anything.
	bar.custom_minimum_size.y = 9.0
	bar.max_value = maxf(target, 1.0)
	bar.value = clampf(progress, 0.0, bar.max_value)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _make_card(objective: Dictionary) -> PanelContainer:
	var done := bool(objective.get("complete", false))
	var pinned := bool(objective.get("pinned", false))
	var card := PanelContainer.new()
	card.custom_minimum_size.y = 44.0
	UiTheme.apply_panel(card, UiTheme.card_style(
		&"done" if done else (&"ready" if pinned else &"normal")))

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	card.add_child(row)

	var mark := UiTheme.icon(UiTheme.Icon.CHECK if done else UiTheme.Icon.TROPHY)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override(&"separation", 2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := UiTheme.label(str(objective.get("title", "Meta de operação")),
		UiTheme.SIZE_SMALL, UiTheme.INK)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(title)

	var progress := float(objective.get("progress", 0.0))
	var target := float(objective.get("target", 0.0))
	if not done:
		text.add_child(_progress_bar(progress, target))
	var detail := UiTheme.label("%s / %s  -  %s" % [GameState.fmt(progress),
		GameState.fmt(target), _reward_text(objective.get("reward", {}))],
		UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP if done else UiTheme.INK_SOFT)
	detail.clip_text = true
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(detail)

	if not done:
		var pin := UiTheme.icon_button(UiTheme.Icon.STAR,
			&"amber" if pinned else &"ghost", 28.0)
		pin.custom_minimum_size = Vector2(30, 28)
		pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UiTheme.describe(pin, "Fixar \"%s\" no HUD"
			% str(objective.get("title", "meta")))
		pin.tooltip_text = "Fixada no HUD" if pinned else "Fixar no HUD"
		pin.disabled = pinned
		pin.pressed.connect(_pin.bind(StringName(objective.get("id", ""))))
		row.add_child(pin)
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


func _reward_text(reward: Variant) -> String:
	## Reward payloads are engine data; a player reads a sentence, never a key.
	if not reward is Dictionary or reward.is_empty():
		return "sem recompensa"
	var kind := StringName(reward.get("kind", ""))
	# Short on purpose: this line shares a 256px rail with the progress figures,
	# and a truncated reward tells the player nothing at all.
	match kind:
		&"teu":
			return "+%s TEU" % GameState.fmt(float(reward.get("amount", 0.0)))
		&"meta":
			return "+%d carreira" % int(reward.get("amount", 1))
		&"cosmetic":
			return "coleção"
	return "especial"


func _layout() -> void:
	if _sheet == null or not is_instance_valid(_sheet):
		return
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var desktop := _profile == "desktop" or (_profile.is_empty() and safe.size.x >= 700.0)
	if desktop:
		# Same slot as the shop: the rail is the one place commands live.
		var slot := _rail.content_rect if _rail != null \
			and _rail.content_rect.size != Vector2.ZERO else Rect2()
		if slot.size == Vector2.ZERO:
			var width := clampf(safe.size.x * 0.34, 280.0, 390.0)
			slot = Rect2(Vector2(safe.end.x - width - 8.0, safe.position.y + 8.0),
				Vector2(width, safe.size.y - 16.0))
		_sheet.size = slot.size
		_sheet.position = slot.position
	else:
		var top := safe.position.y + 20.0
		_sheet.size = Vector2(safe.size.x - 12.0,
			maxf(220.0, safe.end.y - top - 6.0))
		_sheet.position = Vector2(safe.position.x + 6.0,
			safe.end.y - _sheet.size.y - 6.0)
	_backdrop.visible = _open
	_sheet.visible = _open
	UiTheme.place_clip(_clip, _sheet, safe)
