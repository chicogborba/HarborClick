class_name Ship
extends Node2D
## Container ship working the berth, seen from above (bow up).
##
## A call follows the real sequence: it arrives loaded with imports, the player
## empties it, the terminal then loads exports out of the yard, and only when
## the export stow is done does the ship sail.

signal departed
signal phase_changed(phase: int)

enum Phase { AWAY, ARRIVING, DISCHARGING, LOADING, DEPARTING }

const COLS := PortLayout.SHIP_BAY_COLS
const ROWS := PortLayout.SHIP_BAY_ROWS
const BAY_X := [8.0, 34.0]
const BAY_Y0 := 44.0
const BAY_PITCH := 11.0
## Exports never fill the ship — that asymmetry is what lets the yard grow.
const EXPORT_RATIO := 0.45

var phase: Phase = Phase.AWAY

var _hull: Sprite2D
var _cargo: Node2D
var _wake: AnimatedSprite2D
var _slots: Array = []          # [col][row] -> Sprite2D | null
var _cargo_count := 0
var _reserved: Dictionary = {}   # bays claimed by boxes still in flight
var _export_target := 0
var _exported := 0        # boxes actually stowed
var _export_claimed := 0  # boxes promised, including those still flying
var _t := 0.0
var _nudge := 0.0

@onready var _containers: Texture2D = preload("res://assets/sprites/container_sheet.png")


func _ready() -> void:
	_wake = AnimatedSprite2D.new()
	var wf := SpriteFrames.new()
	var wtex: Texture2D = preload("res://assets/sprites/ship_wake.png")
	wf.set_animation_speed(&"default", 5.0)
	for i in 4:
		var at := AtlasTexture.new()
		at.atlas = wtex
		at.region = Rect2(i * 76, 0, 76, 40)
		wf.add_frame(&"default", at)
	_wake.sprite_frames = wf
	_wake.centered = false
	_wake.position = Vector2(PortLayout.SHIP_W / 2.0 - 38.0, PortLayout.SHIP_H - 30.0)
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


func _process(delta: float) -> void:
	_t += delta
	_nudge = maxf(0.0, _nudge - delta * 4.0)
	if is_working():
		_hull.position.x = sin(_t * 0.8) * 0.8 + _nudge * 1.6
		_hull.position.y = sin(_t * 0.55) * 1.2
		_cargo.position = _hull.position
		_wake.position.y = PortLayout.SHIP_H - 30.0 + sin(_t * 0.55) * 1.2


func is_working() -> bool:
	return phase == Phase.DISCHARGING or phase == Phase.LOADING


func is_discharging() -> bool:
	return phase == Phase.DISCHARGING


func is_loading() -> bool:
	return phase == Phase.LOADING


func cargo_left() -> int:
	return _cargo_count


func export_progress() -> Vector2i:
	## Counts claimed boxes so the board reacts to the tap, not to the landing.
	return Vector2i(_export_claimed, _export_target)


func hit_test(world_pos: Vector2) -> bool:
	var r := Rect2(global_position + Vector2(-8, -8),
		Vector2(PortLayout.SHIP_W + 16, PortLayout.SHIP_H + 16))
	return r.has_point(world_pos)


func nudge() -> void:
	_nudge = 1.0


func _set_phase(value: Phase) -> void:
	phase = value
	phase_changed.emit(value)


# ---------------------------------------------------------------- cargo

func _fill_import() -> void:
	for child in _cargo.get_children():
		child.queue_free()
	_slots.clear()
	_reserved.clear()
	_cargo_count = 0
	# the slot grid has to exist before _make_box can register boxes into it
	for c in COLS:
		var col: Array = []
		col.resize(ROWS)
		_slots.append(col)
	for c in COLS:
		for r in ROWS:
			_make_box(c, r, randi() % 8)
			_cargo_count += 1
	_export_target = int(COLS * ROWS * EXPORT_RATIO)
	_exported = 0
	_export_claimed = 0


func _clear_bays() -> void:
	for child in _cargo.get_children():
		child.queue_free()
	_slots.clear()
	_reserved.clear()
	for c in COLS:
		var col: Array = []
		for r in ROWS:
			col.append(null)
		_slots.append(col)
	_cargo_count = 0


func _make_box(col: int, row: int, color_idx: int) -> Sprite2D:
	var spr := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = _containers
	at.region = Rect2(color_idx * 24, 0, 24, 13)
	spr.texture = at
	spr.centered = false
	spr.set_meta("color", color_idx)
	spr.position = Vector2(BAY_X[col] - 1.0, BAY_Y0 + row * BAY_PITCH - 1.0)
	_cargo.add_child(spr)
	_slots[col][row] = spr
	return spr


func take_container() -> Dictionary:
	## Discharge: lift the outermost remaining box (quay side first).
	for c in range(COLS - 1, -1, -1):
		for r in ROWS:
			var spr: Sprite2D = _slots[c][r]
			if spr != null:
				var out := {"pos": spr.global_position, "color": spr.get_meta("color")}
				spr.queue_free()
				_slots[c][r] = null
				_cargo_count -= 1
				if _cargo_count <= 0:
					begin_loading()
				return out
	return {}


func reserve_bay() -> Dictionary:
	## Load: claim the next empty slot and report where the box should land.
	## The claim matters — several boxes are usually in the air at once, and
	## without it they would all aim at the same bay and only one would stick.
	if _export_claimed >= _export_target:
		return {}
	for c in COLS:
		for r in range(ROWS - 1, -1, -1):
			var key := "%d,%d" % [c, r]
			if _slots[c][r] == null and not _reserved.has(key):
				_reserved[key] = true
				_export_claimed += 1
				return {
					"col": c, "row": r,
					"pos": global_position + Vector2(BAY_X[c] - 1.0,
						BAY_Y0 + r * BAY_PITCH - 1.0),
				}
	return {}


func place_container(col: int, row: int, color_idx: int) -> void:
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return
	_reserved.erase("%d,%d" % [col, row])
	if _slots[col][row] != null:
		return
	_make_box(col, row, color_idx)
	_cargo_count += 1
	_exported += 1
	if _exported >= _export_target:
		depart()


# ---------------------------------------------------------------- schedule

func arrive() -> void:
	_fill_import()
	_set_phase(Phase.ARRIVING)
	visible = true
	position = Vector2(PortLayout.SHIP_X, -PortLayout.SHIP_H - 20.0)
	var tween := create_tween()
	tween.tween_property(self, "position:y", PortLayout.SHIP_Y, 4.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_set_phase(Phase.DISCHARGING)
		EventBus.ship_arrived.emit()
		EventBus.toast.emit("Navio atracado. Toque para descarregar!")
		AudioManager.play_sfx("horn", 0.04, -4.0))


func begin_loading() -> void:
	if phase == Phase.LOADING:
		return
	_clear_bays()
	_set_phase(Phase.LOADING)
	EventBus.toast.emit("Descarga concluída. Agora embarque a exportação!")


func depart() -> void:
	if phase == Phase.DEPARTING or phase == Phase.AWAY:
		return
	_set_phase(Phase.DEPARTING)
	AudioManager.play_sfx("horn", 0.04, -6.0)
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(self, "position:y",
		PortLayout.world_bottom() + 80.0, 5.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		visible = false
		_set_phase(Phase.AWAY)
		departed.emit())
