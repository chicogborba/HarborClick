extends Node
## Run with: Godot --headless --path . res://tests/phase4_ship_test_runner.tscn

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	test_catalogue_and_deterministic_rotation()
	test_ship_snapshot_restores_variant()
	test_visual_variants_do_not_change_berth_capacity()
	test_transformed_hull_bay_is_the_flight_destination()
	test_wake_tracks_motion_phase()
	test_two_hulls_never_share_the_channel()
	test_the_channel_runs_the_way_the_bow_points()
	test_moorings_follow_berth_state()
	test_tug_escort_follows_maneuver()
	await test_fleet_uses_the_single_github_hull()
	if failures.is_empty():
		print("PHASE 4 SHIP TESTS PASSED")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func test_fleet_uses_the_single_github_hull() -> void:
	## GitHub's restrained fleet is one 66x232 source sprite. Catalogue entries
	## may scale and recolour it, but never replace the texture or its 24 bays.
	for silhouette: Dictionary in ShipCatalog.SILHOUETTES:
		var hull := Ship.new()
		add_child(hull)
		await get_tree().process_frame
		hull.apply_variant(ShipCatalog.compose(silhouette,
			ShipCatalog.PALETTES[0]))
		var texture := (hull._hull as Sprite2D).texture
		_expect(texture != null and texture.resource_path.ends_with("ship_top.png"),
			"%s uses the single GitHub hull source" % silhouette.id)
		_expect(texture.get_width() == 66 and texture.get_height() == 232,
			"%s source hull remains 66x232" % silhouette.id)
		_expect(hull.bay_rows() == PortLayout.SHIP_BAY_ROWS
				and hull.bay_capacity() == 24,
			"%s keeps the fixed twelve-row, 24-box deck" % silhouette.id)
		var scale: Vector2 = silhouette.hull_scale
		_expect((hull._hull as Sprite2D).scale.is_equal_approx(scale),
			"%s applies the catalogue scale to the shared hull" % silhouette.id)
		_expect(is_equal_approx(hull.hull_height(), 232.0 * scale.y),
			"%s reports the scaled shared-hull height" % silhouette.id)
		hull.free()


func test_catalogue_and_deterministic_rotation() -> void:
	_expect(ShipCatalog.is_valid() and ShipCatalog.SILHOUETTES.size() >= 3 and ShipCatalog.PALETTES.size() >= 4,
		"ship catalogue declares at least three silhouettes and four palettes")
	var first_history: Array[String] = []
	var second_history: Array[String] = []
	for call_index in 18:
		var first := ShipCatalog.select_variant(444, call_index, first_history)
		var second := ShipCatalog.select_variant(444, call_index, second_history)
		_expect(first == second, "variant selection is deterministic for call %d" % call_index)
		first_history.append(str(first.id))
		second_history.append(str(second.id))
		if first_history.size() >= 3:
			var end := first_history.size()
			_expect(not (first_history[end - 1] == first_history[end - 2] and first_history[end - 2] == first_history[end - 3]),
				"same variant cannot repeat for more than two scales")


func test_ship_snapshot_restores_variant() -> void:
	var ship := Ship.new()
	get_tree().root.add_child(ship)
	ship.select_variant(919, 0)
	ship.select_variant(919, 1)
	var saved := ship.snapshot()
	var restored := Ship.new()
	get_tree().root.add_child(restored)
	restored.restore(saved)
	_expect(restored.variant_id() == ship.variant_id(), "ship snapshot restores the selected variant")
	_expect(restored.variant_history == ship.variant_history, "ship snapshot restores variant history")
	_expect(restored.operational_capacity() == ship.operational_capacity() and restored.operational_capacity() > 0,
		"restored vessel keeps declared informational capacity")
	ship.free()
	restored.free()


func test_visual_variants_do_not_change_berth_capacity() -> void:
	_expect(Ship.COLS * Ship.ROWS == 24, "visual catalogue cannot alter the 24-transfer berth contract")
	for silhouette in ShipCatalog.SILHOUETTES:
		_expect(int(silhouette.capacity) > 0, "each silhouette declares an informational vessel capacity")


func test_transformed_hull_bay_is_the_flight_destination() -> void:
	var ship := Ship.new()
	get_tree().root.add_child(ship)
	ship.position = Vector2(240, 60)
	# Reproduce the silhouette transform independently of catalogue selection:
	# the reservation must travel through Cargo's transform, not use the base
	# layout plus the ship origin.
	ship._cargo.position = Vector2(5, 9)
	ship._cargo.scale = Vector2(0.78, 0.92)
	ship.set_manifest([], 1)
	var bay := ship.reserve_bay()
	var top_left := Vector2(
		Ship.BAY_X[int(bay.col)] - 1.0,
		Ship.BAY_Y0 + int(bay.row) * Ship.BAY_PITCH - 1.0)
	var expected := ship._cargo.to_global(
		top_left + Ship.BOX_VISUAL_CENTRE)
	var naive := ship.global_position + top_left
	_expect((bay.pos as Vector2).distance_to(expected) < 0.01,
		"a loading flight ends on the transformed visible hull slot")
	_expect((bay.pos as Vector2).distance_to(naive) > 1.0,
		"the transformed test would catch the old unscaled destination")
	ship.free()


func test_wake_tracks_motion_phase() -> void:
	## A wake is made by a hull making way, not by a hull being in a phase. The
	## two used to be the same thing; they are not any more, because a ship that
	## cannot use the channel is warped on and off the wall beam-on under tow, and
	## a wake streaming off that is the wrong picture.
	var ship := Ship.new()
	get_tree().root.add_child(ship)
	_expect(not ship._wake.visible and not ship._wake.is_playing(),
		"wake is stopped while the ship is away")
	ship._set_phase(Ship.Phase.ARRIVING)
	_expect(not ship._wake.visible,
		"a hull warped in off the offing arrives without a wake")
	ship._under_way = true
	ship._refresh_wake_state()
	_expect(ship._wake.visible and ship._wake.is_playing() and ship._wake.speed_scale < 1.0,
		"an arrival up the channel creates a restrained moving wake")
	ship._set_phase(Ship.Phase.DISCHARGING)
	_expect(not ship._wake.visible and not ship._wake.is_playing(),
		"wake stops while the ship is moored")
	ship._set_phase(Ship.Phase.DEPARTING)
	_expect(ship._wake.visible and ship._wake.is_playing() and ship._wake.speed_scale == 1.0,
		"a departure up the channel creates the faster moving wake")
	ship._under_way = false
	ship._refresh_wake_state()
	_expect(not ship._wake.visible,
		"a hull warped out to sea departs without a wake")
	ship.free()


class LaneWorld:
	extends PortWorld

	## Just a quay with hulls on it. `lane_clear_*` reads `berth_hulls()` and
	## nothing else, so none of the rest of the terminal has to exist to ask it
	## the one question this suite cares about.
	func _ready() -> void:
		for index in 3:
			var hull := Ship.new()
			hull.berth_index = index
			hull.visible = false
			add_child(hull)
			ships.append(hull)

	func moor(indices: Array) -> void:
		for index in ships.size():
			var alongside: bool = indices.has(index)
			ships[index].visible = alongside
			ships[index]._set_phase(
				Ship.Phase.DISCHARGING if alongside else Ship.Phase.AWAY)


func test_two_hulls_never_share_the_channel() -> void:
	## The complaint this exists for: with several ships alongside, a manoeuvring
	## hull slid straight through the moored ones.
	##
	## There is no offset that fixes it. The world is 320 px wide, the water is 80
	## and a hull is 66, so a hull held clear of a moored one would start at 310
	## and end at 376 — off the map. Passing is therefore not allowed at all: a
	## ship whose channel is blocked is warped out to sea sideways instead, and
	## that track stays on its own berth's line where nobody else is.
	var water := PortLayout.WORLD_W - PortLayout.WATER_X0
	_expect(water < PortLayout.SHIP_W * 2.0,
		"the premise still holds: %.0f px of water cannot hold two %.0f px hulls"
			% [water, PortLayout.SHIP_W])
	_expect(PortLayout.FAIRWAY_X > PortLayout.SHIP_X,
		"coming off the berth is a move outboard the player can see")
	_expect(PortLayout.OFFING_X >= PortLayout.SHIP_X + PortLayout.SHIP_W,
		"the seaward route ends clear of the berth line")

	var world := LaneWorld.new()
	get_tree().root.add_child(world)
	world.moor([])
	for index in 3:
		_expect(world.lane_clear_north(index) and world.lane_clear_south(index),
			"an empty quay leaves berth %d both ways" % index)
	# The middle berth alone alongside blocks the run past it in both directions,
	# and leaves the ends of the quay free.
	world.moor([1])
	_expect(world.lane_clear_north(0) and world.lane_clear_south(2),
		"the ends of the quay always have open water on their own side")
	_expect(not world.lane_clear_south(0),
		"a hull moored south of a berth blocks the run in")
	_expect(not world.lane_clear_north(2),
		"a hull moored north of a berth blocks the run out")
	world.moor([0, 1, 2])
	_expect(world.lane_clear_north(0) and world.lane_clear_south(2),
		"a full quay can still be entered and left at its ends")
	_expect(not world.lane_clear_north(1) and not world.lane_clear_south(1),
		"the middle of a full quay has no channel at all, either way")
	world.queue_free()

	# And the two routes really are wired to that answer.
	var ship := Ship.new()
	ship.berth_index = 1
	get_tree().root.add_child(ship)
	ship.arrive(false)
	_expect(is_equal_approx(ship.position.x, PortLayout.OFFING_X),
		"a blocked arrival comes in off the offing (%.1f)" % ship.position.x)
	_expect(is_equal_approx(ship.position.y, ship.berth_position().y),
		"and on its own berth's line, where nobody else is")
	ship._set_phase(Ship.Phase.AWAY)
	ship.arrive(true)
	_expect(is_equal_approx(ship.position.x, PortLayout.FAIRWAY_X)
			and is_equal_approx(ship.position.y, PortLayout.channel_entry_y()),
		"an open arrival picks the channel up from the open water below (%.1f)"
			% ship.position.y)
	_expect(ship.position.y > ship.berth_position().y,
		"and therefore steams *up* to its berth rather than reversing down onto it")
	ship.free()


func test_the_channel_runs_the_way_the_bow_points() -> void:
	## The one invariant nobody wrote down, and the one that broke.
	##
	## The hull sprite was flipped bow-down for a while and then flipped back to
	## bow-up, and the manoeuvre was left driving the other way. Nothing failed:
	## the geometry suite proved which berths block which lane, and the route
	## suite proved the two routes were wired to the answer, but no test tied the
	## *direction of travel* to the *direction the sprite points*. So the ship
	## reversed into its berth and reversed back out to sea, in a game whose
	## README already said "north is rotation zero", and only a player noticed.
	##
	## This measures the actual PNG. `gen_ship.py` tapers the bow, so the narrow
	## end of the hull is the bow — and whichever end that is decides which way
	## the channel has to run.
	var image := preload("res://assets/sprites/ship_top.png").get_image()
	var top := _opaque_width(image, int(image.get_height() * 0.06))
	var bottom := _opaque_width(image, int(image.get_height() * 0.94))
	_expect(top > 0 and bottom > 0,
		"the hull sprite has a body at both ends (%d / %d)" % [top, bottom])
	var bow_is_up := top < bottom
	_expect(bow_is_up,
		"ship_top.png is drawn bow-up: %dpx across the bow, %dpx across the stern"
			% [top, bottom])
	# Bow-first is the only way anything steams, so the bow decides the channel.
	var berth := PortLayout.berth_y(0)
	if bow_is_up:
		_expect(PortLayout.channel_entry_y() > berth
				and PortLayout.channel_exit_y() < berth,
			"a bow-up hull enters from the south and leaves to the north")
	else:
		_expect(PortLayout.channel_entry_y() < berth
				and PortLayout.channel_exit_y() > berth,
			"a bow-down hull enters from the north and leaves to the south")
	_expect(PortLayout.channel_entry_y() > PortLayout.world_bottom()
			and PortLayout.channel_exit_y() < 0.0,
		"both ends of the channel are off screen, so no hull pops into existence")


func _opaque_width(image: Image, row: int) -> int:
	var count := 0
	for x in image.get_width():
		if image.get_pixel(x, clampi(row, 0, image.get_height() - 1)).a > 0.5:
			count += 1
	return count


func test_moorings_follow_berth_state() -> void:
	var ship := Ship.new()
	get_tree().root.add_child(ship)
	ship._set_phase(Ship.Phase.ARRIVING)
	_expect(not ship.moorings_visible(),
		"an arriving ship is not tied to the quay")
	ship._set_phase(Ship.Phase.DISCHARGING)
	_expect(ship.moorings_visible()
			and ship._mooring_lines.size() == Ship.MOORING_LINES,
		"a working ship is made fast on both mooring lines")
	# The head and stern lines both have to land on a bollard the quay actually
	# has, not merely near one.
	_expect(ship._mooring_plan.size() == Ship.MOORING_LINES,
		"every line has a plan")
	var bollards := {}
	for index in PortLayout.bollard_count():
		bollards[roundi(PortLayout.bollard_position(index).y
			+ PortLayout.BOLLARD_CENTRE.y)] = true
	var leads := {}
	for plan: Dictionary in ship._mooring_plan:
		var quay_end: Vector2 = plan.to + ship.position
		_expect(bollards.has(roundi(quay_end.y)),
			"a line is made fast to a real bollard (y %.0f)" % quay_end.y)
		_expect(is_equal_approx(quay_end.x,
				PortLayout.BOLLARD_X + PortLayout.BOLLARD_CENTRE.x),
			"and to the bollard line on the quay")
		var ship_end: Vector2 = plan.from
		_expect(is_equal_approx(ship_end.x, Ship.MOORING_LEAD_X),
			"and led through the port bulwark")
		leads[roundi(ship_end.y)] = true
		_expect(float(plan.sag) > 0.0, "a rope hangs rather than pulling straight")
	_expect(leads.size() >= 2,
		"the lines are led from more than one fairlead (%d)" % leads.size())
	ship._set_phase(Ship.Phase.DEPARTING)
	_expect(not ship.moorings_visible(),
		"mooring lines are cast off before departure")
	# The scaled feeder still has to lead both lines from inside its own hull.
	ship.apply_variant(ShipCatalog.compose(ShipCatalog.SILHOUETTES[0],
		ShipCatalog.PALETTES[0]))
	ship._set_phase(Ship.Phase.DISCHARGING)
	for plan: Dictionary in ship._mooring_plan:
		_expect(float(plan.from.y) < ship.hull_height(),
			"a scaled feeder is made fast on its own hull (%.0f of %.0f)"
				% [plan.from.y, ship.hull_height()])
	ship.free()


func test_tug_escort_follows_maneuver() -> void:
	var world := PortWorld.new()
	var ship := Ship.new()
	get_tree().root.add_child(ship)
	world.ship = ship
	ship.visible = true
	ship.position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y)
	ship._set_phase(Ship.Phase.DEPARTING)

	var tug := StructureActor.new()
	tug.setup("rebocador", 0, world)
	tug.position = Vector2(PortLayout.WATER_X0 + 20.0,
		PortLayout.world_bottom() - 60.0)
	var target := tug._tug_formation_target(ship)
	var before := tug.position.distance_to(target)
	for step in 30:
		tug._process(1.0 / 60.0)
	var after := tug.position.distance_to(tug._tug_formation_target(ship))
	_expect(tug.tug_escort_active() and after < before,
		"a bought tug closes on the ship's stern during departure")
	_expect(tug._boat_wake.visible and tug._boat_glows.size() == 2,
		"an escorting tug has prop wash and navigation lights")

	ship._set_phase(Ship.Phase.DISCHARGING)
	tug._process(1.0 / 60.0)
	_expect(not tug.tug_escort_active(),
		"the tug holds station instead of claiming an escort while moored")
	tug.free()
	ship.free()
	world.free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
