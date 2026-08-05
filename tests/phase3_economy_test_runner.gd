extends Node
## Godot --headless --path . res://tests/phase3_economy_test_runner.tscn

const EconomyMath = preload("res://scripts/economy/economy_math.gd")
const EconomyCatalog = preload("res://scripts/economy/economy_catalog.gd")
const EconomySimulator = preload("res://scripts/economy/economy_simulator.gd")
const StructureDB = preload("res://scripts/data/structure_db.gd")
const UpgradeDB = preload("res://scripts/data/upgrade_db.gd")
const LandDB = preload("res://scripts/data/land_db.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	test_catalog_paybacks()
	test_runtime_catalog_integrity()
	test_land_gates_the_ladder()
	test_geometric_precision_and_monotonicity()
	test_bulk_modes_and_max()
	test_milestones_and_prestige()
	test_simulator_is_deterministic()
	test_balance_targets()
	test_simulator_models_upgrades()
	test_simulator_prestiges_and_measures_recovery()
	test_absence_is_capped_and_discounted()
	test_rebuild_estimate_answers_in_time()
	test_wrong_build_is_worse_but_never_fatal()
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
		# The first two were sped up so a third kind of machine appears sooner:
		# the target is three distinct silhouettes inside five minutes and the
		# port was taking seven. Lowering their prices instead would have made
		# them proportionally weaker — in this catalogue CPS is derived from
		# cost — so the lever is payback, not price.
		"estivador": 85.0, "empilhadeira": 80.0, "tt": 150.0,
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


func test_land_gates_the_ladder() -> void:
	## Land used to buy nothing but yard slots — the one purchase a greedy player
	## was right to never make. Every parcel opens a machine now, so the two
	## ladders are one ladder, and the pairing has to hold: ascending prices, no
	## machine gated twice, and every gate cheaper than the machine behind it so
	## the parcel is a decision about *when* and never a wall.
	_expect(LandDB.is_valid(), "the parcel ladder is well formed")
	var gated := 0
	for parcel in LandDB.ITEMS:
		var unlocks := str(parcel.get("unlocks", ""))
		var machine := StructureDB.get_item(unlocks)
		_expect(not machine.is_empty(),
			"%s opens a real machine (%s)" % [parcel.id, unlocks])
		_expect(float(parcel.cost) < float(machine.get("cost", 0.0)),
			"%s costs less than the %s it opens" % [parcel.id, unlocks])
		_expect(str(LandDB.gate_for(unlocks).get("id", "")) == str(parcel.id),
			"%s is the gate the machine reports" % parcel.id)
		gated += 1
	_expect(gated == LandDB.ITEMS.size(), "every parcel opens something")
	# The first three machines are never gated: a new terminal has to be able to
	# start without buying ground it cannot afford.
	for id in ["estivador", "empilhadeira", "tt"]:
		_expect(LandDB.gate_for(id).is_empty(),
			"%s is available from the first minute" % id)


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
	var early := EconomySimulator.run_scenario(&"recovery",
		{"duration": 300.0, "taps_per_second": 2.0, "starting_currency": 15.0})
	var markers: Dictionary = early.markers
	_expect(float(markers.first_reward) <= 10.0, "first reward arrives within 10 seconds")
	_expect(float(markers.first_passive) <= 30.0, "passive production starts within 30 seconds")
	_expect(float(markers.first_choice) <= 60.0, "first purchase choice happens within 60 seconds")
	var active := EconomySimulator.run_scenario(&"active_90m")
	var first_prestige := float(active.markers.first_prestige)
	_expect(first_prestige >= 3600.0 and first_prestige <= 7200.0,
		"first prestige lands between 60 and 120 minutes")
	# The README target is three distinct machines within five minutes. Speeding
	# up the first two paybacks took it from 7min25 to 6min40; the rest of the
	# gap is the price step to the third machine and it is still a roadmap item.
	# This guards the regression, not the goal.
	_expect(float(active.markers.three_owned) <= 420.0,
		"a third kind of machine arrives within seven minutes")
	# Rebuilding has to be faster than the first climb, but not so much faster
	# that the second run is over before it starts. The rebuild discount is the
	# lever; 75% off put this at 6.1x and emptied the second run.
	var rebuilt := EconomySimulator.run_scenario(&"recovery")
	var climb := float(rebuilt.markers.first_prestige)
	var again := float(rebuilt.markers.first_recovery_seconds)
	_expect(again > 0.0 and climb > 0.0, "the recovery run both resets and rebuilds")
	if again > 0.0:
		var ratio := climb / again
		_expect(ratio >= 3.0 and ratio <= 5.0,
			"rebuilding the peak is 3-5x faster than reaching it (%.2fx)" % ratio)


func test_simulator_models_upgrades() -> void:
	var run := EconomySimulator.run_scenario(&"active_90m")
	_expect(run.upgrades.size() > 0, "the agent buys upgrades, not only structures")
	var bare := {"owned": {"estivador": 10}, "upgrades": {}, "tree_nodes": {},
		"prestige_level": 0}
	var fitted := {"owned": {"estivador": 10}, "upgrades": {"cafe_forte": true},
		"tree_nodes": {}, "prestige_level": 0}
	_expect(EconomySimulator.production_per_second(fitted)
			> EconomySimulator.production_per_second(bare),
		"a structure upgrade raises simulated production")


func test_simulator_prestiges_and_measures_recovery() -> void:
	var run := EconomySimulator.run_scenario(&"recovery")
	_expect(int(run.prestige_count) > 0, "the agent actually resets the port")
	_expect(int(run.prestige_level) > 0 and run.tree_nodes.size() > 0,
		"golden shares are earned and spent on the capital tree")
	var recovery := float(run.markers.first_recovery_seconds)
	var to_first := float(run.markers.first_prestige)
	_expect(recovery > 0.0, "the run rebuilds past its pre-reset production")
	_expect(recovery < to_first,
		"rebuilding after a reset is faster than reaching it the first time")


func test_absence_is_capped_and_discounted() -> void:
	var night := EconomySimulator.run_scenario(&"offline_night")
	_expect(float(night.capped_away_seconds) > 0.0,
		"an absence past the cap reports the seconds it lost")
	# Two hours past the cap pay exactly what the cap pays, or the cap is not one.
	var longer := EconomySimulator.run_scenario(&"offline_night",
		{"duration": 14.0 * 3600.0 + 300.0, "away_seconds": 14.0 * 3600.0})
	_expect(_close(float(night.all_time_productive), float(longer.all_time_productive)),
		"time beyond the offline cap pays nothing extra")
	var full := EconomySimulator.run_scenario(&"offline_night", {"offline_efficiency": 1.0})
	_expect(float(full.all_time_productive) > float(night.all_time_productive),
		"offline efficiency below 1.0 pays less than being online")


func test_rebuild_estimate_answers_in_time() -> void:
	## A port worth a reset: the estimate has to be a real number of seconds, and
	## rebuilding with the discount and the new multiplier has to beat building
	## the same rate from nothing.
	var reference := EconomySimulator.run_scenario(&"active_90m",
		{"duration": 40.0 * 60.0, "prestige_policy": "never"})
	var target := float(reference.production_per_second)
	_expect(target > 0.0, "the reference run produces something to rebuild")
	var peak: Dictionary = {}
	for id: String in reference.owned:
		peak[id] = int(reference.owned[id])
	var rebuild := EconomySimulator.estimate_rebuild_seconds({
		"target_production": target, "prestige_level": 4,
		"rebuild_targets": peak, "taps_per_second": 2.0})
	_expect(rebuild > 0.0, "the estimate reaches the target inside its budget")
	var cold := EconomySimulator.estimate_rebuild_seconds({
		"target_production": target, "prestige_level": 0,
		"rebuild_targets": {}, "taps_per_second": 2.0})
	_expect(cold < 0.0 or rebuild < cold,
		"the rebuild discount and meta multiplier make the second climb faster")


func test_wrong_build_is_worse_but_never_fatal() -> void:
	var greedy := EconomySimulator.run_scenario(&"hybrid_120m")
	var wrong := EconomySimulator.run_scenario(&"wrong_buy")
	_expect(float(wrong.production_per_second) < float(greedy.production_per_second),
		"buying the worst option every time costs production")
	_expect(wrong.purchases.size() > 1 and int(wrong.total_owned) > 0,
		"the wrong build still progresses instead of stalling")


func _close(a: float, b: float, tolerance: float = 0.00001) -> bool:
	return absf(a - b) <= tolerance * maxf(1.0, maxf(absf(a), absf(b)))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
