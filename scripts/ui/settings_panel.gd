class_name SettingsPanel
extends CanvasLayer
## Options board: audio toggles, day-length readout and a save wipe.

const W := PortLayout.WORLD_W
const H := PortLayout.VIEW_H

var _dim: ColorRect
var _panel: PanelContainer
var _music_btn: Button
var _sfx_btn: Button
var _confirm_wipe := false
var _wipe_btn: Button


func _ready() -> void:
	layer = 11
	_build()
	visible = false


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.06, 0.05, 0.09, 0.6)
	_dim.size = Vector2(W, H)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			close())
	add_child(_dim)

	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.panel_style())
	_panel.position = Vector2(24, 120)
	_panel.custom_minimum_size = Vector2(W - 48, 0)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 7)
	_panel.add_child(col)

	var title := UiTheme.label("AJUSTES", UiTheme.SIZE_TITLE, UiTheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	_music_btn = UiTheme.button("", "alt")
	_music_btn.pressed.connect(_toggle_music)
	col.add_child(_music_btn)

	_sfx_btn = UiTheme.button("", "alt")
	_sfx_btn.pressed.connect(_toggle_sfx)
	col.add_child(_sfx_btn)

	var sep := UiTheme.label(
		"Um dia no porto dura 12 minutos.\nDias de neblina rendem menos.",
		UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sep)

	_wipe_btn = UiTheme.button("APAGAR PROGRESSO", "off")
	_wipe_btn.pressed.connect(_on_wipe)
	col.add_child(_wipe_btn)

	var close_btn := UiTheme.button("FECHAR")
	close_btn.pressed.connect(close)
	col.add_child(close_btn)


func open() -> void:
	_confirm_wipe = false
	_wipe_btn.text = "APAGAR PROGRESSO"
	_refresh()
	visible = true
	_panel.modulate.a = 0.0
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.16)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	AudioManager.play_sfx("tap")
	visible = false


func _refresh() -> void:
	_music_btn.text = "MÚSICA: %s" % ("LIGADA" if AudioManager.music_on else "DESLIGADA")
	_sfx_btn.text = "EFEITOS: %s" % ("LIGADOS" if AudioManager.sfx_on else "DESLIGADOS")


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
