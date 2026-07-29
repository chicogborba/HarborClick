extends Node
## Run with: Godot --headless --path . res://tests/core_test_runner.tscn

var failures: Array[String] = []
const TEST_PATH := "user://harborclick_core_test.json"
const PREFERENCES_TEST_PATH := "user://harborclick_preferences_test.cfg"
var save_events: Array[Dictionary] = []
var recovered_sources: Array[StringName] = []
var section_restored: Dictionary = {}
var section_seed_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	EventBus.save_finished.connect(_on_save_finished)
	EventBus.save_recovered.connect(_on_save_recovered)
	SaveManager.set_save_path_for_tests(TEST_PATH)
	SaveManager.wipe()
	test_v2_format()
	test_manual_reward_is_idempotent()
	test_milestone_normalization()
	test_offline_credit_is_idempotent()
	test_late_sections_and_seed()
	test_v1_migration()
	test_corrupt_primary_recovers_backup()
	test_recovered_backup_offline_is_idempotent()
	test_future_version_falls_back()
	test_preferences_backup_recovers()
	test_wipe_removes_everything()
	if failures.is_empty():
		print("CORE TESTS PASSED")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func test_v2_format() -> void:
	SaveManager.wipe()
	save_events.clear()
	GameState.teus = 42.0
	GameState.run_teus = 42.0
	GameState.all_time_teus = 42.0
	GameState.lifetime_teus = 42.0
	_expect(SaveManager.save_game(&"format"), "v2 save writes")
	var data := _read(TEST_PATH)
	_expect(int(data.get("save_version", 0)) == 2, "v2 has save_version")
	_expect(data.has("saved_at_unix") and data.core is Dictionary and data.time is Dictionary and data.sections is Dictionary, "v2 envelope has required sections")
	_expect(not save_events.is_empty() and save_events.back().ok and save_events.back().reason == &"format", "save_finished emits success and reason")


func test_manual_reward_is_idempotent() -> void:
	GameState.from_save({})
	var quote := GameState.make_manual_reward_quote("test:manual:1")
	var before := GameState.teus
	var first := GameState.commit_manual_reward("test:manual:1", quote)
	var after_first := GameState.teus
	var second := GameState.commit_manual_reward("test:manual:1", {"value": 999.0, "crit": true})
	_expect(first is bool and second is bool and first and second, "manual commit has bool success contract")
	_expect(is_equal_approx(after_first - before, float(quote.value)), "first manual commit pays quote")
	_expect(is_equal_approx(GameState.teus, after_first), "duplicate manual commit does not pay twice")


func test_milestone_normalization() -> void:
	GameState.from_save({"flags": {"milestones": [0.0, "one_million", 0, "invalid"]}})
	var seen: Array = GameState.flags.get("milestones", [])
	_expect(seen == ["first_100", "one_million"], "legacy milestone indexes normalize to ids")


func test_offline_credit_is_idempotent() -> void:
	SaveManager.wipe()
	var envelope := _v2_envelope(0.0, {})
	envelope.saved_at_unix = Time.get_unix_time_from_system() - 120.0
	envelope.core["owned"] = {"estivador": 1}
	_write(TEST_PATH, envelope)
	_expect(SaveManager.load_game(), "offline source save loads")
	var after_first := GameState.teus
	_expect(after_first > 0.0, "offline interval credits productive earnings")
	_expect(SaveManager.load_game(), "offline-credit checkpoint reloads")
	_expect(is_equal_approx(GameState.teus, after_first),
		"reload during offline popup cannot credit the same interval twice")


func test_late_sections_and_seed() -> void:
	SaveManager.wipe()
	section_seed_calls = 0
	SaveManager.register_section(&"core_test_seed", Callable(self, "_section_snapshot"), Callable(self, "_section_restore"), Callable(self, "_section_seed"))
	_expect(section_seed_calls == 1, "new game section seed runs on registration")
	_write(TEST_PATH, {
		"save_version": 2, "saved_at_unix": 0.0, "core": {}, "time": {},
		"sections": {"core_test_late": {"token": "restored"}},
	})
	_expect(SaveManager.load_game(), "v2 load for late section succeeds")
	section_restored = {}
	SaveManager.register_section(&"core_test_late", Callable(self, "_section_snapshot"), Callable(self, "_section_restore"))
	_expect(section_restored.get("token", "") == "restored", "late section registration restores loaded payload")


func test_v1_migration() -> void:
	SaveManager.wipe()
	_write(TEST_PATH, {"teus": 7.0, "lifetime": 11.0, "day": 3, "time_of_day": 0.5, "yard": [{"id": "c"}]})
	_expect(SaveManager.load_game(), "v1 load succeeds")
	_expect(is_equal_approx(GameState.teus, 7.0) and is_equal_approx(GameState.all_time_teus, 11.0), "v1 core migrates totals")
	_expect(TimeManager.day == 3 and SaveManager.pending_yard().size() == 1, "v1 time and section migrate")
	section_seed_calls = 0
	SaveManager.register_section(&"v1_missing_section", Callable(self, "_section_snapshot"), Callable(self, "_section_restore"), Callable(self, "_section_seed"))
	_expect(section_seed_calls == 1, "v1 missing section runs seed on late registration")


func test_corrupt_primary_recovers_backup() -> void:
	SaveManager.wipe()
	var backup_envelope := _v2_envelope(10.0, {
		"recovered_late_section": {"token": "from_backup"},
	})
	_write(TEST_PATH + ".bak", backup_envelope)
	var backup_before := _read_text(TEST_PATH + ".bak")
	_write(TEST_PATH, "{ definitely not json")
	GameState.from_save({})
	recovered_sources.clear()
	_expect(SaveManager.load_game(), "backup recovery succeeds")
	_expect(is_equal_approx(GameState.teus, 10.0), "backup content is restored after corrupt primary")
	_expect(recovered_sources.has(&"backup"), "save recovery signal uses source contract")
	_expect(_read_text(TEST_PATH + ".bak") == backup_before and not _read(TEST_PATH + ".bak").is_empty(), "valid backup remains untouched after recovery")
	var promoted := _read(TEST_PATH)
	_expect(promoted.get("sections", {}).get("recovered_late_section", {}).get("token", "") == "from_backup", "promoted primary preserves unregistered sections")
	section_restored = {}
	SaveManager.register_section(&"recovered_late_section", Callable(self, "_section_snapshot"), Callable(self, "_section_restore"))
	_expect(section_restored.get("token", "") == "from_backup", "recovered section restores on late registration")


func test_recovered_backup_offline_is_idempotent() -> void:
	SaveManager.wipe()
	var backup_envelope := _v2_envelope(5.0, {
		"offline_recovery_section": {"kept": true},
	})
	backup_envelope.saved_at_unix = Time.get_unix_time_from_system() - 120.0
	backup_envelope.core["owned"] = {"estivador": 1}
	_write(TEST_PATH + ".bak", backup_envelope)
	_write(TEST_PATH, "{ corrupt primary before offline recovery")
	_expect(SaveManager.load_game(), "productive backup recovery succeeds")
	var after_recovery := GameState.teus
	_expect(after_recovery > 5.0, "recovered productive backup credits offline earnings once")
	_expect(not _read(TEST_PATH + ".bak").is_empty(),
		"offline recovery leaves a valid backup")
	_expect(_read(TEST_PATH).get("sections", {}).get(
		"offline_recovery_section", {}).get("kept", false),
		"offline checkpoint preserves recovered late sections")
	_expect(SaveManager.load_game(), "offline recovery checkpoint reloads")
	_expect(is_equal_approx(GameState.teus, after_recovery),
		"recovered backup cannot credit the same offline interval twice")


func test_future_version_falls_back() -> void:
	SaveManager.wipe()
	var backup_envelope := _v2_envelope(33.0, {"future_fallback_section": {"kept": true}})
	_write(TEST_PATH + ".bak", backup_envelope)
	_write(TEST_PATH, {
		"save_version": SaveManager.SAVE_VERSION + 1,
		"saved_at_unix": 0.0,
		"core": {"teus": 999.0, "lifetime": 999.0},
		"time": {},
		"sections": {},
	})
	recovered_sources.clear()
	_expect(SaveManager.load_game(), "future primary falls back to current-version backup")
	_expect(is_equal_approx(GameState.teus, 33.0), "future save version is not applied")
	_expect(recovered_sources.has(&"backup"), "future-version fallback reports backup recovery")
	_expect(int(_read(TEST_PATH).get("save_version", 0)) == SaveManager.SAVE_VERSION, "fallback promotes supported envelope to primary")


func test_preferences_backup_recovers() -> void:
	UserPreferences.set_config_path_for_tests(PREFERENCES_TEST_PATH)
	for path in [PREFERENCES_TEST_PATH, PREFERENCES_TEST_PATH + ".tmp",
			PREFERENCES_TEST_PATH + ".bak",
			PREFERENCES_TEST_PATH + ".recovery"]:
		_remove_if_exists(path)
	var backup := ConfigFile.new()
	backup.set_value("preferences", "reduce_motion", true)
	backup.set_value("preferences", "floating_numbers", false)
	backup.set_value("preferences", "ui_scale", 1.15)
	backup.set_value("preferences", "fullscreen", true)
	_expect(backup.save(PREFERENCES_TEST_PATH + ".bak") == OK,
		"preferences crash-state backup writes")
	UserPreferences.reduce_motion = false
	UserPreferences.floating_numbers = true
	UserPreferences.ui_scale = 1.0
	UserPreferences.fullscreen = false
	UserPreferences.load_preferences()
	_expect(UserPreferences.reduce_motion and not UserPreferences.floating_numbers \
			and is_equal_approx(UserPreferences.ui_scale, 1.15) \
			and UserPreferences.fullscreen,
		"preferences recover values from backup when live file is absent")
	_expect(FileAccess.file_exists(PREFERENCES_TEST_PATH),
		"recovered preferences are promoted to the live path")
	_expect(_config_is_valid(PREFERENCES_TEST_PATH + ".bak"),
		"preferences promotion preserves the known-good backup")

	for path in [PREFERENCES_TEST_PATH, PREFERENCES_TEST_PATH + ".tmp",
			PREFERENCES_TEST_PATH + ".bak",
			PREFERENCES_TEST_PATH + ".recovery"]:
		_remove_if_exists(path)
	_write(PREFERENCES_TEST_PATH, "{ corrupt preferences")
	var interrupted_tmp := ConfigFile.new()
	interrupted_tmp.set_value("preferences", "reduce_motion", false)
	interrupted_tmp.set_value("preferences", "floating_numbers", true)
	interrupted_tmp.set_value("preferences", "ui_scale", 0.9)
	interrupted_tmp.set_value("preferences", "fullscreen", false)
	_expect(interrupted_tmp.save(PREFERENCES_TEST_PATH + ".tmp") == OK,
		"preferences interrupted temporary file writes")
	UserPreferences.load_preferences()
	_expect(not UserPreferences.reduce_motion and UserPreferences.floating_numbers \
			and is_equal_approx(UserPreferences.ui_scale, 0.9) \
			and not UserPreferences.fullscreen,
		"preferences recover a valid temporary file after a corrupt live file")
	_expect(_config_is_valid(PREFERENCES_TEST_PATH) \
			and not FileAccess.file_exists(PREFERENCES_TEST_PATH + ".recovery"),
		"temporary preference recovery promotes live and discards corruption")
	for path in [PREFERENCES_TEST_PATH, PREFERENCES_TEST_PATH + ".tmp",
			PREFERENCES_TEST_PATH + ".bak",
			PREFERENCES_TEST_PATH + ".recovery"]:
		_remove_if_exists(path)


func test_wipe_removes_everything() -> void:
	GameState.boost_time = 12.0
	TimeManager.fog_active = true
	TimeManager.speed_mult = 40.0
	SaveManager.wipe()
	_expect(not FileAccess.file_exists(TEST_PATH), "wipe removes primary")
	_expect(not FileAccess.file_exists(TEST_PATH + ".tmp"), "wipe removes temporary")
	_expect(not FileAccess.file_exists(TEST_PATH + ".bak"), "wipe removes backup")
	_expect(is_equal_approx(GameState.teus, 0.0) and TimeManager.day == 1,
		"wipe resets core and time")
	_expect(is_zero_approx(GameState.boost_time) and not TimeManager.fog_active \
			and is_equal_approx(TimeManager.speed_mult, 1.0),
		"wipe clears boost, weather and debug session speed")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _on_save_finished(ok: bool, reason: StringName) -> void:
	save_events.append({"ok": ok, "reason": reason})


func _on_save_recovered(source: StringName) -> void:
	recovered_sources.append(source)


func _section_snapshot() -> Dictionary:
	return {"snapshot": true}


func _section_restore(data: Dictionary) -> void:
	section_restored = data.duplicate(true)


func _section_seed() -> void:
	section_seed_calls += 1


func _v2_envelope(teus_value: float, sections: Dictionary) -> Dictionary:
	return {
		"save_version": SaveManager.SAVE_VERSION,
		"saved_at_unix": 0.0,
		"core": {"teus": teus_value, "lifetime": teus_value},
		"time": {},
		"sections": sections,
	}


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _write(path: String, content: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content if content is String else JSON.stringify(content))
	file.close()


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _config_is_valid(path: String) -> bool:
	var config := ConfigFile.new()
	return config.load(path) == OK and UserPreferences._config_is_usable(config)
