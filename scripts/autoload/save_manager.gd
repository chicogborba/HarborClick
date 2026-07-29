extends Node
## JSON save/load with autosave and offline progress.

const SAVE_PATH := "user://save.json"
const AUTOSAVE_INTERVAL := 30.0
const OFFLINE_CAP_HOURS := 8.0
const OFFLINE_EFFICIENCY := 0.5

var offline_earnings: float = 0.0   # shown by UI on load, if > 0

var _timer := 0.0


var _pending: Dictionary = {}


func _ready() -> void:
	load_game()


func pending_yard() -> Array:
	return _pending.get("yard", [])


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= AUTOSAVE_INTERVAL:
		_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()


var yard: ContainerYard        # set by Main so the stacks survive a restart


func save_game() -> void:
	var data := GameState.to_save()
	data["timestamp"] = Time.get_unix_time_from_system()
	data["day"] = TimeManager.day
	data["time_of_day"] = TimeManager.time_of_day
	if yard != null:
		data["yard"] = yard.to_save()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null or not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	_pending = data
	GameState.from_save(data)
	TimeManager.day = int(data.get("day", 1))
	TimeManager.time_of_day = data.get("time_of_day", 0.3)
	# offline progress
	var then: float = data.get("timestamp", 0.0)
	if then > 0.0 and GameState.cps > 0.0:
		var elapsed: float = Time.get_unix_time_from_system() - then
		elapsed = minf(elapsed, OFFLINE_CAP_HOURS * 3600.0)
		if elapsed > 10.0:
			offline_earnings = GameState.cps * elapsed * OFFLINE_EFFICIENCY
			GameState.teus += offline_earnings
			GameState.lifetime_teus += offline_earnings
			EventBus.teus_changed.emit(GameState.teus)


func wipe() -> void:
	## Clears the save so the next scene load starts a fresh terminal.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_pending.clear()
	offline_earnings = 0.0
	GameState.from_save({})
	GameState.flags.clear()
	TimeManager.day = 1
	TimeManager.time_of_day = 0.3
