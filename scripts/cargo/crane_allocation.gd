class_name CraneAllocation
extends RefCounted
## Standing orders: how the bought equipment is divided between the berths.
##
## This exists because automation had stopped being a decision. Every berth was
## being handed the *whole* port's move rate independently, so a second and third
## hull alongside multiplied the same machines by three, and the only question a
## player could ask about their cranes was "how many?". Rule 5 of the design
## principles is that automating a task has to open a higher-order one; this is
## that task, and it is the one a real terminal actually schedules.
##
## The pool is `per_berth_rate x working berths`, so `EQUILIBRIO` divides it back
## out evenly and reproduces the old numbers exactly. Nothing here is a nerf —
## the totals are identical and the default is the old behaviour. What changes is
## that the player may now spend the whole pool on one hull.
##
## Pure and static on purpose: the allocation is a rule, so it is decided here
## and merely obeyed by `PortWorld`.

## Split evenly. Every hull creeps; nothing leaves early.
const EVEN := &"equilibrio"
## Whoever is closest to sailing gets the gang first. Berths free up sooner, so
## more calls are worked per hour and departure bonuses land more often.
const FINISH := &"concluir"
## The biggest hull first. Fewer, larger calls, each worth more.
const BIGGEST := &"maior"

const POLICIES: Array[StringName] = [EVEN, FINISH, BIGGEST]

const LABELS := {
	EVEN: "EQUILÍBRIO",
	FINISH: "CONCLUIR",
	BIGGEST: "MAIOR NAVIO",
}

const BLURBS := {
	EVEN: "A gangue se divide entre todos os berços. Nenhum navio fica parado, nenhum sai antes da hora.",
	FINISH: "Quem está mais perto de zarpar leva a gangue. Mais escalas por hora, mais bônus de partida.",
	BIGGEST: "O maior casco primeiro. Menos escalas, cada uma vale mais.",
}


static func is_policy(id: StringName) -> bool:
	return POLICIES.has(id)


static func coerce(id: StringName) -> StringName:
	## An unknown policy — a save from a future build, a hand-edited file — is the
	## default rather than a crash or a berth that never gets a crane.
	return id if is_policy(id) else EVEN


static func allocate(berths: Array, per_berth_rate: float, policy: StringName,
		cap: float) -> Array[float]:
	## `berths` is one dictionary per berth: {working: bool, progress: float,
	## capacity: float}. Returns one rate per berth, in the same order.
	##
	## `cap` is the per-berth ceiling. Concentrating the pool cannot push a single
	## berth past the rate at which its flights stop being readable, so a policy
	## that would overfill one berth spills the remainder down its own order
	## rather than throwing it away — otherwise "concentrate" would quietly be
	## worse than "spread" the moment the pool exceeded one berth's cap.
	var rates: Array[float] = []
	rates.resize(berths.size())
	rates.fill(0.0)
	var order := _order(berths, policy)
	if order.is_empty():
		return rates
	var pool := per_berth_rate * float(order.size())
	if pool <= 0.0:
		return rates
	if policy == EVEN:
		var share := minf(pool / float(order.size()), cap)
		for index in order:
			rates[index] = share
		return rates
	for index in order:
		if pool <= 0.0:
			break
		var take := minf(pool, cap)
		rates[index] = take
		pool -= take
	return rates


static func _order(berths: Array, policy: StringName) -> Array[int]:
	## The indices of the berths worth feeding, best first. A berth with no hull
	## under the cranes is not in the pool at all: it cannot use a crane, and
	## counting it would dilute the gang into an empty stretch of quay.
	var working: Array[int] = []
	for index in berths.size():
		var berth: Dictionary = berths[index]
		if bool(berth.get("working", false)):
			working.append(index)
	if policy == EVEN or working.size() < 2:
		return working
	# Ties broken by berth index so the same quay always resolves the same way.
	# Without it two identical hulls swap the gang between frames and neither
	# finishes any sooner than sharing would have managed.
	working.sort_custom(func(a: int, b: int) -> bool:
		var left: Dictionary = berths[a]
		var right: Dictionary = berths[b]
		var key_a := _key(left, policy)
		var key_b := _key(right, policy)
		return a < b if is_equal_approx(key_a, key_b) else key_a > key_b)
	return working


static func _key(berth: Dictionary, policy: StringName) -> float:
	var capacity := maxf(1.0, float(berth.get("capacity", 0.0)))
	if policy == BIGGEST:
		return capacity
	# FINISH: the fraction already worked. A hull at 22/24 is two moves from
	# paying a departure bonus; a hull at 1/24 is a whole call away.
	return clampf(float(berth.get("progress", 0.0)) / capacity, 0.0, 1.0)
