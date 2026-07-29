extends Node
## Integration suite for cargo phases 1-2.
## Run with:
## Godot --headless --path . res://tests/cargo_test_runner.tscn

const TEST_SAVE_PATH := "user://harborclick_cargo_test.json"
const CAPACITY := PortLayout.SHIP_BAY_COLS * PortLayout.SHIP_BAY_ROWS

var failures: Array[String] = []
var _world: CargoTestWorld
var _last_status: Dictionary = {}


class CargoTestShip:
	extends Ship

	func arrive() -> void:
		visible = true
		position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y)
		_set_phase(Ship.Phase.DISCHARGING)

	func depart() -> void:
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
		SaveManager.register_section(&"cargo_yard", yard.snapshot, yard.restore)
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

	await _test_capacity_and_hud_format()
	_test_full_call_and_no_import_export()
	_test_invalid_click_has_no_reward()
	_test_full_yard_preserves_ship_and_reward()
	await _test_traffic_denial_and_actor_teardown_release_delivery()
	await _test_reload_mid_discharge_and_loading()
	await _test_one_hundred_accelerated_calls()

	if is_instance_valid(_world):
		_world.free()
	SaveManager._sections.clear()
	SaveManager.wipe()
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH), "cleanup removes cargo test save")
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH + ".bak"), "cleanup removes cargo test backup")
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH + ".tmp"), "cleanup removes cargo test temp")

	if failures.is_empty():
		print("CARGO TESTS PASSED (100 calls, 4800 committed transfers)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("CARGO TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_capacity_and_hud_format() -> void:
	_reset_call(1001)
	_expect(CAPACITY == 24, "ship format is exactly 24 slots")
	var hud := Hud.new()
	add_child(hud)
	await get_tree().process_frame
	_expect(hud.get_node_or_null(^"SettingsGear") != null,
		"HUD initializes all controls before berth-slot validation")
	_last_status = {}
	var on_status := func(status: Dictionary) -> void:
		_last_status = status.duplicate(true)
		hud.set_berth_status(status)
	_world.berth.status_changed.connect(on_status)
	_world.berth._emit_status()
	_expect(int(_last_status.get("capacity", 0)) == 24, "berth status reports 24-slot capacity")
	_expect(str(_last_status.get("text", "")) == "Descarga 0/24", "berth status formats discharge slot count")
	_expect(hud._job_label.text == "Descarga 0/24", "HUD berth slot renders structured status")
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
	_expect(imports.size() == CAPACITY, "full call starts with 24 imports")
	_expect(exports.size() == CAPACITY, "full call finishes with 24 exports")
	_expect(_intersection(imports, exports).is_empty(), "no import UID embarks as export")
	for raw in _world.ship.snapshot().get("manifest", []):
		var unit_raw: Variant = raw.get("unit", raw) if raw is Dictionary else {}
		_expect(unit_raw is Dictionary \
				and StringName(unit_raw.get("sector", &"")) == CargoUnit.EXPORT,
			"every embarked unit belongs to EXPORT sector")
	_assert_unique_ownership(_world, CAPACITY * 2, "full call ownership")


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
	var entry := Vector2(
		PortLayout.GATE_ROAD_X, PortLayout.TOP_MARGIN - 24.0)
	var blocker := Node2D.new()
	blocker.position = entry
	_world.entities.add_child(blocker)
	_world.traffic.reserve(blocker, "gate")

	var denied := StructureActor.new()
	denied.setup("tt", 0, _world)
	_world.entities.add_child(denied)
	var reservations_before := _world.yard._reservations.size()
	denied._try_take_job()
	_expect(_world.yard._reservations.size() == reservations_before,
		"gate denial does not reserve an EXPORT landing")
	denied.free()
	_world.traffic.release(blocker)
	blocker.free()

	var cancelled := StructureActor.new()
	cancelled.setup("tt", 1, _world)
	_world.entities.add_child(cancelled)
	cancelled._try_take_job()
	_expect(cancelled._job_data.get("type", "") == "deliver" \
			and _world.yard._reservations.size() == reservations_before + 1,
		"accepted delivery owns exactly one yard reservation")
	cancelled.free()
	_expect(_world.yard._reservations.size() == reservations_before,
		"freeing an active hauler returns its EXPORT reservation")

	_world.yard.restore({"version": 2, "slots": []})
	_fill_import_sector()
	_world.traffic.clear()
	var pickup_actor := StructureActor.new()
	pickup_actor.setup("tt", 2, _world)
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
	persisted_actor.setup("tt", 3, _world)
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
	_assert_unique_ownership(_world, CAPACITY * 2, "mid-discharge reload ownership")

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
	_assert_unique_ownership(_world, CAPACITY * 2, "mid-loading reload ownership")


func _test_one_hundred_accelerated_calls() -> void:
	var all_seen: Dictionary = {}
	for call_index in 100:
		_reset_call(2000 + call_index)
		var result := _complete_call("accelerated call %03d" % call_index)
		var imports: Array[String] = result.imports
		var exports: Array[String] = result.exports
		_expect(_world.ship.cargo_left() == CAPACITY,
			"accelerated call %03d departs full" % call_index)
		_expect(imports.size() == CAPACITY and exports.size() == CAPACITY,
			"accelerated call %03d handles 24+24" % call_index)
		_expect(_intersection(imports, exports).is_empty(),
			"accelerated call %03d never embarks an import UID" % call_index)
		_assert_unique_ownership(
			_world, CAPACITY * 2, "accelerated call %03d ownership" % call_index)
		for uid in imports + exports:
			_expect(not all_seen.has(uid),
				"accelerated call %03d reuses historical UID %s" % [call_index, uid])
			all_seen[uid] = true
		var drained := _drain_imports_via_gate()
		_expect(drained == CAPACITY,
			"accelerated call %03d drains 24 imports via gate" % call_index)
		_expect(_world.yard.sector_count(CargoUnit.IMPORT) == 0,
			"accelerated call %03d leaves import sector drained" % call_index)
		await get_tree().process_frame
	_expect(all_seen.size() == 100 * CAPACITY * 2,
		"100 calls produce 4800 globally distinct cargo UIDs")


func _reset_call(test_seed: int) -> void:
	_world.yard.restore({"version": 2, "slots": []})
	_world.berth.seed_new(test_seed)
	_world.ship.position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y)
	_world.ship.visible = true
	_world.ship._set_phase(Ship.Phase.DISCHARGING)
	_world.ship.set_flights_in_progress(0)
	_world.reward_visuals = 0
	_expect(_world.ship.cargo_left() == CAPACITY, "reset seeds a full import manifest")
	_expect(_world.yard.sector_count(CargoUnit.EXPORT) == CAPACITY,
		"reset seeds a full export manifest")


func _complete_call(label: String) -> Dictionary:
	var imports := _ship_uids(_world)
	_complete_discharge(label)
	for index in CAPACITY:
		var accepted := _world.berth.handle_tap(_world.ship.global_position)
		_expect(accepted, "%s accepts load %d/24" % [label, index + 1])
		if accepted:
			_finish_all_flights(label + " load")
	_expect(_world.ship.phase == Ship.Phase.DEPARTING,
		"%s reaches departing after final export" % label)
	_expect(_world.ship.cargo_left() == CAPACITY, "%s leaves with 24 exports" % label)
	return {"imports": imports, "exports": _ship_uids(_world)}


func _complete_discharge(label: String) -> void:
	for index in CAPACITY:
		var accepted := _world.berth.handle_tap(_world.ship.global_position)
		_expect(accepted, "%s accepts discharge %d/24" % [label, index + 1])
		if accepted:
			_finish_all_flights(label + " discharge")
	_expect(_world.ship.phase == Ship.Phase.WAITING_EXPORT,
		"%s reaches waiting export after discharge" % label)
	_expect(_world.ship.cargo_left() == 0, "%s discharges all 24 imports" % label)


func _finish_all_flights(label: String) -> void:
	var flights: Array[FlyingContainer] = []
	for child in _world.overhead.get_children():
		if child is FlyingContainer:
			flights.append(child)
	_expect(flights.size() == 1, "%s creates exactly one visual flight" % label)
	for flight in flights:
		flight._land()
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
			_expect(false, "gate pickup returns an IMPORT unit")
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


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
