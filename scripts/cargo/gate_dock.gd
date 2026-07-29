class_name GateDock
extends RefCounted
## The road side of the terminal: trucks from the city, and the guarantee that
## a container can always get in and always get out.
##
## The berth alone is a closed loop — cargo arrives by sea and leaves by sea —
## and a closed loop can jam. With a road, the yard has a second door: a truck
## that arrives loaded is a way *in* even when the yard is empty, and a truck
## that arrives empty is a way *out* even when it is full. That is what makes
## being locked impossible rather than merely unlikely.
##
## A truck works exactly like the ship: tap it to move one box, or let the
## bought yard equipment work it. Every move goes through the same
## `CargoTransfer`, so a box is never in two places and never in none.

signal changed
signal notice_requested(notice: Dictionary)

## Inbound trucks carry cargo to drop; outbound arrive empty to be filled.
enum Kind { INBOUND, OUTBOUND }
## A truck is on the road before and after it is on the apron, and it can only
## be worked while it is parked. Cargo therefore never appears at a bay: it
## drives in on a bed and drives out on one.
enum Stage { ARRIVING, DOCKED, LEAVING }

## A road chassis takes one forty-foot box or two twenty-foot ones. Anything
## more is not a truck, it is a train — and the terminal has one of those.
## Three bays of two carry the same six boxes a shift that two bays of three
## used to, on vehicles that are the size a truck actually is.
const TRUCK_CAPACITY := 2
const ARRIVAL_SECONDS := Vector2(9.0, 17.0)
const DWELL_SECONDS := 90.0
## The drive in and the drive out belong to the view, which reports back when
## the truck has actually got there. This is the belt and braces: with no view
## listening — a headless run, or a save restored into one — the bay still
## advances instead of staying blocked for ever.
const TRANSIT_TIMEOUT := 20.0
## Yard machines that can work the road side without a tap.
const AUTO_MOVERS := {"empilhadeira": 0.22, "reach_stacker": 0.20, "tt": 0.14}
const AUTO_RATE_CAP := 4.0

var world: PortWorld
var yard: ContainerYard
## bay index -> {kind, cargo: Array[CargoUnit], remaining, pending, dwell,
##               stage, transit}
var bays: Dictionary = {}

var _next_arrival := 4.0
var _auto_carry := 0.0


func setup(p_world: PortWorld, p_yard: ContainerYard) -> void:
	world = p_world
	yard = p_yard


# ------------------------------------------------------------------- traffic

func auto_rate() -> float:
	var rate := 0.0
	for id: String in AUTO_MOVERS:
		rate += float(AUTO_MOVERS[id]) * float(GameState.structure_count(id))
	return minf(rate, AUTO_RATE_CAP)


func tick(delta: float) -> void:
	_next_arrival -= delta
	if _next_arrival <= 0.0:
		_next_arrival = randf_range(ARRIVAL_SECONDS.x, ARRIVAL_SECONDS.y)
		_call_a_truck()
	for bay: int in bays.keys():
		var truck: Dictionary = bays[bay]
		match _stage_of(truck):
			Stage.ARRIVING:
				truck.transit = float(truck.transit) - delta
				if float(truck.transit) <= 0.0:
					notify_docked(bay)
			Stage.LEAVING:
				truck.transit = float(truck.transit) - delta
				if float(truck.transit) <= 0.0:
					notify_departed(bay)
			_:
				truck.dwell = float(truck.dwell) - delta
				# A truck does not wait forever, and one that is done has no
				# reason to sit on a bay another could use. Leaving with part
				# of a load matters far less than keeping the apron moving.
				var finished := _free_slots(truck) <= 0
				if (finished or float(truck.dwell) <= 0.0) \
						and int(truck.get("pending", 0)) == 0:
					send_away(bay)
	var rate := auto_rate()
	if rate <= 0.0 or _busiest_bay() < 0:
		return
	_auto_carry += rate * delta
	if _auto_carry < 1.0:
		return
	_auto_carry = minf(_auto_carry - 1.0, 2.0)
	work_bay(_busiest_bay())


func _call_a_truck() -> void:
	if bays.size() >= PortLayout.GATE_BAY_COUNT:
		return
	var bay := -1
	for candidate in PortLayout.GATE_BAY_COUNT:
		if not bays.has(candidate):
			bay = candidate
			break
	if bay < 0:
		return
	# Which way the truck runs is decided by what the terminal is short of, so
	# the road is always the missing half of the loop rather than more of what
	# there already is.
	var kind := Kind.INBOUND if yard.fill_ratio() < world.target_fill() \
		else Kind.OUTBOUND
	var cargo: Array[CargoUnit] = []
	if kind == Kind.INBOUND:
		for i in TRUCK_CAPACITY:
			cargo.append(CargoUnit.new(CargoUnit.new_uid("road"),
				CargoUnit.EXPORT, randi() % 8, "cidade"))
	bays[bay] = {
		"kind": int(kind),
		"cargo": cargo,
		"remaining": TRUCK_CAPACITY if kind == Kind.OUTBOUND else cargo.size(),
		"pending": 0,
		"dwell": DWELL_SECONDS,
		"stage": int(Stage.ARRIVING),
		"transit": TRANSIT_TIMEOUT,
	}
	changed.emit()


func send_away(bay: int) -> void:
	## Anything an inbound truck failed to drop goes back to the city with it;
	## it was never in the yard's ledger, so nothing is lost.
	if not bays.has(bay):
		return
	var truck: Dictionary = bays[bay]
	if _stage_of(truck) == Stage.LEAVING:
		return
	truck["stage"] = int(Stage.LEAVING)
	truck["transit"] = TRANSIT_TIMEOUT
	changed.emit()


func notify_docked(bay: int) -> void:
	## The truck has finished its run down the road and is on the bay. Only now
	## can it be worked, and only now does its clock start.
	if not bays.has(bay):
		return
	var truck: Dictionary = bays[bay]
	if _stage_of(truck) != Stage.ARRIVING:
		return
	truck["stage"] = int(Stage.DOCKED)
	truck["dwell"] = DWELL_SECONDS
	changed.emit()


func notify_departed(bay: int) -> void:
	## Off the map and out of the ledger, in that order.
	if not bays.has(bay):
		return
	bays.erase(bay)
	changed.emit()


func _stage_of(truck: Dictionary) -> Stage:
	return int(truck.get("stage", Stage.DOCKED)) as Stage


func _free_slots(truck: Dictionary) -> int:
	## What is still worth doing at this bay.
	##
	## An outbound truck's `remaining` only falls when a box actually lands, so
	## the moves already in the air have to be counted against it. Without that
	## a tap — or the next auto-mover tick, a quarter of a second later — took
	## another box from the yard for a bed that was already spoken for, and a
	## three-box truck could leave with seven. An inbound bed empties the
	## instant a box is committed to the air, so its count is already right.
	if int(truck.kind) == int(Kind.INBOUND):
		return int(truck.remaining)
	return int(truck.remaining) - int(truck.get("pending", 0))


func _busiest_bay() -> int:
	for bay: int in bays.keys():
		var truck: Dictionary = bays[bay]
		if _stage_of(truck) == Stage.DOCKED and _free_slots(truck) > 0:
			return bay
	return -1


# --------------------------------------------------------------------- moves

func bay_position(bay: int) -> Vector2:
	## The truck's bed, not the corner of the painted rectangle: this is where
	## a box flies to and from.
	return PortLayout.gate_bay_centre(bay)


func handle_tap(world_pos: Vector2) -> bool:
	for bay: int in bays.keys():
		if PortLayout.gate_bay_rect(bay).has_point(world_pos):
			return work_bay(bay)
	return false


func work_bay(bay: int) -> bool:
	if bay < 0 or not bays.has(bay):
		return false
	var truck: Dictionary = bays[bay]
	if _stage_of(truck) != Stage.DOCKED or _free_slots(truck) <= 0:
		return false
	return _unload(bay, truck) if int(truck.kind) == int(Kind.INBOUND) \
		else _load(bay, truck)


func _unload(bay: int, truck: Dictionary) -> bool:
	## City to yard. This is the door that opens when the yard is empty.
	var cargo: Array = truck.cargo
	if cargo.is_empty():
		truck.remaining = 0
		return false
	var landing := yard.pick_landing_slot(CargoUnit.EXPORT)
	if landing.is_empty():
		landing = yard.pick_landing_slot(CargoUnit.IMPORT)
	if landing.is_empty():
		_notice("gate_yard_full", "Pátio cheio. O caminhão não tem onde descarregar.")
		return false
	var unit: CargoUnit = cargo.pop_back()
	truck.remaining = cargo.size()
	var transfer := CargoTransfer.new(unit,
		func(u: CargoUnit) -> bool:
			return yard.place_unit(int(landing.slot), int(landing.level), u,
				str(landing.token)),
		func(u: CargoUnit) -> void:
			yard.release_landing(str(landing.token))
			cargo.append(u)
			truck.remaining = cargo.size())
	_fly(truck, unit.color, bay_position(bay), landing.pos, transfer)
	return true


func _load(bay: int, truck: Dictionary) -> bool:
	## Yard to city. This is the door that opens when the yard is full.
	var candidate := yard.take_exportable()
	if candidate.is_empty():
		truck.remaining = 0
		_notice("gate_no_cargo", "Nada no pátio para carregar no caminhão.")
		return false
	var unit: CargoUnit = candidate.unit
	var transfer := CargoTransfer.new(unit,
		func(u: CargoUnit) -> bool:
			(truck.cargo as Array).append(u)
			truck.remaining = int(truck.remaining) - 1
			GameState.do_click(bay_position(bay))
			return true,
		func(_u: CargoUnit) -> void: yard.restore_taken(candidate))
	_fly(truck, unit.color, candidate.pos, bay_position(bay), transfer)
	return true


func _fly(truck: Dictionary, color: int, from: Vector2, to: Vector2,
		transfer: CargoTransfer) -> void:
	## Every bay counts what it has in the air, which is what keeps a bed from
	## being over-committed and what keeps a truck from driving off with one of
	## its boxes still mid-flight.
	truck["pending"] = int(truck.get("pending", 0)) + 1
	var flight := world.fly_cargo(color, from, to)
	flight.landed.connect(func() -> void:
		truck["pending"] = maxi(0, int(truck.pending) - 1)
		transfer.commit()
		changed.emit())
	flight.tree_exiting.connect(func() -> void:
		if transfer.state == CargoTransfer.State.PREPARED:
			truck["pending"] = maxi(0, int(truck.pending) - 1)
			transfer.rollback()
			changed.emit())


func _notice(code: String, text: String) -> void:
	notice_requested.emit({"code": code, "text": text})


# ----------------------------------------------------------------- persistence

func snapshot() -> Dictionary:
	var records: Array = []
	for bay: int in bays.keys():
		var truck: Dictionary = bays[bay]
		records.append({
			"bay": bay,
			"kind": int(truck.kind),
			"remaining": int(truck.remaining),
			"dwell": float(truck.dwell),
			# A truck still on the road comes back parked rather than driving
			# in again: the box on its bed was already accounted for, and
			# replaying the arrival would show it twice.
			"stage": int(Stage.LEAVING) if _stage_of(truck) == Stage.LEAVING \
				else int(Stage.DOCKED),
			"cargo": (truck.cargo as Array).map(
				func(u: CargoUnit) -> Dictionary: return u.snapshot()),
		})
	return {"bays": records, "next_arrival": _next_arrival}


func restore(data: Dictionary) -> void:
	bays.clear()
	for raw in data.get("bays", []):
		if not raw is Dictionary:
			continue
		var record: Dictionary = raw
		var cargo: Array[CargoUnit] = []
		for snap in record.get("cargo", []):
			if snap is Dictionary:
				cargo.append(CargoUnit.from_snapshot(snap))
		bays[int(record.get("bay", 0))] = {
			"kind": int(record.get("kind", 0)),
			"cargo": cargo,
			"remaining": int(record.get("remaining", 0)),
			"pending": 0,
			"dwell": float(record.get("dwell", DWELL_SECONDS)),
			"stage": int(record.get("stage", Stage.DOCKED)),
			"transit": TRANSIT_TIMEOUT,
		}
	_next_arrival = float(data.get("next_arrival", 4.0))
	changed.emit()


func seed_new() -> void:
	bays.clear()
	_next_arrival = 4.0
	_auto_carry = 0.0
	changed.emit()
