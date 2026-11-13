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
## The price column is fixed so every stamp in a list lines up and the eye can
## scan costs without reading a name. Sized to the widest thing `GameState.fmt`
## can print (five characters plus a suffix) and no wider — the tree spends the
## rest on names, which are now the part a player reads three rows ahead.
const PRICE_WIDTH := 66.0

var id: String = ""
var kind: String = "structure"
## Set before `setup`. A tile stands on the shelf of the equipment tab: the
## machine big on top, its name and yield under it, and the price as a key
## across the foot. A row (the default) is the same card lying down, for lists
## whose text is the point — upgrades, land.
var tile := false
const TILE_ART := Vector2(72, 46)

var _art: PortIcon
var _art_well: PanelContainer
var _indent: Control
var _name_label: Label
var _sub_label: Label
var _lock: TextureRect
## Up to two coloured tags under the name saying what kind of thing this card
## does (production, the whole port, taps, a swap, the rail) and whether it is
## one of an exclusive pair. Built once, rewritten in place.
var _chip_row: HFlowContainer
var _chips: Array[Dictionary] = []   # {panel, style, icon, label}
var _chip_key := ""
var _count_stamp: PanelContainer
var _count_label: Label
var _price_stamp: PanelContainer
## Pulses once when the card becomes affordable — the moment "I can buy this"
# arrives should be visible, not just a colour change.
var _was_affordable := false
var _price_label: Label
var _price_col: VBoxContainer
var _blurb := ""
var _effect := ""
var _state: StringName = &""
var _price_look: StringName = &""
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

	if tile:
		_setup_tile(art_key, title, description, badge)
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	# How far down a trunk this node hangs. Zero for everything that is not part
	# of a tree, which is every card outside the upgrades tab.
	_indent = Control.new()
	_indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indent.custom_minimum_size.x = 0.0
	row.add_child(_indent)

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
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A padlock before the name when something is shutting the card: red words
	# say why, the lock says "shut" before they are read.
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override(&"separation", 3)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(name_row)
	_lock = UiTheme.icon(UiTheme.Icon.LOCK)
	_lock.visible = false
	_lock.modulate = UiTheme.DANGER
	_lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_lock)
	name_row.add_child(_name_label)

	# A flow, not a row: "TROCA" beside "ESCOLHA 1 DE 2" is wider than the text
	# column of a card on a 320px phone, and a row that cannot shrink sets the
	# whole board's minimum width — the shop opened wider than the screen, with
	# its close key and every price off the right edge. Chips wrap instead.
	_chip_row = HFlowContainer.new()
	_chip_row.add_theme_constant_override(&"h_separation", 4)
	_chip_row.add_theme_constant_override(&"v_separation", 2)
	_chip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_row.visible = false
	text_col.add_child(_chip_row)
	for i in 2:
		_chips.append(_make_chip())

	_sub_label = UiTheme.label(description, UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Three lines: an effect cut off after "Estivador vira multiplicador:" was
	# the shop's whole readability problem in one card.
	_sub_label.max_lines_visible = 3
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

	_price_stamp = _make_price_key()
	_price_col.add_child(_price_stamp)
	_art_well.custom_minimum_size = ART_SIZE
	_art.custom_minimum_size = ART_SIZE - Vector2(2, 2)
	_price_col.custom_minimum_size.x = PRICE_WIDTH



func _make_price_key() -> PanelContainer:
	## The price is the key you press, not a number beside one: green when the
	## wallet covers it, the sheet's own colour when it does not.
	var key := UiTheme.panel(UiTheme.nine("ui_btn_off", 5, 4))
	key.size_flags_horizontal = Control.SIZE_FILL
	key.custom_minimum_size.y = 20.0
	_price_label = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK_SOFT)
	_price_label.name = "Value"
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_child(_price_label)
	return key


func _price_key(look: StringName) -> void:
	## `go` | `off` | `done`
	if _price_look == look:
		return
	_price_look = look
	var sprite := "ui_btn_go" if look == &"go" else "ui_btn_off"
	UiTheme.apply_panel(_price_stamp, UiTheme.nine(sprite, 5, 4))
	_price_label.label_settings.font_color = UiTheme.CREAM if look == &"go" \
		else (UiTheme.TEAL_DEEP if look == &"done" else UiTheme.INK_SOFT)


func _setup_tile(art_key: String, title: String, description: String,
		badge: Variant) -> void:
	custom_minimum_size.y = 128.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_indent = Control.new()
	_indent.visible = false
	col.add_child(_indent)

	_art_well = UiTheme.panel(UiTheme.well_style(2))
	_art_well.custom_minimum_size = Vector2(0.0, TILE_ART.y)
	col.add_child(_art_well)
	_art = PortIcon.new()
	_art.custom_minimum_size = Vector2(0.0, TILE_ART.y - 4.0)
	_art.show_item(art_key)
	_art.set_badge(badge)
	_art_well.add_child(_art)
	_count_stamp = UiTheme.panel(UiTheme.slate_style(false, 2))
	_count_stamp.visible = false
	_count_stamp.size_flags_horizontal = Control.SIZE_SHRINK_END
	_count_stamp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_art_well.add_child(_count_stamp)
	_count_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.SLATE_TEXT)
	_count_stamp.add_child(_count_label)

	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override(&"separation", 3)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_row)
	_lock = UiTheme.icon(UiTheme.Icon.LOCK)
	_lock.visible = false
	_lock.modulate = UiTheme.DANGER
	_lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_lock)
	_name_label = UiTheme.label(title, UiTheme.SIZE_BODY, UiTheme.INK)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.max_lines_visible = 2
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_label)

	_chip_row = HFlowContainer.new()
	_chip_row.visible = false
	col.add_child(_chip_row)
	for i in 2:
		_chips.append(_make_chip())

	_sub_label = UiTheme.label(description, UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_label.max_lines_visible = 3
	_sub_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_sub_label)

	_price_col = col
	_price_stamp = _make_price_key()
	_price_stamp.custom_minimum_size.y = 24.0
	col.add_child(_price_stamp)


const INDENT_STEP := 8.0
## Indentation stops after this many levels. On a 320 px phone the name column is
## about two hundred points wide, and a trunk eight nodes deep would spend a third
## of it on whitespace and ellipsise every name past the fourth. The step is there
## to show that a node hangs off something, which the first few levels already
## say; what *specifically* blocks it is on the card in words.
const INDENT_MAX_DEPTH := 3


func set_indent(depth: int) -> void:
	## Push the card right by how deep in the tree its node sits. Depth is the
	## only thing on the upgrades tab that says "this one hangs off that one"
	## without the player having to read two cards and compare their text.
	if _indent == null:
		return
	_indent.custom_minimum_size.x = INDENT_STEP \
		* float(clampi(depth, 0, INDENT_MAX_DEPTH))


func _make_chip() -> Dictionary:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.content_margin_left = 3
	style.content_margin_right = 4
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	style.border_width_bottom = 1
	style.border_color = Color(0, 0, 0, 0.35)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var icon := UiTheme.icon(UiTheme.Icon.STAR)
	row.add_child(icon)
	var label := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.CREAM)
	row.add_child(label)
	_chip_row.add_child(panel)
	return {"panel": panel, "style": style, "icon": icon, "label": label}


func set_chips(chips: Array) -> void:
	## `chips`: [{text, color: Color, icon: UiTheme.Icon}], at most two. Only
	## touches the nodes when what they say changes.
	var key := str(chips)
	if key == _chip_key:
		return
	_chip_key = key
	_chip_row.visible = not chips.is_empty()
	for i in _chips.size():
		var chip: Dictionary = _chips[i]
		var panel: PanelContainer = chip.panel
		if i >= chips.size():
			panel.visible = false
			continue
		var spec: Dictionary = chips[i]
		panel.visible = true
		(chip.style as StyleBoxFlat).bg_color = spec.get("color", UiTheme.TEAL)
		(chip.label as Label).text = str(spec.get("text", ""))
		(chip.icon as TextureRect).texture = UiTheme.icon_texture(
			spec.get("icon", UiTheme.Icon.STAR))


func set_effect(text: String) -> void:
	## What this card actually does, in words. An upgrade whose card only carries
	## a punchline and a price is a mystery box, and eighteen of them in a row is
	## why "as melhorias não fazem sentido".
	_effect = text


func refresh(cost: float, count: int, affordable: bool, sold_out: bool = false,
		quantity: int = 1, cps_gain: float = 0.0) -> void:
	# A card can go from gated back to buyable in the same session — a tree node
	# whose prerequisite was just bought does exactly that — so the silhouette
	# `show_gated` applied has to come back off here rather than only at build.
	_art.modulate = Color.WHITE
	_lock.visible = false
	if sold_out:
		_price_label.text = "PRONTO"
		_price_key(&"done")
		_apply_state(&"done")
		_was_affordable = true
	else:
		_price_label.text = GameState.fmt(cost)
		_price_key(&"go" if affordable else &"off")
		_apply_state(&"ready" if affordable else &"normal")
		var became_affordable := affordable and not _was_affordable
		_was_affordable = affordable
		if became_affordable and UserPreferences.can_animate():
			var pulse := create_tween()
			pulse.tween_property(_price_stamp, "modulate", Color(1.5, 1.6, 1.3), 0.09) \
				.from(Color.WHITE)
			pulse.tween_property(_price_stamp, "modulate", Color.WHITE, 0.24)
			UiMotion.punch(_price_stamp)
	_count_stamp.visible = count > 0
	_count_label.text = "x%d" % count

	# A machine you already run, or one you could buy right now, is a number
	# being compared — so the line says what the purchase changes and how long it
	# takes to pay for itself. A machine you cannot afford yet is still being
	# discovered, so it keeps its sales pitch.
	#
	# Payback is the one figure that makes two very differently priced machines
	# comparable at a glance, and without it "+25%" of an unstated base is a
	# number the player has to take on faith.
	if not _effect.is_empty():
		# An upgrade is bought once and never compared against a second unit of
		# itself, so payback is the wrong figure for it. What it changes and by
		# how much is the right one, and it is stated whether or not the wallet
		# can reach it — a card the player is saving up for is exactly the card
		# they need to understand.
		_sub_label.text = _effect if cps_gain <= 0.0 \
			else "%s\n+%s TEU/s" % [_effect, GameState.fmt(cps_gain)]
		_sub_label.label_settings.font_color = \
			UiTheme.TEAL_DEEP if affordable else UiTheme.INK_SOFT
	elif cps_gain > 0.0 and (count > 0 or affordable):
		# Two deliberate lines rather than one that wraps: on a 320 px phone the
		# effect and the payback do not fit side by side, and a ragged wrap put
		# the separator alone at the end of a line.
		#
		# When the wallet is short, the second line answers the other half of
		# rule 2 instead: a wait whose end is visible is a plan, and the same
		# wait without one is the stall that empties a clicker.
		_sub_label.text = "+%s TEU/s%s\n%s" % [GameState.fmt(cps_gain),
			"  x%d" % quantity if quantity > 1 else "",
			"paga em %s" % _payback(cost, cps_gain) if affordable
			else "faltam %s" % wait_for(cost - GameState.teus, GameState.cps)]
		_sub_label.label_settings.font_color = UiTheme.TEAL_DEEP
	elif sold_out:
		_sub_label.text = _blurb
		_sub_label.label_settings.font_color = UiTheme.TEAL_DEEP
	else:
		_sub_label.text = _blurb
		_sub_label.label_settings.font_color = UiTheme.INK_SOFT
	_name_label.label_settings.font_color = \
		UiTheme.INK if (affordable or sold_out or count > 0) else UiTheme.INK_SOFT

	if not _effect.is_empty():
		tooltip_text = "%s\n%s" % [_effect, _blurb]
		return
	tooltip_text = "%s\n%s" % [_blurb, "Compra x%d - +%s TEU/s - paga em %s"
		% [quantity, GameState.fmt(cps_gain), _payback(cost, cps_gain)]
		if cps_gain > 0.0 else "Compra x%d" % quantity]


static func wait_for(missing: float, rate: float) -> String:
	## How long the wallet needs to reach a price. Rule 2: a wait whose end the
	## player can see is a plan; the same wait without one is a stall.
	if missing <= 0.0:
		return "0s"
	if rate <= 0.0 or not is_finite(missing):
		return "muito"
	return duration(missing / rate)


static func _payback(cost: float, cps_gain: float) -> String:
	## How long this purchase takes to earn its own price back.
	if cps_gain <= 0.0 or not is_finite(cost):
		return "-"
	return duration(cost / cps_gain)


static func duration(seconds: float) -> String:
	## Phrased the way a person says a duration rather than in bare seconds.
	if seconds < 90.0:
		return "%ds" % maxi(1, roundi(seconds))
	if seconds < 5400.0:
		return "%dmin" % roundi(seconds / 60.0)
	if seconds < 172800.0:
		return "%dh" % roundi(seconds / 3600.0)
	return "%dd" % roundi(seconds / 86400.0)


func show_locked(title: String, hint: String) -> void:
	## A teaser for the next thing the terminal could run. Seeing the silhouette
	## of what comes next is the cheapest retention there is.
	_name_label.text = title
	_sub_label.text = hint
	_sub_label.label_settings.font_color = UiTheme.INK_SOFT
	_count_stamp.visible = false
	_price_label.text = "?"
	_price_key(&"off")
	_art.modulate = Color(0.0, 0.0, 0.0, 0.55)
	_apply_state(&"locked")
	tooltip_text = hint


func show_gated(reason: String, cost: float) -> void:
	## A node the player can see, name, and price, but not yet buy — and the one
	## sentence that says why.
	##
	## Different from `show_locked` on purpose. A teaser hides what it is, because
	## the surprise is the point. A gated tree node hides nothing: the whole reason
	## to draw the tree instead of a shelf is that a player can read three rows
	## ahead and decide what to aim at, and a row that will not say what blocks it
	## is worse than a row that is not drawn at all.
	_sub_label.text = reason
	_sub_label.label_settings.font_color = UiTheme.DANGER
	_name_label.label_settings.font_color = UiTheme.INK_SOFT
	_lock.visible = true
	_count_stamp.visible = false
	_price_label.text = GameState.fmt(cost)
	_price_key(&"off")
	_art.modulate = Color(0.35, 0.35, 0.4, 0.8)
	_apply_state(&"locked")
	tooltip_text = "%s\n%s" % [reason, _blurb]


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
