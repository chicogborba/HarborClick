extends Node
## Local opt-in telemetry: off means no-op (no file, no provider call); on
## means the provider gets batches and the JSONL mirror is written and capped.
## Run with: Godot --headless --path . res://tests/telemetry_test_runner.tscn

class RecordingProvider extends TelemetryProvider:
	var batches: Array = []

	func deliver(events: Array) -> void:
		batches.append(events)


const EXPECTED := ["opt_out", "opt_in", "mirror", "cap"]

var failures: Array[String] = []
var _done: Array[String] = []
var _provider := RecordingProvider.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveManager.set_save_path_for_tests("user://harborclick_telemetry_test.json")
	SaveManager.wipe()
	if FileAccess.file_exists("user://telemetry.jsonl"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://telemetry.jsonl"))
	Telemetry.provider = _provider

	UserPreferences.telemetry_on = false
	Telemetry.track(&"session_start", {"day": 1})
	Telemetry._flush()
	_expect(_provider.batches.is_empty(), "opted out: the provider hears nothing")
	_expect(not FileAccess.file_exists("user://telemetry.jsonl"),
		"opted out: no mirror file is written")
	_done.append("opt_out")

	UserPreferences.set_telemetry_on(true)
	expect_true(UserPreferences.telemetry_on, "the preference persists the opt-in")
	for i in 10:
		Telemetry.track(&"level_up", {"level": i + 2})
	_expect(_provider.batches.size() == 1 and _provider.batches[0].size() == 8,
		"events batch at 8 and reach the provider")
	Telemetry._flush()
	_expect(_provider.batches.size() == 2, "the tail flushes on demand")
	_expect(FileAccess.file_exists("user://telemetry.jsonl"),
		"opted in: the local mirror exists")
	var text := FileAccess.get_file_as_string("user://telemetry.jsonl")
	_expect(text.count("level_up") == 10, "the mirror holds all 10 events")
	_done.append("opt_in")
	_done.append("mirror")

	# Cap: write past MAX_LINES and trim.
	for i in 2100:
		Telemetry.track(&"ad_shown", {"placement": "wheel_spin"})
	Telemetry._flush()
	text = FileAccess.get_file_as_string("user://telemetry.jsonl")
	var lines := text.split("\n", false)
	_expect(lines.size() <= Telemetry.MAX_LINES,
		"the mirror is capped at %d lines (got %d)" % [Telemetry.MAX_LINES, lines.size()])
	_done.append("cap")

	UserPreferences.set_telemetry_on(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://telemetry.jsonl"))
	SaveManager.wipe()
	if failures.is_empty():
		print("TELEMETRY TESTS PASSED (%d tests)" % EXPECTED.size())
		get_tree().quit(0)
	else:
		for f in failures:
			push_error(f)
		print("TELEMETRY TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func expect_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
