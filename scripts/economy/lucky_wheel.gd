class_name LuckyWheel
extends RefCounted
## The rules of the Roda da Sorte: eight segments and two free spins a real
## day (one every twelve hours). More spins are tokens, and tokens are scarce:
## a daily mission, a rare respin segment, or a rewarded video.
##
## Pure rules — no nodes, no autoloads, no clock of its own. Every moment is
## passed in as `now_unix` and every roll comes from a caller-owned RNG, so a
## suite can fake both. The prize is decided at `spin()` and then held in
## `pending` until `claim()`: a decided-but-unclaimed prize is what lets a
## reload finish the spin honestly ("nothing half-happens") instead of
## silently eating it. Applying the prize to the economy is NOT this class's
## job — that is `WheelService`.

## Clockwise from the top: index 0 sits under the pointer at rotation 0.
## The weights sum to 100, so a weight is a percentage.
const SEGMENTS: Array[Dictionary] = [
	{"id": &"cash_s", "kind": &"cash", "seconds": 90.0, "weight": 34},
	{"id": &"surge2", "kind": &"surge", "mult": 2.0, "seconds": 90.0, "weight": 20},
	{"id": &"cash_m", "kind": &"cash", "seconds": 360.0, "weight": 16},
	{"id": &"respin", "kind": &"token", "tokens": 1, "weight": 4},
	{"id": &"jackpot", "kind": &"cash", "seconds": 3600.0, "weight": 3},
	{"id": &"surge3", "kind": &"surge", "mult": 3.0, "seconds": 60.0, "weight": 12},
	{"id": &"cash_l", "kind": &"cash", "seconds": 1200.0, "weight": 6},
	{"id": &"frenzy", "kind": &"surge", "mult": 7.0, "seconds": 30.0, "weight": 7},
]
## One free spin every twelve real hours - two a day - on the wall clock the
## save remembers. A rare wheel is one the player comes back for.
const FREE_SPIN_INTERVAL := 12.0 * 3600.0
## The rules still count departures, but the service no longer feeds them: ships
## are the most frequent event in the game and made the wheel a faucet.
const DEPARTURES_PER_TOKEN := 3
const MAX_TOKENS := 3
## A cash prize is seconds of the port's own income — never less than this, so
## a spin in an empty port is still a spin that pays something.
const MIN_PRIZE_CPS := 0.5

var tokens: int = 0
var next_free_unix: float = 0.0
var departures: int = 0
## The decided-but-unclaimed prize ({} when the wheel is idle).
var pending: Dictionary = {}
var spins_total: int = 0
var jackpots: int = 0


func free_spin_ready(now_unix: float) -> bool:
	return now_unix >= next_free_unix


func seconds_to_free(now_unix: float) -> float:
	return maxf(0.0, next_free_unix - now_unix)


func can_spin(now_unix: float) -> bool:
	## A prize already on the table must be collected before the wheel turns
	## again — otherwise a spin could overwrite an unclaimed prize.
	return pending.is_empty() and (free_spin_ready(now_unix) or tokens > 0)


func note_departure() -> bool:
	## One ship left. Returns true when this departure granted a token.
	departures += 1
	if departures < DEPARTURES_PER_TOKEN:
		return false
	# The progress resets either way: a token that cannot be granted because
	# the rack is full is not banked for later.
	departures = 0
	if tokens >= MAX_TOKENS:
		return false
	tokens += 1
	return true


func spin(now_unix: float, rng: RandomNumberGenerator) -> Dictionary:
	## Decide a prize and hold it in `pending`. Returns {} when the wheel
	## cannot spin right now.
	if not can_spin(now_unix):
		return {}
	# The free spin is spent first; a token is only consumed when the free
	# clock is not ready.
	if free_spin_ready(now_unix):
		next_free_unix = now_unix + FREE_SPIN_INTERVAL
	else:
		tokens -= 1
	var total := 0
	for segment in SEGMENTS:
		total += int(segment.weight)
	var roll := rng.randi_range(1, total)
	var index := SEGMENTS.size() - 1
	var acc := 0
	for i in SEGMENTS.size():
		acc += int(SEGMENTS[i].weight)
		if roll <= acc:
			index = i
			break
	var segment: Dictionary = SEGMENTS[index]
	pending = segment.duplicate()
	pending["index"] = index
	spins_total += 1
	if segment.id == &"jackpot":
		jackpots += 1
	return pending


func prize_amount(segment: Dictionary, base_cps: float) -> float:
	## What a cash segment pays: seconds of the port's *base* income. The base
	## rate, never the surged one, so a spin that lands during a frenzy does not
	## pay seven times cash. Non-cash segments have no cash amount.
	if StringName(segment.get("kind", &"")) != &"cash":
		return 0.0
	return maxf(base_cps, MIN_PRIZE_CPS) * float(segment.get("seconds", 0.0))


func claim() -> Dictionary:
	## Hand out the pending prize exactly once, then clear it.
	if pending.is_empty():
		return {}
	var prize := pending
	pending = {}
	return prize


# ----------------------------------------------------------------- persistence

func snapshot() -> Dictionary:
	return {
		"version": 1,
		"tokens": tokens,
		"next_free_unix": next_free_unix,
		"departures": departures,
		# A pending prize IS persisted: a reload applies it once rather than
		# dropping a decided spin on the floor.
		"pending": pending.duplicate(true),
		"spins_total": spins_total,
		"jackpots": jackpots,
	}


func restore(data: Dictionary) -> void:
	## Tolerant of missing or garbage keys: a field that does not parse reads
	## as its default, and a pending prize that does not name a real segment is
	## dropped rather than trusted.
	tokens = clampi(_as_int(data.get("tokens", 0), 0), 0, MAX_TOKENS)
	next_free_unix = maxf(0.0, _as_float(data.get("next_free_unix", 0.0), 0.0))
	departures = clampi(_as_int(data.get("departures", 0), 0), 0, DEPARTURES_PER_TOKEN - 1)
	spins_total = maxi(0, _as_int(data.get("spins_total", 0), 0))
	jackpots = maxi(0, _as_int(data.get("jackpots", 0), 0))
	pending = _restore_pending(data.get("pending", {}))


static func seed_new(now_unix: float) -> Dictionary:
	## A new profile can spin for free immediately.
	return {
		"version": 1,
		"tokens": 0,
		"next_free_unix": now_unix,
		"departures": 0,
		"pending": {},
		"spins_total": 0,
		"jackpots": 0,
	}


func _restore_pending(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var p := raw as Dictionary
	var index := _as_int(p.get("index", -1), -1)
	if index < 0 or index >= SEGMENTS.size():
		return {}
	# The catalogue is the authority on what a segment pays; the save only says
	# which one was rolled.
	if StringName(p.get("id", &"")) != StringName(SEGMENTS[index].get("id", &"")):
		return {}
	var restored := SEGMENTS[index].duplicate()
	restored["index"] = index
	return restored


static func _as_int(raw: Variant, fallback: int) -> int:
	if raw is int:
		return raw
	if raw is float:
		return int(raw)
	if raw is String and (raw as String).is_valid_int():
		return (raw as String).to_int()
	return fallback


static func _as_float(raw: Variant, fallback: float) -> float:
	if raw is float:
		return raw
	if raw is int:
		return float(raw)
	if raw is String and (raw as String).is_valid_float():
		return (raw as String).to_float()
	return fallback
