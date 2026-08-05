extends Node
## Integration suite for cargo phases 1-2.
## Run with:
## Godot --headless --path . res://tests/cargo_test_runner.tscn

const TEST_SAVE_PATH := "user://harborclick_cargo_test.json"
## A call is now as big as the class alongside, and which classes may call
## depends on how much yard there is to work them. A base port only sees
## feeders, so the suite asks the ship rather than assuming a number.

var failures: Array[String] = []
var _world: CargoTestWorld
var _last_status: Dictionary = {}
var _committed_transfers := 0


class CargoTestShip:
	extends Ship

	func arrive(_open_channel: bool = true) -> void:
		visible = true
		position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y)
		_set_phase(Ship.Phase.DISCHARGING)

	func depart(_open_channel: bool = true) -> void:
		if phase == Ship.Phase.DEPARTING or phase == Ship.Phase.AWAY \
				or not ready_to_depart():
			return
		_set_phase(Ship.Phase.DEPARTING)


class CargoTestWorld:
	extends PortWorld

	var reward_visuals := 0
	var _test_sheet: Texture2D = preload("res://assets/sprites/container_sheet.png")

	func _ready() -> void:
		entities = Node2D.new()
		entities.name = "Entities"
		add_child(entities)
		overhead = Node2D.new()
		overhead.name = "Overhead"
		add_child(overhead)

		yard = ContainerYard.new()
		yard.name = "Yard"
		entities.add_child(yard)
		ship = CargoTestShip.new()
		ship.name = "Ship"
		add_child(ship)
		traffic = TrafficCoordinator.new()

		berth = BerthCallController.new()
		berth.setup(self, ship, yard)
		SaveManager.register_section(
			&"cargo_yard", yard.snapshot, yard.restore_saved, yard.seed_new)
		SaveManager.register_section(
			&"berth_call", berth.snapshot, berth.restore, berth.seed_new)
		SaveManager.register_section(
			&"traffic_cargo", _traffic_snapshot, _traffic_restore, _traffic_seed)
		if ship.phase == Ship.Phase.AWAY:
			if berth.call_id.is_empty():
				berth.seed_new()
			ship.arrive()

	func fly_cargo(color: int, from: Vector2, to: Vector2) -> FlyingContainer:
		var flight := FlyingContainer.new()
		flight.setup(_test_sheet, color, from, to)
		overhead.add_child(flight)
		return flight

	func show_cargo_reward(_pos: Vector2, _value: float, _crit: bool) -> void:
		reward_visuals += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	SaveManager.yard = null
	GameState.from_save({})
	_world = CargoTestWorld.new()
	add_child(_world)
	await get_tree().process_frame

	_test_inaugural_road_manifest()
	_test_v2_yard_gets_one_time_road_retrofit()
	await _test_capacity_and_hud_format()
	_test_full_call_and_no_import_export()
	_test_next_ship_can_take_previous_ship_cargo()
	_test_invalid_click_has_no_reward()
	_test_full_yard_preserves_ship_and_reward()
	await _test_traffic_denial_and_actor_teardown_release_delivery()
	await _test_reload_mid_discharge_and_loading()
	await _test_one_hundred_accelerated_calls()
	# Last, because it empties the yard to set up the comparison it needs.
	_test_the_yard_has_a_direction()

	if is_instance_valid(_world):
		_world.free()
	SaveManager._sections.clear()
	SaveManager.wipe()
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH), "cleanup removes cargo test save")
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH + ".bak"), "cleanup removes cargo test backup")
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH + ".tmp"), "cleanup removes cargo test temp")

	if failures.is_empty():
		print("CARGO TESTS PASSED (100 calls, %d committed transfers)"
			% _committed_transfers)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("CARGO TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_the_yard_has_a_direction() -> void:
	## The complaint this exists for: "the machines just move boxes from one
	## corner to another with no sense."
	##
	## They did. A load took whatever stack was tallest, so it could reach into
	## the import yard standing beside the gate and drive the box the whole width
	## of the terminal, straight past the export stacks parked under the crane.
	## Nothing about that is wrong in cargo terms — it is transhipment, and it
	## still is — but it made the terminal look like it had no in and no out.
	##
	## The yards are geometric and permanent: landward is where boxes wait for a
	## lorry, seaward is where they wait for a hull, and the middle is buffer. So
	## the two long hauls run in opposite directions across the terminal and the
	## short ones do not.
	var yard: ContainerYard = _world.yard
	_expect(PortLayout.block_role(0) == PortLayout.ROLE_IMPORT,
		"the landward column is the import yard, beside the gate")
	_expect(PortLayout.block_role(PortLayout.BLOCK_COLUMNS - 1)
			== PortLayout.ROLE_EXPORT,
		"the seaward column is the export yard, beside the cranes")
	_expect(PortLayout.role_heads_seaward(PortLayout.ROLE_EXPORT)
			and not PortLayout.role_heads_seaward(PortLayout.ROLE_IMPORT),
		"and the two yards send their cargo opposite ways")

	# One box in each yard, the landward stack deliberately the taller of the
	# two — under the old "tallest wins" rule that is the one a load would take.
	yard.restore({"version": 2, "slots": []})
	var landward := _slot_in_role(yard, PortLayout.ROLE_IMPORT)
	var seaward := _slot_in_role(yard, PortLayout.ROLE_EXPORT)
	_expect(landward >= 0 and seaward >= 0,
		"the yard has both a landward and a seaward stack to choose between")
	for level in 2:
		yard.place(landward, level, 1)
	yard.place(seaward, 0, 2)

	var loaded := yard.take_exportable()
	_expect(int(loaded.get("slot", -1)) == seaward,
		"a hull is loaded from the seaward yard even when landward is taller")

	# And the road takes from the landward yard, which is the mirror of it.
	yard.restore({"version": 2, "slots": []})
	for level in 2:
		yard.place(_slot_in_role(yard, PortLayout.ROLE_EXPORT), level, 3)
	yard.place(_slot_in_role(yard, PortLayout.ROLE_IMPORT), 0, 4)
	_expect(yard.slot_role(yard.road_pickup_slot()) == PortLayout.ROLE_IMPORT,
		"a lorry collects from the landward yard even when seaward is taller")
	yard.restore({"version": 2, "slots": []})


func _slot_in_role(yard: ContainerYard, role: StringName) -> int:
	for slot in yard.total_slots():
		if yard.slot_role(slot) == role:
			return slot
	return -1


func _test_inaugural_road_manifest() -> void:
	var expected := ContainerYard.INITIAL_EXPORT_STOCK
	var initial_uids := _yard_uids(_world)
	_expect(initial_uids.size() == expected,
		"a new profile starts with one complete export manifest")
	var unique := {}
	var all_traceable := true
	for stack in _world.yard.snapshot().get("slots", []):
		for raw in stack:
			if not raw is Dictionary:
				all_traceable = false
				continue
			var uid := str(raw.get("uid", ""))
			all_traceable = all_traceable and not uid.is_empty() \
				and not unique.has(uid) \
				and StringName(raw.get("sector", &"")) == CargoUnit.EXPORT \
				and str(raw.get("origin_uid", "")) == ContainerYard.INITIAL_ORIGIN_UID
			unique[uid] = true
	_expect(all_traceable and unique.size() == expected,
		"every inaugural box has a unique road UID and city provenance")

	var capacity := _world.ship.bay_capacity()
	var result := _complete_call("inaugural manifest call")
	var exports: Array[String] = result.exports
	# A class now decides how many boxes a call moves, so the first vessel loads
	# *its own* capacity — not necessarily the whole inaugural manifest. What must
	# still hold is that every box it leaves with was already ashore: a call may
	# not invent an identity to fill its deck.
	var from_inaugural := true
	for uid in exports:
		from_inaugural = from_inaugural and initial_uids.has(uid)
	_expect(exports.size() == capacity and from_inaugural,
		"the first vessel loads its own capacity (%d of %d) from the already-delivered inaugural road manifest"
			% [exports.size(), capacity])
	_expect(capacity <= expected,
		"no class can out-stow the inaugural manifest on the first call (%d vs %d)"
			% [capacity, expected])
	_expect(_intersection(result.imports, exports).is_empty(),
		"the inaugural call never reloads its own imports")

	# An explicitly restored empty yard stays empty. Only the new-profile seed
	# may create the inaugural convoy; regular restore/runtime cannot restock it.
	_world.yard.restore({"version": 2, "slots": []})
	var empty_snapshot := _world.yard.snapshot()
	_world.yard.restore(empty_snapshot)
	_expect(not _world.yard.has_boxes(),
		"restoring an empty active run never creates replacement containers")


func _test_v2_yard_gets_one_time_road_retrofit() -> void:
	_world.yard.restore_saved({"version": 2, "slots": []})
	_expect(_world.yard.unit_count() == ContainerYard.INITIAL_EXPORT_STOCK,
		"a drained v2 profile receives the one-time city road retrofit")
	var migrated := _world.yard.snapshot()
	_world.yard.restore_saved({"version": 3, "slots": []})
	_expect(not _world.yard.has_boxes(),
		"a v3 empty save is never replenished during normal restore")
	_world.yard.restore(migrated)


func _test_capacity_and_hud_format() -> void:
	_reset_call(1001)
	var capacity := _world.ship.bay_capacity()
	_expect(capacity == _world.ship.bay_rows() * PortLayout.SHIP_BAY_COLS,
		"the call is exactly the class's own bay grid")
	_expect(capacity > 0 and capacity <= PortLayout.SHIP_BAY_COLS * PortLayout.SHIP_BAY_ROWS,
		"no class exceeds the berth's full-length grid (%d)" % capacity)
	var hud := Hud.new()
	add_child(hud)
	await get_tree().process_frame
	# The keys moved to the command rail; what the HUD still owns is the tally
	# and the berth chip, so that is what has to exist before the berth is
	# allowed to report into it.
	_expect(hud.readout_rect().size != Vector2.ZERO and hud._berth_chip != null,
		"HUD initializes its readout before berth-slot validation")
	_last_status = {}
	var on_status := func(status: Dictionary) -> void:
		_last_status = status.duplicate(true)
		hud.set_berth_status(status)
	_world.berth.status_changed.connect(on_status)
	_world.berth._emit_status()
	_expect(int(_last_status.get("capacity", 0)) == capacity,
		"berth status reports the class's slot count")
	_expect(str(_last_status.get("text", "")) == "Descarga 0/%d" % capacity,
		"berth status formats discharge slot count")
	_expect(hud._job_label.text == "Descarga 0/%d" % capacity,
		"HUD berth slot renders structured status")
	_expect(hud._berth_chip.visible and hud._job_label.clip_text \
			and hud._job_label.get_global_rect().size.x <= hud._berth_chip.get_global_rect().size.x,
		"HUD berth slot is clipped within its dedicated chip")
	_world.berth.status_changed.disconnect(on_status)
	hud.free()


func _test_full_call_and_no_import_export() -> void:
	_reset_call(1002)
	var result := _complete_call("full call")
	var imports: Array[String] = result.imports
	var exports: Array[String] = result.exports
	var capacity := _world.ship.bay_capacity()
	_expect(imports.size() == capacity, "a full call starts with a full deck")
	_expect(exports.size() == capacity, "a full call finishes with a full deck")
	_expect(_intersection(imports, exports).is_empty(), "no import UID embarks as export")
	# Sector is no longer a gate on what may be shipped — the yard tranships —
	# so the contract that matters is the one asserted just above: nothing
	# embarked came off this same hull.
	_assert_unique_ownership(_world, capacity * 2, "full call ownership")


func _test_next_ship_can_take_previous_ship_cargo() -> void:
	_reset_call(1012)
	var first := _complete_call("first transhipment call")
	var first_imports: Array[String] = first.imports

	# Do not clear the yard: ship B must work with the identities ship A left.
	_world.berth.seed_new(1013)
	_world.ship.position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y)
	_world.ship.visible = true
	_world.ship._set_phase(Ship.Phase.DISCHARGING)
	var second_imports := _ship_uids(_world)
	_complete_discharge("second transhipment call")
	for index in _world.ship.bay_capacity():
		var accepted := _world.berth.handle_tap(_world.ship.global_position)
		_expect(accepted, "ship B accepts ship A cargo %d" % (index + 1))
		if accepted:
			_finish_all_flights("ship B transhipment load")
	var second_exports := _ship_uids(_world)
	_expect(_intersection(second_imports, second_exports).is_empty(),
		"ship B never reloads a box it just discharged")
	_expect(_same_uid_set(first_imports, second_exports),
		"ship B may load every box previously discharged by ship A")


func _test_invalid_click_has_no_reward() -> void:
	_reset_call(1003)
	GameState.from_save({})
	var before_teus := GameState.teus
	var before_ship := _ship_uids(_world)
	var before_visuals := _world.reward_visuals
	_world._try_tap(Vector2(-1000.0, -1000.0))
	_expect(is_equal_approx(GameState.teus, before_teus), "invalid click earns zero TEUs")
	_expect(_ship_uids(_world) == before_ship, "invalid click does not move ship cargo")
	_expect(_world.reward_visuals == before_visuals, "invalid click creates no reward visual")
	_expect(_world.berth._active.is_empty() and _world.berth._in_flight == 0,
		"invalid click creates no transfer")


func _test_full_yard_preserves_ship_and_reward() -> void:
	_reset_call(1004)
	_fill_import_sector()
	GameState.from_save({})
	var before_teus := GameState.teus
	var before_ship := _ship_uids(_world)
	var before_imports := _world.yard.sector_count(CargoUnit.IMPORT)
	var before_visuals := _world.reward_visuals
	var accepted := _world.berth.handle_tap(_world.ship.global_position)
	_expect(not accepted, "full import yard rejects discharge")
	_expect(_ship_uids(_world) == before_ship, "full yard restores the exact ship manifest")
	_expect(_world.yard.sector_count(CargoUnit.IMPORT) == before_imports,
		"full yard does not evict an existing import")
	_expect(is_equal_approx(GameState.teus, before_teus), "full yard grants no reward")
	_expect(_world.reward_visuals == before_visuals, "full yard creates no reward visual")
	_expect(_world.berth._active.is_empty() and _world.berth._in_flight == 0,
		"full yard leaves no active transfer")


func _test_traffic_denial_and_actor_teardown_release_delivery() -> void:
	_world.yard.restore({"version": 2, "slots": []})
	_world.traffic.clear()
	var entry := PortLayout.gate_entry()
	var blocker := Node2D.new()
	blocker.position = entry
	_world.entities.add_child(blocker)
	_world.traffic.join(blocker)

	var denied := StructureActor.new()
	denied.setup("reach_stacker", 0, _world)
	_world.entities.add_child(denied)
	var reservations_before := _world.yard._reservations.size()
	denied._try_take_job()
	_expect(_world.yard._reservations.size() == reservations_before,
		"gate denial does not reserve an EXPORT landing")
	denied.free()
	_world.traffic.leave(blocker)
	blocker.free()

	# A driving lane belongs to one hauler at a time, and a hauler that cannot
	# get a lane must hand back the landing slot request_job just reserved for
	# it. Every lane is occupied here so the denial is guaranteed.
	var lane_holders: Array[Node2D] = []
	for lane_y in PortLayout.lane_ys():
		var holder := Node2D.new()
		holder.position = Vector2(PortLayout.ROAD_IN_X, -400.0)
		_world.entities.add_child(holder)
		_world.traffic.reserve_lane(holder, "lane_%d" % roundi(lane_y))
		lane_holders.append(holder)
	var held_reservations := _world.yard._reservations.size()
	var blocked := StructureActor.new()
	blocked.setup("reach_stacker", 2, _world)
	_world.entities.add_child(blocked)
	blocked._try_take_job()
	_expect(blocked._job_data.is_empty() and blocked._lane_key.is_empty(),
		"a hauler with no free driving lane takes no job")
	_expect(_world.yard._reservations.size() == held_reservations,
		"a hauler denied a driving lane returns the landing it just reserved")
	blocked.free()
	for holder in lane_holders:
		_world.traffic.leave(holder)
		holder.free()
	_world.traffic.clear()

	var cancelled := StructureActor.new()
	cancelled.setup("reach_stacker", 1, _world)
	_world.entities.add_child(cancelled)
	cancelled._try_take_job()
	_expect(cancelled._job_data.get("type", "") == "deliver" \
			and _world.yard._reservations.size() == reservations_before + 1,
		"accepted delivery owns exactly one yard reservation")
	cancelled.free()
	_expect(_world.yard._reservations.size() == reservations_before,
		"freeing an active hauler returns its EXPORT reservation")

	var delivered_job := _world.request_job()
	var road_unit := delivered_job.get("unit") as CargoUnit
	_expect(road_unit != null and road_unit.origin_uid == "cidade" \
			and not _yard_uids(_world).has(road_unit.uid),
		"road delivery owns its UID before the vehicle reaches the yard")
	if road_unit != null:
		_expect(_world.complete_delivery(int(delivered_job.slot),
			int(delivered_job.level), road_unit, str(delivered_job.token)),
			"the arriving road vehicle commits its existing cargo identity")
		_expect(_yard_uids(_world).has(road_unit.uid),
			"the yard receives that same road UID instead of spawning a box")

	_world.yard.restore({"version": 2, "slots": []})
	_fill_import_sector()
	_world.traffic.clear()
	var pickup_actor := StructureActor.new()
	pickup_actor.setup("reach_stacker", 2, _world)
	_world.entities.add_child(pickup_actor)
	pickup_actor._try_take_job()
	_expect(pickup_actor._job_data.get("type", "") == "pickup",
		"busy import yard dispatches a pickup")
	var import_count_before := _world.yard.sector_count(CargoUnit.IMPORT)
	pickup_actor._finish_work()
	var taken: Dictionary = pickup_actor._job_data.get("taken", {})
	var taken_unit := taken.get("unit") as CargoUnit
	_expect(taken_unit != null \
			and not _yard_uids(_world).has(taken_unit.uid) \
			and _world.yard.sector_count(CargoUnit.IMPORT) == import_count_before - 1,
		"working pickup is held by the hauler until gate exit")
	pickup_actor.free()
	_expect(taken_unit != null and _yard_uids(_world).has(taken_unit.uid) \
			and _world.yard.sector_count(CargoUnit.IMPORT) == import_count_before,
		"freeing a loaded hauler restores the exact IMPORT UID")

	var before_reload := _yard_uids(_world)
	var persisted_actor := StructureActor.new()
	persisted_actor.setup("reach_stacker", 3, _world)
	_world.entities.add_child(persisted_actor)
	persisted_actor._try_take_job()
	persisted_actor._finish_work()
	_expect(_world._traffic_in_transit.size() == 1,
		"loaded hauler enters the persisted traffic ledger")
	_expect(_world.yard.pick_landing_slot(CargoUnit.IMPORT).is_empty(),
		"hauler keeps its rollback capacity reserved against IMPORT refill")
	_expect(SaveManager.save_game(&"hauler_mid_pickup"),
		"mid-pickup traffic snapshot writes")
	_world = await _reload_world()
	_expect(_world._traffic_in_transit.is_empty(),
		"mid-pickup reload reconciles the traffic ledger")
	_expect_same_uid_set(before_reload, _yard_uids(_world),
		"mid-pickup reload restores the exact yard UID set")


func _test_reload_mid_discharge_and_loading() -> void:
	# Discharge: the unit is temporarily owned by active_transfers.
	_reset_call(1005)
	var discharge_before := _ownership_uids(_world, true)
	_expect(_world.berth.handle_tap(_world.ship.global_position),
		"mid-discharge setup starts a flight")
	_expect(_world.berth._active.size() == 1, "mid-discharge snapshot contains one active flight")
	_expect_same_uid_set(discharge_before, _ownership_uids(_world, true),
		"mid-discharge prepared transfer preserves ownership")
	_expect(SaveManager.save_game(&"cargo_mid_discharge"), "mid-discharge snapshot writes")
	_world = await _reload_world()
	_expect(_world.berth._active.is_empty() and _world.berth._in_flight == 0,
		"mid-discharge reload reconciles transient flight")
	_expect_same_uid_set(discharge_before, _ownership_uids(_world, false),
		"mid-discharge reload loses or duplicates no UID")
	# Counted from what was actually on the board before the save, not from a
	# formula: the class alongside decides how many boxes a call has.
	_assert_unique_ownership(_world, discharge_before.size(),
		"mid-discharge reload ownership")

	# Loading: complete discharge, then snapshot an export between yard and bay.
	_reset_call(1006)
	_complete_discharge("reload loading setup")
	var loading_before := _ownership_uids(_world, true)
	_expect(_world.berth.handle_tap(_world.ship.global_position),
		"mid-loading setup starts a flight")
	_expect(_world.ship.phase == Ship.Phase.LOADING, "mid-loading setup enters loading phase")
	_expect(_world.berth._active.size() == 1, "mid-loading snapshot contains one active flight")
	_expect_same_uid_set(loading_before, _ownership_uids(_world, true),
		"mid-loading prepared transfer preserves ownership")
	_expect(SaveManager.save_game(&"cargo_mid_loading"), "mid-loading snapshot writes")
	_world = await _reload_world()
	_expect(_world.berth._active.is_empty() and _world.berth._in_flight == 0,
		"mid-loading reload reconciles transient flight")
	_expect_same_uid_set(loading_before, _ownership_uids(_world, false),
		"mid-loading reload loses or duplicates no UID")
	_assert_unique_ownership(_world, loading_before.size(),
		"mid-loading reload ownership")


func _test_one_hundred_accelerated_calls() -> void:
	var all_seen: Dictionary = {}
	# A call is as big as the class working it, so the total is a sum rather than
	# a product. What has to hold is that no identity is ever reused and none goes
	# missing — not that every hull is the same size.
	var expected := 0
	for call_index in 100:
		_reset_call(2000 + call_index)
		var result := _complete_call("accelerated call %03d" % call_index)
		var imports: Array[String] = result.imports
		var exports: Array[String] = result.exports
		_expect(_world.ship.cargo_left() == _world.ship.bay_capacity(),
			"accelerated call %03d departs full" % call_index)
		_expect(imports.size() == _world.ship.bay_capacity() and exports.size() == _world.ship.bay_capacity(),
			"accelerated call %03d handles a full deck each way" % call_index)
		_expect(_intersection(imports, exports).is_empty(),
			"accelerated call %03d never embarks an import UID" % call_index)
		_committed_transfers += imports.size() + exports.size()
		expected += imports.size() + exports.size()
		_assert_unique_ownership(
			_world, _world.ship.bay_capacity() * 2, "accelerated call %03d ownership" % call_index)
		for uid in imports + exports:
			_expect(not all_seen.has(uid),
				"accelerated call %03d reuses historical UID %s" % [call_index, uid])
			all_seen[uid] = true
		var drained := _drain_imports_via_gate()
		_expect(drained == 0,
			"accelerated call %03d protects its next outbound manifest" % call_index)
		_expect(_world.yard.sector_count(CargoUnit.IMPORT) == _world.ship.bay_capacity(),
			"accelerated call %03d keeps 24 boxes for the next hull" % call_index)
		await get_tree().process_frame
	_expect(all_seen.size() == expected,
		"100 calls produce %d globally distinct cargo UIDs (saw %d)"
			% [expected, all_seen.size()])
	_expect(expected >= 100 * PortLayout.SHIP_BAY_COLS * 4,
		"and the run really did move a hundred full calls (%d boxes)" % expected)


func _reset_call(test_seed: int) -> void:
	_world.yard.restore({"version": 2, "slots": []})
	_world.berth.seed_new(test_seed)
	_world.ship.position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y)
	_world.ship.visible = true
	_world.ship._set_phase(Ship.Phase.DISCHARGING)
	_world.ship.set_flights_in_progress(0)
	_world.reward_visuals = 0
	_expect(_world.ship.cargo_left() == _world.ship.bay_capacity(), "reset seeds a full import manifest")
	_expect(not _world.yard.has_boxes(),
		"starting a ship call never spawns containers in the yard")
	_deliver_road_exports(_world.ship.bay_capacity(), test_seed)
	_expect(_world.yard.sector_count(CargoUnit.EXPORT) == _world.ship.bay_capacity(),
		"the export manifest reaches the yard from the road")


func _deliver_road_exports(count: int, test_seed: int) -> void:
	## Test fixture for already-arrived road cargo. Every identity is created at
	## the city origin before being committed to a reserved yard landing.
	for index in count:
		var landing := _world.yard.pick_landing_slot(CargoUnit.EXPORT)
		_expect(not landing.is_empty(), "road cargo has a reserved landing")
		if landing.is_empty():
			return
		var unit := CargoUnit.new("test_road_%d_%d" % [test_seed, index],
			CargoUnit.EXPORT, index % 8, "cidade")
		_expect(_world.yard.place_unit(int(landing.slot), int(landing.level),
			unit, str(landing.token)), "road cargo lands with its original UID")


func _complete_call(label: String) -> Dictionary:
	var imports := _ship_uids(_world)
	_complete_discharge(label)
	for index in _world.ship.bay_capacity():
		var accepted := _world.berth.handle_tap(_world.ship.global_position)
		_expect(accepted, "%s accepts load %d/%d" % [label, index + 1, _world.ship.bay_capacity()])
		if accepted:
			_finish_all_flights(label + " load")
	_expect(_world.ship.phase == Ship.Phase.DEPARTING,
		"%s reaches departing after final export" % label)
	_expect(_world.ship.cargo_left() == _world.ship.bay_capacity(),
		"%s leaves with a full deck of exports" % label)
	return {"imports": imports, "exports": _ship_uids(_world)}


func _complete_discharge(label: String) -> void:
	for index in _world.ship.bay_capacity():
		var accepted := _world.berth.handle_tap(_world.ship.global_position)
		_expect(accepted, "%s accepts discharge %d/%d" % [label, index + 1, _world.ship.bay_capacity()])
		if accepted:
			_finish_all_flights(label + " discharge")
	_expect(_world.ship.phase == Ship.Phase.WAITING_EXPORT,
		"%s reaches waiting export after discharge" % label)
	_expect(_world.ship.cargo_left() == 0, "%s discharges every inbound box" % label)


func _finish_all_flights(label: String) -> void:
	var flights: Array[FlyingContainer] = []
	for child in _world.overhead.get_children():
		if child is FlyingContainer:
			flights.append(child)
	_expect(flights.size() == 1, "%s creates exactly one visual flight" % label)
	for flight in flights:
		# Accelerated tests skip the travel and impact tweens, but must finish
		# through the same hand-off used by the real animation. Calling `_land`
		# and freeing immediately used to work only while `landed` was emitted
		# before the impact squash.
		flight._finish_landing()
		if is_instance_valid(flight):
			flight.free()


func _reload_world():
	var old_world := _world
	old_world.free()
	# Simulate process restart: no providers exist while the save envelope loads.
	SaveManager._sections.clear()
	_expect(SaveManager.load_game(), "cargo snapshot reload succeeds")
	var restored := CargoTestWorld.new()
	add_child(restored)
	await get_tree().process_frame
	return restored


func _fill_import_sector() -> void:
	for slot in _world.yard.total_slots():
		if _world.yard.slot_sector(slot) != CargoUnit.IMPORT:
			continue
		while _world.yard._settled(slot) < PortLayout.STACK_MAX:
			var level := _world.yard._settled(slot)
			_expect(_world.yard.place(slot, level, level % 8),
				"test setup fills import slot %d/%d" % [slot, level])


func _drain_imports_via_gate() -> int:
	var drained := 0
	while _world.yard.has_sector(CargoUnit.IMPORT):
		var slot := _world.yard.fullest_slot(CargoUnit.IMPORT)
		if slot < 0:
			_expect(false, "gate drain finds an IMPORT slot")
			break
		var taken := _world.complete_pickup(slot)
		if taken.is_empty():
			break
		var unit: CargoUnit = taken.get("unit")
		_expect(unit != null and unit.sector == CargoUnit.IMPORT,
			"gate drains only IMPORT cargo")
		drained += 1
	return drained


func _ship_uids(world: CargoTestWorld) -> Array[String]:
	var ids: Array[String] = []
	for raw in world.ship.snapshot().get("manifest", []):
		if raw is Dictionary:
			var unit_raw: Variant = raw.get("unit", raw)
			if unit_raw is Dictionary:
				ids.append(str(unit_raw.get("uid", "")))
	return ids


func _yard_uids(world: CargoTestWorld) -> Array[String]:
	var ids: Array[String] = []
	for stack in world.yard.snapshot().get("slots", []):
		for raw in stack:
			if raw is Dictionary:
				ids.append(str(raw.get("uid", "")))
	return ids


func _ownership_uids(world: CargoTestWorld, include_active: bool) -> Array[String]:
	var ids := _ship_uids(world)
	ids.append_array(_yard_uids(world))
	if include_active:
		for record in world.berth.snapshot().get("active_transfers", []):
			if record is Dictionary and record.get("unit") is Dictionary:
				ids.append(str(record.unit.get("uid", "")))
	return ids


func _assert_unique_ownership(world: CargoTestWorld, expected: int, label: String) -> void:
	var ids := _ownership_uids(world, true)
	var unique: Dictionary = {}
	var valid := true
	for uid in ids:
		if uid.is_empty() or unique.has(uid):
			valid = false
		unique[uid] = true
	_expect(valid, "%s has no blank or duplicate UID" % label)
	_expect(ids.size() == expected and unique.size() == expected,
		"%s owns exactly %d cargo units" % [label, expected])


func _expect_same_uid_set(expected: Array[String], actual: Array[String], label: String) -> void:
	var left := expected.duplicate()
	var right := actual.duplicate()
	left.sort()
	right.sort()
	if left != right:
		var missing: Array[String] = []
		var extra: Array[String] = []
		for uid in left:
			if not right.has(uid):
				missing.append(uid)
		for uid in right:
			if not left.has(uid):
				extra.append(uid)
		_expect(false, "%s (expected=%d actual=%d missing=%s extra=%s)" % [
			label, left.size(), right.size(), missing, extra])


func _intersection(left: Array[String], right: Array[String]) -> Array[String]:
	var right_set: Dictionary = {}
	for uid in right:
		right_set[uid] = true
	var common: Array[String] = []
	for uid in left:
		if right_set.has(uid):
			common.append(uid)
	return common


func _same_uid_set(left: Array[String], right: Array[String]) -> bool:
	var sorted_left := left.duplicate()
	var sorted_right := right.duplicate()
	sorted_left.sort()
	sorted_right.sort()
	return sorted_left == sorted_right


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
