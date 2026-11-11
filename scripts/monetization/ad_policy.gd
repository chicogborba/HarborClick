class_name AdPolicy
extends RefCounted
## The rules of rewarded ads: which placements exist, how many may be watched
## per local day, and how long to wait between two of the same placement.
##
## Pure rules — no nodes, no autoloads, no clock of its own. Every moment is
## passed in as `now_unix` and every local day as `day` (the same day number
## `DailyOrders.day_key` produces), so a suite can fake both midnight and the
## wall clock. Whether an ad is *shown* is the provider's job (`AdProvider`);
## whether one *may* be shown is this class's.

## id -> {daily_cap, cooldown}. `daily_cap` 0 means unlimited for the day;
## `cooldown` 0.0 means no wait between two shows.
const PLACEMENTS: Dictionary = {
	&"wheel_spin": {"daily_cap": 3, "cooldown": 1800.0},
	&"wheel_double": {"daily_cap": 0, "cooldown": 0.0},
	&"minigame_retry": {"daily_cap": 0, "cooldown": 0.0},
	&"minigame_play": {"daily_cap": 3, "cooldown": 0.0},
	&"build_speed": {"daily_cap": 0, "cooldown": 30.0},
	&"offline_double": {"daily_cap": 0, "cooldown": 0.0},
	&"gull_double": {"daily_cap": 0, "cooldown": 0.0},
	&"mission_reroll": {"daily_cap": 1, "cooldown": 0.0},
	&"boost_2x": {"daily_cap": 6, "cooldown": 0.0},
	## The level-up card's offer: one per level, so the level itself is the cap;
	## the cooldown only stops two queued levels from stacking two offers.
	&"level_bonus": {"daily_cap": 0, "cooldown": 20.0},
}

## The `last_unix` a placement starts with: far enough back that no real or
## test clock is ever inside a cooldown that was never started. JSON has no
## infinity, so the sentinel is a finite, absurdly old timestamp instead.
const NEVER := -1.0e12
## Upper clamp for a restored `last_unix`: a garbage future timestamp must not
## park a placement on cooldown until the year 33000.
const LAST_UNIX_MAX := 1.0e12

## The local day the counters below belong to.
var day: int = 0
## The "Passe Sem Anúncios" hook: when true the caps and cooldowns below still
## apply, but `AdService` skips the provider and pays the reward straight away.
var no_ads_pass: bool = false
## id -> {"count": int, "last_unix": float} — shows today and the last show.
var _state: Dictionary = {}


func can_show(id: StringName, now_unix: float, day: int) -> bool:
	## May `id` be shown at `now_unix` on local `day`? Unknown placements never
	## may. `no_ads_pass` does not change this answer — the caps still apply.
	_roll_day(day)
	var rule: Dictionary = PLACEMENTS.get(id, {})
	if rule.is_empty():
		return false
	var st := _state_for(id)
	var cap := int(rule.get("daily_cap", 0))
	if cap > 0 and int(st.count) >= cap:
		return false
	return seconds_until(id, now_unix, day) <= 0.0


func seconds_until(id: StringName, now_unix: float, day: int) -> float:
	## Seconds left of `id`'s cooldown at `now_unix`; 0 when there is none to
	## wait out (or the placement is unknown).
	_roll_day(day)
	var rule: Dictionary = PLACEMENTS.get(id, {})
	if rule.is_empty():
		return 0.0
	var cooldown := float(rule.get("cooldown", 0.0))
	if cooldown <= 0.0:
		return 0.0
	var st := _state_for(id)
	var last := float(st.last_unix)
	# A stamp from the future is a clock that was set back (or a damaged save),
	# not a reason to lock the placement for years: read it as never shown.
	if last > now_unix:
		return 0.0
	return maxf(0.0, cooldown - (now_unix - last))


func remaining_today(id: StringName, day: int) -> int:
	## Shows left for `id` on local `day`; -1 when the placement is unlimited.
	_roll_day(day)
	var rule: Dictionary = PLACEMENTS.get(id, {})
	if rule.is_empty():
		return 0
	var cap := int(rule.get("daily_cap", 0))
	if cap <= 0:
		return -1
	return maxi(0, cap - int(_state_for(id).count))


func note_shown(id: StringName, now_unix: float, day: int) -> void:
	## One show of `id` happened at `now_unix` on local `day`. Called only for a
	## rewarded show — a failed or skipped ad does not spend the daily cap.
	_roll_day(day)
	if not PLACEMENTS.has(id):
		return
	var st := _state_for(id)
	st.count = int(st.count) + 1
	st.last_unix = now_unix


# ----------------------------------------------------------------- persistence

func snapshot() -> Dictionary:
	var state := {}
	for id in _state.keys():
		var st: Dictionary = _state[id]
		state[String(id)] = {"count": int(st.count), "last_unix": float(st.last_unix)}
	return {
		"version": 1,
		"day": day,
		"no_ads_pass": no_ads_pass,
		"state": state,
	}


func restore(data: Dictionary) -> void:
	## Tolerant of missing or garbage keys: a field that does not parse reads
	## as its default, unknown placements are dropped, and a count above the
	## cap (or a timestamp from the future) is clamped rather than trusted.
	day = _as_int(data.get("day", 0), 0)
	no_ads_pass = bool(data.get("no_ads_pass", false))
	_state.clear()
	var raw: Variant = data.get("state", {})
	if raw is Dictionary:
		for key in (raw as Dictionary).keys():
			var id := StringName(key)
			if not PLACEMENTS.has(id):
				continue
			var entry: Variant = (raw as Dictionary)[key]
			if not entry is Dictionary:
				continue
			var e: Dictionary = entry
			var cap := int(PLACEMENTS[id].get("daily_cap", 0))
			var count := _as_int(e.get("count", 0), 0)
			count = clampi(count, 0, cap) if cap > 0 else maxi(0, count)
			_state[id] = {
				"count": count,
				"last_unix": clampf(_as_float(e.get("last_unix", NEVER), NEVER),
					NEVER, LAST_UNIX_MAX),
			}


static func seed_new(day: int) -> Dictionary:
	## A new profile starts on `day` with every placement untouched.
	return {"version": 1, "day": day, "no_ads_pass": false, "state": {}}


# -------------------------------------------------------------------- internal

func _roll_day(new_day: int) -> void:
	## A later local day zeroes every daily counter. `last_unix` survives the
	## rollover, so a cooldown that spans midnight still counts.
	if new_day <= day:
		return
	day = new_day
	for id in _state.keys():
		_state[id].count = 0


func _state_for(id: StringName) -> Dictionary:
	if not _state.has(id):
		_state[id] = {"count": 0, "last_unix": NEVER}
	return _state[id]


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
