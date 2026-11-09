class_name PortClock
extends CanvasLayer
## What day it is, what time it is, what the sky is doing and how hard it blows.
##
## Modelled on the one thing a harbour office always has and a clicker usually
## lacks — a glance that answers "where am I in the day?" without opening
## anything. The dial is a twenty-four hour face, because a port works round the
## clock and an AM/PM hand would be ambiguous exactly when it matters.
##
## It is a brass porthole set into the right-hand end of the `Hud` gantry, not a
## board of its own. The clock and the tally are the same instrument panel seen
## from either end, so the clock owns no background: `Hud.BAR_H` is the contract
## that keeps it inside the steel the tally is mounted in.
##
## The dial is a painted sky disc that turns, not a hand on a face: it says what
## the light is doing without being read.

const WEATHER := preload("res://assets/sprites/ui_weather.png")
const FACE := preload("res://assets/sprites/prop_clock_face.png")
const BEZEL := preload("res://assets/sprites/prop_clock_bezel.png")
const GLYPH := 14
## Beaufort in three steps, which is all a glance needs. Keys rather than words:
## the pips are what the player sees, and the word only ever reaches a screen
## reader — which is exactly the audience that must not be read Portuguese.
const WIND_KEYS := ["clock.wind.calm", "clock.wind.fresh", "clock.wind.strong"]

## The dial moved or changed width. `Hud` listens, because the tally's budget is
## "everything up to the clock", and the clock is not a fixed width: "DIA 1" and
## "GIORNO 100" are different lengths, and the board is anchored by its right edge
## so it grows leftwards towards the tally.
signal footprint_changed

var _board: HBoxContainer
var _last_edge := NAN
var _dial: Control
var _sky: Sprite2D
var _weather: TextureRect
var _time: Label
var _day: Label
var _wind_pips: Array[ColorRect] = []
var _safe_rect := Rect2()
var _world_rect := Rect2()
var _glyph := -1
var _wind_step := -1


func _ready() -> void:
	layer = 6
	_board = HBoxContainer.new()
	_board.add_theme_constant_override(&"separation", 4)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)

	# A window onto the sky rather than a hand on a face: the disc is painted with
	# noon at the top and midnight at the bottom, and it turns so the hour the
	# port is living is always under the pointer.
	_dial = Control.new()
	_dial.custom_minimum_size = BEZEL.get_size()
	_dial.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_dial)
	_sky = Sprite2D.new()
	_sky.texture = FACE
	_sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sky.position = BEZEL.get_size() * 0.5
	_dial.add_child(_sky)
	var bezel := Sprite2D.new()
	bezel.texture = BEZEL
	bezel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bezel.position = BEZEL.get_size() * 0.5
	_dial.add_child(bezel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 1)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 3)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	_weather = TextureRect.new()
	_weather.custom_minimum_size = Vector2(GLYPH, GLYPH)
	_weather.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_weather.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_weather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_weather)
	_time = UiTheme.label("--:--", UiTheme.SIZE_BODY, UiTheme.DIGIT)
	_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_time)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override(&"separation", 4)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(foot)
	_day = UiTheme.label(Loc.t("clock.day", {"n": 1}), UiTheme.SIZE_SMALL,
		UiTheme.STEEL_DIM)
	foot.add_child(_day)
	# The wind used to be spelled out, and "VENTO FRESCO" is eleven characters of
	# the bar spent on a value with three states. Three pips say the same thing in
	# twelve pixels, and the words stay in the accessibility label for anyone who
	# cannot see them.
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override(&"separation", 2)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(pips)
	for step in 3:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(2.0, 3.0 + step * 2.0)
		pip.size_flags_vertical = Control.SIZE_SHRINK_END
		pip.color = UiTheme.HULL_EDGE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
		_wind_pips.append(pip)

	_set_glyph(TimeManager.weather_glyph())
	_set_wind(_wind_step_now())
	_layout()


func _process(_delta: float) -> void:
	if not visible:
		return
	_time.text = TimeManager.clock_text()
	var day := Loc.t("clock.day", {"n": TimeManager.day})
	if day != _day.text:
		_day.text = day
		# Day 9 to day 10, or a language switch, widens the board. It was laid out
		# once and then simply grew to the right, over the notice bell.
		_layout()
	_set_glyph(TimeManager.weather_glyph())
	_set_wind(_wind_step_now())
	# Counter-clockwise on screen, because the disc is painted with the hours
	# running clockwise from noon at the top.
	_sky.rotation = -TAU * (TimeManager.time_of_day - 0.5)


func _wind_step_now() -> int:
	if TimeManager.wind < 0.33:
		return 0
	return 1 if TimeManager.wind < 0.7 else 2


func _set_wind(step: int) -> void:
	if step == _wind_step:
		return
	_wind_step = step
	for index in _wind_pips.size():
		_wind_pips[index].color = UiTheme.TEAL_LIGHT if index <= step \
			else UiTheme.HULL_EDGE
	UiTheme.describe(_board, Loc.t("clock.name"),
		Loc.t("clock.hint", {"wind": Loc.t(WIND_KEYS[step])}))


func _set_glyph(index: int) -> void:
	if index == _glyph:
		return
	_glyph = index
	var atlas := AtlasTexture.new()
	atlas.atlas = WEATHER
	atlas.region = Rect2(index * GLYPH, 0, GLYPH, GLYPH)
	_weather.texture = atlas


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_world_rect = metrics.get("world_rect", _safe_rect)
	_layout()


func _layout() -> void:
	if _board == null or not is_instance_valid(_board):
		return
	var area := _world_rect if _world_rect.size != Vector2.ZERO else _safe_rect
	if area.size == Vector2.ZERO:
		area = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_board.reset_size()
	var size := _board.get_combined_minimum_size()
	_board.size = size
	# The right-hand end of the gantry, inboard of the notice bell, and centred in
	# the panel's face rather than its full height: the amber hairline along the
	# bottom is the panel's edge, not room for an instrument.
	_board.position = Vector2(
		area.end.x - size.x - 7.0 - NoticeBell.RESERVE,
		area.position.y + floorf((Hud.BAR_H - 4.0 - size.y) * 0.5))
	var edge := left_edge()
	if edge != _last_edge:
		_last_edge = edge
		footprint_changed.emit()


func left_edge() -> float:
	## Where the dial begins, in the same canvas space the gantry is laid out in.
	return _board.get_global_rect().position.x if _board != null else INF
