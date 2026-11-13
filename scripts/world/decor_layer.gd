class_name DecorLayer
extends Node2D
## Everything the player bought purely because it looks good.
##
## The rule that shapes this file: a decoration must be able to appear and
## disappear at any moment without anything else in the port noticing. Nothing
## here is claimed by a task, stands in a driving lane, or is read by a policy —
## it is scenery, and the whole layer is thrown away and rebuilt whenever
## `EventBus.cosmetics_changed` fires. That is why it is one node with one
## rebuild rather than a flag threaded through `PortWorld`.
##
## The two decorations that could *not* live here are in the places that own the
## thing they change: RGB lamps in `Atmosphere`, because a lamp's colour is part
## of the light it throws, and hats in `StructureActor`, because a hat has to
## walk. See `CosmeticDb` for the shelf itself.

## Pitch of a bunting span, matching the sprite so the runs join cleanly.
const BUNTING_SPAN := 64.0
## How far apart the planters stand down the service band.
const PLANTER_PITCH := 74.0
## Cats, and how far a cat may nap from the middle of its block.
const CAT_COUNT := 5

const PALM_PITCH := 64.0
const FLAG_PITCH := 92.0
const BALLOON_SPEED := 6.0

var world: PortWorld
var _duck: Node2D
var _bob := 0.0
## The moving set pieces, drawn by one node: lighthouse beam, balloon,
## dolphins, fireworks, waving flags.
var _show: _Show


func setup(port: PortWorld) -> void:
	world = port
	EventBus.cosmetics_changed.connect(rebuild)
	# Buying land lengthens the quay, which moves the last berth, which moves the
	# only stretch of water the duck can be moored in without a hull on top of it.
	EventBus.land_bought.connect(func(_id: String) -> void: rebuild())
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_duck = null
	if GameState.cosmetic_on(&"bunting"):
		_build_bunting()
	if GameState.cosmetic_on(&"planters"):
		_build_planters()
	if GameState.cosmetic_on(&"cats"):
		_build_cats()
	if GameState.cosmetic_on(&"duck"):
		_build_duck()
	if GameState.cosmetic_on(&"palms"):
		_build_palms()
	_show = _Show.new()
	_show.layer = self
	_show.lighthouse = GameState.cosmetic_on(&"lighthouse")
	_show.balloon = GameState.cosmetic_on(&"balloon")
	_show.dolphins = GameState.cosmetic_on(&"dolphins")
	_show.fireworks = GameState.cosmetic_on(&"fireworks")
	_show.flags = GameState.cosmetic_on(&"flags")
	_show.z_index = 6
	_show.z_as_relative = false
	add_child(_show)
	set_process(true)


func _process(delta: float) -> void:
	## Only the duck moves, and only because a thing floating on water that does
	## not move is a thing painted on water.
	if _show != null and is_instance_valid(_show):
		_show.advance(delta)
	if _duck == null or not is_instance_valid(_duck):
		return
	_bob += delta
	_duck.position.y = _duck_home().y + sin(_bob * 0.8) * 2.0
	_duck.rotation = sin(_bob * 0.55) * 0.035


# ------------------------------------------------------------------- the kit

func _build_bunting() -> void:
	## Strung down the quay and down the service road, which are the two long
	## straight runs the terminal has. Rotated a quarter turn: the sprite is
	## drawn as a horizontal span because that is how a span is drawn, and both
	## of this port's runs go north to south.
	var texture: Texture2D = PortDB.tex("prop_bunting")
	var top := PortLayout.TOP_MARGIN + 12.0
	var bottom := PortLayout.world_bottom() - 12.0
	for line_x in [PortLayout.QUAY_X0 + 8.0, PortLayout.YARD_X0 + 16.0]:
		var y := top
		while y + BUNTING_SPAN <= bottom:
			var span := Sprite2D.new()
			span.texture = texture
			span.centered = true
			span.rotation = PI * 0.5
			span.position = Vector2(line_x, y + BUNTING_SPAN * 0.5)
			# Over the apron, under anything that drives on it.
			span.z_index = -1
			add_child(span)
			y += BUNTING_SPAN


func _build_planters() -> void:
	var texture: Texture2D = preload("res://assets/sprites/prop_planter.png")
	var y := PortLayout.TOP_MARGIN + 34.0
	var side := 0
	while y < PortLayout.world_bottom() - 30.0:
		var planter := Sprite2D.new()
		planter.texture = texture
		planter.centered = true
		# Alternating sides of the service band, so the row reads as planting
		# rather than as a fence.
		planter.position = Vector2(
			PortLayout.QUAY_X0 - 14.0 if side % 2 == 0 else PortLayout.YARD_X0 + 6.0,
			y)
		planter.z_index = -1
		add_child(planter)
		y += PLANTER_PITCH
		side += 1


func _build_cats() -> void:
	## The port already has one cat, asleep on a stack and moving each day. This
	## is the rest of them. They use the same two-frame sheet and the same idea:
	## a cat is a thing you notice on the third look, not on the first.
	var texture: Texture2D = preload("res://assets/sprites/prop_cat.png")
	var rng := RandomNumberGenerator.new()
	# Seeded from the terminal rather than from the clock: the colony should be
	# in the same places after a reload, or the yard shuffles every session.
	rng.seed = 5150 + PortLayout.block_count()
	for index in CAT_COUNT:
		var frames := SpriteFrames.new()
		frames.set_animation_speed(&"default", 1.2)
		for frame in 2:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(frame * 14, 0, 14, 12)
			frames.add_frame(&"default", atlas)
		var cat := AnimatedSprite2D.new()
		cat.sprite_frames = frames
		cat.centered = false
		cat.frame = index % 2
		cat.play()
		var origin := PortLayout.block_origin(
			rng.randi() % maxi(1, PortLayout.block_count()))
		cat.position = origin + Vector2(
			rng.randf_range(0.0, PortLayout.BLOCK_W - 14.0),
			rng.randf_range(0.0, PortLayout.BLOCK_H - 12.0))
		add_child(cat)


func _duck_home() -> Vector2:
	## Moored in the basin south of the last berth.
	##
	## Two goes at this were wrong for two different reasons. `WATER_X0 + 78` is
	## 318 of a 320-wide world, so two thirds of the duck hung off the edge of the
	## map. Putting it back in the middle of the channel then parked it *under a
	## ship*: a hull is 66 wide in an 80-wide channel, so along the quay there is
	## no water a berth is not already using.
	##
	## What is always clear is the water past the last hull, and how far down that
	## is depends on how much quay has been bought — hence `berth_count`, and
	## hence the rebuild on `land_bought`.
	var last_berth := PortLayout.berth_y(PortLayout.berth_count() - 1)
	return Vector2((PortLayout.WATER_X0 + PortLayout.WORLD_W) * 0.5 - 6.0,
		minf(last_berth + PortLayout.SHIP_H + 46.0,
			PortLayout.world_bottom() - 46.0))


func _build_duck() -> void:
	_duck = Node2D.new()
	_duck.position = _duck_home()
	# Over the water and its foam, under the ships: a duck a hull sails through
	# would be a funnier joke and a worse one.
	_duck.z_index = 4
	_duck.z_as_relative = false
	add_child(_duck)
	var body := Sprite2D.new()
	body.texture = preload("res://assets/sprites/prop_duck.png")
	body.centered = true
	_duck.add_child(body)
	# The ring it pushes out, which is what seats it *in* the water.
	var wash := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/prop_splash.png")
	atlas.region = Rect2(60, 0, 20, 14)
	wash.texture = atlas
	wash.centered = true
	wash.position = Vector2(0, body.texture.get_height() * 0.42)
	# Narrower than the duck, not wider: a ring that oversails the thing making
	# it reads as a puddle the duck is standing in.
	wash.scale = Vector2(1.7, 0.9)
	wash.modulate = Color(1, 1, 1, 0.28)
	_duck.add_child(wash)


func _build_palms() -> void:
	## Down the grass verge west of the access road, the length of the port.
	var texture: Texture2D = preload("res://assets/sprites/prop_palm.png")
	var y := PortLayout.TOP_MARGIN + 20.0
	while y < PortLayout.world_bottom() - 20.0:
		var palm := Sprite2D.new()
		palm.texture = texture
		palm.centered = true
		palm.position = Vector2(4.0, y)
		add_child(palm)
		y += PALM_PITCH


func lighthouse_spot() -> Vector2:
	## On the breakwater at the top of the channel, clear of the berths.
	return Vector2(PortLayout.WORLD_W - 14.0, PortLayout.TOP_MARGIN - 6.0)


func basin_spot() -> Vector2:
	return _duck_home() + Vector2(-18.0, 22.0)


class _Show extends Node2D:
	## Everything on the shelf that moves on its own, in one node so the layer
	## stays one rebuild: the lighthouse's beam, the balloon crossing the
	## terminal, a dolphin jumping in the basin, fireworks over the water at
	## night, and the flags on the quay snapping in the wind.
	const LIGHTHOUSE := preload("res://assets/sprites/prop_lighthouse.png")
	const BALLOON := preload("res://assets/sprites/prop_balloon.png")
	const DOLPHIN := preload("res://assets/sprites/prop_dolphin.png")
	const POLE := preload("res://assets/sprites/prop_flagpole.png")
	const FLAGS := preload("res://assets/sprites/ui_flags.png")

	var layer: DecorLayer
	var lighthouse := false
	var balloon := false
	var dolphins := false
	var fireworks := false
	var flags := false
	var _t := 0.0
	var _balloon_x := -30.0
	var _jump := -1.0
	var _jump_at := Vector2.ZERO
	var _next_jump := 3.0
	var _bursts: Array[Dictionary] = []
	var _next_burst := 0.5
	var _rng := RandomNumberGenerator.new()

	func advance(delta: float) -> void:
		if not (lighthouse or balloon or dolphins or fireworks or flags):
			return
		_t += delta
		if not UserPreferences.can_animate():
			queue_redraw()
			return
		_balloon_x += BALLOON_SPEED * delta
		if _balloon_x > PortLayout.WORLD_W + 30.0:
			_balloon_x = -30.0
		if dolphins:
			if _jump >= 0.0:
				_jump += delta
				if _jump > 1.1:
					_jump = -1.0
			else:
				_next_jump -= delta
				if _next_jump <= 0.0:
					_jump = 0.0
					_jump_at = layer.basin_spot() + Vector2(_rng.randf_range(-16.0, 16.0),
						_rng.randf_range(-20.0, 10.0))
					_next_jump = _rng.randf_range(4.0, 9.0)
		if fireworks and TimeManager.phase() == &"night":
			_next_burst -= delta
			if _next_burst <= 0.0:
				_next_burst = _rng.randf_range(0.8, 2.2)
				_bursts.append({"at": Vector2(_rng.randf_range(250.0, 310.0),
					_rng.randf_range(PortLayout.TOP_MARGIN + 30.0, PortLayout.VIEW_H)),
					"age": 0.0, "hue": _rng.randf()})
		var alive: Array[Dictionary] = []
		for burst: Dictionary in _bursts:
			burst.age = float(burst.age) + delta
			if float(burst.age) < 1.6:
				alive.append(burst)
		_bursts = alive
		queue_redraw()

	func _night() -> float:
		match TimeManager.phase():
			&"night":
				return 1.0
			&"dusk", &"dawn":
				return 0.5
		return 0.15

	func _draw() -> void:
		if flags:
			_draw_flags()
		if lighthouse:
			var spot := layer.lighthouse_spot()
			draw_texture(LIGHTHOUSE, spot - Vector2(9, 36))
			# The beam sweeps round; brighter the darker it gets.
			var angle := _t * 0.9
			var lamp := spot + Vector2(0, -29)
			var dir := Vector2.from_angle(angle)
			var side := dir.orthogonal()
			var reach := 120.0
			var alpha := 0.10 + 0.22 * _night()
			draw_colored_polygon(PackedVector2Array([lamp, lamp + dir * reach + side * 16.0,
				lamp + dir * reach - side * 16.0]), Color(1.0, 0.94, 0.6, alpha))
			draw_circle(lamp, 4.0, Color(1.0, 0.94, 0.6, 0.5 + 0.3 * _night()))
		if dolphins and _jump >= 0.0:
			var k := _jump / 1.1
			var at := _jump_at + Vector2(k * 18.0 - 9.0, -sin(k * PI) * 10.0)
			var frame := 0 if k < 0.5 else 1
			draw_texture_rect_region(DOLPHIN, Rect2(at.round(), Vector2(18, 12)),
				Rect2(frame * 18, 0, 18, 12))
			if k < 0.15 or k > 0.85:
				var splash := _jump_at + Vector2(-9.0 if k < 0.5 else 9.0, 10.0)
				for i in 4:
					draw_rect(Rect2(splash + Vector2(i * 3 - 4, -i % 2 * 2), Vector2(2, 2)),
						Color(0.9, 0.96, 1.0, 0.8))
		for burst: Dictionary in _bursts:
			var age := float(burst.age)
			var colour := Color.from_hsv(float(burst.hue), 0.6, 1.0)
			var at: Vector2 = burst.at
			if age < 0.4:
				# The shell going up.
				draw_rect(Rect2(at + Vector2(0, (0.4 - age) * 60.0), Vector2(1, 3)),
					Color(1, 0.9, 0.7, 0.9))
				continue
			var r := (age - 0.4) * 26.0
			var fade := clampf(1.6 - age, 0.0, 1.0)
			for i in 12:
				var p := at + Vector2.from_angle(TAU * i / 12.0) * r + Vector2(0, r * r * 0.02)
				draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(colour, fade))
		if balloon:
			var y := PortLayout.VIEW_H * 0.55 + sin(_t * 0.3) * 30.0
			var at := Vector2(_balloon_x, y)
			# Its shadow on the ground far below, then the balloon.
			draw_circle(at + Vector2(26, 60), 6.0, Color(0, 0, 0, 0.15))
			draw_texture(BALLOON, (at - Vector2(11, 15) + Vector2(0, sin(_t * 1.4) * 1.5)).round())

	func _draw_flags() -> void:
		var x := PortLayout.WATER_X0 - 5.0
		var y := PortLayout.TOP_MARGIN + 40.0
		var i := 0
		var count := FleetDB.FLAGS.size()
		while y < PortLayout.world_bottom() - 30.0:
			draw_texture(POLE, Vector2(x - 2.0, y - 20.0))
			var flag := posmod(i * 7, count)
			var wave := 1.0 if int(_t * 3.0 + i) % 2 == 0 else 0.0
			draw_texture_rect_region(FLAGS, Rect2(x + 1.0, y - 20.0 + wave, 11, 8),
				Rect2(flag * FleetDB.FLAG_SIZE.x, 0, FleetDB.FLAG_SIZE.x, FleetDB.FLAG_SIZE.y))
			y += FLAG_PITCH
			i += 1
