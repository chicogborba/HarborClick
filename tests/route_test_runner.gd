extends Node
## Trade lanes.
## Run with:
## Godot --headless --path . res://tests/route_test_runner.tscn
##
## A route is only worth having if buying it changes something the player can
## see within a couple of calls. Two things have to be true for that: the lane
## has to widen the pool of hulls that turn up, and it has to move the freight
## rate. Both are checked here, along with the rule that keeps a brand new port
## from having no reason for any ship to call at all.

const TEST_SAVE_PATH := "user://harborclick_route_test.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	GameState.from_save({})

	_test_the_data_is_ordered_and_the_home_lane_is_free()
	_test_a_new_port_is_already_on_a_lane()
	_test_buying_a_lane_widens_the_fleet_and_the_freight()
	_test_lanes_open_outward_in_order()
	_test_lanes_survive_a_save()
	_test_every_class_can_actually_be_reached()
	_test_every_pin_is_on_a_real_coast()
	_test_the_standing_order_is_a_real_choice()
	_test_a_lane_is_worth_what_it_pays_not_what_the_best_lane_pays()

	SaveManager.wipe()
	if failures.is_empty():
		print("ROUTE TESTS PASSED (order, home lane, fleet, freight, save)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("ROUTE TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_every_class_can_actually_be_reached() -> void:
	## A lane is the only way a class gets to call here. Adding a hull to the
	## catalogue without adding it to a lane makes a ship nobody can ever see.
	var reachable := {}
	for route: Dictionary in RouteDB.ITEMS:
		for id in route.get("classes", []):
			reachable[str(id)] = true
			_expect(not ShipCatalog.get_silhouette(StringName(id)).is_empty(),
				"lane %s asks for a class that exists (%s)" % [route.id, id])
	for silhouette: Dictionary in ShipCatalog.SILHOUETTES:
		_expect(reachable.has(str(silhouette.id)),
			"%s is on at least one lane, so it can actually call here"
				% silhouette.id)

	# And owning every lane really does put every class in the pool.
	var all_routes := {}
	for route: Dictionary in RouteDB.ITEMS:
		all_routes[str(route.id)] = true
	var pool := RouteDB.class_pool(all_routes)
	_expect(pool.size() == ShipCatalog.SILHOUETTES.size(),
		"a port on every lane can be called by the whole fleet (%d of %d)"
			% [pool.size(), ShipCatalog.SILHOUETTES.size()])


func _test_the_data_is_ordered_and_the_home_lane_is_free() -> void:
	_expect(RouteDB.is_valid(),
		"the route table is well formed: unique ids, rising cost, a free first lane")


func _test_a_new_port_is_already_on_a_lane() -> void:
	GameState.routes.clear()
	var owned := RouteDB.owned(GameState.routes)
	_expect(owned.size() == 1,
		"a port with nothing bought is still on exactly one lane")
	_expect(not RouteDB.class_pool(GameState.routes).is_empty(),
		"that lane brings at least one class, so a ship has a reason to call")
	_expect(is_equal_approx(RouteDB.reward_multiplier(GameState.routes), 1.0),
		"the home lane pays the base freight rate")


func _test_buying_a_lane_widens_the_fleet_and_the_freight() -> void:
	GameState.routes.clear()
	var before_pool := RouteDB.class_pool(GameState.routes)
	var before_rate := RouteDB.reward_multiplier(GameState.routes)

	var next := RouteDB.next_purchase(GameState.routes)
	_expect(not next.is_empty(), "there is a lane available to buy")
	GameState.routes[str(next.id)] = true

	var after_pool := RouteDB.class_pool(GameState.routes)
	_expect(after_pool.size() > before_pool.size(),
		"a new lane brings a class the port did not see before (%d -> %d)"
			% [before_pool.size(), after_pool.size()])
	for silhouette in before_pool:
		_expect(after_pool.has(silhouette),
			"buying a lane never takes an existing class away")
	_expect(RouteDB.reward_multiplier(GameState.routes) > before_rate,
		"a longer lane pays better freight")

	# Owning more lanes must never be worse than owning fewer, which an average
	# would do the moment a short lane sat beside a long one.
	var long_only := {}
	long_only[str(RouteDB.ITEMS[RouteDB.ITEMS.size() - 1].id)] = true
	var both := long_only.duplicate()
	both[str(next.id)] = true
	_expect(RouteDB.reward_multiplier(both)
			>= RouteDB.reward_multiplier(long_only),
		"holding an extra short lane never lowers the freight rate")


func _test_lanes_open_outward_in_order() -> void:
	GameState.routes.clear()
	var seen: Array[String] = []
	for step in RouteDB.ITEMS.size():
		var next := RouteDB.next_purchase(GameState.routes)
		if next.is_empty():
			break
		var id := str(next.id)
		_expect(not seen.has(id), "each lane is offered once")
		seen.append(id)
		GameState.routes[id] = true
	_expect(RouteDB.next_purchase(GameState.routes).is_empty(),
		"once every lane is owned there is nothing left to buy")
	_expect(seen.size() == RouteDB.ITEMS.size() - 1,
		"every paid lane is reachable (%d of %d)"
			% [seen.size(), RouteDB.ITEMS.size() - 1])


func _test_lanes_survive_a_save() -> void:
	GameState.routes.clear()
	GameState.routes["prata"] = true
	GameState.routes["caribe"] = true
	var envelope := GameState.to_save()
	GameState.routes.clear()
	_expect(GameState.routes.is_empty(), "the run is cleared before restoring")
	GameState.from_save(envelope)
	_expect(GameState.routes.has("prata") and GameState.routes.has("caribe"),
		"bought lanes come back after a reload")
	_expect(GameState.routes.size() == 2,
		"a reload does not invent lanes the port never bought")


func _test_the_standing_order_is_a_real_choice() -> void:
	## Owning a lane used to be strictly good: freight was the maximum across
	## everything owned, so a new lane could only raise it and every older lane
	## stopped existing the moment it was bought. Six lanes, one number, nothing
	## to decide. Now each policy has to actually pull in a different direction.
	var lanes := RouteDB.ITEMS
	var richest := RoutePolicy.pick(lanes, RoutePolicy.RICHEST, 0)
	var fastest := RoutePolicy.pick(lanes, RoutePolicy.FASTEST, 0)
	_expect(str(richest.id) != str(fastest.id),
		"the paying lane and the frequent lane are not the same lane")
	for lane: Dictionary in lanes:
		_expect(float(richest.reward) >= float(lane.reward),
			"MAIOR FRETE really takes the best-paying lane")
		_expect(float(fastest.interval) <= float(lane.interval),
			"MAIS ESCALAS really takes the lane that books again soonest")
	# And the trade is genuine in both directions, or one order dominates.
	_expect(float(richest.interval) > float(fastest.interval),
		"the paying lane makes the berth wait longer")
	_expect(float(fastest.reward) < float(richest.reward),
		"and the frequent lane pays less per call")
	# MISTURA has to visit everything rather than settling on one.
	var seen := {}
	for index in lanes.size() * 2:
		seen[str(RoutePolicy.pick(lanes, RoutePolicy.MIX, index).id)] = true
	_expect(seen.size() == lanes.size(), "MISTURA works every lane the port has")
	_expect(RoutePolicy.pick([], RoutePolicy.MIX, 0).is_empty(),
		"a port with no lane books nothing instead of crashing")
	_expect(RoutePolicy.coerce(&"lixo") == RoutePolicy.MIX,
		"a corrupt saved order falls back rather than breaking the berth")


func _test_a_lane_is_worth_what_it_pays_not_what_the_best_lane_pays() -> void:
	## The freight a call pays is the freight of the lane it was booked on. With
	## the old maximum a coastal call paid ocean money.
	# Asserted through `departure_bonus`, not through the getter: the getter can
	# be right while the bonus still reads the global maximum, which is exactly
	# the bug. The port owns every lane here, so under the old rule both calls
	# would pay identically.
	GameState.from_save({})
	for route in RouteDB.ITEMS:
		GameState.routes[str(route.id)] = true
	GameState.owned["estivador"] = 20
	GameState.recompute()
	var controller := BerthCallController.new()
	controller.lane = RouteDB.get_item("cabotagem")
	var coastal := controller.departure_bonus(false)
	controller.lane = RouteDB.get_item("transpacifico")
	var ocean := controller.departure_bonus(false)
	_expect(coastal > 0.0, "a completed coastal call pays something")
	_expect(ocean > coastal * 2.0,
		"an ocean crossing pays several times a coastal run on the same port"
			+ " (%.1f vs %.1f)" % [ocean, coastal])
	controller.lane = {}
	_expect(is_equal_approx(controller.lane_reward(), 1.0),
		"a call with no lane still pays the base rate")
	_expect(controller.departure_bonus(false) > 0.0,
		"and still pays a departure bonus")
	_expect(controller.lane_interval() > 0.0,
		"and still books again instead of leaving the berth empty forever")


func _test_every_pin_is_on_a_real_coast() -> void:
	## The chart and the lane data are the same projection now, so this is
	## checkable rather than a matter of taste: sample the generated world map at
	## each pin and require land within a couple of pixels.
	##
	## Before the map was a sprite these coordinates were eyeballed against
	## hand-drawn polygons and half of them were in open water — the Caribbean
	## lane pinned off Ecuador, the Atlantic crossing pinned in Algeria.
	var map: Image = preload("res://assets/sprites/map_world.png").get_image()
	var pins := {"casa": RouteDB.HOME}
	for route in RouteDB.ITEMS:
		pins[str(route.id)] = route.chart as Vector2
	for id: String in pins:
		var point: Vector2 = pins[id]
		var x := int(round(point.x * float(map.get_width() - 1)))
		var y := int(round(point.y * float(map.get_height() - 1)))
		_expect(_near_land(map, x, y),
			"%s is pinned on a coast, not in open water (%d,%d)" % [id, x, y])


func _near_land(map: Image, x: int, y: int, reach: int = 1) -> bool:
	## The map's deep water is dark and its land is not; a port sits on the line
	## between them, so "on a coast" means land in one of the eight neighbours.
	## One cell is 3.75 degrees — two would let a pin sit 800 km out to sea and
	## still pass, which is how the old coordinates looked fine.
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var sx := clampi(x + dx, 0, map.get_width() - 1)
			var sy := clampi(y + dy, 0, map.get_height() - 1)
			var colour := map.get_pixel(sx, sy)
			# Land is green/tan/white; every water band is blue-dominant.
			if colour.b <= maxf(colour.r, colour.g) + 0.02:
				return true
	return false


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
