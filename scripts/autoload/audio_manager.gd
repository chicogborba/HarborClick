extends Node
## SFX pool + crossfading music. Tracks follow the day/night cycle and weather.

const SFX_DIR := "res://assets/audio/"
const SFX_POOL_SIZE := 16
const MUSIC_DB := -20.0        # the music sits well under the effects
const FADE_TIME := 3.0
const SETTINGS_PATH := "user://audio.cfg"

## Sounds that exist as a family of near-identical takes, and how many of them
## `tools/audio/gen_sfx.py` writes. A container landing fires several times a
## second once the yard is automated: one sample at that rate stops reading as a
## port and starts reading as a stuck buffer. Families are drawn from a shuffle
## bag, so no take is ever heard twice running and all of them are used before
## any repeats.
const VARIANTS := {"thunk": 6, "click": 4, "horn": 4, "tap": 3, "voice": 10,
	"voice_rf": 8, "page_flip": 3}
## The pitch ladder a family walks, on top of `play_sfx`'s own jitter. Drawn from
## its own bag for the same reason: two consecutive plays never share a step.
const PITCH_STEPS := [0.94, 0.97, 1.0, 1.04, 1.08]

## Muted or not, and — separately — how loud when it is not.
##
## These used to be the whole of the audio settings: two on/off keys, so the only
## answer to "the music is a bit much" was silence. The mute flag stays because a
## mute that remembers the level you liked is worth having on its own, but the
## level is now a real 0..1 the player sets.
var music_on := true
var sfx_on := true
var music_volume := 0.7
var sfx_volume := 0.8

## Below this the level is silence, not a very quiet sound. `linear_to_db(0)` is
## -inf, which is correct but propagates into tweens as a NaN.
const SILENT_DB := -80.0
## Volume moves in steps the player can actually land on with a finger. A
## continuous 0..1 on a 200px track is a control you can never set twice the
## same way.
const VOLUME_STEP := 0.05

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}
var _music: Array[AudioStreamPlayer] = []
var _music_active := 0
var _current_track := ""
var _bags: Dictionary = {}     # bag key -> remaining draws, already shuffled
var _last_draw: Dictionary = {} # bag key -> the value handed out last
var _settings_path := SETTINGS_PATH

## Sounds that may not restart sooner than this, in seconds. An automated yard
## fires `thunk` many times a second, and a full pool then hard-cuts whichever
## voice is oldest; spacing the frequent ones keeps the pool for the rest.
const MIN_INTERVAL := {"voice": 0.05, "thunk": 0.045, "click": 0.03, "tap": 0.02, "combo": 0.03,
	"coins": 0.1, "wheel_tick": 0.02}
var _last_play: Dictionary = {}    # name -> ticks_msec of the last start

## Ambience: looping beds under the music. Each is a player whose level eases
## toward a target worked out from what the port is doing — the sea is always
## there, the hum swells with production, rain and wind follow the weather.
const AMBIENCE := {&"amb_sea": -24.0, &"amb_port": -30.0, &"amb_rain": -22.0,
	&"amb_wind": -28.0}
const AMBIENCE_EASE := 1.2
var _beds: Dictionary = {}          # name -> AudioStreamPlayer
var _bed_target: Dictionary = {}    # name -> 0..1
var _thunder_in := 30.0
var _muted_by_focus := false


func set_settings_path_for_tests(path: String) -> void:
	## A suite that exercises the mixer must not leave the player muted. This is
	## not hypothetical: a settings run that failed halfway through wrote
	## `music = false` into the real config and every session afterwards started
	## silent. Same shape as `SaveManager.set_save_path_for_tests`.
	_settings_path = path
	_load_settings()


func _ready() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	_load_settings()
	EventBus.day_phase_changed.connect(func(_p: StringName) -> void: update_music())
	EventBus.fog_changed.connect(func(_a: bool) -> void: update_music())
	# Moments the game used to let pass in silence, heard from here so no screen
	# has to remember to ask: a trophy, a finished call, a new day.
	EventBus.achievement_completed.connect(func(_p: Dictionary) -> void:
		play_sfx("achievement", 0.02, -2.0))
	EventBus.berth_call_completed.connect(func(_p: Dictionary) -> void:
		play_sfx("berth_done", 0.02, -3.0))
	EventBus.new_day.connect(func(_d: int) -> void: play_sfx("new_day", 0.0, -4.0))
	EventBus.rain_changed.connect(func(_on: bool) -> void: _refresh_bed_targets())
	if DisplayServer.get_name() != "headless":
		_build_beds.call_deferred()
	# Headless runners have no audible output, and keeping a looping WAV alive
	# until SceneTree.quit() makes Godot report two false-positive ObjectDB leaks.
	if DisplayServer.get_name() != "headless":
		update_music.call_deferred()


func _build_beds() -> void:
	for bed: StringName in AMBIENCE:
		var stream := _load(String(bed), true)
		if stream == null:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = SILENT_DB
		add_child(p)
		p.play()
		_beds[bed] = p
		_bed_target[bed] = 0.0
	_refresh_bed_targets()


func _refresh_bed_targets() -> void:
	## What each bed should be doing right now, 0..1.
	var busy := clampf(log(maxf(GameState.cps, 1.0)) / log(1.0e6), 0.0, 1.0)
	var raining := TimeManager.rain_active
	_bed_target[&"amb_sea"] = 1.0
	_bed_target[&"amb_port"] = 0.25 + 0.75 * busy
	_bed_target[&"amb_rain"] = 1.0 if raining else 0.0
	_bed_target[&"amb_wind"] = clampf(TimeManager.wind, 0.0, 1.0) * (1.0 if raining else 0.45)


func _process(delta: float) -> void:
	if _beds.is_empty():
		return
	_bed_refresh_in -= delta
	if _bed_refresh_in <= 0.0:
		_bed_refresh_in = 2.0
		_refresh_bed_targets()
	var step := clampf(delta / AMBIENCE_EASE, 0.0, 1.0)
	for bed: StringName in _beds:
		var p: AudioStreamPlayer = _beds[bed]
		var want := SILENT_DB
		if sfx_audible() and float(_bed_target.get(bed, 0.0)) > 0.01:
			want = float(AMBIENCE[bed]) + linear_to_db(float(_bed_target[bed])) \
				+ linear_to_db(sfx_volume)
		p.volume_db = lerpf(p.volume_db, want, step)
	# Thunder rolls in now and then while it rains — distant, never on a beat.
	if TimeManager.rain_active and sfx_audible():
		_thunder_in -= delta
		if _thunder_in <= 0.0:
			_thunder_in = randf_range(28.0, 75.0)
			play_sfx("amb_thunder", 0.04, -9.0)
	else:
		_thunder_in = maxf(_thunder_in, 20.0)


var _bed_refresh_in := 0.0


func _notification(what: int) -> void:
	## An idle game is backgrounded constantly, and a port that keeps humming from
	## a pocket is a reason to uninstall it. Mute the master bus while the game is
	## not the thing in front of the player.
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_set_focus_mute(true)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_set_focus_mute(false)


func _set_focus_mute(value: bool) -> void:
	if value == _muted_by_focus or DisplayServer.get_name() == "headless":
		return
	_muted_by_focus = value
	AudioServer.set_bus_mute(0, value)


func _exit_tree() -> void:
	## Tests can close the SceneTree on the same frame as a click sound. Stop and
	## release the streams explicitly so AudioStreamPlayback objects cannot outlive
	## their pool during shutdown.
	for player in _pool:
		player.stop()
		player.stream = null
	for player in _music:
		player.stop()
		player.stream = null
	_cache.clear()


func play_sfx(sfx_name: String, pitch_jitter: float = 0.06, volume_db: float = 0.0) -> void:
	if not sfx_audible() or DisplayServer.get_name() == "headless" \
			or _pool.is_empty():
		return
	if MIN_INTERVAL.has(sfx_name):
		var now := Time.get_ticks_msec()
		if float(now - int(_last_play.get(sfx_name, -100000))) \
				< float(MIN_INTERVAL[sfx_name]) * 1000.0:
			return
		_last_play[sfx_name] = now
	var take := pick_variant(sfx_name)
	var stream := _load(take)
	if stream == null and take != sfx_name:
		# A family whose takes have not been generated yet still makes a sound.
		stream = _load(sfx_name)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % SFX_POOL_SIZE
	p.stream = stream
	p.pitch_scale = family_pitch(sfx_name) \
		* (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	p.volume_db = volume_db + sfx_gain_db()
	p.play()


func play_sfx_pitched(sfx_name: String, pitch: float,
		volume_db: float = 0.0) -> void:
	## An exact pitch instead of a drawn one. The stacking minigame walks a rising
	## scale as the tower grows, and a ladder that means something cannot be a
	## shuffle bag.
	if not sfx_audible() or DisplayServer.get_name() == "headless" \
			or _pool.is_empty():
		return
	var take := pick_variant(sfx_name)
	var stream := _load(take)
	if stream == null and take != sfx_name:
		stream = _load(sfx_name)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % SFX_POOL_SIZE
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = volume_db + sfx_gain_db()
	p.play()


func pick_variant(sfx_name: String) -> String:
	## The file to play for this event. Single sounds are returned untouched;
	## families hand back the next take in their shuffle bag.
	var count := int(VARIANTS.get(sfx_name, 0))
	if count <= 1:
		return sfx_name
	return "%s_%d" % [sfx_name, _draw(sfx_name + ":take", count) + 1]


func family_pitch(sfx_name: String) -> float:
	## A step off the ladder, so two takes of the same family are also two
	## pitches. Sounds outside a family keep their exact recorded pitch.
	if not VARIANTS.has(sfx_name):
		return 1.0
	return float(PITCH_STEPS[_draw(sfx_name + ":pitch", PITCH_STEPS.size())])


func _draw(bag_key: String, count: int) -> int:
	## One value from a shuffle bag: every value is used once before the bag is
	## refilled, and a refill never opens on the value the last bag closed with —
	## which is the single repeat a bag exists to prevent.
	var bag: Array = _bags.get(bag_key, [])
	if bag.is_empty():
		for index in count:
			bag.append(index)
		bag.shuffle()
		if bag.size() > 1 and int(bag[0]) == int(_last_draw.get(bag_key, -1)):
			bag.append(bag.pop_front())
	var value := int(bag.pop_front())
	_bags[bag_key] = bag
	_last_draw[bag_key] = value
	return value


## A quicker fade for the shop: the board opens in a moment, and a three-second
## swell would still be arriving after the player had bought and left.
const SHOP_FADE := 1.2
var _shop_music := false
var _music_tween: Tween


func set_shop_music(on: bool) -> void:
	## The shop has its own loop, in the day loop's key so the two blend instead
	## of jumping. In and out on a short crossfade; the sky loop resumes after.
	if _shop_music == on:
		return
	_shop_music = on
	update_music(SHOP_FADE)


func update_music(fade: float = FADE_TIME) -> void:
	## Six loops, one per sky: rain and fog outrank the clock, then the phase.
	## The shop loop outranks them all while the shop is open.
	if _shop_music:
		play_music("music_shop", fade)
		return
	var track := "music_day"
	if TimeManager.rain_active:
		track = "music_rain"
	elif TimeManager.fog_active:
		track = "music_fog"
	else:
		match TimeManager.phase():
			&"dawn": track = "music_dawn"
			&"dusk": track = "music_dusk"
			&"night": track = "music_night"
	play_music(track, fade)


func play_music(track: String, fade: float = FADE_TIME) -> void:
	if track == _current_track:
		return
	# A headless run has nowhere to send audio, and starting a looping stream it
	# will never hear keeps an AudioStreamPlaybackWAV alive until the process
	# ends — which Godot then reports as a leaked instance. `_ready` already
	# declined to start the music here; the guard belongs on the entry point so
	# that turning the music on from a headless test cannot start it either.
	if DisplayServer.get_name() == "headless":
		_current_track = track
		return
	var stream := _load(track, true)
	if stream == null:
		return
	_current_track = track
	var incoming := _music[1 - _music_active]
	var outgoing := _music[_music_active]
	_music_active = 1 - _music_active

	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	# A shop opened and shut inside one fade swaps the two players back before
	# the first fade ends; its "stop the outgoing one" would then silence the
	# player that just came back in. Only the newest fade may finish.
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	var tween := create_tween().set_parallel()
	_music_tween = tween
	tween.tween_property(incoming, "volume_db", music_gain_db(), fade)
	if outgoing.playing:
		tween.tween_property(outgoing, "volume_db", SILENT_DB, fade)
		tween.chain().tween_callback(outgoing.stop)


# --------------------------------------------------------------- levels

func music_gain_db() -> float:
	## What a music player should be sitting at right now. `MUSIC_DB` is the bed
	## the track was mixed against; the player's level rides on top of it, so
	## 100% is the mix as authored rather than as loud as the file goes.
	if not music_audible():
		return SILENT_DB
	return MUSIC_DB + linear_to_db(music_volume)


func sfx_gain_db() -> float:
	return SILENT_DB if not sfx_audible() else linear_to_db(sfx_volume)


func music_audible() -> bool:
	return music_on and music_volume > 0.0


func sfx_audible() -> bool:
	return sfx_on and sfx_volume > 0.0


func set_music_on(value: bool) -> void:
	music_on = value
	_apply_music_level(0.4)
	_save_settings()


func set_sfx_on(value: bool) -> void:
	sfx_on = value
	_save_settings()


func set_music_volume(value: float) -> void:
	var wanted := clamp_volume(value)
	if is_equal_approx(music_volume, wanted):
		return
	music_volume = wanted
	# Straight to the new level, not faded: a player dragging a volume slider is
	# listening for the change they are making, and a 0.4s ramp behind every step
	# of the drag turns the control into a guess.
	_apply_music_level(0.0)
	_save_settings()


func set_sfx_volume(value: float) -> void:
	var wanted := clamp_volume(value)
	if is_equal_approx(sfx_volume, wanted):
		return
	sfx_volume = wanted
	_save_settings()


static func clamp_volume(value: float) -> float:
	if not is_finite(value):
		return 0.0
	return clampf(snappedf(value, VOLUME_STEP), 0.0, 1.0)


func _apply_music_level(fade: float) -> void:
	var target := music_gain_db()
	for m in _music:
		if not m.playing:
			continue
		if fade <= 0.0:
			m.volume_db = target
			continue
		var tween := create_tween()
		tween.tween_property(m, "volume_db", target, fade)
	# Coming back from silence has nothing playing to raise, so the track has to
	# be started again rather than turned up.
	if music_audible() and not _music[_music_active].playing:
		_current_track = ""
		update_music()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_on)
	config.set_value("audio", "sfx", sfx_on)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(_settings_path)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(_settings_path) != OK:
		return
	music_on = config.get_value("audio", "music", true)
	sfx_on = config.get_value("audio", "sfx", true)
	# Absent from every file written while the settings were on/off only. Those
	# players chose "on", and the level they meant by it is the default one.
	music_volume = clamp_volume(float(config.get_value("audio", "music_volume",
		music_volume)))
	sfx_volume = clamp_volume(float(config.get_value("audio", "sfx_volume",
		sfx_volume)))


func _load(stream_name: String, looping: bool = false) -> AudioStream:
	var key := stream_name + ("_loop" if looping else "")
	if _cache.has(key):
		return _cache[key]
	var path := SFX_DIR + stream_name + ".wav"
	if not ResourceLoader.exists(path):
		_cache[key] = null
		return null
	var stream: AudioStream = load(path)
	if looping and stream is AudioStreamWAV:
		var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		# 16-bit samples: two bytes a frame for mono, four for stereo.
		@warning_ignore("integer_division") var frames := wav.data.size() / (4 if wav.stereo else 2)
		wav.loop_end = frames
		stream = wav
	_cache[key] = stream
	return stream
