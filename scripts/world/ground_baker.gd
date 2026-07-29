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
	img.fill(Color8(62, 126, 158))          # sea, under everything

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

	# --- container bay markings under every block ---
	var bay := _img("gr_bay_marks")
	for i in PortLayout.block_count():
		var origin := PortLayout.block_origin(i)
		_blend(img, bay, int(origin.x) - 1, int(origin.y) - 1)

	# --- lane paint between block rows ---
	var dash := _img("gr_lane_dash")
	for lane_y in PortLayout.lane_ys():
		for tx in range(int(PortLayout.YARD_X0), int(PortLayout.QUAY_X0), TILE):
			_blend(img, dash, tx, int(lane_y) - 2)

	# --- RTG runway paint down each gap between block columns ---
	var solid := _rot90(_img("gr_lane_solid"))
	for runway_x in PortLayout.runway_xs():
		for ty in range(int(PortLayout.YARD_Y0) - 8, int(PortLayout.yard_bottom()), TILE):
			_blend(img, solid, int(runway_x) - 5, ty)
			_blend(img, solid, int(runway_x) + 3, ty)

	# --- crane rails on the quay ---
	for ty in range(paved_top, world_h, TILE):
		_blend(img, solid, int(PortLayout.QUAY_X0) + 4, ty)
		_blend(img, solid, int(PortLayout.QUAY_X1) - 7, ty)

	# --- quay coping where the concrete meets the water ---
	var edge := _img("gr_quay_edge")
	for ty in range(0, world_h, TILE):
		_blend(img, edge, int(PortLayout.WATER_X0) - 10, ty)

	return ImageTexture.create_from_image(img)


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
