extends Node
## The water's knowledge of the ship.
## Run with:
## Godot --headless --path . res://tests/wake_test_runner.tscn
##
## The wake is drawn by the water shader from three uniforms. A shader that
## stops being fed fails silently — the sea simply looks calm — so what is
## checked here is the feed: a moored hull reports nothing, a driving hull
## reports its speed, and the centre handed over is in the water rect's own
## space rather than the world's.

const TEST_SAVE_PATH := "user://harborclick_wake_test.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	GameState.from_save({})

	await _test_strength_follows_real_movement()
	_test_centre_is_in_shader_space()

	SaveManager.wipe()
	if failures.is_empty():
		print("WAKE TESTS PASSED (strength, shader space)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("WAKE TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_strength_follows_real_movement() -> void:
	var ship := Ship.new()
	add_child(ship)
	await get_tree().process_frame

	ship.position = Vector2(PortLayout.SHIP_X, 400.0)
	ship._set_phase(Ship.Phase.DISCHARGING)
	for step in 20:
		ship._process(1.0 / 60.0)
	_expect(is_zero_approx(ship.wake_strength()),
		"a moored ship throws no water (%.3f)" % ship.wake_strength())

	# Driving: the phase alone is not enough, the hull has to actually move.
	ship._set_phase(Ship.Phase.ARRIVING)
	for step in 20:
		ship._process(1.0 / 60.0)
	_expect(is_zero_approx(ship.wake_strength()),
		"a ship that has not started moving yet throws no water")

	for step in 90:
		ship.position.y -= 2.0
		ship._process(1.0 / 60.0)
	_expect(ship.wake_strength() > 0.8,
		"a hull under way drives a full wake (%.3f)" % ship.wake_strength())

	# And it dies away rather than snapping off when the engines stop.
	var driving := ship.wake_strength()
	for step in 10:
		ship._process(1.0 / 60.0)
	var easing := ship.wake_strength()
	_expect(easing < driving and easing > 0.0,
		"the wake eases away instead of snapping off (%.3f -> %.3f)"
			% [driving, easing])

	ship.free()


func _test_centre_is_in_shader_space() -> void:
	var ship := Ship.new()
	add_child(ship)
	ship.position = Vector2(PortLayout.SHIP_X, 200.0)
	var centre := ship.hull_centre()
	_expect(is_equal_approx(centre.x,
			PortLayout.SHIP_X + PortLayout.SHIP_W * 0.5),
		"the hull centre is the middle of the beam, not its left edge")
	_expect(is_equal_approx(centre.y, 200.0 + PortLayout.SHIP_H * 0.5),
		"the hull centre is amidships, not at the bow")
	# The water rect is offset from the world origin; the shader reads its own
	# local space, so the centre must be offset by exactly that much.
	var water_origin := Vector2(PortLayout.WATER_X0 - 12.0, 0.0)
	var shader_space := centre - water_origin
	_expect(is_equal_approx(shader_space.x, centre.x - water_origin.x),
		"the centre handed to the shader is in the water rect's space")
	ship.free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
