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

const LABELS := {
	MIX: "MISTURA",
	RICHEST: "MAIOR FRETE",
	FASTEST: "MAIS ESCALAS",
}

const BLURBS := {
	MIX: "As rotas se revezam. Frete e cadência ficam na média de tudo que o porto tem.",
	RICHEST: "Sempre a rota que paga mais. Cascos maiores, menos escalas, berço parado por mais tempo.",
	FASTEST: "Sempre a rota que volta antes. Cascos pequenos, trabalho constante, bônus de partida mais vezes.",
}


static func coerce(policy: Variant) -> StringName:
	var wanted := StringName(str(policy))
	return wanted if POLICIES.has(wanted) else MIX


static func pick(lanes: Array, policy: StringName, call_index: int) -> Dictionary:
	## Which lane serves the next call. Deterministic in `call_index`, so a save
	## restored mid-turnaround books the same lane it was going to book.
	if lanes.is_empty():
		return {}
	match coerce(policy):
		RICHEST:
			return _extreme(lanes, "reward", true)
		FASTEST:
			# Shortest interval, because the interval *is* the wait.
			return _extreme(lanes, "interval", false)
		_:
			return lanes[posmod(call_index, lanes.size())]


static func _extreme(lanes: Array, key: String, highest: bool) -> Dictionary:
	var best: Dictionary = lanes[0]
	for lane: Dictionary in lanes:
		var value := float(lane.get(key, 0.0))
		var incumbent := float(best.get(key, 0.0))
		if value > incumbent if highest else value < incumbent:
			best = lane
	return best
