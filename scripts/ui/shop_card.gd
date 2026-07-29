class_name ShopCard
extends PanelContainer
## One line torn off the purchase manifest.
##
## Reading order is left to right, exactly once: what the machine looks like,
## what it is called, what it does for you, how many you run, what it costs.
## The price column has a fixed width so every stamp in the list lines up and
## the eye can scan costs without reading a single name.
##
## An unowned item still sells itself with its blurb; the moment you own one
## the blurb is replaced by its actual output, because by then you are
## comparing numbers, not discovering the machine.

signal pressed_card(id: String)

const DRAG_CANCEL_DISTANCE := 10.0
const EMULATED_INPUT_DEDUPE_MSEC := 120
const ART_SIZE := Vector2(54, 38)
const ART_SIZE_COMPACT := Vector2(38, 32)
const PRICE_WIDTH := 74.0
const PRICE_WIDTH_COMPACT := 58.0

var id: String = ""
var kind: String = "structure"

var _art: PortIcon
var _art_well: PanelContainer
var _name_label: Label
var _sub_label: Label
var _count_stamp: PanelContainer
var _count_label: Label
var _price_stamp: PanelContainer
var _price_label: Label
var _price_col: VBoxContainer
var _compact := false
var _blurb := ""
var _state: StringName = &""
var _press_start := Vector2.ZERO
var _tracking_press := false
var _last_activation_msec := -1000


func setup(item_id: String, item_kind: String, art_key: String,
		title: String, description: String,
		badge: Variant = null) -> void:
	id = item_id
	kind = item_kind
	_blurb = description
	custom_minimum_size.y = 46.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	# A card is a button in everything but class, so it has to be reachable and
	# activatable from the keyboard like one.
	focus_mode = Control.FOCUS_ALL
	add_theme_stylebox_override(&"focus", UiTheme.focus_ring())
	UiTheme.describe(self, title, description)
	_apply_state(&"normal")

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_art_well = UiTheme.panel(UiTheme.well_style(1))
	_art_well.custom_minimum_size = ART_SIZE
	_art_well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_art_well)
	_art = PortIcon.new()
	_art.custom_minimum_size = ART_SIZE - Vector2(2, 2)
	_art.show_item(art_key)
	_art.set_badge(badge)
	_art_well.add_child(_art)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override(&"separation", 1)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)

	_name_label = UiTheme.label(title, UiTheme.SIZE_BODY, UiTheme.INK)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_col.add_child(_name_label)

	_sub_label = UiTheme.label(description, UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_label.max_lines_visible = 2
	_sub_label.custom_minimum_size.x = 0.0
	text_col.add_child(_sub_label)

	_price_col = VBoxContainer.new()
	_price_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_price_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_price_col.custom_minimum_size.x = PRICE_WIDTH
	_price_col.add_theme_constant_override(&"separation", 2)
	_price_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_price_col)

	_count_stamp = UiTheme.panel(UiTheme.slate_style(false, 2))
	_count_stamp.visible = false
	_count_stamp.size_flags_horizontal = Control.SIZE_SHRINK_END
	_price_col.add_child(_count_stamp)
	_count_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.SLATE_TEXT)
	_count_stamp.add_child(_count_label)

	_price_stamp = UiTheme.stamp("", UiTheme.AMBER)
	_price_stamp.size_flags_horizontal = Control.SIZE_FILL
	_price_col.add_child(_price_stamp)
	_price_label = UiTheme.stamp_label(_price_stamp)
	set_compact(_compact)


func set_compact(compact: bool) -> void:
	## The desktop drawer is a third of the width of a phone sheet, so the art
	## socket and the price column give room back to the name.
	_compact = compact
	if _art_well == null:
		return
	var art_size := ART_SIZE_COMPACT if compact else ART_SIZE
	_art_well.custom_minimum_size = art_size
	_art.custom_minimum_size = art_size - Vector2(2, 2)
	_price_col.custom_minimum_size.x = \
		PRICE_WIDTH_COMPACT if compact else PRICE_WIDTH


func refresh(cost: float, count: int, affordable: bool, sold_out: bool = false,
		quantity: int = 1, cps_gain: float = 0.0) -> void:
	if sold_out:
		_price_label.text = "PRONTO"
		_price_label.label_settings.font_color = UiTheme.TEAL_LIGHT
		_apply_state(&"done")
	else:
		_price_label.text = GameState.fmt(cost)
		_price_label.label_settings.font_color = \
			UiTheme.AMBER if affordable else UiTheme.SLATE_DIM
		_apply_state(&"ready" if affordable else &"normal")
	_count_stamp.visible = count > 0
	_count_label.text = "x%d" % count

	# Owned machines report output; new ones still get their sales pitch.
	if count > 0 and cps_gain > 0.0:
		_sub_label.text = "+%s TEU/s%s" % [GameState.fmt(cps_gain),
			"  (x%d)" % quantity if quantity > 1 else ""]
		_sub_label.label_settings.font_color = UiTheme.TEAL_DEEP
	elif sold_out:
		_sub_label.text = _blurb
		_sub_label.label_settings.font_color = UiTheme.TEAL_DEEP
	else:
		_sub_label.text = _blurb
		_sub_label.label_settings.font_color = UiTheme.INK_SOFT
	_name_label.label_settings.font_color = \
		UiTheme.INK if (affordable or sold_out or count > 0) else UiTheme.INK_SOFT

	tooltip_text = "%s\n%s" % [_blurb, "Compra x%d - +%s TEU/s"
		% [quantity, GameState.fmt(cps_gain)] if cps_gain > 0.0
		else "Compra x%d" % quantity]


func show_locked(title: String, hint: String) -> void:
	## A teaser for the next thing the terminal could run. Seeing the silhouette
	## of what comes next is the cheapest retention there is.
	_name_label.text = title
	_sub_label.text = hint
	_sub_label.label_settings.font_color = UiTheme.INK_SOFT
	_count_stamp.visible = false
	_price_label.text = "?"
	_price_label.label_settings.font_color = UiTheme.SLATE_DIM
	_art.modulate = Color(0.0, 0.0, 0.0, 0.55)
	_apply_state(&"locked")
	tooltip_text = hint


func _apply_state(state: StringName) -> void:
	if _state == state:
		return
	_state = state
	UiTheme.apply_panel(self, UiTheme.card_style(state))


# --------------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		accept_event()
		_activate()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_press(event.position)
		elif _tracking_press:
			_finish_press(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_press(event.position)
		elif _tracking_press:
			_finish_press(event.position)
	elif event is InputEventMouseMotion and _tracking_press:
		if _press_start.distance_to(event.position) >= DRAG_CANCEL_DISTANCE:
			_tracking_press = false
	elif event is InputEventScreenDrag and _tracking_press:
		if _press_start.distance_to(event.position) >= DRAG_CANCEL_DISTANCE:
			_tracking_press = false


func _begin_press(at: Vector2) -> void:
	_press_start = at
	_tracking_press = true


func _finish_press(at: Vector2) -> void:
	var should_buy := _press_start.distance_to(at) < DRAG_CANCEL_DISTANCE
	_tracking_press = false
	if should_buy:
		_activate()


func _activate() -> void:
	## One dedupe window for every input route, so an emulated mouse click that
	## follows a touch — or a key repeat — cannot buy twice.
	var now := Time.get_ticks_msec()
	if now - _last_activation_msec < EMULATED_INPUT_DEDUPE_MSEC:
		return
	_last_activation_msec = now
	pressed_card.emit(id)


# ------------------------------------------------------------------ feedback

func flash_ok() -> void:
	if not UserPreferences.can_animate():
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.35, 1.3, 1.15), 0.06)
	tween.tween_property(self, "modulate", Color.WHITE, 0.24)


func shake_deny() -> void:
	if not UserPreferences.can_animate():
		return
	var origin := position.x
	var tween := create_tween()
	for offset in [3.0, -3.0, 2.0, -2.0, 0.0]:
		tween.tween_property(self, "position:x", origin + offset, 0.04)
