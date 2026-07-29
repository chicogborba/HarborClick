extends Node
## SFX pool + crossfading music. Tracks follow the day/night cycle and weather.

const SFX_DIR := "res://assets/audio/"
const SFX_POOL_SIZE := 10
const MUSIC_DB := -20.0        # the music sits well under the effects
const FADE_TIME := 3.0
const SETTINGS_PATH := "user://audio.cfg"

var music_on := true
var sfx_on := true

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}
var _music: Array[AudioStreamPlayer] = []
var _music_active := 0
var _current_track := ""


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
	# Headless runners have no audible output, and keeping a looping WAV alive
	# until SceneTree.quit() makes Godot report two false-positive ObjectDB leaks.
	if DisplayServer.get_name() != "headless":
		update_music.call_deferred()


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
	if not sfx_on or DisplayServer.get_name() == "headless":
		return
	var stream := _load(sfx_name)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % SFX_POOL_SIZE
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


func update_music() -> void:
	var track := "music_day"
	if TimeManager.fog_active:
		track = "music_fog"
	elif TimeManager.phase() in [&"night", &"dusk"]:
		track = "music_night"
	play_music(track)


func play_music(track: String) -> void:
	if track == _current_track:
		return
	var stream := _load(track, true)
	if stream == null:
		return
	_current_track = track
	var incoming := _music[1 - _music_active]
	var outgoing := _music[_music_active]
	_music_active = 1 - _music_active

	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()
	var tween := create_tween().set_parallel()
	tween.tween_property(incoming, "volume_db",
		MUSIC_DB if music_on else -80.0, FADE_TIME)
	if outgoing.playing:
		tween.tween_property(outgoing, "volume_db", -80.0, FADE_TIME)
		tween.chain().tween_callback(outgoing.stop)


func set_music_on(value: bool) -> void:
	music_on = value
	for m in _music:
		if m.playing:
			var tween := create_tween()
			tween.tween_property(m, "volume_db",
				MUSIC_DB if music_on else -80.0, 0.4)
	if music_on and not _music[_music_active].playing:
		_current_track = ""
		update_music()
	_save_settings()


func set_sfx_on(value: bool) -> void:
	sfx_on = value
	_save_settings()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_on)
	config.set_value("audio", "sfx", sfx_on)
	config.save(SETTINGS_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	music_on = config.get_value("audio", "music", true)
	sfx_on = config.get_value("audio", "sfx", true)


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
		@warning_ignore("integer_division") var frames := wav.data.size() / 2   # 16-bit mono
		wav.loop_end = frames
		stream = wav
	_cache[key] = stream
	return stream
