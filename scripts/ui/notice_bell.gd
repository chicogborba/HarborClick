class_name NoticeBell
extends CanvasLayer
## Notices, collected on a bell instead of thrown across the port.
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


func _ready() -> void:
	layer = 8
	_button = UiTheme.icon_button(UiTheme.Icon.BELL, &"steel", KEY, "Avisos do porto")
	_button.pressed.connect(toggle)
	add_child(_button)
	_pip = UiTheme.pip()
	_pip.visible = false
	add_child(_pip)

	_scrim = UiTheme.scrim(0.28)
	_scrim.visible = false
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)

	_board = UiTheme.panel(UiTheme.board_style(8), false)
	_board.visible = false
	add_child(_board)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	_board.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 5)
	column.add_child(head)
	var title := UiTheme.label("AVISOS DO PORTO", UiTheme.SIZE_SMALL, UiTheme.TEAL_DEEP)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UiTheme.icon_button(UiTheme.Icon.CLOSE, &"ghost", 22.0,
		"Fechar avisos")
	close.pressed.connect(close_log)
	head.add_child(close)
	column.add_child(UiTheme.divider())
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
		UiTheme.INK_SOFT)
	inner.add_child(_empty)
	_inner = inner
	_layout()


func setup(coordinator: NotificationCoordinator) -> void:
	if _coordinator != null and _coordinator.presented.is_connected(_receive):
		_coordinator.presented.disconnect(_receive)
	_coordinator = coordinator
	if _coordinator != null:
		_coordinator.presented.connect(_receive)


func _receive(notice: Dictionary) -> void:
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
	return _board.visible


func toggle() -> void:
	close_log() if _board.visible else open_log()


func open_log() -> void:
	if _board.visible:
		return
	_last_focus = get_viewport().gui_get_focus_owner() if get_viewport() != null \
		else null
	_unread = 0
	_pip.visible = false
	# Opened from a known-small height, so the first layout pass can never be
	# asked to shrink a board that has already been sized by its own wrapped text.
	_board.size = Vector2(_board.size.x, 90.0)
	_fill()
	_scrim.visible = true
	_board.visible = true
	_layout()
	open_changed.emit(true)
	UiTheme.focus_first(_board)
	_fit_board()
	UiTheme.pop_open(_board, _scrim)


func close_log() -> void:
	if not _board.visible:
		return
	_scrim.visible = false
	_board.visible = false
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
	_empty.visible = shown == 0
	_list.visible = shown > 0


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
	row.add_child(UiTheme.icon(notice.get("icon", UiTheme.Icon.TEU)))
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
	var width := clampf(area.size.x - 16.0, 150.0, 250.0)
	_board.size = Vector2(width, minf(_board.size.y, _room(area)))
	_board.position = Vector2(
		clampf(_button.get_global_rect().end.x - width, area.position.x + 6.0,
			maxf(area.position.x + 6.0, area.end.x - width - 4.0)),
		area.position.y + Hud.BAR_H + 4.0)


func _room(area: Rect2) -> float:
	## Everything between the bottom of the gantry and the bottom of the world.
	return maxf(90.0, area.size.y - Hud.BAR_H - 24.0)


func _fit_board() -> void:
	## Shrink to the notices once they have actually wrapped. Measuring before the
	## layout pass is what produced a board several thousand pixels tall, so this
	## waits a frame and stays clamped to the room either way.
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not _board.visible or not is_instance_valid(_board):
		return
	var area := _area()
	var wanted := _inner.get_combined_minimum_size().y \
		+ _board.get_combined_minimum_size().y
	_board.size.y = clampf(wanted, 90.0, _room(area))
	_layout()
