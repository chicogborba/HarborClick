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

const CHART_HEIGHT := 156.0

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
	## A compact equirectangular world chart. Coast points are quantized to the
	## rendered pixel grid, so even on a wide desktop panel it keeps the stepped
	## silhouette of a printed 16-bit atlas instead of becoming smooth vector
	## blobs.

	static var LANDMASSES: Array[PackedVector2Array] = [
		# North America, including Alaska, Mexico and Florida.
		PackedVector2Array([
			Vector2(0.01, 0.14), Vector2(0.05, 0.09), Vector2(0.12, 0.08),
			Vector2(0.16, 0.11), Vector2(0.23, 0.09), Vector2(0.29, 0.13),
			Vector2(0.31, 0.19), Vector2(0.27, 0.23), Vector2(0.25, 0.29),
			Vector2(0.23, 0.34), Vector2(0.21, 0.39), Vector2(0.19, 0.41),
			Vector2(0.17, 0.38), Vector2(0.15, 0.43), Vector2(0.12, 0.39),
			Vector2(0.11, 0.33), Vector2(0.07, 0.30), Vector2(0.04, 0.24),
			Vector2(0.01, 0.22),
		]),
		# Central America.
		PackedVector2Array([
			Vector2(0.15, 0.41), Vector2(0.18, 0.42), Vector2(0.20, 0.47),
			Vector2(0.24, 0.49), Vector2(0.23, 0.52), Vector2(0.19, 0.49),
			Vector2(0.16, 0.46),
		]),
		# South America.
		PackedVector2Array([
			Vector2(0.22, 0.49), Vector2(0.28, 0.47), Vector2(0.34, 0.51),
			Vector2(0.38, 0.58), Vector2(0.37, 0.67), Vector2(0.34, 0.75),
			Vector2(0.32, 0.84), Vector2(0.28, 0.93), Vector2(0.25, 0.85),
			Vector2(0.24, 0.75), Vector2(0.21, 0.66), Vector2(0.20, 0.56),
		]),
		# Greenland.
		PackedVector2Array([
			Vector2(0.29, 0.08), Vector2(0.34, 0.05), Vector2(0.38, 0.10),
			Vector2(0.37, 0.21), Vector2(0.33, 0.27), Vector2(0.30, 0.19),
		]),
		# Europe.
		PackedVector2Array([
			Vector2(0.43, 0.27), Vector2(0.46, 0.22), Vector2(0.50, 0.24),
			Vector2(0.53, 0.21), Vector2(0.57, 0.25), Vector2(0.58, 0.31),
			Vector2(0.55, 0.35), Vector2(0.51, 0.33), Vector2(0.48, 0.37),
			Vector2(0.45, 0.34),
		]),
		# Africa.
		PackedVector2Array([
			Vector2(0.44, 0.35), Vector2(0.51, 0.33), Vector2(0.58, 0.37),
			Vector2(0.61, 0.45), Vector2(0.59, 0.55), Vector2(0.56, 0.65),
			Vector2(0.52, 0.74), Vector2(0.48, 0.66), Vector2(0.46, 0.56),
			Vector2(0.43, 0.46),
		]),
		# Asia, with Arabia, India, Indochina and the eastern coast.
		PackedVector2Array([
			Vector2(0.54, 0.22), Vector2(0.61, 0.14), Vector2(0.72, 0.12),
			Vector2(0.82, 0.15), Vector2(0.91, 0.13), Vector2(0.99, 0.19),
			Vector2(0.98, 0.30), Vector2(0.94, 0.35), Vector2(0.90, 0.42),
			Vector2(0.85, 0.45), Vector2(0.83, 0.51), Vector2(0.80, 0.58),
			Vector2(0.77, 0.55), Vector2(0.75, 0.47), Vector2(0.71, 0.52),
			Vector2(0.68, 0.46), Vector2(0.64, 0.48), Vector2(0.61, 0.42),
			Vector2(0.57, 0.38), Vector2(0.58, 0.31),
		]),
		# Australia.
		PackedVector2Array([
			Vector2(0.78, 0.68), Vector2(0.84, 0.64), Vector2(0.91, 0.68),
			Vector2(0.94, 0.76), Vector2(0.90, 0.85), Vector2(0.82, 0.84),
			Vector2(0.77, 0.78),
		]),
	]

	static var RELIEF: Array[PackedVector2Array] = [
		# Rockies, Andes, Atlas/East Africa and Himalaya.
		PackedVector2Array([Vector2(0.10, 0.18), Vector2(0.13, 0.27),
			Vector2(0.15, 0.36)]),
		PackedVector2Array([Vector2(0.25, 0.55), Vector2(0.27, 0.69),
			Vector2(0.29, 0.84)]),
		PackedVector2Array([Vector2(0.46, 0.42), Vector2(0.52, 0.44),
			Vector2(0.56, 0.58)]),
		PackedVector2Array([Vector2(0.65, 0.35), Vector2(0.74, 0.37),
			Vector2(0.82, 0.35)]),
	]

	static var ISLANDS := [
		Vector2(0.43, 0.27), # Iceland
		Vector2(0.45, 0.31), # Britain
		Vector2(0.61, 0.68), # Madagascar
		Vector2(0.88, 0.40), # Japan
		Vector2(0.80, 0.61), Vector2(0.84, 0.63), # Indonesia
		Vector2(0.96, 0.84), Vector2(0.97, 0.89), # New Zealand
	]

	var _routes: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_routes(routes: Dictionary) -> void:
		_routes = routes.duplicate()
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var ocean := Color8(33, 82, 108)
		var ocean_deep := Color8(24, 60, 84)
		var shelf := Color8(73, 125, 132)
		var coast := Color8(43, 58, 52)
		var land := Color8(126, 145, 91)
		var land_light := Color8(154, 164, 105)
		var relief := Color8(91, 101, 67)
		draw_rect(rect, ocean)

		# Stepped bathymetry and sparse wave pixels make the water read as
		# deliberate pixel art without competing with route lines.
		for band in 4:
			var y := roundf(size.y * (0.18 + band * 0.19))
			for x in range((band % 2) * 9, int(size.x), 23):
				draw_rect(Rect2(Vector2(x, y), Vector2(6, 1)),
					Color(ocean_deep, 0.32))

		var grid := Color(0.66, 0.84, 0.84, 0.14)
		for gx in range(1, 12):
			var x := roundf(size.x * float(gx) / 12.0)
			draw_line(Vector2(x, 0), Vector2(x, size.y), grid, 1.0)
		for gy in range(1, 6):
			var y := roundf(size.y * float(gy) / 6.0)
			draw_line(Vector2(0, y), Vector2(size.x, y), grid, 1.0)
		var equator_y := roundf(size.y * 0.50)
		for x in range(0, int(size.x), 8):
			draw_rect(Rect2(Vector2(x, equator_y), Vector2(4, 1)),
				Color(0.78, 0.91, 0.82, 0.32))

		for outline: PackedVector2Array in LANDMASSES:
			var shape := _shape(outline)
			var shelf_shape := PackedVector2Array()
			for point in shape:
				shelf_shape.append(point + Vector2(1, 1))
			draw_colored_polygon(shelf_shape, shelf)
			draw_colored_polygon(shape, land)
			draw_polyline(shape + PackedVector2Array([shape[0]]), coast, 1.0)

		# Polar cap, deserts and a few raised plateaus add geographic structure.
		draw_rect(Rect2(Vector2(0, size.y - 5), Vector2(size.x, 5)),
			Color8(198, 213, 193))
		_patch(Rect2(Vector2(0.45, 0.42), Vector2(0.12, 0.07)),
			land_light)
		_patch(Rect2(Vector2(0.79, 0.72), Vector2(0.10, 0.05)),
			Color8(164, 139, 88))
		for ridge: PackedVector2Array in RELIEF:
			var points := _shape(ridge)
			draw_polyline(points, relief, 2.0)
			for point in points:
				draw_rect(Rect2(point - Vector2.ONE, Vector2(2, 2)),
					land_light)
		for island: Vector2 in ISLANDS:
			draw_rect(Rect2(_pixel(island) - Vector2.ONE, Vector2(3, 3)),
				land)

		# Tiny compass rose in open South Pacific water.
		var compass := Vector2(size.x * 0.70, size.y * 0.80).round()
		draw_line(compass + Vector2(0, -6), compass + Vector2(0, 6),
			Color(0.88, 0.94, 0.83, 0.55), 1.0)
		draw_line(compass + Vector2(-6, 0), compass + Vector2(6, 0),
			Color(0.88, 0.94, 0.83, 0.55), 1.0)
		draw_colored_polygon(PackedVector2Array([
			compass + Vector2(0, -7), compass + Vector2(-2, -2),
			compass + Vector2(2, -2)]), Color8(237, 197, 85))
		draw_rect(rect, coast, false, 1.0)

		var home := _pixel(RouteDB.HOME)
		for route in RouteDB.ITEMS:
			var id := str(route.id)
			var is_owned := id == str(RouteDB.ITEMS[0].id) or _routes.has(id)
			var points: Array[Vector2] = [RouteDB.HOME]
			for raw_point in route.get("ports", [route.chart]):
				points.append(raw_point)
			var at := _pixel(points.back())
			if is_owned:
				for index in points.size() - 1:
					_draw_wrapped_lane(points[index], points[index + 1],
						Color8(255, 208, 80))
				draw_circle(at, 3.0, Color8(22, 54, 66))
				draw_circle(at, 2.0, Color8(255, 220, 92))
			else:
				draw_circle(at, 2.0, Color(0.82, 0.90, 0.78, 0.72))
				draw_circle(at, 1.0, ocean_deep)
		draw_circle(home, 4.0, Color8(22, 54, 66))
		draw_circle(home, 2.0, Color8(255, 112, 62))

	func _pixel(point: Vector2) -> Vector2:
		return Vector2(roundf(point.x * size.x), roundf(point.y * size.y))

	func _shape(points: PackedVector2Array) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point in points:
			result.append(_pixel(point))
		return result

	func _patch(normalized: Rect2, color: Color) -> void:
		var top_left := _pixel(normalized.position)
		var patch_size := Vector2(
			roundf(normalized.size.x * size.x),
			roundf(normalized.size.y * size.y))
		draw_rect(Rect2(top_left, patch_size), color)

	func _draw_wrapped_lane(a: Vector2, b: Vector2, color: Color) -> void:
		## A Pacific leg exits one chart edge and enters the other instead of
		## drawing straight across Eurasia.
		if absf(a.x - b.x) <= 0.5:
			draw_line(_pixel(a), _pixel(b), color, 2.0)
			return
		var left := a
		var right := b
		if left.x > right.x:
			left = b
			right = a
		var wrapped_left := Vector2(left.x + 1.0, left.y)
		var t := (1.0 - right.x) / maxf(wrapped_left.x - right.x, 0.001)
		var crossing_y := lerpf(right.y, wrapped_left.y, t)
		draw_line(_pixel(right), Vector2(size.x, roundf(crossing_y * size.y)),
			color, 2.0)
		draw_line(Vector2(0, roundf(crossing_y * size.y)), _pixel(left),
			color, 2.0)
