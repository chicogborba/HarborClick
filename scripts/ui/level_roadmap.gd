class_name LevelRoadmap
extends CanvasLayer
## A Rota do Terminal: every level from 1 to 30 on one track, with what each
## one hands over — the battle-pass view of `TerminalLevel`.
##
## The rail down the left is the progress itself: amber up to the level the
## port is at (and part-way into the next by XP), slate beyond. Each stop has a
## card: features it opens in teal, cosmetics it gives in rose with a swatch of
## the hat colour, and the +2% every level pays. A level that only pays the 2%
## is a slim card, so the levels that matter stand out when you scroll.
##
## Built once on first open, rewritten in place afterwards: a panel that
## rebuilds its rows on a signal eats the taps that land during the rebuild.

signal open_changed(opened: bool)

const ROSE := Color8(196, 74, 120)
const RAIL_W := 46.0
const NODE_R := 13.0

var _service: TerminalLevelService
## True from the key press to the first frame of the rise: the state says the
## roadmap is open while the board is still being measured, so nothing else can
## claim the screen in that window and a close in it is honoured.
var _opening := false
var _scrim: ColorRect
var _board: PanelContainer
var _column: VBoxContainer
var _close_button: Button
var _level_label: Label
var _xp_label: Label
var _bonus_label: Label
var _bar: ProgressBar
var _scroll: ScrollContainer
var _track: VBoxContainer
var _rows: Array[Dictionary] = []   # {level, card, rail, tag, minor}
var _safe_rect := Rect2()


func _ready() -> void:
	layer = 13
	visible = false
	_scrim = UiTheme.scrim(0.72)
	_scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(_scrim)
	_board = UiTheme.panel(UiTheme.board_style(10, &"green"), false)
	add_child(_board)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 6)
	_board.add_child(_column)
	var header := UiTheme.header(Loc.t("roadmap.title"), close)
	_column.add_child(header.root)
	_close_button = header.close

	# Where you are: the level, the bar to the next, and what it all adds up to.
	var summary := UiTheme.panel(UiTheme.slate_style(true, 6))
	_column.add_child(summary)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override(&"separation", 8)
	srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(srow)
	srow.add_child(UiTheme.icon16(UiTheme.Icon16.LEVEL, 2))
	var scol := VBoxContainer.new()
	scol.add_theme_constant_override(&"separation", 3)
	scol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	srow.add_child(scol)
	_level_label = UiTheme.label("", UiTheme.SIZE_TITLE, UiTheme.AMBER)
	scol.add_child(_level_label)
	_bar = ProgressBar.new()
	var styles := UiTheme.bar_styles()
	_bar.add_theme_stylebox_override(&"background", styles[0])
	_bar.add_theme_stylebox_override(&"fill", styles[1])
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(0.0, 9.0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scol.add_child(_bar)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scol.add_child(line)
	_xp_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.SLATE_TEXT)
	_xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(_xp_label)
	_bonus_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEAL_LIGHT)
	line.add_child(_bonus_label)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(_scroll)
	# The gutter, so the scrollbar never draws over the cards' right edge.
	var pad := MarginContainer.new()
	pad.add_theme_constant_override(&"margin_right", 10)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pad)
	_track = VBoxContainer.new()
	_track.add_theme_constant_override(&"separation", 0)
	_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(_track)
	for level in range(1, TerminalLevel.MAX_LEVEL + 1):
		_rows.append(_build_row(level))


func setup(service: TerminalLevelService) -> void:
	_service = service
	if _service != null and not _service.xp_changed.is_connected(_on_xp):
		_service.xp_changed.connect(_on_xp)


func _on_xp() -> void:
	if visible:
		refresh()


# --------------------------------------------------------------------- rows

static func rewards_for(level: int) -> Array[Dictionary]:
	## What a level hands over, in the order the card lists it:
	## {kind: feature|cosmetic, name, icon, color?}. The +2% is not listed here;
	## every level carries it.
	var out: Array[Dictionary] = []
	for feature in TerminalLevel.new().unlocks_at(level):
		if LevelHud.FEATURE_NAMES.has(feature):
			out.append({"kind": &"feature",
				"name": Loc.t(str(LevelHud.FEATURE_NAMES[feature]))})
	for item: Dictionary in CosmeticDb.at_level(level):
		out.append({"kind": &"cosmetic", "name": str(item.name),
			"icon": str(item.get("icon", "STAR")), "hat": str(item.get("hat", ""))})
	return out


func _build_row(level: int) -> Dictionary:
	var rewards := rewards_for(level)
	var minor := rewards.is_empty()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(row)
	var rail := _Rail.new()
	rail.level = level
	rail.major = not minor
	rail.custom_minimum_size = Vector2(RAIL_W, 34.0 if minor else 0.0)
	rail.size_flags_vertical = Control.SIZE_FILL
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rail)

	var holder := MarginContainer.new()
	holder.add_theme_constant_override(&"margin_top", 3)
	holder.add_theme_constant_override(&"margin_bottom", 3)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(holder)
	var card := UiTheme.panel(UiTheme.card_style(&"normal"))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var title := UiTheme.label(Loc.t("roadmap.level", {"n": str(level)}),
		UiTheme.SIZE_BODY if not minor else UiTheme.SIZE_SMALL, UiTheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var bonus := UiTheme.label(Loc.t("level.reward"), UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT)
	top.add_child(bonus)
	var tag := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER_DEEP)
	top.add_child(tag)
	for reward: Dictionary in rewards:
		col.add_child(_reward_line(reward))
	return {"level": level, "card": card, "rail": rail, "tag": tag,
		"minor": minor, "title": title, "bonus": bonus}


func _reward_line(reward: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 5)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cosmetic := StringName(reward.kind) == &"cosmetic"
	var hat := str(reward.get("hat", ""))
	if cosmetic and not hat.is_empty():
		# A swatch of the helmet colour: the reward, shown rather than named.
		var swatch := _Swatch.new()
		swatch.tint = hat
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(swatch)
	else:
		var key := str(reward.get("icon", "STAR")) if cosmetic else "CHEVRON"
		var icon := UiTheme.icon(UiTheme.Icon.get(key, UiTheme.Icon.STAR))
		icon.modulate = ROSE if cosmetic else UiTheme.TEAL
		line.add_child(icon)
	var text := UiTheme.label(Loc.t("roadmap.cosmetic" if cosmetic else "roadmap.unlocks",
		{"name": str(reward.name)}), UiTheme.SIZE_SMALL, ROSE if cosmetic else UiTheme.TEAL_DEEP)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size.x = 80.0
	line.add_child(text)
	return line


# --------------------------------------------------------------- open/close

func open() -> void:
	if visible or _opening:
		return
	_opening = true
	# Open to the game from the press itself, not from the first drawn frame:
	# a charter that arrives two frames later must find this screen taken.
	open_changed.emit(true)
	# Measured hidden, then shown while it is already travelling — the board
	# must never be seen at rest before its rise.
	refresh()
	_layout()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _opening:
		return
	_opening = false
	visible = true
	_scroll_to_current()
	UiTheme.pop_open(_board, _scrim)
	_close_button.grab_focus()


func close() -> void:
	if not visible and not _opening:
		return
	_opening = false
	if visible:
		UiTheme.pop_close(_board, _scrim, func() -> void: visible = false)
	open_changed.emit(false)


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and event.keycode in [KEY_ESCAPE, KEY_BACK]:
		close()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	## Rewrites every stop in place. Never adds or frees a node.
	if _service == null or _service.rules == null:
		return
	var rules := _service.rules
	var level := rules.level
	var maxed := level >= TerminalLevel.MAX_LEVEL
	_level_label.text = Loc.t("roadmap.level", {"n": str(level)})
	_bar.value = rules.progress_to_next()
	if maxed:
		_xp_label.text = Loc.t("roadmap.max")
	else:
		var lo := TerminalLevel.xp_for_level(level)
		var hi := TerminalLevel.xp_for_level(level + 1)
		_xp_label.text = Loc.t("roadmap.xp", {"have": str(rules.xp - lo),
			"need": str(hi - lo)})
	_bonus_label.text = Loc.t("roadmap.total",
		{"p": str(roundi((GameState.level_multiplier() - 1.0) * 100.0))})
	var progress := rules.progress_to_next()
	for row: Dictionary in _rows:
		var at := int(row.level)
		var state := 0 if at < level else (1 if at == level else 2)
		var rail: _Rail = row.rail
		rail.state = state
		# The segment from this stop to the next spans two rows: the lower half
		# of this one and the upper half of the next. XP fills it in that order.
		var into := progress if not maxed else 0.0
		rail.fill_below = 1.0 if at < level else (clampf(into * 2.0, 0.0, 1.0) if at == level else 0.0)
		rail.fill_above = 1.0 if at <= level else (clampf(into * 2.0 - 1.0, 0.0, 1.0) if at == level + 1 else 0.0)
		rail.last = at == TerminalLevel.MAX_LEVEL
		rail.queue_redraw()
		var card: PanelContainer = row.card
		UiTheme.apply_panel(card, UiTheme.card_style(
			&"ready" if state == 1 else (&"done" if state == 0 else &"normal")))
		card.modulate = Color(1, 1, 1, 0.62 if state == 2 else 1.0)
		var tag: Label = row.tag
		tag.text = Loc.t("roadmap.current") if state == 1 else ""
		tag.visible = state == 1


func _scroll_to_current() -> void:
	if _service == null:
		return
	var index := clampi(_service.rules.level - 1, 0, _rows.size() - 1)
	var row_card: Control = _rows[index].card
	var target := row_card.get_parent().get_parent() as Control
	_scroll.scroll_vertical = maxi(0, int(target.position.y - _scroll.size.y * 0.35))


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, view))
	_layout()


func _layout() -> void:
	if _board == null:
		return
	var view := get_viewport().get_visible_rect().size
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, view)
	_scrim.position = Vector2.ZERO
	_scrim.size = view
	var width := minf(400.0, safe.size.x - 16.0)
	var height := minf(720.0, safe.size.y - 24.0)
	_board.size = Vector2(width, height)
	_board.position = (safe.position + (safe.size - _board.size) * 0.5).round()


class _Rail extends Control:
	## One stop of the track: the line through it, and its numbered node.
	var level := 1
	var state := 2          # 0 reached, 1 current, 2 ahead
	var major := false
	var fill_above := 0.0   # 0..1 of the segment over the node that is earned
	var fill_below := 0.0   # 0..1 of the segment under the node that is earned
	var last := false
	var _num: Label

	func _ready() -> void:
		_num = UiTheme.label(str(level), UiTheme.SIZE_SMALL, UiTheme.CREAM)
		_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_num)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var cx := floorf(size.x * 0.5)
		var cy := floorf(size.y * 0.5)
		var on := UiTheme.AMBER
		var off := Color8(70, 66, 84)
		var w := 6.0
		# The line above the node, and below it filled as far as the XP goes.
		draw_rect(Rect2(cx - w * 0.5, 0.0, w, cy), off)
		if fill_above > 0.0:
			draw_rect(Rect2(cx - w * 0.5, 0.0, w, roundf(cy * fill_above)), on)
		if not last:
			var below := size.y - cy
			draw_rect(Rect2(cx - w * 0.5, cy, w, below), off)
			if fill_below > 0.0:
				draw_rect(Rect2(cx - w * 0.5, cy, w, roundf(below * fill_below)), on)
		var r := LevelRoadmap.NODE_R if major or state == 1 else 9.0
		var ring := UiTheme.HULL_EDGE
		var fill := on if state == 0 else (UiTheme.TEAL if state == 1 else off)
		if state == 1:
			draw_circle(Vector2(cx, cy), r + 4.0, UiTheme.AMBER, true, -1.0, false)
		draw_circle(Vector2(cx, cy), r + 2.0, ring, true, -1.0, false)
		draw_circle(Vector2(cx, cy), r, fill, true, -1.0, false)
		if _num != null:
			_num.label_settings.font_color = UiTheme.INK if state == 0 else UiTheme.CREAM
			_num.position = Vector2(cx - 14.0, cy - 8.0)
			_num.size = Vector2(28.0, 16.0)


class _Swatch extends Control:
	## A hat colour, or a rainbow of them.
	var tint := ""

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.HULL_EDGE)
		var inner := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		if tint == "rainbow":
			var bands := 4
			for i in bands:
				draw_rect(Rect2(inner.position + Vector2(inner.size.x * i / bands, 0),
					Vector2(ceilf(inner.size.x / bands), inner.size.y)),
					Color.from_hsv(float(i) / bands, 0.7, 1.0))
		else:
			draw_rect(inner, Color(tint))
