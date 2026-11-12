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
	var args := Array(OS.get_cmdline_user_args())
	if args.size() > 0 and String(args[0]).begins_with("lang="):
		Loc.set_language_for_tests(StringName(String(args[0]).substr(5)))
		args.remove_at(0)
	# `port=long_beach` photographs another port: its ground, plant, water and
	# catalogue, on the capture profile.
	if args.size() > 0 and String(args[0]).begins_with("port="):
		PortDB.set_active(StringName(String(args[0]).substr(5)))
		args.remove_at(0)
	# `size=1372x1360` photographs another window shape. A desktop window is
	# nothing like a phone, and the shop once opened wider than the screen in one.
	var window_size := Vector2i(390, 844)
	if args.size() > 0 and String(args[0]).begins_with("size="):
		var parts := String(args[0]).substr(5).split("x")
		window_size = Vector2i(int(parts[0]), int(parts[1]))
		args.remove_at(0)
	var scenario := String(args[0]) if args.size() > 0 else "world"
	var zoom := float(args[1]) if args.size() > 1 else 0.0
	var centre := Vector2(float(args[2]), float(args[3])) if args.size() > 3 \
		else Vector2(-1, -1)
	DisplayServer.window_set_size(window_size)
	get_window().size = window_size

	_main = load("res://scenes/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().create_timer(1.0).timeout
	if _main.get_script() == null or _main.get("world") == null:
		printerr("[closeup] FAIL: Main did not load — look for a parse error above")
		get_tree().quit(1)
		return
	# `fresh*` scenarios photograph a brand-new profile: nothing bought, and for
	# plain `fresh` the tutorial still up — the first thing a new player sees.
	if not scenario.begins_with("fresh") and not scenario.begins_with("tour"):
		await _furnish()
	elif scenario != "fresh" and not scenario.begins_with("tour"):
		for path in [^"TutorialSpotlight", ^"OfflinePopup"]:
			var node := _main.get_node_or_null(path)
			if node != null:
				node.queue_free()
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
	# A queue_free only lands at the end of the frame it was asked in; a
	# scenario that opens a board right after furnishing (the inspection)
	# must not be told "the tour is still up" by a node on its way out.
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.teus = 4.2e7
	GameState.lifetime_teus = 4.2e7
	GameState.all_time_teus = 4.2e7
	for item in StructureDB.ITEMS:
		GameState.owned[item.id] = 3
		GameState.best_owned_by_structure[item.id] = maxi(
			int(GameState.best_owned_by_structure.get(item.id, 0)), 3)
	GameState.recompute()
	# A furnished port is a grown one: every gated key is on the HUD.
	_main.level_service.rules.add_xp(TerminalLevel.xp_for_level(18))
	_main.level_service.xp_changed.emit()
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
		"levelup", "levelup_feature":
			# The level-up card with the ad offer: level 6 opens the wheel, 4 nothing.
			var target := 6 if scenario == "levelup_feature" else 4
			var rules: TerminalLevel = _main.level_service.rules
			rules.level = target - 1
			rules.xp = TerminalLevel.xp_for_level(target) - 1
			_main.level_service._add(1)
			await get_tree().create_timer(0.8).timeout
			return Vector2(-1, -1)
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
		"tour_ship", "tour_shop", "tour_bell":
			# Alisson's tour, at the step named, on a brand-new profile.
			var tour: TutorialSpotlight = _main.tutorial
			var deadline := Time.get_ticks_msec() + 25000
			while Time.get_ticks_msec() < deadline and not _main._ship_is_working():
				await get_tree().process_frame
			if scenario == "tour_bell":
				tour._finish(true)
				_main.bell.open_log()
			else:
				tour._index = 3 if scenario == "tour_ship" else 5
				if scenario == "tour_shop":
					GameState.teus = 40.0
					_main.shop._on_tab("structures")
					await get_tree().create_timer(0.8).timeout
				tour._show_step()
				tour._body.visible_characters = -1
			await get_tree().create_timer(1.0).timeout
			return Vector2(-1, -1)
		"wheel_panel", "shop_lock":
			# The wheel board waiting on its clock, or the shop with a machine
			# shut behind an unbought parcel.
			if scenario == "wheel_panel":
				_main.wheel_service.wheel.next_free_unix = \
					Time.get_unix_time_from_system() + 5.0 * 3600.0 + 1900.0
				_main.wheel_panel.open()
			else:
				GameState.land.clear()
				GameState.lifetime_teus = 1.0e9
				GameState.teus = 1.0e9
				if not _main.shop.visible:
					_main.shop.toggle()
				await get_tree().create_timer(0.6).timeout
				_main.shop._on_tab("structures")
				_main.shop._refresh()
			await get_tree().create_timer(1.2).timeout
			return Vector2(-1, -1)
		"diary":
			_main.bell.open_log()
			await get_tree().create_timer(1.0).timeout
			_main.bell._set_tab("medals")
			await get_tree().create_timer(0.8).timeout
			return Vector2(-1, -1)
		"ports", "ports_lb":
			# The PORTOS board: the globe, the pins, the selected port's card.
			GameState.teus = 9e9
			_main.routes.open()
			if scenario == "ports_lb":
				_main.routes._select(&"long_beach")
			await get_tree().create_timer(1.2).timeout
			return Vector2(-1, -1)
		"shop_rise":
			# The clipboard on its way up: board and open clip below the mark.
			_main.shop.toggle()
			await get_tree().create_timer(0.11).timeout
			return Vector2(-1, -1)
		"journal", "journal_cover", "journal_flip":
			# The logbook: open and read; its cover mid-swing; a leaf turning.
			_main.journal.open("next")
			if scenario == "journal_cover":
				await get_tree().create_timer(BookFx.SWING_AT + 0.12).timeout
				return Vector2(-1, -1)
			await get_tree().create_timer(1.0).timeout
			if scenario == "journal_flip":
				_main.journal._select_tab("troph")
				await get_tree().create_timer(0.09).timeout
			return Vector2(-1, -1)
		"shop_upgrades":
			if not _main.shop.visible:
				_main.shop.toggle()
			await get_tree().create_timer(0.6).timeout
			_main.shop._on_tab("upgrades")
			await get_tree().create_timer(1.0).timeout
			return Vector2(-1, -1)
		"roadmap":
			_main.roadmap.open()
			await get_tree().create_timer(1.2).timeout
			return Vector2(-1, -1)
		"tour_idle":
			# The hello, read: Alisson waiting with his ball in the air.
			await get_tree().create_timer(2.0).timeout
			_main.tutorial._body.visible_characters = -1
			await get_tree().create_timer(0.95).timeout
			return Vector2(-1, -1)
		"tour_tip":
			# Alisson back after the tour with one line about the shop.
			_main.tutorial._finish(true)
			_main.tutorial.tip("land", "guide.tip.land", "shop")
			await get_tree().create_timer(3.5).timeout
			return Vector2(-1, -1)
		"tour_receita":
			# Leôncio's entrance after the tour: the X-ray scanner pitch, read.
			_main.tutorial._finish(true)
			_main.tutorial.tip("receita", "receita.tip.intro", "", &"receita")
			await get_tree().create_timer(2.5).timeout
			_main.tutorial._body.visible_characters = -1
			await get_tree().create_timer(1.2).timeout
			return Vector2(-1, -1)
		"xray_post", "xray_post_due":
			# The Receita's post in the yard: boarded up, or lit red with a "!".
			if scenario == "xray_post_due":
				_main.xray_service.policy.buy()
				_main.xray_service.policy.ready = true
			_main.xray_service.state_changed.emit()
			await get_tree().create_timer(1.0).timeout
			return _main.world.xray_station.centre()
		"xray_panel", "tour_xray_due":
			# The scanner's board before purchase, or Leôncio pointing at its key
			# with an inspection waiting.
			GameState.flags["tutorial_v2_done"] = true
			var flags: Dictionary = GameState.flags.get("guide_tips", {})
			flags["receita"] = true
			GameState.flags["guide_tips"] = flags
			_main._refresh_xray_key()
			if scenario == "xray_panel":
				_main.xray_panel.open()
			else:
				_main.tutorial._finish(true)
				_main.xray_service.policy.buy()
				_main.xray_service.policy.ready = true
				_main.xray_service.state_changed.emit()
				_main._announce_inspection()
				await get_tree().create_timer(2.5).timeout
				_main.tutorial._body.visible_characters = -1
			await get_tree().create_timer(1.2).timeout
			return Vector2(-1, -1)
		"xray_roll", "xray_boot", "xray_scan", "xray_miss", "xray_raw", "xray_coach":
			# The inspection board at each beat: the lorry in the portal with
			# its picture arriving, the splash, the first-scan card, the raw
			# view, a filter view, and a filter view after a wrong tap.
			_main.xray_service.policy.buy()
			_main.xray_service.policy.ready = true
			_main._open_xray()
			await get_tree().create_timer(0.3).timeout
			var board: XrayMinigame = _main.xray_board
			match scenario:
				"xray_roll":
					await get_tree().create_timer(1.6).timeout
				"xray_boot":
					board._set_phase(XrayMinigame.Phase.BOOT)
					await get_tree().create_timer(0.6).timeout
				_:
					board._set_phase(XrayMinigame.Phase.SCAN)
					await get_tree().create_timer(0.8).timeout
					# The picture says the whole rule: the view that shows the
					# contraband with the reticle parked on it (xray_scan), the
					# raw view nothing can be seized in (xray_raw), or an
					# ordinary thing a wrong tap has just cost seconds for
					# (xray_miss).
					if scenario == "xray_coach":
						board.set_process(false)
						return Vector2(-1, -1)
					GameState.flags["xray_coached2"] = true
					board._coach.visible = false
					var pick: Dictionary = board.game.contraband()
					if scenario == "xray_miss":
						for item: Dictionary in board.game.items:
							if not bool(item.contraband) and item.behind == &"carton":
								pick = item
								break
					if scenario != "xray_raw":
						board._pick_filter(XrayScan.filter_for(pick))
						await get_tree().create_timer(0.4).timeout
					board._reticle = board._to_screen(pick.pos)
					if scenario == "xray_miss":
						board._seize_at(board._to_screen(pick.pos))
						await get_tree().create_timer(0.3).timeout
			board.set_process(false)
			return Vector2(-1, -1)
		"fresh_played":
			# Thirty taps into a new profile: the port a player has after their
			# first minute, before the first purchase changes anything.
			await get_tree().create_timer(8.0).timeout
			return Vector2(-1, -1)
		"wake", "wake_stern":
			# A hull making way up the channel, driven by hand so the wake's
			# strength comes from real movement and not a forced uniform. The
			# game's own arrival tween is stopped first or it wins every frame.
			for running in get_tree().get_processed_tweens():
				running.kill()
			var hull: Ship = _main.world.ship
			hull.visible = true
			hull._set_phase(Ship.Phase.ARRIVING)
			hull._under_way = true
			hull._refresh_wake_state()
			var stern := scenario == "wake_stern"
			hull.position = Vector2(PortLayout.FAIRWAY_X, -40.0 if stern else 200.0)
			for step in 50:
				hull.position.y -= 1.6
				await get_tree().process_frame
			return Vector2(PortLayout.WATER_X0 - 10.0,
				hull.position.y + (hull.hull_height() + 40.0 if stern else 110.0))
		"ship":
			# The laytime clock only runs after the tour.
			GameState.flags["tutorial_v2_done"] = true
			await get_tree().create_timer(9.0).timeout
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
