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
	# Overlay open animations move boards for 0.18s; the layout contracts
	# below assert final geometry, so motion is off for the whole run.
	UserPreferences.reduce_motion = true

	await _test_hud_fixed_tally_geometry()
	await _test_rate_tag_never_runs_under_the_clock()
	await _test_shop_card_release_and_drag_contract()
	await _test_shop_backdrop_and_escape_contract()
	await _test_responsive_shell_profiles_without_main_scene()
	await _test_safe_area_reaches_primary_ui()
	await _test_upgrade_map_is_a_navigable_graph()
	await _test_upgrade_list_sells_in_sections()
	await _test_pop_open_yields_to_a_layout_mid_slide()

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

	# The tally is a shared Readout: the same control renders over the port in
	# portrait and inside the command rail on a wide screen, so this contract
	# is proved once for both.
	var readout: Readout = hud._readout
	readout._on_teus(0.0)
	readout._process(0.06)
	var tally := readout._teus_label.get_parent() as HBoxContainer
	var icon := tally.get_child(0) as Control
	var icon_before := icon.get_global_rect()
	var slot_before := readout._teus_label.get_global_rect()
	var rate_before := readout._rate_label.get_global_rect()

	readout._on_teus(1e15)
	readout._process(0.06)
	await get_tree().process_frame
	_expect(readout._teus_label.text == GameState.fmt(1e15),
		"HUD renders the 1e15 tally through the normal formatter")
	_expect(_same_rect(icon.get_global_rect(), icon_before),
		"HUD tally icon does not move from 0 to 1e15")
	# The digits are left-aligned with no panel around them, so the number's
	# origin is invariant and only its unused right edge extends into air.
	_expect(is_equal_approx(readout._teus_label.get_global_rect().position.x,
			slot_before.position.x)
		and is_equal_approx(readout._teus_label.get_global_rect().position.y,
			slot_before.position.y),
		"HUD numeric slot keeps its origin from 0 to 1e15")
	_expect(_same_rect(readout._rate_label.get_global_rect(), rate_before),
		"HUD rate line with the TEU unit does not move from 0 to 1e15")

	# The berth tag is gone from the interface: it restated what the port was
	# already showing and cost a strip of a phone screen to do it. The state still
	# travels through the same entry point for the accessibility tree and the
	# tests, but nothing may draw it and nothing may move the tally.
	var readout_before_hint := hud.readout_rect()
	hud.set_job_hint("Carregamento em andamento 24/24 — manifesto conferido")
	await get_tree().process_frame
	_expect(hud.berth_text() == "Carregamento em andamento 24/24 — manifesto conferido",
		"HUD public text update replaces berth text")
	for child in hud.get_children():
		_expect(child == hud._bar or child is Readout,
			"the gantry carries only the tally, not a berth tag (%s)" % child)
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

	# A wide window is pillarboxed by PortraitFrame, so the shell must not invent
	# a second profile for it: the game has one layout, and this is the test that
	# fails if a wide branch is ever reintroduced without a way to reach it.
	var wide_viewport := _make_viewport(Vector2i(1000, 700))
	var wide_shell := ResponsiveShell.new()
	wide_viewport.add_child(wide_shell)
	await get_tree().process_frame
	_expect(wide_shell.metrics.get("profile") == "portrait",
		"ResponsiveShell reports one profile even for a wide viewport")
	var wide_world: Rect2 = wide_shell.metrics.get("world_rect", Rect2())
	_expect(_same_rect(wide_world, Rect2(Vector2.ZERO, Vector2(1000, 700))),
		"the port keeps the whole safe area at any window size")

	portrait_viewport.queue_free()
	wide_viewport.queue_free()
	await get_tree().process_frame


func _test_safe_area_reaches_primary_ui() -> void:
	var viewport := _make_viewport(Vector2i(360, 800))
	var hud := Hud.new()
	var shop := Shop.new()
	var settings := SettingsPanel.new()
	var bell := NoticeBell.new()
	viewport.add_child(hud)
	viewport.add_child(shop)
	viewport.add_child(settings)
	viewport.add_child(bell)
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
	bell.apply_view_metrics(metrics)
	await get_tree().process_frame

	# The keys live on the console, so that is what has to respect the
	# gesture-safe inset.
	var rail := CommandRail.new()
	viewport.add_child(rail)
	await get_tree().process_frame
	rail.apply_view_metrics(metrics)
	await get_tree().process_frame
	_expect(_rect_inside(safe, hud.readout_rect()),
		"HUD tally stays inside an injected mobile safe area")
	_expect(_rect_inside(safe, rail._bar.get_global_rect()),
		"the portrait key bar stays above the gesture-safe inset")
	_expect(_rect_inside(safe, rail.head_rect()),
		"the console head stays above the gesture-safe inset")

	shop.toggle()
	settings.open()
	await get_tree().process_frame
	_expect(_rect_inside(safe, shop._board.get_global_rect()),
		"Shop sheet stays inside an injected mobile safe area")
	_expect(_rect_inside(safe, settings._panel.get_global_rect()),
		"Settings panel stays inside an injected mobile safe area")
	# Notices no longer land on the port. The bell is a key on the gantry, so what
	# has to hold is that it stays reachable inside the safe area and that its log
	# opens under the bar rather than over it.
	_expect(_rect_inside(safe, bell._button.get_global_rect()),
		"the notice bell stays inside an injected mobile safe area")
	bell.open_log()
	await get_tree().process_frame
	_expect(_rect_inside(safe, bell._board.get_global_rect()),
		"the notice log stays inside an injected mobile safe area")
	_expect(bell._board.get_global_rect().position.y >= safe.position.y + Hud.BAR_H,
		"the notice log hangs below the gantry")
	bell.close_log()

	viewport.queue_free()
	await get_tree().process_frame


func _test_rate_tag_never_runs_under_the_clock() -> void:
	## Reported from a real session: the cat boost's "x3 12s" drew under the
	## compass. The tag's budget was measured once at layout, before the boost
	## existed, and the clock's width was a fixed guess the day number and the
	## language could both outgrow. This builds the worst gantry the game can
	## produce — narrowest phone, longest day label, biggest rate, boost and lift
	## badge all at once — and checks that the tag still stops short of the dial.
	var restore_language := Loc.preference
	var restore_day := TimeManager.day
	var restore_boost := GameState.boost_time
	var viewport := _make_viewport(Vector2i(320, 640))
	var hud := Hud.new()
	viewport.add_child(hud)
	var clock := PortClock.new()
	viewport.add_child(clock)
	await get_tree().process_frame
	var area := Rect2(Vector2.ZERO, Vector2(320.0, 640.0))
	var metrics := {"profile": "portrait", "viewport_size": area.size,
		"safe_rect": area, "world_rect": area}
	hud.apply_view_metrics(metrics)
	clock.apply_view_metrics(metrics)
	hud.set_clock(clock)
	var readout: Readout = hud._readout

	# Roomy first: nothing may be trimmed when nothing needs to be.
	var wide := _make_viewport(Vector2i(900, 640))
	var roomy := Hud.new()
	wide.add_child(roomy)
	await get_tree().process_frame
	roomy.apply_view_metrics({"safe_rect": Rect2(0, 0, 900, 640),
		"world_rect": Rect2(0, 0, 900, 640)})
	GameState.boost_time = 12.0
	roomy._readout._process(0.06)
	roomy._readout._on_cps(1000.0)
	await get_tree().process_frame
	_expect(roomy._readout._boost_label.text.ends_with("s"),
		"a gantry with room shows the boost countdown in full")
	_expect(not roomy._readout._rate_label.clip_text,
		"and does not trim the rate")
	wide.queue_free()

	Loc.apply(&"it")
	for day in [1, 100, 10000]:
		# Settle the gantry with no boost on it first. The real bug only showed
		# when the boost arrived *after* layout with nothing else moving — any
		# other change in the same frame (a day rolling over, a resize) re-fitted
		# the tag and hid it, which is exactly how a first draft of this test
		# passed against the broken code.
		GameState.boost_time = 0.0
		readout._process(0.06)
		TimeManager.day = day
		clock._process(0.0)
		readout._on_cps(8.0e30)
		await get_tree().process_frame
		# Now the cat, and a purchase, into a gantry nobody is re-laying out.
		GameState.boost_time = 12.0
		readout._process(0.06)
		readout._on_cps(8.8e36)
		await get_tree().process_frame
		var tag := readout._rate_tag.get_global_rect()
		var dial := clock._board.get_global_rect()
		_expect(tag.end.x <= dial.position.x,
			"the rate tag ends before the clock on day %d (%.1f > %.1f)"
				% [day, tag.end.x, dial.position.x])
		_expect(dial.end.x <= area.end.x - NoticeBell.RESERVE,
			"and the clock stays clear of the notice bell on day %d" % day)
		_expect(readout._rate_label.text.begins_with(GameState.fmt(8.8e36)),
			"the rate is trimmed for room, never replaced (day %d)" % day)

	# The boost ending hands its room back.
	GameState.boost_time = 0.0
	readout._process(0.06)
	await get_tree().process_frame
	_expect(not readout._boost_row.visible, "the boost badge goes when the boost does")
	_expect(readout._rate_tag.get_global_rect().end.x <= clock._board.get_global_rect().position.x,
		"and the tag still ends before the clock afterwards")

	Loc.apply(StringName(restore_language))
	TimeManager.day = restore_day
	GameState.boost_time = restore_boost
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


func _test_pop_open_yields_to_a_layout_mid_slide() -> void:
	## The open slide used to remember where the board was when it started and
	## drag it back there at the end. A resize during those 0.18s re-laid the
	## board correctly and the tween then undid it: the capture matrix caught the
	## shop at 360x800 ending 137px low, its bottom off the screen.
	UserPreferences.reduce_motion = false
	var layer := CanvasLayer.new()
	add_child(layer)
	var board := PanelContainer.new()
	board.size = Vector2(200, 100)
	board.position = Vector2(6, 275)
	layer.add_child(board)
	UiTheme.pop_open(board)
	await get_tree().process_frame
	await get_tree().process_frame
	board.position = Vector2(6, 138)          # the layout, answering a resize
	await get_tree().create_timer(0.35).timeout
	_expect(board.position.is_equal_approx(Vector2(6, 138)),
		"the slide lands where the latest layout put the board (%s)" % board.position)
	_expect(is_equal_approx(board.modulate.a, 1.0), "and fully opaque")
	UserPreferences.reduce_motion = true
	layer.queue_free()
	await get_tree().process_frame


func _test_upgrade_list_sells_in_sections() -> void:
	## The upgrades tab opens on a list: what can be bought now (cheapest first),
	## what is next and why it is shut, and what is owned, folded away. Three
	## things it must never do: lose a card, rebuild a card under a finger, or
	## show a card with no effect line — the rail nodes used to print nothing.
	GameState.from_save({"owned": {"estivador": 30}, "upgrades": ["luvas"],
		"teus": 1e9, "lifetime": 1e9, "all_time_teus": 1e9})
	GameState.recompute()
	var viewport := _make_viewport(Vector2i(390, 844))
	var shop := Shop.new()
	viewport.add_child(shop)
	await get_tree().process_frame
	shop._on_tab("upgrades")
	await get_tree().process_frame
	await get_tree().process_frame

	for item in UpgradeDB.ITEMS:
		_expect(shop._cards.has("up_" + str(item.id)),
			"every upgrade has a card (%s)" % item.id)
		_expect(not str(GameState.upgrade_preview(item).get("text", "")).is_empty(),
			"every upgrade can say what it does (%s)" % item.id)
	var gancho: ShopCard = shop._cards["up_gancho"]
	var luvas: ShopCard = shop._cards["up_luvas"]
	_expect(gancho.visible, "a node whose parent is owned is on sale")
	_expect(gancho.get_index() < shop._up_caption_next.get_index(),
		"and listed under DISPONÍVEIS, above what comes next")
	_expect(not luvas.visible, "owned nodes are folded away by default")

	var before := gancho.get_instance_id()
	shop._refresh_upgrades()
	shop._refresh_upgrades()
	_expect(gancho.get_instance_id() == before and is_instance_valid(gancho),
		"refreshing restyles cards, it never rebuilds them")

	gancho.pressed_card.emit("gancho")
	await get_tree().process_frame
	_expect(GameState.has_upgrade("gancho"), "tapping an available card buys it")
	shop._refresh_upgrades()
	_expect(not gancho.visible and shop._up_owned_toggle.text.contains("2"),
		"and it folds into COMPRADAS, which now counts two")
	shop._up_owned_toggle.emit_signal("pressed")
	_expect(luvas.visible and gancho.visible, "unfolding COMPRADAS shows them")

	shop._up_view_toggle.emit_signal("pressed")
	_expect(shop._up_map_view.visible and not shop._up_list_view.visible,
		"the map is one key away")
	shop._up_view_toggle.emit_signal("pressed")
	_expect(shop._up_list_view.visible, "and so is the way back")
	viewport.queue_free()
	await get_tree().process_frame
	GameState.from_save({})


func _test_upgrade_map_is_a_navigable_graph() -> void:
	## The upgrades tab is a diagram now, and a diagram has three ways of being
	## quietly wrong that no screenshot review would catch: a station missing from
	## it, a child drawn west of the thing that opens it, and a tap that lands on
	## the wrong station because two are near each other.
	GameState.from_save({"owned": {"estivador": 30},
		"upgrades": ["cafe_forte"], "teus": 1e9, "all_time_teus": 1e9})
	GameState.recompute()
	var map := UpgradeMap.new()
	map.size = Vector2(340, 380)
	add_child(map)
	await get_tree().process_frame

	for item in UpgradeDB.ITEMS:
		_expect(map._nodes.has(str(item.id)),
			"every upgrade is a station on the map (%s)" % item.id)
	_expect(map._nodes.size() == UpgradeDB.ITEMS.size(),
		"and the map invents none of its own")

	# West-to-east is the whole grammar of the picture: a station you can only
	# reach through another has to be drawn further along the line than it.
	for item in UpgradeDB.ITEMS:
		var id := str(item.id)
		for parent in UpgradeDB.requires_of(item):
			_expect(float(map._nodes[parent].pos.x) < float(map._nodes[id].pos.x),
				"%s is drawn east of %s" % [id, parent])

	# The three states the map draws, against a port that has exactly one of each.
	_expect(map._state_of("cafe_forte") == 2, "a bought station is lit")
	_expect(map._state_of("carrinho_mao") == 1, "the next one along is open")
	_expect(map._state_of("sindicato") == 0, "and the one past that is shut")

	# A tap has to select the station under the finger, and a drag has to select
	# nothing at all — this is the whole reason the map does its own panning.
	map.reset_view()
	var picked: Array[String] = []
	map.node_selected.connect(func(id: String) -> void: picked.append(id))
	var target: Vector2 = map._to_screen(Vector2(map._nodes["cafe_forte"].pos))
	map._begin_press(target)
	map._end_press(target)
	_expect(picked.size() == 1 and picked[0] == "cafe_forte",
		"a tap selects the station under it (%s)" % str(picked))
	picked.clear()
	map._begin_press(target)
	map._end_press(target + Vector2(60.0, 0.0))
	_expect(picked.is_empty(), "a drag pans the map instead of buying something")

	# Zoom is about the finger, not about the origin: whatever was under the
	# pinch has to still be under it afterwards, or the map fights the player.
	var anchor := Vector2(170.0, 190.0)
	var before := map._to_map(anchor)
	map._set_zoom(map._zoom * 1.6, anchor)
	_expect(map._to_map(anchor).distance_to(before) < 0.75,
		"zoom keeps the point under the fingers where it was")
	map.queue_free()


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
