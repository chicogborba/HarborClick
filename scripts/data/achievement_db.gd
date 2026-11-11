class_name AchievementDB
## Stable Phase 3 career achievements. Runtime state belongs to ProgressionManager.
##
## Every achievement pays Terminal XP (`TerminalLevelService` listens for
## `achievement_completed`) on top of the permanent +1% production each one
## adds. They used to pay "cosmetics" and "career points" that existed nowhere
## else in the game — a reward the player could never see or spend.

const ITEMS: Array[Dictionary] = [
	# TEU (6)
	{"id": "teu_100", "category": "teu", "stat": "teus_earned", "threshold": 100.0, "title": "Primeira Carga", "description": "Produza 100 TEUs.", "reward": {"kind": "xp", "amount": 40}},
	{"id": "teu_10k", "category": "teu", "stat": "teus_earned", "threshold": 10000.0, "title": "Maré de Contêineres", "description": "Produza 10 mil TEUs.", "reward": {"kind": "xp", "amount": 80}},
	{"id": "teu_1m", "category": "teu", "stat": "teus_earned", "threshold": 1000000.0, "title": "Cidade-Porto", "description": "Produza 1 milhão de TEUs.", "reward": {"kind": "xp", "amount": 40}},
	{"id": "teu_100m", "category": "teu", "stat": "teus_earned", "threshold": 100000000.0, "title": "Corredor Continental", "description": "Produza 100 milhões de TEUs.", "reward": {"kind": "xp", "amount": 160}},
	{"id": "teu_1b", "category": "teu", "stat": "teus_earned", "threshold": 1000000000.0, "title": "Escala Oceânica", "description": "Produza 1 bilhão de TEUs.", "reward": {"kind": "xp", "amount": 40}},
	{"id": "teu_1t", "category": "teu", "stat": "teus_earned", "threshold": 1000000000000.0, "title": "Terminal Global", "description": "Produza 1 trilhão de TEUs.", "reward": {"kind": "xp", "amount": 240}},
	# Escalas servidas (4)
	{"id": "ships_1", "category": "ships", "stat": "ships_served", "threshold": 1.0, "title": "Primeira Escala", "description": "Atenda 1 navio.", "reward": {"kind": "xp", "amount": 40}},
	{"id": "ships_10", "category": "ships", "stat": "ships_served", "threshold": 10.0, "title": "Ritmo de Berço", "description": "Atenda 10 navios.", "reward": {"kind": "xp", "amount": 80}},
	{"id": "ships_50", "category": "ships", "stat": "ships_served", "threshold": 50.0, "title": "Cais Experiente", "description": "Atenda 50 navios.", "reward": {"kind": "xp", "amount": 40}},
	{"id": "ships_250", "category": "ships", "stat": "ships_served", "threshold": 250.0, "title": "Porto de Referência", "description": "Atenda 250 navios.", "reward": {"kind": "xp", "amount": 160}},
	# Estruturas (5)
	{"id": "structure_first_estivador", "category": "structures", "stat": "structure_estivador", "threshold": 1.0, "title": "Equipe a Bordo", "description": "Compre seu primeiro Estivador.", "reward": {"kind": "xp", "amount": 40}},
	{"id": "structures_total_10", "category": "structures", "stat": "structures_bought", "threshold": 10.0, "title": "Pátio em Formação", "description": "Compre 10 estruturas.", "reward": {"kind": "xp", "amount": 80}},
	{"id": "structure_any_25", "category": "structures", "stat": "highest_structure_count", "threshold": 25.0, "title": "Especialista", "description": "Possua 25 unidades de uma estrutura.", "reward": {"kind": "xp", "amount": 40}},
	{"id": "structures_all_15", "category": "structures", "stat": "distinct_structures", "threshold": 15.0, "title": "Porto Completo", "description": "Possua todos os 15 tipos de estrutura.", "reward": {"kind": "xp", "amount": 160}},
	{"id": "structures_total_100", "category": "structures", "stat": "structures_bought", "threshold": 100.0, "title": "Império de Aço", "description": "Compre 100 estruturas.", "reward": {"kind": "xp", "amount": 40}},
	# Carga (5)
	{"id": "cargo_first", "category": "cargo", "stat": "containers_moved", "threshold": 1.0, "title": "Caixa Destravada", "description": "Mova seu primeiro contêiner.", "reward": {"kind": "xp", "amount": 40}},
	{"id": "cargo_import_100", "category": "cargo", "stat": "imports_moved", "threshold": 100.0, "title": "Desembarque Seguro", "description": "Mova 100 importações.", "reward": {"kind": "xp", "amount": 80}},
	{"id": "cargo_export_100", "category": "cargo", "stat": "exports_moved", "threshold": 100.0, "title": "Embarque Seguro", "description": "Mova 100 exportações.", "reward": {"kind": "xp", "amount": 40}},
	{"id": "cargo_perfect_10", "category": "cargo", "stat": "perfect_calls", "threshold": 10.0, "title": "Escala Perfeita", "description": "Conclua 10 escalas perfeitas.", "reward": {"kind": "xp", "amount": 160}},
	{"id": "cargo_moves_1000", "category": "cargo", "stat": "containers_moved", "threshold": 1000.0, "title": "Mil em Movimento", "description": "Mova 1 mil contêineres.", "reward": {"kind": "xp", "amount": 40}},
	# Críticos (3)
	{"id": "critical_1", "category": "critical", "stat": "critical_hits", "threshold": 1.0, "title": "Sete da Sorte", "description": "Consiga 1 crítico.", "reward": {"kind": "xp", "amount": 40}},
	{"id": "critical_25", "category": "critical", "stat": "critical_hits", "threshold": 25.0, "title": "Gancho Preciso", "description": "Consiga 25 críticos.", "reward": {"kind": "xp", "amount": 80}},
	{"id": "critical_250", "category": "critical", "stat": "critical_hits", "threshold": 250.0, "title": "Mestre do Crítico", "description": "Consiga 250 críticos.", "reward": {"kind": "xp", "amount": 40}},
	# Eventos (3)
	{"id": "event_cat", "category": "events", "stat": "event_cat", "threshold": 1.0, "title": "Supervisor Felino", "description": "Conclua um evento de gato.", "reward": {"kind": "xp", "amount": 40}},
	{"id": "event_fog", "category": "events", "stat": "event_fog", "threshold": 1.0, "title": "Na Neblina", "description": "Conclua um evento de neblina.", "reward": {"kind": "xp", "amount": 80}},
	{"id": "event_golden_ship", "category": "events", "stat": "event_golden_ship", "threshold": 1.0, "title": "Navio Dourado", "description": "Atenda o navio dourado.", "requires_feature": "golden_ship", "reward": {"kind": "xp", "amount": 40}},
	# Rotas (2)
	{"id": "route_first", "category": "routes", "stat": "routes_completed", "threshold": 1.0, "title": "Primeiro Despacho", "description": "Conclua uma rota.", "requires_feature": "routes", "reward": {"kind": "xp", "amount": 40}},
	{"id": "routes_three", "category": "routes", "stat": "routes_completed", "threshold": 3.0, "title": "Triângulo Logístico", "description": "Conclua três rotas.", "requires_feature": "routes", "reward": {"kind": "xp", "amount": 80}},
	# Terrenos (3)
	{"id": "terrain_1", "category": "terrain", "stat": "terrain_owned", "threshold": 1.0, "title": "Pé no Chão", "description": "Desbloqueie 1 terreno.", "reward": {"kind": "xp", "amount": 40}},
	{"id": "terrain_4", "category": "terrain", "stat": "terrain_owned", "threshold": 4.0, "title": "Terra Recuperada", "description": "Desbloqueie 4 terrenos.", "reward": {"kind": "xp", "amount": 80}},
	{"id": "terrain_8", "category": "terrain", "stat": "terrain_owned", "threshold": 8.0, "title": "Frente Portuária", "description": "Desbloqueie 8 terrenos.", "reward": {"kind": "xp", "amount": 40}},
	# Coleção (2)
	{"id": "collection_1", "category": "collection", "stat": "collectibles_found", "threshold": 1.0, "title": "Achado no Cais", "description": "Encontre 1 colecionável.", "requires_feature": "collection", "reward": {"kind": "xp", "amount": 40}},
	{"id": "collection_10", "category": "collection", "stat": "collectibles_found", "threshold": 10.0, "title": "Curador Portuário", "description": "Encontre 10 colecionáveis.", "requires_feature": "collection", "reward": {"kind": "xp", "amount": 80}},
	# Contratos (2), prestígio (2), tutorial (1)
	{"id": "contracts_1", "category": "contracts", "stat": "contracts_completed", "threshold": 1.0, "title": "Contrato Assinado", "description": "Conclua 1 contrato.", "reward": {"kind": "xp", "amount": 40}},
	{"id": "contracts_10", "category": "contracts", "stat": "contracts_completed", "threshold": 10.0, "title": "Parceiro do Porto", "description": "Conclua 10 contratos.", "reward": {"kind": "xp", "amount": 160}},
	{"id": "prestige_1", "category": "prestige", "stat": "prestige_count", "threshold": 1.0, "title": "Novo Horizonte", "description": "Faça prestígio 1 vez.", "reward": {"kind": "xp", "amount": 40}},
	{"id": "prestige_3", "category": "prestige", "stat": "prestige_count", "threshold": 3.0, "title": "Dinastia Portuária", "description": "Faça prestígio 3 vezes.", "reward": {"kind": "xp", "amount": 160}},
	{"id": "tutorial_unskipped", "category": "tutorial", "stat": "tutorial_unskipped", "threshold": 1.0, "title": "Aprendiz de Cais", "description": "Conclua o tutorial sem pular.", "reward": {"kind": "xp", "amount": 40}},
]


static func get_item(id: StringName) -> Dictionary:
	for item in ITEMS:
		if StringName(item.get("id", "")) == id:
			return item.duplicate(true)
	return {}


static func is_valid() -> bool:
	var ids := {}
	var counts := {}
	for item in ITEMS:
		var id := StringName(item.get("id", ""))
		var category := StringName(item.get("category", ""))
		if id.is_empty() or category.is_empty() or ids.has(id) or String(item.get("stat", "")).is_empty():
			return false
		if float(item.get("threshold", 0.0)) <= 0.0 or not item.get("reward", {}) is Dictionary:
			return false
		ids[id] = true
		counts[category] = int(counts.get(category, 0)) + 1
	return ITEMS.size() == 38 and counts == {"teu": 6, "ships": 4, "structures": 5, "cargo": 5, "critical": 3, "events": 3, "routes": 2, "terrain": 3, "collection": 2, "contracts": 2, "prestige": 2, "tutorial": 1}
