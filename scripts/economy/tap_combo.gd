class_name TapCombo
extends RefCounted
## The rhythm of working a ship: taps that keep coming build a multiplier on the
## tap, and a pause lets it fall.
##
## Every `TAPS_PER_STEP` taps in a streak add `STEP` to the multiplier, up to
## `MAX_STEPS` steps (x3.0). The streak survives gaps shorter than `WINDOW`
## seconds, so it rewards a steady hand rather than a fast one — a player who
## taps twice a second keeps it, one who stops to read does not. Pure rules with
## the clock passed in; session-scoped, never saved (a combo that survived a
## reload could only be farmed by reloading).
##
## Skills can `pin` the combo at its maximum for a while: Mutirão does.

const TAPS_PER_STEP := 8
const MAX_STEPS := 8
const STEP := 0.25
const WINDOW := 1.4

var taps := 0
var _last := -1.0e9
var _pinned_until := -1.0e9


func note_tap(now: float) -> bool:
	## Count one tap. True when it earned a new step (the moment to ping).
	if now - _last > WINDOW:
		taps = 0
	var before := steps(now)
	_last = now
	taps += 1
	return steps(now) > before


func steps(now: float) -> int:
	if now <= _pinned_until:
		return MAX_STEPS
	if now - _last > WINDOW:
		return 0
	return mini(MAX_STEPS, taps / TAPS_PER_STEP)


func multiplier(now: float) -> float:
	return 1.0 + STEP * float(steps(now))


func is_active(now: float) -> bool:
	return steps(now) > 0


func is_maxed(now: float) -> bool:
	return steps(now) >= MAX_STEPS


func pin(now: float, seconds: float) -> void:
	_pinned_until = maxf(_pinned_until, now + seconds)
	_last = maxf(_last, now)


func reset() -> void:
	taps = 0
	_last = -1.0e9
	_pinned_until = -1.0e9
