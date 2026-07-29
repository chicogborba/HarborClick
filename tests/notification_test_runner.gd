extends Node
## Notification policy suite.
## Run with:
## Godot --headless --path . res://tests/notification_test_runner.tscn
##
## Every system used to emit straight into ToastLayer, so three big banners
## could stack over the port and a routine berth phase competed with a career
## milestone. These are the rules that replaced that.

var failures: Array[String] = []
var _coordinator: NotificationCoordinator
var _shown: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_coordinator = NotificationCoordinator.new()
	add_child(_coordinator)
	_coordinator.presented.connect(func(notice: Dictionary) -> void:
		_shown.append(notice))
	await get_tree().process_frame

	_test_routine_state_never_becomes_a_banner()
	_test_repeats_collapse_into_one_banner()
	_test_one_at_a_time_and_priority_order()
	_test_history_keeps_everything()

	if failures.is_empty():
		print("NOTIFICATION TESTS PASSED (routing, dedupe, priority, history)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("NOTIFICATION TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _test_routine_state_never_becomes_a_banner() -> void:
	_reset()
	for kind in NotificationCoordinator.ROUTINE_KINDS:
		var notice := _coordinator.submit({
			"kind": kind, "text": "Navio se aproximando"})
		_expect(notice.outcome == &"routine",
			"%s is routed as routine state, not a banner" % kind)
	_coordinator._process(0.0)
	_expect(_shown.is_empty(),
		"routine state produces no toast — the berth chip is its display")
	_expect(_coordinator.history.size() == NotificationCoordinator.ROUTINE_KINDS.size(),
		"routine state is still recorded in the history")


func _test_repeats_collapse_into_one_banner() -> void:
	_reset()
	var first := _coordinator.submit({
		"id": "berth_import_yard_full", "kind": &"blocked", "text": "Pátio cheio."})
	_expect(first.outcome == &"queued", "the first refusal queues a banner")
	var collapsed := {}
	for repeat in 9:
		collapsed = _coordinator.submit({
			"id": "berth_import_yard_full", "kind": &"blocked", "text": "Pátio cheio."})
	_expect(collapsed.outcome == &"collapsed" and int(collapsed.count) == 10,
		"ten taps on a blocked yard collapse into one banner counting ten")
	_coordinator._process(0.0)
	_expect(_shown.size() == 1,
		"a collapsed repeat never opens a second banner")


func _test_one_at_a_time_and_priority_order() -> void:
	_reset()
	_coordinator.submit({"id": "first", "kind": &"info", "text": "primeiro"})
	_expect(_shown.size() == 1 and str(_shown[0].text) == "primeiro",
		"an arriving notice shows at once when the screen is free")

	# While that banner is up, two more arrive. Nothing may appear beside it.
	_coordinator.submit({"id": "low", "kind": &"info", "text": "rotina"})
	_coordinator.submit({"id": "high", "kind": &"milestone", "priority": 2,
		"text": "marco"})
	_coordinator._process(0.0)
	_expect(_shown.size() == 1, "only one banner is ever on screen")

	# The queue may not advance until the banner is gone *and* the spacing
	# window has passed, so notices can never machine-gun.
	_coordinator.notify_shown_finished()
	_expect(_shown.size() == 1,
		"the queue does not advance before the spacing window elapses")
	_coordinator._process(NotificationCoordinator.MIN_SPACING + 0.01)
	_expect(_shown.size() == 2 and str(_shown[1].text) == "marco",
		"a milestone jumps ahead of the routine notice queued before it")
	_coordinator.notify_shown_finished()
	_coordinator._process(NotificationCoordinator.MIN_SPACING + 0.01)
	_expect(_shown.size() == 3 and str(_shown[2].text) == "rotina",
		"the lower-priority notice still gets its turn afterwards")


func _test_history_keeps_everything() -> void:
	_reset()
	for index in NotificationCoordinator.HISTORY_MAX + 12:
		_coordinator.submit({"id": "n%d" % index, "kind": &"info",
			"text": "aviso %d" % index})
	_expect(_coordinator.history.size() == NotificationCoordinator.HISTORY_MAX,
		"the history is capped instead of growing without bound")
	_expect(str(_coordinator.history[0].text)
			== "aviso %d" % (NotificationCoordinator.HISTORY_MAX + 11),
		"the newest occurrence is at the front of the history")


func _reset() -> void:
	_coordinator.clear()
	_coordinator._clock = 1000.0
	_coordinator._last_presented_at = -1000.0
	_shown.clear()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
