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
## The crew is on it too: workers from the yard's own sheet dig, tamp and wheel
## barrows across the earth still to do, and a flagman stands at the corner.
##
## Before any of that, the same strip is where the *offer* shows: when the next
## parcel can be paid for, the ground is staked out with a board on it, so land
## announces itself in the yard the way a buyable upgrade does on its tab.
##
## Presentation only: it reads `GameState` and draws. Hidden whenever there are
## neither works nor an offer.

const ASPHALT := Color8(98, 92, 100)
const ASPHALT_L := Color8(116, 110, 116)
const GRADED := Color8(170, 124, 80)
const GRADED_D := Color8(140, 98, 62)
const INK := Color8(24, 20, 30)
const SAFETY := Color8(244, 132, 40)
const WHITE := Color8(244, 238, 222)
const MACHINE := Color8(240, 190, 52)
const MACHINE_D := Color8(176, 124, 30)

const WORKERS := preload("res://assets/sprites/worker_sheet.png")
const WORKER := Vector2(9, 12)
const CREW := 6

var _world: Node
var _label: Label
var _t := 0.0
var _dust := 0.0
## True while the next parcel is affordable and nothing is being built.
var _sale := false
var _poll := 0.0
## {pos, to, wait, job: dig|barrow|flag, face} per worker.
var _crew: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


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
	var working := not GameState.land_works.is_empty()
	var parcel := GameState.next_land()
	_sale = not working and not parcel.is_empty() and FeatureGate.unlocked(&"land") \
		and GameState.can_afford(float(parcel.cost))
	visible = working or _sale
	if working and _crew.is_empty():
		_muster()
	elif not working:
		_crew.clear()
	if _sale:
		_place_label(Loc.t("land.sale.sign"))
	queue_redraw()


func _muster() -> void:
	## The crew walks on from the pavement side and spreads over the earth.
	var area := PortLayout.land_works_rect()
	_rng.seed = 5150
	for i in CREW:
		var job := &"flag" if i == 0 else (&"barrow" if i == 1 else &"dig")
		var start := Vector2(area.position.x + area.size.x * _rng.randf_range(0.3, 0.9),
			area.position.y + 6.0)
		_crew.append({"pos": start, "to": start, "wait": _rng.randf_range(0.0, 1.0),
			"job": job, "face": 1.0, "load": true})


func _place_label(text: String) -> void:
	_label.text = text
	var area := PortLayout.land_works_rect()
	_label.reset_size()
	_label.position = Vector2(
		roundf(area.end.x - _label.size.x - 12.0), area.position.y + 6.0)


func _step_crew(delta: float) -> void:
	var area := PortLayout.land_works_rect()
	var front := area.position.x + area.size.x * _progress()
	# Where there is still earth: east of the roller, inside the fence.
	var earth := Rect2(minf(front + 20.0, area.end.x - 40.0), area.position.y + 20.0,
		0.0, area.size.y - 36.0)
	earth.size.x = maxf(24.0, area.end.x - 10.0 - earth.position.x)
	for worker: Dictionary in _crew:
		var pos: Vector2 = worker.pos
		var to: Vector2 = worker.to
		if StringName(worker.job) == &"flag":
			worker.pos = Vector2(area.end.x - 8.0, area.end.y - 16.0)
			continue
		if pos.distance_to(to) > 1.0:
			var step := (to - pos).normalized() * (16.0 if worker.job == &"barrow" else 12.0) * delta
			worker.pos = pos + step
			if absf(step.x) > 0.01:
				worker.face = signf(step.x)
			continue
		worker.wait = float(worker.wait) - delta
		if float(worker.wait) > 0.0:
			continue
		if StringName(worker.job) == &"barrow":
			# Heap by the east fence to the roller's front, and back again.
			worker.load = not bool(worker.load)
			worker.to = Vector2(area.end.x - 18.0, area.position.y + 26.0) \
				if not bool(worker.load) else Vector2(earth.position.x + 4.0,
					earth.position.y + _rng.randf() * earth.size.y)
			worker.wait = 0.8
		else:
			worker.to = Vector2(earth.position.x + _rng.randf() * earth.size.x,
				earth.position.y + _rng.randf() * earth.size.y)
			worker.wait = _rng.randf_range(1.6, 3.4)


func _draw_crew() -> void:
	var order := _crew.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float((a.pos as Vector2).y) < float((b.pos as Vector2).y))
	for worker: Dictionary in order:
		var pos := (worker.pos as Vector2).round()
		var moving := (worker.pos as Vector2).distance_to(worker.to) > 1.0
		var job := StringName(worker.job)
		var frame := int(_t * 7.0) % 4 if moving else 0
		var face := float(worker.face)
		var feet := pos - Vector2(WORKER.x * 0.5, WORKER.y)
		draw_rect(Rect2(pos + Vector2(-4, -1), Vector2(8, 2)), Color(0, 0, 0, 0.25))
		var dest := Rect2(feet, WORKER)
		if face < 0.0:
			dest = Rect2(feet + Vector2(WORKER.x, 0), Vector2(-WORKER.x, WORKER.y))
		draw_texture_rect_region(WORKERS, dest, Rect2(frame * WORKER.x, 0, WORKER.x, WORKER.y))
		match job:
			&"flag":
				# A paddle, turned once a second: stop, go.
				var go := int(_t) % 2 == 0
				draw_rect(Rect2(pos + Vector2(-7, -13), Vector2(1, 9)), INK)
				draw_rect(Rect2(pos + Vector2(-9, -15), Vector2(5, 4)),
					Color8(72, 168, 96) if go else Color8(212, 56, 48))
			&"barrow":
				var bx := pos.x + face * 6.0
				draw_rect(Rect2(bx - 3.0, pos.y - 6.0, 7, 4), INK)
				draw_rect(Rect2(bx - 2.0, pos.y - 5.0, 5, 2), Color8(92, 100, 118))
				if bool(worker.load):
					draw_rect(Rect2(bx - 2.0, pos.y - 7.0, 5, 2), Color8(70, 66, 74))
				draw_rect(Rect2(bx, pos.y - 2.0, 2, 2), INK)
			_:
				if not moving:
					# The shovel goes in, comes up, goes in.
					var up := int(_t * 3.0 + pos.x) % 2 == 0
					var sx := pos.x + face * 5.0
					draw_rect(Rect2(sx, pos.y - (9.0 if up else 6.0), 1, 7), Color8(120, 84, 52))
					draw_rect(Rect2(sx - 1.0, pos.y - (3.0 if up else 0.0), 3, 2),
						Color8(170, 176, 188))
					if not up:
						draw_rect(Rect2(sx + face * 2.0, pos.y - 2.0, 2, 1), GRADED_D)


func _draw_sale() -> void:
	## Staked out and for sale: corner posts, a rope, and the board.
	var area := PortLayout.land_works_rect()
	var pulse := 0.55 + 0.45 * sin(_t * 3.0) if UserPreferences.can_animate() else 1.0
	var rope := Color(UiTheme.AMBER, 0.5 + 0.5 * pulse)
	var x := area.position.x + 2.0
	while x < area.end.x - 4.0:
		draw_rect(Rect2(x, area.position.y + 2.0, 4, 1), rope)
		draw_rect(Rect2(x, area.end.y - 3.0, 4, 1), rope)
		x += 8.0
	var y := area.position.y + 2.0
	while y < area.end.y - 4.0:
		draw_rect(Rect2(area.position.x + 2.0, y, 1, 4), rope)
		draw_rect(Rect2(area.end.x - 3.0, y, 1, 4), rope)
		y += 8.0
	for corner: Vector2 in [area.position, Vector2(area.end.x - 4.0, area.position.y),
			Vector2(area.position.x, area.end.y - 6.0), area.end - Vector2(4, 6)]:
		draw_rect(Rect2(corner, Vector2(4, 6)), INK)
		draw_rect(Rect2(corner + Vector2(1, 1), Vector2(2, 4)), SAFETY)
	if _label != null and not _label.text.is_empty():
		var board := Rect2(_label.position - Vector2(4, 2), _label.size + Vector2(8, 3))
		draw_rect(Rect2(board.get_center().x - 1.0, board.end.y, 2, 12), INK)
		draw_rect(Rect2(board.position + Vector2(1, 2), board.size), Color(0, 0, 0, 0.3))
		draw_rect(board, INK)
		draw_rect(board.grow(-1.0), Color8(36, 114, 52))
		# The arrow that says: here.
		var tip := Vector2(board.get_center().x, board.position.y - 5.0
			- roundf(2.0 * sin(_t * 5.0)))
		for i in 4:
			draw_rect(Rect2(tip.x - i, tip.y - i * 1.0, i * 2.0 + 1.0, 1), UiTheme.AMBER)


func _progress() -> float:
	var works := GameState.land_works
	if works.is_empty():
		return 0.0
	return clampf(1.0 - float(works.left) / maxf(1.0, float(works.total)), 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	_poll += delta
	if _poll > 0.5:
		_poll = 0.0
		_sync()
	if not visible:
		return
	var works := GameState.land_works
	if works.is_empty():
		_label.label_settings.font_color = UiTheme.CREAM
		queue_redraw()
		return
	_label.label_settings.font_color = UiTheme.AMBER
	if UserPreferences.can_animate():
		_step_crew(delta)
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
		if _sale:
			_draw_sale()
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
	_draw_crew()
	# Cones on the earth still to do.
	for i in 3:
		var cone := Vector2(area.end.x - 24.0 - i * 26.0, area.position.y + 30.0 + (i % 2) * 14.0)
		if cone.x < area.position.x + front + 22.0:
			continue
		draw_rect(Rect2(cone + Vector2(-1, 4), Vector2(6, 2)), SAFETY)
		draw_rect(Rect2(cone + Vector2(0, 1), Vector2(4, 3)), SAFETY)
		draw_rect(Rect2(cone + Vector2(0, 2), Vector2(4, 1)), WHITE)
		draw_rect(Rect2(cone + Vector2(1, -1), Vector2(2, 2)), SAFETY)
