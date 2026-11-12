extends Node
## The PORTOS board, driven the way a finger drives it.
## Run with: Godot --headless --path . res://tests/route_ui_test_runner.tscn
##
## The board is live (it refreshes while the port earns) and its one key is the
## only way to open or sail to a port, so the defect worth guarding is the one
## this board's ancestor had: a key rebuilt between press and release, which
## swallows every tap silently. Plus the globe: a pin must sit where its port
## is, and tapping it must pick that port.

const TEST_SAVE_PATH := "user://harborclick_route_ui_test.json"
const SLOT := 3

var failures: Array[String] = []
var _finished: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	UserPreferences.reduce_motion = true
	SaveManager.delete_profile(SLOT)
	await _test_the_key_survives_a_tap_while_the_port_earns()
	await _test_travel_asks_main_to_sail()
	await _test_a_pin_picks_its_port()
	SaveManager.delete_profile(SLOT)
	var expected := 3
	if _finished.size() != expected:
		failures.append("only %d of %d tests reached their last line (%s)"
			% [_finished.size(), expected, ", ".join(_finished)])
	if failures.is_empty():
		print("ROUTE UI TESTS PASSED (key survives income, travel, globe pins)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("ROUTE UI TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _fresh_board(teus: float) -> RouteMap:
	SaveManager.delete_profile(SLOT)
	SaveManager.use_profile(SLOT)
	GameState.teus = teus
	# A port that is actually producing, so `teus_changed` fires every frame.
	GameState.owned = {"estivador": 40}
	GameState.recompute()
	var map := RouteMap.new()
	add_child(map)
	await get_tree().process_frame
	map.open()
	await get_tree().process_frame
	await get_tree().process_frame
	UiTheme.settle_open(map._sheet)
	return map


func _test_the_key_survives_a_tap_while_the_port_earns() -> void:
	var map := await _fresh_board(1e12)
	map._select(&"long_beach")
	await get_tree().process_frame
	var key: Button = map._go
	_expect(key.visible and not key.disabled, "Long Beach shows a price key")
	var cost := float(PortDB.get_port(&"long_beach").cost)
	var before := GameState.teus
	await _tap(key)
	_expect(SaveManager.port_open(&"long_beach"), "a real tap opens the port")
	_expect(before - GameState.teus >= cost - maxf(1.0, GameState.cps),
		"and it was paid for")
	_expect(map._go == key and is_instance_valid(key),
		"the key is the same node it was before the tap")
	map.queue_free()
	await get_tree().process_frame
	_finished.append("survives")


func _test_travel_asks_main_to_sail() -> void:
	var map := await _fresh_board(1e12)
	SaveManager.buy_port(&"shanghai")
	var asked: Array[StringName] = []
	map.travel_requested.connect(func(id: StringName) -> void: asked.append(id))
	map._select(&"shanghai")
	await get_tree().process_frame
	_expect(map._go.text == Loc.t("ports.travel"), "an open port offers VIAJAR")
	await _tap(map._go)
	_expect(asked == [&"shanghai"], "and the key asks Main to sail there (%s)" % [asked])
	map._select(PortDB.active)
	await get_tree().process_frame
	_expect(not map._go.visible, "the port you are in has no key")
	map.queue_free()
	await get_tree().process_frame
	_finished.append("travel")


func _test_a_pin_picks_its_port() -> void:
	var map := await _fresh_board(0.0)
	var globe := map.globe()
	for port in PortDB.PORTS:
		var id := StringName(port.id)
		globe.look_at_port(id, 0.0)
		var p := globe.project(Globe.lonlat(port))
		_expect(p.z > 0.9, "%s faces the viewer when the globe looks at it" % id)
		var centre := globe.globe_rect().get_center()
		_expect(Vector2(p.x, p.y).distance_to(centre) < globe.globe_rect().size.x * 0.25,
			"and sits near the middle of the planet (%s)" % id)
		_expect(globe.port_at(Vector2(p.x, p.y)) == id, "tapping its pin picks it (%s)" % id)
	var far := PortDB.get_port(&"shanghai")
	globe.look_at_port(&"santos", 0.0)
	_expect(globe.project(Globe.lonlat(far)).z < 0.0,
		"Shanghai is on the far side of the world from Santos")
	map.queue_free()
	await get_tree().process_frame
	_finished.append("pins")


func _find(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null


func _tap(control: Control) -> void:
	## A press and a release with frames in between, which is what a finger is.
	## Emitting `pressed` directly would pass against the broken build.
	## `push_input`'s second argument is `in_local_coords`, and it is not
	## optional here: the root is a Window, so without it the position is treated
	## as screen coordinates, transformed, and lands nowhere. The event is
	## delivered either way and simply picks no control, which reads exactly like
	## a button that does not work.
	var centre := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = centre
	motion.global_position = centre
	get_viewport().push_input(motion, true)
	await get_tree().process_frame

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = centre
	press.global_position = centre
	get_viewport().push_input(press, true)
	# Long enough that the old every-frame rebuild would have freed the button
	# several times over.
	for i in 8:
		await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = centre
	release.global_position = centre
	get_viewport().push_input(release, true)
	await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
