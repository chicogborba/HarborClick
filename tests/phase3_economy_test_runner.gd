extends Node
## Godot --headless --path . res://tests/phase3_economy_test_runner.tscn

const EconomyMath = preload("res://scripts/economy/economy_math.gd")
const EconomyCatalog = preload("res://scripts/economy/economy_catalog.gd")
const EconomySimulator = preload("res://scripts/economy/economy_simulator.gd")
const StructureDB = preload("res://scripts/data/structure_db.gd")
const UpgradeDB = preload("res://scripts/data/upgrade_db.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	test_catalog_paybacks()
	test_runtime_catalog_integrity()
	test_geometric_precision_and_monotonicity()
	test_bulk_modes_and_max()
	test_milestones_and_prestige()
	test_simulator_is_deterministic()
	test_balance_targets()
	if failures.is_empty():
		print("PHASE 3 ECONOMY TESTS PASSED")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func test_catalog_paybacks() -> void:
	for item in EconomyCatalog.all():
		_expect(_close(float(item.base_cost), float(item.cps) * float(item.payback)), "%s base cost derives from CPS × payback" % item.id)


func test_runtime_catalog_integrity() -> void:
	var paybacks := {
		"estivador": 120.0, "empilhadeira": 110.0, "tt": 150.0,
		"reach_stacker": 180.0, "rtg": 240.0, "sts": 300.0,
		"armazem": 360.0, "rebocador": 450.0, "trem": 600.0,
		"flutuante": 720.0, "alfandega": 900.0, "torre": 1200.0,
		"drone": 1500.0, "porto_ia": 1800.0, "portal": 2400.0,
	}
	var catalog_by_id: Dictionary = {}
	for item in EconomyCatalog.all():
		catalog_by_id[item.id] = item
	var structure_ids: Dictionary = {}
	for structure in StructureDB.ITEMS:
		var structure_id := String(structure.id)
		_expect(not structure_ids.has(structure_id), "%s structure id is unique" % structure_id)
		structure_ids[structure_id] = true
		_expect(catalog_by_id.has(structure_id), "%s exists in EconomyCatalog" % structure_id)
		_expect(paybacks.has(structure_id), "%s has a payback target" % structure_id)
		if paybacks.has(structure_id):
			_expect(_close(float(structure.cost) / float(structure.cps), float(paybacks[structure_id])), "%s preserves its target payback" % structure_id)
	_expect(structure_ids.size() == catalog_by_id.size(), "runtime structures cover every EconomyCatalog id")

	var upgrade_ids: Dictionary = {}
	for upgrade in UpgradeDB.ITEMS:
		var upgrade_id := String(upgrade.id)
		_expect(not upgrade_ids.has(upgrade_id), "%s upgrade id is unique" % upgrade_id)
		upgrade_ids[upgrade_id] = true
		if String(upgrade.kind) == "structure_mult":
			var target := String(upgrade.get("target", ""))
			_expect(structure_ids.has(target), "%s targets a valid structure" % upgrade_id)
			_expect(_close(float(upgrade.value), 2.0), "%s doubles its structure CPS" % upgrade_id)
			var unlock: Dictionary = upgrade.get("unlock", {})
			var owned_unlock: Dictionary = unlock.get("owned", {})
			_expect(owned_unlock.size() == 1 and owned_unlock.has(target), "%s unlock targets its structure" % upgrade_id)
			if owned_unlock.has(target):
				_expect(int(owned_unlock[target]) > 0, "%s owned unlock is positive" % upgrade_id)


func test_geometric_precision_and_monotonicity() -> void:
	var expected := 15.0 * (pow(1.15, 10.0) - 1.0) / 0.15
	_expect(_close(EconomyMath.bulk_cost(15.0, 0, 10), expected), "closed-form x10 matches geometric series")
	_expect(_close(EconomyMath.bulk_cost(15.0, 10, 0), 0.0), "zero quantity costs nothing")
	var previous := 0.0
	for amount in range(1, 101):
		var cost := EconomyMath.bulk_cost(100.0, 7, amount)
		_expect(cost > previous, "bulk cost is strictly monotonic at %d" % amount)
		previous = cost


func test_bulk_modes_and_max() -> void:
	var base := 15.0
	var x1: Dictionary = EconomyMath.purchase_cost(base, 3, &"x1")
	var x10: Dictionary = EconomyMath.purchase_cost(base, 3, &"x10")
	var x25: Dictionary = EconomyMath.purchase_cost(base, 3, &"x25")
	_expect(x1.amount == 1 and x10.amount == 10 and x25.amount == 25, "x1/x10/x25 preserve requested quantity")
	_expect(float(x1.cost) < float(x10.cost) and float(x10.cost) < float(x25.cost), "bulk modes have increasing costs")
	var budget := EconomyMath.bulk_cost(base, 3, 37)
	var max_quote: Dictionary = EconomyMath.purchase_cost(base, 3, &"max", budget)
	_expect(max_quote.amount == 37, "MAX finds exact affordable amount")
	_expect(EconomyMath.bulk_cost(base, 3, int(max_quote.amount) + 1) > budget, "MAX cannot afford one more")
	_expect(EconomyMath.max_affordable(1.0, 0, 1e300, EconomyMath.GROWTH, 1000) == 1000, "MAX stays bounded for enormous balances")


func test_milestones_and_prestige() -> void:
	_expect(EconomyMath.milestone_multiplier(9) == 1.0 and EconomyMath.milestone_multiplier(10) == 2.0, "first milestone doubles production")
	_expect(EconomyMath.milestone_multiplier(100) == 16.0, "all four milestones stack")
	_expect(_close(EconomyMath.purchase_cps_gain(1.0, 9, 1), 11.0), "milestone purchase includes retroactive impact")
	_expect(EconomyMath.prestige_potential(99999999.0) == 0 and EconomyMath.prestige_potential(100000000.0) == 1, "prestige potential uses floor sqrt threshold")
	_expect(_close(EconomyMath.prestige_multiplier(4), 1.1), "meta multiplier follows square-root level")


func test_simulator_is_deterministic() -> void:
	var first := EconomySimulator.run_scenario(&"hybrid_120m")
	var second := EconomySimulator.run_scenario(&"hybrid_120m")
	_expect(first == second, "same scenario yields byte-for-byte equivalent result")
	_expect(_close(float(first.elapsed_seconds), 7200.0), "simulator honors configured duration")


func test_balance_targets() -> void:
	var early := EconomySimulator.run_scenario(&"recovery", {"duration": 300.0, "active_cps": 2.0, "starting_currency": 15.0})
	var markers: Dictionary = early.markers
	_expect(float(markers.first_reward) <= 10.0, "first reward arrives within 10 seconds")
	_expect(float(markers.first_passive) <= 30.0, "passive production starts within 30 seconds")
	_expect(float(markers.first_choice) <= 60.0, "first purchase choice happens within 60 seconds")
	_expect(float(markers.three_owned) <= 300.0, "three structures arrive within five minutes")
	var active := EconomySimulator.run_scenario(&"active_90m")
	var first_prestige := float(active.markers.first_prestige)
	_expect(first_prestige >= 3600.0 and first_prestige <= 7200.0, "first prestige lands between 60 and 120 minutes")
	var wrong := EconomySimulator.run_scenario(&"wrong_buy")
	var recovery := EconomySimulator.run_scenario(&"recovery")
	_expect(wrong.purchases.size() > 1 and recovery.purchases.size() > 1, "wrong-buy and recovery scenarios continue purchasing")


func _close(a: float, b: float, tolerance: float = 0.00001) -> bool:
	return absf(a - b) <= tolerance * maxf(1.0, maxf(absf(a), absf(b)))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
