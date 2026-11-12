extends Node
## Day/night cycle + weather. Full lighting arrives in the day/night phase;
## the API is stable from day one so other systems can already hook in.

const DAY_LENGTH := 720.0   # seconds per full day
const FOG_CHANCE := 0.15
## Rain is deliberately weather with no economy attached: fog already carries the
## throughput penalty, and a second one would quietly halve the port on a bad
## roll. This one is only ever seen and heard.
const RAIN_CHANCE := 0.22
## Overcast is what the sky looks like, not what the port earns — same rule as
## rain. Rain always implies it.
const OVERCAST_CHANCE := 0.30

var day: int = 1
var time_of_day: float = 0.3   # 0..1 (0 = midnight). Start mid-morning.
var fog_active: bool = false
var rain_active: bool = false
var overcast: bool = false
## 0 calm, 1 blowing. The windsocks and the pennants read it, and so does the
## clock; nothing in the economy does.
var wind: float = 0.35
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
	# The monsoon port (Shanghai) fogs over far more often.
	fog_active = randf() < float(PortDB.port_trait("fog_chance", FOG_CHANCE))
	if was != fog_active:
		EventBus.fog_changed.emit(fog_active)
		GameState.recompute()
	wind = clampf(randf_range(0.05, 1.0), 0.0, 1.0)
	var was_wet := rain_active
	# Never both: fog and driving rain at once is unreadable rather than moody.
	rain_active = not fog_active and randf() < RAIN_CHANCE
	if was_wet != rain_active:
		EventBus.rain_changed.emit(rain_active)
	overcast = rain_active or randf() < OVERCAST_CHANCE


func weather_glyph() -> int:
	## Which face the port clock shows. Order matters: fog is the one that changes
	## how the port works, so it wins over how the sky looks.
	if fog_active:
		return 4
	if rain_active:
		return 3
	if overcast:
		return 2
	return 1 if phase() == &"night" else 0


func clock_text() -> String:
	var minutes := int(time_of_day * 24.0 * 60.0)
	@warning_ignore("integer_division")
	var hour := minutes / 60
	return "%02d:%02d" % [hour % 24, minutes % 60]


func weather_cps_mult() -> float:
	# There is no radar_neblina upgrade in the current catalog.  Keeping a
	# hidden reference here made fog behavior depend on an impossible state.
	# An automated port works through the fog.
	if fog_active and not bool(PortDB.port_trait("fog_free", false)):
		return 0.8
	return 1.0


func to_save() -> Dictionary:
	return {"day": day, "time_of_day": time_of_day, "fog_active": fog_active,
		"rain_active": rain_active, "overcast": overcast, "wind": wind}


func from_save(data: Dictionary) -> void:
	day = maxi(1, int(data.get("day", 1)))
	time_of_day = clampf(float(data.get("time_of_day", 0.3)), 0.0, 0.999999)
	fog_active = bool(data.get("fog_active", false))
	rain_active = bool(data.get("rain_active", false))
	overcast = bool(data.get("overcast", false)) or rain_active
	wind = clampf(float(data.get("wind", 0.35)), 0.0, 1.0)
	speed_mult = 1.0
	_phase = _compute_phase()
