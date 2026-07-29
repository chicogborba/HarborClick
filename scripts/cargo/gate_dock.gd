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

const BAY_COUNT := 2
const TRUCK_CAPACITY := 3
const ARRIVAL_SECONDS := Vector2(9.0, 17.0)
const DWELL_SECONDS := 90.0
## Yard machines that can work the road side without a tap.
const AUTO_MOVERS := {"empilhadeira": 0.22, "reach_stacker": 0.20, "tt": 0.14}
const AUTO_RATE_CAP := 4.0

var world: PortWorld
var yard: ContainerYard
## bay index -> {kind, cargo: Array[CargoUnit], remaining, dwell}
var bays: Dictionary = {}

var _next_arrival := 4.0
var _auto_carry := 0.0
var _in_flight := 0


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
		truck.dwell -= delta
		# A truck does not wait forever. Leaving with part of a load keeps the
		# bay free, which matters far more than a tidy manifest.
		if truck.dwell <= 0.0 and _in_flight == 0:
			_release(bay)
	var rate := auto_rate()
	if rate <= 0.0 or bays.is_empty():
		return
	_auto_carry += rate * delta
	if _auto_carry < 1.0:
		return
	_auto_carry = minf(_auto_carry - 1.0, 2.0)
	work_bay(_busiest_bay())


func _call_a_truck() -> void:
	if bays.size() >= BAY_COUNT:
		return
	var bay := -1
	for candidate in BAY_COUNT:
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
		"dwell": DWELL_SECONDS,
	}
	changed.emit()


func _release(bay: int) -> void:
	## Anything an inbound truck failed to drop goes back to the city with it;
	## it was never in the yard's ledger, so nothing is lost.
	bays.erase(bay)
	changed.emit()


func _busiest_bay() -> int:
	for bay: int in bays.keys():
		if int(bays[bay].remaining) > 0:
			return bay
	return -1


# --------------------------------------------------------------------- moves

func bay_position(bay: int) -> Vector2:
	return PortLayout.gate_bay_position(bay)


func handle_tap(world_pos: Vector2) -> bool:
	for bay: int in bays.keys():
		if PortLayout.gate_bay_rect(bay).has_point(world_pos):
			return work_bay(bay)
	return false


func work_bay(bay: int) -> bool:
	if bay < 0 or not bays.has(bay):
		return false
	var truck: Dictionary = bays[bay]
	if int(truck.remaining) <= 0:
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
	_fly(unit.color, bay_position(bay), landing.pos, transfer)
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
	_fly(unit.color, candidate.pos, bay_position(bay), transfer)
	return true


func _fly(color: int, from: Vector2, to: Vector2, transfer: CargoTransfer) -> void:
	_in_flight += 1
	var flight := world.fly_cargo(color, from, to)
	flight.landed.connect(func() -> void:
		_in_flight = maxi(0, _in_flight - 1)
		transfer.commit()
		changed.emit())
	flight.tree_exiting.connect(func() -> void:
		if transfer.state == CargoTransfer.State.PREPARED:
			_in_flight = maxi(0, _in_flight - 1)
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
			"dwell": float(record.get("dwell", DWELL_SECONDS)),
		}
	_next_arrival = float(data.get("next_arrival", 4.0))
	changed.emit()


func seed_new() -> void:
	bays.clear()
	_next_arrival = 4.0
	_auto_carry = 0.0
	_in_flight = 0
	changed.emit()
