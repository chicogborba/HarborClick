class_name BerthCallController
extends RefCounted
## Authoritative, restart-safe berth workflow. Visual flights are transactions:
## no destination, ledger update, or reward exists until the flight commits.

signal status_changed(status: Dictionary)
signal transfer_committed(transfer: Dictionary)
## A box has just left one side and is in the air. The world hands this to a quay
## crane so the machine seen moving is the machine that moved this box.
signal move_started(move: Dictionary)
signal notice_requested(notice: Dictionary)
signal call_completed(summary: Dictionary)

## Boxes this berth may have in the air at once.
##
## Without a ceiling every tap started another transfer, so a player tapping
## while a box was already crossing emptied the yard in a burst of moves that had
## no visible reason — cargo reserved, machines claimed, blocks drained, all for
## a hull that already had enough on the way. The cap is generous enough that
## ordinary tapping never meets it and tight enough that the yard stops churning.
const MAX_IN_FLIGHT := 6
## How long a berth may sit with no legal move before it is allowed to break the
## transhipment rule to get going again.
##
## The rule — a box this hull just landed may not go straight back out — is the
## right rule and it stays. What it must never do is deadlock: a small yard
## holding nothing but this call's own imports leaves the ship in
## WAITING_EXPORT with no exportable box, nothing in the air, and a player with
## literally nothing to tap. The road opens that up eventually, and until it does
## the port is frozen. After this many seconds the hull re-handles its own cargo
## and says so.
const EXPORT_STARVE_GRACE := 18.0

var ship: Ship
var yard: ContainerYard
var world: PortWorld
var call_id := ""
## The lane this call was booked on. It decides the hull, the freight it pays and
## how long the berth stands empty afterwards.
var lane: Dictionary = {}
var input_enabled := true
var _in_flight := 0
var _imports: Array[CargoUnit] = []
var _exported: Array[CargoUnit] = [] # committed outbound ledger only
var _active: Dictionary = {} # transfer id -> restart-reconciliation record
var _variant_seed := 0
var _variant_call_index := 0
var _auto_carry := 0.0
## Seconds this call has been unable to make any move at all.
var _starved := 0.0
## Set once the grace runs out: this call may load the boxes it landed.
var _rehandling := false
## The slice of the port's gang this berth has been given, or -1 when nobody has
## divided it. A controller ticked on its own — the suites, a single-berth port
## before the quay grew — keeps the whole rate, so standing orders can only ever
## change how a *shared* gang is spent.
var _auto_share := -1.0

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
## Carga premiada: one box in every ~PREMIUM_EVERY of an inbound manifest is
# premiada (a property of the manifest, never a roll at the finger), gleams on
# the deck, and pays PREMIUM_MULT when it is discharged. It replaced the old
# invisible 3% crit (`GameState.CRIT_CHANCE` is 0 since).
const PREMIUM_EVERY := 12
const PREMIUM_MULT := 5.0


func setup(p_world: PortWorld, p_ship: Ship, p_yard: ContainerYard) -> void:
	world = p_world
	ship = p_ship
	yard = p_yard
	ship.phase_changed.connect(func(_phase: int) -> void: _emit_status())
	ship.departed.connect(_on_ship_departed)


func seed_new(p_seed: int = 0, forced_variant: Dictionary = {}) -> void:
	## `forced_variant` is how a special charter takes over a call: the hull is
	## given rather than rolled, and everything after it — capacity, manifest,
	## history — follows from that one substitution.
	if p_seed != 0:
		seed(p_seed)
	call_id = CargoUnit.new_uid("call")
	_starved = 0.0
	_rehandling = false
	if p_seed != 0:
		_variant_seed = p_seed
	elif _variant_seed == 0:
		# The generated call id is persisted with the selection; this avoids a
		# second global random draw solely for presentation.
		_variant_seed = call_id.hash()
	# The lane is chosen before the hull, because the lane is what decides the
	# hull. Booking against the whole owned set was why a new lane could only
	# ever help: the port traded on all of them at once and was paid the best.
	lane = RoutePolicy.pick(RouteDB.owned(GameState.routes),
		GameState.route_policy, _variant_call_index, 1 + GameState.route_slot_bonus())
	if ship != null:
		if forced_variant.is_empty():
			# Two gates on which hull turns up: the lane this call was booked on,
			# and whether there is enough yard to work the class it brings.
			var pool: Array[String] = []
			for silhouette in lane.get("classes", []):
				pool.append(str(silhouette))
			if pool.is_empty():
				pool = RouteDB.class_pool(GameState.routes)
			ship.select_variant(_variant_seed, _variant_call_index,
				PortLayout.block_count(), pool)
		else:
			ship.apply_variant(forced_variant)
	_variant_call_index += 1
	# The album records what actually arrived — silhouette and livery — so the
	# collection is earned by calls, not by a roll the player never saw.
	if ship != null and not ship.ship_variant.is_empty():
		Progression.record_ship_variant(ship.ship_variant)
	_imports.clear()
	_exported.clear()
	_active.clear()
	_in_flight = 0
	var capacity := ship.bay_capacity()
	for i in capacity:
		var unit := CargoUnit.new("%s_i_%02d" % [call_id, i], CargoUnit.IMPORT,
			randi() % 8, "", call_id)
		unit.premiada = i % PREMIUM_EVERY == PREMIUM_EVERY - 1
		_imports.append(unit)
	# Nothing is seeded into the yard here. Exports must already have arrived
	# on a road vehicle or on an earlier ship; the new call only owns the boxes
	# visibly travelling on its inbound deck.
	ship.set_manifest(_imports, capacity)
	ship.set_flights_in_progress(0)
	_emit_status()


func ensure_export_stock() -> void:
	## Legacy migration hook. Old saves called this after restoring a flattened
	## yard; it deliberately creates nothing now. Road and sea are the only
	## sources of physical cargo.
	_emit_status()


func arrive(open_channel: bool = true) -> void:
	## `open_channel` is the sequencer's answer to "is there a hull moored between
	## this berth and the sea?". False sends the ship in off the offing instead of
	## up the fairway, because the channel is one hull wide.
	if _imports.is_empty():
		seed_new()
	ship.arrive(open_channel)
	_emit_status()


func auto_rate() -> float:
	## Moves per second this berth actually gets — its slice of the gang once
	## `PortWorld` has divided it, and the whole gang when nobody has.
	return pool_rate() if _auto_share < 0.0 else _auto_share


func set_auto_share(rate: float) -> void:
	## Set every tick by `PortWorld` from `CraneAllocation`. Passing a negative
	## rate hands the berth back the undivided gang.
	_auto_share = rate


static func pool_rate() -> float:
	## Moves per second the bought equipment performs, per berth being worked.
	## The port-wide pool is this times the number of hulls under the cranes;
	## `CraneAllocation` is what decides who gets how much of it.
	var rate := 0.0
	for id: String in AUTO_MOVERS:
		rate += float(AUTO_MOVERS[id]) * float(GameState.structure_count(id))
	return minf(rate, AUTO_RATE_CAP)


func tick(delta: float) -> void:
	## Automation runs the very same transaction a tap does — reserve, fly,
	## commit — so there is exactly one path that can move a container and one
	## place a UID can be created or destroyed.
	_tick_starvation(delta)
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
	## The tap pays, and then the terminal moves whatever it can.
	##
	## These used to be one thing: a tap started a transfer, and the transfer
	## paid when the box landed. That made the reward a *consequence* of the
	## simulation, and the simulation has every right to say no — six boxes
	## already in the air, no landing slot, nothing exportable in the yard. The
	## result was a clicker whose click stopped answering, which is the one thing
	## a clicker may never do, and a "+1" that appeared a second and a half after
	## the finger that earned it.
	##
	## So the two are separate now. Tapping a working hull always pays, at the
	## finger, immediately. The cap and the yard rules still govern how many
	## containers may physically be crossing the terminal — they are what stop the
	## yard churning — but they govern the *cargo*, not the player.
	if not input_enabled or ship == null or not ship.is_working():
		return false
	var reward := _commit_reward(pos)
	if _in_flight < MAX_IN_FLIGHT:
		if ship.is_discharging():
			_discharge(pos, reward)
		else:
			_load(pos, reward)
	return true


func can_work() -> bool:
	## Whether a tap would move a box. Read by the ship's interaction outline and
	## by the starvation watchdog — not by `handle_tap`, which now always pays.
	if not input_enabled or ship == null or yard == null or not ship.is_working():
		return false
	if _in_flight >= MAX_IN_FLIGHT:
		return false
	if ship.is_discharging():
		return ship.cargo_left() > 0 and yard.can_accept(CargoUnit.IMPORT)
	var progress := ship.export_progress()
	return progress.x < progress.y \
		and yard.has_exportable(manifest_exclusions())


func _discharge(pos: Vector2, reward: Dictionary = {}) -> bool:
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
		{"origin": "ship", "taken": _snapshot_taken(taken),
		"landing": landing.duplicate(true), "reward": reward})
	return true


func _wait_for_exports() -> void:
	if ship.cargo_left() == 0 and _in_flight == 0:
		ship.wait_for_export()
	_emit_status()


func _load(pos: Vector2, reward: Dictionary = {}) -> bool:
	var candidate := yard.take_exportable(manifest_exclusions())
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
	if not _rehandling and ship.import_manifest_uids().has(unit.uid):
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
		{"origin": "yard", "taken": _snapshot_taken(candidate),
		"bay": bay.duplicate(true), "reward": reward})
	return true


func _begin_flight(color: int, from: Vector2, to: Vector2, transfer: CargoTransfer,
		reward_pos: Vector2, record: Dictionary) -> void:
	record["id"] = transfer.id
	record["unit"] = transfer.unit.snapshot()
	record["reward_pos"] = {"x": reward_pos.x, "y": reward_pos.y}
	_active[transfer.id] = record
	_in_flight += 1
	var flight := world.fly_cargo(color, from, to)
	move_started.emit({
		"loading": str(record.get("origin", "")) == "yard",
		"color": color, "duration": flight.duration(),
		"from": from, "to": to, "id": transfer.id,
	})
	flight.landed.connect(func() -> void:
		if transfer.state != CargoTransfer.State.PREPARED:
			return
		var committed := transfer.commit()
		_active.erase(transfer.id)
		_in_flight = maxi(0, _in_flight - 1)
		ship.set_flights_in_progress(_in_flight)
		if committed:
			# A tap was already paid, at the finger, the moment it happened; an
			# automated move has nobody to pay early and is settled here, on the
			# landing, exactly as every move used to be. The record says which
			# this was, so the two can never both pay and neither can be missed.
			var reward: Dictionary = record.get("reward", {})
			if reward.is_empty():
				reward = _commit_reward(reward_pos)
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
			# A premiada box pays PREMIUM_MULT in total. The base was already
			# paid (at the finger for a tap, in this very quote for an automated
			# move), so the landing pays only the remaining share — under its own
			# transaction id, so a reload between the two can never pay twice or
			# lose the bonus.
			if direction == CargoUnit.IMPORT and transfer.unit.premiada:
				var extra := float(reward.get("value", 0.0)) * (PREMIUM_MULT - 1.0)
				if extra > 0.0 and GameState.has_method("commit_manual_reward"):
					var ptx := "%s:premiada" % transfer.id
					var paid: bool = GameState.call("commit_manual_reward", ptx,
						{"value": extra, "crit": true}, reward_pos)
					if paid:
						payload["premiada"] = true
						payload["reward_teu"] = float(payload["reward_teu"]) + extra
						world.show_cargo_reward(reward_pos + Vector2(0.0, -16.0), extra, true)
						world.show_premiada(reward_pos)
						if world.fx != null:
							world.fx.burst(&"spark", reward_pos, 10, 22.0)
			transfer_committed.emit(payload)
			EventBus.cargo_transfer_committed.emit(payload)
			# Only a box *arriving* on the deck shakes the hull, and it shakes the
			# side whose bay took the weight. A discharge lifts a box clear of the
			# ship and must leave it perfectly still.
			var loading := str(record.get("origin", "")) == "yard"
			if loading:
				var bay: Dictionary = record.get("bay", {})
				ship.nudge(int(bay.get("col", -1)), true)
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
		ship.depart(_channel_out_is_clear())
	_emit_status()


func _channel_out_is_clear() -> bool:
	## The run out is southward — the hull is drawn bow-down — so what matters is
	## whoever is alongside between this berth and the open water below it. A
	## focused harness with no world sails the full channel: there is nobody else
	## on its quay to cross.
	if world == null or not world.has_method("lane_clear_north"):
		return true
	# North is the way out: the hull is drawn bow-up and only steams bow-first.
	return world.lane_clear_north(ship.berth_index)


func _commit_reward(pos: Vector2) -> Dictionary:
	# The combo is counted before the quote, so the tap that earns a step is paid
	# at it: the number on screen and the ping agree.
	var stepped := GameState.combo_tap()
	world.show_combo_feedback(pos, GameState.combo.steps(GameState.combo_now()), stepped)
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
	# Freight is priced by **this call's** lane, not by the best lane the port
	# owns. Taking the maximum meant a coastal call paid ocean money and every
	# lane but one stopped existing the moment it was bought.
	var bonus := rate * DEPARTURE_SECONDS * lane_reward()
	if perfect:
		bonus *= 1.0 + PERFECT_CALL_BONUS
	# "O prático a bordo": a promise made by a skill, spent on the next call.
	bonus *= GameState.take_pilot()
	return bonus


func lane_reward() -> float:
	## The lane's freight times the Rotas branch of the capital tree, so a bought
	# `route_reward_multiplier` node moves a number the player sees.
	return maxf(1.0, float(lane.get("reward", 1.0))) \
		* (1.0 + GameState.route_reward_bonus())


func lane_interval() -> float:
	## How long the berth stands empty before this lane books again, as a
	## multiple of the base turnaround.
	return maxf(0.25, float(lane.get("interval", 1.0)))


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
		world.show_call_bonus(bonus, perfect)
	call_completed.emit(summary)
	EventBus.berth_call_completed.emit(summary)
	_emit_status()


func _notice(code: String, text: String) -> void:
	notice_requested.emit({"code": code, "text": text, "call_id": call_id})


func _tick_starvation(delta: float) -> void:
	## The one guarantee the berth owes the player: there is always something a
	## tap can do, or a countdown to there being something.
	if ship == null or yard == null or _rehandling:
		return
	if _in_flight > 0 or can_work():
		_starved = 0.0
		return
	if not ship.is_working():
		_starved = 0.0
		return
	_starved += delta
	if _starved < EXPORT_STARVE_GRACE:
		return
	_starved = 0.0
	# Only the export side can starve like this. A discharge blocked by a full
	# import yard is cleared by the road's draining run, and inventing a slot
	# would be the silent stack-eviction this yard was built to stop.
	if yard.has_exportable():
		_rehandling = true
		_notice("rehandling",
			"Sem carga de exportação livre: este navio vai reembarcar o que trouxe.")
		_emit_status()


func manifest_exclusions() -> PackedStringArray:
	## Which UIDs this call refuses to load. Empty once the berth has been starved
	## long enough that refusing anything would freeze the port.
	return PackedStringArray() if _rehandling else ship.import_manifest_uids()


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
	var active: Array = []
	for record: Dictionary in _active.values(): active.append(record.duplicate(true))
	return {"call_id": call_id, "imports": imports, "exports": exported,
		"active_transfers": active,
		"variant_seed": _variant_seed, "variant_call_index": _variant_call_index,
		"ship": ship.snapshot() if ship != null else {}}


func restore(data: Dictionary) -> void:
	call_id = str(data.get("call_id", ""))
	_imports = _units_from(data.get("imports", []))
	_exported = _units_from(data.get("exports", []))
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
			ship.depart(_channel_out_is_clear())
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
