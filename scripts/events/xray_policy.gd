class_name XrayPolicy
extends RefCounted
## The Receita Federal's X-ray scanner as rules: what it costs, when an
## inspection is due, and what a cleared inspection pays.
##
## Pure — no nodes, no autoloads, no clock of its own. Deltas, rolls and the
## port's income come from the caller (`XrayService`), so a suite can fake all
## three. Persisted as the `xray_scanner` save section.
##
## **The inspection clock IS persisted**, unlike the golden gull's. The gull's
## first-of-session delay is shorter than its gap, so a clock that reset on
## load would be farmable by reloading; here the opposite holds — a clock that
## reset would *re-arm the first delay* every session — so it is saved and a
## reload simply continues it. A due inspection stays due across a reload too:
## `ready` is only cleared by `resolve`, so a board caught mid-play comes back
## as one still to play ("nothing half-happens").
##
## The scanner is meta progress, like the wheel: a prestige rebuilds the port
## around it and does not take it back.

## The scanner costs this many seconds of the port's base income, and never
## less than `MIN_PRICE`: Neide offers it in the first minutes, when a whole
## port makes a few TEU a second, and it must be a purchase, not a gift.
const PRICE_SECONDS := 480.0
const MIN_PRICE := 250.0
## Real seconds from the purchase to the first inspection — short, so the
## player plays what they just bought — and between inspections after that.
const FIRST_DELAY := 40.0
const MIN_GAP := 300.0
const MAX_GAP := 540.0
## The Benefício Fiscal: a production surge. A clean scan (no wrong taps)
## pays the bigger multiplier.
const BENEFIT_MULT := 3.0
const CLEAN_MULT := 4.0
const BENEFIT_SECONDS := 90.0
## Difficulty grows with inspections cleared, up to this level.
const MAX_LEVEL := 6

var owned := false
var until_next := FIRST_DELAY
var ready := false
var played := 0
var won := 0
var streak := 0
var best_streak := 0


func price(base_cps: float) -> float:
	return maxf(MIN_PRICE, maxf(0.0, base_cps) * PRICE_SECONDS)


func buy() -> bool:
	## Book the purchase (the caller has already taken the money). Refused
	## when already owned, so a double tap never charges twice.
	if owned:
		return false
	owned = true
	ready = false
	until_next = FIRST_DELAY
	return true


func tick(delta: float, can_run: bool, rng: RandomNumberGenerator) -> bool:
	## Advance the inspection clock. True exactly once, when an inspection
	## falls due. A due inspection waits for the player — the clock does not
	## run on top of it — and nothing ticks while `can_run` is false.
	if not owned or ready or not can_run:
		return false
	until_next -= delta
	if until_next > 0.0:
		return false
	ready = true
	until_next = rng.randf_range(MIN_GAP, MAX_GAP)
	return true


func level() -> int:
	return mini(won, MAX_LEVEL)


func scan_seed() -> int:
	## The seed of the inspection on the table: the same until it is resolved.
	return 7919 * (played + 1) + 104729 * won + 17


func resolve(cleared: bool, mistakes: int) -> Dictionary:
	## Book a played inspection. Returns the benefit to grant ({} on a loss or
	## when nothing was due). A loss costs nothing but the streak.
	if not ready:
		return {}
	ready = false
	played += 1
	if not cleared:
		streak = 0
		return {}
	won += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	return {"kind": &"surge", "seconds": BENEFIT_SECONDS,
		"mult": CLEAN_MULT if mistakes <= 0 else BENEFIT_MULT,
		"clean": mistakes <= 0}


func snapshot() -> Dictionary:
	return {
		"version": 1, "owned": owned, "until_next": until_next, "ready": ready,
		"played": played, "won": won, "streak": streak,
		"best_streak": best_streak,
	}


func restore(data: Dictionary) -> void:
	## Tolerant of missing or garbage keys: anything that does not parse reads
	## as its default, and the clock is clamped into the range it can hold.
	owned = _as_bool(data.get("owned", false))
	until_next = clampf(_as_float(data.get("until_next", FIRST_DELAY), FIRST_DELAY),
		0.0, MAX_GAP)
	ready = owned and _as_bool(data.get("ready", false))
	played = maxi(0, _as_int(data.get("played", 0)))
	won = clampi(_as_int(data.get("won", 0)), 0, played)
	streak = clampi(_as_int(data.get("streak", 0)), 0, won)
	best_streak = clampi(_as_int(data.get("best_streak", 0)), streak, won)


static func seed_new() -> Dictionary:
	## A new profile, and an old profile from before the scanner existed: not
	## bought yet. Neide introduces it the first time she gets a tip slot.
	return {"version": 1, "owned": false, "until_next": FIRST_DELAY,
		"ready": false, "played": 0, "won": 0, "streak": 0, "best_streak": 0}


static func _as_bool(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL and bool(value)


static func _as_float(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return float(value)
	return fallback


static func _as_int(value: Variant) -> int:
	if value is int or value is float:
		return int(value)
	return 0
