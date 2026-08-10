extends Node
## The options board.
## Run with:
## Godot --headless --path . res://tests/settings_test_runner.tscn
##
## Two things this suite exists to hold down. First, that the controls are
## controls: a volume track that a finger can actually set, not a bar that only
## looks like one. Second, that the board survives a language change while it is
## open — the one screen guaranteed to be in front of the player at the moment
## the language switches is the one that switched it.

var failures: Array[String] = []
var _finished: Array[String] = []
var _panel: SettingsPanel
var _restore: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_restore = {
		"music_on": AudioManager.music_on, "sfx_on": AudioManager.sfx_on,
		"music": AudioManager.music_volume, "sfx": AudioManager.sfx_volume,
		"language": Loc.preference, "motion": UserPreferences.reduce_motion,
		"scale": UserPreferences.ui_scale,
	}
	# Never the player's own mixer config: this suite deliberately mutes things.
	AudioManager.set_settings_path_for_tests("user://harborclick_audio_test.cfg")
	# Off, so nothing here tries to open an audio device, and no open animation
	# outlives the panel when the runner tears it down.
	AudioManager.set_sfx_on(false)
	AudioManager.set_music_on(false)
	UserPreferences.set_reduce_motion(true)

	_panel = SettingsPanel.new()
	add_child(_panel)
	await get_tree().process_frame
	_panel.apply_view_metrics({
		"profile": "portrait",
		"viewport_size": Vector2(320.0, 480.0),
		"safe_rect": Rect2(Vector2.ZERO, Vector2(320.0, 480.0)),
	})
	_panel.open()
	await get_tree().process_frame
	await get_tree().process_frame

	await _test_a_volume_is_a_level_not_a_switch()
	await _test_dragging_the_track_sets_the_level()
	await _test_mute_remembers_the_level_it_silenced()
	await _test_every_option_shows_all_of_its_answers()
	await _test_switching_language_redraws_the_board()
	await _test_the_board_fits_a_small_phone()

	_panel.queue_free()
	# Deletion is deferred to the end of a frame, and the ObjectDB leak report
	# runs at quit — one frame is not enough for the board's own children.
	for i in 3:
		await get_tree().process_frame
	_restore_state()

	var expected := 6
	if _finished.size() != expected:
		failures.append("only %d of %d tests reached their last line (%s)"
			% [_finished.size(), expected, ", ".join(_finished)])
	if failures.is_empty():
		print("SETTINGS TESTS PASSED (levels, drag, mute, segments, language, fit)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("SETTINGS TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _restore_state() -> void:
	AudioManager.set_music_volume(float(_restore.music))
	AudioManager.set_sfx_volume(float(_restore.sfx))
	AudioManager.set_music_on(bool(_restore.music_on))
	AudioManager.set_sfx_on(bool(_restore.sfx_on))
	UserPreferences.set_reduce_motion(bool(_restore.motion))
	UserPreferences.set_ui_scale(float(_restore.scale))
	Loc.apply(StringName(_restore.language))


func _slider(channel: StringName) -> PixelSlider:
	return _panel._sliders.get(channel) as PixelSlider


func _test_a_volume_is_a_level_not_a_switch() -> void:
	## The whole point of the rewrite: "quieter" used to have exactly one
	## implementation, and it was "silent".
	for channel: StringName in [&"music", &"sfx"]:
		_expect(_slider(channel) != null,
			"%s has a level control, not just a mute key" % channel)
	AudioManager.set_music_on(true)
	AudioManager.set_music_volume(0.35)
	_panel._refresh()
	_expect(is_equal_approx(_slider(&"music").value, 0.35),
		"the track shows the level the mixer is actually at")
	var level: Label = _panel._levels.get(&"music")
	_expect(level != null and level.text == "35%",
		"and the number beside it says so in percent (%s)"
			% (level.text if level != null else "no label"))
	# Levels are stepped so a player can land on the same one twice.
	AudioManager.set_music_volume(0.333)
	_expect(is_equal_approx(AudioManager.music_volume, 0.35),
		"a level snaps to a step rather than to an arbitrary fraction")
	_finished.append("levels")


func _test_dragging_the_track_sets_the_level() -> void:
	## Driven through the viewport, because the risk in a hand-written control is
	## exactly that it draws correctly and receives nothing.
	AudioManager.set_music_volume(0.0)
	_panel._refresh()
	await get_tree().process_frame
	var slider := _slider(&"music")
	var rect := slider.get_global_rect()
	# Three quarters along the track.
	var target := Vector2(rect.position.x + rect.size.x * 0.75,
		rect.get_center().y)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = target
	press.global_position = target
	get_viewport().push_input(press, true)
	await get_tree().process_frame
	_expect(AudioManager.music_volume > 0.6 and AudioManager.music_volume < 0.9,
		"pressing three quarters along the track sets roughly three quarters (%.2f)"
			% AudioManager.music_volume)

	# And it tracks the finger rather than only jumping once.
	var drag := Vector2(rect.position.x + rect.size.x * 0.25, rect.get_center().y)
	var motion := InputEventMouseMotion.new()
	motion.position = drag
	motion.global_position = drag
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	_expect(AudioManager.music_volume < 0.4,
		"and dragging back down follows (%.2f)" % AudioManager.music_volume)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = drag
	release.global_position = drag
	get_viewport().push_input(release, true)
	await get_tree().process_frame

	# Keyboard, for anyone not using a finger.
	slider.grab_focus()
	var before := AudioManager.music_volume
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	get_viewport().push_input(key, true)
	await get_tree().process_frame
	_expect(AudioManager.music_volume > before,
		"the right arrow raises the level for a keyboard user")
	_finished.append("drag")


func _test_mute_remembers_the_level_it_silenced() -> void:
	AudioManager.set_music_volume(0.6)
	AudioManager.set_music_on(true)
	_panel._refresh()
	_panel._on_mute(&"music", "Música")
	_expect(not AudioManager.music_on, "the mute key silences the channel")
	_expect(is_equal_approx(AudioManager.music_volume, 0.6),
		"without throwing away the level it was set to")
	var level: Label = _panel._levels.get(&"music")
	# Never colour or opacity alone: the word has to say it too.
	_expect(level != null and level.text == Loc.t("settings.muted"),
		"and the row says so in words")
	_panel._on_mute(&"music", "Música")
	_expect(AudioManager.music_on and is_equal_approx(AudioManager.music_volume, 0.6),
		"un-muting brings back the same level")

	# A channel muted at zero must not come back inaudible: that is a key that
	# visibly does nothing.
	AudioManager.set_music_volume(0.0)
	AudioManager.set_music_on(false)
	_panel._on_mute(&"music", "Música")
	_expect(AudioManager.music_on and AudioManager.music_volume > 0.0,
		"un-muting a channel left at zero comes back audible (%.2f)"
			% AudioManager.music_volume)
	AudioManager.set_music_on(false)
	_finished.append("mute")


func _test_every_option_shows_all_of_its_answers() -> void:
	## The old board was cycling keys: one value visible, the rest discoverable
	## only by pressing and watching. A segmented control is the fix, and the
	## contract is that the segment count equals the number of real answers.
	_expect(_panel._segments.get(&"ui_scale", []).size()
			== UserPreferences.UI_SCALE_PRESETS.size(),
		"the interface scale shows every preset at once")
	_expect(_panel._segments.get(&"motion", []).size() == 2,
		"motion shows both of its answers")
	_expect(_panel._segments.get(&"language", []).size()
			== Loc.LANGUAGES.size() + 1,
		"the language picker shows every language plus 'follow the device'")

	UserPreferences.set_reduce_motion(true)
	_panel._refresh()
	var lit := 0
	for entry: Dictionary in _panel._segments[&"motion"]:
		var button: Button = entry.button
		if button.accessibility_name.ends_with(Loc.t("common.on")):
			lit += 1
			_expect(bool(entry.value) == true,
				"the lit motion segment is the one that is actually set")
	_expect(lit == 1, "exactly one answer is marked as chosen")
	UserPreferences.set_reduce_motion(false)
	_finished.append("segments")


func _test_switching_language_redraws_the_board() -> void:
	Loc.apply(&"pt_BR")
	_panel._rebuild_deferred()
	await get_tree().process_frame
	var wipe_pt: Button = _panel._wipe_btn
	_expect(wipe_pt.text == Loc.t("settings.wipe"),
		"the board is written in the current language")
	var portuguese := wipe_pt.text

	# Through the real path: pressing a language segment.
	for entry: Dictionary in _panel._segments[&"language"]:
		if StringName(entry.value) != &"en":
			continue
		(entry.button as Button).emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(Loc.language == &"en", "pressing a language segment switches to it")
	_expect(is_instance_valid(_panel._wipe_btn)
			and _panel._wipe_btn.text != portuguese,
		"and the open board is rewritten rather than waiting for a restart")
	_expect(_panel._wipe_btn.text == "ERASE PROGRESS",
		"in the language that was chosen (%s)" % _panel._wipe_btn.text)

	# Following the device is itself a choice the picker can express.
	Loc.set_preference(Loc.FOLLOW_DEVICE)
	await get_tree().process_frame
	_expect(Loc.preference == Loc.FOLLOW_DEVICE
			and Loc.language == Loc.device_language(),
		"and 'follow the device' hands control back to the phone")
	_finished.append("language")


func _test_the_board_fits_a_small_phone() -> void:
	## 320 logical pixels is the narrowest the game is built for, and a stacked
	## row is what makes a long translation safe there. A board that reports a
	## minimum width wider than the phone is a board with a cut-off control.
	for scale: float in UserPreferences.UI_SCALE_PRESETS:
		UserPreferences.set_ui_scale(scale)
		for code in [&"pt_BR", &"en", &"es"]:
			Loc.apply(code)
			_panel._rebuild_deferred()
			await get_tree().process_frame
			await get_tree().process_frame
			var content_width: float = _panel._content.custom_minimum_size.x
			var needed: float = _panel._content.get_combined_minimum_size().x
			_expect(needed <= content_width + 0.5,
				"at %d%% in %s the board needs %.0fpx and has %.0fpx"
					% [roundi(scale * 100.0), code, needed, content_width])
			_expect(_panel._panel.get_global_rect().size.x <= 320.0,
				"and the board itself is no wider than the phone")
			# The scrollbar eats its width out of the content area, so a row can
			# be inside the panel and still have its last characters underneath
			# the bar. Checked on the widest row rather than on the panel.
			var visible_right: float = _panel._scroll.get_global_rect().end.x \
				- UiTheme.SCROLL_WIDTH
			for channel: StringName in [&"music", &"sfx"]:
				var level: Label = _panel._levels.get(channel)
				if level == null:
					continue
				_expect(level.get_global_rect().end.x <= visible_right + 0.5,
					"at %d%% in %s the %s readout is clear of the scrollbar"
						% [roundi(scale * 100.0), code, channel])
	UserPreferences.set_ui_scale(1.0)
	Loc.apply(&"pt_BR")
	_finished.append("fit")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
