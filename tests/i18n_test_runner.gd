extends Node
## Translations.
## Run with:
## Godot --headless --path . res://tests/i18n_test_runner.tscn
##
## A translation table fails quietly: a key nobody filled in for Spanish is an
## English sentence in the middle of a Spanish screen, and nothing crashes. So
## the parity rules are checked here rather than trusted — every key in every
## language, and every `{slot}` the same in all of them, because a translation
## that drops a placeholder prints a price with no number in it.

var failures: Array[String] = []
var _finished: Array[String] = []
var _restore_preference := Loc.FOLLOW_DEVICE


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_restore_preference = Loc.preference

	_test_every_key_speaks_every_language()
	_test_placeholders_survive_translation()
	_test_plurals_have_both_forms()
	_test_the_device_decides_by_default()
	_test_choosing_a_language_changes_the_words()
	_test_an_unknown_language_falls_back_rather_than_breaking()
	_test_the_font_can_draw_every_translated_character()
	await _test_translations_fit_the_controls_that_show_them()

	Loc.apply(_restore_preference)
	var expected := 8
	if _finished.size() != expected:
		failures.append("only %d of %d tests reached their last line (%s)"
			% [_finished.size(), expected, ", ".join(_finished)])
	if failures.is_empty():
		print("I18N TESTS PASSED (parity, placeholders, plurals, device, fallback, glyphs, fit)")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("I18N TESTS FAILED: %d assertion(s)" % failures.size())
		get_tree().quit(1)


func _codes() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in Loc.LANGUAGES:
		out.append(StringName(entry.code))
	return out


func _tables() -> Array[Dictionary]:
	return [LocStringsUi.STRINGS, LocStringsContent.STRINGS]


func _test_every_key_speaks_every_language() -> void:
	var codes := _codes()
	_expect(codes.size() >= 3, "the game is translated into at least three languages")
	for table in _tables():
		for key: String in table:
			var row: Dictionary = table[key]
			for code in codes:
				_expect(row.has(code),
					"'%s' has a %s translation" % [key, code])
				_expect(not str(row.get(code, "")).strip_edges().is_empty(),
					"'%s' in %s is not blank" % [key, code])
			for present: String in row:
				_expect(codes.has(StringName(present)),
					"'%s' has no stray language column (%s)" % [key, present])
	_finished.append("parity")


func _test_placeholders_survive_translation() -> void:
	## `{cost}` dropped from one language is a price with no number in it, and
	## `{coste}` invented in another is a literal brace on screen.
	var pattern := RegEx.new()
	pattern.compile("\\{[a-z_]+\\}")
	for table in _tables():
		for key: String in table:
			var row: Dictionary = table[key]
			var reference: Array[String] = []
			var reference_code := ""
			for code in _codes():
				var slots: Array[String] = []
				for found in pattern.search_all(str(row.get(code, ""))):
					var slot := found.get_string()
					if not slots.has(slot):
						slots.append(slot)
				slots.sort()
				if reference_code.is_empty():
					reference = slots
					reference_code = String(code)
					continue
				_expect(slots == reference,
					"'%s' uses the same slots in %s as in %s (%s vs %s)"
						% [key, code, reference_code, slots, reference])
	_finished.append("placeholders")


func _test_plurals_have_both_forms() -> void:
	for table in _tables():
		for key: String in table:
			if not key.ends_with(".one"):
				continue
			var stem := key.substr(0, key.length() - 4)
			_expect(table.has("%s.other" % stem),
				"'%s' has an 'other' form to go with its 'one'" % stem)
	# And the helper picks between them.
	for code in _codes():
		Loc.apply(code)
		_expect(Loc.tn("routes.count", 1) != Loc.tn("routes.count", 3),
			"%s says one route and several routes differently" % code)
		_expect(Loc.tn("routes.count", 1).contains("1"),
			"%s puts the number in the singular form" % code)
	_finished.append("plurals")


func _test_the_device_decides_by_default() -> void:
	## The mapping, not `OS.get_locale()` itself — the runner cannot change what
	## the machine is set to, and the part worth pinning is that every language
	## the table knows about resolves to something we can actually show.
	for prefix: String in Loc.DEVICE_MAP:
		var resolved := StringName(Loc.DEVICE_MAP[prefix])
		_expect(Loc.is_supported(resolved),
			"device language '%s' maps onto a language we have (%s)"
				% [prefix, resolved])
	_expect(Loc.is_supported(Loc.device_language()),
		"this machine's language resolves to something showable")
	Loc.apply(Loc.FOLLOW_DEVICE)
	_expect(Loc.preference == Loc.FOLLOW_DEVICE,
		"following the device is a state the game can be in")
	_expect(Loc.language == Loc.device_language(),
		"and following it means showing what it asked for")
	_finished.append("device")


func _test_choosing_a_language_changes_the_words() -> void:
	Loc.apply(&"pt_BR")
	var portuguese := Loc.t("settings.title")
	var portuguese_route := RouteDB.display_name("prata")
	Loc.apply(&"en")
	_expect(Loc.t("settings.title") != portuguese,
		"the settings title is not the same word in English and Portuguese")
	_expect(Loc.t("settings.title") == "SETTINGS",
		"and it is the English one")
	_expect(RouteDB.display_name("prata") != portuguese_route,
		"content follows the language too, not just the chrome")
	Loc.apply(&"es")
	_expect(Loc.t("settings.section.danger") == "ZONA DE RIESGO",
		"Spanish is served from the Spanish column")
	_finished.append("switching")


func _test_an_unknown_language_falls_back_rather_than_breaking() -> void:
	Loc.apply(&"xx_YY")
	_expect(Loc.preference == Loc.FOLLOW_DEVICE,
		"a language we do not have is not accepted as a preference")
	_expect(Loc.is_supported(Loc.language),
		"and the game is still showing a language it has")
	Loc.apply(&"en")
	_expect(Loc.t("no.such.key.exists") == "no.such.key.exists",
		"a missing key returns the key rather than an empty label")
	_finished.append("fallback")


func _test_the_font_can_draw_every_translated_character() -> void:
	## The interface is one bitmap font. A translation containing a glyph that
	## font has never heard of does not fail loudly — it draws nothing, and a
	## Spanish question mark quietly disappears. Adding a language means adding
	## its letters to `tools/sprites/gen_font.py`, and this is what says so.
	var font: FontFile = UiTheme.FONT
	var missing: Dictionary = {}
	# `{slot}` never reaches the screen — it is replaced by a number or a name
	# before the label is set — so the braces themselves are not glyphs the font
	# needs.
	var slots := RegEx.new()
	slots.compile("\\{[a-z_]+\\}")
	for table in _tables():
		for key: String in table:
			for code: String in table[key]:
				for character in slots.sub(str(table[key][code]), "", true):
					var unicode := character.unicode_at(0)
					if font.has_char(unicode) or unicode == 10:
						continue
					missing["%s (%s in '%s')" % [character, code, key]] = true
	_expect(missing.is_empty(),
		"the pixel font has a glyph for every translated character; missing: %s"
			% ", ".join(missing.keys()))
	_finished.append("glyphs")


func _test_translations_fit_the_controls_that_show_them() -> void:
	## A translated word is longer than the one it replaced, and the tab strip
	## clips rather than wraps — so "UPGRADES" quietly rendered as "UPGRADE" and
	## looked like a word rather than like a bug. The shop's tabs are the
	## tightest text in the game: five of them share a 320px board with a glyph
	## on each, which makes them the right canary for every other strip.
	var shop := Shop.new()
	add_child(shop)
	await get_tree().process_frame
	shop.apply_view_metrics({
		"profile": "portrait",
		"viewport_size": Vector2(320.0, 480.0),
		"safe_rect": Rect2(Vector2.ZERO, Vector2(320.0, 480.0)),
	})
	shop._launcher.emit_signal("pressed")
	await get_tree().process_frame
	# Every tab shown at once, which is the narrowest each one ever gets. The
	# orders tab is hidden on a one-berth port, and a hidden control takes no
	# share of the row — measuring it there would pass the whole strip on the
	# strength of a tab nobody can see.
	for tab: Array in Shop.TABS:
		var button: Button = shop._tab_buttons.get(tab[0])
		if button != null:
			button.visible = true
	await get_tree().process_frame
	await get_tree().process_frame

	for code in _codes():
		Loc.apply(code)
		for tab: Array in Shop.TABS:
			var button: Button = shop._tab_buttons.get(tab[0])
			if button == null:
				continue
			button.text = Loc.t(str(tab[1]))
			var needed := UiTheme.FONT.get_string_size(button.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x
			# The glyph and the theme's own padding come out of the same width.
			var glyph := 12.0 + 4.0
			_expect(needed + glyph <= button.size.x + 0.5,
				"in %s the '%s' tab needs %.0fpx and has %.0fpx"
					% [code, button.text, needed + glyph, button.size.x])
	shop.queue_free()
	for i in 3:
		await get_tree().process_frame

	# The language picker itself is the other tight strip, and the one most
	# exposed to this exact failure: it grows by one segment every time a
	# language is added, so the room per segment only ever shrinks. This is
	# what caught "AUTO" silently clipping to "AU" the day the sixth language
	# landed — `clip_text` swallows an overflow instead of reporting it as a
	# minimum-size violation, so nothing upstream of a direct measurement like
	# this one would ever see it.
	var settings := SettingsPanel.new()
	add_child(settings)
	await get_tree().process_frame
	settings.apply_view_metrics({
		"safe_rect": Rect2(Vector2.ZERO, Vector2(320.0, 480.0))})
	settings.open()
	await get_tree().process_frame
	await get_tree().process_frame
	for code in _codes():
		Loc.apply(code)
		settings._build_body()
		settings._layout()
		await get_tree().process_frame
		for entry: Dictionary in settings._segments.get(&"language", []):
			var button: Button = entry.button
			if button == null or not is_instance_valid(button):
				continue
			var needed := UiTheme.FONT.get_string_size(button.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_SMALL).x
			_expect(needed <= button.size.x + 0.5,
				"in %s the language tag '%s' needs %.0fpx and has %.0fpx"
					% [code, button.text, needed, button.size.x])
	settings.queue_free()
	for i in 3:
		await get_tree().process_frame
	_finished.append("fit")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
