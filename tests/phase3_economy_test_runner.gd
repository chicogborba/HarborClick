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
	test_upgrade_graph_is_sound()
	test_exclusive_choices_are_swaps_not_traps()
	test_saturating_bonus_bends_instead_of_stopping()
	test_builds_diverge_and_both_stay_viable()
	test_each_machine_prices_its_own_curve()
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

	# This block used to assert that every `structure_mult` was exactly ×2 and
	# unlocked on exactly its own machine. That was a faithful test of the shelf
	# the catalogue used to be — and the thing item 4 of the plan exists to end.
	# What is checked now is that every node points somewhere real: the ×2 rule is
	# gone deliberately, so asserting it would be asserting the defect.
	var upgrade_ids: Dictionary = {}
	for upgrade in UpgradeDB.ITEMS:
		var upgrade_id := String(upgrade.id)
		_expect(not upgrade_ids.has(upgrade_id), "%s upgrade id is unique" % upgrade_id)
		upgrade_ids[upgrade_id] = true
		for target in UpgradeDB.targets_of(upgrade):
			_expect(structure_ids.has(target),
				"%s targets a valid structure (%s)" % [upgrade_id, target])
		if String(upgrade.get("kind", "")) == "synergy":
			_expect(structure_ids.has(String(upgrade.get("per", ""))),
				"%s counts a valid structure" % upgrade_id)
			_expect(float(upgrade.get("value", 0.0)) > 0.0
				and float(upgrade.get("cap", 0.0)) > 0.0,
				"%s has a positive rate and ceiling" % upgrade_id)
		if String(upgrade.get("kind", "")) == "transform":
			_expect(UpgradeDB.targets_of(upgrade).size() == 1,
				"%s transforms exactly one machine" % upgrade_id)
			_expect(float(upgrade.get("self_mult", 1.0)) < 1.0,
				"%s actually gives something up" % upgrade_id)
		for sid: String in upgrade.get("unlock", {}).get("owned", {}):
			_expect(structure_ids.has(sid),
				"%s unlocks on a valid structure (%s)" % [upgrade_id, sid])
			_expect(int(upgrade.unlock.owned[sid]) > 0,
				"%s owned unlock is positive" % upgrade_id)


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


func test_upgrade_graph_is_sound() -> void:
	## The four ways this data can be wrong without any screen showing it: a
	## dangling `requires`, a one-sided exclusion, a cycle, an unknown trunk. The
	## cycle case is the dangerous one — `depth_of` recurses, so a loop is a hang
	## on the first frame the shop is opened, not a wrong label.
	_expect(UpgradeDB.is_valid(), "the upgrade graph validates")
	for item in UpgradeDB.ITEMS:
		var id := String(item.get("id", ""))
		_expect(UpgradeDB.depth_of(id) >= 0, "%s has a finite depth" % id)
		for parent in UpgradeDB.requires_of(item):
			_expect(not UpgradeDB.get_item(parent).is_empty(),
				"%s requires a node that exists (%s)" % [id, parent])
			_expect(UpgradeDB.depth_of(parent) < UpgradeDB.depth_of(id),
				"%s is drawn below its prerequisite" % id)
		for other in UpgradeDB.excludes_of(item):
			_expect(UpgradeDB.excludes_of(UpgradeDB.get_item(other)).has(id),
				"%s and %s exclude each other both ways" % [id, other])


func test_exclusive_choices_are_swaps_not_traps() -> void:
	## "Cara mas possível" is the requirement, and it has two halves that a single
	## boolean cannot express: the sibling has to actually come off, and the second
	## pick has to cost more than the first did.
	var pair: Array[String] = ["estoque_profundo", "giro_rapido"]
	var first := UpgradeDB.get_item(pair[0])
	var second := UpgradeDB.get_item(pair[1])
	_expect(UpgradeDB.excludes_of(first).has(pair[1]),
		"the yard's deep half excludes the fast half")
	_expect(_close(UpgradeDB.price_for(second, {}), float(second.cost)),
		"a first pick is the list price")
	var owning_first := {pair[0]: true}
	_expect(UpgradeDB.price_for(second, owning_first)
		> float(second.cost) * 2.0,
		"replacing the sibling costs a real surcharge")
	_expect(UpgradeDB.conflicts_with(second, owning_first) == pair.slice(0, 1),
		"the swap names exactly what comes off")
	# The conductors are the same rule expressed as a group rather than a pair, so
	# a terminal can only ever be run by one thing at a time.
	var conductors: Array[String] = []
	for item in UpgradeDB.ITEMS:
		if String(item.get("group", "")) == "conductor":
			conductors.append(String(item.id))
	_expect(conductors.size() >= 3, "there is a real choice of identity")
	for id in conductors:
		var excludes := UpgradeDB.excludes_of(UpgradeDB.get_item(id))
		for other in conductors:
			_expect(other == id or excludes.has(other),
				"%s excludes the other identities (%s)" % [id, other])


func test_saturating_bonus_bends_instead_of_stopping() -> void:
	## The curve every synergy and conductor is paid on. A hard cap put a cliff in
	## the middle of a strategy; this has to start at the rate the card quotes,
	## never stop rewarding another unit, and never reach the ceiling.
	var rate := 0.02
	var ceiling := 3.0
	_expect(_close(EconomyMath.saturating_bonus(rate, ceiling, 0), 0.0),
		"an empty fleet is worth nothing")
	var previous := 0.0
	for count in [1, 5, 25, 100, 400, 5000]:
		var bonus := EconomyMath.saturating_bonus(rate, ceiling, count)
		_expect(bonus > previous, "unit %d is still worth something" % count)
		_expect(bonus < ceiling, "the bonus never reaches its ceiling")
		previous = bonus
	# At small counts it should read as roughly the flat rate the card promises,
	# or the card is lying about the first purchase a player makes.
	_expect(absf(EconomyMath.saturating_bonus(rate, ceiling, 5) - rate * 5.0)
		< rate * 5.0 * 0.15, "the first few units pay about the quoted rate")


func test_builds_diverge_and_both_stay_viable() -> void:
	## Item 4's acceptance, stated as what the sandbox can actually prove.
	##
	## Two agents, identical in every field but which half of the tree they
	## committed to, have to end up strong *for different reasons* and neither may
	## be a trap. What is deliberately **not** asserted is a large difference in
	## fleet headcount: with one shared `1.15^n` curve a ×M multiplier moves a
	## machine's equilibrium count by only ln(M)/ln(1.15) units, so both ports
	## converge on a similar pyramid however they are played. That gap is real and
	## it is written down in the plan rather than papered over here.
	var wide := EconomySimulator.run_scenario(&"build_wide")
	var tall := EconomySimulator.run_scenario(&"build_tall")
	var wide_rate := float(wide.production_per_second)
	var tall_rate := float(tall.production_per_second)
	_expect(wide_rate > 0.0 and tall_rate > 0.0, "both builds produce something")
	var ratio := maxf(wide_rate, tall_rate) / maxf(1.0, minf(wide_rate, tall_rate))
	# The `wrong_buy` benchmark says playing badly costs about 2.4×. A build that
	# cost more than that would not be a strategy, it would be a mistake with a
	# name, so this is the line neither side may cross.
	_expect(ratio < 2.4, "neither build is worse than simply playing badly (%.2fx)"
		% ratio)
	_expect(float(wide.conductor_multiplier) > 1.0
		and float(tall.conductor_multiplier) > 1.0,
		"each build ends up run by an identity it chose")
	var wide_set := {}
	for id in wide.upgrades:
		wide_set[String(id)] = true
	var different := 0
	for id in tall.upgrades:
		if not wide_set.has(String(id)):
			different += 1
	_expect(different >= 2,
		"the two builds ended on genuinely different nodes (%d)" % different)
	# C8 note: per-machine growth curves plus the build plans' cheap/big biases
	# are the levers that make fleet shape a decision; the greedy sandbox still
	# ends both builds owning every kind, so composition_distance stays small
	# (~0.005) and is measured here, not asserted — asserting a large value
	# would be papering over what the sandbox can actually prove. The mechanism
	# itself (each machine pricing its own curve) is asserted below.
	var distance := EconomySimulator.composition_distance(wide.owned, tall.owned)
	print("[economy] composition_distance wide vs tall: %.3f" % distance)


func test_each_machine_prices_its_own_curve() -> void:
	## C8: `growth` is per machine, and the price the shop charges follows it.
	var cheap := StructureDB.cost_for("estivador", 10)
	var store := StructureDB.cost_for("armazem", 10)
	var base_cheap: float = StructureDB.get_item("estivador").cost
	var base_store: float = StructureDB.get_item("armazem").cost
	_expect(is_equal_approx(cheap, base_cheap * pow(1.15, 10.0)),
		"estivador prices on its own 1.15 curve")
	_expect(is_equal_approx(store, base_store * pow(1.14, 10.0)),
		"armazem prices on its own 1.14 curve")
	_expect(cheap / base_cheap > store / base_store,
		"the cheap labour saturates faster than the warehouse")
	var grew := 0
	for item in StructureDB.ITEMS:
		if float(item.get("growth", 1.15)) != 1.15:
			grew += 1
	_expect(grew >= 10, "most machines moved off the shared 1.15 curve (%d of %d)"
		% [grew, StructureDB.ITEMS.size()])


func _close(a: float, b: float, tolerance: float = 0.00001) -> bool:
	return absf(a - b) <= tolerance * maxf(1.0, maxf(absf(a), absf(b)))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
