class_name ProgressionManager
extends Node
## Pure progression state owner for Phase 3. It intentionally does not touch autoloads.
## Hosts may forward game events, persist `snapshot()`, and grant declared rewards.

signal achievement_unlocked(id: StringName, achievement: Dictionary)
signal objective_pinned(id: StringName, objective: Dictionary)
signal objective_progressed(id: StringName, progress: float, target: float)
signal contract_offered(offer: Dictionary)
signal contract_started(contract: Dictionary)
signal contract_updated(contract: Dictionary)
signal contract_finished(contract: Dictionary, completed: bool)
signal journal_entry_added(entry: Dictionary)
signal state_restored(snapshot: Dictionary)
## The ship album changed (a new hull×livery seen, or a page became claimable).
signal album_changed

const SNAPSHOT_VERSION := 2
const RETROACTIVE_EVALUATED_VERSION := 1
const JOURNAL_LIMIT := 200

var career_seed := 0
var stats: Dictionary = {}
var unlocked: Dictionary = {} # achievement id -> immutable unlock record
var pinned_objective: StringName = &""
var journal: Array[Dictionary] = []
var active_contract: Dictionary = {}
var tutorial: Dictionary = {"completed": false, "skipped": false}
var ui: Dictionary = {"buy_mode": "one"}
var _seen_values: Dictionary = {} # stat -> {stable value -> true}
## C7 — the ship album: "silhouette:palette" -> true for every hull×livery that
# has actually arrived, plus "claimed" silhouette ids whose page prize was paid.
var album: Dictionary = {}
var album_claimed: Array[String] = []


func record_ship_variant(variant: Dictionary) -> void:
	## Called when a call is seeded: the album records what *arrived*, and a
	# page (one silhouette in every livery) pays a lump once, when complete.
	var key := "%s:%s" % [str(variant.get("silhouette_id", "")),
		str(variant.get("palette_id", ""))]
	if key.contains(":") and not key.begins_with(":") and not key.ends_with(":") \
			and not album.has(key):
		album[key] = true
		album_changed.emit()
		_request_save(&"album")


func album_seen(silhouette_id: String, palette_id: String) -> bool:
	return album.has("%s:%s" % [silhouette_id, palette_id])


func album_page(silhouette_id: String, palettes_total: int) -> Dictionary:
	## Seen/total for one silhouette, and whether the page prize is unclaimed.
	# The palette list lives in `ShipCatalog`, which this class must not import:
	# pulling it in would drag `PortLayout` -> `GameState` into the headless
	# `--script` suites that load this file standalone. The caller passes the
	# count; the seen keys are all this side needs.
	var seen := 0
	for key in album.keys():
		if str(key).begins_with(silhouette_id + ":"):
			seen += 1
	var complete := seen >= palettes_total
	return {"seen": seen, "total": palettes_total,
		"complete": complete, "claimed": album_claimed.has(silhouette_id)}


func claim_album_page(silhouette_id: String, palettes_total: int) -> bool:
	## Marks the page prize claimed, once. The payment itself is the caller's:
	# this class stays free of `GameState` for the same reason as above.
	var page := album_page(silhouette_id, palettes_total)
	if not bool(page.complete) or album_claimed.has(silhouette_id):
		return false
	album_claimed.append(silhouette_id)
	album_changed.emit()
	_request_save(&"album")
	return true


const ALBUM_PAGE_SECONDS := 300.0
var _session_active := true
var _retroactive_evaluated_version := 0


func _ready() -> void:
	## When used as the sole progression autoload, this remains decoupled from
	## PortWorld and only consumes the global event contracts.
	var events := _autoload(&"EventBus")
	if events != null:
		events.teu_credited.connect(_on_teu_credited)
		events.structure_purchase_committed.connect(_on_structure_purchase)
		events.land_bought.connect(func(_id: String) -> void:
			ingest_event(&"land_bought"))
		events.cargo_transfer_committed.connect(_on_cargo_transfer)
		events.berth_call_completed.connect(_on_berth_completed)
		events.prestige_committed.connect(func(_payload: Dictionary) -> void:
			ingest_event(&"prestiged"))
	achievement_unlocked.connect(_on_achievement_unlocked)
	contract_finished.connect(_on_contract_finished)
	objective_pinned.connect(func(_id: StringName, objective: Dictionary) -> void:
		_emit_event(&"objective_changed", objective))
	contract_updated.connect(func(contract: Dictionary) -> void:
		_emit_event(&"contract_changed", contract))
	call_deferred("_register_persistence")


func _process(delta: float) -> void:
	advance_active_time(delta, not get_tree().paused)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_session_active(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		set_session_active(true)


func _register_persistence() -> void:
	var saver := _autoload(&"SaveManager")
	if saver != null:
		saver.register_section(
			&"progression", snapshot, restore, _seed_new_progression)


func _seed_new_progression() -> void:
	career_seed = int(Time.get_unix_time_from_system())
	stats.clear()
	unlocked.clear()
	pinned_objective = &""
	journal.clear()
	active_contract.clear()
	tutorial = {"completed": false, "skipped": false}
	ui = {"buy_mode": "x1"}
	_seen_values.clear()
	_retroactive_evaluated_version = 0
	_apply_retroactive_game_state()


func _apply_retroactive_game_state() -> void:
	## Older save files did not have event histories. Only infer facts that are
	## objectively present; never invent past cargo, crits or contracts.
	if _retroactive_evaluated_version >= RETROACTIVE_EVALUATED_VERSION:
		return
	var game_state := _autoload(&"GameState")
	if game_state == null:
		_retroactive_evaluated_version = RETROACTIVE_EVALUATED_VERSION
		return
	if game_state.all_time_teus > 0.0:
		stats[&"teus_earned"] = maxf(
			float(stats.get(&"teus_earned", 0.0)), game_state.all_time_teus)
		stats[&"productive_teus"] = maxf(
			float(stats.get(&"productive_teus", 0.0)),
			game_state.all_time_productive_teus)
	var total_structures := 0
	for id: String in game_state.owned:
		var count: int = int(game_state.structure_count(id))
		total_structures += count
		if count > 0:
			stats[StringName("structure_%s" % id)] = float(count)
			var distinct: Dictionary = _seen_values.get(
				&"distinct_structures", {})
			distinct[id] = true
			_seen_values[&"distinct_structures"] = distinct
	stats[&"structures_bought"] = maxf(
		float(stats.get(&"structures_bought", 0.0)), total_structures)
	stats[&"terrain_owned"] = maxf(
		float(stats.get(&"terrain_owned", 0.0)), game_state.land.size())
	stats[&"prestige_count"] = maxf(
		float(stats.get(&"prestige_count", 0.0)), game_state.prestige_count)
	_evaluate_achievements(&"retroactive")
	_retroactive_evaluated_version = RETROACTIVE_EVALUATED_VERSION


func _on_teu_credited(payload: Dictionary) -> void:
	if bool(payload.get("productive", true)):
		ingest_event(&"productive_teu", {
			"teus": float(payload.get("amount", 0.0)), "productive": true,
		})


func _on_structure_purchase(payload: Dictionary) -> void:
	ingest_event(&"structure_bought", {
		"id": payload.get("id", ""),
		"amount": payload.get("quantity", 1),
		"owned_count": payload.get("to_count", 0),
	})


func _on_cargo_transfer(payload: Dictionary) -> void:
	ingest_event(&"container_moved", {
		"count": 1, "sector": payload.get("direction", ""),
		"crit": bool(payload.get("crit", false)),
	})


func _on_berth_completed(payload: Dictionary) -> void:
	ingest_event(&"ship_served", {
		"perfect": bool(payload.get("perfect", true)),
	})


func _on_achievement_unlocked(id: StringName, achievement: Dictionary) -> void:
	var reward: Dictionary = achievement.get("reward", {})
	var game_state := _autoload(&"GameState")
	if StringName(reward.get("kind", "")) == &"teu":
		if game_state != null:
			game_state.grant_nonproductive_reward(float(reward.get("amount", 0.0)))
	_emit_event(&"achievement_completed", {"id": id, "reward": reward.duplicate(true)})
	_request_save(&"achievement")


func _on_contract_finished(contract: Dictionary, completed: bool) -> void:
	if completed:
		var reward: Dictionary = contract.get("reward", {})
		var game_state := _autoload(&"GameState")
		if StringName(reward.get("kind", "")) == &"teu":
			if game_state != null:
				game_state.grant_nonproductive_reward(float(reward.get("amount", 0.0)))
		_emit_event(&"contract_completed", contract)
	_request_save(&"contract")


func _autoload(autoload_name: StringName) -> Node:
	# Headless `--script` suites load this class outside any scene tree; there
	# are no autoloads to find there, and an absolute get_node_or_null from
	# outside the tree is a runtime error that aborts the caller.
	if not is_inside_tree():
		return null
	return get_node_or_null(NodePath("/root/%s" % autoload_name))


func _emit_event(signal_name: StringName, payload: Dictionary) -> void:
	var events := _autoload(&"EventBus")
	if events != null and events.has_signal(signal_name):
		events.emit_signal(signal_name, payload)


func _request_save(reason: StringName) -> void:
	var saver := _autoload(&"SaveManager")
	if saver != null:
		saver.request_save(reason)


func ingest_event(event_id: StringName, payload: Dictionary = {}) -> Dictionary:
	## Normalizes a domain event into cumulative statistics. Unknown events are journaled,
	## not rejected, so integrations can evolve without coupling this class to autoloads.
	var changes := {}
	var amount := _positive(payload.get("count", payload.get("amount", 1.0)), 1.0)
	match event_id:
		&"teu_earned", &"teus_earned", &"productive_teu":
			var teu_amount := _positive(payload.get("teus", payload.get("value", amount)), 0.0)
			changes[&"teus_earned"] = teu_amount
			if event_id == &"productive_teu" or bool(payload.get("productive", true)):
				changes[&"productive_teus"] = teu_amount
		&"container_moved", &"container_unloaded":
			changes[&"containers_moved"] = amount
			var sector := StringName(String(payload.get("sector", payload.get("cargo_type", ""))).to_lower())
			if sector == &"import":
				changes[&"imports_moved"] = amount
			elif sector == &"export":
				changes[&"exports_moved"] = amount
			if bool(payload.get("crit", false)):
				changes[&"critical_hits"] = 1.0
		&"critical_hit":
			changes[&"critical_hits"] = amount
		&"click":
			changes[&"clicks"] = amount
			if bool(payload.get("crit", false)):
				changes[&"critical_hits"] = 1.0
		&"structure_bought":
			changes[&"structures_bought"] = amount
			_mark_distinct(&"distinct_structures", StringName(payload.get("id", "")), changes)
			var structure_id := StringName(payload.get("id", ""))
			if not structure_id.is_empty():
				var structure_stat := StringName("structure_%s" % structure_id)
				changes[structure_stat] = amount
				var inferred_owned := float(stats.get(structure_stat, 0.0)) + amount
				var owned_count := _positive(payload.get("owned_count", inferred_owned), inferred_owned)
				var highest_delta := maxf(0.0, owned_count - float(stats.get(&"highest_structure_count", 0.0)))
				if highest_delta > 0.0:
					changes[&"highest_structure_count"] = highest_delta
		&"ship_served", &"ship_departed":
			changes[&"ships_served"] = amount
			if bool(payload.get("perfect", false)):
				changes[&"perfect_calls"] = amount
		&"route_completed":
			changes[&"routes_completed"] = amount
			var route_id := StringName(payload.get("id", ""))
			_mark_distinct(&"distinct_routes", route_id, changes)
			if not route_id.is_empty():
				changes[StringName("route_%s" % route_id)] = amount
		&"terrain_unlocked", &"land_bought":
			changes[&"terrain_owned"] = amount
		&"event_completed":
			changes[&"events_completed"] = amount
			var event_type := StringName(payload.get("id", payload.get("event_type", "")))
			if not event_type.is_empty():
				changes[StringName("event_%s" % event_type)] = amount
		&"collectible_found":
			changes[&"collectibles_found"] = amount
		&"perfect_call", &"ship_call_perfect":
			changes[&"perfect_calls"] = amount
		&"prestiged", &"prestige":
			changes[&"prestige_count"] = amount
		&"tutorial_completed":
			if not bool(tutorial.get("completed", false)):
				tutorial = {"completed": true, "skipped": bool(payload.get("skipped", false))}
				if not bool(tutorial.skipped):
					changes[&"tutorial_unskipped"] = 1.0
		_:
			_add_journal(&"event", {"event_id": event_id, "known": false})
	return ingest_statistics(changes, event_id)


func ingest_statistics(changes: Dictionary, source: StringName = &"statistics") -> Dictionary:
	## Adds finite positive deltas. Statistics are cumulative and safe to replay only
	## when the caller uses its own event ledger; unlocks remain idempotent either way.
	var accepted := {}
	for raw_key in changes:
		var key := StringName(raw_key)
		var delta := _positive(changes[raw_key], 0.0)
		if key.is_empty() or delta <= 0.0:
			continue
		stats[key] = float(stats.get(key, 0.0)) + delta
		accepted[key] = delta
	if not accepted.is_empty():
		_update_contract(accepted, source)
		_evaluate_achievements(source)
	return accepted.duplicate()


func advance_active_time(delta: float, is_active: bool = true) -> float:
	## Only explicit active time is counted; paused/background callers pass false.
	if not _session_active or not is_active:
		return 0.0
	var accepted := _positive(delta, 0.0)
	if accepted <= 0.0:
		return 0.0
	ingest_statistics({&"active_seconds": accepted}, &"active_time")
	return accepted


func set_session_active(value: bool) -> void:
	_session_active = value


func is_session_active() -> bool:
	return _session_active


func materialize_contract_offer(career_seed_value: int, offer_index: int, context: Dictionary = {}) -> Dictionary:
	var offer := ContractDB.materialize(career_seed_value, offer_index, context)
	if not offer.is_empty():
		contract_offered.emit(offer.duplicate(true))
	return offer


func accept_contract(offer: Dictionary) -> bool:
	## Exactly one active contract is allowed. Accept only a canonical materialized offer.
	if not active_contract.is_empty() or offer.is_empty():
		return false
	var offer_seed := int(offer.get("seed", 0))
	var offer_index := int(offer.get("offer_index", -1))
	if offer_index < 0:
		return false
	var canonical := ContractDB.materialize(offer_seed, offer_index, offer.get("context", {}))
	if canonical.is_empty() or String(canonical.id) != String(offer.get("id", "")):
		return false
	canonical.status = &"active"
	active_contract = canonical
	contract_started.emit(active_contract.duplicate(true))
	_add_journal(&"contract_started", {"id": active_contract.id})
	return true


func start_contract(career_seed_value: int, offer_index: int, context: Dictionary = {}) -> bool:
	return accept_contract(ContractDB.materialize(career_seed_value, offer_index, context))


func get_active_contract() -> Dictionary:
	return active_contract.duplicate(true)


func pin_objective(id: StringName) -> bool:
	if AchievementDB.get_item(id).is_empty():
		return false
	pinned_objective = id
	objective_pinned.emit(id, get_pinned_objective())
	return true


func clear_pinned_objective() -> void:
	pinned_objective = &""


func set_career_seed(career_seed_value: int) -> void:
	career_seed = career_seed_value


func set_buy_mode(mode: StringName) -> void:
	if not mode.is_empty():
		ui["buy_mode"] = String(mode)


func get_objective_progress(id: StringName) -> Dictionary:
	var achievement := AchievementDB.get_item(id)
	if achievement.is_empty():
		return {}
	var stat := StringName(achievement.stat)
	var target := float(achievement.threshold)
	var progress := minf(float(stats.get(stat, 0.0)), target)
	return {
		"id": id, "title": achievement.title, "description": achievement.description,
		"stat": stat, "progress": progress, "target": target,
		# The category travels with the objective because the trophy board groups
		# by it, and a screen that has to re-open `AchievementDB` to find out what
		# it is already holding is a screen reading the same table twice.
		"category": StringName(achievement.get("category", "")),
		"complete": unlocked.has(id), "reward": achievement.reward.duplicate(true),
	}


func get_pinned_objective() -> Dictionary:
	if pinned_objective.is_empty():
		return {}
	var objective := get_objective_progress(pinned_objective)
	objective["pinned"] = true
	return objective


func get_all_objectives(include_hidden: bool = false) -> Array[Dictionary]:
	var objectives: Array[Dictionary] = []
	for achievement: Dictionary in AchievementDB.ITEMS:
		if not include_hidden and not String(achievement.get("requires_feature", "")).is_empty():
			continue
		var objective := get_objective_progress(StringName(achievement.id))
		objective["pinned"] = StringName(objective.get("id", "")) == pinned_objective
		objectives.append(objective)
	return objectives


func get_recommended_objective() -> Dictionary:
	if not pinned_objective.is_empty():
		return get_pinned_objective()
	var best: Dictionary = {}
	var best_ratio := INF
	for objective: Dictionary in get_all_objectives():
		if bool(objective.get("complete", false)):
			continue
		var target := maxf(1.0, float(objective.get("target", 1.0)))
		var remaining := maxf(0.0, target - float(objective.get("progress", 0.0)))
		var ratio := remaining / target
		if ratio < best_ratio:
			best_ratio = ratio
			best = objective
	return best


func snapshot() -> Dictionary:
	return {
		"schema_version": SNAPSHOT_VERSION,
		"career_seed": career_seed,
		"stats": stats.duplicate(true),
		"achievements": unlocked.duplicate(true),
		"pinned_objective": {"kind": "achievement", "id": String(pinned_objective)} if not pinned_objective.is_empty() else {},
		"tutorial": tutorial.duplicate(true),
		"contracts": {"active": active_contract.duplicate(true)},
		"ui": {"buy_mode": String(ui.get("buy_mode", "one"))},
		"retroactive_evaluated_version": _retroactive_evaluated_version,
		"journal": journal.duplicate(true),
		"seen_values": _seen_values.duplicate(true),
		"album": album.duplicate(true),
		"album_claimed": album_claimed.duplicate(),
		"session_active": _session_active,
	}


func restore(data: Dictionary) -> void:
	## Restore may discover achievements introduced after an old save. It evaluates
	## after state hydration, while existing unlock IDs prevent duplicate rewards/signals.
	var previously_unlocked := unlocked.duplicate(true)
	career_seed = int(data.get("career_seed", career_seed))
	stats = _numbers_only(data.get("stats", {}))
	unlocked = _unlock_records_only(data.get("achievements", data.get("unlocked", {})))
	# A legacy snapshot can lack an unlock that was already granted retroactively
	# during this process lifetime. Retain it only when its restored requirement
	# is still satisfied, making repeated restores idempotent without polluting a
	# genuinely lower-progress save.
	for raw_id in previously_unlocked:
		var prior_id := StringName(raw_id)
		var prior_achievement := AchievementDB.get_item(prior_id)
		if not prior_achievement.is_empty() \
				and float(stats.get(StringName(prior_achievement.stat), 0.0)) >= float(prior_achievement.threshold):
			unlocked[prior_id] = previously_unlocked[raw_id]
	pinned_objective = _restore_pin(data.get("pinned_objective", {}))
	if AchievementDB.get_item(pinned_objective).is_empty():
		pinned_objective = &""
	journal = _journal_only(data.get("journal", []))
	_seen_values = _seen_only(data.get("seen_values", {}))
	# The album is a flat "silhouette:palette" -> true map, not a nested
	# stat map, so it is not restored through `_seen_only`.
	album = {}
	var raw_album: Variant = data.get("album", {})
	if raw_album is Dictionary:
		for key in raw_album:
			album[str(key)] = true
	album_claimed = []
	for entry in data.get("album_claimed", []):
		album_claimed.append(str(entry))
	_session_active = bool(data.get("session_active", true))
	tutorial = _tutorial_only(data.get("tutorial", {}))
	ui = _ui_only(data.get("ui", {}))
	var contracts_raw: Variant = data.get("contracts", {})
	active_contract = _restore_contract(contracts_raw.get("active", {}) if contracts_raw is Dictionary else data.get("active_contract", {}))
	_retroactive_evaluated_version = int(data.get("retroactive_evaluated_version", 0))
	_evaluate_achievements(&"restore")
	_retroactive_evaluated_version = max(_retroactive_evaluated_version, RETROACTIVE_EVALUATED_VERSION)
	state_restored.emit(snapshot())


func _update_contract(changes: Dictionary, source: StringName) -> void:
	if active_contract.is_empty() or not _session_active:
		return
	var stat := StringName(active_contract.get("stat", ""))
	var delta := float(changes.get(stat, 0.0))
	var active_delta := float(changes.get(&"active_seconds", 0.0))
	if active_delta > 0.0:
		active_contract.active_elapsed = float(active_contract.get("active_elapsed", 0.0)) + active_delta
	if delta > 0.0:
		active_contract.progress = minf(float(active_contract.get("target", 0.0)), float(active_contract.get("progress", 0.0)) + delta)
		contract_updated.emit(active_contract.duplicate(true))
	if float(active_contract.get("progress", 0.0)) >= float(active_contract.get("target", 0.0)):
		_finish_contract(true, source)
	elif float(active_contract.get("active_elapsed", 0.0)) >= float(active_contract.get("active_duration", INF)):
		_finish_contract(false, source)


func _finish_contract(completed: bool, source: StringName) -> void:
	if active_contract.is_empty():
		return
	var finished := active_contract.duplicate(true)
	finished.status = &"completed" if completed else &"expired"
	active_contract.clear()
	contract_finished.emit(finished.duplicate(true), completed)
	_add_journal(&"contract_completed" if completed else &"contract_expired", {"id": finished.id, "source": source, "reward": finished.reward if completed else {}})
	if completed:
		ingest_statistics({&"contracts_completed": 1.0}, &"contract_completed")


func _evaluate_achievements(source: StringName) -> void:
	for achievement in AchievementDB.ITEMS:
		var id := StringName(achievement.id)
		var target := float(achievement.threshold)
		if float(stats.get(StringName(achievement.stat), 0.0)) >= target:
			if not unlocked.has(id):
				unlocked[id] = {"id": id, "unlocked_at_active": float(stats.get(&"active_seconds", 0.0)), "reward": achievement.reward.duplicate(true)}
				achievement_unlocked.emit(id, achievement.duplicate(true))
				_add_journal(&"achievement_unlocked", {"id": id, "source": source, "reward": achievement.reward.duplicate(true)})
			if pinned_objective == id:
				objective_progressed.emit(id, minf(float(stats.get(StringName(achievement.stat), 0.0)), target), target)


func _mark_distinct(stat: StringName, value: StringName, changes: Dictionary) -> void:
	if value.is_empty():
		return
	if not _seen_values.has(stat):
		_seen_values[stat] = {}
	var values: Dictionary = _seen_values[stat]
	if not values.has(value):
		values[value] = true
		changes[stat] = 1.0


func _add_journal(kind: StringName, details: Dictionary = {}) -> void:
	var entry := {"kind": kind, "active_time": float(stats.get(&"active_seconds", 0.0)), "details": details.duplicate(true)}
	journal.append(entry)
	while journal.size() > JOURNAL_LIMIT:
		journal.pop_front()
	journal_entry_added.emit(entry.duplicate(true))


func _restore_contract(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.is_empty():
		return {}
	var offer_index := int(raw.get("offer_index", -1))
	if offer_index < 0:
		return {}
	var restored := ContractDB.materialize(int(raw.get("seed", 0)), offer_index, raw.get("context", {}))
	if restored.is_empty() or String(restored.id) != String(raw.get("id", "")):
		return {}
	if StringName(raw.get("status", &"")) != &"active":
		return {}
	restored.status = &"active"
	restored.progress = clampf(_positive(raw.get("progress", 0.0), 0.0), 0.0, float(restored.target))
	restored.active_elapsed = maxf(0.0, _positive(raw.get("active_elapsed", 0.0), 0.0))
	return restored


func _restore_pin(raw: Variant) -> StringName:
	if raw is Dictionary:
		if StringName(raw.get("kind", "")) == &"achievement":
			return StringName(raw.get("id", ""))
	elif raw is String or raw is StringName:
		# Compatibility with the first Phase 3 snapshot draft.
		return StringName(raw)
	return &""


func _tutorial_only(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {"completed": false, "skipped": false}
	return {"completed": bool(raw.get("completed", false)), "skipped": bool(raw.get("skipped", false))}


func _ui_only(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {"buy_mode": "one"}
	var buy_mode := String(raw.get("buy_mode", "one"))
	return {"buy_mode": buy_mode if not buy_mode.is_empty() else "one"}


func _numbers_only(raw: Variant) -> Dictionary:
	var result := {}
	if not raw is Dictionary:
		return result
	for key in raw:
		var value := _positive(raw[key], 0.0)
		if value > 0.0:
			result[StringName(key)] = value
	return result


func _unlock_records_only(raw: Variant) -> Dictionary:
	var result := {}
	if not raw is Dictionary:
		return result
	for key in raw:
		var id := StringName(key)
		if not AchievementDB.get_item(id).is_empty():
			var record: Dictionary = raw[key] if raw[key] is Dictionary else {}
			result[id] = record.duplicate(true)
	return result


func _journal_only(raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw is Array:
		return result
	for entry in raw:
		if entry is Dictionary:
			result.append(entry.duplicate(true))
	while result.size() > JOURNAL_LIMIT:
		result.pop_front()
	return result


func _seen_only(raw: Variant) -> Dictionary:
	var result := {}
	if not raw is Dictionary:
		return result
	for stat in raw:
		if raw[stat] is Dictionary:
			result[StringName(stat)] = raw[stat].duplicate(true)
	return result


func _positive(raw: Variant, fallback: float) -> float:
	if raw is int or raw is float:
		var value := float(raw)
		if is_finite(value) and value > 0.0:
			return value
	return fallback
