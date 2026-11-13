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
var journal: PortJournal
var routes: RouteMap
var prestige_dialog: PrestigeDialog
var rate_breakdown: RateBreakdown
var tutorial: TutorialSpotlight
var npc_card: NpcCard
var clock: PortClock
var special_alert: SpecialCallAlert
var minigame: CraneMinigame
var maze: MazeMinigame
var wheel_service: WheelService
var wheel_panel: LuckyWheelPanel
var wheel_button: WheelButton
var daily_service: DailyOrdersService
var daily_panel: DailyOrdersPanel
var daily_button: DailyOrdersButton
var boost_chips: BoostChips
var build_hud: BuildHud
var level_hud: LevelHud
var roadmap: LevelRoadmap
var level_service: TerminalLevelService
## The Receita Federal's X-ray scanner: the service (rules + save section), its
## board, its HUD key and the inspection minigame.
var xray_service: XrayService
var xray_panel: XrayPanel
var xray_board: XrayMinigame
## One "contêiner suspeito!" from Leôncio per due inspection, not one a second.
var _xray_announced := false
var _overlay_state := {"roadmap": false, "shop": false, "settings": false, "journal": false,
	"prestige": false, "routes": false, "crew": false, "special": false,
	"minigame": false, "notices": false, "wheel": false, "daily": false,
	"xray": false}
## Whoever's dossier is open, so the objective on it keeps up with the yard.
var _inspected: Object
## The two reasons the camera stops answering a drag: a board is up over the
## port, or somebody is being carried across it.
var _input_blocked := false
var _carrying := false


func _ready() -> void:
	Telemetry.track(&"session_start", {"day": TimeManager.day, "profile": UserPreferences.last_profile})
	# The lucky wheel registers its save section before anything here can
	# save, so however the slot gets chosen the section is in place for it.
	wheel_service = WheelService.new()
	wheel_service.name = "WheelService"
	add_child(wheel_service)
	# Same reason, and it pays its rewards into the wheel's token rack.
	daily_service = DailyOrdersService.new()
	daily_service.name = "DailyOrdersService"
	daily_service.setup(wheel_service)
	add_child(daily_service)
	wheel_service.spun.connect(daily_service.note_spin)
	# The terminal level registers its save section here too, right after the
	# daily service, and pays XP for a claimed mission.
	level_service = TerminalLevelService.new()
	level_service.name = "TerminalLevelService"
	add_child(level_service)
	daily_service.mission_claimed.connect(level_service.note_mission)
	# The scanner's save section, registered with the others before any save.
	xray_service = XrayService.new()
	xray_service.name = "XrayService"
	xray_service.can_run = _xray_clock_runs
	add_child(xray_service)

	# Normally the title screen has already chosen a slot. Running this scene
	# directly — F6, the capture harness, the dev probe — falls back to the
	# first terminal so the game is never left with no save path at all.
	# The game boots straight into the port: no title screen. The terminal is
	# the one the player last ran (or the first, on a new install).
	if SaveManager.active_slot == 0:
		var last := int(UserPreferences.last_profile)
		var slot := last if last >= 1 and last <= SaveManager.PROFILE_COUNT else 1
		UserPreferences.set_last_profile(slot)
		SaveManager.use_profile(slot)
	# Running this scene directly skips the title, so the engine-drawn chrome is
	# themed here too rather than only on the way in.
	UiTheme.install_window_theme(get_window())

	shell = ResponsiveShell.new()
	shell.name = "ResponsiveShell"
	add_child(shell)

	# Main and every board it hosts run while the tree is paused; the port
	# itself, and the services whose clocks are the port's clocks, do not.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for frozen: Node in [wheel_service, daily_service, level_service, xray_service]:
		frozen.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = false
	world = PortWorld.new()
	world.name = "World"
	add_child(world)

	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	cam = PortCamera.new()
	cam.name = "Camera"
	add_child(cam)
	cam.make_current()
	cam.set_world_bottom(world.visible_bottom())
	_build_lens()

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)

	wheel_panel = LuckyWheelPanel.new()
	wheel_panel.name = "LuckyWheelPanel"
	wheel_panel.setup(wheel_service)
	add_child(wheel_panel)
	wheel_button = WheelButton.new()
	wheel_button.name = "WheelButton"
	wheel_button.setup(wheel_service)
	add_child(wheel_button)
	wheel_button.pressed.connect(wheel_panel.open)
	wheel_panel.open_changed.connect(_on_overlay_changed.bind("wheel"))
	daily_panel = DailyOrdersPanel.new()
	daily_panel.name = "DailyOrdersPanel"
	daily_panel.setup(daily_service)
	add_child(daily_panel)
	daily_button = DailyOrdersButton.new()
	daily_button.name = "DailyOrdersButton"
	daily_button.setup(daily_service)
	add_child(daily_button)
	daily_button.pressed.connect(daily_panel.open)
	daily_panel.open_changed.connect(_on_overlay_changed.bind("daily"))
	# A1 gates the two HUD keys on the terminal level; refreshed at start and on
	# every level-up. Nothing else is gated yet.
	level_service.leveled_up.connect(func(level: int, _features: Array) -> void:
		GameState.grant_level_cosmetics(level, true)
		_refresh_level_gates())
	# A save that reached a level before its cosmetics existed is handed them —
	# deferred, so a live level-up (which emits xp_changed first) gets to grant
	# its rewards switched on before this catch-up sees them.
	level_service.xp_changed.connect(func() -> void:
		(func() -> void: GameState.grant_level_cosmetics(
			level_service.rules.level, false)).call_deferred())
	GameState.grant_level_cosmetics(level_service.rules.level, false)
	# Every level pays +2% production (GameState); the wheel is not a level prize.
	# A loaded save restores the level without "levelling up" to it.
	level_service.xp_changed.connect(_refresh_level_gates)
	_refresh_level_gates()
	wheel_service.token_earned.connect(func() -> void:
		EventBus.notification_requested.emit({
			"id": "wheel_token", "kind": &"milestone", "priority": 1,
			"text": Loc.t("wheel.token_earned"),
		}))

	boost_chips = BoostChips.new()
	boost_chips.name = "BoostChips"
	add_child(boost_chips)
	level_hud = LevelHud.new()
	level_hud.name = "LevelHud"
	level_service.setup(wheel_service)
	level_hud.setup(level_service)
	add_child(level_hud)
	roadmap = LevelRoadmap.new()
	roadmap.name = "LevelRoadmap"
	add_child(roadmap)
	roadmap.setup(level_service)
	roadmap.open_changed.connect(_on_overlay_changed.bind("roadmap"))
	level_hud.roadmap_requested.connect(roadmap.open)
	# No construction waits: a machine bought is a machine working. A queue left
	# in an old save is stood up at once by GameState._tick_builds.
	GameState.build_times_enabled = false

	rail = CommandRail.new()
	rail.name = "CommandRail"
	add_child(rail)

	shop = Shop.new()
	shop.name = "Shop"
	add_child(shop)
	_refresh_level_gates()

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
	rail.set_shop_eta_source(Callable(shop, "next_purchase_eta"))

	journal = PortJournal.new()
	journal.name = "PortJournal"
	journal.setup(Progression, {
		"get_objectives": Callable(Progression, "get_all_objectives"),
		"pin": Callable(Progression, "pin_objective"),
		"get_crew": Callable(self, "_journal_crew"),
		"get_charters": Callable(self, "_journal_charters"),
	})
	add_child(journal)
	rail.journal_requested.connect(func() -> void: journal.open())
	# The console asks for the objective on its own slow tick instead of once per
	# progression event: recomputing the recommendation on every credited box
	# made a burst of purchases visibly stall the frame.
	rail.set_objective_source(Callable(self, "_next_objective"))
	Progression.objective_progressed.connect(func(_id: StringName, _progress: float, _target: float) -> void:
		journal.refresh())
	Progression.achievement_unlocked.connect(func(id: StringName, item: Dictionary) -> void:
		journal.refresh()
		# Nothing sits over the port permanently any more, so this is the one
		# moment that earns a banner: a goal actually completed.
		EventBus.notification_requested.emit({
			"id": "achievement_%s" % id, "kind": &"milestone", "priority": 2,
			"text": "Conquista: %s" % str(item.get("title", "meta cumprida")),
		}))
	Progression.album_changed.connect(func() -> void: journal.refresh())
	# A ship the album had never seen is worth a line in the diary: it is the
	# moment a silhouette there turns into a picture.
	Progression.album_ship_added.connect(func(fleet_id: String) -> void:
		var ship := FleetDB.get_ship(fleet_id)
		if ship.is_empty():
			return
		EventBus.notification_requested.emit({
			"id": "album_%s" % fleet_id, "kind": &"unlock", "priority": 2,
			"icon": UiTheme.Icon.SHIP,
			"text": Loc.t("album.new", {"name": str(ship.name)}),
		}))

	routes = RouteMap.new()
	routes.name = "RouteMap"
	add_child(routes)
	rail.routes_requested.connect(routes.open)
	routes.travel_requested.connect(_travel_to_port)
	routes.open_changed.connect(_on_overlay_changed.bind("routes"))

	prestige_dialog = PrestigeDialog.new()
	prestige_dialog.name = "PrestigeDialog"
	prestige_dialog.setup({
		"quote": Callable(self, "_prestige_quote"),
		"commit": Callable(self, "_commit_prestige"),
		"purchase_node": Callable(GameState, "buy_prestige_node"),
		# Reads, not writes. The dialog draws what is owned and what is affordable
		# and must not reach into the economy to find out.
		"shares": Callable(self, "_prestige_shares"),
		"owned_nodes": Callable(self, "_prestige_owned_nodes"),
	})
	add_child(prestige_dialog)
	rail.prestige_requested.connect(prestige_dialog.open)

	shop.open_changed.connect(_on_overlay_changed.bind("shop"))
	shop.open_changed.connect(AudioManager.set_shop_music)
	settings.open_changed.connect(_on_overlay_changed.bind("settings"))
	journal.open_changed.connect(_on_overlay_changed.bind("journal"))
	journal.arcade_requested.connect(_on_arcade_requested)
	prestige_dialog.open_changed.connect(_on_overlay_changed.bind("prestige"))

	rate_breakdown = RateBreakdown.new()
	rate_breakdown.name = "RateBreakdown"
	add_child(rate_breakdown)
	hud.breakdown_requested.connect(rate_breakdown.open)
	rate_breakdown.open_changed.connect(_on_overlay_changed.bind("rate"))

	clock = PortClock.new()
	clock.name = "PortClock"
	add_child(clock)
	hud.set_clock(clock)

	npc_card = NpcCard.new()
	npc_card.name = "NpcCard"
	add_child(npc_card)
	npc_card.open_changed.connect(_on_overlay_changed.bind("crew"))
	npc_card.open_changed.connect(func(opened: bool) -> void:
		if not opened:
			_inspected = null)
	world.npc_inspected.connect(_on_npc_inspected)
	world.npc_grab_changed.connect(_on_npc_grabbed)
	world.golden_gull_caught.connect(_on_golden_gull_caught)

	special_alert = SpecialCallAlert.new()
	special_alert.name = "SpecialCallAlert"
	add_child(special_alert)
	special_alert.open_changed.connect(func(opened: bool) -> void:
		_on_overlay_changed(opened, "special")
		# The charter interrupts: it must not stack on top of an open board
		# (the wheel's SPIN showed through under it). Close everything else.
		if opened:
			_close_other_overlays("special"))
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
		board.open_changed.connect(func(opened: bool) -> void:
			if not opened:
				# The board the queued charter was waiting on is gone: take its
				# turn before the port gives the slot to anything else.
				_flush_queued_charter())
		board.finished.connect(func(won: bool, _summary: Dictionary) -> void:
			var offer: Dictionary = board.offer()
			if bool(offer.get("arcade", false)):
				# An Arcade-key game has no charter behind it: a win pays the
				# small lump straight away, a loss just closes the board.
				if won:
					var outcome := SpecialCallDB.apply_reward(offer)
					EventBus.notification_requested.emit({
						"id": "arcade_win", "kind": &"unlock", "priority": 2,
						"text": str(outcome.get("text", "")),
					})
				return
			world.specials.resolve(won))
	_build_xray()
	# One event at a time: no charter is offered over an open board or the tour.
	world.specials.can_run = func() -> bool: return not _event_boards_busy()
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
		"ship_ready": Callable(self, "_ship_is_working"),
		"shop_open": func() -> bool: return shop != null and shop.is_open(),
		"journal_open": func() -> bool: return journal != null and journal.is_open(),
		"close_shop": func() -> void:
			if shop != null and shop.is_open():
				shop._close(),
	})
	add_child(tutorial)
	tutorial.finished.connect(_on_tutorial_finished)
	tutorial.tip_closed.connect(_on_guide_tip_closed)
	# The tour freezes the golden gull: its veil swallows taps, so a gull
	# crossing under it could only ever escape.
	tutorial.step_changed.connect(func(_i: int, _s: Dictionary) -> void:
		if world != null:
			world.gulls_frozen = true)
	# `tutorial_v2_done`: Alisson's tour is new, so a profile that finished the
	# old card tour still meets him once (he can be skipped after the hello).
	if not GameState.flags.get("tutorial_v2_done", false):
		tutorial.start()

	shell.metrics_changed.connect(_apply_view_metrics)
	shell.world_input_blocked_changed.connect(_on_world_input_blocked)
	shell.save_requested.connect(SaveManager.request_save)
	_apply_view_metrics(shell.metrics)

	# Alisson's later appearances: one look a second for a moment worth a word.
	_seed_guide_tips()
	var guide_timer := Timer.new()
	guide_timer.name = "GuideTips"
	guide_timer.wait_time = 1.0
	guide_timer.autostart = true
	guide_timer.timeout.connect(_check_guide_tips)
	add_child(guide_timer)

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


func _exit_tree() -> void:
	# Do not leak build times into whatever runs next in the same process.
	GameState.build_times_enabled = false
	# Nor a frozen tree: the Voyage scene and a wipe both leave from inside a
	# board, and the next scene must not start paused.
	if is_inside_tree():
		get_tree().paused = false


func _refresh_level_gates() -> void:
	## The two HUD keys the unlock table gates today: the wheel (level 6) and
	## the daily missions (level 7). Rules only — the buttons stay, hidden.
	if level_service == null or wheel_button == null or daily_button == null:
		return
	if rail != null:
		rail.apply_level_gates()
	if shop != null:
		shop._apply_level_gates()
	wheel_button.visible = level_service.rules.unlocked(&"wheel")
	daily_button.visible = level_service.rules.unlocked(&"daily")


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
			# Empty on purpose: with no hull alongside there is nothing to tap and
			# nothing to report, and a chip that says so is just a sign reading
			# "nothing here".
			text = ""
	# The chip is one narrow line, so the berth number goes on it and the rest of
	# the quay goes on the rail, where there is room for it.
	if world.ships.size() > 1:
		text = "Berço %d - %s" % [index + 1, text]
	_set_berth_hint(text, index)
	if world.ships.size() > 1:
		# The tag names the berth it is talking about; the lamps beside it say how
		# many others there are and which of them are under the cranes. Without
		# them a second and third ship are invisible until one is tapped.
		var quay: Array = []
		for row: Dictionary in world.berth_report():
			quay.append({
				"working": float(row.get("total", 0.0)) > 0.0,
				"focused": int(row.get("index", -1)) == index,
			})
		hud.set_quay(quay)


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


## A charter cued while another event had the port: it waits here until every
## board is down. One event at a time — the cue arrives whenever its vessel
## berths, which is whenever it happens to berth.
var _queued_charter: Dictionary = {}


func _open_minigame(offer: Dictionary) -> void:
	## The charter names its own game. An unknown one falls back to the stacker
	## rather than accepting a charter the player can never work. A cued
	## charter that arrived behind an open board waits its turn instead of
	## stacking two boards the player cannot tell apart.
	if not bool(offer.get("arcade", false)) and _event_boards_busy():
		_queued_charter = offer
		return
	_open_charter_board(offer)


func _open_charter_board(offer: Dictionary) -> void:
	# An interrupting board closes whatever menu is open so two never render
	# stacked — the same rule the special alert follows.
	_close_other_overlays("minigame")
	var board: MinigameBoard = minigame
	if StringName(offer.get("game", &"")) == SpecialCallDB.GAME_MAZE:
		board = maze
	board.open(offer)


func _event_boards_busy() -> bool:
	## One event at a time. The tour and the three minigame boards are events:
	## opening a second over them stacks two boards and the port becomes
	## unanswerable. Menus are not events — an event closes them instead.
	if tutorial != null and is_instance_valid(tutorial) \
			and tutorial.is_active():
		return true
	if bool(_overlay_state.special):
		return true
	for board in [minigame, maze, xray_board]:
		if board != null and board.is_open():
			return true
	return false


func _flush_queued_charter() -> void:
	if _queued_charter.is_empty() or _event_boards_busy():
		return
	# The vessel may have sailed while the queue waited its turn: an
	# abandoned charter is not played, and nothing was promised — the queue
	# was only a held turn, so the stale offer is dropped, not paid.
	var still_active := false
	if world != null and world.specials != null:
		still_active = not world.specials.active.is_empty() \
			and world.specials.active.get("id") == _queued_charter.get("id")
	if not still_active:
		_queued_charter = {}
		return
	var offer := _queued_charter
	_queued_charter = {}
	_open_charter_board(offer)


func _on_arcade_requested() -> void:
	## The Arcade key on the Diário: one minigame on demand, paid for by a
	# rewarded ad (`minigame_play`, 3/day). The game itself is a coin-op with a
	# small lump prize and no stake — losing costs nothing but the board.
	if not AdService.available(&"minigame_play"):
		AudioManager.play_sfx("deny")
		return
	AdService.show_rewarded(&"minigame_play", func() -> void:
		# The journal opened the board; the board closes what opened it. Both
		# up at once is the wheel-SPIN-under-a-charter bug again.
		if journal != null and journal.is_open():
			journal.close()
		var offer := {
			"title": Loc.t("arcade.title"),
			"game": SpecialCallDB.GAME_MAZE if randi() % 2 == 0 else SpecialCallDB.GAME_STACK,
			"arcade": true,
			"seconds": 42.0, "goal": 6,
			"reward": {"kind": SpecialCallDB.REWARD_LUMP, "seconds": 180.0},
		}
		_open_minigame(offer))


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


func _next_objective() -> Dictionary:
	## What the console shows the player is working toward: whatever they pinned
	## in the journal, and otherwise whatever progression recommends. Pinning is
	## an explicit choice and always outranks the recommendation.
	var pinned: Dictionary = Progression.get_pinned_objective()
	if not pinned.is_empty():
		pinned["pinned"] = true
		return pinned
	var recommended: Dictionary = Progression.get_recommended_objective()
	return recommended


func _set_berth_hint(text: String, index: int = 0) -> void:
	## One call site for the berth line, so the gantry tag and anything else that
	## reads the berth can never drift apart.
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
	var progress := hull.export_progress()
	var capacity := hull.bay_capacity()
	var done: float = float(capacity - hull.cargo_left()) \
		if hull.is_discharging() else float(progress.x)
	hud.set_berth_status({
		"text": full,
		"current": done if hull.is_working() else 0.0,
		"total": float(capacity) if hull.is_working() else 0.0,
	})


func _apply_view_metrics(metrics: Dictionary) -> void:
	world.apply_view_metrics(metrics)
	cam.apply_view_metrics(metrics)
	# The camera has to know what the chrome is standing on: the gantry spans the
	# top of the world and the console sits on the bottom of it, and without this
	# no amount of dragging brings the gate or the last row of sheds into view.
	cam.set_view_insets(Hud.BAR_H, CommandRail.BAR_H + 12.0)
	hud.apply_view_metrics(metrics)
	rail.apply_view_metrics(metrics)
	shop.set_rail(rail)
	shop.set_branch(world.rail)
	shop.apply_view_metrics(metrics)
	if routes != null:
		routes.apply_view_metrics(metrics)

	bell.apply_view_metrics(metrics)
	settings.apply_view_metrics(metrics)
	if journal != null:
		journal.apply_view_metrics(metrics)
	if prestige_dialog != null:
		prestige_dialog.apply_view_metrics(metrics)
	if rate_breakdown != null:
		rate_breakdown.apply_view_metrics(metrics)
	if tutorial != null:
		tutorial.apply_view_metrics(metrics)
	if clock != null:
		clock.apply_view_metrics(metrics)
	if npc_card != null:
		npc_card.apply_view_metrics(metrics)
	if special_alert != null:
		special_alert.apply_view_metrics(metrics)
	if wheel_panel != null:
		wheel_panel.apply_view_metrics(metrics)
	if wheel_button != null:
		wheel_button.apply_view_metrics(metrics)
	if boost_chips != null:
		boost_chips.apply_view_metrics(metrics)
	if build_hud != null:
		build_hud.apply_view_metrics(metrics)
	if level_hud != null:
		level_hud.apply_view_metrics(metrics)
	if roadmap != null:
		roadmap.apply_view_metrics(metrics)
	if daily_panel != null:
		daily_panel.apply_view_metrics(metrics)
	if daily_button != null:
		daily_button.apply_view_metrics(metrics)
	if minigame != null:
		minigame.apply_view_metrics(metrics)
	if maze != null:
		maze.apply_view_metrics(metrics)
	for node: Variant in [xray_panel, xray_board]:
		if node != null:
			node.apply_view_metrics(metrics)
	var offline := get_node_or_null(^"OfflinePopup")
	if offline != null and offline.has_method("apply_view_metrics"):
		offline.apply_view_metrics(metrics)


func _close_other_overlays(except: String) -> void:
	## An interrupting board (the special-call charter) closes whatever was open
	## so two panels never render stacked — the wheel's SPIN button used to show
	## through under the charter.
	var closers := {
		"shop": func() -> void: shop._close(),
		"settings": func() -> void: settings.close(),
		"journal": func() -> void: journal.close(),
		"routes": func() -> void: routes.close(),
		"wheel": func() -> void: wheel_panel.close(),
		"daily": func() -> void: daily_panel.close(),
		"prestige": func() -> void: prestige_dialog.close(),
		"crew": func() -> void: npc_card.close(),
		"notices": func() -> void: bell.close_log(),
		"rate": func() -> void: rate_breakdown.close(),
		"xray": func() -> void: xray_panel.close(),
		"roadmap": func() -> void: roadmap.close(),
	}
	for source: String in closers:
		if source == except or not bool(_overlay_state.get(source, false)):
			continue
		(closers[source] as Callable).call()


func _on_overlay_changed(opened: bool, source: String) -> void:
	_overlay_state[source] = opened
	# A guide's tip never talks over a board: it stands on layer 20, above all
	# of them, so whoever was in the bubble steps out the moment one opens.
	if opened and tutorial != null and tutorial.tip_active():
		tutorial.dismiss_tip()
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
			or bool(_overlay_state.notices) or bool(_overlay_state.wheel)
			or bool(_overlay_state.daily) or bool(_overlay_state.roadmap)
			or bool(_overlay_state.xray))
	_update_freeze()


func is_frozen() -> bool:
	return get_tree().paused


func _build_lens() -> void:
	## A dithered vignette between the port and the HUD (`lens.gdshader`).
	if DisplayServer.get_name() == "headless":
		return
	var layer := CanvasLayer.new()
	layer.name = "Lens"
	layer.layer = 4
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/lens.gdshader")
	material.set_shader_parameter(&"px", maxf(1.0, roundf(
		get_viewport().get_stretch_transform().get_scale().x)))
	rect.material = material
	layer.add_child(rect)


func _update_freeze() -> void:
	## Any board, minigame, scan or spin freezes the port: income, the clock,
	## ships, trucks, special calls, the golden gull, the inspection clock.
	## Nothing can arrive while the player is reading, so nothing can close what
	## they are reading. The boards themselves run (Main is PROCESS_MODE_ALWAYS);
	## GameState and TimeManager are autoloads under the paused root, so the
	## numbers hold still too. Unfreezes the moment the last board closes.
	var open := false
	for value: bool in _overlay_state.values():
		open = open or value
	if tutorial != null and is_instance_valid(tutorial) and tutorial.is_active():
		# The tour opens the shop as one of its own steps and waits on the port.
		open = false
	get_tree().paused = open


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


func _on_golden_gull_caught(prize: Dictionary, _world_pos: Vector2) -> void:
	## The gull's prize lands here, where a claimed reward touches the economy.
	## Cash is prize money (no prestige progress), a surge is session-scoped
	## like every burst, a token goes straight to the wheel's rack.
	match StringName(prize.get("kind", &"")):
		&"cash":
			GameState.grant_nonproductive_reward(
				world.gull_policy().cash_amount(prize, GameState.base_cps))
		&"surge":
			GameState.grant_surge(float(prize.get("mult", 1.0)),
				float(prize.get("seconds", 0.0)))
		&"token":
			wheel_service.grant_token(int(prize.get("tokens", 1)))
	daily_service.note_gull()


func _apply_camera_input() -> void:
	cam.set_input_enabled(not _input_blocked and not _carrying)


func _prestige_shares() -> int:
	return GameState.shares


func _prestige_owned_nodes() -> Dictionary:
	return GameState.purchased_tree_nodes


func _prestige_quote() -> Dictionary:
	return GameState.get_prestige_quote()


func _commit_prestige() -> Variant:
	var quote := GameState.get_prestige_quote()
	if not GameState.do_prestige():
		return false
	AudioManager.play_sfx("prestige")
	EventBus.notification_requested.emit({
		"kind": &"prestige", "priority": 2,
		"text": "+%d ações douradas. Reconstrução com %s." % [int(quote.gain),
			str(quote.get("rebuild_discount", "desconto"))],
	})
	return quote


func _tutorial_target_rect(target: String) -> Rect2:
	match target:
		"ship":
			# The hull's own hit area, through the camera: a fixed 100x76 box
			# at the hull's origin missed the ship at any zoom but one.
			if world != null and world.ship != null:
				var xf := world.ship.get_global_transform_with_canvas()
				var a := xf * Vector2(-8.0, -8.0)
				var b := xf * Vector2(PortLayout.SHIP_W + 8.0, world.ship.hull_height() + 8.0)
				var view := get_viewport().get_visible_rect()
				return Rect2(a, b - a).abs().intersection(view)
		"shop_card":
			if shop != null and shop.is_open() and shop._cards.has("estivador"):
				return (shop._cards["estivador"] as Control).get_global_rect()
		"journal_key":
			if rail != null:
				for entry: Dictionary in rail._key_labels:
					if str(entry.stem) == "rail.journal":
						return (entry.button as Control).get_global_rect()
		"teu":
			return hud.readout_rect() if hud != null else Rect2()
		"wheel_key":
			if wheel_button != null and wheel_button.visible:
				return wheel_button._button.get_global_rect()
		"daily_key":
			if daily_button != null and daily_button.visible:
				return daily_button._button.get_global_rect()
		"routes_key":
			return _rail_key_rect("rail.routes")
		"xray_station":
			# The post in the yard, on screen: Leôncio walks over to it.
			if world != null and world.xray_station != null and cam != null:
				var xform := get_viewport().get_canvas_transform()
				var station: XrayStation = world.xray_station
				return Rect2(xform * station.global_position,
					XrayStation.FRAME * xform.get_scale())
		"rail", "objective", "journal":
			return rail.head_rect() if rail != null else Rect2()
		"shop":
			# The SHOP key on the console when it is showing: the launcher rect
			# is the whole rail head, and Alisson stood in the middle of it.
			var key := _rail_key_rect("rail.shop")
			if not key.size.is_zero_approx():
				return key
			return shop.launcher_rect() if shop != null else Rect2()
		"prestige":
			return shop.launcher_rect() if shop != null else Rect2()
	return Rect2()


## Alisson's tips, in priority order: {id, say, target, ready}. Each shows once
## per profile (`flags.guide_tips`), only after the tour, only with no board
## open, and never two inside `GUIDE_GAP` seconds of each other.
const GUIDE_GAP := 40.0
var _guide_quiet := 20.0


func _guide_tips() -> Array[Dictionary]:
	## `who` picks the speaker (default Alisson); `seed: false` keeps a tip out of
	## `_seed_guide_tips`, for a character an old profile has never met.
	return [
		# Leôncio from the Receita Federal takes the first slot after the tour:
		# the port needs an X-ray scanner. Her tip closing opens its board.
		{"id": "receita", "who": &"receita", "say": "receita.tip.intro",
			"target": "", "seed": false,
			"ready": func() -> bool:
				return not xray_service.owned() and xray_service.on_site()},
		{"id": "receita_buy", "who": &"receita", "say": "receita.tip.buy",
			"target": "xray_station", "seed": false,
			"ready": func() -> bool:
				return _guide_seen("receita") and xray_service.can_buy()},
		{"id": "land", "say": "guide.tip.land", "target": "shop",
			"ready": func() -> bool:
				var parcel := GameState.next_land()
				return FeatureGate.unlocked(&"land") and GameState.land.is_empty() \
					and not parcel.is_empty() and GameState.can_afford(float(parcel.cost))},
		{"id": "upgrade", "say": "guide.tip.upgrade", "target": "shop",
			"ready": func() -> bool:
				if not FeatureGate.unlocked(&"upgrades") or not GameState.upgrades.is_empty():
					return false
				for item in UpgradeDB.ITEMS:
					if GameState.upgrade_available(item) and GameState.can_afford(
							UpgradeDB.price_for(item, GameState.upgrades)):
						return true
				return false},
		{"id": "wheel", "say": "guide.tip.wheel", "target": "wheel_key",
			"ready": func() -> bool: return FeatureGate.unlocked(&"wheel")},
		{"id": "daily", "say": "guide.tip.daily", "target": "daily_key",
			"ready": func() -> bool: return FeatureGate.unlocked(&"daily")},
		{"id": "gull", "say": "guide.tip.gull", "target": "",
			"ready": func() -> bool: return FeatureGate.unlocked(&"gull")},
		{"id": "routes", "say": "guide.tip.routes", "target": "routes_key",
			"ready": func() -> bool: return FeatureGate.unlocked(&"routes")},
		{"id": "prestige", "say": "guide.tip.prestige", "target": "",
			"ready": func() -> bool: return FeatureGate.unlocked(&"prestige")},
	]


func _seed_guide_tips() -> void:
	## A profile that already played past these moments is not walked back
	## through them: whatever is already true the first time this runs counts as
	## seen. A brand-new profile seeds nothing — its tour has not happened yet.
	if GameState.flags.has("guide_tips"):
		return
	var seen := {}
	if GameState.flags.get("tutorial_v2_done", false):
		for tip: Dictionary in _guide_tips():
			if bool(tip.get("seed", true)) and (tip.ready as Callable).call():
				seen[tip.id] = true
	GameState.flags["guide_tips"] = seen


func _frame_tip_target(target: String) -> void:
	## A tip about something in the yard brings the yard to it first, so the
	## guide is never pointing at a building scrolled off the screen.
	if target == "xray_station" and world != null and world.xray_station != null \
			and cam != null:
		cam.focus_on(world.xray_station.centre().y, 0.5)


func _guide_seen(id: String) -> bool:
	return (GameState.flags.get("guide_tips", {}) as Dictionary).has(id)


func _check_guide_tips() -> void:
	_guide_quiet = maxf(0.0, _guide_quiet - 1.0)
	_refresh_xray_key()
	_announce_inspection()
	if tutorial == null or tutorial.is_active() or tutorial.tip_active() \
			or _guide_quiet > 0.0 or not GameState.flags.get("tutorial_v2_done", false):
		return
	for open: bool in _overlay_state.values():
		if open:
			return
	var seen: Dictionary = GameState.flags.get("guide_tips", {})
	for tip: Dictionary in _guide_tips():
		if seen.has(tip.id) or not (tip.ready as Callable).call():
			continue
		_frame_tip_target(str(tip.target))
		if tutorial.tip(str(tip.id), str(tip.say), str(tip.target),
				StringName(tip.get("who", &"alisson"))):
			seen[tip.id] = true
			GameState.flags["guide_tips"] = seen
			_guide_quiet = GUIDE_GAP
			SaveManager.request_save(&"guide")
		return


func _rail_key_rect(stem: String) -> Rect2:
	if rail == null:
		return Rect2()
	for entry: Dictionary in rail._key_labels:
		var button := entry.button as Control
		if str(entry.stem) == stem and button.is_visible_in_tree():
			return button.get_global_rect()
	return Rect2()


func _on_tutorial_finished(skipped: bool) -> void:
	_update_freeze.call_deferred()
	if world != null:
		world.gulls_frozen = false
	GameState.flags["tutorial_done"] = true
	GameState.flags["tutorial_v2_done"] = true
	Progression.ingest_event(&"tutorial_completed", {"skipped": skipped})
	SaveManager.request_save(&"tutorial")
	# A charter that berthed during the tour plays now: the port it interrupts
	# is finally free.
	_flush_queued_charter()


func _replay_tutorial() -> void:
	settings.close()
	if tutorial != null:
		tutorial.replay()


func _ship_is_working() -> bool:
	return world != null and world.ship != null and world.ship.is_working()


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
	var tut := get_node_or_null(^"TutorialSpotlight")
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
		var parcel := GameState.next_land()
		if parcel.is_empty():
			break
		shop._on_buy_land(parcel.id)
		GameState.finish_land_works()
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
			# A flat million stops being a test grant about twenty minutes in, so
			# the cheat scales with the port: an hour of current production, or a
			# million, whichever is more. Hold Shift for a thousand of those.
			var grant := maxf(1e6, GameState.cps * 3600.0)
			if event.shift_pressed:
				grant *= 1000.0
			GameState.teus += grant
			GameState.run_teus += grant
			GameState.all_time_teus += grant
			GameState.all_time_productive_teus += grant
			EventBus.teus_changed.emit(GameState.teus)
			EventBus.notification_requested.emit({
				"id": "debug_grant", "kind": &"debug", "priority": 1,
				"text": "DEBUG +%s TEU" % GameState.fmt(grant),
			})
		KEY_F4 when OS.is_debug_build():
			TimeManager.speed_mult = 40.0 if TimeManager.speed_mult == 1.0 else 1.0


# --------------------------------------------------------------------- ports

func _travel_to_port(port: StringName) -> void:
	## Leave this port as it stands and sail. The Voyage scene does the actual
	## switch, once this world — and the save sections it registered — is gone.
	if port == PortDB.active or not SaveManager.port_open(port):
		return
	SaveManager.save_game(&"travel")
	PortDB.destination = port
	get_tree().change_scene_to_file("res://scenes/Voyage.tscn")


# ------------------------------------------------- Receita Federal: X-ray

func _build_xray() -> void:
	xray_panel = XrayPanel.new()
	xray_panel.name = "XrayPanel"
	add_child(xray_panel)
	xray_panel.setup(xray_service)
	xray_panel.open_changed.connect(_on_overlay_changed.bind("xray"))
	xray_panel.inspect_requested.connect(_open_xray)
	# The scanner is a place, not a key: the Receita's post on the gate apron.
	# Due, a tap goes straight into the scan; otherwise it opens the post's
	# board (repair it, or see when the next inspection falls).
	world.xray_station_tapped.connect(func() -> void:
		if xray_service.is_due() and xray_service.owned():
			_open_xray()
		else:
			xray_panel.open())
	xray_service.state_changed.connect(_refresh_xray_key)
	EventBus.land_bought.connect(func(_id: String) -> void: _refresh_xray_key())
	world.land_works_tapped.connect(func() -> void:
		if not shop.visible:
			shop.toggle()
		shop._on_tab("land"))
	xray_board = XrayMinigame.new()
	xray_board.name = "XrayMinigame"
	add_child(xray_board)
	xray_board.open_changed.connect(_on_overlay_changed.bind("minigame"))
	xray_board.open_changed.connect(func(opened: bool) -> void:
		if not opened:
			# A charter that berthed during the inspection plays now.
			_flush_queued_charter())
	xray_board.finished.connect(func(won: bool, summary: Dictionary) -> void:
		var benefit := xray_service.resolve(won, summary)
		_xray_announced = false
		if not benefit.is_empty():
			EventBus.notification_requested.emit({
				"id": "xray_benefit", "kind": &"unlock", "priority": 2,
				"text": Loc.t("xray.benefit", {"mult": str(int(benefit.mult)),
					"s": str(int(benefit.seconds))}),
			}))
	xray_service.inspection_ready.connect(func() -> void: _xray_announced = false)
	_refresh_xray_key()


func _open_xray() -> void:
	if xray_board == null or xray_board.is_open() or not xray_service.is_due():
		return
	if tutorial != null and is_instance_valid(tutorial) \
			and tutorial.is_active():
		return
	_close_other_overlays("minigame")
	xray_board.open(xray_service.make_offer())


func _xray_clock_runs() -> bool:
	## The inspection clock runs while the port is being played: after the tour,
	## with no board up. An inspection never falls due behind a charter — and
	## the tour being replayed is still the tour (`tutorial_v2_done` only says
	## the first one finished, so the flag alone cannot gate the clock).
	if not GameState.flags.get("tutorial_v2_done", false):
		return false
	if tutorial != null and is_instance_valid(tutorial) \
			and tutorial.is_active():
		return false
	for open: bool in _overlay_state.values():
		if open:
			return false
	return true


func _refresh_xray_key() -> void:
	## The post in the yard shows the scanner's state: boarded up, waiting, or
	## a red lamp and a "!" when a container is waiting. While it is still
	## abandoned, a wrench bubble appears once the repair is affordable.
	if world == null or world.xray_station == null:
		return
	var station: XrayStation = world.xray_station
	if not xray_service.owned():
		station.set_state(XrayStation.State.ABANDONED, xray_service.can_buy())
	elif xray_service.is_due():
		station.set_state(XrayStation.State.DUE)
	else:
		station.set_state(XrayStation.State.IDLE)


func _announce_inspection() -> void:
	## A due inspection brings Leôncio back to point at the scanner key — once per
	## inspection, never over a board or another guide.
	if _xray_announced or not xray_service.is_due() or tutorial == null \
			or tutorial.is_active() or tutorial.tip_active():
		return
	for open: bool in _overlay_state.values():
		if open:
			return
	_frame_tip_target("xray_station")
	if tutorial.tip("xray_due", "receita.tip.due", "xray_station", &"receita"):
		_xray_announced = true


func _on_guide_tip_closed(_id: String) -> void:
	## Leôncio's introduction ends with him standing at the abandoned post, not
	## with a board: the scanner is a place, and the player goes and taps it.
	_refresh_xray_key()
