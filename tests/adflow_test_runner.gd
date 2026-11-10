extends Node
## Where the game offers a rewarded ad, end to end with a fake provider: the
## wheel (a spin when there is none, doubling a cash prize), the offline return
## and skipping a build. Each pays exactly once, each is optional, and a refused
## or failed ad pays nothing.
## Run with: Godot --headless --path . res://tests/adflow_test_runner.tscn

const EXPECTED := ["wheel_spin", "wheel_double", "offline", "build", "refused",
	"minigame_play"]

class FakeProvider extends AdProvider:
	var auto_reward := true
	var calls: Array[StringName] = []

	func show_rewarded(placement: StringName) -> void:
		calls.append(placement)
		finished.emit(placement, auto_reward)

var failures: Array[String] = []
var _done_tests: Array[String] = []
var _fake := FakeProvider.new()
var _real: AdProvider


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests("user://harborclick_adflow_test.json")
	SaveManager.wipe()
	GameState.from_save({})
	UserPreferences.reduce_motion = true
	AdService.policy.restore(AdPolicy.seed_new(AdService._current_day()))
	AdService.set_provider(_fake)
	await _test_an_ad_buys_a_wheel_spin()
	await _test_an_ad_doubles_a_cash_prize()
	_test_an_ad_doubles_the_offline_return()
	_test_an_ad_finishes_a_build()
	await _test_a_refused_ad_pays_nothing()
	_test_minigame_play_caps_at_three_a_day()
	for name in EXPECTED:
		_expect(_done_tests.has(name), "test '%s' ran to its last line" % name)
	GameState.from_save({})
	SaveManager.wipe()
	if failures.is_empty():
		print("ADFLOW TESTS PASSED (%d tests: %s)" % [EXPECTED.size(), ", ".join(EXPECTED)])
		get_tree().quit(0)
	else:
		for f in failures:
			push_error(f)
		print("ADFLOW TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _wheel_panel() -> Array:
	var service := WheelService.new()
	add_child(service)
	var panel := LuckyWheelPanel.new()
	panel.setup(service)
	add_child(panel)
	await get_tree().process_frame
	return [service, panel]


func _test_an_ad_buys_a_wheel_spin() -> void:
	var pair: Array = await _wheel_panel()
	var service: WheelService = pair[0]
	var panel: LuckyWheelPanel = pair[1]
	# No free spin (a day away) and no tokens.
	service.wheel.next_free_unix = Time.get_unix_time_from_system() + 3600.0
	service.wheel.tokens = 0
	panel._refresh_status()
	_expect(panel._ad_spin_button.visible, "with nothing to spin with, the ad spin is offered")
	var spins := service.wheel.spins_total
	_fake.calls.clear()
	panel._on_ad_spin()
	_expect(_fake.calls == [&"wheel_spin"], "it asked for the wheel_spin placement")
	_expect(service.wheel.spins_total == spins + 1, "and the ad paid for exactly one spin")
	panel.finish_now()
	service.queue_free()
	panel.queue_free()
	await get_tree().process_frame
	_done_tests.append("wheel_spin")


func _test_an_ad_doubles_a_cash_prize() -> void:
	var pair: Array = await _wheel_panel()
	var service: WheelService = pair[0]
	var panel: LuckyWheelPanel = pair[1]
	panel._last_amount = 500.0
	panel._reveal({"id": &"cash_m", "kind": &"cash", "seconds": 360.0})
	_expect(panel._ad_double_button.visible, "a cash prize offers doubling")
	var before := GameState.teus
	panel._on_ad_double()
	_expect(is_equal_approx(GameState.teus - before, 500.0), "the ad pays the amount again, once")
	_expect(not panel._ad_double_button.visible, "and the offer is gone")
	panel._last_amount = 0.0
	panel._reveal({"id": &"surge2", "kind": &"surge", "mult": 2.0, "seconds": 90.0})
	_expect(not panel._ad_double_button.visible, "a surge has no honest doubling")
	service.queue_free()
	panel.queue_free()
	await get_tree().process_frame
	_done_tests.append("wheel_double")


func _test_an_ad_doubles_the_offline_return() -> void:
	GameState.from_save({})
	var before := GameState.teus
	SaveManager.offline_earnings = 1000.0
	SaveManager.offline_report = {"away_seconds": 3600.0, "credited_seconds": 3600.0,
		"capped_seconds": 0.0, "cap_seconds": 28800.0, "efficiency": 0.5, "rate": 1.0,
		"earnings": 1000.0, "lost_to_cap": 0.0}
	var popup := OfflinePopup.new()
	add_child(popup)
	var double := _find_button(popup, Loc.t("offline.double"))
	_expect(double != null, "the return offers to double it")
	if double != null:
		double.pressed.emit()
	_expect(is_equal_approx(GameState.teus - before, 1000.0), "an ad credits the amount again")
	_done_tests.append("offline")


func _test_an_ad_finishes_a_build() -> void:
	GameState.from_save({"teus": 1e9})
	GameState.build_times_enabled = true
	GameState.buy_structure_bulk("estivador")
	_expect(GameState.builds.size() == 1, "a build is under way")
	var hud := BuildHud.new()
	add_child(hud)
	hud.refresh()
	hud._on_ad(0)
	GameState._process(0.01)
	_expect(GameState.builds.is_empty() and GameState.structure_count("estivador") == 1,
		"the ad finished it")
	GameState.build_times_enabled = false
	hud.queue_free()
	_done_tests.append("build")


func _test_a_refused_ad_pays_nothing() -> void:
	var pair: Array = await _wheel_panel()
	var service: WheelService = pair[0]
	var panel: LuckyWheelPanel = pair[1]
	service.wheel.next_free_unix = Time.get_unix_time_from_system() + 3600.0
	service.wheel.tokens = 0
	_fake.auto_reward = false
	var spins := service.wheel.spins_total
	panel._on_ad_spin()
	_expect(service.wheel.spins_total == spins, "a closed ad gives no spin")
	_fake.auto_reward = true
	service.queue_free()
	panel.queue_free()
	await get_tree().process_frame
	_done_tests.append("refused")


func _test_minigame_play_caps_at_three_a_day() -> void:
	## The Arcade key on the Diário buys one minigame per rewarded ad, and the
	# policy caps it at 3 a day: the fourth press is refused and pays nothing.
	AdService.policy.restore(AdPolicy.seed_new(AdService._current_day()))
	AdService.set_provider(_fake)
	_fake.auto_reward = true
	var paid := [0]
	var offered := 0
	for i in 4:
		if AdService.show_rewarded(&"minigame_play", func() -> void: paid[0] += 1):
			offered += 1
	_expect(offered == 3 and paid[0] == 3,
		"minigame_play is offered exactly 3 times a day (offered %d, paid %d)"
		% [offered, paid[0]])
	_expect(not AdService.available(&"minigame_play"),
		"the fourth arcade play is refused by the daily cap")
	_expect(AdService.remaining_today(&"minigame_play") == 0,
		"the remaining counter reads zero at the cap")
	_fake.auto_reward = false
	AdService.policy.restore(AdPolicy.seed_new(AdService._current_day()))
	var refused := [0]
	if AdService.show_rewarded(&"minigame_play", func() -> void: refused[0] += 1):
		pass
	_expect(refused[0] == 0, "a refused minigame_play ad pays nothing")
	_done_tests.append("minigame_play")


func _find_button(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text == text:
		return root
	for child in root.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
