class_name Rainfall
extends Node2D
## Rain over the terminal: falling streaks, the splash where each one lands, and
## the wet sheen it leaves on the pavement.
##
## Drawn rather than particled, for two reasons. The streaks have to be *pixel*
## streaks on the same grid as everything else — a GPU particle at this scale
## produces sub-pixel smear that reads as video noise over pixel art — and the
## whole thing has to cost one draw call on a phone.
##
## The rain is presentation only. `TimeManager` rolls it, nothing in the economy
## reads it: fog already carries the throughput penalty, and a second weather
## with a second penalty would quietly halve the port on a bad day.

## Drops in the air at once, at full downpour.
const DROPS := 190
## Rings alive at once. A cap rather than a rate, so a wide port on a phone costs
## the same as a narrow one.
const SPLASHES := 90
## Pixels per second a drop falls, and the sideways drift that makes it weather
## rather than a screensaver.
const FALL_SPEED := Vector2(-46.0, 330.0)
const LENGTH := 7.0
const SPLASH_LIFE := 0.34
const FADE_SECONDS := 4.0

var world: PortWorld
var _drops: Array[Dictionary] = []
var _splashes: Array[Dictionary] = []
var _amount := 0.0
var _target := 0.0
var _rect := Rect2()


func setup(port: PortWorld) -> void:
	world = port
	name = "Rainfall"
	# Above the yard and the ships, below the UI: rain falls on the whole port.
	z_index = 20
	z_as_relative = false
	world.add_child(self)
	rebuild()
	EventBus.rain_changed.connect(_on_rain_changed)
	_on_rain_changed(TimeManager.rain_active)
	if TimeManager.rain_active:
		_amount = 1.0


func rebuild() -> void:
	## The rain covers whatever the port currently is, so buying land widens it.
	_rect = Rect2(Vector2(-20.0, -40.0),
		Vector2(PortLayout.WORLD_W + 40.0, PortLayout.world_bottom() + 120.0))
	_drops.clear()
	for index in DROPS:
		_drops.append(_new_drop(true))


func is_raining() -> bool:
	return _target > 0.5


func amount() -> float:
	return _amount


func _on_rain_changed(active: bool) -> void:
	_target = 1.0 if active else 0.0


func _new_drop(anywhere: bool) -> Dictionary:
	## Every drop is given the height it lands at, not just where it starts.
	## Without that the only splashes are on the bottom edge of the world, which
	## is to say nowhere the player is looking.
	var ground := randf_range(_rect.position.y + 40.0, _rect.end.y)
	return {
		"pos": Vector2(
			randf_range(_rect.position.x, _rect.end.x),
			randf_range(_rect.position.y, ground) if anywhere \
				else _rect.position.y - randf_range(0.0, 60.0)),
		"ground": ground,
		# A spread of speeds is what gives a flat sheet of rain any depth: the
		# fast ones read as near, the slow ones as far.
		"speed": randf_range(0.72, 1.25),
		"alpha": randf_range(0.34, 0.78),
	}


func _process(delta: float) -> void:
	_amount = move_toward(_amount, _target, delta / FADE_SECONDS)
	if _amount <= 0.001 and _splashes.is_empty():
		visible = false
		return
	visible = true
	var live := int(round(float(_drops.size()) * _amount))
	for index in live:
		var drop: Dictionary = _drops[index]
		var pos: Vector2 = drop.pos
		pos += FALL_SPEED * float(drop.speed) * delta
		if pos.y >= float(drop.ground) or pos.x < _rect.position.x:
			# It landed. A splash where it did is most of what sells rain.
			if pos.y >= float(drop.ground) and _splashes.size() < SPLASHES:
				_splashes.append({"pos": Vector2(pos.x, float(drop.ground)),
					"life": SPLASH_LIFE})
			var fresh := _new_drop(false)
			drop["pos"] = fresh.pos
			drop["ground"] = fresh.ground
			drop["speed"] = fresh.speed
			drop["alpha"] = fresh.alpha
		else:
			drop["pos"] = pos
	for index in range(_splashes.size() - 1, -1, -1):
		var splash: Dictionary = _splashes[index]
		splash["life"] = float(splash.life) - delta
		if float(splash.life) <= 0.0:
			_splashes.remove_at(index)
	queue_redraw()


func _draw() -> void:
	if _amount <= 0.001:
		return
	var live := int(round(float(_drops.size()) * _amount))
	var streak := FALL_SPEED.normalized() * LENGTH
	for index in live:
		var drop: Dictionary = _drops[index]
		var tone := Color(0.78, 0.88, 0.98, float(drop.alpha) * _amount)
		draw_line(drop.pos, drop.pos + streak * float(drop.speed), tone, 1.0)
	for splash: Dictionary in _splashes:
		var life := float(splash.life) / SPLASH_LIFE
		var ring := Color(0.86, 0.94, 1.0, life * 0.5 * _amount)
		# A ring that opens as it fades: a splash is the water moving outward.
		draw_arc(splash.pos, (1.0 - life) * 4.0 + 1.0, 0.0, TAU, 8, ring, 1.0)
