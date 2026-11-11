extends Node
## AdService, AdPolicy and the provider seam: caps, cooldowns, the local-day
## rollover, persistence, and the reward contract (exactly once on success,
## nothing on failure, no double show, no_ads_pass skips the provider but
## respects the caps).
## Run with:
## Godot --headless --path . res://tests/ads_test_runner.tscn
##
## The roll call, and the reason there is one.
##
## A GDScript runtime error does not raise: it prints, aborts the function it
## happened in, and hands control back to the caller as if that function had
## returned. A suite that only counts *assertions it was given* therefore
## reports a test that died on its first line as a pass. Every test below names
## itself as its *last* statement; a test that aborts never gets there, and the
## roll call at the end turns its absence into a failure with the test's own
## name on it.

const TEST_SAVE_PATH := "user://harborclick_ads_test.json"

const EXPECTED := [
	"placements_table", "daily_cap", "cooldown", "day_rollover", "unlimited",
	"unknown_placement", "reward_once", "failure_pays_nothing",
	"no_double_show", "no_ads_pass", "cap_blocks_service",
	"snapshot_roundtrip", "garbage_restore", "seed_new", "save_section",
]

var failures: Array[String] = []
var _finished: Dictionary = {}
## Member arrays, not locals: a lambda reads them through `self` at call time,
## so reassigning between tests is safe (a captured local int would not be).
var _rewards: Array = []
var _granted: Array = []
var _availability: Array = [0]


## A provider that answers immediately (success or failure) or holds the
## finish until `release_last` is called, so a second show can be attempted
## while one is still on screen.
class FakeProvider extends AdProvider:
	var auto_reward := true
	var hold := false
	var calls: Array[StringName] = []
	var _held: Array[StringName] = []

	func show_rewarded(placement: StringName) -> void:
		calls.append(placement)
		if hold:
			_held.append(placement)
			return
		finished.emit(placement, auto_reward)

	func release_last(rewarded: bool = true) -> void:
		if _held.is_empty():
			return
		finished.emit(_held.pop_front(), rewarded)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	GameState.from_save({})
	seed(90210)
	AdService.reward_granted.connect(func(_p: StringName) -> void: _granted.append(_p))
	AdService.availability_changed.connect(func() -> void: _availability[0] += 1)

	_test_placements_table()
	_test_daily_cap()
	_test_cooldown()
	_test_day_rollover()
	_test_unlimited()
	_test_unknown_placement()
	_test_reward_once()
	_test_failure_pays_nothing()
	_test_no_double_show()
	_test_no_ads_pass()
	_test_cap_blocks_service()
	_test_snapshot_roundtrip()
	_test_garbage_restore()
	_test_seed_new()
	_test_save_section()

	for label in EXPECTED:
		_expect(_finished.has(label), "the '%s' test ran to the end" % label)

	await get_tree().process_frame
	SaveManager._sections.clear()
	SaveManager.wipe()
	if failures.is_empty():
		print("ADS TESTS PASSED (%d tests: placements table, daily cap, cooldown, "
			% EXPECTED.size()
			+ "day rollover, unlimited, unknown placement, reward-once, failure, "
			+ "no double show, no-ads pass, service cap, snapshot, garbage, seed, "
			+ "save section)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("ADS TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _done(label: String) -> void:
	## The last statement of every test. See `EXPECTED`.
	_finished[label] = true


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _reset_service() -> void:
	## The autoload AdService, back to a fresh day with no ad on screen.
	AdService._showing = false
	AdService._pending_placement = &""
	AdService._pending_reward = Callable()
	AdService.policy.restore(AdPolicy.seed_new(AdService._current_day()))
	AdService.policy.no_ads_pass = false
	_rewards = [0]
	_granted = []
	_availability = [0]


# ------------------------------------------------------------------ the rules

func _test_placements_table() -> void:
	var expected := {
		&"wheel_spin": [5, 600.0],
		&"wheel_double": [0, 0.0],
		&"minigame_retry": [0, 0.0],
		&"minigame_play": [3, 0.0],
		&"build_speed": [0, 30.0],
		&"offline_double": [0, 0.0],
		&"gull_double": [0, 0.0],
		&"mission_reroll": [1, 0.0],
		&"boost_2x": [6, 0.0],
	}
	_expect(AdPolicy.PLACEMENTS.size() == expected.size(),
		"nine placements are declared (%d)" % AdPolicy.PLACEMENTS.size())
	for id in expected.keys():
		_expect(AdPolicy.PLACEMENTS.has(id), "placement %s exists" % String(id))
		var rule: Dictionary = AdPolicy.PLACEMENTS.get(id, {})
		_expect(int(rule.get("daily_cap", -1)) == int(expected[id][0])
			and is_equal_approx(float(rule.get("cooldown", -1.0)), float(expected[id][1])),
			"placement %s is %d/day with %.0fs cooldown"
			% [String(id), int(expected[id][0]), float(expected[id][1])])
	_done("placements_table")


func _test_daily_cap() -> void:
	var p := AdPolicy.new()
	p.restore(AdPolicy.seed_new(100))
	_expect(p.can_show(&"wheel_spin", 1000.0, 100), "the first show of the day is allowed")
	_expect(p.remaining_today(&"wheel_spin", 100) == 5, "five left before any show")
	for i in 5:
		p.note_shown(&"wheel_spin", 1000.0 + 700.0 * i, 100)
	_expect(p.remaining_today(&"wheel_spin", 100) == 0, "none left at the cap")
	_expect(not p.can_show(&"wheel_spin", 4500.0, 100), "the sixth show is refused")
	_done("daily_cap")


func _test_cooldown() -> void:
	var p := AdPolicy.new()
	p.restore(AdPolicy.seed_new(50))
	_expect(p.can_show(&"build_speed", 1000.0, 50), "the first build_speed show is allowed")
	p.note_shown(&"build_speed", 1000.0, 50)
	_expect(not p.can_show(&"build_speed", 1029.0, 50), "inside the 30s cooldown")
	_expect(is_equal_approx(p.seconds_until(&"build_speed", 1029.0, 50), 1.0),
		"one second left at t=1029")
	_expect(p.can_show(&"build_speed", 1030.0, 50), "the cooldown ends exactly at 30s")
	_expect(is_zero_approx(p.seconds_until(&"build_speed", 2000.0, 50)), "nothing to wait later")
	_expect(p.remaining_today(&"build_speed", 50) == -1, "build_speed has no daily cap")
	_done("cooldown")


func _test_day_rollover() -> void:
	var p := AdPolicy.new()
	p.restore(AdPolicy.seed_new(100))
	for i in 5:
		p.note_shown(&"wheel_spin", 1000.0 + 700.0 * i, 100)
	_expect(not p.can_show(&"wheel_spin", 4500.0, 100), "capped on day 100")
	_expect(p.can_show(&"wheel_spin", 4500.0, 101), "the next local day resets the cap")
	_expect(p.remaining_today(&"wheel_spin", 101) == 5, "all five shows are back")
	# The cooldown clock is wall-clock, so it survives the midnight rollover.
	var q := AdPolicy.new()
	q.restore(AdPolicy.seed_new(100))
	q.note_shown(&"build_speed", 1000.0, 100)
	_expect(not q.can_show(&"build_speed", 1010.0, 101), "a cooldown spans midnight")
	_expect(q.can_show(&"build_speed", 1030.0, 101), "and ends on the new day")
	_done("day_rollover")


func _test_unlimited() -> void:
	var p := AdPolicy.new()
	p.restore(AdPolicy.seed_new(7))
	for i in 50:
		p.note_shown(&"wheel_double", 1000.0, 7)
	_expect(p.can_show(&"wheel_double", 1000.0, 7), "an unlimited placement never caps out")
	_expect(p.remaining_today(&"wheel_double", 7) == -1, "reported as -1 (unlimited)")
	_expect(is_zero_approx(p.seconds_until(&"wheel_double", 1000.0, 7)), "and has no cooldown")
	_done("unlimited")


func _test_unknown_placement() -> void:
	var p := AdPolicy.new()
	p.restore(AdPolicy.seed_new(5))
	_expect(not p.can_show(&"nope", 1000.0, 5), "an unknown placement may never show")
	_expect(p.remaining_today(&"nope", 5) == 0, "and has nothing left")
	_expect(is_zero_approx(p.seconds_until(&"nope", 1000.0, 5)), "and no cooldown")
	p.note_shown(&"nope", 1000.0, 5)
	_expect(not p.can_show(&"nope", 1000.0, 5), "not even after a note")
	_reset_service()
	_expect(not AdService.available(&"nope"), "the service refuses it too")
	_expect(not AdService.show_rewarded(&"nope", func(): _rewards[0] += 1),
		"and show_rewarded returns false")
	_expect(_rewards[0] == 0, "paying nothing")
	_done("unknown_placement")


# ------------------------------------------------------------------ the service

func _test_reward_once() -> void:
	_reset_service()
	var fake := FakeProvider.new()
	AdService.set_provider(fake)
	_expect(AdService.available(&"wheel_spin"), "wheel_spin is available on a fresh day")
	var ok := AdService.show_rewarded(&"wheel_spin", func(): _rewards[0] += 1)
	_expect(ok, "show_rewarded accepts")
	_expect(fake.calls == [&"wheel_spin"],
		"the provider was asked exactly once (%s)" % str(fake.calls))
	_expect(_rewards[0] == 1, "the reward callback ran exactly once")
	_expect(_granted.size() == 1 and _granted[0] == &"wheel_spin",
		"reward_granted fired once for the placement")
	_expect(_availability[0] >= 1, "availability_changed fired")
	_expect(AdService.remaining_today(&"wheel_spin") == 4, "the show spent one of the five")
	_expect(not AdService._showing, "the service is idle after the finish")
	var wait := AdService.seconds_until(&"wheel_spin")
	_expect(wait > 590.0 and wait <= 600.0, "the 10-minute cooldown counts down (%.1f)" % wait)
	_expect(not AdService.available(&"wheel_spin"), "and blocks a second show")
	_expect(not AdService.show_rewarded(&"wheel_spin", func(): _rewards[0] += 1),
		"show_rewarded refuses on cooldown")
	_expect(_rewards[0] == 1, "and pays nothing extra")
	_done("reward_once")


func _test_failure_pays_nothing() -> void:
	_reset_service()
	var fake := FakeProvider.new()
	fake.auto_reward = false
	AdService.set_provider(fake)
	_expect(AdService.show_rewarded(&"minigame_play", func(): _rewards[0] += 1),
		"the show starts")
	_expect(fake.calls.size() == 1, "the provider was asked")
	_expect(_rewards[0] == 0, "a failed ad pays nothing")
	_expect(_granted.is_empty(), "and emits no reward_granted")
	_expect(AdService.remaining_today(&"minigame_play") == 3,
		"and does not spend the daily cap")
	_expect(AdService.available(&"minigame_play"), "so the placement is still available")
	_expect(not AdService._showing, "the service is idle again")
	_done("failure_pays_nothing")


func _test_no_double_show() -> void:
	_reset_service()
	var fake := FakeProvider.new()
	fake.hold = true
	AdService.set_provider(fake)
	_expect(AdService.show_rewarded(&"gull_double", func(): _rewards[0] += 1),
		"the first show starts")
	_expect(AdService._showing, "one ad is on screen")
	_expect(not AdService.show_rewarded(&"gull_double", func(): _rewards[0] += 1),
		"a second show while one runs refuses")
	_expect(fake.calls.size() == 1, "the provider was asked only once")
	fake.release_last(true)
	_expect(_rewards[0] == 1, "the held ad pays exactly once when it finishes")
	_expect(_granted.size() == 1, "with exactly one reward_granted")
	_expect(not AdService._showing, "idle again")
	_done("no_double_show")


func _test_no_ads_pass() -> void:
	_reset_service()
	var fake := FakeProvider.new()
	AdService.set_provider(fake)
	AdService.policy.no_ads_pass = true
	_expect(AdService.available(&"minigame_play"), "available before any show")
	_expect(AdService.show_rewarded(&"minigame_play", func(): _rewards[0] += 1),
		"show_rewarded accepts with the pass")
	_expect(fake.calls.is_empty(), "the provider is skipped entirely")
	_expect(_rewards[0] == 1, "the reward is paid directly")
	_expect(_granted.size() == 1, "with one reward_granted")
	_expect(AdService.remaining_today(&"minigame_play") == 2, "and the show still counts")
	# The caps still bind with the pass: three minigame_play shows is the day.
	var now := Time.get_unix_time_from_system()
	var day := AdService._current_day()
	AdService.policy.note_shown(&"minigame_play", now, day)
	AdService.policy.note_shown(&"minigame_play", now, day)
	_expect(AdService.remaining_today(&"minigame_play") == 0, "the cap is reached")
	_expect(not AdService.available(&"minigame_play"), "caps still apply with no_ads_pass")
	_expect(not AdService.show_rewarded(&"minigame_play", func(): _rewards[0] += 1),
		"show refuses at the cap even with the pass")
	_expect(_rewards[0] == 1, "and pays nothing past the cap")
	_done("no_ads_pass")


func _test_cap_blocks_service() -> void:
	_reset_service()
	AdService.set_provider(FakeProvider.new())
	var now := Time.get_unix_time_from_system()
	var day := AdService._current_day()
	for i in 5:
		AdService.policy.note_shown(&"wheel_spin", now, day)
	_expect(AdService.remaining_today(&"wheel_spin") == 0, "the daily cap is spent")
	_expect(not AdService.available(&"wheel_spin"), "not available at the cap")
	_expect(not AdService.show_rewarded(&"wheel_spin", func(): _rewards[0] += 1),
		"show_rewarded refuses at the cap")
	_expect(_rewards[0] == 0, "and pays nothing")
	_done("cap_blocks_service")


# -------------------------------------------------------------- persistence

func _test_snapshot_roundtrip() -> void:
	var p := AdPolicy.new()
	p.restore(AdPolicy.seed_new(100))
	p.note_shown(&"wheel_spin", 1000.0, 100)
	p.note_shown(&"wheel_spin", 1700.0, 100)
	p.note_shown(&"build_speed", 1200.0, 100)
	p.no_ads_pass = true
	var q := AdPolicy.new()
	q.restore(p.snapshot())
	_expect(q.day == 100 and q.no_ads_pass, "the day and the pass flag survive")
	_expect(q.remaining_today(&"wheel_spin", 100) == 3, "the daily counts survive")
	_expect(is_equal_approx(q.seconds_until(&"build_speed", 1210.0, 100), 20.0),
		"the cooldown clock survives")
	_expect(not q.can_show(&"wheel_spin", 2000.0, 100), "the cap state survives")
	_done("snapshot_roundtrip")


func _test_garbage_restore() -> void:
	var p := AdPolicy.new()
	p.restore({"day": "banana", "no_ads_pass": 1, "state": {
		"wheel_spin": {"count": "x", "last_unix": {}},
		"ghost": {"count": 5},
		"build_speed": {"count": 0, "last_unix": 5.0e15},
		"boost_2x": "nope",
	}})
	_expect(p.day == 0, "a garbage day reads as zero")
	_expect(p.no_ads_pass, "a truthy pass flag survives")
	_expect(p.remaining_today(&"wheel_spin", 0) == 5, "a garbage count reads as zero shows")
	_expect(is_zero_approx(p.seconds_until(&"wheel_spin", 100.0, 0)),
		"a garbage clock reads as never shown")
	_expect(p.can_show(&"build_speed", 100.0, 0),
		"a future timestamp is clamped, not parked on cooldown")
	_expect(p.remaining_today(&"boost_2x", 0) == 6, "a non-dictionary entry reads as fresh")
	p.restore({"state": {"boost_2x": {"count": 99, "last_unix": -5.0}}})
	_expect(p.remaining_today(&"boost_2x", 0) == 0, "a count above the cap clamps to the cap")
	_expect(is_zero_approx(p.seconds_until(&"boost_2x", 100.0, 0)),
		"a negative clock is clamped to never")
	_expect(not p._state.has(&"ghost"), "unknown placements are dropped")
	p.restore({"state": 42})
	_expect(p.remaining_today(&"wheel_spin", 0) == 5, "a non-dictionary state is ignored")
	p.restore({})
	_expect(p.day == 0 and p.remaining_today(&"wheel_spin", 0) == 5,
		"an empty save is a valid save")
	_done("garbage_restore")


func _test_seed_new() -> void:
	var p := AdPolicy.new()
	p.restore(AdPolicy.seed_new(4242))
	_expect(p.day == 4242, "the seed day is kept")
	_expect(not p.no_ads_pass, "a new profile has no pass")
	_expect(p.remaining_today(&"wheel_spin", 4242) == 5, "and every cap is full")
	_expect(p.can_show(&"wheel_spin", 0.0, 4242), "and the first show is allowed")
	_done("seed_new")


func _test_save_section() -> void:
	_reset_service()
	_expect(SaveManager._sections.has(&"ads"), "the ads section is registered")
	var now := Time.get_unix_time_from_system()
	var day := AdService._current_day()
	AdService.policy.note_shown(&"mission_reroll", now, day)
	AdService.policy.no_ads_pass = true
	_expect(SaveManager.save_game(&"test"), "the save writes")
	var envelope := SaveManager.build_envelope()
	_expect(envelope.sections.has(&"ads"), "the ads section is in the envelope")
	var ads: Dictionary = envelope.sections[&"ads"]
	_expect(int(ads.state.mission_reroll.count) == 1, "the show is persisted")
	_expect(bool(ads.no_ads_pass), "the pass flag is persisted")
	var q := AdPolicy.new()
	q.restore(ads)
	_expect(q.remaining_today(&"mission_reroll", day) == 0,
		"the spent cap survives the round trip")
	_done("save_section")
