class_name UpgradeMap
extends Control
## The upgrade catalogue as the thing it actually is: a network diagram.
##
## The first version of this screen was a column of cards. Every node was on it,
## every gate was explained in words, and it was still a list — you could read
## what blocked one row, but not *see* that six trunks leave the same depot and
## rejoin nowhere, or that the branch you are three purchases into runs out in two
## more. A list can answer "what is in my way"; only a picture answers "where does
## this go".
##
## So it is drawn the way the game's own subject matter draws a network: as a
## transit map. Each trunk is a coloured line running west to east. Each upgrade
## is a station on it. A line you have bought is laid in solid steel; one you have
## not is a dashed survey line, and its stations are unlit. Depth is distance
## along the line, so "three stops away" is literally three purchases away.
##
## Everything is `_draw()` on one Control rather than a node per station. A
## fifty-station map made of Controls is fifty Controls to lay out, and the tab
## refreshes while it is open — the version of this screen that rebuilt its
## children on a timer ate every tap that landed during a rebuild.

signal node_selected(id: String)

## Metro-map metrics, in map pixels before zoom.
const COL_W := 88.0
const LANE_H := 36.0
const TRUNK_GAP := 26.0
const MARGIN := Vector2(52.0, 26.0)
const DOT_R := 7.0
const LINE_W := 4.0

const MIN_ZOOM := 0.55
const MAX_ZOOM := 2.4
## A press that travels further than this was a pan, not a tap on a station.
const TAP_SLOP := 8.0

## One colour per trunk, in `UpgradeDB.BRANCHES` order. Chosen the way a transit
## authority chooses them — maximally separable at a glance, and none of them the
## paper the map is printed on.
const LINE_COLOURS := {
	"mao": Color8(228, 146, 54),
	"patio": Color8(78, 150, 200),
	"cais": Color8(206, 88, 76),
	"ramal": Color8(96, 178, 118),
	"portao": Color8(174, 118, 196),
	"comando": Color8(72, 168, 168),
}

var _nodes: Dictionary = {}        # id -> {pos, branch, depth, item}
var _order: Array[String] = []     # draw order, shallow first
var _headers: Array[Dictionary] = []
var _bounds := Rect2()
var _zoom := 1.0
var _pan := Vector2.ZERO
var _selected := ""
var _press_at := Vector2.ZERO
var _press_pan := Vector2.ZERO
var _dragging := false
var _touches: Dictionary = {}
var _pinch_ref := 0.0
var _pinch_zoom := 1.0
var _owned_cache := {}


var _framed := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_build_layout()
	resized.connect(_on_resized)


func _on_resized() -> void:
	# A Control has no size until the first layout pass, so the opening view can
	# only be chosen once there is a panel to fit it to. After that a resize —
	# a rotation, a keyboard opening — keeps the player where they were rather
	# than throwing them back to the depot.
	if not _framed and size.x > 1.0:
		_framed = true
		reset_view()
		return
	_clamp_pan()


# ------------------------------------------------------------------- layout

func _build_layout() -> void:
	## Station positions, computed once from the graph.
	##
	## Depth is the column, so a node always sits east of everything that opens
	## it. Nodes that share a trunk *and* a depth are the branch points — the two
	## halves of an exclusive pair, or a spur off the main line — and they get a
	## lane each, stacked north to south.
	_nodes.clear()
	_order.clear()
	_headers.clear()
	var y := MARGIN.y
	for branch: Dictionary in UpgradeDB.BRANCHES:
		var branch_id := str(branch.get("id", ""))
		var items := UpgradeDB.items_in_branch(branch_id)
		if items.is_empty():
			continue
		# Lanes are inherited, not stacked. A station takes the lane of whatever
		# opens it and only steps aside when that lane is already occupied at its
		# own depth — so a plain chain draws as one straight line and only a real
		# fork bends. Stacking by arrival order instead gave every trunk the height
		# of its most-branched column, and a five-station chain drew as a diagonal
		# staircase with a trunk's worth of empty paper under it.
		var taken: Dictionary = {}       # depth -> {lane: true}
		var lane_of: Dictionary = {}     # id -> lane
		var max_lane := 0
		var placed: Array[Dictionary] = []
		items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var da := UpgradeDB.depth_of(str(a.get("id", "")))
			var db := UpgradeDB.depth_of(str(b.get("id", "")))
			if da != db:
				return da < db
			return float(a.get("cost", 0.0)) < float(b.get("cost", 0.0)))
		for item: Dictionary in items:
			var id := str(item.get("id", ""))
			var depth := UpgradeDB.depth_of(id)
			var lane := 0
			for parent in UpgradeDB.requires_of(item):
				if lane_of.has(parent):
					lane = int(lane_of[parent])
					break
			var occupied: Dictionary = taken.get(depth, {})
			while occupied.has(lane):
				lane += 1
			occupied[lane] = true
			taken[depth] = occupied
			lane_of[id] = lane
			max_lane = maxi(max_lane, lane)
			placed.append({"id": id, "depth": depth, "lane": lane, "item": item})
		_headers.append({"title": str(branch.get("title", "")),
			"branch": branch_id, "y": y})
		for entry: Dictionary in placed:
			var id := str(entry.id)
			_nodes[id] = {
				"pos": Vector2(MARGIN.x + float(entry.depth) * COL_W,
					y + 22.0 + float(entry.lane) * LANE_H),
				"branch": branch_id,
				"depth": int(entry.depth),
				"item": entry.item,
			}
			_order.append(id)
		y += 22.0 + float(max_lane + 1) * LANE_H + TRUNK_GAP
	_recompute_bounds(y)


func _recompute_bounds(height: float) -> void:
	var max_x := MARGIN.x
	for id: String in _nodes:
		max_x = maxf(max_x, float(_nodes[id].pos.x))
	_bounds = Rect2(Vector2.ZERO, Vector2(max_x + MARGIN.x, height))


func map_size() -> Vector2:
	return _bounds.size


# ---------------------------------------------------------------- transform

func _to_screen(p: Vector2) -> Vector2:
	return p * _zoom + _pan


func _to_map(p: Vector2) -> Vector2:
	return (p - _pan) / _zoom


func _clamp_pan() -> void:
	## The map may be smaller than the window in either axis; when it is, it is
	## centred rather than pinned to a corner, because a small diagram stuck to the
	## top-left of a big panel reads as a layout bug.
	var view := size
	var span := _bounds.size * _zoom
	for axis in 2:
		if span[axis] <= view[axis]:
			_pan[axis] = (view[axis] - span[axis]) * 0.5
		else:
			_pan[axis] = clampf(_pan[axis], view[axis] - span[axis], 0.0)
	queue_redraw()


func focus_on(id: String) -> void:
	if not _nodes.has(id):
		return
	_pan = size * 0.5 - Vector2(_nodes[id].pos) * _zoom
	_clamp_pan()


func reset_view() -> void:
	## Open at the west end of every line, at a zoom the station names can be read
	## at.
	##
	## Fitting the whole network to the panel was the obvious choice and the wrong
	## one: on a phone that lands around 0.45, every name disappears, and the tab
	## opens on a field of anonymous dots. A transit map is read zoomed in and
	## panned — the overview is what pinching *out* is for.
	_zoom = clampf(size.x / 420.0, 0.8, 1.15)
	_pan = Vector2.ZERO
	_clamp_pan()


func set_selected(id: String) -> void:
	if _selected == id:
		return
	_selected = id
	queue_redraw()


func refresh() -> void:
	## Ownership changed under us. Only redraw when it actually did: this is
	## called from the shop's refresh timer, and repainting a fifty-station map
	## three times a second to show the same thing is work nobody asked for.
	var owned := {}
	for id: String in _nodes:
		owned[id] = _state_of(id)
	if owned == _owned_cache:
		return
	_owned_cache = owned
	queue_redraw()


func _state_of(id: String) -> int:
	## 2 owned, 1 buyable, 0 shut. The only three things the map draws.
	if GameState.has_upgrade(id):
		return 2
	var item: Dictionary = _nodes[id].item
	return 1 if GameState.upgrade_available(item) else 0


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	# Trunk labels first, behind everything, the way a map prints its line names.
	for header: Dictionary in _headers:
		var ink := _line_colour(str(header.branch))
		var at := _to_screen(Vector2(MARGIN.x - 22.0, float(header.y)))
		if at.y < -20.0 or at.y > size.y + 20.0:
			continue
		draw_string(UiTheme.FONT, at, str(header.title).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiTheme.SIZE_SMALL,
			ink.lerp(UiTheme.PAPER_DEEP, 0.2))
		# A rule under the name, in the line's own colour, so a trunk reads as a
		# band of the map rather than as a caption floating over the one above it.
		draw_line(at + Vector2(0.0, 3.0),
			Vector2(size.x, at.y + 3.0), ink.lerp(UiTheme.PAPER, 0.72), 1.0)

	for id in _order:
		_draw_edges(id)
	for id in _order:
		_draw_station(id)


func _draw_edges(id: String) -> void:
	var node: Dictionary = _nodes[id]
	var state := _state_of(id)
	var colour := _line_colour(str(node.branch))
	for parent in UpgradeDB.requires_of(node.item):
		if not _nodes.has(parent):
			continue
		var a := _to_screen(Vector2(_nodes[parent].pos))
		var b := _to_screen(Vector2(node.pos))
		# A line the player owns both ends of is built track; anything else is a
		# survey line, drawn dashed so an unbuilt connection never reads as one
		# that is simply a different colour.
		var built := state == 2 and GameState.has_upgrade(parent)
		var ink := colour if built else colour.lerp(UiTheme.PAPER_DEEP, 0.34)
		var width := LINE_W * _zoom if built else maxf(1.5, 2.6 * _zoom)
		# Metro elbow: run east from the parent, turn once, run into the station.
		var elbow := Vector2(a.x + (b.x - a.x) * 0.55, a.y)
		var elbow2 := Vector2(elbow.x, b.y)
		if built:
			_line(a, elbow, ink, width)
			_line(elbow, elbow2, ink, width)
			_line(elbow2, b, ink, width)
		else:
			_dashed(a, elbow, ink, width)
			_dashed(elbow, elbow2, ink, width)
			_dashed(elbow2, b, ink, width)


func _line(a: Vector2, b: Vector2, ink: Color, width: float) -> void:
	if a.distance_squared_to(b) < 0.01:
		return
	draw_line(a, b, ink, width)


func _dashed(a: Vector2, b: Vector2, ink: Color, width: float) -> void:
	var span := a.distance_to(b)
	if span < 0.01:
		return
	var step := maxf(4.0, 6.0 * _zoom)
	var dir := (b - a) / span
	var travelled := 0.0
	while travelled < span:
		var end := minf(travelled + step * 0.55, span)
		draw_line(a + dir * travelled, a + dir * end, ink, width)
		travelled += step


func _draw_station(id: String) -> void:
	var node: Dictionary = _nodes[id]
	var at := _to_screen(Vector2(node.pos))
	var radius := DOT_R * _zoom
	# Cheap cull: a fifty-station map at high zoom is mostly off screen.
	if at.x < -60.0 or at.x > size.x + 60.0 or at.y < -40.0 or at.y > size.y + 40.0:
		return
	var state := _state_of(id)
	var colour := _line_colour(str(node.branch))
	var item: Dictionary = node.item

	if id == _selected:
		draw_circle(at, radius + 5.0 * _zoom, UiTheme.AMBER)
	# An interchange — a node that excludes a sibling — is drawn as a ring rather
	# than a dot, the way a transit map marks a station where you have to choose.
	var interchange := not UpgradeDB.excludes_of(item).is_empty()
	match state:
		2:
			draw_circle(at, radius, colour)
			draw_arc(at, radius, 0.0, TAU, 20, UiTheme.CREAM, 2.0 * _zoom)
		1:
			draw_circle(at, radius, UiTheme.PAPER)
			draw_arc(at, radius, 0.0, TAU, 20, colour, 2.5 * _zoom)
		_:
			draw_circle(at, radius * 0.8, UiTheme.PAPER_DEEP.darkened(0.25))
			draw_arc(at, radius * 0.8, 0.0, TAU, 16,
				colour.lerp(UiTheme.PAPER_DEEP, 0.55), 1.5 * _zoom)
	if interchange and state != 0:
		draw_arc(at, radius * 0.45, 0.0, TAU, 14,
			UiTheme.INK if state == 2 else colour, 1.5 * _zoom)

	# Names only once there is room for them; below that the map is a shape you
	# navigate by, and a wall of overlapping five-pixel type is worse than none.
	if _zoom < 0.7:
		return
	# The authored short name, never a truncation. A cut-off name is not a shorter
	# name — it is the same name, unreadable, plus a full stop that looks like part
	# of it.
	var label := UpgradeDB.short_of(item)
	var ink := UiTheme.INK if state != 0 else UiTheme.INK_SOFT
	draw_string(UiTheme.FONT, at + Vector2(-COL_W * 0.5 * _zoom + 4.0,
		radius + 11.0 * _zoom), label, HORIZONTAL_ALIGNMENT_CENTER,
		COL_W * _zoom - 8.0, UiTheme.SIZE_SMALL, ink)


func _line_colour(branch: String) -> Color:
	return LINE_COLOURS.get(branch, UiTheme.TEAL)


# -------------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, 1.12)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / 1.12)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_press(mb.position)
			else:
				_end_press(mb.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_pan = _press_pan + (mm.position - _press_at)
		_clamp_pan()
		accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() == 1:
				_begin_press(st.position)
			elif _touches.size() == 2:
				# A second finger cancels the tap and starts a pinch.
				_dragging = false
				_pinch_ref = _touch_span()
				_pinch_zoom = _zoom
		else:
			if _touches.size() == 1 and _touches.has(st.index):
				_end_press(st.position)
			_touches.erase(st.index)
			_pinch_ref = 0.0
		accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2 and _pinch_ref > 1.0:
			var span := _touch_span()
			if span > 1.0:
				_set_zoom(_pinch_zoom * span / _pinch_ref, _touch_centre())
		elif _dragging:
			_pan = _press_pan + (sd.position - _press_at)
			_clamp_pan()
		accept_event()


func _touch_span() -> float:
	var points: Array = _touches.values()
	if points.size() < 2:
		return 0.0
	return (Vector2(points[0]) - Vector2(points[1])).length()


func _touch_centre() -> Vector2:
	var points: Array = _touches.values()
	if points.size() < 2:
		return size * 0.5
	return (Vector2(points[0]) + Vector2(points[1])) * 0.5


func _begin_press(at: Vector2) -> void:
	_press_at = at
	_press_pan = _pan
	_dragging = true


func _end_press(at: Vector2) -> void:
	var was_tap := _dragging and _press_at.distance_to(at) < TAP_SLOP
	_dragging = false
	if not was_tap:
		return
	var hit := _station_at(at)
	if hit.is_empty():
		return
	set_selected(hit)
	node_selected.emit(hit)


func _station_at(screen: Vector2) -> String:
	## Nearest station within a finger's reach. Nearest rather than first-hit
	## because two stations can be a lane apart at low zoom, and the one whose
	## circle you technically landed in is not always the one you aimed at.
	var best := ""
	var best_distance := UiTheme.TOUCH_MIN * 0.6
	for id in _order:
		var at := _to_screen(Vector2(_nodes[id].pos))
		var distance := at.distance_to(screen)
		if distance < best_distance:
			best_distance = distance
			best = id
	return best


func _zoom_at(anchor: Vector2, factor: float) -> void:
	_set_zoom(_zoom * factor, anchor)


func _set_zoom(wanted: float, anchor: Vector2) -> void:
	## Zoom about a point: whatever was under the fingers stays under them. Zooming
	## about the origin instead sends the thing you were looking at off the edge,
	## which on a map is the difference between a control and a fight.
	var next := clampf(wanted, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next, _zoom):
		return
	var before := _to_map(anchor)
	_zoom = next
	_pan = anchor - before * _zoom
	_clamp_pan()
