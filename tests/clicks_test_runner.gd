extends Node
## Real clicks, end to end.
##
## Every other suite calls handlers directly. This one boots the real main scene
## and pushes mouse events through the viewport, the way a finger arrives, so a
## control that is covered, zero-sized, ignoring the mouse or rebuilt between
## press and release fails here even when its handler works perfectly.
##
## Run with: Godot --headless --path . res://tests/clicks_test_runner.tscn

const TEST_SAVE_PATH := "user://harborclick_clicks_test.json"
## The roll call: a script error aborts a test silently and the runner would
## otherwise print PASSED with the stack trace above it.
const EXPECTED := ["rail_keys", "wheel", "daily", "ship_tap", "every_tap_counts",
	"shop_buy", "upgrade_buy"]
const OVERLAY_OF := {
	"rail.shop": "shop", "rail.routes": "routes",
	"rail.journal": "journal", "rail.settings": "settings",
}

var failures: Array[String] = []
var _reached: Array[String] = []
var _main: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	SaveManager.active_slot = -1
	GameState.from_save({})
	TimeManager.from_save({})
	UserPreferences.reduce_motion = true
	_main = load("res://scenes/Main.tscn").instantiate()
	add_child(_main)
	for i in 20:
		await get_tree().process_frame
	for path in [^"TutorialSpotlight", ^"OfflinePopup"]:
		var node := _main.get_node_or_null(path)
		if node != null:
			node.queue_free()
	await get_tree().process_frame

	await _test_every_rail_key_opens_and_escape_closes()
	await _test_the_wheel_button_opens_and_spins()
	await _test_the_daily_button_opens_the_orders()
	await _test_tapping_the_ship_moves_a_box()
	await _test_every_tap_on_the_ship_counts()
	await _test_tapping_a_machine_card_buys_it()
	await _test_tapping_an_upgrade_card_buys_it()

	for name in EXPECTED:
		_expect(_reached.has(name), "test '%s' ran to its last line" % name)
	_main.queue_free()
	await get_tree().process_frame
	SaveManager.wipe()
	if failures.is_empty():
		print("CLICKS TESTS PASSED (%d tests: %s)" % [EXPECTED.size(), ", ".join(EXPECTED)])
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("CLICKS TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


# ---------------------------------------------------------------- the tests

func _test_every_rail_key_opens_and_escape_closes() -> void:
	# A new terminal has the shop, the challenges and settings; routes
	# (10) arrive with the level. Check that, then play as a grown port.
	for entry: Dictionary in _main.rail._key_labels:
		var grown: bool = str(entry.stem) == "rail.routes"
		_expect((entry.button as Button).visible != grown,
			"%s %s on a new terminal" % [entry.stem, "is hidden" if grown else "is shown"])
	_expect(not _main.shop._tab_buttons["upgrades"].visible
		and not _main.shop._tab_buttons["land"].visible,
		"and the shop opens with machines only")
	_main.level_service.rules.add_xp(TerminalLevel.xp_for_level(18))
	_main.level_service.xp_changed.emit()
	await get_tree().process_frame
	for entry: Dictionary in _main.rail._key_labels:
		var stem := str(entry.stem)
		var key: Button = entry.button
		var overlay := str(OVERLAY_OF.get(stem, ""))
		_expect(key.is_visible_in_tree() and key.size.x > 20.0,
			"%s is on screen and big enough to hit" % stem)
		await _click(key.get_global_rect().get_center())
		_expect(bool(_main._overlay_state.get(overlay, false)),
			"a real click on %s opens its board" % stem)
		await _escape()
		_expect(not bool(_main._overlay_state.get(overlay, false)),
			"and Escape closes it again (%s)" % stem)
	_done("rail_keys")


func _test_the_wheel_button_opens_and_spins() -> void:
	# A new profile has neither key yet: the wheel arrives at terminal level 6
	# and the missions at 7. Check that, then play as a port that has grown.
	_expect(_main.wheel_button.visible and _main.daily_button.visible,
		"a grown terminal shows the wheel and the missions")
	var button: Button = _main.wheel_button._button
	_expect(button.is_visible_in_tree(), "the wheel button is on screen")
	await _click(button.get_global_rect().get_center())
	var panel: LuckyWheelPanel = _main.wheel_panel
	_expect(panel.is_open(), "a real click on the wheel button opens the wheel")
	_expect(bool(_main._overlay_state.get("wheel", false)),
		"and the port stops taking taps behind it")
	var spin: Button = panel._spin_button
	_expect(not spin.disabled, "a new profile has its free spin")
	var before: int = _main.wheel_service.wheel.spins_total
	await _click(spin.get_global_rect().get_center())
	for i in 30:
		await get_tree().process_frame
	_expect(_main.wheel_service.wheel.spins_total == before + 1,
		"a real click on GIRAR spins exactly once")
	_expect(_main.wheel_service.wheel.pending.is_empty(),
		"and the prize is paid when it stops")
	await _escape()
	_expect(not panel.is_open(), "Escape closes the wheel")
	_done("wheel")


func _test_the_daily_button_opens_the_orders() -> void:
	var button: Button = _main.daily_button._button
	_expect(button.is_visible_in_tree(), "the daily orders key is on screen")
	_expect(not button.get_global_rect().intersects(
			_main.wheel_button._button.get_global_rect()),
		"and it does not sit on the wheel's key")
	await _click(button.get_global_rect().get_center())
	for i in 3:
		await get_tree().process_frame
	_expect(_main.daily_panel.is_open(), "a real click on it opens the orders")
	_expect(bool(_main._overlay_state.get("daily", false)),
		"and the port stops taking taps behind it")
	await _escape()
	_expect(not _main.daily_panel.is_open(), "Escape closes the orders")
	_done("daily")


func _test_tapping_the_ship_moves_a_box() -> void:
	## The core loop, through the same path a finger takes: viewport -> world
	## input -> berth. The first ship has to be alongside first.
	var world: PortWorld = _main.world
	var deadline := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline and not world.ship.is_discharging():
		await get_tree().process_frame
	_expect(world.ship.is_discharging(), "the first ship comes alongside")
	var left: int = world.ship.cargo_left()
	var teus: float = GameState.teus
	var on_screen: Vector2 = world.get_canvas_transform() \
		* (world.ship.global_position + Vector2(PortLayout.SHIP_W * 0.5, 110.0))
	await _click(on_screen)
	for i in 90:
		await get_tree().process_frame
	_expect(world.ship.cargo_left() < left or GameState.teus > teus,
		"a real tap on the ship moves a box (left %d -> %d)" % [left, world.ship.cargo_left()])
	_done("ship_tap")


func _test_every_tap_on_the_ship_counts() -> void:
	## "I tapped the ship and nothing happened" — each way that used to happen,
	## through real touch events. Every tap must pay at the finger.
	var world: PortWorld = _main.world
	var berth: BerthCallController = world.berth
	var at: Vector2 = world.get_canvas_transform() \
		* (world.ship.global_position + Vector2(PortLayout.SHIP_W * 0.5, 110.0))
	GameState.surge_mult = 1.0
	GameState.recompute()

	# Two thumbs: the second lands before the first lifts. Both are taps.
	var before := GameState.teus
	_touch(0, at, true)
	_touch(1, at + Vector2(6, 4), true)
	_touch(0, at, false)
	_touch(1, at + Vector2(6, 4), false)
	await get_tree().process_frame
	_expect(GameState.teus - before >= 2.0 * GameState.click_power * 0.99,
		"two overlapping thumbs pay two taps (%.1f for click %.1f)"
			% [GameState.teus - before, GameState.click_power])

	# A finger that rolls on the glass: lots of path, no real movement.
	before = GameState.teus
	_touch(0, at, true)
	for step in [Vector2(5, 0), Vector2(-5, 3), Vector2(4, -4), Vector2(-4, 2), Vector2(3, 3)]:
		_drag(0, at + step)
	_touch(0, at + Vector2(3, 3), false)
	await get_tree().process_frame
	_expect(GameState.teus > before, "a wobbling finger is still a tap")

	# A real pan is not a tap.
	before = GameState.teus
	_touch(0, at, true)
	_drag(0, at + Vector2(0, 40))
	_touch(0, at + Vector2(0, 40), false)
	await get_tree().process_frame
	_expect(is_equal_approx(GameState.teus, before), "a 40px drag pans instead of tapping")

	# Six boxes already in the air: the tap pays and waits for a free hand.
	if world.ship.is_working():
		var flying: int = berth._in_flight
		berth._in_flight = BerthCallController.MAX_IN_FLIGHT
		before = GameState.teus
		var queued: int = berth._queued.size()
		_touch(0, at, true)
		_touch(0, at, false)
		await get_tree().process_frame
		_expect(GameState.teus > before, "a tap over the in-flight cap still pays")
		_expect(berth._queued.size() == queued + 1, "and queues its box instead of dropping it")
		berth._in_flight = flying
		berth._drain_queue()

	# A hull still coming alongside is on screen: tapping it pays.
	var phase: int = world.ship.phase
	world.ship.phase = Ship.Phase.ARRIVING
	before = GameState.teus
	_touch(0, at, true)
	_touch(0, at, false)
	await get_tree().process_frame
	_expect(GameState.teus > before, "tapping an arriving ship pays")
	world.ship.phase = phase
	_done("every_tap_counts")


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = pressed
	get_viewport().push_input(e, true)


func _drag(index: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = at
	get_viewport().push_input(e, true)


func _test_tapping_a_machine_card_buys_it() -> void:
	# This test is about the tap reaching the purchase; the build time that now
	# stands between a purchase and the machine has its own suite (`build`).
	GameState.build_times_enabled = false
	# A machine card is only revealed once the port has earned a quarter of its
	# price, so the wallet alone is not enough: lifetime has to be there too, or
	# the tap lands on the "???" teaser that stands in its place.
	GameState.teus = 1e6
	GameState.lifetime_teus = maxf(GameState.lifetime_teus, 1e6)
	var shop: Shop = _main.shop
	# `_on_tab` opens a closed sheet; on an open one it toggles the tab shut.
	if shop.is_open():
		shop._close()
	shop._on_tab("structures")
	for i in 4:
		await get_tree().process_frame
	var card: ShopCard = shop._cards["estivador"]
	var before := GameState.structure_count("estivador")
	await _click(card.get_global_rect().get_center())
	_expect(GameState.structure_count("estivador") == before + 1,
		"a real tap on a machine card buys one")
	_done("shop_buy")


func _test_tapping_an_upgrade_card_buys_it() -> void:
	GameState.teus = 1e6
	GameState.lifetime_teus = maxf(GameState.lifetime_teus, 1e6)
	var shop: Shop = _main.shop
	shop._on_tab("upgrades")
	for i in 4:
		await get_tree().process_frame
	var card: ShopCard = shop._cards["up_luvas"]
	_expect(card.is_visible_in_tree(), "the first upgrade is on the list")
	await _click(card.get_global_rect().get_center())
	_expect(GameState.has_upgrade("luvas"), "a real tap on an upgrade card buys it")
	await _escape()
	_done("upgrade_buy")


# ------------------------------------------------------------------ helpers

func _click(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	# `true`: the position is in the viewport's own coordinates. Without it a
	# synthetic click transforms to nowhere and hits nothing.
	get_viewport().push_input(down, true)
	await get_tree().process_frame
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	get_viewport().push_input(up, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _escape() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	get_viewport().push_input(key, true)
	await get_tree().process_frame
	var release := key.duplicate() as InputEventKey
	release.pressed = false
	get_viewport().push_input(release, true)
	await get_tree().process_frame


func _done(name: String) -> void:
	_reached.append(name)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
