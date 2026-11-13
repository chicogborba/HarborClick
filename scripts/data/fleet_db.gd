class_name FleetDB
## The named ships that call at the terminal, and the album they fill.
##
## `ShipCatalog.SILHOUETTES` are *classes* — what a berth and a lane care about
## (feeder, panamax, new panamax). This file is the *fleet*: the actual ships
## that sail under those classes, each with its own name, hull, livery, flag of
## registry and rarity. A call rolls one of these, the berth sees its class, and
## the album in the port diary records the ship.
##
## What varies, and where it is drawn (`tools/sprites/gen_ship.py`):
##
## - `hull` — one of five natively drawn 66x232 hulls (`HULLS`). Every one keeps
##   the same 24-bay deck: the berth contract does not care which ship it is.
##   The album's side-on portrait (`ship_side_<hull>`) is where their real size
##   shows — a coaster is half the length of an ULCV and carries two tiers.
## - `hull_color` on the paint layer, `trim_color` on one of four trim patterns
##   (`TRIMS`), `house_color` on the accommodation block.
## - `flag` — the ensign painted on the forecastle and shown on the album card,
##   a code from `FLAGS`, whose order is the frame order of `ui_flags.png`.
## - `rarity` — how often it is rolled (`RARITY_WEIGHT`).
## - `port` — a ship that only ever calls at one port. Most sail everywhere;
##   the American and Chinese registries call only where they are at home, so
##   finishing the album means running more than one terminal.
## - `special` — rolled never; it arrives only as a charter (`special_variant`).
## - `legacy` — the "class:palette" key the old album recorded for this hull and
##   livery, so a save from before the fleet keeps the ships it had seen.

const FLAGS: Array[StringName] = [
	&"br", &"us", &"cn", &"nl", &"sg", &"ae", &"pa", &"lr", &"mh", &"mt",
	&"gr", &"dk", &"de", &"fr", &"it", &"es", &"gb", &"jp", &"kr", &"no",
	&"pt", &"in", &"ar", &"mx", &"ru", &"pl", &"tr", &"cl", &"ca", &"se",
]
const FLAG_SIZE := Vector2(16, 11)

## hull id -> the berth class it sails as, and the size it is sold as.
const HULLS := {
	"coaster": {"class": "coastal_feeder", "type": "Coaster"},
	"feeder": {"class": "coastal_feeder", "type": "Feeder"},
	"panamax": {"class": "panamax", "type": "Panamax"},
	"new_panamax": {"class": "new_panamax", "type": "Neo-Panamax"},
	"ulcv": {"class": "new_panamax", "type": "ULCV"},
}
const HULL_ORDER: Array[String] = ["coaster", "feeder", "panamax", "new_panamax", "ulcv"]
## Same order as the frames of `ship_trim_<hull>.png` and `ship_side_<hull>.png`.
const TRIMS: Array[String] = ["band", "stripe", "bow", "stern"]
const RARITY_WEIGHT := {"common": 12, "rare": 4, "legend": 1}

## Album prizes: every this-many ships seen pays a lump of production once.
const MILESTONE_STEP := 10

const SHIPS: Array[Dictionary] = [
	# ------------------------------------------------ home waters (Santos + all)
	{"id": "mare_alta", "name": "Maré Alta", "hull": "feeder", "flag": &"br",
		"hull_color": "#5c89a8", "trim_color": "#f4f0e6", "trim": "band",
		"house_color": "#ffffff", "rarity": "common", "capacity": 1200,
		"legacy": "coastal_feeder:harbor_blue"},
	{"id": "tia_zuleica", "name": "Tia Zuleica", "hull": "coaster", "flag": &"br",
		"hull_color": "#a95d51", "trim_color": "#f0c040", "trim": "stripe",
		"house_color": "#f4e2b8", "rarity": "common", "capacity": 850,
		"port": &"santos", "legacy": "coastal_feeder:rust_red"},
	{"id": "vento_sul", "name": "Vento Sul", "hull": "feeder", "flag": &"br",
		"hull_color": "#527b69", "trim_color": "#ffffff", "trim": "stripe",
		"house_color": "#ffffff", "rarity": "common", "capacity": 1100,
		"legacy": "coastal_feeder:evergreen"},
	{"id": "ouro_itajai", "name": "Ouro de Itajaí", "hull": "coaster", "flag": &"br",
		"hull_color": "#ad8750", "trim_color": "#3c4250", "trim": "band",
		"house_color": "#ffffff", "rarity": "common", "capacity": 900,
		"legacy": "coastal_feeder:sunset_gold"},
	{"id": "atlantico_azul", "name": "Atlântico Azul", "hull": "panamax", "flag": &"br",
		"hull_color": "#5c89a8", "trim_color": "#ffffff", "trim": "bow",
		"house_color": "#ffffff", "rarity": "common", "capacity": 4500,
		"legacy": "panamax:harbor_blue"},
	{"id": "cidade_santos", "name": "Cidade de Santos", "hull": "panamax", "flag": &"br",
		"hull_color": "#a95d51", "trim_color": "#ffffff", "trim": "stern",
		"house_color": "#ffffff", "rarity": "rare", "capacity": 4800,
		"port": &"santos", "legacy": "panamax:rust_red"},
	{"id": "serra_do_mar", "name": "Serra do Mar", "hull": "panamax", "flag": &"br",
		"hull_color": "#527b69", "trim_color": "#f0c040", "trim": "stripe",
		"house_color": "#ffffff", "rarity": "common", "capacity": 4300,
		"legacy": "panamax:evergreen"},
	{"id": "sol_poente", "name": "Sol Poente", "hull": "panamax", "flag": &"pa",
		"hull_color": "#ad8750", "trim_color": "#ffffff", "trim": "band",
		"house_color": "#ffffff", "rarity": "common", "capacity": 4600,
		"legacy": "panamax:sunset_gold"},
	{"id": "cruzeiro_do_sul", "name": "Cruzeiro do Sul", "hull": "new_panamax",
		"flag": &"br", "hull_color": "#5c89a8", "trim_color": "#f0c040",
		"trim": "stripe", "house_color": "#ffffff", "rarity": "rare",
		"capacity": 8000, "legacy": "new_panamax:harbor_blue"},
	{"id": "ferrugem_nobre", "name": "Ferrugem Nobre", "hull": "new_panamax",
		"flag": &"lr", "hull_color": "#a95d51", "trim_color": "#e8e8e8",
		"trim": "bow", "house_color": "#ffffff", "rarity": "common",
		"capacity": 8200, "legacy": "new_panamax:rust_red"},
	{"id": "mata_atlantica", "name": "Mata Atlântica", "hull": "new_panamax",
		"flag": &"br", "hull_color": "#527b69", "trim_color": "#ffffff",
		"trim": "stern", "house_color": "#ffffff", "rarity": "common",
		"capacity": 7800, "legacy": "new_panamax:evergreen"},
	{"id": "dourado", "name": "Dourado", "hull": "new_panamax", "flag": &"mh",
		"hull_color": "#ad8750", "trim_color": "#3c4250", "trim": "band",
		"house_color": "#ffffff", "rarity": "common", "capacity": 8500,
		"legacy": "new_panamax:sunset_gold"},

	# ----------------------------------------------------- the world's registries
	{"id": "nordlys", "name": "Nordlys", "hull": "feeder", "flag": &"no",
		"hull_color": "#c8303a", "trim_color": "#ffffff", "trim": "stripe",
		"house_color": "#ffffff", "rarity": "common", "capacity": 1000},
	{"id": "kobenhavn", "name": "Kobenhavn Express", "hull": "panamax", "flag": &"dk",
		"hull_color": "#7aa6c8", "trim_color": "#ffffff", "trim": "band",
		"house_color": "#ffffff", "rarity": "common", "capacity": 5000},
	{"id": "elbe_pilot", "name": "Elbe Pilot", "hull": "feeder", "flag": &"de",
		"hull_color": "#f08a24", "trim_color": "#3c4250", "trim": "band",
		"house_color": "#ffffff", "rarity": "common", "capacity": 1300},
	{"id": "etoile_marseille", "name": "Étoile de Marseille", "hull": "panamax",
		"flag": &"fr", "hull_color": "#2f4a8a", "trim_color": "#d03a3a",
		"trim": "stripe", "house_color": "#ffffff", "rarity": "common",
		"capacity": 4400},
	{"id": "laguna_veneta", "name": "Laguna Veneta", "hull": "feeder", "flag": &"it",
		"hull_color": "#2f7a5a", "trim_color": "#ffffff", "trim": "stripe",
		"house_color": "#f4e2b8", "rarity": "common", "capacity": 1150},
	{"id": "costa_brava", "name": "Costa Brava", "hull": "coaster", "flag": &"es",
		"hull_color": "#e8c040", "trim_color": "#c03030", "trim": "band",
		"house_color": "#ffffff", "rarity": "common", "capacity": 700},
	{"id": "thames_lady", "name": "Thames Lady", "hull": "coaster", "flag": &"gb",
		"hull_color": "#2c3e5c", "trim_color": "#c8a040", "trim": "stripe",
		"house_color": "#f4e2b8", "rarity": "rare", "capacity": 650},
	{"id": "sakura_maru", "name": "Sakura Maru", "hull": "new_panamax", "flag": &"jp",
		"hull_color": "#e6e8ee", "trim_color": "#d03050", "trim": "stripe",
		"house_color": "#ffffff", "rarity": "rare", "capacity": 9000},
	{"id": "hanbit_star", "name": "Hanbit Star", "hull": "ulcv", "flag": &"kr",
		"hull_color": "#2f6fbf", "trim_color": "#e8e8e8", "trim": "stripe",
		"house_color": "#ffffff", "rarity": "rare", "capacity": 20000},
	{"id": "lisboa_clara", "name": "Lisboa Clara", "hull": "feeder", "flag": &"pt",
		"hull_color": "#3f8a5a", "trim_color": "#d03a3a", "trim": "bow",
		"house_color": "#f4e2b8", "rarity": "common", "capacity": 1050},
	{"id": "ganga_rani", "name": "Ganga Rani", "hull": "panamax", "flag": &"in",
		"hull_color": "#e08a3a", "trim_color": "#2f6a3a", "trim": "stern",
		"house_color": "#ffffff", "rarity": "common", "capacity": 4200},
	{"id": "rio_de_la_plata", "name": "Río de la Plata", "hull": "feeder", "flag": &"ar",
		"hull_color": "#6caee0", "trim_color": "#ffffff", "trim": "band",
		"house_color": "#ffffff", "rarity": "common", "capacity": 1250},
	{"id": "sol_de_veracruz", "name": "Sol de Veracruz", "hull": "panamax", "flag": &"mx",
		"hull_color": "#2f7a4a", "trim_color": "#d03030", "trim": "band",
		"house_color": "#ffffff", "rarity": "common", "capacity": 4700},
	{"id": "belaya_noch", "name": "Belaya Noch", "hull": "feeder", "flag": &"ru",
		"hull_color": "#3c4250", "trim_color": "#d03a3a", "trim": "stripe",
		"house_color": "#cfe0f0", "rarity": "rare", "capacity": 1100},
	{"id": "wisla", "name": "Wisła", "hull": "coaster", "flag": &"pl",
		"hull_color": "#c03838", "trim_color": "#ffffff", "trim": "stripe",
		"house_color": "#ffffff", "rarity": "common", "capacity": 800},
	{"id": "bogazici", "name": "Boğaziçi", "hull": "panamax", "flag": &"tr",
		"hull_color": "#b03030", "trim_color": "#ffffff", "trim": "band",
		"house_color": "#ffffff", "rarity": "common", "capacity": 4100},
	{"id": "valparaiso", "name": "Valparaíso", "hull": "coaster", "flag": &"cl",
		"hull_color": "#2f4a9a", "trim_color": "#ffffff", "trim": "stern",
		"house_color": "#ffffff", "rarity": "common", "capacity": 750},
	{"id": "maple_trader", "name": "Maple Trader", "hull": "new_panamax", "flag": &"ca",
		"hull_color": "#c03030", "trim_color": "#ffffff", "trim": "stern",
		"house_color": "#ffffff", "rarity": "common", "capacity": 7600},
	{"id": "gotland_viking", "name": "Gotland Viking", "hull": "feeder", "flag": &"se",
		"hull_color": "#2a6ab0", "trim_color": "#f0c040", "trim": "stripe",
		"house_color": "#ffffff", "rarity": "rare", "capacity": 1000},
	{"id": "kalimera", "name": "Kalimera", "hull": "new_panamax", "flag": &"gr",
		"hull_color": "#2a5aa8", "trim_color": "#ffffff", "trim": "bow",
		"house_color": "#ffffff", "rarity": "common", "capacity": 8100},
	{"id": "valletta_grace", "name": "Valletta Grace", "hull": "panamax", "flag": &"mt",
		"hull_color": "#d8d4cc", "trim_color": "#c03030", "trim": "stripe",
		"house_color": "#ffffff", "rarity": "rare", "capacity": 4400},
	{"id": "merlion_star", "name": "Merlion Star", "hull": "ulcv", "flag": &"sg",
		"hull_color": "#c03838", "trim_color": "#ffffff", "trim": "band",
		"house_color": "#ffffff", "rarity": "rare", "capacity": 18000},
	{"id": "desert_falcon", "name": "Desert Falcon", "hull": "new_panamax", "flag": &"ae",
		"hull_color": "#c8a870", "trim_color": "#2f6a3a", "trim": "band",
		"house_color": "#ffffff", "rarity": "rare", "capacity": 8800},
	{"id": "rotterdam_bridge", "name": "Rotterdam Bridge", "hull": "ulcv", "flag": &"nl",
		"hull_color": "#f0a030", "trim_color": "#2f4a8a", "trim": "stripe",
		"house_color": "#ffffff", "rarity": "rare", "capacity": 21000},

	# ---------------------------------------------- Long Beach only (US registry)
	{"id": "pacific_navigator", "name": "Pacific Navigator", "hull": "panamax",
		"flag": &"us", "hull_color": "#34527c", "trim_color": "#ffffff",
		"trim": "stripe", "house_color": "#ffffff", "rarity": "common",
		"capacity": 5100, "port": &"long_beach", "legacy": "panamax:pacific_navy"},
	{"id": "sequoia", "name": "Sequoia", "hull": "feeder", "flag": &"us",
		"hull_color": "#3f6b52", "trim_color": "#f4e2b8", "trim": "band",
		"house_color": "#ffffff", "rarity": "common", "capacity": 1400,
		"port": &"long_beach", "legacy": "coastal_feeder:sequoia_green"},
	{"id": "golden_gate", "name": "Golden Gate", "hull": "new_panamax", "flag": &"us",
		"hull_color": "#c8703a", "trim_color": "#ffffff", "trim": "stern",
		"house_color": "#ffffff", "rarity": "rare", "capacity": 9200,
		"port": &"long_beach", "legacy": "new_panamax:sunset_orange"},
	{"id": "gray_gull", "name": "Gray Gull", "hull": "coaster", "flag": &"us",
		"hull_color": "#7b8590", "trim_color": "#f0c040", "trim": "stripe",
		"house_color": "#ffffff", "rarity": "common", "capacity": 800,
		"port": &"long_beach", "legacy": "coastal_feeder:gull_grey"},

	# ------------------------------------------------ Shanghai only (CN registry)
	{"id": "yangtze_pearl", "name": "Yangtze Pearl", "hull": "panamax", "flag": &"cn",
		"hull_color": "#2f5f9c", "trim_color": "#ffffff", "trim": "band",
		"house_color": "#cfe0f0", "rarity": "common", "capacity": 4900,
		"port": &"shanghai", "legacy": "panamax:ocean_blue"},
	{"id": "red_lantern", "name": "Red Lantern", "hull": "feeder", "flag": &"cn",
		"hull_color": "#b03c36", "trim_color": "#f0c040", "trim": "stripe",
		"house_color": "#ffffff", "rarity": "common", "capacity": 1300,
		"port": &"shanghai", "legacy": "coastal_feeder:lacquer_red"},
	{"id": "jade_dragon", "name": "Jade Dragon", "hull": "ulcv", "flag": &"cn",
		"hull_color": "#3f8a78", "trim_color": "#f0c040", "trim": "stripe",
		"house_color": "#ffffff", "rarity": "legend", "capacity": 24000,
		"port": &"shanghai", "legacy": "new_panamax:jade"},
	{"id": "ink_mountain", "name": "Ink Mountain", "hull": "new_panamax", "flag": &"cn",
		"hull_color": "#3c4250", "trim_color": "#b03c36", "trim": "bow",
		"house_color": "#ffffff", "rarity": "rare", "capacity": 8600,
		"port": &"shanghai", "legacy": "new_panamax:ink"},

	# ------------------------------------------------------------------ legends
	{"id": "fantasma_do_cabo", "name": "Fantasma do Cabo", "hull": "coaster",
		"flag": &"nl", "hull_color": "#e8e8ec", "trim_color": "#9aa8b0",
		"trim": "stripe", "house_color": "#cfd8dc", "rarity": "legend",
		"capacity": 500},
	{"id": "leviata", "name": "Leviatã", "hull": "ulcv", "flag": &"pa",
		"hull_color": "#1c2a3a", "trim_color": "#e05030", "trim": "stripe",
		"house_color": "#ffffff", "rarity": "legend", "capacity": 24000},
	# The charter: never rolled, only booked (`SpecialCallDirector`). Its hull
	# follows the class the charter asks for, so `hull` here is the default.
	{"id": "gala_noturna", "name": "Gala Noturna", "hull": "panamax", "flag": &"mt",
		"hull_color": "#2b2733", "trim_color": "#f0d68a", "trim": "stripe",
		"house_color": "#f4e2b8", "rarity": "legend", "capacity": 5200,
		"special": true},
]


static func get_ship(id: String) -> Dictionary:
	for ship in SHIPS:
		if str(ship.id) == id:
			return ship
	return {}


static func special_ship() -> Dictionary:
	for ship in SHIPS:
		if bool(ship.get("special", false)):
			return ship
	return {}


static func ship_class(ship: Dictionary) -> String:
	return str((HULLS.get(str(ship.get("hull", "")), {}) as Dictionary).get("class", ""))


static func hull_type(ship: Dictionary) -> String:
	return str((HULLS.get(str(ship.get("hull", "")), {}) as Dictionary).get("type", ""))


static func flag_index(code: StringName) -> int:
	return maxi(0, FLAGS.find(code))


static func flag_region(code: StringName) -> Rect2:
	return Rect2(Vector2(flag_index(code) * FLAG_SIZE.x, 0.0), FLAG_SIZE)


static func trim_index(ship: Dictionary) -> int:
	return maxi(0, TRIMS.find(str(ship.get("trim", "band"))))


static func album_order() -> Array[Dictionary]:
	## The album's page order: by size, smallest first, then by name — a grid
	## that reads like a size chart, with the charter last.
	var out: Array[Dictionary] = []
	for ship in SHIPS:
		out.append(ship)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("special", false)) != bool(b.get("special", false)):
			return not bool(a.get("special", false))
		var ha := HULL_ORDER.find(str(a.hull))
		var hb := HULL_ORDER.find(str(b.hull))
		if ha != hb:
			return ha < hb
		return str(a.name) < str(b.name))
	return out


static func is_seen(ship: Dictionary, album: Dictionary) -> bool:
	return album.has(str(ship.id)) or (ship.has("legacy") and album.has(str(ship.legacy)))


static func seen_count(album: Dictionary) -> int:
	var n := 0
	for ship in SHIPS:
		if is_seen(ship, album):
			n += 1
	return n


static func is_valid() -> bool:
	var ids := {}
	var legacy := {}
	var specials := 0
	for ship in SHIPS:
		var id := str(ship.get("id", ""))
		if id.is_empty() or ids.has(id) or str(ship.get("name", "")).is_empty():
			return false
		ids[id] = true
		if not HULLS.has(str(ship.get("hull", ""))):
			return false
		if not FLAGS.has(StringName(ship.get("flag", &""))):
			return false
		if not TRIMS.has(str(ship.get("trim", ""))):
			return false
		if not RARITY_WEIGHT.has(str(ship.get("rarity", ""))):
			return false
		if int(ship.get("capacity", 0)) <= 0:
			return false
		for key in ["hull_color", "trim_color", "house_color"]:
			if not Color.html_is_valid(str(ship.get(key, ""))):
				return false
		if ship.has("legacy"):
			if legacy.has(str(ship.legacy)):
				return false
			legacy[str(ship.legacy)] = true
		if bool(ship.get("special", false)):
			specials += 1
	return SHIPS.size() >= 30 and specials == 1
