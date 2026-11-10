extends Node
## Core economy state: TEUs (currency), structures, upgrades, CPS.

var teus: float = 0.0
var run_teus: float = 0.0
var all_time_teus: float = 0.0
var all_time_productive_teus: float = 0.0
# `lifetime_teus` is retained for world/UI compatibility, including direct
# reads/writes made by older scripts. It is an alias of the all-time total.
var lifetime_teus: float:
	get:
		return all_time_teus
	set(value):
		all_time_teus = value
var owned: Dictionary = {}      # structure id -> count
var upgrades: Dictionary = {}   # upgrade id -> true
var land: Dictionary = {}       # parcel id -> true
var routes: Dictionary = {}     # route id -> true (the free home lane is implicit)
var cps: float = 0.0
var click_power: float = 1.0
var base_cps: float = 0.0        # production without weather or surge
var shares: int = 0              # golden-share wallet
var prestige_level_earned: int = 0
var prestige_count: int = 0
var purchased_tree_nodes: Dictionary = {}
var best_owned_by_structure: Dictionary = {}
var rebuild_targets: Dictionary = {}
var last_run_summary: Dictionary = {}
var boost_time: float = 0.0      # remaining seconds of the cat boost
## A special call's prize or its forfeit: one multiplier over everything the port
## earns, for a fixed number of seconds. Session-scoped like the cat boost — it is
## a burst, and a burst that survives a reload could be banked.
var surge_mult: float = 1.0
var surge_time: float = 0.0
## The Capataz's skills get a slot of their own, beside the luck surge above.
## One slot for both meant that using a skill while a gull's frenzy was running
## threw the skill away ("the strongest wins"); two slots multiply, so pressing a
## button you earned is never wasted. Session-scoped like every burst.
var skill_mult: float = 1.0
var skill_time: float = 0.0
## The tap rhythm (see `TapCombo`): session-scoped, multiplies only the tap.
var combo := TapCombo.new()
## What the pilot skill has promised the next call's departure bonus (1 = nothing).
var pilot_pending: float = 1.0
## Purchases still being built: {id, qty, left, total}. Paid for, not yet owned —
## see `BuildQueue`. Off by default so a headless suite buying a machine has it
## at once; `Main` turns it on for the real game.
var builds: Array[Dictionary] = []
var build_times_enabled := false
var flags: Dictionary = {}       # tutorial_done, seen milestones, ...
## Decorations. Two dictionaries rather than one, because owning a thing and
## having it switched on are different facts and the player changes the second
## one far more often than the first. Neither is touched by `do_prestige`: a
## machine is the run's and a decoration is the player's, and a rebuild that
## took the bunting down would make the whole shelf a rental. See `CosmeticDb`.
var cosmetics_owned: Dictionary = {}   # id -> true
var cosmetics_on: Dictionary = {}      # id -> bool
## How the bought gang is divided between the berths. A standing order rather
## than a preference: it changes what the port produces, so it belongs to the run
## and travels with the save. See `CraneAllocation`.
var crane_policy: StringName = CraneAllocation.EVEN
## The other standing order: what gets bought when nobody is looking, and how
## much of the treasury is off limits. Unlocked by the first rebuild — see
## `foreman_unlocked()`.
## The third standing order: which lane the port books next. See `RoutePolicy` —
## buying a lane used to be strictly good because the freight was the maximum
## across everything owned, so the map was a shopping list.
var route_policy: StringName = RoutePolicy.MIX
## The fourth standing order: what the branch line is briefed to do. A booked
## train is not a thing the player taps into existence, so the decision about it
## has to be made before it arrives. See `RailCargoPolicy`.
var rail_order: StringName = RailCargoPolicy.ORDER_BALANCED
var foreman_mode: StringName = Foreman.OFF
var foreman_reserve: float = 0.25
var _foreman_tick: float = 0.0

const MILESTONES := [
	{"id": "first_100", "teus": 100.0, "text": "100 TEUs! O porto saiu do papel."},
	{"id": "ten_thousand", "teus": 1e4, "text": "10 mil TEUs. A alfândega já sabe teu nome."},
	{"id": "one_million", "teus": 1e6, "text": "1 milhão de TEUs. Isso vira notícia local."},
	{"id": "one_billion", "teus": 1e9, "text": "1 bilhão de TEUs. O oceano pediu pausa."},
	{"id": "one_trillion", "teus": 1e12, "text": "1 trilhão. Contadores do mundo inteiro choram."},
	{"id": "one_quadrillion", "teus": 1e15, "text": "1 quatrilhão. Ninguém sabe mais o que é um container."},
]

## The estimate assumes someone is actually playing during the rebuild. With
## zero taps a port with no structures and no wallet never earns a first TEU, so
## the honest answer would be "never" for every reset.
const REBUILD_ESTIMATE_TAPS := 2.0
## The old invisible 3% crit is gone: `CRIT_CHANCE` is 0 and the big payout is
# now the manifest's carga premiada (see `BerthCallController.PREMIUM_MULT`),
# visible on deck before it is earned. `CRIT_MULT` stays as the display size
# of a premiada/crit-style float, and the `crit` flag stays in quotes and saves
# so old payloads still read.
const CRIT_CHANCE := 0.0
const CRIT_MULT := 7.0
## Every unlocked achievement pays +1% permanent production ("leite"): the
# collection is part of the rate now, and `cps_breakdown` shows it as its own
# row so the bonus is visible where the number is explained.
const ACHIEVEMENT_BONUS_PER := 0.01
## The cat's surge. Below every charter reward — those are earned by playing a
## minigame, this is found by looking at the right pixel — but on the whole port
## rather than on a tap, which is what makes it worth finding at all.
const CAT_BOOST_MULT := 3.0
const CAT_BOOST_TIME := 25.0
## The decimal mark for the current language, cached. `fmt` is called on the
## counter every frame; looking a comma up in the string table that often is a
## lookup nobody needs.
var _decimal_mark := ","


const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
const MANUAL_LEDGER_LIMIT := 512

var _manual_quotes: Dictionary = {} # tx_id -> {value, crit}
var _manual_commits: Dictionary = {} # tx_id -> true


func _ready() -> void:
	# The mark is read once here and again whenever the player switches language,
	# rather than on every `fmt` call. `Loc` is an autoload and may not have built
	# its table yet at this point, so a missing key falls back to the comma the
	# cache already holds.
	# Deferred: autoload order does not guarantee `Loc` has built its table when
	# this runs, and asking early both misses the answer and prints a missing-key
	# warning for a key that is present.
	_adopt_decimal_mark.call_deferred()
	Loc.language_changed.connect(func(_code: StringName) -> void:
		_adopt_decimal_mark())
	recompute()


func _adopt_decimal_mark() -> void:
	if not Loc.has("number.decimal"):
		return
	var mark := Loc.t("number.decimal")
	_decimal_mark = mark if mark.length() == 1 else ","


func _process(delta: float) -> void:
	if boost_time > 0.0:
		boost_time = maxf(0.0, boost_time - delta)
		if boost_time == 0.0:
			recompute()
	if surge_time > 0.0:
		surge_time = maxf(0.0, surge_time - delta)
		if surge_time == 0.0:
			surge_mult = 1.0
			recompute()
	if skill_time > 0.0:
		skill_time = maxf(0.0, skill_time - delta)
		if skill_time == 0.0:
			skill_mult = 1.0
			recompute()
	if cps > 0.0:
		_earn(cps * delta)
	_tick_builds(delta)
	_tick_foreman(delta)


func foreman_unlocked() -> bool:
	## Earned by rebuilding once. Rule 7 asks what a reset *opens*, and until now
	## prestige opened nothing but a multiplier — the second run was the first run
	## again, faster, with the same thirty taps to get through it. This is the
	## thing you go back for.
	return prestige_count > 0


const FOREMAN_INTERVAL := 0.5


func _tick_foreman(delta: float) -> void:
	## Deliberately slow, and one purchase per tick. A foreman that clears the
	## treasury the instant it can afford anything takes away the moment the whole
	## genre is built on: watching the number climb past a price.
	if foreman_mode == Foreman.OFF or not foreman_unlocked():
		return
	_foreman_tick += delta
	if _foreman_tick < FOREMAN_INTERVAL:
		return
	_foreman_tick = 0.0
	var choice := Foreman.pick(_foreman_candidates(), foreman_mode,
		foreman_reserve, teus)
	if choice.is_empty():
		return
	if str(choice.get("kind", "")) == "upgrade":
		buy_upgrade(str(choice.id))
	else:
		buy_structure(str(choice.id))


func _foreman_candidates() -> Array:
	## Equipment and upgrades only. Land is never bought automatically: a parcel
	## permanently changes the shape of the terminal, and a machine deciding to
	## expand the port is the one purchase a player would be right to resent.
	var out: Array = []
	for item in StructureDB.ITEMS:
		# The gate is the player's call, never the foreman's: a standing order
		# that buys land would reshape the terminal on its own.
		if not structure_unlocked(str(item.id)):
			continue
		var quote := structure_purchase_quote(str(item.id), &"x1")
		if not bool(quote.get("ok", false)):
			continue
		# Never reach for a machine the player has not been shown yet — the same
		# reveal rule the shop uses, so the foreman cannot buy what is not on the
		# board.
		if structure_count(str(item.id)) == 0 \
				and lifetime_teus < float(item.cost) * 0.25:
			continue
		out.append({"id": str(item.id), "kind": "structure",
			"cost": float(quote.get("cost", 0.0)),
			"cps_gain": float(quote.get("cps_gain", 0.0))})
	for item in UpgradeDB.ITEMS:
		if has_upgrade(str(item.id)) or not upgrade_available(item):
			continue
		# An exclusive pair is the one purchase on the board that throws something
		# away, and which half of it a port wants is the player's call to make and
		# to defend. A standing order that quietly refitted Estoque Profundo out
		# for Giro Rápido would be undoing a decision, not automating one.
		if not UpgradeDB.conflicts_with(item, upgrades).is_empty():
			continue
		if not can_afford(float(item.cost)):
			continue
		out.append({"id": str(item.id), "kind": "upgrade",
			"cost": float(item.cost),
			"cps_gain": _upgrade_cps_gain(item)})
	return out


func _upgrade_cps_gain(item: Dictionary) -> float:
	## Derived, not simulated. Buying the upgrade into `upgrades`, calling
	## `recompute()` and rolling it back would be the general answer, but
	## `recompute()` emits `cps_changed` — so measuring every candidate twice a
	## second would publish a stream of hypothetical rates the counter would
	## faithfully display.
	##
	## A click upgrade honestly scores zero here: it raises what a tap is worth,
	## not what the port earns on its own. That is what makes MELHOR RETORNO and
	## MAIS BARATO genuinely different orders rather than two spellings of greed —
	## the greedy line never buys a tap upgrade, and the cheap line does.
	match str(item.get("kind", "")):
		"global_mult":
			return cps * maxf(0.0, float(item.get("value", 1.0)) - 1.0)
		"structure_mult":
			var gain := 0.0
			for target in UpgradeDB.targets_of(item):
				gain += structure_total_cps(target) \
					* maxf(0.0, float(item.get("value", 1.0)) - 1.0)
			return gain * _global_cps_multiplier() * _conductor_multiplier() \
				* _upgrade_global_multiplier()
		"synergy":
			return structure_total_cps(str(item.get("target", ""))) \
				* _synergy_bonus(item) * _global_cps_multiplier() \
				* _conductor_multiplier() * _upgrade_global_multiplier()
		"transform":
			# A transform can score *negative* — Turma de Terra costs a port with
			# four estivadores far more output than it hands back. The foreman is
			# ranking by payback, so an honest negative here is what keeps it from
			# gutting a tall port for a wide port's upgrade.
			return _transform_cps_delta(item)
	return 0.0


func grant_surge(multiplier: float, seconds: float) -> void:
	## A prize (or a forfeit) on everything the port earns. The strongest one wins
	## rather than stacking: two overlapping rewards multiplying into each other is
	## how a clicker economy gets away from its own balance.
	var wanted := maxf(0.01, multiplier)
	if surge_time > 0.0 and surge_mult >= wanted and wanted >= 1.0:
		surge_time = maxf(surge_time, seconds)
	else:
		surge_mult = wanted
		surge_time = maxf(0.0, seconds)
	recompute()
	EventBus.teus_changed.emit(teus)


func grant_skill(multiplier: float, seconds: float) -> void:
	## A skill burst on everything the port earns. Unlike `grant_surge` the
	## strongest does not win: it only replaces another skill burst, and always
	## multiplies with the luck surge.
	skill_mult = maxf(1.0, multiplier)
	skill_time = maxf(0.0, seconds)
	recompute()
	EventBus.teus_changed.emit(teus)


func skill_remaining() -> float:
	return skill_time


func surge_remaining() -> float:
	return surge_time


func apply_fine(amount: float) -> float:
	## A forfeit paid out of the wallet, never into debt. Returns what was actually
	## taken so the message can be honest about it.
	var taken := clampf(amount, 0.0, maxf(0.0, teus))
	teus -= taken
	EventBus.teus_changed.emit(teus)
	return taken


func grant_cat_boost() -> bool:
	## A cat visit is a one-shot bonus. Repeated taps cannot extend its timer.
	##
	## It used to multiply `click_power` and nothing else, which made the rarest
	## find in the game worthless the moment the port stopped being tapped — the
	## reward for stumbling on something unusual expired quietly the day
	## automation arrived. It grants a surge now, on everything the terminal
	## earns, which is what `surge_mult` already does for a special call.
	##
	## Smaller than it was for exactly that reason: seven times a tap was a
	## rounding error, seven times the whole port is not.
	if boost_time > 0.0:
		return false
	boost_time = CAT_BOOST_TIME
	# `grant_surge` keeps the stronger of the two, so a cat wandering through a
	# charter's ten-times surge extends it rather than cutting it to three.
	grant_surge(CAT_BOOST_MULT, CAT_BOOST_TIME)
	return true


func prestige_gain() -> int:
	## Unclaimed golden shares from productive throughput only.
	return maxi(0, EconomyMath.prestige_potential(all_time_productive_teus) \
		- prestige_level_earned)


func can_prestige() -> bool:
	return prestige_gain() > 0


func do_prestige() -> bool:
	var gain := prestige_gain()
	if gain <= 0:
		return false
	last_run_summary = {
		"run_teus": run_teus,
		"owned": owned.duplicate(true),
		"peak_owned": best_owned_by_structure.duplicate(true),
	}
	for id: String in owned:
		var peak := maxi(int(best_owned_by_structure.get(id, 0)), structure_count(id))
		best_owned_by_structure[id] = peak
		rebuild_targets[id] = peak
	shares += gain
	prestige_level_earned += gain
	prestige_count += 1
	teus = 0.0
	run_teus = 0.0
	owned.clear()
	# A rebuild takes the works with it: what was still going up is part of the
	# run being reset.
	builds.clear()
	upgrades.clear()
	boost_time = 0.0
	recompute()
	EventBus.teus_changed.emit(teus)
	EventBus.prestiged.emit(shares)
	EventBus.prestige_committed.emit(get_prestige_quote())
	return true


func get_prestige_quote() -> Dictionary:
	return {
		"gain": prestige_gain(),
		"level": prestige_level_earned,
		"wallet": shares,
		"peak": rebuild_peak(),
		# Derived, never typed: the dialog said "75%" for months while
		# `EconomyMath.REBUILD_DISCOUNT` said something else, and the two only
		# have to disagree once for the quote to be a lie.
		"rebuild_discount": "%d%% de desconto"
			% roundi((1.0 - EconomyMath.REBUILD_DISCOUNT) * 100.0),
		"productive_total": all_time_productive_teus,
		"rebuild_seconds": estimate_rebuild_seconds(),
	}


func rebuild_peak() -> Dictionary:
	## The peak the reset is about to record, which is what the discount will
	## cover. `best_owned_by_structure` alone is empty before the first prestige,
	## so quoting it told a first-time player their peak was zero machines.
	var peak: Dictionary = best_owned_by_structure.duplicate(true)
	for id: String in owned:
		peak[id] = maxi(int(peak.get(id, 0)), structure_count(id))
	return peak


func estimate_rebuild_seconds() -> float:
	## How long this port takes to come back after the reset. Without it the
	## dialog asks the player to give up a number and offers no idea of the
	## price, which is the whole reason a first prestige gets abandoned.
	if base_cps <= 0.0:
		return 0.0
	return EconomySimulator.estimate_rebuild_seconds({
		"target_production": base_cps,
		"prestige_level": prestige_level_earned + prestige_gain(),
		"rebuild_targets": rebuild_peak(),
		"tree_nodes": purchased_tree_nodes.duplicate(),
		"taps_per_second": REBUILD_ESTIMATE_TAPS,
	})


func do_click(world_pos: Vector2) -> void:
	# Legacy world API: generate an ephemeral transaction then present the same
	# visual event it has always emitted.
	var tx_id := "local:%d:%d" % [Time.get_ticks_usec(), randi()]
	var quote := make_manual_reward_quote(tx_id)
	if commit_manual_reward(tx_id, quote, world_pos):
		EventBus.container_unloaded.emit(world_pos, float(quote.value), bool(quote.crit))


func take_pilot() -> float:
	## Spent by the call that pays: the promise is for one departure only.
	var mult := pilot_pending
	pilot_pending = 1.0
	return mult


func combo_now() -> float:
	return Time.get_ticks_msec() / 1000.0


func combo_tap() -> bool:
	## One tap on the work. True when it raised the combo a step.
	return combo.note_tap(combo_now())


func combo_multiplier() -> float:
	return combo.multiplier(combo_now())


func make_manual_reward_quote(tx_id: String) -> Dictionary:
	## Returns a deterministic, persisted quote. Calling it never changes money.
	if tx_id.is_empty():
		return {"value": 0.0, "crit": false}
	if _manual_quotes.has(tx_id):
		return _manual_quotes[tx_id].duplicate()
	# A transaction id, rather than a second random roll on retry, decides crit.
	var roll := float(abs(tx_id.hash()) % 1000000) / 1000000.0
	var crit := roll < CRIT_CHANCE
	var quote := {"value": click_power * combo_multiplier() * (CRIT_MULT if crit else 1.0),
		"crit": crit}
	_manual_quotes[tx_id] = quote
	_trim_manual_ledger()
	return quote.duplicate()


func commit_manual_reward(tx_id: String, quote: Dictionary = {}, pos: Vector2 = Vector2.ZERO) -> bool:
	## Idempotent: a retry is successful but never pays the transaction twice.
	if tx_id.is_empty():
		return false
	var committed_quote: Dictionary
	if _manual_quotes.has(tx_id):
		committed_quote = _manual_quotes[tx_id]
	elif quote.is_empty():
		committed_quote = make_manual_reward_quote(tx_id)
	else:
		if not quote.has("value") or not quote.has("crit"):
			return false
		var value := float(quote.value)
		if not is_finite(value) or value < 0.0:
			return false
		committed_quote = {"value": value, "crit": bool(quote.crit)}
		_manual_quotes[tx_id] = committed_quote
	if _manual_commits.has(tx_id):
		return true
	_manual_commits[tx_id] = true
	_earn(float(committed_quote.value))
	_trim_manual_ledger()
	EventBus.manual_reward_committed.emit({
		"tx_id": tx_id, "value": float(committed_quote.value),
		"crit": bool(committed_quote.crit), "pos": pos,
	})
	return true


func grant_offline_earnings(amount: float) -> void:
	## Applies offline income through the normal accounting/milestone path once.
	if is_finite(amount) and amount > 0.0:
		_earn(amount, true)


func grant_nonproductive_reward(amount: float) -> void:
	## Career rewards are currency, but deliberately do not accelerate prestige.
	if is_finite(amount) and amount > 0.0:
		_earn(amount, false)


func _earn(amount: float, productive: bool = true) -> void:
	teus += amount
	run_teus += amount
	all_time_teus += amount
	if productive:
		all_time_productive_teus += amount
	lifetime_teus = all_time_teus
	EventBus.teus_changed.emit(teus)
	EventBus.teu_credited.emit({
		"amount": amount, "productive": productive,
		"all_time_productive": all_time_productive_teus,
	})
	_check_milestones()


func _check_milestones() -> void:
	var seen := _normalized_milestones(flags.get("milestones", []))
	for i in MILESTONES.size():
		var milestone: Dictionary = MILESTONES[i]
		if all_time_teus >= float(milestone.teus) and not seen.has(milestone.id):
			seen.append(milestone.id)
			flags["milestones"] = seen
			_notify(milestone.text)
			AudioManager.play_sfx("milestone")
			return
	flags["milestones"] = seen


func _normalized_milestones(value: Variant) -> Array:
	var normalized: Array = []
	if not value is Array:
		return normalized
	for raw in value:
		var id := ""
		if raw is String:
			id = raw
		elif raw is int and raw >= 0 and raw < MILESTONES.size():
			id = MILESTONES[raw].id
		elif raw is float and raw >= 0.0 and raw < float(MILESTONES.size()) and is_equal_approx(raw, roundf(raw)):
			id = MILESTONES[int(raw)].id
		var known := false
		for milestone: Dictionary in MILESTONES:
			if milestone.id == id:
				known = true
				break
		if known and not normalized.has(id):
			normalized.append(id)
	return normalized


func _notify(text: String) -> void:
	EventBus.notification_requested.emit({
		"text": text, "kind": &"milestone", "priority": 2})


func _trim_manual_ledger() -> void:
	while _manual_quotes.size() > MANUAL_LEDGER_LIMIT:
		_manual_quotes.erase(_manual_quotes.keys()[0])
	while _manual_commits.size() > MANUAL_LEDGER_LIMIT:
		_manual_commits.erase(_manual_commits.keys()[0])


func can_afford(cost: float) -> bool:
	return teus >= cost


func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	teus -= cost
	EventBus.teus_changed.emit(teus)
	return true


func structure_count(id: String) -> int:
	return owned.get(id, 0)


func pending_count(id: String) -> int:
	## Units of `id` paid for and still on the build queue.
	var n := 0
	for b in builds:
		if str(b.id) == id:
			n += int(b.qty)
	return n


func build_active_count() -> int:
	return mini(builds.size(), BuildQueue.MAX_ACTIVE)


func tap_build(index: int, seconds: float = 1.0) -> void:
	## Tapping a site on the works hurries it along, a second a tap.
	if index < 0 or index >= mini(builds.size(), BuildQueue.MAX_ACTIVE):
		return
	builds[index].left = maxf(0.0, float(builds[index].left) - seconds)


func finish_build(index: int) -> void:
	## The rewarded ad: done at once.
	if index >= 0 and index < builds.size():
		builds[index].left = 0.0


func advance_builds(seconds: float) -> void:
	## Time spent away. Everything in the queue works in turn, as it would have.
	var left_over := maxf(0.0, seconds)
	while left_over > 0.0 and not builds.is_empty():
		var active := mini(builds.size(), BuildQueue.MAX_ACTIVE)
		var step := left_over
		for i in active:
			step = minf(step, float(builds[i].left))
		step = maxf(step, 0.001)
		for i in active:
			builds[i].left = float(builds[i].left) - step
		left_over -= step
		_complete_finished_builds()


func _tick_builds(delta: float) -> void:
	if builds.is_empty():
		return
	for i in mini(builds.size(), BuildQueue.MAX_ACTIVE):
		builds[i].left = float(builds[i].left) - delta
	_complete_finished_builds()


func _complete_finished_builds() -> void:
	var i := 0
	var changed := false
	while i < mini(builds.size(), BuildQueue.MAX_ACTIVE):
		if float(builds[i].left) > 0.0:
			i += 1
			continue
		var done: Dictionary = builds[i]
		builds.remove_at(i)
		var id := str(done.id)
		owned[id] = structure_count(id) + int(done.qty)
		best_owned_by_structure[id] = maxi(
			int(best_owned_by_structure.get(id, 0)), structure_count(id))
		changed = true
		recompute()
		EventBus.structure_bought.emit(id, structure_count(id))
		EventBus.build_completed.emit(id, int(done.qty))
	if changed:
		EventBus.teus_changed.emit(teus)


func structure_cost(id: String) -> float:
	var quote := structure_purchase_quote(id, &"x1")
	return float(quote.get("total_cost", INF))


func buy_structure(id: String) -> bool:
	return bool(buy_structure_bulk(id, &"x1").get("ok", false))


func structure_unlocked(id: String) -> bool:
	## A machine waits on the ground it works from. `LandDB` owns the pairing;
	## this is the only place the game asks about it, so the shop, the foreman
	## and the purchase all agree by construction.
	var gate := LandDB.gate_for(id)
	return gate.is_empty() or land.has(str(gate.id))


func structure_gate(id: String) -> Dictionary:
	## The parcel still standing between the player and this machine, or {}.
	var gate := LandDB.gate_for(id)
	return {} if gate.is_empty() or land.has(str(gate.id)) else gate


func structure_purchase_quote(id: String, mode: StringName = &"x1") -> Dictionary:
	var item := StructureDB.get_item(id)
	if item.is_empty():
		return EconomyMath.purchase_quote(-1.0, 0.0, 0, mode, teus)
	if not structure_unlocked(id):
		var locked := EconomyMath.purchase_quote(float(item.cost),
			structure_cps(id), structure_count(id) + pending_count(id), mode, teus,
			int(rebuild_targets.get(id, 0)))
		locked["ok"] = false
		locked["reason"] = &"land_locked"
		locked["id"] = id
		locked["name"] = str(item.get("name", id))
		locked["gate"] = structure_gate(id)
		return locked
	# Units still on the works count toward the price: otherwise ten could be
	# bought at the price of one while the first was being built.
	var count := structure_count(id) + pending_count(id)
	var quote := EconomyMath.purchase_quote(
		float(item.cost), structure_cps(id), count, mode, teus,
		int(rebuild_targets.get(id, 0)))
	quote["id"] = id
	quote["name"] = str(item.get("name", id))
	quote["nominal_cps_before"] = nominal_cps()
	quote["nominal_cps_after"] = nominal_cps(id, int(quote.get("to_count", count)))
	quote["nominal_cps_gain"] = float(quote.nominal_cps_after) \
		- float(quote.nominal_cps_before)
	return quote


func buy_structure_bulk(id: String, mode: StringName = &"x1") -> Dictionary:
	## One quote, one debit, one event — fixed bulk modes never partially buy.
	var quote := structure_purchase_quote(id, mode)
	if not bool(quote.get("ok", false)):
		return quote
	var cost := float(quote.get("total_cost", INF))
	if not spend(cost):
		quote["ok"] = false
		quote["reason"] = &"insufficient_funds"
		return quote
	var before_total := structure_count(id) + pending_count(id)
	var qty := int(quote.get("to_count", before_total)) - before_total
	var seconds := BuildQueue.duration(id, before_total, qty) if build_times_enabled else 0.0
	if seconds > 0.0:
		# Paid now, stands later. The machine appears (and starts earning) when
		# its build finishes; the price already counts it.
		builds.append({"id": id, "qty": qty, "left": seconds, "total": seconds})
		EventBus.build_queued.emit(id, qty)
		EventBus.structure_purchase_committed.emit(quote.duplicate(true))
		return quote
	owned[id] = structure_count(id) + qty
	best_owned_by_structure[id] = maxi(
		int(best_owned_by_structure.get(id, 0)), structure_count(id))
	recompute()
	quote["nominal_cps_after"] = nominal_cps()
	quote["nominal_cps_gain"] = float(quote.nominal_cps_after) \
		- float(quote.nominal_cps_before)
	EventBus.structure_bought.emit(id, structure_count(id))
	EventBus.structure_purchase_committed.emit(quote.duplicate(true))
	return quote


func has_upgrade(id: String) -> bool:
	return upgrades.has(id)


func buy_upgrade(id: String) -> bool:
	var item := UpgradeDB.get_item(id)
	if item.is_empty() or has_upgrade(id):
		return false
	if not upgrade_available(item):
		return false
	# The exclusive halves are a refit, not a second fitting: the price carries the
	# surcharge and the loser comes off in the same transaction, so the port can
	# never be found running both sides of a choice it was asked to make.
	var refits := UpgradeDB.conflicts_with(item, upgrades)
	if not spend(UpgradeDB.price_for(item, upgrades)):
		return false
	for other in refits:
		upgrades.erase(other)
	upgrades[id] = true
	recompute()
	EventBus.upgrade_bought.emit(id)
	return true


func upgrade_available(item: Dictionary) -> bool:
	## Both gates at once. `unlock` asks whether the port is big enough to have
	## met this idea; `requires` asks whether the player has bought the node it
	## hangs off. They fail differently and the tree says which, because "blocked"
	## with no route out is the same as broken.
	return upgrade_unlocked(item) and UpgradeDB.blocked_by(item, upgrades).is_empty()


# ------------------------------------------------------------------ the shelf

func owns_cosmetic(id: StringName) -> bool:
	return bool(cosmetics_owned.get(String(id), false))


func cosmetic_on(id: StringName) -> bool:
	## Owned and switched on. Two questions, one answer, because every caller in
	## the world only ever wants this one — a decoration nobody owns is off, and
	## a decoration switched off is off, and the difference belongs to the shop.
	return owns_cosmetic(id) and bool(cosmetics_on.get(String(id), false))


func buy_cosmetic(id: StringName) -> bool:
	## Bought once, switched on immediately: nobody pays a quarter of a million
	## TEUs for a duck and then goes looking for the switch.
	if not CosmeticDb.exists(id) or owns_cosmetic(id):
		return false
	if not spend(CosmeticDb.cost(id)):
		return false
	cosmetics_owned[String(id)] = true
	cosmetics_on[String(id)] = true
	EventBus.cosmetics_changed.emit()
	return true


func set_cosmetic(id: StringName, on: bool) -> bool:
	if not owns_cosmetic(id):
		return false
	if bool(cosmetics_on.get(String(id), false)) == on:
		return false
	cosmetics_on[String(id)] = on
	EventBus.cosmetics_changed.emit()
	return true


func upgrade_preview(item: Dictionary) -> Dictionary:
	## What an upgrade actually does, in the units the player reads.
	##
	## The shop used to sell these on a punchline alone: name, joke, price. The
	## card never said *what* the thing improved or by how much, so eighteen
	## upgrades were eighteen identical mystery boxes and "as melhorias não fazem
	## sentido" was a fair description of the interface, not of the economy.
	var kind := str(item.get("kind", ""))
	var value := float(item.get("value", 1.0))
	match kind:
		"structure_mult":
			var gain := 0.0
			var names := PackedStringArray()
			for target in UpgradeDB.targets_of(item):
				gain += structure_total_cps(target) * (value - 1.0)
				names.append(str(StructureDB.get_item(target).get("name", target)))
			gain *= _global_cps_multiplier() * _conductor_multiplier() \
				* _upgrade_global_multiplier()
			return {"cps_gain": maxf(0.0, gain), "click_gain": 0.0,
				"text": "%s: %s" % [", ".join(names), _scale_text(value)]}
		"global_mult":
			return {"cps_gain": maxf(0.0, base_cps * (value - 1.0)),
				"click_gain": 0.0, "text": "Todo o porto: %s" % _scale_text(value)}
		"click_mult":
			return {"cps_gain": 0.0,
				"click_gain": maxf(0.0, click_power * (value - 1.0)),
				"text": "Cada toque: %s" % _scale_text(value)}
		"click_cps_pct":
			return {"cps_gain": 0.0, "click_gain": maxf(0.0, cps * value),
				"text": "Toque ganha %d%% da produção" % roundi(value * 100.0)}
		"synergy":
			# A synergy card has to state the part the port has *already earned*,
			# not only the rule. "+3% por cavalo" with no count is homework; "+3%
			# por cavalo (hoje +36%)" is a reason to go and buy cavalos.
			var target := str(item.get("target", ""))
			var per := str(item.get("per", ""))
			var bonus := _synergy_bonus(item)
			var gain := structure_total_cps(target) * bonus \
				* _global_cps_multiplier() * _conductor_multiplier() \
				* _upgrade_global_multiplier()
			return {"cps_gain": maxf(0.0, gain), "click_gain": 0.0,
				"text": "%s: +%d%% por %s (hoje +%d%%)" % [
					str(StructureDB.get_item(target).get("name", target)),
					roundi(value * 100.0),
					str(StructureDB.get_item(per).get("name", per)),
					roundi(bonus * 100.0)]}
		"transform":
			# The one card on the board that can honestly show a loss. It says the
			# net, in the units the counter uses, so a port that would be worse off
			# taking it can see that before paying rather than after.
			var delta := _transform_cps_delta(item)
			var machine := str(StructureDB.get_item(
				str(item.get("target", ""))).get("name", item.get("target", "")))
			return {"cps_gain": maxf(0.0, delta), "click_gain": 0.0,
				"text": "%s vira multiplicador: %s%s TEU/s agora" % [machine,
					"+" if delta >= 0.0 else "-", fmt(absf(delta))]}
		"rail_stat":
			# These move a real knob on the branch rather than a rate, and their
			# card used to print nothing at all: a node costing two hundred billion
			# whose ticket was blank. Say the knob and how far it moves.
			var parts := PackedStringArray()
			for entry in UpgradeDB.stats_of(item):
				parts.append(_rail_stat_text(entry))
			return {"cps_gain": 0.0, "click_gain": 0.0, "text": " • ".join(parts)}
	return {"cps_gain": 0.0, "click_gain": 0.0, "text": ""}


static func _rail_stat_text(entry: Dictionary) -> String:
	var stat := str(entry.get("stat", ""))
	var op := str(entry.get("operation", ""))
	var v := float(entry.get("value", 0.0))
	match stat:
		"service_gap":
			if op == "mult" and v < 1.0:
				return "Trens %d%% mais frequentes" % roundi((1.0 / v - 1.0) * 100.0)
			return "Intervalo entre trens +%d%%" % roundi((v - 1.0) * 100.0)
		"rake_length":
			return "+%d vagões por trem" % roundi(v)
		"dwell":
			return "Trem fica %s%ds na rampa" % ["+" if v >= 0.0 else "-", absi(roundi(v))]
		"auto_rate":
			return "Ramal automático +%s caixas/s" % String.num(v, 2)
		"auto_cap":
			return "teto +%s" % String.num(v, 1)
		"completion":
			return "Bônus de trem completo x%s" % String.num(v, 1)
	return stat


func _upgrade_global_multiplier() -> float:
	var value := 1.0
	for uid: String in upgrades:
		var up := UpgradeDB.get_item(uid)
		if up.get("kind") == "global_mult":
			value *= float(up.value)
	return value


func _synergy_bonus(item: Dictionary, override_id: String = "",
		override_count: int = -1) -> float:
	## What a synergy is worth to *this* port: the card's per-unit rate against how
	## many of the feeding machine are running, bending towards the node's ceiling.
	return EconomyMath.saturating_bonus(float(item.get("value", 0.0)),
		float(item.get("cap", 1.0)),
		_count_with_override(str(item.get("per", "")), override_id, override_count))


func _conductor_multiplier(override_id: String = "",
		override_count: int = -1) -> float:
	## The wide build's whole argument, in one number.
	##
	## A conductor machine gives up almost all of its own output and pays the port
	## a percentage for every unit of itself instead. Below its break-even count it
	## is a straight loss; above it, the cheapest machine in the catalogue becomes
	## the reason the expensive ones are worth anything. Multiplicative across
	## nodes, capped inside each, which is what stops two conductors from turning
	## into an exponent.
	var value := 1.0
	for uid: String in upgrades:
		var up := UpgradeDB.get_item(uid)
		if str(up.get("kind", "")) != "transform" \
				or str(up.get("mode", "")) != "conductor":
			continue
		value *= 1.0 + EconomyMath.saturating_bonus(float(up.get("value", 0.0)),
			float(up.get("cap", 1.0)), _count_with_override(
				str(up.get("target", "")), override_id, override_count))
	return value


func _transform_cps_delta(item: Dictionary) -> float:
	## What taking this transform would do to the rate, sign included.
	##
	## Two opposed movements: the target machine's own output collapses to
	## `self_mult`, and everything the port runs is lifted by the conductor share.
	## Computed against the current port rather than in the abstract, because the
	## same node is a disaster at four machines and the best purchase on the board
	## at forty.
	if str(item.get("mode", "")) != "conductor":
		return 0.0
	# The conductors are one mutually exclusive group, so taking this one *drops*
	# whatever was fitted before — and a swap moves two things, not one. The
	# incoming machine stops producing; the outgoing machine starts again. Pricing
	# only the first half made every swap look worse than it is, and pricing the
	# share as a factor on top of the one already fitted made it look far better.
	var refits := UpgradeDB.conflicts_with(item, upgrades)
	var fitted: Array[String] = [str(item.get("id", ""))]
	for uid: String in upgrades:
		if not refits.has(uid) and uid != str(item.get("id", "")):
			fitted.append(uid)

	var before := _conductor_multiplier()
	if before <= 0.0:
		return 0.0
	var after := 1.0
	# `self_mult` per machine, before and after, so a node that transforms a
	# machine some other node already transformed still composes correctly.
	var new_self: Dictionary = {}
	for uid in fitted:
		var up := UpgradeDB.get_item(uid)
		if str(up.get("kind", "")) != "transform" \
				or str(up.get("mode", "")) != "conductor":
			continue
		var machine := str(up.get("target", ""))
		after *= 1.0 + EconomyMath.saturating_bonus(float(up.get("value", 0.0)),
			float(up.get("cap", 1.0)), structure_count(machine))
		new_self[machine] = float(new_self.get(machine, 1.0)) \
			* clampf(float(up.get("self_mult", 1.0)), 0.0001, 1.0)

	# `structure_total_cps` already carries whatever is fitted *today*, so the
	# adjustment per machine is the ratio between the two, not the new value.
	var adjusted := base_cps
	var scale_out := _global_cps_multiplier() * _conductor_multiplier() \
		* _upgrade_global_multiplier()
	var machines: Dictionary = {}
	for machine: String in new_self:
		machines[machine] = true
	for uid in refits:
		machines[str(UpgradeDB.get_item(uid).get("target", ""))] = true
	for machine: String in machines:
		var old_self := 1.0
		for uid: String in upgrades:
			var up := UpgradeDB.get_item(uid)
			if str(up.get("kind", "")) == "transform" \
					and str(up.get("mode", "")) == "conductor" \
					and str(up.get("target", "")) == machine:
				old_self *= clampf(float(up.get("self_mult", 1.0)), 0.0001, 1.0)
		var factor := float(new_self.get(machine, 1.0)) / old_self
		adjusted += structure_total_cps(machine) * scale_out * (factor - 1.0)
	return (after / before) * adjusted - base_cps


static func _scale_text(value: float) -> String:
	## "x2.00" is a spreadsheet. A person says the double.
	if is_equal_approx(value, 2.0):
		return "o dobro"
	if is_equal_approx(value, 3.0):
		return "o triplo"
	if value > 1.0 and value < 2.0:
		return "+%d%%" % roundi((value - 1.0) * 100.0)
	return "x%.1f" % value


func upgrade_unlocked(item: Dictionary) -> bool:
	var unlock: Dictionary = item.get("unlock", {})
	if unlock.has("teus") and lifetime_teus < unlock.teus:
		return false
	if unlock.has("owned"):
		for sid: String in unlock.owned:
			if structure_count(sid) < unlock.owned[sid]:
				return false
	return true


func structure_cps(id: String, override_id: String = "",
		override_count: int = -1) -> float:
	## Effective CPS of one unit of the structure, upgrades applied.
	##
	## Three kinds land here, in the order they make sense to a player: the flat
	## multipliers fitted to the machine, then what the *rest* of the port lends it
	## through a synergy, then — last, because it overrides everything above it —
	## the transform that took the machine off production altogether.
	##
	## The override is what a *quote* is asking: "if I bought N more of that, what
	## would this be worth?". A synergy counts units of another machine, so without
	## it the shop would price the tractor that feeds the block at its own output
	## alone and hide the whole reason the node was bought.
	var item := StructureDB.get_item(id)
	if item.is_empty():
		return 0.0
	var value: float = item.cps
	for uid: String in upgrades:
		var up := UpgradeDB.get_item(uid)
		match str(up.get("kind", "")):
			"structure_mult":
				if UpgradeDB.targets_of(up).has(id):
					value *= float(up.get("value", 1.0))
			"synergy":
				if str(up.get("target", "")) == id:
					value *= 1.0 + _synergy_bonus(up, override_id, override_count)
			"transform":
				if str(up.get("target", "")) == id \
						and str(up.get("mode", "")) == "conductor":
					value *= float(up.get("self_mult", 1.0))
	return value


func structure_total_cps(id: String, count: int = -1,
		override_id: String = "", override_count: int = -1) -> float:
	var amount := structure_count(id) if count < 0 else maxi(0, count)
	return EconomyMath.total_cps(
		structure_cps(id, override_id, override_count), amount)


func nominal_cps(override_id: String = "", override_count: int = -1) -> float:
	var total := 0.0
	for id: String in owned:
		var count := override_count if id == override_id else structure_count(id)
		total += structure_total_cps(id, count, override_id, override_count)
	if not override_id.is_empty() and not owned.has(override_id):
		total += structure_total_cps(override_id, override_count,
			override_id, override_count)
	# The conductor share and the breadth share belong here rather than in
	# `recompute`, and both have to see the *hypothetical* count: buying the
	# fortieth estivador under Turma de Terra is worth almost nothing on its own
	# line and a great deal on everyone else's, and a quote that priced only its
	# own line would hide the entire reason the node was bought.
	return total * _global_cps_multiplier(override_id, override_count) \
		* _conductor_multiplier(override_id, override_count)


func recompute() -> void:
	var total := nominal_cps()
	var global_mult := 1.0
	var click_mult := 1.0
	var click_cps_pct := 0.0
	for uid: String in upgrades:
		var up := UpgradeDB.get_item(uid)
		match up.get("kind"):
			"global_mult":
				global_mult *= up.value
			"click_mult":
				click_mult *= up.value
			"click_cps_pct":
				click_cps_pct += up.value
	# Weather and surges are transient; the port's own rate is the part that
	# survives them, and it is what the rebuild estimate has to compare against.
	# The achievement bonus is permanent but rides with the transient chain, not
	# with `base_cps`: card previews and the transform delta are quoted in
	# base_cps, and a permanent factor inside it would make every card lie.
	base_cps = total * global_mult
	cps = base_cps * TimeManager.weather_cps_mult() * surge_mult * skill_mult \
		* achievement_multiplier()
	var manual_meta := _tree_scope_multiplier(&"manual", &"click_multiplier")
	var tree_cps_per_tap := _tree_scope_additive(&"manual", &"cps_per_tap")
	click_power = (1.0 * click_mult * manual_meta) \
		+ cps * (click_cps_pct + tree_cps_per_tap)
	# A surge is on everything the port earns, taps included — and the cat is a
	# surge now, so it needs no second multiplication here.
	click_power *= surge_mult * skill_mult
	EventBus.cps_changed.emit(cps)


func cps_breakdown() -> Array[Dictionary]:
	## The factors behind the rate, in the order `recompute` applies them. A
	## clicker's whole strategy layer is "why did that number go up", and until
	## now the game only ever showed the product. Every entry after the first is a
	## multiplier, and multiplying them all reproduces `cps` exactly — the panel
	## is the formula, not a description of it.
	var raw := 0.0          # machines at catalogue rate
	var with_milestones := 0.0
	var with_upgrades := 0.0
	for id: String in owned:
		var count := structure_count(id)
		if count <= 0:
			continue
		var item := StructureDB.get_item(id)
		if item.is_empty():
			continue
		raw += float(item.cps) * float(count)
		with_milestones += EconomyMath.total_cps(float(item.cps), count)
		with_upgrades += structure_total_cps(id, count)
	var global_mult := 1.0
	for uid: String in upgrades:
		var up := UpgradeDB.get_item(uid)
		if up.get("kind") == "global_mult":
			global_mult *= float(up.value)
	var rows: Array[Dictionary] = [
		{"label": "Máquinas", "kind": "base", "value": raw},
		{"label": "Marcos", "kind": "mult", "value": _ratio(with_milestones, raw)},
		{"label": "Melhorias", "kind": "mult", "value": _ratio(with_upgrades, with_milestones)},
		{"label": "Capital", "kind": "mult", "value": _global_cps_multiplier()},
		# Its own line, not folded into "Capital": a player who converted a fleet
		# into conductors traded away the "Melhorias" row to buy this one, and the
		# panel is the formula — if the trade is invisible here it did not happen
		# anywhere the player can see.
		{"label": "Turmas", "kind": "mult", "value": _conductor_multiplier()},
		{"label": "Melhorias globais", "kind": "mult", "value": global_mult},
		{"label": "Conquistas", "kind": "mult", "value": achievement_multiplier()},
	]
	var weather := TimeManager.weather_cps_mult()
	if not is_equal_approx(weather, 1.0):
		rows.append({"label": "Neblina", "kind": "mult", "value": weather})
	if not is_equal_approx(surge_mult, 1.0):
		rows.append({"label": "Surto", "kind": "mult", "value": surge_mult})
	if not is_equal_approx(skill_mult, 1.0):
		rows.append({"label": "Habilidade", "kind": "mult", "value": skill_mult})
	return rows


func _ratio(numerator: float, denominator: float) -> float:
	return 1.0 if denominator <= 0.0 else numerator / denominator


func rail_stat(stat: StringName, base: float) -> float:
	## A knob on the branch line, after everything fitted to it.
	##
	## `RailCargoPolicy` and `RailYard` keep the *baseline* — a six-wagon rake, a
	## 46–74 s interval, a 150 s dwell — because those are the rules of the branch
	## and they have to be readable and testable without a save. What the player
	## bought is applied here, on top, so the policy stays pure and the shop stays
	## the only place a number changes.
	##
	## Flat before multiplier, always: Trem Pesado adds six wagons and then Shuttle
	## would halve the whole rake, and the two orders give different trains. Adding
	## first is the one that matches how the cards read.
	var flat := 0.0
	var mult := 1.0
	for uid: String in upgrades:
		for entry in UpgradeDB.stats_of(UpgradeDB.get_item(uid)):
			if StringName(entry.get("stat", "")) != stat:
				continue
			match str(entry.get("operation", "")):
				"add_flat":
					flat += float(entry.get("value", 0.0))
				"mult":
					mult *= float(entry.get("value", 1.0))
	return (base + flat) * mult


func _count_with_override(id: String, override_id: String,
		override_count: int) -> int:
	## The count a hypothetical purchase would leave behind, for the one machine
	## the quote is about, and the real count for every other.
	if override_count >= 0 and id == override_id:
		return override_count
	return structure_count(id)


func _global_cps_multiplier(override_id: String = "",
		override_count: int = -1) -> float:
	return EconomyMath.prestige_multiplier(prestige_level_earned) \
		* _breadth_multiplier(override_id, override_count) \
		* _tree_scope_multiplier(&"global", &"cps_multiplier")


func _breadth_multiplier(override_id: String = "",
		override_count: int = -1) -> float:
	## The capital tree's `structures` node, rebuilt to mean something.
	##
	## It used to be `add_pct` in the same product as `global`, which made
	## `throughput_structural` and `throughput_global` the same effect with two
	## names and two prices — the player paid twice for one number. The scope did
	## not exist, so it is gone; the node now pays for *breadth*: a share for every
	## kind of machine the terminal actually runs a working fleet of.
	##
	## That is a shape the other node cannot copy. A tall port with four hundred
	## portêiners gets nothing from it; a port running ten different machines gets
	## the lot, which is exactly the composition axis item 4 was missing.
	var per_kind := _tree_scope_additive(&"structures", &"cps_per_kind")
	if per_kind <= 0.0:
		return 1.0
	var kinds := 0
	for item in StructureDB.ITEMS:
		if _count_with_override(str(item.id), override_id, override_count) \
				>= EconomyMath.BREADTH_MIN_COUNT:
			kinds += 1
	return 1.0 + per_kind * float(kinds)


func _tree_scope_multiplier(scope: StringName, stat: StringName) -> float:
	var multiplier := 1.0
	for node_id: String in purchased_tree_nodes:
		var node := PrestigeDB.get_node(node_id)
		var effect: Dictionary = node.get("effect", {})
		if StringName(effect.get("scope", "")) != scope \
				or StringName(effect.get("stat", "")) != stat:
			continue
		if effect.get("operation", "") == "add_pct":
			multiplier += float(effect.get("value", 0.0))
	return multiplier


func _tree_scope_additive(scope: StringName, stat: StringName,
		operation: String = "add_pct") -> float:
	var value := 0.0
	for node_id: String in purchased_tree_nodes:
		var node := PrestigeDB.get_node(node_id)
		var effect: Dictionary = node.get("effect", {})
		if StringName(effect.get("scope", "")) == scope \
				and StringName(effect.get("stat", "")) == stat \
				and effect.get("operation", "") == operation:
			value += float(effect.get("value", 0.0))
	return value


func achievement_multiplier() -> float:
	## +1% permanent production per unlocked achievement (see ACHIEVEMENT_BONUS_PER).
	return 1.0 + ACHIEVEMENT_BONUS_PER * float(Progression.unlocked.size())


func route_reward_bonus() -> float:
	## The Rotas branch's `route_reward_multiplier`: +% on every lane's freight.
	return _tree_scope_additive(&"routes", &"route_reward_multiplier")


func route_slot_bonus() -> int:
	## The Rotas branch's `route_slots`: extra lanes the port books in rotation.
	return int(_tree_scope_additive(&"routes", &"route_slots", "add_flat"))


func event_reward_bonus() -> float:
	## The Eventos branch's `event_reward_multiplier`: +% on charter prizes.
	return _tree_scope_additive(&"events", &"event_reward_multiplier")


func event_duration_bonus() -> float:
	## The Eventos branch's `event_duration_multiplier`: +% on charter windows.
	return _tree_scope_additive(&"events", &"event_duration_multiplier")


func buy_prestige_node(id: StringName) -> bool:
	var node := PrestigeDB.get_node(id)
	if node.is_empty() or purchased_tree_nodes.has(id):
		return false
	# A feature-gated node is buyable once its feature is unlocked — the Rotas
	# and Eventos branches read their stats for real, so the gate is a level
	# gate, not a dead button.
	var feature := String(node.get("requires_feature", ""))
	if not feature.is_empty() and not FeatureGate.unlocked(StringName(feature)):
		return false
	for required in node.get("requires", []):
		if not purchased_tree_nodes.has(StringName(required)):
			return false
	var cost := int(node.get("cost", 0))
	if cost <= 0 or shares < cost:
		return false
	shares -= cost
	purchased_tree_nodes[id] = true
	recompute()
	EventBus.prestige_tree_changed.emit(id)
	return true


const OFFLINE_EFFICIENCY_BASE := 0.5
const OFFLINE_CAP_SECONDS_BASE := 8.0 * 3600.0


func offline_efficiency() -> float:
	return _tree_scope_best(&"offline", &"offline_efficiency", OFFLINE_EFFICIENCY_BASE)


func offline_cap_seconds() -> float:
	return _tree_scope_best(&"offline", &"offline_cap_seconds", OFFLINE_CAP_SECONDS_BASE)


func _tree_scope_best(scope: StringName, stat: StringName, base: float) -> float:
	## The best tier the player owns wins, and the port's baseline is the floor.
	## Taking the last match in dictionary order instead only worked while the
	## `requires` chain happened to be bought in ascending order.
	var value := base
	for node_id: String in purchased_tree_nodes:
		var effect: Dictionary = PrestigeDB.get_node(node_id).get("effect", {})
		if StringName(effect.get("scope", "")) == scope \
				and StringName(effect.get("stat", "")) == stat \
				and effect.get("operation", "") == "set":
			value = maxf(value, float(effect.get("value", base)))
	return value


func fmt(n: float) -> String:
	## 1234 -> "1,23K"; integers below 1000 stay plain.
	##
	## Two things this has to get right that the first version did not.
	##
	## The decimal mark is localised. "1.2B" in a Brazilian game is one point two
	## billion to the code and one comma two to everyone reading it, and a counter
	## is the one string in the game a player reads a thousand times an hour.
	##
	## And the scale has an end. The suffix table stops at `Dc`, and the old loop
	## stopped dividing when it ran out of suffixes — so a port past 10^36 printed
	## "10000000Dc", a number that grows in the digits while claiming to be in the
	## largest unit there is. Past the table it goes to exponent notation, which
	## stays three significant figures wide for ever.
	if n < 1000.0:
		return str(int(n)) if absf(n - roundf(n)) < 0.05 or n >= 100.0 \
			else _decimal("%.1f" % n)
	var tier := 0
	while n >= 1000.0 and tier < SUFFIXES.size() - 1:
		n /= 1000.0
		tier += 1
	if n >= 1000.0:
		# Off the end of the table, so the number goes to an exponent. Built by
		# hand: Godot's `%` operator has no `%e`, and asking it for one raises
		# "unsupported format character" — at 10^36, which is exactly the case
		# this branch exists to handle and the last one anybody tests by playing.
		var decade := int(floor(log(n) / log(10.0)))
		var mantissa := n / pow(10.0, float(decade))
		# `log(1000)/log(10)` is 2.9999999999999996, so the floor lands one decade
		# low and the mantissa comes out as 10 — which prints "10,0e35" for a
		# number that is 1e36. Normalise rather than trust the logarithm, and
		# round to the digit that will actually be printed before deciding: a
		# mantissa of 9.99 is displayed as "10.0", so it has to be carried here or
		# the string says ten times its own exponent.
		mantissa = snappedf(mantissa, 0.1)
		while mantissa >= 10.0:
			mantissa /= 10.0
			decade += 1
		while mantissa < 1.0 and mantissa > 0.0:
			mantissa *= 10.0
			decade -= 1
		return "%se%d" % [_decimal("%.1f" % mantissa),
			decade + (SUFFIXES.size() - 1) * 3]
	if n >= 100.0:
		return "%.0f%s" % [n, SUFFIXES[tier]]
	elif n >= 10.0:
		return _decimal("%.1f" % n) + SUFFIXES[tier]
	return _decimal("%.2f" % n) + SUFFIXES[tier]


func _decimal(text: String) -> String:
	## The point `%f` produces, swapped for whatever this language writes.
	return text if _decimal_mark == "." else text.replace(".", _decimal_mark)


func to_save() -> Dictionary:
	return {
		"teus": teus, "lifetime": lifetime_teus, "run_teus": run_teus,
		"all_time_teus": all_time_teus,
		"all_time_productive_teus": all_time_productive_teus,
		"shares": shares, "prestige_level_earned": prestige_level_earned,
		"prestige_count": prestige_count,
		"purchased_tree_nodes": purchased_tree_nodes.keys(),
		"best_owned_by_structure": best_owned_by_structure,
		"rebuild_targets": rebuild_targets,
		"last_run_summary": last_run_summary,
		"owned": owned, "upgrades": upgrades.keys(), "land": land.keys(),
		"routes": routes.keys(),
		"flags": flags, "crane_policy": String(crane_policy),
		"cosmetics_owned": cosmetics_owned, "cosmetics_on": cosmetics_on,
		"route_policy": String(route_policy),
		"rail_order": String(rail_order),
		"foreman_mode": String(foreman_mode), "foreman_reserve": foreman_reserve,
		"manual_quotes": _manual_quotes,
		"manual_commits": _manual_commits.keys(),
		"builds": builds,
	}


func from_save(data: Dictionary) -> void:
	teus = data.get("teus", 0.0)
	# Boosts are session-scoped and never survive a wipe/reload.
	boost_time = 0.0
	surge_mult = 1.0
	surge_time = 0.0
	skill_mult = 1.0
	skill_time = 0.0
	combo.reset()
	pilot_pending = 1.0
	builds = BuildQueue.normalise(data.get("builds", []))
	# v1's lifetime was the only earned-total field, so it seeds both totals.
	var legacy_lifetime := float(data.get("lifetime", data.get("lifetime_teus", 0.0)))
	run_teus = float(data.get("run_teus", legacy_lifetime))
	all_time_teus = float(data.get("all_time_teus", legacy_lifetime))
	all_time_productive_teus = float(data.get("all_time_productive_teus", all_time_teus))
	lifetime_teus = all_time_teus
	shares = int(data.get("shares", 0))
	prestige_level_earned = int(data.get("prestige_level_earned", shares))
	prestige_count = int(data.get("prestige_count", 0))
	purchased_tree_nodes.clear()
	for node_id in data.get("purchased_tree_nodes", []):
		# Retired ids are rewritten to their replacement, so a save that bought
		# the old offline tier keeps it instead of losing the shares it spent.
		purchased_tree_nodes[PrestigeDB.canonical_id(StringName(node_id))] = true
	best_owned_by_structure = data.get("best_owned_by_structure", {}).duplicate(true)
	rebuild_targets = data.get("rebuild_targets", {}).duplicate(true)
	last_run_summary = data.get("last_run_summary", {}).duplicate(true)
	flags = data.get("flags", {})
	flags["milestones"] = _normalized_milestones(flags.get("milestones", []))
	# Absent in every save written before the shelf existed, which reads as an
	# undecorated port — the honest answer for a terminal that never bought one.
	cosmetics_owned = (data.get("cosmetics_owned", {}) as Dictionary).duplicate()
	cosmetics_on = (data.get("cosmetics_on", {}) as Dictionary).duplicate()
	# Absent in every save written before standing orders existed, which is the
	# same answer an unknown policy gets: the default is what those ports were
	# already doing.
	crane_policy = CraneAllocation.coerce(
		StringName(data.get("crane_policy", CraneAllocation.EVEN)))
	route_policy = RoutePolicy.coerce(
		StringName(data.get("route_policy", RoutePolicy.MIX)))
	rail_order = RailCargoPolicy.coerce_order(
		StringName(data.get("rail_order", RailCargoPolicy.ORDER_BALANCED)))
	foreman_mode = Foreman.coerce(StringName(data.get("foreman_mode", Foreman.OFF)))
	foreman_reserve = Foreman.coerce_reserve(
		float(data.get("foreman_reserve", 0.25)))
	_foreman_tick = 0.0
	owned = data.get("owned", {})
	upgrades.clear()
	for uid in data.get("upgrades", []):
		upgrades[uid] = true
	land.clear()
	routes.clear()
	for rid in data.get("routes", []):
		routes[str(rid)] = true
	for lid in data.get("land", []):
		land[lid] = true
	_manual_quotes = data.get("manual_quotes", {}).duplicate()
	_manual_commits.clear()
	for tx_id in data.get("manual_commits", []):
		_manual_commits[str(tx_id)] = true
	_trim_manual_ledger()
	recompute()
	EventBus.teus_changed.emit(teus)
