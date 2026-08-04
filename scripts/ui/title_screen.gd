extends Control
## The first thing the game shows.
##
## Two pages in one screen, because a title has one job — get the player into the
## terminal — and everything else it offers is a detour it should not charge for.
##
##   * **the marquee**: the plate, JOGAR, CONTINUAR and AJUSTES down the middle,
##     four corner keys and the plate at the foot;
##   * **the board**: the three terminals, reached from JOGAR, and the only place
##     a run can be started or erased.
##
## CONTINUAR is the interesting one. It is the single button that gets a returning
## player back where they were, and it only exists when there *is* a where: the
## slot is remembered in `UserPreferences`, not in a save file, because the title
## has to answer "continue which one?" before any profile has been loaded.
##
## Deleting a run is the most destructive button in the game, so it arms first and
## only the armed slot can be confirmed — arming one and confirming another is
## exactly how somebody loses the wrong terminal.

const SLOT_HEIGHT := 70.0
## The four corner keys, and what each of them opens.
const CORNERS := [
	{"id": "feedback", "label": "FEEDBACK", "icon": UiTheme.Icon.BELL,
		"corner": "tl"},
	{"id": "site", "label": "SITE", "icon": UiTheme.Icon.GLOBE, "corner": "tr"},
	{"id": "comunidade", "label": "COMUNIDADE", "icon": UiTheme.Icon.GLOVE,
		"corner": "bl"},
	{"id": "creditos", "label": "CRÉDITOS", "icon": UiTheme.Icon.TROPHY,
		"corner": "br"},
]
const REPO_URL := "https://github.com/chicogborba/HarborClick"
const VERSION_LINE := "v1.0.0"
const STUDIO_LINE := "PORTSTACK STUDIOS"

var _backdrop: TextureRect
var _marquee: Control
var _plate: PanelContainer
var _actions: VBoxContainer
var _continue_key: Button
var _corner_keys: Dictionary = {}     # id -> Control
var _footer: VBoxContainer
var _board_page: Control
var _board: PanelContainer
var _clip: TextureRect
var _slots: VBoxContainer
var _status: Label
var _sheet: Control
var _armed_delete := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.install_window_theme(get_window())
	_build()
	get_viewport().size_changed.connect(_layout)
	_refresh()
	_show_marquee()
	_layout()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _sheet != null:
		_close_sheet()
		accept_event()
	elif _board_page.visible:
		_show_marquee()
		accept_event()


# ------------------------------------------------------------------- building

func _build() -> void:
	_backdrop = TextureRect.new()
	_backdrop.name = "HarborPanorama"
	_backdrop.texture = preload("res://assets/sprites/ui_title_port.png")
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	var shade := ColorRect.new()
	shade.color = Color(0.055, 0.065, 0.11, 0.34)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_build_marquee()
	_build_board()


func _build_marquee() -> void:
	_marquee = Control.new()
	_marquee.name = "Marquee"
	_marquee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marquee.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_marquee)

	_plate = UiTheme.panel(UiTheme.slate_style(true, 8))
	_plate.name = "TitlePlate"
	_marquee.add_child(_plate)
	var plate_column := VBoxContainer.new()
	plate_column.alignment = BoxContainer.ALIGNMENT_CENTER
	plate_column.add_theme_constant_override(&"separation", 2)
	_plate.add_child(plate_column)

	var logo_row := HBoxContainer.new()
	logo_row.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_row.add_theme_constant_override(&"separation", 3)
	plate_column.add_child(logo_row)
	# The anchor is the mark, so it leads the name rather than sitting over it —
	# a glyph stacked above six-pixel type at this scale is a smudge.
	logo_row.add_child(UiTheme.icon(UiTheme.Icon.SHIP, 2))
	logo_row.add_child(UiTheme.label("HARBOR", UiTheme.SIZE_HUGE, UiTheme.PAPER))
	logo_row.add_child(UiTheme.label("CLICK", UiTheme.SIZE_HUGE, UiTheme.AMBER))

	# Stars as icons, not as text: the pixel font is drawn glyph by glyph in
	# `tools/sprites/gen_font.py` and has no dingbats, so a literal star is a
	# missing-glyph box.
	var motto_row := HBoxContainer.new()
	motto_row.alignment = BoxContainer.ALIGNMENT_CENTER
	motto_row.add_theme_constant_override(&"separation", 4)
	plate_column.add_child(motto_row)
	motto_row.add_child(UiTheme.icon(UiTheme.Icon.STAR, 1))
	motto_row.add_child(UiTheme.label("CONSTRUA • EXPANDA • FATURE",
		UiTheme.SIZE_SMALL, UiTheme.AMBER))
	motto_row.add_child(UiTheme.icon(UiTheme.Icon.STAR, 1))

	_actions = VBoxContainer.new()
	_actions.name = "Actions"
	_actions.add_theme_constant_override(&"separation", 6)
	_marquee.add_child(_actions)

	var play := UiTheme.button("JOGAR", &"amber", UiTheme.SIZE_BODY)
	play.custom_minimum_size.y = 40.0
	UiTheme.describe(play, "Jogar", "Escolher um dos três terminais")
	play.pressed.connect(_show_board)
	_actions.add_child(play)

	_continue_key = UiTheme.button("CONTINUAR", &"alt", UiTheme.SIZE_BODY)
	_continue_key.custom_minimum_size.y = 34.0
	_continue_key.pressed.connect(_continue_last)
	_actions.add_child(_continue_key)

	var settings := UiTheme.button("AJUSTES", &"alt", UiTheme.SIZE_BODY)
	settings.custom_minimum_size.y = 30.0
	UiTheme.describe(settings, "Ajustes", "Som, movimento e tela")
	settings.pressed.connect(_open_options)
	_actions.add_child(settings)

	for spec: Dictionary in CORNERS:
		var key := _corner_key(spec)
		_marquee.add_child(key)
		_corner_keys[str(spec.id)] = key

	_footer = VBoxContainer.new()
	_footer.name = "Footer"
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.add_theme_constant_override(&"separation", 0)
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marquee.add_child(_footer)
	var version := UiTheme.label(VERSION_LINE, UiTheme.SIZE_SMALL,
		UiTheme.SLATE_DIM)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_child(version)
	var studio := UiTheme.label(STUDIO_LINE, UiTheme.SIZE_SMALL, UiTheme.SLATE_DIM)
	studio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_child(studio)


func _corner_key(spec: Dictionary) -> PanelContainer:
	var key := UiTheme.panel(UiTheme.slate_style(false, 4), false)
	key.custom_minimum_size = Vector2(64, 46)
	key.focus_mode = Control.FOCUS_ALL
	key.add_theme_stylebox_override(&"focus", UiTheme.focus_ring())
	key.set_meta("corner", str(spec.corner))
	UiTheme.describe(key, str(spec.label))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_child(column)
	var glyph := UiTheme.icon(spec.icon as UiTheme.Icon, 1)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(glyph)
	var caption := UiTheme.label(str(spec.label), UiTheme.SIZE_SMALL,
		UiTheme.PAPER_DEEP)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	key.gui_input.connect(_corner_input.bind(str(spec.id)))
	return key


func _corner_input(event: InputEvent, id: String) -> void:
	var pressed := false
	if event.is_action_pressed(&"ui_accept"):
		pressed = true
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		pressed = click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		accept_event()
		_open_corner(id)


func _build_board() -> void:
	_board_page = Control.new()
	_board_page.name = "TerminalBoard"
	_board_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_page.visible = false
	add_child(_board_page)

	_board = PanelContainer.new()
	UiTheme.apply_panel(_board, UiTheme.board_style(10))
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board_page.add_child(_board)
	_clip = UiTheme.clip_badge()
	_board_page.add_child(_clip)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 5)
	_board.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 4)
	column.add_child(header)
	var back := UiTheme.button("VOLTAR", &"ghost", UiTheme.SIZE_SMALL)
	back.custom_minimum_size = Vector2(56, 22)
	UiTheme.describe(back, "Voltar", "Voltar à tela inicial")
	back.pressed.connect(_show_marquee)
	header.add_child(back)
	var title := UiTheme.label("ESCOLHA SEU TERMINAL", UiTheme.SIZE_BODY,
		UiTheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	# Balances the back key so the heading sits on the board's centre line.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(56, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	column.add_child(UiTheme.divider())

	var sheet := UiTheme.panel(UiTheme.paper_style(4))
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(sheet)
	# Scrolled, and the bar's width reserved rather than drawn over the cards.
	# Three terminals fit a phone today; the board must not be the thing that
	# decides that, or a fourth slot or a taller card pushes it off the screen the
	# way the first version of this board went off a 320-wide one.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_child(scroll)
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override(&"separation", 4)
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_slots)

	# A pencil clipped to the corner of the board, the way one actually would be.
	var pencil := UiTheme.desk_prop("ui_pencil", -8.0)
	pencil.name = "Pencil"
	_board_page.add_child(pencil)

	_status = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "PROGRESSO SALVO NESTE DISPOSITIVO"
	column.add_child(_status)


# --------------------------------------------------------------------- pages

func _show_marquee() -> void:
	_marquee.visible = true
	_board_page.visible = false
	_refresh_continue()
	_layout()


func _show_board() -> void:
	AudioManager.play_sfx("tap")
	_marquee.visible = false
	_board_page.visible = true
	_refresh()
	_layout()


func _refresh_continue() -> void:
	## CONTINUAR is only offered when there is something to continue. An enabled
	## key that starts a brand new run is the same betrayal as a save that was not
	## there — so a slot that has been deleted since it was last played takes the
	## key away with it.
	var slot := int(UserPreferences.last_profile)
	var summary := SaveManager.profile_summary(slot) if slot > 0 else {}
	var playable := slot > 0 and bool(summary.get("exists", false))
	_continue_key.visible = playable
	if not playable:
		return
	_continue_key.text = "CONTINUAR — DIA %d" % int(summary.get("day", 1))
	UiTheme.describe(_continue_key, "Continuar",
		"Terminal %d, dia %d" % [slot, int(summary.get("day", 1))])


func _continue_last() -> void:
	var slot := int(UserPreferences.last_profile)
	if slot <= 0 or not bool(SaveManager.profile_summary(slot).get("exists", false)):
		_show_board()
		return
	_play(slot)


# --------------------------------------------------------------------- sheets

func _open_options() -> void:
	_open_sheet("AJUSTES", [
		{"kind": "toggle", "label": "MÚSICA",
			"get": func() -> bool: return AudioManager.music_on,
			"set": func(on: bool) -> void: AudioManager.set_music_on(on)},
		{"kind": "toggle", "label": "EFEITOS",
			"get": func() -> bool: return AudioManager.sfx_on,
			"set": func(on: bool) -> void: AudioManager.set_sfx_on(on)},
		{"kind": "toggle", "label": "REDUZIR MOVIMENTO",
			"get": func() -> bool: return UserPreferences.reduce_motion,
			"set": func(on: bool) -> void: UserPreferences.set_reduce_motion(on)},
		{"kind": "toggle", "label": "NÚMEROS FLUTUANTES",
			"get": func() -> bool: return UserPreferences.floating_numbers,
			"set": func(on: bool) -> void: UserPreferences.set_floating_numbers(on)},
		{"kind": "toggle", "label": "TELA CHEIA",
			"get": func() -> bool: return UserPreferences.fullscreen,
			"set": func(on: bool) -> void: UserPreferences.set_fullscreen(on)},
		{"kind": "note", "label":
			"O resto dos ajustes — save, backup e tutorial — fica dentro do terminal, porque pertence a uma operação e não ao aparelho."},
	])


func _open_corner(id: String) -> void:
	AudioManager.play_sfx("tap")
	match id:
		"creditos":
			_open_sheet("CRÉDITOS", [
				{"kind": "note", "label": "HarborClick — %s" % VERSION_LINE},
				{"kind": "note", "label": "%s" % STUDIO_LINE},
				{"kind": "note", "label": "Feito em Godot 4. Cada sprite, fonte, efeito e trilha deste jogo é gerado por código: nada foi desenhado à mão."},
				{"kind": "note", "label": "Jargão de terminal conferido com quem trabalha em porto brasileiro."},
			])
		"site":
			_open_sheet("SITE", [
				{"kind": "note", "label": "O projeto inteiro é aberto, código e geradores de arte."},
				{"kind": "link", "label": "ABRIR REPOSITÓRIO", "url": REPO_URL},
			])
		"feedback":
			_open_sheet("FEEDBACK", [
				{"kind": "note", "label": "Achou um bug ou tem uma ideia? Abra uma issue — é o caminho que a gente lê."},
				{"kind": "link", "label": "ABRIR ISSUES", "url": REPO_URL + "/issues"},
			])
		_:
			_open_sheet("COMUNIDADE", [
				{"kind": "note", "label": "Estratégia, builds e reclamação sobre o pátio cheio."},
				{"kind": "link", "label": "ABRIR DISCUSSÕES",
					"url": REPO_URL + "/discussions"},
			])


func _open_sheet(title: String, rows: Array) -> void:
	_close_sheet()
	_sheet = Control.new()
	_sheet.name = "Sheet"
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sheet)

	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.04, 0.07, 0.72)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_close_sheet())
	_sheet.add_child(scrim)

	var panel := PanelContainer.new()
	panel.name = "SheetPanel"
	UiTheme.apply_panel(panel, UiTheme.board_style(10))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 5)
	panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 4)
	column.add_child(header)
	var heading := UiTheme.label(title, UiTheme.SIZE_BODY, UiTheme.INK)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close := UiTheme.icon_button(UiTheme.Icon.CLOSE)
	UiTheme.describe(close, "Fechar")
	close.pressed.connect(_close_sheet)
	header.add_child(close)
	column.add_child(UiTheme.divider())

	for row: Dictionary in rows:
		match str(row.get("kind", "note")):
			"toggle":
				column.add_child(_toggle_row(row))
			"link":
				var open := UiTheme.button(str(row.label), &"amber",
					UiTheme.SIZE_SMALL)
				open.custom_minimum_size.y = 26.0
				var url := str(row.url)
				UiTheme.describe(open, str(row.label), url)
				open.pressed.connect(func() -> void: OS.shell_open(url))
				column.add_child(open)
			_:
				var note := UiTheme.label(str(row.label), UiTheme.SIZE_SMALL,
					UiTheme.INK_SOFT)
				note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				note.custom_minimum_size.x = 0.0
				column.add_child(note)
	_layout()


func _toggle_row(row: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 6)
	var label := UiTheme.label(str(row.label), UiTheme.SIZE_SMALL, UiTheme.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var getter: Callable = row.get
	var setter: Callable = row.set
	var key := UiTheme.button("", &"alt", UiTheme.SIZE_SMALL)
	key.custom_minimum_size = Vector2(58, 22)
	var paint := func() -> void:
		var on := bool(getter.call())
		key.text = "LIGADO" if on else "DESLIGADO"
		UiTheme.describe(key, str(row.label), "Ligado" if on else "Desligado")
	paint.call()
	key.pressed.connect(func() -> void:
		setter.call(not bool(getter.call()))
		paint.call())
	line.add_child(key)
	return line


func _close_sheet() -> void:
	if _sheet == null:
		return
	_sheet.queue_free()
	_sheet = null


# --------------------------------------------------------------------- slots

func _refresh() -> void:
	for child in _slots.get_children():
		child.queue_free()
	for slot in range(1, SaveManager.PROFILE_COUNT + 1):
		_slots.add_child(_make_slot(SaveManager.profile_summary(slot)))
	if not SaveManager.storage_available():
		_status.text = "Este navegador não está guardando o progresso."
		_status.label_settings.font_color = UiTheme.DANGER
	_refresh_continue()


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

	var badge := UiTheme.panel(UiTheme.slate_style(used, 4))
	badge.custom_minimum_size = Vector2(36, 36)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var badge_label := UiTheme.label("%02d" % slot,
		UiTheme.SIZE_BODY, UiTheme.AMBER if used else UiTheme.PAPER_DEEP)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override(&"separation", 1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(_line("TERMINAL %d" % slot, UiTheme.SIZE_BODY, UiTheme.INK))
	if used:
		text.add_child(_line("%s TEU  •  DIA %d" % [
			GameState.fmt(float(summary.get("teus", 0.0))),
			int(summary.get("day", 1))], UiTheme.SIZE_SMALL, UiTheme.INK_SOFT))
		var flotations := int(summary.get("prestige", 0))
		text.add_child(_line(
			"%d reconstrução(ões)" % flotations if flotations > 0
				else "primeira operação",
			UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP))
	else:
		text.add_child(_line("CAIS LIVRE", UiTheme.SIZE_SMALL,
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
	UserPreferences.set_last_profile(slot)
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
	if int(UserPreferences.last_profile) == slot:
		UserPreferences.set_last_profile(0)
	_armed_delete = 0
	_status.text = "Terminal %d apagado." % slot
	_status.label_settings.font_color = UiTheme.INK_SOFT
	AudioManager.play_sfx("tap")
	_refresh()


# -------------------------------------------------------------------- layout

func _layout() -> void:
	# This root is stretched by the project viewport. Its own rect is the logical
	# canvas; the OS window can be 2x or 3x larger and must not leak into control
	# coordinates.
	var view := size
	if view.x <= 0.0 or view.y <= 0.0:
		view = get_viewport().get_visible_rect().size
	var width := clampf(view.x - 24.0, 260.0, 400.0)
	var left := (view.x - width) * 0.5
	var tight := view.y < 640.0
	var margin := 10.0 if tight else 16.0

	_layout_marquee(view, width, left, tight, margin)
	_layout_board(view, width, left, tight)
	_layout_sheet(view, width, left)


func _layout_marquee(view: Vector2, width: float, left: float, tight: bool,
		margin: float) -> void:
	var corner_size := Vector2(64, 46) if not tight else Vector2(56, 40)
	for id: String in _corner_keys:
		var key: Control = _corner_keys[id]
		key.custom_minimum_size = corner_size
		key.size = corner_size
		var corner := str(key.get_meta("corner", "tl"))
		key.position = Vector2(
			margin if corner.ends_with("l") else view.x - corner_size.x - margin,
			margin if corner.begins_with("t") else view.y - corner_size.y - margin)

	var plate_height := 62.0 if tight else 76.0
	_plate.custom_minimum_size = Vector2(width, plate_height)
	_plate.size = Vector2(width, plate_height)
	# Below the top corner keys, never under them: at 320x568 the keys and the
	# plate both want the top of the frame and the plate is the one that can move.
	_plate.position = Vector2(left,
		margin + corner_size.y + (6.0 if tight else 12.0))

	var action_width := clampf(width * 0.78, 180.0, 260.0)
	_actions.custom_minimum_size.x = action_width
	_actions.size.x = action_width
	var action_height := _actions.get_combined_minimum_size().y
	_actions.position = Vector2((view.x - action_width) * 0.5,
		clampf(view.y * 0.60 - action_height * 0.5,
			_plate.position.y + plate_height + 12.0,
			view.y - action_height - corner_size.y - margin * 3.0))

	var footer_height := _footer.get_combined_minimum_size().y
	_footer.custom_minimum_size.x = width
	_footer.size = Vector2(width, footer_height)
	_footer.position = Vector2(left,
		view.y - footer_height - margin - (2.0 if tight else 6.0))


func _layout_board(view: Vector2, width: float, left: float,
		tight: bool) -> void:
	var height := minf(view.y - 60.0, 372.0)
	_board.custom_minimum_size = Vector2(width, height)
	_board.size = Vector2(width, height)
	# PanelContainer may still be completing its first child sort when this
	# screen is built. Re-apply the authored rect after that sort so the old
	# default window height cannot survive into a smaller phone viewport.
	_board.set_deferred(&"size", Vector2(width, height))
	_board.position = Vector2(left, maxf(20.0,
		view.y - height - (14.0 if tight else 34.0)))
	UiTheme.place_clip(_clip, _board, Rect2(Vector2.ZERO, view))
	var pencil := _board_page.get_node_or_null(^"Pencil") as Control
	if pencil != null:
		pencil.position = _board.position + Vector2(
			_board.size.x - pencil.size.x - 16.0, _board.size.y - 14.0)


func _layout_sheet(view: Vector2, width: float, left: float) -> void:
	if _sheet == null:
		return
	var panel := _sheet.get_node_or_null(^"SheetPanel") as Control
	if panel == null:
		return
	panel.custom_minimum_size.x = width
	panel.size.x = width
	var height := minf(panel.get_combined_minimum_size().y, view.y - 48.0)
	panel.size = Vector2(width, height)
	panel.position = Vector2(left, clampf((view.y - height) * 0.5, 24.0,
		maxf(24.0, view.y - height - 24.0)))
