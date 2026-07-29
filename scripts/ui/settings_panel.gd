class_name SettingsPanel
extends CanvasLayer
## Options board: audio toggles, day-length readout and a save wipe.

signal open_changed(opened: bool)

var _dim: ColorRect
var _panel: PanelContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _music_btn: Button
var _sfx_btn: Button
var _motion_btn: Button
var _haptics_btn: Button
var _numbers_btn: Button
var _ui_scale_btn: Button
var _fullscreen_btn: Button
var _confirm_wipe := false
var _wipe_btn: Button
var _safe_rect := Rect2()


func _ready() -> void:
	layer = 11
	_build()
	get_viewport().size_changed.connect(_layout)
	visible = false


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.06, 0.05, 0.09, 0.6)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch and event.pressed) \
				or (event is InputEventMouseButton and event.pressed):
			close())
	add_child(_dim)

	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.dark_panel())
	add_child(_panel)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override(&"separation", 6)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	var title := UiTheme.label("AJUSTES", UiTheme.SIZE_TITLE, UiTheme.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	_music_btn = _compact_button()
	_music_btn.pressed.connect(_toggle_music)
	_content.add_child(_music_btn)

	_sfx_btn = _compact_button()
	_sfx_btn.pressed.connect(_toggle_sfx)
	_content.add_child(_sfx_btn)

	_motion_btn = _compact_button()
	_motion_btn.pressed.connect(func() -> void:
		UserPreferences.set_reduce_motion(not UserPreferences.reduce_motion)
		_refresh())
	_content.add_child(_motion_btn)

	_haptics_btn = _compact_button()
	_haptics_btn.pressed.connect(func() -> void:
		UserPreferences.set_haptics(not UserPreferences.haptics)
		_refresh())
	_content.add_child(_haptics_btn)

	_numbers_btn = _compact_button()
	_numbers_btn.pressed.connect(func() -> void:
		UserPreferences.set_floating_numbers(not UserPreferences.floating_numbers)
		_refresh())
	_content.add_child(_numbers_btn)

	_ui_scale_btn = _compact_button()
	_ui_scale_btn.pressed.connect(func() -> void:
		UserPreferences.cycle_ui_scale()
		_refresh())
	_content.add_child(_ui_scale_btn)

	_fullscreen_btn = _compact_button()
	_fullscreen_btn.pressed.connect(func() -> void:
		UserPreferences.set_fullscreen(not UserPreferences.fullscreen)
		_refresh())
	_content.add_child(_fullscreen_btn)

	var sep := UiTheme.label(
		"Um dia no porto dura 12 minutos.\nDias de neblina rendem menos.",
		UiTheme.SIZE_SMALL, UiTheme.PLATE_TEXT)
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(sep)

	_wipe_btn = _compact_button("APAGAR PROGRESSO", "off")
	_wipe_btn.pressed.connect(_on_wipe)
	_content.add_child(_wipe_btn)

	var close_btn := _compact_button("FECHAR")
	close_btn.pressed.connect(close)
	_content.add_child(close_btn)


func _compact_button(text: String = "", kind: String = "alt") -> Button:
	var button := UiTheme.button(text, kind, UiTheme.SIZE_SMALL)
	button.custom_minimum_size.y = 28.0
	return button


func open() -> void:
	_confirm_wipe = false
	_wipe_btn.text = "APAGAR PROGRESSO"
	_refresh()
	visible = true
	open_changed.emit(true)
	_layout()
	if not UserPreferences.can_animate():
		_panel.modulate.a = 1.0
		_panel.scale = Vector2.ONE
		return
	_panel.modulate.a = 0.0
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.16)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not visible:
		return
	AudioManager.play_sfx("tap")
	visible = false
	open_changed.emit(false)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		close()
		get_viewport().set_input_as_handled()


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := _resolved_safe_rect(view)
	var width := minf(safe.size.x - 24.0, 360.0)
	_content.custom_minimum_size.x = width - 16.0
	var desired_height := _content.get_combined_minimum_size().y + 16.0
	var height := minf(desired_height, maxf(180.0, safe.size.y - 24.0))
	_scroll.custom_minimum_size = Vector2(width - 16.0, height - 16.0)
	_panel.custom_minimum_size = Vector2(width, height)
	_panel.size = Vector2(width, height)
	_panel.position = safe.position + Vector2(
		(safe.size.x - width) * 0.5,
		(safe.size.y - _panel.size.y) * 0.5)


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get(
		"safe_rect", Rect2(Vector2.ZERO, view))
	_layout()


func _resolved_safe_rect(view: Vector2) -> Rect2:
	var viewport_rect := Rect2(Vector2.ZERO, view)
	if _safe_rect.size.x <= 0.0 or _safe_rect.size.y <= 0.0:
		return viewport_rect
	var clipped := _safe_rect.intersection(viewport_rect)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 \
		else viewport_rect


func _refresh() -> void:
	_music_btn.text = "MÚSICA: %s" % ("LIGADA" if AudioManager.music_on else "DESLIGADA")
	_sfx_btn.text = "EFEITOS: %s" % ("LIGADOS" if AudioManager.sfx_on else "DESLIGADOS")
	_motion_btn.text = "MOVIMENTO: %s" % ("REDUZIDO" if UserPreferences.reduce_motion else "NORMAL")
	_haptics_btn.text = "VIBRAÇÃO: %s" % ("LIGADA" if UserPreferences.haptics else "DESLIGADA")
	_numbers_btn.text = "NÚMEROS FLUTUANTES: %s" % ("LIGADOS" if UserPreferences.floating_numbers else "DESLIGADOS")
	_ui_scale_btn.text = "ESCALA DA UI: %d%%" % roundi(UserPreferences.ui_scale * 100.0)
	_fullscreen_btn.text = "TELA CHEIA: %s" % ("LIGADA" if UserPreferences.fullscreen else "DESLIGADA")


func _toggle_music() -> void:
	AudioManager.set_music_on(not AudioManager.music_on)
	_refresh()


func _toggle_sfx() -> void:
	AudioManager.set_sfx_on(not AudioManager.sfx_on)
	AudioManager.play_sfx("tap")
	_refresh()


func _on_wipe() -> void:
	if not _confirm_wipe:
		_confirm_wipe = true
		_wipe_btn.text = "TEM CERTEZA?"
		AudioManager.play_sfx("deny")
		return
	SaveManager.wipe()
	get_tree().reload_current_scene()
