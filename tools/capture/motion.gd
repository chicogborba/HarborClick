extends Node
## A film strip of one piece of interface motion, for judging animation
## without a human watching.
##
##   godot --path . tools/capture/motion.tscn -- shop
##   godot --path . tools/capture/motion.tscn -- rate 10 0.04
##
## Arguments: a scenario (`shop`, `shop_tab`, `settings`, `rate`, `wheel`,
## `daily`, `ports`, `close`), then optionally how many frames and the seconds
## between them. Writes `user://uishots/motion_<scenario>.png`, the frames side
## by side at half size, and quits. A still tells you a board is in the right
## place; only a strip tells you how it got there.

const SHOT_DIR := "user://uishots"

var _main: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://capture"))
	SaveManager.set_save_path_for_tests("user://capture/harborclick_motion.json")
	SaveManager.active_slot = -1
	GameState.from_save({})
	TimeManager.from_save({})
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var args := Array(OS.get_cmdline_user_args())
	if args.size() > 0 and String(args[0]).begins_with("lang="):
		Loc.set_language_for_tests(StringName(String(args[0]).substr(5)))
		args.remove_at(0)
	var scenario := String(args[0]) if args.size() > 0 else "shop"
	var count := int(args[1]) if args.size() > 1 else 8
	var gap := float(args[2]) if args.size() > 2 else 0.05
	var window_size := Vector2i(390, 844)
	DisplayServer.window_set_size(window_size)
	get_window().size = window_size

	_main = load("res://scenes/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	if _main.get_script() == null or _main.get("world") == null:
		printerr("[motion] FAIL: Main did not load — look for a parse error above")
		get_tree().quit(1)
		return
	for path in [^"TutorialSpotlight", ^"OfflinePopup"]:
		var node := _main.get_node_or_null(path)
		if node != null:
			node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.teus = 4.2e7
	GameState.lifetime_teus = 4.2e7
	GameState.all_time_teus = 4.2e7
	for item in StructureDB.ITEMS:
		GameState.owned[item.id] = 3
		GameState.best_owned_by_structure[item.id] = 3
	GameState.recompute()
	_main.level_service.rules.add_xp(TerminalLevel.xp_for_level(18))
	_main.level_service.xp_changed.emit()
	_main.world.structures.rebuild()
	EventBus.teus_changed.emit(GameState.teus)
	await get_tree().create_timer(0.6).timeout
	DisplayServer.window_move_to_foreground()

	match scenario:
		"shop":
			_main.shop.toggle()
		"shop_tab":
			_main.shop.toggle()
			await get_tree().create_timer(0.9).timeout
			_main.shop._on_tab("upgrades")
		"close":
			_main.shop.toggle()
			await get_tree().create_timer(0.9).timeout
			_main.shop.toggle()
		"settings":
			_main.settings.open()
		"rate":
			_main.rate_breakdown.open()
		"wheel":
			_main.wheel_panel.open()
		"daily":
			_main.daily_panel.open()
		"ports":
			_main.routes.open()
		_:
			printerr("[motion] unknown scenario ", scenario)

	var frames: Array[Image] = []
	for i in count:
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if image != null and not image.is_empty():
			frames.append(image)
		await get_tree().create_timer(gap).timeout
	if frames.is_empty():
		printerr("[motion] no frames")
		get_tree().quit(1)
		return
	var cell := frames[0].get_size() / 2
	var strip := Image.create(cell.x * frames.size(), cell.y, false,
		Image.FORMAT_RGBA8)
	for i in frames.size():
		var frame := frames[i]
		frame.convert(Image.FORMAT_RGBA8)
		frame.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, cell), Vector2i(cell.x * i, 0))
	strip.save_png("%s/motion_%s.png" % [SHOT_DIR, scenario])
	print("[motion] %s %d frames" % [scenario, frames.size()])
	get_tree().quit(0)
