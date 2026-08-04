class_name MazeMinigame
extends MinigameBoard
## The second charter game: a yard you have to find your way out of.
##
## Different verb from the stacker on purpose. That one is timing — one button,
## one moment. This is navigation: read the walls, decide the route, and the
## clock is spent on being wrong rather than on being slow.

const CONTAINERS := preload("res://assets/sprites/container_sheet.png")
const WALL_WIDTH := 2.0

var game: MazeGame
var _grid: Control
var _pad: GridContainer
var _keys: Dictionary = {}       # direction -> Button
var _arrows: Dictionary = {}     # direction -> the rotated chevron on it
var _tractor := Vector2.ZERO     # drawn position, in cells, eased toward `at`


func _build_field(column: VBoxContainer) -> void:
	var well := UiTheme.panel(UiTheme.slate_style(false, 2), false)
	well.custom_minimum_size.y = 190.0
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(well)
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.draw.connect(_draw_maze)
	well.add_child(_grid)


func _build_controls(column: VBoxContainer) -> void:
	## A four-key pad, because a swipe on a nine-cell maze is a guess. Every key is
	## a full touch target and the arrows/WASD do the same thing.
	_pad = GridContainer.new()
	_pad.columns = 3
	_pad.add_theme_constant_override(&"h_separation", 4)
	_pad.add_theme_constant_override(&"v_separation", 4)
	column.add_child(_pad)
	var layout := [
		[0, MazeGame.NORTH, 0],
		[MazeGame.WEST, 0, MazeGame.EAST],
		[0, MazeGame.SOUTH, 0],
	]
	var names := {MazeGame.NORTH: "Subir", MazeGame.EAST: "Direita",
		MazeGame.SOUTH: "Descer", MazeGame.WEST: "Esquerda"}
	var turns := {MazeGame.NORTH: -90.0, MazeGame.EAST: 0.0,
		MazeGame.SOUTH: 90.0, MazeGame.WEST: 180.0}
	for row: Array in layout:
		for direction: int in row:
			if direction == 0:
				var blank := Control.new()
				blank.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN, UiTheme.TOUCH_MIN)
				blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_pad.add_child(blank)
				continue
			var key := UiTheme.button("", &"amber", UiTheme.SIZE_BODY)
			key.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN, UiTheme.TOUCH_MIN)
			key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UiTheme.describe(key, str(names[direction]))
			key.pressed.connect(_step.bind(direction))
			# The arrow is a rotated child, not rotated text: a Control laid out by
			# a container has its own transform managed, so `rotation` on the key
			# itself is thrown away and every arrow ends up pointing right.
			var arrow := UiTheme.icon(UiTheme.Icon.CHEVRON, 2)
			arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			arrow.pivot_offset = arrow.custom_minimum_size * 0.5
			arrow.rotation_degrees = float(turns[direction])
			arrow.modulate = UiTheme.INK
			key.add_child(arrow)
			_pad.add_child(key)
			_keys[direction] = key
			_arrows[direction] = arrow


func _begin(offer: Dictionary) -> void:
	game = MazeGame.new()
	# The charter's own slot seeds the maze, so the same charter is the same yard.
	game.setup(offer, int(offer.get("index", 0)) * 7919 + str(offer.get("id", "")).hash())
	_tractor = Vector2(game.at)
	_hint.text = "Ache os contêineres e chegue no berço."
	_refresh()


func _tick(delta: float) -> void:
	if game == null:
		return
	game.advance(delta)
	_tractor = _tractor.lerp(Vector2(game.at), minf(1.0, delta * 14.0))
	_grid.queue_redraw()
	_refresh()


func _step(direction: int) -> void:
	if game == null or _closing or game.over:
		return
	var outcome := game.move(direction)
	if not bool(outcome.get("moved", false)):
		_shake = maxf(_shake, 0.45)
		AudioManager.play_sfx("deny", 0.08, -6.0)
		return
	if bool(outcome.get("crate", false)):
		_say("ACHOU! %d/%d" % [game.collected, game.goal], UiTheme.TEAL_LIGHT)
		AudioManager.play_sfx_pitched("thunk",
			1.0 + float(game.collected) * 0.12, -2.0)
		if game.exit_open():
			_hint.text = "Tudo a bordo. Corre pro berço!"
	else:
		AudioManager.play_sfx_pitched("tap", 0.9 + float(game.moves % 4) * 0.05, -12.0)
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_UP, KEY_W:
			_step(MazeGame.NORTH)
		KEY_RIGHT, KEY_D:
			_step(MazeGame.EAST)
		KEY_DOWN, KEY_S:
			_step(MazeGame.SOUTH)
		KEY_LEFT, KEY_A:
			_step(MazeGame.WEST)
		_:
			return
	get_viewport().set_input_as_handled()


func _refresh() -> void:
	if game == null:
		return
	_set_stats("%4.1fs" % game.time_left,
		"%d/%d" % [game.collected, game.goal],
		"berço %s" % ("aberto" if game.exit_open() else "fechado"))
	for direction: int in _keys:
		var open := game.can_move(direction)
		(_keys[direction] as Button).disabled = not open
		# The glyph follows the key's own state, or a disabled key keeps an
		# ink-black arrow on a grey face and still reads as pressable.
		(_arrows[direction] as TextureRect).modulate = \
			UiTheme.INK if open else Color(0.42, 0.40, 0.38)


func _over() -> bool:
	return game != null and game.over


func _won() -> bool:
	return game != null and game.victory


func _summary() -> Dictionary:
	return game.summary() if game != null else {}


func _closing_hint() -> String:
	if game == null:
		return ""
	return "%d de %d contêineres, %d movimentos" % [game.collected, game.goal,
		game.moves]


# ---------------------------------------------------------------------- view

func _draw_maze() -> void:
	if game == null or _grid == null:
		return
	var cell := minf(_grid.size.x / float(game.width),
		_grid.size.y / float(game.height))
	var origin := (_grid.size - Vector2(cell * game.width, cell * game.height)) * 0.5
	var wall := UiTheme.SLATE_DIM
	var floor_colour := Color(0.16, 0.15, 0.20)
	_grid.draw_rect(Rect2(origin, Vector2(cell * game.width, cell * game.height)),
		floor_colour)
	for y in game.height:
		for x in game.width:
			var cell_pos := origin + Vector2(x, y) * cell
			var sides := game.sides(Vector2i(x, y))
			# Only the two leading edges are drawn per cell, plus the far border:
			# drawing all four paints every wall twice.
			if (sides & MazeGame.NORTH) == 0:
				_grid.draw_line(cell_pos, cell_pos + Vector2(cell, 0.0), wall, WALL_WIDTH)
			if (sides & MazeGame.WEST) == 0:
				_grid.draw_line(cell_pos, cell_pos + Vector2(0.0, cell), wall, WALL_WIDTH)
			if x == game.width - 1 and (sides & MazeGame.EAST) == 0:
				_grid.draw_line(cell_pos + Vector2(cell, 0.0),
					cell_pos + Vector2(cell, cell), wall, WALL_WIDTH)
			if y == game.height - 1 and (sides & MazeGame.SOUTH) == 0:
				_grid.draw_line(cell_pos + Vector2(0.0, cell),
					cell_pos + Vector2(cell, cell), wall, WALL_WIDTH)

	# The berth, shut until every box is aboard.
	var exit_pos := origin + Vector2(game.exit_cell) * cell
	_grid.draw_rect(Rect2(exit_pos + Vector2(cell, cell) * 0.18,
		Vector2(cell, cell) * 0.64),
		UiTheme.TEAL_LIGHT if game.exit_open() else UiTheme.DANGER)

	for crate: Vector2i in game.crates:
		var crate_pos := origin + Vector2(crate) * cell + Vector2(cell, cell) * 0.5
		var box := AtlasTexture.new()
		box.atlas = CONTAINERS
		box.region = Rect2(posmod(crate.x + crate.y, 8) * 24, 0, 24, 13)
		_grid.draw_texture_rect(box,
			Rect2(crate_pos - Vector2(cell, cell * 0.55) * 0.42,
				Vector2(cell * 0.84, cell * 0.46)), false)

	var truck := origin + _tractor * cell + Vector2(cell, cell) * 0.5
	_grid.draw_circle(truck, cell * 0.28, UiTheme.AMBER)
	_grid.draw_circle(truck, cell * 0.15, UiTheme.AMBER_DEEP)
