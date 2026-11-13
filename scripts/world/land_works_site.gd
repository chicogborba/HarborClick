class_name LandWorksSite
extends Node2D
## A parcel being made: the strip of bare ground south of the pavement, fenced
## off, with a roller laying asphalt across it as the clock runs down.
##
## Buying land used to be a number going down and the terminal jumping a row
## longer in the same frame. Now the purchase breaks ground
## (`GameState.land_works`) and this is what that looks like from the yard: how
## much is paved *is* the progress bar, and the board on the fence carries the
## time left. Tapping the site opens the works in the shop, where an
## advertisement finishes them.
##
## Presentation only: it reads `GameState.land_works` and draws. Hidden, and
## not processing, whenever no works are under way.

const ASPHALT := Color8(98, 92, 100)
const ASPHALT_L := Color8(116, 110, 116)
const GRADED := Color8(170, 124, 80)
const GRADED_D := Color8(140, 98, 62)
const INK := Color8(24, 20, 30)
const SAFETY := Color8(244, 132, 40)
const WHITE := Color8(244, 238, 222)
const MACHINE := Color8(240, 190, 52)
const MACHINE_D := Color8(176, 124, 30)

var _world: Node
var _label: Label
var _t := 0.0
var _dust := 0.0


func setup(world: Node) -> void:
	_world = world
	_label = Label.new()
	_label.label_settings = UiTheme.settings(UiTheme.SIZE_SMALL, UiTheme.AMBER)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.z_index = 2
	add_child(_label)
	EventBus.land_works_changed.connect(_sync)
	EventBus.land_bought.connect(func(_id: String) -> void: _sync())
	_sync()


func active() -> bool:
	return visible


func hit_test(world_pos: Vector2) -> bool:
	return visible and PortLayout.land_works_rect().grow(4.0).has_point(world_pos)


func centre() -> Vector2:
	return PortLayout.land_works_rect().get_center()


func _sync() -> void:
	visible = not GameState.land_works.is_empty()
	set_process(visible)
	queue_redraw()


func _progress() -> float:
	var works := GameState.land_works
	if works.is_empty():
		return 0.0
	return clampf(1.0 - float(works.left) / maxf(1.0, float(works.total)), 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	var works := GameState.land_works
	if works.is_empty():
		return
	var left := maxf(0.0, float(works.left))
	var text := "%s %d:%02d" % [Loc.t("land.works.sign"), int(left) / 60, int(left) % 60]
	if _label.text != text:
		_label.text = text
		var area := PortLayout.land_works_rect()
		_label.reset_size()
		_label.position = Vector2(
			roundf(area.end.x - _label.size.x - 12.0), area.position.y + 6.0)
	_dust += delta
	if _dust > 0.9 and UserPreferences.can_animate() and _world != null \
			and _world.has_method("spawn_dust"):
		_dust = 0.0
		var area := PortLayout.land_works_rect()
		_world.spawn_dust(Vector2(area.position.x + area.size.x * _progress() + 6.0,
			area.position.y + area.size.y * (0.3 + 0.4 * randf())))
	queue_redraw()


func _draw() -> void:
	if GameState.land_works.is_empty():
		return
	var area := PortLayout.land_works_rect()
	var front := roundf(area.size.x * _progress())
	# Graded earth, then the asphalt laid over it so far.
	draw_rect(area, GRADED)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9173
	for i in 60:
		var at := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		draw_rect(Rect2(at.round(), Vector2(rng.randi_range(2, 5), 1)), GRADED_D)
	if front > 0.0:
		draw_rect(Rect2(area.position, Vector2(front, area.size.y)), ASPHALT)
		for i in 40:
			var at := area.position + Vector2(rng.randf() * front, rng.randf() * area.size.y)
			draw_rect(Rect2(at.round(), Vector2(1, 1)), ASPHALT_L)
		draw_rect(Rect2(area.position.x + front - 2.0, area.position.y, 2.0, area.size.y),
			INK)
	# The roller, working the front back and forth across the strip.
	var sweep := 0.5 + 0.5 * sin(_t * 0.9) if UserPreferences.can_animate() else 0.5
	var roller := Vector2(area.position.x + front + 2.0,
		area.position.y + 4.0 + roundf((area.size.y - 22.0) * sweep))
	roller.x = minf(roller.x, area.end.x - 18.0)
	draw_rect(Rect2(roller + Vector2(1, 2), Vector2(16, 14)), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(roller, Vector2(5, 14)), INK)
	draw_rect(Rect2(roller + Vector2(1, 1), Vector2(3, 12)), Color8(92, 100, 118))
	draw_rect(Rect2(roller + Vector2(5, 2), Vector2(10, 10)), INK)
	draw_rect(Rect2(roller + Vector2(6, 3), Vector2(8, 8)), MACHINE)
	draw_rect(Rect2(roller + Vector2(6, 9), Vector2(8, 2)), MACHINE_D)
	draw_rect(Rect2(roller + Vector2(9, 4), Vector2(4, 4)), Color8(120, 190, 210))
	# Barriers all the way round: orange and white, a post every few pixels.
	var x := area.position.x
	var n := 0
	while x < area.end.x:
		var color := SAFETY if n % 2 == 0 else WHITE
		draw_rect(Rect2(x, area.position.y - 2.0, 6.0, 3.0), color)
		draw_rect(Rect2(x, area.end.y - 1.0, 6.0, 3.0), color)
		x += 6.0
		n += 1
	var y := area.position.y
	n = 0
	while y < area.end.y:
		var color := SAFETY if n % 2 == 0 else WHITE
		draw_rect(Rect2(area.position.x - 1.0, y, 3.0, 6.0), color)
		draw_rect(Rect2(area.end.x - 2.0, y, 3.0, 6.0), color)
		y += 6.0
		n += 1
	# The board on the fence: what this is, and how long it has left.
	if _label != null and not _label.text.is_empty():
		var board := Rect2(_label.position - Vector2(4, 2), _label.size + Vector2(8, 3))
		draw_rect(Rect2(board.position + Vector2(1, 2), board.size), Color(0, 0, 0, 0.3))
		draw_rect(board, INK)
		draw_rect(board.grow(-1.0), Color8(34, 30, 44))
		draw_rect(Rect2(board.position.x + 1.0, board.end.y - 2.0, board.size.x - 2.0, 1.0),
			SAFETY)
	# Cones on the earth still to do.
	for i in 3:
		var cone := Vector2(area.end.x - 24.0 - i * 26.0, area.position.y + 30.0 + (i % 2) * 14.0)
		if cone.x < area.position.x + front + 22.0:
			continue
		draw_rect(Rect2(cone + Vector2(-1, 4), Vector2(6, 2)), SAFETY)
		draw_rect(Rect2(cone + Vector2(0, 1), Vector2(4, 3)), SAFETY)
		draw_rect(Rect2(cone + Vector2(0, 2), Vector2(4, 1)), WHITE)
		draw_rect(Rect2(cone + Vector2(1, -1), Vector2(2, 2)), SAFETY)
