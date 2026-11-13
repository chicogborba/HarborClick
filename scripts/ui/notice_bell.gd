class_name NoticeBell
extends CanvasLayer
## The port diary (formerly the notice bell). A leather book on the gantry: tap
## it, it opens in a little pixel animation, and inside are two bookmarks -
## AVISOS, the notices log below, and MEDALHAS, every achievement in the game
## as a struck medal (dark until earned) under the final trophy that lights up
## for whoever earns them all. The class keeps its name and API so Main and the
## notification coordinator did not have to change.
##
## Notices, collected in the book instead of thrown across the port.
##
## They used to arrive as a banner: a slate chip that faded in over the quay,
## sat there for three seconds and faded out, once per notice with a second
## queued behind it. Every one of them landed on the part of the screen the
## player was looking at, to say something they had usually just watched happen.
##
## So nothing interrupts any more. A notice lights a lamp on the bell at the end
## of the gantry and waits there to be read. `NotificationCoordinator` still
## decides what is worth keeping and still collapses repeats; this only decides
## that none of it is worth stopping the game for.
##
## The log itself is paper, not steel: it is something you open, and in this
## interface that means a slip off the manifest rather than another panel bolted
## to the port.

signal open_changed(opened: bool)

## What the bell reserves at the right-hand end of the gantry. `PortClock` reads
## it so the dial sits clear of the key rather than under it.
const RESERVE := 34.0
const KEY := 30.0
const ROWS := 8
## The book's height, whatever page it is open at.
const BOOK_H := 400.0

var _button: Button
var _pip: TextureRect
var _scrim: ColorRect
var _board: PanelContainer
var _scroll: ScrollContainer
var _inner: VBoxContainer
var _list: VBoxContainer
var _empty: Label
var _coordinator: NotificationCoordinator
var _unread := 0
var _safe_rect := Rect2()
var _world_rect := Rect2()
var _last_focus: Control
const TEX_KEY := preload("res://assets/sprites/ui_diary_key.png")
const TEX_TROPHY := preload("res://assets/sprites/ui_trophy_final.png")
const MEDAL_COLUMNS := 4
var _tab := "notices"
var _tab_buttons: Dictionary = {}
var _medals: VBoxContainer
var _medal_cells: Array[Dictionary] = []   # {id, medal, title}
var _trophy: TextureRect
var _trophy_count: Label
var _trophy_bar: ProgressBar
var _detail: Label
## NAVIOS: the fleet album (`FleetDB`), built once and recoloured on open.
const SHIP_COLUMNS := 2
const FLAGS := preload("res://assets/sprites/ui_flags.png")
var _album: VBoxContainer
var _ship_cells: Array[Dictionary] = []   # {ship, card, portrait, flag, name, line}
var _album_count: Label
var _album_bar: ProgressBar
var _album_prize: Label
var _album_claim: Button
var _album_detail: Label
## True while the shut book is dropping out of frame: closed to the game,
## still on screen.
var _closing := false
## True from the key press to the first frame of the rise: the pages are being
## laid out and measured, still unseen (alpha 0), and an open in this state
## can still be cancelled by whoever closes it.
var _opening := false


func _ready() -> void:
	# Above the level badge (9): the open log used to slide under it and lose
	# its title.
	layer = 12
	_button = UiTheme.button("", &"steel", UiTheme.SIZE_SMALL)
	_button.custom_minimum_size = Vector2(KEY, KEY)
	var book_icon := TextureRect.new()
	book_icon.texture = TEX_KEY
	book_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	book_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	book_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_button.add_child(book_icon)
	UiTheme.describe(_button, Loc.t("diary.title"))
	_button.tooltip_text = Loc.t("diary.title")
	_button.pressed.connect(toggle)
	add_child(_button)
	_pip = UiTheme.pip()
	_pip.visible = false
	add_child(_pip)

	_scrim = UiTheme.scrim(0.28)
	_scrim.visible = false
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)

	_board = UiTheme.panel(UiTheme.book_style(), false)
	_board.visible = false
	add_child(_board)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	_board.add_child(column)
	var head := UiTheme.header(Loc.t("diary.title"), close_log,
		UiTheme.Icon.TROPHY, UiTheme.book_header_style())
	column.add_child(head.root)
	# The two bookmarks.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 4)
	column.add_child(tabs)
	for spec in [["notices", "diary.tab.notices"], ["medals", "diary.tab.medals"],
			["ships", "diary.tab.ships"]]:
		var key := UiTheme.button(Loc.t(str(spec[1])), &"steel", UiTheme.SIZE_SMALL)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.custom_minimum_size.y = 26.0
		key.pressed.connect(_set_tab.bind(str(spec[0])))
		tabs.add_child(key)
		_tab_buttons[str(spec[0])] = key
	# The rows wrap, and a wrapped label measured before the layout pass reports a
	# height in the thousands — which is exactly how a 250px log came out 3505px
	# tall and hanging off the bottom of the screen. Inside a scroll container the
	# content's height stops driving the panel's minimum at all.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.style_scroll(_scroll)
	column.add_child(_scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override(&"separation", 2)
	_scroll.add_child(inner)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 2)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_list)
	_empty = UiTheme.label("Nada novo no porto.", UiTheme.SIZE_SMALL,
		UiTheme.BOOK_INK_SOFT)
	inner.add_child(_empty)
	_medals = VBoxContainer.new()
	_medals.add_theme_constant_override(&"separation", 6)
	_medals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_medals.visible = false
	inner.add_child(_medals)
	_album = VBoxContainer.new()
	_album.add_theme_constant_override(&"separation", 6)
	_album.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_album.visible = false
	inner.add_child(_album)
	_inner = inner

	_layout()


func setup(coordinator: NotificationCoordinator) -> void:
	if _coordinator != null and _coordinator.presented.is_connected(_receive):
		_coordinator.presented.disconnect(_receive)
	_coordinator = coordinator
	if _coordinator != null:
		_coordinator.presented.connect(_receive)


func _receive(notice: Dictionary) -> void:
	AudioManager.play_sfx("bell", 0.03, -8.0)
	## The coordinator hands one notice at a time and waits to be told the slot is
	## free. Nothing is being shown, so the slot is free immediately — otherwise
	## the first notice of the run would wedge the queue behind a banner that no
	## longer exists.
	if _coordinator != null:
		_coordinator.notify_shown_finished()
	if str(notice.get("text", "")).is_empty():
		return
	_unread += 1
	_pip.visible = true
	if _board.visible:
		_fill()
	elif UserPreferences.can_animate():
		# One short nudge of the key, so something arriving is noticeable in the
		# corner of the eye without being in the way of anything.
		var tween := create_tween()
		tween.tween_property(_button, "modulate", Color(1.35, 1.2, 0.95), 0.12)
		tween.tween_property(_button, "modulate", Color.WHITE, 0.5)


func unread() -> int:
	return _unread


func is_open() -> bool:
	return _board.visible and not _closing


func toggle() -> void:
	close_log() if is_open() else open_log()


func open_log() -> void:
	if is_open():
		return
	_last_focus = get_viewport().gui_get_focus_owner() if get_viewport() != null \
		else null
	_unread = 0
	_pip.visible = false
	_closing = false
	# Opened from a known-small height, so the first layout pass can never be
	# asked to shrink a board that has already been sized by its own wrapped text.
	_board.size = Vector2(_board.size.x, 90.0)
	_fill()
	# Unseen, but present: the layout pass positions the board by visibility,
	# so the pages are laid out under a cover of alpha 0 until they rise.
	_board.modulate.a = 0.0
	_board.visible = true
	_opening = true
	# Dark from the first frame it exists: shown at full strength and then
	# faded in by the rise, it flashed the whole screen once before opening.
	_scrim.modulate.a = 0.0
	_scrim.visible = true
	open_changed.emit(true)
	_show_pages()


func _show_pages() -> void:
	## The book is fitted while it is still under the counter, and only a book
	## already at its final size ever rises. The fit used to land a frame into
	## the rise — the notices log grew a visible jump mid-animation — and the
	## board spent that frame visible at its resting place, which flashed
	## before the rise. Now it appears and starts rising in the same frame.
	_set_tab(_tab, false)
	_layout()
	if is_inside_tree():
		await get_tree().process_frame
		if _closing or not _opening:
			return
	_fit_board_now()
	_opening = false
	_board.modulate.a = 1.0
	UiTheme.focus_first(_board)
	# The pages are laid out under the cover; `BookFx` swings it off them.
	BookFx.open(_board, _scrim)


func close_log() -> void:
	if not _board.visible or _closing:
		return
	_closing = true
	_opening = false
	BookFx.close(_board, _scrim, func() -> void:
		_closing = false
		_scrim.visible = false
		_board.visible = false)
	open_changed.emit(false)
	UiTheme.restore_focus(_last_focus)
	_last_focus = null


func _fill() -> void:
	for child in _list.get_children():
		child.queue_free()
	var shown := 0
	for notice: Dictionary in _history():
		if shown >= ROWS:
			break
		_list.add_child(_row(notice))
		shown += 1
	# A notice that lands while the book is open at another page refills the
	# log without turning to it.
	var on_notices := _tab == "notices"
	_empty.visible = on_notices and shown == 0
	_list.visible = on_notices and shown > 0


func _history() -> Array:
	## Newest first, and only what was actually news. Routine state — the berth
	## phase, a ship arriving — is already on the gantry, and the coordinator
	## records it so the journal can show the full log; a bell that repeated it
	## would bury the two lines that matter under twenty that do not.
	if _coordinator == null:
		return []
	var rows: Array = []
	var seen: Dictionary = {}
	for notice: Dictionary in _coordinator.history:
		if StringName(notice.get("outcome", &"")) == &"routine":
			continue
		var id := StringName(notice.get("id", &""))
		# A repeat is recorded as its own entry with a bumped count, so the same
		# blocked yard tapped ten times is one line reading x10 rather than ten
		# identical lines. History is newest first, which is why the first hit
		# wins the position and the rest only raise the tally.
		if seen.has(id):
			var at: int = seen[id]
			rows[at]["count"] = maxi(int(rows[at].get("count", 1)),
				int(notice.get("count", 1)))
			continue
		seen[id] = rows.size()
		rows.append(notice.duplicate(true))
	return rows


func _row(notice: Dictionary) -> Control:
	var card := UiTheme.panel(UiTheme.card_style(&"normal"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	# Shrunk to its own 12px: left to fill, a wrapped three-line notice stretched
	# its icon into a tall smear down the side of the card.
	var glyph := UiTheme.icon(notice.get("icon", UiTheme.Icon.TEU))
	glyph.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(glyph)
	var count := int(notice.get("count", 1))
	var text := str(notice.get("text", ""))
	var label := UiTheme.label(text if count <= 1 else "%s  x%d" % [text, count],
		UiTheme.SIZE_SMALL, UiTheme.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return card


func _on_scrim_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and not touch.pressed:
		close_log()
		return
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT \
			and not click.pressed:
		close_log()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE and _board.visible:
		close_log()
		get_viewport().set_input_as_handled()


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, view))
	_world_rect = metrics.get("world_rect", _safe_rect)
	_layout()


func _area() -> Rect2:
	var area := _world_rect if _world_rect.size != Vector2.ZERO else _safe_rect
	if area.size == Vector2.ZERO:
		area = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	return area


func _layout() -> void:
	if _button == null or not is_instance_valid(_button):
		return
	var area := _area()
	# The right-hand end of the gantry, centred in the panel's face — the amber
	# hairline along the bottom is the panel's edge, not room for a key.
	_button.size = Vector2(KEY, KEY)
	_button.position = Vector2(area.end.x - KEY - 4.0,
		area.position.y + floorf((Hud.BAR_H - 4.0 - KEY) * 0.5))
	_pip.position = _button.position + Vector2(KEY - 8.0, 2.0)
	if not _board.visible:
		return
	var width := clampf(area.size.x - 16.0, 150.0, 340.0)
	_board.size = Vector2(width, minf(_board.size.y, _room(area)))
	_board.position = Vector2(
		clampf(_button.get_global_rect().end.x - width, area.position.x + 6.0,
			maxf(area.position.x + 6.0, area.end.x - width - 4.0)),
		area.position.y + Hud.BAR_H + 4.0)


func _room(area: Rect2) -> float:
	## Everything between the bottom of the gantry and the bottom of the world.
	return maxf(90.0, area.size.y - Hud.BAR_H - 24.0)


func _fit_board_now() -> void:
	## The same measurement, applied at once — for the moment before a rise,
	## when landing early beats landing smooth (a board must never change size
	## while it travels).
	_board.size.y = _fitted_height()
	_layout()


func _fitted_height() -> float:
	## One height for every page. A book does not get shorter because the page
	## it is open at has less written on it — the log used to shrink to three
	## notices and grow again for the medals, and that is a panel, not a book.
	return clampf(BOOK_H, 90.0, _room(_area()))


# ------------------------------------------------------------------ medals

func _set_tab(tab: String, turn: bool = true) -> void:
	var turned := turn and tab != _tab and _board.visible
	_tab = tab
	for key: String in _tab_buttons:
		UiTheme.style_book_tab(_tab_buttons[key], key == tab)
	if turned:
		BookFx.flip(_scroll)
	var medals := tab == "medals"
	var ships := tab == "ships"
	var notices := not medals and not ships
	_list.visible = notices and _list.get_child_count() > 0
	_empty.visible = notices and _list.get_child_count() == 0
	_medals.visible = medals
	_album.visible = ships
	if medals:
		_refresh_medals()
	if ships:
		_refresh_album()
	_scroll.scroll_vertical = 0


func _build_medals() -> void:
	## Once: the final trophy, the detail line, and one cell per achievement.
	var card := UiTheme.panel(UiTheme.card_style(&"normal"))
	_medals.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	_trophy = TextureRect.new()
	_trophy.texture = TEX_TROPHY
	_trophy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_trophy.stretch_mode = TextureRect.STRETCH_SCALE
	_trophy.custom_minimum_size = Vector2(64, 64)
	_trophy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_trophy)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(UiTheme.label(Loc.t("diary.trophy"), UiTheme.SIZE_BODY, UiTheme.AMBER_DEEP))
	var sub_title := UiTheme.label(Loc.t("diary.trophy.name"), UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	sub_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_title.custom_minimum_size.x = 120.0
	col.add_child(sub_title)
	_trophy_bar = ProgressBar.new()
	var styles := UiTheme.bar_styles()
	_trophy_bar.add_theme_stylebox_override(&"background", styles[0])
	_trophy_bar.add_theme_stylebox_override(&"fill", styles[1])
	_trophy_bar.show_percentage = false
	_trophy_bar.custom_minimum_size = Vector2(0, 8)
	_trophy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_trophy_bar)
	_trophy_count = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	col.add_child(_trophy_count)

	_detail = UiTheme.label(Loc.t("diary.tap_medal"), UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.custom_minimum_size.x = 120.0
	_medals.add_child(_detail)

	var grid := GridContainer.new()
	grid.columns = MEDAL_COLUMNS
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_medals.add_child(grid)
	for item: Dictionary in AchievementDB.ITEMS:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override(&"separation", 2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		grid.add_child(cell)
		var medal := TextureRect.new()
		var key := str(item.get("category", "teu"))
		var path := "res://assets/sprites/ui_medal_%s.png" % key
		medal.texture = load(path) if ResourceLoader.exists(path) \
			else load("res://assets/sprites/ui_medal_teu.png")
		medal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		medal.custom_minimum_size = Vector2(64, 64)
		medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(medal)
		var title := UiTheme.label(str(item.get("title", "")), UiTheme.SIZE_SMALL, UiTheme.INK)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.custom_minimum_size.x = 60.0
		title.max_lines_visible = 2
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(title)
		cell.gui_input.connect(_on_medal_input.bind(item))
		_medal_cells.append({"id": str(item.id), "medal": medal, "title": title})


func _refresh_medals() -> void:
	if _medal_cells.is_empty():
		_build_medals()
	var done := 0
	for cell: Dictionary in _medal_cells:
		var earned := Progression.unlocked.has(StringName(cell.id)) \
			or Progression.unlocked.has(str(cell.id))
		if earned:
			done += 1
		# Unearned: a dark silhouette of the coin, still recognisable as a goal.
		(cell.medal as TextureRect).modulate = Color.WHITE if earned \
			else Color(0.16, 0.15, 0.2, 0.75)
		(cell.title as Label).label_settings.font_color = UiTheme.INK if earned \
			else UiTheme.INK_SOFT
	var total := _medal_cells.size()
	_trophy_bar.max_value = total
	_trophy_bar.value = done
	_trophy_count.text = Loc.t("diary.count", {"n": str(done), "total": str(total)})
	var complete := done >= total
	_trophy.modulate = Color.WHITE if complete else Color(0.3, 0.28, 0.34, 0.85)


func _on_medal_input(event: InputEvent, item: Dictionary) -> void:
	var released: bool = (event is InputEventMouseButton and not event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and not event.pressed)
	if not released:
		return
	var earned := Progression.unlocked.has(StringName(str(item.id))) \
		or Progression.unlocked.has(str(item.id))
	var reward: Dictionary = item.get("reward", {})
	_detail.text = "%s%s - %s  (+%d XP)" % ["[OK] " if earned else "",
		str(item.get("title", "")), str(item.get("description", "")),
		int(reward.get("amount", 0))]
	_detail.label_settings.font_color = UiTheme.TEAL_DEEP if earned else UiTheme.INK
	AudioManager.play_sfx("tap")


# ------------------------------------------------------------------- album

func _build_album() -> void:
	## Once: the tally with its prize key, the detail line, one card per ship.
	var card := UiTheme.panel(UiTheme.card_style(&"normal"))
	_album.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 6)
	col.add_child(head)
	var glyph := UiTheme.icon(UiTheme.Icon.SHIP, 2)
	glyph.modulate = UiTheme.TEAL_DEEP
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(glyph)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override(&"separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(texts)
	texts.add_child(UiTheme.label(Loc.t("album.title"), UiTheme.SIZE_BODY,
		UiTheme.AMBER_DEEP))
	_album_count = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	texts.add_child(_album_count)
	_album_bar = ProgressBar.new()
	var styles := UiTheme.bar_styles()
	_album_bar.add_theme_stylebox_override(&"background", styles[0])
	_album_bar.add_theme_stylebox_override(&"fill", styles[1])
	_album_bar.show_percentage = false
	_album_bar.custom_minimum_size = Vector2(0, 8)
	_album_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_album_bar)
	var prize_row := HBoxContainer.new()
	prize_row.add_theme_constant_override(&"separation", 6)
	col.add_child(prize_row)
	_album_prize = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_album_prize.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_album_prize.custom_minimum_size.x = 80.0
	_album_prize.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_album_prize.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prize_row.add_child(_album_prize)
	_album_claim = UiTheme.button(Loc.t("album.claim"), &"amber", UiTheme.SIZE_SMALL)
	_album_claim.custom_minimum_size = Vector2(0, 28)
	_album_claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_album_claim.pressed.connect(_on_album_claim)
	prize_row.add_child(_album_claim)

	_album_detail = UiTheme.label(Loc.t("album.tap"), UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	_album_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_album_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_album_detail.custom_minimum_size.x = 120.0
	_album.add_child(_album_detail)

	var grid := GridContainer.new()
	grid.columns = SHIP_COLUMNS
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_album.add_child(grid)
	for ship: Dictionary in FleetDB.album_order():
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.focus_mode = Control.FOCUS_ALL
		grid.add_child(cell)
		var body := VBoxContainer.new()
		body.add_theme_constant_override(&"separation", 2)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(body)
		var portrait := ShipPortrait.new()
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(portrait)
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override(&"separation", 3)
		name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(name_row)
		var flag := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = FLAGS
		atlas.region = FleetDB.flag_region(StringName(ship.flag))
		flag.texture = atlas
		flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flag.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		flag.custom_minimum_size = FleetDB.FLAG_SIZE
		flag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_row.add_child(flag)
		var title := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.max_lines_visible = 2
		title.custom_minimum_size.x = 40.0
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_row.add_child(title)
		var line := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
		line.clip_text = true
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(line)
		cell.gui_input.connect(_on_ship_input.bind(ship))
		_ship_cells.append({"ship": ship, "card": cell, "portrait": portrait,
			"flag": flag, "title": title, "line": line, "style": &""})


func _refresh_album() -> void:
	if _ship_cells.is_empty():
		_build_album()
	var album: Dictionary = Progression.album
	var seen := 0
	for cell: Dictionary in _ship_cells:
		var ship: Dictionary = cell.ship
		var known := FleetDB.is_seen(ship, album)
		if known:
			seen += 1
		(cell.portrait as ShipPortrait).set_ship(ship, known)
		var style: StringName = (&"ready" if str(ship.rarity) == "legend" else &"normal") \
			if known else &"locked"
		if style != cell.style:
			UiTheme.apply_panel(cell.card, UiTheme.card_style(style))
			cell.style = style
		(cell.flag as TextureRect).modulate = Color.WHITE if known \
			else Color(0.16, 0.15, 0.2, 0.55)
		var title: Label = cell.title
		title.text = str(ship.name) if known else "???"
		title.label_settings.font_color = UiTheme.INK if known else UiTheme.INK_SOFT
		var line: Label = cell.line
		var port := StringName(ship.get("port", &""))
		if known:
			line.text = "%s • %d TEU" % [FleetDB.hull_type(ship), int(ship.capacity)]
		elif bool(ship.get("special", false)):
			line.text = Loc.t("album.charter_short")
		elif port != &"":
			line.text = str(PortDB.get_port(port).get("name", ""))
		else:
			line.text = FleetDB.hull_type(ship)
		UiTheme.describe(cell.card, title.text, line.text)
	var total := _ship_cells.size()
	_album_bar.max_value = total
	_album_bar.value = seen
	_album_count.text = Loc.t("album.count", {"n": str(seen), "total": str(total)})
	var claimable := _claimable_milestone(seen, total)
	_album_claim.visible = claimable > 0
	var next := _next_milestone(seen, total)
	if claimable > 0:
		_album_prize.text = Loc.t("album.prize_ready", {"n": str(claimable)})
		_album_prize.label_settings.font_color = UiTheme.AMBER_DEEP
	elif next > 0:
		_album_prize.text = Loc.t("album.prize_next", {"n": str(next)})
		_album_prize.label_settings.font_color = UiTheme.INK_SOFT
	else:
		_album_prize.text = Loc.t("album.complete")
		_album_prize.label_settings.font_color = UiTheme.TEAL_DEEP


func _milestones(total: int) -> Array[int]:
	var out: Array[int] = []
	var step := FleetDB.MILESTONE_STEP
	var at := step
	while at < total:
		out.append(at)
		at += step
	out.append(total)
	return out


func _claimable_milestone(seen: int, total: int) -> int:
	for milestone in _milestones(total):
		if seen >= milestone and not Progression.album_milestone_claimed(milestone):
			return milestone
	return 0


func _next_milestone(seen: int, total: int) -> int:
	for milestone in _milestones(total):
		if seen < milestone:
			return milestone
	return 0


func _on_album_claim() -> void:
	var total := _ship_cells.size()
	var seen := FleetDB.seen_count(Progression.album)
	var milestone := _claimable_milestone(seen, total)
	if milestone <= 0 or not Progression.claim_album_milestone(milestone, seen):
		return
	# Minutes of production, more for each milestone: the last ships are the
	# rare ones and the far ports.
	var minutes := Progression.ALBUM_PAGE_SECONDS \
		* maxf(1.0, float(milestone) / float(FleetDB.MILESTONE_STEP))
	var amount := GameState.cps * minutes
	GameState.grant_nonproductive_reward(amount)
	EventBus.notification_requested.emit({
		"id": "album_prize_%d" % milestone, "kind": &"unlock", "priority": 2,
		"icon": UiTheme.Icon.SHIP,
		"text": Loc.t("album.prize_paid", {"n": str(milestone),
			"amount": GameState.fmt(amount)}),
	})
	AudioManager.play_sfx("coins")
	_refresh_album()


func _on_ship_input(event: InputEvent, ship: Dictionary) -> void:
	var released: bool = (event is InputEventMouseButton and not event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and not event.pressed) \
		or (event is InputEventKey and event.pressed
			and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE))
	if not released:
		return
	_album_detail.text = ship_detail(ship, FleetDB.is_seen(ship, Progression.album))
	_album_detail.label_settings.font_color = UiTheme.INK
	AudioManager.play_sfx("tap")


static func ship_detail(ship: Dictionary, known: bool) -> String:
	## The record printed under the tally when a card is tapped. An unseen ship
	## says where to look for it rather than nothing: a silhouette with no hint
	## is a wall, one with a hint is a goal.
	var rarity := Loc.t("album.rarity.%s" % str(ship.rarity))
	var port := StringName(ship.get("port", &""))
	if not known:
		var hint := Loc.t("album.unseen")
		if bool(ship.get("special", false)):
			hint = Loc.t("album.charter")
		elif port != &"":
			hint = Loc.t("album.only_port",
				{"port": str(PortDB.get_port(port).get("name", ""))})
		return "??? • %s • %s. %s" % [FleetDB.hull_type(ship), rarity, hint]
	return "%s • %s • %d TEU • %s • %s" % [str(ship.name), FleetDB.hull_type(ship),
		int(ship.capacity), Loc.t("country.%s" % str(ship.flag)), rarity]
