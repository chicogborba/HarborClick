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

const CHART_HEIGHT := 132.0

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
	var title := UiTheme.label("ROTAS", UiTheme.SIZE_BODY, UiTheme.INK)
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
	var desktop := _profile == "desktop" \
		or (_profile.is_empty() and safe.size.x >= 700.0)
	if desktop:
		var slot := _rail.content_rect if _rail != null \
			and _rail.content_rect.size != Vector2.ZERO else Rect2()
		if slot.size == Vector2.ZERO:
			var width := clampf(safe.size.x * 0.34, 280.0, 390.0)
			slot = Rect2(Vector2(safe.end.x - width - 8.0, safe.position.y + 20.0),
				Vector2(width, safe.size.y - 28.0))
		_sheet.size = slot.size
		_sheet.position = slot.position
	else:
		var top := safe.position.y + 20.0
		_sheet.size = Vector2(safe.size.x - 12.0,
			maxf(220.0, safe.end.y - top - 6.0))
		_sheet.position = Vector2(safe.position.x + 6.0,
			safe.end.y - _sheet.size.y - 6.0)
	_backdrop.visible = _open
	_sheet.visible = _open
	UiTheme.place_clip(_clip, _sheet, safe)


class RouteChart extends Control:
	## The chart itself. Drawn rather than blitted so the pins always land where
	## the data says, whatever width the board ends up.
	##
	## The landmasses are deliberately crude — a chart on a clipboard is an
	## abstraction, not an atlas — but without any coast at all the pins float
	## on an empty grid and none of the destinations mean anything.

	## Coastlines in the same 0..1 chart space the routes use. A plain array of
	## arrays rather than a const of PackedVector2Array, which GDScript will not
	## accept as a constant expression.
	static var LANDS: Array[PackedVector2Array] = [
		# north america
		PackedVector2Array([Vector2(0.02, 0.06), Vector2(0.30, 0.04),
			Vector2(0.34, 0.22), Vector2(0.24, 0.38), Vector2(0.13, 0.34),
			Vector2(0.04, 0.20)]),
		# south america
		PackedVector2Array([Vector2(0.27, 0.46), Vector2(0.42, 0.44),
			Vector2(0.50, 0.62), Vector2(0.44, 0.84), Vector2(0.34, 0.96),
			Vector2(0.28, 0.74)]),
		# europe and africa
		PackedVector2Array([Vector2(0.52, 0.10), Vector2(0.68, 0.08),
			Vector2(0.74, 0.30), Vector2(0.78, 0.58), Vector2(0.66, 0.80),
			Vector2(0.58, 0.56), Vector2(0.54, 0.28)]),
		# asia
		PackedVector2Array([Vector2(0.76, 0.06), Vector2(0.99, 0.08),
			Vector2(0.98, 0.34), Vector2(0.86, 0.46), Vector2(0.78, 0.26)]),
	]

	var _routes: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_routes(routes: Dictionary) -> void:
		_routes = routes.duplicate()
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, UiTheme.PAPER_DEEP)
		# lat/long grid, faint enough to sit under the ink
		var grid := Color(UiTheme.INK_SOFT, 0.16)
		for gx in range(1, 8):
			var x := size.x * float(gx) / 8.0
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), grid, 1.0)
		for gy in range(1, 5):
			var y := size.y * float(gy) / 5.0
			draw_line(Vector2(0.0, y), Vector2(size.x, y), grid, 1.0)

		# land first, so the grid reads as printed under the coastline
		for outline: PackedVector2Array in LANDS:
			var shape := PackedVector2Array()
			for point in outline:
				shape.append(Vector2(point.x * size.x, point.y * size.y))
			draw_colored_polygon(shape, Color8(196, 178, 146))
			draw_polyline(shape + PackedVector2Array([shape[0]]),
				Color(UiTheme.INK_SOFT, 0.7), 1.0)
		draw_rect(rect, UiTheme.INK_SOFT, false, 1.0)

		var home := Vector2(RouteDB.HOME.x * size.x, RouteDB.HOME.y * size.y)
		for route in RouteDB.ITEMS:
			var id := str(route.id)
			var is_owned := id == str(RouteDB.ITEMS[0].id) or _routes.has(id)
			var at := Vector2(float(route.chart.x) * size.x,
				float(route.chart.y) * size.y)
			if is_owned:
				# A lane the port trades on is inked in; the rest are pencilled
				# destinations it has not reached yet.
				draw_line(home, at, UiTheme.TEAL_DEEP, 1.0)
				draw_circle(at, 3.0, UiTheme.TEAL_DEEP)
				draw_circle(at, 1.0, UiTheme.CREAM)
			else:
				draw_circle(at, 2.0, Color(UiTheme.INK_SOFT, 0.55))
		# home last, so nothing is drawn over the terminal
		draw_circle(home, 4.0, UiTheme.AMBER_DEEP)
		draw_circle(home, 2.0, UiTheme.AMBER)
