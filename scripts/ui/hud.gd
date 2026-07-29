class_name Hud
extends CanvasLayer
## Dockside readout board: TEU tally, throughput, the berth's current job,
## plus the settings and prestige keys.

signal settings_pressed
signal prestige_pressed
signal job_tick

var _teus_label: Label
var _rate_label: Label
var _shares_row: HBoxContainer
var _shares_label: Label
var _job_label: Label
var _boost_row: HBoxContainer
var _boost_label: Label
var _plate: PanelContainer
var _berth_chip: PanelContainer
var _prestige: Button
var _tick := 0.0
var _teu_visual_tick := 0.0
var _pending_teu_text := "0"
var _safe_rect := Rect2()


func _ready() -> void:
	layer = 6
	_build_plate()
	_build_keys()
	get_viewport().size_changed.connect(_layout)
	EventBus.teus_changed.connect(_on_teus)
	EventBus.cps_changed.connect(_on_cps)
	EventBus.prestiged.connect(func(_s: int) -> void: _refresh_prestige())
	_on_teus(GameState.teus)
	_on_cps(GameState.cps)
	_layout()


func _build_plate() -> void:
	_plate = PanelContainer.new()
	UiTheme.apply_panel(_plate, UiTheme.plate_style())
	_plate.position = Vector2(6, 6)
	_plate.size = Vector2(188, 48)
	_plate.custom_minimum_size = _plate.size
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(col)

	# big tally: container icon + number + unit
	var tally := HBoxContainer.new()
	tally.add_theme_constant_override(&"separation", 5)
	tally.alignment = BoxContainer.ALIGNMENT_BEGIN
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tally)

	tally.add_child(UiTheme.icon(UiTheme.Icon.TEU, 2))
	_teus_label = UiTheme.label("0", UiTheme.SIZE_TITLE, UiTheme.PLATE_TEXT)
	_teus_label.label_settings = UiTheme.settings(UiTheme.SIZE_TITLE,
		UiTheme.PLATE_TEXT, 2)
	_teus_label.custom_minimum_size.x = 86
	_teus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tally.add_child(_teus_label)
	tally.add_child(UiTheme.label("TEU", UiTheme.SIZE_SMALL, UiTheme.AMBER))

	# throughput
	var rate := HBoxContainer.new()
	rate.add_theme_constant_override(&"separation", 4)
	rate.alignment = BoxContainer.ALIGNMENT_BEGIN
	rate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rate)
	rate.add_child(UiTheme.icon(UiTheme.Icon.CLOCK))
	_rate_label = UiTheme.label("0 /s", UiTheme.SIZE_SMALL, Color8(178, 168, 186))
	rate.add_child(_rate_label)

	# golden shares, shown only after the first flotation
	_shares_row = HBoxContainer.new()
	_shares_row.add_theme_constant_override(&"separation", 3)
	_shares_row.visible = false
	_shares_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rate.add_child(_shares_row)
	_shares_row.add_child(UiTheme.icon(UiTheme.Icon.STAR))
	_shares_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER)
	_shares_row.add_child(_shares_label)

	# Berth state is deliberately outside the fixed-count plate: it can change
	# freely without moving the tally's borders, icon, unit or digits.
	_berth_chip = PanelContainer.new()
	var chip_style := UiTheme.dark_panel(5, UiTheme.TEAL)
	chip_style.content_margin_left = 4
	chip_style.content_margin_right = 4
	chip_style.content_margin_top = 2
	chip_style.content_margin_bottom = 2
	UiTheme.apply_panel(_berth_chip, chip_style)
	_berth_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_berth_chip.visible = false
	add_child(_berth_chip)

	# A plain Control deliberately breaks minimum-size propagation. Otherwise a
	# long status string makes PanelContainer wider even with clip_text=true.
	var berth_clip := Control.new()
	berth_clip.name = "Clip"
	berth_clip.clip_contents = true
	berth_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	berth_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_berth_chip.add_child(berth_clip)
	_job_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL)
	_job_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_job_label.clip_text = true
	_job_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_job_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	berth_clip.add_child(_job_label)
	_job_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# cat boost timer, only while it runs
	_boost_row = HBoxContainer.new()
	_boost_row.add_theme_constant_override(&"separation", 4)
	_boost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_boost_row.visible = false
	_boost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_boost_row)
	_boost_row.add_child(UiTheme.icon(UiTheme.Icon.PAW))
	_boost_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER)
	_boost_row.add_child(_boost_label)


func _build_keys() -> void:
	var gear := UiTheme.icon_button(UiTheme.Icon.GEAR)
	gear.name = "SettingsGear"
	gear.tooltip_text = "Ajustes"
	gear.focus_mode = Control.FOCUS_ALL
	gear.custom_minimum_size = Vector2(44, 44)
	gear.size = Vector2(44, 44)
	gear.pressed.connect(func() -> void:
		AudioManager.play_sfx("tap")
		settings_pressed.emit())
	add_child(gear)

	_prestige = UiTheme.button("ABRIR CAPITAL", "alt")
	_prestige.icon = UiTheme.icon_texture(UiTheme.Icon.STAR)
	_prestige.position = Vector2(6, 56)
	_prestige.visible = false
	_prestige.pressed.connect(_on_prestige)
	add_child(_prestige)


func _process(delta: float) -> void:
	_teu_visual_tick += delta
	if _teu_visual_tick >= 0.05:
		_teu_visual_tick = 0.0
		if _teus_label.text != _pending_teu_text:
			_teus_label.text = _pending_teu_text
	if GameState.boost_time > 0.0:
		_boost_row.visible = true
		_boost_label.text = "x%d por %ds" % [int(GameState.CAT_BOOST_MULT),
			ceili(GameState.boost_time)]
	elif _boost_row.visible:
		_boost_row.visible = false
	_tick += delta
	if _tick > 0.4:
		_tick = 0.0
		_refresh_prestige()
		job_tick.emit()


func set_job_hint(text: String) -> void:
	set_berth_status({"text": text})


func set_berth_status(status: Dictionary) -> void:
	## Public structured entry point for future berth controllers. Common forms:
	## {text}, {phase, current, total}, or {label, progress}.
	var supplied_text := status.has("text") or status.has("label")
	var text := str(status.get("text", status.get("label", status.get("phase", ""))))
	var current: Variant = status.get("current", status.get("progress", null))
	var total: Variant = status.get("total", null)
	if not supplied_text and current != null and total != null:
		text += " %s/%s" % [current, total]
	_job_label.text = text
	_berth_chip.visible = not text.is_empty()


func _on_teus(total: float) -> void:
	_pending_teu_text = GameState.fmt(total)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := _resolved_safe_rect(view)
	var compact_width := clampf(safe.size.x * 0.58, 168.0, 196.0)
	_plate.position = safe.position + Vector2(6, 6)
	_plate.size = Vector2(compact_width, 48)
	_plate.custom_minimum_size = _plate.size
	_berth_chip.position = safe.position + Vector2(6, 58)
	_berth_chip.size = Vector2(compact_width, 20)
	_berth_chip.custom_minimum_size = _berth_chip.size
	_job_label.custom_minimum_size = Vector2.ZERO
	var gear := get_node_or_null(^"SettingsGear") as Button
	if gear != null:
		gear.position = Vector2(
			safe.end.x - gear.size.x - 6.0, safe.position.y + 6.0)
	_prestige.position = safe.position + Vector2(6, 82)


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


func _on_cps(cps: float) -> void:
	_rate_label.text = GameState.fmt(cps) + " /s"
	_shares_row.visible = GameState.shares > 0
	if _shares_row.visible:
		_shares_label.text = str(GameState.shares)


func _refresh_prestige() -> void:
	var can := GameState.can_prestige()
	_prestige.visible = can
	if can:
		_prestige.text = " +%d ações" % GameState.prestige_gain()


func _on_prestige() -> void:
	prestige_pressed.emit()
