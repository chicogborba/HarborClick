class_name CraneMinigame
extends MinigameBoard
## The charter, played by hand: a trolley running the well and one tap to let go.
##
## `StackGame` owns every rule; this draws it and makes it feel like something.
## The intent is the surprise stage in an old platformer — loud, fast, over in
## under a minute, and either euphoric or your own fault.

const CONTAINERS := preload("res://assets/sprites/container_sheet.png")
## The well is drawn at this scale so a 24x13 container reads as a real box.
const BOX_SCALE := Vector2(1.42, 1.42)
const BOX_H := 13.0 * 1.42
## Height of the drawn well. Taller towers scroll rather than run off the top.
const WELL_H := 250.0
const DROP_SPEED := 620.0


var game: StackGame
var _field: Control
var _tower: Node2D
var _trolley: Node2D
var _carried: Sprite2D
var _falling: Sprite2D
var _falling_to := 0.0
var _falling_x := 0.0
var _tap: Button
var _colour := 0


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
	_tower = Node2D.new()
	_field.add_child(_tower)
	_trolley = Node2D.new()
	_field.add_child(_trolley)
	var beam := ColorRect.new()
	beam.color = UiTheme.AMBER_DEEP
	beam.size = Vector2(StackGame.BOX_WIDTH, 3.0)
	beam.position = Vector2(-StackGame.BOX_WIDTH * 0.5, -13.0)
	_trolley.add_child(beam)
	_carried = _box_sprite(0)
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
	if _falling != null and is_instance_valid(_falling):
		_falling.queue_free()
	_falling = null
	_carried.visible = true
	_tap.disabled = false
	_hint.text = "Toque para soltar o contêiner."
	_rebuild_tower()
	_refresh_stats()
	_tap.grab_focus()


func _tick(delta: float) -> void:
	if game == null:
		return
	if _falling != null:
		_advance_fall(delta)
		return
	game.advance(delta)
	_refresh_stats()
	if game.over:
		return
	_trolley.position = Vector2(_centre_x() + game.trolley_x, 16.0)


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
	_falling = _box_sprite(_colour)
	_falling.position = Vector2(_centre_x() + landed, 16.0)
	_field.add_child(_falling)
	_falling_x = landed
	var missed := StringName(outcome.get("result", &"")) == StackGame.RESULT_MISS
	_falling_to = _row_y(game.height() - 1) if not missed else _field_h() + 40.0
	_carried.visible = false
	if missed:
		_shake = 1.0
		_say("PERDEU!", UiTheme.DANGER)
		AudioManager.play_sfx("deny", 0.06)
	else:
		_colour = (_colour + 1) % 8
		var perfect := StringName(outcome.get("result", &"")) \
			== StackGame.RESULT_PERFECT
		if perfect:
			_say("PERFEITO! x%d" % int(outcome.get("combo", 1)), UiTheme.TEAL_LIGHT)
		# A rising scale as the tower grows: the pitch is the score.
		AudioManager.play_sfx_pitched("thunk",
			1.0 + float(game.placed) * 0.07 + (0.12 if perfect else 0.0), -2.0)
	_refresh_stats()


func _advance_fall(delta: float) -> void:
	_falling.position.y += DROP_SPEED * delta
	if _falling.position.y < _falling_to:
		return
	var landed_home := _falling.position.y >= _field_h() + 30.0
	_falling.queue_free()
	_falling = null
	_carried.visible = true
	if not landed_home:
		_shake = maxf(_shake, 0.55)
	_rebuild_tower()
	_refresh_stats()


func _rebuild_tower() -> void:
	for child in _tower.get_children():
		child.queue_free()
	if game == null:
		return
	# Drawn bottom up, and scrolled down once the tower is taller than the well so
	# the live row is always the one you can see.
	var rows := game.stack.size()
	var overflow := maxf(0.0, float(rows) * BOX_H - (_field_h() - 60.0))
	for row in rows:
		var box := _box_sprite(row % 8)
		box.position = Vector2(_centre_x() + game.stack[row],
			_row_y(row) + overflow)
		_tower.add_child(box)


func _field_h() -> float:
	## The well stretches to fill the board, so the floor is wherever the panel
	## actually ends — not the minimum height it was declared with. Using the
	## constant left the tower floating in mid-air on a tall screen.
	return _field.size.y if _field != null and _field.size.y > 0.0 else WELL_H


func _row_y(row: int) -> float:
	return _field_h() - 14.0 - float(row) * BOX_H


func _centre_x() -> float:
	return _field.size.x * 0.5 if _field != null and _field.size.x > 0.0 \
		else StackGame.WELL_WIDTH * 0.5


func _box_sprite(colour: int) -> Sprite2D:
	var box := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = CONTAINERS
	atlas.region = Rect2(posmod(colour, 8) * 24, 0, 24, 13)
	box.texture = atlas
	box.centered = true
	box.scale = BOX_SCALE
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return box


func _refresh_stats() -> void:
	if game == null:
		return
	_set_stats("%4.1fs" % game.time_left, "%d/%d" % [game.placed, game.goal],
		"%d vidas" % maxi(0, game.lives))
