class_name GroundBaker
## Bakes the whole ground plane into one texture: grass verge, kerb, paved
## yard with randomised tile variants, quay apron, road paint and container-bay
## markings. Rebuilt when a parcel is purchased.

const TILE := 16

static var _cache: Dictionary = {}


static func _img(name: String) -> Image:
	if not _cache.has(name):
		var t: Texture2D = load("res://assets/sprites/%s.png" % name)
		_cache[name] = t.get_image()
	return _cache[name]


static func bake(world_h: int) -> ImageTexture:
	var w := int(PortLayout.WORLD_W)
	var img := Image.create(w, world_h, false, Image.FORMAT_RGBA8)
	# Transparent, not sea blue. The ground plane sits at z -8 and the animated
	# water at z -9, so a solid fill out here painted flat blue straight over
	# the water shader — every wave, band and wake was being drawn and then
	# covered up. Past the quay there is nothing to bake: that is the sea's job.
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = 13371337

	var yard_tiles: Array[Image] = []
	for v in 4:
		yard_tiles.append(_img("gr_yard_%d" % v))
	var dirt_tiles: Array[Image] = []
	for v in 3:
		dirt_tiles.append(_img("gr_dirt_%d" % v))
	var quay_tile := _img("gr_quay")
	var grass_tile := _img("gr_grass")

	var paved_top := int(PortLayout.TOP_MARGIN)
	var paved_bottom := int(PortLayout.world_bottom() - PortLayout.SOUTH_MARGIN)
	var verge := int(PortLayout.YARD_X0) - 6      # grass runs up to the kerb

	# --- base plane ---
	for ty in range(0, world_h, TILE):
		for tx in range(0, int(PortLayout.WATER_X0), TILE):
			var src: Image
			if tx < verge or ty < paved_top - TILE:
				src = grass_tile
			elif tx >= int(PortLayout.QUAY_X0):
				src = quay_tile
			elif ty >= paved_bottom:
				src = dirt_tiles[rng.randi() % dirt_tiles.size()]
			else:
				src = yard_tiles[rng.randi() % yard_tiles.size()]
			_blit(img, src, tx, ty)

	# A real terminal is zoned before it is populated. The subtle amber/teal
	# washes make import and export blocks readable even when a row is empty,
	# instead of leaving one undifferentiated rectangle of asphalt.
	_paint_sector_washes(img)

	# --- kerb + gutter along the grass/yard seam, with grass creeping over ---
	var curb := _img("gr_curb")
	for ty in range(paved_top - TILE, world_h, TILE):
		_blend(img, curb, verge - 2, ty)

	# --- ragged grass/pavement seam at the top and bottom of the paved area ---
	var tufts := _img("gr_seam_tufts")
	for tx in range(verge, int(PortLayout.QUAY_X1), 10):
		var v := rng.randi() % 4
		_blend_region(img, tufts, Rect2i(v * 10, 0, 10, 8), tx, paved_top - 5)
		_blend_region(img, tufts, Rect2i(((v + 2) % 4) * 10, 0, 10, 8),
			tx, paved_bottom - 3)

	# --- container bay markings under every block, colour-coded by sector ---
	# The yard is split into import and export areas, and until now nothing on
	# the ground said which was which — the player had to infer it from where
	# boxes happened to land. Amber heads an import bay, teal an export one.
	var bay := _img("gr_bay_marks")
	for i in PortLayout.block_count():
		var origin := PortLayout.block_origin(i)
		_blend(img, bay, int(origin.x) - 1, int(origin.y) - 1)
		var export_bay := posmod(i, PortLayout.BLOCK_COLUMNS) \
			== PortLayout.BLOCK_COLUMNS - 1
		var head := Color8(104, 194, 176) if export_bay else Color8(232, 176, 78)
		var head_y := int(origin.y) - 4
		for bx in range(int(origin.x), int(origin.x + PortLayout.BLOCK_W)):
			# dashed, so it reads as paint rather than as a solid barrier
			@warning_ignore("integer_division")
			var dash_cell: int = bx / 3
			if dash_cell % 2 == 0:
				_pixel(img, bx, head_y, head)
				_pixel(img, bx, head_y + 1, head.darkened(0.35))

	# --- lane paint between block rows ---
	var dash := _img("gr_lane_dash")
	for lane_y in PortLayout.lane_ys():
		for tx in range(int(PortLayout.YARD_X0), int(PortLayout.QUAY_X0), TILE):
			_blend(img, dash, tx, int(lane_y) - 2)

	var solid := _rot90(_img("gr_lane_solid"))

	# --- the road to the city ---
	# Asphalt, not more apron: the carriageway is darker than the concrete it
	# runs through, kerbed on both sides and centre-lined down the middle, and
	# it starts above the fence so it visibly comes in from off the map rather
	# than beginning at the gate.
	var road := _img("gr_yard_b")
	var road_x0 := int(PortLayout.ROAD_X0)
	var road_x1 := int(PortLayout.ROAD_X1)
	# It runs the length of the terminal and stops where the pavement does,
	# rather than petering out somewhere in the middle of the yard: the sheds
	# in the service band need to be reachable too.
	_fill_tiled(img, road, Rect2i(road_x0, 0, road_x1 - road_x0, paved_bottom),
		0.80)
	for ty in range(0, paved_bottom):
		_pixel(img, road_x0, ty, Color8(196, 190, 178))
		_pixel(img, road_x1 - 1, ty, Color8(196, 190, 178))
	var dash_v := _rot90(dash)
	for ty in range(0, paved_bottom, TILE):
		_blend(img, dash_v, int(PortLayout.GATE_ROAD_X) - 2, ty)
	_paint_road_signage(img, paved_bottom)

	# --- gate apron: the one-way loop the trucks run, and the bays ---
	# Both apron lanes are painted, because a bay you cannot see the way into
	# is just a rectangle. The approach runs east under the bays, the exit runs
	# west over them, and the marked bays sit between the two.
	var apron_end := int(PortLayout.GATE_BAY_X + PortLayout.GATE_BAY_COUNT
		* (PortLayout.GATE_BAY_W + PortLayout.GATE_BAY_GAP))
	for lane_y in [PortLayout.GATE_EXIT_Y, PortLayout.GATE_QUEUE_Y]:
		for tx in range(road_x1, apron_end, TILE):
			_blend(img, dash, tx, int(lane_y) - 2)
	for apron_bay in PortLayout.GATE_BAY_COUNT:
		var origin := PortLayout.gate_bay_position(apron_bay)
		var bx := int(origin.x)
		var by := int(origin.y)
		var bw := int(PortLayout.GATE_BAY_W)
		var bh := int(PortLayout.GATE_BAY_H)
		# Open at both ends: a truck drives in at the bottom and out at the top,
		# and the paint says so.
		for edge in range(bh):
			_pixel(img, bx, by + edge, Color8(226, 182, 78))
			_pixel(img, bx + bw, by + edge, Color8(226, 182, 78))
	_paint_gate_details(img, apron_end)

	# --- RTG runway paint down each gap between block columns ---
	for runway_x in PortLayout.runway_xs():
		for ty in range(int(PortLayout.YARD_Y0) - 8, int(PortLayout.yard_bottom()), TILE):
			_blend(img, solid, int(runway_x) - 3, ty)
			_blend(img, solid, int(runway_x), ty)
	_paint_yard_details(img)

	# --- maintenance/service pads below the stacks ---
	_paint_service_band(img)

	# --- crane rails on the quay ---
	for ty in range(paved_top, world_h, TILE):
		_blend(img, solid, int(PortLayout.QUAY_X0) + 4, ty)
		_blend(img, solid, int(PortLayout.QUAY_X1) - 7, ty)
	_paint_quay_safety(img, world_h)

	# --- intermodal rail corridor ---
	# The train actor has always crossed this coordinate. Giving it ballast,
	# sleepers and two steel rails makes it a real transport connection rather
	# than a locomotive sliding over an empty dirt strip.
	_paint_rail_corridor(img)

	# --- quay coping where the concrete meets the water ---
	var edge := _img("gr_quay_edge")
	for ty in range(0, world_h, TILE):
		_blend(img, edge, int(PortLayout.WATER_X0) - 10, ty)

	return ImageTexture.create_from_image(img)


static func _paint_sector_washes(img: Image) -> void:
	## Which yard each block is, and — the part that was missing — **which way
	## its cargo leaves**.
	##
	## The wash and the stencil already said import or export. What nobody could
	## see was that those two words are directions: landward stacks empty through
	## the gate, seaward stacks empty onto a hull. So every block now carries a
	## chevron pointing the way its boxes go, painted at the head of the block
	## where a driver would read it. `PortLayout.role_heads_seaward` decides both
	## the arrow and the routing, so the paint cannot lie about the traffic.
	for block_index in PortLayout.block_count():
		var origin := PortLayout.block_origin(block_index)
		var role := PortLayout.block_role(block_index)
		var seaward := PortLayout.role_heads_seaward(role)
		var tint := ROLE_TINTS.get(role, Color8(211, 151, 56)) as Color
		var x0 := int(origin.x)
		var y0 := int(origin.y)
		for y in range(y0, int(origin.y + PortLayout.BLOCK_H)):
			for x in range(x0, int(origin.x + PortLayout.BLOCK_W)):
				if (x + y) % 3 == 0:
					_mix_pixel(img, x, y, tint, 0.14)
		@warning_ignore("integer_division")
		var row: int = block_index / PortLayout.BLOCK_COLUMNS
		var label := ROLE_LABELS.get(role, "I") as String
		_draw_stencil(img, label + str(row + 1), x0 + 3, y0 - 10,
			tint.lightened(0.28))
		# The buffer takes either, so it gets no arrow: an arrow that means "one
		# of two ways" is worse than none.
		if role == PortLayout.ROLE_BUFFER:
			continue
		# Beside the label rather than under it. The first attempt put the arrows
		# on the driving lane, where they landed on the dashed centre line and
		# were unreadable — a direction marking has to be on the block it is
		# describing, next to the word it qualifies.
		# `_draw_horizontal_chevron` puts its apex at `cx` and opens *away* from
		# it, so the flag it takes is which way the chevron opens, not which way
		# it points. An arrow has to point where the traffic goes.
		var arrow := tint.lightened(0.4)
		for step in 2:
			_draw_horizontal_chevron(img, x0 + 17 + step * 4, y0 - 7,
				not seaward, arrow)


## What each yard is called on the ground, and the tint its bays are washed in.
const ROLE_LABELS := {
	&"import": "I", &"export": "E", &"buffer": "B",
}
const ROLE_TINTS := {
	&"import": Color8(211, 151, 56),
	&"export": Color8(52, 144, 134),
	&"buffer": Color8(150, 142, 156),
}


static func _paint_road_signage(img: Image, paved_bottom: int) -> void:
	var white := Color8(224, 220, 204)
	# Crosswalk immediately inside the perimeter gate.
	for x in range(int(PortLayout.ROAD_X0) + 3, int(PortLayout.ROAD_X1) - 2, 5):
		for yy in range(int(PortLayout.FENCE_Y) + 3, int(PortLayout.FENCE_Y) + 9):
			for xx in range(x, mini(x + 3, int(PortLayout.ROAD_X1) - 2)):
				_pixel(img, xx, yy, white.darkened(0.08))
	# Direction arrows repeat down both one-way lanes, so traffic flow reads
	# without the player having to watch a whole truck cycle.
	var y := 142
	while y < paved_bottom - 26:
		_draw_vertical_arrow(img, int(PortLayout.ROAD_IN_X), y, false, white)
		_draw_vertical_arrow(img, int(PortLayout.ROAD_OUT_X), y + 34, true, white)
		y += 116
	# Drain covers along the gutter, positioned outside the driven tyre paths.
	for drain_y in range(72, paved_bottom - 12, 92):
		_draw_drain(img, int(PortLayout.ROAD_X1) - 3, drain_y)


static func _paint_gate_details(img: Image, apron_end: int) -> void:
	var amber := Color8(232, 176, 78)
	var white := Color8(224, 220, 204)
	# Chevron arrows carry the one-way loop east on approach and west on exit.
	for x in range(int(PortLayout.ROAD_X1) + 12, apron_end - 3, 22):
		_draw_horizontal_chevron(img, x, int(PortLayout.GATE_QUEUE_Y), true, white)
		_draw_horizontal_chevron(img, x, int(PortLayout.GATE_EXIT_Y), false, white)
	for bay in PortLayout.GATE_BAY_COUNT:
		var pos := PortLayout.gate_bay_position(bay)
		_draw_stencil(img, "G" + str(bay + 1), int(pos.x) + 5,
			int(pos.y) + 3, amber.lightened(0.18))
		# Stop line across each loading bay.
		for x in range(int(pos.x) + 2, int(pos.x + PortLayout.GATE_BAY_W) - 1):
			if x % 2 == 0:
				_pixel(img, x, int(pos.y) + 24, amber)


static func _paint_yard_details(img: Image) -> void:
	var pale := Color8(192, 190, 178)
	# Storm drains at the low side of each cross-lane and small numbered
	# intersection boxes give the apron believable civil infrastructure.
	var lanes := PortLayout.lane_ys()
	for row in lanes.size():
		var lane_y := int(lanes[row])
		_draw_drain(img, int(PortLayout.QUAY_X0) - 5, lane_y - 2)
		_draw_stencil(img, str(row + 1), int(PortLayout.BLOCK_X0) - 9,
			lane_y - 3, pale.darkened(0.06))
	# A broken safety line separates container traffic from the quay crane lane.
	for y in range(int(PortLayout.YARD_Y0), int(PortLayout.yard_bottom()), 9):
		for yy in range(y, mini(y + 5, int(PortLayout.yard_bottom()))):
			_pixel(img, int(PortLayout.QUAY_X0) - 2, yy, Color8(222, 169, 68))


static func _paint_service_band(img: Image) -> void:
	var line := Color8(184, 180, 166)
	for slot in PortLayout.slot_count():
		var pos := PortLayout.slot_position(slot)
		var x0 := int(pos.x) - 3
		var y0 := int(pos.y) - 4
		var x1 := x0 + int(PortLayout.SLOT_W) - 4
		var y1 := y0 + int(PortLayout.SLOT_H) + 6
		for x in range(x0, x1):
			if (x - x0) % 7 < 4:
				_pixel(img, x, y0, line)
				_pixel(img, x, y1, line.darkened(0.20))
		for y in range(y0, y1):
			if (y - y0) % 7 < 4:
				_pixel(img, x0, y, line)
				_pixel(img, x1, y, line.darkened(0.20))
		_draw_stencil(img, "M" + str(slot + 1), x0 + 4, y0 + 4,
			Color8(214, 205, 178))
	# Painted pedestrian spine between the workshops and the quay.
	var spine_x := int(PortLayout.QUAY_X0) - 9
	for y in range(int(PortLayout.service_y()), int(PortLayout.world_bottom()
			- PortLayout.SOUTH_MARGIN), 8):
		for yy in range(y, y + 4):
			_pixel(img, spine_x, yy, Color8(84, 166, 151))


static func _paint_quay_safety(img: Image, world_h: int) -> void:
	var edge_x := int(PortLayout.WATER_X0) - 7
	# Alternating black/yellow edge cells are a universal real-world warning
	# and give the long berth a stronger visual rhythm.
	for y in range(int(PortLayout.TOP_MARGIN), world_h):
		var stripe := posmod(y, 16) < 8
		var color := Color8(232, 176, 62) if stripe else Color8(72, 67, 62)
		_pixel(img, edge_x, y, color)
		_pixel(img, edge_x + 1, y, color.darkened(0.18))
	# Quay station labels align with the bollard rhythm.
	var station := 1
	for y in range(int(PortLayout.TOP_MARGIN) + 18, world_h - 16, 92):
		_draw_stencil(img, "Q" + str(station), int(PortLayout.QUAY_X0) + 12,
			y, Color8(180, 174, 162))
		station += 1


static func _paint_rail_corridor(img: Image) -> void:
	## Two roads, not one: the running line the trains stand on, and the
	## run-around loop the locomotive uses to get to the other end of its train.
	##
	## The loop is the reason a stub-ended siding works at all, and painting it is
	## not decoration — `RailRake` drives the shunt over these exact coordinates,
	## so if the turnouts were not here the loco would be crossing bare ballast.
	var rail_y := int(PortLayout.rail_y())
	var loop_y := int(PortLayout.rail_loop_y())
	var x1 := int(PortLayout.WATER_X0) - 11
	var west := int(PortLayout.rail_west_turnout_x())
	var east := int(PortLayout.rail_east_turnout_x())
	# Ballast bed with a rough, non-repeating shoulder, wide enough for both.
	for y in range(loop_y - 9, rail_y + 12):
		for x in range(0, x1):
			var edge_distance := mini(absi(y - rail_y), absi(y - loop_y))
			if edge_distance <= 8 or (x * 7 + y * 3) % 5 < 3:
				var ballast := Color8(112, 105, 96) if (x + y) % 4 \
					else Color8(143, 132, 116)
				_pixel(img, x, y, ballast)
	_paint_track(img, rail_y, 0, x1)
	# The loop runs only as far as it has to: past each turnout by a locomotive's
	# length, and no further. A second track the full width of the map would read
	# as a main line the terminal does not have.
	_paint_track(img, loop_y, west - 12, east + 14)
	_paint_turnout(img, west, rail_y, loop_y)
	_paint_turnout(img, east, rail_y, loop_y)
	# Buffer stop. The corridor is a stub, not a through line, and without
	# something at the end of it the rails simply stop in the middle of the yard
	# and a rake reads as driving into the quay.
	var stop_x := x1 - 4
	for y in range(rail_y - 7, rail_y + 8):
		_pixel(img, stop_x, y, Color8(58, 52, 48))
		_pixel(img, stop_x + 1, y, Color8(96, 88, 78))
	for y in range(rail_y - 7, rail_y + 8, 3):
		_pixel(img, stop_x + 2, y, Color8(232, 176, 62))
	for ry in [rail_y - 5, rail_y + 5]:
		_pixel(img, stop_x - 1, ry - 2, Color8(190, 188, 178))
		_pixel(img, stop_x - 2, ry - 1, Color8(190, 188, 178))
	# Road crossing panels keep the public-road connection plausible.
	for x in range(int(PortLayout.ROAD_X0), int(PortLayout.ROAD_X1)):
		for y in range(loop_y - 8, rail_y + 9):
			_mix_pixel(img, x, y, Color8(74, 74, 74), 0.62)
	for x in range(int(PortLayout.ROAD_X0) + 2, int(PortLayout.ROAD_X1) - 2, 5):
		_pixel(img, x, loop_y - 10, Color8(232, 176, 62))
		_pixel(img, x, rail_y + 10, Color8(232, 176, 62))


static func _paint_track(img: Image, centre_y: int, x0: int, x1: int) -> void:
	## Timber sleepers first, steel rails over them — the order they are laid.
	for x in range(maxi(0, x0) + (2 if x0 <= 0 else 0), x1, 8):
		for y in range(centre_y - 8, centre_y + 9):
			_pixel(img, x, y, Color8(92, 68, 52))
			_pixel(img, x + 1, y, Color8(126, 91, 62))
	for ry in [centre_y - 5, centre_y + 5]:
		for x in range(maxi(0, x0), x1):
			_pixel(img, x, ry, Color8(64, 64, 68))
			_pixel(img, x, ry - 1, Color8(190, 188, 178))


static func _paint_turnout(img: Image, x: int, rail_y: int, loop_y: int) -> void:
	## The crossover between the two roads, drawn as the pair of curved rails a
	## turnout actually is: they leave the running line, close the gap over ten
	## pixels or so, and join the loop.
	var span := rail_y - loop_y
	var run := 12
	for step in range(run + 1):
		var t := float(step) / float(run)
		var y := rail_y - int(round(span * t))
		for offset in [-5, 5]:
			_pixel(img, x + step - run / 2, y + offset, Color8(64, 64, 68))
			_pixel(img, x + step - run / 2, y + offset - 1, Color8(190, 188, 178))
	# Point blades and the little yellow lever stand that works them.
	_pixel(img, x - run / 2 - 1, rail_y - 5, Color8(216, 208, 196))
	_pixel(img, x - run / 2 - 1, rail_y + 5, Color8(216, 208, 196))
	for y in range(rail_y + 7, rail_y + 10):
		_pixel(img, x - run / 2, y, Color8(232, 176, 62))


static func _draw_vertical_arrow(img: Image, cx: int, cy: int,
		up: bool, color: Color) -> void:
	var direction := -1 if up else 1
	for step in 5:
		_pixel(img, cx, cy - direction * step, color)
		_pixel(img, cx + 1, cy - direction * step, color)
	for wing in 4:
		_pixel(img, cx - wing, cy + direction * wing, color)
		_pixel(img, cx + 1 + wing, cy + direction * wing, color)


static func _draw_horizontal_chevron(img: Image, cx: int, cy: int,
		right: bool, color: Color) -> void:
	var direction := 1 if right else -1
	for step in 4:
		_pixel(img, cx + direction * step, cy - step, color)
		_pixel(img, cx + direction * step, cy + step, color)


static func _draw_drain(img: Image, cx: int, cy: int) -> void:
	for y in range(cy, cy + 5):
		for x in range(cx - 2, cx + 3):
			_pixel(img, x, y, Color8(58, 62, 64))
	for x in range(cx - 1, cx + 2, 2):
		for y in range(cy + 1, cy + 4):
			_pixel(img, x, y, Color8(130, 134, 130))


static func _draw_stencil(img: Image, text: String, x0: int, y0: int,
		color: Color) -> void:
	var cursor := x0
	for character in text:
		var rows := _glyph_rows(character)
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if row[x] == "1":
					_pixel(img, cursor + x, y0 + y, color)
		cursor += 4


static func _glyph_rows(character: String) -> Array[String]:
	match character:
		"I":
			return ["111", "010", "010", "010", "111"]
		"E":
			return ["111", "100", "110", "100", "111"]
		"G":
			return ["111", "100", "101", "101", "111"]
		"M":
			return ["101", "111", "111", "101", "101"]
		"Q":
			return ["111", "101", "101", "111", "001"]
		"1":
			return ["010", "110", "010", "010", "111"]
		"2":
			return ["110", "001", "010", "100", "111"]
		"3":
			return ["110", "001", "010", "001", "110"]
		"4":
			return ["101", "101", "111", "001", "001"]
		"5":
			return ["111", "100", "110", "001", "110"]
		"6":
			return ["011", "100", "111", "101", "111"]
		"7":
			return ["111", "001", "010", "010", "010"]
		"8":
			return ["111", "101", "111", "101", "111"]
		"9":
			return ["111", "101", "111", "001", "110"]
		_:
			return ["000", "000", "000", "000", "000"]


static func _mix_pixel(dst: Image, x: int, y: int, color: Color,
		weight: float) -> void:
	if x < 0 or y < 0 or x >= dst.get_width() or y >= dst.get_height():
		return
	dst.set_pixel(x, y, dst.get_pixel(x, y).lerp(color, weight))


static func _pixel(dst: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= dst.get_width() or y >= dst.get_height():
		return
	dst.set_pixel(x, y, color)


static func _fill_tiled(dst: Image, src: Image, rect: Rect2i,
		shade: float = 1.0) -> void:
	## Tiles `src` over an arbitrary rect rather than a tile-aligned one, so a
	## road can be any width and start anywhere. `shade` multiplies the result,
	## which is how the carriageway ends up darker than the apron it crosses.
	var sw := src.get_width()
	var sh := src.get_height()
	for y in range(maxi(0, rect.position.y), mini(dst.get_height(), rect.end.y)):
		for x in range(maxi(0, rect.position.x), mini(dst.get_width(), rect.end.x)):
			var texel := src.get_pixel(posmod(x, sw), posmod(y, sh))
			dst.set_pixel(x, y, Color(texel.r * shade, texel.g * shade,
				texel.b * shade, 1.0))


static func _blit(dst: Image, src: Image, x: int, y: int) -> void:
	if x >= dst.get_width() or y >= dst.get_height():
		return
	dst.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(x, y))


static func _blend(dst: Image, src: Image, x: int, y: int) -> void:
	if x >= dst.get_width() or y >= dst.get_height():
		return
	dst.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(x, y))


static func _blend_region(dst: Image, src: Image, region: Rect2i,
		x: int, y: int) -> void:
	if x >= dst.get_width() or y >= dst.get_height():
		return
	dst.blend_rect(src, region, Vector2i(x, y))


static func _rot90(src: Image) -> Image:
	var out := Image.create(src.get_height(), src.get_width(), false,
		Image.FORMAT_RGBA8)
	for sy in src.get_height():
		for sx in src.get_width():
			out.set_pixel(sy, sx, src.get_pixel(sx, sy))
	return out
