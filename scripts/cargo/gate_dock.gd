class_name GateDock
extends RefCounted
## The road side of the terminal: trucks from the city, and the guarantee that
## a container can always get in and always get out.
##
## The berth alone is a closed loop — cargo arrives by sea and leaves by sea —
## and a closed loop can jam. The road is the yard's second door, and every
## truck that uses it runs a **round trip**: it comes in off the public road
## carrying boxes the city is sending out, strips them onto the yard, picks up
## boxes a ship discharged, and drives those home.
##
## That is one decision doing three jobs. A truck is never seen towing an empty
## chassis, which is a wasted trip no haulier would make. A box that came off a
## hull always has a way back off the terminal, so the yard cannot silt up with
## imports nobody can move. And the drop is a way *in* even with an empty yard
## while the lift is a way *out* with a full one — on the same vehicle, so the
## terminal can never be locked in either direction.
##
## Nothing is conjured: what a truck brings came from the city, off the map,
## exactly as a ship's inbound manifest does.
##
## A truck works exactly like the ship: tap it to move one box, or let the
## bought yard equipment work it. Every move goes through the same
## `CargoTransfer`, so a box is never in two places and never in none.

signal changed
signal notice_requested(notice: Dictionary)

## Kept only so pre-round-trip saves can still be interpreted.
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
## A truck that can neither drop nor lift is not waiting for anything worth
## waiting for, so it gives the bay up rather than sitting out a full dwell.
const BALKED_DWELL := 8.0
## Yard machines that can work the road side without a tap.
const AUTO_MOVERS := {"empilhadeira": 0.22, "reach_stacker": 0.20, "tt": 0.14}
const AUTO_RATE_CAP := 4.0

var world: PortWorld
var yard: ContainerYard
## bay index -> {cargo: Array[CargoUnit], arrival_uids, drops, lifts, pending,
##               lifting, dwell, stage, transit}
##
## `drops` is what is still to come off the bed, `lifts` what is still to go on
## it. Both start above zero, always.
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
				var finished := _work_left(truck) <= 0
				if (finished or float(truck.dwell) <= 0.0) \
						and int(truck.get("pending", 0)) == 0 \
						and _on_bed(truck) > 0:
					send_away(bay)
	var rate := auto_rate()
	if rate <= 0.0:
		return
	_auto_carry += rate * delta
	if _auto_carry < 1.0:
		return
	# `_busiest_bay` asks the yard what it could give a truck, which walks every
	# slot. Asking that only when a move is actually due — rather than twice per
	# frame to decide whether to accumulate — is most of the gate's cost gone.
	var bay := _busiest_bay()
	if bay < 0:
		return
	_auto_carry = minf(_auto_carry - 1.0, 2.0)
	work_bay(bay)


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
	# The pure policy owns the inventory invariant: a truck may add stock or
	# exchange it one-for-one, but can never drain the terminal.
	var plan := RoadCargoPolicy.trip_plan(
		yard.fill_ratio(), world.target_fill(), TRUCK_CAPACITY)
	var drops := int(plan.drops)
	var lifts := int(plan.lifts)
	var cargo: Array[CargoUnit] = []
	var arrival_uids := PackedStringArray()
	# Every visible road truck crosses the gate loaded, with its boxes laid
	# lengthwise. A restocking run brings two; a collection run still brings
	# one, so neither leg is ever an empty chassis.
	# These identities are born off-map in the city, before the vehicle enters;
	# none is created at the yard landing.
	for i in drops:
		var unit := CargoUnit.new(CargoUnit.new_uid("road"),
			CargoUnit.EXPORT, randi() % 8, "cidade")
		cargo.append(unit)
		arrival_uids.append(unit.uid)
	bays[bay] = {
		"cargo": cargo,
		"arrival_uids": arrival_uids,
		"drops": drops,
		"lifts": lifts,
		"pending": 0,
		"lifting": 0,
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
	# A chassis never drives back to the city bare. If it has discharged
	# everything, it waits for a ship box or another truck's box instead.
	if _on_bed(truck) <= 0:
		truck["dwell"] = maxf(float(truck.get("dwell", 0.0)), BALKED_DWELL)
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
	# Air brakes: the lorry is in the bay. Quiet and low — trucks are constant.
	AudioManager.play_sfx("truck_arrive", 0.06, -10.0)
	changed.emit()


func notify_departed(bay: int) -> void:
	## Off the map and out of the ledger, in that order.
	if not bays.has(bay):
		return
	bays.erase(bay)
	changed.emit()


func _stage_of(truck: Dictionary) -> Stage:
	return int(truck.get("stage", Stage.DOCKED)) as Stage


func _work_left(truck: Dictionary) -> int:
	## What the truck still came here to do. Both counts fall the moment a move
	## is committed to the air rather than when it lands, which is what stops a
	## second tap — or the next auto-mover tick, a quarter of a second later —
	## from taking another box out of the yard for a bed already spoken for. A
	## three-box truck used to leave with seven that way.
	return int(truck.drops) + int(truck.lifts)


func _on_bed(truck: Dictionary) -> int:
	## Boxes standing on the chassis, counting the ones on their way to it. A
	## dropped box leaves the bed the instant it is in the air, so it does not.
	return (truck.cargo as Array).size() + int(truck.get("lifting", 0))


func _busiest_bay() -> int:
	for bay: int in bays.keys():
		if can_work_bay(bay):
			return bay
	return -1


# --------------------------------------------------------------------- moves

func bay_position(bay: int) -> Vector2:
	## The truck's bed, not the corner of the painted rectangle: this is where
	## a box flies to and from.
	return world.to_global(PortLayout.gate_bay_centre(bay))


func handle_tap(world_pos: Vector2) -> bool:
	for bay: int in bays.keys():
		if PortLayout.gate_bay_rect(bay).has_point(world_pos):
			return work_bay(bay)
	return false


func can_work_bay(bay: int) -> bool:
	## Read-only interaction state for the truck outline and auto dispatch.
	if bay < 0 or not bays.has(bay):
		return false
	var truck: Dictionary = bays[bay]
	if _stage_of(truck) != Stage.DOCKED:
		return false
	if int(truck.get("drops", 0)) > 0 and _has_arrival_box_on_bed(truck) \
			and (yard.can_accept(CargoUnit.EXPORT) \
				or yard.can_accept(CargoUnit.IMPORT)):
		return true
	return int(truck.get("lifts", 0)) > 0 \
		and _on_bed(truck) < TRUCK_CAPACITY \
		and world.has_road_pickup(_arrival_uids(truck))


func work_bay(bay: int) -> bool:
	if bay < 0 or not bays.has(bay):
		return false
	var truck: Dictionary = bays[bay]
	if _stage_of(truck) != Stage.DOCKED:
		return false
	# Strip before you load. That is the order the transaction happens in on a
	# real apron, and it is also what keeps the bed inside its own capacity: a
	# box only goes on once the ones that came in on it are off.
	if int(truck.drops) > 0 and _drop(bay, truck):
		return true
	# A full yard is exactly when the lift matters most, so a refused drop
	# falls through to it rather than giving up — taking a box away is what
	# makes room for the next one.
	if int(truck.lifts) > 0 and _on_bed(truck) < TRUCK_CAPACITY \
			and _lift(bay, truck):
		return true
	if int(truck.drops) > 0:
		_notice("gate_yard_full", "Pátio cheio. O caminhão não tem onde descarregar.")
	else:
		_notice("gate_no_cargo", "Nada no pátio para carregar no caminhão.")
	# Nothing it can do right now. A loaded truck gives the bay up early; an
	# empty one stays until another genuine cargo identity becomes available.
	truck["dwell"] = minf(float(truck.dwell), BALKED_DWELL)
	return false


func _drop(bay: int, truck: Dictionary) -> bool:
	## City to yard. This is the door that opens when the yard is empty, and it
	## is on every truck, so the yard can always be fed.
	var cargo: Array = truck.cargo
	var arrival_uids := _arrival_uids(truck)
	var cargo_index := -1
	for index in cargo.size():
		var candidate: CargoUnit = cargo[index]
		if arrival_uids.has(candidate.uid):
			cargo_index = index
			break
	if cargo_index < 0:
		truck["drops"] = 0
		return false
	var landing := yard.pick_landing_slot(CargoUnit.EXPORT)
	if landing.is_empty():
		landing = yard.pick_landing_slot(CargoUnit.IMPORT)
	if landing.is_empty():
		return false
	var source_pos := world.gate_bed_slot_position(bay, cargo_index)
	var unit: CargoUnit = cargo[cargo_index]
	cargo.remove_at(cargo_index)
	truck["drops"] = int(truck.drops) - 1
	var transfer := CargoTransfer.new(unit,
		func(u: CargoUnit) -> bool:
			return yard.place_unit(int(landing.slot), int(landing.level), u,
				str(landing.token)),
		func(u: CargoUnit) -> void:
			yard.release_landing(str(landing.token))
			cargo.insert(mini(cargo_index, cargo.size()), u)
			truck["drops"] = int(truck.drops) + 1)
	_fly(truck, unit.color, source_pos, landing.pos, transfer,
		PI / 2.0, 0.0)
	return true


func _lift(bay: int, truck: Dictionary) -> bool:
	## Yard to city. This is the door that opens when the yard is full, and the
	## one a box a ship discharged goes home through — which is why it asks for
	## an import first.
	var candidate := world.take_road_pickup(_arrival_uids(truck))
	if candidate.is_empty():
		return false
	var unit: CargoUnit = candidate.unit
	var destination_slot := _on_bed(truck)
	var destination_pos := world.gate_bed_slot_position(
		bay, destination_slot)
	truck["lifts"] = int(truck.lifts) - 1
	truck["lifting"] = int(truck.get("lifting", 0)) + 1
	var transfer := CargoTransfer.new(unit,
		func(u: CargoUnit) -> bool:
			(truck.cargo as Array).append(u)
			truck["lifting"] = maxi(0, int(truck.lifting) - 1)
			GameState.do_click(bay_position(bay))
			return true,
		func(_u: CargoUnit) -> void:
			truck["lifts"] = int(truck.lifts) + 1
			truck["lifting"] = maxi(0, int(truck.lifting) - 1)
			yard.restore_taken(candidate))
	_fly(truck, unit.color, candidate.pos, destination_pos, transfer,
		0.0, PI / 2.0)
	return true


func _arrival_uids(truck: Dictionary) -> PackedStringArray:
	var raw: Variant = truck.get("arrival_uids", PackedStringArray())
	if raw is PackedStringArray:
		return raw
	var ids := PackedStringArray()
	if raw is Array:
		for uid in raw:
			ids.append(str(uid))
	return ids


func _has_arrival_box_on_bed(truck: Dictionary) -> bool:
	var ids := _arrival_uids(truck)
	for unit: CargoUnit in truck.get("cargo", []) as Array:
		if ids.has(unit.uid):
			return true
	return false


func _fly(truck: Dictionary, color: int, from: Vector2, to: Vector2,
		transfer: CargoTransfer, start_rotation: float = 0.0,
		end_rotation: float = 0.0) -> void:
	## Every bay counts what it has in the air, which is what keeps a bed from
	## being over-committed and what keeps a truck from driving off with one of
	## its boxes still mid-flight.
	truck["pending"] = int(truck.get("pending", 0)) + 1
	var flight := world.fly_cargo(color, from, to)
	flight.set_rotations(start_rotation, end_rotation)
	# Cargo has left the source manifest already. Refresh the chassis now, not
	# on landing, or its stale permanent sprite remains under the flying one.
	changed.emit()
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
			"drops": int(truck.drops),
			"lifts": int(truck.lifts),
			"arrival_uids": Array(_arrival_uids(truck)),
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
		var arrival_uids := PackedStringArray()
		for uid in record.get("arrival_uids", []):
			arrival_uids.append(str(uid))
		# v2 road saves had one-way trucks. Preserve every existing identity and
		# translate their unfinished work without creating replacement cargo.
		var legacy_kind := int(record.get("kind", Kind.INBOUND))
		var has_round_trip := record.has("drops") or record.has("lifts")
		if arrival_uids.is_empty() and legacy_kind == Kind.INBOUND:
			for unit: CargoUnit in cargo:
				arrival_uids.append(unit.uid)
		var drops := int(record.get("drops",
			record.get("remaining", cargo.size()) if legacy_kind == Kind.INBOUND else 0))
		var lifts := int(record.get("lifts",
			1 if legacy_kind == Kind.INBOUND else record.get("remaining", TRUCK_CAPACITY)))
		if not has_round_trip and legacy_kind == Kind.INBOUND:
			lifts = 1
		bays[int(record.get("bay", 0))] = {
			"cargo": cargo,
			"arrival_uids": arrival_uids,
			"drops": maxi(0, drops),
			"lifts": maxi(0, lifts),
			"pending": 0,
			"lifting": 0,
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
