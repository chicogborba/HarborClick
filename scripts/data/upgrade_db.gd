class_name UpgradeDB
## Static data for upgrades, as a graph rather than a shelf.
##
## The shelf version was eighteen cards that all said `×2`. There was always one
## right answer — the cheapest payback — and the card computed it for you, so the
## "decision" was arithmetic the interface had already done. This file is the
## same catalogue rebuilt as something a player climbs: every node names what
## opens it, and the deeper ones pay for depth in a machine the port already runs.
##
## - `requires` — other upgrade ids that must be owned first. This is the edge
##   that makes the tree a tree. `unlock` still gates on the port's size, but a
##   node with an unmet `requires` is visibly blocked by a *purchase*, which is
##   a thing the player can go and do.
## - `kind: "synergy"` — a machine gains for every unit of a *different* machine
##   the port runs, so a balanced port earns more than a lopsided one.
##
## There are no exclusive picks. The tree used to have pairs where buying one
## half refitted the other out, and "conductor" nodes that gutted a machine to
## pay the port a share; players read both as traps, so every node can now be
## owned beside every other. The nodes that were cut are in `RETIRED`, and a
## save that owned one is refunded on load.
##
## `kind` values in full: "click_mult" (multiplies click), "structure_mult"
## (multiplies one or more structures' cps), "global_mult" (multiplies all cps),
## "click_cps_pct" (click also gains % of cps), "synergy", "rail_stat" (moves a
## real knob on the branch line).
##
## `unlock`: {teus: X} lifetime TEUs or {owned: {id: n}} structure count needed.

## Nodes taken out of the tree, with their authored price. A save that owned
## one gets that price back (paced, like every price) when it loads.
const RETIRED := {
	"turma_de_terra": 20e6, "bloco_mestre": 400e6, "cais_dedicado": 50e6,
	"terminal_interior": 120e12, "centro_de_controle": 2e15,
	"trem_pesado": 30e12, "trem_shuttle": 30e12,
}

## Trunks of the tree, in the order they are drawn. `machines` is what the trunk
## is *about* — used to pick the art when a node has no single target of its own.
## A `static var`, not a `const`: `CatalogText` writes the player's language
## into these rows in place (see scripts/i18n/catalog_text.gd).
static var BRANCHES: Array[Dictionary] = [
	{"id": "mao", "title": "Mão de Obra", "art": "estivador"},
	{"id": "patio", "title": "Pátio", "art": "rtg"},
	{"id": "cais", "title": "Cais", "art": "sts"},
	{"id": "ramal", "title": "Ramal Ferroviário", "art": "trem"},
	{"id": "portao", "title": "Portão", "art": "alfandega"},
	{"id": "comando", "title": "Comando", "art": "torre"},
]

## The authored prices. Everything reads `ITEMS`, which is this table run
## through `EconomyMath.paced`.
const RAW_ITEMS: Array[Dictionary] = [
	# ---------------------------------------------------------------- mão de obra
	{"id": "luvas", "name": "Luvas Reforçadas", "short": "Luvas",
		"desc": "Menos farpa, mais caixa.",
		"branch": "mao", "kind": "click_mult", "value": 2.0, "cost": 100.0,
		"unlock": {"teus": 50.0}},
	{"id": "gancho", "name": "Gancho de Estivador", "short": "Gancho",
		"desc": "O clássico. Nunca sai de moda, às vezes sai da mão.",
		"branch": "mao", "kind": "click_mult", "value": 2.0, "cost": 1000.0,
		"requires": ["luvas"], "unlock": {"teus": 500.0}},
	{"id": "exoesqueleto", "name": "Exoesqueleto Hidráulico", "short": "Exoesqueleto",
		"desc": "Agora o RH exige alongamento antes de vestir.",
		"branch": "mao", "kind": "click_mult", "value": 3.0, "cost": 50000.0,
		"requires": ["gancho"], "unlock": {"teus": 20000.0}},
	{"id": "clique_sindical", "name": "Clique Sindicalizado", "short": "Sindicalizado",
		"desc": "Cada clique conta. Literalmente, pro sindicato.",
		"branch": "mao", "kind": "click_cps_pct", "value": 0.01, "cost": 5e6,
		"requires": ["exoesqueleto"], "unlock": {"teus": 1e6}},

	{"id": "cafe_forte", "name": "Café de Rancho", "short": "Café",
		"desc": "Coado na meia. Eficiência dobra, paladar chora.",
		"branch": "mao", "kind": "structure_mult", "target": "estivador",
		"value": 2.0, "cost": 500.0, "unlock": {"owned": {"estivador": 5}}},
	{"id": "carrinho_mao", "name": "Carrinho de Mão Turbo", "short": "Carrinho",
		"desc": "Rodinha nova. NOVA. Entende a revolução?",
		"branch": "mao", "kind": "structure_mult", "target": "estivador",
		"value": 2.0, "cost": 5000.0, "requires": ["cafe_forte"],
		"unlock": {"owned": {"estivador": 15}}},
	{"id": "sindicato", "name": "Sindicato Organizado", "short": "Sindicato",
		"desc": "Pausa pro café virou instituição. Produtividade subiu. Ninguém explica.",
		"branch": "mao", "kind": "structure_mult", "target": "estivador",
		"value": 2.0, "cost": 50000.0, "requires": ["carrinho_mao"],
		"unlock": {"owned": {"estivador": 30}}},

	# -------------------------------------------------------------------- pátio
	{"id": "garfo_duplo", "name": "Garfo Duplo", "short": "Garfo",
		"desc": "Dois pallets por viagem. O dobro de vento no rosto.",
		"branch": "patio", "kind": "structure_mult", "target": "empilhadeira",
		"value": 2.0, "cost": 4000.0, "unlock": {"owned": {"empilhadeira": 5}}},
	{"id": "buzina_musical", "name": "Buzina Musical", "short": "Buzina",
		"desc": "Toca 'La Cucaracha' a cada ré. O turno inteiro já sabe a letra.",
		"branch": "patio", "kind": "structure_mult", "target": "empilhadeira",
		"value": 2.0, "cost": 40000.0, "requires": ["garfo_duplo"],
		"unlock": {"owned": {"empilhadeira": 15}}},
	{"id": "contrapeso", "name": "Contrapeso Extra", "short": "Contrapeso",
		"desc": "Menos tombos. O seguro mandou flores.",
		"branch": "patio", "kind": "structure_mult", "target": "reach_stacker",
		"value": 2.0, "cost": 480000.0, "requires": ["buzina_musical"],
		"unlock": {"owned": {"reach_stacker": 5}}},
	{"id": "telemetria_lanca", "name": "Telemetria de Lança", "short": "Telemetria",
		"desc": "A lança avisa antes de fazer drama.",
		"branch": "patio", "kind": "structure_mult", "target": "reach_stacker",
		"value": 2.0, "cost": 4.8e6, "requires": ["contrapeso"],
		"unlock": {"owned": {"reach_stacker": 15}}},
	{"id": "gps_rtg", "name": "GPS Milimétrico", "short": "GPS",
		"desc": "Empilha container como quem joga Tetris profissional.",
		"branch": "patio", "kind": "structure_mult", "target": "rtg",
		"value": 2.0, "cost": 5.2e6, "requires": ["telemetria_lanca"],
		"unlock": {"owned": {"rtg": 5}}},
	{"id": "operacao_remota_rtg", "name": "Operação Remota", "short": "Op. Remota",
		"desc": "Controle da sala, pátio obediente.",
		"branch": "patio", "kind": "structure_mult", "target": "rtg",
		"value": 2.0, "cost": 52e6, "requires": ["gps_rtg"],
		"unlock": {"owned": {"rtg": 15}}},
	# The block is only as good as what feeds it. A port that bought fifteen RTGs
	# and two tractors now has a reason to go and buy tractors.
	{"id": "bloco_alimentado", "name": "Bloco Alimentado", "short": "Alimentado",
		"desc": "Cada cavalo mecânico na praça mantém o transtêiner sem espera: +3% no RTG por cavalo, até +180%.",
		"branch": "patio", "kind": "synergy", "target": "rtg", "per": "tt",
		"value": 0.03, "cap": 1.8, "cost": 90e6, "requires": ["gps_rtg"],
		"unlock": {"owned": {"rtg": 5, "tt": 10}}},
	# Two late yard refits, one for the block and one for the machines that move
	# boxes sideways. They used to exclude each other; now a port can own both.
	{"id": "estoque_profundo", "name": "Estoque Profundo", "short": "Estoque",
		"desc": "Cinco alturas no bloco e ninguém remexe. O transtêiner rende 4×; o resto do pátio segue igual.",
		"branch": "patio", "kind": "structure_mult", "target": "rtg", "value": 4.0,
		"cost": 300e6, "requires": ["operacao_remota_rtg"],
		"unlock": {"owned": {"rtg": 15}}},
	{"id": "giro_rapido", "name": "Giro Rápido", "short": "Giro",
		"desc": "Pilha baixa, remoção rara, tudo andando. Empilhadeira e reach stacker rendem 2,2×; o bloco não muda.",
		"branch": "patio", "kind": "structure_mult",
		"targets": ["empilhadeira", "reach_stacker"], "value": 2.2,
		"cost": 300e6, "requires": ["operacao_remota_rtg"],
		"unlock": {"owned": {"rtg": 15}}},

	# --------------------------------------------------------------------- cais
	{"id": "operador_descansado", "name": "Operador Com Sono em Dia", "short": "Operador",
		"desc": "Dormiu 8 horas. O porto inteiro comenta.",
		"branch": "cais", "kind": "structure_mult", "target": "sts", "value": 2.0,
		"cost": 56e6, "unlock": {"owned": {"sts": 5}}},
	{"id": "twin_lift", "name": "Spreader Twin-Lift", "short": "Twin-Lift",
		"desc": "Dois containers por içada. Matemática de gente grande.",
		"branch": "cais", "kind": "structure_mult", "target": "sts", "value": 2.0,
		"cost": 560e6, "requires": ["operador_descansado"],
		"unlock": {"owned": {"sts": 15}}},
	{"id": "propulsao_azimutal", "name": "Propulsão Azimutal", "short": "Azimutal",
		"desc": "Vira no lugar e intimida navio grande.",
		"branch": "cais", "kind": "structure_mult", "target": "rebocador",
		"value": 2.0, "cost": 13.2e9, "requires": ["twin_lift"],
		"unlock": {"owned": {"rebocador": 5}}},
	{"id": "despacho_rebocadores", "name": "Despacho de Rebocadores", "short": "Despacho",
		"desc": "Todo empurrão chega na hora certa.",
		"branch": "cais", "kind": "structure_mult", "target": "rebocador",
		"value": 2.0, "cost": 132e9, "requires": ["propulsao_azimutal"],
		"unlock": {"owned": {"rebocador": 15}}},
	# The tug parks the ship square and the crane never waits on a warp. Bought by
	# a port with no tugs, this node is worth exactly nothing — which is the point.
	{"id": "atracacao_limpa", "name": "Atracação Limpa", "short": "Atracação",
		"desc": "Navio encostado no lugar certo é portêiner sem espera: +4% no STS por rebocador, até +200%.",
		"branch": "cais", "kind": "synergy", "target": "sts", "per": "rebocador",
		"value": 0.04, "cap": 2.0, "cost": 20e9, "requires": ["propulsao_azimutal"],
		"unlock": {"owned": {"sts": 10, "rebocador": 3}}},
	{"id": "estabilizacao_dinamica", "name": "Estabilização Dinâmica", "short": "Dinâmica",
		"desc": "O mar balança; a carga não.",
		"branch": "cais", "kind": "structure_mult", "target": "flutuante",
		"value": 2.0, "cost": 3e12, "requires": ["despacho_rebocadores"],
		"unlock": {"owned": {"flutuante": 5}}},
	{"id": "spreader_pesado", "name": "Spreader Pesado", "short": "Spreader",
		"desc": "Peso bruto tratado com delicadeza.",
		"branch": "cais", "kind": "structure_mult", "target": "flutuante",
		"value": 2.0, "cost": 30e12, "requires": ["estabilizacao_dinamica"],
		"unlock": {"owned": {"flutuante": 15}}},
	# Dois reforços tardios do cais: um para o portêiner, outro para o apoio.
	{"id": "escala_profunda", "name": "Escala Profunda", "short": "Escala",
		"desc": "Um berço, um navio gigante, uma escala longa. O portêiner rende 2,6×; o apoio segue igual.",
		"branch": "cais", "kind": "structure_mult", "target": "sts", "value": 2.6,
		"cost": 60e12, "requires": ["spreader_pesado"],
		"unlock": {"owned": {"sts": 20}}},
	{"id": "cadencia_de_cais", "name": "Cadência de Cais", "short": "Cadência",
		"desc": "Navio médio entrando e saindo o dia todo. Rebocador e flutuante rendem 2,4×; o portêiner segue igual.",
		"branch": "cais", "kind": "structure_mult",
		"targets": ["rebocador", "flutuante"], "value": 2.4,
		"cost": 60e12, "requires": ["spreader_pesado"],
		"unlock": {"owned": {"sts": 20}}},

	# -------------------------------------------------------------------- ramal
	# The branch line is a whole subsystem — rake length, service interval, ramp
	# dwell, gantry rate, completion bonus — and until now the only thing the shop
	# sold for it was two anonymous `×2`s. These nodes move the actual knobs in
	# `RailCargoPolicy` and `RailYard`, so buying one changes a train the player
	# can walk down and look at.
	{"id": "sinalizacao_ctc", "name": "Sinalização CTC", "short": "CTC",
		"desc": "Trilho livre, fila andando. Os serviços chegam ~30% mais juntos.",
		"branch": "ramal", "kind": "rail_stat",
		"stats": [{"stat": "service_gap", "operation": "mult", "value": 0.72}],
		"cost": 204e9, "unlock": {"owned": {"trem": 1}}},
	# Two wagons, not four: `RailCargoPolicy.MAX_RAKE` is eight, and eight is what
	# the run-around loop can hold. A card promising a length the ground refuses
	# would be a card that lies the moment it is bought.
	{"id": "composicao_dupla", "name": "Composição Dupla", "short": "Dupla",
		"desc": "Dois trens, uma pressa só. Mais dois vagões em cada serviço - o comprimento máximo que o desvio de manobra comporta.",
		"branch": "ramal", "kind": "rail_stat",
		"stats": [{"stat": "rake_length", "operation": "add_flat", "value": 2.0}],
		"cost": 2.04e12, "requires": ["sinalizacao_ctc"],
		"unlock": {"owned": {"trem": 5}}},
	{"id": "patio_manobras", "name": "Pátio de Manobras", "short": "Manobras",
		"desc": "Desvio próprio para a manobra da locomotiva. A composição fica 70 s a mais na rampa antes de ir embora.",
		"branch": "ramal", "kind": "rail_stat",
		"stats": [{"stat": "dwell", "operation": "add_flat", "value": 70.0}],
		"cost": 900e9, "requires": ["sinalizacao_ctc"],
		"unlock": {"owned": {"trem": 3}}},
	{"id": "portico_ferroviario", "name": "Pórtico Ferroviário", "short": "Pórtico",
		"desc": "Um RMG só para os vagões. O ramal trabalha sozinho bem mais rápido, e o teto do automático sobe junto.",
		"branch": "ramal", "kind": "rail_stat",
		"stats": [{"stat": "auto_rate", "operation": "add_flat", "value": 0.45},
			{"stat": "auto_cap", "operation": "add_flat", "value": 0.8}],
		"cost": 6e12, "requires": ["composicao_dupla"],
		"unlock": {"owned": {"trem": 8}}},
	{"id": "ramal_alimentado", "name": "Ramal Alimentado", "short": "Abastecido",
		"desc": "Armazém cheio é vagão que nunca sai vazio: +6% no ramal por armazém, até +240%.",
		"branch": "ramal", "kind": "synergy", "target": "trem", "per": "armazem",
		"value": 0.06, "cap": 2.4, "cost": 8e12, "requires": ["composicao_dupla"],
		"unlock": {"owned": {"trem": 5, "armazem": 10}}},

	# ------------------------------------------------------------------- portão
	{"id": "pneus_novos", "name": "Pneus Sem Careca", "short": "Pneus",
		"desc": "Aderência descoberta em 2024.",
		"branch": "portao", "kind": "structure_mult", "target": "tt", "value": 2.0,
		"cost": 44000.0, "unlock": {"owned": {"tt": 5}}},
	{"id": "radio_pesado", "name": "Rádio no Talo", "short": "Rádio",
		"desc": "Motorista feliz dirige mais reto. Ninguém mediu, mas todos juram.",
		"branch": "portao", "kind": "structure_mult", "target": "tt", "value": 2.0,
		"cost": 440000.0, "requires": ["pneus_novos"],
		"unlock": {"owned": {"tt": 15}}},
	{"id": "wms_alfandegado", "name": "WMS Alfandegado", "short": "WMS",
		"desc": "Cada caixa sabe onde espera a fiscalização.",
		"branch": "portao", "kind": "structure_mult", "target": "armazem",
		"value": 2.0, "cost": 800e6, "requires": ["radio_pesado"],
		"unlock": {"owned": {"armazem": 5}}},
	{"id": "docas_automatizadas", "name": "Docas Automatizadas", "short": "Docas",
		"desc": "A doca trabalha até quando o café acaba.",
		"branch": "portao", "kind": "structure_mult", "target": "armazem",
		"value": 2.0, "cost": 8e9, "requires": ["wms_alfandegado"],
		"unlock": {"owned": {"armazem": 15}}},
	{"id": "ocr_gate", "name": "OCR de Gate", "short": "OCR",
		"desc": "Lê placa antes do motorista piscar.",
		"branch": "portao", "kind": "structure_mult", "target": "alfandega",
		"value": 2.0, "cost": 40e12, "requires": ["docas_automatizadas"],
		"unlock": {"owned": {"alfandega": 5}}},
	{"id": "canal_verde", "name": "Canal Verde", "short": "Canal Verde",
		"desc": "Carga regular passa sem novela.",
		"branch": "portao", "kind": "structure_mult", "target": "alfandega",
		"value": 2.0, "cost": 400e12, "requires": ["ocr_gate"],
		"unlock": {"owned": {"alfandega": 15}}},
	{"id": "fila_unica", "name": "Fila Única", "short": "Fila Única",
		"desc": "Cada cavalo mecânico na praça é uma cancela a menos travada: +5% no portão por cavalo, até +200%.",
		"branch": "portao", "kind": "synergy", "target": "alfandega", "per": "tt",
		"value": 0.05, "cap": 2.0, "cost": 120e12, "requires": ["ocr_gate"],
		"unlock": {"owned": {"alfandega": 5, "tt": 20}}},

	# ------------------------------------------------------------------ comando
	{"id": "colete_novo", "name": "Coletes Novos", "short": "Coletes",
		"desc": "Laranja mais laranja. Todo mundo trabalha 5% mais visível.",
		"branch": "comando", "kind": "global_mult", "value": 1.05, "cost": 100000.0,
		"unlock": {"teus": 50000.0}},
	{"id": "wifi_patio", "name": "Wi-Fi no Pátio", "short": "Wi-Fi",
		"desc": "Agora os relatórios chegam. Ninguém lê, mas chegam.",
		"branch": "comando", "kind": "global_mult", "value": 1.10, "cost": 10e6,
		"requires": ["colete_novo"], "unlock": {"teus": 5e6}},
	{"id": "gemeo_digital", "name": "Gêmeo Digital", "short": "Gêmeo",
		"desc": "O porto testa no virtual antes de virar caos.",
		"branch": "comando", "kind": "structure_mult", "target": "torre",
		"value": 2.0, "cost": 560e12, "requires": ["wifi_patio"],
		"unlock": {"owned": {"torre": 5}}},
	{"id": "janela_berco_ia", "name": "Janela de Berço IA", "short": "Janela IA",
		"desc": "O berço sabe quem chega antes de atracar.",
		"branch": "comando", "kind": "structure_mult", "target": "torre",
		"value": 2.0, "cost": 5.6e15, "requires": ["gemeo_digital"],
		"unlock": {"owned": {"torre": 15}}},
	{"id": "visao_termica", "name": "Visão Térmica", "short": "Térmica",
		"desc": "Enxerga calor, atraso e gambiarra.",
		"branch": "comando", "kind": "structure_mult", "target": "drone",
		"value": 2.0, "cost": 6.8e15, "requires": ["janela_berco_ia"],
		"unlock": {"owned": {"drone": 5}}},
	{"id": "enxame_coordenado", "name": "Enxame Coordenado", "short": "Enxame",
		"desc": "Um vê, todos cercam.",
		"branch": "comando", "kind": "structure_mult", "target": "drone",
		"value": 2.0, "cost": 68e15, "requires": ["visao_termica"],
		"unlock": {"owned": {"drone": 15}}},
	{"id": "despacho_preditivo", "name": "Despacho Preditivo", "short": "Preditivo",
		"desc": "A IA já sabia da fila de amanhã.",
		"branch": "comando", "kind": "structure_mult", "target": "porto_ia",
		"value": 2.0, "cost": 84e15, "requires": ["enxame_coordenado"],
		"unlock": {"owned": {"porto_ia": 5}}},
	{"id": "aprendizado_federado", "name": "Aprendizado Federado", "short": "Federado",
		"desc": "Aprende com cada terminal sem fofocar dados.",
		"branch": "comando", "kind": "structure_mult", "target": "porto_ia",
		"value": 2.0, "cost": 840e15, "requires": ["despacho_preditivo"],
		"unlock": {"owned": {"porto_ia": 15}}},
	{"id": "calibracao_quantica", "name": "Calibração Quântica", "short": "Quântica",
		"desc": "Ajusta o impossível em nanosegundos.",
		"branch": "comando", "kind": "structure_mult", "target": "portal",
		"value": 2.0, "cost": 1.04e18, "requires": ["aprendizado_federado"],
		"unlock": {"owned": {"portal": 5}}},
	{"id": "corredor_instantaneo", "name": "Corredor Instantâneo", "short": "Corredor",
		"desc": "Do cais ao destino sem escala.",
		"branch": "comando", "kind": "structure_mult", "target": "portal",
		"value": 2.0, "cost": 1.04e19, "requires": ["calibracao_quantica"],
		"unlock": {"owned": {"portal": 15}}},

	# -------- mão de obra: mais toque e o fundo da turma
	{"id": "botina_aco", "name": "Botina com Biqueira",
		"desc": "Pisa no pé e nem sente. O clique sai com convicção.",
		"branch": "mao", "kind": "click_mult", "value": 2.0, "cost": 12000.0, "requires": ["gancho"],
		"unlock": {"teus": 6000.0}},
	{"id": "luva_titanio", "name": "Luva de Titânio",
		"desc": "Pesa uma tonelada. Cada toque também.",
		"branch": "mao", "kind": "click_mult", "value": 3.0, "cost": 5e7, "requires": ["exoesqueleto"],
		"unlock": {"teus": 2e7}},
	{"id": "apito_contramestre", "name": "Apito do Contramestre",
		"desc": "Um apito e o pátio inteiro acelera junto com o seu dedo.",
		"branch": "mao", "kind": "click_cps_pct", "value": 0.02, "cost": 5e8, "requires": ["clique_sindical"],
		"unlock": {"teus": 1e8}},
	{"id": "toque_de_ouro", "name": "Toque de Ouro",
		"desc": "Lenda do cais: onde ele encosta, sai contêiner.",
		"branch": "mao", "kind": "click_cps_pct", "value": 0.03, "cost": 5e11, "requires": ["apito_contramestre"],
		"unlock": {"teus": 1e11}},
	{"id": "plano_saude", "name": "Plano de Saúde",
		"desc": "Coluna em dia, turno em dobro.",
		"branch": "mao", "kind": "structure_mult", "target": "estivador", "value": 2.0, "cost": 810000.0, "requires": ["sindicato"],
		"unlock": {"owned": {"estivador": 50}}},
	{"id": "vestiario_ar", "name": "Vestiário com Ar",
		"desc": "Ninguém mais some na hora do almoço. Só às vezes.",
		"branch": "mao", "kind": "structure_mult", "target": "estivador", "value": 2.0, "cost": 8.8e8, "requires": ["plano_saude"],
		"unlock": {"owned": {"estivador": 100}}},
	{"id": "dupla_dinamica", "name": "Dupla Dinâmica",
		"desc": "Estivador e empilhadeira se entendem no olhar: +2% no estivador por empilhadeira, até +150%.",
		"branch": "mao", "kind": "synergy", "target": "estivador", "per": "empilhadeira", "value": 0.02, "cap": 1.5, "cost": 200000.0, "requires": ["carrinho_mao"],
		"unlock": {"owned": {"estivador": 25, "empilhadeira": 10}}},

	# -------- pátio: os níveis 30, 50 e 100
	{"id": "bateria_litio", "name": "Bateria de Lítio",
		"desc": "Carrega no almoço, trabalha o turno inteiro.",
		"branch": "patio", "kind": "structure_mult", "target": "empilhadeira", "value": 2.0, "cost": 330000.0, "requires": ["buzina_musical"],
		"unlock": {"owned": {"empilhadeira": 30}}},
	{"id": "garfo_inteligente", "name": "Garfo Inteligente",
		"desc": "Sente o peso antes de levantar. Quase um sommelier.",
		"branch": "patio", "kind": "structure_mult", "target": "empilhadeira", "value": 2.0, "cost": 5.4e6, "requires": ["bateria_litio"],
		"unlock": {"owned": {"empilhadeira": 50}}},
	{"id": "frota_eletrica", "name": "Frota Elétrica",
		"desc": "Silêncio no pátio. Dá até pra ouvir a gaivota.",
		"branch": "patio", "kind": "structure_mult", "target": "empilhadeira", "value": 2.0, "cost": 5.9e9, "requires": ["garfo_inteligente"],
		"unlock": {"owned": {"empilhadeira": 100}}},
	{"id": "lanca_reforcada", "name": "Lança Reforçada",
		"desc": "Aguenta duas alturas a mais sem reclamar.",
		"branch": "patio", "kind": "structure_mult", "target": "reach_stacker", "value": 2.0, "cost": 4e7, "requires": ["telemetria_lanca"],
		"unlock": {"owned": {"reach_stacker": 30}}},
	{"id": "cabine_giratoria", "name": "Cabine Giratória",
		"desc": "O operador vê tudo sem torcer o pescoço.",
		"branch": "patio", "kind": "structure_mult", "target": "reach_stacker", "value": 2.0, "cost": 6.5e8, "requires": ["lanca_reforcada"],
		"unlock": {"owned": {"reach_stacker": 50}}},
	{"id": "rtg_hibrido", "name": "RTG Híbrido",
		"desc": "Metade diesel, metade bateria, inteiro produtivo.",
		"branch": "patio", "kind": "structure_mult", "target": "rtg", "value": 2.0, "cost": 4.3e8, "requires": ["operacao_remota_rtg"],
		"unlock": {"owned": {"rtg": 30}}},
	{"id": "bloco_automatico", "name": "Bloco Automático",
		"desc": "O bloco se organiza sozinho durante a madrugada.",
		"branch": "patio", "kind": "structure_mult", "target": "rtg", "value": 2.0, "cost": 7e9, "requires": ["rtg_hibrido"],
		"unlock": {"owned": {"rtg": 50}}},

	# -------- cais
	{"id": "cabine_panoramica", "name": "Cabine Panorâmica",
		"desc": "Vidro do chão ao teto. O operador nunca mais erra a célula.",
		"branch": "cais", "kind": "structure_mult", "target": "sts", "value": 2.0, "cost": 4.6e9, "requires": ["twin_lift"],
		"unlock": {"owned": {"sts": 30}}},
	{"id": "sts_tandem", "name": "Portêiner Tandem",
		"desc": "Quatro contêineres por içada. O navio nem percebe.",
		"branch": "cais", "kind": "structure_mult", "target": "sts", "value": 2.0, "cost": 7.6e10, "requires": ["cabine_panoramica"],
		"unlock": {"owned": {"sts": 50}}},
	{"id": "patio_sincronizado", "name": "Pátio Sincronizado",
		"desc": "O transtêiner já espera a caixa no pé do portêiner: +2% no STS por RTG, até +150%.",
		"branch": "cais", "kind": "synergy", "target": "sts", "per": "rtg", "value": 0.02, "cap": 1.5, "cost": 1e10, "requires": ["twin_lift"],
		"unlock": {"owned": {"sts": 10, "rtg": 20}}},
	{"id": "rebocador_eletrico", "name": "Rebocador Elétrico",
		"desc": "Empurra igual, faz menos fumaça e mais pose.",
		"branch": "cais", "kind": "structure_mult", "target": "rebocador", "value": 2.0, "cost": 1.1e12, "requires": ["despacho_rebocadores"],
		"unlock": {"owned": {"rebocador": 30}}},
	{"id": "lastro_ativo", "name": "Lastro Ativo",
		"desc": "O flutuante se equilibra antes da onda chegar.",
		"branch": "cais", "kind": "structure_mult", "target": "flutuante", "value": 2.0, "cost": 2.5e14, "requires": ["spreader_pesado"],
		"unlock": {"owned": {"flutuante": 30}}},

	# -------- ramal
	{"id": "locomotiva_nova", "name": "Locomotiva Nova",
		"desc": "Tração de sobra. O apito é o mesmo de 1970.",
		"branch": "ramal", "kind": "structure_mult", "target": "trem", "value": 2.0, "cost": 2e11, "requires": ["sinalizacao_ctc"],
		"unlock": {"owned": {"trem": 5}}},
	{"id": "trilho_soldado", "name": "Trilho Soldado",
		"desc": "Sem emenda, sem tranco, sem carga caindo.",
		"branch": "ramal", "kind": "structure_mult", "target": "trem", "value": 2.0, "cost": 3e12, "requires": ["locomotiva_nova"],
		"unlock": {"owned": {"trem": 15}}},
	{"id": "vagao_plataforma", "name": "Vagão Plataforma",
		"desc": "Dois contêineres empilhados por vagão. O túnel que se cuide.",
		"branch": "ramal", "kind": "structure_mult", "target": "trem", "value": 2.0, "cost": 9e13, "requires": ["trilho_soldado"],
		"unlock": {"owned": {"trem": 30}}},

	# -------- portão
	{"id": "rota_otimizada", "name": "Rota Otimizada",
		"desc": "O GPS finalmente conhece o pátio.",
		"branch": "portao", "kind": "structure_mult", "target": "tt", "value": 2.0, "cost": 3.6e6, "requires": ["radio_pesado"],
		"unlock": {"owned": {"tt": 30}}},
	{"id": "comboio_patio", "name": "Comboio de Pátio",
		"desc": "Três carretas em fila, um motorista só no comando.",
		"branch": "portao", "kind": "structure_mult", "target": "tt", "value": 2.0, "cost": 5.9e7, "requires": ["rota_otimizada"],
		"unlock": {"owned": {"tt": 50}}},
	{"id": "cavalo_autonomo", "name": "Cavalo Autônomo",
		"desc": "Dirige sozinho e nunca para no posto.",
		"branch": "portao", "kind": "structure_mult", "target": "tt", "value": 2.0, "cost": 6.5e10, "requires": ["comboio_patio"],
		"unlock": {"owned": {"tt": 100}}},
	{"id": "cross_docking", "name": "Cross-Docking",
		"desc": "A carreta encosta, descarrega e sai cheia: +2% no armazém por cavalo, até +150%.",
		"branch": "portao", "kind": "synergy", "target": "armazem", "per": "tt", "value": 0.02, "cap": 1.5, "cost": 2e9, "requires": ["wms_alfandegado"],
		"unlock": {"owned": {"armazem": 5, "tt": 30}}},
	{"id": "porta_paletes", "name": "Porta-Paletes Duplo",
		"desc": "Corredor estreito, estante alta, estoque feliz.",
		"branch": "portao", "kind": "structure_mult", "target": "armazem", "value": 2.0, "cost": 6.6e10, "requires": ["docas_automatizadas"],
		"unlock": {"owned": {"armazem": 30}}},
	{"id": "armazem_frio", "name": "Câmara Fria",
		"desc": "Carga refrigerada paga o dobro. O estoquista usa casaco.",
		"branch": "portao", "kind": "structure_mult", "target": "armazem", "value": 2.0, "cost": 1.1e12, "requires": ["porta_paletes"],
		"unlock": {"owned": {"armazem": 50}}},
	{"id": "scanner_portal", "name": "Scanner de Portal",
		"desc": "O caminhão passa e a Receita já viu tudo.",
		"branch": "portao", "kind": "structure_mult", "target": "alfandega", "value": 2.0, "cost": 3.3e15, "requires": ["canal_verde"],
		"unlock": {"owned": {"alfandega": 30}}},

	# -------- comando: o porto inteiro
	{"id": "iso_9001", "name": "Certificação ISO",
		"desc": "Tudo documentado. Até o café tem procedimento.",
		"branch": "comando", "kind": "global_mult", "value": 1.1, "cost": 1e9, "requires": ["wifi_patio"],
		"unlock": {"teus": 5e8}},
	{"id": "selo_verde", "name": "Selo Porto Verde",
		"desc": "Painel solar no telhado e gaivota na foto oficial.",
		"branch": "comando", "kind": "global_mult", "value": 1.15, "cost": 1e12, "requires": ["iso_9001"],
		"unlock": {"teus": 5e11}},
	{"id": "porto_do_ano", "name": "Prêmio Porto do Ano",
		"desc": "Troféu na recepção. Todo mundo trabalha olhando pra ele.",
		"branch": "comando", "kind": "global_mult", "value": 1.2, "cost": 1e15, "requires": ["selo_verde"],
		"unlock": {"teus": 5e14}},
	{"id": "hub_global", "name": "Hub Global",
		"desc": "As rotas do mundo passam por aqui. O mundo agradece.",
		"branch": "comando", "kind": "global_mult", "value": 1.25, "cost": 1e18, "requires": ["porto_do_ano"],
		"unlock": {"teus": 5e17}},
	{"id": "radar_banda_x", "name": "Radar Banda X",
		"desc": "Vê navio atrás da neblina e da burocracia.",
		"branch": "comando", "kind": "structure_mult", "target": "torre", "value": 2.0, "cost": 1e17, "requires": ["janela_berco_ia"],
		"unlock": {"owned": {"torre": 30}}},
	{"id": "malha_de_controle", "name": "Malha de Controle",
		"desc": "Cada torre guia um enxame inteiro: +3% no drone por torre, até +180%.",
		"branch": "comando", "kind": "synergy", "target": "drone", "per": "torre", "value": 0.03, "cap": 1.8, "cost": 1e17, "requires": ["visao_termica"],
		"unlock": {"owned": {"drone": 5, "torre": 10}}},
	{"id": "bateria_solar", "name": "Bateria Solar",
		"desc": "O drone pousa no sol e volta voando.",
		"branch": "comando", "kind": "structure_mult", "target": "drone", "value": 2.0, "cost": 7.3e17, "requires": ["enxame_coordenado"],
		"unlock": {"owned": {"drone": 30}}},
	{"id": "rede_neural", "name": "Rede Neural Portuária",
		"desc": "A IA sonha com contêiner. E acerta.",
		"branch": "comando", "kind": "structure_mult", "target": "porto_ia", "value": 2.0, "cost": 1.2e19, "requires": ["aprendizado_federado"],
		"unlock": {"owned": {"porto_ia": 30}}},
	{"id": "dobra_logistica", "name": "Dobra Logística",
		"desc": "A carga chega antes de sair. O financeiro surtou.",
		"branch": "comando", "kind": "structure_mult", "target": "portal", "value": 2.0, "cost": 3e20, "requires": ["corredor_instantaneo"],
		"unlock": {"owned": {"portal": 30}}},
]
static var ITEMS: Array[Dictionary] = EconomyMath.paced(RAW_ITEMS)


static func apply_port() -> void:
	## The shared tree plus the active port's local trunk (`PortDB.upgrades`,
	## `branch: "porto"`). At home that trunk is empty and this is exactly the
	## table every balance run was tuned against.
	var raw: Array[Dictionary] = []
	raw.append_array(RAW_ITEMS)
	raw.append_array(PortDB.upgrades())
	ITEMS = EconomyMath.paced(raw)


static func branches() -> Array[Dictionary]:
	## The trunks to draw: the six every port has, and the local one when the
	## active port brings nodes for it.
	var out: Array[Dictionary] = []
	out.append_array(BRANCHES)
	if not PortDB.upgrades().is_empty():
		out.append(PortDB.BRANCH)
	return out


static func get_item(id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == id:
			return item
	return {}


static func tier_of(structure_id: String, owned_upgrades: Dictionary) -> int:
	## How many fitted upgrades a machine of this kind is carrying. The yard reads
	## this to mark the machine — an upgrade the player paid for has to change
	## something on the machine it was bought for, not only a multiplier in a
	## panel they closed.
	if structure_id.is_empty():
		return 0
	var tier := 0
	for item in ITEMS:
		if owned_upgrades.has(str(item.get("id", ""))) \
				and targets_of(item).has(structure_id):
			tier += 1
	return tier


static func short_of(item: Dictionary) -> String:
	## The name as it is printed on the map.
	##
	## A transit map has short station names because a long one either overlaps its
	## neighbour or gets cut mid-word, and "Exoesquele." is not a name, it is a
	## failure. These are authored rather than derived: truncating "Bloco
	## Alimentado" and "Bloco Mestre" produces the same string, and two stations
	## with one label is worse than a long one.
	var short := str(item.get("short", ""))
	if not short.is_empty():
		return short
	var name := str(item.get("name", ""))
	return name.split(" ")[0] if name.contains(" ") else name


static func targets_of(item: Dictionary) -> Array[String]:
	## Which machines a node is fitted to. Most nodes name one; a few name two,
	## and a node with no machine at all — a click or global multiplier — names
	## none.
	var out: Array[String] = []
	var single := str(item.get("target", ""))
	if not single.is_empty():
		out.append(single)
	for entry in item.get("targets", []):
		var id := str(entry)
		if not id.is_empty() and not out.has(id):
			out.append(id)
	return out


static func requires_of(item: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for entry in item.get("requires", []):
		out.append(str(entry))
	return out


static func stats_of(item: Dictionary) -> Array:
	## Rail knobs a node moves.
	var raw: Variant = item.get("stats", [])
	return raw if raw is Array else []


static func branch_of(item: Dictionary) -> String:
	return str(item.get("branch", "comando"))


static func items_in_branch(branch_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in ITEMS:
		if branch_of(item) == branch_id:
			out.append(item)
	return out


static func depth_of(id: String) -> int:
	## How far down the trunk a node sits, used to indent it. Computed from the
	## `requires` chain rather than authored, so it cannot drift from the data.
	var item := get_item(id)
	if item.is_empty():
		return 0
	var deepest := -1
	for parent in requires_of(item):
		deepest = maxi(deepest, depth_of(parent))
	return deepest + 1


static func blocked_by(item: Dictionary, owned_upgrades: Dictionary) -> Array[String]:
	## Which prerequisites are still missing. The tree shows this as words — "abre
	## com Café de Rancho" — because a locked node the player cannot see a route to
	## is indistinguishable from a bug.
	var missing: Array[String] = []
	for parent in requires_of(item):
		if not owned_upgrades.has(parent):
			missing.append(parent)
	return missing


static func price_for(item: Dictionary, _owned_upgrades: Dictionary = {}) -> float:
	## What this node costs. Kept as a function so every screen asks one place.
	return float(item.get("cost", 0.0))


static func refund_retired(owned_upgrades: Dictionary) -> float:
	## Takes every retired node out of `owned_upgrades` and returns what they
	## cost, so the caller can hand it back.
	var refund := 0.0
	for id: String in RETIRED:
		if owned_upgrades.has(id):
			owned_upgrades.erase(id)
			refund += EconomyMath.pace_cost(float(RETIRED[id]))
	return refund


static func is_valid() -> bool:
	## Guards the three ways this data can be wrong in a way no screen would
	## show: a duplicate id, a `requires` pointing nowhere, and a cycle. The last
	## one would hang `depth_of` rather than merely look odd.
	var ids := {}
	var branch_ids := {}
	for branch in branches():
		branch_ids[str(branch.get("id", ""))] = true
	for item in ITEMS:
		var id := str(item.get("id", ""))
		if id.is_empty() or ids.has(id):
			return false
		if not branch_ids.has(branch_of(item)):
			return false
		if float(item.get("cost", 0.0)) <= 0.0:
			return false
		ids[id] = true
	for item in ITEMS:
		for parent in requires_of(item):
			if not ids.has(parent):
				return false
	return not _has_cycle()


static func _has_cycle() -> bool:
	var state := {}   # id -> 1 visiting, 2 done
	for item in ITEMS:
		if _visit(str(item.get("id", "")), state):
			return true
	return false


static func _visit(id: String, state: Dictionary) -> bool:
	var mark := int(state.get(id, 0))
	if mark == 2:
		return false
	if mark == 1:
		return true
	state[id] = 1
	for parent in requires_of(get_item(id)):
		if _visit(parent, state):
			return true
	state[id] = 2
	return false
