extends Node
## Missões do Dia: the daily missions' rules, their persistence, and the
## service that pays a claimed reward into the wheel and the port.
## Run with:
## Godot --headless --path . res://tests/daily_test_runner.tscn
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

const TEST_SAVE_PATH := "user://harborclick_daily_test.json"

const EXPECTED := [
	"same_day", "thirty_days", "note_clamps", "claim_once", "streak",
	"bonus", "claimable", "roundtrip", "garbage", "seed_new",
	"service_tokens", "service_surge",
]

var failures: Array[String] = []
var _finished: Dictionary = {}
var _service: DailyOrdersService
var _wheel: WheelService


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	GameState.from_save({})
	seed(90210)

	_test_same_day_rolls_the_same_three()
	_test_thirty_days_have_distinct_sets()
	_test_note_clamps_and_ignores_other_events()
	_test_claim_refuses_incomplete_and_pays_once()
	_test_streak()
	_test_bonus()
	_test_claimable_count()
	_test_snapshot_restore_round_trip()
	_test_restore_shrugs_off_garbage()
	_test_seed_new()
	_test_the_service_grants_tokens_to_the_wheel()
	_test_the_service_applies_the_surge()

	for label in EXPECTED:
		_expect(_finished.has(label), "the '%s' test ran to the end" % label)

	if _service != null:
		_service.queue_free()
		_service = null
	if _wheel != null:
		_wheel.queue_free()
		_wheel = null
	await get_tree().process_frame
	SaveManager._sections.clear()
	SaveManager.wipe()
	if failures.is_empty():
		print("DAILY TESTS PASSED (%d tests: same-day roll, 30-day variety, "
			% EXPECTED.size()
			+ "note clamp, claim-once, streak, bonus, claimable, round trip, "
			+ "garbage restore, seed, service tokens, service surge)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("DAILY TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _done(label: String) -> void:
	## The last statement of every test. See `EXPECTED`.
	_finished[label] = true


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _ids(orders: DailyOrders) -> Array:
	var ids: Array = []
	for m in orders.missions:
		ids.append(StringName(m.id))
	return ids


func _key(orders: DailyOrders) -> String:
	var key := ""
	for id in _ids(orders):
		key += String(id) + "|"
	return key


func _fill_all(orders: DailyOrders, day: int) -> void:
	## Note every pooled event with a huge amount, so every mission of `day`
	## reaches its goal.
	for template in DailyOrders.POOL:
		orders.note(StringName(template.event), 1000000, day)


# ------------------------------------------------------------------ the rules

func _test_same_day_rolls_the_same_three() -> void:
	var a := DailyOrders.new()
	var b := DailyOrders.new()
	a.roll_day(20000)
	b.roll_day(20000)
	_expect(a.missions.size() == DailyOrders.MISSIONS_PER_DAY, "a day rolls three missions")
	_expect(_ids(a) == _ids(b), "the same day rolls the same three on a second object")
	var c := DailyOrders.new()
	c.roll_day(20000)
	c.roll_day(20000) # rolling the same day twice must not reshuffle
	_expect(_ids(c) == _ids(a), "rolling the same day again does not reshuffle")
	var unique := {}
	for id in _ids(a):
		unique[id] = true
	_expect(unique.size() == 3, "the three are different templates")
	var found_different := false
	for d in range(20001, 20011):
		var probe := DailyOrders.new()
		probe.roll_day(d)
		if _ids(probe) != _ids(a):
			found_different = true
	_expect(found_different, "another day rolls a different set")
	_done("same_day")


func _test_thirty_days_have_distinct_sets() -> void:
	var sets := {}
	for d in range(20000, 20030):
		var o := DailyOrders.new()
		o.roll_day(d)
		sets[_key(o)] = d
	_expect(sets.size() >= 5,
		"30 days give at least 5 distinct mission sets (%d)" % sets.size())
	_done("thirty_days")


func _test_note_clamps_and_ignores_other_events() -> void:
	var o := DailyOrders.new()
	o.roll_day(20000)
	o.note(&"nope", 999, 20000)
	for m in o.missions:
		_expect(int(m.progress) == 0, "an event no mission watches changes nothing")
	o.note(&"ship", 2, 20000)
	for m in o.missions:
		var want := mini(2, int(m.goal)) if StringName(m.get("event", &"")) == &"ship" else 0
		_expect(int(m.progress) == want, "only the ship missions took the +2")
	_fill_all(o, 20000)
	for m in o.missions:
		_expect(int(m.progress) == int(m.goal), "a huge note clamps to the goal")
	o.note(&"ship", 5, 20000)
	for m in o.missions:
		_expect(int(m.progress) == int(m.goal), "noting a full mission stays at the goal")
	o.claim(0, 20000) # pays, and marks mission 0 claimed
	var m0: Dictionary = o.missions[0]
	var event0: StringName = StringName(m0.event)
	var goal0 := int(m0.goal)
	o.note(event0, 1000, 20000)
	_expect(int(o.missions[0].progress) == goal0, "a claimed mission takes no more progress")
	_done("note_clamps")


func _test_claim_refuses_incomplete_and_pays_once() -> void:
	var o := DailyOrders.new()
	o.roll_day(20000)
	_expect(o.claim(0, 20000) == {}, "an incomplete mission refuses to pay")
	_expect(o.claim(9, 20000) == {}, "and so does a bad index")
	var m0: Dictionary = o.missions[0]
	m0["progress"] = m0["goal"]
	var reward := o.claim(0, 20000)
	_expect(int(reward.get("tokens", 0)) == 1, "a complete mission pays one token")
	_expect(bool(o.missions[0].claimed), "and is marked claimed")
	_expect(o.claim(0, 20000) == {}, "a second claim pays nothing")
	_done("claim_once")


func _test_streak() -> void:
	var o := DailyOrders.new()
	o.roll_day(100)
	_fill_all(o, 100)
	var r := o.claim(0, 100)
	_expect(int(r.get("tokens", 0)) == 1 and o.streak == 1 and o.last_active_day == 100,
		"the first claim of a day starts the streak")
	r = o.claim(1, 100)
	_expect(o.streak == 1, "another claim the same day does not grow the streak")
	_expect(int(r.get("tokens", 0)) == 1, "and still pays its token")
	_fill_all(o, 101)
	r = o.claim(0, 101)
	_expect(o.streak == 2 and o.last_active_day == 101, "a consecutive day grows the streak")
	_fill_all(o, 103) # 102 is skipped
	r = o.claim(0, 103)
	_expect(o.streak == 1, "a skipped day resets the streak (the new day then claims +1)")
	_expect(o.best_streak == 2, "the best streak is remembered")
	# seven days in a row: the 7th pays an extra token
	var s := DailyOrders.new()
	for d in range(1, 8):
		_fill_all(s, d)
		var pay := s.claim(0, d)
		if d == 7:
			_expect(int(pay.get("tokens", 0)) == 2, "the 7th day of a streak pays an extra token")
		else:
			_expect(int(pay.get("tokens", 0)) == 1, "day %d of a streak pays one token" % d)
	_expect(s.streak == 7 and s.best_streak == 7, "seven consecutive days")
	_done("streak")


func _test_bonus() -> void:
	var o := DailyOrders.new()
	o.roll_day(200)
	_expect(o.claim_bonus(200) == {}, "the bonus refuses on a fresh day")
	_fill_all(o, 200)
	_expect(o.claim_bonus(200) == {}, "complete but unclaimed is not enough")
	o.claim(0, 200)
	o.claim(1, 200)
	_expect(o.claim_bonus(200) == {}, "two of three is not enough either")
	o.claim(2, 200)
	var bonus := o.claim_bonus(200)
	_expect(float(bonus.get("surge_mult", 0.0)) == 3.0
		and float(bonus.get("surge_seconds", 0.0)) == 120.0
		and int(bonus.get("tokens", 0)) == 1, "all three claimed pays the bonus")
	_expect(o.bonus_claimed, "and marks it")
	_expect(o.claim_bonus(200) == {}, "only once")
	_done("bonus")


func _test_claimable_count() -> void:
	var o := DailyOrders.new()
	o.roll_day(300)
	_expect(o.claimable_count() == 0, "nothing claimable on a fresh day")
	var m0: Dictionary = o.missions[0]
	m0["progress"] = m0["goal"]
	_expect(o.claimable_count() == 1, "one complete unclaimed mission")
	o.claim(0, 300)
	_expect(o.claimable_count() == 0, "a claimed mission is not claimable")
	var m1: Dictionary = o.missions[1]
	var m2: Dictionary = o.missions[2]
	m1["progress"] = m1["goal"]
	m2["progress"] = m2["goal"]
	_expect(o.claimable_count() == 2, "two complete unclaimed missions")
	o.claim(1, 300)
	o.claim(2, 300)
	_expect(o.claimable_count() == 1, "all claimed: only the bonus is left")
	o.claim_bonus(300)
	_expect(o.claimable_count() == 0, "and nothing after the bonus")
	_done("claimable")


# -------------------------------------------------------------- persistence

func _test_snapshot_restore_round_trip() -> void:
	var o := DailyOrders.new()
	o.roll_day(400)
	o.note(&"ship", 2, 400)
	var m0: Dictionary = o.missions[0]
	m0["progress"] = m0["goal"]
	o.claim(0, 400)
	o.best_streak = 5
	var snap := o.snapshot()
	var copy := DailyOrders.new()
	copy.restore(snap)
	_expect(copy.day == 400 and copy.streak == o.streak and copy.last_active_day == 400
		and copy.best_streak == 5 and copy.bonus_claimed == o.bonus_claimed,
		"the streak fields round-trip")
	_expect(copy.missions.size() == 3, "three missions round-trip")
	for i in 3:
		_expect(StringName(copy.missions[i].id) == StringName(o.missions[i].id)
			and int(copy.missions[i].progress) == int(o.missions[i].progress)
			and bool(copy.missions[i].claimed) == bool(o.missions[i].claimed),
			"mission %d round-trips" % i)
	var fresh := DailyOrders.new()
	fresh.roll_day(400)
	_expect(_ids(copy) == _ids(fresh), "a reload does not reshuffle the day")
	_done("roundtrip")


func _test_restore_shrugs_off_garbage() -> void:
	var o := DailyOrders.new()
	o.restore({"day": "banana", "missions": 42, "streak": -3,
		"bonus_claimed": 1, "last_active_day": {}, "best_streak": "x"})
	_expect(o.day == 0 and o.missions.size() == 3 and o.streak == 0
		and not o.bonus_claimed, "garbage reads as a fresh day-0 roll")
	var fresh0 := DailyOrders.new()
	fresh0.roll_day(0)
	_expect(_ids(o) == _ids(fresh0), "and the day is re-rolled deterministically")
	o.restore({})
	_expect(o.missions.size() == 3 and o.streak == 0, "an empty save is a valid save")
	# a day whose rolled set contains the unload mission, so the clamp is observable
	var day_with_unload := 500
	for d in range(500, 530):
		var probe := DailyOrders.new()
		probe.roll_day(d)
		for m in probe.missions:
			if StringName(m.id) == &"unload":
				day_with_unload = d
	o.restore({"day": day_with_unload, "missions": [
		{"id": &"nope", "progress": 99}, 42, null,
		{"id": &"unload", "progress": 99999, "claimed": 1}]})
	_expect(o.day == day_with_unload and o.missions.size() == 3,
		"junk entries and unknown ids are dropped")
	for m in o.missions:
		if StringName(m.id) == &"unload":
			_expect(int(m.progress) == 60 and bool(m.claimed),
				"the known id keeps its progress, clamped to the goal")
	var fresh := DailyOrders.new()
	fresh.roll_day(day_with_unload)
	_expect(_ids(o) == _ids(fresh), "the day's set is the rolled one, not the save's")
	_done("garbage")


func _test_seed_new() -> void:
	var data := DailyOrders.seed_new(777)
	_expect(int(data.get("day", -1)) == 777, "seed_new stores the day")
	var o := DailyOrders.new()
	o.restore(data)
	_expect(o.day == 777 and o.missions.size() == 3, "a new profile gets the day's three")
	_expect(o.claimable_count() == 0 and not o.bonus_claimed and o.streak == 0,
		"with nothing done and no streak")
	for m in o.missions:
		_expect(int(m.progress) == 0 and not bool(m.claimed), "fresh missions start empty")
	_done("seed_new")


# ------------------------------------------------------------------ service

func _test_the_service_grants_tokens_to_the_wheel() -> void:
	_wheel = WheelService.new()
	add_child(_wheel)
	_service = DailyOrdersService.new()
	_service.setup(_wheel)
	add_child(_service)
	_expect(SaveManager._sections.has(&"daily_orders"),
		"the service registers the daily_orders section")
	_expect(EventBus.is_connected(&"cargo_transfer_committed",
		Callable(_service, "_on_cargo_transfer_committed")), "wired: cargo transfers")
	_expect(EventBus.is_connected(&"manual_reward_committed",
		Callable(_service, "_on_manual_reward_committed")), "wired: manual taps")
	_expect(EventBus.is_connected(&"ship_departed",
		Callable(_service, "_on_ship_departed")), "wired: departures")
	_expect(EventBus.is_connected(&"structure_purchase_committed",
		Callable(_service, "_on_structure_purchase")), "wired: machine purchases")
	_expect(EventBus.is_connected(&"upgrade_bought",
		Callable(_service, "_on_upgrade_bought")), "wired: upgrades")
	var envelope := SaveManager.build_envelope()
	_expect(envelope.sections.has(&"daily_orders"),
		"the section is in the save envelope (meta, it rides a prestige)")
	# the wheel's new spun signal
	_wheel.wheel.restore(LuckyWheel.seed_new(Time.get_unix_time_from_system()))
	var spun := [0]
	_wheel.spun.connect(func() -> void: spun[0] += 1)
	var prize := _wheel.spin()
	_expect(not prize.is_empty() and spun[0] == 1, "spin() emits spun when a prize is decided")
	_wheel.claim_and_apply()
	# a departure through the real signal feeds only the ship mission
	var day := _service._current_day()
	EventBus.ship_departed.emit()
	for m in _service.orders.missions:
		var want := mini(1, int(m.goal)) if StringName(m.get("event", &"")) == &"ship" else 0
		_expect(int(m.progress) == want, "a departure feeds only the ship mission")
	# the two Main-facing notes
	_service.note_spin()
	_service.note_gull()
	for m in _service.orders.missions:
		var event := StringName(m.get("event", &""))
		var want := 0
		if event == &"ship" or event == &"spin" or event == &"gull":
			want = mini(1, int(m.goal))
		_expect(int(m.progress) == want, "note_spin/note_gull feed their missions")
	# A purchase feeds the units it actually bought, from the committed quote —
	# never `structure_bought`'s count, which is the machine's total owned and
	# would finish "buy ten machines" with one tap on a port with a fleet.
	EventBus.structure_purchase_committed.emit({"id": "estivador", "quantity": 4})
	EventBus.structure_bought.emit("estivador", 250)
	for m in _service.orders.missions:
		var event := StringName(m.get("event", &""))
		var want := 0
		if event == &"ship" or event == &"spin" or event == &"gull":
			want = mini(1, int(m.goal))
		elif event == &"machine":
			want = mini(4, int(m.goal))
		_expect(int(m.progress) == want, "a purchase feeds the units bought, not the fleet size")
	# a claim pays tokens into the wheel
	_fill_all(_service.orders, day)
	var tokens_before := _wheel.wheel.tokens
	var changed := [0]
	_service.state_changed.connect(func() -> void: changed[0] += 1)
	var reward := _service.claim(0)
	_expect(int(reward.get("tokens", 0)) == 1, "the claim returns a token")
	_expect(_wheel.wheel.tokens == tokens_before + 1, "and the wheel's rack got it")
	_expect(changed[0] > 0, "and the service announced the change")
	_done("service_tokens")


func _test_the_service_applies_the_surge() -> void:
	if _service == null or _wheel == null:
		_expect(false, "the service and the wheel exist")
		_done("service_surge")
		return
	var saved := GameState.to_save()
	GameState.from_save({})
	var day := _service._current_day()
	_fill_all(_service.orders, day)
	_service.claim(0)
	_service.claim(1)
	_service.claim(2)
	var bonus := _service.claim_bonus()
	_expect(float(bonus.get("surge_mult", 0.0)) == 3.0
		and float(bonus.get("surge_seconds", 0.0)) == 120.0,
		"the bonus reward is the turbo")
	_expect(is_equal_approx(GameState.surge_mult, 3.0)
		and is_equal_approx(GameState.surge_time, 120.0),
		"and GameState.grant_surge got it (x%.1f for %.0fs)"
		% [GameState.surge_mult, GameState.surge_time])
	_expect(_service.claim_bonus() == {}, "and the bonus pays only once")
	GameState.from_save(saved)
	_done("service_surge")
