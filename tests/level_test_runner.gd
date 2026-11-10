extends Node
## Nível do Terminal: the XP curve, the unlock table, and the service that
## feeds the rules from the EventBus and persists them.
## Run with:
## Godot --headless --path . res://tests/level_test_runner.tscn
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

const TEST_SAVE_PATH := "user://harborclick_level_test.json"

const EXPECTED := [
	"curve_monotonic", "minute_table", "unlock_table", "add_xp_multi_level",
	"snapshot_roundtrip", "garbage_restore", "service_counts_events",
	"legacy_migration", "survives_prestige",
]

## The assumed active-player rate the curve is documented against:
## ~40 transfers/min plus one ship every 90 s.
const ASSUMED_TRANSFERS_PER_MIN := 40.0
const ASSUMED_SHIP_SECONDS := 90.0
const ASSUMED_XP_PER_MIN := ASSUMED_TRANSFERS_PER_MIN \
	+ float(TerminalLevel.XP_PER_SHIP_DEPARTED) * 60.0 / ASSUMED_SHIP_SECONDS

var failures: Array[String] = []
var _finished: Dictionary = {}
var _service: TerminalLevelService


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	GameState.from_save({})
	seed(90210)

	_test_curve_monotonic()
	_test_minute_table()
	_test_unlock_table()
	_test_add_xp_multi_level()
	_test_snapshot_roundtrip()
	_test_garbage_restore()
	_test_service_counts_events()
	_test_legacy_migration()
	_test_survives_prestige()

	for label in EXPECTED:
		_expect(_finished.has(label), "the '%s' test ran to the end" % label)

	if _service != null:
		_service.queue_free()
		_service = null
		await get_tree().process_frame
	SaveManager._sections.clear()
	SaveManager.wipe()
	if failures.is_empty():
		print("LEVEL TESTS PASSED (%d tests: curve, minute table, unlock table, "
			% EXPECTED.size()
			+ "multi-level add_xp, snapshot, garbage restore, service events, "
			+ "legacy migration, prestige)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("LEVEL TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _done(label: String) -> void:
	## The last statement of every test. See `EXPECTED`.
	_finished[label] = true


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


# ------------------------------------------------------------------ the rules

func _test_curve_monotonic() -> void:
	_expect(TerminalLevel.xp_for_level(1) == 0, "level 1 is free")
	_expect(TerminalLevel.xp_for_level(0) == 0, "level 0 clamps to free")
	var previous := 0
	for n in range(2, TerminalLevel.MAX_LEVEL + 1):
		var required := TerminalLevel.xp_for_level(n)
		_expect(required > previous,
			"the curve is strictly increasing at level %d (%d > %d)"
			% [n, required, previous])
		previous = required
	_expect(TerminalLevel.xp_for_level(TerminalLevel.MAX_LEVEL + 5)
		== TerminalLevel.xp_for_level(TerminalLevel.MAX_LEVEL),
		"levels past MAX_LEVEL clamp to the max requirement")
	_expect(TerminalLevel.level_for_xp(0) == 1, "zero XP is level 1")
	_expect(TerminalLevel.level_for_xp(TerminalLevel.xp_for_level(7)) == 7,
		"exactly the requirement lands the level")
	_expect(TerminalLevel.level_for_xp(TerminalLevel.xp_for_level(7) - 1) == 6,
		"one XP short stays on the level below")
	_expect(TerminalLevel.level_for_xp(1000000000) == TerminalLevel.MAX_LEVEL,
		"a huge XP total caps at MAX_LEVEL")
	_done("curve_monotonic")


func _test_minute_table() -> void:
	## Under the assumed rates, each documented level lands in its minute
	## range (plano-release 2.3): 2 at ~2, 3 at ~5, 4 at ~8, 5 at ~12, 6 at ~18,
	## 8 at ~30, 10 at ~45, 12 at ~60.
	var ranges := {
		2: [1.5, 2.6], 3: [4.0, 6.0], 4: [6.5, 9.5], 5: [10.5, 14.0],
		6: [15.0, 20.0], 8: [26.0, 33.0], 10: [40.0, 50.0], 12: [55.0, 66.0],
	}
	for n in ranges.keys():
		var minutes := float(TerminalLevel.xp_for_level(int(n))) / ASSUMED_XP_PER_MIN
		var bounds: Array = ranges[n]
		_expect(minutes >= float(bounds[0]) and minutes <= float(bounds[1]),
			"level %d at %.1f min, expected %.1f-%.1f"
			% [int(n), minutes, float(bounds[0]), float(bounds[1])])
	_done("minute_table")


func _test_unlock_table() -> void:
	_expect(TerminalLevel.UNLOCKS.size() == 17, "the table has 17 features (events joined routes at level 8)")
	var spot := {
		&"shop": 1, &"objective": 2, &"upgrades": 3, &"skill_overtime": 3,
		&"daily": 4, &"land": 5, &"skill_mutirao": 5, &"gull": 5, &"wheel": 6,
		&"journal": 6, &"routes": 8, &"charters": 8, &"skill_pilot": 8,
		&"decor": 10, &"orders": 10, &"prestige": 12,
	}
	for feature in spot.keys():
		_expect(int(TerminalLevel.UNLOCKS.get(feature, -1)) == int(spot[feature]),
			"%s unlocks at %d" % [String(feature), int(spot[feature])])
	var t := TerminalLevel.new()
	_expect(t.unlocked(&"shop") and not t.unlocked(&"objective")
		and not t.unlocked(&"wheel") and not t.unlocked(&"prestige"),
		"a level-1 terminal has only the shop")
	_expect(not t.unlocked(&"not_a_feature"), "an unknown feature is never unlocked")
	t.level = 12
	for feature in TerminalLevel.UNLOCKS.keys():
		_expect(t.unlocked(feature), "%s is unlocked at level 12" % String(feature))
	_expect(TerminalLevel.new().unlocks_at(1) == [&"shop"], "level 1 unlocks the shop")
	_expect(TerminalLevel.new().unlocks_at(2) == [&"objective"], "level 2 the objective")
	_expect(TerminalLevel.new().unlocks_at(4) == [&"daily"], "level 4 the daily missions")
	var at_5 := TerminalLevel.new().unlocks_at(5)
	_expect(at_5.size() == 3 and at_5.has(&"land") and at_5.has(&"skill_mutirao")
		and at_5.has(&"gull"), "level 5 unlocks land, mutirao and the gull")
	var at_6 := TerminalLevel.new().unlocks_at(6)
	_expect(at_6.size() == 2 and at_6.has(&"wheel") and at_6.has(&"journal"),
		"level 6 unlocks the wheel and the journal")
	_expect(TerminalLevel.new().unlocks_at(12) == [&"prestige"],
		"level 12 unlocks the prestige")
	var total := 0
	for n in range(1, TerminalLevel.MAX_LEVEL + 1):
		total += TerminalLevel.new().unlocks_at(n).size()
	_expect(total == 17, "every feature is unlocked by exactly one level")
	_done("unlock_table")


func _test_add_xp_multi_level() -> void:
	var t := TerminalLevel.new()
	var gained := t.add_xp(TerminalLevel.xp_for_level(5))
	_expect(gained == 4 and t.level == 5,
		"one grant can cross several levels (gained %d)" % gained)
	_expect(t.xp == TerminalLevel.xp_for_level(5) and is_zero_approx(t.progress_to_next()),
		"and lands exactly on the level's requirement")
	_expect(t.add_xp(10) == 0 and t.level == 5, "small XP does not level")
	var expected_progress := 10.0 / float(TerminalLevel.xp_for_level(6)
		- TerminalLevel.xp_for_level(5))
	_expect(is_equal_approx(t.progress_to_next(), expected_progress),
		"the bar fills inside the level")
	_expect(t.add_xp(0) == 0 and t.add_xp(-50) == 0 and t.xp == TerminalLevel.xp_for_level(5) + 10,
		"non-positive XP changes nothing")
	var top := TerminalLevel.new()
	_expect(top.add_xp(TerminalLevel.xp_for_level(TerminalLevel.MAX_LEVEL))
		== TerminalLevel.MAX_LEVEL - 1 and top.level == TerminalLevel.MAX_LEVEL,
		"a grant can reach MAX_LEVEL")
	_expect(top.progress_to_next() == 1.0, "the bar is full at MAX_LEVEL")
	_expect(top.add_xp(100000) == 0 and top.level == TerminalLevel.MAX_LEVEL,
		"and nothing levels past it")
	_done("add_xp_multi_level")


# -------------------------------------------------------------- persistence

func _test_snapshot_roundtrip() -> void:
	var t := TerminalLevel.new()
	t.add_xp(TerminalLevel.xp_for_level(5) + 3)
	var snap := t.snapshot()
	_expect(int(snap.get("version", 0)) == 1, "the snapshot is versioned")
	var copy := TerminalLevel.new()
	copy.restore(snap)
	_expect(copy.level == t.level and copy.xp == t.xp,
		"level and XP come back (%d/%d)" % [copy.level, copy.xp])
	_expect(is_equal_approx(copy.progress_to_next(), t.progress_to_next()),
		"and so does the bar")
	_done("snapshot_roundtrip")


func _test_garbage_restore() -> void:
	var t := TerminalLevel.new()
	t.restore({})
	_expect(t.level == 1 and t.xp == 0, "an empty save is a fresh level")
	t.restore({"xp": "banana", "level": {}})
	_expect(t.level == 1 and t.xp == 0, "garbage reads as defaults")
	t.restore({"xp": -50, "level": 99})
	_expect(t.xp == 0 and t.level == 1, "negative XP clamps to zero")
	t.restore({"xp": 1000000, "level": 99})
	_expect(t.level == TerminalLevel.MAX_LEVEL, "the level clamps to MAX_LEVEL")
	t.restore({"xp": 0, "level": 12})
	_expect(t.level == 1,
		"a level the XP does not support is reconciled down")
	t.restore({"xp": TerminalLevel.xp_for_level(8) + 7, "level": 3})
	_expect(t.level == 8 and t.xp == TerminalLevel.xp_for_level(8) + 7,
		"a consistent save keeps its level")
	_done("garbage_restore")


# ------------------------------------------------------------------ service

func _test_service_counts_events() -> void:
	_service = TerminalLevelService.new()
	add_child(_service) # _ready registers the section and seeds the rules
	_expect(SaveManager._sections.has("terminal_level"),
		"the service registers the terminal_level section")
	_expect(_service.rules.level == 1 and _service.rules.xp == 0,
		"a fresh profile starts at level 1 with no XP")
	var changed := [0]
	_service.xp_changed.connect(func() -> void: changed[0] += 1)
	var levels: Array = []
	_service.leveled_up.connect(
		func(level: int, features: Array) -> void: levels.append([level, features]))
	EventBus.cargo_transfer_committed.emit({})
	_expect(_service.rules.xp == TerminalLevel.XP_PER_TRANSFER,
		"a committed transfer pays %d XP" % TerminalLevel.XP_PER_TRANSFER)
	EventBus.ship_departed.emit()
	_expect(_service.rules.xp == TerminalLevel.XP_PER_TRANSFER
		+ TerminalLevel.XP_PER_SHIP_DEPARTED, "a departed ship pays %d XP"
		% TerminalLevel.XP_PER_SHIP_DEPARTED)
	EventBus.structure_purchase_committed.emit({"quantity": 4})
	_expect(_service.rules.xp == TerminalLevel.XP_PER_TRANSFER
		+ TerminalLevel.XP_PER_SHIP_DEPARTED + 4 * TerminalLevel.XP_PER_MACHINE,
		"a purchase pays per unit in the quote")
	EventBus.upgrade_bought.emit("some_upgrade")
	_expect(_service.rules.xp == TerminalLevel.XP_PER_TRANSFER
		+ TerminalLevel.XP_PER_SHIP_DEPARTED + 4 * TerminalLevel.XP_PER_MACHINE
		+ TerminalLevel.XP_PER_UPGRADE, "an upgrade pays %d XP"
		% TerminalLevel.XP_PER_UPGRADE)
	_service.note_mission()
	_expect(_service.rules.xp == TerminalLevel.xp_for_level(2),
		"a claimed mission pays %d XP and completes level 2"
		% TerminalLevel.XP_PER_MISSION_CLAIMED)
	_expect(_service.rules.level == 2, "the level rose to 2")
	_expect(levels.size() == 1 and int(levels[0][0]) == 2,
		"leveled_up fired once for level 2 (%d)" % levels.size())
	_expect(levels[0][1].has(&"objective"),
		"and carries the feature the level unlocked")
	_expect(changed[0] == 5, "every event announced xp_changed (%d)" % changed[0])
	_done("service_counts_events")


func _test_legacy_migration() -> void:
	## A save with no terminal_level section but a played profile: seed_new
	## runs the migration off GameState.lifetime_teus.
	var saved := GameState.to_save()
	GameState.from_save({})
	GameState.lifetime_teus = 5000.0
	_service._seed_new()
	_expect(_service.rules.level == 12
		and _service.rules.xp == TerminalLevel.xp_for_level(12),
		"a profile with 5000 lifetime TEUs migrates to level 12")
	_expect(_service.rules.unlocked(&"prestige") and _service.rules.unlocked(&"wheel"),
		"so everything it could already use stays unlocked")
	GameState.from_save({})
	GameState.all_time_productive_teus = 10.0
	_service._seed_new()
	_expect(_service.rules.level == 1 and _service.rules.xp == 0,
		"a small legacy profile starts honestly at level 1")
	GameState.from_save(saved)
	_done("legacy_migration")


func _test_survives_prestige() -> void:
	## Prestige resets the run (`GameState.do_prestige`), not the registered
	## sections — the level is meta progress and must ride the prestige over.
	var saved := GameState.to_save()
	GameState.from_save({})
	_service._restore({"level": 7, "xp": TerminalLevel.xp_for_level(7) + 5})
	_expect(_service.rules.level == 7, "the level is set before the prestige")
	GameState.all_time_productive_teus = 1.0e10
	_expect(GameState.can_prestige(), "the run has shares to claim")
	_expect(GameState.do_prestige(), "the prestige commits")
	_expect(GameState.prestige_count == 1, "the run itself reset")
	_expect(_service.rules.level == 7
		and _service.rules.xp == TerminalLevel.xp_for_level(7) + 5,
		"the level and XP survive the prestige")
	var envelope := SaveManager.build_envelope()
	_expect(envelope.sections.has("terminal_level"),
		"the section is still in the save envelope after the prestige")
	_expect(int(envelope.sections.terminal_level.get("level", -1)) == 7,
		"and it snapshots the surviving level")
	GameState.from_save(saved)
	_done("survives_prestige")
