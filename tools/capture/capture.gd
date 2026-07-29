extends Node
## Headed screenshot harness. Boots the real game scene, drives the overlays and
## writes framed PNGs so UI work can be judged — and regressions caught —
## without a human in the loop.
##
##   godot --path . tools/capture/capture.tscn -- 390x844
##   godot --path . tools/capture/capture.tscn -- matrix
##   godot --path . tools/capture/capture.tscn -- 1280x720 shop settings
##
## `matrix` walks the QA resolution list in one run, resizing the live window
## between passes, which is also the resize/rotation test: every overlay has to
## re-lay itself out without a restart.

const SHOT_DIR := "user://uishots"

## The QA matrix from the roadmap: compact phone, tall Android, modern iPhone,
## wide Android, tablet portrait, notebook and desktop 16:9.
const MATRIX := [
	Vector2i(320, 568), Vector2i(360, 800), Vector2i(390, 844),
	Vector2i(412, 915), Vector2i(768, 1024), Vector2i(1280, 720),
	Vector2i(1920, 1080),
]

var _main: Node
var _wanted: PackedStringArray = []
var _sizes: Array[Vector2i] = []
var _prefix := ""
var _failures: PackedStringArray = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	for arg in OS.get_cmdline_user_args():
		if arg == "matrix":
			_sizes.assign(MATRIX)
		elif arg.contains("x") and arg.split("x").size() == 2 \
				and arg.split("x")[0].is_valid_int():
			var parts := arg.split("x")
			_sizes.append(Vector2i(int(parts[0]), int(parts[1])))
		else:
			_wanted.append(arg)
	if _sizes.is_empty():
		_sizes.append(Vector2i(390, 844))

	if _wanted.size() == 1 and _wanted[0] == "title":
		# The title screen has no Main behind it, so it is captured on its own.
		var title: Node = load("res://scenes/Title.tscn").instantiate()
		add_child(title)
		for size in _sizes:
			_prefix = "%dx%d_" % [size.x, size.y] if _sizes.size() > 1 else ""
			DisplayServer.window_set_size(size)
			get_window().size = size
			await get_tree().create_timer(0.4).timeout
			_check("title", title.get_node(^"../Title/PanelContainer")
				if title.has_node(^"../Title/PanelContainer") else title._board, size)
			await _shot("title")
		if not _failures.is_empty():
			for failure in _failures:
				printerr("[capture] FAIL: ", failure)
			get_tree().quit(1)
			return
		print("[capture] all layout checks passed")
		get_tree().quit(0)
		return

	_main = load("res://scenes/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	_prepare()
	for size in _sizes:
		_prefix = "%dx%d_" % [size.x, size.y] if _sizes.size() > 1 else ""
		DisplayServer.window_set_size(size)
		get_window().size = size
		await get_tree().process_frame
		await get_tree().create_timer(0.35).timeout
		await _run(size)
	if _failures.is_empty():
		print("[capture] all layout checks passed")
	else:
		for failure in _failures:
			printerr("[capture] FAIL: ", failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _wants(shot: String) -> bool:
	return _wanted.is_empty() or _wanted.has(shot)


func _prepare() -> void:
	var tutorial := _main.get_node_or_null(^"TutorialSpotlight")
	if tutorial != null:
		tutorial.queue_free()
	var offline := _main.get_node_or_null(^"OfflinePopup")
	if offline != null:
		offline.queue_free()
	GameState.teus = 4.2e7
	GameState.lifetime_teus = 4.2e7
	GameState.all_time_teus = 4.2e7
	EventBus.teus_changed.emit(GameState.teus)
	for item in StructureDB.ITEMS:
		for n in 3:
			GameState.buy_structure(item.id)


func _run(size: Vector2i) -> void:
	if _wants("world"):
		await _shot("world")
	# Night and the wake are about the world, not the layout, so across a whole
	# matrix run they are captured once rather than at all seven sizes — they
	# were more than half the wall clock of a full sweep.
	var world_pass := _sizes.size() == 1 or size == _sizes[0]
	if _wants("night") and world_pass:
		# Reflections and flood lights only exist after dark, so they need
		# their own pass rather than whatever the clock happens to say.
		var was := TimeManager.time_of_day
		TimeManager.time_of_day = 0.95
		await get_tree().create_timer(2.6).timeout
		await _shot("night")
		TimeManager.time_of_day = was
		await get_tree().create_timer(0.4).timeout
	if _wants("wake") and world_pass:
		# Driving the hull by hand rather than racing the arrival tween, which
		# would otherwise keep overwriting the position we parked it at. The
		# wake strength is derived from real movement, so this is the genuine
		# state and not a forced uniform.
		var ship: Ship = _main.world.ship
		ship.visible = true
		ship._set_phase(Ship.Phase.ARRIVING)
		ship.position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y + 210.0)
		for step in 40:
			ship.position.y -= 2.6
			ship._process(1.0 / 60.0)
			_main.world._feed_water_shader()
			await get_tree().process_frame
		await _shot("wake")
	if _wants("shop"):
		_main.shop._on_tab("structures")
		await get_tree().create_timer(0.4).timeout
		_check("shop", _main.shop._board, size)
		await _shot("shop")
	if _wants("upgrades"):
		_main.shop._on_tab("upgrades")
		await get_tree().create_timer(0.3).timeout
		await _shot("shop_upgrades")
	if _wants("land"):
		_main.shop._on_tab("land")
		await get_tree().create_timer(0.3).timeout
		await _shot("shop_land")
	_main.shop._close()
	await get_tree().create_timer(0.2).timeout
	if _wants("settings"):
		_main.settings.open()
		await get_tree().create_timer(0.3).timeout
		_check("settings", _main.settings._panel, size)
		await _shot("settings")
		_main.settings.close()
		await get_tree().create_timer(0.2).timeout
	if _wants("routes"):
		_main.routes.open()
		await get_tree().create_timer(0.3).timeout
		_check("routes", _main.routes._sheet, size)
		await _shot("routes")
		_main.routes.close()
		await get_tree().create_timer(0.2).timeout
	if _wants("journal"):
		_main.journal.open()
		await get_tree().create_timer(0.3).timeout
		_check("journal", _main.journal._sheet, size)
		await _shot("journal")
		_main.journal.close()
		await get_tree().create_timer(0.2).timeout
	if _wants("prestige"):
		_main.prestige_dialog.open()
		await get_tree().create_timer(0.3).timeout
		_check("prestige", _main.prestige_dialog._panel, size)
		await _shot("prestige")
		_main.prestige_dialog.close()
		await get_tree().create_timer(0.2).timeout


func _check(what: String, panel: Control, size: Vector2i) -> void:
	## No overlay may hang off the viewport at any resolution in the matrix.
	if panel == null:
		return
	var view := get_viewport().get_visible_rect()
	var rect := panel.get_global_rect()
	if rect.position.x < view.position.x - 0.5 or rect.position.y < view.position.y - 0.5 \
			or rect.end.x > view.end.x + 0.5 or rect.end.y > view.end.y + 0.5:
		# The minimum size is reported because that is almost always the cause:
		# a container can never be laid out smaller than its own content.
		_failures.append("%s at %dx%d spills outside the viewport (%s vs %s, min %s)"
			% [what, size.x, size.y, rect, view, panel.get_combined_minimum_size()])


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[capture] empty image for ", shot_name)
		return
	image.save_png("%s/%s%s.png" % [SHOT_DIR, _prefix, shot_name])
	print("[capture] %s%s %dx%d" % [_prefix, shot_name,
		image.get_size().x, image.get_size().y])
