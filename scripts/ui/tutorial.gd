class_name Tutorial
extends CanvasLayer
## Seu Waldemar walks new players through the first minute.
## Steps advance on real progress, never on a timer alone.

signal finished

const STEPS := [
	{
		"key": "tut.hello",
		"advance": "tap_box",
	},
	{
		"key": "tut.tap_ship",
		"advance": "clicks", "count": 8,
	},
	{
		"key": "tut.teu",
		"advance": "tap_box",
	},
	{
		"key": "tut.shop",
		"advance": "structure",
	},
	{
		"key": "tut.passive",
		"advance": "tap_box",
	},
	{
		"key": "tut.pan",
		"advance": "tap_box",
	},
]

var _panel: PanelContainer
var _label: Label
var _portrait: AnimatedSprite2D
var _hint: Label
var _step := 0
var _clicks := 0
var _active := false
var _safe_rect := Rect2(Vector2.ZERO, Vector2(PortLayout.WORLD_W, PortLayout.VIEW_H))
var _has_shell_metrics := false


func _ready() -> void:
	layer = 9
	_build()
	get_viewport().size_changed.connect(_on_viewport_resized)
	visible = false


func start() -> void:
	if GameState.flags.get("tutorial_done", false):
		queue_free()
		return
	_active = true
	visible = true
	_step = 0
	EventBus.manual_reward_committed.connect(_on_click)
	EventBus.structure_bought.connect(_on_structure)
	_show_step()


func _build() -> void:
	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.board_style(8))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	var portrait_box := PanelContainer.new()
	UiTheme.apply_panel(portrait_box, UiTheme.well_style(2))
	portrait_box.custom_minimum_size = Vector2(32, 40)
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait_box)

	_portrait = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	var tex: Texture2D = preload("res://assets/sprites/foreman_sheet.png")
	frames.set_animation_speed(&"default", 2.4)
	for i in 3:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 12, 0, 12, 16)
		frames.add_frame(&"default", at)
	_portrait.sprite_frames = frames
	_portrait.centered = false
	_portrait.scale = Vector2(2, 2)
	_portrait.position = Vector2(4, 4)
	_portrait.play()
	portrait_box.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = 230
	col.add_child(_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 6)
	col.add_child(footer)

	_hint = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER_DEEP)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_hint)

	var skip := UiTheme.button("PULAR", &"ghost")
	skip.pressed.connect(_finish)
	footer.add_child(skip)
	_layout()


func _show_step() -> void:
	var step: Dictionary = STEPS[_step]
	_label.text = Loc.t(str(step.key))
	match step.advance:
		"tap_box":
			_hint.text = "▸ " + Loc.t("tut.hint.tap")
		"clicks":
			_hint.text = "▸ " + Loc.t("tut.hint.ship", {"count": str(step.count)})
		"structure":
			_hint.text = "▸ " + Loc.t("tut.hint.buy")
	if not UserPreferences.can_animate():
		_panel.modulate.a = 1.0
		_panel.scale = Vector2.ONE
		return
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.22)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _input(event: InputEvent) -> void:
	if not _active or not visible:
		return
	if (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed):
		var step: Dictionary = STEPS[_step]
		if step.advance != "tap_box":
			return
		var local := _panel.get_global_rect()
		if local.has_point(event.position):
			_advance()
			get_viewport().set_input_as_handled()


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect", _safe_rect)
	_has_shell_metrics = true
	_layout()


func _on_viewport_resized() -> void:
	if not _has_shell_metrics:
		_safe_rect = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_layout()


func _layout() -> void:
	if _panel == null:
		return
	if _safe_rect.size == Vector2.ZERO:
		_safe_rect = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var width := minf(_safe_rect.size.x - 16.0, 420.0)
	_panel.custom_minimum_size = Vector2(width, 0)
	_panel.size = Vector2(width, _panel.get_combined_minimum_size().y)
	_panel.position = Vector2(
		_safe_rect.get_center().x - width * 0.5,
		_safe_rect.end.y - _panel.size.y - 10.0)
	_label.custom_minimum_size.x = maxf(150.0, width - 78.0)


func _on_click(_payload: Dictionary) -> void:
	if not _active:
		return
	var step: Dictionary = STEPS[_step]
	if step.advance != "clicks":
		return
	_clicks += 1
	var left: int = maxi(0, int(step.count) - _clicks)
	_hint.text = "▸ " + Loc.t("tut.hint.ship", {"count": str(left)})
	if left == 0:
		_advance()


func _on_structure(id: String, _count: int) -> void:
	if not _active:
		return
	if STEPS[_step].advance == "structure" and id == "estivador":
		_advance()


func _advance() -> void:
	_step += 1
	_clicks = 0
	if _step >= STEPS.size():
		_finish()
		return
	AudioManager.play_sfx("tap")
	_show_step()


func _finish() -> void:
	_active = false
	GameState.flags["tutorial_done"] = true
	if not UserPreferences.can_animate():
		visible = false
		finished.emit()
		EventBus.notification_requested.emit({"id": "tutorial_done", "kind": &"tutorial", "priority": 2, "text": Loc.t("tut.done")})
		return
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		visible = false
		finished.emit()
		EventBus.notification_requested.emit({"id": "tutorial_done", "kind": &"tutorial", "priority": 2, "text": Loc.t("tut.done")}))
