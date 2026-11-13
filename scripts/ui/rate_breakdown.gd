class_name RateBreakdown
extends CanvasLayer
## Why the rate is what it is: the factors, in the order the economy applies them.
##
## `+25%` of a base nobody knows is superstition, not strategy. The counter shows
## the product of six or seven multipliers and the player has no way to tell
## which one moved, so a purchase reads as "a number changed somewhere". This is
## the formula itself: machines at catalogue rate, then every multiplier stacked
## on top, then the total the counter is showing.

signal open_changed(opened: bool)

const MAX_WIDTH := 300.0

var _dim: ColorRect
var _panel: PanelContainer
var _rows: VBoxContainer
var _total: Label
var _safe_rect := Rect2()
var _open := false
var _focus_return: Control


func _ready() -> void:
	layer = 11
	_build()
	visible = false
	get_viewport().size_changed.connect(_layout)


func _build() -> void:
	_dim = UiTheme.scrim(0.62)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		# A finger as well as a mouse: on a phone the scrim got touch events
		# only, and tapping outside the board did nothing.
		if (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventScreenTouch and event.pressed):
			close())
	add_child(_dim)

	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.board_style(10))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 4)
	_panel.add_child(col)

	var header := UiTheme.header("DE ONDE VEM A TAXA", close, UiTheme.Icon.CLOCK)
	col.add_child(header.root)
	(header.close as Button).tooltip_text = Loc.t("common.close_hint")

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 2)
	col.add_child(_rows)

	col.add_child(UiTheme.divider())
	# The product, lit behind glass like the tally it explains.
	var glass := UiTheme.panel(UiTheme.glass_style(4))
	col.add_child(glass)
	_total = UiTheme.label("", UiTheme.SIZE_TITLE, UiTheme.DIGIT)
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glass.add_child(_total)


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_focus_return = get_viewport().gui_get_focus_owner()
	_refresh()
	_open = true
	visible = true
	_layout()
	open_changed.emit(true)
	UiTheme.pop_open(_panel, _dim)
	_play_bars()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if _focus_return != null and is_instance_valid(_focus_return):
		_focus_return.grab_focus()
	open_changed.emit(false)


func _unhandled_key_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var entries: Array = GameState.cps_breakdown()
	# Multipliers multiply, so their logs add: on a log scale each bar is that
	# factor's honest share of the climb from the base rate to the total.
	var span := 0.0
	for entry in entries:
		if String(entry.get("kind", "mult")) != "base":
			span = maxf(span, absf(log(maxf(float(entry.get("value", 1.0)), 0.0001))))
	for entry in entries:
		# A factor of exactly one changed nothing, and six rows of "x1.00" are six
		# rows the eye has to read before it finds the one that moved. They stay on
		# the panel — the formula has to be complete or it is a description of
		# itself again — but they are printed in the paper's own shadow, so what is
		# actually multiplying the port is what stands out.
		_rows.add_child(_row(String(entry.label), _value_text(entry),
			_is_inert(entry), _share(entry, span), _bar_ink(entry)))
	_total.text = "%s TEU/s" % GameState.fmt(GameState.cps)


static func _value_text(entry: Dictionary) -> String:
	var value := float(entry.get("value", 0.0))
	if String(entry.get("kind", "mult")) == "base":
		return "%s TEU/s" % GameState.fmt(value)
	# Two decimals below ten: a "x1" where the real factor is 1.4 is the same lie
	# the panel exists to stop telling.
	return "x%.2f" % value if value < 10.0 else "x%s" % GameState.fmt(value)


static func _is_inert(entry: Dictionary) -> bool:
	## A multiplier that is exactly one. The base row is never inert — a port that
	## produces nothing is a fact worth printing loudly.
	return String(entry.get("kind", "mult")) != "base" \
		and is_equal_approx(float(entry.get("value", 1.0)), 1.0)


static func _share(entry: Dictionary, span: float) -> float:
	if String(entry.get("kind", "mult")) == "base":
		return 1.0
	if span <= 0.0:
		return 0.0
	return clampf(absf(log(maxf(float(entry.get("value", 1.0)), 0.0001))) / span,
		0.0, 1.0)


static func _bar_ink(entry: Dictionary) -> Color:
	if String(entry.get("kind", "mult")) == "base":
		return UiTheme.TEAL
	return UiTheme.AMBER if float(entry.get("value", 1.0)) >= 1.0 \
		else UiTheme.DANGER


func _play_bars() -> void:
	## The bars fill one after another, top to bottom: the order the economy
	## applies them is the order they are seen arriving.
	var index := 0
	for row in _rows.get_children():
		if row.is_queued_for_deletion():
			continue
		var bar := row.get_node_or_null(^"Bar") as RateBar
		if bar != null:
			bar.play(0.16 + index * 0.05)
		index += 1


class RateBar:
	extends Control
	## One factor's share, as a lit segment in a trough. Drawn on whole pixels.
	var share := 0.0
	var ink := Color.WHITE
	var grow := 1.0:
		set(value):
			grow = value
			queue_redraw()

	func play(delay: float) -> void:
		if not UiMotion.live():
			grow = 1.0
			return
		grow = 0.0
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(self, "grow", 1.0, 0.34) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var h := 6.0
		var y := floorf((size.y - h) * 0.5)
		draw_rect(Rect2(0, y, size.x, h), Color8(9, 12, 21))
		draw_rect(Rect2(1, y + 1, size.x - 2, h - 2), Color8(14, 19, 31))
		if share <= 0.0:
			return
		var w := maxf(2.0, roundf((size.x - 2.0) * share * grow))
		if grow <= 0.0:
			return
		draw_rect(Rect2(1, y + 1, w, h - 2), ink)
		draw_rect(Rect2(1, y + 1, w, 1), ink.lightened(0.45))
		draw_rect(Rect2(1, y + h - 2, w, 1), ink.darkened(0.3))
		# the lit head of the bar
		draw_rect(Rect2(w, y + 1, 1, h - 2), ink.lightened(0.7))


func _row(name_text: String, value_text: String, inert: bool = false,
		share: float = 0.0, ink: Color = Color.WHITE) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	var name_ink := UiTheme.PAPER_DEEP if inert else UiTheme.INK_SOFT
	var value_ink := UiTheme.PAPER_DEEP if inert else UiTheme.INK
	var label := UiTheme.label(name_text, UiTheme.SIZE_SMALL, name_ink)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	row.add_child(label)
	var bar := RateBar.new()
	bar.name = "Bar"
	bar.share = 0.0 if inert else share
	bar.ink = ink
	bar.custom_minimum_size = Vector2(76, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var value := UiTheme.label(value_text, UiTheme.SIZE_SMALL, value_ink)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = 64
	row.add_child(value)
	return row


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect", Rect2())
	_layout()


func _layout() -> void:
	if _panel == null:
		return
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	# Fixed on both axes, like every other board here: a panel that asks for its
	# own height depends on Godot's deferred minimum-size pass and can draw one
	# frame at the wrong size.
	# Its height is computed, not asked for: nameplate, one line per factor, the
	# rule and the total, inside the board's margins. A fixed 240 left half the
	# board as empty paper under seven short rows.
	var lines := GameState.cps_breakdown().size()
	var wanted := Vector2(minf(MAX_WIDTH, safe.size.x - 24.0),
		minf(30.0 + 4.0 + lines * 14.0 + 44.0 + 22.0, safe.size.y - 24.0))
	_panel.custom_minimum_size = wanted
	_panel.size = wanted
	_panel.position = safe.position + (safe.size - wanted) * 0.5
