class_name CosmeticDb
## Static data for every decoration the terminal can be dressed in.
##
## A cosmetic is the only thing in this game you buy that does nothing. It pays
## no TEUs, unlocks no station and appears in no rate breakdown — which is the
## whole point of it, and the reason it needs rules of its own:
##
##   * **it is bought once and kept forever.** A machine is a run's asset and a
##     reset takes it away; a decoration is the player's, and surviving the
##     rebuild is most of what makes it worth buying. `GameState.do_prestige`
##     never touches the two dictionaries these live in.
##   * **it can be switched off.** Owning a giant inflatable duck and having a
##     giant inflatable duck moored in your harbour are different decisions, and
##     the second one is allowed to change on a Tuesday.
##   * **it says what it does before you pay.** These cost real TEUs, and a
##     decoration nobody can picture is a decoration nobody buys.
##
## Prices are steep on purpose. A cosmetic competes with a crane for the same
## wallet, so it has to be something you choose rather than something you sweep
## up on the way past — and every one of these is priced around the point in a
## run where the yard has stopped being an emergency.

## `kind` groups the list in the shop. `port` dresses the terminal, `crew`
## dresses the people working it.
const KIND_PORT := &"port"
const KIND_CREW := &"crew"

const ITEMS: Array[Dictionary] = [
	{
		"id": "rgb_lamps", "kind": KIND_PORT,
		"name": "Luzes RGB",
		"desc": "Todo poste do terminal troca de cor devagar, a noite inteira. Ninguém pediu. Fica ótimo.",
		"cost": 45000.0, "icon": "STAR",
	},
	{
		"id": "bunting", "kind": KIND_PORT,
		"name": "Bandeirinhas",
		"desc": "Varal de galhardetes de poste a poste no cais. O porto em festa junina permanente.",
		"cost": 12000.0, "icon": "SHIP",
	},
	{
		"id": "planters", "kind": KIND_PORT,
		"name": "Floreiras",
		"desc": "Canteiros de concreto com flor de verdade ao longo da faixa de serviço.",
		"cost": 8000.0, "icon": "LAND",
	},
	{
		"id": "duck", "kind": KIND_PORT,
		"name": "Pato Gigante",
		"desc": "Um pato inflável do tamanho de um rebocador, atracado na bacia. Custou caro. Valeu.",
		"cost": 250000.0, "icon": "PAW",
	},
	{
		"id": "cats", "kind": KIND_PORT,
		"name": "Colônia de Gatos",
		"desc": "Mais gatos dormindo em cima das pilhas. A produtividade não muda. O moral, sim.",
		"cost": 30000.0, "icon": "PAW",
	},
	{
		"id": "party_hats", "kind": KIND_CREW,
		"name": "Chapéus de Festa",
		"desc": "A equipe troca o capacete por um cone de aniversário. A NR-11 não vai gostar.",
		"cost": 20000.0, "icon": "CREW",
	},
	{
		"id": "gold_hats", "kind": KIND_CREW,
		"name": "Capacetes Dourados",
		"desc": "Capacete banhado a ouro para todo mundo no pátio. Discreto que só.",
		"cost": 500000.0, "icon": "TROPHY",
	},
]


static func all() -> Array[Dictionary]:
	return ITEMS


static func of(id: StringName) -> Dictionary:
	for item: Dictionary in ITEMS:
		if StringName(item.id) == id:
			return item
	return {}


static func exists(id: StringName) -> bool:
	return not of(id).is_empty()


static func cost(id: StringName) -> float:
	return float(of(id).get("cost", 0.0))


static func display_name(id: StringName) -> String:
	return str(of(id).get("name", String(id)))
