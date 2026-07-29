extends Node
## Versioned, recoverable persistence.  The public yard/pending_yard API is
## retained while new systems register a named section instead.

const SAVE_VERSION := 2
const SAVE_PATH := "user://save.json"
const AUTOSAVE_INTERVAL := 30.0
const SAVE_DEBOUNCE := 0.35
const OFFLINE_CAP_HOURS := 8.0
const OFFLINE_EFFICIENCY := 0.5

var offline_earnings: float = 0.0
var yard: ContainerYard # set by Main; kept for integration compatibility

var _timer := 0.0
var _save_due := -1.0
var _save_reason: StringName = &"manual"
var _pending: Dictionary = {}
var _sections: Dictionary = {} # id -> {snapshot, restore, seed_new}
var _loaded_sections: Dictionary = {}
var _has_loaded_game := false
var _save_path := SAVE_PATH


func _ready() -> void:
	_connect_save_events()
	# Test runners choose an isolated path during their first deferred frame.
	# Loading user://save.json here would migrate/credit the player's real save
	# before the runner can redirect us.
	for argument in OS.get_cmdline_args():
		if str(argument).contains("res://tests/"):
			return
	load_game()


func _connect_save_events() -> void:
	EventBus.manual_reward_committed.connect(func(_payload: Dictionary) -> void: request_save(&"manual_reward"))
	# Purchases are low-frequency, high-value commits. Persist synchronously so
	# a mobile background or web reload immediately after release cannot lose
	# them. Manual cargo rewards remain debounced to support rapid tapping.
	EventBus.structure_bought.connect(func(_id: String, _count: int) -> void: save_game(&"structure_bought"))
	EventBus.upgrade_bought.connect(func(_id: String) -> void: save_game(&"upgrade_bought"))
	EventBus.land_bought.connect(func(_id: String) -> void: save_game(&"land_bought"))
	EventBus.prestiged.connect(func(_shares: int) -> void: save_game(&"prestige"))
	EventBus.new_day.connect(func(_day: int) -> void: request_save(&"new_day"))


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= AUTOSAVE_INTERVAL:
		_timer = 0.0
		request_save(&"autosave")
	if _save_due >= 0.0:
		_save_due -= delta
		if _save_due <= 0.0:
			_save_due = -1.0
			save_game(_save_reason)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game(&"lifecycle")
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func register_section(id: StringName, snapshot: Callable, restore: Callable, seed_new: Callable = Callable()) -> void:
	## Registration is safe after load: the saved payload is restored immediately.
	var section_id := String(id)
	if section_id.is_empty() or not snapshot.is_valid() or not restore.is_valid():
		push_error("SaveManager.register_section requires id, snapshot and restore")
		return
	_sections[section_id] = {"snapshot": snapshot, "restore": restore, "seed_new": seed_new}
	if _loaded_sections.has(section_id):
		restore.call(_loaded_sections[section_id])
	elif seed_new.is_valid():
		# This also covers migration from v1 (or an older v2 payload) where a
		# newly introduced provider has no persisted section yet.
		seed_new.call()


func request_save(reason: StringName = &"manual") -> void:
	## Coalesces bursts of events while retaining the most recent save reason.
	_save_reason = reason
	if _save_due < 0.0:
		_save_due = SAVE_DEBOUNCE


func pending_yard() -> Array:
	return _loaded_sections.get("yard", _pending.get("yard", []))


func save_game(reason: StringName = &"manual") -> bool:
	# Preserve payloads whose providers have not registered yet. Registered
	# providers overwrite their own section with a fresh snapshot below.
	var sections: Dictionary = _loaded_sections.duplicate(true)
	for id: String in _sections:
		var snapshot: Callable = _sections[id].snapshot
		sections[id] = snapshot.call()
	# Main currently owns the yard lifecycle and has not registered it itself.
	if yard != null:
		sections["yard"] = yard.to_save()
	var envelope := {
		"save_version": SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"core": GameState.to_save(),
		"time": TimeManager.to_save(),
		"sections": sections,
	}
	if not _write_atomically(envelope):
		EventBus.save_finished.emit(false, reason)
		return false
	_pending = sections.duplicate(true)
	_loaded_sections = sections.duplicate(true)
	_has_loaded_game = true
	EventBus.save_finished.emit(true, reason)
	return true


func load_game() -> bool:
	var result := _read_valid_save(_save_path)
	var recovered := false
	if result.is_empty():
		result = _read_valid_save(_backup_path())
		recovered = not result.is_empty()
	if result.is_empty():
		_has_loaded_game = false
		return false
	if recovered:
		# Repair the primary before applying offline progress. Otherwise the
		# offline checkpoint would rotate the corrupt primary over the valid
		# backup, and promoting the old envelope afterwards could credit the same
		# interval again on every reload.
		var promoted := _promote_recovered_envelope(result)
		EventBus.save_finished.emit(promoted, &"recovery")
		if not promoted:
			return false
		EventBus.save_recovered.emit(&"backup")
	_apply_loaded(result)
	return true


func _apply_loaded(envelope: Dictionary) -> void:
	var version := int(envelope.get("save_version", 1))
	var core: Dictionary
	var time: Dictionary
	var sections: Dictionary
	if version >= 2:
		core = envelope.get("core", {})
		time = envelope.get("time", {})
		sections = envelope.get("sections", {})
	else:
		# v1 was flat: core fields plus timestamp/day/time_of_day/yard.
		core = envelope.duplicate(true)
		time = {"day": envelope.get("day", 1), "time_of_day": envelope.get("time_of_day", 0.3), "fog_active": envelope.get("fog_active", false)}
		sections = {}
		if envelope.has("yard"):
			sections["yard"] = envelope.yard
	GameState.from_save(core)
	TimeManager.from_save(time)
	# Core is restored before time; recompute once the persisted weather is in
	# place so CPS and offline earnings use the right multiplier.
	GameState.recompute()
	_loaded_sections = sections.duplicate(true)
	_pending = _loaded_sections
	_has_loaded_game = true
	for id: String in _sections:
		if _loaded_sections.has(id):
			var restore: Callable = _sections[id].restore
			restore.call(_loaded_sections[id])
	_apply_offline_progress(float(envelope.get("saved_at_unix", envelope.get("timestamp", 0.0))))


func _apply_offline_progress(saved_at: float) -> void:
	offline_earnings = 0.0
	if saved_at <= 0.0 or GameState.cps <= 0.0:
		return
	var elapsed := minf(maxf(0.0, Time.get_unix_time_from_system() - saved_at), OFFLINE_CAP_HOURS * 3600.0)
	if elapsed > 10.0:
		offline_earnings = GameState.cps * elapsed * OFFLINE_EFFICIENCY
		GameState.grant_offline_earnings(offline_earnings)
		# Advance saved_at before the popup is shown. A reload during the popup
		# can no longer credit the same offline interval twice.
		save_game(&"offline_credit")


func wipe() -> void:
	## Removes primary, temporary and backup files, then resets every registered
	## section that supplied a new-game seed.
	for path in [_save_path, _tmp_path(), _backup_path(), _recovery_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_pending.clear()
	_loaded_sections.clear()
	_has_loaded_game = false
	offline_earnings = 0.0
	_save_due = -1.0
	_save_reason = &"manual"
	GameState.from_save({})
	TimeManager.from_save({})
	for id: String in _sections:
		var seed_new: Callable = _sections[id].seed_new
		if seed_new.is_valid():
			seed_new.call()


func _write_atomically(data: Dictionary) -> bool:
	var tmp := _tmp_path()
	if not _write_temporary_envelope(data, tmp):
		return false
	var absolute_save := ProjectSettings.globalize_path(_save_path)
	var absolute_tmp := ProjectSettings.globalize_path(tmp)
	var absolute_backup := ProjectSettings.globalize_path(_backup_path())
	if FileAccess.file_exists(_backup_path()):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(_save_path):
		if DirAccess.rename_absolute(absolute_save, absolute_backup) != OK:
			return false
	if DirAccess.rename_absolute(absolute_tmp, absolute_save) != OK:
		if FileAccess.file_exists(_backup_path()):
			DirAccess.rename_absolute(absolute_backup, absolute_save)
		return false
	return true


func _promote_recovered_envelope(data: Dictionary) -> bool:
	## Repairs only the primary path. The known-good backup is never rotated,
	## overwritten, or removed during recovery.
	var tmp := _tmp_path()
	if not _write_temporary_envelope(data, tmp):
		return false
	var recovery_path := _recovery_path()
	var absolute_save := ProjectSettings.globalize_path(_save_path)
	var absolute_tmp := ProjectSettings.globalize_path(tmp)
	var absolute_recovery := ProjectSettings.globalize_path(recovery_path)
	if FileAccess.file_exists(recovery_path):
		DirAccess.remove_absolute(absolute_recovery)
	if FileAccess.file_exists(_save_path):
		if DirAccess.rename_absolute(absolute_save, absolute_recovery) != OK:
			return false
	if DirAccess.rename_absolute(absolute_tmp, absolute_save) != OK:
		if FileAccess.file_exists(recovery_path):
			DirAccess.rename_absolute(absolute_recovery, absolute_save)
		return false
	if FileAccess.file_exists(recovery_path):
		DirAccess.remove_absolute(absolute_recovery)
	return true


func _write_temporary_envelope(data: Dictionary, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open temporary save")
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	return true


func _read_valid_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return {}
	var data: Dictionary = parsed
	var version := int(data.get("save_version", 1))
	if version > SAVE_VERSION:
		return {}
	if version >= 2 and (not (data.get("core", null) is Dictionary) or not (data.get("time", null) is Dictionary) or not (data.get("sections", null) is Dictionary)):
		return {}
	return data


func _tmp_path() -> String:
	return _save_path + ".tmp"


func _backup_path() -> String:
	return _save_path + ".bak"


func _recovery_path() -> String:
	return _save_path + ".recovery"


func set_save_path_for_tests(path: String) -> void:
	## Deliberately public so the headless suite can isolate its files.
	_save_path = path
