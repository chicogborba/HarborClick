extends Node2D
## Root: assembles world, camera and UI.

var world: PortWorld
var cam: PortCamera
var shop: Shop
var hud: Hud
var rail: CommandRail
var shell: ResponsiveShell
var bell: NoticeBell
var notifications: NotificationCoordinator
var settings: SettingsPanel
var objective: ObjectiveChip
var journal: PortJournal
var routes: RouteMap
var prestige_dialog: PrestigeDialog
var tutorial: TutorialSpotlight
var npc_card: NpcCard
var clock: PortClock
var special_alert: SpecialCallAlert
var minigame: CraneMinigame
var maze: MazeMinigame
var _overlay_state := {"shop": false, "settings": false, "journal": false,
	"prestige": false, "routes": false, "crew": false, "special": false,
	"minigame": false, "notices": false}
## Whoever's dossier is open, so the objective on it keeps up with the yard.
var _inspected: Object
## The two reasons the camera stops answering a drag: a board is up over the
## port, or somebody is being carried across it.
var _input_blocked := false
var _carrying := false


func _ready() -> void:
	# Normally the title screen has already chosen a slot. Running this scene
	# directly — F6, the capture harness, the dev probe — falls back to the
	# first terminal so the game is never left with no save path at all.
	if SaveManager.active_slot == 0:
		SaveManager.use_profile(1)
	# Running this scene directly skips the title, so the engine-drawn chrome is
	# themed here too rather than only on the way in.
	UiTheme.install_window_theme(get_window())

	shell = ResponsiveShell.new()
	shell.name = "ResponsiveShell"
	add_child(shell)

	world = PortWorld.new()
	world.name = "World"
	add_child(world)

	cam = PortCamera.new()
	cam.name = "Camera"
	add_child(cam)
	cam.make_current()
	cam.set_world_bottom(world.visible_bottom())

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)

	rail = CommandRail.new()
	rail.name = "CommandRail"
	add_child(rail)

	shop = Shop.new()
	shop.name = "Shop"
	add_child(shop)

	notifications = NotificationCoordinator.new()
	notifications.name = "Notifications"
	add_child(notifications)

	bell = NoticeBell.new()
	bell.name = "NoticeBell"
	add_child(bell)
	bell.setup(notifications)
	bell.open_changed.connect(_on_overlay_changed.bind("notices"))

	settings = SettingsPanel.new()
	settings.name = "Settings"
	add_child(settings)
	settings.tutorial_replay_requested.connect(_replay_tutorial)
	rail.settings_requested.connect(settings.open)
	rail.shop_requested.connect(func() -> void: shop.toggle())
	rail.set_shop_alert_source(Callable(shop, "has_affordable"))

	objective = ObjectiveChip.new()
	objective.name = "ObjectiveChip"
	objective.setup(Progression, {
		"get_recommended": Callable(Progression, "get_recommended_objective"),
	})
	add_child(objective)

	journal = PortJournal.new()
	journal.name = "PortJournal"
	journal.setup(Progression, {
		"get_objectives": Callable(Progression, "get_all_objectives"),
		"pin": Callable(Progression, "pin_objective"),
		"get_crew": Callable(self, "_journal_crew"),
		"get_charters": Callable(self, "_journal_charters"),
	})
	add_child(journal)
	objective.journal_requested.connect(journal.open)
	rail.journal_requested.connect(func() -> void: journal.open())
	# The rail asks for the objective on its own slow tick instead of once per
	# progression event: recomputing the recommendation on every credited box
	# made a burst of purchases visibly stall the frame.
	rail.set_objective_source(Callable(objective, "_objective"))
	Progression.objective_pinned.connect(func(_id: StringName, _item: Dictionary) -> void: objective.refresh())
	Progression.objective_progressed.connect(func(_id: StringName, _progress: float, _target: float) -> void:
		objective.refresh()
		journal.refresh())
	Progression.achievement_unlocked.connect(func(id: StringName, item: Dictionary) -> void:
		objective.refresh()
		journal.refresh()
		# Nothing sits over the port permanently any more, so this is the one
		# moment that earns a banner: a goal actually completed.
		EventBus.notification_requested.emit({
			"id": "achievement_%s" % id, "kind": &"milestone", "priority": 2,
			"text": "Conquista: %s" % str(item.get("title", "meta cumprida")),
		}))

	routes = RouteMap.new()
	routes.name = "RouteMap"
	add_child(routes)
	rail.routes_requested.connect(routes.open)
	routes.open_changed.connect(_on_overlay_changed.bind("routes"))

	prestige_dialog = PrestigeDialog.new()
	prestige_dialog.name = "PrestigeDialog"
	prestige_dialog.setup({
		"quote": Callable(self, "_prestige_quote"),
		"commit": Callable(self, "_commit_prestige"),
		"purchase_node": Callable(GameState, "buy_prestige_node"),
	})
	add_child(prestige_dialog)
	rail.prestige_requested.connect(prestige_dialog.open)

	shop.open_changed.connect(_on_overlay_changed.bind("shop"))
	settings.open_changed.connect(_on_overlay_changed.bind("settings"))
	journal.open_changed.connect(_on_overlay_changed.bind("journal"))
	prestige_dialog.open_changed.connect(_on_overlay_changed.bind("prestige"))

	clock = PortClock.new()
	clock.name = "PortClock"
	add_child(clock)

	npc_card = NpcCard.new()
	npc_card.name = "NpcCard"
	add_child(npc_card)
	npc_card.open_changed.connect(_on_overlay_changed.bind("crew"))
	npc_card.open_changed.connect(func(opened: bool) -> void:
		if not opened:
			_inspected = null)
	world.npc_inspected.connect(_on_npc_inspected)
	world.npc_grab_changed.connect(_on_npc_grabbed)

	special_alert = SpecialCallAlert.new()
	special_alert.name = "SpecialCallAlert"
	add_child(special_alert)
	special_alert.open_changed.connect(_on_overlay_changed.bind("special"))
	special_alert.accepted.connect(func() -> void: world.specials.accept())
	special_alert.declined.connect(func() -> void: world.specials.decline())

	# One board per kind of game, and the charter says which one it is played on.
	minigame = CraneMinigame.new()
	minigame.name = "CraneMinigame"
	add_child(minigame)
	maze = MazeMinigame.new()
	maze.name = "MazeMinigame"
	add_child(maze)
	for board: MinigameBoard in [minigame, maze]:
		board.open_changed.connect(_on_overlay_changed.bind("minigame"))
		board.finished.connect(func(won: bool, _summary: Dictionary) -> void:
			world.specials.resolve(won))
	world.specials.offer_ready.connect(func(offer: Dictionary) -> void:
		special_alert.open(offer, SpecialCallDirector.OFFER_TIMEOUT))
	world.specials.offer_closed.connect(special_alert.close)
	world.specials.minigame_requested.connect(_open_minigame)

	var offline := OfflinePopup.new()
	offline.name = "OfflinePopup"
	add_child(offline)

	# One-time v1 migration. New saves use the rich cargo_yard/berth_call
	# sections registered by PortWorld and never flatten UIDs back into heights.
	var stored := SaveManager.pending_yard()
	if not stored.is_empty():
		world.yard.from_save(stored)
		world.berth.ensure_export_stock()
	SaveManager.yard = null

	EventBus.land_bought.connect(func(id: String) -> void:
		cam.set_world_bottom(world.visible_bottom())
		var parcel := LandDB.get_item(id)
		EventBus.notification_requested.emit({
			"id": "land_%s" % id,
			"type": &"unlock",
			"priority": 1,
			"text": "%s pavimentado. Mais espaço pra empilhar!"
				% parcel.get("name", "Terreno"),
		})
		cam.focus_on(PortLayout.yard_bottom() - 120.0, 0.9))

	# Every berth reports in; the board shows whichever one is being worked.
	for controller in world.berths:
		controller.status_changed.connect(_on_any_berth_status)
	for hull in world.ships:
		hull.phase_changed.connect(func(_phase: int) -> void: _refresh_berth_board())
	world.berth.notice_requested.connect(
		func(notice: Dictionary) -> void:
			# Berth notices are refusals — full yard, invalid box, reverted
			# move. They deduplicate on their code, so hammering a blocked
			# yard says it once with a count, not once per tap.
			EventBus.notification_requested.emit({
				"id": "berth_%s" % notice.get("code", "notice"),
				"kind": &"blocked", "priority": 1,
				"text": notice.get("text", ""),
			}))
	hud.job_tick.connect(func() -> void:
		_refresh_berth_board()
		_refresh_inspected())
	_refresh_berth_board()

	tutorial = TutorialSpotlight.new()
	tutorial.name = "TutorialSpotlight"
	tutorial.setup({
		"get_target_rect": Callable(self, "_tutorial_target_rect"),
		"reduced_motion": Callable(self, "_tutorial_reduced_motion"),
	})
	add_child(tutorial)
	tutorial.finished.connect(_on_tutorial_finished)
	if not GameState.flags.get("tutorial_done", false):
		tutorial.start()

	shell.metrics_changed.connect(_apply_view_metrics)
	shell.world_input_blocked_changed.connect(_on_world_input_blocked)
	shell.save_requested.connect(SaveManager.request_save)
	_apply_view_metrics(shell.metrics)

	if OS.is_debug_build() and DisplayServer.get_name() != "headless" \
			and FileAccess.file_exists("res://.devprobe"):
		var timer := Timer.new()
		timer.wait_time = 3.0
		timer.autostart = true
		timer.timeout.connect(_save_screenshot.bind("shot"))
		add_child(timer)
		_dev_probe()


func _on_any_berth_status(_status: Dictionary) -> void:
	_refresh_berth_board()


func _refresh_berth_board() -> void:
	## The board follows the work. With three berths it names the one it is talking
	## about, and it says how many others are alongside so the player knows there is
	## more than one ship to tap.
	if world == null or world.ships.is_empty():
		return
	var index := world.focus_berth()
	var hull: Ship = world.ships[index]
	if world.atmosphere != null:
		world.atmosphere.set_berth_active(world.any_ship_working())
	var text := ""
	match hull.phase:
		Ship.Phase.DISCHARGING:
			text = "Descarga: toque no navio"
		Ship.Phase.WAITING_EXPORT:
			text = "Aguardando exportação"
		Ship.Phase.LOADING:
			var progress := hull.export_progress()
			text = "Embarque %d/%d: toque no navio" % [progress.x, progress.y]
		Ship.Phase.ARRIVING:
			text = "Navio se aproximando"
		Ship.Phase.DEPARTING:
			text = "Navio partindo"
		_:
			text = "Aguardando próximo navio"
	# The chip is one narrow line, so the berth number goes on it and the rest of
	# the quay goes on the rail, where there is room for it.
	if world.ships.size() > 1:
		text = "Berço %d - %s" % [index + 1, text]
	_set_berth_hint(text, index)
	if rail != null:
		var report := world.berth_report()
		for row: Dictionary in report:
			row["focused"] = int(row.get("index", -1)) == index
		rail.set_fleet(report)


func _journal_crew() -> Array:
	## The whole shift in one list: who they are, and what each is on right now.
	var rows: Array = []
	if world == null or world.crew == null:
		return rows
	var live := {}
	if world.structures != null:
		for actor in world.structures.crew():
			if actor.profile != null:
				live[actor.profile.slot] = actor
	for bay: int in world._gate_trucks.keys():
		var truck: RoadTruck = world._gate_trucks[bay]
		if is_instance_valid(truck) and truck.driver != null:
			live[truck.driver.slot] = truck
	for profile in world.crew.all():
		var objective := ""
		var actor: Object = live.get(profile.slot)
		if actor != null and actor.has_method("objective_text"):
			objective = str(actor.call("objective_text"))
		rows.append({
			"name": profile.display_name, "title": profile.title(),
			"objective": objective, "moves": profile.moves,
			"special": profile.is_special(),
		})
	return rows


func _journal_charters() -> Dictionary:
	return world.specials.stats() if world != null and world.specials != null \
		else {}


func _open_minigame(offer: Dictionary) -> void:
	## The charter names its own game. An unknown one falls back to the stacker
	## rather than accepting a charter the player can never work.
	var board: MinigameBoard = minigame
	if StringName(offer.get("game", &"")) == SpecialCallDB.GAME_MAZE:
		board = maze
	board.open(offer)


func _on_npc_inspected(profile: NpcProfile, dossier: Dictionary) -> void:
	_inspected = dossier.get("actor")
	npc_card.show_profile(profile, dossier)


func _refresh_inspected() -> void:
	## The open card follows the person: a conferente who finishes a round and
	## walks to the next block says so while you are still reading about him.
	if npc_card == null or not npc_card.is_open():
		return
	if _inspected == null or not is_instance_valid(_inspected):
		return
	var objective := ""
	var stage := ""
	if _inspected.has_method("objective_text"):
		objective = str(_inspected.call("objective_text"))
	if _inspected.has_method("stage_text"):
		stage = str(_inspected.call("stage_text"))
	npc_card.set_objective(objective, stage)


func _set_berth_hint(text: String, index: int = 0) -> void:
	## Portrait reads it over the port, desktop reads it in the rail. One call
	## site so the two can never drift apart.
	if world == null or index < 0 or index >= world.ships.size():
		return
	var hull: Ship = world.ships[index]
	var full := text
	var rate := world.berths[index].auto_rate()
	if rate > 0.0 and hull.is_working():
		# Once equipment is working the ship, say so: the tap is a boost from
		# here on, and the player should be able to see that without counting
		# boxes.
		full = "%s  -  %.1f/s auto" % [text, rate]
	# One measurement of the call, read by both profiles. The phone hangs it on
	# the gantry's tag with a hairline bar; the wide screen spells it out on the
	# rail's berth card.
	var progress := hull.export_progress()
	var capacity := hull.bay_capacity()
	var done: float = float(capacity - hull.cargo_left()) \
		if hull.is_discharging() else float(progress.x)
	hud.set_berth_status({
		"text": full,
		"current": done if hull.is_working() else 0.0,
		"total": float(capacity) if hull.is_working() else 0.0,
	})
	if rail != null:
		# Keep the rail's card in step with the phase text even between the
		# berth's own status emissions.
		var silhouette := ShipCatalog.get_silhouette(
			StringName(hull.ship_variant.get("silhouette_id", "")))
		var vessel := str(silhouette.get("title", ""))
		if world.ships.size() > 1:
			vessel = "%s - berço %d/%d" % [vessel, index + 1, world.ships.size()]
		rail.set_berth({
			"text": text,
			"vessel": vessel,
			"current": done if hull.is_working() else 0.0,
			"total": float(capacity) if hull.is_working() else 0.0,
			"auto_rate": rate,
		})


func _apply_view_metrics(metrics: Dictionary) -> void:
	world.apply_view_metrics(metrics)
	cam.apply_view_metrics(metrics)
	# The camera has to know what the HUD is standing on. The gantry always spans
	# the top of the world; the key console only exists in portrait, because on a
	# wide screen the keys are on the rail beside the port instead of over it.
	cam.set_view_insets(Hud.BAR_H + Hud.TAG_DROP,
		0.0 if str(metrics.get("profile", "")) == "desktop" \
			else CommandRail.BAR_H + 12.0)
	hud.apply_view_metrics(metrics)
	rail.apply_view_metrics(metrics)
	rail.set_yard_source(Callable(world.yard, "fill_ratio"))
	shop.set_rail(rail)
	shop.apply_view_metrics(metrics)
	journal.set_rail(rail)
	if routes != null:
		routes.set_rail(rail)
		routes.apply_view_metrics(metrics)

	bell.apply_view_metrics(metrics)
	settings.apply_view_metrics(metrics)
	if objective != null:
		objective.apply_view_metrics(metrics)
	if journal != null:
		journal.apply_view_metrics(metrics)
	if prestige_dialog != null:
		prestige_dialog.apply_view_metrics(metrics)
	if tutorial != null:
		tutorial.apply_view_metrics(metrics)
	if clock != null:
		clock.apply_view_metrics(metrics)
	if npc_card != null:
		npc_card.apply_view_metrics(metrics)
	if special_alert != null:
		special_alert.apply_view_metrics(metrics)
	if minigame != null:
		minigame.apply_view_metrics(metrics)
	if maze != null:
		maze.apply_view_metrics(metrics)
	var offline := get_node_or_null(^"OfflinePopup")
	if offline != null and offline.has_method("apply_view_metrics"):
		offline.apply_view_metrics(metrics)


func _on_overlay_changed(opened: bool, source: String) -> void:
	_overlay_state[source] = opened
	if rail != null:
		# Anything that draws in the rail's place hides the rail's own keys,
		# so they are never stacked underneath a board.
		rail.set_overlay_open(bool(_overlay_state.shop)
			or bool(_overlay_state.journal) or bool(_overlay_state.routes))
	shell.set_world_input_blocked(
		bool(_overlay_state.shop) or bool(_overlay_state.settings)
			or bool(_overlay_state.journal) or bool(_overlay_state.prestige)
			or bool(_overlay_state.routes) or bool(_overlay_state.crew)
			or bool(_overlay_state.special) or bool(_overlay_state.minigame)
			or bool(_overlay_state.notices))


func _on_world_input_blocked(blocked: bool) -> void:
	_input_blocked = blocked
	world.set_input_enabled(not blocked)
	_apply_camera_input()


func _on_npc_grabbed(held: bool) -> void:
	## Somebody in the hand owns the drag. Without this the camera pans under the
	## person being carried, so the yard slides one way and they slide the other
	## and the terminal ends up somewhere nobody asked for.
	_carrying = held
	_apply_camera_input()


func _apply_camera_input() -> void:
	cam.set_input_enabled(not _input_blocked and not _carrying)


func _prestige_quote() -> Dictionary:
	return GameState.get_prestige_quote()


func _commit_prestige() -> Variant:
	var quote := GameState.get_prestige_quote()
	if not GameState.do_prestige():
		return false
	AudioManager.play_sfx("prestige")
	EventBus.notification_requested.emit({
		"kind": &"prestige", "priority": 2,
		"text": "+%d ações douradas. Reconstrução com 75%% de desconto." % int(quote.gain),
	})
	return quote


func _tutorial_target_rect(target: String) -> Rect2:
	match target:
		"ship":
			if world != null and world.ship != null:
				var point := world.ship.get_global_transform_with_canvas().origin
				return Rect2(point - Vector2(20, 12), Vector2(100, 76))
		"teu":
			return hud.readout_rect() if hud != null else Rect2()
		"rail":
			return rail.content_rect if rail != null else Rect2()
		"objective", "journal":
			return objective._panel.get_global_rect() if objective != null else Rect2()
		"shop":
			return shop.launcher_rect() if shop != null else Rect2()
		"prestige":
			return shop.launcher_rect() if shop != null else Rect2()
	return Rect2()


func _on_tutorial_finished(skipped: bool) -> void:
	GameState.flags["tutorial_done"] = true
	Progression.ingest_event(&"tutorial_completed", {"skipped": skipped})
	SaveManager.request_save(&"tutorial")


func _replay_tutorial() -> void:
	settings.close()
	if tutorial != null:
		tutorial.replay()


func _tutorial_reduced_motion() -> bool:
	return not UserPreferences.can_animate()


func _save_screenshot(shot_name: String = "shot") -> void:
	var texture := get_viewport().get_texture()
	if texture == null:
		return
	var img := texture.get_image()
	if img == null or img.is_empty():
		return
	img.save_png("user://%s.png" % shot_name)


func _dev_probe() -> void:
	## Plays the game: taps the ship, buys everything, expands the port, then
	## grabs framed screenshots. Any failed expectation prints to the console.
	var tut := get_node_or_null(^"Tutorial")
	if tut != null:
		tut.queue_free()
	for child in get_children():
		if child is OfflinePopup:
			child.queue_free()
	await get_tree().create_timer(5.0).timeout

	# --- work a full call: discharge the imports, then load the exports ---
	var before := GameState.teus
	var saw_loading := false
	for i in 120:
		if world.ship.is_working():
			world.berth.handle_tap(world.ship.global_position + Vector2(30, 100))
		if world.ship.is_loading():
			saw_loading = true
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(1.0).timeout
	print("[probe] tap income: ", GameState.teus - before,
		"  yard fill: ", world.yard.fill_ratio())
	if GameState.teus <= before:
		printerr("[probe] FAIL: tapping the ship earned nothing")
	if not saw_loading:
		printerr("[probe] FAIL: ship never switched to loading exports")
	if not world.yard.has_boxes():
		printerr("[probe] FAIL: no containers ended up in the yard")

	# --- buy one of everything ---
	GameState.teus = 1e18
	GameState.lifetime_teus = 1e18
	EventBus.teus_changed.emit(GameState.teus)
	for item in StructureDB.ITEMS:
		for n in 4:
			if not GameState.buy_structure(item.id):
				printerr("[probe] FAIL: could not buy ", item.id)
				break
	print("[probe] cps after buying: ", GameState.fmt(GameState.cps))

	# --- expand the port twice ---
	var bottom_before := PortLayout.world_bottom()
	for n in 2:
		var parcel := LandDB.next_parcel()
		if parcel.is_empty():
			break
		shop._on_buy_land(parcel.id)
		await get_tree().create_timer(0.4).timeout
	if PortLayout.world_bottom() <= bottom_before:
		printerr("[probe] FAIL: buying land did not grow the world")
	print("[probe] world bottom: ", bottom_before, " -> ", PortLayout.world_bottom())

	# --- fill the yard so the busy look can be judged ---
	for i in world.yard.total_slots():
		for lv in randi() % 3:
			world.yard.place(i, lv, randi() % 8)

	shop._close()
	await get_tree().create_timer(1.5).timeout
	cam.position.y = 240.0
	await get_tree().create_timer(0.6).timeout
	_save_screenshot("probe_top")

	cam.position.y = 480.0
	await get_tree().create_timer(0.5).timeout
	_save_screenshot("probe_mid")

	cam.position.y = 820.0
	await get_tree().create_timer(0.5).timeout
	_save_screenshot("probe_low")

	shop._on_tab("structures")
	await get_tree().create_timer(0.7).timeout
	_save_screenshot("probe_shop")

	shop._on_tab("upgrades")
	await get_tree().create_timer(0.5).timeout
	_save_screenshot("probe_upgrades")

	shop._close()
	cam.position.y = 300.0
	TimeManager.time_of_day = 0.95
	await get_tree().create_timer(1.4).timeout
	_save_screenshot("probe_night")

	TimeManager.fog_active = true
	EventBus.fog_changed.emit(true)
	TimeManager.time_of_day = 0.45
	await get_tree().create_timer(8.0).timeout
	_save_screenshot("probe_fog")

	# --- settings board + audio toggles ---
	var settings_panel := get_node_or_null(^"Settings") as SettingsPanel
	settings_panel.open()
	await get_tree().create_timer(0.6).timeout
	_save_screenshot("probe_settings")
	var music_was := AudioManager.music_on
	AudioManager.set_music_on(not music_was)
	if AudioManager.music_on == music_was:
		printerr("[probe] FAIL: music toggle did nothing")
	AudioManager.set_music_on(music_was)
	settings_panel.close()
	print("[probe] done")


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_F2:
			_save_screenshot("shot")
		KEY_F3 when OS.is_debug_build():
			GameState.teus += 1e6
			GameState.run_teus += 1e6
			GameState.all_time_teus += 1e6
			EventBus.teus_changed.emit(GameState.teus)
		KEY_F4 when OS.is_debug_build():
			TimeManager.speed_mult = 40.0 if TimeManager.speed_mult == 1.0 else 1.0
