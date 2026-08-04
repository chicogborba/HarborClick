class_name FlyingContainer
extends Node2D
## A box travelling from the ship's deck to a yard stack. Top-down, so the
## "height" of the arc is faked by lifting the sprite and sliding a shadow
## along the ground path beneath it.

signal landed

const LIFT := 26.0
const BOX_SIZE := Vector2(24.0, 13.0)

var _box: Sprite2D
var _shadow: Sprite2D
var _glint: Sprite2D
var _start := Vector2.ZERO
var _end := Vector2.ZERO
var _start_rotation := 0.0
var _end_rotation := 0.0
var _duration := 0.62
var _lift := LIFT


func setup(sheet: Texture2D, color_idx: int, start: Vector2, end: Vector2) -> void:
	_start = start
	_end = end
	position = start
	var distance := start.distance_to(end)
	_duration = clampf(0.44 + distance / 520.0, 0.50, 0.82)
	_lift = clampf(18.0 + distance * 0.075, 22.0, 34.0)

	_shadow = Sprite2D.new()
	_shadow.texture = preload("res://assets/sprites/container_shadow.png")
	_shadow.centered = true
	_shadow.modulate.a = 0.45
	add_child(_shadow)

	_box = Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(color_idx * 24, 0, 24, 13)
	_box.texture = at
	# Every transfer point is the visual centre of a box. Rotating a
	# top-left-anchored sprite made the last metres of a truck/ship move swing
	# around the destination instead of actually arriving on it.
	_box.centered = true
	add_child(_box)

	_glint = Sprite2D.new()
	_glint.texture = preload("res://assets/sprites/prop_glow.png")
	_glint.position = Vector2.ZERO
	_glint.scale = Vector2.ONE * 0.07
	_glint.modulate = Color8(255, 230, 174, 0)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glint.material = additive
	add_child(_glint)


func duration() -> float:
	## How long this box is in the air. The quay crane animates its trolley over
	## exactly this window so the two are the same event.
	return _duration


func set_rotations(start_rotation: float, end_rotation: float) -> void:
	## Trucks carry boxes lengthwise while yard and ship slots are landscape.
	## The flying view owns the hand-off so neither endpoint snaps by 90°.
	_start_rotation = start_rotation
	_end_rotation = end_rotation
	if _box != null:
		_box.rotation = _start_rotation


func _ready() -> void:
	var tween := create_tween()
	tween.tween_method(_travel, 0.0, 1.0, _duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(_land)


func _travel(t: float) -> void:
	position = _start.lerp(_end, _ease(t))
	var height := sin(t * PI) * _lift
	_box.position = Vector2(0, -height)
	_box.rotation = lerp_angle(_start_rotation, _end_rotation, _ease(t)) \
		+ sin(t * PI) * 0.035
	_shadow.scale = Vector2.ONE * (1.0 - height / (_lift * 2.6))
	_shadow.modulate.a = 0.45 - height / (_lift * 5.0)
	_glint.position.y = 6.0 - height
	_glint.modulate.a = sin(t * PI) * 0.34


func _land() -> void:
	position = _end
	_box.position = Vector2.ZERO
	_box.rotation = _end_rotation
	AudioManager.play_sfx("thunk", 0.10, -3.0)
	_shadow.visible = false
	_glint.modulate.a = 0.46
	# Squash around the same centre that travelled, then hand off to the
	# permanent endpoint sprite. No pivot correction is needed at landing.
	var tween := create_tween()
	tween.tween_property(_box, "scale", Vector2(1.2, 0.72), 0.06)
	tween.tween_property(_box, "scale", Vector2(0.94, 1.06), 0.07)
	tween.tween_property(_box, "scale", Vector2.ONE, 0.05)
	tween.parallel().tween_property(_glint, "modulate:a", 0.0, 0.14)
	tween.tween_callback(_finish_landing)


func _finish_landing() -> void:
	## Hide the traveller before the transaction creates the permanent
	## destination view. The reverse order showed two boxes for one frame.
	_box.visible = false
	_glint.visible = false
	landed.emit()
	queue_free()


static func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)
