class_name SettingsPanel
extends CanvasLayer
## Options board: sound, language, presentation, backup, and the one
## irreversible button in the game.
##
## Two rewrites of history are worth stating, because both were real usability
## faults rather than taste:
##
## 1. **Every option was a mystery key.** A row read "Música ... DESLIGADA" and
##    the only way to find out what any other setting could be was to press it
##    and watch. Cycling keys hide the option set: you cannot see that the
##    interface scale has three steps, or which one you are on relative to the
##    others. Every option with a small fixed set of answers is a segmented
##    control now — all the answers visible, the current one lit, one tap to any
##    other.
## 2. **Sound was on or off.** That is not a volume control, it is a mute
##    switch, and "the music is a bit loud" had exactly one answer: silence.
##    Music and effects each have a real level now, in percent, with the mute
##    key kept beside it because a mute that remembers your level is worth having
##    on its own.
##
## 3. **One long scroll was the whole board.** Sound, language, display, save
##    data and the wipe key were a single column you scrolled through to find
##    anything, on a board that opened at the top every time. It is four pages
##    now behind icon tabs (SOM, TELA, IDIOMA, DADOS), each option on its own
##    card, and the title and tabs stay put while a page scrolls. The language
##    page is a grid of flags with each language's name in that language —
##    two-letter codes were a puzzle for exactly the player who needed them.
##
## Everything is stacked — caption, then a full-width control — rather than laid
## out as label-left/value-right. At 320 logical pixels, with the interface scale
## at 115% and a language whose word for "interface scale" is longer than the
## Portuguese one, a side-by-side row is one translation away from overflowing
## the board. A stacked row cannot.

signal open_changed(opened: bool)
signal tutorial_replay_requested

const ROW_HEIGHT := 26.0
const SEGMENT_HEIGHT := 24.0
## Tallest the board grows. Pages differ in length; the board does not change
## size as you flip between them, so it is a fixed height, capped by the phone.
const BOARD_MAX_H := 560.0
const TAB_HEIGHT := 40.0
const TILE_HEIGHT := 46.0
const LANGUAGE_COLUMNS := 3
## page id, tab label key, icon
const TABS := [
	[&"sound", "settings.tab.sound", UiTheme.Icon.SOUND],
	[&"display", "settings.tab.display", UiTheme.Icon.GEAR],
	[&"language", "settings.tab.language", UiTheme.Icon.GLOBE],
	[&"data", "settings.tab.data", UiTheme.Icon.LOCK],
]
const FLAGS := preload("res://assets/sprites/ui_flags.png")
## Flags at 2x, cut once: the language grid is rebuilt on every language change.
static var _flag_cache: Dictionary = {}

var _dim: ColorRect
var _panel: PanelContainer
var _column: VBoxContainer
## Nameplate and tabs: outside the scroll, so they never scroll away.
var _top: VBoxContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _tab: StringName = &"sound"
var _tab_keys: Dictionary = {}   # page id -> Button
var _pages: Dictionary = {}      # page id -> VBoxContainer
var _confirm_wipe := false
var _confirm_import := false
var _wipe_btn: Button
var _backup_status: Label
var _backup_message := ""
var _backup_tone := UiTheme.INK_SOFT
var _safe_rect := Rect2()
var _focus_return: Control
## Controls the refresh pass writes to. Rebuilt wholesale whenever the language
## changes, so nothing here survives a rebuild and nothing may be cached beyond
## it — see `_build_body`.
var _segments: Dictionary = {}   # group name -> Array[Dictionary]
var _sliders: Dictionary = {}    # channel -> PixelSlider
var _mutes: Dictionary = {}      # channel -> Button
var _levels: Dictionary = {}     # channel -> Label
var _language_note: Label


func _ready() -> void:
	layer = 11
	_build()
	get_viewport().size_changed.connect(_layout)
	# A language switch has to be visible immediately, and the panel that
	# switched it is the one screen guaranteed to be open when it happens.
	Loc.language_changed.connect(_on_language_changed)
	visible = false


func _build() -> void:
	_dim = UiTheme.scrim(0.62)
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch and event.pressed) \
				or (event is InputEventMouseButton and event.pressed):
			close())
	add_child(_dim)

	_panel = PanelContainer.new()
	UiTheme.apply_panel(_panel, UiTheme.board_style(9, &"steel"))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 4)
	_panel.add_child(_column)
	_top = VBoxContainer.new()
	_top.add_theme_constant_override(&"separation", 4)
	_column.add_child(_top)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.style_scroll(_scroll)
	_column.add_child(_scroll)

	# The scrollbar is drawn inside the scroll container's own rect, and with the
	# horizontal mode disabled the child is stretched to the container's full
	# width regardless — so the last few pixels of every row sit underneath the
	# bar. Reserving that gutter explicitly is the only version of this that does
	# not depend on ScrollContainer's internal arithmetic.
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override(&"margin_right",
		int(UiTheme.SCROLL_WIDTH))
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(gutter)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override(&"separation", 3)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_child(_content)
	_build_body()


func _build_body() -> void:
	## Everything below the board itself, rebuilt from scratch on a language
	## change. Re-setting the text of every label instead would mean keeping a
	## reference to each one *and* to each accessible name, tooltip and hint —
	## three parallel bookkeeping tasks whose failure mode is a screen that is
	## half translated. A settings board is opened by hand and never refreshed
	## per frame, so rebuilding it is free where it would be a bug elsewhere.
	for holder: Node in [_top, _content]:
		for child in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	_segments.clear()
	_sliders.clear()
	_mutes.clear()
	_levels.clear()
	_tab_keys.clear()
	_pages.clear()

	_top.add_child(_header())
	_top.add_child(_tabs_row())

	for spec: Array in TABS:
		var page := VBoxContainer.new()
		page.add_theme_constant_override(&"separation", 6)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(page)
		_pages[spec[0]] = page

	# SOM
	var sound: VBoxContainer = _pages[&"sound"]
	sound.add_child(_card(_volume_row(&"music", Loc.t("settings.music"))))
	sound.add_child(_card(_volume_row(&"sfx", Loc.t("settings.sfx"))))

	# TELA
	var display: VBoxContainer = _pages[&"display"]
	display.add_child(_card(_motion_row()))
	display.add_child(_card(_numbers_row()))
	display.add_child(_card(_ui_scale_row()))
	if _fullscreen_supported():
		display.add_child(_card(_fullscreen_row()))

	# IDIOMA
	_pages[&"language"].add_child(_language_row())

	# DADOS
	var data: VBoxContainer = _pages[&"data"]
	data.add_child(_caption(Loc.t("settings.section.port"), UiTheme.Icon.CRANE))
	var port := VBoxContainer.new()
	port.add_theme_constant_override(&"separation", 4)
	var tutorial := _wide_button(Loc.t("settings.tutorial"), &"ghost")
	UiTheme.describe(tutorial, Loc.t("settings.tutorial"),
		Loc.t("settings.tutorial.hint"))
	tutorial.pressed.connect(func() -> void: tutorial_replay_requested.emit())
	port.add_child(tutorial)
	port.add_child(_note(Loc.t("settings.day_note",
		{"minutes": roundi(TimeManager.DAY_LENGTH / 60.0)})))
	# The cap has to be readable *before* the player leaves. Announcing it only
	# on return turns a designed limit into production that vanished overnight.
	port.add_child(_note(Loc.t("settings.offline_note", {
		"percent": roundi(GameState.offline_efficiency() * 100.0),
		"duration": OfflinePopup.format_duration(GameState.offline_cap_seconds()),
	})))
	data.add_child(_card(port))
	data.add_child(_card(_telemetry_row()))

	data.add_child(_caption(Loc.t("settings.section.save"), UiTheme.Icon.LOCK))
	var backup := VBoxContainer.new()
	backup.add_theme_constant_override(&"separation", 4)
	backup.add_child(_backup_row())
	_backup_status = _note("")
	backup.add_child(_backup_status)
	data.add_child(_card(backup))

	data.add_child(_caption(Loc.t("settings.section.danger"), UiTheme.Icon.CLOSE,
		UiTheme.DANGER))
	# The only irreversible action on the board carries the only warning colour
	# and needs a second press to arm.
	var danger := VBoxContainer.new()
	danger.add_theme_constant_override(&"separation", 4)
	_wipe_btn = _wide_button(Loc.t("settings.wipe"), &"danger")
	UiTheme.describe(_wipe_btn, Loc.t("settings.wipe"),
		Loc.t("settings.wipe.hint"))
	_wipe_btn.pressed.connect(_on_wipe)
	danger.add_child(_wipe_btn)
	danger.add_child(_note(Loc.t("settings.wipe.hint")))
	data.add_child(_card(danger, &"locked"))

	_show_tab(_tab, false)
	_refresh()


func _tabs_row() -> Control:
	## Four index keys under the nameplate. Icon over word: side by side, the
	## longest word in the longest language ran out of key before it ran out of
	## letters on a 320-pixel phone.
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 3)
	for spec: Array in TABS:
		var id: StringName = spec[0]
		var key := Button.new()
		key.text = Loc.t(str(spec[1]))
		key.icon = UiTheme.icon_texture(spec[2])
		key.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		key.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.clip_text = true
		key.focus_mode = Control.FOCUS_ALL
		key.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.apply_font(key, UiTheme.SIZE_SMALL)
		UiTheme.describe(key, key.text)
		key.pressed.connect(func() -> void:
			AudioManager.play_sfx("tap")
			_show_tab(id))
		row.add_child(key)
		_tab_keys[id] = key
	return row


func _show_tab(id: StringName, animate: bool = true) -> void:
	if not _pages.has(id):
		id = &"sound"
	var turned := animate and id != _tab and visible
	_tab = id
	for page_id: StringName in _pages:
		(_pages[page_id] as Control).visible = page_id == id
	for key_id: StringName in _tab_keys:
		var key: Button = _tab_keys[key_id]
		var active := key_id == id
		UiTheme.style_tab(key, active)
		# The lit tab is the only one whose glyph is coloured, and the only one
		# whose accessible name says so: never colour alone.
		for slot: StringName in [&"icon_normal_color", &"icon_hover_color",
				&"icon_focus_color", &"icon_pressed_color"]:
			key.add_theme_color_override(slot,
				UiTheme.TEAL_DEEP if active else UiTheme.INK_SOFT)
		key.accessibility_name = "%s%s" % [key.text,
			(", %s" % Loc.t("common.on")) if active else ""]
	_scroll.scroll_vertical = 0
	_layout()
	# Wrapped notes only know their height once they have their width.
	_layout.call_deferred()
	if turned and UserPreferences.can_animate():
		var page: Control = _pages[id]
		page.modulate.a = 0.0
		var tween := page.create_tween()
		tween.tween_property(page, "modulate:a", 1.0, 0.14)


func _card(child: Control, state: StringName = &"normal") -> Control:
	## One option, one label: a slip of manifest paper on the board.
	var card := UiTheme.panel(UiTheme.card_style(state), false)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(child)
	return card


# ------------------------------------------------------------------- pieces

func _header() -> Control:
	## Title and an escape hatch on the same line. A board this tall is scrolled
	## away from its bottom button most of the time, so the close key has to be
	## somewhere that does not depend on where the player happens to be.
	var header := UiTheme.header(Loc.t("settings.title"), close, UiTheme.Icon.GEAR)
	var key: Button = header.close
	key.tooltip_text = Loc.t("common.close_hint")
	UiTheme.describe(key, Loc.t("settings.close_name"))
	return header.root


func _caption(text: String, glyph: UiTheme.Icon,
		tone: Color = UiTheme.TEAL_DEEP) -> Control:
	## A section heading with a picture on it. The icon is what makes the board
	## scannable: six identical teal words down the left edge are six things you
	## have to read before you know which one you wanted.
	var block := VBoxContainer.new()
	block.add_theme_constant_override(&"separation", 1)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(UiTheme.spacer(4.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := UiTheme.icon(glyph)
	badge.modulate = tone
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var label := UiTheme.label(text, UiTheme.SIZE_SMALL, tone)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	block.add_child(row)
	block.add_child(UiTheme.divider())
	return block


func _note(text: String) -> Label:
	var label := UiTheme.label(text, UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# A wrapped Label reports its longest *word* as a minimum width, not its
	# longest line, but a long unbroken path in the export message can still push
	# the board wider than the phone. Let it be laid out narrow and wrap.
	label.custom_minimum_size.x = 0.0
	label.visible = not text.is_empty()
	return label


func _field(name_text: String, control: Control,
		hint: String = "") -> Control:
	## One setting: what it is called, what it is set to, and — where it earns
	## the line — what the answer means.
	var block := VBoxContainer.new()
	block.add_theme_constant_override(&"separation", 2)
	var label := UiTheme.label(name_text, UiTheme.SIZE_SMALL, UiTheme.INK)
	block.add_child(label)
	block.add_child(control)
	if not hint.is_empty():
		var note := UiTheme.label(hint, UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = 0.0
		block.add_child(note)
	return block


func _segmented(group: StringName, options: Array, on_pick: Callable) -> Control:
	## Every answer visible at once, the current one lit. `options` is a list of
	## `{value, text, name, hint}`; `value` is handed back to `on_pick`.
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	row.custom_minimum_size.y = SEGMENT_HEIGHT
	var entries: Array = []
	for option: Dictionary in options:
		var button := UiTheme.segment(str(option.get("text", "")), false)
		button.custom_minimum_size.y = SEGMENT_HEIGHT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		UiTheme.describe(button, str(option.get("name", option.get("text", ""))),
			str(option.get("hint", "")))
		button.pressed.connect(on_pick.bind(option.get("value")))
		row.add_child(button)
		entries.append({"button": button, "value": option.get("value")})
	_segments[group] = entries
	return row


func _refresh_segments(group: StringName, current: Variant) -> void:
	for entry: Dictionary in _segments.get(group, []):
		var button: Button = entry.button
		if not is_instance_valid(button):
			continue
		var active: bool = entry.value == current
		UiTheme.style_segment(button, active)
		# Which one is chosen must never be carried by colour alone. The lit
		# segment is also the only one whose accessible name says so, and the
		# sprite behind it is a different shape, not a different tint.
		button.accessibility_name = "%s%s" % [button.tooltip_text,
			(", %s" % Loc.t("common.on")) if active else ""]


# ------------------------------------------------------------------ sound

func _volume_row(channel: StringName, name_text: String) -> Control:
	## Name and level on the first line, mute key and track on the second. One
	## line would fit on a 320px board in Portuguese and stop fitting the moment
	## the interface scale went up or the language got longer.
	var block := VBoxContainer.new()
	block.add_theme_constant_override(&"separation", 2)

	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 4)
	var glyph := UiTheme.icon(UiTheme.Icon.SOUND)
	glyph.modulate = UiTheme.TEAL_DEEP
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(glyph)
	var label := UiTheme.label(name_text, UiTheme.SIZE_SMALL, UiTheme.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	var level := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER_DEEP)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Wide enough for the longest thing it ever says, which is the word for
	# "muted" rather than "100%".
	level.custom_minimum_size.x = 52.0
	head.add_child(level)
	_levels[channel] = level
	block.add_child(head)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	row.custom_minimum_size.y = ROW_HEIGHT
	var mute := UiTheme.icon_button(UiTheme.Icon.SOUND, &"alt", ROW_HEIGHT)
	mute.custom_minimum_size = Vector2(30.0, ROW_HEIGHT)
	mute.pressed.connect(_on_mute.bind(channel, name_text))
	_mutes[channel] = mute
	row.add_child(mute)

	var slider := PixelSlider.new(_channel_volume(channel),
		AudioManager.VOLUME_STEP)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.accessible_label = name_text
	slider.tooltip_text = Loc.t("settings.volume_hint")
	slider.accessibility_description = Loc.t("settings.volume_hint")
	slider.value_changed.connect(_on_volume.bind(channel))
	# A preview only when the drag ends. Firing a sound on every step of a drag
	# is not feedback, it is a machine gun.
	slider.drag_finished.connect(func(_v: float) -> void:
		if channel == &"sfx":
			AudioManager.play_sfx("tap"))
	_sliders[channel] = slider
	row.add_child(slider)
	block.add_child(row)
	return block


func _channel_volume(channel: StringName) -> float:
	return AudioManager.music_volume if channel == &"music" \
		else AudioManager.sfx_volume


func _channel_muted(channel: StringName) -> bool:
	return not (AudioManager.music_on if channel == &"music"
		else AudioManager.sfx_on)


func _on_volume(value: float, channel: StringName) -> void:
	if channel == &"music":
		AudioManager.set_music_volume(value)
	else:
		AudioManager.set_sfx_volume(value)
	# Dragging a muted channel's level is unambiguously a request to hear it.
	if value > 0.0 and _channel_muted(channel):
		_set_channel_muted(channel, false)
	_refresh()


func _on_mute(channel: StringName, name_text: String) -> void:
	var muted := _channel_muted(channel)
	_set_channel_muted(channel, not muted)
	# Un-muting a channel whose level is zero would be a key that visibly does
	# nothing, so it comes back at a level you can hear.
	if muted and _channel_volume(channel) <= 0.0:
		_on_volume(0.5, channel)
	if channel == &"sfx" and muted:
		AudioManager.play_sfx("tap")
	_refresh()
	var slider: PixelSlider = _sliders.get(channel)
	if slider != null and is_instance_valid(slider):
		slider.accessible_label = name_text


func _set_channel_muted(channel: StringName, muted: bool) -> void:
	if channel == &"music":
		AudioManager.set_music_on(not muted)
	else:
		AudioManager.set_sfx_on(not muted)


# --------------------------------------------------------------- language

func _language_row() -> Control:
	## A tile per language: its flag, and its name written in itself. A player
	## who cannot read the current language can still find their own flag, and
	## "Deutsch" is a word a German reads before "DE" is a code they decode.
	## Following the device gets the full width on top, because it is the one
	## choice that is not a language and its name is the longest.
	var block := VBoxContainer.new()
	block.add_theme_constant_override(&"separation", 6)
	var entries: Array = []

	# Its picture is the flag of whatever the phone itself is set to, which is
	# what "automatic" will actually pick.
	var device: Dictionary = Loc.entry(Loc.device_language())
	var auto := _language_tile(Loc.t("settings.language.auto"),
		_flag_texture(StringName(device.get("flag", &"gb"))), true)
	UiTheme.describe(auto, Loc.t("settings.language.auto"),
		Loc.t("settings.language.auto_hint"))
	auto.pressed.connect(_on_pick_language.bind(Loc.FOLLOW_DEVICE))
	block.add_child(auto)
	entries.append({"button": auto, "value": Loc.FOLLOW_DEVICE})

	var grid := GridContainer.new()
	grid.columns = LANGUAGE_COLUMNS
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_child(grid)
	for entry in Loc.LANGUAGES:
		var code := StringName(entry.code)
		var tile := _language_tile(str(entry.native),
			_flag_texture(StringName(entry.get("flag", &""))), false)
		# The picker names each language *in that language*. A player who
		# cannot read the current one is exactly the player who needs this
		# control, and "Portuguese" spelled in Spanish does not help them.
		UiTheme.describe(tile, str(entry.native))
		tile.pressed.connect(_on_pick_language.bind(code))
		grid.add_child(tile)
		entries.append({"button": tile, "value": code})
	_segments[&"language"] = entries

	_language_note = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_language_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_language_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_language_note.custom_minimum_size.x = 0.0
	block.add_child(_card(_language_note))
	return block


func _language_tile(text: String, picture: Texture2D, wide: bool) -> Button:
	var tile := UiTheme.segment(text, false)
	tile.icon = picture
	tile.expand_icon = false
	tile.alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT if wide \
		else HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER if wide \
		else VERTICAL_ALIGNMENT_TOP
	tile.add_theme_constant_override(&"h_separation", 6)
	tile.custom_minimum_size = Vector2(0.0, 34.0 if wide else TILE_HEIGHT)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Flags keep their own colours whatever the key's text colour is.
	for slot: StringName in [&"icon_normal_color", &"icon_hover_color",
			&"icon_focus_color", &"icon_pressed_color"]:
		tile.add_theme_color_override(slot, Color.WHITE)
	return tile


static func _flag_texture(code: StringName) -> Texture2D:
	if not _flag_cache.has(code):
		var image := FLAGS.get_image()
		if image == null:
			return null
		if image.is_compressed():
			image.decompress()
		var cut := image.get_region(Rect2i(FleetDB.flag_region(code)))
		cut.resize(cut.get_width() * 2, cut.get_height() * 2, Image.INTERPOLATE_NEAREST)
		_flag_cache[code] = ImageTexture.create_from_image(cut)
	return _flag_cache[code]


func _on_pick_language(code: Variant) -> void:
	AudioManager.play_sfx("tap")
	Loc.set_preference(StringName(code))


func _on_language_changed(_code: StringName) -> void:
	# Deferred, because this arrives from inside a segment's own `pressed`
	# handler and the rebuild frees that segment. Godot survives it, but only
	# just; waiting for the frame to finish makes the ordering something the
	# reader can be sure about rather than something the engine gets away with.
	_rebuild_deferred.call_deferred()


func _rebuild_deferred() -> void:
	_build_body()
	_layout()


# -------------------------------------------------------------- presentation

func _motion_row() -> Control:
	var control := _segmented(&"motion", [
		{"value": false, "text": Loc.t("settings.motion.normal")},
		{"value": true, "text": Loc.t("settings.motion.reduced")},
	], func(reduced: Variant) -> void:
		UserPreferences.set_reduce_motion(bool(reduced))
		AudioManager.play_sfx("tap")
		_refresh())
	return _field(Loc.t("settings.motion"), control,
		Loc.t("settings.motion.hint"))


func _numbers_row() -> Control:
	var control := _segmented(&"numbers", [
		{"value": true, "text": Loc.t("common.on")},
		{"value": false, "text": Loc.t("common.off")},
	], func(on: Variant) -> void:
		UserPreferences.set_floating_numbers(bool(on))
		AudioManager.play_sfx("tap")
		_refresh())
	return _field(Loc.t("settings.numbers"), control,
		Loc.t("settings.numbers.hint"))


func _telemetry_row() -> Control:
	## R5: local, opt-in only. The hint says where the data goes (nowhere) and
	# where the local mirror lives, because a privacy toggle that does not say
	# what it does is not a toggle.
	var control := _segmented(&"telemetry", [
		{"value": false, "text": Loc.t("common.off")},
		{"value": true, "text": Loc.t("common.on")},
	], func(on: Variant) -> void:
		UserPreferences.set_telemetry_on(bool(on))
		AudioManager.play_sfx("tap")
		_refresh())
	return _field(Loc.t("settings.telemetry"), control,
		Loc.t("settings.telemetry.hint"))


func _ui_scale_row() -> Control:
	var options: Array = []
	for preset: float in UserPreferences.UI_SCALE_PRESETS:
		options.append({"value": preset, "text": "%d%%" % roundi(preset * 100.0)})
	var control := _segmented(&"ui_scale", options, func(preset: Variant) -> void:
		UserPreferences.set_ui_scale(float(preset))
		AudioManager.play_sfx("tap")
		_refresh()
		_layout())
	return _field(Loc.t("settings.ui_scale"), control,
		Loc.t("settings.ui_scale.hint"))


func _fullscreen_row() -> Control:
	var control := _segmented(&"fullscreen", [
		{"value": true, "text": Loc.t("common.on")},
		{"value": false, "text": Loc.t("common.off")},
	], func(on: Variant) -> void:
		UserPreferences.set_fullscreen(bool(on))
		AudioManager.play_sfx("tap")
		_refresh())
	return _field(Loc.t("settings.fullscreen"), control)


func _fullscreen_supported() -> bool:
	## A phone is already fullscreen and has no window to toggle, so the row is
	## simply not there. Showing a control that cannot do anything is worse than
	## showing one fewer option.
	return not (OS.has_feature("mobile") or DisplayServer.get_name() == "headless")


# ------------------------------------------------------------------- backup

func _backup_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	var export_btn := UiTheme.button(Loc.t("settings.export"), &"ghost",
		UiTheme.SIZE_SMALL)
	export_btn.custom_minimum_size.y = ROW_HEIGHT
	export_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.describe(export_btn, Loc.t("settings.export.name"),
		Loc.t("settings.export.hint"))
	export_btn.pressed.connect(_on_export)
	row.add_child(export_btn)
	var import_btn := UiTheme.button(Loc.t("settings.import"), &"ghost",
		UiTheme.SIZE_SMALL)
	import_btn.custom_minimum_size.y = ROW_HEIGHT
	import_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.describe(import_btn, Loc.t("settings.import.name"),
		Loc.t("settings.import.hint"))
	import_btn.pressed.connect(_on_import)
	row.add_child(import_btn)
	return row


func _wide_button(text: String, kind: StringName) -> Button:
	var button := UiTheme.button(text, kind, UiTheme.SIZE_SMALL)
	button.custom_minimum_size.y = 28.0
	button.clip_text = true
	return button


# --------------------------------------------------------------------- open

func open() -> void:
	_confirm_wipe = false
	_confirm_import = false
	# A browser that refuses site data would otherwise let the player build a
	# run for an hour and lose it on reload without ever being warned.
	if SaveManager.storage_available():
		_set_backup_message("", UiTheme.INK_SOFT)
	else:
		_set_backup_message(Loc.t("settings.storage_warning"), UiTheme.DANGER)
	_refresh()
	_focus_return = get_viewport().gui_get_focus_owner()
	visible = true
	open_changed.emit(true)
	_layout()
	UiTheme.focus_first(_panel)
	UiTheme.pop_open(_panel, _dim)


func close() -> void:
	if not visible:
		return
	AudioManager.play_sfx("tap")
	visible = false
	UiTheme.restore_focus(_focus_return)
	_focus_return = null
	open_changed.emit(false)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		close()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------- layout

func _layout() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	var view := get_viewport().get_visible_rect().size
	var safe := _resolved_safe_rect(view)
	var width := minf(safe.size.x - 24.0, 344.0)
	# Minus the gutter reserved for the scrollbar in `_build`. Getting this wrong
	# cost the volume rows the last letter of their readout — "MUTED" rendered
	# as "MUTE", which is the kind of fault that survives review because it
	# still looks like a word.
	var inner := width - 22.0 - UiTheme.SCROLL_WIDTH
	_content.custom_minimum_size.x = inner
	# The board is as tall as the page it is open at, up to the tallest it may
	# be — but it hangs from the same top edge whatever the page, so the
	# nameplate and the tabs never move under a finger that is changing tabs.
	var most := minf(BOARD_MAX_H, maxf(220.0, safe.size.y - 24.0))
	var wanted := _top.get_combined_minimum_size().y + 4.0 \
		+ _content.get_combined_minimum_size().y + 22.0
	var height := clampf(wanted, 160.0, most)
	_scroll.custom_minimum_size = Vector2(width - 22.0, 0.0)
	_panel.custom_minimum_size = Vector2(width, height)
	_panel.size = Vector2(width, height)
	_panel.position = safe.position + Vector2(
		(safe.size.x - width) * 0.5,
		(safe.size.y - most) * 0.5)


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, view))
	_layout()


func _resolved_safe_rect(view: Vector2) -> Rect2:
	var viewport_rect := Rect2(Vector2.ZERO, view)
	if _safe_rect.size.x <= 0.0 or _safe_rect.size.y <= 0.0:
		return viewport_rect
	var clipped := _safe_rect.intersection(viewport_rect)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 \
		else viewport_rect


# ------------------------------------------------------------------ refresh

func _refresh() -> void:
	for channel: StringName in [&"music", &"sfx"]:
		var muted := _channel_muted(channel)
		var volume := _channel_volume(channel)
		var slider: PixelSlider = _sliders.get(channel)
		if slider != null and is_instance_valid(slider):
			slider.set_value_silently(volume)
			slider.modulate = Color(1, 1, 1, 0.45 if muted else 1.0)
		var level: Label = _levels.get(channel)
		if level != null and is_instance_valid(level):
			# The word, not just a dimmed bar: an "off" state must never be
			# signalled by colour or opacity alone.
			level.text = Loc.t("settings.muted") if muted \
				else "%d%%" % roundi(volume * 100.0)
			level.label_settings.font_color = UiTheme.INK_SOFT if muted \
				else UiTheme.AMBER_DEEP
		var mute: Button = _mutes.get(channel)
		if mute != null and is_instance_valid(mute):
			UiTheme.style_button(mute, &"off" if muted else &"alt")
			var label_text := Loc.t("settings.music") if channel == &"music" \
				else Loc.t("settings.sfx")
			UiTheme.describe(mute, Loc.t(
				"settings.unmute_name" if muted else "settings.mute_name",
				{"label": label_text}))

	_refresh_segments(&"language", Loc.preference)
	if _language_note != null and is_instance_valid(_language_note):
		# Following the device has to name what it resolved to. "Automatic" on
		# its own never tells you whether the game agreed with your phone.
		_language_note.text = "%s %s" % [
			Loc.t("settings.language.current",
				{"label": Loc.native_name(Loc.language)}),
			Loc.t("settings.language.auto_hint")
				if Loc.preference == Loc.FOLLOW_DEVICE else ""]
		_language_note.text = _language_note.text.strip_edges()
	_refresh_segments(&"motion", UserPreferences.reduce_motion)
	_refresh_segments(&"numbers", UserPreferences.floating_numbers)
	_refresh_segments(&"telemetry", UserPreferences.telemetry_on)
	_refresh_segments(&"ui_scale", UserPreferences.ui_scale)
	_refresh_segments(&"fullscreen", UserPreferences.fullscreen)

	if _wipe_btn != null and is_instance_valid(_wipe_btn):
		_wipe_btn.text = Loc.t("settings.wipe.confirm") if _confirm_wipe \
			else Loc.t("settings.wipe")
		UiTheme.style_button(_wipe_btn, &"danger")
	if _backup_status != null and is_instance_valid(_backup_status):
		_backup_status.text = _backup_message
		_backup_status.visible = not _backup_message.is_empty()
		_backup_status.label_settings.font_color = _backup_tone


func _set_backup_message(text: String, tone: Color) -> void:
	## Kept as state rather than written straight onto the label, so a language
	## change — which rebuilds the label — does not silently drop it.
	_backup_message = text
	_backup_tone = tone
	_refresh()


# ------------------------------------------------------------------ actions

func _on_leave() -> void:
	## Write before leaving: the scene change tears down every section provider,
	## so a snapshot taken afterwards would be empty.
	SaveManager.save_game(&"leave_to_menu")
	AudioManager.play_sfx("tap")
	get_tree().change_scene_to_file("res://scenes/Title.tscn")


func _on_export() -> void:
	## Clipboard first: on the web build it is the only channel out of the
	## sandbox, and on desktop the file copy is the one you can actually keep.
	DisplayServer.clipboard_set(SaveManager.export_text())
	var wrote := SaveManager.export_to_file()
	_set_backup_message(Loc.t("settings.export.done_file",
		{"path": SaveManager.EXPORT_PATH}) if wrote
		else Loc.t("settings.export.done_clipboard"), UiTheme.TEAL_DEEP)
	AudioManager.play_sfx("tap")


func _on_import() -> void:
	## Two presses: this overwrites the run in progress and there is no undo.
	if not _confirm_import:
		_confirm_import = true
		_set_backup_message(Loc.t("settings.import.confirm"), UiTheme.DANGER)
		AudioManager.play_sfx("deny")
		return
	_confirm_import = false
	var result := SaveManager.import_text(DisplayServer.clipboard_get())
	if bool(result.get("ok", false)):
		_set_backup_message(Loc.t("settings.import.done"), UiTheme.TEAL_DEEP)
		AudioManager.play_sfx("build")
		get_tree().reload_current_scene()
		return
	_set_backup_message(str(result.get("error", Loc.t("settings.import.failed"))),
		UiTheme.DANGER)
	AudioManager.play_sfx("deny")


func _on_wipe() -> void:
	if not _confirm_wipe:
		_confirm_wipe = true
		_refresh()
		AudioManager.play_sfx("deny")
		return
	SaveManager.wipe()
	get_tree().reload_current_scene()
