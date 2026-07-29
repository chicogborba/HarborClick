extends Node
## Yard traffic regression suite.
## Run with:
## Godot --headless --path . res://tests/traffic_test_runner.tscn
##
## The old coordinator held a "gate" reservation for the whole job, so by the
## time a second hauler asked for clearance the first one was parked far away
## and the check always passed. Vehicles spawned on top of each other and drove
## through one another. These are the two properties that had to hold and did
## not: nothing overlaps, and nothing starves.

const TEST_SAVE_PATH := "user://harborclick_traffic_test.json"
const STEP := 1.0 / 30.0
const STEPS := 5400                 # three simulated minutes
const CLEARANCE := 9.0              # sprite half-widths at the hauler's scale

var failures: Array[String] = []
var _world: TrafficTestWorld


class TrafficTestShip:
	extends Ship

	func arrive() -> void:
		visible = true
		position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y)
		_set_phase(Ship.Phase.DISCHARGING)


class TrafficTestWorld:
	extends PortWorld

	var _sheet: Texture2D = preload("res://assets/sprites/container_sheet.png")

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
		ship = TrafficTestShip.new()
		ship.name = "Ship"
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
	seed(20260729)

	# Yard traffic is demand-driven: PortWorld only hands out jobs while the
	# yard is away from the fill its throughput implies. A busy terminal is
	# what stresses the road, so the run starts with real income behind it.
	GameState.teus = 1e18
	GameState.lifetime_teus = 1e18
	for item in StructureDB.ITEMS:
		for n in 12:
			GameState.buy_structure(item.id)

	_world = TrafficTestWorld.new()
	add_child(_world)
	await get_tree().process_frame

	# Every hauler type at once, which is also the busiest the terminal ever
	# gets: three tractors, two forklifts and two reach stackers on one gate.
	var haulers: Array[StructureActor] = []
	for spec in [["tt", 3], ["empilhadeira", 2], ["reach_stacker", 2]]:
		for index in int(spec[1]):
			var actor := StructureActor.new()
			actor.setup(str(spec[0]), index, _world)
			_world.entities.add_child(actor)
			haulers.append(actor)
	await get_tree().process_frame

	var worked := {}
	var closest := INF
	var lane_conflicts := 0
	for step in STEPS:
		for actor in haulers:
			actor._process(STEP)
		var busy: Array[StructureActor] = []
		var lanes := {}
		for actor in haulers:
			if not actor.visible:
				continue
			busy.append(actor)
			worked[actor.get_instance_id()] = true
			if not actor._lane_key.is_empty():
				lane_conflicts += 1 if lanes.has(actor._lane_key) else 0
				lanes[actor._lane_key] = true
		for i in busy.size():
			for j in range(i + 1, busy.size()):
				closest = minf(closest,
					busy[i].position.distance_to(busy[j].position))

	_expect(lane_conflicts == 0,
		"no two haulers ever hold the same driving lane")
	_expect(closest >= CLEARANCE,
		"haulers never overlap on the road (closest approach %.1f px, floor %.1f)"
			% [closest, CLEARANCE])
	_expect(worked.size() == haulers.size(),
		"every hauler gets on site at least once (%d of %d) — no starvation"
			% [worked.size(), haulers.size()])

	# Nothing may be left holding a lane or a yard reservation on teardown.
	for actor in haulers:
		actor.free()
	_expect(_world.yard._reservations.is_empty(),
		"tearing down every hauler returns every yard reservation")

	_world.queue_free()
	await get_tree().process_frame
	SaveManager.wipe()

	if failures.is_empty():
		print("TRAFFIC TESTS PASSED (%d simulated frames, closest approach %.1f px)"
			% [STEPS, closest])
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("TRAFFIC TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
