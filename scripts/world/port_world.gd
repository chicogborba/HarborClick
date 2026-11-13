class_name PortWorld
extends Node2D
## Top-down terminal: yard on the left, quay and berth on the right.
##
## Draw order is handled by a single y-sorted `Entities` node so machines,
## people and container stacks never punch through each other. Anything that
## genuinely flies above the terminal (gantry booms, drones, boxes in transit)
## lives in `Overhead` instead.

## The gate barrier, across the road and swung back alongside it.
const ARM_CLOSED := PI
const ARM_OPEN := PI * 1.5
## Seconds between one hull clearing the fairway and the next one entering it.
const ARRIVAL_SPACING := 6.0
## How long a berth stays empty after a departure before it books its next call.
const TURNAROUND := 3.0
## Seconds between interaction-outline refreshes.
const OUTLINE_INTERVAL := 0.12
## Hold this long on somebody and you pick them up instead of opening their
## badge. Long enough that a tap never lifts anybody by accident, short enough
## that it does not feel like waiting.
const GRAB_HOLD := 0.26
## The pointer travel that turns a press into a camera pan rather than a tap or
## a grab.
## How far a press may travel (straight-line, viewport px) and still be a tap.
## Measured as displacement, not path length: a finger rolling on glass covers
## ten pixels of path without going anywhere, and that used to cancel the tap.
const GRAB_SLOP := 14.0
## How many hulls the water shader is told about. One per berth.
const WATER_HULLS := PortLayout.BERTH_MAX

## How many containers may be crossing the terminal on a chassis at once. Past
## this the relays overlap into a queue nobody can follow, and the tail of it is
## holding yard reservations open for no visual gain, so the rest of the moves
## take the plain arc.
const MAX_LIVE_RELAYS := 8

## Somebody tapped a person. The UI owns the dossier; the world only knows who
## was touched and what they are doing.
signal npc_inspected(profile: NpcProfile, dossier: Dictionary)
## Somebody is in the player's hand. The camera has to stop panning while they
## are, or dragging a person across the yard drags the terminal with them.
signal npc_grab_changed(held: bool)
## The golden gull was tapped. The prize is already rolled; applying it to the
## economy is Main's job, so the world only reports what was caught and where.
signal golden_gull_caught(prize: Dictionary, world_pos: Vector2)
## The Receita's post was tapped. What that means (repair, scan, status) is
## Main's call: the world does not know the scanner's rules.
signal xray_station_tapped
signal land_works_tapped

## Every berth on the quay, north to south, and the controller that works it.
## `ship` and `berth` are berth 0 — the names the rest of the game and every
## focused suite already use.
var ships: Array[Ship] = []
var berths: Array[BerthCallController] = []
var ship: Ship
var yard: ContainerYard
var structures: StructureLayer
## The crew and the work they are assigned. Both are optional as far as every
## actor is concerned: focused test harnesses build a world without them.
var crew: NpcRoster
var tasks: TaskBoard
## Rare charters: the scheduler, not the screens. Optional like the crew, so a
## focused harness can build a world without one.
var specials: SpecialCallDirector
var atmosphere: Atmosphere
var skyscape: Skyscape
var critters: Critters
var rain: Rainfall
var signals: HarbourSignals
var berth: BerthCallController
var gate: GateDock
var xray_station: XrayStation
var land_site: LandWorksSite
var rail: RailYard
var traffic: TrafficCoordinator
var _gate_view: Node2D
var _gate_trucks: Dictionary = {}     # bay index -> RoadTruck
var _gate_arm: Sprite2D
var _rail_view: Node2D
var _rake: RailRake
var fx: Fx
var _rail_furniture: Node2D
var _rail_signal_lit: Sprite2D
var _rail_crossing_lit: Array[Sprite2D] = []
var _rail_flash := 0.0

var entities: Node2D          # y-sorted ground level
var overhead: Node2D          # gantries, drones, boxes in flight

var _ground: Sprite2D
var _water: ColorRect
var _water_foam: WaterFoam
var _water_quality: WaterQuality.Level = WaterQuality.Level.MEDIUM
var decor: DecorLayer
var _decals: Node2D
var _marks: Node2D
var _props: Node2D
var _pressed := false
var _drag_accum := 0.0
var _touch_down: Dictionary = {} # touch index -> {at, moved}
var _primary_touch := -1
var _mouse_at := Vector2.ZERO
## How long the finger has been down on somebody, and where it went down. A
## negative timer means this press can no longer become a grab.
var _hold_t := -1.0
var _press_at := Vector2.ZERO
var _held_actor: StructureActor
var _hover_world_pos := Vector2(INF, INF)
var _input_enabled := true
var _traffic_in_transit: Dictionary = {} # token -> taken IMPORT record
var _arrival_wait := 1.0
var _outline_due := 0.0
var _turnaround: Dictionary = {}         # berth index -> seconds until it books again
var _live_relays := 0
var _relay_claimed_crane := false
## Off only for the capture harness's endpoint-alignment shots, which time
## themselves off a flight's own duration and need the box's arrival to be a
## function of the clock rather than of where a tractor happens to be.
var relays_enabled := true
## The gaivota dourada: a session-scoped reward clock (never persisted — a
## reward clock that survived a reload could be farmed by reloading), its own
## RNG so nothing else's seeded draws move because a gull flew, and the gull
## currently crossing the terminal, if any.
var _gull_policy := GoldenGullPolicy.new()
var _rng := RandomNumberGenerator.new()
var _gull: GoldenGull
## The first gull of a session announces itself. Once a session rather than
## once ever, because a hint is not worth a persisted field — and a player who
## comes back a week later has forgotten the bird anyway.
var _gull_hint_shown := false
## Main sets this while the tour is on: no new gull, and the one in the air holds.
var gulls_frozen := false


@onready var _containers: Texture2D = PortDB.tex("container_sheet")

## Every save section this world owns, so it can hand them all back when it goes
## away. `SaveManager` holds a `Callable`, and a `Callable` holds an object id
## rather than a reference — leave the terminal for the title screen and every
## one of these points at something freed.
var _saved_sections: Array[StringName] = []


func _register_saved(id: StringName, snapshot: Callable, restore: Callable,
		seed_new: Callable = Callable()) -> void:
	_saved_sections.append(id)
	SaveManager.register_section(id, snapshot, restore, seed_new)


func _exit_tree() -> void:
	## Going back to the title used to leave seven dead providers registered, and
	## the next autosave — and the save on the way out of the app — died on the
	## first of them. The payload each one last wrote stays in `SaveManager`, so
	## unregistering loses nothing.
	for id in _saved_sections:
		SaveManager.unregister_section(id)
	_saved_sections.clear()


func _ready() -> void:
	_rng.randomize()
	_build_water()
	_build_ground()

	_decals = Node2D.new()
	_decals.name = "Decals"
	_decals.z_index = -7
	_decals.z_as_relative = false
	add_child(_decals)
	# Channel marks stand off the starboard side of the fairway and draw *over*
	# the hull, so a ship passes behind them the way it passes a real mark.
	# Underneath, they were simply run over.
	_marks = Node2D.new()
	_marks.name = "ChannelMarks"
	_marks.z_index = 9
	_marks.z_as_relative = false
	add_child(_marks)
	_props = Node2D.new()
	_props.name = "Props"
	_props.z_index = -1
	add_child(_props)

	# Bought scenery, on its own node so the whole shelf can be thrown away and
	# rebuilt when the player switches something on without disturbing a single
	# working part of the terminal.
	decor = DecorLayer.new()
	decor.name = "Decor"
	add_child(decor)
	decor.setup(self)

	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	entities.z_index = 0
	entities.z_as_relative = false
	add_child(entities)

	overhead = Node2D.new()
	overhead.name = "Overhead"
	overhead.z_index = 30
	overhead.z_as_relative = false
	add_child(overhead)
	fx = Fx.new()
	fx.name = "Fx"
	overhead.add_child(fx)

	yard = ContainerYard.new()
	yard.name = "Yard"
	yard.y_sort_enabled = true
	entities.add_child(yard)

	# The payroll comes before the machines, because a machine asks who is
	# operating it while it is being built.
	crew = NpcRoster.new()
	crew.hired.connect(_on_crew_hired)
	tasks = TaskBoard.new()
	tasks.setup(self, crew)
	_register_saved(&"npc_roster", crew.snapshot, crew.restore, crew.seed_new)
	specials = SpecialCallDirector.new()
	specials.setup(self)
	_register_saved(&"special_calls",
		specials.snapshot, specials.restore, specials.seed_new)

	structures = StructureLayer.new()
	structures.world = self
	add_child(structures)

	_spawn_ship()
	_build_gate()
	_build_rail()
	_rebuild_decals()
	structures.rebuild()

	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	atmosphere.setup(self)

	skyscape = Skyscape.new()
	skyscape.name = "Skyscape"
	add_child(skyscape)
	skyscape.setup(self)

	xray_station = XrayStation.new()
	xray_station.name = "XrayStation"
	entities.add_child(xray_station)

	land_site = LandWorksSite.new()
	land_site.name = "LandWorksSite"
	add_child(land_site)
	land_site.setup(self)

	critters = Critters.new()
	add_child(critters)
	critters.setup(self)

	rain = Rainfall.new()
	rain.setup(self)

	signals = HarbourSignals.new()
	signals.setup(self)

	EventBus.land_bought.connect(_on_land_bought)
	EventBus.prestiged.connect(_on_prestiged)


# ---------- construction ----------

func _build_ground() -> void:
	_ground = Sprite2D.new()
	_ground.name = "Ground"
	_ground.centered = false
	_ground.z_index = -8
	_ground.z_as_relative = false
	add_child(_ground)
	_rebake_ground()


func _rebake_ground() -> void:
	_ground.texture = GroundBaker.bake(int(PortLayout.world_bottom() + 90.0),
		_rail_owned())


func _rail_owned() -> bool:
	## The branch's track is painted only once the terminal has the ground it
	# runs on: the bought parcel, the bought branch machine, or the routes
	# feature itself (the same terms `RailYard.is_open` reads). With none of them
	# the corridor stays a bare lot with a sale sign.
	return GameState.land.has("area_ferroviaria") \
		or GameState.structure_count("trem") > 0 \
		or FeatureGate.unlocked(&"routes")


func _build_water() -> void:
	_water = ColorRect.new()
	_water.name = "Water"
	_water.position = Vector2(PortLayout.WATER_X0 - 12.0, 0)
	_water.size = Vector2(PortLayout.WORLD_W - PortLayout.WATER_X0 + 12.0,
		PortLayout.world_bottom() + 220.0)
	_water.z_index = -9
	_water.z_as_relative = false
	_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/water_top.gdshader")
	mat.set_shader_parameter("world_offset", _water.position)
	mat.set_shader_parameter("shore_x", PortLayout.WATER_X0)
	mat.set_shader_parameter("water_span",
		PortLayout.WORLD_W - PortLayout.WATER_X0)
	# Every port's water is its own colour: the Pacific is not Santos bay and
	# neither is the Yangtze estuary.
	var sea := PortDB.water_colors()
	if sea.size() == 4:
		mat.set_shader_parameter("col_shallow", sea[0])
		mat.set_shader_parameter("col_mid", sea[1])
		mat.set_shader_parameter("col_deep", sea[2])
		mat.set_shader_parameter("col_abyss", sea[3])
	_water.material = mat
	add_child(_water)
	_water_quality = WaterQuality.choose(get_viewport().get_visible_rect().size)
	mat.set_shader_parameter("quality_level", int(_water_quality))
	_water_foam = WaterFoam.new()
	_water_foam.name = "WaterFoam"
	_water_foam.z_index = -7
	_water_foam.z_as_relative = false
	add_child(_water_foam)
	_water_foam.setup(_water_quality, PortLayout.world_bottom())


func _spawn_ship() -> void:
	# Named sections coexist with Main's legacy compact-yard handoff.  The
	# manifest section keeps every outbound UID, while ContainerYard ignores the
	# old flattened restore once this richer section has been applied.
	_register_saved(&"cargo_yard", yard.snapshot, yard.restore_saved,
		yard.seed_new)
	for index in PortLayout.berth_count():
		_add_berth(index)
	ship = ships[0]
	berth = berths[0]
	traffic = TrafficCoordinator.new()
	_register_saved(&"traffic_cargo", _traffic_snapshot, _traffic_restore,
		_traffic_seed)
	gate = GateDock.new()
	gate.setup(self, yard)
	gate.changed.connect(_sync_gate_view)
	gate.notice_requested.connect(
		func(notice: Dictionary) -> void:
			EventBus.notification_requested.emit({
				"id": "gate_%s" % notice.get("code", "notice"),
				"kind": &"blocked", "priority": 1,
				"text": notice.get("text", "")}))
	_register_saved(&"gate_dock", gate.snapshot, gate.restore, gate.seed_new)
	rail = RailYard.new()
	rail.setup(self, yard)
	rail.changed.connect(_sync_rail_view)
	rail.notice_requested.connect(
		func(notice: Dictionary) -> void:
			EventBus.notification_requested.emit({
				"id": "rail_%s" % notice.get("code", "notice"),
				"kind": StringName(notice.get("kind", &"blocked")),
				"priority": int(notice.get("priority", 1)),
				"text": notice.get("text", "")}))
	_register_saved(&"rail_yard", rail.snapshot, rail.restore, rail.seed_new)
	_request_arrivals()


func _add_berth(index: int) -> void:
	## One berth: a hull, its controller, and its own persisted section. Berth 0
	## keeps the original section name so existing saves restore untouched.
	var hull := Ship.new()
	hull.name = "Ship" if index == 0 else "Ship%d" % (index + 1)
	hull.berth_index = index
	hull.z_index = 8
	hull.z_as_relative = false
	hull.position = hull.berth_position()
	hull.visible = false
	add_child(hull)
	var controller := BerthCallController.new()
	controller.setup(self, hull, yard)
	hull.departed.connect(_on_ship_departed.bind(index))
	hull.phase_changed.connect(_on_hull_phase.bind(index))
	controller.move_started.connect(_on_berth_move_started)
	ships.append(hull)
	berths.append(controller)
	_register_saved(
		&"berth_call" if index == 0 else StringName("berth_call%d" % (index + 1)),
		controller.snapshot, controller.restore, controller.seed_new)


func _ensure_berths() -> void:
	## Buying land lengthens the quay. A berth is never taken away again: a ship
	## alongside one that vanished would take its manifest with it.
	var wanted := PortLayout.berth_count()
	while ships.size() < wanted:
		var index := ships.size()
		_add_berth(index)
		EventBus.notification_requested.emit({
			# Routine, not a toast: an announcement about a ship arriving is the
			# one interruption the player asked to stop seeing. The berth lamps on
			# the gantry already show a new berth exists, and the Diário keeps the
			# line.
			"id": "berth_open_%d" % index, "kind": &"arrival", "priority": 1,
			"text": "Berço %d liberado. Mais um navio pode atracar." % (index + 1),
		})
	_request_arrivals()


func _rebuild_decals() -> void:
	for child in _decals.get_children():
		child.queue_free()
	for child in _marks.get_children():
		child.queue_free()
	_build_channel_marks()
	for child in _props.get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 776655

	# Bollards along the quay edge. `PortLayout` owns where they are, because the
	# ships' mooring lines are made fast to these exact ones.
	var bollard_tex: Texture2D = preload("res://assets/sprites/prop_bollard.png")
	for index in PortLayout.bollard_count():
		var spot := PortLayout.bollard_position(index)
		# Light falls from the upper left everywhere in this game, so everything
		# standing on the concrete drops something to the lower right.
		var shade := Sprite2D.new()
		shade.texture = bollard_tex
		shade.centered = false
		shade.modulate = Color(0.06, 0.07, 0.11, 0.30)
		shade.position = spot + Vector2(1.0, 2.0)
		_decals.add_child(shade)
		var b := Sprite2D.new()
		b.texture = bollard_tex
		b.centered = false
		b.position = spot
		_decals.add_child(b)


	# puddles and oil marks on the pavement
	for i in 18:
		var p := Sprite2D.new()
		p.texture = preload("res://assets/sprites/prop_puddle.png")
		p.centered = false
		p.position = Vector2(rng.randf_range(16.0, PortLayout.QUAY_X1 - 20.0),
			rng.randf_range(PortLayout.TOP_MARGIN, PortLayout.world_bottom() - 40.0))
		_decals.add_child(p)

	# greenery on the verge, and cones dotted around the yard
	for i in int(PortLayout.world_bottom() / 76.0):
		var ty := 24.0 + i * 76.0 + rng.randf_range(-14.0, 14.0)
		var tree := Sprite2D.new()
		tree.texture = PortDB.tex("prop_tree")
		tree.centered = false
		tree.position = Vector2(-12.0 + rng.randf_range(0.0, 4.0), ty)
		_props.add_child(tree)
		if rng.randf() < 0.55:
			var bush := Sprite2D.new()
			bush.texture = PortDB.tex("prop_bush")
			bush.centered = false
			bush.position = Vector2(-4.0, ty + 34.0)
			_props.add_child(bush)
	for i in 7:
		var c := Sprite2D.new()
		c.texture = preload("res://assets/sprites/prop_cone.png")
		c.centered = false
		# Clear of the carriageway: a cone in a live traffic lane is litter,
		# not detail.
		c.position = Vector2(rng.randf_range(PortLayout.BLOCK_X0, PortLayout.QUAY_X1 - 16.0),
			rng.randf_range(PortLayout.YARD_Y0, PortLayout.world_bottom() - 70.0))
		_props.add_child(c)
	_build_harbor_furniture()


func _build_harbor_furniture() -> void:
	## Functional clutter is grouped where real crews need it: fire and rescue
	## points along the berth, spare parts by the workshop apron. It never sits
	## in a truck lane or on a container stack.
	var y := PortLayout.TOP_MARGIN + 58.0
	var station := 0
	while y < PortLayout.world_bottom() - 28.0:
		var prop := Sprite2D.new()
		prop.texture = preload("res://assets/sprites/prop_hydrant.png") \
			if station % 2 == 0 else preload("res://assets/sprites/prop_lifebuoy.png")
		prop.centered = true
		prop.position = Vector2(PortLayout.WATER_X0 - 6.0, y)
		_props.add_child(prop)
		y += 92.0
		station += 1

	var pallet := Sprite2D.new()
	pallet.texture = preload("res://assets/sprites/prop_pallet.png")
	pallet.centered = false
	pallet.position = Vector2(PortLayout.QUAY_X0 + 5.0,
		PortLayout.service_y() - 24.0)
	_props.add_child(pallet)
	var reel := Sprite2D.new()
	reel.texture = preload("res://assets/sprites/prop_cable_reel.png")
	reel.centered = true
	reel.position = Vector2(PortLayout.QUAY_X0 + 27.0,
		PortLayout.service_y() - 18.0)
	_props.add_child(reel)


func _build_channel_marks() -> void:
	## A line of port-hand marks down the edge of the fairway, from the open
	## water south of the berth to the exit past the top of the quay.
	var sheet: Texture2D = preload("res://assets/sprites/prop_buoy.png")
	var lane_x := PortLayout.WORLD_W - 9.0
	var y := PortLayout.TOP_MARGIN - 10.0
	var index := 0
	while y < PortLayout.world_bottom() + 60.0:
		var buoy := Sprite2D.new()
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2((index % 2) * 12, 0, 12, 14)
		buoy.texture = frame
		buoy.centered = true
		buoy.position = Vector2(lane_x, y)
		_marks.add_child(buoy)
		y += 104.0
		index += 1


# ---------- land ----------

func _on_land_bought(_id: String) -> void:
	yard.resize()
	# A longer quay may have room for another berth.
	_ensure_berths()
	_rebake_ground()
	_water.size.y = PortLayout.world_bottom() + 220.0
	if _water_foam != null:
		_water_foam.rebuild(PortLayout.world_bottom())
	_rebuild_decals()
	structures.rebuild()
	atmosphere.rebuild_lamps()
	if skyscape != null:
		skyscape.rebuild()
	if rain != null:
		rain.rebuild()
	if signals != null:
		signals.rebuild()
	for i in 6:
		spawn_dust(Vector2(randf_range(40.0, 180.0),
			PortLayout.yard_bottom() - randf_range(10.0, 80.0)))


func _on_prestiged(_shares: int) -> void:
	## Visual state is rebuilt from economic state, avoiding stale actors and
	## duplicate props after a prestige reset.
	yard.resize()
	_rebake_ground()
	_water.size.y = PortLayout.world_bottom() + 220.0
	if _water_foam != null:
		_water_foam.rebuild(PortLayout.world_bottom())
	if structures != null:
		structures.rebuild()
	_rebuild_decals()
	structures.rebuild()
	atmosphere.rebuild_lamps()
	if skyscape != null:
		skyscape.rebuild()


func visible_bottom() -> float:
	return PortLayout.world_bottom()


func set_input_enabled(input_allowed: bool) -> void:
	_input_enabled = input_allowed
	for controller in berths:
		controller.set_input_enabled(input_allowed)
	if not input_allowed:
		_pressed = false
		_hold_t = -1.0
		_touch_down.clear()
		_primary_touch = -1
		# An overlay opening with somebody in the air would leave them there, in
		# front of the board, with nothing able to put them down.
		drop_held()
	_refresh_interaction_outlines()


func apply_view_metrics(metrics: Dictionary) -> void:
	_apply_water_quality(metrics)
	for controller in berths:
		controller.apply_view_metrics(metrics)


func _apply_water_quality(metrics: Dictionary) -> void:
	var level := WaterQuality.from_metrics(metrics, get_viewport().get_visible_rect().size)
	if level == _water_quality:
		return
	_water_quality = level
	if _water != null and _water.material is ShaderMaterial:
		(_water.material as ShaderMaterial).set_shader_parameter("quality_level", int(level))
	if _water_foam != null:
		_water_foam.set_quality(level)


func _process(delta: float) -> void:
	_feed_water_shader()
	_allocate_cranes()
	for controller in berths:
		controller.tick(delta)
	if specials != null:
		specials.tick(delta)
	if gate != null:
		gate.tick(delta)
	if rail != null:
		rail.tick(delta)
	_drive_gate_arm(delta)
	_drive_rail_furniture(delta)
	_drive_arrivals(delta)
	_tick_hold(delta)
	_tick_golden_gull(delta)
	# The outlines are a hover affordance, and answering "can this be worked?"
	# walks the whole yard once per ship and once per truck. At sixty hertz on a
	# bought-out port that was the frame; nobody can see the difference at eight.
	_outline_due -= delta
	if _outline_due <= 0.0:
		_outline_due = OUTLINE_INTERVAL
		_refresh_interaction_outlines()


# ---------- the berths ----------

func berth_hulls() -> Array[Ship]:
	## Every hull on the quay. A focused harness may build a single `ship` without
	## the berth arrays at all; treat that as the one-berth port it is, so nothing
	## downstream has to know which kind of world it is running in.
	if not ships.is_empty():
		return ships
	var single: Array[Ship] = []
	if ship != null:
		single.append(ship)
	return single


func berth_controller(index: int) -> BerthCallController:
	if index >= 0 and index < berths.size():
		return berths[index]
	return berth


func any_ship_working() -> bool:
	for hull in berth_hulls():
		if hull.is_working():
			return true
	return false


func manoeuvring_ship() -> Ship:
	## The hull currently on the move, which is the one the tugs are on and the one
	## the water is reacting to. At most one, by design.
	for hull in berth_hulls():
		if hull.visible and (hull.phase == Ship.Phase.ARRIVING
				or hull.phase == Ship.Phase.DEPARTING):
			return hull
	return null


func focus_berth() -> int:
	## Which berth the HUD talks about: one being worked, else one manoeuvring,
	## else the first. With three ships alongside the board follows the work.
	var hulls := berth_hulls()
	for index in hulls.size():
		if hulls[index].is_working():
			return index
	for index in hulls.size():
		if hulls[index].phase != Ship.Phase.AWAY:
			return index
	return 0


func working_ships() -> Array[Ship]:
	var busy: Array[Ship] = []
	for hull in berth_hulls():
		if hull.is_working():
			busy.append(hull)
	return busy


func _fairway_busy() -> bool:
	return manoeuvring_ship() != null


func is_moored(index: int) -> bool:
	## Alongside and in the way. A berth counts from the moment its hull is on
	## screen, including while it is still being worked.
	var hulls := berth_hulls()
	if index < 0 or index >= hulls.size():
		return false
	var hull := hulls[index]
	return hull.visible and hull.phase != Ship.Phase.AWAY


func lane_clear_north(index: int) -> bool:
	## Is the water between this berth and the top of the world empty?
	##
	## The hull is drawn bow-up and can only steam bow-first, so north is the way
	## **out**: this is the question a departure asks. The channel fits one hull,
	## so anything moored above is in the way — being "outboard" of it is not
	## something the geometry allows. When it is not clear the ship is taken off
	## to the offing instead, beam-on, which crosses nobody.
	for other in index:
		if is_moored(other):
			return false
	return true


func lane_clear_south(index: int) -> bool:
	## The same question below: south is the way **in**, so this is the one an
	## arrival asks. These two answers are not interchangeable, and swapping them
	## sails a ship straight through a moored one.
	for other in range(index + 1, berth_hulls().size()):
		if is_moored(other):
			return false
	return true


func _request_arrivals() -> void:
	_arrival_wait = minf(_arrival_wait, 0.4)


func _allocate_cranes() -> void:
	## One gang, divided by the player's standing order. Before this every berth
	## was handed the whole port's rate independently, so a second and third hull
	## multiplied the same machines and there was nothing to decide about them.
	##
	## Done here rather than inside the controller because it is the *quay* that
	## has to be looked at to answer it: what a berth gets depends on what the
	## other berths are doing.
	var quay: Array = []
	for index in berths.size():
		var hull: Ship = ships[index] if index < ships.size() else null
		var working := hull != null and hull.is_working()
		var capacity := float(hull.bay_capacity()) if working else 0.0
		var done := 0.0
		if working:
			done = float(hull.bay_capacity() - hull.cargo_left()) \
				if hull.is_discharging() else float(hull.export_progress().x)
		quay.append({"working": working, "progress": done, "capacity": capacity})
	var rates := CraneAllocation.allocate(quay,
		BerthCallController.pool_rate(),
		CraneAllocation.coerce(GameState.crane_policy),
		BerthCallController.AUTO_RATE_CAP)
	for index in berths.size():
		berths[index].set_auto_share(rates[index])


func berth_report() -> Array[Dictionary]:
	## One row per berth for the board: what it is doing, on which vessel, how far
	## through, and — when it is empty — how long until the next one ties up.
	##
	## The ETA is the real one the sequencer will honour, not an estimate: with a
	## shared fairway an empty berth may be waiting on its own turnaround, on the
	## spacing, or on another hull still under way, and the player should be able
	## to see which.
	var rows: Array[Dictionary] = []
	var hulls := berth_hulls()
	for index in hulls.size():
		var hull := hulls[index]
		var controller := berth_controller(index)
		var capacity := hull.bay_capacity()
		var done := capacity - hull.cargo_left() if hull.is_discharging() \
			else hull.export_progress().x
		var silhouette := ShipCatalog.get_silhouette(
			StringName(hull.ship_variant.get("silhouette_id", "")))
		rows.append({
			"index": index,
			"phase": int(hull.phase),
			"state": _berth_state_text(hull),
			"vessel": str(silhouette.get("title", "")),
			"special": hull.is_special(),
			"current": float(done) if hull.is_working() else 0.0,
			"total": float(capacity) if hull.is_working() else 0.0,
			"auto_rate": controller.auto_rate() if controller != null else 0.0,
			"eta": _berth_eta(index),
		})
	return rows


func _berth_state_text(hull: Ship) -> String:
	match hull.phase:
		Ship.Phase.DISCHARGING:
			return "Descarga"
		Ship.Phase.WAITING_EXPORT:
			return "Aguardando exportação"
		Ship.Phase.LOADING:
			return "Embarque"
		Ship.Phase.ARRIVING:
			return "Atracando"
		Ship.Phase.DEPARTING:
			return "Saindo"
	return "Livre"


func _berth_eta(index: int) -> float:
	## Seconds until this berth's next hull can start its run. Negative means it is
	## not waiting for one — there is already a ship on it.
	if index < 0 or index >= ships.size() or ships[index].phase != Ship.Phase.AWAY:
		return -1.0
	var wait := maxf(0.0, float(_turnaround.get(index, 0.0)))
	wait = maxf(wait, maxf(0.0, _arrival_wait))
	if _fairway_busy():
		# Whatever is under way has to be alongside first. Its own tween is the
		# floor, and it is the same 5.4 s for every class.
		wait = maxf(wait, 1.5)
	# Berths ahead of this one in the queue sail first, one spacing apart.
	var ahead := 0
	for other in index:
		if ships[other].phase == Ship.Phase.AWAY \
				and float(_turnaround.get(other, 0.0)) <= wait:
			ahead += 1
	return wait + float(ahead) * ARRIVAL_SPACING


func _sort_hull_depth() -> void:
	## A hull under way passes outboard of the moored ones, so it has to draw over
	## them for those few seconds. Everything else keeps the berth depth.
	for hull in berth_hulls():
		var moving := hull.phase == Ship.Phase.ARRIVING \
			or hull.phase == Ship.Phase.DEPARTING
		hull.z_index = 10 if moving else 8


func _drive_arrivals(delta: float) -> void:
	## The berths share one fairway, so arrivals are sequenced: exactly one hull is
	## ever under way. Without this two ships would slide through each other in a
	## channel only wide enough for one.
	if berths.is_empty():
		return
	_sort_hull_depth()
	for index: int in _turnaround.keys():
		var left := float(_turnaround[index]) - delta
		if left <= 0.0:
			_turnaround.erase(index)
			if index < berths.size():
				berths[index].seed_new()
		else:
			_turnaround[index] = left
	_arrival_wait -= delta
	if _arrival_wait > 0.0 or _fairway_busy():
		return
	_arrival_wait = ARRIVAL_SPACING
	for index in berths.size():
		if ships[index].phase != Ship.Phase.AWAY or _turnaround.has(index):
			continue
		# A booked charter takes the next hull to sail, whichever berth that is, so
		# the special vessel *arrives* up the fairway. Claiming it here rather than
		# at the previous departure means a charter accepted on a quiet quay — or
		# restored into one — still turns up.
		if specials != null:
			var forced := specials.claim_variant(index)
			if not forced.is_empty():
				berths[index].seed_new(0, forced)
		berths[index].arrive(lane_clear_south(index))
		return


func _on_ship_departed(index: int) -> void:
	EventBus.ship_departed.emit()
	# The berth stays empty for a moment, then books its next call. Counted down in
	# `_drive_arrivals` rather than awaited on a timer, so the wait is a number the
	# board can show as an ETA instead of a promise nothing can read.
	# The lane the berth just worked decides how long it stands empty. A coastal
	# run books again almost at once; an ocean crossing leaves the quay quiet.
	# Without this the cadence in `RouteDB` was data nobody read, and "maior
	# frete" would have been strictly better than "mais escalas".
	_turnaround[index] = TURNAROUND * berths[index].lane_interval()
	_request_arrivals()


func _build_gate() -> void:
	## The perimeter, and the one hole in it. A fence across the top of the
	## terminal is what makes the road mean anything: everything the player
	## sees inside came through this gap, past this guard house, under this
	## barrier.
	var furniture := Node2D.new()
	furniture.name = "Gate"
	entities.add_child(furniture)

	var fence: Texture2D = preload("res://assets/sprites/fence.png")
	var x := PortLayout.YARD_X0 - 10.0
	while x < PortLayout.QUAY_X1:
		# leave the carriageway clear, kerb to kerb
		if x + fence.get_width() > PortLayout.ROAD_X0 - 2.0 \
				and x < PortLayout.ROAD_X1 + 2.0:
			x += fence.get_width()
			continue
		var post := Sprite2D.new()
		post.texture = fence
		post.centered = false
		post.position = Vector2(x, PortLayout.FENCE_Y)
		furniture.add_child(post)
		x += fence.get_width()

	var hut := Sprite2D.new()
	hut.texture = preload("res://assets/sprites/bld_customs.png")
	hut.centered = false
	hut.position = Vector2(PortLayout.ROAD_X1 + 2.0, PortLayout.FENCE_Y - 8.0)
	furniture.add_child(hut)

	# The arm pivots on its own corner against the hut, so it sweeps across the
	# carriageway and parks alongside it rather than shrinking into nothing.
	_gate_arm = Sprite2D.new()
	_gate_arm.texture = preload("res://assets/sprites/bld_customs_arm.png")
	_gate_arm.centered = false
	_gate_arm.position = Vector2(PortLayout.ROAD_X1 + 2.0, PortLayout.GATE_ARM_Y)
	_gate_arm.rotation = ARM_CLOSED
	furniture.add_child(_gate_arm)


func _build_rail() -> void:
	## The furniture that makes the branch a railway rather than two stripes of
	## ballast: the ramp board, the signal that protects the entrance, and a
	## crossing mast on each side of the public road.
	##
	## None of it is decoration in the sense of being inert. The signal reads the
	## service state and the crossing flashes for a train that is actually on the
	## branch, so a player who never opens a menu still knows one is coming.
	var furniture := Node2D.new()
	furniture.name = "Rail"
	entities.add_child(furniture)
	_rail_furniture = furniture

	# The transit shed at the head of the platform, then the board on the platform
	# at the other end. Both stand on the goods apron `GroundBaker` paints, which
	# is what stopped them reading as props dropped onto bare tarmac: the board
	# used to sit forty pixels north of the running line, in the middle of the
	# yard, over the wagons, attached to nothing.
	var shed := Sprite2D.new()
	shed.texture = preload("res://assets/sprites/rail_shed.png")
	shed.centered = false
	shed.position = PortLayout.rail_shed_rect().position
	furniture.add_child(shed)

	var gantry := Sprite2D.new()
	gantry.texture = preload("res://assets/sprites/rail_gantry.png")
	gantry.centered = true
	# Straddling the running line, standing on the two steel rails painted for it.
	gantry.position = Vector2(PortLayout.rail_gantry_x(),
		PortLayout.rail_y() + 3.0)
	furniture.add_child(gantry)

	var board := Sprite2D.new()
	board.texture = preload("res://assets/sprites/rail_board.png")
	board.centered = false
	board.position = PortLayout.rail_board_position()
	furniture.add_child(board)

	var mast := Sprite2D.new()
	mast.texture = preload("res://assets/sprites/rail_signal.png")
	mast.centered = false
	mast.position = PortLayout.rail_signal_position()
	furniture.add_child(mast)

	_rail_signal_lit = Sprite2D.new()
	var aspect := AtlasTexture.new()
	aspect.atlas = preload("res://assets/sprites/rail_signal_lit.png")
	aspect.region = Rect2(0, 0, 10, 18)
	_rail_signal_lit.texture = aspect
	_rail_signal_lit.centered = false
	_rail_signal_lit.position = mast.position
	furniture.add_child(_rail_signal_lit)

	_rail_crossing_lit.clear()
	for side in 2:
		var post := Sprite2D.new()
		post.texture = preload("res://assets/sprites/rail_crossing.png")
		post.centered = false
		post.position = PortLayout.rail_crossing_mast(side)
		furniture.add_child(post)
		var lamps := Sprite2D.new()
		var lit := AtlasTexture.new()
		lit.atlas = preload("res://assets/sprites/rail_crossing_lit.png")
		lit.region = Rect2(0, 0, 12, 15)
		lamps.texture = lit
		lamps.centered = false
		lamps.position = post.position
		lamps.visible = false
		furniture.add_child(lamps)
		_rail_crossing_lit.append(lamps)


func _drive_rail_furniture(delta: float) -> void:
	## The signal shows the aspect the controller is in, and the crossing wig-wags
	## whenever a train is moving on the branch. Both are read straight off the
	## service state, so neither can claim something the branch is not doing.
	if rail == null:
		return
	# Shed, gantry, board, signal and crossings only stand once the railway runs;
	# before that the branch is bare ballast, an unused siding.
	if _rail_furniture != null:
		_rail_furniture.visible = rail.is_open()
	if _rail_signal_lit != null:
		var atlas := _rail_signal_lit.texture as AtlasTexture
		if atlas != null:
			atlas.region = Rect2(_aspect_frame(rail.signal_aspect()) * 10, 0, 10, 18)
	if _rail_crossing_lit.is_empty():
		return
	var moving := rail.stage() == RailYard.Stage.ARRIVING \
		or rail.stage() == RailYard.Stage.DEPARTING \
		or rail.stage() == RailYard.Stage.RUNAROUND
	if not moving:
		_rail_flash = 0.0
		for lamps in _rail_crossing_lit:
			lamps.visible = false
		return
	var was := _rail_flash
	_rail_flash = fmod(_rail_flash + delta, 1.0)
	var left := _rail_flash < 0.5
	# One strike of the gong per lamp, on the lamp's own beat. Ringing off the
	# same clock that drives the wig-wag is what keeps the sound and the picture
	# from drifting apart; a looping sample would not survive the first frame
	# the game dropped.
	if _rail_flash < was or (was < 0.5 and _rail_flash >= 0.5):
		AudioManager.play_sfx("crossing_bell", 0.03, -13.0)
	for index in _rail_crossing_lit.size():
		var lamps := _rail_crossing_lit[index]
		lamps.visible = true
		var atlas := lamps.texture as AtlasTexture
		if atlas != null:
			atlas.region = Rect2((0 if left else 1) * 12, 0, 12, 15)


func _aspect_frame(aspect: StringName) -> int:
	match aspect:
		RailYard.ASPECT_DANGER:
			return 0
		RailYard.ASPECT_APPROACH:
			return 1
		_:
			return 2


func _sync_rail_view() -> void:
	## One rake at a time, kept alive across updates for the same reason the gate
	## keeps its trucks: rebuilding it whenever a box moved would restart the run
	## in, and the train would never actually get anywhere.
	if _rail_view == null:
		_rail_view = Node2D.new()
		_rail_view.name = "RailYard"
		_rail_view.y_sort_enabled = true
		entities.add_child(_rail_view)
	if rail == null:
		return
	if rail.service.is_empty():
		if _rake != null and is_instance_valid(_rake):
			_rake.queue_free()
		_rake = null
		return
	if _rake == null or not is_instance_valid(_rake):
		_rake = RailRake.new()
		_rake.setup(rail.length(), rail.stage() != RailYard.Stage.ARRIVING)
		_rail_view.add_child(_rake)
		_rake.arrived.connect(rail.notify_arrived)
		_rake.ran_around.connect(rail.notify_ran_around)
		_rake.departed.connect(_on_rake_departed)
	_rake.sync(rail)
	match rail.stage():
		RailYard.Stage.RUNAROUND:
			_rake.run_around()
		RailYard.Stage.DEPARTING:
			_rake.run_out()
		_:
			pass


func _on_rake_departed() -> void:
	if _rake != null and is_instance_valid(_rake):
		_rake.queue_free()
	_rake = null
	if rail != null:
		rail.notify_departed()


func _sync_gate_view() -> void:
	## One truck per occupied bay, kept alive across updates. Rebuilding the
	## whole apron on every change — which is what this used to do — restarted
	## the drive each time a box moved, so a truck could never actually go
	## anywhere.
	if _gate_view == null:
		_gate_view = Node2D.new()
		_gate_view.name = "GateDock"
		_gate_view.y_sort_enabled = true
		entities.add_child(_gate_view)
	if gate == null:
		return
	for bay: int in gate.bays.keys():
		var record: Dictionary = gate.bays[bay]
		var truck: RoadTruck = _gate_trucks.get(bay)
		if truck == null or not is_instance_valid(truck):
			truck = RoadTruck.new()
			# The same handful of hauliers serve this port, one per bay, so a
			# driver is a face the player sees again rather than a new stranger
			# every nine seconds.
			if crew != null:
				truck.driver = crew.profile_for("road_truck", bay)
			truck.setup(self, bay, _bed_colors(record),
				int(record.get("stage", GateDock.Stage.DOCKED))
					!= int(GateDock.Stage.ARRIVING))
			_gate_trucks[bay] = truck
			_gate_view.add_child(truck)
			truck.arrived.connect(gate.notify_docked.bind(bay))
			truck.departed.connect(_on_truck_departed.bind(bay))
		truck.set_colors(_bed_colors(record))
		if int(record.get("stage", GateDock.Stage.DOCKED)) \
				== int(GateDock.Stage.LEAVING):
			truck.depart()
	for bay: int in _gate_trucks.keys():
		if gate.bays.has(bay):
			continue
		var stale: RoadTruck = _gate_trucks[bay]
		_gate_trucks.erase(bay)
		if is_instance_valid(stale):
			stale.queue_free()


func _bed_colors(record: Dictionary) -> Array[int]:
	var colors: Array[int] = []
	for unit: CargoUnit in record.get("cargo", []) as Array:
		colors.append(unit.color)
	return colors


func _on_truck_departed(bay: int) -> void:
	_gate_trucks.erase(bay)
	if gate != null:
		gate.notify_departed(bay)


func _drive_gate_arm(delta: float) -> void:
	## Up for anything on the gate stretch of road, down the rest of the time.
	## A barrier that never moves is scenery; one that lifts is the reason the
	## road exists.
	if _gate_arm == null or traffic == null:
		return
	var open := traffic.any_within(
		Vector2(PortLayout.GATE_ROAD_X, PortLayout.GATE_ARM_Y), 32.0)
	_gate_arm.rotation = move_toward(_gate_arm.rotation,
		ARM_OPEN if open else ARM_CLOSED, delta * 2.6)


func _feed_water_shader() -> void:
	if _water == null or ship == null or not (_water.material is ShaderMaterial):
		return
	var mat := _water.material as ShaderMaterial
	var driver := ship
	var strength := 0.0
	for hull in berth_hulls():
		if not hull.visible:
			continue
		if hull.wake_strength() > strength:
			strength = hull.wake_strength()
			driver = hull
	mat.set_shader_parameter("ship_speed", strength)
	if strength > 0.0:
		# Shader space is world space offset by the water rect's own origin, and
		# the half-length is *this* hull's. It used to be the berth envelope, so
		# once classes had their own lengths the bow wave was drawn up to forty
		# pixels off the end of the ship it belonged to.
		mat.set_shader_parameter("ship_centre",
			driver.hull_centre() - _water.position)
		mat.set_shader_parameter("ship_half",
			Vector2(PortLayout.SHIP_W, driver.hull_height()) * 0.5)
	# Every hull on the water, moving or not: a ship lying alongside still works
	# the water around it, and a berth is what the player is looking at almost all
	# of the time. Without this the surface only ever moved during the five
	# seconds of an arrival.
	var rects := PackedVector4Array()
	for hull in berth_hulls():
		if not hull.visible or rects.size() >= WATER_HULLS:
			continue
		var centre := hull.hull_centre() - _water.position
		rects.append(Vector4(centre.x, centre.y,
			PortLayout.SHIP_W * 0.5, hull.hull_height() * 0.5))
	mat.set_shader_parameter("hull_count", rects.size())
	if rects.size() > 0:
		while rects.size() < WATER_HULLS:
			rects.append(Vector4(-9999.0, -9999.0, 1.0, 1.0))
		mat.set_shader_parameter("hulls", rects)


# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	# Touch and mouse each arrive twice — the engine emulates one from the other
	# (`emulate_touch_from_mouse`, and mouse-from-touch by default). The emulated
	# copy carries DEVICE_ID_EMULATION and is skipped, so one finger is one tap.
	if event is InputEventScreenTouch:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event.pressed:
			_touch_down[event.index] = {"at": event.position, "moved": 0.0}
			if _touch_down.size() == 1:
				_primary_touch = event.index
				_begin_press(_to_world(event.position))
		else:
			_end_touch(event.index, event.position)
	elif event is InputEventScreenDrag:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _touch_down.has(event.index):
			var down: Dictionary = _touch_down[event.index]
			down.moved = maxf(float(down.moved),
				(event.position - (down.at as Vector2)).length())
			if event.index == _primary_touch and _pressed:
				_drag_accum = float(down.moved)
				_move_press(_to_world(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_hover_world_pos = _to_world(event.position)
		if event.pressed:
			_mouse_at = event.position
			_begin_press(_hover_world_pos)
		elif _pressed:
			_drag_accum = (event.position - _mouse_at).length()
			_end_press(_hover_world_pos)
	elif event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_hover_world_pos = _to_world(event.position)
		if _pressed:
			_drag_accum = maxf(_drag_accum, (event.position - _mouse_at).length())
			_move_press(_hover_world_pos)
		# A moving pointer refreshes on its own event rather than waiting out the
		# tick, so the outline still feels immediate under the cursor.
		_outline_due = OUTLINE_INTERVAL
		_refresh_interaction_outlines()


func _end_touch(index: int, screen_pos: Vector2) -> void:
	## Every finger is its own tap. With one press slot a second thumb landing
	## before the first lifted overwrote it, and the second thumb's tap was lost
	## — the fast two-thumb tapping a clicker is played with.
	var down: Dictionary = _touch_down.get(index, {})
	_touch_down.erase(index)
	if down.is_empty():
		return
	var moved := maxf(float(down.moved), (screen_pos - (down.at as Vector2)).length())
	if index == _primary_touch:
		_primary_touch = -1
		_drag_accum = moved
		_end_press(_to_world(screen_pos))
	elif moved < GRAB_SLOP:
		_try_tap(_to_world(screen_pos))


func _begin_press(world_pos: Vector2) -> void:
	_pressed = true
	_drag_accum = 0.0
	_press_at = world_pos
	# Only somebody under the finger starts a hold. Everything else in the port is
	# worked by tapping, and arming a timer over cargo would mean the yard behaved
	# differently depending on how long a tap took.
	_hold_t = 0.0 if _person_at(world_pos) != null else -1.0


func _move_press(world_pos: Vector2) -> void:
	if _held_actor != null and is_instance_valid(_held_actor):
		_held_actor.drag_to(world_pos)
	elif _drag_accum >= GRAB_SLOP:
		# A drag is the camera's, not a grab's. Once the pointer has travelled the
		# player is panning the terminal and holding still afterwards must not
		# suddenly lift somebody off the ground.
		_hold_t = -1.0


func _end_press(world_pos: Vector2) -> void:
	_hold_t = -1.0
	if _held_actor != null:
		drop_held()
	elif _pressed and _drag_accum < GRAB_SLOP:
		_try_tap(world_pos)
	_pressed = false


func drop_held() -> void:
	if _held_actor != null and is_instance_valid(_held_actor):
		_held_actor.release()
	_held_actor = null
	npc_grab_changed.emit(false)


func _tick_hold(delta: float) -> void:
	## A tap opens somebody's badge; keeping the finger down picks them up. The
	## two cannot both fire, so the hold is timed here and the tap on release only
	## happens when the hold never matured.
	if _held_actor != null and not is_instance_valid(_held_actor):
		# Buying land rebuilds every actor in the yard, and the one in the air
		# goes with them.
		_held_actor = null
		npc_grab_changed.emit(false)
	if _hold_t < 0.0 or _held_actor != null or not _pressed:
		return
	_hold_t += delta
	if _hold_t < GRAB_HOLD:
		return
	_hold_t = -1.0
	var subject := _person_at(_press_at)
	if subject == null or not subject.grab():
		return
	_held_actor = subject
	_held_actor.drag_to(_press_at)
	AudioManager.play_sfx("tap", 0.14)
	npc_grab_changed.emit(true)


func _person_at(world_pos: Vector2) -> StructureActor:
	if structures == null:
		return null
	for actor in structures.crew():
		if actor.hit_test(world_pos):
			return actor
	return null


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _try_tap(world_pos: Vector2) -> void:
	## The gull first of all, then cargo, then people. Working the ship and
	## working a parked carreta are the game; a dossier is something you go and
	## look at — but a tap on the golden gull must never be eaten by whatever
	## happens to be under the bird.
	if _gull != null and is_instance_valid(_gull) and _gull.hit_test(world_pos):
		_catch_gull()
		return
	if _tap_a_berth(world_pos):
		AudioManager.play_sfx("click", 0.12)
	elif critters != null and critters.tap_cat(world_pos):
		AudioManager.play_sfx("meow", 0.10)
	elif gate != null and gate.handle_tap(world_pos):
		AudioManager.play_sfx("click", 0.12)
	elif rail != null and rail.handle_tap(world_pos):
		AudioManager.play_sfx("click", 0.12)
	elif xray_station != null and xray_station.hit_test(world_pos):
		xray_station_tapped.emit()
		AudioManager.play_sfx("tap", 0.10)
	elif land_site != null and land_site.hit_test(world_pos):
		land_works_tapped.emit()
		AudioManager.play_sfx("tap", 0.10)
	elif _inspect_npc(world_pos):
		AudioManager.play_sfx("tap", 0.10)
	elif atmosphere != null and atmosphere.tap_lamp(world_pos):
		pass


func _inspect_npc(world_pos: Vector2) -> bool:
	## Whoever was touched, and what they are doing right now.
	##
	## People on foot only. A carreteiro's card used to open by tapping the lorry
	## he drives, and every crewed machine in the yard behaved the same way, so
	## reaching for equipment opened a personnel file instead. Their dossiers live
	## in the journal's EQUIPE tab, where the whole shift is listed.
	if crew == null or structures == null:
		return false
	for actor in structures.crew():
		if actor.hit_test(world_pos):
			npc_inspected.emit(actor.profile, {
				"actor": actor,
				"objective": actor.objective_text(),
				"stage": actor.stage_text(),
			})
			return true
	return false


func _on_crew_hired(profile: NpcProfile) -> void:
	## The first hire is the one moment to say that the people on the terminal can
	## be tapped. Nothing else in the game teaches it, and a dossier nobody knows
	## about may as well not exist.
	if profile == null or GameState.flags.get("crew_intro", false):
		return
	GameState.flags["crew_intro"] = true
	# The world is built before Main's notification coordinator exists, so this
	# cannot be emitted inline on the very first hire.
	_announce_crew.call_deferred(profile.display_name, profile.title())


func _announce_crew(display_name: String, title: String) -> void:
	EventBus.notification_requested.emit({
		"id": "crew_intro", "kind": &"crew", "priority": 2,
		"text": "%s assumiu como %s. Toque em alguém no pátio pra ver a ficha."
			% [display_name, title.to_lower()],
	})


func _on_berth_move_started(move: Dictionary) -> void:
	## The relay already put a crane on this box — it claims one leg at a time,
	## for the exact stretch the box is on. Dispatching here as well would set a
	## second gantry running a phantom load for the same transfer.
	##
	## The flag is exact: `BerthCallController._begin_flight` calls `fly_cargo`
	## and emits `move_started` in the same statement block, with nothing in
	## between that could start another flight.
	if _relay_claimed_crane:
		return
	if structures != null:
		structures.dispatch_berth_move(move)


func _refresh_interaction_outlines() -> void:
	var hulls := berth_hulls()
	for index in hulls.size():
		var hull := hulls[index]
		var controller := berth_controller(index)
		var actionable := _input_enabled and controller != null \
			and controller.can_work()
		hull.set_interaction_state(actionable,
			actionable and hull.hit_test(_hover_world_pos))
	for bay: int in _gate_trucks.keys():
		var truck: RoadTruck = _gate_trucks[bay]
		if truck == null or not is_instance_valid(truck):
			continue
		var actionable := _input_enabled and gate != null and gate.can_work_bay(bay)
		truck.set_interaction_state(actionable,
			actionable and truck.hit_test(_hover_world_pos))


# ---------- cargo flow ----------

func _on_container_unloaded(_world_pos: Vector2, _value: float, _crit: bool) -> void:
	## Legacy compatibility only; the berth controller now owns cargo/reward
	## ordering and calls this flow directly from input.
	_tap_a_berth(_world_pos)


func _move_ship_to_yard(_value: float, _crit: bool) -> void:
	if berth != null:
		berth.handle_tap(ship.global_position)


func _move_yard_to_ship(_value: float, _crit: bool) -> void:
	if berth != null:
		berth.handle_tap(ship.global_position)


func fly_cargo(color: int, from: Vector2, to: Vector2) -> FlyingContainer:
	## Every container the terminal moves comes through here, and this is where
	## it is decided whether the box crosses on its own or is handed from machine
	## to machine.
	##
	## A relay is only planned when the port owns a chassis that is free right
	## now. Before the first machine there is nobody to hand a box to, and a relay
	## would make every transfer stand on the apron waiting for a tractor that
	## does not exist — so an empty terminal keeps the plain arc it always had,
	## and buying the first tractor is the moment containers start being *driven*.
	var fly := CargoRelay.new()
	# Controllers exchange global visual centres. The traveller belongs to the
	# Overhead layer, so convert once at this boundary; this remains correct if
	# the world or cargo layer later receives a transform of its own.
	var start := overhead.to_local(from)
	var end := overhead.to_local(to)
	fly.setup(_containers, color, start, end)
	_relay_claimed_crane = relays_enabled and _live_relays < MAX_LIVE_RELAYS \
		and structures != null and fly.plan(self, start, end)
	if _relay_claimed_crane:
		_live_relays += 1
		fly.tree_exiting.connect(func() -> void:
			_live_relays = maxi(0, _live_relays - 1))
	overhead.add_child(fly)
	return fly


func gate_bed_slot_position(bay: int, slot: int) -> Vector2:
	var truck: RoadTruck = _gate_trucks.get(bay)
	if truck != null and is_instance_valid(truck):
		return truck.bed_slot_global_position(slot)
	# No truck on the bay: aim at where the slot would be on a rig parked nose-out
	# in it. The offsets are the chassis's own, so the fallback and the real thing
	# never disagree by more than the suspension.
	var fallback := PortLayout.gate_bay_centre(bay) + Vector2(
		0.0, RoadTruck.HITCH_BACK + RoadTruck.slot_offset(slot))
	return to_global(fallback)


func _fly(color: int, from: Vector2, to: Vector2, on_land: Callable) -> void:
	var fly := fly_cargo(color, from, to)
	fly.landed.connect(on_land)


func show_call_bonus(amount: float, perfect: bool) -> void:
	## A call finished and paid: confetti over the hull, the freight in big gold
	## numbers, a buzz. A perfect call (every bay full) gets twice the confetti.
	if ship == null:
		return
	var at := ship.global_position + Vector2(PortLayout.SHIP_W * 0.5, 90.0)
	if fx != null:
		fx.burst(&"confetti", at, 20 if perfect else 10, 30.0)
		fx.burst(&"coin", at, 6, 14.0)
	Fx.haptic(40)
	if UserPreferences.floating_numbers:
		_spawn_float_text(at + Vector2(0, -16), amount, true)


func show_combo_feedback(pos: Vector2, steps: int, stepped: bool) -> void:
	## The feel of a tap: a spark burst at the finger that grows with the combo,
	## a short buzz, and a ping that climbs a semitone-ish per step.
	if fx != null:
		fx.burst(&"spark", pos, 2 + steps, 10.0)
		if stepped:
			fx.burst(&"coin", pos, 3, 6.0)
	if stepped:
		Fx.haptic(14)
		AudioManager.play_sfx_pitched("combo", 1.0 + 0.07 * float(steps), -4.0)
	elif steps > 0:
		AudioManager.play_sfx_pitched("combo", 0.9 + 0.05 * float(steps), -12.0)


func show_cargo_reward(pos: Vector2, value: float, crit: bool) -> void:
	## Reward accounting happens in BerthCallController before this presentation
	## hook. Hiding feedback must therefore never suppress an earned reward.
	if not UserPreferences.floating_numbers:
		return
	_spawn_float_text(pos + Vector2(4, -8), value, crit)


func show_premiada(pos: Vector2) -> void:
	## The "this box paid x5" label, gold, above the box that just landed.
	if not UserPreferences.floating_numbers:
		return
	var ft := FloatText.new()
	ft.setup(Loc.t("cargo.premiada"), pos + Vector2(0.0, -30.0), true)
	overhead.add_child(ft)


func spawn_dust(pos: Vector2) -> void:
	var puff := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 14.0)
	frames.set_animation_loop(&"default", false)
	var tex: Texture2D = preload("res://assets/sprites/prop_dust.png")
	for i in 4:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 16, 0, 16, 12)
		frames.add_frame(&"default", at)
	puff.sprite_frames = frames
	puff.centered = false
	puff.position = pos - Vector2(2, 2)
	puff.animation_finished.connect(puff.queue_free)
	overhead.add_child(puff)
	puff.play()


func show_world_badge(pos: Vector2, text: String) -> void:
	## A caption over a place in the terminal rather than over a number in the
	## chrome. Used to point at the machine a purchase just paid for, so the
	## answer to "what did that buy me?" is somewhere the player is already
	## looking instead of only in a shop they are about to close.
	if not UserPreferences.floating_numbers:
		return
	var badge := FloatText.new()
	badge.setup(text, pos, false)
	overhead.add_child(badge)


func _spawn_float_text(pos: Vector2, value: float, crit: bool) -> void:
	var ft := FloatText.new()
	ft.setup("+" + GameState.fmt(value), pos, crit)
	overhead.add_child(ft)


func _on_hull_phase(phase: int, index: int) -> void:
	## A special charter is worked when its vessel is actually alongside: the player
	## agreed to it, then watched it come up the fairway, and only now is asked to
	## do the job. A vessel that leaves without being played was interrupted, and an
	## interruption pays nothing either way.
	if specials == null or not specials.is_special_berth(index):
		return
	if phase == Ship.Phase.DISCHARGING:
		specials.notify_alongside(index)
	elif phase == Ship.Phase.AWAY:
		specials.abandon()


func _tap_a_berth(world_pos: Vector2) -> bool:
	## Whichever hull was touched works its own call. With three ships alongside
	## the tap has to reach the one under the finger, not always berth 0.
	var hulls := berth_hulls()
	for index in hulls.size():
		var hull := hulls[index]
		if hull.phase != Ship.Phase.AWAY and hull.hit_test(world_pos):
			var controller := berth_controller(index)
			if controller != null:
				return controller.handle_tap(world_pos)
	return false


# ---------- the golden gull ----------

func _tick_golden_gull(delta: float) -> void:
	## The reward clock only runs while the port is actually being played: a
	## terminal with no base income, or one whose input is blocked by an
	## overlay, has nothing worth rewarding and is not owed a gull.
	if _gull != null and is_instance_valid(_gull):
		_gull.frozen = gulls_frozen
		return
	if gulls_frozen:
		return
	if _gull_policy.tick(delta, GameState.base_cps > 0.0 and _input_enabled, _rng):
		_spawn_golden_gull()


func _spawn_golden_gull() -> void:
	## One gull crossing the part of the terminal the player can actually see:
	## the visible rect mapped into world space and clamped to the world's
	## width, with the 70 px the HUD and the console cover left clear at the
	## top and bottom. It flies from 24 px outside one side to 24 px outside
	## the other, on a random side.
	var world_rect: Rect2 = get_canvas_transform().affine_inverse() \
		* get_viewport().get_visible_rect()
	world_rect.position.x = clampf(world_rect.position.x, 0.0, PortLayout.WORLD_W)
	world_rect.size.x = clampf(world_rect.end.x, 0.0, PortLayout.WORLD_W) \
		- world_rect.position.x
	var y0 := world_rect.position.y + 70.0
	var y1 := world_rect.end.y - 70.0
	var y := _rng.randf_range(y0, y1) if y1 > y0 \
		else world_rect.position.y + world_rect.size.y * 0.5
	var west_first := _rng.randf() < 0.5
	var from := Vector2(
		world_rect.position.x - 24.0 if west_first else world_rect.end.x + 24.0, y)
	var to := Vector2(
		world_rect.end.x + 24.0 if west_first else world_rect.position.x - 24.0, y)
	_gull = GoldenGull.new()
	_gull.setup(from, to, GoldenGullPolicy.FLIGHT_SECONDS)
	_gull.escaped.connect(_on_gull_escaped)
	overhead.add_child(_gull)
	AudioManager.play_sfx("gull", 0.1)
	if not _gull_hint_shown:
		# Riding with the bird, not in the notice bell: the bell collects news
		# for later, and this is worth something only in the next nine seconds.
		_gull_hint_shown = true
		_gull.show_hint(Loc.t("gull.hint"))


func _on_gull_escaped() -> void:
	## It flew off uncaught. Missing costs nothing — that is the whole point of
	## the bonus — but the miss is counted.
	_gull_policy.missed += 1
	AudioManager.play_sfx("gull_escape", 0.04, -6.0)
	_gull = null


func _catch_gull() -> void:
	## A tap on the bird: roll the prize, burst it, count the catch and hand the
	## prize to Main with the position it was caught at.
	var prize := _gull_policy.roll(_rng)
	var pos := _gull.global_position
	_gull.catch()
	_gull = null
	_gull_policy.caught += 1
	AudioManager.play_sfx("coins", 0.05)
	if UserPreferences.floating_numbers:
		var ft := FloatText.new()
		# A crit float adds its own "!", and the strings carry one for the
		# places that print them plainly.
		ft.setup(Loc.t("gull.%s" % str(prize.get("id", "lucky"))).trim_suffix("!"),
			pos, true)
		overhead.add_child(ft)
	golden_gull_caught.emit(prize, pos)


func gull_policy() -> GoldenGullPolicy:
	## For tests and the capture harness.
	return _gull_policy


func active_gull() -> GoldenGull:
	## The gull currently crossing, or null. For tests and the capture harness.
	if _gull != null and is_instance_valid(_gull):
		return _gull
	return null


# ---------- yard traffic dispatch ----------

func target_fill() -> float:
	## How full the yard "should" look for the current throughput. Growing
	## income means a busier terminal, which is the whole visual payoff.
	var cps := maxf(1.0, GameState.cps)
	return clampf(0.08 + log(cps) / log(10.0) / 11.0, 0.08, 0.95)


func request_job(excluded_uids: PackedStringArray = PackedStringArray()) -> Dictionary:
	## Machines ask for work here. Returns a pickup (box leaves by gate) or a
	## delivery (box arrives from the city), whichever the yard needs.
	##
	## `excluded_uids` are the boxes another driver is already on their way to
	## collect. Without it two vehicles are offered the same top-of-stack, the
	## second one finds nothing when it gets there, and drives home empty.
	var fill := yard.fill_ratio()
	var target := target_fill()
	if fill > target + 0.04:
		var slot := road_pickup_slot(excluded_uids)
		if slot >= 0:
			return {"type": "pickup", "slot": slot,
				"pos": yard.slot_position(slot)}
	elif fill < target - 0.04:
		var landing := yard.pick_landing_slot(CargoUnit.EXPORT)
		if landing.is_empty():
			return {}
		var unit := CargoUnit.new(CargoUnit.new_uid("road_service"),
			CargoUnit.EXPORT, randi() % 8, "cidade")
		return {"type": "deliver", "slot": landing.slot, "level": landing.level,
			"pos": landing.pos, "color": unit.color, "unit": unit,
			"token": landing.token}
	return {}


func complete_pickup(slot: int) -> Dictionary:
	return take_road_pickup(PackedStringArray(), slot)


func begin_hauler_pickup(slot: int,
		excluded_uids: PackedStringArray = PackedStringArray()) -> Dictionary:
	## The box leaves the rendered stack now, but remains in a persisted transit
	## ledger until the vehicle clears the gate.
	##
	## The exclusions are the boxes other drivers hold a claim on: without them the
	## yard's own "best top of stack" answer can be somebody else's box, and this
	## driver — standing at the right stack — is told there is nothing to lift.
	var taken := take_road_pickup(excluded_uids, slot)
	if taken.is_empty():
		return {}
	var return_token := yard.reserve_taken_return(taken)
	if return_token.is_empty():
		yard.restore_taken(taken)
		return {}
	var token := CargoUnit.new_uid("haul")
	taken["traffic_token"] = token
	taken["return_token"] = return_token
	_traffic_in_transit[token] = taken
	return taken


func complete_delivery(slot: int, level: int, unit: CargoUnit,
		token: String = "") -> bool:
	if unit == null or unit.origin_uid != "cidade":
		yard.release_landing(token)
		return false
	var placed := yard.place_unit(slot, level, unit, token)
	if placed:
		spawn_dust(yard.level_position(slot, level) + Vector2(4, 4))
	else:
		yard.release_landing(token)
	return placed


func cancel_job(job: Dictionary) -> void:
	## A delivery reserves physical yard capacity before the vehicle starts.
	## A pickup already lifted by a vehicle remains port property until that
	## vehicle exits the gate. Rebuild/prestige must return either resource.
	if job.get("type", "") == "deliver":
		yard.release_landing(str(job.get("token", "")))
	elif job.get("type", "") == "pickup":
		var job_taken: Dictionary = job.get("taken", {})
		var token := str(job.get("traffic_token",
			job_taken.get("traffic_token", "")))
		var taken: Variant = _traffic_in_transit.get(
			token, job_taken)
		if taken is Dictionary and not taken.is_empty():
			var restored := yard.restore_reserved_taken(
				taken, str(taken.get("return_token", "")))
			if not restored:
				yard.release_landing(str(taken.get("return_token", "")))
				restored = yard.restore_taken(taken)
			if restored:
				_traffic_in_transit.erase(token)


func commit_job(job: Dictionary) -> void:
	if job.get("type", "") != "pickup":
		return
	var taken: Dictionary = job.get("taken", {})
	var token := str(job.get(
		"traffic_token", taken.get("traffic_token", "")))
	var tracked: Dictionary = _traffic_in_transit.get(token, taken)
	yard.release_landing(str(tracked.get("return_token", "")))
	_traffic_in_transit.erase(token)
	SaveManager.request_save(&"traffic_pickup_committed")


func _road_priority_uids() -> PackedStringArray:
	## Cargo from the hull currently being worked is ideal road freight because
	## that same hull is forbidden to reload it. Between calls there is no
	## priority set, so the full 24-box reserve is protected.
	var priority := PackedStringArray()
	for hull in working_ships():
		for uid in hull.import_manifest_uids():
			priority.append(uid)
	if not priority.is_empty():
		return priority
	return PackedStringArray()


func road_pickup_slot(excluded_uids: PackedStringArray = PackedStringArray()) -> int:
	return yard.road_pickup_slot(
		_road_priority_uids(), excluded_uids,
		RoadCargoPolicy.MIN_OPERATIONAL_STOCK)


func has_road_pickup(excluded_uids: PackedStringArray = PackedStringArray()) -> bool:
	return road_pickup_slot(excluded_uids) >= 0


func take_road_pickup(excluded_uids: PackedStringArray = PackedStringArray(),
		preferred_slot: int = -1) -> Dictionary:
	var priority := _road_priority_uids()
	var approved_slot := yard.road_pickup_slot(
		priority, excluded_uids, RoadCargoPolicy.MIN_OPERATIONAL_STOCK)
	if approved_slot < 0:
		return {}
	# A structure actor reserved a visual route to this slot. If the approved
	# top changed in the meantime, reject the stale job instead of taking a
	# different box invisibly.
	if preferred_slot >= 0 and approved_slot != preferred_slot:
		return {}
	return yard.take_for_road(
		excluded_uids, priority, RoadCargoPolicy.MIN_OPERATIONAL_STOCK)


func _traffic_snapshot() -> Dictionary:
	var records: Array = []
	for taken: Dictionary in _traffic_in_transit.values():
		var record := taken.duplicate(true)
		if record.get("unit") is CargoUnit:
			record["unit"] = (record.unit as CargoUnit).snapshot()
		records.append(record)
	return {"in_transit": records}


func _traffic_restore(data: Dictionary) -> void:
	for taken: Dictionary in _traffic_in_transit.values():
		yard.release_landing(str(taken.get("return_token", "")))
	_traffic_in_transit.clear()
	if traffic != null:
		traffic.clear()
	for raw in data.get("in_transit", []):
		if not raw is Dictionary:
			continue
		var taken: Dictionary = raw.duplicate(true)
		if taken.get("unit") is Dictionary:
			taken["unit"] = CargoUnit.from_snapshot(taken.unit)
		var old_token := str(taken.get("traffic_token", ""))
		var return_token := yard.reserve_taken_return(taken)
		taken["return_token"] = return_token
		var restored := not return_token.is_empty() \
			and yard.restore_reserved_taken(taken, return_token)
		if not restored:
			yard.release_landing(return_token)
			restored = yard.restore_taken(taken)
		if not restored:
			# Keep ownership in the persisted ledger rather than silently
			# discarding a UID from a malformed/full restored yard.
			_traffic_in_transit[old_token] = taken


func _traffic_seed() -> void:
	for taken: Dictionary in _traffic_in_transit.values():
		yard.release_landing(str(taken.get("return_token", "")))
	_traffic_in_transit.clear()
	if traffic != null:
		traffic.clear()
