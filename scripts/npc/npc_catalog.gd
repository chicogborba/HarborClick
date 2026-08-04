class_name NpcCatalog
## Who works here, and why the port would stop without them.
##
## A container terminal is a chain with a small number of links, and every link
## is one person's station:
##
##   mar -> [berço] portêiner -> [pátio] conferente -> [pilha] transtêiner
##       -> [estrada] motorista -> [portão] despachante -> [cidade] carreteiro
##
## and the same chain backwards for a caixa que embarca. The manoeuvre that puts
## a hull alongside is its own station, because nothing else on that list can
## happen until it is done.
##
## So the crew is deliberately short. Only the roles on that chain get a name, a
## dossier and a task: a warehouse, a control tower or an AI hub is a building,
## not a character, and giving one a person would be exactly the scatter this
## catalog exists to avoid. Buying more equipment makes the port faster; it does
## not make it more crowded with strangers.

## The stations, from the water to the city gate.
const STATION_BERTH: StringName = &"berco"
const STATION_YARD: StringName = &"patio"
const STATION_STACK: StringName = &"pilha"
const STATION_ROAD: StringName = &"estrada"
const STATION_GATE: StringName = &"portao"
const STATION_CITY: StringName = &"cidade"
const STATION_MANOEUVRE: StringName = &"manobra"

## Structure id (or `road_truck`) -> the person who operates it.
##
## `duty` is the answer to "why does this job exist", printed on the dossier. If
## a role cannot answer it in one sentence, it does not belong on this list.
const ROLES := {
	"sts": {
		"station": STATION_BERTH,
		"title": "Operador de portêiner",
		"duty": "Tira a caixa do porão e a põe em terra. Nada entra no porto pelo mar sem passar pelo spreader dele.",
	},
	"estivador": {
		"station": STATION_YARD,
		"title": "Conferente de pátio",
		"duty": "Confere o lacre e decide em que bloco a caixa fica. É quem sabe onde cada contêiner está.",
	},
	"rtg": {
		"station": STATION_STACK,
		"title": "Operador de transtêiner",
		"duty": "Arruma a pilha por dentro. Sem ele o pátio ocupa o dobro de área para a mesma carga.",
	},
	"tt": {
		"station": STATION_ROAD,
		"title": "Motorista de terminal",
		"duty": "Puxa a carreta do costado ao bloco e volta vazio. Não tem placa de rua: é o elo entre o berço e a pilha.",
	},
	"reach_stacker": {
		"station": STATION_ROAD,
		"title": "Operador de reach stacker",
		"duty": "Pega a caixa de cima da pilha sem transtêiner e a entrega na rua. O reforço do elo terrestre.",
	},
	"empilhadeira": {
		"station": STATION_ROAD,
		"title": "Operador de empilhadeira",
		"duty": "Move as caixas leves e as vazias, liberando os equipamentos grandes para o que é pesado.",
	},
	"alfandega": {
		"station": STATION_GATE,
		"title": "Despachante do portão",
		"duty": "Libera o caminhão. A cancela só sobe depois que o papel dela está em ordem.",
	},
	"rebocador": {
		"station": STATION_MANOEUVRE,
		"title": "Comandante de rebocador",
		"duty": "Encosta o navio no cais e o tira de lá. Antes disso, não existe escala nenhuma.",
	},
	"road_truck": {
		"station": STATION_CITY,
		"title": "Carreteiro",
		"duty": "Traz o que a cidade exporta e leva para casa o que o navio descarregou. A outra porta do porto.",
	},
}

## Everything else on the terminal — armazém, torre, porto de IA, portal, trem,
## guindaste flutuante, drone — is infrastructure. It works, it just is not
## somebody.
static func has_crew(role: String) -> bool:
	return ROLES.has(role)


static func station_of(role: String) -> StringName:
	return ROLES.get(role, {}).get("station", &"")


static func title_of(role: String) -> String:
	return str(ROLES.get(role, {}).get("title", "Trabalhador do porto"))


static func duty_of(role: String) -> String:
	return str(ROLES.get(role, {}).get("duty", ""))


## Three people the port would be different without, seeded at a fixed station
## so they are always found among the crew rather than rolled for.
##
## Only the conferente carries a `hat`: his is the one sprite with a helmet to
## tint, and a colour on a role that cannot show it would be a promise the game
## does not keep. A tug master in a hard hat would be wrong anyway.
const SPECIALS := [
	{
		"id": &"alisson",
		"role": "estivador",
		"slot": 0,
		"name": "Alisson",
		"hat": "#3f7ad6",
		"dossier": "Veio da Wilson Sons de Rio Grande, onde aprendeu a ler um pátio inteiro de longe: sabe pela altura da pilha o que já saiu e o que ainda vai sair. Chegou dizendo que aqui o vento é mais manso.",
		"trait": "Capacete azul, sempre. Diz que é para o pessoal do costado achar ele na neblina.",
	},
	{
		"id": &"valdir",
		"role": "rebocador",
		"slot": 0,
		"name": "Seu Valdir",
		"dossier": "Trinta anos na barra. Já entrou com navio na maré vazando e no nevoeiro fechado, e conta as duas histórias com a mesma calma.",
		"trait": "Não usa rádio para atracar. Diz que o cabo fala mais alto.",
	},
	{
		"id": &"neusa",
		"role": "alfandega",
		"slot": 0,
		"name": "Dona Neusa",
		"dossier": "Conhece a placa de cada carreta que entra aqui e o nome de quem dirige. Papel errado não passa da guarita, e ninguém tenta duas vezes.",
		"trait": "Café às seis. A cancela abre depois do café.",
	},
]

## Names for everybody else. Gaúchos, porque é onde o porto está.
const FIRST_NAMES := [
	"Ademar", "Bruna", "Cleber", "Daiane", "Everton", "Fabiane", "Gilmar",
	"Helena", "Ivete", "Jocelito", "Kelen", "Loivo", "Marilda", "Nilson",
	"Odete", "Rejane", "Sandro", "Tarcísio", "Vanderlei", "Zaira",
]
const SURNAMES := [
	"Bandeira", "Camargo", "Dorneles", "Escobar", "Fontoura", "Goulart",
	"Krause", "Lemos", "Moraes", "Nunes", "Ortiz", "Pacheco", "Quadros",
	"Rodrigues", "Silveira", "Tavares", "Vargas", "Weber", "Xavier",
	"Zambrano",
]

## One line of texture per station, so a rolled crew member still reads as a
## person with a history instead of two random words.
const BACKGROUNDS := {
	STATION_BERTH: [
		"Subiu de sinaleiro a operador em quatro anos. Trabalha de cabine com a janela aberta, mesmo no frio.",
		"Conta os movimentos da própria escala em voz baixa. Erra por um, no máximo.",
	],
	STATION_YARD: [
		"Anota tudo num caderno antes de anotar no sistema. Diz que o caderno nunca caiu.",
		"Sabe de cor em que bloco está cada carga que chegou esta semana.",
	],
	STATION_STACK: [
		"Empilha três de altura como quem guarda louça. Nunca precisou remover uma caixa duas vezes.",
		"Aprendeu no pátio de vazios e trouxe de lá o hábito de deixar corredor sobrando.",
	],
	STATION_ROAD: [
		"Faz a volta pelo portão mesmo quando dava para cortar. Diz que atalho no pátio custa caro.",
		"Conhece cada buraco da via de serviço e desvia sem tirar o pé.",
	],
	STATION_GATE: [
		"Fecha a papelada antes da carreta parar. Ninguém espera na guarita por causa dela.",
		"Guarda cópia de tudo. Já salvou duas escalas com isso.",
	],
	STATION_CITY: [
		"Roda a mesma linha há anos: cidade, portão, pátio, cidade. Chega no horário.",
		"Nunca sai daqui com o chassi vazio se der para levar carga.",
	],
	STATION_MANOEUVRE: [
		"Lê o vento pelo movimento das boias do canal.",
		"Já rebocou de tudo, inclusive o que não devia ter saído do estaleiro.",
	],
}


static func background_for(station: StringName, index: int) -> String:
	var pool: Array = BACKGROUNDS.get(station, [])
	if pool.is_empty():
		return "Bateu o ponto pela primeira vez numa segunda de neblina."
	return str(pool[posmod(index, pool.size())])


static func special_for(role: String, slot: int) -> Dictionary:
	for special: Dictionary in SPECIALS:
		if str(special.role) == role and int(special.slot) == slot:
			return special.duplicate(true)
	return {}
