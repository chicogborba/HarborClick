class_name RoutePolicy
extends RefCounted
## Standing orders: which lane the port books its next call on.
##
## Buying a lane used to be strictly good and never a choice. `reward_multiplier`
## took the **maximum** freight across everything owned, so a new lane could only
## raise it, the older lanes stopped existing the moment a longer one was bought,
## and the world map was a shopping list with one row on it. Six lanes and one
## number.
##
## A lane is three things now, and they pull against each other:
##
## * `reward` — what a completed call on it pays;
## * `interval` — how long the berth stands empty before that lane books again;
## * `classes` — which hulls it brings, and a bigger hull needs more yard.
##
## So the ocean crossing pays several times the coastal run and leaves the quay
## idle between calls, while the coastal run pays little and never stops. There
## is no dominant answer, which is the whole point: this is the same shape as
## `CraneAllocation`, one step further out.
##
## Pure and static: the choice is a rule, decided here and obeyed by the berth.

## Round-robin across every owned lane. Every lane gets worked, the freight and
## the cadence both average out.
const MIX := &"mistura"
## Always the highest-paying lane the port is on. Fewest calls, biggest hulls,
## most freight per call — and the longest the quay ever stands empty.
const RICHEST := &"frete"
## Always the lane that books again soonest. Small hulls, constant work, the
## departure bonus lands more often.
const FASTEST := &"cadencia"

const POLICIES: Array[StringName] = [MIX, RICHEST, FASTEST]

static func label(policy: StringName) -> String:
	return Loc.t("order.route.%s.label" % coerce(policy))


static func blurb(policy: StringName) -> String:
	return Loc.t("order.route.%s.blurb" % coerce(policy))


static func coerce(policy: Variant) -> StringName:
	var wanted := StringName(str(policy))
	return wanted if POLICIES.has(wanted) else MIX


static func pick(lanes: Array, policy: StringName, call_index: int,
		slots: int = 1) -> Dictionary:
	## Which lane serves the next call. Deterministic in `call_index`, so a save
	## restored mid-turnaround books the same lane it was going to book.
	if lanes.is_empty():
		return {}
	match coerce(policy):
		RICHEST:
			return _rotating_extreme(lanes, "reward", true, call_index, slots)
		FASTEST:
			# Shortest interval, because the interval *is* the wait.
			return _rotating_extreme(lanes, "interval", false, call_index, slots)
		_:
			return lanes[posmod(call_index, lanes.size())]


static func _rotating_extreme(lanes: Array, key: String, highest: bool,
		call_index: int, slots: int) -> Dictionary:
	## The top `slots` lanes by `key`, rotated by the call index. With the extra
	# route slots the capital tree buys, the port works the good lanes in turn
	# instead of camping on the single best one for the rest of the run.
	var sorted := lanes.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var va := float(a.get(key, 0.0))
		var vb := float(b.get(key, 0.0))
		return va > vb if highest else va < vb)
	var n := clampi(slots, 1, sorted.size())
	return sorted[posmod(call_index, n)]
