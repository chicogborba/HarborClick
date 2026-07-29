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

	SaveManager.wipe()
	if failures.is_empty():
		print("ROUTE TESTS PASSED (order, home lane, fleet, freight, save)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("ROUTE TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


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


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
