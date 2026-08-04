class_name SpecialCallDB
## Rare escalas: a charter nobody expected, on a hull nobody has seen, worked as
## a minigame instead of as taps.
##
## The old contracts were a card in the Diário that quietly counted boxes. These
## are events: they interrupt, they are refusable, they are hard, and they pay or
## they cost. Everything about one is declared here so the director stays pure
## scheduling and the UI stays presentation.
##
## Rewards and forfeits are priced in the port's **own** income — seconds of cps
## or a multiplier for a window — so a charter accepted in the first hour and one
## accepted in the tenth are worth the same *amount of progress*, never a flat
## number that is enormous once and invisible later.

## What a win pays / a loss costs.
const REWARD_SURGE: StringName = &"surge"       # multiplier for N seconds
const REWARD_LUMP: StringName = &"lump"         # N seconds of income, at once
const PENALTY_FINE: StringName = &"fine"        # N seconds of income, taken
const PENALTY_SLUMP: StringName = &"slump"      # multiplier < 1 for N seconds

## The minigames a charter can be worked with. A charter names one; `Main` opens
## the board that plays it.
const GAME_STACK: StringName = &"stack"
const GAME_MAZE: StringName = &"maze"

const OFFERS: Array[Dictionary] = [
	{
		"id": "gala_relampago",
		"title": "Escala Relâmpago",
		"brief": "Um armador pagou pra furar a fila. O navio já está na barra e só encosta se a gente garantir a operação inteira num turno.",
		"game": GAME_STACK,
		"hull": "panamax",
		"goal": 8,
		"seconds": 42.0,
		"reward": {"kind": REWARD_SURGE, "mult": 10.0, "seconds": 15.0},
		"penalty": {"kind": PENALTY_FINE, "seconds": 25.0},
	},
	{
		"id": "carga_projeto",
		"title": "Carga de Projeto",
		"brief": "Peças de usina, altas e sem prumo. Empilhar isso é serviço de quem tem pulso, e o frete vem no mesmo tamanho do risco.",
		"game": GAME_STACK,
		"hull": "new_panamax",
		"goal": 10,
		"seconds": 48.0,
		"reward": {"kind": REWARD_SURGE, "mult": 2.0, "seconds": 120.0},
		"penalty": {"kind": PENALTY_SLUMP, "mult": 0.5, "seconds": 45.0},
	},
	{
		"id": "janela_de_mare",
		"title": "Janela de Maré",
		"brief": "A maré fecha em quarenta segundos e o ULCV não espera. Se ele sair carregado, o porto entra na rota de vez.",
		"game": GAME_STACK,
		"hull": "ulcv",
		"goal": 12,
		"seconds": 40.0,
		"reward": {"kind": REWARD_LUMP, "seconds": 900.0},
		"penalty": {"kind": PENALTY_FINE, "seconds": 40.0},
	},
	{
		"id": "resgate_de_feeder",
		"title": "Resgate de Feeder",
		"brief": "Um feeder encalhou o próprio embarque em outro terminal e chegou aqui pedindo socorro. Serviço pequeno, prazo curto, gratidão grande.",
		"game": GAME_STACK,
		"hull": "coastal_feeder",
		"goal": 6,
		"seconds": 30.0,
		"reward": {"kind": REWARD_SURGE, "mult": 5.0, "seconds": 30.0},
		"penalty": {"kind": PENALTY_FINE, "seconds": 15.0},
	},
	{
		"id": "carga_perdida",
		"title": "Carga Perdida no Pátio",
		"brief": "O sistema caiu no meio do turno e três contêineres sumiram do mapa. Estão no pátio, em algum lugar. O navio sai com maré, achando ou não.",
		"game": GAME_MAZE,
		"hull": "handysize",
		"crates": 3,
		"goal": 3,
		"seconds": 50.0,
		"reward": {"kind": REWARD_SURGE, "mult": 4.0, "seconds": 45.0},
		"penalty": {"kind": PENALTY_FINE, "seconds": 30.0},
	},
	{
		"id": "vistoria_surpresa",
		"title": "Vistoria Surpresa",
		"brief": "A fiscalização quer ver cinco contêineres específicos, agora, e o pátio está do jeito que está. Achar todos é o serviço; achar rápido é o prêmio.",
		"game": GAME_MAZE,
		"hull": "coastal",
		"crates": 5,
		"goal": 5,
		"seconds": 60.0,
		"reward": {"kind": REWARD_LUMP, "seconds": 600.0},
		"penalty": {"kind": PENALTY_SLUMP, "mult": 0.6, "seconds": 40.0},
	},
]


static func get_offer(id: StringName) -> Dictionary:
	for offer in OFFERS:
		if StringName(offer.id) == id:
			return offer.duplicate(true)
	return {}


static func materialize(career_seed: int, index: int) -> Dictionary:
	## Deterministic pick, so the same career offers the same charters in the same
	## order — an event that rerolls on reload is an event worth reloading for.
	if OFFERS.is_empty():
		return {}
	var state: int = posmod(career_seed, 2147483646) + 1
	for _step in range(posmod(index, 89) + 1):
		state = posmod(state * 48271, 2147483647)
	var offer: Dictionary = OFFERS[posmod(state, OFFERS.size())].duplicate(true)
	offer["index"] = index
	return offer


static func reward_text(offer: Dictionary) -> String:
	var reward: Dictionary = offer.get("reward", {})
	match StringName(reward.get("kind", &"")):
		REWARD_SURGE:
			return "%dx a produção por %ds" % [int(reward.get("mult", 1.0)),
				int(reward.get("seconds", 0.0))]
		REWARD_LUMP:
			return "+%s TEU de uma vez" % GameState.fmt(
				_income(float(reward.get("seconds", 0.0))))
	return "frete extra"


static func penalty_text(offer: Dictionary) -> String:
	var penalty: Dictionary = offer.get("penalty", {})
	match StringName(penalty.get("kind", &"")):
		PENALTY_FINE:
			return "multa de %s TEU" % GameState.fmt(
				_income(float(penalty.get("seconds", 0.0))))
		PENALTY_SLUMP:
			return "produção a %d%% por %ds" % [
				int(float(penalty.get("mult", 1.0)) * 100.0),
				int(penalty.get("seconds", 0.0))]
	return "nenhuma"


static func apply_reward(offer: Dictionary) -> Dictionary:
	var reward: Dictionary = offer.get("reward", {})
	match StringName(reward.get("kind", &"")):
		REWARD_SURGE:
			var mult := maxf(1.0, float(reward.get("mult", 1.0)))
			var seconds := maxf(1.0, float(reward.get("seconds", 0.0)))
			GameState.grant_surge(mult, seconds)
			return {"kind": REWARD_SURGE, "mult": mult, "seconds": seconds,
				"text": "%dx a produção por %ds!" % [int(mult), int(seconds)]}
		REWARD_LUMP:
			var amount := _income(float(reward.get("seconds", 0.0)))
			# Career money: it spends, but it must not shortcut the prestige curve
			# the simulator was balanced against.
			GameState.grant_nonproductive_reward(amount)
			return {"kind": REWARD_LUMP, "amount": amount,
				"text": "+%s TEU de frete!" % GameState.fmt(amount)}
	return {}


static func apply_penalty(offer: Dictionary) -> Dictionary:
	var penalty: Dictionary = offer.get("penalty", {})
	match StringName(penalty.get("kind", &"")):
		PENALTY_FINE:
			var taken := GameState.apply_fine(
				_income(float(penalty.get("seconds", 0.0))))
			return {"kind": PENALTY_FINE, "amount": taken,
				"text": "Multa de %s TEU." % GameState.fmt(taken)}
		PENALTY_SLUMP:
			var mult := clampf(float(penalty.get("mult", 1.0)), 0.05, 1.0)
			var seconds := maxf(1.0, float(penalty.get("seconds", 0.0)))
			GameState.grant_surge(mult, seconds)
			return {"kind": PENALTY_SLUMP, "mult": mult, "seconds": seconds,
				"text": "Produção a %d%% por %ds." % [int(mult * 100.0), int(seconds)]}
	return {}


static func is_valid() -> bool:
	var ids := {}
	var games := {}
	for offer in OFFERS:
		var id := StringName(offer.get("id", ""))
		if id.is_empty() or ids.has(id):
			return false
		ids[id] = true
		games[StringName(offer.get("game", &""))] = true
		if int(offer.get("goal", 0)) < 3 or float(offer.get("seconds", 0.0)) < 10.0:
			return false
		# A charter has to name a game something can actually open.
		if not [GAME_STACK, GAME_MAZE].has(StringName(offer.get("game", &""))):
			return false
		if ShipCatalog.get_silhouette(StringName(offer.get("hull", ""))).is_empty():
			return false
		if reward_text(offer).is_empty() or penalty_text(offer) == "nenhuma":
			return false
	return ids.size() >= 3 and games.size() >= 2


static func _income(seconds: float) -> float:
	## Seconds of the port's own throughput, with a floor so a brand-new terminal
	## still has something at stake.
	var rate := maxf(GameState.cps, GameState.click_power)
	return maxf(40.0, rate * maxf(0.0, seconds))
