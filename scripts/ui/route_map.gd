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
var _list: VBoxContainer
var _status: Label
var _open := false
var _safe_rect := Rect2()
var _profile := ""
var _rail: CommandRail
var _focus_return: Control


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

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	_sheet.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 5)
	header.custom_minimum_size.y = 24.0
	column.add_child(header)
	var badge := UiTheme.icon(UiTheme.Icon.SHIP)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(badge)
	var title := UiTheme.label("MAPA-MÚNDI DE ROTAS", UiTheme.SIZE_BODY, UiTheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	var close_button := UiTheme.icon_button(UiTheme.Icon.CLOSE, &"ghost", 26.0,
		"Fechar as rotas")
	close_button.custom_minimum_size = Vector2(30, 24)
	close_button.tooltip_text = "Fechar (Esc)"
	close_button.pressed.connect(close)
	header.add_child(close_button)

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
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 4)
	scroll.add_child(_list)

	EventBus.teus_changed.connect(func(_t: float) -> void:
		if _open:
			_refresh())
	_layout()
	_refresh()


func set_rail(rail: CommandRail) -> void:
	_rail = rail


func open() -> void:
	_open = true
	_focus_return = get_viewport().gui_get_focus_owner()
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

func _refresh() -> void:
	if _list == null or not is_instance_valid(_list):
		return
	_chart.set_routes(GameState.routes)
	var owned := RouteDB.owned(GameState.routes)
	_status.text = "%d %s  -  frete x%.2f" % [owned.size(),
		"rota" if owned.size() == 1 else "rotas",
		RouteDB.reward_multiplier(GameState.routes)]
	for child in _list.get_children():
		child.queue_free()
	var next := RouteDB.next_purchase(GameState.routes)
	for route in RouteDB.ITEMS:
		var id := str(route.id)
		var is_owned := id == str(RouteDB.ITEMS[0].id) or GameState.routes.has(id)
		var is_next := not next.is_empty() and str(next.id) == id
		if not is_owned and not is_next:
			continue
		_list.add_child(_make_card(route, is_owned, is_next))


func _make_card(route: Dictionary, is_owned: bool, is_next: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.y = 44.0
	var affordable := is_next and GameState.can_afford(float(route.cost))
	UiTheme.apply_panel(card, UiTheme.card_style(
		&"done" if is_owned else (&"ready" if affordable else &"normal")))

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	card.add_child(row)
	var mark := UiTheme.icon(UiTheme.Icon.CHECK if is_owned else UiTheme.Icon.SHIP)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override(&"separation", 1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(_clipped(str(route.name), UiTheme.SIZE_SMALL, UiTheme.INK))
	text.add_child(_clipped(str(route.where), UiTheme.SIZE_SMALL,
		UiTheme.INK_SOFT))
	text.add_child(_clipped("frete x%.2f  -  %s" % [float(route.reward),
		str(route.desc)], UiTheme.SIZE_SMALL,
		UiTheme.TEAL_DEEP if is_owned else UiTheme.AMBER_DEEP))

	if not is_owned:
		var buy := UiTheme.button(GameState.fmt(float(route.cost)),
			&"amber" if affordable else &"off", UiTheme.SIZE_SMALL)
		buy.custom_minimum_size = Vector2(66, 28)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.clip_text = true
		UiTheme.describe(buy, "Comprar a rota %s" % str(route.name),
			"Custa %s TEU." % GameState.fmt(float(route.cost)))
		buy.pressed.connect(_buy.bind(str(route.id)))
		row.add_child(buy)
	return card


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
		"text": "Rota aberta: %s. Navios novos a caminho." % str(route.name),
	})
	AudioManager.play_sfx("build")
	_refresh()


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
	_sheet.size = Vector2(safe.size.x - 12.0,
		maxf(220.0, safe.end.y - top - 6.0))
	_sheet.position = Vector2(safe.position.x + 6.0,
		safe.end.y - _sheet.size.y - 6.0)
	# The chart is a sprite at a whole multiple, so its height follows from the
	# width the sheet ended up with rather than from a round number. Picking the
	# scale off the width and then asking for the matching height is what stops
	# the map sitting in the middle of a wide panel with fifty pixels of dead
	# letterbox on each side.
	var inner := _sheet.size.x - 18.0
	var scale := clampi(int(inner / RouteChart.MAP_W), 1, RouteChart.MAX_SCALE)
	_chart.custom_minimum_size.y = float(scale * RouteChart.MAP_H)
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
