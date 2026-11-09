class_name GoldenGullPolicy
extends RefCounted
## The rules of the gaivota dourada: when the golden gull crosses the terminal
## and what tapping it pays.
##
## Pure rules — no nodes, no autoloads, no clock of its own. Every delta and
## every roll comes from the caller (`PortWorld` owns the RNG), so a suite can
## fake both. Presentation is `GoldenGull`; applying a prize to the economy is
## `Main`'s job.
##
## **Session-scoped on purpose, and NOT persisted.** `until_next`, `caught`
## and `missed` live only for the running session: a reward clock that survived
## a reload could be farmed by reloading — quit one second before the gull and
## the next session starts already owed one. That is the same reason
## `GameState.surge_*` never survives a reload (see the events README): a burst
## is not bankable. Nothing here is registered with `SaveManager`.

## Real seconds until the first gull of a session.
## Priced against the port's own income, like every prize here. A gull every
## six minutes on average, worth seven minutes of production 60% of the time,
## is about +70% for a player who catches every one — the same order as the
## golden cookie it is modelled on. The first version (every four minutes, ten
## minutes of income) paid +150%, and an active session outran the whole curve.
const FIRST_DELAY := 90.0
## Real seconds between one gull and the next, drawn uniformly per re-arm.
const MIN_GAP := 240.0
const MAX_GAP := 480.0
## How long the gull stays on screen, tappable.
const FLIGHT_SECONDS := 9.0
## A cash prize is seconds of the port's own income — never less than this, so
## a gull caught in an empty port still pays something.
const MIN_PRIZE_CPS := 0.5

## The prize table. Weights sum to 100, so a weight is a percentage.
const PRIZES: Array[Dictionary] = [
	{"id": &"lucky", "kind": &"cash", "seconds": 420.0, "weight": 60},
	{"id": &"frenzy", "kind": &"surge", "mult": 7.0, "seconds": 30.0, "weight": 25},
	{"id": &"token", "kind": &"token", "tokens": 1, "weight": 15},
]

## Seconds until the next gull may spawn. Counts down only while `can_spawn`.
var until_next := FIRST_DELAY
var caught := 0
var missed := 0


func tick(delta: float, can_spawn: bool, rng: RandomNumberGenerator) -> bool:
	## Advance the reward clock. Returns true exactly once per arming, when the
	## countdown reaches zero, and re-arms the next gap from `rng`. While
	## `can_spawn` is false the clock does not move at all — a paused or
	## input-blocked terminal is not owed a gull.
	if not can_spawn:
		return false
	until_next -= delta
	if until_next > 0.0:
		return false
	until_next = rng.randf_range(MIN_GAP, MAX_GAP)
	return true


func roll(rng: RandomNumberGenerator) -> Dictionary:
	## A weighted pick from `PRIZES`, returned as a duplicate so the caller can
	## never corrupt the table.
	var total := 0
	for prize in PRIZES:
		total += int(prize.weight)
	var draw := rng.randi_range(1, total)
	var acc := 0
	for prize in PRIZES:
		acc += int(prize.weight)
		if draw <= acc:
			return prize.duplicate()
	return PRIZES[PRIZES.size() - 1].duplicate()


func cash_amount(prize: Dictionary, base_cps: float) -> float:
	## What a cash prize pays: seconds of the port's *base* income. The base
	## rate, never the surged one, so a gull caught during a frenzy does not pay
	## seven times cash. Non-cash prizes have no cash amount.
	if StringName(prize.get("kind", &"")) != &"cash":
		return 0.0
	return maxf(base_cps, MIN_PRIZE_CPS) * float(prize.get("seconds", 0.0))
