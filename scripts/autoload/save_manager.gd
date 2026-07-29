extends Node
## Versioned, recoverable persistence.  The public yard/pending_yard API is
## retained while new systems register a named section instead.

const SAVE_VERSION := 2
const SAVE_PATH := "user://save.json"
## Three independent runs. The slot is part of the path, not of the payload, so
## a save file stays byte-identical whichever slot it came from and can be
## exported from one and imported into another.
const PROFILE_COUNT := 3
const PROFILE_DIR := "user://profiles"
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
var _last_saved_at := 0.0
var active_slot := 0
var _storage_ok := true


func _ready() -> void:
	_connect_save_events()
	probe_storage()
	# Nothing is loaded at boot any more: the title screen decides which of the
	# three profiles to open, and Main falls back to the first slot when it is
	# run on its own (F6, the capture harness, the dev probe).
	_migrate_legacy_save()


func _connect_save_events() -> void:
	EventBus.manual_reward_committed.connect(func(_payload: Dictionary) -> void: request_save(&"manual_reward"))
	# Purchases are low-frequency, high-value commits. Persist synchronously so
	# a mobile background or web reload immediately after release cannot lose
	# them. Manual cargo rewards remain debounced to support rapid tapping.
	EventBus.structure_bought.connect(func(_id: String, _count: int) -> void: save_game(&"structure_bought"))
	EventBus.upgrade_bought.connect(func(_id: String) -> void: save_game(&"upgrade_bought"))
	EventBus.land_bought.connect(func(_id: String) -> void: save_game(&"land_bought"))
	# `prestige_committed` is emitted after the career tracker has observed the
	# reset, so the immediate snapshot contains both economy and journal state.
	EventBus.prestige_committed.connect(func(_quote: Dictionary) -> void: save_game(&"prestige"))
	EventBus.prestige_tree_changed.connect(func(_id: StringName) -> void: save_game(&"prestige_tree"))
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
	# Android and iOS can kill a backgrounded app without warning, and a web
	# tab can be discarded on navigation, so every route out of the foreground
	# writes synchronously rather than waiting for the autosave tick.
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game(&"lifecycle")
	if what == NOTIFICATION_APPLICATION_RESUMED:
		# Time passed while we were away. Re-crediting from the last write is
		# the same path a cold start takes, so the two can never disagree.
		_apply_offline_progress(_last_saved_at)
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


func build_envelope() -> Dictionary:
	## The exact payload that would be written right now. Shared by save and
	## manual export so an exported file can never be a different shape from a
	## real save.
	# Preserve payloads whose providers have not registered yet. Registered
	# providers overwrite their own section with a fresh snapshot below.
	var sections: Dictionary = _loaded_sections.duplicate(true)
	for id: String in _sections:
		var snapshot: Callable = _sections[id].snapshot
		sections[id] = snapshot.call()
	# Main currently owns the yard lifecycle and has not registered it itself.
	if yard != null:
		sections["yard"] = yard.to_save()
	return {
		"save_version": SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"core": GameState.to_save(),
		"time": TimeManager.to_save(),
		"sections": sections,
	}


func save_game(reason: StringName = &"manual") -> bool:
	var envelope := build_envelope()
	var sections: Dictionary = envelope.sections
	if not _write_atomically(envelope):
		EventBus.save_finished.emit(false, reason)
		return false
	_pending = sections.duplicate(true)
	_loaded_sections = sections.duplicate(true)
	_has_loaded_game = true
	_last_saved_at = float(envelope.saved_at_unix)
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
	_last_saved_at = float(envelope.get("saved_at_unix", envelope.get("timestamp", 0.0)))
	_apply_offline_progress(_last_saved_at)


func _apply_offline_progress(saved_at: float) -> void:
	offline_earnings = 0.0
	if saved_at <= 0.0 or GameState.cps <= 0.0:
		return
	var cap_seconds := GameState.offline_cap_seconds() if GameState.has_method("offline_cap_seconds") \
		else OFFLINE_CAP_HOURS * 3600.0
	var efficiency := GameState.offline_efficiency() if GameState.has_method("offline_efficiency") \
		else OFFLINE_EFFICIENCY
	var elapsed := minf(maxf(0.0, Time.get_unix_time_from_system() - saved_at), cap_seconds)
	if elapsed > 10.0:
		offline_earnings = GameState.cps * elapsed * efficiency
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
	return data if envelope_problem(data).is_empty() else {}


static func envelope_problem(data: Dictionary) -> String:
	## The one place a payload is judged, so a file on disk and a pasted backup
	## are held to identical rules. Returns "" when the envelope is usable.
	var version := int(data.get("save_version", 1))
	if version > SAVE_VERSION:
		return "Save de uma versão mais nova (v%d)." % version
	if version >= 2:
		if not (data.get("core", null) is Dictionary
				and data.get("time", null) is Dictionary
				and data.get("sections", null) is Dictionary):
			return "Save incompleto ou corrompido."
		return ""
	# A v1 envelope was flat. Requiring the one field every v1 save carried
	# stops an empty or foreign JSON object from being read as a valid save —
	# which would silently wipe the run instead of falling back to the backup.
	if not data.has("teus"):
		return "Isso não é um save do HarborClick."
	return ""


func _tmp_path() -> String:
	return _save_path + ".tmp"


func _backup_path() -> String:
	return _save_path + ".bak"


func _recovery_path() -> String:
	return _save_path + ".recovery"


func set_save_path_for_tests(path: String) -> void:
	## Deliberately public so the headless suite can isolate its files.
	_save_path = path
	active_slot = 0


# ------------------------------------------------------------------ profiles

func profile_path(slot: int) -> String:
	return "%s/%d/save.json" % [PROFILE_DIR, clampi(slot, 1, PROFILE_COUNT)]


func use_profile(slot: int) -> bool:
	## Point every path at this slot and load it. A slot with no file is simply
	## a new game: every registered section seeds itself.
	active_slot = clampi(slot, 1, PROFILE_COUNT)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("%s/%d" % [PROFILE_DIR, active_slot]))
	_save_path = profile_path(active_slot)
	_loaded_sections.clear()
	_pending.clear()
	_has_loaded_game = false
	offline_earnings = 0.0
	GameState.from_save({})
	TimeManager.from_save({})
	return load_game()


func profile_summary(slot: int) -> Dictionary:
	## Read-only peek for the title screen: it must never apply a save or
	## credit offline progress just to draw a slot.
	var envelope := _read_valid_save(profile_path(slot))
	if envelope.is_empty():
		envelope = _read_valid_save(profile_path(slot) + ".bak")
	if envelope.is_empty():
		return {"slot": slot, "exists": false}
	var version := int(envelope.get("save_version", 1))
	var core: Dictionary = envelope.get("core", envelope) if version >= 2 else envelope
	var time: Dictionary = envelope.get("time", {}) if version >= 2 else envelope
	return {
		"slot": slot,
		"exists": true,
		"teus": float(core.get("all_time_teus", core.get("lifetime", 0.0))),
		"day": int(time.get("day", 1)),
		"prestige": int(core.get("prestige_count", 0)),
		"saved_at": float(envelope.get("saved_at_unix", 0.0)),
	}


func delete_profile(slot: int) -> void:
	var base := profile_path(slot)
	for path in [base, base + ".tmp", base + ".bak", base + ".recovery"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if active_slot == clampi(slot, 1, PROFILE_COUNT):
		active_slot = 0


func _migrate_legacy_save() -> void:
	## The single-save build wrote user://save.json. It becomes profile 1 the
	## first time this build starts, so nobody loses a run to a feature.
	if not FileAccess.file_exists(SAVE_PATH):
		return
	if FileAccess.file_exists(profile_path(1)):
		return
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("%s/1" % PROFILE_DIR))
	for suffix: String in ["", ".bak"]:
		var from: String = SAVE_PATH + suffix
		if not FileAccess.file_exists(from):
			continue
		DirAccess.copy_absolute(ProjectSettings.globalize_path(from),
			ProjectSettings.globalize_path(profile_path(1) + suffix))
	print("[save] legacy save migrated into profile 1")


# ------------------------------------------------------ manual backup / web

const EXPORT_PATH := "user://harborclick_save.json"


func storage_available() -> bool:
	## A browser can refuse `user://` entirely — private windows, blocked
	## site data, a full quota. Silently playing a run that will evaporate on
	## reload is the worst possible outcome, so this is probed at boot and the
	## answer is surfaced in Ajustes.
	return _storage_ok


func probe_storage() -> bool:
	var probe := _save_path + ".probe"
	var file := FileAccess.open(probe, FileAccess.WRITE)
	if file == null:
		_storage_ok = false
		return false
	file.store_string("ok")
	file.close()
	var back := FileAccess.open(probe, FileAccess.READ)
	_storage_ok = back != null and back.get_as_text() == "ok"
	if back != null:
		back.close()
	if FileAccess.file_exists(probe):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))
	return _storage_ok


func export_text() -> String:
	## The live state, not whatever is on disk: exporting has to capture the
	## run the player is actually in.
	return JSON.stringify(build_envelope(), "  ")


func export_to_file(path: String = EXPORT_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(export_text())
	file.flush()
	file.close()
	return true


func import_text(text: String) -> Dictionary:
	## Validated against exactly the same rules a save file on disk has to
	## pass, then written through the normal atomic path so a bad paste can
	## never leave the primary save half-written.
	var json := JSON.new()
	if json.parse(text.strip_edges()) != OK:
		return {"ok": false, "error": "Isso não é um save (JSON inválido)."}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {"ok": false, "error": "Isso não é um save do HarborClick."}
	var envelope: Dictionary = parsed
	var problem := envelope_problem(envelope)
	if not problem.is_empty():
		return {"ok": false, "error": problem}
	if not _write_atomically(envelope):
		return {"ok": false, "error": "Não foi possível gravar o save."}
	_apply_loaded(envelope)
	EventBus.save_finished.emit(true, &"import")
	return {"ok": true, "error": ""}
