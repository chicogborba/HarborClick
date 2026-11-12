class_name Globe
extends Control
## A planet you can spin with a finger, with the ports on it.
##
## The pixels come from `globe.gdshader`; this owns the camera (which longitude
## and latitude face the viewer), the finger, the pins and the voyage arc. It
## is used twice: on the PORTOS board, where tapping a pin picks a port, and on
## the voyage screen, where it turns from where you were to where you are going
## while a little hull crosses between them.

signal port_picked(id: StringName)

const MAP := preload("res://assets/sprites/map_world.png")
const COUNTRIES := preload("res://assets/sprites/map_countries.png")
const SHADER := preload("res://assets/shaders/globe.gdshader")
## Globe pixels across. The control draws them at whatever whole multiple fits.
const PIXELS := 112
const TAP_SLOP := 6.0
const IDLE_SPIN := 0.12          # radians a second when nobody is touching it
const IDLE_AFTER := 3.5          # seconds after the last touch before it drifts

var lon0 := deg_to_rad(-46.0)
var lat0 := deg_to_rad(-12.0)
## Port ids drawn as pins, and which one is picked.
var selected: StringName = &""
var spin_when_idle := true
## Voyage mode: a great-circle arc from `arc_from` to `arc_to` (lon/lat in
## degrees), and how far along it the hull is (0..1). Off when `arc_t < 0`.
var arc_from := Vector2.ZERO
var arc_to := Vector2.ZERO
var arc_t := -1.0

var _rect: ColorRect
var _material: ShaderMaterial
var _overlay: Control
var _press := Vector2(-1, -1)
var _last := Vector2.ZERO
var _travel := 0.0
var _idle := 99.0
var _velocity := 0.0
var _focus: Tween
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("world_map", MAP)
	_material.set_shader_parameter("countries", COUNTRIES)
	_material.set_shader_parameter("pixels", float(PIXELS))
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	resized.connect(_fit)
	_fit()
	_push()


func globe_rect() -> Rect2:
	return _rect.get_rect() if _rect != null else Rect2()


func _fit() -> void:
	if _rect == null:
		return
	var side := minf(size.x, size.y)
	var scale := maxi(1, int(side / PIXELS))
	var drawn := Vector2.ONE * float(PIXELS * scale)
	_rect.position = ((size - drawn) * 0.5).floor()
	_rect.size = drawn
	_overlay.position = Vector2.ZERO
	_overlay.size = size


func _push() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("lon0", lon0)
	_material.set_shader_parameter("lat0", lat0)
	var port := PortDB.get_port(PortDB.active)
	_material.set_shader_parameter("active_country", int(port.get("flag", 0)) + 1)
	_overlay.queue_redraw()


# ------------------------------------------------------------------- camera

func look_at_port(id: StringName, seconds: float = 0.6) -> void:
	var port := PortDB.get_port(id)
	if port.is_empty():
		return
	look_at_lonlat(lonlat(port), seconds)


func look_at_lonlat(deg: Vector2, seconds: float = 0.6) -> void:
	## Turn so that `deg` (lon, lat in degrees) faces the viewer, the short way
	## round. Instant when motion is off.
	var target_lon := deg_to_rad(deg.x)
	var target_lat := clampf(deg_to_rad(deg.y) * 0.8, -0.9, 0.9)
	var delta := wrapf(target_lon - lon0, -PI, PI)
	if _focus != null and _focus.is_valid():
		_focus.kill()
	if seconds <= 0.0 or not UserPreferences.can_animate():
		lon0 = lon0 + delta
		lat0 = target_lat
		_push()
		return
	var start_lon := lon0
	var start_lat := lat0
	_focus = create_tween()
	_focus.tween_method(func(k: float) -> void:
		lon0 = start_lon + delta * k
		lat0 = lerpf(start_lat, target_lat, k)
		_push(), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	_idle = 0.0


static func lonlat(port: Dictionary) -> Vector2:
	## A port's chart pin back to degrees (the chart is equirectangular).
	var chart: Vector2 = port.get("chart", Vector2(0.5, 0.5))
	return Vector2(chart.x * 360.0 - 180.0, 90.0 - chart.y * 180.0)


func project(deg: Vector2) -> Vector3:
	## Degrees to (x, y) in control pixels and z: z > 0 is the near side.
	var lon := deg_to_rad(deg.x)
	var lat := deg_to_rad(deg.y)
	var p := Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
	var t := Vector3(p.x * cos(lon0) - p.z * sin(lon0), p.y,
		p.x * sin(lon0) + p.z * cos(lon0))
	var v := Vector3(t.x, t.y * cos(lat0) - t.z * sin(lat0),
		t.y * sin(lat0) + t.z * cos(lat0))
	var r := globe_rect()
	var half := r.size.x * 0.5
	return Vector3(r.position.x + half + v.x * half,
		r.position.y + half - v.y * half, v.z)


# -------------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	var at := Vector2.ZERO
	var pressed := false
	var released := false
	var moved := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		at = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenTouch:
		at = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		at = event.position
		moved = true
	else:
		return
	if pressed:
		_press = at
		_last = at
		_travel = 0.0
		_velocity = 0.0
		if _focus != null and _focus.is_valid():
			_focus.kill()
		accept_event()
	elif moved and _press.x >= 0.0:
		var delta := at - _last
		_last = at
		_travel += delta.length()
		var half := maxf(1.0, globe_rect().size.x * 0.5)
		lon0 -= delta.x / half
		lat0 = clampf(lat0 + delta.y / half, -1.1, 1.1)
		_velocity = -delta.x / half
		_idle = 0.0
		_push()
		accept_event()
	elif released and _press.x >= 0.0:
		if _travel <= TAP_SLOP:
			var picked := port_at(at)
			if picked != &"":
				port_picked.emit(picked)
		_press = Vector2(-1, -1)
		accept_event()


func port_at(at: Vector2) -> StringName:
	## The nearest pin on the near side within a finger's reach.
	var best: StringName = &""
	var best_d := 22.0
	for port in PortDB.PORTS:
		var p := project(lonlat(port))
		if p.z <= 0.05:
			continue
		var d := Vector2(p.x, p.y).distance_to(at)
		if d < best_d:
			best_d = d
			best = StringName(port.id)
	return best


func _process(delta: float) -> void:
	_t += delta
	_idle += delta
	var busy := _press.x >= 0.0 or (_focus != null and _focus.is_running())
	if not busy:
		if absf(_velocity) > 0.0005:
			# A flick keeps turning and slows to a stop.
			lon0 += _velocity
			_velocity *= 0.9
			_push()
		elif spin_when_idle and _idle > IDLE_AFTER and UserPreferences.can_animate():
			lon0 += IDLE_SPIN * delta
			_push()
	_overlay.queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw_overlay() -> void:
	if arc_t >= 0.0:
		_draw_arc()
	for port in PortDB.PORTS:
		var id := StringName(port.id)
		var p := project(lonlat(port))
		if p.z <= 0.0:
			continue
		var at := Vector2(roundf(p.x), roundf(p.y))
		var here := id == PortDB.active
		var open := SaveManager.port_open(id)
		var picked := id == selected
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		var ink := Color8(16, 24, 34)
		var fill := Color8(255, 208, 80) if here else (Color8(104, 214, 190) if open
			else Color8(246, 238, 214))
		var r := 4 if picked else 3
		if picked:
			_diamond(at, r + 3, Color(1, 1, 1, 0.35 + 0.4 * pulse))
		_diamond(at, r + 1, ink)
		_diamond(at, r, fill)
		_diamond(at, 1, Color8(255, 255, 240))


func _draw_arc() -> void:
	## A great circle, sampled; only the near side is drawn.
	var a := _unit(arc_from)
	var b := _unit(arc_to)
	var angle := a.angle_to(b)
	var steps := 48
	var prev := Vector3.ZERO
	var prev_ok := false
	var ship := Vector3.ZERO
	for i in steps + 1:
		var k := float(i) / float(steps)
		var point := _slerp(a, b, angle, k)
		var deg := Vector2(rad_to_deg(atan2(point.x, point.z)),
			rad_to_deg(asin(clampf(point.y, -1.0, 1.0))))
		var p := project(deg)
		var ok := p.z > 0.0
		if ok and prev_ok and i % 2 == 0:
			_overlay.draw_line(Vector2(prev.x, prev.y), Vector2(p.x, p.y),
				Color(1.0, 0.86, 0.4, 0.95 if k <= arc_t else 0.4), 1.0)
		prev = p
		prev_ok = ok
		if k <= arc_t:
			ship = p
	if ship.z > 0.0:
		var at := Vector2(roundf(ship.x), roundf(ship.y))
		_overlay.draw_rect(Rect2(at - Vector2(3, 2), Vector2(7, 4)), Color8(16, 24, 34))
		_overlay.draw_rect(Rect2(at - Vector2(2, 1), Vector2(5, 2)), Color8(240, 240, 232))
		_overlay.draw_rect(Rect2(at + Vector2(-1, -3), Vector2(2, 2)), Color8(214, 72, 60))


static func _unit(deg: Vector2) -> Vector3:
	var lon := deg_to_rad(deg.x)
	var lat := deg_to_rad(deg.y)
	return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))


static func _slerp(a: Vector3, b: Vector3, angle: float, k: float) -> Vector3:
	if angle < 0.0001:
		return a
	return (a * sin((1.0 - k) * angle) + b * sin(k * angle)) / sin(angle)


func _diamond(at: Vector2, radius: int, color: Color) -> void:
	for dy in range(-radius, radius + 1):
		var half := radius - absi(dy)
		_overlay.draw_rect(Rect2(at.x - half, at.y + dy, half * 2 + 1, 1), color)
