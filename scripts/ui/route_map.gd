class_name RouteMap
extends CanvasLayer
## The chart on the clipboard: where this terminal trades, and what it would
## cost to trade further out.
##
## The map is not decoration with a shop bolted underneath. Every pin is a lane
## in `RouteDB`, drawn at the position the data says it sits at, and the lines
## radiating from home are exactly the lanes the port owns — so looking at the
## chart tells you the same thing reading the save would.

signal open_changed(opened: bool)

## Starting height only; `_layout` picks the real one from the sheet's width so
## the map lands on a whole multiple with no dead letterbox.
const CHART_HEIGHT := 96.0

var _backdrop: ColorRect
var _sheet: PanelContainer
var _clip: TextureRect
var _chart: RouteChart
var _title: Label
var _close_button: Button
var _column: VBoxContainer
var _list: VBoxContainer
var _status: Label
var _open := false
var _safe_rect := Rect2()
var _profile := ""
var _rail: CommandRail
var _focus_return: Control
## One card per lane, alive for as long as the board is. See `_process`.
var _cards: Dictionary = {}
var _dirty := false
var _refresh_timer := 0.0

## How often the prices and the "still short by" line are allowed to catch up.
## Fast enough that a key going from grey to amber feels immediate, slow enough
## that it is not a per-frame relayout of the whole list.
const REFRESH_INTERVAL := 0.25


func _ready() -> void:
	layer = 12
	_backdrop = UiTheme.scrim(0.76)
	_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventScreenTouch and event.pressed):
			close())
	add_child(_backdrop)

	_sheet = PanelContainer.new()
	UiTheme.apply_panel(_sheet, UiTheme.board_style(9))
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	_clip = UiTheme.clip_badge()
	add_child(_clip)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 4)
	_sheet.add_child(_column)
	var column := _column

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 5)
	header.custom_minimum_size.y = 24.0
	column.add_child(header)
	var badge := UiTheme.icon(UiTheme.Icon.SHIP)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(badge)
	_title = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.clip_text = true
	header.add_child(_title)
	_close_button = UiTheme.icon_button(UiTheme.Icon.CLOSE, &"ghost", 26.0)
	_close_button.custom_minimum_size = Vector2(30, 24)
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	_chart = RouteChart.new()
	_chart.custom_minimum_size.y = CHART_HEIGHT
	column.add_child(_chart)

	_status = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.clip_text = true
	column.add_child(_status)

	var sheet := UiTheme.panel(UiTheme.paper_style(4))
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(sheet)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiTheme.style_scroll(scroll)
	sheet.add_child(scroll)
	# Same gutter the settings board reserves, for the same reason: the bar is
	# drawn over the child's last few pixels, which here is the edge of the buy
	# key.
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override(&"margin_right",
		int(UiTheme.SCROLL_WIDTH))
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(gutter)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 4)
	gutter.add_child(_list)

	# Marks the board stale rather than rebuilding it. `teus_changed` is emitted
	# every frame the port earns, and answering it directly is what made this
	# panel impossible to use — see `_process`.
	EventBus.teus_changed.connect(func(_t: float) -> void: _dirty = true)
	Loc.language_changed.connect(func(_code: StringName) -> void:
		_apply_language()
		_dirty = true)
	# The sheet is sized to the list inside it, and a list of wrapped labels does
	# not know its own height until it has been laid out at a real width — so the
	# first `_layout` always works from a stale minimum and clamps to the full
	# screen. Re-running when the list settles is what turns that into the right
	# height rather than a clipboard two-thirds full of blank paper. It converges:
	# the sheet's *width* comes from the safe area alone, so re-laying out cannot
	# change how the labels wrap.
	_list.minimum_size_changed.connect(_layout)
	_apply_language()
	_rebuild_cards()
	_refresh()
	_layout()


func set_rail(rail: CommandRail) -> void:
	_rail = rail


func _apply_language() -> void:
	## The chrome. Everything inside a card is written by `_refresh`, which runs
	## on the next tick anyway, so this only has to cover what a refresh does not
	## touch.
	_title.text = Loc.t("routes.title")
	UiTheme.describe(_close_button, Loc.t("routes.close_name"))
	_close_button.tooltip_text = Loc.t("common.close_hint")


func open() -> void:
	_open = true
	_focus_return = get_viewport().gui_get_focus_owner()
	_refresh_timer = 0.0
	_dirty = false
	_refresh()
	_layout()
	UiTheme.focus_first(_sheet)
	open_changed.emit(true)


func close() -> void:
	if not _open:
		return
	_open = false
	_layout()
	UiTheme.restore_focus(_focus_return)
	_focus_return = null
	open_changed.emit(false)


func is_open() -> bool:
	return _open


func _unhandled_key_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		close()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------- content

func _process(delta: float) -> void:
	## The board is live, and being live used to make it unusable.
	##
	## `teus_changed` fires from `GameState._process` on every frame the port is
	## earning anything at all. This panel answered it by freeing every card and
	## building new ones — sixty times a second. A Button emits `pressed` on
	## release, and only if the press *and* the release landed on the same node,
	## so the buy key was destroyed under the player's finger before the tap
	## finished. Every single time. Buying a route was not hard, or expensive, or
	## gated behind something unexplained: it was impossible for as long as the
	## port had any production at all, which is to say from the first machine on.
	##
	## Cards are built once and their contents rewritten now, and the rewrite is
	## throttled besides, because a price that re-renders every frame is not more
	## accurate — just more expensive.
	if not _open:
		return
	_refresh_timer += delta
	if not _dirty and _refresh_timer < REFRESH_INTERVAL:
		return
	_dirty = false
	_refresh_timer = 0.0
	_refresh()


func _rebuild_cards() -> void:
	## One card per lane in the table, in the order the lanes open. All of them,
	## not just the ones in play: the chart is the only place the game says where
	## this port could eventually trade, and hiding every lane past the next one
	## turned a world map into a two-row shopping list.
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_cards.clear()
	for route in RouteDB.ITEMS:
		var card := _make_card(route)
		_cards[str(route.id)] = card
		_list.add_child(card)


func _make_card(route: Dictionary) -> PanelContainer:
	var id := str(route.id)
	var card := PanelContainer.new()
	card.name = "Lane_%s" % id
	card.custom_minimum_size.y = 44.0

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override(&"separation", 5)
	card.add_child(row)
	var mark := UiTheme.icon(UiTheme.Icon.SHIP)
	mark.name = "Mark"
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)

	var text := VBoxContainer.new()
	text.name = "Text"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override(&"separation", 1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	# The name gets a line to itself. Sharing it with the freight rate squeezed
	# "River Plate Basin" down to "River Plate ...", and a lane whose *name* is
	# elided is a row you cannot identify.
	var title := _clipped("", UiTheme.SIZE_SMALL, UiTheme.INK)
	title.name = "Name"
	text.add_child(title)

	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override(&"separation", 4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(head)
	var where := _clipped(str(route.where), UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	where.name = "Where"
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(where)
	var freight := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER_DEEP)
	freight.name = "Freight"
	freight.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(freight)

	# Wrapped, not clipped. These are one short sentence each and they are the
	# only thing on the card that says what the lane is actually like; trimming
	# them to an ellipsis threw away the entire reason to read the row.
	var meta := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.AMBER_DEEP)
	meta.name = "Meta"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.custom_minimum_size.x = 0.0
	text.add_child(meta)

	var buy := UiTheme.button("", &"off", UiTheme.SIZE_SMALL)
	buy.name = "Buy"
	buy.custom_minimum_size = Vector2(66, 28)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.clip_text = true
	buy.pressed.connect(_buy.bind(id))
	row.add_child(buy)
	return card


func _refresh() -> void:
	if _list == null or not is_instance_valid(_list):
		return
	if _cards.size() != RouteDB.ITEMS.size():
		_rebuild_cards()
	_chart.set_routes(GameState.routes)
	var owned := RouteDB.owned(GameState.routes)
	var next := RouteDB.next_purchase(GameState.routes)
	_status.text = Loc.t("routes.status", {
		"count": Loc.tn("routes.count", owned.size()),
		"rate": "%.2f" % RouteDB.reward_multiplier(GameState.routes),
	})

	var previous_name := ""
	for index in RouteDB.ITEMS.size():
		var route: Dictionary = RouteDB.ITEMS[index]
		var id := str(route.id)
		var card: PanelContainer = _cards.get(id)
		if card == null or not is_instance_valid(card):
			continue
		var is_owned := index == 0 or GameState.routes.has(id)
		var is_next := not next.is_empty() and str(next.id) == id
		var cost := float(route.cost)
		var affordable := is_next and GameState.can_afford(cost)
		_apply_card(card, route, {
			"owned": is_owned, "next": is_next, "affordable": affordable,
			"cost": cost, "after": previous_name,
		})
		previous_name = RouteDB.display_name(id)


func _apply_card(card: PanelContainer, route: Dictionary,
		state: Dictionary) -> void:
	var id := str(route.id)
	var is_owned: bool = state.owned
	var is_next: bool = state.next
	var affordable: bool = state.affordable
	var cost: float = state.cost
	UiTheme.apply_panel(card, UiTheme.card_style(
		&"done" if is_owned else (&"ready" if affordable else
			(&"normal" if is_next else &"locked"))))

	var mark := card.get_node(^"Row/Mark") as TextureRect
	mark.texture = UiTheme.icon_texture(UiTheme.Icon.CHECK if is_owned
		else (UiTheme.Icon.SHIP if is_next else UiTheme.Icon.LOCK))
	# A lane the port cannot reach yet is dimmed as well as marked, but never
	# *only* dimmed: the padlock and the "opens after" line both say it too.
	mark.modulate = Color(1, 1, 1, 1.0 if is_owned or is_next else 0.55)

	var title := card.get_node(^"Row/Text/Name") as Label
	title.text = RouteDB.display_name(id)
	title.label_settings.font_color = UiTheme.INK if is_owned or is_next \
		else UiTheme.INK_SOFT

	var freight := card.get_node(^"Row/Text/Head/Freight") as Label
	freight.text = Loc.t("routes.freight", {"rate": "%.2f" % float(route.reward)})
	freight.label_settings.font_color = UiTheme.TEAL_DEEP if is_owned \
		else (UiTheme.AMBER_DEEP if is_next else UiTheme.INK_SOFT)

	var meta := card.get_node(^"Row/Text/Meta") as Label
	if is_owned:
		meta.text = RouteDB.display_desc(id)
		meta.label_settings.font_color = UiTheme.TEAL_DEEP
	elif is_next:
		# What the lane costs is on the key. What it is short by belongs in the
		# text, because "you cannot afford this" and "you are 4K away" are
		# different amounts of information and the second one is the useful one.
		meta.text = RouteDB.display_desc(id) if affordable \
			else Loc.t("routes.missing",
				{"amount": GameState.fmt(cost - GameState.teus)})
		meta.label_settings.font_color = UiTheme.AMBER_DEEP
	else:
		meta.text = Loc.t("routes.locked", {"name": str(state.after)})
		meta.label_settings.font_color = UiTheme.INK_SOFT

	var buy := card.get_node(^"Row/Buy") as Button
	# Present but not shown, rather than added and removed: a control that comes
	# and goes changes the focus order underneath a keyboard user every refresh.
	buy.visible = is_next
	buy.disabled = not is_next
	buy.focus_mode = Control.FOCUS_ALL if is_next else Control.FOCUS_NONE
	if is_next:
		buy.text = GameState.fmt(cost)
		UiTheme.style_button(buy, &"amber" if affordable else &"off")
		UiTheme.describe(buy,
			Loc.t("routes.buy_name", {"name": RouteDB.display_name(id)}),
			Loc.t("routes.buy_hint", {"cost": GameState.fmt(cost)}))


func _clipped(text: String, size: int, color: Color) -> Label:
	var label := UiTheme.label(text, size, color)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = 0.0
	return label


func _buy(id: String) -> void:
	## Lanes open outward in order, so the only purchasable route is the next
	## one — buying is never a menu of unrelated options.
	var next := RouteDB.next_purchase(GameState.routes)
	var route := RouteDB.get_item(id)
	if next.is_empty() or str(next.id) != id or route.is_empty():
		AudioManager.play_sfx("deny")
		return
	if not GameState.spend(float(route.cost)):
		AudioManager.play_sfx("deny")
		return
	GameState.routes[id] = true
	EventBus.route_bought.emit(id)
	EventBus.notification_requested.emit({
		"id": "route_%s" % id, "kind": &"unlock", "priority": 2,
		"text": Loc.t("routes.bought", {"name": RouteDB.display_name(id)}),
	})
	AudioManager.play_sfx("build")
	# Buying moves the whole ladder along by one, so this is the one moment the
	# board must not wait for the throttle.
	_refresh()
	SaveManager.request_save(&"route")


# -------------------------------------------------------------------- layout

func apply_view_metrics(metrics: Dictionary) -> void:
	_safe_rect = metrics.get("safe_rect",
		Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	_profile = str(metrics.get("profile", ""))
	_layout()


func _layout() -> void:
	if _sheet == null or not is_instance_valid(_sheet):
		return
	var safe := _safe_rect if _safe_rect.size != Vector2.ZERO \
		else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var top := safe.position.y + 20.0
	var available := maxf(220.0, safe.end.y - top - 6.0)
	_sheet.size = Vector2(safe.size.x - 12.0, available)
	# The chart is a sprite at a whole multiple, so its height follows from the
	# width the sheet ended up with rather than from a round number. Picking the
	# scale off the width and then asking for the matching height is what stops
	# the map sitting in the middle of a wide panel with fifty pixels of dead
	# letterbox on each side.
	var inner := _sheet.size.x - 18.0
	var scale := clampi(int(inner / RouteChart.MAP_W), 1, RouteChart.MAX_SCALE)
	_chart.custom_minimum_size.y = float(scale * RouteChart.MAP_H)
	# Only as tall as there is chart and lanes to show. Six routes on a tall
	# phone left a third of the clipboard as blank paper, which reads as a list
	# that failed to load rather than as a list that has ended.
	if _column != null and is_instance_valid(_column) and _list != null:
		# The lane list lives in a ScrollContainer, whose minimum height is
		# deliberately tiny — so the column's own minimum says nothing about how
		# many lanes there are. Its content has to be added by hand.
		_sheet.size.y = clampf(_column.get_combined_minimum_size().y
			+ _list.get_combined_minimum_size().y + 22.0, 220.0, available)
	_sheet.position = Vector2(safe.position.x + 6.0,
		safe.end.y - _sheet.size.y - 6.0)
	_backdrop.visible = _open
	_sheet.visible = _open
	UiTheme.place_clip(_clip, _sheet, safe)


class RouteChart extends Control:
	## The world, blitted at an integer scale, with the lanes drawn over it.
	##
	## This used to build the continents at runtime out of a dozen filled
	## polygons scaled to whatever height the panel happened to have. Polygons do
	## not become pixel art by being drawn small — they become blurry pixel art,
	## which is why the chart looked like a diagram in a game made of sprites.
	## The map is a generated sprite now (`tools/sprites/gen_worldmap.py`), so it
	## is authored once at 96x48 and never resampled: the board picks the largest
	## whole multiple that fits and letterboxes the remainder.

	const MAP := preload("res://assets/sprites/map_world.png")
	const MAP_W := 96
	const MAP_H := 48
	## Three whole pixels per map pixel is as tall as the chart may get before it
	## starts eating the lane list under it.
	const MAX_SCALE := 3

	var _routes: Dictionary = {}
	## Where the map actually landed inside the control, so a lane pinned at
	## 0..1 lands on the same pixel as the coastline under it.
	var _frame := Rect2()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_routes(routes: Dictionary) -> void:
		_routes = routes.duplicate()
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func map_frame() -> Rect2:
		return _frame

	func _draw() -> void:
		var scale := clampi(mini(int(size.x / MAP_W), int(size.y / MAP_H)),
			1, MAX_SCALE)
		var drawn := Vector2(MAP.get_width(), MAP.get_height()) * float(scale)
		_frame = Rect2(((size - drawn) * 0.5).floor(), drawn)
		# The letterbox is the same deep water the map's own abyss is, so a panel
		# that is not an exact multiple reads as more ocean rather than as a gap.
		draw_rect(Rect2(Vector2.ZERO, size), Color8(18, 44, 68))
		draw_texture_rect(MAP, _frame, false)
		draw_rect(Rect2(Vector2.ZERO, size), Color8(44, 60, 56), false, 1.0)

		var home := _pixel(RouteDB.HOME)
		for route in RouteDB.ITEMS:
			var id := str(route.id)
			var is_owned := id == str(RouteDB.ITEMS[0].id) or _routes.has(id)
			var points: Array[Vector2] = [RouteDB.HOME]
			for raw_point in route.get("ports", [route.chart]):
				points.append(raw_point)
			var at := _pixel(points.back())
			if is_owned:
				# Drawn twice: a dark under-stroke first, so a lane stays legible
				# where it crosses pale desert or ice.
				for index in points.size() - 1:
					_draw_wrapped_lane(points[index], points[index + 1],
						Color8(18, 40, 54), 3.0)
				for index in points.size() - 1:
					_draw_wrapped_lane(points[index], points[index + 1],
						Color8(255, 208, 80), 1.0)
				draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)),
					Color8(22, 54, 66))
				draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)),
					Color8(255, 220, 92))
			else:
				draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)),
					Color(0.10, 0.20, 0.26, 0.85))
				draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)),
					Color(0.82, 0.90, 0.78, 0.75))
		draw_rect(Rect2(home - Vector2(3, 3), Vector2(7, 7)), Color8(22, 54, 66))
		draw_rect(Rect2(home - Vector2(2, 2), Vector2(5, 5)), Color8(255, 112, 62))
		draw_rect(Rect2(home - Vector2(1, 1), Vector2(3, 3)), Color8(255, 214, 170))

	func _pixel(point: Vector2) -> Vector2:
		## 0..1 chart space to a pixel inside the blitted map, not inside the
		## control: the pins have to sit on the coastline, and the coastline is
		## letterboxed whenever the panel is not an exact multiple of 96x48.
		return (_frame.position + Vector2(point.x * _frame.size.x,
			point.y * _frame.size.y)).round()

	func _draw_wrapped_lane(a: Vector2, b: Vector2, color: Color,
			width: float = 1.0) -> void:
		## A Pacific leg exits one chart edge and enters the other instead of
		## drawing straight across Eurasia.
		if absf(a.x - b.x) <= 0.5:
			draw_line(_pixel(a), _pixel(b), color, width)
			return
		var left := a
		var right := b
		if left.x > right.x:
			left = b
			right = a
		var wrapped_left := Vector2(left.x + 1.0, left.y)
		var t := (1.0 - right.x) / maxf(wrapped_left.x - right.x, 0.001)
		var crossing_y := lerpf(right.y, wrapped_left.y, t)
		var edge_y := roundf(_frame.position.y + crossing_y * _frame.size.y)
		draw_line(_pixel(right), Vector2(_frame.end.x, edge_y), color, width)
		draw_line(Vector2(_frame.position.x, edge_y), _pixel(left), color, width)
