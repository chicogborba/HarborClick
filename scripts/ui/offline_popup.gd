class_name OfflinePopup
extends CanvasLayer
## "While you were away" board, shown once when idle income piled up.

func _ready() -> void:
	layer = 10
	if SaveManager.offline_earnings <= 0.0:
		queue_free()
		return
	_build(SaveManager.offline_earnings)
	SaveManager.offline_earnings = 0.0


func _build(amount: float) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.09, 0.6)
	dim.size = Vector2(PortLayout.WORLD_W, PortLayout.VIEW_H)
	add_child(dim)

	var panel := PanelContainer.new()
	UiTheme.apply_panel(panel, UiTheme.panel_style())
	panel.position = Vector2(26, 160)
	panel.custom_minimum_size = Vector2(PortLayout.WORLD_W - 52, 0)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	panel.add_child(col)

	var title := UiTheme.label("O PORTO NÃO DORMIU", UiTheme.SIZE_BODY, UiTheme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var body := UiTheme.label("Os guindastes trabalharam sem você:",
		UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 5)
	col.add_child(row)
	row.add_child(UiTheme.icon(UiTheme.Icon.TEU, 2))
	row.add_child(UiTheme.label(GameState.fmt(amount) + " TEU",
		UiTheme.SIZE_TITLE, UiTheme.INK))

	var button := UiTheme.button("BELEZA")
	button.pressed.connect(func() -> void:
		AudioManager.play_sfx("tap")
		queue_free())
	col.add_child(button)

	panel.modulate.a = 0.0
	panel.pivot_offset = Vector2(panel.custom_minimum_size.x / 2.0, 50.0)
	panel.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel()
	tween.tween_property(panel, "modulate:a", 1.0, 0.22)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
