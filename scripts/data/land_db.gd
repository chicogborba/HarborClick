class_name LandDB
## Land parcels: what the terminal is allowed to become next.
##
## Land used to be a pure drain. Eight parcels costing up to ninety trillion,
## producing nothing, buying nothing but yard slots the player mostly had spare —
## the one purchase in the game a payback-greedy player was right to never make,
## and it sat there looking like the biggest number on the board.
##
## Now every parcel **opens a machine**. You do not buy a rail shuttle and then
## wonder where it runs: you buy the rail yard, the track appears, and the
## shuttle becomes available. The ladder of equipment and the ladder of ground
## are the same ladder, which is what makes a terminal expand rather than
## accumulate.
##
## Each parcel is priced to land comfortably before the machine it opens, so the
## gate is a decision about *when*, never a wall. `unlocks` is a structure id
## from `StructureDB`; `GameState.structure_unlocked` is the only reader.

const PARCEL_H := 150.0

## The authored prices. Everything reads `ITEMS`, which is this table run
## through `EconomyMath.paced`.
const RAW_ITEMS: Array[Dictionary] = [
	{
		"id": "patio_norte", "name": "Pátio Norte",
		"desc": "Terra batida com potencial. E um carrinho de pipoca abandonado.",
		"cost": 5000.0, "slots": 4, "unlocks": "reach_stacker",
	},
	{
		"id": "patio_sul", "name": "Pátio Sul",
		"desc": "O antigo dono plantava alface aqui. Agora é logística.",
		"cost": 60e3, "slots": 4, "unlocks": "rtg",
	},
	{
		"id": "retroporto", "name": "Retroporto",
		"desc": "Fica atrás do porto. O nome não engana ninguém.",
		"cost": 9e6, "slots": 5, "unlocks": "armazem",
	},
	{
		"id": "area_ferroviaria", "name": "Área Ferroviária",
		"desc": "Trilhos, dormentes e um para-choque no fim da linha. O trem se compra à parte.",
		"cost": 2.2e9, "slots": 5, "unlocks": "trem",
	},
	{
		"id": "aterro_leste", "name": "Aterro Leste",
		"desc": "Terreno que não existia em 2019. A engenharia deu um jeito.",
		"cost": 32e9, "slots": 6, "unlocks": "flutuante",
	},
	{
		"id": "zona_franca", "name": "Zona Franca",
		"desc": "Impostos entram aqui e nunca mais saem. Ninguém investiga.",
		"cost": 420e9, "slots": 6, "unlocks": "alfandega",
	},
	{
		"id": "ilha_artificial", "name": "Ilha Artificial",
		"desc": "Fizemos uma ilha. Porque sim. Porque cabia no orçamento.",
		"cost": 900e12, "slots": 7, "unlocks": "porto_ia",
	},
	{
		"id": "porto_orbital", "name": "Porto Orbital",
		"desc": "Containers em órbita baixa. A ANTAQ ainda está avaliando.",
		"cost": 11e15, "slots": 8, "unlocks": "portal",
	},
]
static var ITEMS: Array[Dictionary] = EconomyMath.paced(RAW_ITEMS)


static func apply_port() -> void:
	## The same parcels, under the names the active port gives its ground.
	ITEMS = EconomyMath.paced(RAW_ITEMS)
	for item in ITEMS:
		item["name"] = PortDB.name_for(str(item.id), str(item.name))


static func get_item(id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == id:
			return item
	return {}


static func gate_for(structure_id: String) -> Dictionary:
	## The parcel a machine waits on, or {} when it waits on nothing.
	for item in ITEMS:
		if str(item.get("unlocks", "")) == structure_id:
			return item
	return {}


## Every query below takes the owned set rather than reaching for the autoload.
## This class is pure data and the balance sandbox links against it; the moment
## it touched `GameState`, `LandDB` stopped compiling in a headless tool script
## and every gated machine silently reported itself locked — the simulator bought
## no cranes at all and reported a curve for a game nobody plays.
static func next_parcel(owned: Dictionary) -> Dictionary:
	## First unbought parcel, or {} when everything is owned.
	for item in ITEMS:
		if not owned.has(item.id):
			return item
	return {}


static func owned_count(owned: Dictionary) -> int:
	var n := 0
	for item in ITEMS:
		if owned.has(item.id):
			n += 1
	return n


static func owned_slots(owned: Dictionary) -> int:
	## Parcel capacity is data, not an incidental "one parcel = one row" rule.
	var total := 0
	for item in ITEMS:
		if owned.has(item.id):
			total += int(item.get("slots", 0))
	return total


static func is_valid() -> bool:
	## Two invariants the shop and the ladder both depend on: parcels open in
	## ascending price order, and a parcel never gates a machine the player could
	## already have afforded long before — that would read as the game taking
	## something away.
	var previous := -1.0
	var gated := {}
	for item in ITEMS:
		var cost := float(item.get("cost", 0.0))
		if cost <= previous:
			return false
		previous = cost
		var unlocks := str(item.get("unlocks", ""))
		if unlocks.is_empty() or gated.has(unlocks):
			return false
		gated[unlocks] = true
		var machine := StructureDB.get_item(unlocks)
		if machine.is_empty() or float(machine.get("cost", 0.0)) <= cost:
			return false
	return true
