class_name BuildQueue
extends RefCounted
## How long a purchase takes to stand: the rules, with no state of its own.
##
## A machine bought in the live game is not there that instant: it is *built*.
## Small kit is up in seconds and a whole gantry crane takes minutes, so a
## purchase has a beginning and an end the player can watch, tap along with and
## — if they like — pay an advertisement to skip. The first unit of a kind is the
## slow one; units after it come off a line the terminal now knows how to run.
##
## The queue itself lives in `GameState.builds` (an Array of {id, qty, left,
## total}) so it saves with everything else, and is worked by `_process`.

const MAX_ACTIVE := 2
const MAX_SECONDS := 300.0
## Seconds [first unit of the kind, each unit after] by machine. Tier 1 is up in
## three seconds the first time and instantly after — the first minutes are for
## tapping the ship, not for waiting on a docker.
const TIERS := {
	"estivador": [3.0, 0.0], "empilhadeira": [3.0, 0.0],
	"tt": [10.0, 2.0], "reach_stacker": [10.0, 2.0],
	"rtg": [30.0, 5.0], "sts": [30.0, 5.0], "armazem": [30.0, 5.0],
	"rebocador": [90.0, 10.0], "trem": [90.0, 10.0], "flutuante": [90.0, 10.0],
	"alfandega": [180.0, 20.0], "torre": [180.0, 20.0], "drone": [180.0, 20.0],
	"porto_ia": [180.0, 20.0], "portal": [180.0, 20.0],
}


static func duration(id: String, owned_before: int, qty: int) -> float:
	## Seconds to stand `qty` units of `id` when `owned_before` already exist
	## (counting any still being built).
	var tier: Array = TIERS.get(id, [0.0, 0.0])
	if qty <= 0:
		return 0.0
	var first := float(tier[0]) if owned_before == 0 else float(tier[1])
	var rest := float(tier[1]) * float(qty - 1)
	return minf(MAX_SECONDS, first + rest)


static func normalise(raw: Variant) -> Array[Dictionary]:
	## A saved queue read back: unknown machines, non-positive quantities and
	## garbage entries are dropped rather than trusted.
	var out: Array[Dictionary] = []
	if not raw is Array:
		return out
	for entry in raw:
		if not entry is Dictionary:
			continue
		var id := str((entry as Dictionary).get("id", ""))
		var qty := int((entry as Dictionary).get("qty", 0))
		var total := float((entry as Dictionary).get("total", 0.0))
		var left := float((entry as Dictionary).get("left", total))
		if not TIERS.has(id) or qty <= 0 or not is_finite(left):
			continue
		out.append({"id": id, "qty": mini(qty, 1000),
			"total": clampf(total, 0.0, MAX_SECONDS),
			"left": clampf(left, 0.0, MAX_SECONDS)})
	return out
