class_name DailyOrders
extends RefCounted
## The rules of Missões do Dia: three missions a day, picked deterministically
## from the local calendar day, a streak for days claimed in a row, and a bonus
## when all three are claimed.
##
## Pure rules — no nodes, no autoloads, no clock of its own. The caller works
## out the local day number with `day_key` and passes it into every call, so a
## suite can fake midnight. Deciding a reward is this class's job; applying it
## to the wheel or the port is NOT — that is `DailyOrdersService`.

## The mission catalogue. `event` is the counter the service notes, `goal` is
## how much of it completes the mission.
const POOL: Array[Dictionary] = [
	{"id": &"unload", "event": &"transfer", "goal": 60},
	{"id": &"taps", "event": &"tap", "goal": 150},
	{"id": &"ships", "event": &"ship", "goal": 3},
	{"id": &"machines", "event": &"machine", "goal": 10},
	{"id": &"upgrade", "event": &"upgrade", "goal": 1},
	{"id": &"spin", "event": &"spin", "goal": 1},
	{"id": &"gull", "event": &"gull", "goal": 1},
]
const MISSIONS_PER_DAY := 3
## The day number alone seeds the pick: every player sees the same three
## missions on the same day, and a reload never reshuffles them.
const DAY_SEED_MULT := 7919
const DAY_SEED_ADD := 17
## A streak that just reached a multiple of this pays one extra token.
const STREAK_BONUS_EVERY := 7
const MISSION_TOKENS := 1
const BONUS_TOKENS := 1
const BONUS_SURGE_MULT := 3.0
const BONUS_SURGE_SECONDS := 120.0

var day: int = 0
var missions: Array[Dictionary] = []
var bonus_claimed: bool = false
var streak: int = 0
## The last day on which at least one mission was claimed.
var last_active_day: int = 0
var best_streak: int = 0


static func day_key(now_unix: float, utc_offset_seconds: int = 0) -> int:
	## The local calendar day as a number: whole days since the epoch, shifted
	## by the zone's offset, so local midnight is the boundary.
	return int(floor((now_unix + float(utc_offset_seconds)) / 86400.0))


func roll_day(day: int) -> void:
	## Start `day` when it is not the running one. The streak rule lives here:
	## yesterday active means the streak continues, anything older resets it —
	## it grows on the first claim of the day, see `claim`.
	_roll_day(day)


func note(event: StringName, amount: int, day: int) -> void:
	## Count `amount` of `event` toward every unclaimed mission that watches it,
	## clamped to the goal.
	roll_day(day)
	for m in missions:
		if not bool(m.claimed) and StringName(m.get("event", &"")) == event:
			m.progress = clampi(int(m.progress) + amount, 0, int(m.goal))


func claim(index: int, day: int) -> Dictionary:
	## Claim mission `index`: only a complete, unclaimed one pays, exactly once.
	## The first claim of a day grows the streak, and a streak that just reached
	## a multiple of STREAK_BONUS_EVERY pays one extra token.
	roll_day(day)
	if index < 0 or index >= missions.size():
		return {}
	var m: Dictionary = missions[index]
	if bool(m.claimed) or int(m.progress) < int(m.goal):
		return {}
	m.claimed = true
	var reward := {"tokens": MISSION_TOKENS}
	if last_active_day != day:
		streak += 1
		last_active_day = day
		best_streak = maxi(best_streak, streak)
		if streak % STREAK_BONUS_EVERY == 0:
			reward["tokens"] = MISSION_TOKENS + 1
	return reward


func claim_bonus(day: int) -> Dictionary:
	## The all-three bonus — a surge for the port plus a token — once per day.
	roll_day(day)
	if bonus_claimed or missions.is_empty():
		return {}
	for m in missions:
		if not bool(m.claimed):
			return {}
	bonus_claimed = true
	return {
		"surge_mult": BONUS_SURGE_MULT,
		"surge_seconds": BONUS_SURGE_SECONDS,
		"tokens": BONUS_TOKENS,
	}


func claimable_count() -> int:
	## Complete-unclaimed missions, plus the bonus when all three are claimed.
	var n := 0
	var claimed := 0
	for m in missions:
		if bool(m.claimed):
			claimed += 1
		elif int(m.progress) >= int(m.goal):
			n += 1
	if not bonus_claimed and not missions.is_empty() and claimed == missions.size():
		n += 1
	return n


# ----------------------------------------------------------------- persistence

func snapshot() -> Dictionary:
	return {
		"version": 1,
		"day": day,
		"missions": missions.duplicate(true),
		"bonus_claimed": bonus_claimed,
		"streak": streak,
		"last_active_day": last_active_day,
		"best_streak": best_streak,
	}


func restore(data: Dictionary) -> void:
	## Tolerant of missing or garbage keys: a field that does not parse reads as
	## its default, unknown mission ids are dropped, and the day's three
	## missions are always re-rolled from the day number — a save may say how
	## far each mission got, never which missions the day has.
	day = _as_int(data.get("day", 0), 0)
	var raw: Variant = data.get("missions", [])
	var usable := raw is Array and not (raw as Array).is_empty()
	var saved := {}
	if usable:
		for entry in raw as Array:
			if entry is Dictionary:
				var template := _template_by_id(StringName((entry as Dictionary).get("id", &"")))
				if not template.is_empty():
					saved[template.id] = entry
	missions = []
	for template in _roll_missions(day):
		var m := {
			"id": template.id,
			"event": template.event,
			"goal": template.goal,
			"progress": 0,
			"claimed": false,
		}
		if saved.has(template.id):
			var s: Dictionary = saved[template.id]
			m["progress"] = clampi(_as_int(s.get("progress", 0), 0), 0, int(template.goal))
			m["claimed"] = bool(s.get("claimed", false))
		missions.append(m)
	bonus_claimed = usable and bool(data.get("bonus_claimed", false))
	streak = maxi(0, _as_int(data.get("streak", 0), 0))
	last_active_day = _as_int(data.get("last_active_day", 0), 0)
	best_streak = maxi(0, _as_int(data.get("best_streak", 0), 0))


static func seed_new(day: int) -> Dictionary:
	## A new profile starts on `day` with its three fresh missions.
	var orders := DailyOrders.new()
	orders.roll_day(day)
	return orders.snapshot()


static func _roll_missions(day_number: int) -> Array[Dictionary]:
	## The day's three missions: a seeded shuffle of the pool's indices, the
	## first MISSIONS_PER_DAY win. Same day, same three — on every device and
	## after every reload.
	var rng := RandomNumberGenerator.new()
	rng.seed = day_number * DAY_SEED_MULT + DAY_SEED_ADD
	var indices: Array[int] = []
	for i in POOL.size():
		indices.append(i)
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	var picked: Array[Dictionary] = []
	for k in mini(MISSIONS_PER_DAY, indices.size()):
		var template: Dictionary = POOL[indices[k]]
		picked.append({
			"id": template.id,
			"event": template.event,
			"goal": template.goal,
			"progress": 0,
			"claimed": false,
		})
	return picked


func _roll_day(new_day: int) -> void:
	## The body of `roll_day`, under a parameter name that does not shadow the
	## `day` member.
	if new_day <= day and not missions.is_empty():
		return
	day = new_day
	missions = _roll_missions(new_day)
	bonus_claimed = false
	if last_active_day < new_day - 1:
		streak = 0
	# last_active_day == new_day - 1 keeps the streak running; it is incremented
	# when the first mission of the day is claimed (see `claim`).


static func _template_by_id(id: StringName) -> Dictionary:
	for template in POOL:
		if StringName(template.get("id", &"")) == id:
			return template
	return {}


static func _as_int(raw: Variant, fallback: int) -> int:
	if raw is int:
		return raw
	if raw is float:
		return int(raw)
	if raw is String and (raw as String).is_valid_int():
		return (raw as String).to_int()
	return fallback
