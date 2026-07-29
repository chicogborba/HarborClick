class_name PortCamera
extends Camera2D
## Vertical touch camera: drag to scroll the terminal, with momentum.

const VIEW_H := PortLayout.VIEW_H
const VIEW_W := PortLayout.WORLD_W

var _velocity := 0.0
var _dragging := false
var _world_bottom := 520.0


func _ready() -> void:
	position = Vector2(VIEW_W / 2.0, VIEW_H / 2.0)
	set_world_bottom(_world_bottom)


func _process(delta: float) -> void:
	if not _dragging and absf(_velocity) > 1.0:
		position.y += _velocity * delta
		_velocity = lerpf(_velocity, 0.0, minf(1.0, delta * 5.0))
	var dev := Input.get_axis(&"pan_left", &"pan_right")
	if dev != 0.0:
		position.y += dev * 300.0 * delta
	_clamp_y()
	position = position.round()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_dragging = event.pressed
		if event.pressed:
			_velocity = 0.0
	elif event is InputEventScreenDrag and _dragging:
		position.y -= event.relative.y
		_velocity = -event.velocity.y * 0.3
		_clamp_y()


func _clamp_y() -> void:
	var max_center := maxf(VIEW_H / 2.0, _world_bottom - VIEW_H / 2.0)
	position.y = clampf(position.y, VIEW_H / 2.0, max_center)


func set_world_bottom(bottom: float) -> void:
	_world_bottom = bottom
	limit_left = 0
	limit_right = int(VIEW_W)
	limit_top = 0
	limit_bottom = int(maxf(bottom, VIEW_H))


func focus_on(y: float, duration: float = 0.6) -> void:
	var target := clampf(y, VIEW_H / 2.0, maxf(VIEW_H / 2.0, _world_bottom - VIEW_H / 2.0))
	var tween := create_tween()
	tween.tween_property(self, "position:y", target, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
