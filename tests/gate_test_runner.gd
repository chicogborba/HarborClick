extends Node
## The road side of the terminal.
## Run with:
## Godot --headless --path . res://tests/gate_test_runner.tscn
##
## The berth on its own is a closed loop — cargo in by sea, out by sea — and a
## closed loop can jam. The gate exists so it cannot: every truck arrives with
## city cargo and leaves carrying a genuine yard box, leaning toward delivery
## or collection according to what the terminal needs.

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
	await _test_transfer_views_never_duplicate_a_box()
	await _test_a_loaded_truck_can_drain_a_full_yard()
	_test_every_trip_plan_is_non_deficit()
	_test_the_road_protects_one_complete_shipload()
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
	_world.gate.bays[0] = _make_truck(GateDock.TRUCK_CAPACITY,
		GateDock.TRUCK_CAPACITY, 1)
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
	_expect(int(_world.gate.bays[0].drops) == 0,
		"the truck reports itself empty when its bed is clear")
	_world.gate.send_away(0)
	_expect(_world.gate.bays.has(0) \
			and int(_world.gate.bays[0].stage) == int(GateDock.Stage.DOCKED),
		"an empty truck is held at the bay instead of leaving bare")


func _test_transfer_views_never_duplicate_a_box() -> void:
	## The manifest removed a road box immediately, but GateDock only emitted
	## `changed` at landing. The RoadTruck therefore kept drawing the old box
	## under the flying one; landing then briefly drew flight and destination.
	_world.yard.restore({"version": 3, "slots": []})
	_world.gate.seed_new()
	_world.gate.bays[0] = _make_truck(2, 2, 0)
	var view := RoadTruck.new()
	view.setup(_world, 0, [0, 1], true)
	_world.entities.add_child(view)
	var refresh := func() -> void:
		view.set_colors(_world._bed_colors(_world.gate.bays[0]))
	_world.gate.changed.connect(refresh)

	_expect(view._boxes[0].visible and view._boxes[1].visible,
		"both genuine road boxes are visible before the lift starts")
	var expected_source := view.bed_slot_global_position(0)
	_expect(_world.gate.work_bay(0), "one road box starts its flight")
	_expect(view._boxes[0].visible and not view._boxes[1].visible,
		"the chassis refreshes as soon as the flight starts")
	var flight := _world.overhead.get_child(0) as FlyingContainer
	_expect(flight._start.distance_to(expected_source) < 0.01,
		"the road flight starts on the exact longitudinal bed slot")
	_expect(flight._box.centered,
		"the travelling box rotates around its visual centre")
	var hidden_before_commit := {"value": false}
	flight.landed.connect(func() -> void:
		hidden_before_commit.value = not flight._box.visible)
	await _settle()
	_expect(bool(hidden_before_commit.value),
		"the travelling sprite hides before the destination view commits")

	_world.gate.changed.disconnect(refresh)
	view.queue_free()
	_world.gate.seed_new()
	await get_tree().process_frame


func _test_a_loaded_truck_can_drain_a_full_yard() -> void:
	for slot in _world.yard.total_slots():
		for level in PortLayout.STACK_MAX:
			_world.yard.place(slot, level, randi() % 8)
	var before := _world.yard.fill_ratio()
	_expect(before > 0.9, "the yard is packed for this case (%.2f)" % before)

	_world.gate.bays[1] = _make_truck(1, 1, 1)
	var taken := 0
	for attempt in GateDock.TRUCK_CAPACITY:
		if _world.gate.work_bay(1):
			taken += 1
		await _settle()
	_expect(taken == GateDock.TRUCK_CAPACITY,
		"a balanced truck frees one slot and exchanges its city box")
	_expect(is_equal_approx(_world.yard.fill_ratio(), before),
		"a full-yard trip is one-for-one, never inventory-negative")
	_expect((_world.gate.bays[1].cargo as Array).size() == 1,
		"the exchanged yard box leaves on the truck rather than vanishing")


func _test_every_trip_plan_is_non_deficit() -> void:
	var restock := RoadCargoPolicy.trip_plan(0.1, 0.5,
		GateDock.TRUCK_CAPACITY)
	var balance := RoadCargoPolicy.trip_plan(0.8, 0.5,
		GateDock.TRUCK_CAPACITY)
	_expect(int(restock.drops) == 2 and int(restock.lifts) == 1,
		"a low yard receives two and releases at most one")
	_expect(int(balance.drops) == 1 and int(balance.lifts) == 1,
		"a busy yard exchanges one box for one box")
	_expect(RoadCargoPolicy.is_non_deficit(restock) \
			and RoadCargoPolicy.is_non_deficit(balance),
		"no road plan can remove more boxes than it brings")


func _test_the_road_protects_one_complete_shipload() -> void:
	_world.yard.seed_new()
	_expect(_world.yard.unit_count() == RoadCargoPolicy.MIN_OPERATIONAL_STOCK,
		"reserve setup starts with one full shipload")
	_expect(not _world.has_road_pickup(),
		"road collection cannot consume the final outbound manifest")
	var landing := _world.yard.pick_landing_slot(CargoUnit.EXPORT)
	var extra := CargoUnit.new("reserve_extra", CargoUnit.EXPORT, 3, "cidade")
	_expect(not landing.is_empty() and _world.yard.place_unit(
		int(landing.slot), int(landing.level), extra, str(landing.token)),
		"reserve setup lands one genuine extra city box")
	var taken := _world.take_road_pickup()
	_expect(not taken.is_empty() \
			and _world.yard.unit_count() == RoadCargoPolicy.MIN_OPERATIONAL_STOCK,
		"collection may take surplus but stops exactly at 24")


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
	_world.gate.bays[0] = _make_truck(1, 1, 1)

	var accepted := 0
	for attempt in GateDock.TRUCK_CAPACITY * 4:
		if _world.gate.work_bay(0):
			accepted += 1
	await _settle()
	for attempt in GateDock.TRUCK_CAPACITY * 4:
		if _world.gate.work_bay(0):
			accepted += 1
		await _settle()
	_expect(accepted == GateDock.TRUCK_CAPACITY,
		"a balanced bed only performs its one drop and one lift (took %d)" % accepted)
	var landed: int = (_world.gate.bays[0].cargo as Array).size()
	_expect(landed == 1,
		"and no more than that ever ends up on it (carried %d)" % landed)


func _test_a_truck_is_only_worked_while_it_is_parked() -> void:
	## Cargo cannot appear at a bay, because a bay is not a place cargo can be
	## until a truck is standing on it.
	_world.yard.restore({"version": 3, "slots": []})
	_world.gate.seed_new()
	var arriving := _make_truck(GateDock.TRUCK_CAPACITY,
		GateDock.TRUCK_CAPACITY, 1)
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
		# Inside the row of bays it must stay within its **own** bay. The tolerance
		# is the bay's half width rather than a pixel because the rig is steered
		# now: it arcs into and out of a bay instead of sliding along an axis, so
		# demanding the centre line to a pixel would only be a test that the truck
		# does not turn. What this protects is unchanged — the bug was a diagonal
		# from mid-approach to the exit lane that crossed every bay in the row,
		# and that misses by more than sixty pixels.
		if truck.position.y > bays_top and truck.position.y < bays_bottom:
			var lane := PortLayout.gate_bay_centre(2).x
			if absf(truck.position.x - lane) > PortLayout.GATE_BAY_W * 0.5:
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


func _make_truck(boxes: int, drops: int, lifts: int) -> Dictionary:
	var cargo: Array[CargoUnit] = []
	var arrival_uids := PackedStringArray()
	for i in boxes:
		var unit := CargoUnit.new(CargoUnit.new_uid("road"),
			CargoUnit.EXPORT, i % 8, "cidade")
		cargo.append(unit)
		arrival_uids.append(unit.uid)
	return {"cargo": cargo, "arrival_uids": arrival_uids,
		"drops": drops, "lifts": lifts, "pending": 0, "lifting": 0,
		"dwell": GateDock.DWELL_SECONDS,
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
