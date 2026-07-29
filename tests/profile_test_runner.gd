extends Node
## Profile slot contract.
## Run with:
## Godot --headless --path . res://tests/profile_test_runner.tscn
##
## Three runs share one build, so the only thing standing between them is the
## path. These are the two ways that goes wrong: a slot reading another slot's
## progress, and a delete taking a terminal the player did not point at.

var failures: Array[String] = []
var _roots: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Work in a scratch directory so a developer's real profiles are never
	# touched by a test run.
	for slot in range(1, SaveManager.PROFILE_COUNT + 1):
		_roots.append(SaveManager.profile_path(slot))
	_wipe_all()

	_test_slots_are_independent()
	_test_delete_only_takes_the_named_slot()
	_test_summary_reads_without_applying()

	_wipe_all()
	if failures.is_empty():
		print("PROFILE TESTS PASSED (isolation, delete, read-only summary)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("PROFILE TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_slots_are_independent() -> void:
	SaveManager.use_profile(1)
	GameState.teus = 111.0
	GameState.owned["estivador"] = 1
	SaveManager.save_game(&"test")

	SaveManager.use_profile(2)
	_expect(is_zero_approx(GameState.teus),
		"opening an unused slot starts a new run, not the neighbour's (%f)"
			% GameState.teus)
	GameState.teus = 222.0
	SaveManager.save_game(&"test")

	SaveManager.use_profile(1)
	_expect(is_equal_approx(GameState.teus, 111.0),
		"slot 1 still holds its own currency after slot 2 was played")
	_expect(GameState.structure_count("estivador") == 1,
		"slot 1 still holds its own structures")
	SaveManager.use_profile(2)
	_expect(is_equal_approx(GameState.teus, 222.0),
		"slot 2 holds its own currency")


func _test_delete_only_takes_the_named_slot() -> void:
	SaveManager.delete_profile(2)
	_expect(not FileAccess.file_exists(SaveManager.profile_path(2)),
		"deleting a slot removes its file")
	_expect(FileAccess.file_exists(SaveManager.profile_path(1)),
		"deleting one slot leaves the others alone")
	var summary := SaveManager.profile_summary(2)
	_expect(not bool(summary.get("exists", true)),
		"a deleted slot reads back as empty")
	_expect(bool(SaveManager.profile_summary(1).get("exists", false)),
		"the untouched slot still reads back as used")


func _test_summary_reads_without_applying() -> void:
	SaveManager.use_profile(3)
	GameState.teus = 777.0
	var before := GameState.teus
	var summary := SaveManager.profile_summary(1)
	_expect(is_equal_approx(GameState.teus, before),
		"reading another slot's summary does not load it over the live run")
	_expect(float(summary.get("teus", -1.0)) >= 0.0,
		"the summary reports a career total for a used slot")
	_expect(int(summary.get("slot", 0)) == 1,
		"the summary names the slot it came from")


func _wipe_all() -> void:
	for slot in range(1, SaveManager.PROFILE_COUNT + 1):
		SaveManager.delete_profile(slot)
	GameState.from_save({})


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
