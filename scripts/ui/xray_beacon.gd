class_name XrayBeacon
extends CanvasLayer
## The way back to the scanner when it is somewhere the player is not looking.
##
## A waiting inspection lights the post red (`XrayStation`), but the camera
## only scrolls one way and the post is one building in a long yard: a player
## working the quay never sees it. While a lorry waits and the post is off
## screen, a red tag stands on the edge of the view nearest to it — top when it
## is up the yard, bottom when it is down — with an arrow pointing that way.
## Tapping the tag brings the camera to the post; once the post is on screen
## the tag goes, and the post's own rings take over.
##
## Presentation only: Main says what is due and whether the port is being
## played (`setup`), this node only decides where the tag stands.

signal pressed

const H := 22.0
const ARROW := 5.0
const RED := Color8(206, 52, 42)
const RED_DEEP := Color8(120, 24, 22)

var _station: XrayStation
var _is_due: Callable
var _can_show: Callable
var _button: Button
var _arrow: _Arrow
var _safe_rect := Rect2()
var _world_rect := Rect2()
var _t := 0.0
## +1 below the view, -1 above it, 0 on screen.
var _side := 0


func _ready() -> void:
	layer = 6
	_button = Button.new()
	_button.name = "Tag"
	_button.text = "!  " + Loc.t("xray.beacon")
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_override(&"font", UiTheme.FONT)
	_button.add_theme_font_size_override(&"font_size", UiTheme.SIZE_SMALL)
	for state: StringName in [&"font_color", &"font_hover_color",
			&"font_pressed_color", &"font_focus_color"]:
		_button.add_theme_color_override(state, UiTheme.CREAM)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = RED_DEEP if state == &"pressed" else RED
		box.border_color = UiTheme.HULL_EDGE
		box.set_border_width_all(1)
		box.border_width_bottom = 2
		box.content_margin_left = 6
		box.content_margin_right = 6
		_button.add_theme_stylebox_override(state, box)
	UiTheme.describe(_button, Loc.t("xray.title"))
	_button.pressed.connect(func() -> void:
		AudioManager.play_sfx("tap")
		pressed.emit())
	_button.visible = false
	add_child(_button)
	_arrow = _Arrow.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	add_child(_arrow)


func setup(station: XrayStation, is_due: Callable, can_show: Callable) -> void:
	_station = station
	_is_due = is_due
	_can_show = can_show


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, view))
	_world_rect = metrics.get("world_rect", _safe_rect)


func side() -> int:
	## Where the tag is standing, for tests: -1 top, +1 bottom, 0 hidden.
	return _side if _button.visible else 0


func tag_rect() -> Rect2:
	return _button.get_global_rect() if _button.visible else Rect2()


func _process(delta: float) -> void:
	_t += delta
	_side = _offscreen_side()
	var show := _side != 0
	_button.visible = show
	_arrow.visible = show
	if show:
		_layout()


func _offscreen_side() -> int:
	if _station == null or not is_instance_valid(_station) \
			or not _station.visible or _station.state != XrayStation.State.DUE:
		return 0
	if _is_due.is_valid() and not bool(_is_due.call()):
		return 0
	if _can_show.is_valid() and not bool(_can_show.call()):
		return 0
	var view := _view_band()
	var xform := get_viewport().get_canvas_transform()
	var top := (xform * _station.global_position).y
	var bottom := (xform * (_station.global_position + XrayStation.FRAME)).y
	# Half the post showing counts as seen: its rings are bigger than it is.
	var mid := (top + bottom) * 0.5
	if mid < view.x:
		return -1
	if mid > view.y:
		return 1
	return 0


func _view_band() -> Vector2:
	## The slice of the screen the yard actually shows: under the gantry, over
	## the console.
	var area := _area()
	return Vector2(area.position.y + Hud.BAR_H, area.end.y - CommandRail.BAR_H)


func _area() -> Rect2:
	var view := get_viewport().get_visible_rect().size
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, view)
	if _world_rect.size.x > 0.0 and _world_rect.size.y > 0.0:
		var inside := _world_rect.intersection(safe)
		if inside.size.x > 0.0 and inside.size.y > 0.0:
			return inside
	return safe


func _layout() -> void:
	var area := _area()
	var band := _view_band()
	_button.reset_size()
	var size := Vector2(_button.size.x, H)
	_button.size = size
	# A beat of a hop toward the post, never a scale: the pixels stay crisp.
	var hop := 0.0
	if UserPreferences.can_animate():
		hop = roundf(absf(sin(_t * 5.0)) * 3.0) * float(_side)
	# Centred: the bar under the gantry carries the level badge on the left
	# and the bell on the right, and the middle is the one place both edges
	# keep clear.
	var x := area.position.x + (area.size.x - size.x) * 0.5
	var y := band.x + 6.0 + ARROW if _side < 0 else band.y - 6.0 - ARROW - size.y
	_button.position = Vector2(x, y + hop).round()
	_arrow.down = _side > 0
	_arrow.size = Vector2(ARROW * 2.0 + 2.0, ARROW)
	var ax := _button.position.x + size.x * 0.5 - _arrow.size.x * 0.5
	var ay := _button.position.y - ARROW if _side < 0 else _button.position.y + size.y
	_arrow.position = Vector2(ax, ay).round()
	_arrow.queue_redraw()


class _Arrow extends Control:
	var down := false

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var tip := Vector2(w * 0.5, h if down else 0.0)
		var base_y := 0.0 if down else h
		var points := PackedVector2Array([Vector2(0, base_y), Vector2(w, base_y), tip])
		draw_colored_polygon(points, UiTheme.HULL_EDGE)
		var inner := PackedVector2Array([Vector2(2, base_y + (1.0 if down else -1.0)),
			Vector2(w - 2, base_y + (1.0 if down else -1.0)),
			tip + Vector2(0, -2.0 if down else 2.0)])
		draw_colored_polygon(inner, XrayBeacon.RED)
