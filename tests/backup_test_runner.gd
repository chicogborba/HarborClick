extends Node
## Manual save export/import contract.
## Run with:
## Godot --headless --path . res://tests/backup_test_runner.tscn
##
## A player moving between a browser and a phone, or clearing site data by
## accident, needs a save they can carry by hand. That is only worth having if
## a round trip reproduces the same state exactly and a bad paste cannot
## destroy the run that is already there.

const TEST_SAVE_PATH := "user://harborclick_backup_test.json"
const TEST_EXPORT_PATH := "user://harborclick_backup_test_export.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	GameState.from_save({})

	_test_round_trip_reproduces_the_same_state()
	_test_a_bad_paste_leaves_the_run_alone()
	_test_storage_probe_reports_a_writable_user_dir()

	SaveManager.wipe()
	if FileAccess.file_exists(TEST_EXPORT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_EXPORT_PATH))
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH), "cleanup removes the test save")

	if failures.is_empty():
		print("BACKUP TESTS PASSED (round trip, rejection, storage probe)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("BACKUP TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_round_trip_reproduces_the_same_state() -> void:
	GameState.teus = 123456.0
	GameState.lifetime_teus = 999999.0
	GameState.owned["estivador"] = 7
	GameState.upgrades["luvas"] = true
	GameState.recompute()
	var exported := SaveManager.export_text()
	_expect(SaveManager.export_to_file(TEST_EXPORT_PATH),
		"the export also lands on disk as a file the player can keep")

	# Wander far away, then come back through the exported text alone.
	GameState.teus = 1.0
	GameState.owned.clear()
	GameState.upgrades.clear()
	GameState.recompute()
	var result := SaveManager.import_text(exported)
	_expect(bool(result.get("ok", false)),
		"a save exported from the live run imports cleanly")
	_expect(is_equal_approx(GameState.teus, 123456.0),
		"the imported run has its currency back (%.1f)" % GameState.teus)
	_expect(GameState.structure_count("estivador") == 7,
		"the imported run has its structures back")
	_expect(GameState.has_upgrade("luvas"),
		"the imported run has its upgrades back")


func _test_a_bad_paste_leaves_the_run_alone() -> void:
	var before := GameState.teus
	for junk in ["", "não é json", "[1,2,3]", "{}",
			'{"save_version": 99, "core": {}, "time": {}, "sections": {}}',
			'{"save_version": 2, "core": "nope", "time": {}, "sections": {}}']:
		var result := SaveManager.import_text(junk)
		_expect(not bool(result.get("ok", true)),
			"import rejects %s" % ("empty text" if junk.is_empty() else junk.left(28)))
		_expect(not str(result.get("error", "")).is_empty(),
			"a rejected import says why")
	_expect(is_equal_approx(GameState.teus, before),
		"a rejected import does not touch the run in progress")
	_expect(FileAccess.file_exists(TEST_SAVE_PATH),
		"a rejected import leaves the save file on disk")


func _test_storage_probe_reports_a_writable_user_dir() -> void:
	_expect(SaveManager.probe_storage(),
		"the storage probe passes where user:// is writable")
	_expect(not FileAccess.file_exists(TEST_SAVE_PATH + ".probe"),
		"the storage probe cleans up after itself")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
