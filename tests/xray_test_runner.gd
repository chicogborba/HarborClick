extends Node
## The Receita Federal's X-ray scanner: the scan rules (`XrayScan`), the
## purchase/clock/benefit rules and their save section (`XrayPolicy`,
## `XrayService`), the board that plays a scan, and the guide's speakers.
## Run with:
## Godot --headless --path . res://tests/xray_test_runner.tscn
##
## Every test names itself as its last statement; the roll call at the end
## turns a test that died part-way (a GDScript error does not raise) into a
## failure with its own name on it. See `gull_test_runner.gd`.

const TEST_SAVE_PATH := "user://harborclick_xray_test.json"

const EXPECTED := [
	"deterministic", "one_contraband", "winnable", "wrong_tap", "timeout",
	"difficulty", "price", "clock", "benefit", "persist", "garbage",
	"reload", "speakers", "board",
]

var failures: Array[String] = []
var _finished: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	GameState.from_save({})

	_test_same_seed_same_scan()
	_test_exactly_one_contraband()
	_test_every_scan_is_winnable()
	_test_wrong_tap_costs_once()
	_test_timeout_loses()
	_test_difficulty_curve()
	_test_price()
	_test_clock()
	_test_benefit()
	_test_snapshot_roundtrip()
	_test_restore_garbage()
	await _test_reload_keeps_scanner()
	await _test_speakers()
	await _test_board_plays_a_scan()

	for label in EXPECTED:
		_expect(_finished.has(label), "the '%s' test ran to the end" % label)
	SaveManager._sections.clear()
	SaveManager.wipe()
	if failures.is_empty():
		print("XRAY TESTS PASSED (%d tests)" % EXPECTED.size())
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("XRAY TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _done(label: String) -> void:
	_finished[label] = true


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


# ------------------------------------------------------------------- scan

func _test_same_seed_same_scan() -> void:
	var a := XrayScan.new()
	var b := XrayScan.new()
	a.setup(1234, 3)
	b.setup(1234, 3)
	_expect(a.items.size() == b.items.size(), "same seed, same item count")
	for i in a.items.size():
		_expect(a.items[i].id == b.items[i].id and a.items[i].pos == b.items[i].pos,
			"same seed, same item %d" % i)
	var c := XrayScan.new()
	c.setup(1235, 3)
	var differs := false
	for i in mini(a.items.size(), c.items.size()):
		differs = differs or a.items[i].pos != c.items[i].pos
	_expect(differs, "another seed deals another scan")
	_done("deterministic")


func _test_exactly_one_contraband() -> void:
	for s in 40:
		var scan := XrayScan.new()
		scan.setup(s * 31 + 7, s % 8)
		var count := 0
		for item: Dictionary in scan.items:
			if bool(item.contraband):
				count += 1
			var pos: Vector2 = item.pos
			_expect(pos.x > 0.0 and pos.x < 1.0 and pos.y > 0.0 and pos.y < 1.0,
				"item inside the scan (seed %d)" % s)
			_expect(XrayScan.ITEMS[int(item.frame)].id == item.id,
				"frame index matches the item table")
		_expect(count == 1, "exactly one contraband (seed %d)" % s)
		_expect(scan.items.size() == XrayScan.goods_for(s % 8) + 1,
			"goods count follows the level (seed %d)" % s)
	_done("one_contraband")


func _test_every_scan_is_winnable() -> void:
	## A tap dead on the contraband always finds the contraband — no ordinary
	## item sits close enough to steal it — so no inspection can only be lost.
	for s in 40:
		var scan := XrayScan.new()
		scan.setup(s * 977 + 3, 6)
		var target := scan.contraband()
		_expect(scan.item_at(target.pos).get("id") == target.id,
			"contraband is the nearest item at its own centre (seed %d)" % s)
		for item: Dictionary in scan.items:
			if item == target:
				continue
			var d := (((item.pos as Vector2) - (target.pos as Vector2))
				* Vector2(XrayScan.COLS, XrayScan.ROWS)).length()
			_expect(d > XrayScan.HIT_RADIUS, "no item overlaps the contraband (seed %d)" % s)
		var result := scan.tap(target.pos)
		_expect(bool(result.hit) and scan.over and scan.victory, "tapping it wins (seed %d)" % s)
	_done("winnable")


func _test_wrong_tap_costs_once() -> void:
	var scan := XrayScan.new()
	scan.setup(99, 0)
	var legal: Dictionary = {}
	for item: Dictionary in scan.items:
		if not bool(item.contraband):
			legal = item
			break
	var before := scan.time_left
	var first := scan.tap(legal.pos)
	_expect(not bool(first.hit), "an ordinary item is not the find")
	_expect(is_equal_approx(scan.time_left, before - XrayScan.WRONG_PENALTY),
		"a wrong tap costs the penalty")
	scan.tap(legal.pos)
	_expect(is_equal_approx(scan.time_left, before - XrayScan.WRONG_PENALTY),
		"the same wrong spot costs only once")
	_expect(scan.mistakes == 1, "one mistake counted")
	_expect(not scan.over, "two misses do not end the round")
	_done("wrong_tap")


func _test_timeout_loses() -> void:
	var scan := XrayScan.new()
	scan.setup(5, 0)
	scan.advance(XrayScan.BASE_SECONDS + 1.0)
	_expect(scan.over and not scan.victory, "the clock running out is a loss")
	var after := scan.tap(scan.contraband().pos)
	_expect(not bool(after.hit) and not scan.victory, "a tap after time is ignored")
	_done("timeout")


func _test_difficulty_curve() -> void:
	_expect(XrayScan.seconds_for(0) == XrayScan.BASE_SECONDS, "level 0 gets the full clock")
	_expect(XrayScan.seconds_for(99) == XrayScan.MIN_SECONDS, "the clock floors")
	_expect(XrayScan.goods_for(99) == XrayScan.MAX_GOODS, "the goods cap")
	for s in 30:
		var scan := XrayScan.new()
		scan.setup(s + 1, 0)
		for item: Dictionary in scan.items:
			_expect(not bool(XrayScan.ITEMS[int(item.frame)].get("decoy", false)),
				"no decoys on a first inspection")
	var saw_decoy := false
	for s in 60:
		var scan := XrayScan.new()
		scan.setup(s + 1, XrayScan.DECOY_LEVEL + 3)
		for item: Dictionary in scan.items:
			saw_decoy = saw_decoy or bool(XrayScan.ITEMS[int(item.frame)].get("decoy", false))
	_expect(saw_decoy, "decoys appear once the player is experienced")
	_done("difficulty")


# ----------------------------------------------------------------- policy

func _test_price() -> void:
	var policy := XrayPolicy.new()
	_expect(policy.price(0.0) == XrayPolicy.MIN_PRICE, "an empty port pays the floor")
	_expect(is_equal_approx(policy.price(10.0), 10.0 * XrayPolicy.PRICE_SECONDS),
		"priced in the port's own income")
	_expect(policy.buy(), "first purchase books")
	_expect(not policy.buy(), "a second purchase is refused")
	_done("price")


func _test_clock() -> void:
	var policy := XrayPolicy.new()
	var rng := _rng(7)
	_expect(not policy.tick(9999.0, true, rng), "no inspections before the scanner is bought")
	policy.buy()
	_expect(not policy.tick(XrayPolicy.FIRST_DELAY - 1.0, true, rng), "not before the first delay")
	_expect(not policy.tick(100.0, false, rng), "the clock stands still while blocked")
	_expect(policy.tick(2.0, true, rng) and policy.ready, "due after the first delay")
	_expect(not policy.tick(9999.0, true, rng), "a due inspection waits, it does not stack")
	_expect(policy.until_next >= XrayPolicy.MIN_GAP and policy.until_next <= XrayPolicy.MAX_GAP,
		"next gap within bounds")
	_done("clock")


func _test_benefit() -> void:
	var policy := XrayPolicy.new()
	_expect(policy.resolve(true, 0).is_empty(), "nothing pays when nothing was due")
	policy.buy()
	policy.ready = true
	var seed_before := policy.scan_seed()
	_expect(policy.scan_seed() == seed_before, "the seed holds until resolved")
	var clean := policy.resolve(true, 0)
	_expect(StringName(clean.kind) == &"surge" and float(clean.mult) == XrayPolicy.CLEAN_MULT,
		"a clean scan pays the bigger surge")
	_expect(not policy.ready and policy.played == 1 and policy.won == 1, "booked as played and won")
	_expect(policy.scan_seed() != seed_before, "the next inspection is another scan")
	policy.ready = true
	_expect(float(policy.resolve(true, 2).mult) == XrayPolicy.BENEFIT_MULT,
		"a scan with misses pays the normal surge")
	policy.ready = true
	_expect(policy.resolve(false, 0).is_empty(), "a loss pays nothing")
	_expect(policy.streak == 0 and policy.best_streak == 2, "a loss ends the streak, keeps the best")
	_expect(policy.level() == 2, "difficulty follows inspections won")
	_done("benefit")


func _test_snapshot_roundtrip() -> void:
	var policy := XrayPolicy.new()
	policy.buy()
	policy.ready = true
	policy.played = 5
	policy.won = 3
	policy.streak = 2
	policy.best_streak = 3
	policy.until_next = 123.0
	var copy := XrayPolicy.new()
	copy.restore(policy.snapshot())
	_expect(copy.snapshot() == policy.snapshot(), "snapshot survives a restore")
	var fresh := XrayPolicy.new()
	fresh.restore(XrayPolicy.seed_new())
	_expect(not fresh.owned and not fresh.ready and fresh.played == 0,
		"a new profile has no scanner")
	_done("persist")


func _test_restore_garbage() -> void:
	var policy := XrayPolicy.new()
	policy.restore({"owned": "yes", "until_next": "soon", "ready": true,
		"played": -4, "won": 99, "streak": "x"})
	_expect(not policy.owned, "a non-bool owned is not ownership")
	_expect(not policy.ready, "nothing is due on a scanner nobody owns")
	_expect(policy.played == 0 and policy.won == 0, "counters clamp")
	_expect(policy.until_next == XrayPolicy.FIRST_DELAY, "a garbage clock reads as the default")
	_done("garbage")


func _test_reload_keeps_scanner() -> void:
	## The section through SaveManager: buy, save, drop the node, register a new
	## one — it comes back owned with the same inspection still due.
	GameState.teus = 1.0e6
	var service := XrayService.new()
	add_child(service)
	_expect(not service.owned(), "seeded without a scanner")
	_expect(service.buy(), "bought with enough TEU")
	_expect(GameState.teus < 1.0e6, "the scanner was paid for")
	service.policy.ready = true
	service.policy.won = 2
	service.policy.played = 2
	_expect(SaveManager.save_game(&"test"), "saved")
	service.queue_free()
	await get_tree().process_frame
	var again := XrayService.new()
	add_child(again)
	_expect(again.owned() and again.is_due() and again.policy.won == 2,
		"reload restores the scanner and the due inspection")
	again.queue_free()
	await get_tree().process_frame
	_done("reload")


# ------------------------------------------------------------ presentation

func _test_speakers() -> void:
	var guide := TutorialSpotlight.new()
	add_child(guide)
	await get_tree().process_frame
	_expect(not guide.tip("x", "receita.tip.intro", "", &"nobody"), "an unknown speaker is refused")
	_expect(guide.tip("receita", "receita.tip.intro", "", &"receita"), "Neide can take a tip")
	_expect(guide.speaker() == &"receita", "the speaker is Neide")
	_expect(guide._walker_atlas.atlas == TutorialSpotlight.CUSTOMS_BODY, "she walks in her own sprite")
	_expect(guide._name.text == "NEIDE", "her name on the plate")
	_expect(guide._role.text == Loc.t("receita.role"), "her role on the plate")
	var closed: Array[String] = []
	guide.tip_closed.connect(func(id: String) -> void: closed.append(id))
	guide.dismiss_tip()
	_expect(not guide.tip_active() and closed == ["receita"], "dismiss closes at once and says so")
	_expect(guide.tip("land", "guide.tip.land"), "Alisson takes the next one")
	_expect(guide.speaker() == &"alisson" and guide._walker_atlas.atlas == TutorialSpotlight.BODY,
		"and it is Alisson again")
	guide.queue_free()
	await get_tree().process_frame
	_done("speakers")


func _test_board_plays_a_scan() -> void:
	var board := XrayMinigame.new()
	add_child(board)
	await get_tree().process_frame
	var results: Array = []
	board.finished.connect(func(won: bool, summary: Dictionary) -> void:
		results.append([won, summary]))
	board.open({"title": "test", "seed": 4321, "level": 1, "scan_no": 3})
	for i in 4:
		await get_tree().process_frame
	_expect(board.is_open() and board.game != null, "the board opened with a scan")
	_expect(board.phase == XrayMinigame.Phase.ROLL, "it opens on the container rolling in")
	var clock := board.game.time_left
	board._tick(0.5)
	_expect(board.game.time_left == clock, "the clock does not run during the intro")
	board._set_phase(XrayMinigame.Phase.SCAN)
	board._img_rect = Rect2(Vector2(10, 10), Vector2(XrayMinigame.IMG) * 1.5)
	var target: Dictionary = board.game.contraband()
	# The loupe reveals it: through one of the two filters, the pixels where it
	# lies are its own false colour, not the ghost of the bales.
	var revealed := 0
	var centre := XrayMinigame.INNER.position + (target.pos as Vector2) * XrayMinigame.INNER.size
	for layer: ImageTexture in board._filter_tex:
		var img := layer.get_image()
		for dy in range(-6, 7):
			for dx in range(-6, 7):
				var c := img.get_pixelv(Vector2i(centre) + Vector2i(dx, dy))
				if absf(c.r - c.b) > 0.25:
					revealed += 1
	_expect(revealed > 6, "the contraband shows through the loupe's filters")
	_expect(board._base_tex.get_image().get_size() == XrayMinigame.IMG, "the scan image is pixel-sized")
	var legal: Dictionary = {}
	for item: Dictionary in board.game.items:
		if not bool(item.contraband):
			legal = item
	board._move_lens(board._to_screen(legal.pos))
	board._on_seize()
	_expect(board.game.mistakes == 1 and not board.game.over, "seizing an ordinary item costs a mistake")
	board._move_lens(board._to_screen(target.pos))
	_expect(board._to_norm(board._lens_centre()).distance_to(target.pos) < 0.01,
		"screen and rule coordinates round-trip")
	board._on_seize()
	_expect(board.game.victory, "seizing the contraband under the crosshair wins")
	var deadline := Time.get_ticks_msec() + 4000
	while results.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_expect(results.size() == 1 and bool(results[0][0]), "the board reports a win")
	_expect(not board.is_open(), "and closes")
	board.queue_free()
	await get_tree().process_frame
	_done("board")
