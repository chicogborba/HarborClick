extends Node
## The Capataz's skills: recharge clocks, what each one does, and that none of
## them can be used early, twice, or while the terminal has not earned it.
## Run with: Godot --headless --path . res://tests/skills_test_runner.tscn

const EXPECTED := ["cooldown", "restore", "overtime", "mutirao", "pilot", "gate", "reset"]

var failures: Array[String] = []
var _done_tests: Array[String] = []
var _service: SkillService


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests("user://harborclick_skills_test.json")
	SaveManager.wipe()
	GameState.from_save({})
	_service = SkillService.new()
	add_child(_service)
	_test_the_recharge_clock()
	_test_restore_is_tolerant_and_clamped()
	_test_overtime_multiplies_with_a_surge()
	await _test_mutirao_pins_the_combo_and_taps()
	_test_the_pilot_promise_is_spent_once()
	_test_a_skill_the_terminal_has_not_earned_does_nothing()
	_test_an_ad_reset_makes_it_ready()
	for name in EXPECTED:
		_expect(_done_tests.has(name), "test '%s' ran to its last line" % name)
	_service.queue_free()
	await get_tree().process_frame
	SaveManager.wipe()
	if failures.is_empty():
		print("SKILLS TESTS PASSED (%d tests: %s)" % [EXPECTED.size(), ", ".join(EXPECTED)])
		get_tree().quit(0)
	else:
		for f in failures:
			push_error(f)
		print("SKILLS TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_the_recharge_clock() -> void:
	var b := SkillBook.new()
	_expect(b.is_ready(&"skill_overtime", 1000.0), "a new book is ready")
	_expect(b.use(&"skill_overtime", 1000.0), "a ready skill can be used")
	_expect(not b.use(&"skill_overtime", 1100.0), "but not again while it recharges")
	_expect(is_equal_approx(b.seconds_left(&"skill_overtime", 1100.0), 200.0),
		"300 s recharge, 100 s in: 200 s left")
	_expect(is_equal_approx(b.fraction_left(&"skill_overtime", 1150.0), 0.5),
		"half way through, the curtain is half down")
	_expect(b.use(&"skill_overtime", 1300.0), "and it is ready again when the clock says so")
	_expect(not b.use(&"nonsense", 0.0), "an unknown skill is refused")
	_done_tests.append("cooldown")


func _test_restore_is_tolerant_and_clamped() -> void:
	var b := SkillBook.new()
	var far := Time.get_unix_time_from_system() + 100.0
	b.use(&"skill_pilot", far)
	var c := SkillBook.new()
	c.restore(b.snapshot())
	_expect(not c.is_ready(&"skill_pilot", far + 1.0), "a recharge survives a save round trip")
	var d := SkillBook.new()
	d.restore({"ready_at": {"skill_pilot": 9.9e15, "ghost": 5, "skill_overtime": "x"}})
	var now := Time.get_unix_time_from_system()
	_expect(d.seconds_left(&"skill_pilot", now) <= 480.0 + 1.0,
		"a clock set far into the future locks a skill for at most one recharge")
	_expect(d.is_ready(&"skill_overtime", now), "garbage reads as ready")
	d.restore({"ready_at": 7})
	_expect(d.ready_at.is_empty(), "a non-dictionary reads as ready")
	_done_tests.append("restore")


func _test_overtime_multiplies_with_a_surge() -> void:
	GameState.from_save({"owned": {"estivador": 40}, "teus": 1e6})
	GameState.recompute()
	var base := GameState.cps
	GameState.grant_surge(3.0, 20.0)
	_service.book.reset(&"skill_overtime")
	_expect(_service.activate(&"skill_overtime"), "Turno Extra activates")
	_expect(is_equal_approx(GameState.cps, base * 6.0), "x2 on top of a x3 surge is x6")
	_expect(not _service.activate(&"skill_overtime"), "and it cannot be pressed twice")
	GameState.from_save({})
	GameState.recompute()
	_done_tests.append("overtime")


func _test_mutirao_pins_the_combo_and_taps() -> void:
	var taps := [0]
	_service.tap_ship = func() -> void: taps[0] += 1
	_service.book.reset(&"skill_mutirao")
	GameState.combo.reset()
	_expect(_service.activate(&"skill_mutirao"), "Mutirão activates")
	_expect(GameState.combo.is_maxed(GameState.combo_now()), "the combo is at the top at once")
	for i in 20:
		_service._process(0.1)
	_expect(taps[0] == 20, "ten taps a second for two seconds is twenty (%d)" % taps[0])
	for i in 100:
		_service._process(0.1)
	# Float steps of 0.1 s may land one tap either side of ten seconds' worth.
	_expect(absi(taps[0] - 100) <= 1, "and ten seconds of it in all (%d)" % taps[0])
	_expect(not _service.mutirao_active(), "then the crew stops")
	GameState.combo.reset()
	await get_tree().process_frame
	_done_tests.append("mutirao")


func _test_the_pilot_promise_is_spent_once() -> void:
	GameState.pilot_pending = 1.0
	_service.book.reset(&"skill_pilot")
	_expect(_service.activate(&"skill_pilot"), "the pilot comes aboard")
	_expect(is_equal_approx(GameState.take_pilot(), 3.0), "the next departure bonus is x3")
	_expect(is_equal_approx(GameState.take_pilot(), 1.0), "and the one after is plain")
	_done_tests.append("pilot")


func _test_a_skill_the_terminal_has_not_earned_does_nothing() -> void:
	var rules := TerminalLevel.new()
	FeatureGate.bind(rules)
	_service.book.reset(&"skill_pilot")
	_expect(not _service.unlocked(&"skill_pilot"), "a level-1 terminal has no pilot skill")
	_expect(not _service.activate(&"skill_pilot"), "and pressing it does nothing")
	_expect(_service.book.is_ready(&"skill_pilot", Time.get_unix_time_from_system()),
		"without starting a recharge")
	rules.add_xp(TerminalLevel.xp_for_level(8))
	_expect(_service.unlocked(&"skill_pilot"), "level 8 earns it")
	FeatureGate.unbind(rules)
	_done_tests.append("gate")


func _test_an_ad_reset_makes_it_ready() -> void:
	_service.book.reset(&"skill_overtime")
	_service.activate(&"skill_overtime")
	_expect(not _service.book.is_ready(&"skill_overtime", Time.get_unix_time_from_system()),
		"recharging after use")
	_service.reset_cooldown(&"skill_overtime")
	_expect(_service.book.is_ready(&"skill_overtime", Time.get_unix_time_from_system()),
		"a skipped wait leaves it ready")
	GameState.from_save({})
	_done_tests.append("reset")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
