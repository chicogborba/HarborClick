class_name StructureDB
## Static data for every buyable structure.
## Cost curve: base_cost * 1.15^owned.

const GROWTH := 1.15

## The authored prices. Everything reads `ITEMS`, which is this table run
## through `EconomyMath.paced`.
const RAW_ITEMS: Array[Dictionary] = [
	{
		"id": "estivador", "name": "Estivador",
		"desc": "Carrega caixas desde 1987. As costas reclamam, ele não.",
		"cost": 15.0, "growth": 1.15, "cps": 15.0 / 85.0,
	},
	{
		"id": "empilhadeira", "name": "Empilhadeira de Vazios",
		"desc": "Só encosta em contêiner vazio. Tem padrão, a criatura.",
		"cost": 100.0, "growth": 1.15, "cps": 100.0 / 80.0,
	},
	{
		"id": "tt", "name": "Cavalo Mecânico",
		"desc": "Puxa semirreboque de berço a pátio o dia inteiro. Nunca viu uma estrada - e não faz questão.",
		"cost": 1100.0, "growth": 1.16, "cps": 1100.0 / 150.0,
	},
	{
		"id": "reach_stacker", "name": "Reach Stacker",
		"desc": "Lança telescópica que empilha cheio em três alturas. Complexo de portêiner assumido.",
		"cost": 12000.0, "growth": 1.15, "cps": 12000.0 / 240.0,
	},
	{
		"id": "rtg", "name": "Transtêiner (RTG)",
		"desc": "Pórtico sobre pneus que vive em cima do bloco. Estaciona melhor que você.",
		"cost": 130000.0, "growth": 1.15, "cps": 130000.0 / 360.0,
	},
	{
		"id": "sts", "name": "Portêiner (STS)",
		"desc": "Ship-to-shore. Do porão ao cais em 90 segundos, sem derramar o café.",
		"cost": 1.4e6, "growth": 1.14, "cps": 1.4e6 / 540.0,
	},
	{
		"id": "armazem", "name": "Armazém Alfandegado",
		"desc": "Onde containers tiram uma soneca fiscal.",
		"cost": 20e6, "growth": 1.14, "cps": 20e6 / 720.0,
	},
	{
		"id": "rebocador", "name": "Rebocador",
		"desc": "Pequeno, teimoso, empurra navios 800× maiores. Terapia? Nunca fez.",
		"cost": 330e6, "growth": 1.15, "cps": 330e6 / 1000.0,
	},
	{
		"id": "trem", "name": "Ramal Ferroviário",
		# Says what it does, not just what it is. Everything the purchase changes
		# happens at the bottom of the world where the camera never goes, so a
		# card that only made a joke about rails was the one machine a player
		# could buy and never find out they owned.
		"desc": "600 metros de impaciência sobre trilhos. Dobra a composição, triplica a frequência, e o pórtico trabalha os vagões sozinho.",
		"cost": 5.1e9, "growth": 1.18, "cps": 5.1e9 / 1400.0,
	},
	{
		"id": "flutuante", "name": "Guindaste Flutuante",
		"desc": "Cábrea que resolveu morar no mar. Ninguém questiona.",
		"cost": 75e9, "growth": 1.14, "cps": 75e9 / 1900.0,
	},
	{
		"id": "alfandega", "name": "Portão (Gate) Expresso",
		"desc": "OCR lê a placa, cancela sobe, caminhão some. Ninguém confere nada.",
		"cost": 1e12, "growth": 1.14, "cps": 1e12 / 2600.0,
	},
	{
		"id": "torre", "name": "Torre de Controle",
		"desc": "Coordena berço, pátio e portão. Vê tudo, sabe tudo, fofoca no rádio.",
		"cost": 14e12, "growth": 1.18, "cps": 14e12 / 3600.0,
	},
	{
		"id": "drone", "name": "Drone de Inspeção",
		"desc": "Fiscaliza de cima. Julga também.",
		"cost": 170e12, "growth": 1.16, "cps": 170e12 / 4800.0,
	},
	{
		"id": "porto_ia", "name": "Porto Autônomo IA",
		"desc": "Substituiu todo mundo. Menos o Estivador. Ninguém demite o Estivador.",
		"cost": 2.1e15, "growth": 1.17, "cps": 2.1e15 / 6400.0,
	},
	{
		"id": "portal", "name": "Portal Logístico",
		"desc": "Teleporta containers. A física reclamou; o prazo agradeceu.",
		"cost": 26e15, "growth": 1.2, "cps": 26e15 / 8600.0,
	},
]
static var ITEMS: Array[Dictionary] = EconomyMath.paced(RAW_ITEMS)


static func apply_port() -> void:
	## The same machines, under the names they go by in the active port
	## (`PortDB.names`). Ids and numbers never change, so nothing that keys on
	## an id — the yard, the actors, a save — can tell ports apart.
	ITEMS = EconomyMath.paced(RAW_ITEMS)
	for item in ITEMS:
		item["name"] = PortDB.name_for(str(item.id), str(item.name))

static func get_item(id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == id:
			return item
	return {}

static func cost_for(id: String, owned: int) -> float:
	## C8: each machine has its own growth rate (`growth`, default GROWTH), so a
	# port that buys only the cheapest machine saturates faster than one that
	# spreads — the fleet shape becomes a decision, not one pyramid.
	var item := get_item(id)
	if item.is_empty():
		return INF
	return item.cost * pow(float(item.get("growth", GROWTH)), owned)
