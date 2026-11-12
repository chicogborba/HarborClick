class_name XrayScan
extends RefCounted
## The rules of one X-ray inspection, with no nodes in them.
##
## A lorry has driven through the Receita's drive-through scanner and the
## monitor shows it side-on: the cab, the chassis and a 20ft box packed in a
## 5x2 grid. Most cells are cartons, one or two are dense machinery, one is a
## gap. Somewhere in there are one to three things that should not be.
##
## The raw picture shows none of them. That is the point of the game — a real
## operator never reads the raw image either, they *switch views*:
##
## - `METAL` paints metal blue and drops everything else: weapons show here,
##   among bikes, laptops and the drill that is shaped like a pistol.
## - `ORGANIC` paints organics orange (and glass green): the taped bricks and
##   the macaw in a tube show here, among bears, shoes and rapaduras.
## - `DENSE` (RAIO+, high energy) sees through the machinery, which is opaque
##   in every other view: whatever is hidden *behind* an engine block shows
##   here, and only here.
##
## A thing can be seized only in a view that shows it. A tap in the raw view
## costs nothing (it only asks for a filter); a tap on anything else costs
## `WRONG_PENALTY`, once per spot. Find every contraband before the clock runs
## out and the scan is won.
##
## Every position is normalised to the cargo area (0..1 on each axis). The deal
## comes from the inspection's own seed with a local generator, so the same
## inspection is the same scan after a reload and nothing here touches the
## global RNG.

enum Filter { RAW, METAL, ORGANIC, DENSE }

## Frame index in `ui_xray_items.png` is the index in this table (see
## `tools/sprites/gen_customs.py`, `ORDER`). `decoy` goods are shaped like a
## contraband of their own material on purpose — the hair dryer and the drill
## for the pistol, the rapadura for the bricks — and only join the scan once
## the player has a few inspections behind them.
const ITEMS: Array[Dictionary] = [
	{"id": &"bear", "material": &"organic", "contraband": false},
	{"id": &"guitar", "material": &"organic", "contraband": false},
	{"id": &"bike", "material": &"metal", "contraband": false},
	{"id": &"shoe", "material": &"organic", "contraband": false},
	{"id": &"bottle", "material": &"glass", "contraband": false},
	{"id": &"tv", "material": &"metal", "contraband": false},
	{"id": &"chair", "material": &"organic", "contraband": false},
	{"id": &"laptop", "material": &"metal", "contraband": false},
	{"id": &"ball", "material": &"organic", "contraband": false},
	{"id": &"umbrella", "material": &"metal", "contraband": false},
	{"id": &"dryer", "material": &"metal", "contraband": false, "decoy": true},
	{"id": &"drill", "material": &"metal", "contraband": false, "decoy": true},
	{"id": &"pistol", "material": &"metal", "contraband": true},
	{"id": &"rifle", "material": &"metal", "contraband": true},
	{"id": &"bricks", "material": &"organic", "contraband": true},
	{"id": &"grenade", "material": &"metal", "contraband": true},
	{"id": &"rapadura", "material": &"organic", "contraband": false, "decoy": true},
	{"id": &"macaw", "material": &"organic", "contraband": true},
]

const COLS := 5
const ROWS := 2
const CELLS := COLS * ROWS
## Decoys appear from this level on.
const DECOY_LEVEL := 2
## Level 0 hides its one contraband in a carton (a colour view finds it);
## level 1 hides it behind machinery (RAIO+ finds it). From then on anything
## goes, so all three views have been met before they are needed together.
const BLOCK_LEVEL := 1
## The clock: a base, more per extra contraband, a little less per level.
const BASE_SECONDS := 30.0
const SECONDS_PER_EXTRA := 10.0
const SECONDS_PER_LEVEL := 1.2
const MIN_SECONDS := 18.0
## A wrong tap costs this much clock. The same wrong spot in the same view
## costs once: a player who misread is not punished twice for it.
const WRONG_PENALTY := 2.0
## How far from an item's centre a tap still counts, in cells.
const HIT_RADIUS := 0.55
const JITTER := 0.08

var level := 0
## One entry per grid cell: {"cell", "kind" (&"carton" | &"block" | &"empty"),
## "pos" (its centre, normalised)}.
var cells: Array[Dictionary] = []
## Every thing in the box: {"id", "frame", "material", "contraband", "pos",
## "flip", "cell", "behind" (&"carton" | &"block"), "seized"}.
var items: Array[Dictionary] = []
var time_left := BASE_SECONDS
var time_total := BASE_SECONDS
var mistakes := 0
var found := 0
var over := false
var victory := false
var _missed: Dictionary = {}


static func item_index(id: StringName) -> int:
	for index in ITEMS.size():
		if ITEMS[index].id == id:
			return index
	return -1


static func contraband_for(at_level: int) -> int:
	if at_level < 2:
		return 1
	return 2 if at_level < 5 else 3


static func blocks_for(at_level: int) -> int:
	return 1 if at_level < 3 else 2


static func seconds_for(at_level: int) -> float:
	var extra := float(contraband_for(at_level) - 1)
	var floor_s := MIN_SECONDS + SECONDS_PER_EXTRA * extra * 0.5
	return maxf(floor_s, BASE_SECONDS + SECONDS_PER_EXTRA * extra
		- SECONDS_PER_LEVEL * float(maxi(0, at_level)))


static func shows(item: Dictionary, filter: Filter) -> bool:
	## Whether `filter` paints this thing. Machinery is opaque to every view
	## but RAIO+, and RAIO+ is no use on a carton: that is what makes each
	## view necessary.
	if StringName(item.get("behind", &"carton")) == &"block":
		return filter == Filter.DENSE
	match filter:
		Filter.METAL:
			return item.material == &"metal"
		Filter.ORGANIC:
			return item.material == &"organic" or item.material == &"glass"
	return false


static func filter_for(item: Dictionary) -> Filter:
	## The one view that shows this thing.
	if StringName(item.get("behind", &"carton")) == &"block":
		return Filter.DENSE
	return Filter.METAL if item.material == &"metal" else Filter.ORGANIC


func setup(scan_seed: int, at_level: int = 0) -> void:
	level = maxi(0, at_level)
	time_total = seconds_for(level)
	time_left = time_total
	mistakes = 0
	found = 0
	over = false
	victory = false
	_missed = {}
	cells = []
	items = []
	var rng := RandomNumberGenerator.new()
	rng.seed = scan_seed
	var order: Array[int] = []
	for cell in CELLS:
		order.append(cell)
	_shuffle(order, rng)
	# order[0] is the gap; the next `blocks` are machinery; the rest cartons.
	var blocks := blocks_for(level)
	var kinds: Dictionary = {}
	kinds[order[0]] = &"empty"
	for n in blocks:
		kinds[order[1 + n]] = &"block"
	for n in range(1 + blocks, CELLS):
		kinds[order[n]] = &"carton"
	for cell in CELLS:
		var centre := Vector2((float(cell % COLS) + 0.5) / COLS,
			(float(cell / COLS) + 0.5) / ROWS)
		cells.append({"cell": cell, "kind": kinds[cell], "pos": centre})
	var block_cells: Array[int] = []
	var carton_cells: Array[int] = []
	for n in range(1, CELLS):
		if kinds[order[n]] == &"block":
			block_cells.append(order[n])
		else:
			carton_cells.append(order[n])

	# The contraband, first, so the goods fill round it.
	var contraband_pool: Array[int] = []
	var goods_pool: Array[int] = []
	for index in ITEMS.size():
		if bool(ITEMS[index].contraband):
			contraband_pool.append(index)
		elif not bool(ITEMS[index].get("decoy", false)) or level >= DECOY_LEVEL:
			goods_pool.append(index)
	_shuffle(contraband_pool, rng)
	_shuffle(goods_pool, rng)
	var wanted := contraband_for(level)
	for n in wanted:
		var behind_block := false
		if level == BLOCK_LEVEL and n == 0:
			behind_block = true
		elif level > BLOCK_LEVEL and not block_cells.is_empty():
			behind_block = rng.randf() < 0.34
		if level < BLOCK_LEVEL:
			behind_block = false
		var cell := -1
		if behind_block and not block_cells.is_empty():
			cell = block_cells.pop_back()
		else:
			behind_block = false
			cell = carton_cells.pop_back()
		_place(contraband_pool[n % contraband_pool.size()], cell,
			&"block" if behind_block else &"carton", rng)
	# Every carton left gets a good. A block may hide a good too, once the
	# player knows the view — RAIO+ is then a reading view, not a reveal.
	var g := 0
	for cell in carton_cells:
		_place(goods_pool[g % goods_pool.size()], cell, &"carton", rng)
		g += 1
	if level >= DECOY_LEVEL:
		for cell in block_cells:
			if rng.randf() < 0.5:
				_place(goods_pool[g % goods_pool.size()], cell, &"block", rng)
				g += 1


func _place(index: int, cell: int, behind: StringName,
		rng: RandomNumberGenerator) -> void:
	var centre := Vector2((float(cell % COLS) + 0.5) / COLS,
		(float(cell / COLS) + 0.5) / ROWS)
	centre += Vector2(rng.randf_range(-JITTER, JITTER) / COLS,
		rng.randf_range(-JITTER, JITTER) / ROWS)
	items.append({"id": ITEMS[index].id, "frame": index,
		"material": ITEMS[index].material,
		"contraband": bool(ITEMS[index].contraband), "pos": centre,
		"flip": rng.randi_range(0, 1) == 1, "cell": cell, "behind": behind,
		"seized": false})


func total() -> int:
	var n := 0
	for item: Dictionary in items:
		if bool(item.contraband):
			n += 1
	return n


func advance(delta: float) -> void:
	if over:
		return
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		over = true
		victory = false


func tap(at: Vector2, filter: Filter) -> Dictionary:
	## A tap on the scan, in normalised coordinates, in a view. Returns
	## `{"hit", "item", "penalty", "over", "raw", "again"}`: `hit` on a seized
	## contraband, `raw` when the view shows nothing to seize, `again` on a
	## thing already seized.
	var out := {"hit": false, "item": "", "penalty": 0.0, "over": over,
		"raw": false, "again": false}
	if over:
		return out
	if filter == Filter.RAW:
		out.raw = true
		return out
	var thing := item_at(at, filter)
	if not thing.is_empty():
		out.item = String(thing.id)
		if bool(thing.seized):
			out.again = true
			return out
		if bool(thing.contraband):
			thing.seized = true
			found += 1
			out.hit = true
			if found >= total():
				over = true
				victory = true
			out.over = over
			return out
	var key := "%s@%d/%d" % [String(thing.get("id", "")), _cell_of(at), filter]
	if not _missed.has(key):
		_missed[key] = true
		out.penalty = WRONG_PENALTY
		mistakes += 1
		time_left = maxf(0.0, time_left - WRONG_PENALTY)
		if time_left <= 0.0:
			over = true
			victory = false
	out.over = over
	return out


func item_at(at: Vector2, filter: Filter) -> Dictionary:
	## The nearest thing this view shows whose hit circle (measured in cells,
	## so a wide monitor does not make targets oval) contains the tap, or {}.
	var best := {}
	var best_d := HIT_RADIUS
	for item: Dictionary in items:
		if not shows(item, filter):
			continue
		var d := ((at - (item.pos as Vector2)) * Vector2(COLS, ROWS)).length()
		if d <= best_d:
			best_d = d
			best = item
	return best


func contraband() -> Dictionary:
	## The first contraband still at large (or the first one, once all are
	## seized): what the end screen names when a scan is lost.
	var first := {}
	for item: Dictionary in items:
		if not bool(item.contraband):
			continue
		if first.is_empty():
			first = item
		if not bool(item.seized):
			return item
	return first


func contrabands() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in items:
		if bool(item.contraband):
			out.append(item)
	return out


func summary() -> Dictionary:
	return {"won": victory, "mistakes": mistakes, "time_left": time_left,
		"item": String(contraband().get("id", "")), "found": found,
		"total": total(), "level": level}


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
