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

	func arrive() -> void:
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
	_world.ship.arrive()
	await get_tree().process_frame

	_test_rate_follows_the_equipment_bought()
	await _test_a_full_call_completes_without_a_single_tap()
	_test_departure_bonus_stays_in_its_band()

	SaveManager.wipe()
	if failures.is_empty():
		print("AUTOMATION TESTS PASSED (rate, hands-off call, bonus band)")
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


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
