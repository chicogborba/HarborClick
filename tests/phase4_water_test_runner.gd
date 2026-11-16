extends Node
## Run with: Godot --headless --path . res://tests/phase4_water_test_runner.tscn

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_quality_budget()
	await _test_foam_caps_and_assets()
	await _test_shader_contract()
	_test_wake_track_ages_and_expires()
	_test_wake_teleport_starts_a_new_chain()
	_test_wake_pack_respects_budget()
	await _test_surface_renders_at_world_resolution()
	await _test_world_feeds_hulls_in_world_space()
	if failures.is_empty():
		print("PHASE 4 WATER TESTS PASSED")
		get_tree().quit(0)
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)


func _test_quality_budget() -> void:
	_expect(WaterQuality.choose(Vector2(360, 800), false) == WaterQuality.Level.LOW, "narrow viewport selects low water quality")
	_expect(WaterQuality.choose(Vector2(800, 600), false) == WaterQuality.Level.MEDIUM, "mid desktop viewport selects medium water quality")
	_expect(WaterQuality.choose(Vector2(1200, 800), false) == WaterQuality.Level.HIGH, "wide desktop viewport selects high water quality")
	_expect(WaterQuality.choose(Vector2(1200, 800), true) == WaterQuality.Level.LOW, "mobile device always selects low quality")


func _test_foam_caps_and_assets() -> void:
	var foam := WaterFoam.new()
	add_child(foam)
	foam.setup(WaterQuality.Level.LOW, 900.0)
	await get_tree().process_frame
	_expect(foam.foam_count() <= WaterFoam.MAX_FOAM[WaterQuality.Level.LOW], "low foam is capped")
	_expect(foam.splash_count() == 0, "low quality skips splash animation")
	foam.set_quality(WaterQuality.Level.HIGH)
	await get_tree().process_frame
	_expect(foam.foam_count() <= WaterFoam.MAX_FOAM[WaterQuality.Level.HIGH], "high foam remains capped")
	_expect(foam.splash_count() == 2, "high quality uses two existing splash animations")
	foam.queue_free()
	await get_tree().process_frame


func _test_shader_contract() -> void:
	var shader := load("res://assets/shaders/water_top.gdshader") as Shader
	_expect(shader != null, "top-down water shader loads")
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("quality_level", WaterQuality.Level.HIGH)
	material.set_shader_parameter("shore_x", PortLayout.WATER_X0)
	_expect(int(material.get_shader_parameter("quality_level")) == WaterQuality.Level.HIGH, "shader exposes quality level")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 64)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var water := ColorRect.new()
	water.size = Vector2(96, 64)
	water.material = material
	viewport.add_child(water)
	await get_tree().process_frame
	viewport.queue_free()


func _test_wake_track_ages_and_expires() -> void:
	var wakes := WaterWakes.new()
	for i in 60:
		wakes.feed(&"hull", Vector2(280.0, 400.0 - i * 2.0), 8.0, 1.0)
		wakes.tick(1.0 / 30.0)
	_expect(wakes.point_count() >= 6, "a hull making way lays a track of samples")
	var packed := wakes.pack(Vector2.ZERO)
	_expect(packed.size() >= 2 and packed[0].w < 0.0,
		"the first sample of a chain is flagged so no segment joins it to another")
	_expect(packed[packed.size() - 1].y < packed[0].y and packed[packed.size() - 1].z < packed[0].z,
		"samples run oldest to newest, the newest at the stern")
	# Stop feeding: the head goes, the track stays, then dissolves.
	wakes.tick(0.1)
	_expect(wakes.point_count() > 0, "a stopped hull leaves its track on the water")
	for i in int(WaterWakes.LIFE * 10.0) + 2:
		wakes.tick(0.1)
	_expect(wakes.point_count() == 0 and wakes.chain_count() == 0,
		"the track is forgotten once it has aged out")


func _test_wake_teleport_starts_a_new_chain() -> void:
	var wakes := WaterWakes.new()
	for i in 20:
		wakes.feed(&"hull", Vector2(280.0, 300.0 - i * 3.0), 8.0, 1.0)
		wakes.tick(1.0 / 30.0)
	# Respawned off-map: must not draw a wake across the harbour.
	wakes.feed(&"hull", Vector2(280.0, 900.0), 8.0, 1.0)
	wakes.tick(1.0 / 30.0)
	_expect(wakes.chain_count() == 2, "a teleport retires the old track instead of joining it")
	var packed := wakes.pack(Vector2.ZERO)
	for i in range(1, packed.size()):
		if packed[i].w > 0.0:
			_expect(Vector2(packed[i].x, packed[i].y).distance_to(
				Vector2(packed[i - 1].x, packed[i - 1].y)) < WaterWakes.TELEPORT,
				"no packed segment spans a teleport")


func _test_wake_pack_respects_budget() -> void:
	var wakes := WaterWakes.new()
	for chain in 6:
		for i in 40:
			wakes.feed(StringName("b%d" % chain), Vector2(250.0 + chain * 10.0, 900.0 - i * 8.0),
				2.5, 1.0, 7.0, 4.5)
			wakes.tick(0.02)
	var packed := wakes.pack(Vector2.ZERO)
	_expect(packed.size() <= WaterWakes.MAX_POINTS, "the shader never receives more samples than it declares")
	var weak := WaterWakes.new()
	weak.feed(&"slow", Vector2(280.0, 400.0), 8.0, 0.2)
	weak.feed(&"slow", Vector2(280.0, 370.0), 8.0, 0.2)
	_expect(weak.pack(Vector2.ZERO)[0].z > 1.0, "a slow hull's track reads as older, so it is fainter")


func _test_surface_renders_at_world_resolution() -> void:
	var surface := WaterSurface.new()
	surface.size = Vector2(104.0, 2400.0)
	surface.set_shader(load("res://assets/shaders/water_top.gdshader"))
	add_child(surface)
	surface.set_process(false)
	await get_tree().process_frame
	_expect(surface.viewport().size == Vector2i(104, 2400),
		"before it follows a camera the whole sea is painted, one fragment per world pixel")
	# Only the rows in view (plus a margin) are painted, wherever the camera is.
	surface.follow_view(Rect2(0.0, 1500.0, 104.0, 300.0))
	var rows := surface.painted_rows()
	_expect(surface.viewport().size.x == 104 and rows.y < 2400,
		"a long harbour paints a window, not the whole quay")
	_expect(rows.x <= 1500 and rows.x + rows.y >= 1800,
		"the painted window covers what the camera sees")
	var offset: Vector2 = surface.water_material.get_shader_parameter("world_offset")
	_expect(is_equal_approx(offset.y, float(rows.x)),
		"the shader is told which world row the window starts at")
	surface.follow_view(Rect2(0.0, 2350.0, 104.0, 300.0))
	rows = surface.painted_rows()
	_expect(rows.x + rows.y <= 2400, "the window never runs past the bottom of the sea")
	surface.size = Vector2(104.0, 3000.0)
	_expect(surface.viewport().size == Vector2i(104, 3000), "buying land grows the render target")
	surface.queue_free()
	await get_tree().process_frame


func _test_world_feeds_hulls_in_world_space() -> void:
	## The hull rectangles used to be sent as world minus the water's origin
	## while the shader works in world space, so every lap was drawn 228 px west,
	## under the quay. Pin the frame they are sent in.
	var world := PortWorld.new()
	add_child(world)
	await get_tree().process_frame
	var hull: Ship = world.ship
	hull.visible = true
	world._feed_water_shader(1.0 / 60.0)
	var mat: ShaderMaterial = world._water.water_material
	var rects: PackedVector4Array = mat.get_shader_parameter("hulls")
	_expect(int(mat.get_shader_parameter("hull_count")) >= 1 and rects.size() >= 1,
		"a visible hull is handed to the water")
	if rects.size() >= 1:
		var sent := Vector2(rects[0].x, rects[0].y)
		_expect(sent.distance_to(hull.hull_centre()) < 0.5,
			"hulls reach the shader in world space, where the water is drawn")
	world.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if not condition: failures.append(label)
