class_name TrafficGame
extends RefCounted
## The rules of the late-lorry minigame, with no nodes in them.
##
## The reefer for the ship is stuck on the avenue and the gate shuts with the
## tide. The player drives it: three lanes, traffic that is slower than you,
## things in the road that are not traffic at all, and a distance to the port
## that has to come down before the clock does.
##
##   * a **hit** costs a life, kills your speed and leaves you a second of
##     blinking grace — three hits and the load is lost;
##   * **oil** does not hurt, it throws you a lane sideways;
##   * **coffee** is a short turbo, a **clock** buys seconds back;
##   * speed builds the longer you drive clean, so the fast run is the careful
##     one.
##
## Everything is in road pixels: the view draws the road at twice that. Pure so
## the suite can drive whole runs headless with a fixed seed.

const LANES := 3
const LANE_W := 22.0
## Length of the player's rig on the road, cab to tail.
const RIG_LEN := 30.0
## How far ahead a new row of traffic appears (just past the top of the view).
const SPAWN_AHEAD := 150.0
const MIN_SPEED := 58.0
const MAX_SPEED := 118.0
## What a clean second of driving adds to the speed.
const ACCEL := 9.0
const TURBO_SPEED := 150.0
const TURBO_SECONDS := 2.2
const GRACE_SECONDS := 1.1
const CLOCK_BONUS := 3.0
const LIVES := 3

const CAR: StringName = &"car"
const BUS: StringName = &"bus"
const MOTO: StringName = &"moto"
const CONE: StringName = &"cone"
const HOLE: StringName = &"hole"
const OIL: StringName = &"oil"
const COFFEE: StringName = &"coffee"
const CLOCK: StringName = &"clock"

## Length on the road and own speed (traffic drives the same way, slower).
const KINDS := {
	CAR: {"len": 20.0, "speed": 30.0},
	BUS: {"len": 40.0, "speed": 22.0},
	MOTO: {"len": 12.0, "speed": 44.0},
	CONE: {"len": 8.0, "speed": 0.0},
	HOLE: {"len": 10.0, "speed": 0.0},
	OIL: {"len": 12.0, "speed": 0.0},
	COFFEE: {"len": 10.0, "speed": 0.0},
	CLOCK: {"len": 10.0, "speed": 0.0},
}

const HIT: StringName = &"hit"
const SKID: StringName = &"skid"
const TURBO: StringName = &"turbo"
const BONUS: StringName = &"bonus"

var distance_goal := 1800.0
var travelled := 0.0
var time_left := 36.0
var lives := LIVES
var lane := 1
var speed := MIN_SPEED
var turbo := 0.0
var grace := 0.0
var hits := 0
var pickups := 0
var over := false
var victory := false
## {kind, lane, y (road px ahead of the rig's nose), id}
var things: Array[Dictionary] = []
## What happened this frame, for the view: [{event, kind, lane}]
var events: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _next_row := 60.0
var _serial := 0


func setup(offer: Dictionary, seed_value: int = -1) -> void:
	distance_goal = float(offer.get("distance", float(offer.get("goal", 8)) * 220.0))
	time_left = float(offer.get("seconds", 36.0))
	lives = LIVES
	lane = 1
	speed = MIN_SPEED
	travelled = 0.0
	turbo = 0.0
	grace = 0.0
	hits = 0
	pickups = 0
	over = false
	victory = false
	things.clear()
	events.clear()
	_next_row = 60.0
	_serial = 0
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func steer(direction: int) -> bool:
	## One lane left (-1) or right (+1). Returns false against the kerb.
	if over:
		return false
	var next := clampi(lane + signi(direction), 0, LANES - 1)
	if next == lane:
		return false
	lane = next
	return true


func progress() -> float:
	return clampf(travelled / maxf(1.0, distance_goal), 0.0, 1.0)


func current_speed() -> float:
	return TURBO_SPEED if turbo > 0.0 else speed


func advance(delta: float) -> void:
	events.clear()
	if over:
		return
	time_left = maxf(0.0, time_left - delta)
	turbo = maxf(0.0, turbo - delta)
	grace = maxf(0.0, grace - delta)
	speed = minf(MAX_SPEED, speed + ACCEL * delta)
	var v := current_speed()
	travelled += v * delta
	for thing: Dictionary in things:
		var own: float = KINDS[thing.kind].speed
		thing.y = float(thing.y) - (v - own) * delta
	_collide()
	var kept: Array[Dictionary] = []
	for thing: Dictionary in things:
		if float(thing.y) > -RIG_LEN - 50.0 and not bool(thing.get("gone", false)):
			kept.append(thing)
	things = kept
	_next_row -= v * delta
	if _next_row <= 0.0 and travelled < distance_goal - SPAWN_AHEAD * 0.6:
		_spawn_row()
	if travelled >= distance_goal:
		over = true
		victory = true
	elif lives <= 0 or time_left <= 0.0:
		over = true
		victory = false


func _collide() -> void:
	for thing: Dictionary in things:
		if int(thing.lane) != lane or bool(thing.get("gone", false)):
			continue
		var length: float = KINDS[thing.kind].len
		# The thing's tail is at y, its body runs forward from there; the rig
		# occupies -RIG_LEN..0 below the nose.
		var tail := float(thing.y)
		if tail > 0.0 or tail + length < -RIG_LEN:
			continue
		var kind: StringName = thing.kind
		match kind:
			COFFEE:
				thing.gone = true
				turbo = TURBO_SECONDS
				pickups += 1
				events.append({"event": TURBO, "kind": kind, "lane": lane})
			CLOCK:
				thing.gone = true
				time_left += CLOCK_BONUS
				pickups += 1
				events.append({"event": BONUS, "kind": kind, "lane": lane})
			OIL:
				thing.gone = true
				if grace > 0.0:
					continue
				# Thrown a lane sideways, away from the kerb if it has to be.
				var dir := -1 if _rng.randf() < 0.5 else 1
				if lane + dir < 0 or lane + dir >= LANES:
					dir = -dir
				lane += dir
				events.append({"event": SKID, "kind": kind, "lane": lane})
			_:
				if grace > 0.0:
					continue
				thing.gone = true
				hits += 1
				lives -= 1
				speed = MIN_SPEED
				turbo = 0.0
				grace = GRACE_SECONDS
				events.append({"event": HIT, "kind": kind, "lane": lane})
		return


func _spawn_row() -> void:
	## One or two lanes blocked, never all three — counting what is still in
	## the road from earlier rows, so a long bus and a new row can never wall
	## the avenue off between them. Now and then a pickup in a free lane.
	## Rows come closer together as the run goes on.
	var busy := {}
	for thing: Dictionary in things:
		var kind: StringName = thing.kind
		if kind in [COFFEE, CLOCK]:
			continue
		var tail := float(thing.y)
		var head := tail + float(KINDS[kind].len)
		# Anything that will still be alongside this row when the rig gets here.
		if head > SPAWN_AHEAD - RIG_LEN - 46.0:
			busy[int(thing.lane)] = true
	var open: Array[int] = []
	for lane in LANES:
		if not busy.has(lane):
			open.append(lane)
	if open.size() <= 1:
		# Already one way through: leave it, and try again a little later.
		_next_row = 20.0
		return
	open.shuffle()
	var want := 1 if _rng.randf() < 0.55 - progress() * 0.25 else 2
	var blocked := mini(want, open.size() - 1)
	for i in blocked:
		_add(_pick_hazard(), open[i])
	if _rng.randf() < 0.22:
		_add(COFFEE if _rng.randf() < 0.55 else CLOCK, open[open.size() - 1])
	var gap := lerpf(78.0, 50.0, progress()) + _rng.randf_range(0.0, 22.0)
	_next_row = gap


func _pick_hazard() -> StringName:
	var roll := _rng.randf()
	if roll < 0.38:
		return CAR
	if roll < 0.52:
		return BUS
	if roll < 0.64:
		return MOTO
	if roll < 0.78:
		return CONE
	if roll < 0.9:
		return HOLE
	return OIL


func _add(kind: StringName, at_lane: int) -> void:
	_serial += 1
	things.append({"kind": kind, "lane": at_lane, "y": SPAWN_AHEAD, "id": _serial})


func summary() -> Dictionary:
	return {"distance": int(travelled), "hits": hits, "pickups": pickups,
		"time_left": snappedf(time_left, 0.1), "won": victory}
