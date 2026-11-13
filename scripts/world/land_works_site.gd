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
const EXCAVATOR := preload("res://assets/sprites/works_excavator.png")
const DUMPER := preload("res://assets/sprites/works_dumper.png")
const MIXER := preload("res://assets/sprites/works_mixer.png")
const ROLLER := preload("res://assets/sprites/works_roller.png")
const JIB := preload("res://assets/sprites/works_jib.png")
const CRANE_BASE := preload("res://assets/sprites/works_crane_base.png")
const TROLLEY := preload("res://assets/sprites/works_trolley.png")
const LOADS := preload("res://assets/sprites/works_loads.png")
const PROPS := preload("res://assets/sprites/works_props.png")
const CABIN := preload("res://assets/sprites/works_cabin.png")
## Mast centre in `works_jib.png` (tools/sprites/gen_works.py JIB_PIVOT).
const JIB_PIVOT := Vector2(26, 5)
const PROP := Vector2(20, 18)
## The yard behind the works, kept at the east end: crane, office, stock.
const STAGING_W := 58.0
## Width of the formwork-and-pour band and of the dig, ahead of the asphalt.
const POUR_W := 30.0
const PIT_W := 46.0
const CRANE_CYCLE := 9.0
const DUMPER_CYCLE := 7.0
const GRAVEL := Color8(150, 132, 108)
const GRAVEL_D := Color8(124, 108, 88)
const PIT := Color8(118, 84, 56)
const PIT_D := Color8(94, 66, 44)
const POURED := Color8(176, 174, 168)
const POURED_L := Color8(198, 196, 190)
const REBAR := Color8(170, 90, 56)
const FORM := Color8(150, 110, 64)
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
	_label.position = _board_label_position(area)


func _board_label_position(area: Rect2) -> Vector2:
	## For sale, the board stands on the staked ground; in works it is the
	## hoarding sign on the north fence, over the progress bar.
	if GameState.land_works.is_empty():
		return Vector2(roundf(area.end.x - _label.size.x - 12.0), area.position.y + 6.0)
	return Vector2(roundf(area.position.x + 10.0), area.position.y - _label.size.y - 9.0)


func _step_crew(delta: float) -> void:
	var area := PortLayout.land_works_rect()
	var zones := _zones(area)
	# The crew works the formwork band: tying rebar, levelling the pour.
	var earth := Rect2(zones.pour, area.position.y + 22.0,
		maxf(16.0, zones.pit - zones.pour), area.size.y - 30.0)
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
			worker.to = Vector2(zones.pit + 4.0, area.position.y + 30.0) \
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
		_label.reset_size()
		_label.position = _board_label_position(PortLayout.land_works_rect())
	_dust += delta
	if _dust > 0.9 and UserPreferences.can_animate() and _world != null \
			and _world.has_method("spawn_dust"):
		_dust = 0.0
		var area := PortLayout.land_works_rect()
		var zones := _zones(area)
		_world.spawn_dust(Vector2(zones.pit + 30.0 + randf() * 8.0,
			area.end.y - 14.0 - randf() * 6.0))
	queue_redraw()


func _zones(area: Rect2) -> Dictionary:
	## Where each trade is working, west to east: asphalt up to `front`, the
	## formwork and pour, the dig, untouched earth, and the staging yard. The
	## bands ride the front across the strip and squeeze up against the yard
	## as the parcel nears done.
	var stage := area.end.x - STAGING_W
	var front := area.position.x + roundf(area.size.x * _progress())
	# What is left between the asphalt and the yard: two fifths formwork,
	# the rest still being dug.
	var left := maxf(0.0, stage - front)
	var pour := minf(front, stage)
	var pit := pour + roundf(left * 0.4)
	return {"front": front, "pour": pour, "pit": pit, "earth": stage, "stage": stage}


func _frame(tex: Texture2D, frames: int, index: int, at: Vector2, flip := false) -> void:
	var w := float(tex.get_width()) / float(frames)
	var h := float(tex.get_height())
	var dest := Rect2(at.round(), Vector2(w, h))
	if flip:
		dest = Rect2(at.round() + Vector2(w, 0), Vector2(-w, h))
	draw_texture_rect_region(tex, dest, Rect2(index * w, 0, w, h))


func _shadow(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0, 0, 0, 0.22))


func _draw() -> void:
	if GameState.land_works.is_empty():
		if _sale:
			_draw_sale()
		return
	var area := PortLayout.land_works_rect()
	var zd := _zones(area)
	var z_front: float = zd.front
	var z_pour: float = zd.pour
	var z_pit: float = zd.pit
	var z_earth: float = zd.earth
	var z_stage: float = zd.stage
	var animate := UserPreferences.can_animate()
	var top := area.position.y
	var bottom := area.end.y
	var rng := RandomNumberGenerator.new()
	rng.seed = 9173
	# --- ground, east to west so each trade's edge sits on the last -----------
	draw_rect(area, GRADED)
	for i in 70:
		var at := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		draw_rect(Rect2(at.round(), Vector2(rng.randi_range(2, 5), 1)), GRADED_D)
	# staging yard: rolled gravel
	var stage_rect := Rect2(z_stage, top, area.end.x - z_stage, area.size.y)
	draw_rect(stage_rect, GRAVEL)
	for i in 50:
		var at := stage_rect.position + Vector2(rng.randf() * stage_rect.size.x,
			rng.randf() * stage_rect.size.y)
		draw_rect(Rect2(at.round(), Vector2.ONE), GRAVEL_D)
	# the dig: a sunken pit with its lip shadowed and the tracks in it
	if z_earth > z_pit:
		var pit := Rect2(z_pit, top + 3.0, z_earth - z_pit, area.size.y - 6.0)
		draw_rect(pit, PIT)
		draw_rect(Rect2(pit.position, Vector2(pit.size.x, 3)), PIT_D)
		draw_rect(Rect2(pit.end.x - 2.0, pit.position.y, 2, pit.size.y), PIT_D)
		var ty := bottom - 16.0
		var tx := pit.position.x + 2.0
		while tx < pit.end.x - 3.0:
			draw_rect(Rect2(tx, ty, 2, 1), PIT_D)
			draw_rect(Rect2(tx, ty + 9.0, 2, 1), PIT_D)
			tx += 4.0
	# formwork and pour: timber edge, a rebar mat, concrete poured over half
	if z_pit > z_pour:
		var pour := Rect2(z_pour, top + 2.0, z_pit - z_pour, area.size.y - 4.0)
		draw_rect(pour, GRADED_D)
		var x := pour.position.x + 1.0
		while x < pour.end.x:
			draw_rect(Rect2(x, pour.position.y, 1, pour.size.y), REBAR)
			x += 4.0
		var y := pour.position.y + 1.0
		while y < pour.end.y:
			draw_rect(Rect2(pour.position.x, y, pour.size.x, 1), REBAR)
			y += 4.0
		var poured := Rect2(pour.position, Vector2(roundf(pour.size.x * 0.5), pour.size.y))
		draw_rect(poured, POURED)
		for i in 12:
			var at := poured.position + Vector2(rng.randf() * poured.size.x,
				rng.randf() * poured.size.y)
			draw_rect(Rect2(at.round(), Vector2(2, 1)), POURED_L)
		draw_rect(Rect2(pour.position.x, pour.position.y, pour.size.x, 2), FORM)
		draw_rect(Rect2(pour.position.x, pour.end.y - 2.0, pour.size.x, 2), FORM)
		draw_rect(Rect2(pour.end.x - 2.0, pour.position.y, 2, pour.size.y), FORM)
	# asphalt laid so far, fresh and dark at the front
	var laid := z_front - area.position.x
	if laid > 0.0:
		draw_rect(Rect2(area.position, Vector2(laid, area.size.y)), ASPHALT)
		for i in 40:
			var at := area.position + Vector2(rng.randf() * laid, rng.randf() * area.size.y)
			draw_rect(Rect2(at.round(), Vector2.ONE), ASPHALT_L)
		draw_rect(Rect2(z_front - 8.0, top, 8.0, area.size.y), Color(0.12, 0.1, 0.14, 0.35))
		draw_rect(Rect2(z_front - 1.0, top, 1.0, area.size.y), INK)
	# --- the staging yard's furniture ----------------------------------------
	var east := area.end.x
	var col_a := east - 56.0
	var base := Vector2(col_a + 2.0, top + 5.0)
	draw_texture(CRANE_BASE, base)
	_frame(PROPS, 6, 0, Vector2(east - 26.0, top + 2.0))
	var heap := Vector2(col_a, top + 27.0)
	_frame(PROPS, 6, 3, heap)
	_frame(PROPS, 6, 4, Vector2(east - 28.0, top + 28.0))
	var stock := Vector2(col_a, top + 54.0)
	_frame(PROPS, 6, 1, stock)
	var cabin := Vector2(east - 36.0, top + 54.0)
	_shadow(Rect2(cabin, Vector2(34, 20)))
	draw_texture(CABIN, cabin)
	if z_pour - area.position.x > 40.0:
		_frame(PROPS, 6, 5, Vector2(z_pour - 30.0, bottom - 21.0))
		_frame(PROPS, 6, 2, Vector2(area.position.x + 6.0, bottom - 21.0))
	# --- machines -------------------------------------------------------------
	# Roller on the fresh asphalt, working up and down the front.
	var sweep := 0.5 + 0.5 * sin(_t * 0.9) if animate else 0.5
	var roller := Vector2(maxf(area.position.x + 2.0, z_front - 28.0),
		top + 4.0 + roundf((area.size.y - 22.0) * sweep))
	_shadow(Rect2(roller + Vector2(1, 1), Vector2(24, 14)))
	_frame(ROLLER, 2, int(_t * 4.0) % 2 if animate else 0, roller)
	# Mixer backed up to the pour, drum turning, chute over the formwork.
	if z_pit - z_pour >= 20.0:
		var mixer := Vector2(z_pour + 2.0, top + 5.0)
		_shadow(Rect2(mixer + Vector2(1, 1), Vector2(32, 14)))
		_frame(MIXER, 4, int(_t * 6.0) % 4 if animate else 0, mixer)
	# Excavator in the pit, taking bites out of the east face.
	if z_earth - z_pit >= 30.0:
		var digger := Vector2(minf(z_pit + 3.0, z_stage - 46.0), bottom - 26.0)
		_shadow(Rect2(digger + Vector2(1, 2), Vector2(20, 18)))
		_frame(EXCAVATOR, 4, int(_t * 2.5) % 4 if animate else 0, digger)
	# Dumper: loaded at the digger, out to the spoil heap, tip, back empty.
	var phase := fmod(_t / DUMPER_CYCLE, 1.0) if animate else 0.0
	var dump_x := heap.x - 30.0
	var load_x := minf(z_pit + 2.0, dump_x - 4.0)
	var lane := top + 30.0
	var dx := load_x
	var loaded := false
	var west := false
	if phase < 0.2:
		dx = load_x
		loaded = phase > 0.12
	elif phase < 0.5:
		dx = lerpf(load_x, dump_x, smoothstep(0.2, 0.5, phase))
		loaded = true
	elif phase < 0.62:
		dx = dump_x
		loaded = phase < 0.56
	else:
		dx = lerpf(dump_x, load_x, smoothstep(0.62, 1.0, phase))
		west = true
	if z_earth - z_pit >= 30.0:
		var truck := Vector2(dx, lane)
		_shadow(Rect2(truck + Vector2(1, 1), Vector2(30, 14)))
		_frame(DUMPER, 2, 1 if loaded else 0, truck, west)
	_draw_crew()
	# Cones along the asphalt front, where the roller turns.
	for i in 3:
		var cone := Vector2(z_front + 2.0, top + 14.0 + i * 22.0)
		if cone.x > z_stage - 6.0:
			break
		draw_rect(Rect2(cone + Vector2(-1, 4), Vector2(6, 2)), SAFETY)
		draw_rect(Rect2(cone + Vector2(0, 1), Vector2(4, 3)), SAFETY)
		draw_rect(Rect2(cone + Vector2(0, 2), Vector2(4, 1)), WHITE)
		draw_rect(Rect2(cone + Vector2(1, -1), Vector2(2, 2)), SAFETY)
	# --- barriers --------------------------------------------------------------
	var bx := area.position.x
	var n := 0
	while bx < area.end.x:
		var color := SAFETY if n % 2 == 0 else WHITE
		draw_rect(Rect2(bx, top - 2.0, 6.0, 3.0), color)
		draw_rect(Rect2(bx, bottom - 1.0, 6.0, 3.0), color)
		bx += 6.0
		n += 1
	var by := top
	n = 0
	while by < bottom:
		var color := SAFETY if n % 2 == 0 else WHITE
		draw_rect(Rect2(area.position.x - 1.0, by, 3.0, 6.0), color)
		draw_rect(Rect2(area.end.x - 2.0, by, 3.0, 6.0), color)
		by += 6.0
		n += 1
	# --- the tower crane, over everything ---------------------------------------
	_draw_crane(base + Vector2(8, 8), stock + Vector2(10, 8),
		Vector2(z_pour + 14.0, top + 40.0), animate)
	# --- the hoarding sign: what this is, how long, how far along ---------------
	_draw_board()


func _draw_crane(mast: Vector2, pick: Vector2, drop: Vector2, animate: bool) -> void:
	## Slews from the stock pile to the pour and back, trolley running out and
	## in along the jib, a load on the hook one way and an empty hook the other.
	var phase := fmod(_t / CRANE_CYCLE, 1.0) if animate else 0.35
	var a_pick := (pick - mast).angle()
	var a_drop := (drop - mast).angle()
	# Always the short way round.
	a_drop = a_pick + wrapf(a_drop - a_pick, -PI, PI)
	var r_pick := clampf(mast.distance_to(pick), 12.0, 54.0)
	var r_drop := clampf(mast.distance_to(drop), 12.0, 54.0)
	var k := 0.0
	var carrying := false
	if phase < 0.15:
		k = 0.0
		carrying = phase > 0.08
	elif phase < 0.5:
		k = smoothstep(0.15, 0.5, phase)
		carrying = true
	elif phase < 0.62:
		k = 1.0
		carrying = phase < 0.56
	else:
		k = 1.0 - smoothstep(0.62, 1.0, phase)
	var angle := lerpf(a_pick, a_drop, k)
	var reach := lerpf(r_pick, r_drop, k)
	var lift := Vector2(7, 11)  # how far the jib's shadow falls from it
	# Shadow of the jib on the ground, then the jib itself up in the air.
	draw_set_transform(mast + lift, angle)
	draw_texture(JIB, -JIB_PIVOT, Color(0, 0, 0, 0.22))
	draw_set_transform(mast, angle)
	draw_texture(JIB, -JIB_PIVOT)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var dir := Vector2.from_angle(angle)
	var trolley := (mast + dir * reach).round()
	draw_texture(TROLLEY, trolley - Vector2(3, 3))
	# The hook block hangs below the trolley; the load swings a pixel.
	var sway := roundf(sin(_t * 2.2)) if animate else 0.0
	var hook := trolley + Vector2(sway, 6.0)
	draw_rect(Rect2(trolley.x, trolley.y + 2.0, 1, hook.y - trolley.y - 2.0),
		Color(0.1, 0.08, 0.12, 0.8))
	if carrying:
		var cargo := int(_t / CRANE_CYCLE) % 3
		draw_rect(Rect2(hook + Vector2(-5, 7), Vector2(12, 4)), Color(0, 0, 0, 0.2))
		_frame(LOADS, 3, cargo, hook + Vector2(-6, 0))
	else:
		draw_rect(Rect2(hook + Vector2(-1, 0), Vector2(3, 3)), Color8(212, 56, 48))
		draw_rect(Rect2(hook + Vector2(0, 3), Vector2(1, 2)), INK)


func _draw_board() -> void:
	if _label == null or _label.text.is_empty():
		return
	var board := Rect2(_label.position - Vector2(5, 3), _label.size + Vector2(10, 8))
	# Two legs down to the fence.
	draw_rect(Rect2(board.position.x + 4.0, board.end.y, 2, 6), INK)
	draw_rect(Rect2(board.end.x - 6.0, board.end.y, 2, 6), INK)
	draw_rect(Rect2(board.position + Vector2(1, 2), board.size), Color(0, 0, 0, 0.3))
	draw_rect(board, INK)
	draw_rect(board.grow(-1.0), Color8(34, 30, 44))
	# Chevron trim along the top, then the progress bar along the bottom.
	var x := board.position.x + 1.0
	var n := 0
	while x < board.end.x - 1.0:
		draw_rect(Rect2(x, board.position.y + 1.0, minf(3.0, board.end.x - 1.0 - x), 1.0),
			SAFETY if n % 2 == 0 else Color8(52, 46, 54))
		x += 3.0
		n += 1
	var bar := Rect2(board.position.x + 3.0, board.end.y - 4.0, board.size.x - 6.0, 2.0)
	draw_rect(bar, Color8(60, 54, 70))
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * _progress()), bar.size.y)),
		Color8(120, 210, 110))
