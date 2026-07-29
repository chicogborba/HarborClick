extends Node2D
## Root: assembles world, camera and UI.

var world: PortWorld
var cam: PortCamera
var shop: Shop
var hud: Hud


func _ready() -> void:
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

	shop = Shop.new()
	shop.name = "Shop"
	add_child(shop)

	var toasts := ToastLayer.new()
	toasts.name = "Toasts"
	add_child(toasts)

	var settings := SettingsPanel.new()
	settings.name = "Settings"
	add_child(settings)
	hud.settings_pressed.connect(settings.open)

	add_child(OfflinePopup.new())

	SaveManager.yard = world.yard
	var stored := SaveManager.pending_yard()
	if not stored.is_empty():
		world.yard.from_save(stored)

	EventBus.land_bought.connect(func(id: String) -> void:
		cam.set_world_bottom(world.visible_bottom())
		var parcel := LandDB.get_item(id)
		EventBus.toast.emit("%s pavimentado. Mais espaço pra empilhar!" % parcel.get("name", "Terreno"))
		cam.focus_on(PortLayout.yard_bottom() - 120.0, 0.9))

	world.ship.phase_changed.connect(_on_ship_phase)
	hud.job_tick.connect(func() -> void: _on_ship_phase(world.ship.phase))
	_on_ship_phase(world.ship.phase)

	var tutorial := Tutorial.new()
	tutorial.name = "Tutorial"
	add_child(tutorial)
	tutorial.start()

	if OS.is_debug_build():
		var timer := Timer.new()
		timer.wait_time = 3.0
		timer.autostart = true
		timer.timeout.connect(_save_screenshot.bind("shot"))
		add_child(timer)
		if FileAccess.file_exists("res://.devprobe"):
			_dev_probe()


func _on_ship_phase(phase: int) -> void:
	## The board tells you what the berth needs, so tapping always has a point.
	match phase:
		Ship.Phase.DISCHARGING:
			hud.set_job_hint("DESCARGA: toque no navio")
		Ship.Phase.LOADING:
			var progress := world.ship.export_progress()
			hud.set_job_hint("EMBARQUE %d/%d: toque no navio"
				% [progress.x, progress.y])
		Ship.Phase.ARRIVING:
			hud.set_job_hint("Navio se aproximando...")
		_:
			hud.set_job_hint("Aguardando próximo navio")


func _save_screenshot(shot_name: String = "shot") -> void:
	var img := get_viewport().get_texture().get_image()
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
	for i in 90:
		if world.ship.is_working():
			GameState.do_click(world.ship.global_position + Vector2(30, 100))
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
			GameState.lifetime_teus += 1e6
			EventBus.teus_changed.emit(GameState.teus)
		KEY_F4 when OS.is_debug_build():
			TimeManager.speed_mult = 40.0 if TimeManager.speed_mult == 1.0 else 1.0
