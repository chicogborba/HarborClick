class_name BerthDeadline
extends RefCounted
## The rules of a call's laytime: how long a hull may stay alongside, what an
## overstay costs and what an early sailing pays.
##
## Pure rules - no nodes, no clock. `BerthCallController` owns the countdown and
## calls these for the numbers.
##
## Designed so the clock is a reason to tap, never a punishment for leaving the
## game alone:
## - the laytime is sized from the work (both legs of the manifest) at the rate
##   the port's own machines manage plus a relaxed tap pace, so a port that is
##   being played beats it comfortably and an automated one is close;
## - an overstay costs a share of what *this ship* earned, once, from the wallet
##   and never into debt - an ignored port loses a slice, not its savings;
## - sailing early multiplies the freight bonus by up to `EARLY_MAX`, in
##   proportion to the time left on the clock.

## Laytime is switched off. A clock over every hull, a fine for missing it and a
## bonus for beating it turned loading a ship into a race nobody had asked to
## run, in a game whose other half is leaving it alone. The rules stay here,
## tested, behind this switch; with it off no call is timed, fined or paid early.
const ENABLED := false

## Moves per second a player tapping at an easy pace adds to the machines.
const TAP_PACE := 0.55
## Slack on top of the work: nobody should need a perfect run.
const SLACK := 1.35
const MIN_SECONDS := 75.0
const MAX_SECONDS := 300.0
## The overstay fine, as a share of what the ship earned before the clock ran out.
const FINE_SHARE := 0.15
## Sailing with the whole clock left would add this much again to the freight.
const EARLY_MAX := 1.0


static func laytime(moves: int, auto_rate: float) -> float:
	## Seconds alongside for a call of `moves` box moves (discharge + load).
	var rate := maxf(0.05, auto_rate) + TAP_PACE
	return clampf(float(moves) / rate * SLACK, MIN_SECONDS, MAX_SECONDS)


static func fine(earned: float) -> float:
	return maxf(0.0, earned) * FINE_SHARE


static func early_multiplier(left: float, total: float) -> float:
	## 1.0 for a ship that sailed on the wire or late; up to 1 + EARLY_MAX.
	if total <= 0.0 or left <= 0.0:
		return 1.0
	return 1.0 + EARLY_MAX * clampf(left / total, 0.0, 1.0)


static func clock_text(seconds: float) -> String:
	var s := maxi(0, ceili(seconds))
	return "%d:%02d" % [s / 60, s % 60]
