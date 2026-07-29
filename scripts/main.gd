extends Node2D
## Root: assembles world, camera and UI.

var world: PortWorld
var cam: PortCamera
var shop: Shop
var hud: Hud
var rail: CommandRail
var shell: ResponsiveShell
var toasts: ToastLayer
var notifications: NotificationCoordinator
var settings: SettingsPanel
var objective: ObjectiveChip
var journal: PortJournal
var prestige_dialog: PrestigeDialog
var tutorial: TutorialSpotlight
var _overlay_state := {"shop": false, "settings": false, "journal": false, "prestige": false}


func _ready() -> void:
	# Normally the title screen has already chosen a slot. Running this scene
	# directly — F6, the capture harness, the dev probe — falls back to the
	# first terminal so the game is never left with no save path at all.
	if SaveManager.active_slot == 0:
		SaveManager.use_profile(1)

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

	toasts = ToastLayer.new()
	toasts.name = "Toasts"
	add_child(toasts)
	toasts.setup(notifications)

	settings = SettingsPanel.new()
	settings.name = "Settings"
	add_child(settings)
	settings.tutorial_replay_requested.connect(_replay_tutorial)
	rail.settings_requested.connect(settings.open)
	rail.shop_requested.connect(func() -> void: shop.toggle())

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
		"get_contract": Callable(self, "_journal_contract"),
		"accept_contract": Callable(Progression, "accept_contract"),
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
	Progression.contract_updated.connect(func(_contract: Dictionary) -> void: journal.refresh())
	Progression.contract_finished.connect(func(_contract: Dictionary, _completed: bool) -> void: journal.refresh())

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

	world.berth.status_changed.connect(hud.set_berth_status)
	world.berth.status_changed.connect(_on_berth_status)
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
	world.ship.phase_changed.connect(_on_ship_phase)
	hud.job_tick.connect(func() -> void: _on_ship_phase(world.ship.phase))
	_on_ship_phase(world.ship.phase)

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


func _on_ship_phase(phase: int) -> void:
	## The board tells you what the berth needs, so tapping always has a point.
	if world != null and world.atmosphere != null:
		world.atmosphere.set_berth_active(world.ship.is_working())
	match phase:
		Ship.Phase.DISCHARGING:
			_set_berth_hint("Descarga: toque no navio")
		Ship.Phase.WAITING_EXPORT:
			_set_berth_hint("Aguardando exportação")
		Ship.Phase.LOADING:
			var progress := world.ship.export_progress()
			_set_berth_hint("Embarque %d/%d: toque no navio"
				% [progress.x, progress.y])
		Ship.Phase.ARRIVING:
			_set_berth_hint("Navio se aproximando")
		Ship.Phase.DEPARTING:
			_set_berth_hint("Navio partindo")
		_:
			_set_berth_hint("Aguardando próximo navio")


func _on_berth_status(status: Dictionary) -> void:
	## The rail draws a card, so it wants the numbers, not a sentence.
	var payload := status.duplicate()
	payload["auto_rate"] = world.berth.auto_rate() if world != null \
		and world.berth != null else 0.0
	rail.set_berth(payload)


func _set_berth_hint(text: String) -> void:
	## Portrait reads it over the port, desktop reads it in the rail. One call
	## site so the two can never drift apart.
	var full := text
	var rate := world.berth.auto_rate() if world != null and world.berth != null else 0.0
	if rate > 0.0 and world.ship != null and world.ship.is_working():
		# Once equipment is working the ship, say so: the tap is a boost from
		# here on, and the player should be able to see that without counting
		# boxes.
		full = "%s  -  %.1f/s auto" % [text, rate]
	hud.set_job_hint(full)
	if rail != null and world != null and world.berth != null:
		# Keep the rail's card in step with the phase text even between the
		# berth's own status emissions.
		var progress := world.ship.export_progress()
		var capacity := world.ship.bay_capacity()
		var done: float = float(capacity - world.ship.cargo_left()) \
			if world.ship.is_discharging() else float(progress.x)
		var silhouette := ShipCatalog.get_silhouette(
			StringName(world.ship.ship_variant.get("silhouette_id", "")))
		rail.set_berth({
			"text": text,
			"vessel": str(silhouette.get("title", "")),
			"current": done if world.ship.is_working() else 0.0,
			"total": float(capacity) if world.ship.is_working() else 0.0,
			"auto_rate": rate,
		})


func _apply_view_metrics(metrics: Dictionary) -> void:
	world.apply_view_metrics(metrics)
	cam.apply_view_metrics(metrics)
	hud.apply_view_metrics(metrics)
	rail.apply_view_metrics(metrics)
	rail.set_yard_source(Callable(world.yard, "fill_ratio"))
	shop.set_rail(rail)
	shop.apply_view_metrics(metrics)
	journal.set_rail(rail)

	toasts.apply_view_metrics(metrics)
	settings.apply_view_metrics(metrics)
	if objective != null:
		objective.apply_view_metrics(metrics)
	if journal != null:
		journal.apply_view_metrics(metrics)
	if prestige_dialog != null:
		prestige_dialog.apply_view_metrics(metrics)
	if tutorial != null:
		tutorial.apply_view_metrics(metrics)
	var offline := get_node_or_null(^"OfflinePopup")
	if offline != null and offline.has_method("apply_view_metrics"):
		offline.apply_view_metrics(metrics)


func _on_overlay_changed(opened: bool, source: String) -> void:
	_overlay_state[source] = opened
	if rail != null:
		# Anything that draws in the rail's place hides the rail's own keys,
		# so they are never stacked underneath a board.
		rail.set_overlay_open(bool(_overlay_state.shop)
			or bool(_overlay_state.journal))
	shell.set_world_input_blocked(
		bool(_overlay_state.shop) or bool(_overlay_state.settings)
			or bool(_overlay_state.journal) or bool(_overlay_state.prestige))


func _on_world_input_blocked(blocked: bool) -> void:
	world.set_input_enabled(not blocked)
	cam.set_input_enabled(not blocked)


func _prestige_quote() -> Dictionary:
	return GameState.get_prestige_quote()


func _journal_contract() -> Dictionary:
	var active := Progression.get_active_contract()
	if not active.is_empty():
		return active
	return Progression.materialize_contract_offer(Progression.career_seed, TimeManager.day, {
		"projected_rate": GameState.cps,
	})


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
