class_name SkillBook
extends RefCounted
## The Capataz's three skills: buttons the player presses, each on a recharge.
##
## Until now every bonus in the game was a roll of the dice. These are the
## player's: earned by level, used when *they* choose, and recharged on a clock
## that survives a reload (an absolute wall-clock time, so closing the game does
## not refill them — and an hour away does). Pure rules, the clock passed in.
## What a skill *does* is `SkillService`'s job.

const SKILLS: Array[Dictionary] = [
	{"id": &"skill_overtime", "feature": &"skill_overtime", "cooldown": 300.0,
		"mult": 2.0, "seconds": 30.0},
	{"id": &"skill_mutirao", "feature": &"skill_mutirao", "cooldown": 240.0,
		"seconds": 10.0, "taps_per_second": 10.0},
	{"id": &"skill_pilot", "feature": &"skill_pilot", "cooldown": 480.0,
		"bonus_mult": 3.0},
]

## When each skill is ready again, unix seconds. Absent = ready now.
var ready_at: Dictionary = {}


static func get_skill(id: StringName) -> Dictionary:
	for skill in SKILLS:
		if skill.id == id:
			return skill
	return {}


func is_ready(id: StringName, now_unix: float) -> bool:
	return now_unix >= float(ready_at.get(id, 0.0))


func seconds_left(id: StringName, now_unix: float) -> float:
	return maxf(0.0, float(ready_at.get(id, 0.0)) - now_unix)


func fraction_left(id: StringName, now_unix: float) -> float:
	## 1 right after use, 0 when ready: what the radial overlay draws.
	var skill := get_skill(id)
	if skill.is_empty():
		return 0.0
	return clampf(seconds_left(id, now_unix) / float(skill.cooldown), 0.0, 1.0)


func use(id: StringName, now_unix: float) -> bool:
	## Start the recharge. False for an unknown skill or one still recharging.
	var skill := get_skill(id)
	if skill.is_empty() or not is_ready(id, now_unix):
		return false
	ready_at[id] = now_unix + float(skill.cooldown)
	return true


func reset(id: StringName) -> void:
	## A recharge skipped (the rewarded ad): ready right now.
	ready_at.erase(id)


func snapshot() -> Dictionary:
	var out := {}
	for id in ready_at:
		out[String(id)] = float(ready_at[id])
	return {"version": 1, "ready_at": out}


func restore(data: Dictionary) -> void:
	## A time from the future (a clock set back) is clamped to one full
	## recharge from now at most: it must not lock a skill for years.
	ready_at.clear()
	var raw: Variant = data.get("ready_at", {})
	if not raw is Dictionary:
		return
	var now := Time.get_unix_time_from_system()
	for key in (raw as Dictionary):
		var id := StringName(key)
		var skill := get_skill(id)
		var v: Variant = (raw as Dictionary)[key]
		if skill.is_empty() or not (v is float or v is int):
			continue
		ready_at[id] = minf(float(v), now + float(skill.cooldown))


static func seed_new() -> Dictionary:
	return {"version": 1, "ready_at": {}}
