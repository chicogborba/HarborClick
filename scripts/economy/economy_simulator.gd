class_name EconomySimulator
extends RefCounted
## A deterministic balance sandbox: no Nodes, clocks, autoloads, randomness, or I/O.

const TICK := 0.25
const DECISION_INTERVAL := 5.0
const DEFAULT_ACTIVE_CPS := 3500.0


static func scenario_names() -> PackedStringArray:
	return PackedStringArray(["active_90m", "hybrid_120m", "casual_24h", "offline_8h", "wrong_buy", "recovery"])


static func scenario_config(name: StringName) -> Dictionary:
	var base := {
		"name": String(name), "duration": 90.0 * 60.0, "tick": TICK,
		"decision_interval": DECISION_INTERVAL, "active_cps": DEFAULT_ACTIVE_CPS,
		"starting_currency": 0.0, "starting_owned": {}, "prestige_level": 0,
		"max_bulk": 25, "force_wrong_buy": false,
	}
	match name:
		&"hybrid_120m": base.merge({"duration": 120.0 * 60.0, "active_cps": 6500.0}, true)
		&"casual_24h": base.merge({"duration": 24.0 * 3600.0, "active_cps": 30.0}, true)
		&"offline_8h": base.merge({"duration": 8.0 * 3600.0, "active_cps": 0.0, "starting_owned": {"estivador": 10, "empilhadeira": 4}}, true)
		&"wrong_buy": base.merge({"duration": 120.0 * 60.0, "active_cps": 6500.0, "starting_currency": 1200.0, "force_wrong_buy": true}, true)
		&"recovery": base.merge({"duration": 30.0 * 60.0, "active_cps": 22000.0, "starting_currency": 0.0}, true)
	return base


static func run_scenario(name: StringName, overrides: Dictionary = {}) -> Dictionary:
	var config := scenario_config(name)
	config.merge(overrides, true)
	return run(config)


static func run(config: Dictionary) -> Dictionary:
	var tick := float(config.get("tick", TICK))
	var decision_interval := float(config.get("decision_interval", DECISION_INTERVAL))
	if tick <= 0.0 or decision_interval <= 0.0:
		return {"error": "tick and decision_interval must be positive"}
	var state := _new_state(config)
	var duration := maxf(0.0, float(config.get("duration", 0.0)))
	var next_decision := 0.0
	while state.elapsed < duration - 0.0000001:
		var step := minf(tick, duration - state.elapsed)
		var passive := production_per_second(state)
		var active := float(config.get("active_cps", DEFAULT_ACTIVE_CPS)) * EconomyMath.prestige_multiplier(int(state.prestige_level))
		var earned := (passive + active) * step
		state.currency += earned
		state.all_time_productive += earned
		state.elapsed += step
		if earned > 0.0 and state.markers.first_reward < 0.0:
			state.markers.first_reward = state.elapsed
		if passive > 0.0 and state.markers.first_passive < 0.0:
			state.markers.first_passive = state.elapsed
		if EconomyMath.prestige_potential(state.all_time_productive) >= 1 and state.markers.first_prestige < 0.0:
			state.markers.first_prestige = state.elapsed
		while state.elapsed + 0.0000001 >= next_decision:
			_make_decision(state, config)
			next_decision += decision_interval
	return summary(state, config)


static func production_per_second(state: Dictionary) -> float:
	var total := 0.0
	for item in EconomyCatalog.all():
		total += EconomyMath.total_cps(float(item.cps), int(state.owned.get(item.id, 0)))
	return total * EconomyMath.prestige_multiplier(int(state.prestige_level))


static func summary(state: Dictionary, config: Dictionary = {}) -> Dictionary:
	return {
		"scenario": String(config.get("name", "custom")),
		"elapsed_seconds": state.elapsed,
		"currency": state.currency,
		"all_time_productive": state.all_time_productive,
		"production_per_second": production_per_second(state),
		"owned": state.owned.duplicate(),
		"total_owned": _total_owned(state.owned),
		"purchases": state.purchases,
		"prestige_potential": EconomyMath.prestige_potential(state.all_time_productive),
		"markers": state.markers.duplicate(),
	}


static func _new_state(config: Dictionary) -> Dictionary:
	var owned: Dictionary = {}
	for item in EconomyCatalog.all():
		owned[item.id] = maxi(0, int(config.get("starting_owned", {}).get(item.id, 0)))
	return {
		"elapsed": 0.0,
		"currency": maxf(0.0, float(config.get("starting_currency", 0.0))),
		"all_time_productive": 0.0,
		"prestige_level": maxi(0, int(config.get("prestige_level", 0))),
		"owned": owned,
		"purchases": [],
		"markers": {"first_reward": -1.0, "first_passive": -1.0, "first_choice": -1.0, "three_owned": -1.0, "first_prestige": -1.0},
	}


static func _make_decision(state: Dictionary, config: Dictionary) -> void:
	var choice := _best_choice(state, config)
	if choice.is_empty():
		return
	var item: Dictionary = choice.item
	var amount := int(choice.amount)
	var cost := float(choice.cost)
	state.currency = maxf(0.0, state.currency - cost)
	state.owned[item.id] = int(state.owned.get(item.id, 0)) + amount
	state.purchases.append({"at": state.elapsed, "id": item.id, "amount": amount, "cost": cost})
	if state.markers.first_choice < 0.0:
		state.markers.first_choice = state.elapsed
	if _total_owned(state.owned) >= 3 and state.markers.three_owned < 0.0:
		state.markers.three_owned = state.elapsed


static func _best_choice(state: Dictionary, config: Dictionary) -> Dictionary:
	var force_wrong: bool = bool(config.get("force_wrong_buy", false)) and state.purchases.is_empty()
	var selected: Dictionary = {}
	var best_score := -1.0
	for item in EconomyCatalog.all():
		var owned := int(state.owned.get(item.id, 0))
		var affordable := EconomyMath.max_affordable(float(item.base_cost), owned, state.currency)
		if affordable <= 0:
			continue
		var amount: int = mini(affordable, maxi(1, int(config.get("max_bulk", 25))))
		if force_wrong:
			if item.id != "estivador":
				continue
			amount = 1
		var impact := EconomyMath.purchase_impact(float(item.base_cost), float(item.cps), owned, amount)
		var score := float(impact.cps_gain) / maxf(0.000001, float(impact.cost))
		if score > best_score:
			best_score = score
			selected = {"item": item, "amount": amount, "cost": impact.cost}
	return selected


static func _total_owned(owned: Dictionary) -> int:
	var total := 0
	for amount in owned.values():
		total += int(amount)
	return total
