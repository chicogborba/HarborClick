class_name RouteMap
extends CanvasLayer
## PORTOS: a planet you can spin, the three ports on it, and the one you tap.
##
## This board used to be a flat chart with two tabs — ports, and trade lanes to
## buy. The lanes now open by themselves as the port grows (`GameState.
## _grant_routes`), so the board is only about where the operator works: a
## pixel globe (`Globe`) with Brazil, the United States and China picked out,
## a pin per port, and under it the card of whichever port is selected — its
## flag, how it plays, and one key: the price, VIAJAR, or "você está aqui".
##
## Like every live board, it is built once and rewritten in place, throttled;
## the other ports' wallets are read from their files once per open.
## The class keeps its old name so Main, the rail and the tests did not move.

signal open_changed(opened: bool)
## Asks Main to sail to another open port. The board never changes scene itself.
signal travel_requested(port: StringName)

const FLAGS := preload("res://assets/sprites/ui_flags.png")
const FLAG_SIZE := Vector2(16, 11)
const REFRESH_INTERVAL := 0.25

var _backdrop: ColorRect
var _sheet: PanelContainer
var _clip: TextureRect
var _title: Label
var _close_button: Button
var _column: VBoxContainer
var _space: PanelContainer
var _globe: Globe
var _chips: HBoxContainer
var _chip_keys: Dictionary = {}
var _card: PanelContainer
var _flag: TextureRect
var _name: Label
var _perk: Label
var _state: Label
var _go: Button
var _network: Label
var _selected: StringName = &""
var _open := false
var _safe_rect := Rect2()
var _rail: CommandRail
var _focus_return: Control
var _dirty := false
var _refresh_timer := 0.0
## Each open port's wallet, read once when the board opens.
var _port_wallets: Dictionary = {}


func _ready() -> void:
	layer = 12
	_backdrop = UiTheme.scrim(0.76)
	_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventScreenTouch and event.pressed):
			close())
	add_child(_backdrop)

	_sheet = PanelContainer.new()
	UiTheme.apply_panel(_sheet, UiTheme.board_style(9))
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	_clip = UiTheme.clip_badge()
	add_child(_clip)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 5)
	_sheet.add_child(_column)
	var header := UiTheme.header("", close, UiTheme.Icon.GLOBE)
	_column.add_child(header.root)
	_title = header.title
	_close_button = header.close

	# Space behind the planet: the HUD's navy with a scatter of stars.
	_space = UiTheme.panel(UiTheme.glass_style(2), false)
	_space.custom_minimum_size.y = 236.0
	_column.add_child(_space)
	var stars := _Stars.new()
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_space.add_child(stars)
	_globe = Globe.new()
	_globe.name = "Globe"
	_globe.port_picked.connect(_select)
	_space.add_child(_globe)

	# One chip per port under the planet: the same choice without a pin hunt.
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override(&"separation", 4)
	_column.add_child(_chips)
	for port in PortDB.PORTS:
		var id := StringName(port.id)
		var chip := UiTheme.button("", &"steel", UiTheme.SIZE_SMALL)
		chip.name = "Chip_%s" % String(id)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size.y = 26.0
		chip.icon = _flag_texture(int(port.get("flag", 0)))
		chip.expand_icon = false
		chip.clip_text = true
		# A flag keeps its own colours on the amber key too.
		for key: StringName in [&"icon_normal_color", &"icon_hover_color",
				&"icon_pressed_color", &"icon_focus_color", &"icon_disabled_color"]:
			chip.add_theme_color_override(key, Color.WHITE)
		chip.pressed.connect(_select.bind(id))
		_chips.add_child(chip)
		_chip_keys[id] = chip

	_card = UiTheme.panel(UiTheme.card_style(&"normal"), false)
	_card.name = "PortCard"
	_column.add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	_card.add_child(row)
	_flag = TextureRect.new()
	_flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flag.custom_minimum_size = FLAG_SIZE * 2.0
	_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_flag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_flag)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	_name = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK)
	_name.clip_text = true
	_name.custom_minimum_size.x = 0.0
	text.add_child(_name)
	_perk = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_perk.custom_minimum_size.x = 0.0
	text.add_child(_perk)
	_state = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state.custom_minimum_size.x = 0.0
	text.add_child(_state)
	_go = UiTheme.button("", &"amber", UiTheme.SIZE_SMALL)
	_go.name = "Go"
	_go.custom_minimum_size = Vector2(76, 32)
	_go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_go.pressed.connect(_on_go)
	row.add_child(_go)

	_network = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_network.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_network.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_network.custom_minimum_size.x = 0.0
	_column.add_child(_network)

	EventBus.teus_changed.connect(func(_t: float) -> void: _dirty = true)
	Loc.language_changed.connect(func(_code: StringName) -> void:
		_apply_language()
		_dirty = true)
	_column.minimum_size_changed.connect(_layout)
	_apply_language()
	_select(PortDB.active, false)
	_layout()


func set_rail(rail: CommandRail) -> void:
	_rail = rail


func _apply_language() -> void:
	_title.text = Loc.t("ports.title")
	UiTheme.fit_title(_title)
	UiTheme.describe(_close_button, Loc.t("routes.close_name"))
	_close_button.tooltip_text = Loc.t("common.close_hint")
	for id: StringName in _chip_keys:
		(_chip_keys[id] as Button).text = str(PortDB.get_port(id).get("name", ""))


func open() -> void:
	_read_port_wallets()
	_open = true
	_focus_return = get_viewport().gui_get_focus_owner()
	_refresh_timer = 0.0
	_dirty = false
	_select(PortDB.active, false)
	_globe.look_at_port(PortDB.active, 0.0)
	_refresh()
	_layout()
	UiTheme.focus_first(_sheet)
	open_changed.emit(true)
	UiTheme.pop_open(_sheet, _backdrop)


func close() -> void:
	if not _open:
		return
	_open = false
	UiTheme.pop_close(_sheet, _backdrop, _layout)
	UiTheme.restore_focus(_focus_return)
	_focus_return = null
	open_changed.emit(false)


func is_open() -> bool:
	return _open


func selected() -> StringName:
	return _selected


func globe() -> Globe:
	return _globe


func _unhandled_key_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	## Live, and throttled: `teus_changed` fires every frame the port earns.
	if not _open:
		return
	_refresh_timer += delta
	if not _dirty or _refresh_timer < REFRESH_INTERVAL:
		return
	_refresh_timer = 0.0
	_dirty = false
	_refresh()


# --------------------------------------------------------------------- ports

func _flag_texture(index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = FLAGS
	atlas.region = Rect2(Vector2(index * FLAG_SIZE.x, 0), FLAG_SIZE)
	return atlas


func _select(id: StringName, turn: bool = true) -> void:
	if PortDB.get_port(id).is_empty():
		return
	var changed := id != _selected
	_selected = id
	_globe.selected = id
	if turn:
		_globe.look_at_port(id)
		if changed and _open:
			AudioManager.play_sfx("ui_tab", 0.03, -3.0)
	_refresh()


func _refresh() -> void:
	if _card == null or _selected == &"":
		return
	for id: StringName in _chip_keys:
		UiTheme.style_button(_chip_keys[id], &"amber" if id == _selected else &"steel")
	var port := PortDB.get_port(_selected)
	var here := _selected == PortDB.active
	var open := SaveManager.port_open(_selected)
	var cost := float(port.get("cost", 0.0))
	var affordable := not open and GameState.can_afford(cost)
	UiTheme.apply_panel(_card, UiTheme.card_style(
		&"done" if here else (&"ready" if affordable or open else &"normal")))
	_flag.texture = _flag_texture(int(port.get("flag", 0)))
	_name.text = "%s - %s" % [str(port.name), str(port.country)]
	_perk.text = str(port.get("perk", ""))
	_go.visible = not here
	_go.disabled = here
	_go.focus_mode = Control.FOCUS_NONE if here else Control.FOCUS_ALL
	if here:
		_state.text = Loc.t("ports.here")
		_state.label_settings.font_color = UiTheme.TEAL_DEEP
	elif open:
		_state.text = Loc.t("ports.wallet", {"amount": GameState.fmt(
			float(_port_wallets[_selected]))}) if _port_wallets.has(_selected) \
			else Loc.t("ports.new")
		_state.label_settings.font_color = UiTheme.TEAL_DEEP
		_go.text = Loc.t("ports.travel")
		UiTheme.style_button(_go, &"amber")
		UiTheme.describe(_go, Loc.t("ports.travel_name", {"name": str(port.name)}))
	else:
		_state.text = str(port.get("tagline", "")) if affordable \
			else Loc.t("ports.missing", {"amount": GameState.fmt(cost - GameState.teus)})
		_state.label_settings.font_color = UiTheme.AMBER_DEEP
		_go.text = GameState.fmt(cost)
		UiTheme.style_button(_go, &"amber" if affordable else &"off")
		UiTheme.describe(_go, Loc.t("ports.open_name", {"name": str(port.name)}))
	var count := SaveManager.open_ports().size()
	_network.text = Loc.t("ports.network.none") if count <= 1 \
		else Loc.t("ports.network", {"count": str(count),
			"pct": str(int(round((PortDB.network_multiplier() - 1.0) * 100.0)))})


func _read_port_wallets() -> void:
	_port_wallets.clear()
	if SaveManager.active_slot <= 0:
		return
	for id: StringName in SaveManager.open_ports():
		if id == PortDB.active:
			continue
		var summary := SaveManager.port_summary(SaveManager.active_slot, id)
		if bool(summary.get("exists", false)):
			_port_wallets[id] = float(summary.get("teus", 0.0))


func _on_go() -> void:
	var id := _selected
	if id == PortDB.active or not PortDB.is_playable(id):
		return
	if SaveManager.port_open(id):
		AudioManager.play_sfx("tap")
		travel_requested.emit(id)
		return
	if not SaveManager.buy_port(id):
		AudioManager.play_sfx("deny")
		return
	AudioManager.play_sfx("build")
	EventBus.notification_requested.emit({
		"id": "port_%s" % String(id), "kind": &"unlock", "priority": 2,
		"text": Loc.t("ports.opened", {"name": str(PortDB.get_port(id).get("name", ""))}),
	})
	_refresh()


# -------------------------------------------------------------------- layout

func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


func _layout() -> void:
	if _sheet == null or not is_instance_valid(_sheet):
		return
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var width := safe.size.x - 12.0
	# The planet is a whole multiple of its own pixels: two on a phone, three
	# where the board is wide enough.
	var scale := clampi(int((width - 30.0) / Globe.PIXELS), 1, 3)
	_space.custom_minimum_size.y = float(Globe.PIXELS * scale) + 12.0
	var top := safe.position.y + 20.0
	var available := maxf(220.0, safe.end.y - top - 6.0)
	_sheet.size = Vector2(width, clampf(_column.get_combined_minimum_size().y + 22.0,
		220.0, available))
	_sheet.position = Vector2(safe.position.x + 6.0, safe.end.y - _sheet.size.y - 6.0)
	_backdrop.visible = _open
	_sheet.visible = _open
	UiTheme.place_clip(_clip, _sheet, safe)


class _Stars extends Control:
	## A few fixed stars behind the planet, so it hangs in space rather than on
	## a navy rectangle.
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1977
		for i in 46:
			var at := Vector2(rng.randf() * size.x, rng.randf() * size.y).floor()
			var c := 0.45 + rng.randf() * 0.5
			draw_rect(Rect2(at, Vector2.ONE), Color(c, c, c * 1.05, 1.0))
