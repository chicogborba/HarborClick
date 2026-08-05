extends Node
## Rare charters and the minigame that decides them.
## Run with:
## Godot --headless --path . res://tests/special_test_runner.tscn
##
## Three things here cannot be judged by looking at the game:
##
## 1. **Rarity.** A charter offered twice a minute is not an event. The director's
##    clock, its refusal path and its expiry are all here.
## 2. **The stake is real and bounded.** A prize is seconds of the port's own
##    income, a forfeit never pushes the wallet below zero, and neither survives a
##    reload as a banked multiplier.
## 3. **The minigame is winnable and losable.** The rules are pure, so the suite
##    plays a perfect game, a hopeless one and one that runs out of clock.

const TEST_SAVE_PATH := "user://harborclick_special_test.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests(TEST_SAVE_PATH)
	SaveManager.wipe()
	GameState.from_save({})
	seed(30072026)

	_test_the_catalogue_is_priced_in_the_port_s_own_income()
	_test_a_charter_is_rare_refusable_and_expires()
	_test_an_accepted_charter_arrives_on_a_hull_nobody_can_roll()
	_test_the_prize_and_the_forfeit_are_bounded()
	_test_the_stack_game_can_be_won()
	_test_the_stack_game_can_be_lost()
	_test_the_maze_is_always_solvable()
	_test_the_maze_can_be_won_and_lost()
	_test_a_reload_keeps_the_charter_but_not_the_burst()

	SaveManager._sections.clear()
	SaveManager.wipe()
	if failures.is_empty():
		print("SPECIAL CALL TESTS PASSED")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("SPECIAL CALL TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


# ------------------------------------------------------------------ catalogue

func _test_the_catalogue_is_priced_in_the_port_s_own_income() -> void:
	_expect(SpecialCallDB.is_valid(), "the charter catalogue is a valid blueprint")
	for offer: Dictionary in SpecialCallDB.OFFERS:
		_expect(str(offer.brief).length() > 40,
			"%s explains itself before asking for an answer" % offer.id)
		_expect(not SpecialCallDB.reward_text(offer).is_empty()
				and SpecialCallDB.penalty_text(offer) != "nenhuma",
			"%s names both the prize and the forfeit" % offer.id)
		var hull := ShipCatalog.get_silhouette(StringName(offer.hull))
		_expect(not hull.is_empty(), "%s sails on a real class" % offer.id)

	# Deterministic per career: an event that rerolls on reload is an event worth
	# reloading for.
	var first := SpecialCallDB.materialize(9911, 0)
	_expect(str(first.id) == str(SpecialCallDB.materialize(9911, 0).id),
		"the same career offers the same charter in the same slot")
	var seen := {}
	for index in 24:
		seen[str(SpecialCallDB.materialize(9911, index).id)] = true
	_expect(seen.size() >= 3,
		"a career sees a spread of charters, not one on repeat (%d)" % seen.size())


func _test_a_charter_is_rare_refusable_and_expires() -> void:
	var director := SpecialCallDirector.new()
	director.setup(null)
	director.seed_new()
	GameState.all_time_teus = 0.0
	var offers: Array[Dictionary] = []
	director.offer_ready.connect(func(offer: Dictionary) -> void: offers.append(offer))

	# A port with nothing behind it has nothing to stake.
	for step in 6000:
		director.tick(1.0 / 30.0)
	_expect(offers.is_empty(),
		"no charter is offered before the terminal is worth one")

	GameState.all_time_teus = 1e6
	var elapsed := 0.0
	while offers.is_empty() and elapsed < 1200.0:
		director.tick(1.0 / 30.0)
		elapsed += 1.0 / 30.0
	_expect(offers.size() == 1, "exactly one charter is on the table at a time")
	_expect(elapsed > 10.0,
		"a charter takes real time to turn up (%.0fs)" % elapsed)

	# Refusing is a first-class answer, and it puts the next one further away than
	# the moment it was refused.
	director.decline()
	_expect(director.offer.is_empty() and director.booked.is_empty(),
		"a refused charter leaves nothing behind")
	var after_decline := 0.0
	while offers.size() < 2 and after_decline < 600.0:
		director.tick(1.0 / 30.0)
		after_decline += 1.0 / 30.0
	_expect(after_decline >= SpecialCallDirector.DECLINE_COOLDOWN.x - 1.0,
		"a refusal still costs a cooldown (%.0fs)" % after_decline)

	# An unanswered charter expires on its own rather than sitting there for ever.
	var before := offers.size()
	for step in int(SpecialCallDirector.OFFER_TIMEOUT * 31.0):
		director.tick(1.0 / 30.0)
	_expect(director.offer.is_empty(),
		"an unanswered charter expires (%d offers seen)" % before)


func _test_an_accepted_charter_arrives_on_a_hull_nobody_can_roll() -> void:
	var director := SpecialCallDirector.new()
	director.setup(null)
	director.seed_new()
	director.offer = SpecialCallDB.materialize(551, 0)
	_expect(director.accept(), "a charter on the table can be accepted")
	_expect(not director.booked.is_empty() and director.offer.is_empty(),
		"accepting books it and clears the table")

	var variant := director.claim_variant(1)
	_expect(not variant.is_empty() and bool(variant.get("special", false)),
		"the booked charter hands the berth a special hull")
	_expect(str(variant.get("palette_id", "")) == str(ShipCatalog.SPECIAL_PALETTE.id),
		"that hull wears a livery outside the rolled pool")
	var rolled := {}
	for index in 40:
		rolled[str(ShipCatalog.select_variant(index * 7 + 1, index).get("palette_id", ""))] = true
	_expect(not rolled.has(str(ShipCatalog.SPECIAL_PALETTE.id)),
		"and no routine escala can ever wear it")
	_expect(director.is_special_berth(1) and not director.is_special_berth(0),
		"only the berth that took the charter is the special one")
	_expect(director.claim_variant(2).is_empty(),
		"a second berth cannot also claim the same charter")

	# The minigame is cued by the vessel berthing, not by the acceptance.
	var games: Array[Dictionary] = []
	director.minigame_requested.connect(
		func(offer: Dictionary) -> void: games.append(offer))
	director.notify_alongside(0)
	_expect(games.is_empty(), "another berth's arrival is not the charter's cue")
	director.notify_alongside(1)
	_expect(games.size() == 1, "the special vessel berthing opens the minigame")
	director.notify_alongside(1)
	_expect(games.size() == 1, "and it opens exactly once")

	# Resolving pays out, reports, and stands the director down.
	var results: Array = []
	director.resolved.connect(
		func(finished: Dictionary, won: bool, outcome: Dictionary) -> void:
			results.append([str(finished.id), won, outcome]))
	var outcome := director.resolve(true)
	_expect(not outcome.is_empty() and results.size() == 1 and bool(results[0][1]),
		"a won charter resolves once, with an outcome")
	_expect(director.active.is_empty() and director.active_berth < 0,
		"and the berth goes back to routine escalas")
	_expect(int(director.stats().played) == 1 and int(director.stats().won) == 1,
		"the run keeps a tally of charters worked")
	_expect(director.resolve(true).is_empty(),
		"a resolved charter cannot be resolved twice")
	GameState.surge_mult = 1.0
	GameState.surge_time = 0.0
	GameState.recompute()

	# A vessel that leaves unplayed pays nothing either way.
	director.offer = SpecialCallDB.materialize(551, 2)
	director.accept()
	director.claim_variant(0)
	var teus_before := GameState.teus
	director.abandon()
	_expect(director.active.is_empty() and is_equal_approx(GameState.teus, teus_before),
		"an abandoned charter neither pays nor fines")


func _test_the_prize_and_the_forfeit_are_bounded() -> void:
	GameState.from_save({})
	GameState.owned["estivador"] = 40
	GameState.recompute()
	GameState.teus = 1000.0
	var surge_offer := SpecialCallDB.get_offer(&"gala_relampago")
	var outcome := SpecialCallDB.apply_reward(surge_offer)
	_expect(GameState.surge_remaining() > 0.0 and GameState.surge_mult > 1.0,
		"a won charter multiplies the port's income")
	_expect(not str(outcome.get("text", "")).is_empty(),
		"and it says what it did")
	var boosted := GameState.cps
	GameState.surge_mult = 1.0
	GameState.surge_time = 0.0
	GameState.recompute()
	_expect(boosted > GameState.cps,
		"the burst really is on top of the base rate (%.2f vs %.2f)"
			% [boosted, GameState.cps])

	# The strongest burst wins rather than stacking into itself.
	GameState.grant_surge(10.0, 15.0)
	GameState.grant_surge(2.0, 5.0)
	_expect(is_equal_approx(GameState.surge_mult, 10.0),
		"a weaker burst cannot cut a stronger one short")
	GameState.surge_mult = 1.0
	GameState.surge_time = 0.0
	GameState.recompute()

	# A forfeit is paid out of the wallet and never into debt.
	GameState.teus = 50.0
	var fine := SpecialCallDB.apply_penalty(
		SpecialCallDB.get_offer(&"janela_de_mare"))
	_expect(GameState.teus >= 0.0,
		"a fine never pushes the wallet below zero (%.2f)" % GameState.teus)
	_expect(float(fine.get("amount", 0.0)) <= 50.0 + 0.001,
		"and it can only take what was there")
	var slump := SpecialCallDB.apply_penalty(
		SpecialCallDB.get_offer(&"carga_projeto"))
	_expect(GameState.surge_mult < 1.0 and GameState.surge_remaining() > 0.0,
		"a slump forfeit slows the port down instead of taking money")
	_expect(str(slump.get("kind", "")) == str(SpecialCallDB.PENALTY_SLUMP),
		"and it reports itself as one")
	GameState.surge_mult = 1.0
	GameState.surge_time = 0.0
	GameState.recompute()


# ------------------------------------------------------------------- minigame

func _test_the_stack_game_can_be_won() -> void:
	var game := StackGame.new()
	game.setup({"goal": 6, "seconds": 60.0})
	_expect(game.height() == 1 and game.placed == 0,
		"the game opens with one box on the ground")
	var perfects := 0
	while not game.over:
		# Play it perfectly: park the trolley over the top box and let go.
		game.trolley_x = game.top()
		var outcome := game.drop()
		if StringName(outcome.get("result", &"")) == StackGame.RESULT_PERFECT:
			perfects += 1
		game.advance(1.0 / 60.0)
	_expect(game.victory and game.placed == 6,
		"a perfect run wins the charter (%d placed)" % game.placed)
	_expect(perfects == 6, "every centred drop is called perfect (%d)" % perfects)
	_expect(is_zero_approx(game.lean()),
		"a plumb tower has no lean at all (%.3f)" % game.lean())
	_expect(game.best_combo == 6, "a perfect run keeps its combo (%d)" % game.best_combo)

	# An off-centre drop still lands, but it shifts the tower's centre of mass —
	# which is the whole game now, and what a tolerance check could never model.
	var lean := StackGame.new()
	lean.setup({"goal": 4, "seconds": 60.0})
	lean.trolley_x = lean.top() + StackGame.BOX_WIDTH * 0.4
	var landed := lean.drop()
	_expect(StringName(landed.get("result", &"")) == StackGame.RESULT_OK,
		"a drop inside the overlap holds")
	_expect(lean.lean() > 0.0,
		"and pushes the centre of mass the way you were off (%.3f)" % lean.lean())
	_expect(is_equal_approx(lean.centre_of_mass(),
			StackGame.BOX_WIDTH * 0.4 * 0.5),
		"the centre of mass is the mean of where the boxes landed")
	_expect(lean.speed > StackGame.START_SPEED,
		"the trolley speeds up with every box (%.0f)" % lean.speed)

	# Two errors the same way are worse than one error and one correction, which
	# is the property that makes this a balancing game rather than a timing one.
	var drift := StackGame.new()
	drift.setup({"goal": 20, "seconds": 600.0})
	var cancelled := StackGame.new()
	cancelled.setup({"goal": 20, "seconds": 600.0})
	for step in 3:
		drift.trolley_x = drift.top() + StackGame.BOX_WIDTH * 0.3
		drift.drop()
		cancelled.trolley_x = cancelled.top() \
			+ StackGame.BOX_WIDTH * 0.3 * (1.0 if step % 2 == 0 else -1.0)
		cancelled.drop()
	_expect(absf(drift.lean()) > absf(cancelled.lean()),
		"drifting one way beats being wrong both ways (%.2f vs %.2f)"
			% [drift.lean(), cancelled.lean()])


func _test_the_stack_game_can_be_lost() -> void:
	# A box with no overlap slides off the side. It costs no life — there are
	# none — and it does not join the tower, so nothing about the balance changes.
	var game := StackGame.new()
	game.setup({"goal": 8, "seconds": 60.0})
	for attempt in 3:
		game.trolley_x = game.top() + StackGame.WELL_WIDTH
		var outcome := game.drop()
		_expect(StringName(outcome.get("result", &"")) == StackGame.RESULT_SLIP,
			"a drop past the overlap goes over the side")
	_expect(not game.over and game.placed == 0,
		"slipping costs progress, not the charter")
	_expect(is_zero_approx(game.lean()),
		"a box that never rested never weighed on the tower")

	# The tower going over is what loses it: enough weight far enough off centre.
	var topple := StackGame.new()
	topple.setup({"goal": 20, "seconds": 600.0})
	var toppled := false
	for step in 20:
		topple.trolley_x = topple.top() \
			+ StackGame.BOX_WIDTH * (1.0 - StackGame.MIN_OVERLAP) * 0.95
		var outcome := topple.drop()
		if StringName(outcome.get("result", &"")) == StackGame.RESULT_TOPPLE:
			toppled = true
			break
	_expect(toppled and topple.over and not topple.victory and topple.toppled,
		"a tower leaned far enough goes over and loses the charter")
	_expect(topple.placed > 0, "and it was carrying boxes when it did")

	# The clock is the other way to lose it.
	var slow := StackGame.new()
	slow.setup({"goal": 8, "seconds": 12.0})
	for step in 13 * 60:
		slow.advance(1.0 / 60.0)
	_expect(slow.over and not slow.victory,
		"running the clock out loses it too")
	_expect(slow.drop().get("over", false),
		"and a finished game cannot be played on")

	# The trolley stays inside the well no matter how fast it ends up going.
	var fast := StackGame.new()
	fast.setup({"goal": 40, "seconds": 600.0})
	fast.speed = StackGame.MAX_SPEED
	var limit := StackGame.WELL_WIDTH * 0.5
	for step in 2000:
		fast.advance(1.0 / 60.0)
		if absf(fast.trolley_x) > limit:
			_expect(false, "the trolley left the well at %.1f" % fast.trolley_x)
			break


func _test_the_maze_is_always_solvable() -> void:
	## A maze nobody can finish is a charter that only ever fines you, so this is
	## the one property that has to hold for every seed: every cell reachable from
	## the gate, which also means every crate and the berth.
	for attempt in 40:
		var maze := MazeGame.new()
		maze.setup({"id": "carga_perdida", "crates": 5, "goal": 5,
			"seconds": 60.0}, attempt * 7919 + 13)
		var seen := {Vector2i.ZERO: true}
		var stack: Array[Vector2i] = [Vector2i.ZERO]
		while not stack.is_empty():
			var cell: Vector2i = stack.pop_back()
			for direction: int in MazeGame.STEP:
				if (maze.sides(cell) & direction) == 0:
					continue
				var next: Vector2i = cell + MazeGame.STEP[direction]
				if not seen.has(next):
					seen[next] = true
					stack.append(next)
		if seen.size() != maze.width * maze.height:
			_expect(false, "maze %d leaves %d of %d cells unreachable"
				% [attempt, maze.width * maze.height - seen.size(),
					maze.width * maze.height])
			break
		if not seen.has(maze.exit_cell):
			_expect(false, "maze %d walls the berth off" % attempt)
			break
		var crates_reachable := true
		for crate: Vector2i in maze.crates:
			crates_reachable = crates_reachable and seen.has(crate)
			if crate == Vector2i.ZERO or crate == maze.exit_cell:
				crates_reachable = false
		_expect(crates_reachable,
			"maze %d puts every crate somewhere worth walking to" % attempt)
		if not crates_reachable:
			break
	# Same charter, same yard: a maze that rerolls is a maze worth reloading for.
	var first := MazeGame.new()
	first.setup({"id": "carga_perdida", "crates": 3, "goal": 3}, 4242)
	var again := MazeGame.new()
	again.setup({"id": "carga_perdida", "crates": 3, "goal": 3}, 4242)
	_expect(first.open_sides == again.open_sides and first.crates == again.crates,
		"the same charter lays out the same yard")
	var other := MazeGame.new()
	other.setup({"id": "carga_perdida", "crates": 3, "goal": 3}, 99)
	_expect(first.open_sides != other.open_sides,
		"a different charter lays out a different one")


func _test_the_maze_can_be_won_and_lost() -> void:
	var maze := MazeGame.new()
	maze.setup({"id": "carga_perdida", "crates": 3, "goal": 3,
		"seconds": 90.0}, 2026)
	_expect(not maze.exit_open(), "the berth is shut until the boxes are found")
	_expect(maze.remaining() == 3, "and it says how many are left")

	# Walk the whole maze depth-first, which is what a player does badly and a
	# test does exhaustively: every crate found, then out through the berth.
	var route := _walk_everywhere(maze)
	_expect(maze.collected == maze.goal,
		"a full sweep finds every crate (%d of %d)" % [maze.collected, maze.goal])
	_expect(maze.exit_open(), "which opens the berth")
	_expect(maze.victory and maze.over,
		"and arriving there with them wins the charter (%d moves)" % route)
	_expect(maze.time_left > 0.0, "with clock to spare")

	# A wall is a wall.
	var blocked := MazeGame.new()
	blocked.setup({"id": "carga_perdida", "crates": 3, "goal": 3}, 77)
	var refused := 0
	for direction: int in MazeGame.STEP:
		if not blocked.can_move(direction):
			refused += 1
			_expect(not bool(blocked.move(direction).get("moved", true)),
				"a walled side refuses the move")
	_expect(refused > 0, "the gate cell really is walled on some side")
	_expect(blocked.at == Vector2i.ZERO, "and a refused move goes nowhere")

	# The clock is the way to lose it.
	var slow := MazeGame.new()
	slow.setup({"id": "carga_perdida", "crates": 5, "goal": 5,
		"seconds": 12.0}, 5)
	for step in 13 * 60:
		slow.advance(1.0 / 60.0)
	_expect(slow.over and not slow.victory, "running the clock out loses it")
	_expect(not bool(slow.move(MazeGame.EAST).get("moved", true)),
		"and a finished maze cannot be walked on")


func _walk_everywhere(maze: MazeGame) -> int:
	## Depth-first with backtracking, moving one legal cell at a time exactly as a
	## player would — no teleporting, so the walk proves the maze is walkable.
	var seen := {maze.at: true}
	var trail: Array[int] = []
	var steps := 0
	while steps < 4000 and not maze.over:
		var advanced := false
		for direction: int in MazeGame.STEP:
			if not maze.can_move(direction):
				continue
			if seen.has(maze.at + MazeGame.STEP[direction]):
				continue
			maze.move(direction)
			steps += 1
			seen[maze.at] = true
			trail.append(int(MazeGame.OPPOSITE[direction]))
			advanced = true
			break
		if advanced:
			continue
		if trail.is_empty():
			break
		maze.move(trail.pop_back())
		steps += 1
	return steps


func _test_a_reload_keeps_the_charter_but_not_the_burst() -> void:
	var director := SpecialCallDirector.new()
	director.setup(null)
	director.seed_new()
	director.offer = SpecialCallDB.materialize(7788, 3)
	director.accept()
	var booked_id := str(director.booked.id)
	var restored := SpecialCallDirector.new()
	restored.setup(null)
	restored.restore(director.snapshot())
	_expect(str(restored.booked.get("id", "")) == booked_id,
		"a charter the player already agreed to survives a reload")

	# One caught mid-play comes back as one still to play: half a burst of input
	# cannot be restored honestly.
	director.claim_variant(0)
	director.notify_alongside(0)
	_expect(bool(director.active.get("played", false)),
		"an opened minigame is marked as played")
	var resumed := SpecialCallDirector.new()
	resumed.setup(null)
	resumed.restore(director.snapshot())
	_expect(not resumed.active.is_empty()
			and not bool(resumed.active.get("played", false)),
		"and comes back still to be played")
	var replays: Array[Dictionary] = []
	resumed.minigame_requested.connect(
		func(offer: Dictionary) -> void: replays.append(offer))
	resumed.notify_alongside(resumed.active_berth)
	_expect(replays.size() == 1, "so the charter can actually be worked again")

	# An offer nobody answered is never restored: it would be answered by nobody.
	director.offer = SpecialCallDB.materialize(7788, 4)
	var reloaded := SpecialCallDirector.new()
	reloaded.setup(null)
	reloaded.restore(director.snapshot())
	_expect(reloaded.offer.is_empty(),
		"an unanswered charter is not restored into a loading screen")

	# A burst is session-scoped: banking one across a reload would be free money.
	GameState.grant_surge(10.0, 30.0)
	GameState.from_save(GameState.to_save())
	_expect(is_equal_approx(GameState.surge_mult, 1.0)
			and is_zero_approx(GameState.surge_remaining()),
		"a reload never restores a running burst")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
