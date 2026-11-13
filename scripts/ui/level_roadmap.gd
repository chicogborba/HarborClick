class_name LevelRoadmap
extends CanvasLayer
## O Passe do Terminal: every level from 1 to 30 laid out as a pass — a track
## you travel left to right, with something waiting at every stop.
##
## It used to be a list: thirty cards down a rail, telling you what each level
## had already done for you. Nothing on it could be touched. A pass is the same
## thirty levels the other way round: reaching a tier *earns* its prize and the
## player collects it here, by hand, so a level-up leaves something on the
## table instead of only a line in a log. `TerminalLevel.reward_for` decides
## the prize and `TerminalLevelService.claim` pays it; this draws the track.
##
## The track scrolls sideways. Each tier is a column: its stop on the rail
## (filled as far as the XP goes), a card with the prize and whatever the level
## opens, and one key under it — green to collect, a padlock with the level it
## waits for, or a tick once it is in the bag.
##
## Built once on first open, rewritten in place afterwards: a panel that
## rebuilds its rows on a signal eats the taps that land during the rebuild.

signal open_changed(opened: bool)

const ROSE := Color8(196, 74, 120)
const TIER_W := 92.0
const RAIL_H := 30.0

var _service: TerminalLevelService
## True from the key press to the first frame of the rise: the state says the
## pass is open while the board is still being measured, so nothing else can
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
var _track: HBoxContainer
var _claim_all: Button
var _tiers: Array[Dictionary] = []   # {level, rail, card, art, key, prize}
var _safe_rect := Rect2()
var _layout_pending := false


func _ready() -> void:
	layer = 13
	visible = false
	_scrim = UiTheme.scrim(0.72)
	_scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(_scrim)
	_board = UiTheme.panel(UiTheme.board_style(10, &"gold"), false)
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
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_scroll(_scroll)
	_column.add_child(_scroll)
	# Room under the keys, so the scrollbar never draws over them.
	var pad := MarginContainer.new()
	pad.add_theme_constant_override(&"margin_bottom", 10)
	_scroll.add_child(pad)
	_track = HBoxContainer.new()
	_track.add_theme_constant_override(&"separation", 0)
	pad.add_child(_track)
	for level in range(1, TerminalLevel.MAX_LEVEL + 1):
		_tiers.append(_build_tier(level))

	_claim_all = UiTheme.button("", &"amber", UiTheme.SIZE_SMALL)
	_claim_all.custom_minimum_size.y = UiTheme.TOUCH_MIN
	_claim_all.pressed.connect(_on_claim_all)
	_column.add_child(_claim_all)


func setup(service: TerminalLevelService) -> void:
	_service = service
	if _service != null and not _service.xp_changed.is_connected(_on_xp):
		_service.xp_changed.connect(_on_xp)


func _on_xp() -> void:
	if visible:
		refresh()


# -------------------------------------------------------------------- tiers

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


static func prize_text(reward: Dictionary) -> String:
	## The prize in a few words, for the card under its picture.
	match StringName(reward.get("kind", &"")):
		&"cash":
			return Loc.t("pass.reward.cash", {"min": str(int(reward.get("minutes", 0)))})
		&"tokens":
			return Loc.t("pass.reward.tokens", {"n": str(int(reward.get("tokens", 1)))})
		&"surge":
			var text := Loc.t("pass.reward.surge", {
				"mult": str(int(reward.get("mult", 1.0))),
				"min": str(int(float(reward.get("seconds", 0.0)) / 60.0))})
			if int(reward.get("tokens", 0)) > 0:
				text += "\n+ " + Loc.t("pass.reward.tokens",
					{"n": str(int(reward.get("tokens", 0)))})
			return text
	return Loc.t("pass.start")


func _build_tier(level: int) -> Dictionary:
	var reward := TerminalLevel.reward_for(level)
	var tier := VBoxContainer.new()
	tier.add_theme_constant_override(&"separation", 3)
	tier.custom_minimum_size.x = TIER_W
	_track.add_child(tier)
	var rail := _Rail.new()
	rail.level = level
	rail.custom_minimum_size = Vector2(TIER_W, RAIL_H)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier.add_child(rail)

	var holder := MarginContainer.new()
	holder.add_theme_constant_override(&"margin_left", 3)
	holder.add_theme_constant_override(&"margin_right", 3)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier.add_child(holder)
	var card := UiTheme.panel(UiTheme.card_style(&"normal"))
	holder.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	# The prize, standing in a well like the machines in the shop.
	var well := UiTheme.panel(UiTheme.well_style(4))
	well.custom_minimum_size.y = 44.0
	col.add_child(well)
	var kind := StringName(reward.get("kind", &""))
	var art := UiTheme.icon16({&"cash": UiTheme.Icon16.TEU,
		&"tokens": UiTheme.Icon16.TOKEN, &"surge": UiTheme.Icon16.BOOST}.get(
			kind, UiTheme.Icon16.LEVEL), 2)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	well.add_child(art)
	var prize := UiTheme.label(prize_text(reward), UiTheme.SIZE_SMALL, UiTheme.INK)
	prize.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prize.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prize.custom_minimum_size.x = TIER_W - 22.0
	col.add_child(prize)
	for extra: Dictionary in rewards_for(level):
		col.add_child(_unlock_line(extra))
	var key_pad := MarginContainer.new()
	key_pad.add_theme_constant_override(&"margin_left", 3)
	key_pad.add_theme_constant_override(&"margin_right", 3)
	tier.add_child(key_pad)
	var key := UiTheme.button("", &"off", UiTheme.SIZE_SMALL)
	key.custom_minimum_size.y = UiTheme.TOUCH_MIN
	key.clip_text = true
	key.pressed.connect(_on_claim.bind(level))
	key.visible = level > 1
	key_pad.add_child(key)
	if level <= 1:
		key_pad.custom_minimum_size.y = UiTheme.TOUCH_MIN
	return {"level": level, "rail": rail, "card": card, "art": art, "key": key,
		"root": tier}


func _unlock_line(reward: Dictionary) -> Control:
	## What the level opens by itself: a feature in teal, a cosmetic in rose
	## with a swatch of the helmet colour — the reward shown rather than named.
	var cosmetic := StringName(reward.kind) == &"cosmetic"
	var hat := str(reward.get("hat", ""))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cosmetic and not hat.is_empty():
		var swatch := _Swatch.new()
		swatch.tint = hat
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(swatch)
	var text := UiTheme.label(str(reward.name), UiTheme.SIZE_SMALL,
		ROSE if cosmetic else UiTheme.TEAL_DEEP)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = TIER_W - 22.0
	box.add_child(text)
	return box


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
	## Rewrites every tier in place. Never adds or frees a node.
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
	var progress := rules.progress_to_next() if not maxed else 0.0
	for tier: Dictionary in _tiers:
		var at := int(tier.level)
		var reached := at <= level
		var claimed := rules.claimed.has(at) or at == 1
		var ready := rules.can_claim(at)
		var rail: _Rail = tier.rail
		rail.state = 0 if at < level else (1 if at == level else 2)
		# The stretch between two stops spans two columns: the right half of
		# this one and the left half of the next. XP fills it in that order.
		rail.fill_left = 1.0 if reached else (
			clampf(progress * 2.0 - 1.0, 0.0, 1.0) if at == level + 1 else 0.0)
		rail.fill_right = 1.0 if at < level else (
			clampf(progress * 2.0, 0.0, 1.0) if at == level else 0.0)
		rail.first = at == 1
		rail.last = at == TerminalLevel.MAX_LEVEL
		rail.queue_redraw()
		var card: PanelContainer = tier.card
		UiTheme.apply_panel(card, UiTheme.card_style(
			&"ready" if ready else (&"done" if claimed and reached else &"normal")))
		card.modulate = Color(1, 1, 1, 1.0 if reached else 0.7)
		(tier.art as CanvasItem).modulate = Color(1, 1, 1, 0.45) \
			if claimed and at > 1 else Color.WHITE
		var key: Button = tier.key
		if ready:
			key.text = Loc.t("daily.claim")
			key.disabled = false
			UiTheme.style_button(key, &"go")
		elif claimed:
			key.text = Loc.t("daily.done")
			key.disabled = true
			UiTheme.style_button(key, &"ghost")
		else:
			key.text = Loc.t("level.short", {"n": str(at)})
			key.disabled = true
			UiTheme.style_button(key, &"off")
	var waiting := _service.claimable_count()
	_claim_all.text = Loc.t("pass.claim_all", {"n": str(waiting)})
	_claim_all.disabled = waiting == 0
	UiTheme.style_button(_claim_all, &"amber" if waiting > 0 else &"off")


func _on_claim(level: int) -> void:
	if _service == null:
		return
	var reward := _service.claim(level)
	if reward.is_empty():
		AudioManager.play_sfx("deny")
		return
	_celebrate(level)
	refresh()


func _on_claim_all() -> void:
	if _service == null:
		return
	var paid := _service.claim_all()
	if paid.is_empty():
		AudioManager.play_sfx("deny")
		return
	for reward: Dictionary in paid:
		_celebrate(int(reward.get("tier", 0)), false)
	AudioManager.play_sfx("wheel_win")
	refresh()


func _celebrate(level: int, sound: bool = true) -> void:
	if sound:
		AudioManager.play_sfx("milestone")
		AudioManager.play_sfx("coins", 0.05, -4.0)
	Fx.haptic(20)
	var index := level - 1
	if index < 0 or index >= _tiers.size():
		return
	UiMotion.flash(_tiers[index].card)
	UiMotion.punch(_tiers[index].card)


func _scroll_to_current() -> void:
	## The first prize still waiting, or else where the port stands now.
	if _service == null:
		return
	var waiting := _service.rules.claimable_tiers()
	var level := waiting[0] if not waiting.is_empty() else _service.rules.level
	var root: Control = _tiers[clampi(level - 1, 0, _tiers.size() - 1)].root
	_scroll.scroll_horizontal = maxi(0,
		int(root.position.x - (_scroll.size.x - TIER_W) * 0.35))


func apply_view_metrics(metrics: Dictionary) -> void:
	var view := get_viewport().get_visible_rect().size
	_safe_rect = metrics.get("safe_rect", Rect2(Vector2.ZERO, view))
	_layout()


func _layout() -> void:
	## Width first, height a frame later: the cards wrap their text to a fixed
	## column, and a height read before that has propagated is a guess.
	if _board == null or not is_instance_valid(_board):
		return
	var view := get_viewport().get_visible_rect().size
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, view)
	_scrim.position = Vector2.ZERO
	_scrim.size = view
	var width := minf(620.0, safe.size.x - 12.0)
	_board.size = Vector2(width, _board.size.y)
	if _layout_pending or not is_inside_tree():
		return
	_layout_pending = true
	await get_tree().process_frame
	_layout_pending = false
	if _board == null or not is_instance_valid(_board):
		return
	# A scroll container does not ask for room on the axis it does not scroll.
	_scroll.custom_minimum_size.y = _scroll.get_child(0).get_combined_minimum_size().y
	var height := minf(_board.get_combined_minimum_size().y, safe.size.y - 24.0)
	_board.size = Vector2(width, height)
	_board.position = (safe.position + (safe.size - _board.size) * 0.5).round()


class _Rail extends Control:
	## One stop of the track: the line through it, and its numbered plate.
	var level := 1
	var state := 2          # 0 passed, 1 here, 2 ahead
	var fill_left := 0.0    # 0..1 of the stretch into the stop that is earned
	var fill_right := 0.0   # 0..1 of the stretch out of it that is earned
	var first := false
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
		var off := Color8(96, 84, 78)
		var edge := UiTheme.INK
		var h := 6.0
		if not first:
			draw_rect(Rect2(0.0, cy - h * 0.5 - 1.0, cx, h + 2.0), edge)
			draw_rect(Rect2(0.0, cy - h * 0.5, cx, h), off)
			if fill_left > 0.0:
				draw_rect(Rect2(0.0, cy - h * 0.5, roundf(cx * fill_left), h), on)
		if not last:
			var span := size.x - cx
			draw_rect(Rect2(cx, cy - h * 0.5 - 1.0, span, h + 2.0), edge)
			draw_rect(Rect2(cx, cy - h * 0.5, span, h), off)
			if fill_right > 0.0:
				draw_rect(Rect2(cx, cy - h * 0.5, roundf(span * fill_right), h), on)
		# The plate: a square with its corners knocked off, in whole pixels.
		var r := 12.0 if state == 1 else 10.0
		var fill := on if state == 0 else (UiTheme.TEAL if state == 1 else off)
		if state == 1:
			_plate(cx, cy, r + 3.0, UiTheme.AMBER)
		_plate(cx, cy, r + 1.0, edge)
		_plate(cx, cy, r, fill)
		if _num != null:
			_num.label_settings.font_color = UiTheme.INK if state == 0 else UiTheme.CREAM
			_num.position = Vector2(cx - 14.0, cy - 8.0)
			_num.size = Vector2(28.0, 16.0)

	func _plate(cx: float, cy: float, r: float, color: Color) -> void:
		draw_rect(Rect2(cx - r + 2.0, cy - r, r * 2.0 - 4.0, r * 2.0), color)
		draw_rect(Rect2(cx - r, cy - r + 2.0, r * 2.0, r * 2.0 - 4.0), color)
		draw_rect(Rect2(cx - r + 1.0, cy - r + 1.0, r * 2.0 - 2.0, r * 2.0 - 2.0), color)


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
