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
	## The deal: the contraband count follows the level, every cell holds what
	## its kind says, and nothing leaves the cargo space.
	for s in 40:
		var scan := XrayScan.new()
		var level := s % 8
		scan.setup(s * 31 + 7, level)
		_expect(scan.total() == XrayScan.contraband_for(level),
			"contraband count follows the level (seed %d)" % s)
		var kinds := {}
		for cell: Dictionary in scan.cells:
			kinds[int(cell.cell)] = cell.kind
		_expect(scan.cells.size() == XrayScan.CELLS, "every cell is dealt")
		var empty := 0
		for cell: Dictionary in scan.cells:
			if cell.kind == &"empty":
				empty += 1
		_expect(empty == 1, "one gap in the box (seed %d)" % s)
		var used := {}
		for item: Dictionary in scan.items:
			var pos: Vector2 = item.pos
			_expect(pos.x > 0.0 and pos.x < 1.0 and pos.y > 0.0 and pos.y < 1.0,
				"item inside the scan (seed %d)" % s)
			_expect(XrayScan.ITEMS[int(item.frame)].id == item.id,
				"frame index matches the item table")
			_expect(not used.has(int(item.cell)), "one thing per cell (seed %d)" % s)
			used[int(item.cell)] = true
			var kind: StringName = kinds[int(item.cell)]
			_expect((item.behind == &"block") == (kind == &"block"),
				"a thing behind machinery sits in a machinery cell (seed %d)" % s)
			_expect(kind != &"empty", "nothing in the gap (seed %d)" % s)
	_done("one_contraband")


func _test_every_scan_is_winnable() -> void:
	## Each contraband shows in exactly one view, and a tap dead on it in that
	## view seizes it: no inspection can only be lost. The raw view seizes
	## nothing and costs nothing.
	for s in 40:
		var scan := XrayScan.new()
		scan.setup(s * 977 + 3, 6)
		var raw := scan.tap(scan.contraband().pos, XrayScan.Filter.RAW)
		_expect(bool(raw.raw) and float(raw.penalty) == 0.0,
			"a raw tap only asks for a filter (seed %d)" % s)
		for target: Dictionary in scan.contrabands():
			var view := XrayScan.filter_for(target)
			var shown := 0
			for f: XrayScan.Filter in [XrayScan.Filter.RAW, XrayScan.Filter.METAL,
					XrayScan.Filter.ORGANIC, XrayScan.Filter.DENSE]:
				if XrayScan.shows(target, f):
					shown += 1
			_expect(shown == 1, "a contraband shows in one view only (seed %d)" % s)
			_expect(scan.item_at(target.pos, view).get("id") == target.id,
				"it is the nearest thing at its own centre in its view (seed %d)" % s)
			var result := scan.tap(target.pos, view)
			_expect(bool(result.hit), "tapping it in its view seizes it (seed %d)" % s)
		_expect(scan.over and scan.victory and scan.mistakes == 0,
			"seizing them all wins (seed %d)" % s)
	_done("winnable")


func _test_wrong_tap_costs_once() -> void:
	var scan := XrayScan.new()
	scan.setup(99, 0)
	var legal: Dictionary = {}
	for item: Dictionary in scan.items:
		if not bool(item.contraband) and item.behind == &"carton":
			legal = item
			break
	var view := XrayScan.filter_for(legal)
	var before := scan.time_left
	var first := scan.tap(legal.pos, view)
	_expect(not bool(first.hit), "an ordinary item is not the find")
	_expect(is_equal_approx(scan.time_left, before - XrayScan.WRONG_PENALTY),
		"a wrong tap costs the penalty")
	scan.tap(legal.pos, view)
	_expect(is_equal_approx(scan.time_left, before - XrayScan.WRONG_PENALTY),
		"the same wrong spot costs only once")
	_expect(scan.mistakes == 1, "one mistake counted")
	# The contraband, in a view that does not show it, is not seized.
	var target := scan.contraband()
	var wrong_view := XrayScan.Filter.DENSE if XrayScan.filter_for(target) \
		!= XrayScan.Filter.DENSE else XrayScan.Filter.METAL
	var blind := scan.tap(target.pos, wrong_view)
	_expect(not bool(blind.hit) and not bool(target.seized),
		"a contraband the view does not show cannot be seized")
	_expect(not scan.over, "misses do not end the round")
	_done("wrong_tap")


func _test_timeout_loses() -> void:
	var scan := XrayScan.new()
	scan.setup(5, 0)
	scan.advance(XrayScan.seconds_for(0) + 1.0)
	_expect(scan.over and not scan.victory, "the clock running out is a loss")
	var target := scan.contraband()
	var after := scan.tap(target.pos, XrayScan.filter_for(target))
	_expect(not bool(after.hit) and not scan.victory, "a tap after time is ignored")
	_done("timeout")


func _test_difficulty_curve() -> void:
	_expect(XrayScan.seconds_for(0) == XrayScan.BASE_SECONDS, "level 0 gets the full clock")
	_expect(XrayScan.seconds_for(99) >= XrayScan.MIN_SECONDS, "the clock floors")
	_expect(XrayScan.contraband_for(0) == 1 and XrayScan.contraband_for(99) == 3,
		"one contraband at first, three at most")
	for s in 30:
		var scan := XrayScan.new()
		scan.setup(s + 1, 0)
		for item: Dictionary in scan.items:
			_expect(not bool(XrayScan.ITEMS[int(item.frame)].get("decoy", false)),
				"no decoys on a first inspection")
			if bool(item.contraband):
				_expect(item.behind == &"carton",
					"the first inspection hides it in a carton (a colour view)")
		var level1 := XrayScan.new()
		level1.setup(s + 1, XrayScan.BLOCK_LEVEL)
		_expect(level1.contraband().behind == &"block",
			"the second inspection hides it behind machinery (RAIO+)")
	var saw_decoy := false
	var saw_each := {}
	for s in 60:
		var scan := XrayScan.new()
		scan.setup(s + 1, XrayScan.DECOY_LEVEL + 3)
		for item: Dictionary in scan.items:
			saw_decoy = saw_decoy or bool(XrayScan.ITEMS[int(item.frame)].get("decoy", false))
			if bool(item.contraband):
				saw_each[XrayScan.filter_for(item)] = true
	_expect(saw_decoy, "decoys appear once the player is experienced")
	_expect(saw_each.size() == 3, "later scans need every view")
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
	# The abandoned post comes with the second parcel: no ground, no repair.
	_expect(not service.buy(), "nothing to repair before the parcel is paved")
	_expect(is_equal_approx(GameState.teus, 1.0e6), "and nothing is charged for it")
	GameState.land[LandDB.SCANNER_PARCEL] = true
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
	_expect(guide.tip("receita", "receita.tip.intro", "", &"receita"), "Leôncio can take a tip")
	_expect(guide.speaker() == &"receita", "the speaker is Leôncio")
	_expect(guide._walker_atlas.atlas == TutorialSpotlight.CUSTOMS_BODY, "she walks in her own sprite")
	_expect(guide._name.text == "LEÔNCIO", "his name on the plate")
	_expect(guide._role.text == Loc.t("receita.role"), "his role on the plate")
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


func _spread(img: Image, centre: Vector2i) -> float:
	## The widest brightness difference round a point: how much is drawn there.
	var lo := 1.0
	var hi := 0.0
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var lum := img.get_pixelv(centre + Vector2i(dx, dy)).get_luminance()
			lo = minf(lo, lum)
			hi = maxf(hi, lum)
	return hi - lo


func _test_board_plays_a_scan() -> void:
	var board := XrayMinigame.new()
	add_child(board)
	await get_tree().process_frame
	var results: Array = []
	board.finished.connect(func(won: bool, summary: Dictionary) -> void:
		results.append([won, summary]))
	board.open({"title": "test", "seed": 4321, "level": 0, "scan_no": 3})
	for i in 4:
		await get_tree().process_frame
	_expect(board.is_open() and board.game != null, "the board opened with a scan")
	_expect(board.phase == XrayMinigame.Phase.ROLL, "it opens on the lorry driving in")
	var clock := board.game.time_left
	board._tick(0.5)
	_expect(board.game.time_left == clock, "the clock does not run during the intro")
	board._set_phase(XrayMinigame.Phase.SCAN)
	board._img_rect = Rect2(Vector2(10, 10), Vector2(XrayMinigame.IMG) * 1.5)
	var target: Dictionary = board.game.contraband()
	# Four pictures of one lorry. The raw one shows the carton, not what is in
	# it; the view that shows the contraband paints it plainly.
	var view := XrayScan.filter_for(target)
	var raw: Image = board._tex[XrayScan.Filter.RAW].get_image()
	var shown: Image = board._tex[view].get_image()
	_expect(raw.get_size() == XrayMinigame.IMG, "the scan image is pixel-sized")
	var centre := Vector2i(XrayMinigame.INNER.position
		+ (target.pos as Vector2) * XrayMinigame.INNER.size)
	var raw_spread := _spread(raw, centre)
	var view_spread := _spread(shown, centre)
	_expect(raw_spread < 0.12, "the raw view hides the contraband (%.2f)" % raw_spread)
	_expect(view_spread > 0.3, "its own view paints it plainly (%.2f)" % view_spread)
	board._seize_at(board._to_screen(target.pos))
	_expect(not board.game.victory and board.game.mistakes == 0,
		"a tap in the raw view seizes nothing and costs nothing")
	var legal: Dictionary = {}
	for item: Dictionary in board.game.items:
		if not bool(item.contraband) and item.behind == &"carton":
			legal = item
	board._pick_filter(XrayScan.filter_for(legal))
	board._seize_at(board._to_screen(legal.pos))
	_expect(board.game.mistakes == 1 and not board.game.over,
		"tapping an ordinary thing costs a mistake")
	board._pick_filter(view)
	_expect(board.filter == view, "the bar switches the view")
	board._seize_at(board._to_screen(target.pos))
	_expect(board.game.victory, "tapping the contraband in its view wins")
	var deadline := Time.get_ticks_msec() + 4000
	while results.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_expect(results.size() == 1 and bool(results[0][0]), "the board reports a win")
	_expect(not board.is_open(), "and closes")
	board.queue_free()
	await get_tree().process_frame
	_done("board")
