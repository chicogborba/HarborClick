class_name StackGame
extends RefCounted
## The rules of the stacking minigame, with no nodes in them.
##
## A trolley runs the width of the well, faster with every box you land. Tap and
## the box drops straight down. It lands where the trolley let go, so the tower
## leans by however much you were off, and the *overlap* with the box below is
## what you have to hit next time — miss the overlap and the box goes over the
## side. Three of those and the charter is lost; so is running the clock out.
##
## Keeping this pure is what makes it testable: the suite plays whole games
## headless, including a perfect one and a hopeless one, which is not something a
## screenshot can tell you.

## Field the boxes are stacked in, in the same pixel units the view draws.
const WELL_WIDTH := 220.0
const BOX_WIDTH := 34.0
## How much of the box below you must still cover for the drop to hold. It starts
## generous and closes as the tower rises.
const START_TOLERANCE := 15.0
const MIN_TOLERANCE := 5.0
const TOLERANCE_LOSS := 0.9
## Within this, the drop is dead centre: nothing is lost and time is given back.
const PERFECT_WINDOW := 2.4
const PERFECT_BONUS_SECONDS := 1.5
const LIVES := 3
## Trolley speed in pixels per second, and what each landed box adds to it.
const START_SPEED := 96.0
const SPEED_STEP := 15.0
const MAX_SPEED := 260.0

const RESULT_PERFECT: StringName = &"perfeito"
const RESULT_OK: StringName = &"ok"
const RESULT_MISS: StringName = &"errou"

var goal := 8
var placed := 0
var lives := LIVES
var time_left := 42.0
var tolerance := START_TOLERANCE
var speed := START_SPEED
var trolley_x := 0.0
var tower_x := 0.0
var direction := 1.0
var combo := 0
var best_combo := 0
## Every box that landed, as an x offset from the centre, bottom first. The view
## draws the tower straight off this.
var stack: Array[float] = []
var over := false
var victory := false


func setup(offer: Dictionary) -> void:
	goal = maxi(3, int(offer.get("goal", 8)))
	time_left = maxf(10.0, float(offer.get("seconds", 42.0)))
	placed = 0
	lives = LIVES
	tolerance = START_TOLERANCE
	speed = START_SPEED
	trolley_x = -WELL_WIDTH * 0.5 + BOX_WIDTH * 0.5
	tower_x = 0.0
	direction = 1.0
	combo = 0
	best_combo = 0
	stack = [0.0]                      # the box on the ground is always straight
	over = false
	victory = false


func advance(delta: float) -> void:
	if over:
		return
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		_finish(false)
		return
	trolley_x += direction * speed * delta
	var limit := WELL_WIDTH * 0.5 - BOX_WIDTH * 0.5
	if trolley_x > limit:
		trolley_x = limit
		direction = -1.0
	elif trolley_x < -limit:
		trolley_x = -limit
		direction = 1.0


func drop() -> Dictionary:
	## Let go. Returns what happened, which is also what the view animates.
	if over:
		return {"result": RESULT_MISS, "offset": 0.0, "over": true}
	var offset := trolley_x - tower_x
	var distance := absf(offset)
	if distance > tolerance:
		lives -= 1
		combo = 0
		if lives <= 0:
			_finish(false)
		return {"result": RESULT_MISS, "offset": offset, "landed_x": trolley_x,
			"lives": lives, "over": over}
	var perfect := distance <= PERFECT_WINDOW
	if perfect:
		# A dead-centre drop is rewarded with the thing the player is short of.
		trolley_x = tower_x
		time_left += PERFECT_BONUS_SECONDS
		combo += 1
	else:
		tolerance = maxf(MIN_TOLERANCE, tolerance * TOLERANCE_LOSS)
		combo = 0
	best_combo = maxi(best_combo, combo)
	tower_x = trolley_x
	stack.append(tower_x)
	placed += 1
	speed = minf(MAX_SPEED, speed + SPEED_STEP)
	if placed >= goal:
		_finish(true)
	return {"result": RESULT_PERFECT if perfect else RESULT_OK, "offset": offset,
		"landed_x": tower_x, "placed": placed, "combo": combo, "over": over}


func height() -> int:
	return stack.size()


func progress() -> float:
	return clampf(float(placed) / float(maxi(1, goal)), 0.0, 1.0)


func summary() -> Dictionary:
	return {"won": victory, "placed": placed, "goal": goal, "lives": lives,
		"best_combo": best_combo, "time_left": time_left}


func _finish(won: bool) -> void:
	over = true
	victory = won
