extends Node
## Day/night cycle + weather. Full lighting arrives in the day/night phase;
## the API is stable from day one so other systems can already hook in.

const DAY_LENGTH := 720.0   # seconds per full day
const FOG_CHANCE := 0.15

var day: int = 1
var time_of_day: float = 0.3   # 0..1 (0 = midnight). Start mid-morning.
var fog_active: bool = false
var speed_mult: float = 1.0    # debug: accelerate the cycle

var _phase: StringName = &"day"


func _process(delta: float) -> void:
	time_of_day += delta * speed_mult / DAY_LENGTH
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
		_roll_weather()
		EventBus.new_day.emit(day)
	var new_phase := _compute_phase()
	if new_phase != _phase:
		_phase = new_phase
		EventBus.day_phase_changed.emit(_phase)


func phase() -> StringName:
	return _phase


func _compute_phase() -> StringName:
	if time_of_day < 0.20:
		return &"night"
	elif time_of_day < 0.28:
		return &"dawn"
	elif time_of_day < 0.72:
		return &"day"
	elif time_of_day < 0.82:
		return &"dusk"
	return &"night"


func _roll_weather() -> void:
	var was := fog_active
	fog_active = randf() < FOG_CHANCE
	if was != fog_active:
		EventBus.fog_changed.emit(fog_active)
		GameState.recompute()


func weather_cps_mult() -> float:
	if fog_active and not GameState.has_upgrade("radar_neblina"):
		return 0.8
	return 1.0
