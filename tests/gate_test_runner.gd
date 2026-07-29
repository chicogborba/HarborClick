extends Node
## The road side of the terminal.
## Run with:
## Godot --headless --path . res://tests/gate_test_runner.tscn
##
## The berth on its own is a closed loop — cargo in by sea, out by sea — and a
## closed loop can jam. The gate exists so it cannot: a loaded truck is a way
## in when the yard is empty, an empty truck is a way out when it is full.
## These are the two states that used to be dead ends.

const TEST_SAVE_PATH := "user://harborclick_gate_test.json"

var failures: Array[String] = []
var _world: GateTestWorld


class GateTestWorld:
	extends PortWorld

	var _sheet: Texture2D = preload("res://assets/sprites/container_sheet.png")

	func _ready() -> void:
		entities = Node2D.new()
		add_child(entities)
		overhead = Node2D.new()
		add_child(overhead)
		yard = ContainerYard.new()
		entities.add_child(yard)
		gate = GateDock.new()
		gate.setup(self, yard)

	func fly_cargo(color: int, from: Vector2, to: Vector2) -> FlyingContainer:
		var flight := FlyingContainer.new()
		flight.setup(_sheet, color, from, to)
		overhead.add_child(flight)
		return flight

	func target_fill() -> float:
		return 0.5

	func spawn_dust(_pos: Vector2) -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	GameState.from_save({})
	seed(99001)

	_world = GateTestWorld.new()
	add_child(_world)
	await get_tree().process_frame

	await _test_a_loaded_truck_can_fill_an_empty_yard()
	await _test_an_empty_truck_can_drain_a_full_yard()
	_test_a_truck_survives_a_reload()

	SaveManager.wipe()
	if failures.is_empty():
		print("GATE TESTS PASSED (in when empty, out when full, reload)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("GATE TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_a_loaded_truck_can_fill_an_empty_yard() -> void:
	_world.yard.restore({"version": 2, "slots": []})
	_world.gate.seed_new()
	_world.gate.bays[0] = _make_truck(GateDock.Kind.INBOUND, 3)
	_expect(_world.yard.fill_ratio() <= 0.0, "the yard starts empty")

	var landed := 0
	for attempt in 3:
		if _world.gate.work_bay(0):
			landed += 1
		await _settle()
	_expect(landed == 3, "every box on an inbound truck can be dropped")
	_expect(_world.yard.has_boxes(),
		"a loaded truck is a way into an empty yard")
	_expect(int(_world.gate.bays[0].remaining) == 0,
		"the truck reports itself empty when its bed is clear")


func _test_an_empty_truck_can_drain_a_full_yard() -> void:
	for slot in _world.yard.total_slots():
		for level in PortLayout.STACK_MAX:
			_world.yard.place(slot, level, randi() % 8)
	var before := _world.yard.fill_ratio()
	_expect(before > 0.9, "the yard is packed for this case (%.2f)" % before)

	_world.gate.bays[1] = _make_truck(GateDock.Kind.OUTBOUND, 0)
	var taken := 0
	for attempt in GateDock.TRUCK_CAPACITY:
		if _world.gate.work_bay(1):
			taken += 1
		await _settle()
	_expect(taken == GateDock.TRUCK_CAPACITY,
		"an outbound truck fills up from a packed yard")
	_expect(_world.yard.fill_ratio() < before,
		"an empty truck is a way out of a full yard")
	_expect((_world.gate.bays[1].cargo as Array).size() == GateDock.TRUCK_CAPACITY,
		"the boxes end up on the truck rather than vanishing")


func _test_a_truck_survives_a_reload() -> void:
	var snapshot := _world.gate.snapshot()
	var before_bays := _world.gate.bays.size()
	var before_cargo := (_world.gate.bays[1].cargo as Array).size()
	_world.gate.seed_new()
	_expect(_world.gate.bays.is_empty(), "a new game starts with an empty apron")
	_world.gate.restore(snapshot)
	_expect(_world.gate.bays.size() == before_bays,
		"every parked truck comes back after a reload")
	_expect((_world.gate.bays[1].cargo as Array).size() == before_cargo,
		"a truck comes back with the same load it had")


func _make_truck(kind: int, boxes: int) -> Dictionary:
	var cargo: Array[CargoUnit] = []
	for i in boxes:
		cargo.append(CargoUnit.new(CargoUnit.new_uid("road"),
			CargoUnit.EXPORT, i % 8, "cidade"))
	return {"kind": int(kind), "cargo": cargo,
		"remaining": boxes if kind == GateDock.Kind.INBOUND else GateDock.TRUCK_CAPACITY,
		"dwell": GateDock.DWELL_SECONDS}


func _settle() -> void:
	## Flights are real nodes; a move is not committed until one lands.
	var deadline := Time.get_ticks_msec() + 4000
	while _world.overhead.get_child_count() > 0 \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
