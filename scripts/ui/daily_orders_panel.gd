class_name DailyOrdersPanel
extends CanvasLayer
## Missões do Dia: three orders a day, a bonus for all three, and the streak.
##
## Paper, because it is a board you open. Every row is built once and rewritten
## in place — the shop's upgrades tab learned the hard way that a panel which
## rebuilds itself on a timer eats the taps that land during the rebuild.

signal open_changed(opened: bool)

const ROWS := 3
const BUTTON_W := 78.0

var _service: DailyOrdersService
var _scrim: ColorRect
var _board: PanelContainer
var _column: VBoxContainer
var _close_button: Button
var _streak: Label
var _rows: Array[Dictionary] = []      # {box, name, bar, count, button}
var _bonus_label: Label
var _bonus_button: Button
var _reset: Label
var _safe_rect := Rect2()
var _tick := 0.0
var _layout_pending := false


func _ready() -> void:
	layer = 13
	visible = false
	_scrim = UiTheme.scrim(0.7)
	_scrim.gui_input.connect(_on_scrim_input)
	add_child(_scrim)
	_board = UiTheme.panel(UiTheme.board_style(11), false)
	add_child(_board)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 6)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.add_child(_column)

	var header := UiTheme.header(Loc.t("daily.title"), close)
	_column.add_child(header.root)
	_close_button = header.close

	_streak = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.TEAL_DEEP)
	_streak.clip_text = true
	_column.add_child(_streak)
	_column.add_child(UiTheme.divider())

	for index in ROWS:
		_rows.append(_build_row(index))

	_column.add_child(UiTheme.divider())
	var bonus := HBoxContainer.new()
	bonus.add_theme_constant_override(&"separation", 6)
	_column.add_child(bonus)
	_bonus_label = UiTheme.label(Loc.t("daily.bonus"), UiTheme.SIZE_SMALL, UiTheme.INK)
	_bonus_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Wrapped, which is safe here only because `_layout` sets the board's width
	# a frame before it measures the height (see the note there).
	_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bonus_label.custom_minimum_size.x = 120.0
	bonus.add_child(_bonus_label)
	_bonus_button = UiTheme.button(Loc.t("daily.claim"), &"amber", UiTheme.SIZE_SMALL)
	_bonus_button.custom_minimum_size = Vector2(BUTTON_W, UiTheme.TOUCH_MIN)
	_bonus_button.pressed.connect(_on_bonus)
	bonus.add_child(_bonus_button)

	_reset = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_reset.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reset.clip_text = true
	_column.add_child(_reset)
	_layout()


func _build_row(index: int) -> Dictionary:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	_column.add_child(box)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 2)
	box.add_child(text)
	var name := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK)
	name.clip_text = true
	text.add_child(name)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override(&"separation", 4)
	text.add_child(bar_row)
	var bar := ProgressBar.new()
	var styles := UiTheme.bar_styles()
	bar.add_theme_stylebox_override(&"background", styles[0])
	bar.add_theme_stylebox_override(&"fill", styles[1])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(60.0, 9.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_child(bar)
	var count := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	count.custom_minimum_size.x = 44.0
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar_row.add_child(count)
	var button := UiTheme.button(Loc.t("daily.claim"), &"amber", UiTheme.SIZE_SMALL)
	button.custom_minimum_size = Vector2(BUTTON_W, UiTheme.TOUCH_MIN)
	button.pressed.connect(_on_claim.bind(index))
	box.add_child(button)
	return {"box": box, "name": name, "bar": bar, "count": count, "button": button}


func setup(service: DailyOrdersService) -> void:
	_service = service
	if _service != null and not _service.state_changed.is_connected(refresh):
		_service.state_changed.connect(refresh)
	refresh()


func open() -> void:
	if visible:
		return
	visible = true
	refresh()
	_layout()
	# Same as the wheel: the height is fitted a frame after the width, and
	# pop_open captures the resting position, so let it settle first.
	await get_tree().process_frame
	await get_tree().process_frame
	if not visible:
		return
	open_changed.emit(true)
	UiTheme.pop_open(_board, _scrim)
	_close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	open_changed.emit(false)


func is_open() -> bool:
	return visible


func refresh() -> void:
	## Rewrites every row in place. Never adds or frees a node.
	if _service == null or _service.orders == null or _rows.is_empty():
		return
	var orders := _service.orders
	_streak.text = "%s  •  %s" % [Loc.t("daily.streak", {"n": str(orders.streak)}),
		Loc.t("daily.best", {"n": str(orders.best_streak)})]
	var all_claimed := true
	for index in ROWS:
		var row: Dictionary = _rows[index]
		if index >= orders.missions.size():
			(row.box as Control).visible = false
			continue
		(row.box as Control).visible = true
		var mission: Dictionary = orders.missions[index]
		var goal := maxi(1, int(mission.get("goal", 1)))
		var progress := clampi(int(mission.get("progress", 0)), 0, goal)
		var claimed := bool(mission.get("claimed", false))
		all_claimed = all_claimed and claimed
		(row.name as Label).text = Loc.t("daily.mission.%s" % str(mission.get("id", "")),
			{"goal": str(goal)})
		(row.name as Label).label_settings.font_color = \
			UiTheme.INK_SOFT if claimed else UiTheme.INK
		var bar: ProgressBar = row.bar
		bar.max_value = goal
		bar.value = progress
		(row.count as Label).text = "%d/%d" % [progress, goal]
		var button: Button = row.button
		if claimed:
			button.text = Loc.t("daily.done")
			button.disabled = true
			UiTheme.style_button(button, &"ghost")
		elif progress >= goal:
			button.text = Loc.t("daily.claim")
			button.disabled = false
			UiTheme.style_button(button, &"amber")
		else:
			button.text = Loc.t("daily.claim")
			button.disabled = true
			UiTheme.style_button(button, &"off")
	var bonus_ready := all_claimed and not orders.bonus_claimed
	_bonus_button.disabled = not bonus_ready
	_bonus_button.text = Loc.t("daily.done") if orders.bonus_claimed \
		else Loc.t("daily.claim")
	UiTheme.style_button(_bonus_button, &"amber" if bonus_ready
		else (&"ghost" if orders.bonus_claimed else &"off"))
	_refresh_reset()


func _refresh_reset() -> void:
	## Counts down to local midnight, when the next three orders are drawn.
	var bias_s := float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
	var now := Time.get_unix_time_from_system() + bias_s
	var left := 86400.0 - fposmod(now, 86400.0)
	_reset.text = Loc.t("daily.reset", {"time": "%dh%02d" % [
		int(left / 3600.0), int(left / 60.0) % 60]})


func _process(delta: float) -> void:
	if not visible:
		return
	_tick += delta
	if _tick >= 0.5:
		_tick = 0.0
		refresh()


func _on_claim(index: int) -> void:
	if _service == null:
		return
	if _service.claim(index).is_empty():
		AudioManager.play_sfx("deny")
		return
	AudioManager.play_sfx("milestone")
	AudioManager.play_sfx("coins", 0.05, -4.0)
	_pop(_rows[index].box)
	refresh()


func _on_bonus() -> void:
	if _service == null:
		return
	if _service.claim_bonus().is_empty():
		AudioManager.play_sfx("deny")
		return
	AudioManager.play_sfx("wheel_win")
	_pop(_bonus_button)
	refresh()


func _pop(node: Control) -> void:
	## A short brighten on the row that paid — modulate, not scale, so the
	## bitmap type is never resampled.
	if not UserPreferences.can_animate() or node == null:
		return
	var tween := node.create_tween()
	tween.tween_property(node, "modulate", Color(1.4, 1.35, 1.1), 0.07)
	tween.tween_property(node, "modulate", Color.WHITE, 0.3)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		close()
		get_viewport().set_input_as_handled()


func _on_scrim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		close()
		get_viewport().set_input_as_handled()


func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_layout()


func _layout() -> void:
	## Width first, height a frame later: the bonus line wraps to the board's
	## width, and a height measured before that width propagates is a fantasy
	## that once pushed the wheel's board off the top of a phone.
	if _board == null or not is_instance_valid(_board):
		return
	var safe := _safe_rect
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	if safe.size == Vector2.ZERO:
		safe = view
	safe = safe.intersection(view) if safe.intersects(view) else view
	var width := minf(300.0, safe.size.x - 16.0)
	_board.size = Vector2(width, _board.size.y)
	if _layout_pending:
		return
	_layout_pending = true
	await get_tree().process_frame
	_layout_pending = false
	if _board == null or not is_instance_valid(_board):
		return
	var content_h := _column.get_combined_minimum_size().y + 22.0
	_board.size = Vector2(width, minf(content_h, safe.size.y - 20.0))
	_board.position = (safe.position + (safe.size - _board.size) * 0.5).round()
