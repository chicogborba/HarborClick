class_name ShipWake
extends Node2D
## The sea being cut by a hull under way, in the game's own pixels.
##
## The water shader already swells and shades around a moving ship
## (`water_top.gdshader`), but everything a shader mixes is soft, and a wake
## is the one thing on the water that is *hard*: white foam with an edge. So
## this layer draws the foam, as whole pixels, on top of the shader's swell:
##
##   * the bow wave — water piled on the stem and peeled down both shoulders;
##   * the collar dragged along the plating;
##   * the boil right at the screws.
##
## The V and the long track astern are the water's, not this layer's: they are
## laid on the sea by WaterWakes so they stay where the hull made them.
##
## Two rules make it read as water rather than as a sticker towed by the ship.
## Every pattern is hashed on *world* rows, so foam stays where it was made
## while the hull moves through it. And the hull's real outline is read from
## its sprite (`fit`), so the foam hugs whatever class of ship this is.
##
## It is presentation only. `Ship` drives `visible`, `speed_scale` and
## `strength`; nothing reads anything back.

const FOAM := Color8(246, 252, 252)
const SPRAY := Color8(190, 232, 236)
## Rows of bow the shoulders' foam runs down, in hull pixels.
const BOW_ROWS := 54
## Rows of fine boil drawn astern before the water's own track takes over.
const BOIL_ROWS := 22

## 0 moored .. 1 full ahead; eased by the ship from its real movement.
var strength := 0.0:
	set(value):
		strength = clampf(value, 0.0, 1.0)
		queue_redraw()
## 1.0 on the faster departure leg, less on an arrival (`Ship` sets it).
var speed_scale := 1.0
var tint := Color.WHITE

var _playing := false
var _left := PackedInt32Array()     # per local row: first opaque hull column
var _right := PackedInt32Array()    # per local row: last opaque hull column
var _height := 0
var _t := 0.0
## The quay wall in local x, refreshed each draw.
var _shore := -1.0e9


func fit(texture: Texture2D, hull_scale: Vector2, hull_offset: Vector2) -> void:
	## Reads the hull's silhouette row by row. Called whenever the variant
	## changes; costs one image read, not one per frame.
	_left.clear()
	_right.clear()
	_height = 0
	if texture == null:
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		return
	if image.is_compressed():
		image.decompress()
	var width := image.get_width()
	_height = int(round(image.get_height() * hull_scale.y))
	_left.resize(_height)
	_right.resize(_height)
	for row in _height:
		var src_y := clampi(int(row / maxf(hull_scale.y, 0.01)), 0,
			image.get_height() - 1)
		var first := -1
		var last := -1
		for x in width:
			if image.get_pixel(x, src_y).a > 0.5:
				if first < 0:
					first = x
				last = x
		if first < 0:
			# An empty row (padding): carry the neighbour so nothing spikes.
			first = _left[row - 1] if row > 0 else width / 2
			last = _right[row - 1] if row > 0 else width / 2
			_left[row] = first
			_right[row] = last
			continue
		_left[row] = int(round(hull_offset.x + first * hull_scale.x))
		_right[row] = int(round(hull_offset.x + (last + 1) * hull_scale.x))
	position = Vector2(0.0, roundf(hull_offset.y))
	queue_redraw()


func play() -> void:
	_playing = true
	set_process(true)


func stop() -> void:
	_playing = false
	set_process(false)


func is_playing() -> bool:
	return _playing


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(_playing)


func _process(delta: float) -> void:
	_t += delta * speed_scale
	if visible and strength > 0.01:
		queue_redraw()


static func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65535.0


func _dot(x: float, y: float, w: float, h: float, color: Color,
		alpha: float) -> void:
	if alpha <= 0.02:
		return
	# Foam belongs to the water. The V is wider than the channel, and without
	# this its landward arm was drawn straight across the quay.
	if x < _shore:
		w -= _shore - x
		x = _shore
		if w <= 0.0:
			return
	var c := color * tint
	c.a = clampf(alpha, 0.0, 1.0)
	draw_rect(Rect2(roundf(x), roundf(y), w, h), c)


func _draw() -> void:
	if _height <= 0 or strength <= 0.01:
		return
	var s := strength
	_shore = PortLayout.WATER_X0 + 2.0 - global_position.x
	# World rows: what makes foam stay put while the hull slides through it.
	var world_y := int(roundf(global_position.y))
	var beat := int(_t * 9.0)
	var centre := float(_left[mini(BOW_ROWS, _height - 1)]
		+ _right[mini(BOW_ROWS, _height - 1)]) * 0.5
	var bow := mini(BOW_ROWS, _height - 1)

	# --- the boil at the screws ---
	# Only the first few rows astern, in single pixels. The track behind it is
	# the water's (WaterWakes → water_top.gdshader), where it stays on the sea as
	# the hull moves on. This used to run two hundred rows of 2x2 cells, which
	# read as a mosaic pasted over the tugs riding in it.
	var stern_half := float(_right[_height - 3] - _left[_height - 3]) * 0.5
	for i in range(-4, BOIL_ROWS):
		var y := _height + i
		var far := clampf(float(i) / float(BOIL_ROWS), 0.0, 1.0)
		var half := stern_half * 0.55 + maxf(0.0, float(i)) * 0.12
		var gy := world_y + y
		var cells := int(half)
		for c in range(-cells, cells + 1):
			var n := _hash(c, (gy >> 1) + (beat if absi(c) < 3 else 0))
			var edge := absf(float(c)) / maxf(1.0, float(cells))
			var need := 0.46 + far * 0.42 + edge * edge * 0.25
			if n > need + 0.24:
				_dot(centre + c, y, 1, 1, FOAM, s * (1.0 - far * 0.7))
			elif n > need:
				_dot(centre + c, y, 1, 1, SPRAY, s * (0.75 - far * 0.5))

	# --- the collar along the plating ---
	for y in range(bow, _height - 2):
		var gy := world_y + y
		var n := _hash(3, gy >> 1)
		var m := _hash(5, gy >> 1)
		_dot(_left[y] - 1, y, 1, 1, FOAM if n > 0.42 else SPRAY, s * 0.95)
		_dot(_right[y], y, 1, 1, FOAM if m > 0.42 else SPRAY, s * 0.95)
		if n > 0.74:
			_dot(_left[y] - 3, y, 2, 1, SPRAY, s * 0.8)
		if m > 0.74:
			_dot(_right[y] + 1, y, 2, 1, SPRAY, s * 0.8)

	# --- the bow wave: piled on the stem, peeled down the shoulders ---
	var stem := float(_left[0] + _right[0]) * 0.5
	for i in 4:
		# Water heaped ahead of the stem, widening as it falls back.
		var w := 2.0 + i * 2.0
		_dot(stem - w * 0.5, -4.0 + i, w, 1, FOAM, s * (0.55 + i * 0.15))
	for y in bow:
		var run := float(y) / float(bow)
		# Thick at the stem, thinning aft; it stands off the plating a little
		# more with every row, which is the wave curling away from the hull.
		var thick := 3.0 - floorf(run * 2.2)
		var off := floorf(run * run * 3.0)
		var gy := world_y + y
		var a := s * (1.0 - run * 0.35)
		_dot(_left[y] - thick - off, y, thick, 1, FOAM, a)
		_dot(_right[y] + off, y, thick, 1, FOAM, a)
		_dot(_left[y] - thick - off - 1.0, y, 1, 1, SPRAY, a * 0.9)
		_dot(_right[y] + off + thick, y, 1, 1, SPRAY, a * 0.9)
		# Spray thrown clear of the crest.
		if _hash(13, (gy >> 1) + beat) > 0.80 - s * 0.2:
			_dot(_left[y] - thick - off - 3.0 - (gy & 1), y, 1, 1, FOAM, a)
		if _hash(17, (gy >> 1) + beat) > 0.80 - s * 0.2:
			_dot(_right[y] + off + thick + 2.0 + (gy & 1), y, 1, 1, FOAM, a)
