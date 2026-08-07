extends Node
## Berth automation and the departure bonus.
## Run with:
## Godot --headless --path . res://tests/automation_test_runner.tscn
##
## Automation is the one feature that can quietly break the cargo contract: it
## moves containers without a finger on the screen, so if it took a different
## code path from a tap it could create or lose a UID where nothing was
## watching. It does not — it calls the very same transaction — and that is
## what this proves, along with the bonus staying inside its band.

const TEST_SAVE_PATH := "user://harborclick_automation_test.json"
const STEP := 1.0 / 30.0
## The class alongside decides how big a call is, so the suite asks the ship.

var failures: Array[String] = []
var _world: AutoTestWorld


class AutoTestShip:
	extends Ship

	func arrive(_open_channel: bool = true) -> void:
		visible = true
		position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y)
		_set_phase(Ship.Phase.DISCHARGING)


class AutoTestWorld:
	extends PortWorld

	var _sheet: Texture2D = preload("res://assets/sprites/container_sheet.png")

	func _ready() -> void:
		entities = Node2D.new()
		add_child(entities)
		overhead = Node2D.new()
		add_child(overhead)
		yard = ContainerYard.new()
		entities.add_child(yard)
		ship = AutoTestShip.new()
		add_child(ship)
		traffic = TrafficCoordinator.new()
		berth = BerthCallController.new()
		berth.setup(self, ship, yard)

	func fly_cargo(color: int, from: Vector2, to: Vector2) -> FlyingContainer:
		var flight := FlyingContainer.new()
		flight.setup(_sheet, color, from, to)
		overhead.add_child(flight)
		return flight

	func show_cargo_reward(_pos: Vector2, _value: float, _crit: bool) -> void:
		pass

	func spawn_dust(_pos: Vector2) -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	GameState.from_save({})
	seed(4242)

	_world = AutoTestWorld.new()
	add_child(_world)
	await get_tree().process_frame
	_world.berth.seed_new(4242)
	_deliver_road_exports(_world.ship.bay_capacity())
	_world.ship.arrive()
	await get_tree().process_frame

	_test_rate_follows_the_equipment_bought()
	await _test_a_full_call_completes_without_a_single_tap()
	_test_departure_bonus_stays_in_its_band()
	_test_the_rail_gantry_only_works_a_train_that_is_there()
	_test_standing_orders_divide_one_gang()
	_test_standing_orders_survive_a_reload()
	_test_the_foreman_respects_the_reserve()
	_test_the_foreman_is_earned_and_persisted()

	SaveManager.wipe()
	if failures.is_empty():
		print("AUTOMATION TESTS PASSED (rate, hands-off call, bonus band, orders, foreman)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("AUTOMATION TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_rate_follows_the_equipment_bought() -> void:
	GameState.owned.clear()
	GameState.recompute()
	_expect(is_zero_approx(_world.berth.auto_rate()),
		"a terminal with no gantries moves nothing on its own")
	GameState.owned["estivador"] = 50
	GameState.recompute()
	_expect(is_zero_approx(_world.berth.auto_rate()),
		"yard-only equipment does not work the berth")
	GameState.owned["sts"] = 4
	GameState.recompute()
	_expect(_world.berth.auto_rate() > 0.0,
		"portainers work the berth")
	GameState.owned["sts"] = 10000
	GameState.recompute()
	_expect(is_equal_approx(_world.berth.auto_rate(),
			BerthCallController.AUTO_RATE_CAP),
		"the automatic rate is capped rather than becoming an unreadable smear")


func _test_a_full_call_completes_without_a_single_tap() -> void:
	GameState.owned.clear()
	GameState.owned["sts"] = 6
	GameState.recompute()
	var departures: Array[Dictionary] = []
	_world.berth.call_completed.connect(
		func(summary: Dictionary) -> void: departures.append(summary))

	# Flights are real nodes that need real frames to land, so this runs on the
	# wall clock rather than on a simulated step: no input at all, just time.
	var deadline := Time.get_ticks_msec() + 90000
	while departures.is_empty() and Time.get_ticks_msec() < deadline:
		_world.berth.tick(get_process_delta_time())
		await get_tree().process_frame

	_expect(not departures.is_empty(),
		"equipment alone finishes a call — no tap required")
	if departures.is_empty():
		return
	var summary: Dictionary = departures[0]
	var uids := {}
	for snapshot: Dictionary in summary.get("exports", []):
		var uid := str(snapshot.get("uid", ""))
		_expect(not uids.has(uid), "automation never ships a duplicate UID")
		uids[uid] = true
	var capacity := _world.ship.bay_capacity()
	_expect(uids.size() == capacity,
		"an automated call still departs with a full deck (%d of %d)"
			% [uids.size(), capacity])
	var imports := {}
	for uid: String in _world.ship.import_manifest_uids():
		imports[uid] = true
	var recycled := 0
	for uid: String in uids:
		recycled += 1 if imports.has(uid) else 0
	_expect(recycled == 0,
		"automation never reloads the cargo it just discharged")


func _deliver_road_exports(count: int) -> void:
	## The automation under test works the berth, not the public road. Give it
	## a manifest that has already arrived through that road, preserving the
	## same provenance rule as live play.
	for index in count:
		var landing := _world.yard.pick_landing_slot(CargoUnit.EXPORT)
		_expect(not landing.is_empty(), "automated call reserves road cargo")
		if landing.is_empty():
			return
		var unit := CargoUnit.new("auto_road_%02d" % index,
			CargoUnit.EXPORT, index % 8, "cidade")
		_expect(_world.yard.place_unit(int(landing.slot), int(landing.level),
			unit, str(landing.token)), "road cargo exists before berth automation")


func _test_departure_bonus_stays_in_its_band() -> void:
	GameState.owned.clear()
	GameState.owned["sts"] = 3
	GameState.recompute()
	var rate := maxf(GameState.cps, GameState.click_power)
	var plain := _world.berth.departure_bonus(false)
	var perfect := _world.berth.departure_bonus(true)
	_expect(is_equal_approx(plain, rate * BerthCallController.DEPARTURE_SECONDS),
		"the departure bonus is priced in seconds of the port's own income")
	_expect(perfect > plain,
		"a call with no refusals pays more than one with them")
	_expect(perfect <= rate * BerthCallController.DEPARTURE_SECONDS * 2.0,
		"even a perfect call cannot pay more than a short burst of income")


func _test_standing_orders_divide_one_gang() -> void:
	## The point of standing orders is that the gang is *one* gang. Before them
	## every berth was handed the whole port's rate on its own, so three hulls
	## alongside tripled the same machines and nothing about them was a decision.
	var cap := BerthCallController.AUTO_RATE_CAP
	var quay: Array = [
		{"working": true, "progress": 2.0, "capacity": 24.0},   # barely started
		{"working": true, "progress": 22.0, "capacity": 24.0},  # nearly sailing
		{"working": false, "progress": 0.0, "capacity": 0.0},   # empty berth
	]
	var even := CraneAllocation.allocate(quay, 1.0, CraneAllocation.EVEN, cap)
	_expect(is_equal_approx(even[0], 1.0) and is_equal_approx(even[1], 1.0),
		"EQUILIBRIO gives every worked berth exactly what it had before orders")
	_expect(is_zero_approx(even[2]),
		"an empty berth is never allocated a crane")

	var finish := CraneAllocation.allocate(quay, 1.0, CraneAllocation.FINISH, cap)
	_expect(is_equal_approx(finish[1], 2.0) and is_zero_approx(finish[0]),
		"CONCLUIR spends the whole pool on the hull closest to sailing")
	var biggest := CraneAllocation.allocate(
		[{"working": true, "progress": 0.0, "capacity": 12.0},
		{"working": true, "progress": 0.0, "capacity": 48.0}],
		1.0, CraneAllocation.BIGGEST, cap)
	_expect(is_equal_approx(biggest[1], 2.0) and is_zero_approx(biggest[0]),
		"MAIOR NAVIO spends the whole pool on the larger hull")

	# Whatever the order, the port cannot move more boxes than it has machines
	# for: concentrating is a choice about *where*, never a multiplier.
	for policy: StringName in CraneAllocation.POLICIES:
		var rates := CraneAllocation.allocate(quay, 1.7, policy, cap)
		var total := 0.0
		for rate: float in rates:
			total += rate
		_expect(is_equal_approx(total, 1.7 * 2.0),
			"%s spends the whole gang and no more" % policy)

	# A pool bigger than one berth can absorb spills down the order rather than
	# evaporating, or concentrating would silently become the worse choice.
	var spill := CraneAllocation.allocate(quay, cap, CraneAllocation.FINISH, cap)
	_expect(is_equal_approx(spill[1], cap) and is_equal_approx(spill[0], cap),
		"a pool past one berth's ceiling cascades instead of being thrown away")

	_expect(CraneAllocation.coerce(&"nao_existe") == CraneAllocation.EVEN,
		"an unknown standing order falls back to the default")


func _test_standing_orders_survive_a_reload() -> void:
	GameState.crane_policy = CraneAllocation.FINISH
	var saved := GameState.to_save()
	GameState.from_save({})
	_expect(GameState.crane_policy == CraneAllocation.EVEN,
		"a fresh terminal starts on the default standing order")
	GameState.from_save(saved)
	_expect(GameState.crane_policy == CraneAllocation.FINISH,
		"a standing order survives a reload")
	# A save written before orders existed has to keep doing what it was doing.
	saved.erase("crane_policy")
	GameState.from_save(saved)
	_expect(GameState.crane_policy == CraneAllocation.EVEN,
		"a save from before standing orders keeps the behaviour it had")


func _test_the_foreman_respects_the_reserve() -> void:
	var options: Array = [
		{"id": "barato", "kind": "structure", "cost": 10.0, "cps_gain": 0.05},
		{"id": "retorno", "kind": "structure", "cost": 40.0, "cps_gain": 1.0},
		{"id": "caro", "kind": "structure", "cost": 500.0, "cps_gain": 50.0},
	]
	_expect(Foreman.pick(options, Foreman.OFF, 0.0, 1e9).is_empty(),
		"a foreman who is off buys nothing at any price")
	var greedy := Foreman.pick(options, Foreman.PAYBACK, 0.0, 100.0)
	_expect(str(greedy.get("id", "")) == "retorno",
		"MELHOR RETORNO buys what pays for itself soonest, not what is cheapest")
	var thrifty := Foreman.pick(options, Foreman.CHEAPEST, 0.0, 100.0)
	_expect(str(thrifty.get("id", "")) == "barato",
		"MAIS BARATO buys the cheapest thing on the board")

	# The reserve is the whole point: without it an auto-buyer holds the wallet at
	# zero and land, upgrades and charters stop being reachable.
	_expect(str(Foreman.pick(options, Foreman.PAYBACK, 0.75, 100.0)
			.get("id", "")) == "barato",
		"a reserve keeps the greedy line inside the share it is allowed to spend")
	_expect(Foreman.pick(options, Foreman.PAYBACK, 1.0, 1e9).is_empty(),
		"a full reserve means the foreman never spends anything")
	_expect(Foreman.pick(options, Foreman.CHEAPEST, 0.0, 5.0).is_empty(),
		"a foreman who cannot afford the cheapest thing waits")

	# Something that adds no income has no payback, so the greedy line must not
	# reach for it — otherwise a tap upgrade would rank alongside a crane.
	var no_income: Array = [{"id": "toque", "kind": "upgrade", "cost": 10.0,
		"cps_gain": 0.0}]
	_expect(Foreman.pick(no_income, Foreman.PAYBACK, 0.0, 1e6).is_empty(),
		"MELHOR RETORNO never buys something that produces nothing")
	_expect(str(Foreman.pick(no_income, Foreman.CHEAPEST, 0.0, 1e6)
			.get("id", "")) == "toque",
		"MAIS BARATO still climbs the ladder a payback order would skip")


func _test_the_foreman_is_earned_and_persisted() -> void:
	GameState.from_save({})
	_expect(not GameState.foreman_unlocked(),
		"a first run has no foreman: rule 7 asks what a rebuild opens")
	GameState.prestige_count = 1
	_expect(GameState.foreman_unlocked(),
		"rebuilding once is what hires him")
	GameState.foreman_mode = Foreman.CHEAPEST
	GameState.foreman_reserve = 0.5
	var saved := GameState.to_save()
	GameState.from_save({})
	_expect(GameState.foreman_mode == Foreman.OFF,
		"a fresh terminal has nobody buying for it")
	GameState.from_save(saved)
	_expect(GameState.foreman_mode == Foreman.CHEAPEST
			and is_equal_approx(GameState.foreman_reserve, 0.5),
		"the foreman's orders survive a reload")
	# A hand-edited or future-build save must not produce a reserve the board has
	# no way to show or change.
	saved["foreman_reserve"] = 0.9
	saved["foreman_mode"] = "nao_existe"
	GameState.from_save(saved)
	_expect(Foreman.RESERVES.has(GameState.foreman_reserve),
		"an off-preset reserve snaps to one the board can display")
	_expect(GameState.foreman_mode == Foreman.OFF,
		"an unknown foreman order falls back to buying nothing")


func _test_the_rail_gantry_only_works_a_train_that_is_there() -> void:
	## The *Ramal Ferroviário* used to be the train: a strip of sprites that slid
	## across the bottom of the map, permanently loaded, never arriving anywhere
	## and never taking anything away. The train belongs to `RailYard` now — it
	## brings real cargo, and `tests/rail_test_runner.gd` owns that contract — so
	## what the player buys here is the rail-mounted gantry that works it.
	##
	## The thing to prove about a bought machine is the thing that makes it worth
	## buying: it works when there is something to work, and it does not mime
	## work over an empty siding.
	_world.rail = RailYard.new()
	_world.rail.setup(_world, _world.yard)
	var gantry := StructureActor.new()
	gantry.setup("trem", 0, _world)
	_world.entities.add_child(gantry)
	var home := PortLayout.rail_west_turnout_x() + 24.0

	for _step in int(6.0 / STEP):
		gantry._run_rail_gantry(STEP)
	_expect(absf(gantry.position.x - home) < 6.0,
		"a quiet branch leaves the gantry at its home end (x=%.1f)"
			% gantry.position.x)
	_expect(not gantry._spreader.visible and not gantry._cargo.visible,
		"with the spreader up and no phantom container under it")

	# A rake standing at the ramp, with wagons to work.
	var wagons: Array = []
	var arrival_uids := PackedStringArray()
	for slot in 4:
		var unit := CargoUnit.new(CargoUnit.new_uid("rail"),
			CargoUnit.EXPORT, slot % 8, "interior")
		wagons.append(unit)
		arrival_uids.append(unit.uid)
	_world.rail.service = {
		"wagons": wagons, "arrival_uids": arrival_uids, "length": 4,
		"drops": 4, "lifts": 0, "pending": 0, "lifting": 0,
		"dwell": RailYard.DWELL_SECONDS,
		"stage": int(RailYard.Stage.WORKING),
		"transit": RailYard.TRANSIT_TIMEOUT}

	var lifted := false
	var reached_east := -1e9
	var travelled := 0.0
	var previous := gantry.position.x
	for _step in int(30.0 / STEP):
		gantry._run_rail_gantry(STEP)
		travelled += absf(gantry.position.x - previous)
		previous = gantry.position.x
		reached_east = maxf(reached_east, gantry.position.x)
		lifted = lifted or gantry._cargo.visible
	_expect(lifted, "a standing rake gets the spreader down onto a wagon")
	_expect(travelled > PortLayout.RAIL_WAGON_PITCH,
		"and the gantry travels the train rather than working one spot (%.1f)"
			% travelled)
	# East of the buffer stop is the quay and then the sea.
	_expect(reached_east <= PortLayout.rail_buffer_x(),
		"it never travels past the buffer stop (x=%.1f)" % reached_east)

	# And it goes home again when the train has gone.
	_world.rail.service = {}
	for _step in int(12.0 / STEP):
		gantry._run_rail_gantry(STEP)
	_expect(not gantry._cargo.visible,
		"an empty siding gets a parked machine, not a mimed lift")
	gantry.queue_free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
