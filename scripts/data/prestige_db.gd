class_name PrestigeDB
## Declarative prestige branches. A future economy owner applies these effects.

const BRANCHES: Array[Dictionary] = [
	{"id": "throughput", "title": "Vazão", "nodes": [
		{"id": "throughput_structural", "cost": 1, "effect": {"scope": "structures", "stat": "cps_multiplier", "operation": "add_pct", "value": 0.25}},
		{"id": "throughput_global", "cost": 3, "requires": ["throughput_structural"], "effect": {"scope": "global", "stat": "cps_multiplier", "operation": "add_pct", "value": 0.20}},
	]},
	{"id": "click", "title": "Clique", "nodes": [
		{"id": "click_manual", "cost": 1, "effect": {"scope": "manual", "stat": "click_multiplier", "operation": "add_pct", "value": 0.50}},
		{"id": "click_cps_per_tap", "cost": 3, "requires": ["click_manual"], "effect": {"scope": "manual", "stat": "cps_per_tap", "operation": "add_pct", "value": 0.01}},
	]},
	{"id": "offline", "title": "Offline", "nodes": [
		{"id": "offline_50", "cost": 1, "effect": {"scope": "offline", "stat": "offline_efficiency", "operation": "set", "value": 0.50}},
		{"id": "offline_65", "cost": 3, "requires": ["offline_50"], "effect": {"scope": "offline", "stat": "offline_efficiency", "operation": "set", "value": 0.65}},
		{"id": "offline_cap_8h", "cost": 2, "requires": ["offline_50"], "effect": {"scope": "offline", "stat": "offline_cap_seconds", "operation": "set", "value": 28800.0}},
		{"id": "offline_cap_10h", "cost": 5, "requires": ["offline_65", "offline_cap_8h"], "effect": {"scope": "offline", "stat": "offline_cap_seconds", "operation": "set", "value": 36000.0}},
	]},
	{"id": "routes", "title": "Rotas", "requires_feature": "routes", "nodes": [
		{"id": "routes_reward", "cost": 1, "requires_feature": "routes", "effect": {"scope": "routes", "stat": "route_reward_multiplier", "operation": "add_pct", "value": 0.10}},
		{"id": "routes_slot", "cost": 3, "requires": ["routes_reward"], "requires_feature": "routes", "effect": {"scope": "routes", "stat": "route_slots", "operation": "add_flat", "value": 1.0}},
	]},
	{"id": "events", "title": "Eventos", "requires_feature": "events", "nodes": [
		{"id": "events_reward", "cost": 1, "requires_feature": "events", "effect": {"scope": "events", "stat": "event_reward_multiplier", "operation": "add_pct", "value": 0.10}},
		{"id": "events_window", "cost": 3, "requires": ["events_reward"], "requires_feature": "events", "effect": {"scope": "events", "stat": "event_duration_multiplier", "operation": "add_pct", "value": 0.10}},
	]},
]


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
	return branch_ids.size() == 5
