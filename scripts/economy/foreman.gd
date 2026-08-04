class_name Foreman
extends RefCounted
## The standing order for spending: what the port buys when nobody is looking.
##
## Rule 5 again. `CraneAllocation` decided where the gang goes; this decides
## where the money goes, and it is the half of the loop a clicker leans on
## hardest — after the first rebuild nobody wants to re-tap thirty purchases they
## already know the order of. Automating that has to *raise* the question rather
## than delete it, so the foreman is not "buy everything": the player sets what
## he optimises for and how much of the treasury he is never allowed to touch.
##
## The reserve is the whole design. Without it an auto-buyer drains the wallet to
## zero forever and land, upgrades and charters — the purchases worth saving up
## for — become unreachable the moment it is switched on. With it, choosing the
## reserve *is* the strategy: low reserve compounds fastest, high reserve keeps
## the port able to take the big decision when it appears.
##
## Pure and static, so the rule can be tested without a running game.

## Buy nothing; every purchase is the player's.
const OFF := &"off"
## Whatever pays for itself soonest. The greedy compounding line.
const PAYBACK := &"retorno"
## Whatever is cheapest. Slower, but it climbs the ladder of unlocks in order
## rather than parking on one machine.
const CHEAPEST := &"barato"

const MODES: Array[StringName] = [OFF, PAYBACK, CHEAPEST]

const LABELS := {
	OFF: "DESLIGADO",
	PAYBACK: "MELHOR RETORNO",
	CHEAPEST: "MAIS BARATO",
}

const BLURBS := {
	OFF: "Ninguém compra por você.",
	PAYBACK: "Compra o que se paga mais rápido. Cresce mais, concentra num equipamento só.",
	CHEAPEST: "Compra sempre o mais barato. Cresce menos, mas destrava a escada inteira.",
}

## What the foreman is never allowed to spend, as a share of the treasury.
## Presets rather than a slider: this is set once a session on a phone, and four
## honest choices read faster than a number nobody can reason about.
const RESERVES: Array[float] = [0.0, 0.25, 0.5, 0.75]

const RESERVE_LABELS := {
	0.0: "NADA",
	0.25: "25%",
	0.5: "METADE",
	0.75: "75%",
}


static func is_mode(id: StringName) -> bool:
	return MODES.has(id)


static func coerce(id: StringName) -> StringName:
	return id if is_mode(id) else OFF


static func coerce_reserve(value: float) -> float:
	## Snapped to a preset rather than clamped, so a hand-edited save cannot
	## produce a reserve the UI has no way to display or change.
	var best := RESERVES[0]
	var best_gap := INF
	for preset: float in RESERVES:
		var gap := absf(preset - value)
		if gap < best_gap:
			best_gap = gap
			best = preset
	return best


static func pick(candidates: Array, mode: StringName, reserve: float,
		treasury: float) -> Dictionary:
	## `candidates` is one dictionary per thing that could be bought right now:
	## {id, kind, cost, cps_gain}. Returns the one to buy, or an empty dictionary.
	##
	## Only ever one purchase per call. The foreman spending a full treasury in a
	## single frame is how an idle game's most satisfying moment — watching the
	## number climb past a price you were waiting for — turns into a wallet that
	## is simply always empty.
	if coerce(mode) == OFF:
		return {}
	var budget := treasury * (1.0 - clampf(reserve, 0.0, 1.0))
	if budget <= 0.0:
		return {}
	var best: Dictionary = {}
	var best_key := INF
	for candidate: Dictionary in candidates:
		var cost := float(candidate.get("cost", 0.0))
		if cost <= 0.0 or cost > budget:
			continue
		var key := _key(candidate, mode)
		if key >= best_key:
			continue
		best_key = key
		best = candidate
	return best


static func _key(candidate: Dictionary, mode: StringName) -> float:
	## Lower is better, so both modes sort the same way.
	var cost := float(candidate.get("cost", 0.0))
	if mode == CHEAPEST:
		return cost
	var gain := float(candidate.get("cps_gain", 0.0))
	# Something that adds no income has no payback, so the greedy line never
	# reaches for it. Land is the honest example: it is bought to make room, and
	# a foreman told to optimise return should not be the one deciding to expand.
	return INF if gain <= 0.0 else cost / gain
