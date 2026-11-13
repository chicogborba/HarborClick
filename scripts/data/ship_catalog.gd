class_name ShipCatalog
## Berth classes, and the bridge from them to the named fleet.
##
## `SILHOUETTES` are the three classes a berth and a lane reason about. Which
## ship of that class actually calls is `FleetDB`'s: `select_variant` rolls a
## named ship there and `compose_ship` turns it into what `Ship` wears. Every
## hull keeps the same 24 physical bays. `PALETTES`/`compose` remain for saves
## and tests written before the fleet — a hull saved as "class:palette" still
## restores — and compatibility aliases keep older routes readable.

const SOURCE_SPRITE := "ship_top"
const FIXED_BAY_ROWS := PortLayout.SHIP_BAY_ROWS

## Three native hulls drawn at 1:1 (`ship_top_feeder/panamax/new_panamax` in
## `tools/sprites/gen_ship.py`), all on the same 66x232 canvas with the same 24
## bays — the silhouettes differ in bow and stern shaping, never in a fractional
## scale that would distort the containers. `sprite`/`paint` name the textures.
const SILHOUETTES: Array[Dictionary] = [
	{"id": "coastal_feeder", "title": "Feeder Costeiro", "capacity": 1200,
		"unlock_blocks": 0, "sprite": "ship_top_feeder",
		"paint": "ship_paint_feeder", "hull_scale": Vector2.ONE,
		"hull_offset": Vector2.ZERO},
	{"id": "panamax", "title": "Panamax", "capacity": 4500,
		"unlock_blocks": 18, "sprite": "ship_top",
		"paint": "ship_paint", "hull_scale": Vector2.ONE,
		"hull_offset": Vector2.ZERO},
	{"id": "new_panamax", "title": "New Panamax", "capacity": 8000,
		"unlock_blocks": 21, "sprite": "ship_top_new_panamax",
		"paint": "ship_paint_new_panamax", "hull_scale": Vector2.ONE,
		"hull_offset": Vector2.ZERO},
]

const COMPATIBILITY_ALIASES := {
	"barge": {"base": "coastal_feeder", "title": "Barcaça Fluvial", "capacity": 480},
	"coastal": {"base": "coastal_feeder", "title": "Costeiro", "capacity": 2600},
	"handysize": {"base": "panamax", "title": "Handysize", "capacity": 3400},
	"ulcv": {"base": "new_panamax", "title": "ULCV", "capacity": 21000},
}

const HOME_PALETTES: Array[Dictionary] = [
	{"id": "harbor_blue", "hull": "#5c89a8", "wake": "#b9e5f2", "cargo": "#ffffff"},
	{"id": "rust_red", "hull": "#a95d51", "wake": "#d3e8ed", "cargo": "#fff3e0"},
	{"id": "evergreen", "hull": "#527b69", "wake": "#caedf0", "cargo": "#f0fff4"},
	{"id": "sunset_gold", "hull": "#ad8750", "wake": "#d7eef2", "cargo": "#fff8dc"},
]

## The liveries calling at the active port. Home's by default; a port with its
## own (`PortDB.palettes`) swaps them in through `apply_port`.
static var PALETTES: Array[Dictionary] = HOME_PALETTES

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
	## One named ship from `FleetDB`, weighted by rarity. The berth class still
	## decides who may call (unlocked by blocks, allowed by the lane); the fleet
	## decides which ship of that class it is. Deterministic per seed and call.
	var blocked := ""
	if history.size() >= 2 and history[history.size() - 1] == history[history.size() - 2]:
		blocked = history[history.size() - 1]
	var allowed := _allowed_classes(blocks, lane_classes)
	var candidates: Array[Dictionary] = []
	var weights: Array[int] = []
	for ship in FleetDB.SHIPS:
		if bool(ship.get("special", false)) or str(ship.id) == blocked:
			continue
		if not allowed.has(FleetDB.ship_class(ship)):
			continue
		var port := StringName(ship.get("port", &""))
		if port != &"" and port != PortDB.active:
			continue
		candidates.append(ship)
		weights.append(int(FleetDB.RARITY_WEIGHT.get(str(ship.rarity), 1)))
	if candidates.is_empty():
		return {}
	var total := 0
	for weight in weights:
		total += weight
	var pick := posmod(_roll(variant_seed, call_index), total)
	for index in candidates.size():
		pick -= weights[index]
		if pick < 0:
			return compose_ship(candidates[index])
	return compose_ship(candidates[candidates.size() - 1])


static func _allowed_classes(blocks: int, lane_classes: Array[String]) -> Dictionary:
	## Class ids a call may sail as. A lane may still name a compatibility alias
	## (`barge`, `ulcv`...) from an old save: it counts as the class it aliases.
	var unlocked := {}
	for silhouette in unlocked_silhouettes(blocks):
		unlocked[str(silhouette.id)] = true
	if lane_classes.is_empty():
		return unlocked
	var allowed := {}
	for requested in lane_classes:
		var base := requested
		if COMPATIBILITY_ALIASES.has(requested):
			base = str(COMPATIBILITY_ALIASES[requested].base)
		if unlocked.has(base):
			allowed[base] = true
	return allowed


static func compose_ship(ship: Dictionary, class_id: String = "") -> Dictionary:
	## The variant a `Ship` wears for one fleet entry. `class_id` overrides the
	## class (and so the hull) — only the charter does that, because it sails as
	## whatever class the charter booked.
	var hull := str(ship.hull)
	var klass := FleetDB.ship_class(ship)
	if not class_id.is_empty() and class_id != klass:
		klass = class_id
		hull = {"coastal_feeder": "feeder", "panamax": "panamax",
			"new_panamax": "new_panamax"}.get(class_id, hull)
	var silhouette := get_silhouette(StringName(klass))
	var suffix := "" if hull == "panamax" else "_" + hull
	var special := bool(ship.get("special", false))
	return {
		"id": str(ship.id), "fleet_id": str(ship.id), "name": str(ship.name),
		"silhouette_id": klass,
		"palette_id": str(SPECIAL_PALETTE.id) if special else str(ship.id),
		"capacity": int(ship.capacity),
		"title": str(silhouette.get("title", FleetDB.hull_type(ship))),
		"bay_rows": FIXED_BAY_ROWS,
		"hull": hull,
		"sprite": "ship_top" + suffix, "paint": "ship_paint" + suffix,
		"trim_sprite": "ship_trim_" + hull, "trim_frame": FleetDB.trim_index(ship),
		"hull_scale": Vector2.ONE, "hull_offset": Vector2.ZERO,
		"hull_color": str(ship.hull_color), "trim_color": str(ship.trim_color),
		"house_color": str(ship.house_color), "flag": str(ship.flag),
		"wake_color": str(SPECIAL_PALETTE.wake) if special else "#d0eaf0",
		"cargo_color": "#ffffff", "special": special, "legacy": str(ship.get("legacy", "")),
	}


static func restore_ship(raw: Dictionary) -> Dictionary:
	## A saved fleet variant, rebuilt from the catalogue rather than trusted.
	var ship := FleetDB.get_ship(str(raw.get("fleet_id", "")))
	if ship.is_empty():
		return {}
	var variant := compose_ship(ship, str(raw.get("silhouette_id", "")))
	if bool(raw.get("special", false)):
		variant["special"] = true
	return variant


static func compose(silhouette: Dictionary, palette: Dictionary) -> Dictionary:
	return {
		"id": "%s:%s" % [String(silhouette.id), String(palette.id)],
		"silhouette_id": silhouette.id, "palette_id": palette.id,
		"capacity": silhouette.capacity, "title": silhouette.title,
		"bay_rows": FIXED_BAY_ROWS,
		"sprite": silhouette.get("sprite", SOURCE_SPRITE),
		"paint": silhouette.get("paint", "ship_paint"),
		"hull_scale": silhouette.get("hull_scale", Vector2.ONE),
		"hull_offset": silhouette.get("hull_offset", Vector2.ZERO),
		"hull_color": palette.hull, "wake_color": palette.wake,
		"cargo_color": palette.cargo,
	}


static func special_variant(silhouette_id: StringName = &"panamax") -> Dictionary:
	## The charter's own ship, sailing as the class the charter booked.
	var class_id := String(silhouette_id)
	if get_silhouette(silhouette_id).is_empty():
		class_id = "panamax"
	var alias: Dictionary = COMPATIBILITY_ALIASES.get(class_id, {})
	if not alias.is_empty():
		class_id = str(alias.base)
	var variant := compose_ship(FleetDB.special_ship(), class_id)
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


static func apply_port() -> void:
	var local := PortDB.palettes()
	PALETTES = local if not local.is_empty() else HOME_PALETTES


static func get_palette(id: StringName) -> Dictionary:
	for palette in PALETTES:
		if StringName(palette.get("id", "")) == id:
			return palette.duplicate(true)
	# A hull saved under another port's livery, or under home's while abroad.
	for palette in HOME_PALETTES + PortDB.all_palettes():
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
	return silhouettes.size() == 3 and palettes.size() == 4 and FleetDB.is_valid()


static func _roll(variant_seed: int, call_index: int) -> int:
	var state: int = posmod(variant_seed, 2147483646) + 1
	for _step in range(posmod(call_index, 97) + 1):
		state = posmod(state * 48271, 2147483647)
	return state
