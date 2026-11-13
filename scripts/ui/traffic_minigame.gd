class_name TrafficMinigame
extends MinigameBoard
## The late lorry, played by hand: the avenue to the port, three lanes of it,
## seen from above and scrolling under the rig.
##
## `TrafficGame` owns every rule; this draws the road at twice its size and
## turns taps, swipes and arrow keys into lane changes. The left and right
## halves of the road are the two keys — a phone held in one hand plays it
## with a thumb — and the two big arrow keys under it are there for anyone who
## wants something to press.

const SCALE := 2.0
const FIELD_H := 252.0
## Kerb and pavement either side of the carriageway, in road pixels.
const KERB := 7.0
const RIG := preload("res://assets/sprites/mg_rig.png")
const CARS := preload("res://assets/sprites/mg_cars.png")
const BUS := preload("res://assets/sprites/mg_bus.png")
const MOTO := preload("res://assets/sprites/mg_moto.png")
const ITEMS := preload("res://assets/sprites/mg_items.png")
const ROADSIDE := preload("res://assets/sprites/mg_roadside.png")
const ROOFS := preload("res://assets/sprites/mg_roofs.png")
const TILE := Color8(176, 168, 156)
const TILE_D := Color8(150, 142, 132)
const SHADOW := Color(0.08, 0.06, 0.12, 0.32)
const ASPHALT := Color8(70, 66, 76)
const ASPHALT_L := Color8(84, 80, 90)
const LINE := Color8(236, 226, 196)
const KERB_A := Color8(214, 70, 58)
const KERB_B := Color8(236, 226, 196)
const PAVEMENT := Color8(160, 150, 138)
const VERGE := Color8(96, 146, 76)

var game: TrafficGame
var _field: Control
var _left: Button
var _right: Button
## The rig's drawn lane, easing toward the real one so a change slides.
var _lane_x := 1.0
var _swipe_from := Vector2.ZERO
var _swiping := false
var _sparks: Array[Dictionary] = []
## Exhaust puffs, in screen space: {pos, life}.
var _smoke: Array[Dictionary] = []
var _puff := 0.0
var _t := 0.0


func _build_field(column: VBoxContainer) -> void:
	var well := UiTheme.panel(UiTheme.slate_style(false, 2), false)
	well.custom_minimum_size.y = FIELD_H
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(well)
	_field = Control.new()
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.draw.connect(_draw_road)
	_field.gui_input.connect(_on_field_input)
	well.add_child(_field)


func _build_controls(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	column.add_child(row)
	_left = UiTheme.button("<  ESQ", &"steel", UiTheme.SIZE_BODY)
	_right = UiTheme.button("DIR  >", &"steel", UiTheme.SIZE_BODY)
	for key: Button in [_left, _right]:
		key.custom_minimum_size.y = UiTheme.TOUCH_MIN + 4.0
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.focus_mode = Control.FOCUS_NONE
		row.add_child(key)
	_left.button_down.connect(_steer.bind(-1))
	_right.button_down.connect(_steer.bind(1))


func _begin(offer: Dictionary) -> void:
	game = TrafficGame.new()
	game.setup(offer)
	_lane_x = float(game.lane)
	_sparks.clear()
	_smoke.clear()
	_hint.text = "Toque num lado da pista (ou arraste) pra trocar de faixa. Café é turbo, relógio dá tempo."
	_refresh()


func _tick(delta: float) -> void:
	if game == null:
		return
	_t += delta
	game.advance(delta)
	for event: Dictionary in game.events:
		_on_event(event)
	_lane_x = lerpf(_lane_x, float(game.lane), minf(1.0, delta * 16.0))
	for spark: Dictionary in _sparks:
		spark.life = float(spark.life) - delta
		spark.pos = (spark.pos as Vector2) + (spark.vel as Vector2) * delta
	_puff -= delta
	if _puff <= 0.0 and UserPreferences.can_animate():
		_puff = 0.05 if game.turbo > 0.0 else 0.12
		var rig := _rig_rect()
		_smoke.append({"pos": Vector2(rig.position.x + 5.0 + randf() * 3.0, rig.end.y),
			"life": 0.6})
	var puffs: Array[Dictionary] = []
	for p: Dictionary in _smoke:
		p.life = float(p.life) - delta
		p.pos = (p.pos as Vector2) + Vector2(randf_range(-6.0, 6.0), game.current_speed() * SCALE) * delta
		if float(p.life) > 0.0:
			puffs.append(p)
	_smoke = puffs
	var alive: Array[Dictionary] = []
	for spark: Dictionary in _sparks:
		if float(spark.life) > 0.0:
			alive.append(spark)
	_sparks = alive
	_refresh()
	_field.queue_redraw()


func _on_event(event: Dictionary) -> void:
	match StringName(event.event):
		TrafficGame.HIT:
			_shake = 1.2
			_say("BATEU!", UiTheme.DANGER)
			AudioManager.play_sfx("deny", 0.06)
			_burst(Color8(255, 200, 80), 10)
		TrafficGame.SKID:
			_say("ÓLEO!", UiTheme.AMBER)
			AudioManager.play_sfx("rail_brake", 0.08, -6.0)
		TrafficGame.TURBO:
			_say("TURBO!", UiTheme.TEAL_LIGHT)
			AudioManager.play_sfx("combo", 0.05)
			_burst(Color8(150, 96, 56), 6)
		TrafficGame.BONUS:
			_say("+%ds" % int(TrafficGame.CLOCK_BONUS), UiTheme.TEAL_LIGHT)
			AudioManager.play_sfx("coins", 0.05)
			_burst(Color8(120, 190, 240), 6)


func _burst(colour: Color, count: int) -> void:
	if not UserPreferences.can_animate():
		return
	var at := _rig_rect().get_center() - Vector2(0, _rig_rect().size.y * 0.4)
	for i in count:
		var a := randf() * TAU
		_sparks.append({"pos": at, "vel": Vector2.from_angle(a) * randf_range(40.0, 110.0),
			"life": randf_range(0.25, 0.5), "colour": colour})


func _refresh() -> void:
	if game == null:
		return
	var metres := maxi(0, int((game.distance_goal - game.travelled) * 0.5))
	_set_stats("%4.1fs" % game.time_left, "%dm" % metres, "vidas %d" % game.lives)


func _over() -> bool:
	return game != null and game.over


func _won() -> bool:
	return game != null and game.victory


func _summary() -> Dictionary:
	return game.summary() if game != null else {}


func _closing_hint() -> String:
	if game == null:
		return ""
	if game.victory:
		return "Chegou com %.1fs de folga." % game.time_left
	if game.lives <= 0:
		return "Três batidas: a carga ficou no caminho."
	return "O portão fechou a %dm do porto." % int((game.distance_goal - game.travelled) * 0.5)


func _result_text(won: bool) -> String:
	return "CHEGOU!" if won else "ATRASOU"


# ------------------------------------------------------------------ input

func _steer(direction: int) -> void:
	if game == null or _closing:
		return
	if game.steer(direction):
		AudioManager.play_sfx("tap", 0.1, -8.0)


func _on_field_input(event: InputEvent) -> void:
	var at := Vector2.ZERO
	var pressed := false
	var released := false
	var touch := event as InputEventScreenTouch
	var click := event as InputEventMouseButton
	if touch != null:
		at = touch.position
		pressed = touch.pressed
		released = not touch.pressed
	elif click != null and click.button_index == MOUSE_BUTTON_LEFT:
		at = click.position
		pressed = click.pressed
		released = not click.pressed
	else:
		return
	if pressed:
		_swipe_from = at
		_swiping = true
	elif released and _swiping:
		_swiping = false
		var dx := at.x - _swipe_from.x
		if absf(dx) > 18.0:
			_steer(signi(int(dx)))
		else:
			# A tap: the half of the road it landed on.
			_steer(-1 if at.x < _rig_rect().get_center().x else 1)
	_field.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or game == null:
		return
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"pan_left"):
		_steer(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"pan_right"):
		_steer(1)
		get_viewport().set_input_as_handled()


# ----------------------------------------------------------------- drawing

func _road_left() -> float:
	## Screen x of the carriageway's west edge, centred in the field.
	var road_w := TrafficGame.LANES * TrafficGame.LANE_W * SCALE
	return roundf((_field.size.x - road_w) * 0.5)


func _lane_centre(lane: float) -> float:
	return _road_left() + (lane + 0.5) * TrafficGame.LANE_W * SCALE


func _nose_y() -> float:
	return _field.size.y - 14.0 - TrafficGame.RIG_LEN * SCALE


func _rig_rect() -> Rect2:
	var w := float(RIG.get_width())
	var h := float(RIG.get_height())
	return Rect2(roundf(_lane_centre(_lane_x) - w * 0.5), _nose_y() - 2.0, w, h)


func _sprite(tex: Texture2D, frames: int, index: int, centre_x: float, top: float) -> void:
	var w := float(tex.get_width()) / float(frames)
	var h := float(tex.get_height())
	## Road sprites are drawn at the size they are shown: no scaling.
	var dest := Rect2(roundf(centre_x - w * 0.5), roundf(top), w, h)
	_field.draw_texture_rect_region(tex, dest, Rect2(index * w, 0, w, h))


func _vehicle(tex: Texture2D, frames: int, index: int, centre_x: float, top: float) -> void:
	var w := float(tex.get_width()) / float(frames)
	var h := float(tex.get_height())
	_field.draw_rect(Rect2(roundf(centre_x - w * 0.5) + 3.0, roundf(top) + 5.0, w - 2.0, h - 2.0),
		SHADOW)
	_sprite(tex, frames, index, centre_x, top)


func _draw_road() -> void:
	if game == null:
		return
	var size := _field.size
	var left := _road_left()
	var road_w := TrafficGame.LANES * TrafficGame.LANE_W * SCALE
	var right := left + road_w
	var roll := game.travelled * SCALE
	var kerb := 6.0
	var walk := 22.0
	# --- the blocks either side: rooftops, then the pavement in front ----
	_field.draw_rect(Rect2(Vector2.ZERO, size), Color8(88, 84, 92))
	var block_h := 80.0
	var block_roll := fmod(roll, block_h)
	var west_edge := left - kerb - walk
	var east_edge := right + kerb + walk
	var b := -1
	while -block_h + block_roll + b * block_h < size.y:
		var by := -block_h + block_roll + b * block_h
		var index := int(floorf(roll / block_h)) - b
		_field.draw_texture_rect_region(ROOFS, Rect2(west_edge - 56.0, by + 4.0, 56, 72),
			Rect2(posmod(index, 3) * 56, 0, 56, 72))
		_field.draw_texture_rect_region(ROOFS, Rect2(east_edge, by + 4.0, 56, 72),
			Rect2(posmod(index + 1, 3) * 56, 0, 56, 72))
		b += 1
	# pavement: square slabs that scroll with the road
	for side in 2:
		var x0 := west_edge if side == 0 else right + kerb
		_field.draw_rect(Rect2(x0, 0, walk, size.y), TILE)
		var ty := fmod(roll, 11.0) - 11.0
		while ty < size.y:
			_field.draw_rect(Rect2(x0, ty, walk, 1), TILE_D)
			ty += 11.0
		_field.draw_rect(Rect2(x0 + walk * 0.5, 0, 1, size.y), TILE_D)
	# kerbs, red and white
	var ky := fmod(roll, 24.0) - 24.0
	var n := 0
	while ky < size.y:
		var c := KERB_A if n % 2 == 0 else KERB_B
		_field.draw_rect(Rect2(left - kerb, ky, kerb, 12.0), c)
		_field.draw_rect(Rect2(right, ky, kerb, 12.0), c)
		ky += 12.0
		n += 1
	# --- the carriageway ------------------------------------------------------
	_field.draw_rect(Rect2(left, 0, road_w, size.y), ASPHALT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 90:
		var py := fmod(rng.randf() * 900.0 + roll, size.y + 20.0) - 10.0
		_field.draw_rect(Rect2(left + roundf(rng.randf() * road_w), roundf(py), 1, 1),
			ASPHALT_L if i % 3 else Color8(58, 54, 64))
	# tyre tracks worn into each lane
	for lane in TrafficGame.LANES:
		var lx := _lane_centre(float(lane))
		_field.draw_rect(Rect2(lx - 9.0, 0, 3, size.y), Color(0, 0, 0, 0.08))
		_field.draw_rect(Rect2(lx + 6.0, 0, 3, size.y), Color(0, 0, 0, 0.08))
	# edge lines and lane dashes
	_field.draw_rect(Rect2(left + 3.0, 0, 2, size.y), LINE)
	_field.draw_rect(Rect2(right - 5.0, 0, 2, size.y), LINE)
	for lane in range(1, TrafficGame.LANES):
		var x := left + lane * TrafficGame.LANE_W * SCALE - 1.0
		var dy := fmod(roll, 44.0) - 44.0
		while dy < size.y:
			_field.draw_rect(Rect2(x, dy, 2, 22), LINE)
			dy += 44.0
	# street furniture that rolls past: a crossing, manholes, arrows
	var cross_y := fmod(roll, 520.0) - 120.0
	if cross_y > -40.0 and cross_y < size.y:
		var sx := left + 6.0
		while sx < right - 10.0:
			_field.draw_rect(Rect2(sx, cross_y, 7, 26), Color(LINE, 0.9))
			sx += 12.0
	for k in 2:
		var my := fmod(roll + k * 260.0, 520.0) - 60.0
		var mx := _lane_centre(float(k * 2)) + (8.0 if k == 0 else -8.0)
		_field.draw_circle(Vector2(mx, my), 6.0, Color8(52, 48, 58))
		_field.draw_circle(Vector2(mx, my), 5.0, Color8(96, 92, 102))
		for g in range(-3, 4, 2):
			_field.draw_rect(Rect2(mx - 4.0, my + g, 8, 1), Color8(60, 56, 66))
	var ay := fmod(roll + 180.0, 520.0) - 60.0
	var ax := _lane_centre(1.0)
	_field.draw_rect(Rect2(ax - 1.0, ay, 3, 14), Color(LINE, 0.7))
	_field.draw_colored_polygon(PackedVector2Array([Vector2(ax - 6.0, ay + 1.0),
		Vector2(ax + 7.0, ay + 1.0), Vector2(ax + 0.5, ay - 7.0)]), Color(LINE, 0.7))
	# trees, lamps and kiosks on the pavement
	var side_roll := fmod(roll, 120.0)
	for i in range(-1, int(size.y / 60.0) + 2):
		var sy := -60.0 + side_roll + i * 60.0
		var k := posmod(int(floorf(roll / 60.0)) - i, 4)
		_sprite(ROADSIDE, 4, [0, 1, 0, 3][k], west_edge + 6.0, sy)
		_sprite(ROADSIDE, 4, [1, 0, 2, 0][k], east_edge - 6.0, sy + 30.0)
	# the port gate when it is in sight: a striped barrier and its booth
	var gate_ahead := game.distance_goal - game.travelled
	if gate_ahead < 160.0:
		var gy := _nose_y() - gate_ahead * SCALE
		_field.draw_rect(Rect2(left - kerb - walk, gy - 26.0, road_w + 2.0 * (kerb + walk), 30),
			Color(0, 0, 0, 0.18))
		for gx in range(0, int(road_w), 12):
			_field.draw_rect(Rect2(left + gx, gy - 6.0, 12, 6),
				KERB_A if posmod(gx, 24) < 12 else KERB_B)
		_field.draw_rect(Rect2(right + 2.0, gy - 22.0, 18, 18), Color8(64, 156, 160))
		_field.draw_rect(Rect2(right + 4.0, gy - 20.0, 14, 6), Color8(146, 194, 208))
		_field.draw_string(UiTheme.FONT, Vector2(left + road_w * 0.5 - 22.0, gy - 12.0),
			"PORTO", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL, LINE)
	# --- traffic and things in the road ---------------------------------------
	for thing: Dictionary in game.things:
		var kind: StringName = thing.kind
		var length: float = TrafficGame.KINDS[kind].len
		var top := _nose_y() - (float(thing.y) + length) * SCALE
		if top > size.y or top + length * SCALE < -90.0:
			continue
		var cx := _lane_centre(float(thing.lane))
		match kind:
			TrafficGame.CAR:
				_vehicle(CARS, 4, int(thing.id) % 4, cx, top)
			TrafficGame.BUS:
				_vehicle(BUS, 1, 0, cx, top)
			TrafficGame.MOTO:
				_vehicle(MOTO, 1, 0, cx + (6.0 if int(thing.id) % 2 else -6.0), top)
			TrafficGame.CONE:
				_sprite(ITEMS, 5, 0, cx - 12.0, top - 4.0)
				_sprite(ITEMS, 5, 0, cx + 12.0, top + 4.0)
				_field.draw_rect(Rect2(cx - 12.0, top + 8.0, 24, 3), Color8(244, 132, 40))
			TrafficGame.HOLE:
				_sprite(ITEMS, 5, 1, cx, top)
			TrafficGame.OIL:
				_sprite(ITEMS, 5, 2, cx, top)
			TrafficGame.COFFEE, TrafficGame.CLOCK:
				var bob := roundf(sin(_t * 6.0 + float(thing.id)) * 2.0)
				var glow := Color8(255, 220, 140) if kind == TrafficGame.COFFEE else Color8(140, 200, 255)
				_field.draw_circle(Vector2(cx, top + 12.0), 16.0,
					Color(glow, 0.22 + 0.12 * sin(_t * 8.0)))
				_field.draw_circle(Vector2(cx, top + 12.0), 11.0, Color(glow, 0.25))
				_sprite(ITEMS, 5, 3 if kind == TrafficGame.COFFEE else 4, cx, top + bob)
	# --- the rig ---------------------------------------------------------------
	for p: Dictionary in _smoke:
		var a := clampf(float(p.life) / 0.6, 0.0, 1.0)
		var r := 3.0 + (1.0 - a) * 5.0
		_field.draw_circle((p.pos as Vector2).round(), r, Color(0.85, 0.85, 0.9, 0.35 * a))
	var rig := _rig_rect()
	var blink := game.grace > 0.0 and int(_t * 12.0) % 2 == 0
	# Lean into a lane change: the drawn lane lags the real one, and the gap
	# is how far the cab is turned.
	var lean := clampf((float(game.lane) - _lane_x) * 0.35, -0.3, 0.3)
	if not blink:
		var pivot := rig.get_center()
		_field.draw_set_transform(pivot + Vector2(4, 6), lean, Vector2.ONE)
		_field.draw_rect(Rect2(-rig.size * 0.5, rig.size), SHADOW)
		_field.draw_set_transform(pivot, lean, Vector2.ONE)
		_field.draw_texture(RIG, -rig.size * 0.5)
		_field.draw_set_transform_matrix(Transform2D.IDENTITY)
	if game.turbo > 0.0:
		var flame := 10.0 + roundf(sin(_t * 40.0) * 3.0)
		_field.draw_rect(Rect2(rig.get_center().x - 7.0, rig.end.y, 5, flame), Color8(255, 150, 50))
		_field.draw_rect(Rect2(rig.get_center().x + 2.0, rig.end.y, 5, flame - 2.0), Color8(255, 150, 50))
		_field.draw_rect(Rect2(rig.get_center().x - 6.0, rig.end.y, 3, flame - 4.0), Color8(255, 236, 170))
		_field.draw_rect(Rect2(rig.get_center().x + 3.0, rig.end.y, 3, flame - 6.0), Color8(255, 236, 170))
		for i in 5:
			var ly := fmod(_t * 520.0 + i * 61.0, size.y)
			_field.draw_rect(Rect2(left + 10.0 + i * 27.0, ly, 1, 28), Color(1, 1, 1, 0.4))
	for spark: Dictionary in _sparks:
		_field.draw_rect(Rect2((spark.pos as Vector2).round(), Vector2(3, 3)), spark.colour)
	# --- the strip across the top: how far to the port --------------------------
	var bar := Rect2(14.0, 9.0, size.x - 28.0, 6.0)
	_field.draw_rect(bar.grow(3.0), Color8(24, 20, 30))
	_field.draw_rect(bar, Color8(60, 54, 70))
	_field.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * game.progress()), bar.size.y)),
		Color8(120, 210, 110))
	var marker := roundf(bar.position.x + bar.size.x * game.progress())
	_field.draw_texture_rect(RIG, Rect2(marker - 4.0, bar.position.y - 7.0, 7, 16), false)
	_field.draw_rect(Rect2(bar.end.x - 2.0, bar.position.y - 6.0, 2, 18), LINE)
	_field.draw_rect(Rect2(bar.end.x, bar.position.y - 6.0, 8, 6), Color8(64, 156, 160))
