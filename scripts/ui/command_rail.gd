class_name CommandRail
extends CanvasLayer
## The console under the thumb: what to do next, and every key that opens a board.
##
## This used to be two layouts. On a wide screen it was a clipboard pinned down
## the right-hand third of the window carrying the berth, the pinned objective,
## a port summary and the keys; in portrait it collapsed to this steel console.
## `PortraitFrame` then clamped the aspect at 2:3, which made the logical
## viewport never wider than it is tall, which made the wide branch unreachable
## from inside the game. The board is gone rather than dormant — but the two
## things it carried that the phone never had are not, because losing them was
## how "próximo objetivo sempre visível" quietly stopped being true.
##
## So the console grew a head: one line that answers "what now?". On the left the
## objective the player is working toward, on the right the single most valuable
## thing they could press. That right-hand chip is a priority, not a state:
## reconstruction outranks a purchase, and a purchase outranks a countdown, so
## the console never shows the smaller of two invitations.
##
## The tally is deliberately not here. It lives on the gantry, which spans the
## port, so there is exactly one number in the game.

signal shop_requested
signal routes_requested
signal journal_requested
signal settings_requested
signal prestige_requested

## The console, and the key face on it. Sized so a 24px glyph and its word both
## fit: a 12px icon on a thumb-sized key reads as a bullet point, and this is the
## one row of the interface the player touches all session.
const BAR_KEY_H := 44.0
## The head above the keys: the objective and the next-move chip.
const HEAD_H := 17.0
const BAR_H := 54.0 + HEAD_H

var _bar: PanelContainer
var _head: Control
var _objective_button: Button
var _objective_label: Label
var _objective_value: Label
var _next_button: Button
var _next_label: Label
var _next_pip: TextureRect
var _bar_keys: HBoxContainer
var _shop_pip: TextureRect
var _shop_alert := Callable()
var _shop_eta := Callable()
var _objective_source := Callable()
var _safe_rect := Rect2()
var _tick := 0.0


func _ready() -> void:
	layer = 5
	_build_bar()
	get_viewport().size_changed.connect(_layout)
	EventBus.prestiged.connect(func(_s: int) -> void: _refresh_next())
	_layout()


# ------------------------------------------------------------------ assembly

func _build_bar() -> void:
	## The port keeps the whole screen, so the console is the gantry's panel the
	## other way up, with its amber edge facing the port.
	_bar = PanelContainer.new()
	UiTheme.apply_panel(_bar, UiTheme.console_style())
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bar)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 2)
	_bar.add_child(column)
	column.add_child(_build_head())

	_bar_keys = HBoxContainer.new()
	_bar_keys.add_theme_constant_override(&"separation", 3)
	column.add_child(_bar_keys)
	# Four keys of equal weight, each a glyph over its word. The old bar gave the
	# named keys a full-width slab and squeezed settings into a 44px square with a
	# 12px glyph in it, which is the "settings icon is rubbish" from the playtest.
	# Stacking the glyph buys every key a real word inside 80px.
	var shop_key: Button = null
	for spec in [["LOJA", UiTheme.Icon.CRANE, &"amber", "Abrir a loja do terminal", shop_requested],
			["ROTAS", UiTheme.Icon.GLOBE, &"steel", "Abrir o mapa de rotas", routes_requested],
			["DIÁRIO", UiTheme.Icon.TROPHY, &"steel", "Abrir o Diário do Porto", journal_requested],
			["AJUSTES", UiTheme.Icon.GEAR, &"steel", "Abrir os ajustes", settings_requested]]:
		var key := _make_key(str(spec[0]), spec[1], spec[2], str(spec[3]), spec[4])
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.custom_minimum_size = Vector2(0.0, BAR_KEY_H)
		_bar_keys.add_child(key)
		if shop_key == null:
			shop_key = key

	# A lamp on the key that has something behind it. A clicker's whole loop is
	# "earn, then spend", and the spend half was invisible until you opened the
	# shop and looked.
	_shop_pip = UiTheme.pip()
	_shop_pip.visible = false
	_shop_pip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT,
		Control.PRESET_MODE_MINSIZE)
	_shop_pip.position = Vector2(-11.0, 4.0)
	_shop_pip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	shop_key.add_child(_shop_pip)


func _build_head() -> Control:
	## Two touch targets on one line. Both are flat buttons over the console's own
	## enamel rather than panels: a card here would be a third material inside a
	## panel that is already two, and the line is 17px tall.
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 4)
	head.custom_minimum_size.y = HEAD_H
	_head = head

	_objective_button = _flat_button("Abrir o Diário do Porto", journal_requested)
	# The objective takes the room the chip does not, so a long goal title is
	# trimmed by its own label rather than pushing the chip off the console.
	_objective_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_objective_button.clip_contents = true
	head.add_child(_objective_button)
	var objective_row := HBoxContainer.new()
	objective_row.add_theme_constant_override(&"separation", 3)
	objective_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE, 2)
	_objective_button.add_child(objective_row)
	var star := UiTheme.icon(UiTheme.Icon.TROPHY)
	star.modulate = UiTheme.STEEL_DIM
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	objective_row.add_child(star)
	_objective_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.STEEL_TEXT)
	_objective_label.clip_text = true
	_objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_row.add_child(_objective_label)
	_objective_value = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER)
	_objective_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_row.add_child(_objective_value)

	_next_button = _flat_button("Próxima ação", shop_requested)
	head.add_child(_next_button)
	var next_row := HBoxContainer.new()
	next_row.add_theme_constant_override(&"separation", 3)
	next_row.alignment = BoxContainer.ALIGNMENT_END
	next_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE, 2)
	_next_button.add_child(next_row)
	_next_pip = UiTheme.pip()
	_next_pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_row.add_child(_next_pip)
	_next_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER)
	_next_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_row.add_child(_next_label)
	return head


func _flat_button(control_name: String, target: Signal) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override(&"focus", UiTheme.focus_ring())
	UiTheme.describe(button, control_name)
	button.pressed.connect(func() -> void:
		AudioManager.play_sfx("tap")
		target.emit())
	return button


func _make_key(text: String, icon: UiTheme.Icon, kind: StringName,
		control_name: String, target: Signal) -> Button:
	## Button draws its icon hard against the left edge and only centres the
	## text, which left a hand-sized hole between the two on a wide key. The
	## glyph and the word are laid out as one group instead, stacked and centred
	## together.
	var key := UiTheme.button("", kind, UiTheme.SIZE_SMALL)
	key.custom_minimum_size.y = BAR_KEY_H
	UiTheme.describe(key, control_name)
	key.pressed.connect(func() -> void:
		AudioManager.play_sfx("tap")
		target.emit())

	var group := VBoxContainer.new()
	group.add_theme_constant_override(&"separation", 1)
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	key.add_child(group)
	var glyph := UiTheme.icon(icon, 2)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	group.add_child(glyph)
	var label := UiTheme.label(text, UiTheme.SIZE_SMALL, _key_ink(kind))
	label.name = "KeyText"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Only the console's keys are width-constrained, and only there may the word
	# be clipped. A clipped Label reports a minimum width of one pixel.
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_child(label)
	return key


func _key_ink(kind: StringName) -> Color:
	## The word on a key follows the key's own face. A steel key carries the same
	## cream as the enamel it is bolted to; an amber one carries ink.
	match kind:
		&"alt", &"danger":
			return UiTheme.CREAM
		&"steel":
			return UiTheme.STEEL_TEXT
		_:
			return UiTheme.INK


# --------------------------------------------------------------------- state

func set_objective_source(objective: Callable) -> void:
	_objective_source = objective
	_refresh_objective()


func set_shop_alert_source(alert: Callable) -> void:
	## Whether the shop has anything the player can afford right now. Asked on
	## the console's own slow tick rather than on every credited box: the answer
	## walks the whole catalogue.
	_shop_alert = alert
	_refresh_next()


func set_shop_eta_source(eta: Callable) -> void:
	## Seconds until the cheapest revealed purchase becomes affordable, or a
	## negative number when the port earns too little to ever reach it. Rule 2 of
	## the design principles: a wait the player cannot price is a stall.
	_shop_eta = eta
	_refresh_next()


func _process(delta: float) -> void:
	_tick += delta
	if _tick > 0.4:
		_tick = 0.0
		_refresh_objective()
		_refresh_next()


func _refresh_objective() -> void:
	if _objective_label == null:
		return
	var objective: Dictionary = {}
	if _objective_source.is_valid():
		var value: Variant = _objective_source.call()
		objective = value if value is Dictionary else {}
	if objective.is_empty():
		_objective_label.text = "Toque no navio pra mover carga"
		_objective_value.text = ""
		return
	var pinned := bool(objective.get("pinned", false))
	_objective_label.text = ("FIXADA: " if pinned else "") \
		+ str(objective.get("title", "Meta"))
	_objective_value.text = "%s/%s" % [
		GameState.fmt(float(objective.get("progress", 0.0))),
		GameState.fmt(float(objective.get("target", 0.0)))]


func _refresh_next() -> void:
	## One chip, three answers, in the order the player should care about them.
	## Rebuilding the port is rare and outranks everything; something affordable
	## outranks a countdown to something that is not.
	if _next_label == null:
		return
	var affordable := _shop_alert.is_valid() and bool(_shop_alert.call())
	if _shop_pip != null:
		_shop_pip.visible = affordable
	if GameState.can_prestige():
		_set_next("CAPITAL +%d" % GameState.prestige_gain(), UiTheme.AMBER, true,
			"Reconstruir o porto e emitir ações", prestige_requested)
		return
	if affordable:
		_set_next("COMPRAR", UiTheme.AMBER, true, "Abrir a loja do terminal",
			shop_requested)
		return
	var eta := float(_shop_eta.call()) if _shop_eta.is_valid() else -1.0
	if eta < 0.0:
		# Nothing revealed, or nothing the port's income will ever reach. Saying
		# "em ∞" is worse than saying nothing.
		_set_next("", UiTheme.STEEL_DIM, false, "Abrir a loja do terminal",
			shop_requested)
		return
	_set_next(_fmt_eta(eta), UiTheme.STEEL_DIM, false,
		"Abrir a loja do terminal", shop_requested)


func _set_next(text: String, ink: Color, lit: bool, control_name: String,
		target: Signal) -> void:
	_next_label.text = text
	_next_label.add_theme_color_override(&"font_color", ink)
	_next_pip.visible = lit
	_next_button.visible = not text.is_empty()
	# A Button is not a Container, so the row anchored inside it contributes
	# nothing to its minimum size: left alone the chip is born zero pixels wide
	# and its end-aligned contents spill off the side of the console. The width
	# is measured from the string it is currently showing.
	var glyph := _next_pip.custom_minimum_size.x + 3.0 if lit else 0.0
	_next_button.custom_minimum_size = Vector2(
		UiTheme.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UiTheme.SIZE_SMALL).x + glyph + 8.0, HEAD_H)
	UiTheme.describe(_next_button, control_name, text)
	# The chip changes what it does, not just what it says, so the old connection
	# has to go with the old label — otherwise pressing "CAPITAL" opens the shop.
	for connection in _next_button.pressed.get_connections():
		_next_button.pressed.disconnect(connection["callable"])
	_next_button.pressed.connect(func() -> void:
		AudioManager.play_sfx("tap")
		target.emit())


static func _fmt_eta(seconds: float) -> String:
	## Coarse on purpose. The number is there to turn a wait into a plan, and a
	## countdown ticking every second on a bar the player is not looking at is
	## movement for its own sake.
	if seconds < 60.0:
		return "em %ds" % maxi(1, int(ceilf(seconds)))
	if seconds < 3600.0:
		return "em %dmin" % maxi(1, int(ceilf(seconds / 60.0)))
	return "em %dh" % int(ceilf(seconds / 3600.0))


# -------------------------------------------------------------------- layout

func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, view)
	_bar.size = Vector2(safe.size.x - 12.0, BAR_H)
	_bar.position = Vector2(safe.position.x + 6.0, safe.end.y - BAR_H - 6.0)


func head_rect() -> Rect2:
	## Where the "what now?" line actually is, for the tutorial spotlight to cut
	## its hole around. Asked rather than reached into.
	return _head.get_global_rect() if _head != null and is_instance_valid(_head) \
		else Rect2()


func set_overlay_open(open: bool) -> void:
	## While a board is up over the console, its keys would be drawn underneath.
	## Hiding them keeps the focus order honest too.
	_bar.visible = not open
