extends Node
## Laytime: a call's clock is sized from its work, an overstay costs a share of
## what that ship earned (never into debt), and an early sailing pays more.
## Run with: Godot --headless --path . res://tests/deadline_test_runner.tscn

const EXPECTED := ["laytime", "fine", "early", "clock"]

var failures: Array[String] = []
var _done_tests: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_laytime_is_sized_from_the_work()
	_test_the_fine_is_a_share_of_the_ship()
	_test_early_sailing_pays_more()
	_test_the_clock_reads()
	for name in EXPECTED:
		_expect(_done_tests.has(name), "test '%s' ran to its last line" % name)
	if failures.is_empty():
		print("DEADLINE TESTS PASSED (%d tests: %s)" % [EXPECTED.size(), ", ".join(EXPECTED)])
		get_tree().quit(0)
	else:
		for f in failures:
			push_error(f)
		print("DEADLINE TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_laytime_is_sized_from_the_work() -> void:
	var empty_port := BerthDeadline.laytime(48, 0.0)
	var busy_port := BerthDeadline.laytime(48, 3.0)
	_expect(empty_port > busy_port, "a port with machines gets a shorter clock")
	_expect(empty_port <= BerthDeadline.MAX_SECONDS and busy_port >= BerthDeadline.MIN_SECONDS,
		"the clock stays inside its bounds")
	# A player tapping at the easy pace on an empty port beats it with slack.
	var needed := 48.0 / BerthDeadline.TAP_PACE
	_expect(empty_port >= minf(needed, BerthDeadline.MAX_SECONDS) * 0.99,
		"the easy pace finishes inside the clock")
	_done("laytime")


func _test_the_fine_is_a_share_of_the_ship() -> void:
	_expect(is_equal_approx(BerthDeadline.fine(1000.0), 150.0), "15% of what the ship earned")
	_expect(BerthDeadline.fine(-5.0) == 0.0, "never negative")
	var saved := GameState.teus
	GameState.teus = 40.0
	var taken := GameState.apply_fine(BerthDeadline.fine(1000.0))
	_expect(is_equal_approx(taken, 40.0) and GameState.teus == 0.0,
		"the wallet pays what it has and never goes into debt")
	GameState.teus = saved
	_done("fine")


func _test_early_sailing_pays_more() -> void:
	_expect(BerthDeadline.early_multiplier(0.0, 100.0) == 1.0, "on the wire pays the base")
	_expect(is_equal_approx(BerthDeadline.early_multiplier(50.0, 100.0), 1.5), "half the clock left: x1.5")
	_expect(is_equal_approx(BerthDeadline.early_multiplier(100.0, 100.0),
		1.0 + BerthDeadline.EARLY_MAX), "the whole clock left: the maximum")
	_expect(BerthDeadline.early_multiplier(10.0, 0.0) == 1.0, "no clock, no bonus")
	_done("early")


func _test_the_clock_reads() -> void:
	_expect(BerthDeadline.clock_text(125.2) == "2:06", "minutes and seconds, rounded up")
	_expect(BerthDeadline.clock_text(-3.0) == "0:00", "never negative")
	_done("clock")


func _done(name: String) -> void:
	_done_tests.append(name)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
