extends Node
## Builds: a paid purchase stands after a delay, the price already counts it, two
## work at a time, a tap hurries one, an ad finishes one, the time away counts,
## and the queue saves and is cleared by a rebuild.
## Run with: Godot --headless --path . res://tests/build_test_runner.tscn

const EXPECTED := ["durations", "off", "queue", "price", "slots", "hurry", "offline",
	"save", "prestige"]

var failures: Array[String] = []
var _done_tests: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests("user://harborclick_build_test.json")
	SaveManager.wipe()
	_test_durations()
	_test_disabled_means_instant()
	_test_a_purchase_is_built()
	_test_the_price_counts_what_is_still_going_up()
	_test_two_work_at_a_time()
	_test_a_tap_hurries_and_an_ad_finishes()
	_test_time_away_counts()
	_test_the_queue_saves()
	_test_a_rebuild_clears_the_works()
	for name in EXPECTED:
		_expect(_done_tests.has(name), "test '%s' ran to its last line" % name)
	GameState.build_times_enabled = false
	GameState.from_save({})
	SaveManager.wipe()
	if failures.is_empty():
		print("BUILD TESTS PASSED (%d tests: %s)" % [EXPECTED.size(), ", ".join(EXPECTED)])
		get_tree().quit(0)
	else:
		for f in failures:
			push_error(f)
		print("BUILD TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _fresh(teus: float = 1e9) -> void:
	GameState.from_save({"teus": teus, "lifetime": teus, "all_time_teus": teus})
	GameState.build_times_enabled = true
	GameState.recompute()


func _test_durations() -> void:
	_expect(BuildQueue.duration("estivador", 0, 1) == 3.0, "the first docker takes 3 s")
	_expect(BuildQueue.duration("estivador", 4, 1) == 0.0, "the fifth is instant")
	_expect(BuildQueue.duration("rtg", 0, 1) == 30.0, "a first RTG takes 30 s")
	_expect(BuildQueue.duration("rtg", 3, 10) == 5.0 * 10.0, "ten more take 5 s each")
	_expect(BuildQueue.duration("portal", 0, 100) == BuildQueue.MAX_SECONDS,
		"nothing takes more than five minutes")
	_expect(BuildQueue.duration("ghost", 0, 1) == 0.0, "an unknown machine is instant")
	_done_tests.append("durations")


func _test_disabled_means_instant() -> void:
	_fresh()
	GameState.build_times_enabled = false
	GameState.buy_structure_bulk("estivador")
	_expect(GameState.structure_count("estivador") == 1 and GameState.builds.is_empty(),
		"with build times off a purchase stands at once")
	_done_tests.append("off")


func _test_a_purchase_is_built() -> void:
	_fresh()
	var teus_before := GameState.teus
	var done := [0]
	var cb := func(_id: String, _q: int) -> void: done[0] += 1
	EventBus.build_completed.connect(cb)
	GameState.buy_structure_bulk("estivador")
	_expect(GameState.structure_count("estivador") == 0, "it is not owned yet")
	_expect(GameState.pending_count("estivador") == 1, "it is on the works")
	_expect(GameState.teus < teus_before, "but it is paid for")
	_expect(is_zero_approx(GameState.base_cps), "and earns nothing until it stands")
	GameState._process(2.0)
	_expect(GameState.structure_count("estivador") == 0, "2 s in, still going up")
	GameState._process(1.5)
	_expect(GameState.structure_count("estivador") == 1 and GameState.builds.is_empty(),
		"after its 3 s it is owned and the queue is empty")
	_expect(GameState.base_cps > 0.0, "and it earns")
	_expect(done[0] == 1, "completion was announced once")
	EventBus.build_completed.disconnect(cb)
	_done_tests.append("queue")


func _test_the_price_counts_what_is_still_going_up() -> void:
	_fresh()
	var first := float(GameState.structure_purchase_quote("rtg_or_x").get("total_cost", 0.0))
	GameState.land["patio_sul"] = true
	var q1 := GameState.structure_purchase_quote("tt")
	GameState.buy_structure_bulk("tt")
	var q2 := GameState.structure_purchase_quote("tt")
	_expect(float(q2.total_cost) > float(q1.total_cost),
		"the second lorry costs more while the first is still being built")
	_expect(first == first, "(sanity)")
	_done_tests.append("price")


func _test_two_work_at_a_time() -> void:
	_fresh()
	GameState.land["patio_norte"] = true
	GameState.buy_structure_bulk("tt")
	GameState.buy_structure_bulk("tt")
	GameState.buy_structure_bulk("reach_stacker")
	_expect(GameState.builds.size() == 3, "three purchases are queued")
	var third_before := float(GameState.builds[2].left)
	GameState._process(1.0)
	_expect(is_equal_approx(float(GameState.builds[2].left), third_before),
		"the third waits its turn while two work")
	GameState._process(1.5)
	_expect(GameState.builds.size() == 2 and str(GameState.builds[1].id) == "reach_stacker",
		"and takes the freed slot when one finishes")
	_done_tests.append("slots")


func _test_a_tap_hurries_and_an_ad_finishes() -> void:
	_fresh()
	GameState.buy_structure_bulk("estivador")
	var before := float(GameState.builds[0].left)
	GameState.tap_build(0, 1.0)
	_expect(is_equal_approx(float(GameState.builds[0].left), before - 1.0),
		"a tap takes a second off")
	GameState.tap_build(5, 1.0)
	_expect(true, "tapping a site that is not there is harmless")
	GameState.finish_build(0)
	GameState._process(0.01)
	_expect(GameState.builds.is_empty() and GameState.structure_count("estivador") == 1,
		"finishing a build (the ad) stands it at the next tick")
	_done_tests.append("hurry")


func _test_time_away_counts() -> void:
	_fresh()
	GameState.land["patio_norte"] = true
	GameState.buy_structure_bulk("reach_stacker")
	GameState.buy_structure_bulk("reach_stacker")
	GameState.buy_structure_bulk("reach_stacker")
	GameState.advance_builds(60.0)
	_expect(GameState.structure_count("reach_stacker") == 3 and GameState.builds.is_empty(),
		"a minute away finishes three small builds, queued in turn")
	_done_tests.append("offline")


func _test_the_queue_saves() -> void:
	_fresh()
	GameState.buy_structure_bulk("estivador")
	var saved := GameState.to_save()
	GameState.from_save(saved)
	_expect(GameState.builds.size() == 1 and GameState.pending_count("estivador") == 1,
		"a build in progress survives a save and load")
	GameState.from_save({"builds": [{"id": "ghost", "qty": 3}, 5, {"id": "estivador", "qty": -2},
		{"id": "estivador", "qty": 2, "left": 1.0e300, "total": 4.0}]})
	_expect(GameState.builds.size() == 1 and float(GameState.builds[0].left) <= BuildQueue.MAX_SECONDS,
		"garbage entries are dropped and a huge clock is clamped")
	_done_tests.append("save")


func _test_a_rebuild_clears_the_works() -> void:
	_fresh(1e12)
	GameState.buy_structure_bulk("estivador")
	GameState.all_time_productive_teus = 1e12
	GameState.do_prestige()
	_expect(GameState.builds.is_empty(), "a rebuild takes the works with it")
	_done_tests.append("prestige")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
