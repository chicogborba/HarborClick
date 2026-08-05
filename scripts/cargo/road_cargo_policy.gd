class_name RoadCargoPolicy
extends RefCounted
## Pure road/yard policy. Keeping these invariants outside the animated gate
## makes them testable without a scene and gives every road actor one contract.

const MIN_OPERATIONAL_STOCK := PortLayout.SHIP_BAY_COLS * PortLayout.SHIP_BAY_ROWS
## Above this share of the yard the road stops delivering and starts clearing.
##
## Every plan used to be inventory-neutral or better, which sounded like a safe
## invariant and was in fact a deadlock: a full import yard refuses a landing, a
## refused landing blocks the discharge, and a road that can only ever exchange
## one for one never opens the slot that would unblock it. The port could reach a
## state where no tap was legal and nothing on the map would ever change it.
##
## Draining is safe because the floor is enforced at the pickup, not here:
## `ContainerYard.road_pickup_slot` refuses to lift below `MIN_OPERATIONAL_STOCK`,
## so the road can clear a jam but can never starve the next ship.
const DRAIN_FILL := 0.94


static func trip_plan(fill_ratio: float, target_fill: float,
		truck_capacity: int) -> Dictionary:
	## Three bands:
	## - below target: two arrive, at most one leaves (net +1);
	## - between target and `DRAIN_FILL`: one arrives and one leaves (net 0);
	## - at/above `DRAIN_FILL`: one arrives and a full chassis leaves (net -1).
	##
	## The clearing run still brings a box, because no truck crosses the gate
	## bare in either direction — that is the gate's own visual contract.
	##
	## The balanced 1-for-1 trip also works in a nearly full yard: lifting first
	## opens the exact slot where its city box can then land.
	if fill_ratio >= DRAIN_FILL:
		return {"drops": 1, "lifts": maxi(2, truck_capacity)}
	var restocking := fill_ratio < target_fill
	return {
		"drops": maxi(1, truck_capacity) if restocking else 1,
		"lifts": 1,
	}


static func is_non_deficit(plan: Dictionary) -> bool:
	return int(plan.get("drops", 0)) >= int(plan.get("lifts", 0))


static func is_draining(plan: Dictionary) -> bool:
	## A clearing run. It is the only plan allowed to take more than it brings,
	## and only because the yard has no room left to work a ship.
	return int(plan.get("lifts", 0)) > int(plan.get("drops", 0))
