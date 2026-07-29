class_name OfflinePopup
extends CanvasLayer
## "While you were away" board, shown once when idle income piled up.

var _dim: ColorRect
var _panel: PanelContainer

func _ready() -> void:
	layer = 10
	if SaveManager.offline_earnings <= 0.0:
		queue_free()
		return
	_build(SaveManager.offline_earnings)
	SaveManager.offline_earnings = 0.0
	get_viewport().size_changed.connect(_layout)


func _build(amount: float) -> void:
	_dim = UiTheme.scrim(0.62)
	add_child(_dim)

	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.board_style(10))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	_panel.add_child(col)

	var title := UiTheme.label("O PORTO NÃO DORMIU", UiTheme.SIZE_BODY, UiTheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var body := UiTheme.label("Os guindastes trabalharam sem você:",
		UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(body)

	var readout := UiTheme.panel(UiTheme.slate_style(true, 6))
	col.add_child(readout)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.add_child(row)
	row.add_child(UiTheme.icon(UiTheme.Icon.TEU, 2))
	row.add_child(UiTheme.label(GameState.fmt(amount) + " TEU",
		UiTheme.SIZE_TITLE, UiTheme.AMBER))

	var button := UiTheme.button("BELEZA")
	button.pressed.connect(func() -> void:
		AudioManager.play_sfx("tap")
		queue_free())
	col.add_child(button)

	_layout()
	_panel.modulate.a = 0.0
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.22)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func apply_view_metrics(metrics: Dictionary) -> void:
	_layout(metrics.get("safe_rect", Rect2(Vector2.ZERO,
		get_viewport().get_visible_rect().size)))


func _layout(safe_rect: Rect2 = Rect2()) -> void:
	if _panel == null:
		return
	if safe_rect.size == Vector2.ZERO:
		safe_rect = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var width := minf(safe_rect.size.x - 32.0, 360.0)
	_panel.custom_minimum_size = Vector2(width, 0)
	_panel.size = Vector2(width, _panel.get_combined_minimum_size().y)
	_panel.position = safe_rect.position + (safe_rect.size - _panel.size) * 0.5
