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
const EXPECTED := ["rail_keys", "wheel", "daily", "ship_tap", "shop_buy", "upgrade_buy"]
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
	# A new terminal has the shop and settings only; the logbook (6) and routes
	# (8) arrive with the level. Check that, then play as a grown port.
	for entry: Dictionary in _main.rail._key_labels:
		var grown: bool = str(entry.stem) in ["rail.routes", "rail.journal"]
		_expect((entry.button as Button).visible != grown,
			"%s %s on a new terminal" % [entry.stem, "is hidden" if grown else "is shown"])
	_expect(not _main.shop._tab_buttons["upgrades"].visible
		and not _main.shop._tab_buttons["land"].visible,
		"and the shop opens with machines only")
	_main.level_service.rules.add_xp(TerminalLevel.xp_for_level(12))
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
	# and the missions at 4. Check that, then play as a port that has grown.
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
