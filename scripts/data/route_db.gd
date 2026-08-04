class_name RouteDB
## The trade lanes this terminal is on.
##
## A route is the answer to "why did *that* ship turn up?". Owning one adds its
## destination to the pool a call is drawn from, and each lane pulls the port in
## a different direction: a short coastal run pays little but calls constantly,
## a long ocean lane pays several times as much and keeps the berth busy for
## ages. There is never a strictly best one, which is the point.
##
## `chart` is the final pin and `ports` is the complete painted lane, both in
## the map's 0..1 equirectangular space, so the drawing and data cannot drift.

const ITEMS: Array[Dictionary] = [
	{
		"id": "cabotagem", "name": "Cabotagem Sul",
		"where": "Rio Grande - Itajaí", "cost": 0.0,
		"chart": Vector2(0.32, 0.78),
		"ports": [Vector2(0.32, 0.78)],
		"classes": ["coastal_feeder"],
		"interval": 0.75, "reward": 1.0,
		"desc": "Curta e constante. Sempre tem navio.",
	},
	{
		"id": "prata", "name": "Bacia do Prata",
		"where": "Buenos Aires - Montevidéu", "cost": 25_000.0,
		"chart": Vector2(0.31, 0.82),
		"ports": [Vector2(0.31, 0.82)],
		"classes": ["coastal_feeder", "panamax"],
		"interval": 0.9, "reward": 1.25,
		"desc": "Mais volume sem sair de casa.",
	},
	{
		"id": "caribe", "name": "Corredor do Caribe",
		"where": "Cartagena - Colón", "cost": 900_000.0,
		"chart": Vector2(0.25, 0.49),
		"ports": [Vector2(0.25, 0.49)],
		"classes": ["coastal_feeder", "panamax"],
		"interval": 1.15, "reward": 1.7,
		"desc": "Panamax começa a encostar no berço.",
	},
	{
		"id": "atlantico", "name": "Travessia Atlântica",
		"where": "Roterdã - Antuérpia", "cost": 40e6,
		"chart": Vector2(0.50, 0.29),
		"ports": [Vector2(0.50, 0.29)],
		"classes": ["panamax", "new_panamax"],
		"interval": 1.5, "reward": 2.6,
		"desc": "Escala longa, frete alto, berço ocupado.",
	},
	{
		"id": "cabo", "name": "Rota do Cabo",
		"where": "Durban - Singapura", "cost": 3e9,
		"chart": Vector2(0.79, 0.58),
		"ports": [Vector2(0.58, 0.70), Vector2(0.79, 0.58)],
		"classes": ["panamax", "new_panamax"],
		"interval": 1.7, "reward": 3.4,
		"desc": "A mais longa que um porto deste tamanho aguenta.",
	},
	{
		"id": "transpacifico", "name": "Transpacífico",
		"where": "Xangai - Los Angeles", "cost": 500e12,
		"chart": Vector2(0.12, 0.39),
		"ports": [
			Vector2(0.58, 0.70), Vector2(0.79, 0.58),
			Vector2(0.86, 0.38), Vector2(0.12, 0.39),
		],
		"classes": ["new_panamax"],
		"interval": 2.0, "reward": 5.0,
		"desc": "New Panamax e ULCV. O porto vira referência.",
	},
]

## Where the terminal itself sits on the chart.
const HOME := Vector2(0.34, 0.72)


static func get_item(id: String) -> Dictionary:
	for item in ITEMS:
		if str(item.id) == id:
			return item.duplicate(true)
	return {}


static func default_route() -> Dictionary:
	## The lane a brand new terminal is already on. A port with no route at all
	## would have no reason for any ship to call, so this one costs nothing and
	## can never be un-owned.
	return ITEMS[0].duplicate(true)


static func owned(routes: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = [default_route()]
	for item in ITEMS:
		if str(item.id) != str(ITEMS[0].id) and routes.has(str(item.id)):
			result.append(item.duplicate(true))
	return result


static func next_purchase(routes: Dictionary) -> Dictionary:
	## Lanes open in order: the map reads as reaching further out from home
	## rather than as a menu of unrelated options.
	for item in ITEMS:
		if not routes.has(str(item.id)) and float(item.cost) > 0.0:
			return item.duplicate(true)
	return {}


static func class_pool(routes: Dictionary) -> Array[String]:
	## Every silhouette any owned lane can bring. The berth draws from this, so
	## buying a lane visibly changes what ties up alongside.
	var pool: Array[String] = []
	for route in owned(routes):
		for silhouette in route.get("classes", []):
			var id := str(silhouette)
			if not pool.has(id):
				pool.append(id)
	return pool


static func reward_multiplier(routes: Dictionary) -> float:
	## The best lane the port is on sets the freight rate. Averaging would
	## punish owning a short route alongside a long one, which is backwards —
	## more lanes should never be worse than fewer.
	var best := 1.0
	for route in owned(routes):
		best = maxf(best, float(route.get("reward", 1.0)))
	return best


static func is_valid() -> bool:
	var ids := {}
	var previous_cost := -1.0
	for item in ITEMS:
		var id := str(item.get("id", ""))
		if id.is_empty() or ids.has(id):
			return false
		if (item.get("classes", []) as Array).is_empty():
			return false
		var chart: Vector2 = item.get("chart", Vector2(-1, -1))
		if chart.x < 0.0 or chart.x > 1.0 or chart.y < 0.0 or chart.y > 1.0:
			return false
		var ports: Array = item.get("ports", [])
		if ports.is_empty():
			return false
		for point: Vector2 in ports:
			if point.x < 0.0 or point.x > 1.0 \
					or point.y < 0.0 or point.y > 1.0:
				return false
		var cost := float(item.get("cost", -1.0))
		if cost < previous_cost:
			return false
		previous_cost = cost
		ids[id] = true
	return ids.size() >= 5 and is_zero_approx(float(ITEMS[0].cost))
