extends Node
## Player-facing preferences kept separate from the progression save.
##
## A temporary file in the same directory is renamed over the live file, so a
## quit or power loss cannot leave a partially-written preferences.cfg behind.

signal changed(key: StringName)
signal ui_scale_changed(scale: float)
signal fullscreen_changed(enabled: bool)

const CONFIG_PATH := "user://preferences.cfg"
const TEMP_PATH := "user://preferences.cfg.tmp"
const BACKUP_PATH := "user://preferences.cfg.bak"
const RECOVERY_PATH := "user://preferences.cfg.recovery"
const UI_SCALE_PRESETS := [0.90, 1.00, 1.15]

var reduce_motion := false
var floating_numbers := true
var ui_scale := 1.00
var fullscreen := false
## Which language the interface is in, or `Loc.FOLLOW_DEVICE` for "whatever the
## phone says". Kept here rather than in the save because it is a fact about the
## player and their device, not about any one terminal — switching profiles must
## not switch the language back.
var language: StringName = &"auto"
## Which terminal the player was last in. Lives here rather than in a save file
## because it is a fact about the *player*, not about any one run — and the title
## screen has to answer "continue where?" before any profile is loaded.
var last_profile := 0
var _config_path := CONFIG_PATH
var _temp_path := TEMP_PATH
var _backup_path := BACKUP_PATH
var _recovery_path := RECOVERY_PATH


func _ready() -> void:
	load_preferences()
	_apply_fullscreen()
	_apply_ui_scale()


func load_preferences() -> void:
	var config: ConfigFile
	var source := ""
	for path in [_config_path, _backup_path, _recovery_path, _temp_path]:
		var candidate := ConfigFile.new()
		if candidate.load(path) == OK and _config_is_usable(candidate):
			config = candidate
			source = path
			break
	if config == null:
		return
	reduce_motion = bool(config.get_value("preferences", "reduce_motion", reduce_motion))
	floating_numbers = bool(config.get_value("preferences", "floating_numbers", floating_numbers))
	ui_scale = _safe_ui_scale(float(config.get_value("preferences", "ui_scale", ui_scale)))
	fullscreen = bool(config.get_value("preferences", "fullscreen", fullscreen))
	last_profile = clampi(int(config.get_value("preferences", "last_profile",
		last_profile)), 0, 9)
	# Absent from every file written before the game had more than one language,
	# and the honest answer for those saves is the one a fresh install gets: ask
	# the device.
	language = StringName(config.get_value("preferences", "language", "auto"))
	if source != _config_path:
		var result := save_preferences()
		if result != OK:
			push_warning("Could not promote recovered preferences (error %d)" % result)


func _config_is_usable(config: ConfigFile) -> bool:
	if config == null or not config.has_section("preferences"):
		return false
	for key in ["reduce_motion", "floating_numbers", "ui_scale", "fullscreen"]:
		if not config.has_section_key("preferences", key):
			return false
	for key in ["reduce_motion", "floating_numbers", "fullscreen"]:
		if not config.get_value("preferences", key) is bool:
			return false
	var raw_scale: Variant = config.get_value("preferences", "ui_scale")
	if not (raw_scale is float or raw_scale is int):
		return false
	var scale := float(raw_scale)
	return is_finite(scale) and is_equal_approx(_safe_ui_scale(scale), scale)


func set_reduce_motion(value: bool) -> void:
	if reduce_motion == value:
		return
	reduce_motion = value
	_commit(&"reduce_motion")


func set_floating_numbers(value: bool) -> void:
	if floating_numbers == value:
		return
	floating_numbers = value
	_commit(&"floating_numbers")


func set_ui_scale(value: float) -> void:
	var safe_value := _safe_ui_scale(value)
	if is_equal_approx(ui_scale, safe_value):
		return
	ui_scale = safe_value
	_apply_ui_scale()
	ui_scale_changed.emit(ui_scale)
	_commit(&"ui_scale")


func cycle_ui_scale() -> void:
	var index := UI_SCALE_PRESETS.find(ui_scale)
	if index < 0:
		index = UI_SCALE_PRESETS.find(_safe_ui_scale(ui_scale))
	set_ui_scale(UI_SCALE_PRESETS[(index + 1) % UI_SCALE_PRESETS.size()])


func set_fullscreen(value: bool) -> void:
	if fullscreen == value:
		return
	fullscreen = value
	_apply_fullscreen()
	fullscreen_changed.emit(fullscreen)
	_commit(&"fullscreen")


func set_language(code: StringName) -> void:
	if language == code:
		return
	language = code
	_commit(&"language")


func set_last_profile(slot: int) -> void:
	if last_profile == slot:
		return
	last_profile = slot
	_commit(&"last_profile")


func can_animate() -> bool:
	return not reduce_motion


func _safe_ui_scale(value: float) -> float:
	var nearest := UI_SCALE_PRESETS[0]
	var distance := absf(value - nearest)
	for preset: float in UI_SCALE_PRESETS:
		var candidate_distance := absf(value - preset)
		if candidate_distance < distance:
			nearest = preset
			distance = candidate_distance
	return nearest


func _apply_ui_scale() -> void:
	## Configure the root Window explicitly instead of relying only on imported
	## project defaults. Web builds can keep a root window alive while a new PWA
	## package activates; in that case its old integer-stretch policy survived
	## and centred a 320px game inside a wider phone canvas. Reasserting the
	## complete contract here makes every boot fractional and edge-to-edge.
	if DisplayServer.get_name() == "headless":
		return
	var root := get_tree().root
	# Desktop/headed QA can resize the root window after autoloads enter the
	# tree. Replacing all of its content-scale properties there would restore
	# the authored 640×960 override during title captures. The stale-root issue
	# is specific to the long-lived browser/PWA runtime.
	if OS.has_feature("web"):
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		root.content_scale_size = Vector2i(320, 480)
	root.content_scale_factor = ui_scale


func _apply_fullscreen() -> void:
	## Godot 4.7 uses DisplayServer window modes, rather than the old OS API.
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)


func _commit(key: StringName) -> void:
	var result := save_preferences()
	if result != OK:
		push_warning("Could not save preference %s (error %d)" % [key, result])
	changed.emit(key)


func save_preferences() -> Error:
	var config := ConfigFile.new()
	config.set_value("preferences", "reduce_motion", reduce_motion)
	config.set_value("preferences", "floating_numbers", floating_numbers)
	config.set_value("preferences", "ui_scale", ui_scale)
	config.set_value("preferences", "fullscreen", fullscreen)
	config.set_value("preferences", "last_profile", last_profile)
	config.set_value("preferences", "language", String(language))
	var result := config.save(_temp_path)
	if result != OK:
		return result
	var live := ProjectSettings.globalize_path(_config_path)
	var temporary := ProjectSettings.globalize_path(_temp_path)
	var backup := ProjectSettings.globalize_path(_backup_path)
	var recovery := ProjectSettings.globalize_path(_recovery_path)
	if FileAccess.file_exists(_recovery_path):
		DirAccess.remove_absolute(recovery)
	if FileAccess.file_exists(_config_path):
		# Keep the known-good backup in place until the new live file exists.
		# The current live is staged separately so every interruption point has
		# at least one valid candidate for load_preferences().
		result = DirAccess.rename_absolute(live, recovery)
		if result != OK:
			return result
	result = DirAccess.rename_absolute(temporary, live)
	if result != OK:
		if FileAccess.file_exists(_recovery_path):
			DirAccess.rename_absolute(recovery, live)
		return result
	if FileAccess.file_exists(_recovery_path):
		var previous := ConfigFile.new()
		if previous.load(_recovery_path) == OK and _config_is_usable(previous):
			if FileAccess.file_exists(_backup_path):
				DirAccess.remove_absolute(backup)
			DirAccess.rename_absolute(recovery, backup)
		else:
			DirAccess.remove_absolute(recovery)
	return OK


func set_config_path_for_tests(path: String) -> void:
	## Allows the headless suite to exercise crash recovery without touching the
	## player's real preferences.
	_config_path = path
	_temp_path = path + ".tmp"
	_backup_path = path + ".bak"
	_recovery_path = path + ".recovery"
