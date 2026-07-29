class_name LandDB
## Land parcels. Buying one extends the world downward and unlocks yard slots.

const PARCEL_H := 150.0

const ITEMS: Array[Dictionary] = [
	{
		"id": "patio_norte", "name": "Pátio Norte",
		"desc": "Terra batida com potencial. E um carrinho de pipoca abandonado.",
		"cost": 5000.0, "slots": 4,
	},
	{
		"id": "patio_sul", "name": "Pátio Sul",
		"desc": "O antigo dono plantava alface aqui. Agora é logística.",
		"cost": 250e3, "slots": 4,
	},
	{
		"id": "area_ferroviaria", "name": "Área Ferroviária",
		"desc": "Trilhos incluídos. O trem vem junto? Não. O trem se compra.",
		"cost": 8e6, "slots": 5,
	},
	{
		"id": "retroporto", "name": "Retroporto",
		"desc": "Fica atrás do porto. O nome não engana ninguém.",
		"cost": 400e6, "slots": 5,
	},
	{
		"id": "aterro_leste", "name": "Aterro Leste",
		"desc": "Terreno que não existia em 2019. A engenharia deu um jeito.",
		"cost": 20e9, "slots": 6,
	},
	{
		"id": "zona_franca", "name": "Zona Franca",
		"desc": "Impostos entram aqui e nunca mais saem. Ninguém investiga.",
		"cost": 1.2e12, "slots": 6,
	},
	{
		"id": "ilha_artificial", "name": "Ilha Artificial",
		"desc": "Fizemos uma ilha. Porque sim. Porque cabia no orçamento.",
		"cost": 90e12, "slots": 7,
	},
	{
		"id": "porto_orbital", "name": "Porto Orbital",
		"desc": "Containers em órbita baixa. A ANTAQ ainda está avaliando.",
		"cost": 6e15, "slots": 8,
	},
]

static func get_item(id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == id:
			return item
	return {}


static func next_parcel() -> Dictionary:
	## First unbought parcel, or {} when everything is owned.
	for item in ITEMS:
		if not GameState.land.has(item.id):
			return item
	return {}


static func owned_count() -> int:
	var n := 0
	for item in ITEMS:
		if GameState.land.has(item.id):
			n += 1
	return n
