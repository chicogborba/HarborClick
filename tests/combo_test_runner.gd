extends Node
## The tap combo: steady taps build a multiplier, a pause lets it fall, a skill
## can pin it, and a payout during it is multiplied and still paid exactly once.
## Run with: Godot --headless --path . res://tests/combo_test_runner.tscn

const EXPECTED := ["build", "decay", "window", "pin", "payout"]

var failures: Array[String] = []
var _done_tests: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_steady_taps_build_steps()
	_test_a_pause_lets_it_fall()
	_test_the_window_rewards_a_steady_hand_not_a_fast_one()
	_test_a_pin_holds_the_maximum()
	_test_a_payout_in_the_combo_is_multiplied_once()
	for name in EXPECTED:
		_expect(_done_tests.has(name), "test '%s' ran to its last line" % name)
	if failures.is_empty():
		print("COMBO TESTS PASSED (%d tests: %s)" % [EXPECTED.size(), ", ".join(EXPECTED)])
		get_tree().quit(0)
	else:
		for f in failures:
			push_error(f)
		print("COMBO TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_steady_taps_build_steps() -> void:
	var c := TapCombo.new()
	var t := 100.0
	var pings := 0
	for i in TapCombo.TAPS_PER_STEP * TapCombo.MAX_STEPS + 20:
		if c.note_tap(t):
			pings += 1
		t += 0.3
	_expect(c.steps(t - 0.3) == TapCombo.MAX_STEPS, "a long steady streak reaches the top step")
	_expect(is_equal_approx(c.multiplier(t - 0.3), 1.0 + TapCombo.STEP * TapCombo.MAX_STEPS),
		"which is x%.1f" % (1.0 + TapCombo.STEP * TapCombo.MAX_STEPS))
	_expect(pings == TapCombo.MAX_STEPS, "and pinged once per step (%d)" % pings)
	_done_tests.append("build")


func _test_a_pause_lets_it_fall() -> void:
	var c := TapCombo.new()
	var t := 10.0
	for i in 40:
		c.note_tap(t)
		t += 0.3
	_expect(c.is_active(t), "a streak is active while it is fed")
	_expect(not c.is_active(t + TapCombo.WINDOW + 0.5), "and gone after a pause")
	c.note_tap(t + 5.0)
	_expect(c.steps(t + 5.0) == 0, "the first tap after a pause starts from nothing")
	_done_tests.append("decay")


func _test_the_window_rewards_a_steady_hand_not_a_fast_one() -> void:
	var slow := TapCombo.new()
	var t := 0.0
	for i in 48:
		slow.note_tap(t)
		t += 1.2        # under the window: a relaxed pace keeps it
	_expect(slow.steps(t) >= 4, "one tap a little under every 1.4s still builds (%d)" % slow.steps(t))
	var gappy := TapCombo.new()
	t = 0.0
	for i in 48:
		gappy.note_tap(t)
		t += 1.6        # over the window: it never builds
	_expect(gappy.steps(t) == 0, "a pace slower than the window never does")
	_done_tests.append("window")


func _test_a_pin_holds_the_maximum() -> void:
	var c := TapCombo.new()
	c.pin(50.0, 10.0)
	_expect(c.is_maxed(55.0), "a pinned combo is at the top with no taps at all")
	_expect(not c.is_active(70.0), "and lets go when the pin ends")
	_done_tests.append("pin")


func _test_a_payout_in_the_combo_is_multiplied_once() -> void:
	GameState.from_save({})
	GameState.recompute()
	GameState.combo.reset()
	var base := GameState.click_power
	var t := GameState.combo_now()
	GameState.combo.pin(t, 30.0)
	var quote := GameState.make_manual_reward_quote("combo_test_tx")
	var crit := bool(quote.crit)
	var want := base * (1.0 + TapCombo.STEP * TapCombo.MAX_STEPS) * (GameState.CRIT_MULT if crit else 1.0)
	_expect(is_equal_approx(float(quote.value), want),
		"a tap at the top step pays x%.1f" % (1.0 + TapCombo.STEP * TapCombo.MAX_STEPS))
	var again := GameState.make_manual_reward_quote("combo_test_tx")
	GameState.combo.reset()
	_expect(is_equal_approx(float(again.value), float(quote.value)),
		"the quote for one transaction never changes when asked again")
	GameState.from_save({})
	_done_tests.append("payout")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
