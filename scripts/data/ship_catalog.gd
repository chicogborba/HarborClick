class_name ShipCatalog
## The fleet: four silhouettes and four liveries, so a call is recognisably a
## different vessel from the last one.
##
## A class does *not* change how many boxes a call moves. That was tried and
## looked wrong — a shorter hull with the same beam reads as a squashed boat,
## not a smaller one — so the berth grid stays the berth's and a class is a
## silhouette, a beam, a livery and a name.
##
## `unlock_blocks` still gates which classes call here, so a first-hour port
## sees feeders and the first Panamax alongside is something it earned.

const SILHOUETTES: Array[Dictionary] = [
	{"id": "coastal_feeder", "title": "Feeder Costeiro", "capacity": 1200,
		"unlock_blocks": 0,
		"hull_scale": Vector2(0.90, 0.94), "hull_offset": Vector2(8.0, 3.0), "wake_scale": Vector2(0.88, 0.95)},
	{"id": "coastal", "title": "Costeiro", "capacity": 2600,
		"unlock_blocks": 12,
		"hull_scale": Vector2(0.95, 0.97), "hull_offset": Vector2(4.0, 1.0), "wake_scale": Vector2(0.94, 0.98)},
	{"id": "panamax", "title": "Panamax", "capacity": 4500,
		"unlock_blocks": 18,
		"hull_scale": Vector2(1.00, 1.00), "hull_offset": Vector2.ZERO, "wake_scale": Vector2.ONE},
	{"id": "new_panamax", "title": "New Panamax", "capacity": 8000,
		"unlock_blocks": 21,
		"hull_scale": Vector2(1.08, 1.03), "hull_offset": Vector2(-8.0, -2.0), "wake_scale": Vector2(1.08, 1.02)},
]

const PALETTES: Array[Dictionary] = [
	{"id": "harbor_blue", "hull": "#5c89a8", "wake": "#b9e5f2", "cargo": "#ffffff"},
	{"id": "rust_red", "hull": "#a95d51", "wake": "#d3e8ed", "cargo": "#fff3e0"},
	{"id": "evergreen", "hull": "#527b69", "wake": "#caedf0", "cargo": "#f0fff4"},
	{"id": "sunset_gold", "hull": "#ad8750", "wake": "#d7eef2", "cargo": "#fff8dc"},
]


static func unlocked_silhouettes(blocks: int) -> Array[Dictionary]:
	## Everything the terminal is currently big enough to handle. Always at
	## least the feeder, so a brand new port still gets a ship.
	var allowed: Array[Dictionary] = []
	for silhouette in SILHOUETTES:
		if int(silhouette.get("unlock_blocks", 0)) <= blocks:
			allowed.append(silhouette)
	if allowed.is_empty():
		allowed.append(SILHOUETTES[0])
	return allowed


static func select_variant(variant_seed: int, call_index: int,
		history: Array[String] = [], blocks: int = 9999) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var blocked := ""
	if history.size() >= 2 and history[history.size() - 1] == history[history.size() - 2]:
		blocked = history[history.size() - 1]
	for silhouette in unlocked_silhouettes(blocks):
		for palette in PALETTES:
			var variant_id := "%s:%s" % [String(silhouette.id), String(palette.id)]
			if variant_id != blocked:
				candidates.append({"id": variant_id, "silhouette_id": silhouette.id, "palette_id": palette.id,
					"capacity": silhouette.capacity, "title": silhouette.title,
					"hull_scale": silhouette.hull_scale,
					"hull_offset": silhouette.hull_offset, "wake_scale": silhouette.wake_scale,
					"hull_color": palette.hull, "wake_color": palette.wake, "cargo_color": palette.cargo})
	if candidates.is_empty():
		return {}
	return candidates[posmod(_roll(variant_seed, call_index), candidates.size())].duplicate(true)


static func get_silhouette(id: StringName) -> Dictionary:
	for silhouette in SILHOUETTES:
		if StringName(silhouette.get("id", "")) == id:
			return silhouette.duplicate(true)
	return {}


static func get_palette(id: StringName) -> Dictionary:
	for palette in PALETTES:
		if StringName(palette.get("id", "")) == id:
			return palette.duplicate(true)
	return {}


static func is_valid() -> bool:
	var silhouettes := {}
	var palettes := {}
	for silhouette in SILHOUETTES:
		var id := StringName(silhouette.get("id", ""))
		if id.is_empty() or silhouettes.has(id) or int(silhouette.get("capacity", 0)) <= 0:
			return false
		silhouettes[id] = true
	for palette in PALETTES:
		var id := StringName(palette.get("id", ""))
		if id.is_empty() or palettes.has(id) or String(palette.get("hull", "")).is_empty():
			return false
		palettes[id] = true
	return silhouettes.size() >= 3 and palettes.size() >= 4


static func _roll(variant_seed: int, call_index: int) -> int:
	var state: int = posmod(variant_seed, 2147483646) + 1
	for _step in range(posmod(call_index, 97) + 1):
		state = posmod(state * 48271, 2147483647)
	return state
