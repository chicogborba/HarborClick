class_name SupplyDrop
extends Node2D
## A purchase, arriving: a container under a parachute, down out of the sky
## onto the spot where the thing it holds is going to stand.
##
## Whatever was bought — a docker, a reach stacker, a whole gantry — used to
## fade into existence where it belonged. Now it is *delivered*: the box comes
## down swinging, lands with a thump and a puff, the canopy folds, the doors
## go, and what was inside is standing there. `opened` fires at that moment and
## `StructureLayer` is what makes the machine appear (or, past the visible cap,
## makes an existing one take the weight).
##
## One box can carry many: buying ten at once is one container with "x10"
## stencilled on it, not ten parachutes. See `StructureLayer._deliver`.
##
## Presentation only, drawn in whole pixels. With motion off it opens at once.

signal opened

const FALL_TIME := 1.25
const SETTLE_TIME := 0.32
const OPEN_TIME := 0.45
const DROP_HEIGHT := 230.0
const BOX := Vector2(24, 13)
const INK := Color8(24, 20, 30)
const PAINTS := [Color8(196, 84, 40), Color8(44, 116, 142), Color8(54, 130, 78),
	Color8(196, 150, 40), Color8(150, 60, 110), Color8(70, 92, 160)]

var quantity := 1
var delay := 0.0
var on_water := false
var _world: Node
var _paint := PAINTS[0]
var _t := 0.0
var _sway := 0.0
var _label: Label
var _landed := false
var _opened := false


func setup(world: Node, at: Vector2, id: String, count: int, wait: float) -> void:
	_world = world
	position = at.round()
	quantity = maxi(1, count)
	delay = wait
	_paint = PAINTS[absi(hash(id)) % PAINTS.size()]
	_sway = float(absi(hash(id + str(count))) % 100) / 100.0 * TAU
	on_water = at.x >= PortLayout.WATER_X0
	z_index = 60
	z_as_relative = false
	_label = Label.new()
	_label.label_settings = UiTheme.settings(UiTheme.SIZE_SMALL, UiTheme.CREAM, 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_show_quantity()
	if not UserPreferences.can_animate() or DisplayServer.get_name() == "headless":
		_open_now()
		queue_free()


func add(count: int) -> void:
	## More of the same bought while this box is still in the air: it is the
	## same delivery, with a bigger number on the side.
	quantity += maxi(0, count)
	_show_quantity()


func in_flight() -> bool:
	return not _opened


func _show_quantity() -> void:
	if _label == null:
		return
	_label.text = "x%d" % quantity if quantity > 1 else ""
	_label.reset_size()


func _open_now() -> void:
	if _opened:
		return
	_opened = true
	opened.emit()


func _height() -> float:
	## How far above its mark the box is. It leaves the top of the fall quickly
	## and the canopy takes the last of it gently.
	var t := clampf((_t - delay) / FALL_TIME, 0.0, 1.0)
	return roundf(DROP_HEIGHT * pow(1.0 - t, 1.7))


func _process(delta: float) -> void:
	_t += delta
	var since := _t - delay
	if since < 0.0:
		return
	if not _landed and since >= FALL_TIME:
		_landed = true
		AudioManager.play_sfx("splash" if on_water else "thunk", 0.08, -3.0)
		if _world != null and _world.has_method("spawn_dust") and not on_water:
			for i in 3:
				_world.spawn_dust(position + Vector2((i - 1) * 9.0, 2.0))
	if not _opened and since >= FALL_TIME + SETTLE_TIME:
		AudioManager.play_sfx("build", 0.06, -5.0)
		_open_now()
	if since >= FALL_TIME + SETTLE_TIME + OPEN_TIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var since := _t - delay
	if since < 0.0:
		return
	var up := _height()
	var falling := since < FALL_TIME
	var swing := roundf(sin(_sway + since * 3.4) * 5.0 * (up / DROP_HEIGHT)) if falling else 0.0
	var box := Vector2(swing - BOX.x * 0.5, -up - BOX.y)
	# The shadow on the ground: small and faint from high up, the box's own
	# size when it arrives.
	var near := 1.0 - up / DROP_HEIGHT
	var shade := roundf(lerpf(8.0, BOX.x, near))
	draw_rect(Rect2(-shade * 0.5, -2.0, shade, 4), Color(0, 0, 0, 0.12 + 0.2 * near))
	var open_t := clampf((since - FALL_TIME - SETTLE_TIME) / OPEN_TIME, 0.0, 1.0)
	var fade := 1.0 - open_t
	# Canopy and lines, folding away once the weight is off them.
	var fold := clampf((since - FALL_TIME) / SETTLE_TIME, 0.0, 1.0) if not falling else 0.0
	if fold < 1.0:
		var top := box.y - 30.0 + roundf(22.0 * fold)
		var half := roundf(lerpf(17.0, 9.0, fold))
		var cx := box.x + BOX.x * 0.5 + roundf(8.0 * fold)
		for line: float in [-1.0, 1.0]:
			_line(Vector2(cx + line * half, top + 9.0),
				Vector2(box.x + BOX.x * 0.5 + line * 9.0, box.y), Color8(230, 224, 208))
		for row in 5:
			var w := roundf(half * [0.45, 0.75, 0.92, 1.0, 1.0][row])
			var y := top + row * 2.0
			draw_rect(Rect2(cx - w - 1.0, y, w * 2.0 + 2.0, 2), INK)
			var stripes := 4
			for s in stripes:
				draw_rect(Rect2(cx - w + s * (w * 2.0 / stripes), y,
					ceilf(w * 2.0 / stripes), 2),
					Color8(226, 70, 56) if s % 2 == 0 else Color8(250, 244, 224))
		draw_rect(Rect2(cx - half - 1.0, top + 10.0, half * 2.0 + 2.0, 1), INK)
	# The box: whole until the doors go, then two halves pulled apart.
	var gap := roundf(10.0 * open_t)
	for side in 2:
		var half_w := BOX.x * 0.5
		var at := box + Vector2(half_w * side + (gap if side == 1 else -gap), 0)
		draw_rect(Rect2(at, Vector2(half_w, BOX.y)), Color(INK, fade))
		draw_rect(Rect2(at + Vector2(1 if side == 0 else 0, 1),
			Vector2(half_w - 1.0, BOX.y - 2.0)), Color(_paint, fade))
		draw_rect(Rect2(at + Vector2(1 if side == 0 else 0, 1), Vector2(half_w - 1.0, 2)),
			Color(_paint.lightened(0.3), fade))
		var rx := at.x + 2.0
		while rx < at.x + half_w - 1.0:
			draw_rect(Rect2(rx, at.y + 4.0, 1, BOX.y - 6.0), Color(_paint.darkened(0.2), fade))
			rx += 3.0
	if open_t > 0.0 and open_t < 0.5:
		# What was inside, for one bright beat.
		draw_rect(Rect2(box - Vector2(2, 3), BOX + Vector2(4, 4)),
			Color(1.0, 0.96, 0.8, 0.8 * (1.0 - open_t * 2.0)))
	if _label != null:
		_label.position = Vector2(box.x + (BOX.x - _label.size.x) * 0.5, box.y - 1.0)
		_label.modulate.a = fade


func _line(from: Vector2, to: Vector2, color: Color) -> void:
	var span := to - from
	var steps := int(maxf(absf(span.x), absf(span.y)))
	for i in steps + 1:
		draw_rect(Rect2((from + span * (float(i) / maxf(1.0, steps))).round(),
			Vector2(1, 1)), color)
