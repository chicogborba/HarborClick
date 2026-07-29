class_name EconomyMath
## Deterministic, side-effect-free helpers for the incremental economy.

const GROWTH := 1.15
const MILESTONES: Array[int] = [10, 25, 50, 100]
const MAX_BULK_LIMIT := 10_000
const MAX_BULK_COUNT := MAX_BULK_LIMIT # compatibility for callers/tests
const PRESTIGE_DIVISOR := 100_000_000.0
const REBUILD_DISCOUNT := 0.25


static func next_cost(base_cost: float, owned: int, growth: float = GROWTH) -> float:
	if base_cost < 0.0 or owned < 0 or growth <= 1.0:
		return INF
	return base_cost * exp(log(growth) * float(owned))


static func bulk_cost(base_cost: float, owned: int, amount: int, growth: float = GROWTH) -> float:
	## Closed-form geometric series. This deliberately has no per-unit loop.
	if amount <= 0:
		return 0.0
	if base_cost < 0.0 or owned < 0 or growth <= 1.0:
		return INF
	var first := next_cost(base_cost, owned, growth)
	var exponent := log(growth) * float(amount)
	if exponent > 700.0:
		return INF
	return first * (exp(exponent) - 1.0) / (growth - 1.0)


static func max_affordable(base_cost: float, owned: int, currency: float, growth: float = GROWTH, cap: int = MAX_BULK_COUNT) -> int:
	## The analytic estimate is corrected with a bounded binary search for float edges.
	if currency < 0.0 or base_cost <= 0.0 or owned < 0 or growth <= 1.0 or cap <= 0:
		return 0
	var first := next_cost(base_cost, owned, growth)
	if currency + _epsilon(currency) < first:
		return 0
	var scaled: float = currency * (growth - 1.0) / first
	var estimate: int = int(floor(log(1.0 + maxf(0.0, scaled)) / log(growth)))
	estimate = clampi(estimate, 0, cap)
	var low: int = maxi(0, estimate - 2)
	var high: int = mini(cap, estimate + 2)
	while high < cap and bulk_cost(base_cost, owned, high, growth) <= currency + _epsilon(currency):
		low = high
		high = min(cap, high * 2)
		if high == low:
			break
	while low < high:
		var middle: int = low + int((high - low + 1) * 0.5)
		if bulk_cost(base_cost, owned, middle, growth) <= currency + _epsilon(currency):
			low = middle
		else:
			high = middle - 1
	return low


static func purchase_cost(base_cost: float, owned: int, mode: StringName, currency: float = INF, growth: float = GROWTH) -> Dictionary:
	var amount := 1
	match mode:
		&"x10": amount = 10
		&"x25": amount = 25
		&"max": amount = max_affordable(base_cost, owned, currency, growth)
		_: amount = 1
	return {
		"mode": mode,
		"amount": amount,
		"cost": bulk_cost(base_cost, owned, amount, growth),
		"first_cost": next_cost(base_cost, owned, growth),
	}


static func discounted_bulk_cost(base_cost: float, owned: int, amount: int,
		rebuild_target: int, discount: float = REBUILD_DISCOUNT,
		growth: float = GROWTH) -> float:
	## The first units up to the historic peak are discounted after prestige.
	if amount <= 0:
		return 0.0
	if discount < 0.0 or discount > 1.0:
		return INF
	var discounted_amount := clampi(rebuild_target - owned, 0, amount)
	var discounted_cost := bulk_cost(base_cost, owned, discounted_amount, growth)
	var regular_cost := bulk_cost(base_cost, owned + discounted_amount,
		amount - discounted_amount, growth)
	if not is_finite(discounted_cost) or not is_finite(regular_cost):
		return INF
	return discounted_cost * discount + regular_cost


static func max_affordable_discounted(base_cost: float, owned: int,
		currency: float, rebuild_target: int, discount: float = REBUILD_DISCOUNT,
		growth: float = GROWTH, cap: int = MAX_BULK_LIMIT) -> int:
	## A bounded binary search keeps MAX exact even across a rebuild discount.
	if currency < 0.0 or base_cost <= 0.0 or owned < 0 or cap <= 0:
		return 0
	var low := 0
	var high := cap
	while low < high:
		var middle: int = low + int((high - low + 1) * 0.5)
		if discounted_bulk_cost(base_cost, owned, middle, rebuild_target,
			discount, growth) <= currency + _epsilon(currency):
			low = middle
		else:
			high = middle - 1
	return low


static func purchase_quote(base_cost: float, unit_cps: float, owned: int,
		mode: StringName, currency: float, rebuild_target: int = 0,
		discount: float = REBUILD_DISCOUNT, growth: float = GROWTH) -> Dictionary:
	## Single runtime/simulator contract for x1/x10/x25/MAX. No state mutates.
	var requested := 1
	match mode:
		&"x1": requested = 1
		&"x10": requested = 10
		&"x25": requested = 25
		&"max": requested = max_affordable_discounted(base_cost, owned,
			currency, rebuild_target, discount, growth)
		_:
			return _invalid_quote(mode, &"invalid_mode", owned)
	if requested <= 0:
		return _invalid_quote(mode, &"insufficient_funds", owned)
	var total_cost := discounted_bulk_cost(base_cost, owned, requested,
		rebuild_target, discount, growth)
	var affordable := is_finite(total_cost) and total_cost <= currency + _epsilon(currency)
	var after := owned + requested
	var crossed: Array[StringName] = []
	for threshold in MILESTONES:
		if owned < threshold and after >= threshold:
			crossed.append(StringName(str(threshold)))
	var next_discount := discount if after < rebuild_target else 1.0
	return {
		"ok": affordable,
		"reason": &"" if affordable else &"insufficient_funds",
		"mode": mode,
		"quantity": requested,
		"amount": requested,
		"from_count": owned,
		"to_count": after,
		"total_cost": total_cost,
		"next_unit_cost": next_cost(base_cost, after, growth) * next_discount,
		"nominal_cps_before": total_cps(unit_cps, owned),
		"nominal_cps_after": total_cps(unit_cps, after),
		"nominal_cps_gain": purchase_cps_gain(unit_cps, owned, requested),
		"milestones_crossed": crossed,
	}


static func _invalid_quote(mode: StringName, reason: StringName, owned: int) -> Dictionary:
	return {
		"ok": false, "reason": reason, "mode": mode, "quantity": 0,
		"amount": 0, "from_count": owned, "to_count": owned,
		"total_cost": 0.0, "next_unit_cost": INF,
		"nominal_cps_before": 0.0, "nominal_cps_after": 0.0,
		"nominal_cps_gain": 0.0, "milestones_crossed": [],
	}


static func milestone_multiplier(owned: int) -> float:
	var reached := 0
	for threshold in MILESTONES:
		if owned >= threshold:
			reached += 1
	return pow(2.0, float(reached))


static func total_cps(unit_cps: float, owned: int) -> float:
	if unit_cps < 0.0 or owned <= 0:
		return 0.0
	return unit_cps * float(owned) * milestone_multiplier(owned)


static func purchase_cps_gain(unit_cps: float, owned: int, amount: int) -> float:
	if amount <= 0:
		return 0.0
	return total_cps(unit_cps, owned + amount) - total_cps(unit_cps, owned)


static func purchase_impact(base_cost: float, unit_cps: float, owned: int, amount: int, growth: float = GROWTH) -> Dictionary:
	var cost := bulk_cost(base_cost, owned, amount, growth)
	var cps_gain := purchase_cps_gain(unit_cps, owned, amount)
	return {
		"amount": amount,
		"cost": cost,
		"cps_gain": cps_gain,
		"payback_seconds": INF if cps_gain <= 0.0 else cost / cps_gain,
		"milestone_before": milestone_multiplier(owned),
		"milestone_after": milestone_multiplier(owned + amount),
	}


static func prestige_potential(all_time_productive: float) -> int:
	return max(0, int(floor(sqrt(maxf(0.0, all_time_productive) / PRESTIGE_DIVISOR))))


static func prestige_multiplier(level: int) -> float:
	return 1.0 + 0.05 * sqrt(float(maxi(0, level)))


static func _epsilon(value: float) -> float:
	return maxf(0.000001, absf(value) * 0.0000000001)
