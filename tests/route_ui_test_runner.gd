extends Node
## The route board as a player meets it.
## Run with:
## Godot --headless --path . res://tests/route_ui_test_runner.tscn
##
## `route_test_runner.gd` proves the lane *data* is sane. It passed happily for
## as long as buying a lane was flatly impossible, because nothing it checked
## went anywhere near the panel: the board rebuilt every card on every
## `teus_changed`, which `GameState._process` emits on every frame the port is
## earning, so the buy key was freed between the press and the release and the
## `pressed` signal never fired. A port with one machine could never open a
## second route, and the suite was green.
##
## So this suite drives the real control: a real press and a real release,
## separated by frames, on a port that is earning the whole time.

const TEST_SAVE_PATH := "user://harborclick_route_ui_test.json"

var failures: Array[String] = []
var _finished: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()

	await _test_the_buy_key_survives_a_tap_while_the_port_earns()
	await _test_a_real_tap_actually_opens_the_lane()
	await _test_the_whole_ladder_is_on_the_board()
	await _test_only_the_next_lane_can_be_bought()

	SaveManager.wipe()
	# A roll call, because a GDScript runtime error aborts the function it
	# happened in and returns to the caller as though it had finished.
	var expected := 4
	if _finished.size() != expected:
		failures.append("only %d of %d tests reached their last line (%s)"
			% [_finished.size(), expected, ", ".join(_finished)])
	if failures.is_empty():
		print("ROUTE UI TESTS PASSED (survives income, real tap buys, full ladder, order)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("ROUTE UI TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _fresh_port(teus: float) -> RouteMap:
	GameState.from_save({})
	GameState.teus = teus
	# A port that is actually producing. With `cps` at zero the defect this suite
	# exists for does not reproduce at all: nothing emits `teus_changed`.
	GameState.owned = {"estivador": 40}
	GameState.recompute()
	var map := RouteMap.new()
	add_child(map)
	await get_tree().process_frame
	map.open()
	await get_tree().process_frame
	await get_tree().process_frame
	return map


func _buy_button(map: RouteMap) -> Button:
	var next := RouteDB.next_purchase(GameState.routes)
	if next.is_empty():
		return null
	var card := _find(map, "Lane_%s" % str(next.id))
	if card == null:
		return null
	return card.get_node_or_null(^"Row/Buy") as Button


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


func _test_the_buy_key_survives_a_tap_while_the_port_earns() -> void:
	var map := await _fresh_port(1e6)
	var button := _buy_button(map)
	_expect(button != null, "the next lane has a buy key on the board")
	if button != null:
		var id := button.get_instance_id()
		_expect(GameState.cps > 0.0,
			"the port is earning, so teus_changed is firing every frame")
		for i in 20:
			await get_tree().process_frame
		_expect(is_instance_valid(button),
			"the buy key still exists after 20 frames of income")
		if is_instance_valid(button):
			_expect(button.get_instance_id() == id
					and button.is_inside_tree(),
				"it is the same node, still in the tree — not a replacement")
	map.queue_free()
	await get_tree().process_frame
	_finished.append("survives_income")


func _test_a_real_tap_actually_opens_the_lane() -> void:
	var map := await _fresh_port(1e6)
	var next := RouteDB.next_purchase(GameState.routes)
	var id := str(next.id)
	var button := _buy_button(map)
	_expect(button != null, "there is a key to press")
	if button != null:
		var before := GameState.teus
		await _tap(button)
		_expect(GameState.routes.has(id),
			"pressing the key opens the lane (%s)" % id)
		# The port keeps earning across the frames the tap spans, so the wallet
		# does not fall by exactly the price. One second of production is the
		# slack — enough to cover the tap, far too little to hide a missed debit.
		_expect(before - GameState.teus
				>= float(next.cost) - maxf(1.0, GameState.cps),
			"and the lane was paid for")
		_expect(RouteDB.owned(GameState.routes).size() == 2,
			"the port is now on two lanes")
	map.queue_free()
	await get_tree().process_frame
	_finished.append("real_tap_buys")


func _test_the_whole_ladder_is_on_the_board() -> void:
	## Every lane in the table has a row, including the ones far out of reach.
	## The board used to show only what was owned plus the single next purchase,
	## so a world map with six routes on it displayed two.
	var map := await _fresh_port(100.0)
	for route: Dictionary in RouteDB.ITEMS:
		_expect(_find(map, "Lane_%s" % str(route.id)) != null,
			"lane %s has a row on the chart" % str(route.id))
	map.queue_free()
	await get_tree().process_frame
	_finished.append("full_ladder")


func _test_only_the_next_lane_can_be_bought() -> void:
	## The rows further down the ladder are readable, not purchasable — and the
	## guard is in `_buy`, not only in the visuals.
	var map := await _fresh_port(1e18)
	var last := str(RouteDB.ITEMS[RouteDB.ITEMS.size() - 1].id)
	var card := _find(map, "Lane_%s" % last)
	_expect(card != null, "the furthest lane is on the board")
	if card != null:
		var buy := card.get_node_or_null(^"Row/Buy") as Button
		_expect(buy != null and not buy.visible,
			"and it has no live buy key while earlier lanes are unopened")
	var wallet := GameState.teus
	map._buy(last)
	_expect(not GameState.routes.has(last),
		"asking to buy it directly is refused")
	_expect(is_equal_approx(wallet, GameState.teus),
		"and refusing costs nothing")
	map.queue_free()
	await get_tree().process_frame
	_finished.append("order_enforced")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
