class_name ContractDB
## Deterministic short-contract definitions. Runtime progress is owned elsewhere.

## Rewards are 180-360 s of production for a 5-10 min window: a contract is
## opt-in, timed active play, and at 60-120 s it paid less than the minutes it
## asked for were already earning. `productive_teus` is measured in seconds of
## the port's own rate (480-560 s inside a 600 s window), because a fixed
## "produce 90 TEU" completed itself the instant a grown port accepted it.
const TEMPLATES: Array[Dictionary] = [
	{"id": "container_turn", "title": "Giro de Contêineres", "description": "Mova carga no turno ativo.", "stat": "containers_moved", "min_target": 12.0, "max_target": 20.0, "active_duration": 300.0, "seconds_of_cps": 180.0},
	{"id": "import_clearance", "title": "Liberação de Importação", "description": "Descarregue importações no turno ativo.", "stat": "imports_moved", "min_target": 8.0, "max_target": 14.0, "active_duration": 480.0, "seconds_of_cps": 270.0},
	{"id": "export_window", "title": "Janela de Exportação", "description": "Embarque exportações no turno ativo.", "stat": "exports_moved", "min_target": 8.0, "max_target": 14.0, "active_duration": 480.0, "seconds_of_cps": 270.0},
	{"id": "berth_schedule", "title": "Agenda de Berço", "description": "Atenda escalas no turno ativo.", "stat": "ships_served", "min_target": 1.0, "max_target": 3.0, "active_duration": 600.0, "seconds_of_cps": 360.0},
	{"id": "yard_expansion", "title": "Pátio em Expansão", "description": "Compre estruturas no turno ativo.", "stat": "structures_bought", "min_target": 2.0, "max_target": 4.0, "active_duration": 300.0, "seconds_of_cps": 180.0},
	{"id": "productive_push", "title": "Impulso Produtivo", "description": "Produza TEUs no turno ativo.", "stat": "productive_teus", "min_target": 480.0, "max_target": 560.0, "target_in_seconds_of_rate": true, "active_duration": 600.0, "seconds_of_cps": 360.0},
]


static func materialize(career_seed: int, offer_index: int, context: Dictionary = {}) -> Dictionary:
	if TEMPLATES.is_empty():
		return {}
	var normalized_index: int = max(0, offer_index)
	var template: Dictionary = TEMPLATES[posmod(normalized_index, TEMPLATES.size())]
	var roll: int = _roll(career_seed, normalized_index)
	var min_target: float = float(template.get("min_target", 1.0))
	var max_target: float = float(template.get("max_target", min_target))
	var steps: int = int(maxf(0.0, max_target - min_target))
	var target: float = min_target + float(posmod(roll, steps + 1))
	var frozen_context := _freeze_context(context)
	if bool(template.get("target_in_seconds_of_rate", false)):
		target = ceilf(target * maxf(1.0, float(frozen_context.projected_rate)))
	var seconds_of_cps := float(template.seconds_of_cps)
	var reward_rate := maxf(float(frozen_context.projected_rate), float(frozen_context.measured_transfer_rate))
	var reward_amount := maxf(30.0, reward_rate * seconds_of_cps)
	return {
		"id": "%s:%d:%d" % [String(template.id), career_seed, normalized_index],
		"template_id": StringName(template.id), "seed": career_seed, "offer_index": normalized_index,
		"title": template.title, "description": template.description,
		"stat": StringName(template.stat), "target": target, "progress": 0.0,
		"active_elapsed": 0.0, "active_duration": float(template.active_duration),
		"status": &"offered", "context": frozen_context,
		"reward": {"kind": "teu", "amount": reward_amount, "minimum": 30.0, "seconds_of_cps": seconds_of_cps, "frozen": true},
	}


static func get_template(id: StringName) -> Dictionary:
	for template in TEMPLATES:
		if StringName(template.get("id", "")) == id:
			return template.duplicate(true)
	return {}


static func is_valid() -> bool:
	var ids := {}
	var stats := {}
	for template in TEMPLATES:
		var id := StringName(template.get("id", ""))
		var stat := StringName(template.get("stat", ""))
		var duration := float(template.get("active_duration", 0.0))
		var reward_seconds := float(template.get("seconds_of_cps", 0.0))
		if id.is_empty() or stat.is_empty() or ids.has(id) or stats.has(stat):
			return false
		if duration not in [300.0, 480.0, 600.0] or reward_seconds not in [180.0, 270.0, 360.0]:
			return false
		if float(template.get("min_target", 0.0)) <= 0.0 or float(template.get("max_target", 0.0)) < float(template.get("min_target", 0.0)):
			return false
		ids[id] = true
		stats[stat] = true
	for required_stat in [&"containers_moved", &"imports_moved", &"exports_moved", &"ships_served", &"structures_bought", &"productive_teus"]:
		if not stats.has(required_stat):
			return false
	return TEMPLATES.size() == 6


static func _freeze_context(context: Dictionary) -> Dictionary:
	return {
		"projected_rate": _non_negative(context.get("projected_rate", 0.0)),
		"measured_transfer_rate": _non_negative(context.get("measured_transfer_rate", 0.0)),
	}


static func _non_negative(raw: Variant) -> float:
	if raw is int or raw is float:
		var value: float = float(raw)
		if is_finite(value) and value >= 0.0:
			return value
	return 0.0


static func _roll(career_seed: int, offer_index: int) -> int:
	# Park-Miller avoids global RNG and is stable across reloads.
	var state: int = posmod(career_seed, 2147483646) + 1
	for _step in range(posmod(offer_index, 97) + 1):
		state = posmod(state * 48271, 2147483647)
	return state
