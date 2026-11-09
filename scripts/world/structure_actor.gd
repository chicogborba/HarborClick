class_name StructureActor
extends Node2D
## One visible instance of a bought structure.
##
## Haulers (reach stacker, empty handler, terminal tractor) actually work:
## they come in through the gate, run down the service road, reach into a
## block from the driving lane, and carry the box back out of the terminal.
## Gantries and buildings animate in place.
##
## The ones that are somebody's job — see `NpcCatalog` — also carry that person's
## `NpcProfile` and take their work from the `TaskBoard`, one claim at a time, so
## two of them can never be sent to the same box. A machine with no crew (a
## warehouse, the radar tower) is left exactly as it was: infrastructure.

const CONTAINERS := preload("res://assets/sprites/container_sheet.png")
const HAULERS := ["tt", "empilhadeira", "reach_stacker"]
## Where the portainer's trolley sits over the hull and over the quay apron.
const STS_SHIP_X := 52.0
const STS_YARD_X := -30.0
## Touch target floor for inspecting a person. A 9x12 stevedore is not tappable
## on a phone at its own size.
const TOUCH_HALF := Vector2(11.0, 12.0)

enum Job {
	IDLE, ENTERING, TO_TARGET, WORKING, TO_ROAD, LEAVING,
	## Legs of a `CargoRelay`: driving empty to the box, driving loaded to the
	## hand-off, standing there until the relay lets go, and driving back to the
	## parking rank afterwards.
	RELAY_FETCH, RELAY_CARRY, RELAY_HOLD, RELAY_HOME,
}

# ---------------------------------------------------------------- relay stages
## What a `CargoRelay` needs to know about the machine holding its box, polled
## rather than signalled: it is one integer, it changes at most three times per
## run, and polling cannot leave a dangling connection on a freed traveller.
const RELAY_NONE := 0      ## not on a relay, or gave the run back
const RELAY_APPROACH := 1  ## on the way to the box, chassis empty
const RELAY_CARRY := 2     ## box aboard
const RELAY_DONE := 3      ## set down at the hand-off, waiting to be released

# ------------------------------------------------------------ being picked up
## Press and hold on somebody and you lift them off the ground: they swing from
## the scruff, kick, and grow because they are nearer the camera than the yard
## is. Let go and they drop, land, and walk back to whatever they were doing.
##
## It is the one thing in the game you do to a person rather than to cargo, and
## it costs the simulation nothing — the round they were walking is a task off
## the board, so being carried across the terminal only means the walk back is
## longer.
const GRAB_SCALE := 1.8
## How far the feet hang above the point under the hand, once grown.
const GRAB_CLEARANCE := 7.0
const GRAB_SWING := 0.26
const GRAB_BLEND_RATE := 7.0
## Half the walking frame, so the swing pivots on the scruff of the neck rather
## than on the corner of the sprite.
const GRAB_PIVOT_X := -4.5
const GRAB_FRAME_H := 12.0
## The squash on landing, and how long it takes to spring out of it.
const LAND_TIME := 0.2
## `prop_shadow` is authored at 32x20; this is the patch a nine-pixel figure
## casts on the apron.
const GRAB_SHADOW_SCALE := Vector2(10.0 / 32.0, 5.0 / 20.0)

# ------------------------------------------------------------------ overboard
## Let go of somebody past the quay edge and they go in the water.
##
## `release` used to clamp the drop back onto the apron, on the grounds that a
## conferente treading water was worse than a small correction. It was, while
## treading water was all that happened. Now they go under, surface, swim back
## to the wall, climb out and drip across the yard for a few seconds — which is
## the correction, done as a consequence instead of as a teleport.
##
## Nothing about it costs the simulation anything: the claim is handed back the
## moment they hit the water, so the station reopens and somebody dry takes it.
enum Wet { DRY, SPLASH, SWIM, CLIMB }
## How long they are under before they surface, and how far they sink.
const DUNK_TIME := 0.45
## A person swims a good deal slower than they walk, and the difference is the
## whole joke.
const SWIM_SPEED := 21.0
const SWIM_BOB := 1.5
const CLIMB_TIME := 0.5
## Wet footprints and drips, after. Long enough to notice on the walk back.
const DRIP_TIME := 4.0
## Where a swimmer aims: the quay wall, a body's width inside it.
const SHORE_X := PortLayout.QUAY_X1 - 7.0
## `prop_splash` is four frames; playing them this fast is one ring opening.
const SPLASH_FRAMES := 4.0
const SPLASH_FPS := 12.0

## Beacons stop being countable past this, and the row stops fitting the machine.
const MAX_UPGRADE_MARKS := 4
const MARK_OFFSET_Y := -9.0

## How long a hauler may sit blocked before it gives the job back.
const STALL_TIMEOUT := 12.0
## A truck has mass. Constant speed and instant 90-degree turns are what made
## the yard read as boxes sliding around rather than vehicles driving.
const ACCELERATION := 52.0
const BRAKING := 78.0
const BRAKE_DISTANCE := 16.0
const TURN_RATE := 7.0
const TUG_ESCORT_SPEED := 58.0
const TUG_HOLD_SPEED := 24.0

var id: String = ""
var index := 0
## The person operating this machine, or null when it is infrastructure.
var profile: NpcProfile
var station: StringName = &""

var _sprite: Node2D
var _hat: AnimatedSprite2D    # tinted helmet for a crew member who has one
var _extra: Node2D            # trolley / radar / barrier arm
var _spreader: Sprite2D
var _cargo: Sprite2D
var _shadow: Sprite2D
var _walk: AnimatedSprite2D
var _held := false
var _grab_blend := 0.0
var _grab_shadow: Sprite2D
var _grab_home_z := 0
var _wet: Wet = Wet.DRY
var _wet_t := 0.0
var _drip_t := 0.0
var _wake_t := 0.0
var _waterline: Sprite2D
var _land_t := 0.0
var _boat_fx: Node2D
var _boat_wake: AnimatedSprite2D
var _boat_glows: Array[Sprite2D] = []
## Amber beacons, one per fitted upgrade. See `refresh_upgrade_marks`.
var _marks: Node2D

var _t := 0.0
var _phase := 0.0
var _dir := 1.0
var _lane_y := 0.0
var _lane_x := 0.0
var _vertical := false
var _block_origin := Vector2.ZERO
var _block_index := -1
var _speed := 26.0

# hauler job state
var _job: Job = Job.IDLE
var _job_data: Dictionary = {}
## The claim held on the task board, if this actor is crewed.
var _task: Dictionary = {}
## The real berth transfer this crane was handed, while it is in the air.
var _berth_move: Dictionary = {}
## Throttle on stations whose claim has to be rechecked rather than driven by an
## event: deriving needs allocates, and none of it changes within a frame.
var _claim_check := 0.0
var _waypoints: Array[Vector2] = []
var _lane_key := ""
var _stalled := 0.0
var _cruise := 0.0
var _facing := 0.0
var _cooldown := 0.0
var _work_timer := 0.0
var _carrying := false
var _world: PortWorld
var _escort_active := false

# walker state
var _stroll_target := Vector2.ZERO
var _stroll_pause := 0.0

# gantry state
var _gantry_cycle := 0.0
var _gantry_idle := true

# relay state
var _relay_stage := RELAY_NONE
var _relay_to := Vector2.ZERO
## The leg a gantry is shadowing: the box's own path, which the trolley tracks in
## x and — for a transtainer, which rolls — in y as well.
var _relay_mirror: Dictionary = {}
## The parking rank this machine goes home to. Set by `StructureLayer`, because
## it is the only thing that knows how many of each machine exist.
var _depot := Vector2.ZERO


func setup(structure_id: String, actor_index: int, world: PortWorld) -> void:
	id = structure_id
	index = actor_index
	_world = world
	station = NpcCatalog.station_of(structure_id)
	# The operator is hired before the sprite is built, because a special one
	# changes how the sprite is built.
	if world != null and world.crew != null:
		profile = world.crew.profile_for(structure_id, actor_index)
	_phase = randf() * TAU
	_dir = 1.0 if actor_index % 2 == 0 else -1.0
	_cooldown = randf_range(0.5, 5.0)
	_build()
	refresh_upgrade_marks()
	EventBus.upgrade_bought.connect(
		func(_upgrade_id: String) -> void: refresh_upgrade_marks())


func is_hauler() -> bool:
	return HAULERS.has(id)


func is_crew() -> bool:
	## Somebody is on this machine's books. True for the whole roster, including
	## everyone who works sitting in a cab — the Port Journal lists them all.
	return profile != null


func grab() -> bool:
	## Lift somebody off the ground. Only people on foot: a transtêiner dangling
	## from the sky would be a different game.
	if _held or not is_person():
		return false
	_held = true
	_grab_home_z = z_index
	# Over everything. Held above the yard they have to read as being in front of
	# the stacks, not walking behind them.
	z_index = 60
	_land_t = 0.0
	_ensure_grab_shadow()
	return true


func drag_to(world_pos: Vector2) -> void:
	## The hand's position on the ground, which is what the shadow tracks. The
	## figure itself hangs above it.
	if not _held:
		return
	position = world_pos


func release() -> void:
	if not _held:
		return
	_held = false
	z_index = _grab_home_z
	_land_t = LAND_TIME
	position.y = clampf(position.y, PortLayout.TOP_MARGIN,
		PortLayout.world_bottom() - 14.0)
	if position.x > PortLayout.WATER_X0 + 2.0:
		# Past the wall. They are going in, and the swim back is the correction.
		position.x = minf(position.x, PortLayout.WATER_X0 + 92.0)
		_go_overboard()
		return
	# Put them down somewhere they can stand.
	position.x = clampf(position.x, PortLayout.YARD_X0, PortLayout.QUAY_X1 - 8.0)
	# Wherever they were sent, they are not there any more. Retargeting here is
	# what makes the walk back look deliberate instead of a figure teleporting to
	# resume a leg it had already finished.
	_stroll_target = position
	_stroll_pause = randf_range(0.25, 0.7)
	AudioManager.play_sfx("thunk", 0.14, -6.0)


func is_held() -> bool:
	return _held


func is_overboard() -> bool:
	return _wet != Wet.DRY


# ------------------------------------------------------------------ overboard

func _go_overboard() -> void:
	## In they go. The claim is handed back immediately: somebody in the water is
	## not conferring a stack, and a station held by a swimmer is a station the
	## rest of the shift cannot work.
	_release_task()
	_wet = Wet.SPLASH
	_wet_t = 0.0
	_drip_t = 0.0
	_stroll_pause = 0.0
	# Under the ship and the quay furniture, over the water itself.
	z_index = -2
	_land_t = 0.0
	_splash(position, true)
	AudioManager.play_sfx("splash", 0.12, -3.0)
	if _world != null:
		_world.show_world_badge(position + Vector2(4.0, -10.0), "SPLASH")


func _swim(delta: float) -> void:
	## Sink, surface, swim to the wall, climb out. One state machine, because the
	## three of them share the bob and the wake and only differ in what they do
	## with the body.
	_wet_t += delta
	match _wet:
		Wet.SPLASH:
			# Under. The sprite dips and dims rather than vanishing: a figure that
			# disappears reads as a bug, a figure sinking reads as a fall.
			var under := clampf(_wet_t / DUNK_TIME, 0.0, 1.0)
			var dip := sin(under * PI) * 5.0
			_body_offset(dip, lerpf(1.0, 0.62, sin(under * PI)))
			if _wet_t >= DUNK_TIME:
				_wet = Wet.SWIM
				_wet_t = 0.0
				_ensure_waterline()
				_splash(position, false)
		Wet.SWIM:
			var shore := Vector2(SHORE_X, position.y)
			var to_shore := shore - position
			if to_shore.length() <= 1.5:
				_wet = Wet.CLIMB
				_wet_t = 0.0
				_clear_waterline()
				AudioManager.play_sfx("thunk", 0.1, -8.0)
			else:
				var step := to_shore.normalized() * SWIM_SPEED * delta
				position += step if to_shore.length() > step.length() else to_shore
				_face_walk(to_shore)
				if _walk != null:
					# Half speed: this is a breaststroke, not a jog.
					_walk.speed_scale = 0.55
					_walk.play()
				_body_offset(3.0 + sin(_wet_t * 7.0) * SWIM_BOB, 0.78)
				_wake_t -= delta
				if _wake_t <= 0.0:
					_wake_t = 0.16
					_wake(position)
		Wet.CLIMB:
			# Out over the wall: they rise the last few pixels and land on the
			# apron, which is the same squash a drop uses.
			var out := clampf(_wet_t / CLIMB_TIME, 0.0, 1.0)
			position.x = lerpf(SHORE_X, PortLayout.QUAY_X1 - 13.0, out)
			_body_offset(lerpf(3.0, -2.0, out) * (1.0 - out), 1.0)
			if _wet_t >= CLIMB_TIME:
				_wet = Wet.DRY
				_drip_t = DRIP_TIME
				z_index = _grab_home_z
				_land_t = LAND_TIME
				_stroll_target = position
				_stroll_pause = randf_range(0.4, 0.9)
				if _walk != null:
					_walk.speed_scale = 1.0
				_body_offset(0.0, 1.0)
	_sync_hat()


func _body_offset(dip: float, tone: float) -> void:
	## How deep in the water the figure is drawn, and how much of the daylight
	## reaches them down there.
	if _walk == null:
		return
	_walk.offset.y = dip
	_walk.modulate = Color(lerpf(0.62, 1.0, tone), lerpf(0.74, 1.0, tone),
		lerpf(0.98, 1.0, tone))
	if _waterline != null and is_instance_valid(_waterline):
		_waterline.position = Vector2(4.0, 8.0 + dip)


func _drip(delta: float) -> void:
	## The walk back, wet. Three seconds of drops off the hem is the only thing
	## that says the swim happened to *them* rather than to the water.
	_drip_t -= delta
	if not UserPreferences.can_animate():
		return
	if randf() > delta * 7.0:
		return
	var drop := Sprite2D.new()
	drop.texture = preload("res://assets/sprites/prop_puddle.png")
	drop.centered = true
	drop.scale = Vector2(0.2, 0.2)
	drop.modulate = Color(0.42, 0.66, 0.82, 0.7)
	drop.z_index = -3
	drop.position = position + Vector2(randf_range(0.0, 8.0), 11.0)
	_effect_layer().add_child(drop)
	var fade := drop.create_tween()
	fade.tween_property(drop, ^"modulate:a", 0.0, 1.6)
	fade.tween_callback(drop.queue_free)


func _effect_layer() -> Node:
	## Splashes belong to the water, not to the swimmer: parented to the actor
	## they would follow them to shore and climb out too.
	var parent := get_parent()
	return parent if parent != null else self


func _splash(where: Vector2, big: bool) -> void:
	var layer := _effect_layer()
	var burst := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", SPLASH_FPS)
	frames.set_animation_loop(&"default", false)
	var sheet: Texture2D = preload("res://assets/sprites/prop_splash.png")
	for frame in int(SPLASH_FRAMES):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(frame * 20, 0, 20, 14)
		frames.add_frame(&"default", atlas)
	burst.sprite_frames = frames
	burst.position = where + Vector2(4.0, 8.0)
	burst.z_index = -1
	burst.scale = Vector2(1.4, 1.4) if big else Vector2.ONE
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(burst)
	burst.play()
	# The splash owns its own lifetime, on a tween bound to itself, rather than
	# on `animation_finished`. That signal never arrives from a looping
	# animation, and every splash stayed on the water for the rest of the
	# session — a ring of foam parked where somebody went in an hour ago. A tween
	# on the node dies with the node, so this cannot outlive it or double-free.
	var life := burst.create_tween()
	life.tween_interval(SPLASH_FRAMES / SPLASH_FPS)
	life.tween_callback(burst.queue_free)
	if not big or not UserPreferences.can_animate():
		return
	# Two rings running out from the entry point. The splash says something hit
	# the water; the rings say how hard.
	for ring_index in 2:
		var ring := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(60, 0, 20, 14)
		ring.texture = atlas
		ring.position = burst.position
		ring.z_index = -2
		ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ring.modulate = Color(0.86, 0.95, 1.0, 0.75)
		layer.add_child(ring)
		var spread := ring.create_tween().set_parallel()
		spread.tween_property(ring, ^"scale", Vector2(2.6 + ring_index, 1.9),
			0.7 + ring_index * 0.25).from(Vector2(0.6, 0.5))
		spread.tween_property(ring, ^"modulate:a", 0.0,
			0.7 + ring_index * 0.25)
		spread.chain().tween_callback(ring.queue_free)


func _wake(where: Vector2) -> void:
	## What they leave behind them. Without it a swimmer is a sprite sliding
	## across a shader.
	if not UserPreferences.can_animate():
		return
	var foam := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/foam_sheet.png")
	atlas.region = Rect2(randi() % 4 * 16, 0, 16, 6)
	foam.texture = atlas
	foam.position = where + Vector2(6.0, 10.0)
	foam.z_index = -3
	foam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	foam.modulate = Color(1, 1, 1, 0.6)
	_effect_layer().add_child(foam)
	var fade := foam.create_tween().set_parallel()
	fade.tween_property(foam, ^"modulate:a", 0.0, 0.9)
	fade.tween_property(foam, ^"scale", Vector2(0.5, 0.5), 0.9)
	fade.chain().tween_callback(foam.queue_free)


func _ensure_waterline() -> void:
	## Foam around the middle of them, drawn over the sprite: it is what turns a
	## figure standing on the sea into a figure *in* it, and it costs one sprite.
	if _waterline != null and is_instance_valid(_waterline):
		return
	_waterline = Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/sprites/foam_sheet.png")
	atlas.region = Rect2(0, 0, 16, 6)
	_waterline.texture = atlas
	_waterline.centered = true
	_waterline.position = Vector2(4.0, 11.0)
	_waterline.z_index = 2
	_waterline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_waterline.modulate = Color(0.92, 0.98, 1.0, 0.9)
	add_child(_waterline)


func _clear_waterline() -> void:
	if _waterline != null and is_instance_valid(_waterline):
		_waterline.queue_free()
	_waterline = null


func _ensure_grab_shadow() -> void:
	## A worker never had one, and every other object in the yard does. It earns
	## its place twice: it seats the figure on the apron while they walk, and it
	## is the only thing that says how far off the ground they are while they are
	## being carried.
	if _grab_shadow != null and is_instance_valid(_grab_shadow):
		return
	_grab_shadow = Sprite2D.new()
	_grab_shadow.texture = load("res://assets/sprites/prop_shadow.png")
	_grab_shadow.centered = true
	_grab_shadow.position = Vector2(4.5, 11.0)
	_grab_shadow.scale = GRAB_SHADOW_SCALE
	_grab_shadow.modulate = Color(0.06, 0.05, 0.09, 0.36)
	add_child(_grab_shadow)
	move_child(_grab_shadow, 0)


func _dangle(delta: float) -> void:
	## Everything about being held is a blend, so grabbing and dropping are the
	## same animation run in opposite directions and neither one pops.
	var target := 1.0 if _held else 0.0
	if not UserPreferences.can_animate():
		_grab_blend = target
	else:
		_grab_blend = move_toward(_grab_blend, target, delta * GRAB_BLEND_RATE)
	if _land_t > 0.0:
		_land_t = maxf(0.0, _land_t - delta)

	var k := _grab_blend
	var grown := lerpf(1.0, GRAB_SCALE, k)
	# The landing squash, which is the whole difference between a sprite being
	# repositioned and a person being dropped.
	var squash := sin(_land_t / LAND_TIME * PI) * 0.22 if _land_t > 0.0 else 0.0
	_sprite.scale = Vector2(grown * (1.0 + squash), grown * (1.0 - squash))
	_sprite.offset = Vector2(GRAB_PIVOT_X * k, 0.0)
	_sprite.position.y = -(GRAB_FRAME_H * GRAB_SCALE + GRAB_CLEARANCE) * k
	# A swing from the scruff, and a faster jitter across it. The swing alone
	# reads as a pendulum; the jitter is what reads as somebody objecting.
	_sprite.position.x = sin(_t * 19.0) * 1.3 * k
	_sprite.rotation = sin(_t * 12.0) * GRAB_SWING * k
	if _grab_shadow != null and is_instance_valid(_grab_shadow):
		# Rising off the ground spreads the shadow and thins it, which is the only
		# thing on screen that says how far up they are.
		_grab_shadow.modulate.a = lerpf(0.36, 0.2, k)
		_grab_shadow.scale = GRAB_SHADOW_SCALE * lerpf(1.0, 1.3, k)
	if _held and _walk != null:
		# Facing the viewer and kicking. Held by the scruff, nobody keeps walking
		# in the direction they were pointed.
		_walk.animation = &"down"
		_walk.speed_scale = 2.4
		_walk.play()
	elif _walk != null:
		_walk.speed_scale = 1.0
	_sync_hat()


func is_person() -> bool:
	## Somebody standing in the yard on their own two feet.
	##
	## A crewed machine is still a machine. Inspecting by `is_crew` meant every
	## reach stacker, transtêiner, portêiner and tug on the terminal was a
	## personnel card waiting to open, so touching equipment popped a dossier the
	## player never asked for. Their crew is still reachable — the journal's
	## EQUIPE tab is the whole shift in one list, which is where you go to read
	## about somebody you cannot walk up to.
	return profile != null and _walk != null


func _exit_tree() -> void:
	if _world == null:
		return
	if not _job_data.is_empty():
		_world.cancel_job(_job_data)
		_job_data = {}
	_release_task()
	if _world.traffic != null:
		_world.traffic.leave(self)


# ------------------------------------------------------------------ the person

func _board() -> TaskBoard:
	return _world.tasks if _world != null else null


func _release_task() -> void:
	## Hand the claim back without crediting it. Used when the actor is torn down
	## or gives up: the station has to reopen or nobody else can work it.
	var board := _board()
	if board != null:
		board.release(self)
	_task = {}


func _complete_task() -> void:
	var board := _board()
	if board != null:
		board.complete(self)
	_task = {}


func _count_move() -> void:
	## One box on this operator's tally. Cranes and transtainers work continuously
	## while their station is claimed, so they count moves rather than completing
	## and re-claiming the same seat several times a second.
	if _world != null and _world.crew != null:
		_world.crew.record_move(profile)


func objective_text() -> String:
	## A relay leg is a real job and has to read as one on the operator's card.
	## It is not a task-board claim — the board hands out *places*, and a leg is
	## a box — so it is answered here rather than there.
	if _relay_stage != RELAY_NONE:
		return "carreta: berço ↔ bloco"
	var board := _board()
	if board == null:
		return ""
	return board.label_of(self)


func stage_text() -> String:
	match _job:
		Job.RELAY_FETCH: return "a caminho da caixa"
		Job.RELAY_CARRY: return "carregado"
		Job.RELAY_HOLD: return "entregando"
		Job.RELAY_HOME: return "voltando ao pátio"
		_: pass
	var board := _board()
	if board == null or _task.is_empty():
		return ""
	return board.stage_text(_task.get("stage", TaskBoard.STAGE_TO_TARGET))


func hit_test(world_pos: Vector2) -> bool:
	## Only people on foot are inspectable, and only while they are on site.
	if not is_person() or not visible:
		return false
	var half := _touch_half()
	return Rect2(global_position + _touch_centre() - half,
		half * 2.0).has_point(world_pos)


func _touch_centre() -> Vector2:
	if _walk != null:
		return Vector2(4.5, 6.0)
	var sprite := _sprite as Sprite2D
	if sprite != null and sprite.texture != null and not sprite.centered:
		return sprite.texture.get_size() * 0.5 * sprite.scale
	return Vector2.ZERO


func _touch_half() -> Vector2:
	var sprite := _sprite as Sprite2D
	if _walk != null or sprite == null or sprite.texture == null:
		return TOUCH_HALF
	var half := sprite.texture.get_size() * sprite.scale * 0.5
	return Vector2(maxf(TOUCH_HALF.x, half.x), maxf(TOUCH_HALF.y, half.y))


# ---------------------------------------------------------------- building

func _build() -> void:
	match id:
		"estivador":
			_build_worker()
		"empilhadeira":
			_build_vehicle("veh_forklift", 34.0)
		"tt":
			_build_vehicle("veh_tt", 46.0)
		"reach_stacker":
			_build_vehicle("veh_reach_stacker", 30.0)
		"rtg":
			_build_rtg()
		"sts":
			_build_sts()
		"rebocador":
			_build_boat("veh_tug", 16.0)
		"trem":
			_build_rail_gantry()
		"flutuante":
			_build_static("flutuante")
		"drone":
			_build_drone()
		"armazem":
			_build_static("bld_warehouse")
		"alfandega":
			_build_customs()
		"torre":
			_build_tower()
		"porto_ia":
			_build_static("bld_ai_hub")
		"portal":
			_build_portal()
		_:
			_build_static("bld_office")


func _sprite2d(sprite_name: String, centered: bool = false) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/sprites/%s.png" % sprite_name)
	spr.centered = centered
	return spr


func _anim(sheet_name: String, count: int, fw: int, fh: int, fps: float,
		centered: bool = false) -> AnimatedSprite2D:
	var spr := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	var tex: Texture2D = load("res://assets/sprites/%s.png" % sheet_name)
	frames.set_animation_speed(&"default", fps)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		frames.add_frame(&"default", at)
	spr.sprite_frames = frames
	spr.centered = centered
	spr.frame = randi() % count
	spr.play()
	return spr


func _add_shadow(w: float, h: float, offset := Vector2.ZERO) -> void:
	_shadow = _sprite2d("prop_shadow")
	_shadow.centered = true
	_shadow.scale = Vector2(w / 32.0, h / 20.0)
	_shadow.modulate.a = 0.4
	_shadow.position = offset
	_shadow.z_index = -1
	add_child(_shadow)


func _build_static(sprite_name: String) -> void:
	var tex: Texture2D = load("res://assets/sprites/%s.png" % sprite_name)
	_add_shadow(tex.get_width() + 4, 12.0,
		Vector2(tex.get_width() / 2.0, tex.get_height() - 2.0))
	_sprite = _sprite2d(sprite_name)
	add_child(_sprite)


func _build_worker() -> void:
	## worker_sheet is 4 side frames, then 4 walking down, then 4 walking up.
	## Playing it as one 12-frame strip made the figure flicker between facings
	## every seventh of a second; each direction is its own animation now.
	_walk = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	var tex: Texture2D = load("res://assets/sprites/worker_sheet.png")
	for pair in [["side", 0], ["down", 4], ["up", 8]]:
		var anim := StringName(pair[0])
		if anim != &"default":
			frames.add_animation(anim)
		frames.set_animation_speed(anim, 7.0)
		for i in 4:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((int(pair[1]) + i) * 9, 0, 9, 12)
			frames.add_frame(anim, at)
	frames.remove_animation(&"default")
	_walk.sprite_frames = frames
	_walk.centered = false
	_walk.animation = &"side"
	_walk.frame = randi() % 4
	_walk.play()
	_sprite = _walk
	add_child(_walk)
	_ensure_grab_shadow()
	if profile != null and profile.wears_special_hat():
		_build_hat()
	_speed = randf_range(11.0, 17.0)
	_stroll_pause = randf_range(0.2, 2.5)


func _build_hat() -> void:
	## A helmet the player can pick out of the yard from across the terminal.
	##
	## `worker_hat` is the same twelve frames as the body with nothing but the
	## helmet on them, drawn in greys, so modulating it produces a properly shaded
	## helmet in any colour instead of a flat blob. It is never played: its frame
	## is copied from the body every tick, which is the only way the two can never
	## drift apart.
	_hat = AnimatedSprite2D.new()
	_hat.centered = false
	add_child(_hat)
	# No `animation` until `_dress_hat` has built the frames: naming an animation
	# an `AnimatedSprite2D` does not have yet is an error per worker per rebuild.
	_dress_hat()
	EventBus.cosmetics_changed.connect(_dress_hat)


func _dress_hat() -> void:
	## Which hat, and what colour. Both are decorations now — the shelf can put
	## the whole yard in party cones or in gold — so this is rebuilt on the
	## signal rather than only at construction.
	##
	## Party beats gold when both are owned and on. They are the same slot, and
	## the funnier one is the one somebody switched on to look at.
	if _hat == null or profile == null:
		return
	var party := GameState.cosmetic_on(&"party_hats")
	var sheet := "worker_hat_party" if party else "worker_hat"
	if str(_hat.get_meta("sheet", "")) != sheet:
		_hat.set_meta("sheet", sheet)
		var frames := SpriteFrames.new()
		var tex: Texture2D = load("res://assets/sprites/%s.png" % sheet)
		for pair in [["side", 0], ["down", 4], ["up", 8]]:
			var anim := StringName(pair[0])
			if anim != &"default":
				frames.add_animation(anim)
			for i in 4:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2((int(pair[1]) + i) * 9, 0, 9, 12)
				frames.add_frame(anim, at)
		frames.remove_animation(&"default")
		_hat.sprite_frames = frames
		_hat.animation = &"side"
	if party:
		# A cone per person, from their own identity, so a gang in party hats is
		# eight colours rather than eight of one.
		_hat.modulate = Color.from_hsv(
			fposmod(float(profile.uid.hash() % 360) / 360.0, 1.0), 0.62, 1.0)
	elif GameState.cosmetic_on(&"gold_hats"):
		_hat.modulate = Color8(248, 206, 92)
	else:
		_hat.modulate = profile.hat_color
	_sync_hat()


func _sync_hat() -> void:
	if _hat == null or _walk == null:
		return
	_hat.animation = _walk.animation
	_hat.frame = _walk.frame
	_hat.flip_h = _walk.flip_h
	_hat.position = _walk.position
	# The helmet is a separate sprite that copies the body every tick, so it has
	# to copy the whole transform. Being lifted was the first thing to move the
	# body without moving the head.
	_hat.scale = _walk.scale
	_hat.rotation = _walk.rotation
	_hat.offset = _walk.offset


func _build_vehicle(sprite_name: String, speed: float) -> void:
	_add_shadow(15.0, 9.0, Vector2(0, 6))
	_sprite = _sprite2d(sprite_name, true)
	_sprite.scale = Vector2(0.70, 0.70)
	add_child(_sprite)
	_speed = speed
	_cargo = _container_sprite()
	_cargo.centered = true
	_cargo.scale = Vector2(0.70, 0.70)
	_cargo.visible = false
	add_child(_cargo)
	# Off-site until something puts it somewhere: a parking rank (`set_depot`)
	# for terminal plant, or a job driving in off the public road for the rest.
	visible = false


func _build_boat(sprite_name: String, speed: float) -> void:
	_boat_fx = Node2D.new()
	_boat_fx.name = "BoatFX"
	_boat_fx.z_index = -1
	add_child(_boat_fx)
	_boat_wake = _anim("foam_sheet", 4, 16, 6, 6.0, true)
	_boat_wake.name = "PropWash"
	_boat_wake.position = Vector2(0.0, 18.0)
	_boat_wake.scale = Vector2(0.82, 1.15)
	_boat_wake.modulate = Color(0.78, 0.94, 1.0, 0.24)
	_boat_fx.add_child(_boat_wake)
	_sprite = _sprite2d(sprite_name, true)
	_sprite.scale = Vector2(0.70, 0.70)
	add_child(_sprite)
	_add_boat_light(Vector2(0.0, -12.0), Color8(255, 247, 214), 0.065)
	_add_boat_light(Vector2(-5.0, -2.0), Color8(255, 48, 42), 0.052)
	_speed = speed
	_vertical = true


func _add_boat_light(pos: Vector2, color: Color, glow_scale: float) -> void:
	var glow := Sprite2D.new()
	glow.texture = preload("res://assets/sprites/prop_glow.png")
	glow.position = pos
	glow.scale = Vector2.ONE * glow_scale
	glow.modulate = color
	glow.modulate.a = 0.0
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	_boat_fx.add_child(glow)
	_boat_glows.append(glow)


func _build_rtg() -> void:
	_sprite = _sprite2d("rtg")
	add_child(_sprite)
	_extra = _sprite2d("rtg_trolley")
	add_child(_extra)
	_spreader = _sprite2d("spreader")
	_spreader.visible = false
	add_child(_spreader)
	_cargo = _container_sprite()
	_cargo.visible = false
	add_child(_cargo)


func _build_sts() -> void:
	var beam := _sprite2d("sts_beam")
	beam.position = Vector2(-44, 15)
	add_child(beam)
	_sprite = _sprite2d("sts_base")
	add_child(_sprite)
	_extra = _sprite2d("sts_trolley")
	add_child(_extra)
	_spreader = _sprite2d("spreader")
	_spreader.visible = false
	add_child(_spreader)
	_cargo = _container_sprite()
	_cargo.visible = false
	add_child(_cargo)


func _build_rail_gantry() -> void:
	## The machine that works a train, and the reason a rake is a delivery rather
	## than a decoration.
	##
	## What the player buys as the *Ramal Ferroviário* used to be the train
	## itself: a rake of sprites that ran in, showed some boxes and ran out again
	## without a container ever changing hands. The train now belongs to
	## `RailYard`, which brings real cargo and needs somebody to lift it, so the
	## structure is the rail-mounted gantry that stands over the running line and
	## does that lifting.
	##
	## The portal art is the transtainer's, turned a quarter: it is drawn
	## straddling a north-south block, and the branch runs east-west. Turning it
	## puts a leg either side of the track and the trolley across the wagons,
	## which is exactly the machine an intermodal ramp has.
	_sprite = _sprite2d("rtg", true)
	_sprite.rotation = PI / 2.0
	add_child(_sprite)
	_extra = _sprite2d("rtg_trolley", true)
	_extra.rotation = PI / 2.0
	add_child(_extra)
	_spreader = _sprite2d("rtg_spreader", true)
	_spreader.rotation = PI / 2.0
	_spreader.visible = false
	add_child(_spreader)
	_cargo = _container_sprite()
	_cargo.centered = true
	_cargo.rotation = PI / 2.0
	_cargo.visible = false
	add_child(_cargo)
	position.x = PortLayout.rail_west_turnout_x() + 24.0


func _build_drone() -> void:
	_sprite = _anim("veh_drone", 2, 18, 18, 16.0, true)
	_sprite.scale = Vector2(0.70, 0.70)
	add_child(_sprite)
	_add_shadow(9.0, 6.0, Vector2(2, 14))


func _build_customs() -> void:
	_build_static("bld_customs")
	_extra = _sprite2d("bld_customs_arm")
	_extra.position = Vector2(26, 10)
	add_child(_extra)


func _build_tower() -> void:
	_build_static("bld_tower")
	_extra = _sprite2d("bld_tower_radar", true)
	_extra.position = Vector2(14, 14)
	add_child(_extra)


func _build_portal() -> void:
	_add_shadow(32.0, 12.0, Vector2(17, 32))
	_sprite = _anim("bld_portal", 3, 34, 34, 6.0)
	add_child(_sprite)


func _container_sprite() -> Sprite2D:
	var spr := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = CONTAINERS
	at.region = Rect2((randi() % 8) * 24, 0, 24, 13)
	spr.texture = at
	spr.centered = false
	return spr


func _set_cargo_color(color_idx: int) -> void:
	var at := _cargo.texture as AtlasTexture
	if at != null:
		at.region = Rect2(color_idx * 24, 0, 24, 13)


# ---------------------------------------------------------------- placement

func set_lane(lane_y: float, vertical: bool = false, lane_x: float = 0.0) -> void:
	_lane_y = lane_y
	_lane_x = lane_x
	_vertical = vertical


func set_block(origin: Vector2, block_index: int = -1) -> void:
	_block_origin = origin
	_block_index = block_index


# ------------------------------------------------------------------ process

func _process(delta: float) -> void:
	_t += delta
	_pulse_upgrade_marks()
	# Held, or still settling after being dropped. The round they were walking is
	# a claim off the board and stays claimed, so nothing else takes their work
	# while they are in the air.
	if _held or _grab_blend > 0.0 or _land_t > 0.0:
		_dangle(delta)
		if _held:
			return
	# In the water, nothing else applies: they are not conferring, hauling or
	# claiming anything until they are back on the wall.
	if _wet != Wet.DRY:
		_swim(delta)
		return
	if _drip_t > 0.0:
		_drip(delta)
	match id:
		"estivador":
			_walk_lane(delta)
		"empilhadeira", "tt", "reach_stacker":
			_run_job(delta)
		"rebocador":
			_claim_manoeuvre(delta)
			_patrol_water(delta)
		"trem":
			_run_rail_gantry(delta)
		"drone":
			_fly(delta)
		"rtg":
			_rtg_cycle(delta)
		"sts":
			_sts_cycle(delta)
		"torre":
			if _extra != null:
				_extra.rotation = _t * 1.1
		"alfandega":
			_claim_gate(delta)
			if _extra != null:
				_extra.rotation = -0.9 + absf(sin(_t * 0.5)) * 0.9
		"flutuante":
			# Riding the swell on whole pixels and never tilting: pixel art turned
			# by a degree is resampled, and the barge's lattice boom shimmered
			# like a heat haze the whole time it was afloat.
			position.y = roundf(_lane_y + sin(_t * 0.7 + _phase) * 3.0)
	if id == "rebocador":
		_update_boat_fx()


# ---------- haulers ----------

func _run_job(delta: float) -> void:
	match _job:
		Job.IDLE:
			_idle_at_depot(delta)
			_cooldown -= delta
			if _cooldown <= 0.0:
				_try_take_job()
		Job.WORKING:
			_work_timer -= delta
			# little lift bob while the spreader does its thing
			_sprite.position.y = -sin(maxf(0.0, _work_timer) * 6.0) * 1.5
			if _work_timer <= 0.0:
				_finish_work()
		Job.RELAY_HOLD:
			# Set down at the hand-off. The relay decides when this run is over,
			# because only it knows whether the next machine has the box yet.
			_sprite.position.y = sin(_t * 9.0 + _phase) * 0.35
		_:
			_follow_waypoints(delta)


func _idle_at_depot(delta: float) -> void:
	## Parked, and visibly so. The engine idles — a couple of pixels of shudder —
	## because a rank of perfectly still vehicles reads as scenery, and these are
	## the machines the player just paid for.
	if _depot == Vector2.ZERO:
		return
	if position.distance_to(_depot) > 1.5:
		# Off its space — the yard grew under it, or a run ended somewhere else.
		# Drive back rather than following an empty waypoint list, which reads as
		# "job finished" and would park the machine off-map.
		if _waypoints.is_empty():
			_go_home()
		return
	_sprite.position.y = sin(_t * 9.0 + _phase) * 0.35


func _try_take_job() -> void:
	if id == "tt":
		# The terminal tractor works inside the fence and nowhere else — it is a
		# yard machine with no road plates, which its own catalogue entry says out
		# loud. Its work is relay legs; between them it stands on the rank.
		_cooldown = 0.6
		return
	if _world == null:
		_cooldown = 1.0
		return
	var entry := PortLayout.gate_entry()
	# Check the shared gate before request_job reserves an EXPORT landing.
	if _world.traffic != null and not _world.traffic.gate_clear(self, entry):
		_cooldown = 0.4
		return
	# The board hands out the land-side station, and it is what stops two drivers
	# being sent to the same stack — the second used to arrive to find the box
	# already gone and drive home with an empty chassis. A world without a board
	# (a focused harness) dispatches straight from the yard, exactly as before.
	var board := _board()
	var job: Dictionary = {}
	if board != null:
		_task = board.claim_haul(self)
		job = _task.get("job", {}) as Dictionary
	else:
		job = _world.request_job()
	if job.is_empty():
		_cooldown = randf_range(1.5, 3.5)
		return

	var target: Vector2 = job.pos
	var lane_y := PortLayout.nearest_lane(target.y + 6.0)
	var lane_key := "lane_%d" % roundi(lane_y)
	# A driving lane is a dead end: the hauler has to reverse back out of it.
	# Taking one that is already occupied is the only way two vehicles could
	# ever meet head-on, so the job is handed straight back if it is busy.
	if _world.traffic != null and not _world.traffic.reserve_lane(self, lane_key):
		_world.cancel_job(job)
		_release_task()
		_cooldown = randf_range(0.5, 1.2)
		return
	if _world.traffic != null:
		_world.traffic.join(self)
	_lane_key = lane_key
	_job_data = job
	_carrying = job.type == "deliver"
	_cargo.visible = _carrying
	if _carrying:
		_set_cargo_color(job.color)

	position = entry
	_cruise = 0.0
	_facing = 0.0
	visible = true
	_waypoints = [
		Vector2(PortLayout.ROAD_IN_X, lane_y),
		Vector2(target.x + PortLayout.BOX_W * 0.5, lane_y),
	]
	_job = Job.ENTERING


func _follow_waypoints(delta: float) -> void:
	if _waypoints.is_empty():
		_on_waypoints_done()
		return
	var target: Vector2 = _waypoints[0]
	var delta_v := target - position
	# Pull up to the last waypoint rather than stopping dead on it: a vehicle
	# arriving at a stack should be seen slowing into it.
	var wanted := _speed
	if _waypoints.size() == 1:
		wanted = _speed * clampf(delta_v.length() / BRAKE_DISTANCE, 0.22, 1.0)
	_cruise = move_toward(_cruise, wanted,
		(ACCELERATION if wanted > _cruise else BRAKING) * delta)
	var step := _cruise * delta
	if delta_v.length() <= step:
		position = target
		_waypoints.pop_front()
		if _waypoints.is_empty():
			_on_waypoints_done()
		return
	var dir := delta_v.normalized()
	# Hold station behind whatever is in front. Every shared stretch of road is
	# one-way, so waiting here always resolves — the vehicle ahead is never
	# waiting on this one. The stall timer is a belt-and-braces guard: a hauler
	# frozen on a lane it has reserved would starve every other hauler, so it
	# gives up the job rather than hold the terminal hostage.
	if _world != null and _world.traffic != null \
			and not _world.traffic.can_advance(self, position + dir * step):
		_cruise = move_toward(_cruise, 0.0, BRAKING * delta)
		_face(dir, delta)
		_stalled += delta
		if _stalled > STALL_TIMEOUT:
			if _job in [Job.RELAY_FETCH, Job.RELAY_CARRY]:
				_abandon_relay()
			else:
				_abandon_job()
		return
	_stalled = 0.0
	position += dir * step
	_face(dir, delta)


func _face(dir: Vector2, delta: float = 0.0) -> void:
	## The target heading is still one of four, because the sprites only have
	## four sides. Turning *into* it takes time, though — snapping through 90
	## degrees in one frame is why the yard looked like sliding boxes.
	##
	## Every vehicle here is drawn nose-up — the tractor's windscreen, the
	## forklift's forks and the stacker's boom are all at the top of their
	## sprite — so north is rotation zero. The vertical case used to be the
	## other way round, which drove the whole fleet up and down the yard in
	## reverse.
	var wanted: float
	if absf(dir.x) > absf(dir.y):
		wanted = PI / 2.0 if dir.x > 0.0 else -PI / 2.0
	else:
		wanted = PI if dir.y > 0.0 else 0.0
	if delta <= 0.0:
		_facing = wanted
	else:
		_facing = rotate_toward(_facing, wanted, TURN_RATE * delta)
	_sprite.rotation = _facing
	if _shadow != null:
		_shadow.rotation = _facing
	if _cargo != null:
		_cargo.rotation = _facing


# ----------------------------------------------------------------- the relay
## A `CargoRelay` owns one container's itinerary and hands each leg to a real
## machine. Two kinds of machine answer: a wheeled one *carries* the box, so it
## leads the leg and the box rides its chassis; a gantry *shadows* the box, so
## the relay leads and the trolley tracks it. Either way the machine can hand the
## run back at any moment — the relay's fallback is the plain arc, so refusing is
## always safe and never loses cargo.

func take_relay_haul(from: Vector2, to: Vector2) -> bool:
	## Accept a ride: drive empty to `from`, pick the box up, drive it to `to`.
	if not is_hauler() or not is_free_for_relay():
		return false
	_release_task()
	_relay_stage = RELAY_APPROACH
	_relay_to = to
	_carrying = false
	_cargo.visible = false
	_stalled = 0.0
	visible = true
	_job = Job.RELAY_FETCH
	_waypoints = _corridor_route(position, from)
	return true


func mirror_relay(from: Vector2, to: Vector2, seconds: float) -> bool:
	## Accept a shadow: for `seconds`, put this gantry's spreader wherever the box
	## is. The trolley is clamped to its own reach, so a crane that cannot quite
	## stretch to a far bay leans as far as it goes instead of detaching.
	if not is_gantry() or not is_free_for_relay():
		return false
	_relay_mirror = {"from": from, "to": to,
		"dur": maxf(0.1, seconds), "t": 0.0}
	_relay_stage = RELAY_CARRY
	_gantry_idle = false
	return true


func relay_stage() -> int:
	return _relay_stage


func relay_bed_position() -> Vector2:
	## Where the box sits on this machine. Centred on the chassis: these are
	## 11-pixel vehicles carrying a 24-pixel box, so any offset reads as the load
	## hanging off the back.
	return position


func relay_bed_rotation() -> float:
	## A container on a chassis lies along the direction of travel, always. The
	## sprite is drawn 24x13 — lengthwise east-west — so a machine heading north
	## carries it a quarter turn round. Without this the box stays landscape while
	## the tractor under it turns, and a hand-off reads as a box sliding on ice.
	return _facing + PI / 2.0


func is_free_for_relay() -> bool:
	if _relay_stage != RELAY_NONE or _held:
		return false
	if is_gantry():
		return _berth_move.is_empty() and _relay_mirror.is_empty()
	return _job == Job.IDLE


func is_gantry() -> bool:
	return id == "sts" or id == "rtg" or id == "flutuante"


func is_idle_at_home() -> bool:
	## Safe to move by hand. A relayout after buying land must never teleport a
	## machine that is halfway through a run with a container on it.
	return _job == Job.IDLE and _relay_stage == RELAY_NONE


func release_relay() -> void:
	## The relay is done with this machine — either the box moved on, or the whole
	## itinerary collapsed. A carrier drives home; a gantry parks.
	_relay_stage = RELAY_NONE
	_relay_mirror = {}
	if not is_hauler():
		return
	_carrying = false
	if _cargo != null:
		_cargo.visible = false
	if _job in [Job.RELAY_FETCH, Job.RELAY_CARRY, Job.RELAY_HOLD]:
		_go_home()


func _go_home() -> void:
	## Back to the rank if this machine lives in the terminal, out through the
	## gate if it does not. A reach stacker called in for one lift is a visitor;
	## the terminal tractor is staff.
	_job = Job.RELAY_HOME
	_waypoints = _corridor_route(position, _depot) if _depot != Vector2.ZERO \
		else _road_exit_route(position)
	if _world != null and _world.traffic != null:
		_world.traffic.join(self)


func _road_exit_route(from: Vector2) -> Array[Vector2]:
	## The way out is the way any vehicle leaves: down a driving lane to the
	## carriageway, then north up the outbound side past the gate.
	var lane := PortLayout.nearest_lane(from.y)
	var spine := PortLayout.interchange_spine_x()
	var route: Array[Vector2] = []
	if absf(from.y - lane) > 1.0:
		route.append(Vector2(spine, from.y))
		route.append(Vector2(spine, lane))
	route.append(Vector2(PortLayout.ROAD_OUT_X, lane))
	route.append(PortLayout.gate_exit())
	return route


func set_depot(home: Vector2) -> void:
	## Giving a machine a rank is what puts it on the map for good. Everything
	## with one is visible whether or not it currently has a box, which is the
	## whole difference between "I bought a tractor" and "nothing happened".
	_depot = home
	visible = true


func _corridor_route(from: Vector2, to: Vector2) -> Array[Vector2]:
	## Never the diagonal. A tractor uses the apron to change block row and the
	## driving lane to reach the block, because those are the only two stretches
	## of this terminal that are actually road — cutting the corner drives it
	## straight over other people's stacks.
	##
	## The fence is a third stretch this has to respect and used to not: a
	## road-plated hauler's home is `PortLayout.gate_entry()`, off-site and
	## north of `FENCE_Y`, so its first relay leg starts on the wrong side of a
	## wall that has exactly one gap. The plain spine route used to cross that
	## wall wherever the quay lane happens to sit — nowhere near the gate — and
	## drive the machine straight through the fence posts to prove it. A leg
	## that actually changes sides threads the gate first, at the lane it is
	## already using for one-way road traffic, and only picks up the ordinary
	## spine routing once it is on the correct side.
	if _crosses_fence(from.y, to.y):
		var gate_x := PortLayout.ROAD_IN_X if to.y > from.y else PortLayout.ROAD_OUT_X
		var route: Array[Vector2] = [Vector2(gate_x, from.y), Vector2(gate_x, to.y)]
		route.append_array(_corridor_route(Vector2(gate_x, to.y), to))
		return route
	var spine := PortLayout.interchange_spine_x()
	var route: Array[Vector2] = []
	if absf(from.y - to.y) > 1.0:
		if absf(from.x - spine) > 1.0:
			route.append(Vector2(spine, from.y))
		route.append(Vector2(spine, to.y))
	route.append(to)
	return route


func _crosses_fence(y1: float, y2: float) -> bool:
	return (y1 < PortLayout.FENCE_Y) != (y2 < PortLayout.FENCE_Y)


func _abandon_relay() -> void:
	## Give the run back. The relay sees `RELAY_NONE` on its next poll and carries
	## the box itself, so a boxed-in tractor costs a nicer animation and never a
	## container.
	_relay_stage = RELAY_NONE
	_relay_mirror = {}
	_carrying = false
	if _cargo != null:
		_cargo.visible = false
	if is_hauler():
		_go_home()


func _relay_mirror_step(delta: float) -> bool:
	## Track the box for a gantry. Returns false when there is nothing to shadow,
	## which is the caller's cue to run its own idle behaviour.
	if _relay_mirror.is_empty():
		return false
	_relay_mirror["t"] = float(_relay_mirror.t) + delta
	var k: float = clampf(float(_relay_mirror.t) / float(_relay_mirror.dur),
		0.0, 1.0)
	var box: Vector2 = (_relay_mirror.from as Vector2).lerp(
		_relay_mirror.to as Vector2, _ease(k))
	var local := box - position
	# Down at both ends, up in the middle: the beat of a spreader making and
	# breaking a lock, on the same clock as the box it is holding.
	var drop: float = 7.0 * (1.0 - sin(k * PI))
	if id == "rtg":
		# The transtainer rolls along its block to meet the row it is working.
		position.y = move_toward(position.y, box.y - PortLayout.BLOCK_H * 0.5,
			38.0 * delta)
		local = box - position
		var reach := clampf(local.x, 6.0, PortLayout.BLOCK_W + 18.0)
		_extra.position = Vector2(reach - 10.0, 6.0)
		_spreader.position = Vector2(reach - 12.0, 8.0 + drop)
	else:
		var reach := clampf(local.x, STS_YARD_X, STS_SHIP_X)
		_extra.position = Vector2(reach - 2.0, 12.0)
		_spreader.position = Vector2(reach - 5.0, 18.0 + drop)
	if _spreader != null:
		_spreader.visible = true
	if _cargo != null:
		# The relay draws the box. Two copies of one container is the one thing a
		# hand-off must never look like.
		_cargo.visible = false
	if k >= 1.0:
		_relay_mirror = {}
		_relay_stage = RELAY_NONE
		_count_move()
	return true


func _on_waypoints_done() -> void:
	match _job:
		Job.RELAY_FETCH:
			# Standing over the box. It is on the ground here whether or not the
			# machine that set it down still exists.
			_relay_stage = RELAY_CARRY
			_carrying = true
			_job = Job.RELAY_CARRY
			_waypoints = _corridor_route(position, _relay_to)
			if _world != null:
				_world.spawn_dust(position + Vector2(-6, 4))
			return
		Job.RELAY_CARRY:
			_relay_stage = RELAY_DONE
			_carrying = false
			_job = Job.RELAY_HOLD
			_cruise = 0.0
			if _world != null:
				_world.spawn_dust(position + Vector2(-6, 4))
			return
		Job.RELAY_HOME:
			_job = Job.IDLE
			_cruise = 0.0
			_cooldown = randf_range(0.8, 2.4)
			visible = _depot != Vector2.ZERO
			if _world != null and _world.traffic != null:
				_world.traffic.leave(self)
			return
		Job.ENTERING, Job.TO_TARGET:
			_job = Job.WORKING
			_work_timer = 0.9
			_cruise = 0.0
			var board := _board()
			if board != null:
				board.set_stage(self, TaskBoard.STAGE_WORKING)
			# Dust where the tyres stop, so the arrival lands rather than just
			# ending.
			if _world != null:
				_world.spawn_dust(position + Vector2(-6, 4))
		Job.TO_ROAD:
			_waypoints = [PortLayout.gate_exit()]
			_job = Job.LEAVING
		Job.LEAVING:
			_end_job()
		_:
			_end_job()


func _finish_work() -> void:
	_sprite.position.y = 0.0
	var board := _board()
	if board != null:
		board.set_stage(self, TaskBoard.STAGE_RETURNING)
	if _world != null:
		if _job_data.get("type") == "pickup":
			# Other drivers' claims are excluded so the yard's "best top of stack"
			# answer cannot be somebody else's box while this one is standing at
			# the right stack.
			var box: Dictionary = _world.begin_hauler_pickup(_job_data.slot,
				board.claimed_uids_except(self) if board != null \
					else PackedStringArray())
			if not box.is_empty():
				_job_data["taken"] = box
				_job_data["traffic_token"] = str(box.get("traffic_token", ""))
				_carrying = true
				_cargo.visible = true
				var carried_unit: CargoUnit = box.get("unit")
				_set_cargo_color(carried_unit.color if carried_unit != null else 0)
		else:
			_world.complete_delivery(_job_data.slot, _job_data.level,
				_job_data.get("unit") as CargoUnit,
				str(_job_data.get("token", "")))
			_carrying = false
			_cargo.visible = false
	var lane_y := position.y
	_waypoints = [Vector2(PortLayout.ROAD_OUT_X, lane_y)]
	_job = Job.TO_ROAD


func _abandon_job() -> void:
	## Hand the cargo reservation back rather than commit it: nothing was
	## delivered, and a phantom commit would leak a container's identity. The
	## station reopens uncredited for the same reason.
	if _world != null and not _job_data.is_empty():
		_world.cancel_job(_job_data)
	_job_data = {}
	_release_task()
	_release_job_state()


func _end_job() -> void:
	if _world != null and not _job_data.is_empty():
		_world.commit_job(_job_data)
	_complete_task()
	_release_job_state()


func _release_job_state() -> void:
	_job = Job.IDLE
	_job_data = {}
	_task = {}
	_waypoints.clear()
	_lane_key = ""
	_carrying = false
	_cargo.visible = false
	# Off-site only if this machine has nowhere in the terminal to stand.
	visible = _depot != Vector2.ZERO
	if _world != null and _world.traffic != null:
		# Leaving drops both the lane and the vehicle's place in traffic: an
		# off-site hauler parked on the spawn point must not block the gate.
		_world.traffic.leave(self)
	_cooldown = randf_range(1.0, 4.0)


# ---------- other behaviours ----------

func _walk_lane(delta: float) -> void:
	## The conferente's round, and it has a reason.
	##
	## Every leg of it is a task off the board: the berth while a hull is
	## alongside, the carreta that has just parked, then the blocks that actually
	## hold stock. He walks to that place, stands there long enough to have checked
	## something, credits the job and takes the next one — and because the board
	## hands out one claim per place, the second conferente is always somewhere
	## else. This used to be a random walk between two invisible walls, which is
	## the "parece tão aleatório" the crew rework exists to answer.
	var board := _board()
	if board == null:
		_walk_idle(delta)
		return
	if _task.is_empty():
		_task = board.claim(self, NpcCatalog.STATION_YARD)
		if _task.is_empty():
			# Nothing to confer — no hull alongside, an empty yard. Walk the lane
			# rather than freeze: a figure standing perfectly still for the five
			# seconds a ship takes to berth reads as a broken sprite.
			_walk_idle(delta)
			return
		_stroll_target = _round_target(_task)
		_work_timer = 0.0
	if _work_timer > 0.0:
		_walk.pause()
		_sync_hat()
		_work_timer -= delta
		if _work_timer <= 0.0:
			# `complete` is what credits the move; counting here as well would put
			# every check on the tally twice.
			_complete_task()
			_stroll_pause = randf_range(0.3, 1.1)
		return
	if _stroll_pause > 0.0:
		_stroll_pause -= delta
		_walk.pause()
		_sync_hat()
		return
	var to_target := _stroll_target - position
	if to_target.length() < 1.5:
		_work_timer = randf_range(1.6, 3.2)
		board.set_stage(self, TaskBoard.STAGE_WORKING)
		return
	_walk.play()
	var step := to_target.normalized() * _speed * delta
	position += step if to_target.length() > step.length() else to_target
	_face_walk(to_target)


func _walk_idle(delta: float) -> void:
	## No board to take work from — a focused test harness, or a preview scene.
	## Keep the figure alive on its own lane instead of freezing it.
	if _stroll_pause > 0.0:
		_stroll_pause -= delta
		_walk.pause()
		return
	if _stroll_target == Vector2.ZERO or position.distance_to(_stroll_target) < 1.5:
		_stroll_target = Vector2(
			randf_range(PortLayout.BLOCK_X0, PortLayout.QUAY_X1 - 14.0), _lane_y)
		_stroll_pause = randf_range(0.8, 3.4)
		return
	_walk.play()
	var to_target := _stroll_target - position
	var step := to_target.normalized() * _speed * delta
	position += step if to_target.length() > step.length() else to_target
	_face_walk(to_target)


func _face_walk(to_target: Vector2) -> void:
	if absf(to_target.x) > absf(to_target.y):
		_walk.animation = &"side"
		_walk.flip_h = to_target.x < 0.0
	else:
		_walk.animation = &"down" if to_target.y > 0.0 else &"up"
		_walk.flip_h = false
	_sync_hat()


func _round_target(task: Dictionary) -> Vector2:
	## Stand *beside* the work, never on it: a figure inside a stack or in a
	## driving lane reads as a bug even when the task behind it is sound.
	var where: Vector2 = task.get("where", position)
	where += Vector2(randf_range(-5.0, 5.0), randf_range(-3.0, 3.0))
	return Vector2(
		clampf(where.x, PortLayout.BLOCK_X0 - 6.0, PortLayout.QUAY_X1 - 12.0),
		clampf(where.y, PortLayout.TOP_MARGIN, PortLayout.world_bottom() - 20.0))


func _patrol_water(delta: float) -> void:
	var ship: Ship = _world.manoeuvring_ship() if _world != null else null
	if ship == null:
		var alongside := _world.working_ships() if _world != null else [] as Array[Ship]
		ship = alongside[0] if not alongside.is_empty() else null
	if ship != null and ship.visible and (
			ship.phase == Ship.Phase.ARRIVING or ship.phase == Ship.Phase.DEPARTING):
		z_index = 7
		var target := _tug_formation_target(ship)
		# On arrival the whole formation begins below the visible world. Put the
		# tug in station there instead of making it teleport through the quay
		# several seconds later when it finally catches the hull.
		if not _escort_active and target.y > PortLayout.world_bottom() + 28.0:
			position = target
		_escort_active = true
		_drive_boat_toward(target, TUG_ESCORT_SPEED, delta)
		return
	_escort_active = false
	z_index = 5
	if ship != null and ship.visible and ship.is_working():
		_drive_boat_toward(_tug_holding_target(), TUG_HOLD_SPEED, delta)
		return
	# After escorting a departure beyond the north edge, re-enter the patrol
	# from open water below the camera. No craft cuts back through the berth.
	if position.y < -30.0:
		position = Vector2(_lane_x, PortLayout.world_bottom() + 34.0)
		_dir = -1.0
	position.y += _dir * _speed * delta
	if position.y < PortLayout.berth_y(0) + PortLayout.SHIP_H + 20.0:
		_dir = 1.0
	elif position.y > PortLayout.world_bottom() - 50.0:
		_dir = -1.0
	# Bow first: the tug's hull tapers to the top of its sprite.
	_facing = rotate_toward(_facing, PI if _dir > 0.0 else 0.0,
		TURN_RATE * delta)
	_sprite.rotation = _facing
	_boat_fx.rotation = _facing
	position.x = _lane_x + sin(_t * 0.6 + _phase) * 3.0


func tug_escort_active() -> bool:
	return _escort_active


func _tug_formation_target(ship: Ship) -> Vector2:
	## Both boats work astern, one on each quarter. This keeps them in navigable
	## water even at the berth — a port-side escort would otherwise drive over
	## the quay in this narrow top-down composition.
	var side := -16.0 if index % 2 == 0 else 16.0
	var stagger := 20.0 if index % 2 == 0 else 36.0
	return ship.position + Vector2(
		PortLayout.SHIP_W * 0.5 + side + sin(_t * 0.8 + _phase) * 1.5,
		PortLayout.SHIP_H + stagger)


func _tug_holding_target() -> Vector2:
	## Astern of whichever berth is being worked, so the pair is where the work is
	## rather than parked at berth one for ever.
	var side := -16.0 if index % 2 == 0 else 16.0
	var stagger := 20.0 if index % 2 == 0 else 36.0
	var berth_index := 0
	if _world != null:
		var alongside := _world.working_ships()
		if not alongside.is_empty():
			berth_index = alongside[0].berth_index
	return Vector2(
		PortLayout.SHIP_X + PortLayout.SHIP_W * 0.5 + side
			+ sin(_t * 0.55 + _phase) * 2.0,
		PortLayout.berth_y(berth_index) + PortLayout.SHIP_H + stagger)


func _drive_boat_toward(target: Vector2, top_speed: float, delta: float) -> void:
	var to_target := target - position
	var distance := to_target.length()
	var wanted := top_speed * clampf(distance / 28.0, 0.12, 1.0)
	if distance < 0.7:
		wanted = 0.0
	_cruise = move_toward(_cruise, wanted,
		(ACCELERATION if wanted > _cruise else BRAKING) * delta)
	if distance > 0.05:
		var dir := to_target / distance
		var step := minf(distance, _cruise * delta)
		position += dir * step
		var wanted_heading := dir.angle() + PI / 2.0
		_facing = rotate_toward(_facing, wanted_heading, TURN_RATE * delta)
	_sprite.rotation = _facing
	_boat_fx.rotation = _facing


func _update_boat_fx() -> void:
	if _boat_fx == null:
		return
	var underway := _cruise > 1.0 or _escort_active
	if _boat_wake != null:
		_boat_wake.visible = underway
		_boat_wake.modulate.a = (0.36 if _escort_active else 0.22) \
			* (0.90 + sin(_t * 4.0 + _phase) * 0.10)
		_boat_wake.speed_scale = 1.35 if _escort_active else 0.8
	var night := Skyscape._night_factor(TimeManager.time_of_day)
	var target := maxf(clampf(night * 1.25, 0.0, 1.0),
		0.28 if _escort_active else 0.10)
	for light_index in _boat_glows.size():
		_boat_glows[light_index].modulate.a = target \
			* (0.62 if light_index == 0 else 0.76)


func _run_rail_gantry(delta: float) -> void:
	## Travel the length of the standing rake, lower onto a wagon, lift, repeat;
	## go home to the west end when the branch is quiet.
	##
	## Like the transtainer, this is presentation: `RailYard` owns the cargo and
	## the arithmetic, and the gantry is what the player watches while the boxes
	## it is paid to move actually move. What it must never do is mime work on an
	## empty siding — a machine that looks busy over nothing is the whole of
	## "I bought this and I cannot tell what it does".
	var rail: RailYard = _world.rail if _world != null else null
	var home := PortLayout.rail_west_turnout_x() + 24.0
	if rail == null or not rail.is_standing():
		position.x = lerpf(position.x, home, minf(1.0, delta * 0.9))
		_park_gantry(Vector2(0.0, 0.0))
		return
	if _gantry_idle:
		_gantry_idle = false
		_set_cargo_color(randi() % 8)
	_gantry_cycle += delta
	var cycle := 4.4
	var t: float = fmod(_gantry_cycle + _phase, cycle) / cycle
	# Along the train, wagon by wagon rather than in one smooth sweep: a gantry
	# spots over a wagon, works it, and travels to the next one.
	var wagons: int = maxi(1, rail.length())
	var slot: int = int(_gantry_cycle / cycle) % wagons
	position.x = lerpf(position.x, PortLayout.rail_wagon_x(slot),
		minf(1.0, delta * 3.2))
	# Across the beam: the yard side of the track and back over the wagon.
	var reach: float = -14.0 + (sin(t * TAU) * 0.5 + 0.5) * 26.0
	_extra.position = Vector2(0.0, reach)
	var drop: float = 7.0 if fmod(t * 2.0, 1.0) > 0.55 else 1.0
	_spreader.visible = true
	_spreader.position = Vector2(0.0, reach + drop)
	var carrying := t > 0.5
	_cargo.visible = carrying
	if carrying:
		_cargo.position = _spreader.position
	elif t < 0.05:
		_set_cargo_color(randi() % 8)


func _fly(delta: float) -> void:
	## A survey drone flies a route over the yard instead of orbiting a point.
	var home: Vector2 = get_meta("home", position)
	if _stroll_target == Vector2.ZERO or position.distance_to(_stroll_target) < 3.0:
		_stroll_target = home + Vector2(
			randf_range(-58.0, 58.0), randf_range(-70.0, 70.0))
	var to_target := _stroll_target - position
	var step := to_target.normalized() * 22.0 * delta
	position += step if to_target.length() > step.length() else to_target
	position.y += sin(_t * 2.4 + _phase) * 0.25
	if _shadow != null:
		_shadow.position = Vector2(2, 14 + sin(_t * 2.4 + _phase) * 1.5)


func _rtg_cycle(delta: float) -> void:
	## The transtainer only runs over a block that actually holds boxes, and
	## the container it shuttles takes the colour of one standing in that
	## block. An empty block gets a parked machine, which is what a real yard
	## looks like — and it stops the terminal pretending to be busy when the
	## player's yard is empty.
	if _relay_mirror_step(delta):
		return
	var color := _world.yard.block_top_color(_block_index) if _world != null \
		and _world.yard != null else -1
	# The block is this operator's station and nobody else's: the claim is exact,
	# so a second transtainer cannot be told to work the same stacks.
	var board := _board()
	if board != null:
		if color < 0:
			if not _task.is_empty():
				_release_task()
		elif _task.is_empty():
			_task = board.claim(self, NpcCatalog.STATION_STACK,
				"pilha:bloco%d" % _block_index, true)
	if color < 0:
		_park_gantry(Vector2(PortLayout.BLOCK_W * 0.5 - 10.0, 6.0))
		return
	if _gantry_idle:
		_gantry_idle = false
		_set_cargo_color(color)
	var previous_cycle := _gantry_cycle
	_gantry_cycle += delta
	var travel := PortLayout.BLOCK_H - 22.0
	position.y = _block_origin.y - 8.0 + (sin(_t * 0.25 + _phase) * 0.5 + 0.5) * travel
	var cycle := 5.0
	var t: float = fmod(_gantry_cycle + _phase, cycle) / cycle
	var span := PortLayout.BLOCK_W - 4.0
	var x: float = 14.0 + (sin(t * TAU) * 0.5 + 0.5) * span
	_extra.position = Vector2(x - 10.0, 6.0)
	var drop: float = 10.0 if fmod(t * 2.0, 1.0) > 0.55 else 2.0
	_spreader.visible = true
	_spreader.position = Vector2(x - 12.0, 8.0 + drop)
	var carrying := t > 0.5
	_cargo.visible = carrying
	if carrying:
		_cargo.position = _spreader.position
	elif t < 0.05:
		_set_cargo_color(color)
	# One landed box per cycle, on this operator's tally.
	if fmod(previous_cycle + _phase, cycle) > fmod(_gantry_cycle + _phase, cycle):
		_count_move()


func play_berth_move(payload: Dictionary) -> bool:
	## The berth has started a real transfer and handed it to this crane.
	##
	## This is the whole point of the quay crane now: the trolley follows *that*
	## box, in the direction it is really going, for as long as its flight lasts.
	## It used to run a fixed six-second loop whether or not anything was moving,
	## which is exactly why the quay read as decoration rather than as the machine
	## doing the work.
	if id != "sts" or not _berth_move.is_empty():
		return false
	_berth_move = {
		"t": 0.0,
		"dur": maxf(0.25, float(payload.get("duration", 0.62))),
		"loading": bool(payload.get("loading", false)),
	}
	_set_cargo_color(int(payload.get("color", 0)))
	_gantry_idle = false
	return true


func is_free_for_berth_move() -> bool:
	return id == "sts" and _berth_move.is_empty()


func _sts_cycle(delta: float) -> void:
	## The portainer only moves when a container moves.
	if _relay_mirror_step(delta):
		return
	var working := _world != null and _world.any_ship_working()
	var board := _board()
	if board != null:
		if working and _task.is_empty():
			_task = board.claim(self, NpcCatalog.STATION_BERTH)
		elif not working and not _task.is_empty():
			_release_task()
	if _berth_move.is_empty():
		# Waiting over the hatch it is working, or parked back over the apron
		# between calls. Either way: no phantom box on the spreader.
		var idle_x := STS_SHIP_X if working else -32.0
		_park_gantry(Vector2(idle_x - 2.0, 12.0))
		return
	_berth_move["t"] = float(_berth_move.t) + delta
	var t: float = clampf(float(_berth_move.t) / float(_berth_move.dur), 0.0, 1.0)
	var loading := bool(_berth_move.loading)
	# Pick up at one end, traverse, set down at the other. Loading is the same
	# three beats with the ends swapped.
	var from_x := STS_YARD_X if loading else STS_SHIP_X
	var to_x := STS_SHIP_X if loading else STS_YARD_X
	var x := from_x
	var drop := 0.0
	var carrying := true
	if t < 0.18:
		drop = sin(t / 0.18 * PI) * 7.0
		carrying = t / 0.18 > 0.5
	elif t < 0.82:
		x = lerpf(from_x, to_x, _ease((t - 0.18) / 0.64))
	else:
		x = to_x
		drop = sin((t - 0.82) / 0.18 * PI) * 7.0
		carrying = (t - 0.82) / 0.18 < 0.5
	_extra.position = Vector2(x - 2.0, 12.0)
	_spreader.visible = true
	_spreader.position = Vector2(x - 5.0, 18.0 + drop)
	_cargo.visible = carrying
	if carrying:
		_cargo.position = _spreader.position
	if t >= 1.0:
		_berth_move = {}
		_count_move()


func _claim_manoeuvre(delta: float) -> void:
	## The tug's seat on the manoeuvre, so the card can say which one it is on.
	## Rechecked a couple of times a second rather than every frame: deriving needs
	## allocates, and a berthing takes five seconds.
	var board := _board()
	if board == null or not _due_for_claim_check(delta):
		return
	if _task.is_empty():
		_task = board.claim(self, NpcCatalog.STATION_MANOEUVRE,
			"manobra:escolta#%d" % index)
		return
	if board.open_needs(NpcCatalog.STATION_MANOEUVRE).is_empty():
		# The ship has gone. Release rather than keep claiming an escort of
		# nothing, and pick the next manoeuvre up when it arrives.
		_release_task()


func _claim_gate(delta: float) -> void:
	## One carreta at a time gets the despachante's attention, and the bay it is
	## parked on is the key, so the paperwork is never done twice.
	var board := _board()
	if board == null or not _due_for_claim_check(delta):
		return
	if _task.is_empty():
		_task = board.claim(self, NpcCatalog.STATION_GATE)
		return
	var bay := int((_task.get("meta", {}) as Dictionary).get("bay", -1))
	var still_there := false
	for need in board.open_needs(NpcCatalog.STATION_GATE):
		if int((need.get("meta", {}) as Dictionary).get("bay", -1)) == bay:
			still_there = true
			break
	if not still_there:
		# The truck has left, so the paperwork is done. `complete` credits it.
		_complete_task()


func _due_for_claim_check(delta: float) -> bool:
	_claim_check -= delta
	if _claim_check > 0.0:
		return false
	_claim_check = 0.4
	return true


func _park_gantry(trolley_position: Vector2) -> void:
	## Nothing to lift: trolley home, spreader up, no phantom container.
	_gantry_idle = true
	if _extra != null:
		_extra.position = _extra.position.lerp(trolley_position, 0.06)
	if _spreader != null:
		_spreader.visible = false
	if _cargo != null:
		_cargo.visible = false


static func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


func refresh_upgrade_marks() -> void:
	## An upgrade bolted to a machine has to be visible **on that machine**.
	##
	## One amber beacon per fitted upgrade, standing off the nose in a short row
	## and flashing out of phase, so a stock reach stacker and a three-times
	## upgraded one are told apart from across the terminal without reading a
	## number. They are lights rather than new artwork on purpose: the sprites are
	## generated by `tools/sprites`, and a mark that needs no regeneration can
	## follow the upgrade table wherever it goes.
	var tier := UpgradeDB.tier_of(id, GameState.upgrades)
	if _marks != null:
		_marks.queue_free()
		_marks = null
	if tier <= 0 or _sprite == null:
		return
	_marks = Node2D.new()
	_marks.name = "UpgradeMarks"
	add_child(_marks)
	for i in mini(tier, MAX_UPGRADE_MARKS):
		var lamp := Sprite2D.new()
		lamp.texture = preload("res://assets/sprites/prop_glow.png")
		lamp.scale = Vector2.ONE * 0.035
		lamp.position = Vector2(-3.0 + float(i) * 3.0, MARK_OFFSET_Y)
		lamp.modulate = Color8(255, 196, 92)
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		lamp.material = additive
		_marks.add_child(lamp)


func _pulse_upgrade_marks() -> void:
	if _marks == null:
		return
	var lamps := _marks.get_children()
	for i in lamps.size():
		var lamp := lamps[i] as Sprite2D
		lamp.modulate.a = 0.45 + 0.55 * maxf(0.0,
			sin(_t * 2.6 + float(i) * 0.9 + _phase))


func acknowledge() -> void:
	## The shudder of a machine taking the weight. Fires on every purchase of this
	## kind, including the ones past the visible cap that add no new sprite — it
	## is the cheapest way for money spent to have a body somewhere.
	if _sprite == null or not UserPreferences.can_animate() or not visible:
		return
	var home := _sprite.scale
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", home * Vector2(1.18, 0.86), 0.07)
	tween.tween_property(_sprite, "scale", home * Vector2(0.94, 1.08), 0.09)
	tween.tween_property(_sprite, "scale", home, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func pop_in() -> void:
	if is_hauler() and _depot == Vector2.ZERO:
		return       # road-plated machines appear when they drive in
	modulate.a = 0.0
	scale = Vector2(0.6, 0.6)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.20)
	tween.tween_property(self, "scale", Vector2.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
