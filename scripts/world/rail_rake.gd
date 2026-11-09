class_name RailRake
extends Node2D
## The train on the branch, and the shunt that lets it leave.
##
## `RailYard` owns the cargo and the schedule. This owns nothing but the
## picture: where the loco is, where each wagon is, which wagons are carrying a
## box, and how the rake gets from one end of the siding to the other. It
## reports back at three moments — standing, run round, gone — and every one of
## them has a timeout on the controller's side, so a rake that is never drawn
## still finishes its service.
##
## The run-around is the point of this class. The corridor is a stub siding: the
## rails end at a buffer stop with the quay behind it, so a train that ran in
## nose-first cannot simply drive out the other side, and the previous version
## solved that by flipping the sprite's x scale at the moment of departure — the
## locomotive teleported to the other end of its own train. Here it does the
## move a real one does. It uncouples, draws forward past the turnout, crosses to
## the run-around road, runs back west alongside its train, crosses again and
## couples to what used to be the tail. Same train, other end, no cheating.
##
## Everything else here exists because the branch is the one part of the
## terminal the camera does not point at. It runs along the very bottom of the
## world, below the last row of sheds, and a player has to choose to go and look
## — so when they do, it has to be worth the trip and it has to be *legible from
## the sound alone* when they don't. Hence a headlight that leads the train, an
## exhaust plume that thickens with the load on the engine, brake dust under the
## bogies at the stand, three different wagons in the rake, and a horn, a squeal
## and a coupling clank at the three moments that matter.

signal arrived
signal ran_around
signal departed

## The rake is drawn at the size it is shown (`tools/sprites/gen_train.py`):
## a wagon is exactly one `RAIL_WAGON_PITCH` long, couplers included, so a rake
## couples up buffer to buffer. It used to be 34px art scaled by 0.62 in-engine,
## which put pixels of two sizes on one screen and carried every box on the
## branch a third smaller than the identical box in the yard beside it.
const WAGON_LEN := 21.0
const LOCO_LEN := 29.0
## Centre-to-centre from the head wagon to a loco coupled onto it. Both lengths
## are odd, so this is a whole number and the couplers meet on a pixel boundary.
const LOCO_GAP := (WAGON_LEN + LOCO_LEN) * 0.5
## Each sprite's top-left relative to its centre on the running line — the
## row of the art that sits on `PortLayout.rail_y()`. Mirrors the constants in
## `gen_train.py`; the rail suite checks the textures are the size these assume.
const WAGON_OFFSET := Vector2(-10, -8)
const LOCO_OFFSET := Vector2(-14, -10)
## A box's top-left on its wagon: its side wall stands on the deck's south edge.
const BOX_OFFSET := Vector2(-8, -8)
const BOX_W := 18
const BOX_H := 11
const LAMP_W := 22
const LAMP_OFFSET_Y := -6.0

const RUN_SPEED := 48.0
const SHUNT_SPEED := 33.0
const CROSS_SPEED := 14.0
const BRAKING_DISTANCE := 44.0

## Wagon variety. `veh_wagon` is a three-frame sheet — container flat, well
## wagon, skeletal spine — and a rake is dealt from it by slot. Six identical
## vehicles read as a decal of a train; three kinds shuffled read as whatever
## the interior could couple up that morning.
const WAGON_W := 21
const WAGON_H := 18
## The order a rake is dealt in. A written-out deal rather than `slot % 3`,
## which lays a three-wagon stripe that a six-wagon rake then shows twice; this
## one puts no two alike next to each other and does not visibly repeat inside
## the longest rake the branch runs.
const WAGON_DEAL: Array[int] = [0, 2, 1, 0, 1, 2, 2, 0, 1]

## Exhaust. A fixed pool, cycled: the plume runs the whole length of every
## journey and a rake that allocated a node per puff would be the only thing in
## the world churning the scene tree once a frame.
const SMOKE_PUFFS := 14
const SMOKE_LIFE := 1.45
## Puffs per second at full line speed. Under this the plume is a dotted line;
## over it, it is a smear.
const SMOKE_RATE := 9.0
## How far a puff drifts by the end of its life. North, because the camera looks
## down: away from the viewer is up.
const SMOKE_RISE := 13.0
const SMOKE_DRIFT := 5.0
## A puff opens out as it goes. The art is 12px square, so it leaves the stack
## tighter than the sprite and ends up half as wide again.
const SMOKE_SIZE_FROM := 0.75
const SMOKE_SIZE_TO := 1.75

## Brake dust, thrown once as the rake comes to a stand.
const DUST_PUFFS := 4

## The shunt, in the order the locomotive performs it.
enum Shunt { DRAW_FORWARD, CROSS_EAST, RUN_BACK, CROSS_WEST, COUPLE, DONE }

enum Mode { RUNNING_IN, STANDING, SHUNTING, RUNNING_OUT, GONE }

var mode: Mode = Mode.RUNNING_IN

var _length := 0
## x of the head wagon. Every other vehicle is placed off this.
var _lead_x := 0.0
var _loco := Sprite2D.new()
var _loco_pos := Vector2.ZERO
var _lamp := Sprite2D.new()
var _shunt: Shunt = Shunt.DRAW_FORWARD
## Which end of its train the loco is coupled to. It runs in on the east end,
## which is the end pointing at the buffer stop, and leaves on the west one.
var _loco_east := true
var _wagons: Array[Sprite2D] = []
var _boxes: Array[Sprite2D] = []
var _sheet: Texture2D = preload("res://assets/sprites/rail_box_sheet.png")
var _wagon_sheet: Texture2D = preload("res://assets/sprites/veh_wagon.png")

## How fast the locomotive is actually travelling, measured rather than
## declared: the shunt moves it on one axis and the run moves the whole rake on
## another, and the plume has to answer to both without either knowing about it.
var _speed := 0.0
var _last_loco_pos := Vector2.ZERO
var _smoke: Array[Sprite2D] = []
var _smoke_age := PackedFloat32Array()
var _smoke_dir := PackedFloat32Array()
var _smoke_next := 0
var _smoke_carry := 0.0
## One horn per journey, not one per frame.
var _sounded := false


func setup(length: int, standing: bool) -> void:
	## `standing` restores a service that a save caught at the ramp: the train is
	## already there, so it must not run in again.
	_length = maxi(1, length)
	name = "RailRake"
	position = Vector2.ZERO
	_build()
	if standing:
		_lead_x = PortLayout.rail_stop_x()
		mode = Mode.STANDING
		# A restored rake is not arriving, so it neither sounds up nor squeals to
		# a stand. It has been here all along as far as the player knows.
		_sounded = true
	else:
		_lead_x = PortLayout.RAIL_STAGING_X
		mode = Mode.RUNNING_IN
	_loco_east = true
	_place()
	_last_loco_pos = _loco_pos


func _build() -> void:
	_loco.texture = preload("res://assets/sprites/veh_loco.png")
	# Drawn nose east, the way the branch runs in, and never rotated: the art
	# shows its south side the way every stack in the yard does, and a quarter
	# turn would stand that side up on end. Turning round is a mirror.
	_loco.centered = false
	_loco.offset = LOCO_OFFSET
	add_child(_loco)
	_lamp.texture = preload("res://assets/sprites/veh_loco_lamp.png")
	_lamp.centered = false
	_lamp.visible = false
	# Light adds to what it falls on. Alpha-blended, the cone would darken the
	# rails under it, which is the one thing a headlight cannot do.
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lamp.material = glow
	add_child(_lamp)
	for slot in _length:
		var wagon := Sprite2D.new()
		var deck := AtlasTexture.new()
		deck.atlas = _wagon_sheet
		# Dealt by slot rather than at random: the same service looks the same
		# after a reload, and a rake never comes back as a different train.
		deck.region = Rect2(_wagon_kind(slot) * WAGON_W, 0, WAGON_W, WAGON_H)
		wagon.texture = deck
		wagon.centered = false
		wagon.offset = WAGON_OFFSET
		add_child(wagon)
		_wagons.append(wagon)
		var box := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = _sheet
		atlas.region = Rect2(0, 0, BOX_W, BOX_H)
		box.texture = atlas
		# Lengthwise along the wagon, like the wagon itself, and drawn for the
		# wagon: `rail_box_sheet` is the yard's eight liveries cut to the deck of
		# a 21px wagon. The yard's own 24px box laid on it would overhang the
		# couplers, and a quarter-turned one put a forty-footer crosswise on a
		# wagon barely wider than a person — cargo that had fallen over.
		box.centered = false
		box.offset = BOX_OFFSET
		box.visible = false
		add_child(box)
		_boxes.append(box)
	# Last, so the plume draws over the train it comes out of. The camera looks
	# down: exhaust rises *towards the viewer*, so anything it passes in front of
	# it should hide. Built under the vehicles first time round, which put every
	# puff behind the locomotive that made it — the one object guaranteed to be
	# in the way — and the engine appeared to be running clean.
	_build_smoke()


func _wagon_kind(slot: int) -> int:
	return WAGON_DEAL[posmod(slot, WAGON_DEAL.size())]


func _build_smoke() -> void:
	var exhaust: Texture2D = preload("res://assets/sprites/prop_exhaust.png")
	_smoke_age.resize(SMOKE_PUFFS)
	_smoke_dir.resize(SMOKE_PUFFS)
	for index in SMOKE_PUFFS:
		var puff := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = exhaust
		atlas.region = Rect2(0, 0, 12, 12)
		puff.texture = atlas
		puff.centered = true
		puff.visible = false
		add_child(puff)
		_smoke.append(puff)
		# Retired, not new. A rake that started with fourteen puffs already in
		# the air would appear in a cloud of its own making.
		_smoke_age[index] = SMOKE_LIFE
		_smoke_dir[index] = 0.0


func sync(rail: RailYard) -> void:
	## Which wagons are carrying something, straight off the controller. A wagon
	## whose box is currently in the air shows nothing: the flight is drawing it.
	for slot in _boxes.size():
		var unit := rail.wagon_unit(slot)
		_boxes[slot].visible = unit != null
		if unit == null:
			continue
		var atlas := _boxes[slot].texture as AtlasTexture
		if atlas != null:
			atlas.region = Rect2(posmod(unit.color, 8) * BOX_W, 0, BOX_W, BOX_H)


func run_around() -> void:
	if mode == Mode.SHUNTING or mode == Mode.GONE:
		return
	mode = Mode.SHUNTING
	_shunt = Shunt.DRAW_FORWARD
	_loco_pos = _loco.position


func run_out() -> void:
	if mode == Mode.GONE:
		return
	if mode != Mode.RUNNING_OUT:
		# Sounding up before moving off is the whole convention: the horn is a
		# warning, so it has to come before the thing it warns about.
		AudioManager.play_sfx("train_horn", 0.05, -5.0)
	mode = Mode.RUNNING_OUT


func _process(delta: float) -> void:
	match mode:
		Mode.RUNNING_IN:
			_run_in(delta)
		Mode.SHUNTING:
			_shunt_step(delta)
		Mode.RUNNING_OUT:
			_run_out(delta)
		_:
			pass
	_place()
	_drive_smoke(delta)
	_drive_lamp()


func _run_in(delta: float) -> void:
	## Ease into the stand rather than stopping dead: a loaded rake weighs a
	## couple of thousand tonnes and it should look like it.
	if not _sounded:
		_sounded = true
		AudioManager.play_sfx("train_horn", 0.05, -6.0)
	var target := PortLayout.rail_stop_x()
	var remaining := target - _lead_x
	var speed := clampf(remaining / BRAKING_DISTANCE * RUN_SPEED, 7.0, RUN_SPEED)
	# The squeal starts where the brakes do, not where the train stops.
	if remaining <= BRAKING_DISTANCE and remaining + speed * delta > BRAKING_DISTANCE:
		AudioManager.play_sfx("rail_brake", 0.05, -9.0)
	_lead_x = minf(target, _lead_x + speed * delta)
	if target - _lead_x <= 0.5:
		_lead_x = target
		mode = Mode.STANDING
		_throw_brake_dust()
		arrived.emit()


func _run_out(delta: float) -> void:
	## The head wagon is the last thing over the boundary, so it is the one that
	## decides when the service is off the map.
	_lead_x -= RUN_SPEED * delta
	if _lead_x > PortLayout.RAIL_STAGING_X:
		return
	mode = Mode.GONE
	departed.emit()


func _shunt_step(delta: float) -> void:
	var rail_y := PortLayout.rail_y()
	var loop_y := PortLayout.rail_loop_y()
	match _shunt:
		Shunt.DRAW_FORWARD:
			# Clear of the train, and clear of the turnout blades behind it.
			_loco_east = true
			if _advance_x(PortLayout.rail_east_turnout_x() + 6.0, SHUNT_SPEED, delta):
				_shunt = Shunt.CROSS_EAST
		Shunt.CROSS_EAST:
			if _advance_y(loop_y, CROSS_SPEED, delta):
				_shunt = Shunt.RUN_BACK
		Shunt.RUN_BACK:
			# Back down the run-around road, past its own train.
			_loco_east = false
			if _advance_x(PortLayout.rail_west_turnout_x() - 4.0, SHUNT_SPEED, delta):
				_shunt = Shunt.CROSS_WEST
		Shunt.CROSS_WEST:
			if _advance_y(rail_y, CROSS_SPEED, delta):
				_shunt = Shunt.COUPLE
		Shunt.COUPLE:
			# On to the back of the train, which is now the front.
			_loco_east = true
			if _advance_x(_tail_x() - LOCO_GAP, SHUNT_SPEED, delta):
				_shunt = Shunt.DONE
				_loco_east = false
				mode = Mode.STANDING
				# Buffers meeting. The one moment in the shunt with a sound of
				# its own, and the one that says the move actually finished.
				AudioManager.play_sfx("coupling", 0.06, -6.0)
				ran_around.emit()
		_:
			pass


func _advance_x(target_x: float, speed: float, delta: float) -> bool:
	var step := speed * delta
	var to_target := target_x - _loco_pos.x
	if absf(to_target) <= step:
		_loco_pos.x = target_x
		return true
	_loco_pos.x += signf(to_target) * step
	return false


func _advance_y(target_y: float, speed: float, delta: float) -> bool:
	var step := speed * delta
	var to_target := target_y - _loco_pos.y
	if absf(to_target) <= step:
		_loco_pos.y = target_y
		return true
	_loco_pos.y += signf(to_target) * step
	return false


func _tail_x() -> float:
	return _lead_x - PortLayout.RAIL_WAGON_PITCH * (_length - 1)


func _place() -> void:
	var rail_y := PortLayout.rail_y()
	# Whole pixels only. Art drawn 1:1 and placed at a fractional position is
	# resampled by the nearest filter, and a moving train shimmers row by row.
	var lead := roundf(_lead_x)
	for slot in _wagons.size():
		var x := lead - PortLayout.RAIL_WAGON_PITCH * slot
		_wagons[slot].position = Vector2(x, rail_y).round()
		_boxes[slot].position = Vector2(x, rail_y).round()
	if mode != Mode.SHUNTING:
		# Coupled: the loco stands at whichever end it is currently on.
		_loco_pos = Vector2(
			_lead_x + LOCO_GAP if _loco_east else _tail_x() - LOCO_GAP, rail_y)
	_loco.position = _loco_pos.round()
	# A locomotive faces the way it is going. Its own sprite mirrors, not the
	# rake, which is what keeps the wagons from turning round with it.
	_loco.flip_h = not _loco_east


# ----------------------------------------------------------------------- fx

func _drive_lamp() -> void:
	## The headlight leads. It is lit whenever the train is moving under its own
	## power and dark at the stand, which is both what a real one does and the
	## cheapest possible answer to "is this thing about to move?".
	var lit := mode == Mode.RUNNING_IN or mode == Mode.RUNNING_OUT \
		or mode == Mode.SHUNTING
	_lamp.visible = lit
	if not lit:
		return
	var facing := 1.0 if _loco_east else -1.0
	# At the nose, throwing along the track. The cone is drawn pointing east and
	# mirrors with the loco.
	_lamp.flip_h = not _loco_east
	_lamp.offset = Vector2(0.0 if _loco_east else -LAMP_W, LAMP_OFFSET_Y)
	_lamp.position = (_loco_pos + Vector2(facing * (LOCO_LEN * 0.5 + 1.0), 0.0)).round()


func _throw_brake_dust() -> void:
	## Brake smoke under the bogies as the rake comes to a stand — grey, because
	## that is what cast-iron blocks on steel tyres actually make, which is why
	## it can share the exhaust's pool and its art. Dealt along the train rather
	## than out of the stack: a puff at the wheels is the difference between
	## stopping and having arrived already stopped.
	var rail_y := PortLayout.rail_y()
	for index in DUST_PUFFS:
		var at := _lead_x - PortLayout.RAIL_WAGON_PITCH * (float(index) * 1.4)
		_emit_smoke(Vector2(at, rail_y + 5.0), 0.0)


func _drive_smoke(delta: float) -> void:
	## Two jobs on one pool: age everything that is already in the air, and put
	## a new puff out of the stack if the engine is working hard enough to make
	## one. Measured speed rather than the mode, because the shunt and the run
	## move the loco on different axes at different rates and the plume should
	## thin out for the slow one without being told.
	var travelled := _loco_pos.distance_to(_last_loco_pos)
	_last_loco_pos = _loco_pos
	_speed = travelled / maxf(delta, 0.0001)
	for index in _smoke.size():
		var age := _smoke_age[index] + delta
		_smoke_age[index] = age
		var puff := _smoke[index]
		if age >= SMOKE_LIFE:
			puff.visible = false
			continue
		var t := age / SMOKE_LIFE
		var atlas := puff.texture as AtlasTexture
		if atlas != null:
			atlas.region = Rect2(mini(3, int(t * 4.0)) * 12, 0, 12, 12)
		# Rising away from the camera and trailing behind the engine that made
		# it. Both ease off, the way a plume loses its momentum to the air.
		var ease := 1.0 - (1.0 - t) * (1.0 - t)
		puff.position = puff.position + Vector2(
			_smoke_dir[index] * SMOKE_DRIFT * delta,
			-SMOKE_RISE * delta * (1.0 - t * 0.55))
		# Opening out as well as thinning. The four sheet frames carry some of
		# this, but the whole port fits in a phone's width — at that zoom the
		# branch is forty pixels tall and a plume that only changed colour was a
		# plume nobody could see. Growth is the part that survives the scale.
		puff.scale = Vector2.ONE * (SMOKE_SIZE_FROM
			+ (SMOKE_SIZE_TO - SMOKE_SIZE_FROM) * ease)
		puff.modulate.a = 1.0 - ease
		puff.visible = true
	if mode == Mode.STANDING or mode == Mode.GONE or _speed <= 1.0:
		return
	_smoke_carry += delta * SMOKE_RATE * clampf(_speed / RUN_SPEED, 0.35, 1.0)
	if _smoke_carry < 1.0:
		return
	_smoke_carry -= 1.0
	# Out of the stack, which sits just behind the nose. Clear of the roof line
	# rather than on it: a puff born inside the locomotive's own silhouette
	# spends the first third of its life invisible.
	var facing := 1.0 if _loco_east else -1.0
	# The stack is on the long hood just behind the cab (`gen_train.py`), and the
	# puff is a 12px sprite drawn centred, so it starts above the roof line.
	_emit_smoke(_loco_pos + Vector2(facing * 1.0, -11.0), -facing)


func _emit_smoke(at: Vector2, drift: float) -> void:
	var index := _smoke_next
	_smoke_next = (_smoke_next + 1) % maxi(1, _smoke.size())
	if index >= _smoke.size():
		return
	var puff := _smoke[index]
	puff.position = at
	puff.modulate.a = 1.0
	puff.scale = Vector2.ONE * SMOKE_SIZE_FROM
	puff.visible = true
	_smoke_age[index] = 0.0
	_smoke_dir[index] = drift
