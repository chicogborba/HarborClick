class_name TaskBoard
extends RefCounted
## What the terminal needs next, and exactly one owner for each of it.
##
## The port is a chain of stations (see `NpcCatalog`), and a *need* is a station
## with work waiting at it: a hull with boxes still on board, a block that wants
## re-stacking, a truck parked with its paperwork unsigned. Needs are derived from
## the live world every time they are asked for — never stored — so the board can
## not drift from the terminal it describes.
##
## Two rules make the whole thing work:
##
## 1. **A need has a key, and a key has one claimant.** Keys are scoped to the
##    physical thing being worked (`pilha:bloco3`, `portao:baia1`,
##    `estrada:patio47`), so two people cannot be given the same job — not
##    because something checks afterwards, but because there is only one key.
## 2. **The board does not move cargo.** `BerthCallController`, `GateDock` and
##    `PortWorld` remain the only things that can create, destroy or hand over a
##    `CargoUnit`. The board decides *who* is doing it and can say so in
##    Portuguese; the transaction path is untouched.
##
## The one need that reserves something real is the land-side haul, because
## `PortWorld.request_job` has to reserve yard capacity to describe a delivery.
## That goes through `claim_haul`, which is also what stops two drivers being
## sent to the same stack — the bug the old free-for-all had.

signal task_completed(profile: NpcProfile, task: Dictionary)

const KIND_SHIP_TO_YARD: StringName = &"ship_to_yard"
const KIND_YARD_TO_SHIP: StringName = &"yard_to_ship"
const KIND_RESTACK: StringName = &"restack"
const KIND_CHECK_BERTH: StringName = &"check_berth"
const KIND_CHECK_BLOCK: StringName = &"check_block"
const KIND_CHECK_GATE: StringName = &"check_gate"
const KIND_HAUL_OUT: StringName = &"haul_out"
const KIND_HAUL_IN: StringName = &"haul_in"
const KIND_RELEASE_BAY: StringName = &"release_bay"
const KIND_ESCORT: StringName = &"escort"
const KIND_STANDBY: StringName = &"standby"
const KIND_ROAD_TRIP: StringName = &"road_trip"

const STAGE_TO_TARGET: StringName = &"a_caminho"
const STAGE_WORKING: StringName = &"trabalhando"
const STAGE_RETURNING: StringName = &"retornando"

## How many people can be working one hull at once. It is the quay crane cap,
## because that is physically what limits it.
const BERTH_SEATS := 2

var world: PortWorld
var crew: NpcRoster

var _claims: Dictionary = {}     # task key -> {ref: WeakRef, id: int}
var _tasks: Dictionary = {}      # claimant instance id -> task dictionary


func setup(p_world: PortWorld, p_crew: NpcRoster) -> void:
	world = p_world
	crew = p_crew


# ------------------------------------------------------------------- claiming

func claim(claimant: Object, station: StringName, prefer: String = "",
		exact: bool = false) -> Dictionary:
	## The claimant's task at this station, taking a new one if it holds none.
	##
	## `prefer` asks for one particular key — a transtainer works its own block
	## and nothing else — and `exact` refuses anything but that key.
	##
	## The returned dictionary is the board's own, so a claimant may write its
	## `stage` into it and the crew card reads that back.
	if claimant == null:
		return {}
	_prune()
	var mine := task_of(claimant)
	if not mine.is_empty():
		return mine
	var chosen: Dictionary = {}
	for need in open_needs(station):
		var key := str(need.get("key", ""))
		if key.is_empty() or is_claimed(key):
			continue
		if not prefer.is_empty() and key == prefer:
			chosen = need
			break
		if exact:
			continue
		if chosen.is_empty():
			chosen = need
	if chosen.is_empty():
		return {}
	return _register(claimant, chosen)


func claim_haul(claimant: Object) -> Dictionary:
	## The land-side station. Unlike every other need, describing this one
	## reserves real yard capacity, so it is claimed through the same call that
	## asks for it — and the excluded-uid list makes sure the job offered is never
	## the box another driver is already on their way to collect.
	if claimant == null or world == null:
		return {}
	_prune()
	var mine := task_of(claimant)
	if not mine.is_empty():
		return mine
	var job: Dictionary = world.request_job(claimed_uids())
	if job.is_empty():
		return {}
	var pickup := str(job.get("type", "")) == "pickup"
	var slot := int(job.get("slot", -1))
	var key := "estrada:patio%d" % slot if pickup \
		else "estrada:entrega:%s" % str(job.get("token", ""))
	if is_claimed(key):
		world.cancel_job(job)
		return {}
	var meta := {"slot": slot}
	if pickup and world.yard != null:
		meta["uid"] = world.yard.top_uid(slot)
	else:
		meta["block"] = _block_of_slot(slot)
	var where: Vector2 = job.get("pos", Vector2.ZERO)
	return _register(claimant, {
		"key": key, "station": NpcCatalog.STATION_ROAD,
		"kind": KIND_HAUL_OUT if pickup else KIND_HAUL_IN,
		"where": where, "meta": meta, "job": job,
	})


func release(claimant: Object) -> void:
	if claimant == null:
		return
	var id := claimant.get_instance_id()
	var task: Dictionary = _tasks.get(id, {})
	if not task.is_empty():
		_claims.erase(str(task.get("key", "")))
	_tasks.erase(id)


func complete(claimant: Object) -> void:
	## The job is done: it goes on the person's tally and the key opens again.
	var task: Dictionary = task_of(claimant)
	var profile := _profile_of(claimant)
	if crew != null and profile != null:
		crew.record_move(profile)
	if not task.is_empty():
		task_completed.emit(profile, task.duplicate(true))
	release(claimant)


func set_stage(claimant: Object, stage: StringName) -> void:
	var task: Dictionary = task_of(claimant)
	if not task.is_empty():
		task["stage"] = stage


func task_of(claimant: Object) -> Dictionary:
	if claimant == null:
		return {}
	return _tasks.get(claimant.get_instance_id(), {})


func is_claimed(key: String) -> bool:
	var claim: Dictionary = _claims.get(key, {})
	if claim.is_empty():
		return false
	var ref: WeakRef = claim.get("ref")
	if ref == null or ref.get_ref() == null:
		_drop(key, int(claim.get("id", 0)))
		return false
	return true


func claimed_uids() -> PackedStringArray:
	## The identities already spoken for by somebody on their way to collect one.
	var uids := PackedStringArray()
	for id: int in _tasks.keys():
		var meta: Dictionary = (_tasks[id] as Dictionary).get("meta", {})
		var uid := str(meta.get("uid", ""))
		if not uid.is_empty():
			uids.append(uid)
	return uids


func claimed_uids_except(claimant: Object) -> PackedStringArray:
	## Everything claimed by somebody *else*. A driver standing at its own stack
	## must not be told that its own box is unavailable.
	var mine := str((task_of(claimant).get("meta", {}) as Dictionary).get("uid", ""))
	var uids := PackedStringArray()
	for uid in claimed_uids():
		if uid != mine:
			uids.append(uid)
	return uids


func assignments() -> Array[Dictionary]:
	## Everything being worked right now, for the crew card and for the suite that
	## proves no two people share a key.
	var rows: Array[Dictionary] = []
	_prune()
	for key: String in _claims.keys():
		var claim: Dictionary = _claims[key]
		var task: Dictionary = _tasks.get(int(claim.get("id", 0)), {})
		var profile := _profile_of((claim.get("ref") as WeakRef).get_ref())
		rows.append({
			"key": key,
			"kind": task.get("kind", &""),
			"station": task.get("station", &""),
			"stage": task.get("stage", STAGE_TO_TARGET),
			"label": label_for(task),
			"name": profile.display_name if profile != null else "",
		})
	return rows


func clear() -> void:
	_claims.clear()
	_tasks.clear()


# ---------------------------------------------------------------------- needs

func open_needs(station: StringName) -> Array[Dictionary]:
	## Read-only, derived, ordered by what the terminal most wants done.
	match station:
		NpcCatalog.STATION_BERTH:
			return _berth_needs()
		NpcCatalog.STATION_YARD:
			return _yard_needs()
		NpcCatalog.STATION_STACK:
			return _stack_needs()
		NpcCatalog.STATION_GATE:
			return _gate_needs()
		NpcCatalog.STATION_MANOEUVRE:
			return _manoeuvre_needs()
		NpcCatalog.STATION_CITY:
			return _city_needs()
	return []


func _berth_needs() -> Array[Dictionary]:
	## Every berth being worked offers its own seats, keyed on the berth, so a
	## portainer on berth 2 and one on berth 1 are never given the same job.
	var needs: Array[Dictionary] = []
	if world == null or world.yard == null:
		return needs
	var hulls := world.berth_hulls()
	for berth_index in hulls.size():
		var ship: Ship = hulls[berth_index]
		if not ship.is_working():
			continue
		var quay := Vector2(PortLayout.quay_lane_x(),
			PortLayout.berth_y(berth_index) + 70.0)
		var seats := 0
		var kind := KIND_SHIP_TO_YARD
		if ship.is_discharging():
			if not world.yard.can_accept(CargoUnit.IMPORT):
				continue
			seats = mini(BERTH_SEATS, ship.cargo_left())
		else:
			var progress := ship.export_progress()
			if progress.x >= progress.y \
					or not world.yard.has_exportable(ship.import_manifest_uids()):
				continue
			kind = KIND_YARD_TO_SHIP
			seats = mini(BERTH_SEATS, progress.y - progress.x)
		for seat in seats:
			needs.append({
				"key": "berco%d:%s#%d" % [berth_index,
					"descarga" if kind == KIND_SHIP_TO_YARD else "embarque", seat],
				"station": NpcCatalog.STATION_BERTH, "kind": kind,
				"where": quay + Vector2(0.0, seat * 48.0),
				"meta": {"seat": seat, "berth": berth_index},
			})
	return needs


func _yard_needs() -> Array[Dictionary]:
	## The conferente follows the cargo: the berth while a hull is alongside, then
	## the trucks on the apron, then the blocks that hold stock.
	var needs: Array[Dictionary] = []
	if world == null or world.yard == null:
		return needs
	var hulls := world.berth_hulls()
	for berth_index in hulls.size():
		if not hulls[berth_index].is_working():
			continue
		needs.append({
			"key": "patio:berco%d" % berth_index,
			"station": NpcCatalog.STATION_YARD, "kind": KIND_CHECK_BERTH,
			"where": Vector2(PortLayout.QUAY_X0 - 16.0,
				PortLayout.berth_y(berth_index) + 90.0),
			"meta": {"berth": berth_index},
		})
	for bay in _docked_bays():
		needs.append({
			"key": "patio:baia%d" % bay, "station": NpcCatalog.STATION_YARD,
			"kind": KIND_CHECK_GATE,
			"where": PortLayout.gate_bay_centre(bay) + Vector2(-16.0, 6.0),
			"meta": {"bay": bay},
		})
	for block in PortLayout.block_count():
		if world.yard.block_top_color(block) < 0:
			continue
		needs.append({
			"key": "patio:bloco%d" % block, "station": NpcCatalog.STATION_YARD,
			"kind": KIND_CHECK_BLOCK,
			"where": Vector2(PortLayout.block_origin(block).x + PortLayout.BLOCK_W * 0.5,
				PortLayout.block_lane_y(block)),
			"meta": {"block": block},
		})
	return needs


func _stack_needs() -> Array[Dictionary]:
	var needs: Array[Dictionary] = []
	if world == null or world.yard == null:
		return needs
	for block in PortLayout.block_count():
		if world.yard.block_top_color(block) < 0:
			continue
		needs.append({
			"key": "pilha:bloco%d" % block, "station": NpcCatalog.STATION_STACK,
			"kind": KIND_RESTACK, "where": PortLayout.block_origin(block),
			"meta": {"block": block},
		})
	return needs


func _gate_needs() -> Array[Dictionary]:
	var needs: Array[Dictionary] = []
	for bay in _docked_bays():
		needs.append({
			"key": "portao:baia%d" % bay, "station": NpcCatalog.STATION_GATE,
			"kind": KIND_RELEASE_BAY,
			"where": PortLayout.gate_bay_centre(bay), "meta": {"bay": bay},
		})
	return needs


func _manoeuvre_needs() -> Array[Dictionary]:
	## One manoeuvre at a time, whichever berth it belongs to: the berths share a
	## fairway, so only one hull is ever under way.
	var needs: Array[Dictionary] = []
	if world == null:
		return needs
	var moving: Ship = world.manoeuvring_ship()
	var subject := moving
	if subject == null:
		var busy := world.working_ships()
		if busy.is_empty():
			return needs
		subject = busy[0]
	for seat in 2:
		needs.append({
			"key": "manobra:%s#%d" % ["escolta" if moving != null else "espera", seat],
			"station": NpcCatalog.STATION_MANOEUVRE,
			"kind": KIND_ESCORT if moving != null else KIND_STANDBY,
			"where": subject.hull_centre(),
			"meta": {"seat": seat, "berth": subject.berth_index},
		})
	return needs


func _city_needs() -> Array[Dictionary]:
	var needs: Array[Dictionary] = []
	if world == null or world.gate == null:
		return needs
	for bay: int in world.gate.bays.keys():
		needs.append({
			"key": "cidade:baia%d" % bay, "station": NpcCatalog.STATION_CITY,
			"kind": KIND_ROAD_TRIP,
			"where": PortLayout.gate_bay_centre(bay), "meta": {"bay": bay},
		})
	return needs


func _docked_bays() -> Array[int]:
	var bays: Array[int] = []
	if world == null or world.gate == null:
		return bays
	for bay: int in world.gate.bays.keys():
		var record: Dictionary = world.gate.bays[bay]
		if int(record.get("stage", GateDock.Stage.DOCKED)) == int(GateDock.Stage.DOCKED):
			bays.append(bay)
	bays.sort()
	return bays


# --------------------------------------------------------------------- labels

func label_of(claimant: Object) -> String:
	return label_for(task_of(claimant))


func label_for(task: Dictionary) -> String:
	## Rebuilt from live state every time it is read, so a card that stays open
	## while the berth works counts up instead of freezing on the claim.
	if task.is_empty():
		return ""
	var meta: Dictionary = task.get("meta", {})
	match StringName(task.get("kind", &"")):
		KIND_SHIP_TO_YARD:
			return "Descarregando o navio do berço %d para o pátio%s" % [
				int(meta.get("berth", 0)) + 1,
				_berth_progress(int(meta.get("berth", 0)))]
		KIND_YARD_TO_SHIP:
			return "Embarcando exportação no berço %d%s" % [
				int(meta.get("berth", 0)) + 1,
				_berth_progress(int(meta.get("berth", 0)))]
		KIND_RESTACK:
			return "Arrumando a pilha do bloco %d" % (int(meta.get("block", 0)) + 1)
		KIND_CHECK_BERTH:
			return "Conferindo a carga no berço %d" % (int(meta.get("berth", 0)) + 1)
		KIND_CHECK_BLOCK:
			return "Conferindo lacres no bloco %d" % (int(meta.get("block", 0)) + 1)
		KIND_CHECK_GATE:
			return "Conferindo a carreta na baia %d" % (int(meta.get("bay", 0)) + 1)
		KIND_HAUL_OUT:
			return "Levando um contêiner do bloco %d ao portão" \
				% (_block_of_slot(int(meta.get("slot", 0))) + 1)
		KIND_HAUL_IN:
			return "Trazendo um contêiner da cidade para o bloco %d" \
				% (int(meta.get("block", 0)) + 1)
		KIND_RELEASE_BAY:
			return "Liberando a carreta da baia %d" % (int(meta.get("bay", 0)) + 1)
		KIND_ESCORT:
			# Both tugs work one manoeuvre, one on each quarter, and the seat is
			# the side they are really on. Two people on the same job have to be
			# able to say which half of it is theirs.
			return "Assistindo a manobra pela alheta de %s" \
				% _quarter(int(meta.get("seat", 0)))
		KIND_STANDBY:
			return "De prontidão a %s do navio atracado" \
				% _quarter(int(meta.get("seat", 0)))
		KIND_ROAD_TRIP:
			return _road_trip_label(int(meta.get("bay", 0)))
	return ""


func stage_text(stage: StringName) -> String:
	match stage:
		STAGE_WORKING:
			return "trabalhando"
		STAGE_RETURNING:
			return "voltando"
	return "a caminho"


func _quarter(seat: int) -> String:
	## `StructureActor` puts even-indexed tugs on the port quarter, and the seat a
	## tug claims is its own index, so this is the side it is actually on.
	return "bombordo" if seat % 2 == 0 else "estibordo"


func _berth_progress(berth_index: int) -> String:
	if world == null:
		return ""
	var hulls := world.berth_hulls()
	if berth_index < 0 or berth_index >= hulls.size():
		return ""
	var ship: Ship = hulls[berth_index]
	if not ship.is_working():
		return ""
	var total := ship.bay_capacity()
	var done := total - ship.cargo_left() if ship.is_discharging() \
		else ship.export_progress().x
	return " (%d/%d)" % [done, total]


func _road_trip_label(bay: int) -> String:
	if world == null or world.gate == null or not world.gate.bays.has(bay):
		return "Voltando para a cidade"
	var record: Dictionary = world.gate.bays[bay]
	var stage := int(record.get("stage", GateDock.Stage.DOCKED))
	if stage == int(GateDock.Stage.ARRIVING):
		return "Entrando pelo portão com %d contêiner(es)" \
			% (record.get("cargo", []) as Array).size()
	if stage == int(GateDock.Stage.LEAVING):
		return "Saindo para a cidade com %d contêiner(es)" \
			% (record.get("cargo", []) as Array).size()
	var drops := int(record.get("drops", 0))
	if drops > 0:
		return "Entregando %d contêiner(es) da cidade" % drops
	if int(record.get("lifts", 0)) > 0:
		return "Esperando carga do pátio para levar"
	return "Pronto para sair da baia %d" % (bay + 1)


# ------------------------------------------------------------------ internals

func _profile_of(claimant: Object) -> NpcProfile:
	## A machine carries its operator in `profile`; a road truck carries its
	## driver in `driver`. Either way there is one person behind the claim.
	if claimant == null:
		return null
	if claimant.get("profile") is NpcProfile:
		return claimant.get("profile")
	if claimant.get("driver") is NpcProfile:
		return claimant.get("driver")
	return null


func _register(claimant: Object, task: Dictionary) -> Dictionary:
	var stored := task.duplicate(true)
	stored["stage"] = STAGE_TO_TARGET
	var id := claimant.get_instance_id()
	_claims[str(stored.key)] = {"ref": weakref(claimant), "id": id}
	_tasks[id] = stored
	return stored


func _prune() -> void:
	## Actors are freed by the dozen on a rebuild. A claim whose claimant is gone
	## would hold its key for ever and starve the station.
	for key: String in _claims.keys():
		var claim: Dictionary = _claims[key]
		var ref: WeakRef = claim.get("ref")
		if ref == null or ref.get_ref() == null:
			_drop(key, int(claim.get("id", 0)))


func _drop(key: String, id: int) -> void:
	_claims.erase(key)
	_tasks.erase(id)


func _block_of_slot(slot: int) -> int:
	if slot < 0:
		return 0
	@warning_ignore("integer_division")
	var block := slot / ContainerYard.SLOTS_PER_BLOCK
	return block
