extends SceneTree
## Run with: Godot --headless --path . --script res://tests/phase3_progression_test_runner.gd

var failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	test_catalogues_are_exact_and_valid()
	test_retroactive_restore_is_idempotent()
	test_snapshot_schema_and_restore()
	test_pin_and_domain_statistics()
	test_contract_determinism_frozen_reward_and_single_active()
	test_paused_time_and_events_do_not_advance_contract()
	test_ship_album_records_and_claims_once()
	test_fleet_album_records_by_name_and_keeps_old_saves()
	if failures.is_empty():
		print("PHASE 3 PROGRESSION TESTS PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func test_catalogues_are_exact_and_valid() -> void:
	_expect(AchievementDB.ITEMS.size() == 38 and AchievementDB.is_valid(), "achievement catalogue is the exact valid 38-entry blueprint")
	_expect(AchievementDB.get_item(&"event_golden_ship").get("requires_feature", "") == "golden_ship", "golden ship achievement is feature gated")
	_expect(AchievementDB.get_item(&"route_first").get("requires_feature", "") == "routes", "route achievement is feature gated")
	_expect(AchievementDB.get_item(&"collection_1").get("requires_feature", "") == "collection", "collection achievement is feature gated")
	_expect(ContractDB.is_valid(), "six contract templates use the required stats and timings")
	_expect(PrestigeDB.is_valid(), "prestige tree has valid effects and feature-gated branches")
	_expect(PrestigeDB.get_node(&"routes_reward").get("requires_feature", "") == "routes", "route prestige node is feature gated")


func test_retroactive_restore_is_idempotent() -> void:
	var manager := ProgressionManager.new()
	var unlock_count := [0]
	manager.achievement_unlocked.connect(func(_id: StringName, _item: Dictionary) -> void: unlock_count[0] += 1)
	var legacy := {"stats": {"teus_earned": 100.0}, "achievements": {}}
	manager.restore(legacy)
	_expect(manager.unlocked.has(&"teu_100"), "retroactive restore unlocks matching achievement")
	_expect(unlock_count[0] == 1, "retroactive restore emits first reward once")
	manager.restore(legacy)
	_expect(unlock_count[0] == 1, "same retroactive restore never grants duplicate reward")
	_expect(manager.snapshot().retroactive_evaluated_version == ProgressionManager.RETROACTIVE_EVALUATED_VERSION, "restore marks retroactive evaluation version")
	manager.free()


func test_snapshot_schema_and_restore() -> void:
	var original := ProgressionManager.new()
	original.set_career_seed(921)
	original.set_buy_mode(&"ten")
	original.ingest_event(&"container_moved", {"count": 25, "sector": "import"})
	original.ingest_event(&"container_moved", {"count": 3, "sector": "export"})
	original.ingest_event(&"tutorial_completed", {"skipped": false})
	_expect(original.pin_objective(&"cargo_moves_1000"), "known objective can be pinned")
	_expect(original.start_contract(921, 0, {"projected_rate": 2.0}), "contract starts from deterministic materialization")
	var saved := original.snapshot()
	for required in ["schema_version", "career_seed", "stats", "achievements", "pinned_objective", "tutorial", "contracts", "ui", "retroactive_evaluated_version"]:
		_expect(saved.has(required), "snapshot contains %s" % required)
	_expect(saved.pinned_objective == {"kind": "achievement", "id": "cargo_moves_1000"}, "snapshot stores typed pin")
	var loaded := ProgressionManager.new()
	loaded.restore(saved)
	_expect(is_equal_approx(float(loaded.stats.get(&"imports_moved", 0.0)), 25.0) and is_equal_approx(float(loaded.stats.get(&"exports_moved", 0.0)), 3.0), "snapshot restores sector statistics")
	_expect(loaded.pinned_objective == &"cargo_moves_1000" and loaded.ui.buy_mode == "ten", "snapshot restores pin and UI buy mode")
	_expect(loaded.career_seed == 921 and bool(loaded.tutorial.completed), "snapshot restores career seed and tutorial")
	_expect(loaded.get_active_contract().get("id", "") == original.get_active_contract().get("id", ""), "snapshot restores canonical active contract")
	original.free()
	loaded.free()


func test_pin_and_domain_statistics() -> void:
	var manager := ProgressionManager.new()
	_expect(not manager.pin_objective(&"not_real"), "unknown objective cannot be pinned")
	_expect(manager.pin_objective(&"cargo_import_100"), "achievement objective can be pinned")
	manager.ingest_event(&"container_moved", {"count": 100, "sector": "import"})
	manager.ingest_event(&"container_moved", {"count": 100, "sector": "export"})
	manager.ingest_event(&"perfect_call")
	manager.ingest_event(&"ship_served")
	manager.ingest_event(&"prestiged")
	manager.ingest_event(&"tutorial_completed", {"skipped": false})
	_expect(manager.start_contract(31, 0), "contract starts for completed-contract statistic")
	manager.ingest_event(&"container_moved", {"count": 100})
	_expect(float(manager.stats.get(&"imports_moved", 0.0)) == 100.0 and float(manager.stats.get(&"exports_moved", 0.0)) == 100.0, "event ingestion distinguishes imports and exports")
	_expect(float(manager.stats.get(&"perfect_calls", 0.0)) == 1.0 and float(manager.stats.get(&"ships_served", 0.0)) == 1.0, "event ingestion records perfect calls and served scales")
	_expect(float(manager.stats.get(&"prestige_count", 0.0)) == 1.0 and float(manager.stats.get(&"tutorial_unskipped", 0.0)) == 1.0 and float(manager.stats.get(&"contracts_completed", 0.0)) == 1.0, "event ingestion records prestige, unskipped tutorial and completed contracts")
	_expect(bool(manager.get_pinned_objective().get("complete", false)), "pinned objective exposes completion")
	manager.free()


func test_contract_determinism_frozen_reward_and_single_active() -> void:
	var context := {"projected_rate": 0.2, "measured_transfer_rate": 0.4}
	var first := ContractDB.materialize(77, 4, context)
	var second := ContractDB.materialize(77, 4, context)
	_expect(first == second, "same seed, offer index and context materialize the same contract")
	_expect(float(first.reward.amount) >= 30.0 and bool(first.reward.frozen) and float(first.active_duration) in [300.0, 480.0, 600.0], "contract reward is frozen TEU minimum with active duration")
	var manager := ProgressionManager.new()
	_expect(manager.accept_contract(first), "first canonical contract is accepted")
	_expect(not manager.accept_contract(ContractDB.materialize(78, 1)), "only one contract may be active")
	manager.free()


func test_paused_time_and_events_do_not_advance_contract() -> void:
	var manager := ProgressionManager.new()
	_expect(manager.start_contract(5, 0), "container contract starts")
	manager.set_session_active(false)
	_expect(is_zero_approx(manager.advance_active_time(90.0)), "paused session reports no active time")
	manager.ingest_event(&"container_moved", {"count": 100})
	_expect(is_zero_approx(float(manager.get_active_contract().get("progress", 0.0))) and is_zero_approx(float(manager.get_active_contract().get("active_elapsed", 0.0))), "paused session cannot progress contract from events or time")
	manager.set_session_active(true)
	manager.advance_active_time(1.0, false)
	manager.ingest_event(&"container_moved", {"count": 1})
	_expect(float(manager.get_active_contract().get("progress", 0.0)) == 1.0 and is_zero_approx(float(manager.get_active_contract().get("active_elapsed", 0.0))), "active event progresses but background time does not")
	manager.advance_active_time(5.0)
	_expect(float(manager.get_active_contract().get("active_elapsed", 0.0)) == 5.0, "active time advances contract duration")
	manager.free()


func test_ship_album_records_and_claims_once() -> void:
	## C7: every arriving hull×livery is recorded, a silhouette page completes at
	# one chip per livery, and the prize claims exactly once across a reload.
	var manager := ProgressionManager.new()
	var total := 4 # ShipCatalog.PALETTES.size(), passed in to keep this suite standalone
	for i in total:
		manager.record_ship_variant({"silhouette_id": "panamax",
			"palette_id": "palette_%d" % i})
	_expect(manager.album.size() == total, "four liveries of one hull are four album keys")
	manager.record_ship_variant({"silhouette_id": "panamax", "palette_id": "palette_0"})
	_expect(manager.album.size() == total, "a repeat arrival does not double-record")
	var page := manager.album_page("panamax", total)
	_expect(bool(page.complete) and not bool(page.claimed), "the page is complete and unclaimed")
	_expect(manager.claim_album_page("panamax", total), "the page claims")
	_expect(not manager.claim_album_page("panamax", total), "the page never claims twice")
	_expect(manager.album_page("panamax", total).claimed, "claimed survives the page read")
	var saved := manager.snapshot()
	var loaded := ProgressionManager.new()
	loaded.restore(saved)
	_expect(loaded.album.size() == total, "the album survives a snapshot round trip")
	_expect(loaded.album_claimed.has("panamax"), "the claim survives a snapshot round trip")
	_expect(not loaded.claim_album_page("panamax", total), "a reloaded page still never claims twice")
	loaded.free()
	manager.free()


func test_fleet_album_records_by_name_and_keeps_old_saves() -> void:
	## A named ship is recorded by its fleet id and announced once; a ship the
	# old album already held under its "class:palette" key is recorded but not
	# announced again; milestone prizes claim once and only when reached.
	var manager := ProgressionManager.new()
	var announced: Array[String] = []
	manager.album_ship_added.connect(func(id: String) -> void: announced.append(id))
	manager.album["panamax:harbor_blue"] = true
	manager.record_ship_variant({"fleet_id": "atlantico_azul",
		"legacy": "panamax:harbor_blue", "silhouette_id": "panamax"})
	manager.record_ship_variant({"fleet_id": "nordlys", "silhouette_id": "coastal_feeder"})
	manager.record_ship_variant({"fleet_id": "nordlys", "silhouette_id": "coastal_feeder"})
	_expect(manager.album.has("atlantico_azul") and manager.album.has("nordlys"),
		"named ships are recorded by fleet id")
	_expect(announced == ["nordlys"],
		"only a ship the album had never seen is announced, once (%s)" % [announced])
	_expect(not manager.claim_album_milestone(10, 9), "a milestone not reached does not claim")
	_expect(manager.claim_album_milestone(10, 10), "a reached milestone claims")
	_expect(not manager.claim_album_milestone(10, 12), "and never twice")
	var loaded := ProgressionManager.new()
	loaded.restore(manager.snapshot())
	_expect(loaded.album_milestone_claimed(10) and loaded.album.has("nordlys"),
		"the album and its prizes survive a reload")
	loaded.free()
	manager.free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
