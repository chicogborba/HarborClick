class_name CommandRail
extends CanvasLayer
## Where the player's commands live.
##
## On a wide screen the world only wants about two thirds of the window, and
## the third that was left over was literally empty grey with a gear floating
## in one corner and a shop button in the other. That is not a layout, it is a
## leftover. The rail is a real clipboard pinned down that side: the berth, the
## pinned objective and every key, in the same material as the boards they open.
##
## In portrait the port takes the whole screen, so the rail collapses to a steel
## console under the thumb — the same enamel panel the gantry is made of, seen
## from the other end of the screen, with the keys bolted to it.
##
## The tally is deliberately not here in either profile. It used to be, and a
## wide screen then carried the same number twice: once in the rail and once
## over the port. The gantry spans the world in both profiles now, so there is
## one counter in the game.

signal shop_requested
signal routes_requested
signal journal_requested
signal settings_requested
signal prestige_requested

## Where a desktop overlay should draw itself so it reads as the rail changing
## contents rather than a drawer sliding over the port.
var content_rect := Rect2()

var _board: PanelContainer
var _clip: TextureRect
var _column: VBoxContainer
var _berth_chip: PanelContainer
var _berth_label: Label
var _berth_bar: ProgressBar
var _berth_detail: Label
var _fleet: VBoxContainer
var _fleet_rows: Array[PanelContainer] = []
var _objective: PanelContainer
var _objective_title: Label
var _objective_progress: Label
var _keys: VBoxContainer
var _prestige_key: Button
var _summary: VBoxContainer
var _summary_values: Dictionary = {}
var _yard_fill := Callable()
var _objective_source := Callable()
var _bar: PanelContainer
var _bar_keys: HBoxContainer
var _shop_pip: TextureRect
var _shop_alert := Callable()
var _desktop := false
var _safe_rect := Rect2()
var _profile := ""
var _tick := 0.0


func _ready() -> void:
	layer = 5
	_build_board()
	_build_bar()
	get_viewport().size_changed.connect(_layout)
	EventBus.prestiged.connect(func(_s: int) -> void: _refresh_prestige())
	_layout()


# ------------------------------------------------------------------ assembly

func _build_board() -> void:
	_board = PanelContainer.new()
	UiTheme.apply_panel(_board, UiTheme.board_style(9))
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_board)
	_clip = UiTheme.clip_badge()
	add_child(_clip)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 5)
	_board.add_child(_column)

	# The berth is the thing the player is actually watching, and the rail had
	# a hand-sized patch of blank paper under the keys. It gets a real card:
	# what the berth is doing, how far through it is, and what the machines are
	# contributing without a finger on the screen.
	_berth_chip = PanelContainer.new()
	UiTheme.apply_panel(_berth_chip, UiTheme.card_style(&"normal"))
	_berth_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_berth_chip.visible = false
	_column.add_child(_berth_chip)
	var berth_col := VBoxContainer.new()
	berth_col.add_theme_constant_override(&"separation", 3)
	berth_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_berth_chip.add_child(berth_col)
	var berth_head := HBoxContainer.new()
	berth_head.add_theme_constant_override(&"separation", 4)
	berth_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	berth_col.add_child(berth_head)
	berth_head.add_child(UiTheme.icon(UiTheme.Icon.SHIP))
	_berth_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK)
	_berth_label.clip_text = true
	_berth_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_berth_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	berth_head.add_child(_berth_label)
	_berth_bar = ProgressBar.new()
	var bar_styles := UiTheme.bar_styles()
	_berth_bar.add_theme_stylebox_override(&"background", bar_styles[0])
	_berth_bar.add_theme_stylebox_override(&"fill", bar_styles[1])
	_berth_bar.show_percentage = false
	_berth_bar.custom_minimum_size.y = 9.0
	_berth_bar.max_value = 1.0
	_berth_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	berth_col.add_child(_berth_bar)
	_berth_detail = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_berth_detail.clip_text = true
	berth_col.add_child(_berth_detail)

	# With more than one berth the rail carries the whole quay: the worked berth
	# keeps the card above, and the others get a line each with what they are on
	# or when their next hull ties up. In portrait there is no room, so this stays
	# collapsed and the HUD chip speaks for the focused berth alone.
	_fleet = VBoxContainer.new()
	_fleet.add_theme_constant_override(&"separation", 2)
	_fleet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fleet.visible = false
	_column.add_child(_fleet)

	_objective = PanelContainer.new()
	UiTheme.apply_panel(_objective, UiTheme.card_style(&"ready"))
	_objective.mouse_filter = Control.MOUSE_FILTER_STOP
	_objective.visible = false
	_column.add_child(_objective)
	var objective_button := Button.new()
	objective_button.flat = true
	objective_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	objective_button.add_theme_stylebox_override(&"focus", UiTheme.focus_ring())
	UiTheme.describe(objective_button, "Abrir o Diário do Porto")
	objective_button.pressed.connect(func() -> void: journal_requested.emit())
	_objective.add_child(objective_button)
	var objective_row := HBoxContainer.new()
	objective_row.add_theme_constant_override(&"separation", 4)
	objective_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_row.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	_objective.add_child(objective_row)
	objective_row.add_child(UiTheme.icon(UiTheme.Icon.TROPHY))
	var objective_text := VBoxContainer.new()
	objective_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_text.add_theme_constant_override(&"separation", 0)
	objective_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_row.add_child(objective_text)
	_objective_title = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK)
	_objective_title.clip_text = true
	_objective_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective_text.add_child(_objective_title)
	_objective_progress = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER_DEEP)
	_objective_progress.clip_text = true
	objective_text.add_child(_objective_progress)

	_column.add_child(UiTheme.divider())

	_keys = VBoxContainer.new()
	_keys.add_theme_constant_override(&"separation", 4)
	_keys.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(_keys)
	_keys.add_child(_make_key("LOJA", UiTheme.Icon.CRANE, &"amber",
		"Abrir a loja do terminal", shop_requested))
	# A globe, not a hull: the key opens a world chart, and the ship glyph is
	# already what a berth row wears.
	_keys.add_child(_make_key("ROTAS", UiTheme.Icon.GLOBE, &"ghost",
		"Abrir o mapa de rotas", routes_requested))
	_keys.add_child(_make_key("DIÁRIO", UiTheme.Icon.TROPHY, &"ghost",
		"Abrir o Diário do Porto", journal_requested))
	_keys.add_child(_make_key("AJUSTES", UiTheme.Icon.GEAR, &"ghost",
		"Abrir os ajustes", settings_requested))
	_prestige_key = _make_key("ABRIR CAPITAL", UiTheme.Icon.STAR, &"alt",
		"Reconstruir o porto e emitir ações", prestige_requested)
	_prestige_key.visible = false
	_keys.add_child(_prestige_key)
	# The keys never fill a full-height board and the blank sheet under them
	# read as unfinished. A pencil lying across it says "someone works here"
	# for the price of one sprite.
	var pencil_row := Control.new()
	pencil_row.custom_minimum_size.y = 24.0
	pencil_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.add_child(pencil_row)
	var pencil := UiTheme.desk_prop("ui_pencil", -6.0)
	pencil.position = Vector2(12, 6)
	pencil_row.add_child(pencil)

	# The keys do not fill a full-height board, and blank parchment reads as
	# unfinished. The gap carries the three numbers a foreman would actually
	# glance at between decisions.
	_column.add_child(UiTheme.spacer(2.0))
	_column.add_child(UiTheme.divider())
	_summary = VBoxContainer.new()
	_summary.add_theme_constant_override(&"separation", 1)
	_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_summary)
	for row in [["DIA", "day"], ["ESCALAS", "calls"], ["PÁTIO", "fill"]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 4)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_summary.add_child(line)
		var caption := UiTheme.label(str(row[0]), UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(caption)
		var value := UiTheme.label("-", UiTheme.SIZE_SMALL, UiTheme.INK)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value)
		_summary_values[str(row[1])] = value


## The console, and the key face on it. Sized so a 24px glyph and its word both
## fit: a 12px icon on a thumb-sized key reads as a bullet point, and this is the
## one row of the interface the player touches all session.
const BAR_H := 54.0
const BAR_KEY_H := 44.0


func _build_bar() -> void:
	## Portrait: the port keeps the whole screen, so the rail is one console of
	## keys where a thumb already rests — the gantry's panel the other way up,
	## with its amber edge facing the port.
	_bar = PanelContainer.new()
	UiTheme.apply_panel(_bar, UiTheme.console_style())
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bar)
	_bar_keys = HBoxContainer.new()
	_bar_keys.add_theme_constant_override(&"separation", 3)
	_bar.add_child(_bar_keys)
	# Four keys of equal weight, each a glyph over its word. The old bar gave the
	# named keys a full-width slab and squeezed settings into a 44px square with a
	# 12px glyph in it, which is the "settings icon is rubbish" from the playtest.
	# Stacking the glyph buys every key a real word inside 80px.
	var shop_key: Button = null
	for spec in [["LOJA", UiTheme.Icon.CRANE, &"amber", "Abrir a loja do terminal", shop_requested],
			["ROTAS", UiTheme.Icon.GLOBE, &"steel", "Abrir o mapa de rotas", routes_requested],
			["DIÁRIO", UiTheme.Icon.TROPHY, &"steel", "Abrir o Diário do Porto", journal_requested],
			["AJUSTES", UiTheme.Icon.GEAR, &"steel", "Abrir os ajustes", settings_requested]]:
		var key := _make_key(str(spec[0]), spec[1], spec[2], str(spec[3]), spec[4],
			true)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.custom_minimum_size = Vector2(0.0, BAR_KEY_H)
		_bar_keys.add_child(key)
		if shop_key == null:
			shop_key = key

	# A lamp on the key that has something behind it. A clicker's whole loop is
	# "earn, then spend", and the spend half was invisible until you opened the
	# shop and looked.
	_shop_pip = UiTheme.pip()
	_shop_pip.visible = false
	_shop_pip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT,
		Control.PRESET_MODE_MINSIZE)
	_shop_pip.position = Vector2(-11.0, 4.0)
	_shop_pip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	shop_key.add_child(_shop_pip)


func _make_key(text: String, icon: UiTheme.Icon, kind: StringName,
		control_name: String, target: Signal, stacked: bool = false) -> Button:
	## Button draws its icon hard against the left edge and only centres the
	## text, which left a hand-sized hole between the two on a wide key. The
	## glyph and the word are laid out as one group instead, centred together —
	## side by side on the rail's tall keys, stacked on the console's square ones.
	var key := UiTheme.button("", kind, UiTheme.SIZE_SMALL)
	key.custom_minimum_size.y = BAR_KEY_H if stacked else 34.0
	UiTheme.describe(key, control_name)
	key.pressed.connect(func() -> void:
		AudioManager.play_sfx("tap")
		target.emit())

	var group: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	group.add_theme_constant_override(&"separation", 1 if stacked else 5)
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	key.add_child(group)
	var glyph := UiTheme.icon(icon, 2 if stacked else 1)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if stacked \
		else Control.SIZE_FILL
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	group.add_child(glyph)
	if not text.is_empty():
		var label := UiTheme.label(text, UiTheme.SIZE_SMALL, _key_ink(kind))
		label.name = "KeyText"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if stacked:
			# Only the console's keys are width-constrained, and only there may the
			# word be clipped. A clipped Label reports a minimum width of one
			# pixel, so doing this on the rail's centred group collapses the word
			# to nothing and leaves a key with a bare glyph on it.
			label.clip_text = true
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group.add_child(label)
	return key


func _key_ink(kind: StringName) -> Color:
	## The word on a key follows the key's own face. A steel key carries the same
	## cream as the enamel it is bolted to; an amber one carries ink.
	match kind:
		&"alt", &"danger":
			return UiTheme.CREAM
		&"steel":
			return UiTheme.STEEL_TEXT
		_:
			return UiTheme.INK


func _set_key_text(key: Button, text: String) -> void:
	## The word on a key is a child Label, not the Button's own `text` — the icon
	## and the word are laid out as one centred group. Writing `Button.text`
	## instead draws a *second*, differently centred string on top of the first,
	## which is what turned the prestige key into "CABEITALCABITAL".
	if key == null:
		return
	for group in key.get_children():
		var label := group.get_node_or_null(^"KeyText") as Label
		if label != null:
			label.text = text
			return


# --------------------------------------------------------------------- state

func set_berth_status(text: String) -> void:
	set_berth({"text": text})


func set_berth(status: Dictionary) -> void:
	var text := str(status.get("text", ""))
	_berth_label.text = text
	var total := float(status.get("total", 0.0))
	var current := float(status.get("current", 0.0))
	_berth_bar.visible = total > 0.0
	if total > 0.0:
		_berth_bar.max_value = total
		_berth_bar.value = clampf(current, 0.0, total)
	var rate := float(status.get("auto_rate", 0.0))
	var parts: PackedStringArray = []
	var vessel := str(status.get("vessel", ""))
	if not vessel.is_empty():
		parts.append(vessel)
	if total > 0.0:
		parts.append("%d / %d" % [int(current), int(total)])
	if rate > 0.0:
		parts.append("%.1f/s auto" % rate)
	# The card is a rail's width; a truncated line says nothing.
	_berth_detail.text = " - ".join(parts)
	_berth_detail.visible = not _berth_detail.text.is_empty()
	_berth_chip.visible = _desktop and not text.is_empty()


func set_fleet(rows: Array) -> void:
	## One line per berth other than the one the card above is already showing.
	if _fleet == null or not is_instance_valid(_fleet):
		return
	var wanted := 0 if not _desktop else maxi(0, rows.size() - 1)
	while _fleet_rows.size() < wanted:
		_fleet_rows.append(_make_fleet_row())
	for index in _fleet_rows.size():
		_fleet_rows[index].visible = index < wanted
	_fleet.visible = wanted > 0
	if wanted == 0:
		return
	var slot := 0
	for row: Dictionary in rows:
		if bool(row.get("focused", false)):
			continue
		if slot >= _fleet_rows.size():
			break
		_fill_fleet_row(_fleet_rows[slot], row)
		slot += 1


func _make_fleet_row() -> PanelContainer:
	var card := PanelContainer.new()
	UiTheme.apply_panel(card, UiTheme.card_style(&"normal"))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fleet.add_child(card)
	var row := HBoxContainer.new()
	# Named, because the row is looked up by path every refresh: an auto-named
	# node makes that lookup fail once per berth per frame, and the error spam
	# costs more than the row draws.
	row.name = "Row"
	row.add_theme_constant_override(&"separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(UiTheme.icon(UiTheme.Icon.SHIP))
	var label := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK)
	label.name = "Berth"
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER_DEEP)
	value.name = "Value"
	row.add_child(value)
	return card


func _fill_fleet_row(card: PanelContainer, row: Dictionary) -> void:
	var index := int(row.get("index", 0))
	var label := card.get_node(^"Row/Berth") as Label
	var value := card.get_node(^"Row/Value") as Label
	var vessel := str(row.get("vessel", ""))
	label.text = "B%d  %s" % [index + 1,
		vessel if not vessel.is_empty() else str(row.get("state", ""))]
	var total := float(row.get("total", 0.0))
	var eta := float(row.get("eta", -1.0))
	if total > 0.0:
		value.text = "%d/%d" % [int(row.get("current", 0.0)), int(total)]
	elif eta >= 0.0:
		# An empty berth is only interesting for one reason: when the next one
		# gets here.
		value.text = "em %ds" % int(ceilf(eta))
	else:
		value.text = str(row.get("state", ""))
	UiTheme.apply_panel(card, UiTheme.card_style(
		&"ready" if bool(row.get("special", false)) else &"normal"))


func set_objective(objective: Dictionary) -> void:
	if objective.is_empty():
		_objective.visible = false
		return
	_objective.visible = _desktop
	var pinned := bool(objective.get("pinned", false))
	_objective_title.text = ("FIXADA: " if pinned else "PRÓXIMA: ") \
		+ str(objective.get("title", "Meta"))
	_objective_progress.text = "%s / %s" % [
		GameState.fmt(float(objective.get("progress", 0.0))),
		GameState.fmt(float(objective.get("target", 0.0)))]


func set_yard_source(fill: Callable) -> void:
	_yard_fill = fill


func set_objective_source(objective: Callable) -> void:
	_objective_source = objective
	_refresh_objective()


func set_shop_alert_source(alert: Callable) -> void:
	## Whether the shop has anything the player can afford right now. Asked on
	## the rail's own slow tick rather than on every credited box: the answer
	## walks the whole catalogue.
	_shop_alert = alert
	_refresh_alerts()


func _process(delta: float) -> void:
	_tick += delta
	if _tick > 0.4:
		_tick = 0.0
		_refresh_prestige()
		_refresh_summary()
		_refresh_objective()
		_refresh_alerts()


func _refresh_alerts() -> void:
	if _shop_pip == null:
		return
	_shop_pip.visible = _shop_alert.is_valid() and bool(_shop_alert.call())


func _refresh_objective() -> void:
	if _objective_source.is_valid():
		var value: Variant = _objective_source.call()
		set_objective(value if value is Dictionary else {})


func _refresh_summary() -> void:
	if not _desktop or _summary_values.is_empty():
		return
	(_summary_values.day as Label).text = str(TimeManager.day)
	(_summary_values.calls as Label).text = str(int(
		Progression.stats.get(&"calls_completed", 0)))
	var fill := float(_yard_fill.call()) if _yard_fill.is_valid() else 0.0
	(_summary_values.fill as Label).text = "%d%%" % roundi(fill * 100.0)


func _refresh_prestige() -> void:
	if _prestige_key == null:
		return
	var can := GameState.can_prestige()
	_prestige_key.visible = can
	if can:
		_set_key_text(_prestige_key, "CAPITAL +%d" % GameState.prestige_gain())


# -------------------------------------------------------------------- layout

func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_profile = str(metrics.get("profile", ""))
	_layout()


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, view)
	_desktop = _profile == "desktop" if not _profile.is_empty() \
		else view.x >= 700.0 and view.x / maxf(view.y, 1.0) >= 1.25

	_board.visible = _desktop
	_bar.visible = not _desktop
	if _desktop:
		var width := clampf(safe.size.x * 0.30, 240.0, 360.0)
		# The spring clip straddles the top edge, so the board starts far
		# enough down for the hardware to be on screen.
		var top := safe.position.y + 20.0
		_board.size = Vector2(width, safe.end.y - top - 8.0)
		_board.position = Vector2(safe.end.x - width - 8.0, top)
		# Overlays land exactly here, so opening the shop reads as the rail
		# turning a page instead of a panel arriving from off screen.
		content_rect = Rect2(_board.position, _board.size)
	else:
		_bar.size = Vector2(safe.size.x - 12.0, BAR_H)
		_bar.position = Vector2(safe.position.x + 6.0,
			safe.end.y - BAR_H - 6.0)
		content_rect = Rect2()
	UiTheme.place_clip(_clip, _board, safe)
	_berth_chip.visible = _desktop and not _berth_label.text.is_empty()
	_objective.visible = _desktop and not _objective_title.text.is_empty()
	_summary.visible = _desktop
	_refresh_summary()


func set_overlay_open(open: bool) -> void:
	## While a board is up in the rail's place, the rail's own keys would be
	## drawn underneath it. Hiding them keeps the focus order honest too.
	if _desktop:
		_board.visible = not open
		_clip.visible = not open and _clip.visible
	else:
		_bar.visible = not open
