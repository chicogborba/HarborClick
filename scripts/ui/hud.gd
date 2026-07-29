class_name Hud
extends CanvasLayer
## The readout over the terminal: how much you have, how fast it grows, and
## what the berth needs next.
##
## There is deliberately no panel behind the tally any more. A 188x48 plate was
## the loudest object on a phone screen and it was fighting the port for
## attention; a short gradient at the top of the viewport buys the same
## legibility for none of the visual weight.
##
## Geometry is fixed by construction rather than by reserving a wide slot: the
## icon sits at a constant offset, the number is left-aligned so only its right
## edge moves into empty space, and the unit lives on the line below with the
## rate. Nothing in the header can shift when the digits change.

signal settings_pressed
signal prestige_pressed
signal job_tick

const TEU_REFRESH := 0.05

var _fade: TextureRect
var _teus_label: Label
var _rate_label: Label
var _shares_row: HBoxContainer
var _shares_label: Label
var _job_label: Label
var _boost_row: HBoxContainer
var _boost_label: Label
var _header: VBoxContainer
var _berth_chip: PanelContainer
var _prestige: Button
var _tick := 0.0
var _teu_visual_tick := 0.0
var _pending_teu_text := "0"
var _safe_rect := Rect2()


func _ready() -> void:
	layer = 6
	_build_header()
	_build_keys()
	get_viewport().size_changed.connect(_layout)
	EventBus.teus_changed.connect(_on_teus)
	EventBus.cps_changed.connect(_on_cps)
	EventBus.prestiged.connect(func(_s: int) -> void: _refresh_prestige())
	_on_teus(GameState.teus)
	_on_cps(GameState.cps)
	_layout()


func _build_header() -> void:
	_fade = UiTheme.top_fade(78.0)
	add_child(_fade)

	_header = VBoxContainer.new()
	_header.add_theme_constant_override(&"separation", 0)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)

	var tally := HBoxContainer.new()
	tally.add_theme_constant_override(&"separation", 5)
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(tally)
	var teu_icon := UiTheme.icon(UiTheme.Icon.TEU, 2)
	teu_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tally.add_child(teu_icon)
	_teus_label = UiTheme.label("0", UiTheme.SIZE_TITLE, UiTheme.CREAM)
	_teus_label.label_settings = UiTheme.settings(
		UiTheme.SIZE_TITLE, UiTheme.CREAM, 3)
	tally.add_child(_teus_label)

	var rate := HBoxContainer.new()
	rate.add_theme_constant_override(&"separation", 6)
	rate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(rate)
	_rate_label = UiTheme.label("0 TEU/s", UiTheme.SIZE_SMALL, UiTheme.AMBER)
	_rate_label.label_settings = UiTheme.settings(
		UiTheme.SIZE_SMALL, UiTheme.AMBER, 2)
	rate.add_child(_rate_label)

	# golden shares, shown only after the first flotation
	_shares_row = HBoxContainer.new()
	_shares_row.add_theme_constant_override(&"separation", 2)
	_shares_row.visible = false
	_shares_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rate.add_child(_shares_row)
	_shares_row.add_child(UiTheme.icon(UiTheme.Icon.STAR))
	_shares_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER)
	_shares_label.label_settings = UiTheme.settings(
		UiTheme.SIZE_SMALL, UiTheme.AMBER, 2)
	_shares_row.add_child(_shares_label)

	# cat boost timer, only while it runs
	_boost_row = HBoxContainer.new()
	_boost_row.add_theme_constant_override(&"separation", 2)
	_boost_row.visible = false
	_boost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rate.add_child(_boost_row)
	_boost_row.add_child(UiTheme.icon(UiTheme.Icon.PAW))
	_boost_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_LIGHT)
	_boost_label.label_settings = UiTheme.settings(
		UiTheme.SIZE_SMALL, UiTheme.TEAL_LIGHT, 2)
	_boost_row.add_child(_boost_label)

	# The berth state is its own chip, outside the tally, so a long status
	# string can never move the counter's geometry.
	_berth_chip = UiTheme.panel(UiTheme.slate_style(false, 3))
	_berth_chip.visible = false
	add_child(_berth_chip)

	# A plain Control deliberately breaks minimum-size propagation. Otherwise a
	# long status string makes PanelContainer wider even with clip_text=true.
	var berth_clip := Control.new()
	berth_clip.name = "Clip"
	berth_clip.clip_contents = true
	berth_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	berth_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	berth_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_berth_chip.add_child(berth_clip)
	_job_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_LIGHT)
	_job_label.clip_text = true
	_job_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	berth_clip.add_child(_job_label)
	_job_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_keys() -> void:
	var gear := UiTheme.icon_button(UiTheme.Icon.GEAR, &"alt")
	gear.name = "SettingsGear"
	gear.tooltip_text = "Ajustes"
	gear.pressed.connect(func() -> void:
		AudioManager.play_sfx("tap")
		settings_pressed.emit())
	add_child(gear)

	_prestige = UiTheme.button("ABRIR CAPITAL", &"alt")
	_prestige.icon = UiTheme.icon_texture(UiTheme.Icon.STAR)
	_prestige.visible = false
	_prestige.pressed.connect(_on_prestige)
	add_child(_prestige)


func _process(delta: float) -> void:
	_teu_visual_tick += delta
	if _teu_visual_tick >= TEU_REFRESH:
		_teu_visual_tick = 0.0
		if _teus_label.text != _pending_teu_text:
			_teus_label.text = _pending_teu_text
	if GameState.boost_time > 0.0:
		_boost_row.visible = true
		_boost_label.text = "x%d %ds" % [int(GameState.CAT_BOOST_MULT),
			ceili(GameState.boost_time)]
	elif _boost_row.visible:
		_boost_row.visible = false
	_tick += delta
	if _tick > 0.4:
		_tick = 0.0
		_refresh_prestige()
		job_tick.emit()


func readout_rect() -> Rect2:
	## Where the tally actually is on screen — the tutorial spotlight and the
	## responsive tests both ask for this instead of reaching into a node.
	return _header.get_global_rect() if _header != null else Rect2()


func set_job_hint(text: String) -> void:
	set_berth_status({"text": text})


func set_berth_status(status: Dictionary) -> void:
	## Public structured entry point for berth controllers. Common forms:
	## {text}, {phase, current, total}, or {label, progress}.
	var supplied_text := status.has("text") or status.has("label")
	var text := str(status.get("text", status.get("label", status.get("phase", ""))))
	var current: Variant = status.get("current", status.get("progress", null))
	var total: Variant = status.get("total", null)
	if not supplied_text and current != null and total != null:
		text += " %s/%s" % [current, total]
	_job_label.text = text
	_berth_chip.visible = not text.is_empty()
	_fit_berth_chip()


func _on_teus(total: float) -> void:
	_pending_teu_text = GameState.fmt(total)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := _resolved_safe_rect(view)
	_fade.position = Vector2(0, safe.position.y)
	_fade.size = Vector2(view.x, 78.0)
	_header.position = safe.position + Vector2(8, 6)
	_berth_chip.position = safe.position + Vector2(8, 48)
	_fit_berth_chip()
	var gear := get_node_or_null(^"SettingsGear") as Button
	if gear != null:
		gear.position = Vector2(
			safe.end.x - gear.size.x - 6.0, safe.position.y + 6.0)
	# Flotation is a rare, deliberate action: it lives with the other big keys
	# at the bottom of the screen instead of crowding the readout.
	_prestige.position = Vector2(
		safe.position.x + 8.0, safe.end.y - _prestige.size.y - 10.0)


func _fit_berth_chip() -> void:
	## The chip hugs its text instead of holding a fixed slab: a short phase
	## like "Descarga 8/24" should not paint a 200px bar across the port.
	if _berth_chip == null or _job_label == null:
		return
	var safe := _resolved_safe_rect(get_viewport().get_visible_rect().size)
	var text_width := UiTheme.FONT.get_string_size(_job_label.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x
	var width := clampf(text_width + 14.0, 80.0, safe.size.x - 16.0)
	_job_label.custom_minimum_size = Vector2.ZERO
	_berth_chip.size = Vector2(width, 18)
	_berth_chip.custom_minimum_size = _berth_chip.size


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


func _on_cps(cps: float) -> void:
	_rate_label.text = GameState.fmt(cps) + " TEU/s"
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
