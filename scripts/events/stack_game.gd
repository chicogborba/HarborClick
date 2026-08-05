class_name StackGame
extends RefCounted
## The rules of the stacking minigame, with no nodes in them.
##
## A trolley runs the width of the well and one tap lets go. The box lands where
## you released it, and from then on the tower has to *hold it up*.
##
## The first version scored a drop against a shrinking tolerance: inside it the
## box landed, outside it you lost a life. That is a timing game wearing a
## stacking game's clothes — the tower never actually did anything, and a
## playtest said so. It balances now:
##
##   * a box has to **overlap** the one under it or it slides off the side;
##   * every box that stays adds its weight where it landed, so the whole
##     tower's **centre of mass** wanders;
##   * when that centre leaves the footprint of the box on the ground, the tower
##     **goes over** and the charter is lost. Nothing else ends it early.
##
## So the pressure is cumulative rather than per-drop, and a run of small
## rightward errors is as fatal as one big one — which is the thing a real stack
## does and a tolerance check never could. `lean()` is that same number as a
## fraction, and the view tilts the tower by it, so the danger is visible several
## drops before it arrives.
##
## Keeping this pure is what makes it testable: the suite plays whole games
## headless, including a perfect one, a toppled one and one lost to the clock,
## which is not something a screenshot can tell you.

## Field the boxes are stacked in, in the same pixel units the view draws. The
## box is deliberately big — a playtest expected containers, and 34px of box in a
## 220px well read as a brick.
const WELL_WIDTH := 208.0
const BOX_WIDTH := 62.0
## Least overlap with the box below that still counts as landing on it. Below
## this the box tips off the edge instead of resting.
const MIN_OVERLAP := 0.22
## How far the centre of mass may stray from the middle of the base before the
## tower goes over, as a fraction of half a box.
const TOPPLE_AT := 0.92
## Within this, the drop is dead centre: it costs nothing and buys time back.
const PERFECT_WINDOW := 3.0
const PERFECT_BONUS_SECONDS := 1.5
## Trolley speed in pixels per second, and what each landed box adds to it.
const START_SPEED := 92.0
const SPEED_STEP := 13.0
const MAX_SPEED := 250.0

const RESULT_PERFECT: StringName = &"perfeito"
const RESULT_OK: StringName = &"ok"
const RESULT_SLIP: StringName = &"escorregou"
const RESULT_TOPPLE: StringName = &"tombou"

var goal := 8
var placed := 0
var time_left := 42.0
var speed := START_SPEED
var trolley_x := 0.0
var direction := 1.0
var combo := 0
var best_combo := 0
## Every box that landed, as an x offset from the centre, bottom first. The view
## draws the tower straight off this.
var stack: Array[float] = []
var over := false
var victory := false
var toppled := false


func setup(offer: Dictionary) -> void:
	goal = maxi(3, int(offer.get("goal", 8)))
	time_left = maxf(10.0, float(offer.get("seconds", 42.0)))
	placed = 0
	speed = START_SPEED
	trolley_x = -WELL_WIDTH * 0.5 + BOX_WIDTH * 0.5
	direction = 1.0
	combo = 0
	best_combo = 0
	stack = [0.0]                      # the box on the ground is always straight
	over = false
	victory = false
	toppled = false


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


func top() -> float:
	return stack[stack.size() - 1] if not stack.is_empty() else 0.0


func centre_of_mass() -> float:
	## Every box weighs the same, so this is the mean of where they landed. It is
	## the whole game: one wild drop and four careful ones average out, five drops
	## drifting the same way do not.
	if stack.is_empty():
		return 0.0
	var total := 0.0
	for x: float in stack:
		total += x
	return total / float(stack.size())


func lean() -> float:
	## How close the tower is to going over, from 0 to 1 and signed. The view
	## tilts by this, which is what makes the danger arrive gradually instead of
	## as a verdict on the last drop.
	var reach := BOX_WIDTH * 0.5 * TOPPLE_AT
	return clampf((centre_of_mass() - stack[0]) / maxf(reach, 0.001), -1.0, 1.0)


func drop() -> Dictionary:
	## Let go. Returns what happened, which is also what the view animates.
	if over:
		return {"result": RESULT_SLIP, "offset": 0.0, "over": true}
	var offset := trolley_x - top()
	# Land on the box below or slide off it. There are no lives: the tower is the
	# health bar, and a box that never rested was never part of it.
	if absf(offset) > BOX_WIDTH * (1.0 - MIN_OVERLAP):
		combo = 0
		return {"result": RESULT_SLIP, "offset": offset, "landed_x": trolley_x,
			"lean": lean(), "over": over}
	var perfect := absf(offset) <= PERFECT_WINDOW
	if perfect:
		# A dead-centre drop is rewarded with the thing the player is short of,
		# and it lands truly square rather than three pixels out.
		trolley_x = top()
		time_left += PERFECT_BONUS_SECONDS
		combo += 1
	else:
		combo = 0
	best_combo = maxi(best_combo, combo)
	stack.append(trolley_x)
	placed += 1
	speed = minf(MAX_SPEED, speed + SPEED_STEP)
	# Weight added, tower re-checked. The order matters: a box that puts the
	# centre of mass over the edge still counts as placed, and *then* the tower
	# goes over — which is the frame the view needs to animate.
	if absf(lean()) >= 1.0:
		toppled = true
		_finish(false)
		return {"result": RESULT_TOPPLE, "offset": offset, "landed_x": trolley_x,
			"placed": placed, "lean": lean(), "over": over}
	if placed >= goal:
		_finish(true)
	return {"result": RESULT_PERFECT if perfect else RESULT_OK, "offset": offset,
		"landed_x": trolley_x, "placed": placed, "combo": combo,
		"lean": lean(), "over": over}


func height() -> int:
	return stack.size()


func progress() -> float:
	return clampf(float(placed) / float(maxi(1, goal)), 0.0, 1.0)


func summary() -> Dictionary:
	return {"won": victory, "placed": placed, "goal": goal,
		"toppled": toppled, "best_combo": best_combo, "time_left": time_left}


func _finish(won: bool) -> void:
	over = true
	victory = won
