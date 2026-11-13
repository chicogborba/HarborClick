class_name TerminalLevel
extends RefCounted
## The rules of Nível do Terminal: the XP curve, the level, and the table of
## what each level unlocks (plano-release 2.3).
##
## Pure rules — no nodes, no autoloads, no clock. The caller feeds it XP;
## deciding how much XP an event is worth is this class's job (the XP_* consts),
## applying anything to the world is NOT — that is `TerminalLevelService`.
##
## XP sources: +1 per container transfer committed, +25 per ship departed,
## +40 per daily mission claimed, +5 per machine bought, +30 per upgrade bought.
##
## The curve is calibrated for an active player doing ~40 transfers/min and
## one ship every 90 s, i.e. 40 + 25/1.5 = 56.7 XP/min from those two alone
## (missions, machines and upgrades on top accelerate a little). At that rate
## the cumulative XP needed to reach each level lands at:
##
## | Level | Cumulative XP | Minutes active |
## |---|---|---|
## | 1  | 0     | 0    |
## | 2  | 116   | ~2   |
## | 3  | 270   | ~5   |
## | 4  | 464   | ~8   |
## | 5  | 696   | ~12  |
## | 6  | 968   | ~17  |
## | 7  | 1278  | ~23  |
## | 8  | 1628  | ~29  |
## | 9  | 2016  | ~36  |
## | 10 | 2444  | ~43  |
## | 11 | 2910  | ~51  |
## | 12 | 3416  | ~60  |
## | ...|       |      |
## | 30 | 19184 | ~338 |

const MAX_LEVEL := 30
## The whole curve stretched for a week of two-hour days: level 30 at ~14 h of
## active play rather than ~5.6 h (the minute table below is the unscaled one;
## multiply its minutes by this).
const XP_SCALE := 2.5

## XP per event, see the class doc.
const XP_PER_TRANSFER := 1
const XP_PER_SHIP_DEPARTED := 25
const XP_PER_MISSION_CLAIMED := 40
const XP_PER_MACHINE := 5
const XP_PER_UPGRADE := 30

## Feature -> the level that unlocks it. A feature not in this table is never
## unlocked. Paced for the week (see `tools/balance/week_report.gd`): a casual
## player — five ten-minute check-ins a day — earns ~2.8k XP a day, so level 8
## lands on day 1, the first rebuild (14) on day 2, and the last unlock (18) on
## day 3, while the economy keeps opening machines and parcels until day 7.
const UNLOCKS: Dictionary = {
	&"shop": 1,
	# The challenges board is there from the first minute: a new port's console
	# had a single real key, and the list of what to do next is the reason to
	# keep tapping.
	&"journal": 1,
	&"objective": 2,
	&"upgrades": 3,
	# Missions come after everything a mission can ask for: one of them is "catch
	# a golden gull" and another "spin the wheel", and the day's three are rolled
	# the same for everyone, so a mission before its feature could be impossible.
	&"gull": 4,
	&"land": 5,
	&"wheel": 6,
	&"daily": 7,
	&"routes": 10,
	&"charters": 12,
	&"events": 12,
	&"prestige": 14,
	&"decor": 16,
	&"orders": 18,
}

## From this level a pass reward may include a wheel token: the wheel itself
## opens at 6, and a token for a wheel the player cannot see is a riddle.
const TOKENS_FROM_LEVEL := 6

## The level the terminal is at, 1..MAX_LEVEL.
var level: int = 1
## The pass: level -> true for every tier whose reward has been collected.
var claimed: Dictionary = {}
## Cumulative XP earned, ever (within this profile — prestige does not reset it).
var xp: int = 0


static func xp_for_level(n: int) -> int:
	## Cumulative XP needed to *reach* level `n` from level 1. Quadratic in
	## k = n-1: 96k + 19.5k², see the table in the class doc. Level 1 is free.
	var k := clampi(n - 1, 0, MAX_LEVEL - 1)
	return int(round(XP_SCALE * (96.0 * k + 19.5 * float(k) * float(k))))


static func level_for_xp(total_xp: int) -> int:
	## The highest level whose requirement the cumulative XP already meets.
	var n := 1
	while n < MAX_LEVEL and xp_for_level(n + 1) <= total_xp:
		n += 1
	return n


func add_xp(amount: int) -> int:
	## Credit `amount` XP and return how many levels were gained (0, or more
	## than one on a big grant). Non-positive amounts change nothing.
	if amount <= 0:
		return 0
	xp += amount
	var new_level := level_for_xp(xp)
	var gained := new_level - level
	level = new_level
	return gained


func progress_to_next() -> float:
	## 0..1 of the current level's bar; a full bar at MAX_LEVEL.
	if level >= MAX_LEVEL:
		return 1.0
	var lo := xp_for_level(level)
	var hi := xp_for_level(level + 1)
	return clampf(float(xp - lo) / float(hi - lo), 0.0, 1.0)


func unlocked(feature: StringName) -> bool:
	## Whether `feature` is available at the current level.
	if not UNLOCKS.has(feature):
		return false
	return level >= int(UNLOCKS[feature])


func unlocks_at(at_level: int) -> Array[StringName]:
	## Every feature the given level unlocks, in a stable order.
	var out: Array[StringName] = []
	for feature in UNLOCKS.keys():
		if int(UNLOCKS[feature]) == at_level:
			out.append(feature)
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


# ------------------------------------------------------------------ the pass
#
# The level is also a pass. Reaching a tier *earns* its reward; the player
# collects it by hand on the track (`LevelRoadmap`), which is the whole point
# of a pass — a row of things waiting with your name on them. Features and
# cosmetics still open by themselves the moment the level is reached: nobody
# should have to find a button to be allowed to use the shop.

static func reward_for(tier: int) -> Dictionary:
	## What tier `tier` pays when collected. Level 1 is where everyone starts
	## and pays nothing. {kind: cash|tokens|surge, minutes?, tokens?, mult?,
	## seconds?} — deciding it is this class's job, paying it the service's.
	if tier <= 1 or tier > MAX_LEVEL:
		return {}
	if tier % 5 == 0:
		# The milestone: a rush on the whole port, and a token once there is
		# a wheel to spend it on.
		return {"kind": &"surge", "mult": 3.0, "seconds": 300.0,
			"tokens": 1 if tier >= 10 else 0}
	if tier % 2 == 0 and tier >= TOKENS_FROM_LEVEL:
		return {"kind": &"tokens", "tokens": 1}
	# A crate of cargo: minutes of the port's own output, more with the tier.
	return {"kind": &"cash", "minutes": 4 + tier / 2}


func can_claim(tier: int) -> bool:
	return tier >= 2 and tier <= level and not claimed.has(tier)


func claimable_tiers() -> Array[int]:
	var out: Array[int] = []
	for tier in range(2, level + 1):
		if not claimed.has(tier):
			out.append(tier)
	return out


func claim(tier: int) -> Dictionary:
	## Collect tier `tier`: its reward, or {} when it is not there to collect.
	if not can_claim(tier):
		return {}
	claimed[tier] = true
	return reward_for(tier)


# ----------------------------------------------------------------- persistence

func snapshot() -> Dictionary:
	var tiers: Array = claimed.keys()
	tiers.sort()
	return {
		"version": 1,
		"level": level,
		"xp": xp,
		"claimed": tiers,
	}


func restore(data: Dictionary) -> void:
	## Tolerant of missing or garbage keys: XP reads as a non-negative int and
	## the level is always derived from it, so a save can never claim a level
	## its XP does not support (in either direction). A save with no XP at all
	## falls back to its stored level.
	if data.has("xp"):
		xp = maxi(0, _as_int(data.get("xp", 0), 0))
	else:
		xp = xp_for_level(clampi(_as_int(data.get("level", 1), 1), 1, MAX_LEVEL))
	level = level_for_xp(xp)
	# A tier above the level cannot have been collected, whatever the file says.
	# A save from before the pass has no list at all: every tier it already
	# reached is waiting on the track, which is the nicest way to meet it.
	claimed.clear()
	var raw: Variant = data.get("claimed", [])
	if raw is Array:
		for entry: Variant in raw:
			var tier := _as_int(entry, 0)
			if tier >= 2 and tier <= level:
				claimed[tier] = true


static func seed_new() -> Dictionary:
	## A new profile starts at level 1 with zero XP.
	return TerminalLevel.new().snapshot()


static func _as_int(raw: Variant, fallback: int) -> int:
	if raw is int:
		return raw
	if raw is float:
		return int(raw)
	if raw is String and (raw as String).is_valid_int():
		return (raw as String).to_int()
	return fallback
