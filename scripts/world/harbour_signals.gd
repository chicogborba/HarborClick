class_name HarbourSignals
extends Node2D
## The instruments a working port wears: windsocks on the quay and pennants over
## the service band.
##
## They exist to make the weather *legible from the world* rather than only from
## the clock in the corner. A sock streaming flat and a pennant snapping tell you
## it is blowing before you look at anything, and on a calm day they hang and the
## terminal reads still. Both are driven by the one `TimeManager.wind` the clock
## reads, so the corner and the quay can never disagree.

const SOCK := preload("res://assets/sprites/prop_windsock.png")
const FLAG := preload("res://assets/sprites/prop_flag.png")
const SOCK_FRAME := Vector2i(20, 14)
const FLAG_FRAME := Vector2i(16, 16)

var world: PortWorld
var _socks: Array[Sprite2D] = []
var _flags: Array[AnimatedSprite2D] = []
var _t := 0.0


func setup(port: PortWorld) -> void:
	world = port
	name = "HarbourSignals"
	world.entities.add_child(self)
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_socks.clear()
	_flags.clear()
	# Socks go where a terminal actually has clear ground for them: beside the
	# gate apron, out on the service band, and at the foot of the quay past the
	# last berth. The working quay itself is crane rail and bollards end to end,
	# and a sock planted in it would be standing in the way.
	for spot in [
			Vector2(PortLayout.GATE_BAY_X + PortLayout.GATE_BAY_COUNT
				* (PortLayout.GATE_BAY_W + PortLayout.GATE_BAY_GAP) - 8.0,
				PortLayout.GATE_APRON_Y + 2.0),
			Vector2(PortLayout.QUAY_X0 - 28.0, PortLayout.service_y() + 4.0),
			Vector2(PortLayout.QUAY_X0 + 4.0, PortLayout.world_bottom() - 44.0)]:
		_add_sock(spot)
	# Pennants down the fence line and over the service band, which is the part
	# of the terminal that otherwise has nothing moving in it.
	_add_flag(Vector2(PortLayout.ROAD_X1 + 34.0, PortLayout.FENCE_Y - 14.0))
	for row in PortLayout.slot_rows():
		_add_flag(Vector2(PortLayout.QUAY_X0 - 16.0,
			PortLayout.service_y() + 10.0 + row * PortLayout.SLOT_ROW_H))


func _add_sock(spot: Vector2) -> void:
	var sock := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = SOCK
	atlas.region = Rect2(0, 0, SOCK_FRAME.x, SOCK_FRAME.y)
	sock.texture = atlas
	sock.centered = false
	sock.position = spot
	add_child(sock)
	_socks.append(sock)


func _add_flag(spot: Vector2) -> void:
	var flag := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 6.0)
	for index in 3:
		var atlas := AtlasTexture.new()
		atlas.atlas = FLAG
		atlas.region = Rect2(index * FLAG_FRAME.x, 0, FLAG_FRAME.x, FLAG_FRAME.y)
		frames.add_frame(&"default", atlas)
	flag.sprite_frames = frames
	flag.centered = false
	flag.frame = randi() % 3
	flag.position = spot
	flag.play()
	add_child(flag)
	_flags.append(flag)


func _process(delta: float) -> void:
	_t += delta
	var wind := clampf(TimeManager.wind, 0.0, 1.0)
	# The sock's fill is the wind itself: three states, picked rather than
	# animated, because a sock does not flap — it fills.
	var fill := 0
	if wind > 0.62:
		fill = 2
	elif wind > 0.28:
		fill = 1
	for index in _socks.size():
		var atlas := _socks[index].texture as AtlasTexture
		# A gust is the same wind a moment stronger, staggered per sock so the
		# quay does not breathe in unison.
		var gust := fill
		if wind > 0.28 and sin(_t * 1.7 + float(index)) > 0.72:
			gust = mini(2, fill + 1)
		atlas.region = Rect2(gust * SOCK_FRAME.x, 0, SOCK_FRAME.x, SOCK_FRAME.y)
	for flag in _flags:
		# Cloth answers faster than a sock, so the pennants carry the speed.
		flag.speed_scale = 0.25 + wind * 2.4
