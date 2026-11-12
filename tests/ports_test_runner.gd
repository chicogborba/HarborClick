extends Node
## Ports contract.
## Run with:
## Godot --headless --path . res://tests/ports_test_runner.tscn
##
## A port is a save file inside a profile, and a set of catalogue changes that
## must be in force while it is the active one and gone when it is not. The
## ways that goes wrong are the ways a profile goes wrong, one level down — a
## port reading another port's wallet — plus three of its own: a port got for
## free, a catalogue that stays foreign after the trip home, and a rate panel
## that no longer multiplies out to the rate.

const SLOT := 3

var failures: Array[String] = []
var _finished: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_wipe()
	_test_the_table_is_sound()
	_test_a_port_must_be_paid_for()
	_test_ports_keep_separate_books()
	_test_catalogues_follow_the_port_and_come_home()
	_test_the_rate_panel_still_multiplies_out()
	_test_a_profile_resumes_in_its_last_port()
	_test_deleting_a_profile_takes_its_ports()
	_test_each_port_plays_differently()
	_wipe()
	var expected := 8
	if _finished.size() != expected:
		failures.append("only %d of %d tests reached their last line (%s)"
			% [_finished.size(), expected, ", ".join(_finished)])
	if failures.is_empty():
		print("PORTS TESTS PASSED (table, purchase, isolation, catalogues, rate, resume, delete)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("PORTS TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_the_table_is_sound() -> void:
	_expect(PortDB.is_valid(), "PortDB is internally consistent")
	_expect(PortDB.is_playable(&"long_beach") and PortDB.is_playable(&"shanghai"),
		"the United States and China are open for business")
	_expect(PortDB.PORTS.size() == 3, "home and exactly two ports abroad")
	_expect(not PortDB.is_playable(&"atlantis"), "a port that is not in the table is not")
	for port in PortDB.PORTS:
		if not bool(port.get("playable", false)):
			continue
		PortDB.set_active(StringName(port.id))
		_expect(UpgradeDB.is_valid(),
			"the upgrade tree is sound with %s's trunk grafted on" % port.id)
		_expect(ShipCatalog.is_valid(), "and so is its fleet (%s)" % port.id)
		for item in UpgradeDB.ITEMS:
			_expect(not str(GameState.upgrade_preview(item).get("text", "")).is_empty(),
				"every node can say what it does (%s)" % item.id)
	PortDB.set_active(PortDB.HOME)
	_finished.append("table")


func _test_a_port_must_be_paid_for() -> void:
	_wipe()
	SaveManager.use_profile(SLOT)
	var cost := float(PortDB.get_port(&"long_beach").cost)
	GameState.teus = cost - 1.0
	_expect(not SaveManager.buy_port(&"long_beach"), "one TEU short buys nothing")
	_expect(not SaveManager.port_open(&"long_beach"), "and opens nothing")
	_expect(not SaveManager.use_port(&"long_beach"),
		"a port that is not open cannot be sailed to")
	_expect(not SaveManager.buy_port(&"atlantis"), "a port that does not exist is not for sale")
	GameState.teus = cost + 50.0
	_expect(SaveManager.buy_port(&"long_beach"), "the price buys the port")
	_expect(is_equal_approx(GameState.teus, 50.0), "and is taken once (%s)" % GameState.teus)
	_expect(not SaveManager.buy_port(&"long_beach"), "it cannot be bought twice")
	_expect(PortDB.open_count == 2, "the network counts two ports")
	_finished.append("purchase")


func _test_ports_keep_separate_books() -> void:
	_wipe()
	SaveManager.use_profile(SLOT)
	GameState.teus = float(PortDB.get_port(&"long_beach").cost) + 111.0
	GameState.owned["estivador"] = 4
	GameState.upgrades["luvas"] = true
	GameState.recompute()
	SaveManager.buy_port(&"long_beach")
	SaveManager.save_game()

	_expect(SaveManager.use_port(&"long_beach"), "the operator sails to Long Beach")
	_expect(PortDB.active == &"long_beach", "which is now the active port")
	_expect(is_equal_approx(GameState.teus,
		float(PortDB.get_port(&"long_beach").grant)),
		"and arrives with the working capital, not Santos's wallet (%s)" % GameState.teus)
	_expect(GameState.structure_count("estivador") == 0 and not GameState.has_upgrade("luvas"),
		"none of Santos's plant came along")
	_expect(bool(GameState.flags.get("tutorial_v2_done", false)),
		"and nobody is walked through the tour a second time")
	GameState.owned["tt"] = 2
	GameState.teus = 777.0
	SaveManager.save_game()

	_expect(SaveManager.use_port(PortDB.HOME), "and sails home")
	_expect(GameState.structure_count("estivador") == 4 and GameState.has_upgrade("luvas"),
		"to the port exactly as it was left")
	_expect(GameState.structure_count("tt") == 0, "with none of Long Beach's trucks in it")
	_expect(GameState.teus >= 111.0 and GameState.teus < 1e6,
		"and its own wallet (%s)" % GameState.teus)
	var summary := SaveManager.port_summary(SLOT, &"long_beach")
	_expect(bool(summary.get("exists", false))
		and is_equal_approx(float(summary.get("teus", 0.0)), 777.0),
		"the chart can read Long Beach's wallet without going there")
	SaveManager.use_port(&"long_beach")
	_expect(GameState.structure_count("tt") == 2, "Long Beach kept its trucks")
	_finished.append("isolation")


func _test_catalogues_follow_the_port_and_come_home() -> void:
	PortDB.set_active(PortDB.HOME)
	var home_nodes := UpgradeDB.ITEMS.size()
	var home_branches := UpgradeDB.branches().size()
	var home_name := str(StructureDB.get_item("estivador").name)
	var home_palettes := ShipCatalog.PALETTES.size()

	PortDB.set_active(&"long_beach")
	_expect(UpgradeDB.ITEMS.size() == home_nodes + PortDB.upgrades().size()
		and not PortDB.upgrades().is_empty(), "Long Beach grafts its own trunk on")
	_expect(not UpgradeDB.get_item("lb_double_stack").is_empty(),
		"with its own nodes on it")
	_expect(UpgradeDB.branches().size() == home_branches + 1, "under its own heading")
	_expect(str(StructureDB.get_item("estivador").name) != home_name,
		"a docker goes by another name there")
	_expect(PortDB.structure_mult("tt") > 1.0 and PortDB.click_mult() > 1.0,
		"and the place is good at trucks and taps")
	_expect(str(ShipCatalog.PALETTES[0].id) == "pacific_navy",
		"other liveries call at its berth")
	_expect(not ShipCatalog.get_palette(&"harbor_blue").is_empty(),
		"but a hull painted at home still finds its paint")

	PortDB.set_active(&"shanghai")
	_expect(UpgradeDB.get_item("lb_double_stack").is_empty(),
		"Long Beach's nodes do not follow the operator to Shanghai")
	_expect(not UpgradeDB.get_item("sh_agv").is_empty(), "which has its own")
	_expect(PortDB.click_mult() < 1.0 and PortDB.structure_mult("sts") > 1.0,
		"and is a port where the machines carry it")

	PortDB.set_active(PortDB.HOME)
	_expect(UpgradeDB.ITEMS.size() == home_nodes
		and UpgradeDB.branches().size() == home_branches,
		"home is exactly the tree every balance run was tuned against")
	_expect(str(StructureDB.get_item("estivador").name) == home_name
		and ShipCatalog.PALETTES.size() == home_palettes,
		"with its own names and its own fleet back")
	_expect(is_equal_approx(PortDB.structure_mult("tt"), 1.0), "and no local bias")
	_finished.append("catalogues")


func _test_the_rate_panel_still_multiplies_out() -> void:
	## `cps_breakdown` is the formula, not a caption for it. Two new factors
	## went into `recompute`; both have to be rows.
	_wipe()
	SaveManager.use_profile(SLOT)
	GameState.teus = 1e12
	SaveManager.buy_port(&"long_beach")
	SaveManager.use_port(&"long_beach")
	GameState.owned = {"estivador": 12, "tt": 7}
	GameState.recompute()
	var product := 1.0
	var labels: Array[String] = []
	for row: Dictionary in GameState.cps_breakdown():
		product *= float(row.value)
		labels.append(str(row.label))
	_expect(labels.has("Porto"), "what the port is good at has its own row")
	_expect(labels.has("Rede de portos"), "and so does the network")
	_expect(is_equal_approx(product, GameState.cps),
		"and the rows still multiply out to the rate (%s vs %s)" % [product, GameState.cps])
	_finished.append("rate")


func _test_a_profile_resumes_in_its_last_port() -> void:
	_wipe()
	SaveManager.use_profile(SLOT)
	GameState.teus = 1e12
	SaveManager.buy_port(&"long_beach")
	SaveManager.save_game()
	SaveManager.use_port(&"long_beach")
	GameState.teus = 4321.0
	SaveManager.save_game()
	# The title screen, some other day.
	SaveManager.use_profile(1)
	_expect(PortDB.active == PortDB.HOME, "another profile is at home")
	SaveManager.use_profile(SLOT)
	_expect(PortDB.active == &"long_beach" and SaveManager.active_port == &"long_beach",
		"the profile opens in the port its operator was last in")
	_expect(GameState.teus >= 4321.0 and GameState.teus < 1e6,
		"with that port's books (%s)" % GameState.teus)
	_finished.append("resume")


func _test_deleting_a_profile_takes_its_ports() -> void:
	_expect(FileAccess.file_exists(SaveManager.port_path(SLOT, &"long_beach")),
		"Long Beach has a file of its own")
	SaveManager.delete_profile(SLOT)
	_expect(not FileAccess.file_exists(SaveManager.port_path(SLOT, &"long_beach"))
		and not FileAccess.file_exists(SaveManager.profile_path(SLOT)),
		"deleting the profile takes every port with it")
	_expect((SaveManager.port_ledger(SLOT).open as Array).size() == 1,
		"and the ledger: a fresh profile owns only its home port")
	_finished.append("delete")


func _test_each_port_plays_differently() -> void:
	## Two ports abroad, each with a way of playing that changes a real system,
	## and home exactly as it was.
	PortDB.set_active(PortDB.HOME)
	var home_foreman := GameState.foreman_unlocked()
	GameState.prestige_count = 0
	_expect(not GameState.foreman_unlocked(), "at home the foreman waits for a rebuild")
	_expect(is_equal_approx(float(PortDB.port_trait("gate_cadence", 1.0)), 1.0)
		and is_equal_approx(float(PortDB.port_trait("crane_auto", 1.0)), 1.0),
		"and home has no traits at all")
	PortDB.set_active(&"long_beach")
	_expect(float(PortDB.port_trait("gate_cadence", 1.0)) < 1.0
		and float(PortDB.port_trait("rail_gap", 1.0)) < 1.0,
		"Long Beach calls lorries and trains more often")
	PortDB.set_active(&"shanghai")
	_expect(GameState.foreman_unlocked(), "Shanghai has the foreman from day one")
	GameState.owned = {"sts": 2}
	var auto := BerthCallController.pool_rate()
	PortDB.set_active(PortDB.HOME)
	var home_auto := BerthCallController.pool_rate()
	_expect(auto > home_auto * 1.5, "and its cranes work faster on their own (%s vs %s)"
		% [auto, home_auto])
	PortDB.set_active(&"shanghai")
	TimeManager.fog_active = true
	_expect(is_equal_approx(TimeManager.weather_cps_mult(), 1.0),
		"and the monsoon fog costs it nothing")
	PortDB.set_active(PortDB.HOME)
	_expect(TimeManager.weather_cps_mult() < 1.0, "where at home fog still slows the port")
	TimeManager.fog_active = false
	GameState.owned = {}
	_finished.append("traits")
	if home_foreman:
		pass


func _wipe() -> void:
	SaveManager.delete_profile(SLOT)
	SaveManager.delete_profile(1)
	GameState.from_save({})
	PortDB.set_active(PortDB.HOME)
	PortDB.open_count = 1


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
