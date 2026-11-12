class_name RailYard
extends RefCounted
## The branch line: block trains from the interior, and the terminal's third
## door.
##
## The berth is a closed loop and the gate is the road that keeps it from
## jamming. The branch is the same argument at a different scale. A container
## terminal that can only be reached by lorry is a lorry park with a crane on it;
## the reason a real one is built where it is built is that a railhead runs into
## it, and one service does the work of a shift's worth of trucks.
##
## Mechanically it is the gate with a longer bed and a slower clock. A service
## arrives loaded with boxes the interior is sending for export, those are
## stripped onto the yard, imports are loaded in their place, and the rake goes
## home. Every identity on it was born off-map before the train entered, exactly
## as a ship's inbound manifest is, and every move it makes goes through the same
## `CargoTransfer` — so a box on a wagon is never a box that is also in the yard.
##
## What the branch does *not* share with the road is the ability to turn round.
## The corridor is a stub, so the locomotive runs round its own train before it
## can leave; `RailRake` performs that move and reports back. This class only
## needs to know that the shunt takes time and that it always finishes, which is
## why every stage that waits on the view also carries a timeout.

signal changed
signal notice_requested(notice: Dictionary)

## A rake is off-map, running in, standing at the ramp, running round its train,
## or running out. It can only be worked while it stands.
enum Stage { AWAY, ARRIVING, WORKING, RUNAROUND, DEPARTING }

## How long a service stands at the ramp before it goes home with whatever it
## managed to exchange. A train holds a path, and a path is not indefinite.
const DWELL_SECONDS := 150.0
## A stage the view drives falls through on its own if no view is listening —
## a headless run, or a save restored into one. Without this the branch would
## block for ever on a train nobody is drawing.
const TRANSIT_TIMEOUT := 26.0
## A rake with nothing left to exchange gives the ramp up rather than standing
## out a full dwell.
const BALKED_DWELL := 10.0
## Yard machines that can work a rake without a tap, and the boxes per second
## each one is worth. The rail gantry is the machine built for this and moves
## most of the train; the road-plated machines can reach a wagon but are working
## away from the yard while they do it.
const AUTO_MOVERS := {"trem": 0.30, "reach_stacker": 0.10, "empilhadeira": 0.07}
const AUTO_RATE_CAP := 1.6
## Seconds of green before the train appears. The signal clears for a service
## that has been accepted, not for one that has arrived.
const SIGNAL_LEAD := 12.0

## Signal aspects, in the order a driver meets them.
const ASPECT_CLEAR := &"clear"
const ASPECT_APPROACH := &"approach"
const ASPECT_DANGER := &"danger"

## Seconds of the port's current income paid out when a rake leaves with every
## move on its plan done. The berth pays a departure bonus for a call worked
## clean; this is the same idea at the third door, and it is the only reason to
## chase the last two wagons instead of letting the dwell run out.
##
## Deliberately smaller than the berth's: a service is shorter than a call, and
## the branch already pays per box on the way past.
const COMPLETION_SECONDS := 9.0

var world: PortWorld
var yard: ContainerYard
## Empty when the branch is quiet. One service at a time: there is one running
## line, and a second train on it would be a collision, not a feature.
var service: Dictionary = {}

var _next_service := 20.0
var _auto_carry := 0.0


func setup(p_world: PortWorld, p_yard: ContainerYard) -> void:
	world = p_world
	yard = p_yard


# ------------------------------------------------------------------- traffic

func is_open() -> bool:
	## The branch is part of the world from the start, but the railway only runs
	## once the terminal has grown to it (or its machine is bought): a new
	## player's first minutes are a ship, a quay and a yard, not a timetable.
	return has_branch() or FeatureGate.unlocked(&"routes")


func has_branch() -> bool:
	## The bought structure is the branch itself. Without it the terminal is
	## still on the network — every real port is — but it gets an occasional trip
	## freight instead of a booked shuttle.
	return GameState.structure_count("trem") > 0


func auto_rate() -> float:
	var rate := 0.0
	for id: String in AUTO_MOVERS:
		rate += float(AUTO_MOVERS[id]) * float(GameState.structure_count(id))
	# A rail gantry is a machine bought for the ramp, so it moves both figures: the
	# rate the branch works at and the ceiling that rate is held under. Lifting the
	# rate alone would have sold an upgrade the cap immediately ate.
	rate = GameState.rail_stat(&"auto_rate", rate)
	return maxf(0.0, minf(rate, GameState.rail_stat(&"auto_cap", AUTO_RATE_CAP)))


func dwell_seconds() -> float:
	## How long a service will stand, for this port. The constant is the path the
	## interior books; a run-round loop of the terminal's own is what buys more of
	## it, and the exclusive pair trades it against how often a train comes at all.
	return maxf(BALKED_DWELL, GameState.rail_stat(&"dwell", DWELL_SECONDS))


func completion_seconds() -> float:
	## Seconds of income paid for a rake worked clean. A dry port makes the branch
	## the terminal's second front door, so it pays like one.
	return maxf(0.0, GameState.rail_stat(&"completion", COMPLETION_SECONDS))


func stage() -> Stage:
	if service.is_empty():
		return Stage.AWAY
	return int(service.get("stage", Stage.WORKING)) as Stage


func is_standing() -> bool:
	return stage() == Stage.WORKING


func signal_aspect() -> StringName:
	## What the mast beside the running line is showing. Red while the section is
	## occupied, amber once a service has been accepted or is on the move, green
	## when the line is clear — the same three things the player would read off a
	## real signal, used here so the branch announces itself before the train is
	## on screen.
	match stage():
		Stage.WORKING, Stage.RUNAROUND:
			return ASPECT_DANGER
		Stage.ARRIVING, Stage.DEPARTING:
			return ASPECT_APPROACH
		_:
			return ASPECT_CLEAR if _next_service > SIGNAL_LEAD else ASPECT_APPROACH


func seconds_to_service() -> float:
	return maxf(0.0, _next_service)


func order() -> StringName:
	## What the *current* service was briefed with, which is not necessarily what
	## the player has selected: an order changed while a train is standing at the
	## ramp applies to the next one, the way a booked path actually works.
	if service.is_empty():
		return RailCargoPolicy.coerce_order(GameState.rail_order)
	return RailCargoPolicy.coerce_order(
		StringName(service.get("order", RailCargoPolicy.ORDER_BALANCED)))


func report() -> Dictionary:
	## Everything a caption needs, in one read.
	##
	## The branch is the one subsystem with no permanent home on screen — it runs
	## along the bottom of the world, below the last row of sheds — so the shop's
	## orders board doubles as its instrument panel. Without this the player picks
	## a standing order and never finds out whether it did anything.
	var current := stage()
	return {
		"stage": int(current),
		"standing": current == Stage.WORKING,
		"idle": service.is_empty(),
		"order": order(),
		"length": length(),
		"drops": int(service.get("drops", 0)),
		"lifts": int(service.get("lifts", 0)),
		"booked": int(service.get("booked", 0)),
		"moved": int(service.get("moved", 0)),
		"dwell": maxf(0.0, float(service.get("dwell", 0.0))),
		"eta": seconds_to_service(),
		"aspect": signal_aspect(),
		"auto_rate": auto_rate(),
		"has_branch": has_branch(),
	}


func tick(delta: float) -> void:
	if service.is_empty():
		if not is_open():
			# Held, not skipped: the first train comes a minute after it opens.
			_next_service = maxf(_next_service, 60.0)
			return
		_next_service -= delta
		if _next_service <= 0.0:
			_call_a_service()
		return
	match stage():
		Stage.ARRIVING, Stage.RUNAROUND, Stage.DEPARTING:
			service["transit"] = float(service.get("transit", 0.0)) - delta
			if float(service.transit) <= 0.0:
				_advance_transit()
		Stage.WORKING:
			service["dwell"] = float(service.dwell) - delta
			var finished := _work_left() <= 0
			if (finished or float(service.dwell) <= 0.0) \
					and int(service.get("pending", 0)) == 0:
				send_away()
	if not is_standing():
		return
	var rate := auto_rate()
	if rate <= 0.0:
		return
	_auto_carry += rate * delta
	if _auto_carry < 1.0:
		return
	# Asking the yard what it could give a train walks every slot, so it is asked
	# when a move is actually due rather than twice a frame to decide whether one
	# is.
	if not can_work():
		return
	_auto_carry = minf(_auto_carry - 1.0, 2.0)
	work_once()


func _advance_transit() -> void:
	match stage():
		Stage.ARRIVING:
			notify_arrived()
		Stage.RUNAROUND:
			notify_ran_around()
		Stage.DEPARTING:
			notify_departed()


func _call_a_service() -> void:
	# The timetable is a band, not a number, so what is fitted to the branch scales
	# both ends of it: signalling that halves the interval has to halve the long
	# nights too, or the average would improve while the worst wait did not.
	var factor := GameState.rail_stat(&"service_gap", 1.0) \
		* float(PortDB.port_trait("rail_gap", 1.0))
	var gap := RailCargoPolicy.clamp_gap(
		RailCargoPolicy.service_gap(has_branch()) * factor)
	_next_service = randf_range(gap.x, gap.y)
	if not service.is_empty():
		return
	var length := RailCargoPolicy.clamp_rake(int(roundf(
		GameState.rail_stat(&"rake_length",
			float(RailCargoPolicy.rake_length(has_branch()))))))
	var order := RailCargoPolicy.coerce_order(GameState.rail_order)
	# The pure policy owns the inventory invariant: a service may add stock or
	# exchange it, and may only clear a yard that has no room left to work a ship.
	# The standing order biases that exchange; it cannot break it.
	var plan := RailCargoPolicy.service_plan(
		yard.fill_ratio(), world.target_fill(), length, order)
	var drops: int = mini(int(plan.drops), length)
	var lifts: int = mini(int(plan.lifts), length)
	var wagons: Array = []
	var arrival_uids := PackedStringArray()
	# These identities are born in the interior, off-map, before the train is on
	# the branch. None is created at the yard landing.
	for slot in length:
		if slot < drops:
			var unit := CargoUnit.new(CargoUnit.new_uid("rail"),
				CargoUnit.EXPORT, randi() % 8, "interior")
			wagons.append(unit)
			arrival_uids.append(unit.uid)
		else:
			wagons.append(null)
	service = {
		"wagons": wagons,
		"arrival_uids": arrival_uids,
		"length": length,
		"order": order,
		"drops": drops,
		"lifts": lifts,
		# What the service was booked to do, kept beside what is left of it. A
		# train that is half worked can only be told from a train that arrived
		# half empty by remembering the plan it came in with.
		"booked": drops + lifts,
		"moved": 0,
		"pending": 0,
		"lifting": 0,
		"dwell": dwell_seconds(),
		"stage": int(Stage.ARRIVING),
		"transit": TRANSIT_TIMEOUT,
	}
	# The branch runs along the very bottom of the world and the camera does not
	# follow it, so a service that announced itself only with a signal lamp was a
	# system most players never learned existed. It says so out loud, once, while
	# there is still time to go and look.
	_notice("rail_booked", "Trem aceito no ramal: %d vagões, %s."
		% [length, String(RailCargoPolicy.ORDER_LABELS.get(order, "")).to_lower()],
		&"rail", 1)
	changed.emit()


func send_away() -> void:
	## Work is over. The loco still has to get to the other end of its train
	## before anything moves, so the rake goes to the shunt, not to the exit.
	if service.is_empty() or stage() != Stage.WORKING:
		return
	service["stage"] = int(Stage.RUNAROUND)
	service["transit"] = TRANSIT_TIMEOUT
	changed.emit()


func notify_arrived() -> void:
	## The rake has run in and stands at the ramp. Only now can it be worked, and
	## only now does its clock start.
	if service.is_empty() or stage() != Stage.ARRIVING:
		return
	service["stage"] = int(Stage.WORKING)
	service["dwell"] = dwell_seconds()
	# The dwell starts here, so this is the moment the offer is real: what the
	# train wants, and how long it will wait. Said once, at the only point where
	# going to look at it can still change the outcome.
	_notice("rail_standing", "Trem no ramal: %d para descarregar, %d para embarcar."
		% [int(service.get("drops", 0)), int(service.get("lifts", 0))],
		&"rail", 2)
	changed.emit()


func notify_ran_around() -> void:
	## The loco is coupled to what used to be the tail and the train faces the way
	## it came in.
	if service.is_empty() or stage() != Stage.RUNAROUND:
		return
	service["stage"] = int(Stage.DEPARTING)
	service["transit"] = TRANSIT_TIMEOUT
	changed.emit()


func notify_departed() -> void:
	## Off the map and out of the ledger, in that order. Anything the ramp failed
	## to strip goes back to the interior on the train; it was never in the yard's
	## ledger, so nothing is lost.
	if service.is_empty():
		return
	_settle_service()
	service = {}
	changed.emit()


func _settle_service() -> void:
	## What the service was worth, decided as it leaves rather than as it works.
	##
	## Each box already paid on the way past. This is the difference between a
	## rake that went home empty of work and one that went home with every move
	## on its plan done — the same thing the berth pays a departure bonus for,
	## and the only reason to chase the last two wagons instead of letting the
	## dwell run out on them.
	var booked := int(service.get("booked", 0))
	var moved := int(service.get("moved", 0))
	if booked <= 0:
		return
	if moved < booked:
		# Not a fine, an explanation. A player who never sees the branch cannot
		# tell a train that left with work outstanding from one that had none.
		_notice("rail_partial", "O trem partiu com %d de %d movimentos feitos."
			% [moved, booked], &"rail", 1)
		return
	var bonus := maxf(GameState.cps, GameState.click_power) * completion_seconds()
	if bonus <= 0.0:
		return
	# Career money: it spends, but it must not shortcut the prestige curve the
	# economy simulator was balanced against — same rule as the berth's bonus.
	GameState.grant_nonproductive_reward(bonus)
	_notice("rail_complete", "Composição trabalhada por inteiro: %d movimentos, +%s TEU."
		% [moved, GameState.fmt(bonus)], &"milestone", 2)


# --------------------------------------------------------------------- moves

func length() -> int:
	return int(service.get("length", 0))


func wagon_unit(slot: int) -> CargoUnit:
	var wagons: Array = service.get("wagons", [])
	if slot < 0 or slot >= wagons.size():
		return null
	var entry: Variant = wagons[slot]
	return entry as CargoUnit if entry is CargoUnit else null


func wagon_position(slot: int) -> Vector2:
	return world.to_global(PortLayout.rail_wagon_centre(slot))


func handle_tap(world_pos: Vector2) -> bool:
	if not is_standing():
		return false
	for slot in length():
		if PortLayout.rail_wagon_rect(slot).has_point(world_pos):
			return work_once()
	return false


func can_work() -> bool:
	## Read-only interaction state, for the rake's outline and for auto dispatch.
	if not is_standing():
		return false
	if int(service.get("drops", 0)) > 0 and _loaded_arrival_slot() >= 0 \
			and (yard.can_accept(CargoUnit.EXPORT) or yard.can_accept(CargoUnit.IMPORT)):
		return true
	return int(service.get("lifts", 0)) > 0 and _empty_slot() >= 0 \
		and world.has_road_pickup(_arrival_uids())


func work_once() -> bool:
	if not is_standing():
		return false
	# Strip before you load, the way the ramp is actually worked, and the way that
	# keeps the rake inside its own length: a wagon is only offered a box once the
	# one it came in with is off.
	if int(service.drops) > 0 and _drop():
		return true
	if int(service.lifts) > 0 and _lift():
		return true
	if int(service.drops) > 0:
		_notice("rail_yard_full", "Pátio cheio. O trem não tem onde descarregar.")
	else:
		_notice("rail_no_cargo", "Nada no pátio para embarcar no trem.")
	service["dwell"] = minf(float(service.dwell), BALKED_DWELL)
	return false


func _drop() -> bool:
	## Interior to yard. This is the door that opens when the yard is empty, and
	## every wagon that came in loaded is one.
	var slot := _loaded_arrival_slot()
	if slot < 0:
		service["drops"] = 0
		return false
	var landing := yard.pick_landing_slot(CargoUnit.EXPORT)
	if landing.is_empty():
		landing = yard.pick_landing_slot(CargoUnit.IMPORT)
	if landing.is_empty():
		return false
	var wagons: Array = service.wagons
	var unit: CargoUnit = wagons[slot]
	wagons[slot] = null
	service["drops"] = int(service.drops) - 1
	var transfer := CargoTransfer.new(unit,
		func(u: CargoUnit) -> bool:
			return yard.place_unit(int(landing.slot), int(landing.level), u,
				str(landing.token)),
		func(u: CargoUnit) -> void:
			yard.release_landing(str(landing.token))
			wagons[slot] = u
			service["drops"] = int(service.drops) + 1)
	# No turn in the air, either way. A box lies the same way on a wagon as it
	# does in the stack: the branch and the block rows both run east-west, and the
	# quarter turn this used to carry was the flight faithfully animating a box
	# falling over onto a wagon it could not fit across.
	_fly(unit.color, wagon_position(slot), landing.pos, transfer, 0.0, 0.0)
	return true


func _lift() -> bool:
	## Yard to interior. This is the door that opens when the yard is full, and
	## the one a box a ship discharged goes inland through — which is why it asks
	## the same protected pickup the road does, floor and all.
	var slot := _empty_slot()
	if slot < 0:
		return false
	var candidate := world.take_road_pickup(_arrival_uids())
	if candidate.is_empty():
		return false
	var unit: CargoUnit = candidate.unit
	service["lifts"] = int(service.lifts) - 1
	service["lifting"] = int(service.get("lifting", 0)) + 1
	var wagons: Array = service.wagons
	# The wagon is spoken for the moment the box is in the air, so the next tick
	# offers the next one instead of loading two boxes onto one deck.
	wagons[slot] = true
	var transfer := CargoTransfer.new(unit,
		func(u: CargoUnit) -> bool:
			wagons[slot] = u
			service["lifting"] = maxi(0, int(service.lifting) - 1)
			GameState.do_click(wagon_position(slot))
			return true,
		func(_u: CargoUnit) -> void:
			wagons[slot] = null
			service["lifts"] = int(service.lifts) + 1
			service["lifting"] = maxi(0, int(service.lifting) - 1)
			yard.restore_taken(candidate))
	_fly(unit.color, candidate.pos, wagon_position(slot), transfer, 0.0, 0.0)
	return true


func _work_left() -> int:
	## What the service still came here to do. Both counts fall when a move is
	## committed to the air rather than when it lands, which is what stops a
	## second tap — or the gantry a third of a second later — from taking another
	## box out of the yard for a wagon already spoken for.
	return int(service.get("drops", 0)) + int(service.get("lifts", 0))


func _loaded_arrival_slot() -> int:
	var ids := _arrival_uids()
	for slot in length():
		var unit := wagon_unit(slot)
		if unit != null and ids.has(unit.uid):
			return slot
	return -1


func _empty_slot() -> int:
	var wagons: Array = service.get("wagons", [])
	for slot in wagons.size():
		if wagons[slot] == null:
			return slot
	return -1


func _arrival_uids() -> PackedStringArray:
	var raw: Variant = service.get("arrival_uids", PackedStringArray())
	if raw is PackedStringArray:
		return raw
	var ids := PackedStringArray()
	if raw is Array:
		for uid in raw:
			ids.append(str(uid))
	return ids


func _fly(color: int, from: Vector2, to: Vector2, transfer: CargoTransfer,
		start_rotation: float = 0.0, end_rotation: float = 0.0) -> void:
	## The service counts what it has in the air, which is what keeps a wagon from
	## being over-committed and what keeps a train from pulling out with one of
	## its boxes still mid-flight.
	service["pending"] = int(service.get("pending", 0)) + 1
	var flight := world.fly_cargo(color, from, to)
	flight.set_rotations(start_rotation, end_rotation)
	# Cargo has left the source already. Refresh the rake now, not on landing, or
	# its stale permanent sprite remains under the flying one.
	changed.emit()
	flight.landed.connect(func() -> void:
		service["pending"] = maxi(0, int(service.get("pending", 0)) - 1)
		# The tally is the ownership change, not the tap that asked for it: a
		# move the yard refused on landing rolls back, and a rake cannot be paid
		# a completion bonus for work that came undone.
		if transfer.commit():
			service["moved"] = int(service.get("moved", 0)) + 1
		changed.emit())
	flight.tree_exiting.connect(func() -> void:
		if transfer.state == CargoTransfer.State.PREPARED:
			service["pending"] = maxi(0, int(service.get("pending", 0)) - 1)
			transfer.rollback()
			changed.emit())


func _notice(code: String, text: String, kind: StringName = &"blocked",
		priority: int = 1) -> void:
	## The branch speaks in three registers and they must not look alike: a
	## refusal is a problem to fix, a service is news to act on, and a completed
	## composition is a reward. `PortWorld` passes the kind straight through to
	## the notification policy, which is what decides whether it interrupts.
	notice_requested.emit({"code": code, "text": text, "kind": kind,
		"priority": priority})


# ----------------------------------------------------------------- persistence

func snapshot() -> Dictionary:
	if service.is_empty():
		return {"next_service": _next_service}
	var wagons: Array = []
	for slot in length():
		var unit := wagon_unit(slot)
		wagons.append(unit.snapshot() if unit != null else null)
	return {
		"next_service": _next_service,
		"service": {
			"length": length(),
			"order": str(service.get("order", RailCargoPolicy.ORDER_BALANCED)),
			"drops": int(service.drops),
			"lifts": int(service.lifts),
			"booked": int(service.get("booked", 0)),
			"moved": int(service.get("moved", 0)),
			"dwell": float(service.dwell),
			"arrival_uids": Array(_arrival_uids()),
			# A train that was on the move comes back standing at the ramp. Its
			# boxes were already accounted for, and replaying the run-in would
			# show them twice.
			"stage": int(Stage.WORKING),
			"wagons": wagons,
		},
	}


func restore(data: Dictionary) -> void:
	service = {}
	_next_service = float(data.get("next_service", 20.0))
	var raw: Variant = data.get("service", null)
	if raw is Dictionary:
		var record: Dictionary = raw
		var wagons: Array = []
		for snap in record.get("wagons", []):
			wagons.append(CargoUnit.from_snapshot(snap) if snap is Dictionary else null)
		var arrival_uids := PackedStringArray()
		for uid in record.get("arrival_uids", []):
			arrival_uids.append(str(uid))
		var length := maxi(int(record.get("length", wagons.size())), wagons.size())
		while wagons.size() < length:
			wagons.append(null)
		var drops := maxi(0, int(record.get("drops", 0)))
		var lifts := maxi(0, int(record.get("lifts", 0)))
		var moved := maxi(0, int(record.get("moved", 0)))
		service = {
			"wagons": wagons,
			"arrival_uids": arrival_uids,
			"length": length,
			"order": RailCargoPolicy.coerce_order(
				StringName(record.get("order", RailCargoPolicy.ORDER_BALANCED))),
			"drops": drops,
			"lifts": lifts,
			# A save written before the plan was recorded still has to settle
			# honestly on departure, and what is left plus what is done is the
			# only figure such a save can reconstruct its booking from.
			"booked": maxi(int(record.get("booked", 0)), drops + lifts + moved),
			"moved": moved,
			"pending": 0,
			"lifting": 0,
			"dwell": float(record.get("dwell", DWELL_SECONDS)),
			"stage": int(record.get("stage", Stage.WORKING)),
			"transit": TRANSIT_TIMEOUT,
		}
	changed.emit()


func seed_new() -> void:
	service = {}
	# Long enough that a fresh profile meets the road, the berth and the yard
	# before a train turns up on top of them.
	_next_service = 90.0
	_auto_carry = 0.0
	changed.emit()
