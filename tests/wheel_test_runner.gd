extends Node
## The Roda da Sorte: the wheel's rules, its persistence, and the service that
## applies a claimed prize to the port.
## Run with:
## Godot --headless --path . res://tests/wheel_test_runner.tscn
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

const TEST_SAVE_PATH := "user://harborclick_wheel_test.json"

const EXPECTED := [
	"weights", "free_before_tokens", "free_clock", "pending_blocks",
	"claim_once", "departures", "prize_amount", "snapshot_roundtrip",
	"garbage_restore", "seed_new", "service_spin", "service_cash",
	"service_surge", "service_token", "prestige_keeps_section",
	"pending_applied_once", "panel_spin", "panel_close_mid_spin",
	"panel_disabled", "button_badge",
]

var failures: Array[String] = []
var _finished: Dictionary = {}
var _service: WheelService


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	GameState.from_save({})
	seed(90210)

	_test_weights_follow_the_table()
	_test_the_free_spin_is_spent_before_a_token()
	_test_the_free_clock()
	_test_a_pending_prize_blocks_the_next_spin()
	_test_claim_pays_exactly_once()
	_test_departures_grant_every_third_token()
	_test_prize_amount_uses_base_cps_and_the_floor()
	_test_snapshot_restore_round_trip()
	_test_restore_shrugs_off_garbage()
	_test_seed_new_offers_a_free_spin_now()
	_test_the_service_registers_and_spins()
	_test_the_service_applies_cash()
	_test_the_service_applies_surge()
	_test_the_service_applies_a_token()
	_test_the_section_survives_a_prestige()
	await _test_a_restored_pending_prize_is_applied_exactly_once()
	await _test_panel_spin()
	await _test_panel_close_mid_spin()
	await _test_panel_disabled()
	await _test_panel_button_badge()

	for label in EXPECTED:
		_expect(_finished.has(label), "the '%s' test ran to the end" % label)

	if _service != null:
		_service.queue_free()
		_service = null
		await get_tree().process_frame
	SaveManager._sections.clear()
	SaveManager.wipe()
	if failures.is_empty():
		print("WHEEL TESTS PASSED (%d tests: weights, free spin, free clock, "
			% EXPECTED.size()
			+ "pending block, claim-once, departures, prize amount, snapshot, "
			+ "garbage restore, seed, service spin/cash/surge/token, prestige, "
			+ "pending-on-reload)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("WHEEL TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _done(label: String) -> void:
	## The last statement of every test. See `EXPECTED`.
	_finished[label] = true


func _new_wheel(now: float = 1000.0) -> LuckyWheel:
	var w := LuckyWheel.new()
	w.restore(LuckyWheel.seed_new(now))
	return w


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# ------------------------------------------------------------------ the rules

func _test_weights_follow_the_table() -> void:
	## 20000 seeded spins: every segment lands within 1.5 percentage points of
	## its weight. The weights sum to 100, so a weight is the expected share.
	var w := _new_wheel(0.0)
	w.next_free_unix = 1.0e12 # never free: every spin below spends a token
	w.tokens = 100000
	var rng := _seeded_rng(20260214)
	var counts := {}
	for i in LuckyWheel.SEGMENTS.size():
		counts[i] = 0
	var spins := 0
	for n in 20000:
		var prize := w.spin(0.0, rng)
		if prize.is_empty():
			continue
		spins += 1
		counts[int(prize.index)] += 1
		w.claim()
	_expect(spins == 20000, "every one of the 20000 spins landed (%d)" % spins)
	var total_weight := 0
	for segment in LuckyWheel.SEGMENTS:
		total_weight += int(segment.weight)
	for i in LuckyWheel.SEGMENTS.size():
		var share := 100.0 * float(counts[i]) / float(spins)
		var expected := 100.0 * float(LuckyWheel.SEGMENTS[i].weight) / float(total_weight)
		_expect(absf(share - expected) <= 1.5,
			"segment %s landed %.2f%% of the spins, expected %.2f%%"
			% [str(LuckyWheel.SEGMENTS[i].id), share, expected])
	_expect(w.spins_total == 20000, "every spin is counted")
	_done("weights")


func _test_the_free_spin_is_spent_before_a_token() -> void:
	var w := _new_wheel(100.0) # the free spin is ready at t=100
	w.tokens = 2
	var rng := _seeded_rng(7)
	var prize := w.spin(100.0, rng)
	_expect(not prize.is_empty(), "the free spin fires")
	_expect(w.tokens == 2, "a free spin does not spend a token")
	_expect(is_equal_approx(w.next_free_unix, 100.0 + LuckyWheel.FREE_SPIN_INTERVAL),
		"and restarts the free clock")
	w.claim() # a pending prize blocks the next spin; collect it first
	prize = w.spin(100.0, rng)
	_expect(not prize.is_empty(), "a token spin fires right after")
	_expect(w.tokens == 1, "a spin with the free clock running spends a token")
	w.claim()
	w.tokens = 0
	_expect(not w.can_spin(100.0), "no free spin and no tokens means no spin")
	_expect(w.spin(100.0, rng).is_empty(), "and spin refuses")
	_done("free_before_tokens")


func _test_the_free_clock() -> void:
	var w := _new_wheel(500.0)
	_expect(w.free_spin_ready(500.0), "ready exactly at the deadline")
	_expect(not w.free_spin_ready(499.999), "not ready a hair before")
	_expect(is_zero_approx(w.seconds_to_free(500.0)), "nothing to wait at the deadline")
	_expect(is_equal_approx(w.seconds_to_free(400.0), 100.0), "the wait counts down")
	w.next_free_unix = 500.0 + LuckyWheel.FREE_SPIN_INTERVAL
	_expect(is_equal_approx(w.seconds_to_free(500.0), LuckyWheel.FREE_SPIN_INTERVAL),
		"a full interval of waiting after a spin")
	_done("free_clock")


func _test_a_pending_prize_blocks_the_next_spin() -> void:
	var w := _new_wheel(10.0)
	w.tokens = 5
	var rng := _seeded_rng(11)
	var prize := w.spin(10.0, rng)
	_expect(not prize.is_empty(), "the first spin lands")
	_expect(not w.can_spin(10.0),
		"a pending prize blocks the next spin even with tokens to spend")
	_expect(w.spin(10.0, rng).is_empty(), "and spin refuses while pending")
	_expect(w.pending == prize, "the pending prize is the one that was returned")
	_done("pending_blocks")


func _test_claim_pays_exactly_once() -> void:
	var w := _new_wheel(10.0)
	var rng := _seeded_rng(13)
	var prize := w.spin(10.0, rng)
	var claimed := w.claim()
	_expect(not claimed.is_empty() and claimed == prize, "claim returns the pending prize")
	_expect(w.pending.is_empty(), "and clears it")
	_expect(w.claim().is_empty(), "a second claim pays nothing")
	_expect(w.can_spin(10.0 + LuckyWheel.FREE_SPIN_INTERVAL),
		"and the wheel can spin again once the prize is collected")
	_done("claim_once")


func _test_departures_grant_every_third_token() -> void:
	var w := _new_wheel(0.0)
	_expect(not w.note_departure(), "the first departure earns nothing")
	_expect(not w.note_departure(), "nor the second")
	_expect(w.note_departure(), "the third earns a token")
	_expect(w.tokens == 1 and w.departures == 0, "and the progress resets")
	w.tokens = LuckyWheel.MAX_TOKENS
	_expect(not w.note_departure(), "at the cap the first departure grants nothing")
	_expect(not w.note_departure(), "at the cap the second grants nothing")
	_expect(not w.note_departure(), "at the cap the third still grants nothing")
	_expect(w.tokens == LuckyWheel.MAX_TOKENS, "the rack stays full")
	_expect(w.departures == 0, "and the progress still resets at the cap")
	_done("departures")


func _test_prize_amount_uses_base_cps_and_the_floor() -> void:
	var w := _new_wheel(0.0)
	var cash_s: Dictionary = LuckyWheel.SEGMENTS[0]
	_expect(is_equal_approx(w.prize_amount(cash_s, 0.0), LuckyWheel.MIN_PRIZE_CPS * 90.0),
		"an empty port still pays the floor")
	_expect(is_equal_approx(w.prize_amount(cash_s, 2.0), 180.0),
		"cash pays base cps times seconds")
	var jackpot: Dictionary = LuckyWheel.SEGMENTS[4]
	_expect(is_equal_approx(w.prize_amount(jackpot, 3.0), 3.0 * 3600.0),
		"the jackpot scales with the base rate")
	var surge: Dictionary = LuckyWheel.SEGMENTS[1]
	_expect(w.prize_amount(surge, 5.0) == 0.0, "a surge has no cash amount")
	# The floor is a floor, not a minimum wage: a rich port gets its real rate.
	_expect(is_equal_approx(w.prize_amount(cash_s, 50.0), 50.0 * 90.0),
		"a rate above the floor is paid in full")
	_done("prize_amount")


# -------------------------------------------------------------- persistence

func _test_snapshot_restore_round_trip() -> void:
	var w := _new_wheel(1000.0)
	var rng := _seeded_rng(17)
	w.tokens = 2
	w.departures = 2
	w.spin(2000.0, rng) # the free spin is ready at 1000, so this is a free spin
	w.spins_total = 9
	w.jackpots = 1
	var snap := w.snapshot()
	var copy := LuckyWheel.new()
	copy.restore(snap)
	_expect(copy.tokens == 2 and copy.departures == 2
		and copy.spins_total == 9 and copy.jackpots == 1, "the counters come back")
	_expect(is_equal_approx(copy.next_free_unix, w.next_free_unix), "the clock comes back")
	_expect(not copy.pending.is_empty() and copy.pending == w.pending,
		"a pending prize survives the round trip")
	_expect(copy.claim() == w.claim(), "and both wheels hand out the same prize")
	_done("snapshot_roundtrip")


func _test_restore_shrugs_off_garbage() -> void:
	var w := LuckyWheel.new()
	w.restore({"tokens": "banana", "next_free_unix": {}, "departures": -5,
		"pending": 42, "spins_total": "x", "jackpots": null})
	_expect(w.tokens == 0 and w.departures == 0 and w.pending.is_empty()
		and w.spins_total == 0 and w.jackpots == 0, "garbage reads as defaults")
	_expect(w.next_free_unix == 0.0, "a garbage clock reads as zero")
	w.restore({})
	_expect(w.tokens == 0 and w.pending.is_empty(), "an empty save is a valid save")
	w.restore({"tokens": 999, "next_free_unix": -50.0,
		"pending": {"index": 99, "id": &"nope"}})
	_expect(w.tokens == LuckyWheel.MAX_TOKENS, "tokens clamp to the rack")
	_expect(w.next_free_unix == 0.0, "the clock never goes negative")
	_expect(w.pending.is_empty(), "a pending prize with an unknown index is dropped")
	w.restore({"pending": {"index": 2, "id": &"cash_m", "rigged": true}})
	_expect(StringName(w.pending.get("id", &"")) == &"cash_m" and int(w.pending.index) == 2,
		"a pending prize naming a real segment comes back")
	_expect(float(w.pending.get("seconds", 0.0)) == 360.0,
		"rebuilt from the catalogue, not from the save's extra keys")
	_done("garbage_restore")


func _test_seed_new_offers_a_free_spin_now() -> void:
	var w := LuckyWheel.new()
	w.restore(LuckyWheel.seed_new(777.0))
	_expect(w.free_spin_ready(777.0), "a new profile can spin for free immediately")
	_expect(is_zero_approx(w.seconds_to_free(777.0)), "with nothing to wait for")
	_expect(w.tokens == 0 and w.pending.is_empty(), "and no tokens yet")
	_expect(w.can_spin(777.0), "so the wheel can spin at once")
	_done("seed_new")


# ------------------------------------------------------------------ service

func _test_the_service_registers_and_spins() -> void:
	_service = WheelService.new()
	add_child(_service) # _ready registers the section and seeds the wheel
	_expect(SaveManager._sections.has("lucky_wheel"),
		"the service registers the lucky_wheel section")
	# Counters in an Array: a GDScript lambda captures a local int by value, so
	# `changed += 1` inside it would count into a copy and the test would fail
	# for a reason that has nothing to do with the wheel.
	var changed := [0]
	_service.state_changed.connect(func() -> void: changed[0] += 1)
	_expect(_service.wheel.free_spin_ready(Time.get_unix_time_from_system()),
		"a fresh service has a free spin ready")
	var prize := _service.spin()
	_expect(not prize.is_empty(), "spin lands a prize on the real clock")
	_expect(changed[0] > 0, "and announces the new state")
	_expect(_service.wheel.pending == prize, "the prize is pending until claimed")
	var earned := [0]
	_service.token_earned.connect(func() -> void: earned[0] += 1)
	EventBus.ship_departed.emit()
	EventBus.ship_departed.emit()
	EventBus.ship_departed.emit()
	_expect(earned[0] == 0 and _service.wheel.tokens == 0,
		"ships no longer feed the wheel: it is rare on purpose")
	_service.claim_and_apply() # clear the pending prize so later tests start clean
	_done("service_spin")


func _test_the_service_applies_cash() -> void:
	var saved := GameState.to_save()
	GameState.from_save({})
	GameState.base_cps = 2.0
	var teus_before := GameState.teus
	var productive_before := GameState.all_time_productive_teus
	var applied: Array = []
	_service.prize_applied.connect(
		func(p: Dictionary, amount: float) -> void: applied.append([p, amount]))
	_service.wheel.pending = LuckyWheel.SEGMENTS[0].duplicate()
	_service.wheel.pending["index"] = 0
	var prize := _service.claim_and_apply()
	_expect(StringName(prize.get("id", &"")) == &"cash_s", "the cash prize is claimed")
	var expected := 2.0 * 90.0
	_expect(is_equal_approx(GameState.teus - teus_before, expected),
		"cash pays base cps × seconds (got %.1f)" % (GameState.teus - teus_before))
	_expect(is_equal_approx(GameState.all_time_productive_teus, productive_before),
		"prize money does not count toward prestige")
	_expect(applied.size() == 1 and is_equal_approx(float(applied[0][1]), expected),
		"prize_applied carries the computed amount")
	_expect(_service.wheel.pending.is_empty(), "and the wheel is idle again")
	_expect(_service.claim_and_apply().is_empty(), "a second claim applies nothing")
	GameState.from_save(saved)
	_done("service_cash")


func _test_the_service_applies_surge() -> void:
	var saved := GameState.to_save()
	GameState.from_save({})
	_service.wheel.pending = LuckyWheel.SEGMENTS[5].duplicate() # surge3: ×3 for 60s
	_service.wheel.pending["index"] = 5
	var prize := _service.claim_and_apply()
	_expect(StringName(prize.get("id", &"")) == &"surge3", "the surge prize is claimed")
	_expect(is_equal_approx(GameState.surge_mult, 3.0)
		and is_equal_approx(GameState.surge_time, 60.0),
		"the surge lands on the port (×%.1f for %.0fs)"
		% [GameState.surge_mult, GameState.surge_time])
	GameState.from_save(saved)
	_done("service_surge")


func _test_the_service_applies_a_token() -> void:
	var saved := GameState.to_save()
	GameState.from_save({})
	_service.wheel.tokens = 2
	_service.wheel.pending = LuckyWheel.SEGMENTS[3].duplicate() # respin: +1 token
	_service.wheel.pending["index"] = 3
	var prize := _service.claim_and_apply()
	_expect(StringName(prize.get("id", &"")) == &"respin", "the token prize is claimed")
	_expect(_service.wheel.tokens == 3, "and it adds a token")
	_service.wheel.tokens = LuckyWheel.MAX_TOKENS
	_service.wheel.pending = LuckyWheel.SEGMENTS[3].duplicate()
	_service.wheel.pending["index"] = 3
	_service.claim_and_apply()
	_expect(_service.wheel.tokens == LuckyWheel.MAX_TOKENS, "capped at the rack")
	GameState.from_save(saved)
	_done("service_token")


func _test_the_section_survives_a_prestige() -> void:
	## Prestige resets the run (`GameState.do_prestige`), not the registered
	## sections — only a full profile wipe re-seeds those. Tokens and the free
	## clock are meta progress and must ride the prestige over.
	var saved := GameState.to_save()
	GameState.from_save({})
	_service.wheel.tokens = 5
	_service.wheel.departures = 1
	GameState.all_time_productive_teus = 1.0e10
	_expect(GameState.can_prestige(), "the run has shares to claim")
	_expect(GameState.do_prestige(), "the prestige commits")
	_expect(GameState.prestige_count == 1, "the run itself reset")
	_expect(_service.wheel.tokens == 5 and _service.wheel.departures == 1,
		"the wheel's meta progress is not wiped by the prestige")
	var envelope := SaveManager.build_envelope()
	_expect(envelope.sections.has("lucky_wheel"),
		"the section is still in the save envelope after the prestige")
	_expect(int(envelope.sections.lucky_wheel.get("tokens", -1)) == 5,
		"and it snapshots the surviving tokens")
	GameState.from_save(saved)
	_done("prestige_keeps_section")


func _test_a_restored_pending_prize_is_applied_exactly_once() -> void:
	var saved := GameState.to_save()
	GameState.from_save({})
	# Decide a cash_m prize, then persist the whole game with it pending.
	_service.wheel.pending = LuckyWheel.SEGMENTS[2].duplicate()
	_service.wheel.pending["index"] = 2
	_expect(SaveManager.save_game(&"test"), "the pending prize is written to the save")
	var applied: Array = []
	_service.prize_applied.connect(
		func(_p: Dictionary, amount: float) -> void: applied.append(amount))
	_expect(SaveManager.load_game(), "the save reloads")
	await get_tree().process_frame
	await get_tree().process_frame
	# The reload restored GameState from the core (no structures, so base_cps
	# is 0), and the wheel section came back with the prize still pending.
	_expect(applied.size() == 1,
		"the restored pending prize was applied exactly once (%d)" % applied.size())
	_expect(is_equal_approx(float(applied[0]), LuckyWheel.MIN_PRIZE_CPS * 360.0),
		"priced from the reloaded base rate through the floor")
	_expect(is_equal_approx(GameState.teus, float(applied[0])),
		"and it landed in the wallet once")
	_expect(_service.wheel.pending.is_empty(), "the pending prize is cleared")
	_expect(_service.claim_and_apply().is_empty(), "and cannot be applied again")
	_expect(applied.size() == 1, "exactly one prize_applied signal in total")
	GameState.from_save(saved)
	_done("pending_applied_once")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


# ------------------------------------------------------------------ the panel

func _free_wheel_ready() -> void:
	## The shared service's wheel, reset so a free spin is ready right now and
	## nothing is pending.
	_service.wheel.restore(LuckyWheel.seed_new(Time.get_unix_time_from_system()))
	_service.wheel.pending = {}
	_service.wheel.tokens = 0


func _test_panel_spin() -> void:
	var saved := GameState.to_save()
	GameState.from_save({})
	_free_wheel_ready()
	var panel := LuckyWheelPanel.new()
	panel.setup(_service)
	add_child(panel)
	panel.open()
	var applied: Array = []
	_service.prize_applied.connect(
		func(p: Dictionary, amount: float) -> void: applied.append([p, amount]))
	_expect(panel.is_open(), "the panel opens")
	_expect(not panel._spin_button.disabled,
		"the spin key is enabled with a free spin ready")
	panel._spin_button.pressed.emit()
	_expect(not _service.wheel.pending.is_empty(), "the spin decided a prize")
	_expect(panel._spinning, "the spin animation is running")
	# Drive the panel's own _process with big deltas until the spin ends.
	var guard := 0
	while panel._spinning and guard < 64:
		panel._process(0.25)
		guard += 1
	_expect(not panel._spinning, "the spin ran to the end")
	_expect(_service.wheel.pending.is_empty(), "the pending prize was claimed")
	_expect(applied.size() == 1,
		"prize_applied fired exactly once (%d)" % applied.size())
	_expect(panel._prize.visible and not panel._prize.text.is_empty(),
		"the prize label is revealed with its name")
	_expect(not panel._detail.text.is_empty(), "the prize detail is filled in")
	panel.queue_free()
	await get_tree().process_frame
	GameState.from_save(saved)
	_done("panel_spin")


func _test_panel_close_mid_spin() -> void:
	var saved := GameState.to_save()
	GameState.from_save({})
	_free_wheel_ready()
	var panel := LuckyWheelPanel.new()
	panel.setup(_service)
	add_child(panel)
	panel.open()
	var applied := [0]
	_service.prize_applied.connect(
		func(_p: Dictionary, _amount: float) -> void: applied[0] += 1)
	panel._spin_button.pressed.emit()
	_expect(panel._spinning, "the spin started")
	panel.close()
	_expect(not panel.is_open(), "the panel is hidden after close")
	_expect(applied[0] == 1,
		"a mid-spin close applied the prize exactly once (%d)" % applied[0])
	_expect(_service.wheel.pending.is_empty(), "nothing is left pending")
	panel.queue_free()
	await get_tree().process_frame
	GameState.from_save(saved)
	_done("panel_close_mid_spin")


func _test_panel_disabled() -> void:
	var saved := GameState.to_save()
	GameState.from_save({})
	_free_wheel_ready()
	_service.wheel.next_free_unix = Time.get_unix_time_from_system() + 100000.0
	_service.wheel.tokens = 0
	var panel := LuckyWheelPanel.new()
	panel.setup(_service)
	add_child(panel)
	panel.open()
	panel._refresh_status()
	_expect(panel._spin_button.disabled,
		"no free spin and no tokens disables the spin key")
	panel._spin_button.pressed.emit()
	_expect(_service.wheel.pending.is_empty(), "a refused spin decides nothing")
	panel.queue_free()
	await get_tree().process_frame
	GameState.from_save(saved)
	_done("panel_disabled")


func _test_panel_button_badge() -> void:
	var saved := GameState.to_save()
	GameState.from_save({})
	_free_wheel_ready()
	_service.wheel.tokens = 3
	var button := WheelButton.new()
	button.setup(_service)
	add_child(button)
	button.refresh()
	_expect(button._token_pill.visible and button._token_badge.text == "3",
		"three tokens show '3' on the badge")
	_expect(button._badge_atlas.region.position.x == 24.0,
		"the lit badge frame shows while a free spin is ready")
	_service.wheel.tokens = 0
	button.refresh()
	_expect(not button._token_pill.visible, "zero tokens hides the badge")
	_service.wheel.next_free_unix = Time.get_unix_time_from_system() + 100000.0
	button.refresh()
	_expect(button._badge_atlas.region.position.x == 0.0,
		"the plain badge frame shows when no free spin is waiting")
	button.queue_free()
	await get_tree().process_frame
	GameState.from_save(saved)
	_done("button_badge")
