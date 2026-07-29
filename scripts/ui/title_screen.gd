extends Control
## The first thing the game shows: pick one of three terminals and go.
##
## Profiles are three separate save paths, nothing more. Everything the game
## persists already lives behind `SaveManager`, so a slot is chosen before Main
## exists and the whole tree below it never learns there was a choice.
##
## Deleting a run is the most destructive button in the game, so it arms first
## and only the armed slot can be confirmed — arming one and confirming another
## is exactly how someone loses the wrong terminal.

const SLOT_HEIGHT := 74.0

var _board: PanelContainer
var _clip: TextureRect
var _slots: VBoxContainer
var _status: Label
var _armed_delete := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	get_viewport().size_changed.connect(_layout)
	_refresh()
	_layout()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color8(38, 46, 60)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_board = PanelContainer.new()
	UiTheme.apply_panel(_board, UiTheme.board_style(10))
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_board)
	_clip = UiTheme.clip_badge()
	add_child(_clip)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 5)
	_board.add_child(column)

	var title := UiTheme.label("HARBORCLICK", UiTheme.SIZE_TITLE, UiTheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := UiTheme.label("Terminal de contêineres",
		UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(UiTheme.divider())

	var sheet := UiTheme.panel(UiTheme.paper_style(4))
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(sheet)
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override(&"separation", 4)
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_child(_slots)

	# A pencil clipped to the corner of the board, the way one actually would be.
	var pencil := UiTheme.desk_prop("ui_pencil", -8.0)
	pencil.name = "Pencil"
	add_child(pencil)

	_status = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)


func _refresh() -> void:
	for child in _slots.get_children():
		child.queue_free()
	for slot in range(1, SaveManager.PROFILE_COUNT + 1):
		_slots.add_child(_make_slot(SaveManager.profile_summary(slot)))
	if not SaveManager.storage_available():
		_status.text = "Este navegador não está guardando o progresso."
		_status.label_settings.font_color = UiTheme.DANGER


func _make_slot(summary: Dictionary) -> PanelContainer:
	var slot := int(summary.slot)
	var used := bool(summary.get("exists", false))
	var armed := _armed_delete == slot
	var card := PanelContainer.new()
	card.custom_minimum_size.y = SLOT_HEIGHT
	UiTheme.apply_panel(card, UiTheme.card_style(&"ready" if used else &"normal"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	card.add_child(row)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override(&"separation", 1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(_line("TERMINAL %d" % slot, UiTheme.SIZE_BODY, UiTheme.INK))
	if used:
		text.add_child(_line("%s TEU  -  dia %d" % [
			GameState.fmt(float(summary.get("teus", 0.0))),
			int(summary.get("day", 1))], UiTheme.SIZE_SMALL, UiTheme.INK_SOFT))
		var flotations := int(summary.get("prestige", 0))
		text.add_child(_line(
			"%d reconstrução(ões)" % flotations if flotations > 0
				else "primeira operação",
			UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP))
	else:
		text.add_child(_line("Terreno livre.", UiTheme.SIZE_SMALL,
			UiTheme.INK_SOFT))

	var keys := VBoxContainer.new()
	keys.add_theme_constant_override(&"separation", 3)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.custom_minimum_size.x = 84.0
	row.add_child(keys)

	var play := UiTheme.button("CONTINUAR" if used else "COMEÇAR", &"amber",
		UiTheme.SIZE_SMALL)
	play.custom_minimum_size.y = 26.0
	UiTheme.describe(play, "%s o terminal %d"
		% ["Continuar" if used else "Começar", slot])
	play.pressed.connect(_play.bind(slot))
	keys.add_child(play)

	if used:
		var erase := UiTheme.button("APAGAR?" if armed else "APAGAR",
			&"danger" if armed else &"ghost", UiTheme.SIZE_SMALL)
		erase.custom_minimum_size.y = 24.0
		UiTheme.describe(erase, "Apagar o terminal %d" % slot,
			"Toque duas vezes. A operação não pode ser desfeita.")
		erase.pressed.connect(_erase.bind(slot))
		keys.add_child(erase)
	return card


func _line(text: String, font_size: int, color: Color) -> Label:
	## Every label on a slot clips. A long terminal summary must never set the
	## board's minimum width — that is what pushed the whole card off a 320px
	## screen the first time.
	var label := UiTheme.label(text, font_size, color)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = 0.0
	return label


func _play(slot: int) -> void:
	AudioManager.play_sfx("build")
	SaveManager.use_profile(slot)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _erase(slot: int) -> void:
	## Arming is per slot: confirming has to be the same terminal that was
	## armed, or a mis-tap deletes a run the player never selected.
	if _armed_delete != slot:
		_armed_delete = slot
		_status.text = "Apagar o terminal %d é definitivo. Toque em APAGAR? de novo." % slot
		_status.label_settings.font_color = UiTheme.DANGER
		AudioManager.play_sfx("deny")
		_refresh()
		return
	SaveManager.delete_profile(slot)
	_armed_delete = 0
	_status.text = "Terminal %d apagado." % slot
	_status.label_settings.font_color = UiTheme.INK_SOFT
	AudioManager.play_sfx("tap")
	_refresh()


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var width := clampf(view.x - 24.0, 260.0, 400.0)
	var height := minf(view.y - 24.0, 380.0)
	_board.size = Vector2(width, height)
	_board.custom_minimum_size = _board.size
	_board.position = (view - _board.size) * 0.5
	UiTheme.place_clip(_clip, _board, Rect2(Vector2.ZERO, view))
	var pencil := get_node_or_null(^"Pencil") as Control
	if pencil != null:
		pencil.position = _board.position + Vector2(
			_board.size.x - pencil.size.x - 16.0, _board.size.y - 14.0)
