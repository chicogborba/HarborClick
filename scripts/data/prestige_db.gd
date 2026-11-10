class_name PrestigeDB
## Declarative prestige branches. A future economy owner applies these effects.

const BRANCHES: Array[Dictionary] = [
	# `throughput_structural` used to be `scope: "structures", cps_multiplier`,
	# which `GameState` multiplied into the same product as `scope: "global"`. Two
	# names, two prices, one number: the scope did not exist. It now pays per kind
	# of machine the terminal runs a real fleet of, which is a shape the global
	# node cannot reproduce — one rewards a wide port, the other a big one.
	{"id": "throughput", "title": "Vazão", "nodes": [
		{"id": "throughput_structural", "title": "Malha Diversa", "cost": 1, "effect": {"scope": "structures", "stat": "cps_per_kind", "operation": "add_pct", "value": 0.06}},
		{"id": "throughput_global", "title": "Vazão Geral", "cost": 3, "requires": ["throughput_structural"], "effect": {"scope": "global", "stat": "cps_multiplier", "operation": "add_pct", "value": 0.20}},
	]},
	{"id": "click", "title": "Clique", "nodes": [
		{"id": "click_manual", "title": "Braço Firme", "cost": 1, "effect": {"scope": "manual", "stat": "click_multiplier", "operation": "add_pct", "value": 0.50}},
		{"id": "click_cps_per_tap", "title": "Mão na Massa", "cost": 3, "requires": ["click_manual"], "effect": {"scope": "manual", "stat": "cps_per_tap", "operation": "add_pct", "value": 0.01}},
	]},
	# Every node here must beat the port's baseline (50% efficiency, 8h cap in
	# `GameState`). The first two versions of this branch sold `set 0.50` and
	# `set 28800.0`, which are the defaults: the player paid three golden shares
	# for nothing. `LEGACY_NODE_IDS` carries those purchases forward.
	{"id": "offline", "title": "Offline", "nodes": [
		{"id": "offline_eff_60", "title": "Turno da Noite", "cost": 1, "effect": {"scope": "offline", "stat": "offline_efficiency", "operation": "set", "value": 0.60}},
		{"id": "offline_eff_75", "title": "Turno Integral", "cost": 3, "requires": ["offline_eff_60"], "effect": {"scope": "offline", "stat": "offline_efficiency", "operation": "set", "value": 0.75}},
		{"id": "offline_cap_12h", "title": "Plantão de 12h", "cost": 2, "requires": ["offline_eff_60"], "effect": {"scope": "offline", "stat": "offline_cap_seconds", "operation": "set", "value": 43200.0}},
		{"id": "offline_cap_16h", "title": "Plantão de 16h", "cost": 5, "requires": ["offline_eff_75", "offline_cap_12h"], "effect": {"scope": "offline", "stat": "offline_cap_seconds", "operation": "set", "value": 57600.0}},
	]},
	{"id": "routes", "title": "Rotas", "requires_feature": "routes", "nodes": [
		{"id": "routes_reward", "title": "Frete Melhor", "cost": 1, "requires_feature": "routes", "effect": {"scope": "routes", "stat": "route_reward_multiplier", "operation": "add_pct", "value": 0.10}},
		{"id": "routes_slot", "title": "Segunda Rota", "cost": 3, "requires": ["routes_reward"], "requires_feature": "routes", "effect": {"scope": "routes", "stat": "route_slots", "operation": "add_flat", "value": 1.0}},
	]},
	{"id": "events", "title": "Eventos", "requires_feature": "events", "nodes": [
		{"id": "events_reward", "title": "Prêmio Maior", "cost": 1, "requires_feature": "events", "effect": {"scope": "events", "stat": "event_reward_multiplier", "operation": "add_pct", "value": 0.10}},
		{"id": "events_window", "title": "Janela Longa", "cost": 3, "requires": ["events_reward"], "requires_feature": "events", "effect": {"scope": "events", "stat": "event_duration_multiplier", "operation": "add_pct", "value": 0.10}},
	]},
]


## Retired node ids mapped to their replacement. A save that bought the old node
## keeps the tier it paid for; it is never silently dropped, because dropping it
## would spend the shares and hand back nothing.
const LEGACY_NODE_IDS := {
	"offline_50": "offline_eff_60",
	"offline_65": "offline_eff_75",
	"offline_cap_8h": "offline_cap_12h",
	"offline_cap_10h": "offline_cap_16h",
}


static func canonical_id(id: StringName) -> StringName:
	return StringName(LEGACY_NODE_IDS.get(String(id), String(id)))


static func purchasable_branches() -> Array[Dictionary]:
	## Branches whose feature is not unlocked yet stay hidden: the Rotas and
	## Eventos branches read their stats for real (route freight, charter
	## prizes and windows), so the gate is the terminal level, not a dead
	## button. `ProgressionManager` hides feature-gated achievements for the
	## same reason.
	var result: Array[Dictionary] = []
	for branch in BRANCHES:
		var branch_feature := String(branch.get("requires_feature", ""))
		if not branch_feature.is_empty() \
				and not FeatureGate.unlocked(StringName(branch_feature)):
			continue
		var branch_copy := branch.duplicate(true)
		var nodes: Array[Dictionary] = []
		for node: Dictionary in branch_copy.get("nodes", []):
			var node_feature := String(node.get("requires_feature", ""))
			if node_feature.is_empty() \
					or FeatureGate.unlocked(StringName(node_feature)):
				nodes.append(node)
		if nodes.is_empty():
			continue
		branch_copy["nodes"] = nodes
		result.append(branch_copy)
	return result


static func all_nodes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for branch in BRANCHES:
		for node in branch.nodes:
			result.append(node.duplicate(true))
	return result


static func get_node(id: StringName) -> Dictionary:
	for node in all_nodes():
		if StringName(node.get("id", "")) == id:
			return node
	return {}


static func is_valid() -> bool:
	var branch_ids := {}
	var node_ids := {}
	for branch in BRANCHES:
		var branch_id := StringName(branch.get("id", ""))
		if branch_id.is_empty() or branch_ids.has(branch_id) or not branch.get("nodes", []) is Array:
			return false
		if branch_id in [&"routes", &"events"] and String(branch.get("requires_feature", "")).is_empty():
			return false
		branch_ids[branch_id] = true
		for node in branch.nodes:
			var node_id := StringName(node.get("id", ""))
			if node_id.is_empty() or node_ids.has(node_id) or int(node.get("cost", 0)) <= 0 or not node.get("effect", {}) is Dictionary:
				return false
			if branch_id in [&"routes", &"events"] and String(node.get("requires_feature", "")).is_empty():
				return false
			node_ids[node_id] = true
	for node in all_nodes():
		for required in node.get("requires", []):
			if not node_ids.has(StringName(required)):
				return false
	for legacy: String in LEGACY_NODE_IDS:
		# A retired id that still exists would shadow a live node on load, and
		# one that points nowhere would silently eat the purchase.
		if node_ids.has(StringName(legacy)):
			return false
		if not node_ids.has(StringName(LEGACY_NODE_IDS[legacy])):
			return false
	return branch_ids.size() == 5
