class_name SettingsPanel
extends CanvasLayer
## Options board: audio, presentation, and the destructive save wipe.
##
## The previous version was eight identical full-width keys stacked in a
## column, so nothing was findable — every option had the same weight and the
## wipe button looked exactly like the music toggle. Options are grouped under
## captions now, each row reads "name ... current value", and the only two
## buttons that are not toggles (replay the tutorial, wipe the save) sit apart
## from them with their own colour.

signal open_changed(opened: bool)
signal tutorial_replay_requested

const ROW_HEIGHT := 24.0
const VALUE_WIDTH := 116.0

var _dim: ColorRect
var _panel: PanelContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _music_btn: Button
var _sfx_btn: Button
var _motion_btn: Button
var _numbers_btn: Button
var _ui_scale_btn: Button
var _fullscreen_btn: Button
var _confirm_wipe := false
var _wipe_btn: Button
var _tutorial_btn: Button
var _safe_rect := Rect2()
var _focus_return: Control
var _backup_status: Label
var _confirm_import := false


func _ready() -> void:
	layer = 11
	_build()
	get_viewport().size_changed.connect(_layout)
	visible = false


func _build() -> void:
	_dim = UiTheme.scrim(0.62)
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch and event.pressed) \
				or (event is InputEventMouseButton and event.pressed):
			close())
	add_child(_dim)

	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.board_style(9))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	UiTheme.style_scroll(_scroll)
	_panel.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override(&"separation", 3)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	var title := UiTheme.label("AJUSTES", UiTheme.SIZE_TITLE, UiTheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	_content.add_child(_caption("SOM"))
	_music_btn = _option_row("Música", _toggle_music)
	_sfx_btn = _option_row("Efeitos", _toggle_sfx)

	_content.add_child(_caption("APRESENTAÇÃO"))
	_motion_btn = _option_row("Movimento", func() -> void:
		UserPreferences.set_reduce_motion(not UserPreferences.reduce_motion)
		_refresh())
	_numbers_btn = _option_row("Números flutuantes", func() -> void:
		UserPreferences.set_floating_numbers(not UserPreferences.floating_numbers)
		_refresh())
	_ui_scale_btn = _option_row("Escala da interface", func() -> void:
		UserPreferences.cycle_ui_scale()
		_refresh())
	_fullscreen_btn = _option_row("Tela cheia", func() -> void:
		UserPreferences.set_fullscreen(not UserPreferences.fullscreen)
		_refresh())

	_content.add_child(_caption("PORTO"))
	_tutorial_btn = _wide_button("REVER TUTORIAL", &"ghost")
	_tutorial_btn.pressed.connect(func() -> void: tutorial_replay_requested.emit())
	_content.add_child(_tutorial_btn)
	var note := UiTheme.label(
		"Um dia no porto dura 12 minutos.\nDias de neblina rendem menos.",
		UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(note)

	_content.add_child(_caption("SAVE"))
	var backup_row := HBoxContainer.new()
	backup_row.add_theme_constant_override(&"separation", 4)
	_content.add_child(backup_row)
	var export_btn := UiTheme.button("EXPORTAR", &"ghost", UiTheme.SIZE_SMALL)
	export_btn.custom_minimum_size.y = 26.0
	export_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.describe(export_btn, "Exportar o save",
		"Copia o save para a área de transferência e grava uma cópia em disco.")
	export_btn.pressed.connect(_on_export)
	backup_row.add_child(export_btn)
	var import_btn := UiTheme.button("IMPORTAR", &"ghost", UiTheme.SIZE_SMALL)
	import_btn.custom_minimum_size.y = 26.0
	import_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.describe(import_btn, "Importar um save",
		"Lê o save da área de transferência e substitui o progresso atual.")
	import_btn.pressed.connect(_on_import)
	backup_row.add_child(import_btn)
	_backup_status = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_backup_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_backup_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_backup_status)

	_content.add_child(UiTheme.spacer(4.0))
	_content.add_child(UiTheme.divider())
	_content.add_child(UiTheme.spacer(2.0))

	# The only irreversible action on the board carries the only warning colour
	# and needs a second press to arm.
	_wipe_btn = _wide_button("APAGAR PROGRESSO", &"danger")
	_wipe_btn.pressed.connect(_on_wipe)
	_content.add_child(_wipe_btn)

	var close_btn := _wide_button("FECHAR", &"amber")
	close_btn.pressed.connect(close)
	_content.add_child(close_btn)


func _caption(text: String) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override(&"separation", 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiTheme.spacer(3.0))
	row.add_child(UiTheme.label(text, UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP))
	row.add_child(UiTheme.divider())
	return row


func _option_row(name_text: String, on_press: Callable) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.custom_minimum_size.y = ROW_HEIGHT
	_content.add_child(row)

	var label := UiTheme.label(name_text, UiTheme.SIZE_SMALL, UiTheme.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var value := UiTheme.button("", &"alt", UiTheme.SIZE_SMALL)
	value.custom_minimum_size = Vector2(VALUE_WIDTH, ROW_HEIGHT)
	value.tooltip_text = name_text
	# The key's own text is only the value ("LIGADA"); on its own that says
	# nothing, so the accessible name carries the row it belongs to.
	value.set_meta("row_name", name_text)
	UiTheme.describe(value, name_text)
	value.pressed.connect(on_press)
	row.add_child(value)
	return value


func _wide_button(text: String, kind: StringName) -> Button:
	var button := UiTheme.button(text, kind, UiTheme.SIZE_SMALL)
	button.custom_minimum_size.y = 28.0
	return button


func open() -> void:
	_confirm_wipe = false
	_confirm_import = false
	_wipe_btn.text = "APAGAR PROGRESSO"
	UiTheme.style_button(_wipe_btn, &"danger")
	# A browser that refuses site data would otherwise let the player build a
	# run for an hour and lose it on reload without ever being warned.
	if SaveManager.storage_available():
		_backup_status.text = ""
	else:
		_backup_status.text = "Este navegador não está guardando o progresso. Exporte o save antes de sair."
		_backup_status.label_settings.font_color = UiTheme.DANGER
	_refresh()
	_focus_return = get_viewport().gui_get_focus_owner()
	visible = true
	open_changed.emit(true)
	_layout()
	UiTheme.focus_first(_panel)
	if not UserPreferences.can_animate():
		_panel.modulate.a = 1.0
		_panel.scale = Vector2.ONE
		return
	_panel.modulate.a = 0.0
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.94, 0.94)
	var tween := create_tween().set_parallel()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.16)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not visible:
		return
	AudioManager.play_sfx("tap")
	visible = false
	UiTheme.restore_focus(_focus_return)
	_focus_return = null
	open_changed.emit(false)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		close()
		get_viewport().set_input_as_handled()


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := _resolved_safe_rect(view)
	var width := minf(safe.size.x - 24.0, 344.0)
	_content.custom_minimum_size.x = width - 22.0
	var desired_height := _content.get_combined_minimum_size().y + 22.0
	var height := minf(desired_height, maxf(180.0, safe.size.y - 24.0))
	_scroll.custom_minimum_size = Vector2(width - 22.0, height - 22.0)
	_panel.custom_minimum_size = Vector2(width, height)
	_panel.size = Vector2(width, height)
	_panel.position = safe.position + Vector2(
		(safe.size.x - width) * 0.5,
		(safe.size.y - _panel.size.y) * 0.5)


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, view))
	_layout()


func _resolved_safe_rect(view: Vector2) -> Rect2:
	var viewport_rect := Rect2(Vector2.ZERO, view)
	if _safe_rect.size.x <= 0.0 or _safe_rect.size.y <= 0.0:
		return viewport_rect
	var clipped := _safe_rect.intersection(viewport_rect)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 \
		else viewport_rect


func _refresh() -> void:
	_music_btn.text = "LIGADA" if AudioManager.music_on else "DESLIGADA"
	_sfx_btn.text = "LIGADOS" if AudioManager.sfx_on else "DESLIGADOS"
	_motion_btn.text = "REDUZIDO" if UserPreferences.reduce_motion else "NORMAL"
	_numbers_btn.text = "LIGADOS" if UserPreferences.floating_numbers else "DESLIGADOS"
	_ui_scale_btn.text = "%d%%" % roundi(UserPreferences.ui_scale * 100.0)
	_fullscreen_btn.text = "LIGADA" if UserPreferences.fullscreen else "DESLIGADA"
	# An "off" state must not be signalled by colour alone; the word already
	# says it, and the key drops to the muted style so it also reads by shape.
	for pair in [[_music_btn, AudioManager.music_on], [_sfx_btn, AudioManager.sfx_on],
			[_numbers_btn, UserPreferences.floating_numbers],
			[_fullscreen_btn, UserPreferences.fullscreen]]:
		UiTheme.style_button(pair[0], &"alt" if bool(pair[1]) else &"off")
	for button in [_music_btn, _sfx_btn, _motion_btn, _numbers_btn,
			_ui_scale_btn, _fullscreen_btn]:
		button.accessibility_name = "%s: %s" % [
			str(button.get_meta("row_name", "")), button.text]


func _toggle_music() -> void:
	AudioManager.set_music_on(not AudioManager.music_on)
	_refresh()


func _toggle_sfx() -> void:
	AudioManager.set_sfx_on(not AudioManager.sfx_on)
	AudioManager.play_sfx("tap")
	_refresh()


func _on_export() -> void:
	## Clipboard first: on the web build it is the only channel out of the
	## sandbox, and on desktop the file copy is the one you can actually keep.
	DisplayServer.clipboard_set(SaveManager.export_text())
	var wrote := SaveManager.export_to_file()
	_backup_status.text = "Save copiado. Cópia em %s" % SaveManager.EXPORT_PATH \
		if wrote else "Save copiado para a área de transferência."
	_backup_status.label_settings.font_color = UiTheme.TEAL_DEEP
	AudioManager.play_sfx("tap")


func _on_import() -> void:
	## Two presses: this overwrites the run in progress and there is no undo.
	if not _confirm_import:
		_confirm_import = true
		_backup_status.text = "Isso substitui o progresso atual. Toque de novo."
		_backup_status.label_settings.font_color = UiTheme.DANGER
		AudioManager.play_sfx("deny")
		return
	_confirm_import = false
	var result := SaveManager.import_text(DisplayServer.clipboard_get())
	if bool(result.get("ok", false)):
		_backup_status.text = "Save importado."
		_backup_status.label_settings.font_color = UiTheme.TEAL_DEEP
		AudioManager.play_sfx("build")
		get_tree().reload_current_scene()
		return
	_backup_status.text = str(result.get("error", "Falha ao importar."))
	_backup_status.label_settings.font_color = UiTheme.DANGER
	AudioManager.play_sfx("deny")


func _on_wipe() -> void:
	if not _confirm_wipe:
		_confirm_wipe = true
		_wipe_btn.text = "TEM CERTEZA? TOQUE DE NOVO"
		AudioManager.play_sfx("deny")
		return
	SaveManager.wipe()
	get_tree().reload_current_scene()
