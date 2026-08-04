extends Node
## Run with: Godot --headless --path . res://tests/phase3_progression_ui_test_runner.tscn

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_safe_area_and_journal_close()
	await _test_pin_and_objective_contract()
	await _test_prestige_requires_explicit_confirmation()
	await _test_spotlight_seven_steps_and_safe_target()
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
	var chip := ObjectiveChip.new()
	chip.setup(null, {"get_objective": func() -> Dictionary: return {"title":"Movimente carga", "progress":4.0, "target":10.0, "pinned":true}})
	viewport.add_child(chip)
	await get_tree().process_frame
	_expect(chip._title.text.begins_with("FIXADA:"), "objective chip labels a pinned objective")
	_expect(chip._progress.text == "4 / 10", "objective chip renders pinned progress")
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
	# instead of running off the side of the dialog.
	_expect(dialog._tree.get_child_count()
			== PrestigeDB.BRANCHES.size() + PrestigeDB.all_nodes().size(),
		"prestige dialog renders every capital branch and node as its own row")
	viewport.queue_free()
	await get_tree().process_frame


func _test_spotlight_seven_steps_and_safe_target() -> void:
	var viewport := _viewport(Vector2i(360, 800))
	var target := [Rect2(Vector2(24, 80), Vector2(90, 40))]
	var spotlight := TutorialSpotlight.new()
	spotlight.setup({"get_target_rect": func(_key: String) -> Rect2: return target[0], "reduced_motion": func() -> bool: return true})
	viewport.add_child(spotlight)
	await get_tree().process_frame
	var safe := Rect2(Vector2(10, 24), Vector2(340, 740))
	spotlight.apply_view_metrics({"safe_rect": safe})
	spotlight.start()
	_expect(spotlight.STEPS.size() == 7, "spotlight has seven data-driven orientation steps")
	_expect(spotlight._veil.mouse_filter == Control.MOUSE_FILTER_IGNORE, "spotlight veil does not block the highlighted target")
	_expect(_inside(safe, spotlight._panel.get_global_rect()), "spotlight instruction panel stays inside safe area")
	_expect(spotlight._panel.size.y <= 120.0,
		"spotlight instruction panel remains compact instead of covering the port")
	target[0] = Rect2(Vector2(80, 650), Vector2(120, 52))
	spotlight._show_step()
	_expect(not spotlight._panel.get_global_rect().intersects(target[0].grow(8.0)),
		"spotlight instruction panel moves away from a bottom-screen target")
	for _step in 7: spotlight.next()
	_expect(not spotlight.is_active(), "spotlight completes after its seventh step")
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
