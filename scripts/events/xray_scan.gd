class_name XrayScan
extends RefCounted
## The rules of one X-ray inspection, with no nodes in them.
##
## A container has rolled through the Creatus Security e VWI portal and its
## scan is on the monitor: ordinary goods buried in the cargo and, among
## them, one thing that should not be there. Find it with the loupe and seize
## it before the clock runs out. Seizing anything else costs seconds.
##
## Every position is normalised to the scan (0..1 on each axis) so the rules
## never know how big the monitor is drawn. The layout is a jittered 5x2 grid —
## items never overlap, so a fair tap is never ambiguous — dealt from the
## inspection's own seed with a local generator: the same inspection is the
## same scan after a reload, and nothing here touches the global RNG.

## Frame index in `ui_xray_items.png` is the index in this table (see
## `tools/sprites/gen_customs.py`, `ORDER`). `decoy` goods are shaped like a
## weapon on purpose — the hair dryer, the drill — and only join the scan once
## the player has a few inspections behind them.
const ITEMS: Array[Dictionary] = [
	{"id": &"bear", "contraband": false},
	{"id": &"guitar", "contraband": false},
	{"id": &"bike", "contraband": false},
	{"id": &"shoe", "contraband": false},
	{"id": &"bottle", "contraband": false},
	{"id": &"tv", "contraband": false},
	{"id": &"chair", "contraband": false},
	{"id": &"laptop", "contraband": false},
	{"id": &"ball", "contraband": false},
	{"id": &"umbrella", "contraband": false},
	{"id": &"dryer", "contraband": false, "decoy": true},
	{"id": &"drill", "contraband": false, "decoy": true},
	{"id": &"pistol", "contraband": true},
	{"id": &"rifle", "contraband": true},
	{"id": &"bricks", "contraband": true},
	{"id": &"grenade", "contraband": true},
]

const COLS := 5
const ROWS := 2
## How many goods share the scan with the contraband, by level (0 = first
## inspection). Always leaves at least one empty cell so the grid is not a
## grid of solid colour.
const BASE_GOODS := 5
const MAX_GOODS := COLS * ROWS - 2
## Decoys appear from this level on.
const DECOY_LEVEL := 2
## The clock, by level. Generous on purpose: the scan is a picture to *read*
## — shapes, not pixels — and a clock tighter than the reading time turns a
## shape game into a guessing game.
const BASE_SECONDS := 24.0
const MIN_SECONDS := 14.0
const SECONDS_PER_LEVEL := 1.5
## A wrong tap costs this much clock. Tapping the same wrong spot twice costs
## once: a player who misread is not punished twice for it.
const WRONG_PENALTY := 2.0
## How far from an item's centre a tap still counts, in cells.
const HIT_RADIUS := 0.5
const JITTER := 0.18

var level := 0
var items: Array[Dictionary] = []
var time_left := BASE_SECONDS
var time_total := BASE_SECONDS
var mistakes := 0
var over := false
var victory := false
var _missed: Dictionary = {}


static func item_index(id: StringName) -> int:
	for index in ITEMS.size():
		if ITEMS[index].id == id:
			return index
	return -1


static func seconds_for(at_level: int) -> float:
	return maxf(MIN_SECONDS, BASE_SECONDS - SECONDS_PER_LEVEL * float(maxi(0, at_level)))


static func goods_for(at_level: int) -> int:
	return clampi(BASE_GOODS + maxi(0, at_level), BASE_GOODS, MAX_GOODS)


func setup(scan_seed: int, at_level: int = 0) -> void:
	level = maxi(0, at_level)
	time_total = seconds_for(level)
	time_left = time_total
	mistakes = 0
	over = false
	victory = false
	_missed = {}
	items = []
	var rng := RandomNumberGenerator.new()
	rng.seed = scan_seed
	var cells: Array[int] = []
	for cell in COLS * ROWS:
		cells.append(cell)
	_shuffle(cells, rng)
	var pool: Array[int] = []
	var contraband: Array[int] = []
	for index in ITEMS.size():
		if bool(ITEMS[index].contraband):
			contraband.append(index)
		elif not bool(ITEMS[index].get("decoy", false)) or level >= DECOY_LEVEL:
			pool.append(index)
	_shuffle(pool, rng)
	var goods := goods_for(level)
	# The contraband takes the first dealt cell; goods fill the next ones.
	var picks: Array[int] = [contraband[rng.randi_range(0, contraband.size() - 1)]]
	for n in goods:
		picks.append(pool[n % pool.size()])
	for n in picks.size():
		var cell := cells[n]
		var centre := Vector2((float(cell % COLS) + 0.5) / COLS,
			(float(cell / COLS) + 0.5) / ROWS)
		centre += Vector2(rng.randf_range(-JITTER, JITTER) / COLS,
			rng.randf_range(-JITTER, JITTER) / ROWS)
		var index := picks[n]
		items.append({"id": ITEMS[index].id, "frame": index,
			"contraband": bool(ITEMS[index].contraband), "pos": centre,
			"flip": rng.randi_range(0, 1) == 1})


func advance(delta: float) -> void:
	if over:
		return
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		over = true
		victory = false


func tap(at: Vector2) -> Dictionary:
	## A tap on the scan, in normalised coordinates. Returns what it hit:
	## `{"hit": true}` on the contraband (the round is won), otherwise the item
	## it landed on (or "") and the seconds it cost.
	if over:
		return {"hit": false, "item": "", "penalty": 0.0, "over": true}
	var found := item_at(at)
	if not found.is_empty() and bool(found.contraband):
		over = true
		victory = true
		return {"hit": true, "item": String(found.id), "penalty": 0.0, "over": true}
	var key := String(found.id) if not found.is_empty() \
		else "cell_%d" % _cell_of(at)
	var penalty := 0.0
	if not _missed.has(key):
		_missed[key] = true
		penalty = WRONG_PENALTY
		mistakes += 1
		time_left = maxf(0.0, time_left - penalty)
		if time_left <= 0.0:
			over = true
			victory = false
	return {"hit": false, "item": String(found.get("id", "")),
		"penalty": penalty, "over": over}


func item_at(at: Vector2) -> Dictionary:
	## The nearest item whose hit circle (measured in cells, so a wide monitor
	## does not make targets oval) contains the tap, or {}.
	var best := {}
	var best_d := HIT_RADIUS
	for item: Dictionary in items:
		var d := ((at - (item.pos as Vector2)) * Vector2(COLS, ROWS)).length()
		if d <= best_d:
			best_d = d
			best = item
	return best


func contraband() -> Dictionary:
	for item: Dictionary in items:
		if bool(item.contraband):
			return item
	return {}


func summary() -> Dictionary:
	return {"won": victory, "mistakes": mistakes, "time_left": time_left,
		"item": String(contraband().get("id", "")), "level": level}


func _cell_of(at: Vector2) -> int:
	var x := clampi(int(at.x * COLS), 0, COLS - 1)
	var y := clampi(int(at.y * ROWS), 0, ROWS - 1)
	return y * COLS + x


static func _shuffle(values: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := values[i]
		values[i] = values[j]
		values[j] = swap
