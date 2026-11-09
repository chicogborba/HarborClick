extends Node
## One close-up of the running game, for judging art at the pixel.
##
##   godot --path . tools/capture/closeup.tscn -- rail
##   godot --path . tools/capture/closeup.tscn -- rail_shunt 3
##   godot --path . tools/capture/closeup.tscn -- yard 2.5 150 260
##   godot --path . tools/capture/closeup.tscn -- gull 3
##
## Arguments: a scenario, then optionally a zoom and a world-space centre.
## Writes `user://uishots/closeup_<scenario>.png` and quits.
##
## Why a second harness: `capture.gd` walks a whole list of shots in one
## window, and on macOS an agent's window is unfocused, so the compositor stops
## presenting frames after the first shot — every later PNG is the same stale
## picture (see tools/README.md). This takes exactly one shot per process, raises
## the window first, and waits for the frame it wants rather than a stopwatch.

const SHOT_DIR := "user://uishots"

var _main: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://capture"))
	SaveManager.set_save_path_for_tests("user://capture/harborclick_closeup.json")
	SaveManager.active_slot = -1
	GameState.from_save({})
	TimeManager.from_save({})
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var args := OS.get_cmdline_user_args()
	var scenario := String(args[0]) if args.size() > 0 else "world"
	var zoom := float(args[1]) if args.size() > 1 else 0.0
	var centre := Vector2(float(args[2]), float(args[3])) if args.size() > 3 \
		else Vector2(-1, -1)
	DisplayServer.window_set_size(Vector2i(390, 844))
	get_window().size = Vector2i(390, 844)

	_main = load("res://scenes/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	if _main.get_script() == null or _main.get("world") == null:
		printerr("[closeup] FAIL: Main did not load — look for a parse error above")
		get_tree().quit(1)
		return
	_furnish()
	var focus := await _stage(scenario)
	if centre.x >= 0.0:
		focus = centre
	var cam: Camera2D = _main.cam
	cam.set_process(false)
	if zoom > 0.0:
		cam.zoom = Vector2.ONE * zoom
	if focus.x >= 0.0:
		cam.position = focus
	await _shot("closeup_" + scenario)
	get_tree().quit(0)


func _furnish() -> void:
	for path in [^"TutorialSpotlight", ^"OfflinePopup"]:
		var node := _main.get_node_or_null(path)
		if node != null:
			node.queue_free()
	GameState.teus = 4.2e7
	GameState.lifetime_teus = 4.2e7
	GameState.all_time_teus = 4.2e7
	for item in StructureDB.ITEMS:
		GameState.owned[item.id] = 3
		GameState.best_owned_by_structure[item.id] = maxi(
			int(GameState.best_owned_by_structure.get(item.id, 0)), 3)
	GameState.recompute()
	_main.world.structures.rebuild()
	EventBus.teus_changed.emit(GameState.teus)


func _stage(scenario: String) -> Vector2:
	## Sets the scene up and returns the world point the shot is centred on
	## (x < 0 = leave the camera where it is).
	match scenario:
		"rail", "rail_shunt":
			var rail: RailYard = _main.world.rail
			rail.seed_new()
			rail._next_service = 0.01
			rail.tick(0.02)
			var deadline := Time.get_ticks_msec() + 30000
			while Time.get_ticks_msec() < deadline and not rail.is_standing():
				await get_tree().process_frame
			if scenario == "rail_shunt":
				rail.send_away()
				await get_tree().create_timer(2.6).timeout
			return Vector2(PortLayout.WORLD_W * 0.5, PortLayout.rail_y() - 4.0)
		"gull":
			# A golden gull mid-crossing, held still so the shot shows the bird
			# and its trail rather than wherever it had flown to.
			await get_tree().create_timer(1.0).timeout
			var world: PortWorld = _main.world
			world._spawn_golden_gull()
			await get_tree().create_timer(2.2).timeout
			var gull := world.active_gull()
			if gull != null:
				return gull.global_position
			return Vector2(-1, -1)
		"ship":
			await get_tree().create_timer(1.5).timeout
			return Vector2(PortLayout.WATER_X0 + 30.0, 200.0)
		"yard":
			await get_tree().create_timer(1.5).timeout
			return Vector2(150.0, 200.0)
		_:
			await get_tree().create_timer(1.5).timeout
			return Vector2(-1, -1)


func _shot(shot_name: String) -> void:
	DisplayServer.window_move_to_foreground()
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[closeup] empty image for ", shot_name)
		return
	image.save_png("%s/%s.png" % [SHOT_DIR, shot_name])
	print("[closeup] %s %dx%d" % [shot_name, image.get_size().x, image.get_size().y])
