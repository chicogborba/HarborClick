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
	var paved_bottom := int(PortLayout.world_bottom() - PortLayout.RAIL_MARGIN)
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

	# --- RTG runway paint down each gap between block columns ---
	for runway_x in PortLayout.runway_xs():
		for ty in range(int(PortLayout.YARD_Y0) - 8, int(PortLayout.yard_bottom()), TILE):
			_blend(img, solid, int(runway_x) - 3, ty)
			_blend(img, solid, int(runway_x), ty)

	# --- crane rails on the quay ---
	for ty in range(paved_top, world_h, TILE):
		_blend(img, solid, int(PortLayout.QUAY_X0) + 4, ty)
		_blend(img, solid, int(PortLayout.QUAY_X1) - 7, ty)

	# --- quay coping where the concrete meets the water ---
	var edge := _img("gr_quay_edge")
	for ty in range(0, world_h, TILE):
		_blend(img, edge, int(PortLayout.WATER_X0) - 10, ty)

	return ImageTexture.create_from_image(img)


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
