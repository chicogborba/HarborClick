class_name PortDB
## The ports a terminal operator can run, and which one is on screen.
##
## A port is not a skin. Each one is its own terminal with its own yard, cargo,
## berth, clock, level and wallet — `SaveManager` keeps one save file per port
## inside the profile, so every cargo and persistence contract holds per port
## without a line of the cargo code knowing ports exist. What this file owns is
## everything that makes one port *not the last one*:
##
## - `mods` — what the place is good and bad at. Long Beach is an intermodal
##   port: trucks and the branch line carry it. Shanghai is an automated one:
##   the cranes and the machines that need nobody carry it, and a tap is worth
##   less. They are multipliers on the same machines, applied in
##   `GameState.structure_cps` and shown as their own row in the rate breakdown.
## - `upgrades` — a local trunk on the upgrade tree (`branch: "porto"`), merged
##   into `UpgradeDB.ITEMS` only while that port is active.
## - `names` — what the same machine or parcel is called there.
## - `palettes` — the liveries that call at its berth.
## - `theme` — the sprite suffix its ground and plant are painted under
##   (`tools/sprites/gen_ports.py`) and the colour of its water.
##
## `active` is the port the running scene is built for. It is set by
## `SaveManager` *before* a save is applied, because production maths read it.
## Every port in the table is playable: two abroad, chosen for how differently
## they play (`traits`), rather than a row of names with a multiplier each.

const HOME: StringName = &"santos"

## Chart positions are in the world map's 0..1 equirectangular space:
## x = (lon + 180) / 360, y = (90 - lat) / 180.
const PORTS: Array[Dictionary] = [
	{
		"id": &"santos", "name": "Santos", "country": "Brasil", "flag": 0,
		"chart": Vector2(0.371, 0.633), "playable": true, "cost": 0.0,
		"tagline": "Onde tudo começou.",
		"perk": "Porto de casa: equilibrado em tudo.",
		"grant": 0.0,
		"mods": {}, "click": 1.0,
		"theme": {"suffix": ""},
	},
	{
		"id": &"long_beach", "name": "Long Beach", "country": "EUA", "flag": 1,
		"chart": Vector2(0.172, 0.3125), "playable": true, "cost": 250e6,
		"tagline": "A porta do Pacífico.",
		"perk": "Intermodal: caminhões e trens chegam no dobro do ritmo e rendem x2. Toque +50%.",
		"grant": 2500.0,
		"mods": {"tt": 2.0, "trem": 2.0, "alfandega": 2.0, "armazem": 1.5},
		"click": 1.5,
		# How the place *plays*, read by the systems it changes: the gate calls a
		# lorry twice as often and the branch line runs twice as many trains.
		"traits": {"gate_cadence": 0.5, "rail_gap": 0.5},
		"theme": {
			"suffix": "usa",
			"water": ["#3fa8d0", "#1f78b8", "#104c92", "#082c62"],
		},
		"names": {
			"estivador": "Longshoreman", "tt": "Yard Truck",
			"alfandega": "Gate de Terminal Island", "trem": "Ramal Alameda",
			"armazem": "Warehouse do Pier T", "rebocador": "Tug do Pacífico",
			"patio_norte": "Pier T", "patio_sul": "Pier J",
			"retroporto": "Terminal Island", "area_ferroviaria": "Pátio ICTF",
			"aterro_leste": "Middle Harbor", "zona_franca": "Foreign Trade Zone",
			"ilha_artificial": "Ilha Chaffee",
		},
		"palettes": [
			{"id": "pacific_navy", "hull": "#34527c", "wake": "#c4e6f0", "cargo": "#ffffff"},
			{"id": "sequoia_green", "hull": "#3f6b52", "wake": "#cdeee6", "cargo": "#f2fff4"},
			{"id": "gull_grey", "hull": "#7b8590", "wake": "#dcecf0", "cargo": "#ffffff"},
			{"id": "sunset_orange", "hull": "#c8703a", "wake": "#e6eef0", "cargo": "#fff4e0"},
		],
		"upgrades": [
			{"id": "lb_sindicato", "name": "Turno do Sindicato", "short": "Sindicato",
				"desc": "Hora extra paga em dobro. O braço agradece.",
				"branch": "porto", "kind": "click_mult", "value": 2.0,
				"cost": 500.0, "unlock": {"teus": 200.0}},
			{"id": "lb_chassis", "name": "Pool de Chassis", "short": "Chassis",
				"desc": "Ninguém espera carreta. Tem sempre uma sobrando.",
				"branch": "porto", "kind": "structure_mult", "target": "tt",
				"value": 2.0, "cost": 40_000.0,
				"unlock": {"owned": {"tt": 5}}},
			{"id": "lb_alameda", "name": "Corredor Alameda", "short": "Alameda",
				"desc": "Trinta quilômetros de trilho rebaixado até o centro. Sem um cruzamento.",
				"branch": "porto", "kind": "structure_mult",
				"targets": ["tt", "alfandega"], "value": 2.0, "cost": 600_000.0,
				"requires": ["lb_chassis"], "unlock": {"owned": {"tt": 15}}},
			{"id": "lb_double_stack", "name": "Trem Double-Stack", "short": "Double-Stack",
				"desc": "Duas caixas de altura, três quilômetros de comprimento.",
				"branch": "porto", "kind": "structure_mult", "target": "trem",
				"value": 3.0, "cost": 80e6, "requires": ["lb_alameda"],
				"unlock": {"owned": {"trem": 1}}},
			{"id": "lb_peak_season", "name": "Peak Season", "short": "Peak Season",
				"desc": "De agosto a outubro o Natal inteiro passa por aqui.",
				"branch": "porto", "kind": "global_mult", "value": 1.5,
				"cost": 2e9, "requires": ["lb_double_stack"],
				"unlock": {"teus": 5e8}},
		],
	},
	{
		"id": &"shanghai", "name": "Xangai", "country": "China", "flag": 2,
		"chart": Vector2(0.8375, 0.327), "playable": true, "cost": 50e9,
		"tagline": "O maior porto do mundo.",
		"perk": "Automação: Capataz liberado, guindastes trabalham 60% mais rápido sozinhos, monção sem perda. Toque -50%.",
		"grant": 100_000.0,
		"mods": {"sts": 2.0, "rtg": 2.0, "drone": 2.0, "porto_ia": 2.0,
			"torre": 1.5},
		"click": 0.5,
		# The automated port: the foreman (the auto-buyer) works from day one, the
		# quay and yard cranes move boxes on their own 60% faster, and the monsoon
		# fog comes three times as often but costs an automated port nothing.
		"traits": {"foreman_free": true, "crane_auto": 1.6, "fog_chance": 0.45,
			"fog_free": true},
		"theme": {
			"suffix": "cn",
			"water": ["#8e8a5c", "#76734e", "#5e5d43", "#464838"],
		},
		"names": {
			"estivador": "Operador de Cais", "tt": "AGV Automático",
			"sts": "Portêiner ZPMC", "trem": "Ramal de Luchao",
			"armazem": "Armazém de Lingang", "rebocador": "Rebocador do Yangtzé",
			"patio_norte": "Yangshan Fase I", "patio_sul": "Yangshan Fase II",
			"retroporto": "Yangshan Fase III", "area_ferroviaria": "Pátio de Luchao",
			"aterro_leste": "Yangshan Fase IV", "zona_franca": "Zona Franca de Lingang",
			"ilha_artificial": "Ilha Xiaoyangshan",
		},
		"palettes": [
			{"id": "ocean_blue", "hull": "#2f5f9c", "wake": "#c8e8f0", "cargo": "#ffffff"},
			{"id": "lacquer_red", "hull": "#b03c36", "wake": "#e4eeee", "cargo": "#fff3e0"},
			{"id": "jade", "hull": "#3f8a78", "wake": "#d0f0e8", "cargo": "#f0fff8"},
			{"id": "ink", "hull": "#3c4250", "wake": "#d8e6ee", "cargo": "#ffffff"},
		],
		"upgrades": [
			{"id": "sh_agv", "name": "Frota de AGVs", "short": "AGVs",
				"desc": "Carretas sem cabine seguindo ímãs no piso. Ninguém buzina.",
				"branch": "porto", "kind": "structure_mult", "target": "tt",
				"value": 3.0, "cost": 60_000.0, "unlock": {"owned": {"tt": 5}}},
			{"id": "sh_zpmc", "name": "Portêineres de Fábrica", "short": "ZPMC",
				"desc": "Chegam montados, de navio, já pintados.",
				"branch": "porto", "kind": "structure_mult", "target": "sts",
				"value": 2.0, "cost": 5e6, "requires": ["sh_agv"],
				"unlock": {"owned": {"sts": 1}}},
			{"id": "sh_fase4", "name": "Cais Sem Luz", "short": "Cais Sem Luz",
				"desc": "Fase IV opera no escuro. Máquina não precisa enxergar.",
				"branch": "porto", "kind": "structure_mult",
				"targets": ["rtg", "sts"], "value": 2.0, "cost": 400e6,
				"requires": ["sh_zpmc"], "unlock": {"owned": {"rtg": 10}}},
			{"id": "sh_semana_dourada", "name": "Semana Dourada", "short": "Semana Dourada",
				"desc": "Antes do feriado o mundo inteiro quer a carga embarcada.",
				"branch": "porto", "kind": "global_mult", "value": 1.5,
				"cost": 2e9, "requires": ["sh_fase4"], "unlock": {"teus": 5e8}},
			{"id": "sh_5g", "name": "Rede 5G do Cais", "short": "5G",
				"desc": "Latência de um milissegundo entre a torre e a garra.",
				"branch": "porto", "kind": "structure_mult",
				"targets": ["drone", "porto_ia"], "value": 3.0, "cost": 5e13,
				"requires": ["sh_semana_dourada"],
				"unlock": {"owned": {"drone": 1}}},
		],
	},
]

## The local trunk a port adds to the upgrade tree.
const BRANCH := {"id": "porto", "title": "Porto", "art": "torre"}
## What every *other* open port is worth to this one: the network is the reason
## to run more than one terminal, and the only thing ports share.
const NETWORK_BONUS_PER_PORT := 0.10

static var active: StringName = HOME
## How many ports this profile has open, home included. Kept by `SaveManager`
## from the profile's port ledger so production maths never read a file.
static var open_count := 1
## Where the Voyage scene is headed. Set by whoever asks for the trip.
static var destination: StringName = &""

static var _texture_cache: Dictionary = {}


static func get_port(id: StringName) -> Dictionary:
	for port in PORTS:
		if port.id == id:
			return port
	return {}


static func current() -> Dictionary:
	var port := get_port(active)
	return port if not port.is_empty() else PORTS[0]


static func is_playable(id: StringName) -> bool:
	return bool(get_port(id).get("playable", false))


static func set_active(id: StringName) -> void:
	## Points every catalogue at this port. Unknown or unplayable ids fall back
	## to home rather than leaving the game on a port that has no content.
	active = id if is_playable(id) else HOME
	_texture_cache.clear()
	StructureDB.apply_port()
	LandDB.apply_port()
	UpgradeDB.apply_port()
	ShipCatalog.apply_port()


# ------------------------------------------------------------------- economy

static func structure_mult(structure_id: String) -> float:
	return float((current().get("mods", {}) as Dictionary).get(structure_id, 1.0))


static func port_trait(key: String, fallback: Variant) -> Variant:
	## A gameplay switch the active port flips (`traits`). Every system that
	## reads one names its home default as the fallback, so home plays exactly
	## as it always has.
	return (current().get("traits", {}) as Dictionary).get(key, fallback)


static func click_mult() -> float:
	return float(current().get("click", 1.0))


static func network_multiplier() -> float:
	return 1.0 + NETWORK_BONUS_PER_PORT * float(maxi(0, open_count - 1))


static func upgrades() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in current().get("upgrades", []):
		out.append(item)
	return out


static func name_for(id: String, fallback: String) -> String:
	return str((current().get("names", {}) as Dictionary).get(id, fallback))


static func palettes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for palette: Dictionary in current().get("palettes", []):
		out.append(palette)
	return out


static func all_palettes() -> Array[Dictionary]:
	## Every livery of every port: a saved hull must still find its paint after
	## the catalogue it was drawn from is no longer the active one.
	var out: Array[Dictionary] = []
	for port in PORTS:
		for palette: Dictionary in port.get("palettes", []):
			out.append(palette)
	return out


# --------------------------------------------------------------------- theme

static func sprite_name(base: String) -> String:
	## The port's own drawing of a sprite when it has one (`<base>__<suffix>`),
	## otherwise the shared one.
	var suffix := str((current().get("theme", {}) as Dictionary).get("suffix", ""))
	if suffix.is_empty():
		return base
	var themed := "%s__%s" % [base, suffix]
	return themed if ResourceLoader.exists("res://assets/sprites/%s.png" % themed) \
		else base


static func tex(base: String) -> Texture2D:
	var key := sprite_name(base)
	if not _texture_cache.has(key):
		_texture_cache[key] = load("res://assets/sprites/%s.png" % key)
	return _texture_cache[key]


static func water_colors() -> Array[Color]:
	var out: Array[Color] = []
	for hex: String in (current().get("theme", {}) as Dictionary).get("water", []):
		out.append(Color(hex))
	return out


# ---------------------------------------------------------------- validation

static func is_valid() -> bool:
	var ids := {}
	for port in PORTS:
		var id := StringName(port.get("id", &""))
		if id == &"" or ids.has(id):
			return false
		ids[id] = true
		var chart: Vector2 = port.get("chart", Vector2(-1, -1))
		if chart.x < 0.0 or chart.x > 1.0 or chart.y < 0.0 or chart.y > 1.0:
			return false
		if bool(port.get("playable", false)):
			if not port.has("mods") or not port.has("theme"):
				return false
			for sid: String in port.mods:
				if StructureDB.get_item(sid).is_empty():
					return false
			for item: Dictionary in port.get("upgrades", []):
				if str(item.get("branch", "")) != "porto":
					return false
	return ids.has(HOME) and float(get_port(HOME).get("cost", 1.0)) == 0.0
