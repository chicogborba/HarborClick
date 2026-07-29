class_name ContainerYard
extends Node2D
## The stacking yard. Boxes land here from the ship and pile up block by block
## until the whole terminal looks gloriously overloaded.

const SLOTS_PER_BLOCK := PortLayout.BLOCK_COLS * PortLayout.BLOCK_ROWS

var _levels: Array[int] = []      # one entry per slot, 0..STACK_MAX
var _sprites: Dictionary = {}     # slot index -> Array[Node2D]
var _shadow_tex: Texture2D = preload("res://assets/sprites/container_shadow.png")
var _containers: Texture2D = preload("res://assets/sprites/container_sheet.png")


func _ready() -> void:
	resize()


func resize() -> void:
	var wanted := PortLayout.block_count() * SLOTS_PER_BLOCK
	while _levels.size() < wanted:
		_levels.append(0)
	while _levels.size() > wanted:
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


func pick_landing_slot() -> Dictionary:
	## Reserves the least-loaded slot so boxes already in flight cannot collide
	## with each other. The caller must follow up with `place()`.
	## Returns {slot, level, pos}; recycles a random column when everything is
	## full (those boxes "left by truck").
	var best := PortLayout.STACK_MAX
	for lv in _levels:
		best = mini(best, lv)
	if best >= PortLayout.STACK_MAX:
		_clear_slot(randi() % _levels.size())
		best = 0
	var candidates: Array[int] = []
	for i in _levels.size():
		if _levels[i] == best:
			candidates.append(i)
	var slot: int = candidates[randi() % candidates.size()]
	_levels[slot] = best + 1          # reserve it now
	return {"slot": slot, "level": best, "pos": level_position(slot, best)}


func place(slot: int, level: int, color_idx: int) -> void:
	## Materialises a box in a slot reserved by `pick_landing_slot()`.
	if slot < 0 or slot >= _levels.size():
		return
	if level < 0 or level >= PortLayout.STACK_MAX:
		return
	# The node sits at the stack's ground position so the y-sorted world puts
	# it correctly against machines and people; the stacked look comes from
	# offsetting the sprite upward instead of moving the node.
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
	at.region = Rect2(color_idx * 24, 0, 24, 13)
	box.texture = at
	box.centered = false
	box.position = Vector2(0, lift)
	root.add_child(box)

	_levels[slot] = maxi(_levels[slot], level + 1)
	if not _sprites.has(slot):
		_sprites[slot] = []
	_sprites[slot].append(root)


func take_top(preferred_slot: int = -1) -> Dictionary:
	## Removes the topmost box of a stacked slot (a machine is collecting it).
	## Returns {slot, level, pos} or {} when the yard is empty.
	## Only slots whose boxes have actually landed are fair game — a slot with
	## a reservation still in the air must be left alone.
	var candidates: Array[int] = []
	if preferred_slot >= 0 and preferred_slot < _levels.size() \
			and _settled(preferred_slot) > 0:
		candidates.append(preferred_slot)
	else:
		var best := 0
		for i in _levels.size():
			best = maxi(best, _settled(i))
		if best == 0:
			return {}
		for i in _levels.size():
			if _settled(i) == best:
				candidates.append(i)
	if candidates.is_empty():
		return {}
	var slot: int = candidates[randi() % candidates.size()]
	var stack: Array = _sprites.get(slot, [])
	if stack.is_empty():
		return {}
	var node: Node2D = stack.pop_back()
	var level: int = stack.size()
	var pos := level_position(slot, level)
	node.queue_free()
	_levels[slot] = maxi(0, _levels[slot] - 1)
	return {"slot": slot, "level": level, "pos": pos}


func _settled(slot: int) -> int:
	## Boxes that have already landed, ignoring anything still in flight.
	return (_sprites.get(slot, []) as Array).size()


func has_boxes() -> bool:
	for i in _levels.size():
		if _settled(i) > 0:
			return true
	return false


func fullest_slot() -> int:
	var best := -1
	var best_level := 0
	for i in _levels.size():
		if _settled(i) > best_level:
			best_level = _settled(i)
			best = i
	return best


func _clear_slot(slot: int) -> void:
	for node: Node2D in _sprites.get(slot, []):
		var tween := node.create_tween()
		tween.tween_property(node, "modulate:a", 0.0, 0.25)
		tween.parallel().tween_property(node, "position:x",
			node.position.x - 14.0, 0.25)
		tween.tween_callback(node.queue_free)
	_sprites[slot] = []
	_levels[slot] = 0


func fill_ratio() -> float:
	if _levels.is_empty():
		return 0.0
	var total := 0
	for lv in _levels:
		total += lv
	return float(total) / float(_levels.size() * PortLayout.STACK_MAX)


func to_save() -> Array:
	return _levels.duplicate()


func from_save(data: Array) -> void:
	## Restore the visual pile without replaying every click.
	for children: Array in _sprites.values():
		for node: Node2D in children:
			node.queue_free()
	_sprites.clear()
	resize()
	for i in _levels.size():
		_levels[i] = 0
	for i in mini(data.size(), _levels.size()):
		var want: int = clampi(int(data[i]), 0, PortLayout.STACK_MAX)
		for level in want:
			place(i, level, randi() % 8)
	# levels are derived from what actually landed
	for i in _levels.size():
		_levels[i] = _settled(i)
