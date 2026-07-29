class_name Ship
extends Node2D
## View of the berth manifest.  BerthCallController owns the workflow; this
## node only animates and exposes the legacy interaction API used by Main.

signal departed
signal phase_changed(phase: int)

enum Phase { AWAY, ARRIVING, DISCHARGING, WAITING_EXPORT, LOADING, DEPARTING }
const COLS := PortLayout.SHIP_BAY_COLS
const ROWS := PortLayout.SHIP_BAY_ROWS
const BAY_X := [8.0, 34.0]
const BAY_Y0 := 44.0
const BAY_PITCH := 11.0

var phase: Phase = Phase.AWAY
var _hull: Sprite2D
var _cargo: Node2D
var _wake: AnimatedSprite2D
var _slots: Array = [] # [column][row] -> {sprite, unit} | null
var _imports: Array[CargoUnit] = []
var _export_target := 0
var _exported := 0
var _export_claimed := 0
var _reserved: Dictionary = {}
var _flights_in_progress := 0
var _t := 0.0
var _nudge := 0.0
var _last_y := 0.0
var _wake_strength := 0.0
var ship_variant: Dictionary = {}
var variant_history: Array[String] = []
@onready var _containers: Texture2D = preload("res://assets/sprites/container_sheet.png")


func _ready() -> void:
	_wake = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	var texture: Texture2D = preload("res://assets/sprites/ship_wake.png")
	frames.set_animation_speed(&"default", 5.0)
	for i in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * 76, 0, 76, 40)
		frames.add_frame(&"default", atlas)
	_wake.sprite_frames = frames
	_wake.centered = false
	_wake.position = Vector2(PortLayout.SHIP_W * 0.5 - 38.0, PortLayout.SHIP_H - 30.0)
	_wake.modulate.a = 0.65
	_wake.z_index = -1
	_wake.play()
	add_child(_wake)
	_hull = Sprite2D.new()
	_hull.texture = preload("res://assets/sprites/ship_top.png")
	_hull.centered = false
	add_child(_hull)
	_cargo = Node2D.new()
	add_child(_cargo)
	if ship_variant.is_empty():
		ship_variant = ShipCatalog.select_variant(0, 0, [])
	_apply_ship_variant()
	_refresh_wake_state()


func wake_strength() -> float:
	## Measured from the hull actually moving, not from the phase: a tween that
	## has not started yet, or one easing to a stop at the berth, should not be
	## throwing water either way.
	return _wake_strength


func hull_centre() -> Vector2:
	return global_position + Vector2(PortLayout.SHIP_W, PortLayout.SHIP_H) * 0.5


func _process(delta: float) -> void:
	var travelled := absf(position.y - _last_y) / maxf(delta, 0.0001)
	_last_y = position.y
	var driving := 0.0 if not (phase == Phase.ARRIVING or phase == Phase.DEPARTING) \
		else clampf(travelled / 70.0, 0.0, 1.0)
	_wake_strength = move_toward(_wake_strength, driving, delta * 1.6)
	_t += delta
	_nudge = maxf(0.0, _nudge - delta * 4.0)
	if is_working():
		var hull_offset: Vector2 = ship_variant.get("hull_offset", Vector2.ZERO)
		_hull.position = hull_offset + Vector2(sin(_t * 0.8) * 0.8 + _nudge * 1.6, sin(_t * 0.55) * 1.2)
		_cargo.position = _hull.position
		_wake.position.y = PortLayout.SHIP_H - 30.0 + _hull.position.y


func is_working() -> bool:
	return phase == Phase.DISCHARGING or phase == Phase.WAITING_EXPORT or phase == Phase.LOADING

func is_discharging() -> bool: return phase == Phase.DISCHARGING
func is_loading() -> bool: return phase == Phase.LOADING
func cargo_left() -> int:
	var total := 0
	for col: Array in _slots:
		for item in col:
			if item != null:
				total += 1
	return total
func export_progress() -> Vector2i: return Vector2i(_export_claimed, _export_target)
func import_manifest_uids() -> PackedStringArray:
	var ids := PackedStringArray()
	for unit in _imports: ids.append(unit.uid)
	return ids
func hit_test(world_pos: Vector2) -> bool:
	return Rect2(global_position + Vector2(-8, -8), Vector2(PortLayout.SHIP_W + 16, PortLayout.SHIP_H + 16)).has_point(world_pos)
func nudge() -> void: _nudge = 1.0
func set_flights_in_progress(total: int) -> void: _flights_in_progress = maxi(0, total)


func select_variant(variant_seed: int, call_index: int,
		blocks: int = 9999) -> Dictionary:
	## Deterministic, history-aware, and now size-aware: the classes on offer
	## are the ones the terminal is big enough to work.
	ship_variant = ShipCatalog.select_variant(variant_seed, call_index,
		variant_history, blocks)
	if not ship_variant.is_empty():
		variant_history.append(str(ship_variant.id))
		while variant_history.size() > 8:
			variant_history.pop_front()
	_apply_ship_variant()
	return ship_variant.duplicate(true)


func variant_id() -> StringName:
	return StringName(ship_variant.get("id", ""))


func operational_capacity() -> int:
	## The vessel's nominal size in TEU, for flavour and for the journal.
	return int(ship_variant.get("capacity", 0))


func bay_rows() -> int:
	## The berth grid is the berth's, not the ship's. Classes were briefly given
	## fewer rows and a proportionally shorter hull; the result read as a
	## squashed boat rather than a smaller one, so a class is a silhouette and a
	## livery again and every hull works the same twenty-four slots.
	return ROWS


func bay_capacity() -> int:
	## The number of boxes this call moves in each direction.
	return COLS * bay_rows()


func _apply_ship_variant() -> void:
	if _hull == null or _cargo == null or _wake == null or ship_variant.is_empty():
		return
	var hull_scale: Vector2 = ship_variant.get("hull_scale", Vector2.ONE)
	var hull_offset: Vector2 = ship_variant.get("hull_offset", Vector2.ZERO)
	_hull.scale = hull_scale
	_hull.position = hull_offset
	_cargo.scale = hull_scale
	_cargo.position = hull_offset
	_wake.scale = ship_variant.get("wake_scale", Vector2.ONE)
	_hull.modulate = Color(str(ship_variant.get("hull_color", "#ffffff")))
	var wake_color := Color(str(ship_variant.get("wake_color", "#ffffff")))
	wake_color.a = 0.65
	_wake.modulate = wake_color

func _set_phase(value: Phase) -> void:
	if phase == value: return
	phase = value
	_refresh_wake_state()
	phase_changed.emit(value)


func _refresh_wake_state() -> void:
	if _wake == null or not is_instance_valid(_wake):
		return
	var moving := phase == Phase.ARRIVING or phase == Phase.DEPARTING
	_wake.visible = moving
	if moving:
		# Departure is the faster leg; both values stay deliberately restrained.
		_wake.speed_scale = 1.0 if phase == Phase.DEPARTING else 0.72
		if not _wake.is_playing():
			_wake.play()
	else:
		_wake.stop()

func set_manifest(imports: Array[CargoUnit], export_target: int = 0) -> void:
	_imports = imports.duplicate()
	_export_target = export_target if export_target > 0 else imports.size()
	_exported = 0
	_export_claimed = 0
	_build_import_view()

func set_import_manifest_reference(imports: Array[CargoUnit]) -> void:
	## Restore rebuilds the current deck independently; keep the full inbound
	## identity set for export validation without disturbing visible boxes.
	_imports = imports.duplicate()

func _empty_grid() -> void:
	for child in _cargo.get_children(): child.queue_free()
	_slots.clear()
	_reserved.clear()
	for c in COLS:
		var column: Array = []
		column.resize(bay_rows())
		_slots.append(column)

func _build_import_view() -> void:
	_empty_grid()
	for i in _imports.size():
		var col := i % COLS
		@warning_ignore("integer_division") var row := i / COLS
		if row < bay_rows(): _make_box(col, row, _imports[i])

func _make_box(col: int, row: int, unit: CargoUnit) -> void:
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = _containers
	atlas.region = Rect2(unit.color * 24, 0, 24, 13)
	sprite.texture = atlas
	sprite.centered = false
	sprite.position = Vector2(BAY_X[col] - 1.0, BAY_Y0 + row * BAY_PITCH - 1.0)
	_cargo.add_child(sprite)
	_slots[col][row] = {"sprite": sprite, "unit": unit}

func take_container() -> Dictionary:
	for col in range(COLS - 1, -1, -1):
		for row in bay_rows():
			var item: Variant = _slots[col][row]
			if item != null:
				var sprite: Sprite2D = item.sprite
				var unit: CargoUnit = item.unit
				var out := {"col": col, "row": row, "pos": sprite.global_position, "color": unit.color, "unit": unit}
				sprite.queue_free()
				_slots[col][row] = null
				return out
	return {}

func restore_import(taken: Dictionary) -> void:
	if taken.is_empty() or not taken.has("unit"): return
	if _slots[int(taken.col)][int(taken.row)] == null: _make_box(int(taken.col), int(taken.row), taken.unit)

func wait_for_export() -> void:
	if cargo_left() == 0: _set_phase(Phase.WAITING_EXPORT)
func begin_loading() -> void:
	if cargo_left() == 0: _set_phase(Phase.LOADING)

func reserve_bay() -> Dictionary:
	if _export_claimed >= _export_target: return {}
	for col in COLS:
		for row in range(bay_rows() - 1, -1, -1):
			var key := "%d,%d" % [col, row]
			if _slots[col][row] == null and not _reserved.has(key):
				_reserved[key] = true
				_export_claimed += 1
				return {"col": col, "row": row, "pos": global_position + Vector2(BAY_X[col] - 1.0, BAY_Y0 + row * BAY_PITCH - 1.0)}
	return {}
func release_bay(bay: Dictionary) -> void:
	if bay.is_empty(): return
	var key := "%d,%d" % [int(bay.col), int(bay.row)]
	if _reserved.erase(key): _export_claimed = maxi(0, _export_claimed - 1)
func place_unit(col: int, row: int, unit: CargoUnit) -> bool:
	# Sector is not checked here any more. Since the yard tranships, a box being
	# loaded may well have arrived as an IMPORT on an earlier call — refusing it
	# made every such transfer roll back with "movimento cancelado" and the
	# berth could never finish loading.
	if unit == null or col < 0 or col >= COLS or row < 0 or row >= bay_rows():
		return false
	var key := "%d,%d" % [col, row]
	if not _reserved.has(key) or _slots[col][row] != null:
		return false
	_reserved.erase(key)
	_make_box(col, row, unit)
	_exported += 1
	return true
func place_container(col: int, row: int, color_idx: int) -> bool:
	return place_unit(col, row, CargoUnit.new("", CargoUnit.EXPORT, color_idx))
func ready_to_depart() -> bool:
	return _export_target > 0 and _exported >= _export_target and _flights_in_progress == 0

func arrive() -> void:
	if _imports.is_empty():
		var generated: Array[CargoUnit] = []
		for i in bay_capacity(): generated.append(CargoUnit.new("", CargoUnit.IMPORT, randi() % 8))
		set_manifest(generated, generated.size())
	_set_phase(Phase.ARRIVING)
	visible = true
	# The hull is drawn bow-up, so a ship can only travel north bow-first. The
	# channel therefore runs south to north past the quay: in from the open
	# water below, out past the top. It used to be tweened downward at both
	# ends, which is a ship reversing into its berth and then reversing out to
	# sea.
	position = Vector2(PortLayout.SHIP_X,
		PortLayout.world_bottom() + PortLayout.SHIP_H * 0.5)
	var tween := create_tween()
	tween.tween_property(self, "position:y", PortLayout.SHIP_Y, 5.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_set_phase(Phase.DISCHARGING)
		EventBus.ship_arrived.emit()
		AudioManager.play_sfx("horn", 0.04, -4.0))
func depart() -> void:
	if phase == Phase.DEPARTING or phase == Phase.AWAY or not ready_to_depart(): return
	_set_phase(Phase.DEPARTING)
	AudioManager.play_sfx("horn", 0.04, -6.0)
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(self, "position:y", -PortLayout.SHIP_H - 40.0, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: visible = false; _set_phase(Phase.AWAY); departed.emit())

func snapshot() -> Dictionary:
	var manifest: Array = []
	for col_index in _slots.size():
		var column: Array = _slots[col_index]
		for row_index in column.size():
			var item: Variant = column[row_index]
			if item != null:
				manifest.append({
					"col": col_index,
					"row": row_index,
					"unit": item.unit.snapshot(),
				})
	return {"phase": int(phase), "exports_target": _export_target, "exported": _exported,
		"claimed": _export_claimed, "manifest": manifest,
		"variant": ship_variant.duplicate(true), "variant_history": variant_history.duplicate()}


func restore(data: Dictionary) -> void:
	_export_target = int(data.get("exports_target", 0))
	_exported = int(data.get("exported", 0))
	_export_claimed = int(data.get("claimed", _exported))
	ship_variant = _restore_variant(data.get("variant", {}))
	variant_history = _restore_variant_history(data.get("variant_history", []))
	if ship_variant.is_empty():
		ship_variant = ShipCatalog.select_variant(0, 0, variant_history)
	_apply_ship_variant()
	_empty_grid()
	var manifest: Array = data.get("manifest", [])
	for i in manifest.size():
		var raw: Variant = manifest[i]
		if not (raw is Dictionary):
			continue
		var unit_raw: Variant = raw.get("unit", raw)
		if not (unit_raw is Dictionary):
			continue
		# v2.1 records retain the physical bay so a mid-flight restore leaves
		# the reserved origin empty. Older flat manifests remain readable.
		var col := int(raw.get("col", i % COLS))
		@warning_ignore("integer_division")
		var legacy_row := i / COLS
		var row := int(raw.get("row", legacy_row))
		if col >= 0 and col < COLS and row >= 0 and row < ROWS \
				and _slots[col][row] == null:
			_make_box(col, row, CargoUnit.from_snapshot(unit_raw))
	_set_phase(int(data.get("phase", Phase.AWAY)))


func _restore_variant(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var silhouette_id := StringName(raw.get("silhouette_id", ""))
	var palette_id := StringName(raw.get("palette_id", ""))
	var silhouette := ShipCatalog.get_silhouette(silhouette_id)
	var palette := ShipCatalog.get_palette(palette_id)
	if silhouette.is_empty() or palette.is_empty():
		return {}
	return {
		"id": "%s:%s" % [String(silhouette_id), String(palette_id)],
		"silhouette_id": silhouette_id, "palette_id": palette_id,
		"capacity": silhouette.capacity, "hull_scale": silhouette.hull_scale,
		"hull_offset": silhouette.hull_offset, "wake_scale": silhouette.wake_scale,
		"hull_color": palette.hull, "wake_color": palette.wake, "cargo_color": palette.cargo,
	}


func _restore_variant_history(raw: Variant) -> Array[String]:
	var restored: Array[String] = []
	if raw is Array:
		for item in raw:
			if item is String or item is StringName:
				restored.append(str(item))
	while restored.size() > 8:
		restored.pop_front()
	return restored

func normalize_after_restore() -> void:
	## Flights are reconciled by BerthCallController; transient tween phases are
	## resumed as a stable berth state at the physical dock.
	if phase == Phase.ARRIVING:
		visible = true
		position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y)
		_set_phase(Phase.DISCHARGING)
	elif phase == Phase.DEPARTING:
		visible = true
		position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y)
		_set_phase(Phase.LOADING)
	elif phase == Phase.AWAY:
		visible = false
	else:
		visible = true
		position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y)
	_flights_in_progress = 0
	_reserved.clear()
	_export_claimed = _exported
func apply_view_metrics(metrics: Dictionary) -> void:
	visible = bool(metrics.get("ship_visible", visible))
