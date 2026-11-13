class_name DailyOrdersPanel
extends CanvasLayer
## Missões do Dia: three orders a day, a bonus for all three, and the streak —
## written out by hand on a clipboard.
##
## Every other board in the game is printed: a container wall, a stencilled
## title, a manifest. This one is the foreman's own list — ruled notebook paper
## under a spring clip, boxes drawn with a pen that did not use a ruler, a
## highlighter over whatever is ready, and a tick you make yourself. Claiming a
## mission *is* ticking its box: the row is the key, there is no button on it.
##
## Everything "handwritten" is drawn in whole pixels from a seed, so a row
## wobbles the same way every frame. The words are the game's bitmap type —
## a second, hand-lettered font would be unreadable at this size.
##
## Every row is built once and rewritten in place — the shop's upgrades tab
## learned the hard way that a panel which rebuilds itself on a timer eats the
## taps that land during the rebuild.

signal open_changed(opened: bool)

const ROWS := 3
const PEN := Color8(44, 62, 128)
const PENCIL := Color8(98, 90, 88)
const RED_PEN := Color8(196, 56, 48)
const MARKER := Color8(255, 226, 110)
const SHEET := Color8(250, 244, 224)

var _service: DailyOrdersService
## True from the key press to the first frame of the rise: the state says the
## panel is open while the board is still being measured, so nothing else can
## claim the screen in that window and a close in it is honoured.
var _opening := false
var _scrim: ColorRect
var _board: _Clipboard
var _column: VBoxContainer
var _close_button: Button
var _streak: Label
var _rows: Array[_Row] = []
var _bonus: _Row
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
	_board = _Clipboard.new()
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_board)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 6)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.add_child(_column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 4)
	_column.add_child(head)
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override(&"separation", 0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title_box)
	var title := UiTheme.label(Loc.t("daily.title"), UiTheme.SIZE_TITLE, PEN)
	title.clip_text = true
	title_box.add_child(title)
	var under := _Scribble.new()
	under.kind = &"underline"
	under.custom_minimum_size = Vector2(0.0, 6.0)
	title_box.add_child(under)
	_close_button = Button.new()
	_close_button.flat = true
	_close_button.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN, UiTheme.TOUCH_MIN)
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.pressed.connect(close)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		_close_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	UiTheme.describe(_close_button, Loc.t("daily.title"))
	var cross := _Scribble.new()
	cross.kind = &"cross"
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_close_button.add_child(cross)
	head.add_child(_close_button)

	_streak = UiTheme.label("", UiTheme.SIZE_SMALL, PENCIL)
	_streak.clip_text = true
	_column.add_child(_streak)

	for index in ROWS:
		var row := _Row.new()
		row.seed_no = index + 1
		row.pressed.connect(_on_claim.bind(index))
		_column.add_child(row)
		_rows.append(row)

	_bonus = _Row.new()
	_bonus.seed_no = 9
	_bonus.star = true
	_bonus.pressed.connect(_on_bonus)
	_column.add_child(_bonus)

	_reset = UiTheme.label("", UiTheme.SIZE_SMALL, PENCIL)
	_reset.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reset.clip_text = true
	_column.add_child(_reset)
	_layout()


func setup(service: DailyOrdersService) -> void:
	_service = service
	if _service != null and not _service.state_changed.is_connected(refresh):
		_service.state_changed.connect(refresh)
	refresh()


func open() -> void:
	if visible or _opening:
		return
	_opening = true
	# Open to the game from the press itself, not from the first drawn frame:
	# a charter that arrives two frames later must find this screen taken.
	open_changed.emit(true)
	# Same as the wheel: the height is fitted a frame after the width, and a
	# board must never be seen at rest before its rise — measured hidden,
	# then shown while it is already travelling.
	refresh()
	_layout()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _opening:
		return
	_opening = false
	visible = true
	UiTheme.pop_open(_board, _scrim)
	_close_button.grab_focus()


func close() -> void:
	if not visible and not _opening:
		return
	_opening = false
	if visible:
		# The rise has a drop to answer it: a board that comes up travelling
		# and vanishes standing still is half a gesture.
		UiTheme.pop_close(_board, _scrim, func() -> void: visible = false)
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
		var row := _rows[index]
		if index >= orders.missions.size():
			row.visible = false
			continue
		row.visible = true
		var mission: Dictionary = orders.missions[index]
		var goal := maxi(1, int(mission.get("goal", 1)))
		var progress := clampi(int(mission.get("progress", 0)), 0, goal)
		var claimed := bool(mission.get("claimed", false))
		all_claimed = all_claimed and claimed
		row.show_state(Loc.t("daily.mission.%s" % str(mission.get("id", "")),
			{"goal": str(goal)}), progress, goal, claimed)
	_bonus.show_state(Loc.t("daily.bonus"), 1 if all_claimed else 0, 1,
		orders.bonus_claimed)
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
		_rows[index].refuse()
		return
	AudioManager.play_sfx("milestone")
	AudioManager.play_sfx("coins", 0.05, -4.0)
	refresh()


func _on_bonus() -> void:
	if _service == null:
		return
	if _service.claim_bonus().is_empty():
		AudioManager.play_sfx("deny")
		_bonus.refuse()
		return
	AudioManager.play_sfx("wheel_win")
	refresh()


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
	## Width first, height a frame later: the rows wrap to the board's
	## width, and a height measured before that width propagates is a fantasy
	## that once pushed the wheel's board off the top of a phone.
	if _board == null or not is_instance_valid(_board):
		return
	var safe := _safe_rect
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	if safe.size == Vector2.ZERO:
		safe = view
	safe = safe.intersection(view) if safe.intersects(view) else view
	var width := minf(330.0, safe.size.x - 10.0)
	# The words wrap to exactly the room they have; left at a narrow floor they
	# report the height of a column one word wide and the sheet comes out tall.
	for row: _Row in _rows + [_bonus]:
		if row != null:
			row.set_text_width(width - 72.0)
	_board.size = Vector2(width, 0.0)
	if _layout_pending:
		return
	_layout_pending = true
	await get_tree().process_frame
	_layout_pending = false
	if _board == null or not is_instance_valid(_board):
		return
	var content_h := _board.get_combined_minimum_size().y
	_board.size = Vector2(width, minf(content_h, safe.size.y - 20.0))
	_board.position = (safe.position + (safe.size - _board.size) * 0.5).round()


# ------------------------------------------------------------------ the hand

static func stroke(on: CanvasItem, from: Vector2, to: Vector2, ink: Color,
		weight: float = 1.0, upto: float = 1.0) -> void:
	## A pen line in whole pixels, drawn as far as `upto` (0..1) of its length.
	var span := to - from
	var steps := int(maxf(absf(span.x), absf(span.y)))
	if steps <= 0:
		on.draw_rect(Rect2(from.round(), Vector2(weight, weight)), ink)
		return
	for i in int(steps * clampf(upto, 0.0, 1.0)) + 1:
		var at := (from + span * (float(i) / steps)).round()
		on.draw_rect(Rect2(at, Vector2(weight, weight)), ink)


static func wobble(on: CanvasItem, from: Vector2, to: Vector2, ink: Color,
		seed_no: int, weight: float = 1.0, upto: float = 1.0) -> void:
	## The same line by a hand without a ruler: it drifts a pixel either side.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_no * 7919 + 13
	var parts := maxi(2, int(from.distance_to(to) / 14.0))
	var prev := from
	for i in range(1, parts + 1):
		var t := float(i) / parts
		if t - 1.0 / parts >= upto:
			break
		var next := from.lerp(to, t)
		if i < parts:
			next += Vector2(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		var part := clampf((upto - (t - 1.0 / parts)) * parts, 0.0, 1.0)
		stroke(on, prev, next, ink, weight, part)
		prev = next


class _Clipboard extends MarginContainer:
	## The board itself: hardboard, a spring clip, and one sheet of ruled paper
	## with its margin line, its punch holes and a ring where a mug stood.
	const WOOD := Color8(156, 108, 66)
	const WOOD_D := Color8(104, 68, 44)
	const WOOD_L := Color8(188, 138, 88)
	const EDGE := Color8(52, 34, 30)
	const RULE := Color8(184, 210, 226)
	const MARGIN := Color8(228, 146, 136)
	const SHEET_D := Color8(212, 200, 172)
	const STEEL := Color8(164, 172, 184)
	const STEEL_D := Color8(92, 100, 118)
	const STEEL_L := Color8(226, 232, 238)

	func _init() -> void:
		add_theme_constant_override(&"margin_left", 18)
		add_theme_constant_override(&"margin_right", 16)
		add_theme_constant_override(&"margin_top", 30)
		add_theme_constant_override(&"margin_bottom", 14)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# Hardboard, with a bevel and a little grain.
		draw_rect(Rect2(0, 0, w, h), EDGE)
		draw_rect(Rect2(1, 1, w - 2, h - 2), WOOD)
		draw_rect(Rect2(1, 1, w - 2, 1), WOOD_L)
		draw_rect(Rect2(1, h - 3, w - 2, 2), WOOD_D)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for i in int(h / 9.0):
			var gy := 5.0 + i * 9.0 + rng.randi_range(-2, 2)
			var gx := rng.randi_range(2, int(w * 0.5))
			draw_rect(Rect2(gx, gy, rng.randi_range(18, 70), 1), WOOD_D if i % 3 else WOOD_L)
		# The sheet: a shadow, the paper, a turned-up corner.
		var sheet := Rect2(7, 14, w - 14, h - 21)
		draw_rect(Rect2(sheet.position + Vector2(2, 2), sheet.size), Color(0, 0, 0, 0.28))
		draw_rect(sheet, DailyOrdersPanel.SHEET)
		draw_rect(Rect2(sheet.position.x, sheet.end.y - 1, sheet.size.x, 1), SHEET_D)
		draw_rect(Rect2(sheet.end.x - 1, sheet.position.y, 1, sheet.size.y), SHEET_D)
		# The spring clip, biting the top of the sheet.
		var cx := roundf(w * 0.5)
		draw_rect(Rect2(cx - 38, 4, 76, 18), EDGE)
		draw_rect(Rect2(cx - 37, 5, 74, 16), STEEL)
		draw_rect(Rect2(cx - 37, 5, 74, 2), STEEL_L)
		draw_rect(Rect2(cx - 37, 17, 74, 4), STEEL_D)
		draw_rect(Rect2(cx - 16, 0, 32, 8), EDGE)
		draw_rect(Rect2(cx - 15, 1, 30, 6), STEEL)
		draw_rect(Rect2(cx - 9, 3, 18, 3), EDGE)
		for side: float in [-28.0, 26.0]:
			draw_rect(Rect2(cx + side, 10, 3, 3), STEEL_D)
			draw_rect(Rect2(cx + side, 10, 2, 1), STEEL_L)


class _Scribble extends Control:
	## Small things the pen left on the page: the underline, the X, a cut line.
	var kind: StringName = &"underline"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		match kind:
			&"underline":
				var reach := minf(size.x, 190.0)
				draw_rect(Rect2(0, 2, reach, 2), DailyOrdersPanel.PEN)
			&"cross":
				var c := (size * 0.5).round()
				DailyOrdersPanel.stroke(self, c + Vector2(-6, -6), c + Vector2(6, 6),
					DailyOrdersPanel.RED_PEN, 2.0)
				DailyOrdersPanel.stroke(self, c + Vector2(6, -7), c + Vector2(-6, 5),
					DailyOrdersPanel.RED_PEN, 2.0)
			&"dashes":
				var x := 0.0
				while x < size.x - 4.0:
					draw_rect(Rect2(x, 2, 5, 1), DailyOrdersPanel.PENCIL)
					x += 9.0


class _Row extends MarginContainer:
	## One line of the list. The whole line is the key: when its box can be
	## ticked the highlighter is over it, and pressing it makes the tick.
	signal pressed

	var seed_no := 1
	var star := false
	var _name: Label
	var _count: Label
	var _progress := 0
	var _goal := 1
	var _claimed := false
	var _ready_now := false
	## 0..1 of the tick (and then the strike-through) the pen has drawn so far.
	var _ink := 0.0
	var _nudge := 0.0
	var _t := 0.0
	var _ink_tween: Tween

	func _init() -> void:
		add_theme_constant_override(&"margin_left", 30)
		add_theme_constant_override(&"margin_right", 6)
		add_theme_constant_override(&"margin_top", 7)
		add_theme_constant_override(&"margin_bottom", 9)
		custom_minimum_size.y = UiTheme.TOUCH_MIN
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", 3)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(col)
		_name = UiTheme.label("", UiTheme.SIZE_TITLE, UiTheme.INK)
		_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_name.custom_minimum_size.x = 100.0
		col.add_child(_name)
		_count = UiTheme.label("", UiTheme.SIZE_SMALL, DailyOrdersPanel.PENCIL)
		_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		col.add_child(_count)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		resized.connect(queue_redraw)

	func show_state(text: String, progress: int, goal: int, claimed: bool) -> void:
		var was_claimed := _claimed
		_name.text = text
		_progress = progress
		_goal = goal
		_claimed = claimed
		_ready_now = progress >= goal and not claimed
		_name.label_settings.font_color = UiTheme.INK_SOFT if claimed else UiTheme.INK
		_count.visible = not star and not claimed
		_count.text = "%d/%d" % [progress, goal]
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _ready_now \
			else Control.CURSOR_ARROW
		UiTheme.describe(self, text)
		if claimed and not was_claimed and is_visible_in_tree() \
				and UserPreferences.can_animate():
			_ink = 0.0
			_ink_tween = create_tween()
			_ink_tween.tween_property(self, "_ink", 1.0, 0.42)
		elif claimed:
			if _ink_tween == null or not _ink_tween.is_running():
				_ink = 1.0
		else:
			_ink = 0.0
		queue_redraw()

	func set_text_width(width: float) -> void:
		_name.custom_minimum_size.x = maxf(80.0, width)

	func refuse() -> void:
		## Not yet: the row shakes its head.
		if not UserPreferences.can_animate():
			return
		var tween := create_tween()
		tween.tween_property(self, "_nudge", 3.0, 0.04)
		tween.tween_property(self, "_nudge", -2.0, 0.06)
		tween.tween_property(self, "_nudge", 0.0, 0.06)

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_t += delta
		if _ready_now or (_ink > 0.0 and _ink < 1.0) or _nudge != 0.0:
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		var touch := event as InputEventScreenTouch
		if (click != null and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed) \
				or (touch != null and not touch.pressed) \
				or event.is_action_pressed(&"ui_accept"):
			accept_event()
			pressed.emit()

	func _draw() -> void:
		var pen := DailyOrdersPanel.PEN
		var ox := roundf(_nudge)
		if _ready_now:
			# One pass of highlighter: this line can be ticked.
			var glow := 0.8 + 0.2 * sin(_t * 4.0) if UserPreferences.can_animate() else 1.0
			var m := DailyOrdersPanel.MARKER
			draw_rect(Rect2(0, 1, size.x, size.y - 3), Color(m.r, m.g, m.b, 0.7 * glow))
		if has_focus():
			draw_rect(Rect2(0, size.y - 2, size.x, 1), pen)
		var top := roundf(_name.global_position.y - global_position.y)
		var box := Vector2(4 + ox, top + 2)
		if star:
			_draw_star(box + Vector2(9, 9), pen)
		else:
			# A plain square, two pixels of pen.
			draw_rect(Rect2(box, Vector2(18, 18)), pen)
			draw_rect(Rect2(box + Vector2(2, 2), Vector2(14, 14)),
				DailyOrdersPanel.MARKER if _ready_now else DailyOrdersPanel.SHEET)
		# How far along: one thin line under the words.
		if not star and not _claimed:
			var track := Rect2(30, size.y - 6, size.x - 36, 2)
			draw_rect(track, Color(DailyOrdersPanel.PENCIL, 0.3))
			draw_rect(Rect2(track.position, Vector2(roundf(track.size.x
				* clampf(float(_progress) / float(_goal), 0.0, 1.0)), 2)), pen)
		if _ink > 0.0:
			var red := DailyOrdersPanel.RED_PEN
			var first := clampf(_ink / 0.3, 0.0, 1.0)
			var second := clampf((_ink - 0.3) / 0.7, 0.0, 1.0)
			if star:
				_draw_star(box + Vector2(9, 9), red)
			else:
				DailyOrdersPanel.stroke(self, box + Vector2(3, 8), box + Vector2(8, 14), red, 3.0, first)
				if second > 0.0:
					DailyOrdersPanel.stroke(self, box + Vector2(8, 14), box + Vector2(20, -4), red, 3.0, second)

	func _draw_star(c: Vector2, ink: Color) -> void:
		var pts: Array[Vector2] = []
		for i in 5:
			var a := -PI * 0.5 + TAU * (i * 2 % 5) / 5.0
			pts.append((c + Vector2(cos(a), sin(a)) * 10.0).round())
		for i in 5:
			DailyOrdersPanel.stroke(self, pts[i], pts[(i + 1) % 5], ink, 2.0)
