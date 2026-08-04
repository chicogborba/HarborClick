class_name MazeGame
extends RefCounted
## The rules of the yard-maze minigame, with no nodes in them.
##
## A terminal tractor is dropped at the gate of a yard nobody has swept in
## months. Somewhere in it are the boxes the charter is waiting on, and the berth
## is on the far corner. Collect every box, reach the berth, beat the clock.
##
## The maze is carved deterministically from the charter's own seed, so the same
## charter is the same maze — a maze that rerolls on reload is a maze worth
## reloading for. Generation is a plain iterative backtracker with its own
## generator: touching the global RNG here would make every other seeded thing in
## the game depend on how a minigame was played.

const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8

const STEP := {NORTH: Vector2i(0, -1), EAST: Vector2i(1, 0),
	SOUTH: Vector2i(0, 1), WEST: Vector2i(-1, 0)}
const OPPOSITE := {NORTH: SOUTH, EAST: WEST, SOUTH: NORTH, WEST: EAST}

## A grid small enough to read on a phone and big enough to get lost in.
const SIZE := Vector2i(9, 9)

var width := SIZE.x
var height := SIZE.y
## `open_sides[y * width + x]` is the bitmask of walls this cell has *removed*.
var open_sides: PackedInt32Array = PackedInt32Array()
var at := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
var crates: Array[Vector2i] = []
var collected := 0
var goal := 3
var time_left := 45.0
var moves := 0
var over := false
var victory := false
var _state := 1


func setup(offer: Dictionary, maze_seed: int = 0) -> void:
	width = SIZE.x
	height = SIZE.y
	goal = clampi(int(offer.get("crates", 3)), 1, 8)
	time_left = maxf(10.0, float(offer.get("seconds", 45.0)))
	collected = 0
	moves = 0
	over = false
	victory = false
	_state = posmod(maze_seed if maze_seed != 0 else str(offer.get("id", "")).hash(),
		2147483646) + 1
	_carve()
	at = Vector2i.ZERO
	exit_cell = Vector2i(width - 1, height - 1)
	_scatter_crates()


func advance(delta: float) -> void:
	if over:
		return
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		over = true
		victory = false


func can_move(direction: int) -> bool:
	if over or not STEP.has(direction):
		return false
	return (open_sides[_index(at)] & direction) != 0


func move(direction: int) -> Dictionary:
	## One cell, if there is no wall in the way. Returns what happened there.
	if not can_move(direction):
		return {"moved": false, "blocked": true, "over": over}
	at += STEP[direction]
	moves += 1
	var took := false
	for index in crates.size():
		if crates[index] == at:
			crates.remove_at(index)
			collected += 1
			took = true
			# Every box found buys a little clock back: the game should reward
			# finding things, not just surviving.
			time_left += 2.5
			break
	var arrived := at == exit_cell and collected >= goal
	if arrived:
		over = true
		victory = true
	return {"moved": true, "blocked": false, "crate": took, "arrived": arrived,
		"collected": collected, "over": over}


func remaining() -> int:
	return maxi(0, goal - collected)


func exit_open() -> bool:
	return collected >= goal


func progress() -> float:
	return clampf(float(collected) / float(maxi(1, goal)), 0.0, 1.0)


func summary() -> Dictionary:
	return {"won": victory, "collected": collected, "goal": goal,
		"moves": moves, "time_left": time_left}


func sides(cell: Vector2i) -> int:
	if not _inside(cell):
		return 0
	return open_sides[_index(cell)]


# ------------------------------------------------------------------ carving

func _carve() -> void:
	## Iterative backtracker: every cell is reachable from every other, so the
	## maze can never be generated unsolvable.
	open_sides = PackedInt32Array()
	open_sides.resize(width * height)
	var visited := {}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	visited[Vector2i.ZERO] = true
	while not stack.is_empty():
		var cell: Vector2i = stack[stack.size() - 1]
		var options: Array[int] = []
		for direction: int in STEP:
			var next: Vector2i = cell + STEP[direction]
			if _inside(next) and not visited.has(next):
				options.append(direction)
		if options.is_empty():
			stack.pop_back()
			continue
		var chosen: int = options[_roll(options.size())]
		var target: Vector2i = cell + STEP[chosen]
		open_sides[_index(cell)] |= chosen
		open_sides[_index(target)] |= int(OPPOSITE[chosen])
		visited[target] = true
		stack.append(target)


func _scatter_crates() -> void:
	## Boxes go where the player has to go looking for them: never on the gate
	## cell, never on the berth, and no two on the same square.
	crates = []
	var taken := {Vector2i.ZERO: true, exit_cell: true}
	var guard := 0
	while crates.size() < goal and guard < 400:
		guard += 1
		var cell := Vector2i(_roll(width), _roll(height))
		if taken.has(cell):
			continue
		# Push them away from the gate so the first one is never underfoot.
		if cell.x + cell.y < 2:
			continue
		taken[cell] = true
		crates.append(cell)


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func _index(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func _roll(limit: int) -> int:
	## Park-Miller, the same generator the ship catalogue rolls with. Deliberately
	## not the global RNG: a maze must not move the seeded sequence every other
	## system draws from.
	_state = posmod(_state * 48271, 2147483647)
	return posmod(_state, maxi(1, limit))
