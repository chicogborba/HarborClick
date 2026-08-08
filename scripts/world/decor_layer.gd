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

var world: PortWorld
var _duck: Node2D
var _bob := 0.0


func setup(port: PortWorld) -> void:
	world = port
	EventBus.cosmetics_changed.connect(rebuild)
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
	set_process(_duck != null)


func _process(delta: float) -> void:
	## Only the duck moves, and only because a thing floating on water that does
	## not move is a thing painted on water.
	if _duck == null or not is_instance_valid(_duck):
		set_process(false)
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
	var texture: Texture2D = preload("res://assets/sprites/prop_bunting.png")
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
	## Moored out in the basin, clear of the fairway a ship comes up. Far enough
	## off the wall to be obviously *floating* rather than parked on the apron.
	return Vector2(PortLayout.WATER_X0 + 78.0,
		PortLayout.TOP_MARGIN + PortLayout.world_bottom() * 0.42)


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
	wash.position = Vector2(0, body.texture.get_height() * 0.4)
	wash.scale = Vector2(2.6, 1.4)
	wash.modulate = Color(1, 1, 1, 0.35)
	_duck.add_child(wash)
