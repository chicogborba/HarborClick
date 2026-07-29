extends Node
## Run with: Godot --headless --path . res://tests/phase4_ship_test_runner.tscn

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	test_catalogue_and_deterministic_rotation()
	test_ship_snapshot_restores_variant()
	test_visual_variants_do_not_change_berth_capacity()
	test_wake_tracks_motion_phase()
	if failures.is_empty():
		print("PHASE 4 SHIP TESTS PASSED")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func test_catalogue_and_deterministic_rotation() -> void:
	_expect(ShipCatalog.is_valid() and ShipCatalog.SILHOUETTES.size() >= 3 and ShipCatalog.PALETTES.size() >= 4,
		"ship catalogue declares at least three silhouettes and four palettes")
	var first_history: Array[String] = []
	var second_history: Array[String] = []
	for call_index in 18:
		var first := ShipCatalog.select_variant(444, call_index, first_history)
		var second := ShipCatalog.select_variant(444, call_index, second_history)
		_expect(first == second, "variant selection is deterministic for call %d" % call_index)
		first_history.append(str(first.id))
		second_history.append(str(second.id))
		if first_history.size() >= 3:
			var end := first_history.size()
			_expect(not (first_history[end - 1] == first_history[end - 2] and first_history[end - 2] == first_history[end - 3]),
				"same variant cannot repeat for more than two scales")


func test_ship_snapshot_restores_variant() -> void:
	var ship := Ship.new()
	get_tree().root.add_child(ship)
	ship.select_variant(919, 0)
	ship.select_variant(919, 1)
	var saved := ship.snapshot()
	var restored := Ship.new()
	get_tree().root.add_child(restored)
	restored.restore(saved)
	_expect(restored.variant_id() == ship.variant_id(), "ship snapshot restores the selected variant")
	_expect(restored.variant_history == ship.variant_history, "ship snapshot restores variant history")
	_expect(restored.operational_capacity() == ship.operational_capacity() and restored.operational_capacity() > 0,
		"restored vessel keeps declared informational capacity")
	ship.free()
	restored.free()


func test_visual_variants_do_not_change_berth_capacity() -> void:
	_expect(Ship.COLS * Ship.ROWS == 24, "visual catalogue cannot alter the 24-transfer berth contract")
	for silhouette in ShipCatalog.SILHOUETTES:
		_expect(int(silhouette.capacity) > 0, "each silhouette declares an informational vessel capacity")


func test_wake_tracks_motion_phase() -> void:
	var ship := Ship.new()
	get_tree().root.add_child(ship)
	_expect(not ship._wake.visible and not ship._wake.is_playing(),
		"wake is stopped while the ship is away")
	ship._set_phase(Ship.Phase.ARRIVING)
	_expect(ship._wake.visible and ship._wake.is_playing() and ship._wake.speed_scale < 1.0,
		"arrival creates a restrained moving wake")
	ship._set_phase(Ship.Phase.DISCHARGING)
	_expect(not ship._wake.visible and not ship._wake.is_playing(),
		"wake stops while the ship is moored")
	ship._set_phase(Ship.Phase.DEPARTING)
	_expect(ship._wake.visible and ship._wake.is_playing() and ship._wake.speed_scale == 1.0,
		"departure creates the faster moving wake")
	ship.free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
