class_name StructureDB
## Static data for every buyable structure.
## Cost curve: base_cost * 1.15^owned.

const GROWTH := 1.15

const ITEMS: Array[Dictionary] = [
	{
		"id": "estivador", "name": "Estivador",
		"desc": "Carrega caixas desde 1987. As costas reclamam, ele não.",
		"cost": 15.0, "cps": 0.1,
	},
	{
		"id": "empilhadeira", "name": "Empilhadeira de Vazios",
		"desc": "Só encosta em contêiner vazio. Tem padrão, a criatura.",
		"cost": 100.0, "cps": 1.0,
	},
	{
		"id": "tt", "name": "Cavalo Mecânico",
		"desc": "Puxa semirreboque de berço a pátio o dia inteiro. Nunca viu uma estrada - e não faz questão.",
		"cost": 1100.0, "cps": 8.0,
	},
	{
		"id": "reach_stacker", "name": "Reach Stacker",
		"desc": "Lança telescópica que empilha cheio em três alturas. Complexo de portêiner assumido.",
		"cost": 12000.0, "cps": 47.0,
	},
	{
		"id": "rtg", "name": "Transtêiner (RTG)",
		"desc": "Pórtico sobre pneus que vive em cima do bloco. Estaciona melhor que você.",
		"cost": 130000.0, "cps": 260.0,
	},
	{
		"id": "sts", "name": "Portêiner (STS)",
		"desc": "Ship-to-shore. Do porão ao cais em 90 segundos, sem derramar o café.",
		"cost": 1.4e6, "cps": 1400.0,
	},
	{
		"id": "armazem", "name": "Armazém Alfandegado",
		"desc": "Onde containers tiram uma soneca fiscal.",
		"cost": 20e6, "cps": 7800.0,
	},
	{
		"id": "rebocador", "name": "Rebocador",
		"desc": "Pequeno, teimoso, empurra navios 800× maiores. Terapia? Nunca fez.",
		"cost": 330e6, "cps": 44e3,
	},
	{
		"id": "trem", "name": "Ramal Ferroviário",
		"desc": "600 metros de impaciência sobre trilhos, direto pro interior.",
		"cost": 5.1e9, "cps": 260e3,
	},
	{
		"id": "flutuante", "name": "Guindaste Flutuante",
		"desc": "Cábrea que resolveu morar no mar. Ninguém questiona.",
		"cost": 75e9, "cps": 1.6e6,
	},
	{
		"id": "alfandega", "name": "Portão (Gate) Expresso",
		"desc": "OCR lê a placa, cancela sobe, caminhão some. Ninguém confere nada.",
		"cost": 1e12, "cps": 10e6,
	},
	{
		"id": "torre", "name": "Torre de Controle",
		"desc": "Coordena berço, pátio e portão. Vê tudo, sabe tudo, fofoca no rádio.",
		"cost": 14e12, "cps": 65e6,
	},
	{
		"id": "drone", "name": "Drone de Inspeção",
		"desc": "Fiscaliza de cima. Julga também.",
		"cost": 170e12, "cps": 430e6,
	},
	{
		"id": "porto_ia", "name": "Porto Autônomo IA",
		"desc": "Substituiu todo mundo. Menos o Estivador. Ninguém demite o Estivador.",
		"cost": 2.1e15, "cps": 2.9e9,
	},
	{
		"id": "portal", "name": "Portal Logístico",
		"desc": "Teleporta containers. A física reclamou; o prazo agradeceu.",
		"cost": 26e15, "cps": 21e9,
	},
]

static func get_item(id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == id:
			return item
	return {}

static func cost_for(id: String, owned: int) -> float:
	var item := get_item(id)
	if item.is_empty():
		return INF
	return item.cost * pow(GROWTH, owned)
