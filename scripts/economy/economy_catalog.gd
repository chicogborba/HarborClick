class_name EconomyCatalog
## Phase 3 starting economy. Costs remain the authored game prices; CPS is
## derived precisely from the intended payback so the runtime and simulator
## share a single curve.

const ITEMS: Array[Dictionary] = [
	{"id": "estivador", "name": "Estivador", "base_cost": 15.0, "cps": 15.0 / 85.0, "payback": 85.0},
	{"id": "empilhadeira", "name": "Empilhadeira", "base_cost": 100.0, "cps": 100.0 / 80.0, "payback": 80.0},
	{"id": "tt", "name": "TT", "base_cost": 1100.0, "cps": 1100.0 / 150.0, "payback": 150.0},
	{"id": "reach_stacker", "name": "Reach Stacker", "base_cost": 12000.0, "cps": 12000.0 / 180.0, "payback": 180.0},
	{"id": "rtg", "name": "RTG", "base_cost": 130000.0, "cps": 130000.0 / 240.0, "payback": 240.0},
	{"id": "sts", "name": "STS", "base_cost": 1400000.0, "cps": 1400000.0 / 300.0, "payback": 300.0},
	{"id": "armazem", "name": "Armazém", "base_cost": 20000000.0, "cps": 20000000.0 / 360.0, "payback": 360.0},
	{"id": "rebocador", "name": "Rebocador", "base_cost": 330000000.0, "cps": 330000000.0 / 450.0, "payback": 450.0},
	{"id": "trem", "name": "Trem", "base_cost": 5100000000.0, "cps": 5100000000.0 / 600.0, "payback": 600.0},
	{"id": "flutuante", "name": "Flutuante", "base_cost": 75000000000.0, "cps": 75000000000.0 / 720.0, "payback": 720.0},
	{"id": "alfandega", "name": "Alfândega", "base_cost": 1000000000000.0, "cps": 1000000000000.0 / 900.0, "payback": 900.0},
	{"id": "torre", "name": "Torre", "base_cost": 14000000000000.0, "cps": 14000000000000.0 / 1200.0, "payback": 1200.0},
	{"id": "drone", "name": "Drone", "base_cost": 170000000000000.0, "cps": 170000000000000.0 / 1500.0, "payback": 1500.0},
	{"id": "porto_ia", "name": "Porto IA", "base_cost": 2100000000000000.0, "cps": 2100000000000000.0 / 1800.0, "payback": 1800.0},
	{"id": "portal", "name": "Portal", "base_cost": 26000000000000000.0, "cps": 26000000000000000.0 / 2400.0, "payback": 2400.0},
]


static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in ITEMS:
		result.append(item.duplicate())
	return result


static func get_item(id: StringName) -> Dictionary:
	for item in all():
		if StringName(item.id) == id:
			return item
	return {}
