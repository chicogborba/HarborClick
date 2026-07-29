extends Node
## Headless UI contract suite.
## Run with: Godot --headless --path . res://tests/ui_p0_test_runner.tscn

const TEST_SAVE_PATH := "user://harborclick_ui_p0_test.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	GameState.from_save({})

	await _test_hud_fixed_tally_geometry()
	await _test_shop_card_release_and_drag_contract()
	await _test_shop_backdrop_and_escape_contract()
	await _test_responsive_shell_profiles_without_main_scene()
	await _test_safe_area_reaches_primary_ui()

	SaveManager.wipe()
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH), "cleanup removes UI test save")
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH + ".bak"), "cleanup removes UI test backup")
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH + ".tmp"), "cleanup removes UI test temporary save")

	if failures.is_empty():
		print("UI P0 TESTS PASSED (HUD, ShopCard, Shop, ResponsiveShell)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("UI P0 TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_hud_fixed_tally_geometry() -> void:
	var viewport := _make_viewport(Vector2i(360, 800))
	var hud := Hud.new()
	viewport.add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame

	hud._on_teus(0.0)
	hud._process(0.06)
	var tally := hud._teus_label.get_parent() as HBoxContainer
	var icon := tally.get_child(0) as Control
	var icon_before := icon.get_global_rect()
	var slot_before := hud._teus_label.get_global_rect()
	var rate_before := hud._rate_label.get_global_rect()

	hud._on_teus(1e15)
	hud._process(0.06)
	await get_tree().process_frame
	_expect(hud._teus_label.text == GameState.fmt(1e15),
		"HUD renders the 1e15 tally through the normal formatter")
	_expect(_same_rect(icon.get_global_rect(), icon_before),
		"HUD tally icon does not move from 0 to 1e15")
	# The digits are left-aligned with no panel around them, so the number's
	# origin is invariant and only its unused right edge extends into air.
	_expect(is_equal_approx(hud._teus_label.get_global_rect().position.x,
			slot_before.position.x)
		and is_equal_approx(hud._teus_label.get_global_rect().position.y,
			slot_before.position.y),
		"HUD numeric slot keeps its origin from 0 to 1e15")
	_expect(_same_rect(hud._rate_label.get_global_rect(), rate_before),
		"HUD rate line with the TEU unit does not move from 0 to 1e15")

	# set_job_hint is the public text-only berth update entry point. Its chip is
	# deliberately independent from the tally, so text of any length may resize
	# the chip but must never move the readout.
	hud.set_job_hint("Descarga 0/24")
	await get_tree().process_frame
	var short_chip := hud._berth_chip.get_global_rect()
	var readout_before_hint := hud.readout_rect()
	hud.set_job_hint("Carregamento em andamento 24/24 — manifesto conferido")
	await get_tree().process_frame
	var long_chip := hud._berth_chip.get_global_rect()
	_expect(hud._job_label.text == "Carregamento em andamento 24/24 — manifesto conferido",
		"HUD public text update replaces berth text")
	_expect(hud._job_label.clip_text,
		"HUD berth label clips long status text")
	_expect(hud._job_label.get_global_rect().size.x <= long_chip.size.x,
		"HUD berth text viewport remains within its chip")
	_expect(long_chip.size.x > short_chip.size.x and long_chip.end.x <= 360.0,
		"HUD berth chip grows with its text but stays inside the viewport")
	_expect(_same_rect(hud.readout_rect(), readout_before_hint),
		"HUD berth text update does not move the tally")

	viewport.queue_free()
	await get_tree().process_frame


func _test_shop_card_release_and_drag_contract() -> void:
	var viewport := _make_viewport(Vector2i(360, 800))
	var card := ShopCard.new()
	card.setup("test_card", "structure", "", "Teste", "Contrato de toque")
	viewport.add_child(card)
	var activation_ids: Array[String] = []
	card.pressed_card.connect(func(id: String) -> void: activation_ids.append(id))
	await get_tree().process_frame

	for drag_index in 100:
		var start := Vector2(8.0 + float(drag_index % 3), 12.0)
		var end := start + Vector2(10.0, 0.0)
		if drag_index % 2 == 0:
			_card_mouse(card, true, start)
			_card_mouse_motion(card, end)
			_card_mouse(card, false, end)
		else:
			_card_touch(card, true, start)
			_card_screen_drag(card, end)
			_card_touch(card, false, end)
	_expect(activation_ids.is_empty(), "ShopCard rejects all 100 drags at the 10 px cancellation threshold")

	var tap := Vector2(16.0, 16.0)
	_card_mouse(card, true, tap)
	_expect(activation_ids.is_empty(), "ShopCard does not buy on mouse press")
	_card_mouse(card, false, tap)
	_expect(activation_ids.size() == 1, "ShopCard buys exactly once on mouse release")
	_card_touch(card, true, tap)
	_card_touch(card, false, tap)
	_expect(activation_ids.size() == 1, "ShopCard deduplicates immediate emulated mouse/touch activation")

	viewport.queue_free()
	await get_tree().process_frame


func _test_shop_backdrop_and_escape_contract() -> void:
	var viewport := _make_viewport(Vector2i(360, 800))
	var shop := Shop.new()
	viewport.add_child(shop)
	await get_tree().process_frame
	await get_tree().process_frame

	# Button signal opens the actual sheet. Direct handler calls below are the
	# nearest public-facing units that can be exercised without a window-backed
	# GUI input router in headless mode.
	shop._launcher.emit_signal("pressed")
	_expect(shop.is_open() and shop._backdrop.visible and shop._board.visible,
		"Shop opens from its launcher")
	var backdrop_press := InputEventMouseButton.new()
	backdrop_press.button_index = MOUSE_BUTTON_LEFT
	backdrop_press.pressed = true
	shop._on_backdrop_input(backdrop_press)
	_expect(not shop.is_open() and not shop._backdrop.visible and not shop._board.visible,
		"Shop closes from its backdrop handler")

	shop._launcher.emit_signal("pressed")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	shop._unhandled_key_input(escape)
	_expect(not shop.is_open(), "Shop closes from Escape")

	viewport.queue_free()
	await get_tree().process_frame


func _test_responsive_shell_profiles_without_main_scene() -> void:
	var portrait_viewport := _make_viewport(Vector2i(360, 800))
	var portrait_shell := ResponsiveShell.new()
	portrait_viewport.add_child(portrait_shell)
	await get_tree().process_frame
	_expect(portrait_shell.metrics.get("profile") == "portrait",
		"ResponsiveShell classifies a portrait viewport without Main")
	var portrait_world: Rect2 = portrait_shell.metrics.get("world_rect", Rect2())
	_expect(_same_rect(portrait_world, Rect2(Vector2.ZERO, Vector2(360, 800))),
		"ResponsiveShell leaves the full world rail available in portrait")

	var desktop_viewport := _make_viewport(Vector2i(1000, 700))
	var desktop_shell := ResponsiveShell.new()
	desktop_viewport.add_child(desktop_shell)
	await get_tree().process_frame
	_expect(desktop_shell.metrics.get("profile") == "desktop",
		"ResponsiveShell classifies a wide viewport as desktop without Main")
	var desktop_world: Rect2 = desktop_shell.metrics.get("world_rect", Rect2())
	_expect(is_equal_approx(desktop_world.size.x, floorf(1000.0 * ResponsiveShell.WORLD_DESKTOP_FRACTION)),
		"ResponsiveShell computes the desktop world rail from WORLD_DESKTOP_FRACTION")
	_expect(is_equal_approx(desktop_world.size.y, 700.0) and is_zero_approx(desktop_world.position.x),
		"ResponsiveShell keeps the desktop world rail aligned to the left safe area")

	portrait_viewport.queue_free()
	desktop_viewport.queue_free()
	await get_tree().process_frame


func _test_safe_area_reaches_primary_ui() -> void:
	var viewport := _make_viewport(Vector2i(360, 800))
	var hud := Hud.new()
	var shop := Shop.new()
	var settings := SettingsPanel.new()
	var toasts := ToastLayer.new()
	viewport.add_child(hud)
	viewport.add_child(shop)
	viewport.add_child(settings)
	viewport.add_child(toasts)
	await get_tree().process_frame
	await get_tree().process_frame

	var safe := Rect2(Vector2(12.0, 30.0), Vector2(336.0, 720.0))
	var metrics := {
		"profile": "portrait",
		"viewport_size": Vector2(360.0, 800.0),
		"safe_rect": safe,
		"world_rect": safe,
	}
	hud.apply_view_metrics(metrics)
	shop.apply_view_metrics(metrics)
	settings.apply_view_metrics(metrics)
	toasts.apply_view_metrics(metrics)
	await get_tree().process_frame

	var gear := hud.get_node(^"SettingsGear") as Button
	_expect(_rect_inside(safe, hud.readout_rect()),
		"HUD plate stays inside an injected mobile safe area")
	_expect(_rect_inside(safe, gear.get_global_rect()),
		"HUD gear stays inside an injected mobile safe area")
	_expect(_rect_inside(safe, shop._launcher.get_global_rect()),
		"Shop launcher stays above the gesture-safe inset")

	shop._launcher.emit_signal("pressed")
	settings.open()
	await get_tree().process_frame
	_expect(_rect_inside(safe, shop._board.get_global_rect()),
		"Shop sheet stays inside an injected mobile safe area")
	_expect(_rect_inside(safe, settings._panel.get_global_rect()),
		"Settings panel stays inside an injected mobile safe area")
	_expect(toasts._stack.position.x >= safe.position.x \
			and toasts._stack.position.x + toasts._stack.custom_minimum_size.x <= safe.end.x,
		"Toast stack stays horizontally inside an injected mobile safe area")

	viewport.queue_free()
	await get_tree().process_frame


func _make_viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	return viewport


func _card_mouse(card: ShopCard, pressed: bool, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	card._gui_input(event)


func _card_mouse_motion(card: ShopCard, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	card._gui_input(event)


func _card_touch(card: ShopCard, pressed: bool, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	event.position = position
	card._gui_input(event)


func _card_screen_drag(card: ShopCard, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.position = position
	card._gui_input(event)


func _same_rect(left: Rect2, right: Rect2) -> bool:
	return left.position.is_equal_approx(right.position) and left.size.is_equal_approx(right.size)


func _rect_inside(outer: Rect2, inner: Rect2) -> bool:
	var epsilon := 0.01
	return inner.position.x + epsilon >= outer.position.x \
		and inner.position.y + epsilon >= outer.position.y \
		and inner.end.x <= outer.end.x + epsilon \
		and inner.end.y <= outer.end.y + epsilon


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
