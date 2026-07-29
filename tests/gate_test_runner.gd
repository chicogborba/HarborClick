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
		traffic = TrafficCoordinator.new()
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
	await _test_a_truck_never_over_fills()
	await _test_a_truck_is_only_worked_while_it_is_parked()
	await _test_a_truck_drives_the_road_in_and_out()
	await _test_a_truck_turned_away_finishes_its_run_first()

	SaveManager.wipe()
	if failures.is_empty():
		print("GATE TESTS PASSED (in when empty, out when full, reload, "
			+ "capacity under load, parked-only work, the road end to end)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("GATE TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_a_loaded_truck_can_fill_an_empty_yard() -> void:
	_world.yard.restore({"version": 2, "slots": []})
	_world.gate.seed_new()
	_world.gate.bays[0] = _make_truck(GateDock.Kind.INBOUND,
		GateDock.TRUCK_CAPACITY)
	_expect(_world.yard.fill_ratio() <= 0.0, "the yard starts empty")

	var landed := 0
	for attempt in GateDock.TRUCK_CAPACITY:
		if _world.gate.work_bay(0):
			landed += 1
		await _settle()
	_expect(landed == GateDock.TRUCK_CAPACITY,
		"every box on an inbound truck can be dropped")
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


func _test_a_truck_never_over_fills() -> void:
	## The bug this exists for: `remaining` only fell when a box landed, so
	## working the bay again while the first box was still in the air kept
	## pulling more of them out of the yard. With the auto-movers firing four
	## times a second and a flight lasting the better part of one, a truck drew
	## itself a stack twice its own length and drove off with it.
	for slot in _world.yard.total_slots():
		for level in PortLayout.STACK_MAX:
			_world.yard.place(slot, level, randi() % 8)
	_world.gate.seed_new()
	_world.gate.bays[0] = _make_truck(GateDock.Kind.OUTBOUND, 0)

	var accepted := 0
	for attempt in GateDock.TRUCK_CAPACITY * 4:
		if _world.gate.work_bay(0):
			accepted += 1
	_expect(accepted == GateDock.TRUCK_CAPACITY,
		"a bed only accepts as many boxes as it has room for (took %d)" % accepted)
	await _settle()
	var landed: int = (_world.gate.bays[0].cargo as Array).size()
	_expect(landed == GateDock.TRUCK_CAPACITY,
		"and no more than that ever ends up on it (carried %d)" % landed)


func _test_a_truck_is_only_worked_while_it_is_parked() -> void:
	## Cargo cannot appear at a bay, because a bay is not a place cargo can be
	## until a truck is standing on it.
	_world.gate.seed_new()
	var arriving := _make_truck(GateDock.Kind.INBOUND, GateDock.TRUCK_CAPACITY)
	arriving["stage"] = int(GateDock.Stage.ARRIVING)
	_world.gate.bays[0] = arriving
	_expect(not _world.gate.work_bay(0),
		"a truck still out on the road cannot be unloaded")

	_world.gate.notify_docked(0)
	_expect(_world.gate.work_bay(0), "one that has parked can")
	await _settle()

	_world.gate.send_away(0)
	_expect(not _world.gate.work_bay(0),
		"a truck that has pulled off the bay is not worked on its way out")
	_expect(_world.gate.bays.has(0),
		"but it keeps its bay until it is actually gone")
	_world.gate.notify_departed(0)
	_expect(not _world.gate.bays.has(0),
		"and the bay only frees up once the truck is off the map")


func _test_a_truck_drives_the_road_in_and_out() -> void:
	## The road, end to end. A truck comes in from the city, parks on the bay
	## it was called to, and leaves northwards past the gate — no part of that
	## is a sprite being switched on and off.
	var truck := RoadTruck.new()
	truck.setup(_world, 1, [3, 5], false)
	_world.entities.add_child(truck)
	await get_tree().process_frame
	_expect(truck.position.y < 0.0,
		"a truck starts out at the city, off the top of the map")

	# A dictionary, because a lambda captures a local by value and could never
	# report anything back through one.
	var run := {"docked": false, "left_at": Vector2.ZERO}
	truck.arrived.connect(func() -> void: run.docked = true)
	_drive(truck, func() -> bool: return bool(run.docked))
	_expect(bool(run.docked), "it gets to its bay by driving there")
	_expect(truck.position.distance_to(PortLayout.gate_bay_centre(1)) < 0.5,
		"and parks on the bay it was called to, not near it")

	truck.departed.connect(func() -> void: run.left_at = truck.position)
	truck.depart()
	_drive(truck, func() -> bool: return run.left_at != Vector2.ZERO)
	var left_at: Vector2 = run.left_at
	_expect(left_at.y <= PortLayout.CITY_Y,
		"and it leaves the way it came, north past the gate (ended at %s)" % left_at)
	_expect(left_at.x > PortLayout.GATE_ROAD_X,
		"up the outbound lane, not against the traffic coming in")
	await get_tree().process_frame


func _test_a_truck_turned_away_finishes_its_run_first() -> void:
	## Sending a truck away while it is still on the approach used to hand it a
	## route that started at the bay, so it drove a diagonal across every
	## parking bay between here and there. The legs are one-way and axis
	## aligned, and they stay that way.
	var truck := RoadTruck.new()
	truck.setup(_world, 2, [1], false)
	_world.entities.add_child(truck)
	var run := {"left_at": Vector2.ZERO, "strayed": false}
	truck.departed.connect(func() -> void: run.left_at = truck.position)

	# Halfway along the approach, well short of its bay.
	_drive(truck, func() -> bool:
		return truck.position.y >= PortLayout.GATE_QUEUE_Y - 0.5 \
			and truck.position.x > PortLayout.ROAD_OUT_X)
	truck.depart()

	var bays_top := PortLayout.GATE_APRON_Y
	var bays_bottom := PortLayout.GATE_APRON_Y + PortLayout.GATE_BAY_H
	_drive(truck, func() -> bool:
		# Inside the row of bays it must be on a bay's own centre line; that is
		# the only reason to be there at all.
		if truck.position.y > bays_top and truck.position.y < bays_bottom:
			var lane := PortLayout.gate_bay_centre(2).x
			if absf(truck.position.x - lane) > 1.0:
				run.strayed = true
		return run.left_at != Vector2.ZERO)
	_expect(not bool(run.strayed),
		"a truck turned away drives round the bays, never across them")
	_expect((run.left_at as Vector2).y <= PortLayout.CITY_Y,
		"and still leaves for the city")


func _drive(truck: RoadTruck, done: Callable, steps: int = 1800) -> void:
	## Stepped by hand at a fixed rate rather than in real time: the route is a
	## few hundred pixels at forty a second, and a test should not spend ten
	## seconds finding that out.
	truck.set_process(false)
	for step in steps:
		if done.call():
			return
		truck._process(1.0 / 60.0)


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
		"pending": 0, "dwell": GateDock.DWELL_SECONDS,
		"stage": int(GateDock.Stage.DOCKED), "transit": GateDock.TRANSIT_TIMEOUT}


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
