extends Node
## Run with: Godot --headless --path . res://tests/phase3_progression_ui_test_runner.tscn

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_safe_area_and_journal_close()
	await _test_pin_and_objective_contract()
	await _test_prestige_requires_explicit_confirmation()
	await _test_spotlight_steps_and_safe_target()
	if failures.is_empty():
		print("PHASE 3 PROGRESSION UI TESTS PASSED")
		get_tree().quit(0)
	else:
		for failure in failures: push_error(failure)
		print("PHASE 3 PROGRESSION UI TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_safe_area_and_journal_close() -> void:
	var viewport := _viewport(Vector2i(360, 800))
	var journal := PortJournal.new()
	viewport.add_child(journal)
	await get_tree().process_frame
	var safe := Rect2(Vector2(12, 30), Vector2(336, 720))
	journal.apply_view_metrics({"safe_rect": safe, "profile": "portrait"})
	journal.open()
	await get_tree().process_frame
	_expect(_inside(safe, journal._sheet.get_global_rect()), "journal mobile sheet remains inside safe area")
	# The board starts far enough down for its spring clip to be on screen, so
	# "almost full height" now means the safe area minus that clip and a margin.
	_expect(journal._sheet.size.y >= safe.size.y - 30.0, "journal is almost full-height on mobile")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	journal._on_backdrop_input(click)
	_expect(not journal.is_open(), "journal closes when outside backdrop is pressed")
	journal.open()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	journal._unhandled_key_input(escape)
	_expect(not journal.is_open(), "journal closes with Escape")
	viewport.queue_free()
	await get_tree().process_frame


func _test_pin_and_objective_contract() -> void:
	var viewport := _viewport(Vector2i(420, 700))
	var pinned: Array[StringName] = []
	var accepted: Array[StringName] = []
	var objectives := [{"id": "quay", "title": "Movimente carga", "progress": 4.0, "target": 10.0, "reward": {"capital": 1}, "complete": false}]
	var journal := PortJournal.new()
	journal.setup(null, {
		"get_objectives": func() -> Array: return objectives,
		"pin": func(id: StringName) -> bool: pinned.append(id); return true,
	})
	viewport.add_child(journal)
	journal.open()
	await get_tree().process_frame
	journal._pin(&"quay")
	_expect(pinned == [&"quay"], "journal invokes injected objective pin callback")
	# Charters are events now, not a card on this board. The Diário must not carry
	# one at all, and the alert is what answers for them.
	_expect(not journal.has_method("_accept_contract"),
		"the objective board no longer owns contracts")
	var alert := SpecialCallAlert.new()
	viewport.add_child(alert)
	await get_tree().process_frame
	alert.accepted.connect(func() -> void: accepted.append(&"aceita"))
	alert.declined.connect(func() -> void: accepted.append(&"recusada"))
	var offer := SpecialCallDB.materialize(4242, 0)
	alert.open(offer, 30.0)
	_expect(alert.is_open() and alert._title.text == str(offer.title),
		"the charter alert states which charter it is")
	_expect(alert._reward.text.length() > 12 and alert._penalty.text.length() > 12,
		"the alert states the prize and the forfeit before an answer")
	alert._on_accept()
	_expect(accepted == [&"aceita"] and not alert.is_open(),
		"accepting answers once and closes the board")
	alert.open(offer, 30.0)
	alert._on_decline()
	_expect(accepted == [&"aceita", &"recusada"],
		"refusing is a first-class answer")
	alert._on_decline()
	_expect(accepted.size() == 2, "a closed alert cannot answer twice")
	# The objective used to live on a chip over the port, which was hidden, and
	# on the desktop rail, which was unreachable — so it was visible nowhere. It
	# is a line on the console now, and this is the test that says so.
	var console := CommandRail.new()
	viewport.add_child(console)
	await get_tree().process_frame
	console.set_objective_source(func() -> Dictionary:
		return {"title": "Movimente carga", "progress": 4.0, "target": 10.0,
			"pinned": true})
	# Against the translation, not against the Portuguese: the console speaks the
	# player's language now, so asserting a literal here would only pass on a
	# machine whose phone happens to be set to pt-BR.
	_expect(console._objective_label.text.begins_with(
			Loc.t("rail.objective.pinned")),
		"the console labels a pinned objective as pinned")
	_expect(console._objective_value.text == "4/10",
		"the console renders the pinned objective's progress")
	viewport.queue_free()
	await get_tree().process_frame


func _test_prestige_requires_explicit_confirmation() -> void:
	var viewport := _viewport(Vector2i(800, 600))
	var commits := [0]
	var dialog := PrestigeDialog.new()
	dialog.setup({"quote": func() -> Dictionary: return {"gain": 3, "peak": 1000, "rebuild_discount": "10%"}, "commit": func() -> Dictionary: commits[0] += 1; return {"ok": true}})
	viewport.add_child(dialog)
	await get_tree().process_frame
	dialog.open()
	dialog._confirm_or_quote()
	_expect(commits[0] == 0 and dialog._quoted, "prestige first action only displays a quote")
	dialog._confirm_or_quote()
	_expect(commits[0] == 1 and not dialog.is_open(), "prestige commits only after explicit second confirmation")
	# One caption plus one row per node, so the whole tree fits a phone column
	# instead of running off the side of the dialog. Only purchasable branches
	# are drawn: a feature-gated node is refused by `GameState.buy_prestige_node`,
	# so a priced button for it swallows the press without a word.
	var branches := PrestigeDB.purchasable_branches()
	var node_rows := 0
	for branch: Dictionary in branches:
		node_rows += branch.get("nodes", []).size()
	_expect(dialog._tree.get_child_count() == branches.size() + node_rows,
		"prestige dialog renders every purchasable branch and node as its own row")
	viewport.queue_free()
	await get_tree().process_frame


func _test_spotlight_steps_and_safe_target() -> void:
	## Alisson's tour: talking steps wait for a tap, action steps for the action,
	## and nothing outside the highlight can be pressed.
	var viewport := _viewport(Vector2i(360, 800))
	var target := [Rect2(Vector2(24, 80), Vector2(90, 40))]
	var shop_open := [false]
	var closed := [0]
	var journal_open := [false]
	var spotlight := TutorialSpotlight.new()
	spotlight.setup({
		"get_target_rect": func(_key: String) -> Rect2: return target[0],
		"ship_ready": func() -> bool: return true,
		"shop_open": func() -> bool: return shop_open[0],
		"close_shop": func() -> void: closed[0] += 1; shop_open[0] = false,
		"journal_open": func() -> bool: return journal_open[0],
	})
	viewport.add_child(spotlight)
	await get_tree().process_frame
	var safe := Rect2(Vector2(10, 24), Vector2(340, 740))
	spotlight.apply_view_metrics({"safe_rect": safe})
	spotlight.start()
	var ids := []
	for step in spotlight.STEPS:
		ids.append(str(step.id))
	_expect(ids == ["intro", "intro2", "wait", "navio", "teu", "loja", "compra",
		"desafios", "fim"], "the tour is Alisson's nine steps (%s)" % [ids])
	_expect(spotlight._veil.mouse_filter == Control.MOUSE_FILTER_STOP,
		"the veil stops presses")
	# Let him hop in from the edge to centre stage.
	for i in 90:
		spotlight._process(0.016)
	_expect(_inside(safe, spotlight._bubble.get_global_rect()),
		"his speech bubble stays inside the safe area")
	_expect(_inside(safe, spotlight._walker.get_global_rect()),
		"and so does he, once he has hopped in")

	# Step 0 talks: a tap on the box moves on (after finishing the typed line).
	_expect(spotlight._until() == "ok" and not spotlight._skip.visible,
		"the hello waits for a tap and cannot be skipped")
	spotlight._advance_by_tap()
	if spotlight._index == 0:
		spotlight._advance_by_tap()
	_expect(spotlight._index == 1, "a tap on the box moves on")
	spotlight._body.visible_characters = -1
	spotlight._advance_by_tap()
	spotlight._process(0.016)
	_expect(spotlight._index == 3 and spotlight._until() == "taps",
		"with a ship alongside the wait step passes straight to the taps")

	# The highlight lets presses through; everywhere else is solid.
	spotlight._process(0.016)
	var veil: Control = spotlight._veil
	_expect(not veil._has_point(target[0].get_center()),
		"a press inside the highlight reaches the game")
	_expect(veil._has_point(Vector2(300, 400)),
		"a press outside it is swallowed")
	spotlight._body.visible_characters = -1
	spotlight._advance_by_tap()
	_expect(spotlight._index == 3, "a tap on the box does not count as a tap on the ship")
	for i in 14:
		spotlight._on_tap_paid({})
	_expect(spotlight._index == 3, "fourteen taps are not enough")
	spotlight._on_tap_paid({})
	_expect(spotlight._index == 4, "the fifteenth moves on")

	# He hops over to a bottom-screen target, and his bubble keeps off it.
	target[0] = Rect2(Vector2(80, 650), Vector2(120, 52))
	for i in 120:
		spotlight._process(0.016)
	_expect(not spotlight._bubble.get_global_rect().intersects(target[0].grow(4.0)),
		"the speech bubble keeps off a bottom-screen target")
	_expect(spotlight._walker.get_global_rect().get_center().distance_to(
		target[0].get_center()) < 140.0, "he stands next to what he talks about")

	spotlight._body.visible_characters = -1
	spotlight._advance_by_tap()
	_expect(spotlight._until() == "shop_open", "then he asks for the shop")
	shop_open[0] = true
	spotlight._process(0.016)
	_expect(spotlight._until() == "buy", "an open shop moves to the purchase")
	shop_open[0] = false
	spotlight._process(0.016)
	_expect(spotlight._until() == "shop_open", "closing the shop without buying points back at it")
	shop_open[0] = true
	spotlight._process(0.016)
	spotlight._on_purchase({})
	_expect(closed[0] == 1 and spotlight._until() == "journal_open",
		"a purchase closes the shop and moves on to the challenges key")
	spotlight._body.visible_characters = -1
	spotlight._advance_by_tap()
	_expect(spotlight._until() == "journal_open",
		"a tap on the veil does not skip the challenges key")
	journal_open[0] = true
	spotlight._process(0.016)
	_expect(spotlight._until() == "ok" and spotlight.STEPS[spotlight._index].id == "fim",
		"opening the challenges board moves on to the goodbye")
	spotlight._body.visible_characters = -1
	spotlight._advance_by_tap()
	# He runs off screen, and the tour ends when he is gone.
	for i in 200:
		if not spotlight.is_active():
			break
		spotlight._process(0.016)
	_expect(not spotlight.is_active(), "the tour completes after its last line")

	# A tip: no veil, one line, gone on a tap.
	_expect(spotlight.tip("land", "guide.tip.land", "shop"), "a tip starts after the tour")
	_expect(not spotlight._veil.visible, "a tip blocks nothing")
	_expect(not spotlight.tip("wheel", "guide.tip.wheel"), "one tip at a time")
	spotlight._body.visible_characters = -1
	spotlight._advance_by_tap()
	for i in 200:
		if not spotlight.tip_active():
			break
		spotlight._process(0.016)
	_expect(not spotlight.tip_active(), "a tap sends him off")
	viewport.queue_free()
	await get_tree().process_frame


func _viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	return viewport


func _inside(container: Rect2, item: Rect2) -> bool:
	return container.encloses(item)


func _expect(condition: bool, label: String) -> void:
	if not condition: failures.append(label)
