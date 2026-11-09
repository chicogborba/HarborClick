class_name UpgradeDB
## Static data for upgrades, as a graph rather than a shelf.
##
## The shelf version was eighteen cards that all said `×2`. There was always one
## right answer — the cheapest payback — and the card computed it for you, so the
## "decision" was arithmetic the interface had already done. This file is the
## same catalogue rebuilt as something a player climbs: every node names what
## opens it, some nodes refuse to sit beside their neighbour, and a few stop
## making a machine *more* and make it *something else*.
##
## Four things carry that weight, and every one of them is readable off a card:
##
## - `requires` — other upgrade ids that must be owned first. This is the edge
##   that makes the tree a tree. `unlock` still exists and still gates on the
##   port's size, but a node with an unmet `requires` is visibly blocked by a
##   *purchase*, which is a thing the player can go and do.
## - `excludes` — a node that cannot be owned beside this one. Bought later, the
##   loser is refitted out at `SWAP_SURCHARGE` times the price: expensive, so the
##   first pick matters; possible, so the pick is not a trap.
## - `kind: "synergy"` — a machine gains for every unit of a *different* machine
##   the port runs. Composition starts to matter: fifteen of one thing and one of
##   another is now a worse port than a balanced one, or a better one, depending
##   on which nodes you took.
## - `kind: "transform"` — the machine changes job. `conductor` mode guts a
##   machine's own output and pays the port a percentage per unit instead, which
##   turns a generator into a multiplier and makes a wide cheap fleet a strategy
##   rather than a rounding error.
##
## `kind` values in full: "click_mult" (multiplies click), "structure_mult"
## (multiplies one or more structures' cps), "global_mult" (multiplies all cps),
## "click_cps_pct" (click also gains % of cps), "synergy", "transform",
## "rail_stat" (moves a real knob on the branch line).
##
## `unlock`: {teus: X} lifetime TEUs or {owned: {id: n}} structure count needed.

## What refitting out an exclusive choice costs, as a multiple of the incoming
## node's price. The roadmap's requirement was "cara mas possível": a player who
## picks wrong at hour two must not be reading about it at hour forty, and a
## player who picks right must not feel the choice was free.
const SWAP_SURCHARGE := 3.0

## Trunks of the tree, in the order they are drawn. `machines` is what the trunk
## is *about* — used to pick the art when a node has no single target of its own.
const BRANCHES: Array[Dictionary] = [
	{"id": "mao", "title": "Mão de Obra", "art": "estivador"},
	{"id": "patio", "title": "Pátio", "art": "rtg"},
	{"id": "cais", "title": "Cais", "art": "sts"},
	{"id": "ramal", "title": "Ramal Ferroviário", "art": "trem"},
	{"id": "portao", "title": "Portão", "art": "alfandega"},
	{"id": "comando", "title": "Comando", "art": "torre"},
]

const ITEMS: Array[Dictionary] = [
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
	# The first of the five conductors — the `group: "conductor"` nodes that answer
	# "who actually runs this terminal". Exactly one can be fitted at a time, and
	# which one is worth taking depends entirely on where the port already has
	# depth: 1,5% per docker is enormous to a yard with two hundred of them and
	# nothing to a yard with six. That is the composition axis item 4 was missing,
	# and it is a question a payback figure cannot answer for you.
	{"id": "turma_de_terra", "name": "Turma de Terra", "short": "Turma",
		"desc": "O estivador larga o gancho e passa a orientar o pátio inteiro. Produz quase nada sozinho; os primeiros somam ~2% cada a todo o porto, e o ganho desacelera rumo a +300%.",
		"branch": "mao", "kind": "transform", "target": "estivador",
		"mode": "conductor", "group": "conductor",
		"self_mult": 0.25, "value": 0.023, "cap": 3.0,
		"cost": 20e6, "requires": ["sindicato"],
		"unlock": {"owned": {"estivador": 40}}},

	# -------------------------------------------------------------------- pátio
	{"id": "garfo_duplo", "name": "Garfo Duplo", "short": "Garfo",
		"desc": "Dois pallets por viagem. O dobro de vento no rosto.",
		"branch": "patio", "kind": "structure_mult", "target": "empilhadeira",
		"value": 2.0, "cost": 4000.0, "unlock": {"owned": {"empilhadeira": 5}}},
	{"id": "buzina_musical", "name": "Buzina Musical", "short": "Buzina",
		"desc": "Toca 'La Cucaracha'. Moral +40%, paciência do turno -60%.",
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
	# Estoque × giro. Deep stacking wins on the one machine built for it; fast
	# turnover wins across the three that move boxes sideways.
	{"id": "estoque_profundo", "name": "Estoque Profundo", "short": "Estoque",
		"desc": "Cinco alturas no bloco e ninguém remexe. O transtêiner rende 4×; o resto do pátio segue igual.",
		"branch": "patio", "kind": "structure_mult", "target": "rtg", "value": 4.0,
		"cost": 300e6, "requires": ["operacao_remota_rtg"],
		"excludes": ["giro_rapido"], "unlock": {"owned": {"rtg": 15}}},
	{"id": "giro_rapido", "name": "Giro Rápido", "short": "Giro",
		"desc": "Pilha baixa, remoção rara, tudo andando. Empilhadeira e reach stacker rendem 2,2×; o bloco não muda.",
		"branch": "patio", "kind": "structure_mult",
		"targets": ["empilhadeira", "reach_stacker"], "value": 2.2,
		"cost": 300e6, "requires": ["operacao_remota_rtg"],
		"excludes": ["estoque_profundo"], "unlock": {"owned": {"rtg": 15}}},
	# Conductor two. A yard that stacks deep has few RTGs and a lot riding on each,
	# so this pays more per unit than the dockers' turma and caps far sooner.
	{"id": "bloco_mestre", "name": "Bloco Mestre", "short": "Bloco Mestre",
		"desc": "O transtêiner deixa de mover caixa e passa a reger o bloco. Os primeiros somam ~6% cada a todo o porto, desacelerando rumo a +360% - e o RTG em si quase para.",
		"branch": "patio", "kind": "transform", "target": "rtg",
		"mode": "conductor", "group": "conductor",
		"self_mult": 0.25, "value": 0.06, "cap": 3.6,
		"cost": 400e6, "requires": ["operacao_remota_rtg"],
		"unlock": {"owned": {"rtg": 12}}},

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
	# Conductor three, and the tall build's natural answer: a portêiner is the most
	# expensive thing on the board that a port ever owns dozens of, so 4% a unit
	# caps at a fleet a deep port has and a wide one never bothers with.
	# Hangs off the first quay node, not the second, and is priced in the same era
	# as the dockers' turma on purpose. An identity that only opens after the port
	# is already rich is not a choice — the sandbox showed exactly that: the build
	# committed to the quay never reached its own conductor, fell behind, and then
	# could not afford it precisely because it had fallen behind.
	{"id": "cais_dedicado", "name": "Cais Dedicado", "short": "Dedicado",
		"desc": "O portêiner para de trabalhar caixa avulsa e passa a ditar o ritmo do porto. Os primeiros somam ~10% cada, desacelerando rumo a +450% - e o cais rende um terço.",
		"branch": "cais", "kind": "transform", "target": "sts",
		"mode": "conductor", "group": "conductor",
		"self_mult": 0.3, "value": 0.10, "cap": 4.5,
		"cost": 50e6, "requires": ["operador_descansado"],
		"unlock": {"owned": {"sts": 10}}},
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
	# Profundidade × cadência no cais: um berço que engole um navio enorme, ou
	# três berços que nunca ficam vazios.
	{"id": "escala_profunda", "name": "Escala Profunda", "short": "Escala",
		"desc": "Um berço, um navio gigante, uma escala longa. O portêiner rende 2,6×; o apoio segue igual.",
		"branch": "cais", "kind": "structure_mult", "target": "sts", "value": 2.6,
		"cost": 60e12, "requires": ["spreader_pesado"],
		"excludes": ["cadencia_de_cais"], "unlock": {"owned": {"sts": 20}}},
	{"id": "cadencia_de_cais", "name": "Cadência de Cais", "short": "Cadência",
		"desc": "Navio médio entrando e saindo o dia todo. Rebocador e flutuante rendem 2,4×; o portêiner segue igual.",
		"branch": "cais", "kind": "structure_mult",
		"targets": ["rebocador", "flutuante"], "value": 2.4,
		"cost": 60e12, "requires": ["spreader_pesado"],
		"excludes": ["escala_profunda"], "unlock": {"owned": {"sts": 20}}},

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
		"desc": "Dois trens, uma pressa só. Mais dois vagões em cada serviço — o comprimento máximo que o desvio de manobra comporta.",
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
	# Profundidade × cadência, na versão ferroviária. O comprimento do trem é
	# limitado pelo chão, então a escolha se dá no relógio: uma composição que fica
	# muito tempo e vem raro, ou um vaivém que mal encosta e nunca para. As duas
	# movem carga; nenhuma move a mesma, e nenhuma é a resposta certa.
	{"id": "trem_pesado", "name": "Trem Pesado", "short": "Pesado",
		"desc": "Bloco de longo curso: fica 2 minutos a mais na rampa, mas o intervalo entre serviços cresce 50%. Rende para quem trabalha o trem inteiro.",
		"branch": "ramal", "kind": "rail_stat",
		"stats": [{"stat": "dwell", "operation": "add_flat", "value": 120.0},
			{"stat": "service_gap", "operation": "mult", "value": 1.5}],
		"cost": 30e12, "requires": ["portico_ferroviario"],
		"excludes": ["trem_shuttle"], "unlock": {"owned": {"trem": 10}}},
	{"id": "trem_shuttle", "name": "Shuttle de Cintura", "short": "Shuttle",
		"desc": "Vaivém para o pátio vizinho: encosta 1 minuto a menos, e vem com menos da metade do intervalo. Rende para quem tem pórtico e não precisa olhar.",
		"branch": "ramal", "kind": "rail_stat",
		"stats": [{"stat": "dwell", "operation": "add_flat", "value": -60.0},
			{"stat": "service_gap", "operation": "mult", "value": 0.45}],
		"cost": 30e12, "requires": ["portico_ferroviario"],
		"excludes": ["trem_pesado"], "unlock": {"owned": {"trem": 10}}},
	{"id": "terminal_interior", "name": "Terminal Interior", "short": "Porto Seco",
		"desc": "O ramal vira porto seco: o ramal em si quase para de produzir, mas os primeiros somam ~20% cada a todo o porto, rumo a +450% - e o bônus de composição completa triplica.",
		"branch": "ramal", "kind": "transform", "target": "trem",
		"mode": "conductor", "group": "conductor",
		"self_mult": 0.3, "value": 0.20, "cap": 4.5,
		"stats": [{"stat": "completion", "operation": "mult", "value": 3.0}],
		"cost": 120e12, "requires": ["portico_ferroviario"],
		"unlock": {"owned": {"trem": 15}}},

	# ------------------------------------------------------------------- portão
	{"id": "pneus_novos", "name": "Pneus Sem Careca", "short": "Pneus",
		"desc": "Aderência descoberta em 2024.",
		"branch": "portao", "kind": "structure_mult", "target": "tt", "value": 2.0,
		"cost": 44000.0, "unlock": {"owned": {"tt": 5}}},
	{"id": "radio_pesado", "name": "Rádio no Talo", "short": "Rádio",
		"desc": "Motorista feliz dirige 12% mais reto.",
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
	# Conductor five, and the last identity a terminal takes on. Few, enormous, and
	# every one worth 6% of everything — the ceiling is reached by a port with
	# thirty control towers, which is a sentence only a very late port can say.
	{"id": "centro_de_controle", "name": "Centro de Controle", "short": "Centro",
		"desc": "A torre para de operar e passa a mandar. Quase não produz sozinha; as primeiras somam ~20% cada, desacelerando rumo a +450%.",
		"branch": "comando", "kind": "transform", "target": "torre",
		"mode": "conductor", "group": "conductor",
		"self_mult": 0.2, "value": 0.20, "cap": 4.5,
		"cost": 2e15, "requires": ["janela_berco_ia"],
		"unlock": {"owned": {"torre": 10}}},
]


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
	## Which machines a node is fitted to. Most nodes name one; the exclusive
	## "spread" halves name two or three, and a node with no machine at all — a
	## click or global multiplier — names none.
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


static func excludes_of(item: Dictionary) -> Array[String]:
	## Authored exclusions, plus every other member of this node's group.
	##
	## `group` exists so an N-way choice does not have to be written out N times
	## with N chances to forget one and leave the rule half-applied. The conductor
	## nodes are one such choice: a terminal is run by its dockers, or its yard, or
	## its quay, or its railhead, or its tower — one answer, swappable, never two.
	var out: Array[String] = []
	for entry in item.get("excludes", []):
		out.append(str(entry))
	var group := str(item.get("group", ""))
	if group.is_empty():
		return out
	var id := str(item.get("id", ""))
	for other in ITEMS:
		var other_id := str(other.get("id", ""))
		if other_id != id and str(other.get("group", "")) == group \
				and not out.has(other_id):
			out.append(other_id)
	return out


static func stats_of(item: Dictionary) -> Array:
	## Rail knobs a node moves. A `transform` can carry these too — Terminal
	## Interior changes what the branch pays as well as what the machine is for.
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


static func conflicts_with(item: Dictionary, owned_upgrades: Dictionary) -> Array[String]:
	## Which owned nodes this one would refit out. Non-empty means the purchase is
	## a swap at `SWAP_SURCHARGE`, not a plain buy.
	var hits: Array[String] = []
	for other in excludes_of(item):
		if owned_upgrades.has(other):
			hits.append(other)
	return hits


static func price_for(item: Dictionary, owned_upgrades: Dictionary) -> float:
	## What this node costs *this* port right now. A first pick is the list price;
	## replacing the sibling you already fitted is the list price times the
	## surcharge, and the card says so before the press, not after.
	var cost := float(item.get("cost", 0.0))
	return cost * SWAP_SURCHARGE if not conflicts_with(item, owned_upgrades).is_empty() \
		else cost


static func is_valid() -> bool:
	## Guards the four ways this data can be wrong in a way no screen would show:
	## a duplicate id, a `requires` pointing nowhere, a one-sided exclusion, and a
	## cycle. The last one would hang `depth_of` rather than merely look odd.
	var ids := {}
	var branch_ids := {}
	for branch in BRANCHES:
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
		for other in excludes_of(item):
			# Exclusion has to be mutual, or the order of purchase would decide
			# whether the rule applied at all.
			if not ids.has(other):
				return false
			if not excludes_of(get_item(other)).has(str(item.get("id", ""))):
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
