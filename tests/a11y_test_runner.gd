extends Node
## Keyboard and screen-reader contract.
## Run with:
## Godot --headless --path . res://tests/a11y_test_runner.tscn
##
## The whole game has to be reachable with a keyboard and describable to a
## screen reader. Two things make that fail silently and are checked here: a
## control that cannot take focus at all, and a control whose only label is a
## picture.

const TEST_SAVE_PATH := "user://harborclick_a11y_test.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	GameState.from_save({})

	_test_theme_controls_are_reachable_and_named()
	await _test_card_is_a_button_for_the_keyboard()
	await _test_overlays_take_and_return_focus()

	SaveManager.wipe()
	if failures.is_empty():
		print("A11Y TESTS PASSED (focus, names, keyboard activation)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("A11Y TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_theme_controls_are_reachable_and_named() -> void:
	var text_key := UiTheme.button("COMPRAR")
	_expect(text_key.focus_mode == Control.FOCUS_ALL,
		"a themed key can take keyboard focus")
	_expect(text_key.accessibility_name == "COMPRAR",
		"a themed key names itself from its label")
	_expect(text_key.has_theme_stylebox_override(&"focus"),
		"a themed key draws a focus ring rather than relying on a tint")

	# An icon key has no text at all, so it is exactly the case where an
	# unnamed control becomes invisible to a screen reader.
	var icon_key := UiTheme.icon_button(UiTheme.Icon.GEAR, &"alt",
		UiTheme.TOUCH_MIN, "Ajustes")
	_expect(icon_key.accessibility_name == "Ajustes",
		"an icon key carries an explicit accessible name")
	_expect(not icon_key.tooltip_text.is_empty(),
		"an icon key also has a pointer tooltip")
	_expect(icon_key.custom_minimum_size.x >= UiTheme.TOUCH_MIN
			and icon_key.custom_minimum_size.y >= UiTheme.TOUCH_MIN,
		"an icon key meets the minimum touch target")

	var segment := UiTheme.segment("X10", false)
	_expect(segment.focus_mode == Control.FOCUS_ALL
			and segment.accessibility_name == "X10",
		"a bulk segment is reachable and named")
	text_key.free()
	icon_key.free()
	segment.free()


func _test_card_is_a_button_for_the_keyboard() -> void:
	var viewport := _make_viewport(Vector2i(360, 800))
	var card := ShopCard.new()
	card.setup("rtg", "structure", "rtg", "Transtêiner", "Empilha o pátio.")
	viewport.add_child(card)
	var bought: Array[String] = []
	card.pressed_card.connect(func(id: String) -> void: bought.append(id))
	await get_tree().process_frame

	_expect(card.focus_mode == Control.FOCUS_ALL,
		"a shop card can take keyboard focus")
	_expect(card.accessibility_name == "Transtêiner",
		"a shop card names itself for a screen reader")
	_expect(card.accessibility_description == "Empilha o pátio.",
		"a shop card describes what it does")

	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	card._gui_input(accept)
	_expect(bought.size() == 1, "Enter on a focused card buys once")

	# The dedupe window is shared with pointer input, so a key repeat arriving
	# straight after cannot buy a second time.
	card._gui_input(accept)
	_expect(bought.size() == 1, "an immediate key repeat does not buy again")

	viewport.queue_free()
	await get_tree().process_frame


func _test_overlays_take_and_return_focus() -> void:
	var viewport := _make_viewport(Vector2i(360, 800))
	var shop := Shop.new()
	viewport.add_child(shop)
	await get_tree().process_frame
	await get_tree().process_frame

	shop._launcher.grab_focus()
	await get_tree().process_frame
	shop._launcher.emit_signal("pressed")
	await get_tree().process_frame
	var focused := viewport.gui_get_focus_owner()
	_expect(focused != null and shop._board.is_ancestor_of(focused),
		"opening the shop moves focus inside the board")

	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	shop._unhandled_key_input(escape)
	await get_tree().process_frame
	_expect(not shop.is_open(), "Escape closes the shop")
	_expect(viewport.gui_get_focus_owner() == shop._launcher,
		"closing the shop hands focus back to the key that opened it")

	viewport.queue_free()
	await get_tree().process_frame


func _make_viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	return viewport


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
