extends Node
## The crew: identity, the task board, and the vessel's answer to a box landing.
## Run with:
## Godot --headless --path . res://tests/npc_test_runner.tscn
##
## Three properties matter here and none of them can be judged from a screenshot:
##
## 1. A person is persistent. Equipment is rebuilt on every parcel, prestige and
##    reload; the operator, their hire date and their tally are not.
## 2. Two people are never given the same job. Not "usually" — the board hands a
##    key out once, and the land-side station is the one that used to send two
##    drivers to the same stack and let the second arrive to nothing.
## 3. A box changing hands heels the hull *both* ways. The old nudge was
##    unsigned, so a working berth listed permanently to one side.

const TEST_SAVE_PATH := "user://harborclick_npc_test.json"

var failures: Array[String] = []
var _world: NpcTestWorld


class NpcTestShip:
	extends Ship

	func arrive(_open_channel: bool = true) -> void:
		visible = true
		position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y)
		_set_phase(Ship.Phase.DISCHARGING)


class NpcTestWorld:
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
		ship = NpcTestShip.new()
		ship.name = "Ship"
		add_child(ship)
		traffic = TrafficCoordinator.new()
		crew = NpcRoster.new()
		tasks = TaskBoard.new()
		tasks.setup(self, crew)
		berth = BerthCallController.new()
		berth.setup(self, ship, yard)
		gate = GateDock.new()
		gate.setup(self, yard)

	func fly_cargo(color: int, from: Vector2, to: Vector2) -> FlyingContainer:
		var flight := FlyingContainer.new()
		flight.setup(_sheet, color, from, to)
		overhead.add_child(flight)
		return flight

	func target_fill() -> float:
		return 0.1

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
	TimeManager.from_save({"day": 12})
	seed(30072026)

	_world = NpcTestWorld.new()
	add_child(_world)
	await get_tree().process_frame

	_test_the_catalog_only_staffs_the_container_chain()
	_test_a_person_is_persistent_and_unique()
	_test_the_special_crew_is_where_it_says_it_is()
	await _test_one_key_one_owner()
	await _test_two_drivers_are_never_sent_to_one_stack()
	_test_every_station_says_what_it_is_doing()
	await _test_tapping_somebody_opens_their_dossier()
	await _test_holding_somebody_picks_them_up()
	_test_everything_the_crew_says_is_printable()
	await _test_a_landing_box_rolls_the_hull_both_ways()
	_test_the_landing_sound_has_six_takes()

	if is_instance_valid(_world):
		_world.free()
	SaveManager._sections.clear()
	SaveManager.wipe()

	if failures.is_empty():
		print("NPC TESTS PASSED")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("NPC TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


# ------------------------------------------------------------------- catalogue

func _test_the_catalog_only_staffs_the_container_chain() -> void:
	## A building is not a person. The crew is short on purpose, and every role on
	## it has to be able to say why it exists.
	var stations := [
		NpcCatalog.STATION_BERTH, NpcCatalog.STATION_YARD,
		NpcCatalog.STATION_STACK, NpcCatalog.STATION_ROAD,
		NpcCatalog.STATION_GATE, NpcCatalog.STATION_CITY,
		NpcCatalog.STATION_MANOEUVRE,
	]
	for role: String in NpcCatalog.ROLES:
		_expect(not NpcCatalog.title_of(role).is_empty(),
			"%s has a job title" % role)
		_expect(NpcCatalog.duty_of(role).length() > 20,
			"%s says what it is for in the port" % role)
		_expect(stations.has(NpcCatalog.station_of(role)),
			"%s stands at a station on the container chain" % role)
	for infrastructure in ["armazem", "torre", "porto_ia", "portal", "trem",
			"flutuante", "drone"]:
		_expect(not NpcCatalog.has_crew(infrastructure),
			"%s is infrastructure, not somebody" % infrastructure)
	# Every station on the chain must be reachable, or the flow has a gap nobody
	# owns.
	for station: StringName in stations:
		var staffed := false
		for role: String in NpcCatalog.ROLES:
			if NpcCatalog.station_of(role) == station:
				staffed = true
		_expect(staffed, "station %s has somebody who works it" % station)


func _test_a_person_is_persistent_and_unique() -> void:
	var roster := NpcRoster.new()
	var first := roster.profile_for("sts", 0)
	_expect(first != null and first == roster.profile_for("sts", 0),
		"asking twice for one station returns the same person")
	_expect(roster.profile_for("armazem", 0) == null,
		"a warehouse has no operator to ask for")
	var names := {}
	for role in ["sts", "estivador", "rtg", "tt", "reach_stacker",
			"empilhadeira", "alfandega", "rebocador", "road_truck"]:
		for index in 2:
			var profile := roster.profile_for(role, index)
			_expect(profile != null and not profile.display_name.is_empty(),
				"%s#%d is somebody with a name" % [role, index])
			_expect(not names.has(profile.display_name),
				"nobody shares a name with %s" % profile.display_name)
			names[profile.display_name] = true
	_expect(first.joined_day == 12,
		"a hire records the port's own day (%d)" % first.joined_day)
	_expect(first.joined_unix > 0 and not first.joined_text().is_empty(),
		"a hire records a readable calendar date: %s" % first.joined_text())

	roster.record_move(first, 7)
	var reloaded := NpcRoster.new()
	reloaded.restore(roster.snapshot())
	var same := reloaded.find("sts#0")
	_expect(same != null and same.display_name == first.display_name \
			and same.joined_day == first.joined_day \
			and same.joined_unix == first.joined_unix and same.moves == 7,
		"a reload brings back the same operator, hire date and tally")
	_expect(reloaded.size() == roster.size(),
		"a reload brings back the whole crew (%d of %d)"
			% [reloaded.size(), roster.size()])


func _test_the_special_crew_is_where_it_says_it_is() -> void:
	## The named characters are seeded, not rolled, so the player always finds
	## them among the crew rather than eventually.
	var roster := NpcRoster.new()
	var alisson := roster.profile_for("estivador", 0)
	_expect(alisson != null and alisson.display_name == "Alisson",
		"the conferente at the first yard station is Alisson")
	_expect(alisson.is_special() and alisson.wears_special_hat(),
		"Alisson is a special with a helmet of his own")
	_expect(alisson.hat_color.b > alisson.hat_color.r \
			and alisson.hat_color.b > 0.6,
		"Alisson's helmet is blue (%s)" % alisson.hat_color.to_html(false))
	_expect(alisson.dossier.to_lower().contains("wilson sons") \
			and alisson.dossier.to_lower().contains("rio grande"),
		"Alisson's dossier says where he came from")
	_expect(ResourceLoader.exists("res://assets/sprites/worker_hat.png"),
		"the tintable helmet overlay exists for him to wear")

	# Only the conferente's sprite has a helmet to tint, so only the conferente
	# carries a colour: a hat on a role that cannot show one is a promise the game
	# does not keep.
	for special: Dictionary in NpcCatalog.SPECIALS:
		var wears := str(special.get("hat", "")) != ""
		_expect(wears == (str(special.role) == "estivador"),
			"%s carries a helmet colour only if their sprite wears one"
				% special.name)

	# The overlay is real, and it tracks the body frame by frame. Playing it as its
	# own animation is what would let the helmet drift off the head.
	var hatted := _actor("estivador", 0)
	_expect(hatted._hat != null, "Alisson is built with the helmet overlay")
	if hatted._hat != null:
		_expect(hatted._hat.modulate.is_equal_approx(alisson.hat_color),
			"the overlay is tinted with his own colour")
		hatted._walk.animation = &"down"
		hatted._walk.frame = 3
		hatted._walk.flip_h = true
		hatted._sync_hat()
		_expect(hatted._hat.animation == &"down" and hatted._hat.frame == 3 \
				and hatted._hat.flip_h,
			"the helmet copies the body's facing and frame")
		_expect(not hatted._hat.is_playing(),
			"the helmet is never played on its own clock")
	hatted.free()
	var plain := _actor("estivador", 1)
	_expect(plain._hat == null,
		"a conferente with no colour of their own keeps the standard helmet")
	plain.free()

	var restored := NpcRoster.new()
	restored.restore(roster.snapshot())
	var kept := restored.find("estivador#0")
	_expect(kept != null and kept.wears_special_hat() \
			and is_equal_approx(kept.hat_color.b, alisson.hat_color.b),
		"a reload keeps the blue helmet")
	for special: Dictionary in NpcCatalog.SPECIALS:
		var profile := roster.profile_for(str(special.role), int(special.slot))
		_expect(profile != null and profile.display_name == str(special.name),
			"%s holds their reserved station" % special.name)
		_expect(profile.dossier.length() > 40,
			"%s has a dossier worth reading" % special.name)


# ------------------------------------------------------------------ the board

func _test_one_key_one_owner() -> void:
	_world.berth.seed_new(30072026)
	_world.ship.arrive()
	# A hull alongside and stock in the blocks: that is two different places the
	# conferente could be, which is the point of the assertion below.
	_stock_a_few_blocks()
	await get_tree().process_frame

	var first := _actor("estivador", 0)
	var second := _actor("estivador", 1)
	var a: Dictionary = _world.tasks.claim(first, NpcCatalog.STATION_YARD)
	var b: Dictionary = _world.tasks.claim(second, NpcCatalog.STATION_YARD)
	_expect(not a.is_empty() and not b.is_empty(),
		"both conferentes get work while a hull is alongside")
	_expect(str(a.get("key", "")) != str(b.get("key", "")),
		"two conferentes never hold the same task (%s / %s)"
			% [a.get("key", ""), b.get("key", "")])
	_expect(_world.tasks.claim(first, NpcCatalog.STATION_YARD).get("key", "") \
			== a.get("key", ""),
		"asking again returns the task already held, not a second one")

	var keys := {}
	for row: Dictionary in _world.tasks.assignments():
		_expect(not keys.has(str(row.key)), "the board lists each key once")
		keys[str(row.key)] = true
		_expect(not str(row.label).is_empty(),
			"an assignment can say what it is: %s" % row.label)

	# An exact claim is how a transtainer is bound to its own block and cannot be
	# handed somebody else's.
	var taken_key := str(a.get("key", ""))
	var third := _actor("estivador", 2)
	_expect(_world.tasks.claim(third, NpcCatalog.STATION_YARD, taken_key,
			true).is_empty(),
		"an exact claim on a taken key is refused rather than substituted")

	_world.tasks.release(first)
	_expect(not _world.tasks.claim(third, NpcCatalog.STATION_YARD, taken_key,
			true).is_empty(),
		"releasing a task reopens exactly that key")

	# Freeing the actor has to reopen the station, or a rebuild starves it.
	var freed_key := str(_world.tasks.task_of(third).get("key", ""))
	third.free()
	_expect(not _world.tasks.is_claimed(freed_key),
		"tearing down an actor reopens its station")
	first.free()
	second.free()


func _test_two_drivers_are_never_sent_to_one_stack() -> void:
	## The bug this replaces: both drivers were offered the same top-of-stack, the
	## second arrived to find it gone and drove home with an empty chassis.
	_world.yard.restore({"version": 3, "slots": []})
	_fill_import_sector()
	_world.traffic.clear()
	var drivers: Array[StructureActor] = [_actor("tt", 0), _actor("tt", 1),
		_actor("reach_stacker", 0)]
	var claimed := {}
	var uids := {}
	for driver in drivers:
		var task: Dictionary = _world.tasks.claim_haul(driver)
		_expect(not task.is_empty(), "%s gets a land-side job" % driver.id)
		if task.is_empty():
			continue
		var key := str(task.get("key", ""))
		_expect(not claimed.has(key), "no two drivers share a job key (%s)" % key)
		claimed[key] = true
		var uid := str((task.get("meta", {}) as Dictionary).get("uid", ""))
		if not uid.is_empty():
			_expect(not uids.has(uid),
				"no two drivers are sent to the same container (%s)" % uid)
			uids[uid] = true
	_expect(uids.size() >= 2,
		"a busy yard really does dispatch collections (%d distinct boxes)"
			% uids.size())
	# The claim is what excludes it: with the claims live, the yard must offer
	# something else or nothing at all.
	_expect(not _world.tasks.claimed_uids().is_empty(),
		"live claims are visible to the yard as excluded identities")
	for driver in drivers:
		var mine := str((_world.tasks.task_of(driver).get("meta", {}) \
			as Dictionary).get("uid", ""))
		_expect(not _world.tasks.claimed_uids_except(driver).has(mine),
			"a driver's own box is not excluded from it")
	for driver in drivers:
		var job: Dictionary = _world.tasks.task_of(driver).get("job", {})
		if not job.is_empty():
			_world.cancel_job(job)
		driver.free()
	_expect(_world.yard._reservations.is_empty(),
		"tearing the drivers down returns every yard reservation")


func _test_every_station_says_what_it_is_doing() -> void:
	## A task nobody can read is a task that may as well not exist.
	##
	## The yard is left with stock *and* room: a completely full import sector has
	## no landing for a discharge, so the berth would legitimately have nothing to
	## describe.
	_stock_a_few_blocks()
	_world.gate.seed_new()
	_world.gate._call_a_truck()
	for bay: int in _world.gate.bays.keys():
		_world.gate.notify_docked(bay)
	var stations := [
		NpcCatalog.STATION_BERTH, NpcCatalog.STATION_YARD,
		NpcCatalog.STATION_STACK, NpcCatalog.STATION_GATE,
		NpcCatalog.STATION_CITY, NpcCatalog.STATION_MANOEUVRE,
	]
	for station: StringName in stations:
		var needs := _world.tasks.open_needs(station)
		_expect(not needs.is_empty(), "station %s has open work to describe"
			% station)
		for need: Dictionary in needs:
			_expect(not str(need.get("key", "")).is_empty(),
				"every need at %s has a key" % station)
			var label := _world.tasks.label_for(need)
			_expect(not label.is_empty(),
				"need %s reads as a sentence" % need.get("key", ""))
	for stage in [TaskBoard.STAGE_TO_TARGET, TaskBoard.STAGE_WORKING,
			TaskBoard.STAGE_RETURNING]:
		_expect(not _world.tasks.stage_text(stage).is_empty(),
			"stage %s has words" % stage)


func _test_everything_the_crew_says_is_printable() -> void:
	## The UI is drawn with a hand-made bitmap font, and a character it has no
	## glyph for prints as a hollow box. An em dash and a middle dot both shipped
	## in the first draft of these dossiers and both looked like corruption on the
	## card, so every string the crew can put on screen is checked against the
	## font itself.
	var glyphs := _font_glyphs()
	_expect(glyphs.size() > 80, "the font manifest is readable (%d glyphs)"
		% glyphs.size())
	if glyphs.is_empty():
		return
	var strings: Array[String] = []
	for role: String in NpcCatalog.ROLES:
		strings.append(NpcCatalog.title_of(role))
		strings.append(NpcCatalog.duty_of(role))
	for special: Dictionary in NpcCatalog.SPECIALS:
		strings.append(str(special.name))
		strings.append(str(special.dossier))
		strings.append(str(special.get("trait", "")))
	for pool: Array in NpcCatalog.BACKGROUNDS.values():
		for line in pool:
			strings.append(str(line))
	for first in NpcCatalog.FIRST_NAMES:
		strings.append(str(first))
	for last in NpcCatalog.SURNAMES:
		strings.append(str(last))
	var roster := NpcRoster.new()
	var dated := roster.profile_for("sts", 0)
	strings.append(dated.joined_text())
	for station: StringName in [NpcCatalog.STATION_BERTH, NpcCatalog.STATION_YARD,
			NpcCatalog.STATION_STACK, NpcCatalog.STATION_GATE,
			NpcCatalog.STATION_CITY, NpcCatalog.STATION_MANOEUVRE]:
		for need: Dictionary in _world.tasks.open_needs(station):
			strings.append(_world.tasks.label_for(need))
	for stage in [TaskBoard.STAGE_TO_TARGET, TaskBoard.STAGE_WORKING,
			TaskBoard.STAGE_RETURNING]:
		strings.append(_world.tasks.stage_text(stage))

	for text in strings:
		for index in text.length():
			var code := text.unicode_at(index)
			if not glyphs.has(code):
				_expect(false, "\"%s\" uses a character the font cannot draw (%s)"
					% [text, text[index]])
				break


func _font_glyphs() -> Dictionary:
	var glyphs := {}
	var file := FileAccess.open("res://assets/fonts/harbor_font.fnt", FileAccess.READ)
	if file == null:
		return glyphs
	while not file.eof_reached():
		var line := file.get_line()
		if not line.begins_with("char id="):
			continue
		glyphs[int(line.substr(8).split(" ")[0])] = true
	file.close()
	return glyphs


func _test_tapping_somebody_opens_their_dossier() -> void:
	## The inspection tap, end to end: a real structure layer, a real actor, and
	## the world reporting who was touched and what they are doing.
	GameState.owned.clear()
	GameState.owned["estivador"] = 1
	_world.structures = StructureLayer.new()
	_world.structures.world = _world
	_world.add_child(_world.structures)
	_world.structures.rebuild()
	await get_tree().process_frame
	var people := _world.structures.crew()
	_expect(people.size() == 1,
		"one bought conferente puts exactly one person on the terminal (%d)"
			% people.size())
	if people.is_empty():
		return
	var actor: StructureActor = people[0]
	var seen: Array[NpcProfile] = []
	var dossiers: Array[Dictionary] = []
	_world.npc_inspected.connect(
		func(profile: NpcProfile, dossier: Dictionary) -> void:
			seen.append(profile)
			dossiers.append(dossier))

	_expect(_world._inspect_npc(actor.global_position + Vector2(4.0, 6.0)),
		"tapping the conferente is a hit")
	_expect(seen.size() == 1 and seen[0] == actor.profile,
		"the world reports exactly who was touched")
	if not dossiers.is_empty():
		_expect(dossiers[0].get("actor") == actor,
			"the dossier carries the actor so the card can follow them")
	_expect(not _world._inspect_npc(Vector2(-400.0, -400.0)),
		"tapping empty ground is not somebody")
	_expect(seen.size() == 1, "a miss reports nobody")

	# A machine that is nobody cannot be inspected, however hard it is tapped.
	var warehouse := _actor("armazem", 0)
	_expect(warehouse.profile == null and not warehouse.hit_test(
			warehouse.global_position),
		"a warehouse is not a person to tap")
	warehouse.free()
	_world.structures.queue_free()
	_world.structures = null
	await get_tree().process_frame


func _test_holding_somebody_picks_them_up() -> void:
	## Tap and hold are two verbs sharing one press, and the hold is the one that
	## lifts somebody off the ground. What has to hold: the two never both fire,
	## a machine is never picked up however long it is held, a person in the hand
	## does not carry on with their round, and nobody can be put down in the sea.
	GameState.owned.clear()
	GameState.owned["estivador"] = 1
	GameState.owned["rtg"] = 1
	_world.structures = StructureLayer.new()
	_world.structures.world = _world
	_world.add_child(_world.structures)
	_world.structures.rebuild()
	await get_tree().process_frame
	var walker: StructureActor = null
	var machine: StructureActor = null
	for actor in _world.structures.crew():
		if actor.is_person():
			walker = actor
		elif machine == null:
			machine = actor
	_expect(walker != null, "a bought conferente is somebody on foot")
	_expect(machine != null and not machine.grab(),
		"a crewed transtêiner is still a machine and cannot be picked up")
	if walker == null:
		_world.structures.queue_free()
		_world.structures = null
		await get_tree().process_frame
		return

	# An Array, not an int: a GDScript lambda captures a local by value, so a
	# counter incremented inside one leaves the outer variable at zero and every
	# assertion about it passes for the wrong reason.
	var inspected: Array[NpcProfile] = []
	var on_inspect := func(profile: NpcProfile, _dossier: Dictionary) -> void:
		inspected.append(profile)
	_world.npc_inspected.connect(on_inspect)

	var grip := walker.global_position + Vector2(4.0, 6.0)
	_world._begin_press(grip)
	_world._tick_hold(PortWorld.GRAB_HOLD * 0.5)
	_expect(not walker.is_held(),
		"half the hold has not picked anybody up yet")
	_world._tick_hold(PortWorld.GRAB_HOLD)
	_expect(walker.is_held(), "holding the conferente picks them up")

	var carried := Vector2(PortLayout.BLOCK_X0 + 20.0, PortLayout.YARD_Y0 + 40.0)
	_world._move_press(carried)
	_expect(walker.global_position.is_equal_approx(carried),
		"whoever is held follows the hand")
	walker._process(0.5)
	_expect(walker.global_position.is_equal_approx(carried),
		"a person in the air does not walk their round")

	_world._end_press(carried)
	_expect(not walker.is_held(), "letting go puts them down")
	_expect(inspected.is_empty(), "a grab never also opens the badge behind it")

	# A tap on the same person still opens the badge: the hold is the only thing
	# that changed, and it must not have eaten the tap.
	# Where they are *now*, not where they were picked up: they have just been
	# carried across the yard, which is the whole point.
	var tap_at := walker.global_position + Vector2(4.0, 6.0)
	_world._begin_press(tap_at)
	_world._end_press(tap_at)
	_expect(inspected.size() == 1,
		"a press with no hold is still an inspection tap")

	# The sea is somewhere you *can* leave a conferente — and the swim back is
	# the correction. Dropping them past the wall used to clamp them onto the
	# apron mid-air, which taught the player that the water was not really there.
	_world._begin_press(walker.global_position + Vector2(4.0, 6.0))
	_world._tick_hold(PortWorld.GRAB_HOLD + 0.01)
	var overboard := Vector2(PortLayout.WATER_X0 + 40.0, PortLayout.YARD_Y0)
	_world._move_press(overboard)
	_world._end_press(overboard)
	_expect(not walker.is_held(), "the last grab was released")
	_expect(walker.is_overboard(),
		"dropping somebody past the wall puts them in the water (%.1f)"
			% walker.global_position.x)
	_expect(walker.global_position.x > PortLayout.WATER_X0,
		"they go in where they were dropped, not on the apron")
	_expect(_world.tasks.task_of(walker).is_empty(),
		"a swimmer holds no claim, so the station reopens")

	# And they get themselves out. Ten seconds of simulation is more than the
	# swim needs from anywhere in the fairway, and the assertion is that the
	# state machine *terminates* — an actor stuck in the water is an actor whose
	# station is never worked again.
	for step in 400:
		walker._process(0.025)
		if not walker.is_overboard():
			break
	_expect(not walker.is_overboard(), "a swimmer reaches the wall")
	_expect(walker.global_position.x <= PortLayout.QUAY_X1,
		"they climb out onto the apron (%.1f)" % walker.global_position.x)

	_world.npc_inspected.disconnect(on_inspect)
	_world.structures.queue_free()
	_world.structures = null
	await get_tree().process_frame


# ------------------------------------------------------------------ the vessel

func _test_a_landing_box_rolls_the_hull_both_ways() -> void:
	var ship := Ship.new()
	add_child(ship)
	await get_tree().process_frame
	ship._set_phase(Ship.Phase.DISCHARGING)

	# One box landing, one tremor: the hull has to be seen on both sides of the
	# centreline before it settles, which is what the old one-way shove never did.
	ship.nudge(1, true)
	var minimum := 0.0
	var maximum := 0.0
	for step in 90:
		ship._process(1.0 / 60.0)
		minimum = minf(minimum, ship.roll_offset())
		maximum = maxf(maximum, ship.roll_offset())
	_expect(minimum < -0.3 and maximum > 0.3,
		"a landing box shakes the hull to port and to starboard (%.2f .. %.2f)"
			% [minimum, maximum])
	_expect(is_zero_approx(ship.roll_offset()),
		"the tremor settles instead of leaving the hull leaning (%.3f)"
			% ship.roll_offset())

	# A discharge lifts a box clear of the deck. Nothing strikes the ship, so the
	# ship must not move at all — this is the whole point of the change.
	ship.nudge(1, false)
	_expect(is_zero_approx(ship.roll_offset()),
		"taking a box off the deck does not shake the hull (%.3f)"
			% ship.roll_offset())
	for step in 8:
		ship._process(1.0 / 60.0)
	_expect(is_zero_approx(ship.roll_offset()),
		"and it stays still on the frames after (%.3f)" % ship.roll_offset())

	# The weight lands on the side its own bay is on.
	ship.nudge(0, true)
	var port_side := ship.roll_side()
	ship.nudge(Ship.COLS - 1, true)
	_expect(port_side < 0.0 and ship.roll_side() > 0.0,
		"the two deck columns shake to opposite sides (%.1f / %.1f)"
			% [port_side, ship.roll_side()])

	# With no bay reported at all it must still alternate rather than lean.
	var sides := {}
	for step in 24:
		ship.nudge(-1, true)
		sides[ship.roll_side()] = true
	_expect(sides.size() == 2,
		"unattributed moves still use both sides (%d seen)" % sides.size())
	ship.free()


func _test_the_landing_sound_has_six_takes() -> void:
	## Six near-identical landings, drawn so no take and no pitch repeats back to
	## back. Under automation this fires several times a second.
	for index in range(1, 7):
		_expect(ResourceLoader.exists("res://assets/audio/thunk_%d.wav" % index),
			"landing take %d is generated" % index)
	for index in range(1, 5):
		_expect(ResourceLoader.exists("res://assets/audio/click_%d.wav" % index),
			"pick-up take %d is generated" % index)
	var seen := {}
	var previous := ""
	var repeats := 0
	for draw in 240:
		var take := AudioManager.pick_variant("thunk")
		if take == previous:
			repeats += 1
		previous = take
		seen[take] = true
	_expect(repeats == 0, "the same landing take never plays twice running")
	_expect(seen.size() == 6, "all six landing takes are used (%d)" % seen.size())
	# Every family generated is a family the manager knows about, and the other
	# way round: a count that outruns the files plays silence.
	for base: String in AudioManager.VARIANTS:
		var count := int(AudioManager.VARIANTS[base])
		for index in range(1, count + 1):
			_expect(ResourceLoader.exists(
					"res://assets/audio/%s_%d.wav" % [base, index]),
				"%s take %d is generated" % [base, index])
		_expect(not ResourceLoader.exists(
				"res://assets/audio/%s_%d.wav" % [base, count + 1]),
			"%s declares every take it has (%d)" % [base, count])
	_expect(AudioManager.pick_variant("prestige") == "prestige",
		"a sound with a single take is left alone")
	var pitches := {}
	for draw in 40:
		pitches[AudioManager.family_pitch("thunk")] = true
	_expect(pitches.size() >= 4,
		"the landing walks a pitch ladder (%d steps)" % pitches.size())
	_expect(is_equal_approx(AudioManager.family_pitch("prestige"), 1.0),
		"a single-take sound keeps its recorded pitch")


# ------------------------------------------------------------------- utilities

func _actor(role: String, index: int) -> StructureActor:
	var actor := StructureActor.new()
	actor.setup(role, index, _world)
	_world.entities.add_child(actor)
	return actor


func _stock_a_few_blocks() -> void:
	## One box on the ground in the first three blocks, so the yard holds cargo in
	## more than one place and still has capacity for a discharge.
	_world.yard.restore({"version": 3, "slots": []})
	for block in 3:
		var slot := block * ContainerYard.SLOTS_PER_BLOCK
		_world.yard.place(slot, 0, block)


func _fill_import_sector() -> void:
	for slot in _world.yard.total_slots():
		if _world.yard.slot_sector(slot) != CargoUnit.IMPORT:
			continue
		while _world.yard._settled(slot) < PortLayout.STACK_MAX:
			var level := _world.yard._settled(slot)
			if not _world.yard.place(slot, level, level % 8):
				break


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
