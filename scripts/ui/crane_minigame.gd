class_name CraneMinigame
extends MinigameBoard
## The charter, played by hand: a trolley running the well and one tap to let go.
##
## `StackGame` owns every rule; this draws it and makes it feel like something.
## The intent is the surprise stage in an old platformer — loud, fast, over in
## under a minute, and either euphoric or your own fault.
##
## Two things a playtest asked for, and they turn out to be the same thing. The
## boxes are containers now, at nearly three times the size, because a 34px brick
## in a 220px well was not the cargo this game is about. And the tower *leans*:
## `StackGame` tracks a centre of mass and this rotates the whole stack about its
## base by it, so a run of small errors visibly tips the tower several drops
## before it goes over. A gauge on the floor reads the same number as a length,
## because the thing the player is fighting has to be on screen.

## Container art is 24x13. Scaled so a box is `StackGame.BOX_WIDTH` across, which
## is what makes it read as freight rather than as a counter.
const BOX_SCALE := StackGame.BOX_WIDTH / 24.0
const BOX_H := 13.0 * BOX_SCALE
## Height of the drawn well. Taller towers scroll rather than run off the top.
const WELL_H := 250.0
const DROP_SPEED := 700.0
## The tower's worst tilt, in degrees, at the moment it goes over.
const MAX_TILT := 13.0
## The band at the foot of the well that belongs to the balance gauge.
const GAUGE_BAND := 26.0

var game: StackGame
var _field: Control
var _decor: Control
var _gauge: Control
var _pivot: Node2D
var _tower: Node2D
var _trolley: Node2D
var _carried: Sprite2D
var _falling: Sprite2D
var _falling_to := 0.0
var _tap: Button
var _colour := 0
var _tilt := 0.0
var _dust: Array[Dictionary] = []


func _build_field(column: VBoxContainer) -> void:
	# The well itself: a recessed panel with the tower drawn inside it.
	var well := UiTheme.panel(UiTheme.slate_style(false, 2), false)
	well.custom_minimum_size.y = WELL_H
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(well)
	_field = Control.new()
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	well.add_child(_field)

	# The room, painted rather than stacked out of nodes: quay walls, the crane
	# rail and the hazard-striped floor, in one draw call that always matches the
	# field's real size.
	_decor = Control.new()
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_decor.draw.connect(_draw_well)
	_field.add_child(_decor)

	# The tower hangs off a pivot on the floor, so leaning it is a rotation about
	# the base — which is how a stack of boxes actually goes over.
	_pivot = Node2D.new()
	_field.add_child(_pivot)
	_tower = Node2D.new()
	_pivot.add_child(_tower)

	# The gauge draws *after* the tower. It reads the load on the floor, where the
	# bottom container stands, so behind the tower it is simply not there — which
	# is exactly what the first version of it was.
	_gauge = Control.new()
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gauge.draw.connect(_draw_gauge)
	_field.add_child(_gauge)

	# The trolley: a bogie on the rail, two hoist wires, and the spreader frame
	# the container hangs in. Plain rectangles because the whole thing is nine of
	# them, and a sprite would be one more file to keep in step.
	_trolley = Node2D.new()
	_field.add_child(_trolley)
	var half := StackGame.BOX_WIDTH * 0.5
	for piece in [
			# bogie box on the rail, then its two wheels
			[Vector2(-15.0, -22.0), Vector2(30.0, 11.0), Color(0.58, 0.28, 0.24)],
			[Vector2(-13.0, -24.0), Vector2(7.0, 3.0), UiTheme.STEEL_TEXT],
			[Vector2(6.0, -24.0), Vector2(7.0, 3.0), UiTheme.STEEL_TEXT],
			# hoist wires down to the spreader
			[Vector2(-half + 5.0, -11.0), Vector2(1.0, 11.0), UiTheme.STEEL_DIM],
			[Vector2(half - 6.0, -11.0), Vector2(1.0, 11.0), UiTheme.STEEL_DIM],
			# the spreader beam and its two twistlock heads
			[Vector2(-half, -2.0), Vector2(half * 2.0, 5.0), UiTheme.AMBER],
			[Vector2(-half + 1.0, -1.0), Vector2(half * 2.0 - 2.0, 2.0),
				UiTheme.CREAM],
			[Vector2(-half + 2.0, 3.0), Vector2(5.0, 4.0), UiTheme.AMBER_DEEP],
			[Vector2(half - 7.0, 3.0), Vector2(5.0, 4.0), UiTheme.AMBER_DEEP]]:
		var part := ColorRect.new()
		part.position = piece[0]
		part.size = piece[1]
		part.color = piece[2]
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_trolley.add_child(part)

	_carried = _box_sprite(0)
	# Hung *under* the spreader, the way a box on twistlocks actually is.
	_carried.position.y = BOX_H * 0.5 + 5.0
	_trolley.add_child(_carried)


func _build_controls(column: VBoxContainer) -> void:
	_tap = UiTheme.button("SOLTAR", &"amber", UiTheme.SIZE_BODY)
	_tap.custom_minimum_size.y = UiTheme.TOUCH_MIN + 6.0
	_tap.pressed.connect(_on_drop)
	column.add_child(_tap)


func _begin(offer: Dictionary) -> void:
	game = StackGame.new()
	game.setup(offer)
	_colour = 0
	_tilt = 0.0
	_dust.clear()
	if _falling != null and is_instance_valid(_falling):
		_falling.queue_free()
	_falling = null
	_carried.visible = true
	_tap.disabled = false
	_hint.text = "A pilha pende pra onde você errar."
	_rebuild_tower()
	_refresh_stats()
	_tap.grab_focus()


func _tick(delta: float) -> void:
	if game == null:
		return
	_advance_dust(delta)
	# The lean eases toward the real one rather than snapping, so a box landing
	# off-centre visibly *pushes* the tower over instead of teleporting it.
	_tilt = lerpf(_tilt, game.lean(), minf(1.0, delta * 5.0))
	_pivot.rotation_degrees = _tilt * MAX_TILT
	_decor.queue_redraw()
	_gauge.queue_redraw()
	if _falling != null:
		_advance_fall(delta)
		return
	game.advance(delta)
	_refresh_stats()
	if game.over:
		return
	_trolley.position = Vector2(_centre_x() + game.trolley_x, 20.0)


func _over() -> bool:
	# A landing box has to finish falling before the result is called, or the last
	# container of a winning run is never seen to arrive.
	return game != null and game.over and _falling == null


func _won() -> bool:
	return game != null and game.victory


func _summary() -> Dictionary:
	return game.summary() if game != null else {}


func _closing_hint() -> String:
	if game == null:
		return ""
	if game.toppled:
		return "A pilha tombou com %d contêineres" % game.placed
	return "%d de %d contêineres" % [game.placed, game.goal]


func _on_scrim_input(event: InputEvent) -> void:
	## The whole screen is the button: a minigame that demands you find a 44-pixel
	## key is a minigame you lose to the interface.
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		_on_drop()
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_on_drop()


func _on_drop() -> void:
	if game == null or _closing or _falling != null or game.over:
		return
	var outcome := game.drop()
	var landed := float(outcome.get("landed_x", game.trolley_x))
	var result := StringName(outcome.get("result", &""))
	_falling = _box_sprite(_colour)
	_falling.position = Vector2(_centre_x() + landed, 20.0)
	_field.add_child(_falling)
	var slipped := result == StackGame.RESULT_SLIP
	_falling_to = _row_y(game.height() - 1) if not slipped else _field_h() + 60.0
	if slipped:
		# It went over the side rather than onto the tower, so it tumbles.
		_falling.rotation_degrees = signf(float(outcome.get("offset", 1.0))) * 8.0
	_carried.visible = false
	match result:
		StackGame.RESULT_SLIP:
			_shake = 1.0
			_say("ESCORREGOU!", UiTheme.DANGER)
			AudioManager.play_sfx("deny", 0.06)
		StackGame.RESULT_TOPPLE:
			_shake = 1.4
			_say("TOMBOU!", UiTheme.DANGER)
			AudioManager.play_sfx("deny", 0.06)
		_:
			_colour = (_colour + 1) % 8
			if result == StackGame.RESULT_PERFECT:
				_say("PERFEITO! x%d" % int(outcome.get("combo", 1)),
					UiTheme.TEAL_LIGHT)
			# A rising scale as the tower grows: the pitch is the score.
			AudioManager.play_sfx_pitched("thunk",
				1.0 + float(game.placed) * 0.07
					+ (0.12 if result == StackGame.RESULT_PERFECT else 0.0), -2.0)
	_refresh_stats()


func _advance_fall(delta: float) -> void:
	_falling.position.y += DROP_SPEED * delta
	if _falling.position.y < _falling_to:
		return
	var went_over_the_side := _falling.position.y >= _field_h() + 30.0
	var landing := _falling.position
	_falling.queue_free()
	_falling = null
	_carried.visible = true
	if not went_over_the_side:
		_shake = maxf(_shake, 0.55)
		_puff(landing)
	_rebuild_tower()
	_refresh_stats()


func _puff(at: Vector2) -> void:
	## Dust under a landing box. Cheap, and it is the difference between a box
	## that stopped and a box that *hit* something.
	if not UserPreferences.can_animate():
		return
	for i in 5:
		_dust.append({
			"pos": at + Vector2(randf_range(-22.0, 22.0), 8.0),
			"vel": Vector2(randf_range(-34.0, 34.0), randf_range(-26.0, -8.0)),
			"life": randf_range(0.28, 0.46),
		})


func _advance_dust(delta: float) -> void:
	for mote: Dictionary in _dust:
		mote["life"] = float(mote["life"]) - delta
		mote["pos"] = Vector2(mote["pos"]) + Vector2(mote["vel"]) * delta
		mote["vel"] = Vector2(mote["vel"]) * (1.0 - minf(1.0, delta * 3.0))
	_dust = _dust.filter(func(mote: Dictionary) -> bool:
		return float(mote["life"]) > 0.0)


func _rebuild_tower() -> void:
	for child in _tower.get_children():
		child.queue_free()
	if game == null:
		return
	# Drawn bottom up, and scrolled down once the tower is taller than the well so
	# the live row is always the one you can see. The pivot sits on the floor at
	# the base box's centre, so the whole thing leans about the right point.
	var rows := game.stack.size()
	var overflow := maxf(0.0, float(rows) * BOX_H - (_floor_y() - 56.0))
	_pivot.position = Vector2(_centre_x() + game.stack[0],
		_row_y(0) + overflow + BOX_H * 0.5)
	for row in rows:
		var box := _box_sprite(row % 8)
		box.position = Vector2(_centre_x() + game.stack[row],
			_row_y(row) + overflow) - _pivot.position
		_tower.add_child(box)


func _field_h() -> float:
	## The well stretches to fill the board, so the floor is wherever the panel
	## actually ends — not the minimum height it was declared with. Using the
	## constant left the tower floating in mid-air on a tall screen.
	return _field.size.y if _field != null and _field.size.y > 0.0 else WELL_H


func _floor_y() -> float:
	## Where the boxes stand. The band below it belongs to the gauge.
	return _field_h() - GAUGE_BAND


func _row_y(row: int) -> float:
	return _floor_y() - BOX_H * 0.5 - float(row) * BOX_H


func _centre_x() -> float:
	return _field.size.x * 0.5 if _field != null and _field.size.x > 0.0 \
		else StackGame.WELL_WIDTH * 0.5


func _box_sprite(colour: int) -> Sprite2D:
	var box := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = PortDB.tex("container_sheet")
	atlas.region = Rect2(posmod(colour, 8) * 24, 0, 24, 13)
	box.texture = atlas
	box.centered = true
	box.scale = Vector2(BOX_SCALE, BOX_SCALE)
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return box


# ---------------------------------------------------------------------- view

func _draw_well() -> void:
	## The room the game is played in: quay walls, the crane rail, and a striped
	## floor slab for the tower to stand on.
	if _decor == null or game == null:
		return
	var w := _decor.size.x
	var h := _decor.size.y
	if w <= 0.0 or h <= 0.0:
		return

	# Back wall, lit from the top like every other surface in the game.
	_decor.draw_rect(Rect2(0.0, 0.0, w, h), Color(0.10, 0.11, 0.16))
	_decor.draw_rect(Rect2(0.0, 0.0, w, 30.0), Color(0.13, 0.15, 0.21))

	# The quay walls either side of the well, so the field has edges to fail off.
	var margin := maxf(0.0, (w - StackGame.WELL_WIDTH) * 0.5 - 6.0)
	if margin > 2.0:
		_decor.draw_rect(Rect2(0.0, 0.0, margin, h), Color(0.17, 0.16, 0.19))
		_decor.draw_rect(Rect2(w - margin, 0.0, margin, h), Color(0.17, 0.16, 0.19))
		_decor.draw_rect(Rect2(margin - 2.0, 0.0, 2.0, h), Color(0.26, 0.25, 0.28))
		_decor.draw_rect(Rect2(w - margin, 0.0, 2.0, h), Color(0.26, 0.25, 0.28))

	# The rail the trolley runs on: a web, a lit top flange, and its sleepers.
	_decor.draw_rect(Rect2(0.0, 6.0, w, 5.0), Color(0.26, 0.26, 0.31))
	_decor.draw_rect(Rect2(0.0, 6.0, w, 1.0), Color(0.52, 0.52, 0.60))
	_decor.draw_rect(Rect2(0.0, 11.0, w, 1.0), Color(0.13, 0.13, 0.17))
	for x in range(6, int(w), 22):
		_decor.draw_rect(Rect2(x, 4.0, 3.0, 8.0), Color(0.34, 0.34, 0.40))

	# The floor slab, with hazard stripes: the one place a diagonal is allowed.
	var floor_y := _floor_y()
	_decor.draw_rect(Rect2(0.0, floor_y, w, h - floor_y), Color(0.19, 0.18, 0.21))
	for x in range(-16, int(w) + 16, 16):
		_decor.draw_colored_polygon(PackedVector2Array([
			Vector2(x, h), Vector2(x + 8.0, h),
			Vector2(x + 8.0 + GAUGE_BAND, floor_y),
			Vector2(x + GAUGE_BAND, floor_y)]),
			Color(0.60, 0.46, 0.16, 0.30))
	_decor.draw_line(Vector2(0.0, floor_y), Vector2(w, floor_y),
		UiTheme.AMBER_DEEP, 2.0)

	for mote: Dictionary in _dust:
		var life := float(mote["life"])
		_decor.draw_circle(Vector2(mote["pos"]), 1.0 + life * 3.0,
			Color(0.78, 0.74, 0.66, life * 1.6))


func _draw_gauge() -> void:
	## How far off centre the load is, and how much room is left, as a length.
	##
	## This was a plumb line first — a hairline wire with a 3px bob on it, drawn
	## behind the tower. At a glance it was invisible, which is the one thing a
	## game's own mechanic cannot be.
	if _gauge == null or game == null or _gauge.size.x <= 0.0:
		return
	var reach := StackGame.BOX_WIDTH * 0.5 * StackGame.TOPPLE_AT
	var base_x := _centre_x() + game.stack[0]
	var y := _floor_y() + 14.0
	var danger := absf(game.lean())
	var lit := UiTheme.TEAL_LIGHT.lerp(UiTheme.DANGER, danger * danger)

	_gauge.draw_rect(Rect2(base_x - reach - 3.0, y - 5.0,
		reach * 2.0 + 6.0, 12.0), Color(0.05, 0.06, 0.09))
	_gauge.draw_rect(Rect2(base_x - reach, y - 3.0, reach * 2.0, 8.0),
		Color(0.18, 0.20, 0.25))
	# The red end of the track: past that, one more bad drop finishes it.
	for side: float in [-1.0, 1.0]:
		var from_x := base_x + side * reach
		_gauge.draw_rect(Rect2(minf(from_x, from_x - reach * 0.34), y - 3.0,
			reach * 0.34, 8.0), Color(UiTheme.DANGER, 0.5))
	_gauge.draw_line(Vector2(base_x, y - 5.0), Vector2(base_x, y + 7.0),
		Color(UiTheme.CREAM, 0.6), 1.0)
	# The slider, and a wire up into the tower so the two are obviously the same
	# number seen twice.
	var mark_x := base_x + game.lean() * reach
	_gauge.draw_line(Vector2(mark_x, _floor_y() - 6.0), Vector2(mark_x, y),
		Color(lit, 0.5), 1.0)
	_gauge.draw_rect(Rect2(mark_x - 3.0, y - 6.0, 6.0, 14.0), Color(0, 0, 0, 0.75))
	_gauge.draw_rect(Rect2(mark_x - 2.0, y - 5.0, 4.0, 12.0), lit)


func _refresh_stats() -> void:
	if game == null:
		return
	# The third stat used to be lives. There are none: the tower is the health
	# bar, so it reads how far off plumb it is instead.
	_set_stats("%4.1fs" % game.time_left, "%d/%d" % [game.placed, game.goal],
		"prumo %d%%" % roundi((1.0 - absf(game.lean())) * 100.0))
