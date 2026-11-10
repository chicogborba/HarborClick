class_name ContainerYard
extends Node2D
## Physical, identity-preserving yard.  A reservation is capacity only; a box
## is not present until its flight commits, so interrupted animation is safe.

const SLOTS_PER_BLOCK := PortLayout.BLOCK_COLS * PortLayout.BLOCK_ROWS
## One complete berth exchange is already ashore before the player's first
## shift. These are road units from the city, not a runtime refill: this
## initializer is called only for a new profile or an explicit save wipe.
const INITIAL_EXPORT_STOCK := PortLayout.SHIP_BAY_COLS * PortLayout.SHIP_BAY_ROWS
const INITIAL_ORIGIN_UID := "cidade"
const INITIAL_COLORS := [2, 4, 1, 7, 0, 5, 3, 6]

var _levels: Array[int] = []
var _sprites: Dictionary = {} # slot -> Array[Node2D]
var _units: Dictionary = {} # slot -> Array[CargoUnit], bottom to top
var _reservations: Dictionary = {} # token -> {slot, level}
## How many reservations each slot carries. `_slot_is_reserved` is asked once per
## slot inside loops that already walk every slot, so scanning the reservation
## list there made those loops O(slots x reservations) — with a bought-out port
## that is the single most expensive thing in the frame.
var _reserved_slots: Dictionary = {} # slot -> count
var _restored_manifest := false
var _shadow_tex: Texture2D = preload("res://assets/sprites/container_shadow.png")
var _containers: Texture2D = preload("res://assets/sprites/container_sheet.png")


func _ready() -> void:
	resize()


func seed_new() -> void:
	## Reset/new-profile seed. The inaugural city convoy is considered to have
	## reached the terminal before play begins, so the first vessel can exchange
	## a full manifest without any box appearing during the live simulation.
	_clear_visuals()
	resize()
	for slot in _levels.size():
		_levels[slot] = 0
	_restored_manifest = false
	_seed_city_exports(INITIAL_EXPORT_STOCK, "road_inaugural")


func _seed_city_exports(count: int, uid_prefix: String) -> void:
	## Save initialization/migration only. Live traffic must use a CargoUnit
	## already carried by a visible road vehicle.
	for index in maxi(0, count):
		var landing := pick_landing_slot(CargoUnit.EXPORT)
		if landing.is_empty():
			push_error("Initial road manifest exceeds EXPORT yard capacity")
			break
		var unit := CargoUnit.new(
			CargoUnit.new_uid(uid_prefix),
			CargoUnit.EXPORT,
			INITIAL_COLORS[index % INITIAL_COLORS.size()],
			INITIAL_ORIGIN_UID)
		if not place_unit(
				int(landing.slot), int(landing.level), unit, str(landing.token)):
			release_landing(str(landing.token))
			push_error("Initial road manifest could not commit its reserved landing")
			break


func resize() -> void:
	var wanted := PortLayout.block_count() * SLOTS_PER_BLOCK
	while _levels.size() < wanted:
		_levels.append(0)
	while _levels.size() > wanted:
		# Land only grows in normal play.  Keeping occupied tail slots avoids a
		# destructive resize if a restored save is temporarily smaller.
		if _settled(_levels.size() - 1) > 0:
			break
		_levels.pop_back()


func total_slots() -> int:
	return _levels.size()


func slot_position(index: int) -> Vector2:
	@warning_ignore("integer_division") var block := index / SLOTS_PER_BLOCK
	var inner := index % SLOTS_PER_BLOCK
	var col := inner % PortLayout.BLOCK_COLS
	@warning_ignore("integer_division") var row := inner / PortLayout.BLOCK_COLS
	return PortLayout.block_origin(block) + Vector2(col * PortLayout.BOX_W,
		row * PortLayout.BOX_H)


func level_position(index: int, level: int) -> Vector2:
	return slot_position(index) - Vector2(0, level * PortLayout.BOX_LIFT)


func slot_block(slot: int) -> int:
	@warning_ignore("integer_division") var block := slot / SLOTS_PER_BLOCK
	return block


func slot_role(slot: int) -> StringName:
	## Which yard this slot belongs to. Geometric, never relative to yard size:
	## buying land must not turn existing import stacks into exports.
	return PortLayout.block_role(slot_block(slot))


func slot_sector(slot: int) -> StringName:
	## The sector a box landing here is filed under. Buffer takes either, and
	## files as import, because a box with nowhere else to go is a box waiting on
	## the road rather than one promised to a hull.
	return CargoUnit.EXPORT if slot_role(slot) == PortLayout.ROLE_EXPORT \
		else CargoUnit.IMPORT


func pick_landing_slot(sector: StringName = CargoUnit.IMPORT) -> Dictionary:
	## Where a box of this sector is put down.
	##
	## Full means full, and deliberately so on both counts. Earlier code silently
	## removed a random stack to make room, which broke manifests and player
	## trust. Later work tried the opposite — overflowing an arriving import into
	## the export stacks — and that is worse in a quieter way: it removes the one
	## piece of pressure that makes buying land mean anything, and it puts a box
	## bound for the gate in the yard a crane loads from, which is exactly the
	## incoherent shuffling the yards exist to stop.
	##
	## Landing stays inside the sector's own yard. Which *stack* inside it is the
	## shallowest, so blocks fill evenly rather than growing one tower.
	if _levels.is_empty():
		return {}
	var best := PortLayout.STACK_MAX + 1
	for slot in _levels.size():
		if slot_sector(slot) != sector or _slot_is_reserved(slot):
			continue
		var used := _levels[slot]
		if used < PortLayout.STACK_MAX:
			best = mini(best, used)
	if best > PortLayout.STACK_MAX:
		return {}
	var candidates: Array[int] = []
	for slot in _levels.size():
		if slot_sector(slot) == sector and not _slot_is_reserved(slot) \
				and _levels[slot] == best:
			candidates.append(slot)
	if candidates.is_empty():
		return {}
	var chosen: int = candidates[randi() % candidates.size()]
	var token := CargoUnit.new_uid("yard")
	_levels[chosen] = best + 1
	_reservations[token] = {"slot": chosen, "level": best}
	_hold_slot(chosen)
	return {"slot": chosen, "level": best,
		"pos": to_global(level_position(chosen, best) + BOX_VISUAL_CENTRE),
		"token": token}


func release_landing(token: String) -> void:
	var landing: Dictionary = _reservations.get(token, {})
	if landing.is_empty():
		return
	var slot := int(landing.slot)
	_levels[slot] = maxi(_settled(slot), _levels[slot] - 1)
	_reservations.erase(token)
	_free_slot(slot)


func place_unit(slot: int, level: int, unit: CargoUnit, token: String = "") -> bool:
	if unit == null or slot < 0 or slot >= _levels.size() or level < 0 or level >= PortLayout.STACK_MAX:
		return false
	var reservation: Dictionary = _reservations.get(token, {})
	if token.is_empty() or reservation.is_empty() or int(reservation.get("slot", -1)) != slot \
			or int(reservation.get("level", -1)) != level:
		return false
	var stack: Array = _units.get(slot, [])
	# A delayed landing can only occupy the reserved top; do not overwrite a
	# real unit if the world changed beneath it.
	if stack.size() != level:
		return false
	_reservations.erase(token)
	_free_slot(slot)
	stack.append(unit)
	_units[slot] = stack
	_levels[slot] = maxi(_levels[slot], stack.size())
	_materialize(slot, level, unit.color)
	return true


func place(slot: int, level: int, color_idx: int) -> bool:
	## Legacy API used by dev probes and autonomous traffic.
	if slot < 0 or slot >= _levels.size() or level < 0 or level >= PortLayout.STACK_MAX \
			or _slot_is_reserved(slot) or _levels[slot] != level:
		return false
	var token := _reserve_exact(slot, level, "legacy")
	return place_unit(slot, level, CargoUnit.new("", slot_sector(slot), color_idx), token)


func _materialize(slot: int, level: int, color_idx: int) -> void:
	var root := Node2D.new()
	root.position = slot_position(slot)
	add_child(root)
	var lift := -level * PortLayout.BOX_LIFT
	if level > 0:
		var shadow := Sprite2D.new()
		shadow.texture = _shadow_tex
		shadow.centered = false
		shadow.position = Vector2(0, lift + PortLayout.BOX_LIFT - 1)
		shadow.modulate.a = 0.5
		root.add_child(shadow)
	else:
		# The bottom box casts onto the pavement too. Without it a full stack has
		# depth and a single box looks painted on the ground.
		var contact := Sprite2D.new()
		contact.texture = _shadow_tex
		contact.centered = false
		contact.position = Vector2(1, 2)
		contact.modulate = Color(0.06, 0.07, 0.11, 0.30)
		root.add_child(contact)
	var box := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = _containers
	at.region = Rect2(posmod(color_idx, 8) * 24, 0, 24, 13)
	box.texture = at
	box.centered = false
	box.position = Vector2(0, lift)
	root.add_child(box)
	if not _sprites.has(slot):
		_sprites[slot] = []
	_sprites[slot].append(root)


func take_top(preferred_slot: int = -1) -> Dictionary:
	return _take_top(preferred_slot, &"", PackedStringArray())


func take_import(preferred_slot: int = -1) -> Dictionary:
	return _take_top(preferred_slot, CargoUnit.IMPORT, PackedStringArray())


func road_pickup_slot(priority_uids: PackedStringArray = PackedStringArray(),
		excluded_uids: PackedStringArray = PackedStringArray(),
		minimum_exportable: int = 0) -> int:
	## Prefer boxes discharged by the vessel currently alongside: that hull
	## cannot reload them anyway. Once those are gone, protect one complete
	## outbound manifest so road traffic can never strand the next ship.
	## Walked in one pass per rule rather than by building and sorting every
	## occupied slot: this is asked once per truck per frame by the interaction
	## outlines, and sorting six hundred slots for it is most of a frame.
	var best_priority := -1
	var best_priority_height := 0
	var best_import := -1
	var best_import_height := 0
	var best_any := -1
	var best_any_height := 0
	for slot in _levels.size():
		if _slot_is_reserved(slot):
			continue
		var stack: Array = _units.get(slot, [])
		if stack.is_empty():
			continue
		var unit: CargoUnit = stack.back()
		if excluded_uids.has(unit.uid):
			continue
		var height := stack.size()
		if priority_uids.has(unit.uid):
			if height > best_priority_height:
				best_priority_height = height
				best_priority = slot
			continue
		# Landward first: a box in the import yard is standing beside the gate
		# precisely because a lorry is what takes it away.
		if slot_role(slot) == PortLayout.ROLE_IMPORT and height > best_import_height:
			best_import_height = height
			best_import = slot
		if height > best_any_height:
			best_any_height = height
			best_any = slot
	if best_priority >= 0:
		return best_priority
	if count_excluding(priority_uids) <= minimum_exportable:
		return -1
	return best_import if best_import >= 0 else best_any


func take_for_road(excluded_uids: PackedStringArray = PackedStringArray(),
		priority_uids: PackedStringArray = PackedStringArray(),
		minimum_exportable: int = 0) -> Dictionary:
	## What goes home by truck. A box a ship discharged is the whole reason a
	## truck comes here, but a complete shipload is protected from collection.
	## Exclusions stop a lorry dropping a box and immediately taking that exact
	## same identity home.
	var slot := road_pickup_slot(priority_uids, excluded_uids,
		minimum_exportable)
	return {} if slot < 0 else _take_top(slot, &"", excluded_uids)


func export_pickup_slot(import_uids: PackedStringArray) -> int:
	## Which stack a hull is loaded from, and the other half of the terminal's
	## sense of direction.
	##
	## This used to be "whatever is tallest", which is why the machines looked
	## like they were shuffling boxes: a load could reach into the import yard
	## right beside the gate and drive the box the whole width of the terminal
	## past the export stacks standing under the crane. The seaward yard is asked
	## first now, then the buffer, then — only because a berth must never stall —
	## the import yard.
	for role: StringName in [PortLayout.ROLE_EXPORT, PortLayout.ROLE_BUFFER,
			PortLayout.ROLE_IMPORT]:
		var best := -1
		var best_height := 0
		for slot in _levels.size():
			if slot_role(slot) != role or _slot_is_reserved(slot):
				continue
			var stack: Array = _units.get(slot, [])
			if stack.is_empty() or import_uids.has((stack.back() as CargoUnit).uid):
				continue
			if stack.size() > best_height:
				best_height = stack.size()
				best = slot
		if best >= 0:
			return best
	return -1


func take_exportable(import_uids: PackedStringArray = PackedStringArray()) -> Dictionary:
	## Anything standing in the yard can be shipped out, except the boxes this
	## same call just landed.
	##
	## Sectors used to gate this, so a box that arrived by sea was stuck in the
	## import area forever and the export area could run dry while the yard was
	## full — the berth would then sit waiting for cargo that was ten metres
	## away. A real terminal tranships: what came in on one hull leaves on the
	## next.
	##
	## Which stack it comes off, though, is where the terminal's sense of
	## direction lives. This used to be "whatever is tallest", which is why the
	## machines looked like they were shuffling boxes about: a load could reach
	## into the import yard beside the gate and drive the box the whole width of
	## the terminal, straight past the export stacks standing under the crane.
	## The seaward yard is asked first now, then the buffer, then — only because
	## a berth must never stall — the landward one.
	return _take_top(export_pickup_slot(import_uids), &"", import_uids)


func can_accept(sector: StringName = CargoUnit.IMPORT) -> bool:
	## Read-only partner to `pick_landing_slot`, used by hover affordances.
	for slot in _levels.size():
		if slot_sector(slot) == sector and not _slot_is_reserved(slot) \
				and _levels[slot] < PortLayout.STACK_MAX:
			return true
	return false


func has_exportable(excluded_uids: PackedStringArray = PackedStringArray()) -> bool:
	return _has_top(&"", excluded_uids)


func has_for_road(excluded_uids: PackedStringArray = PackedStringArray(),
		priority_uids: PackedStringArray = PackedStringArray(),
		minimum_exportable: int = 0) -> bool:
	return road_pickup_slot(priority_uids, excluded_uids,
		minimum_exportable) >= 0


func _has_top(required_sector: StringName,
		excluded_uids: PackedStringArray) -> bool:
	for slot in _levels.size():
		if _slot_is_reserved(slot):
			continue
		var stack: Array = _units.get(slot, [])
		if stack.is_empty():
			continue
		var unit: CargoUnit = stack.back()
		if required_sector != &"" and unit.sector != required_sector:
			continue
		if not excluded_uids.has(unit.uid):
			return true
	return false


func _take_top(preferred_slot: int, required_sector: StringName, import_uids: PackedStringArray) -> Dictionary:
	var choices: Array[int] = []
	if preferred_slot >= 0 and preferred_slot < _levels.size() and not _slot_is_reserved(preferred_slot) \
			and _settled(preferred_slot) > 0:
		choices.append(preferred_slot)
	else:
		## Tallest stack first, then down through the rest. Only the tallest
		## used to be considered, which was fine until a caller could refuse
		## what was on top of it — a sector it will not take, or a box the same
		## ship call has just landed — and then the yard reported itself empty
		## with a hundred boxes standing in it.
		for slot in _levels.size():
			if not _slot_is_reserved(slot) and _settled(slot) > 0:
				choices.append(slot)
		choices.sort_custom(func(a: int, b: int) -> bool:
			return _settled(a) > _settled(b))
	for slot in choices:
		var stack: Array = _units.get(slot, [])
		if stack.is_empty():
			continue
		var unit: CargoUnit = stack.back()
		if required_sector != &"" and unit.sector != required_sector:
			continue
		if import_uids.has(unit.uid):
			continue
		var sprites: Array = _sprites.get(slot, [])
		var node: Node2D = sprites.pop_back() if not sprites.is_empty() else null
		if node != null:
			node.queue_free()
		stack.pop_back()
		_units[slot] = stack
		_sprites[slot] = sprites
		var level := stack.size()
		_levels[slot] = maxi(level, _levels[slot] - 1)
		return {"slot": slot, "level": level,
			"pos": to_global(level_position(slot, level) + BOX_VISUAL_CENTRE),
			"unit": unit, "color": unit.color}
	return {}


func reserve_taken_return(taken: Dictionary) -> String:
	## Haulers remove a top IMPORT visually, but reserve its exact former level
	## until they clear the gate. Ship discharge therefore cannot consume the
	## rollback capacity.
	if taken.is_empty() or not taken.has("unit"):
		return ""
	return _reserve_exact(
		int(taken.get("slot", -1)), int(taken.get("level", -1)),
		"haul_return")


func restore_reserved_taken(taken: Dictionary, token: String) -> bool:
	if taken.is_empty() or not taken.get("unit") is CargoUnit:
		return false
	return place_unit(
		int(taken.get("slot", -1)), int(taken.get("level", -1)),
		taken.unit, token)


func restore_taken(taken: Dictionary) -> bool:
	if taken.is_empty() or not taken.has("unit"):
		return false
	# A rolled-back transfer goes back to its exact former berth first; only
	# if that spot was claimed meanwhile does it fall back to the shallowest
	# stack in its sector.
	var slot := int(taken.get("slot", -1))
	var level := int(taken.get("level", -1))
	if slot >= 0 and slot < _levels.size() and level >= 0 \
			and level < PortLayout.STACK_MAX:
		var token := _reserve_exact(slot, level, "restore")
		if not token.is_empty() and place_unit(slot, level, taken.unit, token):
			return true
	var sector: StringName = taken.unit.sector
	var landing := pick_landing_slot(sector)
	if not landing.is_empty():
		return place_unit(
			int(landing.slot), int(landing.level), taken.unit,
			str(landing.token))
	return false


func _settled(slot: int) -> int:
	return (_units.get(slot, []) as Array).size()


func _slot_is_reserved(slot: int) -> bool:
	return _reserved_slots.has(slot)


func _hold_slot(slot: int) -> void:
	_reserved_slots[slot] = int(_reserved_slots.get(slot, 0)) + 1


func _free_slot(slot: int) -> void:
	var held := int(_reserved_slots.get(slot, 0)) - 1
	if held > 0:
		_reserved_slots[slot] = held
	else:
		_reserved_slots.erase(slot)


func _reserve_exact(slot: int, level: int, prefix: String = "yard") -> String:
	if slot < 0 or slot >= _levels.size() or level < 0 or level >= PortLayout.STACK_MAX \
			or _slot_is_reserved(slot) or _levels[slot] != level:
		return ""
	var token := CargoUnit.new_uid(prefix)
	_reservations[token] = {"slot": slot, "level": level}
	_hold_slot(slot)
	_levels[slot] = level + 1
	return token


func sector_count(sector: StringName) -> int:
	var total := 0
	for stack: Array in _units.values():
		for unit: CargoUnit in stack:
			if unit.sector == sector:
				total += 1
	return total


func unit_count() -> int:
	var total := 0
	for stack: Array in _units.values():
		total += stack.size()
	return total


func count_excluding(excluded_uids: PackedStringArray) -> int:
	var total := 0
	for stack: Array in _units.values():
		for unit: CargoUnit in stack:
			if not excluded_uids.has(unit.uid):
				total += 1
	return total


func has_boxes() -> bool:
	for slot in _levels.size():
		if _settled(slot) > 0:
			return true
	return false


func has_sector(sector: StringName) -> bool:
	for slot in _levels.size():
		for unit: CargoUnit in _units.get(slot, []):
			if unit.sector == sector:
				return true
	return false


func block_top_color(block_index: int) -> int:
	## The colour of some box currently standing in a block, or -1 when the
	## block is empty. Gantries use it so the container they are seen shuttling
	## is a container that is really there.
	if block_index < 0:
		return -1
	var first := block_index * SLOTS_PER_BLOCK
	for slot in range(first, mini(first + SLOTS_PER_BLOCK, _levels.size())):
		var stack: Array = _units.get(slot, [])
		if not stack.is_empty():
			return (stack[stack.size() - 1] as CargoUnit).color
	return -1


func top_uid(slot: int) -> String:
	## The identity currently on top of this stack, or "" for an empty slot. The
	## task board needs it to tell `road_pickup_slot` which box is already
	## somebody else's job.
	if slot < 0 or slot >= _levels.size():
		return ""
	var stack: Array = _units.get(slot, [])
	return "" if stack.is_empty() else (stack.back() as CargoUnit).uid


func fullest_slot(sector: StringName = &"") -> int:
	var best := -1
	var best_level := 0
	for slot in _levels.size():
		if sector != &"" and slot_sector(slot) != sector:
			continue
		if _settled(slot) > best_level:
			best_level = _settled(slot)
			best = slot
	return best


func fill_ratio() -> float:
	if _levels.is_empty():
		return 0.0
	var total := 0
	for slot in _levels.size():
		total += _settled(slot)
	return float(total) / float(_levels.size() * PortLayout.STACK_MAX)


func snapshot() -> Dictionary:
	var slots: Array = []
	for slot in _levels.size():
		var units: Array = []
		for unit: CargoUnit in _units.get(slot, []):
			units.append(unit.snapshot())
		slots.append(units)
	return {"version": 3, "slots": slots}


func restore_saved(data: Dictionary) -> void:
	## v3 introduces the non-deficit road contract. A v2 profile may already
	## have been drained by the old 1-in/2-out rule, so it receives one
	## traceable city retrofit before the scene becomes visible. From v3 on,
	## even an intentionally empty saved yard remains empty.
	restore(data)
	if int(data.get("version", 1)) < 3:
		var missing := maxi(0,
			INITIAL_EXPORT_STOCK - sector_count(CargoUnit.EXPORT))
		_seed_city_exports(missing, "road_v3_retrofit")


func restore(data: Dictionary) -> void:
	_clear_visuals()
	resize()
	for slot in _levels.size():
		_levels[slot] = 0
	var saved_slots: Array = data.get("slots", [])
	for slot in mini(_levels.size(), saved_slots.size()):
		var stack: Array = saved_slots[slot]
		for raw in stack:
			if raw is Dictionary and _settled(slot) < PortLayout.STACK_MAX:
				var level := _settled(slot)
				var token := _reserve_exact(slot, level, "restore")
				if not token.is_empty():
					place_unit(slot, level, CargoUnit.from_snapshot(raw), token)
	_restored_manifest = true


func _clear_visuals() -> void:
	for nodes: Array in _sprites.values():
		for node: Node2D in nodes:
			node.queue_free()
	_sprites.clear()
	_units.clear()
	_reservations.clear()
	_reserved_slots.clear()


func to_save() -> Array:
	## Kept as the legacy compact representation until SaveManager is migrated.
	return _levels.duplicate()


func manifest_save() -> Dictionary:
	return snapshot()


func from_save(data: Array) -> void:
	# Main still restores the old compact `yard` section.  If the new manifest
	# section already restored, preserve its UIDs/colors instead of flattening it.
	if _restored_manifest:
		return
	_clear_visuals()
	resize()
	for slot in _levels.size():
		_levels[slot] = 0
	for slot in mini(data.size(), _levels.size()):
		for level in clampi(int(data[slot]), 0, PortLayout.STACK_MAX):
			place(slot, level, randi() % 8)
const BOX_VISUAL_CENTRE := Vector2(12.0, 6.5)
