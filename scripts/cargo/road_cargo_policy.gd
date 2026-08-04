class_name RoadCargoPolicy
extends RefCounted
## Pure road/yard policy. Keeping these invariants outside the animated gate
## makes them testable without a scene and gives every road actor one contract.

const MIN_OPERATIONAL_STOCK := PortLayout.SHIP_BAY_COLS * PortLayout.SHIP_BAY_ROWS


static func trip_plan(fill_ratio: float, target_fill: float,
		truck_capacity: int) -> Dictionary:
	## A normal trip is never inventory-negative:
	## - below target: two arrive, at most one leaves (net +1);
	## - at/above target: one arrives and one leaves (net 0).
	##
	## The balanced 1-for-1 trip also works in a full yard: lifting first opens
	## the exact slot where its city box can then land.
	var restocking := fill_ratio < target_fill
	return {
		"drops": maxi(1, truck_capacity) if restocking else 1,
		"lifts": 1,
	}


static func is_non_deficit(plan: Dictionary) -> bool:
	return int(plan.get("drops", 0)) >= int(plan.get("lifts", 0))
