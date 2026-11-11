class_name EconomySimulator
extends RefCounted
## A deterministic balance sandbox: no Nodes, clocks, autoloads, randomness, or I/O.
##
## This is the only honest telemetry a single-player offline game can have, so it
## has to model the economy the player actually plays: structures *and* upgrades,
## the prestige reset with its rebuild discount, the golden shares that reset buys,
## and absences that pay a capped fraction instead of full production. A sandbox
## that models only the fifteen generators answers questions about a game that
## does not exist.
##
## Land **is** modelled, because it stopped being decoration: every parcel now
## opens a machine, so a sandbox that ignored it would buy cranes the real game
## would not sell yet and report a curve nobody can play.
##
## Not modelled, on purpose: weather, surges and the cat boost (session-scoped
## bursts), and cargo flow.

const TICK := 0.25
const DECISION_INTERVAL := 5.0
## Taps per second of a player who is actually working the ship. A hand does a
## few per second; it does not do three thousand. Modelling active play as a flat
## TEU/s floor made every early marker meaningless, because the floor dwarfed the
## whole early economy from the first tick.
const DEFAULT_TAPS_PER_SECOND := 4.0
## 3% of taps pay 7×, so a tap is worth 1.18 of its face value on average
## (`GameState.CRIT_CHANCE` and `CRIT_MULT`). The sandbox uses the expectation
## instead of rolling, and stays deterministic.
const CRIT_EXPECTED_MULTIPLIER := 0.97 + 0.03 * 7.0
const OFFLINE_EFFICIENCY := 0.5
const OFFLINE_CAP_SECONDS := 8.0 * 3600.0
## A run is worth resetting once the shares it would pay beat this share of the
## level already banked. Below it the reset costs more time than it returns.
const EFFICIENT_PRESTIGE_RATIO := 0.5

## Two ways of playing the same catalogue, as a *player's* plan rather than a
## rule of the economy.
##
## Item 4 of the plan asks for proof that two builds reach different results by
## composition and not only by efficiency. Proving that needs two agents that
## commit to opposite halves of the tree and are otherwise the identical greedy
## line — so a plan may only ever *refuse* a node, never make a weak one score
## well, and the structure bias is a preference between machines the agent could
## already afford.
##
## - `wide` runs many kinds and many cheap units. Its terminal is run by the
##   dockers, and it takes the spread half of every exclusive pair.
## - `tall` runs a few very large machines. Its terminal is run by the quay or the
##   yard, and it stacks deep rather than turning over fast.
##
## Neither plan bans the *other* conductors outright — the group already makes
## them mutually exclusive, so naming one to avoid is enough to send each agent to
## a different identity.
const BUILD_PLANS := {
	"wide": {
		"avoid": ["estoque_profundo", "escala_profunda", "trem_pesado",
			"bloco_mestre", "cais_dedicado", "centro_de_controle"],
		"breadth_bias": 1.4,
		# C8: the wide build actually prefers cheap machines, so the fleet
		# *shape* diverges from the tall one and composition_distance can
		# measure it — with one shared cost curve both agents built the same
		# pyramid however they were played.
		"cheap_bias": 1.30,
	},
	"tall": {
		# `bloco_mestre` is refused as well as `turma_de_terra`: a port that has
		# just tripled its block with Estoque Profundo converting that same block
		# into a conductor is not the tall build, it is the tall build undoing
		# itself. Its identity is the quay.
		"avoid": ["giro_rapido", "cadencia_de_cais", "trem_shuttle",
			"turma_de_terra", "bloco_mestre"],
		"breadth_bias": 0.0,
		"big_bias": 1.30,
	},
}


static func scenario_names() -> PackedStringArray:
	return PackedStringArray(["active_90m", "hybrid_120m", "casual_24h",
		"offline_night", "wrong_buy", "recovery", "build_wide", "build_tall",
		"casual_week", "engaged_week"])


static func scenario_config(name: StringName) -> Dictionary:
	var base := {
		"name": String(name), "duration": 90.0 * 60.0, "tick": TICK,
		"decision_interval": DECISION_INTERVAL,
		"taps_per_second": DEFAULT_TAPS_PER_SECOND,
		"starting_currency": 0.0, "starting_owned": {}, "prestige_level": 0,
		"max_bulk": 25,
		# "greedy" takes the best payback available; "worst" takes the worst one,
		# every decision, for the whole run. Erring only the first purchase is not
		# a wrong build, it is a rounding error.
		"buy_policy": "greedy",
		# "never", "asap" or "efficient".
		"prestige_policy": "asap",
		"spend_shares": true,
		# A session/absence cycle. `away_seconds` of 0 means the player never
		# closes the game.
		"session_seconds": 0.0, "away_seconds": 0.0,
		# Seeds for asking "how long to rebuild this port", not for a scenario.
		"starting_upgrades": {}, "starting_tree_nodes": {},
		"starting_rebuild_targets": {}, "stop_at_production": 0.0,
		"offline_efficiency": OFFLINE_EFFICIENCY,
		"offline_cap_seconds": OFFLINE_CAP_SECONDS,
		# Which half of the tree this agent committed to. Empty is the unopinionated
		# greedy line every other scenario is measured with.
		"build": "",
	}
	match name:
		&"hybrid_120m":
			base.merge({"duration": 120.0 * 60.0, "taps_per_second": 2.0,
				"session_seconds": 20.0 * 60.0, "away_seconds": 40.0 * 60.0}, true)
		&"casual_24h":
			# Four short sessions a day, not a player tapping for 24 hours.
			base.merge({"duration": 24.0 * 3600.0, "taps_per_second": 1.0,
				"session_seconds": 5.0 * 60.0, "away_seconds": 5.75 * 3600.0}, true)
		&"offline_night":
			# A short session to set the port up, then ten hours away: two more
			# than the cap, so `capped_away_seconds` reports what the player lost
			# by sleeping. An absence that fits inside the cap proves nothing.
			base.merge({"duration": 10.0 * 3600.0 + 300.0, "taps_per_second": 2.0,
				"starting_owned": {"estivador": 10, "empilhadeira": 4},
				"session_seconds": 300.0, "away_seconds": 10.0 * 3600.0}, true)
		&"wrong_buy":
			# Identical to `hybrid_120m` in every way except the policy, so the
			# two results subtract. A scenario with its own duration and starting
			# wallet answers a different question than the one it was named for.
			base.merge({"duration": 120.0 * 60.0, "taps_per_second": 2.0,
				"session_seconds": 20.0 * 60.0, "away_seconds": 40.0 * 60.0,
				"buy_policy": "worst"}, true)
		&"recovery":
			# Long enough to reach the first reset and rebuild past it, which is
			# the only way `first_recovery_seconds` can report anything.
			base.merge({"duration": 8.0 * 3600.0}, true)
		&"casual_week":
			# The week the game is paced for: five check-ins a day of ten minutes,
			# tapping now and then, resetting when the reset is worth it. Most of
			# the catalogue should open inside these seven days and not before.
			base.merge({"duration": 7.0 * 86400.0, "taps_per_second": 1.5,
				"session_seconds": 10.0 * 60.0, "away_seconds": 4.8 * 3600.0 - 600.0,
				"prestige_policy": "efficient", "decision_interval": 10.0,
				"tick": 1.0}, true)
		&"engaged_week":
			# The player who keeps it open: eight half-hour sessions a day. The
			# ceiling of the pacing — they may finish early, but not on day two.
			base.merge({"duration": 7.0 * 86400.0, "taps_per_second": 2.5,
				"session_seconds": 30.0 * 60.0, "away_seconds": 3.0 * 3600.0 - 1800.0,
				"prestige_policy": "efficient", "decision_interval": 10.0,
				"tick": 1.0}, true)
		&"build_wide", &"build_tall":
			# The composition pair. Identical in every field but `build`, so the
			# two results subtract and the difference is the tree and nothing else.
			# Six hours: an exclusive pair does not open until the port is large,
			# and a run that ends before the choice exists cannot measure it
			# (three hours was enough before the week-long pacing).
			base.merge({"duration": 6.0 * 3600.0, "taps_per_second": 2.0,
				"prestige_policy": "never",
				"build": "wide" if name == &"build_wide" else "tall"}, true)
	return base


static func estimate_rebuild_seconds(snapshot: Dictionary,
		budget_seconds: float = 4.0 * 3600.0) -> float:
	## "You get this peak back in about N minutes" — the question the prestige
	## dialog could not answer. The port is rebuilt from zero with the discount
	## its own peak earns and the meta multiplier the reset is about to pay, then
	## run until it passes the production being given up. Returns -1 when the
	## budget runs out, which is itself an answer worth showing.
	var target := maxf(0.0, float(snapshot.get("target_production", 0.0)))
	if target <= 0.0:
		return 0.0
	var config := scenario_config(&"rebuild_estimate")
	config.merge({
		"duration": maxf(0.0, budget_seconds),
		"taps_per_second": float(snapshot.get("taps_per_second", 0.0)),
		"prestige_level": maxi(0, int(snapshot.get("prestige_level", 0))),
		"prestige_policy": "never",
		"spend_shares": false,
		"starting_tree_nodes": snapshot.get("tree_nodes", {}),
		"starting_rebuild_targets": snapshot.get("rebuild_targets", {}),
		"stop_at_production": target,
	}, true)
	var result := run(config)
	return float(result.markers.get("target_reached_at", -1.0))


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
	var session_seconds := maxf(0.0, float(config.get("session_seconds", 0.0)))
	var away_seconds := maxf(0.0, float(config.get("away_seconds", 0.0)))
	var stop_at := maxf(0.0, float(config.get("stop_at_production", 0.0)))
	var next_decision := 0.0
	var session_left := session_seconds if session_seconds > 0.0 else INF
	while state.elapsed < duration - 0.0000001:
		if session_left <= 0.0000001 and away_seconds > 0.0:
			_apply_absence(state, config, minf(away_seconds, duration - state.elapsed))
			session_left = session_seconds
			next_decision = state.elapsed
			continue
		var step := minf(minf(tick, session_left), duration - state.elapsed)
		var passive := production_per_second(state)
		var active := active_income_per_second(state, config)
		var earned := (passive + active) * step
		_credit(state, earned, passive)
		state.elapsed += step
		session_left -= step
		if earned > 0.0 and state.markers.first_reward < 0.0:
			state.markers.first_reward = state.elapsed
		if passive > 0.0 and state.markers.first_passive < 0.0:
			state.markers.first_passive = state.elapsed
		if EconomyMath.prestige_potential(state.all_time_productive) >= 1 \
				and state.markers.first_prestige < 0.0:
			state.markers.first_prestige = state.elapsed
		_track_recovery(state, passive)
		if stop_at > 0.0 and passive >= stop_at:
			state.markers.target_reached_at = state.elapsed
			break
		while state.elapsed + 0.0000001 >= next_decision:
			_consider_prestige(state, config)
			_spend_shares(state, config)
			_make_decision(state, config)
			next_decision += decision_interval
	return summary(state, config)


static func _credit(state: Dictionary, amount: float, production: float) -> void:
	## `production` is passed in rather than recomputed: this runs once per tick
	## and the formula walks every structure and every upgrade.
	if amount <= 0.0:
		return
	state.currency += amount
	state.all_time_productive += amount
	state.run_peak_production = maxf(float(state.run_peak_production), production)


static func _apply_absence(state: Dictionary, config: Dictionary, seconds: float) -> void:
	## The port keeps working while the game is closed, but only up to the cap and
	## only at the configured efficiency. Charging full production for an absence
	## is the difference between "the night paid for a new crane" and "the night
	## paid for half of one", and the whole point of the offline scenario.
	if seconds <= 0.0:
		return
	# The offline branch of the capital tree raises both, so shares actually buy
	# something the absence scenarios can see.
	var cap := tree_offline_value(state, &"offline_cap_seconds",
		maxf(0.0, float(config.get("offline_cap_seconds", OFFLINE_CAP_SECONDS))))
	var efficiency := clampf(tree_offline_value(state, &"offline_efficiency",
		float(config.get("offline_efficiency", OFFLINE_EFFICIENCY))), 0.0, 1.0)
	var production := production_per_second(state)
	var credited := minf(seconds, cap)
	_credit(state, production * credited * efficiency, production)
	state.absent_seconds += seconds
	state.capped_away_seconds += maxf(0.0, seconds - credited)
	state.elapsed += seconds
	if state.markers.first_passive < 0.0 and production > 0.0:
		state.markers.first_passive = state.elapsed


static func click_power(state: Dictionary) -> float:
	## Mirrors `GameState.recompute`: a flat part that only click upgrades and the
	## capital tree move, plus a share of production. Note what it does *not*
	## contain — the meta multiplier. Tapping only rides prestige through the
	## `cps_per_tap` term, so an active player falls behind an idle one by design.
	var click_mult := 1.0
	var click_cps_pct := 0.0
	for up in UpgradeDB.ITEMS:
		if not state.upgrades.has(String(up.id)):
			continue
		match up.get("kind"):
			"click_mult": click_mult *= float(up.value)
			"click_cps_pct": click_cps_pct += float(up.value)
	var flat := click_mult * _tree_multiplier(state, &"manual", &"click_multiplier")
	var share := click_cps_pct + _tree_additive(state, &"manual", &"cps_per_tap")
	return flat + production_per_second(state) * share


static func active_income_per_second(state: Dictionary, config: Dictionary) -> float:
	return maxf(0.0, float(config.get("taps_per_second", DEFAULT_TAPS_PER_SECOND))) \
		* click_power(state) * CRIT_EXPECTED_MULTIPLIER


static func unit_cps(state: Dictionary, item: Dictionary) -> float:
	## One unit's production with its fitted upgrades, mirroring
	## `GameState.structure_cps` — flat multipliers, then what the rest of the port
	## lends it through a synergy, then the transform that takes it off production.
	##
	## Two of those three read `state.owned`, which is why `_refresh_derived` has
	## to run after a *structure* purchase now and not only after an upgrade.
	var id := String(item.id)
	var value := float(item.cps)
	for up in UpgradeDB.ITEMS:
		if not state.upgrades.has(String(up.id)):
			continue
		match String(up.get("kind", "")):
			"structure_mult":
				if UpgradeDB.targets_of(up).has(id):
					value *= float(up.get("value", 1.0))
			"synergy":
				if String(up.get("target", "")) == id:
					value *= 1.0 + _synergy_bonus(state, up)
			"transform":
				if String(up.get("target", "")) == id \
						and String(up.get("mode", "")) == "conductor":
					value *= float(up.get("self_mult", 1.0))
	return value


static func _synergy_bonus(state: Dictionary, up: Dictionary) -> float:
	return EconomyMath.saturating_bonus(float(up.get("value", 0.0)),
		float(up.get("cap", 1.0)), int(state.owned.get(String(up.get("per", "")), 0)))


static func conductor_multiplier(state: Dictionary) -> float:
	## Mirrors `GameState._conductor_multiplier`: a transformed machine pays the
	## port a share per unit of itself instead of producing. This is the factor the
	## wide build exists to move.
	var value := 1.0
	for up in UpgradeDB.ITEMS:
		if String(up.get("kind", "")) != "transform" \
				or String(up.get("mode", "")) != "conductor" \
				or not state.upgrades.has(String(up.id)):
			continue
		value *= 1.0 + EconomyMath.saturating_bonus(float(up.get("value", 0.0)),
			float(up.get("cap", 1.0)),
			int(state.owned.get(String(up.get("target", "")), 0)))
	return value


static func breadth_multiplier(state: Dictionary) -> float:
	## Mirrors `GameState._breadth_multiplier`. The capital tree's `structures`
	## node pays per kind of machine the terminal runs a working fleet of, which is
	## the one meta effect a tall port cannot buy its way into.
	var per_kind := _tree_additive(state, &"structures", &"cps_per_kind")
	if per_kind <= 0.0:
		return 1.0
	var kinds := 0
	for item in EconomyCatalog.ITEMS:
		if int(state.owned.get(String(item.id), 0)) >= EconomyMath.BREADTH_MIN_COUNT:
			kinds += 1
	return 1.0 + per_kind * float(kinds)


static func global_multiplier(state: Dictionary) -> float:
	## `GameState` applies the meta multiplier, the capital tree's two genuinely
	## different scopes, the conductor share and every `global_mult` upgrade to the
	## same product. The sandbox mirrors that exactly.
	var value := EconomyMath.prestige_multiplier(int(state.prestige_level)) \
		* breadth_multiplier(state) \
		* _tree_multiplier(state, &"global", &"cps_multiplier") \
		* conductor_multiplier(state)
	for up in UpgradeDB.ITEMS:
		if up.get("kind") == "global_mult" and state.upgrades.has(String(up.id)):
			value *= float(up.value)
	return value


static func _refresh_derived(state: Dictionary) -> void:
	## Production is read every tick and the honest formula walks every structure
	## against every upgrade. Only upgrades, tree nodes and prestige move these
	## factors, so they are recomputed on purchase instead of on read.
	var cache: Dictionary = {}
	for item in EconomyCatalog.ITEMS:
		cache[item.id] = unit_cps(state, item)
	state.unit_cps_cache = cache
	state.global_mult_cache = global_multiplier(state)


static func production_per_second(state: Dictionary) -> float:
	var cache: Variant = state.get("unit_cps_cache")
	var multiplier: Variant = state.get("global_mult_cache")
	if not (cache is Dictionary) or not (multiplier is float):
		# Hand-built states (tests, probes) never went through `_new_state`.
		_refresh_derived(state)
		cache = state.unit_cps_cache
		multiplier = state.global_mult_cache
	var total := 0.0
	for id: String in cache:
		total += EconomyMath.total_cps(float(cache[id]), int(state.owned.get(id, 0)))
	return total * float(multiplier)


static func summary(state: Dictionary, config: Dictionary = {}) -> Dictionary:
	return {
		"scenario": String(config.get("name", "custom")),
		"elapsed_seconds": state.elapsed,
		"currency": state.currency,
		"all_time_productive": state.all_time_productive,
		"production_per_second": production_per_second(state),
		"owned": state.owned.duplicate(),
		"total_owned": _total_owned(state.owned),
		"distinct_owned": _distinct_owned(state.owned),
		# The two factors item 4 was written to create. Reported separately from
		# the rate because "this port earns more" and "this port earns more *for a
		# different reason*" are the two different claims being checked.
		"conductor_multiplier": conductor_multiplier(state),
		"breadth_multiplier": breadth_multiplier(state),
		"land": state.land.keys(),
		"upgrades": state.upgrades.keys(),
		"tree_nodes": state.tree_nodes.keys(),
		"purchases": state.purchases,
		"prestige_potential": EconomyMath.prestige_potential(state.all_time_productive),
		"prestige_count": state.prestige_count,
		"prestige_level": state.prestige_level,
		"shares": state.shares,
		"runs": state.runs,
		"absent_seconds": state.absent_seconds,
		"capped_away_seconds": state.capped_away_seconds,
		"markers": state.markers.duplicate(),
	}


static func _new_state(config: Dictionary) -> Dictionary:
	var owned: Dictionary = {}
	for item in EconomyCatalog.all():
		owned[item.id] = maxi(0, int(config.get("starting_owned", {}).get(item.id, 0)))
	var state := {
		"elapsed": 0.0,
		"currency": maxf(0.0, float(config.get("starting_currency", 0.0))),
		"all_time_productive": 0.0,
		"prestige_level": maxi(0, int(config.get("prestige_level", 0))),
		"prestige_count": 0,
		"shares": 0,
		"owned": owned,
		"land": {},
		"upgrades": (config.get("starting_upgrades", {}) as Dictionary).duplicate(),
		"tree_nodes": (config.get("starting_tree_nodes", {}) as Dictionary).duplicate(),
		"rebuild_targets": (config.get("starting_rebuild_targets", {}) as Dictionary).duplicate(),
		"purchases": [],
		"runs": [],
		"run_started_at": 0.0,
		"run_peak_production": 0.0,
		"pending_recovery_target": 0.0,
		"pending_recovery_from": -1.0,
		"absent_seconds": 0.0,
		"capped_away_seconds": 0.0,
		"markers": {"first_reward": -1.0, "first_passive": -1.0,
			"first_choice": -1.0, "three_owned": -1.0, "first_prestige": -1.0,
			"first_recovery_seconds": -1.0, "target_reached_at": -1.0},
	}
	_refresh_derived(state)
	return state


static func _consider_prestige(state: Dictionary, config: Dictionary) -> void:
	## `GameState.do_prestige`, minus the presentation: banked shares grow, the
	## port is cleared, and the peak becomes a rebuild discount on the next run.
	var policy := String(config.get("prestige_policy", "asap"))
	if policy == "never":
		return
	var gain: int = maxi(0, EconomyMath.prestige_potential(state.all_time_productive)
		- int(state.prestige_level))
	if gain <= 0:
		return
	if policy == "efficient" \
			and gain < maxi(1, int(float(state.prestige_level) * EFFICIENT_PRESTIGE_RATIO)):
		return
	var before := production_per_second(state)
	for id: String in state.owned:
		state.rebuild_targets[id] = maxi(int(state.rebuild_targets.get(id, 0)),
			int(state.owned[id]))
		state.owned[id] = 0
	state.upgrades.clear()
	state.currency = 0.0
	state.shares += gain
	state.prestige_level += gain
	state.prestige_count += 1
	state.runs.append({
		"ended_at": state.elapsed,
		"duration": state.elapsed - float(state.run_started_at),
		"peak_production": float(state.run_peak_production),
		"gain": gain,
	})
	state.run_started_at = state.elapsed
	state.run_peak_production = 0.0
	_refresh_derived(state)
	# The question the prestige dialog cannot answer yet: how long until this
	# port is back where it was.
	if state.pending_recovery_from < 0.0 and before > 0.0:
		state.pending_recovery_target = before
		state.pending_recovery_from = state.elapsed


static func _track_recovery(state: Dictionary, production: float) -> void:
	if state.pending_recovery_from < 0.0:
		return
	if state.markers.first_recovery_seconds >= 0.0:
		return
	if production >= float(state.pending_recovery_target):
		state.markers.first_recovery_seconds = state.elapsed - float(state.pending_recovery_from)


static func _tree_multiplier(state: Dictionary, scope: StringName, stat: StringName) -> float:
	var multiplier := 1.0
	for node_id: String in state.tree_nodes:
		var effect: Dictionary = PrestigeDB.get_node(node_id).get("effect", {})
		if StringName(effect.get("scope", "")) == scope \
				and StringName(effect.get("stat", "")) == stat \
				and effect.get("operation", "") == "add_pct":
			multiplier += float(effect.get("value", 0.0))
	return multiplier


static func _tree_additive(state: Dictionary, scope: StringName, stat: StringName) -> float:
	var value := 0.0
	for node_id: String in state.tree_nodes:
		var effect: Dictionary = PrestigeDB.get_node(node_id).get("effect", {})
		if StringName(effect.get("scope", "")) == scope \
				and StringName(effect.get("stat", "")) == stat \
				and effect.get("operation", "") == "add_pct":
			value += float(effect.get("value", 0.0))
	return value


static func tree_offline_value(state: Dictionary, stat: StringName, base: float) -> float:
	var value := base
	for node_id: String in state.tree_nodes:
		var effect: Dictionary = PrestigeDB.get_node(node_id).get("effect", {})
		if StringName(effect.get("scope", "")) == &"offline" \
				and StringName(effect.get("stat", "")) == stat \
				and effect.get("operation", "") == "set":
			value = maxf(value, float(effect.get("value", base)))
	return value


static func _spend_shares(state: Dictionary, config: Dictionary) -> void:
	## Golden shares are a currency with sinks. Leaving them unspent modelled a
	## player who prestiges and then ignores the only thing prestige buys.
	if not bool(config.get("spend_shares", true)) or int(state.shares) <= 0:
		return
	var bought := true
	while bought:
		bought = false
		for branch in PrestigeDB.purchasable_branches():
			for node: Dictionary in branch.get("nodes", []):
				var id := String(node.get("id", ""))
				if state.tree_nodes.has(id):
					continue
				var cost := int(node.get("cost", 0))
				if cost <= 0 or int(state.shares) < cost:
					continue
				var blocked := false
				for required in node.get("requires", []):
					if not state.tree_nodes.has(String(required)):
						blocked = true
				if blocked:
					continue
				state.shares -= cost
				state.tree_nodes[id] = true
				bought = true
	_refresh_derived(state)


static func _make_decision(state: Dictionary, config: Dictionary) -> void:
	var choice := _best_choice(state, config)
	if choice.is_empty():
		return
	state.currency = maxf(0.0, state.currency - float(choice.cost))
	if String(choice.kind) == "land":
		state.land[String(choice.id)] = true
	elif String(choice.kind) == "upgrade":
		# An exclusive pick refits its sibling out, exactly as `buy_upgrade` does.
		# The price paid was already the swap price; leaving the loser in the set
		# would let a sandbox port run both halves of a choice a player cannot.
		for other in UpgradeDB.conflicts_with(UpgradeDB.get_item(String(choice.id)),
				state.upgrades):
			state.upgrades.erase(other)
		state.upgrades[String(choice.id)] = true
		_refresh_derived(state)
	else:
		state.owned[choice.id] = int(state.owned.get(choice.id, 0)) + int(choice.amount)
		# Synergies and conductors make one machine's rate depend on how many of
		# *another* the port runs, so the cached factors go stale on a structure
		# purchase now. Before those kinds existed this line was genuinely
		# unnecessary; leaving it out now would quietly freeze the economy.
		_refresh_derived(state)
	state.purchases.append({"at": state.elapsed, "kind": choice.kind,
		"id": choice.id, "amount": choice.amount, "cost": choice.cost})
	if state.markers.first_choice < 0.0:
		state.markers.first_choice = state.elapsed
	# Three *kinds* of machine, not three machines. The goal is "three visually
	# different unlocks"; ten dockworkers are one thing on screen.
	if _distinct_owned(state.owned) >= 3 and state.markers.three_owned < 0.0:
		state.markers.three_owned = state.elapsed


static func _best_choice(state: Dictionary, config: Dictionary) -> Dictionary:
	## Everything the wallet can reach is scored on the same denominator — the
	## production a TEU buys — so an upgrade and a crane compete directly.
	var worst := String(config.get("buy_policy", "greedy")) == "worst"
	var options := _affordable_options(state, config)
	var selected: Dictionary = {}
	var best_score := -1.0
	for option: Dictionary in options:
		var score := float(option.score)
		if score <= 0.0:
			continue
		if selected.is_empty() \
				or (score > best_score if not worst else score < best_score):
			best_score = score
			selected = option
	return selected


static func _build_plan(config: Dictionary) -> Dictionary:
	return BUILD_PLANS.get(String(config.get("build", "")), {})


static func _spillover_gain(state: Dictionary, id: String, amount: int) -> float:
	## What buying `amount` more of `id` does to production *elsewhere*.
	##
	## Two routes, and a port only ever has the ones it bought: the conductor share
	## rises with units of the machine it is fitted to, and a synergy's bonus rises
	## with units of the machine it counts. Both are computed as a before/after on
	## the real formula rather than approximated, because the caps mean the tenth
	## unit and the hundredth are worth very different amounts.
	if not _touches_spillover(state, id):
		return 0.0
	var item := EconomyCatalog.get_item(StringName(id))
	if item.is_empty():
		return 0.0
	var owned: Dictionary = state.owned
	var probe: Dictionary = state.duplicate()
	probe.owned = owned.duplicate()
	probe.owned[id] = int(owned.get(id, 0)) + amount
	_refresh_derived(probe)
	# The machine's own extra output is already scored by the caller, at the rate
	# and multiplier it has *today*; subtract exactly that and what is left is the
	# part of the purchase that lands on every other line.
	var direct := (EconomyMath.total_cps(unit_cps(state, item), int(probe.owned[id]))
		- EconomyMath.total_cps(unit_cps(state, item), int(owned.get(id, 0)))) \
		* global_multiplier(state)
	return maxf(0.0, production_per_second(probe)
		- production_per_second(state) - direct)


static func _touches_spillover(state: Dictionary, id: String) -> bool:
	## Cheap guard so the probe above only runs for the handful of machines some
	## fitted node actually counts. Without it every option on every decision would
	## rebuild the derived cache.
	for up in UpgradeDB.ITEMS:
		if not state.upgrades.has(String(up.id)):
			continue
		match String(up.get("kind", "")):
			"transform":
				if String(up.get("target", "")) == id:
					return true
			"synergy":
				if String(up.get("per", "")) == id:
					return true
	return false


static func _affordable_options(state: Dictionary, config: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var current := production_per_second(state) + active_income_per_second(state, config)
	var max_bulk: int = maxi(1, int(config.get("max_bulk", 25)))
	for parcel in LandDB.ITEMS:
		var parcel_id := String(parcel.id)
		if state.land.has(parcel_id):
			continue
		# Parcels open in order, so only the next one is ever on the board.
		var cost_of_land := float(parcel.cost)
		if cost_of_land > state.currency:
			break
		# Land produces nothing, so it can never win on payback. It is scored on
		# what it *opens*: the machine behind the gate, at that machine's own
		# rate. Without this the agent would never buy ground and would stall at
		# the first gate, which is exactly what a greedy player would do if the
		# shop did not tell them why the crane is grey.
		var opened := EconomyCatalog.get_item(StringName(str(parcel.get("unlocks", ""))))
		var worth := 0.0
		if not opened.is_empty():
			worth = EconomyMath.total_cps(unit_cps(state, opened), 1) \
				* global_multiplier(state)
		options.append({"kind": "land", "id": parcel_id, "amount": 1,
			"cost": cost_of_land, "score": worth / cost_of_land})
		break
	var plan := _build_plan(config)
	for item in EconomyCatalog.all():
		if not _structure_unlocked(state, String(item.id)):
			continue
		var owned := int(state.owned.get(item.id, 0))
		var target := int(state.rebuild_targets.get(item.id, 0))
		var growth := float(item.get("growth", EconomyMath.GROWTH))
		var affordable := EconomyMath.max_affordable_discounted(float(item.base_cost),
			owned, state.currency, target, EconomyMath.REBUILD_DISCOUNT, growth)
		if affordable <= 0:
			continue
		var amount: int = mini(affordable, max_bulk)
		var cost := EconomyMath.discounted_bulk_cost(float(item.base_cost), owned,
			amount, target, EconomyMath.REBUILD_DISCOUNT, growth)
		if not is_finite(cost) or cost <= 0.0:
			continue
		var gain := EconomyMath.total_cps(unit_cps(state, item), owned + amount) \
			- EconomyMath.total_cps(unit_cps(state, item), owned)
		var value := gain * global_multiplier(state)
		# What the machine is worth to the *port*, not to its own line.
		#
		# A unit of the machine a conductor is fitted to lifts everything the
		# terminal earns, and a unit of a machine some synergy counts lifts whatever
		# that synergy feeds. Scoring only the machine's own delta made both effects
		# invisible to the agent, so it kept buying the same cost-curve pyramid
		# whatever was fitted — and two builds that cannot see their own strategy
		# produce two identical ports, which is exactly what the sandbox reported
		# before this line existed.
		value += _spillover_gain(state, String(item.id), amount)
		var score := value / cost
		# A wide player pays over the odds to get a machine's fleet up to a working
		# size, because breadth is worth something to them that payback does not
		# show: the capital tree's per-kind share.
		if owned + amount < EconomyMath.BREADTH_MIN_COUNT:
			score *= 1.0 + float(plan.get("breadth_bias", 0.0))
		# C8: a build plan also tilts the *machine* choice — wide prefers cheap
		# units, tall prefers the big ones — so the two fleets end up shaped
		# differently and composition_distance has something to measure.
		if float(plan.get("cheap_bias", 0.0)) > 0.0 and float(item.base_cost) <= 1.0e6:
			score *= 1.0 + float(plan.get("cheap_bias", 0.0))
		if float(plan.get("big_bias", 0.0)) > 0.0 and float(item.base_cost) > 1.0e6:
			score *= 1.0 + float(plan.get("big_bias", 0.0))
		options.append({"kind": "structure", "id": item.id, "amount": amount,
			"cost": cost, "score": score})
	for up in UpgradeDB.ITEMS:
		var id := String(up.id)
		if state.upgrades.has(id) or not _upgrade_available(state, up):
			continue
		# A build is a plan a player follows, not a rule of the economy. It only
		# ever refuses nodes — it never makes a bad one look good — so a scenario
		# with a build is still the honest greedy agent inside the half of the tree
		# that build committed to.
		if not plan.is_empty() and plan.get("avoid", []).has(id):
			continue
		var cost := UpgradeDB.price_for(up, state.upgrades)
		if cost <= 0.0 or cost > state.currency:
			continue
		# Scored on total income, not production. A click upgrade moves no
		# production at all, so on a production-only denominator it would score
		# zero forever and the greedy agent would never buy one.
		var gain := _income_with_upgrade(state, config, id) - current
		if gain <= 0.0:
			continue
		options.append({"kind": "upgrade", "id": id, "amount": 1,
			"cost": cost, "score": gain / cost})
	return options


static func _income_with_upgrade(state: Dictionary, config: Dictionary, id: String) -> float:
	var probe: Dictionary = state.duplicate()
	probe.upgrades = state.upgrades.duplicate()
	# The probe has to price the *whole* trade. A transform gives up the machine's
	# own output, and an exclusive swap gives up the sibling already fitted — score
	# either without the loss and the agent buys a downgrade at full confidence.
	for other in UpgradeDB.conflicts_with(UpgradeDB.get_item(id), probe.upgrades):
		probe.upgrades.erase(other)
	probe.upgrades[id] = true
	_refresh_derived(probe)
	return production_per_second(probe) + active_income_per_second(probe, config)


static func _structure_unlocked(state: Dictionary, id: String) -> bool:
	## Mirrors `GameState.structure_unlocked`.
	var gate := LandDB.gate_for(id)
	return gate.is_empty() or state.land.has(String(gate.id))


static func _upgrade_unlocked(state: Dictionary, item: Dictionary) -> bool:
	## Mirrors `GameState.upgrade_unlocked`. The sandbox has a single income
	## stream, so lifetime TEUs and productive TEUs are the same number.
	var unlock: Dictionary = item.get("unlock", {})
	if unlock.has("teus") and float(state.all_time_productive) < float(unlock.teus):
		return false
	if unlock.has("owned"):
		for sid: String in unlock.owned:
			if int(state.owned.get(sid, 0)) < int(unlock.owned[sid]):
				return false
	return true


static func _upgrade_available(state: Dictionary, item: Dictionary) -> bool:
	## Mirrors `GameState.upgrade_available`: the port has to be big enough *and*
	## the node above has to be bought. Without the second half the sandbox would
	## report a curve reachable only by a player who could skip the tree.
	return _upgrade_unlocked(state, item) \
		and UpgradeDB.blocked_by(item, state.upgrades).is_empty()


static func composition_distance(a: Dictionary, b: Dictionary) -> float:
	## How differently two ports are *made up*, ignoring how big they are.
	##
	## Each port becomes a share-of-fleet vector — what fraction of its machines
	## are dockers, what fraction are cranes — and the answer is half the total
	## absolute difference between the two. That lands on 0.0 for two ports built
	## the same way at any scale and 1.0 for two with no machine in common, which
	## is the shape "different by composition, not by efficiency" needs: a bigger
	## port built identically must score zero, and it does.
	var shares_a := _fleet_shares(a)
	var shares_b := _fleet_shares(b)
	var ids := {}
	for id: String in shares_a:
		ids[id] = true
	for id: String in shares_b:
		ids[id] = true
	var total := 0.0
	for id: String in ids:
		total += absf(float(shares_a.get(id, 0.0)) - float(shares_b.get(id, 0.0)))
	return total * 0.5


static func _fleet_shares(owned: Dictionary) -> Dictionary:
	var total := float(_total_owned(owned))
	if total <= 0.0:
		return {}
	var shares := {}
	for id: String in owned:
		shares[id] = float(int(owned[id])) / total
	return shares


static func _total_owned(owned: Dictionary) -> int:
	var total := 0
	for amount in owned.values():
		total += int(amount)
	return total


static func _distinct_owned(owned: Dictionary) -> int:
	var total := 0
	for amount in owned.values():
		if int(amount) > 0:
			total += 1
	return total
