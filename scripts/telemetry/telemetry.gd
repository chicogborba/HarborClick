extends Node
## Local, opt-in telemetry (plano-release R5).
##
## Every event is a line of JSON in `user://telemetry.jsonl` — on the player's
## own device, readable by them, deletable by wiping the profile. Nothing is
## sent anywhere: `TelemetryProvider` is the seam where a real backend would
## go, and the placeholder keeps the contract. Opt-in lives in
## `UserPreferences.telemetry_on` (default OFF) and the toggle in Ajustes
## says exactly that.
##
## Events tracked: tutorial steps, time-to-each-level, ads watched per
## placement, and session start/return (D1/D7 retention) — the funnel the
## release plan needs before any real analytics provider is plugged in.

const PATH := "user://telemetry.jsonl"
const MAX_LINES := 2000


func _ready() -> void:
	provider = PlaceholderTelemetryProvider.new()


var provider: TelemetryProvider
var _buffer: Array[Dictionary] = []


func track(event: StringName, props: Dictionary = {}) -> void:
	## No-op while the player has not opted in — the flag is checked here, at
	# the single entry point, so no call site can forget it.
	if not UserPreferences.telemetry_on:
		return
	var entry := {"event": String(event), "at": Time.get_unix_time_from_system(),
		"props": props}
	_buffer.append(entry)
	if _buffer.size() >= 8:
		_flush()


func _flush() -> void:
	if _buffer.is_empty():
		return
	var batch := _buffer.duplicate(true)
	_buffer.clear()
	if provider != null:
		provider.deliver(batch)
	# Local mirror: the file is the player's own copy of what was "sent".
	var file := FileAccess.open(PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	for entry in batch:
		file.store_line(JSON.stringify(entry))
	file.close()
	_trim()


func _trim() -> void:
	## Keep the file bounded: read the tail, rewrite. Telemetry is a debugging
	# aid, not an archive.
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var lines := file.get_as_text().split("\n", false)
	file.close()
	if lines.size() <= MAX_LINES:
		return
	var kept := lines.slice(lines.size() - MAX_LINES)
	file = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	for line in kept:
		file.store_line(line)
	file.close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_flush()
