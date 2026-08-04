class_name ShipCatalog
## GitHub's single-source visual fleet.
##
## Every call uses the same 66x232 `ship_top.png` and the same 24 physical bays.
## The three catalogue silhouettes vary only by scale, offset and livery, as they
## do on `origin/main`. Compatibility aliases keep newer routes and saved special
## calls readable without creating more hull textures.

const SOURCE_SPRITE := "ship_top"
const FIXED_BAY_ROWS := PortLayout.SHIP_BAY_ROWS

const SILHOUETTES: Array[Dictionary] = [
	{"id": "coastal_feeder", "title": "Feeder Costeiro", "capacity": 1200,
		"unlock_blocks": 0, "hull_scale": Vector2(0.90, 0.94),
		"hull_offset": Vector2(8.0, 3.0), "wake_scale": Vector2(0.88, 0.95)},
	{"id": "panamax", "title": "Panamax", "capacity": 4500,
		"unlock_blocks": 18, "hull_scale": Vector2.ONE,
		"hull_offset": Vector2.ZERO, "wake_scale": Vector2.ONE},
	{"id": "new_panamax", "title": "New Panamax", "capacity": 8000,
		"unlock_blocks": 21, "hull_scale": Vector2(1.08, 1.03),
		"hull_offset": Vector2(-8.0, -2.0), "wake_scale": Vector2(1.08, 1.02)},
]

const COMPATIBILITY_ALIASES := {
	"barge": {"base": "coastal_feeder", "title": "Barcaça Fluvial", "capacity": 480},
	"coastal": {"base": "coastal_feeder", "title": "Costeiro", "capacity": 2600},
	"handysize": {"base": "panamax", "title": "Handysize", "capacity": 3400},
	"ulcv": {"base": "new_panamax", "title": "ULCV", "capacity": 21000},
}

const PALETTES: Array[Dictionary] = [
	{"id": "harbor_blue", "hull": "#5c89a8", "wake": "#b9e5f2", "cargo": "#ffffff"},
	{"id": "rust_red", "hull": "#a95d51", "wake": "#d3e8ed", "cargo": "#fff3e0"},
	{"id": "evergreen", "hull": "#527b69", "wake": "#caedf0", "cargo": "#f0fff4"},
	{"id": "sunset_gold", "hull": "#ad8750", "wake": "#d7eef2", "cargo": "#fff8dc"},
]

const SPECIAL_PALETTE := {
	"id": "gala_black", "hull": "#2b2733", "wake": "#f0d68a", "cargo": "#ffe9a8",
}


static func unlocked_silhouettes(blocks: int) -> Array[Dictionary]:
	var allowed: Array[Dictionary] = []
	for silhouette in SILHOUETTES:
		if int(silhouette.get("unlock_blocks", 0)) <= blocks:
			allowed.append(silhouette)
	if allowed.is_empty():
		allowed.append(SILHOUETTES[0])
	return allowed


static func select_variant(variant_seed: int, call_index: int,
		history: Array[String] = [], blocks: int = 9999,
		lane_classes: Array[String] = []) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var blocked := ""
	if history.size() >= 2 and history[history.size() - 1] == history[history.size() - 2]:
		blocked = history[history.size() - 1]
	for silhouette in unlocked_silhouettes(blocks):
		if not lane_classes.is_empty() and not lane_classes.has(str(silhouette.id)):
			continue
		for palette in PALETTES:
			var variant_id := "%s:%s" % [String(silhouette.id), String(palette.id)]
			if variant_id != blocked:
				candidates.append(compose(silhouette, palette))
	if candidates.is_empty():
		# A compatibility-only class may be the sole class on an old lane. Map it
		# to its GitHub source silhouette rather than withholding the ship call.
		for requested in lane_classes:
			var silhouette := get_silhouette(StringName(requested))
			if silhouette.is_empty() \
					or int(silhouette.get("unlock_blocks", 0)) > blocks:
				continue
			for palette in PALETTES:
				candidates.append(compose(silhouette, palette))
	if candidates.is_empty():
		return {}
	return candidates[posmod(_roll(variant_seed, call_index), candidates.size())].duplicate(true)


static func compose(silhouette: Dictionary, palette: Dictionary) -> Dictionary:
	return {
		"id": "%s:%s" % [String(silhouette.id), String(palette.id)],
		"silhouette_id": silhouette.id, "palette_id": palette.id,
		"capacity": silhouette.capacity, "title": silhouette.title,
		"bay_rows": FIXED_BAY_ROWS, "sprite": SOURCE_SPRITE,
		"hull_scale": silhouette.get("hull_scale", Vector2.ONE),
		"hull_offset": silhouette.get("hull_offset", Vector2.ZERO),
		"wake_scale": silhouette.get("wake_scale", Vector2.ONE),
		"hull_color": palette.hull, "wake_color": palette.wake,
		"cargo_color": palette.cargo,
	}


static func special_variant(silhouette_id: StringName = &"panamax") -> Dictionary:
	var silhouette := get_silhouette(silhouette_id)
	if silhouette.is_empty():
		silhouette = SILHOUETTES[1]
	var variant := compose(silhouette, SPECIAL_PALETTE)
	variant["special"] = true
	return variant


static func get_silhouette(id: StringName) -> Dictionary:
	for silhouette in SILHOUETTES:
		if StringName(silhouette.get("id", "")) == id:
			return silhouette.duplicate(true)
	var key := String(id)
	if not COMPATIBILITY_ALIASES.has(key):
		return {}
	var alias: Dictionary = COMPATIBILITY_ALIASES[key]
	var restored := get_silhouette(StringName(alias.base))
	if restored.is_empty():
		return {}
	restored["id"] = key
	restored["title"] = alias.title
	restored["capacity"] = alias.capacity
	return restored


static func get_palette(id: StringName) -> Dictionary:
	for palette in PALETTES:
		if StringName(palette.get("id", "")) == id:
			return palette.duplicate(true)
	if StringName(SPECIAL_PALETTE.id) == id:
		return SPECIAL_PALETTE.duplicate(true)
	return {}


static func is_valid() -> bool:
	var silhouettes := {}
	var palettes := {}
	if not ResourceLoader.exists("res://assets/sprites/%s.png" % SOURCE_SPRITE):
		return false
	for silhouette in SILHOUETTES:
		var id := StringName(silhouette.get("id", ""))
		if id.is_empty() or silhouettes.has(id) \
				or int(silhouette.get("capacity", 0)) <= 0:
			return false
		silhouettes[id] = true
	for palette in PALETTES:
		var id := StringName(palette.get("id", ""))
		if id.is_empty() or palettes.has(id) \
				or String(palette.get("hull", "")).is_empty():
			return false
		palettes[id] = true
	return silhouettes.size() == 3 and palettes.size() == 4


static func _roll(variant_seed: int, call_index: int) -> int:
	var state: int = posmod(variant_seed, 2147483646) + 1
	for _step in range(posmod(call_index, 97) + 1):
		state = posmod(state * 48271, 2147483647)
	return state
