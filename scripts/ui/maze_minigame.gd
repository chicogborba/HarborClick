class_name MazeMinigame
extends MinigameBoard
## The second charter game: a yard you have to find your way out of.
##
## Different verb from the stacker on purpose. That one is timing — one button,
## one moment. This is navigation: read the walls, decide the route, and the
## clock is spent on being wrong rather than on being slow.
##
## It is played on a **cabinet**. The first version was a maze drawn on a slate
## panel with a three-by-three grid of chevron keys under it, which is a diagram
## with a d-pad, and a playtest said as much. A yard maze under glass with a ball
## stick under it is the same rules wearing the right clothes — and the stick is
## not decoration: the whole control is one lever you push, which is what an
## arcade cabinet actually gives you and what four separate keys never did.

const CONTAINERS := preload("res://assets/sprites/container_sheet.png")
const WALL_WIDTH := 2.0
## The stick's throw, in pixels, and how far a press has to be from the centre
## before it counts as a direction rather than a nudge.
const STICK_THROW := 12.0
const STICK_DEADZONE := 6.0
## How long a held direction waits before it repeats, and how fast after that.
const REPEAT_DELAY := 0.34
const REPEAT_RATE := 0.13

var game: MazeGame
var _screen: Control
var _deck: Control
var _tractor := Vector2.ZERO     # drawn position, in cells, eased toward `at`
## Where the stick is, from -1 to 1 on each axis, and where it is being pushed.
var _stick := Vector2.ZERO
var _push := Vector2.ZERO
var _held := 0
var _repeat := 0.0
## Which of the two buttons is lit, and for how long. They flash on a move and on
## a refusal, so the deck answers every press even when the yard does not.
var _lamp := [0.0, 0.0]


func _build_field(column: VBoxContainer) -> void:
	## The cabinet: a moulded bezel with the glass recessed into it.
	var cabinet := UiTheme.panel(UiTheme.arcade_style(9), false)
	cabinet.custom_minimum_size.y = 196.0
	cabinet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(cabinet)
	_screen = Control.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen.draw.connect(_draw_screen)
	cabinet.add_child(_screen)


func _build_controls(column: VBoxContainer) -> void:
	## The control deck: one ball stick and two buttons, on the same plastic.
	##
	## The stick is a single focusable control rather than four keys, because
	## that is what it is. Arrows and WASD drive it too, so nothing here is only
	## reachable by pointing at it.
	var deck := UiTheme.panel(UiTheme.arcade_style(8), false)
	deck.custom_minimum_size.y = 92.0
	column.add_child(deck)
	_deck = Control.new()
	_deck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_deck.custom_minimum_size.y = 78.0
	_deck.mouse_filter = Control.MOUSE_FILTER_STOP
	_deck.focus_mode = Control.FOCUS_ALL
	_deck.add_theme_stylebox_override(&"focus", UiTheme.focus_ring())
	UiTheme.describe(_deck, "Manche",
		"Empurre para andar. As setas e WASD fazem o mesmo.")
	_deck.gui_input.connect(_on_deck_input)
	_deck.draw.connect(_draw_deck)
	deck.add_child(_deck)


func _begin(offer: Dictionary) -> void:
	game = MazeGame.new()
	# The charter's own slot seeds the maze, so the same charter is the same yard.
	game.setup(offer, int(offer.get("index", 0)) * 7919 + str(offer.get("id", "")).hash())
	_tractor = Vector2(game.at)
	_stick = Vector2.ZERO
	_push = Vector2.ZERO
	_held = 0
	_lamp = [0.0, 0.0]
	_hint.text = "Ache os contêineres e chegue no berço."
	_deck.grab_focus()
	_refresh()


func _tick(delta: float) -> void:
	if game == null:
		return
	game.advance(delta)
	_tractor = _tractor.lerp(Vector2(game.at), minf(1.0, delta * 14.0))
	# The stick springs back when nothing is pushing it, the way a real one does.
	_stick = _stick.lerp(_push, minf(1.0, delta * 22.0))
	for index in _lamp.size():
		_lamp[index] = maxf(0.0, float(_lamp[index]) - delta * 3.2)
	if _held != 0:
		_repeat -= delta
		if _repeat <= 0.0:
			_repeat = REPEAT_RATE
			_step(_held)
	_screen.queue_redraw()
	_deck.queue_redraw()
	_refresh()


func _step(direction: int) -> void:
	if game == null or _closing or game.over:
		return
	var outcome := game.move(direction)
	if not bool(outcome.get("moved", false)):
		_shake = maxf(_shake, 0.45)
		_lamp[1] = 1.0
		AudioManager.play_sfx("deny", 0.08, -6.0)
		return
	_lamp[0] = 1.0
	if bool(outcome.get("crate", false)):
		_say("ACHOU! %d/%d" % [game.collected, game.goal], UiTheme.TEAL_LIGHT)
		AudioManager.play_sfx_pitched("thunk",
			1.0 + float(game.collected) * 0.12, -2.0)
		if game.exit_open():
			_hint.text = "Tudo a bordo. Corre pro berço!"
	else:
		AudioManager.play_sfx_pitched("tap", 0.9 + float(game.moves % 4) * 0.05, -12.0)
	_refresh()


# --------------------------------------------------------------------- input

func _on_deck_input(event: InputEvent) -> void:
	## Push the stick. Anywhere on the deck works — demanding the player find the
	## ball itself would be a 20px target on a phone.
	var pressed := false
	var released := false
	var at := Vector2.ZERO
	var touch := event as InputEventScreenTouch
	if touch != null:
		pressed = touch.pressed
		released = not touch.pressed
		at = touch.position
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		pressed = click.pressed
		released = not click.pressed
		at = click.position
	var drag := event as InputEventScreenDrag
	if drag != null:
		pressed = true
		at = drag.position
	var motion := event as InputEventMouseMotion
	if motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pressed = true
		at = motion.position

	if released:
		_push = Vector2.ZERO
		_held = 0
		return
	if not pressed:
		return
	var from_centre := at - _stick_centre()
	if from_centre.length() < STICK_DEADZONE:
		_push = Vector2.ZERO
		_held = 0
		return
	# One axis at a time: a maze is four-way, and a stick pushed diagonally has
	# to commit to whichever way it is pushed hardest or the yard reads as
	# ignoring half the presses.
	var direction := _direction_of(from_centre)
	_push = _offset_of(direction)
	if direction != _held:
		_held = direction
		_repeat = REPEAT_DELAY
		_step(direction)


static func _direction_of(from_centre: Vector2) -> int:
	if absf(from_centre.x) > absf(from_centre.y):
		return MazeGame.EAST if from_centre.x > 0.0 else MazeGame.WEST
	return MazeGame.SOUTH if from_centre.y > 0.0 else MazeGame.NORTH


static func _offset_of(direction: int) -> Vector2:
	match direction:
		MazeGame.NORTH:
			return Vector2(0.0, -1.0)
		MazeGame.SOUTH:
			return Vector2(0.0, 1.0)
		MazeGame.WEST:
			return Vector2(-1.0, 0.0)
		MazeGame.EAST:
			return Vector2(1.0, 0.0)
	return Vector2.ZERO


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	var direction := 0
	match key.keycode:
		KEY_UP, KEY_W:
			direction = MazeGame.NORTH
		KEY_RIGHT, KEY_D:
			direction = MazeGame.EAST
		KEY_DOWN, KEY_S:
			direction = MazeGame.SOUTH
		KEY_LEFT, KEY_A:
			direction = MazeGame.WEST
		_:
			return
	# The key throws the stick too, so the cabinet shows what the keyboard did.
	if key.pressed:
		_push = _offset_of(direction)
		_step(direction)
	elif _push == _offset_of(direction):
		_push = Vector2.ZERO
	get_viewport().set_input_as_handled()


func _refresh() -> void:
	if game == null:
		return
	_set_stats("%4.1fs" % game.time_left,
		"%d/%d" % [game.collected, game.goal],
		"berço %s" % ("aberto" if game.exit_open() else "fechado"))


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

func _draw_screen() -> void:
	## The glass: the yard, then the scanlines and the corner vignette that make
	## it a screen rather than a panel.
	if game == null or _screen == null:
		return
	var w := _screen.size.x
	var h := _screen.size.y
	if w <= 0.0 or h <= 0.0:
		return
	# The marquee across the top of the cabinet, and the glass under it. The glass
	# is square because the yard is: painting the whole panel black left two
	# letterboxes of nothing above and below a nine-by-nine grid, and hid the
	# cabinet the game is supposed to be played on.
	var marquee_h := 15.0
	_screen.draw_rect(Rect2(0.0, 0.0, w, marquee_h), Color(0.13, 0.11, 0.17))
	_screen.draw_rect(Rect2(0.0, marquee_h - 1.0, w, 1.0), Color(0.30, 0.26, 0.38))
	var name := str(_offer.get("title", "PÁTIO")).to_upper()
	var name_w := UiTheme.FONT.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT,
		-1, UiTheme.SIZE_SMALL).x
	_screen.draw_string(UiTheme.FONT, Vector2((w - name_w) * 0.5, marquee_h - 4.0),
		name, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL,
		Color(UiTheme.AMBER, 0.85))

	var glass := minf(w - 8.0, h - marquee_h - 10.0)
	var glass_at := Vector2((w - glass) * 0.5,
		marquee_h + (h - marquee_h - glass) * 0.5)
	# The recess the glass sits in, then the glass.
	_screen.draw_rect(Rect2(glass_at - Vector2.ONE * 3.0,
		Vector2.ONE * (glass + 6.0)), Color(0.09, 0.08, 0.12))
	_screen.draw_rect(Rect2(glass_at - Vector2.ONE * 3.0,
		Vector2.ONE * (glass + 6.0)), Color(0.34, 0.31, 0.40), false, 1.0)
	_screen.draw_rect(Rect2(glass_at, Vector2.ONE * glass), Color(0.04, 0.06, 0.05))

	var cell := glass / float(maxi(game.width, game.height))
	var origin := glass_at + (Vector2.ONE * glass
		- Vector2(cell * game.width, cell * game.height)) * 0.5
	# Yard surface, and the painted grid on it.
	_screen.draw_rect(Rect2(origin, Vector2(cell * game.width, cell * game.height)),
		Color(0.10, 0.13, 0.12))
	var wall := Color(0.36, 0.86, 0.62)
	var paint := Color(0.20, 0.30, 0.26)
	for y in game.height:
		for x in game.width:
			var cell_pos := origin + Vector2(x, y) * cell
			_screen.draw_rect(Rect2(cell_pos + Vector2.ONE,
				Vector2(cell, cell) - Vector2.ONE * 2.0), paint, false, 1.0)
	# Only the two leading edges are drawn per cell, plus the far border: drawing
	# all four paints every wall twice.
	for y in game.height:
		for x in game.width:
			var cell_pos := origin + Vector2(x, y) * cell
			var sides := game.sides(Vector2i(x, y))
			if (sides & MazeGame.NORTH) == 0:
				_screen.draw_line(cell_pos, cell_pos + Vector2(cell, 0.0), wall, WALL_WIDTH)
			if (sides & MazeGame.WEST) == 0:
				_screen.draw_line(cell_pos, cell_pos + Vector2(0.0, cell), wall, WALL_WIDTH)
			if x == game.width - 1 and (sides & MazeGame.EAST) == 0:
				_screen.draw_line(cell_pos + Vector2(cell, 0.0),
					cell_pos + Vector2(cell, cell), wall, WALL_WIDTH)
			if y == game.height - 1 and (sides & MazeGame.SOUTH) == 0:
				_screen.draw_line(cell_pos + Vector2(0.0, cell),
					cell_pos + Vector2(cell, cell), wall, WALL_WIDTH)

	# The berth, shut until every box is aboard.
	var exit_pos := origin + Vector2(game.exit_cell) * cell
	var exit_colour := UiTheme.TEAL_LIGHT if game.exit_open() else UiTheme.DANGER
	_screen.draw_rect(Rect2(exit_pos + Vector2(cell, cell) * 0.18,
		Vector2(cell, cell) * 0.64), Color(exit_colour, 0.25))
	_screen.draw_rect(Rect2(exit_pos + Vector2(cell, cell) * 0.18,
		Vector2(cell, cell) * 0.64), exit_colour, false, 1.0)

	for crate: Vector2i in game.crates:
		var crate_pos := origin + Vector2(crate) * cell + Vector2(cell, cell) * 0.5
		var box := AtlasTexture.new()
		box.atlas = CONTAINERS
		box.region = Rect2(posmod(crate.x + crate.y, 8) * 24, 0, 24, 13)
		_screen.draw_texture_rect(box,
			Rect2(crate_pos - Vector2(cell, cell * 0.55) * 0.42,
				Vector2(cell * 0.84, cell * 0.46)), false)

	# The tractor: a body with a nose, so which way it last went is visible.
	var truck := origin + _tractor * cell + Vector2(cell, cell) * 0.5
	var nose := _push if _push != Vector2.ZERO else Vector2(0.0, -1.0)
	_screen.draw_circle(truck, cell * 0.30, UiTheme.AMBER)
	_screen.draw_circle(truck + nose * cell * 0.20, cell * 0.13, UiTheme.CREAM)
	_screen.draw_circle(truck, cell * 0.14, UiTheme.AMBER_DEEP)

	# Scanlines and a vignette, on the glass only. Cheap, and they are the
	# difference between a drawing of a maze and a maze on a screen.
	for y in range(int(glass_at.y), int(glass_at.y + glass), 3):
		_screen.draw_rect(Rect2(glass_at.x, y, glass, 1.0),
			Color(0.0, 0.0, 0.0, 0.22))
	for step in 5:
		var inset := float(step)
		_screen.draw_rect(Rect2(glass_at.x + inset, glass_at.y + inset,
			glass - inset * 2.0, glass - inset * 2.0),
			Color(0.0, 0.0, 0.0, 0.13), false, 1.0)


func _stick_centre() -> Vector2:
	return Vector2(_deck.size.x * 0.32, _deck.size.y * 0.5) if _deck != null \
		else Vector2.ZERO


func _draw_deck() -> void:
	## The ball stick and the two buttons. All of it drawn rather than sprited,
	## because a stick that tilts is a sprite per angle.
	if _deck == null:
		return
	var w := _deck.size.x
	var h := _deck.size.y
	if w <= 0.0 or h <= 0.0:
		return
	var centre := _stick_centre()

	# The dust washer the shaft comes through, and the gate ring around it.
	_deck.draw_circle(centre, 26.0, Color(0.10, 0.09, 0.13))
	_deck.draw_circle(centre, 23.0, Color(0.17, 0.16, 0.21))
	_deck.draw_arc(centre, 23.0, 0.0, TAU, 32, Color(0.36, 0.34, 0.42), 1.0)
	# Four lamps on the gate, lit for the ways out of this cell. The maze is the
	# thing the player is reading, and a stick that says which way is open is the
	# arcade version of the greyed-out key the pad used to have.
	for direction: int in [MazeGame.NORTH, MazeGame.EAST, MazeGame.SOUTH,
			MazeGame.WEST]:
		var open := game != null and game.can_move(direction)
		var mark := centre + _offset_of(direction) * 23.0
		_deck.draw_circle(mark, 3.5, Color(0.08, 0.07, 0.10))
		_deck.draw_circle(mark, 2.5,
			Color(UiTheme.TEAL_LIGHT if open else UiTheme.DANGER,
				0.9 if open else 0.45))

	# Shaft and ball, thrown by however far the stick is pushed.
	var ball := centre + _stick * STICK_THROW
	_deck.draw_line(centre, ball, Color(0.55, 0.55, 0.63), 6.0)
	_deck.draw_line(centre, ball, Color(0.84, 0.84, 0.92), 2.0)
	_deck.draw_circle(ball + Vector2(0.0, 2.0), 12.0, Color(0.0, 0.0, 0.0, 0.5))
	_deck.draw_circle(ball, 12.0, Color(0.62, 0.16, 0.14))
	_deck.draw_circle(ball, 10.5, UiTheme.DANGER)
	_deck.draw_circle(ball - Vector2(3.5, 4.0), 3.5, Color(1.0, 0.74, 0.68, 0.9))

	# Two buttons: one lights when the yard let you through, one when it did not.
	var colours := [UiTheme.TEAL_LIGHT, UiTheme.AMBER]
	for index in 2:
		var at := Vector2(w * 0.68 + float(index) * 34.0, h * 0.5
			- (8.0 if index == 0 else -8.0))
		var glow := float(_lamp[index])
		_deck.draw_circle(at + Vector2(0.0, 2.0), 13.0, Color(0.08, 0.07, 0.10))
		_deck.draw_circle(at, 12.0, Color(0.21, 0.20, 0.25))
		_deck.draw_circle(at, 9.5,
			Color(colours[index]).lerp(Color(0.13, 0.12, 0.16), 1.0 - glow * 0.85))
		_deck.draw_arc(at, 12.0, 0.0, TAU, 26, Color(0.42, 0.40, 0.48), 1.0)

