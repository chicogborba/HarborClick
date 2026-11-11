class_name BoostChips
extends CanvasLayer
## What is multiplying the port right now, and for how long.
##
## A x7 frenzy used to be a number that quietly changed in the counter: no icon,
## no clock, nothing to say it was running out. Each active bonus gets a chip
## under the gantry — an icon, the multiplier and the seconds left — and a chip
## that is not earning anything is not there. Built once, rewritten in place,
## four times a second.

const TICK := 0.12
const GAP := 4.0

var _luck: Dictionary = {}
var _combo: Dictionary = {}
var _row: HBoxContainer
var _safe_rect := Rect2()
var _world_rect := Rect2()
var _tick := 0.0


func _ready() -> void:
	layer = 7
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", int(GAP))
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_luck = _make_chip(UiTheme.Icon16.BOOST, "boost.output")
	_combo = _make_chip(UiTheme.Icon16.COMBO, "boost.combo")
	refresh()
	_layout()


func _make_chip(icon: UiTheme.Icon16, caption_key: String) -> Dictionary:
	var panel := UiTheme.panel(UiTheme.tag_style(3))
	panel.visible = false
	_row.add_child(panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	box.add_child(UiTheme.icon16(icon))
	# The word: a bare "x7 24s" never said *what* was multiplied.
	var caption := UiTheme.label(Loc.t(caption_key), UiTheme.SIZE_SMALL, UiTheme.STEEL_DIM)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(caption)
	var label := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return {"panel": panel, "label": label}


static func chip_text(mult: float, seconds: float) -> String:
	## "x7 24s", "x2 1m05" — short enough for a 44px-tall tag on a phone.
	var m := roundi(mult * 10.0)
	var head := "x%d" % (m / 10) if m % 10 == 0 else "x%.1f" % (float(m) / 10.0)
	var s := ceili(seconds)
	var tail := "%ds" % s if s < 60 else "%dm%02d" % [s / 60, s % 60]
	return "%s %s" % [head, tail]


func refresh() -> void:
	if _row == null:
		return
	_set_chip(_luck, GameState.surge_mult, GameState.surge_time)
	var now := GameState.combo_now()
	var on := GameState.combo.is_active(now)
	(_combo.panel as Control).visible = on
	if on:
		var label: Label = _combo.label
		label.text = "x%.2f" % GameState.combo.multiplier(now)
		label.label_settings.font_color = UiTheme.AMBER if GameState.combo.is_maxed(now) \
			else UiTheme.CREAM
	# A chip appearing changes the row's width, and the row hangs from the right.
	_layout()


func _set_chip(chip: Dictionary, mult: float, seconds: float) -> void:
	var active := seconds > 0.0 and not is_equal_approx(mult, 1.0)
	(chip.panel as Control).visible = active
	if active:
		var label: Label = chip.label
		label.text = chip_text(mult, seconds)
		# Below one, it is a penalty (a failed charter): say so in the colour.
		label.label_settings.font_color = UiTheme.AMBER if mult >= 1.0 else UiTheme.DANGER


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= TICK:
		_tick = 0.0
		refresh()


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, view))
	_world_rect = metrics.get("world_rect", _safe_rect)
	_layout()


func _layout() -> void:
	if _row == null or not is_instance_valid(_row):
		return
	var view := get_viewport().get_visible_rect().size
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, view)
	var area := safe
	if _world_rect.size.x > 0.0 and _world_rect.size.y > 0.0:
		var inside := _world_rect.intersection(safe)
		if inside.size.x > 0.0 and inside.size.y > 0.0:
			area = inside
	_row.reset_size()
	_row.position = (Vector2(area.end.x - _row.size.x - 6.0,
		area.position.y + Hud.BAR_H + 4.0)).round()
