class_name Hud
extends CanvasLayer
## Dockside readout board: TEU tally, throughput, the berth's current job,
## plus the settings and prestige keys.

signal settings_pressed
signal job_tick

const W := PortLayout.WORLD_W

var _teus_label: Label
var _rate_label: Label
var _shares_row: HBoxContainer
var _shares_label: Label
var _job_label: Label
var _boost_row: HBoxContainer
var _boost_label: Label
var _plate: PanelContainer
var _prestige: Button
var _pulse := 0.0
var _tick := 0.0


func _ready() -> void:
	layer = 6
	_build_plate()
	_build_keys()
	EventBus.teus_changed.connect(_on_teus)
	EventBus.cps_changed.connect(_on_cps)
	EventBus.prestiged.connect(func(_s: int) -> void: _refresh_prestige())
	_on_teus(GameState.teus)
	_on_cps(GameState.cps)


func _build_plate() -> void:
	_plate = PanelContainer.new()
	UiTheme.apply_panel(_plate, UiTheme.plate_style())
	_plate.position = Vector2(6, 6)
	_plate.size = Vector2(W - 46, 58)
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
	tally.alignment = BoxContainer.ALIGNMENT_CENTER
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tally)

	tally.add_child(UiTheme.icon(UiTheme.Icon.TEU, 2))
	_teus_label = UiTheme.label("0", UiTheme.SIZE_TITLE, UiTheme.PLATE_TEXT)
	_teus_label.label_settings = UiTheme.settings(UiTheme.SIZE_TITLE,
		UiTheme.PLATE_TEXT, 2)
	tally.add_child(_teus_label)
	tally.add_child(UiTheme.label("TEU", UiTheme.SIZE_SMALL, UiTheme.AMBER))

	# throughput
	var rate := HBoxContainer.new()
	rate.add_theme_constant_override(&"separation", 4)
	rate.alignment = BoxContainer.ALIGNMENT_CENTER
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

	# what the berth wants from you right now
	_job_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL)
	_job_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_job_label.visible = false
	col.add_child(_job_label)

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
	gear.position = Vector2(W - 34, 6)
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
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 4.0)
		_plate.pivot_offset = _plate.size / 2.0
		_plate.scale = Vector2.ONE * (1.0 + _pulse * 0.03)
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
	_job_label.text = text
	_job_label.visible = text != ""


func _on_teus(total: float) -> void:
	_teus_label.text = GameState.fmt(total)
	_pulse = 0.6


func _on_cps(cps: float) -> void:
	_rate_label.text = GameState.fmt(cps) + " /s"
	_shares_row.visible = GameState.shares > 0
	if _shares_row.visible:
		_shares_label.text = str(GameState.shares)


func _refresh_prestige() -> void:
	var can := GameState.can_prestige()
	_prestige.visible = can
	if can:
		_prestige.text = " +%d ações" % (GameState.prestige_gain() - GameState.shares)


func _on_prestige() -> void:
	if GameState.do_prestige():
		AudioManager.play_sfx("prestige")
		EventBus.toast.emit("Porto aberto na bolsa! Bônus permanente aplicado.")
		_refresh_prestige()
