extends Node
## Container relay regression suite.
## Run with:
## Godot --headless --path . res://tests/relay_test_runner.tscn
##
## The relay is the only thing between a `CargoTransfer` and the player's eyes,
## and it is allowed to be slow, ugly or unlucky — it is *not* allowed to be a
## place where a container can stop. Every property below is about that:
##
##   * with no machine on the payroll, a move is the plain arc it always was;
##   * with a tractor, the box is lifted, driven and set down, and the tractor is
##     really underneath it while it travels;
##   * a fleet with nothing free falls back to that arc instead of queueing, and
##     a tractor freed mid-ride still ends with the box on its destination;
##   * a full ship call still discharges and loads to the last box.
##
## Everything here runs on the engine's own frame clock rather than on hand-fed
## deltas, because the landing squash is a `Tween` and a tween only advances on
## real frames. Stepping `_process` by hand *as well* was the first version of
## this suite, and it double-drove every actor: the tractors covered a leg in a
## fifth of the frames the itinerary was priced for, and the suite reported it as
## a bug in the relay. `Engine.time_scale` buys the speed instead, and it scales
## tweens and `_process` alike.

const TEST_SAVE_PATH := "user://harborclick_relay_test.json"
## Fast enough that a three-second drive is a couple of hundred frames, slow
## enough that a frame is still a small slice of one.
const TIME_SCALE := 3.0
## Frames to wait on any single box. Several times the longest itinerary the
## planner can produce, so exhausting it means stuck rather than slow.
const PATIENCE := 4000

var failures: Array[String] = []
var _world: RelayTestWorld


class RelayTestShip:
	extends Ship

	func arrive(_open_channel: bool = true) -> void:
		visible = true
		position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y)
		_set_phase(Ship.Phase.DISCHARGING)

	func depart(_open_channel: bool = true) -> void:
		_set_phase(Ship.Phase.AWAY)
		visible = false
		departed.emit()


class StuckTractor:
	extends Node
	## Books the run and never turns up. `CargoRelay` only ever asks a carrier
	## four things, so this is the whole contract.

	var released := false

	func relay_stage() -> int:
		return StructureActor.RELAY_APPROACH

	func relay_bed_position() -> Vector2:
		return Vector2.ZERO

	func relay_bed_rotation() -> float:
		return 0.0

	func release_relay() -> void:
		released = true


class RelayTestWorld:
	extends PortWorld
	## The real `fly_cargo` — that is the code under test — over the smallest
	## world that can host it.

	var sim := 0.0

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
		ship = RelayTestShip.new()
		ship.name = "Ship"
		add_child(ship)
		ships = [ship]
		traffic = TrafficCoordinator.new()
		berth = BerthCallController.new()
		berth.setup(self, ship, yard)
		berths = [berth]
		structures = StructureLayer.new()
		structures.world = self
		add_child(structures)
		structures.rebuild()

	func _process(delta: float) -> void:
		## The real world drives water, weather and arrivals from here; none of
		## that exists in this harness. Keeping the clock is all it has to do.
		sim += delta

	func show_cargo_reward(_pos: Vector2, _value: float, _crit: bool) -> void:
		pass

	func spawn_dust(_pos: Vector2) -> void:
		pass

	func relays() -> Array[CargoRelay]:
		var live: Array[CargoRelay] = []
		for child in overhead.get_children():
			if child is CargoRelay:
				live.append(child as CargoRelay)
		return live

	func machines() -> Array[StructureActor]:
		var all: Array[StructureActor] = []
		for child in entities.get_children():
			if child is StructureActor:
				all.append(child as StructureActor)
		for child in overhead.get_children():
			if child is StructureActor:
				all.append(child as StructureActor)
		return all


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	GameState.from_save({})
	seed(20260730)
	Engine.time_scale = TIME_SCALE

	_world = RelayTestWorld.new()
	add_child(_world)
	await get_tree().process_frame

	await _test_bare_terminal_flies()
	await _test_a_tractor_drives_the_box()
	await _test_a_busy_fleet_falls_back()
	await _test_carrier_freed_mid_ride()
	await _test_a_late_tractor_never_freezes_the_box()
	await _test_force_land_releases_every_claim()
	await _test_a_full_call_still_completes()
	await _test_a_road_plated_hauler_threads_the_gate_not_the_fence()

	_world.queue_free()
	await get_tree().process_frame
	Engine.time_scale = 1.0
	SaveManager.wipe()

	if failures.is_empty():
		print("RELAY TESTS PASSED (arc fallback, hand-off, abandonment, force-land, full call, gate crossing)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("RELAY TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


# --------------------------------------------------------------------- tests

func _test_bare_terminal_flies() -> void:
	## Nobody on the payroll: the box crosses on its own, exactly as before, and
	## in one leg rather than standing on an apron waiting for nobody.
	await _own([])
	var flight := _world.fly_cargo(0, _ship_point(), _yard_point())
	await get_tree().process_frame
	_expect(flight is CargoRelay, "every flight is a relay node")
	_expect((flight as CargoRelay)._legs.is_empty(),
		"an unequipped terminal plans no legs and keeps the plain arc")
	_expect(flight.duration() < 1.0,
		"and the arc keeps its old, short duration (%.2fs)" % flight.duration())
	flight.free()


func _test_a_tractor_drives_the_box() -> void:
	## The headline: lift, ride, set down — with the tractor really under the box
	## for the middle of it.
	await _own(["tt"])
	var landed := [false]
	var flight := _world.fly_cargo(0, _ship_point(), _yard_point())
	flight.landed.connect(func() -> void: landed[0] = true)
	await get_tree().process_frame
	var relay := flight as CargoRelay
	_expect(relay._legs.size() == 3,
		"an equipped terminal plans lift/ride/lift (%d legs)" % relay._legs.size())
	_expect(relay.duration() > 1.5,
		"and the itinerary is priced as a drive, not a throw (%.2fs)"
			% relay.duration())

	var carried := 0.0
	var carrier_gap := 0.0
	var frames := 0
	while frames < PATIENCE and not landed[0]:
		if is_instance_valid(relay):
			var carrier: Node = relay._carrier
			if carrier != null and is_instance_valid(carrier) \
					and int(carrier.call("relay_stage")) == StructureActor.RELAY_CARRY:
				carried += get_process_delta_time()
				carrier_gap = maxf(carrier_gap,
					relay.position.distance_to(carrier.position))
		await get_tree().process_frame
		frames += 1
	_expect(landed[0], "a driven box still lands (%d frames)" % frames)
	_expect(carried > 0.8,
		"and spends real time on a chassis (%.2fs)" % carried)
	_expect(carrier_gap < 1.0,
		"the box is on the tractor, not near it (worst gap %.2f px)" % carrier_gap)
	_expect(_claimed_machines() == 0,
		"and no machine is left holding a container that has landed")


func _test_a_busy_fleet_falls_back() -> void:
	## The whole fleet is already under a box. The next move must not queue behind
	## it — this is what keeps a tap feeling like a tap, so it is asserted rather
	## than assumed: no chassis, no relay, old speed.
	await _own(["tt"])
	for actor in _world.machines():
		_expect(actor.take_relay_haul(Vector2(204.0, 200.0), Vector2(94.0, 243.0)),
			"the fleet really was put to work first")
	var landed := [false]
	var flight := _world.fly_cargo(1, _ship_point(), _yard_point())
	flight.landed.connect(func() -> void: landed[0] = true)
	await get_tree().process_frame
	_expect((flight as CargoRelay)._legs.is_empty(),
		"a move with no free chassis plans no legs")
	_expect(flight.duration() < 1.0,
		"and crosses at the old speed (%.2fs)" % flight.duration())
	var frames := 0
	while frames < PATIENCE and not landed[0]:
		await get_tree().process_frame
		frames += 1
	_expect(landed[0], "and still lands")


func _test_carrier_freed_mid_ride() -> void:
	## A tractor that disappears from under the box — rebuilt on a land purchase,
	## reset by a prestige — must not take the container with it.
	await _own(["tt"])
	var landed := [false]
	var flight := _world.fly_cargo(2, _ship_point(), _yard_point())
	flight.landed.connect(func() -> void: landed[0] = true)
	await get_tree().process_frame
	var relay := flight as CargoRelay
	var killed := false
	var frames := 0
	while frames < PATIENCE and not landed[0]:
		if is_instance_valid(relay) and not killed:
			var carrier: Node = relay._carrier
			if carrier != null and is_instance_valid(carrier) \
					and int(carrier.call("relay_stage")) == StructureActor.RELAY_CARRY:
				carrier.free()
				killed = true
		await get_tree().process_frame
		frames += 1
	_expect(killed, "the run really did reach a tractor before it was killed")
	_expect(landed[0], "and the box lands anyway when its carrier is freed")
	_expect(not is_instance_valid(relay),
		"the traveller frees itself after landing")


func _test_a_late_tractor_never_freezes_the_box() -> void:
	## The reported bug, as a test. A box left the hull, stopped dead on the quay
	## and stayed there while its tractor fought its way over — and because the
	## berth counts a transfer as in flight until it lands, the ship could not
	## change phase and the player could not tap anything. One slow tractor froze
	## the terminal.
	##
	## The tractor here never arrives at all: a stub that reports "on my way"
	## forever, which is the worst case the old code waited a full ride deadline
	## for. The box may rest on the apron for about a crane cycle; past that it
	## flies itself, whatever the fleet is doing.
	await _own(["tt"])
	var landed := [false]
	var flight := _world.fly_cargo(3, _ship_point(), _yard_point())
	flight.landed.connect(func() -> void: landed[0] = true)
	await get_tree().process_frame
	var relay := flight as CargoRelay
	_expect(relay._legs.size() == 3, "the itinerary really was planned as a drive")
	var planned := relay.duration()
	var real_carrier: Node = relay._carrier
	_expect(real_carrier != null and is_instance_valid(real_carrier),
		"a tractor took the run")
	if real_carrier != null and is_instance_valid(real_carrier):
		real_carrier.call("release_relay")
	var stub := StuckTractor.new()
	add_child(stub)
	relay._carrier = stub

	var waited := 0.0
	var frames := 0
	while frames < PATIENCE and not landed[0]:
		waited += get_process_delta_time()
		await get_tree().process_frame
		frames += 1
	_expect(landed[0], "the box lands even though its tractor never arrived")
	# Bounded against the itinerary the relay itself priced, not against the
	# constant under test — a limit written as `APPROACH_GRACE + slack` passes
	# whatever `APPROACH_GRACE` is set to, which is no limit at all. A stalled
	# presentation may cost about one extra itinerary, and not a ride deadline.
	_expect(waited < planned * 2.0 + 2.0,
		"and promptly: %.2fs against a %.2fs itinerary" % [waited, planned])
	_expect(stub.released, "the stalled tractor got its run back")
	stub.queue_free()
	await get_tree().process_frame


func _test_force_land_releases_every_claim() -> void:
	## The capture harness force-lands travellers so a screenshot is never taken
	## mid-flight. Doing that must leave no machine holding a box that is gone.
	await _own(["tt", "sts", "rtg"])
	var flight := _world.fly_cargo(3, _ship_point(), _yard_point())
	await get_tree().process_frame
	var relay := flight as CargoRelay
	for frame in 30:
		await get_tree().process_frame
	_expect(relay._leg >= 0, "the itinerary started")
	relay._finish_landing()
	await get_tree().process_frame
	_expect(_claimed_machines() == 0,
		"force-landing releases every claim (%d machine(s) still holding)"
			% _claimed_machines())


func _test_a_full_call_still_completes() -> void:
	## The property the whole fallback design exists to protect: with the relay
	## on, a hull discharges and loads to the last box and leaves.
	await _own(["tt", "sts", "rtg"])
	_world.yard.restore({"version": 3, "slots": []})
	_world.yard.seed_new()
	_world.berth.seed_new(4242)
	_world.ship.arrive()
	var capacity := _world.ship.bay_capacity()
	var completed := [false]
	_world.berth.call_completed.connect(func(_s: Dictionary) -> void:
		completed[0] = true)

	var frames := 0
	while frames < PATIENCE * 4 and not completed[0]:
		_world.berth.handle_tap(_world.ship.global_position)
		await get_tree().process_frame
		frames += 1
	_expect(completed[0],
		"a full call completes through the relay (%d frames)" % frames)
	_expect(_world.ship.cargo_left() == capacity,
		"and the hull leaves full (%d/%d)"
			% [_world.ship.cargo_left(), capacity])
	_expect(_world.relays().is_empty(), "with nothing left in the air")
	_expect(_world.yard._reservations.is_empty(),
		"and every yard reservation returned (%d held)"
			% _world.yard._reservations.size())


func _test_a_road_plated_hauler_threads_the_gate_not_the_fence() -> void:
	## The reported bug, as a test. `empilhadeira` and `reach_stacker` park
	## off-site at `PortLayout.gate_entry()` when idle — see
	## `structure_layer.gd`'s `_place()` — so their first relay leg starts
	## north of `FENCE_Y` and has to cross it to reach a box. The plain spine
	## route used to cross wherever the quay lane happens to sit, nowhere near
	## the one gap in the fence, and drove the machine through the posts to
	## prove it.
	for id: String in ["empilhadeira", "reach_stacker"]:
		await _own([id])
		var actor: StructureActor = null
		for candidate in _world.machines():
			if candidate.id == id:
				actor = candidate
		_expect(actor != null, "%s is on the payroll to inspect" % id)
		if actor == null:
			continue
		_expect(actor.position.y < PortLayout.FENCE_Y,
			"%s starts off-site, at the gate (y=%.1f)" % [id, actor.position.y])

		var pickup := Vector2(94.0, 243.0)                # deep in the yard
		_expect(actor.take_relay_haul(pickup, Vector2(150.0, 300.0)),
			"%s accepts a relay haul from the gate" % id)

		var trail: Array[Vector2] = [actor.position]
		trail.append_array(actor._waypoints)
		for i in trail.size() - 1:
			var a: Vector2 = trail[i]
			var b: Vector2 = trail[i + 1]
			if (a.y < PortLayout.FENCE_Y) == (b.y < PortLayout.FENCE_Y):
				continue
			# This leg crosses the fence, which has exactly one gap: the
			# carriageway between the kerbs.
			_expect(a.x >= PortLayout.ROAD_X0 and a.x <= PortLayout.ROAD_X1,
				"%s crosses the fence on the road (x=%.1f), not through it"
					% [id, a.x])
			_expect(is_equal_approx(a.x, b.x),
				"%s crosses the fence going straight, not on the diagonal" % id)
		_expect(trail[trail.size() - 1] == pickup,
			"%s's route still ends at the box (%s)" % [id, trail[trail.size() - 1]])


# ------------------------------------------------------------------- helpers

func _own(ids: Array) -> void:
	## Rebuild the payroll for one test. Rebuilding is also what clears anything
	## the previous test left driving: every actor is replaced.
	GameState.from_save({})
	GameState.teus = 1e21
	GameState.lifetime_teus = 1e21
	for id in ids:
		# Some machines wait on a parcel — `reach_stacker` on `patio_norte`, for
		# one — and `buy_structure` is a silent no-op against a locked one.
		var gate := LandDB.gate_for(str(id))
		if not gate.is_empty():
			GameState.land[str(gate.id)] = true
		GameState.buy_structure(str(id))
	_world.structures.rebuild()
	await get_tree().process_frame
	for actor in _world.machines():
		actor._cooldown = 0.0


func _claimed_machines() -> int:
	var held := 0
	for actor in _world.machines():
		if is_instance_valid(actor) \
				and actor.relay_stage() != StructureActor.RELAY_NONE:
			held += 1
	return held


func _ship_point() -> Vector2:
	return Vector2(PortLayout.SHIP_X + 20.0, PortLayout.SHIP_Y + 60.0)


func _yard_point() -> Vector2:
	return _world.yard.slot_position(4) + Vector2(PortLayout.BOX_W,
		PortLayout.BOX_H) * 0.5


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
