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

## `level` (optional): the Terminal level that hands this item over for free —
## the rewards on the level roadmap. An item with a level and a `cost` of 0 is
## never sold; one with both can be bought early or earned later.
## `slot` (optional): items sharing a slot are worn one at a time — switching
## one on switches the others off. Every hat is in the `hat` slot.
## `hat`: the helmet colour, or "rainbow" for one hue per worker.
## `art`: the frame of `ui_decor_art.png` the shelf shows it with
## (tools/sprites/gen_decor.py ART, same order).
const ITEMS: Array[Dictionary] = [
	{
		"id": "teal_hats", "art": 0, "kind": KIND_CREW, "level": 3, "slot": "hat",
		"hat": "#46c4b2", "name": "Capacete Verde-Água",
		"desc": "A turma inteira de verde-água. Combina com a maré.",
		"cost": 0.0, "icon": "CREW",
	},
	{
		"id": "pink_hats", "art": 1, "kind": KIND_CREW, "level": 5, "slot": "hat",
		"hat": "#f27fb6", "name": "Capacete Rosa",
		"desc": "Rosa-chiclete no pátio todo. Dá pra ver da ponte.",
		"cost": 0.0, "icon": "CREW",
	},
	{
		"id": "purple_hats", "art": 2, "kind": KIND_CREW, "level": 8, "slot": "hat",
		"hat": "#9b6ce0", "name": "Capacete Roxo",
		"desc": "Roxo de time campeão. O Alisson aprovou.",
		"cost": 0.0, "icon": "CREW",
	},
	{
		"id": "white_hats", "art": 3, "kind": KIND_CREW, "level": 11, "slot": "hat",
		"hat": "#f4f2ea", "name": "Capacete de Engenheiro",
		"desc": "Branco, de quem assina o projeto. Todo mundo virou engenheiro.",
		"cost": 0.0, "icon": "CREW",
	},
	{
		"id": "rainbow_hats", "art": 4, "kind": KIND_CREW, "level": 17, "slot": "hat",
		"hat": "rainbow", "name": "Capacete Arco-Íris",
		"desc": "Cada um de uma cor. O pátio parece uma caixa de lápis.",
		"cost": 0.0, "icon": "STAR",
	},
	{
		"id": "black_hats", "art": 5, "kind": KIND_CREW, "level": 22, "slot": "hat",
		"hat": "#30303c", "name": "Capacete Preto Fosco",
		"desc": "Preto fosco, estilo equipe de elite. Sério demais. Adoramos.",
		"cost": 0.0, "icon": "CREW",
	},
	{
		"id": "rgb_lamps", "art": 6, "level": 25, "kind": KIND_PORT,
		"name": "Luzes RGB",
		"desc": "Todo poste do terminal troca de cor devagar, a noite inteira. Ninguém pediu. Fica ótimo.",
		"cost": 45000.0, "icon": "STAR",
	},
	{
		"id": "bunting", "art": 7, "level": 13, "kind": KIND_PORT,
		"name": "Bandeirinhas",
		"desc": "Varal de galhardetes de poste a poste no cais. O porto em festa junina permanente.",
		"cost": 12000.0, "icon": "SHIP",
	},
	{
		"id": "planters", "art": 8, "level": 9, "kind": KIND_PORT,
		"name": "Floreiras",
		"desc": "Canteiros de concreto com flor de verdade ao longo da faixa de serviço.",
		"cost": 8000.0, "icon": "LAND",
	},
	{
		"id": "duck", "art": 9, "level": 30, "kind": KIND_PORT,
		"name": "Pato Gigante",
		"desc": "Um pato inflável do tamanho de um rebocador, atracado na bacia. Custou caro. Valeu.",
		"cost": 250000.0, "icon": "PAW",
	},
	{
		"id": "cats", "art": 10, "level": 20, "kind": KIND_PORT,
		"name": "Colônia de Gatos",
		"desc": "Mais gatos dormindo em cima das pilhas. A produtividade não muda. O moral, sim.",
		"cost": 30000.0, "icon": "PAW",
	},
	{
		"id": "party_hats", "art": 11, "level": 27, "slot": "hat", "kind": KIND_CREW,
		"name": "Chapéus de Festa",
		"desc": "A equipe troca o capacete por um cone de aniversário. A NR-11 não vai gostar.",
		"cost": 20000.0, "icon": "CREW",
	},
	{
		"id": "gold_hats", "art": 12, "slot": "hat", "kind": KIND_CREW,
		"name": "Capacetes Dourados",
		"desc": "Capacete banhado a ouro para todo mundo no pátio. Discreto que só.",
		"cost": 500000.0, "icon": "TROPHY",
	},
	{
		"id": "palms", "art": 13, "kind": KIND_PORT,
		"name": "Coqueiros",
		"desc": "Uma fileira de coqueiros na beira da avenida de acesso. Porto com cara de orla.",
		"cost": 15000.0, "icon": "LAND",
	},
	{
		"id": "flags", "art": 17, "kind": KIND_PORT,
		"name": "Bandeiras do Mundo",
		"desc": "Mastros no cais com a bandeira de cada país que já atracou aqui, tremulando no vento.",
		"cost": 40000.0, "icon": "GLOBE",
	},
	{
		"id": "dolphins", "art": 16, "kind": KIND_PORT,
		"name": "Golfinhos",
		"desc": "Uma família de golfinhos adotou a bacia. De vez em quando um pula pra ver o movimento.",
		"cost": 60000.0, "icon": "SHIP",
	},
	{
		"id": "lighthouse", "art": 14, "kind": KIND_PORT,
		"name": "Farol",
		"desc": "Farol listrado na ponta do cais, com o facho girando a noite inteira.",
		"cost": 90000.0, "icon": "STAR",
	},
	{
		"id": "balloon", "art": 15, "kind": KIND_PORT,
		"name": "Balão Panorâmico",
		"desc": "Um balão de ar quente passeia devagar sobre o terminal. Os turistas acenam pros guindastes.",
		"cost": 120000.0, "icon": "GLOBE",
	},
	{
		"id": "fireworks", "art": 18, "kind": KIND_PORT,
		"name": "Fogos na Baía",
		"desc": "Toda noite tem queima de fogos sobre a água. Ninguém sabe o que estamos comemorando.",
		"cost": 180000.0, "icon": "STAR",
	},
	{
		"id": "neon_hats", "art": 19, "kind": KIND_CREW, "slot": "hat",
		"hat": "#a6ff3c", "name": "Capacete Neon",
		"desc": "Verde-limão fluorescente. Ninguém se perde no pátio, nem de madrugada.",
		"cost": 25000.0, "icon": "CREW",
	},
	{
		"id": "camo_hats", "art": 20, "kind": KIND_CREW, "slot": "hat",
		"hat": "#687846", "name": "Capacete Camuflado",
		"desc": "Camuflagem de operação especial. No meio dos contêineres, ninguém vê ninguém.",
		"cost": 35000.0, "icon": "CREW",
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


static func level_of(id: StringName) -> int:
	## The level that hands it over, or 0 when no level does.
	return int(of(id).get("level", 0))


static func level_only(id: StringName) -> bool:
	## Earned on the roadmap, never sold.
	return level_of(id) > 0 and cost(id) <= 0.0


static func at_level(level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in ITEMS:
		if int(item.get("level", 0)) == level:
			out.append(item)
	return out


static func slot_of(id: StringName) -> String:
	return str(of(id).get("slot", ""))


static func art_of(id: StringName) -> int:
	return int(of(id).get("art", 0))


static func owned_count() -> int:
	var n := 0
	for item: Dictionary in ITEMS:
		if GameState.owns_cosmetic(StringName(item.id)):
			n += 1
	return n
