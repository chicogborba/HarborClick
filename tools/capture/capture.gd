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
	# Captures drive purchases, time and berth state aggressively. Keep that
	# synthetic run on its own save path so visual QA can never alter whichever
	# player profile was used most recently.
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://capture"))
	SaveManager.set_save_path_for_tests("user://capture/harborclick_capture.json")
	SaveManager.active_slot = -1
	GameState.from_save({})
	TimeManager.from_save({})
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
			# Two pages, so two checks. Measuring only the terminal board while the
			# marquee is on screen tests a panel nobody is looking at and misses
			# the one they are.
			_check("title marquee", title._actions, size)
			_check("title plate", title._plate, size)
			await _shot("title")
			title._show_board()
			await get_tree().process_frame
			await get_tree().process_frame
			_check("title board", title._board, size)
			await _shot("title_board")
			title._show_marquee()
			await get_tree().process_frame
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
	# A script that failed to compile leaves the scene up with a null root script,
	# and every shot after that quietly does nothing — the harness then printed
	# "all layout checks passed" over a game that had not started. A harness that
	# can report success without running is worse than no harness.
	if _main.get_script() == null or _main.get("world") == null:
		printerr("[capture] FAIL: Main did not load — look for a parse error above")
		get_tree().quit(1)
		return
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
	# Every visible cap has to be present in the world capture. Set the synthetic
	# inventory directly: buying each unit used to trigger dozens of immediate
	# disk saves and still stopped at the mid-game equipment when the fake
	# budget ran out.
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


func _run(size: Vector2i) -> void:
	if _wants("world"):
		_check_hud(size)
		await _shot("world")
	if _wants("clock"):
		# The clock reads the real clock, so the shot is driven to a known hour
		# rather than to whatever the run happens to be at.
		var was_time := TimeManager.time_of_day
		var was_wind := TimeManager.wind
		TimeManager.time_of_day = 0.62
		TimeManager.wind = 0.85
		TimeManager.overcast = true
		await get_tree().create_timer(0.35).timeout
		_check("clock", _main.clock._board, size)
		await _shot("clock")
		TimeManager.time_of_day = was_time
		TimeManager.wind = was_wind
		TimeManager.overcast = false
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
		# Follow the hull, or the shot is a photograph of empty water while the
		# ship it is about sits off the bottom of the frame.
		_main.cam.focus_on(ship.position.y + ship.hull_height() * 0.4, 0.2)
		await get_tree().create_timer(0.4).timeout
		for step in 40:
			ship.position.y -= 2.6
			ship._process(1.0 / 60.0)
			_main.world._feed_water_shader()
			_main.cam.position.y = ship.position.y + ship.hull_height() * 0.4
			await get_tree().process_frame
		await _shot("wake")
	if _wants("reward") and world_pass:
		# The "+N TEU" that pops when a box lands. It is the game's only feedback
		# that a tap paid, so it has to be on screen and readable.
		var paid: Ship = _main.world.ship
		paid.visible = true
		paid.position = paid.berth_position()
		paid._set_phase(Ship.Phase.DISCHARGING)
		_main.cam.focus_on(paid.position.y + paid.hull_height() * 0.5, 0.2)
		await get_tree().create_timer(0.5).timeout
		for tap in 5:
			_main.world.berth.handle_tap(
				paid.global_position + Vector2(30.0, 40.0 + tap * 18.0))
			await get_tree().create_timer(0.08).timeout
		# Land them all, which is when the reward commits and the text spawns.
		for child in _main.world.overhead.get_children():
			if child is FlyingContainer:
				(child as FlyingContainer)._finish_landing()
		await get_tree().create_timer(0.25).timeout
		var floats := 0
		for child in _main.world.overhead.get_children():
			if child is FloatText:
				floats += 1
		print("[capture] reward floats alive: %d" % floats)
		await _shot("reward")
		if floats == 0:
			_failures.append("reward at %dx%d showed no floating TEU"
				% [size.x, size.y])
	if _wants("rain") and world_pass:
		# Rain, the wet grade and the lamps it strikes, on a hull tied up with its
		# lines out — everything that is only ever seen together.
		var wet_ship: Ship = _main.world.ship
		wet_ship.visible = true
		wet_ship.position = wet_ship.berth_position()
		wet_ship._set_phase(Ship.Phase.DISCHARGING)
		TimeManager.rain_active = true
		EventBus.rain_changed.emit(true)
		_main.world.rain._amount = 1.0
		_main.cam.focus_on(wet_ship.position.y + wet_ship.hull_height() * 0.5, 0.3)
		await get_tree().create_timer(3.2).timeout
		await _shot("rain")
		TimeManager.rain_active = false
		EventBus.rain_changed.emit(false)
		_main.world.rain._amount = 0.0
		await get_tree().create_timer(0.4).timeout
	if _wants("moorings") and world_pass:
		var moored: Ship = _main.world.ship
		moored.visible = true
		moored.position = moored.berth_position()
		moored._set_phase(Ship.Phase.AWAY)
		moored._set_phase(Ship.Phase.DISCHARGING)
		_main.cam.focus_on(moored.position.y + moored.hull_height() * 0.5, 0.3)
		await get_tree().create_timer(1.6).timeout
		await _shot("moorings")
		if moored._mooring_throw < 0.9:
			_failures.append("moorings at %dx%d never finished being thrown (%.2f)"
				% [size.x, size.y, moored._mooring_throw])
	if _wants("relay") and world_pass:
		await _capture_relay()
	if _wants("transfer") and world_pass:
		await _capture_transfer_alignment()
	if _wants("gate") and world_pass:
		# The road is only worth anything if a truck is seen using it, so this
		# drives the whole cycle — in through the gate, parked on a bay, back
		# out to the city — rather than photographing an empty apron and
		# calling it a road.
		var gate: GateDock = _main.world.gate
		gate.seed_new()
		for bay in PortLayout.GATE_BAY_COUNT:
			gate._call_a_truck()
		await get_tree().create_timer(1.4).timeout
		await _shot("gate_arriving")
		# Shot the frame the first truck parks: with every machine bought, the
		# auto-movers strip its bed within a second and send it away again.
		# Timed off the wall clock, because a frame delta that comes back zero
		# turns a bounded wait into a hang.
		var deadline := Time.get_ticks_msec() + 16000
		while Time.get_ticks_msec() < deadline and _docked(gate) < 1:
			await get_tree().process_frame
		await _shot("gate_docked")
		for bay: int in gate.bays.keys():
			gate.send_away(bay)
		await get_tree().create_timer(1.5).timeout
		await _shot("gate_leaving")
	if _wants("rail") and world_pass:
		# The branch is at the very bottom of the world, so a world shot never
		# contains it. This drives a whole service — run in, stand, run round the
		# train, run out — with the camera parked on the ramp, because the shunt
		# is the part of it that has to be *seen* to be believed.
		var rail: RailYard = _main.world.rail
		rail.seed_new()
		_main.cam.focus_on(PortLayout.rail_y() - 30.0, 0.2)
		rail._next_service = 0.01
		rail.tick(0.02)
		# Wait for the *train*, not for a stopwatch. The rake starts a hundred and
		# seventy pixels west of the map and runs in at 48px/s, so the fixed 1.2s
		# pause this used to take photographed an empty corridor and filed it as
		# "arriving" — the one frame that is supposed to prove a train appears was
		# the frame guaranteed not to contain one. Held until the head of the rake
		# is properly inside the frame, and until the run-in has had long enough
		# to lay a plume behind it.
		var arrive_deadline := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < arrive_deadline:
			var running: RailRake = _main.world._rake
			if running != null and is_instance_valid(running) \
					and running._lead_x > PortLayout.rail_west_turnout_x():
				break
			await get_tree().process_frame
		await _shot("rail_arriving")
		var deadline := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < deadline and not rail.is_standing():
			await get_tree().process_frame
		await get_tree().create_timer(0.6).timeout
		await _shot("rail_standing")
		rail.send_away()
		# Mid-shunt: the locomotive on the run-around road, alongside its own
		# train. If this frame ever shows it on the running line the loop is not
		# being used and the move is a lie.
		var shunt_deadline := Time.get_ticks_msec() + 16000
		var rake: RailRake = _main.world._rake
		while Time.get_ticks_msec() < shunt_deadline and rake != null \
				and is_instance_valid(rake) \
				and absf(rake._loco.position.y - PortLayout.rail_loop_y()) > 1.0:
			await get_tree().process_frame
		await _shot("rail_runaround")
		if rake != null and is_instance_valid(rake):
			print("[capture] loco y=%.1f loop y=%.1f rail y=%.1f" % [
				rake._loco.position.y, PortLayout.rail_loop_y(),
				PortLayout.rail_y()])
		# And the answer to "did the shunt achieve anything?": the loco has to be
		# at the *west* end of its own train, leading it off the map, with the
		# headlight throwing that way. A rake photographed only on the way in
		# would never show whether the run-around was worth drawing.
		var leave_deadline := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < leave_deadline and rake != null \
				and is_instance_valid(rake) \
				and rake.mode != RailRake.Mode.RUNNING_OUT:
			await get_tree().process_frame
		await get_tree().create_timer(0.9).timeout
		await _shot("rail_departing")
		if rake != null and is_instance_valid(rake) \
				and rake._loco.position.x > PortLayout.rail_wagon_x(0):
			_failures.append("rail at %dx%d left with the loco still at the "
				% [size.x, size.y] + "buffer-stop end, pushing its own train")
	if _wants("fleet") and world_pass:
		# Three berths only exist once the quay is long enough, so the parcels are
		# bought here and the hulls forced alongside: an empty second berth proves
		# nothing about whether two ships can be worked at once.
		var world: PortWorld = _main.world
		var guard := 0
		while PortLayout.berth_count() < PortLayout.BERTH_MAX and guard < 12:
			var parcel := LandDB.next_parcel(GameState.land)
			if parcel.is_empty():
				break
			GameState.teus = 1e18
			_main.shop._on_buy_land(parcel.id)
			guard += 1
			await get_tree().create_timer(0.25).timeout
		_main.shop._close()
		for index in world.ships.size():
			var hull: Ship = world.ships[index]
			hull.visible = true
			hull.position = hull.berth_position()
			hull._set_phase(Ship.Phase.DISCHARGING)
		await get_tree().create_timer(0.6).timeout
		_main.cam.focus_on(PortLayout.berth_y(1) + 40.0, 0.3)
		await get_tree().create_timer(0.6).timeout
		print("[capture] berths: %d, hulls alongside: %d" % [
			PortLayout.berth_count(), world.working_ships().size()])
		await _shot("fleet")
		if world.working_ships().size() < PortLayout.berth_count():
			_failures.append("fleet at %dx%d has %d hulls for %d berths"
				% [size.x, size.y, world.working_ships().size(),
					PortLayout.berth_count()])
		# And the same quay with berths empty, which is when the ETA is the only
		# thing the board can usefully say.
		for index in world.ships.size():
			if index == 0:
				continue
			var idle: Ship = world.ships[index]
			idle._set_phase(Ship.Phase.AWAY)
			idle.visible = false
		world._turnaround[1] = 9.0
		_main._refresh_berth_board()
		await get_tree().create_timer(0.4).timeout
		await _shot("fleet_waiting")

		# The manoeuvre that used to slide one hull through another: the middle
		# berth sailing with both its neighbours alongside. There is no channel for
		# it, so the tugs take it straight out to sea instead, and this is the shot
		# that says so. The export ledger is forced because `depart` refuses a call
		# that is not finished, and the point here is the track, not the cargo.
		for index in world.ships.size():
			var alongside: Ship = world.ships[index]
			alongside.visible = true
			alongside.position = alongside.berth_position()
			alongside._set_phase(Ship.Phase.DISCHARGING)
		await get_tree().create_timer(0.5).timeout
		var sailing: Ship = world.ships[1]
		sailing._export_target = 1
		sailing._exported = 1
		sailing.set_flights_in_progress(0)
		_main.cam.focus_on(sailing.position.y + 60.0, 0.3)
		sailing.depart(world.lane_clear_north(1))
		# Long enough to be off the wall and on the way out, short enough to still
		# be in frame.
		await get_tree().create_timer(3.6).timeout
		print("[capture] blocked departure at x=%.1f, berth line x=%.1f"
			% [sailing.position.x, PortLayout.SHIP_X])
		await _shot("unberth")
		if sailing.position.x <= PortLayout.SHIP_X + 1.0:
			_failures.append("unberth at %dx%d never came off the wall"
				% [size.x, size.y])
	if _wants("charter"):
		# The interruption, and then the game it turns into. Both are full-screen
		# boards over a live port, so both have to fit at every size.
		var offer := SpecialCallDB.materialize(4242, 0)
		_main.special_alert.open(offer, SpecialCallDirector.OFFER_TIMEOUT)
		await get_tree().create_timer(0.35).timeout
		_check("charter", _main.special_alert._board, size)
		await _shot("charter")
		_main.special_alert.close()
		await get_tree().create_timer(0.2).timeout
	if _wants("maze"):
		# The second charter game: a different verb, so it gets its own shot.
		_main.maze.open(SpecialCallDB.get_offer(&"carga_perdida"))
		await get_tree().create_timer(0.5).timeout
		# Walk it a little so the shot shows a route taken, not a fresh grid.
		for step in 6:
			for direction in [MazeGame.EAST, MazeGame.SOUTH,
					MazeGame.NORTH, MazeGame.WEST]:
				if _main.maze.game.can_move(direction):
					_main.maze._step(direction)
					break
			await get_tree().create_timer(0.12).timeout
		_check("maze", _main.maze._board, size)
		await _shot("maze")
		if _main.maze.game.moves < 3:
			_failures.append("maze at %dx%d only moved %d times"
				% [size.x, size.y, _main.maze.game.moves])
		_main.maze.visible = false
		await get_tree().create_timer(0.2).timeout
	if _wants("minigame"):
		var game_offer := SpecialCallDB.get_offer(&"gala_relampago")
		_main.minigame.open(game_offer)
		await get_tree().create_timer(0.4).timeout
		# Stack a few by hand so the shot shows a tower rather than an empty well.
		# Deliberately off-centre by a little more each time, because the point of
		# the game is the lean and a plumb tower photographs as a column.
		for placed in 4:
			_main.minigame.game.trolley_x = _main.minigame.game.top() \
				+ StackGame.BOX_WIDTH * 0.13 * float(placed)
			_main.minigame._on_drop()
			# The next box cannot be let go until this one has landed, so wait for
			# the fall rather than guessing at a delay.
			var fall_deadline := Time.get_ticks_msec() + 2000
			while _main.minigame._falling != null \
					and Time.get_ticks_msec() < fall_deadline:
				await get_tree().process_frame
		_check("minigame", _main.minigame._board, size)
		await _shot("minigame")
		if _main.minigame.game.placed < 4:
			_failures.append("minigame at %dx%d stacked %d of 4"
				% [size.x, size.y, _main.minigame.game.placed])
		_main.minigame.visible = false
		await get_tree().create_timer(0.2).timeout
	if _wants("crew"):
		# The dossier is opened by tapping somebody in the yard, so it has to fit
		# over a live port at every size in the matrix — not just on a phone.
		var people: Array[StructureActor] = _main.world.structures.crew()
		var subject: StructureActor = null
		for candidate in people:
			if candidate.profile == null:
				continue
			# Prefer somebody with a helmet of their own: their dossier is the
			# longest, so it is the hardest to lay out, and the shot doubles as
			# the check that the tinted helmet reaches the screen.
			if subject == null or candidate.profile.wears_special_hat():
				subject = candidate
		if subject != null:
			# Bring the person on screen behind their own card: a dossier for
			# somebody the shot does not contain is half a review.
			_main.cam.focus_on(subject.global_position.y - 40.0, 0.2)
			await get_tree().create_timer(0.4).timeout
			# Where they ended up on screen, so a reviewer can crop straight to
			# them instead of hunting a nine-pixel figure in a full frame.
			print("[capture] crew subject %s (%s) at %s" % [
				subject.profile.display_name, subject.id,
				subject.get_global_transform_with_canvas().origin])
			_main.npc_card.show_profile(subject.profile, {
				"actor": subject,
				"objective": subject.objective_text(),
				"stage": subject.stage_text(),
			})
			await get_tree().create_timer(0.35).timeout
			_check("crew", _main.npc_card._card, size)
			await _shot("crew")
			_main.npc_card.close()
			await get_tree().create_timer(0.2).timeout
		else:
			_failures.append("crew at %dx%d has nobody to inspect"
				% [size.x, size.y])
	if _wants("grab") and world_pass:
		# Press and hold lifts somebody off the ground. Driven through the world's
		# own press handlers rather than through synthetic InputEvents, because
		# what is worth proving is the hold-versus-tap decision and the dangle,
		# not Godot's event routing.
		var world: PortWorld = _main.world
		var lifted: StructureActor = null
		for candidate in world.structures.crew():
			if candidate.is_person():
				lifted = candidate
				break
		if lifted == null:
			_failures.append("grab at %dx%d has nobody on foot to pick up"
				% [size.x, size.y])
		else:
			_main.cam.focus_on(lifted.global_position.y, 0.2)
			await get_tree().create_timer(0.4).timeout
			var from := lifted.global_position + Vector2(4.0, 6.0)
			world._begin_press(from)
			world._tick_hold(PortWorld.GRAB_HOLD + 0.01)
			if not lifted.is_held():
				_failures.append("grab at %dx%d did not pick anybody up"
					% [size.x, size.y])
			# Carry them a little way, so the shot is somebody in transit rather
			# than somebody standing where they already were.
			for step in 12:
				world._move_press(from + Vector2(-2.0 * step, -1.5 * step))
				await get_tree().process_frame
			await get_tree().create_timer(0.45).timeout
			await _shot("grab")
			var carried := lifted.global_position
			world._end_press(carried)
			await get_tree().create_timer(0.4).timeout
			if lifted.is_held():
				_failures.append("grab at %dx%d never let go" % [size.x, size.y])
			await _shot("grab_dropped")

			# And the sea. Dropping somebody past the quay wall is the one
			# interaction whose whole payload is animation — splash, rings,
			# wake, the swim back, the drips — so it is worth a frame of it and
			# worth failing if the swimmer never reaches the wall.
			var overboard := Vector2(PortLayout.WATER_X0 + 34.0,
				lifted.global_position.y)
			_main.cam.focus_on(overboard.y, 0.2)
			world._begin_press(lifted.global_position + Vector2(4.0, 6.0))
			world._tick_hold(PortWorld.GRAB_HOLD + 0.01)
			world._move_press(overboard)
			world._end_press(overboard)
			if not lifted.is_overboard():
				_failures.append("overboard at %dx%d stayed dry"
					% [size.x, size.y])
			await get_tree().create_timer(0.7).timeout
			await _shot("overboard")
			# Long enough for the longest swim in the fairway, then check they
			# are back on the apron rather than parked in the water.
			await get_tree().create_timer(6.0).timeout
			if lifted.is_overboard():
				_failures.append("overboard at %dx%d never got out"
					% [size.x, size.y])
			await _shot("overboard_ashore")
	if _wants("decor") and world_pass:
		# The whole shelf at once. Every decoration is scenery with no rule
		# attached, so the only way to review one is to look at it — and the only
		# way to know the layer really does rebuild on the signal is to switch
		# them on with the port already running.
		for item: Dictionary in CosmeticDb.all():
			GameState.cosmetics_owned[str(item.id)] = true
			GameState.cosmetics_on[str(item.id)] = true
		EventBus.cosmetics_changed.emit()
		# Night, so the RGB masts are actually lit for the shot.
		var was_time := TimeManager.time_of_day
		TimeManager.time_of_day = 0.92
		_main.cam.focus_on(PortLayout.world_bottom() * 0.4, 0.2)
		await get_tree().create_timer(1.2).timeout
		await _shot("decor")
		if _main.world.decor.get_child_count() == 0:
			_failures.append("decor at %dx%d built nothing" % [size.x, size.y])
		# The duck has to float in water no hull is using. There is 80px of
		# channel and a ship is 66 of it, so "in the middle of the water" is
		# "underneath a ship" everywhere along the quay — the only clear basin is
		# past the last berth, and how far down that is depends on the land.
		var duck: Vector2 = _main.world.decor._duck_home()
		print("[capture] duck %s berths=%d last berth ends %.0f bottom %.0f"
			% [duck, PortLayout.berth_count(),
			PortLayout.berth_y(PortLayout.berth_count() - 1) + PortLayout.SHIP_H,
			PortLayout.world_bottom()])
		for index in PortLayout.berth_count():
			var top := PortLayout.berth_y(index)
			if duck.y > top - 30.0 and duck.y < top + PortLayout.SHIP_H + 24.0:
				_failures.append("the duck is moored under berth %d" % (index + 1))
		# And off again, to prove the switch is a switch rather than a purchase.
		for item: Dictionary in CosmeticDb.all():
			GameState.cosmetics_on[str(item.id)] = false
		EventBus.cosmetics_changed.emit()
		await get_tree().create_timer(0.4).timeout
		if _main.world.decor.get_child_count() != 0:
			_failures.append("decor at %dx%d would not switch off"
				% [size.x, size.y])
		TimeManager.time_of_day = was_time
	if _wants("notices"):
		# Nothing interrupts the port any more, so the notice log is the only
		# place a notice is ever seen. It hangs off the bell at the end of the
		# gantry and has to stay inside the world at every size.
		var bell: NoticeBell = _main.bell
		for index in 4:
			EventBus.notification_requested.emit({
				"id": "capture_notice_%d" % index, "kind": &"milestone",
				"priority": 1, "text": "Aviso de teste %d do terminal" % (index + 1),
			})
			await get_tree().create_timer(0.15).timeout
		bell.open_log()
		await get_tree().create_timer(0.35).timeout
		_check("notices", bell._board, size)
		await _shot("notices")
		bell.close_log()
		await get_tree().create_timer(0.2).timeout
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
	if _wants("decorshop"):
		# The shelf, half bought: a row carries a price before it is owned and a
		# switch afterwards, and the two states have to be legible side by side
		# on the narrowest phone in the matrix.
		for item: Dictionary in CosmeticDb.all().slice(0, 3):
			GameState.cosmetics_owned[str(item.id)] = true
			GameState.cosmetics_on[str(item.id)] = str(item.id) != "planters"
		EventBus.cosmetics_changed.emit()
		_main.shop._on_tab("cosmetics")
		await get_tree().create_timer(0.35).timeout
		_check("shop decor", _main.shop._board, size)
		await _shot("shop_decor")
	if _wants("orders"):
		# Standing orders only exist once the quay has more than one berth, so the
		# parcels are bought first. A shot of a tab that is correctly hidden would
		# prove nothing, and the tab silently never appearing is exactly the
		# failure this is here to catch.
		var guard := 0
		while PortLayout.berth_count() < 2 and guard < 12:
			var parcel := LandDB.next_parcel(GameState.land)
			if parcel.is_empty():
				break
			GameState.teus = 1e18
			_main.shop._on_buy_land(parcel.id)
			guard += 1
			await get_tree().create_timer(0.25).timeout
		_main.shop._on_tab("orders")
		await get_tree().create_timer(0.4).timeout
		var tab: Button = _main.shop._tab_buttons.get("orders")
		if tab == null or not tab.visible:
			_failures.append("orders tab hidden at %dx%d with %d berths"
				% [size.x, size.y, PortLayout.berth_count()])
		_check("orders", _main.shop._board, size)
		await _shot("shop_orders")
		# And the same board with the foreman hired, because a section that only
		# ever photographs greyed out proves nothing about the state it spends the
		# rest of the game in.
		GameState.prestige_count = maxi(1, GameState.prestige_count)
		GameState.foreman_mode = Foreman.PAYBACK
		_main.shop._refresh()
		await get_tree().create_timer(0.3).timeout
		var modes: HBoxContainer = _main.shop._lists["orders"] \
			.get_node_or_null(^"Foreman/Modes")
		var greedy: Button = modes.get_node_or_null(
			NodePath("Mode_%s" % Foreman.PAYBACK)) if modes != null else null
		if greedy == null or greedy.disabled:
			_failures.append("foreman still locked at %dx%d after a rebuild"
				% [size.x, size.y])
		_check("orders_foreman", _main.shop._board, size)
		await _shot("shop_orders_foreman")
		# The branch's section, scrolled to and with a train actually on the line.
		# It is the only readout the rail has — everything it reports happens at
		# the bottom of the world where the camera never goes — so a board that
		# rendered its three buttons and left the status line empty would look
		# exactly like a working one in the shot above.
		var branch: RailYard = _main.world.rail
		branch.seed_new()
		branch._next_service = 0.01
		branch.tick(0.02)
		branch.notify_arrived()
		var board: VBoxContainer = _main.shop._lists["orders"]
		var section: VBoxContainer = board.get_node_or_null(^"Branch")
		if section == null:
			_failures.append("no branch section on the orders board at %dx%d"
				% [size.x, size.y])
		else:
			var scroll: ScrollContainer = _main.shop._scrolls.get("orders")
			if scroll != null:
				_main.shop._refresh()
				await get_tree().process_frame
				scroll.scroll_vertical = int(section.position.y)
			await get_tree().create_timer(0.4).timeout
			var status: Label = section.get_node_or_null(^"Status")
			if status == null or status.text.is_empty():
				_failures.append("the branch section reports nothing at %dx%d"
					% [size.x, size.y])
			else:
				print("[capture] branch says: ", status.text)
			_check("orders_branch", _main.shop._board, size)
			await _shot("shop_orders_branch")
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
		# The crew page is the same board with a very different list on it, so it
		# gets its own layout check.
		# The trophy board is twelve struck coins and forty-odd lamps on the same
		# sheet, which is the widest thing this board has ever had to hold.
		_main.journal._select_tab("troph")
		await get_tree().create_timer(0.3).timeout
		_check("journal_trophies", _main.journal._sheet, size)
		await _shot("journal_trophies")
		_main.journal._select_tab("crew")
		await get_tree().create_timer(0.3).timeout
		_check("journal_crew", _main.journal._sheet, size)
		await _shot("journal_crew")
		_main.journal._select_tab("next")
		_main.journal.close()
		await get_tree().create_timer(0.2).timeout
	if _wants("prestige"):
		_main.prestige_dialog.open()
		await get_tree().create_timer(0.3).timeout
		_check("prestige", _main.prestige_dialog._panel, size)
		await _shot("prestige")
		# The quoted state is the taller one: it adds the gain line and the
		# rebuild estimate, and it is the state the player actually decides in.
		_main.prestige_dialog._confirm_or_quote()
		await get_tree().create_timer(0.3).timeout
		_check("prestige_quote", _main.prestige_dialog._panel, size)
		await _shot("prestige_quote")
		_main.prestige_dialog.close()
		await get_tree().create_timer(0.2).timeout
	if _wants("rate"):
		_main.rate_breakdown.open()
		await get_tree().create_timer(0.3).timeout
		_check("rate", _main.rate_breakdown._panel, size)
		await _shot("rate")
		_main.rate_breakdown.close()
		await get_tree().create_timer(0.2).timeout
	if _wants("wheel"):
		_main.wheel_panel.open()
		await get_tree().create_timer(0.3).timeout
		_check("wheel", _main.wheel_panel._board, size)
		await _shot("wheel")
		_main.wheel_panel.close()
		await get_tree().create_timer(0.2).timeout
	if _wants("offline"):
		await _capture_offline(size)


func _capture_offline(size: Vector2i) -> void:
	## The return board is built once, at load, from a real absence. Feed it a
	## synthetic one: it is the widest text in the game and the only screen that
	## has to fit an amount, a duration, a rate and a cap warning.
	SaveManager.offline_earnings = maxf(1.0, GameState.cps * 28800.0 * 0.5)
	SaveManager.offline_report = {
		"away_seconds": 36000.0, "credited_seconds": 28800.0,
		"capped_seconds": 7200.0, "cap_seconds": 28800.0, "efficiency": 0.5,
		"rate": GameState.cps, "earnings": SaveManager.offline_earnings,
		"lost_to_cap": GameState.cps * 7200.0 * 0.5,
	}
	var popup := OfflinePopup.new()
	popup.name = "OfflinePopupCapture"
	_main.add_child(popup)
	await get_tree().create_timer(0.4).timeout
	_check("offline", popup._panel, size)
	await _shot("offline")
	popup.queue_free()
	await get_tree().create_timer(0.2).timeout


func _docked(gate: GateDock) -> int:
	var count := 0
	for bay: int in gate.bays.keys():
		if int(gate.bays[bay].stage) == int(GateDock.Stage.DOCKED):
			count += 1
	return count


func _capture_transfer_alignment() -> void:
	## Freeze both problematic approaches just before impact. These use the
	## production endpoint APIs, including the selected hull transform and the
	## actual longitudinal bed slot.
	var world: PortWorld = _main.world
	# These two shots time themselves off the flight's own duration to freeze the
	# frame before impact. A relay's arrival is decided by where a tractor is, not
	# by a clock, so the alignment check takes the direct arc.
	world.relays_enabled = false
	var live_ship: Ship = world.ship
	live_ship.visible = false
	# The live vessel may still own its arrival tween when the harness starts;
	# use an isolated moored hull so a background tween cannot drag the target
	# away while the screenshot is being timed.
	var ship := Ship.new()
	world.add_child(ship)
	ship.select_variant(42017, 2)
	ship.position = Vector2(PortLayout.SHIP_X, PortLayout.SHIP_Y)
	ship._set_phase(Ship.Phase.LOADING)
	ship.set_manifest([], 1)
	var bay := ship.reserve_bay()
	var yard_point := world.to_global(
		PortLayout.block_origin(2) + Vector2(12.0, 18.0))
	var ship_flight := world.fly_cargo(2, yard_point, bay.pos)
	await get_tree().create_timer(ship_flight._duration * 0.92).timeout
	await _shot("transfer_ship_approach")
	await get_tree().create_timer(0.28).timeout
	ship.queue_free()
	live_ship.visible = true

	var truck := RoadTruck.new()
	truck.setup(world, 0, [], true)
	world.entities.add_child(truck)
	await get_tree().process_frame
	var truck_flight := world.fly_cargo(5, yard_point,
		truck.bed_slot_global_position(0))
	truck_flight.set_rotations(0.0, PI / 2.0)
	await get_tree().create_timer(truck_flight._duration * 0.92).timeout
	await _shot("transfer_truck_approach")
	await get_tree().create_timer(0.28).timeout
	truck.queue_free()
	world.relays_enabled = true


func _capture_relay() -> void:
	## The chain of custody, photographed at the moment it is a chain: a box on a
	## tractor's chassis, between the crane that lifted it and the block it is
	## going to. Waiting for that state is the point — an empty apron proves the
	## relay exists exactly as much as an empty road proves a truck does.
	var world: PortWorld = _main.world
	world.relays_enabled = true
	var hull: Ship = world.ship
	hull.visible = true
	hull.position = Vector2(PortLayout.SHIP_X, PortLayout.berth_y(0))
	hull._set_phase(Ship.Phase.DISCHARGING)
	# Wait for a box that is not only on a chassis but has been driven a way on
	# it: photographing the instant of the pick-up shows a tractor and a box in
	# the same place as the crane, which is the one frame that proves nothing.
	var deadline := Time.get_ticks_msec() + 20000
	var driven := 0.0
	while Time.get_ticks_msec() < deadline and driven < 26.0:
		world.berth.handle_tap(hull.global_position)
		for child in world.overhead.get_children():
			if not (child is CargoRelay):
				continue
			var relay := child as CargoRelay
			var carrier: Node = relay._carrier
			if carrier == null or not is_instance_valid(carrier) \
					or int(carrier.call("relay_stage")) \
						!= StructureActor.RELAY_CARRY:
				continue
			driven = maxf(driven, relay.position.distance_to(relay._leg_from))
		await get_tree().process_frame
	if driven < 26.0:
		_failures.append(
			"no container was driven on a chassis in 20s (best %.0f px)" % driven)
	await _shot("relay_hand_off")


func _check_hud(size: Vector2i) -> void:
	## The permanent chrome, which no overlay check covers because it is never
	## opened. The gantry carries two instruments that are laid out by two
	## different scripts against one shared constant, so the thing worth proving
	## is that they are still inside the steel they are supposed to be bolted to.
	var hud: Hud = _main.hud
	var rail: CommandRail = _main.rail
	var bar := hud.bar_rect()
	_check("gantry", hud._bar, size)
	if not _inside(bar, hud.readout_rect()):
		_failures.append("the tally at %dx%d is not inside the gantry (%s vs %s)"
			% [size.x, size.y, hud.readout_rect(), bar])
	var clock: PortClock = _main.clock
	var dial: Rect2 = clock._board.get_global_rect()
	if not _inside(bar, dial):
		_failures.append("the clock at %dx%d is not inside the gantry (%s vs %s)"
			% [size.x, size.y, dial, bar])


func _inside(outer: Rect2, inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 0.5 \
		and inner.position.y >= outer.position.y - 0.5 \
		and inner.end.x <= outer.end.x + 0.5 and inner.end.y <= outer.end.y + 0.5


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
