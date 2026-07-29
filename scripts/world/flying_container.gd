class_name FlyingContainer
extends Node2D
## A box travelling from the ship's deck to a yard stack. Top-down, so the
## "height" of the arc is faked by lifting the sprite and sliding a shadow
## along the ground path beneath it.

signal landed

const LIFT := 26.0

var _box: Sprite2D
var _shadow: Sprite2D
var _start := Vector2.ZERO
var _end := Vector2.ZERO


func setup(sheet: Texture2D, color_idx: int, start: Vector2, end: Vector2) -> void:
	_start = start
	_end = end
	position = start

	_shadow = Sprite2D.new()
	_shadow.texture = preload("res://assets/sprites/container_shadow.png")
	_shadow.centered = false
	_shadow.modulate.a = 0.45
	add_child(_shadow)

	_box = Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(color_idx * 24, 0, 24, 13)
	_box.texture = at
	_box.centered = false
	add_child(_box)


func _ready() -> void:
	var tween := create_tween()
	tween.tween_method(_travel, 0.0, 1.0, 0.62).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(_land)


func _travel(t: float) -> void:
	position = _start.lerp(_end, _ease(t))
	var height := sin(t * PI) * LIFT
	_box.position = Vector2(0, -height)
	_box.rotation = sin(t * PI) * 0.05
	_shadow.scale = Vector2.ONE * (1.0 - height / (LIFT * 2.6))
	_shadow.modulate.a = 0.45 - height / (LIFT * 5.0)


func _land() -> void:
	position = _end
	_box.position = Vector2.ZERO
	_box.rotation = 0.0
	landed.emit()
	AudioManager.play_sfx("thunk", 0.10, -3.0)
	_shadow.visible = false
	# squash on impact, then hand off to the permanent yard sprite
	_box.offset = Vector2(-12, -13)
	_box.position = Vector2(12, 13)
	var tween := create_tween()
	tween.tween_property(_box, "scale", Vector2(1.2, 0.72), 0.06)
	tween.tween_property(_box, "scale", Vector2(0.94, 1.06), 0.07)
	tween.tween_property(_box, "scale", Vector2.ONE, 0.05)
	tween.tween_callback(queue_free)


static func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)
