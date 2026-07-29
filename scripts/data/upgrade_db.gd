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

	# --- rtg ---
	{"id": "gps_rtg", "name": "GPS Milimétrico",
		"desc": "Empilha container como quem joga Tetris profissional.",
		"kind": "structure_mult", "target": "rtg", "value": 2.0,
		"cost": 5.2e6, "unlock": {"owned": {"rtg": 5}}},

	# --- sts ---
	{"id": "operador_descansado", "name": "Operador Com Sono em Dia",
		"desc": "Dormiu 8 horas. O porto inteiro comenta.",
		"kind": "structure_mult", "target": "sts", "value": 2.0,
		"cost": 56e6, "unlock": {"owned": {"sts": 5}}},
	{"id": "twin_lift", "name": "Spreader Twin-Lift",
		"desc": "Dois containers por içada. Matemática de gente grande.",
		"kind": "structure_mult", "target": "sts", "value": 2.0,
		"cost": 560e6, "unlock": {"owned": {"sts": 15}}},

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

static func get_item(id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == id:
			return item
	return {}
