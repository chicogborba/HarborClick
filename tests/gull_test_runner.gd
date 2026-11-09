extends Node
## The gaivota dourada: the reward clock's rules, the prize table, the gull's
## flight/hit/catch presentation, and the token grant that pays one prize.
## Run with:
## Godot --headless --path . res://tests/gull_test_runner.tscn
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

const TEST_SAVE_PATH := "user://harborclick_gull_test.json"

const EXPECTED := [
	"first_delay", "blocked_clock", "gaps", "weights", "cash_floor",
	"flight", "hit_test", "token_cap",
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
	seed(4242)

	_test_first_gull_not_before_first_delay()
	_test_no_countdown_while_blocked()
	_test_every_gap_within_bounds()
	_test_weights_follow_the_table()
	_test_cash_floor()
	_test_flight_escapes_once_and_ends_at_to()
	_test_hit_test()
	_test_grant_token_caps_at_max()

	for label in EXPECTED:
		_expect(_finished.has(label), "the '%s' test ran to the end" % label)

	if _service != null:
		_service.queue_free()
		_service = null
		await get_tree().process_frame
	SaveManager._sections.clear()
	SaveManager.wipe()
	if failures.is_empty():
		print("GULL TESTS PASSED (%d tests: first delay, blocked clock, gaps, "
			% EXPECTED.size()
			+ "weights, cash floor, flight escape, hit test, token cap)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("GULL TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _done(label: String) -> void:
	## The last statement of every test. See `EXPECTED`.
	_finished[label] = true


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# ------------------------------------------------------------- the policy

func _test_first_gull_not_before_first_delay() -> void:
	var policy := GoldenGullPolicy.new()
	var rng := _seeded_rng(99)
	_expect(policy.until_next == GoldenGullPolicy.FIRST_DELAY,
		"a fresh policy is armed at FIRST_DELAY")
	_expect(not policy.tick(GoldenGullPolicy.FIRST_DELAY - 0.01, true, rng),
		"no gull before FIRST_DELAY")
	_expect(is_equal_approx(policy.until_next, 0.01), "and the clock counted down")
	_expect(policy.tick(0.02, true, rng), "one gull exactly when it reaches zero")
	_done("first_delay")


func _test_no_countdown_while_blocked() -> void:
	var policy := GoldenGullPolicy.new()
	var rng := _seeded_rng(5)
	_expect(not policy.tick(1000.0, false, rng), "no spawn while can_spawn is false")
	_expect(policy.until_next == GoldenGullPolicy.FIRST_DELAY,
		"the clock did not move at all (%s)" % str(policy.until_next))
	_expect(not policy.tick(0.0, false, rng), "not even on a zero delta")
	_done("blocked_clock")


func _test_every_gap_within_bounds() -> void:
	var policy := GoldenGullPolicy.new()
	var rng := _seeded_rng(1234)
	for i in 200:
		var guard := 0
		while not policy.tick(0.5, true, rng):
			guard += 1
			if guard > 100000:
				break
		_expect(guard <= 100000, "re-arm %d eventually fires" % i)
		_expect(policy.until_next >= GoldenGullPolicy.MIN_GAP
			and policy.until_next <= GoldenGullPolicy.MAX_GAP,
			"re-arm %d is %.2f, inside [%.0f, %.0f]"
			% [i, policy.until_next, GoldenGullPolicy.MIN_GAP, GoldenGullPolicy.MAX_GAP])
	_done("gaps")


func _test_weights_follow_the_table() -> void:
	## 20000 seeded rolls: every prize lands within 1.5 percentage points of its
	## weight. The weights sum to 100, so a weight is the expected share.
	var policy := GoldenGullPolicy.new()
	var rng := _seeded_rng(20260215)
	var counts := {}
	for prize in GoldenGullPolicy.PRIZES:
		counts[StringName(prize.id)] = 0
	for n in 20000:
		var prize := policy.roll(rng)
		counts[StringName(prize.get("id", &""))] += 1
	for prize in GoldenGullPolicy.PRIZES:
		var share := 100.0 * float(counts[StringName(prize.id)]) / 20000.0
		_expect(absf(share - float(prize.weight)) <= 1.5,
			"%s landed %.2f%% of the rolls, expected %.2f%%"
			% [str(prize.id), share, float(prize.weight)])
	# roll returns a duplicate: mutating the result must not corrupt the table.
	var rolled := policy.roll(rng)
	rolled["weight"] = 9999
	rolled["id"] = &"hacked"
	_expect(StringName(GoldenGullPolicy.PRIZES[0].id) == &"lucky"
		and int(GoldenGullPolicy.PRIZES[0].weight) == 60,
		"roll returns a duplicate of the prize")
	_done("weights")


func _test_cash_floor() -> void:
	var policy := GoldenGullPolicy.new()
	var cash: Dictionary = GoldenGullPolicy.PRIZES[0]
	_expect(is_equal_approx(policy.cash_amount(cash, 0.0),
		GoldenGullPolicy.MIN_PRIZE_CPS * float(cash.seconds)),
		"an empty port still pays the floor")
	_expect(is_equal_approx(policy.cash_amount(cash, 2.0), 2.0 * float(cash.seconds)),
		"cash pays base cps x seconds above the floor")
	var surge: Dictionary = GoldenGullPolicy.PRIZES[1]
	_expect(policy.cash_amount(surge, 5.0) == 0.0, "a surge has no cash amount")
	var token: Dictionary = GoldenGullPolicy.PRIZES[2]
	_expect(policy.cash_amount(token, 5.0) == 0.0, "a token has no cash amount")
	_done("cash_floor")


# ---------------------------------------------------------- the gull node

func _test_flight_escapes_once_and_ends_at_to() -> void:
	var gull := GoldenGull.new()
	var from := Vector2(-24.0, 100.0)
	var to := Vector2(344.0, 100.0)
	gull.setup(from, to, GoldenGullPolicy.FLIGHT_SECONDS)
	var escaped_count := [0]
	gull.escaped.connect(func() -> void: escaped_count[0] += 1)
	# Drive the node by hand for the whole flight plus a half second of slack.
	var steps := int((GoldenGullPolicy.FLIGHT_SECONDS + 0.5) / 0.05) + 2
	for i in steps:
		gull._process(0.05)
	_expect(escaped_count[0] == 1,
		"escaped emitted exactly once (%d)" % escaped_count[0])
	_expect(gull.position == to,
		"the gull ends at `to` (position %s, expected %s)"
		% [str(gull.position), str(to)])
	_done("flight")


func _test_hit_test() -> void:
	var gull := GoldenGull.new()
	gull.setup(Vector2(0.0, 50.0), Vector2(320.0, 50.0), GoldenGullPolicy.FLIGHT_SECONDS)
	gull._process(0.1)
	var centre := gull.position
	_expect(gull.hit_test(centre), "hit_test is true at the centre")
	_expect(gull.hit_test(centre + Vector2(17.0, 0.0)),
		"true just inside the 18px radius")
	_expect(not gull.hit_test(centre + Vector2(30.0, 0.0)),
		"false 30px away")
	var escaped_count := [0]
	gull.escaped.connect(func() -> void: escaped_count[0] += 1)
	gull.catch()
	_expect(not gull.hit_test(centre), "false after catch()")
	gull._process(1.0)
	_expect(escaped_count[0] == 0, "a caught gull never emits escaped")
	_expect(not gull.hit_test(centre), "and stays unhittable")
	_done("hit_test")


# ------------------------------------------------------------- the payout

func _test_grant_token_caps_at_max() -> void:
	_service = WheelService.new()
	add_child(_service) # _ready registers the section and seeds the wheel
	_expect(SaveManager._sections.has("lucky_wheel"),
		"the service registers the lucky_wheel section")
	_service.wheel.tokens = LuckyWheel.MAX_TOKENS - 1
	var earned := [0]
	var changed := [0]
	_service.token_earned.connect(func() -> void: earned[0] += 1)
	_service.state_changed.connect(func() -> void: changed[0] += 1)
	_service.grant_token(5)
	_expect(_service.wheel.tokens == LuckyWheel.MAX_TOKENS,
		"grant_token caps at MAX_TOKENS (%d)" % _service.wheel.tokens)
	_expect(earned[0] == 1, "token_earned fired for the token that landed")
	_expect(changed[0] == 1, "and state_changed fired")
	_service.grant_token(1)
	_expect(_service.wheel.tokens == LuckyWheel.MAX_TOKENS, "still capped")
	_expect(earned[0] == 1, "no token_earned when the rack is full")
	_expect(changed[0] == 2, "but state_changed fires on every grant")
	_service.wheel.tokens = 2
	_service.grant_token()
	_expect(_service.wheel.tokens == 3, "the default grant is one token")
	_done("token_cap")
