class_name UpgradeDB
## Static data for upgrades.
## kind: "click_mult" (multiplies click), "structure_mult" (multiplies one
## structure's cps), "global_mult" (multiplies all cps),
## "click_cps_pct" (click also gains % of cps).
## unlock: {teus: X} lifetime TEUs or {owned: {id: n}} structure count needed.

const ITEMS: Array[Dictionary] = [
	# --- click upgrades ---
	{"id": "luvas", "name": "Luvas Reforçadas",
		"desc": "Menos farpa, mais caixa.",
		"kind": "click_mult", "value": 2.0, "cost": 100.0,
		"unlock": {"teus": 50.0}},
	{"id": "gancho", "name": "Gancho de Estivador",
		"desc": "O clássico. Nunca sai de moda, às vezes sai da mão.",
		"kind": "click_mult", "value": 2.0, "cost": 1000.0,
		"unlock": {"teus": 500.0}},
	{"id": "exoesqueleto", "name": "Exoesqueleto Hidráulico",
		"desc": "Agora o RH exige alongamento antes de vestir.",
		"kind": "click_mult", "value": 3.0, "cost": 50000.0,
		"unlock": {"teus": 20000.0}},
	{"id": "clique_sindical", "name": "Clique Sindicalizado",
		"desc": "Cada clique conta. Literalmente, pro sindicato.",
		"kind": "click_cps_pct", "value": 0.01, "cost": 5e6,
		"unlock": {"teus": 1e6}},

	# --- estivador ---
	{"id": "cafe_forte", "name": "Café de Rancho",
		"desc": "Coado na meia. Eficiência dobra, paladar chora.",
		"kind": "structure_mult", "target": "estivador", "value": 2.0,
		"cost": 500.0, "unlock": {"owned": {"estivador": 5}}},
	{"id": "carrinho_mao", "name": "Carrinho de Mão Turbo",
		"desc": "Rodinha nova. NOVA. Entende a revolução?",
		"kind": "structure_mult", "target": "estivador", "value": 2.0,
		"cost": 5000.0, "unlock": {"owned": {"estivador": 15}}},
	{"id": "sindicato", "name": "Sindicato Organizado",
		"desc": "Pausa pro café virou instituição. Produtividade subiu. Ninguém explica.",
		"kind": "structure_mult", "target": "estivador", "value": 2.0,
		"cost": 50000.0, "unlock": {"owned": {"estivador": 30}}},

	# --- empilhadeira ---
	{"id": "garfo_duplo", "name": "Garfo Duplo",
		"desc": "Dois pallets por viagem. O dobro de vento no rosto.",
		"kind": "structure_mult", "target": "empilhadeira", "value": 2.0,
		"cost": 4000.0, "unlock": {"owned": {"empilhadeira": 5}}},
	{"id": "buzina_musical", "name": "Buzina Musical",
		"desc": "Toca 'La Cucaracha'. Moral +40%, paciência do turno -60%.",
		"kind": "structure_mult", "target": "empilhadeira", "value": 2.0,
		"cost": 40000.0, "unlock": {"owned": {"empilhadeira": 15}}},

	# --- tt ---
	{"id": "pneus_novos", "name": "Pneus Sem Careca",
		"desc": "Aderência descoberta em 2024.",
		"kind": "structure_mult", "target": "tt", "value": 2.0,
		"cost": 44000.0, "unlock": {"owned": {"tt": 5}}},
	{"id": "radio_pesado", "name": "Rádio no Talo",
		"desc": "Motorista feliz dirige 12% mais reto.",
		"kind": "structure_mult", "target": "tt", "value": 2.0,
		"cost": 440000.0, "unlock": {"owned": {"tt": 15}}},

	# --- reach stacker ---
	{"id": "contrapeso", "name": "Contrapeso Extra",
		"desc": "Menos tombos. O seguro mandou flores.",
		"kind": "structure_mult", "target": "reach_stacker", "value": 2.0,
		"cost": 480000.0, "unlock": {"owned": {"reach_stacker": 5}}},
	{"id": "telemetria_lanca", "name": "Telemetria de Lança",
		"desc": "A lança avisa antes de fazer drama.",
		"kind": "structure_mult", "target": "reach_stacker", "value": 2.0,
		"cost": 4.8e6, "unlock": {"owned": {"reach_stacker": 15}}},

	# --- rtg ---
	{"id": "gps_rtg", "name": "GPS Milimétrico",
		"desc": "Empilha container como quem joga Tetris profissional.",
		"kind": "structure_mult", "target": "rtg", "value": 2.0,
		"cost": 5.2e6, "unlock": {"owned": {"rtg": 5}}},
	{"id": "operacao_remota_rtg", "name": "Operação Remota",
		"desc": "Controle da sala, pátio obediente.",
		"kind": "structure_mult", "target": "rtg", "value": 2.0,
		"cost": 52e6, "unlock": {"owned": {"rtg": 15}}},

	# --- sts ---
	{"id": "operador_descansado", "name": "Operador Com Sono em Dia",
		"desc": "Dormiu 8 horas. O porto inteiro comenta.",
		"kind": "structure_mult", "target": "sts", "value": 2.0,
		"cost": 56e6, "unlock": {"owned": {"sts": 5}}},
	{"id": "twin_lift", "name": "Spreader Twin-Lift",
		"desc": "Dois containers por içada. Matemática de gente grande.",
		"kind": "structure_mult", "target": "sts", "value": 2.0,
		"cost": 560e6, "unlock": {"owned": {"sts": 15}}},

	# --- armazém ---
	{"id": "wms_alfandegado", "name": "WMS Alfandegado",
		"desc": "Cada caixa sabe onde espera a fiscalização.",
		"kind": "structure_mult", "target": "armazem", "value": 2.0,
		"cost": 800e6, "unlock": {"owned": {"armazem": 5}}},
	{"id": "docas_automatizadas", "name": "Docas Automatizadas",
		"desc": "A doca trabalha até quando o café acaba.",
		"kind": "structure_mult", "target": "armazem", "value": 2.0,
		"cost": 8e9, "unlock": {"owned": {"armazem": 15}}},

	# --- rebocador ---
	{"id": "propulsao_azimutal", "name": "Propulsão Azimutal",
		"desc": "Vira no lugar e intimida navio grande.",
		"kind": "structure_mult", "target": "rebocador", "value": 2.0,
		"cost": 13.2e9, "unlock": {"owned": {"rebocador": 5}}},
	{"id": "despacho_rebocadores", "name": "Despacho de Rebocadores",
		"desc": "Todo empurrão chega na hora certa.",
		"kind": "structure_mult", "target": "rebocador", "value": 2.0,
		"cost": 132e9, "unlock": {"owned": {"rebocador": 15}}},

	# --- trem ---
	{"id": "sinalizacao_ctc", "name": "Sinalização CTC",
		"desc": "Trilho livre, fila andando.",
		"kind": "structure_mult", "target": "trem", "value": 2.0,
		"cost": 204e9, "unlock": {"owned": {"trem": 5}}},
	{"id": "composicao_dupla", "name": "Composição Dupla",
		"desc": "Dois trens, uma pressa só.",
		"kind": "structure_mult", "target": "trem", "value": 2.0,
		"cost": 2.04e12, "unlock": {"owned": {"trem": 15}}},

	# --- flutuante ---
	{"id": "estabilizacao_dinamica", "name": "Estabilização Dinâmica",
		"desc": "O mar balança; a carga não.",
		"kind": "structure_mult", "target": "flutuante", "value": 2.0,
		"cost": 3e12, "unlock": {"owned": {"flutuante": 5}}},
	{"id": "spreader_pesado", "name": "Spreader Pesado",
		"desc": "Peso bruto tratado com delicadeza.",
		"kind": "structure_mult", "target": "flutuante", "value": 2.0,
		"cost": 30e12, "unlock": {"owned": {"flutuante": 15}}},

	# --- alfândega ---
	{"id": "ocr_gate", "name": "OCR de Gate",
		"desc": "Lê placa antes do motorista piscar.",
		"kind": "structure_mult", "target": "alfandega", "value": 2.0,
		"cost": 40e12, "unlock": {"owned": {"alfandega": 5}}},
	{"id": "canal_verde", "name": "Canal Verde",
		"desc": "Carga regular passa sem novela.",
		"kind": "structure_mult", "target": "alfandega", "value": 2.0,
		"cost": 400e12, "unlock": {"owned": {"alfandega": 15}}},

	# --- torre ---
	{"id": "gemeo_digital", "name": "Gêmeo Digital",
		"desc": "O porto testa no virtual antes de virar caos.",
		"kind": "structure_mult", "target": "torre", "value": 2.0,
		"cost": 560e12, "unlock": {"owned": {"torre": 5}}},
	{"id": "janela_berco_ia", "name": "Janela de Berço IA",
		"desc": "O berço sabe quem chega antes de atracar.",
		"kind": "structure_mult", "target": "torre", "value": 2.0,
		"cost": 5.6e15, "unlock": {"owned": {"torre": 15}}},

	# --- drone ---
	{"id": "visao_termica", "name": "Visão Térmica",
		"desc": "Enxerga calor, atraso e gambiarra.",
		"kind": "structure_mult", "target": "drone", "value": 2.0,
		"cost": 6.8e15, "unlock": {"owned": {"drone": 5}}},
	{"id": "enxame_coordenado", "name": "Enxame Coordenado",
		"desc": "Um vê, todos cercam.",
		"kind": "structure_mult", "target": "drone", "value": 2.0,
		"cost": 68e15, "unlock": {"owned": {"drone": 15}}},

	# --- porto ia ---
	{"id": "despacho_preditivo", "name": "Despacho Preditivo",
		"desc": "A IA já sabia da fila de amanhã.",
		"kind": "structure_mult", "target": "porto_ia", "value": 2.0,
		"cost": 84e15, "unlock": {"owned": {"porto_ia": 5}}},
	{"id": "aprendizado_federado", "name": "Aprendizado Federado",
		"desc": "Aprende com cada terminal sem fofocar dados.",
		"kind": "structure_mult", "target": "porto_ia", "value": 2.0,
		"cost": 840e15, "unlock": {"owned": {"porto_ia": 15}}},

	# --- portal ---
	{"id": "calibracao_quantica", "name": "Calibração Quântica",
		"desc": "Ajusta o impossível em nanosegundos.",
		"kind": "structure_mult", "target": "portal", "value": 2.0,
		"cost": 1.04e18, "unlock": {"owned": {"portal": 5}}},
	{"id": "corredor_instantaneo", "name": "Corredor Instantâneo",
		"desc": "Do cais ao destino sem escala.",
		"kind": "structure_mult", "target": "portal", "value": 2.0,
		"cost": 1.04e19, "unlock": {"owned": {"portal": 15}}},

	# --- global ---
	{"id": "colete_novo", "name": "Coletes Novos",
		"desc": "Laranja mais laranja. Todo mundo trabalha 5% mais visível.",
		"kind": "global_mult", "value": 1.05, "cost": 100000.0,
		"unlock": {"teus": 50000.0}},
	{"id": "wifi_patio", "name": "Wi-Fi no Pátio",
		"desc": "Agora os relatórios chegam. Ninguém lê, mas chegam.",
		"kind": "global_mult", "value": 1.10, "cost": 10e6,
		"unlock": {"teus": 5e6}},
]

static func tier_of(structure_id: String, owned_upgrades: Dictionary) -> int:
	## How many fitted upgrades a machine of this kind is carrying. The yard reads
	## this to mark the machine — an upgrade the player paid for has to change
	## something on the machine it was bought for, not only a multiplier in a
	## panel they closed.
	if structure_id.is_empty():
		return 0
	var tier := 0
	for item in ITEMS:
		if str(item.get("target", "")) == structure_id \
				and owned_upgrades.has(str(item.get("id", ""))):
			tier += 1
	return tier


static func get_item(id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == id:
			return item
	return {}
