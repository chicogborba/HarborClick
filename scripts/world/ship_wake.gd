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
##   * the two arms of the V it sheds, running aft and outward;
##   * the collar dragged along the plating;
##   * the propeller wash boiling astern and thinning out behind.
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
const HAZE := Color8(132, 200, 214)
## Rows of bow the shoulders' foam runs down, in hull pixels.
const BOW_ROWS := 54
const ARM_SLOPE := 0.44
const INNER_SLOPE := 0.24

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

	# --- the propeller wash, first, so everything else sits on it ---
	var trail := int(60.0 + 130.0 * s)
	var stern_half := float(_right[_height - 3] - _left[_height - 3]) * 0.5
	for i in range(-6, trail, 2):
		var y := _height + i
		var far := clampf(float(i) / float(trail), 0.0, 1.0)
		var half := stern_half * 0.62 + maxf(0.0, float(i)) * 0.11
		var gy := (world_y + y) >> 1
		var cells := int(half / 2.0)
		for c in range(-cells, cells + 1):
			# Hashed on a row twice as tall as it is drawn, so foam comes in
			# short streaks along the track instead of single-pixel static.
			var n := _hash(c, (gy >> 1) + (beat if absi(c) < 2 else 0))
			# The boil is dense at the screws and thins toward the edges and aft.
			var edge := absf(float(c)) / maxf(1.0, float(cells))
			var need := 0.40 + far * 0.50 + edge * edge * 0.24
			if n > need + 0.26:
				_dot(centre + c * 2.0, y, 2, 2, FOAM, s * (1.0 - far * 0.75))
			elif n > need:
				_dot(centre + c * 2.0, y, 2, 2, SPRAY, s * (0.80 - far * 0.55))
			elif far < 0.55 and n > need - 0.30:
				# Aerated water under the foam: the pale bed the wash lies on.
				_dot(centre + c * 2.0, y, 2, 2, HAZE, s * (0.55 - far * 0.9))
		# The two bright seams the wash leaves at its edges.
		if _hash(7, gy) > 0.30 + far * 0.5:
			_dot(centre - half - 2.0, y, 2, 2, FOAM, s * (0.9 - far * 0.8))
		if _hash(11, gy) > 0.30 + far * 0.5:
			_dot(centre + half, y, 2, 2, FOAM, s * (0.9 - far * 0.8))

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

	# --- the V: two arms shed from the shoulders, a fainter pair inside ---
	var arm := int(80.0 + 150.0 * s)
	var root := 10
	var root_half := float(_right[mini(root, _height - 1)]
		- _left[mini(root, _height - 1)]) * 0.5 + 3.0
	for i in range(0, arm, 1):
		var y := root + i
		var far := float(i) / float(arm)
		var gy := world_y + y
		var a := s * (1.0 - far) * (1.0 - far * 0.3)
		var reach := root_half + float(i) * ARM_SLOPE
		# Dashes three world rows long, so the arm is broken water, not a line.
		var dash := _hash(19, gy / 3)
		if dash > 0.22 + far * 0.35:
			var w := 2.0 if far < 0.5 else 1.0
			var color := FOAM if far < 0.45 and dash > 0.5 else SPRAY
			_dot(stem - reach - w, y, w, 1, color, a)
			_dot(stem + reach, y, w, 1, color, a)
		if i > 14 and _hash(23, gy / 4) > 0.5 + far * 0.3:
			var inner := root_half + float(i) * INNER_SLOPE
			# Only where it has cleared the hull's own side.
			var row := mini(y, _height - 1)
			if y >= _height or stem - inner < _left[row] - 4:
				_dot(stem - inner - 1.0, y, 1, 1, HAZE, a * 0.9)
				_dot(stem + inner, y, 1, 1, HAZE, a * 0.9)
