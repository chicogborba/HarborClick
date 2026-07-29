class_name BerthCallController
extends RefCounted
## Authoritative, restart-safe berth workflow. Visual flights are transactions:
## no destination, ledger update, or reward exists until the flight commits.

signal status_changed(status: Dictionary)
signal transfer_committed(transfer: Dictionary)
signal notice_requested(notice: Dictionary)
signal call_completed(summary: Dictionary)

var ship: Ship
var yard: ContainerYard
var world: PortWorld
var call_id := ""
var input_enabled := true
var _in_flight := 0
var _imports: Array[CargoUnit] = []
var _exported: Array[CargoUnit] = [] # committed outbound ledger only
var _seeded_exports: Array[CargoUnit] = []
var _active: Dictionary = {} # transfer id -> restart-reconciliation record
var _variant_seed := 0
var _variant_call_index := 0
var _auto_carry := 0.0

## Gantries that actually reach a hull. Everything else in the yard feeds the
## stacks; these are the machines that work a berth, so they are the ones that
## can move cargo without a finger on the screen.
const AUTO_MOVERS := {"sts": 0.28, "rtg": 0.10, "flutuante": 0.16}
## Ceiling on the automatic rate, in moves per second. Past this the flights
## overlap into an unreadable smear and the tap stops meaning anything.
const AUTO_RATE_CAP := 6.0
## The departure bonus is expressed as seconds of current income so it can
## never outgrow the economy it sits in.
const DEPARTURE_SECONDS := 12.0
const PERFECT_CALL_BONUS := 0.35


func setup(p_world: PortWorld, p_ship: Ship, p_yard: ContainerYard) -> void:
	world = p_world
	ship = p_ship
	yard = p_yard
	ship.phase_changed.connect(func(_phase: int) -> void: _emit_status())
	ship.departed.connect(_on_ship_departed)


func seed_new(p_seed: int = 0) -> void:
	if p_seed != 0:
		seed(p_seed)
	call_id = CargoUnit.new_uid("call")
	if p_seed != 0:
		_variant_seed = p_seed
	elif _variant_seed == 0:
		# The generated call id is persisted with the selection; this avoids a
		# second global random draw solely for presentation.
		_variant_seed = call_id.hash()
	if ship != null:
		# Two gates on which hull turns up: the lanes the port trades on, and
		# whether there is enough yard to work the class those lanes bring.
		ship.select_variant(_variant_seed, _variant_call_index,
			PortLayout.block_count(), RouteDB.class_pool(GameState.routes))
	_variant_call_index += 1
	_imports.clear()
	_exported.clear()
	_active.clear()
	_in_flight = 0
	var capacity := ship.bay_capacity()
	for i in capacity:
		_imports.append(CargoUnit.new("%s_i_%02d" % [call_id, i], CargoUnit.IMPORT,
			randi() % 8, "", call_id))
	# A new call always has a complete, distinct outbound manifest waiting in
	# the EXPORT zone. No import UID can ever be recycled as an export UID.
	_seeded_exports = yard.ensure_export_manifest(call_id, capacity)
	if yard.sector_count(CargoUnit.EXPORT) < capacity:
		_notice("export_capacity", "Área de exportação sem espaço para o manifesto completo.")
	ship.set_manifest(_imports, capacity)
	ship.set_flights_in_progress(0)
	_emit_status()


func ensure_export_stock() -> void:
	var capacity := ship.bay_capacity() if ship != null \
		else PortLayout.SHIP_BAY_COLS * PortLayout.SHIP_BAY_ROWS
	_seeded_exports.append_array(yard.ensure_export_manifest(call_id, capacity))
	if yard.sector_count(CargoUnit.EXPORT) < capacity:
		_notice("export_capacity", "Área de exportação sem espaço para o manifesto completo.")
	_emit_status()


func arrive() -> void:
	if _imports.is_empty():
		seed_new()
	ship.arrive()
	_emit_status()


func auto_rate() -> float:
	## Moves per second the bought equipment performs on its own.
	var rate := 0.0
	for id: String in AUTO_MOVERS:
		rate += float(AUTO_MOVERS[id]) * float(GameState.structure_count(id))
	return minf(rate, AUTO_RATE_CAP)


func tick(delta: float) -> void:
	## Automation runs the very same transaction a tap does — reserve, fly,
	## commit — so there is exactly one path that can move a container and one
	## place a UID can be created or destroyed.
	if ship == null or not ship.is_working():
		_auto_carry = 0.0
		return
	var rate := auto_rate()
	if rate <= 0.0:
		return
	_auto_carry += rate * delta
	# One move per frame at most: a burst would launch a dozen flights on the
	# same frame and they would land on top of each other.
	if _auto_carry < 1.0:
		return
	_auto_carry -= 1.0
	if _auto_carry > 2.0:
		_auto_carry = 2.0
	# Exactly the branch a tap takes. WAITING_EXPORT has to fall through to
	# `_load`, because that is the only thing that flips the ship into loading —
	# routing it anywhere else leaves an automated call parked forever with a
	# full yard and an empty deck.
	var origin := ship.global_position if ship != null else Vector2.ZERO
	if ship.is_discharging():
		_discharge(origin)
	else:
		_load(origin)


func set_input_enabled(input_allowed: bool) -> void:
	input_enabled = input_allowed
	_emit_status()


func handle_tap(pos: Vector2) -> bool:
	if not input_enabled or ship == null or not ship.is_working():
		return false
	return _discharge(pos) if ship.is_discharging() else _load(pos)


func _discharge(pos: Vector2) -> bool:
	var taken := ship.take_container()
	if taken.is_empty():
		_wait_for_exports()
		return false
	var landing := yard.pick_landing_slot(CargoUnit.IMPORT)
	if landing.is_empty():
		ship.restore_import(taken)
		_notice("import_yard_full", "Pátio de importação cheio. Libere espaço antes de descarregar.")
		return false
	var unit: CargoUnit = taken.unit
	var transfer := CargoTransfer.new(unit,
		func(u: CargoUnit) -> bool: return yard.place_unit(int(landing.slot), int(landing.level), u, str(landing.token)),
		func(_u: CargoUnit) -> void: yard.release_landing(str(landing.token)); ship.restore_import(taken))
	_begin_flight(taken.color, taken.pos, landing.pos, transfer, pos,
		{"origin": "ship", "taken": _snapshot_taken(taken), "landing": landing.duplicate(true)})
	return true


func _wait_for_exports() -> void:
	if ship.cargo_left() == 0 and _in_flight == 0:
		ship.wait_for_export()
	_emit_status()


func _load(pos: Vector2) -> bool:
	var candidate := yard.take_exportable(ship.import_manifest_uids())
	if candidate.is_empty():
		ship.wait_for_export()
		return false
	var bay := ship.reserve_bay()
	if bay.is_empty():
		yard.restore_taken(candidate)
		return false
	var unit: CargoUnit = candidate.unit
	# The only box that may not go out is one this same hull just landed.
	# Anything else in the yard is fair cargo — that is what transhipment is.
	if ship.import_manifest_uids().has(unit.uid):
		ship.release_bay(bay)
		yard.restore_taken(candidate)
		_notice("invalid_export", "Esse contêiner acabou de sair deste navio.")
		return false
	var transfer := CargoTransfer.new(unit,
		func(u: CargoUnit) -> bool:
			var accepted := ship.place_unit(int(bay.col), int(bay.row), u)
			if accepted:
				_exported.append(u)
			return accepted,
		func(_u: CargoUnit) -> void: ship.release_bay(bay); yard.restore_taken(candidate))
	ship.begin_loading()
	_begin_flight(unit.color, candidate.pos, bay.pos, transfer, pos,
		{"origin": "yard", "taken": _snapshot_taken(candidate), "bay": bay.duplicate(true)})
	return true


func _begin_flight(color: int, from: Vector2, to: Vector2, transfer: CargoTransfer,
		reward_pos: Vector2, record: Dictionary) -> void:
	record["id"] = transfer.id
	record["unit"] = transfer.unit.snapshot()
	record["reward_pos"] = {"x": reward_pos.x, "y": reward_pos.y}
	_active[transfer.id] = record
	_in_flight += 1
	var flight := world.fly_cargo(color, from, to)
	flight.landed.connect(func() -> void:
		if transfer.state != CargoTransfer.State.PREPARED:
			return
		var committed := transfer.commit()
		_active.erase(transfer.id)
		_in_flight = maxi(0, _in_flight - 1)
		ship.set_flights_in_progress(_in_flight)
		if committed:
			var reward := _commit_reward(reward_pos)
			var direction: StringName = CargoUnit.IMPORT \
				if record.get("origin", "") == "ship" else CargoUnit.EXPORT
			var payload := {
				"id": transfer.id, "transfer_id": transfer.id,
				"unit": transfer.unit.snapshot(), "unit_uid": transfer.unit.uid,
				"call_id": call_id, "direction": direction,
				"reward_teu": float(reward.get("value", 0.0)),
				"crit": bool(reward.get("crit", false)),
				"tx_id": str(reward.get("tx_id", "")),
			}
			transfer_committed.emit(payload)
			EventBus.cargo_transfer_committed.emit(payload)
			ship.nudge()
		else:
			_notice("transfer_reverted", "Movimento cancelado; o contêiner voltou à origem.")
		if ship.is_discharging():
			_wait_for_exports()
		else:
			_maybe_depart()
		_emit_status())
	flight.tree_exiting.connect(func() -> void:
		if transfer.state == CargoTransfer.State.PREPARED:
			transfer.rollback()
			_active.erase(transfer.id)
			_in_flight = maxi(0, _in_flight - 1)
			ship.set_flights_in_progress(_in_flight)
			_emit_status())
	ship.set_flights_in_progress(_in_flight)
	_emit_status()


func _maybe_depart() -> void:
	if ship.ready_to_depart():
		ship.depart()
	_emit_status()


func _commit_reward(pos: Vector2) -> Dictionary:
	var tx_id := CargoUnit.new_uid("reward")
	if GameState.has_method("make_manual_reward_quote") and GameState.has_method("commit_manual_reward"):
		var quote: Variant = GameState.call("make_manual_reward_quote", tx_id)
		if GameState.call("commit_manual_reward", tx_id, quote, pos):
			var data: Dictionary = quote if quote is Dictionary else {}
			world.show_cargo_reward(pos, float(data.get("value", GameState.click_power)), bool(data.get("crit", false)))
			data["tx_id"] = tx_id
			return data
	else:
		GameState.do_click(pos)
	return {"tx_id": tx_id, "value": GameState.click_power, "crit": false}


func departure_bonus(perfect: bool) -> float:
	## Paid on a completed call, priced in seconds of the port's own income so
	## it scales with the run instead of being a flat number that is enormous
	## in the first hour and invisible in the third.
	var rate := maxf(GameState.cps, GameState.click_power)
	# Freight is priced by the longest lane the port is on: a box that crossed
	# an ocean is worth more than one that came up the coast.
	var bonus := rate * DEPARTURE_SECONDS \
		* RouteDB.reward_multiplier(GameState.routes)
	if perfect:
		bonus *= 1.0 + PERFECT_CALL_BONUS
	return bonus


func _on_ship_departed() -> void:
	var perfect: bool = _exported.size() >= ship.bay_capacity()
	var summary := {"call_id": call_id,
		"exports": _exported.map(func(u: CargoUnit) -> Dictionary: return u.snapshot()),
		"perfect": perfect}
	var bonus := departure_bonus(perfect)
	if bonus > 0.0:
		# Career money: it spends, but it must not shortcut the prestige curve
		# the simulator was balanced against.
		GameState.grant_nonproductive_reward(bonus)
		summary["bonus"] = bonus
		EventBus.notification_requested.emit({
			"id": "call_bonus", "kind": &"milestone", "priority": 2,
			"text": "Escala concluída%s. +%s TEU de frete."
				% [" sem falhas" if perfect else "", GameState.fmt(bonus)],
		})
	call_completed.emit(summary)
	EventBus.berth_call_completed.emit(summary)
	_emit_status()


func _notice(code: String, text: String) -> void:
	notice_requested.emit({"code": code, "text": text, "call_id": call_id})


func _emit_status() -> void:
	if ship == null:
		return
	var capacity := ship.bay_capacity()
	var state := _state_name(ship.phase)
	var progress := ship.export_progress()
	var handled := capacity - ship.cargo_left() if ship.is_discharging() else progress.x
	var current := handled if ship.is_discharging() else progress.x
	var total := capacity if ship.is_discharging() else progress.y
	status_changed.emit({"call_id": call_id, "phase": int(ship.phase), "state": state,
		"handled": handled, "current": current, "total": total, "in_flight": _in_flight,
		"ship_loaded": ship.cargo_left(), "capacity": capacity, "text": _state_text(state, current, total),
		"label": _state_text(state, current, total), "imports_remaining": ship.cargo_left() if ship.is_discharging() else 0,
		"export_progress": progress, "input_enabled": input_enabled})


func _state_name(value: Ship.Phase) -> String:
	match value:
		Ship.Phase.ARRIVING: return "ARRIVING"
		Ship.Phase.DISCHARGING: return "DISCHARGING"
		Ship.Phase.WAITING_EXPORT: return "WAITING_EXPORT"
		Ship.Phase.LOADING: return "LOADING"
		Ship.Phase.DEPARTING: return "DEPARTING"
		_: return "AWAY"


func _state_text(state: String, current: int, total: int) -> String:
	match state:
		"DISCHARGING": return "Descarga %d/%d" % [current, total]
		"WAITING_EXPORT": return "Aguardando exportação"
		"LOADING": return "Embarque %d/%d" % [current, total]
		"ARRIVING": return "Navio se aproximando"
		"DEPARTING": return "Navio partindo"
		_: return "Aguardando próxima escala"


func _snapshot_taken(taken: Dictionary) -> Dictionary:
	var out := taken.duplicate(true)
	if taken.get("unit") is CargoUnit:
		out["unit"] = (taken.unit as CargoUnit).snapshot()
	return out


func snapshot() -> Dictionary:
	var imports: Array = []
	for unit in _imports: imports.append(unit.snapshot())
	var exported: Array = []
	for unit in _exported: exported.append(unit.snapshot())
	var seeded: Array = []
	for unit in _seeded_exports: seeded.append(unit.snapshot())
	var active: Array = []
	for record: Dictionary in _active.values(): active.append(record.duplicate(true))
	return {"call_id": call_id, "imports": imports, "exports": exported,
		"seeded_exports": seeded, "active_transfers": active,
		"variant_seed": _variant_seed, "variant_call_index": _variant_call_index,
		"ship": ship.snapshot() if ship != null else {}}


func restore(data: Dictionary) -> void:
	call_id = str(data.get("call_id", ""))
	_imports = _units_from(data.get("imports", []))
	_exported = _units_from(data.get("exports", []))
	_seeded_exports = _units_from(data.get("seeded_exports", []))
	_variant_seed = int(data.get("variant_seed", 0))
	_variant_call_index = maxi(0, int(data.get("variant_call_index", 0)))
	if ship != null:
		ship.restore(data.get("ship", {}))
		ship.set_import_manifest_reference(_imports)
	for record in data.get("active_transfers", []):
		if record is Dictionary:
			_reconcile_active(record)
	_active.clear()
	_in_flight = 0
	if ship != null:
		ship.set_flights_in_progress(0)
		ship.normalize_after_restore()
		if ship.phase == Ship.Phase.LOADING and ship.ready_to_depart():
			ship.depart()
		elif ship.phase == Ship.Phase.AWAY:
			seed_new()
	_emit_status()


func _reconcile_active(record: Dictionary) -> void:
	var taken: Dictionary = record.get("taken", {})
	if taken.has("unit") and taken.unit is Dictionary:
		taken["unit"] = CargoUnit.from_snapshot(taken.unit)
	if record.get("origin", "") == "ship":
		if ship != null:
			ship.restore_import(taken)
	elif record.get("origin", "") == "yard":
		yard.restore_taken(taken)


func _units_from(raws: Array) -> Array[CargoUnit]:
	var units: Array[CargoUnit] = []
	for raw in raws:
		if raw is Dictionary: units.append(CargoUnit.from_snapshot(raw))
	return units


func apply_view_metrics(metrics: Dictionary) -> void:
	if ship != null:
		ship.apply_view_metrics(metrics)
