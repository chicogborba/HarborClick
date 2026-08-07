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
	test_offline_report_accounts_for_the_cap()
	test_offline_duration_reads_as_time()
	test_offline_lines_fit_the_board()
	test_prestige_quote_reads_as_a_decision()
	test_cps_breakdown_reproduces_the_rate()
	test_purchase_wait_reads_as_time()
	test_late_sections_and_seed()
	test_a_dead_provider_cannot_kill_the_save()
	test_v1_migration()
	test_corrupt_primary_recovers_backup()
	test_recovered_backup_offline_is_idempotent()
	test_future_version_falls_back()
	test_preferences_backup_recovers()
	test_prestige_nodes_all_change_something()
	test_retired_prestige_nodes_migrate()
	test_offline_tier_ignores_purchase_order()
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


func test_offline_report_accounts_for_the_cap() -> void:
	## The popup can only explain the absence if the credit path hands it the
	## account instead of a single total.
	SaveManager.wipe()
	var cap := GameState.OFFLINE_CAP_SECONDS_BASE
	var away := cap + 7200.0
	var envelope := _v2_envelope(0.0, {})
	envelope.saved_at_unix = Time.get_unix_time_from_system() - away
	envelope.core["owned"] = {"estivador": 1}
	_write(TEST_PATH, envelope)
	_expect(SaveManager.load_game(), "long-absence save loads")
	var report: Dictionary = SaveManager.offline_report
	_expect(not report.is_empty(), "a credited absence reports its account")
	_expect(absf(float(report.get("away_seconds", 0.0)) - away) <= 5.0,
		"the report keeps the whole absence, not the capped part")
	_expect(is_equal_approx(float(report.get("credited_seconds", 0.0)), cap),
		"only the capped seconds are paid")
	_expect(absf(float(report.get("capped_seconds", 0.0)) - 7200.0) <= 5.0,
		"the report names the seconds the cap refused")
	_expect(float(report.get("lost_to_cap", 0.0)) > 0.0,
		"the report prices what the cap refused")
	_expect(is_equal_approx(float(report.get("earnings", 0.0)),
			SaveManager.offline_earnings),
		"the report and the credited total agree")
	# A short absence has nothing to apologise for and must not claim a loss.
	SaveManager.wipe()
	var short_envelope := _v2_envelope(0.0, {})
	short_envelope.saved_at_unix = Time.get_unix_time_from_system() - 120.0
	short_envelope.core["owned"] = {"estivador": 1}
	_write(TEST_PATH, short_envelope)
	_expect(SaveManager.load_game(), "short-absence save loads")
	_expect(is_zero_approx(float(SaveManager.offline_report.get("capped_seconds", 0.0))),
		"an absence inside the cap reports no loss")


func test_offline_duration_reads_as_time() -> void:
	_expect(OfflinePopup.format_duration(0.0) == "0s", "zero reads as seconds")
	_expect(OfflinePopup.format_duration(90.0) == "1min", "minutes drop seconds")
	_expect(OfflinePopup.format_duration(3600.0) == "1h", "a whole hour has no minutes")
	_expect(OfflinePopup.format_duration(29100.0) == "8h05", "hours and minutes pad")


func test_offline_lines_fit_the_board() -> void:
	## The board has no autowrap on purpose, so a line that outgrows the panel
	## would be clipped instead of wrapped. Worst case: ten hours away and a rate
	## wide enough to need a suffix.
	var report := {"away_seconds": 36000.0, "credited_seconds": 28800.0,
		"capped_seconds": 7200.0, "cap_seconds": 28800.0, "efficiency": 0.5,
		"rate": 123.456e12, "earnings": 1.0, "lost_to_cap": 999.9e12}
	var lines: Array[String] = [OfflinePopup.greeting(report)]
	lines.append_array(OfflinePopup.breakdown_lines(report))
	_expect(lines.size() == 3, "a capped absence explains itself in three lines")
	for line in lines:
		_expect(line.length() <= OfflinePopup.MAX_LINE,
			"\"%s\" fits the board (%d chars)" % [line, line.length()])
	_expect(OfflinePopup.breakdown_lines({}).is_empty(),
		"no report means no breakdown")
	var inside := report.duplicate()
	inside["capped_seconds"] = 0.0
	_expect(OfflinePopup.breakdown_lines(inside).size() == 1,
		"an absence inside the cap shows no loss line")


func test_prestige_quote_reads_as_a_decision() -> void:
	## The quote line used to feed the per-structure `peak` dictionary to
	## `float()`, which raised every time the button was pressed — so `_quoted`
	## never flipped and the reset could not be confirmed from the dialog at all.
	GameState.from_save({"owned": {"estivador": 30, "empilhadeira": 10},
		"all_time_productive_teus": 4.0e10})
	GameState.recompute()
	var quote := GameState.get_prestige_quote()
	_expect(int(quote.get("gain", 0)) > 0, "the seeded port is worth a reset")
	_expect(PrestigeDialog.peak_units(quote.get("peak", {})) == 40,
		"the peak reads as a machine count, not a dictionary")
	_expect(quote.has("rebuild_seconds"), "the quote prices the rebuild in time")
	var seconds := float(quote.rebuild_seconds)
	_expect(seconds > 0.0, "a producing port has a finite rebuild estimate")
	_expect(PrestigeDialog.rebuild_line(seconds).contains(
			OfflinePopup.format_duration(seconds)),
		"the dialog line states the estimate as time")
	_expect(not PrestigeDialog.rebuild_line(-1.0).is_empty(),
		"a rebuild past the budget still says something")
	_expect(PrestigeDialog.peak_units("not a dictionary") == 0,
		"a malformed peak cannot crash the quote")


func test_cps_breakdown_reproduces_the_rate() -> void:
	## The panel is the formula, not a description of it: multiplying the factors
	## has to land back on the rate the counter is showing, or it is decoration.
	GameState.from_save({"owned": {"estivador": 25, "empilhadeira": 10},
		"upgrades": ["cafe_forte", "carrinho_mao", "colete_novo"],
		"purchased_tree_nodes": ["throughput_structural"],
		"prestige_level_earned": 9, "shares": 9})
	GameState.recompute()
	var rows := GameState.cps_breakdown()
	_expect(rows.size() >= 5, "the breakdown names every factor")
	_expect(String(rows[0].kind) == "base", "the first row is the machine rate")
	var product := 1.0
	for row in rows:
		product *= float(row.value)
	_expect(absf(product - GameState.base_cps) <= maxf(0.001, GameState.base_cps * 1e-9),
		"the factors multiply back to the port's own rate")
	var milestone := float(rows[1].value)
	var upgrades := float(rows[2].value)
	_expect(milestone > 1.0, "25 machines have crossed a milestone")
	_expect(upgrades > 1.0, "two fitted upgrades read as a multiplier above one")
	_expect(float(rows[3].value) > 1.0, "capital reads as a multiplier above one")
	# An empty port has no factors to lie about.
	GameState.from_save({})
	GameState.recompute()
	var empty := GameState.cps_breakdown()
	_expect(is_zero_approx(float(empty[0].value)), "an empty port produces nothing")
	for row in empty:
		if String(row.kind) == "mult":
			_expect(float(row.value) > 0.0, "no factor is zero on an empty port")


func test_purchase_wait_reads_as_time() -> void:
	_expect(ShopCard.wait_for(0.0, 10.0) == "0s", "nothing missing is no wait")
	_expect(ShopCard.wait_for(100.0, 0.0) == "muito",
		"a port that produces nothing cannot promise a time")
	_expect(ShopCard.wait_for(120.0, 1.0) == "120s"
			or ShopCard.wait_for(120.0, 1.0) == "2min",
		"two minutes read as a duration")
	_expect(ShopCard.wait_for(7200.0, 1.0) == "2h", "hours read as hours")


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


func test_a_dead_provider_cannot_kill_the_save() -> void:
	## Leaving the terminal for the title screen frees everything `PortWorld`
	## registered, and a `Callable` holds an object id rather than a reference.
	## Calling one of those aborted `build_envelope`, which returned the empty
	## Dictionary its signature promises, which made `save_game` fail on
	## `envelope.sections` — so every autosave from that moment on, and the save
	## on the way out of the app, wrote nothing at all and said nothing about it.
	SaveManager.wipe()
	var ghost := Node.new()
	add_child(ghost)
	SaveManager.register_section(&"ghost_section",
		Callable(self, "_section_snapshot"), Callable(self, "_section_restore"))
	SaveManager.register_section(&"live_section",
		Callable(self, "_section_snapshot"), Callable(self, "_section_restore"))
	_expect(SaveManager.save_game(&"test"), "a save with both providers alive")
	# Free the provider the way a scene change does, then save again.
	SaveManager.register_section(&"ghost_section",
		Callable(ghost, "queue_free"), Callable(self, "_section_restore"))
	ghost.free()
	var envelope := SaveManager.build_envelope()
	_expect(envelope.has("sections"), "a dead provider still builds an envelope")
	_expect(SaveManager.save_game(&"test"), "a dead provider still saves")
	_expect(envelope.sections.has("live_section"),
		"the live sections are still written")
	_expect(envelope.sections.has("ghost_section"),
		"the dead one keeps whatever it last wrote")
	SaveManager.unregister_section(&"live_section")
	_expect(SaveManager.build_envelope().sections.has("live_section"),
		"unregistering keeps the payload and only drops the provider")


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


func _tree_probe() -> Array[float]:
	## Every observable a prestige node is allowed to move. A node that changes
	## none of these is charging golden shares for nothing.
	return [GameState.cps, GameState.click_power,
		GameState.offline_efficiency(), GameState.offline_cap_seconds()]


func _seed_state_for_tree() -> void:
	## Multipliers are invisible against a zero base, so the port owns something.
	GameState.from_save({"owned": {"estivador": 10}})
	GameState.recompute()


func _buy_prerequisites(id: StringName) -> void:
	## `requires` is a graph, not a list: the deepest offline node depends on two
	## nodes that themselves depend on a third.
	for required in PrestigeDB.get_node(id).get("requires", []):
		var required_id := StringName(required)
		if GameState.purchased_tree_nodes.has(required_id):
			continue
		_buy_prerequisites(required_id)
		_expect(GameState.buy_prestige_node(required_id),
			"%s prerequisite %s is buyable" % [id, required_id])


func test_prestige_nodes_all_change_something() -> void:
	_expect(PrestigeDB.is_valid(), "prestige tree data is valid")
	var branches := PrestigeDB.purchasable_branches()
	_expect(not branches.is_empty(), "at least one branch is purchasable")
	for branch: Dictionary in branches:
		_expect(String(branch.get("requires_feature", "")).is_empty(),
			"%s is not feature gated" % branch.get("id", "?"))
		for gated: Dictionary in branch.get("nodes", []):
			_expect(String(gated.get("requires_feature", "")).is_empty(),
				"%s is not feature gated" % gated.get("id", "?"))
	for branch: Dictionary in branches:
		for node: Dictionary in branch.get("nodes", []):
			var id := StringName(node.get("id", ""))
			_seed_state_for_tree()
			GameState.shares = 999
			_buy_prerequisites(id)
			var before := _tree_probe()
			_expect(GameState.buy_prestige_node(id), "%s is buyable" % id)
			var after := _tree_probe()
			var moved := false
			for index in before.size():
				if not is_equal_approx(before[index], after[index]):
					moved = true
			_expect(moved, "%s changes a value the player can observe" % id)


func test_retired_prestige_nodes_migrate() -> void:
	## The first two versions of the offline branch sold the port's own defaults.
	## A save that bought them keeps the tier it paid for under the new ids.
	for legacy: String in PrestigeDB.LEGACY_NODE_IDS:
		var replacement := StringName(PrestigeDB.LEGACY_NODE_IDS[legacy])
		GameState.from_save({"purchased_tree_nodes": [legacy]})
		_expect(GameState.purchased_tree_nodes.has(replacement),
			"%s is restored as %s" % [legacy, replacement])
		_expect(not GameState.purchased_tree_nodes.has(StringName(legacy)),
			"%s does not survive as a dead id" % legacy)
	GameState.from_save({"purchased_tree_nodes": ["offline_50"]})
	_expect(GameState.offline_efficiency() > GameState.OFFLINE_EFFICIENCY_BASE,
		"a migrated offline node now beats the baseline")


func test_offline_tier_ignores_purchase_order() -> void:
	## The old lookup took the last matching node in dictionary order. It only
	## worked because `requires` happened to force an ascending sequence.
	GameState.from_save({"purchased_tree_nodes":
		["offline_cap_16h", "offline_cap_12h"]})
	_expect(is_equal_approx(GameState.offline_cap_seconds(), 57600.0),
		"the best owned cap wins regardless of insertion order")
	GameState.from_save({"purchased_tree_nodes": ["offline_eff_75", "offline_eff_60"]})
	_expect(is_equal_approx(GameState.offline_efficiency(), 0.75),
		"the best owned efficiency wins regardless of insertion order")


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
