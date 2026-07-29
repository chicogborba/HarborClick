extends Node
## Frame-time measurement under the worst terminal the game can produce.
##
##   godot --path . tools/capture/perf.tscn -- 390x844
##   godot --path . tools/capture/perf.tscn -- 1920x1080
##
## Headless says nothing useful about frame cost, so this runs windowed and
## times real frames. The stress scenario is every structure at its display
## cap, every parcel bought, the yard packed to the top of every stack, fog
## rolling and the flood lights struck — i.e. everything on screen at once.
##
## Exits non-zero if the 95th percentile misses the 60 FPS budget.

const BUDGET_MS := 1000.0 / 60.0
const WARMUP := 1.5
const SAMPLE_SECONDS := 6.0

var _main: Node
var _samples: PackedFloat64Array = []
var _sampling := false
var _elapsed := 0.0
var _size := Vector2i(390, 844)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("x")
		if parts.size() == 2 and parts[0].is_valid_int():
			_size = Vector2i(int(parts[0]), int(parts[1]))
	DisplayServer.window_set_size(_size)
	get_window().size = _size
	# Vsync would pin every sample to the refresh interval and report the
	# monitor's rate instead of the frame's real cost.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	_main = load("res://scenes/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	await _build_stress()
	await get_tree().create_timer(WARMUP).timeout
	_sampling = true


func _build_stress() -> void:
	var tutorial := _main.get_node_or_null(^"TutorialSpotlight")
	if tutorial != null:
		tutorial.queue_free()
	var offline := _main.get_node_or_null(^"OfflinePopup")
	if offline != null:
		offline.queue_free()

	GameState.teus = 1e30
	GameState.lifetime_teus = 1e30
	GameState.all_time_teus = 1e30
	EventBus.teus_changed.emit(GameState.teus)
	for item in StructureDB.ITEMS:
		for n in 40:
			GameState.buy_structure(item.id)
	for parcel in LandDB.ITEMS:
		if not GameState.land.has(parcel.id):
			GameState.land[parcel.id] = true
			EventBus.land_bought.emit(parcel.id)
			await get_tree().process_frame
	var yard: ContainerYard = _main.world.yard
	for slot in yard.total_slots():
		for level in PortLayout.STACK_MAX:
			yard.place(slot, level, randi() % 8)
	TimeManager.time_of_day = 0.93
	TimeManager.fog_active = true
	EventBus.fog_changed.emit(true)
	_main.cam.position.y = PortLayout.world_bottom() * 0.4
	var actors := 0
	for node in _main.world.entities.get_children() + _main.world.overhead.get_children():
		actors += 1 if node is StructureActor else 0
	print("[perf] stress built: %d yard slots, world %d px tall, %d visible machines"
		% [yard.total_slots(), int(PortLayout.world_bottom()), actors])


func _process(delta: float) -> void:
	if not _sampling:
		return
	_samples.append(delta * 1000.0)
	_elapsed += delta
	if _elapsed < SAMPLE_SECONDS:
		return
	_sampling = false
	_report()


func _report() -> void:
	var sorted := Array(_samples)
	sorted.sort()
	var p50 := float(sorted[int(sorted.size() * 0.50)])
	var p95 := float(sorted[int(sorted.size() * 0.95)])
	var worst := float(sorted[sorted.size() - 1])
	print("[perf] %dx%d  frames=%d  p50=%.2fms (%.0f fps)  p95=%.2fms  worst=%.2fms  budget=%.2fms"
		% [_size.x, _size.y, _samples.size(), p50, 1000.0 / maxf(p50, 0.001),
			p95, worst, BUDGET_MS])
	if p95 > BUDGET_MS:
		printerr("[perf] FAIL: p95 %.2fms misses the 60 FPS budget" % p95)
		get_tree().quit(1)
		return
	print("[perf] PASS")
	get_tree().quit(0)
