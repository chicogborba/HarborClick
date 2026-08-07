class_name RailCargoPolicy
extends RefCounted
## Pure rail/yard policy: how long a rake is, and what one service does to the
## terminal's stock.
##
## The road and the branch line are the same kind of door — land-side, off-map,
## round trip — so they answer to the same invariant: a service may add stock or
## exchange it one for one, and may only take more than it brings when the yard
## is so full that nothing else can unblock it. What differs is scale. A chassis
## carries two boxes and comes back in a quarter of a minute; a rake carries a
## dozen and comes back when the interior has filled it again.
##
## Keeping this outside `RailYard` is what lets the arithmetic be tested without
## a scene, a train, or a frame of animation.

## The floor is the road's floor. There is one terminal and one stock of boxes;
## two land-side channels with two different ideas of "enough" would let the
## quieter one starve the ship the busier one just protected.
const MIN_OPERATIONAL_STOCK := RoadCargoPolicy.MIN_OPERATIONAL_STOCK
const DRAIN_FILL := RoadCargoPolicy.DRAIN_FILL

## Wagons in a rake. The branch line is a bought structure: without it the
## terminal is still on the network, but it gets a short trip freight rather
## than a block train.
const SHORT_RAKE := 3
const FULL_RAKE := 6

## --- standing orders -------------------------------------------------------
## What the branch is *for*.
##
## The gang has `CraneAllocation` and the world map has `RoutePolicy`. This is
## the same question asked about the third door, and it is the one thing about
## the railway the player actually decides: a booked service is not a thing you
## tap, it is a thing you brief. Without this the branch was a weather system —
## it happened to you on a timer and the only input was tapping wagons faster.
##
## An order biases the exchange. It may not break the two rules that keep the
## terminal alive:
##
## - every service still brings at least one box, in every band and every order;
## - a yard with no room left to work a ship still gets its clearing service,
##   whatever the order says.
##
## The second is why `DRAIN_FILL` is checked before the order is even read. An
## order the player can deadlock their own port with is not a decision, it is a
## trap, and the drain band exists precisely to break that deadlock.
const ORDER_BALANCED := &"equilibrio"
const ORDER_SUPPLY := &"abastecer"
const ORDER_CLEAR := &"escoar"

const ORDERS: Array[StringName] = [ORDER_BALANCED, ORDER_SUPPLY, ORDER_CLEAR]

const ORDER_LABELS := {
	ORDER_BALANCED: "EQUILÍBRIO",
	ORDER_SUPPLY: "ABASTECER",
	ORDER_CLEAR: "ESCOAR",
}

const ORDER_BLURBS := {
	ORDER_BALANCED:
		"O ramal segue o pátio: enche quando falta, troca quando basta.",
	ORDER_SUPPLY:
		"O interior manda o trem cheio e leva o mínimo. O estoque sobe depressa, e navio parado por falta de carga deixa de acontecer.",
	ORDER_CLEAR:
		"Todo vagão trabalha nos dois sentidos: o dobro de movimentos por escala. Rende mais na mão, mas o pátio não cresce com isso.",
}


static func is_order(id: StringName) -> bool:
	return ORDERS.has(id)


static func coerce_order(id: StringName) -> StringName:
	## An unknown order — a save from a future build, a hand-edited file — is the
	## default rather than a crash or a branch that never books anything.
	return id if is_order(id) else ORDER_BALANCED


static func rake_length(has_branch: bool) -> int:
	return FULL_RAKE if has_branch else SHORT_RAKE


static func service_plan(fill_ratio: float, target_fill: float,
		rake_length: int, order: StringName = ORDER_BALANCED) -> Dictionary:
	## What one service exchanges.
	##
	## `EQUILIBRIO` is the road's three bands, scaled to a train:
	## - below target: the rake arrives full and goes back half empty (net +);
	## - between target and `DRAIN_FILL`: half and half (net 0);
	## - at/above `DRAIN_FILL`: one box in, the whole rake out (net −).
	##
	## The other two orders trade one of those axes away for the other, which is
	## what makes them a choice rather than a difficulty setting:
	## - `ABASTECER` runs the rake in full and takes a token load back, so stock
	##   climbs about as fast as a train can carry it and the ramp is cheap to
	##   work — but the branch stops being a way of *earning* on the way out;
	## - `ESCOAR` works every wagon in both directions, which is twice the moves
	##   and twice the pay for the same booked path, and leaves the yard exactly
	##   where it found it.
	##
	## No service is ever an empty train in either direction. A rake that ran in
	## light and out light would be a very expensive way of showing the player
	## nothing, and the drop is the door that opens when the yard is empty exactly
	## as the lift is the door that opens when it is full.
	var wagons := maxi(1, rake_length)
	@warning_ignore("integer_division")
	var half: int = maxi(1, wagons / 2)
	@warning_ignore("integer_division")
	var token: int = maxi(1, wagons / 4)
	# Before the order, not after it. See the note on the orders above.
	if fill_ratio >= DRAIN_FILL:
		return {"drops": 1, "lifts": wagons}
	match coerce_order(order):
		ORDER_SUPPLY:
			return {"drops": wagons, "lifts": token}
		ORDER_CLEAR:
			return {"drops": wagons, "lifts": wagons}
		_:
			if fill_ratio < target_fill:
				return {"drops": wagons, "lifts": half}
			return {"drops": half, "lifts": half}


static func is_non_deficit(plan: Dictionary) -> bool:
	return int(plan.get("drops", 0)) >= int(plan.get("lifts", 0))


static func is_draining(plan: Dictionary) -> bool:
	return int(plan.get("lifts", 0)) > int(plan.get("drops", 0))


static func service_gap(has_branch: bool) -> Vector2:
	## Seconds between services. The branch is the upgrade that turns an
	## occasional trip freight into a shuttle, so the thing the player buys is a
	## line that is actually busy rather than a longer train they see as rarely.
	return Vector2(46.0, 74.0) if has_branch else Vector2(150.0, 230.0)
