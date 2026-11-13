class_name PortCamera
extends Camera2D
## Responsive terminal camera: touch/mouse drag, wheel zoom and keyboard pan.

const VIEW_H := PortLayout.VIEW_H
const VIEW_W := PortLayout.WORLD_W

var _velocity := Vector2.ZERO
var _dragging := false
var _world_bottom := 520.0
var _viewport_size := Vector2(VIEW_W, VIEW_H)
var _world_rect := Rect2(Vector2.ZERO, Vector2(VIEW_W, VIEW_H))
var _zoom_floor := 1.0
var _zoom_ceiling := 2.5
var _has_shell_metrics := false
var _input_enabled := true
## Camera shake state: a decaying whole-pixel jitter applied on top of
## `_base_offset` through Camera2D.offset, zero when no shake is running.
## `_base_offset` is the anchor offset the shell metrics set, so the shake
## never clobbers it.
var _base_offset := Vector2.ZERO
var _shake_strength := 0.0
var _shake_elapsed := 0.0
var _shake_seconds := 0.0
## Screen-space strips the HUD covers at the top and the bottom of the world.
## Without them the gantry sits on the gate and the console sits on the last row
## of buildings, and no amount of dragging can bring either out — the camera
## stops at the edge of the terminal, not at the edge of what can be seen.
var _inset_top := 0.0
var _inset_bottom := 0.0


func _ready() -> void:
	position = Vector2(VIEW_W / 2.0, VIEW_H / 2.0)
	set_world_bottom(_world_bottom)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()


func _process(delta: float) -> void:
	if not _dragging and _velocity.length() > 1.0:
		position += _velocity * delta
		_velocity = _velocity.lerp(Vector2.ZERO, minf(1.0, delta * 5.0))
	var keyboard := Vector2.ZERO
	if _input_enabled:
		keyboard = Vector2(
			Input.get_axis(&"pan_left", &"pan_right"),
			float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP)))
	if keyboard != Vector2.ZERO:
		position += keyboard.normalized() * 300.0 * delta / zoom
	_clamp_position()
	position = position.round()
	_update_shake(delta)


## Fingers currently down, index -> position. Two of them are a pinch.
var _touches: Dictionary = {}
var _pinch_span := 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	if event is InputEventMagnifyGesture:
		# A trackpad pinch, or a browser forwarding one.
		_set_zoom(zoom.x * event.factor)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_span = _touch_span()
		_dragging = event.pressed and _touches.size() < 2
		if event.pressed:
			_velocity = Vector2.ZERO
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				_velocity = Vector2.ZERO
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,
				MOUSE_BUTTON_WHEEL_DOWN]:
			var up: bool = event.button_index == MOUSE_BUTTON_WHEEL_UP
			if event.ctrl_pressed or event.meta_pressed:
				# Ctrl/Cmd + wheel is the zoom a desktop player reaches for on
				# purpose; the bare wheel is a scroll, like on every page.
				_set_zoom(zoom.x * (1.14 if up else 0.88))
			else:
				_scroll(-WHEEL_STEP if up else WHEEL_STEP)
	elif event is InputEventPanGesture:
		# Two fingers on a trackpad: the same scroll, not a zoom.
		_scroll(event.delta.y * PAN_GESTURE_STEP)
	elif event is InputEventScreenDrag and _touches.size() >= 2:
		# Two fingers zoom, and never pan: the terminal stays under them.
		_touches[event.index] = event.position
		var span := _touch_span()
		if _pinch_span > 8.0 and span > 8.0:
			_set_zoom(zoom.x * span / _pinch_span)
		_pinch_span = span
	elif event is InputEventScreenDrag and _dragging:
		_drag_camera(event.relative, event.velocity)
	elif event is InputEventMouseMotion and _dragging:
		_drag_camera(event.relative, event.velocity)


func apply_view_metrics(metrics: Dictionary) -> void:
	_viewport_size = metrics.get("viewport_size", _viewport_size)
	_world_rect = metrics.get("world_rect", Rect2(Vector2.ZERO, _viewport_size))
	_has_shell_metrics = true
	var target_zoom := _target_zoom_for(_world_rect)
	# Camera2D normally centres its canvas in the whole viewport. When the world
	# frame is narrower than the viewport it is anchored left instead, so the
	# leftover is one margin the chrome can own rather than two empty gutters.
	offset = Vector2(
		maxf(0.0, (_viewport_size.x - _world_rect.size.x) / (2.0 * target_zoom)),
		0.0)
	_base_offset = offset
	_zoom_floor = clampf(target_zoom, 0.25, 4.0)
	_zoom_ceiling = maxf(_zoom_floor * 2.5, 1.0)
	zoom = Vector2.ONE * _zoom_floor
	_clamp_position()


func _on_viewport_resized() -> void:
	if _has_shell_metrics:
		return
	_viewport_size = get_viewport().get_visible_rect().size
	_world_rect = Rect2(Vector2.ZERO, _viewport_size)
	offset = Vector2.ZERO
	_base_offset = Vector2.ZERO
	var target_zoom := _target_zoom_for(_world_rect)
	_zoom_floor = clampf(target_zoom, 0.25, 4.0)
	_zoom_ceiling = maxf(_zoom_floor * 2.5, 1.0)
	zoom = Vector2.ONE * _zoom_floor
	_clamp_position()


## World pixels one wheel notch scrolls, and per unit of trackpad pan.
const WHEEL_STEP := 36.0
const PAN_GESTURE_STEP := 12.0


func _scroll(world_dy: float) -> void:
	_velocity = Vector2.ZERO
	position.y += world_dy / zoom.y
	_clamp_position()


func _drag_camera(relative: Vector2, drag_velocity: Vector2) -> void:
	position -= relative / zoom
	_velocity = -drag_velocity / zoom * 0.3
	_clamp_position()


func _touch_span() -> float:
	if _touches.size() < 2:
		return 0.0
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _set_zoom(value: float) -> void:
	zoom = Vector2.ONE * clampf(value, _zoom_floor, _zoom_ceiling)
	_clamp_position()


func set_view_insets(top: float, bottom: float) -> void:
	## How much of the viewport the HUD is covering, in screen pixels.
	_inset_top = maxf(0.0, top)
	_inset_bottom = maxf(0.0, bottom)
	set_world_bottom(_world_bottom)


func _world_inset(screen_pixels: float) -> float:
	return screen_pixels / maxf(zoom.y, 0.01)


func _clamp_position() -> void:
	var half_view := Vector2(_world_rect.size.x, _viewport_size.y) / (zoom * 2.0)
	var min_x := minf(VIEW_W * 0.5, half_view.x)
	var max_x := maxf(VIEW_W * 0.5, VIEW_W - half_view.x)
	# The travel is measured against the *visible* port, so scrolling to the top
	# puts the gate just under the gantry rather than behind it.
	var min_y := half_view.y - _world_inset(_inset_top)
	var max_y := maxf(min_y, _world_bottom - half_view.y + _world_inset(_inset_bottom))
	position.x = clampf(position.x, min_x, max_x)
	position.y = clampf(position.y, min_y, max_y)


func set_world_bottom(bottom: float) -> void:
	_world_bottom = bottom
	limit_left = 0
	limit_right = int(VIEW_W)
	# Camera2D limits are world units and are not recomputed on zoom, so they are
	# taken at the widest possible view — `_clamp_position` is what actually holds
	# the edge at any given zoom.
	var widest := 1.0 / maxf(_zoom_floor, 0.01)
	limit_top = -int(ceilf(_inset_top * widest))
	limit_bottom = int(maxf(bottom + _inset_bottom * widest, VIEW_H))
	_clamp_position()


func set_input_enabled(input_allowed: bool) -> void:
	_input_enabled = input_allowed
	if not input_allowed:
		_dragging = false
		_velocity = Vector2.ZERO


func focus_on(y: float, duration: float = 0.6) -> void:
	var half_height := _viewport_size.y / (zoom.y * 2.0)
	var low := half_height - _world_inset(_inset_top)
	var target := clampf(y, low,
		maxf(low, _world_bottom - half_height + _world_inset(_inset_bottom)))
	var tween := create_tween()
	tween.tween_property(self, "position:y", target, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func shake(strength: float = 2.0, seconds: float = 0.18) -> void:
	## A decaying random whole-pixel tremor, applied via Camera2D.offset in
	## `_process` and back to the base offset when it finishes. Ignored under
	## "movimento reduzido", like every other motion in the game.
	if not UserPreferences.can_animate():
		return
	_shake_strength = maxf(0.0, strength)
	_shake_seconds = maxf(0.01, seconds)
	_shake_elapsed = 0.0


func _update_shake(delta: float) -> void:
	if _shake_elapsed >= _shake_seconds:
		if _shake_strength > 0.0:
			_shake_strength = 0.0
			offset = _base_offset
		return
	if not UserPreferences.can_animate():
		# Reduce motion flipped on mid-shake: stop dead on the base offset.
		_shake_elapsed = _shake_seconds
		_shake_strength = 0.0
		offset = _base_offset
		return
	_shake_elapsed += delta
	var decay := 1.0 - minf(1.0, _shake_elapsed / _shake_seconds)
	if decay <= 0.0:
		_shake_strength = 0.0
		offset = _base_offset
		return
	var jitter := Vector2(
		roundf(randf_range(-_shake_strength, _shake_strength) * decay),
		roundf(randf_range(-_shake_strength, _shake_strength) * decay))
	offset = _base_offset + jitter


func _target_zoom_for(world_rect: Rect2) -> float:
	## The terminal scrolls vertically, so width is the stable composition axis:
	## the world's 320px design width is stretched to fill the frame it is given.
	return world_rect.size.x / VIEW_W
