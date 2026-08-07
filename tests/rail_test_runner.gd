extends Node
## The branch line: block trains from the interior, and the shunt that lets one
## leave a stub-ended siding.
## Run with:
## Godot --headless --path . res://tests/rail_test_runner.tscn
##
## The rail is the terminal's third door and it answers to the same contract as
## the second: nothing is conjured at the ramp, the yard's operational floor is
## the road's floor, and a service always finishes even with nobody drawing it.
## The extra thing it has to prove is the run-around — a locomotive that cannot
## reach the other end of its train is a train that never leaves.

const TEST_SAVE_PATH := "user://harborclick_rail_test.json"

## The roll call, and the reason there is one.
##
## A GDScript runtime error does not raise: it prints, aborts the function it
## happened in, and hands control back to the caller as if that function had
## returned. A suite that only counts *assertions it was given* therefore reports
## a test that died on its first line as a pass — and this one did exactly that.
## Two rail tests spent a build silently not running, because `RailRake.new()`
## was failing against a sprite the importer had never been shown, and the suite
## printed PASSED underneath the stack traces.
##
## Every test below names itself as its *last* statement. A test that aborts
## never gets there, and the roll call at the end turns its absence into a
## failure with the test's own name on it.
const EXPECTED := [
	"plans", "orders", "order_never_deadlocks", "stock_floor", "fill_empty_yard",
	"no_conjuring", "parked_only", "reload", "order_survives_reload", "headless",
	"aspects", "completion_bonus", "report", "run_around", "run_around_loop",
	"rake_is_not_six_copies", "smoke",
]

var failures: Array[String] = []
var _finished: Dictionary = {}
var _world: RailTestWorld


class RailTestWorld:
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
		rail = RailYard.new()
		rail.setup(self, yard)

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
	seed(70117)

	_world = RailTestWorld.new()
	add_child(_world)
	await get_tree().process_frame

	_test_every_service_plan_is_honest()
	_test_every_standing_order_is_honest()
	_test_no_order_can_deadlock_the_yard()
	_test_the_branch_protects_one_complete_shipload()
	await _test_a_loaded_rake_can_fill_an_empty_yard()
	await _test_the_ramp_never_creates_cargo()
	await _test_a_rake_is_only_worked_while_it_stands()
	await _test_a_service_survives_a_reload()
	_test_the_standing_order_survives_a_reload()
	_test_a_service_finishes_with_nobody_watching()
	_test_the_signal_says_what_the_branch_is_doing()
	_test_only_a_finished_composition_is_paid_a_bonus()
	_test_the_branch_reports_itself()
	_test_the_loco_runs_round_its_own_train()
	_test_the_run_around_uses_the_loop_that_is_painted()
	_test_a_rake_is_not_six_copies_of_one_wagon()
	_test_a_working_locomotive_makes_smoke()

	for label in EXPECTED:
		_expect(_finished.has(label), "the '%s' test ran to the end" % label)

	SaveManager.wipe()
	if failures.is_empty():
		print("RAIL TESTS PASSED (%d tests: plans, standing orders, stock floor, "
			% EXPECTED.size()
			+ "in when empty, no conjuring, parked-only work, reload, headless "
			+ "service, aspects, completion bonus, report, run-around, rake)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("RAIL TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _done(label: String) -> void:
	## The last statement of every test. See `EXPECTED`.
	_finished[label] = true


# ------------------------------------------------------------------ the plan

func _test_every_service_plan_is_honest() -> void:
	## The road's three bands, at a train's scale. Only a yard with no room left
	## to work a ship may be cleared, and even then the rake still brings a box.
	for wagons in [RailCargoPolicy.SHORT_RAKE, RailCargoPolicy.FULL_RAKE]:
		for fill in [0.0, 0.2, 0.5, 0.7, 0.93, RailCargoPolicy.DRAIN_FILL, 1.0]:
			var plan := RailCargoPolicy.service_plan(fill, 0.5, wagons)
			var drops := int(plan.drops)
			var lifts := int(plan.lifts)
			_expect(drops >= 1, "a service always brings something (%.2f)" % fill)
			_expect(drops <= wagons and lifts <= wagons,
				"a service never exceeds the rake it has (%.2f)" % fill)
			if fill < RailCargoPolicy.DRAIN_FILL:
				_expect(RailCargoPolicy.is_non_deficit(plan),
					"below the drain line the branch never drains the yard (%.2f)" % fill)
			else:
				_expect(RailCargoPolicy.is_draining(plan),
					"a packed yard gets a clearing service (%.2f)" % fill)
	_expect(RailCargoPolicy.rake_length(true) > RailCargoPolicy.rake_length(false),
		"buying the branch is what makes the train longer")
	_expect(RailCargoPolicy.service_gap(true).y < RailCargoPolicy.service_gap(false).x,
		"and what makes it come back sooner")
	_done("plans")


func _test_every_standing_order_is_honest() -> void:
	## The order biases the exchange. It may not break the contract the plans are
	## held to, so every one of them goes through the same sweep the default
	## gets — an order that could produce an empty train, or a wagon that does
	## not exist, would be a bug the player chose.
	for order: StringName in RailCargoPolicy.ORDERS:
		for wagons in [RailCargoPolicy.SHORT_RAKE, RailCargoPolicy.FULL_RAKE]:
			for fill in [0.0, 0.2, 0.5, 0.7, 0.93]:
				var plan := RailCargoPolicy.service_plan(fill, 0.5, wagons, order)
				var drops := int(plan.drops)
				var lifts := int(plan.lifts)
				_expect(drops >= 1,
					"%s still brings something (%.2f)" % [order, fill])
				_expect(drops <= wagons and lifts <= wagons,
					"%s never exceeds the rake it has (%.2f)" % [order, fill])
				_expect(RailCargoPolicy.is_non_deficit(plan),
					"%s never drains a yard that is not jammed (%.2f)"
						% [order, fill])
	# And the orders have to actually differ, or they are three buttons wired to
	# one behaviour — which is the failure mode a standing order exists to avoid.
	var wagons := RailCargoPolicy.FULL_RAKE
	var supply := RailCargoPolicy.service_plan(0.5, 0.5, wagons,
		RailCargoPolicy.ORDER_SUPPLY)
	var clear := RailCargoPolicy.service_plan(0.5, 0.5, wagons,
		RailCargoPolicy.ORDER_CLEAR)
	var balanced := RailCargoPolicy.service_plan(0.5, 0.5, wagons,
		RailCargoPolicy.ORDER_BALANCED)
	_expect(int(supply.drops) - int(supply.lifts)
			> int(balanced.drops) - int(balanced.lifts),
		"ABASTECER grows the yard faster than the default does")
	_expect(int(clear.drops) + int(clear.lifts)
			> int(balanced.drops) + int(balanced.lifts),
		"ESCOAR works more boxes per service than the default does")
	_expect(int(clear.drops) == int(clear.lifts),
		"and leaves the yard exactly where it found it")
	_expect(RailCargoPolicy.coerce_order(&"nonsense")
			== RailCargoPolicy.ORDER_BALANCED,
		"an order from a save this build has never heard of is the default")
	_done("orders")


func _test_no_order_can_deadlock_the_yard() -> void:
	## The clearing band is what breaks the jam a full import yard would
	## otherwise be: no landing is legal, so no discharge can proceed, so nothing
	## on the map will ever open a slot. A standing order the player could use to
	## switch that escape off would be a way of bricking their own port, so the
	## drain band is read before the order is.
	for order: StringName in RailCargoPolicy.ORDERS:
		for fill in [RailCargoPolicy.DRAIN_FILL, 0.97, 1.0]:
			var plan := RailCargoPolicy.service_plan(
				fill, 0.5, RailCargoPolicy.FULL_RAKE, order)
			_expect(RailCargoPolicy.is_draining(plan),
				"a packed yard is cleared whatever the order says (%s, %.2f)"
					% [order, fill])
			_expect(int(plan.drops) >= 1,
				"and the clearing service still brings a box (%s)" % order)
	_done("order_never_deadlocks")


func _test_the_branch_protects_one_complete_shipload() -> void:
	_expect(RailCargoPolicy.MIN_OPERATIONAL_STOCK
			== RoadCargoPolicy.MIN_OPERATIONAL_STOCK,
		"both land-side doors defend the same floor")
	_world.yard.restore({"version": 3, "slots": []})
	for slot in RailCargoPolicy.MIN_OPERATIONAL_STOCK:
		_world.yard.place(slot % _world.yard.total_slots(), 0, slot % 8)
	var stock := _yard_uids().size()
	_expect(stock <= RailCargoPolicy.MIN_OPERATIONAL_STOCK,
		"the yard is at the floor for this case (%d)" % stock)
	_expect(not _world.has_road_pickup(PackedStringArray()),
		"nothing may be taken inland once the floor is reached")
	_done("stock_floor")


# ----------------------------------------------------------------- the moves

func _test_a_loaded_rake_can_fill_an_empty_yard() -> void:
	_world.yard.restore({"version": 3, "slots": []})
	_world.rail.seed_new()
	_world.rail.service = _make_service(4, 4, 0)
	_expect(_world.yard.fill_ratio() <= 0.0, "the yard starts empty")

	var landed := 0
	for attempt in 4:
		if _world.rail.work_once():
			landed += 1
		await _settle()
	_expect(landed == 4, "every wagon that came in loaded can be stripped")
	var in_yard := _yard_uids()
	_expect(in_yard.size() == 4,
		"and each one lands exactly once (%d)" % in_yard.size())
	_expect(int(_world.rail.service.drops) == 0,
		"the service reports itself stripped when the wagons are clear")
	_done("fill_empty_yard")


func _test_the_ramp_never_creates_cargo() -> void:
	## Entry paths are enumerated in docs/architecture/cargo-flow.md and a yard
	## landing is not one of them. Every UID that reaches the stacks off a train
	## has to be a UID that was on the train when it arrived.
	_world.yard.restore({"version": 3, "slots": []})
	_world.rail.seed_new()
	_world.rail.service = _make_service(3, 3, 0)
	var manifest := {}
	for uid in _world.rail._arrival_uids():
		manifest[uid] = true
	for attempt in 3:
		_world.rail.work_once()
		await _settle()
	var landed := _yard_uids()
	for uid in landed:
		_expect(manifest.has(uid), "a box in the yard came off the train")
	_expect(landed.size() == 3,
		"the whole rake is accounted for in the yard (%d)" % landed.size())
	_done("no_conjuring")


func _test_a_rake_is_only_worked_while_it_stands() -> void:
	_world.yard.restore({"version": 3, "slots": []})
	_world.rail.seed_new()
	_world.rail.service = _make_service(2, 2, 0)
	for stage in [RailYard.Stage.ARRIVING, RailYard.Stage.RUNAROUND,
			RailYard.Stage.DEPARTING]:
		_world.rail.service["stage"] = int(stage)
		_expect(not _world.rail.can_work(),
			"a moving train offers no work (stage %d)" % int(stage))
		_expect(not _world.rail.work_once(),
			"and refuses one (stage %d)" % int(stage))
		_expect(not _world.rail.handle_tap(PortLayout.rail_wagon_centre(0)),
			"and cannot be tapped (stage %d)" % int(stage))
	_world.rail.service["stage"] = int(RailYard.Stage.WORKING)
	_expect(_world.rail.can_work(), "a standing train offers work")
	_expect(_world.rail.handle_tap(PortLayout.rail_wagon_centre(0)),
		"and a tap on a wagon works it")
	await _settle()
	_done("parked_only")


func _test_a_service_survives_a_reload() -> void:
	_world.yard.restore({"version": 3, "slots": []})
	_world.rail.seed_new()
	_world.rail.service = _make_service(3, 3, 2)
	var before := PackedStringArray()
	for slot in _world.rail.length():
		var unit := _world.rail.wagon_unit(slot)
		if unit != null:
			before.append(unit.uid)
	var snapshot := _world.rail.snapshot()
	_world.rail.seed_new()
	_expect(_world.rail.service.is_empty(), "a new game starts with a quiet branch")
	_world.rail.restore(snapshot)
	_expect(_world.rail.length() == 3, "the rake comes back the length it was")
	var after := PackedStringArray()
	for slot in _world.rail.length():
		var unit := _world.rail.wagon_unit(slot)
		if unit != null:
			after.append(unit.uid)
	_expect(after == before, "every box on it comes back exactly once")
	_expect(_world.rail.stage() == RailYard.Stage.WORKING,
		"a restored service is standing at the ramp, not replaying its run in")
	_world.rail.seed_new()
	await get_tree().process_frame
	_done("reload")


func _test_a_service_finishes_with_nobody_watching() -> void:
	## Headless, or a save restored into a scene that never builds a rake: every
	## stage the view would normally end has a timeout, so the branch can never
	## block on a train nobody is drawing.
	_world.yard.restore({"version": 3, "slots": []})
	_world.rail.seed_new()
	_world.rail._next_service = 0.01
	var seen := {}
	var guard := 0
	while guard < 20000:
		guard += 1
		_world.rail.tick(1.0 / 30.0)
		seen[int(_world.rail.stage())] = true
		if seen.has(int(RailYard.Stage.DEPARTING)) and _world.rail.service.is_empty():
			break
	_expect(guard < 20000, "an unwatched service reaches the end of its cycle")
	for stage in [RailYard.Stage.ARRIVING, RailYard.Stage.WORKING,
			RailYard.Stage.RUNAROUND, RailYard.Stage.DEPARTING]:
		_expect(seen.has(int(stage)),
			"it passes through every stage (%d)" % int(stage))
	_world.rail.seed_new()
	_done("headless")


func _test_the_signal_says_what_the_branch_is_doing() -> void:
	_world.rail.seed_new()
	_world.rail._next_service = RailYard.SIGNAL_LEAD + 10.0
	_expect(_world.rail.signal_aspect() == RailYard.ASPECT_CLEAR,
		"a quiet branch shows a clear road")
	_world.rail._next_service = RailYard.SIGNAL_LEAD - 1.0
	_expect(_world.rail.signal_aspect() == RailYard.ASPECT_APPROACH,
		"the signal clears before the train appears, not after")
	_world.rail.service = _make_service(1, 1, 0)
	_expect(_world.rail.signal_aspect() == RailYard.ASPECT_DANGER,
		"a train at the ramp puts the section back to danger")
	_world.rail.service["stage"] = int(RailYard.Stage.DEPARTING)
	_expect(_world.rail.signal_aspect() == RailYard.ASPECT_APPROACH,
		"a train on the move is not a clear road either")
	_world.rail.seed_new()
	_done("aspects")


func _test_the_standing_order_survives_a_reload() -> void:
	## A standing order is not a preference. It changes what the port produces,
	## so it belongs to the run and has to come back with it.
	GameState.rail_order = RailCargoPolicy.ORDER_CLEAR
	var saved := GameState.to_save()
	GameState.rail_order = RailCargoPolicy.ORDER_SUPPLY
	GameState.from_save(saved)
	_expect(GameState.rail_order == RailCargoPolicy.ORDER_CLEAR,
		"the order the player set is the order that comes back")
	GameState.from_save({})
	_expect(GameState.rail_order == RailCargoPolicy.ORDER_BALANCED,
		"and a save written before orders existed gets the default")
	_done("order_survives_reload")


func _test_only_a_finished_composition_is_paid_a_bonus() -> void:
	## The branch pays per box on the way past. The bonus is for the *last* two
	## wagons — the ones a player has to choose to go back down and work rather
	## than letting the dwell run out on them — so it must not fall out of a
	## train that merely turned up.
	_world.rail.seed_new()
	var before := GameState.teus
	_world.rail.service = _make_service(3, 3, 0)
	_world.rail.service["booked"] = 3
	_world.rail.service["moved"] = 1
	_world.rail.notify_departed()
	_expect(is_equal_approx(GameState.teus, before),
		"a rake that went home with work outstanding is paid nothing extra")

	_world.rail.service = _make_service(3, 3, 0)
	_world.rail.service["booked"] = 3
	_world.rail.service["moved"] = 3
	_world.rail.notify_departed()
	_expect(GameState.teus > before,
		"a composition worked to the last wagon is worth a bonus")
	_expect(_world.rail.service.is_empty(),
		"and settling the service is still what clears it")

	# A service with nothing booked cannot be "complete": paying for it would be
	# paying for a train that never came.
	var idle_before := GameState.teus
	_world.rail.service = _make_service(2, 0, 0)
	_world.rail.service["booked"] = 0
	_world.rail.service["moved"] = 0
	_world.rail.notify_departed()
	_expect(is_equal_approx(GameState.teus, idle_before),
		"a service with nothing on its plan is not a completed one")
	_world.rail.seed_new()
	_done("completion_bonus")


func _test_the_branch_reports_itself() -> void:
	## The orders board is the branch's only instrument, and it reads this. A
	## report that disagreed with the controller would be worse than no report:
	## the player cannot see the train to check it against.
	_world.rail.seed_new()
	var idle := _world.rail.report()
	_expect(bool(idle.idle) and not bool(idle.standing),
		"a quiet branch reports itself quiet")
	_expect(float(idle.eta) > 0.0, "with a time on the next service")

	GameState.rail_order = RailCargoPolicy.ORDER_SUPPLY
	_expect(_world.rail.order() == RailCargoPolicy.ORDER_SUPPLY,
		"an idle branch reports the order the next train will be booked with")

	_world.rail.service = _make_service(4, 3, 1)
	_world.rail.service["order"] = RailCargoPolicy.ORDER_CLEAR
	var standing := _world.rail.report()
	_expect(bool(standing.standing) and not bool(standing.idle),
		"a train at the ramp reports itself standing")
	_expect(int(standing.drops) == 3 and int(standing.lifts) == 1,
		"with the work it still has on it")
	_expect(int(standing.length) == 4, "and the rake it is")
	_expect(standing.order == RailCargoPolicy.ORDER_CLEAR,
		"an order changed mid-service applies to the next train, not this one")
	_expect(standing.aspect == RailYard.ASPECT_DANGER,
		"and the report agrees with the signal beside the line")
	_world.rail.seed_new()
	GameState.rail_order = RailCargoPolicy.ORDER_BALANCED
	_done("report")


# ------------------------------------------------------------- the shunt

func _test_the_loco_runs_round_its_own_train() -> void:
	## The whole reason this exists. The rake runs in with the loco at the head,
	## and has to leave with the loco at what was the tail — by driving there.
	var rake := RailRake.new()
	rake.setup(4, true)
	add_child(rake)
	var head := rake._loco.position.x
	_expect(head > PortLayout.rail_wagon_x(0),
		"the loco stands at the buffer-stop end of its train on arrival")

	rake.run_around()
	var done := _drive(rake, func() -> bool: return rake.mode == RailRake.Mode.STANDING)
	_expect(done, "the run-around finishes")
	_expect(rake._loco.position.x < PortLayout.rail_wagon_x(3),
		"and leaves the loco at the other end, past the last wagon")
	_expect(rake._loco.scale.y < 0.0,
		"facing the way it is about to go")

	rake.run_out()
	var gone := _drive(rake, func() -> bool: return rake.mode == RailRake.Mode.GONE)
	_expect(gone, "and the train can then leave the way it came")
	rake.queue_free()
	_done("run_around")


func _test_the_run_around_uses_the_loop_that_is_painted() -> void:
	## The shunt is drawn on the ground by `GroundBaker._paint_rail_corridor`.
	## If the loco crossed anywhere else it would be running over ballast.
	var rake := RailRake.new()
	rake.setup(4, true)
	add_child(rake)
	rake.run_around()
	var on_loop := false
	var east_of_train := false
	for step in 6000:
		rake._process(1.0 / 60.0)
		if absf(rake._loco.position.y - PortLayout.rail_loop_y()) < 0.6:
			on_loop = true
			if rake._loco.position.x > PortLayout.rail_wagon_x(0):
				east_of_train = true
		if rake.mode == RailRake.Mode.STANDING:
			break
	_expect(on_loop, "the loco actually uses the run-around road")
	_expect(east_of_train,
		"having first drawn forward clear of its train, as a shunt does")
	_expect(absf(rake._loco.position.y - PortLayout.rail_y()) < 0.6,
		"and comes back down onto the running line to couple up")
	rake.queue_free()
	_done("run_around_loop")


func _test_a_rake_is_not_six_copies_of_one_wagon() -> void:
	## `veh_wagon` is a three-frame sheet and a rake is dealt from it. The point
	## is the silhouette: six identical vehicles read as a decal of a train, and
	## the branch is the one part of the terminal a player has to *choose* to
	## scroll down to. It has to pay for the trip.
	var rake := RailRake.new()
	rake.setup(RailCargoPolicy.FULL_RAKE, true)
	add_child(rake)
	var kinds := {}
	var previous := -1
	for slot in RailCargoPolicy.FULL_RAKE:
		var kind := rake._wagon_kind(slot)
		_expect(kind >= 0 and kind < RailRake.WAGON_DEAL.size(),
			"wagon %d is dealt a frame that exists" % slot)
		_expect(kind != previous,
			"no two coupled wagons are the same vehicle (slot %d)" % slot)
		previous = kind
		kinds[kind] = true
	_expect(kinds.size() >= 3, "and the whole fleet turns up in a full rake")
	# The deal is by slot, so the same service is the same train after a reload
	# rather than reshuffling itself every time the view is rebuilt.
	var twin := RailRake.new()
	twin.setup(RailCargoPolicy.FULL_RAKE, true)
	add_child(twin)
	for slot in RailCargoPolicy.FULL_RAKE:
		_expect(twin._wagon_kind(slot) == rake._wagon_kind(slot),
			"a restored rake comes back the same train (slot %d)" % slot)
	rake.queue_free()
	twin.queue_free()
	_done("rake_is_not_six_copies")


func _test_a_working_locomotive_makes_smoke() -> void:
	## The plume is the only thing on the branch that says the engine is under
	## load, and it is the hardest thing here to check by looking: the branch is
	## forty pixels tall at the bottom of a phone screen, and "I cannot see any
	## smoke" and "there is no smoke" are the same picture. So it is asserted.
	##
	## The first version of it was built before the locomotive and drew behind it,
	## which put every puff under the one object guaranteed to be in the way.
	var rake := RailRake.new()
	rake.setup(4, false)
	add_child(rake)
	rake.set_process(false)

	var lit_while_running := false
	var seen := 0
	for step in 400:
		rake._process(1.0 / 60.0)
		lit_while_running = lit_while_running or rake._lamp.visible
		seen = maxi(seen, _visible_puffs(rake))
	_expect(seen > 0, "a locomotive running in leaves a plume behind it")
	_expect(lit_while_running, "and runs with its headlight on")

	# Drawn *over* the train, because the camera looks down and exhaust rises
	# towards it. Index order is draw order for siblings on the same layer.
	var loco_index := rake._loco.get_index()
	for puff in rake._smoke:
		_expect(puff.get_index() > loco_index,
			"the plume draws over the locomotive that made it")

	# And it stops when the train does, or the rake stands at the ramp for two
	# and a half minutes fuming like it is about to leave.
	for step in 200:
		rake._process(1.0 / 60.0)
	_expect(rake.mode == RailRake.Mode.STANDING, "the rake reaches the ramp")
	for step in 200:
		rake._process(1.0 / 60.0)
	_expect(_visible_puffs(rake) == 0, "a stabled locomotive stops smoking")
	_expect(not rake._lamp.visible, "and puts its headlight out")
	rake.queue_free()
	_done("smoke")


func _visible_puffs(rake: RailRake) -> int:
	var count := 0
	for puff in rake._smoke:
		if puff.visible and puff.modulate.a > 0.01:
			count += 1
	return count


# ------------------------------------------------------------------ helpers

func _yard_uids() -> PackedStringArray:
	## Every identity standing in the yard, straight off its own snapshot.
	var uids := PackedStringArray()
	var snapshot: Dictionary = _world.yard.snapshot()
	for stack in snapshot.get("slots", []):
		for unit in stack as Array:
			if unit is Dictionary:
				uids.append(str((unit as Dictionary).get("uid", "")))
	return uids


func _make_service(length: int, drops: int, lifts: int) -> Dictionary:
	var wagons: Array = []
	var arrival_uids := PackedStringArray()
	for slot in length:
		if slot < drops:
			var unit := CargoUnit.new(CargoUnit.new_uid("rail"),
				CargoUnit.EXPORT, slot % 8, "interior")
			wagons.append(unit)
			arrival_uids.append(unit.uid)
		else:
			wagons.append(null)
	return {"wagons": wagons, "arrival_uids": arrival_uids, "length": length,
		"drops": drops, "lifts": lifts, "pending": 0, "lifting": 0,
		"dwell": RailYard.DWELL_SECONDS,
		"stage": int(RailYard.Stage.WORKING),
		"transit": RailYard.TRANSIT_TIMEOUT}


func _drive(rake: RailRake, done: Callable, steps: int = 6000) -> bool:
	## Stepped by hand at a fixed rate rather than in real time: the shunt is a
	## couple of hundred pixels at thirty a second, and a test should not spend
	## ten seconds watching it.
	rake.set_process(false)
	for step in steps:
		if done.call():
			return true
		rake._process(1.0 / 60.0)
	return done.call()


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
