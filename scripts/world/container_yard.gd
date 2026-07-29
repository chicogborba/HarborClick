class_name ContainerYard
extends Node2D
## Physical, identity-preserving yard.  A reservation is capacity only; a box
## is not present until its flight commits, so interrupted animation is safe.

const SLOTS_PER_BLOCK := PortLayout.BLOCK_COLS * PortLayout.BLOCK_ROWS

var _levels: Array[int] = []
var _sprites: Dictionary = {} # slot -> Array[Node2D]
var _units: Dictionary = {} # slot -> Array[CargoUnit], bottom to top
var _reservations: Dictionary = {} # token -> {slot, level}
var _restored_manifest := false
var _shadow_tex: Texture2D = preload("res://assets/sprites/container_shadow.png")
var _containers: Texture2D = preload("res://assets/sprites/container_sheet.png")


func _ready() -> void:
	resize()


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


func slot_sector(slot: int) -> StringName:
	## Sector assignment is geometric, never relative to yard size: buying land
	## must not turn existing import stacks into exports.
	@warning_ignore("integer_division") var block := slot / SLOTS_PER_BLOCK
	var block_column := posmod(block, PortLayout.BLOCK_COLUMNS)
	return CargoUnit.EXPORT if block_column == PortLayout.BLOCK_COLUMNS - 1 else CargoUnit.IMPORT


func pick_landing_slot(sector: StringName = CargoUnit.IMPORT) -> Dictionary:
	## Full means full.  Previous code silently removed a random stack here,
	## which broke both manifests and player trust.
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
		if slot_sector(slot) == sector and not _slot_is_reserved(slot) and _levels[slot] == best:
			candidates.append(slot)
	if candidates.is_empty():
		return {}
	var chosen: int = candidates[randi() % candidates.size()]
	var token := CargoUnit.new_uid("yard")
	_levels[chosen] = best + 1
	_reservations[token] = {"slot": chosen, "level": best}
	return {"slot": chosen, "level": best, "pos": level_position(chosen, best), "token": token}


func release_landing(token: String) -> void:
	var landing: Dictionary = _reservations.get(token, {})
	if landing.is_empty():
		return
	var slot := int(landing.slot)
	_levels[slot] = maxi(_settled(slot), _levels[slot] - 1)
	_reservations.erase(token)


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


func take_exportable(import_uids: PackedStringArray = PackedStringArray()) -> Dictionary:
	return _take_top(-1, CargoUnit.EXPORT, import_uids)


func _take_top(preferred_slot: int, required_sector: StringName, import_uids: PackedStringArray) -> Dictionary:
	var choices: Array[int] = []
	if preferred_slot >= 0 and preferred_slot < _levels.size() and not _slot_is_reserved(preferred_slot) \
			and _settled(preferred_slot) > 0:
		choices.append(preferred_slot)
	else:
		var best := 0
		for slot in _levels.size():
			if not _slot_is_reserved(slot) and _settled(slot) > best:
				best = _settled(slot)
		for slot in _levels.size():
			if not _slot_is_reserved(slot) and _settled(slot) == best and best > 0:
				choices.append(slot)
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
		return {"slot": slot, "level": level, "pos": level_position(slot, level), "unit": unit,
			"color": unit.color}
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
	var slot := int(taken.slot)
	var level := _settled(slot)
	if slot < 0 or slot >= _levels.size() or level >= PortLayout.STACK_MAX:
		return false
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
	for reservation: Dictionary in _reservations.values():
		if int(reservation.get("slot", -1)) == slot:
			return true
	return false


func _reserve_exact(slot: int, level: int, prefix: String = "yard") -> String:
	if slot < 0 or slot >= _levels.size() or level < 0 or level >= PortLayout.STACK_MAX \
			or _slot_is_reserved(slot) or _levels[slot] != level:
		return ""
	var token := CargoUnit.new_uid(prefix)
	_reservations[token] = {"slot": slot, "level": level}
	_levels[slot] = level + 1
	return token


func ensure_export_manifest(p_call_id: String, count: int) -> Array[CargoUnit]:
	var seeded: Array[CargoUnit] = []
	var missing := maxi(0, count - sector_count(CargoUnit.EXPORT))
	for i in missing:
		var landing := pick_landing_slot(CargoUnit.EXPORT)
		if landing.is_empty():
			break
		var unit := CargoUnit.new("%s_e_%02d" % [
			p_call_id, count - missing + i], CargoUnit.EXPORT,
			randi() % 8, "", p_call_id)
		if place_unit(int(landing.slot), int(landing.level), unit, str(landing.token)):
			seeded.append(unit)
		else:
			release_landing(str(landing.token))
	return seeded


func sector_count(sector: StringName) -> int:
	var total := 0
	for stack: Array in _units.values():
		for unit: CargoUnit in stack:
			if unit.sector == sector:
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
	return {"version": 2, "slots": slots}


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
