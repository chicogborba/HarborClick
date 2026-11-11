extends Node
## Run with: Godot --headless --path . res://tests/core_test_runner.tscn

var failures: Array[String] = []
const TEST_PATH := "user://harborclick_core_test.json"
const PREFERENCES_TEST_PATH := "user://harborclick_preferences_test.cfg"
var save_events: Array[Dictionary] = []
var recovered_sources: Array[StringName] = []
var section_restored: Dictionary = {}
var section_seed_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	EventBus.save_finished.connect(_on_save_finished)
	EventBus.save_recovered.connect(_on_save_recovered)
	SaveManager.set_save_path_for_tests(TEST_PATH)
	SaveManager.wipe()
	test_v2_format()
	test_manual_reward_is_idempotent()
	test_milestone_normalization()
	test_offline_credit_is_idempotent()
	test_offline_report_accounts_for_the_cap()
	test_offline_duration_reads_as_time()
	test_offline_lines_fit_the_board()
	test_prestige_quote_reads_as_a_decision()
	test_cps_breakdown_reproduces_the_rate()
	test_a_transform_preview_tells_the_truth()
	test_a_quote_prices_what_a_machine_does_to_the_whole_port()
	test_an_exclusive_swap_costs_and_replaces()
	test_a_blocked_node_is_refused_not_silently_bought()
	test_fmt_reads_as_a_number_in_this_language()
	test_the_cat_is_worth_finding_after_automation()
	test_purchase_wait_reads_as_time()
	test_late_sections_and_seed()
	test_achievements_pay_and_gated_branches_read_their_stats()
	test_a_dead_provider_cannot_kill_the_save()
	test_decorations_are_bought_once_and_kept()
	test_v1_migration()
	test_corrupt_primary_recovers_backup()
	test_recovered_backup_offline_is_idempotent()
	test_future_version_falls_back()
	test_preferences_backup_recovers()
	test_prestige_nodes_all_change_something()
	test_retired_prestige_nodes_migrate()
	test_offline_tier_ignores_purchase_order()
	test_wipe_removes_everything()
	if failures.is_empty():
		print("CORE TESTS PASSED")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func test_v2_format() -> void:
	SaveManager.wipe()
	save_events.clear()
	GameState.teus = 42.0
	GameState.run_teus = 42.0
	GameState.all_time_teus = 42.0
	GameState.lifetime_teus = 42.0
	_expect(SaveManager.save_game(&"format"), "v2 save writes")
	var data := _read(TEST_PATH)
	_expect(int(data.get("save_version", 0)) == 2, "v2 has save_version")
	_expect(data.has("saved_at_unix") and data.core is Dictionary and data.time is Dictionary and data.sections is Dictionary, "v2 envelope has required sections")
	_expect(not save_events.is_empty() and save_events.back().ok and save_events.back().reason == &"format", "save_finished emits success and reason")


func test_manual_reward_is_idempotent() -> void:
	GameState.from_save({})
	var quote := GameState.make_manual_reward_quote("test:manual:1")
	var before := GameState.teus
	var first := GameState.commit_manual_reward("test:manual:1", quote)
	var after_first := GameState.teus
	var second := GameState.commit_manual_reward("test:manual:1", {"value": 999.0, "crit": true})
	_expect(first is bool and second is bool and first and second, "manual commit has bool success contract")
	_expect(is_equal_approx(after_first - before, float(quote.value)), "first manual commit pays quote")
	_expect(is_equal_approx(GameState.teus, after_first), "duplicate manual commit does not pay twice")


func test_milestone_normalization() -> void:
	GameState.from_save({"flags": {"milestones": [0.0, "one_million", 0, "invalid"]}})
	var seen: Array = GameState.flags.get("milestones", [])
	_expect(seen == ["first_100", "one_million"], "legacy milestone indexes normalize to ids")


func test_offline_credit_is_idempotent() -> void:
	SaveManager.wipe()
	var envelope := _v2_envelope(0.0, {})
	envelope.saved_at_unix = Time.get_unix_time_from_system() - 120.0
	envelope.core["owned"] = {"estivador": 1}
	_write(TEST_PATH, envelope)
	_expect(SaveManager.load_game(), "offline source save loads")
	var after_first := GameState.teus
	_expect(after_first > 0.0, "offline interval credits productive earnings")
	_expect(SaveManager.load_game(), "offline-credit checkpoint reloads")
	_expect(is_equal_approx(GameState.teus, after_first),
		"reload during offline popup cannot credit the same interval twice")


func test_offline_report_accounts_for_the_cap() -> void:
	## The popup can only explain the absence if the credit path hands it the
	## account instead of a single total.
	SaveManager.wipe()
	var cap := GameState.OFFLINE_CAP_SECONDS_BASE
	var away := cap + 7200.0
	var envelope := _v2_envelope(0.0, {})
	envelope.saved_at_unix = Time.get_unix_time_from_system() - away
	envelope.core["owned"] = {"estivador": 1}
	_write(TEST_PATH, envelope)
	_expect(SaveManager.load_game(), "long-absence save loads")
	var report: Dictionary = SaveManager.offline_report
	_expect(not report.is_empty(), "a credited absence reports its account")
	_expect(absf(float(report.get("away_seconds", 0.0)) - away) <= 5.0,
		"the report keeps the whole absence, not the capped part")
	_expect(is_equal_approx(float(report.get("credited_seconds", 0.0)), cap),
		"only the capped seconds are paid")
	_expect(absf(float(report.get("capped_seconds", 0.0)) - 7200.0) <= 5.0,
		"the report names the seconds the cap refused")
	_expect(float(report.get("lost_to_cap", 0.0)) > 0.0,
		"the report prices what the cap refused")
	_expect(is_equal_approx(float(report.get("earnings", 0.0)),
			SaveManager.offline_earnings),
		"the report and the credited total agree")
	# A short absence has nothing to apologise for and must not claim a loss.
	SaveManager.wipe()
	var short_envelope := _v2_envelope(0.0, {})
	short_envelope.saved_at_unix = Time.get_unix_time_from_system() - 120.0
	short_envelope.core["owned"] = {"estivador": 1}
	_write(TEST_PATH, short_envelope)
	_expect(SaveManager.load_game(), "short-absence save loads")
	_expect(is_zero_approx(float(SaveManager.offline_report.get("capped_seconds", 0.0))),
		"an absence inside the cap reports no loss")


func test_offline_duration_reads_as_time() -> void:
	_expect(OfflinePopup.format_duration(0.0) == "0s", "zero reads as seconds")
	_expect(OfflinePopup.format_duration(90.0) == "1min", "minutes drop seconds")
	_expect(OfflinePopup.format_duration(3600.0) == "1h", "a whole hour has no minutes")
	_expect(OfflinePopup.format_duration(29100.0) == "8h05", "hours and minutes pad")


func test_offline_lines_fit_the_board() -> void:
	## The board has no autowrap on purpose, so a line that outgrows the panel
	## would be clipped instead of wrapped. Worst case: ten hours away and a rate
	## wide enough to need a suffix.
	var report := {"away_seconds": 36000.0, "credited_seconds": 28800.0,
		"capped_seconds": 7200.0, "cap_seconds": 28800.0, "efficiency": 0.5,
		"rate": 123.456e12, "earnings": 1.0, "lost_to_cap": 999.9e12}
	# Every language, not only the one the suite happens to run in. The board has
	# no autowrap, so a translation that runs long is a clipped sentence on a
	# device nobody testing in Portuguese will ever open.
	var restore := Loc.language
	for entry in Loc.LANGUAGES:
		var code := StringName(entry.code)
		Loc.apply(code, false)
		var localised: Array[String] = [OfflinePopup.greeting(report)]
		localised.append_array(OfflinePopup.breakdown_lines(report))
		_expect(localised.size() == 3,
			"[%s] a capped absence explains itself in three lines" % code)
		for line in localised:
			_expect(line.length() <= OfflinePopup.MAX_LINE,
				"[%s] \"%s\" fits the board (%d chars)" % [code, line, line.length()])
	Loc.apply(restore, false)
	var lines: Array[String] = [OfflinePopup.greeting(report)]
	lines.append_array(OfflinePopup.breakdown_lines(report))
	_expect(OfflinePopup.breakdown_lines({}).is_empty(),
		"no report means no breakdown")
	var inside := report.duplicate()
	inside["capped_seconds"] = 0.0
	_expect(OfflinePopup.breakdown_lines(inside).size() == 1,
		"an absence inside the cap shows no loss line")


func test_prestige_quote_reads_as_a_decision() -> void:
	## The quote line used to feed the per-structure `peak` dictionary to
	## `float()`, which raised every time the button was pressed — so `_quoted`
	## never flipped and the reset could not be confirmed from the dialog at all.
	GameState.from_save({"owned": {"estivador": 30, "empilhadeira": 10},
		"all_time_productive_teus": 4.0e10})
	GameState.recompute()
	var quote := GameState.get_prestige_quote()
	_expect(int(quote.get("gain", 0)) > 0, "the seeded port is worth a reset")
	_expect(PrestigeDialog.peak_units(quote.get("peak", {})) == 40,
		"the peak reads as a machine count, not a dictionary")
	_expect(quote.has("rebuild_seconds"), "the quote prices the rebuild in time")
	var seconds := float(quote.rebuild_seconds)
	_expect(seconds > 0.0, "a producing port has a finite rebuild estimate")
	_expect(PrestigeDialog.rebuild_line(seconds).contains(
			OfflinePopup.format_duration(seconds)),
		"the dialog line states the estimate as time")
	_expect(not PrestigeDialog.rebuild_line(-1.0).is_empty(),
		"a rebuild past the budget still says something")
	_expect(PrestigeDialog.peak_units("not a dictionary") == 0,
		"a malformed peak cannot crash the quote")


func test_cps_breakdown_reproduces_the_rate() -> void:
	## The panel is the formula, not a description of it: multiplying the factors
	## has to land back on the rate the counter is showing, or it is decoration.
	GameState.from_save({"owned": {"estivador": 25, "empilhadeira": 10},
		"upgrades": ["cafe_forte", "carrinho_mao", "colete_novo"],
		"purchased_tree_nodes": ["throughput_structural"],
		"prestige_level_earned": 9, "shares": 9})
	GameState.recompute()
	var rows := GameState.cps_breakdown()
	_expect(rows.size() >= 5, "the breakdown names every factor")
	_expect(String(rows[0].kind) == "base", "the first row is the machine rate")
	var product := 1.0
	for row in rows:
		product *= float(row.value)
	_expect(absf(product - GameState.cps) <= maxf(0.001, GameState.cps * 1e-9),
		"the factors multiply back to the rate the counter is showing")
	var milestone := float(rows[1].value)
	var upgrades := float(rows[2].value)
	_expect(milestone > 1.0, "25 machines have crossed a milestone")
	_expect(upgrades > 1.0, "two fitted upgrades read as a multiplier above one")
	_expect(float(rows[3].value) > 1.0, "capital reads as a multiplier above one")
	# An empty port has no factors to lie about.
	GameState.from_save({})
	GameState.recompute()
	var empty := GameState.cps_breakdown()
	_expect(is_zero_approx(float(empty[0].value)), "an empty port produces nothing")
	for row in empty:
		if String(row.kind) == "mult":
			_expect(float(row.value) > 0.0, "no factor is zero on an empty port")


func test_a_transform_preview_tells_the_truth() -> void:
	## The conductor card is the only one on the board that can honestly show a
	## loss, so the figure it shows has to be the figure that happens. It is
	## derived rather than simulated — `recompute()` emits, so the shop cannot
	## buy-measure-rollback twice a second — and a derivation is exactly the kind
	## of thing that quietly stops matching the formula it was derived from.
	# Both signs, because the clamped `cps_gain` on the card cannot show a loss and
	# the loss is the half that makes it a decision.
	for case in [
		# A yard that is *only* dockers: converting them guts 99% of its own
		# output to lift a port that is almost entirely those same dockers.
		{"owned": {"estivador": 120, "empilhadeira": 10}, "gain": false},
		# A yard where the dockers are long since a rounding error in production
		# but still a hundred-odd bodies to pay a share on.
		{"owned": {"estivador": 120, "empilhadeira": 100, "tt": 90,
			"reach_stacker": 70, "rtg": 55, "sts": 40}, "gain": true},
	]:
		GameState.from_save({"owned": case.owned,
			"upgrades": ["cafe_forte", "carrinho_mao", "sindicato"],
			"teus": 1e18, "all_time_teus": 1e18})
		GameState.recompute()
		var before := GameState.base_cps
		var predicted := float(GameState._transform_cps_delta(
			UpgradeDB.get_item("turma_de_terra")))
		_expect(GameState.buy_upgrade("turma_de_terra"), "the turma can be fitted")
		var actual := GameState.base_cps - before
		_expect(absf(predicted - actual) <= maxf(0.001, absf(actual) * 1e-6),
			"the card promised what the port got (%f vs %f)" % [predicted, actual])
		_expect((actual > 0.0) == bool(case.gain),
			"the trade lands the way the port's shape says it should (%+f)" % actual)

	# The same question about a *swap*. The conductors are one exclusive group, so
	# taking a second drops the first: scored as a factor on top of the share
	# already fitted, every swap would show a large fake gain.
	GameState.from_save({"owned": {"estivador": 120, "empilhadeira": 100,
		"tt": 90, "reach_stacker": 70, "rtg": 55, "sts": 40},
		"upgrades": ["cafe_forte", "carrinho_mao", "sindicato", "turma_de_terra",
			"operador_descansado"],
		"teus": 1e18, "all_time_teus": 1e18})
	GameState.recompute()
	var swap_before := GameState.base_cps
	var swap_predicted := GameState._transform_cps_delta(
		UpgradeDB.get_item("cais_dedicado"))
	_expect(GameState.buy_upgrade("cais_dedicado"), "the swap goes through")
	_expect(not GameState.has_upgrade("turma_de_terra"),
		"and the identity it replaced actually came off")
	var swap_actual := GameState.base_cps - swap_before
	_expect(absf(swap_predicted - swap_actual) <= maxf(0.001, absf(swap_actual) * 1e-6),
		"a swap is priced as a replacement, not as a second identity (%f vs %f)"
			% [swap_predicted, swap_actual])


func test_a_quote_prices_what_a_machine_does_to_the_whole_port() -> void:
	## Since a machine's count can move *other* machines' rates — a conductor's
	## share, a synergy's ceiling, the capital tree's breadth — a quote that only
	## added up the new units' own output would understate exactly the purchases
	## the tree was built to make interesting. The card's "+N TEU/s" is the number
	## the whole decision hangs on, so it has to be the real one.
	var owned := {"estivador": 120, "empilhadeira": 100, "tt": 90,
		"reach_stacker": 70, "rtg": 55, "sts": 40}
	GameState.from_save({"owned": owned,
		"upgrades": ["cafe_forte", "carrinho_mao", "sindicato", "turma_de_terra"],
		"teus": 1e18, "all_time_teus": 1e18})
	GameState.recompute()
	var quoted := GameState.nominal_cps("estivador", 145) - GameState.nominal_cps()
	# The honest answer: actually own 145 and look.
	var truth := {}
	for id: String in owned:
		truth[id] = owned[id]
	truth["estivador"] = 145
	GameState.from_save({"owned": truth,
		"upgrades": ["cafe_forte", "carrinho_mao", "sindicato", "turma_de_terra"],
		"teus": 1e18, "all_time_teus": 1e18})
	GameState.recompute()
	var real_after := GameState.nominal_cps()
	GameState.from_save({"owned": owned,
		"upgrades": ["cafe_forte", "carrinho_mao", "sindicato", "turma_de_terra"],
		"teus": 1e18, "all_time_teus": 1e18})
	GameState.recompute()
	var actual := real_after - GameState.nominal_cps()
	_expect(actual > 0.0, "twenty-five more dockers are worth something")
	_expect(absf(quoted - actual) <= maxf(0.001, absf(actual) * 1e-6),
		"the quote is the truth, conductor share included (%f vs %f)"
			% [quoted, actual])
	# And the lift is the *majority* of it, or the override is being applied
	# somewhere that does not matter.
	var own_line := GameState.structure_total_cps("estivador", 145) \
		- GameState.structure_total_cps("estivador", 120)
	_expect(actual > own_line * 2.0,
		"most of what a conductor machine is worth lands on the other machines")


func test_an_exclusive_swap_costs_and_replaces() -> void:
	## "Cara mas possível", checked against the wallet rather than against the
	## catalogue: the second pick has to actually charge the surcharge, and the
	## first has to actually come off.
	GameState.from_save({"owned": {"rtg": 20, "empilhadeira": 30,
		"reach_stacker": 20},
		"upgrades": ["garfo_duplo", "buzina_musical", "contrapeso",
			"telemetria_lanca", "gps_rtg", "operacao_remota_rtg",
			"estoque_profundo"],
		"teus": 1e18, "all_time_teus": 1e18})
	GameState.recompute()
	var list_price := float(UpgradeDB.get_item("giro_rapido").cost)
	var before := GameState.teus
	_expect(GameState.buy_upgrade("giro_rapido"), "the yard can change its mind")
	_expect(not GameState.has_upgrade("estoque_profundo"),
		"and the half it replaced came off in the same transaction")
	var paid := before - GameState.teus
	_expect(absf(paid - list_price * UpgradeDB.SWAP_SURCHARGE) <= 1.0,
		"changing its mind cost the surcharge, not the list price (%f)" % paid)


func test_a_blocked_node_is_refused_not_silently_bought() -> void:
	## `requires` is a rule, not a hint the shop happens to draw. A port with the
	## money and none of the prerequisites must not be able to skip the tree.
	GameState.from_save({"owned": {"estivador": 60},
		"teus": 1e18, "all_time_teus": 1e18})
	GameState.recompute()
	var sindicato := UpgradeDB.get_item("sindicato")
	_expect(GameState.upgrade_unlocked(sindicato),
		"the port is big enough for the node")
	_expect(not GameState.upgrade_available(sindicato),
		"but the node above it is unbought")
	_expect(not GameState.buy_upgrade("sindicato"),
		"and money alone does not open it")
	_expect(GameState.buy_upgrade("cafe_forte") and GameState.buy_upgrade("carrinho_mao"),
		"climbing the trunk is the way through")
	_expect(GameState.buy_upgrade("sindicato"), "and then it opens")


func test_purchase_wait_reads_as_time() -> void:
	_expect(ShopCard.wait_for(0.0, 10.0) == "0s", "nothing missing is no wait")
	_expect(ShopCard.wait_for(100.0, 0.0) == "muito",
		"a port that produces nothing cannot promise a time")
	_expect(ShopCard.wait_for(120.0, 1.0) == "120s"
			or ShopCard.wait_for(120.0, 1.0) == "2min",
		"two minutes read as a duration")
	_expect(ShopCard.wait_for(7200.0, 1.0) == "2h", "hours read as hours")


func test_late_sections_and_seed() -> void:
	SaveManager.wipe()
	section_seed_calls = 0
	SaveManager.register_section(&"core_test_seed", Callable(self, "_section_snapshot"), Callable(self, "_section_restore"), Callable(self, "_section_seed"))
	_expect(section_seed_calls == 1, "new game section seed runs on registration")
	_write(TEST_PATH, {
		"save_version": 2, "saved_at_unix": 0.0, "core": {}, "time": {},
		"sections": {"core_test_late": {"token": "restored"}},
	})
	_expect(SaveManager.load_game(), "v2 load for late section succeeds")
	section_restored = {}
	SaveManager.register_section(&"core_test_late", Callable(self, "_section_snapshot"), Callable(self, "_section_restore"))
	_expect(section_restored.get("token", "") == "restored", "late section registration restores loaded payload")


func test_decorations_are_bought_once_and_kept() -> void:
	## A decoration is the only purchase in the game that survives a rebuild, and
	## the only one that can be switched off after it is paid for. Both are the
	## reason anybody buys one, so both are asserted here rather than left to the
	## shop to remember.
	SaveManager.wipe()
	GameState.from_save({})
	var duck := &"duck"
	var price := CosmeticDb.cost(duck)
	_expect(not GameState.buy_cosmetic(duck), "an empty wallet buys nothing")
	GameState.teus = price + 5.0
	_expect(GameState.buy_cosmetic(duck), "the shelf sells at the listed price")
	_expect(is_equal_approx(GameState.teus, 5.0), "and charges exactly it")
	_expect(GameState.cosmetic_on(duck), "what you just bought is switched on")
	_expect(not GameState.buy_cosmetic(duck), "nobody buys the same duck twice")

	_expect(GameState.set_cosmetic(duck, false), "it can be switched off")
	_expect(GameState.owns_cosmetic(duck) and not GameState.cosmetic_on(duck),
		"switched off is still owned")
	_expect(not GameState.set_cosmetic(&"bunting", true),
		"nothing switches on what was never bought")

	# Through a save and back.
	GameState.set_cosmetic(duck, true)
	_expect(SaveManager.save_game(&"test"), "a decorated port saves")
	GameState.from_save({})
	_expect(not GameState.owns_cosmetic(duck), "a fresh profile owns nothing")
	_expect(SaveManager.load_game(), "the decorated save loads")
	_expect(GameState.cosmetic_on(duck), "the duck is still moored after a reload")

	# And through a rebuild, which is the whole point.
	GameState.owned = {"estivador": 40}
	GameState.all_time_productive_teus = 1.0e11
	GameState.recompute()
	_expect(GameState.do_prestige(), "the seeded port is worth a reset")
	_expect(GameState.owned.is_empty(), "the reset took the machines")
	_expect(GameState.cosmetic_on(duck), "and left the duck")


func test_achievements_pay_and_gated_branches_read_their_stats() -> void:
	## C6: every unlocked achievement is +1% permanent production, shown in the
	## breakdown; and the Rotas/Eventos branches of the capital tree are real —
	## a gated node is refused while its feature is locked and bought once it
	## is not, and its stats move the lane freight and the charter window.
	GameState.from_save({})
	GameState.owned["estivador"] = 2
	GameState.recompute()
	var mult_before := GameState.achievement_multiplier()
	var cps_before := GameState.cps
	for i in 10:
		Progression.unlocked[StringName("core_ach_%d" % i)] = {"id": "core_ach_%d" % i}
	GameState.recompute()
	_expect(is_equal_approx(GameState.achievement_multiplier(), mult_before + 0.10),
		"10 more achievements pay +10% on top of whatever was unlocked")
	_expect(is_equal_approx(GameState.cps, cps_before * (mult_before + 0.10) / mult_before),
		"the achievement multiplier is inside cps")
	var saw := false
	for row in GameState.cps_breakdown():
		if row.get("label", "") == "Conquistas":
			saw = is_equal_approx(float(row.get("value", 1.0)),
				mult_before + 0.10)
	_expect(saw, "the breakdown shows the Conquistas row")
	var rules := TerminalLevel.new()
	rules.level = 1
	FeatureGate.bind(rules)
	GameState.shares = 10
	_expect(not GameState.buy_prestige_node(&"routes_reward"),
		"routes node is refused while the routes feature is locked")
	_expect(not GameState.buy_prestige_node(&"events_reward"),
		"events node is refused while the events feature is locked")
	rules.level = 12
	FeatureGate.bind(rules)
	_expect(PrestigeDB.purchasable_branches().size() == PrestigeDB.BRANCHES.size(),
		"at level 12 every branch is on the tree")
	_expect(GameState.buy_prestige_node(&"routes_reward"),
		"routes node buys once routes is unlocked")
	_expect(is_equal_approx(GameState.route_reward_bonus(), 0.10),
		"route_reward_bonus reads the bought node")
	_expect(GameState.buy_prestige_node(&"routes_slot"),
		"route slot node buys after its requirement")
	_expect(GameState.route_slot_bonus() == 1, "route_slot_bonus reads the flat node")
	_expect(GameState.buy_prestige_node(&"events_reward"), "events node buys at level 12")
	_expect(is_equal_approx(GameState.event_reward_bonus(), 0.10),
		"event_reward_bonus reads the bought node")
	_expect(GameState.buy_prestige_node(&"events_window"), "events window node buys")
	_expect(is_equal_approx(GameState.event_duration_bonus(), 0.10),
		"event_duration_bonus reads the bought node")
	var offer := SpecialCallDB.materialize(12345, 0)
	var raw_seconds := 0.0
	for o in SpecialCallDB.OFFERS:
		if o.get("title", "") == offer.get("title", ""):
			raw_seconds = float(o.get("seconds", 0.0))
	_expect(raw_seconds > 0.0 and is_equal_approx(float(offer.get("seconds", 0.0)),
		raw_seconds * 1.10), "a materialized charter window is 10% longer with the node bought")
	FeatureGate.unbind(rules)
	for i in 10:
		Progression.unlocked.erase(StringName("core_ach_%d" % i))
	GameState.from_save({})
	GameState.recompute()


func test_a_dead_provider_cannot_kill_the_save() -> void:
	## Leaving the terminal for the title screen frees everything `PortWorld`
	## registered, and a `Callable` holds an object id rather than a reference.
	## Calling one of those aborted `build_envelope`, which returned the empty
	## Dictionary its signature promises, which made `save_game` fail on
	## `envelope.sections` — so every autosave from that moment on, and the save
	## on the way out of the app, wrote nothing at all and said nothing about it.
	SaveManager.wipe()
	var ghost := Node.new()
	add_child(ghost)
	SaveManager.register_section(&"ghost_section",
		Callable(self, "_section_snapshot"), Callable(self, "_section_restore"))
	SaveManager.register_section(&"live_section",
		Callable(self, "_section_snapshot"), Callable(self, "_section_restore"))
	_expect(SaveManager.save_game(&"test"), "a save with both providers alive")
	# Free the provider the way a scene change does, then save again.
	SaveManager.register_section(&"ghost_section",
		Callable(ghost, "queue_free"), Callable(self, "_section_restore"))
	ghost.free()
	var envelope := SaveManager.build_envelope()
	_expect(envelope.has("sections"), "a dead provider still builds an envelope")
	_expect(SaveManager.save_game(&"test"), "a dead provider still saves")
	_expect(envelope.sections.has("live_section"),
		"the live sections are still written")
	_expect(envelope.sections.has("ghost_section"),
		"the dead one keeps whatever it last wrote")
	SaveManager.unregister_section(&"live_section")
	_expect(SaveManager.build_envelope().sections.has("live_section"),
		"unregistering keeps the payload and only drops the provider")


func test_v1_migration() -> void:
	SaveManager.wipe()
	_write(TEST_PATH, {"teus": 7.0, "lifetime": 11.0, "day": 3, "time_of_day": 0.5, "yard": [{"id": "c"}]})
	_expect(SaveManager.load_game(), "v1 load succeeds")
	_expect(is_equal_approx(GameState.teus, 7.0) and is_equal_approx(GameState.all_time_teus, 11.0), "v1 core migrates totals")
	_expect(TimeManager.day == 3 and SaveManager.pending_yard().size() == 1, "v1 time and section migrate")
	section_seed_calls = 0
	SaveManager.register_section(&"v1_missing_section", Callable(self, "_section_snapshot"), Callable(self, "_section_restore"), Callable(self, "_section_seed"))
	_expect(section_seed_calls == 1, "v1 missing section runs seed on late registration")


func test_corrupt_primary_recovers_backup() -> void:
	SaveManager.wipe()
	var backup_envelope := _v2_envelope(10.0, {
		"recovered_late_section": {"token": "from_backup"},
	})
	_write(TEST_PATH + ".bak", backup_envelope)
	var backup_before := _read_text(TEST_PATH + ".bak")
	_write(TEST_PATH, "{ definitely not json")
	GameState.from_save({})
	recovered_sources.clear()
	_expect(SaveManager.load_game(), "backup recovery succeeds")
	_expect(is_equal_approx(GameState.teus, 10.0), "backup content is restored after corrupt primary")
	_expect(recovered_sources.has(&"backup"), "save recovery signal uses source contract")
	_expect(_read_text(TEST_PATH + ".bak") == backup_before and not _read(TEST_PATH + ".bak").is_empty(), "valid backup remains untouched after recovery")
	var promoted := _read(TEST_PATH)
	_expect(promoted.get("sections", {}).get("recovered_late_section", {}).get("token", "") == "from_backup", "promoted primary preserves unregistered sections")
	section_restored = {}
	SaveManager.register_section(&"recovered_late_section", Callable(self, "_section_snapshot"), Callable(self, "_section_restore"))
	_expect(section_restored.get("token", "") == "from_backup", "recovered section restores on late registration")


func test_recovered_backup_offline_is_idempotent() -> void:
	SaveManager.wipe()
	var backup_envelope := _v2_envelope(5.0, {
		"offline_recovery_section": {"kept": true},
	})
	backup_envelope.saved_at_unix = Time.get_unix_time_from_system() - 120.0
	backup_envelope.core["owned"] = {"estivador": 1}
	_write(TEST_PATH + ".bak", backup_envelope)
	_write(TEST_PATH, "{ corrupt primary before offline recovery")
	_expect(SaveManager.load_game(), "productive backup recovery succeeds")
	var after_recovery := GameState.teus
	_expect(after_recovery > 5.0, "recovered productive backup credits offline earnings once")
	_expect(not _read(TEST_PATH + ".bak").is_empty(),
		"offline recovery leaves a valid backup")
	_expect(_read(TEST_PATH).get("sections", {}).get(
		"offline_recovery_section", {}).get("kept", false),
		"offline checkpoint preserves recovered late sections")
	_expect(SaveManager.load_game(), "offline recovery checkpoint reloads")
	_expect(is_equal_approx(GameState.teus, after_recovery),
		"recovered backup cannot credit the same offline interval twice")


func test_future_version_falls_back() -> void:
	SaveManager.wipe()
	var backup_envelope := _v2_envelope(33.0, {"future_fallback_section": {"kept": true}})
	_write(TEST_PATH + ".bak", backup_envelope)
	_write(TEST_PATH, {
		"save_version": SaveManager.SAVE_VERSION + 1,
		"saved_at_unix": 0.0,
		"core": {"teus": 999.0, "lifetime": 999.0},
		"time": {},
		"sections": {},
	})
	recovered_sources.clear()
	_expect(SaveManager.load_game(), "future primary falls back to current-version backup")
	_expect(is_equal_approx(GameState.teus, 33.0), "future save version is not applied")
	_expect(recovered_sources.has(&"backup"), "future-version fallback reports backup recovery")
	_expect(int(_read(TEST_PATH).get("save_version", 0)) == SaveManager.SAVE_VERSION, "fallback promotes supported envelope to primary")


func test_preferences_backup_recovers() -> void:
	UserPreferences.set_config_path_for_tests(PREFERENCES_TEST_PATH)
	for path in [PREFERENCES_TEST_PATH, PREFERENCES_TEST_PATH + ".tmp",
			PREFERENCES_TEST_PATH + ".bak",
			PREFERENCES_TEST_PATH + ".recovery"]:
		_remove_if_exists(path)
	var backup := ConfigFile.new()
	backup.set_value("preferences", "reduce_motion", true)
	backup.set_value("preferences", "floating_numbers", false)
	backup.set_value("preferences", "ui_scale", 1.15)
	backup.set_value("preferences", "fullscreen", true)
	_expect(backup.save(PREFERENCES_TEST_PATH + ".bak") == OK,
		"preferences crash-state backup writes")
	UserPreferences.reduce_motion = false
	UserPreferences.floating_numbers = true
	UserPreferences.ui_scale = 1.0
	UserPreferences.fullscreen = false
	UserPreferences.load_preferences()
	_expect(UserPreferences.reduce_motion and not UserPreferences.floating_numbers \
			and is_equal_approx(UserPreferences.ui_scale, 1.15) \
			and UserPreferences.fullscreen,
		"preferences recover values from backup when live file is absent")
	_expect(FileAccess.file_exists(PREFERENCES_TEST_PATH),
		"recovered preferences are promoted to the live path")
	_expect(_config_is_valid(PREFERENCES_TEST_PATH + ".bak"),
		"preferences promotion preserves the known-good backup")

	for path in [PREFERENCES_TEST_PATH, PREFERENCES_TEST_PATH + ".tmp",
			PREFERENCES_TEST_PATH + ".bak",
			PREFERENCES_TEST_PATH + ".recovery"]:
		_remove_if_exists(path)
	_write(PREFERENCES_TEST_PATH, "{ corrupt preferences")
	var interrupted_tmp := ConfigFile.new()
	interrupted_tmp.set_value("preferences", "reduce_motion", false)
	interrupted_tmp.set_value("preferences", "floating_numbers", true)
	interrupted_tmp.set_value("preferences", "ui_scale", 0.9)
	interrupted_tmp.set_value("preferences", "fullscreen", false)
	_expect(interrupted_tmp.save(PREFERENCES_TEST_PATH + ".tmp") == OK,
		"preferences interrupted temporary file writes")
	UserPreferences.load_preferences()
	_expect(not UserPreferences.reduce_motion and UserPreferences.floating_numbers \
			and is_equal_approx(UserPreferences.ui_scale, 0.9) \
			and not UserPreferences.fullscreen,
		"preferences recover a valid temporary file after a corrupt live file")
	_expect(_config_is_valid(PREFERENCES_TEST_PATH) \
			and not FileAccess.file_exists(PREFERENCES_TEST_PATH + ".recovery"),
		"temporary preference recovery promotes live and discards corruption")
	for path in [PREFERENCES_TEST_PATH, PREFERENCES_TEST_PATH + ".tmp",
			PREFERENCES_TEST_PATH + ".bak",
			PREFERENCES_TEST_PATH + ".recovery"]:
		_remove_if_exists(path)


func _tree_probe() -> Array[float]:
	## Every observable a prestige node is allowed to move. A node that changes
	## none of these is charging golden shares for nothing. The Rotas/Eventos
	## stats are here because those branches read them for real (lane freight,
	## route rotation, charter window and prize).
	return [GameState.cps, GameState.click_power,
		GameState.offline_efficiency(), GameState.offline_cap_seconds(),
		GameState.route_reward_bonus(), float(GameState.route_slot_bonus()),
		GameState.event_reward_bonus(), GameState.event_duration_bonus()]


func _seed_state_for_tree() -> void:
	## Multipliers are invisible against a zero base, so the port owns something.
	GameState.from_save({"owned": {"estivador": 10}})
	GameState.recompute()


func _buy_prerequisites(id: StringName) -> void:
	## `requires` is a graph, not a list: the deepest offline node depends on two
	## nodes that themselves depend on a third.
	for required in PrestigeDB.get_node(id).get("requires", []):
		var required_id := StringName(required)
		if GameState.purchased_tree_nodes.has(required_id):
			continue
		_buy_prerequisites(required_id)
		_expect(GameState.buy_prestige_node(required_id),
			"%s prerequisite %s is buyable" % [id, required_id])


func test_prestige_nodes_all_change_something() -> void:
	_expect(PrestigeDB.is_valid(), "prestige tree data is valid")
	var branches := PrestigeDB.purchasable_branches()
	_expect(not branches.is_empty(), "at least one branch is purchasable")
	# Feature-gated branches are allowed now — they read their stats for real —
	# but only once their feature is unlocked (covered by the gate test below).
	for branch: Dictionary in branches:
		var bf := String(branch.get("requires_feature", ""))
		if not bf.is_empty():
			_expect(FeatureGate.unlocked(StringName(bf)),
				"%s shows only because its feature is unlocked" % branch.get("id", "?"))
	for branch: Dictionary in branches:
		for node: Dictionary in branch.get("nodes", []):
			var id := StringName(node.get("id", ""))
			_seed_state_for_tree()
			GameState.shares = 999
			_buy_prerequisites(id)
			var before := _tree_probe()
			_expect(GameState.buy_prestige_node(id), "%s is buyable" % id)
			var after := _tree_probe()
			var moved := false
			for index in before.size():
				if not is_equal_approx(before[index], after[index]):
					moved = true
			_expect(moved, "%s changes a value the player can observe" % id)


func test_retired_prestige_nodes_migrate() -> void:
	## The first two versions of the offline branch sold the port's own defaults.
	## A save that bought them keeps the tier it paid for under the new ids.
	for legacy: String in PrestigeDB.LEGACY_NODE_IDS:
		var replacement := StringName(PrestigeDB.LEGACY_NODE_IDS[legacy])
		GameState.from_save({"purchased_tree_nodes": [legacy]})
		_expect(GameState.purchased_tree_nodes.has(replacement),
			"%s is restored as %s" % [legacy, replacement])
		_expect(not GameState.purchased_tree_nodes.has(StringName(legacy)),
			"%s does not survive as a dead id" % legacy)
	GameState.from_save({"purchased_tree_nodes": ["offline_50"]})
	_expect(GameState.offline_efficiency() > GameState.OFFLINE_EFFICIENCY_BASE,
		"a migrated offline node now beats the baseline")


func test_offline_tier_ignores_purchase_order() -> void:
	## The old lookup took the last matching node in dictionary order. It only
	## worked because `requires` happened to force an ascending sequence.
	GameState.from_save({"purchased_tree_nodes":
		["offline_cap_16h", "offline_cap_12h"]})
	_expect(is_equal_approx(GameState.offline_cap_seconds(), 57600.0),
		"the best owned cap wins regardless of insertion order")
	GameState.from_save({"purchased_tree_nodes": ["offline_eff_75", "offline_eff_60"]})
	_expect(is_equal_approx(GameState.offline_efficiency(), 0.75),
		"the best owned efficiency wins regardless of insertion order")


func test_wipe_removes_everything() -> void:
	GameState.boost_time = 12.0
	TimeManager.fog_active = true
	TimeManager.speed_mult = 40.0
	SaveManager.wipe()
	_expect(not FileAccess.file_exists(TEST_PATH), "wipe removes primary")
	_expect(not FileAccess.file_exists(TEST_PATH + ".tmp"), "wipe removes temporary")
	_expect(not FileAccess.file_exists(TEST_PATH + ".bak"), "wipe removes backup")
	_expect(is_equal_approx(GameState.teus, 0.0) and TimeManager.day == 1,
		"wipe resets core and time")
	_expect(is_zero_approx(GameState.boost_time) and not TimeManager.fog_active \
			and is_equal_approx(TimeManager.speed_mult, 1.0),
		"wipe clears boost, weather and debug session speed")


func test_fmt_reads_as_a_number_in_this_language() -> void:
	## The counter is the string a player reads more than any other, so both ways
	## it used to be wrong matter: an English decimal point in a Portuguese game,
	## and a scale that ran out.
	_expect(GameState.fmt(999.0) == "999", "small integers stay plain")
	var thousand := GameState.fmt(1234.0)
	_expect(thousand.contains("K"), "thousands carry a suffix (%s)" % thousand)
	_expect(not thousand.contains("."),
		"and no full stop survives the localised mark (%s)" % thousand)
	# Past the end of the suffix table. The old loop simply stopped dividing, so a
	# port at 10^36 printed "10000000Dc" — a number growing in the digits while
	# claiming to be in the largest unit that exists.
	var huge := GameState.fmt(1e36)
	_expect(huge.contains("e") and not huge.contains("Dc"),
		"past the table the scale goes to an exponent (%s)" % huge)
	_expect(huge.length() <= Readout.WIDEST.length(),
		"and still fits the glass cut for it (%s)" % huge)
	# The mantissa has to be normalised against the digit that is *printed*: 9.99
	# displays as "10.0", which would claim ten times its own exponent.
	for value in [1e36, 1e40, 9.9999e59, 5e45]:
		var text := GameState.fmt(value)
		_expect(not text.begins_with("10"),
			"%s prints a normalised mantissa (%s)" % [value, text])


func test_the_cat_is_worth_finding_after_automation() -> void:
	## The rarest thing in the game used to multiply `click_power` alone, so it
	## expired the day the port stopped being tapped. It is a surge now.
	GameState.from_save({"owned": {"estivador": 40, "empilhadeira": 20},
		"teus": 1e6, "all_time_teus": 1e6})
	GameState.recompute()
	var before := GameState.cps
	_expect(GameState.grant_cat_boost(), "a cat can be found")
	_expect(GameState.cps > before,
		"and it lifts what the port earns, not only what a tap earns")
	_expect(not GameState.grant_cat_boost(),
		"a second tap on the same cat does not extend it")
	# A charter's surge outranks it: wandering past during a ten-times reward
	# must not cut the reward to three.
	GameState.from_save({"owned": {"estivador": 40}, "teus": 1e6})
	GameState.recompute()
	GameState.grant_surge(10.0, 30.0)
	var during := GameState.cps
	GameState.grant_cat_boost()
	_expect(is_equal_approx(GameState.cps, during),
		"the stronger surge wins instead of being downgraded")
	GameState.from_save({})
	GameState.recompute()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _on_save_finished(ok: bool, reason: StringName) -> void:
	save_events.append({"ok": ok, "reason": reason})


func _on_save_recovered(source: StringName) -> void:
	recovered_sources.append(source)


func _section_snapshot() -> Dictionary:
	return {"snapshot": true}


func _section_restore(data: Dictionary) -> void:
	section_restored = data.duplicate(true)


func _section_seed() -> void:
	section_seed_calls += 1


func _v2_envelope(teus_value: float, sections: Dictionary) -> Dictionary:
	return {
		"save_version": SaveManager.SAVE_VERSION,
		"saved_at_unix": 0.0,
		"core": {"teus": teus_value, "lifetime": teus_value},
		"time": {},
		"sections": sections,
	}


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _write(path: String, content: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content if content is String else JSON.stringify(content))
	file.close()


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _config_is_valid(path: String) -> bool:
	var config := ConfigFile.new()
	return config.load(path) == OK and UserPreferences._config_is_usable(config)
